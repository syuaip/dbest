-- Primary Key Check: Verify every user table has a single-column primary key
-- Runs across ALL user databases, ordered by database size descending
-- Flags tables missing PK (critical) or with composite PK (advisory)

IF OBJECT_ID('tempdb..#pk_results') IS NOT NULL DROP TABLE #pk_results;
CREATE TABLE #pk_results (
    db_name SYSNAME,
    db_size_mb BIGINT,
    total_tables INT,
    missing_pk INT,
    composite_pk INT
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
    DECLARE @missing INT, @composite INT, @total INT;

    SELECT @total = COUNT(*)
    FROM sys.tables WHERE type = ''U'';

    SELECT @missing = COUNT(*)
    FROM sys.tables t
    WHERE t.type = ''U''
      AND NOT EXISTS (
        SELECT 1 FROM sys.indexes i
        WHERE i.object_id = t.object_id
          AND i.is_primary_key = 1
      );

    SELECT @composite = COUNT(*)
    FROM (
        SELECT ic.object_id
        FROM sys.index_columns ic
        INNER JOIN sys.indexes i
            ON ic.object_id = i.object_id AND ic.index_id = i.index_id
        WHERE i.is_primary_key = 1
        GROUP BY ic.object_id
        HAVING COUNT(*) > 1
    ) x;

    SET @composite = ISNULL(@composite, 0);

    INSERT INTO #pk_results (db_name, db_size_mb, total_tables, missing_pk, composite_pk)
    VALUES (DB_NAME(), ' + CAST(@db_size_mb AS NVARCHAR(20)) + N', @total, @missing, @composite);
    ';

    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        -- Skip databases that cannot be accessed
        INSERT INTO #pk_results (db_name, db_size_mb, total_tables, missing_pk, composite_pk)
        VALUES (@db_name, @db_size_mb, -1, -1, -1);
    END CATCH

    FETCH NEXT FROM db_cursor INTO @db_name, @db_size_mb;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Return results ordered by database size descending
SELECT
    'Primary Key Check' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN missing_pk > 0 THEN 'FLAGGED'
        WHEN composite_pk > 0 THEN 'FLAGGED'
        WHEN total_tables = -1 THEN 'ERROR'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN missing_pk > 0 THEN 'CRITICAL'
        WHEN composite_pk > 0 THEN 'ADVISORY'
        WHEN total_tables = -1 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    '[' + db_name + '] Total tables='
        + CAST(total_tables AS VARCHAR(10))
        + ', Missing PK=' + CAST(missing_pk AS VARCHAR(10))
        + ', Composite PK=' + CAST(composite_pk AS VARCHAR(10))
        AS current_value,
    'All tables should have single-column primary key' AS default_value,
    CASE
        WHEN total_tables = -1
            THEN 'Could not access database [' + db_name + ']'
        WHEN missing_pk > 0 AND composite_pk > 0
            THEN '[' + db_name + '] '
                + CAST(missing_pk AS VARCHAR(10))
                + ' table(s) missing primary key. '
                + CAST(composite_pk AS VARCHAR(10))
                + ' table(s) have composite primary key.'
        WHEN missing_pk > 0
            THEN '[' + db_name + '] '
                + CAST(missing_pk AS VARCHAR(10))
                + ' table(s) missing primary key'
        WHEN composite_pk > 0
            THEN '[' + db_name + '] '
                + CAST(composite_pk AS VARCHAR(10))
                + ' table(s) have composite primary key'
        ELSE '[' + db_name + '] All '
            + CAST(total_tables AS VARCHAR(10))
            + ' tables have single-column primary keys'
    END AS message
FROM #pk_results
ORDER BY db_size_mb DESC;

DROP TABLE #pk_results;
