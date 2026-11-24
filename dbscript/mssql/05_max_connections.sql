-- Maximum Connections Check: max worker threads setting
-- Flags when value is 1 (critical) or differs from default (0 = auto)
DECLARE @current_value INT;
DECLARE @default_value INT = 0;

SELECT @current_value = CAST(value_in_use AS INT)
FROM sys.configurations
WHERE name = 'max worker threads';

SELECT 
    'Maximum Connections (max worker threads)' AS check_name,
    'INSTANCE' AS check_level,
    CASE 
        WHEN @current_value IS NULL THEN 'ERROR'
        WHEN @current_value = 1 THEN 'FLAGGED'
        WHEN @current_value <> @default_value THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE 
        WHEN @current_value IS NULL THEN 'ADVISORY'
        WHEN @current_value = 1 THEN 'CRITICAL'
        WHEN @current_value <> @default_value THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CAST(ISNULL(@current_value, 0) AS VARCHAR(20)) AS current_value,
    CAST(@default_value AS VARCHAR(20)) AS default_value,
    CASE 
        WHEN @current_value IS NULL 
            THEN 'Unable to retrieve max worker threads setting'
        WHEN @current_value = 1 
            THEN 'Critical: maximum connections set to 1. Engine default: ' + CAST(@default_value AS VARCHAR(20))
        WHEN @current_value <> @default_value 
            THEN 'Non-default maximum connections requiring verification. Current: ' + CAST(@current_value AS VARCHAR(20)) + ', Default: ' + CAST(@default_value AS VARCHAR(20))
        ELSE 'Maximum connections (max worker threads) is at default value: ' + CAST(@current_value AS VARCHAR(20)) + ' (auto)'
    END AS message;
