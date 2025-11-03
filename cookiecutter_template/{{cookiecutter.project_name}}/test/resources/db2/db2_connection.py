from robot.api.deco import keyword
from robot.libraries.BuiltIn import BuiltIn
import ibm_db
import ibm_db_dbi


class db2_connection:
    """Robot Framework library for DB2 database connections"""
    
    # ROBOT_LIBRARY_SCOPE defines the lifecycle and scope of a library instance
    # Possible values:
    #   - 'SUITE': One instance per test suite (what we're using)
    #     * Library instance is created when suite starts and destroyed when it ends
    #     * All tests in the same suite share the same library instance
    #     * Perfect for database connections - connect once at suite setup, all tests use that connection
    #     * State is maintained throughout the suite
    #   - 'TEST': New instance for each test case
    #     * Library is created at test start and destroyed at test end
    #     * Each test gets a fresh instance
    #     * Good for ensuring test isolation
    #   - 'GLOBAL': Single instance for entire test run (default if not specified)
    #     * Library is created once and shared across all suites and tests
    #     * State persists across everything
    #     * Good for expensive initializations
    #
    # Why SUITE scope for DB2 connection?
    #   1. Connection reuse - Don't reconnect for every test (expensive)
    #   2. Suite isolation - Different suites might need different database states
    #   3. Resource efficiency - One connection per suite, not per test
    #   4. Setup/Teardown alignment - Matches Robot's Suite Setup/Teardown pattern
    #
    # Example flow:
    #   Test Suite A starts
    #     → db2_connection instance created
    #     → Suite Setup: Connect to DB2
    #     → Test 1 runs (uses same connection)
    #     → Test 2 runs (uses same connection)
    #     → Test 3 runs (uses same connection)
    #     → Suite Teardown
    #     → db2_connection instance destroyed
    #   Test Suite B starts
    #     → NEW db2_connection instance created
    #     → Fresh connection
    ROBOT_LIBRARY_SCOPE = 'SUITE'
    
    def __init__(self):
        self.connection = None
    
    @keyword("Connect Db2 To Database Library")
    def connect_db2_to_database_library(self, dbname, dbhost, dbport, dbuser, dbpass):
        """Connect to DB2 using DatabaseLibrary
        
        Args:
            dbname: Database name
            dbhost: Database host
            dbport: Database port
            dbuser: Database username
            dbpass: Database password
            
        Returns:
            str: Connection status message
        """
        try:
            # Get DatabaseLibrary instance
            db_lib = BuiltIn().get_library_instance('DatabaseLibrary')
            
            # Use DatabaseLibrary's connect method with ibm_db_dbi module
            # DatabaseLibrary expects: module_name, database, username, password, host, port
            db_lib.connect_to_database(
                'ibm_db_dbi',
                dbname,
                dbuser,
                dbpass,
                dbhost,
                dbport
            )
            
            return "Connected to DB2"
        except Exception as e:
            raise Exception(f"Failed to connect to DB2: {str(e)}")
