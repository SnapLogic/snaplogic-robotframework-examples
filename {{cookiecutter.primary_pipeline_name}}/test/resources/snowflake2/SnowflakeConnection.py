"""
Snowflake Connection Library for Robot Framework

This library handles Snowflake database connections with both password and key pair authentication.
It properly processes private keys and establishes connections without string conversion issues.

Requirements:
    - snowflake-connector-python
    - cryptography>=3.0.0

Usage in Robot Framework:
    Library    libraries/SnowflakeConnection.py

Author: Swapna Pothana
"""

import os
import snowflake.connector
from typing import Optional, Dict, Any
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend


class SnowflakeConnection:
    """Library for establishing Snowflake connections with key pair authentication"""
    
    ROBOT_LIBRARY_SCOPE = 'GLOBAL'
    
    def __init__(self):
        self.connection = None
        self.cursor = None
    
    def connect_with_keypair(
        self,
        user: str,
        account: str,
        private_key_data: str,
        database: Optional[str] = None,
        schema: Optional[str] = None,
        warehouse: Optional[str] = None,
        role: Optional[str] = None,
        private_key_passphrase: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Connect to Snowflake using key pair authentication.
        
        This method properly handles private key processing and establishes connection
        without string conversion issues that cause "null bytes" errors.
        
        Args:
            user: Snowflake username
            account: Snowflake account identifier
            private_key_data: Private key (PEM format string or file path)
            database: Database name (optional)
            schema: Schema name (optional, defaults to PUBLIC)
            warehouse: Warehouse name (optional)
            role: Role name (optional)
            private_key_passphrase: Passphrase for encrypted keys (optional)
            
        Returns:
            Dictionary with connection details
            
        Raises:
            Exception: If connection fails
            
        Example:
            ${result}=    Connect With Keypair
            ...    user=${SNOWFLAKE_KEYPAIR_USERNAME}
            ...    account=${SNOWFLAKE_ACCOUNT_IDENTIFIER}
            ...    private_key_data=${SNOWFLAKE_KEYPAIR_PRIVATE_KEY}
            ...    database=${SNOWFLAKE_KEYPAIR_DATABASE}
            ...    warehouse=${SNOWFLAKE_KEYPAIR_WAREHOUSE}
            ...    role=${SNOWFLAKE_KEYPAIR_ROLE}
            ...    private_key_passphrase=${SNOWFLAKE_KEYPAIR_PRIVATE_KEY_PASSPHRASE}
        """
        try:
            # Process the private key
            print(f"🔐 Processing private key for user: {user}")
            pkcs8_key_bytes = self._process_private_key(private_key_data, private_key_passphrase)
            print(f"✓ Private key processed successfully ({len(pkcs8_key_bytes)} bytes)")
            
            # Build connection parameters
            conn_params = {
                'user': user,
                'account': account,
                'private_key': pkcs8_key_bytes,
            }
            
            # Add optional parameters
            if database:
                conn_params['database'] = database
            if schema:
                conn_params['schema'] = schema
            if warehouse:
                conn_params['warehouse'] = warehouse
            if role:
                conn_params['role'] = role
            
            # Establish connection
            print(f"🔌 Connecting to Snowflake account: {account}")
            self.connection = snowflake.connector.connect(**conn_params)
            
            print(f"✅ Connected to Snowflake successfully!")
            
            # Return connection details
            return {
                'status': 'SUCCESS',
                'user': user,
                'account': account,
                'database': database or 'Not set',
                'schema': schema or 'Not set',
                'warehouse': warehouse or 'Not set',
                'role': role or 'Not set'
            }
            
        except Exception as e:
            error_msg = f"Key pair authentication failed: {str(e)}"
            print(f"❌ {error_msg}")
            raise Exception(error_msg)
    
    def connect_with_password(
        self,
        user: str,
        password: str,
        account: str,
        database: Optional[str] = None,
        schema: Optional[str] = None,
        warehouse: Optional[str] = None,
        role: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Connect to Snowflake using password authentication.
        
        Args:
            user: Snowflake username
            password: Snowflake password
            account: Snowflake account identifier
            database: Database name (optional)
            schema: Schema name (optional)
            warehouse: Warehouse name (optional)
            role: Role name (optional)
            
        Returns:
            Dictionary with connection details
            
        Example:
            ${result}=    Connect With Password
            ...    user=${SNOWFLAKE_USERNAME}
            ...    password=${SNOWFLAKE_PASSWORD}
            ...    account=${SNOWFLAKE_ACCOUNT_IDENTIFIER}
            ...    database=${SNOWFLAKE_DATABASE}
            ...    warehouse=${SNOWFLAKE_WAREHOUSE}
            ...    role=${SNOWFLAKE_ROLE}
        """
        try:
            # Build connection parameters
            conn_params = {
                'user': user,
                'password': password,
                'account': account,
            }
            
            # Add optional parameters
            if database:
                conn_params['database'] = database
            if schema:
                conn_params['schema'] = schema
            if warehouse:
                conn_params['warehouse'] = warehouse
            if role:
                conn_params['role'] = role
            
            # Establish connection
            print(f"🔌 Connecting to Snowflake with password authentication")
            self.connection = snowflake.connector.connect(**conn_params)
            
            print(f"✅ Connected to Snowflake successfully!")
            
            return {
                'status': 'SUCCESS',
                'user': user,
                'account': account,
                'database': database or 'Not set',
                'schema': schema or 'Not set',
                'warehouse': warehouse or 'Not set',
                'role': role or 'Not set'
            }
            
        except Exception as e:
            error_msg = f"Password authentication failed: {str(e)}"
            print(f"❌ {error_msg}")
            raise Exception(error_msg)
    
    def get_connection(self):
        """
        Get the current Snowflake connection object.
        
        This allows DatabaseLibrary to use the established connection.
        
        Returns:
            The active snowflake connection object
            
        Example:
            ${conn}=    Get Connection
        """
        if not self.connection:
            raise Exception("No active connection. Please connect first.")
        return self.connection
    
    def register_with_database_library(self):
        """
        Register this connection with Robot Framework's DatabaseLibrary.
        
        This allows DatabaseLibrary keywords (Query, Execute SQL String, etc.)
        to use the connection established by SnowflakeConnection.
        
        Example:
            Register With Database Library
        """
        try:
            from robot.libraries.BuiltIn import BuiltIn
            builtin = BuiltIn()
            
            # Get DatabaseLibrary instance
            db_lib = builtin.get_library_instance('DatabaseLibrary')
            
            if self.connection:
                # Manually add our connection to DatabaseLibrary's connection cache
                # DatabaseLibrary stores connections in a list called _connections or similar
                # This is a bit hacky but necessary to integrate our custom connection
                if hasattr(db_lib, '_dbconnection'):
                    db_lib._dbconnection = self.connection
                    print("✓ Connection registered with DatabaseLibrary")
                else:
                    print("⚠ DatabaseLibrary structure may have changed, using alternative registration")
                    # Alternative: Store in our own variable that DatabaseLibrary can access
                    builtin.set_global_variable('${SNOWFLAKE_CONNECTION}', self.connection)
            else:
                raise Exception("No active connection to register")
                
        except Exception as e:
            print(f"⚠ Warning: Could not register with DatabaseLibrary: {e}")
            print("  SQL operations may need to use SnowflakeConnection methods directly")
    
    def close_connection(self):
        """
        Close the Snowflake connection.
        
        Example:
            Close Connection
        """
        if self.connection:
            self.connection.close()
            print("🔌 Snowflake connection closed")
            self.connection = None
            self.cursor = None
    
    def execute_sql_string(self, sql_string: str):
        """
        Execute a SQL statement that doesn't return results (DDL, DML).
        
        Args:
            sql_string: SQL statement to execute
            
        Example:
            Execute SQL String    USE WAREHOUSE MY_WH
            Execute SQL String    CREATE TABLE test (id INT)
        """
        if not self.connection:
            raise Exception("No active connection. Please connect first.")
        
        try:
            cursor = self.connection.cursor()
            cursor.execute(sql_string)
            cursor.close()
            return True
        except Exception as e:
            raise Exception(f"Failed to execute SQL: {str(e)}")
    
    def query(self, sql_query: str):
        """
        Execute a SQL query and return results.
        
        Args:
            sql_query: SQL SELECT statement
            
        Returns:
            List of tuples containing query results
            
        Example:
            ${results}=    Query    SELECT * FROM table
            ${results}=    Query    SHOW DATABASES
        """
        if not self.connection:
            raise Exception("No active connection. Please connect first.")
        
        try:
            cursor = self.connection.cursor()
            cursor.execute(sql_query)
            results = cursor.fetchall()
            cursor.close()
            return results
        except Exception as e:
            raise Exception(f"Failed to execute query: {str(e)}")
    
    def _process_private_key(self, private_key_input: str, passphrase: Optional[str] = None) -> bytes:
        """
        Internal method to process private key into PKCS8 DER format.
        
        Args:
            private_key_input: Private key (PEM string or file path)
            passphrase: Optional passphrase for encrypted keys
            
        Returns:
            Private key in PKCS8 DER format (bytes)
        """
        try:
            # Check if it's a file path
            if os.path.isfile(private_key_input):
                with open(private_key_input, 'rb') as key_file:
                    private_key_pem = key_file.read()
            else:
                # Handle inline PEM string
                cleaned_key = private_key_input
                
                # Replace literal \n with actual newlines
                cleaned_key = cleaned_key.replace('\\n', '\n')
                
                # Handle space-separated keys (common from .env files)
                if '-----BEGIN' in cleaned_key and '-----END' in cleaned_key:
                    # Extract the key type and content
                    if 'BEGIN ENCRYPTED PRIVATE KEY' in cleaned_key:
                        begin_marker = '-----BEGIN ENCRYPTED PRIVATE KEY-----'
                        end_marker = '-----END ENCRYPTED PRIVATE KEY-----'
                    elif 'BEGIN PRIVATE KEY' in cleaned_key:
                        begin_marker = '-----BEGIN PRIVATE KEY-----'
                        end_marker = '-----END PRIVATE KEY-----'
                    elif 'BEGIN RSA PRIVATE KEY' in cleaned_key:
                        begin_marker = '-----BEGIN RSA PRIVATE KEY-----'
                        end_marker = '-----END RSA PRIVATE KEY-----'
                    else:
                        begin_marker = None
                        end_marker = None
                    
                    if begin_marker and end_marker:
                        # Extract base64 content
                        start_idx = cleaned_key.find(begin_marker) + len(begin_marker)
                        end_idx = cleaned_key.find(end_marker)
                        
                        if start_idx > 0 and end_idx > start_idx:
                            # Get base64 content and remove spaces/newlines
                            base64_content = cleaned_key[start_idx:end_idx].strip()
                            base64_content = base64_content.replace(' ', '').replace('\n', '').replace('\r', '')
                            
                            # Reconstruct proper PEM format
                            lines = [begin_marker]
                            for i in range(0, len(base64_content), 64):
                                lines.append(base64_content[i:i+64])
                            lines.append(end_marker)
                            
                            cleaned_key = '\n'.join(lines)
                
                private_key_pem = cleaned_key.encode('utf-8')
            
            # Prepare passphrase
            password_bytes = None
            if passphrase and passphrase.strip():
                password_bytes = passphrase.encode('utf-8')
            
            # Load the private key
            private_key = serialization.load_pem_private_key(
                private_key_pem,
                password=password_bytes,
                backend=default_backend()
            )
            
            # Serialize to PKCS8 DER format
            pkcs8_key = private_key.private_bytes(
                encoding=serialization.Encoding.DER,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption()
            )
            
            return pkcs8_key
            
        except Exception as e:
            raise Exception(f"Failed to process private key: {str(e)}")
