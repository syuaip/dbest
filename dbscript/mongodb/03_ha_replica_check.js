// MongoDB High Availability Replica Check
// Verifies that the instance is part of a replica set for HA
// Requirement: 6.1, 6.2, 6.3 - Replica configuration check

var statusValue = "FLAGGED";
var severityValue = "CRITICAL";
var currentValue = "0";
var message = "";

try {
    var replStatus = rs.status();
    var members = replStatus.members || [];
    var replicaCount = members.length - 1; // Subtract primary from total members

    if (replicaCount < 1) {
        replicaCount = 0;
    }

    currentValue = String(replicaCount);

    if (replicaCount >= 1) {
        statusValue = "PASSED";
        severityValue = "OK";
        message = "Replica set configured with " + replicaCount + " replica(s) for high availability";
    } else {
        message = "Replica set has no secondary members — missing replica for high availability";
    }
} catch (e) {
    // If rs.status() fails, the instance may not be part of a replica set
    statusValue = "FLAGGED";
    severityValue = "CRITICAL";
    currentValue = "0";
    message = "Instance is not configured as part of a replica set — missing replica for high availability";
}

var result = {
    "check_name": "High Availability Replica",
    "check_level": "INSTANCE",
    "status": statusValue,
    "severity": severityValue,
    "current_value": currentValue + " replica(s)",
    "default_value": "At least 1 replica",
    "message": message
};

result;
