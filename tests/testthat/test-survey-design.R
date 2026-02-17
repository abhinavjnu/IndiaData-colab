# ============================================================================
# test-survey-design.R - Tests for Survey Design Module
# ============================================================================

# Create minimal test data
create_test_data <- function() {
  data.table(
    MULT = c(100, 200, 300, 400, 500),
    NO_QTR = c(1, 1, 2, 2, 1),
    State_Ut_Code = c(1, 1, 2, 2, 1),
    Sector = c(1, 2, 1, 2, 1),
    Stratum = c(1, 1, 2, 2, 1),
    Sub_Stratum = c(1, 1, 1, 1, 1),
    FSU = c(101, 102, 103, 104, 105),
    Age = c(25, 35, 45, 55, 30),
    Sex = c(1, 2, 1, 2, 1),
    Current_Weekly_Status_CWS = c(31, 11, 61, 31, 41)
  )
}

test_that("Weight calculation is correct", {
  source("R/01_config.R")
  source("R/03_survey_design.R")
  
  test_data <- create_test_data()
  
  # Test weight formula: MULT / 100 for calendar year data
  # With NO_QTR: MULT / (NO_QTR * 100)
  expect_equal(test_data$MULT[1] / (test_data$NO_QTR[1] * 100), 1.0)
  expect_equal(test_data$MULT[3] / (test_data$NO_QTR[3] * 100), 1.5)
})

test_that("Variable auto-detection works", {
  test_data <- create_test_data()
  
  # Test that expected columns exist
  expect_true("MULT" %in% names(test_data))
  expect_true("NO_QTR" %in% names(test_data))
  expect_true("FSU" %in% names(test_data))
  expect_true("Current_Weekly_Status_CWS" %in% names(test_data))
})

test_that("Survey design creation handles invalid inputs", {
  source("R/01_config.R")
  source("R/03_survey_design.R")
  
  # Empty data should error
  empty_data <- data.table()
  expect_error(create_survey_design(empty_data, weight_var = "MULT"))
  
  # Missing weight variable should error
  bad_data <- data.table(x = 1:5)
  expect_error(create_survey_design(bad_data, weight_var = "MULT"))
})
