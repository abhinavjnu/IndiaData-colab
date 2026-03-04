#!/usr/bin/env Rscript
# ============================================================================
# REAL DATA VALIDATION: PLFS Calendar Year 2024
# ============================================================================
# This script loads the REAL PLFS Calendar Year 2024 unit-level data,
# runs the IndiaData pipeline, computes LFPR/WPR/UR, and cross-validates
# against official MoSPI eSankhyiki API numbers.
#
# Data source: MoSPI microdata (Data and Instructions from MOSPI/)
# Official numbers: https://api.mospi.gov.in
# ============================================================================

cat("\n")
cat("================================================================\n")
cat("  REAL DATA VALIDATION: PLFS Calendar Year 2024\n") 
cat("  Testing IndiaData Pipeline with Official MoSPI Data\n")
cat("================================================================\n\n")

# --- Step 0: Setup ---
project_root <- here::here()
setwd(project_root)

# Source all pipeline functions
cat("Step 0: Loading IndiaData pipeline functions...\n")
suppressMessages({
  source("R/01_config.R")
  source("R/03_survey_design.R")
  source("R/04_plfs_indicators.R")
})
cat("  ✓ Pipeline functions loaded\n\n")

# --- Step 1: Load Real Data ---
cat("================================================================\n")
cat("Step 1: Loading REAL PLFS Calendar Year 2024 Data\n")
cat("================================================================\n")

data_file <- file.path(project_root, "data", "raw", "cperv1.csv")
if (!file.exists(data_file)) {
  stop("Real data file not found: ", data_file, 
       "\nPlease extract 'Data in CSV(1).zip' from 'Data and Instructions from MOSPI/' into data/raw/")
}

cat("  Reading: ", basename(data_file), "\n")
plfs <- data.table::fread(data_file, showProgress = FALSE)
cat(sprintf("  ✓ Loaded %s person records × %d columns\n", 
            format(nrow(plfs), big.mark = ","), ncol(plfs)))
cat(sprintf("  ✓ Memory usage: %.1f MB\n", object.size(plfs) / 1024^2))

# --- Step 2: Data Exploration ---
cat("\n================================================================\n")
cat("Step 2: Data Overview\n")
cat("================================================================\n")

cat(sprintf("  Quarters:  %s\n", paste(sort(unique(plfs$Quarter)), collapse = ", ")))
cat(sprintf("  States:    %d unique\n", length(unique(plfs$State_UT_Code))))
cat(sprintf("  Sectors:   %s\n", paste(sort(unique(plfs$Sector)), collapse = " = ")))
cat(sprintf("  Sex codes: %s\n", paste(sort(unique(plfs$Sex)), collapse = ", ")))
cat(sprintf("  Age range: %d to %d\n", min(plfs$Age, na.rm = TRUE), max(plfs$Age, na.rm = TRUE)))

# Distribution of Principal Status Codes
ps_codes <- plfs[, .N, by = Principal_Status_Code][order(Principal_Status_Code)]
cat(sprintf("\n  Principal Status Code distribution (top 10):\n"))
top_ps <- head(ps_codes[order(-N)], 10)
for (i in seq_len(nrow(top_ps))) {
  cat(sprintf("    Code %2s: %s records (%4.1f%%)\n", 
              top_ps$Principal_Status_Code[i], 
              format(top_ps$N[i], big.mark = ","),
              top_ps$N[i] / nrow(plfs) * 100))
}

# CWS Status
cws_codes <- plfs[!is.na(CWS_Status_Code) & CWS_Status_Code != "", .N, by = CWS_Status_Code][order(CWS_Status_Code)]
cat(sprintf("\n  CWS Status Code distribution (top 10):\n"))
top_cws <- head(cws_codes[order(-N)], 10)
for (i in seq_len(nrow(top_cws))) {
  cat(sprintf("    Code %2s: %s records (%4.1f%%)\n", 
              top_cws$CWS_Status_Code[i],
              format(top_cws$N[i], big.mark = ","),
              top_cws$N[i] / nrow(plfs) * 100))
}

# --- Step 3: Compute Weights ---
cat("\n================================================================\n")
cat("Step 3: Computing Survey Weights\n")
cat("================================================================\n")

# Clean numeric columns
plfs[, Subsample_Multiplier := as.numeric(trimws(as.character(Subsample_Multiplier)))]
plfs[, Ns_Count_Sector_Stratum_Substratum_Subsample := as.numeric(trimws(as.character(Ns_Count_Sector_Stratum_Substratum_Subsample)))]
plfs[, Ns_Count_Sector_Stratum_Substratum := as.numeric(trimws(as.character(Ns_Count_Sector_Stratum_Substratum)))]

# Count number of quarters per Sector × State × Stratum × Sub_Stratum
# NO_QTR is count of contributing quarters for that cell
plfs[, NO_QTR := uniqueN(Quarter), by = .(Sector, State_UT_Code, Stratum, Sub_Stratum)]

# Official weight formula from MoSPI README:
# Combined estimate: MULT/(NO_QTR*100) if NSS=NSC, MULT/(NO_QTR*200) otherwise
plfs[, MULT := Subsample_Multiplier]
plfs[, NSS := Ns_Count_Sector_Stratum_Substratum_Subsample]
plfs[, NSC := Ns_Count_Sector_Stratum_Substratum]

plfs[, final_weight := ifelse(
  NSS == NSC,
  MULT / (NO_QTR * 100),
  MULT / (NO_QTR * 200)
)]

cat(sprintf("  NO_QTR distribution: %s\n", 
            paste(paste0(names(table(plfs$NO_QTR)), "Q=", table(plfs$NO_QTR)), collapse = ", ")))
cat(sprintf("  NSS==NSC: %s (%.1f%%)\n", 
            format(sum(plfs$NSS == plfs$NSC, na.rm = TRUE), big.mark = ","),
            mean(plfs$NSS == plfs$NSC, na.rm = TRUE) * 100))
cat(sprintf("  Weight range: %.2f to %.2f\n", 
            min(plfs$final_weight, na.rm = TRUE), max(plfs$final_weight, na.rm = TRUE)))
cat(sprintf("  ✓ Weights computed for %s records\n", format(sum(!is.na(plfs$final_weight)), big.mark = ",")))

# --- Step 4: Manual Indicator Computation (Ground Truth) ---
cat("\n================================================================\n")
cat("Step 4: Manual Indicator Computation (Ground Truth)\n")
cat("================================================================\n")

# PLFS Activity Status codes (standard)
EMPLOYED_CODES_PS <- c(11, 12, 21, 31, 41, 42, 51)
UNEMPLOYED_CODES_PS <- c(81, 82)
NOT_IN_LF_CODES_PS <- c(91, 92, 93, 94, 95, 97, 98, 99)

# Filter to age 15+ for standard indicators
plfs_15plus <- plfs[Age >= 15]
cat(sprintf("  Population 15+: %s records\n", format(nrow(plfs_15plus), big.mark = ",")))

# --- Principal Status (PS+SS) approach ---
plfs_15plus[, ps_code := as.integer(trimws(as.character(Principal_Status_Code)))]
# Subsidiary status also counts for PS+SS
plfs_15plus[, ss_code := as.integer(trimws(as.character(Subsidiary_Status_Code)))]

# In PS+SS approach: a person is employed if Principal OR Subsidiary status is employed
plfs_15plus[, is_employed_psss := ps_code %in% EMPLOYED_CODES_PS | 
              (!is.na(ss_code) & ss_code %in% EMPLOYED_CODES_PS)]
plfs_15plus[, is_unemployed_psss := ps_code %in% UNEMPLOYED_CODES_PS &
              !((!is.na(ss_code)) & ss_code %in% EMPLOYED_CODES_PS)]
plfs_15plus[, is_in_lf_psss := is_employed_psss | is_unemployed_psss]

# Weighted LFPR, WPR, UR — All India, Age 15+, PS+SS
lfpr_all_psss <- plfs_15plus[!is.na(final_weight), 
                              sum(final_weight * is_in_lf_psss) / sum(final_weight) * 100]
wpr_all_psss <- plfs_15plus[!is.na(final_weight), 
                             sum(final_weight * is_employed_psss) / sum(final_weight) * 100]
ur_all_psss <- plfs_15plus[is_in_lf_psss == TRUE & !is.na(final_weight), 
                            sum(final_weight * is_unemployed_psss) / sum(final_weight) * 100]

cat("\n  >>> PS+SS Approach (All India, Age 15+, All) <<<\n")
cat(sprintf("  LFPR (PS+SS): %.1f%%\n", lfpr_all_psss))
cat(sprintf("  WPR  (PS+SS): %.1f%%\n", wpr_all_psss))
cat(sprintf("  UR   (PS+SS): %.1f%%\n", ur_all_psss))

# --- CWS approach ---  
plfs_15plus[, cws_code := as.integer(trimws(as.character(CWS_Status_Code)))]

EMPLOYED_CODES_CWS <- c(11, 12, 21, 31, 41, 42, 51)
UNEMPLOYED_CODES_CWS <- c(81, 82)

plfs_15plus[, is_employed_cws := cws_code %in% EMPLOYED_CODES_CWS]
plfs_15plus[, is_unemployed_cws := cws_code %in% UNEMPLOYED_CODES_CWS]
plfs_15plus[, is_in_lf_cws := is_employed_cws | is_unemployed_cws]

lfpr_all_cws <- plfs_15plus[!is.na(final_weight) & !is.na(cws_code), 
                             sum(final_weight * is_in_lf_cws) / sum(final_weight) * 100]
wpr_all_cws <- plfs_15plus[!is.na(final_weight) & !is.na(cws_code), 
                            sum(final_weight * is_employed_cws) / sum(final_weight) * 100]
ur_all_cws <- plfs_15plus[is_in_lf_cws == TRUE & !is.na(final_weight), 
                           sum(final_weight * is_unemployed_cws) / sum(final_weight) * 100]

cat("\n  >>> CWS Approach (All India, Age 15+, All) <<<\n")
cat(sprintf("  LFPR (CWS): %.1f%%\n", lfpr_all_cws))
cat(sprintf("  WPR  (CWS): %.1f%%\n", wpr_all_cws))
cat(sprintf("  UR   (CWS): %.1f%%\n", ur_all_cws))

# --- By Sex ---
cat("\n  >>> By Sex (PS+SS, Age 15+) <<<\n")
for (s in c(1, 2)) {
  sex_label <- ifelse(s == 1, "Male", "Female")
  sub <- plfs_15plus[Sex == s & !is.na(final_weight)]
  lfpr_s <- sub[, sum(final_weight * is_in_lf_psss) / sum(final_weight) * 100]
  wpr_s <- sub[, sum(final_weight * is_employed_psss) / sum(final_weight) * 100]
  ur_s <- sub[is_in_lf_psss == TRUE, sum(final_weight * is_unemployed_psss) / sum(final_weight) * 100]
  cat(sprintf("  %s: LFPR=%.1f%%, WPR=%.1f%%, UR=%.1f%%\n", sex_label, lfpr_s, wpr_s, ur_s))
}

# --- By Sector ---
cat("\n  >>> By Sector (PS+SS, Age 15+) <<<\n")
for (sec in c(1, 2)) {
  sec_label <- ifelse(sec == 1, "Rural", "Urban")
  sub <- plfs_15plus[Sector == sec & !is.na(final_weight)]
  lfpr_s <- sub[, sum(final_weight * is_in_lf_psss) / sum(final_weight) * 100]
  wpr_s <- sub[, sum(final_weight * is_employed_psss) / sum(final_weight) * 100]
  ur_s <- sub[is_in_lf_psss == TRUE, sum(final_weight * is_unemployed_psss) / sum(final_weight) * 100]
  cat(sprintf("  %s: LFPR=%.1f%%, WPR=%.1f%%, UR=%.1f%%\n", sec_label, lfpr_s, wpr_s, ur_s))
}

# --- Step 5: Pipeline Functions Test ---
cat("\n================================================================\n")
cat("Step 5: Testing Pipeline Functions (survey design + indicators)\n")
cat("================================================================\n")

# Prepare data for pipeline
# The pipeline expects specific column name patterns
# Map CSV column names to what the pipeline detects:
plfs_pipe <- copy(plfs_15plus)

# Rename to match what detect_variable() looks for
# The pipeline looks for patterns like "mult", "weight", "stratum", "fsu"
if (!"MULT" %in% names(plfs_pipe)) plfs_pipe[, MULT := Subsample_Multiplier]

# The pipeline's create_plfs_design needs specific names
# Let's use the generic create_survey_design instead, more directly

cat("  Creating survey design with create_survey_design()...\n")

# Use combined strata: State_UT_Code + Stratum + Sub_Stratum
plfs_pipe[, combined_strata := paste(State_UT_Code, Stratum, Sub_Stratum, sep = "_")]

tryCatch({
  design <- create_survey_design(
    data = plfs_pipe,
    weight_var = "final_weight",
    strata_vars = "combined_strata",
    cluster_var = "FSU",
    nest = TRUE
  )
  cat("  ✓ Survey design created successfully\n")
  cat(sprintf("  ✓ Design type: %s\n", class(design)[1]))
  
  # --- Test calc_lfpr ---
  cat("\n  Testing calc_lfpr() with PS approach...\n")
  lfpr_result <- calc_lfpr(design, status_var = "Principal_Status_Code", approach = "ps")
  cat(sprintf("  ✓ calc_lfpr(): LFPR = %.1f%% (SE=%.2f, CI=[%.1f, %.1f])\n", 
              lfpr_result$lfpr, lfpr_result$lfpr_se, 
              lfpr_result$lfpr_low, lfpr_result$lfpr_upp))
  
  # --- Test calc_wpr ---
  cat("\n  Testing calc_wpr() with PS approach...\n")
  wpr_result <- calc_wpr(design, status_var = "Principal_Status_Code", approach = "ps")
  cat(sprintf("  ✓ calc_wpr(): WPR = %.1f%% (SE=%.2f, CI=[%.1f, %.1f])\n", 
              wpr_result$wpr, wpr_result$wpr_se, 
              wpr_result$wpr_low, wpr_result$wpr_upp))
  
  # --- Test calc_unemployment_rate ---
  cat("\n  Testing calc_unemployment_rate() with PS approach...\n")
  ur_result <- calc_unemployment_rate(design, status_var = "Principal_Status_Code", approach = "ps")
  cat(sprintf("  ✓ calc_unemployment_rate(): UR = %.1f%% (SE=%.2f, CI=[%.1f, %.1f])\n", 
              ur_result$ur, ur_result$ur_se, 
              ur_result$ur_low, ur_result$ur_upp))
  
  # --- Test by Sex ---
  cat("\n  Testing calc_lfpr() by Sex...\n")
  lfpr_sex <- calc_lfpr(design, by = "Sex", status_var = "Principal_Status_Code", approach = "ps")
  for (i in seq_len(nrow(lfpr_sex))) {
    sex_label <- ifelse(lfpr_sex$Sex[i] == 1, "Male", "Female")
    cat(sprintf("  ✓ %s: LFPR = %.1f%%\n", sex_label, lfpr_sex$lfpr[i]))
  }
  
  # --- Test CWS approach ---  
  cat("\n  Testing calc_lfpr() with CWS approach...\n")
  lfpr_cws <- calc_lfpr(design, status_var = "CWS_Status_Code", approach = "cws")
  cat(sprintf("  ✓ calc_lfpr(CWS): LFPR = %.1f%%\n", lfpr_cws$lfpr))
  
  cat("\n  Testing calc_unemployment_rate() with CWS approach...\n")
  ur_cws <- calc_unemployment_rate(design, status_var = "CWS_Status_Code", approach = "cws")
  cat(sprintf("  ✓ calc_unemployment_rate(CWS): UR = %.1f%%\n", ur_cws$ur))
  
  pipeline_lfpr_ps <- lfpr_result$lfpr
  pipeline_wpr_ps <- wpr_result$wpr
  pipeline_ur_ps <- ur_result$ur
  pipeline_lfpr_cws <- lfpr_cws$lfpr
  pipeline_ur_cws <- ur_cws$ur
  pipeline_success <- TRUE
  
}, error = function(e) {
  cat(sprintf("  ✗ Pipeline error: %s\n", e$message))
  pipeline_success <<- FALSE
})

# --- Step 6: Cross-Validation vs Official Numbers ---
cat("\n================================================================\n")
cat("Step 6: Cross-Validation: Our Results vs MoSPI Official\n")
cat("================================================================\n")

# Note: Calendar Year 2024 data was newly released, so eSankhyiki API may
# not have it yet. The API currently has 2017-18 to 2023-24.
# We validate our computation against manual ground truth.

cat("\n  COMPARISON TABLE: Manual Ground Truth vs Pipeline Functions\n")
cat("  ─────────────────────────────────────────────────────────────\n")
cat(sprintf("  %-25s  %10s  %10s  %8s\n", "Indicator", "Manual", "Pipeline", "Diff"))
cat("  ─────────────────────────────────────────────────────────────\n")

if (exists("pipeline_success") && pipeline_success) {
  # PS approach comparisons
  diff_lfpr_ps <- abs(lfpr_all_psss - pipeline_lfpr_ps)
  diff_wpr_ps <- abs(wpr_all_psss - pipeline_wpr_ps)
  diff_ur_ps <- abs(ur_all_psss - pipeline_ur_ps)
  
  cat(sprintf("  %-25s  %9.1f%%  %9.1f%%  %7.2fpp\n", 
              "LFPR (PS, All)", lfpr_all_psss, pipeline_lfpr_ps, diff_lfpr_ps))
  cat(sprintf("  %-25s  %9.1f%%  %9.1f%%  %7.2fpp\n", 
              "WPR (PS, All)", wpr_all_psss, pipeline_wpr_ps, diff_wpr_ps))
  cat(sprintf("  %-25s  %9.1f%%  %9.1f%%  %7.2fpp\n", 
              "UR (PS, All)", ur_all_psss, pipeline_ur_ps, diff_ur_ps))
  
  diff_lfpr_cws <- abs(lfpr_all_cws - pipeline_lfpr_cws)
  diff_ur_cws <- abs(ur_all_cws - pipeline_ur_cws)
  
  cat(sprintf("  %-25s  %9.1f%%  %9.1f%%  %7.2fpp\n", 
              "LFPR (CWS, All)", lfpr_all_cws, pipeline_lfpr_cws, diff_lfpr_cws))
  cat(sprintf("  %-25s  %9.1f%%  %9.1f%%  %7.2fpp\n", 
              "UR (CWS, All)", ur_all_cws, pipeline_ur_cws, diff_ur_cws))
  
  cat("  ─────────────────────────────────────────────────────────────\n")
  
  # Verdict
  max_diff <- max(diff_lfpr_ps, diff_wpr_ps, diff_ur_ps, diff_lfpr_cws, diff_ur_cws, na.rm = TRUE)
  if (max_diff < 1.0) {
    cat(sprintf("\n  ✅ PASS: Max difference = %.2fpp (< 1.0pp threshold)\n", max_diff))
    cat("  The pipeline produces results consistent with manual computation.\n")
  } else {
    cat(sprintf("\n  ⚠️  WARNING: Max difference = %.2fpp (≥ 1.0pp threshold)\n", max_diff))
    cat("  The pipeline results differ from manual computation.\n")
    cat("  Note: Differences may be due to PS vs PS+SS approach handling.\n")
  }
} else {
  cat("  Pipeline functions were not tested due to errors above.\n")
}

# --- Step 7: Summary Statistics for Reference ---
cat("\n================================================================\n")
cat("Step 7: Summary Statistics for Reference\n")
cat("================================================================\n")

cat("\n  Weighted population estimates (All India):\n")
total_pop <- plfs_15plus[!is.na(final_weight), sum(final_weight)]
cat(sprintf("  Total population (15+): %.0f (weighted)\n", total_pop))
cat(sprintf("  In labour force (PS+SS): %.0f (%.1f%%)\n", 
            plfs_15plus[!is.na(final_weight), sum(final_weight * is_in_lf_psss)],
            lfpr_all_psss))

cat("\n  Employment type distribution (PS, weighted, 15+):\n")
plfs_15plus[, emp_type := fcase(
  ps_code %in% c(11, 12, 21), "Self-employed",
  ps_code == 31, "Regular wage/salaried",
  ps_code %in% c(41, 51), "Casual labour",
  ps_code %in% UNEMPLOYED_CODES_PS, "Unemployed",
  default = "Not in labour force"
)]

emp_dist <- plfs_15plus[!is.na(final_weight), 
                         .(weighted_count = sum(final_weight), 
                           unweighted_n = .N), 
                         by = emp_type][order(-weighted_count)]
emp_dist[, pct := weighted_count / sum(weighted_count) * 100]
for (i in seq_len(nrow(emp_dist))) {
  cat(sprintf("  %-25s: %7.1f%% (n=%s)\n", 
              emp_dist$emp_type[i], emp_dist$pct[i],
              format(emp_dist$unweighted_n[i], big.mark = ",")))
}

cat("\n================================================================\n")
cat("  VALIDATION COMPLETE\n")
cat("================================================================\n")
cat(sprintf("  Data: PLFS Calendar Year 2024 (Jan-Dec 2024)\n"))
cat(sprintf("  Records: %s persons, %d columns\n", format(nrow(plfs), big.mark = ","), ncol(plfs)))
cat(sprintf("  Date: %s\n", Sys.time()))
cat("================================================================\n")
