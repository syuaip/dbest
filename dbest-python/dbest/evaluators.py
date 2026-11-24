"""Check evaluators for dbbpc diagnostic script results."""

from datetime import datetime, timedelta
from typing import Dict, List, Optional

from .models import CheckLevel, CheckResult, CheckStatus, DetailRow, ENGINE_DEFAULTS, Severity


def evaluate_cpu_utilization(results: dict) -> CheckResult:
    """Evaluate CPU utilization check results.

    Classifies instance CPU usage based on 30-day average:
    - Below 40%: over-provisioned (FLAGGED, ADVISORY)
    - 40% or above: passed (PASSED, OK)
    - Less than 30 days of data: insufficient data (INSUFFICIENT_DATA, ADVISORY)

    Args:
        results: Dict with keys:
            - avg_cpu_percent (float): Average CPU usage percentage over available period
            - days_available (int): Number of days of CPU data available

    Returns:
        CheckResult with check_level=INSTANCE and appropriate classification.

    Validates: Requirements 4.1, 4.2, 4.3, 4.4
    """
    avg_cpu = results.get("avg_cpu_percent", 0.0)
    days_available = results.get("days_available", 0)

    if days_available < 30:
        return CheckResult(
            script_name="cpu_utilization",
            check_name="CPU Utilization",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.INSUFFICIENT_DATA,
            severity=Severity.ADVISORY,
            current_value=f"{avg_cpu:.1f}%",
            default_value="",
            message=f"Insufficient data: only {days_available} days of CPU data available (30 days required)",
            details=[],
        )

    if avg_cpu < 40.0:
        return CheckResult(
            script_name="cpu_utilization",
            check_name="CPU Utilization",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.FLAGGED,
            severity=Severity.ADVISORY,
            current_value=f"{avg_cpu:.1f}%",
            default_value="",
            message=f"Instance is over-provisioned: average CPU usage is {avg_cpu:.1f}% over 30 days (below 40% threshold)",
            details=[],
        )

    return CheckResult(
        script_name="cpu_utilization",
        check_name="CPU Utilization",
        check_level=CheckLevel.INSTANCE,
        status=CheckStatus.PASSED,
        severity=Severity.OK,
        current_value=f"{avg_cpu:.1f}%",
        default_value="",
        message=f"CPU utilization check passed: average CPU usage is {avg_cpu:.1f}% over 30 days",
        details=[],
    )


def evaluate_high_availability(script_result: dict) -> CheckResult:
    """Evaluate high availability check based on replica count.

    Parses script results for replica count and classifies the instance
    as "missing replica" when count is 0, or "passed" when 1 or more.

    Args:
        script_result: Dict with keys:
            - replica_count (int or None): Number of configured replicas
            - error (str or None): Error message if query failed

    Returns:
        CheckResult with check_level=INSTANCE and appropriate status/severity.

    Validates: Requirements 6.1, 6.2, 6.3, 6.4
    """
    error = script_result.get("error")

    if error:
        return CheckResult(
            script_name="high_availability",
            check_name="High Availability Replica Check",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.ERROR,
            severity=Severity.ADVISORY,
            current_value="",
            default_value="",
            message=f"Unable to evaluate high availability: {error}",
            details=[],
        )

    replica_count = script_result.get("replica_count", 0)

    if replica_count == 0:
        return CheckResult(
            script_name="high_availability",
            check_name="High Availability Replica Check",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.FLAGGED,
            severity=Severity.CRITICAL,
            current_value=str(replica_count),
            default_value="",
            message="missing replica for high availability",
            details=[],
        )

    # replica_count >= 1
    return CheckResult(
        script_name="high_availability",
        check_name="High Availability Replica Check",
        check_level=CheckLevel.INSTANCE,
        status=CheckStatus.PASSED,
        severity=Severity.OK,
        current_value=str(replica_count),
        default_value="",
        message=f"High availability configured with {replica_count} replica(s)",
        details=[],
    )


def evaluate_buffer_cache_hit_ratio(result: dict) -> CheckResult:
    """Evaluate buffer cache hit ratio check results.

    Parses script results for average Buffer Cache Hit Ratio over 24 hours.
    Classifies as "under-provisioned" when below 90%, "passed" when 90% or above.
    Handles insufficient metrics and permissions errors.

    Args:
        result: A dict with keys:
            - avg_hit_ratio (float|None): Average buffer cache hit ratio percentage
            - hours_available (float|None): Hours of metrics data available
            - error (str|None): Error message if metrics unavailable

    Returns:
        CheckResult with check_level=INSTANCE and appropriate status/severity.

    Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5
    """
    # Handle error case (permissions or metrics unavailable)
    if result.get("error"):
        return CheckResult(
            script_name="buffer_cache_hit_ratio",
            check_name="Buffer Cache Hit Ratio",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.ERROR,
            severity=Severity.ADVISORY,
            current_value="N/A",
            default_value="",
            message=f"unable to evaluate — metric unavailable: {result['error']}",
            details=[],
        )

    avg_hit_ratio = result.get("avg_hit_ratio")
    hours_available = result.get("hours_available")

    # Build period note if less than 24 hours of data
    period_note = ""
    if hours_available is not None and hours_available < 24:
        period_note = f" (based on {hours_available:.1f} hours of available data)"

    current_value = f"{avg_hit_ratio:.2f}%"

    # Classify based on threshold
    if avg_hit_ratio < 90:
        return CheckResult(
            script_name="buffer_cache_hit_ratio",
            check_name="Buffer Cache Hit Ratio",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.FLAGGED,
            severity=Severity.ADVISORY,
            current_value=current_value,
            default_value="",
            message=f"under-provisioned{period_note}",
            details=[],
        )
    else:
        return CheckResult(
            script_name="buffer_cache_hit_ratio",
            check_name="Buffer Cache Hit Ratio",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.PASSED,
            severity=Severity.OK,
            current_value=current_value,
            default_value="",
            message=f"passed{period_note}",
            details=[],
        )


# Engine-specific CPU count parameter names
_CPU_COUNT_PARAMS = {
    "postgres": "max_worker_processes",
    "mssql": "max worker threads",
    "mysql": "CPU affinity",
    "oracle": "configure-core-count",
}


def evaluate_cpu_count_configuration(
    dbengine: str, current_value: str, default_value: str
) -> CheckResult:
    """Evaluate CPU count configuration check.

    Compares the CPU count setting against the engine default value.
    Flags non-default values as requiring verification.

    Args:
        dbengine: Database engine name (postgres, mssql, mysql, oracle).
        current_value: The current CPU count setting value, or None/empty on error.
        default_value: The engine default CPU count value.

    Returns:
        CheckResult with check_level=INSTANCE and appropriate status/severity.

    Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7
    """
    param_name = _CPU_COUNT_PARAMS.get(dbengine, "CPU count")

    # Handle error case: if current_value is None or empty, treat as error
    if current_value is None or current_value == "":
        return CheckResult(
            script_name="cpu_count_configuration",
            check_name="CPU Count Configuration",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.ERROR,
            severity=Severity.ADVISORY,
            current_value="",
            default_value=default_value,
            message=f"Unable to retrieve {param_name} for {dbengine}",
            details=[],
        )

    if current_value != default_value:
        return CheckResult(
            script_name="cpu_count_configuration",
            check_name="CPU Count Configuration",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.FLAGGED,
            severity=Severity.ADVISORY,
            current_value=current_value,
            default_value=default_value,
            message=f"non-default CPU count requiring verification",
            details=[],
        )

    return CheckResult(
        script_name="cpu_count_configuration",
        check_name="CPU Count Configuration",
        check_level=CheckLevel.INSTANCE,
        status=CheckStatus.PASSED,
        severity=Severity.OK,
        current_value=current_value,
        default_value=default_value,
        message=f"CPU count configuration ({param_name}) matches default",
        details=[],
    )


# Memory parameters expected per engine
MEMORY_PARAMS: Dict[str, list] = {
    "postgres": ["shared_buffers", "effective_cache_size"],
    "mssql": ["max server memory"],
    "mysql": ["innodb_buffer_pool_size"],
    "oracle": ["MEMORY_MAX_TARGET", "SGA_MAX_SIZE"],
}


def evaluate_memory_settings(
    dbengine: str, parsed_settings: Dict[str, Optional[str]]
) -> Optional[CheckResult]:
    """Evaluate memory settings display check.

    This is a display-only check that always passes. It retrieves and reports
    the current memory configuration parameters for the given engine.

    Args:
        dbengine: The database engine identifier (postgres, mssql, mysql, oracle, mongodb).
        parsed_settings: Dict mapping parameter names to their current values.
            A value of None indicates the parameter could not be retrieved.

    Returns:
        CheckResult with status=PASSED and severity=OK showing memory settings,
        or None if dbengine is "mongodb" (skip).

    Validates: Requirements 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7
    """
    if dbengine == "mongodb":
        return None

    expected_params = MEMORY_PARAMS.get(dbengine, [])

    # Build message parts for each memory parameter
    message_parts = []
    value_parts = []

    for param in expected_params:
        value = parsed_settings.get(param)
        if value is None:
            message_parts.append(f"{param}: could not be retrieved")
            value_parts.append(f"{param}=N/A")
        else:
            message_parts.append(f"{param}: {value}")
            value_parts.append(f"{param}={value}")

    message = "Memory settings — " + "; ".join(message_parts) if message_parts else "No memory parameters configured for this engine"
    current_value = "; ".join(value_parts) if value_parts else ""

    return CheckResult(
        script_name="memory_settings",
        check_name="Memory Settings Display",
        check_level=CheckLevel.INSTANCE,
        status=CheckStatus.PASSED,
        severity=Severity.OK,
        current_value=current_value,
        default_value="",
        message=message,
        details=[],
    )


def evaluate_tempdb_file_count(dbengine: str, results: dict) -> Optional[CheckResult]:
    """Evaluate TempDB file count correlation with MaxDOP (SQL Server only).

    Compares the number of TempDB data files against the MaxDOP value.
    When MaxDOP is 0, compares against the number of logical processors instead.

    Args:
        dbengine: The database engine identifier (e.g., "mssql", "postgres").
        results: Dict with keys:
            - tempdb_file_count (int): Total number of TempDB data files
            - maxdop (int): Current MaxDOP value
            - logical_processors (int): Number of logical processors available

    Returns:
        CheckResult with check_level=INSTANCE, or None if dbengine is not "mssql".

    Validates: Requirements 13.1, 13.2, 13.3, 13.4, 13.5
    """
    if dbengine != "mssql":
        return None

    tempdb_file_count = results.get("tempdb_file_count", 0)
    maxdop = results.get("maxdop", 0)
    logical_processors = results.get("logical_processors", 0)

    # Determine comparison value: if MaxDOP is 0, use logical processor count
    if maxdop == 0:
        comparison_value = logical_processors
    else:
        comparison_value = maxdop

    if tempdb_file_count == comparison_value:
        return CheckResult(
            script_name="tempdb_file_count",
            check_name="TempDB File Count",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.PASSED,
            severity=Severity.OK,
            current_value=str(tempdb_file_count),
            default_value=str(comparison_value),
            message=f"TempDB file count ({tempdb_file_count}) correlates with MaxDOP ({maxdop})",
            details=[],
        )

    return CheckResult(
        script_name="tempdb_file_count",
        check_name="TempDB File Count",
        check_level=CheckLevel.INSTANCE,
        status=CheckStatus.FLAGGED,
        severity=Severity.ADVISORY,
        current_value=str(tempdb_file_count),
        default_value=str(comparison_value),
        message=f"TempDB file count does not correlate with MaxDOP \u2014 current TempDB files: {tempdb_file_count}, MaxDOP: {maxdop}",
        details=[],
    )


def evaluate_adhoc_query_setting(dbengine: str, settings: Dict[str, str]) -> CheckResult:
    """Evaluate ad-hoc query optimization settings per engine.

    Checks engine-specific settings that control how the database handles
    unprepared/ad-hoc queries. Each engine has different parameters and
    optimized values.

    Optimized values per engine:
    - mssql: "optimize for ad hoc workloads" should be "1" (enabled)
    - postgres: plan_cache_mode should be "auto" or "force_custom_plan"
    - mysql: prepared_stmt_count and table_open_cache should be non-zero
    - oracle: CURSOR_SHARING should be "FORCE" or "SIMILAR"

    Args:
        dbengine: One of "mssql", "mysql", "oracle", "postgres"
        settings: Dict mapping parameter name to current value string

    Returns:
        CheckResult with check_level=INSTANCE and appropriate status/severity.

    Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5, 11.6
    """
    if dbengine == "mssql":
        value = settings.get("optimize for ad hoc workloads", "0")
        current_display = f"optimize for ad hoc workloads={value}"
        is_optimized = str(value) == "1"

    elif dbengine == "postgres":
        value = settings.get("plan_cache_mode", "")
        current_display = f"plan_cache_mode={value}"
        is_optimized = value.lower() in ("auto", "force_custom_plan")

    elif dbengine == "mysql":
        prepared_stmt_count = settings.get("prepared_stmt_count", "0")
        table_open_cache = settings.get("table_open_cache", "0")
        current_display = (
            f"prepared_stmt_count={prepared_stmt_count}, "
            f"table_open_cache={table_open_cache}"
        )
        try:
            stmt_count_val = int(prepared_stmt_count)
            cache_val = int(table_open_cache)
        except (ValueError, TypeError):
            stmt_count_val = 0
            cache_val = 0
        is_optimized = stmt_count_val > 0 and cache_val > 0

    elif dbengine == "oracle":
        value = settings.get("CURSOR_SHARING", "")
        current_display = f"CURSOR_SHARING={value}"
        is_optimized = value.upper() in ("FORCE", "SIMILAR")

    else:
        # Unsupported engine for this check
        current_display = ""
        is_optimized = True  # Skip/pass for unsupported engines

    if not is_optimized:
        return CheckResult(
            script_name="adhoc_query_setting",
            check_name="Ad-Hoc Query Setting Check",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.FLAGGED,
            severity=Severity.ADVISORY,
            current_value=current_display,
            default_value="",
            message="ad-hoc query optimization not enabled",
            details=[],
        )

    return CheckResult(
        script_name="adhoc_query_setting",
        check_name="Ad-Hoc Query Setting Check",
        check_level=CheckLevel.INSTANCE,
        status=CheckStatus.PASSED,
        severity=Severity.OK,
        current_value=current_display,
        default_value="",
        message="Ad-hoc query optimization is enabled",
        details=[],
    )


def evaluate_max_connections(script_result: dict) -> CheckResult:
    """Evaluate maximum connection check with three-way classification.

    Retrieves the max connection value per engine and classifies:
    - critical (value == 1): FLAGGED with CRITICAL severity
    - non-default (value differs from default, not 1): FLAGGED with ADVISORY severity
    - passed (value equals default): PASSED with OK severity
    - error (permissions/unsupported): ERROR with ADVISORY severity

    Args:
        script_result: Dict with keys:
            - max_connections (int or None): Current maximum connections value
            - default_value (int): Engine default maximum connections value
            - error (str or None): Error message if query failed

    Returns:
        CheckResult with check_level=INSTANCE and appropriate classification.

    Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5
    """
    error = script_result.get("error")

    if error:
        return CheckResult(
            script_name="max_connections",
            check_name="Maximum Connection Check",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.ERROR,
            severity=Severity.ADVISORY,
            current_value="",
            default_value=str(script_result.get("default_value", "")),
            message=f"Unable to evaluate maximum connections: {error}",
            details=[],
        )

    max_connections = script_result.get("max_connections", 0)
    default_value = script_result.get("default_value", 0)

    if max_connections == 1:
        return CheckResult(
            script_name="max_connections",
            check_name="Maximum Connection Check",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.FLAGGED,
            severity=Severity.CRITICAL,
            current_value=str(max_connections),
            default_value=str(default_value),
            message="critical: maximum connections set to 1",
            details=[],
        )

    if max_connections != default_value:
        return CheckResult(
            script_name="max_connections",
            check_name="Maximum Connection Check",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.FLAGGED,
            severity=Severity.ADVISORY,
            current_value=str(max_connections),
            default_value=str(default_value),
            message="non-default maximum connections requiring verification",
            details=[],
        )

    # max_connections == default_value
    return CheckResult(
        script_name="max_connections",
        check_name="Maximum Connection Check",
        check_level=CheckLevel.INSTANCE,
        status=CheckStatus.PASSED,
        severity=Severity.OK,
        current_value=str(max_connections),
        default_value=str(default_value),
        message="Maximum connections check passed",
        details=[],
    )


# Parallelism parameters per engine used for the CPU parallelism check
_PARALLELISM_PARAMS: Dict[str, Dict[str, str]] = {
    "postgres": {"max_parallel_workers": ENGINE_DEFAULTS["postgres"]["max_parallel_workers"]},
    "mssql": {
        "MaxDOP": ENGINE_DEFAULTS["mssql"]["MaxDOP"],
        "cost threshold for parallelism": ENGINE_DEFAULTS["mssql"]["cost threshold for parallelism"],
    },
    "mysql": {"innodb_parallel_read_threads": ENGINE_DEFAULTS["mysql"]["innodb_parallel_read_threads"]},
    "oracle": {"PARALLEL_MAX_SERVERS": ENGINE_DEFAULTS["oracle"]["PARALLEL_MAX_SERVERS"]},
}


def evaluate_cpu_parallelism(dbengine: str, settings: Dict[str, str]) -> CheckResult:
    """Evaluate CPU parallelism configuration check.

    Uses INVERSE logic compared to other default-comparison checks:
    - Flag when current_value EQUALS default (parallelism hasn't been tuned)
    - Pass when current_value DIFFERS from default (it's been customized)

    For mssql: flag if EITHER MaxDOP or cost threshold uses its default value.

    Args:
        dbengine: One of "postgres", "mssql", "mysql", "oracle".
        settings: Dict mapping parameter name to its current value as a string.

    Returns:
        CheckResult with check_level=INSTANCE and appropriate status/severity.

    Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7
    """
    defaults = _PARALLELISM_PARAMS.get(dbengine, {})

    # Build a string representation of current values for the result
    current_values_parts = [f"{param}={settings.get(param, '')}" for param in defaults]
    current_value_str = ", ".join(current_values_parts)

    # Check if any setting still uses its default value
    any_default = False
    for param, default_val in defaults.items():
        current_val = settings.get(param, "")
        if current_val == default_val:
            any_default = True
            break

    if any_default:
        return CheckResult(
            script_name="cpu_parallelism",
            check_name="CPU Parallelism Configuration Check",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.FLAGGED,
            severity=Severity.ADVISORY,
            current_value=current_value_str,
            default_value=", ".join(f"{p}={v}" for p, v in defaults.items()),
            message="CPU parallelism using default value \u2014 consider tuning",
            details=[],
        )

    return CheckResult(
        script_name="cpu_parallelism",
        check_name="CPU Parallelism Configuration Check",
        check_level=CheckLevel.INSTANCE,
        status=CheckStatus.PASSED,
        severity=Severity.OK,
        current_value=current_value_str,
        default_value=", ".join(f"{p}={v}" for p, v in defaults.items()),
        message="CPU parallelism configured with non-default values",
        details=[],
    )

def evaluate_mysql_table_size_and_count(
    dbengine: str, parsed_results: dict
) -> Optional[CheckResult]:
    """Evaluate MySQL table size and count check.

    Retrieves table sizes (data + index) and total table count for MySQL databases.
    Flags tables exceeding 100GB and flags when total table count exceeds 10,000.

    Args:
        dbengine: The database engine identifier.
        parsed_results: Dict with keys:
            - tables (list): List of dicts with 'name' (str) and 'size_bytes' (int)
            - total_table_count (int): Total number of tables in the database

    Returns:
        CheckResult with check_level=DATABASE and appropriate status/severity,
        or None if dbengine is not "mysql".

    Validates: Requirements 15.1, 15.2, 15.3, 15.4, 15.5, 15.6
    """
    if dbengine != "mysql":
        return None

    tables = parsed_results.get("tables", [])
    total_table_count = parsed_results.get("total_table_count", 0)

    # 100GB threshold in bytes
    size_threshold = 107_374_182_400

    # Find tables exceeding 100GB
    oversized_tables = [
        t for t in tables if t.get("size_bytes", 0) > size_threshold
    ]

    # Check if table count exceeds 10,000
    count_exceeded = total_table_count > 10000

    # Build details for flagged items
    details = []
    for t in oversized_tables:
        size_gb = t["size_bytes"] / (1024 ** 3)
        details.append(
            DetailRow(
                object_name=t.get("name", "unknown"),
                column_name="",
                finding="table size exceeds 100GB \u2014 consider partitioning or archiving",
                value=f"{size_gb:.2f} GB",
            )
        )

    if count_exceeded:
        details.append(
            DetailRow(
                object_name="database",
                column_name="",
                finding="table count exceeds 10,000 \u2014 consider consolidation or schema separation",
                value=str(total_table_count),
            )
        )

    if oversized_tables or count_exceeded:
        messages = []
        if oversized_tables:
            table_names = ", ".join(t.get("name", "unknown") for t in oversized_tables)
            messages.append(
                f"table size exceeds 100GB \u2014 consider partitioning or archiving"
            )
        if count_exceeded:
            messages.append(
                f"table count exceeds 10,000 \u2014 consider consolidation or schema separation"
            )

        return CheckResult(
            script_name="table_size_and_count",
            check_name="MySQL Table Size and Count Check",
            check_level=CheckLevel.DATABASE,
            status=CheckStatus.FLAGGED,
            severity=Severity.ADVISORY,
            current_value=f"tables: {total_table_count}, oversized: {len(oversized_tables)}",
            default_value="",
            message="; ".join(messages),
            details=details,
        )

    return CheckResult(
        script_name="table_size_and_count",
        check_name="MySQL Table Size and Count Check",
        check_level=CheckLevel.DATABASE,
        status=CheckStatus.PASSED,
        severity=Severity.OK,
        current_value=f"tables: {total_table_count}, oversized: 0",
        default_value="",
        message="All tables under 100GB and table count within limits",
        details=[],
    )


# Engine-specific checkpoint parameter names
_CHECKPOINT_PARAMS: Dict[str, list] = {
    "postgres": ["checkpoint_timeout", "max_wal_size"],
    "mssql": ["recovery_interval"],
    "mysql": ["innodb_log_file_size"],
    "oracle": ["LOG_CHECKPOINT_TIMEOUT"],
}


# Autovacuum parameters for PostgreSQL with their default values
_AUTOVACUUM_PARAMS: Dict[str, str] = {
    "autovacuum_freeze_max_age": ENGINE_DEFAULTS["postgres"]["autovacuum_freeze_max_age"],
    "autovacuum_vacuum_threshold": ENGINE_DEFAULTS["postgres"]["autovacuum_vacuum_threshold"],
    "autovacuum_vacuum_scale_factor": ENGINE_DEFAULTS["postgres"]["autovacuum_vacuum_scale_factor"],
    "autovacuum_max_workers": ENGINE_DEFAULTS["postgres"]["autovacuum_max_workers"],
}


def evaluate_autovacuum_configuration(
    dbengine: str, parsed_settings: Dict[str, str]
) -> Optional[CheckResult]:
    """Evaluate PostgreSQL autovacuum configuration check.

    Compares current autovacuum parameter values against PostgreSQL defaults.
    Flags any non-default values as requiring verification.

    Args:
        dbengine: Database engine name (postgres, mssql, mysql, oracle, mongodb).
        parsed_settings: Dict mapping parameter_name to current_value.

    Returns:
        CheckResult with check_level=DATABASE and appropriate status/severity,
        or None if dbengine is not "postgres" (skip).

    Validates: Requirements 23.1, 23.2, 23.3, 23.4, 23.5, 23.6, 23.7
    """
    if dbengine != "postgres":
        return None

    # Collect mismatches
    mismatched = []
    current_parts = []
    default_parts = []

    for param, default_val in _AUTOVACUUM_PARAMS.items():
        current_val = parsed_settings.get(param, "")
        current_parts.append(f"{param}={current_val}")
        default_parts.append(f"{param}={default_val}")
        if current_val != default_val:
            mismatched.append(param)

    current_value = "; ".join(current_parts)
    default_value = "; ".join(default_parts)

    if mismatched:
        return CheckResult(
            script_name="autovacuum_configuration",
            check_name="Autovacuum Configuration Check",
            check_level=CheckLevel.DATABASE,
            status=CheckStatus.FLAGGED,
            severity=Severity.ADVISORY,
            current_value=current_value,
            default_value=default_value,
            message="non-default autovacuum configuration requiring verification",
            details=[],
        )

    return CheckResult(
        script_name="autovacuum_configuration",
        check_name="Autovacuum Configuration Check",
        check_level=CheckLevel.DATABASE,
        status=CheckStatus.PASSED,
        severity=Severity.OK,
        current_value=current_value,
        default_value=default_value,
        message="Autovacuum configuration matches PostgreSQL defaults",
        details=[],
    )


def evaluate_checkpoint_configuration(
    dbengine: str, parsed_settings: Dict[str, str]
) -> Optional[CheckResult]:
    """Evaluate checkpoint configuration check.

    Compares current checkpoint parameter values against engine defaults.
    Flags any non-default values as requiring verification.

    Args:
        dbengine: Database engine name (postgres, mssql, mysql, oracle, mongodb).
        parsed_settings: Dict mapping parameter_name to current_value.

    Returns:
        CheckResult with check_level=INSTANCE and appropriate status/severity,
        or None if dbengine is "mongodb" (skip).

    Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7
    """
    if dbengine == "mongodb":
        return None

    checkpoint_params = _CHECKPOINT_PARAMS.get(dbengine, [])
    engine_defaults = ENGINE_DEFAULTS.get(dbengine, {})

    # Collect mismatches
    mismatched = []
    current_parts = []
    default_parts = []

    for param in checkpoint_params:
        current_val = parsed_settings.get(param, "")
        default_val = engine_defaults.get(param, "")
        current_parts.append(f"{param}={current_val}")
        default_parts.append(f"{param}={default_val}")
        if current_val != default_val:
            mismatched.append(param)

    current_value = "; ".join(current_parts)
    default_value = "; ".join(default_parts)

    if mismatched:
        return CheckResult(
            script_name="checkpoint_configuration",
            check_name="Checkpoint Configuration Check",
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.FLAGGED,
            severity=Severity.ADVISORY,
            current_value=current_value,
            default_value=default_value,
            message="non-default checkpoint configuration requiring verification",
            details=[],
        )

    return CheckResult(
        script_name="checkpoint_configuration",
        check_name="Checkpoint Configuration Check",
        check_level=CheckLevel.INSTANCE,
        status=CheckStatus.PASSED,
        severity=Severity.OK,
        current_value=current_value,
        default_value=default_value,
        message="Checkpoint configuration matches engine defaults",
        details=[],
    )


def evaluate_partition_check(partitioned_objects: List[Dict[str, object]]) -> List[CheckResult]:
    """Evaluate database-level partition check for partitioned objects.

    Checks each partitioned object's partition count and strategy:
    - Flag when partition count < 50 or > 200
    - Flag when partition strategy is not "hash"
    - Pass when count is 50-200 inclusive AND strategy is "hash"
    - If no partitioned objects exist, return single PASSED with note

    Args:
        partitioned_objects: List of dicts, each with keys:
            - object_name (str): Name of the partitioned object
            - partition_count (int): Number of partitions
            - partition_strategy (str): Partitioning strategy (e.g., "hash", "range", "list")

    Returns:
        List of CheckResult objects (one per object, or a single PASSED if no
        partitioned objects exist).

    Validates: Requirements 14.1, 14.2, 14.3, 14.4, 14.5
    """
    if not partitioned_objects:
        return [
            CheckResult(
                script_name="partition_check",
                check_name="Database Partition Check",
                check_level=CheckLevel.DATABASE,
                status=CheckStatus.PASSED,
                severity=Severity.OK,
                current_value="",
                default_value="",
                message="no partitioned objects found",
                details=[],
            )
        ]

    results: List[CheckResult] = []

    for obj in partitioned_objects:
        object_name = obj.get("object_name", "unknown")
        partition_count = obj.get("partition_count", 0)
        partition_strategy = obj.get("partition_strategy", "")

        findings: List[str] = []

        # Check partition count range
        count_outside_range = partition_count < 50 or partition_count > 200

        # Check partition strategy
        non_hash_strategy = partition_strategy.lower() != "hash"

        if count_outside_range:
            findings.append("partition count outside recommended range (50-200)")

        if non_hash_strategy:
            findings.append("non-hash partition strategy \u2014 consider hash partitioning")

        if findings:
            # Object has one or more issues
            message = "; ".join(findings)
            results.append(
                CheckResult(
                    script_name="partition_check",
                    check_name="Database Partition Check",
                    check_level=CheckLevel.DATABASE,
                    status=CheckStatus.FLAGGED,
                    severity=Severity.ADVISORY,
                    current_value=f"partitions={partition_count}, strategy={partition_strategy}",
                    default_value="50-200 partitions, hash strategy",
                    message=f"{object_name}: {message}",
                    details=[
                        DetailRow(
                            object_name=object_name,
                            column_name="",
                            finding=message,
                            value=f"partitions={partition_count}, strategy={partition_strategy}",
                        )
                    ],
                )
            )
        else:
            # Object passes: count 50-200 AND hash strategy
            results.append(
                CheckResult(
                    script_name="partition_check",
                    check_name="Database Partition Check",
                    check_level=CheckLevel.DATABASE,
                    status=CheckStatus.PASSED,
                    severity=Severity.OK,
                    current_value=f"partitions={partition_count}, strategy={partition_strategy}",
                    default_value="50-200 partitions, hash strategy",
                    message=f"{object_name}: partition check passed",
                    details=[],
                )
            )

    return results


def evaluate_primary_key(parsed_results: List[dict]) -> List[CheckResult]:
    """Evaluate primary key check for all user tables.

    Classifies each table based on its primary key status:
    - Missing PK (pk_columns is None or empty): FLAGGED with CRITICAL severity
    - Composite PK (pk_columns has multiple columns): FLAGGED with ADVISORY severity
    - Single-column PK (pk_columns has exactly one column): PASSED with OK severity

    Args:
        parsed_results: List of dicts, each with keys:
            - schema_name (str): Schema name of the table
            - table_name (str): Table name
            - pk_columns (list[str] or None): List of PK column names, or None if no PK
            - error (str, optional): Error message if metadata retrieval failed

    Returns:
        List of CheckResult objects, one per table, with check_level=TABLE.

    Validates: Requirements 17.1, 17.2, 17.3, 17.4, 17.5
    """
    results: List[CheckResult] = []

    for table_info in parsed_results:
        schema_name = table_info.get("schema_name", "")
        table_name = table_info.get("table_name", "")
        pk_columns = table_info.get("pk_columns")
        error = table_info.get("error")
        object_name = f"{schema_name}.{table_name}" if schema_name else table_name

        # Handle error case
        if error:
            results.append(
                CheckResult(
                    script_name="primary_key_check",
                    check_name="Primary Key Check",
                    check_level=CheckLevel.TABLE,
                    status=CheckStatus.ERROR,
                    severity=Severity.ADVISORY,
                    current_value="",
                    default_value="",
                    message=f"Unable to retrieve primary key metadata for {object_name}: {error}",
                    details=[],
                )
            )
            continue

        # Missing primary key
        if pk_columns is None or len(pk_columns) == 0:
            results.append(
                CheckResult(
                    script_name="primary_key_check",
                    check_name="Primary Key Check",
                    check_level=CheckLevel.TABLE,
                    status=CheckStatus.FLAGGED,
                    severity=Severity.CRITICAL,
                    current_value=object_name,
                    default_value="",
                    message="missing primary key",
                    details=[],
                )
            )
        # Composite primary key (multiple columns)
        elif len(pk_columns) > 1:
            results.append(
                CheckResult(
                    script_name="primary_key_check",
                    check_name="Primary Key Check",
                    check_level=CheckLevel.TABLE,
                    status=CheckStatus.FLAGGED,
                    severity=Severity.ADVISORY,
                    current_value=object_name,
                    default_value="",
                    message=f"composite primary key \u2014 single-column primary key recommended",
                    details=[
                        DetailRow(
                            object_name=object_name,
                            column_name=", ".join(pk_columns),
                            finding="composite primary key",
                            value=str(len(pk_columns)),
                        )
                    ],
                )
            )
        # Single-column primary key (passed)
        else:
            results.append(
                CheckResult(
                    script_name="primary_key_check",
                    check_name="Primary Key Check",
                    check_level=CheckLevel.TABLE,
                    status=CheckStatus.PASSED,
                    severity=Severity.OK,
                    current_value=object_name,
                    default_value="",
                    message=f"Primary key check passed for {object_name}",
                    details=[],
                )
            )

    return results


def evaluate_vlf_count(
    dbengine: str, parsed_results: List[Dict[str, object]]
) -> Optional[List[CheckResult]]:
    """Evaluate Virtual Log File (VLF) count check (SQL Server only).

    Retrieves the VLF count per database and flags databases with 1000 or more VLFs.

    Args:
        dbengine: The database engine identifier (e.g., "mssql", "postgres").
        parsed_results: List of dicts, each with keys:
            - database_name (str): Name of the database
            - vlf_count (int): Total number of VLFs for the database

    Returns:
        List of CheckResult objects (one per database), or None if dbengine
        is not "mssql".

    Validates: Requirements 16.1, 16.2, 16.3, 16.4
    """
    if dbengine != "mssql":
        return None

    results: List[CheckResult] = []

    for db_entry in parsed_results:
        database_name = db_entry.get("database_name", "unknown")
        vlf_count = db_entry.get("vlf_count", 0)

        if vlf_count >= 1000:
            results.append(
                CheckResult(
                    script_name="vlf_count",
                    check_name="VLF Count Check",
                    check_level=CheckLevel.DATABASE,
                    status=CheckStatus.FLAGGED,
                    severity=Severity.ADVISORY,
                    current_value=str(vlf_count),
                    default_value="< 1000",
                    message=f"VLF count exceeds threshold \u2014 current count: {vlf_count}, recommended: less than 1000",
                    details=[
                        DetailRow(
                            object_name=database_name,
                            column_name="",
                            finding=f"VLF count exceeds threshold \u2014 current count: {vlf_count}, recommended: less than 1000",
                            value=str(vlf_count),
                        )
                    ],
                )
            )
        else:
            results.append(
                CheckResult(
                    script_name="vlf_count",
                    check_name="VLF Count Check",
                    check_level=CheckLevel.DATABASE,
                    status=CheckStatus.PASSED,
                    severity=Severity.OK,
                    current_value=str(vlf_count),
                    default_value="< 1000",
                    message=f"{database_name}: VLF count check passed ({vlf_count} VLFs)",
                    details=[],
                )
            )

    return results


def evaluate_statistics_freshness(
    dbengine: str,
    current_timestamp: datetime,
    parsed_results: List[Dict],
) -> Optional[List[CheckResult]]:
    """Evaluate statistics freshness for each table.

    Retrieves the last statistics update date per engine and classifies:
    - Flag when (current_timestamp - last_stats_date) > 7 days: "stale statistics — last updated on [date]"
    - Flag when last_stats_date is None: "stale statistics — never analyzed"
    - Pass when difference is ≤ 7 days

    Args:
        dbengine: Database engine name (postgres, mssql, mysql, oracle, mongodb).
        current_timestamp: The current execution timestamp (datetime).
        parsed_results: List of dicts, each with keys:
            - table_name (str): Name of the table
            - last_stats_date (datetime or None): Last statistics update date

    Returns:
        List of CheckResult objects with check_level=TABLE, or None if dbengine is "mongodb".

    Validates: Requirements 22.1, 22.2, 22.3, 22.4, 22.5, 22.6, 22.7, 22.8
    """
    if dbengine == "mongodb":
        return None

    results: List[CheckResult] = []
    stale_threshold = timedelta(days=7)

    for entry in parsed_results:
        table_name = entry.get("table_name", "unknown")
        last_stats_date = entry.get("last_stats_date")

        if last_stats_date is None:
            results.append(
                CheckResult(
                    script_name="statistics_freshness",
                    check_name="Statistics Freshness Check",
                    check_level=CheckLevel.TABLE,
                    status=CheckStatus.FLAGGED,
                    severity=Severity.ADVISORY,
                    current_value="never",
                    default_value="",
                    message="stale statistics \u2014 never analyzed",
                    details=[
                        DetailRow(
                            object_name=table_name,
                            column_name="",
                            finding="stale statistics \u2014 never analyzed",
                            value="never",
                        )
                    ],
                )
            )
        elif (current_timestamp - last_stats_date) > stale_threshold:
            date_str = last_stats_date.strftime("%Y-%m-%d")
            results.append(
                CheckResult(
                    script_name="statistics_freshness",
                    check_name="Statistics Freshness Check",
                    check_level=CheckLevel.TABLE,
                    status=CheckStatus.FLAGGED,
                    severity=Severity.ADVISORY,
                    current_value=date_str,
                    default_value="",
                    message=f"stale statistics \u2014 last updated on {date_str}",
                    details=[
                        DetailRow(
                            object_name=table_name,
                            column_name="",
                            finding=f"stale statistics \u2014 last updated on {date_str}",
                            value=date_str,
                        )
                    ],
                )
            )
        else:
            results.append(
                CheckResult(
                    script_name="statistics_freshness",
                    check_name="Statistics Freshness Check",
                    check_level=CheckLevel.TABLE,
                    status=CheckStatus.PASSED,
                    severity=Severity.OK,
                    current_value=last_stats_date.strftime("%Y-%m-%d"),
                    default_value="",
                    message=f"Statistics up to date for {table_name}",
                    details=[],
                )
            )

    return results


def evaluate_foreign_key_nullability(parsed_results: List[Dict[str, str]]) -> List[CheckResult]:
    """Evaluate foreign key column nullability check.

    Identifies FK columns and checks their nullability. Flags nullable FK columns
    and passes when all FK columns in a table are non-nullable. Tables with no
    FK constraints are excluded from results.

    Args:
        parsed_results: List of dicts, each with keys:
            - schema_name (str): Schema name of the table
            - table_name (str): Table name
            - column_name (str): Column name participating in FK constraint
            - is_nullable (str): "YES" if nullable, "NO" if not nullable

    Returns:
        List of CheckResult objects with check_level=TABLE.
        One result per table that has FK constraints.
        Tables with no FK constraints are excluded.

    Validates: Requirements 18.1, 18.2, 18.3, 18.4
    """
    # Group FK columns by (schema_name, table_name)
    table_fk_columns: Dict[tuple, List[Dict[str, str]]] = {}
    for row in parsed_results:
        key = (row.get("schema_name", ""), row.get("table_name", ""))
        if key not in table_fk_columns:
            table_fk_columns[key] = []
        table_fk_columns[key].append(row)

    results: List[CheckResult] = []

    for (schema_name, table_name), columns in table_fk_columns.items():
        object_name = f"{schema_name}.{table_name}" if schema_name else table_name

        # Check if any FK column is nullable
        nullable_columns = [
            col for col in columns
            if col.get("is_nullable", "").upper() == "YES"
        ]

        if nullable_columns:
            # Flag: at least one nullable FK column
            details = [
                DetailRow(
                    object_name=object_name,
                    column_name=col.get("column_name", ""),
                    finding="nullable foreign key column",
                    value=col.get("column_name", ""),
                )
                for col in nullable_columns
            ]
            results.append(CheckResult(
                script_name="foreign_key_nullability",
                check_name="Foreign Key Nullability Check",
                check_level=CheckLevel.TABLE,
                status=CheckStatus.FLAGGED,
                severity=Severity.ADVISORY,
                current_value=object_name,
                default_value="",
                message="nullable foreign key column",
                details=details,
            ))
        else:
            # Pass: all FK columns in this table are non-nullable
            results.append(CheckResult(
                script_name="foreign_key_nullability",
                check_name="Foreign Key Nullability Check",
                check_level=CheckLevel.TABLE,
                status=CheckStatus.PASSED,
                severity=Severity.OK,
                current_value=object_name,
                default_value="",
                message="All foreign key columns are non-nullable",
                details=[],
            ))

    return results


def evaluate_search_column_nullability(parsed_results: List[Dict[str, str]]) -> List[CheckResult]:
    """Evaluate search column (indexed column) nullability check.

    Identifies columns participating in non-primary-key indexes and checks their
    nullability. Flags nullable indexed columns and passes when all indexed columns
    in a table are non-nullable. Tables with no non-PK indexes are skipped.

    Args:
        parsed_results: List of dicts, each with keys:
            - table_name (str): Table name
            - column_name (str): Column name participating in a non-PK index
            - index_name (str): Name of the index
            - is_nullable (str): "YES" if nullable, "NO" if not nullable

    Returns:
        List of CheckResult objects with check_level=TABLE.
        One result per table that has non-PK indexes.
        Tables with no non-PK indexes are skipped (not included in results).

    Validates: Requirements 19.1, 19.2, 19.3, 19.4
    """
    # Group indexed columns by table_name
    table_indexed_columns: Dict[str, List[Dict[str, str]]] = {}
    for row in parsed_results:
        table_name = row.get("table_name", "")
        if table_name not in table_indexed_columns:
            table_indexed_columns[table_name] = []
        table_indexed_columns[table_name].append(row)

    results: List[CheckResult] = []

    for table_name, columns in table_indexed_columns.items():
        # Check if any indexed column is nullable
        nullable_columns = [
            col for col in columns
            if col.get("is_nullable", "").upper() == "YES"
        ]

        if nullable_columns:
            # Flag: at least one nullable indexed column
            details = [
                DetailRow(
                    object_name=table_name,
                    column_name=col.get("column_name", ""),
                    finding="nullable search column",
                    value=col.get("index_name", ""),
                )
                for col in nullable_columns
            ]
            results.append(CheckResult(
                script_name="search_column_nullability",
                check_name="Search Column Nullability Check",
                check_level=CheckLevel.TABLE,
                status=CheckStatus.FLAGGED,
                severity=Severity.ADVISORY,
                current_value=table_name,
                default_value="",
                message="nullable search column",
                details=details,
            ))
        else:
            # Pass: all indexed columns in this table are non-nullable
            results.append(CheckResult(
                script_name="search_column_nullability",
                check_name="Search Column Nullability Check",
                check_level=CheckLevel.TABLE,
                status=CheckStatus.PASSED,
                severity=Severity.OK,
                current_value=table_name,
                default_value="",
                message="All indexed columns are non-nullable",
                details=[],
            ))

    return results


def evaluate_trigger_presence(parsed_results: List[Dict]) -> List[CheckResult]:
    """Evaluate trigger presence check for tables.

    Identifies tables with triggers and flags them, recommending event-driven
    architecture as an alternative. Tables without triggers pass.

    Args:
        parsed_results: List of dicts, each with keys:
            - table_name (str): Name of the table
            - trigger_names (list of str): List of trigger names on the table

    Returns:
        List of CheckResult objects with check_level=TABLE.
        - Tables with non-empty trigger_names are FLAGGED with ADVISORY severity
        - Tables with empty trigger_names are PASSED
        - If no tables have triggers, returns a single PASSED result

    Validates: Requirements 20.1, 20.2, 20.3, 20.4
    """
    results: List[CheckResult] = []
    any_triggers_found = False

    for row in parsed_results:
        table_name = row.get("table_name", "")
        trigger_names = row.get("trigger_names", [])

        if trigger_names:
            any_triggers_found = True
            triggers_str = ", ".join(trigger_names)
            results.append(CheckResult(
                script_name="trigger_presence",
                check_name="Trigger Presence Check",
                check_level=CheckLevel.TABLE,
                status=CheckStatus.FLAGGED,
                severity=Severity.ADVISORY,
                current_value=triggers_str,
                default_value="",
                message=f"has triggers \u2014 consider event-driven architecture",
                details=[
                    DetailRow(
                        object_name=table_name,
                        column_name="",
                        finding="has triggers \u2014 consider event-driven architecture",
                        value=triggers_str,
                    )
                ],
            ))
        else:
            results.append(CheckResult(
                script_name="trigger_presence",
                check_name="Trigger Presence Check",
                check_level=CheckLevel.TABLE,
                status=CheckStatus.PASSED,
                severity=Severity.OK,
                current_value=table_name,
                default_value="",
                message="No triggers defined",
                details=[],
            ))

    if not any_triggers_found:
        # No tables have triggers — return single PASSED result
        return [CheckResult(
            script_name="trigger_presence",
            check_name="Trigger Presence Check",
            check_level=CheckLevel.TABLE,
            status=CheckStatus.PASSED,
            severity=Severity.OK,
            current_value="",
            default_value="",
            message="No tables have triggers",
            details=[],
        )]

    return results


def evaluate_table_partition_check(partitioned_tables: List[Dict[str, object]]) -> List[CheckResult]:
    """Evaluate table-level partition check for partitioned tables.

    Checks each partitioned table's partition count and strategy:
    - Flag when partition count < 50 or > 200
    - Flag when partition strategy is not "hash"
    - A table can have multiple flags (both count and strategy issues)
    - Pass when count is 50-200 inclusive AND strategy is "hash"
    - If no partitioned tables exist, return single PASSED with note

    Args:
        partitioned_tables: List of dicts, each with keys:
            - table_name (str): Name of the partitioned table
            - partition_count (int): Number of partitions
            - partition_strategy (str): Partitioning strategy (e.g., "hash", "range", "list")

    Returns:
        List of CheckResult objects (one per table, or a single PASSED if no
        partitioned tables exist). check_level=TABLE for all results.

    Validates: Requirements 21.1, 21.2, 21.3, 21.4, 21.5, 21.6
    """
    if not partitioned_tables:
        return [
            CheckResult(
                script_name="table_partition_check",
                check_name="Table Partition Check",
                check_level=CheckLevel.TABLE,
                status=CheckStatus.PASSED,
                severity=Severity.OK,
                current_value="",
                default_value="",
                message="no partitioned tables found",
                details=[],
            )
        ]

    results: List[CheckResult] = []

    for table in partitioned_tables:
        table_name = table.get("table_name", "unknown")
        partition_count = table.get("partition_count", 0)
        partition_strategy = table.get("partition_strategy", "")

        findings: List[str] = []

        # Check partition count range
        count_outside_range = partition_count < 50 or partition_count > 200

        # Check partition strategy
        non_hash_strategy = partition_strategy.lower() != "hash"

        if count_outside_range:
            findings.append("table partition count outside recommended range (50-200)")

        if non_hash_strategy:
            findings.append("non-hash table partition strategy \u2014 consider hash partitioning")

        if findings:
            # Table has one or more issues
            message = "; ".join(findings)
            results.append(
                CheckResult(
                    script_name="table_partition_check",
                    check_name="Table Partition Check",
                    check_level=CheckLevel.TABLE,
                    status=CheckStatus.FLAGGED,
                    severity=Severity.ADVISORY,
                    current_value=f"partitions={partition_count}, strategy={partition_strategy}",
                    default_value="50-200 partitions, hash strategy",
                    message=f"{table_name}: {message}",
                    details=[
                        DetailRow(
                            object_name=table_name,
                            column_name="",
                            finding=message,
                            value=f"partitions={partition_count}, strategy={partition_strategy}",
                        )
                    ],
                )
            )
        else:
            # Table passes: count 50-200 AND hash strategy
            results.append(
                CheckResult(
                    script_name="table_partition_check",
                    check_name="Table Partition Check",
                    check_level=CheckLevel.TABLE,
                    status=CheckStatus.PASSED,
                    severity=Severity.OK,
                    current_value=f"partitions={partition_count}, strategy={partition_strategy}",
                    default_value="50-200 partitions, hash strategy",
                    message=f"{table_name}: table partition check passed",
                    details=[],
                )
            )

    return results
