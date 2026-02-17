# Postgraduate Prime Working Age (25-40) Analysis
# ================================================
# Cross-tabulation: Tech/Non-Tech × Sex × Sector × Employment Type

library(data.table)
library(arrow)
library(ggplot2)
library(scales)

cat("=" , rep("=", 70), "\n", sep = "")
cat("POSTGRADUATE ANALYSIS: PRIME WORKING AGE (25-40)\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("\n")

# Load data
persons <- as.data.table(read_parquet("data/processed/plfs_2024_persons.parquet"))

# Define codes
employed_codes <- c(11, 12, 21, 31, 41, 42, 51)
unemployed_codes <- c(61, 62)
lf_codes <- c(employed_codes, unemployed_codes)

# Filter to PG, Age 25-40
pg <- persons[Age >= 25 & Age <= 40 & General_Educaion_Level %in% c(11, 13)]

cat("Total PG population (25-40): ", nrow(pg), "\n\n", sep = "")

# Create readable labels
pg[, Education := ifelse(General_Educaion_Level == 11, "General", "Technical")]
pg[, Sex_Label := ifelse(Sex == 1, "Male", "Female")]
pg[, Sector_Label := ifelse(Sector == 1, "Rural", "Urban")]

# Labour force status
pg[, LF_Status := fcase(
  Current_Weekly_Status_CWS %in% employed_codes, "Employed",
  Current_Weekly_Status_CWS %in% unemployed_codes, "Unemployed",
  default = "Not in LF"
)]

# Employment type (for employed only)
pg[, Emp_Type := fcase(
  Current_Weekly_Status_CWS %in% c(11, 12), "Self-employed",
  Current_Weekly_Status_CWS == 21, "Unpaid family",
  Current_Weekly_Status_CWS == 31, "Regular wage",
  Current_Weekly_Status_CWS %in% c(41, 42, 51), "Casual labour",
  default = NA_character_
)]

# =====================================================================
# TABLE 1: Population Distribution
# =====================================================================
cat("-", rep("-", 70), "\n", sep = "")
cat("1. POPULATION DISTRIBUTION (Age 25-40 Postgraduates)\n")
cat("-", rep("-", 70), "\n", sep = "")

pop_dist <- pg[, .(Count = .N), by = .(Education, Sex_Label, Sector_Label)]
pop_dist[, Total := sum(Count), by = .(Education, Sex_Label)]
pop_dist <- dcast(pop_dist, Education + Sex_Label ~ Sector_Label, value.var = "Count")
pop_dist[, Total := Rural + Urban]

cat("\n")
print(pop_dist)
cat("\nTotal: ", nrow(pg), " postgraduates aged 25-40\n", sep = "")

# =====================================================================
# TABLE 2: Labour Force Participation Rate (LFPR)
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("2. LABOUR FORCE PARTICIPATION RATE (%)\n")
cat("-", rep("-", 70), "\n", sep = "")

lfpr <- pg[, .(
  Total = .N,
  In_LF = sum(LF_Status %in% c("Employed", "Unemployed")),
  LFPR = round(100 * sum(LF_Status %in% c("Employed", "Unemployed")) / .N, 1)
), by = .(Education, Sex_Label, Sector_Label)]

lfpr_wide <- dcast(lfpr, Education + Sex_Label ~ Sector_Label, value.var = "LFPR")
cat("\n")
print(lfpr_wide)

# =====================================================================
# TABLE 3: Unemployment Rate
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("3. UNEMPLOYMENT RATE (%) - Among those in Labour Force\n")
cat("-", rep("-", 70), "\n", sep = "")

ur <- pg[LF_Status %in% c("Employed", "Unemployed"), .(
  In_LF = .N,
  Unemployed = sum(LF_Status == "Unemployed"),
  UR = round(100 * sum(LF_Status == "Unemployed") / .N, 2)
), by = .(Education, Sex_Label, Sector_Label)]

ur_wide <- dcast(ur, Education + Sex_Label ~ Sector_Label, value.var = "UR")
cat("\n")
print(ur_wide)

# =====================================================================
# TABLE 4: Employment Type Distribution (for employed only)
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("4. EMPLOYMENT TYPE DISTRIBUTION (%) - Among Employed\n")
cat("-", rep("-", 70), "\n", sep = "")

emp_type <- pg[LF_Status == "Employed", .(Count = .N), by = .(Education, Sex_Label, Sector_Label, Emp_Type)]
emp_type[, Total := sum(Count), by = .(Education, Sex_Label, Sector_Label)]
emp_type[, Percent := round(100 * Count / Total, 1)]

# Focus on Regular wage employment (the "good jobs")
regular_wage <- emp_type[Emp_Type == "Regular wage"]
rw_wide <- dcast(regular_wage, Education + Sex_Label ~ Sector_Label, value.var = "Percent")
cat("\nRegular Wage Employment (%):\n")
print(rw_wide)

# Self-employed
self_emp <- emp_type[Emp_Type == "Self-employed"]
se_wide <- dcast(self_emp, Education + Sex_Label ~ Sector_Label, value.var = "Percent")
cat("\nSelf-Employed (%):\n")
print(se_wide)

# Casual labour
casual <- emp_type[Emp_Type == "Casual labour"]
if(nrow(casual) > 0) {
  cl_wide <- dcast(casual, Education + Sex_Label ~ Sector_Label, value.var = "Percent")
  cat("\nCasual Labour (%):\n")
  print(cl_wide)
}

# =====================================================================
# TABLE 5: Complete Summary Table
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("5. COMPLETE SUMMARY TABLE\n")
cat("-", rep("-", 70), "\n", sep = "")

summary_table <- pg[, .(
  N = .N,
  In_LF = sum(LF_Status %in% c("Employed", "Unemployed")),
  Employed = sum(LF_Status == "Employed"),
  Unemployed = sum(LF_Status == "Unemployed"),
  Regular_Wage = sum(Emp_Type == "Regular wage", na.rm = TRUE),
  Self_Employed = sum(Emp_Type == "Self-employed", na.rm = TRUE),
  Casual = sum(Emp_Type == "Casual labour", na.rm = TRUE)
), by = .(Education, Sex_Label, Sector_Label)]

summary_table[, `:=`(
  LFPR = round(100 * In_LF / N, 1),
  UR = round(100 * Unemployed / In_LF, 2),
  Pct_Regular = round(100 * Regular_Wage / Employed, 1),
  Pct_Self = round(100 * Self_Employed / Employed, 1),
  Pct_Casual = round(100 * Casual / Employed, 1)
)]

# Order nicely
setorder(summary_table, Education, Sex_Label, Sector_Label)

cat("\n")
print(summary_table[, .(Education, Sex = Sex_Label, Sector = Sector_Label, 
                        N, LFPR, UR, Pct_Regular, Pct_Self, Pct_Casual)])

# =====================================================================
# KEY INSIGHTS
# =====================================================================
cat("\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("KEY INSIGHTS\n")
cat("=", rep("=", 70), "\n", sep = "")

# Best and worst segments
best_ur <- summary_table[which.min(UR)]
worst_ur <- summary_table[which.max(UR)]
best_regular <- summary_table[which.max(Pct_Regular)]
worst_lfpr <- summary_table[which.min(LFPR)]

cat("\n")
cat("LOWEST Unemployment: ", best_ur$Education, " ", best_ur$Sex_Label, " ", 
    best_ur$Sector_Label, " (", best_ur$UR, "%)\n", sep = "")
cat("HIGHEST Unemployment: ", worst_ur$Education, " ", worst_ur$Sex_Label, " ", 
    worst_ur$Sector_Label, " (", worst_ur$UR, "%)\n", sep = "")
cat("HIGHEST Regular Wage: ", best_regular$Education, " ", best_regular$Sex_Label, " ", 
    best_regular$Sector_Label, " (", best_regular$Pct_Regular, "%)\n", sep = "")
cat("LOWEST LFPR: ", worst_lfpr$Education, " ", worst_lfpr$Sex_Label, " ", 
    worst_lfpr$Sector_Label, " (", worst_lfpr$LFPR, "%)\n", sep = "")

# =====================================================================
# VISUALIZATIONS
# =====================================================================
cat("\n")
cat("Creating visualizations...\n")

# Theme
theme_report <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = base_size * 1.3, hjust = 0),
      plot.subtitle = element_text(color = "grey30", size = base_size),
      plot.caption = element_text(color = "grey50", size = base_size * 0.8, hjust = 1),
      axis.title = element_text(face = "bold"),
      legend.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      strip.text = element_text(face = "bold", size = base_size),
      strip.background = element_rect(fill = "grey95", color = NA)
    )
}

colors_edu <- c("General" = "#e41a1c", "Technical" = "#4daf4a")
colors_sex <- c("Male" = "#377eb8", "Female" = "#e41a1c")

# CHART 1: Comprehensive heatmap-style bar chart
summary_table[, Group := paste(Sex_Label, Sector_Label, sep = "\n")]

p1 <- ggplot(summary_table, aes(x = Group, y = UR, fill = Education)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(UR, "%")), 
            position = position_dodge(width = 0.8), vjust = -0.5, size = 3.5, fontface = "bold") +
  scale_fill_manual(values = colors_edu) +
  scale_y_continuous(limits = c(0, max(summary_table$UR) * 1.4), expand = c(0, 0)) +
  labs(
    title = "Unemployment Rate: Postgraduates Age 25-40",
    subtitle = "Technical vs General Education by Sex and Sector",
    x = "",
    y = "Unemployment Rate (%)",
    fill = "Education Type",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_report() +
  theme(legend.position = "top")

ggsave("outputs/figures/17_pg_ur_matrix.png", p1, width = 10, height = 7, dpi = 300)
cat("  Saved: 17_pg_ur_matrix.png\n")

# CHART 2: LFPR comparison
p2 <- ggplot(summary_table, aes(x = Group, y = LFPR, fill = Education)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(LFPR, "%")), 
            position = position_dodge(width = 0.8), vjust = -0.5, size = 3.5, fontface = "bold") +
  scale_fill_manual(values = colors_edu) +
  scale_y_continuous(limits = c(0, 105), expand = c(0, 0)) +
  labs(
    title = "Labour Force Participation: Postgraduates Age 25-40",
    subtitle = "Technical vs General Education by Sex and Sector",
    x = "",
    y = "LFPR (%)",
    fill = "Education Type",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_report() +
  theme(legend.position = "top")

ggsave("outputs/figures/18_pg_lfpr_matrix.png", p2, width = 10, height = 7, dpi = 300)
cat("  Saved: 18_pg_lfpr_matrix.png\n")

# CHART 3: Regular wage employment percentage
p3 <- ggplot(summary_table, aes(x = Group, y = Pct_Regular, fill = Education)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(Pct_Regular, "%")), 
            position = position_dodge(width = 0.8), vjust = -0.5, size = 3.5, fontface = "bold") +
  scale_fill_manual(values = colors_edu) +
  scale_y_continuous(limits = c(0, 100), expand = c(0, 0)) +
  labs(
    title = "Regular Wage Employment: Postgraduates Age 25-40",
    subtitle = "Percentage of employed in salaried jobs",
    x = "",
    y = "Regular Wage Employment (%)",
    fill = "Education Type",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_report() +
  theme(legend.position = "top")

ggsave("outputs/figures/19_pg_regular_wage.png", p3, width = 10, height = 7, dpi = 300)
cat("  Saved: 19_pg_regular_wage.png\n")

# CHART 4: Employment type stacked bar
emp_type_plot <- emp_type[Emp_Type %in% c("Regular wage", "Self-employed", "Casual labour")]
emp_type_plot[, Group := paste(Education, Sex_Label, Sector_Label, sep = "\n")]
emp_type_plot[, Emp_Type := factor(Emp_Type, levels = c("Casual labour", "Self-employed", "Regular wage"))]

p4 <- ggplot(emp_type_plot, aes(x = Group, y = Percent, fill = Emp_Type)) +
  geom_col(position = "stack", width = 0.7) +
  geom_text(aes(label = ifelse(Percent >= 5, paste0(Percent, "%"), "")), 
            position = position_stack(vjust = 0.5), size = 3, color = "white", fontface = "bold") +
  scale_fill_brewer(palette = "Set2", direction = -1) +
  scale_y_continuous(expand = c(0, 0)) +
  labs(
    title = "Employment Type Distribution: Postgraduates Age 25-40",
    subtitle = "Quality of employment varies significantly by education type and demographics",
    x = "",
    y = "Percent of Employed (%)",
    fill = "Employment Type",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_report() +
  theme(
    legend.position = "top",
    axis.text.x = element_text(size = 8)
  )

ggsave("outputs/figures/20_pg_emp_type_stacked.png", p4, width = 14, height = 8, dpi = 300)
cat("  Saved: 20_pg_emp_type_stacked.png\n")

# CHART 5: Faceted comparison - UR by Sex, faceted by Sector
p5 <- ggplot(summary_table, aes(x = Sex_Label, y = UR, fill = Education)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_text(aes(label = paste0(UR, "%")), 
            position = position_dodge(width = 0.7), vjust = -0.5, size = 4, fontface = "bold") +
  facet_wrap(~Sector_Label, scales = "free_x") +
  scale_fill_manual(values = colors_edu) +
  scale_y_continuous(limits = c(0, max(summary_table$UR) * 1.5), expand = c(0, 0)) +
  labs(
    title = "Unemployment Rate by Sex and Sector",
    subtitle = "Postgraduates Age 25-40: Technical vs General",
    x = "",
    y = "Unemployment Rate (%)",
    fill = "Education",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_report() +
  theme(legend.position = "top")

ggsave("outputs/figures/21_pg_ur_faceted.png", p5, width = 11, height = 7, dpi = 300)
cat("  Saved: 21_pg_ur_faceted.png\n")

# CHART 6: Dot plot comparison
summary_long <- melt(summary_table, 
                     id.vars = c("Education", "Sex_Label", "Sector_Label"),
                     measure.vars = c("LFPR", "UR", "Pct_Regular"),
                     variable.name = "Indicator",
                     value.name = "Value")

summary_long[, Indicator := factor(Indicator, 
                                   levels = c("LFPR", "UR", "Pct_Regular"),
                                   labels = c("LFPR (%)", "Unemployment Rate (%)", "Regular Wage (%)"))]
summary_long[, Group := paste(Sex_Label, Sector_Label)]

p6 <- ggplot(summary_long, aes(x = Value, y = Group, color = Education, shape = Education)) +
  geom_point(size = 4, position = position_dodge(width = 0.5)) +
  facet_wrap(~Indicator, scales = "free_x", ncol = 3) +
  scale_color_manual(values = colors_edu) +
  labs(
    title = "Key Indicators: Postgraduates Age 25-40",
    subtitle = "Comparison across Education Type, Sex, and Sector",
    x = "",
    y = "",
    color = "Education",
    shape = "Education",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_report() +
  theme(
    legend.position = "top",
    panel.grid.major.y = element_line(color = "grey90")
  )

ggsave("outputs/figures/22_pg_indicators_dot.png", p6, width = 14, height = 6, dpi = 300)
cat("  Saved: 22_pg_indicators_dot.png\n")

# Save summary table
fwrite(summary_table, "outputs/tables/16_pg_prime_age_summary.csv")
fwrite(emp_type, "outputs/tables/17_pg_emp_type_detailed.csv")
cat("  Saved: CSV tables\n")

# =====================================================================
# FINAL SUMMARY
# =====================================================================
cat("\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("EXECUTIVE SUMMARY: PG (25-40) LABOUR MARKET OUTCOMES\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("\n")

cat("SAMPLE: ", nrow(pg), " postgraduates aged 25-40\n\n", sep = "")

cat("1. TECHNICAL EDUCATION ADVANTAGE:\n")
tech_ur <- summary_table[Education == "Technical", mean(UR)]
gen_ur <- summary_table[Education == "General", mean(UR)]
cat("   - Technical PG avg UR: ", round(tech_ur, 2), "%\n", sep = "")
cat("   - General PG avg UR: ", round(gen_ur, 2), "%\n", sep = "")
cat("   - General PGs are ", round(gen_ur/tech_ur, 1), "x more likely to be unemployed\n\n", sep = "")

cat("2. GENDER GAP:\n")
male_lfpr <- summary_table[Sex_Label == "Male", mean(LFPR)]
female_lfpr <- summary_table[Sex_Label == "Female", mean(LFPR)]
cat("   - Male LFPR: ", round(male_lfpr, 1), "%\n", sep = "")
cat("   - Female LFPR: ", round(female_lfpr, 1), "%\n", sep = "")
cat("   - ", round(100 - female_lfpr, 1), "% of female PGs are NOT in labour force\n\n", sep = "")

cat("3. URBAN-RURAL DIVIDE:\n")
urban_reg <- summary_table[Sector_Label == "Urban", mean(Pct_Regular)]
rural_reg <- summary_table[Sector_Label == "Rural", mean(Pct_Regular)]
cat("   - Urban: ", round(urban_reg, 1), "% in regular wage jobs\n", sep = "")
cat("   - Rural: ", round(rural_reg, 1), "% in regular wage jobs\n\n", sep = "")

cat("4. JOB QUALITY (Regular Wage Employment):\n")
cat("   - Technical PG: ", round(summary_table[Education == "Technical", mean(Pct_Regular)], 1), "% salaried\n", sep = "")
cat("   - General PG: ", round(summary_table[Education == "General", mean(Pct_Regular)], 1), "% salaried\n\n", sep = "")

cat("5. MOST VULNERABLE GROUPS:\n")
cat("   - General Female Rural: Low LFPR, high self-employment\n")
cat("   - General Male Urban: Highest unemployment rate\n")
cat("\n")

cat("Analysis complete!\n")
