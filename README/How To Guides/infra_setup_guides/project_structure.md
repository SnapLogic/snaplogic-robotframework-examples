# Project Structure

> **Note:** This project structure is continuously evolving! We're actively working to make the framework easier and more efficient to use, so expect improvements and changes over time.

```
snaplogic-robotframework-examples/
├── .env                           # Environment variables (credentials, URLs)
├── .env.example                   # Template for environment configuration
├── Makefile                       # Master build automation commands
├── docker-compose.yml             # Multi-container orchestration
├── robot.Dockerfile               # Robot Framework Docker image definition
├── .travis.yml                    # CI/CD pipeline configuration
├── .gitignore                     # Git exclusion rules
│
├── makefiles/                     # Modular build scripts
│   ├── common_services/           # Shared service operations
│   ├── database_services/         # Database container management
│   ├── messaging_services/        # Kafka/messaging setup makefiles
│   └── mock_services/             # Mock service containers
│
├── docker/                        # Docker configurations for all services
│   ├── groundplex/                # Groundplex container setup
│   ├── oracle/                    # Oracle database container
│   ├── postgres/                  # PostgreSQL container
│   ├── kafka/                     # Kafka messaging setup
│   └── ...                        # Other service configurations
│
├── env_files/                     # Service-specific environment variables
│   ├── database.env               # Database connection settings
│   ├── kafka.env                  # Messaging service config
│   └── ...                        # Other service env files
│
├── test/                          # Test suite directory
│   ├── suite/                     # Robot Framework test suites
│   │   ├── __init__.robot         # Suite initialization
│   │   └── pipeline_tests/        # Test cases organized by functionality
│   │       ├── oracle/            # Oracle-specific pipeline tests
│   │       ├── postgres_s3/       # PostgreSQL + S3 integration tests
│   │       └── kafka/             # Kafka messaging tests
│   │
│   └── test_data/                 # Test data and configurations
│       ├── input_files/           # Sample input data
│       └── expected_outputs/      # Expected test results
│
├── src/                           # Source code and pipelines
│   ├── pipelines/                 # Pipeline SLP files
│   │   ├── oracle_pipeline.slp    # Oracle integration pipeline
│   │   ├── kafka_pipeline.slp     # Kafka messaging pipeline
│   │   └── ...                    # Other pipeline definitions
│   │
│   └── tools/                     # Helper utilities
│       └── requirements.txt       # Python dependencies
│
├── shared-data/                   # Common data files shared across tests
│   └── reference_data/            # Reference datasets
│
├── activemq-data/                 # ActiveMQ message queue data persistence
│
├── travis_scripts/                # Travis CI-specific scripts
│   ├── build.sh                   # Build automation
│   └── deploy.sh                  # Deployment scripts
│
└── README/                        # Documentation
    └── setup_guide.md             # Setup and usage instructions
```

## High-Level Overview

| Directory/File | Purpose |
|----------------|---------|
| **`.env` / `.env.example`** | Store and template environment variables for credentials, URLs, and configuration settings |
| **`Makefile`** | Central command hub for building, testing, and managing the entire framework |
| **`docker-compose.yml`** | Orchestrates all Docker containers to spin up the complete test environment with one command |
| **`makefiles/`** | Modular build scripts organized by service type (database, messaging, mock services) for maintainable automation |
| **`docker/`** | Docker configurations for each service container (Groundplex, databases, Kafka, etc.) |
| **`env_files/`** | Service-specific environment variable files to isolate configuration per service |
| **`test/`** | Robot Framework test suites organized by pipeline functionality with corresponding test data |
| **`src/`** | SnapLogic pipeline SLP files being tested and helper tools including Python dependencies |
| **`shared-data/`** | Common data files and reference datasets used across multiple test scenarios |
| **`activemq-data/`** | Persistent storage for ActiveMQ message queue data |
| **`travis_scripts/`** | CI/CD automation scripts for Travis CI integration |
| **`README/`** | Project documentation and setup guides |

### External Dependency
**`snaplogic-common-robot`** - PyPI-published library (installed via requirements.txt) providing reusable Robot Framework keywords for SnapLogic API interactions

## Directory Descriptions

### Configuration Files
- **`.env`** - Main environment variables file containing credentials, API URLs, and configuration
- **`.env.example`** - Template showing required environment variables for setup
- **`Makefile`** - Master makefile with commands for build, test, and deployment
- **`docker-compose.yml`** - Orchestrates all Docker containers for the test environment
- **`robot.Dockerfile`** - Custom Docker image for running Robot Framework tests

### Build Automation (`makefiles/`)
Modular makefiles organized by service type:
- **`common_services/`** - Shared operations across all services
- **`database_services/`** - Database container lifecycle management
- **`messaging_services/`** - Kafka and messaging infrastructure setup
- **`mock_services/`** - Mock service containers for testing

### Infrastructure (`docker/`)
Docker configurations for each service in the test environment:
- **`groundplex/`** - SnapLogic Groundplex container setup
- **`oracle/`** - Oracle database container configuration
- **`postgres/`** - PostgreSQL database setup
- **`kafka/`** - Kafka messaging service
- Additional services as needed for pipeline testing

### Test Suite (`test/`)
Robot Framework test organization:
- **`suite/__init__.robot`** - Suite-level setup and teardown
- **`pipeline_tests/`** - Test cases organized by pipeline functionality
  - Tests are grouped by integration type (Oracle, PostgreSQL+S3, Kafka, etc.)
- **`test_data/`** - Input data and expected outputs for test validation

### Source Code (`src/`)
- **`pipelines/`** - SnapLogic pipeline SLP files being tested
- **`tools/`** - Supporting utilities and helper scripts
- **`requirements.txt`** - Python dependencies for the framework

### Supporting Directories
- **`shared-data/`** - Common data files used across multiple tests
- **`activemq-data/`** - Persistent data for ActiveMQ message queues
- **`travis_scripts/`** - CI/CD automation scripts for Travis CI
- **`README/`** - Project documentation and setup guides

## Workflow

1. **Configuration**: Set up `.env` file with required credentials and URLs
2. **Build**: Run `make build` to create Docker images using makefiles
3. **Start Services**: `docker-compose up` launches all required containers
4. **Run Tests**: Execute Robot Framework tests against live services
5. **Generate Reports**: HTML/XML test reports are automatically created
6. **Cleanup**: Use `make clean` to tear down containers and clean up

## Key Benefits

- **Modular Architecture**: Service-specific makefiles enable independent management
- **Environment Isolation**: Docker containers provide clean, reproducible test environments
- **CI/CD Ready**: Travis CI integration for continuous testing
- **Reusable Components**: Common Robot Framework library shared across all tests
- **Scalable**: Easy to add new services or test suites
