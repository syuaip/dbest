# ScriptRunner.ps1 - Script execution and result parsing

function Invoke-DiagnosticScripts {
    <#
    .SYNOPSIS
        Executes diagnostic scripts against the connected database and collects results.
    .DESCRIPTION
        Iterates through the provided scripts in order, executing each script's SQL/JS content
        against the connection handle. On execution failure, captures the error into a CheckResult
        with Status=ERROR and continues executing remaining scripts.
    .PARAMETER Connection
        A database connection handle (driver-specific .NET object or MongoDB client).
    .PARAMETER Scripts
        Array of ScriptFile PSCustomObjects, already sorted alphabetically.
    .PARAMETER DbEngine
        The database engine identifier (mssql, mysql, oracle, postgres, mongodb).
    .OUTPUTS
        PSCustomObject[] Array of CheckResult objects from all executed scripts.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Scripts,

        [Parameter(Mandatory = $true)]
        [string]$DbEngine
    )

    $results = @()

    foreach ($script in $Scripts) {
        # Check for unreadable file (content is null or empty)
        if ([string]::IsNullOrWhiteSpace($script.Content)) {
            Write-Error "Warning: Script '$($script.Filename)' is unreadable or empty, skipping."
            continue
        }

        try {
            if ($DbEngine -eq 'mongodb') {
                $rawResults = Invoke-MongoDbScript -Connection $Connection -Script $script
            }
            else {
                $rawResults = Invoke-SqlScript -Connection $Connection -Script $script -DbEngine $DbEngine
            }

            # Parse the raw results into a CheckResult
            $checkResult = ConvertTo-CheckResult -Script $script -RawResults $rawResults
            $results += $checkResult
        }
        catch {
            # Capture execution failure as ERROR CheckResult
            $errorResult = New-CheckResult `
                -ScriptName $script.Filename `
                -CheckName (Get-CheckNameFromFilename -Filename $script.Filename) `
                -CheckLevel ([CheckLevel]::INSTANCE) `
                -Status ([CheckStatus]::ERROR) `
                -Severity ([Severity]::ADVISORY) `
                -CurrentValue '' `
                -DefaultValue '' `
                -Message "Script execution failed: $($_.Exception.GetType().Name): $($_.Exception.Message)" `
                -Details @()
            $results += $errorResult
        }
    }

    return $results
}

function Invoke-SqlScript {
    <#
    .SYNOPSIS
        Executes a SQL script against the connection and returns result rows as hashtable arrays.
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Connection,

        [Parameter(Mandatory)]
        [PSCustomObject]$Script,

        [Parameter(Mandatory)]
        [string]$DbEngine
    )

    $cmd = $Connection.CreateCommand()

    try {
        $cmd.CommandText = $Script.Content
        $reader = $cmd.ExecuteReader()

        try {
            $results = @()

            while ($reader.Read()) {
                $row = @{}
                for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                    $columnName = $reader.GetName($i)
                    $value = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) }
                    $row[$columnName] = $value
                }
                $results += $row
            }

            return , $results
        }
        finally {
            $reader.Close()
            $reader.Dispose()
        }
    }
    finally {
        $cmd.Dispose()
    }
}

function Invoke-MongoDbScript {
    <#
    .SYNOPSIS
        Executes a MongoDB script using RunCommand and returns result rows.
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Connection,

        [Parameter(Mandatory)]
        [PSCustomObject]$Script
    )

    $content = $Script.Content.Trim()

    try {
        # Attempt to parse as BSON/JSON command document
        $commandDoc = [MongoDB.Bson.BsonDocument]::Parse($content)
        $adminDb = $Connection.GetDatabase('admin')

        # Use reflection to call the generic RunCommand method
        $runCommandMethod = $adminDb.GetType().GetMethod('RunCommand').MakeGenericMethod([MongoDB.Bson.BsonDocument])
        $result = $runCommandMethod.Invoke($adminDb, @($commandDoc, $null))

        $dict = ConvertFrom-BsonDocument -Document $result
        return , @($dict)
    }
    catch {
        # If not valid JSON/BSON, try eval command
        try {
            $adminDb = $Connection.GetDatabase('admin')
            $evalCommand = [MongoDB.Bson.BsonDocument]::new('eval', $content)
            $runCommandMethod = $adminDb.GetType().GetMethod('RunCommand').MakeGenericMethod([MongoDB.Bson.BsonDocument])
            $result = $runCommandMethod.Invoke($adminDb, @($evalCommand, $null))

            $dict = ConvertFrom-BsonDocument -Document $result
            return , @($dict)
        }
        catch {
            throw
        }
    }
}

function ConvertFrom-BsonDocument {
    <#
    .SYNOPSIS
        Converts a BsonDocument to a PowerShell hashtable.
    #>
    param(
        [Parameter(Mandatory)]
        [MongoDB.Bson.BsonDocument]$Document
    )

    $dict = @{}
    foreach ($element in $Document) {
        $dict[$element.Name] = ConvertFrom-BsonValue -Value $element.Value
    }
    return $dict
}

function ConvertFrom-BsonValue {
    <#
    .SYNOPSIS
        Converts a BsonValue to a .NET object.
    #>
    param(
        [Parameter(Mandatory)]
        [MongoDB.Bson.BsonValue]$Value
    )

    if ($Value.IsBsonNull) { return $null }
    if ($Value.IsString) { return $Value.AsString }
    if ($Value.IsInt32) { return $Value.AsInt32 }
    if ($Value.IsInt64) { return $Value.AsInt64 }
    if ($Value.IsDouble) { return $Value.AsDouble }
    if ($Value.IsBoolean) { return $Value.AsBoolean }
    return $Value.ToString()
}

function Get-CheckNameFromFilename {
    <#
    .SYNOPSIS
        Derives a human-readable check name from a script filename.
    .DESCRIPTION
        Strips the file extension, removes leading numeric prefixes and underscores,
        and converts underscores to spaces with title case.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Filename
    )

    # Remove extension
    $name = [System.IO.Path]::GetFileNameWithoutExtension($Filename)

    # Remove leading numeric prefix (e.g., '01_')
    $underscoreIndex = $name.IndexOf('_')
    if ($underscoreIndex -gt 0) {
        $prefix = $name.Substring(0, $underscoreIndex)
        if ($prefix -match '^\d+$') {
            $name = $name.Substring($underscoreIndex + 1)
        }
    }

    # Convert underscores to spaces and title case each word
    $words = $name -split '_'
    $titleCased = $words | ForEach-Object {
        if ($_.Length -gt 0) {
            $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower()
        }
        else {
            $_
        }
    }

    return ($titleCased -join ' ')
}

function ConvertTo-CheckResult {
    <#
    .SYNOPSIS
        Parses raw script execution results into a CheckResult PSCustomObject.
    .DESCRIPTION
        Scripts are expected to return a result set with standardized column names:
        check_name, check_level, status, severity, current_value, default_value, message.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Script,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$RawResults
    )

    if ($RawResults.Count -eq 0) {
        return New-CheckResult `
            -ScriptName $Script.Filename `
            -CheckName (Get-CheckNameFromFilename -Filename $Script.Filename) `
            -CheckLevel ([CheckLevel]::INSTANCE) `
            -Status ([CheckStatus]::PASSED) `
            -Severity ([Severity]::OK) `
            -CurrentValue '' `
            -DefaultValue '' `
            -Message 'Check completed with no findings' `
            -Details @()
    }

    # Use the first row as the primary result
    $row = $RawResults[0]

    # Extract standardized fields with defaults
    $checkName = Get-RowStringValue -Row $row -Key 'check_name' -Default (Get-CheckNameFromFilename -Filename $Script.Filename)

    # Parse check_level
    $checkLevelStr = (Get-RowStringValue -Row $row -Key 'check_level' -Default 'INSTANCE').ToUpper()
    $checkLevel = switch ($checkLevelStr) {
        'INSTANCE' { [CheckLevel]::INSTANCE }
        'DATABASE' { [CheckLevel]::DATABASE }
        'TABLE'    { [CheckLevel]::TABLE }
        default    { [CheckLevel]::INSTANCE }
    }

    # Parse status
    $statusStr = (Get-RowStringValue -Row $row -Key 'status' -Default 'PASSED').ToUpper()
    $status = switch ($statusStr) {
        'PASSED'            { [CheckStatus]::PASSED }
        'FLAGGED'           { [CheckStatus]::FLAGGED }
        'ERROR'             { [CheckStatus]::ERROR }
        'INSUFFICIENT_DATA' { [CheckStatus]::INSUFFICIENT_DATA }
        default             { [CheckStatus]::PASSED }
    }

    # Parse severity
    $severityStr = (Get-RowStringValue -Row $row -Key 'severity' -Default 'OK').ToUpper()
    $severity = switch ($severityStr) {
        'OK'       { [Severity]::OK }
        'ADVISORY' { [Severity]::ADVISORY }
        'CRITICAL' { [Severity]::CRITICAL }
        default    { [Severity]::OK }
    }

    $currentValue = Get-RowStringValue -Row $row -Key 'current_value' -Default ''
    $defaultValue = Get-RowStringValue -Row $row -Key 'default_value' -Default ''
    $message = Get-RowStringValue -Row $row -Key 'message' -Default ''

    # Parse detail rows if there are multiple result rows
    $details = @()
    if ($RawResults.Count -gt 1) {
        for ($i = 1; $i -lt $RawResults.Count; $i++) {
            $detailRow = $RawResults[$i]
            $detail = New-DetailRow `
                -ObjectName (Get-RowStringValue -Row $detailRow -Key 'object_name' -Default '') `
                -ColumnName (Get-RowStringValue -Row $detailRow -Key 'column_name' -Default '') `
                -Finding (Get-RowStringValue -Row $detailRow -Key 'finding' -Default '') `
                -Value (Get-RowStringValue -Row $detailRow -Key 'value' -Default '')
            $details += $detail
        }
    }

    return New-CheckResult `
        -ScriptName $Script.Filename `
        -CheckName $checkName `
        -CheckLevel $checkLevel `
        -Status $status `
        -Severity $severity `
        -CurrentValue $currentValue `
        -DefaultValue $defaultValue `
        -Message $message `
        -Details $details
}

function Get-RowStringValue {
    <#
    .SYNOPSIS
        Gets a string value from a result row hashtable, with a default fallback.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Row,

        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Default
    )

    if ($Row.ContainsKey($Key) -and $null -ne $Row[$Key]) {
        return [string]$Row[$Key]
    }
    return $Default
}
