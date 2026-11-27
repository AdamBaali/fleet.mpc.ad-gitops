# Results: package-filename-identity

No lab run yet. The lab fleet applies after this branch merges to `main`. Then run `bash scripts/run-tests.sh`
and add one entry per test here.

## Code read (2026-11-27): INFO
- **Steps:** Read the upload and title checks at `fleet-v4.95.0` and `fleet-v4.96.0` (see NOTES.md).
- **Expected for T-2, T-3, T-6:** 400 "Couldn't add. <file> doesn't match the software title."
- **Finding:** For script, .zip and .tar.gz packages, the filename is the title identity. The title check runs
  before the hash check, so the message is misleading when the bytes are identical.
