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
#
# R Packages (optional):
#   - webshot2 (for PNG export)
#   - openxlsx (for Excel export)
#
# Custom Functions (via load_all.R):
#   - core/utilities.R: log_message, load_cpn_final, load_master_data
#   - validation/validation.R: validate_cpn_data, validate_master_data,
#                              assert_directory_exists
#   - analysis/summarization.R: create_detector_activity_summary,
#                               create_study_summary, calculate_variance_components,
#                               create_species_summary_by_detector,
#                               create_species_accumulation_summary,
#                               create_hourly_activity_summary
#   - output/tables.R: format_detector_summary_gt, format_study_summary_gt,
#                      format_species_summary_gt, format_hourly_summary_gt,
#                      save_gt_table
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
# 2024-12-29: Initial version following CODING_STANDARDS
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

message(sprintf("✓ CallsPerNight final loaded: %s rows, %d detectors",
                format(nrow(calls_per_night_final), big.mark = ","),
                n_distinct(calls_per_night_final$Detector)))

# ------------------------------------------------------------------------------
# Load Master File
# ------------------------------------------------------------------------------

message("\nLoading Master file...")

kpro_master <- load_master_data()

validate_master_data(kpro_master)

message(sprintf("✓ Master file loaded: %s rows",
                format(nrow(kpro_master), big.mark = ",")))

# Check for Hour or DateTime (needed for hourly analysis)
has_hour <- "Hour" %in% names(kpro_master)
has_datetime <- "DateTime" %in% names(kpro_master)

if (!has_hour && !has_datetime) {
  warning("Master file has no Hour or DateTime column - hourly analysis will be skipped")
}

log_message(sprintf("[Stage 5.1] Loaded data: CPN=%d rows, Master=%d rows",
                    nrow(calls_per_night_final), nrow(kpro_master)))

# ==============================================================================
# STAGE 5.2: DETECTOR ACTIVITY SUMMARY
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.2: Detector Activity Summary              │")
message("└─────────────────────────────────────────────────────────────────┘\n")

message("Creating detector activity summary...")

detector_summary <- create_detector_activity_summary(calls_per_night_final)

message(sprintf("✓ Detector summary created: %d detectors", nrow(detector_summary)))

# Preview
message("\nDetector summary preview (top 5 by total calls):")
preview <- detector_summary %>%
  arrange(desc(total_calls)) %>%
  head(5) %>%
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

log_message(sprintf("[Stage 5.2] Created detector summary: %d detectors", nrow(detector_summary)))

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
message(sprintf("  Mean calls per hour: %.2f", study_summary$mean_cph))
message(sprintf("  Success rate: %.1f%%", study_summary$pct_success))

log_message("[Stage 5.3] Created study summary")

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

# ==============================================================================
# STAGE 5.5: SPECIES COMPOSITION
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.5: Species Composition                    │")
message("└─────────────────────────────────────────────────────────────────┘\n")

if ("auto_id" %in% names(kpro_master)) {
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
  
} else {
  warning("auto_id column not found - skipping species summary")
  species_summary <- NULL
  log_message("[Stage 5.5] Skipped species summary (no auto_id column)")
}

# ==============================================================================
# STAGE 5.6: SPECIES ACCUMULATION
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 5.6: Species Accumulation                   │")
message("└─────────────────────────────────────────────────────────────────┘\n")

if ("auto_id" %in% names(kpro_master) && "Night" %in% names(kpro_master)) {
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
    filter(!is.na(new_species_list) & new_species_list != "") %>%  # ✅ Use new_species_list
    head(5)
  
  for (i in seq_len(nrow(first_detections))) {
    message(sprintf("  %s: %s (cumulative: %d)", 
                    first_detections$Night[i],            # ✅ Now works with Night column
                    first_detections$new_species_list[i], # ✅ Show species names
                    first_detections$cumulative_species[i]))
  }
  
  log_message(sprintf("[Stage 5.6] Created species accumulation: %d total species", final_richness))
  
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
      mutate(Hour = lubridate::hour(DateTime))
  }
  
  # Study-wide hourly profile
  hourly_summary_overall <- create_hourly_activity_summary(kpro_master, by_detector = FALSE)
  
  # Per-detector hourly profile
  hourly_summary_by_detector <- create_hourly_activity_summary(kpro_master, by_detector = TRUE)
  
  # Find peak hour
  peak_hour <- hourly_summary_overall %>%
    slice_max(n_calls, n = 1)  # ✅ Changed from total_calls to n_calls
  
  message(sprintf("✓ Hourly profiles created"))
  message(sprintf("  Peak hour: %02d:00 (%s calls, %.1f%% of total)",
                  peak_hour$Hour,
                  format(peak_hour$n_calls, big.mark = ","),      # ✅ Changed from total_calls
                  peak_hour$pct_of_total))                        # ✅ Changed from pct_total
  
  log_message("[Stage 5.7] Created hourly activity profiles")
  
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

message(sprintf("\n✓ Created %d GT tables", length(gt_tables)))

log_message(sprintf("[Stage 5.8] Created %d GT tables", length(gt_tables)))

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
} else {
  message("Skipping PNG export (webshot2 not installed)")
}

# ------------------------------------------------------------------------------
# Export GT tables as HTML (always)
# ------------------------------------------------------------------------------

message("\nExporting GT tables as HTML...")

for (table_name in names(gt_tables)) {
  html_file <- sprintf("results/figures/%s_%s.html", table_name, timestamp)
  save_gt_table(gt_tables[[table_name]], html_file, format = "html")
  files_created <- c(files_created, html_file)
  message(sprintf("  ✓ %s", basename(html_file)))
}

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
message(sprintf("   Mean calls/hour: %.2f", study_summary$overall_mean_cph))      # ✅ Fixed
message(sprintf("   Median calls/hour: %.2f", study_summary$overall_median_cph))  # ✅ Fixed
message(sprintf("   SD calls/hour: %.2f", study_summary$overall_sd_cph))          # ✅ Added
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
  peak <- hourly_summary_overall %>% slice_max(n_calls, n = 1)  # ✅ Changed from total_calls
  message("\n⏰ TEMPORAL PATTERNS")
  message(sprintf("   Peak activity hour: %02d:00", peak$Hour))
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