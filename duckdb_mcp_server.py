#!/usr/bin/env python
"""
DuckDB MCP Server for PLFS Data Analysis
=========================================
Query parquet files using SQL directly.

Usage:
  python duckdb_mcp_server.py

Configuration:
  Set PLFS_DATA_PATH environment variable to point to your parquet file.
  Default: data/processed/plfs_2024_persons.parquet
"""

import json
import sys
import duckdb
import os
from pathlib import Path

# Data paths
DEFAULT_PATH = Path("data/processed/plfs_2024_persons.parquet")
PARQUET_FILE = Path(os.getenv("PLFS_DATA_PATH", DEFAULT_PATH))

def setup_database():
    """Initialize DuckDB connection with security constraints."""
    try:
        # Use in-memory database
        conn = duckdb.connect(database=":memory:")

        # Check if file exists
        if not PARQUET_FILE.exists():
            print(f"Warning: Parquet file not found at {PARQUET_FILE}", file=sys.stderr)
            # We can still run, but queries will fail if table not created
            return conn

        # Load parquet file into memory table 'plfs'
        print(f"Loading data from {PARQUET_FILE}...", file=sys.stderr)
        conn.execute(f"CREATE TABLE plfs AS SELECT * FROM '{PARQUET_FILE}'")

        # Secure the connection: Disable external file access
        conn.execute("SET enable_external_access=false")
        print("Database secured: External file access disabled.", file=sys.stderr)

        return conn
    except Exception as e:
        print(f"Error initializing database: {e}", file=sys.stderr)
        sys.exit(1)

# Initialize DuckDB connection
conn = setup_database()

def handle_request(request):
    """Handle MCP JSON-RPC requests."""
    method = request.get("method", "")
    params = request.get("params", {})
    req_id = request.get("id")
    
    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {}
                },
                "serverInfo": {
                    "name": "duckdb-plfs",
                    "version": "1.1.0"
                }
            }
        }
    
    elif method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "tools": [
                    {
                        "name": "query_plfs",
                        "description": "Execute SQL query on PLFS data. Table name: plfs",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "sql": {
                                    "type": "string",
                                    "description": "SQL query. Use 'plfs' as table name."
                                }
                            },
                            "required": ["sql"]
                        }
                    },
                    {
                        "name": "describe_plfs",
                        "description": "Get column names and types from PLFS data",
                        "inputSchema": {
                            "type": "object",
                            "properties": {}
                        }
                    },
                    {
                        "name": "sample_plfs",
                        "description": "Get sample rows from PLFS data",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "limit": {
                                    "type": "integer",
                                    "description": "Number of rows (default: 5)"
                                }
                            }
                        }
                    }
                ]
            }
        }
    
    elif method == "tools/call":
        tool_name = params.get("name", "")
        args = params.get("arguments", {})
        
        try:
            if tool_name == "query_plfs":
                sql = args.get("sql", "")
                # Security: sql is executed as-is, but external access is disabled
                # so users cannot read/write files.
                # Table 'plfs' is available.

                # Check for basic injection attempts that might bypass logic (though strict mode handles most)
                # But we rely on DuckDB security configuration.

                result = conn.execute(sql).fetchdf()
                return {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "content": [
                            {
                                "type": "text",
                                "text": result.to_string()
                            }
                        ]
                    }
                }
            
            elif tool_name == "describe_plfs":
                result = conn.execute("DESCRIBE plfs").fetchdf()
                return {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "content": [
                            {
                                "type": "text",
                                "text": result.to_string()
                            }
                        ]
                    }
                }
            
            elif tool_name == "sample_plfs":
                try:
                    limit = int(args.get("limit", 5))
                except (ValueError, TypeError):
                    return {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "error": {"code": -32602, "message": "Limit must be an integer"}
                    }

                # Use parameterized query for limit to be extra safe, though int cast handles it
                result = conn.execute("SELECT * FROM plfs LIMIT ?", [limit]).fetchdf()
                return {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "content": [
                            {
                                "type": "text",
                                "text": result.to_string()
                            }
                        ]
                    }
                }
            
            else:
                return {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"}
                }
        
        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32000, "message": str(e)}
            }
    
    elif method == "notifications/initialized":
        return None  # No response needed for notifications
    
    else:
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {"code": -32601, "message": f"Method not found: {method}"}
        }

def main():
    """Main loop - read JSON-RPC from stdin, write to stdout."""
    # Ensure stdin is in non-blocking mode or handled correctly
    # sys.stdin is an iterator which blocks until EOF or line
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        
        try:
            request = json.loads(line)
            response = handle_request(request)
            if response:
                print(json.dumps(response), flush=True)
        except json.JSONDecodeError as e:
            error_response = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32700, "message": f"Parse error: {e}"}
            }
            print(json.dumps(error_response), flush=True)

if __name__ == "__main__":
    main()
