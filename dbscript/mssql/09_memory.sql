-- Memory Settings Check: max server memory
-- Displays the current max server memory setting for review
DECLARE @max_server_memory INT;

SELECT @max_server_memory = CAST(value_in_use AS INT)
FROM sys.configurations
WHERE name = 'max server memory (MB)';

SELECT 
    'Memory Configuration (max server memory)' AS check_name,
    'INSTANCE' AS check_level,
    CASE 
        WHEN @max_server_memory IS NULL THEN 'ERROR'
        WHEN @max_server_memory = 2147483647 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE 
        WHEN @max_server_memory IS NULL THEN 'ADVISORY'
        WHEN @max_server_memory = 2147483647 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CAST(ISNULL(@max_server_memory, 0) AS VARCHAR(20)) + ' MB' AS current_value,
    '2147483647 MB (unlimited)' AS default_value,
    CASE 
        WHEN @max_server_memory IS NULL 
            THEN 'Unable to retrieve max server memory setting'
        WHEN @max_server_memory = 2147483647 
            THEN 'Max server memory is set to default (unlimited: 2147483647 MB). Consider setting an explicit limit to prevent OS memory pressure.'
        ELSE 'Max server memory is configured: ' + CAST(@max_server_memory AS VARCHAR(20)) + ' MB'
    END AS message;
