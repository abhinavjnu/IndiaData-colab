import unittest
import os
import json
import duckdb
from pathlib import Path
import sys

# Add project root to path to import duckdb_mcp_server
sys.path.append(str(Path(__file__).parent.parent))

# Set env var before import if possible, but module import happens once.
# So we need to rely on the server being robust or reload it.
# For simplicity, we'll setup the environment before importing.
TEST_PARQUET = "tests/test_data.parquet"
TEST_SECRET = "tests/secret.txt"
os.environ["PLFS_DATA_PATH"] = TEST_PARQUET

# Import the server module
import duckdb_mcp_server

class TestDuckDBMCPServer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Create dummy parquet file
        conn = duckdb.connect()
        conn.execute("CREATE TABLE t (a INTEGER); INSERT INTO t VALUES (1);")
        conn.execute(f"COPY t TO '{TEST_PARQUET}' (FORMAT PARQUET);")
        conn.close()

        # Create secret file
        with open(TEST_SECRET, "w") as f:
            f.write("THIS_IS_A_SECRET")

        # Initialize server database (in case import happened before env var was set)
        # We can manually call setup_database again to refresh conn
        # But setup_database writes to global conn.
        # We need to monkeypatch or just re-run setup
        duckdb_mcp_server.PARQUET_FILE = Path(TEST_PARQUET)
        duckdb_mcp_server.conn = duckdb_mcp_server.setup_database()

    @classmethod
    def tearDownClass(cls):
        if os.path.exists(TEST_PARQUET):
            os.remove(TEST_PARQUET)
        if os.path.exists(TEST_SECRET):
            os.remove(TEST_SECRET)

    def test_legitimate_query(self):
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "query_plfs",
                "arguments": {
                    "sql": "SELECT * FROM plfs"
                }
            }
        }
        response = duckdb_mcp_server.handle_request(payload)
        self.assertIn("result", response)
        content = response["result"]["content"][0]["text"]
        self.assertIn("1", content)

    def test_exploit_blocked(self):
        payload = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "query_plfs",
                "arguments": {
                    "sql": f"SELECT * FROM read_csv('{TEST_SECRET}', header=False)"
                }
            }
        }
        response = duckdb_mcp_server.handle_request(payload)
        self.assertIn("error", response)
        msg = response["error"]["message"]
        # Error message usually contains "Permission Error" or "disabled by configuration"
        self.assertTrue("Permission Error" in msg or "disabled by configuration" in msg,
                        f"Unexpected error message: {msg}")

    def test_sample_plfs_limit_validation(self):
        # Test string limit which should be parsed or rejected if not int
        payload = {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "sample_plfs",
                "arguments": {
                    "limit": "1; DROP TABLE plfs; --"
                }
            }
        }
        response = duckdb_mcp_server.handle_request(payload)
        self.assertIn("error", response)
        self.assertEqual(response["error"]["code"], -32602) # Invalid params

if __name__ == "__main__":
    unittest.main()
