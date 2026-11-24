using System.Text;

namespace dbbpc;

/// <summary>
/// HTML report generation for dbbpc.
/// Generates HTML report with same structure and color coding as Python reference.
/// </summary>
public static class ReportGenerator
{
    /// <summary>
    /// Return CSS color class based on severity and status.
    /// </summary>
    public static string SeverityColor(Severity severity, CheckStatus status)
    {
        if (status == CheckStatus.Error)
            return "red";
        if (severity == Severity.Ok || status == CheckStatus.Passed)
            return "green";
        if (severity == Severity.Advisory)
            return "amber";
        if (severity == Severity.Critical)
            return "red";
        // Default for InsufficientData or other cases
        return "amber";
    }

    /// <summary>
    /// Return the actual CSS color value for a color class name.
    /// </summary>
    private static string CssColorValue(string colorClass)
    {
        return colorClass switch
        {
            "green" => "#28a745",
            "amber" => "#ffc107",
            "red" => "#dc3545",
            _ => "#6c757d"
        };
    }

    /// <summary>
    /// Escape HTML special characters.
    /// </summary>
    private static string EscapeHtml(string text)
    {
        return text
            .Replace("&", "&amp;")
            .Replace("<", "&lt;")
            .Replace(">", "&gt;")
            .Replace("\"", "&quot;")
            .Replace("'", "&#x27;");
    }

    /// <summary>
    /// Render a single CheckResult as an HTML table row.
    /// </summary>
    private static string RenderResultRow(CheckResult result)
    {
        var colorClass = SeverityColor(result.Severity, result.Status);
        var colorValue = CssColorValue(colorClass);

        var sb = new StringBuilder();
        sb.AppendLine($"<tr class=\"{colorClass}\" style=\"background-color: {colorValue}20; border-left: 4px solid {colorValue};\">");
        sb.AppendLine($"  <td>{EscapeHtml(result.CheckName)}</td>");
        sb.AppendLine($"  <td>{EscapeHtml(StatusToString(result.Status))}</td>");
        sb.AppendLine($"  <td>{EscapeHtml(SeverityToString(result.Severity))}</td>");
        sb.AppendLine($"  <td>{EscapeHtml(result.CurrentValue)}</td>");
        sb.AppendLine($"  <td>{EscapeHtml(result.DefaultValue)}</td>");
        sb.AppendLine($"  <td>{EscapeHtml(result.Message)}</td>");
        sb.AppendLine("</tr>");

        // Render detail rows if present
        if (result.Details.Count > 0)
        {
            sb.AppendLine($"<tr class=\"{colorClass}-details\">");
            sb.AppendLine("  <td colspan=\"6\">");
            sb.AppendLine("    <table class=\"details-table\">");
            sb.AppendLine("      <tr><th>Object</th><th>Column</th><th>Finding</th><th>Value</th></tr>");
            foreach (var detail in result.Details)
            {
                sb.AppendLine("      <tr>");
                sb.AppendLine($"        <td>{EscapeHtml(detail.ObjectName)}</td>");
                sb.AppendLine($"        <td>{EscapeHtml(detail.ColumnName)}</td>");
                sb.AppendLine($"        <td>{EscapeHtml(detail.Finding)}</td>");
                sb.AppendLine($"        <td>{EscapeHtml(detail.Value)}</td>");
                sb.AppendLine("      </tr>");
            }
            sb.AppendLine("    </table>");
            sb.AppendLine("  </td>");
            sb.AppendLine("</tr>");
        }

        return sb.ToString();
    }

    /// <summary>
    /// Render a section of results grouped by check level.
    /// </summary>
    private static string RenderSection(string levelName, List<CheckResult> results)
    {
        if (results.Count == 0)
            return "";

        var sb = new StringBuilder();
        sb.AppendLine("<div class=\"section\">");
        sb.AppendLine($"<h2>{EscapeHtml(levelName)} Checks</h2>");
        sb.AppendLine("<table class=\"results-table\">");
        sb.AppendLine("<tr><th>Check Name</th><th>Status</th><th>Severity</th><th>Current Value</th><th>Default Value</th><th>Message</th></tr>");
        foreach (var result in results)
        {
            sb.Append(RenderResultRow(result));
        }
        sb.AppendLine("</table>");
        sb.AppendLine("</div>");
        return sb.ToString();
    }

    /// <summary>
    /// Generate an HTML report from check results and metadata.
    /// Writes the report to dbbpc.html in the current working directory.
    /// </summary>
    /// <param name="results">List of CheckResult objects from script execution.</param>
    /// <param name="metadata">ReportMetadata with summary information.</param>
    /// <returns>The file path of the written HTML report.</returns>
    public static string GenerateReport(List<CheckResult> results, ReportMetadata metadata)
    {
        // Group results by check_level
        var instanceResults = results.Where(r => r.CheckLevel == CheckLevel.Instance).ToList();
        var databaseResults = results.Where(r => r.CheckLevel == CheckLevel.Database).ToList();
        var tableResults = results.Where(r => r.CheckLevel == CheckLevel.Table).ToList();

        var sb = new StringBuilder();

        sb.AppendLine("<!DOCTYPE html>");
        sb.AppendLine("<html lang=\"en\">");
        sb.AppendLine("<head>");
        sb.AppendLine("<meta charset=\"UTF-8\">");
        sb.AppendLine("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">");
        sb.AppendLine("<title>Database Evaluation &amp; Summary Report</title>");
        sb.AppendLine("<style>");
        sb.AppendLine("  body {");
        sb.AppendLine("    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;");
        sb.AppendLine("    margin: 0;");
        sb.AppendLine("    padding: 20px;");
        sb.AppendLine("    background-color: #f8f9fa;");
        sb.AppendLine("    color: #212529;");
        sb.AppendLine("  }");
        sb.AppendLine("  .header {");
        sb.AppendLine("    background-color: #343a40;");
        sb.AppendLine("    color: #ffffff;");
        sb.AppendLine("    padding: 20px 30px;");
        sb.AppendLine("    border-radius: 8px;");
        sb.AppendLine("    margin-bottom: 30px;");
        sb.AppendLine("  }");
        sb.AppendLine("  .header h1 {");
        sb.AppendLine("    margin: 0 0 15px 0;");
        sb.AppendLine("    font-size: 1.5em;");
        sb.AppendLine("  }");
        sb.AppendLine("  .summary {");
        sb.AppendLine("    display: flex;");
        sb.AppendLine("    flex-wrap: wrap;");
        sb.AppendLine("    gap: 20px;");
        sb.AppendLine("    align-items: center;");
        sb.AppendLine("  }");
        sb.AppendLine("  .summary-item {");
        sb.AppendLine("    display: flex;");
        sb.AppendLine("    flex-direction: column;");
        sb.AppendLine("  }");
        sb.AppendLine("  .summary-label {");
        sb.AppendLine("    font-size: 0.8em;");
        sb.AppendLine("    opacity: 0.8;");
        sb.AppendLine("    text-transform: uppercase;");
        sb.AppendLine("  }");
        sb.AppendLine("  .summary-value {");
        sb.AppendLine("    font-size: 1.2em;");
        sb.AppendLine("    font-weight: bold;");
        sb.AppendLine("  }");
        sb.AppendLine("  .passed-count { color: #28a745; }");
        sb.AppendLine("  .flagged-count { color: #dc3545; }");
        sb.AppendLine("  .section {");
        sb.AppendLine("    margin-bottom: 30px;");
        sb.AppendLine("  }");
        sb.AppendLine("  .section h2 {");
        sb.AppendLine("    color: #343a40;");
        sb.AppendLine("    border-bottom: 2px solid #dee2e6;");
        sb.AppendLine("    padding-bottom: 8px;");
        sb.AppendLine("    margin-bottom: 15px;");
        sb.AppendLine("  }");
        sb.AppendLine("  .results-table {");
        sb.AppendLine("    width: 100%;");
        sb.AppendLine("    border-collapse: collapse;");
        sb.AppendLine("    background-color: #ffffff;");
        sb.AppendLine("    border-radius: 8px;");
        sb.AppendLine("    overflow: hidden;");
        sb.AppendLine("    box-shadow: 0 1px 3px rgba(0,0,0,0.1);");
        sb.AppendLine("  }");
        sb.AppendLine("  .results-table th {");
        sb.AppendLine("    background-color: #495057;");
        sb.AppendLine("    color: #ffffff;");
        sb.AppendLine("    padding: 12px 15px;");
        sb.AppendLine("    text-align: left;");
        sb.AppendLine("    font-size: 0.85em;");
        sb.AppendLine("    text-transform: uppercase;");
        sb.AppendLine("  }");
        sb.AppendLine("  .results-table td {");
        sb.AppendLine("    padding: 10px 15px;");
        sb.AppendLine("    border-bottom: 1px solid #dee2e6;");
        sb.AppendLine("    font-size: 0.9em;");
        sb.AppendLine("  }");
        sb.AppendLine("  .results-table tr.green { background-color: #28a74520; border-left: 4px solid #28a745; }");
        sb.AppendLine("  .results-table tr.amber { background-color: #ffc10720; border-left: 4px solid #ffc107; }");
        sb.AppendLine("  .results-table tr.red { background-color: #dc354520; border-left: 4px solid #dc3545; }");
        sb.AppendLine("  .details-table {");
        sb.AppendLine("    width: 100%;");
        sb.AppendLine("    border-collapse: collapse;");
        sb.AppendLine("    margin: 5px 0;");
        sb.AppendLine("    font-size: 0.85em;");
        sb.AppendLine("  }");
        sb.AppendLine("  .details-table th {");
        sb.AppendLine("    background-color: #e9ecef;");
        sb.AppendLine("    padding: 6px 10px;");
        sb.AppendLine("    text-align: left;");
        sb.AppendLine("    color: #495057;");
        sb.AppendLine("  }");
        sb.AppendLine("  .details-table td {");
        sb.AppendLine("    padding: 5px 10px;");
        sb.AppendLine("    border-bottom: 1px solid #f1f3f5;");
        sb.AppendLine("  }");
        sb.AppendLine("</style>");
        sb.AppendLine("</head>");
        sb.AppendLine("<body>");

        // Summary header
        sb.AppendLine("<div class=\"header\">");
        sb.AppendLine("<h1>Database Evaluation &amp; Summary Report</h1>");
        sb.AppendLine("<div class=\"summary\">");
        sb.AppendLine("<div class=\"summary-item\">");
        sb.AppendLine("  <span class=\"summary-label\">Engine</span>");
        sb.AppendLine($"  <span class=\"summary-value\">{EscapeHtml(metadata.DbEngine)}</span>");
        sb.AppendLine("</div>");
        sb.AppendLine("<div class=\"summary-item\">");
        sb.AppendLine("  <span class=\"summary-label\">Host</span>");
        sb.AppendLine($"  <span class=\"summary-value\">{EscapeHtml(metadata.DbHost)}</span>");
        sb.AppendLine("</div>");
        sb.AppendLine("<div class=\"summary-item\">");
        sb.AppendLine("  <span class=\"summary-label\">Timestamp</span>");
        sb.AppendLine($"  <span class=\"summary-value\">{EscapeHtml(metadata.Timestamp)}</span>");
        sb.AppendLine("</div>");
        sb.AppendLine("<div class=\"summary-item\">");
        sb.AppendLine("  <span class=\"summary-label\">Passed</span>");
        sb.AppendLine($"  <span class=\"summary-value passed-count\">{metadata.TotalPassed}</span>");
        sb.AppendLine("</div>");
        sb.AppendLine("<div class=\"summary-item\">");
        sb.AppendLine("  <span class=\"summary-label\">Flagged</span>");
        sb.AppendLine($"  <span class=\"summary-value flagged-count\">{metadata.TotalFlagged}</span>");
        sb.AppendLine("</div>");
        sb.AppendLine("</div>");
        sb.AppendLine("</div>");

        // Render sections in order: Instance → Database → Table
        sb.Append(RenderSection("Instance", instanceResults));
        sb.Append(RenderSection("Database", databaseResults));
        sb.Append(RenderSection("Table", tableResults));

        sb.AppendLine("</body>");
        sb.AppendLine("</html>");

        // Write report with unique filename based on engine + host + timestamp
        var outputPath = "dbest"
            + "_" + metadata.DbEngine.Replace(" ", "_")
            + "_" + metadata.DbHost.Replace(" ", "_")
            + "_" + metadata.Timestamp.Replace(" ", "_").Replace(":", "-")
            + ".html";
        File.WriteAllText(outputPath, sb.ToString(), Encoding.UTF8);

        return outputPath;
    }

    /// <summary>
    /// Convert CheckStatus enum to its string representation matching Python output.
    /// </summary>
    private static string StatusToString(CheckStatus status)
    {
        return status switch
        {
            CheckStatus.Passed => "PASSED",
            CheckStatus.Flagged => "FLAGGED",
            CheckStatus.Error => "ERROR",
            CheckStatus.InsufficientData => "INSUFFICIENT_DATA",
            _ => "PASSED"
        };
    }

    /// <summary>
    /// Convert Severity enum to its string representation matching Python output.
    /// </summary>
    private static string SeverityToString(Severity severity)
    {
        return severity switch
        {
            Severity.Ok => "OK",
            Severity.Advisory => "ADVISORY",
            Severity.Critical => "CRITICAL",
            _ => "OK"
        };
    }
}
