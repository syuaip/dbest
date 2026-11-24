''' HTML report generation for dbbpc.

Imports System
Imports System.Collections.Generic
Imports System.IO
Imports System.Linq
Imports System.Text
Imports dbbpc.Models

Namespace Reporting

    ''' <summary>
    ''' Transforms check results into a structured, color-coded HTML report.
    ''' </summary>
    Public Module ReportGenerator

        ''' <summary>
        ''' Generate an HTML report from check results and metadata.
        ''' Writes output to dbbpc.html in the current working directory.
        ''' </summary>
        ''' <param name="results">List of CheckResult objects from script execution.</param>
        ''' <param name="metadata">ReportMetadata with summary information.</param>
        ''' <returns>The file path of the written HTML report.</returns>
        Public Function GenerateReport(results As List(Of CheckResult), metadata As ReportMetadata) As String
            ' Group results by check_level
            Dim instanceResults = results.Where(Function(r) r.CheckLevel = CheckLevel.INSTANCE).ToList()
            Dim databaseResults = results.Where(Function(r) r.CheckLevel = CheckLevel.DATABASE).ToList()
            Dim tableResults = results.Where(Function(r) r.CheckLevel = CheckLevel.TABLE).ToList()

            Dim html As New StringBuilder()

            html.AppendLine("<!DOCTYPE html>")
            html.AppendLine("<html lang=""en"">")
            html.AppendLine("<head>")
            html.AppendLine("<meta charset=""UTF-8"">")
            html.AppendLine("<meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">")
            html.AppendLine("<title>Database Evaluation &amp; Summary Report</title>")
            html.AppendLine("<style>")
            html.AppendLine("  body {")
            html.AppendLine("    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;")
            html.AppendLine("    margin: 0;")
            html.AppendLine("    padding: 20px;")
            html.AppendLine("    background-color: #f8f9fa;")
            html.AppendLine("    color: #212529;")
            html.AppendLine("  }")
            html.AppendLine("  .header {")
            html.AppendLine("    background-color: #343a40;")
            html.AppendLine("    color: #ffffff;")
            html.AppendLine("    padding: 20px 30px;")
            html.AppendLine("    border-radius: 8px;")
            html.AppendLine("    margin-bottom: 30px;")
            html.AppendLine("  }")
            html.AppendLine("  .header h1 {")
            html.AppendLine("    margin: 0 0 15px 0;")
            html.AppendLine("    font-size: 1.5em;")
            html.AppendLine("  }")
            html.AppendLine("  .summary {")
            html.AppendLine("    display: flex;")
            html.AppendLine("    flex-wrap: wrap;")
            html.AppendLine("    gap: 20px;")
            html.AppendLine("    align-items: center;")
            html.AppendLine("  }")
            html.AppendLine("  .summary-item {")
            html.AppendLine("    display: flex;")
            html.AppendLine("    flex-direction: column;")
            html.AppendLine("  }")
            html.AppendLine("  .summary-label {")
            html.AppendLine("    font-size: 0.8em;")
            html.AppendLine("    opacity: 0.8;")
            html.AppendLine("    text-transform: uppercase;")
            html.AppendLine("  }")
            html.AppendLine("  .summary-value {")
            html.AppendLine("    font-size: 1.2em;")
            html.AppendLine("    font-weight: bold;")
            html.AppendLine("  }")
            html.AppendLine("  .passed-count { color: #28a745; }")
            html.AppendLine("  .flagged-count { color: #dc3545; }")
            html.AppendLine("  .section {")
            html.AppendLine("    margin-bottom: 30px;")
            html.AppendLine("  }")
            html.AppendLine("  .section h2 {")
            html.AppendLine("    color: #343a40;")
            html.AppendLine("    border-bottom: 2px solid #dee2e6;")
            html.AppendLine("    padding-bottom: 8px;")
            html.AppendLine("    margin-bottom: 15px;")
            html.AppendLine("  }")
            html.AppendLine("  .results-table {")
            html.AppendLine("    width: 100%;")
            html.AppendLine("    border-collapse: collapse;")
            html.AppendLine("    background-color: #ffffff;")
            html.AppendLine("    border-radius: 8px;")
            html.AppendLine("    overflow: hidden;")
            html.AppendLine("    box-shadow: 0 1px 3px rgba(0,0,0,0.1);")
            html.AppendLine("  }")
            html.AppendLine("  .results-table th {")
            html.AppendLine("    background-color: #495057;")
            html.AppendLine("    color: #ffffff;")
            html.AppendLine("    padding: 12px 15px;")
            html.AppendLine("    text-align: left;")
            html.AppendLine("    font-size: 0.85em;")
            html.AppendLine("    text-transform: uppercase;")
            html.AppendLine("  }")
            html.AppendLine("  .results-table td {")
            html.AppendLine("    padding: 10px 15px;")
            html.AppendLine("    border-bottom: 1px solid #dee2e6;")
            html.AppendLine("    font-size: 0.9em;")
            html.AppendLine("  }")
            html.AppendLine("  .results-table tr.green { background-color: #28a74520; border-left: 4px solid #28a745; }")
            html.AppendLine("  .results-table tr.amber { background-color: #ffc10720; border-left: 4px solid #ffc107; }")
            html.AppendLine("  .results-table tr.red { background-color: #dc354520; border-left: 4px solid #dc3545; }")
            html.AppendLine("  .details-table {")
            html.AppendLine("    width: 100%;")
            html.AppendLine("    border-collapse: collapse;")
            html.AppendLine("    margin: 5px 0;")
            html.AppendLine("    font-size: 0.85em;")
            html.AppendLine("  }")
            html.AppendLine("  .details-table th {")
            html.AppendLine("    background-color: #e9ecef;")
            html.AppendLine("    padding: 6px 10px;")
            html.AppendLine("    text-align: left;")
            html.AppendLine("    color: #495057;")
            html.AppendLine("  }")
            html.AppendLine("  .details-table td {")
            html.AppendLine("    padding: 5px 10px;")
            html.AppendLine("    border-bottom: 1px solid #f1f3f5;")
            html.AppendLine("  }")
            html.AppendLine("</style>")
            html.AppendLine("</head>")
            html.AppendLine("<body>")

            ' Summary header
            html.AppendLine("<div class=""header"">")
            html.AppendLine("<h1>Database Evaluation &amp; Summary Report</h1>")
            html.AppendLine("<div class=""summary"">")
            html.AppendLine("<div class=""summary-item"">")
            html.AppendLine("  <span class=""summary-label"">Engine</span>")
            html.AppendLine($"  <span class=""summary-value"">{EscapeHtml(metadata.DbEngine)}</span>")
            html.AppendLine("</div>")
            html.AppendLine("<div class=""summary-item"">")
            html.AppendLine("  <span class=""summary-label"">Host</span>")
            html.AppendLine($"  <span class=""summary-value"">{EscapeHtml(metadata.DbHost)}</span>")
            html.AppendLine("</div>")
            html.AppendLine("<div class=""summary-item"">")
            html.AppendLine("  <span class=""summary-label"">Timestamp</span>")
            html.AppendLine($"  <span class=""summary-value"">{EscapeHtml(metadata.Timestamp)}</span>")
            html.AppendLine("</div>")
            html.AppendLine("<div class=""summary-item"">")
            html.AppendLine("  <span class=""summary-label"">Passed</span>")
            html.AppendLine($"  <span class=""summary-value passed-count"">{metadata.TotalPassed}</span>")
            html.AppendLine("</div>")
            html.AppendLine("<div class=""summary-item"">")
            html.AppendLine("  <span class=""summary-label"">Flagged</span>")
            html.AppendLine($"  <span class=""summary-value flagged-count"">{metadata.TotalFlagged}</span>")
            html.AppendLine("</div>")
            html.AppendLine("</div>")
            html.AppendLine("</div>")

            ' Render sections in order: Instance -> Database -> Table
            html.Append(RenderSection("Instance", instanceResults))
            html.Append(RenderSection("Database", databaseResults))
            html.Append(RenderSection("Table", tableResults))

            html.AppendLine("</body>")
            html.AppendLine("</html>")

            ' Write to dbbpc.html in current working directory
            Dim outputPath As String = "dbest"

            ' OutputPath diubah jadi path yang lebih spesifik untuk menghindari konflik dengan file lain.
            ' Gunakan nama file yang unik berdasarkan db engine + hostname + timestamp.
            outputPath = outputPath + "_" + metadata.DbEngine.Replace(" ", "_") + "_" + metadata.DbHost.Replace(" ", "_") + "_" + metadata.Timestamp.Replace(" ", "_").Replace(":", "-")
            outputPath = outputPath + ".html"

            File.WriteAllText(outputPath, html.ToString(), Encoding.UTF8)

            Return outputPath
        End Function

        ''' <summary>
        ''' Return CSS color class based on severity and status.
        ''' </summary>
        Public Function SeverityColor(severity As Severity, status As CheckStatus) As String
            If status = CheckStatus.ERROR Then
                Return "red"
            End If
            If severity = Severity.OK OrElse status = CheckStatus.PASSED Then
                Return "green"
            End If
            If severity = Severity.ADVISORY Then
                Return "amber"
            End If
            If severity = Severity.CRITICAL Then
                Return "red"
            End If
            ' Default for INSUFFICIENT_DATA or other cases
            Return "amber"
        End Function

        ''' <summary>
        ''' Return the actual CSS color value for a color class name.
        ''' </summary>
        Private Function CssColorValue(colorClass As String) As String
            Select Case colorClass
                Case "green"
                    Return "#28a745"
                Case "amber"
                    Return "#ffc107"
                Case "red"
                    Return "#dc3545"
                Case Else
                    Return "#6c757d"
            End Select
        End Function

        ''' <summary>
        ''' Escape HTML special characters.
        ''' </summary>
        Public Function EscapeHtml(text As String) As String
            If text Is Nothing Then Return ""
            Return text.Replace("&", "&amp;").
                        Replace("<", "&lt;").
                        Replace(">", "&gt;").
                        Replace("""", "&quot;").
                        Replace("'", "&#x27;")
        End Function

        ''' <summary>
        ''' Render a single CheckResult as an HTML table row.
        ''' </summary>
        Private Function RenderResultRow(result As CheckResult) As String
            Dim colorClass As String = SeverityColor(result.Severity, result.Status)
            Dim colorValue As String = CssColorValue(colorClass)

            Dim row As New StringBuilder()
            row.AppendLine($"<tr class=""{colorClass}"" style=""background-color: {colorValue}20; border-left: 4px solid {colorValue};"">")
            row.AppendLine($"  <td>{EscapeHtml(result.CheckName)}</td>")
            row.AppendLine($"  <td>{EscapeHtml(result.Status.ToString())}</td>")
            row.AppendLine($"  <td>{EscapeHtml(result.Severity.ToString())}</td>")
            row.AppendLine($"  <td>{EscapeHtml(result.CurrentValue)}</td>")
            row.AppendLine($"  <td>{EscapeHtml(result.DefaultValue)}</td>")
            row.AppendLine($"  <td>{EscapeHtml(result.Message)}</td>")
            row.AppendLine("</tr>")

            ' Render detail rows if present
            If result.Details IsNot Nothing AndAlso result.Details.Count > 0 Then
                row.AppendLine($"<tr class=""{colorClass}-details"">")
                row.AppendLine("  <td colspan=""6"">")
                row.AppendLine("    <table class=""details-table"">")
                row.AppendLine("      <tr><th>Object</th><th>Column</th><th>Finding</th><th>Value</th></tr>")
                For Each detail In result.Details
                    row.AppendLine("      <tr>")
                    row.AppendLine($"        <td>{EscapeHtml(detail.ObjectName)}</td>")
                    row.AppendLine($"        <td>{EscapeHtml(detail.ColumnName)}</td>")
                    row.AppendLine($"        <td>{EscapeHtml(detail.Finding)}</td>")
                    row.AppendLine($"        <td>{EscapeHtml(detail.Value)}</td>")
                    row.AppendLine("      </tr>")
                Next
                row.AppendLine("    </table>")
                row.AppendLine("  </td>")
                row.AppendLine("</tr>")
            End If

            Return row.ToString()
        End Function

        ''' <summary>
        ''' Render a section of results grouped by check level.
        ''' </summary>
        Private Function RenderSection(levelName As String, results As List(Of CheckResult)) As String
            If results Is Nothing OrElse results.Count = 0 Then
                Return ""
            End If

            Dim html As New StringBuilder()
            html.AppendLine("<div class=""section"">")
            html.AppendLine($"<h2>{EscapeHtml(levelName)} Checks</h2>")
            html.AppendLine("<table class=""results-table"">")
            html.AppendLine("<tr><th>Check Name</th><th>Status</th><th>Severity</th><th>Current Value</th><th>Default Value</th><th>Message</th></tr>")
            For Each result In results
                html.Append(RenderResultRow(result))
            Next
            html.AppendLine("</table>")
            html.AppendLine("</div>")
            Return html.ToString()
        End Function

    End Module

End Namespace
