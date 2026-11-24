# DbConnector.ps1 - Database connection using .NET classes

# Connection timeout in seconds
$script:ConnectionTimeout = 30

function Connect-Database {
    <#
    .SYNOPSIS
        Establishes and verifies a database connection using engine-appropriate .NET classes.
    .DESCRIPTION
        Loads required .NET assemblies, builds a connection string with 30-second timeout,
        opens the connection, and executes a health-check query (SELECT 1 for relational, ping for MongoDB).
        On failure, classifies the error and writes a descriptive message to the error stream, then exits with code 1.
    .PARAMETER ConnectionParams
        A PSCustomObject (DBBPC.ConnectionParams) with properties: DbEngine, DbHost, Port, Username, Password
    .OUTPUTS
        Connection handle object on success.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ConnectionParams
    )

    try {
        $connection = switch ($ConnectionParams.DbEngine) {
            'mssql'    { Connect-Mssql -Params $ConnectionParams }
            'mysql'    { Connect-Mysql -Params $ConnectionParams }
            'oracle'   { Connect-Oracle -Params $ConnectionParams }
            'postgres' { Connect-Postgres -Params $ConnectionParams }
            'mongodb'  { Connect-Mongodb -Params $ConnectionParams }
            default    { throw [System.InvalidOperationException]::new("Unsupported database engine '$($ConnectionParams.DbEngine)'.") }
        }
        return $connection
    }
    catch {
        $errorMessage = Get-ConnectionErrorMessage -Exception $_.Exception -ConnectionParams $ConnectionParams
        Write-Error $errorMessage
        exit 1
    }
}

function Connect-Mssql {
    <#
    .SYNOPSIS
        Connects to Microsoft SQL Server using Microsoft.Data.SqlClient.
    #>
    param([PSCustomObject]$Params)

    # Load the assembly
    $assemblyPath = Find-Assembly -AssemblyName 'Microsoft.Data.SqlClient'
    if ($assemblyPath) {
        Add-Type -Path $assemblyPath
    }

    $connectionString = "Server=$($Params.DbHost),$($Params.Port);" +
                        "User Id=$($Params.Username);" +
                        "Password=$($Params.Password);" +
                        "Connection Timeout=$script:ConnectionTimeout;" +
                        "TrustServerCertificate=True;"

    $conn = [Microsoft.Data.SqlClient.SqlConnection]::new($connectionString)
    $conn.Open()

    # Health-check query
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = 'SELECT 1'
    $null = $cmd.ExecuteScalar()
    $cmd.Dispose()

    return $conn
}

function Connect-Mysql {
    <#
    .SYNOPSIS
        Connects to MySQL using MySql.Data.MySqlClient.
    #>
    param([PSCustomObject]$Params)

    # Load the assembly
    $assemblyPath = Find-Assembly -AssemblyName 'MySql.Data'
    if ($assemblyPath) {
        Add-Type -Path $assemblyPath
    }

    $connectionString = "Server=$($Params.DbHost);" +
                        "Port=$($Params.Port);" +
                        "User Id=$($Params.Username);" +
                        "Password=$($Params.Password);" +
                        "Connection Timeout=$script:ConnectionTimeout;"

    $conn = [MySql.Data.MySqlClient.MySqlConnection]::new($connectionString)
    $conn.Open()

    # Health-check query
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = 'SELECT 1'
    $null = $cmd.ExecuteScalar()
    $cmd.Dispose()

    return $conn
}

function Connect-Oracle {
    <#
    .SYNOPSIS
        Connects to Oracle using Oracle.ManagedDataAccess.Client.
    #>
    param([PSCustomObject]$Params)

    # Load the assembly
    $assemblyPath = Find-Assembly -AssemblyName 'Oracle.ManagedDataAccess'
    if ($assemblyPath) {
        Add-Type -Path $assemblyPath
    }

    $connectionString = "Data Source=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=$($Params.DbHost))(PORT=$($Params.Port)))(CONNECT_DATA=(SERVICE_NAME=ORCL)));" +
                        "User Id=$($Params.Username);" +
                        "Password=$($Params.Password);" +
                        "Connection Timeout=$script:ConnectionTimeout;"

    $conn = [Oracle.ManagedDataAccess.Client.OracleConnection]::new($connectionString)
    $conn.Open()

    # Health-check query
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = 'SELECT 1 FROM DUAL'
    $null = $cmd.ExecuteScalar()
    $cmd.Dispose()

    return $conn
}

function Connect-Postgres {
    <#
    .SYNOPSIS
        Connects to PostgreSQL using Npgsql.
    #>
    param([PSCustomObject]$Params)

    # Load the assembly
    $assemblyPath = Find-Assembly -AssemblyName 'Npgsql'
    if ($assemblyPath) {
        Add-Type -Path $assemblyPath
    }

    $connectionString = "Host=$($Params.DbHost);" +
                        "Port=$($Params.Port);" +
                        "Username=$($Params.Username);" +
                        "Password=$($Params.Password);" +
                        "Timeout=$script:ConnectionTimeout;"

    $conn = [Npgsql.NpgsqlConnection]::new($connectionString)
    $conn.Open()

    # Health-check query
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = 'SELECT 1'
    $null = $cmd.ExecuteScalar()
    $cmd.Dispose()

    return $conn
}

function Connect-Mongodb {
    <#
    .SYNOPSIS
        Connects to MongoDB using MongoDB.Driver.
    #>
    param([PSCustomObject]$Params)

    # Load the assembly
    $assemblyPath = Find-Assembly -AssemblyName 'MongoDB.Driver'
    if ($assemblyPath) {
        Add-Type -Path $assemblyPath
    }

    # Also load MongoDB.Bson if available
    $bsonPath = Find-Assembly -AssemblyName 'MongoDB.Bson'
    if ($bsonPath) {
        Add-Type -Path $bsonPath
    }

    $uri = "mongodb://$($Params.Username):$($Params.Password)@$($Params.DbHost):$($Params.Port)/"

    $settings = [MongoDB.Driver.MongoClientSettings]::FromConnectionString($uri)
    $settings.ServerSelectionTimeout = [System.TimeSpan]::FromSeconds($script:ConnectionTimeout)
    $settings.ConnectTimeout = [System.TimeSpan]::FromSeconds($script:ConnectionTimeout)

    $client = [MongoDB.Driver.MongoClient]::new($settings)

    # Health-check: ping the admin database
    $adminDb = $client.GetDatabase('admin')
    $pingCommand = [MongoDB.Bson.BsonDocument]::new('ping', [MongoDB.Bson.BsonInt32]::new(1))
    $runCommandMethod = $adminDb.GetType().GetMethod('RunCommand').MakeGenericMethod([MongoDB.Bson.BsonDocument])
    $null = $runCommandMethod.Invoke($adminDb, @($pingCommand, $null))

    return $client
}

function Find-Assembly {
    <#
    .SYNOPSIS
        Attempts to find a .NET assembly by name in common NuGet package locations.
    .DESCRIPTION
        Searches for the assembly DLL in the user's NuGet package cache and common paths.
        Returns the path if found, or $null if the assembly should already be loaded.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$AssemblyName
    )

    # Check if the assembly is already loaded
    $loaded = [System.AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq $AssemblyName }
    if ($loaded) {
        return $null
    }

    # Search in common NuGet package cache locations
    $nugetPaths = @(
        [System.IO.Path]::Combine($env:USERPROFILE, '.nuget', 'packages'),
        [System.IO.Path]::Combine($HOME, '.nuget', 'packages'),
        '/usr/local/share/dotnet/shared',
        '/usr/share/dotnet/shared'
    )

    $assemblyNameLower = $AssemblyName.ToLower()

    foreach ($basePath in $nugetPaths) {
        if (-not (Test-Path $basePath)) { continue }

        $packageDir = [System.IO.Path]::Combine($basePath, $assemblyNameLower)
        if (Test-Path $packageDir) {
            # Find the latest version directory
            $versionDirs = Get-ChildItem -Path $packageDir -Directory | Sort-Object Name -Descending
            foreach ($versionDir in $versionDirs) {
                # Look for the DLL in lib/net8.0, lib/net7.0, lib/net6.0, lib/netstandard2.1, lib/netstandard2.0
                $targetFrameworks = @('net8.0', 'net7.0', 'net6.0', 'netstandard2.1', 'netstandard2.0')
                foreach ($tfm in $targetFrameworks) {
                    $dllPath = [System.IO.Path]::Combine($versionDir.FullName, 'lib', $tfm, "$AssemblyName.dll")
                    if (Test-Path $dllPath) {
                        return $dllPath
                    }
                }
            }
        }
    }

    # If not found in NuGet cache, try to find alongside the C# project output
    $scriptDir = $PSScriptRoot
    $repoRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent
    $csharpBinPaths = @(
        [System.IO.Path]::Combine($repoRoot, 'csharp', 'dbbpc', 'bin', 'Debug', 'net8.0'),
        [System.IO.Path]::Combine($repoRoot, 'csharp', 'dbbpc', 'bin', 'Release', 'net8.0'),
        [System.IO.Path]::Combine($repoRoot, 'csharp', 'dbbpc', 'bin', 'Debug', 'net8.0', 'linux-x64'),
        [System.IO.Path]::Combine($repoRoot, 'csharp', 'dbbpc', 'bin', 'Release', 'net8.0', 'linux-x64')
    )

    foreach ($binPath in $csharpBinPaths) {
        if (-not (Test-Path $binPath)) { continue }
        $dllPath = [System.IO.Path]::Combine($binPath, "$AssemblyName.dll")
        if (Test-Path $dllPath) {
            return $dllPath
        }
    }

    # Assembly not found - return null and let .NET runtime resolve it
    return $null
}

function Get-ConnectionErrorMessage {
    <#
    .SYNOPSIS
        Classifies a connection exception and returns a formatted error message.
    .DESCRIPTION
        Inspects the exception type and message for keywords to classify the error as
        timeout, authentication, or network, then formats the appropriate message.
    #>
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception,

        [Parameter(Mandatory)]
        [PSCustomObject]$ConnectionParams
    )

    $errorClass = Get-ErrorClassification -Exception $Exception

    switch ($errorClass) {
        'timeout' {
            return "Connection timed out connecting to $($ConnectionParams.DbHost):$($ConnectionParams.Port)"
        }
        'authentication' {
            return "Authentication failed for user '$($ConnectionParams.Username)' on $($ConnectionParams.DbHost)"
        }
        default {
            return "Cannot reach $($ConnectionParams.DbHost):$($ConnectionParams.Port) $([char]0x2014) verify host and network"
        }
    }
}

function Get-ErrorClassification {
    <#
    .SYNOPSIS
        Classifies a connection exception into a category: timeout, authentication, or network.
    .DESCRIPTION
        Inspects the exception type name and message for keywords to determine the error category.
    #>
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    $excType = $Exception.GetType().Name.ToLower()
    $excMsg = $Exception.Message.ToLower()

    # Also check inner exception message if available
    $innerMsg = ''
    if ($Exception.InnerException) {
        $innerMsg = $Exception.InnerException.Message.ToLower()
    }

    $combinedMsg = "$excMsg $innerMsg"

    # Timeout detection
    $timeoutIndicators = @('timeout', 'timed out', 'connection timed out')
    foreach ($indicator in $timeoutIndicators) {
        if ($combinedMsg.Contains($indicator) -or $excType.Contains($indicator.Replace(' ', ''))) {
            return 'timeout'
        }
    }

    # Authentication failure detection
    $authIndicators = @('authentication', 'login failed', 'access denied', 'invalid credentials', 'password', 'logon', 'ora-01017')
    foreach ($indicator in $authIndicators) {
        if ($combinedMsg.Contains($indicator) -or $excType.Contains($indicator.Replace(' ', ''))) {
            return 'authentication'
        }
    }

    # Network error (default fallback)
    return 'network'
}
