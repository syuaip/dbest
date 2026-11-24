-- PostgreSQL Statistics Freshness Check
-- Checks last vacuum/analyze date for each table (stale if > 7 days)

SELECT
    'Statistics Freshness - ' || schemaname || '.' || relname AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN last_autoanalyze IS NULL AND last_analyze IS NULL THEN 'FLAGGED'
        WHEN GREATEST(COALESCE(last_autoanalyze, '1970-01-01'::timestamp), COALESCE(last_analyze, '1970-01-01'::timestamp)) < (now() - interval '7 days') THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN last_autoanalyze IS NULL AND last_analyze IS NULL THEN 'ADVISORY'
        WHEN GREATEST(COALESCE(last_autoanalyze, '1970-01-01'::timestamp), COALESCE(last_analyze, '1970-01-01'::timestamp)) < (now() - interval '7 days') THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CASE
        WHEN last_autoanalyze IS NULL AND last_analyze IS NULL THEN 'Never analyzed'
        ELSE GREATEST(COALESCE(last_autoanalyze, '1970-01-01'::timestamp), COALESCE(last_analyze, '1970-01-01'::timestamp))::text
    END AS current_value,
    'Within 7 days' AS default_value,
    CASE
        WHEN last_autoanalyze IS NULL AND last_analyze IS NULL THEN schemaname || '.' || relname || ' - stale statistics - never analyzed'
        WHEN GREATEST(COALESCE(last_autoanalyze, '1970-01-01'::timestamp), COALESCE(last_analyze, '1970-01-01'::timestamp)) < (now() - interval '7 days')
            THEN schemaname || '.' || relname || ' - stale statistics - last updated on ' || GREATEST(COALESCE(last_autoanalyze, '1970-01-01'::timestamp), COALESCE(last_analyze, '1970-01-01'::timestamp))::text
        ELSE schemaname || '.' || relname || ' - statistics freshness check passed'
    END AS message
FROM pg_stat_user_tables;
