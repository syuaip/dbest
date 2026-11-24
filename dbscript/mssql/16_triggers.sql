-- Trigger Check: Detect tables with triggers defined
-- Flags tables with triggers and recommends event-driven alternatives
-- Runs across ALL user databases, ordered by database size descending

IF OBJECT_ID('tempdb..#trigger_results') IS NOT NULL DROP TABLE #trigger_results;
CREATE TABLE #trigger_results (
    db_name SYSNAME,
    db_size_mb BIGINT,
    tables_with_triggers INT,
    total_triggers INT
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
    DECLARE @tbl_with_trg INT, @total_trg INT;

    SELECT
        @tbl_with_trg = COUNT(DISTINCT parent_id),
        @total_trg = COUNT(*)
    FROM sys.triggers
    WHERE parent_class = 1;

    SET @tbl_with_trg = ISNULL(@tbl_with_trg, 0);
    SET @total_trg = ISNULL(@total_trg, 0);

    INSERT INTO #trigger_results (db_name, db_size_mb, tables_with_triggers, total_triggers)
    VALUES (DB_NAME(), ' + CAST(@db_size_mb AS NVARCHAR(20)) + N', @tbl_with_trg, @total_trg);
    ';

    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        INSERT INTO #trigger_results (db_name, db_size_mb, tables_with_triggers, total_triggers)
        VALUES (@db_name, @db_size_mb, -1, -1);
    END CATCH

    FETCH NEXT FROM db_cursor INTO @db_name, @db_size_mb;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Return results ordered by database size descending
SELECT
    'Trigger Check' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN tables_with_triggers = -1 THEN 'ERROR'
        WHEN tables_with_triggers > 0 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN tables_with_triggers = -1 THEN 'ADVISORY'
        WHEN tables_with_triggers > 0 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    '[' + db_name + '] Tables with triggers='
        + CAST(tables_with_triggers AS VARCHAR(10))
        + ', Total triggers='
        + CAST(total_triggers AS VARCHAR(10))
        AS current_value,
    'No triggers (use event-driven architecture)' AS default_value,
    CASE
        WHEN tables_with_triggers = -1
            THEN 'Could not access database [' + db_name + ']'
        WHEN tables_with_triggers > 0
            THEN '[' + db_name + '] '
                + CAST(tables_with_triggers AS VARCHAR(10))
                + ' table(s) have triggers ('
                + CAST(total_triggers AS VARCHAR(10))
                + ' total) - consider event-driven architecture'
        ELSE '[' + db_name + '] No triggers found on any tables'
    END AS message
FROM #trigger_results
ORDER BY db_size_mb DESC;

DROP TABLE #trigger_results;
