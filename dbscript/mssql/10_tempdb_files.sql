-- TempDB File Count Check
-- Verifies TempDB data file count correlates with MaxDOP (or logical processors if MaxDOP=0)
DECLARE @tempdb_files INT;
DECLARE @maxdop INT;
DECLARE @logical_processors INT;
DECLARE @compare_value INT;

-- Count TempDB data files (type = 0 is data files)
SELECT @tempdb_files = COUNT(*)
FROM tempdb.sys.database_files
WHERE type = 0;

-- Get MaxDOP setting
SELECT @maxdop = CAST(value_in_use AS INT)
FROM sys.configurations
WHERE name = 'max degree of parallelism';

-- Get logical processor count
SELECT @logical_processors = cpu_count
FROM sys.dm_os_sys_info;

-- If MaxDOP is 0, compare against logical processors
SET @compare_value = CASE WHEN @maxdop = 0 THEN @logical_processors ELSE @maxdop END;

SELECT 
    'TempDB File Count' AS check_name,
    'INSTANCE' AS check_level,
    CASE 
        WHEN @tempdb_files IS NULL OR @compare_value IS NULL THEN 'ERROR'
        WHEN @tempdb_files <> @compare_value THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE 
        WHEN @tempdb_files IS NULL OR @compare_value IS NULL THEN 'ADVISORY'
        WHEN @tempdb_files <> @compare_value THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    'TempDB files=' + CAST(ISNULL(@tempdb_files, 0) AS VARCHAR(10)) + ', MaxDOP=' + CAST(ISNULL(@maxdop, 0) AS VARCHAR(10)) + ', CPUs=' + CAST(ISNULL(@logical_processors, 0) AS VARCHAR(10)) AS current_value,
    'TempDB files should equal MaxDOP (or CPU count if MaxDOP=0)' AS default_value,
    CASE 
        WHEN @tempdb_files IS NULL OR @compare_value IS NULL 
            THEN 'Unable to retrieve TempDB file count or MaxDOP setting'
        WHEN @tempdb_files <> @compare_value 
            THEN 'TempDB file count does not correlate with MaxDOP — current TempDB files: ' + CAST(@tempdb_files AS VARCHAR(10)) + ', MaxDOP: ' + CAST(@maxdop AS VARCHAR(10)) + CASE WHEN @maxdop = 0 THEN ' (using CPU count: ' + CAST(@logical_processors AS VARCHAR(10)) + ')' ELSE '' END
        ELSE 'TempDB file count (' + CAST(@tempdb_files AS VARCHAR(10)) + ') correlates with ' + CASE WHEN @maxdop = 0 THEN 'logical processor count (' + CAST(@logical_processors AS VARCHAR(10)) + ')' ELSE 'MaxDOP (' + CAST(@maxdop AS VARCHAR(10)) + ')' END
    END AS message;
