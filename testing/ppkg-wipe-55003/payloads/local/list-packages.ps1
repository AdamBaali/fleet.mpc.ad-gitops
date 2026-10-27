# Lists every provisioning package a push-button reset could re-apply: the ones kept from setup and the staged ones.
foreach ($d in 'C:\ProgramData\Microsoft\Provisioning', 'C:\Recovery\Customizations') {
  "== $d"
  Get-ChildItem $d -Recurse -Include *.ppkg -Force -ErrorAction SilentlyContinue | ForEach-Object { "$($_.FullName) $($_.Length)" }
}
