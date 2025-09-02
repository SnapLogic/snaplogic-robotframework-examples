#!/bin/bash
# setup_env.sh - Travis CI environment setup only
# This script is designed exclusively for Travis CI builds
# Robot Framework tests cannot access environment variables directly,they should be loaded and assigned to respective
# global or suite variables. This script helps to create a .env file and __init__.robot will load this env file
# and assign the variables to global variables for Robot Framework tests.
set -e

# Check if running in Travis CI
if [ -z "$TRAVIS" ]; then
    echo "⚠️  This script is designed for Travis CI builds only."
    echo "   For local development, create your own .env file manually."
    echo "   Exiting gracefully..."
    exit 0
fi

echo "🔧 Travis CI Build: Creating .env from environment variables..."
echo "📦 Running in Travis CI environment (Build #$TRAVIS_BUILD_NUMBER)"
echo "🌿 Branch: $TRAVIS_BRANCH | Commit: ${TRAVIS_COMMIT:0:8}"
echo ""

# All required variables for Travis builds(available from Travis settings)
# These variables are essential for the SnapLogic project to run correctly      
required_vars=(
    "URL"
    "ORG_ADMIN_USER"
    "ORG_ADMIN_PASSWORD"
    "ORG_NAME"
    "PROJECT_SPACE"
    "PROJECT_NAME"
    "GROUNDPLEX_NAME"
    "GROUNDPLEX_ENV"
    "GROUNDPLEX_LOCATION_PATH"
    "RELEASE_BUILD_VERSION"
    "ACCOUNT_LOCATION_PATH"
    "RELEASE_BUILD_VERSION"
)

# Optional database/service variables (available from Travis.yaml)
optional_vars=(
    # Build Configuration
    "HMD_HOME"
    
    # Oracle Database Configuration
    "ORACLE_ACCOUNT_NAME"
    "ORACLE_HOST"
    "ORACLE_DBNAME"
    "ORACLE_DBPORT"
    "ORACLE_DBUSER"
    "ORACLE_DBPASS"
    
    # PostgreSQL Database Configuration
    "POSTGRES_ACCOUNT_NAME"
    "POSTGRES_HOST"
    "POSTGRES_DBNAME"
    "POSTGRES_DBPORT"
    "POSTGRES_DBUSER"
    "POSTGRES_DBPASS"
    
    # SQL Server Database Configuration
    "SQLSERVER_ACCOUNT_NAME"
    "SQLSERVER_HOST"
    "SQLSERVER_DBNAME"
    "SQLSERVER_DBPORT"
    "SQLSERVER_DBUSER"
    "SQLSERVER_DBPASS"
    
    # MySQL Database Configuration
    "MYSQL_ACCOUNT_NAME"
    "MYSQL_HOST"
    "MYSQL_DBNAME"
    "MYSQL_DBPORT"
    "MYSQL_DBUSER"
    "MYSQL_DBPASS"
    "MYSQL_JAR"

    # DB2 Database Configuration
    "DB2_ACCOUNT_NAME"
    "DB2_HOST"
    "DB2_DBNAME"
    "DB2_DBPORT"
    "DB2_DBUSER"
    "DB2_DBPASS"
    "DB2_JDBC_JAR"
    "DB2_JDBC_DRIVER_CLASS"
    "DB2_JDBC_URL"
    "DB2_TEST_QUERY"
    
    # S3/MinIO Configuration
    "S3_ACCOUNT_NAME"
    "S3_ENDPOINT"
    "S3_ACCESS_KEY"
    "S3_SECRET_KEY"
    
    # JMS/ActiveMQ Configuration
    "JMS_ACCOUNT_NAME"
    "JMS_HOST"
    "JMS_PORT"
    "JMS_USERNAME"
    "JMS_PASSWORD"
    "JMS_CONNECTION_FACTORY"
    "JMS_INITIAL_CONTEXT_FACTORY"
    "JMS_PROVIDER_URL"
    "JMS_QUEUE_NAME"
    
    # Snowflake Database Configuration
    "SNOWFLAKE_ACCOUNT_NAME"
    "SNOWFLAKE_ACCOUNT"
    "SNOWFLAKE_HOSTNAME"
    "SNOWFLAKE_PORT"
    "SNOWFLAKE_DATABASE"
    "SNOWFLAKE_SCHEMA"
    "SNOWFLAKE_WAREHOUSE"
    "SNOWFLAKE_USERNAME"
    "SNOWFLAKE_PASSWORD"
    "SNOWFLAKE_ROLE"
    "SNOWFLAKE_S3_BUCKET"
    "SNOWFLAKE_S3_FOLDER"
    "SNOWFLAKE_S3_ACCESS_KEY"
    "SNOWFLAKE_S3_SECRET_KEY"
)

# Check for missing required variables
echo "🔍 Validating required variables for Travis CI build..."
missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

# Report missing required variables and fail
if [ ${#missing_vars[@]} -gt 0 ]; then
    echo "❌ Travis CI Build Failed: Missing ${#missing_vars[@]} required variables:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "💡 Please add these variables to your Travis CI configuration:"
    echo "   - Via .travis.yml env: section, OR"
    echo "   - Via Travis CI web interface > Settings > Environment Variables"
    exit 1
fi

echo "✅ All required variables validated successfully for Travis CI"

# Create .env file for Travis CI
echo "Creating .env file..."

{
    echo "# Generated for Travis CI build"
    echo "# Date: $(date)"
    echo ""
    
    echo "# Required Variables"
    for var in "${required_vars[@]}"; do
        echo "$var=${!var}"
    done
    
    echo ""
    echo "# Optional Database/Service Variables"
    for var in "${optional_vars[@]}"; do
        if [ -n "${!var}" ]; then
            echo "$var=${!var}"
        else
            echo "# $var=<not_set>"
        fi
    done
    
} > .env

echo "✅ Created .env file successfully"

# Show summary of what was created
echo ""
echo "📋 Summary:"
echo "  - Required variables: ${#required_vars[@]} (all present)"
available_optional=0
for var in "${optional_vars[@]}"; do
    if [ -n "${!var}" ]; then
        available_optional=$((available_optional + 1))
    fi
done
echo "  - Optional variables: ${available_optional}/${#optional_vars[@]} available"

echo ""
echo "🚀 Ready to run tests"
