''' Core data models and enums for dbbpc.

Namespace Models

    ''' <summary>
    ''' Categorization level for a diagnostic check.
    ''' </summary>
    Public Enum CheckLevel
        INSTANCE
        DATABASE
        TABLE
    End Enum

    ''' <summary>
    ''' Outcome status of a diagnostic check.
    ''' </summary>
    Public Enum CheckStatus
        PASSED
        FLAGGED
        [ERROR]
        INSUFFICIENT_DATA
    End Enum

    ''' <summary>
    ''' Visual severity level for report color coding.
    ''' </summary>
    Public Enum Severity
        OK
        ADVISORY
        CRITICAL
    End Enum

    ''' <summary>
    ''' Database connection parameters parsed from CLI arguments.
    ''' </summary>
    Public Class ConnectionParams
        ''' <summary>One of: mssql, mysql, oracle, postgres, mongodb</summary>
        Public Property DbEngine As String

        ''' <summary>Non-empty hostname or IP</summary>
        Public Property DbHost As String

        ''' <summary>Port number 1-65535</summary>
        Public Property Port As Integer

        ''' <summary>Non-empty username</summary>
        Public Property Username As String

        ''' <summary>May be empty string if prompted</summary>
        Public Property Password As String

        Public Sub New()
            DbEngine = String.Empty
            DbHost = String.Empty
            Port = 0
            Username = String.Empty
            Password = String.Empty
        End Sub

        Public Sub New(dbEngine As String, dbHost As String, port As Integer, username As String, password As String)
            Me.DbEngine = dbEngine
            Me.DbHost = dbHost
            Me.Port = port
            Me.Username = username
            Me.Password = password
        End Sub
    End Class

    ''' <summary>
    ''' Per-object detail row for multi-row check results.
    ''' </summary>
    Public Class DetailRow
        ''' <summary>Schema.table or database name</summary>
        Public Property ObjectName As String

        ''' <summary>Column name (may be empty)</summary>
        Public Property ColumnName As String

        ''' <summary>Specific finding for this object</summary>
        Public Property Finding As String

        ''' <summary>Associated value</summary>
        Public Property Value As String

        Public Sub New()
            ObjectName = String.Empty
            ColumnName = String.Empty
            Finding = String.Empty
            Value = String.Empty
        End Sub

        Public Sub New(objectName As String, columnName As String, finding As String, value As String)
            Me.ObjectName = objectName
            Me.ColumnName = columnName
            Me.Finding = finding
            Me.Value = value
        End Sub
    End Class

    ''' <summary>
    ''' Result of a single diagnostic check execution.
    ''' </summary>
    Public Class CheckResult
        ''' <summary>Filename of the source script</summary>
        Public Property ScriptName As String

        ''' <summary>Human-readable check identifier</summary>
        Public Property CheckName As String

        ''' <summary>INSTANCE, DATABASE, or TABLE</summary>
        Public Property CheckLevel As CheckLevel

        ''' <summary>PASSED, FLAGGED, ERROR, or INSUFFICIENT_DATA</summary>
        Public Property Status As CheckStatus

        ''' <summary>OK, ADVISORY, or CRITICAL</summary>
        Public Property Severity As Severity

        ''' <summary>Retrieved configuration value</summary>
        Public Property CurrentValue As String

        ''' <summary>Engine default value (may be empty)</summary>
        Public Property DefaultValue As String

        ''' <summary>Descriptive finding text</summary>
        Public Property Message As String

        ''' <summary>Per-object details for multi-row checks</summary>
        Public Property Details As List(Of DetailRow)

        Public Sub New()
            ScriptName = String.Empty
            CheckName = String.Empty
            CheckLevel = CheckLevel.INSTANCE
            Status = CheckStatus.PASSED
            Severity = Severity.OK
            CurrentValue = String.Empty
            DefaultValue = String.Empty
            Message = String.Empty
            Details = New List(Of DetailRow)()
        End Sub

        Public Sub New(scriptName As String, checkName As String, checkLevel As CheckLevel,
                       status As CheckStatus, severity As Severity, currentValue As String,
                       defaultValue As String, message As String, Optional details As List(Of DetailRow) = Nothing)
            Me.ScriptName = scriptName
            Me.CheckName = checkName
            Me.CheckLevel = checkLevel
            Me.Status = status
            Me.Severity = severity
            Me.CurrentValue = currentValue
            Me.DefaultValue = defaultValue
            Me.Message = message
            Me.Details = If(details, New List(Of DetailRow)())
        End Sub
    End Class

    ''' <summary>
    ''' Metadata for the generated HTML report.
    ''' </summary>
    Public Class ReportMetadata
        ''' <summary>Engine that was checked</summary>
        Public Property DbEngine As String

        ''' <summary>Target host</summary>
        Public Property DbHost As String

        ''' <summary>ISO 8601 execution timestamp</summary>
        Public Property Timestamp As String

        ''' <summary>Count of passed checks</summary>
        Public Property TotalPassed As Integer

        ''' <summary>Count of flagged checks</summary>
        Public Property TotalFlagged As Integer

        Public Sub New()
            DbEngine = String.Empty
            DbHost = String.Empty
            Timestamp = String.Empty
            TotalPassed = 0
            TotalFlagged = 0
        End Sub

        Public Sub New(dbEngine As String, dbHost As String, timestamp As String, totalPassed As Integer, totalFlagged As Integer)
            Me.DbEngine = dbEngine
            Me.DbHost = dbHost
            Me.Timestamp = timestamp
            Me.TotalPassed = totalPassed
            Me.TotalFlagged = totalFlagged
        End Sub
    End Class

    ''' <summary>
    ''' A discovered diagnostic script file.
    ''' </summary>
    Public Class ScriptFile
        ''' <summary>Script filename</summary>
        Public Property Filename As String

        ''' <summary>Absolute path to the script</summary>
        Public Property FullPath As String

        ''' <summary>Loaded file content</summary>
        Public Property Content As String

        Public Sub New()
            Filename = String.Empty
            FullPath = String.Empty
            Content = String.Empty
        End Sub

        Public Sub New(filename As String, fullPath As String, content As String)
            Me.Filename = filename
            Me.FullPath = fullPath
            Me.Content = content
        End Sub
    End Class

    ''' <summary>
    ''' Engine configuration defaults mapping engine -> parameter -> default_value.
    ''' Used for comparison checks (parallelism, checkpoint, etc.)
    ''' </summary>
    Public Module EngineDefaults
        Public ReadOnly ENGINE_DEFAULTS As New Dictionary(Of String, Dictionary(Of String, String)) From {
            {"postgres", New Dictionary(Of String, String) From {
                {"max_parallel_workers", "8"},
                {"checkpoint_timeout", "5min"},
                {"max_wal_size", "1GB"},
                {"autovacuum_freeze_max_age", "200000000"},
                {"autovacuum_vacuum_threshold", "50"},
                {"autovacuum_vacuum_scale_factor", "0.2"},
                {"autovacuum_max_workers", "3"}
            }},
            {"mssql", New Dictionary(Of String, String) From {
                {"MaxDOP", "0"},
                {"cost threshold for parallelism", "5"},
                {"recovery_interval", "0"}
            }},
            {"mysql", New Dictionary(Of String, String) From {
                {"innodb_parallel_read_threads", "4"},
                {"innodb_log_file_size", "48MB"}
            }},
            {"oracle", New Dictionary(Of String, String) From {
                {"PARALLEL_MAX_SERVERS", "0"},
                {"LOG_CHECKPOINT_TIMEOUT", "0"}
            }}
        }
    End Module

End Namespace
