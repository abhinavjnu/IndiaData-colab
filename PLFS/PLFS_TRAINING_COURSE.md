# PLFS Analyst Training Course

## A Comprehensive Guide for Working with Periodic Labour Force Survey Data

**Version**: 1.0  
**Last Updated**: February 2026  
**Target Audience**: New analysts, researchers, and data scientists  
**Prerequisites**: Basic R programming, statistics fundamentals

---

## 📋 Course Overview

This training course prepares analysts to work effectively with the **Periodic Labour Force Survey (PLFS)** datasets from the Government of India. PLFS is India's primary source of labour market statistics, replacing the older Employment-Unemployment Surveys conducted by NSSO.

**Course Duration**: 5 days (intensive) or 4 weeks (part-time)  
**Format**: Theory + Hands-on Labs + Assessment  
**Tools Required**: R/RStudio, required packages, access to PLFS data files

---

## 🎯 Learning Objectives

By the end of this course, you will be able to:

1. **Understand PLFS Survey Design**: Sampling methodology, visit structure, and data hierarchy
2. **Navigate Documentation**: Use Data Layout files, Instruction Manuals, and Estimation Procedures
3. **Parse Raw Data**: Convert fixed-width text files into analysis-ready formats
4. **Apply Survey Weights**: Correctly calculate multipliers for population estimates
5. **Compute Key Indicators**: Calculate LFPR, WPR, UR, and other labour market metrics
6. **Avoid Common Errors**: Identify and prevent typical mistakes in PLFS analysis
7. **Generate Reports**: Produce publication-ready tables and visualizations

---

## 📚 Module 1: Introduction to PLFS (Day 1)

### 1.1 What is PLFS?

The **Periodic Labour Force Survey (PLFS)** is a nationwide survey conducted by the Ministry of Statistics & Programme Implementation (MoSPI), Government of India. It collects detailed information on:

- Employment status (employed, unemployed, not in labour force)
- Industry and occupation
- Wages and earnings
- Demographic characteristics
- Education and training

**Key Features:**
- **Started**: 2017-18 (first round)
- **Frequency**: Continuous survey with annual/quarterly estimates
- **Coverage**: All states/UTs of India
- **Sample Size**: ~100,000 households per year
- **Reference Period**: 
  - Usual Status (PS): Previous 365 days
  - Current Weekly Status (CWS): Previous 7 days

### 1.2 PLFS vs. Previous NSSO Surveys

| Aspect | Old NSS EUS | PLFS |
|--------|-------------|------|
| **Frequency** | Quinquennial (every 5 years) | Continuous (annual) |
| **Rural Visits** | Multiple visits | Single visit |
| **Urban Visits** | Multiple visits | 4 quarterly visits |
| **Questionnaire** | 10+ schedules | Unified Schedule 10.4 |
| **Estimates** | Point-in-time | Time series |

### 1.3 Data Structure Overview

PLFS data comes in **two hierarchical levels**:

**Level 1: Household Data (HH)**
- Housing characteristics
- Land ownership
- Religion, social group
- Household amenities

**Level 2: Person Data (PER)**
- Demographics (age, sex, marital status)
- Education
- Activity status (employment)
- Industry and occupation
- Wages and earnings

**Unique Identifier (Primary Key):**
```
FSU_No + Hamlet_Group + Second_Stage_Stratum + Sample_Household_No (+ Visit)
```

### 1.4 File Organization

```
PLFS/
├── 2017-18/                    # First PLFS round
├── 2018-19/
├── 2019-20/
├── 2020-21/
├── 2021-22/
├── 2022-23/
├── 2023-24/                    # Most complete folder
│   ├── raw/                    # Raw .TXT files
│   │   ├── CHHV1.TXT          # Household data
│   │   └── CPERV1.TXT         # Person data
│   ├── csv/                    # Converted CSV files
│   ├── Data_LayoutPLFS_2023-24.xlsx  # Variable specifications
│   └── parse_plfs_2023-24.R    # Parsing script
├── 2024/                       # Latest calendar year
├── common_docs/                # Generic documentation
│   ├── Instruction_Manual_PLFS_Vol-II.pdf
│   ├── EstimationProcedure_PLFS.pdf
│   └── README.pdf
└── Panel_data/                 # Cross-year panel files
```

**📖 Exercise 1.1**: Explore the folder structure. Identify which years have complete data vs. documentation only.

---

## 📚 Module 2: Understanding Documentation (Day 1-2)

### 2.1 The Three Essential Documents

You **cannot** analyze PLFS data without these three documents. Think of them as your "Rosetta Stone":

#### Document 1: Data Layout (.xlsx)
**Purpose**: Technical parsing specifications  
**What it tells you**: Byte positions for each variable

**Typical Columns:**
- `Variable_Name`: Name of the variable
- `Start_Position`: Beginning byte (1-indexed)
- `End_Position`: Ending byte
- `Width`: Number of characters
- `Description`: What the variable represents

**Example:**
| Variable_Name | Start | End | Width | Description |
|---------------|-------|-----|-------|-------------|
| FSU_NO | 1 | 5 | 5 | First Stage Unit Number |
| AGE | 23 | 25 | 3 | Age in completed years |
| SEX | 26 | 26 | 1 | Sex (1=Male, 2=Female) |

> 💡 **Pro Tip**: Always keep the Data Layout open on a second screen while coding.

#### Document 2: Instruction Manual (Vol-II, .pdf)
**Purpose**: Variable definitions and coding schemes  
**What it tells you**: What each code means

**Key Sections:**
- Activity status codes (11, 12, 21, 31, 41, 51, 61, 71-98)
- Industry classification (NIC codes)
- Occupation classification (NCO codes)
- Education codes

#### Document 3: Estimation Procedure (.pdf)
**Purpose**: Statistical methodology  
**What it tells you**: How to calculate weights and estimates

**Key Topics:**
- Multiplier calculation formula
- Sub-sample combining
- Variance estimation
- Stratification details

### 2.2 Activity Status Codes (CRITICAL)

This is the **most important** coding system in PLFS. Master these codes:

**Employed (Working):**
| Code | Description | Category |
|------|-------------|----------|
| 11 | Self-employed (own account worker) | Employed |
| 12 | Self-employed (employer) | Employed |
| 21 | Helper in household enterprise | Employed |
| 31 | Regular wage/salaried employee | Employed |
| 41 | Casual wage labour (public works) | Employed |
| 51 | Casual wage labour (other works) | Employed |

**Unemployed:**
| Code | Description | Category |
|------|-------------|----------|
| 61 | Seeking work | Unemployed |
| 62 | Available for work | Unemployed |

**Not in Labour Force:**
| Code | Description | Category |
|------|-------------|----------|
| 71 | Attending educational institution | NILF |
| 72 | Domestic duties | NILF |
| 81 | Rentiers, pensioners | NILF |
| 82 | Not able to work | NILF |
| 91 | Other not in labour force | NILF |
| 92-98 | Other categories | NILF |

**Quick Classification:**
```
Employed:    11, 12, 21, 31, 41, 51
Unemployed:  61, 62
Labour Force: 11-51, 61-62 (Employed + Unemployed)
NILF:        71-98
```

### 2.3 Principal Status vs. Current Weekly Status

**Principal Status (PS)**
- Based on **major time** spent in the last 365 days
- Person's "usual" activity
- More stable, less volatile
- Use for: Annual comparisons, structural analysis

**Current Weekly Status (CWS)**
- Based on **reference week** (last 7 days)
- Person's current activity
- More volatile, captures short-term changes
- Use for: Current snapshot, quarterly trends

**Example:**
- Person worked 8 months, unemployed 4 months → PS = Employed
- Person didn't work last week but worked before → CWS = Unemployed

### 2.4 Visit Structure and Multipliers

**Urban Areas:**
- 4 visits (quarters) per year
- Each household surveyed 4 times
- **Important**: Don't sum all visits (will quadruple-count!)

**Rural Areas:**
- 1 visit per year
- Simpler structure

**Multiplier Formula:**
```
For sub-sample estimates:     Weight = MULT / (NO_QTR * 100)
For combined estimates:       Weight = MULT / (NO_QTR * 200)
For calendar year data:       Weight = MULT / 100
```

Where:
- `MULT`: Sub-sample multiplier from data
- `NO_QTR`: Number of quarters (usually 1 for rural, 4 for urban)
- 100/200: Scaling factors from official procedure

**📖 Exercise 2.1**: Open a Data Layout file and identify the byte positions for Age, Sex, and Activity Status.

**📖 Exercise 2.2**: Write down the activity status codes for: (a) A regular salaried worker, (b) An unemployed person seeking work, (c) A student.

---

## 📚 Module 3: Environment Setup (Day 2)

### 3.1 Required Software

**Essential:**
- R (version 4.2.0 or higher)
- RStudio (latest version)
- Git (for version control)

**Optional but Recommended:**
- VS Code with R extension
- DuckDB (for large dataset exploration)

### 3.2 Required R Packages

```r
# Core packages (install once)
install.packages(c(
  "data.table",      # Fast data manipulation
  "survey",          # Survey statistics
  "srvyr",           # Tidy survey analysis
  "readxl",          # Read Excel files
  "arrow",           # Parquet file format
  "dplyr",           # Data manipulation
  "haven",           # Stata/SPSS files
  "progress",        # Progress bars
  "yaml",            # Config files
  "here",            # Path management
  "fs"               # File system operations
))
```

### 3.3 Project Structure Setup

Our analysis framework uses a standardized structure:

```
IndiaData/
├── R/                      # R modules (00-07)
│   ├── 01_config.R        # Configuration loader
│   ├── 02_read_microdata.R # File parsing
│   ├── 03_survey_design.R  # Survey design setup
│   ├── 04_plfs_indicators.R # Indicator calculation
│   ├── 05_codebook_utils.R # Code decoding
│   ├── 06_export_tables.R  # Table export
│   └── 07_viz_themes.R     # Visualization
├── data/
│   ├── raw/               # Raw downloaded files
│   ├── processed/         # Parsed Parquet/CSV files
│   ├── codebooks/         # Lookup tables
│   ├── tables/            # Output tables
│   └── figures/           # Output charts
├── PLFS/                  # PLFS-specific files
├── config.yaml            # Configuration file
└── .Rproj                 # RStudio project file
```

### 3.4 Configuration File (config.yaml)

Create a `config.yaml` file in your project root:

```yaml
# Project Configuration
settings:
  default_survey: "plfs"
  save_format: "parquet"
  encoding: "UTF-8"

# Directory Paths
paths:
  raw_data: "data/raw"
  processed_data: "data/processed"
  codebooks: "data/codebooks"
  tables: "data/tables"
  figures: "data/figures"

# API Settings (for microdata.gov.in)
api:
  base_url: "https://microdata.gov.in/nada/index.php/api"
  api_key: "YOUR_API_KEY_HERE"  # Get from microdata.gov.in

# Survey-specific settings
surveys:
  plfs:
    default_age_min: 15
    default_age_max: 99
    weight_divisor: 100
  nss:
    weight_divisor: 100
  hces:
    weight_divisor: 100
```

### 3.5 Loading the Framework

Every analysis script should start with:

```r
# Set working directory to project root
setwd("D:/Opencode/Data Analysis/IndiaData")

# Load configuration and core modules
source("R/01_config.R")
source("R/02_read_microdata.R")
source("R/03_survey_design.R")
source("R/04_plfs_indicators.R")
source("R/05_codebook_utils.R")

# Verify setup
print_config()
```

**📖 Exercise 3.1**: Set up your environment. Install required packages and create the folder structure.

**📖 Exercise 3.2**: Create a config.yaml file with your settings and verify it loads correctly.

---

## 📚 Module 4: Data Parsing and Processing (Day 3)

### 4.1 Understanding Fixed-Width Format

PLFS raw data comes as **fixed-width text files (.txt)**. This means:
- No delimiters (commas, tabs)
- Each variable occupies specific character positions
- Must use Data Layout to parse correctly

**Example Raw Data Line:**
```
123450110010001025120101311...
```

Breaking it down (hypothetical positions):
- Positions 1-5: FSU_NO = "12345"
- Positions 6-8: Stratum = "011"
- Positions 9-11: Sub-stratum = "001"
- Positions 23-25: Age = "025"
- Positions 26-26: Sex = "1"
- Positions 31-32: Status = "31"

### 4.2 Parsing Workflow

#### Step 1: Read the Data Layout

```r
# Parse the Excel layout file
layout <- parse_layout("PLFS/2023-24/Data_LayoutPLFS_2023-24.xlsx")

# View the layout
head(layout)
#>    var_name start end width var_name_clean
#> 1:   FSU_NO     1   5     5        FSU_NO
#> 2:   STRATUM     6   8     3        STRATUM
#> 3:       AGE    23  25     3          AGE
```

#### Step 2: Parse the Raw Text File

```r
# Parse person-level data
persons <- read_microdata(
  data_file = "PLFS/2023-24/raw/CPERV1.TXT",
  layout_file = "PLFS/2023-24/Data_LayoutPLFS_2023-24.xlsx"
)

# Check results
cat(sprintf("Loaded %s rows x %d columns\n", 
            format(nrow(persons), big.mark = ","), 
            ncol(persons)))
```

#### Step 3: Save to Efficient Format

```r
# Save as Parquet (recommended - fast, compressed)
save_as_parquet(persons, "plfs_2023-24_persons")

# Or save as CSV (for compatibility)
save_as_csv(persons, "plfs_2023-24_persons")
```

### 4.3 Complete Example: Year-Specific Script

```r
# ============================================================================
# parse_plfs_2023-24.R - Complete Processing Script
# ============================================================================

# Setup
setwd("D:/Opencode/Data Analysis/IndiaData")
source("R/01_config.R")
source("R/02_read_microdata.R")
source("R/03_survey_design.R")
source("R/04_plfs_indicators.R")
source("R/05_codebook_utils.R")

# Define paths
data_dir <- "PLFS/2023-24"
raw_dir <- file.path(data_dir, "raw")
layout_file <- file.path(data_dir, "Data_LayoutPLFS_2023-24.xlsx")

# Verify files exist
cat("Checking files...\n")
cat("  Layout file:", file.exists(layout_file), "\n")
cat("  Person data:", file.exists(file.path(raw_dir, "CPERV1.TXT")), "\n")
cat("  Household data:", file.exists(file.path(raw_dir, "CHHV1.TXT")), "\n")

# Parse Person-Level Data
cat("\n--- Parsing Person-Level Data ---\n")
persons <- read_microdata(
  data_file = file.path(raw_dir, "CPERV1.TXT"),
  layout_file = layout_file
)

# Save
persons_parquet <- "data/processed/plfs_2023-24_persons.parquet"
save_as_parquet(persons, "plfs_2023-24_persons")

# Parse Household-Level Data
cat("\n--- Parsing Household-Level Data ---\n")
households <- read_microdata(
  data_file = file.path(raw_dir, "CHHV1.TXT"),
  layout_file = layout_file
)

# Save
save_as_parquet(households, "plfs_2023-24_households")

cat("\n✓ Processing Complete!\n")
```

### 4.4 Auto-Detection Features

The framework includes auto-detection for convenience:

```r
# Auto-detect person vs household files
persons <- read_plfs_data("PLFS/2023-24/", level = "person")
households <- read_plfs_data("PLFS/2023-24/", level = "household")
```

### 4.5 Inspecting Parsed Data

```r
# Quick summary
inspect_microdata(persons)
#> === Microdata Summary ===
#> Rows: 567,890
#> Columns: 142
#> Memory: 156.3 MB
#> Column types:
#>   numeric: 89
#>   character: 53

# Preview first rows
preview_data(persons, n = 5)

# Check specific variables
table(persons$SEX)
table(persons$AGE[persons$AGE >= 15])
```

**📖 Exercise 4.1**: Parse the 2023-24 person-level data and save it as Parquet.

**📖 Exercise 4.2**: Inspect the parsed data. How many rows? What are the column types?

---

## 📚 Module 5: Survey Design and Weighting (Day 3-4)

### 5.1 Why Survey Design Matters

PLFS uses **complex survey design**:
- **Stratified**: Different strata (state × sector × stratum)
- **Multi-stage**: Villages/blocks → households → persons
- **Weighted**: Multipliers account for sampling probability

**Never** analyze PLFS data as if it were a simple random sample. This will give you wrong results.

### 5.2 Creating Survey Design Objects

```r
# Load parsed data
persons <- load_from_parquet("plfs_2023-24_persons")

# Create survey design
design <- create_plfs_design(
  data = persons,
  level = "person",
  quarter_weights = TRUE,
  subsample = "combined"
)
```

This automatically:
1. Detects key variables (weight, strata, cluster)
2. Calculates final weights using correct formula
3. Creates stratified design
4. Handles singleton strata

### 5.3 Understanding the Weight Formula

**PLFS Weight Calculation:**

```
# For single sub-sample (SS1 or SS2):
Weight = MULT / (NO_QTR * 100)

# For combined sub-samples:
Weight = MULT / (NO_QTR * 200)

# Where:
# MULT = Sub-sample multiplier from data file
# NO_QTR = Number of quarters (1 for rural, 4 for urban)
```

**Why divide by 100 or 200?**
- 100: Converts to population estimate for one sub-sample
- 200: Averages two sub-samples (1/2 weight each)

### 5.4 Survey Design Summary

```r
# Get summary of design
survey_design_summary(design)

#> === Survey Design Summary ===
#> Observations: 567,890
#> Sum of weights (est. population): 987,654,321
#> Design type: Stratified (4,567 strata), Clustered (12,345 PSUs)
#> Weight distribution:
#>   Min: 0.50
#>   Median: 45.23
#>   Mean: 89.12
#>   Max: 2,456.78
#>   CV: 125.3%
```

### 5.5 Working with Survey Objects

```r
library(srvyr)
library(dplyr)

# Weighted mean of age
mean_age <- design |>
  summarize(mean_age = survey_mean(AGE, na.rm = TRUE))

# Weighted counts by state
counts <- design |>
  group_by(State) |>
  summarize(
    n_unweighted = unweighted(n()),
    n_weighted = survey_total()
  )
```

**📖 Exercise 5.1**: Create a survey design for the 2023-24 data and check the summary.

**📖 Exercise 5.2**: Calculate the total estimated population (sum of weights) for persons aged 15+.

---

## 📚 Module 6: Calculating Key Indicators (Day 4)

### 6.1 The Three Core Indicators

#### Labour Force Participation Rate (LFPR)
```
LFPR = (Labour Force / Population) × 100

Where:
- Labour Force = Employed + Unemployed
- Population = All persons in age group
```

**Code Implementation:**
```r
# Calculate overall LFPR for age 15+
lfpr_overall <- calc_lfpr(
  design = design,
  by = NULL,
  approach = "ps",
  age_filter = c(15, 99)
)

#> lfpr  lfpr_se  n  n_in_lf
#> 52.3   0.12   567890  298765
```

#### Worker Population Ratio (WPR) / Employment Rate
```
WPR = (Employed / Population) × 100
```

**Code Implementation:**
```r
wpr_overall <- calc_wpr(
  design = design,
  by = NULL,
  approach = "ps",
  age_filter = c(15, 99)
)
```

#### Unemployment Rate (UR)
```
UR = (Unemployed / Labour Force) × 100

Note: Denominator is Labour Force, NOT total population!
```

**Code Implementation:**
```r
ur_overall <- calc_unemployment_rate(
  design = design,
  by = NULL,
  approach = "ps",
  age_filter = c(15, 99)
)
```

### 6.2 Disaggregated Analysis

#### By Sex
```r
indicators_by_sex <- calc_indicators_by_sex(design, approach = "ps")

#>    Sex  lfpr  lfpr_se  wpr  wpr_se  ur  ur_se
#> 1: Male  75.2    0.15 71.3  0.14  5.2  0.08
#> 2: Female 28.4   0.22 24.1  0.21 15.1  0.35
```

#### By State
```r
indicators_by_state <- calc_indicators_by_state(
  design, 
  approach = "ps",
  add_names = TRUE
)

# Shows all states with LFPR, WPR, UR
```

#### By Multiple Dimensions
```r
# By state and sex
indicators <- calc_all_indicators(
  design = design,
  by = c("State", "SEX"),
  approach = "ps",
  age_filter = c(15, 59)  # Working age
)
```

### 6.3 Employment Type Distribution

```r
# Distribution of employment types
emp_dist <- calc_employment_distribution(
  design = design,
  by = "SEX",
  approach = "ps"
)

#>    SEX employment_type share share_se  n
#> 1:   1 Self-employed   45.2   0.25  123456
#> 2:   1 Regular wage    32.1   0.22   87654
#> 3:   1 Casual labour   22.7   0.18   62098
```

### 6.4 Activity Status Distribution

```r
# Full activity status breakdown
act_dist <- calc_activity_distribution(
  design = design,
  by = "SEX"
)
```

### 6.5 Complete Example: Analysis Script

```r
# ============================================================================
# plfs_analysis_example.R - Complete Analysis Workflow
# ============================================================================

# Setup
setwd("D:/Opencode/Data Analysis/IndiaData")
source("R/01_config.R")
source("R/02_read_microdata.R")
source("R/03_survey_design.R")
source("R/04_plfs_indicators.R")
source("R/05_codebook_utils.R")

# 1. Load data
persons <- load_from_parquet("plfs_2023-24_persons")

# 2. Create survey design
design <- create_plfs_design(persons, level = "person")

# 3. Calculate all indicators
indicators <- calc_all_indicators(
  design = design,
  by = c("State", "SEX"),
  approach = "ps",
  age_filter = c(15, 99)
)

# 4. Format for presentation
formatted <- format_indicators(indicators, digits = 1)

# 5. Save results
fwrite(formatted, "data/tables/plfs_2023-24_indicators.csv")

cat("✓ Analysis complete. Results saved.\n")
```

**📖 Exercise 6.1**: Calculate the overall LFPR, WPR, and UR for 2023-24.

**📖 Exercise 6.2**: Compare LFPR between males and females. What's the gap?

**📖 Exercise 6.3**: Calculate unemployment rate by state for your home state.

---

## 📚 Module 7: Code Decoding and Enrichment (Day 4)

### 7.1 Why Decode Codes?

Raw PLFS data uses numeric codes:
- State: 1, 2, 3... (not "Jammu & Kashmir", "Himachal Pradesh"...)
- Activity: 11, 12, 31... (not "Self-employed", "Regular wage"...)

Decoding makes data readable and analysis easier.

### 7.2 Decoding Functions

```r
# Decode state codes
data <- decode_state(persons, "State")

# Now data has both 'State' (code) and 'State_name' (label)

# Decode activity status
data <- decode_activity(data, "Status_Code")

# Decode industry codes (NIC)
data <- decode_nic(data, "NIC_5D", level = "division")

# Decode occupation codes (NCO)
data <- decode_nco(data, "NCO_4D")

# Decode sex codes (1/2 → Male/Female)
data <- decode_sex(data, "SEX")

# Decode sector codes (1/2 → Rural/Urban)
data <- decode_sector(data, "Sector")
```

### 7.3 Batch Decoding

```r
# Decode multiple at once
data <- decode_all(
  data = persons,
  state_col = "State",
  activity_col = "Status_Code",
  sex_col = "SEX",
  sector_col = "Sector"
)
```

### 7.4 Classification Functions

```r
# Classify activity into broad categories
data <- classify_activity(data, "Status_Code", "activity_broad")

# Results in categories: "Self-employed", "Regular wage/salaried", 
#                        "Casual labour", "Unemployed", etc.

# Classify industry into 3 broad sectors
data <- classify_sector_broad(data, "NIC_5D", "sector_broad")

# Results in: "Primary", "Secondary", "Tertiary"
```

**📖 Exercise 7.1**: Decode state and activity status codes in your dataset.

**📖 Exercise 7.2**: Create a table showing employment type distribution with proper labels (not codes).

---

## 📚 Module 8: Common Pitfalls and Best Practices (Day 5)

### 8.1 Critical Errors to Avoid

#### ❌ Pitfall 1: Summing All Visits (Urban Areas)
**Mistake**: Adding all 4 urban visits together.  
**Result**: Quadruple-counts urban population!  
**Solution**: Use weights correctly or average across visits.

```r
# WRONG - Don't do this!
urban_total <- sum(persons$MULT[persons$Sector == 2])

# RIGHT - Use survey design
urban_pop <- design |>
  filter(Sector == 2) |>
  summarize(total = survey_total())
```

#### ❌ Pitfall 2: Ignoring Weights
**Mistake**: Reporting unweighted counts.  
**Result**: Sample counts, not population estimates.  
**Solution**: Always apply multipliers.

```r
# WRONG - Unweighted count
unemployed_count <- sum(persons$Status_Code %in% c(61, 62))

# RIGHT - Weighted estimate
design |>
  summarize(unemployed = survey_total(is_unemployed))
```

#### ❌ Pitfall 3: Wrong Denominator for UR
**Mistake**: UR = Unemployed / Total Population  
**Correct**: UR = Unemployed / Labour Force  

```r
# WRONG
ur_wrong <- sum(unemployed) / sum(total_pop) * 100

# RIGHT
ur_right <- sum(unemployed) / sum(employed + unemployed) * 100
```

#### ❌ Pitfall 4: Confusing PS and CWS
**Mistake**: Mixing Principal Status and Current Weekly Status.  
**Solution**: Be explicit about which approach you use.

#### ❌ Pitfall 5: Variable Name Changes Across Years
**Mistake**: Assuming same variable names across all PLFS rounds.  
**Solution**: Check Data Layout for each year.

### 8.2 Best Practices

#### ✅ Practice 1: Always Use the Framework
```r
# Use built-in functions - they handle complexities
source("R/01_config.R")
design <- create_plfs_design(data)  # Handles weights automatically
```

#### ✅ Practice 2: Filter by Age Appropriately
```r
# Standard LFPR: Age 15+
lfpr <- calc_lfpr(design, age_filter = c(15, 99))

# Working age: 15-59
lfpr_working <- calc_lfpr(design, age_filter = c(15, 59))

# Youth unemployment: 15-29
ur_youth <- calc_unemployment_rate(design, age_filter = c(15, 29))
```

#### ✅ Practice 3: Report Standard Errors
```r
# Always get confidence intervals
result <- design |>
  summarize(
    mean = survey_mean(variable, vartype = c("se", "ci"))
  )
# Reports: mean, mean_se, mean_low, mean_upp
```

#### ✅ Practice 4: Validate Your Results
```r
# Compare with official statistics
# PLFS reports are published on https://plfs.gov.in

# Check if your estimates are in the right ballpark
```

#### ✅ Practice 5: Document Your Code
```r
# Add comments explaining key decisions
# Note which year's data, which approach (PS/CWS), age range

# Example:
# PLFS 2023-24, Principal Status approach, Age 15+
# Using combined sub-sample weights
```

### 8.3 Quality Checklist

Before finalizing any analysis, verify:

- [ ] Correct year/round specified
- [ ] PS vs CWS approach clearly stated
- [ ] Age range appropriate for indicator
- [ ] Weights applied correctly
- [ ] Visit structure handled (urban 4 visits)
- [ ] Denominator correct (especially for UR)
- [ ] Standard errors calculated
- [ ] Results comparable to official estimates
- [ ] Code documented
- [ ] Output files organized

**📖 Exercise 8.1**: Review a past analysis. Did you make any of these mistakes?

**📖 Exercise 8.2**: Create a personal checklist for your PLFS analyses.

---

## 📚 Module 9: Advanced Topics (Optional)

### 9.1 Working with Panel Data

PLFS includes panel households tracked across visits:

```r
# Load panel identification files
panel_info <- fread("PLFS/Panel_data/District_codes_PLFS_Panel_4_202324_2024.xlsx")

# Use for longitudinal analysis
```

### 9.2 Multi-Year Analysis

```r
# Load multiple years
plfs_22 <- load_from_parquet("plfs_2022-23_persons")
plfs_23 <- load_from_parquet("plfs_2023-24_persons")

# Create comparable indicators
design_22 <- create_plfs_design(plfs_22)
design_23 <- create_plfs_design(plfs_23)

ind_22 <- calc_all_indicators(design_22, by = "State")
ind_23 <- calc_all_indicators(design_23, by = "State")

# Merge and calculate change
comparison <- merge(ind_22, ind_23, by = "State", suffixes = c("_22", "_23"))
comparison[, lfpr_change := lfpr_23 - lfpr_22]
```

### 9.3 Custom Indicators

```r
# Youth Not in Employment, Education, or Training (NEET)
design <- design |>
  mutate(
    is_neet = (AGE >= 15 & AGE <= 29) &
              (Status_Code %in% c(71, 72, 81, 82, 91, 92, 93, 94, 95, 97, 98))
  )

neet_rate <- design |>
  filter(AGE >= 15 & AGE <= 29) |>
  summarize(neet = survey_mean(is_neet) * 100)
```

### 9.4 Exporting Results

```r
source("R/06_export_tables.R")

# Export to Word
export_to_word(
  indicators,
  filename = "plfs_2023-24_results.docx",
  title = "PLFS 2023-24 Key Indicators",
  notes = "Source: PLFS 2023-24, Principal Status approach"
)

# Export to LaTeX
export_to_latex(
  indicators,
  filename = "plfs_2023-24_results.tex",
  caption = "Labour Force Indicators by State"
)
```

---

## 📚 Module 10: Assessment and Certification

### 10.1 Practical Exam

Complete the following tasks using PLFS 2023-24 data:

**Task 1**: Parse the person-level data and create a survey design. (10 points)

**Task 2**: Calculate overall LFPR, WPR, and UR for ages 15+. (15 points)

**Task 3**: Calculate LFPR by state and sex. Identify the state with highest female LFPR. (20 points)

**Task 4**: Calculate unemployment rate for youth (15-29) by education level. (20 points)

**Task 5**: Create a table showing employment type distribution by sector (rural/urban). (20 points)

**Task 6**: Document your analysis and export results to Word format. (15 points)

### 10.2 Knowledge Check

Answer the following:

1. What is the difference between Principal Status and Current Weekly Status? When would you use each?

2. What are the activity status codes for:
   - Self-employed own account worker
   - Regular salaried employee
   - Unemployed seeking work
   - Student

3. Explain the weight formula for PLFS. Why do we divide by 100 or 200?

4. What is wrong with this UR calculation: `UR = Unemployed / Total Population`?

5. Why should you never sum the 4 urban visits directly?

### 10.3 Troubleshooting Scenarios

**Scenario 1**: Your LFPR estimate is 200%. What went wrong?

**Scenario 2**: Your urban population estimate is 4x higher than expected. What happened?

**Scenario 3**: You can't find the `Multiplier` variable in the data. What should you check?

---

## 📎 Appendix A: Quick Reference

### A.1 Activity Status Codes

```
EMPLOYED:
  11 - Self-employed (own account)
  12 - Self-employed (employer)
  21 - Helper in household enterprise
  31 - Regular wage/salaried
  41 - Casual labour (public works)
  51 - Casual labour (other)

UNEMPLOYED:
  61 - Seeking work
  62 - Available for work

NOT IN LABOUR FORCE:
  71 - Student
  72 - Domestic duties
  81 - Rentiers/pensioners
  82 - Not able to work
  91-98 - Other NILF
```

### A.2 Common Variable Names

| Concept | Common Names |
|---------|-------------|
| Weight | MULT, Multiplier, MLT |
| State | State, STATE, State_Code |
| Sector | Sector, SECTOR, Rural_Urban |
| Sex | Sex, SEX, Gender |
| Age | Age, AGE |
| Stratum | Stratum, STRATUM, STR |
| FSU/Cluster | FSU, FSU_NO, PSU |
| Quarter | NO_QTR, Quarter, QTR |
| Activity PS | Status_Code, Principal_Status |
| Activity CWS | CWS, Current_Weekly_Status |

### A.3 Weight Formulas

```
Sub-sample:        MULT / (NO_QTR * 100)
Combined:          MULT / (NO_QTR * 200)
Calendar Year:     MULT / 100
```

### A.4 Key Formulas

```
LFPR = (Employed + Unemployed) / Population × 100
WPR  = Employed / Population × 100
UR   = Unemployed / (Employed + Unemployed) × 100
```

### A.5 Useful R Commands

```r
# Load framework
source("R/01_config.R")

# Parse data
data <- read_microdata("file.TXT", "layout.xlsx")

# Save/load Parquet
save_as_parquet(data, "filename")
data <- load_from_parquet("filename")

# Create design
design <- create_plfs_design(data)

# Calculate indicators
lfpr <- calc_lfpr(design, by = "State")
wpr <- calc_wpr(design, by = "State")
ur <- calc_unemployment_rate(design, by = "State")

# Decode codes
data <- decode_state(data, "State")
data <- decode_activity(data, "Status")

# Inspect
inspect_microdata(data)
survey_design_summary(design)
```

---

## 📎 Appendix B: Resources

### B.1 Official Resources

- **PLFS Official Website**: https://plfs.gov.in
- **MoSPI Website**: https://mospi.gov.in
- **Microdata Portal**: https://microdata.gov.in

### B.2 Documentation Files

| File | Location | Purpose |
|------|----------|---------|
| Instruction Manual | `common_docs/Instruction_Manual_PLFS_Vol-II.pdf` | Code definitions |
| Estimation Procedure | `common_docs/EstimationProcedure_PLFS.pdf` | Weight formulas |
| Data Layout | `20XX-YY/Data_LayoutPLFS_20XX-YY.xlsx` | Variable positions |
| README | `20XX-YY/README*.pdf` | Year-specific notes |

### B.3 Codebook Files

Located in `data/codebooks/`:
- `state_codes.csv` - State code lookups
- `activity_status.csv` - Activity status descriptions
- `nic_2008.csv` - Industry codes
- `nco_2015.csv` - Occupation codes

### B.4 Framework R Modules

| Module | Purpose |
|--------|---------|
| `01_config.R` | Configuration loading |
| `02_read_microdata.R` | File parsing |
| `03_survey_design.R` | Survey design creation |
| `04_plfs_indicators.R` | Indicator calculation |
| `05_codebook_utils.R` | Code decoding |
| `06_export_tables.R` | Table export |
| `07_viz_themes.R` | Visualization |

---

## 📎 Appendix C: Glossary

**Activity Status**: A person's engagement in economic activity (employed, unemployed, not in labour force)

**CWS (Current Weekly Status)**: Activity status based on reference week (last 7 days)

**FSU (First Stage Unit)**: Primary sampling unit (village/block)

**LFPR (Labour Force Participation Rate)**: Proportion of population in labour force

**Multiplier**: Sampling weight for population estimation

**NIC (National Industrial Classification)**: Industry coding system

**NCO (National Classification of Occupations)**: Occupation coding system

**NILF (Not in Labour Force)**: People neither employed nor seeking work

**PS (Principal Status)**: Activity status based on major time in last 365 days

**PSU (Primary Sampling Unit)**: See FSU

**Sub-sample**: PLFS uses two independent sub-samples (SS1 and SS2)

**UR (Unemployment Rate)**: Proportion of labour force that is unemployed

**WPR (Worker Population Ratio)**: Proportion of population that is employed

---

## 📎 Appendix D: Troubleshooting Guide

### D.1 Common Errors

**Error**: "Layout file not found"  
**Solution**: Check file path. Use `file.exists()` to verify.

**Error**: "Could not find weight variable"  
**Solution**: Check variable name in Data Layout. May be called MULT, Multiplier, or MLT.

**Error**: "Weight variable has missing values"  
**Solution**: Check data quality. Some observations may have zero/invalid weights.

**Error**: "Singleton strata detected"  
**Solution**: Framework handles this automatically with `lonely.psu = "adjust"`.

**Error**: Estimates don't match official reports  
**Solution**: Check: (1) Same year/round, (2) Same approach (PS/CWS), (3) Same age range, (4) Weights applied correctly.

### D.2 Performance Issues

**Slow parsing**:  
- Use `nrows = 1000` for testing before full run
- Consider using CSV files if already converted
- Use Parquet format for fast loading

**Memory issues**:  
- Use `data.table` operations (memory efficient)
- Process data in chunks
- Use `gc()` to trigger garbage collection

---

## 🎓 Conclusion

You have now completed the comprehensive PLFS Analyst Training Course. You should be able to:

1. ✅ Navigate and understand PLFS documentation
2. ✅ Parse raw fixed-width data files
3. ✅ Create proper survey design objects
4. ✅ Calculate key labour force indicators correctly
5. ✅ Decode and enrich data with meaningful labels
6. ✅ Avoid common errors and follow best practices
7. ✅ Generate publication-ready outputs

### Next Steps

1. **Practice**: Work through all exercises in this course
2. **Explore**: Try analyzing different years and indicators
3. **Compare**: Validate your results against official PLFS reports
4. **Build**: Create your own analysis templates
5. **Share**: Document and share your learnings with colleagues

### Getting Help

If you encounter issues:

1. Check this guide's troubleshooting section
2. Review the existing scripts in `PLFS/` folder
3. Examine the R module source code for examples
4. Compare your code with working examples
5. Consult official PLFS documentation

---

**Good luck with your PLFS analyses!** 🚀

*For questions or feedback on this training course, please document them and share with your team lead.*

---

**Document Information**  
**Author**: Training Team  
**Version**: 1.0  
**Last Updated**: February 2026  
**Related Files**:
- `PLFS_ANALYST_GUIDE.md` - Quick reference guide
- `ORGANIZATION_SUMMARY.md` - Folder structure details
- `R/*.R` - Analysis framework modules

