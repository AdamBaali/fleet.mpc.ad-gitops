#!/usr/bin/env bash
# Start a test project from the framework templates.
# Usage: testing/_framework/bin/new-project.sh <slug> "<title>"      slug is <topic>-<issue number>, for example luks-54871
# Creates testing/<slug>/ with the documents, test-evidence/, drafts/ (for messages Adam posts) and private/ (git ignores private/).
# It never overwrites: an existing file is left as it is.
set -euo pipefail
slug="${1:?usage: new-project.sh <slug> \"<title>\"}"; title="${2:?usage: new-project.sh <slug> \"<title>\"}"
case "$slug" in *[!a-z0-9-]*|"") echo "slug uses lowercase letters, digits and dashes only" >&2; exit 2 ;; esac
F="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; P="$F/../$slug"
mkdir -p "$P"/{test-evidence,drafts,private}
for t in README TEST_PLAN RESULTS NOTES HANDOFF STATUS ISSUE_UPDATE; do
  src="$F/templates/$t.md"
  dst="$P/$t.md"
  [ -e "$dst" ] || sed "s|<project>|$slug|g; s|<Title>|$title|g; s|<feature or issue>|$title|g" "$src" > "$dst"
done
echo "created testing/$slug"
echo "next: fill TEST_PLAN.md, then: . testing/_framework/bin/ev.sh with EV=testing/$slug/test-evidence/<group>"
echo "private/ holds internal links and names. Check that .gitignore still lists testing/*/private/."
