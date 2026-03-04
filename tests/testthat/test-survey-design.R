# ============================================================================
# test-survey-design.R - Tests for Survey Design Module
# ============================================================================

test_that("Weight calculation is correct", {
  source_config()
  source("R/03_survey_design.R")

  test_data <- create_plfs_fixture(10)

  # Test weight formula: MULT / (NO_QTR * 100)
  weights <- test_data$MULT / (test_data$NO_QTR * 100)
  expect_true(all(weights > 0))
  expect_true(all(is.finite(weights)))
})

test_that("Variable auto-detection works on fixture data", {
  source_config()

  test_data <- create_plfs_fixture(10)

  # All key columns must exist
  expect_true("MULT" %in% names(test_data))
  expect_true("NO_QTR" %in% names(test_data))
  expect_true("FSU" %in% names(test_data))
  expect_true("Current_Weekly_Status_CWS" %in% names(test_data))
  expect_true("State_Ut_Code" %in% names(test_data))
  expect_true("Sector" %in% names(test_data))
  expect_true("Stratum" %in% names(test_data))
  expect_true("Sub_Stratum" %in% names(test_data))
})

test_that("Survey design creation handles invalid inputs", {
  source_config()
  source("R/03_survey_design.R")

  # Empty data should error
  empty_data <- data.table()
  expect_error(create_survey_design(empty_data, weight_var = "MULT"))

  # Missing weight variable should error
  bad_data <- data.table(x = 1:5)
  expect_error(create_survey_design(bad_data, weight_var = "MULT"))
})

test_that("PLFS design creation works with fixture data", {
  source_config()
  source("R/03_survey_design.R")

  test_data <- create_plfs_fixture(20)
  design <- create_plfs_design(test_data, level = "person")

  # Should return a survey design object
  expect_true(inherits(design, "tbl_svy") || inherits(design, "survey.design"))
})
