# PLFS Analyst Guide

This document is a comprehensive guide for any analyst (new or experienced) looking to work with the **Periodic Labour Force Survey (PLFS)** data in this repository.

---

## 🚀 1. Quick Start: Where is the data?

The data is organized **Year-Wise** in the `PLFS` folder.

| Folder | Status | Best For... |
| :--- | :--- | :--- |
| `2023-24/` | **Gold Standard** | Start here. Contains raw `.txt` data, `.csv` conversions, and parsing scripts. |
| `2024/` | **Calendar Data** | Latest calendar year data. |
| `2017-18` to `2022-23` | **Incomplete** | Documentation exists, but you need to download raw files. |
| `Panel_data/` | **Longitudinal** | Files for tracking households across visits. |

---

## 📚 2. Essential Documentation ("The Rosetta Stone")

You cannot analyze this data without these three documents. All are found in the respective year folders or `common_docs/`.

| Document | Purpose | Vital Question it Answers |
| :--- | :--- | :--- |
| **Data Layout** (`.xlsx`) | **Parsing** | "Byte position 23-25 is Age." |
| **Instruction Manual** (`Vol-II.pdf`) | **Decoding** | "Activity Status '31' means 'Attending educational institution'." |
| **Estimation Procedure** (`.pdf`) | **Weighting** | "How do I calculate the Multiplier (Weight) to get national estimates?" |

> 💡 **Pro Tip**: Always keep the **Data Layout** open on a second screen while coding.

---

## 🛠️ 3. How to Work with the Data

### Step 1: Parsing (Raw Text -> Analysis Ready)
The raw data comes in **Fixed-Width Text Files** (`.txt`).
- **Do not** attempt to open these in Excel directly.
- **Use the R Scripts**: We have a robust R pipeline set up.
  - Example: `2023-24/parse_plfs_2023-24.R`
  - This script reads the layout and automatically parses the text file into Parquet/CSV.

### Step 2: Understanding the Hierarchy
PLFS has two main levels:
1.  **Household Level (Level 1)**: Housing conditions, religion, social group.
2.  **Person Level (Level 2)**: Age, education, employment status.

> ⚠️ **Common Mistake**: Merging them incorrectly. A Household can have multiple Persons.
> - **Primary Key**: `FSU_No` + `Hamlet_Group` + `Second_Stage_Stratum` + `Sample_Household_No` (+ `Visit` if applicable).

### Step 3: Applying Weights (Multipliers)
**NEVER** report unweighted counts. PLFS is a sample.
- **Multiplier (MLT)**: Found in the data (usually at the end of the byte string).
- **Formula**: `Estimated Population = Sum(Multiplier / 100)` (Check specific year's manual for dividing by 2 or 100).
- **Sub-samples**: Often you must average the estimates from Sub-sample 1 and Sub-sample 2.

---

## ⚠️ 4. Common Pitfalls & "Gotchas"

1.  **Visit Numbers**: Urban areas have 4 visits (quarters). Rural has 1. Don't sum them up blindly or you'll quadruple-count the urban population.
2.  **Activity Status Priorities**:
    - Status is determined by **Major Time Criterion**.
    - Don't confuse **Principal Status (ps)** with **Subsidiary Status (ss)**.
    - **Usual Status (ps+ss)** includes people who worked for even 30 days in the year.
3.  **Variable Changes**: Codes change between years!
    - *Example*: Education codes might shift. Always check the `README` for that specific year.

---

## 🧪 5. Sample Analysis Workflow

1.  **Objective**: Find the Unemployment Rate for 2023-24.
2.  **Load Data**: Run `2023-24/parse_plfs_2023-24.R` to get the dataframe.
3.  **Filter**: Select `Age >= 15`.
4.  **Define Unemployed**:
    - `Activity Status` in `(81, 82)` (Seeking/Available for work).
5.  **Define Labor Force**:
    - `Activity Status` in `(11-51)` (Employed) OR `(81-82)` (Unemployed).
6.  **Calculate**:
    - `Unemployed_Pop = Sum(Multiplier)` where status is 81/82.
    - `Labor_Force_Pop = Sum(Multiplier)` where status is in Labor Force.
    - `Rate = (Unemployed_Pop / Labor_Force_Pop) * 100`.

---
