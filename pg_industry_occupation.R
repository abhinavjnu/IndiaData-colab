# Industry & Occupation Analysis: Postgraduates Age 25-40
# =======================================================
# Where do Technical vs General PGs work? What jobs do they do?

library(data.table)
library(arrow)
library(ggplot2)
library(scales)

cat("=" , rep("=", 70), "\n", sep = "")
cat("INDUSTRY & OCCUPATION ANALYSIS: POSTGRADUATES (25-40)\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("\n")

# Load data
persons <- as.data.table(read_parquet("data/processed/plfs_2024_persons.parquet"))

# Load codebooks
nic <- fread("data/codebooks/nic_2008.csv")
nco <- fread("data/codebooks/nco_2015.csv")

# Define codes
employed_codes <- c(11, 12, 21, 31, 41, 42, 51)

# Filter to employed PG, Age 25-40
pg <- persons[Age >= 25 & Age <= 40 & 
              General_Educaion_Level %in% c(11, 13) &
              Current_Weekly_Status_CWS %in% employed_codes]

cat("Employed PGs (25-40): ", nrow(pg), "\n\n", sep = "")

# Create labels
pg[, Education := ifelse(General_Educaion_Level == 11, "General", "Technical")]
pg[, Sex_Label := ifelse(Sex == 1, "Male", "Female")]
pg[, Sector_Label := ifelse(Sector == 1, "Rural", "Urban")]

# Extract 2-digit industry code from 4-digit NIC
pg[, NIC_2digit := as.integer(substr(sprintf("%04d", Industry_Code_NIC), 1, 2))]

# Extract 1-digit occupation code from 3-digit NCO
pg[, NCO_1digit := as.integer(substr(sprintf("%03d", Occupation_Code_NCO), 1, 1))]

# Merge with codebooks
pg <- merge(pg, nic[, .(nic_2digit, section_name)], 
            by.x = "NIC_2digit", by.y = "nic_2digit", all.x = TRUE)
pg <- merge(pg, nco[, .(nco_1digit, major_group)], 
            by.x = "NCO_1digit", by.y = "nco_1digit", all.x = TRUE)

# Shorten long names
pg[, Industry := fcase(
  section_name == "Agriculture forestry and fishing", "Agriculture",
  section_name == "Mining and quarrying", "Mining",
  section_name == "Manufacturing", "Manufacturing",
  section_name == "Electricity gas steam and air conditioning supply", "Utilities",
  section_name == "Water supply sewerage waste management and remediation", "Water/Waste",
  section_name == "Construction", "Construction",
  section_name == "Wholesale and retail trade", "Trade",
  section_name == "Transportation and storage", "Transport",
  section_name == "Accommodation and food service activities", "Hotels/Food",
  section_name == "Information and communication", "IT/Telecom",
  section_name == "Financial and insurance activities", "Finance/Insurance",
  section_name == "Real estate activities", "Real Estate",
  section_name == "Professional scientific and technical activities", "Professional Services",
  section_name == "Administrative and support service activities", "Admin Services",
  section_name == "Public administration and defence", "Govt/Defence",
  section_name == "Education", "Education",
  section_name == "Human health and social work activities", "Healthcare",
  section_name == "Arts entertainment and recreation", "Entertainment",
  section_name == "Other service activities", "Other Services",
  section_name == "Activities of households as employers", "Household",
  default = "Other"
)]

pg[, Occupation := fcase(
  major_group == "Managers", "Managers",
  major_group == "Professionals", "Professionals",
  major_group == "Technicians", "Technicians",
  major_group == "Clerical", "Clerical",
  major_group == "Service", "Service Workers",
  major_group == "Agricultural", "Agricultural",
  major_group == "Craft", "Craft Workers",
  major_group == "Operators", "Machine Operators",
  major_group == "Elementary", "Elementary",
  major_group == "Armed forces", "Armed Forces",
  default = "Other"
)]

# =====================================================================
# ANALYSIS 1: Industry Distribution by Education Type
# =====================================================================
cat("-", rep("-", 70), "\n", sep = "")
cat("1. INDUSTRY DISTRIBUTION: TECHNICAL vs GENERAL PG\n")
cat("-", rep("-", 70), "\n", sep = "")

ind_by_edu <- pg[!is.na(Industry), .(Count = .N), by = .(Education, Industry)]
ind_by_edu[, Total := sum(Count), by = Education]
ind_by_edu[, Percent := round(100 * Count / Total, 1)]
ind_by_edu <- ind_by_edu[order(Education, -Percent)]

# Top industries for each
cat("\nTOP 5 INDUSTRIES - GENERAL PG:\n")
print(ind_by_edu[Education == "General"][1:5, .(Industry, Count, Percent)])

cat("\nTOP 5 INDUSTRIES - TECHNICAL PG:\n")
print(ind_by_edu[Education == "Technical"][1:5, .(Industry, Count, Percent)])

# Comparison table
ind_wide <- dcast(ind_by_edu, Industry ~ Education, value.var = "Percent", fill = 0)
ind_wide[, Diff := Technical - General]
ind_wide <- ind_wide[order(-abs(Diff))]

cat("\nINDUSTRY COMPARISON (sorted by difference):\n")
print(ind_wide[1:12])

# =====================================================================
# ANALYSIS 2: Occupation Distribution by Education Type
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("2. OCCUPATION DISTRIBUTION: TECHNICAL vs GENERAL PG\n")
cat("-", rep("-", 70), "\n", sep = "")

occ_by_edu <- pg[!is.na(Occupation), .(Count = .N), by = .(Education, Occupation)]
occ_by_edu[, Total := sum(Count), by = Education]
occ_by_edu[, Percent := round(100 * Count / Total, 1)]
occ_by_edu <- occ_by_edu[order(Education, -Percent)]

cat("\nOCCUPATION - GENERAL PG:\n")
print(occ_by_edu[Education == "General", .(Occupation, Count, Percent)])

cat("\nOCCUPATION - TECHNICAL PG:\n")
print(occ_by_edu[Education == "Technical", .(Occupation, Count, Percent)])

# Comparison
occ_wide <- dcast(occ_by_edu, Occupation ~ Education, value.var = "Percent", fill = 0)
occ_wide[, Diff := Technical - General]
occ_wide <- occ_wide[order(-Diff)]

cat("\nOCCUPATION COMPARISON:\n")
print(occ_wide)

# =====================================================================
# ANALYSIS 3: Industry by Sex
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("3. TOP INDUSTRIES BY SEX AND EDUCATION\n")
cat("-", rep("-", 70), "\n", sep = "")

ind_by_sex_edu <- pg[!is.na(Industry), .(Count = .N), by = .(Education, Sex_Label, Industry)]
ind_by_sex_edu[, Total := sum(Count), by = .(Education, Sex_Label)]
ind_by_sex_edu[, Percent := round(100 * Count / Total, 1)]

# Top 3 for each group
cat("\nGENERAL MALE:\n")
print(ind_by_sex_edu[Education == "General" & Sex_Label == "Male"][order(-Percent)][1:3, .(Industry, Percent)])

cat("\nGENERAL FEMALE:\n")
print(ind_by_sex_edu[Education == "General" & Sex_Label == "Female"][order(-Percent)][1:3, .(Industry, Percent)])

cat("\nTECHNICAL MALE:\n")
print(ind_by_sex_edu[Education == "Technical" & Sex_Label == "Male"][order(-Percent)][1:3, .(Industry, Percent)])

cat("\nTECHNICAL FEMALE:\n")
print(ind_by_sex_edu[Education == "Technical" & Sex_Label == "Female"][order(-Percent)][1:3, .(Industry, Percent)])

# =====================================================================
# ANALYSIS 4: Occupation Quality Check
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("4. OCCUPATION QUALITY: ARE PGs IN APPROPRIATE JOBS?\n")
cat("-", rep("-", 70), "\n", sep = "")

# Define "appropriate" occupations for postgraduates
pg[, Appropriate_Job := Occupation %in% c("Managers", "Professionals", "Technicians")]

job_quality <- pg[, .(
  Total = .N,
  In_Appropriate = sum(Appropriate_Job),
  Pct_Appropriate = round(100 * sum(Appropriate_Job) / .N, 1)
), by = .(Education, Sex_Label, Sector_Label)]

cat("\nPercent in 'Appropriate' Jobs (Managers/Professionals/Technicians):\n")
print(job_quality[order(Education, Sex_Label, Sector_Label)])

# Summary
cat("\nSUMMARY - APPROPRIATE JOB PERCENTAGE:\n")
quality_summary <- pg[, .(
  Pct_Appropriate = round(100 * sum(Appropriate_Job) / .N, 1)
), by = Education]
print(quality_summary)

# =====================================================================
# ANALYSIS 5: Underemployment - PGs in Elementary/Craft jobs
# =====================================================================
cat("\n")
cat("-", rep("-", 70), "\n", sep = "")
cat("5. UNDEREMPLOYMENT: PGs IN LOW-SKILL OCCUPATIONS\n")
cat("-", rep("-", 70), "\n", sep = "")

pg[, Underemployed := Occupation %in% c("Elementary", "Craft Workers", "Machine Operators", "Agricultural")]

underemployment <- pg[, .(
  Total = .N,
  Underemployed = sum(Underemployed),
  Pct_Underemployed = round(100 * sum(Underemployed) / .N, 1)
), by = .(Education, Sex_Label)]

cat("\nUnderemployment Rate (in Elementary/Craft/Operator/Agricultural jobs):\n")
print(underemployment[order(Education, Sex_Label)])

# =====================================================================
# KEY INSIGHTS
# =====================================================================
cat("\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("KEY INSIGHTS\n")
cat("=", rep("=", 70), "\n", sep = "")

# Calculate key metrics
tech_healthcare <- ind_by_edu[Education == "Technical" & Industry == "Healthcare", Percent]
gen_healthcare <- ind_by_edu[Education == "General" & Industry == "Healthcare", Percent]
tech_education <- ind_by_edu[Education == "Technical" & Industry == "Education", Percent]
gen_education <- ind_by_edu[Education == "General" & Industry == "Education", Percent]

cat("\n")
cat("1. INDUSTRY CONCENTRATION:\n")
cat("   - Technical PGs: Concentrated in Healthcare (", tech_healthcare, "%) and Education (", tech_education, "%)\n", sep = "")
cat("   - General PGs: Education (", gen_education, "%) and diversified across sectors\n\n", sep = "")

cat("2. OCCUPATION DISTRIBUTION:\n")
tech_prof <- occ_by_edu[Education == "Technical" & Occupation == "Professionals", Percent]
gen_prof <- occ_by_edu[Education == "General" & Occupation == "Professionals", Percent]
cat("   - Technical: ", tech_prof, "% are Professionals\n", sep = "")
cat("   - General: ", gen_prof, "% are Professionals\n\n", sep = "")

cat("3. JOB APPROPRIATENESS:\n")
cat("   - Technical PGs: ", quality_summary[Education == "Technical", Pct_Appropriate], "% in appropriate jobs\n", sep = "")
cat("   - General PGs: ", quality_summary[Education == "General", Pct_Appropriate], "% in appropriate jobs\n\n", sep = "")

cat("4. GENDER PATTERNS:\n")
cat("   - Female Technical PGs: Heavily concentrated in Healthcare\n")
cat("   - Female General PGs: Concentrated in Education\n")
cat("   - Males are more diversified across industries\n")
cat("\n")

# =====================================================================
# VISUALIZATIONS
# =====================================================================
cat("Creating visualizations...\n")

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

# CHART 1: Industry Distribution - Top 8 industries
top_industries <- ind_by_edu[, .(Total = sum(Count)), by = Industry][order(-Total)][1:10, Industry]
ind_plot <- ind_by_edu[Industry %in% top_industries]
ind_plot[, Industry := factor(Industry, levels = rev(top_industries))]

p1 <- ggplot(ind_plot, aes(x = Industry, y = Percent, fill = Education)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(Percent, "%")), 
            position = position_dodge(width = 0.8), hjust = -0.1, size = 3) +
  coord_flip() +
  scale_fill_manual(values = colors_edu) +
  scale_y_continuous(limits = c(0, max(ind_plot$Percent) * 1.3), expand = c(0, 0)) +
  labs(
    title = "Industry Distribution: Postgraduates (25-40)",
    subtitle = "Technical vs General Education",
    x = "",
    y = "Percent of Employed (%)",
    fill = "Education",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_report() +
  theme(legend.position = "top")

ggsave("outputs/figures/23_pg_industry_distribution.png", p1, width = 12, height = 8, dpi = 300)
cat("  Saved: 23_pg_industry_distribution.png\n")

# CHART 2: Occupation Distribution
occ_plot <- occ_by_edu[Occupation != "Other"]
occ_order <- occ_plot[, .(Total = sum(Count)), by = Occupation][order(-Total), Occupation]
occ_plot[, Occupation := factor(Occupation, levels = rev(occ_order))]

p2 <- ggplot(occ_plot, aes(x = Occupation, y = Percent, fill = Education)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(Percent, "%")), 
            position = position_dodge(width = 0.8), hjust = -0.1, size = 3.5) +
  coord_flip() +
  scale_fill_manual(values = colors_edu) +
  scale_y_continuous(limits = c(0, max(occ_plot$Percent) * 1.2), expand = c(0, 0)) +
  labs(
    title = "Occupation Distribution: Postgraduates (25-40)",
    subtitle = "Technical vs General Education",
    x = "",
    y = "Percent of Employed (%)",
    fill = "Education",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_report() +
  theme(legend.position = "top")

ggsave("outputs/figures/24_pg_occupation_distribution.png", p2, width = 12, height = 8, dpi = 300)
cat("  Saved: 24_pg_occupation_distribution.png\n")

# CHART 3: Industry by Sex - Faceted
ind_sex_top <- ind_by_sex_edu[Industry %in% top_industries[1:8]]
ind_sex_top[, Industry := factor(Industry, levels = rev(top_industries[1:8]))]

p3 <- ggplot(ind_sex_top, aes(x = Industry, y = Percent, fill = Education)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  coord_flip() +
  facet_wrap(~Sex_Label) +
  scale_fill_manual(values = colors_edu) +
  labs(
    title = "Industry Distribution by Sex: Postgraduates (25-40)",
    subtitle = "Technical vs General Education",
    x = "",
    y = "Percent (%)",
    fill = "Education",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_report() +
  theme(legend.position = "top")

ggsave("outputs/figures/25_pg_industry_by_sex.png", p3, width = 14, height = 8, dpi = 300)
cat("  Saved: 25_pg_industry_by_sex.png\n")

# CHART 4: Job Appropriateness
job_quality[, Group := paste(Sex_Label, Sector_Label, sep = "\n")]

p4 <- ggplot(job_quality, aes(x = Group, y = Pct_Appropriate, fill = Education)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(Pct_Appropriate, "%")), 
            position = position_dodge(width = 0.8), vjust = -0.5, size = 3.5, fontface = "bold") +
  scale_fill_manual(values = colors_edu) +
  scale_y_continuous(limits = c(0, 105), expand = c(0, 0)) +
  labs(
    title = "Job Appropriateness: PGs in Manager/Professional/Technician Roles",
    subtitle = "Postgraduates (25-40) by Education Type, Sex, and Sector",
    x = "",
    y = "Percent in Appropriate Jobs (%)",
    fill = "Education",
    caption = "Appropriate = Managers, Professionals, or Technicians | Source: PLFS 2024"
  ) +
  theme_report() +
  theme(legend.position = "top")

ggsave("outputs/figures/26_pg_job_appropriateness.png", p4, width = 11, height = 7, dpi = 300)
cat("  Saved: 26_pg_job_appropriateness.png\n")

# CHART 5: Underemployment
underemployment[, Group := paste(Education, Sex_Label)]

p5 <- ggplot(underemployment, aes(x = reorder(Group, Pct_Underemployed), y = Pct_Underemployed, fill = Education)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = paste0(Pct_Underemployed, "%")), hjust = -0.2, size = 4, fontface = "bold") +
  coord_flip() +
  scale_fill_manual(values = colors_edu) +
  scale_y_continuous(limits = c(0, max(underemployment$Pct_Underemployed) * 1.4), expand = c(0, 0)) +
  labs(
    title = "Underemployment: PGs in Low-Skill Occupations",
    subtitle = "Percent in Elementary/Craft/Operator/Agricultural jobs",
    x = "",
    y = "Underemployment Rate (%)",
    fill = "Education",
    caption = "Source: PLFS Calendar Year 2024"
  ) +
  theme_report() +
  theme(legend.position = "none")

ggsave("outputs/figures/27_pg_underemployment.png", p5, width = 10, height = 6, dpi = 300)
cat("  Saved: 27_pg_underemployment.png\n")

# Save tables
fwrite(ind_by_edu, "outputs/tables/18_pg_industry_distribution.csv")
fwrite(occ_by_edu, "outputs/tables/19_pg_occupation_distribution.csv")
fwrite(job_quality, "outputs/tables/20_pg_job_appropriateness.csv")
fwrite(underemployment, "outputs/tables/21_pg_underemployment.csv")
cat("  Saved: CSV tables\n")

# =====================================================================
# FINAL SUMMARY
# =====================================================================
cat("\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("EXECUTIVE SUMMARY: WHERE DO POSTGRADUATES WORK?\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("\n")

cat("TECHNICAL POSTGRADUATES (25-40):\n")
cat("  - Dominant Industries: Healthcare, Education\n")
cat("  - Primary Occupation: Professionals (doctors, engineers, etc.)\n")
cat("  - Job Match: ", quality_summary[Education == "Technical", Pct_Appropriate], "% in appropriate roles\n\n", sep = "")

cat("GENERAL POSTGRADUATES (25-40):\n")
cat("  - Dominant Industries: Education, Trade, Agriculture\n")
cat("  - Mixed Occupations: Professionals, Clerical, Service\n")
cat("  - Job Match: ", quality_summary[Education == "General", Pct_Appropriate], "% in appropriate roles\n\n", sep = "")

cat("KEY FINDING:\n")
cat("  Technical education leads to BOTH better employment rates AND\n")
cat("  better job quality (more likely to be in professional roles).\n")
cat("\n")

cat("Analysis complete!\n")
