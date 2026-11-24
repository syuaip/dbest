-- PostgreSQL Foreign Key Nullability Check
-- Checks that foreign key columns are NOT NULL

WITH fk_columns AS (
    SELECT DISTINCT
        kcu.table_schema,
        kcu.table_name,
        kcu.column_name,
        tc.constraint_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema NOT IN ('pg_catalog', 'information_schema')
),
fk_nullability AS (
    SELECT
        fk.table_schema,
        fk.table_name,
        fk.column_name,
        fk.constraint_name,
        c.is_nullable
    FROM fk_columns fk
    JOIN information_schema.columns c
        ON c.table_schema = fk.table_schema
        AND c.table_name = fk.table_name
        AND c.column_name = fk.column_name
)
SELECT
    'FK Nullability - ' || table_schema || '.' || table_name || '.' || column_name AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN is_nullable = 'YES' THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN is_nullable = 'YES' THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CASE
        WHEN is_nullable = 'YES' THEN 'NULLABLE'
        ELSE 'NOT NULL'
    END AS current_value,
    'NOT NULL' AS default_value,
    CASE
        WHEN is_nullable = 'YES' THEN table_schema || '.' || table_name || '.' || column_name || ' - nullable foreign key column (constraint: ' || constraint_name || ')'
        ELSE table_schema || '.' || table_name || '.' || column_name || ' - foreign key nullability check passed'
    END AS message
FROM fk_nullability;
