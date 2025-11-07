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

# DEBUG: Show all environment variables related to databases
echo "🔍 DEBUG: All Travis CI environment variables (filtered for databases):"
echo "=========================================="
env | grep -E "^(SNOWFLAKE|ORACLE|POSTGRES|MYSQL|SQLSERVER|DB2)_" | sort | while IFS='=' read -r key value; do
    if [[ "$key" == *"PASSWORD"* ]]; then
        echo "  $key=${value:0:3}*** (masked)"
    else
        echo "  $key=$value"
    fi
done
echo "=========================================="
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
    "PIPELINES_LOCATION_PATH"
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
                
                # DEBUG: Extra notification for Snowflake file
                if [[ "$filename" == ".env.snowflake" ]]; then
                    echo "     🎯 SNOWFLAKE FILE DETECTED - Enabling verbose debugging" >&2
                fi
                
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
                        
                        # DEBUG: Extra verbose output for Snowflake variables
                        if [[ "$var_name" == SNOWFLAKE_USERNAME || "$var_name" == SNOWFLAKE_PASSWORD ]]; then
                            echo "" >&2
                            echo "    🔍 DEBUG: Processing $var_name" >&2
                            echo "       - Line from file: '$line'" >&2
                            echo "       - Extracted var_name: '$var_name'" >&2
                            echo "       - Extracted var_default: '$var_default'" >&2
                            echo "       - Travis env value: '${!var_name}'" >&2
                            echo "       - Is Travis value set? [ -n \"${!var_name}\" ] = $([ -n "${!var_name}" ] && echo 'YES' || echo 'NO')" >&2
                        fi
                        
                        # Check if Travis has overridden this variable
                        if [ -n "${!var_name}" ]; then
                            # Use Travis-provided value
                            echo "$var_name=${!var_name}" >> .env
                            echo "    ✓ $var_name (using Travis value)" >&2
                            
                            # DEBUG: Confirm what was written for Snowflake vars
                            if [[ "$var_name" == SNOWFLAKE_USERNAME || "$var_name" == SNOWFLAKE_PASSWORD ]]; then
                                echo "       - ✅ Written to .env: $var_name=${!var_name:0:10}..." >&2
                            fi
                        else
                            # Use default value from file
                            echo "$var_name=$var_default" >> .env
                            echo "    → $var_name (using default)" >&2
                            
                            # DEBUG: Warn if Snowflake variables are using empty defaults
                            if [[ "$var_name" == SNOWFLAKE_USERNAME || "$var_name" == SNOWFLAKE_PASSWORD ]]; then
                                echo "       - ⚠️  WARNING: Using empty default for $var_name!" >&2
                            fi
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

# DEBUG: Check Snowflake variables before processing
echo ""
echo "🔍 DEBUG: Snowflake variables in Travis environment:"
echo "  SNOWFLAKE_USERNAME='$SNOWFLAKE_USERNAME'"
echo "  SNOWFLAKE_PASSWORD='${SNOWFLAKE_PASSWORD:0:3}***' (masked)"
echo ""

# Process all env_files directories
echo ""
echo "🔄 Merging configuration from env_files directory..."

# Get the script directory and project root to ensure we can find env_files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILES_DIR="$PROJECT_ROOT/env_files"

echo "🔍 DEBUG: Directory paths:"
echo "  Script dir: $SCRIPT_DIR"
echo "  Project root: $PROJECT_ROOT"
echo "  Env files dir: $ENV_FILES_DIR"
echo ""

# Process all subdirectories in env_files
# The env_files directory is part of the repository and should always exist
echo ""
echo "🔄 Processing all configuration directories in env_files..."

for dir in "$ENV_FILES_DIR"/*; do
    if [ -d "$dir" ]; then
        dir_name=$(basename "$dir")
        # Convert directory name to title case for display
        # e.g., database_accounts -> DATABASE ACCOUNTS
        display_name=$(echo "$dir_name" | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
        merge_env_files "$dir" "$display_name"
    fi
done

# Add any additional Travis-specific variables that might be set
echo "" >> .env
echo "# ============================================" >> .env
echo "# Additional Travis Environment Variables" >> .env
echo "# ============================================" >> .env
echo "# Build metadata" >> .env
echo "HMD_HOME=${HMD_HOME:-$TRAVIS_BUILD_DIR}" >> .env

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
for dir in "$ENV_FILES_DIR"/*; do
    if [ -d "$dir" ]; then
        dir_name=$(basename "$dir")
        # Convert directory name to readable format
        display_name=$(echo "$dir_name" | tr '_' ' ' | sed 's/\b\(\w\)/\u\1/g')
        echo "    ✓ $display_name"
    fi
done

# DEBUG: Comprehensive .env file verification
echo ""
echo "========================================"
echo "🔍 DEBUG: FINAL .env FILE VERIFICATION"
echo "========================================"

if [ -f .env ]; then
    echo "✅ .env file exists"
    echo "   File size: $(wc -c < .env) bytes"
    echo "   Total lines: $(wc -l < .env) lines"
    echo ""
    
    echo "SNOWFLAKE variables in .env:"
    echo "----------------------------"
    if grep -q "^SNOWFLAKE_" .env; then
        grep "^SNOWFLAKE_" .env | while IFS='=' read -r key value; do
            if [[ "$key" == *"PASSWORD"* ]]; then
                echo "  $key=${value:0:3}*** (masked, length: ${#value})"
            else
                echo "  $key=$value (length: ${#value})"
            fi
        done
    else
        echo "  ⚠️  NO SNOWFLAKE_* variables found in .env file!"
        echo ""
        echo "  Checking if database_accounts section exists in .env:"
        if grep -q "DATABASE ACCOUNTS" .env; then
            echo "    ✓ DATABASE ACCOUNTS section found"
            echo "    Here's what's in that section:"
            sed -n '/DATABASE ACCOUNTS/,/^# =/p' .env | head -30
        else
            echo "    ✗ DATABASE ACCOUNTS section NOT found"
        fi
    fi
else
    echo "❌ .env file does NOT exist!"
    exit 1
fi

echo ""
echo "Comparing Travis CI env vs .env file:"
echo "--------------------------------------"
for var in SNOWFLAKE_USERNAME SNOWFLAKE_PASSWORD SNOWFLAKE_HOSTNAME SNOWFLAKE_DATABASE; do
    travis_value="${!var}"
    if [ -n "$travis_value" ]; then
        if [[ "$var" == *"PASSWORD"* ]]; then
            echo "  Travis $var: SET (length: ${#travis_value})"
        else
            echo "  Travis $var: '$travis_value' (length: ${#travis_value})"
        fi
    else
        echo "  Travis $var: NOT SET"
    fi
    
    if grep -q "^$var=" .env; then
        env_value=$(grep "^$var=" .env | cut -d'=' -f2-)
        if [ -n "$env_value" ]; then
            if [[ "$var" == *"PASSWORD"* ]]; then
                echo "    .env $var: SET (length: ${#env_value})"
            else
                echo "    .env $var: '$env_value' (length: ${#env_value})"
            fi
        else
            echo "    .env $var: EMPTY ❌"
        fi
    else
        echo "    .env $var: MISSING ❌"
    fi
    echo ""
done

echo "========================================"
echo ""
echo "🚀 Ready to run tests"
