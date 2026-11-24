-- MySQL CPU Parallelism Check (innodb_parallel_read_threads)
-- Flags when using default value (4) - parallelism should be tuned away from default

SELECT
    'CPU Parallelism (innodb_parallel_read_threads)' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN @@innodb_parallel_read_threads = 4 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN @@innodb_parallel_read_threads = 4 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CAST(@@innodb_parallel_read_threads AS CHAR) AS current_value,
    '4' AS default_value,
    CASE
        WHEN @@innodb_parallel_read_threads = 4
            THEN 'CPU parallelism using default value (4) - consider tuning for workload'
        ELSE CONCAT('CPU parallelism configured to non-default value: ', @@innodb_parallel_read_threads)
    END AS message;
