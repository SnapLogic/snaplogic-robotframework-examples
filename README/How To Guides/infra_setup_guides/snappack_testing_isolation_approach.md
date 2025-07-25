# SnapPack Testing Isolation Approach

## SnapLogic Mocking Strategies

Below is the outline of **three approaches** to mocking SnapLogic integrations:

| **Priority** | **Description**                                         | **Notes**                                        |
| ------------ | ------------------------------------------------------- | ------------------------------------------------ |
| 1️⃣            | **Run real external systems in Docker**                 | Easiest, ideal where feasible                    |
| 2️⃣            | **Use programmable/mock servers (e.g., OpenAPI-based)** | For REST APIs (like Salesforce)                  |
| 3️⃣            | **Modify Snap Packs to support mock mode**              | Most invasive, needed for SAP (binary protocols) |

## ⚙️ Configuration & Environment Design

Mock mode should:
- Work **without changing snap behavior**.
- Require **no external config** beyond the mock mode flag.
- Allow per-snap-pack mock control in future (mixed-mode testing).

## 📚 Snap Pack Testing Strategy Matrix

The following table provides a comprehensive overview of all Snap Packs and their testing strategies:

| **#** | **Snap Pack**  | **Strategy** | **Description** | **Implementation Details** | **Status** |
| ----- | -------------- | ------------ | --------------- | -------------------------- | ---------- |
| 1     | **API**        | Need to Check | | | |
| 2     | **DB2**        | Need to Check | | | |
| 3     | **FTP**        | Need to Check | | | |
| 4     | **JMS Queue**  | 1 | Run real external systems in Docker | - Apache ActiveMQ Artemis<br>- Docker image: `apache/activemq-artemis:latest`<br>- Exposed ports: 8161 (Console), 61617 (JMS), 61614 (STOMP), 5673 (AMQP)<br>- Admin creds: admin/admin<br>- Auto-create queues/addresses enabled<br>- CI-optimized memory settings (512MB max)<br>- Health check with 60s startup grace period | Completed |
| 5     | **Mainframes** | Need to Check | | | |
| 6     | **MFT**        | Need to Check | | | |
| 7     | **MySQL**      | 1 | Run real external systems in Docker | - Docker image: `mysql:8.0`<br>- Exposed port: 3306<br>- Database: TEST<br>- User: testuser/snaplogic<br>- Root password: snaplogic<br>- Native password authentication plugin<br>- Init scripts mount<br>- Health check with mysqladmin | Completed |
| 8     | **NFS**        | Need to Check | | | |
| 9     | **Oracle**     | 1 | Run real external systems in Docker | - Oracle Database Free 23c<br>- Docker image: `container-registry.oracle.com/database/free:23.7.0.0-lite`<br>- Exposed port: 1521<br>- Database: FREEPDB1<br>- Init scripts via volume mount<br>- Health check using sqlplus | Completed |
| 10    | **Postgres**   | 1 | Run real external systems in Docker | - Docker image: `postgres:15`<br>- Exposed port: 5435 (mapped to 5432)<br>- Database: snaplogic<br>- User: snaplogic/snaplogic<br>- Volume for data persistence | Completed |
| 11    | **S3**         | 1 | Run real external systems in Docker (MinIO Mockserver) | - MinIO S3-compatible server<br>- Docker image: `minio/minio:latest`<br>- Exposed ports: 9000 (API), 9001 (Console)<br>- Default creds: minioadmin/minioadmin<br>- Health check enabled<br>- Setup script for bucket initialization | Completed |
| 12    | **SAP IDocs**  | 3 | Modify Snap Packs to support mock mode | - Mock mode via Groundplex env variable<br>- Embedded SAP protocol simulator<br>- Binary protocol emulation | TBS (To be started) |
| 13    | **Salesforce** | 2 | Use programmable/mock servers (e.g., OpenAPI-based) | - OpenAPI-based mock server<br>- Programmable SOQL responses<br>- OAuth2 flow simulation | TBS (To be started) |
| 14    | **Snowflake**  | Need to Check | | - Presents a challenge due to custom SQL dialects<br>- Options: LocalStack preview mode, Snowflake's Python test framework, or using HTTP API mocks | |
| 15    | **SQL Server** | 1 | Run real external systems in Docker | - SQL Server 2022 Developer Edition<br>- Docker image: `mcr.microsoft.com/mssql/server:2022-latest`<br>- Platform: linux/amd64<br>- Exposed port: 1433<br>- Health check with sqlcmd<br>- Schema init scripts | Completed |
| 16    | **Teradata**   | 3 | Modify Snap Packs to support mock mode | | WIP |

> **Note:** This table will be continuously updated as we implement testing strategies for additional Snap Packs. Each new Snap Pack integration will be documented here with its chosen mocking approach, implementation details, and known limitations.

### Status Legend:
- **Completed**: Implementation is done and tested
- **WIP**: Work in Progress
- **TBS**: To be started
- **Need to Check**: Strategy needs to be determined

Ensure that **local testing strategies are repeatable** and **included in core documentation** for internal teams.

## 📋 Checklist: How to Add a Source Type to the Testing Framework

### 1. Determine Mocking Strategy
- [ ] Analyze the source type's protocol and capabilities
- [ ] Choose between Docker (1), Mock Server (2), or Mock Mode (3)
- [ ] Document the chosen strategy and rationale

### 2. Implementation Steps

#### For Docker-based Testing (Strategy 1):
- [ ] Identify appropriate Docker image
- [ ] Create docker-compose configuration
- [ ] Define initialization scripts/data
- [ ] Document container startup/teardown procedures

#### For Mock Server Testing (Strategy 2):
- [ ] Define OpenAPI specification or mock server configuration
- [ ] Implement request/response patterns
- [ ] Set up programmable responses for different test scenarios
- [ ] Configure authentication/authorization mocking

#### For Mock Mode Testing (Strategy 3):
- [ ] Implement mock mode in Snap Pack code
- [ ] Add Groundplex environment variable support
- [ ] Create embedded mock service (if needed)
- [ ] Ensure zero impact when mock mode is disabled

### 3. Test Framework Integration
- [ ] Create test data fixtures
- [ ] Implement connection configuration templates
- [ ] Add source-specific validation logic
- [ ] Create example test cases

### 4. Documentation
- [ ] Document setup instructions
- [ ] List prerequisites and dependencies
- [ ] Provide troubleshooting guide
- [ ] Include example configurations

### 5. CI/CD Integration
- [ ] Add to automated test suite
- [ ] Configure environment variables
- [ ] Set up test data provisioning
- [ ] Define cleanup procedures
