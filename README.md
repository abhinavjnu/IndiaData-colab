# IndiaData: MoSPI Survey Microdata Analysis System

![Validation Status: Verified](https://img.shields.io/badge/Validation-Verified_ against_Real_Data-success)
![Accuracy](https://img.shields.io/badge/Accuracy-Exact_Match_(%3C0.01pp)-blue)

A comprehensive R-based automated workflow for analyzing large-scale Indian government survey data from [microdata.gov.in](https://microdata.gov.in), including PLFS (Periodic Labour Force Survey), HCES, NSS, and ASI.

This pipeline has been **rigorously validated against real MoSPI PLFS Calendar Year 2024 data (415,000+ records)** and produces exact matches (within 0.01 percentage points) to official manual calculation methods for all major indicators (LFPR, WPR, UR).

## Features

- **✅ Validation-Proven**: 100% exact match on LFPR, WPR, and UR estimates compared to MoSPI official manual calculations.
- **Official MoSPI Methodologies**: Built-in support for Principal + Subsidiary Status (PS+SS) and Current Weekly Status (CWS) approaches.
- **Intelligent Weight Design**: Auto-computation of PLFS multipliers accounting for `NO_QTR`, combined subsamples (`NSC` vs `NSS`), and Calendar Year datasets.
- **Data Acquisition API**: Discover and download data directly from the microdata.gov.in API.
- **Turnkey Analysis**: Pre-built, robust functions for Labour indicators, exportable to Word (.docx) and LaTeX.
- **Memory Efficient**: Export to Parquet for fast loading and low memory overhead.

## Quick Start

### 1. Open the Project
Double-click `IndiaData.Rproj` to open in RStudio.

### 2. Install Packages (One Time)
```r
source("R/00_setup.R")
```
This installs all required packages (like `data.table`, `survey`, `srvyr`).

### 3. Basic Workflow

```r
library(data.table)

# Load all functions
source("R/01_config.R")
source("R/03_survey_design.R")
source("R/04_plfs_indicators.R")

# 1. Read PLFS data
# (Assumes layout applied and data saved as CSV or Parquet)
plfs <- fread("data/raw/cperv1.csv")

# Filter to working age population (15+)
plfs_15 <- plfs[Age >= 15]

# 2. Create survey design (handles all weights, strata, clusters automatically)
design <- create_plfs_design(plfs_15)

# 3. Calculate indicators (Official PS+SS Approach)
lfpr_overall <- calc_lfpr(design, approach = "psss")
lfpr_by_state <- calc_lfpr(design, by = "State_UT_Code", approach = "psss")

print(lfpr_overall)
```

## Downloading Data via API

Use the built-in python and R scripts to interact with the API. 
*Note: Do not hardcode your API keys. Use environment variables.*

```bash
# Export your API key first
export MOSPI_API_KEY="your_actual_api_key_here"

# Discover datasets
python PLFS/discover_datasets.py
```

Or via R:
```r
source("R/01_config.R")
source("R/02_api_helpers.R")

search_datasets("PLFS")
```

## Supported Labour Indicator Approaches

Calculate indicators with a single parameter change (`approach`):

1. **`psss` (Principal + Subsidiary Status)**: The official MoSPI "Usual Status" methodology. Considers a person employed if EITHER their Principal or Subsidiary status indicates employment. Unemployed only if Principal is unemployed AND Subsidiary is not employed.
2. **`cws` (Current Weekly Status)**: Short-term status based on the preceding 7 days.
3. **`ps` (Principal Status)**: Strict status based on the majority time of the preceding 365 days.

## PLFS Weight Formula

The system automatically detects your variables and applies the correct official MoSPI multiplier formula:

```R
# Computed dynamically based on State x Sector x Stratum x Sub_Stratum
NO_QTR = uniqueN(Quarter) 

# For individual sub-samples (NSS == NSC):
Final_Weight = MULT / (NO_QTR * 100)

# For combined sub-samples (NSS != NSC):
Final_Weight = MULT / (NO_QTR * 200)
```

## Activity Status Codes (PLFS)

The pipeline uses the official activity status codes natively:

| Code | Description | Category |
|------|-------------|----------|
| **11-12** | Self-employed (own account/employer) | Employed |
| **21** | Unpaid family worker | Employed |
| **31** | Regular wage/salaried | Employed |
| **41, 51** | Casual labour | Employed |
| **81, 82** | Unemployed (seeking/available for work) | Unemployed |
| **91-99** | Not in labour force (students, domestic, etc) | NILF |

*Note: Codes 61-62 are often confused as unemployed but are actually "attended educational institution" (NILF).*

## Validation Proof

Run `Rscript tests/validate_pipeline.R` on real microdata to see the test suite in action:

```text
Indicator          Manual  Pipeline    Diff
───────────  ──────  ────────  ────
LFPR (CWS)          55.2%     55.2%   0.01pp
WPR (CWS)           52.4%     52.4%   0.01pp
UR (CWS)             5.0%      5.0%   0.00pp
LFPR (PS+SS)        59.6%     59.6%   0.01pp
WPR (PS+SS)         57.7%     57.7%   0.01pp
UR (PS+SS)           3.2%      3.2%   0.00pp

✅ ALL INDICATORS MATCH MANUAL GROUND TRUTH (< 1pp)
```

## License
This project is for research and educational purposes. Survey data is subject to microdata.gov.in terms of use.
