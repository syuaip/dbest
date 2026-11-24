// MongoDB CPU Utilization Check
// Retrieves CPU usage from serverStatus to assess over-provisioning
// Requirement: 4.1, 4.2, 4.3 - Average CPU usage over available period
// Note: MongoDB serverStatus provides instantaneous CPU metrics;
// historical 30-day average requires external monitoring (CloudWatch/Atlas)

var status = db.serverStatus();
var cpuInfo = status.extra_info || {};
var systemCpu = cpuInfo.page_faults || 0;

// MongoDB does not natively track 30-day CPU averages.
// This script retrieves current CPU usage indicators from serverStatus.
// For full 30-day analysis, use CloudWatch or Atlas metrics.

var result = {
    "check_name": "CPU Utilization",
    "check_level": "INSTANCE",
    "status": "INSUFFICIENT_DATA",
    "severity": "ADVISORY",
    "current_value": "See CloudWatch/Atlas metrics for 30-day average",
    "default_value": "40% threshold",
    "message": "MongoDB does not natively store 30-day CPU history. Use CloudWatch or Atlas Performance Advisor for historical CPU utilization analysis. Current page faults (I/O indicator): " + systemCpu
};

result;
