''' Database connection management for dbbpc.

Imports System
Imports System.Data
Imports System.Data.SqlClient
Imports MySql.Data.MySqlClient
Imports Npgsql
Imports Oracle.ManagedDataAccess.Client
Imports MongoDB.Driver
Imports MongoDB.Bson
Imports dbbpc.Models

Namespace Connection

    ''' <summary>
    ''' Establishes and verifies database connections using engine-appropriate drivers.
    ''' </summary>
    Public Module DbConnector

        ''' <summary>
        ''' Connection timeout in seconds.
        ''' </summary>
        Public Const CONNECTION_TIMEOUT As Integer = 30

        ''' <summary>
        ''' Establish a database connection using engine-specific drivers.
        ''' Applies a 30-second connection timeout and executes a health-check query.
        ''' On failure, prints a descriptive error message and exits with code 1.
        ''' </summary>
        ''' <param name="params">ConnectionParams with dbengine, dbhost, port, username, password.</param>
        ''' <returns>A connection handle (IDbConnection or IMongoClient) on success.</returns>
        Public Function Connect(params As ConnectionParams) As Object
            Try
                Select Case params.DbEngine
                    Case "mssql"
                        Return ConnectMssql(params)
                    Case "mysql"
                        Return ConnectMysql(params)
                    Case "oracle"
                        Return ConnectOracle(params)
                    Case "postgres"
                        Return ConnectPostgres(params)
                    Case "mongodb"
                        Return ConnectMongodb(params)
                    Case Else
                        Console.Error.WriteLine($"Error: Unsupported database engine '{params.DbEngine}'.")
                        Environment.Exit(1)
                        Return Nothing
                End Select
            Catch ex As Exception
                HandleConnectionError(ex, params)
                Return Nothing
            End Try
        End Function

        ''' <summary>
        ''' Connect to SQL Server using System.Data.SqlClient.
        ''' </summary>
        Private Function ConnectMssql(params As ConnectionParams) As IDbConnection
            Dim connStr As String = $"Server={params.DbHost},{params.Port};User Id={params.Username};Password={params.Password};Connection Timeout={CONNECTION_TIMEOUT};"
            Dim conn As New SqlConnection(connStr)
            conn.Open()
            ' Health-check query
            Using cmd As IDbCommand = conn.CreateCommand()
                cmd.CommandText = "SELECT 1"
                cmd.ExecuteScalar()
            End Using
            Return conn
        End Function

        ''' <summary>
        ''' Connect to MySQL using MySql.Data.
        ''' </summary>
        Private Function ConnectMysql(params As ConnectionParams) As IDbConnection
            Dim connStr As String = $"Server={params.DbHost};Port={params.Port};User Id={params.Username};Password={params.Password};Connection Timeout={CONNECTION_TIMEOUT};"
            Dim conn As New MySqlConnection(connStr)
            conn.Open()
            ' Health-check query
            Using cmd As IDbCommand = conn.CreateCommand()
                cmd.CommandText = "SELECT 1"
                cmd.ExecuteScalar()
            End Using
            Return conn
        End Function

        ''' <summary>
        ''' Connect to Oracle using Oracle.ManagedDataAccess.
        ''' </summary>
        Private Function ConnectOracle(params As ConnectionParams) As IDbConnection
            Dim connStr As String = $"Data Source=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST={params.DbHost})(PORT={params.Port}))(CONNECT_DATA=(SERVICE_NAME=ORCL)));User Id={params.Username};Password={params.Password};Connection Timeout={CONNECTION_TIMEOUT};"
            Dim conn As New OracleConnection(connStr)
            conn.Open()
            ' Health-check query
            Using cmd As IDbCommand = conn.CreateCommand()
                cmd.CommandText = "SELECT 1 FROM DUAL"
                cmd.ExecuteScalar()
            End Using
            Return conn
        End Function

        ''' <summary>
        ''' Connect to PostgreSQL using Npgsql.
        ''' </summary>
        Private Function ConnectPostgres(params As ConnectionParams) As IDbConnection
            Dim connStr As String = $"Host={params.DbHost};Port={params.Port};Username={params.Username};Password={params.Password};Timeout={CONNECTION_TIMEOUT};"
            Dim conn As New NpgsqlConnection(connStr)
            conn.Open()
            ' Health-check query
            Using cmd As IDbCommand = conn.CreateCommand()
                cmd.CommandText = "SELECT 1"
                cmd.ExecuteScalar()
            End Using
            Return conn
        End Function

        ''' <summary>
        ''' Connect to MongoDB using MongoDB.Driver.
        ''' </summary>
        Private Function ConnectMongodb(params As ConnectionParams) As IMongoClient
            Dim uri As String = $"mongodb://{params.Username}:{params.Password}@{params.DbHost}:{params.Port}/"
            Dim settings = MongoClientSettings.FromConnectionString(uri)
            settings.ServerSelectionTimeout = TimeSpan.FromSeconds(CONNECTION_TIMEOUT)
            settings.ConnectTimeout = TimeSpan.FromSeconds(CONNECTION_TIMEOUT)
            Dim client As New MongoClient(settings)
            ' Health-check: ping the admin database
            Dim adminDb = client.GetDatabase("admin")
            adminDb.RunCommand(Of BsonDocument)(New BsonDocument("ping", 1))
            Return client
        End Function

        ''' <summary>
        ''' Classify a connection exception into a category.
        ''' Returns one of: "timeout", "authentication", "network".
        ''' </summary>
        Private Function ClassifyError(exc As Exception) As String
            Dim excType As String = exc.GetType().Name.ToLower()
            Dim excMsg As String = exc.Message.ToLower()

            ' Timeout detection
            Dim timeoutIndicators() As String = {"timeout", "timed out", "connection timed out"}
            For Each indicator In timeoutIndicators
                If excMsg.Contains(indicator) OrElse excType.Contains(indicator) Then
                    Return "timeout"
                End If
            Next

            ' Authentication failure detection
            Dim authIndicators() As String = {"authentication", "auth", "login failed", "access denied",
                                              "invalid credentials", "password", "logon", "ora-01017"}
            For Each indicator In authIndicators
                If excMsg.Contains(indicator) OrElse excType.Contains(indicator) Then
                    Return "authentication"
                End If
            Next

            ' Network error detection (default fallback)
            Return "network"
        End Function

        ''' <summary>
        ''' Print a descriptive error message and exit with code 1.
        ''' </summary>
        Private Sub HandleConnectionError(exc As Exception, params As ConnectionParams)
            Dim errorClass As String = ClassifyError(exc)
            Dim msg As String

            Select Case errorClass
                Case "timeout"
                    msg = $"Connection timed out connecting to {params.DbHost}:{params.Port}"
                Case "authentication"
                    msg = $"Authentication failed for user '{params.Username}' on {params.DbHost}"
                Case Else
                    msg = $"Cannot reach {params.DbHost}:{params.Port} — verify host and network"
            End Select

            Console.Error.WriteLine($"Error: {msg}")
            Environment.Exit(1)
        End Sub

    End Module

End Namespace
