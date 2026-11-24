-- MySQL Trigger Check
-- Identifies tables with triggers defined

SELECT
    'Trigger Check' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN t.TRIGGER_NAME IS NOT NULL THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN t.TRIGGER_NAME IS NOT NULL THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CASE
        WHEN t.TRIGGER_NAME IS NOT NULL
            THEN CONCAT(t.TRIGGER_NAME, ' (', t.ACTION_TIMING, ' ', t.EVENT_MANIPULATION, ')')
        ELSE 'No triggers'
    END AS current_value,
    'No triggers' AS default_value,
    CASE
        WHEN t.TRIGGER_NAME IS NOT NULL
            THEN CONCAT(t.EVENT_OBJECT_SCHEMA, '.', t.EVENT_OBJECT_TABLE,
                        ' has trigger: ', t.TRIGGER_NAME,
                        ' - consider event-driven architecture')
        ELSE CONCAT(tbl.TABLE_SCHEMA, '.', tbl.TABLE_NAME, ' - trigger check passed')
    END AS message
FROM information_schema.TABLES tbl
LEFT JOIN information_schema.TRIGGERS t
    ON tbl.TABLE_SCHEMA = t.EVENT_OBJECT_SCHEMA
    AND tbl.TABLE_NAME = t.EVENT_OBJECT_TABLE
WHERE tbl.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND tbl.TABLE_TYPE = 'BASE TABLE'
ORDER BY
    CASE WHEN t.TRIGGER_NAME IS NOT NULL THEN 0 ELSE 1 END,
    tbl.TABLE_SCHEMA, tbl.TABLE_NAME;
