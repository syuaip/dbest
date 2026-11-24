"""Core data models and enums for dbbpc."""

from dataclasses import dataclass, field
from enum import Enum
from typing import List


class CheckLevel(Enum):
    """Categorization level for a diagnostic check."""

    INSTANCE = "INSTANCE"
    DATABASE = "DATABASE"
    TABLE = "TABLE"


class CheckStatus(Enum):
    """Outcome status of a diagnostic check."""

    PASSED = "PASSED"
    FLAGGED = "FLAGGED"
    ERROR = "ERROR"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"


class Severity(Enum):
    """Visual severity level for report color coding."""

    OK = "OK"
    ADVISORY = "ADVISORY"
    CRITICAL = "CRITICAL"


@dataclass
class ConnectionParams:
    """Database connection parameters parsed from CLI arguments."""

    dbengine: str  # one of: mssql, mysql, oracle, postgres, mongodb
    dbhost: str  # non-empty hostname or IP
    port: int  # 1-65535
    username: str  # non-empty
    password: str  # may be empty string if prompted


@dataclass
class DetailRow:
    """Per-object detail row for multi-row check results."""

    object_name: str  # schema.table or database name
    column_name: str  # column name (may be empty)
    finding: str  # specific finding for this object
    value: str  # associated value


@dataclass
class CheckResult:
    """Result of a single diagnostic check execution."""

    script_name: str  # filename of the source script
    check_name: str  # human-readable check identifier
    check_level: CheckLevel  # INSTANCE, DATABASE, or TABLE
    status: CheckStatus  # PASSED, FLAGGED, ERROR, or INSUFFICIENT_DATA
    severity: Severity  # OK, ADVISORY, or CRITICAL
    current_value: str  # retrieved configuration value
    default_value: str  # engine default value (may be empty)
    message: str  # descriptive finding text
    details: List[DetailRow] = field(default_factory=list)


@dataclass
class ReportMetadata:
    """Metadata for the generated HTML report."""

    dbengine: str  # engine that was checked
    dbhost: str  # target host
    timestamp: str  # ISO 8601 execution timestamp
    total_passed: int  # count of passed checks
    total_flagged: int  # count of flagged checks


@dataclass
class ScriptFile:
    """A discovered diagnostic script file."""

    filename: str  # script filename
    full_path: str  # absolute path to the script
    content: str  # loaded file content


# Engine configuration defaults mapping engine → parameter → default_value
# Used for comparison checks (parallelism, checkpoint, etc.)
ENGINE_DEFAULTS: dict = {
    "postgres": {
        "max_parallel_workers": "8",
        "checkpoint_timeout": "5min",
        "max_wal_size": "1GB",
        "autovacuum_freeze_max_age": "200000000",
        "autovacuum_vacuum_threshold": "50",
        "autovacuum_vacuum_scale_factor": "0.2",
        "autovacuum_max_workers": "3",
    },
    "mssql": {
        "MaxDOP": "0",
        "cost threshold for parallelism": "5",
        "recovery_interval": "0",
    },
    "mysql": {
        "innodb_parallel_read_threads": "4",
        "innodb_log_file_size": "48MB",
    },
    "oracle": {
        "PARALLEL_MAX_SERVERS": "0",
        "LOG_CHECKPOINT_TIMEOUT": "0",
    },
}
