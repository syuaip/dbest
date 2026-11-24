-- MySQL Partition Check
-- Checks partition count (recommended 50-200) and partition method (hash preferred)

SELECT
    'Partition Check' AS check_name,
    'DATABASE' AS check_level,
    CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.PARTITIONS
            WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
              AND PARTITION_NAME IS NOT NULL
        ) THEN 'PASSED'
        WHEN EXISTS (
            SELECT 1
            FROM (
                SELECT TABLE_SCHEMA, TABLE_NAME, PARTITION_METHOD, COUNT(*) AS partition_count
                FROM information_schema.PARTITIONS
                WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                  AND PARTITION_NAME IS NOT NULL
                GROUP BY TABLE_SCHEMA, TABLE_NAME, PARTITION_METHOD
                HAVING COUNT(*) < 50 OR COUNT(*) > 200 OR PARTITION_METHOD != 'HASH'
            ) flagged
        ) THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.PARTITIONS
            WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
              AND PARTITION_NAME IS NOT NULL
        ) THEN 'OK'
        WHEN EXISTS (
            SELECT 1
            FROM (
                SELECT TABLE_SCHEMA, TABLE_NAME, PARTITION_METHOD, COUNT(*) AS partition_count
                FROM information_schema.PARTITIONS
                WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                  AND PARTITION_NAME IS NOT NULL
                GROUP BY TABLE_SCHEMA, TABLE_NAME, PARTITION_METHOD
                HAVING COUNT(*) < 50 OR COUNT(*) > 200 OR PARTITION_METHOD != 'HASH'
            ) flagged
        ) THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    COALESCE(
        (SELECT CONCAT(TABLE_SCHEMA, '.', TABLE_NAME, ': ', COUNT(*), ' partitions (', PARTITION_METHOD, ')')
         FROM information_schema.PARTITIONS
         WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
           AND PARTITION_NAME IS NOT NULL
         GROUP BY TABLE_SCHEMA, TABLE_NAME, PARTITION_METHOD
         HAVING COUNT(*) < 50 OR COUNT(*) > 200 OR PARTITION_METHOD != 'HASH'
         LIMIT 1),
        'No issues found'
    ) AS current_value,
    '50-200 partitions, HASH method' AS default_value,
    CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.PARTITIONS
            WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
              AND PARTITION_NAME IS NOT NULL
        ) THEN 'No partitioned objects found'
        WHEN EXISTS (
            SELECT 1
            FROM (
                SELECT TABLE_SCHEMA, TABLE_NAME, PARTITION_METHOD, COUNT(*) AS partition_count
                FROM information_schema.PARTITIONS
                WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                  AND PARTITION_NAME IS NOT NULL
                GROUP BY TABLE_SCHEMA, TABLE_NAME, PARTITION_METHOD
                HAVING COUNT(*) < 50 OR COUNT(*) > 200
            ) flagged
        ) THEN 'Partition count outside recommended range (50-200)'
        WHEN EXISTS (
            SELECT 1
            FROM (
                SELECT TABLE_SCHEMA, TABLE_NAME, PARTITION_METHOD, COUNT(*) AS partition_count
                FROM information_schema.PARTITIONS
                WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                  AND PARTITION_NAME IS NOT NULL
                GROUP BY TABLE_SCHEMA, TABLE_NAME, PARTITION_METHOD
                HAVING PARTITION_METHOD != 'HASH'
            ) flagged
        ) THEN 'Non-hash partition strategy - consider hash partitioning'
        ELSE 'All partitioned objects within recommended range and using hash partitioning'
    END AS message;
