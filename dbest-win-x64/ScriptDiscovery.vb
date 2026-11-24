''' Engine directory resolution and script scanning for dbbpc.

Imports System
Imports System.Collections.Generic
Imports System.IO
Imports System.Linq
Imports System.Reflection
Imports dbbpc.Models

Namespace Discovery

    ''' <summary>
    ''' Resolves engine directories and discovers diagnostic scripts.
    ''' </summary>
    Public Module ScriptDiscovery

        ''' <summary>
        ''' Engine name to directory mapping.
        ''' </summary>
        Public ReadOnly ENGINE_DIRECTORY_MAP As New Dictionary(Of String, String) From {
            {"mssql", "mssql"},
            {"mysql", "mysql"},
            {"oracle", "oracle"},
            {"postgres", "pgsql"},
            {"mongodb", "mongodb"}
        }

        ''' <summary>
        ''' Discover and load diagnostic scripts for the given database engine.
        ''' Resolves the engine-specific directory, scans for eligible script files,
        ''' sorts them alphabetically, and loads their content.
        ''' </summary>
        ''' <param name="dbengine">The database engine name (mssql, mysql, oracle, postgres, mongodb).</param>
        ''' <param name="basePath">Optional base path for resolving engine directories.
        ''' If not provided, resolves relative to the executable location (parent directory).</param>
        ''' <returns>A list of ScriptFile objects sorted alphabetically by filename.</returns>
        Public Function DiscoverScripts(dbengine As String, Optional basePath As String = Nothing) As List(Of ScriptFile)
            ' Determine the base path for engine directories
            If basePath Is Nothing Then
                ' Resolve relative to the executable location.
                ' The executable is in vbnet/dbbpc/bin/..., engine dirs are in the project root.
                Dim exeDir As String = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location)
                basePath = Path.GetFullPath(Path.Combine(exeDir, "..\dbscript"))
            End If

            ' Get the directory name for this engine
            Dim directoryName As String = Nothing
            If Not ENGINE_DIRECTORY_MAP.TryGetValue(dbengine, directoryName) Then
                Console.Error.WriteLine($"Error: Unknown database engine '{dbengine}'. Valid engines: {String.Join(", ", ENGINE_DIRECTORY_MAP.Keys.OrderBy(Function(k) k))}")
                Environment.Exit(1)
                Return Nothing
            End If

            ' Resolve the full path to the engine directory
            Dim engineDir As String = Path.Combine(basePath, directoryName)

            Console.Error.WriteLine($"Info: Fetching scripts from '{engineDir}': loading... ")

            ' Check if the directory exists
            If Not Directory.Exists(engineDir) Then
                Console.Error.WriteLine($"Error: Engine directory not found: {engineDir}")
                Environment.Exit(1)
                Return Nothing
            End If

            ' Determine the file extension to scan for
            Dim extension As String = If(dbengine = "mongodb", ".js", ".sql")

            ' Scan for eligible script files
            Dim scriptFiles As New List(Of ScriptFile)()
            Dim files = Directory.GetFiles(engineDir).OrderBy(Function(f) Path.GetFileName(f)).ToList()

            For Each filePath In files
                Dim fileName As String = Path.GetFileName(filePath)
                If Path.GetExtension(fileName).ToLower() = extension Then
                    Try
                        Dim content As String = File.ReadAllText(filePath)
                        scriptFiles.Add(New ScriptFile(fileName, Path.GetFullPath(filePath), content))
                    Catch ex As Exception
                        Console.Error.WriteLine($"Warning: Could not read file {fileName}: {ex.Message}")
                        Continue For
                    End Try
                End If
            Next

            ' Error if no eligible scripts found
            If scriptFiles.Count = 0 Then
                Console.Error.WriteLine($"Error: No {extension} scripts found in engine directory: {engineDir}")
                Environment.Exit(1)
                Return Nothing
            End If

            ' Sort alphabetically by filename (already sorted, but explicit)
            scriptFiles.Sort(Function(a, b) String.Compare(a.Filename, b.Filename, StringComparison.Ordinal))

            Return scriptFiles
        End Function

    End Module

End Namespace
