-- PostgreSQL High Availability Replica Check
-- Checks if streaming replication replicas are configured

SELECT
    'High Availability Replica' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN (SELECT count(*) FROM pg_stat_replication) = 0
            THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN (SELECT count(*) FROM pg_stat_replication) = 0
            THEN 'CRITICAL'
        ELSE 'OK'
    END AS severity,
    (SELECT count(*) FROM pg_stat_replication)::text AS current_value,
    '1' AS default_value,
    CASE
        WHEN (SELECT count(*) FROM pg_stat_replication) = 0
            THEN 'Missing replica for high availability - no streaming replicas detected'
        ELSE 'High availability check passed - ' || (SELECT count(*) FROM pg_stat_replication)::text || ' replica(s) configured'
    END AS message;
