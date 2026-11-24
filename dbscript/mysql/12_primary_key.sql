-- MySQL Primary Key Check
-- Identifies tables missing primary keys or with composite primary keys

SELECT
    'Primary Key Check' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN t.TABLE_NAME IS NOT NULL AND pk.CONSTRAINT_NAME IS NULL THEN 'FLAGGED'
        WHEN pk.column_count > 1 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN t.TABLE_NAME IS NOT NULL AND pk.CONSTRAINT_NAME IS NULL THEN 'CRITICAL'
        WHEN pk.column_count > 1 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CASE
        WHEN pk.CONSTRAINT_NAME IS NULL THEN 'No primary key'
        WHEN pk.column_count > 1 THEN CONCAT('Composite PK (', pk.column_count, ' columns)')
        ELSE 'Single-column PK'
    END AS current_value,
    'Single-column primary key' AS default_value,
    CASE
        WHEN pk.CONSTRAINT_NAME IS NULL
            THEN CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME, ' - missing primary key')
        WHEN pk.column_count > 1
            THEN CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME, ' - composite primary key (', pk.pk_columns, ') - single-column primary key recommended')
        ELSE CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME, ' - primary key check passed')
    END AS message
FROM information_schema.TABLES t
LEFT JOIN (
    SELECT
        tc.TABLE_SCHEMA,
        tc.TABLE_NAME,
        tc.CONSTRAINT_NAME,
        COUNT(kcu.COLUMN_NAME) AS column_count,
        GROUP_CONCAT(kcu.COLUMN_NAME ORDER BY kcu.ORDINAL_POSITION) AS pk_columns
    FROM information_schema.TABLE_CONSTRAINTS tc
    JOIN information_schema.KEY_COLUMN_USAGE kcu
        ON tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
        AND tc.TABLE_NAME = kcu.TABLE_NAME
        AND tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
    GROUP BY tc.TABLE_SCHEMA, tc.TABLE_NAME, tc.CONSTRAINT_NAME
) pk ON t.TABLE_SCHEMA = pk.TABLE_SCHEMA AND t.TABLE_NAME = pk.TABLE_NAME
WHERE t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND t.TABLE_TYPE = 'BASE TABLE'
ORDER BY
    CASE WHEN pk.CONSTRAINT_NAME IS NULL THEN 0 WHEN pk.column_count > 1 THEN 1 ELSE 2 END,
    t.TABLE_SCHEMA, t.TABLE_NAME;
