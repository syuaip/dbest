-- MySQL High Availability Replica Check
-- Checks if the instance has replicas configured for high availability

SELECT
    'High Availability Replica' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Rpl_semi_sync_source_clients') IS NOT NULL
             AND CAST((SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Rpl_semi_sync_source_clients') AS UNSIGNED) > 0
            THEN 'PASSED'
        WHEN (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Rpl_semi_sync_master_clients') IS NOT NULL
             AND CAST((SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Rpl_semi_sync_master_clients') AS UNSIGNED) > 0
            THEN 'PASSED'
        WHEN (SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE COMMAND = 'Binlog Dump' OR COMMAND = 'Binlog Dump GTID') > 0
            THEN 'PASSED'
        ELSE 'FLAGGED'
    END AS status,
    CASE
        WHEN (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Rpl_semi_sync_source_clients') IS NOT NULL
             AND CAST((SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Rpl_semi_sync_source_clients') AS UNSIGNED) > 0
            THEN 'OK'
        WHEN (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Rpl_semi_sync_master_clients') IS NOT NULL
             AND CAST((SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Rpl_semi_sync_master_clients') AS UNSIGNED) > 0
            THEN 'OK'
        WHEN (SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE COMMAND = 'Binlog Dump' OR COMMAND = 'Binlog Dump GTID') > 0
            THEN 'OK'
        ELSE 'CRITICAL'
    END AS severity,
    CAST(
        (SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE COMMAND = 'Binlog Dump' OR COMMAND = 'Binlog Dump GTID')
    AS CHAR) AS current_value,
    '1' AS default_value,
    CASE
        WHEN (SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE COMMAND = 'Binlog Dump' OR COMMAND = 'Binlog Dump GTID') > 0
            THEN CONCAT('Instance has ', (SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE COMMAND = 'Binlog Dump' OR COMMAND = 'Binlog Dump GTID'), ' replica(s) connected')
        ELSE 'No replicas detected - missing replica for high availability'
    END AS message;
