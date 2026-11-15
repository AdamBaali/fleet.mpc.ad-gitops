#!/usr/bin/env bash
# Look up a customer label in the confidential repo's GitHub labels, where the label's entry holds the customer's name.
# Usage: customer.sh <label> [repo]       repo defaults to fleetdm/confidential
# Prints the matching labels with their descriptions. Read-only. The output names a customer: keep it in private/ only,
# never in a committed file, a commit message, or a PR.
set -euo pipefail
label="${1:?usage: customer.sh <label> [repo]}"; repo="${2:-fleetdm/confidential}"
# All labels, then match: the exact label first, then any label or description that contains the part after "customer-".
gh api --paginate "repos/$repo/labels?per_page=100" --jq '.[] | [.name, (.description // "")] | @tsv' \
  | awk -F'\t' -v l="$label" -v k="${label#customer-}" '
      tolower($1) == tolower(l) { print "exact\t" $0; found = 1; next }
      index(tolower($1 "\t" $2), tolower(k)) { near = near "near\t" $0 "\n" }
      END { printf "%s", near; if (!found && near == "") { print "no label matches " l > "/dev/stderr"; exit 1 } }'
