@echo off
REM ============================================================================
REM Move remaining docs to common_docs and clean up duplicates
REM ============================================================================
cd /d "D:\Opencode\Data Analysis\IndiaData\PLFS"

echo Moving remaining common documentation to common_docs folder...

REM Move instruction manuals (vol I and II)
move "2_1 Instruction manual*" "common_docs\" 2>nul
move "2_1 Instructions to Field*" "common_docs\" 2>nul
move "2_1Instructions_to_Field*" "common_docs\" 2>nul
move "2_2 Instruction Manual*" "common_docs\" 2>nul
move "Instructions-to-Field*" "common_docs\" 2>nul

REM Move estimation procedures
move "3_1 Estimation*" "common_docs\" 2>nul
move "3_1Estimation*" "common_docs\" 2>nul

REM Move generic README files
move "1 README.docx" "common_docs\" 2>nul
move "1 README.pdf" "common_docs\" 2>nul
move "1_README_Final.pdf" "common_docs\" 2>nul
move "README.doc" "common_docs\" 2>nul
move "README.pdf" "common_docs\" 2>nul

REM Move generic schedules
move "Schedule10.4_FIRSTVISIT (4).pdf" "common_docs\" 2>nul
move "Schedule10.4_REVISIT (4).pdf" "common_docs\" 2>nul

REM Move generic data layouts (without year in name)
move "Data_LayoutPLFS (1).xlsx" "common_docs\" 2>nul
move "Data_LayoutPLFS (5).xlsx" "common_docs\" 2>nul
move "Data_LayoutPLFS (6).xlsx" "common_docs\" 2>nul

echo.
echo Moving Panel_1 district codes to 2017-18 and 2018-19...
copy "2018-19\District_codes_PLFS_Panel_1*" "2017-18\" 2>nul

echo.
echo Files remaining in root:
dir /b *.zip *.rar 2>nul

echo.
echo ============================================
echo Cleanup complete! 
echo.
echo Compressed data files remaining in root:
echo - Data in CSV (2).zip
echo - Data in SPSS.zip  
echo - data (2) (1).rar
echo.
echo Please extract these manually and move to appropriate year folders.
echo ============================================
pause
