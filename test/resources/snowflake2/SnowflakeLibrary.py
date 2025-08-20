"""
Custom Snowflake Library for Robot Framework
"""
import snowflake.connector
from robot.api.deco import keyword
from robot.libraries.BuiltIn import BuiltIn
from robot.api import logger

class SnowflakeLibrary:
    ROBOT_LIBRARY_SCOPE = 'SUITE'  # Share instance across all tests in a suite
    
    def __init__(self):
        self.connection = None
        self.cursor = None
    
    @keyword
    def connect_to_snowflake_db(self, account, user, password, database, schema, warehouse, role=None):
        """Connect to Snowflake database with proper parameters"""
        # Check if we already have a valid connection
        if self.connection:
            try:
                # Test if connection is still alive
                self.cursor.execute("SELECT 1")
                logger.info(f"Reusing existing connection to Snowflake account: {account}")
                return self.connection
            except:
                # Connection is dead, close it and create new one
                logger.info("Existing connection is dead, creating new one")
                try:
                    self.connection.close()
                except:
                    pass
        
        try:
            conn_params = {
                'account': account,
                'user': user,
                'password': password,
                'database': database,
                'schema': schema,
                'warehouse': warehouse
            }
            
            if role:
                conn_params['role'] = role
            
            self.connection = snowflake.connector.connect(**conn_params)
            self.cursor = self.connection.cursor()
            
            # Log success
            BuiltIn().log(f"Successfully connected to Snowflake account: {account}")
            return self.connection
            
        except Exception as e:
            raise Exception(f"Failed to connect to Snowflake: {str(e)}")
    
    @keyword
    # def execute_snowflake_query(self, query):
    #     """Execute a query and return results"""
    #     if not self.cursor:
    #         raise Exception("Not connected to Snowflake. Please connect first.")
        
    #     self.cursor.execute(query)
    #     results = self.cursor.fetchall()
    #     return results
    def execute_snowflake_query(self, query):
        """
        Execute a query and return results
        
        If not connected, establishes a connection automatically.
        For SELECT queries, returns the results.
        For other queries, executes and commits.
        
        Args:
            query: SQL query to execute
        
        Returns:
            - For SELECT queries: List of tuples containing results
            - For other queries: "Query executed successfully"
        """
        # Auto-connect if not connected
        if not self.cursor:
            raise Exception("Not connected to Snowflake. Please connect first.")
        
        try:
            self.cursor.execute(query)
            if query.strip().upper().startswith('SELECT'):
                results = self.cursor.fetchall()
                logger.info(f"Query returned {len(results)} rows")
                return results
            else:
                self.connection.commit()
                logger.info("Query executed successfully")
                return "Query executed successfully"
        except Exception as e:
            logger.error(f"Query execution failed: {str(e)}")
            raise Exception(f"Query execution failed: {str(e)}")
    
    @keyword
    def execute_snowflake_command(self, command):
        """Execute a command without returning results"""
        if not self.cursor:
            raise Exception("Not connected to Snowflake. Please connect first.")
        
        self.cursor.execute(command)
        self.connection.commit()
        return "Command executed successfully"
    
    @keyword
    def disconnect_from_snowflake(self):
        """Close the Snowflake connection"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
        BuiltIn().log("Disconnected from Snowflake")
        return "Disconnected from Snowflake"
    
    @keyword
    def is_connected(self):
        """
        Check if currently connected to Snowflake
        
        Returns:
            Boolean indicating connection status
        """
        if not self.connection or not self.cursor:
            return False
        
        try:
            self.cursor.execute("SELECT 1")
            return True
        except:
            return False
    
    @keyword
    def get_snowflake_version(self):
        """Get Snowflake version"""
        if not self.cursor:
            raise Exception("Not connected to Snowflake. Please connect first.")
        
        self.cursor.execute("SELECT CURRENT_VERSION()")
        version = self.cursor.fetchone()[0]
        return version

    @keyword
    def get_current_snowflake_context(self):
        """
        Get current Snowflake context (user, database, schema, warehouse, role)
        
        Returns:
            Dictionary with current context information
        """
        if not self.cursor:
            raise Exception("Not connected to Snowflake. Please connect first.")
        
        self.cursor.execute("""
            SELECT CURRENT_USER() as user, 
                   CURRENT_DATABASE() as database,
                   CURRENT_SCHEMA() as schema,
                   CURRENT_WAREHOUSE() as warehouse,
                   CURRENT_ROLE() as role,
                   CURRENT_ACCOUNT() as account
        """)
        result = self.cursor.fetchone()
        
        context = {
            'user': result[0],
            'database': result[1],
            'schema': result[2],
            'warehouse': result[3],
            'role': result[4],
            'account': result[5]
        }
        
        logger.info(f"Current context: {context}")
        return context
    
    @keyword
    def create_stage(self, stage_name, stage_type='INTERNAL'):
        """
        Create a Snowflake stage for data loading
        
        Args:
            stage_name: Name of the stage to create
            stage_type: Type of stage (INTERNAL or EXTERNAL)
            
        Returns:
            Success message
        """
        if not self.cursor:
            raise Exception("Not connected to Snowflake. Please connect first.")
        
        try:
            if stage_type == 'INTERNAL':
                query = f"CREATE OR REPLACE STAGE {stage_name}"
            else:
                # For external stages, additional parameters would be needed
                raise NotImplementedError("External stages require additional configuration")
            
            self.cursor.execute(query)
            logger.info(f"Stage {stage_name} created successfully")
            return f"Stage {stage_name} created successfully"
        except Exception as e:
            logger.error(f"Failed to create stage: {str(e)}")
            raise Exception(f"Failed to create stage: {str(e)}")
    
    @keyword
    def upload_file_to_stage(self, file_path, stage_name):
        """
        Upload a file to a Snowflake stage
        Note: This requires the file to be accessible from the Snowflake client
        
        Args:
            file_path: Local path to the file
            stage_name: Target stage name
            
        Returns:
            Upload result
        """
        if not self.cursor:
            raise Exception("Not connected to Snowflake. Please connect first.")
        
        try:
            query = f"PUT file://{file_path} @{stage_name}"
            self.cursor.execute(query)
            result = self.cursor.fetchall()
            logger.info(f"File uploaded successfully: {result}")
            return result
        except Exception as e:
            logger.error(f"Failed to upload file: {str(e)}")
            raise Exception(f"Failed to upload file: {str(e)}")
    
    @keyword
    def test_time_travel(self, table_name, minutes_ago=5):
        """
        Test Snowflake's time travel feature
        
        Args:
            table_name: Table to query
            minutes_ago: How many minutes to go back
            
        Returns:
            Query result from the past
        """
        if not self.cursor:
            raise Exception("Not connected to Snowflake. Please connect first.")
        
        try:
            query = f"SELECT COUNT(*) FROM {table_name} AT(OFFSET => -{minutes_ago * 60})"
            self.cursor.execute(query)
            result = self.cursor.fetchone()
            logger.info(f"Row count {minutes_ago} minutes ago: {result[0]}")
            return result[0]
        except Exception as e:
            logger.error(f"Time travel query failed: {str(e)}")
            raise Exception(f"Time travel query failed: {str(e)}")
    
    @keyword
    def create_table_if_not_exists(self, table_name, table_definition):
        """
        Create a table if it doesn't already exist
        
        Args:
            table_name: Name of the table
            table_definition: Column definitions (e.g., "(id NUMBER, name VARCHAR(100))")
            
        Returns:
            Success message
        """
        if not self.cursor:
            raise Exception("Not connected to Snowflake. Please connect first.")
        
        query = f"CREATE TABLE IF NOT EXISTS {table_name} {table_definition}"
        return self.execute_snowflake_command(query)
    
    @keyword
    def drop_table_if_exists(self, table_name):
        """
        Drop a table if it exists
        
        Args:
            table_name: Name of the table to drop
            
        Returns:
            Success message
        """
        if not self.cursor:
            raise Exception("Not connected to Snowflake. Please connect first.")
        
        query = f"DROP TABLE IF EXISTS {table_name}"
        return self.execute_snowflake_command(query)
    
    @keyword
    def get_row_count(self, table_name, where_clause=None):
        """
        Get the number of rows in a table
        
        Args:
            table_name: Name of the table
            where_clause: Optional WHERE clause (without 'WHERE' keyword)
            
        Returns:
            Row count
        """
        if not self.cursor:
            raise Exception("Not connected to Snowflake. Please connect first.")
        
        if where_clause:
            query = f"SELECT COUNT(*) FROM {table_name} WHERE {where_clause}"
        else:
            query = f"SELECT COUNT(*) FROM {table_name}"
        
        result = self.execute_snowflake_query(query)
        return result[0][0]
    
    @keyword
    def table_should_exist(self, table_name):
        """
        Verify that a table exists in the current schema
        
        Args:
            table_name: Name of the table
            
        Raises:
            Exception if table doesn't exist
        """
        if not self.cursor:
            raise Exception("Not connected to Snowflake. Please connect first.")
        
        query = f"""
            SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_NAME = '{table_name.upper()}' 
            AND TABLE_SCHEMA = CURRENT_SCHEMA()
        """
        result = self.execute_snowflake_query(query)
        
        if result[0][0] == 0:
            raise Exception(f"Table {table_name} does not exist in current schema")
        
        logger.info(f"Table {table_name} exists")
        return True
    
    @keyword
    def use_database(self, database_name):
        """
        Switch to a different database
        
        Args:
            database_name: Name of the database
            
        Returns:
            Success message
        """
        return self.execute_snowflake_command(f"USE DATABASE {database_name}")
    
    @keyword
    def use_schema(self, schema_name):
        """
        Switch to a different schema
        
        Args:
            schema_name: Name of the schema
            
        Returns:
            Success message
        """
        return self.execute_snowflake_command(f"USE SCHEMA {schema_name}")
    
    @keyword
    def use_warehouse(self, warehouse_name):
        """
        Switch to a different warehouse
        
        Args:
            warehouse_name: Name of the warehouse
            
        Returns:
            Success message
        """
        return self.execute_snowflake_command(f"USE WAREHOUSE {warehouse_name}")

    