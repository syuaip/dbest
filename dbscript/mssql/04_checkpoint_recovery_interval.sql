-- Checkpoint Configuration Check: recovery_interval setting
-- Flags when recovery_interval differs from default value (0)
DECLARE @current_value INT;
DECLARE @default_value INT = 0;

SELECT @current_value = CAST(value_in_use AS INT)
FROM sys.configurations
WHERE name = 'recovery interval (min)';

SELECT 
    'Checkpoint Configuration (recovery_interval)' AS check_name,
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
            THEN 'Unable to retrieve recovery_interval setting'
        WHEN @current_value <> @default_value 
            THEN 'Non-default checkpoint configuration requiring verification. recovery_interval is ' + CAST(@current_value AS VARCHAR(20)) + ' (default: ' + CAST(@default_value AS VARCHAR(20)) + ')'
        ELSE 'Checkpoint configuration (recovery_interval) is at default value: ' + CAST(@current_value AS VARCHAR(20))
    END AS message;
