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
        teradata-start teradata-stop db2-start db2-stop snowflake-start snowflake-stop snowflake-setup \
        robotidy robocop lint groundplex-status stop-groundplex \
        start-s3-emulator stop-s3-emulator run-s3-demo ensure-config-dir \
        activemq-start activemq-stop activemq-status activemq-setup run-jms-demo \
        start-services createplex-launch-groundplex \
        salesforce-mock-start salesforce-mock-stop salesforce-mock-status salesforce-mock-restart \
		rebuild-tools-with-updated-requirements install-requirements-local install-requirements-venv \
		update-requirements-all clean-install-requirements upload-test-results upload-test-results-cli

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
COMPOSE_PROFILES ?= tools,oracle-dev,minio,postgres-dev,mysql-dev,sqlserver-dev,activemq

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
	echo ":========== [Phase 2.1] Setting permissions for test data directories =========="; \
	chmod +x ./scripts/set_travis_permissions.sh; \
	./scripts/set_travis_permissions.sh || echo "Warning: Could not set all permissions"; \
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
clean-start: snaplogic-stop snaplogic-start-services createplex-launch-groundplex
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
# 🔄 Restart Groundplex (stop and launch)
# =============================================================================
restart-groundplex: stop-groundplex launch-groundplex
	@echo "✅ Groundplex successfully restarted!"

# =============================================================================
# 🔍 Check Groundplex Java Options and Configuration
# =============================================================================
groundplex-check-java-opts:
	@echo "🔍 Checking SL_JAVA_OPTS in Groundplex container..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "📋 Environment Variable:"
	@docker exec snaplogic-groundplex printenv SL_JAVA_OPTS || echo "❌ SL_JAVA_OPTS not set"
	@echo ""
	@echo "🔍 All JAVA-related environment variables:"
	@docker exec snaplogic-groundplex env | grep -i java || echo "No Java env vars found"
	@echo ""
	@echo "🔧 Java Process Arguments (main JCC):"
	@docker exec snaplogic-groundplex ps aux | grep "jcc.war jcc" | grep -v grep || echo "JCC process not found"
	@echo ""
	@echo "📊 JCC Status:"
	@docker exec snaplogic-groundplex bash -c "cd /opt/snaplogic/bin && ./jcc.sh status" || echo "JCC not running"
	@echo ""
	@echo "🔍 Checking if Salesforce options are present in Java process:"
	@if docker exec snaplogic-groundplex ps aux | grep -q "salesforce.force.http"; then \
		echo "✅ Salesforce HTTP option is ACTIVE"; \
	else \
		echo "❌ Salesforce HTTP option NOT found in Java process"; \
	fi
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
	@echo "⚠️  IMPORTANT: Teradata Docker images are NOT publicly available"
	@echo "🔐 You need special access from Teradata Corporation to use these images"
	@echo "👉 See docker/docker-compose.teradata.yml for details on how to get access"
	@echo ""
	@echo "⚠️  Note: Teradata requires significant resources (6GB RAM, 2 CPUs)"
	@echo "📦 Attempting to start Teradata (will fail if images not available)..."
	$(DOCKER_COMPOSE) --profile teradata-dev up -d teradata-db || { \
		echo ""; \
		echo "❌ Failed to start Teradata. This usually means:"; \
		echo "   1. You don't have access to Teradata Docker images"; \
		echo "   2. You haven't logged into Teradata's registry"; \
		echo ""; \
		echo "💡 Alternatives:"; \
		echo "   - Use Teradata Vantage Express on VMware (free)"; \
		echo "   - Use Teradata Vantage Developer cloud (14-day trial)"; \
		echo "   - Contact Teradata for Docker image access"; \
		exit 1; \
	}
	@echo "⏳ Teradata is starting. This may take 5-10 minutes on first run."
	@echo "💡 Monitor startup progress with: docker compose -f docker/docker-compose.yml logs -f teradata-db"
	@echo "🌐 Once started:"
	@echo "   - Database port: 1025"
	@echo "   - Viewpoint UI: http://localhost:8020"
	@echo "   - Username: dbc / Password: dbc"

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
# 🛢️ Start DB2 DB container
# =============================================================================
db2-start:
	@echo "Starting DB2..."
	@echo "⚠️  Note: DB2 may take 3-5 minutes to initialize on first run"
	@if [ "$(uname -m)" = "arm64" ]; then \
		echo "⚠️  Running on Apple Silicon - DB2 will run under x86_64 emulation (slower performance)"; \
	fi
	$(DOCKER_COMPOSE) --profile db2-dev up -d db2-db
	@echo "⏳ DB2 is starting. Monitor progress with: docker compose -f docker/docker-compose.yml logs -f db2-db"
	@echo "🌐 Once started:"
	@echo "   - Database port: 50000"
	@echo "   - Database name: TESTDB"
	@echo "   - Schema: SNAPTEST"
	@echo "   - Admin user: db2inst1 / Password: snaplogic"
	@echo "   - Test user: testuser / Password: snaplogic"

# =============================================================================
# ⛔ Stop DB2 DB container and clean up volumes
# =============================================================================
db2-stop:
	@echo "Stopping DB2 DB container..."
	$(DOCKER_COMPOSE) stop db2-db || true
	@echo "Removing DB2 container and volumes..."
	$(DOCKER_COMPOSE) rm -f -v db2-db || true
	@echo "Cleaning up DB2 volumes..."
	docker volume rm $(docker volume ls -q | grep db2) 2>/dev/null || true
	@echo "✅ DB2 stopped and cleaned up."

# =============================================================================
# ❄️ Start Snowflake SQL client container
# =============================================================================
snowflake-start:
	@echo "Starting Snowflake SQL client..."
	@echo "⚠️  IMPORTANT: Snowflake is a cloud-only service and cannot run locally"
	@echo "👉 This container provides the SnowSQL CLI client to connect to your Snowflake cloud account"
	@echo ""
	@if [ ! -f "docker/snowflake-config/config" ]; then \
		echo "⚠️  No config file found at docker/snowflake-config/config"; \
		echo "📝 Please edit the config file with your Snowflake account details"; \
	fi
	$(DOCKER_COMPOSE) --profile snowflake-dev up -d snowsql-client
	@echo "⏳ SnowSQL client is starting..."
	@sleep 5
	@echo "🌐 SnowSQL client ready!"
	@echo ""
	@echo "🔧 Usage examples:"
	@echo "   - Interactive shell: docker exec -it snowsql-client snowsql"
	@echo "   - With connection: docker exec -it snowsql-client snowsql -c example"
	@echo "   - Run query: docker exec -it snowsql-client snowsql -c example -q 'SELECT CURRENT_VERSION()'"
	@echo ""
	@echo "📄 Don't forget to configure your connection in docker/snowflake-config/config"

# =============================================================================
# ⛔ Stop Snowflake SQL client container
# =============================================================================
snowflake-stop:
	@echo "Stopping Snowflake SQL client..."
	$(DOCKER_COMPOSE) stop snowsql-client || true
	@echo "Removing Snowflake client container..."
	$(DOCKER_COMPOSE) rm -f -v snowsql-client || true
	@echo "✅ Snowflake SQL client stopped and cleaned up."

# =============================================================================
# 🔧 Setup Snowflake test data
# =============================================================================
snowflake-setup:
	@echo "🔧 Snowflake Test Data Setup"
	@echo "⚠️  Note: Snowflake runs in the cloud, so you need to:"
	@echo "   1. Have a Snowflake account (sign up for free trial at https://signup.snowflake.com/)"
	@echo "   2. Configure your connection in docker/snowflake-config/config"
	@echo "   3. Ensure the SnowSQL client is running (make snowflake-start)"
	@echo ""
	@echo "📄 To set up test data, run ONE of these commands:"
	@echo ""
	@echo "Option 1 - Run setup script directly:"
	@echo "  docker exec -it snowsql-client snowsql -c example -f /scripts/setup_testdb.sql"
	@echo ""
	@echo "Option 2 - Interactive session:"
	@echo "  docker exec -it snowsql-client snowsql -c example"
	@echo "  Then in SnowSQL: !source /scripts/setup_testdb.sql"
	@echo ""
	@echo "Option 3 - Run individual commands:"
	@echo "  docker exec -it snowsql-client snowsql -c example -q \"CREATE DATABASE IF NOT EXISTS TESTDB\""
	@echo ""
	@echo "🧪 Test your setup:"
	@echo "  docker exec -it snowsql-client snowsql -c example -f /scripts/test_queries.sql"
	@echo ""
	@echo "📁 Available SQL scripts:"
	@echo "  - /scripts/setup_testdb.sql - Creates tables and sample data"
	@echo "  - /scripts/test_queries.sql - Sample queries to verify setup"


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
		--endpoint http://localhost:9010 \
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
# 🔌 Salesforce Mock API Server Management
# =============================================================================

# =============================================================================
# 🚀 Start Salesforce Mock server for API mocking
# =============================================================================
salesforce-mock-start:
	@echo "🚀 Starting Salesforce Mock API server..."
	$(DOCKER_COMPOSE) --profile salesforce-dev up -d salesforce-mock salesforce-json-server
	@echo "⏳ Waiting for WireMock to initialize..."
	@sleep 5
	@echo "✅ Salesforce mock service started!"
	@echo ""
	@echo "🌐 Available endpoints:"
	@echo "   • Base URL: http://localhost:8089 (will show 403 - this is normal!)"
	@echo "   • OAuth Token: POST http://localhost:8089/services/oauth2/token"
	@echo "   • Query API: GET http://localhost:8089/services/data/v59.0/query"
	@echo "   • CRUD Operations: http://localhost:8089/services/data/v59.0/sobjects/Account"
	@echo "   • Admin Console: http://localhost:8089/__admin/"
	@echo "   • View Mappings: http://localhost:8089/__admin/mappings"
	@echo ""
	@echo "🔧 Configure SnapLogic Salesforce Account:"
	@echo "   • Login URL: http://localhost:8089"
	@echo "   • Username: snap-qa@snaplogic.com (or any value)"
	@echo "   • Password: any value"
	@echo ""
	@echo "🧪 Test the service:"
	@echo "   curl -X POST http://localhost:8089/services/oauth2/token -d 'grant_type=password'"

# =============================================================================
# ⛔ Stop Salesforce Mock server and clean up volumes
# =============================================================================
salesforce-mock-stop:
	@echo "⛔ Stopping Salesforce Mock server containers..."
	$(DOCKER_COMPOSE) stop salesforce-mock salesforce-json-server || true
	@echo "Removing Salesforce mock containers and volumes..."
	$(DOCKER_COMPOSE) rm -f -v salesforce-mock salesforce-json-server || true
	@echo "Cleaning up Salesforce mock volumes..."
	docker volume rm $(docker volume ls -q | grep salesforce) 2>/dev/null || true
	@echo "✅ Salesforce mock stopped and cleaned up."

# =============================================================================
# 🔍 Check Salesforce Mock server status
# =============================================================================
salesforce-mock-status:
	@bash -c '\
		echo "🔍 Checking Salesforce Mock status..."; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		wiremock_status=$$(docker inspect -f "{{.State.Status}}" salesforce-api-mock 2>/dev/null || echo "not found"); \
		json_server_status=$$(docker inspect -f "{{.State.Status}}" salesforce-json-mock 2>/dev/null || echo "not found"); \
		if [ "$$wiremock_status" = "running" ]; then \
			echo "✅ WireMock container is running"; \
			echo "   Container: salesforce-api-mock"; \
			echo "   Port: 8089"; \
		else \
			echo "❌ WireMock container is not running (status: $$wiremock_status)"; \
		fi; \
		if [ "$$json_server_status" = "running" ]; then \
			echo "✅ JSON Server container is running"; \
			echo "   Container: salesforce-json-mock"; \
			echo "   Port: 8082"; \
		else \
			echo "❌ JSON Server container is not running (status: $$json_server_status)"; \
		fi; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		if [ "$$wiremock_status" = "running" ] && [ "$$json_server_status" = "running" ]; then \
			echo "🌐 Available endpoints:"; \
			echo "   • Base URL: http://localhost:8089"; \
			echo "   • Admin Console: http://localhost:8089/__admin/"; \
			echo "   • Request Journal: http://localhost:8089/__admin/requests"; \
			echo "   • JSON Server: http://localhost:8082"; \
			echo ""; \
			echo "🧪 Testing service health..."; \
			if curl -s -f http://localhost:8089/__admin/health >/dev/null 2>&1; then \
				echo "   ✅ WireMock health check passed"; \
			else \
				echo "   ⚠️  WireMock health check failed"; \
			fi; \
			if curl -s -f -X POST http://localhost:8089/services/oauth2/token -d "grant_type=password" >/dev/null 2>&1; then \
				echo "   ✅ OAuth endpoint is accessible"; \
			else \
				echo "   ⚠️  OAuth endpoint not responding"; \
			fi; \
			if curl -s -f http://localhost:8082/ >/dev/null 2>&1; then \
				echo "   ✅ JSON Server is accessible"; \
			else \
				echo "   ⚠️  JSON Server not responding"; \
			fi; \
		elif [ "$$wiremock_status" = "running" ] || [ "$$json_server_status" = "running" ]; then \
			echo "⚠️  WARNING: Only partial services are running"; \
			echo "💡 Run '\''make salesforce-mock-restart'\'' to restart all services"; \
		else \
			echo "💡 Run '\''make salesforce-mock-start'\'' to start the mock services"; \
		fi'
# =============================================================================
# 🔄 Restart Salesforce Mock server
# =============================================================================
salesforce-mock-restart:
	@echo "🔄 Restarting Salesforce Mock server..."
	@$(MAKE) salesforce-mock-stop
	@sleep 2
	@$(MAKE) salesforce-mock-start

# =============================================================================
# 🔄 Rebuild tools container with updated requirements
#   → This target is useful for development when you need to update the tools container if there are changes in the requirements.txt file or .env file
# =============================================================================
rebuild-tools:
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


# =============================================================================
# 📦 Install requirements in local virtual environment
# =============================================================================
install-requirements-local:
	@echo "📦 Installing requirements in local environment..."
	@if [ -z "$VIRTUAL_ENV" ]; then \
		echo "❌ No virtual environment activated!"; \
		echo "💡 Please activate your virtual environment first:"; \
		echo "   source ../.venv/bin/activate"; \
		echo "   or use: make install-requirements-venv"; \
		exit 1; \
	fi
	@echo "✅ Virtual environment detected: $VIRTUAL_ENV"
	@echo "🔧 Installing requirements..."
	pip install -r src/tools/requirements.txt
	@echo "✅ Requirements installed successfully!"
	@echo "📋 Installed packages:"
	@pip list | head -20

# =============================================================================
# 🐍 Activate venv and install requirements (all-in-one)
# =============================================================================
install-requirements-venv:
	@echo "🐍 Setting up virtual environment and installing requirements..."
	@if [ ! -d "../.venv" ]; then \
		echo "❌ Virtual environment not found at ../.venv"; \
		echo "💡 Creating new virtual environment..."; \
		python3 -m venv ../.venv; \
	fi
	@echo "📦 Installing requirements in virtual environment..."
	@../.venv/bin/pip install --upgrade pip
	@../.venv/bin/pip install -r src/tools/requirements.txt
	@echo "✅ Requirements installed successfully!"
	@echo "💡 To activate the virtual environment, run:"
	@echo "   source ../.venv/bin/activate"

# =============================================================================
# 🔄 Update requirements in both local venv and Docker tools container
# =============================================================================
update-requirements-all: install-requirements-venv
	@echo "🔄 Updating Docker tools container..."
	@if docker ps | grep -q snaplogic-test-example-tools-container; then \
		echo "📋 Copying requirements to running container..."; \
		docker cp src/tools/requirements.txt snaplogic-test-example-tools-container:/app/src/tools/requirements.txt; \
		echo "📦 Installing in container..."; \
		docker exec snaplogic-test-example-tools-container pip install -r /app/src/tools/requirements.txt; \
		echo "✅ Docker container updated!"; \
	else \
		echo "⚠️  Tools container not running. Run 'make rebuild-tools-with-updated-requirements' to rebuild."; \
	fi

# =============================================================================
# 🧹 Clean and reinstall requirements in venv
# =============================================================================
clean-install-requirements:
	@echo "🧹 Clean installing requirements..."
	@if [ -z "$VIRTUAL_ENV" ]; then \
		echo "⚠️  Activating virtual environment..."; \
		source ../.venv/bin/activate; \
	fi
	@echo "🗑️  Removing all packages..."
	@pip freeze | xargs pip uninstall -y 2>/dev/null || true
	@echo "📦 Installing fresh requirements..."
	@pip install --upgrade pip
	@pip install -r src/tools/requirements.txt
	@echo "✅ Clean install completed!"

# Send slack notifications for test results
slack-notify:
	@echo "Sending Slack notifications for test results..."
	docker compose --env-file .env -f docker/docker-compose.yml exec -e SLACK_WEBHOOK_URL -w /app/test tools bash -c 'LATEST_OUTPUT=$$(ls -t robot_output/output-*.xml | head -1) && echo "Processing: $$LATEST_OUTPUT" && python testresults_slack_notifications.py "$$LATEST_OUTPUT"'
# =============================================================================
# 📤 Upload Robot Framework test results to S3
# Usage:
#   make upload-test-results                     # Upload all files with zip
#   CREATE_ZIP=false make upload-test-results    # Upload without zip file
#   UPLOAD_LATEST_ONLY=true make upload-test-results  # Upload only latest files
# =============================================================================
upload-test-results:
	@echo "📤 Uploading test results to S3..."
	@echo "🔍 Checking for AWS credentials..."
	@if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then \
		echo "⚠️  AWS credentials not found in environment."; \
		echo "🔍 Checking .env file for credentials..."; \
		if [ -f ".env" ] && grep -q "AWS_ACCESS_KEY_ID" .env && grep -q "AWS_SECRET_ACCESS_KEY" .env; then \
			echo "✅ Found AWS credentials in .env file"; \
			export $(cat .env | grep -E '^AWS_' | xargs); \
		else \
			echo "❌ AWS credentials not found. Please set:"; \
			echo "   export AWS_ACCESS_KEY_ID=your_access_key"; \
			echo "   export AWS_SECRET_ACCESS_KEY=your_secret_key"; \
			echo "   Or add them to your .env file"; \
			exit 1; \
		fi; \
	fi
	@echo "🚀 Running upload script inside tools container..."
	$(DOCKER_COMPOSE) exec -w /app/test -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e CREATE_ZIP -e UPLOAD_LATEST_ONLY -e LATEST_COUNT tools python upload_robot_results.py

# =============================================================================
# 🚀 Upload test results using AWS CLI (alternative to Python script)
# =============================================================================
upload-test-results-cli:
	@echo "📤 Uploading test results to S3 using AWS CLI..."
	@echo "🔍 Checking for AWS credentials..."
	@if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then \
		echo "⚠️  AWS credentials not found in environment."; \
		echo "🔍 Checking .env file for credentials..."; \
		if [ -f ".env" ] && grep -q "AWS_ACCESS_KEY_ID" .env && grep -q "AWS_SECRET_ACCESS_KEY" .env; then \
			echo "✅ Found AWS credentials in .env file"; \
			source .env && export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; \
		else \
			echo "❌ AWS credentials not found. Please set:"; \
			echo "   export AWS_ACCESS_KEY_ID=your_access_key"; \
			echo "   export AWS_SECRET_ACCESS_KEY=your_secret_key"; \
			echo "   Or add them to your .env file"; \
			exit 1; \
		fi; \
	fi
	@echo "⏰ Creating timestamp..."
	$(eval TIMESTAMP := $(shell date +'%Y%m%d-%H%M%S'))
	@echo "📁 Timestamp: $(TIMESTAMP)"
	@echo "🚀 Uploading files to S3..."
	@echo "📤 Uploading XML files..."
	@$(DOCKER_COMPOSE) exec -T -w /app/test \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		tools bash -c 'aws s3 cp robot_output/ s3://artifacts.slimdev.snaplogic/RF_CommonTests_Results/$(TIMESTAMP)/ \
		--recursive --exclude "*" --include "output-*.xml" --no-progress || echo "No XML files to upload"'
	@echo "📤 Uploading HTML log files..."
	@$(DOCKER_COMPOSE) exec -T -w /app/test \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		tools bash -c 'aws s3 cp robot_output/ s3://artifacts.slimdev.snaplogic/RF_CommonTests_Results/$(TIMESTAMP)/ \
		--recursive --exclude "*" --include "log-*.html" --no-progress || echo "No log files to upload"'
	@echo "📤 Uploading HTML report files..."
	@$(DOCKER_COMPOSE) exec -T -w /app/test \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		tools bash -c 'aws s3 cp robot_output/ s3://artifacts.slimdev.snaplogic/RF_CommonTests_Results/$(TIMESTAMP)/ \
		--recursive --exclude "*" --include "report-*.html" --no-progress || echo "No report files to upload"'
	@echo "" 
	@echo "======================================================================"
	@echo "✅ All uploads completed successfully!"
	@echo "📍 Complete S3 Location:"
	@echo "   s3://artifacts.slimdev.snaplogic/RF_CommonTests_Results/$(TIMESTAMP)/"
	@echo ""
	@echo "🌐 S3 Console URL:"
	@echo "   https://s3.console.aws.amazon.com/s3/buckets/artifacts.slimdev.snaplogic?prefix=RF_CommonTests_Results/$(TIMESTAMP)/"
	@echo ""
	@echo "📋 AWS CLI command to list uploaded files:"
	@echo "   aws s3 ls s3://artifacts.slimdev.snaplogic/RF_CommonTests_Results/$(TIMESTAMP)/"
	@echo ""
	@echo "📥 AWS CLI command to download all files:"
	@echo "   aws s3 sync s3://artifacts.slimdev.snaplogic/RF_CommonTests_Results/$(TIMESTAMP)/ ./downloaded_results/"
	@echo "======================================================================"