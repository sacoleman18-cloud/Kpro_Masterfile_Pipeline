# ==============================================================================
# MAINLINE WORKFLOW: 05_summary_stats.R
# ==============================================================================
# PURPOSE
# -------
# Generate comprehensive descriptive summary statistics for bat acoustic data.
# Creates detector-level summaries, study-wide overviews, species composition,
# temporal patterns, and publication-ready GT tables.
#
# This workflow is DESCRIPTIVE ONLY - no statistical inference or hypothesis
# testing. All outputs are meant for data exploration and reporting.
#
# WORKFLOW POSITION
# -----------------
# This is Workflow 05 in the processing pipeline:
#   01_ingest_raw_data.R  → Load & intro-standardize raw CSVs
#   02_standardize.R      → Transform to master schema
#   [OPTIONAL: Manual ID in Kaleidoscope]
#   03_generate_cpn_template.R → Generate template for editing
#   [USER: Edit template in Excel]
#   04_finalize_cpn.R     → Process edited template
#   05_summary_stats.R    → [THIS SCRIPT] Generate summary statistics
#   06_generate_report.R  → Create final report (if applicable)
#
# INPUTS
# ------
# In Memory (preferred):
#   - calls_per_night_final (from Workflow 04)
#   - kpro_master (from Workflow 02/03)
#
# OR Checkpoints (fallback):
#   - results/csv/CallsPerNight_final_vX.csv (most recent version)
#   - outputs/02_kpro_master_YYYYMMDD_HHMMSS.csv
#
# Configuration Files:
#   - inst/config/study_parameters.yaml (study metadata)
#
# PROCESSING STAGES
# -----------------
# Stage 5.1: Load Data
#   - Loads CallsPerNight_final (from memory or checkpoint)
#   - Loads Master file (from memory or checkpoint)
#   - Validates required columns
#   - Type coercion for Date/numeric columns
#
# Stage 5.2: Detector Activity Summary
#   - Creates comprehensive per-detector summary
#   - Effort, activity, variability metrics
#
# Stage 5.3: Study-Wide Summary
#   - Single-row study overview
#   - Total calls, hours, detector-nights
#   - Mean CPH, CV, success rates
#
# Stage 5.4: Variance Components
#   - Between/within detector variance decomposition
#   - Plain-English interpretation
#
# Stage 5.5: Species Composition
#   - Species counts per detector
#   - Top species identification
#
# Stage 5.6: Species Accumulation
#   - Cumulative species richness over time
#   - Plateau detection
#
# Stage 5.7: Hourly Activity Profiles
#   - Study-wide hourly profile
#   - Per-detector hourly profiles
#   - Peak hour identification
#
# Stage 5.8: Format GT Tables
#   - Applies consistent styling to all summaries
#   - Creates publication-ready tables
#
# Stage 5.9: Export Outputs
#   - PNG export (if webshot2 installed)
#   - HTML export (always)
#   - Excel workbook (if openxlsx installed)
#   - RDS file (always)
#
# Stage 5.10: Summary Report
#   - Console output with study overview
#   - Lists all outputs created
#
# OUTPUTS
# -------
# Files Created:
#   - results/figures/detector_summary_YYYYMMDD.png (GT table)
#   - results/figures/detector_summary_YYYYMMDD.html (GT table)
#   - results/figures/study_summary_YYYYMMDD.png (GT table)
#   - results/figures/study_summary_YYYYMMDD.html (GT table)
#   - results/tables/summary_statistics_YYYYMMDD.xlsx (multi-sheet workbook)
#   - results/rds/summary_data_YYYYMMDD.rds (all summaries as list)
#   - logs/workflow_log_YYYYMMDD.txt (processing log)
#   - results/validation/validation_05_YYYYMMDD_HHMMSS.yaml (validation log)
#   - results/validation/validation_05_YYYYMMDD_HHMMSS.html (validation report)
#
# In Memory:
#   - detector_summary (tibble)
#   - study_summary (tibble)
#   - variance_components (list)
#   - species_summary (tibble)
#   - species_accumulation (tibble)
#   - hourly_summary_overall (tibble)
#   - hourly_summary_by_detector (tibble)
#   - gt_tables (list of GT objects)
#   - all_summaries (master list)
#
# Registry:
#   - inst/config/artifact_registry.yaml (updated with summary stats RDS)
#
# VALIDATION TRACKING
# -------------------
# This workflow tracks the following validation events:
#   - data_loaded: CallsPerNight final loaded
#   - data_loaded: Master file loaded
#   - summary_generated: Detector activity summary
#   - summary_generated: Study-wide summary
#   - summary_generated: Variance components
#   - summary_generated: Species composition (if available)
#   - summary_generated: Species accumulation (if available)
#   - summary_generated: Hourly activity profiles (if available)
#   - tables_created: GT tables formatted
#   - files_exported: PNG exports (if available)
#   - files_exported: HTML exports
#   - files_exported: Excel export (if available)
#   - files_exported: RDS file saved
#
# PERFORMANCE EXPECTATIONS
# -------------------------
# Typical bat acoustic datasets:
#
# Small study (3 detectors, 30 nights):
#   - Processing: < 30 seconds
#
# Medium study (10 detectors, 90 nights):
#   - Processing: < 1 minute
#
# Large study (20+ detectors, 180 nights):
#   - Processing: 1-2 minutes
#
# Note: GT table rendering may take additional time
#
# DEPENDENCIES
# ------------
# R Packages (required):
#   - tidyverse (dplyr, readr, tidyr, purrr)
#   - gt (table formatting)
#   - here (path management)
#
# R Packages (optional):
#   - webshot2 (for PNG export)
#   - openxlsx (for Excel export)
#
# Custom Functions (via load_all.R):
#   - core/utilities.R: log_message, load_cpn_final, load_master_data
#   - core/artifacts.R: create_validation_context, log_validation_event,
#                       finalize_validation_report, init_artifact_registry,
#                       register_artifact
#   - validation/validation.R: validate_cpn_data, validate_master_data,
#                              assert_directory_exists, require_study_parameters
#   - analysis/summarization.R: create_detector_activity_summary,
#                               create_study_summary, calculate_variance_components,
#                               create_species_summary_by_detector,
#                               create_species_accumulation_summary,
#                               create_hourly_activity_summary
#   - output/tables.R: format_detector_summary_gt, format_study_summary_gt,
#                      format_species_summary_gt, format_hourly_summary_gt,
#                      save_gt_table
#
# Configuration Files:
#   - inst/config/study_parameters.yaml (study metadata)
#
# TROUBLESHOOTING
# ---------------
# Issue: "CallsPerNight_final not found"
# Fix: Run 04_finalize_cpn.R first
#
# Issue: "kpro_master not found"
# Fix: Run 02_standardize.R first
#
# Issue: "PNG export failed"
# Fix: Install webshot2 package: install.packages("webshot2")
#
# Issue: "Excel export failed"
# Fix: Install openxlsx package: install.packages("openxlsx")
#
# USAGE EXAMPLES
# --------------
# # Run after Workflow 04:
# source("R/workflows/05_summary_stats.R")
#
# # Inspect results:
# detector_summary
# study_summary
# gt_tables$detector_summary
#
# # Access all summaries:
# names(all_summaries)
#
# MAINTAINER NOTES
# ----------------
# - ASCII boxes: Single-line (┌─┐) for all stages
# - Stage numbering: 5.1 - 5.10
# - All summaries are DESCRIPTIVE only (no inference)
# - GT tables use consistent white background styling
# - Optional packages gracefully degrade if not installed
# - RDS output always created for programmatic access
#
# CHANGELOG
# ---------
# 2026-01-12: Enhanced validation tracking for all summary stages and exports
# 2026-01-12: Added artifact registration for summary statistics RDS (v2.1)
# 2026-01-09: Updated section 5.1 to have *_local after time values
# 2025-12-29: Initial version following CODING_STANDARDS
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Load all functions
# ------------------------------------------------------------------------------

source("R/functions/load_all.R")

# ------------------------------------------------------------------------------
# Load required libraries
# ------------------------------------------------------------------------------

library(tidyverse)
library(gt)

# Check for optional packages
has_webshot2 <- requireNamespace("webshot2", quietly = TRUE)
has_openxlsx <- requireNamespace("openxlsx", quietly = TRUE)

if (!has_webshot2) {
  message("Note: webshot2 not installed - PNG export will be skipped")
  message("      Install with: install.packages('webshot2')")
}

if (!has_openxlsx) {
  message("Note: openxlsx not installed - Excel export will be skipped")
  message("      Install with: install.packages('openxlsx')")
}

# ------------------------------------------------------------------------------
# Initialize logging
# ------------------------------------------------------------------------------

log_message("=== WORKFLOW 05: Generate Summary Statistics ===")

# ------------------------------------------------------------------------------
# Initialize validation context
# ------------------------------------------------------------------------------

validation_context <- create_validation_context(
  workflow = "05",
  study_name = NULL  # Will be set from params if available
)

# Load study parameters if available (for study name)
params <- tryCatch({
  require_study_parameters()
}, error = function(e) {
  NULL
})

if (!is.null(params)) {
  validation_context$study_name <- params$study_parameters$study_name
}

# ==============================================================================
# STAGE 5.1: LOAD DATA
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.1: Load Data                              │")
message("└─────────────────────────────────────────────────────────────────┘\n")

# ------------------------------------------------------------------------------
# Load CallsPerNight Final
# ------------------------------------------------------------------------------

message("Loading CallsPerNight final data...")

calls_per_night_final <- load_cpn_final()

validate_cpn_data(calls_per_night_final, require_status = TRUE, require_cph = TRUE)

n_cpn_rows <- nrow(calls_per_night_final)
n_detectors <- n_distinct(calls_per_night_final$Detector)

message(sprintf("✓ CallsPerNight final loaded: %s rows, %d detectors",
                format(n_cpn_rows, big.mark = ","),
                n_detectors))

log_message(sprintf("[Stage 5.1] Loaded CallsPerNight: %d rows, %d detectors", 
                    n_cpn_rows, n_detectors))

# Log CallsPerNight loading
validation_context <- log_validation_event(
  validation_context,
  event_type = "data_loaded",
  description = sprintf("Loaded CallsPerNight final: %s rows", format(n_cpn_rows, big.mark = ",")),
  count = n_cpn_rows,
  details = list(
    n_detectors = n_detectors,
    n_nights = n_distinct(calls_per_night_final$Night),
    data_validated = TRUE
  )
)

# ------------------------------------------------------------------------------
# Load Master File
# ------------------------------------------------------------------------------

message("\nLoading Master file...")

kpro_master <- load_master_data()

validate_master_data(kpro_master)

n_master_rows <- nrow(kpro_master)

message(sprintf("✓ Master file loaded: %s rows",
                format(n_master_rows, big.mark = ",")))

log_message(sprintf("[Stage 5.1] Loaded Master: %d rows", n_master_rows))

# Check for Hour or DateTime (needed for hourly analysis)
has_hour <- "Hour_local" %in% names(kpro_master)
has_datetime <- "DateTime_local" %in% names(kpro_master)

if (!has_hour && !has_datetime) {
  warning("Master file has no Hour_local or DateTime_local column - hourly analysis will be skipped")
}

# Log Master file loading
validation_context <- log_validation_event(
  validation_context,
  event_type = "data_loaded",
  description = sprintf("Loaded Master file: %s rows", format(n_master_rows, big.mark = ",")),
  count = n_master_rows,
  details = list(
    has_hour_column = has_hour,
    has_datetime_column = has_datetime,
    has_species_column = "species" %in% names(kpro_master),
    data_validated = TRUE
  )
)

# ==============================================================================
# STAGE 5.2: DETECTOR ACTIVITY SUMMARY
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.2: Detector Activity Summary              │")
message("└─────────────────────────────────────────────────────────────────┘\n")

message("Creating detector activity summary...")

detector_summary <- create_detector_activity_summary(calls_per_night_final)

n_detector_summary <- nrow(detector_summary)

message(sprintf("✓ Detector summary created: %d detectors", n_detector_summary))

# Preview
message("\nDetector summary preview (top 5 by total calls):")
preview <- detector_summary %>%
  arrange(desc(total_calls)) %>%
  head(10) %>%
  select(Detector, n_nights, total_hours, total_calls, mean_cph, pct_success)

for (i in seq_len(nrow(preview))) {
  message(sprintf("  %s: %d nights, %.0f hrs, %s calls, %.2f CPH, %.0f%% success",
                  preview$Detector[i],
                  preview$n_nights[i],
                  preview$total_hours[i],
                  format(preview$total_calls[i], big.mark = ","),
                  preview$mean_cph[i],
                  preview$pct_success[i]))
}

log_message(sprintf("[Stage 5.2] Created detector summary: %d detectors", n_detector_summary))

# Log detector summary creation
validation_context <- log_validation_event(
  validation_context,
  event_type = "summary_generated",
  description = sprintf("Created detector activity summary: %d detectors", n_detector_summary),
  count = n_detector_summary,
  details = list(
    summary_type = "detector_activity",
    metrics_calculated = c("effort", "activity", "variability", "success_rate")
  )
)

# ==============================================================================
# STAGE 5.3: STUDY-WIDE SUMMARY
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.3: Study-Wide Summary                     │")
message("└─────────────────────────────────────────────────────────────────┘\n")

message("Creating study-wide summary...")

study_summary <- create_study_summary(calls_per_night_final)

message("✓ Study summary created")

# Display key metrics
message("\nStudy overview:")
message(sprintf("  Total detectors: %d", study_summary$n_detectors))
message(sprintf("  Total detector-nights: %s", format(study_summary$n_detector_nights, big.mark = ",")))
message(sprintf("  Total recording hours: %.1f", study_summary$total_hours))
message(sprintf("  Total calls: %s", format(study_summary$total_calls, big.mark = ",")))
message(sprintf("  Mean calls per hour: %.2f", study_summary$overall_mean_cph))
message(sprintf("  Mean calls per night: %.1f", study_summary$overall_mean_cpn))
message(sprintf("  Success rate: %.1f%%", study_summary$pct_success))

log_message("[Stage 5.3] Created study summary")

# Log study summary creation
validation_context <- log_validation_event(
  validation_context,
  event_type = "summary_generated",
  description = "Created study-wide summary",
  details = list(
    summary_type = "study_wide",
    n_detectors = study_summary$n_detectors,
    n_detector_nights = study_summary$n_detector_nights,
    total_calls = study_summary$total_calls,
    total_hours = round(study_summary$total_hours, 1),
    mean_cph = round(study_summary$overall_mean_cph, 2),
    success_rate_pct = round(study_summary$pct_success, 1)
  )
)

# ==============================================================================
# STAGE 5.4: VARIANCE COMPONENTS
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.4: Variance Components                    │")
message("└─────────────────────────────────────────────────────────────────┘\n")

message("Calculating variance components...")

variance_components <- calculate_variance_components(calls_per_night_final)

message("✓ Variance components calculated")

# Display interpretation
message("\nVariance decomposition:")
message(sprintf("  Between-detector variance: %.1f%%", variance_components$pct_between))
message(sprintf("  Within-detector variance: %.1f%%", variance_components$pct_within))
message(sprintf("  Interpretation: %s", variance_components$interpretation))

log_message("[Stage 5.4] Calculated variance components")

# Log variance components
validation_context <- log_validation_event(
  validation_context,
  event_type = "summary_generated",
  description = "Calculated variance components",
  details = list(
    summary_type = "variance_decomposition",
    pct_between = round(variance_components$pct_between, 1),
    pct_within = round(variance_components$pct_within, 1),
    interpretation = variance_components$interpretation
  )
)

# ==============================================================================
# STAGE 5.5: SPECIES COMPOSITION
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.5: Species Composition                    │")
message("└─────────────────────────────────────────────────────────────────┘\n")

if ("species" %in% names(kpro_master)) {
  message("Creating species composition summary...")
  
  species_summary <- create_species_summary_by_detector(kpro_master)
  
  n_species <- n_distinct(species_summary$species)
  message(sprintf("✓ Species summary created: %d species detected", n_species))
  
  # Show top 3 species per detector
  message("\nTop 3 species by detector:")
  top_species <- species_summary %>%
    group_by(Detector) %>%
    slice_max(n_calls, n = 3) %>%
    summarise(top3 = paste(species, collapse = ", "), .groups = "drop")
  
  for (i in seq_len(min(5, nrow(top_species)))) {
    message(sprintf("  %s: %s", top_species$Detector[i], top_species$top3[i]))
  }
  
  if (nrow(top_species) > 5) {
    message(sprintf("  ... and %d more detectors", nrow(top_species) - 5))
  }
  
  log_message(sprintf("[Stage 5.5] Created species summary: %d species", n_species))
  
  # Log species composition
  validation_context <- log_validation_event(
    validation_context,
    event_type = "summary_generated",
    description = sprintf("Created species composition summary: %d species", n_species),
    details = list(
      summary_type = "species_composition",
      n_species = n_species,
      n_detectors = n_distinct(species_summary$Detector)
    )
  )
  
} else {
  warning("species column not found - skipping species summary")
  species_summary <- NULL
  log_message("[Stage 5.5] Skipped species summary (no species column)")
}

# ==============================================================================
# STAGE 5.6: SPECIES ACCUMULATION
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.6: Species Accumulation                   │")
message("└─────────────────────────────────────────────────────────────────┘\n")

if ("species" %in% names(kpro_master) && "Night" %in% names(kpro_master)) {
  message("Creating species accumulation summary...")
  
  # Pass date_col = "Night" to use Night column
  species_accumulation <- create_species_accumulation_summary(
    kpro_master, 
    date_col = "Night"
  )
  
  final_richness <- max(species_accumulation$cumulative_species, na.rm = TRUE)
  message(sprintf("✓ Species accumulation calculated: %d total species", final_richness))
  
  # Show first detections
  message("\nFirst detections:")
  first_detections <- species_accumulation %>%
    filter(!is.na(new_species_list) & new_species_list != "") %>%
    head(5)
  
  for (i in seq_len(nrow(first_detections))) {
    message(sprintf("  %s: %s (cumulative: %d)", 
                    first_detections$Night[i],
                    first_detections$new_species_list[i],
                    first_detections$cumulative_species[i]))
  }
  
  log_message(sprintf("[Stage 5.6] Created species accumulation: %d total species", final_richness))
  
  # Log species accumulation
  validation_context <- log_validation_event(
    validation_context,
    event_type = "summary_generated",
    description = sprintf("Created species accumulation: %d total species", final_richness),
    details = list(
      summary_type = "species_accumulation",
      final_richness = final_richness,
      n_nights = nrow(species_accumulation)
    )
  )
  
} else {
  warning("Required columns not found - skipping species accumulation")
  species_accumulation <- NULL
  log_message("[Stage 5.6] Skipped species accumulation")
}


# ==============================================================================
# STAGE 5.7: HOURLY ACTIVITY PROFILES
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.7: Hourly Activity Profiles               │")
message("└─────────────────────────────────────────────────────────────────┘\n")

if (has_hour || has_datetime) {
  message("Creating hourly activity profiles...")
  
  # Add Hour column if not present
  if (!has_hour && has_datetime) {
    kpro_master <- kpro_master %>%
      mutate(Hour_local = lubridate::hour(DateTime_local))
  }
  
  # Study-wide hourly profile
  hourly_summary_overall <- create_hourly_activity_summary(kpro_master, by_detector = FALSE)
  
  # Per-detector hourly profile
  hourly_summary_by_detector <- create_hourly_activity_summary(kpro_master, by_detector = TRUE)
  
  # Find peak hour
  peak_hour <- hourly_summary_overall %>%
    slice_max(n_calls, n = 1)
  
  message(sprintf("✓ Hourly profiles created"))
  message(sprintf("  Peak hour: %02d:00 (%s calls, %.1f%% of total)",
                  peak_hour$Hour_local,
                  format(peak_hour$n_calls, big.mark = ","),
                  peak_hour$pct_of_total))
  
  log_message("[Stage 5.7] Created hourly activity profiles")
  
  # Log hourly profiles
  validation_context <- log_validation_event(
    validation_context,
    event_type = "summary_generated",
    description = "Created hourly activity profiles",
    details = list(
      summary_type = "hourly_activity",
      peak_hour = peak_hour$Hour_local,
      peak_hour_calls = peak_hour$n_calls,
      study_wide_profile = TRUE,
      by_detector_profile = TRUE
    )
  )
  
} else {
  warning("No Hour or DateTime column - skipping hourly analysis")
  hourly_summary_overall <- NULL
  hourly_summary_by_detector <- NULL
  log_message("[Stage 5.7] Skipped hourly analysis")
}


# ==============================================================================
# STAGE 5.8: FORMAT GT TABLES
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.8: Format GT Tables                       │")
message("└─────────────────────────────────────────────────────────────────┘\n")

message("Formatting GT tables...")

gt_tables <- list()

# Detector summary table
gt_tables$detector_summary <- format_detector_summary_gt(detector_summary)
message("  ✓ Detector summary table")

# Study summary table
gt_tables$study_summary <- format_study_summary_gt(study_summary, orientation = "horizontal")
message("  ✓ Study summary table")

# Species summary table (if available)
if (!is.null(species_summary)) {
  gt_tables$species_summary <- format_species_summary_gt(species_summary, format = "wide")
  message("  ✓ Species summary table")
}

# Hourly summary table (if available)
if (!is.null(hourly_summary_overall)) {
  gt_tables$hourly_summary <- format_hourly_summary_gt(hourly_summary_overall)
  message("  ✓ Hourly summary table")
}

n_tables <- length(gt_tables)

message(sprintf("\n✓ Created %d GT tables", n_tables))

log_message(sprintf("[Stage 5.8] Created %d GT tables", n_tables))

# Log GT table creation
validation_context <- log_validation_event(
  validation_context,
  event_type = "tables_created",
  description = sprintf("Formatted %d GT tables", n_tables),
  count = n_tables,
  details = list(
    table_types = names(gt_tables)
  )
)

# ==============================================================================
# STAGE 5.9: EXPORT OUTPUTS
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.9: Export Outputs                         │")
message("└─────────────────────────────────────────────────────────────────┘\n")

# Create output directories
assert_directory_exists("results/figures", create = TRUE)
assert_directory_exists("results/tables", create = TRUE)
assert_directory_exists("results/rds", create = TRUE)

# Timestamp for filenames
timestamp <- format(Sys.time(), "%Y%m%d")

files_created <- character()

# ------------------------------------------------------------------------------
# Export GT tables as PNG (if webshot2 available)
# ------------------------------------------------------------------------------

if (has_webshot2) {
  message("Exporting GT tables as PNG...")
  
  for (table_name in names(gt_tables)) {
    png_file <- sprintf("results/figures/%s_%s.png", table_name, timestamp)
    save_gt_table(gt_tables[[table_name]], png_file, format = "png")
    files_created <- c(files_created, png_file)
    message(sprintf("  ✓ %s", basename(png_file)))
  }
  
  # Log PNG exports
  validation_context <- log_validation_event(
    validation_context,
    event_type = "files_exported",
    description = sprintf("Exported %d PNG files", length(gt_tables)),
    count = length(gt_tables),
    details = list(
      export_format = "png",
      files = basename(files_created)
    )
  )
} else {
  message("Skipping PNG export (webshot2 not installed)")
}

# ------------------------------------------------------------------------------
# Export GT tables as HTML (always)
# ------------------------------------------------------------------------------

message("\nExporting GT tables as HTML...")

html_files_start <- length(files_created)

for (table_name in names(gt_tables)) {
  html_file <- sprintf("results/figures/%s_%s.html", table_name, timestamp)
  save_gt_table(gt_tables[[table_name]], html_file, format = "html")
  files_created <- c(files_created, html_file)
  message(sprintf("  ✓ %s", basename(html_file)))
}

n_html_files <- length(files_created) - html_files_start

# Log HTML exports
validation_context <- log_validation_event(
  validation_context,
  event_type = "files_exported",
  description = sprintf("Exported %d HTML files", n_html_files),
  count = n_html_files,
  details = list(
    export_format = "html"
  )
)

# ------------------------------------------------------------------------------
# Export Excel workbook (if openxlsx available)
# ------------------------------------------------------------------------------

if (has_openxlsx) {
  message("\nExporting Excel workbook...")
  
  xlsx_file <- sprintf("results/tables/summary_statistics_%s.xlsx", timestamp)
  
  wb <- openxlsx::createWorkbook()
  
  # Add sheets
  openxlsx::addWorksheet(wb, "Detector Summary")
  openxlsx::writeData(wb, "Detector Summary", detector_summary)
  
  openxlsx::addWorksheet(wb, "Study Summary")
  openxlsx::writeData(wb, "Study Summary", as.data.frame(study_summary))
  
  if (!is.null(species_summary)) {
    openxlsx::addWorksheet(wb, "Species by Detector")
    openxlsx::writeData(wb, "Species by Detector", species_summary)
  }
  
  if (!is.null(hourly_summary_overall)) {
    openxlsx::addWorksheet(wb, "Hourly Profile")
    openxlsx::writeData(wb, "Hourly Profile", hourly_summary_overall)
  }
  
  openxlsx::saveWorkbook(wb, xlsx_file, overwrite = TRUE)
  files_created <- c(files_created, xlsx_file)
  message(sprintf("  ✓ %s", basename(xlsx_file)))
  
  # Log Excel export
  validation_context <- log_validation_event(
    validation_context,
    event_type = "files_exported",
    description = "Exported Excel workbook",
    details = list(
      export_format = "xlsx",
      n_sheets = length(wb$sheet_names),
      file = basename(xlsx_file)
    )
  )
  
} else {
  message("Skipping Excel export (openxlsx not installed)")
}

# ------------------------------------------------------------------------------
# Export RDS file (always)
# ------------------------------------------------------------------------------

message("\nExporting RDS file...")

all_summaries <- list(
  detector_summary = detector_summary,
  study_summary = study_summary,
  variance_components = variance_components,
  species_summary = species_summary,
  species_accumulation = species_accumulation,
  hourly_summary_overall = hourly_summary_overall,
  hourly_summary_by_detector = hourly_summary_by_detector,
  metadata = list(
    created = Sys.time(),
    n_detectors = study_summary$n_detectors,
    n_detector_nights = study_summary$n_detector_nights,
    total_calls = study_summary$total_calls
  )
)

rds_file <- sprintf("results/rds/summary_data_%s.rds", timestamp)
saveRDS(all_summaries, rds_file)
files_created <- c(files_created, rds_file)
message(sprintf("  ✓ %s", basename(rds_file)))

message(sprintf("\n✓ Exported %d files", length(files_created)))

log_message(sprintf("[Stage 5.9] Exported %d files", length(files_created)))

# Log RDS export
validation_context <- log_validation_event(
  validation_context,
  event_type = "files_exported",
  description = "Exported RDS file with all summaries",
  details = list(
    export_format = "rds",
    file = basename(rds_file),
    summaries_included = names(all_summaries)
  )
)

# -------------------------
# Register artifact
# -------------------------

message("\nRegistering artifact...")

# Initialize artifact registry
registry <- init_artifact_registry()

# Register summary stats RDS
registry <- register_artifact(
  registry = registry,
  artifact_name = sprintf("summary_stats_%s", timestamp),
  artifact_type = "summary_stats",
  workflow = "05",
  file_path = rds_file,
  input_artifacts = c("cpn_final", "kpro_master"),
  metadata = list(
    n_detectors = study_summary$n_detectors,
    n_detector_nights = study_summary$n_detector_nights,
    total_calls = study_summary$total_calls,
    total_hours = round(study_summary$total_hours, 1),
    gt_tables_created = length(gt_tables),
    files_exported = length(files_created),
    has_species_summary = !is.null(species_summary),
    has_hourly_summary = !is.null(hourly_summary_overall)
  )
)

message("✓ Artifact registered in registry")

# ==============================================================================
# FINALIZE VALIDATION REPORT
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│          Generating Validation Report                          │")
message("└─────────────────────────────────────────────────────────────────┘\n")

# Finalize validation context
validation_context$summary$rows_processed <- length(files_created)

validation_report_path <- finalize_validation_report(
  validation_context,
  output_dir = here::here("results", "validation")
)

log_message(sprintf("[Workflow 05] Validation report: %s", basename(validation_report_path)))

# ==============================================================================
# STAGE 5.10: SUMMARY REPORT
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.10: Summary Report                        │")
message("└─────────────────────────────────────────────────────────────────┘\n")

message("╔═══════════════════════════════════════════════════════════════╗")
message("║                    STUDY SUMMARY                               ║")
message("╚═══════════════════════════════════════════════════════════════╝")

message("\n📊 STUDY OVERVIEW")
message(sprintf("   Detectors: %d", study_summary$n_detectors))
message(sprintf("   Study period: %s to %s", 
                min(calls_per_night_final$Night), 
                max(calls_per_night_final$Night)))
message(sprintf("   Detector-nights: %s", format(study_summary$n_detector_nights, big.mark = ",")))
message(sprintf("   Recording hours: %.1f", study_summary$total_hours))

message("\n🦇 ACTIVITY METRICS")
message(sprintf("   Total calls: %s", format(study_summary$total_calls, big.mark = ",")))
message(sprintf("   Mean calls/hour: %.2f", study_summary$overall_mean_cph))
message(sprintf("   Median calls/hour: %.2f", study_summary$overall_median_cph))
message(sprintf("   SD calls/hour: %.2f", study_summary$overall_sd_cph))
message(sprintf("   CV: %.1f%%", study_summary$overall_cv_pct))  

message("\n📈 VARIANCE DECOMPOSITION")
message(sprintf("   Between-detector: %.1f%%", variance_components$pct_between))
message(sprintf("   Within-detector: %.1f%%", variance_components$pct_within))

if (!is.null(species_summary)) {
  n_species <- n_distinct(species_summary$species)
  message("\n🔬 SPECIES")
  message(sprintf("   Species detected: %d", n_species))
}

if (!is.null(hourly_summary_overall)) {
  peak <- hourly_summary_overall %>% slice_max(n_calls, n = 1)
  message("\n⏰ TEMPORAL PATTERNS")
  message(sprintf("   Peak activity hour: %02d:00", peak$Hour_local))
}

message("\n✅ RECORDING STATUS")
message(sprintf("   Success: %.1f%%", study_summary$pct_success))
message(sprintf("   Partial: %.1f%%", study_summary$pct_partial))
message(sprintf("   Fail: %.1f%%", study_summary$pct_fail))

message("\n📁 FILES CREATED")
for (f in files_created) {
  message(sprintf("   • %s", f))
}

# ==============================================================================
# WORKFLOW 05 COMPLETE
# ==============================================================================

message("\n╔═══════════════════════════════════════════════════════════════╗")
message("║          WORKFLOW 05 COMPLETE: Summary Statistics Generated    ║")
message("╚═══════════════════════════════════════════════════════════════╝")

message("\n========================================")
message("✓ Workflow 05 Complete")
message("========================================")

message("\nData in environment:")
message("  • detector_summary")
message("  • study_summary")
message("  • variance_components")
if (!is.null(species_summary)) message("  • species_summary")
if (!is.null(species_accumulation)) message("  • species_accumulation")
if (!is.null(hourly_summary_overall)) message("  • hourly_summary_overall")
if (!is.null(hourly_summary_by_detector)) message("  • hourly_summary_by_detector")
message("  • gt_tables (list)")
message("  • all_summaries (master list)")
message(sprintf("  • Validation report: %s", basename(validation_report_path)))

message("\nTo access GT tables:")
message("  gt_tables$detector_summary")
message("  gt_tables$study_summary")

message("\nTo access all summaries:")
message("  all_summaries <- readRDS('results/rds/summary_data_", timestamp, ".rds')")

message("\nNext steps:")
message("  - Review generated tables in results/figures/")
message("  - Use summaries for reporting")
message("  - Generate custom visualizations\n")

log_message("=== WORKFLOW 05 COMPLETE ===")
