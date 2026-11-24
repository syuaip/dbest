-- MySQL CPU Utilization Check
-- Checks average CPU usage via performance_schema thread activity
-- Note: MySQL does not natively track historical CPU usage like SQL Server.
-- This script uses performance_schema to estimate current CPU thread activity.
-- For full 30-day historical data, CloudWatch or external monitoring is recommended.

SELECT
    'CPU Utilization' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN (SELECT COUNT(*) FROM performance_schema.threads WHERE TYPE = 'FOREGROUND' AND PROCESSLIST_STATE IS NOT NULL) = 0
            THEN 'INSUFFICIENT_DATA'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN (SELECT COUNT(*) FROM performance_schema.threads WHERE TYPE = 'FOREGROUND' AND PROCESSLIST_STATE IS NOT NULL) = 0
            THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    COALESCE(
        CAST(
            ROUND(
                (SELECT COUNT(*) FROM performance_schema.threads WHERE TYPE = 'FOREGROUND' AND PROCESSLIST_STATE IS NOT NULL)
                / GREATEST((SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Threads_connected'), 1)
                * 100, 2
            ) AS CHAR
        ),
        'N/A'
    ) AS current_value,
    '40' AS default_value,
    CASE
        WHEN (SELECT COUNT(*) FROM performance_schema.threads WHERE TYPE = 'FOREGROUND' AND PROCESSLIST_STATE IS NOT NULL) = 0
            THEN 'Insufficient CPU usage data available. Use CloudWatch or external monitoring for 30-day average.'
        ELSE CONCAT(
            'CPU thread activity ratio: ',
            ROUND(
                (SELECT COUNT(*) FROM performance_schema.threads WHERE TYPE = 'FOREGROUND' AND PROCESSLIST_STATE IS NOT NULL)
                / GREATEST((SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Threads_connected'), 1)
                * 100, 2
            ),
            '%. Note: For accurate 30-day average, use CloudWatch metrics.'
        )
    END AS message;
