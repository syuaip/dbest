-- Foreign Key Nullability Check
-- Flags foreign key columns that allow NULL values
-- Runs across ALL user databases, ordered by database size descending

IF OBJECT_ID('tempdb..#fk_results') IS NOT NULL DROP TABLE #fk_results;
CREATE TABLE #fk_results (
    db_name SYSNAME,
    db_size_mb BIGINT,
    total_fk_columns INT,
    nullable_fk_count INT
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
    FROM sys.foreign_key_columns fkc
    INNER JOIN sys.columns c
        ON fkc.parent_object_id = c.object_id
        AND fkc.parent_column_id = c.column_id;

    SET @nullable = ISNULL(@nullable, 0);
    SET @total = ISNULL(@total, 0);

    INSERT INTO #fk_results (db_name, db_size_mb, total_fk_columns, nullable_fk_count)
    VALUES (DB_NAME(), ' + CAST(@db_size_mb AS NVARCHAR(20)) + N', @total, @nullable);
    ';

    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        INSERT INTO #fk_results (db_name, db_size_mb, total_fk_columns, nullable_fk_count)
        VALUES (@db_name, @db_size_mb, -1, -1);
    END CATCH

    FETCH NEXT FROM db_cursor INTO @db_name, @db_size_mb;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Return results ordered by database size descending
SELECT
    'Foreign Key Nullability' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN total_fk_columns = -1 THEN 'ERROR'
        WHEN total_fk_columns = 0 THEN 'PASSED'
        WHEN nullable_fk_count > 0 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN total_fk_columns = -1 THEN 'ADVISORY'
        WHEN total_fk_columns = 0 THEN 'OK'
        WHEN nullable_fk_count > 0 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    '[' + db_name + '] Nullable FK columns='
        + CAST(nullable_fk_count AS VARCHAR(10))
        + ', Total FK columns='
        + CAST(total_fk_columns AS VARCHAR(10))
        AS current_value,
    'All FK columns should be NOT NULL' AS default_value,
    CASE
        WHEN total_fk_columns = -1
            THEN 'Could not access database [' + db_name + ']'
        WHEN total_fk_columns = 0
            THEN '[' + db_name + '] No foreign key constraints found'
        WHEN nullable_fk_count > 0
            THEN '[' + db_name + '] '
                + CAST(nullable_fk_count AS VARCHAR(10))
                + ' nullable FK column(s) out of '
                + CAST(total_fk_columns AS VARCHAR(10))
                + ' total. FK columns should not allow NULL.'
        ELSE '[' + db_name + '] All '
            + CAST(total_fk_columns AS VARCHAR(10))
            + ' FK columns are non-nullable'
    END AS message
FROM #fk_results
ORDER BY db_size_mb DESC;

DROP TABLE #fk_results;
