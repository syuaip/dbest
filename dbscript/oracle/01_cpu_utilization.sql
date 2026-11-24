-- Oracle CPU Utilization Check
-- Retrieves average CPU usage over the past 30 days
-- Flags as over-provisioned when below 40%
SELECT
    'CPU Utilization' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN avg_cpu IS NULL THEN 'INSUFFICIENT_DATA'
        WHEN avg_cpu < 40 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN avg_cpu IS NULL THEN 'ADVISORY'
        WHEN avg_cpu < 40 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    COALESCE(TO_CHAR(ROUND(avg_cpu, 2)), 'N/A') AS current_value,
    '40' AS default_value,
    CASE
        WHEN avg_cpu IS NULL THEN 'Insufficient CPU usage data - less than 30 days available'
        WHEN avg_cpu < 40 THEN 'Instance appears over-provisioned - average CPU usage ' || ROUND(avg_cpu, 2) || '% over 30 days is below 40% threshold'
        ELSE 'CPU utilization is adequate - average ' || ROUND(avg_cpu, 2) || '% over 30 days'
    END AS message
FROM (
    SELECT AVG(value) AS avg_cpu
    FROM V$SYSMETRIC_HISTORY
    WHERE METRIC_NAME = 'Host CPU Utilization (%)'
      AND BEGIN_TIME >= SYSDATE - 30
);
