@echo off
REM ============================================================================
REM PLFS File Organizer - Run this script to organize files into year folders
REM ============================================================================
cd /d "D:\Opencode\Data Analysis\IndiaData\PLFS"

echo Creating year-wise folders...
mkdir "2017-18" 2>nul
mkdir "2018-19" 2>nul
mkdir "2019-20" 2>nul
mkdir "2020-21" 2>nul
mkdir "2021-22" 2>nul
mkdir "2022-23" 2>nul
mkdir "2023-24" 2>nul
mkdir "2024" 2>nul
mkdir "common_docs" 2>nul
mkdir "Panel_data" 2>nul

echo Moving 2023-24 files...
move "*2023-24*" "2023-24\" 2>nul
move "*2023_24*" "2023-24\" 2>nul
move "*Calendar_2023*" "2023-24\" 2>nul

echo Moving 2024 files...
move "*Calendar_2024*" "2024\" 2>nul
move "*calendar2024*" "2024\" 2>nul

echo Moving 2022-23 files...
move "*2022-23*" "2022-23\" 2>nul
move "*2022_23*" "2022-23\" 2>nul
move "*Calendar_2022*" "2022-23\" 2>nul

echo Moving 2021-22 files...
move "*2021-22*" "2021-22\" 2>nul
move "*2021_22*" "2021-22\" 2>nul
move "*Jan_Dec21*" "2021-22\" 2>nul
move "*2021_without*" "2021-22\" 2>nul

echo Moving 2020-21 files...
move "*2020-21*" "2020-21\" 2>nul
move "*july20*jun21*" "2020-21\" 2>nul
move "*28122020*" "2020-21\" 2>nul

echo Moving 2019-20 files...
move "*2019-20*" "2019-20\" 2>nul
move "*201920*" "2019-20\" 2>nul

echo Moving 2018-19 files...
move "*2018-19*" "2018-19\" 2>nul
move "*201819*" "2018-19\" 2>nul
move "*July18*June19*" "2018-19\" 2>nul

echo Moving 2017-18 files...
move "*2017-18*" "2017-18\" 2>nul
move "*201718*" "2017-18\" 2>nul

echo Moving Panel data files...
move "*Panel_1*" "Panel_data\" 2>nul
move "*Panel_2*" "Panel_data\" 2>nul
move "*Panel_3*" "Panel_data\" 2>nul
move "*Panel_4*" "Panel_data\" 2>nul
move "*Panel 4*" "Panel_data\" 2>nul

echo Moving common documentation...
move "Instruction Manual*" "common_docs\" 2>nul
move "Instructions to Field*" "common_docs\" 2>nul
move "Instructions_to_Field*" "common_docs\" 2>nul
move "InstructionsFieldStaff*" "common_docs\" 2>nul
move "Estimation Procedure*" "common_docs\" 2>nul
move "EstimationProcedure*" "common_docs\" 2>nul
move "NMDS*" "common_docs\" 2>nul
move "Additional_instructions*" "common_docs\" 2>nul

echo.
echo ============================================
echo Organization complete!
echo ============================================
echo.
echo Folders created:
dir /ad /b
echo.
pause
