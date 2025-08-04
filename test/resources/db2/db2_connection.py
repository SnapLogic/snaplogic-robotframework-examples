from robot.api.deco import keyword
from robot.libraries.BuiltIn import BuiltIn
import ibm_db
import ibm_db_dbi


class db2_connection:
    """Robot Framework library for DB2 database connections"""
    
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
