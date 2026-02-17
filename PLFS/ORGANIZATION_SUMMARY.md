# PLFS Folder Organization Summary

## Date: January 31, 2026

## What Was Done

The PLFS (Periodic Labour Force Survey) folder has been organized year-wise with all supporting files placed in their respective year folders.

## Folder Structure

### Root Level
- `discover_datasets.py` - Python script for discovering datasets
- `discover_plfs_datasets.R` - R script for discovering datasets
- `download_all_plfs.R` - R script for downloading PLFS data
- `PLFS.png` - PLFS logo/image

### Year Folders (2017-18 through 2024)
Each year folder now contains:
- Data files (CSV, TXT)
- Documentation (README, Data Layout, Schedules)
- Year-specific code/scripts

#### 2017-18
#### 2017-18
(Empty - Data files missing)

#### 2018-19
#### 2018-19
- README_July18_June19.pdf

#### 2019-20
#### 2019-20
(Empty - Data files missing)

#### 2020-21
- 2_2Schedule10.4_FIRSTVISIT_28122020.pdf
- 2_3Schedule10.4_REVISIT_28122020.pdf
- plfsREADMEjuly20-jun21-1 (4).pdf
- Schedule10.4_FIRSTVISIT_2020-21.pdf

#### 2021-22
- 4Data_LayoutPLFS_2021-22.xlsx
- README_Jan_Dec21.pdf

#### 2022-23
- 2_2 Schedule104_FIRSTVISIT_2022_23.pdf
- 2_3 Schedule10.4_REVISIT_2022_23.pdf
- Data_LayoutPLFS_2022-23 (1).xlsx
- Data_LayoutPLFS_Calendar_2022.xlsx
- Note_on_changes_PLFS_2022_23.pdf
- README_Calendar_2022.pdf
- Technical clarification regarding high multiplier value in PLFS 2022-23.pdf

#### 2023-24
- 1 README_Calendar_2023.pdf
- 2_3 Note on Updated Instruction for PLFS 2023-24.pdf
- 3 Data_LayoutPLFS_Calendar_2023.xlsx
- Data_LayoutPLFS_2023-24.xlsx
- parse_plfs_2023-24.R
- csv/ (folder with CSV data files)
- raw/ (folder with raw TXT data files)

#### 2024
- Data_LayoutPLFS_Calendar_2024 (4) (1).xlsx
- README_Calendar_2024 (3) (1).docx
- txt2csv_calendar2024 (1) (1)/ (folder with converter tool)
- txt2csv_calendar2024 (1) (1).rar

### common_docs/ (Generic Documentation)
Contains only documentation that applies across all years:
- EstimationProcedure_PLFS.pdf
- Instruction_Manual_PLFS_Vol-II.pdf
- README.pdf

### Panel_data/ (Cross-Year Panel Files)
Contains files that span multiple years:
- District_codes_PLFS_Panel_3_202122_202223.xlsx
- District_codes_PLFS_Panel_4_202324_2024.xlsx
- District_codes_PLFS_Panel_1_201718_201819.xlsx
- District_codes_PLFS_Panel_2_201920_202021.xlsx
- District_codes_PLFS_Panel_3_202122_202223.xlsx
- District_codes_PLFS_Panel_4_202324_2024.xlsx
- PLFS Panel 4 Sch 10.4 Item Code Description & Codes (1) (1).xlsx

### scripts/ (Helper Scripts)
Contains organization and cleanup scripts:
- cleanup_docs.bat
- move_data_2023-24.bat
- organize_data_helper.bat
- organize_files.py
- organize_plfs.bat

## Cleanup Actions Performed

1. **Removed duplicate files** - Many files had duplicates with names like "file (1).pdf", "file (2).pdf", etc. These were removed, keeping only one copy.

2. **Moved helper scripts** - All .bat, .py organization scripts moved to `scripts/` folder

3. **Consolidated common_docs** - Removed year-specific files from common_docs, keeping only generic documentation

4. **Renamed files** - Removed numeric prefixes and cleaned up filenames where appropriate

## Notes

- No data files were deleted - only duplicate copies were removed
- Each year folder is now self-contained with its data and documentation
- Panel data files remain in Panel_data/ as they span multiple years
- The 2023-24 folder has the most complete structure with raw data, CSV conversions, and parsing scripts
