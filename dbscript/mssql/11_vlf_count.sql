-- Virtual Log File (VLF) Count Check
-- Flags databases with 1000 or more VLFs
DECLARE @db_name NVARCHAR(256);
DECLARE @vlf_count INT;
DECLARE @max_vlf_count INT = 0;
DECLARE @max_vlf_db NVARCHAR(256) = '';
DECLARE @flagged_count INT = 0;
DECLARE @total_databases INT = 0;

-- Create temp table to hold VLF info
CREATE TABLE #VLFInfo (
    RecoveryUnitId INT,
    FileId INT,
    FileSize BIGINT,
    StartOffset BIGINT,
    FSeqNo BIGINT,
    [Status] INT,
    Parity INT,
    CreateLSN NUMERIC(38)
);

CREATE TABLE #VLFResults (
    DatabaseName NVARCHAR(256),
    VLFCount INT
);

DECLARE db_cursor CURSOR FOR
SELECT name FROM sys.databases
WHERE state_desc = 'ONLINE'
  AND database_id > 0;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @db_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        TRUNCATE TABLE #VLFInfo;
        INSERT INTO #VLFInfo
        EXEC('DBCC LOGINFO([' + @db_name + ']) WITH NO_INFOMSGS');
        
        SET @vlf_count = @@ROWCOUNT;
        INSERT INTO #VLFResults VALUES (@db_name, @vlf_count);
        
        SET @total_databases = @total_databases + 1;
        
        IF @vlf_count >= 1000
            SET @flagged_count = @flagged_count + 1;
        
        IF @vlf_count > @max_vlf_count
        BEGIN
            SET @max_vlf_count = @vlf_count;
            SET @max_vlf_db = @db_name;
        END
    END TRY
    BEGIN CATCH
        -- Skip databases we can't access
        SET @total_databases = @total_databases + 1;
    END CATCH
    
    FETCH NEXT FROM db_cursor INTO @db_name;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

SELECT 
    'VLF Count' AS check_name,
    'DATABASE' AS check_level,
    CASE 
        WHEN @flagged_count > 0 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE 
        WHEN @flagged_count > 0 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    'Max VLFs=' + CAST(@max_vlf_count AS VARCHAR(10)) + ' (db: ' + @max_vlf_db + ')' AS current_value,
    '< 1000' AS default_value,
    CASE 
        WHEN @flagged_count > 0 
            THEN 'VLF count exceeds threshold — ' + CAST(@flagged_count AS VARCHAR(10)) + ' database(s) have 1000+ VLFs. Highest: ' + @max_vlf_db + ' with ' + CAST(@max_vlf_count AS VARCHAR(10)) + ' VLFs. Recommended: less than 1000.'
        ELSE 'All ' + CAST(@total_databases AS VARCHAR(10)) + ' databases have VLF counts below 1000. Maximum: ' + CAST(@max_vlf_count AS VARCHAR(10)) + ' VLFs in ' + @max_vlf_db
    END AS message;

DROP TABLE #VLFInfo;
DROP TABLE #VLFResults;
