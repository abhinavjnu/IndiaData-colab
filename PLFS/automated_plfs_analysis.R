# ============================================================================
# automated_plfs_analysis.R - Complete PLFS Analysis Automation
# ============================================================================
# This script automates the entire PLFS analysis pipeline from raw data to
# final reports. Run with: source("PLFS/automated_plfs_analysis.R")
#
# What this script does:
#   1. Discovers available PLFS datasets (year folders)
#   2. Parses raw TXT files using Data_Layout.xlsx
#   3. Creates proper survey designs with weights/strata/PSU
#   4. Calculates all major labour force indicators
#   5. Generates formatted tables (CSV, Word .docx)
#   6. Creates publication-quality visualizations
#   7. Saves all outputs to organized directories
#
# Requirements:
#   - Raw data files (CPERV1.TXT, CHHV1.TXT) in year folders
#   - Data_Layout.xlsx files for each year
#   - R modules in R/ directory
# ============================================================================

# Set working directory to project root (cross-platform)
get_current_script_path <- function() {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_flag <- "--file="
  file_idx <- grep(file_flag, cmd_args)

  if (length(file_idx) > 0) {
    return(normalizePath(sub(file_flag, "", cmd_args[file_idx[1]]), winslash = "/", mustWork = TRUE))
  }

  ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(ofile)) {
    return(normalizePath(ofile, winslash = "/", mustWork = TRUE))
  }

  stop("Could not determine script path. Run this script with source() or Rscript.")
}

script_path <- get_current_script_path()
project_root <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
setwd(project_root)

# ============================================================================
# Configuration
# ============================================================================

# Years to process (will auto-detect if data exists)
YEARS_TO_PROCESS <- c("2023-24", "2022-23", "2021-22", "2020-21", 
                      "2019-20", "2018-19", "2017-18")

# Analysis settings
AGE_FILTER <- c(15, 99)  # Standard labour force age (15+)
APPROACH <- "ps"         # Principal Status approach (or "cws" for Current Weekly)

# Output settings
OUTPUT_FORMATS <- c("csv", "docx")  # Table formats
FIGURE_FORMATS <- c("pdf", "png")   # Figure formats

# ============================================================================
# Load Required Libraries and Modules
# ============================================================================

cat("\n========================================\n")
cat("PLFS Automated Analysis Pipeline\n")
cat("========================================\n\n")

cat("Loading required packages and modules...\n")

# Core packages
suppressPackageStartupMessages({
  library(data.table)
  library(srvyr)
  library(dplyr)
  library(ggplot2)
  library(readxl)
  library(arrow)
  library(progress)
})

# Load project modules
source("R/01_config.R")
source("R/02_read_microdata.R")
source("R/03_survey_design.R")
source("R/04_plfs_indicators.R")
source("R/06_export_tables.R")
source("R/07_viz_themes.R")

cat("✓ All modules loaded successfully\n\n")

# ============================================================================
# Helper Functions
# ============================================================================

#' Discover available PLFS year folders
discover_plfs_years <- function(base_dir = "PLFS") {
  if (!dir.exists(base_dir)) {
    stop("PLFS directory not found: ", base_dir)
  }
  
  # List all directories that look like year folders
  all_dirs <- list.dirs(base_dir, recursive = FALSE, full.names = FALSE)
  year_dirs <- all_dirs[grepl("^[0-9]{4}-[0-9]{2,4}$", all_dirs)]
  
  # Check which have required files
  valid_years <- character()
  for (year in year_dirs) {
    year_path <- file.path(base_dir, year)
    raw_dir <- file.path(year_path, "raw")
    
    # Check for data files and layout
    has_data <- any(file.exists(
      file.path(raw_dir, c("CPERV1.TXT", "CPERV2.TXT", "person.txt")),
      file.path(year_path, c("CPERV1.TXT", "CPERV2.TXT"))
    ))
    
    has_layout <- any(file.exists(
      list.files(year_path, pattern = "layout.*\\.xlsx$", 
                 ignore.case = TRUE, full.names = TRUE)
    ))
    
    if (has_data && has_layout) {
      valid_years <- c(valid_years, year)
    }
  }
  
  return(sort(valid_years, decreasing = TRUE))
}

#' Find data and layout files for a year
find_year_files <- function(year, base_dir = "PLFS") {
  year_path <- file.path(base_dir, year)
  raw_dir <- file.path(year_path, "raw")
  
  result <- list()
  
  # Find person data file
  person_patterns <- c("CPERV", "cperv", "person", "PER", "individual")
  person_file <- NULL
  for (pat in person_patterns) {
    matches <- list.files(c(raw_dir, year_path), 
                         pattern = paste0(pat, ".*\\.TXT$"),
                         ignore.case = TRUE, full.names = TRUE)
    if (length(matches) > 0) {
      person_file <- matches[1]
      break
    }
  }
  
  # Find household data file
  hh_patterns <- c("CHHV", "chhv", "household", "HH", "HHV")
  hh_file <- NULL
  for (pat in hh_patterns) {
    matches <- list.files(c(raw_dir, year_path), 
                         pattern = paste0(pat, ".*\\.TXT$"),
                         ignore.case = TRUE, full.names = TRUE)
    if (length(matches) > 0) {
      hh_file <- matches[1]
      break
    }
  }
  
  # Find layout file
  layout_files <- list.files(year_path, pattern = "layout.*\\.xlsx$",
                            ignore.case = TRUE, full.names = TRUE)
  layout_file <- if (length(layout_files) > 0) layout_files[1] else NULL
  
  return(list(
    person = person_file,
    household = hh_file,
    layout = layout_file,
    year_path = year_path
  ))
}

#' Create output directory structure
create_output_dirs <- function(year) {
  base_dir <- file.path("outputs", paste0("plfs_", year))
  
  dirs <- list(
    base = base_dir,
    tables = file.path(base_dir, "tables"),
    figures = file.path(base_dir, "figures"),
    data = file.path(base_dir, "data")
  )
  
  for (d in dirs) {
    if (!dir.exists(d)) {
      dir.create(d, recursive = TRUE)
    }
  }
  
  return(dirs)
}

#' Recode sex variable to labels
recode_sex <- function(data, sex_var) {
  if (is.numeric(data[[sex_var]])) {
    data[[sex_var]] <- ifelse(data[[sex_var]] == 1, "Male", 
                             ifelse(data[[sex_var]] == 2, "Female", "Other"))
  }
  return(data)
}

#' Recode sector variable to labels
recode_sector <- function(data, sector_var) {
  if (is.numeric(data[[sector_var]])) {
    data[[sector_var]] <- ifelse(data[[sector_var]] == 1, "Rural", 
                                ifelse(data[[sector_var]] == 2, "Urban", "Other"))
  }
  return(data)
}

# ============================================================================
# Main Analysis Functions
# ============================================================================

#' Parse raw data for a year
parse_year_data <- function(year, files) {
  cat(sprintf("\n--- Parsing data for %s ---\n", year))
  
  results <- list()
  
  # Parse person data
  if (!is.null(files$person) && file.exists(files$person)) {
    cat("  Parsing person data...\n")
    tryCatch({
      results$persons <- read_microdata(
        data_file = files$person,
        layout_file = files$layout
      )
      cat(sprintf("    ✓ Loaded %s persons\n", 
                  format(nrow(results$persons), big.mark = ",")))
    }, error = function(e) {
      warning(sprintf("Failed to parse person data: %s", e$message))
    })
  } else {
    cat("  ✗ Person data file not found\n")
  }
  
  # Parse household data
  if (!is.null(files$household) && file.exists(files$household)) {
    cat("  Parsing household data...\n")
    tryCatch({
      results$households <- read_microdata(
        data_file = files$household,
        layout_file = files$layout
      )
      cat(sprintf("    ✓ Loaded %s households\n", 
                  format(nrow(results$households), big.mark = ",")))
    }, error = function(e) {
      warning(sprintf("Failed to parse household data: %s", e$message))
    })
  } else {
    cat("  ✗ Household data file not found\n")
  }
  
  return(results)
}

#' Calculate all indicators for a dataset
calculate_all_indicators <- function(data, design, year, output_dirs) {
  cat("\n--- Calculating Labour Force Indicators ---\n")
  
  results <- list()
  
  # Detect key variables
  sex_var <- detect_variable(data, "sex")
  state_var <- detect_variable(data, "state")
  sector_var <- detect_variable(data, "sector")
  age_var <- detect_variable(data, "age")
  
  # 1. Overall indicators (age 15+)
  cat("  1. Overall indicators (age 15+)...\n")
  results$overall <- calc_all_indicators(
    design, 
    by = NULL, 
    approach = APPROACH,
    age_filter = AGE_FILTER
  )
  results$overall$year <- year
  
  # 2. By Sex
  if (!is.na(sex_var)) {
    cat("  2. By Sex...\n")
    results$by_sex <- calc_all_indicators(
      design, 
      by = sex_var, 
      approach = APPROACH,
      age_filter = AGE_FILTER
    )
    results$by_sex <- recode_sex(results$by_sex, sex_var)
    results$by_sex$year <- year
  }
  
  # 3. By Sector (Rural/Urban)
  if (!is.na(sector_var)) {
    cat("  3. By Sector...\n")
    results$by_sector <- calc_all_indicators(
      design, 
      by = sector_var, 
      approach = APPROACH,
      age_filter = AGE_FILTER
    )
    results$by_sector <- recode_sector(results$by_sector, sector_var)
    results$by_sector$year <- year
  }
  
  # 4. By Sex x Sector
  if (!is.na(sex_var) && !is.na(sector_var)) {
    cat("  4. By Sex and Sector...\n")
    results$by_sex_sector <- calc_all_indicators(
      design, 
      by = c(sex_var, sector_var), 
      approach = APPROACH,
      age_filter = AGE_FILTER
    )
    results$by_sex_sector <- recode_sex(results$by_sex_sector, sex_var)
    results$by_sex_sector <- recode_sector(results$by_sex_sector, sector_var)
    results$by_sex_sector$year <- year
  }
  
  # 5. By State
  if (!is.na(state_var)) {
    cat("  5. By State...\n")
    results$by_state <- calc_all_indicators(
      design, 
      by = state_var, 
      approach = APPROACH,
      age_filter = AGE_FILTER
    )
    results$by_state$year <- year
    
    # Add state names if available
    tryCatch({
      state_codes <- load_state_codes()
      setnames(results$by_state, state_var, "state_code", skip_absent = TRUE)
      results$by_state <- merge(
        results$by_state, 
        state_codes[, .(state_code, state_name)],
        by = "state_code", all.x = TRUE
      )
    }, error = function(e) {
      cat("    (State names not available)\n")
    })
  }
  
  # 6. By Age Groups
  if (!is.na(age_var)) {
    cat("  6. By Age Groups...\n")
    # Create age groups
    design_with_age <- design %>%
      mutate(age_group = case_when(
        !!sym(age_var) < 15 ~ "0-14",
        !!sym(age_var) >= 15 & !!sym(age_var) < 25 ~ "15-24",
        !!sym(age_var) >= 25 & !!sym(age_var) < 35 ~ "25-34",
        !!sym(age_var) >= 35 & !!sym(age_var) < 45 ~ "35-44",
        !!sym(age_var) >= 45 & !!sym(age_var) < 55 ~ "45-54",
        !!sym(age_var) >= 55 & !!sym(age_var) < 65 ~ "55-64",
        !!sym(age_var) >= 65 ~ "65+",
        TRUE ~ NA_character_
      ))
    
    results$by_age <- calc_all_indicators(
      design_with_age, 
      by = "age_group", 
      approach = APPROACH,
      age_filter = NULL  # Already filtered by age_group creation
    )
    results$by_age <- results$by_age[!is.na(age_group)]
    results$by_age$year <- year
  }
  
  # 7. Youth indicators (age 15-29)
  cat("  7. Youth indicators (age 15-29)...\n")
  results$youth <- calc_all_indicators(
    design, 
    by = NULL, 
    approach = APPROACH,
    age_filter = c(15, 29)
  )
  results$youth$year <- year
  results$youth$group <- "Youth (15-29)"
  
  # 8. Prime age indicators (age 25-54)
  cat("  8. Prime age indicators (age 25-54)...\n")
  results$prime_age <- calc_all_indicators(
    design, 
    by = NULL, 
    approach = APPROACH,
    age_filter = c(25, 54)
  )
  results$prime_age$year <- year
  results$prime_age$group <- "Prime Age (25-54)"
  
  return(results)
}

#' Export all results to tables
export_results <- function(results, year, output_dirs) {
  cat("\n--- Exporting Results ---\n")
  
  # Export each result table
  for (name in names(results)) {
    if (is.null(results[[name]])) next
    
    data <- results[[name]]
    filename <- paste0("indicators_", name)
    
    # CSV export
    if ("csv" %in% OUTPUT_FORMATS) {
      csv_path <- file.path(output_dirs$tables, paste0(filename, ".csv"))
      fwrite(data, csv_path)
      cat(sprintf("  ✓ CSV: %s\n", basename(csv_path)))
    }
    
    # Word export
    if ("docx" %in% OUTPUT_FORMATS) {
      tryCatch({
        docx_path <- file.path(output_dirs$tables, paste0(filename, ".docx"))
        
        # Create flextable
        ft <- flextable(as.data.frame(data)) %>%
          autofit() %>%
          theme_vanilla()
        
        save_as_docx(ft, path = docx_path)
        cat(sprintf("  ✓ DOCX: %s\n", basename(docx_path)))
      }, error = function(e) {
        cat(sprintf("  ✗ DOCX failed for %s: %s\n", name, e$message))
      })
    }
  }
  
  # Combined summary table
  cat("  Creating combined summary...\n")
  summary_data <- rbindlist(list(
    results$overall[, .(year, group = "Overall (15+)", lfpr, wpr, ur, n)],
    results$youth[, .(year, group, lfpr, wpr, ur, n)],
    results$prime_age[, .(year, group, lfpr, wpr, ur, n)]
  ), use.names = TRUE, fill = TRUE)
  
  fwrite(summary_data, file.path(output_dirs$tables, "summary_key_groups.csv"))
  cat("  ✓ Summary table exported\n")
}

#' Create visualizations
create_visualizations <- function(results, year, output_dirs) {
  cat("\n--- Creating Visualizations ---\n")
  
  # 1. Overall indicators bar chart
  if (!is.null(results$overall)) {
    cat("  1. Overall indicators chart...\n")
    
    plot_data <- data.table(
      indicator = c("LFPR", "WPR", "UR"),
      value = c(results$overall$lfpr[1], 
                results$overall$wpr[1], 
                results$overall$ur[1])
    )
    
    p <- ggplot(plot_data, aes(x = indicator, y = value, fill = indicator)) +
      geom_col(width = 0.6) +
      geom_text(aes(label = sprintf("%.1f%%", value)), vjust = -0.5, size = 4) +
      scale_fill_manual(values = c("LFPR" = "#2E5B88", 
                                   "WPR" = "#6B8E23", 
                                   "UR" = "#E57200")) +
      labs(
        title = paste("Labour Force Indicators - India", year),
        subtitle = "Age 15+ population",
        x = NULL,
        y = "Percentage",
        caption = "Source: PLFS microdata analysis"
      ) +
      scale_y_continuous(labels = function(x) paste0(x, "%"), limits = c(0, 100)) +
      theme_publication() +
      theme(legend.position = "none")
    
    save_figure(p, "01_overall_indicators", 
                output_dir = output_dirs$figures,
                formats = FIGURE_FORMATS, width = 6, height = 5)
  }
  
  # 2. By Sex comparison
  if (!is.null(results$by_sex) && nrow(results$by_sex) > 0) {
    cat("  2. By Sex comparison chart...\n")
    
    sex_var <- names(results$by_sex)[1]
    plot_data <- melt(results$by_sex, 
                     id.vars = c(sex_var, "year"),
                     measure.vars = c("lfpr", "wpr", "ur"),
                     variable.name = "indicator",
                     value.name = "value")
    
    p <- ggplot(plot_data, aes(x = indicator, y = value, 
                              fill = !!sym(sex_var))) +
      geom_col(position = position_dodge(width = 0.8), width = 0.7) +
      geom_text(aes(label = sprintf("%.1f", value)), 
                position = position_dodge(width = 0.8),
                vjust = -0.5, size = 3) +
      scale_fill_manual(values = c("Male" = "#2E5B88", "Female" = "#E57200")) +
      labs(
        title = paste("Labour Force Indicators by Sex - India", year),
        subtitle = "Age 15+ population",
        x = NULL,
        y = "Percentage",
        fill = "Sex",
        caption = "Source: PLFS microdata analysis"
      ) +
      scale_y_continuous(labels = function(x) paste0(x, "%")) +
      scale_x_discrete(labels = c("lfpr" = "LFPR", "wpr" = "WPR", "ur" = "UR")) +
      theme_publication()
    
    save_figure(p, "02_by_sex", 
                output_dir = output_dirs$figures,
                formats = FIGURE_FORMATS, width = 7, height = 5)
  }
  
  # 3. By Sector comparison
  if (!is.null(results$by_sector) && nrow(results$by_sector) > 0) {
    cat("  3. By Sector comparison chart...\n")
    
    sector_var <- names(results$by_sector)[1]
    plot_data <- melt(results$by_sector, 
                     id.vars = c(sector_var, "year"),
                     measure.vars = c("lfpr", "wpr", "ur"),
                     variable.name = "indicator",
                     value.name = "value")
    
    p <- ggplot(plot_data, aes(x = indicator, y = value, 
                              fill = !!sym(sector_var))) +
      geom_col(position = position_dodge(width = 0.8), width = 0.7) +
      geom_text(aes(label = sprintf("%.1f", value)), 
                position = position_dodge(width = 0.8),
                vjust = -0.5, size = 3) +
      scale_fill_manual(values = c("Rural" = "#6B8E23", "Urban" = "#2E5B88")) +
      labs(
        title = paste("Labour Force Indicators by Sector - India", year),
        subtitle = "Age 15+ population",
        x = NULL,
        y = "Percentage",
        fill = "Sector",
        caption = "Source: PLFS microdata analysis"
      ) +
      scale_y_continuous(labels = function(x) paste0(x, "%")) +
      scale_x_discrete(labels = c("lfpr" = "LFPR", "wpr" = "WPR", "ur" = "UR")) +
      theme_publication()
    
    save_figure(p, "03_by_sector", 
                output_dir = output_dirs$figures,
                formats = FIGURE_FORMATS, width = 7, height = 5)
  }
  
  # 4. By Sex x Sector (faceted)
  if (!is.null(results$by_sex_sector) && nrow(results$by_sex_sector) > 0) {
    cat("  4. By Sex and Sector chart...\n")
    
    cols <- names(results$by_sex_sector)
    sex_var <- cols[1]
    sector_var <- cols[2]
    
    plot_data <- melt(results$by_sex_sector, 
                     id.vars = c(sex_var, sector_var, "year"),
                     measure.vars = c("lfpr", "wpr", "ur"),
                     variable.name = "indicator",
                     value.name = "value")
    
    p <- ggplot(plot_data, aes(x = !!sym(sex_var), y = value, 
                              fill = !!sym(sector_var))) +
      geom_col(position = position_dodge(width = 0.8), width = 0.7) +
      facet_wrap(~indicator, labeller = labeller(indicator = c(
        "lfpr" = "LFPR", "wpr" = "WPR", "ur" = "UR"
      ))) +
      scale_fill_manual(values = c("Rural" = "#6B8E23", "Urban" = "#2E5B88")) +
      labs(
        title = paste("Labour Force Indicators by Sex and Sector - India", year),
        subtitle = "Age 15+ population",
        x = NULL,
        y = "Percentage",
        fill = "Sector",
        caption = "Source: PLFS microdata analysis"
      ) +
      scale_y_continuous(labels = function(x) paste0(x, "%")) +
      theme_facet()
    
    save_figure(p, "04_by_sex_sector", 
                output_dir = output_dirs$figures,
                formats = FIGURE_FORMATS, width = 10, height = 4)
  }
  
  # 5. By State (horizontal bar chart for UR)
  if (!is.null(results$by_state) && nrow(results$by_state) > 1) {
    cat("  5. By State chart...\n")
    
    state_col <- if ("state_name" %in% names(results$by_state)) "state_name" else names(results$by_state)[1]
    
    # UR by state
    plot_data <- copy(results$by_state)
    setorderv(plot_data, "ur", order = 1)
    plot_data[[state_col]] <- factor(plot_data[[state_col]], 
                                     levels = plot_data[[state_col]])
    
    p <- ggplot(plot_data, aes(x = ur, y = !!sym(state_col))) +
      geom_col(fill = "#2E5B88", width = 0.7) +
      geom_text(aes(label = sprintf("%.1f", ur)), 
                hjust = -0.2, size = 2.5) +
      labs(
        title = paste("Unemployment Rate by State - India", year),
        subtitle = "Age 15+ population",
        x = "Unemployment Rate (%)",
        y = NULL,
        caption = "Source: PLFS microdata analysis"
      ) +
      scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
      theme_publication() +
      theme(panel.grid.major.y = element_blank())
    
    save_figure(p, "05_ur_by_state", 
                output_dir = output_dirs$figures,
                formats = FIGURE_FORMATS, width = 8, height = 12)
  }
  
  # 6. By Age Group
  if (!is.null(results$by_age) && nrow(results$by_age) > 0) {
    cat("  6. By Age Group chart...\n")
    
    plot_data <- melt(results$by_age, 
                     id.vars = c("age_group", "year"),
                     measure.vars = c("lfpr", "wpr", "ur"),
                     variable.name = "indicator",
                     value.name = "value")
    
    # Ensure proper age group ordering
    age_order <- c("0-14", "15-24", "25-34", "35-44", "45-54", "55-64", "65+")
    plot_data$age_group <- factor(plot_data$age_group, levels = age_order)
    plot_data <- plot_data[!is.na(age_group)]
    
    p <- ggplot(plot_data, aes(x = age_group, y = value, 
                              color = indicator, group = indicator)) +
      geom_line(linewidth = 1) +
      geom_point(size = 2) +
      scale_color_manual(values = c("lfpr" = "#2E5B88", 
                                   "wpr" = "#6B8E23", 
                                   "ur" = "#E57200"),
                        labels = c("LFPR", "WPR", "UR")) +
      labs(
        title = paste("Labour Force Indicators by Age Group - India", year),
        x = "Age Group",
        y = "Percentage",
        color = "Indicator",
        caption = "Source: PLFS microdata analysis"
      ) +
      scale_y_continuous(labels = function(x) paste0(x, "%")) +
      theme_publication()
    
    save_figure(p, "06_by_age_group", 
                output_dir = output_dirs$figures,
                formats = FIGURE_FORMATS, width = 8, height = 5)
  }
  
  cat("  ✓ All visualizations created\n")
}

#' Save processed data
save_processed_data <- function(data, design, year, output_dirs) {
  cat("\n--- Saving Processed Data ---\n")
  
  # Save as Parquet (efficient format)
  if (!is.null(data$persons)) {
    parquet_path <- file.path(output_dirs$data, "persons.parquet")
    arrow::write_parquet(data$persons, parquet_path)
    cat(sprintf("  ✓ Persons data: %s\n", basename(parquet_path)))
  }
  
  if (!is.null(data$households)) {
    parquet_path <- file.path(output_dirs$data, "households.parquet")
    arrow::write_parquet(data$households, parquet_path)
    cat(sprintf("  ✓ Households data: %s\n", basename(parquet_path)))
  }
  
  # Save survey design info
  design_info <- list(
    year = year,
    n_observations = nrow(design),
    sum_weights = sum(weights(design)),
    estimated_population_millions = round(sum(weights(design)) / 1e6, 2),
    strata = if (!is.null(design$strata)) length(unique(design$strata)) else NA,
    clusters = if (!is.null(design$cluster)) length(unique(design$cluster[[1]])) else NA
  )
  
  info_path <- file.path(output_dirs$data, "survey_design_info.csv")
  fwrite(as.data.table(design_info), info_path)
  cat(sprintf("  ✓ Survey design info: %s\n", basename(info_path)))
}

# ============================================================================
# Main Execution
# ============================================================================

cat("\n========================================\n")
cat("Discovering Available Datasets\n")
cat("========================================\n")

# Discover available years
available_years <- discover_plfs_years()

if (length(available_years) == 0) {
  stop("No valid PLFS datasets found. Please ensure data files are in PLFS/YYYY-YY/ folders.")
}

cat(sprintf("Found %d year(s) with valid data:\n", length(available_years)))
cat(paste("  -", available_years, collapse = "\n"))
cat("\n")

# Process each year
all_results <- list()

for (year in available_years) {
  cat("\n")
  cat("╔════════════════════════════════════════════════════════════╗\n")
  cat(sprintf("║  PROCESSING YEAR: %-40s ║\n", year))
  cat("╚════════════════════════════════════════════════════════════╝\n")
  
  # Find files for this year
  files <- find_year_files(year)
  
  if (is.null(files$person) || is.null(files$layout)) {
    cat(sprintf("✗ Skipping %s - missing required files\n", year))
    next
  }
  
  cat(sprintf("\nData file: %s\n", basename(files$person)))
  cat(sprintf("Layout file: %s\n", basename(files$layout)))
  
  # Create output directories
  output_dirs <- create_output_dirs(year)
  cat(sprintf("Output directory: %s\n", output_dirs$base))
  
  # Step 1: Parse data
  parsed_data <- parse_year_data(year, files)
  
  if (is.null(parsed_data$persons)) {
    cat(sprintf("✗ Skipping %s - could not parse person data\n", year))
    next
  }
  
  # Step 2: Create survey design
  cat("\n--- Creating Survey Design ---\n")
  design <- create_plfs_design(parsed_data$persons, level = "person")
  survey_design_summary(design)
  
  # Step 3: Calculate indicators
  results <- calculate_all_indicators(parsed_data$persons, design, year, output_dirs)
  all_results[[year]] <- results
  
  # Step 4: Export tables
  export_results(results, year, output_dirs)
  
  # Step 5: Create visualizations
  create_visualizations(results, year, output_dirs)
  
  # Step 6: Save processed data
  save_processed_data(parsed_data, design, year, output_dirs)
  
  cat("\n")
  cat(sprintf("✓ Year %s processing complete!\n", year))
  cat(sprintf("  Outputs saved to: %s\n", output_dirs$base))
}

# ============================================================================
# Cross-Year Summary (if multiple years processed)
# ============================================================================

if (length(all_results) > 1) {
  cat("\n========================================\n")
  cat("Creating Cross-Year Summary\n")
  cat("========================================\n")
  
  # Combine overall indicators across years
  overall_combined <- rbindlist(
    lapply(names(all_results), function(y) all_results[[y]]$overall),
    use.names = TRUE, fill = TRUE
  )
  
  # Save combined summary
  summary_dir <- "outputs/plfs_summary"
  if (!dir.exists(summary_dir)) {
    dir.create(summary_dir, recursive = TRUE)
  }
  
  fwrite(overall_combined, file.path(summary_dir, "overall_indicators_all_years.csv"))
  cat(sprintf("✓ Cross-year summary saved to: %s\n", summary_dir))
  
  # Create trend visualization
  cat("\nCreating trend visualization...\n")
  
  plot_data <- melt(overall_combined, 
                   id.vars = "year",
                   measure.vars = c("lfpr", "wpr", "ur"),
                   variable.name = "indicator",
                   value.name = "value")
  
  p <- ggplot(plot_data, aes(x = year, y = value, 
                            color = indicator, group = indicator)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    scale_color_manual(values = c("lfpr" = "#2E5B88", 
                                 "wpr" = "#6B8E23", 
                                 "ur" = "#E57200"),
                      labels = c("LFPR", "WPR", "UR")) +
    labs(
      title = "Labour Force Indicators Trend - India",
      subtitle = "Age 15+ population",
      x = "Year",
      y = "Percentage",
      color = "Indicator",
      caption = "Source: PLFS microdata analysis"
    ) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    theme_publication()
  
  save_figure(p, "trend_all_years", 
              output_dir = summary_dir,
              formats = FIGURE_FORMATS, width = 8, height = 5)
}

# ============================================================================
# Completion Summary
# ============================================================================

cat("\n")
cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║           AUTOMATED ANALYSIS COMPLETE                      ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n")
cat("\n")

cat("Summary:\n")
cat(sprintf("  Years processed: %d\n", length(all_results)))
for (year in names(all_results)) {
  cat(sprintf("    - %s: %d indicator tables generated\n", 
              year, length(all_results[[year]])))
}

cat("\nOutput Locations:\n")
for (year in names(all_results)) {
  cat(sprintf("  %s: outputs/plfs_%s/\n", year, year))
}

if (length(all_results) > 1) {
  cat(sprintf("  Cross-year summary: outputs/plfs_summary/\n"))
}

cat("\nGenerated Files:\n")
cat("  - CSV tables with indicators\n")
cat("  - Word documents (.docx) with formatted tables\n")
cat("  - PDF and PNG visualizations\n")
cat("  - Processed data in Parquet format\n")
cat("  - Survey design information\n")

cat("\nKey Indicators Calculated:\n")
cat("  - LFPR: Labour Force Participation Rate\n")
cat("  - WPR: Worker Population Ratio (Employment Rate)\n")
cat("  - UR: Unemployment Rate\n")

cat("\nDisaggregations:\n")
cat("  - By Sex (Male/Female)\n")
cat("  - By Sector (Rural/Urban)\n")
cat("  - By State\n")
cat("  - By Age Group\n")
cat("  - By Sex x Sector\n")

cat("\n✓ Analysis complete! Check the outputs/ directory for results.\n")
cat("\n")
