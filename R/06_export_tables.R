# ============================================================================
# 06_export_tables.R - Publication-Quality Table Export
# ============================================================================
# Functions for exporting tables to Word (.docx) and LaTeX (.tex) formats.
# Uses modelsummary for regression tables and gt/flextable for data tables.
#
# Output Types:
#   1. Regression tables (modelsummary)
#   2. Summary statistics tables (gt)
#   3. Indicator tables (custom formatting)
#   4. Cross-tabulations
#
# Usage:
#   source("R/01_config.R")
#   source("R/09_export_tables.R")
#
#   # Export regression table
#   export_regression_table(list(model1, model2), "regression_results")
#
#   # Export indicator table
#   export_indicator_table(indicators, "lfpr_by_state")
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(modelsummary)
  library(gt)
  library(flextable)
})

# ============================================================================
# Configuration
# ============================================================================

# Default output settings
.TABLE_DEFAULTS <- list(
  digits = 2,
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  note_format = "Source: Authors' calculations using PLFS microdata.",
  font_size = 10,
  font_family = "Times New Roman"
)

# ============================================================================
# Regression Tables (modelsummary)
# ============================================================================

#' Export regression results to Word and/or LaTeX
#' @param models List of model objects or single model
#' @param filename Output filename (without extension)
#' @param output_dir Output directory (default: tables folder from config)
#' @param formats Character vector: "docx", "tex", or both (default)
#' @param title Table title
#' @param notes Footnotes (character vector)
#' @param coef_rename Named vector to rename coefficients
#' @param gof_map Which goodness-of-fit stats to include
#' @param stars Significance stars (default: * p<0.1, ** p<0.05, *** p<0.01)
#' @param ... Additional arguments passed to modelsummary
#' @return Paths to created files (invisibly)
export_regression_table <- function(models,
                                    filename,
                                    output_dir = NULL,
                                    formats = c("docx", "tex"),
                                    title = NULL,
                                    notes = NULL,
                                    coef_rename = NULL,
                                    gof_map = NULL,
                                    stars = .TABLE_DEFAULTS$stars,
                                    ...) {

  # Get output directory
  if (is.null(output_dir)) {
    output_dir <- get_path("tables")
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Ensure models is a list
  if (!is.list(models) || inherits(models, "lm") || inherits(models, "fixest")) {
    models <- list(models)
  }

  # Default goodness-of-fit statistics
  if (is.null(gof_map)) {
    gof_map <- c(
      "nobs" = "N",
      "r.squared" = "R²",
      "adj.r.squared" = "Adj. R²",
      "rmse" = "RMSE",
      "FE" = "Fixed Effects"
    )
  }

  # Add default note if none provided
  if (is.null(notes)) {
    notes <- .TABLE_DEFAULTS$note_format
  }

  created_files <- character()

  # Export to each format
  for (fmt in formats) {

    output_path <- file.path(output_dir, paste0(filename, ".", fmt))

    tryCatch({
      modelsummary(
        models,
        output = output_path,
        stars = stars,
        title = title,
        notes = notes,
        coef_rename = coef_rename,
        gof_map = gof_map,
        ...
      )

      message(sprintf("Created: %s", output_path))
      created_files <- c(created_files, output_path)

    }, error = function(e) {
      warning(sprintf("Failed to create %s: %s", fmt, e$message))
    })
  }

  invisible(created_files)
}

#' Create regression table comparing multiple specifications
#' @param models Named list of models
#' @param filename Output filename
#' @param dep_var_label Label for dependent variable
#' @param model_names Column names for each model
#' @param ... Additional arguments
#' @return Paths to created files
export_regression_comparison <- function(models,
                                         filename,
                                         dep_var_label = NULL,
                                         model_names = NULL,
                                         ...) {

  # Set model names if provided
  if (!is.null(model_names) && length(model_names) == length(models)) {
    names(models) <- model_names
  }

  # Add dependent variable label as title if provided
  title <- if (!is.null(dep_var_label)) {
    paste("Dependent Variable:", dep_var_label)
  } else {
    NULL
  }

  export_regression_table(models, filename, title = title, ...)
}

# ============================================================================
# Summary Statistics Tables (gt)
# ============================================================================

#' Export summary statistics table
#' @param data data.table with summary statistics
#' @param filename Output filename
#' @param output_dir Output directory
#' @param formats Output formats ("docx", "tex")
#' @param title Table title
#' @param source_note Source/footnote text
#' @param digits Number of decimal places
#' @return Paths to created files
export_summary_table <- function(data,
                                 filename,
                                 output_dir = NULL,
                                 formats = c("docx", "tex"),
                                 title = NULL,
                                 source_note = NULL,
                                 digits = 2) {

  if (is.null(output_dir)) {
    output_dir <- get_path("tables")
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Create gt table
  tbl <- gt(data) |>
    fmt_number(
      columns = where(is.numeric),
      decimals = digits
    )

  # Add title
  if (!is.null(title)) {
    tbl <- tbl |> tab_header(title = title)
  }

  # Add source note
  if (!is.null(source_note)) {
    tbl <- tbl |> tab_source_note(source_note = source_note)
  } else {
    tbl <- tbl |> tab_source_note(source_note = .TABLE_DEFAULTS$note_format)
  }

  # Style
  tbl <- tbl |>
    tab_options(
      table.font.size = px(.TABLE_DEFAULTS$font_size),
      table.font.names = .TABLE_DEFAULTS$font_family
    )

  created_files <- character()

  # Export
  for (fmt in formats) {
    output_path <- file.path(output_dir, paste0(filename, ".", fmt))

    tryCatch({
      if (fmt == "docx") {
        gt::gtsave(tbl, output_path)
      } else if (fmt == "tex") {
        # gt exports to LaTeX
        gt::gtsave(tbl, output_path)
      } else if (fmt == "html") {
        gt::gtsave(tbl, output_path)
      }

      message(sprintf("Created: %s", output_path))
      created_files <- c(created_files, output_path)

    }, error = function(e) {
      warning(sprintf("Failed to create %s: %s", fmt, e$message))
    })
  }

  invisible(created_files)
}

# ============================================================================
# Labour Force Indicator Tables
# ============================================================================

#' Export labour force indicator table (LFPR, WPR, UR)
#' @param indicators data.table from calc_all_indicators or similar
#' @param filename Output filename
#' @param output_dir Output directory
#' @param formats Output formats
#' @param title Table title
#' @param include_ci Include confidence intervals
#' @param include_n Include sample size column
#' @return Paths to created files
export_indicator_table <- function(indicators,
                                   filename,
                                   output_dir = NULL,
                                   formats = c("docx", "tex"),
                                   title = "Labour Force Indicators",
                                   include_ci = TRUE,
                                   include_n = TRUE) {

  if (is.null(output_dir)) {
    output_dir <- get_path("tables")
  }

  data <- copy(indicators)

  # Select and rename columns for display
  display_cols <- character()

  # Find grouping columns (non-indicator columns)
  indicator_cols <- c("lfpr", "wpr", "ur", "lfpr_se", "wpr_se", "ur_se",
                      "lfpr_low", "lfpr_upp", "wpr_low", "wpr_upp",
                      "ur_low", "ur_upp", "n", "n_in_lf", "n_employed")
  group_cols <- setdiff(names(data), indicator_cols)
  display_cols <- c(display_cols, group_cols)

  # Format indicators
  if (include_ci) {
    # Create formatted columns with CIs
    if ("lfpr" %in% names(data)) {
      data[, LFPR := sprintf("%.1f (%.1f-%.1f)", lfpr, lfpr_low, lfpr_upp)]
      display_cols <- c(display_cols, "LFPR")
    }
    if ("wpr" %in% names(data)) {
      data[, WPR := sprintf("%.1f (%.1f-%.1f)", wpr, wpr_low, wpr_upp)]
      display_cols <- c(display_cols, "WPR")
    }
    if ("ur" %in% names(data)) {
      data[, UR := sprintf("%.1f (%.1f-%.1f)", ur, ur_low, ur_upp)]
      display_cols <- c(display_cols, "UR")
    }
  } else {
    # Just point estimates
    if ("lfpr" %in% names(data)) {
      data[, LFPR := round(lfpr, 1)]
      display_cols <- c(display_cols, "LFPR")
    }
    if ("wpr" %in% names(data)) {
      data[, WPR := round(wpr, 1)]
      display_cols <- c(display_cols, "WPR")
    }
    if ("ur" %in% names(data)) {
      data[, UR := round(ur, 1)]
      display_cols <- c(display_cols, "UR")
    }
  }

  if (include_n && "n" %in% names(data)) {
    data[, N := format(n, big.mark = ",")]
    display_cols <- c(display_cols, "N")
  }

  # Subset to display columns
  display_data <- data[, ..display_cols]

  # Create gt table
  tbl <- gt(display_data) |>
    tab_header(title = title) |>
    tab_source_note(
      source_note = paste(
        "Notes: LFPR = Labour Force Participation Rate;",
        "WPR = Worker Population Ratio;",
        "UR = Unemployment Rate.",
        if (include_ci) "95% confidence intervals in parentheses." else "",
        .TABLE_DEFAULTS$note_format
      )
    ) |>
    tab_options(
      table.font.size = px(.TABLE_DEFAULTS$font_size)
    )

  # Export
  created_files <- character()

  for (fmt in formats) {
    output_path <- file.path(output_dir, paste0(filename, ".", fmt))

    tryCatch({
      gt::gtsave(tbl, output_path)
      message(sprintf("Created: %s", output_path))
      created_files <- c(created_files, output_path)
    }, error = function(e) {
      warning(sprintf("Failed to create %s: %s", fmt, e$message))
    })
  }

  invisible(created_files)
}

# ============================================================================
# Cross-Tabulation Tables
# ============================================================================

#' Export cross-tabulation table
#' @param data data.table with cross-tabulation results
#' @param row_var Row variable name
#' @param col_var Column variable name
#' @param value_var Value variable (e.g., "share", "count")
#' @param filename Output filename
#' @param title Table title
#' @param ... Additional arguments
#' @return Paths to created files
export_crosstab <- function(data,
                            row_var,
                            col_var,
                            value_var,
                            filename,
                            title = NULL,
                            ...) {

  # Pivot to wide format
  wide_data <- dcast(data,
                     as.formula(paste(row_var, "~", col_var)),
                     value.var = value_var)

  export_summary_table(wide_data, filename, title = title, ...)
}

# ============================================================================
# Flextable Export (Alternative for Word)
# ============================================================================

#' Export table using flextable (better Word compatibility)
#' @param data data.table or data.frame
#' @param filename Output filename
#' @param output_dir Output directory
#' @param title Table title
#' @param digits Decimal places
#' @return Path to created file
export_flextable <- function(data,
                             filename,
                             output_dir = NULL,
                             title = NULL,
                             digits = 2) {

  if (is.null(output_dir)) {
    output_dir <- get_path("tables")
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Create flextable
  ft <- flextable(as.data.frame(data)) |>
    colformat_double(digits = digits) |>
    autofit() |>
    theme_vanilla() |>
    fontsize(size = .TABLE_DEFAULTS$font_size, part = "all") |>
    font(fontname = .TABLE_DEFAULTS$font_family, part = "all")

  # Add title
  if (!is.null(title)) {
    ft <- ft |> set_caption(caption = title)
  }

  # Add footnote
  ft <- ft |>
    add_footer_lines(values = .TABLE_DEFAULTS$note_format)

  # Export to Word
  output_path <- file.path(output_dir, paste0(filename, ".docx"))

  save_as_docx(ft, path = output_path)
  message(sprintf("Created: %s", output_path))

  invisible(output_path)
}

# ============================================================================
# Descriptive Statistics
# ============================================================================

#' Generate and export descriptive statistics table
#' @param data data.table
#' @param vars Variables to summarize (NULL for all numeric)
#' @param filename Output filename
#' @param by_var Optional grouping variable
#' @param stats Which statistics: "mean", "sd", "min", "max", "median", "n"
#' @param ... Additional arguments for export
#' @return Paths to created files
export_descriptive_stats <- function(data,
                                     vars = NULL,
                                     filename,
                                     by_var = NULL,
                                     stats = c("mean", "sd", "min", "max", "n"),
                                     ...) {

  # Select numeric variables if not specified
  if (is.null(vars)) {
    vars <- names(data)[sapply(data, is.numeric)]
  }

  # Calculate statistics
  calc_stats <- function(x) {
    result <- list()
    if ("n" %in% stats) result$N <- sum(!is.na(x))
    if ("mean" %in% stats) result$Mean <- mean(x, na.rm = TRUE)
    if ("sd" %in% stats) result$SD <- sd(x, na.rm = TRUE)
    if ("min" %in% stats) result$Min <- min(x, na.rm = TRUE)
    if ("max" %in% stats) result$Max <- max(x, na.rm = TRUE)
    if ("median" %in% stats) result$Median <- median(x, na.rm = TRUE)
    return(result)
  }

  if (is.null(by_var)) {
    # Overall statistics
    stats_list <- lapply(vars, function(v) {
      s <- calc_stats(data[[v]])
      s$Variable <- v
      as.data.table(s)
    })
    summary_dt <- rbindlist(stats_list)
    setcolorder(summary_dt, "Variable")
  } else {
    # Statistics by group
    stats_list <- lapply(vars, function(v) {
      data[, c(calc_stats(get(v)), list(Variable = v)), by = by_var]
    })
    summary_dt <- rbindlist(stats_list)
    setcolorder(summary_dt, c(by_var, "Variable"))
  }

  export_summary_table(summary_dt, filename,
                       title = "Descriptive Statistics", ...)
}

# ============================================================================
# Batch Export
# ============================================================================

#' Export multiple tables at once
#' @param tables Named list of data.tables
#' @param prefix Filename prefix
#' @param output_dir Output directory
#' @param formats Output formats
#' @return List of created file paths
export_batch <- function(tables,
                         prefix = "",
                         output_dir = NULL,
                         formats = c("docx", "tex")) {

  if (is.null(output_dir)) {
    output_dir <- get_path("tables")
  }

  all_files <- list()

  for (name in names(tables)) {
    filename <- if (prefix != "") paste0(prefix, "_", name) else name

    tryCatch({
      files <- export_summary_table(
        tables[[name]],
        filename,
        output_dir = output_dir,
        formats = formats
      )
      all_files[[name]] <- files
    }, error = function(e) {
      warning(sprintf("Failed to export '%s': %s", name, e$message))
    })
  }

  message(sprintf("\nExported %d of %d tables",
                  length(all_files), length(tables)))

  invisible(all_files)
}

# ============================================================================
# Startup Message
# ============================================================================

message("Table export functions loaded. Main functions:")
message("  export_regression_table(models, filename)  - Regression results")
message("  export_summary_table(data, filename)       - Summary tables (gt)")
message("  export_indicator_table(data, filename)     - Labour indicators")
message("  export_flextable(data, filename)           - Word tables")
message("  export_descriptive_stats(data, vars, ...)  - Descriptive stats")
