-- Oracle Statistics Freshness Check
-- Checks when table statistics were last gathered
-- Flags tables with statistics older than 7 days or never analyzed
SELECT
    'Statistics Freshness' AS check_name,
    'TABLE' AS check_level,
    CASE
        WHEN last_analyzed IS NULL THEN 'FLAGGED'
        WHEN last_analyzed < SYSDATE - 7 THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN last_analyzed IS NULL THEN 'ADVISORY'
        WHEN last_analyzed < SYSDATE - 7 THEN 'ADVISORY'
        ELSE 'OK'
    END AS severity,
    CASE
        WHEN last_analyzed IS NULL THEN 'Never analyzed'
        ELSE TO_CHAR(last_analyzed, 'YYYY-MM-DD HH24:MI:SS')
    END AS current_value,
    'Within 7 days' AS default_value,
    CASE
        WHEN last_analyzed IS NULL THEN owner || '.' || table_name || ' - stale statistics - never analyzed'
        WHEN last_analyzed < SYSDATE - 7 THEN owner || '.' || table_name || ' - stale statistics - last updated on ' || TO_CHAR(last_analyzed, 'YYYY-MM-DD')
        ELSE owner || '.' || table_name || ' - statistics freshness check passed (last analyzed: ' || TO_CHAR(last_analyzed, 'YYYY-MM-DD') || ')'
    END AS message
FROM DBA_TABLES
WHERE owner NOT IN ('SYS', 'SYSTEM', 'MDSYS', 'CTXSYS', 'XDB', 'WMSYS', 'DBSNMP', 'OUTLN', 'APPQOSSYS', 'DBSFWUSER', 'REMOTE_SCHEDULER_AGENT', 'GSMADMIN_INTERNAL', 'LBACSYS', 'DVSYS', 'AUDSYS', 'OJVMSYS')
  AND table_name NOT LIKE 'BIN$%'
  AND temporary = 'N'
  AND nested = 'NO'
ORDER BY
    CASE
        WHEN last_analyzed IS NULL THEN 0
        WHEN last_analyzed < SYSDATE - 7 THEN 1
        ELSE 2
    END,
    owner, table_name;
