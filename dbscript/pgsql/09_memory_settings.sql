-- PostgreSQL Memory Settings Display
-- Retrieves shared_buffers and effective_cache_size values

SELECT
    'Memory Settings - shared_buffers' AS check_name,
    'INSTANCE' AS check_level,
    'PASSED' AS status,
    'OK' AS severity,
    s.setting || ' ' || COALESCE(s.unit, '') AS current_value,
    s.boot_val || ' ' || COALESCE(s.unit, '') AS default_value,
    'shared_buffers is set to ' || s.setting || ' ' || COALESCE(s.unit, '') AS message
FROM pg_settings s
WHERE s.name = 'shared_buffers'

UNION ALL

SELECT
    'Memory Settings - effective_cache_size' AS check_name,
    'INSTANCE' AS check_level,
    'PASSED' AS status,
    'OK' AS severity,
    s.setting || ' ' || COALESCE(s.unit, '') AS current_value,
    s.boot_val || ' ' || COALESCE(s.unit, '') AS default_value,
    'effective_cache_size is set to ' || s.setting || ' ' || COALESCE(s.unit, '') AS message
FROM pg_settings s
WHERE s.name = 'effective_cache_size';
