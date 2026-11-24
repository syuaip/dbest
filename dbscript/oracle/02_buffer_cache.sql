-- Oracle Buffer Cache Hit Ratio Check
-- Retrieves average Buffer Cache Hit Ratio over the past 24 hours
-- Flags as under-provisioned when below 90%
SELECT
    'Buffer Cache Hit Ratio' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN avg_ratio IS NULL THEN 'INSUFFICIENT_DATA'
        WHEN avg_ratio < 90 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN avg_ratio IS NULL THEN 'ADVISORY'
        WHEN avg_ratio < 90 THEN 'CRITICAL'
        ELSE 'OK'
    END AS severity,
    COALESCE(TO_CHAR(ROUND(avg_ratio, 2)), 'N/A') AS current_value,
    '90' AS default_value,
    CASE
        WHEN avg_ratio IS NULL THEN 'Unable to evaluate - Buffer Cache Hit Ratio metric unavailable'
        WHEN avg_ratio < 90 THEN 'Instance appears under-provisioned - Buffer Cache Hit Ratio ' || ROUND(avg_ratio, 2) || '% is below 90% threshold'
        ELSE 'Buffer Cache Hit Ratio is adequate at ' || ROUND(avg_ratio, 2) || '%'
    END AS message
FROM (
    SELECT AVG(value) AS avg_ratio
    FROM V$SYSMETRIC_HISTORY
    WHERE METRIC_NAME = 'Buffer Cache Hit Ratio'
      AND BEGIN_TIME >= SYSDATE - 1
);
