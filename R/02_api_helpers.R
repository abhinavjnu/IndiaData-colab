# ============================================================================
# 02_api_helpers.R - microdata.gov.in API Integration
# ============================================================================
# Functions for downloading survey data from microdata.gov.in API
#
# API Documentation: https://microdata.gov.in/swagger-ui/
#
# Usage:
#   source("R/01_config.R")
#   source("R/02_api_helpers.R")
#
#   # Test connection
#   test_api_connection()
#
#   # Search for datasets
#   datasets <- search_datasets("PLFS 2023")
#
#   # Get files for a dataset
#   files <- get_dataset_files(dataset_id = "2728")
#
#   # Download data file
#   download_datafile(dataset_id = "2728", file_id = "F1")
# ============================================================================

suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
  library(data.table)
})

# ============================================================================
# API Configuration
# ============================================================================

#' Get API configuration with validation
#' @return List with base_url and api_key
#' @export
get_api_config <- function() {
  config <- CONFIG$api

  if (is.null(config$api_key) || config$api_key == "YOUR_API_KEY_HERE") {
    stop(
      "API key not configured.\n",
      "1. Get your API key from: https://microdata.gov.in\n",
      "2. Copy config.yaml.example to config.yaml\n",
      "3. Add your API key to config.yaml"
    )
  }

  return(config)
}

#' Build API request URL
#' @param endpoint API endpoint path
#' @param ... Query parameters
#' @return Full URL string
.build_api_url <- function(endpoint, ...) {
  config <- get_api_config()
  base <- config$base_url

  # Ensure endpoint starts with /
  if (!startsWith(endpoint, "/")) {
    endpoint <- paste0("/", endpoint)
  }

  url <- paste0(base, endpoint)

  # Add query parameters
  params <- list(...)
  if (length(params) > 0) {
    query <- paste(
      sapply(names(params), function(n) paste0(n, "=", params[[n]])),
      collapse = "&"
    )
    url <- paste0(url, "?", query)
  }

  return(url)
}

#' Make authenticated API request
#' @param endpoint API endpoint
#' @param ... Query parameters
#' @return Parsed JSON response
.api_request <- function(endpoint, ...) {
  config <- get_api_config()

  url <- .build_api_url(endpoint, ..., api_key = config$api_key)

  tryCatch(
    {
      response <- request(url) |>
        req_headers(
          "Accept" = "application/json",
          "User-Agent" = "IndiaData-R-Client/1.0"
        ) |>
        req_timeout(seconds = 60) |>
        req_retry(
          max_tries = 3,
          backoff = ~2 # Exponential backoff
        ) |>
        req_perform()

      status <- resp_status(response)

      if (status == 200) {
        return(resp_body_json(response))
      }

      # Handle specific HTTP error codes with helpful messages
      error_msg <- switch(as.character(status),
        "401" = "Authentication failed. Please check your API key in config.yaml",
        "403" = "Access forbidden. Your API key may not have access to this resource",
        "404" = "Resource not found. The dataset or file ID may be incorrect",
        "429" = "Rate limit exceeded. Please wait a few minutes before retrying",
        "500" = "Server error. The microdata.gov.in API may be experiencing issues",
        "502" = "Bad gateway. The API server may be temporarily unavailable",
        "503" = "Service unavailable. The API may be down for maintenance",
        sprintf("Unexpected HTTP error: %d", status)
      )

      stop(sprintf("API request failed: %s\nURL: %s", error_msg, url))
    },
    error = function(e) {
      # Handle network-level errors
      if (grepl("timeout|timed out", e$message, ignore.case = TRUE)) {
        stop(sprintf(
          "Request timed out after 60 seconds.\n%s\n%s",
          "The API may be slow or your connection may be unstable.",
          "Try again or check your network connection."
        ))
      }

      if (grepl("could not resolve|connection refused|network", e$message, ignore.case = TRUE)) {
        stop(sprintf(
          "Network error: Could not connect to microdata.gov.in\n%s\n%s",
          "Please check your internet connection.",
          "The API server may also be temporarily unavailable."
        ))
      }

      # Re-throw other errors with context
      stop(sprintf("API request failed: %s\nEndpoint: %s", e$message, endpoint))
    }
  )
}

# ============================================================================
# Dataset Search and Discovery
# ============================================================================

#' Test API connection
#' @return TRUE if successful, throws error otherwise
#' @export
test_api_connection <- function() {
  tryCatch(
    {
      config <- get_api_config()
      message("Testing API connection...")
      message("Base URL: ", config$base_url)
      message("API Key: ", substr(config$api_key, 1, 4), "****")

      # Try to get dataset list (lightweight request)
      result <- search_datasets(limit = 1)

      message("✓ API connection successful!")
      return(TRUE)
    },
    error = function(e) {
      message("✗ API connection failed:")
      message("  ", e$message)
      return(FALSE)
    }
  )
}

#' Search for datasets on microdata.gov.in
#' @param query Search query string (e.g., "PLFS", "NSS", "HCES")
#' @param limit Maximum number of results (default: 20)
#' @return data.table with dataset information
#' @export
search_datasets <- function(query = NULL, limit = 20) {
  message(sprintf("Searching for datasets: '%s'", query))

  # Build request
  endpoint <- "/api/v1/datasets"

  if (!is.null(query)) {
    result <- .api_request(endpoint, q = query, limit = limit)
  } else {
    result <- .api_request(endpoint, limit = limit)
  }

  # Parse results
  if (length(result$datasets) == 0) {
    message("No datasets found.")
    return(data.table())
  }

  datasets <- rbindlist(result$datasets, fill = TRUE)

  message(sprintf("Found %d datasets", nrow(datasets)))
  return(datasets)
}

#' Get detailed information about a dataset
#' @param dataset_id Dataset ID (e.g., "2728" for PLFS 2022-23)
#' @return List with dataset metadata
#' @export
get_dataset_info <- function(dataset_id) {
  message(sprintf("Getting info for dataset: %s", dataset_id))

  endpoint <- sprintf("/api/v1/datasets/%s", dataset_id)
  result <- .api_request(endpoint)

  return(result)
}

#' List files available for a dataset
#' @param dataset_id Dataset ID
#' @return data.table with file information
#' @export
get_dataset_files <- function(dataset_id) {
  message(sprintf("Getting files for dataset: %s", dataset_id))

  endpoint <- sprintf("/api/v1/datasets/%s/files", dataset_id)
  result <- .api_request(endpoint)

  if (length(result$files) == 0) {
    message("No files found.")
    return(data.table())
  }

  files <- rbindlist(result$files, fill = TRUE)

  message(sprintf("Found %d files", nrow(files)))
  return(files)
}

#' List all available surveys
#' @return data.table with survey types
#' @export
list_surveys <- function() {
  message("Getting list of available surveys...")

  endpoint <- "/api/v1/surveys"
  result <- .api_request(endpoint)

  if (length(result$surveys) == 0) {
    return(data.table())
  }

  surveys <- rbindlist(result$surveys, fill = TRUE)
  return(surveys)
}

# ============================================================================
# Data Download
# ============================================================================

#' Download a data file from microdata.gov.in
#' @param dataset_id Dataset ID
#' @param file_id File ID (e.g., "F1", "F2")
#' @param dest_dir Destination directory (default: raw data folder from config)
#' @param overwrite Overwrite existing file (default: FALSE)
#' @return Path to downloaded file
#' @export
download_datafile <- function(dataset_id, file_id,
                              dest_dir = NULL,
                              overwrite = FALSE) {
  # Get destination directory
  if (is.null(dest_dir)) {
    dest_dir <- get_path("raw")
  }

  if (!dir.exists(dest_dir)) {
    dir.create(dest_dir, recursive = TRUE)
  }

  # Get file info first
  files <- get_dataset_files(dataset_id)
  file_info <- files[file_id == file_id]

  if (nrow(file_info) == 0) {
    stop(sprintf("File '%s' not found in dataset '%s'", file_id, dataset_id))
  }

  # Determine filename
  if (!is.null(file_info$file_name)) {
    filename <- file_info$file_name
  } else {
    filename <- sprintf("dataset_%s_file_%s.zip", dataset_id, file_id)
  }

  dest_path <- file.path(dest_dir, filename)

  # Check if file exists
  if (file.exists(dest_path) && !overwrite) {
    message(sprintf("File already exists: %s", dest_path))
    message("Use overwrite = TRUE to re-download")
    return(dest_path)
  }

  # Download file
  message(sprintf("Downloading: %s", filename))

  config <- get_api_config()
  endpoint <- sprintf("/api/v1/datasets/%s/files/%s/download", dataset_id, file_id)
  url <- .build_api_url(endpoint)

  response <- request(url) |>
    req_headers(
      "Accept" = "application/octet-stream",
      "User-Agent" = "IndiaData-R-Client/1.0"
    ) |>
    req_timeout(seconds = 300) |>
    req_progress() |>
    req_perform()

  # Save to file
  writeBin(resp_body_raw(response), dest_path)

  file_size <- file.size(dest_path)
  message(sprintf(
    "Downloaded: %s (%.1f MB)",
    filename, file_size / 1024^2
  ))

  # If it's a zip file, offer to extract
  if (grepl("\\.zip$", filename, ignore.case = TRUE)) {
    message("Note: This is a ZIP file. Use unzip_datafile() to extract.")
  }

  return(dest_path)
}

#' Extract downloaded ZIP file
#' @param zip_path Path to ZIP file
#' @param dest_dir Destination directory (default: same as ZIP)
#' @return Vector of extracted file paths
#' @export
unzip_datafile <- function(zip_path, dest_dir = NULL) {
  if (!file.exists(zip_path)) {
    stop("ZIP file not found: ", zip_path)
  }

  if (is.null(dest_dir)) {
    dest_dir <- dirname(zip_path)
  }

  message(sprintf("Extracting: %s", basename(zip_path)))

  # List contents before extraction
  files <- unzip(zip_path, list = TRUE)
  message(sprintf("Contains %d files:", nrow(files)))
  print(files$Name)

  # Extract
  extracted <- unzip(zip_path, exdir = dest_dir)

  message(sprintf("Extracted to: %s", dest_dir))
  return(extracted)
}

#' Download and extract complete dataset
#' @param dataset_id Dataset ID
#' @param file_ids Vector of file IDs (NULL for all files)
#' @param extract Automatically extract ZIP files (default: TRUE)
#' @return List of downloaded file paths
#' @export
download_dataset <- function(dataset_id, file_ids = NULL, extract = TRUE) {
  message(sprintf("=== Downloading Dataset: %s ===", dataset_id))

  # Get file list if not specified
  if (is.null(file_ids)) {
    files <- get_dataset_files(dataset_id)
    file_ids <- files$file_id
  }

  # Download each file
  downloaded <- character()

  for (fid in file_ids) {
    tryCatch(
      {
        path <- download_datafile(dataset_id, fid)
        downloaded <- c(downloaded, path)

        # Extract if ZIP
        if (extract && grepl("\\.zip$", path, ignore.case = TRUE)) {
          unzip_datafile(path)
        }
      },
      error = function(e) {
        warning(sprintf("Failed to download file '%s': %s", fid, e$message))
      }
    )
  }

  message(sprintf("\nDownloaded %d of %d files", length(downloaded), length(file_ids)))
  return(downloaded)
}

# ============================================================================
# Batch Download Utilities
# ============================================================================

#' Download latest PLFS data
#' @param year Survey year (e.g., "2023", "2024")
#' @param type "annual" or "quarterly"
#' @param dest_dir Destination directory
#' @return Paths to downloaded files
#' @export
download_plfs <- function(year = NULL, type = "annual", dest_dir = NULL) {
  message(sprintf("=== Downloading PLFS Data ==="))

  # Search for PLFS datasets
  query <- if (!is.null(year)) paste("PLFS", year) else "PLFS"
  datasets <- search_datasets(query)

  if (nrow(datasets) == 0) {
    stop("No PLFS datasets found")
  }

  # Show available datasets
  message("\nAvailable PLFS datasets:")
  print(datasets[, .(id, title, year_start, year_end)])

  # Use first dataset if only one found
  if (nrow(datasets) == 1) {
    dataset_id <- datasets$id[1]
  } else {
    # Let user choose or take most recent
    message("\nUsing most recent dataset...")
    dataset_id <- datasets$id[1]
  }

  # Download
  return(download_dataset(dataset_id, dest_dir = dest_dir))
}

# ============================================================================
# Startup Message
# ============================================================================

message("API helpers loaded. Main functions:")
message("  test_api_connection()           - Test API connection")
message("  search_datasets(query)          - Search for surveys")
message("  get_dataset_files(id)           - List files in dataset")
message("  download_datafile(ds, file)     - Download a file")
message("  download_dataset(id)            - Download complete dataset")
message("  download_plfs(year)             - Download PLFS data")
