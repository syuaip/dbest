-- MySQL Maximum Connections Check
-- Checks if max_connections is at default (151) or set to critical value (1)

SELECT
    'Maximum Connections' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN @@max_connections = 1 THEN 'FLAGGED'
        WHEN @@max_connections != 151 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN @@max_connections = 1 THEN 'CRITICAL'
        WHEN @@max_connections != 151 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CAST(@@max_connections AS CHAR) AS current_value,
    '151' AS default_value,
    CASE
        WHEN @@max_connections = 1
            THEN 'Critical: maximum connections set to 1'
        WHEN @@max_connections != 151
            THEN CONCAT('Non-default maximum connections requiring verification. Current: ', @@max_connections, ', Default: 151')
        ELSE 'Maximum connections is at default value (151)'
    END AS message;
