<!-- Short update for the customer thread now, from Adam. Not sent. Reply in the 12 Oct thread (link in private/). -->
Hi, a quick update on the `.app` cleanup. The scripts are rewritten, and we've run them against Fleet 4.90.3 and 4.93.1 in a test database. They go to our engineers for review today, and I'll send them once that's done.

Plan to run them after your 4.93 upgrade:
- The upgrade runs Fleet's migration that merges the duplicate giflib rows, as part of the normal database migration.
- The first script is read-only and reports what's left, so its numbers only make sense after the upgrade.

You were right about Firefox. Fleet's `macos_firefox` query creates the `Firefox.app` name itself, so the scripts leave Firefox alone. We filed a bug for a product fix: https://github.com/fleetdm/fleet/issues/56168

A correction to what we sent on the 12th: neither of these changes the macOS Firefox name.
- https://github.com/fleetdm/fleet/issues/50090 fixes Firefox 153.0 being matched to CVEs it's patched for. That fix ships in 4.94.0, not 4.93.
- https://github.com/fleetdm/fleet/issues/50077 is about Windows titles.
