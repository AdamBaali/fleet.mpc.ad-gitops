<!-- Short update for the customer thread now, from Adam. Not sent. Reply in the 12 Oct thread. -->
Hi, a quick update on the `.app` cleanup. The scripts are rewritten, and we've run them against Fleet 4.90.3 and 4.93.1 in a test database. They go to our engineers for review today, and I'll send them once that's done.

Plan to run them after your 4.93 upgrade:
- The upgrade runs Fleet's migration that merges the duplicate giflib rows, as part of the normal database migration.
- The first script is read-only and reports what's left, so its numbers only make sense after the upgrade.

You were right about Firefox. Fleet's `macos_firefox` query creates the `Firefox.app` name itself, so the scripts leave Firefox alone. A correction to what we sent on the 12th: #50077 and #50090 don't change that name. #50090 fixes Firefox 153.0 being matched to CVEs it's patched for, and that fix ships in 4.94.0, not 4.93. #50077 is about Windows titles. We're filing a separate bug for the macOS name, and I'll share the link.
