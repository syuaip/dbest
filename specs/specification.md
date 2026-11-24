# Database Best Practices Checker — Specification

## Problem statement

It is a challenge for an AWS Solutions Architect to know what is wrong — and what *may* be wrong — within a running database in a customer environment. Avoiding a database issue is better than fixing a running one; hence, checking database best practices whenever possible is preferable.

## Target database engines

The target database engines to check are:

| # | Engine | Working directory |
| --- | --- | --- |
| 1 | SQL Server | `mssql` |
| 2 | MySQL | `mysql` |
| 3 | Oracle | `oracle` |
| 4 | PostgreSQL | `pgsql` |
| 5 | MongoDB | `mongodb` |

## Behavior

The behavior of the database best practices checker script is as follows:

- The checker is a script or a command-line executable (CLI).
- The script name is `dbbpc`, with a file extension added based on the language used to create it (e.g. `.py` for Python, `.exe` for Windows).
- The script is called with the following parameters:

| Parameter | Name | Description |
| --- | --- | --- |
| a | `dbengine` | Database engine type |
| b | `dbhost` | Database hostname |
| c | `port` | Database port number |
| d | `username` | Database username |
| e | `password` | Database password. If the `password` parameter is not given, prompt for it with: `give me password to access the database:` |

### Directory usage

The engine determines which script directory is used:

| Engine (`dbengine`) | Script directory |
| --- | --- |
| `mongodb` | `mongodb` |
| `mssql` | `mssql` |
| `mysql` | `mysql` |
| `oracle` | `oracle` |
| `postgres` | `pgsql` |

### Rules and output

The rules for database best practices are defined in a Markdown file named `bestpractices.md`. Run the SQL scripts found in the relevant directory and write the output to an HTML file named `dbbpc.html`.

## Workflow

```text
Script called/run
    → Get parameters
    → Connect to the database instance
    → Run relevant SQL scripts
    → Write output as an HTML file for analysis by the AWS SA

```

## Build task

You are tasked to plan a build of this database best practices checker script.

### Target languages

| # | Language | Purpose |
| --- | --- | --- |
| 1 | Python | Ability to run as a script downloaded from GitHub |
| 2 | VB.NET | Ability to run as an executable on Windows |
| 3 | C#.NET | Ability to run as an executable on Amazon Linux |

### Tasks

1. Create scripts in each database engine directory based on each database best practices rule as defined in `bestpractices.md`.
2. Create a detailed specification of the script.
3. Create a ready-to-run script for Python, and ready-to-compile-and-run projects for VB.NET and C#.NET.

