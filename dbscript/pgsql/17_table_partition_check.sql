-- PostgreSQL Table-Level Partition Check
-- Checks individual table partition counts and strategies

WITH partitioned_tables AS (
    SELECT
        n.nspname AS schema_name,
        c.relname AS table_name,
        p.partstrat AS partition_strategy,
        (SELECT count(*) FROM pg_inherits i WHERE i.inhparent = c.oid) AS partition_count
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_partitioned_table p ON p.partrelid = c.oid
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
        AND c.relkind = 'p'
)
SELECT
    'Table Partition Check - ' || schema_name || '.' || table_name AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN partition_count < 50 OR partition_count > 200 THEN 'FLAGGED'
        WHEN partition_strategy != 'h' THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN partition_count < 50 OR partition_count > 200 THEN 'ADVISORY'
        WHEN partition_strategy != 'h' THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    'partitions: ' || partition_count::text || ', strategy: ' ||
        CASE partition_strategy
            WHEN 'h' THEN 'hash'
            WHEN 'l' THEN 'list'
            WHEN 'r' THEN 'range'
            ELSE 'unknown'
        END AS current_value,
    '50-200 partitions, hash strategy' AS default_value,
    CASE
        WHEN partition_count < 50 OR partition_count > 200
            THEN schema_name || '.' || table_name || ' - table partition count outside recommended range (50-200), current: ' || partition_count::text
        WHEN partition_strategy != 'h'
            THEN schema_name || '.' || table_name || ' - non-hash table partition strategy - consider hash partitioning'
        ELSE schema_name || '.' || table_name || ' - table partition check passed'
    END AS message
FROM partitioned_tables

UNION ALL

SELECT
    'Table Partition Check' AS check_name,
    'TABLE' AS check_level,
    'PASSED' AS status,
    'OK' AS severity,
    'N/A' AS current_value,
    'N/A' AS default_value,
    'No partitioned tables found' AS message
WHERE NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_partitioned_table p ON p.partrelid = c.oid
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
        AND c.relkind = 'p'
);
