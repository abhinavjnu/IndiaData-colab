# ============================================================================
# parse_plfs_2023-24.R - Parse PLFS 2023-24 Microdata
# ============================================================================
# This script reads the PLFS 2023-24 raw data files and creates
# analysis-ready Parquet files.

# Set working directory to project root
setwd("D:/Opencode/Data Analysis/IndiaData")

# Load required functions
source("R/01_config.R")
source("R/02_read_microdata.R")
source("R/03_survey_design.R")
source("R/04_plfs_indicators.R")
source("R/05_codebook_utils.R")

cat("\n===========================================\n")
cat("PLFS 2023-24 Data Processing\n")
cat("===========================================\n\n")

# Define paths
data_dir <- "PLFS/2023-24"
raw_dir <- file.path(data_dir, "raw")
layout_file <- file.path(data_dir, "Data_LayoutPLFS_2023-24.xlsx")

# Check files exist
cat("Checking files...\n")
cat("  Layout file:", file.exists(layout_file), "\n")
cat("  Person data:", file.exists(file.path(raw_dir, "CPERV1.TXT")), "\n")
cat("  Household data:", file.exists(file.path(raw_dir, "CHHV1.TXT")), "\n")

if (!file.exists(layout_file)) {
    stop("Layout file not found!")
}

# ============================================================================
# Parse Person-Level Data
# ============================================================================
cat("\n--- Parsing Person-Level Data ---\n")

persons <- read_microdata(
    data_file = file.path(raw_dir, "CPERV1.TXT"),
    layout_file = layout_file
)

cat(sprintf(
    "\nPerson data: %s rows x %d columns\n",
    format(nrow(persons), big.mark = ","), ncol(persons)
))

# Save to Parquet
persons_parquet <- "data/processed/plfs_2023-24_persons.parquet"
save_microdata(persons, persons_parquet)
cat(sprintf("Saved to: %s\n", persons_parquet))

# ============================================================================
# Parse Household-Level Data
# ============================================================================
cat("\n--- Parsing Household-Level Data ---\n")

households <- read_microdata(
    data_file = file.path(raw_dir, "CHHV1.TXT"),
    layout_file = layout_file
)

cat(sprintf(
    "\nHousehold data: %s rows x %d columns\n",
    format(nrow(households), big.mark = ","), ncol(households)
))

# Save to Parquet
hh_parquet <- "data/processed/plfs_2023-24_households.parquet"
save_microdata(households, hh_parquet)
cat(sprintf("Saved to: %s\n", hh_parquet))

# ============================================================================
# Summary Statistics
# ============================================================================
cat("\n===========================================\n")
cat("Processing Complete!\n")
cat("===========================================\n\n")

cat("Files created:\n")
cat(sprintf(
    "  - %s (%s MB)\n", persons_parquet,
    round(file.size(persons_parquet) / 1024^2, 1)
))
cat(sprintf(
    "  - %s (%s MB)\n", hh_parquet,
    round(file.size(hh_parquet) / 1024^2, 1)
))

cat("\nNext steps:\n")
cat("  1. Run: source('R/03_survey_design.R')\n")
cat("  2. Create design: design <- create_plfs_design(persons)\n")
cat("  3. Calculate indicators: calc_all_indicators(design)\n")
