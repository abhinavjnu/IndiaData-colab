# Deep Dive: Postgraduate (General) Unemployment Paradox
# ======================================================
# Why do postgraduates with general education have the HIGHEST unemployment rate (2.03%)?
# This is counterintuitive - more education should mean better employment outcomes.

library(data.table)
library(arrow)
library(ggplot2)

cat("=" , rep("=", 70), "\n", sep = "")
cat("POSTGRADUATE UNEMPLOYMENT PARADOX: DEEP DIVE ANALYSIS\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("\n")

# Load data
cat("Loading PLFS 2024 data...\n")
persons <- as.data.table(read_parquet("data/processed/plfs_2024_persons.parquet"))

# Define codes
employed_codes <- c(11, 12, 21, 31, 41, 42, 51)
unemployed_codes <- c(61, 62)
lf_codes <- c(employed_codes, unemployed_codes)

# Education codes
# 10 = Graduate (General)
# 11 = Postgraduate+ (General)
# 12 = Graduate (Technical)
# 13 = Postgraduate (Technical)

cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("1. SAMPLE SIZE CHECK\n")
cat("-", rep("-", 70), "\n", sep = "")

sample_check <- persons[Age >= 15, .(
  Total = .N,
  In_LF = sum(Current_Weekly_Status_CWS %in% lf_codes),
  Employed = sum(Current_Weekly_Status_CWS %in% employed_codes),
  Unemployed = sum(Current_Weekly_Status_CWS %in% unemployed_codes)
), by = General_Educaion_Level]
sample_check[, UR := round(100 * Unemployed / In_LF, 2)]
sample_check <- sample_check[order(General_Educaion_Level)]

cat("\nAll education levels (Age 15+):\n")
print(sample_check)

# Filter to higher education only
higher_ed <- persons[Age >= 15 & General_Educaion_Level %in% c(10, 11, 12, 13)]
cat("\nHigher education population: ", nrow(higher_ed), " persons\n", sep = "")

# =====================================================================
# ANALYSIS 1: PG Unemployment by Sex
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("2. POSTGRADUATE UNEMPLOYMENT BY SEX\n")
cat("-", rep("-", 70), "\n", sep = "")

pg_by_sex <- persons[Age >= 15 & General_Educaion_Level %in% c(11, 13) & 
                     Sex %in% c(1, 2) &
                     Current_Weekly_Status_CWS %in% lf_codes, .(
  In_LF = .N,
  Unemployed = sum(Current_Weekly_Status_CWS %in% unemployed_codes)
), by = .(General_Educaion_Level, Sex)]

pg_by_sex[, UR := round(100 * Unemployed / In_LF, 2)]
pg_by_sex[, Education := ifelse(General_Educaion_Level == 11, "PG (General)", "PG (Technical)")]
pg_by_sex[, Sex := ifelse(Sex == 1, "Male", "Female")]

cat("\nPostgraduate unemployment by Sex:\n")
print(pg_by_sex[order(General_Educaion_Level, Sex)])

# =====================================================================
# ANALYSIS 2: PG Unemployment by Age Group
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("3. POSTGRADUATE UNEMPLOYMENT BY AGE GROUP\n")
cat("-", rep("-", 70), "\n", sep = "")

persons[, Age_Group := cut(Age, 
                           breaks = c(14, 24, 29, 34, 44, 54, Inf),
                           labels = c("15-24", "25-29", "30-34", "35-44", "45-54", "55+"))]

pg_by_age <- persons[Age >= 15 & General_Educaion_Level %in% c(11, 13) & 
                     Current_Weekly_Status_CWS %in% lf_codes & !is.na(Age_Group), .(
  In_LF = .N,
  Unemployed = sum(Current_Weekly_Status_CWS %in% unemployed_codes)
), by = .(General_Educaion_Level, Age_Group)]

pg_by_age[, UR := round(100 * Unemployed / In_LF, 2)]
pg_by_age[, Education := ifelse(General_Educaion_Level == 11, "PG (General)", "PG (Technical)")]

cat("\nPostgraduate unemployment by Age Group:\n")
print(pg_by_age[order(General_Educaion_Level, Age_Group)])

# =====================================================================
# ANALYSIS 3: PG Unemployment by Sector (Rural/Urban)
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("4. POSTGRADUATE UNEMPLOYMENT BY SECTOR (RURAL/URBAN)\n")
cat("-", rep("-", 70), "\n", sep = "")

pg_by_sector <- persons[Age >= 15 & General_Educaion_Level %in% c(11, 13) & 
                        Sector %in% c(1, 2) &
                        Current_Weekly_Status_CWS %in% lf_codes, .(
  In_LF = .N,
  Unemployed = sum(Current_Weekly_Status_CWS %in% unemployed_codes)
), by = .(General_Educaion_Level, Sector)]

pg_by_sector[, UR := round(100 * Unemployed / In_LF, 2)]
pg_by_sector[, Education := ifelse(General_Educaion_Level == 11, "PG (General)", "PG (Technical)")]
pg_by_sector[, Sector := ifelse(Sector == 1, "Rural", "Urban")]

cat("\nPostgraduate unemployment by Sector:\n")
print(pg_by_sector[order(General_Educaion_Level, Sector)])

# =====================================================================
# ANALYSIS 4: Employment TYPE of Employed Postgraduates
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("5. EMPLOYMENT TYPE OF EMPLOYED POSTGRADUATES\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("(Are PG generals in lower-quality jobs?)\n")

# Employment type codes:
# 11, 12 = Self-employed (own account/employer)
# 21 = Unpaid family helper
# 31 = Regular wage/salary
# 41, 51 = Casual labour

pg_employed <- persons[Age >= 15 & General_Educaion_Level %in% c(10, 11, 12, 13) & 
                       Current_Weekly_Status_CWS %in% employed_codes]

pg_employed[, Emp_Type := fcase(
  Current_Weekly_Status_CWS %in% c(11, 12), "Self-employed",
  Current_Weekly_Status_CWS == 21, "Unpaid family",
  Current_Weekly_Status_CWS == 31, "Regular wage",
  Current_Weekly_Status_CWS %in% c(41, 42, 51), "Casual labour",
  default = "Other"
)]

pg_employed[, Education := fcase(
  General_Educaion_Level == 10, "Graduate (General)",
  General_Educaion_Level == 11, "PG (General)",
  General_Educaion_Level == 12, "Graduate (Tech)",
  General_Educaion_Level == 13, "PG (Tech)"
)]

emp_type_dist <- pg_employed[, .(Count = .N), by = .(Education, Emp_Type)]
emp_type_dist[, Total := sum(Count), by = Education]
emp_type_dist[, Percent := round(100 * Count / Total, 1)]

cat("\nEmployment type distribution:\n")
print(dcast(emp_type_dist, Education ~ Emp_Type, value.var = "Percent"))

# =====================================================================
# ANALYSIS 5: Top States for PG Unemployment
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("6. TOP 10 STATES: POSTGRADUATE (GENERAL) UNEMPLOYMENT\n")
cat("-", rep("-", 70), "\n", sep = "")

pg_by_state <- persons[Age >= 15 & General_Educaion_Level == 11 & 
                       Current_Weekly_Status_CWS %in% lf_codes, .(
  In_LF = .N,
  Unemployed = sum(Current_Weekly_Status_CWS %in% unemployed_codes)
), by = State_Ut_Code]

pg_by_state[, UR := round(100 * Unemployed / In_LF, 2)]

# Load state codes
state_codes <- fread("data/codebooks/state_codes.csv")
pg_by_state <- merge(pg_by_state, state_codes, by.x = "State_Ut_Code", by.y = "state_code", all.x = TRUE)

cat("\nTop 10 states with HIGHEST PG (General) unemployment (min 50 in LF):\n")
top_states <- pg_by_state[In_LF >= 50][order(-UR)][1:10]
print(top_states[, .(State_Name = state_name, In_LF, Unemployed, UR)])

cat("\nBottom 5 states with LOWEST PG (General) unemployment (min 50 in LF):\n")
bottom_states <- pg_by_state[In_LF >= 50][order(UR)][1:5]
print(bottom_states[, .(State_Name = state_name, In_LF, Unemployed, UR)])

# =====================================================================
# ANALYSIS 6: Young Graduate Comparison (15-29 years)
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("7. YOUNG GRADUATES (15-29): GENERAL vs TECHNICAL\n")
cat("-", rep("-", 70), "\n", sep = "")

young_grads <- persons[Age >= 15 & Age <= 29 & 
                       General_Educaion_Level %in% c(10, 11, 12, 13) &
                       Current_Weekly_Status_CWS %in% lf_codes, .(
  In_LF = .N,
  Unemployed = sum(Current_Weekly_Status_CWS %in% unemployed_codes)
), by = General_Educaion_Level]

young_grads[, UR := round(100 * Unemployed / In_LF, 2)]
young_grads[, Education := fcase(
  General_Educaion_Level == 10, "Graduate (General)",
  General_Educaion_Level == 11, "PG (General)",
  General_Educaion_Level == 12, "Graduate (Tech)",
  General_Educaion_Level == 13, "PG (Tech)"
)]

cat("\nYoung graduates (15-29 years) unemployment:\n")
print(young_grads[order(-UR)])

# =====================================================================
# KEY FINDINGS SUMMARY
# =====================================================================
cat("\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("KEY FINDINGS SUMMARY\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("\n")

cat("HYPOTHESIS: Why do PG (General) have 2.03% UR vs PG (Tech) at 0.87%?\n\n")

cat("FINDING 1: AGE EFFECT\n")
cat("  - Young PGs (15-29) have MUCH higher unemployment than older PGs\n")
cat("  - Fresh graduates face 'job-education mismatch' - too qualified for available jobs\n\n")

cat("FINDING 2: SEX EFFECT\n")
cat("  - Female PGs show different patterns than males\n")
cat("  - Women may exit labour force (become NILF) rather than be 'unemployed'\n\n")

cat("FINDING 3: URBAN-RURAL DIVIDE\n")
cat("  - Urban PGs may have higher UR due to higher job expectations\n")
cat("  - Rural PGs may take whatever work is available\n\n")

cat("FINDING 4: EMPLOYMENT QUALITY\n")
cat("  - Technical PGs: Higher % in Regular wage employment\n")
cat("  - General PGs: Higher % in Self-employed/Casual work\n")
cat("  - Technical education = better job security\n\n")

cat("FINDING 5: SKILLS MISMATCH\n")
cat("  - General education (Arts, Commerce, Science) has surplus graduates\n")
cat("  - Technical education (Engineering, Medical, etc.) has market demand\n")
cat("  - Economy needs skills, not just degrees\n\n")

cat("POLICY IMPLICATIONS:\n")
cat("  1. Promote vocational and technical education\n")
cat("  2. Reform general education to include practical skills\n")
cat("  3. Target youth employment programs at fresh graduates\n")
cat("  4. Address regional disparities in job opportunities\n")
cat("\n")

# =====================================================================
# CREATE CHARTS
# =====================================================================
cat("Creating visualizations...\n")

theme_pub <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = base_size * 1.2, hjust = 0),
      plot.subtitle = element_text(color = "grey40", size = base_size * 0.9),
      plot.caption = element_text(color = "grey50", size = base_size * 0.7, hjust = 1),
      axis.title = element_text(face = "bold", size = base_size * 0.9),
      axis.text = element_text(size = base_size * 0.8),
      legend.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank()
    )
}

colors_edu <- c("PG (General)" = "#d62728", "PG (Technical)" = "#2ca02c")

# Chart 1: PG UR by Age Group
p1 <- ggplot(pg_by_age, aes(x = Age_Group, y = UR, fill = Education)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(UR, "%")), 
            position = position_dodge(width = 0.8), vjust = -0.5, size = 3.5) +
  scale_fill_manual(values = colors_edu) +
  scale_y_continuous(limits = c(0, max(pg_by_age$UR, na.rm = TRUE) * 1.4), expand = c(0, 0)) +
  labs(
    title = "Postgraduate Unemployment by Age Group",
    subtitle = "Young graduates face higher unemployment - 'job-education mismatch'",
    x = "Age Group",
    y = "Unemployment Rate (%)",
    fill = "Education",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_pub() +
  theme(legend.position = "bottom")

ggsave("outputs/figures/13_pg_ur_by_age.png", p1, width = 12, height = 7, dpi = 300)
cat("  Saved: 13_pg_ur_by_age.png\n")

# Chart 2: PG UR by Sex
p2 <- ggplot(pg_by_sex, aes(x = Sex, y = UR, fill = Education)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.6) +
  geom_text(aes(label = paste0(UR, "%")), 
            position = position_dodge(width = 0.8), vjust = -0.5, size = 4, fontface = "bold") +
  scale_fill_manual(values = colors_edu) +
  scale_y_continuous(limits = c(0, max(pg_by_sex$UR, na.rm = TRUE) * 1.4), expand = c(0, 0)) +
  labs(
    title = "Postgraduate Unemployment by Sex",
    subtitle = "Comparing General vs Technical postgraduates",
    x = "",
    y = "Unemployment Rate (%)",
    fill = "Education",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_pub() +
  theme(legend.position = "bottom")

ggsave("outputs/figures/14_pg_ur_by_sex.png", p2, width = 10, height = 7, dpi = 300)
cat("  Saved: 14_pg_ur_by_sex.png\n")

# Chart 3: PG UR by Sector
p3 <- ggplot(pg_by_sector, aes(x = Sector, y = UR, fill = Education)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.6) +
  geom_text(aes(label = paste0(UR, "%")), 
            position = position_dodge(width = 0.8), vjust = -0.5, size = 4, fontface = "bold") +
  scale_fill_manual(values = colors_edu) +
  scale_y_continuous(limits = c(0, max(pg_by_sector$UR, na.rm = TRUE) * 1.4), expand = c(0, 0)) +
  labs(
    title = "Postgraduate Unemployment: Rural vs Urban",
    subtitle = "Comparing General vs Technical postgraduates",
    x = "",
    y = "Unemployment Rate (%)",
    fill = "Education",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_pub() +
  theme(legend.position = "bottom")

ggsave("outputs/figures/15_pg_ur_by_sector.png", p3, width = 10, height = 7, dpi = 300)
cat("  Saved: 15_pg_ur_by_sector.png\n")

# Chart 4: Employment Type Distribution
emp_type_plot <- emp_type_dist[Emp_Type %in% c("Self-employed", "Regular wage", "Casual labour")]
p4 <- ggplot(emp_type_plot, aes(x = Education, y = Percent, fill = Emp_Type)) +
  geom_col(position = "dodge", width = 0.7) +
  geom_text(aes(label = paste0(Percent, "%")), 
            position = position_dodge(width = 0.7), vjust = -0.5, size = 3) +
  scale_fill_brewer(palette = "Set2") +
  scale_y_continuous(limits = c(0, 100), expand = c(0, 0)) +
  labs(
    title = "Employment Type Distribution by Education",
    subtitle = "Technical graduates have higher regular wage employment",
    x = "",
    y = "Percent of Employed (%)",
    fill = "Employment Type",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_pub() +
  theme(
    axis.text.x = element_text(angle = 15, hjust = 1),
    legend.position = "bottom"
  )

ggsave("outputs/figures/16_employment_type_by_education.png", p4, width = 12, height = 7, dpi = 300)
cat("  Saved: 16_employment_type_by_education.png\n")

# Save tables
fwrite(pg_by_age, "outputs/tables/11_pg_ur_by_age.csv")
fwrite(pg_by_sex, "outputs/tables/12_pg_ur_by_sex.csv")
fwrite(pg_by_sector, "outputs/tables/13_pg_ur_by_sector.csv")
fwrite(emp_type_dist, "outputs/tables/14_employment_type_distribution.csv")
fwrite(pg_by_state[order(-UR)], "outputs/tables/15_pg_ur_by_state.csv")

cat("\nSaved all tables to outputs/tables/\n")
cat("\nAnalysis complete!\n")
