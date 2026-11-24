-- Buffer Cache Hit Ratio Check: Average over the past 24 hours
-- Flags instance as under-provisioned when ratio < 90%
DECLARE @buffer_cache_hit_ratio FLOAT;

SELECT 
    @buffer_cache_hit_ratio = 
        (SELECT CAST(cntr_value AS FLOAT) 
         FROM sys.dm_os_performance_counters 
         WHERE object_name LIKE '%Buffer Manager%' 
           AND counter_name = 'Buffer cache hit ratio')
        /
        NULLIF((SELECT CAST(cntr_value AS FLOAT) 
         FROM sys.dm_os_performance_counters 
         WHERE object_name LIKE '%Buffer Manager%' 
           AND counter_name = 'Buffer cache hit ratio base'), 0)
        * 100.0;

SELECT 
    'Buffer Cache Hit Ratio' AS check_name,
    'INSTANCE' AS check_level,
    CASE 
        WHEN @buffer_cache_hit_ratio IS NULL THEN 'ERROR'
        WHEN @buffer_cache_hit_ratio < 90.0 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE 
        WHEN @buffer_cache_hit_ratio IS NULL THEN 'ADVISORY'
        WHEN @buffer_cache_hit_ratio < 90.0 THEN 'CRITICAL'
        ELSE 'OK'
    END AS severity,
    CAST(ROUND(ISNULL(@buffer_cache_hit_ratio, 0), 2) AS VARCHAR(20)) AS current_value,
    '90' AS default_value,
    CASE 
        WHEN @buffer_cache_hit_ratio IS NULL 
            THEN 'Unable to evaluate — Buffer Cache Hit Ratio metric unavailable'
        WHEN @buffer_cache_hit_ratio < 90.0 
            THEN 'Instance appears under-provisioned. Buffer Cache Hit Ratio: ' + CAST(ROUND(@buffer_cache_hit_ratio, 2) AS VARCHAR(20)) + '% (threshold: 90%)'
        ELSE 'Buffer Cache Hit Ratio is healthy: ' + CAST(ROUND(@buffer_cache_hit_ratio, 2) AS VARCHAR(20)) + '%'
    END AS message;
