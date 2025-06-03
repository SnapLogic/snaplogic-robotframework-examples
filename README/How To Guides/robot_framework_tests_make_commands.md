

# Robot Framework Make Commands Guide

This document provides a comprehensive guide to the Robot Framework make commands available in the automation framework, explaining when and how to use each command based on your testing requirements.

---

## Overview

The framework provides two primary `make` commands for running tests:

1. **`robot-run-all-tests`** – Performs full setup and test execution (ideal for first-time use).
2. **`robot-run-tests`** – Executes tests with optional setup (ideal for iterative development and CI).

---

## Key Environment Variable: `PROJECT_SPACE_SETUP`

This variable controls whether setup tasks (e.g., project space and project creation) are performed before running tests.

- `True`: Sets up the environment (e.g., project space, project).
- `False`: Skips setup and assumes infrastructure is already provisioned.

---

## Command 1: `robot-run-all-tests`

### Purpose

Executes a full end-to-end workflow:
- Creates required infrastructure (plex, project space, project).
- Starts necessary services.
- Runs the tests.

### When to Use

- First-time execution
- Environment refresh
- CI pipelines requiring full setup

### Prerequisites

- Permissions for creating SnapLogic resources

### Usage Examples

```bash
make robot-run-all-tests TAGS="oracle"
make robot-run-all-tests TAGS="oracle,database"
```

### Command Logic

```makefile
robot-run-all-tests: check-env
	@echo ":========= [Phase 1] Running createplex tests ========================================="
	$(MAKE) robot-run-tests TAGS="createplex" PROJECT_SPACE_SETUP=True

	@echo ":========== [Phase 2] Computing and starting containers using COMPOSE_PROFILES... =========="
	$(MAKE) start-services
	
	@echo ":========== [Phase 3] Running user-defined robot tests with PROJECT_SPACE_SETUP=False... =========="
	$(MAKE) robot-run-tests TAGS="$(TAGS)" PROJECT_SPACE_SETUP=False
```

### Execution Phases

- **Phase 1: Infrastructure Setup**
  - Runs `createplex` tests with setup enabled.
- **Phase 2: Service Initialization**
  - Starts services based on `docker-compose` profiles.
- **Phase 3: Test Execution**
  - Runs actual test cases with setup disabled.

---

## Command 2: `robot-run-tests`

### Purpose

Executes tests with configurable setup — useful for development workflows and reruns.

### When to Use

- Local test runs
- Iterative development
- Tests against already-set-up environments

### Usage Examples

```bash
make robot-run-tests TAGS="minio"
make robot-run-tests TAGS="minio" PROJECT_SPACE_SETUP=True
make robot-run-tests TAGS="minio,storage"
make robot-run-tests TAGS="oracle" PROJECT_SPACE_SETUP=True
```

### Command Logic

```makefile
robot-run-tests: check-env
	@echo "🔧 Starting Robot Framework tests..."
	$(eval INCLUDES=$(foreach arg,$(TAGS),--include $(arg)))
	$(eval PROJECT_SPACE_SETUP_VAL=$(if $(PROJECT_SPACE_SETUP),$(PROJECT_SPACE_SETUP),False))
	docker compose exec -w /app/test tools robot \
		-G $(DATE) \
		--timestampoutputs \
		--variable PROJECT_SPACE_SETUP:$(PROJECT_SPACE_SETUP_VAL) \
		--variable TAGS:"$(TAGS)" \
		$(INCLUDES) \
		--outputdir robot_output suite/
```

### Key Features

- **Tag Filtering**: Dynamically includes test tags using `--include`.
- **Conditional Setup**: Skips or performs setup based on env variable.
- **Timestamped Output**: Adds traceability via `--timestampoutputs`.
- **Modular Configuration**: Customizable via `make` parameters.

---

## Usage Scenarios

### 1. Tests Without Infrastructure Setup

```bash
make robot-run-tests TAGS="minio"
```

- Skips project setup (`PROJECT_SPACE_SETUP=False`)
- Useful when infra already exists

### 2. Tests With Setup

```bash
make robot-run-tests TAGS="minio" PROJECT_SPACE_SETUP=True
```

- Creates project space and project
- Assumes plex is already created

### 3. Full Setup for Fresh Environment

```bash
make robot-run-all-tests TAGS="oracle"
```

- Creates plex, project space, project
- Starts services and runs tests

---

## Decision Matrix

| Scenario             | Command               | `PROJECT_SPACE_SETUP` | Use Case                                    |
| -------------------- | --------------------- | --------------------- | ------------------------------------------- |
| Fresh Environment    | `robot-run-all-tests` | Managed internally    | Complete setup (first-time or full refresh) |
| Infra Already Exists | `robot-run-tests`     | `False` (default)     | Quick test execution                        |
| Setup Project Only   | `robot-run-tests`     | `True` (explicit)     | Skips plex creation                         |

---

## Best Practices

1. **First-Time Setup** – Use `robot-run-all-tests`
2. **Iterative Testing** – Use `robot-run-tests` with `PROJECT_SPACE_SETUP=False`
3. **Partial Refresh** – Use `robot-run-tests` with `PROJECT_SPACE_SETUP=True`
4. **CI/CD** – Automate using `robot-run-all-tests` for clean test environments

---

## Troubleshooting Tips

- **Tests Fail Due to Infra** – Use `robot-run-all-tests`
- **Conflicts in Setup** – Manually override `PROJECT_SPACE_SETUP`
- **Missing Services** – Verify `start-services` started all dependencies

---

## Environment Variables Summary

| Variable              | Default          | Description                       |
| --------------------- | ---------------- | --------------------------------- |
| `TAGS`                | None             | Comma-separated test tags         |
| `PROJECT_SPACE_SETUP` | `False`          | Enables or disables project setup |
| `DATE`                | Current datetime | Used for timestamping test output |

---

*End of Guide*