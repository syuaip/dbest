"""CLI argument parsing and validation for dbbpc."""

import argparse
import getpass
import sys
from typing import List, Optional

from dbest.models import ConnectionParams

VALID_ENGINES = ["mssql", "mysql", "oracle", "postgres", "mongodb"]


def parse_args(args: Optional[List[str]] = None) -> ConnectionParams:
    """Parse and validate CLI arguments, returning a ConnectionParams object.

    Args:
        args: List of command-line arguments. Defaults to sys.argv[1:] if None.

    Returns:
        ConnectionParams populated with validated values.

    Raises:
        SystemExit: On missing or invalid parameters.
    """
    if args is None:
        args = sys.argv[1:]

    parser = argparse.ArgumentParser(
        prog="dbest",
        description="Database Evaluation & Summary Tool (DBEST) - Analyze database instances against best practices.",
        add_help=True,
    )
    parser.add_argument(
        "--dbengine",
        required=True,
        help=f"Database engine type. Valid values: {', '.join(VALID_ENGINES)}",
    )
    parser.add_argument(
        "--dbhost",
        required=True,
        help="Database hostname or IP address (non-empty)",
    )
    parser.add_argument(
        "--port",
        required=True,
        help="Database port number (1-65535)",
    )
    parser.add_argument(
        "--username",
        required=True,
        help="Database username",
    )
    parser.add_argument(
        "--password",
        required=False,
        default=None,
        help="Database password (will prompt if not provided)",
    )

    parsed = parser.parse_args(args)

    # Validate dbengine
    if parsed.dbengine not in VALID_ENGINES:
        print(
            f"Error: Invalid dbengine '{parsed.dbengine}'. "
            f"Valid values are: {', '.join(VALID_ENGINES)}",
            file=sys.stderr,
        )
        sys.exit(1)

    # Validate dbhost is non-empty
    if not parsed.dbhost:
        print(
            "Error: dbhost must be a non-empty hostname or IP address.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Validate port is numeric integer in range 1-65535
    try:
        port = int(parsed.port)
    except ValueError:
        print(
            f"Error: Invalid port '{parsed.port}'. Port must be a numeric integer between 1 and 65535.",
            file=sys.stderr,
        )
        sys.exit(1)

    if port < 1 or port > 65535:
        print(
            f"Error: Invalid port '{port}'. Port must be a numeric integer between 1 and 65535.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Handle password - prompt if not provided
    password = parsed.password
    if password is None:
        password = getpass.getpass("give me password to access the database: ")

    return ConnectionParams(
        dbengine=parsed.dbengine,
        dbhost=parsed.dbhost,
        port=port,
        username=parsed.username,
        password=password,
    )
