-- MySQL Checkpoint Configuration Check (innodb_log_file_size)
-- Compares current innodb_log_file_size against the default value (48MB)

SELECT
    'Checkpoint Configuration (innodb_log_file_size)' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN @@innodb_log_file_size = 50331648 THEN 'PASSED'
        ELSE 'FLAGGED'
    END AS status,
    CASE
        WHEN @@innodb_log_file_size = 50331648 THEN 'OK'
        ELSE 'ADVISORY'
    END AS severity,
    CONCAT(ROUND(@@innodb_log_file_size / 1048576, 2), 'MB') AS current_value,
    '48MB' AS default_value,
    CASE
        WHEN @@innodb_log_file_size = 50331648
            THEN 'innodb_log_file_size is at default value (48MB)'
        ELSE CONCAT(
            'Non-default checkpoint configuration requiring verification. Current: ',
            ROUND(@@innodb_log_file_size / 1048576, 2), 'MB, Default: 48MB'
        )
    END AS message;
