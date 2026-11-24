-- PostgreSQL Trigger Check
-- Detects tables with triggers defined

WITH table_triggers AS (
    SELECT
        n.nspname AS schema_name,
        c.relname AS table_name,
        string_agg(t.tgname, ', ') AS trigger_names,
        count(*) AS trigger_count
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE NOT t.tgisinternal
        AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    GROUP BY n.nspname, c.relname
)
SELECT
    'Trigger Check - ' || schema_name || '.' || table_name AS check_name,
    'TABLE' AS check_level,
    'FLAGGED' AS status,
    'ADVISORY' AS severity,
    trigger_count::text || ' trigger(s): ' || trigger_names AS current_value,
    'No triggers' AS default_value,
    schema_name || '.' || table_name || ' - has triggers - consider event-driven architecture (triggers: ' || trigger_names || ')' AS message
FROM table_triggers

UNION ALL

SELECT
    'Trigger Check' AS check_name,
    'TABLE' AS check_level,
    'PASSED' AS status,
    'OK' AS severity,
    'No triggers' AS current_value,
    'No triggers' AS default_value,
    'No tables with triggers found' AS message
WHERE NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE NOT t.tgisinternal
        AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
);
