# DBEST — Database Evaluation & Summary Tool

> A self-service, read-only diagnostic that checks a running database against configuration best practices and produces a color-coded HTML report.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.9+](https://img.shields.io/badge/python-3.9%2B-blue.svg)](https://www.python.org/)
[![.NET 8.0](https://img.shields.io/badge/.NET-8.0-512BD4.svg)](https://dotnet.microsoft.com/)
[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-5391FE.svg)](https://github.com/PowerShell/PowerShell)

DBEST connects to a database instance, runs a curated set of **read-only** diagnostic
scripts, evaluates the results against a documented rule set, and writes a single
self-contained HTML report you can read, share, or feed into an LLM for a remediation plan.

It is engine-aware across **SQL Server, PostgreSQL, MySQL, Oracle, and MongoDB**, and ships
in four interchangeable implementations (Python, C#/.NET, VB.NET, PowerShell) that share the
same CLI, the same SQL script packs, and the same report format.

---

## Table of Contents

- [Why DBEST](#why-dbest)
- [Features](#features)
- [How it works](#how-it-works)
- [Supported engines](#supported-engines)
- [Repository layout](#repository-layout)
- [Quick start](#quick-start)
- [CLI reference](#cli-reference)
- [The report](#the-report)
- [What it checks](#what-it-checks)
- [Writing your own checks](#writing-your-own-checks)
- [Security & safety](#security--safety)
- [Development & testing](#development--testing)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Why DBEST

Spotting what is wrong — or *about to be* wrong — inside a running database usually requires a
specialist and a lot of manual query-running. DBEST packages that expertise into a single
command. Point it at an instance and in seconds you get a prioritized, human-readable
assessment of high-availability, performance, memory, storage, schema, and statistics
hygiene — without modifying a single row.

Avoiding a database problem is cheaper than fixing one. DBEST makes "check the best
practices first" the easy default.

## Features

- **One command, full assessment** — connect, run, report.
- **Five engines, one interface** — SQL Server, PostgreSQL, MySQL, Oracle, MongoDB.
- **Four implementations** — run as a Python script, a self-contained Linux/Windows
  executable (C#/.NET), a Windows executable (VB.NET), or a PowerShell script. Pick whatever
  fits the environment you're allowed to run in.
- **100% read-only** — every bundled script is a `SELECT`/diagnostic query. No writes, no DDL,
  no data exfiltration. Safe to run against production.
- **Data-driven rules** — checks live as plain `.sql` / `.js` files in per-engine folders and
  are discovered at runtime. Add, edit, or remove a check without touching application code.
- **Self-contained HTML report** — color-coded by severity, with current vs. recommended
  values and a plain-language explanation for every finding.
- **LLM-ready output** — hand the HTML to an assistant to generate a remediation plan,
  executive summary, or slide deck.

## How it works

```
                 ┌──────────┐   ┌──────────┐   ┌─────────────┐   ┌──────────┐   ┌──────────┐
   CLI args ───► │  Parse   ├──►│ Connect  ├──►│  Discover   ├──►│   Run    ├──►│ Generate │──► report.html
                 │  & valid.│   │ (engine  │   │  scripts    │   │ scripts  │   │  HTML    │
                 └──────────┘   │  driver) │   │ (per engine)│   │ (read-   │   │  report  │
                                └──────────┘   └─────────────┘   │  only)   │   └──────────┘
                                                                 └──────────┘
```

1. **Parse & validate** CLI arguments (engine, host, port, username, password).
2. **Connect** using the engine-appropriate driver with a short connection timeout.
3. **Discover** the numbered diagnostic scripts in the engine's folder (e.g. `mssql/`).
4. **Run** each script read-only and evaluate the result against the rule for that check.
5. **Generate** a single HTML file: `dbest_<engine>_<host>_<timestamp>.html`.

The rule set that drives evaluation is documented in
[`bestpractices.md`](specs/bestpractices.md), and the end-to-end behavior is described in
[`specification.md`](specs/specification.md).

## Supported engines

| Engine | Keyword (`--dbengine`) | Default port | Script folder | Checks |
|---|---|---|---|---|
| Microsoft SQL Server | `mssql` | 1433 | [`mssql/`](dbscript/mssql/) | 27 |
| PostgreSQL | `postgres` | 5432 | [`pgsql/`](dbscript/pgsql/) | 26 |
| Oracle | `oracle` | 1521 | [`oracle/`](dbscript/oracle/) | 25 |
| MySQL | `mysql` | 3306 | [`mysql/`](dbscript/mysql/) | 24 |
| MongoDB | `mongodb` | 27017 | [`mongodb/`](dbscript/mongodb/) | 7 |

> MongoDB checks are authored as `.js` scripts; all relational engines use `.sql`.

## Repository layout

```
.
├── dbscript/                 # Per-engine read-only diagnostic scripts,
│   ├── mssql/                #   numbered for deterministic run order
│   ├── pgsql/
│   ├── oracle/
│   ├── mysql/
│   └── mongodb/
│
├── dbest-python/             # Python implementation (reference)
│   ├── dbest.py              #   entry point
│   ├── dbest/                #   cli_parser, db_connector, script_discovery,
│   │                         #   script_runner, evaluators, report_generator, models
│   └── requirements.txt
│
├── dbest-linux-x64/          # C#/.NET 8 implementation (Linux executable)
│   ├── Program.cs            #   entry point + sources
│   ├── dbbpc.csproj
│   └── dbbpc.sln
│
├── dbest-win-x64/            # VB.NET implementation (Windows executable)
│   ├── Program.vb            #   entry point + sources
│   ├── dbbpc.vbproj
│   └── dbbpc.sln
│
└── dbest-powershell/         # PowerShell 7 implementation
    ├── dbest.ps1             #   entry point
    └── dbest/                #   module files
```

> The four implementations are feature-equivalent: same CLI, same script packs, same report.
> Choose the one that matches the runtime you're permitted to use on the target machine.

## Quick start

Clone the repository:

```bash
git clone https://github.com/syuaip/dbest.git
cd dbest
```

### Python

```bash
cd python
python -m pip install -r requirements.txt
python dbest.py --dbengine postgres --dbhost <host> --port 5432 --username <user>
# You will be prompted for the password if --password is omitted.
```

### C# / .NET 8 (Linux or Windows)

```bash
cd csharp
dotnet run --project dbbpc -- --dbengine mssql --dbhost <host> --port 1433 --username <user>
# Or publish a self-contained single-file executable:
dotnet publish dbbpc -c Release -r linux-x64   --self-contained
dotnet publish dbbpc -c Release -r win-x64     --self-contained
```

### VB.NET (Windows)

```bat
cd vbnet
dotnet run --project dbbpc -- --dbengine mysql --dbhost <host> --port 3306 --username <user>
```

### PowerShell 7+

```powershell
cd powershell
pwsh ./dbest.ps1 -DbEngine oracle -DbHost <host> -Port 1521 -Username <user>
```

## CLI reference

All implementations accept the same parameters:

| Parameter | Required | Description |
|---|---|---|
| `--dbengine` | Yes | One of `mssql`, `mysql`, `oracle`, `postgres`, `mongodb` |
| `--dbhost` | Yes | Hostname or IP of the target instance |
| `--port` | Yes | Port number (1–65535) |
| `--username` | Yes | Database username |
| `--password` | No | Password. **If omitted, you are prompted** so it never lands in shell history |

> PowerShell uses PascalCase switches (`-DbEngine`, `-DbHost`, `-Port`, `-Username`,
> `-Password`); the Python/.NET builds use `--dbengine`-style flags.

Example:

```bash
python dbest.py --dbengine postgres --dbhost db.internal.example.com --port 5432 --username readonly_user
# give me password to access the database: ********
# Report generated successfully: dbest_postgres_db.internal.example.com_2026-01-01T00-00-00Z.html
```

## The report

DBEST writes one self-contained HTML file to the current directory:

```
dbest_<engine>_<host>_<timestamp>.html
```

It contains:

- A summary header (engine, host, passed vs. flagged counts).
- One row per check with a **severity indicator**, the **current value**, the
  **recommended/default value**, and a plain-language **message**.
- Optional per-object detail rows (e.g. the specific tables missing a primary key).

### Severity legend

| Severity | Meaning | Suggested action |
|---|---|---|
| 🟢 **PASSED / OK** | Meets best practice | None |
| 🟡 **ADVISORY** | Non-default or sub-optimal setting | Review |
| 🔴 **CRITICAL / WARNING** | Risk to availability, integrity, or performance | Remediate promptly |
| ⚪ **INSUFFICIENT_DATA** | Not enough history to judge (e.g. < 7 days of metrics) | Re-run later |

## What it checks

Checks are grouped into three levels. The authoritative definitions live in
[`bestpractices.md`](specs/bestpractices.md); the highlights:

**Instance level**
- High-availability replica present for production instances
- CPU utilization right-sizing (over/under-provisioned detection, 40–90% band)
- Buffer cache hit ratio
- Checkpoint configuration vs. engine defaults
- Max connections sanity
- CPU count / worker configuration vs. default
- CPU parallelism tuned to vCPU count and parallelism wait types
- Ad-hoc workload / cursor-sharing settings
- Memory configuration surfaced for review
- SQL Server TempDB file count vs. MaxDOP and logical processors

**Database level**
- Partition count in a manageable range (hash partitioning preferred)
- MySQL table size and table count ceilings
- SQL Server VLF count under 1000

**Table level**
- Every table has a single-column, stable primary key
- Foreign-key columns are not nullable
- Search/filter columns are not nullable
- Triggers flagged for review (prefer event-driven designs)
- Statistics / vacuum / `ANALYZE` freshness (stale > 1 week is a finding)
- PostgreSQL autovacuum thresholds surfaced for review

## Writing your own checks

Checks are just files — no code change required.

1. Drop a new script into the engine folder using the numbered naming convention, e.g.
   `pgsql/27_my_new_check.sql`.
2. Make sure the query is **read-only** and returns the standard columns the report expects
   (`check_name`, `check_level`, `status`, `severity`, `current_value`, `default_value`,
   `message`). See any existing script, e.g. [`mssql/01_cpu_utilization.sql`](dbscript/mssql/01_cpu_utilization.sql),
   for the exact shape.
3. Run DBEST — the script is auto-discovered in sort order.

Only numerically-prefixed scripts (`NN_name.sql` / `.js`) are executed, so helper or scratch
files in the folder are ignored.

## Security & safety

- **Read-only by design.** Every bundled script performs diagnostics only — no `INSERT`,
  `UPDATE`, `DELETE`, or DDL. Safe to run against production instances.
- **No telemetry.** DBEST makes exactly one outbound connection — to the database you point it
  at. Nothing is sent anywhere else.
- **Credentials stay local.** Omit `--password` to be prompted, keeping secrets out of your
  shell history and process list. Prefer a dedicated least-privilege, read-only account.
- **The report may contain sensitive details** (hostnames, object names, configuration
  values). Treat generated `dbest_*.html` files as confidential and do not commit them.

## Development & testing

Each implementation ships with its own test suite.

```bash
# Python (pytest + hypothesis property tests)
cd python && python -m pip install -r requirements.txt && pytest

# C# / VB.NET (xUnit)
cd csharp && dotnet test
cd vbnet  && dotnet test

# PowerShell (Pester)
cd powershell && pwsh -c "Invoke-Pester ./tests"
```

The codebase is organized into small, single-responsibility modules —
`cli_parser`, `db_connector`, `script_discovery`, `script_runner`, `evaluators`,
`report_generator`, `models` — mirrored across all four languages, which keeps the behavior
consistent and the tests parallel.

## Roadmap

- [ ] Expand MongoDB check coverage toward parity with the relational engines
- [ ] Optional JSON output alongside HTML for programmatic pipelines
- [ ] CI workflow running all four test suites on every push
- [ ] Packaged releases (PyPI wheel, signed executables)

## Contributing

Contributions are welcome. Please:

1. Open an issue describing the check or fix.
2. Keep new diagnostic scripts **read-only** and engine-appropriate.
3. Add/adjust tests in the relevant implementation(s).
4. Avoid committing any real hostnames, credentials, or generated reports.

## License

Released under the [MIT License](LICENSE).

---

*DBEST is an independent, community diagnostic tool. The bundled rules are informed by widely
published database and cloud best-practice guidance; always validate findings against your own
environment and vendor documentation before acting on them.*
