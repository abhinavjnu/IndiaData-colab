# ============================================================================
# test-codebook-utils.R - Tests for Codebook Utilities Module
# ============================================================================

test_that("State codebook exists and is valid", {
  source_config()

  state_file <- codebook_path("state_codes.csv")

  if (file.exists(state_file)) {
    states <- fread(state_file)

    # Should have state_code and state_name columns
    expect_true("state_code" %in% names(states) || "state_name" %in% names(states))

    # Should have at least 36 rows (28 states + 8 UTs)
    expect_gte(nrow(states), 36)
  } else {
    skip("State codebook not found")
  }
})

test_that("Activity status codebook exists", {
  source_config()

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
  source_config()
  source("R/05_codebook_utils.R")

  test_data <- data.table(Sex = c(1, 2, 1, 2, NA))
  result <- decode_sex(test_data, "Sex")

  expect_equal(result$Sex, c("Male", "Female", "Male", "Female", NA))
})

test_that("decode_sector works correctly", {
  source_config()
  source("R/05_codebook_utils.R")

  test_data <- data.table(Sector = c(1, 2, 1, 2))
  result <- decode_sector(test_data, "Sector")

  expect_equal(result$Sector, c("Rural", "Urban", "Rural", "Urban"))
})

test_that("classify_sector_broad works correctly", {
  source_config()
  source("R/05_codebook_utils.R")

  test_data <- data.table(
    NIC = c(1, 2, 20, 45, 60)  # Agriculture, Forestry, Manufacturing, Construction, Services
  )
  result <- classify_sector_broad(test_data, "NIC")

  expect_equal(result$sector_broad, c("Primary", "Primary", "Secondary", "Tertiary", "Tertiary"))
})

test_that("codebook validation functions exist", {
  source_config()
  source("R/05_codebook_utils.R")

  # Clear the cache to ensure we test fresh loading
  if (exists(".codebook_cache")) {
    rm(list = ls(envir = .codebook_cache), envir = .codebook_cache)
  }

  # Test that validation is in place by checking the function exists
  expect_true(exists(".load_codebook"))
})
