#!/bin/sh
# Script-only package for the Package Identity Lab. Fleet names a script package's title
# after its filename, so this file is the base title that the filename tests add versions to.
# It only writes a marker, so installing it on a lab host changes nothing else.
set -eu
marker=/var/tmp/fleet-package-identity-probe
echo "package-identity-probe v1 installed $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$marker"
cat "$marker"
