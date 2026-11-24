''' CLI argument parsing and validation for dbbpc.

Imports System
Imports System.Collections.Generic
Imports dbbpc.Models

Namespace Cli

    ''' <summary>
    ''' Parses and validates command-line arguments for the dbbpc tool.
    ''' </summary>
    Public Module CliParser

        ''' <summary>
        ''' Valid database engine names (case-sensitive).
        ''' </summary>
        Public ReadOnly VALID_ENGINES As String() = {"mssql", "mysql", "oracle", "postgres", "mongodb"}

        ''' <summary>
        ''' Parse and validate CLI arguments, returning a ConnectionParams object.
        ''' On missing or invalid parameters, prints an error and exits with code 1.
        ''' </summary>
        ''' <param name="args">Raw command-line arguments.</param>
        ''' <returns>A populated ConnectionParams on success.</returns>
        Public Function ParseArgs(args As String()) As ConnectionParams
            Dim dbengine As String = Nothing
            Dim dbhost As String = Nothing
            Dim portStr As String = Nothing
            Dim username As String = Nothing
            Dim password As String = Nothing

            ' Parse named parameters from args
            Dim i As Integer = 0
            While i < args.Length
                Select Case args(i).ToLower()
                    Case "--dbengine"
                        If i + 1 < args.Length Then
                            dbengine = args(i + 1)
                            i += 2
                        Else
                            PrintErrorAndExit("Error: --dbengine requires a value.")
                            Return Nothing
                        End If
                    Case "--dbhost"
                        If i + 1 < args.Length Then
                            dbhost = args(i + 1)
                            i += 2
                        Else
                            PrintErrorAndExit("Error: --dbhost requires a value.")
                            Return Nothing
                        End If
                    Case "--port"
                        If i + 1 < args.Length Then
                            portStr = args(i + 1)
                            i += 2
                        Else
                            PrintErrorAndExit("Error: --port requires a value.")
                            Return Nothing
                        End If
                    Case "--username"
                        If i + 1 < args.Length Then
                            username = args(i + 1)
                            i += 2
                        Else
                            PrintErrorAndExit("Error: --username requires a value.")
                            Return Nothing
                        End If
                    Case "--password"
                        If i + 1 < args.Length Then
                            password = args(i + 1)
                            i += 2
                        Else
                            PrintErrorAndExit("Error: --password requires a value.")
                            Return Nothing
                        End If
                    Case Else
                        PrintUsageAndExit($"Error: Unknown argument '{args(i)}'.")
                        Return Nothing
                End Select
            End While

            ' Check for missing required parameters
            Dim missing As New List(Of String)()
            If dbengine Is Nothing Then missing.Add("dbengine")
            If dbhost Is Nothing Then missing.Add("dbhost")
            If portStr Is Nothing Then missing.Add("port")
            If username Is Nothing Then missing.Add("username")

            If missing.Count > 0 Then
                PrintUsageAndExit($"Error: Missing required parameter(s): {String.Join(", ", missing)}")
                Return Nothing
            End If

            ' Validate dbengine against allowed values (case-sensitive)
            If Array.IndexOf(VALID_ENGINES, dbengine) < 0 Then
                PrintErrorAndExit($"Error: Invalid dbengine '{dbengine}'. Valid values are: {String.Join(", ", VALID_ENGINES)}")
                Return Nothing
            End If

            ' Validate dbhost is non-empty
            If String.IsNullOrWhiteSpace(dbhost) Then
                PrintErrorAndExit("Error: dbhost must be a non-empty hostname or IP address.")
                Return Nothing
            End If

            ' Validate port is numeric integer in range 1-65535
            Dim port As Integer
            If Not Integer.TryParse(portStr, port) Then
                PrintErrorAndExit($"Error: Invalid port '{portStr}'. Port must be a numeric integer between 1 and 65535.")
                Return Nothing
            End If

            If port < 1 OrElse port > 65535 Then
                PrintErrorAndExit($"Error: Invalid port '{port}'. Port must be a numeric integer between 1 and 65535.")
                Return Nothing
            End If

            ' Handle password - prompt if not provided
            If password Is Nothing Then
                password = PromptPassword("give me password to access the database: ")
            End If

            Return New ConnectionParams(dbengine, dbhost, port, username, password)
        End Function

        ''' <summary>
        ''' Prompt the user for a password without echoing characters.
        ''' </summary>
        Private Function PromptPassword(prompt As String) As String
            Console.Write(prompt)
            Dim pwd As String = ""
            Dim key As ConsoleKeyInfo
            Do
                key = Console.ReadKey(True)
                If key.Key = ConsoleKey.Enter Then
                    Exit Do
                ElseIf key.Key = ConsoleKey.Backspace Then
                    If pwd.Length > 0 Then
                        pwd = pwd.Substring(0, pwd.Length - 1)
                    End If
                Else
                    pwd &= key.KeyChar
                End If
            Loop
            Console.WriteLine()
            Return pwd
        End Function

        ''' <summary>
        ''' Print an error message to stderr and exit with code 1.
        ''' </summary>
        Private Sub PrintErrorAndExit(message As String)
            Console.Error.WriteLine(message)
            Environment.Exit(1)
        End Sub

        ''' <summary>
        ''' Print usage information and an error message to stderr, then exit with code 1.
        ''' </summary>
        Private Sub PrintUsageAndExit(message As String)
            Console.Error.WriteLine(message)
            Console.Error.WriteLine()
            Console.Error.WriteLine("Usage: dbest --dbengine <engine> --dbhost <host> --port <port> --username <user> [--password <pass>]")
            Console.Error.WriteLine()
            Console.Error.WriteLine("Database Evaluation & Summary Tool (DBEST) - Analyze database instances against best practices.")
            Console.Error.WriteLine()
            Console.Error.WriteLine("Required parameters:")
            Console.Error.WriteLine("  --dbengine   Database engine type. Valid values: mssql, mysql, oracle, postgres, mongodb")
            Console.Error.WriteLine("  --dbhost     Database hostname or IP address (non-empty)")
            Console.Error.WriteLine("  --port       Database port number (1-65535)")
            Console.Error.WriteLine("  --username   Database username")
            Console.Error.WriteLine()
            Console.Error.WriteLine("Optional parameters:")
            Console.Error.WriteLine("  --password   Database password (will prompt if not provided)")
            Environment.Exit(1)
        End Sub

    End Module

End Namespace
