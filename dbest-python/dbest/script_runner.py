"""Script execution engine for dbbpc."""

import json
import logging
from typing import Any, Dict, List, Optional

from .models import CheckLevel, CheckResult, CheckStatus, ScriptFile, Severity

logger = logging.getLogger(__name__)


def run_scripts(
    connection: Any,
    scripts: List[ScriptFile],
    dbengine: str,
) -> List[CheckResult]:
    """Execute diagnostic scripts against the database and collect results.

    Iterates through the provided scripts in order, executing each script's
    SQL/JS content against the connection handle. On execution failure
    (permissions, syntax, timeout), captures the error into a CheckResult
    with status=ERROR. On unreadable file (content is empty or None), skips
    with a logged warning and continues.

    Args:
        connection: A database connection handle (driver-specific).
        scripts: List of ScriptFile objects, already sorted alphabetically.
        dbengine: The database engine identifier (mssql, mysql, oracle, postgres, mongodb).

    Returns:
        A complete list of CheckResult objects from all executed scripts.

    Validates: Requirements 26.6, 26.7, 26.8, 24.5
    """
    results: List[CheckResult] = []

    for script in scripts:
        # Check for unreadable file (content is empty or None)
        if script.content is None or script.content.strip() == "":
            logger.warning(
                "Skipping script '%s': file content is empty or unreadable",
                script.filename,
            )
            continue

        try:
            if dbengine == "mongodb":
                script_results = _execute_mongodb_script(connection, script)
            else:
                script_results = _execute_sql_script(connection, script)

            # Parse the raw results into a CheckResult
            check_result = _parse_script_result(script, script_results)
            results.append(check_result)

        except Exception as exc:
            # Capture execution failure as ERROR CheckResult
            error_result = CheckResult(
                script_name=script.filename,
                check_name=_derive_check_name(script.filename),
                check_level=CheckLevel.INSTANCE,
                status=CheckStatus.ERROR,
                severity=Severity.ADVISORY,
                current_value="",
                default_value="",
                message=f"Script execution failed: {type(exc).__name__}: {str(exc)}",
                details=[],
            )
            results.append(error_result)
            logger.error(
                "Script '%s' execution failed: %s: %s",
                script.filename,
                type(exc).__name__,
                str(exc),
            )

    return results


def _execute_sql_script(connection: Any, script: ScriptFile) -> List[Dict[str, Any]]:
    """Execute a SQL script against the connection and return result rows.

    Args:
        connection: A database connection handle with cursor support.
        script: The ScriptFile containing SQL content to execute.

    Returns:
        A list of dictionaries representing result rows, where keys are
        column names and values are the row values.
    """
    cursor = connection.cursor()
    try:
        cursor.execute(script.content)

        # Attempt to fetch results if the query returns rows
        if cursor.description is not None:
            columns = [desc[0] for desc in cursor.description]
            rows = cursor.fetchall()
            return [dict(zip(columns, row)) for row in rows]
        else:
            return []
    finally:
        cursor.close()


def _execute_mongodb_script(connection: Any, script: ScriptFile) -> List[Dict[str, Any]]:
    """Execute a MongoDB JavaScript script using runCommand.

    For MongoDB, scripts are expected to contain JSON-formatted commands
    or JavaScript that can be evaluated via the admin database's command
    interface.

    Args:
        connection: A pymongo MongoClient instance.
        script: The ScriptFile containing JS/JSON content to execute.

    Returns:
        A list of dictionaries representing the command result.
    """
    # Try to parse the script content as a JSON command
    content = script.content.strip()

    try:
        # Attempt to parse as JSON command document
        command_doc = json.loads(content)
        result = connection.admin.command(command_doc)
        if isinstance(result, dict):
            return [result]
        return []
    except (json.JSONDecodeError, ValueError):
        # If not valid JSON, try to evaluate as a JavaScript expression
        # using the $eval command (deprecated but available in older versions)
        # or use runCommand with eval
        try:
            result = connection.admin.command("eval", content)
            if isinstance(result, dict):
                return [result]
            elif isinstance(result, list):
                return result
            return [{"result": result}]
        except Exception:
            # Re-raise to be caught by the outer exception handler
            raise


def _derive_check_name(filename: str) -> str:
    """Derive a human-readable check name from a script filename.

    Strips the file extension, removes leading numeric prefixes and
    underscores, and converts underscores to spaces with title case.

    Args:
        filename: The script filename (e.g., '01_cpu_utilization.sql').

    Returns:
        A human-readable check name (e.g., 'Cpu Utilization').
    """
    # Remove extension
    name = filename.rsplit(".", 1)[0] if "." in filename else filename

    # Remove leading numeric prefix (e.g., '01_')
    parts = name.split("_", 1)
    if len(parts) > 1 and parts[0].isdigit():
        name = parts[1]

    # Convert underscores to spaces and title case
    return name.replace("_", " ").title()


def _parse_script_result(
    script: ScriptFile, raw_results: List[Dict[str, Any]]
) -> CheckResult:
    """Parse raw script execution results into a CheckResult.

    Interprets the result set from a diagnostic script. Scripts are expected
    to return a result set with standardized column names that map to
    CheckResult fields. If the result set doesn't match the expected format,
    a basic PASSED result is returned with the raw data as the message.

    Expected columns in result set:
        - check_name (str): Human-readable check name
        - check_level (str): INSTANCE, DATABASE, or TABLE
        - status (str): PASSED, FLAGGED, ERROR, or INSUFFICIENT_DATA
        - severity (str): OK, ADVISORY, or CRITICAL
        - current_value (str): The retrieved value
        - default_value (str): The engine default value
        - message (str): Descriptive finding text

    Args:
        script: The ScriptFile that was executed.
        raw_results: List of row dictionaries from the query execution.

    Returns:
        A CheckResult object representing the script's findings.
    """
    if not raw_results:
        return CheckResult(
            script_name=script.filename,
            check_name=_derive_check_name(script.filename),
            check_level=CheckLevel.INSTANCE,
            status=CheckStatus.PASSED,
            severity=Severity.OK,
            current_value="",
            default_value="",
            message="Check completed with no findings",
            details=[],
        )

    # Use the first row as the primary result
    row = raw_results[0]

    # Try to extract standardized fields from the result
    check_name = str(row.get("check_name", _derive_check_name(script.filename)))

    # Parse check_level
    check_level_str = str(row.get("check_level", "INSTANCE")).upper()
    try:
        check_level = CheckLevel(check_level_str)
    except ValueError:
        check_level = CheckLevel.INSTANCE

    # Parse status
    status_str = str(row.get("status", "PASSED")).upper()
    try:
        status = CheckStatus(status_str)
    except ValueError:
        status = CheckStatus.PASSED

    # Parse severity
    severity_str = str(row.get("severity", "OK")).upper()
    try:
        severity = Severity(severity_str)
    except ValueError:
        severity = Severity.OK

    current_value = str(row.get("current_value", ""))
    default_value = str(row.get("default_value", ""))
    message = str(row.get("message", ""))

    return CheckResult(
        script_name=script.filename,
        check_name=check_name,
        check_level=check_level,
        status=status,
        severity=severity,
        current_value=current_value,
        default_value=default_value,
        message=message,
        details=[],
    )
