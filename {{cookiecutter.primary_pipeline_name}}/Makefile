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
.PHONY: help list-categories status docker-networks container-networks network-check show-running


# -----------------------------------------------------------------------------
# Include Common Configuration (MUST BE FIRST)
# -----------------------------------------------------------------------------
include makefiles/common_services/Makefile.common

# -----------------------------------------------------------------------------
# Include all general common Services Makefiles
# -----------------------------------------------------------------------------
include makefiles/common_services/Makefile.testing
include makefiles/common_services/Makefile.groundplex
include makefiles/common_services/Makefile.docker
include makefiles/common_services/Makefile.quality

# -----------------------------------------------------------------------------
# Include all database-specific Makefiles
# -----------------------------------------------------------------------------
include makefiles/database_services/Makefile.oracle
include makefiles/database_services/Makefile.postgres
include makefiles/database_services/Makefile.mysql
include makefiles/database_services/Makefile.sqlserver
include makefiles/database_services/Makefile.teradata
include makefiles/database_services/Makefile.db2
include makefiles/database_services/Makefile.snowflake

# -----------------------------------------------------------------------------
# Include all messaging service Makefiles
# -----------------------------------------------------------------------------
include makefiles/messaging_services/Makefile.kafka
include makefiles/messaging_services/Makefile.activemq

# -----------------------------------------------------------------------------
# Include all mock service Makefiles
# -----------------------------------------------------------------------------
include makefiles/mock_services/Makefile.minio
include makefiles/mock_services/Makefile.salesforce-django
include makefiles/mock_services/Makefile.maildev


# -----------------------------------------------------------------------------
# System Status and Monitoring
# -----------------------------------------------------------------------------
status:
	@echo "🔍 System Status Check"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "📋 All Running Containers:"
	@docker ps --format "table {% raw %}{{.Names}}\t{{.Status}}\t{{.Ports}}{% endraw %}" || echo "  No containers running"
	@echo ""
	@echo "🌐 Container Networks:"
	@docker ps --format "table {% raw %}{{.Names}}\t{{.Networks}}{% endraw %}" || echo "  No containers running"
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
	@docker ps --format "table {% raw %}{{.Names}}\t{{.Networks}}{% endraw %}"
	@echo ""
	@echo "📝 Detailed Network Connections:"
	@for container in $(docker ps --format "{% raw %}{{.Names}}{% endraw %}"); do \
		echo ""; \
		echo "Container: $container"; \
		docker inspect $container --format '{% raw %}{{range $k, $v := .NetworkSettings.Networks}}  - Network: {{$k}}{{"\n"}}    IP: {{$v.IPAddress}}{{"\n"}}    Gateway: {{$v.Gateway}}{{end}}{% endraw %}'; \
	done

# -----------------------------------------------------------------------------
# Docker Network Inspection
# -----------------------------------------------------------------------------
docker-networks:
	@echo "🌐 Docker Networks"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@docker network ls --format "table {% raw %}{{.Name}}\t{{.Driver}}\t{{.Scope}}{% endraw %}"
	@echo ""
	@echo "📊 Network Details:"
	@for network in $(docker network ls --format "{% raw %}{{.Name}}{% endraw %}" | grep -E "snaplogic|docker_default"); do \
		echo ""; \
		echo "Network: $network"; \
		docker network inspect $network --format '  Subnet: {% raw %}{{range .IPAM.Config}}{{.Subnet}}{{end}}{% endraw %}'; \
		echo "  Connected Containers:"; \
		docker network inspect $network --format '{% raw %}{{range $k, $v := .Containers}}    - {{$v.Name}} ({{$v.IPv4Address}}){{end}}{% endraw %}' || echo "    None"; \
	done

# -----------------------------------------------------------------------------
# Quick Network Diagnostics
# -----------------------------------------------------------------------------
network-check:
	@echo "🔍 Network Connectivity Check"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🌐 SnapLogic-related Networks:"
	@docker network ls --format "table {% raw %}{{.Name}}\t{{.Driver}}\t{{.Scope}}{% endraw %}" | grep -i snaplogic || echo "  No SnapLogic networks found"
	@echo ""
	@echo "🐳 Containers on SnapLogic networks:"
	@for network in $(docker network ls --format "{% raw %}{{.Name}}{% endraw %}" | grep -i snaplogic); do \
		echo ""; \
		echo "Network: $network"; \
		docker ps --filter network=$network --format "  - {% raw %}{{.Names}} ({{.Status}}){% endraw %}" || echo "  No containers"; \
	done
	@echo ""
	@echo "📋 All Docker Networks:"
	@docker network ls --format "table {% raw %}{{.Name}}\t{{.Driver}}\t{{.ID}}{% endraw %}"
	@echo ""
	@echo "📦 Container Count by Network:"
	@for network in $(docker network ls --format "{% raw %}{{.Name}}{% endraw %}"); do \
		count=$(docker network inspect $network --format '{% raw %}{{len .Containers}}{% endraw %}' 2>/dev/null || echo "0"); \
		if [ "$count" -gt 0 ]; then \
			echo "  $network: $count container(s)"; \
		fi; \
	done

# -----------------------------------------------------------------------------
# SHOW-RUNNING: Display currently running services
# -----------------------------------------------------------------------------
# What it does:
#   - Shows all running containers and their status
#   - Helps identify what services might need restart
# When to use:
#   - To check what's currently running
#   - Before deciding what to restart
#   - To verify services are up
# Usage:
#   make show-running
# -----------------------------------------------------------------------------
show-running:
	@echo "📋 Currently running services:"
	@echo "========================================"
	$(DOCKER_COMPOSE) ps --format "table {% raw %}{{.Name}}\t{{.Status}}\t{{.Ports}}{% endraw %}"
	@echo "========================================"
	@echo "💡 Tip: Use 'make recreate-tools' to reload .env file changes (5s)"
	@echo "💡 Tip: Use 'make restart-tools' for quick restart without env reload (3s)"