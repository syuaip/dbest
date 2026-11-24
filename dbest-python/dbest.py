#!/usr/bin/env python3
"""Database Best Practices Checker (dbbpc) - Entry Point."""

import sys
from datetime import datetime, timezone

from dbest.cli_parser import parse_args
from dbest.db_connector import connect
from dbest.models import CheckStatus, ReportMetadata
from dbest.report_generator import generate_report
from dbest.script_discovery import discover_scripts
from dbest.script_runner import run_scripts


def main():
    """Main entry point for the dbbpc CLI tool.

    Pipeline: parse args → connect → discover scripts → run scripts → generate report.

    Exit codes:
        0 - Success
        1 - Error (connection failure, missing scripts, report generation failure, etc.)
    """
    try:
        # Step 1: Parse CLI arguments
        params = parse_args()

        # Step 2: Connect to the database
        connection = connect(params)

        # Step 3: Discover diagnostic scripts for the engine
        scripts = discover_scripts(params.dbengine)

        # Step 4: Run scripts against the database
        results = run_scripts(connection, scripts, params.dbengine)

        # Step 5: Build report metadata
        total_passed = sum(
            1 for r in results if r.status == CheckStatus.PASSED
        )
        total_flagged = sum(
            1 for r in results
            if r.status in (CheckStatus.FLAGGED, CheckStatus.ERROR)
        )
        metadata = ReportMetadata(
            dbengine=params.dbengine,
            dbhost=params.dbhost,
            timestamp=datetime.now(timezone.utc).isoformat(),
            total_passed=total_passed,
            total_flagged=total_flagged,
        )

        # Step 6: Generate the HTML report
        report_path = generate_report(results, metadata)

        # Step 7: Print success message
        print(f"Report generated successfully: {report_path}")

    except SystemExit:
        # Re-raise SystemExit so that argparse/validation exits propagate
        raise
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
