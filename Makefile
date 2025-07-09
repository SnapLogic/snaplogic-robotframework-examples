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
.PHONY: robot-run-tests robot-run-all-tests snaplogic-start-services snaplogic-stop snaplogic-build-tools \
        snaplogic-stop-tools check-env clean-start launch-groundplex oracle-start oracle-stop \
        postgres-start postgres-stop mysql-start mysql-stop sqlserver-start sqlserver-stop \
        teradata-start teradata-stop \
        robotidy robocop lint groundplex-status stop-groundplex \
        start-s3-emulator stop-s3-emulator run-s3-demo ensure-config-dir \
        activemq-start activemq-stop activemq-status activemq-setup run-jms-demo \
        start-services createplex-launch-groundplex \
		rebuild-tools-with-updated-requirements

# -----------------------------------------------------------------------------
# Global Variables
# -----------------------------------------------------------------------------
DATE := $(shell date +'%Y-%m-%d-%H-%M')  # Used to tag Robot output
SHELL = /bin/bash

# Docker compose file location
DOCKER_COMPOSE_FILE := docker/docker-compose.yml
# Docker compose command with env file
DOCKER_COMPOSE := docker compose --env-file .env -f $(DOCKER_COMPOSE_FILE)

# Docker Compose profiles to be used (can be overridden by CLI)
# COMPOSE_PROFILES ?= gp,oracle-dev,postgres-dev,minio-dev
COMPOSE_PROFILES ?= tools,oracle-dev,minio,postgres-dev,mysql-dev,sqlserver-dev

# =============================================================================
#  🛠️ snaplogic tools lifecycle
# 📦 Build tools container image 
# =============================================================================
snaplogic-build-tools: snaplogic-stop-tools
	@echo "Building image..."
	$(DOCKER_COMPOSE) build --no-cache tools

snaplogic-stop-tools:
	@echo "Stopping tools container..."
	$(DOCKER_COMPOSE) stop tools || true
	$(DOCKER_COMPOSE) rm -f tools || true

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
	COMPOSE_PROFILES=$(COMPOSE_PROFILES) $(DOCKER_COMPOSE) up -d
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
#  → usage if user want to delete the projectspace(if exists) and create a clean project space add the flag PROJECT_SPACE_SETUP=True
#.   make robot-run-all-tests TAGS="oracle,minio" PROJECT_SPACE_SETUP=True
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
	$(DOCKER_COMPOSE) exec -w /app/test tools robot \
		-G $(DATE) \
		--timestampoutputs \
		--variable PROJECT_SPACE_SETUP:$(PROJECT_SPACE_SETUP_VAL) \
		--variable TAGS:"$(TAGS)" \
		$(INCLUDES) \
		--outputdir robot_output suite/

# =============================================================================
# 🔄 Build & Start snaplogic services in compose profile 
# =============================================================================
snaplogic-start-services: 
	@echo ":==========starting services/containers using COMPOSE_PROFILES... =========="
	COMPOSE_PROFILES=$(COMPOSE_PROFILES) $(DOCKER_COMPOSE) up -d
	@echo "⏳ Waiting for services to stabilize..."
	@sleep 30
	

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
	$(DOCKER_COMPOSE) down --remove-orphans
	$(DOCKER_COMPOSE) --profile tools down --volumes --remove-orphans
	echo "Ensuring snaplogic-network is removed..."
	docker network rm snaplogic-network 2>/dev/null || true

# =============================================================================
# 🧹 Clean restart of all relevant services and DB
# =============================================================================
clean-start: snaplogic-stop snaplogic-start-services launch-groundplex
	@echo "You should be good to go"

# =============================================================================
# 🚀 Launch SnapLogic Groundplex container and validate status
# =============================================================================
launch-groundplex:
	@echo "Launching Groundplex..."
	$(DOCKER_COMPOSE) --profile gp up -d snaplogic-groundplex
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
	$(DOCKER_COMPOSE) --profile gp down --remove-orphans

	@echo "✅ Groundplex successfully stopped and cleaned up."

# =============================================================================
# 🛢️ Start Oracle DB container
# =============================================================================
oracle-start:
	@echo "Starting Oracle..."
	$(DOCKER_COMPOSE) --profile oracle-dev up -d oracle-db

# =============================================================================
# ⛔ Stop Oracle DB container and clean up volumes
# =============================================================================
oracle-stop:
	@echo "Stopping Oracle DB container..."
	$(DOCKER_COMPOSE) stop oracle-db || true
	@echo "Removing Oracle container and volumes..."
	$(DOCKER_COMPOSE) rm -f -v oracle-db || true
	@echo "Cleaning up Oracle volumes..."
	docker volume rm $(docker volume ls -q | grep oracle) 2>/dev/null || true
	@echo "✅ Oracle stopped and cleaned up."

# =============================================================================
# 🛢️ Start Postgres DB container
# =============================================================================
postgres-start:
	@echo "Starting Postgres..."
	$(DOCKER_COMPOSE) --profile postgres-dev up -d postgres-db

# =============================================================================
# ⛔ Stop Postgres DB container and clean up volumes
# =============================================================================
postgres-stop:
	@echo "Stopping Postgres DB container..."
	$(DOCKER_COMPOSE) stop postgres-db || true
	@echo "Removing Postgres container and volumes..."
	$(DOCKER_COMPOSE) rm -f -v postgres-db || true
	@echo "Cleaning up Postgres volumes..."
	docker volume rm $(docker volume ls -q | grep postgres) 2>/dev/null || true
	@echo "✅ Postgres stopped and cleaned up."

# =============================================================================
# 🛢️ Start MySQL DB container
# =============================================================================
mysql-start:
	@echo "Starting MySQL..."
	$(DOCKER_COMPOSE) --profile mysql-dev up -d mysql-db

# =============================================================================
# ⛔ Stop MySQL DB container and clean up volumes
# =============================================================================
mysql-stop:
	@echo "Stopping MySQL DB container..."
	$(DOCKER_COMPOSE) stop mysql-db || true
	@echo "Removing MySQL container and volumes..."
	$(DOCKER_COMPOSE) rm -f -v mysql-db || true
	@echo "Cleaning up MySQL volumes..."
	docker volume rm $(docker volume ls -q | grep mysql) 2>/dev/null || true
	@echo "✅ MySQL stopped and cleaned up."

# =============================================================================
# 🛢️ Start SQL Server DB container
# =============================================================================
sqlserver-start:
	@echo "Starting SQL Server..."
	$(DOCKER_COMPOSE) --profile sqlserver-dev up -d sqlserver-db

# =============================================================================
# ⛔ Stop SQL Server DB container and clean up volumes
# =============================================================================
sqlserver-stop:
	@echo "Stopping SQL Server DB container..."
	$(DOCKER_COMPOSE) stop sqlserver-db || true
	@echo "Removing SQL Server container and volumes..."
	$(DOCKER_COMPOSE) rm -f -v sqlserver-db || true
	@echo "Cleaning up SQL Server volumes..."
	docker volume rm $(docker volume ls -q | grep sqlserver) 2>/dev/null || true
	@echo "✅ SQL Server stopped and cleaned up."

# =============================================================================
# 🛢️ Start Teradata DB container
# =============================================================================
teradata-start:
	@echo "Starting Teradata..."
	@echo "⚠️  Note: Teradata requires significant resources (6GB RAM, 2 CPUs)"
	$(DOCKER_COMPOSE) --profile teradata-dev up -d teradata-db
	@echo "⏳ Teradata is starting. This may take 5-10 minutes on first run."
	@echo "💡 Monitor startup progress with: docker compose -f docker/docker-compose.yml logs -f teradata-db"
	@echo "🌐 Once started:"
	@echo "   - Database port: 1025"
	@echo "   - Viewpoint UI: http://localhost:8020"
	@echo "   - Username: testuser / Password: snaplogic"

# =============================================================================
# ⛔ Stop Teradata DB container and clean up volumes
# =============================================================================
teradata-stop:
	@echo "Stopping Teradata DB container..."
	$(DOCKER_COMPOSE) stop teradata-db || true
	@echo "Removing Teradata container and volumes..."
	$(DOCKER_COMPOSE) rm -f -v teradata-db || true
	@echo "Cleaning up Teradata volumes..."
	docker volume rm $(docker volume ls -q | grep teradata) 2>/dev/null || true
	@echo "✅ Teradata stopped and cleaned up."


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
	$(DOCKER_COMPOSE) --profile minio-dev up -d minio

# =============================================================================
# ⛔ Stop local MinIO S3 emulator
# =============================================================================
stop-s3-emulator:
	@echo "Stopping Minio..."
	$(DOCKER_COMPOSE) stop minio

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

# =============================================================================
# 📡 ActiveMQ JMS Server Management
# =============================================================================

# =============================================================================
# 🚀 Start ActiveMQ JMS server with setup
# =============================================================================
activemq-start:
	@echo "Starting ActiveMQ JMS server..."
	$(DOCKER_COMPOSE) --profile activemq up -d activemq activemq-setup
	@echo "⏳ Waiting for ActiveMQ to fully initialize..."
	@sleep 15
	@echo "✅ ActiveMQ started. Web Console: http://localhost:8161/console"
	@echo "🔑 Credentials: admin/admin"

# =============================================================================
# 🚀 Start ActiveMQ JMS server for development (no setup)
# =============================================================================
activemq-dev-start:
	@echo "Starting ActiveMQ JMS server (dev mode)..."
	$(DOCKER_COMPOSE) --profile activemq-dev up -d activemq
	@echo "⏳ Waiting for ActiveMQ to fully initialize..."
	@sleep 15
	@echo "✅ ActiveMQ started in dev mode."

# =============================================================================
# ⛔ Stop ActiveMQ JMS server
# =============================================================================
activemq-stop:
	@echo "Stopping ActiveMQ JMS server..."
	$(DOCKER_COMPOSE) stop activemq activemq-setup 2>/dev/null || true
	@echo "✅ ActiveMQ stopped."

# =============================================================================
# 🔍 Check ActiveMQ JMS server status and connection
# =============================================================================
activemq-status:
	@echo "🔍 Checking ActiveMQ status..."
	@container_status=$$(docker inspect -f '{{.State.Status}}' snaplogic-activemq 2>/dev/null || echo "not found"); \
	if [ "$$container_status" = "running" ]; then \
		echo "✅ ActiveMQ container is running"; \
		echo "🌐 Web Console: http://localhost:8161/console"; \
		echo "📡 JMS URL: tcp://localhost:61616"; \
		echo "🔑 Credentials: admin/admin"; \
		echo "🧪 Testing web console connection..."; \
		if curl -s -f -u admin:admin http://localhost:8161/console/ >/dev/null 2>&1; then \
			echo "✅ Web console is accessible"; \
		else \
			echo "⚠️  Web console not yet ready (may still be starting)"; \
		fi; \
	else \
		echo "❌ ActiveMQ container is not running (status: $$container_status)"; \
		echo "💡 Run 'make activemq-start' to start ActiveMQ"; \
	fi

# =============================================================================
# 🔧 Run ActiveMQ setup and display connection info
# =============================================================================
activemq-setup:
	@echo "🔧 Running ActiveMQ setup and displaying connection info..."
	@$(MAKE) activemq-status
	@echo ""
	@echo "📋 Queue Suggestions for SAP IDOC Integration:"
	@echo "   • sap.idoc.queue - Main queue for SAP IDOC messages"
	@echo "   • test.queue - Queue for testing and development"
	@echo "   • demo.queue - Queue for demonstrations"
	@echo ""
	@echo "🛠️  Sample JMS Connection Properties:"
	@echo "   • Broker URL: tcp://localhost:61616"
	@echo "   • Username: admin"
	@echo "   • Password: admin"
	@echo "   • Connection Factory: ConnectionFactory"
	@echo ""
	@echo "💡 Queues are auto-created when first accessed"
	@echo "💡 Use the web console to monitor queues and messages"

# =============================================================================
# 🧪 Run JMS demo script (placeholder for future implementation)
# =============================================================================
run-jms-demo:
	@echo "🧪 JMS Demo Script"
	@echo "📝 This target is ready for your JMS demo implementation"
	@echo "💡 Consider creating: test/suite/test_data/python_helper_files/jms_demo.py"
	@echo ""
	@echo "🔧 Connection details for your demo:"
	@echo "   • JMS URL: tcp://localhost:61616"
	@echo "   • Username: admin"
	@echo "   • Password: admin"
	@echo "   • Suggested queues: sap.idoc.queue, test.queue, demo.queue"
	@echo ""
	@echo "📚 Example libraries: pyjms, stomp.py, or py4j with ActiveMQ client"

# =============================================================================
# 🔄 Rebuild tools container with updated requirements
# =============================================================================
rebuild-tools-with-updated-requirements:
	@echo "🛑 Stopping and removing tools container..."
	$(DOCKER_COMPOSE) --profile tools down
	
	@echo "🗑️  Removing old image to force complete rebuild..."
	docker rmi snaplogic-test-example:latest || true
	
	@echo "🔨 Building tools container without cache..."
	$(DOCKER_COMPOSE) build --no-cache tools
	
	@echo "🚀 Starting tools container..."
	$(DOCKER_COMPOSE) --profile tools up -d
	
	@echo "⏳ Waiting for container to be ready..."
	@sleep 5
	
	@echo "✅ Verifying snaplogic-common-robot version..."
	$(DOCKER_COMPOSE) exec tools pip show snaplogic-common-robot

# =============================================================================
   # 📦update snaplogic-common-robot to absolute latest
   # This target is useful for quick updates without rebuilding the entire tools container
# =============================================================================

quick-update-snaplogic-robot-only:
	@echo "📦 Force updating snaplogic-common-robot to latest version..."
	@echo "🔍 Current version:"
	@$(DOCKER_COMPOSE) exec -T tools pip show snaplogic-common-robot || echo "Not installed"
	@echo "🗑️  Uninstalling current version..."
	@$(DOCKER_COMPOSE) exec -T tools pip uninstall -y snaplogic-common-robot
	@echo "📥 Installing latest version from PyPI..."
	@$(DOCKER_COMPOSE) exec -T tools pip install --no-cache-dir snaplogic-common-robot
	@echo "✅ New version:"
	@$(DOCKER_COMPOSE) exec -T tools pip show snaplogic-common-robot
