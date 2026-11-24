-- PostgreSQL Maximum Connections Check
-- Checks max_connections against default value

SELECT
    'Maximum Connections' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN s.setting = '1' THEN 'FLAGGED'
        WHEN s.setting = s.boot_val THEN 'PASSED'
        ELSE 'FLAGGED'
    END AS status,
    CASE
        WHEN s.setting = '1' THEN 'CRITICAL'
        WHEN s.setting = s.boot_val THEN 'OK'
        ELSE 'ADVISORY'
    END AS severity,
    s.setting AS current_value,
    s.boot_val AS default_value,
    CASE
        WHEN s.setting = '1' THEN 'Critical: maximum connections set to 1'
        WHEN s.setting = s.boot_val THEN 'Maximum connections check passed - using default value'
        ELSE 'Non-default maximum connections requiring verification - current: ' || s.setting || ', default: ' || s.boot_val
    END AS message
FROM pg_settings s
WHERE s.name = 'max_connections';
