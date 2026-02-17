# ============================================================================
# download_all_plfs.R - Download All Available PLFS Datasets
# ============================================================================
# This script downloads all PLFS datasets from microdata.gov.in
# Progress is logged to PLFS/download_log.txt

suppressPackageStartupMessages({
    library(data.table)
    library(httr2)
})

source("R/01_config.R")
source("R/02_api_helpers.R")

# Setup logging
log_file <- "PLFS/download_log.txt"
log_msg <- function(msg) {
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    log_line <- sprintf("[%s] %s\n", timestamp, msg)
    cat(log_line)
    cat(log_line, file = log_file, append = TRUE)
}

# Start logging
cat("", file = log_file) # Clear log file
log_msg("=== PLFS Download Script Started ===")

# Test API
log_msg("Testing API connection...")
tryCatch(
    {
        test_api_connection()
        log_msg("✓ API connection successful")
    },
    error = function(e) {
        log_msg(paste("✗ API connection failed:", e$message))
        stop("Cannot proceed without API")
    }
)

# Search for all PLFS datasets
log_msg("\nSearching for PLFS datasets...")
datasets <- tryCatch(
    {
        search_datasets(query = "Periodic Labour Force Survey", limit = 100)
    },
    error = function(e) {
        log_msg(paste("Error in search:", e$message))
        # Try alternate search terms
        log_msg("Trying alternate search: 'PLFS'...")
        tryCatch(
            {
                search_datasets(query = "PLFS", limit = 100)
            },
            error = function(e2) {
                log_msg(paste("Alternate search also failed:", e2$message))
                return(NULL)
            }
        )
    }
)

if (is.null(datasets) || nrow(datasets) == 0) {
    log_msg("✗ No datasets found via API search")
    log_msg("Will use known PLFS dataset IDs instead")

    # Known PLFS dataset IDs (these are common ones on microdata.gov.in)
    # Update these based on actual IDs from the website
    known_plfs <- data.table(
        year = c("2017-18", "2018-19", "2019-20", "2020-21", "2021-22", "2022-23", "2023-24"),
        id = c("", "", "", "", "", "", ""), # To be filled
        type = c("Annual", "Annual", "Annual", "Annual", "Annual", "Annual", "Annual")
    )

    log_msg(sprintf("Using %d known PLFS datasets", nrow(known_plfs)))
    datasets <- known_plfs
} else {
    log_msg(sprintf("✓ Found %d datasets", nrow(datasets)))

    # Save catalog
    cat_file <- "PLFS/datasets_catalog.csv"
    fwrite(datasets, cat_file)
    log_msg(sprintf("✓ Saved catalog to %s", cat_file))

    # Log dataset details
    log_msg("\nDataset details:")
    for (i in 1:min(nrow(datasets), 10)) {
        log_msg(sprintf(
            "  %d. ID=%s, Title=%s",
            i,
            datasets$id[i] %||% "N/A",
            datasets$title[i] %||% "N/A"
        ))
    }
}

# Download each dataset
log_msg("\n=== Starting Downloads ===")

if (nrow(datasets) > 0 && "id" %in% names(datasets)) {
    for (i in 1:nrow(datasets)) {
        dataset_id <- datasets$id[i]

        if (is.na(dataset_id) || dataset_id == "") {
            log_msg(sprintf("\nSkipping row %d - no dataset ID", i))
            next
        }

        log_msg(sprintf("\n[%d/%d] Processing dataset ID: %s", i, nrow(datasets), dataset_id))

        # Get dataset info
        tryCatch(
            {
                info <- get_dataset_info(dataset_id)
                log_msg(sprintf("  Title: %s", info$title %||% "Unknown"))

                # Get files
                files <- get_dataset_files(dataset_id)
                log_msg(sprintf("  Files available: %d", nrow(files)))

                # Download dataset
                if (nrow(files) > 0) {
                    log_msg("  Starting download...")
                    result <- download_dataset(
                        dataset_id = dataset_id,
                        dest_dir = "PLFS",
                        overwrite = FALSE
                    )
                    log_msg(sprintf("  ✓ Downloaded to: %s", result))
                } else {
                    log_msg("  ✗ No files to download")
                }
            },
            error = function(e) {
                log_msg(sprintf("  ✗ Error: %s", e$message))
            }
        )

        # Rate limiting - wait 2 seconds between requests
        Sys.sleep(2)
    }
} else {
    log_msg("No valid dataset IDs found to download")
}

log_msg("\n=== Download Script Complete ===")
log_msg(sprintf("See %s for details", log_file))
