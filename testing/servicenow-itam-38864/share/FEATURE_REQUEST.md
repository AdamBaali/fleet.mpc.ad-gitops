# Feature request and issue comments (drafts, not posted)

Template: `.github/ISSUE_TEMPLATE/feature-request.md` on fleetdm/fleet `main` (fetched 2026-10-19). Labels: `:product`, `customer-rosner` (the label already on #38864, #54912 and #54914; confirm before filing). Gong snippet: none yet.

Install date and publisher are already filed (#54912, #54914), as are the connector (#38864) and extension hosting (#31036). The one gap our lab work found that no issue covers is below.

---

**Title options**

1. Reports: cap stored results per host, so reports with many rows per host work across a fleet
2. Store every row per host for reports that return one row per app or package
3. Report cap that scales with host count for multi-row reports

- [ ] Unpacked: TODO: Product Designer checks this box when the request goes through "Unpacking the why": https://fleetdm.com/handbook/product-design#unpacking-the-why
- [ ] Gong snippet: TODO

### Interpretation _(optional)_

**How do you interpret the customer's words?**

The customer needs every app on every host in ServiceNow, hourly, with publisher and install date, for an audit. Until #38864, #54912, and #54914 ship, the way to get there is custom reports that collect the missing fields, read through `GET /api/v1/fleet/reports/:id/report` by a script. Those reports return one row per app or package, not one row per host. Other customers building CMDB, license, or compliance exports hit the same shape: inventory-style reports with many rows per host.

**What's Fleet missing?**

Fleet caps stored results per report, not per host. `report_cap` defaults to 1,000 rows for the whole report. Fleet 4.93.0 raises it to the host count when that's higher, which fixes reports with one row per host only. A report with 150 rows per host on 2,000 hosts needs 300,000 rows.

Today the admin has to:
- Guess one global `report_cap` that applies to every report on the instance, so raising it for one inventory report raises it for all.
- Notice clipping. When a report is full, Fleet keeps updating hosts already in it and skips new hosts, so the newest hosts are the ones missing from the export.
- Or send results to a log destination, which needs infrastructure many customers don't run, and moves the data out of the API they already use.

**What does the customer's ideal workflow look like?**

1. The admin adds a report in GitOps or the UI and sets a per-host row limit on that report (for example, `max_rows_per_host: 2000`), or Fleet sizes stored results per host by default.
2. Fleet stores the latest snapshot for every host in scope, up to that limit per host. The report's total grows with the number of hosts, not with a global setting.
3. When a host returns more rows than the limit, Fleet stores the first rows, marks that host's result as truncated, and shows it in the report and in the API response.
4. A script reads `GET /api/v1/fleet/reports/:id/report` with `page` and `per_page` every hour and gets every host's rows, including hosts enrolled since the last run.

---

## Comment for #54912 (install date)

From a lab stopgap for this request. Sources per OS that need no fleetd change, all native osquery tables:

- macOS: `/Library/Receipts/InstallHistory.plist` (through `plist`) keeps every install with a date, including App Store and pkg installs, and survives updates. It misses apps dragged into Applications. Spotlight `kMDItemDateAdded` (`mdls`) and bundle `btime` (`file`) cover those, but can move on update.
- Windows: `programs.install_date` (day precision, sometimes empty). The Uninstall key's write time (`registry`, `type = 'subkey'`, `mtime`) fills the empty ones, and an upgrade or repair rewrites it.
- Linux RPM: `rpm_packages.install_time`.
- Linux DEB: dpkg keeps no install time. The first `install` line in `/var/log/dpkg.log*` (including rotated `.gz` files) is the first install within log retention. The `/var/lib/dpkg/info/<pkg>.list` mtime is the last change.

Labeling each date with its source let the export show proxies as proxies. Lab results with ground-truth installs land on 2026-10-20 and will be added here.

## Comment for #54914 (publisher)

From the same stopgap. The native osquery `signature` table already returns the signing certificate name in `authority` (for example, "Developer ID Application: Example Inc (TEAMID1234)"). With `hash_resources = 0` it skips hashing the bundle, so no `codesign` table change or Team ID mapping is needed for Developer ID apps. Two cases need a fallback: App Store apps are re-signed by Apple, and unsigned apps have no authority. `NSHumanReadableCopyright` in Info.plist names the company in both cases.

Windows and RPM publishers are stored as `vendor` but `GET /api/v1/fleet/hosts/:id/software` doesn't return them. Returning `vendor` there closes those two platforms without new collection.

## Comment for #31036 (extension hosting)

Another case for this: a stopgap for #38864 needed an osquery extension on macOS, Windows, and Linux. `agent_options.extensions` needs a self-hosted TUF server, so the extension was deployed with a policy plus `run_script` instead. The script downloads a binary pinned by commit and SHA-256 and adds it to osquery's default `extensions.load`. Orbit's own `extensions.load` couldn't be used, because orbit empties it when `agent_options.extensions` is unset. Fleet-hosted extensions would remove the script, the pinning, and the restart handling from every customer that needs one.
