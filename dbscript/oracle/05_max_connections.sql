-- Oracle Maximum Connections Check
-- Checks the 'processes' parameter against default value
SELECT
    'Maximum Connections (processes)' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN TO_NUMBER(value) = 1 THEN 'FLAGGED'
        WHEN value != default_value THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN TO_NUMBER(value) = 1 THEN 'CRITICAL'
        WHEN value != default_value THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    value AS current_value,
    COALESCE(default_value, '300') AS default_value,
    CASE
        WHEN TO_NUMBER(value) = 1 THEN 'Critical: maximum connections (processes) set to 1'
        WHEN value != default_value THEN 'Non-default maximum connections requiring verification - processes is ' || value || ' (default: ' || COALESCE(default_value, '300') || ')'
        ELSE 'Maximum connections (processes) is set to default value'
    END AS message
FROM V$PARAMETER
WHERE UPPER(name) = 'PROCESSES';
