-- MySQL Foreign Key Nullability Check
-- Identifies foreign key columns that allow NULL values

SELECT
    'Foreign Key Nullability' AS check_name,
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
            THEN CONCAT(kcu.TABLE_SCHEMA, '.', kcu.TABLE_NAME, '.', kcu.COLUMN_NAME, ' - nullable foreign key column')
        ELSE CONCAT(kcu.TABLE_SCHEMA, '.', kcu.TABLE_NAME, '.', kcu.COLUMN_NAME, ' - foreign key nullability check passed')
    END AS message
FROM information_schema.KEY_COLUMN_USAGE kcu
JOIN information_schema.TABLE_CONSTRAINTS tc
    ON kcu.TABLE_SCHEMA = tc.TABLE_SCHEMA
    AND kcu.TABLE_NAME = tc.TABLE_NAME
    AND kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
JOIN information_schema.COLUMNS c
    ON kcu.TABLE_SCHEMA = c.TABLE_SCHEMA
    AND kcu.TABLE_NAME = c.TABLE_NAME
    AND kcu.COLUMN_NAME = c.COLUMN_NAME
WHERE tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
  AND kcu.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
ORDER BY
    CASE WHEN c.IS_NULLABLE = 'YES' THEN 0 ELSE 1 END,
    kcu.TABLE_SCHEMA, kcu.TABLE_NAME, kcu.COLUMN_NAME;
