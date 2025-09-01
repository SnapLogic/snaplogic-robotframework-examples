#!/bin/bash
# Script to load environment variables from .env.ports and run docker-compose

# Load .env.ports if it exists
if [ -f .env.ports ]; then
    echo "Loading port configuration from .env.ports..."
    set -a
    source .env.ports
    set +a
fi

# Load .env if it exists
if [ -f .env ]; then
    echo "Loading environment configuration from .env..."
    set -a
    source .env
    set +a
fi

# Run docker-compose with all arguments passed to this script
docker-compose "$@"
