Best Practices Rules:

1 - Instance level:
a. Production level database instance requires to have a replica for high-availability purpose. 
b. CPU utilization monitoring should detect both over-provisioned and under-provisioned instances:
    - A consistent CPU usage value average below 40% for a period of time (e.g. a month) is an indicator of an over-provisioned instance. Consider downsizing to reduce costs.
    - A consistent CPU usage value average at or above 90% for a period of time (e.g. a month) is an indicator of an under-provisioned instance. Consider scaling up compute resources.
    - Acceptable CPU utilization range is between 40% and 90%.
    - Minimum 7 days of data is required to make a reliable assessment.
c. A consistent Buffer Cache Hit Ratio value average below 90% for a period of time (e.g. a day) is an indicator of an under-provisioned instance.
d. Database checkpoint outside of default value needs to be challenged and verified. 
    Checkpoint settings:
        Postgres/postgres – checkpoint_timeout & max_wal_size
        SQL Server/mssql – recovery_interval
        MySQL/mysql – set value of innodb_log_file_size  
        Oracle/oracle - LOG_CHECKPOINT_TIMEOUT 
d. Database instance maximum connection value outside of default value needs to be challenged and verified. 
e. Database instance maximum connection value of 1 needs to be challenged and verified. 
f. Number of CPU available to use by database must use default value. Outside of default value needs to be challenged and verified.
    Number of CPU available:
        Postgres – max_worker_processes
        SQL Server – max worker threads
        MySQL – use CPU affinity
        Oracle – configure-core-count 
g. Number of CPU parallelism to use by database depends on vCPU count and parallelism-related wait types.
    Decision rules:
        Rule 1: If vCPU = 1, parallelism check is unnecessary (0 or 1 is acceptable).
        Rule 2: If vCPU < 4, parallelism should equal vCPU count or 0 (automatic).
        Rule 3: If vCPU between 4 and 7, parallelism should be set to 4.
        Rule 4: If vCPU between 8 and 16, parallelism should be 8, 12, or 16 depending on wait type pressure.
        Rule 5: If vCPU >= 8, having parallelism set to 0 (automatic) is a finding.
    Wait types to monitor for Rule 4 guidance:
        SQL Server – CXPacket / CXCONSUMER waits
        PostgreSQL – IPC wait events
        MySQL – sync/mutex/rwlock waits (wait/synch/%)
        Oracle – PX wait events
    Number of CPU parallelism settings:
        Postgres – max_parallel_workers
        SQL Server – MaxDOP & cost threshold
        MySQL – innodb_parallel_read_threads
        Oracle - PARALLEL_MAX_SERVERS  
h. AdHoc query setting (at least on mssql/SQL Server) need to be enabled. Find similar setting on other database engines. 
i. Find and show memory setting of database instance for AWS SA to review
    Postgres – shared_buffers & effective_cache_size 
    SQL Server – max server memory
    MySQL – innodb_buffer_pool_size
    Oracle – MEMORY_MAX_TARGET & SGA_MAX_SIZE
j. For SQL Server, TempDB data file count must correlate with MaxDOP and follow these rules:
    - Target file count = MIN(MaxDOP, 8). If MaxDOP=0, use MIN(logical_processors, 8).
    - TempDB files must never exceed logical processor count (too many = excessive overhead).
    - Having only 1 TempDB file on a multi-core system is a finding (allocation contention risk).
    - Files between target and logical processor count are acceptable if PAGELATCH contention warranted expansion.
    - Monitor PAGELATCH waits (PAGELATCH_UP, PAGELATCH_EX, PAGELATCH_SH) — if > 10%, consider adding files up to logical processor count.

2 - Database level:
a. Keep database partition number at around 50-200 for manageability. Use hash partition whenever possible.
b. For MySQL, Maintain table size. Keep table less than 100GB in size. Maintain number of tables. Keep amount less than 10K.  
C. For SQL Server, total number of VLF (Virtual Log Files) must be less than 1000. 

3 - Table level:
a. Every table has a unique and unchangeable primary key. 
b. The primary key of a table will be a single column.
c. Foreign key columns cannot be nullable
d. Columns used as search criteria should not be nullable
e. As a general rule, it is advised to NOT use any triggers. Consider/explore event driven methods/architecture. 
f. Keep table partition number at around 50-200 for manageability. Use hash partition whenever possible.
g. Keep tables' statistics regularly updated. Statistics not being updated for a week or more needs to be fixed. 
    Need to be checked:
        Postgres – last date of table vacumming
        SQL Server – last date of table statistics update
        MySQL – last date of running ANALYZE TABLE 
    For Postgres, also check these values:
        Autovacuum_freeze_max_age
        Autovacuum_vacuum_threshold
        Autovacuum_vacuum_scale_factor
        Autovacuum_max_worker
