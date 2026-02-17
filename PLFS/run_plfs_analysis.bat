@echo off
REM ============================================================================
REM run_plfs_analysis.bat - One-Click PLFS Analysis Runner
REM ============================================================================
REM This batch file runs the complete PLFS analysis pipeline.
REM Simply double-click this file or run it from command prompt.
REM
REM Requirements:
REM   - R installed and in PATH
REM   - All required R packages installed
REM   - Raw PLFS data in PLFS/YYYY-YY/ folders
REM ============================================================================

echo.
echo ========================================
echo PLFS Automated Analysis
echo ========================================
echo.
echo This will run the complete analysis pipeline:
echo   1. Parse raw data files
echo   2. Create survey designs
echo   3. Calculate labour force indicators
echo   4. Generate tables and visualizations
echo.
echo Press Ctrl+C to cancel, or
echo.
pause

echo.
echo Starting analysis...
echo.

REM Change to the project directory
cd /d "D:\Opencode\Data Analysis\IndiaData"

REM Run the R script
Rscript -e "source('PLFS/automated_plfs_analysis.R')"

echo.
echo ========================================
echo Analysis Complete!
echo ========================================
echo.
echo Check the outputs/ folder for results.
echo.
pause
