''' Entry point for the Database Best Practices Checker (dbbpc) CLI tool.

Imports System
Imports dbbpc.Models
Imports dbbpc.Cli
Imports dbbpc.Connection
Imports dbbpc.Discovery
Imports dbbpc.Execution
Imports dbbpc.Reporting

Module Program

    ''' <summary>
    ''' Main entry point for the dbbpc CLI tool.
    ''' Implements the pipeline: CLI parsing -> DB connection -> Script discovery -> Script execution -> Report generation.
    ''' Exit codes:
    '''   0 - Success
    '''   1 - Error (connection failure, missing scripts, report generation failure, etc.)
    ''' </summary>
    Sub Main(args As String())
        Try
            ' Step 1: Parse CLI arguments
            Dim params As ConnectionParams = CliParser.ParseArgs(args)

            ' Step 2: Connect to the database
            Dim connection As Object = DbConnector.Connect(params)

            ' Step 3: Discover diagnostic scripts for the engine
            Dim scripts As List(Of ScriptFile) = ScriptDiscovery.DiscoverScripts(params.DbEngine)

            ' Step 4: Run scripts against the database
            Dim results As List(Of CheckResult) = ScriptRunner.RunScripts(connection, scripts, params.DbEngine)

            ' Step 5: Build report metadata
            Dim totalPassed As Integer = 0
            Dim totalFlagged As Integer = 0
            For Each r In results
                If r.Status = CheckStatus.PASSED Then
                    totalPassed += 1
                ElseIf r.Status = CheckStatus.FLAGGED OrElse r.Status = CheckStatus.ERROR Then
                    totalFlagged += 1
                End If
            Next

            Dim metadata As New ReportMetadata(
                dbEngine:=params.DbEngine,
                dbHost:=params.DbHost,
                timestamp:=DateTime.UtcNow.ToString("o"),
                totalPassed:=totalPassed,
                totalFlagged:=totalFlagged
            )

            ' Step 6: Generate the HTML report
            Dim reportPath As String = ReportGenerator.GenerateReport(results, metadata)

            ' Step 7: Print success message
            Console.WriteLine($"Report generated successfully: {reportPath}")

        Catch ex As Exception
            Console.Error.WriteLine($"Error: {ex.Message}")
            Environment.Exit(1)
        End Try
    End Sub

End Module
