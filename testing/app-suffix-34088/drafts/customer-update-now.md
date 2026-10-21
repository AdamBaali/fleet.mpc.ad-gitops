<!-- Short update for the customer thread now, from Adam. Not sent. Reply in the 12 Oct thread. -->
Hi, quick update on the `.app` cleanup. The scripts are rewritten and tested on 4.90.3 and 4.93.1, and they're going to our engineers for review today. I'll send them once that's done, this week or early next.

Plan to run them after your 4.93 upgrade, not before:
- The upgrade runs Fleet's migration that merges the duplicate giflib rows, with no manual steps.
- The first script is read only and reports what's left, so its numbers are only useful after the upgrade.

You were right about Firefox: Fleet's `macos_firefox` query creates `Firefox.app` itself, so the scripts leave Firefox alone and we're filing a bug for a product fix. I'll share the link.
