

# 🛠️ Infrastructure Setup Guide

This document describes the necessary prerequisites and setup steps for running Robot Framework tests in the SnapLogic automation environment.

---

## Table of Contents
1. [Development Environment](#development-environment)
2. [Docker Desktop Installation](#docker-desktop-installation)
3. [Understanding Docker Compose](#understanding-docker-compose)
4. [Verification Steps](#verification-steps)
5. [Troubleshooting](#troubleshooting)
6. [Next Steps](#next-steps)

---

## Development Environment

You can use any IDE or development environment of your choice to work with Robot Framework tests. Popular options include:

- 💻 **Any IDE** with Robot Framework support (VS Code, PyCharm, IntelliJ, etc.)
- 🖥️ **Terminal/Command Line** for direct execution
- 📝 **Text Editors** with syntax highlighting

**Key Requirements:**
- Ability to edit `.robot` files
- Terminal access for running Docker commands
- Git integration (recommended)

**Helpful Features to Look For:**
- Robot Framework syntax highlighting
- Integrated terminal
- File explorer
- Git integration

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

### Full System Check

```bash
docker ps
docker compose --version
```

---

## Troubleshooting

### Docker Issues

- **Windows**: Enable Hyper-V and WSL
- **Mac**: Must be on macOS 10.15+
- **Linux**: Add user to `docker` group

### Development Environment Issues

- Ensure your chosen IDE/editor can access the project directory
- Verify terminal access for Docker commands
- Check file permissions for editing `.robot` files

---

## Next Steps

After infrastructure setup:

1. ✅ Clone the Robot Framework test repository
2. ⚙️ Configure your `.env` file
3. 🧪 Run sample test suite
4. 🚀 Start developing and executing automated tests

---

## 📚 Explore More Documentation

💡 **Need help finding other guides?** Check out our **[📖 Complete Documentation Reference](../../reference.md)** for a comprehensive overview of all available tutorials, how-to guides, and quick start paths. It's your one-stop navigation hub for the entire SnapLogic Test Framework documentation!