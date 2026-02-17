# ============================================================================
# 00_setup.R - Package Installation Script
# ============================================================================
# Run this script ONCE to install all required packages.
# After running, you don't need to run it again unless you reinstall R.
#
# Usage: source("R/00_setup.R")
# ============================================================================

cat("=== India Microdata Analysis Setup ===\n\n")

# List of required packages
packages <- c(
  # Data manipulation
  "data.table",    # Fast data processing (essential for large survey files)
  "arrow",         # Parquet file support (efficient storage)
  "readxl",        # Read Excel files (for Data_Layout.xlsx)
  "janitor",       # Clean column names
  

  # Survey analysis
  "survey",        # Core survey statistics with proper weighting
  "srvyr",         # Tidyverse-friendly wrapper for survey package
  
  # Econometrics
  "fixest",        # Fast fixed-effects regression
  
  # Tables and output
  "modelsummary",  # Publication-quality regression tables
  "gt",            # Beautiful tables (HTML, Word, LaTeX)
  "flextable",     # Word-compatible tables
  "officer",       # Word document creation
  
  # Visualization
  "ggplot2",       # Grammar of graphics
  "scales",        # Axis formatting
  "patchwork",     # Combine multiple plots
  
  # API and web

  "httr2",         # Modern HTTP requests (for microdata.gov.in API)
  "jsonlite",      # JSON parsing
  
  # Configuration and utilities
  "yaml",          # Read config.yaml
  "here",          # Project-relative paths
  "fs",            # File system operations
  "progress",      # Progress bars for long operations
  
  # Reporting
  "quarto",        # Document generation
  "knitr",         # Knitting documents
  "rmarkdown"      # R Markdown support
)

# Function to install packages if not already installed
install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("Installing: ", pkg, "\n"))
    install.packages(pkg, repos = "https://cloud.r-project.org/", quiet = TRUE)
  } else {
    cat(paste0("Already installed: ", pkg, "\n"))
  }
}

# Install all packages
cat("Checking and installing packages...\n\n")
invisible(lapply(packages, install_if_missing))

# Verify installation
cat("\n\n=== Verification ===\n")
installed <- sapply(packages, requireNamespace, quietly = TRUE)

if (all(installed)) {
  cat("\n SUCCESS! All packages installed correctly.\n")
  cat("\nNext step: In your analysis scripts, start with:\n")
  cat('  source("R/01_config.R")\n\n')
} else {
  failed <- packages[!installed]
  cat("\n WARNING: Some packages failed to install:\n")
  cat(paste0("  - ", failed, "\n"))
  cat("\nTry installing them manually with:\n")
  cat(paste0('  install.packages("', failed, '")\n'))
}

# Print package versions for reproducibility
cat("\n=== Installed Package Versions ===\n")
for (pkg in packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    ver <- as.character(packageVersion(pkg))
    cat(sprintf("%-15s %s\n", pkg, ver))
  }
}

cat("\n=== Setup Complete ===\n")
