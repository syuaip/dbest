using System.Data;
using System.Data.SqlClient;
using MySql.Data.MySqlClient;
using Npgsql;
using Oracle.ManagedDataAccess.Client;
using MongoDB.Driver;

namespace dbbpc;

/// <summary>
/// Database connection management for dbbpc.
/// Establishes connections using engine-specific drivers with 30s timeout and health check.
/// </summary>
public static class DbConnector
{
    /// <summary>Connection timeout in seconds.</summary>
    public const int ConnectionTimeout = 30;

    /// <summary>
    /// Establish a database connection using engine-specific drivers.
    /// Applies a 30-second connection timeout, executes a health-check query on success,
    /// and returns the connection handle.
    /// On failure, prints a descriptive error message to stderr and exits with code 1.
    /// </summary>
    /// <param name="params">ConnectionParams with dbengine, dbhost, port, username, password.</param>
    /// <returns>A connection handle (object) on success.</returns>
    public static object Connect(ConnectionParams @params)
    {
        try
        {
            return @params.DbEngine switch
            {
                "mssql" => ConnectMssql(@params),
                "mysql" => ConnectMysql(@params),
                "oracle" => ConnectOracle(@params),
                "postgres" => ConnectPostgres(@params),
                "mongodb" => ConnectMongodb(@params),
                _ => throw new InvalidOperationException($"Unsupported database engine '{@params.DbEngine}'.")
            };
        }
        catch (Exception exc) when (exc is not SystemException { } se || se is not OutOfMemoryException)
        {
            HandleConnectionError(exc, @params);
            return null!; // unreachable
        }
    }

    private static object ConnectMssql(ConnectionParams @params)
    {
        var connectionString =
            $"Server={@params.DbHost},{@params.Port};" +
            $"User Id={@params.Username};" +
            $"Password={@params.Password};" +
            $"Connection Timeout={ConnectionTimeout};";

        var conn = new SqlConnection(connectionString);
        conn.Open();

        // Health-check query
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT 1";
        cmd.ExecuteScalar();

        return conn;
    }

    private static object ConnectMysql(ConnectionParams @params)
    {
        var connectionString =
            $"Server={@params.DbHost};" +
            $"Port={@params.Port};" +
            $"User Id={@params.Username};" +
            $"Password={@params.Password};" +
            $"Connection Timeout={ConnectionTimeout};";

        var conn = new MySqlConnection(connectionString);
        conn.Open();

        // Health-check query
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT 1";
        cmd.ExecuteScalar();

        return conn;
    }

    private static object ConnectOracle(ConnectionParams @params)
    {
        var connectionString =
            $"Data Source=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST={@params.DbHost})(PORT={@params.Port}))(CONNECT_DATA=(SERVICE_NAME=ORCL)));" +
            $"User Id={@params.Username};" +
            $"Password={@params.Password};" +
            $"Connection Timeout={ConnectionTimeout};";

        var conn = new OracleConnection(connectionString);
        conn.Open();

        // Health-check query
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT 1 FROM DUAL";
        cmd.ExecuteScalar();

        return conn;
    }

    private static object ConnectPostgres(ConnectionParams @params)
    {
        var connectionString =
            $"Host={@params.DbHost};" +
            $"Port={@params.Port};" +
            $"Username={@params.Username};" +
            $"Password={@params.Password};" +
            $"Timeout={ConnectionTimeout};";

        var conn = new NpgsqlConnection(connectionString);
        conn.Open();

        // Health-check query
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT 1";
        cmd.ExecuteScalar();

        return conn;
    }

    private static object ConnectMongodb(ConnectionParams @params)
    {
        var uri = $"mongodb://{@params.Username}:{@params.Password}@{@params.DbHost}:{@params.Port}/";

        var settings = MongoClientSettings.FromConnectionString(uri);
        settings.ServerSelectionTimeout = TimeSpan.FromSeconds(ConnectionTimeout);
        settings.ConnectTimeout = TimeSpan.FromSeconds(ConnectionTimeout);

        var client = new MongoClient(settings);

        // Health-check: ping the admin database
        var adminDb = client.GetDatabase("admin");
        adminDb.RunCommand<MongoDB.Bson.BsonDocument>(
            new MongoDB.Bson.BsonDocument("ping", 1));

        return client;
    }

    /// <summary>
    /// Classify a connection exception into a category: timeout, authentication, or network.
    /// </summary>
    private static string ClassifyError(Exception exc)
    {
        var excType = exc.GetType().Name.ToLower();
        var excMsg = exc.Message.ToLower();

        // Timeout detection
        string[] timeoutIndicators = { "timeout", "timed out", "connection timed out" };
        foreach (var indicator in timeoutIndicators)
        {
            if (excMsg.Contains(indicator) || excType.Contains(indicator))
                return "timeout";
        }

        // Authentication failure detection
        string[] authIndicators = {
            "authentication", "auth", "login failed", "access denied",
            "invalid credentials", "password", "logon", "ora-01017"
        };
        foreach (var indicator in authIndicators)
        {
            if (excMsg.Contains(indicator) || excType.Contains(indicator))
                return "authentication";
        }

        // Network error detection (default fallback)
        return "network";
    }

    /// <summary>
    /// Print a descriptive error message and exit with code 1.
    /// </summary>
    private static void HandleConnectionError(Exception exc, ConnectionParams @params)
    {
        var errorClass = ClassifyError(exc);

        string msg = errorClass switch
        {
            "timeout" => $"Connection timed out connecting to {@params.DbHost}:{@params.Port}",
            "authentication" => $"Authentication failed for user '{@params.Username}' on {@params.DbHost}",
            _ => $"Cannot reach {@params.DbHost}:{@params.Port} — verify host and network"
        };

        Console.Error.WriteLine($"Error: {msg}");
        Environment.Exit(1);
    }
}
