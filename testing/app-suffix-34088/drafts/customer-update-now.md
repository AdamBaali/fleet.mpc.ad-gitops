<!-- Short update for the customer thread now, from Adam. Not sent. Reply in the 12 Oct thread. -->
Hi, a quick update on the `.app` cleanup. The scripts are rewritten, and we've run them against Fleet 4.90.3 and 4.93.1 in a test database. They go to our engineers for review today, and I'll send them once that's done.

Plan to run them after your 4.93 upgrade:
- The upgrade runs Fleet's migration that merges the duplicate giflib rows, with no manual steps.
- The first script is read-only and reports what's left, so its numbers only make sense after the upgrade.

You were right about Firefox. Fleet's `macos_firefox` query creates the `Firefox.app` name itself, so the scripts leave Firefox alone. We're filing a bug for a product fix, and I'll share the link.
