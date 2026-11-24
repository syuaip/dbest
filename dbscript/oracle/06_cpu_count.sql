-- Oracle CPU Count Configuration Check
-- Checks cpu_count parameter (configure-core-count equivalent)
SELECT
    'CPU Count Configuration' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN value != default_value THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN value != default_value THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    value AS current_value,
    COALESCE(default_value, value) AS default_value,
    CASE
        WHEN value != default_value THEN 'Non-default CPU count requiring verification - cpu_count is ' || value || ' (default: ' || COALESCE(default_value, value) || ')'
        ELSE 'CPU count (configure-core-count) is set to default value'
    END AS message
FROM V$PARAMETER
WHERE UPPER(name) = 'CPU_COUNT';
