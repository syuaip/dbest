-- MySQL Buffer Cache Hit Ratio Check
-- Evaluates InnoDB buffer pool hit ratio using global status counters

SELECT
    'Buffer Cache Hit Ratio' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') = '0'
            THEN 'INSUFFICIENT_DATA'
        WHEN (1 - (
            (SELECT CAST(VARIABLE_VALUE AS UNSIGNED) FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads')
            / GREATEST((SELECT CAST(VARIABLE_VALUE AS UNSIGNED) FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 1)
        )) * 100 < 90
            THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') = '0'
            THEN 'ADVISORY'
        WHEN (1 - (
            (SELECT CAST(VARIABLE_VALUE AS UNSIGNED) FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads')
            / GREATEST((SELECT CAST(VARIABLE_VALUE AS UNSIGNED) FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 1)
        )) * 100 < 90
            THEN 'CRITICAL'
        ELSE 'OK'
    END AS severity,
    CONCAT(
        ROUND(
            (1 - (
                (SELECT CAST(VARIABLE_VALUE AS UNSIGNED) FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads')
                / GREATEST((SELECT CAST(VARIABLE_VALUE AS UNSIGNED) FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 1)
            )) * 100, 2
        ), '%'
    ) AS current_value,
    '90%' AS default_value,
    CASE
        WHEN (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') = '0'
            THEN 'Insufficient buffer pool data - instance may have just started'
        WHEN (1 - (
            (SELECT CAST(VARIABLE_VALUE AS UNSIGNED) FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads')
            / GREATEST((SELECT CAST(VARIABLE_VALUE AS UNSIGNED) FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 1)
        )) * 100 < 90
            THEN 'Buffer cache hit ratio below 90% - instance may be under-provisioned for memory'
        ELSE 'Buffer cache hit ratio is healthy (90% or above)'
    END AS message;
