# ============================================================================
# 04_plfs_indicators.R - Labour Force Indicators for PLFS Data
# ============================================================================
# Calculates standard labour market indicators from PLFS data:
#
# Key Indicators:
#   - LFPR: Labour Force Participation Rate
#   - WPR: Worker Population Ratio (Employment Rate)
#   - UR: Unemployment Rate
#   - Activity Status Distribution
#
# Two approaches for activity status:
#   - PS (Principal Status): Based on major time spent in reference year
#   - CWS (Current Weekly Status): Based on reference week
#
# Activity Status Codes (PLFS):
#   11-51: Employed (Workers)
#   61:    Unemployed (seeking/available for work)
#   71-98: Not in Labour Force
#
# Usage:
#   source("R/01_config.R")
#   source("R/04_survey_design.R")
#   source("R/06_plfs_indicators.R")
#
#   # Create survey design first
#   design <- create_plfs_design(person_data)
#
#   # Calculate all indicators
#   indicators <- calc_all_indicators(design)
#
#   # Or specific indicators
#   lfpr <- calc_lfpr(design, by = c("State", "Sex"))
#   ur <- calc_unemployment_rate(design, by = "Sector")
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(srvyr)
  library(dplyr)
})

# ============================================================================
# Activity Status Classification
# ============================================================================

# Standard PLFS activity status codes
# Reference: PLFS Annual Report & Instruction Manual Vol-II
#   11-12 = Self-employed (own account worker, employer)
#   21    = Self-employed (unpaid family helper)
#   31    = Regular wage/salaried employee
#   41    = Casual labour (in other types of work)
#   42    = Casual labour (in public works) — rare variant
#   51    = Contract worker
EMPLOYED_CODES <- c(11, 12, 21, 31, 41, 42, 51)

# Unemployed: seeking/available for work
#   81 = Sought work or did not seek but was available for work (seeking)
#   82 = Sought work or did not seek but was available for work (available)
UNEMPLOYED_CODES <- c(81, 82)

# Not in Labour Force
#   61-62 = Attended educational institution
#   71-72 = Attended domestic duties only
#   91    = Rentier, pensioner, remittance recipient
#   92    = Not able to work due to disability
#   93    = Beggars, vagrants
#   94    = Prostitution
#   95    = Others
#   97-99 = Children (0-4), not available, etc.
NILF_CODES <- c(61, 62, 71, 72, 91, 92, 93, 94, 95, 97, 98, 99)

#' Add labour force classification variables to data
#' @param data data.table or srvyr design
#' @param status_var Name of the activity status variable (for PS/CWS)
#' @param subsidiary_var Name of subsidiary status variable (auto-detected for PS+SS)
#' @param approach "ps" for principal status only, "psss" for principal + subsidiary
#'   (official MoSPI usual status), or "cws" for current weekly status
#' @return Data with added classification variables
add_lf_classification <- function(data, status_var = NULL, subsidiary_var = NULL,
                                   approach = c("ps", "psss", "cws")) {
  approach <- match.arg(approach)

  # Get column names - handle both data.table and srvyr design
  if (inherits(data, "tbl_svy")) {
    col_names <- colnames(data)
  } else {
    col_names <- names(data)
  }

  # Auto-detect status variable if not provided
  if (is.null(status_var)) {
    var_type <- if (approach == "cws") "status_cws" else "status_ps"
    status_var <- detect_variable(data, var_type)

    if (is.na(status_var)) {
      status_var <- detect_variable(data, "status")
    }

    if (is.na(status_var)) {
      stop(
        "Could not find activity status variable. Please specify status_var.\n",
        "Available columns: ", paste(head(col_names, 20), collapse = ", "), "..."
      )
    }

    message(sprintf("Using status variable: %s", status_var))
  }

  # For PS+SS approach, also detect subsidiary status variable
  if (approach == "psss" && is.null(subsidiary_var)) {
    ss_patterns <- c("Subsidiary_Status_Code", "Subsidiary_Status",
                     "subsidiary_status", "SS_Status", "Sub_Status")
    for (p in ss_patterns) {
      m <- col_names[grepl(paste0("^", p, "$"), col_names, ignore.case = TRUE)]
      if (length(m) > 0) { subsidiary_var <- m[1]; break }
    }
    if (is.null(subsidiary_var)) {
      # Fallback: try partial match
      m <- col_names[grepl("subsidiary.*status", col_names, ignore.case = TRUE)]
      if (length(m) > 0) subsidiary_var <- m[1]
    }
    if (!is.null(subsidiary_var)) {
      message(sprintf("Using subsidiary status variable: %s", subsidiary_var))
    } else {
      warning("PS+SS approach requested but no subsidiary status variable found. Falling back to PS-only.")
      approach <- "ps"
    }
  }

  # Check if it's a survey design or data.table
  is_design <- inherits(data, "tbl_svy")

  if (is_design) {
    if (approach == "psss" && !is.null(subsidiary_var)) {
      # PS+SS approach: combine Principal and Subsidiary status
      # Person is employed if EITHER principal or subsidiary status is employed
      # Person is unemployed if principal is unemployed AND subsidiary is NOT employed
      data <- data |>
        mutate(
          .status_code = as.numeric(!!sym(status_var)),
          .ss_code = as.numeric(!!sym(subsidiary_var)),
          is_employed = .status_code %in% !!EMPLOYED_CODES |
            (!is.na(.ss_code) & .ss_code %in% !!EMPLOYED_CODES),
          is_unemployed = .status_code %in% !!UNEMPLOYED_CODES &
            !((!is.na(.ss_code)) & .ss_code %in% !!EMPLOYED_CODES),
          is_in_lf = is_employed | is_unemployed,
          is_nilf = !is_in_lf,
          employment_type = case_when(
            .status_code %in% c(11, 12, 21) ~ "Self-employed",
            !is.na(.ss_code) & .ss_code %in% c(11, 12, 21) & !(.status_code %in% EMPLOYED_CODES) ~ "Self-employed",
            .status_code == 31 ~ "Regular wage/salaried",
            !is.na(.ss_code) & .ss_code == 31 & !(.status_code %in% EMPLOYED_CODES) ~ "Regular wage/salaried",
            .status_code %in% c(41, 51) ~ "Casual labour",
            !is.na(.ss_code) & .ss_code %in% c(41, 51) & !(.status_code %in% EMPLOYED_CODES) ~ "Casual labour",
            TRUE ~ NA_character_
          )
        )
    } else {
      # PS-only or CWS approach: use single status variable
      data <- data |>
        mutate(
          .status_code = as.numeric(!!sym(status_var)),
          is_employed = .status_code %in% !!EMPLOYED_CODES,
          is_unemployed = .status_code %in% !!UNEMPLOYED_CODES,
          is_in_lf = is_employed | is_unemployed,
          is_nilf = !is_in_lf,
          employment_type = case_when(
            .status_code %in% c(11, 12, 21) ~ "Self-employed",
            .status_code == 31 ~ "Regular wage/salaried",
            .status_code %in% c(41, 51) ~ "Casual labour",
            TRUE ~ NA_character_
          )
        )
    }
  } else {
    data <- copy(data)
    data[, .status_code := as.numeric(get(status_var))]
    
    if (approach == "psss" && !is.null(subsidiary_var)) {
      data[, .ss_code := as.numeric(get(subsidiary_var))]
      data[, is_employed := .status_code %in% EMPLOYED_CODES |
             (!is.na(.ss_code) & .ss_code %in% EMPLOYED_CODES)]
      data[, is_unemployed := .status_code %in% UNEMPLOYED_CODES &
             !((!is.na(.ss_code)) & .ss_code %in% EMPLOYED_CODES)]
    } else {
      data[, is_employed := .status_code %in% EMPLOYED_CODES]
      data[, is_unemployed := .status_code %in% UNEMPLOYED_CODES]
    }
    
    data[, is_in_lf := is_employed | is_unemployed]
    data[, is_nilf := !is_in_lf]

    data[, employment_type := fcase(
      .status_code %in% c(11, 12, 21), "Self-employed",
      .status_code == 31, "Regular wage/salaried",
      .status_code %in% c(41, 51), "Casual labour",
      default = NA_character_
    )]
  }

  return(data)
}

# ============================================================================
# Core Indicator Functions
# ============================================================================

#' Calculate Labour Force Participation Rate (LFPR)
#' @param design srvyr survey design object
#' @param by Grouping variables (character vector or NULL for overall)
#' @param status_var Activity status variable name (auto-detected if NULL)
#' @param approach "ps" or "cws"
#' @param age_filter Age range to include (default: 15+ for standard LFPR)
#' @return data.table with LFPR estimates and confidence intervals
calc_lfpr <- function(design,
                      by = NULL,
                      status_var = NULL,
                      approach = c("ps", "psss", "cws"),
                      age_filter = c(15, 99)) {
  approach <- match.arg(approach)

  # Validate input

  stopifnot(
    "design must be a srvyr survey design object" = inherits(design, "tbl_svy"),
    "design cannot be empty" = nrow(design) > 0
  )

  # Add classification
  design <- add_lf_classification(design, status_var = status_var, approach = approach)

  # Apply age filter if age variable exists
  age_vars <- c("Age", "AGE", "age", "Person_Age")
  age_var <- intersect(colnames(design), age_vars)[1]

  if (!is.na(age_var) && !is.null(age_filter)) {
    design <- design |>
      filter(!!sym(age_var) >= age_filter[1] & !!sym(age_var) <= age_filter[2])
    message(sprintf(
      "Filtered to age %d-%d: %s observations",
      age_filter[1], age_filter[2], format(nrow(design), big.mark = ",")
    ))
  }

  # Calculate LFPR
  # LFPR = (Employed + Unemployed) / Population * 100
  #      = Labour Force / Population * 100

  if (is.null(by)) {
    result <- design |>
      summarize(
        lfpr = survey_mean(is_in_lf, na.rm = TRUE, vartype = c("se", "ci")),
        n = unweighted(n()),
        n_in_lf = unweighted(sum(is_in_lf, na.rm = TRUE))
      )
  } else {
    result <- design |>
      group_by(across(all_of(by))) |>
      summarize(
        lfpr = survey_mean(is_in_lf, na.rm = TRUE, vartype = c("se", "ci")),
        n = unweighted(n()),
        n_in_lf = unweighted(sum(is_in_lf, na.rm = TRUE))
      )
  }

  # Convert to percentage and clean up
  result <- as.data.table(result)
  result[, lfpr := lfpr * 100]
  result[, lfpr_se := lfpr_se * 100]
  result[, lfpr_low := lfpr_low * 100]
  result[, lfpr_upp := lfpr_upp * 100]

  return(result)
}

#' Calculate Worker Population Ratio (WPR) / Employment Rate
#' @param design srvyr survey design object
#' @param by Grouping variables
#' @param status_var Activity status variable name
#' @param approach "ps" or "cws"
#' @param age_filter Age range (default: 15+)
#' @return data.table with WPR estimates
calc_wpr <- function(design,
                     by = NULL,
                     status_var = NULL,
                     approach = c("ps", "psss", "cws"),
                     age_filter = c(15, 99)) {
  approach <- match.arg(approach)

  # Add classification
  design <- add_lf_classification(design, status_var = status_var, approach = approach)

  # Apply age filter
  age_vars <- c("Age", "AGE", "age", "Person_Age")
  age_var <- intersect(colnames(design), age_vars)[1]

  if (!is.na(age_var) && !is.null(age_filter)) {
    design <- design |>
      filter(!!sym(age_var) >= age_filter[1] & !!sym(age_var) <= age_filter[2])
  }

  # Calculate WPR
  # WPR = Employed / Population * 100

  if (is.null(by)) {
    result <- design |>
      summarize(
        wpr = survey_mean(is_employed, na.rm = TRUE, vartype = c("se", "ci")),
        n = unweighted(n()),
        n_employed = unweighted(sum(is_employed, na.rm = TRUE))
      )
  } else {
    result <- design |>
      group_by(across(all_of(by))) |>
      summarize(
        wpr = survey_mean(is_employed, na.rm = TRUE, vartype = c("se", "ci")),
        n = unweighted(n()),
        n_employed = unweighted(sum(is_employed, na.rm = TRUE))
      )
  }

  result <- as.data.table(result)
  result[, wpr := wpr * 100]
  result[, wpr_se := wpr_se * 100]
  result[, wpr_low := wpr_low * 100]
  result[, wpr_upp := wpr_upp * 100]

  return(result)
}

#' Calculate Unemployment Rate (UR)
#' @param design srvyr survey design object
#' @param by Grouping variables
#' @param status_var Activity status variable name
#' @param approach "ps" or "cws"
#' @param age_filter Age range (default: 15+)
#' @return data.table with UR estimates
calc_unemployment_rate <- function(design,
                                   by = NULL,
                                   status_var = NULL,
                                   approach = c("ps", "psss", "cws"),
                                   age_filter = c(15, 99)) {
  approach <- match.arg(approach)

  # Add classification
  design <- add_lf_classification(design, status_var = status_var, approach = approach)

  # Apply age filter
  age_vars <- c("Age", "AGE", "age", "Person_Age")
  age_var <- intersect(colnames(design), age_vars)[1]

  if (!is.na(age_var) && !is.null(age_filter)) {
    design <- design |>
      filter(!!sym(age_var) >= age_filter[1] & !!sym(age_var) <= age_filter[2])
  }

  # Filter to labour force only (UR is among LF, not total population)
  design <- design |> filter(is_in_lf)

  # Calculate UR
  # UR = Unemployed / Labour Force * 100

  if (is.null(by)) {
    result <- design |>
      summarize(
        ur = survey_mean(is_unemployed, na.rm = TRUE, vartype = c("se", "ci")),
        n_lf = unweighted(n()),
        n_unemployed = unweighted(sum(is_unemployed, na.rm = TRUE))
      )
  } else {
    result <- design |>
      group_by(across(all_of(by))) |>
      summarize(
        ur = survey_mean(is_unemployed, na.rm = TRUE, vartype = c("se", "ci")),
        n_lf = unweighted(n()),
        n_unemployed = unweighted(sum(is_unemployed, na.rm = TRUE))
      )
  }

  result <- as.data.table(result)
  result[, ur := ur * 100]
  result[, ur_se := ur_se * 100]
  result[, ur_low := ur_low * 100]
  result[, ur_upp := ur_upp * 100]

  return(result)
}

# ============================================================================
# Employment Distribution Functions
# ============================================================================

#' Calculate employment type distribution
#' @param design srvyr survey design object
#' @param by Grouping variables
#' @param status_var Activity status variable
#' @param approach "ps" or "cws"
#' @return data.table with employment type shares
calc_employment_distribution <- function(design,
                                         by = NULL,
                                         status_var = NULL,
                                         approach = c("ps", "psss", "cws")) {
  approach <- match.arg(approach)

  # Add classification
  design <- add_lf_classification(design, status_var = status_var, approach = approach)

  # Filter to employed only
  design <- design |> filter(is_employed)

  # Calculate shares by employment type
  if (is.null(by)) {
    result <- design |>
      group_by(employment_type) |>
      summarize(
        share = survey_mean(vartype = c("se", "ci")),
        n = unweighted(n())
      )
  } else {
    result <- design |>
      group_by(across(all_of(c(by, "employment_type")))) |>
      summarize(
        n = unweighted(n())
      ) |>
      group_by(across(all_of(by))) |>
      mutate(
        share = n / sum(n) * 100
      )
  }

  result <- as.data.table(result)

  if ("share" %in% names(result) && "share_se" %in% names(result)) {
    result[, share := share * 100]
    result[, share_se := share_se * 100]
    result[, share_low := share_low * 100]
    result[, share_upp := share_upp * 100]
  }

  return(result)
}

#' Calculate activity status distribution
#' @param design srvyr survey design object
#' @param by Grouping variables
#' @param status_var Activity status variable
#' @return data.table with status distribution
calc_activity_distribution <- function(design, by = NULL, status_var = NULL) {
  # Find status variable
  if (is.null(status_var)) {
    status_var <- detect_variable(design, "status_ps")
    if (is.na(status_var)) {
      stop("Could not find activity status variable")
    }
  }

  # Load activity status codebook
  activity_codes <- tryCatch(
    load_activity_status(),
    error = function(e) NULL
  )

  if (is.null(by)) {
    result <- design |>
      group_by(!!sym(status_var)) |>
      summarize(
        share = survey_mean(vartype = c("se")),
        n = unweighted(n())
      )
  } else {
    result <- design |>
      group_by(across(all_of(c(by, status_var)))) |>
      summarize(
        share = survey_mean(vartype = c("se")),
        n = unweighted(n())
      )
  }

  result <- as.data.table(result)
  result[, share := share * 100]
  result[, share_se := share_se * 100]

  # Merge with codebook if available
  if (!is.null(activity_codes)) {
    setnames(result, status_var, "status_code", skip_absent = TRUE)
    result <- merge(result, activity_codes[, .(status_code, status_description, category)],
      by = "status_code", all.x = TRUE
    )
  }

  return(result)
}

# ============================================================================
# Comprehensive Indicator Tables
# ============================================================================

#' Calculate all major labour force indicators
#' @param design srvyr survey design object
#' @param by Grouping variables
#' @param approach "ps" or "cws"
#' @param age_filter Age range
#' @return data.table with LFPR, WPR, UR
calc_all_indicators <- function(design,
                                by = NULL,
                                approach = c("ps", "psss", "cws"),
                                age_filter = c(15, 99)) {
  approach <- match.arg(approach)

  message(sprintf("Calculating labour force indicators (approach: %s)", approach))

  # Calculate each indicator
  lfpr <- calc_lfpr(design, by, approach = approach, age_filter = age_filter)
  wpr <- calc_wpr(design, by, approach = approach, age_filter = age_filter)
  ur <- calc_unemployment_rate(design, by, approach = approach, age_filter = age_filter)

  # Merge results
  if (is.null(by)) {
    result <- data.table(
      lfpr = lfpr$lfpr,
      lfpr_se = lfpr$lfpr_se,
      wpr = wpr$wpr,
      wpr_se = wpr$wpr_se,
      ur = ur$ur,
      ur_se = ur$ur_se,
      n = lfpr$n
    )
  } else {
    result <- merge(
      lfpr[, c(by, "lfpr", "lfpr_se", "lfpr_low", "lfpr_upp", "n"), with = FALSE],
      wpr[, c(by, "wpr", "wpr_se", "wpr_low", "wpr_upp"), with = FALSE],
      by = by
    )
    result <- merge(
      result,
      ur[, c(by, "ur", "ur_se", "ur_low", "ur_upp"), with = FALSE],
      by = by
    )
  }

  return(result)
}

#' Calculate indicators by sex (common analysis)
#' @param design srvyr survey design object
#' @param approach "ps" or "cws"
#' @return data.table with indicators by Male/Female
calc_indicators_by_sex <- function(design, approach = c("ps", "psss", "cws")) {
  approach <- match.arg(approach)

  # Find sex variable
  sex_var <- detect_variable(design, "sex")

  if (is.na(sex_var)) {
    stop("Could not find sex/gender variable")
  }

  result <- calc_all_indicators(design, by = sex_var, approach = approach)

  # Recode sex to labels if numeric
  if (is.numeric(result[[sex_var]])) {
    result[, (sex_var) := fifelse(get(sex_var) == 1, "Male", "Female")]
  }

  return(result)
}

#' Calculate indicators by state
#' @param design srvyr survey design object
#' @param approach "ps" or "cws"
#' @param add_names Add state names from codebook
#' @return data.table with indicators by state
calc_indicators_by_state <- function(design,
                                     approach = c("ps", "psss", "cws"),
                                     add_names = TRUE) {
  approach <- match.arg(approach)

  # Find state variable
  state_var <- detect_variable(design, "state")

  if (is.na(state_var)) {
    stop("Could not find state variable")
  }

  result <- calc_all_indicators(design, by = state_var, approach = approach)

  # Add state names if requested
  if (add_names) {
    state_codes <- tryCatch(
      load_state_codes(),
      error = function(e) NULL
    )

    if (!is.null(state_codes)) {
      setnames(result, state_var, "state_code", skip_absent = TRUE)
      result <- merge(result, state_codes[, .(state_code, state_name)],
        by = "state_code", all.x = TRUE
      )
      # Reorder columns
      setcolorder(result, c("state_code", "state_name"))
    }
  }

  return(result)
}

# ============================================================================
# Formatting and Presentation
# ============================================================================

#' Format indicator table for presentation
#' @param result data.table from calc_* functions
#' @param digits Number of decimal places
#' @param include_ci Include confidence intervals
#' @return Formatted data.table
format_indicators <- function(result, digits = 1, include_ci = TRUE) {
  result <- copy(result)

  # Format main estimates
  for (col in c("lfpr", "wpr", "ur")) {
    if (col %in% names(result)) {
      se_col <- paste0(col, "_se")
      low_col <- paste0(col, "_low")
      upp_col <- paste0(col, "_upp")

      if (include_ci && low_col %in% names(result)) {
        # Create formatted string with CI
        result[, (paste0(col, "_fmt")) := sprintf(
          "%.*f (%.*f-%.*f)",
          digits, get(col),
          digits, get(low_col),
          digits, get(upp_col)
        )]
      } else if (se_col %in% names(result)) {
        # Create formatted string with SE
        result[, (paste0(col, "_fmt")) := sprintf(
          "%.*f (±%.*f)",
          digits, get(col),
          digits, 1.96 * get(se_col)
        )]
      }

      # Round numeric columns
      result[, (col) := round(get(col), digits)]
    }
  }

  return(result)
}

# ============================================================================
# Startup Message
# ============================================================================

message("PLFS indicator functions loaded. Main functions:")
message("  calc_lfpr(design, by)              - Labour Force Participation Rate")
message("  calc_wpr(design, by)               - Worker Population Ratio")
message("  calc_unemployment_rate(design, by) - Unemployment Rate")
message("  calc_all_indicators(design, by)    - All indicators together")
message("  calc_indicators_by_sex(design)     - Indicators by gender")
message("  calc_indicators_by_state(design)   - Indicators by state")
