# E-3: Where Windows keeps the package

- **Started:** 2026-10-26T18:05:35Z
- **Objective:** After applying a package during setup, record where Windows stores it and who can read it
- **Expected:** ProgramData\Microsoft\Provisioning holds it; C:\Recovery\Customizations empty

## Steps and evidence
- `01-e1-locations.txt`: `tools/vm-exec.sh e1-bypass 'Get-ProvisioningPackage -AllInstalledPackages -ErrorAction SilentlyContinue | Form`
- `02-e1-file-acl.txt`: `tools/vm-exec.sh e1-bypass '(Get-Acl C:\ProgramData\Microsoft\Provisioning\fleet-agent-b-plain.ppkg).Access | `

After E-1: the package is kept as C:\ProgramData\Microsoft\Provisioning\fleet-agent-b-plain.ppkg (24 MB, contains the MSI with the enroll secret). C:\Recovery is empty, so nothing is staged for push-button reset. File ACL: Users and Everyone read+execute, INTERACTIVE modify. Any signed-in user, standard users included, can copy the package and read the enroll secret. Get-ProvisioningPackage can't load during setup (module load error), so the list comes from the folder.

## Result: PARTIAL

PKG-B (unencrypted) kept in ProgramData\Microsoft\Provisioning, readable by every user; C:\Recovery empty. PKG-N location still to record after E-2.

_Finished 2026-10-26T18:06:34Z_
- `03-e2-locations.txt`: `tools/vm-exec.sh e2-nobypass 'Get-ChildItem C:\ProgramData\Microsoft\Provisioning -Force | Where-Object Length`

## Result: PASS

Both packages kept as C:\ProgramData\Microsoft\Provisioning\<name>.ppkg, the folder Microsoft names for doWipePersistProvisionedData. C:\Recovery stays empty. Users and Everyone can read the file, so any signed-in user can extract the MSI and its enroll secret (unencrypted packages; encrypted not tested, see E-1).

_Finished 2026-10-26T18:22:24Z_
