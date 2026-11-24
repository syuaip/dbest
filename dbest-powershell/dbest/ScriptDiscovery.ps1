# ScriptDiscovery.ps1 - Engine directory resolution and script scanning

function Find-DiagnosticScripts {
    <#
    .SYNOPSIS
        Discovers and loads diagnostic scripts for the given database engine.
    .DESCRIPTION
        Resolves the engine-specific directory, scans for eligible script files (.sql or .js),
        sorts them alphabetically by filename, and loads their content using UTF-8 encoding.
    .PARAMETER DbEngine
        The database engine name (mssql, mysql, oracle, postgres, mongodb).
    .PARAMETER BasePath
        Optional base path for resolving engine directories.
        If not provided, defaults to the parent of the powershell/ directory (repository root).
    .OUTPUTS
        PSCustomObject[] Array of ScriptFile objects sorted alphabetically by filename.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DbEngine,

        [Parameter(Mandatory = $false)]
        [string]$BasePath
    )

    # Determine the base path (repository root) if not provided
    if (-not $BasePath) {
        # Resolve relative to the powershell/ directory — look for dbscript sibling folder
        $scriptDir = $PSScriptRoot
        $powershellDir = Split-Path -Parent $scriptDir
        $BasePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($powershellDir, 'dbscript'))
    }

    # Get the directory name for this engine from the map
    $directoryName = $script:ENGINE_DIRECTORY_MAP[$DbEngine]
    if (-not $directoryName) {
        $validEngines = ($script:ENGINE_DIRECTORY_MAP.Keys | Sort-Object) -join ', '
        Write-Error "Error: Unknown database engine '$DbEngine'. Valid engines: $validEngines"
        exit 1
    }

    # Resolve the full path to the engine directory using cross-platform path construction
    $engineDir = [System.IO.Path]::Combine($BasePath, $directoryName)

    Write-Host "Info: Fetching scripts from '$engineDir': loading..." -ForegroundColor Cyan

    # Check if the directory exists
    if (-not (Test-Path -Path $engineDir -PathType Container)) {
        Write-Error "Error: Engine directory not found: $engineDir"
        exit 1
    }

    # Determine the file extension to scan for
    $extension = if ($DbEngine -eq 'mongodb') { '.js' } else { '.sql' }

    # Scan for eligible script files
    $files = Get-ChildItem -Path $engineDir -File |
        Where-Object { $_.Extension -eq $extension } |
        Sort-Object -Property Name

    # Error if no eligible scripts found
    if (-not $files -or $files.Count -eq 0) {
        Write-Error "Error: No $extension scripts found in engine directory: $engineDir"
        exit 1
    }

    # Load file content using UTF-8 encoding and build ScriptFile objects
    $scriptFiles = @()
    foreach ($file in $files) {
        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $scriptFiles += New-ScriptFile -Filename $file.Name -FullPath $file.FullName -Content $content
    }

    return $scriptFiles
}
