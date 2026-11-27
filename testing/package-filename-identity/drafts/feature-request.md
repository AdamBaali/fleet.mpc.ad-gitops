# Draft: feature request for fleetdm/fleet

Title: Add a package to a software title by its contents, not its filename

## Goal

| User story |
|---|
| As an IT admin, I want to add a new version of a script, .zip or .tar.gz package to its existing software title even when the filename changed, so that I don't have to rename files from vendors or build systems to match the first upload. |

## Context
- Requested by: customer-cisneros-l
- Fleet version: 4.95.0 and 4.96.0 (code read)

When an admin clicks "Add package" on a software title, Fleet checks that the new package belongs to that title.
For packages without metadata (.sh, .ps1, .py, .zip, .tar.gz), Fleet takes the title name from the filename.
So `tool.sh` and `tool-20261120.sh` are different software to Fleet, and the upload fails with:

> Couldn't add. tool-20261120.sh doesn't match the software title. To add it, go to Software and add it as new software.

Filenames often carry a date, a build number or a checksum, so this fails on most new versions unless the admin
renames every file first.

The message is also misleading when the bytes are identical. A renamed copy of a package that is already on the
title gets the title message above, not "tool-test.sh package is already added (same SHA-256 hash)."
The title check runs before the duplicate hash check.

.deb, .rpm, .pkg, .msi and .exe packages aren't affected. Their title comes from package metadata.

## Requirements
- [ ] When the admin adds a package to a title, and the package has no extracted identity (no bundle ID, no upgrade
      code, no metadata name), Fleet adds it to the chosen title whatever its filename.
- [ ] Fleet still rejects a package whose bundle ID or upgrade code belongs to a different title.
- [ ] A package with the same SHA-256 as a package already on the title gets the hash conflict message, whatever
      its filename.

## Steps to reproduce
1. Add `probe.sh` as a custom package to a fleet.
2. On the `probe` title, click "Add package" and choose a copy named `probe-v2.sh` with one line changed.
3. Fleet shows "Couldn't add. probe-v2.sh doesn't match the software title."
4. Repeat step 2 with an unchanged copy named `probe-test.sh`. Fleet shows the same message, not the hash message.

Lab reproduction: `testing/package-filename-identity/` in fleet.mpc.ad-gitops (T-2, T-3, T-6).
