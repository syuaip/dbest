namespace dbbpc;

/// <summary>
/// Engine directory resolution and script scanning for dbbpc.
/// Resolves engine directories, scans .sql/.js files, sorts alphabetically.
/// </summary>
public static class ScriptDiscovery
{
    /// <summary>Engine name to directory mapping.</summary>
    public static readonly Dictionary<string, string> EngineDirectoryMap = new()
    {
        ["mssql"] = "mssql",
        ["mysql"] = "mysql",
        ["oracle"] = "oracle",
        ["postgres"] = "pgsql",
        ["mongodb"] = "mongodb"
    };

    /// <summary>
    /// Discover and load diagnostic scripts for the given database engine.
    /// Resolves the engine-specific directory, scans for eligible script files,
    /// sorts them alphabetically, and loads their content.
    /// </summary>
    /// <param name="dbengine">The database engine name (mssql, mysql, oracle, postgres, mongodb).</param>
    /// <param name="basePath">Optional base path for resolving engine directories.
    /// If not provided, resolves relative to the executable location (parent directory).</param>
    /// <returns>A list of ScriptFile objects sorted alphabetically by filename.</returns>
    public static List<ScriptFile> DiscoverScripts(string dbengine, string? basePath = null)
    {
        // Determine the base path for engine directories
        if (basePath == null)
        {
            // Resolve relative to the executable location.
            // The executable is in csharp/dbbpc/bin/..., engine dirs are at the repo root.
            var exeDir = AppDomain.CurrentDomain.BaseDirectory;
            basePath = Path.GetFullPath(Path.Combine(exeDir, "../dbscript"));
        }

        // Get the directory name for this engine
        if (!EngineDirectoryMap.TryGetValue(dbengine, out var directoryName))
        {
            Console.Error.WriteLine(
                $"Error: Unknown database engine '{dbengine}'. " +
                $"Valid engines: {string.Join(", ", EngineDirectoryMap.Keys.OrderBy(k => k))}");
            Environment.Exit(1);
            return null!; // unreachable
        }

        // Resolve the full path to the engine directory
        var engineDir = Path.Combine(basePath, directoryName);

        Console.Error.WriteLine($"Info: Fetching scripts from {engineDir}: loading...");

        // Check if the directory exists
        if (!Directory.Exists(engineDir))
        {
            Console.Error.WriteLine($"Error: Engine directory not found: {engineDir}");
            Environment.Exit(1);
            return null!; // unreachable
        }

        // Determine the file extension to scan for
        var extension = dbengine == "mongodb" ? ".js" : ".sql";

        // Scan for eligible script files
        var scriptFiles = new List<ScriptFile>();
        var files = Directory.GetFiles(engineDir)
            .Where(f => Path.GetExtension(f).Equals(extension, StringComparison.OrdinalIgnoreCase))
            .OrderBy(f => Path.GetFileName(f))
            .ToList();

        foreach (var filePath in files)
        {
            try
            {
                var content = File.ReadAllText(filePath);
                scriptFiles.Add(new ScriptFile
                {
                    Filename = Path.GetFileName(filePath),
                    FullPath = Path.GetFullPath(filePath),
                    Content = content
                });
            }
            catch (Exception e) when (e is IOException || e is UnauthorizedAccessException)
            {
                Console.Error.WriteLine($"Warning: Could not read file {Path.GetFileName(filePath)}: {e.Message}");
                continue;
            }
        }

        // Error if no eligible scripts found
        if (scriptFiles.Count == 0)
        {
            Console.Error.WriteLine(
                $"Error: No {extension} scripts found in engine directory: {engineDir}");
            Environment.Exit(1);
            return null!; // unreachable
        }

        // Sort alphabetically by filename (already sorted, but explicit for clarity)
        scriptFiles.Sort((a, b) => string.Compare(a.Filename, b.Filename, StringComparison.Ordinal));

        return scriptFiles;
    }
}
