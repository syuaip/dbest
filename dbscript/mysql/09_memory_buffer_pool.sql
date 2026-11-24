-- MySQL Memory Settings Check (innodb_buffer_pool_size)
-- Displays current memory configuration for SA review

SELECT
    'Memory Settings (innodb_buffer_pool_size)' AS check_name,
    'INSTANCE' AS check_level,
    'PASSED' AS status,
    'OK' AS severity,
    CONCAT(ROUND(@@innodb_buffer_pool_size / 1048576, 2), 'MB') AS current_value,
    '128MB' AS default_value,
    CONCAT(
        'InnoDB buffer pool size: ', ROUND(@@innodb_buffer_pool_size / 1048576, 2), 'MB',
        ' (', ROUND(@@innodb_buffer_pool_size / 1073741824, 2), 'GB)',
        '. Review for appropriateness based on available system memory.'
    ) AS message;
