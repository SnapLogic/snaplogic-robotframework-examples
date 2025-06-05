# Robot Tests Execution Flow

This document describes the execution flow for SnapLogic Robot Framework tests based on the `PROJECT_SPACE_SETUP` parameter.

## Overview

The `make robot-run-all-tests` command supports two modes of operation:

- **Setup Mode** (`PROJECT_SPACE_SETUP=True`): Creates/recreates project space and Snaplex
- **Verify Mode** (`PROJECT_SPACE_SETUP=False`): Verifies existing project space and runs tests

---

## Setup Mode: PROJECT_SPACE_SETUP=True [Create ProjectSpace and Launch Groundplex]

**Usage:**
```bash
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True
```

**Execution Flow:**

```
PROJECT_SPACE_SETUP=True
│
├─ 🏗️  Phase 1: Run createplex tests
│   │
│   ├─ 🚀 Initialize Robot Framework
│   │
│   ├─ 📋 CASE 1: Normal Flow
│   │   ├─ 🗑️  Delete ProjectSpace
│   │   ├─ ✨ Create Project Space  
│   │   └─ 📁 Create Project
│   │
│   └─ ⚠️  CASE 2: Active Nodes Detected
│       │
│       ├─ ❌ Delete ProjectSpace → FAILS (active nodes)
│       │
│       ├─ 🔄 Error Recovery Process:
│       │   ├─ 🛑 Stop Groundplex
│       │   ├─ ⏳ Wait 60s for deregistration
│       │   └─ 🔁 Retry createplex tests
│       │
│       └─ ✅ Retry Success:
│           ├─ 🗑️  Delete ProjectSpace → NOW SUCCEEDS
│           ├─ ✨ Create Project Space
│           └─ 📁 Create Project
│
├─ 🚀 Phase 2: Launch Groundplex
│   │
│   ├─ 🐳 Start snaplogic-groundplex container
│   ├─ ⏱️  Wait for JCC to be ready
│   └─ ✅ Groundplex running and ready
│
└─ 🧪 Phase 3: Run User Tests
    │
    ├─ 🎯 Execute Target Tests
    │   ├─ 🚀 Initialize Robot Framework for user tests
    │   ├─ 🏷️  Filter tests by TAGS (e.g., "oracle")
    │   ├─ 🔄 Run filtered test suites
    │   └─ 📊 Generate test reports
    │
    └─ 🎉 Execution Complete
```

**Key Features:**
- **Intelligent Error Recovery**: Automatically handles active node conflicts
- **Clean Environment**: Ensures fresh project space setup
- **Complete Setup**: Creates all necessary SnapLogic components

---

## USAGE


### 1. Basic Test Run

```bash

# Run with project space setup (first time setup or when ever user needs to set up project space and create plex)
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True
make robot-run-all-tests TAGS="oracle minio" PROJECT_SPACE_SETUP=True #mutiple tags

# Run Oracle tests with out the need of Project Space SetUp (Default value for PROJECT_SPACE_SETUP is False)
make robot-run-all-tests TAGS="oracle" 


```

**Execution Flow:**

```
PROJECT_SPACE_SETUP=False
│
├─ 🔍 Phase 1: Verify Project Space Exists
│   │
│   ├─ 🚀 Initialize Robot Framework
│   │
│   ├─ ⏩ Skip createplex setup (PROJECT_SPACE_SETUP is not True)
│   │
│   ├─ 📋 CASE 1: Project Space Found
│   │   ├─ 🔎 Check if project space exists
│   │   ├─ ✅ Project space 'sl-automtaion-ps' found
│   │   └─ 📊 Log project count and details
│   │
│   └─ ❌ CASE 2: Project Space Missing
│       │
│       ├─ 🔍 Search for project space → NOT FOUND
│       │
│       ├─ 💥 Test Failure:
│       │   └─ "Project space 'sl-automtaion-ps' is not created"
│       │
│       └─ 📝 Helpful Error Message:
│           └─ "Run 'make robot-run-all-tests' with PROJECT_SPACE_SETUP=True"
│
├─ 🚀 Phase 2: Launch Groundplex
│   │
│   ├─ 🐳 Start snaplogic-groundplex container
│   ├─ ⏱️  Wait for JCC to be ready
│   └─ ✅ Groundplex running and ready
│
├─ 🧪 Phase 3: Run User Tests
│   │
│   ├─ 🔍 Additional Project Verification
│   │   ├─ 🚀 Run verify_project_exists tests
│   │   └─ ✅ Confirm project accessibility
│   │
│   └─ 🎯 Execute Target Tests
│       ├─ 🚀 Initialize Robot Framework for user tests
│       ├─ 🏷️  Filter tests by TAGS (e.g., "oracle")
│       ├─ 🔄 Run filtered test suites
│       └─ 📊 Generate test reports
│
└─ 🎉 Execution Complete
```

**Key Features:**
- **Fast Execution**: Skips setup, goes straight to testing
- **Safety Checks**: Verifies prerequisites before running tests
- **Read-Only**: No modifications to SnapLogic cloud environment

---

## Comparison Table

| **Aspect**             | **Setup Mode (True)**   | **Verify Mode (False)**         |
| ---------------------- | ----------------------- | ------------------------------- |
| **Phase 1 Action**     | Create/Delete/Setup     | Verify Existence Only           |
| **Error Handling**     | Intelligent Recovery    | Fail with Instructions          |
| **Phase 3 Extra Step** | None                    | Additional project verification |
| **Risk Level**         | Higher (modifies cloud) | Lower (read-only checks)        |
| **Use Case**           | Fresh setup/recreation  | Using existing environment      |
| **Execution Time**     | Longer (3-5 min)        | Faster (1-2 min)                |
| **Prerequisites**      | None                    | Existing project space          |

---


## Troubleshooting

### Common Scenarios

1. **Active Nodes Error**: Automatically handled in Setup Mode
2. **Missing Project Space**: Clear error message in Verify Mode

---

## 📚 Explore More Documentation

💡 **Need help finding other guides?** Check out our **[📖 Complete Documentation Reference](../../reference.md)** for a comprehensive overview of all available tutorials, how-to guides, and quick start paths. It's your one-stop navigation hub for the entire SnapLogic Test Framework documentation!



