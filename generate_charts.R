# ============================================================================
# generate_charts.R - Generate Charts and Summary Statistics for PLFS 2024
# ============================================================================
# This script generates:
# 1. Summary statistics tables
# 2. Labour force indicator charts
# 3. Employment distribution charts
# 4. Age-wise participation charts
# ============================================================================

cat("\n========================================\n")
cat("PLFS 2024 - Charts & Summary Statistics\n")
cat("========================================\n\n")

# ============================================================================
# Setup
# ============================================================================
cat("Loading packages and functions...\n")

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(ggplot2)
  library(scales)
  library(srvyr)
  library(dplyr)
})

source("R/01_config.R")
source("R/03_survey_design.R")
source("R/04_plfs_indicators.R")
source("R/05_codebook_utils.R")

# Create output directories
dir.create("outputs/figures", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/tables", showWarnings = FALSE, recursive = TRUE)

# ============================================================================
# Load Data
# ============================================================================
cat("Loading data from parquet...\n")
persons <- read_parquet("data/processed/plfs_2024_persons.parquet")
persons <- as.data.table(persons)
cat(sprintf("  Loaded %s observations\n\n", format(nrow(persons), big.mark = ",")))

# ============================================================================
# Publication Theme
# ============================================================================
theme_pub <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = base_size * 1.2, hjust = 0),
      plot.subtitle = element_text(color = "grey40", size = base_size * 0.9, hjust = 0),
      plot.caption = element_text(color = "grey50", size = base_size * 0.7, hjust = 1),
      axis.title = element_text(face = "bold", size = base_size * 0.9),
      axis.text = element_text(size = base_size * 0.8),
      legend.title = element_text(face = "bold", size = base_size * 0.9),
      legend.text = element_text(size = base_size * 0.8),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = "grey90"),
      panel.grid.major.x = element_blank(),
      strip.text = element_text(face = "bold", size = base_size * 0.9)
    )
}

# Color palette
colors_sex <- c("Male" = "#2171b5", "Female" = "#cb181d")
colors_sector <- c("Rural" = "#238b45", "Urban" = "#6a51a3")
colors_emp <- c("Self-employed" = "#1b9e77", "Regular wage/salaried" = "#d95f02", 
                "Casual labour" = "#7570b3")

# ============================================================================
# PART 1: SUMMARY STATISTICS
# ============================================================================
cat("=" %>% rep(50) %>% paste(collapse = ""), "\n")
cat("PART 1: SUMMARY STATISTICS\n")
cat("=" %>% rep(50) %>% paste(collapse = ""), "\n\n")

# --- 1.1 Sample Overview ---
cat("1.1 Sample Overview\n")
cat("-" %>% rep(30) %>% paste(collapse = ""), "\n")

sample_overview <- data.table(
  Metric = c("Total Observations", "Total Households", "States/UTs", 
             "Rural Observations", "Urban Observations",
             "Male", "Female", "Age Range"),
  Value = c(
    format(nrow(persons), big.mark = ","),
    format(length(unique(paste(persons$FSU, persons$Sample_Household_Number))), big.mark = ","),
    length(unique(persons$State_Ut_Code)),
    format(sum(persons$Sector == 1), big.mark = ","),
    format(sum(persons$Sector == 2), big.mark = ","),
    format(sum(persons$Sex == 1), big.mark = ","),
    format(sum(persons$Sex == 2), big.mark = ","),
    paste(min(persons$Age, na.rm = TRUE), "-", max(persons$Age, na.rm = TRUE))
  )
)
print(sample_overview)
fwrite(sample_overview, "outputs/tables/01_sample_overview.csv")
cat("\n")

# --- 1.2 Age Distribution Statistics ---
cat("1.2 Age Distribution\n")
cat("-" %>% rep(30) %>% paste(collapse = ""), "\n")

age_stats <- persons[, .(
  Mean = round(mean(Age, na.rm = TRUE), 1),
  Median = median(Age, na.rm = TRUE),
  SD = round(sd(Age, na.rm = TRUE), 1),
  Min = min(Age, na.rm = TRUE),
  Max = max(Age, na.rm = TRUE),
  `Working Age (15-64)` = sum(Age >= 15 & Age <= 64),
  `Pct Working Age` = round(100 * sum(Age >= 15 & Age <= 64) / .N, 1)
)]
print(age_stats)
cat("\n")

# Age by Sex
age_by_sex <- persons[, .(
  Mean_Age = round(mean(Age, na.rm = TRUE), 1),
  Median_Age = median(Age, na.rm = TRUE),
  N = .N
), by = Sex]
age_by_sex[, Sex := ifelse(Sex == 1, "Male", ifelse(Sex == 2, "Female", "Other"))]
print(age_by_sex)
fwrite(age_by_sex, "outputs/tables/02_age_by_sex.csv")
cat("\n")

# --- 1.3 Education Distribution ---
cat("1.3 Education Distribution (Age 15+)\n")
cat("-" %>% rep(30) %>% paste(collapse = ""), "\n")

edu_labels <- c(
  "01" = "Not literate",
  "02" = "Literate without formal schooling",
  "03" = "Literate below primary",
  "04" = "Primary",
  "05" = "Middle",
  "06" = "Secondary",
  "07" = "Higher secondary",
  "08" = "Diploma/certificate",
  "10" = "Graduate",
  "11" = "Postgraduate and above"
)

edu_dist <- persons[Age >= 15, .N, by = General_Educaion_Level]
edu_dist <- edu_dist[order(General_Educaion_Level)]
edu_dist[, Pct := round(100 * N / sum(N), 1)]
edu_dist[, Education := edu_labels[as.character(General_Educaion_Level)]]
edu_dist[is.na(Education), Education := paste0("Code ", General_Educaion_Level)]
print(edu_dist[, .(Education, N, Pct)])
fwrite(edu_dist, "outputs/tables/03_education_distribution.csv")
cat("\n")

# --- 1.4 Activity Status Distribution (CWS) ---
cat("1.4 Activity Status Distribution (CWS, Age 15+)\n")
cat("-" %>% rep(30) %>% paste(collapse = ""), "\n")

activity_labels <- c(
  "11" = "Self-employed: own account",
  "12" = "Self-employed: employer",
  "21" = "Unpaid family worker",
  "31" = "Regular wage/salaried",
  "41" = "Casual labour (public works)",
  "42" = "Casual labour (public works)",
  "51" = "Casual labour (other)",
  "61" = "Unemployed (seeking)",
  "62" = "Unemployed (available)",
  "71" = "Student",
  "72" = "Student + economic activity",
  "81" = "Domestic duties only",
  "82" = "Domestic duties + economic activity",
  "91" = "Domestic + free collection",
  "92" = "Rentiers/pensioners",
  "93" = "Disabled",
  "94" = "Beggars/vagrants",
  "95" = "Others",
  "97" = "Not working (sickness)",
  "98" = "Not working (other)",
  "99" = "Not reported"
)

cws_dist <- persons[Age >= 15, .N, by = Current_Weekly_Status_CWS]
cws_dist <- cws_dist[order(Current_Weekly_Status_CWS)]
cws_dist[, Pct := round(100 * N / sum(N), 1)]
cws_dist[, Status := activity_labels[as.character(Current_Weekly_Status_CWS)]]
cws_dist[is.na(Status), Status := paste0("Code ", Current_Weekly_Status_CWS)]
print(cws_dist[, .(Current_Weekly_Status_CWS, Status, N, Pct)])
fwrite(cws_dist, "outputs/tables/04_cws_distribution.csv")
cat("\n")

# ============================================================================
# PART 2: CREATE SURVEY DESIGN & CALCULATE INDICATORS
# ============================================================================
cat("=" %>% rep(50) %>% paste(collapse = ""), "\n")
cat("PART 2: LABOUR FORCE INDICATORS\n")
cat("=" %>% rep(50) %>% paste(collapse = ""), "\n\n")

cat("Creating survey design...\n")
design <- create_plfs_design(persons, level = "person")
cat("\n")

# --- 2.1 Overall Indicators ---
cat("2.1 Overall Labour Force Indicators (CWS, Age 15+)\n")
cat("-" %>% rep(30) %>% paste(collapse = ""), "\n")

overall <- calc_all_indicators(design, approach = "cws")
overall_formatted <- data.table(
  Indicator = c("LFPR", "WPR", "UR"),
  Estimate = c(overall$lfpr, overall$wpr, overall$ur),
  SE = c(overall$lfpr_se, overall$wpr_se, overall$ur_se),
  `Sample Size` = overall$n
)
overall_formatted[, Estimate := round(Estimate, 2)]
overall_formatted[, SE := round(SE, 3)]
print(overall_formatted)
fwrite(overall_formatted, "outputs/tables/05_overall_indicators.csv")
cat("\n")

# --- 2.2 Indicators by Sex ---
cat("2.2 Indicators by Sex\n")
cat("-" %>% rep(30) %>% paste(collapse = ""), "\n")

by_sex <- calc_indicators_by_sex(design, approach = "cws")
by_sex[, `:=`(
  lfpr = round(lfpr, 2),
  wpr = round(wpr, 2),
  ur = round(ur, 2)
)]
print(by_sex[, .(Sex, lfpr, wpr, ur, n)])
fwrite(by_sex, "outputs/tables/06_indicators_by_sex.csv")
cat("\n")

# --- 2.3 Indicators by Sector ---
cat("2.3 Indicators by Sector\n")
cat("-" %>% rep(30) %>% paste(collapse = ""), "\n")

by_sector <- calc_all_indicators(design, by = "Sector", approach = "cws")
by_sector[, Sector_Name := ifelse(Sector == 1, "Rural", "Urban")]
by_sector[, `:=`(
  lfpr = round(lfpr, 2),
  wpr = round(wpr, 2),
  ur = round(ur, 2)
)]
print(by_sector[, .(Sector_Name, lfpr, wpr, ur, n)])
fwrite(by_sector, "outputs/tables/07_indicators_by_sector.csv")
cat("\n")

# --- 2.4 Indicators by State ---
cat("2.4 Indicators by State (Top 10 by LFPR)\n")
cat("-" %>% rep(30) %>% paste(collapse = ""), "\n")

by_state <- calc_indicators_by_state(design, approach = "cws")
by_state[, `:=`(
  lfpr = round(lfpr, 2),
  wpr = round(wpr, 2),
  ur = round(ur, 2)
)]

# State names are already added by calc_indicators_by_state
# Fill in any missing names
by_state[is.na(state_name), state_name := paste0("State ", state_code)]

print(by_state[order(-lfpr)][1:10, .(state_name, lfpr, wpr, ur, n)])
fwrite(by_state, "outputs/tables/08_indicators_by_state.csv")
cat("\n")

# ============================================================================
# PART 3: GENERATE CHARTS
# ============================================================================
cat("=" %>% rep(50) %>% paste(collapse = ""), "\n")
cat("PART 3: GENERATING CHARTS\n")
cat("=" %>% rep(50) %>% paste(collapse = ""), "\n\n")

# --- 3.1 Age Pyramid ---
cat("Creating age pyramid...\n")

age_pyramid_data <- persons[, .N, by = .(Age_Group = cut(Age, breaks = c(seq(0, 80, 5), Inf), 
                                                          labels = c("0-4", "5-9", "10-14", "15-19", 
                                                                     "20-24", "25-29", "30-34", "35-39",
                                                                     "40-44", "45-49", "50-54", "55-59",
                                                                     "60-64", "65-69", "70-74", "75-79", "80+"),
                                                          right = FALSE),
                                        Sex)]
age_pyramid_data[, Sex := ifelse(Sex == 1, "Male", ifelse(Sex == 2, "Female", "Other"))]
age_pyramid_data <- age_pyramid_data[Sex %in% c("Male", "Female")]
age_pyramid_data[Sex == "Male", N := -N]  # Negative for left side

p1 <- ggplot(age_pyramid_data, aes(x = Age_Group, y = N, fill = Sex)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  scale_y_continuous(labels = function(x) format(abs(x), big.mark = ",")) +
  scale_fill_manual(values = colors_sex) +
  labs(
    title = "Population Age Pyramid",
    subtitle = "PLFS Calendar Year 2024",
    x = "Age Group",
    y = "Number of Persons",
    fill = "Sex",
    caption = "Source: PLFS Calendar Year 2024, microdata.gov.in"
  ) +
  theme_pub() +
  theme(legend.position = "bottom")

ggsave("outputs/figures/01_age_pyramid.png", p1, width = 10, height = 8, dpi = 300)
ggsave("outputs/figures/01_age_pyramid.pdf", p1, width = 10, height = 8)
cat("  Saved: 01_age_pyramid.png/pdf\n")

# --- 3.2 LFPR by Sex (Bar Chart) ---
cat("Creating LFPR by sex chart...\n")

p2 <- ggplot(by_sex, aes(x = Sex, y = lfpr, fill = Sex)) +
  geom_col(width = 0.6) +
  geom_errorbar(aes(ymin = lfpr_low, ymax = lfpr_upp), width = 0.2) +
  geom_text(aes(label = paste0(lfpr, "%")), vjust = -0.5, size = 5, fontface = "bold") +
  scale_fill_manual(values = colors_sex) +
  scale_y_continuous(limits = c(0, 100), expand = expansion(mult = c(0, 0.1))) +
  labs(
    title = "Labour Force Participation Rate by Sex",
    subtitle = "PLFS Calendar Year 2024, Age 15+, Current Weekly Status",
    x = "",
    y = "LFPR (%)",
    caption = "Error bars show 95% confidence intervals\nSource: PLFS Calendar Year 2024"
  ) +
  theme_pub() +
  theme(legend.position = "none")

ggsave("outputs/figures/02_lfpr_by_sex.png", p2, width = 8, height = 6, dpi = 300)
ggsave("outputs/figures/02_lfpr_by_sex.pdf", p2, width = 8, height = 6)
cat("  Saved: 02_lfpr_by_sex.png/pdf\n")

# --- 3.3 All Indicators by Sex (Grouped Bar) ---
cat("Creating indicators comparison chart...\n")

indicators_long <- melt(by_sex[, .(Sex, LFPR = lfpr, WPR = wpr, UR = ur)], 
                        id.vars = "Sex", variable.name = "Indicator", value.name = "Value")

p3 <- ggplot(indicators_long, aes(x = Indicator, y = Value, fill = Sex)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(Value, "%")), 
            position = position_dodge(width = 0.8), vjust = -0.5, size = 4) +
  scale_fill_manual(values = colors_sex) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Labour Market Indicators by Sex",
    subtitle = "PLFS Calendar Year 2024, Age 15+",
    x = "",
    y = "Percentage (%)",
    fill = "Sex",
    caption = "LFPR = Labour Force Participation Rate, WPR = Worker Population Ratio, UR = Unemployment Rate\nSource: PLFS Calendar Year 2024"
  ) +
  theme_pub() +
  theme(legend.position = "bottom")

ggsave("outputs/figures/03_indicators_by_sex.png", p3, width = 10, height = 7, dpi = 300)
ggsave("outputs/figures/03_indicators_by_sex.pdf", p3, width = 10, height = 7)
cat("  Saved: 03_indicators_by_sex.png/pdf\n")

# --- 3.4 LFPR by State (Horizontal Bar) ---
cat("Creating LFPR by state chart...\n")

by_state_plot <- by_state[order(lfpr)]
by_state_plot[, state_name := factor(state_name, levels = state_name)]

p4 <- ggplot(by_state_plot, aes(x = state_name, y = lfpr)) +
  geom_col(fill = "#2171b5", width = 0.7) +
  geom_text(aes(label = paste0(lfpr, "%")), hjust = -0.1, size = 3) +
  coord_flip() +
  scale_y_continuous(limits = c(0, max(by_state_plot$lfpr) * 1.15), expand = c(0, 0)) +
  labs(
    title = "Labour Force Participation Rate by State/UT",
    subtitle = "PLFS Calendar Year 2024, Age 15+",
    x = "",
    y = "LFPR (%)",
    caption = "Source: PLFS Calendar Year 2024, microdata.gov.in"
  ) +
  theme_pub() +
  theme(
    axis.text.y = element_text(size = 9),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "grey90")
  )

ggsave("outputs/figures/04_lfpr_by_state.png", p4, width = 10, height = 12, dpi = 300)
ggsave("outputs/figures/04_lfpr_by_state.pdf", p4, width = 10, height = 12)
cat("  Saved: 04_lfpr_by_state.png/pdf\n")

# --- 3.5 Unemployment Rate by State (Top/Bottom) ---
cat("Creating unemployment rate chart...\n")

ur_top <- by_state[order(-ur)][1:10]
ur_top[, state_name := factor(state_name, levels = rev(state_name))]

p5 <- ggplot(ur_top, aes(x = state_name, y = ur)) +
  geom_col(fill = "#cb181d", width = 0.7) +
  geom_text(aes(label = paste0(ur, "%")), hjust = -0.1, size = 4) +
  coord_flip() +
  scale_y_continuous(limits = c(0, max(ur_top$ur) * 1.2), expand = c(0, 0)) +
  labs(
    title = "Top 10 States/UTs by Unemployment Rate",
    subtitle = "PLFS Calendar Year 2024, Age 15+",
    x = "",
    y = "Unemployment Rate (%)",
    caption = "Source: PLFS Calendar Year 2024, microdata.gov.in"
  ) +
  theme_pub() +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "grey90")
  )

ggsave("outputs/figures/05_ur_top_states.png", p5, width = 10, height = 7, dpi = 300)
ggsave("outputs/figures/05_ur_top_states.pdf", p5, width = 10, height = 7)
cat("  Saved: 05_ur_top_states.png/pdf\n")

# --- 3.6 Rural vs Urban Comparison ---
cat("Creating rural-urban comparison chart...\n")

sector_long <- melt(by_sector[, .(Sector_Name, LFPR = lfpr, WPR = wpr, UR = ur)],
                    id.vars = "Sector_Name", variable.name = "Indicator", value.name = "Value")

p6 <- ggplot(sector_long, aes(x = Indicator, y = Value, fill = Sector_Name)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(Value, "%")), 
            position = position_dodge(width = 0.8), vjust = -0.5, size = 4) +
  scale_fill_manual(values = colors_sector) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Labour Market Indicators: Rural vs Urban",
    subtitle = "PLFS Calendar Year 2024, Age 15+",
    x = "",
    y = "Percentage (%)",
    fill = "Sector",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_pub() +
  theme(legend.position = "bottom")

ggsave("outputs/figures/06_rural_urban_comparison.png", p6, width = 10, height = 7, dpi = 300)
ggsave("outputs/figures/06_rural_urban_comparison.pdf", p6, width = 10, height = 7)
cat("  Saved: 06_rural_urban_comparison.png/pdf\n")

# --- 3.7 Employment Type Distribution ---
cat("Creating employment type chart...\n")

# Calculate employment type distribution from CWS
emp_type <- persons[Age >= 15 & Current_Weekly_Status_CWS %in% c(11, 12, 21, 31, 41, 42, 51), 
                    .N, by = .(Sex, Emp_Type = fcase(
                      Current_Weekly_Status_CWS %in% c(11, 12, 21), "Self-employed",
                      Current_Weekly_Status_CWS == 31, "Regular wage/salaried",
                      Current_Weekly_Status_CWS %in% c(41, 42, 51), "Casual labour"
                    ))]
emp_type[, Sex := ifelse(Sex == 1, "Male", "Female")]
emp_type <- emp_type[Sex %in% c("Male", "Female")]
emp_type[, Pct := round(100 * N / sum(N), 1), by = Sex]

p7 <- ggplot(emp_type, aes(x = Sex, y = Pct, fill = Emp_Type)) +
  geom_col(position = "stack", width = 0.6) +
  geom_text(aes(label = paste0(Pct, "%")), 
            position = position_stack(vjust = 0.5), size = 4, color = "white", fontface = "bold") +
  scale_fill_manual(values = colors_emp) +
  scale_y_continuous(expand = c(0, 0)) +
  labs(
    title = "Employment Type Distribution by Sex",
    subtitle = "PLFS Calendar Year 2024, Employed persons Age 15+",
    x = "",
    y = "Percentage (%)",
    fill = "Employment Type",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_pub() +
  theme(legend.position = "bottom")

ggsave("outputs/figures/07_employment_type.png", p7, width = 9, height = 7, dpi = 300)
ggsave("outputs/figures/07_employment_type.pdf", p7, width = 9, height = 7)
cat("  Saved: 07_employment_type.png/pdf\n")

# --- 3.8 Age-wise LFPR ---
cat("Creating age-wise LFPR chart...\n")

# Calculate LFPR by age group and sex
persons[, Age_Group := cut(Age, breaks = c(15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, Inf),
                           labels = c("15-19", "20-24", "25-29", "30-34", "35-39", 
                                      "40-44", "45-49", "50-54", "55-59", "60-64", "65+"),
                           right = FALSE)]

age_lfpr <- persons[Age >= 15 & Sex %in% c(1, 2), .(
  In_LF = sum(Current_Weekly_Status_CWS %in% c(11, 12, 21, 31, 41, 42, 51, 61, 62)),
  Total = .N
), by = .(Age_Group, Sex)]
age_lfpr[, LFPR := round(100 * In_LF / Total, 1)]
age_lfpr[, Sex := ifelse(Sex == 1, "Male", "Female")]
age_lfpr <- age_lfpr[!is.na(Age_Group)]

p8 <- ggplot(age_lfpr, aes(x = Age_Group, y = LFPR, color = Sex, group = Sex)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = colors_sex) +
  scale_y_continuous(limits = c(0, 100)) +
  labs(
    title = "Labour Force Participation Rate by Age Group",
    subtitle = "PLFS Calendar Year 2024",
    x = "Age Group",
    y = "LFPR (%)",
    color = "Sex",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_pub() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave("outputs/figures/08_lfpr_by_age.png", p8, width = 10, height = 7, dpi = 300)
ggsave("outputs/figures/08_lfpr_by_age.pdf", p8, width = 10, height = 7)
cat("  Saved: 08_lfpr_by_age.png/pdf\n")

# --- 3.9 Education vs LFPR ---
cat("Creating education vs LFPR chart...\n")

edu_lfpr <- persons[Age >= 15 & Sex %in% c(1, 2) & !is.na(General_Educaion_Level), .(
  In_LF = sum(Current_Weekly_Status_CWS %in% c(11, 12, 21, 31, 41, 42, 51, 61, 62)),
  Total = .N
), by = .(General_Educaion_Level, Sex)]
edu_lfpr[, LFPR := round(100 * In_LF / Total, 1)]
edu_lfpr[, Sex := ifelse(Sex == 1, "Male", "Female")]

# Add education labels
edu_lfpr[, Education := factor(General_Educaion_Level, 
                                levels = c(1, 2, 3, 4, 5, 6, 7, 8, 10, 11),
                                labels = c("Not literate", "Literate (no school)", 
                                           "Below primary", "Primary", "Middle",
                                           "Secondary", "Higher secondary", 
                                           "Diploma", "Graduate", "Postgraduate+"))]
edu_lfpr <- edu_lfpr[!is.na(Education)]

p9 <- ggplot(edu_lfpr, aes(x = Education, y = LFPR, fill = Sex)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_fill_manual(values = colors_sex) +
  scale_y_continuous(limits = c(0, 100), expand = c(0, 0)) +
  labs(
    title = "Labour Force Participation by Education Level",
    subtitle = "PLFS Calendar Year 2024, Age 15+",
    x = "",
    y = "LFPR (%)",
    fill = "Sex",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_pub() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave("outputs/figures/09_lfpr_by_education.png", p9, width = 12, height = 7, dpi = 300)
ggsave("outputs/figures/09_lfpr_by_education.pdf", p9, width = 12, height = 7)
cat("  Saved: 09_lfpr_by_education.png/pdf\n")

# ============================================================================
# SUMMARY
# ============================================================================
cat("\n")
cat("=" %>% rep(50) %>% paste(collapse = ""), "\n")
cat("COMPLETE!\n")
cat("=" %>% rep(50) %>% paste(collapse = ""), "\n\n")

cat("Summary Statistics Tables saved to outputs/tables/:\n")
list.files("outputs/tables", pattern = "\\.csv$") |> paste(" -", .) |> cat(sep = "\n")

cat("\nCharts saved to outputs/figures/:\n")
list.files("outputs/figures", pattern = "\\.png$") |> paste(" -", .) |> cat(sep = "\n")

cat("\n\nKey Findings:\n")
cat("-" %>% rep(30) %>% paste(collapse = ""), "\n")
cat(sprintf("Overall LFPR: %.1f%%\n", overall$lfpr))
cat(sprintf("  Male LFPR: %.1f%%\n", by_sex[Sex == "Male", lfpr]))
cat(sprintf("  Female LFPR: %.1f%%\n", by_sex[Sex == "Female", lfpr]))
cat(sprintf("  Gender Gap: %.1f percentage points\n", 
            by_sex[Sex == "Male", lfpr] - by_sex[Sex == "Female", lfpr]))
cat(sprintf("\nOverall Unemployment Rate: %.2f%%\n", overall$ur))
cat(sprintf("Highest UR State: %s (%.1f%%)\n", 
            by_state[which.max(ur), state_name], max(by_state$ur)))
cat(sprintf("Lowest UR State: %s (%.1f%%)\n", 
            by_state[which.min(ur), state_name], min(by_state$ur)))
cat("\n")
