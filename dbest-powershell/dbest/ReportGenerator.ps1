# ReportGenerator.ps1 - HTML report generation for the Database Best Practices Checker (PowerShell port)

function ConvertTo-HtmlEncoded {
    <#
    .SYNOPSIS
        Escapes HTML special characters in a string using entity encoding.
    .PARAMETER Text
        The string to escape.
    #>
    param(
        [string]$Text
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return ''
    }

    $Text = $Text.Replace('&', '&amp;')
    $Text = $Text.Replace('<', '&lt;')
    $Text = $Text.Replace('>', '&gt;')
    $Text = $Text.Replace('"', '&quot;')
    $Text = $Text.Replace("'", '&#x27;')
    return $Text
}

function Get-SeverityColor {
    <#
    .SYNOPSIS
        Returns the CSS color class based on severity and status.
    .PARAMETER Severity
        The Severity enum value (OK, ADVISORY, CRITICAL).
    .PARAMETER Status
        The CheckStatus enum value (PASSED, FLAGGED, ERROR, INSUFFICIENT_DATA).
    #>
    param(
        [Severity]$Severity,
        [CheckStatus]$Status
    )

    if ($Status -eq [CheckStatus]::ERROR) {
        return 'red'
    }
    if ($Severity -eq [Severity]::OK -or $Status -eq [CheckStatus]::PASSED) {
        return 'green'
    }
    if ($Severity -eq [Severity]::ADVISORY) {
        return 'amber'
    }
    if ($Severity -eq [Severity]::CRITICAL) {
        return 'red'
    }
    # Default for INSUFFICIENT_DATA or other cases
    return 'amber'
}

function Get-CssColorValue {
    <#
    .SYNOPSIS
        Returns the actual CSS hex color value for a color class name.
    #>
    param(
        [string]$ColorClass
    )

    switch ($ColorClass) {
        'green' { return '#28a745' }
        'amber' { return '#ffc107' }
        'red'   { return '#dc3545' }
        default { return '#6c757d' }
    }
}

function New-HtmlReport {
    <#
    .SYNOPSIS
        Generates an HTML report from check results and metadata.
    .DESCRIPTION
        Transforms check results into a structured, color-coded HTML report.
        Groups results by CheckLevel (INSTANCE, DATABASE, TABLE).
        Writes the report to dbbpc.html in the current working directory.
    .PARAMETER Results
        Array of CheckResult PSCustomObjects from script execution.
    .PARAMETER Metadata
        ReportMetadata PSCustomObject with summary information.
    .OUTPUTS
        String - the file path of the written HTML report.
    #>
    param(
        [PSCustomObject[]]$Results,
        [PSCustomObject]$Metadata
    )

    # Group results by CheckLevel
    $instanceResults = @($Results | Where-Object { $_.CheckLevel -eq [CheckLevel]::INSTANCE })
    $databaseResults = @($Results | Where-Object { $_.CheckLevel -eq [CheckLevel]::DATABASE })
    $tableResults = @($Results | Where-Object { $_.CheckLevel -eq [CheckLevel]::TABLE })

    $sb = [System.Text.StringBuilder]::new()

    # HTML document start
    [void]$sb.AppendLine('<!DOCTYPE html>')
    [void]$sb.AppendLine('<html lang="en">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="UTF-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1.0">')
    [void]$sb.AppendLine('<title>Database Evaluation &amp; Summary Report</title>')
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('  body {')
    [void]$sb.AppendLine("    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;")
    [void]$sb.AppendLine('    margin: 0;')
    [void]$sb.AppendLine('    padding: 20px;')
    [void]$sb.AppendLine('    background-color: #f8f9fa;')
    [void]$sb.AppendLine('    color: #212529;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .header {')
    [void]$sb.AppendLine('    background-color: #343a40;')
    [void]$sb.AppendLine('    color: #ffffff;')
    [void]$sb.AppendLine('    padding: 20px 30px;')
    [void]$sb.AppendLine('    border-radius: 8px;')
    [void]$sb.AppendLine('    margin-bottom: 30px;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .header h1 {')
    [void]$sb.AppendLine('    margin: 0 0 15px 0;')
    [void]$sb.AppendLine('    font-size: 1.5em;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .summary {')
    [void]$sb.AppendLine('    display: flex;')
    [void]$sb.AppendLine('    flex-wrap: wrap;')
    [void]$sb.AppendLine('    gap: 20px;')
    [void]$sb.AppendLine('    align-items: center;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .summary-item {')
    [void]$sb.AppendLine('    display: flex;')
    [void]$sb.AppendLine('    flex-direction: column;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .summary-label {')
    [void]$sb.AppendLine('    font-size: 0.8em;')
    [void]$sb.AppendLine('    opacity: 0.8;')
    [void]$sb.AppendLine('    text-transform: uppercase;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .summary-value {')
    [void]$sb.AppendLine('    font-size: 1.2em;')
    [void]$sb.AppendLine('    font-weight: bold;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .passed-count { color: #28a745; }')
    [void]$sb.AppendLine('  .flagged-count { color: #dc3545; }')
    [void]$sb.AppendLine('  .section {')
    [void]$sb.AppendLine('    margin-bottom: 30px;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .section h2 {')
    [void]$sb.AppendLine('    color: #343a40;')
    [void]$sb.AppendLine('    border-bottom: 2px solid #dee2e6;')
    [void]$sb.AppendLine('    padding-bottom: 8px;')
    [void]$sb.AppendLine('    margin-bottom: 15px;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .results-table {')
    [void]$sb.AppendLine('    width: 100%;')
    [void]$sb.AppendLine('    border-collapse: collapse;')
    [void]$sb.AppendLine('    background-color: #ffffff;')
    [void]$sb.AppendLine('    border-radius: 8px;')
    [void]$sb.AppendLine('    overflow: hidden;')
    [void]$sb.AppendLine('    box-shadow: 0 1px 3px rgba(0,0,0,0.1);')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .results-table th {')
    [void]$sb.AppendLine('    background-color: #495057;')
    [void]$sb.AppendLine('    color: #ffffff;')
    [void]$sb.AppendLine('    padding: 12px 15px;')
    [void]$sb.AppendLine('    text-align: left;')
    [void]$sb.AppendLine('    font-size: 0.85em;')
    [void]$sb.AppendLine('    text-transform: uppercase;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .results-table td {')
    [void]$sb.AppendLine('    padding: 10px 15px;')
    [void]$sb.AppendLine('    border-bottom: 1px solid #dee2e6;')
    [void]$sb.AppendLine('    font-size: 0.9em;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .results-table tr.green { background-color: #28a74520; border-left: 4px solid #28a745; }')
    [void]$sb.AppendLine('  .results-table tr.amber { background-color: #ffc10720; border-left: 4px solid #ffc107; }')
    [void]$sb.AppendLine('  .results-table tr.red { background-color: #dc354520; border-left: 4px solid #dc3545; }')
    [void]$sb.AppendLine('  .details-table {')
    [void]$sb.AppendLine('    width: 100%;')
    [void]$sb.AppendLine('    border-collapse: collapse;')
    [void]$sb.AppendLine('    margin: 5px 0;')
    [void]$sb.AppendLine('    font-size: 0.85em;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .details-table th {')
    [void]$sb.AppendLine('    background-color: #e9ecef;')
    [void]$sb.AppendLine('    padding: 6px 10px;')
    [void]$sb.AppendLine('    text-align: left;')
    [void]$sb.AppendLine('    color: #495057;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('  .details-table td {')
    [void]$sb.AppendLine('    padding: 5px 10px;')
    [void]$sb.AppendLine('    border-bottom: 1px solid #f1f3f5;')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')

    # Summary header
    [void]$sb.AppendLine('<div class="header">')
    [void]$sb.AppendLine('<h1>Database Evaluation &amp; Summary Report</h1>')
    [void]$sb.AppendLine('<div class="summary">')
    [void]$sb.AppendLine('<div class="summary-item">')
    [void]$sb.AppendLine('  <span class="summary-label">Engine</span>')
    [void]$sb.AppendLine("  <span class=""summary-value"">$(ConvertTo-HtmlEncoded $Metadata.DbEngine)</span>")
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('<div class="summary-item">')
    [void]$sb.AppendLine('  <span class="summary-label">Host</span>')
    [void]$sb.AppendLine("  <span class=""summary-value"">$(ConvertTo-HtmlEncoded $Metadata.DbHost)</span>")
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('<div class="summary-item">')
    [void]$sb.AppendLine('  <span class="summary-label">Timestamp</span>')
    [void]$sb.AppendLine("  <span class=""summary-value"">$(ConvertTo-HtmlEncoded $Metadata.Timestamp)</span>")
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('<div class="summary-item">')
    [void]$sb.AppendLine('  <span class="summary-label">Passed</span>')
    [void]$sb.AppendLine("  <span class=""summary-value passed-count"">$($Metadata.TotalPassed)</span>")
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('<div class="summary-item">')
    [void]$sb.AppendLine('  <span class="summary-label">Flagged</span>')
    [void]$sb.AppendLine("  <span class=""summary-value flagged-count"">$($Metadata.TotalFlagged)</span>")
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('</div>')

    # Render sections in order: Instance → Database → Table
    if ($instanceResults.Count -gt 0) {
        [void]$sb.Append((Render-Section -LevelName 'Instance' -Results $instanceResults))
    }
    if ($databaseResults.Count -gt 0) {
        [void]$sb.Append((Render-Section -LevelName 'Database' -Results $databaseResults))
    }
    if ($tableResults.Count -gt 0) {
        [void]$sb.Append((Render-Section -LevelName 'Table' -Results $tableResults))
    }

    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')

    # Write report with unique filename based on engine + host + timestamp
    $fileName = "dbest" `
        + "_" + $Metadata.DbEngine.Replace(" ", "_") `
        + "_" + $Metadata.DbHost.Replace(" ", "_") `
        + "_" + $Metadata.Timestamp.Replace(" ", "_").Replace(":", "-") `
        + ".html"
    $outputPath = [System.IO.Path]::Combine((Get-Location).Path, $fileName)

    try {
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($outputPath, $sb.ToString(), $utf8NoBom)
    }
    catch {
        Write-Error "Cannot write report to '$outputPath': $($_.Exception.Message)"
        exit 1
    }

    return $outputPath
}

function Render-Section {
    <#
    .SYNOPSIS
        Renders a section of results grouped by check level as HTML.
    #>
    param(
        [string]$LevelName,
        [PSCustomObject[]]$Results
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<div class="section">')
    [void]$sb.AppendLine("<h2>$(ConvertTo-HtmlEncoded $LevelName) Checks</h2>")
    [void]$sb.AppendLine('<table class="results-table">')
    [void]$sb.AppendLine('<tr><th>Check Name</th><th>Status</th><th>Severity</th><th>Current Value</th><th>Default Value</th><th>Message</th></tr>')

    foreach ($result in $Results) {
        [void]$sb.Append((Render-ResultRow -Result $result))
    }

    [void]$sb.AppendLine('</table>')
    [void]$sb.AppendLine('</div>')
    return $sb.ToString()
}

function Render-ResultRow {
    <#
    .SYNOPSIS
        Renders a single CheckResult as an HTML table row with color coding.
    #>
    param(
        [PSCustomObject]$Result
    )

    $colorClass = Get-SeverityColor -Severity $Result.Severity -Status $Result.Status
    $colorValue = Get-CssColorValue -ColorClass $colorClass

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("<tr class=""$colorClass"" style=""background-color: ${colorValue}20; border-left: 4px solid $colorValue;"">")
    [void]$sb.AppendLine("  <td>$(ConvertTo-HtmlEncoded $Result.CheckName)</td>")
    [void]$sb.AppendLine("  <td>$(ConvertTo-HtmlEncoded ($Result.Status.ToString()))</td>")
    [void]$sb.AppendLine("  <td>$(ConvertTo-HtmlEncoded ($Result.Severity.ToString()))</td>")
    [void]$sb.AppendLine("  <td>$(ConvertTo-HtmlEncoded $Result.CurrentValue)</td>")
    [void]$sb.AppendLine("  <td>$(ConvertTo-HtmlEncoded $Result.DefaultValue)</td>")
    [void]$sb.AppendLine("  <td>$(ConvertTo-HtmlEncoded $Result.Message)</td>")
    [void]$sb.AppendLine('</tr>')

    # Render detail rows if present
    if ($null -ne $Result.Details -and $Result.Details.Count -gt 0) {
        [void]$sb.AppendLine("<tr class=""${colorClass}-details"">")
        [void]$sb.AppendLine('  <td colspan="6">')
        [void]$sb.AppendLine('    <table class="details-table">')
        [void]$sb.AppendLine('      <tr><th>Object</th><th>Column</th><th>Finding</th><th>Value</th></tr>')
        foreach ($detail in $Result.Details) {
            [void]$sb.AppendLine('      <tr>')
            [void]$sb.AppendLine("        <td>$(ConvertTo-HtmlEncoded $detail.ObjectName)</td>")
            [void]$sb.AppendLine("        <td>$(ConvertTo-HtmlEncoded $detail.ColumnName)</td>")
            [void]$sb.AppendLine("        <td>$(ConvertTo-HtmlEncoded $detail.Finding)</td>")
            [void]$sb.AppendLine("        <td>$(ConvertTo-HtmlEncoded $detail.Value)</td>")
            [void]$sb.AppendLine('      </tr>')
        }
        [void]$sb.AppendLine('    </table>')
        [void]$sb.AppendLine('  </td>')
        [void]$sb.AppendLine('</tr>')
    }

    return $sb.ToString()
}
