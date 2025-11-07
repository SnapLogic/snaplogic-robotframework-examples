# =============================================================================
# DB2 Database Management
# =============================================================================
# This file contains DB2 database specific targets
# =============================================================================

.PHONY: db2-start db2-stop db2-logs db2-shell db2-status \
        db2-restart db2-backup db2-restore db2-help

# Include common configuration
include makefiles/common_services/Makefile.common

# =============================================================================
# 🔵 DB2 Configuration
# =============================================================================
DB2_CONTAINER_NAME := db2-db
DB2_PROFILE := db2-dev
DB2_PORT := 50000
DB2_INSTANCE := db2inst1
DB2_PASSWORD := snaplogic
DB2_DATABASE := TESTDB
DB2_SCHEMA := SNAPTEST
DB2_USER := testuser


# =============================================================================
# 🚀 DB2 Commands
# =============================================================================

# Start DB2 database
db2-start:
	@echo "🔵 Starting DB2 Database..."
	@echo "⚠️  Note: DB2 may take 3-5 minutes to initialize on first run"
	@if [ "$$(uname -m)" = "arm64" ]; then \
		echo "⚠️  Running on Apple Silicon - DB2 will run under x86_64 emulation (slower performance)"; \
	fi
	$(DOCKER_COMPOSE) --profile $(DB2_PROFILE) up -d $(DB2_CONTAINER_NAME)
	@echo "⏳ DB2 is starting. Monitor progress with: make db2-logs"
	@echo "🌐 Once started:"
	@echo "   - Database port: $(DB2_PORT)"
	@echo "   - Database name: $(DB2_DATABASE)"
	@echo "   - Schema: $(DB2_SCHEMA)"
	@echo "   - Admin user: $(DB2_INSTANCE) / Password: $(DB2_PASSWORD)"
	@echo "   - Test user: $(DB2_USER) / Password: $(DB2_PASSWORD)"

# Stop DB2 database
db2-stop:
	@echo "🛑 Stopping DB2 container..."
	$(DOCKER_COMPOSE) stop $(DB2_CONTAINER_NAME) || true
	@echo "🧹 Removing DB2 container and volumes..."
	$(DOCKER_COMPOSE) rm -f -v $(DB2_CONTAINER_NAME) || true
	@echo "🗑️  Cleaning up DB2 volumes..."
	docker volume rm $$(docker volume ls -q | grep db2) 2>/dev/null || true
	@echo "✅ DB2 stopped and cleaned up."

# View DB2 logs
db2-logs:
	@echo "📜 Viewing DB2 logs..."
	$(DOCKER_COMPOSE) logs -f $(DB2_CONTAINER_NAME)

# Access DB2 shell
db2-shell:
	@echo "🐚 Accessing DB2 shell..."
	@echo "📝 Type 'db2' to enter DB2 command line processor"
	@echo "📝 Use 'CONNECT TO $(DB2_DATABASE)' to connect to database"
	@echo "📝 Type 'exit' twice to leave (once for db2, once for bash)"
	docker exec -it $(DB2_CONTAINER_NAME) bash -c "su - $(DB2_INSTANCE)"

# Direct DB2 command line
db2-cli:
	@echo "🐚 Accessing DB2 Command Line Interface..."
	docker exec -it $(DB2_CONTAINER_NAME) bash -c "su - $(DB2_INSTANCE) -c 'db2 CONNECT TO $(DB2_DATABASE) && db2'"

# Check DB2 status
db2-status:
	@echo "📊 DB2 Database Status:"
	@docker ps -a --filter name=$(DB2_CONTAINER_NAME) --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@if docker ps --filter name=$(DB2_CONTAINER_NAME) --format "{{.Names}}" | grep -q $(DB2_CONTAINER_NAME); then \
		echo "✅ DB2 container is running"; \
		echo "🔍 Testing connection..."; \
		docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "db2 CONNECT TO $(DB2_DATABASE) && db2 'SELECT CURRENT TIMESTAMP FROM SYSIBM.SYSDUMMY1'" 2>/dev/null && \
		echo "✅ DB2 database is accessible" || echo "⚠️  Database is still initializing (may take 3-5 minutes)"; \
	else \
		echo "❌ DB2 is not running"; \
	fi

# Restart DB2 database
db2-restart: db2-stop db2-start

# Backup DB2 database
db2-backup:
	@echo "💾 Backing up DB2 database..."
	@mkdir -p backups/db2
	@echo "Creating backup..."
	@docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "db2 BACKUP DATABASE $(DB2_DATABASE) TO /database/backup"
	@echo "Copying backup to local filesystem..."
	@docker cp $(DB2_CONTAINER_NAME):/database/backup backups/db2/
	@echo "✅ Backup completed to backups/db2/"

# Restore DB2 database from backup
db2-restore:
	@echo "📥 Available backups:"
	@ls -la backups/db2/backup/*.001 2>/dev/null || echo "No backups found"
	@echo ""
	@echo "To restore a backup:"
	@echo "  1. Copy backup to container: docker cp backups/db2/backup $(DB2_CONTAINER_NAME):/database/"
	@echo "  2. Restore: docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c 'db2 RESTORE DATABASE $(DB2_DATABASE) FROM /database/backup'"

# Initialize DB2 test database
db2-init:
	@echo "🔧 Initializing DB2 test database..."
	@echo "Waiting for DB2 to be fully ready..."
	@sleep 10
	@docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "\
		db2 CONNECT TO $(DB2_DATABASE) && \
		db2 'CREATE SCHEMA IF NOT EXISTS $(DB2_SCHEMA)' && \
		db2 'SET CURRENT SCHEMA = $(DB2_SCHEMA)' && \
		db2 'CREATE TABLE IF NOT EXISTS $(DB2_SCHEMA).users ( \
			id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1), \
			username VARCHAR(100) NOT NULL, \
			email VARCHAR(100), \
			created_at TIMESTAMP DEFAULT CURRENT TIMESTAMP, \
			PRIMARY KEY (id) \
		)' && \
		db2 'CREATE TABLE IF NOT EXISTS $(DB2_SCHEMA).products ( \
			id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1), \
			name VARCHAR(200) NOT NULL, \
			price DECIMAL(10,2), \
			quantity INTEGER, \
			PRIMARY KEY (id) \
		)' && \
		db2 'CREATE TABLE IF NOT EXISTS $(DB2_SCHEMA).orders ( \
			id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1), \
			user_id INTEGER, \
			product_id INTEGER, \
			order_date TIMESTAMP DEFAULT CURRENT TIMESTAMP, \
			PRIMARY KEY (id), \
			FOREIGN KEY (user_id) REFERENCES $(DB2_SCHEMA).users(id), \
			FOREIGN KEY (product_id) REFERENCES $(DB2_SCHEMA).products(id) \
		)'"
	@echo "✅ Test database initialized"

# Show DB2 databases
db2-show-dbs:
	@echo "📂 DB2 Databases:"
	@docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "db2 LIST DATABASE DIRECTORY"

# Show DB2 tables
db2-show-tables:
	@echo "📋 Tables in $(DB2_DATABASE).$(DB2_SCHEMA):"
	@docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "\
		db2 CONNECT TO $(DB2_DATABASE) && \
		db2 'LIST TABLES FOR SCHEMA $(DB2_SCHEMA)'"

# Show DB2 schemas
db2-show-schemas:
	@echo "📁 Schemas in $(DB2_DATABASE):"
	@docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "\
		db2 CONNECT TO $(DB2_DATABASE) && \
		db2 'SELECT SCHEMANAME FROM SYSCAT.SCHEMATA WHERE SCHEMANAME NOT LIKE \"SYS%\" ORDER BY SCHEMANAME'"

# Run DB2 query
db2-query:
	@echo "Enter your SQL query (or use: make db2-query QUERY='SELECT * FROM $(DB2_SCHEMA).users')"
	@if [ -n "$(QUERY)" ]; then \
		docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "db2 CONNECT TO $(DB2_DATABASE) && db2 '$(QUERY)'"; \
	else \
		read -p "SQL Query: " query; \
		docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "db2 CONNECT TO $(DB2_DATABASE) && db2 '$$query'"; \
	fi

# Show DB2 version
db2-version:
	@echo "📌 DB2 Version:"
	@docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "db2level"

# Show DB2 configuration
db2-config:
	@echo "⚙️  DB2 Database Configuration:"
	@docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "db2 GET DB CFG FOR $(DB2_DATABASE)" | head -20

# Create DB2 test user
db2-create-user:
	@echo "Creating DB2 user $(DB2_USER)..."
	@docker exec $(DB2_CONTAINER_NAME) bash -c "\
		useradd -m -s /bin/bash $(DB2_USER) 2>/dev/null || true && \
		echo '$(DB2_USER):$(DB2_PASSWORD)' | chpasswd"
	@docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "\
		db2 CONNECT TO $(DB2_DATABASE) && \
		db2 'GRANT CONNECT ON DATABASE TO USER $(DB2_USER)' && \
		db2 'GRANT CREATETAB ON DATABASE TO USER $(DB2_USER)' && \
		db2 'GRANT IMPLICIT_SCHEMA ON DATABASE TO USER $(DB2_USER)' && \
		db2 'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA $(DB2_SCHEMA) TO USER $(DB2_USER)'"
	@echo "✅ User $(DB2_USER) created with access to $(DB2_DATABASE).$(DB2_SCHEMA)"

# Insert sample data
db2-sample-data:
	@echo "📝 Inserting sample data into DB2..."
	@docker exec $(DB2_CONTAINER_NAME) su - $(DB2_INSTANCE) -c "\
		db2 CONNECT TO $(DB2_DATABASE) && \
		db2 'INSERT INTO $(DB2_SCHEMA).users (username, email) VALUES \
			(\"john_doe\", \"john@example.com\"), \
			(\"jane_smith\", \"jane@example.com\"), \
			(\"bob_wilson\", \"bob@example.com\")' && \
		db2 'INSERT INTO $(DB2_SCHEMA).products (name, price, quantity) VALUES \
			(\"Laptop\", 999.99, 10), \
			(\"Mouse\", 29.99, 50), \
			(\"Keyboard\", 79.99, 30)' && \
		db2 'INSERT INTO $(DB2_SCHEMA).orders (user_id, product_id) VALUES \
			(1, 1), \
			(2, 2), \
			(3, 3)'"
	@echo "✅ Sample data inserted"

# Help for DB2 commands
db2-help:
	@echo "DB2 Database Management Commands:"
	@echo "  make db2-start         - Start DB2 database"
	@echo "  make db2-stop          - Stop and clean up DB2"
	@echo "  make db2-restart       - Restart DB2 database"
	@echo "  make db2-logs          - View DB2 logs"
	@echo "  make db2-shell         - Access DB2 shell"
	@echo "  make db2-cli           - Access DB2 CLI directly"
	@echo "  make db2-status        - Check DB2 status"
	@echo "  make db2-backup        - Backup DB2 database"
	@echo "  make db2-restore       - Restore DB2 from backup"
	@echo "  make db2-init          - Initialize test database and tables"
	@echo "  make db2-show-dbs      - Show all databases"
	@echo "  make db2-show-tables   - Show tables in database"
	@echo "  make db2-show-schemas  - Show database schemas"
	@echo "  make db2-version       - Show DB2 version info"
	@echo "  make db2-config        - Show DB2 configuration"
	@echo "  make db2-create-user   - Create test user"
	@echo "  make db2-sample-data   - Insert sample data"
	@echo "  make db2-query         - Run a SQL query"
	@echo "  make db2-help          - Show this help message"
	@echo ""
	@echo "⚠️  Note: DB2 may take 3-5 minutes to initialize on first run"
