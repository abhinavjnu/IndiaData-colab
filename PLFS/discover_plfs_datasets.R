# ============================================================================
# discover_plfs_datasets.R - Search and catalog PLFS datasets from API
# ============================================================================

suppressPackageStartupMessages({
    library(data.table)
    library(httr2)
})

source("R/01_config.R")
source("R/02_api_helpers.R")

cat("\n=== PLFS Dataset Discovery ===\n\n")

# Test API connection
cat("1. Testing API connection...\n")
tryCatch(
    {
        test_result <- test_api_connection()
        cat("   ✓ API connection successful\n\n")
    },
    error = function(e) {
        cat("   ✗ API connection failed:", e$message, "\n")
        stop("Cannot proceed without API access")
    }
)

# Search for PLFS datasets
cat("2. Searching for PLFS datasets...\n")
plfs_datasets <- tryCatch(
    {
        search_datasets(query = "PLFS", limit = 100)
    },
    error = function(e) {
        cat("   Error searching datasets:", e$message, "\n")
        return(NULL)
    }
)

if (is.null(plfs_datasets) || nrow(plfs_datasets) == 0) {
    cat("   ✗ No PLFS datasets found\n")
    quit(save = "no", status = 1)
}

cat(sprintf("   ✓ Found %d datasets\n\n", nrow(plfs_datasets)))

# Display dataset information
cat("3. Available PLFS datasets:\n\n")
cat("Available columns:", paste(names(plfs_datasets), collapse = ", "), "\n\n")

# Save to CSV for review
output_file <- "PLFS/plfs_datasets_catalog.csv"
fwrite(plfs_datasets, output_file)
cat(sprintf("   ✓ Saved dataset catalog to: %s\n\n", output_file))

# Print summary
if ("id" %in% names(plfs_datasets)) {
    for (i in 1:min(10, nrow(plfs_datasets))) {
        cat(sprintf("Dataset %d:\n", i))
        cat(sprintf("  ID: %s\n", plfs_datasets$id[i]))

        # Print available fields
        for (col in names(plfs_datasets)) {
            if (col != "id" && !is.na(plfs_datasets[[col]][i])) {
                value <- plfs_datasets[[col]][i]
                if (nchar(as.character(value)) < 100) {
                    cat(sprintf("  %s: %s\n", col, value))
                }
            }
        }
        cat("\n")
    }

    if (nrow(plfs_datasets) > 10) {
        cat(sprintf("... and %d more datasets (see CSV for full list)\n\n", nrow(plfs_datasets) - 10))
    }
}

cat("✓ Discovery complete!\n")
