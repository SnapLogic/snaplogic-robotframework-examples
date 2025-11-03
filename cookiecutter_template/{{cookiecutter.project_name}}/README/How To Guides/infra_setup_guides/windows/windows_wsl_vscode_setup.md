# Windows: WSL Setup and VS Code Integration Guide

A complete guide to check for WSL, install Ubuntu on Windows, verify make commands, and integrate with VS Code terminal.

## Table of Contents

1. [Checking if WSL is Installed](#checking-if-wsl-is-installed)
2. [Installing WSL and Ubuntu](#installing-wsl-and-ubuntu)
3. [Setting Up Development Environment](#setting-up-development-environment)
4. [Docker Desktop WSL Integration](#docker-desktop-wsl-integration)
5. [Using WSL in VS Code Terminal](#using-wsl-in-vs-code-terminal)
6. [Quick Reference](#quick-reference)

## Checking if WSL is Installed

### Method 1: Using Command Line

Open PowerShell or Command Prompt and run:

```powershell
wsl --status
```

**Possible outcomes:**

✅ **WSL is installed:**
```
Default Distribution: Ubuntu
Default Version: 2
```

❌ **WSL is NOT installed:**
```
The term 'wsl' is not recognized as the name of a cmdlet...
```

### Method 2: Check Version and Distributions

```powershell
# Check WSL version
wsl --version

# List installed distributions
wsl --list --verbose
```

Output example if installed:
```
  NAME            STATE           VERSION
* Ubuntu          Running         2
  Debian          Stopped         2
```

### Method 3: Check Windows Features

```powershell
# In PowerShell as Administrator
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
```

- **State: Enabled** = WSL is enabled
- **State: Disabled** = WSL is not enabled

### Method 4: Via Windows Settings

1. Open **Settings** → **Apps** → **Optional features**
2. Click **"More Windows features"**
3. Look for **"Windows Subsystem for Linux"** (should be checked if enabled)

## Installing WSL and Ubuntu

### Prerequisites

1. **Check Windows Version:**
   ```powershell
   winver
   ```
   - Minimum: Windows 10 version 1607
   - Recommended: Windows 10 version 2004 or higher
   - Windows 11: All versions supported

2. **Enable Virtualization:**
   - Check in Task Manager → Performance → CPU
   - "Virtualization: Enabled" should be shown
   - If disabled, enable in BIOS/UEFI

### Quick Installation (Recommended)

1. **Open PowerShell as Administrator:**
   - Right-click Start button
   - Select "Windows PowerShell (Admin)"

2. **Install WSL with Ubuntu:**
   ```powershell
   wsl --install
   ```
   
   This single command will:
   - Enable WSL feature
   - Install WSL 2
   - Download and install Ubuntu
   - Set Ubuntu as default

3. **Restart your computer** when prompted

4. **Complete Ubuntu setup:**
   - After restart, Ubuntu window will open automatically
   - Create a username (lowercase recommended)
   - Set a password (won't show while typing)
   - Remember these credentials!

### Manual Installation Steps

If the quick install doesn't work:

#### Step 1: Enable WSL Features
```powershell
# Enable WSL
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# Enable Virtual Machine Platform
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Restart your computer
shutdown /r /t 0
```

#### Step 2: Set WSL 2 as Default
After restart:
```powershell
wsl --set-default-version 2
```

#### Step 3: Install Ubuntu

**Option A - From Microsoft Store:**
1. Open Microsoft Store
2. Search "Ubuntu"
3. Click "Get" or "Install"
4. Launch after installation

**Option B - From Command Line:**
```powershell
# List available distributions
wsl --list --online

# Install Ubuntu
wsl --install -d Ubuntu
```

**Option C - Direct Download:**
```powershell
# Download Ubuntu 22.04
Invoke-WebRequest -Uri https://aka.ms/wslubuntu2204 -OutFile Ubuntu.appx -UseBasicParsing

# Install
Add-AppxPackage .\Ubuntu.appx
```

### Post-Installation Setup

1. **Launch Ubuntu:**
   ```powershell
   ubuntu
   ```
   Or search "Ubuntu" in Start Menu

2. **Update Ubuntu:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

3. **Set Ubuntu as default WSL distribution:**
   ```powershell
   wsl --set-default Ubuntu
   ```

## Setting Up Development Environment

After installing WSL and Ubuntu, you'll need to set up development tools including make, compilers, and other essentials.

### Step 1: Check if Make is Already Installed

First, open Ubuntu/WSL and check if make is already installed:

```bash
# Open WSL from PowerShell/Command Prompt
wsl
# or
ubuntu

# Check if make is installed
make --version
```

**Results:**
- ✅ **Installed:** Shows GNU Make version (skip to verification)
- ❌ **Not installed:** Shows "command not found" (continue with installation)

### Step 2: Quick Development Setup

This single command installs the most common development tools:

```bash
sudo apt update && sudo apt install -y build-essential git python3-pip
```

### What Each Part Does

1. **`sudo apt update`** - Updates the package list from Ubuntu repositories
2. **`&&`** - Chains commands (runs the second only if the first succeeds)
3. **`sudo apt install -y`** - Installs packages with automatic yes to prompts

### What Gets Installed

| Package             | Description                         | Includes/Purpose                           |
| ------------------- | ----------------------------------- | ------------------------------------------ |
| **build-essential** | Core compilation tools meta-package | gcc, g++, make, dpkg-dev, libc6-dev        |
| **git**             | Version control system              | Clone repos, manage code, collaborate      |
| **python3-pip**     | Python package installer            | Install Python packages like numpy, django |

### Why This Combination?

This gives you everything needed for basic development:

```bash
# After installation, you can:

# Compile C/C++ programs
gcc myprogram.c -o myprogram
g++ myapp.cpp -o myapp

# Use makefiles
make
make clean
make install

# Work with Git
git clone https://github.com/user/repo.git
git add .
git commit -m "Initial commit"

# Install Python packages
pip install requests
pip install django
pip install numpy
```

### Step 3: Verify Installation

After installation, verify all tools are working:

```bash
# Check core tools
make --version
gcc --version
g++ --version
git --version
python3 --version
pip --version

# Check installation paths
which make
which gcc
which git
```

### Alternative: Install Only Make

If you only need make without other development tools:

```bash
sudo apt update
sudo apt install make -y
```

However, `build-essential` is recommended as it includes make plus other tools you'll likely need.

### Extended Development Setup

For a more comprehensive environment, add these commonly needed tools:

```bash
sudo apt update && sudo apt install -y \
    build-essential \
    git \
    python3-pip \
    nodejs \
    npm \
    curl \
    wget \
    vim \
    htop \
    tree
```

**Additional tools explained:**
- **nodejs/npm** - JavaScript runtime and package manager
- **curl/wget** - Download files from the command line
- **vim** - Powerful text editor
- **htop** - Interactive process viewer
- **tree** - Display directory structure

### Language-Specific Development

**For Python Development:**
```bash
sudo apt install -y python3-venv python3-dev
# Create virtual environments with: python3 -m venv myenv
```

**For Node.js Development:**
```bash
# Install Node Version Manager (nvm) for better Node.js management
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
```

**For C/C++ Development:**
```bash
sudo apt install -y cmake gdb valgrind
```

### Troubleshooting Development Tools

**"make: command not found" after installation:**
```bash
# Refresh shell environment
source ~/.bashrc
# Or exit and reopen WSL
exit
wsl
```

**Permission denied errors:**
```bash
# Always use sudo for system installations
sudo apt install package-name
```

**Package not found errors:**
```bash
# Update package lists first
sudo apt update
# Then try installing again
sudo apt install package-name
```

## Docker Desktop WSL Integration

After installing WSL and Ubuntu, you need to configure Docker Desktop to work with WSL for running Docker commands.

### Prerequisites

- Docker Desktop installed on Windows
- WSL 2 with Ubuntu installed (from previous steps)

### Enable WSL Integration in Docker Desktop

1. **Open Docker Desktop**
2. **Navigate to Settings:**
   - Click the gear icon (⚙️) in the top right
   - Or go to **Docker Desktop** → **Settings**

3. **Configure WSL Integration:**
   - Go to **Resources** → **WSL Integration**
   - Ensure **"Enable integration with my default WSL distro"** is checked ✅
   - Under **"Enable integration with additional distros"**, toggle on **Ubuntu**
   - Click **"Refetch distros"** if Ubuntu doesn't appear in the list
   - Click **"Apply & Restart"**

### Why This Integration Is Important

- Allows you to run Docker commands from within WSL/Ubuntu
- Enables seamless container management from Linux environment
- Required for make commands that use Docker in your projects
- Provides better performance than running Docker through Windows

### Verify Docker Integration

Test that Docker is accessible from WSL:

```bash
# In your WSL/Ubuntu terminal
docker --version
docker ps
```

Expected output:
- `docker --version` should show Docker version
- `docker ps` should list running containers (or show empty list)

### ⚠️ Important: After Enabling WSL Integration

**You must complete these steps:**

1. **Restart your WSL terminal:**
   ```bash
   # Exit current WSL session
   exit
   # Open a new WSL session
   wsl
   ```

2. **If using VS Code, restart the terminal:**
   - Close all terminal tabs in VS Code
   - Open a new terminal with `` Ctrl+` ``
   - Select Ubuntu (WSL) from the dropdown

3. **Verify Docker is working:**
   ```bash
   docker version
   ```
   You should see both Client and Server information

4. **Now you can run your make commands:**
   ```bash
   make start-services
   make robot-run-all-tests
   ```

### Troubleshooting Docker WSL Integration

**"Cannot connect to Docker daemon" error:**
- Ensure Docker Desktop is running
- Check WSL integration is enabled in Docker settings
- Restart both Docker Desktop and WSL

**"docker: command not found" in WSL:**
- Verify WSL integration is enabled for Ubuntu
- Restart your terminal after enabling integration
- Try running `wsl --shutdown` in PowerShell, then reopen WSL

**Docker commands work in PowerShell but not WSL:**
- This indicates WSL integration is not properly configured
- Follow the integration steps above again
- Ensure you clicked "Apply & Restart" after making changes

## Using WSL in VS Code Terminal

### Prerequisites

1. Install VS Code if not already installed
2. Ensure WSL and Ubuntu are set up (previous steps)

### Step 1: Install WSL Extension

1. Open VS Code
2. Press `Ctrl+Shift+X` (Extensions)
3. Search for "WSL"
4. Install the official Microsoft "WSL" extension
5. Reload VS Code if prompted

### Step 2: Open Terminal with WSL

#### Method 1: Select WSL Terminal
1. Open terminal: `` Ctrl+` `` or View → Terminal
2. Click the dropdown arrow (˅) next to the + icon
3. Select "Ubuntu (WSL)" or your Linux distribution
4. Terminal prompt changes to: `username@computer:~$`

#### Method 2: Set WSL as Default Terminal
1. Press `Ctrl+Shift+P` (Command Palette)
2. Type "Terminal: Select Default Profile"
3. Choose "Ubuntu (WSL)"
4. Now all new terminals will be WSL

#### Method 3: Open Project in WSL
1. Press `Ctrl+Shift+P`
2. Type "WSL: Open Folder in WSL"
3. Select your project folder
4. VS Code reopens connected to WSL
5. Look for "[WSL: Ubuntu]" in the title bar

### Step 3: Configure VS Code for WSL

Add to VS Code settings.json (`Ctrl+,` then click {} icon):

```json
{
    // Set WSL as default terminal
    "terminal.integrated.defaultProfile.windows": "Ubuntu (WSL)",
    
    // Configure WSL profile
    "terminal.integrated.profiles.windows": {
        "Ubuntu (WSL)": {
            "path": "wsl.exe",
            "args": ["-d", "Ubuntu"],
            "icon": "terminal-ubuntu"
        }
    },
    
    // Optional: Set starting directory
    "terminal.integrated.cwd": "/home/username/projects"
}
```

### Step 4: Using Make in VS Code Terminal

1. **With WSL terminal active:**
   ```bash
   # Navigate to project
   cd /mnt/c/Users/YourName/project
   # or if in Linux filesystem
   cd ~/project
   
   # Run make
   make
   make clean
   make test
   ```

2. **From any terminal using wsl prefix:**
   ```powershell
   wsl make
   wsl make clean
   ```

3. **Create VS Code tasks** (`.vscode/tasks.json`):
   ```json
   {
       "version": "2.0.0",
       "tasks": [
           {
               "label": "Make Build",
               "type": "shell",
               "command": "make",
               "options": {
                   "shell": {
                       "executable": "wsl.exe"
                   }
               },
               "group": {
                   "kind": "build",
                   "isDefault": true
               }
           }
       ]
   }
   ```
   Run with `Ctrl+Shift+B`

## Quick Reference

### Essential Commands

| Action                 | Command                            |
| ---------------------- | ---------------------------------- |
| Check if WSL installed | `wsl --status`                     |
| Install WSL + Ubuntu   | `wsl --install`                    |
| Open Ubuntu            | `wsl` or `ubuntu`                  |
| Check make version     | `make --version`                   |
| Install make           | `sudo apt install build-essential` |
| Check Docker in WSL    | `docker --version`                 |
| Test Docker connection | `docker ps`                        |
| Restart WSL            | `wsl --shutdown` (from PowerShell) |
| Open WSL in VS Code    | Terminal dropdown → Ubuntu (WSL)   |

### Terminal Indicators

| Terminal Type  | Prompt Example    | Can Run Make?       |
| -------------- | ----------------- | ------------------- |
| PowerShell     | `PS C:\>`         | No (use `wsl make`) |
| Command Prompt | `C:\>`            | No (use `wsl make`) |
| Git Bash       | `user@PC MINGW64` | Maybe (limited)     |
| WSL/Ubuntu     | `user@pc:~$`      | Yes ✅               |

### Common Issues and Fixes

| Issue                          | Solution                                          |
| ------------------------------ | ------------------------------------------------- |
| WSL not recognized             | Run PowerShell as Admin                           |
| Ubuntu won't start             | `wsl --shutdown` then retry                       |
| Make not found                 | `sudo apt install build-essential`                |
| Docker not found in WSL        | Enable WSL integration in Docker Desktop settings |
| Docker daemon connection error | Restart terminal after enabling WSL integration   |
| Wrong terminal in VS Code      | Select "Ubuntu (WSL)" from dropdown               |
| Permission denied              | Use `sudo` before commands                        |

### File Path Conversions

| Windows Path            | WSL Path                    |
| ----------------------- | --------------------------- |
| `C:\Users\Name\project` | `/mnt/c/Users/Name/project` |
| `D:\data`               | `/mnt/d/data`               |
| `\\wsl$\Ubuntu\home`    | `/home` or `~`              |

## Troubleshooting

### WSL Installation Issues

1. **"Virtualization not enabled"**
   - Restart computer
   - Enter BIOS/UEFI (usually F2, F10, or Del during startup)
   - Enable Virtualization/VT-x/AMD-V
   - Save and exit

2. **"WSL 2 requires an update"**
   ```powershell
   wsl --update
   ```

3. **"Access denied" errors**
   - Ensure running PowerShell as Administrator
   - Check Windows Defender exclusions

### Ubuntu Issues

1. **Forgot password:**
   ```powershell
   # In PowerShell
   ubuntu config --default-user root
   # Then in Ubuntu
   passwd your_username
   ```

2. **Reset Ubuntu:**
   ```powershell
   wsl --unregister Ubuntu
   wsl --install -d Ubuntu
   ```

### VS Code Terminal Issues

1. **Terminal not showing WSL option:**
   - Restart VS Code
   - Ensure WSL extension is installed
   - Check if Ubuntu is running: `wsl --list --running`

2. **"Command 'make' not found in WSL terminal":**
   ```bash
   # In WSL terminal
   sudo apt update
   sudo apt install build-essential -y
   ```

## Next Steps

1. **Optimize Performance:**
   - Store projects in WSL filesystem (`~/projects/`)
   - Use `.wslconfig` for memory limits

2. **Set up Git:**
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

3. **Create aliases** in `~/.bashrc`:
   ```bash
   alias ll='ls -la'
   alias gs='git status'
   alias mk='make'
   ```

4. **Install Docker** (optional):
   ```bash
   # Docker Desktop for Windows integrates with WSL2
   # Download from https://www.docker.com/products/docker-desktop
   ```

Now you're ready to use make and other Linux tools seamlessly in Windows through VS Code!
