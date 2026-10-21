-- =====================================================================
-- 4_titles.sql: trim ".app" from software title names
--
-- Mutating. Independent of 2_plan.sql and 3_apply_batch.sql, and can run
-- on its own. It does the same as the contributor API call
-- PATCH /api/v1/fleet/software/titles/:id/name, for every title at once.
--
-- Why titles need this: a title is shared by all versions of an app and
-- ingestion never renames an existing title, so a ".app" title name stays
-- after every version under it is fixed.
--
-- Titles have no checksum, so a rename is a plain UPDATE. The only guard
-- is the unique key: a title with no bundle ID, application ID or upgrade
-- code is identified by its name, and renaming it could clash with an
-- existing title. Those are skipped and listed.
--
-- Admin display names (software_title_display_names) are left alone.
-- =====================================================================

CREATE TABLE IF NOT EXISTS zz_app_suffix_bak_titles (
  id   INT UNSIGNED NOT NULL PRIMARY KEY,
  name VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO zz_app_suffix_bak_titles (id, name)
SELECT id, name FROM software_titles
WHERE source = 'apps' AND name LIKE '%.app' AND CHAR_LENGTH(name) > 4;

-- Titles the guard skips. Expected: empty, or a short list to rename by
-- hand after a look.
SELECT t.id, t.name AS skipped_title
FROM software_titles t
WHERE t.source = 'apps' AND t.name LIKE '%.app' AND CHAR_LENGTH(t.name) > 4
  AND t.bundle_identifier IS NULL AND t.application_id IS NULL
  AND NULLIF(t.upgrade_code, '') IS NULL
  AND EXISTS (SELECT 1 FROM (SELECT unique_identifier, source, extension_for FROM software_titles) x
              WHERE x.unique_identifier = LEFT(t.name, CHAR_LENGTH(t.name) - 4)
                AND x.source = t.source AND x.extension_for = t.extension_for);

UPDATE software_titles t
SET t.name = LEFT(t.name, CHAR_LENGTH(t.name) - 4)
WHERE t.source = 'apps' AND t.name LIKE '%.app' AND CHAR_LENGTH(t.name) > 4
  AND (t.bundle_identifier IS NOT NULL OR t.application_id IS NOT NULL
       OR NULLIF(t.upgrade_code, '') IS NOT NULL
       OR NOT EXISTS (SELECT 1 FROM (SELECT unique_identifier, source, extension_for FROM software_titles) x
                      WHERE x.unique_identifier = LEFT(t.name, CHAR_LENGTH(t.name) - 4)
                        AND x.source = t.source AND x.extension_for = t.extension_for));

SELECT COUNT(*) AS titles_still_ending_in_app
FROM software_titles
WHERE source = 'apps' AND name LIKE '%.app' AND CHAR_LENGTH(name) > 4;

-- To undo:
--   UPDATE software_titles t JOIN zz_app_suffix_bak_titles b ON b.id = t.id SET t.name = b.name;
