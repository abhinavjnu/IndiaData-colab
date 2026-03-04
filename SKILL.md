# SKILL: Indian Government Survey Microdata Analysis (PLFS)

## Overview

This skill enables comprehensive analysis of Indian government survey microdata, specifically the **Periodic Labour Force Survey (PLFS)** from [microdata.gov.in](https://microdata.gov.in). The workflow handles fixed-width data parsing, survey-weighted analysis, and publication-quality visualizations.

## When to Use This Skill

Use this skill when the user asks about:
- PLFS (Periodic Labour Force Survey) data analysis
- Indian labour market indicators (LFPR, WPR, Unemployment Rate)
- microdata.gov.in data processing
- NSO/NSS survey data from India
- Fixed-width file parsing with layout files
- Survey-weighted statistics in R
- Postgraduate unemployment analysis
- Education-employment relationships

## Project Location

```
# Use the repository root (wherever you cloned it)
# e.g., ~/IndiaData or /path/to/IndiaData-colab
```

## Technology Stack

| Component | Technology |
|-----------|------------|
| Language | R 4.0+ |
| R Path | `Rscript` (must be on PATH; see your OS-specific R installation) |
| Data Format | Fixed-width TXT → Parquet |
| Survey Analysis | `srvyr` package (tidyverse-style survey) |
| Data Manipulation | `data.table` |
| Visualization | `ggplot2` |
| API Integration | `httr2` for microdata.gov.in |
| Export | CSV, PNG, PDF, Word, LaTeX |

## Quick Start Commands

```bash
# Setup (install packages) - Run once
Rscript R/00_setup.R

# Full analysis pipeline
Rscript run_analysis.R

# Generate charts and tables
Rscript generate_charts.R

# Postgraduate unemployment deep dive
Rscript analyze_pg_unemployment.R

# PG prime age (25-40) analysis
Rscript pg_prime_age_analysis.R

# Industry and occupation analysis
Rscript pg_industry_occupation.R

# Education vs unemployment charts
Rscript create_education_ur_charts.R
```

## Project Structure

```
IndiaData/
├── config.yaml                  # API key and settings
├── IndiaData.Rproj             # RStudio project file
│
├── R/                          # Core functions (source these)
│   ├── 00_setup.R              # Package installation
│   ├── 01_config.R             # Configuration & paths
│   ├── 02_api_helpers.R        # microdata.gov.in API
│   ├── 02_read_microdata.R     # Fixed-width parser
│   ├── 03_survey_design.R      # Survey design setup
│   ├── 04_plfs_indicators.R    # LFPR, WPR, UR functions
│   ├── 05_codebook_utils.R     # Code lookup utilities
│   ├── 06_export_tables.R      # Word/LaTeX export
│   └── 07_viz_themes.R         # ggplot2 themes
│
├── data/
│   ├── raw/                    # Downloaded TXT files
│   │   ├── CPERV1.TXT          # Person-level data
│   │   └── Data_LayoutPLFS_Calendar_2024.xlsx
│   ├── processed/              # Parquet files (fast loading)
│   │   └── plfs_2024_persons.parquet
│   └── codebooks/              # Lookup tables
│       ├── state_codes.csv     # 36 States/UTs
│       ├── nic_2008.csv        # Industry codes
│       ├── nco_2015.csv        # Occupation codes
│       └── activity_status.csv # Activity status descriptions
│
├── analysis/
│   └── templates/              # Quarto report templates
│
├── outputs/
│   ├── tables/                 # CSV exports
│   └── figures/                # PNG/PDF charts
│
├── PLFS/                       # Year-wise data storage
│   ├── 2023-24/                # Gold standard dataset
│   ├── 2024/                   # Calendar year data
│   └── PLFS_ANALYST_GUIDE.md   # Comprehensive guide
│
└── tests/                      # Unit tests
    └── testthat/
```

## Key Data Concepts

### Activity Status Codes (PLFS)

| Code | Description | Category | In Labour Force |
|------|-------------|----------|-----------------|
| 11, 12 | Self-employed (own account/employer) | Employed | Yes |
| 21 | Unpaid family worker | Employed | Yes |
| 31 | Regular wage/salaried | Employed | Yes |
| 41, 42, 51 | Casual labour | Employed | Yes |
| **61, 62** | **Unemployed (seeking/available)** | **Unemployed** | **Yes** |
| 71-98 | Not in labour force | NILF | No |

**Critical:** Always use **CWS (Current Weekly Status)** for unemployment analysis, NOT Principal Status (PS).

### Key Variables

| Variable | Description | Codes |
|----------|-------------|-------|
| `Current_Weekly_Status_CWS` | Activity status for unemployment | 11-98 |
| `Status_Code` | Principal activity status | 11-98 |
| `General_Educaion_Level` | Education level (1-13) | See below |
| `State_Ut_Code` | State/UT code | 01-37 |
| `Sector` | Rural/Urban | 1=Rural, 2=Urban |
| `Sex` | Gender | 1=Male, 2=Female |
| `Age` | Age in years | 0-99 |
| `Industry_Code_NIC` | 4-digit NIC industry | 0100-9900 |
| `Occupation_Code_NCO` | 3-digit NCO occupation | 001-999 |
| `MULT` | Sub-sample multiplier (weight) | Numeric |
| `NO_QTR` | Quarter number | 1-4 |

### Education Codes

| Code | Level | Type |
|------|-------|------|
| 1 | Not literate | - |
| 5 | Middle school | General |
| 6 | Secondary | General |
| 7 | Higher secondary | General |
| 8 | Diploma/Certificate | Technical |
| 10 | Graduate (General) | General |
| 11 | **Postgraduate+ (General)** | General |
| 12 | Graduate (Technical) | Technical |
| 13 | **Postgraduate (Technical)** | Technical |

### Labour Force Indicators

| Indicator | Formula |
|-----------|---------|
| **LFPR** | (Employed + Unemployed) / Population × 100 |
| **WPR** | Employed / Population × 100 |
| **UR** | Unemployed / Labour Force × 100 |

## Standard Workflow

### 1. Quick Analysis (Using Pre-processed Data)

```r
library(data.table)
library(arrow)

# Load processed parquet (fast!)
persons <- as.data.table(read_parquet("data/processed/plfs_2024_persons.parquet"))

# Define codes
employed_codes <- c(11, 12, 21, 31, 41, 42, 51)
unemployed_codes <- c(61, 62)
lf_codes <- c(employed_codes, unemployed_codes)

# Calculate unemployment rate by education
ur_by_edu <- persons[Age >= 15 & Current_Weekly_Status_CWS %in% lf_codes, .(
  In_LF = .N,
  Unemployed = sum(Current_Weekly_Status_CWS %in% unemployed_codes),
  UR = round(100 * sum(Current_Weekly_Status_CWS %in% unemployed_codes) / .N, 2)
), by = General_Educaion_Level]

print(ur_by_edu)
```

### 2. Full Pipeline (From Raw Data)

```r
# Source core functions
source("R/01_config.R")
source("R/02_read_microdata.R")
source("R/03_survey_design.R")
source("R/04_plfs_indicators.R")
source("R/05_codebook_utils.R")

# Parse layout
layout <- parse_layout("data/raw/Data_LayoutPLFS_Calendar_2024.xlsx")

# Read raw data
persons <- read_microdata(
  data_file = "data/raw/CPERV1.TXT",
  layout = layout,
  use_clean_names = TRUE
)

# Save as parquet for future use
save_as_parquet(persons, "plfs_2024_persons")

# Create survey design with proper weights
design <- create_plfs_design(persons, level = "person")

# Calculate weighted indicators
overall <- calc_all_indicators(design, approach = "cws")
by_sex <- calc_indicators_by_sex(design, approach = "cws")
by_state <- calc_indicators_by_state(design, approach = "cws")

# Export results
fwrite(by_state, "outputs/tables/indicators_by_state.csv")
```

### 3. Using the API to Download Data

```r
source("R/01_config.R")
source("R/02_api_helpers.R")

# Test API connection
test_api_connection()

# Search for PLFS datasets
datasets <- search_datasets("PLFS 2024")
print(datasets)

# Download specific dataset
download_dataset(dataset_id = "2728", extract = TRUE)

# Or use convenience function
download_plfs(year = "2024")
```

## Variable Detection Utility

The system includes centralized variable detection to handle different naming conventions:

```r
source("R/01_config.R")

# Detect single variable
weight_var <- detect_variable(persons, "weight")
age_var <- detect_variable(persons, "age")
state_var <- detect_variable(persons, "state")

# Detect multiple variables
detected <- detect_variables(persons, c("weight", "state", "sector", "sex"))
print(detected)

# Report all detected variables
report_detected_variables(persons)
```

**Supported Variable Types:**
- `weight` - Multiplier/weight variables
- `strata` - Stratum variables
- `cluster` - FSU/cluster variables
- `state` - State codes
- `sector` - Rural/urban
- `sex` - Gender
- `age` - Age
- `status_ps` - Principal status
- `status_cws` - Current weekly status
- `quarter` - Quarter/visit
- `subsample` - Sub-sample indicator

## Common Analysis Patterns

### 1. Calculate Indicator by Group

```r
# UR by education level
ur_by_edu <- persons[Age >= 15 & Current_Weekly_Status_CWS %in% lf_codes, .(
  In_LF = .N,
  Unemployed = sum(Current_Weekly_Status_CWS %in% unemployed_codes),
  UR = round(100 * sum(Current_Weekly_Status_CWS %in% unemployed_codes) / .N, 2)
), by = General_Educaion_Level]
```

### 2. Cross-Tabulation (Multiple Groups)

```r
# UR by Education × Sex × Sector
ur_cross <- persons[Age >= 15 & Current_Weekly_Status_CWS %in% lf_codes, .(
  In_LF = .N,
  Unemployed = sum(Current_Weekly_Status_CWS %in% unemployed_codes),
  UR = round(100 * sum(Current_Weekly_Status_CWS %in% unemployed_codes) / .N, 2)
), by = .(General_Educaion_Level, Sex, Sector)]
```

### 3. Employment Type Distribution

```r
# Among employed, what type of employment?
persons[Current_Weekly_Status_CWS %in% employed_codes, .(
  Count = .N,
  Self_Employed = sum(Current_Weekly_Status_CWS %in% c(11, 12)),
  Regular_Wage = sum(Current_Weekly_Status_CWS == 31),
  Casual = sum(Current_Weekly_Status_CWS %in% c(41, 42, 51))
), by = Group_Variable]
```

### 4. Industry/Occupation Analysis

```r
# Merge with codebooks
nic <- fread("data/codebooks/nic_2008.csv")
nco <- fread("data/codebooks/nco_2015.csv")

# Extract 2-digit industry, 1-digit occupation
persons[, NIC_2digit := as.integer(substr(sprintf("%04d", Industry_Code_NIC), 1, 2))]
persons[, NCO_1digit := as.integer(substr(sprintf("%03d", Occupation_Code_NCO), 1, 1))]

# Merge
persons <- merge(persons, nic[, .(nic_2digit, section_name)], 
                 by.x = "NIC_2digit", by.y = "nic_2digit", all.x = TRUE)
```

### 5. Postgraduate (Age 25-40) Analysis

```r
# Filter to PG, Age 25-40
pg <- persons[Age >= 25 & Age <= 40 & General_Educaion_Level %in% c(11, 13)]
pg[, Education := ifelse(General_Educaion_Level == 11, "General", "Technical")]
pg[, Sex_Label := ifelse(Sex == 1, "Male", "Female")]
pg[, Sector_Label := ifelse(Sector == 1, "Rural", "Urban")]

# Labour force status
pg[, LF_Status := fcase(
  Current_Weekly_Status_CWS %in% employed_codes, "Employed",
  Current_Weekly_Status_CWS %in% unemployed_codes, "Unemployed",
  default = "Not in LF"
)]

# Calculate UR matrix: Tech/General × Male/Female × Rural/Urban
ur_matrix <- pg[LF_Status %in% c("Employed", "Unemployed"), .(
  In_LF = .N,
  Unemployed = sum(LF_Status == "Unemployed"),
  UR = round(100 * sum(LF_Status == "Unemployed") / .N, 2)
), by = .(Education, Sex_Label, Sector_Label)]
```

### 6. Create Publication-Quality Charts

```r
library(ggplot2)

theme_pub <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = base_size * 1.2),
      plot.subtitle = element_text(color = "grey40"),
      plot.caption = element_text(color = "grey50", hjust = 1),
      axis.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank()
    )
}

colors_sex <- c("Male" = "#2171b5", "Female" = "#cb181d")
colors_edu <- c("General" = "#e41a1c", "Technical" = "#4daf4a")

ggplot(data, aes(x = Group, y = Value, fill = Category)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(Value, "%")), 
            position = position_dodge(width = 0.8), vjust = -0.5) +
  scale_fill_manual(values = colors_edu) +
  theme_pub() +
  labs(title = "Title", subtitle = "Subtitle", caption = "Source: PLFS 2024")

ggsave("outputs/figures/chart_name.png", width = 12, height = 7, dpi = 300)
```

## Survey-Weighted Analysis (Proper Method)

For publication-quality estimates with standard errors:

```r
source("R/01_config.R")
source("R/03_survey_design.R")
source("R/04_plfs_indicators.R")

# Create survey design (handles weights, strata, clusters)
design <- create_plfs_design(persons)

# Calculate weighted indicators with SEs
overall <- calc_all_indicators(design, approach = "cws")
by_sex <- calc_indicators_by_sex(design, approach = "cws")
by_state <- calc_indicators_by_state(design, approach = "cws")

# Custom analysis by any grouping
by_education <- calc_all_indicators(design, by = "General_Educaion_Level", approach = "cws")
```

## Codebook Utilities

```r
source("R/01_config.R")
source("R/05_codebook_utils.R")

# Decode state codes
persons <- decode_state(persons, "State_Ut_Code")

# Decode activity status
persons <- decode_activity(persons, "Current_Weekly_Status_CWS")

# Decode industry (NIC) codes
persons <- decode_nic(persons, "Industry_Code_NIC", level = "division")

# Decode occupation (NCO) codes
persons <- decode_nco(persons, "Occupation_Code_NCO")

# Decode sex and sector
persons <- decode_sex(persons, "Sex")
persons <- decode_sector(persons, "Sector")

# Decode everything at once
persons <- decode_all(persons, 
                      state_col = "State_Ut_Code",
                      activity_col = "Current_Weekly_Status_CWS",
                      sex_col = "Sex",
                      sector_col = "Sector")
```

## Critical Notes

### 1. Use CWS for Unemployment

```r
# WRONG: Principal Status (Status_Code) shows 0% unemployment
# RIGHT: Current Weekly Status (Current_Weekly_Status_CWS) captures unemployment

approach = "cws"  # NOT "ps"
```

### 2. Age Filter

Always filter to working-age population:

```r
persons[Age >= 15, ...]  # Standard LFPR/WPR/UR definition
persons[Age >= 15 & Age <= 64, ...]  # Working-age only
```

### 3. Unemployment Codes

```r
# Include BOTH codes
unemployed_codes <- c(61, 62)  # NOT just c(61)
```

### 4. Employed Codes

```r
# Include code 42 (casual labour variant)
employed_codes <- c(11, 12, 21, 31, 41, 42, 51)  # NOT just c(11, 12, 21, 31, 41, 51)
```

### 5. Weights Formula

PLFS uses multiplier-based weights:

```r
# Sub-sample: Final_Weight = MULT / (NO_QTR × 100)
# Combined:   Final_Weight = MULT / (NO_QTR × 200)
# Calendar:   Final_Weight = MULT / 100
```

The `create_plfs_design()` function handles this automatically.

## Output Files Reference

### Tables (outputs/tables/)

| File | Description |
|------|-------------|
| `01_sample_overview.csv` | Sample demographics |
| `02_age_by_sex.csv` | Age distribution by sex |
| `03_education_distribution.csv` | Education levels (Age 15+) |
| `04_cws_distribution.csv` | Activity status distribution |
| `05_overall_indicators.csv` | Overall LFPR, WPR, UR |
| `06_indicators_by_sex.csv` | By Male/Female |
| `07_indicators_by_sector.csv` | Rural vs Urban |
| `08_indicators_by_state.csv` | All 36 states/UTs |
| `09_ur_by_education.csv` | UR by education level |
| `10_ur_by_education_sex.csv` | UR by education × sex |
| `11_pg_ur_by_age.csv` | PG unemployment by age |
| `12_pg_ur_by_sex.csv` | PG unemployment by sex |
| `13_pg_ur_by_sector.csv` | PG unemployment rural/urban |
| `14_employment_type_distribution.csv` | Employment type breakdown |
| `15_pg_ur_by_state.csv` | PG unemployment by state |
| `16_pg_prime_age_summary.csv` | PG (25-40) full summary |
| `17_pg_emp_type_detailed.csv` | PG employment type details |
| `18_pg_industry_distribution.csv` | Where PGs work |
| `19_pg_occupation_distribution.csv` | What jobs PGs do |
| `20_pg_job_appropriateness.csv` | Job quality metrics |
| `21_pg_underemployment.csv` | PG underemployment rates |

### Figures (outputs/figures/)

| File | Description |
|------|-------------|
| `01_age_pyramid.png` | Population pyramid |
| `02_lfpr_by_sex.png` | LFPR comparison |
| `03_indicators_by_sex.png` | All indicators by sex |
| `04_lfpr_by_state.png` | State-wise LFPR |
| `05_ur_top_states.png` | Top 10 states by UR |
| `06_rural_urban_comparison.png` | Rural vs urban |
| `07_employment_type.png` | Employment type distribution |
| `08_lfpr_by_age.png` | Age-wise LFPR |
| `09_lfpr_by_education.png` | Education-wise LFPR |
| `10_ur_by_education.png` | Education-unemployment relationship |
| `11_ur_by_education_sex.png` | Education × sex UR |
| `12_education_ur_trend.png` | UR trend by education |
| `13_pg_ur_by_age.png` | PG unemployment by age |
| `14_pg_ur_by_sex.png` | PG unemployment by sex |
| `15_pg_ur_by_sector.png` | PG unemployment by sector |
| `16_employment_type_by_education.png` | Employment type by education |
| `17_pg_ur_matrix.png` | PG UR: Tech vs General × Sex × Sector |
| `18_pg_lfpr_matrix.png` | PG LFPR matrix |
| `19_pg_regular_wage.png` | Regular wage employment |
| `20_pg_emp_type_stacked.png` | Employment type stacked |
| `21_pg_ur_faceted.png` | Faceted UR comparison |
| `22_pg_indicators_dot.png` | Dot plot comparison |
| `23_pg_industry_distribution.png` | PG industry comparison |
| `24_pg_occupation_distribution.png` | PG occupation comparison |
| `25_pg_industry_by_sex.png` | Industry by sex |
| `26_pg_job_appropriateness.png` | Job appropriateness |
| `27_pg_underemployment.png` | PG underemployment rates |

## Key Findings (Reference)

### Overall Indicators (PLFS 2024)
- LFPR: 53.15%
- WPR: 52.45%
- UR: 1.33%

### Gender Gap
- Male LFPR: 73.88%
- Female LFPR: 32.71%
- Gender Gap: 41.17 percentage points

### Education-Unemployment Paradox
- Correlation: -0.285 (weak negative)
- Highest UR: Postgraduate (General) at 2.03%
- Lowest UR: Graduate (Technical) at 0.83%

### Technical vs General Education (PG, Age 25-40)

| Metric | Technical | General |
|--------|-----------|---------|
| Unemployment Rate | 0.84% | 1.88% |
| In Professional Jobs | 48.4% | 13.5% |
| In Appropriate Jobs | 67.8% | 33.5% |
| Male Underemployment | 11.6% | 52.9% |

### Industry Distribution (PG 25-40)

**Technical PGs:**
- Healthcare: ~40%
- Education: ~25%
- IT/Telecom: ~10%

**General PGs:**
- Education: ~30%
- Trade: ~15%
- Agriculture: ~10%

### Job Appropriateness (PG 25-40)
- Technical PGs: 67.8% in appropriate jobs (Managers/Professionals/Technicians)
- General PGs: 33.5% in appropriate jobs

## Troubleshooting

### Common Issues

1. **UR shows 0%**: Using `Status_Code` instead of `Current_Weekly_Status_CWS`
2. **Memory issues**: Use parquet file, not raw TXT
3. **Missing columns**: Check exact column names with `names(persons)`
4. **State names missing**: Merge with `data/codebooks/state_codes.csv`
5. **API connection fails**: Check config.yaml has valid API key

### R Execution

```bash
# Run R script from command line (any OS)
cd /path/to/IndiaData-colab
Rscript run_analysis.R
```

## Testing

```r
# Run all tests
testthat::test_dir("tests/testthat")

# Run specific test file
testthat::test_file("tests/testthat/test-plfs-indicators.R")
```

## Extending the Analysis

To add new analyses:

1. Create new R script in project root
2. Load parquet data: `persons <- as.data.table(read_parquet(...))`
3. Define codes (employed, unemployed, etc.)
4. Filter and aggregate using data.table
5. Create ggplot2 charts with `theme_pub()`
6. Save to `outputs/tables/` and `outputs/figures/`

## Data Source

- **Survey**: Periodic Labour Force Survey (PLFS) Calendar Year 2024
- **Source**: [microdata.gov.in](https://microdata.gov.in)
- **Coverage**: All India, 36 States/UTs
- **Sample**: 415,549 persons
- **Design**: Stratified multi-stage random sampling
- **Reference Period**: January 2024 - December 2024

## Additional Resources

- `PLFS/PLFS_ANALYST_GUIDE.md` - Comprehensive analyst guide
- `PLFS/PLFS_TRAINING_COURSE.md` - Training materials
- `README.md` - Project overview
- `IMPROVEMENTS.md` - Codebase improvements summary
