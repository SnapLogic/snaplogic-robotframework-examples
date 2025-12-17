# Cookiecutter Project Generation Guide

This guide explains how to use Cookiecutter to generate customized test projects from the `snaplogic-robotframework-examples` template.

---

## What is Cookiecutter?

**Cookiecutter** is a command-line tool that creates projects from project templates. It allows you to:

- Generate new projects with a predefined structure
- Customize projects based on user input (prompts)
- Include/exclude files based on your selections
- Automate repetitive project setup tasks

Instead of manually copying files and editing configurations, Cookiecutter handles this automatically based on your inputs.

### How Cookiecutter Works (General Concept)

```
┌─────────────────────────────────────────────────────────────────┐
│                     COOKIECUTTER TEMPLATE                       │
│                                                                 │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐│
│  │  cookiecutter.json  │    │  {{cookiecutter.project_name}}/ ││
│  │  (defines prompts)  │    │  (template directory)           ││
│  └─────────────────────┘    └─────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────┐                                        │
│  │  hooks/             │                                        │
│  │  (pre/post scripts) │                                        │
│  └─────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ cookiecutter command
                              │ (prompts user for input)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     GENERATED PROJECT                           │
│                                                                 │
│  my_custom_project/                                             │
│  ├── docker-compose.yml    (customized)                         │
│  ├── Makefile              (customized)                         │
│  ├── src/                                                       │
│  ├── test/                                                      │
│  └── ...                                                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## How Cookiecutter Works in This Repository

### Template Structure

```
snaplogic-robotframework-examples/
├── cookiecutter.json                              # Configuration & prompts
├── hooks/
│   └── post_gen_project.py                        # Post-generation cleanup script
└── {{cookiecutter.primary_pipeline_name}}/        # Template directory
    ├── system_mappings.json                       # System-to-file mappings
    ├── docker-compose.yml
    ├── Makefile
    ├── src/
    ├── test/
    └── ...
```

### Key Files Explained

#### 1. `cookiecutter.json` - Configuration File

This file defines the prompts shown to users during project generation:

```json
{
    "primary_pipeline_name": "demo_project",
    "included_systems": "oracle,postgres,mysql,sqlserver,db2,teradata,snowflake,salesforce,kafka,activemq,s3,email"
}
```

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `primary_pipeline_name` | Name for your generated project | `demo_project` |
| `included_systems` | Comma-separated list of systems to include | All systems |

#### 2. `system_mappings.json` - System-to-File Mappings

This file maps each system (oracle, postgres, kafka, etc.) to its associated files and directories. The post-generation hook uses this to determine which files to keep or remove based on your selections.

**Structure:**

```json
{
  "oracle": {
    "docker_path": "docker/oracle/**",
    "env_path": "env_files/database_accounts/.env.oracle",
    "makefile_path": "makefiles/database_services/Makefile.oracle",
    "pipeline_path": "src/pipelines/oracle.slp",
    "tests_path": "test/suite/pipeline_tests/*oracle*",
    "accounts_path": "test/suite/test_data/accounts_payload/acc_oracle.json"
  },
  "kafka": {
    "docker_path": "docker/kafka/**",
    "env_path": "env_files/messaging_service_accounts/.env.kafka",
    "makefile_path": "makefiles/messaging_services/Makefile.kafka",
    "pipeline_path": "src/pipelines/kafka.slp",
    "resources_path": "test/resources/kafka/**",
    "libraries_path": "test/libraries/kafka/**",
    "tests_path": "test/suite/pipeline_tests/*kafka*",
    "accounts_path": "test/suite/test_data/accounts_payload/acc_kafka.json"
  }
}
```

**What Each Path Represents:**

| Key | Description |
|-----|-------------|
| `docker_path` | Docker configuration files for the service |
| `env_path` / `env_paths` | Environment variable files with credentials |
| `makefile_path` | Makefile with service-specific targets |
| `pipeline_path` / `pipeline_paths` | SnapLogic pipeline files (.slp) |
| `tests_path` | Robot Framework test files |
| `resources_path` | Robot Framework resource files |
| `libraries_path` | Custom Python libraries for testing |
| `accounts_path` | SnapLogic account configuration JSON files |

#### 3. `hooks/post_gen_project.py` - Post-Generation Hook

This Python script runs automatically after the project is generated. It performs the following steps:

| Step | Action |
|------|--------|
| 1 | Parse the `included_systems` input |
| 2 | Validate system names (with typo suggestions) |
| 3 | Load `system_mappings.json` |
| 4 | Remove files for **excluded** systems |
| 5 | Update `docker-compose.yml` (remove unused services) |
| 6 | Update `Makefile` (remove unused includes) |
| 7 | Update `COMPOSE_PROFILES` in Makefile.common |
| 8 | Remove empty directories |
| 9 | Clean up template artifacts |

---

## Available Systems

You can include any combination of these systems:

| System | Type | Description |
|--------|------|-------------|
| `oracle` | Database | Oracle Database |
| `postgres` | Database | PostgreSQL Database |
| `mysql` | Database | MySQL Database |
| `sqlserver` | Database | Microsoft SQL Server |
| `db2` | Database | IBM DB2 |
| `teradata` | Database | Teradata |
| `snowflake` | Database | Snowflake Data Warehouse |
| `salesforce` | Mock Service | Salesforce (mock) |
| `kafka` | Messaging | Apache Kafka |
| `activemq` | Messaging | Apache ActiveMQ/Artemis (JMS) |
| `s3` | Storage | S3-compatible storage (MinIO) |
| `email` | Mock Service | Email service (MailDev) |

---

## Generating a New Project

### Option 1: Using the Cookiecutter Command Directly

```bash
# Navigate to the template repository
cd snaplogic-robotframework-examples

# Generate a new project (interactive)
cookiecutter .

# You'll be prompted:
# primary_pipeline_name [demo_project]: my_oracle_tests
# included_systems [oracle,postgres,...]: oracle,postgres
```

**With command-line arguments (non-interactive):**

```bash
# Generate with specific values
cookiecutter . --no-input \
  primary_pipeline_name=my_kafka_project \
  included_systems=kafka,postgres
```

**Generate to a specific output directory:**

```bash
cookiecutter . -o /path/to/output/directory
```

### Option 2: Using the Make Command

The repository includes a `Makefile` with a convenient target for project generation:

```bash
# Generate project to parent directory (default)
make generate-project

# Generate project to current directory
make generate-project OUTPUT_DIR=.

# Generate project to a specific location
make generate-project OUTPUT_DIR=/Users/username/Projects

# Generate project to home directory
make generate-project OUTPUT_DIR=~/QADocs
```

**Make target reference:**

```makefile
generate-project:
    @echo "🔨 Generating project from cookiecutter template..."
    @echo "📁 Output directory (relative): $(OUTPUT_DIR)"
    @mkdir -p $(OUTPUT_DIR)
    @echo "📂 Output directory (absolute): $$(cd $(OUTPUT_DIR) && pwd)"
    @cookiecutter . -o $(OUTPUT_DIR)
```

---

## Example: Generating a Project

### Step 1: Run the command

```bash
cd snaplogic-robotframework-examples
make generate-project OUTPUT_DIR=~/Projects
```

### Step 2: Answer the prompts

```
primary_pipeline_name [demo_project]: oracle_kafka_tests
included_systems [oracle,postgres,mysql,...]: oracle,kafka
```

### Step 3: Post-generation output

```
🧭 Project Setup Information
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Project root: /Users/username/Projects/oracle_kafka_tests
📝 Project name: oracle_kafka_tests
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 Configuring project for systems: oracle, kafka
✅ Loaded cleanup patterns from system_mappings.json

🧹 Starting pattern-based cleanup...
   Systems to KEEP: oracle, kafka
   ✓ Removed 45 files from excluded systems
   ✓ Protected 12 files

🔧 Updating docker-compose.yml...
   ✓ Removed 8 service includes

📝 Updating Makefile...
   ✓ Removed 10 Makefile includes

==================================================
🎉 PROJECT CONFIGURATION COMPLETE!
==================================================
📦 Project: oracle_kafka_tests
🔧 Systems: oracle, kafka
🐳 Docker Profiles: tools,oracle-dev,kafka
📁 Location: /Users/username/Projects/oracle_kafka_tests
==================================================
```

### Step 4: Generated project structure

```
oracle_kafka_tests/
├── docker-compose.yml           # Only oracle & kafka services
├── Makefile                     # Only oracle & kafka includes
├── docker/
│   ├── oracle/                  # ✓ Included
│   ├── kafka/                   # ✓ Included
│   └── groundplex/              # ✓ Always included
├── env_files/
│   ├── database_accounts/
│   │   └── .env.oracle          # ✓ Included
│   └── messaging_service_accounts/
│       └── .env.kafka           # ✓ Included
├── src/
│   └── pipelines/
│       ├── oracle.slp           # ✓ Included
│       └── kafka.slp            # ✓ Included
└── test/
    └── suite/
        └── pipeline_tests/
            ├── *oracle*.robot   # ✓ Included
            └── *kafka*.robot    # ✓ Included
```

---

## Tips and Best Practices

### 1. Use "all" to keep everything

If you want all systems (useful for development):

```bash
included_systems: all
```

### 2. Typo detection

The post-generation hook includes typo detection:

```
⚠️  Error: Unknown systems specified: ['oracl', 'kafak']
   'oracl' → Did you mean: oracle?
   'kafak' → Did you mean: kafka?
```

### 3. Start small

For learning or focused testing, start with 1-2 systems:

```bash
included_systems: postgres
```

### 4. Verify the generated project

After generation, check:

```bash
cd oracle_kafka_tests
ls docker/           # Should only have selected systems
cat Makefile         # Should only include selected makefiles
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "cookiecutter: command not found" | Install with `pip install cookiecutter` |
| Empty project generated | Check that `included_systems` has valid values |
| Files not being removed | Verify `system_mappings.json` has correct paths |
| Permission denied | Check write permissions on output directory |

---

## Related Documentation

- [Pipeline Execution 5-Step Quick Start](../../Tutorials/03.pipelineExecution_5-step%20quick%20start.md)
- [VSCode Setup Guide](../vscode/vscode_robot_framework_setup_guide.md)
- [Cookiecutter Official Documentation](https://cookiecutter.readthedocs.io/en/stable/tutorials/index.html)

---

*Last updated: December 2024*
