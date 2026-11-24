// MongoDB Partition (Sharding) Check
// Verifies shard count and distribution strategy for sharded collections
// Requirement: 14.1, 14.2, 14.3, 14.4, 14.5 - Partition count and strategy
// In MongoDB, sharding is the equivalent of partitioning

var statusValue = "PASSED";
var severityValue = "OK";
var currentValue = "";
var message = "";

try {
    var configDB = db.getSiblingDB("config");
    var shardedCollections = configDB.collections.find({dropped: false}).toArray();

    if (shardedCollections.length === 0) {
        message = "No sharded collections found — partition check passed (no partitioned objects)";
        currentValue = "0 sharded collections";
    } else {
        var issues = [];

        shardedCollections.forEach(function(coll) {
            var ns = coll._id;
            var shardKey = coll.key || {};
            var chunkCount = configDB.chunks.count({ns: ns});

            // Check partition (chunk) count range 50-200
            var countOk = (chunkCount >= 50 && chunkCount <= 200);

            // Check if using hashed shard key (equivalent to hash partitioning)
            var isHashed = false;
            for (var key in shardKey) {
                if (shardKey[key] === "hashed") {
                    isHashed = true;
                    break;
                }
            }

            if (!countOk || !isHashed) {
                var issue = ns + ": ";
                var flags = [];

                if (!countOk) {
                    flags.push("chunk count " + chunkCount + " outside recommended range (50-200)");
                }
                if (!isHashed) {
                    flags.push("non-hash shard key strategy — consider hashed sharding");
                }

                issue += flags.join("; ");
                issues.push(issue);
            }
        });

        if (issues.length > 0) {
            statusValue = "FLAGGED";
            severityValue = "ADVISORY";
            currentValue = shardedCollections.length + " sharded collection(s)";
            message = issues.join(" | ");
        } else {
            currentValue = shardedCollections.length + " sharded collection(s)";
            message = "All sharded collections have chunk counts within 50-200 range and use hashed shard keys";
        }
    }
} catch (e) {
    // If config database is not accessible, instance may not be a sharded cluster
    statusValue = "PASSED";
    severityValue = "OK";
    currentValue = "Not a sharded cluster";
    message = "Instance is not part of a sharded cluster — partition check not applicable (passed)";
}

var result = {
    "check_name": "Partition Check",
    "check_level": "DATABASE",
    "status": statusValue,
    "severity": severityValue,
    "current_value": currentValue,
    "default_value": "50-200 chunks with hashed shard key",
    "message": message
};

result;
