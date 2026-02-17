# ============================================================================
# 05_codebook_utils.R - Code Lookup Utilities
# ============================================================================
# Functions for decoding numeric codes in survey data (state, industry, etc.)
# Uses the codebook CSV files in data/codebooks/
#
# Usage:
#   source("R/01_config.R")
#   source("R/08_codebook_utils.R")
#   
#   # Decode state codes
#   data <- decode_state(data, "State")
#   
#   # Decode activity status
#   data <- decode_activity(data, "Principal_Status")
#   
#   # Decode industry codes
#   data <- decode_nic(data, "NIC_Code")
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
})

# ============================================================================
# Codebook Loading (cached)
# ============================================================================

# Cache for loaded codebooks
.codebook_cache <- new.env()

#' Load codebook with caching
#' @param name Codebook name: "state", "activity", "nic", "nco"
#' @return data.table with codebook
.load_codebook <- function(name) {
  
  # Check cache
  if (exists(name, envir = .codebook_cache)) {
    return(get(name, envir = .codebook_cache))
  }
  
  # Load from file
  filename <- switch(
    name,
    "state" = "state_codes.csv",
    "activity" = "activity_status.csv",
    "nic" = "nic_2008.csv",
    "nco" = "nco_2015.csv",
    stop(paste("Unknown codebook:", name))
  )
  
  filepath <- codebook_path(filename)
  
  if (!file.exists(filepath)) {
    stop(paste("Codebook file not found:", filepath))
  }
  
  cb <- fread(filepath)
  
  # Validate schema - ensure required columns exist
  required_cols <- switch(
    name,
    "state" = c("state_code", "state_name"),
    "activity" = c("status_code", "status_description", "category"),
    "nic" = c("nic_2digit", "division_name"),
    "nco" = c("nco_1digit", "major_group"),
    character(0)  # No validation for unknown types
  )
  
  if (length(required_cols) > 0) {
    missing_cols <- setdiff(required_cols, names(cb))
    if (length(missing_cols) > 0) {
      stop(sprintf(
        "Malformed codebook '%s': missing required columns: %s\nExpected: %s\nFound: %s",
        name,
        paste(missing_cols, collapse = ", "),
        paste(required_cols, collapse = ", "),
        paste(names(cb), collapse = ", ")
      ))
    }
  }
  
  # Cache and return
  assign(name, cb, envir = .codebook_cache)
  return(cb)
}

# ============================================================================
# State Codes
# ============================================================================

#' Decode state codes to state names
#' @param data data.table
#' @param state_col Name of the state code column
#' @param new_col Name for the new state name column (default: adds "_name")
#' @param keep_code Keep the original code column (default: TRUE)
#' @return data.table with state names added
decode_state <- function(data, 
                          state_col,
                          new_col = NULL,
                          keep_code = TRUE) {
  
  data <- copy(data)
  
  if (is.null(new_col)) {
    new_col <- paste0(state_col, "_name")
  }
  
  # Load codebook
  states <- .load_codebook("state")
  
  # Ensure state code is character for matching
  data[, .state_temp := as.character(get(state_col))]
  data[, .state_temp := sprintf("%02d", as.integer(.state_temp))]  # Pad with zeros
  
  states[, state_code := sprintf("%02d", as.integer(state_code))]
  
  # Merge
  data <- merge(data, states[, .(state_code, state_name)],
                by.x = ".state_temp", by.y = "state_code",
                all.x = TRUE)
  
  # Rename and clean up
  setnames(data, "state_name", new_col)
  data[, .state_temp := NULL]
  
  if (!keep_code) {
    data[, (state_col) := NULL]
  }
  
  message(sprintf("Decoded %d unique state codes", 
                  data[!is.na(get(new_col)), uniqueN(get(new_col))]))
  
  return(data)
}

#' Get state name from code
#' @param code State code (numeric or character)
#' @return State name
get_state_name <- function(code) {
  states <- .load_codebook("state")
  code_str <- sprintf("%02d", as.integer(code))
  states[state_code == code_str, state_name]
}

#' Get state code from name
#' @param name State name (partial match supported)
#' @return State code
get_state_code <- function(name) {
  states <- .load_codebook("state")
  states[grepl(name, state_name, ignore.case = TRUE), state_code]
}

#' List all states with codes
#' @param region Optional: filter by region
#' @return data.table
list_states <- function(region = NULL) {
  states <- .load_codebook("state")
  
  if (!is.null(region)) {
    states <- states[tolower(region) == tolower(region)]
  }
  
  return(states)
}

# ============================================================================
# Activity Status Codes
# ============================================================================

#' Decode activity status codes
#' @param data data.table
#' @param status_col Name of the status code column
#' @param new_col Name for the new description column
#' @param add_category Add activity category column
#' @return data.table with activity descriptions added
decode_activity <- function(data,
                             status_col,
                             new_col = NULL,
                             add_category = TRUE) {
  
  data <- copy(data)
  
  if (is.null(new_col)) {
    new_col <- paste0(status_col, "_desc")
  }
  
  # Load codebook
  activity <- .load_codebook("activity")
  
  # Merge
  data <- merge(data, activity[, .(status_code, status_description, category)],
                by.x = status_col, by.y = "status_code",
                all.x = TRUE)
  
  # Rename
  setnames(data, "status_description", new_col)
  
  if (!add_category) {
    data[, category := NULL]
  } else {
    setnames(data, "category", paste0(status_col, "_category"))
  }
  
  n_decoded <- data[!is.na(get(new_col)), .N]
  n_total <- nrow(data)
  message(sprintf("Decoded %d of %d activity codes (%.1f%%)",
                  n_decoded, n_total, n_decoded / n_total * 100))
  
  return(data)
}

#' Get activity description from code
#' @param code Activity status code
#' @return Description string
get_activity_desc <- function(code) {
  activity <- .load_codebook("activity")
  activity[status_code == as.integer(code), status_description]
}

#' Classify activity status into broad categories
#' @param data data.table
#' @param status_col Status column name
#' @param new_col New column name for broad category
#' @return data.table with broad category added
classify_activity <- function(data, status_col, new_col = "activity_broad") {
  
  data <- copy(data)
  
  data[, (new_col) := fcase(
    get(status_col) %in% c(11, 12, 21), "Self-employed",
    get(status_col) == 31, "Regular wage/salaried",
    get(status_col) %in% c(41, 51), "Casual labour",
    get(status_col) == 61, "Unemployed",
    get(status_col) %in% c(71, 72), "Student",
    get(status_col) %in% c(81, 82), "Domestic duties",
    get(status_col) %in% c(91, 92, 93, 94, 95, 97, 98), "Other not in LF",
    default = NA_character_
  )]
  
  return(data)
}

# ============================================================================
# Industry Codes (NIC)
# ============================================================================

#' Decode NIC (industry) codes
#' @param data data.table
#' @param nic_col Name of the NIC code column
#' @param level Detail level: "division" (2-digit), "section" (1-letter)
#' @return data.table with industry names added
decode_nic <- function(data,
                        nic_col,
                        level = c("division", "section")) {
  
  level <- match.arg(level)
  data <- copy(data)
  
  # Load codebook
  nic <- .load_codebook("nic")
  
  # Extract 2-digit code from whatever format we have
  data[, .nic_2digit := as.integer(substr(as.character(get(nic_col)), 1, 2))]
  
  # Merge
  data <- merge(data, nic,
                by.x = ".nic_2digit", by.y = "nic_2digit",
                all.x = TRUE)
  
  # Rename based on level
  if (level == "division") {
    setnames(data, "division_name", paste0(nic_col, "_industry"))
    data[, c("section", "section_name") := NULL]
  } else {
    setnames(data, "section_name", paste0(nic_col, "_sector"))
    data[, c("division_name") := NULL]
  }
  
  data[, .nic_2digit := NULL]
  
  return(data)
}

#' Get industry name from NIC code
#' @param code NIC code (any length)
#' @return Industry division name
get_industry_name <- function(code) {
  nic <- .load_codebook("nic")
  code_2digit <- as.integer(substr(as.character(code), 1, 2))
  nic[nic_2digit == code_2digit, division_name]
}

#' Get broad sector from NIC code
#' @param code NIC code
#' @return Sector name (section level)
get_sector_name <- function(code) {
  nic <- .load_codebook("nic")
  code_2digit <- as.integer(substr(as.character(code), 1, 2))
  nic[nic_2digit == code_2digit, section_name]
}

#' Classify into 3 broad sectors
#' @param data data.table
#' @param nic_col NIC column name
#' @param new_col New column name
#' @return data.table with broad sector
classify_sector_broad <- function(data, nic_col, new_col = "sector_broad") {
  
  data <- copy(data)
  
  # Extract 2-digit
  data[, .nic_2digit := as.integer(substr(as.character(get(nic_col)), 1, 2))]
  
  data[, (new_col) := fcase(
    .nic_2digit >= 1 & .nic_2digit <= 3, "Primary",      # Agriculture
    .nic_2digit >= 5 & .nic_2digit <= 43, "Secondary",   # Mining + Manufacturing + Construction
    .nic_2digit >= 45, "Tertiary",                       # Services
    default = NA_character_
  )]
  
  data[, .nic_2digit := NULL]
  
  return(data)
}

# ============================================================================
# Occupation Codes (NCO)
# ============================================================================

#' Decode NCO (occupation) codes
#' @param data data.table
#' @param nco_col Name of the NCO code column
#' @return data.table with occupation names added
decode_nco <- function(data, nco_col) {
  
  data <- copy(data)
  
  # Load codebook
  nco <- .load_codebook("nco")
  
  # Extract 1-digit code
  data[, .nco_1digit := as.integer(substr(as.character(get(nco_col)), 1, 1))]
  
  # Merge
  data <- merge(data, nco,
                by.x = ".nco_1digit", by.y = "nco_1digit",
                all.x = TRUE)
  
  # Rename
  setnames(data, "major_group", paste0(nco_col, "_occupation"))
  data[, c(".nco_1digit", "description") := NULL]
  
  return(data)
}

#' Get occupation name from NCO code
#' @param code NCO code
#' @return Major group name
get_occupation_name <- function(code) {
  nco <- .load_codebook("nco")
  code_1digit <- as.integer(substr(as.character(code), 1, 1))
  nco[nco_1digit == code_1digit, major_group]
}

# ============================================================================
# Sex/Gender Codes
# ============================================================================

#' Decode sex codes (1=Male, 2=Female)
#' @param data data.table
#' @param sex_col Sex column name
#' @param new_col New column name (default: replaces original)
#' @return data.table with sex labels
decode_sex <- function(data, sex_col, new_col = NULL) {
  
  data <- copy(data)
  
  if (is.null(new_col)) {
    new_col <- sex_col
  }
  
  data[, (new_col) := fcase(
    get(sex_col) == 1, "Male",
    get(sex_col) == 2, "Female",
    default = NA_character_
  )]
  
  return(data)
}

# ============================================================================
# Sector Codes (Rural/Urban)
# ============================================================================

#' Decode sector codes (1=Rural, 2=Urban)
#' @param data data.table
#' @param sector_col Sector column name
#' @param new_col New column name
#' @return data.table with sector labels
decode_sector <- function(data, sector_col, new_col = NULL) {
  
  data <- copy(data)
  
  if (is.null(new_col)) {
    new_col <- sector_col
  }
  
  data[, (new_col) := fcase(
    get(sector_col) == 1, "Rural",
    get(sector_col) == 2, "Urban",
    default = NA_character_
  )]
  
  return(data)
}

# ============================================================================
# Batch Decoding
# ============================================================================

#' Decode all common codes in one call
#' @param data data.table
#' @param state_col State column (NULL to skip)
#' @param activity_col Activity status column (NULL to skip)
#' @param nic_col NIC column (NULL to skip)
#' @param nco_col NCO column (NULL to skip)
#' @param sex_col Sex column (NULL to skip)
#' @param sector_col Sector column (NULL to skip)
#' @return data.table with all codes decoded
decode_all <- function(data,
                        state_col = NULL,
                        activity_col = NULL,
                        nic_col = NULL,
                        nco_col = NULL,
                        sex_col = NULL,
                        sector_col = NULL) {
  
  data <- copy(data)
  
  if (!is.null(state_col) && state_col %in% names(data)) {
    data <- decode_state(data, state_col)
  }
  
  if (!is.null(activity_col) && activity_col %in% names(data)) {
    data <- decode_activity(data, activity_col)
  }
  
  if (!is.null(nic_col) && nic_col %in% names(data)) {
    data <- decode_nic(data, nic_col)
  }
  
  if (!is.null(nco_col) && nco_col %in% names(data)) {
    data <- decode_nco(data, nco_col)
  }
  
  if (!is.null(sex_col) && sex_col %in% names(data)) {
    data <- decode_sex(data, sex_col)
  }
  
  if (!is.null(sector_col) && sector_col %in% names(data)) {
    data <- decode_sector(data, sector_col)
  }
  
  return(data)
}

# ============================================================================
# Startup Message
# ============================================================================

message("Codebook utilities loaded. Main functions:")
message("  decode_state(data, col)      - State codes to names")
message("  decode_activity(data, col)   - Activity status codes")
message("  decode_nic(data, col)        - Industry (NIC) codes")
message("  decode_nco(data, col)        - Occupation (NCO) codes")
message("  decode_sex(data, col)        - Sex (1/2) to Male/Female")
message("  decode_sector(data, col)     - Sector (1/2) to Rural/Urban")
message("  decode_all(data, ...)        - Decode multiple at once")
