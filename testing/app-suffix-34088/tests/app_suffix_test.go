package mysql

// Tests for the .app suffix cleanup in testing/app-suffix-34088. Copied into a Fleet checkout
// at server/datastore/mysql by run-db-tests.sh, so it runs against Fleet's real schema and
// ingestion code (UpdateHostSoftware, SyncHostsSoftware). Not meant to be merged into Fleet.

import (
	"context"
	"crypto/md5" //nolint:gosec // matches Fleet's software checksum, not used for security
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/fleetdm/fleet/v4/server/fleet"
	"github.com/fleetdm/fleet/v4/server/test"
	"github.com/stretchr/testify/require"
)

var (
	appSuffixDir = os.Getenv("APP_SUFFIX_DIR") // testing/app-suffix-34088
	appSuffixOut = os.Getenv("APP_SUFFIX_OUT") // folder for the raw SQL output
)

func TestAppSuffix(t *testing.T) {
	if appSuffixDir == "" {
		t.Skip("APP_SUFFIX_DIR not set")
	}
	ds := CreateMySQLDS(t)
	cases := []struct {
		name string
		fn   func(t *testing.T, ds *Datastore)
	}{
		{"C1_SelfHealWhenHostReports", testAppSuffixSelfHeal},
		{"C2_FirefoxComesBack", testAppSuffixFirefoxComesBack},
		{"C3_DiagnoseBuckets", testAppSuffixDiagnose},
		{"C4_CleanupThenIngest", testAppSuffixCleanupThenIngest},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			defer TruncateTables(t, ds)
			c.fn(t, ds)
		})
	}
}

// ---- helpers ---------------------------------------------------------------------------

func app(name, version, bundleID string) fleet.Software {
	return fleet.Software{Name: name, Version: version, Source: "apps", BundleIdentifier: bundleID}
}

func appOpened(name, version, bundleID string, opened time.Time) fleet.Software {
	s := app(name, version, bundleID)
	s.LastOpenedAt = &opened
	return s
}

func newAppSuffixHost(t *testing.T, ds *Datastore, name string, seen time.Time) *fleet.Host {
	h := test.NewHost(t, ds, name, "", name+"key", name+"uuid", time.Now())
	setSeen(t, ds, h.ID, seen)
	return h
}

func setSeen(t *testing.T, ds *Datastore, hostID uint, seen time.Time) {
	_, err := ds.primary.Exec(`INSERT INTO host_seen_times (host_id, seen_time) VALUES (?, ?)
		ON DUPLICATE KEY UPDATE seen_time = VALUES(seen_time)`, hostID, seen)
	require.NoError(t, err)
}

func report(t *testing.T, ds *Datastore, h *fleet.Host, sw ...fleet.Software) {
	_, err := ds.UpdateHostSoftware(context.Background(), h.ID, sw)
	require.NoError(t, err)
}

func softwareIDs(t *testing.T, ds *Datastore, name, version string) []uint {
	var ids []uint
	require.NoError(t, ds.primary.Select(&ids,
		`SELECT id FROM software WHERE BINARY name = ? AND version = ? AND source = 'apps' ORDER BY id`, name, version))
	return ids
}

func oneID(t *testing.T, ds *Datastore, name, version string) uint {
	ids := softwareIDs(t, ds, name, version)
	require.Len(t, ids, 1, "rows named %q %s", name, version)
	return ids[0]
}

func hostLinks(t *testing.T, ds *Datastore, hostID uint) map[string]uint {
	var rows []struct {
		Name    string `db:"name"`
		Version string `db:"version"`
		ID      uint   `db:"id"`
	}
	require.NoError(t, ds.primary.Select(&rows, `SELECT s.name, s.version, s.id FROM host_software hs
		JOIN software s ON s.id = hs.software_id WHERE hs.host_id = ?`, hostID))
	out := map[string]uint{}
	for _, r := range rows {
		out[r.Name+" "+r.Version] = r.ID
	}
	return out
}

func countInt(t *testing.T, ds *Datastore, q string, args ...any) int {
	var n int
	require.NoError(t, ds.primary.Get(&n, q, args...))
	return n
}

// runSQLFile runs a script on one connection, so session variables carry across statements,
// the way the mysql client runs it. SELECT output is written to APP_SUFFIX_OUT/<label>.txt.
// It stops at the first error, like the mysql client without --force, and returns that error.
func runSQLFile(t *testing.T, ds *Datastore, path, label string) (results [][]map[string]string, runErr error) {
	ctx := context.Background()
	raw, err := os.ReadFile(path)
	require.NoError(t, err)

	conn, err := ds.primary.Conn(ctx)
	require.NoError(t, err)
	defer conn.Close()

	var out strings.Builder
	fmt.Fprintf(&out, "# %s\n", filepath.Base(path))
	defer func() {
		if runErr != nil {
			fmt.Fprintf(&out, "\nSTOPPED: %v\n", runErr)
		}
		if appSuffixOut != "" {
			require.NoError(t, os.MkdirAll(appSuffixOut, 0o755))
			require.NoError(t, os.WriteFile(filepath.Join(appSuffixOut, label+".txt"), []byte(out.String()), 0o644))
		}
	}()

	for _, stmt := range splitSQL(string(raw)) {
		head := strings.ToUpper(strings.Fields(stmt)[0])
		if head != "SELECT" {
			res, err := conn.ExecContext(ctx, stmt)
			if err != nil {
				fmt.Fprintf(&out, "\n> %s\n", firstLine(stmt))
				return results, fmt.Errorf("%s: %w", firstLine(stmt), err)
			}
			n, _ := res.RowsAffected()
			fmt.Fprintf(&out, "\n> %s  -- %d rows affected\n", firstLine(stmt), n)
			continue
		}
		rows, err := conn.QueryContext(ctx, stmt)
		if err != nil {
			fmt.Fprintf(&out, "\n> %s\n", firstLine(stmt))
			return results, fmt.Errorf("%s: %w", firstLine(stmt), err)
		}
		set, err := scanAll(rows)
		if err != nil {
			return results, err
		}
		results = append(results, set)
		fmt.Fprintf(&out, "\n> %s\n%s", firstLine(stmt), formatRows(rows, set))
	}
	return results, nil
}

func splitSQL(s string) []string {
	var stmts []string
	var cur strings.Builder
	for _, line := range strings.Split(s, "\n") {
		trim := strings.TrimSpace(line)
		if trim == "" || strings.HasPrefix(trim, "--") {
			continue
		}
		cur.WriteString(line)
		cur.WriteString("\n")
		if strings.HasSuffix(trim, ";") {
			stmts = append(stmts, strings.TrimSuffix(strings.TrimSpace(cur.String()), ";"))
			cur.Reset()
		}
	}
	return stmts
}

func firstLine(stmt string) string {
	return strings.SplitN(strings.TrimSpace(stmt), "\n", 2)[0]
}

func scanAll(rows *sql.Rows) ([]map[string]string, error) {
	defer rows.Close()
	cols, err := rows.Columns()
	if err != nil {
		return nil, err
	}
	var set []map[string]string
	for rows.Next() {
		vals := make([]sql.RawBytes, len(cols))
		ptrs := make([]any, len(cols))
		for i := range vals {
			ptrs[i] = &vals[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return nil, err
		}
		m := map[string]string{}
		for i, c := range cols {
			if vals[i] == nil {
				m[c] = "NULL"
			} else if c == "target_checksum" || c == "checksum" {
				m[c] = fmt.Sprintf("%x", []byte(vals[i]))
			} else {
				m[c] = string(vals[i])
			}
		}
		set = append(set, m)
	}
	return set, rows.Err()
}

func formatRows(_ *sql.Rows, set []map[string]string) string {
	if len(set) == 0 {
		return "(no rows)\n"
	}
	var cols []string
	for c := range set[0] {
		cols = append(cols, c)
	}
	// The map loses the query's column order, so sort for evidence that diffs cleanly.
	sort.Strings(cols)
	var b strings.Builder
	b.WriteString(strings.Join(cols, " | ") + "\n")
	for _, r := range set {
		var v []string
		for _, c := range cols {
			v = append(v, r[c])
		}
		b.WriteString(strings.Join(v, " | ") + "\n")
	}
	return b.String()
}

func sqlPath(name string) string { return filepath.Join(appSuffixDir, "sql", name) }

func syncSoftware(t *testing.T, ds *Datastore) {
	ctx := context.Background()
	require.NoError(t, ds.SyncHostsSoftware(ctx, time.Now()))
	require.NoError(t, ds.CleanupSoftwareTitles(ctx))
	require.NoError(t, ds.SyncHostsSoftwareTitles(ctx, time.Now()))
}

// ---- C1 --------------------------------------------------------------------------------

// A host that reports the corrected name drops its link to the ".app" row in the same
// report, and the vulnerabilities cron then deletes the row. The title keeps its old name.
func testAppSuffixSelfHeal(t *testing.T, ds *Datastore) {
	now := time.Now()
	h := newAppSuffixHost(t, ds, "heal", now)
	report(t, ds, h, app("Slack.app", "4.40", "com.tinyspeck.slackmacgap"))
	stale := oneID(t, ds, "Slack.app", "4.40")
	syncSoftware(t, ds)

	report(t, ds, h, app("Slack", "4.40", "com.tinyspeck.slackmacgap"))
	links := hostLinks(t, ds, h.ID)
	require.NotContains(t, links, "Slack.app 4.40")
	require.Contains(t, links, "Slack 4.40")

	syncSoftware(t, ds)
	require.Zero(t, countInt(t, ds, `SELECT COUNT(*) FROM software WHERE id = ?`, stale), "orphaned .app row deleted by SyncHostsSoftware")

	var title string
	require.NoError(t, ds.primary.Get(&title, `SELECT name FROM software_titles WHERE bundle_identifier = 'com.tinyspeck.slackmacgap'`))
	require.Equal(t, "Slack.app", title, "ingestion never renames an existing title")
}

// ---- C2 --------------------------------------------------------------------------------

// Fleet's macos_firefox query sends "Firefox.app". If the ".app" row is merged away, the next
// report from a host with parse_ini brings it back. This is why the plan excludes Firefox.
func testAppSuffixFirefoxComesBack(t *testing.T, ds *Datastore) {
	now := time.Now()
	fleetd := newAppSuffixHost(t, ds, "fleetd", now)
	plain := newAppSuffixHost(t, ds, "plain", now)
	report(t, ds, fleetd, app("Firefox.app", "140.0", "org.mozilla.firefox"))
	report(t, ds, plain, app("Firefox", "140.0", "org.mozilla.firefox"))
	require.Len(t, softwareIDs(t, ds, "Firefox.app", "140.0"), 1)
	require.Len(t, softwareIDs(t, ds, "Firefox", "140.0"), 1, "two version rows for one app, split by host setup")

	// Merge by hand: move the fleetd host's link and delete the .app row.
	firefox := oneID(t, ds, "Firefox", "140.0")
	stale := oneID(t, ds, "Firefox.app", "140.0")
	_, err := ds.primary.Exec(`UPDATE host_software SET software_id = ? WHERE software_id = ?`, firefox, stale)
	require.NoError(t, err)
	_, err = ds.primary.Exec(`DELETE FROM software WHERE id = ?`, stale)
	require.NoError(t, err)

	report(t, ds, fleetd, app("Firefox.app", "140.0", "org.mozilla.firefox"))
	require.Len(t, softwareIDs(t, ds, "Firefox.app", "140.0"), 1, "the .app row is back after one report")
	require.Contains(t, hostLinks(t, ds, fleetd.ID), "Firefox.app 140.0")
}

// ---- C3 and C4 shared fixture ----------------------------------------------------------

type fixture struct {
	fleetdOn, plainOn, legacyOn, off1, off2 *fleet.Host
	opened                                  time.Time
}

// Builds the state the customer has: ".app" rows left from a 2025 detail query override, on
// hosts that have been offline since, next to correctly named rows from hosts that report today.
func buildFixture(t *testing.T, ds *Datastore) fixture {
	now := time.Now()
	old := now.Add(-60 * 24 * time.Hour)
	f := fixture{opened: now.Add(-2 * time.Hour).Truncate(time.Second)}

	// The override era: every host sent ".app" names.
	f.off1 = newAppSuffixHost(t, ds, "off1", old)
	f.off2 = newAppSuffixHost(t, ds, "off2", old)
	f.legacyOn = newAppSuffixHost(t, ds, "legacyon", old)
	report(t, ds, f.off1,
		app("Slack.app", "4.40", "com.tinyspeck.slackmacgap"),
		appOpened("Zoom.app", "6.0", "us.zoom.xos", f.opened),
		app("Notion.app", "3.0", "notion.id"),
		app("Firefox.app", "140.0", "org.mozilla.firefox"),
	)
	report(t, ds, f.off2, appOpened("Zoom.app", "6.0", "us.zoom.xos", f.opened))
	report(t, ds, f.legacyOn, app("Slack.app", "4.40", "com.tinyspeck.slackmacgap"))
	orphanHost := newAppSuffixHost(t, ds, "gone", old)
	report(t, ds, orphanHost, app("Old.app", "1.0", "com.example.old"))
	report(t, ds, orphanHost) // the host removed the app: Old.app keeps no links

	// Today: Fleet trims ".app" for everything except Firefox on fleetd hosts.
	f.fleetdOn = newAppSuffixHost(t, ds, "fleetdon", now)
	f.plainOn = newAppSuffixHost(t, ds, "plainon", now)
	report(t, ds, f.fleetdOn, app("Firefox.app", "140.0", "org.mozilla.firefox"),
		app("Slack", "4.40", "com.tinyspeck.slackmacgap"),
		app("Zoom", "6.0", "us.zoom.xos"))
	report(t, ds, f.plainOn, app("Firefox", "140.0", "org.mozilla.firefox"))

	// off2 also has the corrected Zoom row from a later report, so it is linked to both.
	_, err := ds.primary.Exec(`INSERT INTO host_software (host_id, software_id, last_opened_at) VALUES (?, ?, ?)`,
		f.off2.ID, oneID(t, ds, "Zoom", "6.0"), f.opened.Add(-24*time.Hour))
	require.NoError(t, err)

	// legacyOn is online again but its software has not changed since, so it still sends the
	// ".app" name. Mark it seen now.
	setSeen(t, ds, f.legacyOn.ID, now)
	return f
}

func testAppSuffixDiagnose(t *testing.T, ds *Datastore) {
	f := buildFixture(t, ds)

	// A row created before 4.76.0, when the checksum put the name first (fleetdm/fleet#52314),
	// and the second row a host created for the same app after the upgrade.
	legacy := md5.Sum([]byte(strings.Join([]string{"Legacy Tool", "1.0", "apps", "", "", "", "", "", ""}, "\x00")))
	res0, err := ds.primary.Exec(`INSERT INTO software (name, version, source, bundle_identifier, checksum)
		VALUES ('Legacy Tool', '1.0', 'apps', '', ?)`, legacy[:])
	require.NoError(t, err)
	legacyID, err := res0.LastInsertId()
	require.NoError(t, err)
	_, err = ds.primary.Exec(`INSERT INTO host_software (host_id, software_id) VALUES (?, ?)`, f.off1.ID, legacyID)
	require.NoError(t, err)
	report(t, ds, f.plainOn, app("Firefox", "140.0", "org.mozilla.firefox"), app("Legacy Tool", "1.0", ""))
	require.Len(t, softwareIDs(t, ds, "Legacy Tool", "1.0"), 2, "the pre-4.76 row duplicated")

	res, err := runSQLFile(t, ds, sqlPath("1_diagnose.sql"), "C3-diagnose")
	require.NoError(t, err)

	// res[0] CHECK 1, res[1] CHECK 2, res[2] CHECK 3, res[3] CHECK 4, res[4] CHECK 5...
	buckets := map[string]string{}
	for _, r := range res[1] {
		buckets[r["bucket"]+"/firefox="+r["is_firefox"]] = r["software_rows"]
	}
	require.Equal(t, map[string]string{
		"orphaned/firefox=0":     "1", // Old.app
		"offline_only/firefox=0": "2", // Zoom.app, Notion.app
		"recurring/firefox=0":    "1", // Slack.app, still linked to legacyon, which is online
		"recurring/firefox=1":    "1", // Firefox.app, sent today by fleetdon
	}, buckets)
	require.Equal(t, "1", res[3][0]["legacy_pre_4_76"], "the pre-4.76 row is recognized")
	require.Equal(t, "0", res[3][0]["unexplained"], "every other stored checksum matches the formula")

	// res[6] is CHECK 7: the pre-4.76 pair is one duplicate group.
	require.Equal(t, []map[string]string{{"source": "apps", "duplicate_groups": "1", "rows_in_groups": "2"}}, res[6])
}

func testAppSuffixCleanupThenIngest(t *testing.T, ds *Datastore) {
	f := buildFixture(t, ds)
	notionStale := oneID(t, ds, "Notion.app", "3.0")
	zoomStale := oneID(t, ds, "Zoom.app", "6.0")
	zoom := oneID(t, ds, "Zoom", "6.0")
	firefoxApp := oneID(t, ds, "Firefox.app", "140.0")
	slackApp := oneID(t, ds, "Slack.app", "4.40")
	// A path on the stale row that the survivor already has, to check paths are not doubled.
	_, err := ds.primary.Exec(`INSERT INTO host_software_installed_paths (host_id, software_id, installed_path)
		VALUES (?, ?, '/Applications/zoom.us.app'), (?, ?, '/Applications/zoom.us.app')`,
		f.off2.ID, zoomStale, f.off2.ID, zoom)
	require.NoError(t, err)

	res, err := runSQLFile(t, ds, sqlPath("2_plan.sql"), "C4-plan")
	require.NoError(t, err)
	actions := map[string]string{}
	for _, r := range res[0] {
		actions[r["action"]] = r["software_rows"]
	}
	require.Equal(t, map[string]string{"merge": "1", "rename": "1"}, actions, "Zoom.app merges, Notion.app renames; Slack.app and Firefox.app are left")

	for i := 0; ; i++ {
		require.Less(t, i, 5)
		res, err = runSQLFile(t, ds, sqlPath("3_apply_batch.sql"), fmt.Sprintf("C4-apply-%d", i+1))
		require.NoError(t, err)
		if countInt(t, ds, `SELECT COUNT(*) FROM zz_app_suffix_map WHERE state = 'pending'`) == 0 {
			break
		}
	}
	_, err = runSQLFile(t, ds, sqlPath("4_titles.sql"), "C4-titles")
	require.NoError(t, err)

	// Merge: Zoom.app is gone, both offline hosts point at Zoom, off2 kept the newer timestamp,
	// and its path is not doubled.
	require.Zero(t, countInt(t, ds, `SELECT COUNT(*) FROM software WHERE id = ?`, zoomStale))
	require.Equal(t, zoom, hostLinks(t, ds, f.off1.ID)["Zoom 6.0"])
	require.Equal(t, zoom, hostLinks(t, ds, f.off2.ID)["Zoom 6.0"])
	var lastOpened time.Time
	require.NoError(t, ds.primary.Get(&lastOpened, `SELECT last_opened_at FROM host_software WHERE host_id = ? AND software_id = ?`, f.off2.ID, zoom))
	require.True(t, lastOpened.Equal(f.opened), "newer last_opened_at carried over: got %v want %v", lastOpened, f.opened)
	require.Equal(t, 1, countInt(t, ds, `SELECT COUNT(*) FROM host_software_installed_paths WHERE host_id = ? AND software_id = ?`, f.off2.ID, zoom))

	// Rename: same id, new name, and the checksum Fleet's Go code computes for that name.
	require.Equal(t, notionStale, oneID(t, ds, "Notion", "3.0"))
	var stored []byte
	require.NoError(t, ds.primary.Get(&stored, `SELECT checksum FROM software WHERE id = ?`, notionStale))
	want, err := app("Notion", "3.0", "notion.id").ComputeRawChecksum()
	require.NoError(t, err)
	require.Equal(t, want, stored, "SQL checksum equals Software.ComputeRawChecksum")

	// Left alone: Firefox (excluded) and Slack.app (an online host still links it).
	require.Equal(t, firefoxApp, oneID(t, ds, "Firefox.app", "140.0"))
	require.Equal(t, slackApp, oneID(t, ds, "Slack.app", "4.40"))

	// Now hosts report through Fleet's real ingestion. Nothing new may be created.
	before := countInt(t, ds, `SELECT COUNT(*) FROM software`)
	setSeen(t, ds, f.off1.ID, time.Now())
	report(t, ds, f.off1,
		app("Slack", "4.40", "com.tinyspeck.slackmacgap"),
		app("Zoom", "6.0", "us.zoom.xos"),
		app("Notion", "3.0", "notion.id"),
		app("Firefox.app", "140.0", "org.mozilla.firefox"))
	newHost := newAppSuffixHost(t, ds, "brandnew", time.Now())
	report(t, ds, newHost, app("Notion", "3.0", "notion.id"))
	require.Equal(t, before, countInt(t, ds, `SELECT COUNT(*) FROM software`), "no software rows created by later reports")
	require.Equal(t, notionStale, hostLinks(t, ds, newHost.ID)["Notion 3.0"], "a new host finds the renamed row by checksum")

	_, err = runSQLFile(t, ds, sqlPath("5_verify.sql"), "C4-verify")
	require.NoError(t, err)
	require.Zero(t, countInt(t, ds, `SELECT COUNT(*) FROM (SELECT 1 FROM software WHERE source = 'apps'
		GROUP BY name, version, bundle_identifier HAVING COUNT(*) > 1) d`), "no duplicate versions")

	// Titles: every bundle title trimmed, including Firefox (titles are never renamed back).
	require.Zero(t, countInt(t, ds, `SELECT COUNT(*) FROM software_titles WHERE name LIKE '%.app'`))

	// The vulnerabilities cron then cleans up as usual.
	syncSoftware(t, ds)
	require.Equal(t, 2, countInt(t, ds, `SELECT hosts_count FROM software_host_counts
		WHERE software_id = ? AND team_id = 0 AND global_stats = 1`, notionStale), "off1 and brandnew count under Notion")
}
