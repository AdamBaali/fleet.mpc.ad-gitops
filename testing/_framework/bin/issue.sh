#!/usr/bin/env bash
# Save a GitHub issue with all its comments as markdown, for reading. Read-only: it never comments or reacts.
# Usage: issue.sh <issue URL | owner/repo#N | N> [out file]      N alone means fleetdm/fleet
# Default output: testing/<project>/private/issue-<N>.md when run inside a project, else stdout.
# The file goes to private/ (git ignored) because issues name customers and people.
# Also saves the parent issue (for a sub-issue) and lists sub-issues, because the parent often holds the real ask.
# Uses the REST API through gh (gh auth login once). REST because some environments block GitHub GraphQL.
set -euo pipefail
ref="${1:?usage: issue.sh <issue URL | owner/repo#N | N> [out file]}"
case "$ref" in
  https://github.com/*) p="${ref#https://github.com/}"; repo="${p%%/issues/*}"; repo="${repo%%/pull/*}"; n="${p##*/}" ;;
  *#*) repo="${ref%%#*}"; n="${ref##*#}" ;;
  *) repo=fleetdm/fleet; n="$ref" ;;
esac
n="${n%%[^0-9]*}"
out="${2:-}"
if [ -z "$out" ]; then case "$PWD" in */testing/*/*|*/testing/*) proj="${PWD%%/testing/*}/testing/$(echo "${PWD#*/testing/}" | cut -d/ -f1)"
  [ "${proj##*/}" != _framework ] && { mkdir -p "$proj/private"; out="$proj/private/issue-$n.md"; } ;; esac; fi
{
  gh api "repos/$repo/issues/$n" --jq '"# \(.title)\n\n\(.html_url) · \(.state) · labels: \([.labels[].name] | join(", ")) · opened \(.created_at[:10])\n\n\(.body // "")\n"'
  gh api --paginate "repos/$repo/issues/$n/comments" --jq '.[] | "\n---\n**\(.user.login)** \(.created_at[:10])\n\n\(.body)\n"'
  # Sub-issue API. Both calls fail quietly on issues without a parent or children, and on hosts without the API.
  if parent=$(gh api "repos/$repo/issues/$n/parent" --jq '.number' 2>/dev/null) && [ -n "$parent" ]; then
    echo; echo "---"; echo "# Parent issue"; echo
    gh api "repos/$repo/issues/$parent" --jq '"## \(.title)\n\n\(.html_url) · \(.state) · labels: \([.labels[].name] | join(", "))\n\n\(.body // "")\n"'
    gh api --paginate "repos/$repo/issues/$parent/comments" --jq '.[] | "\n---\n**\(.user.login)** \(.created_at[:10])\n\n\(.body)\n"'
  fi
  subs=$(gh api "repos/$repo/issues/$n/sub_issues" --jq '.[] | "- #\(.number) \(.title) (\(.state))"' 2>/dev/null || true)
  [ -n "$subs" ] && { echo; echo "---"; echo "# Sub-issues"; echo; echo "$subs"; }
} > "${out:-/dev/stdout}"
[ -n "$out" ] && echo "$out ($(grep -c '^---$' "$out") comments)"
