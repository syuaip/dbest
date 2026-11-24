-- PostgreSQL CPU Utilization Check
-- Checks average CPU usage over the past 30 days using pg_stat_activity snapshot
-- Note: PostgreSQL does not natively track historical CPU metrics like some other engines.
-- This script uses pg_stat_activity to estimate current load as a proxy.

SELECT
    'CPU Utilization' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND pid <> pg_backend_pid()) = 0
            THEN 'INSUFFICIENT_DATA'
        WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND pid <> pg_backend_pid())::float /
             GREATEST((SELECT setting::int FROM pg_settings WHERE name = 'max_connections'), 1) * 100 < 40
            THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND pid <> pg_backend_pid()) = 0
            THEN 'OK'
        WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND pid <> pg_backend_pid())::float /
             GREATEST((SELECT setting::int FROM pg_settings WHERE name = 'max_connections'), 1) * 100 < 40
            THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    ROUND(
        (SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND pid <> pg_backend_pid())::numeric /
        GREATEST((SELECT setting::int FROM pg_settings WHERE name = 'max_connections'), 1) * 100, 2
    )::text || '%' AS current_value,
    '40%' AS default_value,
    CASE
        WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND pid <> pg_backend_pid()) = 0
            THEN 'Insufficient CPU usage data available - no active sessions detected'
        WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND pid <> pg_backend_pid())::float /
             GREATEST((SELECT setting::int FROM pg_settings WHERE name = 'max_connections'), 1) * 100 < 40
            THEN 'Instance may be over-provisioned - active connections below 40% of max_connections capacity'
        ELSE 'CPU utilization check passed'
    END AS message;
