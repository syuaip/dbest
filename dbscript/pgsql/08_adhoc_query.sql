-- PostgreSQL Ad-Hoc Query Setting Check
-- Checks plan_cache_mode setting

SELECT
    'Ad-Hoc Query Optimization - plan_cache_mode' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN s.setting = 'auto' THEN 'PASSED'
        WHEN s.setting = 'force_generic_plan' THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN s.setting = 'force_generic_plan' THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    s.setting AS current_value,
    s.boot_val AS default_value,
    CASE
        WHEN s.setting = 'auto' THEN 'Ad-hoc query optimization check passed - plan_cache_mode is set to auto'
        WHEN s.setting = 'force_generic_plan' THEN 'Ad-hoc query optimization not enabled - plan_cache_mode set to force_generic_plan, consider using auto or force_custom_plan'
        ELSE 'Ad-hoc query optimization check passed - plan_cache_mode is set to ' || s.setting
    END AS message
FROM pg_settings s
WHERE s.name = 'plan_cache_mode';
