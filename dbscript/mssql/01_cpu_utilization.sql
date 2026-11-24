-- CPU Utilization Check: Average CPU usage over the past 30 days
-- Flags instance as over-provisioned when average CPU < 40%
DECLARE @avg_cpu FLOAT;
DECLARE @days_available INT;
DECLARE @ms_ticks_now BIGINT;

SELECT @ms_ticks_now = ms_ticks FROM sys.dm_os_sys_info;

;WITH ring_buffer_data AS (
    SELECT
        -- Convert ring buffer timestamp (ms since boot) to datetime
        -- Use seconds to avoid INT overflow in DATEADD
        DATEADD(SECOND,
            -CAST((@ms_ticks_now - CAST(timestamp AS BIGINT)) / 1000 AS INT),
            GETDATE()) AS event_time,
        CONVERT(XML, record) AS record
    FROM sys.dm_os_ring_buffers
    WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
        AND record LIKE '%<SystemHealth>%'
)
SELECT
    @avg_cpu = AVG(CAST(
        record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')
        AS FLOAT)),
    @days_available = DATEDIFF(DAY, MIN(event_time), MAX(event_time))
FROM ring_buffer_data
WHERE event_time >= DATEADD(DAY, -30, GETDATE());

-- SystemIdle gives idle %, so CPU usage = 100 - SystemIdle
SET @avg_cpu = 100.0 - ISNULL(@avg_cpu, 100.0);

SELECT
    'CPU Utilization' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN @days_available IS NULL OR @days_available < 1
            THEN 'INSUFFICIENT_DATA'
        WHEN @avg_cpu < 40.0 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN @days_available IS NULL OR @days_available < 1
            THEN 'ADVISORY'
        WHEN @avg_cpu < 40.0 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CAST(ROUND(ISNULL(@avg_cpu, 0), 2) AS VARCHAR(20)) AS current_value,
    '40' AS default_value,
    CASE
        WHEN @days_available IS NULL OR @days_available < 1
            THEN 'Insufficient CPU data available. Only '
                + CAST(ISNULL(@days_available, 0) AS VARCHAR(10))
                + ' days of data found.'
        WHEN @avg_cpu < 40.0
            THEN 'Instance appears over-provisioned. Average CPU usage over '
                + CAST(@days_available AS VARCHAR(10)) + ' days is '
                + CAST(ROUND(@avg_cpu, 2) AS VARCHAR(20))
                + '% (threshold: 40%)'
        ELSE 'CPU utilization is within acceptable range. Average: '
            + CAST(ROUND(@avg_cpu, 2) AS VARCHAR(20)) + '% over '
            + CAST(@days_available AS VARCHAR(10)) + ' days'
    END AS message;
