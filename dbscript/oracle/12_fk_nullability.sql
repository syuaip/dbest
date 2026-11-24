-- Oracle Foreign Key Nullability Check
-- Identifies nullable columns that participate in foreign key constraints
SELECT
    'Foreign Key Nullability' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN tc.nullable = 'Y' THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN tc.nullable = 'Y' THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CASE
        WHEN tc.nullable = 'Y' THEN 'NULLABLE'
        ELSE 'NOT NULL'
    END AS current_value,
    'NOT NULL' AS default_value,
    CASE
        WHEN tc.nullable = 'Y' THEN cc.owner || '.' || cc.table_name || '.' || cc.column_name || ' - nullable foreign key column'
        ELSE cc.owner || '.' || cc.table_name || '.' || cc.column_name || ' - foreign key nullability check passed'
    END AS message
FROM DBA_CONS_COLUMNS cc
JOIN DBA_CONSTRAINTS c
    ON cc.owner = c.owner
    AND cc.constraint_name = c.constraint_name
    AND cc.table_name = c.table_name
JOIN DBA_TAB_COLUMNS tc
    ON cc.owner = tc.owner
    AND cc.table_name = tc.table_name
    AND cc.column_name = tc.column_name
WHERE c.constraint_type = 'R'
  AND cc.owner NOT IN ('SYS', 'SYSTEM', 'MDSYS', 'CTXSYS', 'XDB', 'WMSYS', 'DBSNMP', 'OUTLN', 'APPQOSSYS', 'DBSFWUSER')
ORDER BY cc.owner, cc.table_name, cc.column_name;
