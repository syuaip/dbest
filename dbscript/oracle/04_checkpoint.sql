-- Oracle Checkpoint Configuration Check
-- Checks LOG_CHECKPOINT_TIMEOUT against default value (0)
SELECT
    'Checkpoint Configuration (LOG_CHECKPOINT_TIMEOUT)' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN value = '0' THEN 'PASSED'
        ELSE 'FLAGGED'
    END AS status,
    CASE
        WHEN value = '0' THEN 'OK'
        ELSE 'ADVISORY'
    END AS severity,
    value AS current_value,
    '0' AS default_value,
    CASE
        WHEN value = '0' THEN 'LOG_CHECKPOINT_TIMEOUT is set to default value'
        ELSE 'Non-default checkpoint configuration requiring verification - LOG_CHECKPOINT_TIMEOUT is ' || value || ' (default: 0)'
    END AS message
FROM V$PARAMETER
WHERE UPPER(name) = 'LOG_CHECKPOINT_TIMEOUT';
