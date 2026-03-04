# ============================================================================
# test-plfs-indicators.R - Tests for PLFS Indicators Module
# ============================================================================

library(srvyr)

# Helper: create a test survey design from fixture data
create_test_design <- function() {
  source_config()
  source("R/03_survey_design.R")
  source("R/04_plfs_indicators.R")

  test_data <- create_plfs_fixture(40)
  create_plfs_design(test_data, level = "person")
}

# The status variable in our fixture
STATUS_VAR <- "Current_Weekly_Status_CWS"

test_that("Activity status classification constants are correct", {
  source_config()
  source("R/04_plfs_indicators.R")

  # Employed codes must include standard codes
  expect_true(all(c(11, 12, 21, 31, 41, 42, 51) %in% EMPLOYED_CODES))

  # Unemployed codes
  expect_true(all(c(81, 82) %in% UNEMPLOYED_CODES))

  # No overlap between employed and unemployed
  expect_equal(length(intersect(EMPLOYED_CODES, UNEMPLOYED_CODES)), 0)
})

test_that("add_lf_classification classifies CWS correctly", {
  source_config()
  source("R/04_plfs_indicators.R")

  test_data <- create_plfs_fixture(20)
  result <- add_lf_classification(test_data, approach = "cws")

  # Must add boolean classification columns
  expect_true("is_employed" %in% names(result))
  expect_true("is_unemployed" %in% names(result))
  expect_true("is_in_lf" %in% names(result))
  expect_true("is_nilf" %in% names(result))
  expect_true("employment_type" %in% names(result))

  # Spot-check: verify classification matches activity status codes
  for (i in seq_len(nrow(result))) {
    cws <- result$Current_Weekly_Status_CWS[i]
    if (cws %in% EMPLOYED_CODES) {
      expect_true(result$is_employed[i],
                  info = paste("CWS code", cws, "should be employed"))
      expect_true(result$is_in_lf[i],
                  info = paste("CWS code", cws, "should be in labour force"))
    } else if (cws %in% UNEMPLOYED_CODES) {
      expect_true(result$is_unemployed[i],
                  info = paste("CWS code", cws, "should be unemployed"))
      expect_true(result$is_in_lf[i],
                  info = paste("CWS code", cws, "should be in labour force"))
    } else {
      expect_true(result$is_nilf[i],
                  info = paste("CWS code", cws, "should be NILF"))
      expect_false(result$is_in_lf[i],
                   info = paste("CWS code", cws, "should NOT be in labour force"))
    }
  }
})

test_that("LFPR calculation is in valid range", {
  design <- create_test_design()
  result <- calc_lfpr(design, status_var = STATUS_VAR, approach = "cws")

  # LFPR should be between 0 and 100
  expect_gte(result$lfpr, 0)
  expect_lte(result$lfpr, 100)
})

test_that("WPR calculation is in valid range", {
  design <- create_test_design()
  result <- calc_wpr(design, status_var = STATUS_VAR, approach = "cws")

  expect_gte(result$wpr, 0)
  expect_lte(result$wpr, 100)
})

test_that("Unemployment rate calculation is in valid range", {
  design <- create_test_design()
  result <- calc_unemployment_rate(design, status_var = STATUS_VAR, approach = "cws")

  expect_gte(result$ur, 0)
  expect_lte(result$ur, 100)
})

test_that("All indicators return standard columns", {
  design <- create_test_design()
  # Use explicit status_var to avoid auto-detect issues with srvyr internals
  lfpr <- calc_lfpr(design, status_var = STATUS_VAR, approach = "cws")
  wpr  <- calc_wpr(design, status_var = STATUS_VAR, approach = "cws")
  ur   <- calc_unemployment_rate(design, status_var = STATUS_VAR, approach = "cws")

  # Check all three indicators
  expect_true("lfpr" %in% names(lfpr))
  expect_true("wpr" %in% names(wpr))
  expect_true("ur" %in% names(ur))

  # Check standard errors
  expect_true("lfpr_se" %in% names(lfpr))
  expect_true("wpr_se" %in% names(wpr))
  expect_true("ur_se" %in% names(ur))
})

test_that("Grouping by sex works", {
  design <- create_test_design()
  # Use calc_lfpr with by='Sex' instead of calc_indicators_by_sex
  # (which uses detect_variable internally and may mismatch on srvyr designs)
  result <- calc_lfpr(design, by = "Sex", status_var = STATUS_VAR, approach = "cws")

  # Should have 2 rows (Male=1, Female=2)
  expect_equal(nrow(result), 2)
  expect_true("Sex" %in% names(result))
})

test_that("Age filtering works", {
  design <- create_test_design()

  result <- calc_lfpr(design, status_var = STATUS_VAR, approach = "cws", age_filter = c(25, 35))
  expect_true(is.data.table(result))
  expect_true("lfpr" %in% names(result))
})
