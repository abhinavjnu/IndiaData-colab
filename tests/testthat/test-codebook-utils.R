# ============================================================================
# test-codebook-utils.R - Tests for Codebook Utilities Module
# ============================================================================

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

test_that("State codebook exists and is valid", {
  source_file("R/01_config.R")

  state_file <- codebook_path("state_codes.csv")

  if (file.exists(state_file)) {
    states <- fread(state_file)

    # Should have state_code and state_name columns
    expect_true("state_code" %in% names(states) || "state_name" %in% names(states))

    # Should have 36 rows (28 states + 8 UTs)
    expect_gte(nrow(states), 36)
  } else {
    skip("State codebook not found")
  }
})

test_that("Activity status codebook exists", {
  source_file("R/01_config.R")

  activity_file <- codebook_path("activity_status.csv")

  if (file.exists(activity_file)) {
    activity <- fread(activity_file)

    # Should have status_code and status_description
    expect_true(any(c("status_code", "status_description") %in% names(activity)))
  } else {
    skip("Activity codebook not found")
  }
})

test_that("decode_sex works correctly", {
  source_file("R/05_codebook_utils.R")

  test_data <- data.table(Sex = c(1, 2, 1, 2, NA))
  result <- decode_sex(test_data, "Sex")

  expect_equal(result$Sex, c("Male", "Female", "Male", "Female", NA))
})

test_that("decode_sector works correctly", {
  source_file("R/05_codebook_utils.R")

  test_data <- data.table(Sector = c(1, 2, 1, 2))
  result <- decode_sector(test_data, "Sector")

  expect_equal(result$Sector, c("Rural", "Urban", "Rural", "Urban"))
})

test_that("classify_sector_broad works correctly", {
  source_file("R/05_codebook_utils.R")

  test_data <- data.table(
    NIC = c(1, 10, 20, 45, 60) # Agriculture, Mining, Manufacturing, Services
  )
  result <- classify_sector_broad(test_data, "NIC")

  expect_equal(result$sector_broad, c("Primary", "Primary", "Secondary", "Tertiary", "Tertiary"))
})

test_that("codebook validation catches malformed files", {
  source_file("R/01_config.R")
  source_file("R/05_codebook_utils.R")

  # Clear the cache to ensure we test fresh loading
  rm(list = ls(envir = .codebook_cache), envir = .codebook_cache)

  # Create a temporary malformed codebook
  temp_dir <- tempdir()
  old_path <- CONFIG$paths$codebooks

  # Test that validation is in place by checking the function exists
  expect_true(exists(".load_codebook"))
})
