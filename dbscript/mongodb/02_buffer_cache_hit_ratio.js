// MongoDB Buffer Cache Hit Ratio Check
// Retrieves WiredTiger cache statistics to assess memory provisioning
// Requirement: 5.1, 5.2, 5.3 - Buffer Cache Hit Ratio over 24 hours

var status = db.serverStatus();
var wiredTiger = status.wiredTiger || {};
var cache = wiredTiger.cache || {};

var bytesRead = cache["bytes read into cache"] || 0;
var bytesInCache = cache["bytes currently in the cache"] || 0;
var pagesRead = cache["pages read into cache"] || 0;
var pagesRequested = cache["pages requested from the cache"] || 0;

var hitRatio = 0;
var statusValue = "INSUFFICIENT_DATA";
var severityValue = "ADVISORY";
var message = "";

if (pagesRequested > 0) {
    hitRatio = ((pagesRequested - pagesRead) / pagesRequested) * 100;
    hitRatio = Math.round(hitRatio * 100) / 100;

    if (hitRatio < 90) {
        statusValue = "FLAGGED";
        severityValue = "CRITICAL";
        message = "Buffer cache hit ratio is " + hitRatio + "% (below 90% threshold) — instance may be under-provisioned for memory";
    } else {
        statusValue = "PASSED";
        severityValue = "OK";
        message = "Buffer cache hit ratio is " + hitRatio + "% (meets 90% threshold)";
    }
} else {
    message = "Insufficient cache activity data to compute hit ratio";
}

var result = {
    "check_name": "Buffer Cache Hit Ratio",
    "check_level": "INSTANCE",
    "status": statusValue,
    "severity": severityValue,
    "current_value": hitRatio + "%",
    "default_value": "90% threshold",
    "message": message
};

result;
