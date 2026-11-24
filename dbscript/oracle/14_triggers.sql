-- Oracle Trigger Check
-- Identifies tables with triggers defined
-- Recommends considering event-driven architecture alternatives
SELECT
    'Trigger Check' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN trigger_count > 0 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN trigger_count > 0 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    TO_CHAR(trigger_count) || ' trigger(s)' AS current_value,
    '0' AS default_value,
    CASE
        WHEN trigger_count > 0 THEN table_owner || '.' || table_name || ' - has triggers (' || trigger_names || ') - consider event-driven architecture'
        ELSE table_owner || '.' || table_name || ' - trigger check passed'
    END AS message
FROM (
    SELECT
        t.owner AS table_owner,
        t.table_name,
        COUNT(tr.trigger_name) AS trigger_count,
        LISTAGG(tr.trigger_name, ', ') WITHIN GROUP (ORDER BY tr.trigger_name) AS trigger_names
    FROM DBA_TABLES t
    LEFT JOIN DBA_TRIGGERS tr
        ON t.owner = tr.table_owner
        AND t.table_name = tr.table_name
    WHERE t.owner NOT IN ('SYS', 'SYSTEM', 'MDSYS', 'CTXSYS', 'XDB', 'WMSYS', 'DBSNMP', 'OUTLN', 'APPQOSSYS', 'DBSFWUSER')
      AND t.table_name NOT LIKE 'BIN$%'
      AND t.temporary = 'N'
      AND t.nested = 'NO'
    GROUP BY t.owner, t.table_name
)
WHERE trigger_count > 0
UNION ALL
SELECT
    'Trigger Check' AS check_name,
    'TABLE' AS check_level,
    'PASSED' AS status,
    'OK' AS severity,
    '0 triggers' AS current_value,
    '0' AS default_value,
    'No tables with triggers found' AS message
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1
    FROM DBA_TRIGGERS
    WHERE table_owner NOT IN ('SYS', 'SYSTEM', 'MDSYS', 'CTXSYS', 'XDB', 'WMSYS', 'DBSNMP', 'OUTLN', 'APPQOSSYS', 'DBSFWUSER')
);
