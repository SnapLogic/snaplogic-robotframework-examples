# Getting Started with Robot Automation Framework

**Reference links for high level demo recording:** [Snaplogic Test Example Framework Overview](https://drive.google.com/file/d/1Ub-bQtmNfL_BiXGMb2k3ocRMGjfn0mhf/view?usp=drive_link)

## Prerequisites

Before you begin, make sure you have access to the project repository:

**Repository:** https://github.com/SnapLogic/snaplogic-test-example

### Connect your GitHub account

If this is a private repository, ensure your GitHub account has been granted access. You may need to request access from the repository administrator.

### Clone the repository locally

Open your terminal and run:

```bash
git clone https://github.com/SnapLogic/snaplogic-test-example.git
cd snaplogic-test-example
```

This repository contains all the necessary configurations, templates, and automation scripts. You'll be working from it throughout the entire setup and execution process.

## Pre-requisite: Pipeline File (.slp)

⚠️ **Important:** Before running any tests, it's assumed that you already have a valid `.slp` SnapLogic pipeline file ready to be imported. This file is essential for executing test workflows within the framework.

## Recommended Prerequisites

To make the most of this automation framework, we recommend having a basic understanding of the following technologies:

### Docker & Containers
Understand how containerized environments work and how Docker is used to manage services.
👉 [Docker 101 Tutorial](https://docs.docker.com/get-started/)

### Robot Framework
Familiarize yourself with this open-source test automation framework. It's used for writing and executing the tests in this project.
👉 [Robot Framework Introduction](https://robotframework.org/)

### Make & Makefiles
Learn how make commands work and how Makefiles are structured. This project uses Makefile targets extensively to manage tasks.
👉 [Makefile Tutorial](https://makefiletutorial.com/)

## Step 1: Install Docker Desktop

Ensure Docker Desktop is installed and running on your system. It's essential for launching the containerized environment that powers the SnapLogic ML migration framework.

## Step 2: Configure Environment Variables

Start by copying the example environment configuration:

```bash
cp .env.example .env
```

The `.env` file contains all necessary configuration values. Below is a sample of `.env.example`. Update and extend it as needed:

```bash
# Configuration for the SnapLogic ML migration project
URL=https://example.com/
ORG_ADMIN_USER=your_username
ORG_ADMIN_PASSWORD=your_password
ORG_NAME=org_name
ORG_SNODE_ID=org_snode_id
PROJECT_SPACE=project_space
PROJECT_NAME=project_name

# Configuration for the SnapLogic Groundplex
GROUNDPLEX_NAME=groundplex_name
GROUNDPLEX_ENV=groundplex_environment_name
GROUNDPLEX_LOCATION_PATH=project_space/project_name/shared
RELEASE_BUILD_VERSION=main-30027

# Configuration for the Oracle database connection
# Ensure the Oracle DB is reachable from SnapLogic
ACCOUNT_LOCATION_PATH=project_space/project_name/shared
ORACLE_ACCOUNT_NAME=oracle_account_name
ORACLE_HOST=oracle_oracle-hostname
ORACLE_DBNAME=dbname
ORACLE_DBUSER=oracle_username
ORACLE_DBPASS=oracle_password
```

## Step 3: snaplogic package

The `snaplogic-common-robot` library, which includes reusable Robot Framework keywords, is published to public pypi.

### robot.Dockerfile Key Steps:

1. Initializes a Python environment
2. Installs Python packages listed in `requirements.txt`

## Step 4: Understanding requirements.txt

This file lists all the Python dependencies, including `snaplogic-common-robot`, required to run the automation framework.

If your project needs additional tools or database drivers, add them here.

## Step 5: Launch the Tools Container

Run the following command to start the essential services:

```bash
make snaplogic-start-services
```

This step will also generate a new `.env` file with runtime-specific variables that can be reused in later stages.

## Step 6: Run the Full Automation Workflow

Once your environment is set up and the `.env` file is configured, run the following command to execute all automation steps:

```bash
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True # If you already have project space set up ready ignore the argument PROJECT_SPACE_SETUP=True
```

This command performs the full end-to-end automation flow, including:

- **Plex Creation** – Sets up a new SnapLogic Plex
- **Groundplex Launch** – Spins up and registers the Groundplex service
- **Project Space & Project Creation** – Creates a new project space and project
- **Account Creation** – Creates the necessary Oracle account in the defined location
- **Pipeline Import** – Imports the specified `.slp` pipeline into the project
- **Triggered Task Setup** – Creates a triggered task to execute the pipeline

Make sure the `.slp` pipeline file is ready and correctly referenced as mentioned in the prerequisites.