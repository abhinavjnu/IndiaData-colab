# MCP Server Setup for PLFS Data Analysis

## Overview

This guide helps you connect MCP servers for Indian survey data analysis.

## Installed MCP Servers

| Server | Purpose | Status |
|--------|---------|--------|
| **RMCP** | R statistical analysis (52 tools) | ✅ Installed |
| **DuckDB** | SQL queries on parquet files | ✅ Installed |
| **Filesystem** | File read/write operations | ✅ Available via npx |

---

## Quick Test

### Test RMCP
```powershell
& "C:\Users\91735\AppData\Local\Python\pythoncore-3.14-64\Scripts\rmcp.exe" list-capabilities
```

### Test DuckDB
```powershell
python -c "import duckdb; print(duckdb.connect().execute(\"SELECT COUNT(*) FROM 'D:/Opencode/Data Analysis/IndiaData/data/processed/plfs_2024_persons.parquet'\").fetchone())"
```

---

## Configuration Files

### For Claude Desktop

Copy `mcp_config.json` to:
```
%APPDATA%\Claude\claude_desktop_config.json
```

Or manually:
```powershell
mkdir "$env:APPDATA\Claude" -Force
copy "D:\Opencode\Data Analysis\IndiaData\mcp_config.json" "$env:APPDATA\Claude\claude_desktop_config.json"
```

### For Cursor

Add to `.cursor/mcp.json` in your project or globally:
```powershell
copy "D:\Opencode\Data Analysis\IndiaData\mcp_config.json" "$env:USERPROFILE\.cursor\mcp.json"
```

### For VS Code + Continue

Add to Continue config (`~/.continue/config.json`):
```json
{
  "mcpServers": [
    {
      "name": "rmcp",
      "command": "C:\\Users\\91735\\AppData\\Local\\Python\\pythoncore-3.14-64\\Scripts\\rmcp.exe",
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

**Tools:**
| Tool | Description |
|------|-------------|
| `query_plfs` | Run SQL queries (use `plfs` as table name) |
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

```json
{
  "mcpServers": {
    "rmcp-statistics": {
      "command": "C:\\Users\\91735\\AppData\\Local\\Python\\pythoncore-3.14-64\\Scripts\\rmcp.exe",
      "args": ["start"],
      "env": {
        "R_HOME": "C:\\Program Files\\R\\R-4.5.2"
      }
    },
    "duckdb-plfs": {
      "command": "python",
      "args": ["D:\\Opencode\\Data Analysis\\IndiaData\\duckdb_mcp_server.py"]
    },
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "D:\\Opencode\\Data Analysis\\IndiaData"
      ]
    }
  }
}
```

---

## Troubleshooting

### RMCP not found
```powershell
# Add to PATH
$env:PATH += ";C:\Users\91735\AppData\Local\Python\pythoncore-3.14-64\Scripts"

# Or use full path in config
"C:\\Users\\91735\\AppData\\Local\\Python\\pythoncore-3.14-64\\Scripts\\rmcp.exe"
```

### DuckDB import error
```powershell
python -m pip install duckdb --upgrade
```

### R not found by RMCP
Ensure R_HOME is set in the MCP config env:
```json
"env": {
  "R_HOME": "C:\\Program Files\\R\\R-4.5.2"
}
```

### Filesystem permission denied
Make sure the path in args is accessible:
```json
"args": ["-y", "@modelcontextprotocol/server-filesystem", "D:\\Opencode\\Data Analysis\\IndiaData"]
```

---

## Paths Reference

| Component | Path |
|-----------|------|
| Python | `C:\Users\91735\AppData\Local\Python\pythoncore-3.14-64\python.exe` |
| RMCP | `C:\Users\91735\AppData\Local\Python\pythoncore-3.14-64\Scripts\rmcp.exe` |
| R | `C:\Program Files\R\R-4.5.2\bin\Rscript.exe` |
| Node.js | `C:\Program Files\nodejs\node.exe` |
| Project | `D:\Opencode\Data Analysis\IndiaData` |
| Parquet Data | `D:\Opencode\Data Analysis\IndiaData\data\processed\plfs_2024_persons.parquet` |

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

1. **Claude Desktop**: Copy config to `%APPDATA%\Claude\claude_desktop_config.json`
2. **Restart** your MCP client (Claude Desktop, Cursor, etc.)
3. **Test** by asking: "List available MCP tools"
