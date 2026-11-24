-- PostgreSQL Search Column Nullability Check
-- Checks that columns in non-primary-key indexes are NOT NULL

WITH indexed_columns AS (
    SELECT DISTINCT
        n.nspname AS schema_name,
        t.relname AS table_name,
        a.attname AS column_name,
        i.relname AS index_name
    FROM pg_index ix
    JOIN pg_class t ON t.oid = ix.indrelid
    JOIN pg_class i ON i.oid = ix.indexrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
    WHERE NOT ix.indisprimary
        AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
        AND a.attnum > 0
        AND NOT a.attisdropped
)
SELECT
    'Search Column Nullability - ' || ic.schema_name || '.' || ic.table_name || '.' || ic.column_name AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN c.is_nullable = 'YES' THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN c.is_nullable = 'YES' THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CASE
        WHEN c.is_nullable = 'YES' THEN 'NULLABLE'
        ELSE 'NOT NULL'
    END AS current_value,
    'NOT NULL' AS default_value,
    CASE
        WHEN c.is_nullable = 'YES' THEN ic.schema_name || '.' || ic.table_name || '.' || ic.column_name || ' - nullable search column (index: ' || ic.index_name || ')'
        ELSE ic.schema_name || '.' || ic.table_name || '.' || ic.column_name || ' - search column nullability check passed'
    END AS message
FROM indexed_columns ic
JOIN information_schema.columns c
    ON c.table_schema = ic.schema_name
    AND c.table_name = ic.table_name
    AND c.column_name = ic.column_name;
