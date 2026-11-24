-- PostgreSQL CPU Parallelism Configuration Check
-- Checks max_parallel_workers - flags when using default value (should be tuned)

SELECT
    'CPU Parallelism - max_parallel_workers' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN s.setting = s.boot_val THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN s.setting = s.boot_val THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    s.setting AS current_value,
    s.boot_val AS default_value,
    CASE
        WHEN s.setting = s.boot_val THEN 'CPU parallelism using default value - consider tuning max_parallel_workers (current: ' || s.setting || ', default: ' || s.boot_val || ')'
        ELSE 'CPU parallelism check passed - max_parallel_workers has been tuned to ' || s.setting
    END AS message
FROM pg_settings s
WHERE s.name = 'max_parallel_workers';
