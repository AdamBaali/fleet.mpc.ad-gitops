# Fakes the registry keys and certificates an Entra-joined, Intune-enrolled host has, so the
# report SQL can be tested without a tenant. Windows did not write these: it proves the SQL, not Windows.
# Usage (as SYSTEM): fake-ids.ps1 <action>
#   baseline   show what exists before any fake
#   setup      one current Entra join and one Intune enrollment (T-1)
#   clear      remove every fake (T-2a)
#   nocert     setup, then delete the device certificate but keep the JoinInfo subkey (T-2b)
#   otherca    a JoinInfo subkey and certificate from a different issuer only (T-2c)
#   stale      setup, plus an older second Intune enrollment (T-2d)
#   twojoins   setup, plus an older second Entra join with its own matching certificate (T-2e)
# Every fake carries the "ids-test" marker so clear can find it. Expected values go to C:\ids\expected.json.
param([Parameter(Mandatory)][ValidateSet('baseline','setup','clear','nocert','otherca','stale','twojoins')]$Action)
$ErrorActionPreference = 'Stop'
$join = 'HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo'
$enr  = 'HKLM:\SOFTWARE\Microsoft\Enrollments'
$store = 'Cert:\LocalMachine\My'
# The real issuer is one multi-valued RDN. osquery renders its values joined by " + ", which is
# what Fleet's LIKE 'net + windows + MS-Organization-Access%' matches.
$entraCa = 'DC=net+DC=windows+CN=MS-Organization-Access+OU=82dbaca4-3e81-46ca-9c73-0950c1eaca97'
$expected = [ordered]@{}

function New-Ca($subject) {
  New-SelfSignedCertificate -Subject $subject -CertStoreLocation $store -KeyUsage CertSign, CRLSign `
    -TextExtension @('2.5.29.19={critical}{text}ca=true') -FriendlyName 'ids-test' -NotAfter (Get-Date).AddYears(5)
}
function New-Join($ca, $years) {
  $id = [guid]::NewGuid().ToString()
  $c = New-SelfSignedCertificate -Subject "CN=$id" -Signer $ca -CertStoreLocation $store -FriendlyName 'ids-test' -NotAfter (Get-Date).AddYears($years)
  $k = New-Item -Path "$join\$($c.Thumbprint)" -Force
  Set-ItemProperty $k.PSPath TenantId '00000000-0000-0000-0000-000000000001'
  Set-ItemProperty $k.PSPath UserEmail 'test.user@example.com'
  Set-ItemProperty $k.PSPath IdpDomain 'login.windows.net'
  Set-ItemProperty $k.PSPath Marker 'ids-test'
  [pscustomobject]@{ Id = $id; Thumbprint = $c.Thumbprint }
}
function New-Enrollment {
  $g = [guid]::NewGuid().ToString().ToUpper(); $id = [guid]::NewGuid().ToString()
  $k = New-Item -Path "$enr\$g" -Force
  Set-ItemProperty $k.PSPath ProviderID 'MS DM Server'
  Set-ItemProperty $k.PSPath Marker 'ids-test'
  $d = New-Item -Path "$enr\$g\DMClient\MS DM Server" -Force
  Set-ItemProperty $d.PSPath EntDMID $id
  [pscustomobject]@{ Id = $id; Key = $g }
}
function Clear-Fakes {
  Get-ChildItem $store | Where-Object FriendlyName -eq 'ids-test' | Remove-Item
  foreach ($root in $join, $enr) {
    if (Test-Path $root) {
      Get-ChildItem $root | Where-Object { (Get-ItemProperty $_.PSPath).Marker -eq 'ids-test' } | Remove-Item -Recurse
    }
  }
}
function Show-State {
  "JoinInfo subkeys: $(@(Get-ChildItem $join -ErrorAction SilentlyContinue).PSChildName -join ', ')"
  "Enrollments subkeys: $(@(Get-ChildItem $enr -ErrorAction SilentlyContinue).PSChildName -join ', ')"
  "MS-Organization-Access certs: $(@(Get-ChildItem $store | Where-Object Issuer -like '*MS-Organization-Access*').Count)"
  "Test certs: $(@(Get-ChildItem $store | Where-Object FriendlyName -eq 'ids-test').Count)"
}

if ($Action -eq 'baseline') { Show-State; return }
Clear-Fakes
switch ($Action) {
  'clear' { }
  { $_ -in 'setup','nocert','stale','twojoins' } {
    $ca = New-Ca $entraCa
    $j = New-Join $ca 10
    $e = New-Enrollment
    $expected.entra_device_id = $j.Id; $expected.intune_device_id = $e.Id; $expected.enrollment_key = $e.Key
  }
  'nocert' {
    Get-ChildItem "$store\$($j.Thumbprint)" | Remove-Item
    $expected.entra_device_id = $null
  }
  'stale' {
    $old = New-Enrollment
    $expected.stale_intune_device_id = $old.Id; $expected.stale_enrollment_key = $old.Key
  }
  'twojoins' {
    # Shorter lifetime stands in for the older join: the query keeps the latest not_valid_after.
    $old = New-Join $ca 2
    $expected.older_entra_device_id = $old.Id
  }
  'otherca' {
    $other = New-Ca 'CN=Some Other CA'
    $j = New-Join $other 10
    $expected.entra_device_id = $null
    $expected.other_issuer_id = $j.Id
  }
}
$expected | ConvertTo-Json | Set-Content C:\ids\expected.json
Show-State
'expected:'; Get-Content C:\ids\expected.json
