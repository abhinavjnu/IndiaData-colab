@echo off
echo ====================================
echo Testing MCP Servers for PLFS Analysis
echo ====================================
echo.

echo [1/3] Testing RMCP (R Statistics)...
set R_HOME=C:\Program Files\R\R-4.5.2
"C:\Users\91735\AppData\Local\Python\pythoncore-3.14-64\Scripts\rmcp.exe" --version
if %errorlevel% equ 0 (
    echo     RMCP: OK
) else (
    echo     RMCP: FAILED
)
echo.

echo [2/3] Testing DuckDB (SQL Queries)...
python -c "import duckdb; print(f'    DuckDB {duckdb.__version__}: OK')"
echo.

echo [3/3] Testing Parquet Data Access...
python -c "import duckdb; c=duckdb.connect(); r=c.execute(\"SELECT COUNT(*) FROM 'D:/Opencode/Data Analysis/IndiaData/data/processed/plfs_2024_persons.parquet'\").fetchone(); print(f'    Parquet ({r[0]:,} rows): OK')"
echo.

echo ====================================
echo All tests complete!
echo ====================================
pause
