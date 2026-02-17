#!/usr/bin/env python
"""
DuckDB MCP Server for PLFS Data Analysis
=========================================
Query parquet files using SQL directly.

Usage:
  python duckdb_mcp_server.py

This server provides SQL access to your PLFS parquet data.
"""

import json
import sys
import duckdb
from pathlib import Path

# Data paths
DATA_DIR = Path(r"D:\Opencode\Data Analysis\IndiaData\data\processed")
PARQUET_FILE = DATA_DIR / "plfs_2024_persons.parquet"

# Initialize DuckDB connection
conn = duckdb.connect()

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
                    "version": "1.0.0"
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
                        "description": "Execute SQL query on PLFS 2024 parquet data. Table alias: plfs",
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
                # Replace 'plfs' with actual file path
                sql = sql.replace("plfs", f"'{PARQUET_FILE}'")
                sql = sql.replace("FROM persons", f"FROM '{PARQUET_FILE}'")
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
                result = conn.execute(f"DESCRIBE SELECT * FROM '{PARQUET_FILE}'").fetchdf()
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
                limit = args.get("limit", 5)
                result = conn.execute(f"SELECT * FROM '{PARQUET_FILE}' LIMIT {limit}").fetchdf()
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
