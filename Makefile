# =============================================================================
# Makefile for Snaplogic Robot Framework Automation Framework
# -----------------------------------------------------------------------------
# This is the main orchestrator Makefile that includes all category-specific
# Makefiles for better organization and maintainability.
# 
# Categories:
# - Testing: Robot Framework test execution and reporting
# - Groundplex: SnapLogic Groundplex management
# - Databases: Various database systems (Oracle, PostgreSQL, MySQL, etc.)
# - Messaging: Kafka and ActiveMQ message brokers
# - Mocks: Mock services (Salesforce, S3, Email)
# - Docker: Container and tools management
# - Quality: Code formatting and dependency management
# -----------------------------------------------------------------------------
# Use 'make help' to see all available targets grouped by category
# =============================================================================

# Default target when 'make' is run without arguments
# This sets robot-run-tests as the default action, making it easy to run tests with just 'make'
.DEFAULT_GOAL := robot-run-tests

# -----------------------------------------------------------------------------
# Declare all phony targets (targets that don't create files)
# -----------------------------------------------------------------------------
.PHONY: help list-categories status docker-networks container-networks network-check

# -----------------------------------------------------------------------------
# Include Common Configuration (MUST BE FIRST)
# -----------------------------------------------------------------------------
include makefiles/Makefile.common

# -----------------------------------------------------------------------------
# Include all category-specific Makefiles
# -----------------------------------------------------------------------------
include makefiles/Makefile.testing
include makefiles/Makefile.groundplex
include makefiles/Makefile.databases
include makefiles/Makefile.messaging
include makefiles/Makefile.mocks
include makefiles/Makefile.docker
include makefiles/Makefile.quality

# -----------------------------------------------------------------------------
# Help System
# -----------------------------------------------------------------------------
help:
	@echo "============================================================================="
	@echo "       Snaplogic Robot Framework Automation - Available Commands"
	@echo "============================================================================="
	@echo ""
	@echo "🧪 TESTING & TEST EXECUTION"
	@echo "  robot-run-tests              - Run Robot Framework tests with optional tags"
	@echo "  robot-run-all-tests          - End-to-end test workflow with environment setup"
	@echo "  robot-run-tests-no-gp        - Run tests WITHOUT launching Groundplex"
	@echo "  slack-notify                 - Send test results to Slack"
	@echo "  upload-test-results          - Upload results to S3"
	@echo "  upload-test-results-cli      - Upload results using AWS CLI"
	@echo ""
	@echo "🚀 GROUNDPLEX MANAGEMENT"
	@echo "  launch-groundplex            - Launch SnapLogic Groundplex container"
	@echo "  groundplex-status            - Check Groundplex JCC status"
	@echo "  stop-groundplex              - Stop Groundplex and cleanup"
	@echo "  restart-groundplex           - Restart Groundplex"
	@echo "  setup-groundplex-cert        - Setup HTTPS certificates"
	@echo "  groundplex-check-cert        - Check certificate status"
	@echo "  createplex-launch-groundplex - Create project space and launch Groundplex"
	@echo ""
	@echo "🛢️ DATABASE SERVICES"
	@echo "  oracle-start/stop            - Oracle database management"
	@echo "  postgres-start/stop          - PostgreSQL database management"
	@echo "  mysql-start/stop             - MySQL database management"
	@echo "  sqlserver-start/stop         - SQL Server database management"
	@echo "  teradata-start/stop          - Teradata database management"
	@echo "  db2-start/stop               - DB2 database management"
	@echo "  snowflake-start/stop/setup   - Snowflake SQL client management"
	@echo ""
	@echo "📡 MESSAGE QUEUES & STREAMING"
	@echo "  kafka-start/stop/restart     - Kafka broker management"
	@echo "  kafka-status                 - Check Kafka services status"
	@echo "  kafka-create-topic           - Create a Kafka topic"
	@echo "  kafka-list-topics            - List all Kafka topics"
	@echo "  kafka-test                   - Test Kafka connectivity"
	@echo "  activemq-start/stop          - ActiveMQ JMS server management"
	@echo "  activemq-status              - Check ActiveMQ status"
	@echo ""
	@echo "🔌 MOCK SERVICES"
	@echo "  start-s3-emulator            - Start MinIO S3 emulator"
	@echo "  salesforce-mock-start/stop   - Salesforce API mock management"
	@echo "  salesforce-mock-status       - Check Salesforce mock status"
	@echo "  email-start/stop/restart     - MailDev email server management"
	@echo "  email-status                 - Check email server status"
	@echo ""
	@echo "🐳 DOCKER & TOOLS"
	@echo "  snaplogic-start-services     - Start services with compose profiles"
	@echo "  snaplogic-stop               - Stop all containers and cleanup"
	@echo "  snaplogic-build-tools        - Build tools container"
	@echo "  clean-start                  - Clean restart of all services"
	@echo "  rebuild-tools                - Rebuild tools with updated requirements"
	@echo "  check-env                    - Validate environment setup"
	@echo ""
	@echo "✨ CODE QUALITY & DEPENDENCIES"
	@echo "  robotidy                     - Format Robot Framework files"
	@echo "  robocop                      - Run static analysis on Robot files"
	@echo "  lint                         - Run both formatter and linter"
	@echo "  install-requirements-venv    - Setup venv and install requirements"
	@echo "  update-requirements-all      - Update requirements everywhere"
	@echo ""
	@echo "🔍 MONITORING & STATUS"
	@echo "  status                       - System status with container networks"
	@echo "  docker-networks              - Show all Docker networks"
	@echo "  container-networks           - Show containers and their networks"
	@echo ""
	@echo "============================================================================="
	@echo "📚 USAGE EXAMPLES:"
	@echo "  make robot-run-tests TAGS=\"oracle,minio\" PROJECT_SPACE_SETUP=True"
	@echo "  make kafka-create-topic TOPIC=my-topic PARTITIONS=3"
	@echo "  make clean-start"
	@echo ""
	@echo "💡 For detailed help on specific categories, see makefiles/README.md"
	@echo "============================================================================="

# -----------------------------------------------------------------------------
# Category Listing
# -----------------------------------------------------------------------------
list-categories:
	@echo "📁 Available Makefile Categories:"
	@echo ""
	@echo "  testing     - Robot Framework test execution and reporting"
	@echo "  groundplex  - SnapLogic Groundplex management and certificates"
	@echo "  databases   - Database services (Oracle, PostgreSQL, MySQL, etc.)"
	@echo "  messaging   - Message queues (Kafka, ActiveMQ)"
	@echo "  mocks       - Mock services (Salesforce, S3, Email)"
	@echo "  docker      - Container and tools management"
	@echo "  quality     - Code formatting and dependency management"
	@echo ""
	@echo "Each category is in makefiles/Makefile.<category>"
	@echo "You can also run targets directly: make -f makefiles/Makefile.testing robot-run-tests"

# -----------------------------------------------------------------------------
# System Status and Monitoring
# -----------------------------------------------------------------------------
status:
	@echo "🔍 System Status Check"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "📋 All Running Containers:"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "  No containers running"
	@echo ""
	@echo "🌐 Container Networks:"
	@docker ps --format "table {{.Names}}\t{{.Networks}}" || echo "  No containers running"
	@echo ""
	@echo "📡 Known Service Endpoints:"
	@if docker ps | grep -q snaplogic-groundplex; then echo "  ✅ Groundplex: Running"; else echo "  ⚠️  Groundplex: Not running"; fi
	@if docker ps | grep -q snaplogic-kafka; then echo "  ✅ Kafka: localhost:9092 (UI: http://localhost:8080)"; else echo "  ⚠️  Kafka: Not running"; fi
	@if docker ps | grep -q snaplogic-activemq; then echo "  ✅ ActiveMQ: http://localhost:8161/console"; else echo "  ⚠️  ActiveMQ: Not running"; fi
	@if docker ps | grep -q salesforce-api-mock; then echo "  ✅ Salesforce Mock: http://localhost:8089/__admin/"; else echo "  ⚠️  Salesforce Mock: Not running"; fi
	@if docker ps | grep -q maildev-test; then echo "  ✅ Email Server: http://localhost:1080"; else echo "  ⚠️  Email Server: Not running"; fi
	@if docker ps | grep -q oracle-db; then echo "  ✅ Oracle DB: localhost:1521"; else echo "  ⚠️  Oracle DB: Not running"; fi
	@if docker ps | grep -q postgres-db; then echo "  ✅ PostgreSQL: localhost:5432"; else echo "  ⚠️  PostgreSQL: Not running"; fi
	@if docker ps | grep -q mysql-db; then echo "  ✅ MySQL: localhost:3306"; else echo "  ⚠️  MySQL: Not running"; fi
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


container-networks:
	@echo "🐳 Containers and Their Networks"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@docker ps --format "table {{.Names}}\t{{.Networks}}"
	@echo ""
	@echo "📝 Detailed Network Connections:"
	@for container in $(docker ps --format "{{.Names}}"); do \
		echo ""; \
		echo "Container: $container"; \
		docker inspect $container --format '{{range $k, $v := .NetworkSettings.Networks}}  - Network: {{$k}}{{"\n"}}    IP: {{$v.IPAddress}}{{"\n"}}    Gateway: {{$v.Gateway}}{{end}}'; \
	done

# -----------------------------------------------------------------------------
# Docker Network Inspection
# -----------------------------------------------------------------------------
docker-networks:
	@echo "🌐 Docker Networks"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
	@echo ""
	@echo "📊 Network Details:"
	@for network in $(docker network ls --format "{{.Name}}" | grep -E "snaplogic|docker_default"); do \
		echo ""; \
		echo "Network: $network"; \
		docker network inspect $network --format '  Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}'; \
		echo "  Connected Containers:"; \
		docker network inspect $network --format '{{range $k, $v := .Containers}}    - {{$v.Name}} ({{$v.IPv4Address}}){{end}}' || echo "    None"; \
	done

# -----------------------------------------------------------------------------
# Quick Network Diagnostics
# -----------------------------------------------------------------------------
network-check:
	@echo "🔍 Network Connectivity Check"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🌐 SnapLogic-related Networks:"
	@docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | grep -i snaplogic || echo "  No SnapLogic networks found"
	@echo ""
	@echo "🐳 Containers on SnapLogic networks:"
	@for network in $(docker network ls --format "{{.Name}}" | grep -i snaplogic); do \
		echo ""; \
		echo "Network: $network"; \
		docker ps --filter network=$network --format "  - {{.Names}} ({{.Status}})" || echo "  No containers"; \
	done
	@echo ""
	@echo "📋 All Docker Networks:"
	@docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.ID}}"
	@echo ""
	@echo "📦 Container Count by Network:"
	@for network in $(docker network ls --format "{{.Name}}"); do \
		count=$(docker network inspect $network --format '{{len .Containers}}' 2>/dev/null || echo "0"); \
		if [ "$count" -gt 0 ]; then \
			echo "  $network: $count container(s)"; \
		fi; \
	done

