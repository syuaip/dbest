-- Search Column Nullability Check
-- Flags indexed columns (non-PK indexes) that allow NULL values
-- Runs across ALL user databases, ordered by database size descending

IF OBJECT_ID('tempdb..#search_col_results') IS NOT NULL DROP TABLE #search_col_results;
CREATE TABLE #search_col_results (
    db_name SYSNAME,
    db_size_mb BIGINT,
    total_index_cols INT,
    nullable_index_cols INT
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
    DECLARE @nullable INT, @total INT;

    SELECT
        @nullable = SUM(CASE WHEN c.is_nullable = 1 THEN 1 ELSE 0 END),
        @total = COUNT(*)
    FROM sys.index_columns ic
    INNER JOIN sys.indexes i
        ON ic.object_id = i.object_id
        AND ic.index_id = i.index_id
    INNER JOIN sys.columns c
        ON ic.object_id = c.object_id
        AND ic.column_id = c.column_id
    INNER JOIN sys.tables t
        ON ic.object_id = t.object_id
    WHERE i.is_primary_key = 0
      AND i.type > 0
      AND t.type = ''U'';

    SET @nullable = ISNULL(@nullable, 0);
    SET @total = ISNULL(@total, 0);

    INSERT INTO #search_col_results (db_name, db_size_mb, total_index_cols, nullable_index_cols)
    VALUES (DB_NAME(), ' + CAST(@db_size_mb AS NVARCHAR(20)) + N', @total, @nullable);
    ';

    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        INSERT INTO #search_col_results (db_name, db_size_mb, total_index_cols, nullable_index_cols)
        VALUES (@db_name, @db_size_mb, -1, -1);
    END CATCH

    FETCH NEXT FROM db_cursor INTO @db_name, @db_size_mb;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Return results ordered by database size descending
SELECT
    'Search Column Nullability' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN total_index_cols = -1 THEN 'ERROR'
        WHEN total_index_cols = 0 THEN 'PASSED'
        WHEN nullable_index_cols > 0 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN total_index_cols = -1 THEN 'ADVISORY'
        WHEN total_index_cols = 0 THEN 'OK'
        WHEN nullable_index_cols > 0 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    '[' + db_name + '] Nullable indexed columns='
        + CAST(nullable_index_cols AS VARCHAR(10))
        + ', Total non-PK indexed columns='
        + CAST(total_index_cols AS VARCHAR(10))
        AS current_value,
    'All indexed columns should be NOT NULL' AS default_value,
    CASE
        WHEN total_index_cols = -1
            THEN 'Could not access database [' + db_name + ']'
        WHEN total_index_cols = 0
            THEN '[' + db_name + '] No non-PK indexes found'
        WHEN nullable_index_cols > 0
            THEN '[' + db_name + '] '
                + CAST(nullable_index_cols AS VARCHAR(10))
                + ' nullable search column(s) in non-PK indexes out of '
                + CAST(total_index_cols AS VARCHAR(10))
                + ' total. Search columns should not be nullable.'
        ELSE '[' + db_name + '] All '
            + CAST(total_index_cols AS VARCHAR(10))
            + ' non-PK indexed columns are non-nullable'
    END AS message
FROM #search_col_results
ORDER BY db_size_mb DESC;

DROP TABLE #search_col_results;
