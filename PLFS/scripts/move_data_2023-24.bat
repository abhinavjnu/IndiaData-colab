@echo off
REM ============================================================================
REM Move PLFS 2023-24 data files to correct folder
REM ============================================================================
cd /d "D:\Opencode\Data Analysis\IndiaData\PLFS"

echo.
echo Creating raw subfolder in 2023-24...
mkdir "2023-24\raw" 2>nul

echo Moving TXT data files to 2023-24\raw...
move "data (2) (1)\CPERV1.TXT" "2023-24\raw\" 2>nul
move "data (2) (1)\CHHV1.TXT" "2023-24\raw\" 2>nul

echo.
echo Removing empty extracted folders...
rmdir "data (2) (1)" 2>nul

echo.
echo Keeping CSV version as backup (optional - delete if not needed)
mkdir "2023-24\csv" 2>nul
move "Data in CSV (2)\cperv1.csv" "2023-24\csv\" 2>nul
move "Data in CSV (2)\chhv1.csv" "2023-24\csv\" 2>nul
rmdir "Data in CSV (2)" 2>nul

echo.
echo Deleting zip files...
del "Data in CSV (2).zip" 2>nul
del "data (2) (1).rar" 2>nul

echo.
echo ============================================
echo Done! PLFS 2023-24 data organized:
echo ============================================
echo.
dir "2023-24" /s /b
echo.
pause
