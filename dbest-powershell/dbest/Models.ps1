# Models.ps1 - Data models for the Database Best Practices Checker (PowerShell port)

# --- Enums ---

enum CheckLevel {
    INSTANCE
    DATABASE
    TABLE
}

enum CheckStatus {
    PASSED
    FLAGGED
    ERROR
    INSUFFICIENT_DATA
}

enum Severity {
    OK
    ADVISORY
    CRITICAL
}

# --- Factory Functions ---

function New-ConnectionParams {
    <#
    .SYNOPSIS
        Creates a ConnectionParams object with database connection details.
    .PARAMETER DbEngine
        One of: mssql, mysql, oracle, postgres, mongodb
    .PARAMETER DbHost
        Non-empty hostname or IP address
    .PARAMETER Port
        Port number (1-65535)
    .PARAMETER Username
        Non-empty username
    .PARAMETER Password
        Password string (may be empty if prompted)
    #>
    param(
        [string]$DbEngine,
        [string]$DbHost,
        [int]$Port,
        [string]$Username,
        [string]$Password
    )

    [PSCustomObject]@{
        PSTypeName = 'DBBPC.ConnectionParams'
        DbEngine   = $DbEngine
        DbHost     = $DbHost
        Port       = $Port
        Username   = $Username
        Password   = $Password
    }
}

function New-CheckResult {
    <#
    .SYNOPSIS
        Creates a CheckResult object representing the outcome of a single diagnostic check.
    .PARAMETER ScriptName
        Filename of the source script
    .PARAMETER CheckName
        Human-readable check identifier
    .PARAMETER CheckLevel
        INSTANCE, DATABASE, or TABLE
    .PARAMETER Status
        PASSED, FLAGGED, ERROR, or INSUFFICIENT_DATA
    .PARAMETER Severity
        OK, ADVISORY, or CRITICAL
    .PARAMETER CurrentValue
        Retrieved configuration value
    .PARAMETER DefaultValue
        Engine default value (may be empty)
    .PARAMETER Message
        Descriptive finding text
    .PARAMETER Details
        Array of DetailRow objects for multi-row checks
    #>
    param(
        [string]$ScriptName,
        [string]$CheckName,
        [CheckLevel]$CheckLevel,
        [CheckStatus]$Status,
        [Severity]$Severity,
        [string]$CurrentValue = '',
        [string]$DefaultValue = '',
        [string]$Message = '',
        [array]$Details = @()
    )

    [PSCustomObject]@{
        PSTypeName   = 'DBBPC.CheckResult'
        ScriptName   = $ScriptName
        CheckName    = $CheckName
        CheckLevel   = $CheckLevel
        Status       = $Status
        Severity     = $Severity
        CurrentValue = $CurrentValue
        DefaultValue = $DefaultValue
        Message      = $Message
        Details      = $Details
    }
}

function New-DetailRow {
    <#
    .SYNOPSIS
        Creates a DetailRow object for per-object details in multi-row checks.
    .PARAMETER ObjectName
        Schema.table or database name
    .PARAMETER ColumnName
        Column name (may be empty)
    .PARAMETER Finding
        Specific finding for this object
    .PARAMETER Value
        Associated value
    #>
    param(
        [string]$ObjectName = '',
        [string]$ColumnName = '',
        [string]$Finding = '',
        [string]$Value = ''
    )

    [PSCustomObject]@{
        PSTypeName = 'DBBPC.DetailRow'
        ObjectName = $ObjectName
        ColumnName = $ColumnName
        Finding    = $Finding
        Value      = $Value
    }
}

function New-ReportMetadata {
    <#
    .SYNOPSIS
        Creates a ReportMetadata object for the HTML report header.
    .PARAMETER DbEngine
        Engine that was checked
    .PARAMETER DbHost
        Target host
    .PARAMETER Timestamp
        ISO 8601 execution timestamp
    .PARAMETER TotalPassed
        Count of passed checks
    .PARAMETER TotalFlagged
        Count of flagged checks
    #>
    param(
        [string]$DbEngine,
        [string]$DbHost,
        [string]$Timestamp,
        [int]$TotalPassed = 0,
        [int]$TotalFlagged = 0
    )

    [PSCustomObject]@{
        PSTypeName  = 'DBBPC.ReportMetadata'
        DbEngine    = $DbEngine
        DbHost      = $DbHost
        Timestamp   = $Timestamp
        TotalPassed = $TotalPassed
        TotalFlagged = $TotalFlagged
    }
}

function New-ScriptFile {
    <#
    .SYNOPSIS
        Creates a ScriptFile object representing a discovered diagnostic script.
    .PARAMETER Filename
        Script filename (e.g., "01_cpu_utilization.sql")
    .PARAMETER FullPath
        Absolute path to the script
    .PARAMETER Content
        Loaded file content
    #>
    param(
        [string]$Filename,
        [string]$FullPath,
        [string]$Content
    )

    [PSCustomObject]@{
        PSTypeName = 'DBBPC.ScriptFile'
        Filename   = $Filename
        FullPath   = $FullPath
        Content    = $Content
    }
}

# --- Constants ---

$script:ENGINE_DIRECTORY_MAP = @{
    'mssql'    = 'mssql'
    'mysql'    = 'mysql'
    'oracle'   = 'oracle'
    'postgres' = 'pgsql'
    'mongodb'  = 'mongodb'
}
