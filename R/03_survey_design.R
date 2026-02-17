# ============================================================================
# 03_survey_design.R - Survey Design Setup for Indian Microdata
# ============================================================================
# Creates proper survey design objects using the survey/srvyr packages.
# Handles stratified multi-stage sampling used in PLFS, NSS, HCES.
#
# Key concepts:
#   - Strata: Stratification variables (e.g., State x Sector x Stratum)
#   - Clusters (PSU): Primary Sampling Units (FSU in Indian surveys)
#   - Weights: Sampling weights (multipliers) for population estimates
#
# Usage:
#   source("R/01_config.R")
#   source("R/04_survey_design.R")
#
#   # Create PLFS survey design
#   plfs_design <- create_plfs_design(person_data)
#
#   # Now use srvyr/dplyr syntax for weighted analysis
#   plfs_design |>
#     group_by(State) |>
#     summarize(lfpr = survey_mean(in_labour_force))
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(survey)
  library(srvyr)
})

# ============================================================================
# Generic Survey Design Creation
# ============================================================================

#' Create a survey design object from microdata
#' @param data data.table or data.frame with survey data
#' @param weight_var Name of the weight variable
#' @param strata_vars Character vector of stratification variables
#' @param cluster_var Name of the cluster/PSU variable (NULL for no clustering)
#' @param nest Whether strata are nested within clusters (default: TRUE)
#' @param fpc_var Finite population correction variable (optional)
#' @return srvyr survey design object
create_survey_design <- function(data,
                                 weight_var,
                                 strata_vars = NULL,
                                 cluster_var = NULL,
                                 nest = TRUE,
                                 fpc_var = NULL) {
  # Validate input data
  stopifnot(
    "data must be a data.frame or data.table" = inherits(data, "data.frame"),
    "data cannot be empty" = nrow(data) > 0,
    "weight_var must be a character string" = is.character(weight_var) && length(weight_var) == 1
  )

  # Convert to data.frame if data.table (survey package prefers data.frame)
  if (inherits(data, "data.table")) {
    data <- as.data.frame(data)
  }

  # Validate inputs
  if (!weight_var %in% names(data)) {
    stop(sprintf("Weight variable '%s' not found in data", weight_var))
  }

  if (!is.null(strata_vars)) {
    missing_strata <- setdiff(strata_vars, names(data))
    if (length(missing_strata) > 0) {
      stop(sprintf("Strata variables not found: %s", paste(missing_strata, collapse = ", ")))
    }
  }

  if (!is.null(cluster_var) && !cluster_var %in% names(data)) {
    stop(sprintf("Cluster variable '%s' not found in data", cluster_var))
  }

  # Check for missing weights
  n_missing_wt <- sum(is.na(data[[weight_var]]))
  if (n_missing_wt > 0) {
    warning(sprintf("%d rows have missing weights - these will be excluded", n_missing_wt))
    data <- data[!is.na(data[[weight_var]]), ]
  }

  # Check for zero/negative weights
  n_invalid_wt <- sum(data[[weight_var]] <= 0, na.rm = TRUE)
  if (n_invalid_wt > 0) {
    warning(sprintf("%d rows have zero or negative weights - these will be excluded", n_invalid_wt))
    data <- data[data[[weight_var]] > 0, ]
  }

  message(sprintf("Creating survey design with %s observations", format(nrow(data), big.mark = ",")))
  message(sprintf("  Weight variable: %s", weight_var))

  # Build formula components
  # Weights
  weight_formula <- as.formula(paste0("~", weight_var))

  # Strata
  if (!is.null(strata_vars) && length(strata_vars) > 0) {
    # Create combined strata variable if multiple
    if (length(strata_vars) > 1) {
      data$.strata_combined <- interaction(data[, strata_vars], drop = TRUE)
      strata_formula <- ~.strata_combined
      message(sprintf("  Strata: %s (combined into single variable)", paste(strata_vars, collapse = " x ")))
    } else {
      strata_formula <- as.formula(paste0("~", strata_vars))
      message(sprintf("  Strata: %s", strata_vars))
    }
  } else {
    strata_formula <- NULL
    message("  Strata: None")
  }

  # Clusters
  if (!is.null(cluster_var)) {
    cluster_formula <- as.formula(paste0("~", cluster_var))
    message(sprintf("  Clusters (PSU): %s", cluster_var))
  } else {
    cluster_formula <- NULL
    message("  Clusters: None (treating as simple random sample)")
  }

  # FPC
  if (!is.null(fpc_var)) {
    fpc_formula <- as.formula(paste0("~", fpc_var))
    message(sprintf("  FPC: %s", fpc_var))
  } else {
    fpc_formula <- NULL
  }

  # Create the survey design
  # Using survey::svydesign then converting to srvyr

  if (!is.null(cluster_formula)) {
    # Clustered design
    design <- survey::svydesign(
      ids = cluster_formula,
      strata = strata_formula,
      weights = weight_formula,
      fpc = fpc_formula,
      data = data,
      nest = nest
    )
  } else if (!is.null(strata_formula)) {
    # Stratified but not clustered
    design <- survey::svydesign(
      ids = ~1,
      strata = strata_formula,
      weights = weight_formula,
      fpc = fpc_formula,
      data = data
    )
  } else {
    # Simple weighted design
    design <- survey::svydesign(
      ids = ~1,
      weights = weight_formula,
      fpc = fpc_formula,
      data = data
    )
  }

  # Convert to srvyr for tidyverse compatibility
  svy_design <- as_survey_design(design)

  # Report design effect estimate
  message(sprintf("  Design created successfully"))

  return(svy_design)
}

# ============================================================================
# PLFS-Specific Survey Design
# ============================================================================
#' Create survey design for PLFS data
#' @param data PLFS data (person or household level)
#' @param level "person" or "household"
#' @param quarter_weights Use quarterly weights (default) or annual
#' @param subsample "ss1", "ss2", or "combined" (default)
#' @return srvyr survey design object
create_plfs_design <- function(data,
                               level = c("person", "household"),
                               quarter_weights = TRUE,
                               subsample = c("combined", "ss1", "ss2")) {
  level <- match.arg(level)
  subsample <- match.arg(subsample)

  message(sprintf("Creating PLFS %s-level survey design...", level))

  # Convert to data.table for manipulation
  if (!inherits(data, "data.table")) {
    data <- as.data.table(data)
  }

  # -------------------------------------------------------------------------
  # Identify PLFS variables using centralized detection
  # -------------------------------------------------------------------------

  weight_var <- detect_variable(data, "weight")
  qtr_var <- detect_variable(data, "quarter")
  stratum_var <- detect_variable(data, "strata")
  substratum_var <- detect_variable(data, "substrata")
  state_var <- detect_variable(data, "state")
  sector_var <- detect_variable(data, "sector")
  fsu_var <- detect_variable(data, "cluster")
  ss_var <- detect_variable(data, "subsample")

  if (is.na(weight_var)) {
    stop("Could not find weight/multiplier variable. Expected: MULT, Multiplier, Weight, etc.")
  }

  # Report found variables
  report_detected_variables(data, c(
    "weight", "quarter", "strata", "substrata",
    "state", "sector", "cluster", "subsample"
  ))

  # -------------------------------------------------------------------------
  # Calculate final weights
  # -------------------------------------------------------------------------

  # PLFS weight formula from official documentation:
  # For sub-sample estimates: Final_Weight = MULT / (NO_QTR * 100)
  # For combined estimates:
  #   - If NSS == NSC: Final_Weight = MULT / (NO_QTR * 100)
  #   - Otherwise: Final_Weight = MULT / (NO_QTR * 200)
  # For Calendar Year data: Final_Weight = MULT / 100 (simpler)

  data <- copy(data) # Don't modify original

  # Check if quarter variable has valid numeric data
  qtr_valid <- FALSE
  if (!is.na(qtr_var) && quarter_weights) {
    n_quarters <- suppressWarnings(as.numeric(data[[qtr_var]]))
    qtr_valid <- !all(is.na(n_quarters)) && all(n_quarters[!is.na(n_quarters)] > 0)
  }

  if (qtr_valid && quarter_weights) {
    if (subsample == "combined" && !is.na(ss_var)) {
      # For combined sub-samples
      message("Using combined sub-sample weight formula: MULT / (NO_QTR * 200)")
      data[, .final_weight := get(weight_var) / (n_quarters * 200)]
    } else {
      # Single sub-sample
      message("Using sub-sample weight formula: MULT / (NO_QTR * 100)")
      data[, .final_weight := get(weight_var) / (n_quarters * 100)]
    }
  } else {
    # No quarter adjustment (calendar year data or annual weights)
    message("Using simple weight formula: MULT / 100 (Calendar Year / Annual data)")
    data[, .final_weight := get(weight_var) / 100]
  }

  # -------------------------------------------------------------------------
  # Build stratification
  # -------------------------------------------------------------------------

  strata_components <- character()

  # Add state to strata if available
  if (!is.na(state_var)) {
    strata_components <- c(strata_components, state_var)
  }

  # Add sector (rural/urban) to strata if available
  if (!is.na(sector_var)) {
    strata_components <- c(strata_components, sector_var)
  }

  # Add stratum
  if (!is.na(stratum_var)) {
    strata_components <- c(strata_components, stratum_var)
  }

  # Add sub-stratum
  if (!is.na(substratum_var)) {
    strata_components <- c(strata_components, substratum_var)
  }

  # -------------------------------------------------------------------------
  # Handle singleton strata (common issue in survey data)
  # -------------------------------------------------------------------------

  # Create combined strata for checking
  if (length(strata_components) > 0) {
    data[, .strata_check := interaction(.SD, drop = TRUE), .SDcols = strata_components]

    # Count observations per stratum
    strata_counts <- data[, .N, by = .strata_check]
    singleton_strata <- strata_counts[N == 1, .strata_check]

    if (length(singleton_strata) > 0) {
      warning(sprintf(
        "%d singleton strata detected. Using 'lonely.psu = adjust' option.",
        length(singleton_strata)
      ))
      options(survey.lonely.psu = "adjust")
    }

    data[, .strata_check := NULL]
  }

  # -------------------------------------------------------------------------
  # Create the design
  # -------------------------------------------------------------------------

  design <- create_survey_design(
    data = data,
    weight_var = ".final_weight",
    strata_vars = if (length(strata_components) > 0) strata_components else NULL,
    cluster_var = if (!is.na(fsu_var)) fsu_var else NULL,
    nest = TRUE
  )

  message("PLFS survey design created successfully!")

  return(design)
}

# ============================================================================
# NSS/HCES Survey Design
# ============================================================================

#' Create survey design for NSS/HCES data
#' @param data NSS data
#' @param weight_var Name of weight variable (auto-detected if NULL
#' @return srvyr survey design object
create_nss_design <- function(data, weight_var = NULL) {
  message("Creating NSS survey design...")

  if (!inherits(data, "data.table")) {
    data <- as.data.table(data)
  }

  # Auto-detect weight variable if not specified
  if (is.null(weight_var)) {
    weight_vars <- c("MULT", "Multiplier", "MLT", "WGT", "Weight")
    weight_var <- intersect(names(data), weight_vars)[1]

    if (is.na(weight_var)) {
      stop("Could not auto-detect weight variable. Please specify weight_var.")
    }
  }

  # Detect other variables (similar to PLFS)
  stratum_var <- intersect(names(data), c("Stratum", "STRATUM", "stratum"))[1]
  substratum_var <- intersect(names(data), c("Sub_Stratum", "SUB_STRATUM", "Sub_Round"))[1]
  state_var <- intersect(names(data), c("State", "STATE", "State_Code"))[1]
  sector_var <- intersect(names(data), c("Sector", "SECTOR"))[1]
  fsu_var <- intersect(names(data), c("FSU", "FSU_NO", "PSU"))[1]

  # Build strata
  strata_vars <- na.omit(c(state_var, sector_var, stratum_var, substratum_var))

  # Calculate weights (NSS typically uses MULT/100)
  data <- copy(data)
  data[, .final_weight := get(weight_var) / 100]

  # Handle lonely PSUs
  options(survey.lonely.psu = "adjust")

  design <- create_survey_design(
    data = data,
    weight_var = ".final_weight",
    strata_vars = if (length(strata_vars) > 0) strata_vars else NULL,
    cluster_var = if (!is.na(fsu_var)) fsu_var else NULL,
    nest = TRUE
  )

  message("NSS survey design created successfully!")

  return(design)
}

# ============================================================================
# Survey Design Utilities
# ============================================================================

#' Get summary of survey design
#' @param design srvyr design object
#' @return Summary information (printed and returned invisibly)
survey_design_summary <- function(design) {
  cat("=== Survey Design Summary ===\n\n")

  # Basic info
  n_obs <- nrow(design)
  cat(sprintf("Observations: %s\n", format(n_obs, big.mark = ",")))

  # Sum of weights (estimated population)
  sum_weights <- sum(weights(design))
  cat(sprintf("Sum of weights (est. population): %s\n", format(round(sum_weights), big.mark = ",")))

  # Design type
  cat("\nDesign type: ")
  if (!is.null(design$strata)) {
    n_strata <- length(unique(design$strata))
    cat(sprintf("Stratified (%s strata)", format(n_strata, big.mark = ",")))
  }
  if (!is.null(design$cluster)) {
    n_clusters <- length(unique(design$cluster[[1]]))
    cat(sprintf(", Clustered (%s PSUs)", format(n_clusters, big.mark = ",")))
  }
  cat("\n")

  # Weight distribution
  wts <- weights(design)
  cat("\nWeight distribution:\n")
  cat(sprintf("  Min: %.2f\n", min(wts)))
  cat(sprintf("  Median: %.2f\n", median(wts)))
  cat(sprintf("  Mean: %.2f\n", mean(wts)))
  cat(sprintf("  Max: %.2f\n", max(wts)))
  cat(sprintf("  CV: %.1f%%\n", sd(wts) / mean(wts) * 100))

  cat("\n")

  invisible(list(
    n_obs = n_obs,
    sum_weights = sum_weights,
    weight_stats = summary(wts)
  ))
}

#' Subset a survey design
#' @param design srvyr design object
#' @param condition Subsetting condition (unquoted expression)
#' @return Subsetted srvyr design
subset_design <- function(design, condition) {
  condition_expr <- rlang::enquo(condition)
  filter(design, !!condition_expr)
}

# ============================================================================
# Startup Message
# ============================================================================

message("Survey design functions loaded. Main functions:")
message("  create_plfs_design(data)    - PLFS survey design")
message("  create_nss_design(data)     - NSS/HCES survey design")
message("  create_survey_design(...)   - Generic survey design")
message("  survey_design_summary(des)  - Design summary")
