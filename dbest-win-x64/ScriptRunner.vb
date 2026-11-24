''' Script execution engine for dbbpc.

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.IO
Imports System.Text.Json
Imports MongoDB.Driver
Imports MongoDB.Bson
Imports dbbpc.Models

Namespace Execution

    ''' <summary>
    ''' Executes diagnostic scripts against the database and collects results.
    ''' </summary>
    Public Module ScriptRunner

        ''' <summary>
        ''' Execute diagnostic scripts against the database and collect results.
        ''' Iterates through the provided scripts in order, executing each script's
        ''' SQL/JS content against the connection handle. On execution failure,
        ''' captures the error into a CheckResult with status=ERROR.
        ''' </summary>
        ''' <param name="connection">A database connection handle (IDbConnection or IMongoClient).</param>
        ''' <param name="scripts">List of ScriptFile objects, already sorted alphabetically.</param>
        ''' <param name="dbengine">The database engine identifier.</param>
        ''' <returns>A complete list of CheckResult objects from all executed scripts.</returns>
        Public Function RunScripts(connection As Object, scripts As List(Of ScriptFile), dbengine As String) As List(Of CheckResult)
            Dim results As New List(Of CheckResult)()

            For Each script In scripts
                ' Check for unreadable file (content is empty or Nothing)
                If script.Content Is Nothing OrElse String.IsNullOrWhiteSpace(script.Content) Then
                    ' Skip with logged warning
                    Console.Error.WriteLine($"Warning: Skipping script '{script.Filename}': file content is empty or unreadable")
                    Continue For
                End If

                Try
                    Dim rawResults As List(Of Dictionary(Of String, Object))

                    Console.Error.WriteLine($"Info: Running script '{script.Filename}': executing... ")

                    If dbengine = "mongodb" Then
                        rawResults = ExecuteMongodbScript(DirectCast(connection, IMongoClient), script)
                    Else
                        rawResults = ExecuteSqlScript(DirectCast(connection, IDbConnection), script)
                    End If

                    ' Parse the raw results into CheckResult(s)
                    Dim checkResults As List(Of CheckResult) = ParseScriptResults(script, rawResults)
                    results.AddRange(checkResults)

                Catch ex As Exception
                    ' Capture execution failure as ERROR CheckResult
                    Dim errorResult As New CheckResult(
                        scriptName:=script.Filename,
                        checkName:=DeriveCheckName(script.Filename),
                        checkLevel:=CheckLevel.INSTANCE,
                        status:=CheckStatus.ERROR,
                        severity:=Severity.ADVISORY,
                        currentValue:="",
                        defaultValue:="",
                        message:=$"Script execution failed: {ex.GetType().Name}: {ex.Message}"
                    )
                    results.Add(errorResult)
                End Try
            Next

            Return results
        End Function

        ''' <summary>
        ''' Execute a SQL script against the connection and return result rows.
        ''' </summary>
        Private Function ExecuteSqlScript(connection As IDbConnection, script As ScriptFile) As List(Of Dictionary(Of String, Object))
            Dim results As New List(Of Dictionary(Of String, Object))()

            Using cmd As IDbCommand = connection.CreateCommand()
                ' Oracle rejects trailing semicolons (ORA-00933).
                ' Strip them universally; other engines tolerate absence.
                Dim sqlContent As String = script.Content.TrimEnd()
                If sqlContent.EndsWith(";") Then
                    sqlContent = sqlContent.Substring(0, sqlContent.Length - 1)
                End If

                cmd.CommandText = sqlContent

                Using reader As IDataReader = cmd.ExecuteReader()
                    ' Get column names
                    Dim columns As New List(Of String)()
                    For i As Integer = 0 To reader.FieldCount - 1
                        columns.Add(reader.GetName(i))
                    Next

                    ' Read rows
                    While reader.Read()
                        Dim row As New Dictionary(Of String, Object)()
                        For i As Integer = 0 To columns.Count - 1
                            Dim value As Object = reader.GetValue(i)
                            If TypeOf value Is DBNull Then
                                row(columns(i)) = Nothing
                            Else
                                row(columns(i)) = value
                            End If
                        Next
                        results.Add(row)
                    End While
                End Using
            End Using

            Return results
        End Function

        ''' <summary>
        ''' Execute a MongoDB JavaScript script using RunCommand.
        ''' </summary>
        Private Function ExecuteMongodbScript(client As IMongoClient, script As ScriptFile) As List(Of Dictionary(Of String, Object))
            Dim results As New List(Of Dictionary(Of String, Object))()
            Dim content As String = script.Content.Trim()

            Try
                ' Attempt to parse as JSON command document
                Dim commandDoc = BsonDocument.Parse(content)
                Dim adminDb = client.GetDatabase("admin")
                Dim result = adminDb.RunCommand(Of BsonDocument)(commandDoc)

                Dim row As New Dictionary(Of String, Object)()
                For Each element In result.Elements
                    row(element.Name) = BsonTypeMapper.MapToDotNetValue(element.Value)
                Next
                results.Add(row)
            Catch ex As Exception
                ' If not valid JSON, try eval command
                Try
                    Dim adminDb = client.GetDatabase("admin")
                    Dim evalCmd = New BsonDocument("eval", content)
                    Dim result = adminDb.RunCommand(Of BsonDocument)(evalCmd)

                    Dim row As New Dictionary(Of String, Object)()
                    For Each element In result.Elements
                        row(element.Name) = BsonTypeMapper.MapToDotNetValue(element.Value)
                    Next
                    results.Add(row)
                Catch
                    ' Re-throw to be caught by outer handler
                    Throw
                End Try
            End Try

            Return results
        End Function

        ''' <summary>
        ''' Derive a human-readable check name from a script filename.
        ''' Strips the file extension, removes leading numeric prefixes and
        ''' underscores, and converts underscores to spaces with title case.
        ''' </summary>
        Public Function DeriveCheckName(filename As String) As String
            ' Remove extension
            Dim name As String = Path.GetFileNameWithoutExtension(filename)

            ' Remove leading numeric prefix (e.g., '01_')
            Dim underscoreIdx As Integer = name.IndexOf("_"c)
            If underscoreIdx > 0 Then
                Dim prefix As String = name.Substring(0, underscoreIdx)
                Dim allDigits As Boolean = True
                For Each c In prefix
                    If Not Char.IsDigit(c) Then
                        allDigits = False
                        Exit For
                    End If
                Next
                If allDigits Then
                    name = name.Substring(underscoreIdx + 1)
                End If
            End If

            ' Convert underscores to spaces and title case
            Dim words = name.Split("_"c)
            For i As Integer = 0 To words.Length - 1
                If words(i).Length > 0 Then
                    words(i) = Char.ToUpper(words(i)(0)) & words(i).Substring(1).ToLower()
                End If
            Next

            Return String.Join(" ", words)
        End Function

        ''' <summary>
        ''' Parse raw script execution results into one or more CheckResults.
        ''' If multiple rows all contain standardized columns (check_name, status),
        ''' each row becomes a separate CheckResult. Otherwise, subsequent rows
        ''' are treated as detail rows of the first result.
        ''' </summary>
        Private Function ParseScriptResults(script As ScriptFile, rawResults As List(Of Dictionary(Of String, Object))) As List(Of CheckResult)
            Dim resultList As New List(Of CheckResult)()

            If rawResults Is Nothing OrElse rawResults.Count = 0 Then
                resultList.Add(New CheckResult(
                    scriptName:=script.Filename,
                    checkName:=DeriveCheckName(script.Filename),
                    checkLevel:=CheckLevel.INSTANCE,
                    status:=CheckStatus.PASSED,
                    severity:=Severity.OK,
                    currentValue:="",
                    defaultValue:="",
                    message:="Check completed with no findings"
                ))
                Return resultList
            End If

            ' Determine if multiple rows are independent results or detail rows
            Dim hasMultipleResults As Boolean = False
            If rawResults.Count > 1 Then
                Dim secondRow = rawResults(1)
                If secondRow.ContainsKey("check_name") AndAlso secondRow.ContainsKey("status") Then
                    hasMultipleResults = True
                End If
            End If

            If hasMultipleResults Then
                ' Each row is an independent CheckResult
                For Each row In rawResults
                    resultList.Add(ParseSingleRow(script, row))
                Next
            Else
                ' Single result (first row only)
                resultList.Add(ParseSingleRow(script, rawResults(0)))
            End If

            Return resultList
        End Function

        ''' <summary>
        ''' Parse a single result row into a CheckResult.
        ''' </summary>
        Private Function ParseSingleRow(script As ScriptFile, row As Dictionary(Of String, Object)) As CheckResult
            Dim checkName As String = GetStringValue(row, "check_name", DeriveCheckName(script.Filename))

            Dim checkLevelStr As String = GetStringValue(row, "check_level", "INSTANCE").ToUpper()
            Dim parsedCheckLevel As CheckLevel
            If Not [Enum].TryParse(checkLevelStr, parsedCheckLevel) Then
                parsedCheckLevel = CheckLevel.INSTANCE
            End If

            Dim statusStr As String = GetStringValue(row, "status", "PASSED").ToUpper()
            Dim status As CheckStatus
            If Not [Enum].TryParse(statusStr, status) Then
                status = CheckStatus.PASSED
            End If

            Dim severityStr As String = GetStringValue(row, "severity", "OK").ToUpper()
            Dim parsedSeverity As Severity
            If Not [Enum].TryParse(severityStr, parsedSeverity) Then
                parsedSeverity = Severity.OK
            End If

            Dim currentValue As String = GetStringValue(row, "current_value", "")
            Dim defaultValue As String = GetStringValue(row, "default_value", "")
            Dim message As String = GetStringValue(row, "message", "")

            Return New CheckResult(
                scriptName:=script.Filename,
                checkName:=checkName,
                checkLevel:=parsedCheckLevel,
                status:=status,
                severity:=parsedSeverity,
                currentValue:=currentValue,
                defaultValue:=defaultValue,
                message:=message
            )
        End Function

        ''' <summary>
        ''' Get a string value from a dictionary, with a default fallback.
        ''' </summary>
        Private Function GetStringValue(row As Dictionary(Of String, Object), key As String, defaultVal As String) As String
            Dim value As Object = Nothing
            If row.TryGetValue(key, value) Then
                If value IsNot Nothing Then
                    Return value.ToString()
                End If
            End If
            Return defaultVal
        End Function

    End Module

End Namespace
