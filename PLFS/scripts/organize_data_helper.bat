@echo off
REM ============================================================================
REM Organize PLFS data files into year folders based on available layouts
REM ============================================================================
cd /d "D:\Opencode\Data Analysis\IndiaData\PLFS"

echo.
echo ============================================
echo PLFS Data Organization Helper
echo ============================================
echo.
echo Current data files found:
echo.
echo 1. "data (2) (1)" folder:
echo    - CPERV1.TXT (139MB) - Person-level fixed-width
echo    - CHHV1.TXT (13MB) - Household-level fixed-width
echo.
echo 2. "Data in CSV (2)" folder:
echo    - cperv1.csv (124MB) - Person-level CSV
echo    - chhv1.csv (13MB) - Household-level CSV
echo.
echo These appear to be the SAME data in different formats.
echo Check the README files in each year folder to identify which year.
echo.
echo Data Layout files available:
dir /b /s *Data_Layout*.xlsx
echo.
echo ============================================
echo MANUAL STEPS NEEDED:
echo ============================================
echo.
echo 1. Open README or check file dates to identify which year
echo 2. Move TXT files to the correct year folder, e.g.:
echo    move "data (2) (1)\CPERV1.TXT" "2023-24\raw\"
echo    move "data (2) (1)\CHHV1.TXT" "2023-24\raw\"
echo.
echo 3. Create "raw" subfolders in year folders if needed:
echo    mkdir "2023-24\raw"
echo.
echo 4. Delete the CSV/ZIP duplicates if not needed
echo.
pause
