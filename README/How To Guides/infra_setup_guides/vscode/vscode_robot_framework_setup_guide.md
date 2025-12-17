# VSCode Setup Guide for Robot Framework Testing

This guide helps new team members set up Visual Studio Code for navigating and working with Robot Framework tests in our Docker-based test framework.

---

## Prerequisites

Before starting, ensure you have:
- **Docker Desktop** installed and running
- **Visual Studio Code** installed
- Access to the `snaplogic-robotframework-examples` repository

> **Note:** You do NOT need to install Robot Framework locally. All tests run inside Docker containers. However, for VSCode code navigation (Cmd+Click) to work, you'll need a local Python environment with the dependencies.

---

## Step 1: Clone the Repository

```bash
git clone <repository-url>
cd snaplogic-robotframework-examples
```

---

## Step 2: Install Required VSCode Extensions

Open VSCode and install these extensions (`Cmd+Shift+X` on Mac / `Ctrl+Shift+X` on Windows):

| Extension | Publisher | Purpose |
|-----------|-----------|---------|
| **Robot Framework Language Server** | Robocorp | Syntax highlighting, code navigation, autocomplete |
| **Python** | Microsoft | Python interpreter support |
| **Docker** | Microsoft | Docker container management (optional but recommended) |

### How to Install:
1. Click the Extensions icon in the sidebar (or press `Cmd+Shift+X`)
2. Search for "Robot Framework Language Server"
3. Click **Install**
4. Repeat for other extensions

---

## Step 3: Set Up Local Python Environment (for Code Navigation)

Even though tests run in Docker, VSCode needs a local Python environment for code navigation features like `Cmd+Click`.

### Create a virtual environment and install dependencies:
```bash
# Create virtual environment
python3 -m venv .venv

# Activate it
source .venv/bin/activate  # Mac/Linux
# OR
.venv\Scripts\activate     # Windows

# Install all dependencies from requirements.txt
pip install -r {{cookiecutter.primary_pipeline_name}}/src/tools/requirements.txt
```

### What gets installed from requirements.txt:

| Package | Purpose |
|---------|---------|
| `snaplogic-common-robot` | SnapLogic-specific Robot Framework keywords (see below for included libraries) |
| `oracledb` | Oracle database driver |
| `psycopg2-binary` | PostgreSQL database driver |
| `pymssql` | Microsoft SQL Server database driver |
| `pymysql` | MySQL database driver |
| `ibm_db` | IBM DB2 database driver |
| `teradatasql` | Teradata database driver |
| `snowflake-connector-python` | Snowflake database driver |
| `cryptography` | Required for Snowflake key pair authentication |
| `minio` | MinIO/S3 client for object storage testing |
| `kafka-python` | Kafka client for message queue testing |
| `stomp-py` | STOMP protocol client (ActiveMQ, Artemis, RabbitMQ) |

### Libraries bundled with snaplogic-common-robot:

When you install `snaplogic-common-robot`, the following Robot Framework libraries are automatically included:

| Package | Purpose |
|---------|---------|
| `robotframework>=3.2` | Core Robot Framework |
| `robotframework-requests` | HTTP/REST API testing keywords |
| `robotframework-docker` | Docker container management keywords |
| `robotframework-databaselibrary` | Database testing keywords |
| `robotframework-jsonlibrary` | JSON manipulation keywords |
| `robotframework-robocop` | Robot Framework static code analyzer/linter |
| `robotframework-tidy` | Robot Framework code formatter |
| `robotframework-dependencylibrary` | Test dependency management |
| `robotframework-pabot` | Parallel test execution |
| `robotframework-csvlibrary` | CSV file handling keywords |

**Supporting libraries also included:**

| Package | Purpose |
|---------|---------|
| `requests` | HTTP client |
| `jinja2` | Template rendering |
| `envyaml` | YAML config with environment variable support |
| `deepdiff` | Deep comparison of objects |
| `pyyaml` | YAML parsing |
| `tabulate` | Table formatting for output |
| `awscli` | AWS command-line interface |
| `boto3` | AWS SDK for Python |
| `python-dotenv` | Load environment variables from .env files |
| `cookiecutter` | Project templating |

> **Note:** Some database drivers (like `ibm_db`) may require additional system dependencies. If installation fails for a specific driver, you can comment it out in the requirements file if you don't need it for your testing.

---

## Step 4: Select Python Interpreter in VSCode

1. Open Command Palette: `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows)
2. Type: `Python: Select Interpreter`
3. Choose the `.venv` Python interpreter you just created

---

## Step 5: Configure Workspace Settings

Create a `.vscode` folder in the project root (if it doesn't exist) and add a `settings.json` file:

### File: `.vscode/settings.json`

```json
{
    "robot.pythonpath": [
        "${workspaceFolder}",
        "${workspaceFolder}/{{cookiecutter.primary_pipeline_name}}/src",
        "${workspaceFolder}/{{cookiecutter.primary_pipeline_name}}/test",
        "${workspaceFolder}/{{cookiecutter.primary_pipeline_name}}/src/tools"
    ],
    "robot.variables": {
        "EXECDIR": "${workspaceFolder}"
    },
    "editor.formatOnSave": true,
    "files.associations": {
        "*.robot": "robotframework",
        "*.resource": "robotframework"
    },
    "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python"
}
```

> **Important:** After generating a project from the cookiecutter template, update the paths to match your actual project structure.

---

## Step 6: Restart VSCode

After making configuration changes:
1. Close VSCode completely
2. Reopen your project folder

---

## Running Tests (Docker-based)

Tests run inside Docker containers, NOT locally.

> **For detailed instructions on running tests, see:** [Pipeline Execution 5-Step Quick Start](../../../Tutorials/03.pipelineExecution_5-step%20quick%20start.md)

---

## Enabling Cmd+Click (Go to Definition)

For `Cmd+Click` (Mac) or `Ctrl+Click` (Windows) navigation to work:

### Checklist:
- [ ] Robot Framework Language Server extension is installed and enabled
- [ ] Local `.venv` is created with `robotframework` and `snaplogic-common-robot` installed
- [ ] Correct Python interpreter (`.venv`) is selected in VSCode
- [ ] `robot.pythonpath` includes directories containing your keywords/resources
- [ ] VSCode has been restarted after configuration changes

### Common Issues and Solutions:

| Issue | Solution |
|-------|----------|
| Cmd+Click does nothing | Ensure extension is installed and `.venv` interpreter is selected |
| "Keyword not found" errors | Add the keyword file's directory to `robot.pythonpath` |
| `snaplogic-common-robot` keywords not found | Run `pip install snaplogic-common-robot` in your `.venv` |
| Extension not recognizing .robot files | Check `files.associations` in settings |

---

## Project Structure Overview

```
snaplogic-robotframework-examples/
├── {{cookiecutter.primary_pipeline_name}}/
│   ├── docker-compose.yml          # Main Docker Compose file
│   ├── src/
│   │   └── tools/
│   │       └── requirements.txt    # Python dependencies (for Docker)
│   ├── test/
│   │   └── suite/                  # Test suites go here
│   └── docker/                     # Docker configurations
├── Makefile                        # Build/test commands
└── .vscode/
    └── settings.json               # VSCode configuration
```

---

## Useful Keyboard Shortcuts

| Action | Mac | Windows |
|--------|-----|---------|
| Go to Definition | `Cmd+Click` | `Ctrl+Click` |
| Find All References | `Shift+F12` | `Shift+F12` |
| Quick Open File | `Cmd+P` | `Ctrl+P` |
| Command Palette | `Cmd+Shift+P` | `Ctrl+Shift+P` |
| Toggle Terminal | `` Ctrl+` `` | `` Ctrl+` `` |
| Format Document | `Shift+Option+F` | `Shift+Alt+F` |

---

## Troubleshooting

### Keywords Not Recognized
1. Verify `snaplogic-common-robot` is installed in your local `.venv`
2. Check that the file path in `robot.pythonpath` is correct
3. Look at the Output panel: `View > Output > Robot Framework`

### Docker Issues
1. Ensure Docker Desktop is running
2. Check container logs: `docker-compose logs -f`
3. Rebuild if needed: `docker-compose build --no-cache`

### Extension Not Working
1. Check extension output: `View > Output > Robot Framework`
2. Ensure no conflicting Robot Framework extensions are installed
3. Try disabling and re-enabling the extension

---

## Quick Start Checklist

- [ ] Docker Desktop installed and running
- [ ] VSCode installed
- [ ] Repository cloned
- [ ] Robot Framework Language Server extension installed
- [ ] Python extension installed
- [ ] Local `.venv` created with `robotframework` and `snaplogic-common-robot`
- [ ] `.venv` interpreter selected in VSCode
- [ ] `.vscode/settings.json` configured with correct paths
- [ ] VSCode restarted
- [ ] Cmd+Click navigation verified working

---

*Last updated: December 2024*
