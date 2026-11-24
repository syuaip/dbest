-- Oracle High Availability Replica Check
-- Checks if Data Guard standby databases are configured
SELECT
    'High Availability Replica' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN replica_count = 0 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN replica_count = 0 THEN 'CRITICAL'
        ELSE 'OK'
    END AS severity,
    TO_CHAR(replica_count) AS current_value,
    '1' AS default_value,
    CASE
        WHEN replica_count = 0 THEN 'Missing replica for high availability - no Data Guard standby database detected'
        ELSE 'High availability check passed - ' || replica_count || ' replica(s) configured'
    END AS message
FROM (
    SELECT COUNT(*) AS replica_count
    FROM V$ARCHIVE_DEST_STATUS
    WHERE STATUS = 'VALID'
      AND TYPE = 'PHYSICAL'
      AND DATABASE_MODE != 'UNKNOWN'
);
