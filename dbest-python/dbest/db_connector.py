"""Database connection management for dbbpc."""

import sys

from dbest.models import ConnectionParams

# Connection timeout in seconds
CONNECTION_TIMEOUT = 30


def connect(params: ConnectionParams):
    """Establish a database connection using engine-specific drivers.

    Selects the appropriate driver based on params.dbengine, applies a
    30-second connection timeout, executes a health-check query on success,
    and returns the connection handle.

    On failure, prints a descriptive error message to stderr and exits
    with code 1.

    Args:
        params: ConnectionParams with dbengine, dbhost, port, username, password.

    Returns:
        A connection handle (driver-specific) on success.
    """
    engine = params.dbengine

    try:
        if engine == "mssql":
            return _connect_mssql(params)
        elif engine == "mysql":
            return _connect_mysql(params)
        elif engine == "oracle":
            return _connect_oracle(params)
        elif engine == "postgres":
            return _connect_postgres(params)
        elif engine == "mongodb":
            return _connect_mongodb(params)
        else:
            print(
                f"Error: Unsupported database engine '{engine}'.",
                file=sys.stderr,
            )
            sys.exit(1)
    except SystemExit:
        raise
    except Exception as exc:
        _handle_connection_error(exc, params)


def _connect_mssql(params: ConnectionParams):
    """Connect to SQL Server using pyodbc."""
    import pyodbc

    connection_string = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={params.dbhost},{params.port};"
        f"UID={params.username};"
        f"PWD={params.password};"
    )
    conn = pyodbc.connect(connection_string, timeout=CONNECTION_TIMEOUT)
    # Health-check query
    cursor = conn.cursor()
    cursor.execute("SELECT 1")
    cursor.close()
    return conn


def _connect_mysql(params: ConnectionParams):
    """Connect to MySQL using mysql-connector-python."""
    import mysql.connector

    conn = mysql.connector.connect(
        host=params.dbhost,
        port=params.port,
        user=params.username,
        password=params.password,
        connection_timeout=CONNECTION_TIMEOUT,
    )
    # Health-check query
    cursor = conn.cursor()
    cursor.execute("SELECT 1")
    cursor.fetchall()
    cursor.close()
    return conn


def _connect_oracle(params: ConnectionParams):
    """Connect to Oracle using cx_Oracle."""
    import cx_Oracle

    dsn = cx_Oracle.makedsn(params.dbhost, params.port)
    conn = cx_Oracle.connect(
        user=params.username,
        password=params.password,
        dsn=dsn,
    )
    # cx_Oracle doesn't have a direct timeout param on connect;
    # set call_timeout in milliseconds after connection
    conn.call_timeout = CONNECTION_TIMEOUT * 1000
    # Health-check query
    cursor = conn.cursor()
    cursor.execute("SELECT 1 FROM DUAL")
    cursor.fetchall()
    cursor.close()
    return conn


def _connect_postgres(params: ConnectionParams):
    """Connect to PostgreSQL using psycopg2."""
    import psycopg2

    conn = psycopg2.connect(
        host=params.dbhost,
        port=params.port,
        user=params.username,
        password=params.password,
        connect_timeout=CONNECTION_TIMEOUT,
    )
    # Health-check query
    cursor = conn.cursor()
    cursor.execute("SELECT 1")
    cursor.fetchall()
    cursor.close()
    return conn


def _connect_mongodb(params: ConnectionParams):
    """Connect to MongoDB using pymongo."""
    from pymongo import MongoClient

    uri = (
        f"mongodb://{params.username}:{params.password}"
        f"@{params.dbhost}:{params.port}/"
    )
    client = MongoClient(
        uri,
        serverSelectionTimeoutMS=CONNECTION_TIMEOUT * 1000,
        connectTimeoutMS=CONNECTION_TIMEOUT * 1000,
    )
    # Health-check: ping the admin database
    client.admin.command("ping")
    return client


def _classify_error(exc: Exception) -> str:
    """Classify a connection exception into a category.

    Returns one of: 'timeout', 'authentication', 'network'.
    """
    exc_type = type(exc).__name__.lower()
    exc_msg = str(exc).lower()

    # Timeout detection
    timeout_indicators = ["timeout", "timed out", "connection timed out"]
    for indicator in timeout_indicators:
        if indicator in exc_msg or indicator in exc_type:
            return "timeout"

    # Authentication failure detection
    auth_indicators = [
        "authentication",
        "auth",
        "login failed",
        "access denied",
        "invalid credentials",
        "password",
        "logon",
        "ora-01017",
    ]
    for indicator in auth_indicators:
        if indicator in exc_msg or indicator in exc_type:
            return "authentication"

    # Network error detection (default fallback for connection issues)
    return "network"


def _handle_connection_error(exc: Exception, params: ConnectionParams):
    """Print a descriptive error message and exit with code 1."""
    error_class = _classify_error(exc)

    if error_class == "timeout":
        msg = (
            f"Connection timed out connecting to "
            f"{params.dbhost}:{params.port}"
        )
    elif error_class == "authentication":
        msg = (
            f"Authentication failed for user '{params.username}' "
            f"on {params.dbhost}"
        )
    else:
        msg = (
            f"Cannot reach {params.dbhost}:{params.port} "
            f"— verify host and network"
        )

    print(f"Error: {msg}", file=sys.stderr)
    sys.exit(1)
