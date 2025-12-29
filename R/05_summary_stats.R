# ==============================================================================
# MAINLINE WORKFLOW: 05_summary_stats.R
# ==============================================================================
# PURPOSE
# -------
# Generate comprehensive descriptive summary statistics and formatted tables
# from CallsPerNight final data and Master file. Creates publication-ready
# GT tables for detector performance, species composition, and temporal
# activity patterns.
#
# WORKFLOW POSITION
# -----------------
# This is Workflow 05 in the processing pipeline:
#   01_ingest_raw_data.R       → Load & intro-standardize raw CSVs
#   02_standardize.R           → Transform to master schema
#   03_generate_cpn_template.R → Generate template for editing
#   [USER: Edit template in Excel]
#   04_finalize_cpn.R          → Process edited template
#   05_summary_stats.R         → [THIS SCRIPT] Generate summary statistics
#
# INPUTS
# ------
# Required Files:
#   - outputs/04_CallsPerNight_Final_vX.csv (most recent version)
#   - outputs/02_kpro_master_YYYYMMDD_HHMMSS.csv (most recent)
#
# Optional (from memory if running sequentially):
#   - calls_per_night_final (from Workflow 04)
#   - kpro_master (from Workflow 02)
#
# DATA SOURCES AND THEIR PURPOSES
# --------------------------------
# **CallsPerNight_final** (aggregated, one row per detector-night):
#   - Detector activity metrics (calls per hour, variability)
#   - Recording effort metrics (hours, success rate)
#   - Variance decomposition (between/within detector)
#
# **Master file** (row-level, one row per call):
#   - Species composition and proportions
#   - Species accumulation over time
#   - Hourly activity profiles
#
# PROCESSING STAGES
# -----------------
# Stage 5.1: Load Data
#   - Locate and load most recent CallsPerNight_final
#   - Locate and load most recent Master file
#   - Validate required columns present
#
# Stage 5.2: Detector Activity Summary
#   - Create comprehensive per-detector summary
#   - Effort, activity, and variability metrics
#
# Stage 5.3: Study-Wide Summary
#   - Create single-row study overview
#   - Total calls, hours, detector-nights
#
# Stage 5.4: Variance Components
#   - Decompose variance into between/within detector
#   - Generate plain-English interpretation
#
# Stage 5.5: Species Composition
#   - Summarize species counts per detector
#   - Calculate proportions within detector and across study
#
# Stage 5.6: Species Accumulation
#   - Track cumulative species richness over study period
#   - Identify when new species were first detected
#
# Stage 5.7: Hourly Activity Profiles
#   - Create overall study hourly profile
#   - Create per-detector hourly profiles
#   - Identify peak activity hours
#
# Stage 5.8: Format GT Tables
#   - Apply consistent styling to all summary tibbles
#   - Create publication-ready tables
#
# Stage 5.9: Export Outputs
#   - Save GT tables as PNG (standalone viewing)
#   - Save GT tables as HTML (Quarto embedding)
#   - Save summary tibbles as RDS (programmatic access)
#   - Save all summaries to Excel workbook
#
# Stage 5.10: Summary Report
#   - Log processing summary
#   - Report key findings
#
# OUTPUTS
# -------
# Files Created:
#   results/figures/
#     - detector_activity_summary.png
#     - study_summary.png
#     - species_composition.png
#     - hourly_activity.png
#
#   results/tables/
#     - summary_statistics_YYYYMMDD.xlsx (multi-sheet workbook)
#
#   results/rds/
#     - summary_data_YYYYMMDD.rds (list of all summary tibbles)
#
#   logs/
#     - workflow_log_YYYYMMDD.txt (processing log)
#
# In Memory:
#   - detector_summary (tibble)
#   - study_summary (tibble)
#   - variance_components (tibble)
#   - species_summary (tibble)
#   - species_accumulation (tibble)
#   - hourly_summary_overall (tibble)
#   - hourly_summary_by_detector (tibble)
#   - all_summaries (list of all above)
#
# SUMMARY METRICS PRODUCED
# -------------------------
# **Detector Activity Summary:**
#   - n_nights, total_hours, mean_hours
#   - pct_success, pct_partial, pct_fail
#   - total_calls, mean_cpn, mean_cph, median_cph
#   - sd_cph, cv_pct, pct_zero
#   - first_night, last_night
#
# **Study-Wide Summary:**
#   - n_detectors, n_detector_nights
#   - study_start, study_end, study_duration_days
#   - total_calls, total_hours
#   - overall_mean_cph, overall_cv_pct
#   - pct_success, pct_partial, pct_fail
#
# **Variance Components:**
#   - var_between, var_within, var_total
#   - pct_between, pct_within
#   - interpretation (plain English)
#
# **Species Summary:**
#   - Detector, species, n_calls
#   - pct_of_detector, pct_of_species
#
# **Species Accumulation:**
#   - Night, night_number
#   - new_species, cumulative_species
#   - species_list (new species names)
#
# **Hourly Activity:**
#   - Hour (0-23), n_calls, pct_of_total
#   - Optional: by Detector
#
# PERFORMANCE EXPECTATIONS
# -------------------------
# Typical bat acoustic datasets:
#
# Small study (3 detectors, 30 nights, 5k calls):
#   - Processing: < 30 seconds
#
# Medium study (10 detectors, 90 nights, 50k calls):
#   - Processing: 1-2 minutes
#
# Large study (20+ detectors, 180 nights, 200k+ calls):
#   - Processing: 2-5 minutes
#   - Species accumulation may be slower for very large datasets
#
# DEPENDENCIES
# ------------
# R Packages:
#   - tidyverse (dplyr, readr, tidyr, purrr)
#   - lubridate (date/time extraction)
#   - gt (table formatting)
#   - webshot2 (PNG export for GT tables)
#   - openxlsx (Excel export)
#
# Custom Functions (via load_all.R):
#   - analysis/summarization.R:
#       create_detector_activity_summary()
#       create_study_summary()
#       calculate_variance_components()
#       create_species_summary_by_detector()
#       create_species_accumulation_summary()
#       create_hourly_activity_summary()
#
#   - output/tables.R:
#       format_detector_summary_gt()
#       format_species_summary_gt()
#       format_study_summary_gt()
#       format_hourly_summary_gt()
#       save_gt_table()
#
#   - core/utilities.R:
#       log_message()
#       safe_read_csv()
#
# TROUBLESHOOTING
# ---------------
# Issue: "CallsPerNight_final not found"
# Fix: Run 04_finalize_cpn.R first to generate final dataset
#
# Issue: "Master file not found"
# Fix: Run 02_standardize.R first to generate master file
#
# Issue: "No identified species found"
# Fix: Check that auto_id column contains valid species codes (not all NoID)
#
# Issue: "PNG export failed"
# Fix: Install webshot2 package: install.packages("webshot2")
#
# Issue: "Excel export failed"
# Fix: Install openxlsx package: install.packages("openxlsx")
#
# USAGE EXAMPLES
# --------------
# # Run after completing Workflow 04:
# source("R/workflows/05_summary_stats.R")
#
# # Inspect results:
# print(detector_summary)
# print(study_summary)
# print(variance_components$interpretation)
#
# # View species composition:
# species_summary %>%
#   group_by(Detector) %>%
#   slice_max(n_calls, n = 3)
#
# # Find peak activity hour:
# hourly_summary_overall %>%
#   slice_max(n_calls, n = 1)
#
# # Access all summaries:
# names(all_summaries)
#
# MAINTAINER NOTES
# ----------------
# - ASCII boxes: Single-line (┌─┐) for all stages
# - Stage numbering: 5.1 - 5.10 (10 stages total)
# - All statistics are DESCRIPTIVE only (no inference)
# - Species filtering excludes NoID, UNKNOWN, NA, blank
# - GT tables require webshot2 for PNG export
# - Excel workbook has one sheet per summary type
# - RDS file contains list for easy Quarto integration
#
# CHANGELOG
# ---------
# 2024-12-29: Initial version with comprehensive summary statistics
#
# ==============================================================================


# ==============================================================================
# SETUP
# ==============================================================================

# ------------------------------------------------------------------------------
# Load all functions
# ------------------------------------------------------------------------------

source("R/functions/load_all.R")

# ------------------------------------------------------------------------------
# Load required libraries
# ------------------------------------------------------------------------------

library(dplyr)
library(tidyr)
library(readr)
library(lubridate)
library(stringr)
library(here)
library(gt)

# Optional: Check for export packages
has_webshot2 <- requireNamespace("webshot2", quietly = TRUE)
has_openxlsx <- requireNamespace("openxlsx", quietly = TRUE)

if (!has_webshot2) {
  warning("Package 'webshot2' not installed - PNG export will be skipped")
}

if (!has_openxlsx) {
  warning("Package 'openxlsx' not installed - Excel export will be skipped")
}

# ------------------------------------------------------------------------------
# Initialize logging
# ------------------------------------------------------------------------------

log_message("=== WORKFLOW 05: Summary Statistics ===")

# ------------------------------------------------------------------------------
# Create output directories
# ------------------------------------------------------------------------------

# Ensure all output directories exist
dir.create("results/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("results/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("results/rds", recursive = TRUE, showWarnings = FALSE)

# Generate timestamp for output files
output_timestamp <- format(Sys.time(), "%Y%m%d")


# ==============================================================================
# STAGE 5.1: LOAD DATA
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.1: Load Data                               │")
message("└─────────────────────────────────────────────────────────────────┘\n")

# ------------------------------------------------------------------------------
# Load CallsPerNight Final
# ------------------------------------------------------------------------------

message("Loading CallsPerNight final data...")

# Check if in memory first
if (!exists("calls_per_night_final")) {
  
  # Look for most recent final file
  cpn_files <- list.files("outputs",
                          pattern = "^04_CallsPerNight_Final_v.*\\.csv$",
                          full.names = TRUE)
  
  if (length(cpn_files) == 0) {
    stop("No CallsPerNight_final files found. Please run 04_finalize_cpn.R first.")
  }
  
  # Get most recent by modification time
  cpn_file <- cpn_files[order(file.mtime(cpn_files), decreasing = TRUE)][1]
  
  message(sprintf("  Loading: %s", basename(cpn_file)))
  
  calls_per_night_final <- safe_read_csv(cpn_file)
  
  if (is.null(calls_per_night_final)) {
    stop("Failed to load CallsPerNight_final file")
  }
  
  # Ensure Night is Date class
  if (!inherits(calls_per_night_final$Night, "Date")) {
    calls_per_night_final <- calls_per_night_final %>%
      mutate(Night = as.Date(Night))
  }
  
} else {
  message("  Using calls_per_night_final from memory")
  cpn_file <- "(from memory)"
}

message(sprintf("✓ CallsPerNight final loaded: %s rows, %d detectors",
                format(nrow(calls_per_night_final), big.mark = ","),
                n_distinct(calls_per_night_final$Detector)))

# Validate required columns
cpn_required <- c("Detector", "Night", "CallsPerNight", "CallsPerHour", 
                  "RecordingHours", "Status")
cpn_missing <- setdiff(cpn_required, names(calls_per_night_final))

if (length(cpn_missing) > 0) {
  stop(sprintf("CallsPerNight_final missing required columns: %s",
               paste(cpn_missing, collapse = ", ")))
}

# ------------------------------------------------------------------------------
# Load Master File
# ------------------------------------------------------------------------------

message("\nLoading Master file...")

# Check if in memory first
if (!exists("kpro_master")) {
  
  # Look for most recent master file
  master_files <- list.files("outputs",
                             pattern = "^02_kpro_master_.*\\.csv$",
                             full.names = TRUE)
  
  if (length(master_files) == 0) {
    stop("No Master files found. Please run 02_standardize.R first.")
  }
  
  # Get most recent by modification time
  master_file <- master_files[order(file.mtime(master_files), decreasing = TRUE)][1]
  
  message(sprintf("  Loading: %s", basename(master_file)))
  
  kpro_master <- safe_read_csv(master_file)
  
  if (is.null(kpro_master)) {
    stop("Failed to load Master file")
  }
  
} else {
  message("  Using kpro_master from memory")
  master_file <- "(from memory)"
}

message(sprintf("✓ Master file loaded: %s rows",
                format(nrow(kpro_master), big.mark = ",")))

# Validate required columns for species/hourly analysis
master_required <- c("Detector", "auto_id")
master_missing <- setdiff(master_required, names(kpro_master))

if (length(master_missing) > 0) {
  warning(sprintf("Master file missing columns for full analysis: %s",
                  paste(master_missing, collapse = ", ")))
}

# Check for Hour or DateTime
has_hour <- "Hour" %in% names(kpro_master)
has_datetime <- "DateTime" %in% names(kpro_master)

if (!has_hour && !has_datetime) {
  warning("Master file has no Hour or DateTime column - hourly analysis will be skipped")
}

log_message(sprintf("Loaded data: CPN=%d rows, Master=%d rows",
                    nrow(calls_per_night_final), nrow(kpro_master)))


# ==============================================================================
# STAGE 5.2: DETECTOR ACTIVITY SUMMARY
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│          STAGE 5.2: Detector Activity Summary                   │")
message("└─────────────────────────────────────────────────────────────────┘\n")

detector_summary <- create_detector_activity_summary(calls_per_night_final)

# Display preview
message("\nDetector summary preview:")
print(detector_summary %>% 
        select(Detector, n_nights, total_calls, mean_cph, cv_pct) %>%
        head(5))

log_message(sprintf("Created detector summary: %d detectors", nrow(detector_summary)))


# ==============================================================================
# STAGE 5.3: STUDY-WIDE SUMMARY
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│            STAGE 5.3: Study-Wide Summary                        │")
message("└─────────────────────────────────────────────────────────────────┘\n")

study_summary <- create_study_summary(calls_per_night_final)

# Display summary
message("\nStudy overview:")
message(sprintf("  Detectors: %d", study_summary$n_detectors))
message(sprintf("  Detector-nights: %d", study_summary$n_detector_nights))
message(sprintf("  Study period: %s to %s (%d days)",
                study_summary$study_start, 
                study_summary$study_end,
                study_summary$study_duration_days))
message(sprintf("  Total calls: %s", format(study_summary$total_calls, big.mark = ",")))
message(sprintf("  Total hours: %s", format(study_summary$total_hours, big.mark = ",")))
message(sprintf("  Mean CPH: %.2f (CV: %.1f%%)", 
                study_summary$overall_mean_cph,
                study_summary$overall_cv_pct))

log_message(sprintf("Study summary: %d detectors, %s calls, %s hours",
                    study_summary$n_detectors,
                    format(study_summary$total_calls, big.mark = ","),
                    format(study_summary$total_hours, big.mark = ",")))


# ==============================================================================
# STAGE 5.4: VARIANCE COMPONENTS
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│           STAGE 5.4: Variance Components                        │")
message("└─────────────────────────────────────────────────────────────────┘\n")

variance_components <- calculate_variance_components(calls_per_night_final)

# Display interpretation
message("\nVariance decomposition:")
message(sprintf("  Between-detector: %.1f%%", variance_components$pct_between))
message(sprintf("  Within-detector:  %.1f%%", variance_components$pct_within))
message(sprintf("\n  Interpretation: %s", variance_components$interpretation))

log_message(sprintf("Variance: %.1f%% between, %.1f%% within",
                    variance_components$pct_between,
                    variance_components$pct_within))


# ==============================================================================
# STAGE 5.5: SPECIES COMPOSITION
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│           STAGE 5.5: Species Composition                        │")
message("└─────────────────────────────────────────────────────────────────┘\n")

# Check if auto_id column exists
if ("auto_id" %in% names(kpro_master)) {
  
  species_summary <- create_species_summary_by_detector(kpro_master)
  
  if (nrow(species_summary) > 0) {
    # Display top species
    message("\nTop 3 species per detector:")
    top_species <- species_summary %>%
      group_by(Detector) %>%
      slice_max(n_calls, n = 3, with_ties = FALSE) %>%
      ungroup()
    
    print(top_species %>% head(12))
    
    # Overall species count
    n_species <- n_distinct(species_summary$species)
    message(sprintf("\n✓ Total species detected: %d", n_species))
    
    log_message(sprintf("Species summary: %d species across %d detectors",
                        n_species, n_distinct(species_summary$Detector)))
  } else {
    message("⚠ No identified species found in Master data")
    species_summary <- NULL
  }
  
} else {
  warning("auto_id column not found - skipping species summary")
  species_summary <- NULL
}


# ==============================================================================
# STAGE 5.6: SPECIES ACCUMULATION
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│          STAGE 5.6: Species Accumulation                        │")
message("└─────────────────────────────────────────────────────────────────┘\n")

if ("auto_id" %in% names(kpro_master) && !is.null(species_summary)) {
  
  # Study-wide accumulation
  species_accumulation <- create_species_accumulation_summary(kpro_master, by_detector = FALSE)
  
  if (nrow(species_accumulation) > 0) {
    # Display accumulation summary
    final_richness <- max(species_accumulation$cumulative_species)
    nights_to_plateau <- species_accumulation %>%
      filter(cumulative_species == final_richness) %>%
      slice_min(night_number, n = 1) %>%
      pull(night_number)
    
    message("\nSpecies accumulation:")
    message(sprintf("  Final richness: %d species", final_richness))
    message(sprintf("  Reached plateau: Night %d of %d", 
                    nights_to_plateau, 
                    max(species_accumulation$night_number)))
    
    # Show first few nights of accumulation
    message("\nFirst detections:")
    first_detections <- species_accumulation %>%
      filter(new_species > 0) %>%
      head(5)
    print(first_detections %>% select(Night, night_number, new_species, cumulative_species))
    
    log_message(sprintf("Species accumulation: %d species, plateau at night %d",
                        final_richness, nights_to_plateau))
  } else {
    message("⚠ Could not calculate species accumulation")
    species_accumulation <- NULL
  }
  
} else {
  message("Skipping species accumulation (no species data)")
  species_accumulation <- NULL
}


# ==============================================================================
# STAGE 5.7: HOURLY ACTIVITY PROFILES
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│          STAGE 5.7: Hourly Activity Profiles                    │")
message("└─────────────────────────────────────────────────────────────────┘\n")

if (has_hour || has_datetime) {
  
  # Overall hourly profile
  message("Creating study-wide hourly profile...")
  hourly_summary_overall <- create_hourly_activity_summary(kpro_master, by_detector = FALSE)
  
  # Find peak hour
  peak_row <- hourly_summary_overall %>%
    slice_max(n_calls, n = 1)
  
  message(sprintf("\nPeak activity: %02d:00 (%s calls, %.1f%% of total)",
                  as.integer(sub(":00", "", peak_row$Hour)),
                  format(peak_row$n_calls, big.mark = ","),
                  peak_row$pct_of_total))
  
  # Per-detector hourly profiles
  message("\nCreating per-detector hourly profiles...")
  hourly_summary_by_detector <- create_hourly_activity_summary(kpro_master, by_detector = TRUE)
  
  message(sprintf("✓ Created hourly profiles for %d detectors",
                  n_distinct(hourly_summary_by_detector$Detector)))
  
  log_message(sprintf("Hourly profiles: peak at %s", peak_row$Hour))
  
} else {
  message("Skipping hourly analysis (no Hour or DateTime column)")
  hourly_summary_overall <- NULL
  hourly_summary_by_detector <- NULL
}


# ==============================================================================
# STAGE 5.8: FORMAT GT TABLES
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│            STAGE 5.8: Format GT Tables                          │")
message("└─────────────────────────────────────────────────────────────────┘\n")

# Store all GT tables in a list
gt_tables <- list()

# ------------------------------------------------------------------------------
# Detector Activity Summary Table
# ------------------------------------------------------------------------------

message("Formatting detector activity summary...")
gt_tables$detector_summary <- format_detector_summary_gt(
  detector_summary,
  title = "Detector Activity Summary",
  subtitle = sprintf("Study Period: %s to %s", 
                     study_summary$study_start, 
                     study_summary$study_end)
)
message("  ✓ Detector summary table formatted")

# ------------------------------------------------------------------------------
# Study Summary Table
# ------------------------------------------------------------------------------

message("Formatting study summary...")
gt_tables$study_summary <- format_study_summary_gt(
  study_summary,
  title = "Study Overview",
  orientation = "vertical"
)
message("  ✓ Study summary table formatted")

# ------------------------------------------------------------------------------
# Species Summary Table
# ------------------------------------------------------------------------------

if (!is.null(species_summary) && nrow(species_summary) > 0) {
  message("Formatting species summary...")
  gt_tables$species_summary_long <- format_species_summary_gt(
    species_summary,
    format = "long",
    title = "Species Composition by Detector",
    top_n = 10  # Top 10 species per detector
  )
  
  # Also create wide format if not too many species
  n_species <- n_distinct(species_summary$species)
  if (n_species <= 15) {
    gt_tables$species_summary_wide <- format_species_summary_gt(
      species_summary,
      format = "wide",
      title = "Species × Detector Matrix"
    )
    message("  ✓ Species tables formatted (long and wide)")
  } else {
    message(sprintf("  ✓ Species table formatted (long only, %d species too many for wide)", n_species))
  }
}

# ------------------------------------------------------------------------------
# Hourly Activity Table
# ------------------------------------------------------------------------------

if (!is.null(hourly_summary_overall)) {
  message("Formatting hourly activity table...")
  gt_tables$hourly_summary <- format_hourly_summary_gt(
    hourly_summary_overall,
    title = "Hourly Activity Profile",
    subtitle = "Study-wide (all detectors combined)",
    highlight_peak = TRUE
  )
  message("  ✓ Hourly activity table formatted")
}

message(sprintf("\n✓ Created %d GT tables", length(gt_tables)))

log_message(sprintf("Formatted %d GT tables", length(gt_tables)))


# ==============================================================================
# STAGE 5.9: EXPORT OUTPUTS
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│             STAGE 5.9: Export Outputs                           │")
message("└─────────────────────────────────────────────────────────────────┘\n")

# ------------------------------------------------------------------------------
# Export GT Tables as PNG
# ------------------------------------------------------------------------------

if (has_webshot2) {
  message("Exporting GT tables as PNG...")
  
  for (table_name in names(gt_tables)) {
    save_gt_table(
      gt_tables[[table_name]],
      filename = table_name,
      output_dir = "results/figures",
      format = "png"
    )
  }
  
  message(sprintf("  ✓ Saved %d PNG files to results/figures/", length(gt_tables)))
} else {
  message("⚠ Skipping PNG export (webshot2 not installed)")
}

# ------------------------------------------------------------------------------
# Export GT Tables as HTML
# ------------------------------------------------------------------------------

message("\nExporting GT tables as HTML...")

for (table_name in names(gt_tables)) {
  save_gt_table(
    gt_tables[[table_name]],
    filename = table_name,
    output_dir = "results/figures",
    format = "html"
  )
}

message(sprintf("  ✓ Saved %d HTML files to results/figures/", length(gt_tables)))

# ------------------------------------------------------------------------------
# Export to Excel Workbook
# ------------------------------------------------------------------------------

if (has_openxlsx) {
  message("\nExporting summaries to Excel workbook...")
  
  wb <- openxlsx::createWorkbook()
  
  # Detector summary sheet
  openxlsx::addWorksheet(wb, "Detector Summary")
  openxlsx::writeData(wb, "Detector Summary", detector_summary)
  
  # Study summary sheet
  openxlsx::addWorksheet(wb, "Study Summary")
  study_summary_long <- study_summary %>%
    tidyr::pivot_longer(everything(), names_to = "Metric", values_to = "Value")
  openxlsx::writeData(wb, "Study Summary", study_summary_long)
  
  # Variance components sheet
  openxlsx::addWorksheet(wb, "Variance Components")
  openxlsx::writeData(wb, "Variance Components", variance_components)
  
  # Species summary sheet (if available)
  if (!is.null(species_summary) && nrow(species_summary) > 0) {
    openxlsx::addWorksheet(wb, "Species Summary")
    openxlsx::writeData(wb, "Species Summary", species_summary)
  }
  
  # Species accumulation sheet (if available)
  if (!is.null(species_accumulation) && nrow(species_accumulation) > 0) {
    openxlsx::addWorksheet(wb, "Species Accumulation")
    openxlsx::writeData(wb, "Species Accumulation", species_accumulation)
  }
  
  # Hourly summary sheet (if available)
  if (!is.null(hourly_summary_overall)) {
    openxlsx::addWorksheet(wb, "Hourly Activity")
    openxlsx::writeData(wb, "Hourly Activity", hourly_summary_overall)
  }
  
  # Save workbook
  excel_path <- sprintf("results/tables/summary_statistics_%s.xlsx", output_timestamp)
  openxlsx::saveWorkbook(wb, excel_path, overwrite = TRUE)
  
  message(sprintf("  ✓ Saved Excel workbook: %s", excel_path))
  
} else {
  message("⚠ Skipping Excel export (openxlsx not installed)")
}

# ------------------------------------------------------------------------------
# Export Summary Tibbles as RDS
# ------------------------------------------------------------------------------

message("\nExporting summary tibbles as RDS...")

all_summaries <- list(
  detector_summary = detector_summary,
  study_summary = study_summary,
  variance_components = variance_components,
  species_summary = species_summary,
  species_accumulation = species_accumulation,
  hourly_summary_overall = hourly_summary_overall,
  hourly_summary_by_detector = hourly_summary_by_detector,
  metadata = list(
    generated_at = Sys.time(),
    cpn_source = ifelse(exists("cpn_file"), cpn_file, "memory"),
    master_source = ifelse(exists("master_file"), master_file, "memory")
  )
)

rds_path <- sprintf("results/rds/summary_data_%s.rds", output_timestamp)
saveRDS(all_summaries, rds_path)

message(sprintf("  ✓ Saved RDS file: %s", rds_path))

log_message(sprintf("Exported: PNG=%s, HTML=%d, Excel=%s, RDS=%s",
                    ifelse(has_webshot2, length(gt_tables), "skipped"),
                    length(gt_tables),
                    ifelse(has_openxlsx, "yes", "skipped"),
                    "yes"))


# ==============================================================================
# STAGE 5.10: SUMMARY REPORT
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│            STAGE 5.10: Summary Report                           │")
message("└─────────────────────────────────────────────────────────────────┘\n")

message("═══════════════════════════════════════════════════════════════════")
message("                    WORKFLOW 05 COMPLETE                           ")
message("═══════════════════════════════════════════════════════════════════")

message("\n📊 STUDY OVERVIEW")
message(sprintf("   Detectors:        %d", study_summary$n_detectors))
message(sprintf("   Detector-nights:  %d", study_summary$n_detector_nights))
message(sprintf("   Study duration:   %d days", study_summary$study_duration_days))
message(sprintf("   Total calls:      %s", format(study_summary$total_calls, big.mark = ",")))
message(sprintf("   Total hours:      %s", format(study_summary$total_hours, big.mark = ",")))

message("\n📈 ACTIVITY METRICS")
message(sprintf("   Mean CPH:         %.2f", study_summary$overall_mean_cph))
message(sprintf("   Median CPH:       %.2f", study_summary$overall_median_cph))
message(sprintf("   CV:               %.1f%%", study_summary$overall_cv_pct))
message(sprintf("   Success rate:     %.1f%%", study_summary$pct_success))

message("\n🔬 VARIANCE DECOMPOSITION")
message(sprintf("   Between-detector: %.1f%%", variance_components$pct_between))
message(sprintf("   Within-detector:  %.1f%%", variance_components$pct_within))

if (!is.null(species_summary) && nrow(species_summary) > 0) {
  message("\n🦇 SPECIES")
  message(sprintf("   Species detected: %d", n_distinct(species_summary$species)))
  
  # Most common species overall
  top_overall <- species_summary %>%
    group_by(species) %>%
    summarise(total = sum(n_calls), .groups = "drop") %>%
    slice_max(total, n = 3)
  
  message("   Most common:")
  for (i in seq_len(nrow(top_overall))) {
    message(sprintf("     %d. %s (%s calls)", 
                    i, 
                    top_overall$species[i],
                    format(top_overall$total[i], big.mark = ",")))
  }
}

if (!is.null(hourly_summary_overall)) {
  peak <- hourly_summary_overall %>% slice_max(n_calls, n = 1)
  message("\n⏰ TEMPORAL PATTERNS")
  message(sprintf("   Peak hour:        %s (%.1f%% of calls)", 
                  peak$Hour, peak$pct_of_total))
}

message("\n📁 OUTPUTS CREATED")
message(sprintf("   PNG tables:       %s", 
                ifelse(has_webshot2, 
                       sprintf("%d files in results/figures/", length(gt_tables)),
                       "skipped (install webshot2)")))
message(sprintf("   HTML tables:      %d files in results/figures/", length(gt_tables)))
message(sprintf("   Excel workbook:   %s",
                ifelse(has_openxlsx,
                       sprintf("results/tables/summary_statistics_%s.xlsx", output_timestamp),
                       "skipped (install openxlsx)")))
message(sprintf("   RDS data:         results/rds/summary_data_%s.rds", output_timestamp))

message("\n═══════════════════════════════════════════════════════════════════")
message("   Summary statistics ready for analysis and reporting!")
message("═══════════════════════════════════════════════════════════════════\n")

log_message("=== WORKFLOW 05 COMPLETE ===")


# ==============================================================================
# OBJECTS AVAILABLE IN ENVIRONMENT
# ==============================================================================
#
# After running this script, the following objects are available:
#
# Summary tibbles:
#   - detector_summary         Per-detector effort & activity summary
#   - study_summary            Single-row study overview
#   - variance_components      Between/within detector variance
#   - species_summary          Species counts by detector (if available)
#   - species_accumulation     Cumulative species over time (if available)
#   - hourly_summary_overall   Study-wide hourly profile (if available)
#   - hourly_summary_by_detector Per-detector hourly (if available)
#
# GT table objects:
#   - gt_tables                List of formatted GT tables
#
# Master list:
#   - all_summaries            List containing all summary tibbles + metadata
#
# ==============================================================================