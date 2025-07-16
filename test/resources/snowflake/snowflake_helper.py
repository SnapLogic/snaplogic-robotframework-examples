"""
Snowflake Connection Helper for Robot Framework Tests
=====================================================

This module provides utility functions for connecting to Snowflake from Robot Framework tests.

PURPOSE:
--------
This helper file provides Python functions that can be used as Robot Framework keywords
for advanced Snowflake operations that might be difficult to do with just DatabaseLibrary.

KEY FEATURES:
-------------
1. Direct Snowflake cloud connection using snowflake-connector-python
2. SnowSQL Docker container command execution
3. Snowflake-specific features (Time Travel, Stages, Bulk Loading)
4. Environment-based configuration
5. Better error handling and logging

WHEN TO USE THIS HELPER:
------------------------
- Time Travel Operations: Testing Snowflake's unique time travel feature
- Stage Operations: Bulk data loading through stages
- Complex Queries: When DatabaseLibrary isn't enough
- SnowSQL Integration: If you need to use the SnowSQL client container
- Environment-based Config: Connecting using environment variables

HOW TO USE IN ROBOT TESTS:
--------------------------
*** Settings ***
Library    test/suite/test_data/python_helper_files/snowflake_helper.py

*** Test Cases ***
Test Snowflake Time Travel
    Connect To Snowflake Cloud
    ${old_count}=    Test Time Travel    CUSTOMERS    5
    Log    Customer count 5 minutes ago: ${old_count}

Execute Complex Query
    ${result}=    Execute Snowflake Query    
    ...    SELECT * FROM ORDERS WHERE ORDER_DATE > DATEADD(day, -7, CURRENT_DATE())
    Log    Recent orders: ${result}

Run SnowSQL Command
    # This uses the Docker container if you have it running
    ${output}=    Run Snowsql Command    SHOW WAREHOUSES
    Log    ${output}

BENEFITS:
---------
- Reusable Functions: Write once, use in many tests
- Error Handling: Better error messages and logging
- Snowflake-Specific: Access features not available in generic DatabaseLibrary
- Flexibility: Can use either direct connection or SnowSQL client

NOTE:
-----
You can use this helper alongside or instead of DatabaseLibrary, depending on your needs.
It's particularly useful for Snowflake-specific features that generic database libraries don't support.
"""

import os
import snowflake.connector
from robot.api import logger


class SnowflakeHelper:
    """
    Helper class for Snowflake operations in Robot Framework
    
    This class manages Snowflake connections and provides methods for:
    - Direct cloud connections
    - SnowSQL client container integration
    - Snowflake-specific features (stages, time travel, etc.)
    
    The class maintains a single connection and cursor that can be reused
    across multiple operations for efficiency.
    """
    
    def __init__(self):
        self.connection = None
        self.cursor = None
    
    def connect_to_snowflake_with_config(self, config_file_path=None):
        """
        Connect to Snowflake using a configuration file or environment variables
        
        This method establishes a direct connection to Snowflake cloud service.
        No Docker container or local database is needed - it connects over the internet.
        
        Connection priority:
        1. Environment variables (SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, etc.)
        2. Config file (if provided)
        3. Default values for warehouse, database, schema, and role
        
        Args:
            config_file_path: Path to SnowSQL config file (optional)
                             Defaults to docker/snowflake-config/config
        
        Returns:
            Connection object
            
        Environment Variables:
            SNOWFLAKE_ACCOUNT: Your account identifier (e.g., xy12345.us-east-1.aws)
            SNOWFLAKE_USER: Your username
            SNOWFLAKE_PASSWORD: Your password
            SNOWFLAKE_WAREHOUSE: Compute warehouse (default: COMPUTE_WH)
            SNOWFLAKE_DATABASE: Database name (default: TESTDB)
            SNOWFLAKE_SCHEMA: Schema name (default: SNAPTEST)
            SNOWFLAKE_ROLE: User role (default: SYSADMIN)
        """
        # If using SnowSQL config file, parse it
        # For now, we'll use environment variables or direct parameters
        
        connection_params = {
            'account': os.getenv('SNOWFLAKE_ACCOUNT'),
            'user': os.getenv('SNOWFLAKE_USER'),
            'password': os.getenv('SNOWFLAKE_PASSWORD'),
            'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
            'database': os.getenv('SNOWFLAKE_DATABASE', 'TESTDB'),
            'schema': os.getenv('SNOWFLAKE_SCHEMA', 'SNAPTEST'),
            'role': os.getenv('SNOWFLAKE_ROLE', 'SYSADMIN')
        }
        
        logger.info(f"Connecting to Snowflake account: {connection_params['account']}")
        
        try:
            self.connection = snowflake.connector.connect(**connection_params)
            self.cursor = self.connection.cursor()
            logger.info("Successfully connected to Snowflake")
            return self.connection
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {str(e)}")
            raise
    
    def execute_snowsql_command(self, command):
        """
        Execute a command using the SnowSQL client container
        
        This method is an ALTERNATIVE to direct connection. It uses Docker exec
        to run commands in the snowsql-client container. This is useful when:
        - You need SnowSQL-specific features
        - You want to run SQL scripts exactly as they would run in SnowSQL
        - You're testing SnowSQL command compatibility
        
        PREREQUISITE: The SnowSQL client container must be running
        (started with 'make snowflake-start')
        
        Args:
            command: SQL command to execute
            
        Returns:
            Command output as string
            
        Example:
            output = execute_snowsql_command("SHOW DATABASES")
            output = execute_snowsql_command("SELECT COUNT(*) FROM CUSTOMERS")
        """
        import subprocess
        
        docker_command = [
            'docker', 'exec', '-it', 'snowsql-client',
            'snowsql', '-c', 'example', '-q', command
        ]
        
        try:
            result = subprocess.run(
                docker_command,
                capture_output=True,
                text=True,
                check=True
            )
            logger.info(f"Command output: {result.stdout}")
            return result.stdout
        except subprocess.CalledProcessError as e:
            logger.error(f"Command failed: {e.stderr}")
            raise
    
    def load_data_from_stage(self, stage_name, table_name, file_format=None):
        """
        Load data from a Snowflake stage into a table
        
        Args:
            stage_name: Name of the Snowflake stage
            table_name: Target table name
            file_format: File format specification (optional)
        """
        try:
            if file_format:
                query = f"COPY INTO {table_name} FROM @{stage_name} FILE_FORMAT = {file_format}"
            else:
                query = f"COPY INTO {table_name} FROM @{stage_name}"
            
            self.cursor.execute(query)
            result = self.cursor.fetchone()
            logger.info(f"Data loaded successfully: {result}")
            return result
        except Exception as e:
            logger.error(f"Failed to load data: {str(e)}")
            raise
    
    def create_stage(self, stage_name, stage_type='INTERNAL'):
        """
        Create a Snowflake stage for data loading
        
        Args:
            stage_name: Name of the stage to create
            stage_type: Type of stage (INTERNAL or EXTERNAL)
        """
        try:
            if stage_type == 'INTERNAL':
                query = f"CREATE OR REPLACE STAGE {stage_name}"
            else:
                # For external stages, additional parameters would be needed
                raise NotImplementedError("External stages require additional configuration")
            
            self.cursor.execute(query)
            logger.info(f"Stage {stage_name} created successfully")
        except Exception as e:
            logger.error(f"Failed to create stage: {str(e)}")
            raise
    
    def upload_file_to_stage(self, file_path, stage_name):
        """
        Upload a file to a Snowflake stage
        Note: This requires the file to be accessible from the Snowflake client
        
        Args:
            file_path: Local path to the file
            stage_name: Target stage name
        """
        try:
            query = f"PUT file://{file_path} @{stage_name}"
            self.cursor.execute(query)
            result = self.cursor.fetchall()
            logger.info(f"File uploaded successfully: {result}")
            return result
        except Exception as e:
            logger.error(f"Failed to upload file: {str(e)}")
            raise
    
    def test_time_travel(self, table_name, minutes_ago=5):
        """
        Test Snowflake's time travel feature
        
        Args:
            table_name: Table to query
            minutes_ago: How many minutes to go back
            
        Returns:
            Query result from the past
        """
        try:
            query = f"SELECT COUNT(*) FROM {table_name} AT(OFFSET => -{minutes_ago * 60})"
            self.cursor.execute(query)
            result = self.cursor.fetchone()
            logger.info(f"Row count {minutes_ago} minutes ago: {result[0]}")
            return result[0]
        except Exception as e:
            logger.error(f"Time travel query failed: {str(e)}")
            raise
    
    def close_connection(self):
        """Close the Snowflake connection"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
            logger.info("Snowflake connection closed")


# =============================================================================
# ROBOT FRAMEWORK KEYWORD FUNCTIONS
# =============================================================================
# These functions are designed to be imported and used directly in Robot tests
# They handle connection management and provide simple interfaces for testing

def connect_to_snowflake_cloud():
    """
    Robot Framework keyword to connect to Snowflake
    
    This keyword establishes a connection to Snowflake cloud using environment variables.
    No arguments needed - configure connection through environment variables:
    - SNOWFLAKE_ACCOUNT
    - SNOWFLAKE_USER
    - SNOWFLAKE_PASSWORD
    - SNOWFLAKE_DATABASE (optional)
    - SNOWFLAKE_WAREHOUSE (optional)
    
    Usage in Robot:
        Connect To Snowflake Cloud
    
    Returns:
        Connection object
    """
    helper = SnowflakeHelper()
    return helper.connect_to_snowflake_with_config()


def execute_snowflake_query(query):
    """
    Robot Framework keyword to execute a Snowflake query
    
    This keyword handles the complete lifecycle:
    1. Connects to Snowflake
    2. Executes the query
    3. Returns results (for SELECT) or success message
    4. Closes the connection
    
    Args:
        query: SQL query to execute
    
    Returns:
        - For SELECT queries: List of tuples containing results
        - For other queries: "Query executed successfully"
    
    Usage in Robot:
        ${result}=    Execute Snowflake Query    SELECT * FROM CUSTOMERS LIMIT 5
        ${result}=    Execute Snowflake Query    CREATE TABLE TEST (id NUMBER)
    
    Note: This creates a new connection for each query. For multiple queries,
          consider using DatabaseLibrary with snowflake-connector-python instead.
    """
    helper = SnowflakeHelper()
    helper.connect_to_snowflake_with_config()
    
    try:
        helper.cursor.execute(query)
        if query.strip().upper().startswith('SELECT'):
            return helper.cursor.fetchall()
        else:
            helper.connection.commit()
            return "Query executed successfully"
    finally:
        helper.close_connection()


def run_snowsql_command(command):
    """
    Robot Framework keyword to run SnowSQL client commands
    
    This keyword executes commands through the SnowSQL Docker container.
    It's an alternative to direct Python connection and useful for:
    - Testing SnowSQL-specific syntax
    - Running commands exactly as they would in SnowSQL CLI
    - Debugging connection issues
    
    PREREQUISITE: SnowSQL container must be running (make snowflake-start)
    
    Args:
        command: SQL command or SnowSQL command to execute
    
    Returns:
        Command output as string
    
    Usage in Robot:
        ${output}=    Run Snowsql Command    SHOW WAREHOUSES
        ${output}=    Run Snowsql Command    SELECT CURRENT_VERSION()
        ${output}=    Run Snowsql Command    !help
    
    Note: This method is slower than direct connection as it uses Docker exec.
    """
    helper = SnowflakeHelper()
    return helper.execute_snowsql_command(command)
