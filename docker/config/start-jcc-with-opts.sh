#!/bin/bash
# Wrapper script to start JCC with custom Java options

echo "Starting JCC with custom Java options for Salesforce HTTP support..."

# Export the Java options as JCC expects them
export JCC_SERVER_HEAP_SIZE="${JCC_SERVER_HEAP_SIZE:-15693M}"
export JCC_HEAP_MIN="${JCC_HEAP_MIN:-512m}"

# Add our custom options to the JVM arguments
export JCC_EXTRA_OPTS="-Dcom.snaplogic.snaps.salesforce.force.http=true -Dhttp.protocols=http,https"

# Log what we're doing
echo "JCC_EXTRA_OPTS: $JCC_EXTRA_OPTS"

# Start JCC with our custom options
cd /opt/snaplogic/bin

# Modify the jcc.sh call to include our options
./jcc.sh start

# Keep the container running
echo "JCC started. Tailing logs..."
tail -f /opt/snaplogic/run/log/jcc.log
