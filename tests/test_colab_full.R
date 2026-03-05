#!/usr/bin/env Rscript
# Test all chart-generating code from the Colab notebook locally

cat("=== TESTING FULL ANALYSIS NOTEBOOK LOCALLY ===\n\n")

suppressMessages({
  library(data.table)
  library(ggplot2)
  library(scales)
  source("R/01_config.R")
  source("R/03_survey_design.R")
  source("R/04_plfs_indicators.R")
})

dir.create("outputs/charts", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/tables", showWarnings = FALSE, recursive = TRUE)

# ── Load ──
data_path <- "data/raw/cperv1.csv"
plfs <- fread(data_path, showProgress = FALSE)
cat(sprintf("Loaded %s records\n", format(nrow(plfs), big.mark=",")))

plfs_15 <- plfs[Age >= 15]
cat(sprintf("Age 15+: %s records\n", format(nrow(plfs_15), big.mark=",")))

design <- create_plfs_design(plfs_15, level = "person")

theme_india <- theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15, hjust = 0),
    plot.subtitle = element_text(color = "grey40", size = 11),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(color = "grey90"),
    legend.position = "bottom",
    plot.margin = margin(10, 15, 10, 10)
  )
india_colors <- c("#FF9933", "#138808", "#000080", "#E34234", "#6B5B95", "#9B2335")

## ── A. Overall ──
cat("\n=== A. Overall Indicators ===\n")
lfpr_psss <- calc_lfpr(design, approach = "psss")
wpr_psss  <- calc_wpr(design, approach = "psss")
ur_psss   <- calc_unemployment_rate(design, approach = "psss")
lfpr_cws <- calc_lfpr(design, approach = "cws")
wpr_cws  <- calc_wpr(design, approach = "cws")
ur_cws   <- calc_unemployment_rate(design, approach = "cws")

overall <- data.table(
  Indicator = rep(c("LFPR", "WPR", "UR"), 2),
  Approach = c(rep("PS+SS (Usual Status)", 3), rep("CWS (Weekly)", 3)),
  Value = c(lfpr_psss$lfpr, wpr_psss$wpr, ur_psss$ur, lfpr_cws$lfpr, wpr_cws$wpr, ur_cws$ur),
  SE = c(lfpr_psss$lfpr_se, wpr_psss$wpr_se, ur_psss$ur_se, lfpr_cws$lfpr_se, wpr_cws$wpr_se, ur_cws$ur_se)
)
overall[, Indicator := factor(Indicator, levels = c("LFPR", "WPR", "UR"))]
p1 <- ggplot(overall, aes(x = Indicator, y = Value, fill = Approach)) +
  geom_col(position = position_dodge(0.8), width = 0.7) +
  geom_errorbar(aes(ymin = Value - 1.96*SE, ymax = Value + 1.96*SE), position = position_dodge(0.8), width = 0.2) +
  geom_text(aes(label = sprintf("%.1f%%", Value)), position = position_dodge(0.8), vjust = -0.8, size = 4) +
  scale_fill_manual(values = c("#FF9933", "#138808")) +
  labs(title = "Key Labour Indicators", subtitle = "PLFS — Population aged 15+", y = "Percentage (%)", x = NULL, fill = "Approach") +
  ylim(0, max(overall$Value) * 1.15) + theme_india
ggsave("outputs/charts/01_overall_indicators.png", p1, width = 8, height = 5, dpi = 150)
fwrite(overall, "outputs/tables/01_overall_indicators.csv")
cat("  ✅ Chart 1 saved\n")

## ── B. By Sex ──
cat("=== B. By Sex ===\n")
sex_var <- detect_variable(design, "sex")
lfpr_sex <- calc_lfpr(design, by = sex_var, approach = "psss")
wpr_sex  <- calc_wpr(design, by = sex_var, approach = "psss")
ur_sex   <- calc_unemployment_rate(design, by = sex_var, approach = "psss")
sex_dt <- data.table(
  Sex = rep(c("Male", "Female"), 3),
  Indicator = c(rep("LFPR", 2), rep("WPR", 2), rep("UR", 2)),
  Value = c(lfpr_sex$lfpr[1:2], wpr_sex$wpr[1:2], ur_sex$ur[1:2])
)
sex_dt[, Indicator := factor(Indicator, levels = c("LFPR", "WPR", "UR"))]
p2 <- ggplot(sex_dt, aes(x = Indicator, y = Value, fill = Sex)) +
  geom_col(position = position_dodge(0.8), width = 0.7) +
  geom_text(aes(label = sprintf("%.1f%%", Value)), position = position_dodge(0.8), vjust = -0.5, size = 4) +
  scale_fill_manual(values = c("Female" = "#E34234", "Male" = "#000080")) +
  labs(title = "Labour Indicators by Sex", subtitle = "PS+SS (Usual Status), Age 15+", y = "Percentage (%)", x = NULL) +
  ylim(0, max(sex_dt$Value) * 1.15) + theme_india
ggsave("outputs/charts/02_indicators_by_sex.png", p2, width = 8, height = 5, dpi = 150)
fwrite(sex_dt, "outputs/tables/02_indicators_by_sex.csv")
cat("  ✅ Chart 2 saved\n")

## ── C. Rural vs Urban ──
cat("=== C. Rural vs Urban ===\n")
sector_var <- detect_variable(design, "sector")
lfpr_sec <- calc_lfpr(design, by = sector_var, approach = "psss")
wpr_sec  <- calc_wpr(design, by = sector_var, approach = "psss")
ur_sec   <- calc_unemployment_rate(design, by = sector_var, approach = "psss")
sec_dt <- data.table(
  Sector = rep(c("Rural", "Urban"), 3),
  Indicator = c(rep("LFPR", 2), rep("WPR", 2), rep("UR", 2)),
  Value = c(lfpr_sec$lfpr[1:2], wpr_sec$wpr[1:2], ur_sec$ur[1:2])
)
sec_dt[, Indicator := factor(Indicator, levels = c("LFPR", "WPR", "UR"))]
p3 <- ggplot(sec_dt, aes(x = Indicator, y = Value, fill = Sector)) +
  geom_col(position = position_dodge(0.8), width = 0.7) +
  geom_text(aes(label = sprintf("%.1f%%", Value)), position = position_dodge(0.8), vjust = -0.5, size = 4) +
  scale_fill_manual(values = c("Rural" = "#138808", "Urban" = "#FF9933")) +
  labs(title = "Labour Indicators: Rural vs Urban", subtitle = "PS+SS (Usual Status), Age 15+", y = "Percentage (%)", x = NULL) +
  ylim(0, max(sec_dt$Value) * 1.15) + theme_india
ggsave("outputs/charts/03_rural_urban.png", p3, width = 8, height = 5, dpi = 150)
fwrite(sec_dt, "outputs/tables/03_rural_urban.csv")
cat("  ✅ Chart 3 saved\n")

## ── D. Age Group ──
cat("=== D. Age Group ===\n")
design_ag <- design |>
  dplyr::mutate(age_group = cut(Age,
    breaks = c(14, 19, 24, 29, 34, 39, 44, 49, 54, 59, 99),
    labels = c("15-19", "20-24", "25-29", "30-34", "35-39", "40-44", "45-49", "50-54", "55-59", "60+")))
design_ag <- add_lf_classification(design_ag, approach = "psss")
age_result <- design_ag |>
  dplyr::group_by(age_group) |>
  srvyr::summarize(
    lfpr = srvyr::survey_mean(is_in_lf, na.rm = TRUE) * 100,
    wpr  = srvyr::survey_mean(is_employed, na.rm = TRUE) * 100,
    ur_num = srvyr::survey_total(is_unemployed, na.rm = TRUE),
    lf_num = srvyr::survey_total(is_in_lf, na.rm = TRUE),
    n = srvyr::unweighted(dplyr::n())
  ) |> as.data.table()
age_result[, ur := ifelse(lf_num > 0, ur_num / lf_num * 100, 0)]
age_long <- melt(age_result[, .(age_group, LFPR = lfpr, WPR = wpr, UR = ur)],
                 id.vars = "age_group", variable.name = "Indicator", value.name = "Value")
p4 <- ggplot(age_long, aes(x = age_group, y = Value, color = Indicator, group = Indicator)) +
  geom_line(linewidth = 1.2) + geom_point(size = 3) +
  scale_color_manual(values = c("LFPR" = "#FF9933", "WPR" = "#138808", "UR" = "#E34234")) +
  labs(title = "Labour Indicators by Age Group", subtitle = "PS+SS (Usual Status)", x = "Age Group", y = "Percentage (%)") +
  theme_india
ggsave("outputs/charts/04_age_group.png", p4, width = 9, height = 5, dpi = 150)
fwrite(age_result[, .(age_group, lfpr, wpr, ur, n)], "outputs/tables/04_age_group.csv")
cat("  ✅ Chart 4 saved\n")

## ── E. Education ──
cat("=== E. Education Level ===\n")
edu_labels <- c("1" = "Not literate", "2" = "Literate (no school)", "3" = "Below primary", "4" = "Primary",
  "5" = "Middle", "6" = "Secondary", "7" = "Higher secondary", "8" = "Diploma/Certificate",
  "10" = "Graduate", "11" = "Post-graduate & above")
edu_var <- intersect(c("General_Education_Level", "Education_Level", "Education"), names(plfs))[1]
design_edu <- design |> dplyr::mutate(edu = as.character(get(edu_var)))
design_edu <- add_lf_classification(design_edu, approach = "psss")
edu_result <- design_edu |>
  dplyr::group_by(edu) |>
  srvyr::summarize(
    lfpr = srvyr::survey_mean(is_in_lf, na.rm = TRUE) * 100,
    wpr  = srvyr::survey_mean(is_employed, na.rm = TRUE) * 100,
    ur_num = srvyr::survey_total(is_unemployed, na.rm = TRUE),
    lf_num = srvyr::survey_total(is_in_lf, na.rm = TRUE),
    n = srvyr::unweighted(dplyr::n())
  ) |> as.data.table()
edu_result[, ur := ifelse(lf_num > 0, ur_num / lf_num * 100, 0)]
edu_result[, edu_label := ifelse(edu %in% names(edu_labels), edu_labels[edu], paste("Code", edu))]
edu_result[, edu_label := factor(edu_label, levels = edu_labels[edu_labels %in% edu_result$edu_label])]
edu_long <- melt(edu_result[!is.na(edu_label), .(edu_label, LFPR = lfpr, WPR = wpr, UR = ur)],
                 id.vars = "edu_label", variable.name = "Indicator", value.name = "Value")
p5 <- ggplot(edu_long, aes(x = edu_label, y = Value, fill = Indicator)) +
  geom_col(position = position_dodge(0.8), width = 0.7) +
  scale_fill_manual(values = c("LFPR" = "#FF9933", "WPR" = "#138808", "UR" = "#E34234")) +
  labs(title = "Labour Indicators by Education Level", subtitle = "PS+SS (Usual Status), Age 15+", x = NULL, y = "Percentage (%)") +
  coord_flip() + theme_india
ggsave("outputs/charts/05_education.png", p5, width = 10, height = 6, dpi = 150)
fwrite(edu_result[, .(edu, edu_label, lfpr, wpr, ur, n)], "outputs/tables/05_education.csv")
cat("  ✅ Chart 5 saved\n")

## ── F. Employment Type ──
cat("=== F. Employment Type ===\n")
ps_var <- detect_variable(design, "status_ps")
design_emp <- design |>
  dplyr::filter(get(ps_var) %in% c(11, 12, 21, 31, 41, 51)) |>
  dplyr::mutate(emp_type = factor(get(ps_var),
    levels = c(11, 12, 21, 31, 41, 51),
    labels = c("Self-employed (own account)", "Employer", "Unpaid family worker",
               "Regular salaried", "Casual labour (public)", "Casual labour (other)")))
emp_dist <- design_emp |>
  dplyr::group_by(emp_type) |>
  srvyr::summarize(pct = srvyr::survey_mean(na.rm = TRUE) * 100, n = srvyr::unweighted(dplyr::n())) |>
  as.data.table()
p6 <- ggplot(emp_dist, aes(x = reorder(emp_type, pct), y = pct, fill = emp_type)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.1f%%", pct)), hjust = -0.1, size = 4) +
  scale_fill_manual(values = india_colors) +
  coord_flip() +
  labs(title = "Employment Type Distribution", subtitle = "Among employed persons (PS), Age 15+", x = NULL, y = "Share of Employed (%)") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) + theme_india
ggsave("outputs/charts/06_employment_type.png", p6, width = 9, height = 5, dpi = 150)
fwrite(emp_dist, "outputs/tables/06_employment_type.csv")
cat("  ✅ Chart 6 saved\n")

## ── G. State LFPR ──
cat("=== G. State LFPR ===\n")
state_var <- detect_variable(design, "state")
lfpr_st <- calc_lfpr(design, by = state_var, approach = "psss")
wpr_st  <- calc_wpr(design, by = state_var, approach = "psss")
ur_st   <- calc_unemployment_rate(design, by = state_var, approach = "psss")
state_table <- merge(merge(lfpr_st[, c(state_var, "lfpr"), with=FALSE],
  wpr_st[, c(state_var, "wpr"), with=FALSE], by=state_var),
  ur_st[, c(state_var, "ur"), with=FALSE], by=state_var)
setorderv(state_table, "lfpr", order = -1)
state_names <- c("1"="Jammu & Kashmir", "2"="Himachal Pradesh", "3"="Punjab",
  "4"="Chandigarh", "5"="Uttarakhand", "6"="Haryana", "7"="Delhi", "8"="Rajasthan",
  "9"="Uttar Pradesh", "10"="Bihar", "11"="Sikkim", "12"="Arunachal Pradesh",
  "13"="Nagaland", "14"="Manipur", "15"="Mizoram", "16"="Tripura", "17"="Meghalaya",
  "18"="Assam", "19"="West Bengal", "20"="Jharkhand", "21"="Odisha", "22"="Chhattisgarh",
  "23"="Madhya Pradesh", "24"="Gujarat", "25"="Daman & Diu", "26"="D & N Haveli",
  "27"="Maharashtra", "28"="Andhra Pradesh", "29"="Karnataka", "30"="Goa",
  "31"="Lakshadweep", "32"="Kerala", "33"="Tamil Nadu", "34"="Puducherry",
  "35"="A & N Islands", "36"="Telangana", "37"="Ladakh")
state_table[, state_name := ifelse(as.character(get(state_var)) %in% names(state_names),
                                    state_names[as.character(get(state_var))],
                                    paste("State", get(state_var)))]
state_table[, state_name := factor(state_name, levels = rev(state_name))]
p7 <- ggplot(state_table, aes(x = state_name, y = lfpr)) +
  geom_col(fill = "#FF9933", width = 0.7) +
  geom_text(aes(label = sprintf("%.1f%%", lfpr)), hjust = -0.1, size = 3) +
  coord_flip() +
  labs(title = "LFPR by State/UT", subtitle = "PS+SS (Usual Status), Age 15+, sorted by LFPR", x = NULL, y = "LFPR (%)") +
  theme_india + theme(axis.text.y = element_text(size = 9))
ggsave("outputs/charts/07_lfpr_by_state.png", p7, width = 10, height = 12, dpi = 150)
fwrite(state_table, "outputs/tables/07_state_indicators.csv")
cat("  ✅ Chart 7 saved\n")

## ── H. State UR ──
cat("=== H. State UR ===\n")
state_ur <- copy(state_table)
setorderv(state_ur, "ur", order = -1)
state_ur[, state_name := factor(state_name, levels = rev(state_ur$state_name))]
p8 <- ggplot(state_ur, aes(x = state_name, y = ur)) +
  geom_col(fill = "#E34234", width = 0.7) +
  geom_text(aes(label = sprintf("%.1f%%", ur)), hjust = -0.1, size = 3) +
  coord_flip() +
  labs(title = "Unemployment Rate by State/UT", subtitle = "PS+SS (Usual Status), Age 15+, sorted by UR", x = NULL, y = "Unemployment Rate (%)") +
  theme_india + theme(axis.text.y = element_text(size = 9))
ggsave("outputs/charts/08_ur_by_state.png", p8, width = 10, height = 12, dpi = 150)
cat("  ✅ Chart 8 saved\n")

## ── I. Sex × Sector ──
cat("=== I. Sex × Sector ===\n")
design_cross <- add_lf_classification(design, approach = "psss")
design_cross <- design_cross |>
  dplyr::mutate(
    sex_label = ifelse(get(sex_var) == 1, "Male", ifelse(get(sex_var) == 2, "Female", "Other")),
    sector_label = ifelse(get(sector_var) == 1, "Rural", "Urban")
  )
cross_result <- design_cross |>
  dplyr::group_by(sex_label, sector_label) |>
  srvyr::summarize(
    lfpr = srvyr::survey_mean(is_in_lf, na.rm = TRUE) * 100,
    wpr  = srvyr::survey_mean(is_employed, na.rm = TRUE) * 100,
    ur_num = srvyr::survey_total(is_unemployed, na.rm = TRUE),
    lf_num = srvyr::survey_total(is_in_lf, na.rm = TRUE),
    n = srvyr::unweighted(dplyr::n())
  ) |> as.data.table()
cross_result[, ur := ifelse(lf_num > 0, ur_num / lf_num * 100, 0)]
cross_result <- cross_result[sex_label %in% c("Male", "Female")]
cross_long <- melt(cross_result[, .(sex_label, sector_label, LFPR = lfpr, WPR = wpr, UR = ur)],
                   id.vars = c("sex_label", "sector_label"),
                   variable.name = "Indicator", value.name = "Value")
cross_long[, Group := paste(sex_label, sector_label, sep = " - ")]
p9 <- ggplot(cross_long, aes(x = Indicator, y = Value, fill = Group)) +
  geom_col(position = position_dodge(0.8), width = 0.7) +
  geom_text(aes(label = sprintf("%.1f", Value)), position = position_dodge(0.8), vjust = -0.5, size = 3.5) +
  scale_fill_manual(values = c("Male - Rural" = "#000080", "Male - Urban" = "#6B5B95",
    "Female - Rural" = "#E34234", "Female - Urban" = "#FF9933")) +
  labs(title = "Labour Indicators: Sex × Sector", subtitle = "PS+SS (Usual Status), Age 15+",
       x = NULL, y = "Percentage (%)", fill = NULL) +
  ylim(0, max(cross_long$Value) * 1.15) + theme_india
ggsave("outputs/charts/09_sex_sector_cross.png", p9, width = 9, height = 5, dpi = 150)
fwrite(cross_result[, .(sex_label, sector_label, lfpr, wpr, ur, n)], "outputs/tables/09_sex_sector.csv")
cat("  ✅ Chart 9 saved\n")

cat("\n═══════════════════════════════════════\n")
cat("  ALL 9 CHARTS + TABLES GENERATED!\n")
cat("═══════════════════════════════════════\n")
cat("Charts:  ", paste(list.files("outputs/charts", pattern = ".png"), collapse = ", "), "\n")
cat("Tables:  ", paste(list.files("outputs/tables", pattern = ".csv"), collapse = ", "), "\n")
