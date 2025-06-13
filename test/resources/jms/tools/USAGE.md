# ActiveMQ Artemis Bulk Management Tool

A comprehensive command-line tool for bulk operations on ActiveMQ Artemis addresses and queues with advanced pattern matching capabilities.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Command Reference](#command-reference)
- [Pattern Matching](#pattern-matching)
- [Usage Examples](#usage-examples)
- [Advanced Features](#advanced-features)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Installation

### Prerequisites
- Python 3.7+
- Access to ActiveMQ Artemis web console
- Required Python packages: `requests`

### Setup
```bash
# Install required packages
pip install requests

# Make the script executable
chmod +x tools/enhanced_bulk_manager.py

# Test connection
python tools/enhanced_bulk_manager.py --operation list
```

## Quick Start

### Basic Commands
```bash
# List all addresses
python tools/enhanced_bulk_manager.py --operation list

# Delete addresses matching a pattern
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "xml.*"

# Cleanup test data
python tools/enhanced_bulk_manager.py --operation cleanup

# Skip confirmation prompts
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "test.*" --confirm
```

## Command Reference

### General Options
```bash
python tools/enhanced_bulk_manager.py [OPTIONS]
```

| Option        | Description                        | Default     | Example                        |
| ------------- | ---------------------------------- | ----------- | ------------------------------ |
| `--host`      | Artemis host                       | `localhost` | `--host artemis.example.com`   |
| `--port`      | Artemis web port                   | `8161`      | `--port 8080`                  |
| `--username`  | Username                           | `admin`     | `--username myuser`            |
| `--password`  | Password                           | prompt      | `--password secret`            |
| `--operation` | Operation to perform               | `list`      | `--operation delete-addresses` |
| `--pattern`   | Single or comma-separated patterns | none        | `--pattern "xml.*,robot.*"`    |
| `--patterns`  | Space-separated patterns           | none        | `--patterns "xml.*" "robot.*"` |
| `--confirm`   | Skip confirmation prompts          | `false`     | `--confirm`                    |

### Operations

#### `list`
Lists all addresses in the Artemis broker.
```bash
python tools/enhanced_bulk_manager.py --operation list
```

#### `delete-addresses`
Deletes addresses matching specified patterns.
```bash
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "xml.*"
```

#### `cleanup`
Removes common test data patterns (`robot.*`, `test.*`, `modular.test.*`).
```bash
python tools/enhanced_bulk_manager.py --operation cleanup
```

## Pattern Matching

### Supported Pattern Types

#### 1. Simple Wildcards
```bash
# All addresses starting with "xml"
--pattern "xml.*"

# All addresses ending with "address"
--pattern ".*\.address$"

# All addresses containing "test"
--pattern ".*test.*"
```

#### 2. Complex Regex Patterns
```bash
# Addresses starting with xml, robot, or test
--pattern "^(xml|robot|test)\."

# Addresses with specific suffixes
--pattern ".*\.(address|queue|topic)$"

# Numeric suffixes
--pattern ".*\.[0-9]+$"
```

#### 3. Multiple Patterns

**Comma-separated:**
```bash
--pattern "xml.*,robot.*,test.*"
```

**Space-separated:**
```bash
--patterns "xml.*" "robot.*" "test.*"
```

### Pattern Examples

| Pattern         | Matches                                   | Description                  |
| --------------- | ----------------------------------------- | ---------------------------- |
| `xml.*`         | `xml.customer.address`, `xml.order.queue` | Starts with "xml"            |
| `.*\.address$`  | `order.address`, `customer.address`       | Ends with ".address"         |
| `robot\.[0-9]+` | `robot.1`, `robot.123`                    | "robot." followed by numbers |
| `^(xml\|csv)\.` | `xml.data`, `csv.export`                  | Starts with "xml." or "csv." |
| `test.*,demo.*` | `test.queue`, `demo.address`              | Multiple patterns            |

## Usage Examples

### Basic Operations

#### List All Addresses
```bash
python tools/enhanced_bulk_manager.py --operation list
```
**Output:**
```
📋 Listing All Addresses:
==================================================
🔍 Fetching addresses using Jolokia READ...
📡 Response status: 200
📊 Extracting addresses from API response...
✅ Found 34 unique addresses
📋 Addresses found:
    1. DLQ
    2. ExpiryQueue
    3. csv.customer.address
    4. xml.order.address
    ...
```

#### Delete Single Pattern

python /Users/spothana/QADocs/SNAPLOGIC_RF_EXAMPLES2/snaplogic-robotframework-examples/test/resources/jms/tools/cleanup_queue_address_script.py \
  --operation delete-all-except-system


```bash
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "xml.*"
```

#### Delete Multiple Patterns
```bash
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "xml.*,robot.*,test.*"
```

### Development Workflow

#### Clean Development Environment
```bash
# Remove all test-related addresses
python tools/enhanced_bulk_manager.py --operation cleanup

# Or be more specific
python tools/enhanced_bulk_manager.py --operation delete-addresses --patterns "robot.*" "test.*" "modular.*" "demo.*"
```

#### Environment-Specific Cleanup
```bash
# Development environment
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "dev\..*"

# Staging environment  
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "staging\..*"

# Test data cleanup
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "temp\..*,scratch\..*"
```

### Data Migration Scenarios

#### Remove Old Schema Addresses
```bash
# Remove addresses from old schema version
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "v1\..*,legacy\..*"

# Clean up after data format migration
python tools/enhanced_bulk_manager.py --operation delete-addresses --patterns "old_format.*" "deprecated.*"
```

#### Selective Environment Cleanup
```bash
# Remove specific data types
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "(xml|json|csv)\.temp\..*"

# Clean specific modules
python tools/enhanced_bulk_manager.py --operation delete-addresses --patterns "module_a.*" "module_b.*"
```

### Automation Scripts

#### Automated Cleanup Script
```bash
#!/bin/bash
# cleanup_artemis.sh

echo "🧹 Starting Artemis cleanup..."

# Remove test data
python tools/enhanced_bulk_manager.py --operation cleanup --confirm

# Remove temporary addresses
python tools/enhanced_bulk_manager.py --operation delete-addresses \
  --pattern "temp\..*,tmp\..*,scratch\..*" --confirm

# Remove old demo data
python tools/enhanced_bulk_manager.py --operation delete-addresses \
  --pattern "demo\..*,example\..*" --confirm

echo "✅ Cleanup completed!"
```

#### CI/CD Integration
```bash
# In your pipeline
python tools/enhanced_bulk_manager.py \
  --host $ARTEMIS_HOST \
  --port $ARTEMIS_PORT \
  --username $ARTEMIS_USER \
  --password $ARTEMIS_PASS \
  --operation cleanup \
  --confirm
```

## Advanced Features

### Connection Configuration

#### Different Environments
```bash
# Local development
python tools/enhanced_bulk_manager.py --host localhost --port 8161

# Remote server
python tools/enhanced_bulk_manager.py --host artemis.prod.com --port 8080

# Custom credentials
python tools/enhanced_bulk_manager.py --username myuser --password mypass
```

#### Secure Environments
```bash
# Prompt for password (more secure)
python tools/enhanced_bulk_manager.py --username admin
# Will prompt: Password: 

# Environment variables
export ARTEMIS_PASSWORD="secret"
python tools/enhanced_bulk_manager.py --password $ARTEMIS_PASSWORD
```

### Complex Pattern Matching

#### Conditional Patterns
```bash
# Addresses with numbers in specific positions
python tools/enhanced_bulk_manager.py --operation delete-addresses \
  --pattern ".*\.[0-9]{3}\.address$"

# Addresses matching specific formats
python tools/enhanced_bulk_manager.py --operation delete-addresses \
  --pattern "^(test|dev)_[0-9]{4}_.*"
```

#### Negative Patterns (Keep Everything Except)
```bash
# Keep only production addresses (remove everything else)
# Note: Use with extreme caution!
python tools/enhanced_bulk_manager.py --operation delete-addresses \
  --pattern "^(?!prod\.).*"
```

### Batch Operations

#### Large-Scale Cleanup
```bash
# Process in stages for large environments
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "xml.*" --confirm
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "csv.*" --confirm  
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "json.*" --confirm
```

## Troubleshooting

### Common Issues

#### Connection Problems
```
❌ HTTP Error: 401 Unauthorized
```
**Solution:** Check username/password
```bash
python tools/enhanced_bulk_manager.py --username admin --password admin
```

#### No Addresses Found
```
✅ Found 0 unique addresses
```
**Solutions:**
1. Check if Artemis is running
2. Verify host/port settings
3. Ensure you have proper permissions

#### Deletion Failures
```
❌ API Error: Address has queues attached
```
**Solution:** The tool automatically handles queue cleanup, but some addresses may still be in use.

### Debug Mode

#### Verbose Output
The tool provides detailed output by default:
```
🔍 Searching for addresses matching 2 pattern(s)
   [1/2] Testing pattern: 'xml.*'
      📋 Found 6 matches
         - xml.catalog.address
         - xml.config.address
         - xml.customer.address
   [2/2] Testing pattern: 'robot.*'
      📋 Found 12 matches
         - robot.csv.address
         - robot.json.address
```

#### Check Connection
```bash
# Test basic connectivity
python tools/enhanced_bulk_manager.py --operation list
```

### Error Recovery

#### Partial Deletion Failures
```
📊 Final Results:
   Addresses:   8 ✅    2 ❌
   Success Rate: 80.0%
```

**Recovery steps:**
1. Check which addresses failed
2. Verify no active consumers
3. Retry with force deletion
4. Manual cleanup via web console if needed

## Best Practices

### Safety Guidelines

#### 1. Always Test First
```bash
# List before deleting
python tools/enhanced_bulk_manager.py --operation list

# Test pattern matching
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "test.*"
# Review the list before confirming
```

#### 2. Use Confirmation
```bash
# Let the tool prompt for confirmation
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "xml.*"

# Only use --confirm in automated scripts
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "test.*" --confirm
```

#### 3. Start Small
```bash
# Test with a small subset first
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "test\.temp\..*"

# Then expand to larger patterns
python tools/enhanced_bulk_manager.py --operation delete-addresses --pattern "test\..*"
```

### Performance Optimization

#### 1. Pattern Efficiency
```bash
# More efficient (specific)
--pattern "xml\.customer\..*"

# Less efficient (broad)
--pattern ".*customer.*"
```

#### 2. Batch Processing
```bash
# Process related addresses together
python tools/enhanced_bulk_manager.py --operation delete-addresses \
  --patterns "xml.customer.*" "xml.order.*" "xml.catalog.*"
```

### Environment Management

#### 1. Environment-Specific Patterns
```bash
# Development
--pattern "dev\..*,test\..*,tmp\..*"

# Staging  
--pattern "stage\..*,staging\..*"

# Never use broad patterns in production!
```

#### 2. Backup Important Data
```bash
# Before major cleanup, export configurations
# Use Artemis management tools to backup
artemis data exp --file backup.xml
```

### Automation Best Practices

#### 1. Script Templates
```bash
#!/bin/bash
# artemis_cleanup_template.sh

set -e  # Exit on error

ARTEMIS_HOST=${ARTEMIS_HOST:-localhost}
ARTEMIS_PORT=${ARTEMIS_PORT:-8161}
ARTEMIS_USER=${ARTEMIS_USER:-admin}

echo "🎯 Cleaning up Artemis at $ARTEMIS_HOST:$ARTEMIS_PORT"

# Cleanup test data
python tools/enhanced_bulk_manager.py \
  --host $ARTEMIS_HOST \
  --port $ARTEMIS_PORT \
  --username $ARTEMIS_USER \
  --operation cleanup \
  --confirm

echo "✅ Cleanup completed successfully"
```

#### 2. CI/CD Integration
```yaml
# .github/workflows/cleanup.yml
name: Artemis Cleanup
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-python@v2
      - run: pip install requests
      - run: |
          python tools/enhanced_bulk_manager.py \
            --host ${{ secrets.ARTEMIS_HOST }} \
            --username ${{ secrets.ARTEMIS_USER }} \
            --password ${{ secrets.ARTEMIS_PASS }} \
            --operation cleanup \
            --confirm
```

## Support and Contributing

### Getting Help
- Review this documentation
- Check the command help: `python tools/enhanced_bulk_manager.py --help`
- Test with `--operation list` first
- Use specific patterns before broad ones

### Feature Requests
The tool supports:
- ✅ Multiple pattern matching
- ✅ Safe deletion with confirmation
- ✅ Automatic queue cleanup
- ✅ Detailed progress reporting
- ✅ Connection configuration
- ✅ Error handling and recovery

### Version Information
- **Version**: 1.0
- **Compatible with**: ActiveMQ Artemis 2.x+
- **Python**: 3.7+
- **Dependencies**: requests

---

**⚠️ Important:** Always test patterns on non-production environments first. The tool provides safety confirmations, but deletion operations are irreversible.

**💡 Pro Tip:** Use the `--operation list` command frequently to understand your address landscape before performing bulk operations.
