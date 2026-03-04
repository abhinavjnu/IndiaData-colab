#!/usr/bin/env python
"""
DuckDB MCP Server for PLFS Data Analysis
=========================================
Query parquet files using SQL directly.

Usage:
  python duckdb_mcp_server.py

This server provides SQL access to your PLFS parquet data.
Works on Windows, Linux, and macOS.

Configuration:
  Set INDADATA_DATA_DIR environment variable to override the default data path.
  Default: data/processed/ relative to this script's location.
"""

import json
import os
import re
import sys
import duckdb
from pathlib import Path

# ============================================================================
# Cross-platform path resolution
# ============================================================================
# Priority: INDADATA_DATA_DIR env var > relative to script location
_SCRIPT_DIR = Path(__file__).resolve().parent

if os.environ.get("INDADATA_DATA_DIR"):
    DATA_DIR = Path(os.environ["INDADATA_DATA_DIR"])
else:
    DATA_DIR = _SCRIPT_DIR / "data" / "processed"

# Find parquet file(s)
PARQUET_FILE = None
if DATA_DIR.exists():
    parquet_files = sorted(DATA_DIR.glob("plfs_*_persons.parquet"))
    if parquet_files:
        PARQUET_FILE = parquet_files[-1]  # Use the latest one

# Initialize DuckDB connection
conn = duckdb.connect()

# ============================================================================
# SQL safety: reject mutating statements
# ============================================================================
_UNSAFE_PATTERNS = re.compile(
    r"\b(DROP|DELETE|INSERT|UPDATE|ALTER|CREATE|TRUNCATE|REPLACE|MERGE)\b",
    re.IGNORECASE,
)


def _validate_sql(sql: str) -> None:
    """Reject SQL statements that could mutate data."""
    if _UNSAFE_PATTERNS.search(sql):
        raise ValueError(
            "Only SELECT queries are allowed. "
            "Data-modifying statements (DROP, DELETE, INSERT, UPDATE, ALTER, CREATE) are rejected."
        )


def _get_parquet_path() -> str:
    """Return the parquet path as a string, or raise a clear error."""
    if PARQUET_FILE is None or not PARQUET_FILE.exists():
        raise FileNotFoundError(
            f"No PLFS parquet file found in {DATA_DIR}. "
            "Run the analysis pipeline first, or set INDADATA_DATA_DIR to point at your processed data folder."
        )
    return str(PARQUET_FILE)


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
                        "description": "Execute SQL query on PLFS parquet data. Table alias: plfs. SELECT only.",
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
            pq_path = _get_parquet_path()

            if tool_name == "query_plfs":
                sql = args.get("sql", "")
                _validate_sql(sql)
                # Replace 'plfs' with actual file path
                sql = sql.replace("plfs", f"'{pq_path}'")
                sql = sql.replace("FROM persons", f"FROM '{pq_path}'")
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
                result = conn.execute(f"DESCRIBE SELECT * FROM '{pq_path}'").fetchdf()
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
                result = conn.execute(f"SELECT * FROM '{pq_path}' LIMIT {int(limit)}").fetchdf()
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
