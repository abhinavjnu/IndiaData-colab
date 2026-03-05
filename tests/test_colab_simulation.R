#!/usr/bin/env Rscript
# Simulate what the Colab notebook does, step by step
# This tests the exact same code that runs in the notebook cells

cat("========================================\n")
cat("  SIMULATING COLAB NOTEBOOK LOCALLY\n")
cat("========================================\n\n")

# ── Step 4: Load & Validate ──
cat("=== STEP 4: Load Data & Validate ===\n")

suppressMessages({
  library(data.table)
  source("R/01_config.R")
  source("R/03_survey_design.R")
  source("R/04_plfs_indicators.R")
})

csv_files <- list.files("data/raw", pattern = "\\.csv$", full.names = TRUE)
cat("Found CSV files:\n")
for (f in csv_files) cat(sprintf("  %s\n", f))

# Prefer person-level
person_files <- grep("cper|person|per_", csv_files, ignore.case = TRUE, value = TRUE)
if (length(person_files) > 0) {
  data_path <- person_files[1]
} else {
  data_path <- csv_files[1]
}

cat(sprintf("\n📂 Loading: %s\n", basename(data_path)))
plfs <- fread(data_path, showProgress = FALSE)
cat(sprintf("   Loaded %s records × %d columns\n\n",
            format(nrow(plfs), big.mark = ","), ncol(plfs)))

# Validate person-level
cols <- names(plfs)

age_candidates <- c("Age", "AGE", "age", "Person_Age", "Age_In_Years")
age_var <- intersect(age_candidates, cols)

has_status <- any(grepl("Status_Code|Activity_Status|CWS_Status|Principal_Status",
                        cols, ignore.case = TRUE))

if (length(age_var) == 0 || !has_status) {
  cat("⚠️  WARNING: This does NOT appear to be a person-level PLFS file!\n")
  cat("   Missing:",
      ifelse(length(age_var) == 0, " Age column", ""),
      ifelse(!has_status, " Activity Status columns", ""), "\n\n")
  cat("   Columns found:\n")
  cat(paste("    •", cols[1:min(15, length(cols))]), sep = "\n")
  stop("Wrong file type.")
}

age_var <- age_var[1]
cat(sprintf("✅ Person-level file confirmed (found: %s, status columns)\n\n", age_var))

status_cols <- grep("Status_Code|Activity_Status|CWS_Status", cols, value = TRUE, ignore.case = TRUE)
cat(sprintf("   Status columns: %s\n", paste(status_cols, collapse = ", ")))
weight_cols <- grep("Multiplier|MULT|Weight", cols, value = TRUE, ignore.case = TRUE)
cat(sprintf("   Weight columns: %s\n", paste(weight_cols, collapse = ", ")))

plfs_15 <- plfs[get(age_var) >= 15]
cat(sprintf("\n   Total records:   %s\n", format(nrow(plfs), big.mark = ",")))
cat(sprintf("   Age 15+ records: %s\n\n", format(nrow(plfs_15), big.mark = ",")))

# ── Step 5: Create Design ──
cat("=== STEP 5: Create Survey Design ===\n")
design <- create_plfs_design(plfs_15, level = "person")
cat("\n✅ Survey design ready!\n\n")

# ── Step 6: Overall Indicators ──
cat("=== STEP 6: Overall Indicators ===\n\n")

cat("── PS+SS (Usual Status) ──\n")
lfpr <- calc_lfpr(design, approach = "psss")
wpr  <- calc_wpr(design, approach = "psss")
ur   <- calc_unemployment_rate(design, approach = "psss")
cat(sprintf("  LFPR = %.1f%%  WPR = %.1f%%  UR = %.1f%%\n\n", lfpr$lfpr, wpr$wpr, ur$ur))

cat("── CWS (Current Weekly Status) ──\n")
lfpr_cws <- calc_lfpr(design, approach = "cws")
wpr_cws  <- calc_wpr(design, approach = "cws")
ur_cws   <- calc_unemployment_rate(design, approach = "cws")
cat(sprintf("  LFPR = %.1f%%  WPR = %.1f%%  UR = %.1f%%\n\n", lfpr_cws$lfpr, wpr_cws$wpr, ur_cws$ur))

# ── Step 7: By Sex ──
cat("=== STEP 7: By Sex ===\n\n")
sex_var <- detect_variable(design, "sex")
cat(sprintf("Sex variable: %s\n", sex_var))

lfpr_sex <- calc_lfpr(design, by = sex_var, approach = "psss")
wpr_sex  <- calc_wpr(design, by = sex_var, approach = "psss")
ur_sex   <- calc_unemployment_rate(design, by = sex_var, approach = "psss")

sex_labels <- c("1" = "Male", "2" = "Female")
for (i in seq_len(nrow(lfpr_sex))) {
  s <- as.character(lfpr_sex[[sex_var]][i])
  label <- ifelse(s %in% names(sex_labels), sex_labels[s], s)
  cat(sprintf("  %s: LFPR=%.1f%% WPR=%.1f%% UR=%.1f%%\n",
              label, lfpr_sex$lfpr[i], wpr_sex$wpr[i], ur_sex$ur[i]))
}

# ── Step 8: By State ──
cat("\n=== STEP 8: By State ===\n\n")
state_var <- detect_variable(design, "state")
cat(sprintf("State variable: %s\n\n", state_var))

lfpr_state <- calc_lfpr(design, by = state_var, approach = "psss")
wpr_state  <- calc_wpr(design, by = state_var, approach = "psss")
ur_state   <- calc_unemployment_rate(design, by = state_var, approach = "psss")

state_table <- merge(lfpr_state[, c(state_var, "lfpr"), with = FALSE],
                     wpr_state[, c(state_var, "wpr"), with = FALSE],
                     by = state_var)
state_table <- merge(state_table,
                     ur_state[, c(state_var, "ur"), with = FALSE],
                     by = state_var)
setorderv(state_table, state_var)

cat(sprintf("  Found %d states/UTs\n", nrow(state_table)))
print(state_table)

# ── Step 9: By Sector ──
cat("\n=== STEP 9: By Sector ===\n\n")
sector_var <- detect_variable(design, "sector")
cat(sprintf("Sector variable: %s\n", sector_var))

lfpr_sector <- calc_lfpr(design, by = sector_var, approach = "psss")
wpr_sector  <- calc_wpr(design, by = sector_var, approach = "psss")
ur_sector   <- calc_unemployment_rate(design, by = sector_var, approach = "psss")

sector_labels <- c("1" = "Rural", "2" = "Urban")
for (i in seq_len(nrow(lfpr_sector))) {
  s <- as.character(lfpr_sector[[sector_var]][i])
  label <- ifelse(s %in% names(sector_labels), sector_labels[s], s)
  cat(sprintf("  %s: LFPR=%.1f%% WPR=%.1f%% UR=%.1f%%\n",
              label, lfpr_sector$lfpr[i], wpr_sector$wpr[i], ur_sector$ur[i]))
}

# ── Step 10: Save results ──
cat("\n=== STEP 10: Save results ===\n")
results <- data.table(
  Approach = c(rep("PS+SS (Usual Status)", 3), rep("CWS (Current Weekly)", 3)),
  Indicator = rep(c("LFPR", "WPR", "UR"), 2),
  Value_Percent = c(lfpr$lfpr, wpr$wpr, ur$ur, lfpr_cws$lfpr, wpr_cws$wpr, ur_cws$ur),
  SE = c(lfpr$lfpr_se, wpr$wpr_se, ur$ur_se, lfpr_cws$lfpr_se, wpr_cws$wpr_se, ur_cws$ur_se)
)
fwrite(results, "plfs_results_overall.csv")
fwrite(state_table, "plfs_results_by_state.csv")
cat("✅ Results saved!\n")

cat("\n══════════════════════════════════\n")
cat("  ALL STEPS COMPLETED SUCCESSFULLY\n")
cat("══════════════════════════════════\n")
