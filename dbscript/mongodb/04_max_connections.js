// MongoDB Maximum Connections Check
// Retrieves net.maxIncomingConnections to detect non-default or critical values
// Requirement: 8.1, 8.2, 8.3, 8.4 - Maximum connection value check

var status = db.serverStatus();
var connections = status.connections || {};
var currentConnections = connections.current || 0;
var availableConnections = connections.available || 0;
var totalCreated = connections.totalCreated || 0;

// Get the configured maximum connections
var cmdLineOpts = db.adminCommand({getCmdLineOpts: 1});
var maxConns = 65536; // MongoDB default
var configuredMax = null;

// Check if maxIncomingConnections is set in config
if (cmdLineOpts && cmdLineOpts.parsed && cmdLineOpts.parsed.net) {
    configuredMax = cmdLineOpts.parsed.net.maxIncomingConnections;
}

// If not found in parsed options, calculate from serverStatus
if (configuredMax === null) {
    configuredMax = currentConnections + availableConnections;
}

var defaultValue = 65536;
var statusValue = "PASSED";
var severityValue = "OK";
var message = "";

if (configuredMax === 1) {
    statusValue = "FLAGGED";
    severityValue = "CRITICAL";
    message = "Critical: maximum connections set to 1 — database cannot accept client connections";
} else if (configuredMax !== defaultValue) {
    statusValue = "FLAGGED";
    severityValue = "ADVISORY";
    message = "Non-default maximum connections (" + configuredMax + ") requiring verification. Default is " + defaultValue;
} else {
    message = "Maximum connections is set to default value (" + defaultValue + ")";
}

var result = {
    "check_name": "Maximum Connections",
    "check_level": "INSTANCE",
    "status": statusValue,
    "severity": severityValue,
    "current_value": String(configuredMax),
    "default_value": String(defaultValue),
    "message": message
};

result;
