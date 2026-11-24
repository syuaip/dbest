namespace dbbpc;

/// <summary>
/// Entry point for the Database Best Practices Checker (dbbpc) CLI tool.
/// Targets Linux (linux-x64) and implements the same pipeline as the Python reference:
/// CLI Parser → DB Connector → Script Discovery → Script Runner → Report Generator.
/// </summary>
public class Program
{
    public static int Main(string[] args)
    {
        try
        {
            // Step 1: Parse CLI arguments
            var connectionParams = CliParser.ParseArgs(args);

            // Step 2: Establish database connection
            var connection = DbConnector.Connect(connectionParams);

            // Step 3: Discover diagnostic scripts for the engine
            var scripts = ScriptDiscovery.DiscoverScripts(connectionParams.DbEngine);

            // Step 4: Run scripts against the database
            var results = ScriptRunner.RunScripts(connection, scripts, connectionParams.DbEngine);

            // Step 5: Build report metadata
            var totalPassed = results.Count(r => r.Status == CheckStatus.Passed);
            var totalFlagged = results.Count(r =>
                r.Status == CheckStatus.Flagged || r.Status == CheckStatus.Error);

            var metadata = new ReportMetadata
            {
                DbEngine = connectionParams.DbEngine,
                DbHost = connectionParams.DbHost,
                Timestamp = DateTime.UtcNow.ToString("o"),
                TotalPassed = totalPassed,
                TotalFlagged = totalFlagged
            };

            // Step 6: Generate the HTML report
            var reportPath = ReportGenerator.GenerateReport(results, metadata);

            // Step 7: Print success message
            Console.WriteLine($"Report generated successfully: {reportPath}");

            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error: {ex.Message}");
            return 1;
        }
    }
}
