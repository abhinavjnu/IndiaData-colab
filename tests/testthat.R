# ============================================================================
# testthat.R - Test Runner for IndiaData
# ============================================================================
# Run all tests with: Rscript -e 'testthat::test_dir("tests/testthat")'
# Or: Rscript tests/testthat.R

library(testthat)
library(here)

# Set working directory to project root
setwd(here::here())

# Run tests using test_dir (this is NOT an R package, so test_check won't work)
test_dir("tests/testthat", reporter = "summary")
