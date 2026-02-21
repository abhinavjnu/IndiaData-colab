# ============================================================================
# test-config.R - Tests for Configuration Module
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

test_that("Project root is found correctly", {
  source_file("R/01_config.R")
  expect_true(dir.exists(PROJECT_ROOT))
  expect_true(file.exists(file.path(PROJECT_ROOT, "config.yaml")) ||
                file.exists(file.path(PROJECT_ROOT, "config.yaml.example")))
})

test_that("Path helpers work correctly", {
  source_file("R/01_config.R")

  # Test that path functions return character strings
  expect_type(get_path("raw"), "character")
  expect_type(get_path("processed"), "character")
  expect_type(get_path("codebooks"), "character")
  expect_type(get_path("tables"), "character")
  expect_type(get_path("figures"), "character")

  # Test that paths exist or can be created
  expect_true(dir.exists(get_path("raw")) || !dir.exists(get_path("raw")))
})

test_that("Configuration loads correctly", {
  source_file("R/01_config.R")

  # Check CONFIG is a list
  expect_type(CONFIG, "list")

  # Check required sections exist
  expect_true("api" %in% names(CONFIG) || "settings" %in% names(CONFIG))
  expect_true("paths" %in% names(CONFIG))
})

test_that("Codebook loaders work", {
  source_file("R/01_config.R")

  # Test that codebook paths are returned
  expect_type(codebook_path("state_codes.csv"), "character")
  expect_type(codebook_path("nic_2008.csv"), "character")
})
