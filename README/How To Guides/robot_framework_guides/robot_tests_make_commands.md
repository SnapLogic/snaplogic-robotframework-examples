# Robot Tests Execution Flow

This document describes the execution flow for SnapLogic Robot Framework tests based on the `PROJECT_SPACE_SETUP` parameter.

## Overview

The `make robot-run-all-tests` command supports two modes of operation:

- **Setup Mode** (`PROJECT_SPACE_SETUP=True`): Creates/recreates project space and Snaplex
- **Verify Mode** (`PROJECT_SPACE_SETUP=False`): Verifies existing project space and runs tests

---

## Setup Mode: PROJECT_SPACE_SETUP=True

When `PROJECT_SPACE_SETUP=True`, the system performs a complete setup of the SnapLogic environment before running tests.

**Usage:**
```bash
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True
```

### Detailed Execution Flow

```
PROJECT_SPACE_SETUP=True
│
├─ 🏗️ Phase 1: Create Project Space & Plex
│   │
│   ├─ 🚀 Initialize Robot Framework
│   │   ├─ Load .env configuration
│   │   ├─ Set up global variables
│   │   └─ Prepare test environment
│   │
│   ├─ 🔄 Run createplex Tests
│   │   │
│   │   ├─ 📋 SCENARIO A: Clean Setup (No Conflicts)
│   │   │   ├─ 🗑️ Delete existing project space (if exists)
│   │   │   ├─ ✨ Create new project space 'sl-automation-ps'
│   │   │   ├─ 📁 Create project 'sl_project'
│   │   │   ├─ 🔧 Create Snaplex in project
│   │   │   ├─ 📦 Download Snaplex configuration
│   │   │   └─ ✅ Setup completed successfully
│   │   │
│   │   └─ ⚠️ SCENARIO B: Active Groundplex Nodes Detected
│   │       │
│   │       ├─ ❌ Initial delete attempt fails
│   │       │   └─ Error: "cannot be deleted while it contains active nodes"
│   │       │
│   │       ├─ 🔍 Intelligent Error Detection
│   │       │   ├─ Parse error logs
│   │       │   └─ Identify active nodes issue
│   │       │
│   │       ├─ 🔄 Automatic Recovery Process:
│   │       │   ├─ 🛑 Stop Groundplex container
│   │       │   ├─ ⏳ Wait 60 seconds for node deregistration
│   │       │   └─ 🔁 Retry createplex tests
│   │       │
│   │       └─ ✅ Recovery Success:
│   │           ├─ 🗑️ Delete project space (now succeeds)
│   │           ├─ ✨ Create new project space
│   │           ├─ 📁 Create project
│   │           ├─ 🔧 Create Snaplex
│   │           └─ ✅ Setup completed after recovery
│   │
│   └─ 📊 Phase 1 Results:
│       ├─ Project Space: Created/Recreated
│       ├─ Project: Created
│       ├─ Snaplex: Configured
│       └─ Status: Ready for Groundplex launch
│
├─ 🚀 Phase 2: Launch & Configure Groundplex
│   │
│   ├─ 🐳 Start Groundplex Container
│   │   ├─ Pull latest Groundplex image
│   │   ├─ Start snaplogic-groundplex container
│   │   └─ Mount configuration volumes
│   │
│   ├─ ⏱️ JCC Initialization
│   │   ├─ Poll JCC status (20 attempts, 10s intervals)
│   │   ├─ Wait for JCC to be ready
│   │   └─ Verify connectivity to SnapLogic cloud
│   │
│   └─ ✅ Groundplex Status:
│       ├─ Container: Running
│       ├─ JCC: Active and connected
│       └─ Ready for test execution
│
├─ 🔧 Phase 2.1: Set Permissions (Travis CI Only)
│   │
│   ├─ 🔍 Check if running on Travis
│   │
│   └─ 📝 If Travis Detected:
│       ├─ Run set_travis_permissions.sh
│       └─ Set proper file permissions for test data
│
├─ 🧪 Phase 3: Execute User-Defined Tests
│   │
│   ├─ 🎯 Test Execution Setup
│   │   ├─ Apply user-specified TAGS filter
│   │   ├─ Set PROJECT_SPACE_SETUP=False for tests
│   │   └─ Initialize test reporting
│   │
│   ├─ 🔄 Run Test Suites
│   │   ├─ Execute tests matching TAGS
│   │   ├─ Use created project space/project
│   │   ├─ Leverage running Groundplex
│   │   └─ Generate timestamped outputs
│   │
│   └─ 📊 Test Results:
│       ├─ Output: robot_output/output-*.xml
│       ├─ Log: robot_output/log-*.html
│       ├─ Report: robot_output/report-*.html
│       └─ Status: Pass/Fail with details
│
└─ 🎉 Complete Execution Summary
    ├─ Environment: Fully configured
    ├─ Tests: Executed with results
    └─ Ready for: Next test run or cleanup
```

### Key Features of Setup Mode

| Feature | Description |
|---------|-------------|
| **Clean Slate** | Always starts with fresh project space |
| **Intelligent Recovery** | Automatically handles active node conflicts |
| **Complete Setup** | Creates all necessary SnapLogic components |
| **Error Resilience** | Retries on known failure scenarios |
| **Automated Workflow** | No manual intervention required |

### When to Use Setup Mode

- ✅ **First-time setup** of the testing environment
- ✅ **Clean environment needed** for critical tests
- ✅ **Project space corrupted** or in unknown state
- ✅ **Snaplex configuration changed** in .env file
- ✅ **CI/CD pipelines** requiring fresh environment

---

## Verify Mode: PROJECT_SPACE_SETUP=False

When `PROJECT_SPACE_SETUP=False` (default), the system verifies existing infrastructure and runs tests.

**Usage:**
```bash
# Default behavior - PROJECT_SPACE_SETUP=False is implicit
make robot-run-all-tests TAGS="oracle"

# Or explicitly set
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=False
```

### Detailed Execution Flow

```
PROJECT_SPACE_SETUP=False
│
├─ 🔍 Phase 1: Verify Project Space Exists
│   │
│   ├─ 🚀 Initialize Robot Framework
│   │   ├─ Load .env configuration
│   │   ├─ Set up global variables  
│   │   └─ Skip createplex setup
│   │
│   ├─ 🔍 Run verify_project_space_exists Test
│   │   │
│   │   ├─ 📋 SCENARIO A: Project Space Found
│   │   │   ├─ 🔎 Search for project space
│   │   │   ├─ ✅ Project space 'sl-automation-ps' found
│   │   │   ├─ 📊 Log project count and details
│   │   │   └─ ✅ Verification passed
│   │   │
│   │   └─ ❌ SCENARIO B: Project Space Missing
│   │       │
│   │       ├─ 🔍 Search for project space
│   │       │   └─ Result: NOT FOUND
│   │       │
│   │       ├─ 💥 Test Failure Generated:
│   │       │   ├─ Error: "Project space 'sl-automation-ps' is not created"
│   │       │   └─ Test marked as FAILED
│   │       │
│   │       └─ 📝 Helpful Error Instructions:
│   │           ├─ "Run 'make robot-run-all-tests' with"
│   │           └─ "PROJECT_SPACE_SETUP=True to create environment"
│   │
│   └─ 📊 Phase 1 Results:
│       ├─ Status: Pass or Fail based on verification
│       └─ Continue: Only if project space exists
│
├─ 🚀 Phase 2: Launch Groundplex (If Phase 1 Passed)
│   │
│   ├─ 🐳 Start Groundplex Container
│   │   ├─ Pull latest Groundplex image
│   │   ├─ Start snaplogic-groundplex container
│   │   └─ Mount configuration volumes
│   │
│   ├─ ⏱️ JCC Initialization
│   │   ├─ Poll JCC status (20 attempts, 10s intervals)
│   │   ├─ Wait for JCC to be ready
│   │   └─ Verify connectivity to SnapLogic cloud
│   │
│   └─ ✅ Groundplex Status:
│       ├─ Container: Running
│       ├─ JCC: Active and connected
│       └─ Ready for test execution
│
├─ 🧪 Phase 3: Execute User-Defined Tests
│   │
│   ├─ 🔍 Additional Project Verification
│   │   ├─ 🚀 Run verify_project_exists tests
│   │   ├─ ✅ Confirm project accessibility
│   │   └─ 📁 Validate project structure
│   │
│   ├─ 🎯 Execute Target Tests
│   │   ├─ 🚀 Initialize Robot Framework for user tests
│   │   ├─ 🏷️ Filter tests by TAGS (e.g., "oracle")
│   │   ├─ 🔄 Run filtered test suites
│   │   ├─ 📡 Use existing project space/project
│   │   └─ 📊 Generate timestamped reports
│   │
│   └─ 📊 Test Results:
│       ├─ Output: robot_output/output-*.xml
│       ├─ Log: robot_output/log-*.html
│       ├─ Report: robot_output/report-*.html
│       └─ Status: Pass/Fail with details
│
└─ 🎉 Execution Complete
    ├─ Environment: Used existing setup
    ├─ Tests: Executed with results
    └─ Ready for: Review or next test run
```

### Key Features of Verify Mode

| Feature | Description |
|---------|-------------|
| **Fast Execution** | Skips setup, goes straight to testing |
| **Safety Checks** | Verifies prerequisites before running tests |
| **Read-Only Setup** | No modifications to SnapLogic cloud environment |
| **Fail-Fast** | Stops immediately if project space missing |
| **Clear Guidance** | Provides exact commands to fix issues |

### When to Use Verify Mode

- ✅ **Subsequent test runs** after initial setup
- ✅ **Quick test iterations** during development
- ✅ **Stable environment** already configured
- ✅ **Production testing** where setup shouldn't change
- ✅ **Debugging existing tests** without environment changes

---

## Usage Examples

### Basic Test Execution

```bash
# First time setup - create everything fresh
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True

# Subsequent runs - use existing setup
make robot-run-all-tests TAGS="oracle"

# Multiple tags
make robot-run-all-tests TAGS="oracle minio" PROJECT_SPACE_SETUP=True

# Explicitly set to False (same as default)
make robot-run-all-tests TAGS="postgres" PROJECT_SPACE_SETUP=False
```

### CI/CD Pipeline Usage

```bash
# CI/CD typically needs fresh environment
make robot-run-all-tests TAGS="smoke" PROJECT_SPACE_SETUP=True

# Development environment with stable setup
make robot-run-all-tests TAGS="integration"
```

---

## Comparison Table

| **Aspect** | **Setup Mode (True)** | **Verify Mode (False)** |
|------------|----------------------|------------------------|
| **Phase 1 Action** | Delete/Create/Setup project space & plex | Verify existence only |
| **Error Handling** | Intelligent recovery for active nodes | Fail with clear instructions |
| **Groundplex** | Always launches fresh | Launches if verification passes |
| **Phase 3 Extra** | Direct test execution | Additional project verification |
| **Cloud Modifications** | Yes - creates/modifies resources | No - read-only checks |
| **Use Case** | Fresh setup/CI/CD/clean environment | Development/debugging/stable env |
| **Execution Time** | Longer (3-5 minutes) | Faster (1-2 minutes) |
| **Prerequisites** | Valid .env configuration | Existing project space & project |
| **Risk Level** | Higher - modifies cloud resources | Lower - read-only operations |

---

## Troubleshooting

### Common Scenarios and Solutions

| Scenario | Error Message | Solution |
|----------|--------------|----------|
| **Active Nodes** | "cannot be deleted while it contains active nodes" | Automatically handled in Setup Mode |
| **Missing Project Space** | "Project space 'sl-automation-ps' is not created" | Run with `PROJECT_SPACE_SETUP=True` |
| **JCC Failed to Start** | "JCC failed to start after 20 attempts" | Check Groundplex logs, restart Docker |
| **Invalid Credentials** | "401 Unauthorized" | Verify .env file credentials |
| **Network Issues** | "Connection timeout" | Check network connectivity, proxy settings |

### Debug Commands

```bash
# Check Groundplex status
make groundplex-status

# View Groundplex logs
docker logs snaplogic-groundplex

# Restart Groundplex
make restart-groundplex

# Clean start everything
make clean-start
```

---




