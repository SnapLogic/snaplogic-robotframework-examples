# Infrastructure Services Connection Details

This guide provides connection details for all infrastructure services available in the SnapLogic Robot Framework test environment.

## Quick Start

To start any service, use the following commands:

```bash
# Start individual services
make oracle-start
make postgres-start
make mysql-start
make sqlserver-start
make start-s3-emulator
make activemq-start

# Stop individual services
make oracle-stop
make postgres-stop
make mysql-stop
make sqlserver-stop
make stop-s3-emulator
make activemq-stop
```

## Connection Details Summary

| Service | Container Name | Host | Port | Admin User | Admin Password | Test User | Test Password | Database/Schema | Additional Info |
|---------|----------------|------|------|------------|----------------|-----------|---------------|-----------------|-----------------|
| **Oracle DB** | oracle-db | localhost | 1521 | system | Oracle123 | TEST | Test123 | FREEPDB1 | Oracle Free 23.7.0.0-lite |
| **PostgreSQL** | postgres-db | localhost | 5434 | snaplogic | snaplogic | snaplogic | snaplogic | snaplogic | PostgreSQL 15 |
| **SQL Server** | sqlserver-db | localhost | 1433 | sa | Snaplogic123! | testuser | Snaplogic123! | TEST | SQL Server 2022 Developer |
| **MySQL** | mysql-db | localhost | 3306 | root | snaplogic | testuser | snaplogic | TEST | MySQL 8.0 |
| **MinIO (S3)** | snaplogic-minio | localhost | 9000 (API)<br>9001 (Console) | minioadmin | minioadmin | demouser | demopassword | N/A | Buckets: demo-bucket, test-bucket |
| **ActiveMQ** | snaplogic-activemq | localhost | 8161 (Web)<br>61616 (JMS)<br>61613 (STOMP)<br>5672 (AMQP) | admin | admin | admin | admin | N/A | Apache Artemis |

## Detailed Service Information

### Oracle Database
- **Image**: container-registry.oracle.com/database/free:23.7.0.0-lite
- **Connection String**: `jdbc:oracle:thin:@localhost:1521/FREEPDB1`
- **Service Name**: FREEPDB1
- **Profile**: oracle-dev
- **Features**: 
  - Automatically creates TEST user with full privileges
  - Includes health check for container readiness
  - Persistent volume for data

### PostgreSQL
- **Image**: postgres:15
- **Connection String**: `jdbc:postgresql://localhost:5434/snaplogic`
- **Default Database**: snaplogic
- **Profile**: postgres-dev
- **Note**: Runs on port 5434 (not default 5432)

### SQL Server
- **Image**: mcr.microsoft.com/mssql/server:2022-latest
- **Connection String**: `jdbc:sqlserver://localhost:1433;databaseName=TEST`
- **Edition**: Developer (free for development)
- **Profile**: sqlserver-dev
- **Features**:
  - Creates TEST database automatically
  - Creates testuser with db_owner role
  - Accepts EULA automatically

### MySQL
- **Image**: mysql:8.0
- **Connection String**: `jdbc:mysql://localhost:3306/TEST`
- **Authentication**: mysql_native_password
- **Profile**: mysql-dev
- **Features**:
  - TEST database created automatically
  - testuser has full privileges on TEST database
  - Includes verification table

### MinIO (S3-Compatible Storage)
- **Image**: minio/minio:latest
- **API Endpoint**: http://localhost:9000
- **Console URL**: http://localhost:9001
- **Profile**: minio, minio-dev
- **Pre-created Resources**:
  - Buckets: `demo-bucket`, `test-bucket`
  - Users: `minioadmin` (root), `demouser` (regular user)
  - Sample files uploaded during setup
- **S3 Configuration**:
  ```python
  # Example Python configuration
  s3_client = boto3.client(
      's3',
      endpoint_url='http://localhost:9000',
      aws_access_key_id='minioadmin',
      aws_secret_access_key='minioadmin',
      use_ssl=False
  )
  ```

### ActiveMQ (JMS Message Broker)
- **Image**: apache/activemq-artemis:latest
- **Web Console**: http://localhost:8161/console
- **Connection URLs**:
  - JMS: `tcp://localhost:61616`
  - STOMP: `tcp://localhost:61613`
  - AMQP: `amqp://localhost:5672`
- **Profile**: activemq, activemq-dev
- **Features**:
  - Apache Artemis implementation
  - Auto-creates queues and topics
  - Supports both ANYCAST (queue) and MULTICAST (topic) routing
- **Suggested Queue Names**:
  - `test.queue` - For testing
  - `demo.queue` - For demonstrations
  - `sap.idoc.queue` - For SAP IDOC messages
- **JMS Configuration Example**:
  ```java
  // Java example
  ConnectionFactory factory = new ActiveMQConnectionFactory(
      "tcp://localhost:61616?user=admin&password=admin"
  );
  ```

## Docker Compose Profiles

Services are organized into profiles for easy management:

| Profile | Services Included |
|---------|------------------|
| `oracle-dev` | Oracle DB and schema initialization |
| `postgres-dev` | PostgreSQL database |
| `mysql-dev` | MySQL database and permissions setup |
| `sqlserver-dev` | SQL Server and database setup |
| `minio-dev` | MinIO S3 server only |
| `minio` | MinIO S3 server with setup (creates buckets/users) |
| `activemq-dev` | ActiveMQ message broker only |
| `activemq` | ActiveMQ with setup and configuration display |

## Network Configuration

All services connect through a custom Docker network:
- **Network Name**: `snaplogicnet`
- **Driver**: bridge

This allows services to communicate with each other using container names as hostnames.

## Volume Persistence

Each service uses named volumes for data persistence:
- `oracle_data` - Oracle database files
- `postgres_data` - PostgreSQL database files
- `mysql_data` - MySQL database files
- `sqlserver_data` - SQL Server database files
- `minio_data` - MinIO object storage
- `activemq_data` - ActiveMQ message persistence

## Health Checks

All services include health checks to ensure they're ready before dependent services start:
- Oracle: SQL query test
- PostgreSQL: pg_isready command
- MySQL: mysqladmin ping
- SQL Server: sqlcmd query test
- MinIO: HTTP health endpoint
- ActiveMQ: Web console availability

## Troubleshooting

### Service Won't Start
```bash
# Check if port is already in use
lsof -i :PORT_NUMBER

# Check service logs
docker logs CONTAINER_NAME

# Force recreate service
docker-compose --profile PROFILE_NAME up -d --force-recreate SERVICE_NAME
```

### Clean Start
```bash
# Stop all services and remove volumes
make snaplogic-stop

# Start fresh
make clean-start
```

### Connection Issues
1. Ensure the service is running: `docker ps | grep CONTAINER_NAME`
2. Check health status: `docker inspect CONTAINER_NAME | grep -A 10 Health`
3. Verify port mapping: `docker port CONTAINER_NAME`
4. Test connectivity: `telnet localhost PORT_NUMBER`

## Integration with Robot Framework

These services can be accessed in Robot Framework tests using the appropriate libraries:

```robotframework
*** Settings ***
Library    DatabaseLibrary
Library    RequestsLibrary
Library    OperatingSystem

*** Variables ***
# Database connections
${ORACLE_CONN}      cx_Oracle://TEST:Test123@localhost:1521/FREEPDB1
${POSTGRES_CONN}    psycopg2://snaplogic:snaplogic@localhost:5434/snaplogic
${MYSQL_CONN}       pymysql://testuser:snaplogic@localhost:3306/TEST
${SQLSERVER_CONN}   pymssql://testuser:Snaplogic123!@localhost:1433/TEST

# S3 endpoint
${S3_ENDPOINT}      http://localhost:9000

# JMS connection
${JMS_URL}          tcp://localhost:61616
```

## Security Notes

⚠️ **Warning**: These configurations are for development/testing only. They use:
- Simple passwords
- No SSL/TLS encryption
- Open network access
- Default ports

For production environments, ensure proper security measures are implemented.
