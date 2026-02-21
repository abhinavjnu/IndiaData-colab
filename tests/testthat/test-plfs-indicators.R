# ============================================================================
# test-plfs-indicators.R - Tests for PLFS Indicators Module
# ============================================================================

library(srvyr)

# Helper to source files from project root or test directory
source_file <- function(path) {
  if (file.exists(path)) {
    source(path)
  } else if (file.exists(file.path("../..", path))) {
    source(file.path("../..", path))
  } else {
    stop(sprintf("Could not find %s. Working directory: %s", path, getwd()))
  }
}

# Create test survey design
create_test_design <- function() {
  source_file("R/01_config.R")
  source_file("R/03_survey_design.R")
  source_file("R/04_plfs_indicators.R")

  test_data <- data.table(
    MULT = c(100, 100, 100, 100, 100, 100, 100, 100),
    NO_QTR = rep(1, 8),
    State_Ut_Code = c(1, 1, 1, 1, 2, 2, 2, 2),
    Sector = c(1, 1, 2, 2, 1, 1, 2, 2),
    Stratum = c(1, 1, 1, 1, 2, 2, 2, 2),
    FSU = c(101, 102, 103, 104, 105, 106, 107, 108),
    Age = c(25, 30, 35, 40, 25, 30, 35, 40),
    Sex = c(1, 2, 1, 2, 1, 2, 1, 2),
    # Activity status: 31=employed, 61=unemployed
    Current_Weekly_Status_CWS = c(31, 31, 61, 31, 31, 61, 31, 31)
  )

  create_plfs_design(test_data, level = "person")
}

test_that("Activity status classification is correct", {
  source_file("R/01_config.R")
  source_file("R/04_plfs_indicators.R")

  # Test employed codes
  expect_true(all(c(11, 12, 21, 31, 41, 42, 51) %in% EMPLOYED_CODES))

  # Test unemployed codes
  expect_true(all(c(61, 62) %in% UNEMPLOYED_CODES))

  # Test labour force codes
  lf_codes <- c(EMPLOYED_CODES, UNEMPLOYED_CODES)
  expect_true(all(c(31, 61) %in% lf_codes))
})

test_that("LFPR calculation is in valid range", {
  design <- create_test_design()

  result <- calc_lfpr(design)

  # LFPR should be between 0 and 100
  expect_gte(result$lfpr, 0)
  expect_lte(result$lfpr, 100)

  # With our test data (6 employed + 2 unemployed out of 8), LFPR = 100%
  expect_equal(result$lfpr, 100, tolerance = 1)
})

test_that("Unemployment rate calculation is in valid range", {
  design <- create_test_design()

  result <- calc_unemployment_rate(design)

  # UR should be between 0 and 100
  expect_gte(result$ur, 0)
  expect_lte(result$ur, 100)

  # With our test data (2 unemployed / 8 in LF), UR = 25%
  expect_equal(result$ur, 25, tolerance = 1)
})

test_that("Grouping by sex works correctly", {
  design <- create_test_design()

  result <- calc_indicators_by_sex(design, approach = "cws")

  # Should have 2 rows (Male, Female)
  expect_equal(nrow(result), 2)

  # Check that Sex column exists
  expect_true("Sex" %in% names(result))
})

test_that("All indicators are calculated", {
  design <- create_test_design()

  result <- calc_all_indicators(design, approach = "cws")

  # Check that all three indicators are present
  expect_true("lfpr" %in% names(result))
  expect_true("wpr" %in% names(result))
  expect_true("ur" %in% names(result))

  # Check standard errors
  expect_true("lfpr_se" %in% names(result))
  expect_true("wpr_se" %in% names(result))
  expect_true("ur_se" %in% names(result))
})

test_that("Age filtering works", {
  design <- create_test_design()

  # Filter to specific age range
  result <- calc_lfpr(design, age_filter = c(25, 35))

  # Should still return a result
  expect_true(is.data.table(result))
  expect_true("lfpr" %in% names(result))
})
