-- PostgreSQL Primary Key Check
-- Checks that all user tables have a single-column primary key

WITH table_pk_info AS (
    SELECT
        t.table_schema,
        t.table_name,
        (
            SELECT count(*)
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            WHERE tc.constraint_type = 'PRIMARY KEY'
                AND tc.table_schema = t.table_schema
                AND tc.table_name = t.table_name
        ) AS pk_column_count,
        (
            SELECT count(*)
            FROM information_schema.table_constraints tc
            WHERE tc.constraint_type = 'PRIMARY KEY'
                AND tc.table_schema = t.table_schema
                AND tc.table_name = t.table_name
        ) AS pk_count
    FROM information_schema.tables t
    WHERE t.table_type = 'BASE TABLE'
        AND t.table_schema NOT IN ('pg_catalog', 'information_schema')
)
SELECT
    'Primary Key Check - ' || table_schema || '.' || table_name AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN pk_count = 0 THEN 'FLAGGED'
        WHEN pk_column_count > 1 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN pk_count = 0 THEN 'CRITICAL'
        WHEN pk_column_count > 1 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CASE
        WHEN pk_count = 0 THEN 'No primary key'
        WHEN pk_column_count > 1 THEN 'Composite key (' || pk_column_count::text || ' columns)'
        ELSE 'Single-column primary key'
    END AS current_value,
    'Single-column primary key' AS default_value,
    CASE
        WHEN pk_count = 0 THEN table_schema || '.' || table_name || ' - missing primary key'
        WHEN pk_column_count > 1 THEN table_schema || '.' || table_name || ' - composite primary key - single-column primary key recommended'
        ELSE table_schema || '.' || table_name || ' - primary key check passed'
    END AS message
FROM table_pk_info;
