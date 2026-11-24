-- High Availability Replica Check
-- Flags instance when no replica is configured for high availability
DECLARE @replica_count INT;

SELECT @replica_count = COUNT(*)
FROM sys.dm_hadr_availability_replica_states
WHERE role_desc = 'SECONDARY';

-- If Always On is not enabled, also check for mirroring or log shipping
IF @replica_count = 0
BEGIN
    SELECT @replica_count = COUNT(*)
    FROM sys.database_mirroring
    WHERE mirroring_state IS NOT NULL
      AND mirroring_role_desc = 'MIRROR';
END

IF @replica_count = 0
BEGIN
    SELECT @replica_count = COUNT(*)
    FROM msdb.dbo.log_shipping_secondary_databases;
END

SELECT 
    'High Availability Replica' AS check_name,
    'INSTANCE' AS check_level,
    CASE 
        WHEN @replica_count = 0 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE 
        WHEN @replica_count = 0 THEN 'CRITICAL'
        ELSE 'OK'
    END AS severity,
    CAST(@replica_count AS VARCHAR(10)) AS current_value,
    '1' AS default_value,
    CASE 
        WHEN @replica_count = 0 
            THEN 'Missing replica for high availability. No Always On, mirroring, or log shipping replicas detected.'
        ELSE 'High availability configured. ' + CAST(@replica_count AS VARCHAR(10)) + ' replica(s) detected.'
    END AS message;
