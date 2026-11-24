// MongoDB Primary Key Equivalent Check
// Verifies that all collections have proper _id indexes (MongoDB's primary key equivalent)
// Requirement: 17.1, 17.2, 17.3, 17.4 - Primary key check
// In MongoDB, every collection has an _id field that serves as the primary key.
// This check verifies _id index existence and identifies collections with
// compound _id fields (equivalent to composite primary keys).

var statusValue = "PASSED";
var severityValue = "OK";
var currentValue = "";
var message = "";

var collections = db.getCollectionNames();
var issues = [];
var checkedCount = 0;

collections.forEach(function(collName) {
    // Skip system collections
    if (collName.startsWith("system.")) {
        return;
    }

    checkedCount++;
    var indexes = db.getCollection(collName).getIndexes();
    var hasIdIndex = false;
    var idIsCompound = false;

    indexes.forEach(function(idx) {
        var keys = idx.key || {};
        if (keys._id !== undefined) {
            hasIdIndex = true;
            // Check if _id index has multiple fields (compound _id)
            var keyCount = Object.keys(keys).length;
            if (keyCount > 1) {
                idIsCompound = true;
            }
        }
    });

    // Also check if any documents use compound _id (object as _id)
    var sampleDoc = db.getCollection(collName).findOne();
    if (sampleDoc && sampleDoc._id && typeof sampleDoc._id === "object" && !(sampleDoc._id instanceof ObjectId)) {
        idIsCompound = true;
    }

    if (!hasIdIndex) {
        issues.push(collName + ": missing _id index (primary key equivalent)");
    } else if (idIsCompound) {
        issues.push(collName + ": composite _id field — single-field _id recommended");
    }
});

if (issues.length > 0) {
    statusValue = "FLAGGED";
    // Determine severity based on issue type
    var hasMissing = issues.some(function(i) { return i.indexOf("missing") >= 0; });
    severityValue = hasMissing ? "CRITICAL" : "ADVISORY";
    currentValue = issues.length + " issue(s) in " + checkedCount + " collection(s)";
    message = issues.join(" | ");
} else {
    currentValue = checkedCount + " collection(s) checked";
    message = "All collections have proper _id index (primary key equivalent) with single-field _id";
}

var result = {
    "check_name": "Primary Key Equivalent",
    "check_level": "TABLE",
    "status": statusValue,
    "severity": severityValue,
    "current_value": currentValue,
    "default_value": "Single-field _id on all collections",
    "message": message
};

result;
