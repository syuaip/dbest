-- Oracle CPU Parallelism Configuration Check
-- Checks PARALLEL_MAX_SERVERS against default value (0)
-- Flags when using default (parallelism not configured)
SELECT
    'CPU Parallelism (PARALLEL_MAX_SERVERS)' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN value = '0' THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN value = '0' THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    value AS current_value,
    '0' AS default_value,
    CASE
        WHEN value = '0' THEN 'CPU parallelism using default value - consider tuning PARALLEL_MAX_SERVERS (current: 0)'
        ELSE 'CPU parallelism configured - PARALLEL_MAX_SERVERS is ' || value
    END AS message
FROM V$PARAMETER
WHERE UPPER(name) = 'PARALLEL_MAX_SERVERS';
