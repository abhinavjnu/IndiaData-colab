# ============================================================================
# 02_read_microdata.R - Fixed-Width File Parser for Indian Survey Data
# ============================================================================
# Reads fixed-width text files from microdata.gov.in using Data_Layout.xlsx
# 
# PLFS/NSS/HCES data comes as:
#   - TXT file: Fixed-width format (no delimiters)
#   - Data_Layout.xlsx: Column specifications (start, end, width, name)
#
# Usage:
#   source("R/01_config.R")
#   source("R/03_read_microdata.R")
#   
#   # Read PLFS person-level data
#   persons <- read_microdata(
#     data_file = "data/raw/PLFS_2022-23_Person.txt",
#     layout_file = "data/raw/Data_Layout_Person.xlsx"
#   )
#
#   # Or use auto-detection
#   persons <- read_plfs_data("data/raw/", level = "person")
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(readxl)
  library(arrow)
  library(progress)  # For progress bars
})

# ============================================================================
# Layout File Parsing
# ============================================================================

#' Parse Data_Layout.xlsx to get column specifications
#' @param layout_file Path to Data_Layout.xlsx
#' @param sheet Sheet name or number (default: 1)
#' @param skip Number of rows to skip (for layouts with title rows)
#' @return data.table with column specifications
parse_layout <- function(layout_file, sheet = 1, skip = NULL) {
  
  if (!file.exists(layout_file)) {
    stop(paste("Layout file not found:", layout_file))
  }
  
  message(sprintf("Parsing layout file: %s (sheet: %s)", basename(layout_file), sheet))
  
  # Try reading with different skip values if not specified
  if (is.null(skip)) {
    # First try without skip
    layout <- as.data.table(read_excel(layout_file, sheet = sheet))
    
    # Check if first row looks like a title (has unnamed columns starting with "...")
    if (any(grepl("^\\.\\.\\.\\d+$", names(layout)))) {
      message("  Detected title row, skipping first row...")
      layout <- as.data.table(read_excel(layout_file, sheet = sheet, skip = 1))
    }
  } else {
    layout <- as.data.table(read_excel(layout_file, sheet = sheet, skip = skip))
  }
  
  # Standardize column names (different surveys may use different names)
  names(layout) <- tolower(trimws(names(layout)))
  names(layout) <- gsub("[^a-z0-9]", "_", names(layout))
  names(layout) <- gsub("_+", "_", names(layout))
  names(layout) <- gsub("^_|_$", "", names(layout))
  
  message(sprintf("  Layout columns: %s", paste(names(layout), collapse = ", ")))
  
  # Try to identify key columns - expanded list for PLFS format
  name_cols <- c("variable_name", "var_name", "name", "variable", "field_name", 
                 "column_name", "item", "variable_label", "full_name")
  start_cols <- c("start", "from", "start_col", "begin", "start_position", 
                  "starting_position", "col_start")
  end_cols <- c("end", "to", "end_col", "finish", "end_position", 
                "ending_position", "col_end")
  width_cols <- c("width", "length", "size", "field_length", "col_width")
  
  # Find matching columns
  name_col <- intersect(names(layout), name_cols)[1]
  start_col <- intersect(names(layout), start_cols)[1]
  end_col <- intersect(names(layout), end_cols)[1]
  width_col <- intersect(names(layout), width_cols)[1]
  
  message(sprintf("  Detected: name_col=%s, width_col=%s, start_col=%s", 
                  ifelse(is.na(name_col), "NA", name_col),
                  ifelse(is.na(width_col), "NA", width_col),
                  ifelse(is.na(start_col), "NA", start_col)))
  
  # Validate we have required columns
  if (is.na(name_col)) {
    stop("Could not find variable name column in layout file. 
         Expected one of: ", paste(name_cols, collapse = ", "),
         "\nActual columns: ", paste(names(layout), collapse = ", "))
  }
  
  if (is.na(start_col) && is.na(width_col)) {
    stop("Could not find start position or width column in layout file.
         Expected start column: ", paste(start_cols, collapse = ", "), "
         Or width column: ", paste(width_cols, collapse = ", "),
         "\nActual columns: ", paste(names(layout), collapse = ", "))
  }
  
  # Build standardized layout
  result <- data.table(
    var_name = as.character(layout[[name_col]])
  )
  
  # Add start position
  if (!is.na(start_col)) {
    result[, start := as.integer(layout[[start_col]])]
  }
  
  # Add end position
  if (!is.na(end_col)) {
    result[, end := as.integer(layout[[end_col]])]
  }
  
  # Add or calculate width
  if (!is.na(width_col)) {
    result[, width := as.integer(layout[[width_col]])]
  } else if (!is.na(start_col) && !is.na(end_col)) {
    result[, width := end - start + 1]
  }
  
  # Remove rows with missing width before calculating positions
  result <- result[!is.na(width) & width > 0]
  result <- result[!is.na(var_name) & var_name != ""]
  
  # Calculate missing start/end if needed (cumulative positions)
  if (is.na(start_col) && !is.na(width_col)) {
    result[, start := cumsum(c(1L, width[-.N]))]
    result[, end := start + width - 1L]
  }
  
  if (is.na(end_col) && !is.na(start_col) && !is.na(width_col)) {
    result[, end := start + width - 1L]
  }
  
  # Clean variable names (make valid R names)
  result[, var_name_clean := make.names(var_name, unique = TRUE)]
  result[, var_name_clean := gsub("\\.+", "_", var_name_clean)]
  result[, var_name_clean := gsub("_+", "_", var_name_clean)]
  result[, var_name_clean := gsub("^_|_$", "", var_name_clean)]
  
  # Final validation
  result <- result[!is.na(start) & !is.na(width) & width > 0]
  
  # Sort by start position
  setorder(result, start)
  
  # Verify total width matches expected
  total_width <- max(result$end)
  message(sprintf("  Found %d variables (total width: %d characters)", 
                  nrow(result), total_width))
  
  return(result)
}

# ============================================================================
# Fixed-Width File Reading
# ============================================================================

#' Read a fixed-width microdata file using layout specifications
#' @param data_file Path to the TXT data file
#' @param layout_file Path to Data_Layout.xlsx
#' @param layout Optional: pre-parsed layout (if already parsed)
#' @param nrows Number of rows to read (-1 for all, default)
#' @param skip Number of rows to skip at start (default: 0)
#' @param use_clean_names Use cleaned variable names (default: TRUE)
#' @param convert_types Attempt to convert to numeric where appropriate (default: TRUE)
#' @return data.table with the survey data
read_microdata <- function(data_file, 
                           layout_file = NULL, 
                           layout = NULL,
                           nrows = -1,
                           skip = 0,
                           use_clean_names = TRUE,
                           convert_types = TRUE) {
  
  # Validate inputs
  if (!file.exists(data_file)) {
    stop(paste("Data file not found:", data_file))
  }
  
  # Get layout
  if (is.null(layout)) {
    if (is.null(layout_file)) {
      stop("Must provide either layout_file or layout")
    }
    layout <- parse_layout(layout_file)
  }
  
  message(sprintf("Reading: %s", basename(data_file)))
  
  # Get file size for progress info
  file_size_mb <- file.size(data_file) / 1024^2
  message(sprintf("File size: %.1f MB", file_size_mb))
  
  # Build column specifications for fread
  # fread doesn't directly support fixed-width, so we read as single column
  # then use substr to extract fields
  
  # Read raw lines
  message("Reading raw data...")
  
  if (nrows > 0) {
    raw <- fread(data_file, 
                 header = FALSE, 
                 sep = "\n", 
                 nrows = nrows + skip,
                 skip = skip,
                 col.names = "line",
                 colClasses = "character")
  } else {
    raw <- fread(data_file, 
                 header = FALSE, 
                 sep = "\n",
                 skip = skip,
                 col.names = "line",
                 colClasses = "character")
  }
  
  message(sprintf("Read %s rows", format(nrow(raw), big.mark = ",")))
  
  # Extract each variable using substr
  message("Parsing fixed-width columns...")
  
  # Choose column names
  col_names <- if (use_clean_names) layout$var_name_clean else layout$var_name
  
  # Create progress bar
  pb <- progress_bar$new(
    format = "  Parsing [:bar] :percent | :current/:total columns | ETA: :eta",
    total = nrow(layout), clear = FALSE, width = 60
  )
  
  # Extract columns
  for (i in seq_len(nrow(layout))) {
    var_name <- col_names[i]
    start_pos <- layout$start[i]
    end_pos <- layout$end[i]
    
    # Extract and trim whitespace
    raw[, (var_name) := trimws(substr(line, start_pos, end_pos))]
    
    # Update progress bar
    pb$tick()
  }
  
  # Remove the raw line column
  raw[, line := NULL]
  
  # Convert types if requested
  if (convert_types) {
    message("Converting data types...")
    
    # Create progress bar for type conversion
    cols_to_convert <- names(raw)
    pb_conv <- progress_bar$new(
      format = "  Converting [:bar] :percent | :current/:total columns",
      total = length(cols_to_convert), clear = FALSE, width = 60
    )
    
    for (col in cols_to_convert) {
      # Get sample of non-empty values
      sample_vals <- raw[!is.na(get(col)) & get(col) != "", get(col)][1:min(100, .N)]
      
      if (length(sample_vals) > 0) {
        # Check if all values are numeric
        numeric_check <- suppressWarnings(as.numeric(sample_vals))
        
        if (all(!is.na(numeric_check))) {
          # Convert to numeric
          raw[, (col) := as.numeric(get(col))]
        }
      }
      
      pb_conv$tick()
    }
  }
  
  # Report memory usage
  mem_mb <- object.size(raw) / 1024^2
  message(sprintf("Data loaded: %s rows x %d columns (%.1f MB in memory)",
                  format(nrow(raw), big.mark = ","), ncol(raw), mem_mb))
  
  return(raw)
}

# ============================================================================
# Convenience Functions for PLFS
# ============================================================================

#' Auto-detect and read PLFS data files
#' @param data_dir Directory containing PLFS files
#' @param level "person" or "household"
#' @param year Optional year (for directory organization)
#' @return data.table with PLFS data
read_plfs_data <- function(data_dir, level = c("person", "household"), year = NULL) {
  
  level <- match.arg(level)
  
  # Common PLFS file naming patterns
  person_patterns <- c("person", "per", "cperv", "individual", "member")
  hh_patterns <- c("household", "hh", "chhv", "dwelling")
  
  patterns <- if (level == "person") person_patterns else hh_patterns
  
  # Find data file
  all_files <- list.files(data_dir, pattern = "\\.txt$", ignore.case = TRUE, full.names = TRUE)
  
  data_file <- NULL
  for (pat in patterns) {
    matches <- all_files[grepl(pat, basename(all_files), ignore.case = TRUE)]
    if (length(matches) > 0) {
      data_file <- matches[1]
      break
    }
  }
  
  if (is.null(data_file)) {
    stop(sprintf("Could not find %s-level data file in: %s\nFiles found: %s",
                 level, data_dir, paste(basename(all_files), collapse = ", ")))
  }
  
  # Find layout file
  layout_files <- list.files(data_dir, pattern = "layout.*\\.xlsx$", ignore.case = TRUE, full.names = TRUE)
  
  layout_file <- NULL
  for (pat in patterns) {
    matches <- layout_files[grepl(pat, basename(layout_files), ignore.case = TRUE)]
    if (length(matches) > 0) {
      layout_file <- matches[1]
      break
    }
  }
  
  # If no specific layout, try generic
  if (is.null(layout_file) && length(layout_files) > 0) {
    layout_file <- layout_files[1]
    message("Using generic layout file: ", basename(layout_file))
  }
  
  if (is.null(layout_file)) {
    stop(sprintf("Could not find layout file for %s data in: %s", level, data_dir))
  }
  
  message(sprintf("Auto-detected %s data:", level))
  message(sprintf("  Data: %s", basename(data_file)))
  message(sprintf("  Layout: %s", basename(layout_file)))
  
  return(read_microdata(data_file, layout_file))
}

# ============================================================================
# Data Export Functions
# ============================================================================

#' Save microdata as Parquet (recommended for efficiency)
#' @param data data.table to save
#' @param filename Output filename (without extension)
#' @param dest_dir Destination directory (default: processed data folder)
#' @return Path to saved file
save_as_parquet <- function(data, filename, dest_dir = NULL) {
  
  if (is.null(dest_dir)) {
    dest_dir <- get_path("processed")
  }
  
  if (!dir.exists(dest_dir)) {
    dir.create(dest_dir, recursive = TRUE)
  }
  
  # Ensure .parquet extension
  if (!grepl("\\.parquet$", filename)) {
    filename <- paste0(filename, ".parquet")
  }
  
  filepath <- file.path(dest_dir, filename)
  
  message(sprintf("Saving to Parquet: %s", filepath))
  
  arrow::write_parquet(data, filepath)
  
  # Report compression
  file_size_mb <- file.size(filepath) / 1024^2
  mem_size_mb <- object.size(data) / 1024^2
  compression <- (1 - file_size_mb / mem_size_mb) * 100
  
  message(sprintf("Saved: %.1f MB (%.0f%% compression from %.1f MB in memory)",
                  file_size_mb, compression, mem_size_mb))
  
  return(filepath)
}

#' Load microdata from Parquet
#' @param filename Filename or full path
#' @param src_dir Source directory (default: processed data folder)
#' @return data.table
load_from_parquet <- function(filename, src_dir = NULL) {
  
  # If full path provided
  if (file.exists(filename)) {
    filepath <- filename
  } else {
    if (is.null(src_dir)) {
      src_dir <- get_path("processed")
    }
    
    # Ensure .parquet extension
    if (!grepl("\\.parquet$", filename)) {
      filename <- paste0(filename, ".parquet")
    }
    
    filepath <- file.path(src_dir, filename)
  }
  
  if (!file.exists(filepath)) {
    stop(paste("Parquet file not found:", filepath))
  }
  
  message(sprintf("Loading: %s", basename(filepath)))
  
  data <- as.data.table(arrow::read_parquet(filepath))
  
  message(sprintf("Loaded: %s rows x %d columns",
                  format(nrow(data), big.mark = ","), ncol(data)))
  
  return(data)
}

#' Save microdata as CSV (for compatibility)
#' @param data data.table to save
#' @param filename Output filename
#' @param dest_dir Destination directory
#' @return Path to saved file
save_as_csv <- function(data, filename, dest_dir = NULL) {
  
  if (is.null(dest_dir)) {
    dest_dir <- get_path("processed")
  }
  
  if (!dir.exists(dest_dir)) {
    dir.create(dest_dir, recursive = TRUE)
  }
  
  if (!grepl("\\.csv$", filename)) {
    filename <- paste0(filename, ".csv")
  }
  
  filepath <- file.path(dest_dir, filename)
  
  message(sprintf("Saving to CSV: %s", filepath))
  
  fwrite(data, filepath)
  
  file_size_mb <- file.size(filepath) / 1024^2
  message(sprintf("Saved: %.1f MB", file_size_mb))
  
  return(filepath)
}

# ============================================================================
# Data Inspection Utilities
# ============================================================================

#' Quick summary of microdata
#' @param data data.table with survey data
#' @return Invisibly returns summary statistics
inspect_microdata <- function(data) {
  
  cat("=== Microdata Summary ===\n\n")
  cat(sprintf("Rows: %s\n", format(nrow(data), big.mark = ",")))
  cat(sprintf("Columns: %d\n", ncol(data)))
  cat(sprintf("Memory: %.1f MB\n\n", object.size(data) / 1024^2))
  
  # Column types
  types <- sapply(data, class)
  type_summary <- table(sapply(types, `[`, 1))
  cat("Column types:\n")
  for (t in names(type_summary)) {
    cat(sprintf("  %s: %d\n", t, type_summary[t]))
  }
  
  # Missing values
  missing <- sapply(data, function(x) sum(is.na(x)))
  cols_with_missing <- sum(missing > 0)
  cat(sprintf("\nColumns with missing values: %d of %d\n", cols_with_missing, ncol(data)))
  
  if (cols_with_missing > 0 && cols_with_missing <= 10) {
    cat("Missing counts:\n")
    for (col in names(missing[missing > 0])) {
      cat(sprintf("  %s: %s (%.1f%%)\n", 
                  col, 
                  format(missing[col], big.mark = ","),
                  missing[col] / nrow(data) * 100))
    }
  }
  
  cat("\n")
  invisible(list(
    nrow = nrow(data),
    ncol = ncol(data),
    types = types,
    missing = missing
  ))
}

#' Preview first few rows with all columns
#' @param data data.table
#' @param n Number of rows to show (default: 5)
preview_data <- function(data, n = 5) {
  print(data[1:min(n, nrow(data))], class = TRUE)
}

# ============================================================================
# Startup Message
# ============================================================================

message("Microdata reader loaded. Functions available:")
message("  read_microdata(data_file, layout_file)  - Read fixed-width data")
message("  read_plfs_data(dir, level)              - Auto-detect PLFS files")
message("  save_as_parquet(data, filename)         - Save to Parquet")
message("  load_from_parquet(filename)             - Load from Parquet")
message("  inspect_microdata(data)                 - Quick data summary")
