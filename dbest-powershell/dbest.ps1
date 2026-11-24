#Requires -Version 5.1

param(
    [string]$DbEngine,
    [string]$DbHost,
    [string]$Port,
    [string]$Username,
    [string]$Password
)

# Dot-source all component scripts from the dbest/ subdirectory
$componentDir = [System.IO.Path]::Combine($PSScriptRoot, 'dbest')
. ([System.IO.Path]::Combine($componentDir, 'Models.ps1'))
. ([System.IO.Path]::Combine($componentDir, 'CliParser.ps1'))
. ([System.IO.Path]::Combine($componentDir, 'DbConnector.ps1'))
. ([System.IO.Path]::Combine($componentDir, 'ScriptDiscovery.ps1'))
. ([System.IO.Path]::Combine($componentDir, 'ScriptRunner.ps1'))
. ([System.IO.Path]::Combine($componentDir, 'ReportGenerator.ps1'))

try {
    # Step 1: Parse and validate CLI arguments
    $connectionParams = Invoke-CliParser -DbEngine $DbEngine -DbHost $DbHost -Port $Port -Username $Username -Password $Password

    # Step 2: Establish database connection
    $connection = Connect-Database -ConnectionParams $connectionParams

    # Step 3: Discover diagnostic scripts for the engine
    $scripts = Find-DiagnosticScripts -DbEngine $connectionParams.DbEngine

    # Step 4: Execute diagnostic scripts against the database
    $results = Invoke-DiagnosticScripts -Connection $connection -Scripts $scripts -DbEngine $connectionParams.DbEngine

    # Step 5: Build report metadata
    $totalPassed = @($results | Where-Object { $_.Status -eq [CheckStatus]::PASSED }).Count
    $totalFlagged = @($results | Where-Object { $_.Status -eq [CheckStatus]::FLAGGED -or $_.Status -eq [CheckStatus]::ERROR }).Count

    $metadata = New-ReportMetadata `
        -DbEngine $connectionParams.DbEngine `
        -DbHost $connectionParams.DbHost `
        -Timestamp ([System.DateTime]::UtcNow.ToString('o')) `
        -TotalPassed $totalPassed `
        -TotalFlagged $totalFlagged

    # Step 6: Generate the HTML report
    $reportPath = New-HtmlReport -Results $results -Metadata $metadata

    # Step 7: Print success message
    Write-Output "Report generated successfully: $reportPath"

    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
