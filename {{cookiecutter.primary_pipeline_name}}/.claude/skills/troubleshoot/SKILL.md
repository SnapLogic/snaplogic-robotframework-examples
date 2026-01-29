---
name: troubleshoot
description: Troubleshooting guide for common issues in SnapLogic Robot Framework testing. Use when the user encounters errors, Docker/container issues, environment configuration problems, network connectivity issues, or SnapLogic API errors.
user-invocable: true
---

You are helping a user troubleshoot issues in this SnapLogic Robot Framework testing project. Diagnose problems and provide solutions.

## Quick Diagnostic Commands

```bash
# Overall system status
make status

# Check running containers
make show-running

# View all logs
docker compose logs --tail=50

# Check environment
make check-env

# Network connectivity
make docker-networks
```

## Issue Categories

## 1. Environment Issues

### Missing Environment Variables

**Symptoms:**
```
Missing required environment variables: URL, ORG_ADMIN_USER
KeyError: 'ORACLE_PASSWORD'
Variable ${URL} not found
```

**Solutions:**
```bash
# Check if .env exists
ls -la .env

# If missing, create from template
cp .env.example .env

# Edit with your values
nano .env  # or your preferred editor

# Verify variables are set
make check-env
grep -E "^URL=" .env
```

### Environment Not Loading

**Symptoms:**
```
Variable shows as empty
Settings from .env not applied
```

**Solutions:**
```bash
# Check .env file format (no spaces around =)
# Good: URL=https://example.com
# Bad:  URL = https://example.com

# Check for hidden characters
cat -A .env | head -20

# Reload containers to pick up changes
docker compose down
docker compose up -d
```

---

## 2. Docker Issues

### Containers Not Starting

**Symptoms:**
```
Container exited with code 1
Service failed to start
```

**Solutions:**
```bash
# Check container logs
docker compose logs <service_name>

# Check for port conflicts
lsof -i :8000  # Replace with relevant port

# Check Docker resources
docker system df
docker stats

# Clean up and restart
docker compose down
docker system prune -f
docker compose up -d
```

### Out of Disk Space

**Symptoms:**
```
no space left on device
Cannot create container
```

**Solutions:**
```bash
# Check Docker disk usage
docker system df

# Clean up unused resources
docker system prune -a --volumes

# Remove old test outputs
rm -rf test/robot_output/output-*.xml
rm -rf test/robot_output/log-*.html
```

### Network Issues

**Symptoms:**
```
Could not resolve hostname
Connection refused
Network unreachable
```

**Solutions:**
```bash
# Check Docker networks
make docker-networks

# Verify container is on correct network
docker network inspect <network_name>

# Test connectivity between containers
docker compose exec tools ping -c 3 oracle-db

# Recreate networks
docker compose down
docker network prune -f
docker compose up -d
```

---

## 3. Database Issues

### Cannot Connect to Database

**Symptoms:**
```
ORA-12541: TNS:no listener
Connection refused
FATAL: password authentication failed
```

**Solutions:**
```bash
# 1. Verify database is running
make oracle-status  # or postgres-status, etc.

# 2. Check database logs
make oracle-logs

# 3. Wait for initialization (Oracle takes 5-10 min first time)
docker compose logs -f oracle-db | grep -i "ready"

# 4. Verify credentials
grep ORACLE .env

# 5. Test connection manually
docker compose exec oracle-db sqlplus testuser/testpass@//localhost:1521/FREEPDB1
```

### Database Initialization Failed

**Symptoms:**
```
Database creation failed
ORA-01034: ORACLE not available
```

**Solutions:**
```bash
# Remove and recreate database volume
docker compose stop oracle-db
docker volume rm $(docker volume ls -q | grep oracle)
make oracle-start

# Check for memory issues
docker stats oracle-db
```

---

## 4. Groundplex Issues

### Groundplex Not Registering

**Symptoms:**
```
Snaplex not found
No active nodes
Pipeline execution failed - no available node
```

**Solutions:**
```bash
# 1. Check Groundplex container
docker compose logs groundplex

# 2. Verify Groundplex credentials
grep GROUNDPLEX .env

# 3. Restart Groundplex
make stop-groundplex
sleep 60  # Wait for cloud deregistration
make launch-groundplex

# 4. Check SnapLogic cloud for Snaplex status
# Login to SnapLogic Manager and verify Snaplex is registered
```

### Groundplex Has Active Nodes (Can't Delete Project)

**Symptoms:**
```
cannot be deleted while it contains active nodes
Project deletion failed
```

**Solutions:**
```bash
# Stop Groundplex and wait for deregistration
make stop-groundplex
echo "Waiting 60 seconds for cloud deregistration..."
sleep 60

# Retry operation
make robot-run-tests TAGS="createplex" PROJECT_SPACE_SETUP=True
```

---

## 5. Test Execution Issues

### Tests Not Finding Tags

**Symptoms:**
```
No tests found matching tag
0 tests run
```

**Solutions:**
```bash
# List all available tags
docker compose exec -w /app/test tools robot --dryrun suite/ 2>&1 | grep "\[Tags\]"

# Check tag spelling (case-sensitive)
grep -r "\[Tags\]" test/suite/

# Run without tag filter to verify tests exist
docker compose exec -w /app/test tools robot --dryrun suite/
```

### Tests Timing Out

**Symptoms:**
```
Test timeout exceeded
Operation timed out after 300 seconds
```

**Solutions:**
```bash
# Check service responsiveness
make status

# Increase timeout in test
# [Timeout]    600s

# Check for blocking operations
docker compose logs tools | grep -i "wait\|block\|hang"

# Check system resources
docker stats
```

### Import Errors

**Symptoms:**
```
No keyword with name 'My Keyword' found
Resource file not found
Library import failed
```

**Solutions:**
```bash
# Check file path in Settings section
# Paths should be relative to the test file

# Verify resource file exists
ls -la test/resources/common/

# Check for syntax errors in resource file
docker compose exec -w /app/test tools robot --dryrun \
    suite/pipeline_tests/oracle/my_test.robot
```

---

## 6. Pipeline Execution Issues

### Pipeline Upload Failed

**Symptoms:**
```
Pipeline upload failed
401 Unauthorized
Asset already exists
```

**Solutions:**
```bash
# Check credentials
grep -E "^(URL|ORG_ADMIN)" .env

# Check project path exists
# Verify in SnapLogic Manager

# Delete existing pipeline first
make robot-run-tests TAGS="cleanup"
```

### Pipeline Execution Failed

**Symptoms:**
```
Pipeline status: Failed
Execution error
```

**Solutions:**
```bash
# Check pipeline logs in SnapLogic Manager

# Verify Groundplex is running
docker compose ps groundplex

# Check pipeline dependencies (accounts, connections)
# Verify all required accounts are created

# Run with verbose logging
make robot-run-tests TAGS="your_tag" 2>&1 | tee test_output.log
```

---

## 7. CI/CD Issues (Travis)

### Travis Build Failing

**Symptoms:**
```
Build failed
Docker command not found
Permission denied
```

**Solutions:**
```bash
# Check Travis configuration
cat .travis.yml

# Verify Docker is enabled in Travis
# services:
#   - docker

# Check for permission issues in Travis logs
# May need: chmod +x scripts/*.sh
```

---

## Diagnostic Scripts

### Full System Check
```bash
#!/bin/bash
echo "=== System Check ==="
echo "Docker version:"
docker --version
echo ""
echo "Docker Compose version:"
docker compose version
echo ""
echo "Running containers:"
docker compose ps
echo ""
echo "Environment check:"
make check-env 2>&1 || echo "check-env not available"
echo ""
echo "Network status:"
docker network ls | grep -E "snaplogic|default"
echo ""
echo "Disk usage:"
docker system df
```

### Quick Health Check
```bash
# Run from project root
make status && echo "System OK" || echo "System has issues"
```

## Getting More Help

1. **Check the logs first** - Most issues are revealed in container logs
2. **Isolate the problem** - Which service/component is failing?
3. **Check recent changes** - Did something change in .env or docker-compose.yml?
4. **Try a clean restart** - Sometimes `docker compose down && docker compose up -d` fixes things
5. **Search error messages** - The exact error text often leads to solutions
