# CliParser.ps1 - CLI argument parsing and validation

# Valid database engine values (case-sensitive)
$script:VALID_ENGINES = @("mssql", "mysql", "oracle", "postgres", "mongodb")

function Invoke-ExitWithCode {
    <#
    .SYNOPSIS
        Wrapper around exit to allow mocking in tests.
    #>
    param([int]$ExitCode)
    exit $ExitCode
}

function Invoke-CliParser {
    <#
    .SYNOPSIS
        Parse and validate CLI arguments, returning a ConnectionParams object.
    .DESCRIPTION
        Accepts database connection parameters, validates them, and returns a
        ConnectionParams PSCustomObject. Supports both PowerShell-style parameters
        (-DbEngine) and long-form (--dbengine) for Python CLI compatibility.
        On missing or invalid parameters, writes error to error stream and exits with code 1.
    .PARAMETER DbEngine
        Database engine type. Valid values: mssql, mysql, oracle, postgres, mongodb
    .PARAMETER DbHost
        Database hostname or IP address (non-empty)
    .PARAMETER Port
        Database port number (1-65535)
    .PARAMETER Username
        Database username
    .PARAMETER Password
        Database password (will prompt if not provided)
    #>
    param(
        [string]$DbEngine,
        [string]$DbHost,
        [string]$Port,
        [string]$Username,
        [string]$Password
    )

    # Check for missing required parameters
    if ([string]::IsNullOrEmpty($DbEngine) -or
        [string]::IsNullOrEmpty($DbHost) -or
        [string]::IsNullOrEmpty($Port) -or
        [string]::IsNullOrEmpty($Username)) {
        Write-Error "usage: dbest --dbengine <engine> --dbhost <host> --port <port> --username <user> [--password <pass>]

Database Evaluation & Summary Tool (DBEST) - Analyze database instances against best practices.

Required arguments:
  --dbengine    Database engine type. Valid values: mssql, mysql, oracle, postgres, mongodb
  --dbhost      Database hostname or IP address (non-empty)
  --port        Database port number (1-65535)
  --username    Database username

Optional arguments:
  --password    Database password (will prompt if not provided)"
        Invoke-ExitWithCode -ExitCode 1
    }

    # Validate DbHost is non-empty (handles whitespace-only strings)
    if ([string]::IsNullOrWhiteSpace($DbHost)) {
        Write-Error "Error: dbhost must be a non-empty hostname or IP address."
        Invoke-ExitWithCode -ExitCode 1
    }

    # Validate DbEngine against allowed values (case-sensitive)
    if ($DbEngine -cnotin $script:VALID_ENGINES) {
        Write-Error "Error: Invalid dbengine '$DbEngine'. Valid values are: $($script:VALID_ENGINES -join ', ')"
        Invoke-ExitWithCode -ExitCode 1
    }

    # Validate Port is numeric integer in range 1-65535
    $portNumber = 0
    if (-not [int]::TryParse($Port, [ref]$portNumber)) {
        Write-Error "Error: Invalid port '$Port'. Port must be a numeric integer between 1 and 65535."
        Invoke-ExitWithCode -ExitCode 1
    }

    if ($portNumber -lt 1 -or $portNumber -gt 65535) {
        Write-Error "Error: Invalid port '$portNumber'. Port must be a numeric integer between 1 and 65535."
        Invoke-ExitWithCode -ExitCode 1
    }

    # Handle password - prompt if not provided
    $passwordValue = $Password
    if ([string]::IsNullOrEmpty($Password)) {
        $securePassword = Read-Host -Prompt "give me password to access the database: " -AsSecureString
        $passwordValue = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        )
    }

    # Return ConnectionParams PSCustomObject
    return New-ConnectionParams -DbEngine $DbEngine -DbHost $DbHost -Port $portNumber -Username $Username -Password $passwordValue
}
