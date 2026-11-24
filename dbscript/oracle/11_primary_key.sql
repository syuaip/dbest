-- Oracle Primary Key Check
-- Identifies tables missing primary keys or with composite primary keys
SELECT
    'Primary Key Check' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN pk_column_count = 0 THEN 'FLAGGED'
        WHEN pk_column_count > 1 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN pk_column_count = 0 THEN 'CRITICAL'
        WHEN pk_column_count > 1 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CASE
        WHEN pk_column_count = 0 THEN 'No PK'
        ELSE TO_CHAR(pk_column_count) || ' column(s): ' || pk_columns
    END AS current_value,
    'Single-column PK' AS default_value,
    CASE
        WHEN pk_column_count = 0 THEN owner || '.' || table_name || ' - missing primary key'
        WHEN pk_column_count > 1 THEN owner || '.' || table_name || ' - composite primary key (' || pk_columns || ') - single-column primary key recommended'
        ELSE owner || '.' || table_name || ' - primary key check passed'
    END AS message
FROM (
    SELECT
        t.owner,
        t.table_name,
        NVL(pk.pk_column_count, 0) AS pk_column_count,
        NVL(pk.pk_columns, 'N/A') AS pk_columns
    FROM DBA_TABLES t
    LEFT JOIN (
        SELECT
            cc.owner,
            cc.table_name,
            COUNT(cc.column_name) AS pk_column_count,
            LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position) AS pk_columns
        FROM DBA_CONS_COLUMNS cc
        JOIN DBA_CONSTRAINTS c
            ON cc.owner = c.owner
            AND cc.constraint_name = c.constraint_name
            AND cc.table_name = c.table_name
        WHERE c.constraint_type = 'P'
        GROUP BY cc.owner, cc.table_name
    ) pk ON t.owner = pk.owner AND t.table_name = pk.table_name
    WHERE t.owner NOT IN ('SYS', 'SYSTEM', 'MDSYS', 'CTXSYS', 'XDB', 'WMSYS', 'DBSNMP', 'OUTLN', 'APPQOSSYS', 'DBSFWUSER', 'REMOTE_SCHEDULER_AGENT', 'GSMADMIN_INTERNAL', 'LBACSYS', 'DVSYS', 'AUDSYS', 'OJVMSYS')
      AND t.table_name NOT LIKE 'BIN$%'
      AND t.temporary = 'N'
      AND t.nested = 'NO'
);
