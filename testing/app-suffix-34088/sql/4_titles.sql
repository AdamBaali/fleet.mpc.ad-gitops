-- =====================================================================
-- 4_titles.sql: trim ".app" from software title names
--
-- Mutating. Independent of 2_plan.sql and 3_apply_batch.sql, and can run
-- on its own. It makes the same change as the contributor API call
-- PATCH /api/v1/fleet/software/titles/:id/name, for every title at once,
-- with the same limit: only titles with a bundle ID
-- (UpdateSoftwareTitleName in server/datastore/mysql/software_titles.go).
--
-- Why titles need this: a title is shared by all versions of an app, and
-- software ingestion never renames an existing title. The Fleet-maintained
-- app job renames titles of catalog apps, but not Firefox, whose bundle ID
-- is shared with Firefox ESR.
--
-- Titles have no checksum, so a rename is a plain UPDATE. Titles without a
-- bundle ID are left alone and listed: ingestion finds those by name, so a
-- host that still sends the ".app" name would create a second title.
--
-- Admin display names (software_title_display_names) are left alone.
-- =====================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS zz_app_suffix_bak_titles (
  id   INT UNSIGNED NOT NULL PRIMARY KEY,
  name VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO zz_app_suffix_bak_titles (id, name)
SELECT id, name FROM software_titles
WHERE source = 'apps' AND name LIKE '%.app' AND CHAR_LENGTH(name) > 4
  AND bundle_identifier <> '';

UPDATE software_titles t
SET t.name = LEFT(t.name, CHAR_LENGTH(t.name) - 4)
WHERE t.source = 'apps' AND t.name LIKE '%.app' AND CHAR_LENGTH(t.name) > 4
  AND t.bundle_identifier <> '';

-- Titles left alone because they have no bundle ID. Expected: empty, or a
-- short list to look at by hand.
SELECT t.id, t.name AS title_without_bundle_id
FROM software_titles t
WHERE t.source = 'apps' AND t.name LIKE '%.app' AND CHAR_LENGTH(t.name) > 4
  AND COALESCE(t.bundle_identifier, '') = '';

SELECT COUNT(*) AS titles_still_ending_in_app
FROM software_titles
WHERE source = 'apps' AND name LIKE '%.app' AND CHAR_LENGTH(name) > 4;

-- To undo:
--   UPDATE software_titles t JOIN zz_app_suffix_bak_titles b ON b.id = t.id SET t.name = b.name;
