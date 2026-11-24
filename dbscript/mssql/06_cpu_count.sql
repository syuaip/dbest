-- CPU Count Configuration Check: max worker threads
-- Verifies that max worker threads uses the default value (0 = auto-configured)
DECLARE @current_value INT;
DECLARE @default_value INT = 0;

SELECT @current_value = CAST(value_in_use AS INT)
FROM sys.configurations
WHERE name = 'max worker threads';

SELECT 
    'CPU Count Configuration (max worker threads)' AS check_name,
    'INSTANCE' AS check_level,
    CASE 
        WHEN @current_value IS NULL THEN 'ERROR'
        WHEN @current_value <> @default_value THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE 
        WHEN @current_value IS NULL THEN 'ADVISORY'
        WHEN @current_value <> @default_value THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CAST(ISNULL(@current_value, 0) AS VARCHAR(20)) AS current_value,
    CAST(@default_value AS VARCHAR(20)) AS default_value,
    CASE 
        WHEN @current_value IS NULL 
            THEN 'Unable to retrieve max worker threads setting'
        WHEN @current_value <> @default_value 
            THEN 'Non-default CPU count requiring verification. max worker threads is ' + CAST(@current_value AS VARCHAR(20)) + ' (default: ' + CAST(@default_value AS VARCHAR(20)) + ' = auto)'
        ELSE 'CPU count configuration (max worker threads) is at default value: ' + CAST(@current_value AS VARCHAR(20)) + ' (auto-configured)'
    END AS message;
