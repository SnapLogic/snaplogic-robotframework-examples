#!/bin/bash
# =============================================================================
# Docker Build Debugging Script for Travis CI
# =============================================================================
# This script contains all debugging commands to troubleshoot Docker build
# issues in Travis CI. It helps identify path resolution and configuration
# problems with docker-compose.
# =============================================================================

echo "=========================================================================="
echo "🔍 DOCKER BUILD DEBUGGING INFORMATION"
echo "=========================================================================="

# -----------------------------------------------------------------------------
# Docker and Docker Compose Versions
# -----------------------------------------------------------------------------
echo ""
echo "===== Docker and Docker Compose Versions ====="
docker --version
docker-compose --version || echo "docker-compose (v1) not found"
docker compose version || echo "docker compose (v2) not found"

# -----------------------------------------------------------------------------
# Current Directory and File Structure
# -----------------------------------------------------------------------------
echo ""
echo "===== Current Directory and Contents ====="
echo "Working directory: $(pwd)"
echo ""
echo "Root directory contents:"
ls -la

echo ""
echo "===== Source Directory Contents ====="
if [ -d "src" ]; then
    ls -la src/
    if [ -d "src/tools" ]; then
        echo ""
        echo "src/tools/ contents:"
        ls -la src/tools/
    else
        echo "⚠️  src/tools/ directory not found"
    fi
else
    echo "⚠️  src/ directory not found"
fi

# -----------------------------------------------------------------------------
# Dockerfile Location Check
# -----------------------------------------------------------------------------
echo ""
echo "===== Check for Dockerfile ====="
echo "Looking for *.Dockerfile in root:"
ls -la *.Dockerfile 2>/dev/null || echo "No .Dockerfile files found in root"

echo ""
echo "Looking for Dockerfiles recursively:"
find . -name "*.Dockerfile" -o -name "Dockerfile" | head -20

# -----------------------------------------------------------------------------
# Docker Compose Configuration
# -----------------------------------------------------------------------------
echo ""
echo "===== Docker Compose Configuration ====="
if [ -f "docker-compose.yml" ]; then
    echo "tools service configuration from docker-compose.yml:"
    cat docker-compose.yml | grep -A10 "tools:" || echo "tools service not found"
else
    echo "❌ docker-compose.yml not found!"
fi

# -----------------------------------------------------------------------------
# Docker Compose Config Resolution
# -----------------------------------------------------------------------------
echo ""
echo "===== Docker Compose Config Resolution ====="
echo "Resolved configuration for tools service:"
docker compose config 2>/dev/null | grep -A15 "tools:" || echo "Could not resolve docker compose config"

# -----------------------------------------------------------------------------
# Path Resolution Analysis
# -----------------------------------------------------------------------------
echo ""
echo "===== Dockerfile Path Resolution Analysis ====="

# Extract context and dockerfile paths from docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    CONTEXT=$(grep -A2 'tools:' docker-compose.yml | grep 'context:' | awk '{print $2}')
    DOCKERFILE=$(grep -A3 'tools:' docker-compose.yml | grep 'dockerfile:' | awk '{print $2}')
    
    echo "Extracted from docker-compose.yml:"
    echo "  Build context: ${CONTEXT:-'not found'}"
    echo "  Dockerfile: ${DOCKERFILE:-'not found'}"
    
    if [ -n "$CONTEXT" ] && [ -n "$DOCKERFILE" ]; then
        echo ""
        echo "Path resolution:"
        echo "  1. Docker will use context: $CONTEXT"
        echo "  2. From that context, it will look for: $DOCKERFILE"
        
        # Try to determine the actual path Docker will use
        if [[ "$DOCKERFILE" == /* ]]; then
            # Absolute path
            RESOLVED_PATH="$DOCKERFILE"
            echo "  3. Dockerfile uses absolute path: $RESOLVED_PATH"
        elif [[ "$DOCKERFILE" == ../* ]]; then
            # Relative path going up
            echo "  3. Dockerfile uses relative path going up from context"
            # Simple resolution for demonstration
            if [[ "$CONTEXT" == "." ]]; then
                RESOLVED_PATH="$DOCKERFILE"
            else
                RESOLVED_PATH="$CONTEXT/$DOCKERFILE"
            fi
            echo "  4. Approximate resolved path: $RESOLVED_PATH"
        else
            # Relative path within context
            if [[ "$CONTEXT" == "." ]]; then
                RESOLVED_PATH="$DOCKERFILE"
            else
                RESOLVED_PATH="$CONTEXT/$DOCKERFILE"
            fi
            echo "  3. Resolved path would be: $RESOLVED_PATH"
        fi
        
        echo ""
        echo "Checking if Dockerfile exists:"
        if [ -f "$RESOLVED_PATH" ]; then
            echo "  ✅ File exists at: $RESOLVED_PATH"
            ls -la "$RESOLVED_PATH"
        else
            echo "  ❌ File NOT found at: $RESOLVED_PATH"
            echo ""
            echo "  Looking for similar files:"
            find . -name "$(basename $DOCKERFILE)" 2>/dev/null | head -5
        fi
    fi
else
    echo "❌ Cannot analyze - docker-compose.yml not found"
fi

# -----------------------------------------------------------------------------
# Test Docker Build (Dry Run)
# -----------------------------------------------------------------------------
echo ""
echo "===== Testing Docker Build Context Resolution ====="
echo "Attempting dry-run build (may not be supported in all Docker versions):"
docker compose build --dry-run tools 2>&1 | head -20 || echo "Dry-run not supported or failed"

# -----------------------------------------------------------------------------
# Environment Variables
# -----------------------------------------------------------------------------
echo ""
echo "===== Environment Variables (Travis-specific) ====="
echo "TRAVIS_BUILD_DIR: ${TRAVIS_BUILD_DIR:-'not set'}"
echo "PWD: $PWD"
echo "HOME: $HOME"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=========================================================================="
echo "📋 DEBUGGING SUMMARY"
echo "=========================================================================="
echo "1. Docker Compose version: $(docker compose version 2>/dev/null | head -1 || echo 'unknown')"
echo "2. Working directory: $(pwd)"
echo "3. robot.Dockerfile exists: $([ -f "robot.Dockerfile" ] && echo "✅ Yes" || echo "❌ No")"
echo "4. docker-compose.yml exists: $([ -f "docker-compose.yml" ] && echo "✅ Yes" || echo "❌ No")"

if [ -n "$CONTEXT" ] && [ -n "$DOCKERFILE" ]; then
    echo "5. Build context: $CONTEXT"
    echo "6. Dockerfile path: $DOCKERFILE"
    echo "7. Resolved path exists: $([ -f "$RESOLVED_PATH" ] && echo "✅ Yes at $RESOLVED_PATH" || echo "❌ No at $RESOLVED_PATH")"
fi

echo "=========================================================================="
echo "🔍 END OF DOCKER BUILD DEBUGGING"
echo "=========================================================================="
