# ============================================================================
# testthat.R - Test Runner for IndiaData
# ============================================================================
# Run all tests with: testthat::test_dir("tests/testthat")
# Or in RStudio: Ctrl+Shift+T (if Build > Configure Build Tools > Test package)

library(testthat)
library(here)

# Set working directory to project root
setwd(here::here())

# Run tests
test_check("IndiaData")
