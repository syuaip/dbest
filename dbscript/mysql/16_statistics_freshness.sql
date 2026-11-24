-- MySQL Statistics Freshness Check
-- Checks when tables were last analyzed (ANALYZE TABLE)
-- Uses information_schema.TABLES UPDATE_TIME as proxy for statistics freshness

SELECT
    'Statistics Freshness' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN t.UPDATE_TIME IS NULL AND t.CREATE_TIME < DATE_SUB(NOW(), INTERVAL 7 DAY)
            THEN 'FLAGGED'
        WHEN t.UPDATE_TIME IS NOT NULL AND t.UPDATE_TIME < DATE_SUB(NOW(), INTERVAL 7 DAY)
            THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN t.UPDATE_TIME IS NULL AND t.CREATE_TIME < DATE_SUB(NOW(), INTERVAL 7 DAY)
            THEN 'ADVISORY'
        WHEN t.UPDATE_TIME IS NOT NULL AND t.UPDATE_TIME < DATE_SUB(NOW(), INTERVAL 7 DAY)
            THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CASE
        WHEN t.UPDATE_TIME IS NOT NULL THEN CAST(t.UPDATE_TIME AS CHAR)
        ELSE 'Never analyzed'
    END AS current_value,
    'Within 7 days' AS default_value,
    CASE
        WHEN t.UPDATE_TIME IS NULL AND t.CREATE_TIME < DATE_SUB(NOW(), INTERVAL 7 DAY)
            THEN CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME, ' - stale statistics - never analyzed')
        WHEN t.UPDATE_TIME IS NOT NULL AND t.UPDATE_TIME < DATE_SUB(NOW(), INTERVAL 7 DAY)
            THEN CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME, ' - stale statistics - last updated on ', t.UPDATE_TIME)
        ELSE CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME, ' - statistics freshness check passed')
    END AS message
FROM information_schema.TABLES t
WHERE t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND t.TABLE_TYPE = 'BASE TABLE'
ORDER BY
    CASE
        WHEN t.UPDATE_TIME IS NULL AND t.CREATE_TIME < DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 0
        WHEN t.UPDATE_TIME IS NOT NULL AND t.UPDATE_TIME < DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1
        ELSE 2
    END,
    t.TABLE_SCHEMA, t.TABLE_NAME;
