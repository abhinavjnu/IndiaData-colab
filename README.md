# IndiaData: Indian Government Survey Microdata Analysis System

A comprehensive R-based workflow for analyzing large-scale Indian government survey data from [microdata.gov.in](https://microdata.gov.in), including PLFS (Periodic Labour Force Survey), HCES (Household Consumer Expenditure Survey), NSS, and ASI.

## Features

- **API Integration**: Download data directly from microdata.gov.in
- **Fixed-Width Parser**: Read NSO's fixed-width TXT files using Data_Layout.xlsx
- **Survey Analysis**: Proper weighted estimates with confidence intervals using `srvyr`
- **Labour Indicators**: Pre-built functions for LFPR, WPR, Unemployment Rate
- **Publication Output**: Export tables to Word (.docx) and LaTeX (.tex)
- **Visualization**: Publication-quality ggplot2 themes
- **Efficient Storage**: Parquet format for fast loading and small file sizes

## Quick Start

### 1. Open the Project

Double-click `IndiaData.Rproj` to open in RStudio.

### 2. Install Packages (One Time)

```r
source("R/00_setup.R")
```

This installs all required packages (~5-10 minutes).

### 3. Basic Workflow

```r
# Load all functions
source("R/01_config.R")
source("R/02_api_helpers.R")
source("R/02_read_microdata.R")
source("R/03_survey_design.R")
source("R/04_plfs_indicators.R")
source("R/05_codebook_utils.R")
source("R/06_export_tables.R")
source("R/07_viz_themes.R")

# Read PLFS data (after downloading)
persons <- read_microdata(
  data_file = "data/raw/PLFS_Person.txt",
  layout_file = "data/raw/Data_Layout.xlsx"
)

# Decode categorical variables
persons <- decode_all(persons, 
                      state_col = "State", 
                      sex_col = "Sex", 
                      sector_col = "Sector")

# Create survey design (handles weights automatically)
design <- create_plfs_design(persons)

# Calculate indicators
lfpr_by_state <- calc_indicators_by_state(design)
print(lfpr_by_state)

# Export to Word/LaTeX
export_indicator_table(lfpr_by_state, "lfpr_by_state")

# Create visualization
p <- plot_horizontal_bars(lfpr_by_state, "lfpr", "state_name",
                          title = "LFPR by State")
save_figure(p, "lfpr_by_state")
```

## Project Structure

```
IndiaData/
├── config.yaml              # API key and settings
├── IndiaData.Rproj          # RStudio project file
│
├── R/                       # Functions (source these)
│   ├── 00_setup.R           # Package installation
│   ├── 01_config.R          # Configuration loader
│   ├── 02_api_helpers.R     # microdata.gov.in API
│   ├── 02_read_microdata.R  # Fixed-width file parser
  │   ├── 02_api_helpers.R     # microdata.gov.in API
│   ├── 03_survey_design.R   # Survey design setup
│   ├── 04_plfs_indicators.R # LFPR, WPR, UR functions
│   ├── 05_codebook_utils.R  # Code lookup utilities
│   ├── 06_export_tables.R   # Word/LaTeX export
│   └── 07_viz_themes.R      # ggplot2 themes
│ 
│
├── data/
│   ├── raw/                 # Downloaded data files
│   ├── processed/           # Parquet files (fast loading)
│   └── codebooks/           # Lookup tables (state, NIC, NCO)
│
├── analysis/
│   └── templates/           # Quarto report templates
│       ├── plfs_basic_analysis.qmd
│       └── state_comparison.qmd
│
└── outputs/
    ├── tables/              # Exported .docx and .tex
    └── figures/             # Exported .pdf and .png
```

## Downloading Data

### Option 1: Using the API (New!)

```r
source("R/01_config.R")
source("R/02_api_helpers.R")

# Configure API key in config.yaml first
# Then test connection
test_api_connection()

# Search for PLFS datasets
datasets <- search_datasets("PLFS")
print(datasets)

# Get files for a dataset
files <- get_dataset_files(dataset_id = "2728")
print(files)

# Download a specific file
download_datafile(dataset_id = "2728", file_id = "F1")

# Or download entire dataset with auto-extraction
download_dataset(dataset_id = "2728", extract = TRUE)

# Convenience function for PLFS
download_plfs(year = "2024")
```

### Option 2: Manual Download

1. Go to [microdata.gov.in](https://microdata.gov.in)
2. Search for your survey (e.g., "PLFS 2022-23")
3. Download the data files (.TXT) and layout files (.xlsx)
4. Place them in `data/raw/`

## Key Functions

### Data Loading

| Function | Description |
|----------|-------------|
| `read_microdata(data_file, layout_file)` | Read fixed-width TXT using layout |
| `save_as_parquet(data, filename)` | Save to Parquet (10x smaller) |
| `load_from_parquet(filename)` | Load Parquet (5x faster) |

### Survey Analysis

| Function | Description |
|----------|-------------|
| `create_plfs_design(data)` | Create survey design with proper weights |
| `calc_lfpr(design, by)` | Labour Force Participation Rate |
| `calc_wpr(design, by)` | Worker Population Ratio |
| `calc_unemployment_rate(design, by)` | Unemployment Rate |
| `calc_all_indicators(design, by)` | All three indicators at once |

### Code Decoding

| Function | Description |
|----------|-------------|
| `decode_state(data, col)` | State codes → names |
| `decode_activity(data, col)` | Activity status descriptions |
| `decode_nic(data, col)` | Industry (NIC) codes |
| `decode_sex(data, col)` | 1/2 → Male/Female |

### Output

| Function | Description |
|----------|-------------|
| `export_regression_table(models, filename)` | Regression to Word/LaTeX |
| `export_indicator_table(data, filename)` | Indicator table with CIs |
| `save_figure(plot, filename)` | Save to PDF/PNG |

## PLFS Weight Formula

The system automatically applies the correct weight formula:

```
Sub-sample: Final_Weight = MULT / (NO_QTR × 100)
Combined:   Final_Weight = MULT / (NO_QTR × 200)
```

## Report Templates

### Basic PLFS Analysis

```r
# Render the basic analysis report
quarto::quarto_render(
  "analysis/templates/plfs_basic_analysis.qmd",
  execute_params = list(
    data_file = "plfs_2022_23_person",
    survey_year = "2022-23",
    approach = "ps"
  )
)
```

### State Comparison

```r
quarto::quarto_render(
  "analysis/templates/state_comparison.qmd",
  execute_params = list(
    data_file = "plfs_2022_23_person",
    survey_year = "2022-23"
  )
)
```

## Configuration

Edit `config.yaml` to change settings:

```yaml
api:
  base_url: "https://microdata.gov.in/NADA/index.php"
  api_key: "your_api_key_here"

settings:
  default_survey: "PLFS"
  save_format: "parquet"
  confidence_level: 0.95
```

## Requirements

- R 4.0+
- RStudio (recommended)
- ~2GB disk space for packages
- 8GB RAM (sufficient for PLFS)

## Activity Status Codes (PLFS)

| Code | Description | Category |
|------|-------------|----------|
| 11-12 | Self-employed (own account/employer) | Employed |
| 21 | Unpaid family worker | Employed |
| 31 | Regular wage/salaried | Employed |
| 41, 51 | Casual labour | Employed |
| 61 | Unemployed (seeking work) | Unemployed |
| 71-98 | Not in labour force | NILF |

## Tips

1. **Memory Management**: Use Parquet format for large files
2. **First Run**: Always run `00_setup.R` first to install packages
3. **Survey Weights**: Never analyze without proper weights - use `create_plfs_design()`
4. **Confidence Intervals**: All indicator functions return SEs and CIs by default

## License

This project is for research and educational purposes. Survey data is subject to microdata.gov.in terms of use.

## Author

Created using the IndiaData analysis system.
