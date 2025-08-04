from robot.api.deco import keyword
from robot.libraries.BuiltIn import BuiltIn
import ibm_db
import ibm_db_dbi



@keyword("Connect Db2 To Database Library")  # ✅ Proper keyword registration
def connect_db2_to_database_library(self, dbname, dbhost, dbport, dbuser, dbpass):
        """Connect to DB2 and register with DatabaseLibrary"""
        conn_str = f"DATABASE={dbname};HOSTNAME={dbhost};PORT={dbport};PROTOCOL=TCPIP;UID={dbuser};PWD={dbpass}"
        ibm_conn = ibm_db.connect(conn_str, "", "")
        db_conn = ibm_db_dbi.Connection(ibm_conn)

        db_lib = BuiltIn().get_library_instance('DatabaseLibrary')
        db_lib._dbconnection = db_conn

        return "Connected to DB2"