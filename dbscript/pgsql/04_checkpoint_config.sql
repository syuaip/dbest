-- PostgreSQL Checkpoint Configuration Check
-- Checks checkpoint_timeout and max_wal_size against default values

SELECT
    'Checkpoint Configuration - checkpoint_timeout' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN s.setting = s.boot_val THEN 'PASSED'
        ELSE 'FLAGGED'
    END AS status,
    CASE
        WHEN s.setting = s.boot_val THEN 'OK'
        ELSE 'ADVISORY'
    END AS severity,
    s.setting || ' ' || COALESCE(s.unit, '') AS current_value,
    s.boot_val || ' ' || COALESCE(s.unit, '') AS default_value,
    CASE
        WHEN s.setting = s.boot_val THEN 'Checkpoint timeout uses default value'
        ELSE 'Non-default checkpoint_timeout requiring verification - current: ' || s.setting || ' ' || COALESCE(s.unit, '') || ', default: ' || s.boot_val || ' ' || COALESCE(s.unit, '')
    END AS message
FROM pg_settings s
WHERE s.name = 'checkpoint_timeout'

UNION ALL

SELECT
    'Checkpoint Configuration - max_wal_size' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN s.setting = s.boot_val THEN 'PASSED'
        ELSE 'FLAGGED'
    END AS status,
    CASE
        WHEN s.setting = s.boot_val THEN 'OK'
        ELSE 'ADVISORY'
    END AS severity,
    s.setting || ' ' || COALESCE(s.unit, '') AS current_value,
    s.boot_val || ' ' || COALESCE(s.unit, '') AS default_value,
    CASE
        WHEN s.setting = s.boot_val THEN 'max_wal_size uses default value'
        ELSE 'Non-default max_wal_size requiring verification - current: ' || s.setting || ' ' || COALESCE(s.unit, '') || ', default: ' || s.boot_val || ' ' || COALESCE(s.unit, '')
    END AS message
FROM pg_settings s
WHERE s.name = 'max_wal_size';
