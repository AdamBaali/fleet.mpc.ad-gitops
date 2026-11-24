# Notes: fleetd health check scripts

## Lab versus production
- Fleet runs the script as SYSTEM with `%TEMP%` set to `C:\Windows\Temp`, so the archive lands there. A person running
  it elevated gets their own `%TEMP%`.
- Fleet keeps only the end of a long script output, so T-3 and T-4 may lose the first sections. The archive's
  `summary.txt` holds everything.
- Fleet accepts saved scripts up to 500,000 characters and run-once scripts up to 10,000 (`server/fleet/scripts.go`),
  so the 21 KB script has to be saved, not sent inline.

## Sources
- Credential Manager: `orbit/pkg/keystore/keystore_windows.go` (`Supported()` returns true), and
  `deleteSecretPathIfExists` in `orbit/cmd/orbit/orbit.go`.
