# Database Best Practices Rules

This document defines the best-practice rules evaluated by the Database Evaluation & Summary Tool (DBEST). Rules are grouped into three levels — **Instance**, **Database**, and **Table** — and each rule keeps its original identifier (e.g. `1.b`, `3.g`) so the per-engine diagnostic scripts can map back to it.

---

## 1. Instance level

### 1.a — High availability

Production-level database instances must have a replica for high-availability purposes.

### 1.b — CPU utilization

CPU utilization monitoring should detect both over-provisioned and under-provisioned instances:

- A consistent CPU usage average **below 40%** over a period (e.g. a month) indicates an **over-provisioned** instance. Consider downsizing to reduce costs.
- A consistent CPU usage average **at or above 90%** over a period (e.g. a month) indicates an **under-provisioned** instance. Consider scaling up compute resources.
- Acceptable CPU utilization range is between **40% and 90%**.
- A minimum of **7 days** of data is required to make a reliable assessment.

### 1.c — Buffer cache hit ratio

A consistent Buffer Cache Hit Ratio average **below 90%** over a period (e.g. a day) indicates an under-provisioned instance.

### 1.d — Checkpoint configuration

Database checkpoint settings outside of their default value need to be challenged and verified.

| Engine | Setting(s) |
| --- | --- |
| PostgreSQL (`postgres`) | `checkpoint_timeout` & `max_wal_size` |
| SQL Server (`mssql`) | `recovery_interval` |
| MySQL (`mysql`) | `innodb_log_file_size` |
| Oracle (`oracle`) | `LOG_CHECKPOINT_TIMEOUT` |

### 1.e — Maximum connections

- A database instance maximum connection value outside of its default value needs to be challenged and verified.
- A database instance maximum connection value of **1** needs to be challenged and verified.

### 1.f — CPU count (available CPUs)

The number of CPUs available for use by the database must use the default value. Any value outside the default needs to be challenged and verified.

| Engine | Setting |
| --- | --- |
| PostgreSQL | `max_worker_processes` |
| SQL Server | `max worker threads` |
| MySQL | use CPU affinity |
| Oracle | `configure-core-count` |

### 1.g — CPU parallelism

The number of CPUs used for parallelism depends on the vCPU count and parallelism-related wait types.

**Decision rules**

1. If vCPU = 1, the parallelism check is unnecessary (0 or 1 is acceptable).
2. If vCPU < 4, parallelism should equal the vCPU count or 0 (automatic).
3. If vCPU is between 4 and 7, parallelism should be set to 4.
4. If vCPU is between 8 and 16, parallelism should be 8, 12, or 16 depending on wait-type pressure.
5. If vCPU >= 8, having parallelism set to 0 (automatic) is a finding.

**Wait types to monitor for Rule 4 guidance**

| Engine | Wait types |
| --- | --- |
| SQL Server | `CXPACKET` / `CXCONSUMER` waits |
| PostgreSQL | IPC wait events |
| MySQL | sync/mutex/rwlock waits (`wait/synch/%`) |
| Oracle | PX wait events |

**Parallelism settings**

| Engine | Setting |
| --- | --- |
| PostgreSQL | `max_parallel_workers` |
| SQL Server | `MaxDOP` & cost threshold |
| MySQL | `innodb_parallel_read_threads` |
| Oracle | `PARALLEL_MAX_SERVERS` |

### 1.h — Ad hoc query setting

The ad hoc query setting (at least on SQL Server / `mssql`) needs to be enabled. Find the equivalent setting on other database engines.

### 1.i — Memory settings

Find and show the memory setting of the database instance for the AWS SA to review.

| Engine | Setting(s) |
| --- | --- |
| PostgreSQL | `shared_buffers` & `effective_cache_size` |
| SQL Server | `max server memory` |
| MySQL | `innodb_buffer_pool_size` |
| Oracle | `MEMORY_MAX_TARGET` & `SGA_MAX_SIZE` |

### 1.j — SQL Server TempDB data files

For SQL Server, the TempDB data file count must correlate with MaxDOP and follow these rules:

- Target file count = `MIN(MaxDOP, 8)`. If `MaxDOP = 0`, use `MIN(logical_processors, 8)`.
- TempDB files must never exceed the logical processor count (too many = excessive overhead).
- Having only 1 TempDB file on a multi-core system is a finding (allocation contention risk).
- Files between the target and the logical processor count are acceptable if PAGELATCH contention warranted expansion.
- Monitor PAGELATCH waits (`PAGELATCH_UP`, `PAGELATCH_EX`, `PAGELATCH_SH`) — if > 10%, consider adding files up to the logical processor count.

---

## 2. Database level

### 2.a — Partitioning

Keep the database partition number at around **50–200** for manageability. Use hash partitioning whenever possible.

### 2.b — MySQL table size and count

For MySQL, maintain table size and count:

- Keep each table **less than 100 GB** in size.
- Keep the number of tables **less than 10K**.

### 2.c — SQL Server VLF count

For SQL Server, the total number of VLFs (Virtual Log Files) must be **less than 1000**.

---

## 3. Table level

### 3.a — Primary key presence

Every table has a unique and unchangeable primary key.

### 3.b — Single-column primary key

The primary key of a table should be a single column.

### 3.c — Foreign key nullability

Foreign key columns cannot be nullable.

### 3.d — Search column nullability

Columns used as search criteria should not be nullable.

### 3.e — Triggers

As a general rule, it is advised **not** to use any triggers. Consider or explore event-driven methods and architecture instead.

### 3.f — Table partitioning

Keep the table partition number at around **50–200** for manageability. Use hash partitioning whenever possible.

### 3.g — Statistics freshness

Keep tables' statistics regularly updated. Statistics not updated for a week or more need to be fixed.

**To be checked**

| Engine | Check |
| --- | --- |
| PostgreSQL | last date of table vacuuming |
| SQL Server | last date of table statistics update |
| MySQL | last date of running `ANALYZE TABLE` |

For PostgreSQL, also check these values:

- `autovacuum_freeze_max_age`
- `autovacuum_vacuum_threshold`
- `autovacuum_vacuum_scale_factor`
- `autovacuum_max_workers`

