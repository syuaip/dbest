-- Statistics Freshness Check
-- Flags tables with statistics not updated within the past 7 days
-- Runs across ALL user databases, ordered by database size descending

IF OBJECT_ID('tempdb..#stats_results') IS NOT NULL DROP TABLE #stats_results;
CREATE TABLE #stats_results (
    db_name SYSNAME,
    db_size_mb BIGINT,
    total_tables INT,
    stale_count INT,
    never_updated_count INT
);

DECLARE @sql NVARCHAR(MAX);
DECLARE @db_name SYSNAME;
DECLARE @db_size_mb BIGINT;

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT d.name,
           SUM(CAST(mf.size AS BIGINT) * 8 / 1024) AS size_mb
    FROM sys.databases d
    INNER JOIN sys.master_files mf ON d.database_id = mf.database_id
    WHERE d.database_id > 4  -- exclude system databases
      AND d.state = 0        -- online only
    GROUP BY d.name
    ORDER BY size_mb DESC;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @db_name, @db_size_mb;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
    USE ' + QUOTENAME(@db_name) + N';
    DECLARE @total INT, @stale INT, @never INT;

    SELECT @total = COUNT(*) FROM sys.tables WHERE type = ''U'';

    SELECT @stale = COUNT(DISTINCT t.object_id)
    FROM sys.tables t
    INNER JOIN sys.stats s ON t.object_id = s.object_id
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
    WHERE t.type = ''U''
      AND sp.last_updated IS NOT NULL
      AND sp.last_updated < DATEADD(DAY, -7, GETDATE())
      AND NOT EXISTS (
        SELECT 1
        FROM sys.stats s2
        CROSS APPLY sys.dm_db_stats_properties(s2.object_id, s2.stats_id) sp2
        WHERE s2.object_id = t.object_id
          AND sp2.last_updated >= DATEADD(DAY, -7, GETDATE())
      );

    SELECT @never = COUNT(DISTINCT t.object_id)
    FROM sys.tables t
    WHERE t.type = ''U''
      AND NOT EXISTS (
        SELECT 1
        FROM sys.stats s
        CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
        WHERE s.object_id = t.object_id
          AND sp.last_updated IS NOT NULL
      );

    SET @stale = ISNULL(@stale, 0);
    SET @never = ISNULL(@never, 0);

    INSERT INTO #stats_results (db_name, db_size_mb, total_tables, stale_count, never_updated_count)
    VALUES (DB_NAME(), ' + CAST(@db_size_mb AS NVARCHAR(20)) + N', @total, @stale, @never);
    ';

    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        INSERT INTO #stats_results (db_name, db_size_mb, total_tables, stale_count, never_updated_count)
        VALUES (@db_name, @db_size_mb, -1, -1, -1);
    END CATCH

    FETCH NEXT FROM db_cursor INTO @db_name, @db_size_mb;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Return results ordered by database size descending
SELECT
    'Statistics Freshness' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN total_tables = -1 THEN 'ERROR'
        WHEN stale_count > 0 OR never_updated_count > 0 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN total_tables = -1 THEN 'ADVISORY'
        WHEN stale_count > 0 OR never_updated_count > 0 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    '[' + db_name + '] Stale (>7 days)='
        + CAST(stale_count AS VARCHAR(10))
        + ', Never updated='
        + CAST(never_updated_count AS VARCHAR(10))
        + ', Total tables='
        + CAST(total_tables AS VARCHAR(10))
        AS current_value,
    'Statistics updated within 7 days' AS default_value,
    CASE
        WHEN total_tables = -1
            THEN 'Could not access database [' + db_name + ']'
        WHEN stale_count > 0 AND never_updated_count > 0
            THEN '[' + db_name + '] '
                + CAST(stale_count AS VARCHAR(10))
                + ' table(s) have stale statistics (>7 days). '
                + CAST(never_updated_count AS VARCHAR(10))
                + ' table(s) never analyzed.'
        WHEN stale_count > 0
            THEN '[' + db_name + '] '
                + CAST(stale_count AS VARCHAR(10))
                + ' table(s) have stale statistics (>7 days)'
        WHEN never_updated_count > 0
            THEN '[' + db_name + '] '
                + CAST(never_updated_count AS VARCHAR(10))
                + ' table(s) have never been analyzed'
        ELSE '[' + db_name + '] All statistics up to date (within 7 days)'
    END AS message
FROM #stats_results
ORDER BY db_size_mb DESC;

DROP TABLE #stats_results;
