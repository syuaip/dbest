"""HTML report generation for dbbpc."""

from typing import List

from dbest.models import CheckLevel, CheckResult, CheckStatus, ReportMetadata, Severity


def _severity_color(severity: Severity, status: CheckStatus) -> str:
    """Return CSS color class based on severity and status."""
    if status == CheckStatus.ERROR:
        return "red"
    if severity == Severity.OK or status == CheckStatus.PASSED:
        return "green"
    if severity == Severity.ADVISORY:
        return "amber"
    if severity == Severity.CRITICAL:
        return "red"
    # Default for INSUFFICIENT_DATA or other cases
    return "amber"


def _css_color_value(color_class: str) -> str:
    """Return the actual CSS color value for a color class name."""
    if color_class == "green":
        return "#28a745"
    if color_class == "amber":
        return "#ffc107"
    if color_class == "red":
        return "#dc3545"
    return "#6c757d"


def _escape_html(text: str) -> str:
    """Escape HTML special characters."""
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#x27;")
    )


def _render_result_row(result: CheckResult) -> str:
    """Render a single CheckResult as an HTML table row."""
    color_class = _severity_color(result.severity, result.status)
    color_value = _css_color_value(color_class)

    row = f'<tr class="{color_class}" style="background-color: {color_value}20; border-left: 4px solid {color_value};">\n'
    row += f"  <td>{_escape_html(result.check_name)}</td>\n"
    row += f"  <td>{_escape_html(result.status.value)}</td>\n"
    row += f"  <td>{_escape_html(result.severity.value)}</td>\n"
    row += f"  <td>{_escape_html(result.current_value)}</td>\n"
    row += f"  <td>{_escape_html(result.default_value)}</td>\n"
    row += f"  <td>{_escape_html(result.message)}</td>\n"
    row += "</tr>\n"

    # Render detail rows if present
    if result.details:
        row += f'<tr class="{color_class}-details">\n'
        row += '  <td colspan="6">\n'
        row += '    <table class="details-table">\n'
        row += "      <tr><th>Object</th><th>Column</th><th>Finding</th><th>Value</th></tr>\n"
        for detail in result.details:
            row += "      <tr>\n"
            row += f"        <td>{_escape_html(detail.object_name)}</td>\n"
            row += f"        <td>{_escape_html(detail.column_name)}</td>\n"
            row += f"        <td>{_escape_html(detail.finding)}</td>\n"
            row += f"        <td>{_escape_html(detail.value)}</td>\n"
            row += "      </tr>\n"
        row += "    </table>\n"
        row += "  </td>\n"
        row += "</tr>\n"

    return row


def _render_section(level_name: str, results: List[CheckResult]) -> str:
    """Render a section of results grouped by check level."""
    if not results:
        return ""

    html = f'<div class="section">\n'
    html += f"<h2>{_escape_html(level_name)} Checks</h2>\n"
    html += '<table class="results-table">\n'
    html += "<tr><th>Check Name</th><th>Status</th><th>Severity</th><th>Current Value</th><th>Default Value</th><th>Message</th></tr>\n"
    for result in results:
        html += _render_result_row(result)
    html += "</table>\n"
    html += "</div>\n"
    return html


def generate_report(results: List[CheckResult], metadata: ReportMetadata) -> str:
    """Generate an HTML report from check results and metadata.

    Args:
        results: List of CheckResult objects from script execution.
        metadata: ReportMetadata with summary information.

    Returns:
        The file path of the written HTML report (dbbpc.html in cwd).
    """
    # Group results by check_level
    instance_results = [r for r in results if r.check_level == CheckLevel.INSTANCE]
    database_results = [r for r in results if r.check_level == CheckLevel.DATABASE]
    table_results = [r for r in results if r.check_level == CheckLevel.TABLE]

    html = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Database Evaluation &amp; Summary Report</title>
<style>
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    margin: 0;
    padding: 20px;
    background-color: #f8f9fa;
    color: #212529;
  }
  .header {
    background-color: #343a40;
    color: #ffffff;
    padding: 20px 30px;
    border-radius: 8px;
    margin-bottom: 30px;
  }
  .header h1 {
    margin: 0 0 15px 0;
    font-size: 1.5em;
  }
  .summary {
    display: flex;
    flex-wrap: wrap;
    gap: 20px;
    align-items: center;
  }
  .summary-item {
    display: flex;
    flex-direction: column;
  }
  .summary-label {
    font-size: 0.8em;
    opacity: 0.8;
    text-transform: uppercase;
  }
  .summary-value {
    font-size: 1.2em;
    font-weight: bold;
  }
  .passed-count { color: #28a745; }
  .flagged-count { color: #dc3545; }
  .section {
    margin-bottom: 30px;
  }
  .section h2 {
    color: #343a40;
    border-bottom: 2px solid #dee2e6;
    padding-bottom: 8px;
    margin-bottom: 15px;
  }
  .results-table {
    width: 100%;
    border-collapse: collapse;
    background-color: #ffffff;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }
  .results-table th {
    background-color: #495057;
    color: #ffffff;
    padding: 12px 15px;
    text-align: left;
    font-size: 0.85em;
    text-transform: uppercase;
  }
  .results-table td {
    padding: 10px 15px;
    border-bottom: 1px solid #dee2e6;
    font-size: 0.9em;
  }
  .results-table tr.green { background-color: #28a74520; border-left: 4px solid #28a745; }
  .results-table tr.amber { background-color: #ffc10720; border-left: 4px solid #ffc107; }
  .results-table tr.red { background-color: #dc354520; border-left: 4px solid #dc3545; }
  .details-table {
    width: 100%;
    border-collapse: collapse;
    margin: 5px 0;
    font-size: 0.85em;
  }
  .details-table th {
    background-color: #e9ecef;
    padding: 6px 10px;
    text-align: left;
    color: #495057;
  }
  .details-table td {
    padding: 5px 10px;
    border-bottom: 1px solid #f1f3f5;
  }
</style>
</head>
<body>
"""

    # Summary header
    html += '<div class="header">\n'
    html += "<h1>Database Evaluation &amp; Summary Report</h1>\n"
    html += '<div class="summary">\n'
    html += '<div class="summary-item">\n'
    html += '  <span class="summary-label">Engine</span>\n'
    html += f'  <span class="summary-value">{_escape_html(metadata.dbengine)}</span>\n'
    html += "</div>\n"
    html += '<div class="summary-item">\n'
    html += '  <span class="summary-label">Host</span>\n'
    html += f'  <span class="summary-value">{_escape_html(metadata.dbhost)}</span>\n'
    html += "</div>\n"
    html += '<div class="summary-item">\n'
    html += '  <span class="summary-label">Timestamp</span>\n'
    html += f'  <span class="summary-value">{_escape_html(metadata.timestamp)}</span>\n'
    html += "</div>\n"
    html += '<div class="summary-item">\n'
    html += '  <span class="summary-label">Passed</span>\n'
    html += f'  <span class="summary-value passed-count">{metadata.total_passed}</span>\n'
    html += "</div>\n"
    html += '<div class="summary-item">\n'
    html += '  <span class="summary-label">Flagged</span>\n'
    html += f'  <span class="summary-value flagged-count">{metadata.total_flagged}</span>\n'
    html += "</div>\n"
    html += "</div>\n"
    html += "</div>\n"

    # Render sections in order: Instance → Database → Table
    html += _render_section("Instance", instance_results)
    html += _render_section("Database", database_results)
    html += _render_section("Table", table_results)

    html += "</body>\n</html>\n"

    # Write report with unique filename based on engine + host + timestamp
    output_path = (
        "dbest"
        + "_" + metadata.dbengine.replace(" ", "_")
        + "_" + metadata.dbhost.replace(" ", "_")
        + "_" + metadata.timestamp.replace(" ", "_").replace(":", "-")
        + ".html"
    )
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)

    return output_path
