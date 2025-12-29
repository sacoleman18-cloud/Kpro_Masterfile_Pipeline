# Migration Parasite Load Analysis

## **Overview**
This project analyzes parasite loads in waterfowl during early and late fall migration. The analysis includes:

- Summary statistics (n, mean, median) for **parasite richness** and **abundance**  
- **Normality testing** using the Shapiro-Wilk test  
- **Mann-Whitney U tests** (Wilcoxon rank-sum) with effect sizes  
- **Density plots** with 95% confidence intervals  

**Goal:** Compare parasite loads between **Early Fall** vs **Late Fall** migrating waterfowl.

---

## **Project Structure**
Fall Parasite Project/
├── data/ # Raw CSV dataset
│ └── migration_data.csv
├── scripts/ # R scripts for analysis
│ ├── 01_DataPreparation.R
│ ├── 02_SummaryStats.R
│ ├── 03_MWTests.R
│ └── 04_Plots.R
├── outputs/
│ ├── tables/ # GT tables
│ │ └── mw_results_gt.html
│ └── figures/ # Density plots
│ ├── richness_density.png
│ └── abundance_density.png
├── README.md
└── migration_parasite_project.Rproj

## **How to Run**

1. Open the project in **RStudio**.  
2. Install required packages if not already installed:
r
install.packages(c("dplyr", "tidyr", "ggplot2", "readr", "gt"))
3. Run scripts in order:

source("scripts/01_DataPreparation.R")
source("scripts/02_SummaryStats.R")
source("scripts/03_MWTests.R")
source("scripts/04_Plots.R")

## **Outputs**
**Tables:** GT tables with summary statistics and Mann-Whitney U results
  Example: outputs/tables/mw_results_gt.html

**Plots:** Density plots for Richness and Abundance with mean and confidence interval lines
  Example: outputs/figures/richness_density.png

**Significance notation:** Mann-Whitney U test p-values include asterisks:
  * p < 0.05
  *** p < 0.001

## **Notes**
.RData and .Rhistory are **excluded**; only raw CSVs and scripts are needed.

Scripts are **modular and reproducible**; each script can be run independently.

Plot colors: **Early Fall = blue, Late Fall = orange.**