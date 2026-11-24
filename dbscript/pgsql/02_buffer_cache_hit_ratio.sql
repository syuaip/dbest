-- PostgreSQL Buffer Cache Hit Ratio Check
-- Checks the buffer cache hit ratio using pg_stat_database

SELECT
    'Buffer Cache Hit Ratio' AS check_name,
    'INSTANCE' AS check_level,
    CASE
        WHEN (SELECT sum(blks_hit) + sum(blks_read) FROM pg_stat_database) = 0
            THEN 'INSUFFICIENT_DATA'
        WHEN (SELECT sum(blks_hit)::float / NULLIF(sum(blks_hit) + sum(blks_read), 0) * 100 FROM pg_stat_database) < 90
            THEN 'FLAGGED'
        ELSE 'PASSED'
    END AS status,
    CASE
        WHEN (SELECT sum(blks_hit) + sum(blks_read) FROM pg_stat_database) = 0
            THEN 'OK'
        WHEN (SELECT sum(blks_hit)::float / NULLIF(sum(blks_hit) + sum(blks_read), 0) * 100 FROM pg_stat_database) < 90
            THEN 'CRITICAL'
        ELSE 'OK'
    END AS severity,
    COALESCE(
        ROUND(
            (SELECT sum(blks_hit)::numeric / NULLIF(sum(blks_hit) + sum(blks_read), 0) * 100 FROM pg_stat_database),
            2
        )::text || '%',
        'N/A'
    ) AS current_value,
    '90%' AS default_value,
    CASE
        WHEN (SELECT sum(blks_hit) + sum(blks_read) FROM pg_stat_database) = 0
            THEN 'Unable to evaluate - no buffer activity recorded'
        WHEN (SELECT sum(blks_hit)::float / NULLIF(sum(blks_hit) + sum(blks_read), 0) * 100 FROM pg_stat_database) < 90
            THEN 'Instance may be under-provisioned - buffer cache hit ratio below 90%'
        ELSE 'Buffer cache hit ratio check passed'
    END AS message;
