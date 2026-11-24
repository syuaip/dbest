-- Partition Check: Verify partition counts are within recommended range (50-200)
-- and use hash partitioning (HASH in SQL Server = partition function with RANGE)
DECLARE @partitioned_count INT;
DECLARE @flagged_count INT = 0;

SELECT @partitioned_count = COUNT(DISTINCT ps.name)
FROM sys.partition_schemes ps;

IF @partitioned_count = 0
BEGIN
    SELECT 
        'Partition Check' AS check_name,
        'DATABASE' AS check_level,
        'PASSED' AS status,
        'OK' AS severity,
        '0' AS current_value,
        '50-200 partitions with hash strategy' AS default_value,
        'No partitioned objects found in the database' AS message;
END
ELSE
BEGIN
    ;WITH PartitionInfo AS (
        SELECT 
            SCHEMA_NAME(o.schema_id) + '.' + o.name AS object_name,
            COUNT(p.partition_number) AS partition_count,
            pf.name AS partition_function,
            CASE 
                WHEN pf.type = 'R' THEN 'RANGE'
                WHEN pf.type = 'H' THEN 'HASH'
                ELSE 'OTHER'
            END AS partition_strategy
        FROM sys.partitions p
        INNER JOIN sys.objects o ON p.object_id = o.object_id
        INNER JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
        INNER JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
        INNER JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
        WHERE o.type IN ('U', 'V')
          AND i.index_id <= 1
        GROUP BY o.schema_id, o.name, pf.name, pf.type
    )
    SELECT 
        'Partition Check' AS check_name,
        'DATABASE' AS check_level,
        CASE 
            WHEN EXISTS (SELECT 1 FROM PartitionInfo WHERE partition_count < 50 OR partition_count > 200 OR partition_strategy <> 'HASH') THEN 'FLAGGED'
            ELSE 'PASSED'
        END AS status,
        CASE 
            WHEN EXISTS (SELECT 1 FROM PartitionInfo WHERE partition_count < 50 OR partition_count > 200 OR partition_strategy <> 'HASH') THEN 'ADVISORY'
            ELSE 'OK'
        END AS severity,
        CAST(@partitioned_count AS VARCHAR(10)) + ' partition scheme(s)' AS current_value,
        '50-200 partitions with hash strategy' AS default_value,
        CASE 
            WHEN EXISTS (SELECT 1 FROM PartitionInfo WHERE partition_count < 50 OR partition_count > 200)
                THEN 'Partition count outside recommended range (50-200) detected for one or more objects'
            WHEN EXISTS (SELECT 1 FROM PartitionInfo WHERE partition_strategy <> 'HASH')
                THEN 'Non-hash partition strategy detected — consider hash partitioning'
            ELSE 'All partitioned objects have partition counts within 50-200 range'
        END AS message;
END
