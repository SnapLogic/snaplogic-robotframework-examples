# 🚀 Pipeline Execution: 5-Step Quick Start

## ⚡ Step 1: Install Docker Desktop
Download and install Docker Desktop for your OS, start it, and verify installation with `docker --version`

## 📥 Step 2: Clone the Repository
Create a working directory and clone the GitHub repository:
```bash
git clone https://github.com/SnapLogic/snaplogic-robotframework-examples
```

## 💻 Step 3: Open Project (Either in IDE or Terminal)
Download VS Code (or any preferred IDE) and open the project folder, or work directly from terminal

## ⚙️ Step 4: Configure Environment
Copy the contents of `.env.example` to a new file named `.env` and update env values as per project requirements:
```bash
cp .env.example .env
```
Then edit the `.env` file with your actual SnapLogic credentials, organization details, and project settings

## 🏗️ Step 5: Build and Execute
Build your test environment using make commands:
```bash
make snaplogic-start-tools # Build the Docker containers that will run your tests:
make robot-run-all-tests TAGS="oracle" # Runs Robot tests with the "oracle" tag and Starts Your Test Services
```

> **⏱️ Note:** This creates a containerized environment with Robot Framework and all testing dependencies. The build process takes about 2-3 minutes.

---

✅ **You're all set!** Your SnapLogic Robot Framework testing environment is ready to go.

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