# ============================================================================
# helper-fixtures.R - Shared Test Fixtures for IndiaData Tests
# ============================================================================
# This file is auto-loaded by testthat before any test file.
# It provides reusable synthetic PLFS data for testing.

suppressPackageStartupMessages({
  library(data.table)
})

#' Create a realistic synthetic PLFS person-level dataset
#' Contains all key variables with correct codes for testing.
#'
#' @param n Number of rows (default: 20)
#' @return data.table with PLFS-like columns
create_plfs_fixture <- function(n = 20) {
  set.seed(42)

  # Activity status codes: mix of employed, unemployed, NILF
  status_pool <- c(
    11, 12, 21, 31, 41, 51,  # employed
    61, 62,                   # unemployed
    91, 92, 93, 94, 95        # NILF
  )
  status_weights <- c(
    0.10, 0.08, 0.05, 0.25, 0.10, 0.05,
    0.04, 0.01,
    0.10, 0.08, 0.05, 0.05, 0.04
  )

  data.table(
    MULT = sample(100:500, n, replace = TRUE),
    NO_QTR = sample(c(1, 2, 4), n, replace = TRUE),
    State_Ut_Code = sample(1:36, n, replace = TRUE),
    Sector = sample(1:2, n, replace = TRUE),
    Stratum = sample(1:4, n, replace = TRUE),
    Sub_Stratum = sample(1:2, n, replace = TRUE),
    FSU = sample(100:200, n, replace = TRUE),
    Age = sample(15:65, n, replace = TRUE),
    Sex = sample(1:2, n, replace = TRUE),
    General_Educaion_Level = sample(1:13, n, replace = TRUE),
    Current_Weekly_Status_CWS = sample(status_pool, n, replace = TRUE, prob = status_weights),
    Status_Code = sample(status_pool, n, replace = TRUE, prob = status_weights),
    Industry_Code_NIC = sample(c(100, 500, 1500, 4500, 6000, 8500), n, replace = TRUE),
    Occupation_Code_NCO = sample(c(110, 210, 310, 520, 830, 920), n, replace = TRUE),
    NSS = sample(1:2, n, replace = TRUE)
  )
}

#' Source config modules (with fallback to config.yaml.example)
#' Call this in tests that need the config loaded.
source_config <- function() {
  # Ensure we're in the project root
  if (file.exists("R/01_config.R")) {
    source("R/01_config.R")
  } else if (file.exists(here::here("R/01_config.R"))) {
    source(here::here("R/01_config.R"))
  } else {
    stop("Cannot find R/01_config.R - are you in the project root?")
  }
}
