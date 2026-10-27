# S-6: Build PKG-B and PKG-N

- **Started:** 2026-10-26T17:54:37Z
- **Objective:** Encrypted provisioning packages with the guide's ProvisioningCommands settings, one per MSI
- **Expected:** Two .ppkg files; passwords kept in private/

## Steps and evidence
- `01-customizations.txt`: `cat ppkg/customizations-b.xml; diff ppkg/customizations-b.xml ppkg/customizations-n.xml`
- `02-packages.txt`: `ls -l out/*.ppkg; shasum -a 256 out/*.ppkg out/msi-*/fleet-osquery-arm64.msi`

Built in the builder VM with ICD.exe /Build-ProvisioningPackage ... +Encrypted +Overwrite (StoreFile Microsoft-Desktop-Provisioning.dat). ICD generated each package's password; they're in private/ppkg-passwords.txt and not in any evidence file. ICD failed first with 'Command-line has too many parameters' when the StoreFile path contained spaces; a copy at C:\build\store-desktop.dat fixed it.

## Result: PASS

PKG-B and PKG-N built, encrypted, Owner IT Admin, CommandLine msiexec.exe /i fleet-osquery-arm64.msi /qn /norestart, as the guide sets them.

_Finished 2026-10-26T17:54:38Z_
