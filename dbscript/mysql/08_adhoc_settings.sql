-- MySQL Ad-Hoc Query Settings Check
-- Checks prepared_stmt_count and table_open_cache for ad-hoc query optimization

SELECT
    'Ad-Hoc Query Settings' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN @@table_open_cache <= 400 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN @@table_open_cache <= 400 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CONCAT(
        'max_prepared_stmt_count=', @@max_prepared_stmt_count,
        ', table_open_cache=', @@table_open_cache
    ) AS current_value,
    'max_prepared_stmt_count=16382, table_open_cache=4000' AS default_value,
    CASE
        WHEN @@table_open_cache <= 400
            THEN CONCAT(
                'Ad-hoc query optimization not enabled. table_open_cache=', @@table_open_cache,
                ' (recommended: > 400). max_prepared_stmt_count=', @@max_prepared_stmt_count
            )
        ELSE CONCAT(
            'Ad-hoc query settings are acceptable. table_open_cache=', @@table_open_cache,
            ', max_prepared_stmt_count=', @@max_prepared_stmt_count
        )
    END AS message;
