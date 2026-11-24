-- Oracle Search Column Nullability Check
-- Identifies nullable columns in non-primary-key indexes
SELECT
    'Search Column Nullability' AS check_name,
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
        WHEN tc.nullable = 'Y' THEN ic.table_owner || '.' || ic.table_name || '.' || ic.column_name || ' (index: ' || ic.index_name || ') - nullable search column'
        ELSE ic.table_owner || '.' || ic.table_name || '.' || ic.column_name || ' (index: ' || ic.index_name || ') - search column nullability check passed'
    END AS message
FROM DBA_IND_COLUMNS ic
JOIN DBA_INDEXES i
    ON ic.index_owner = i.owner
    AND ic.index_name = i.index_name
JOIN DBA_TAB_COLUMNS tc
    ON ic.table_owner = tc.owner
    AND ic.table_name = tc.table_name
    AND ic.column_name = tc.column_name
WHERE i.uniqueness != 'UNIQUE'
  AND NOT EXISTS (
      SELECT 1
      FROM DBA_CONSTRAINTS c
      WHERE c.owner = i.table_owner
        AND c.table_name = i.table_name
        AND c.constraint_type = 'P'
        AND c.index_name = i.index_name
  )
  AND ic.table_owner NOT IN ('SYS', 'SYSTEM', 'MDSYS', 'CTXSYS', 'XDB', 'WMSYS', 'DBSNMP', 'OUTLN', 'APPQOSSYS', 'DBSFWUSER')
ORDER BY ic.table_owner, ic.table_name, ic.column_name;
