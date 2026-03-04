# ============================================================================
# test-config.R - Tests for Configuration Module
# ============================================================================
# These tests work without config.yaml (uses config.yaml.example fallback)

test_that("Project root is found correctly", {
  source_config()
  expect_true(dir.exists(PROJECT_ROOT))
  expect_true(
    file.exists(file.path(PROJECT_ROOT, "config.yaml")) ||
    file.exists(file.path(PROJECT_ROOT, "config.yaml.example"))
  )
})

test_that("Path helpers work correctly", {
  source_config()

  # Test that path functions return character strings
  expect_type(get_path("raw"), "character")
  expect_type(get_path("processed"), "character")
  expect_type(get_path("codebooks"), "character")
  expect_type(get_path("tables"), "character")
  expect_type(get_path("figures"), "character")

  # Bad path type should error
  expect_error(get_path("nonexistent"), "Unknown path type")
})

test_that("Configuration loads correctly", {
  source_config()

  # Check CONFIG is a list
  expect_type(CONFIG, "list")

  # Check required sections exist
  expect_true("api" %in% names(CONFIG) || "settings" %in% names(CONFIG))
  expect_true("paths" %in% names(CONFIG))
})

test_that("Codebook loaders work", {
  source_config()

  # Test that codebook paths are returned
  expect_type(codebook_path("state_codes.csv"), "character")
  expect_type(codebook_path("nic_2008.csv"), "character")
})

# ============================================================================
# Variable Detection Tests
# ============================================================================

test_that("detect_variable finds exact matches", {
  source_config()

  test_data <- create_plfs_fixture(10)
  expect_equal(detect_variable(test_data, "weight"), "MULT")
  expect_equal(detect_variable(test_data, "quarter"), "NO_QTR")
  expect_equal(detect_variable(test_data, "cluster"), "FSU")
  expect_equal(detect_variable(test_data, "sex"), "Sex")
  expect_equal(detect_variable(test_data, "age"), "Age")
  expect_equal(detect_variable(test_data, "sector"), "Sector")
})

test_that("detect_variable handles alternative column names", {
  source_config()

  # Simulate a dataset with alternative naming
  alt_data <- data.table(
    Multiplier = 100,
    QTR = 1,
    PSU = 101,
    Gender = 1,
    Person_Age = 25,
    Rural_Urban = 1
  )

  expect_equal(detect_variable(alt_data, "weight"), "Multiplier")
  expect_equal(detect_variable(alt_data, "cluster"), "PSU")
  expect_equal(detect_variable(alt_data, "sex"), "Gender")
  expect_equal(detect_variable(alt_data, "age"), "Person_Age")
  expect_equal(detect_variable(alt_data, "sector"), "Rural_Urban")
})

test_that("detect_variable returns NA for missing variables", {
  source_config()

  empty_data <- data.table(x = 1, y = 2)
  expect_true(is.na(detect_variable(empty_data, "weight")))
  expect_true(is.na(detect_variable(empty_data, "age")))
})

test_that("detect_variables returns named vector", {
  source_config()

  test_data <- create_plfs_fixture(10)
  result <- detect_variables(test_data, c("weight", "age", "sex"))

  expect_type(result, "character")
  expect_equal(names(result), c("weight", "age", "sex"))
  expect_equal(result[["weight"]], "MULT")
  expect_equal(result[["age"]], "Age")
  expect_equal(result[["sex"]], "Sex")
})
