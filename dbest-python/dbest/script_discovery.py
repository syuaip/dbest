"""Engine directory resolution and script scanning for dbbpc."""

import os
import sys
from pathlib import Path
from typing import List, Optional

from .models import ScriptFile

# Engine name to directory mapping
ENGINE_DIRECTORY_MAP: dict = {
    "mssql": "mssql",
    "mysql": "mysql",
    "oracle": "oracle",
    "postgres": "pgsql",
    "mongodb": "mongodb",
}


def discover_scripts(dbengine: str, base_path: Optional[str] = None) -> List[ScriptFile]:
    """Discover and load diagnostic scripts for the given database engine.

    Resolves the engine-specific directory, scans for eligible script files,
    sorts them alphabetically, and loads their content.

    Args:
        dbengine: The database engine name (mssql, mysql, oracle, postgres, mongodb).
        base_path: Optional base path for resolving engine directories.
                   If not provided, resolves relative to the dbbpc.py script location
                   (the parent of the python/ directory).

    Returns:
        A list of ScriptFile objects sorted alphabetically by filename.

    Raises:
        SystemExit: If the engine directory does not exist or contains no eligible scripts.
    """
    # Determine the base path for engine directories
    if base_path is None:
        # Resolve relative to the dbbpc.py script location.
        # Look for dbscript sibling folder next to the python/ directory
        script_dir = Path(os.path.dirname(os.path.abspath(sys.argv[0])))
        base_path = str(script_dir / "../dbscript")

    # Get the directory name for this engine
    directory_name = ENGINE_DIRECTORY_MAP.get(dbengine)
    if directory_name is None:
        print(
            f"Error: Unknown database engine '{dbengine}'. "
            f"Valid engines: {', '.join(sorted(ENGINE_DIRECTORY_MAP.keys()))}",
            file=sys.stderr,
        )
        sys.exit(1)

    # Resolve the full path to the engine directory
    engine_dir = Path(base_path) / directory_name

    print(f"Info: Fetching scripts from '{engine_dir}': loading...", file=sys.stderr)

    # Check if the directory exists
    if not engine_dir.is_dir():
        print(
            f"Error: Engine directory not found: {engine_dir}",
            file=sys.stderr,
        )
        sys.exit(1)

    # Determine the file extension to scan for
    extension = ".js" if dbengine == "mongodb" else ".sql"

    # Scan for eligible script files
    script_files: List[ScriptFile] = []
    for entry in sorted(engine_dir.iterdir()):
        if entry.is_file() and entry.suffix.lower() == extension:
            try:
                content = entry.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError) as e:
                print(
                    f"Warning: Could not read file {entry.name}: {e}",
                    file=sys.stderr,
                )
                continue
            script_files.append(
                ScriptFile(
                    filename=entry.name,
                    full_path=str(entry.resolve()),
                    content=content,
                )
            )

    # Error if no eligible scripts found
    if not script_files:
        print(
            f"Error: No {extension} scripts found in engine directory: {engine_dir}",
            file=sys.stderr,
        )
        sys.exit(1)

    # Sort alphabetically by filename (already sorted by iterdir + sorted, but explicit)
    script_files.sort(key=lambda sf: sf.filename)

    return script_files
