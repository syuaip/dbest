using System.Data;
using System.Data.SqlClient;
using System.Text.Json;
using MySql.Data.MySqlClient;
using Npgsql;
using Oracle.ManagedDataAccess.Client;
using MongoDB.Bson;
using MongoDB.Driver;

namespace dbbpc;

/// <summary>
/// Script execution engine for dbbpc.
/// Executes diagnostic scripts against the database and collects results.
/// </summary>
public static class ScriptRunner
{
    /// <summary>
    /// Execute diagnostic scripts against the database and collect results.
    /// Iterates through the provided scripts in order, executing each script's
    /// SQL/JS content against the connection handle. On execution failure,
    /// captures the error into a CheckResult with status=ERROR.
    /// </summary>
    /// <param name="connection">A database connection handle (driver-specific).</param>
    /// <param name="scripts">List of ScriptFile objects, already sorted alphabetically.</param>
    /// <param name="dbengine">The database engine identifier.</param>
    /// <returns>A complete list of CheckResult objects from all executed scripts.</returns>
    public static List<CheckResult> RunScripts(object connection, List<ScriptFile> scripts, string dbengine)
    {
        var results = new List<CheckResult>();

        foreach (var script in scripts)
        {
            // Check for unreadable file (content is empty or null)
            if (string.IsNullOrWhiteSpace(script.Content))
            {
                continue;
            }

            Console.Error.WriteLine($"Info: Running script {script.Filename}: executing...");

            try
            {
                List<Dictionary<string, object?>> scriptResults;

                if (dbengine == "mongodb")
                {
                    scriptResults = ExecuteMongodbScript(connection, script);
                }
                else
                {
                    scriptResults = ExecuteSqlScript(connection, script, dbengine);
                }

                // Parse the raw results into a CheckResult
                var checkResult = ParseScriptResult(script, scriptResults);
                results.Add(checkResult);
            }
            catch (Exception exc)
            {
                // Capture execution failure as ERROR CheckResult
                var errorResult = new CheckResult
                {
                    ScriptName = script.Filename,
                    CheckName = DeriveCheckName(script.Filename),
                    CheckLevel = CheckLevel.Instance,
                    Status = CheckStatus.Error,
                    Severity = Severity.Advisory,
                    CurrentValue = "",
                    DefaultValue = "",
                    Message = $"Script execution failed: {exc.GetType().Name}: {exc.Message}",
                    Details = new List<DetailRow>()
                };
                results.Add(errorResult);
            }
        }

        return results;
    }

    /// <summary>
    /// Execute a SQL script against the connection and return result rows.
    /// </summary>
    private static List<Dictionary<string, object?>> ExecuteSqlScript(object connection, ScriptFile script, string dbengine)
    {
        IDbCommand cmd;

        switch (dbengine)
        {
            case "mssql":
                cmd = ((SqlConnection)connection).CreateCommand();
                break;
            case "mysql":
                cmd = ((MySqlConnection)connection).CreateCommand();
                break;
            case "oracle":
                cmd = ((OracleConnection)connection).CreateCommand();
                break;
            case "postgres":
                cmd = ((NpgsqlConnection)connection).CreateCommand();
                break;
            default:
                throw new InvalidOperationException($"Unsupported engine for SQL execution: {dbengine}");
        }

        try
        {
            // Oracle ODP.NET rejects trailing semicolons (ORA-00933).
            // Strip them for Oracle; other engines tolerate them.
            var sqlContent = script.Content;
            if (dbengine == "oracle")
            {
                sqlContent = sqlContent.TrimEnd();
                if (sqlContent.EndsWith(";"))
                    sqlContent = sqlContent[..^1];
            }

            cmd.CommandText = sqlContent;
            using var reader = cmd.ExecuteReader();

            var results = new List<Dictionary<string, object?>>();

            // Read all result rows
            while (reader.Read())
            {
                var row = new Dictionary<string, object?>();
                for (int i = 0; i < reader.FieldCount; i++)
                {
                    var columnName = reader.GetName(i);
                    var value = reader.IsDBNull(i) ? null : reader.GetValue(i);
                    row[columnName] = value;
                }
                results.Add(row);
            }

            return results;
        }
        finally
        {
            if (cmd is IDisposable disposable)
            {
                disposable.Dispose();
            }
        }
    }

    /// <summary>
    /// Execute a MongoDB JavaScript script using runCommand.
    /// </summary>
    private static List<Dictionary<string, object?>> ExecuteMongodbScript(object connection, ScriptFile script)
    {
        var client = (MongoClient)connection;
        var content = script.Content.Trim();

        try
        {
            // Attempt to parse as JSON command document
            var commandDoc = BsonDocument.Parse(content);
            var adminDb = client.GetDatabase("admin");
            var result = adminDb.RunCommand<BsonDocument>(commandDoc);

            return new List<Dictionary<string, object?>> { BsonDocumentToDict(result) };
        }
        catch (Exception)
        {
            // If not valid JSON/BSON, try eval command
            try
            {
                var adminDb = client.GetDatabase("admin");
                var evalCommand = new BsonDocument("eval", content);
                var result = adminDb.RunCommand<BsonDocument>(evalCommand);

                return new List<Dictionary<string, object?>> { BsonDocumentToDict(result) };
            }
            catch
            {
                throw;
            }
        }
    }

    /// <summary>
    /// Convert a BsonDocument to a Dictionary.
    /// </summary>
    private static Dictionary<string, object?> BsonDocumentToDict(BsonDocument doc)
    {
        var dict = new Dictionary<string, object?>();
        foreach (var element in doc)
        {
            dict[element.Name] = BsonValueToObject(element.Value);
        }
        return dict;
    }

    /// <summary>
    /// Convert a BsonValue to a .NET object.
    /// </summary>
    private static object? BsonValueToObject(BsonValue value)
    {
        if (value.IsBsonNull) return null;
        if (value.IsString) return value.AsString;
        if (value.IsInt32) return value.AsInt32;
        if (value.IsInt64) return value.AsInt64;
        if (value.IsDouble) return value.AsDouble;
        if (value.IsBoolean) return value.AsBoolean;
        return value.ToString();
    }

    /// <summary>
    /// Derive a human-readable check name from a script filename.
    /// Strips the file extension, removes leading numeric prefixes and underscores,
    /// and converts underscores to spaces with title case.
    /// </summary>
    public static string DeriveCheckName(string filename)
    {
        // Remove extension
        var name = Path.GetFileNameWithoutExtension(filename);

        // Remove leading numeric prefix (e.g., '01_')
        var underscoreIndex = name.IndexOf('_');
        if (underscoreIndex > 0)
        {
            var prefix = name[..underscoreIndex];
            if (prefix.All(char.IsDigit))
            {
                name = name[(underscoreIndex + 1)..];
            }
        }

        // Convert underscores to spaces and title case
        var words = name.Split('_');
        var titleCased = words.Select(w =>
            w.Length > 0 ? char.ToUpper(w[0]) + w[1..].ToLower() : w);

        return string.Join(" ", titleCased);
    }

    /// <summary>
    /// Parse raw script execution results into a CheckResult.
    /// Scripts are expected to return a result set with standardized column names.
    /// </summary>
    private static CheckResult ParseScriptResult(ScriptFile script, List<Dictionary<string, object?>> rawResults)
    {
        if (rawResults.Count == 0)
        {
            return new CheckResult
            {
                ScriptName = script.Filename,
                CheckName = DeriveCheckName(script.Filename),
                CheckLevel = CheckLevel.Instance,
                Status = CheckStatus.Passed,
                Severity = Severity.Ok,
                CurrentValue = "",
                DefaultValue = "",
                Message = "Check completed with no findings",
                Details = new List<DetailRow>()
            };
        }

        // Use the first row as the primary result
        var row = rawResults[0];

        // Extract standardized fields
        var checkName = GetStringValue(row, "check_name", DeriveCheckName(script.Filename));

        // Parse check_level
        var checkLevelStr = GetStringValue(row, "check_level", "INSTANCE").ToUpper();
        var checkLevel = checkLevelStr switch
        {
            "INSTANCE" => CheckLevel.Instance,
            "DATABASE" => CheckLevel.Database,
            "TABLE" => CheckLevel.Table,
            _ => CheckLevel.Instance
        };

        // Parse status
        var statusStr = GetStringValue(row, "status", "PASSED").ToUpper();
        var status = statusStr switch
        {
            "PASSED" => CheckStatus.Passed,
            "FLAGGED" => CheckStatus.Flagged,
            "ERROR" => CheckStatus.Error,
            "INSUFFICIENT_DATA" => CheckStatus.InsufficientData,
            _ => CheckStatus.Passed
        };

        // Parse severity
        var severityStr = GetStringValue(row, "severity", "OK").ToUpper();
        var severity = severityStr switch
        {
            "OK" => Severity.Ok,
            "ADVISORY" => Severity.Advisory,
            "CRITICAL" => Severity.Critical,
            _ => Severity.Ok
        };

        var currentValue = GetStringValue(row, "current_value", "");
        var defaultValue = GetStringValue(row, "default_value", "");
        var message = GetStringValue(row, "message", "");

        return new CheckResult
        {
            ScriptName = script.Filename,
            CheckName = checkName,
            CheckLevel = checkLevel,
            Status = status,
            Severity = severity,
            CurrentValue = currentValue,
            DefaultValue = defaultValue,
            Message = message,
            Details = new List<DetailRow>()
        };
    }

    /// <summary>
    /// Get a string value from a row dictionary, with a default fallback.
    /// </summary>
    private static string GetStringValue(Dictionary<string, object?> row, string key, string defaultValue)
    {
        if (row.TryGetValue(key, out var value) && value != null)
        {
            return value.ToString() ?? defaultValue;
        }
        return defaultValue;
    }
}
