-- MySQL Search Column Nullability Check
-- Identifies nullable columns used in non-primary-key indexes

SELECT
    'Search Column Nullability' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN c.IS_NULLABLE = 'YES' THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN c.IS_NULLABLE = 'YES' THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CASE
        WHEN c.IS_NULLABLE = 'YES' THEN 'NULLABLE'
        ELSE 'NOT NULL'
    END AS current_value,
    'NOT NULL' AS default_value,
    CASE
        WHEN c.IS_NULLABLE = 'YES'
            THEN CONCAT(s.TABLE_SCHEMA, '.', s.TABLE_NAME, '.', s.COLUMN_NAME,
                        ' (index: ', s.INDEX_NAME, ') - nullable search column')
        ELSE CONCAT(s.TABLE_SCHEMA, '.', s.TABLE_NAME, '.', s.COLUMN_NAME,
                    ' (index: ', s.INDEX_NAME, ') - search column nullability check passed')
    END AS message
FROM information_schema.STATISTICS s
JOIN information_schema.COLUMNS c
    ON s.TABLE_SCHEMA = c.TABLE_SCHEMA
    AND s.TABLE_NAME = c.TABLE_NAME
    AND s.COLUMN_NAME = c.COLUMN_NAME
WHERE s.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND s.INDEX_NAME != 'PRIMARY'
ORDER BY
    CASE WHEN c.IS_NULLABLE = 'YES' THEN 0 ELSE 1 END,
    s.TABLE_SCHEMA, s.TABLE_NAME, s.INDEX_NAME, s.SEQ_IN_INDEX;
