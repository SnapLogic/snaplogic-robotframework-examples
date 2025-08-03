from robot.libraries.BuiltIn import BuiltIn
import ibm_db
import ibm_db_dbi

class DB2Connection:
    
    @staticmethod
    def connect_db2_to_database_library(dbname, dbhost, dbport, dbuser, dbpass):
        """Connect to DB2 and register with DatabaseLibrary"""
        # Build connection string
        conn_str = f"DATABASE={dbname};HOSTNAME={dbhost};PORT={dbport};PROTOCOL=TCPIP;UID={dbuser};PWD={dbpass}"
        
        # Connect using ibm_db
        ibm_conn = ibm_db.connect(conn_str, "", "")
        
        # Wrap with DB-API 2.0
        db_conn = ibm_db_dbi.Connection(ibm_conn)
        
        # Get DatabaseLibrary instance and set connection
        db_lib = BuiltIn().get_library_instance('DatabaseLibrary')
        db_lib._dbconnection = db_conn
        
        return "Connected to DB2"