# MCP Server Setup for PLFS Data Analysis

## Overview

This guide helps you connect MCP servers for Indian survey data analysis.
All paths are cross-platform and work on **Windows, Linux, and macOS**.

## Available MCP Servers

| Server | Purpose | Status |
|--------|---------|--------|
| **RMCP** | R statistical analysis (52 tools) | Install separately |
| **DuckDB** | SQL queries on parquet files | ✅ Included in repo |
| **Filesystem** | File read/write operations | ✅ Available via npx |

---

## Prerequisites

| Tool | Installation |
|------|-------------|
| **Python 3.8+** | [python.org](https://python.org) or your OS package manager |
| **R 4.0+** | [r-project.org](https://www.r-project.org/) |
| **Node.js 18+** | [nodejs.org](https://nodejs.org) |
| **DuckDB (Python)** | `pip install duckdb` |
| **RMCP** | `pip install rmcp` |

---

## Quick Test

### Test DuckDB

```bash
# Any OS
python -c "import duckdb; print('DuckDB OK:', duckdb.__version__)"
```

### Test RMCP

```bash
# Any OS (rmcp must be on PATH)
rmcp list-capabilities
```

### Test the DuckDB MCP Server

```bash
# From the project root
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | python duckdb_mcp_server.py
```

---

## Configuration Files

### For Claude Desktop

**macOS:**
```bash
cp mcp_config_claude_desktop.json ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

**Linux:**
```bash
mkdir -p ~/.config/claude
cp mcp_config_claude_desktop.json ~/.config/claude/claude_desktop_config.json
```

**Windows:**
```powershell
mkdir "$env:APPDATA\Claude" -Force
copy mcp_config_claude_desktop.json "$env:APPDATA\Claude\claude_desktop_config.json"
```

### For Cursor

```bash
# From project root
cp mcp_config.json .cursor/mcp.json
```

### For VS Code + Continue

Add to Continue config (`~/.continue/config.json`):
```json
{
  "mcpServers": [
    {
      "name": "rmcp",
      "command": "rmcp",
      "args": ["start"]
    }
  ]
}
```

---

## Server Details

### 1. RMCP (R Statistics)

**52 statistical analysis tools** including:
- Linear regression with robust standard errors
- Panel data analysis (fixed/random effects)
- Instrumental variables regression
- Descriptive statistics
- Correlation analysis
- Group-by aggregations

**Example prompts:**
- "Run a linear regression of unemployment on education level"
- "Calculate summary statistics for Age by Sex"
- "Compute correlation between LFPR and education"

### 2. DuckDB PLFS Server

**Custom SQL server** for querying your parquet data.

The server auto-detects parquet files in `data/processed/`. You can override the data directory with the `INDADATA_DATA_DIR` environment variable.

**Tools:**
| Tool | Description |
|------|-------------|
| `query_plfs` | Run SQL queries (use `plfs` as table name; SELECT only) |
| `describe_plfs` | Get column names and types |
| `sample_plfs` | Get sample rows |

**Example queries:**
```sql
-- Unemployment rate by education
SELECT
  General_Educaion_Level,
  COUNT(*) as n,
  SUM(CASE WHEN Current_Weekly_Status_CWS IN (61,62) THEN 1 ELSE 0 END) as unemployed,
  ROUND(100.0 * SUM(CASE WHEN Current_Weekly_Status_CWS IN (61,62) THEN 1 ELSE 0 END) / COUNT(*), 2) as UR
FROM plfs
WHERE Age >= 15 AND Current_Weekly_Status_CWS IN (11,12,21,31,41,42,51,61,62)
GROUP BY General_Educaion_Level
ORDER BY General_Educaion_Level
```

### 3. Filesystem Server

**Read/write files** in the project directory.

**Capabilities:**
- Read CSV, parquet, R scripts
- Write output files
- List directory contents

---

## Full MCP Config

The config files use portable commands (`rmcp`, `python`, `npx`) that should be on your PATH:

```json
{
  "mcpServers": {
    "rmcp-statistics": {
      "command": "rmcp",
      "args": ["start"],
      "env": {}
    },
    "duckdb-plfs": {
      "command": "python",
      "args": ["duckdb_mcp_server.py"]
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "."]
    }
  }
}
```

> **Note:** If `rmcp` or `python` are not on your PATH, replace the command with the full path to the executable for your OS.

---

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `INDADATA_DATA_DIR` | Override data directory for DuckDB server | `data/processed/` relative to script |
| `R_HOME` | R installation path (needed by RMCP on some systems) | Auto-detected |

---

## Troubleshooting

### RMCP not found

```bash
# Install
pip install rmcp

# Or add to PATH (check where pip installs scripts)
python -m site --user-base
# Add the Scripts/ (Windows) or bin/ (Linux/Mac) subdirectory to PATH
```

### DuckDB import error

```bash
pip install duckdb --upgrade
```

### R not found by RMCP

Set `R_HOME` in the MCP config env:
```json
"env": {
  "R_HOME": "/usr/lib/R"
}
```

Common `R_HOME` values:
- **Linux:** `/usr/lib/R` or `/usr/local/lib/R`
- **macOS:** `/Library/Frameworks/R.framework/Resources`
- **Windows:** `C:\\Program Files\\R\\R-4.x.x`

### No parquet file found

Run the analysis pipeline first to generate processed data:
```bash
Rscript run_analysis.R
```

Or set `INDADATA_DATA_DIR` to point at your parquet files:
```bash
export INDADATA_DATA_DIR=/path/to/your/processed/data
```

### Filesystem permission denied

Ensure the filesystem server has access to the project directory.

---

## What You Can Do Now

With these MCP servers, you can:

1. **Query data with SQL** via DuckDB
   - "What's the unemployment rate by state?"
   - "Show me education distribution by sex"

2. **Run statistical analysis** via RMCP
   - "Regress unemployment on education and age"
   - "Calculate panel data model for states"

3. **Read/write files** via Filesystem
   - "Read the latest CSV output"
   - "Save this analysis to a new file"

---

## Next Steps

1. **Install prerequisites** (Python, R, Node.js, pip packages)
2. **Copy** the appropriate MCP config to your client's config directory
3. **Restart** your MCP client (Claude Desktop, Cursor, etc.)
4. **Test** by asking: "List available MCP tools"
