namespace dbbpc;

/// <summary>
/// CLI argument parsing and validation for dbbpc.
/// Parses --dbengine, --dbhost, --port, --username, --password with same validation as Python reference.
/// </summary>
public static class CliParser
{
    /// <summary>Valid database engine values (case-sensitive).</summary>
    public static readonly string[] ValidEngines = { "mssql", "mysql", "oracle", "postgres", "mongodb" };

    /// <summary>
    /// Parse and validate CLI arguments, returning a ConnectionParams object.
    /// On missing or invalid parameters, writes error to stderr and exits with code 1.
    /// </summary>
    /// <param name="args">Raw command-line arguments.</param>
    /// <returns>Populated ConnectionParams on success.</returns>
    public static ConnectionParams ParseArgs(string[] args)
    {
        var parsed = new Dictionary<string, string?>();
        string? dbengine = null;
        string? dbhost = null;
        string? port = null;
        string? username = null;
        string? password = null;

        // Parse named parameters
        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--dbengine":
                    if (i + 1 < args.Length)
                        dbengine = args[++i];
                    break;
                case "--dbhost":
                    if (i + 1 < args.Length)
                        dbhost = args[++i];
                    break;
                case "--port":
                    if (i + 1 < args.Length)
                        port = args[++i];
                    break;
                case "--username":
                    if (i + 1 < args.Length)
                        username = args[++i];
                    break;
                case "--password":
                    if (i + 1 < args.Length)
                        password = args[++i];
                    break;
            }
        }

        // Check for missing required parameters
        if (dbengine == null || dbhost == null || port == null || username == null)
        {
            PrintUsageAndExit();
        }

        // Validate dbengine
        if (!ValidEngines.Contains(dbengine))
        {
            Console.Error.WriteLine(
                $"Error: Invalid dbengine '{dbengine}'. Valid values are: {string.Join(", ", ValidEngines)}");
            Environment.Exit(1);
        }

        // Validate dbhost is non-empty
        if (string.IsNullOrEmpty(dbhost))
        {
            Console.Error.WriteLine(
                "Error: dbhost must be a non-empty hostname or IP address.");
            Environment.Exit(1);
        }

        // Validate port is numeric integer in range 1-65535
        if (!int.TryParse(port, out int portNumber))
        {
            Console.Error.WriteLine(
                $"Error: Invalid port '{port}'. Port must be a numeric integer between 1 and 65535.");
            Environment.Exit(1);
        }

        if (portNumber < 1 || portNumber > 65535)
        {
            Console.Error.WriteLine(
                $"Error: Invalid port '{portNumber}'. Port must be a numeric integer between 1 and 65535.");
            Environment.Exit(1);
        }

        // Handle password - prompt if not provided
        if (password == null)
        {
            password = PromptPassword("give me password to access the database: ");
        }

        return new ConnectionParams
        {
            DbEngine = dbengine!,
            DbHost = dbhost!,
            Port = portNumber,
            Username = username!,
            Password = password
        };
    }

    /// <summary>
    /// Display usage message and exit with non-zero code.
    /// </summary>
    private static void PrintUsageAndExit()
    {
        Console.Error.WriteLine("usage: dbest --dbengine <engine> --dbhost <host> --port <port> --username <user> [--password <pass>]");
        Console.Error.WriteLine();
        Console.Error.WriteLine("Database Evaluation & Summary Tool (DBEST) - Analyze database instances against best practices.");
        Console.Error.WriteLine();
        Console.Error.WriteLine("Required arguments:");
        Console.Error.WriteLine("  --dbengine    Database engine type. Valid values: mssql, mysql, oracle, postgres, mongodb");
        Console.Error.WriteLine("  --dbhost      Database hostname or IP address (non-empty)");
        Console.Error.WriteLine("  --port        Database port number (1-65535)");
        Console.Error.WriteLine("  --username    Database username");
        Console.Error.WriteLine();
        Console.Error.WriteLine("Optional arguments:");
        Console.Error.WriteLine("  --password    Database password (will prompt if not provided)");
        Environment.Exit(1);
    }

    /// <summary>
    /// Prompt for password without echoing characters to the console.
    /// </summary>
    /// <param name="prompt">The prompt text to display.</param>
    /// <returns>The entered password string.</returns>
    private static string PromptPassword(string prompt)
    {
        Console.Write(prompt);
        var password = new System.Text.StringBuilder();

        while (true)
        {
            var keyInfo = Console.ReadKey(intercept: true);
            if (keyInfo.Key == ConsoleKey.Enter)
            {
                Console.WriteLine();
                break;
            }
            else if (keyInfo.Key == ConsoleKey.Backspace)
            {
                if (password.Length > 0)
                {
                    password.Remove(password.Length - 1, 1);
                }
            }
            else
            {
                password.Append(keyInfo.KeyChar);
            }
        }

        return password.ToString();
    }
}
