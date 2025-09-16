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

# Core required variables for Travis builds(available from Travis settings)
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
echo "📝 Creating .env file..."

# Start creating the .env file
{
    echo "# ============================================"
    echo "# Generated for Travis CI build"
    echo "# Date: $(date)"
    echo "# Build: #$TRAVIS_BUILD_NUMBER"
    echo "# ============================================"
    echo ""
    
    echo "# Core Required Variables"
    echo "# ============================================"
    for var in "${required_vars[@]}"; do
        echo "$var=${!var}"
    done
    echo ""
    
} > .env

# Function to merge env files
merge_env_files() {
    local env_dir="$1"
    local category_name="$2"
    
    if [ -d "$env_dir" ]; then
        local files_found=0
        echo "" >> .env
        echo "# ============================================" >> .env
        echo "# $category_name" >> .env
        echo "# ============================================" >> .env
        
        # Find all .env files in the directory
        for env_file in "$env_dir"/.env.*; do
            if [ -f "$env_file" ]; then
                local filename=$(basename "$env_file")
                echo "  📄 Processing: $filename"
                
                # Add source file comment
                echo "" >> .env
                echo "# From: $env_file" >> .env
                echo "# --------------------------------------------" >> .env
                
                # Process each line from the env file
                while IFS= read -r line || [ -n "$line" ]; do
                    # Skip empty lines and comments
                    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                        continue
                    fi
                    
                    # Extract variable name and value
                    if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
                        var_name="${BASH_REMATCH[1]}"
                        var_default="${BASH_REMATCH[2]}"
                        
                        # Check if Travis has overridden this variable
                        if [ -n "${!var_name}" ]; then
                            # Use Travis-provided value
                            echo "$var_name=${!var_name}" >> .env
                            echo "    ✓ $var_name (using Travis value)" >&2
                        else
                            # Use default value from file
                            echo "$var_name=$var_default" >> .env
                            echo "    → $var_name (using default)" >&2
                        fi
                    fi
                done < "$env_file"
                
                files_found=$((files_found + 1))
            fi
        done
        
        if [ $files_found -eq 0 ]; then
            echo "  ⚠️  No .env files found in $env_dir"
        else
            echo "  ✅ Processed $files_found file(s) from $category_name"
        fi
    else
        echo "  ⚠️  Directory not found: $env_dir"
    fi
}

# Process all env_files directories
echo ""
echo "🔄 Merging configuration from env_files directory..."

# Get the script directory to ensure we can find env_files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_FILES_DIR="$SCRIPT_DIR/env_files"

if [ ! -d "$ENV_FILES_DIR" ]; then
    echo "⚠️  Warning: env_files directory not found at $ENV_FILES_DIR"
    echo "   Continuing with only core required variables..."
else
    # Process each category of env files
    merge_env_files "$ENV_FILES_DIR/database_accounts" "DATABASE ACCOUNTS"
    merge_env_files "$ENV_FILES_DIR/messaging_service_accounts" "MESSAGING SERVICE ACCOUNTS"
    merge_env_files "$ENV_FILES_DIR/mock_service_accounts" "MOCK SERVICE ACCOUNTS"
    merge_env_files "$ENV_FILES_DIR/groundplex" "GROUNDPLEX CONFIGURATION"
fi

# Add any additional Travis-specific variables that might be set
echo "" >> .env
echo "# ============================================" >> .env
echo "# Additional Travis Environment Variables" >> .env
echo "# ============================================" >> .env
echo "# Build metadata" >> .env
echo "HMD_HOME=${HMD_HOME:-$TRAVIS_BUILD_DIR}" >> .env

# Add Snowflake variables if they exist (these might not be in env_files)
if [ -n "$SNOWFLAKE_ACCOUNT" ]; then
    echo "" >> .env
    echo "# Snowflake Configuration (from Travis)" >> .env
    echo "SNOWFLAKE_ACCOUNT_NAME=${SNOWFLAKE_ACCOUNT_NAME}" >> .env
    echo "SNOWFLAKE_ACCOUNT=${SNOWFLAKE_ACCOUNT}" >> .env
    echo "SNOWFLAKE_HOSTNAME=${SNOWFLAKE_HOSTNAME}" >> .env
    echo "SNOWFLAKE_DATABASE=${SNOWFLAKE_DATABASE}" >> .env
    echo "SNOWFLAKE_SCHEMA=${SNOWFLAKE_SCHEMA}" >> .env
    echo "SNOWFLAKE_WAREHOUSE=${SNOWFLAKE_WAREHOUSE}" >> .env
    echo "SNOWFLAKE_USERNAME=${SNOWFLAKE_USERNAME}" >> .env
    echo "SNOWFLAKE_PASSWORD=${SNOWFLAKE_PASSWORD}" >> .env
    echo "SNOWFLAKE_ROLE=${SNOWFLAKE_ROLE}" >> .env
    [ -n "$SNOWFLAKE_S3_BUCKET" ] && echo "SNOWFLAKE_S3_BUCKET=${SNOWFLAKE_S3_BUCKET}" >> .env
    [ -n "$SNOWFLAKE_S3_FOLDER" ] && echo "SNOWFLAKE_S3_FOLDER=${SNOWFLAKE_S3_FOLDER}" >> .env
    [ -n "$SNOWFLAKE_S3_ACCESS_KEY" ] && echo "SNOWFLAKE_S3_ACCESS_KEY=${SNOWFLAKE_S3_ACCESS_KEY}" >> .env
    [ -n "$SNOWFLAKE_S3_SECRET_KEY" ] && echo "SNOWFLAKE_S3_SECRET_KEY=${SNOWFLAKE_S3_SECRET_KEY}" >> .env
fi

echo ""
echo "✅ Created .env file successfully"

# Show summary of what was created
echo ""
echo "📋 Summary:"
echo "  - Core required variables: ${#required_vars[@]} (all present)"

# Count total variables in .env file (excluding comments and empty lines)
total_vars=$(grep -E '^[A-Z_][A-Z0-9_]*=' .env | wc -l)
echo "  - Total variables in .env: $total_vars"

# Show categories processed
echo "  - Categories processed:"
[ -d "$ENV_FILES_DIR/database_accounts" ] && echo "    ✓ Database accounts"
[ -d "$ENV_FILES_DIR/messaging_service_accounts" ] && echo "    ✓ Messaging services"  
[ -d "$ENV_FILES_DIR/mock_service_accounts" ] && echo "    ✓ Mock services"
[ -d "$ENV_FILES_DIR/groundplex" ] && echo "    ✓ Groundplex configuration"

echo ""
echo "🚀 Ready to run tests"
