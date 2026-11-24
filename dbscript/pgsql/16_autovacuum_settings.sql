-- PostgreSQL Autovacuum Configuration Check
-- Checks autovacuum_freeze_max_age, autovacuum_vacuum_threshold,
-- autovacuum_vacuum_scale_factor, and autovacuum_max_workers against defaults

SELECT
    'Autovacuum - autovacuum_freeze_max_age' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN s.setting = s.boot_val THEN 'PASSED'
        ELSE 'FLAGGED'
    END AS status,
    CASE
        WHEN s.setting = s.boot_val THEN 'OK'
        ELSE 'ADVISORY'
    END AS severity,
    s.setting AS current_value,
    s.boot_val AS default_value,
    CASE
        WHEN s.setting = s.boot_val THEN 'autovacuum_freeze_max_age uses default value'
        ELSE 'Non-default autovacuum_freeze_max_age requiring verification - current: ' || s.setting || ', default: ' || s.boot_val
    END AS message
FROM pg_settings s
WHERE s.name = 'autovacuum_freeze_max_age'

UNION ALL

SELECT
    'Autovacuum - autovacuum_vacuum_threshold' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN s.setting = s.boot_val THEN 'PASSED'
        ELSE 'FLAGGED'
    END AS status,
    CASE
        WHEN s.setting = s.boot_val THEN 'OK'
        ELSE 'ADVISORY'
    END AS severity,
    s.setting AS current_value,
    s.boot_val AS default_value,
    CASE
        WHEN s.setting = s.boot_val THEN 'autovacuum_vacuum_threshold uses default value'
        ELSE 'Non-default autovacuum_vacuum_threshold requiring verification - current: ' || s.setting || ', default: ' || s.boot_val
    END AS message
FROM pg_settings s
WHERE s.name = 'autovacuum_vacuum_threshold'

UNION ALL

SELECT
    'Autovacuum - autovacuum_vacuum_scale_factor' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN s.setting = s.boot_val THEN 'PASSED'
        ELSE 'FLAGGED'
    END AS status,
    CASE
        WHEN s.setting = s.boot_val THEN 'OK'
        ELSE 'ADVISORY'
    END AS severity,
    s.setting AS current_value,
    s.boot_val AS default_value,
    CASE
        WHEN s.setting = s.boot_val THEN 'autovacuum_vacuum_scale_factor uses default value'
        ELSE 'Non-default autovacuum_vacuum_scale_factor requiring verification - current: ' || s.setting || ', default: ' || s.boot_val
    END AS message
FROM pg_settings s
WHERE s.name = 'autovacuum_vacuum_scale_factor'

UNION ALL

SELECT
    'Autovacuum - autovacuum_max_workers' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN s.setting = s.boot_val THEN 'PASSED'
        ELSE 'FLAGGED'
    END AS status,
    CASE
        WHEN s.setting = s.boot_val THEN 'OK'
        ELSE 'ADVISORY'
    END AS severity,
    s.setting AS current_value,
    s.boot_val AS default_value,
    CASE
        WHEN s.setting = s.boot_val THEN 'autovacuum_max_workers uses default value'
        ELSE 'Non-default autovacuum_max_workers requiring verification - current: ' || s.setting || ', default: ' || s.boot_val
    END AS message
FROM pg_settings s
WHERE s.name = 'autovacuum_max_workers';
