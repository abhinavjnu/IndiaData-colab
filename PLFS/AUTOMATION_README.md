# PLFS Automated Analysis

This directory contains fully automated scripts for analyzing Periodic Labour Force Survey (PLFS) data.

## Quick Start

### Option 1: One-Click (Windows)
Double-click `run_plfs_analysis.bat`

### Option 2: Command Line (Any OS)
```bash
# Windows
PLFS\run_plfs_analysis.bat

# Linux/Mac
bash PLFS/run_plfs_analysis.sh

# Or directly in R
Rscript -e "source('PLFS/automated_plfs_analysis.R')"
```

### Option 3: From R/RStudio
```r
source("PLFS/automated_plfs_analysis.R")
```

## What Gets Automated

The script performs a complete end-to-end analysis:

### 1. Data Discovery & Parsing
- Automatically finds all PLFS year folders (e.g., `2023-24/`, `2022-23/`)
- Parses raw `.TXT` files using `Data_Layout.xlsx` specifications
- Handles both person-level and household-level data

### 2. Survey Design Creation
- Creates proper stratified survey designs
- Applies correct PLFS weight formulas:
  - Single sub-sample: `MULT / (NO_QTR * 100)`
  - Combined sub-samples: `MULT / (NO_QTR * 200)`
- Handles strata, PSUs (FSUs), and finite population corrections

### 3. Indicator Calculation
Calculates standard labour force indicators for age 15+:

| Indicator | Description |
|-----------|-------------|
| **LFPR** | Labour Force Participation Rate |
| **WPR** | Worker Population Ratio (Employment Rate) |
| **UR** | Unemployment Rate |

With disaggregation by:
- **Sex** (Male/Female)
- **Sector** (Rural/Urban)
- **State** (all Indian states/UTs)
- **Age Groups** (15-24, 25-34, 35-44, 45-54, 55-64, 65+)
- **Sex × Sector** (intersectional analysis)
- **Special groups**: Youth (15-29), Prime age (25-54)

### 4. Output Generation

#### Tables (CSV + Word .docx)
- `indicators_overall.csv` - National aggregates
- `indicators_by_sex.csv` - Male/Female comparison
- `indicators_by_sector.csv` - Rural/Urban comparison
- `indicators_by_sex_sector.csv` - Intersectional
- `indicators_by_state.csv` - State-wise estimates
- `indicators_by_age.csv` - Age group breakdown
- `summary_key_groups.csv` - Key demographic groups

#### Visualizations (PDF + PNG)
- `01_overall_indicators` - National LFPR, WPR, UR
- `02_by_sex` - Sex-disaggregated comparison
- `03_by_sector` - Rural vs Urban
- `04_by_sex_sector` - Faceted by indicator
- `05_ur_by_state` - State-wise unemployment (ranked)
- `06_by_age_group` - Age profiles
- `trend_all_years` - Cross-year comparison (if multiple years)

#### Processed Data
- `persons.parquet` - Parsed person-level data
- `households.parquet` - Parsed household-level data
- `survey_design_info.csv` - Design metadata

## Directory Structure

```
outputs/
├── plfs_2023-24/
│   ├── tables/
│   │   ├── indicators_overall.csv
│   │   ├── indicators_by_sex.csv
│   │   ├── indicators_by_sector.csv
│   │   ├── indicators_by_state.csv
│   │   ├── indicators_by_age.csv
│   │   ├── indicators_by_sex_sector.csv
│   │   ├── summary_key_groups.csv
│   │   └── *.docx (formatted tables)
│   ├── figures/
│   │   ├── 01_overall_indicators.pdf
│   │   ├── 02_by_sex.pdf
│   │   ├── 03_by_sector.pdf
│   │   ├── 04_by_sex_sector.pdf
│   │   ├── 05_ur_by_state.pdf
│   │   ├── 06_by_age_group.pdf
│   │   └── *.png
│   └── data/
│       ├── persons.parquet
│       ├── households.parquet
│       └── survey_design_info.csv
└── plfs_summary/ (if multiple years)
    ├── overall_indicators_all_years.csv
    └── trend_all_years.pdf
```

## Configuration

Edit these variables at the top of `automated_plfs_analysis.R`:

```r
# Years to process (auto-detected if data exists)
YEARS_TO_PROCESS <- c("2023-24", "2022-23", "2021-22")

# Analysis settings
AGE_FILTER <- c(15, 99)  # Standard labour force age
APPROACH <- "ps"         # "ps" = Principal Status, "cws" = Current Weekly

# Output formats
OUTPUT_FORMATS <- c("csv", "docx")  # Table formats
FIGURE_FORMATS <- c("pdf", "png")   # Figure formats
```

## Requirements

### Data Files
Place your PLFS data in this structure:
```
PLFS/
├── 2023-24/
│   ├── raw/
│   │   ├── CPERV1.TXT      # Person-level data
│   │   └── CHHV1.TXT       # Household-level data
│   └── Data_LayoutPLFS_2023-24.xlsx  # Layout file
├── 2022-23/
│   └── ...
```

### R Packages
The script requires these packages (install with `install.packages()`):
- `data.table` - Fast data manipulation
- `srvyr` - Survey analysis with dplyr syntax
- `dplyr` - Data manipulation
- `ggplot2` - Visualization
- `readxl` - Read Excel layout files
- `arrow` - Parquet file format
- `progress` - Progress bars
- `modelsummary` - Regression tables
- `gt` - Publication tables
- `flextable` - Word document tables
- `scales` - Scale formatting

### System Requirements
- R version 4.0 or higher
- Sufficient RAM (8GB+ recommended for large datasets)
- Disk space for outputs (varies by dataset size)

## Activity Status Codes

The analysis uses standard PLFS activity status codes:

| Code Range | Category |
|------------|----------|
| 11-51 | Employed (Workers) |
| 61-62 | Unemployed |
| 71-98 | Not in Labour Force |

## Weighting Methodology

The script implements official PLFS weighting:

1. **Sub-sample estimates**: `Final_Weight = MULT / (NO_QTR * 100)`
2. **Combined estimates**: `Final_Weight = MULT / (NO_QTR * 200)`
3. **Calendar year**: `Final_Weight = MULT / 100`

Where:
- `MULT` = Sub-sample multiplier from data
- `NO_QTR` = Number of quarters (4 for urban, 1 for rural)

## Troubleshooting

### "No valid PLFS datasets found"
- Ensure data files are in `PLFS/YYYY-YY/` folders
- Check that both `.TXT` data files and `.xlsx` layout files exist

### "Could not find variable"
- The script auto-detects variables using multiple naming patterns
- If detection fails, check that your data uses standard PLFS variable names

### Memory errors
- Process one year at a time by modifying `YEARS_TO_PROCESS`
- Use `gc()` in R to force garbage collection

### Package not found
```r
install.packages(c("data.table", "srvyr", "dplyr", "ggplot2", 
                   "readxl", "arrow", "progress", "modelsummary",
                   "gt", "flextable", "scales"))
```

## Customization

### Add New Indicators
Edit the `calculate_all_indicators()` function in the script to add:
- New age groups
- Additional disaggregations
- Custom indicators

### Change Visualizations
Modify the `create_visualizations()` function to:
- Change chart types
- Adjust colors/themes
- Add new plot types

### Export Formats
Modify `OUTPUT_FORMATS` and `FIGURE_FORMATS` to include/exclude:
- LaTeX (.tex) tables
- HTML tables
- SVG figures
- Other formats

## Citation

When using this analysis in publications:

```
Data Source: Periodic Labour Force Survey (PLFS), National Statistical Office (NSO), 
Ministry of Statistics and Programme Implementation, Government of India.

Analysis conducted using automated PLFS analysis pipeline 
(github.com/abhinavjnu/IndiaData)
```

## Support

For issues or questions:
1. Check the PLFS_ANALYST_GUIDE.md for detailed methodology
2. Review the R module documentation in `R/` directory
3. Check the survey design summary in output files

## License

This automation script is part of the IndiaData project for research purposes.
