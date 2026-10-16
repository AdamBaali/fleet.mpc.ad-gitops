# Skip the certificate picker in Chrome and Edge for the lab PingFederate certificate port (9032).
# Writes the AutoSelectCertificateForUrls policy to the registry. Run as SYSTEM (Fleet script or utmctl exec).
$pattern = '{"pattern":"https://ping.lab:9032","filter":{"ISSUER":{"CN":"Fleet Lab CA Intermediate CA"}}}'
foreach ($vendor in 'Google\Chrome', 'Microsoft\Edge') {
  $key = "HKLM:\SOFTWARE\Policies\$vendor\AutoSelectCertificateForUrls"
  New-Item -Path $key -Force | Out-Null
  New-ItemProperty -Path $key -Name '1' -Value $pattern -PropertyType String -Force | Out-Null
  "$vendor -> $((Get-ItemProperty $key).'1')"
}
