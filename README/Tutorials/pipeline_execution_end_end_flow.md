# Pipeline Setup Guide

This guide will help new team members set up and execute the SnapLogic pipeline project for the first time.

## Table of Contents

- [Pipeline Setup Guide](#pipeline-setup-guide)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Setup Steps](#setup-steps)
    - [1. Install Docker Desktop](#1-install-docker-desktop)
    - [2. Clone the Repository](#2-clone-the-repository)
    - [3. Install any IDE and Open Project](#3-install-any-ide-and-open-project)
    - [4. Environment Configuration](#4-environment-configuration)
    - [5. Navigate to Project Folder](#5-navigate-to-project-folder)
    - [6. Build Your Test Environment](#6-build-your-test-environment)
  - [What Happens After Execution](#what-happens-after-execution)
    - [🚀 Services Started](#-services-started)
    - [🚀 Tests Are Executed](#-tests-are-executed)
  - [What Gets Created For Minio (http://localhost:9000)](#what-gets-created-for-minio-httplocalhost9000)
    - [👤 MinIO User](#-minio-user)
    - [🪣 Buckets Created in MinIO](#-buckets-created-in-minio)
    - [📄 Files Created in Buckets](#-files-created-in-buckets)
  - [Troubleshooting](#troubleshooting)
  - [Need Help?](#need-help)

---

## Prerequisites

Before starting, ensure the following:

- You have access to the GitHub repository.
- You have the required permissions to clone and run the project.
- You have internet access to download tools and dependencies.

---

## Setup Steps

### 1. Install Docker Desktop

- Download and install Docker Desktop for your OS: [docker.com](https://www.docker.com/products/docker-desktop/)
- Start Docker Desktop and ensure it’s running.
- Verify the installation by running:

```bash
docker --version
```

### 2. Clone the Repository

- Create a new directory for your work.
- Clone the GitHub repository:

```bash
git clone https://github.com/SnapLogic/snaplogic-test-example
```

### 3. Install any IDE and Open Project

- Download and install [Visual Studio Code](https://code.visualstudio.com/).
- Open the project folder in VS Code:
  - Go to `File > Open Folder`, then select the cloned `snaplogic-test-example` folder.
  

### 4. Environment Configuration

- Navigate to the project root directory.
- Create a `.env` file:
  - Copy the contents of `.env.example` to a new file named `.env`.
  - Modify values as needed for your local environment.
  - Keep this file secure and do **not** check it into version control.

```bash
cp .env.example .env
```
Open the `.env` file and add your SnapLogic credentials:

```bash
URL=https://your.elastic.snaplogic.com/
ORG_ADMIN_USER=your_username@snaplogic.com
ORG_ADMIN_PASSWORD=your_password
ORG_NAME=your_organization
PROJECT_SPACE=TestSpace
PROJECT_NAME=FirstTest
GROUNDPLEX_NAME=my-test-groundplex
GROUNDPLEX_ENV=testenv
RELEASE_BUILD_VERSION=main-30027
```
**Important**: Replace the placeholder values with your actual SnapLogic credentials. Never commit this file to version control.

### 5. Navigate to Project Folder

In a terminal, navigate to the  project directory:

```bash
cd snaplogic-test-example
```

### 6. Build Your Test Environment

Start the required services and run the tests:

```bash
make snaplogic-start-tools         # Build the Docker containers that will run your tests:
make robot-run-all-tests TAGS="oracle"   # Runs Robot tests with the "oracle" tag and Starts Your Test Services
```

This creates a containerized environment with Robot Framework and all testing dependencies. The build process takes about 2-3 minutes.

To run additional test suites:

```bash
make robot-run-all-tests TAGS="oracle minio"
```

You can pass multiple tags separated by spaces to include additional test scenarios.

**Available Tags:**  
Refer to the `TAGS` section inside test files located at:

```
test/suite/pipeline_tests/
```

Explore the test files to find appropriate tags for your needs.

---

## What Happens After Execution

After executing the above commands, the following services will be launched automatically:

### 🚀 Services Started

- **Groundplex** is launched for SnapLogic pipeline execution.
- **Oracle Database** is started.
- **PostgreSQL Database** is started.
- **MinIO** (S3-compatible object store) is started and pre-configured.

### 🚀 Tests Are Executed
- **RobotFrameWork Tests** You'll see Robot Framework output showing each step. Look for green "PASS" messages.

  **In SnapLogic Org:** (Based on the values given in .env file)
   - Accounts are created
   - ProjectSpace is Created (If there is existing project space with the same name it will be deleted)
   - Project is Created
   - Pipeline is imported
   - Triggered task is created and Executed

---

## What Gets Created For Minio (http://localhost:9000)

### 👤 MinIO User

- **Username**: `demouser`
- **Password**: `demopassword`
- **Permissions**: `readwrite` policy (can read/write but not manage users)

### 🪣 Buckets Created in MinIO

- `demo-bucket`: Primary test data bucket
- `test-bucket`: Secondary bucket for additional tests

### 📄 Files Created in Buckets

- `welcome.txt` (inside `demo-bucket`): Contains a welcome message and timestamp.
- `setup-info.txt` (inside `test-bucket`): Similar content for verifying setup.
- `config.json` (inside `demo-bucket`): Metadata file with setup details.

These files are useful for verifying storage access during automated tests.

---

## Troubleshooting

- ✅ **Ensure Docker Desktop is running** before executing `make` commands.
- ✅ **Verify `.env` values**: Double-check that required environment variables are correctly set.
- ✅ **Permissions**: Ensure you have access to the repo and aren’t blocked by firewalls or policies.
- ✅ **Check logs**: If something fails, check terminal output or container logs using `docker compose logs`.

---

## Need Help?

If you encounter issues, please:

- Contact a team member on Slack.
- Open a GitHub issue if you suspect a bug.
- Reach out via email if onboarding support is needed.

We’re here to help you get started smoothly 🚀