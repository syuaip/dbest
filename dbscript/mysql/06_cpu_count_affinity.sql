-- MySQL CPU Count (CPU Affinity) Check
-- Checks innodb_read_io_threads and innodb_write_io_threads as CPU affinity indicators
-- MySQL uses thread-based CPU affinity rather than a single CPU count parameter

SELECT
    'CPU Count (CPU Affinity)' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN @@innodb_read_io_threads = 4 AND @@innodb_write_io_threads = 4 THEN 'PASSED'
        ELSE 'FLAGGED'
    END AS status,
    CASE
        WHEN @@innodb_read_io_threads = 4 AND @@innodb_write_io_threads = 4 THEN 'OK'
        ELSE 'ADVISORY'
    END AS severity,
    CONCAT('read_io_threads=', @@innodb_read_io_threads, ', write_io_threads=', @@innodb_write_io_threads) AS current_value,
    'read_io_threads=4, write_io_threads=4' AS default_value,
    CASE
        WHEN @@innodb_read_io_threads = 4 AND @@innodb_write_io_threads = 4
            THEN 'CPU affinity settings are at default values'
        ELSE CONCAT(
            'Non-default CPU count requiring verification. ',
            'innodb_read_io_threads=', @@innodb_read_io_threads,
            ', innodb_write_io_threads=', @@innodb_write_io_threads,
            ' (defaults: 4, 4)'
        )
    END AS message;
