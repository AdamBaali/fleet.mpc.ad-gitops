# Notes: package-filename-identity

## Lab versus production
- The lab runs Fleet 4.95.0. The code below is the same at `fleet-v4.95.0` and `fleet-v4.96.0`.
- The customer's fleet is Linux. Their package type is not confirmed. The error only fits a type whose title
  comes from the filename: .sh, .py, .ps1, .zip or .tar.gz. Confirm this with the customer.

## Not tested
- Host installs. The error happens at upload, before any host is involved.
- The UI. The UI sends the same API request as `scripts/upload.sh`. A screenshot of the UI message is a good
  addition for the feature request.

## Sources (fleetdm/fleet at `fleet-v4.96.0`)
- `server/fleet/errors.go:56-57`: the two messages.
  `SoftwarePackageHashConflictMessage` is "%s package is already added (same SHA-256 hash)."
  `SoftwarePackageTitleMismatchMessage` is "Couldn't add. %s doesn't match the software title. To add it, go to Software and add it as new software."
- `server/datastore/mysql/software_installers.go:5110-5141` (`checkSoftwareConflictsByIdentifier`): resolves
  the package's title, returns the title mismatch when it differs from `software_title_id`, and only after that
  checks for a duplicate hash on the title. This order is why identical bytes get the title message.
- `ee/server/service/software_installers.go:2739-2743`: packages with no metadata name use the full filename
  as the title (.tar.gz keeps its extension).
- `ee/server/service/software_installers.go:2891-2894` and `:2938-2941`: script packages and .zip use the
  filename without its extension.
- `ee/server/service/software_installers.go:432-438`: the upload reads `software_title_id` from the form.
- `server/service/integration_software_titles_test.go:801-899` (`TestSoftwarePackageTitleValidation`):
  `other.sh` added to the `deploy` title is rejected with the title mismatch. This is the behavior on purpose.
- The check was added in "Fix mismatched package upload creating a new title instead of erroring", first
  released in `fleet-v4.90.0`. Before that, a mismatched package silently made a new title.
- `docs/Configuration/yaml-files.md`: "The same custom package at different versions can upload side by side."

## Ideas
- Fix the message without changing behavior: run the duplicate hash check before the title check, so identical
  bytes always get the hash message.
- For types with no extracted identity (scripts, .zip, .tar.gz), trust the title the admin picked when
  `software_title_id` is set. Packages with a bundle ID or upgrade code keep today's check, which stops a
  different app from landing on the wrong title.
