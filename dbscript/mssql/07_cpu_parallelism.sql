-- CPU Parallelism Configuration Check: MaxDOP and cost threshold for parallelism
-- Flags when EITHER setting uses its default value (MaxDOP default: 0, cost threshold default: 5)
DECLARE @maxdop INT;
DECLARE @cost_threshold INT;
DECLARE @maxdop_default INT = 0;
DECLARE @cost_threshold_default INT = 5;

SELECT @maxdop = CAST(value_in_use AS INT)
FROM sys.configurations
WHERE name = 'max degree of parallelism';

SELECT @cost_threshold = CAST(value_in_use AS INT)
FROM sys.configurations
WHERE name = 'cost threshold for parallelism';

SELECT 
    'CPU Parallelism (MaxDOP & Cost Threshold)' AS check_name,
    'INSTANCE' AS check_level,
    CASE 
        WHEN @maxdop IS NULL OR @cost_threshold IS NULL THEN 'ERROR'
        WHEN @maxdop = @maxdop_default OR @cost_threshold = @cost_threshold_default THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE 
        WHEN @maxdop IS NULL OR @cost_threshold IS NULL THEN 'ADVISORY'
        WHEN @maxdop = @maxdop_default OR @cost_threshold = @cost_threshold_default THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    'MaxDOP=' + CAST(ISNULL(@maxdop, 0) AS VARCHAR(10)) + ', CostThreshold=' + CAST(ISNULL(@cost_threshold, 5) AS VARCHAR(10)) AS current_value,
    'MaxDOP=0, CostThreshold=5' AS default_value,
    CASE 
        WHEN @maxdop IS NULL OR @cost_threshold IS NULL 
            THEN 'Unable to retrieve parallelism settings'
        WHEN @maxdop = @maxdop_default AND @cost_threshold = @cost_threshold_default 
            THEN 'CPU parallelism using default values — consider tuning. MaxDOP=' + CAST(@maxdop AS VARCHAR(10)) + ' (default: 0), Cost Threshold=' + CAST(@cost_threshold AS VARCHAR(10)) + ' (default: 5)'
        WHEN @maxdop = @maxdop_default 
            THEN 'CPU parallelism using default value — consider tuning. MaxDOP=' + CAST(@maxdop AS VARCHAR(10)) + ' (default: 0), Cost Threshold=' + CAST(@cost_threshold AS VARCHAR(10))
        WHEN @cost_threshold = @cost_threshold_default 
            THEN 'CPU parallelism using default value — consider tuning. MaxDOP=' + CAST(@maxdop AS VARCHAR(10)) + ', Cost Threshold=' + CAST(@cost_threshold AS VARCHAR(10)) + ' (default: 5)'
        ELSE 'CPU parallelism configured with non-default values. MaxDOP=' + CAST(@maxdop AS VARCHAR(10)) + ', Cost Threshold=' + CAST(@cost_threshold AS VARCHAR(10))
    END AS message;
