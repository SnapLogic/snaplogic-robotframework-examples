# =============================================================================
# Makefile for Snaplogic Robot Framework Automation Framework
# -----------------------------------------------------------------------------
# This Makefile provides commands for:
# - Building and launching Docker containers (Groundplex, Oracle, MinIO, etc.)
# - Running Robot Framework tests in a structured multi-phase approach
# - Performing static analysis and formatting of Robot Framework files
# - Environment validation and cleanup
# -----------------------------------------------------------------------------
# Default target
# =============================================================================
.DEFAULT_GOAL := robot-run-tests

# -----------------------------------------------------------------------------
# Declare phony targets (not associated with real files)
# -----------------------------------------------------------------------------
.PHONY: robot-run-tests snaplogic-start-services snaplogic-stop snaplogic-build-tools check-env \
        clean-start launch-groundplex oracle-start end-to-end-workflow-execution \
        robotidy robocop lint list-profiles groundplex-status \
        start-s3-emulator stop-s3-emulator run-s3-demo

# -----------------------------------------------------------------------------
# Global Variables
# -----------------------------------------------------------------------------
DATE := $(shell date +'%Y-%m-%d-%H-%M')  # Used to tag Robot output
SHELL = /bin/bash

# Docker Compose profiles to be used (can be overridden by CLI)
# COMPOSE_PROFILES ?= gp,oracle-dev,postgres-dev,minio-dev
COMPOSE_PROFILES ?= tools,oracle-dev,minio,postgres-dev

# =============================================================================
#  🛠️ snaplogic tools lifecycle
# 📦 Build tools container image 
# =============================================================================
snaplogic-build-tools: snaplogic-stop
	@echo "Building image..."
	docker compose build --no-cache tools

# =============================================================================
# ✅ Validate presence of the required .env file
# =============================================================================
check-env:
	@if [ -f ".env" ]; then \
		echo "✅ Found .env file at: .env"; \
	else \
		echo "❌ Error: .env file not found at .env"; \
		echo "Please ensure .env file exists in project root."; \
		echo "Current directory: $(pwd)"; \
		echo "Files in current directory: $(ls -la | grep -E '\.env')"; \
		exit 1; \
	fi

# =============================================================================
# 🚀 Start services using Docker Compose with selected profiles
# =============================================================================
start-services:
	@echo ":[Phase 2] Starting containers using compose profiles: $(COMPOSE_PROFILES)..."
	COMPOSE_PROFILES=$(COMPOSE_PROFILES) docker compose up -d
	@echo "⏳ Waiting for services to stabilize..."
	@sleep 30

# =============================================================================
#  Create project space, Create Plex in Project Space, and launch Groundplex
# =============================================================================
createplex-launch-groundplex:
	@echo ":========= Running createplex tests to create plex in Proejctspace ========================================="
	$(MAKE) robot-run-tests TAGS="createplex" PROJECT_SPACE_SETUP=True

	@echo ":========== [Phase 2] Computing and starting containers using COMPOSE_PROFILES... =========="
	$(MAKE) launch-groundplex

	${MAKE} groundplex-status

# =============================================================================
# 🧪 End-to-End Robot Test Workflow (including environment setup)
# =============================================================================
robot-run-all-tests: check-env
	@PROJECT_SPACE_SETUP_ACTUAL=$${PROJECT_SPACE_SETUP:-False}; \
	echo ":========== [Phase 1] Create project space and create plex inside project space =========="; \
	if [ "$$PROJECT_SPACE_SETUP_ACTUAL" = "True" ]; then \
		echo ":========= [Phase 1] Running createplex tests ========================================="; \
		$(MAKE) robot-run-tests TAGS="createplex" PROJECT_SPACE_SETUP=True || { \
			echo "❌ createplex test failed, checking if error is due to active Snaplex nodes..."; \
			if ls robot_output/log-*.html 2>/dev/null | head -1 | xargs grep -q "cannot be deleted while it contains active nodes" 2>/dev/null; then \
				echo "🛑 Active Groundplex nodes detected — killing Groundplex and retrying to create project space and plex..."; \
				$(MAKE) stop-groundplex; \
				echo "⏳ Waiting 60 seconds for nodes to deregister from SnapLogic Cloud..."; \
				sleep 60; \
				$(MAKE) robot-run-tests TAGS="createplex" PROJECT_SPACE_SETUP=True || exit 1; \
			else \
				echo "❌ createplex test failed for a different reason."; \
				exit 1; \
			fi; \
		}; \
	else \
		echo "⏩ Skipping createplex setup (PROJECT_SPACE_SETUP is not True)"; \
		echo ":========== [Phase 1.1] Verifying if project space exists =========="; \
		$(MAKE) robot-run-tests TAGS="verify_project_space_exists" PROJECT_SPACE_SETUP=False; \
	fi; \
	\
	echo ":========== [Phase 2] Computing and starting containers using COMPOSE_PROFILES... =========="; \
	$(MAKE) launch-groundplex; \
	\
	echo ":========== [Phase 3] Running user-defined robot tests... =========="; \
	$(MAKE) robot-run-tests TAGS="$(TAGS)" PROJECT_SPACE_SETUP=False
	
	
# =============================================================================
# 🧪 Run Robot Framework tests with optional tags
#   → usage: make robot-run-tests TAGS="oracle,minio" PROJECT_SPACE_SETUP=True
# =============================================================================
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

# =============================================================================
# 🔄 Build & Start snaplogic tools container
# =============================================================================
snaplogic-start-services: snaplogic-stop snaplogic-build-tools
	@echo ":==========starting services/containers using COMPOSE_PROFILES... =========="
	$(MAKE) start-services
	

# =============================================================================
# 🧹 Stop all snaplogic containers and clean up
# =============================================================================
snaplogic-stop:
	echo "Stopping snaplogic App..."
	echo "Stopping any containers connected to snaplogic-network..."
	docker ps -a --filter network=snaplogic-network --format "{{.ID}}" | xargs -r docker stop || true
	echo "Removing any stopped containers..."
	docker container prune -f || true
	echo "Running docker compose down..."
	docker compose down --remove-orphans
	docker-compose --profile tools down --volumes --remove-orphans
	echo "Ensuring snaplogic-network is removed..."
	docker network rm snaplogic-network 2>/dev/null || true

# =============================================================================
# 🧹 Clean restart of all relevant services and DB
# =============================================================================
clean-start: snaplogic-build-tools snaplogic-start-tools oracle-start
	@echo "You should be good to go"

# =============================================================================
# 🚀 Launch SnapLogic Groundplex container and validate status
# =============================================================================
launch-groundplex:
	@echo "Launching Groundplex..."
	docker compose  --profile gp up -d snaplogic-groundplex
	make groundplex-status

# =============================================================================
# 🔁 Poll for Groundplex JCC readiness inside container
# =============================================================================
groundplex-status:
	@echo "🔁 Checking Snaplex JCC status in snaplogic-groundplex container (20 attempts, 10s interval)..."
	@attempt=1; \
	while [ $$attempt -le 20 ]; do \
		echo "⏱️ Attempt $$attempt..."; \
		container_status=$$(docker inspect -f '{{.State.Status}}' snaplogic-groundplex 2>/dev/null); \
		if [ "$$container_status" != "running" ]; then \
			echo "⚠️  snaplogic-groundplex is not running (status: $$container_status). Retrying in 10s..."; \
			exit_code=$$(docker inspect -f '{{.State.ExitCode}}' snaplogic-groundplex 2>/dev/null); \
			echo "🔎 Exit code: $$exit_code"; \
			echo "🪵 Last 5 log lines from snaplogic-groundplex:"; \
			docker logs --tail 5 snaplogic-groundplex 2>/dev/null || echo "⚠️  Could not fetch logs."; \
		else \
			if docker exec snaplogic-groundplex /bin/bash -c "cd /opt/snaplogic/bin && sh jcc.sh status"; then \
				echo "✅ JCC is running."; \
				exit 0; \
			else \
				echo "❌ JCC not running inside container. Retrying in 10s..."; \
			fi; \
		fi; \
		sleep 10; \
		attempt=$$((attempt + 1)); \
	done; \
	echo "❌ JCC failed to start after 20 attempts."; \
	exit 1


# =============================================================================
# 🛑 Kill Snaplex JCC and shutdown groundplex container (with retries)
# =============================================================================
stop-groundplex:
	@echo "🛑 Attempting to stop JCC inside snaplogic-groundplex container..."
	docker exec snaplogic-groundplex /bin/bash -c "cd /opt/snaplogic/bin && sh jcc.sh stop" || true

	@echo "🔁 Waiting for JCC to fully shut down (up to 20 attempts, 10s interval)..."
	@attempt=1; \
	while [ $$attempt -le 20 ]; do \
		echo "⏱️ Attempt $$attempt..."; \
		container_status=$$(docker inspect -f '{{.State.Status}}' snaplogic-groundplex 2>/dev/null); \
		if [ "$$container_status" != "running" ]; then \
			echo "✅ Container is already stopped."; \
			break; \
		else \
			status=$$(docker exec snaplogic-groundplex /bin/bash -c "cd /opt/snaplogic/bin && sh jcc.sh status" 2>&1); \
			echo "🔍 JCC Status: $$status"; \
			echo "$$status" | grep -q "PID file not found" && break; \
			echo "⌛ JCC still shutting down. Retrying in 10s..."; \
		fi; \
		sleep 10; \
		attempt=$$((attempt + 1)); \
	done; \
	if [ $$attempt -gt 20 ]; then \
		echo "❌ JCC failed to stop cleanly after 20 attempts."; \
		exit 1; \
	else \
		echo "✅ JCC shutdown confirmed."; \
	fi

	@echo "🧹 Bringing down container using Docker Compose profile 'gp'..."
	docker compose --profile gp down --remove-orphans

	@echo "✅ Groundplex successfully stopped and cleaned up."

# =============================================================================
# 🛢️ Start Oracle DB container
# =============================================================================
oracle-start:
	@echo "Starting Oracle..."
	docker compose --profile oracle-dev up -d oracle-db

# =============================================================================
# 🛢️ Start Postgres DB container
# =============================================================================
postgres-start:
	@echo "Starting Postgres..."
	docker compose --profile postgres-dev up -d postgres-db


# =============================================================================
# 🧽 Format Robot files using Robotidy
# =============================================================================
robotidy:
	@echo "✨ Running Robotidy to auto-format .robot files..."
	@robotidy test/

# =============================================================================
# 🔍 Run Robocop for static lint checks
# =============================================================================
robocop:
	@echo "🔍 Running Robocop for lint checks..."
	@robocop test/

# =============================================================================
# 🧼 Run both formatter and linter
# =============================================================================
lint: robotidy robocop
	@echo "✅ Linting and formatting completed."

# =============================================================================
# 📁 Ensure required config directory exists
# =============================================================================
ensure-config-dir:
	mkdir -p ./test/.config

# =============================================================================
# ☁️ Start local MinIO S3-compatible emulator
# =============================================================================
start-s3-emulator:
	@echo "Starting Minio..."
	docker compose --profile minio-dev up -d minio

# =============================================================================
# ⛔ Stop local MinIO S3 emulator
# =============================================================================
stop-s3-emulator:
	@echo "Stopping Minio..."
	docker compose stop minio

# =============================================================================
# 🧪 Run S3 demo Python script using MinIO credentials
# =============================================================================
run-s3-demo:
	@echo "Running minio_demo.py script..."
	python3 test/suite/test_data/python_helper_files/minio_demo.py \
		--endpoint http://localhost:9000 \
		--access-key minioadmin \
		--secret-key minioadmin \
		--bucket demo-bucket2
