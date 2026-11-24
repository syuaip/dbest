-- MySQL Table Size and Count Check
-- Flags tables exceeding 100GB and databases with more than 10,000 tables

-- Check for oversized tables (> 100GB)
SELECT
    'Table Size Check' AS check_name,
    'DATABASE' AS check_level,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.TABLES
            WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
              AND TABLE_TYPE = 'BASE TABLE'
              AND (DATA_LENGTH + INDEX_LENGTH) > 107374182400
        ) THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.TABLES
            WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
              AND TABLE_TYPE = 'BASE TABLE'
              AND (DATA_LENGTH + INDEX_LENGTH) > 107374182400
        ) THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    COALESCE(
        (SELECT CONCAT(TABLE_SCHEMA, '.', TABLE_NAME, ' = ', ROUND((DATA_LENGTH + INDEX_LENGTH) / 1073741824, 2), 'GB')
         FROM information_schema.TABLES
         WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
           AND TABLE_TYPE = 'BASE TABLE'
           AND (DATA_LENGTH + INDEX_LENGTH) > 107374182400
         ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC
         LIMIT 1),
        'All tables under 100GB'
    ) AS current_value,
    '100GB' AS default_value,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.TABLES
            WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
              AND TABLE_TYPE = 'BASE TABLE'
              AND (DATA_LENGTH + INDEX_LENGTH) > 107374182400
        ) THEN 'Table size exceeds 100GB - consider partitioning or archiving'
        ELSE 'All tables are within acceptable size limits (under 100GB)'
    END AS message

UNION ALL

-- Check for excessive table count (> 10,000)
SELECT
    'Table Count Check' AS check_name,
    'DATABASE' AS check_level,
    CASE
        WHEN (SELECT COUNT(*) FROM information_schema.TABLES
              WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                AND TABLE_TYPE = 'BASE TABLE') > 10000
            THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN (SELECT COUNT(*) FROM information_schema.TABLES
              WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                AND TABLE_TYPE = 'BASE TABLE') > 10000
            THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CAST(
        (SELECT COUNT(*) FROM information_schema.TABLES
         WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
           AND TABLE_TYPE = 'BASE TABLE')
    AS CHAR) AS current_value,
    '10000' AS default_value,
    CASE
        WHEN (SELECT COUNT(*) FROM information_schema.TABLES
              WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                AND TABLE_TYPE = 'BASE TABLE') > 10000
            THEN CONCAT('Table count exceeds 10,000 (',
                (SELECT COUNT(*) FROM information_schema.TABLES
                 WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                   AND TABLE_TYPE = 'BASE TABLE'),
                ') - consider consolidation or schema separation')
        ELSE CONCAT('Table count is within acceptable limits: ',
            (SELECT COUNT(*) FROM information_schema.TABLES
             WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
               AND TABLE_TYPE = 'BASE TABLE'))
    END AS message;
