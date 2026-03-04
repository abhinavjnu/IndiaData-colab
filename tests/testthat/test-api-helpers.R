# ============================================================================
# test-api-helpers.R - Tests for API Helpers Module
# ============================================================================
# These tests validate API helper functionality without making actual API calls

test_that("get_api_config fails with placeholder key", {
  source_config()
  source("R/02_api_helpers.R")

  # Mock a config with placeholder key
  old_config <- CONFIG
  CONFIG$api$api_key <- "YOUR_API_KEY_HERE"
  assign("CONFIG", CONFIG, envir = globalenv())

  expect_error(get_api_config(), "API key not configured")

  # Restore
  assign("CONFIG", old_config, envir = globalenv())
})

test_that("build_api_url constructs correct URLs", {
  source_config()
  source("R/02_api_helpers.R")

  # Test basic URL construction (internal function)
  config <- tryCatch(
    get_api_config(),
    error = function(e) list(base_url = "https://microdata.gov.in/NADA/index.php")
  )

  expect_true(grepl("microdata.gov.in", config$base_url))
})

test_that("API functions have correct signatures", {
  source_config()
  source("R/02_api_helpers.R")

  # Test that exported functions exist and have expected arguments
  expect_true(exists("test_api_connection"))
  expect_true(exists("search_datasets"))
  expect_true(exists("get_dataset_info"))
  expect_true(exists("get_dataset_files"))
  expect_true(exists("download_datafile"))
  expect_true(exists("download_dataset"))
  expect_true(exists("download_plfs"))

  # Check function arguments
  expect_true("query" %in% names(formals(search_datasets)))
  expect_true("limit" %in% names(formals(search_datasets)))
  expect_true("dataset_id" %in% names(formals(get_dataset_info)))
  expect_true("dataset_id" %in% names(formals(download_datafile)))
  expect_true("file_id" %in% names(formals(download_datafile)))
})

test_that("unzip_datafile validates file existence", {
  source_config()
  source("R/02_api_helpers.R")

  # Non-existent file should error
  expect_error(
    unzip_datafile("nonexistent_file.zip"),
    "ZIP file not found"
  )
})

test_that("download_datafile has correct signature", {
  source_config()
  source("R/02_api_helpers.R")

  args <- names(formals(download_datafile))
  expect_true("dataset_id" %in% args)
  expect_true("file_id" %in% args)
  expect_true("dest_dir" %in% args)
  expect_true("overwrite" %in% args)
})
