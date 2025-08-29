#!/bin/bash

# run-tests.sh - Wrapper script to run tests with specific environment

# Default to dev environment if not specified
ENV_NAME=${1:-dev}
TAGS=${2:-""}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting Robot Framework Tests${NC}"
echo -e "${YELLOW}📦 Environment: ${ENV_NAME}${NC}"

# Check if environment file exists
ENV_FILE=".env.${ENV_NAME}"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Error: Environment file ${ENV_FILE} not found!${NC}"
    echo "Available environments:"
    ls -la .env.* 2>/dev/null | awk '{print "  - " $9}' | sed 's/.env.//'
    exit 1
fi

# Copy the selected env file to .env (which docker-compose reads)
echo -e "${YELLOW}📋 Loading environment from ${ENV_FILE}${NC}"
cp ${ENV_FILE} .env

# Export for docker-compose
export ENV_FILE=${ENV_FILE}
export ENVIRONMENT=${ENV_NAME}

# Run docker-compose with the selected environment
echo -e "${GREEN}🔧 Starting Docker containers with ${ENV_NAME} environment...${NC}"

# If TAGS provided, use them
if [ -n "$TAGS" ]; then
    echo -e "${YELLOW}🏷️  Running tests with tags: ${TAGS}${NC}"
    docker-compose --env-file ${ENV_FILE} -f docker/docker-compose.yml exec -w /app/test tools robot \
        --variable ENVIRONMENT:${ENV_NAME} \
        --variable ENV_FILE:${ENV_FILE} \
        --include ${TAGS} \
        --outputdir robot_output suite/
else
    echo -e "${YELLOW}▶️  Running all tests${NC}"
    docker-compose --env-file ${ENV_FILE} -f docker/docker-compose.yml exec -w /app/test tools robot \
        --variable ENVIRONMENT:${ENV_NAME} \
        --variable ENV_FILE:${ENV_FILE} \
        --outputdir robot_output suite/
fi

echo -e "${GREEN}✅ Tests completed for ${ENV_NAME} environment${NC}"
