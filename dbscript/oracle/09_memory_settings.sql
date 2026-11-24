-- Oracle Memory Settings Check
-- Retrieves MEMORY_MAX_TARGET and SGA_MAX_SIZE for review
SELECT
    check_name,
    'INSTANCE' AS check_level,
    'PASSED' AS status,
    'OK' AS severity,
    current_value,
    'N/A' AS default_value,
    message
FROM (
    SELECT
        'Memory Setting (MEMORY_MAX_TARGET)' AS check_name,
        value AS current_value,
        'MEMORY_MAX_TARGET is ' || value || ' bytes (' || ROUND(TO_NUMBER(value) / 1024 / 1024, 2) || ' MB)' AS message
    FROM V$PARAMETER
    WHERE UPPER(name) = 'MEMORY_MAX_TARGET'
    UNION ALL
    SELECT
        'Memory Setting (SGA_MAX_SIZE)' AS check_name,
        value AS current_value,
        'SGA_MAX_SIZE is ' || value || ' bytes (' || ROUND(TO_NUMBER(value) / 1024 / 1024, 2) || ' MB)' AS message
    FROM V$PARAMETER
    WHERE UPPER(name) = 'SGA_MAX_SIZE'
);
