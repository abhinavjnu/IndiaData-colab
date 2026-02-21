# ============================================================================
# 01_config.R - Configuration Loader
# ============================================================================
# Source this file at the start of every analysis script.
# It loads the configuration and sets up the environment.
#
# To run: source("R/01_config.R")
# ============================================================================

# Load required packages
suppressPackageStartupMessages({
  library(data.table)
  library(yaml)
  library(here)
  library(fs)
})

# ============================================================================
# Load Configuration
# ============================================================================

# Find project root (where config.yaml is)
find_project_root <- function() {
  # Try 'here' package first (works with .Rproj)
  if (file.exists(here::here("config.yaml"))) {
    return(here::here())
  }

  # Also check for config.yaml.example (for CI/fresh clones)
  if (file.exists(here::here("config.yaml.example"))) {
    return(here::here())
  }

  # Fallback: search upward from current directory
  current <- getwd()
  while (current != dirname(current)) {
    if (file.exists(file.path(current, "config.yaml"))) {
      return(current)
    }
    if (file.exists(file.path(current, "config.yaml.example"))) {
      return(current)
    }
    current <- dirname(current)
  }
  stop("Could not find config.yaml or config.yaml.example. Are you in the IndiaData project?")
}

# Set project root
PROJECT_ROOT <- find_project_root()
setwd(PROJECT_ROOT)

# Load config
# Use example config if main config is missing (for CI/testing)
config_file <- file.path(PROJECT_ROOT, "config.yaml")
if (!file.exists(config_file)) {
  config_file <- file.path(PROJECT_ROOT, "config.yaml.example")
  if (file.exists(config_file)) {
    message("Notice: Using config.yaml.example (config.yaml not found)")
  }
}

CONFIG <- yaml::read_yaml(config_file)

# ============================================================================
# Path Helpers
# ============================================================================

#' Get full path to a project directory
#' @param type One of: "raw", "processed", "codebooks", "tables", "figures"
#' @return Full path to the directory
get_path <- function(type) {
  paths <- list(
    raw = CONFIG$paths$raw_data,
    processed = CONFIG$paths$processed_data,
    codebooks = CONFIG$paths$codebooks,
    tables = CONFIG$paths$tables,
    figures = CONFIG$paths$figures
  )

  if (!type %in% names(paths)) {
    stop(paste("Unknown path type:", type,
               "\nValid types:", paste(names(paths), collapse = ", ")))
  }

  file.path(PROJECT_ROOT, paths[[type]])
}

#' Get path to a raw data file
#' @param filename Name of the file
#' @return Full path
raw_path <- function(filename) {
  file.path(get_path("raw"), filename)
}

#' Get path to a processed data file
#' @param filename Name of the file
#' @return Full path
processed_path <- function(filename) {
  file.path(get_path("processed"), filename)
}

#' Get path to a codebook file
#' @param filename Name of the file
#' @return Full path
codebook_path <- function(filename) {
  file.path(get_path("codebooks"), filename)
}

#' Get path for output table
#' @param filename Name of the file
#' @return Full path
table_path <- function(filename) {
  file.path(get_path("tables"), filename)
}

#' Get path for output figure
#' @param filename Name of the file
#' @return Full path
figure_path <- function(filename) {
  file.path(get_path("figures"), filename)
}

# ============================================================================
# API Configuration
# ============================================================================

#' Get API configuration
#' @return List with base_url and api_key
get_api_config <- function() {
  list(
    base_url = CONFIG$api$base_url,
    api_key = CONFIG$api$api_key
  )
}

# ============================================================================
# Survey Settings
# ============================================================================

#' Get settings for a specific survey
#' @param survey Survey name (e.g., "plfs", "hces")
#' @return List of survey-specific settings
get_survey_settings <- function(survey = "plfs") {
  survey <- tolower(survey)
  if (!survey %in% names(CONFIG$surveys)) {
    stop(paste("Unknown survey:", survey,
               "\nAvailable surveys:", paste(names(CONFIG$surveys), collapse = ", ")))
  }
  CONFIG$surveys[[survey]]
}

# ============================================================================
# Codebook Loaders
# ============================================================================

#' Load state codes lookup table
#' @return data.table with state_code and state_name
load_state_codes <- function() {
  data.table::fread(codebook_path("state_codes.csv"))
}

#' Load activity status codes lookup table
#' @return data.table with status_code, status_description, category
load_activity_status <- function() {
  data.table::fread(codebook_path("activity_status.csv"))
}

#' Load NIC (industry) codes lookup table
#' @return data.table with nic_code and industry_name
load_nic_codes <- function() {
  data.table::fread(codebook_path("nic_2008.csv"))
}

#' Load NCO (occupation) codes lookup table
#' @return data.table with nco_code and occupation_name
load_nco_codes <- function() {
  data.table::fread(codebook_path("nco_2015.csv"))
}

# ============================================================================
# Variable Detection Utility
# ============================================================================

#' Detect variables in data using multiple naming patterns
#' @param data data.table or data.frame
#' @param var_type Type of variable to detect
#' @param patterns Custom patterns to try (optional)
#' @return Character string: detected column name or NA
#' @export
detect_variable <- function(data, var_type = c("weight", "strata", "substrata", "cluster",
                                                "state", "sector", "sex", "age", "status",
                                                "quarter", "subsample"),
                            patterns = NULL) {

  var_type <- match.arg(var_type)
  col_names <- names(data)

  # Define default patterns for each variable type
  default_patterns <- list(
    weight = c("MULT", "Multiplier", "MLT", "multiplier", "Weight", "WGT",
               "Subsample_Multiplier", "SUBSAMPLE_MULTIPLIER",
               "Sub_sample_wise_Multiplier", "Sub_Sample_Multiplier"),

    strata = c("Stratum", "STRATUM", "stratum", "STR"),

    substrata = c("Sub_Stratum", "SUB_STRATUM", "SubStratum", "sub_stratum",
                  "Sub_Round", "SUB_ROUND"),

    cluster = c("FSU", "FSU_NO", "FSU_Serial_No", "Fsu_no", "PSU", "fsu",
                "FSU_Serial", "First_Stage_Unit"),

    state = c("State", "STATE", "State_Code", "STATE_CODE", "state",
              "State_Ut_Code", "ST"),

    sector = c("Sector", "SECTOR", "sector", "Rural_Urban"),

    sex = c("Sex", "SEX", "Gender", "sex", "Gender_Code"),

    age = c("Age", "AGE", "age", "Person_Age", "Age_In_Years"),

    status_ps = c("Status_Code", "Principal_Status", "PS_Status",
                  "Principal_Activity_Status", "Usual_Principal_Activity_Status",
                  "PS", "ps_status", "UPS", "UPAS", "PAS"),

    status_cws = c("Current_Weekly_Status_CWS", "ACWS", "CWS_Status",
                   "Current_Weekly_Status", "CWS", "cws_status", "Current_Status"),

    quarter = c("NO_QTR", "Quarter", "QTR", "QUARTER", "Qtr", "Visit"),

    subsample = c("NSS", "NSC", "Sub_Sample", "SUB_SAMPLE", "Subsample", "SS")
  )

  # Use custom patterns if provided, otherwise use defaults
  if (!is.null(patterns)) {
    search_patterns <- patterns
  } else {
    search_patterns <- default_patterns[[var_type]]
    if (is.null(search_patterns)) {
      stop(paste("Unknown variable type:", var_type))
    }
  }

  # Try exact matches first
  match <- intersect(col_names, search_patterns)[1]

  # If no exact match, try partial matches
  if (is.na(match)) {
    for (pattern in search_patterns) {
      matches <- col_names[grepl(pattern, col_names, ignore.case = TRUE)]
      if (length(matches) > 0) {
        match <- matches[1]
        break
      }
    }
  }

  return(ifelse(is.na(match), NA_character_, match))
}

#' Detect multiple variables at once
#' @param data data.table or data.frame
#' @param var_types Character vector of variable types
#' @return Named character vector of detected column names
#' @export
detect_variables <- function(data, var_types = c("weight", "strata", "cluster",
                                                  "state", "sector", "sex", "age")) {
  result <- sapply(var_types, function(vt) detect_variable(data, vt))
  names(result) <- var_types
  return(result)
}

#' Report detected variables
#' @param data data.table or data.frame
#' @param var_types Character vector of variable types to report
#' @export
report_detected_variables <- function(data, var_types = c("weight", "quarter", "strata",
                                                           "substrata", "state", "sector",
                                                           "cluster", "subsample")) {
  cat("=== Detected Variables ===\n")

  detected <- detect_variables(data, var_types)

  for (vt in var_types) {
    var_name <- detected[vt]
    status <- ifelse(is.na(var_name), "NOT FOUND", var_name)
    cat(sprintf("  %-15s: %s\n", paste0(toupper(vt), ":"), status))
  }
  cat("\n")

  invisible(detected)
}

# ============================================================================
# Utility Functions
# ============================================================================

#' Print current configuration summary
print_config <- function() {
  cat("=== India Microdata Analysis Configuration ===\n\n")
  cat("Project root:", PROJECT_ROOT, "\n")
  cat("Default survey:", CONFIG$settings$default_survey, "\n")
  cat("Save format:", CONFIG$settings$save_format, "\n")
  cat("\nPaths:\n")
  cat("  Raw data:", get_path("raw"), "\n")
  cat("  Processed:", get_path("processed"), "\n")
  cat("  Codebooks:", get_path("codebooks"), "\n")
  cat("  Tables:", get_path("tables"), "\n")
  cat("  Figures:", get_path("figures"), "\n")
  cat("\nAPI configured:", !is.null(CONFIG$api$api_key), "\n")
}

# ============================================================================
# Startup Message
# ============================================================================

message("India Microdata Analysis - Configuration loaded")
message("Project root: ", PROJECT_ROOT)
message("Type print_config() to see full configuration")
