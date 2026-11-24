namespace dbbpc;

/// <summary>
/// Categorization level for a diagnostic check.
/// </summary>
public enum CheckLevel
{
    Instance,
    Database,
    Table
}

/// <summary>
/// Outcome status of a diagnostic check.
/// </summary>
public enum CheckStatus
{
    Passed,
    Flagged,
    Error,
    InsufficientData
}

/// <summary>
/// Visual severity level for report color coding.
/// </summary>
public enum Severity
{
    Ok,
    Advisory,
    Critical
}

/// <summary>
/// Database connection parameters parsed from CLI arguments.
/// </summary>
public class ConnectionParams
{
    /// <summary>One of: mssql, mysql, oracle, postgres, mongodb</summary>
    public string DbEngine { get; set; } = string.Empty;

    /// <summary>Non-empty hostname or IP</summary>
    public string DbHost { get; set; } = string.Empty;

    /// <summary>Port number 1-65535</summary>
    public int Port { get; set; }

    /// <summary>Non-empty username</summary>
    public string Username { get; set; } = string.Empty;

    /// <summary>Password (may be empty string if prompted)</summary>
    public string Password { get; set; } = string.Empty;
}

/// <summary>
/// Per-object detail row for multi-row check results.
/// </summary>
public class DetailRow
{
    /// <summary>Schema.table or database name</summary>
    public string ObjectName { get; set; } = string.Empty;

    /// <summary>Column name (may be empty)</summary>
    public string ColumnName { get; set; } = string.Empty;

    /// <summary>Specific finding for this object</summary>
    public string Finding { get; set; } = string.Empty;

    /// <summary>Associated value</summary>
    public string Value { get; set; } = string.Empty;
}

/// <summary>
/// Result of a single diagnostic check execution.
/// </summary>
public class CheckResult
{
    /// <summary>Filename of the source script</summary>
    public string ScriptName { get; set; } = string.Empty;

    /// <summary>Human-readable check identifier</summary>
    public string CheckName { get; set; } = string.Empty;

    /// <summary>INSTANCE, DATABASE, or TABLE</summary>
    public CheckLevel CheckLevel { get; set; }

    /// <summary>PASSED, FLAGGED, ERROR, or INSUFFICIENT_DATA</summary>
    public CheckStatus Status { get; set; }

    /// <summary>OK, ADVISORY, or CRITICAL</summary>
    public Severity Severity { get; set; }

    /// <summary>Retrieved configuration value</summary>
    public string CurrentValue { get; set; } = string.Empty;

    /// <summary>Engine default value (may be empty)</summary>
    public string DefaultValue { get; set; } = string.Empty;

    /// <summary>Descriptive finding text</summary>
    public string Message { get; set; } = string.Empty;

    /// <summary>Per-object details for multi-row checks</summary>
    public List<DetailRow> Details { get; set; } = new();
}

/// <summary>
/// Metadata for the generated HTML report.
/// </summary>
public class ReportMetadata
{
    /// <summary>Engine that was checked</summary>
    public string DbEngine { get; set; } = string.Empty;

    /// <summary>Target host</summary>
    public string DbHost { get; set; } = string.Empty;

    /// <summary>ISO 8601 execution timestamp</summary>
    public string Timestamp { get; set; } = string.Empty;

    /// <summary>Count of passed checks</summary>
    public int TotalPassed { get; set; }

    /// <summary>Count of flagged checks</summary>
    public int TotalFlagged { get; set; }
}

/// <summary>
/// A discovered diagnostic script file.
/// </summary>
public class ScriptFile
{
    /// <summary>Script filename</summary>
    public string Filename { get; set; } = string.Empty;

    /// <summary>Absolute path to the script</summary>
    public string FullPath { get; set; } = string.Empty;

    /// <summary>Loaded file content</summary>
    public string Content { get; set; } = string.Empty;
}

/// <summary>
/// Engine configuration defaults mapping engine → parameter → default_value.
/// Used for comparison checks (parallelism, checkpoint, etc.)
/// </summary>
public static class EngineDefaults
{
    public static readonly Dictionary<string, Dictionary<string, string>> Defaults = new()
    {
        ["postgres"] = new Dictionary<string, string>
        {
            ["max_parallel_workers"] = "8",
            ["checkpoint_timeout"] = "5min",
            ["max_wal_size"] = "1GB",
            ["autovacuum_freeze_max_age"] = "200000000",
            ["autovacuum_vacuum_threshold"] = "50",
            ["autovacuum_vacuum_scale_factor"] = "0.2",
            ["autovacuum_max_workers"] = "3"
        },
        ["mssql"] = new Dictionary<string, string>
        {
            ["MaxDOP"] = "0",
            ["cost threshold for parallelism"] = "5",
            ["recovery_interval"] = "0"
        },
        ["mysql"] = new Dictionary<string, string>
        {
            ["innodb_parallel_read_threads"] = "4",
            ["innodb_log_file_size"] = "48MB"
        },
        ["oracle"] = new Dictionary<string, string>
        {
            ["PARALLEL_MAX_SERVERS"] = "0",
            ["LOG_CHECKPOINT_TIMEOUT"] = "0"
        }
    };
}
