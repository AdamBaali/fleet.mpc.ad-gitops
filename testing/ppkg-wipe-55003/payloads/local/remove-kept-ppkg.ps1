# Negative control for X-7: removes the package kept from setup, so no package is left for the reset to re-apply.
Get-ChildItem 'C:\ProgramData\Microsoft\Provisioning' -Filter *.ppkg -Force | Remove-Item -Force
Get-ChildItem 'C:\ProgramData\Microsoft\Provisioning', 'C:\Recovery\Customizations' -Recurse -Include *.ppkg -Force -ErrorAction SilentlyContinue | Measure-Object | ForEach-Object { "packages left: $($_.Count)" }
