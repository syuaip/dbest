-- Ad-Hoc Workloads Check: optimize for ad hoc workloads setting
-- Flags when the setting is not enabled (value should be 1)
DECLARE @current_value INT;

SELECT @current_value = CAST(value_in_use AS INT)
FROM sys.configurations
WHERE name = 'optimize for ad hoc workloads';

SELECT 
    'Ad-Hoc Workloads Optimization' AS check_name,
    'INSTANCE' AS check_level,
    CASE 
        WHEN @current_value IS NULL THEN 'ERROR'
        WHEN @current_value = 0 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE 
        WHEN @current_value IS NULL THEN 'ADVISORY'
        WHEN @current_value = 0 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CAST(ISNULL(@current_value, 0) AS VARCHAR(10)) AS current_value,
    '1' AS default_value,
    CASE 
        WHEN @current_value IS NULL 
            THEN 'Unable to retrieve optimize for ad hoc workloads setting'
        WHEN @current_value = 0 
            THEN 'Ad-hoc query optimization not enabled. optimize for ad hoc workloads is disabled (0). Recommend enabling (1) to reduce plan cache bloat.'
        ELSE 'Ad-hoc query optimization is enabled. optimize for ad hoc workloads = ' + CAST(@current_value AS VARCHAR(10))
    END AS message;
