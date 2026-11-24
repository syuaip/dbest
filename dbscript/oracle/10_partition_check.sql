-- Oracle Database-Level Partition Check
-- Checks partition count and strategy for partitioned tables and indexes
-- Flags when count outside 50-200 or when not using hash partitioning
SELECT
    'Partition Check' AS check_name,
    'DATABASE' AS check_level,
    CASE
        WHEN partition_count < 50 OR partition_count > 200 THEN 'FLAGGED'
        WHEN UPPER(partitioning_type) != 'HASH' THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN partition_count < 50 OR partition_count > 200 THEN 'ADVISORY'
        WHEN UPPER(partitioning_type) != 'HASH' THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    TO_CHAR(partition_count) || ' (' || partitioning_type || ')' AS current_value,
    '50-200 (HASH)' AS default_value,
    CASE
        WHEN partition_count < 50 OR partition_count > 200 THEN
            table_owner || '.' || table_name || ' - partition count outside recommended range (50-200): ' || partition_count || ' partitions'
        WHEN UPPER(partitioning_type) != 'HASH' THEN
            table_owner || '.' || table_name || ' - non-hash partition strategy: ' || partitioning_type || ' - consider hash partitioning'
        ELSE
            table_owner || '.' || table_name || ' - partition check passed (' || partition_count || ' ' || partitioning_type || ' partitions)'
    END AS message
FROM (
    SELECT
        pt.owner AS table_owner,
        pt.table_name,
        pt.partitioning_type,
        COUNT(tp.partition_name) AS partition_count
    FROM DBA_PART_TABLES pt
    JOIN DBA_TAB_PARTITIONS tp
        ON pt.owner = tp.table_owner AND pt.table_name = tp.table_name
    WHERE pt.owner NOT IN ('SYS', 'SYSTEM', 'MDSYS', 'CTXSYS', 'XDB', 'WMSYS', 'DBSNMP', 'OUTLN')
    GROUP BY pt.owner, pt.table_name, pt.partitioning_type
)
UNION ALL
SELECT
    'Partition Check' AS check_name,
    'DATABASE' AS check_level,
    'PASSED' AS status,
    'OK' AS severity,
    '0' AS current_value,
    '50-200 (HASH)' AS default_value,
    'No partitioned objects found' AS message
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM DBA_PART_TABLES
    WHERE owner NOT IN ('SYS', 'SYSTEM', 'MDSYS', 'CTXSYS', 'XDB', 'WMSYS', 'DBSNMP', 'OUTLN')
);
