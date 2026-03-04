#!/usr/bin/env Rscript
# Comprehensive validation of IndiaData pipeline on real PLFS CY2024 data
# Tests: CWS, PS-only, PS+SS approaches via pipeline functions

cat("========================================\n")
cat("  FULL PIPELINE VALIDATION\n")
cat("  PLFS Calendar Year 2024 (Real Data)\n")
cat("========================================\n\n")

suppressMessages({
  library(data.table)
  setDTthreads(2)
  source("R/01_config.R")
  source("R/03_survey_design.R")
  source("R/04_plfs_indicators.R")
})

# Load data
cat("Loading data...\n")
plfs <- fread("data/raw/cperv1.csv", showProgress=FALSE,
              select=c("State_UT_Code","Sector","Stratum","Sub_Stratum","FSU",
                        "Sub_Sample","Quarter","Sex","Age",
                        "Subsample_Multiplier","Ns_Count_Sector_Stratum_Substratum_Subsample",
                        "Ns_Count_Sector_Stratum_Substratum",
                        "Principal_Status_Code","Subsidiary_Status_Code","CWS_Status_Code"))
cat(sprintf("  Loaded %s records × %d columns\n\n", format(nrow(plfs), big.mark=","), ncol(plfs)))

# Filter to 15+
plfs15 <- plfs[Age >= 15]
cat(sprintf("  Age 15+: %s records\n\n", format(nrow(plfs15), big.mark=",")))

# Step 1: Create design via pipeline
cat("=== Step 1: create_plfs_design() ===\n")
design <- create_plfs_design(plfs15, level = "person")
cat("  ✓ Design created\n\n")

# Step 2: CWS approach
cat("=== Step 2: CWS Approach ===\n")
lfpr_cws <- calc_lfpr(design, approach = "cws")
wpr_cws <- calc_wpr(design, approach = "cws")
ur_cws <- calc_unemployment_rate(design, approach = "cws")
cat(sprintf("  LFPR (CWS) = %.1f%%\n", lfpr_cws$lfpr))
cat(sprintf("  WPR  (CWS) = %.1f%%\n", wpr_cws$wpr))
cat(sprintf("  UR   (CWS) = %.1f%%\n\n", ur_cws$ur))

# Step 3: PS+SS approach (official MoSPI usual status)
cat("=== Step 3: PS+SS Approach (Official MoSPI) ===\n")
lfpr_psss <- calc_lfpr(design, approach = "psss")
wpr_psss <- calc_wpr(design, approach = "psss")
ur_psss <- calc_unemployment_rate(design, approach = "psss")
cat(sprintf("  LFPR (PS+SS) = %.1f%%\n", lfpr_psss$lfpr))
cat(sprintf("  WPR  (PS+SS) = %.1f%%\n", wpr_psss$wpr))
cat(sprintf("  UR   (PS+SS) = %.1f%%\n\n", ur_psss$ur))

# Step 4: PS-only approach
cat("=== Step 4: PS-only Approach ===\n")
lfpr_ps <- calc_lfpr(design, approach = "ps")
wpr_ps <- calc_wpr(design, approach = "ps")
ur_ps <- calc_unemployment_rate(design, approach = "ps")
cat(sprintf("  LFPR (PS) = %.1f%%\n", lfpr_ps$lfpr))
cat(sprintf("  WPR  (PS) = %.1f%%\n", wpr_ps$wpr))
cat(sprintf("  UR   (PS) = %.1f%%\n\n", ur_ps$ur))

# Step 5: By-Sex validation (PS+SS)
cat("=== Step 5: By Sex (PS+SS) ===\n")
lfpr_sex <- calc_lfpr(design, by = "Sex", approach = "psss")
ur_sex <- calc_unemployment_rate(design, by = "Sex", approach = "psss")
for (i in seq_len(nrow(lfpr_sex))) {
  lab <- ifelse(lfpr_sex$Sex[i]==1,"Male",ifelse(lfpr_sex$Sex[i]==2,"Female","Other"))
  cat(sprintf("  %s: LFPR=%.1f%%, UR=%.1f%%\n", lab, lfpr_sex$lfpr[i], ur_sex$ur[i]))
}

# Step 6: Manual ground truth
cat("\n=== Step 6: Manual Ground Truth ===\n")
plfs15m <- copy(plfs15)
mult <- plfs15m$Subsample_Multiplier
nss <- plfs15m$Ns_Count_Sector_Stratum_Substratum_Subsample
nsc <- plfs15m$Ns_Count_Sector_Stratum_Substratum
no_qtr <- 4  
wt <- ifelse(nss == nsc, mult / (no_qtr * 100), mult / (no_qtr * 200))
plfs15m[, w := wt]

EMPLOYED <- c(11, 12, 21, 31, 41, 42, 51)
UNEMPLOYED <- c(81, 82)

# PS+SS ground truth
ps <- plfs15m$Principal_Status_Code
ss <- plfs15m$Subsidiary_Status_Code
emp_psss <- (ps %in% EMPLOYED) | (!is.na(ss) & ss %in% EMPLOYED)
unemp_psss <- (ps %in% UNEMPLOYED) & !(!is.na(ss) & ss %in% EMPLOYED)
lf_psss <- emp_psss | unemp_psss

lfpr_gt_psss <- sum(wt[lf_psss]) / sum(wt) * 100
wpr_gt_psss <- sum(wt[emp_psss]) / sum(wt) * 100
ur_gt_psss <- sum(wt[unemp_psss]) / sum(wt[lf_psss]) * 100

# CWS ground truth
cws <- plfs15m$CWS_Status_Code
emp_cws <- cws %in% EMPLOYED
unemp_cws <- cws %in% UNEMPLOYED
lf_cws <- emp_cws | unemp_cws

lfpr_gt_cws <- sum(wt[lf_cws]) / sum(wt) * 100
wpr_gt_cws <- sum(wt[emp_cws]) / sum(wt) * 100
ur_gt_cws <- sum(wt[unemp_cws]) / sum(wt[lf_cws]) * 100

cat(sprintf("  PS+SS: LFPR=%.1f%% WPR=%.1f%% UR=%.1f%%\n", lfpr_gt_psss, wpr_gt_psss, ur_gt_psss))
cat(sprintf("  CWS:   LFPR=%.1f%% WPR=%.1f%% UR=%.1f%%\n", lfpr_gt_cws, wpr_gt_cws, ur_gt_cws))

# Step 7: COMPARISON TABLE
cat("\n================================\n")
cat("  FINAL COMPARISON TABLE\n")
cat("================================\n")
cat(sprintf("%-15s  %8s  %8s  %6s\n", "Indicator", "Manual", "Pipeline", "Diff"))
cat(sprintf("%-15s  %8s  %8s  %6s\n", "───────────", "──────", "────────", "────"))

diffs <- numeric()

d <- abs(lfpr_gt_cws - lfpr_cws$lfpr)
cat(sprintf("%-15s  %7.1f%%  %7.1f%%  %5.2fpp\n", "LFPR (CWS)", lfpr_gt_cws, lfpr_cws$lfpr, d))
diffs <- c(diffs, d)

d <- abs(wpr_gt_cws - wpr_cws$wpr)
cat(sprintf("%-15s  %7.1f%%  %7.1f%%  %5.2fpp\n", "WPR (CWS)", wpr_gt_cws, wpr_cws$wpr, d))
diffs <- c(diffs, d)

d <- abs(ur_gt_cws - ur_cws$ur)
cat(sprintf("%-15s  %7.1f%%  %7.1f%%  %5.2fpp\n", "UR (CWS)", ur_gt_cws, ur_cws$ur, d))
diffs <- c(diffs, d)

d <- abs(lfpr_gt_psss - lfpr_psss$lfpr)
cat(sprintf("%-15s  %7.1f%%  %7.1f%%  %5.2fpp\n", "LFPR (PS+SS)", lfpr_gt_psss, lfpr_psss$lfpr, d))
diffs <- c(diffs, d)

d <- abs(wpr_gt_psss - wpr_psss$wpr)
cat(sprintf("%-15s  %7.1f%%  %7.1f%%  %5.2fpp\n", "WPR (PS+SS)", wpr_gt_psss, wpr_psss$wpr, d))
diffs <- c(diffs, d)

d <- abs(ur_gt_psss - ur_psss$ur)
cat(sprintf("%-15s  %7.1f%%  %7.1f%%  %5.2fpp\n", "UR (PS+SS)", ur_gt_psss, ur_psss$ur, d))
diffs <- c(diffs, d)

cat(sprintf("\nMax diff: %.2fpp\n", max(diffs)))
if (max(diffs) < 1.0) {
  cat("✅ ALL INDICATORS MATCH MANUAL GROUND TRUTH (< 1pp)\n")
} else {
  cat("⚠️  Some discrepancies remain (> 1pp)\n")
}
cat("\nDone.\n")
