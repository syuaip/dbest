-- Oracle Ad-Hoc Query Setting Check
-- Checks CURSOR_SHARING parameter
-- EXACT means no ad-hoc optimization; FORCE or SIMILAR means optimized
SELECT
    'Ad-Hoc Query Setting (CURSOR_SHARING)' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN UPPER(value) = 'EXACT' THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN UPPER(value) = 'EXACT' THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    value AS current_value,
    'EXACT' AS default_value,
    CASE
        WHEN UPPER(value) = 'EXACT' THEN 'Ad-hoc query optimization not enabled - CURSOR_SHARING is EXACT (consider FORCE for ad-hoc workloads)'
        ELSE 'Ad-hoc query optimization enabled - CURSOR_SHARING is ' || value
    END AS message
FROM V$PARAMETER
WHERE UPPER(name) = 'CURSOR_SHARING';
