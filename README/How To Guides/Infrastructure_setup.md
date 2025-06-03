

# 🛠️ Infrastructure Setup Guide

This document describes the necessary prerequisites and setup steps for running Robot Framework tests in the SnapLogic automation environment.

---

## Table of Contents
1. [Visual Studio Code Installation](#visual-studio-code-installation)
2. [Docker Desktop Installation](#docker-desktop-installation)
3. [Understanding Docker Compose](#understanding-docker-compose)
4. [Verification Steps](#verification-steps)
5. [Troubleshooting](#troubleshooting)
6. [Next Steps](#next-steps)

---

## Visual Studio Code Installation

### Why VS Code?

Visual Studio Code is the recommended editor because it offers:

- ⚡ **Lightweight and fast** startup and performance
- 🤖 **Robot Framework extensions** for syntax and keyword support
- 🛠️ **Integrated terminal and debugging**
- 🎨 **Enhanced readability** for `.robot` files
- 🔀 **Built-in Git integration**

### Installation Guide by OS

#### Windows

1. Download from: https://code.visualstudio.com/download
2. Run the installer (`VSCodeUserSetup-x64-{version}.exe`)
3. Enable the following during setup:
   - ☑ Create a desktop icon
   - ☑ Add to PATH (Important!)
   - ☑ Register file associations

#### macOS

```bash
# Option 1: From website
# https://code.visualstudio.com/download

# Option 2: With Homebrew
brew install --cask visual-studio-code
```

- Add to PATH:
  - Open VS Code → `Cmd+Shift+P` → "Shell Command: Install 'code' command in PATH"

#### Linux (Ubuntu/Debian)

```bash
sudo snap install --classic code

# Or using APT
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install code
```

### Essential Extensions

Search and install the following in the Extensions view (`Ctrl+Shift+X`):

- 🤖 **Robot Framework Language Server** – Robocorp
- 📄 **YAML** – Red Hat
- 🐍 **Python** – Microsoft
- 🐋 **Docker** – Microsoft

---

## Docker Desktop Installation

### Why Docker?

- 🔁 **Consistency**: Same setup across machines
- 🧪 **Isolation**: Independent test containers
- ⚡ **Speed**: Easy to start and stop
- 🔐 **Security**: Sandbox execution

### Installation Links

- [Mac](https://docs.docker.com/desktop/setup/install/mac-install/)
- [Windows](https://docs.docker.com/desktop/setup/install/windows-install/)
- [Linux](https://docs.docker.com/desktop/setup/install/linux/)

---

## Understanding Docker Compose

Docker Compose manages multiple containers and services, such as:

- Test runner
- Postgres, Oracle, and MinIO services
- Volume mounts and logs
- Shared networks between services

Used via the `docker compose` command.

---

## Verification Steps

### Post-Installation Checks

```bash
docker --version
docker compose version
docker run hello-world
docker system info
```

### VS Code Checks

```bash
code --version
```

- Verify extensions in VS Code
- Open terminal → `code .` to ensure shell integration works

### Full System Check

```bash
docker ps
docker compose --version
code .
```

---

## Troubleshooting

### Docker Issues

- **Windows**: Enable Hyper-V and WSL
- **Mac**: Must be on macOS 10.15+
- **Linux**: Add user to `docker` group

### VS Code Issues

- Restart after installing extensions
- Update VS Code and extensions
- Check internet for marketplace access

### PATH Issues

- Restart terminal/shell
- macOS/Linux: Check `~/.zshrc`, `~/.bashrc`

---

## Next Steps

After infrastructure setup:

1. ✅ Clone the Robot Framework test repository
2. ⚙️ Configure your `.env` file
3. 🧪 Run sample test suite
4. 🚀 Start developing and executing automated tests