# Windows, Linux, WSL & Ubuntu — Fundamentals for SnapLogic Robot Framework

A comprehensive guide for developers new to Windows machines, explaining the core concepts behind WSL, Ubuntu, and why they matter for running the SnapLogic Robot Framework automation project.

---

## Table of Contents

1. [Two Different Worlds — Windows vs Linux](#1-two-different-worlds--windows-vs-linux)
2. [What Is a Shell?](#2-what-is-a-shell)
3. [What Is Ubuntu?](#3-what-is-ubuntu)
4. [What Is WSL?](#4-what-is-wsl)
5. [WSL 1 vs WSL 2](#5-wsl-1-vs-wsl-2)
6. [WSL Distributions — The Common Pitfall](#6-wsl-distributions--the-common-pitfall)
7. [How The Pieces Connect For Our Project](#7-how-the-pieces-connect-for-our-project)
8. [Key Concepts Cheat Sheet](#8-key-concepts-cheat-sheet)
9. [Step-by-Step Fix — Getting Everything Working](#9-step-by-step-fix--getting-everything-working)
10. [File Path Mapping Between Windows and WSL](#10-file-path-mapping-between-windows-and-wsl)
11. [Common Mistakes and How to Avoid Them](#11-common-mistakes-and-how-to-avoid-them)
12. [Quick Reference Commands](#12-quick-reference-commands)
13. [Next Steps](#13-next-steps)

---

## 1. Two Different Worlds — Windows vs Linux

Think of your computer as a house. The **operating system (OS)** is the foundation and plumbing. Windows and Linux are two completely different architectural styles.

### Side-by-Side Comparison

| Aspect | Windows | Linux |
|--------|---------|-------|
| **Built by** | Microsoft | Open-source community |
| **Shell** | PowerShell, CMD | Bash, Zsh |
| **Packages** | `.exe`, `.msi` | `apt`, `yum`, `dnf` |
| **File paths** | `C:\Users\folder` | `/home/user/folder` |
| **Line endings** | `\r\n` (CRLF) | `\n` (LF) |
| **Case sensitivity** | NOT sensitive (`File.txt` = `file.txt`) | SENSITIVE (`File.txt` ≠ `file.txt`) |
| **Install tools** | `choco`, `winget` | `apt`, `dnf`, `apk` |
| **Native binaries** | `.exe` | ELF binaries |

### Why This Matters For Our Project

The SnapLogic Robot Framework automation project was **built for Linux**. All the `Makefile` commands, Docker Compose files, and shell scripts assume a Linux environment. Windows cannot natively understand them. This is why we need WSL.

---

## 2. What Is a Shell?

A **shell** is how you talk to your computer via text commands. Different operating systems use different shells — and they speak different languages.

### Shells Compared

| Shell | Where It Runs | Example Command | Prompt Looks Like |
|-------|--------------|-----------------|-------------------|
| **PowerShell** | Windows | `Get-ChildItem C:\Users` | `PS C:\>` |
| **CMD** | Windows | `dir C:\Users` | `C:\>` |
| **Bash** | Linux/Mac | `ls /home/user` | `user@pc:~$` |

### Can I Run `make` Here?

| Prompt You See | Shell | Can Run `make`? |
|----------------|-------|-----------------|
| `PS C:\>` | PowerShell | **No** — `make` is a Linux tool |
| `C:\>` | CMD | **No** — same problem |
| `user@PC MINGW64` | Git Bash | **Maybe** — limited compatibility |
| `user@pc:~$` | WSL/Ubuntu Bash | **Yes** ✅ |

**Key takeaway:** If your terminal prompt starts with `PS` or `C:\`, you are in Windows land. You need to switch to WSL/Ubuntu before running project commands.

### How to "Switch to WSL/Ubuntu" — What That Actually Means

When you open a terminal on Windows, it starts in **PowerShell** or **CMD** by default. "Switching to WSL/Ubuntu" means **changing your terminal session from the Windows shell to the Linux shell**. There are 3 ways to do it:

#### Way 1: Type `wsl` in Your Current Terminal

You are in PowerShell and see this prompt:

```
PS C:\Users\YourName>
```

Type `wsl` and press Enter. The prompt changes to:

```
yourname@DESKTOP-ABC123:/mnt/c/Users/YourName$
```

That's it — you switched. `make` commands will now work. To go back to PowerShell, type `exit`.

#### Way 2: Use the VS Code Terminal Dropdown

In VS Code, look at the top-right corner of the terminal panel. There is a **dropdown arrow (▼)** next to the `+` button. Click it and select **Ubuntu (WSL)**. A new terminal tab opens directly in Ubuntu:

```
┌─────────────────────────────────────────────┐
│  TERMINAL                          ▼  +  ⊟  │
│  powershell    Ubuntu (WSL)                  │
│                                              │
│  yourname@DESKTOP:~$                         │  ← Now in Ubuntu
└──────────────────────────────────────────────┘
```

#### Way 3: Set Ubuntu as Default Terminal (Recommended — Do Once, Never Think About It Again)

This is the best option. After this, **every new terminal in VS Code automatically starts in Ubuntu**.

1. Press `Ctrl+Shift+P` in VS Code
2. Type: `Terminal: Select Default Profile`
3. Select **Ubuntu (WSL)** from the list

From now on, every new terminal opens in Linux. No manual switching needed.

#### How Do I Know Which Shell I'm In?

| You See This Prompt | You're In | `make` Works? |
|---|---|---|
| `PS C:\Users\Name>` | PowerShell (Windows) | **No** |
| `C:\Users\Name>` | CMD (Windows) | **No** |
| `yourname@DESKTOP:~$` | Ubuntu / WSL (Linux) | **Yes** ✅ |

> **Quick check:** A `$` at the end of the prompt means Linux/Bash. If you see `PS` or `C:\>`, you are still in Windows.

---

## 3. What Is Ubuntu?

**Linux** is not one thing — it is a **kernel** (the engine). Different teams build complete operating systems on top of that kernel. These are called **distributions** (distros).

### Linux = The Engine, Ubuntu = The Car

| Distribution | Package Manager | Install `make` Command | Family |
|-------------|----------------|----------------------|--------|
| **Ubuntu** | `apt` | `sudo apt install make` | Debian |
| **Debian** | `apt` | `sudo apt install make` | Debian |
| **Fedora** | `dnf` | `sudo dnf install make` | Red Hat |
| **CentOS** | `yum` | `sudo yum install make` | Red Hat |
| **Alpine** | `apk` | `apk add make` | Independent |

**Ubuntu** is the most popular and beginner-friendly distribution. It is the recommended distro for WSL and for this project.

### Why Does the Package Manager Matter?

Each distro uses a different command to install software:

- **On Ubuntu:** `sudo apt install git` ✅
- **On Fedora:** `sudo dnf install git` ✅
- **On CentOS:** `sudo yum install git` ✅

Using the wrong package manager on the wrong distro will fail. For example, typing `dnf install make` inside Ubuntu will give you `command not found` because Ubuntu uses `apt`, not `dnf`.

---

## 4. What Is WSL?

**WSL = Windows Subsystem for Linux**

It is Microsoft's solution to the "two worlds" problem. WSL lets you run a **real Linux environment inside Windows** — no dual boot, no separate machine, no slow virtual machines.

### Before WSL vs After WSL

**Before WSL — your only options to run Linux on Windows:**

- **Dual boot** — Restart your computer every time you switch OS
- **Virtual Machine (VirtualBox, VMware)** — Slow, eats RAM, clunky
- **Separate Linux server** — Extra hardware, SSH access needed

**With WSL — Linux runs alongside Windows:**

- Open a terminal, type `wsl`, you are in Linux instantly
- Your Windows files are accessible from Linux at `/mnt/c/`
- Your Linux files are accessible from Windows at `\\wsl$\Ubuntu\`
- Near-native performance
- Docker integrates seamlessly

### How WSL Fits In

```
┌───────────────────────────────────────┐
│           Your Computer               │
│                                       │
│  ┌─────────────────────────────────┐  │
│  │          Windows OS             │  │
│  │                                 │  │
│  │   ┌─────────────────────────┐   │  │
│  │   │      WSL Layer          │   │  │
│  │   │                         │   │  │
│  │   │  ┌───────────────────┐  │   │  │
│  │   │  │     Ubuntu        │  │   │  │
│  │   │  │  bash, make, gcc  │  │   │  │
│  │   │  │  apt, docker      │  │   │  │
│  │   │  └───────────────────┘  │   │  │
│  │   │                         │   │  │
│  │   └─────────────────────────┘   │  │
│  │                                 │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
```

WSL is an apartment built inside your house. It has its own plumbing (Linux kernel), its own tools (`bash`, `make`, `apt`), but it shares the same roof (your hardware) and can access the house's storage (your `C:\` drive).

---

## 5. WSL 1 vs WSL 2

There are two versions of WSL. **Version 2 is required for this project.**

| Aspect | WSL 1 | WSL 2 |
|--------|-------|-------|
| **How it works** | Translates Linux calls to Windows calls | Runs a real Linux kernel in a lightweight VM |
| **Performance** | Slower for file I/O | Much faster |
| **Docker support** | ❌ No native support | ✅ Full Docker support |
| **Linux compatibility** | Partial — some things break | Full — everything works |
| **Network** | Shares Windows network | Has its own virtual network |
| **For our project** | ❌ Will not work | ✅ Required |

### How to Check Your WSL Version

Open PowerShell and run:

```powershell
wsl --list --verbose
```

Look at the `VERSION` column:

```
  NAME            STATE           VERSION
* Ubuntu          Running         2          ← This MUST be 2
```

If it shows `1`, upgrade it:

```powershell
wsl --set-version Ubuntu 2
```

---

## 6. WSL Distributions — The Common Pitfall

WSL can have **multiple Linux distros installed at the same time**. One of them is the **default** — the one that launches when you type `wsl`.

### The Problem: Docker Desktop Hijacks the Default

When you install Docker Desktop on Windows, it installs its own tiny WSL distro called `docker-desktop`. This distro is **not** a full Linux — it has no `apt`, no `make`, no development tools. It exists only for Docker's internal use.

**What a broken setup looks like:**

```
wsl --list --verbose

  NAME                    STATE       VERSION
* docker-desktop          Running     2       ← DEFAULT (THIS IS THE PROBLEM)
  docker-desktop-data     Running     2
```

When you type `wsl` in this state, you land inside Docker's stripped-down distro, where:

- `apt` does not exist
- `dnf` does not exist
- `make` does not exist
- Almost nothing useful is installed

**What a correct setup looks like:**

```
wsl --list --verbose

  NAME                    STATE       VERSION
* Ubuntu                  Running     2       ← DEFAULT (CORRECT!)
  docker-desktop          Running     2
  docker-desktop-data     Running     2
```

Now when you type `wsl`, you land in Ubuntu with all your tools available.

### How to Fix the Default

```powershell
# In PowerShell
wsl --set-default Ubuntu
```

---

## 7. How The Pieces Connect For Our Project

Here is the full architecture of how the SnapLogic Robot Framework project runs on a Windows machine:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    THE FULL PICTURE                                  │
│                                                                     │
│  ┌─────────────┐    ┌──────────────┐    ┌────────────────────────┐  │
│  │  VS Code    │───→│  WSL/Ubuntu  │───→│   Docker Engine        │  │
│  │  (editor)   │    │  (Linux env) │    │   (containers)         │  │
│  │             │    │              │    │                        │  │
│  │  You write  │    │  make runs   │    │  ┌──────────────────┐  │  │
│  │  code here  │    │  here        │    │  │  Groundplex      │  │  │
│  │             │    │              │    │  │  Oracle DB        │  │  │
│  │  Terminal   │    │  Makefile    │    │  │  PostgreSQL       │  │  │
│  │  set to     │    │  bash scripts│    │  │  Kafka            │  │  │
│  │  Ubuntu WSL │    │  docker cmds │    │  │  MinIO            │  │  │
│  │             │    │              │    │  │  Robot Framework  │  │  │
│  └─────────────┘    └──────────────┘    │  └──────────────────┘  │  │
│                                         └────────────────────────┘  │
│                                                                     │
│  The flow:                                                          │
│  1. You type "make start-services" in VS Code terminal              │
│  2. VS Code sends it to Ubuntu (WSL)                                │
│  3. Ubuntu's bash reads the Makefile                                │
│  4. Makefile calls docker-compose commands                          │
│  5. Docker starts Oracle, Kafka, MinIO, etc. as containers          │
│  6. Robot Framework tests execute against these containers           │
└─────────────────────────────────────────────────────────────────────┘
```

### The Dependency Chain

Each layer depends on the one below it. If any layer is missing or broken, everything above it fails.

```
Layer 4:  Robot Framework tests      ← What you actually want to run
Layer 3:  Docker containers          ← Where databases/services live
Layer 2:  WSL 2 + Ubuntu             ← Where make/bash/docker commands run
Layer 1:  Windows + Docker Desktop   ← The foundation
```

---

## 8. Key Concepts Cheat Sheet

| Concept | What It Is | Analogy |
|---------|-----------|---------|
| **Windows** | Your main OS | The house you live in |
| **Linux** | A different OS kernel | A different type of house |
| **Ubuntu** | A Linux distribution | A specific house design using Linux |
| **WSL** | Linux running inside Windows | An apartment built inside your house |
| **WSL 2** | Improved WSL with real kernel | A better apartment with its own plumbing |
| **Bash** | Linux command-line shell | How you talk to the apartment |
| **PowerShell** | Windows command-line shell | How you talk to the house |
| **Docker** | Container runtime | Mini-appliances that run independently |
| **Docker Desktop** | Docker's Windows app | The control panel for your appliances |
| **`make`** | Build automation tool | A recipe book that Docker follows |
| **`apt`** | Ubuntu's package installer | Ubuntu's app store (command line) |
| **`choco`** | Windows package installer | Windows' app store (command line) |
| **Makefile** | File containing build recipes | The recipe book itself |

---

## 9. Step-by-Step Fix — Getting Everything Working

This section combines the fundamentals above with the practical setup steps.

### Step 1: Verify Windows Prerequisites

Open PowerShell (search "PowerShell" in Start menu):

```powershell
# Check Windows version (need 10 v2004+ or Windows 11)
winver

# Check if virtualization is enabled
# Task Manager → Performance → CPU → "Virtualization: Enabled"
```

### Step 2: Install WSL 2 with Ubuntu

```powershell
# Open PowerShell as Administrator (right-click → Run as Administrator)
wsl --install
```

This single command does everything:
- Enables the WSL feature
- Installs WSL 2
- Downloads and installs Ubuntu
- Sets Ubuntu as the default

**Restart your computer when prompted.**

After restart, an Ubuntu window opens. Create your username and password (remember these!).

### Step 3: Verify the Installation

Back in PowerShell:

```powershell
# Check WSL status
wsl --status

# Expected output:
# Default Distribution: Ubuntu
# Default Version: 2

# List all distros
wsl --list --verbose

# Expected:
# * Ubuntu    Running    2
```

### Step 4: Set Ubuntu as Default (if not already)

```powershell
wsl --set-default Ubuntu
```

### Step 5: Install Development Tools Inside Ubuntu

```bash
# Enter Ubuntu
wsl

# Update package lists and install dev tools
sudo apt update && sudo apt install -y build-essential git python3-pip

# Verify make is installed
make --version
```

**What `build-essential` installs:**

| Package | What It Is |
|---------|-----------|
| `gcc` | C compiler |
| `g++` | C++ compiler |
| `make` | Build automation tool (this is what we need!) |
| `dpkg-dev` | Debian package development tools |
| `libc6-dev` | C standard library headers |

### Step 6: Configure Docker Desktop for WSL

1. Open **Docker Desktop**
2. Click the **gear icon** (⚙️) → **Settings**
3. Go to **Resources** → **WSL Integration**
4. Check ✅ **"Enable integration with my default WSL distro"**
5. Toggle **ON** next to **Ubuntu**
6. Click **"Apply & Restart"**

### Step 7: Verify Docker Works Inside WSL

```bash
# Inside WSL/Ubuntu
docker --version
docker ps
docker-compose --version
```

All three commands should return version info without errors.

### Step 8: Set Up VS Code

1. Install the **WSL extension** in VS Code (`Ctrl+Shift+X` → search "WSL")
2. Set Ubuntu as the default terminal:
   - `Ctrl+Shift+P` → "Terminal: Select Default Profile" → **Ubuntu (WSL)**
3. Or add to `settings.json`:

```json
{
    "terminal.integrated.defaultProfile.windows": "Ubuntu (WSL)",
    "terminal.integrated.profiles.windows": {
        "Ubuntu (WSL)": {
            "path": "wsl.exe",
            "args": ["-d", "Ubuntu"],
            "icon": "terminal-ubuntu"
        }
    }
}
```

### Step 9: Run the Project

```bash
# In VS Code terminal (should now be Ubuntu/WSL)

# Navigate to the project (note: C:\ becomes /mnt/c/)
cd /mnt/c/Users/YourName/path/to/snaplogic-robotframework-examples

# Enter the project folder (curly braces need double quotes on some systems)
cd "{{cookiecutter.primary_pipeline_name}}"

# Copy and configure environment
cp .env.example .env
# Edit .env with your SnapLogic credentials

# Start services
make start-services

# Run tests
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True
```

---

## 10. File Path Mapping Between Windows and WSL

When you use WSL, your Windows drives are mounted under `/mnt/`:

| Windows Path | WSL Path |
|-------------|----------|
| `C:\Users\Name\project` | `/mnt/c/Users/Name/project` |
| `D:\data` | `/mnt/d/data` |
| `\\wsl$\Ubuntu\home` | `/home` or `~` |

### Accessing Files Both Ways

**From WSL, access Windows files:**
```bash
ls /mnt/c/Users/
cd /mnt/c/Users/YourName/Documents
```

**From Windows, access WSL files:**
```
# In Windows Explorer address bar:
\\wsl$\Ubuntu\home\username\
```

### Performance Tip

Files stored on the **WSL filesystem** (`~/projects/`) are significantly faster than files on the **Windows filesystem** (`/mnt/c/...`). For best performance, clone your repos inside WSL:

```bash
# Inside WSL - FASTER
cd ~
mkdir projects
cd projects
git clone https://github.com/SnapLogic/snaplogic-robotframework-examples

# Vs. accessing from Windows mount - SLOWER
cd /mnt/c/Users/YourName/repos/snaplogic-robotframework-examples
```

---

## 11. Common Mistakes and How to Avoid Them

### Mistake 1: Running `make` in PowerShell

**Symptom:** `make : The term 'make' is not recognized...`

**Why:** PowerShell is Windows, `make` is a Linux tool.

**Fix:** Switch to WSL first by typing `wsl` or selecting Ubuntu from VS Code terminal dropdown.

### Mistake 2: Using the Wrong Package Manager

**Symptom:** `dnf: command not found` or `yum: command not found`

**Why:** You are in Ubuntu which uses `apt`, not `dnf` (Fedora) or `yum` (CentOS).

**Fix:** Use `sudo apt install <package>` on Ubuntu.

### Mistake 3: Landing in docker-desktop Distro

**Symptom:** Typing `wsl` drops you into a shell with almost no tools available.

**Why:** Docker Desktop's WSL distro is set as default instead of Ubuntu.

**Fix:**
```powershell
wsl --set-default Ubuntu
```

### Mistake 4: Docker Not Available in WSL

**Symptom:** `docker: command not found` inside WSL.

**Why:** Docker Desktop WSL integration is not enabled for Ubuntu.

**Fix:** Docker Desktop → Settings → Resources → WSL Integration → Toggle Ubuntu ON → Apply & Restart.

### Mistake 5: Curly Braces in Folder Names

**Symptom:** Cannot `cd` into `{{cookiecutter.primary_pipeline_name}}`

**Why:** Curly braces are special characters in most shells.

**Fix:** Wrap the path in double quotes:
```bash
cd "{{cookiecutter.primary_pipeline_name}}"
```

### Mistake 6: Using `host.docker.internal` for Docker Services

**Symptom:** Connection refused when pipelines try to connect to databases.

**Why:** The Groundplex and database containers are on the same Docker network (`snaplogicnet`). They communicate via container names, not through the host.

**Fix:** Use container names as hostnames (e.g., `oracle-db`, `postgres-db`, `sqlserver-db`). The `env_files/` directory already has the correct values — do not change them.

---

## 12. Quick Reference Commands

### PowerShell Commands (Run From Windows)

| Action | Command |
|--------|---------|
| Check if WSL installed | `wsl --status` |
| Install WSL + Ubuntu | `wsl --install` |
| List WSL distros | `wsl --list --verbose` |
| Set default distro | `wsl --set-default Ubuntu` |
| Enter Ubuntu | `wsl` |
| Shut down all WSL | `wsl --shutdown` |
| Check WSL version | `wsl --version` |
| Update WSL | `wsl --update` |

### Ubuntu/WSL Commands (Run From Inside WSL)

| Action | Command |
|--------|---------|
| Update package lists | `sudo apt update` |
| Install dev tools | `sudo apt install -y build-essential git python3-pip` |
| Check make version | `make --version` |
| Check Docker | `docker --version` |
| Check Docker Compose | `docker-compose --version` |
| Navigate to C: drive | `cd /mnt/c/` |
| See current directory | `pwd` |
| List files | `ls -la` |

### Project Commands (Run From Inside WSL, in Project Directory)

| Action | Command |
|--------|---------|
| Start all services | `make start-services` |
| Check service status | `make status` |
| Run Oracle tests | `make robot-run-all-tests TAGS="oracle"` |
| Run tests (no Groundplex) | `make robot-run-tests-no-gp TAGS="oracle"` |
| View test results | Open `test/robot_output/report-*.html` |
| Check environment | `make check-env` |
| View Oracle logs | `make oracle-logs` |
| Stop all services | `make stop-services` |

---

## 13. Next Steps

Once your environment is working:

1. **Read the main project README** — Understand the full test execution flow
2. **Configure your `.env` file** — Add your SnapLogic credentials
3. **Start with a simple test** — Run `make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True`
4. **Check the test results** — Open `test/robot_output/report-*.html` in your browser
5. **Explore slash commands** — Use `/run-tests`, `/add-test`, `/troubleshoot` in Claude Code for guided help

### Related Documentation

- [Windows WSL & VS Code Setup Guide](./windows_wsl_vscode_setup.md) — Detailed installation steps with screenshots
- [Project CLAUDE.md](../../../../.claude/CLAUDE.md) — Full project documentation and Makefile reference

---

*Last updated: 2026-03-19*
