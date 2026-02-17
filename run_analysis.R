# ============================================================================
# run_analysis.R - Complete PLFS Analysis Runner
# ============================================================================
# This script runs the full PLFS analysis pipeline:
# 1. Load data from fixed-width TXT using layout file
# 2. Create survey design with proper weights
# 3. Calculate labour force indicators
# 4. Export tables to Word/LaTeX
# 5. Generate visualizations
#
# USAGE: Open in RStudio and run (Ctrl+Shift+Enter) or source("run_analysis.R")
# ============================================================================

cat("\n========================================\n")
cat("PLFS Analysis Pipeline Starting...\n")
cat("========================================\n\n")

# ============================================================================
# Step 0: Load All Functions
# ============================================================================
cat("Step 0: Loading functions...\n")

source("R/01_config.R")
source("R/02_read_microdata.R")
source("R/03_survey_design.R")
source("R/04_plfs_indicators.R")
source("R/05_codebook_utils.R")
source("R/06_export_tables.R")
source("R/07_viz_themes.R")

cat("  All functions loaded.\n\n")

# ============================================================================
# Step 1: Define File Paths
# ============================================================================
cat("Step 1: Setting up file paths...\n")

# Data files
person_data_file <- raw_path("CPERV1.TXT")
household_data_file <- raw_path("CHHV1.TXT")
layout_file <- raw_path("Data_LayoutPLFS_Calendar_2024 (4).xlsx")

# Verify files exist
stopifnot("Person data file not found" = file.exists(person_data_file))
stopifnot("Layout file not found" = file.exists(layout_file))

cat("  Person data:", basename(person_data_file), "\n")
cat("  Layout file:", basename(layout_file), "\n\n")

# ============================================================================
# Step 2: Read and Parse Layout File
# ============================================================================
cat("Step 2: Parsing layout file...\n")

# Read layout - try different sheet names common in PLFS layouts
library(readxl)

# List available sheets
sheets <- excel_sheets(layout_file)
cat("  Available sheets:", paste(sheets, collapse = ", "), "\n")

# Find person-level layout sheet
person_sheet <- sheets[grepl("person|per|cper|individual", sheets, ignore.case = TRUE)][1]
if (is.na(person_sheet)) {
  person_sheet <- sheets[1]  # Default to first sheet
  cat("  Using first sheet for person layout:", person_sheet, "\n")
} else {
  cat("  Using person sheet:", person_sheet, "\n")
}

# Parse the layout
layout <- parse_layout(layout_file, sheet = person_sheet)
cat("  Layout parsed:", nrow(layout), "variables\n\n")

# Show first few variables
cat("  First 10 variables:\n")
print(layout[1:min(10, nrow(layout)), .(var_name, start, end, width)])
cat("\n")

# ============================================================================
# Step 3: Read Person-Level Data
# ============================================================================
cat("Step 3: Reading person-level microdata...\n")
cat("  This may take a few minutes for large files...\n\n")

# Read the data
persons <- read_microdata(
  data_file = person_data_file,
  layout = layout,
  use_clean_names = TRUE,
  convert_types = TRUE
)

cat("\n  Data dimensions:", nrow(persons), "rows x", ncol(persons), "columns\n")
cat("  Memory usage:", round(object.size(persons) / 1024^2, 1), "MB\n\n")

# Quick inspection
cat("  Column names (first 20):\n")
print(names(persons)[1:min(20, ncol(persons))])
cat("\n")

# ============================================================================
# Step 4: Identify Key Variables
# ============================================================================
cat("Step 4: Identifying key PLFS variables...\n")

# List all column names to help identify variables
all_cols <- names(persons)
cat("\n  All column names:\n")
print(all_cols)
cat("\n")

# Try to auto-detect key variables
detect_var <- function(patterns, cols) {
  for (pat in patterns) {
    matches <- cols[grepl(pat, cols, ignore.case = TRUE)]
    if (length(matches) > 0) return(matches[1])
  }
  return(NA)
}

# Key variable detection
state_var <- detect_var(c("^state$", "state_code", "state"), all_cols)
sector_var <- detect_var(c("^sector$", "rural", "urban"), all_cols)
sex_var <- detect_var(c("^sex$", "gender"), all_cols)
age_var <- detect_var(c("^age$", "person_age"), all_cols)
weight_var <- detect_var(c("mult", "multiplier", "weight", "wgt"), all_cols)
qtr_var <- detect_var(c("no_qtr", "quarter", "qtr"), all_cols)
status_var <- detect_var(c("principal", "status", "activity", "ps_", "ups"), all_cols)
fsu_var <- detect_var(c("fsu", "psu", "first_stage"), all_cols)
stratum_var <- detect_var(c("stratum", "strat"), all_cols)

cat("  Detected variables:\n")
cat("    State:", ifelse(is.na(state_var), "NOT FOUND", state_var), "\n")
cat("    Sector:", ifelse(is.na(sector_var), "NOT FOUND", sector_var), "\n")
cat("    Sex:", ifelse(is.na(sex_var), "NOT FOUND", sex_var), "\n")
cat("    Age:", ifelse(is.na(age_var), "NOT FOUND", age_var), "\n")
cat("    Weight/Mult:", ifelse(is.na(weight_var), "NOT FOUND", weight_var), "\n")
cat("    Quarter:", ifelse(is.na(qtr_var), "NOT FOUND", qtr_var), "\n")
cat("    Activity Status:", ifelse(is.na(status_var), "NOT FOUND", status_var), "\n")
cat("    FSU (cluster):", ifelse(is.na(fsu_var), "NOT FOUND", fsu_var), "\n")
cat("    Stratum:", ifelse(is.na(stratum_var), "NOT FOUND", stratum_var), "\n\n")

# ============================================================================
# Step 5: Data Validation & Summary
# ============================================================================
cat("Step 5: Data validation...\n")

# Check for key variables
if (!is.na(state_var)) {
  cat("  States in data:", length(unique(persons[[state_var]])), "\n")
  cat("  State codes:", paste(head(sort(unique(persons[[state_var]])), 10), collapse = ", "), "...\n")
}

if (!is.na(sex_var)) {
  cat("  Sex distribution:\n")
  print(table(persons[[sex_var]], useNA = "ifany"))
}

if (!is.na(age_var)) {
  cat("  Age range:", min(persons[[age_var]], na.rm = TRUE), "-", 
      max(persons[[age_var]], na.rm = TRUE), "\n")
}

if (!is.na(weight_var)) {
  cat("  Weight range:", min(persons[[weight_var]], na.rm = TRUE), "-", 
      max(persons[[weight_var]], na.rm = TRUE), "\n")
}

if (!is.na(status_var)) {
  cat("  Activity status codes:\n")
  print(table(persons[[status_var]], useNA = "ifany"))
}

cat("\n")

# ============================================================================
# Step 6: Create Survey Design
# ============================================================================
cat("Step 6: Creating survey design with proper weights...\n\n")

# Create PLFS survey design
design <- create_plfs_design(persons, level = "person")

cat("\n  Survey design created successfully!\n")
survey_design_summary(design)
cat("\n")

# ============================================================================
# Step 7: Calculate Labour Force Indicators
# ============================================================================
cat("Step 7: Calculating labour force indicators...\n\n")

# NOTE: PLFS Calendar Year 2024 data has no unemployed in Principal Status (PS)
# but CWS (Current Weekly Status) has unemployed persons (codes 61, 62).
# Using CWS approach for accurate unemployment measurement.

# Overall indicators - using CWS for unemployment
cat("--- Overall Indicators (Age 15+, CWS Approach) ---\n")
overall <- calc_all_indicators(design, approach = "cws")
print(overall)
cat("\n")

# By Sex
cat("--- Indicators by Sex ---\n")
by_sex <- calc_indicators_by_sex(design, approach = "cws")
print(by_sex)
cat("\n")

# By State
cat("--- Indicators by State ---\n")
by_state <- calc_indicators_by_state(design, approach = "cws")
print(by_state)
cat("\n")

# ============================================================================
# Step 8: Export Tables
# ============================================================================
cat("Step 8: Exporting tables...\n")

# Create output directories if they don't exist
dir.create(get_path("tables"), showWarnings = FALSE, recursive = TRUE)
dir.create(get_path("figures"), showWarnings = FALSE, recursive = TRUE)

# Save results as CSV
fwrite(overall, table_path("plfs_overall_indicators.csv"))
fwrite(by_sex, table_path("plfs_indicators_by_sex.csv"))
fwrite(by_state, table_path("plfs_indicators_by_state.csv"))

cat("  Saved: plfs_overall_indicators.csv\n")
cat("  Saved: plfs_indicators_by_sex.csv\n")
cat("  Saved: plfs_indicators_by_state.csv\n\n")

# ============================================================================
# Step 9: Save Processed Data as Parquet
# ============================================================================
cat("Step 9: Saving processed data as Parquet...\n")

save_as_parquet(persons, "plfs_2024_persons")
cat("  Saved to data/processed/plfs_2024_persons.parquet\n")
cat("  (Future loads will be much faster using load_from_parquet())\n\n")

# ============================================================================
# Step 10: Summary
# ============================================================================
cat("========================================\n")
cat("Analysis Complete!\n")
cat("========================================\n\n")

cat("Key Results:\n")
cat("-----------\n")
cat(sprintf("Total observations: %s\n", format(nrow(persons), big.mark = ",")))
cat(sprintf("Estimated population (sum of weights): %s\n", 
            format(round(sum(weights(design))), big.mark = ",")))
cat("\n")

cat("Labour Force Indicators (Age 15+, Current Weekly Status):\n")
cat(sprintf("  LFPR: %.1f%%\n", overall$lfpr))
cat(sprintf("  WPR:  %.1f%%\n", overall$wpr))
cat(sprintf("  UR:   %.1f%%\n", overall$ur))
cat("\n")

cat("Output files:\n")
cat("  - outputs/tables/plfs_overall_indicators.csv\n")
cat("  - outputs/tables/plfs_indicators_by_sex.csv\n")
cat("  - outputs/tables/plfs_indicators_by_state.csv\n")
cat("  - data/processed/plfs_2024_persons.parquet\n")
cat("\n")

cat("Next steps:\n")
cat("  1. Review the indicator tables in outputs/tables/\n")
cat("  2. Run specific analyses using the survey design object 'design'\n")
cat("  3. Create visualizations using plot_* functions\n")
cat("  4. Generate reports using Quarto templates in analysis/templates/\n")
cat("\n")
