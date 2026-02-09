# ==============================================================================
# MAINLINE WORKFLOW: 06_generate_plots.R
# ==============================================================================
# PURPOSE
# -------
# Generate comprehensive exploratory visualizations for bat acoustic data.
# Creates quality, detector, species, and temporal plots for data inspection,
# Quarto report integration, and standalone publication use.
#
# This workflow is VISUALIZATION ONLY - no statistical analysis or inference.
# All outputs are meant for data exploration, quality assessment, and reporting.
#
# WORKFLOW POSITION
# -----------------
# This is Workflow 06 in the processing pipeline:
#   01_ingest_raw_data.R  → Load & intro-standardize raw CSVs
#   02_standardize.R      → Transform to master schema
#   [OPTIONAL: Manual ID in Kaleidoscope]
#   03_generate_cpn_template.R → Generate template for editing
#   [USER: Edit template in Excel]
#   04_finalize_cpn.R     → Process edited template
#   05_summary_stats.R    → Generate summary statistics
#   06_generate_plots.R   → [THIS SCRIPT] Generate exploratory plots
#   07_generate_report_and_release.R → Create final report and release bundle
#
# INPUTS
# ------
# In Memory (preferred):
#   - calls_per_night_final (from Workflow 04)
#   - kpro_master (from Workflow 02/03, with unified `species` column)
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
# Stage 6.1: Load Data
#   - Loads CallsPerNight_final (from memory or checkpoint)
#   - Loads Master file (from memory or checkpoint)
#   - Validates required columns
#   - Checks for species column (created in Workflow 03)
#   - Checks for temporal columns (Hour_local, DateTime_local)
#
# Stage 6.2: Configuration
#   - Sets export options (PNG, SVG)
#   - Creates output directory structure
#   - Initializes plot storage list
#
# Stage 6.3: Data Quality Plots (8 plots)
#   - Recording status visualizations (3)
#   - Effort summaries by detector (2)
#   - Data completeness assessments (3)
#
# Stage 6.4: Detector Activity Plots (7 plots)
#   - Total calls by detector
#   - Activity distributions and comparisons
#   - Correlation and synchrony analyses
#
# Stage 6.5: Species Composition Plots (5 plots, conditional)
#   - Species composition and diversity
#   - Detector × species matrices
#   - NoID proportion analysis
#   - Requires unified `species` column from Workflow 03
#
# Stage 6.6: Temporal Pattern Plots (6 plots)
#   - Activity over time trends
#   - Hourly, weekly, and monthly patterns
#   - Distribution analysis
#
# Stage 6.7: Export Plots
#   - PNG export (300 DPI, publication quality)
#   - SVG export (optional, for vector editing)
#   - RDS export (ggplot objects for Quarto reuse)
#
# Stage 6.8: Summary Report
#   - Console output with plot inventory
#   - Lists all outputs created
#   - Usage instructions for Quarto integration
#
# OUTPUTS
# -------
# Files Created:
#   - results/figures/png/quality/*.png (8 plots)
#   - results/figures/png/detector/*.png (7 plots)
#   - results/figures/png/species/*.png (5 plots, conditional)
#   - results/figures/png/temporal/*.png (6 plots)
#   - results/figures/svg/*/*.svg (optional, if export_svg = TRUE)
#   - results/rds/plot_objects_YYYYMMDD.rds (all plots as list)
#   - logs/workflow_log_YYYYMMDD.txt (processing log)
#   - results/validation/validation_06_YYYYMMDD_HHMMSS.yaml (validation log)
#   - results/validation/validation_06_YYYYMMDD_HHMMSS.html (validation report)
#
# In Memory:
#   - all_plots (nested list of ggplot objects)
#     - all_plots$quality (8 plots)
#     - all_plots$detector (7 plots)
#     - all_plots$species (5 plots, if available)
#     - all_plots$temporal (6 plots)
#
# Registry:
#   - inst/config/artifact_registry.yaml (updated with plot_objects RDS)
#
# PLOT INVENTORY
# --------------
# Quality (8):
#   - plot_recording_status_summary
#   - plot_recording_status_percent
#   - plot_recording_status_overall
#   - plot_effort_by_detector
#   - plot_nights_by_detector
#   - plot_data_completeness_calendar
#   - plot_missing_nights
#   - plot_recording_effort_heatmap
#
# Detector (7):
#   - plot_total_calls_by_detector
#   - plot_detector_activity_caterpillar
#   - plot_detector_boxplots
#   - plot_activity_with_without_outliers
#   - plot_synchrony
#   - plot_correlation_heatmap
#   - plot_detector_rank_over_time
#
# Species (5, conditional on `species` column):
#   - plot_species_composition_bar
#   - plot_species_by_detector_heatmap
#   - plot_species_accumulation_curve
#   - plot_species_hourly_profile (conditional on Hour_local)
#   - plot_noid_proportion
#
# Temporal (6):
#   - plot_activity_over_time
#   - plot_cumulative_calls_over_time
#   - plot_hourly_activity_profile (conditional on Hour_local)
#   - plot_callsperhour_distribution
#   - plot_weekly_activity
#   - plot_activity_by_month
#
# VALIDATION TRACKING
# -------------------
# This workflow tracks the following validation events:
#   - data_loaded: CallsPerNight final loaded
#   - data_loaded: Master file loaded
#   - plots_generated: Quality plots created
#   - plots_generated: Detector plots created
#   - plots_generated: Species plots created (if available)
#   - plots_generated: Temporal plots created
#   - files_exported: PNG exports
#   - files_exported: SVG exports (if enabled)
#   - files_exported: RDS file saved
#
# PERFORMANCE EXPECTATIONS
# -------------------------
# Typical bat acoustic datasets:
#
# Small study (3 detectors, 30 nights):
#   - Processing: < 1 minute
#
# Medium study (10 detectors, 90 nights):
#   - Processing: 1-2 minutes
#
# Large study (20+ detectors, 180 nights):
#   - Processing: 2-5 minutes
#
# Note: Some complex plots (heatmaps, correlation matrices) may take longer
#
# DEPENDENCIES
# ------------
# R Packages (required):
#   - tidyverse (ggplot2, dplyr, readr, tidyr, purrr, lubridate)
#   - here (path management)
#
# R Packages (optional):
#   - svglite (for SVG export)
#
# Custom Functions (via load_all.R):
#   - core/utilities.R: log_message, load_cpn_final, load_master_data
#   - core/artifacts.R: create_validation_context, log_validation_event,
#                       finalize_validation_report, init_artifact_registry,
#                       register_artifact
#   - validation/validation.R: validate_cpn_data, validate_master_data,
#                              assert_directory_exists, require_study_parameters
#   - output/plot_helpers.R: theme_kpro, validate_plot_input, kpro_palette_*
#   - output/plot_quality.R: plot_recording_status_*, plot_effort_*,
#                            plot_data_completeness_*, plot_missing_*,
#                            plot_recording_effort_heatmap
#   - output/plot_detector.R: plot_total_calls_by_detector, plot_detector_*,
#                             plot_synchrony, plot_correlation_heatmap
#   - output/plot_species.R: plot_species_*, plot_noid_proportion
#   - output/plot_temporal.R: plot_activity_*, plot_cumulative_*,
#                             plot_hourly_*, plot_weekly_*
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
# Issue: "Species plots skipped"
# Fix: Run Workflow 03 with species column unification enabled
#
# Issue: "SVG export failed"
# Fix: Install svglite package: install.packages("svglite")
#
# Issue: "Hourly plots skipped"
# Fix: Ensure master file has Hour_local or DateTime_local column from Workflow 02
#
# USAGE EXAMPLES
# --------------
# # Run after Workflow 05:
# source("R/workflows/06_generate_plots.R")
#
# # Inspect results:
# names(all_plots)
# all_plots$quality$recording_status_summary
#
# # Customize a plot:
# all_plots$detector$correlation_heatmap +
#   ggplot2::labs(title = "My Custom Title")
#
# # Use in Quarto:
# all_plots <- readRDS("results/rds/plot_objects_20250107.rds")
#
# MAINTAINER NOTES
# ----------------
# - ASCII boxes: Single-line (┌─┐) for all stages
# - Stage numbering: 6.1 - 6.8
# - All plots are ggplot2 objects (can be modified after creation)
# - Plots organized by category in subdirectories
# - RDS output always created for programmatic access
# - Species plots require unified `species` column (Workflow 03)
# - Temporal plots degrade gracefully if Hour_local/DateTime_local missing
# - Total plots: 26 (8 quality + 7 detector + 5 species + 6 temporal)
#
# CHANGELOG
# ---------
# 2026-01-12: Enhanced validation tracking for all plot generation stages
# 2026-01-12: Added artifact registration for plot_objects RDS (v2.1)
# 2026-01-09: Updated to use Hour_local/DateTime_local from standardization
# 2025-01-07: Initial version following CODING_STANDARDS
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

# Check for optional packages
has_svglite <- requireNamespace("svglite", quietly = TRUE)

# ==============================================================================
# USER-CONFIGURABLE OPTIONS
# ==============================================================================
# Modify these settings before running if needed

export_svg <- FALSE       # Set TRUE for vector format (requires svglite)
png_width <- 10           # Width in inches
png_height <- 6           # Height in inches
png_dpi <- 300            # Resolution (300 = publication quality)

# ==============================================================================

if (export_svg && !has_svglite) {
  message("Note: svglite not installed - SVG export will be skipped")
  message("      Install with: install.packages('svglite')")
  export_svg <- FALSE
}

# ------------------------------------------------------------------------------
# Initialize logging
# ------------------------------------------------------------------------------

log_message("=== WORKFLOW 06: Generate Plots ===")

# ------------------------------------------------------------------------------
# Initialize validation context
# ------------------------------------------------------------------------------

validation_context <- create_validation_context(
  workflow = "06",
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
# STAGE 6.1: LOAD DATA
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 6.1: Load Data                              │")
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

log_message(sprintf("[Stage 6.1] Loaded CallsPerNight: %d rows, %d detectors", 
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

log_message(sprintf("[Stage 6.1] Loaded Master: %d rows", n_master_rows))

# ------------------------------------------------------------------------------
# Check for optional columns
# ------------------------------------------------------------------------------

# Species column (created in Workflow 03 unification)
has_species <- "species" %in% names(kpro_master)

if (!has_species) {
  message("\n⚠️  'species' column not found in master file")
  message("  Species plots will be skipped")
  message("  To enable: Run Workflow 03 with species column unification")
}

# Temporal columns (check for standardized names from Workflow 02)
has_hour_local <- "Hour_local" %in% names(kpro_master)
has_datetime_local <- "DateTime_local" %in% names(kpro_master)

# Create Hour_local from DateTime_local if needed
if (!has_hour_local && has_datetime_local) {
  message("\nCreating Hour_local column from DateTime_local...")
  kpro_master <- kpro_master %>%
    mutate(Hour_local = lubridate::hour(DateTime_local))
  has_hour_local <- TRUE
  message("✓ Hour_local column created")
}

if (!has_hour_local && !has_datetime_local) {
  message("\n⚠️  No Hour_local or DateTime_local column found")
  message("  Hourly activity plots will be skipped")
  message("  These columns are created by Workflow 02 standardization")
}

# Check for Date_local (used by some plots)
has_date_local <- "Date_local" %in% names(kpro_master)

if (!has_date_local && has_datetime_local) {
  message("\nCreating Date_local column from DateTime_local...")
  kpro_master <- kpro_master %>%
    mutate(Date_local = lubridate::as_date(DateTime_local))
  has_date_local <- TRUE
  message("✓ Date_local column created")
}

# Log Master file loading
validation_context <- log_validation_event(
  validation_context,
  event_type = "data_loaded",
  description = sprintf("Loaded Master file: %s rows", format(n_master_rows, big.mark = ",")),
  count = n_master_rows,
  details = list(
    has_hour_column = has_hour_local,
    has_datetime_column = has_datetime_local,
    has_species_column = has_species,
    data_validated = TRUE
  )
)

# ==============================================================================
# STAGE 6.2: CONFIGURATION
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 6.2: Configuration                          │")
message("└─────────────────────────────────────────────────────────────────┘\n")

# Timestamp for filenames
timestamp <- format(Sys.Date(), "%Y%m%d")

message(sprintf("Timestamp for outputs: %s", timestamp))
message(sprintf("PNG dimensions: %d × %d inches at %d DPI", png_width, png_height, png_dpi))
message(sprintf("SVG export: %s", ifelse(export_svg, "Enabled", "Disabled")))

# Initialize plot storage
all_plots <- list()

# Create output directories
output_dirs <- c(
  "results/figures/png/quality",
  "results/figures/png/detector",
  "results/figures/png/species",
  "results/figures/png/temporal",
  "results/rds"
)

if (export_svg) {
  output_dirs <- c(output_dirs,
                   "results/figures/svg/quality",
                   "results/figures/svg/detector",
                   "results/figures/svg/species",
                   "results/figures/svg/temporal"
  )
}

message("\nCreating output directories...")

for (dir in output_dirs) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
    message(sprintf("  Created: %s", dir))
  }
}

message("✓ Output directories ready")

log_message(sprintf("[Stage 6.2] Configuration set: timestamp=%s, svg=%s", timestamp, export_svg))

# ==============================================================================
# STAGE 6.3: DATA QUALITY PLOTS
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 6.3: Data Quality Plots                     │")
message("└─────────────────────────────────────────────────────────────────┘\n")

quality_plots <- list()

# 6.3.1 Recording Status Summary (stacked bar)
message("  Creating recording_status_summary...")
quality_plots$recording_status_summary <- 
  plot_recording_status_summary(calls_per_night_final)

# 6.3.2 Recording Status Percent (100% stacked)
message("  Creating recording_status_percent...")
quality_plots$recording_status_percent <- 
  plot_recording_status_percent(calls_per_night_final)

# 6.3.3 Recording Status Overall (donut)
message("  Creating recording_status_overall...")
quality_plots$recording_status_overall <- 
  plot_recording_status_overall(calls_per_night_final)

# 6.3.4 Effort by Detector
message("  Creating effort_by_detector...")
quality_plots$effort_by_detector <- 
  plot_effort_by_detector(calls_per_night_final)

# 6.3.5 Nights by Detector
message("  Creating nights_by_detector...")
quality_plots$nights_by_detector <- 
  plot_nights_by_detector(calls_per_night_final)

# 6.3.6 Data Completeness Calendar
message("  Creating data_completeness_calendar...")
quality_plots$data_completeness_calendar <- 
  plot_data_completeness_calendar(calls_per_night_final)

# 6.3.7 Missing Nights
message("  Creating missing_nights...")
quality_plots$missing_nights <- 
  plot_missing_nights(calls_per_night_final)

# 6.3.8 Recording Effort Heatmap
message("  Creating recording_effort_heatmap...")
quality_plots$recording_effort_heatmap <- 
  plot_recording_effort_heatmap(calls_per_night_final)

n_quality_plots <- length(quality_plots)

message(sprintf("\n✓ Created %d quality plots", n_quality_plots))
all_plots$quality <- quality_plots

log_message(sprintf("[Stage 6.3] Created %d quality plots", n_quality_plots))

# Log quality plots generation
validation_context <- log_validation_event(
  validation_context,
  event_type = "plots_generated",
  description = sprintf("Created %d quality plots", n_quality_plots),
  count = n_quality_plots,
  details = list(
    plot_category = "quality",
    plot_types = names(quality_plots)
  )
)

# ==============================================================================
# STAGE 6.4: DETECTOR ACTIVITY PLOTS
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 6.4: Detector Activity Plots                │")
message("└─────────────────────────────────────────────────────────────────┘\n")

detector_plots <- list()

# 6.4.1 Total Calls by Detector (from master)
message("  Creating total_calls_by_detector...")
detector_plots$total_calls_by_detector <- 
  plot_total_calls_by_detector(kpro_master)

# 6.4.2 Detector Activity Caterpillar
message("  Creating detector_activity_caterpillar...")
detector_plots$detector_activity_caterpillar <- 
  plot_detector_activity_caterpillar(calls_per_night_final)

# 6.4.3 Detector Boxplots
message("  Creating detector_boxplots...")
detector_plots$detector_boxplots <- 
  plot_detector_boxplots(calls_per_night_final)

# 6.4.4 Activity With/Without Outliers
message("  Creating activity_with_without_outliers...")
detector_plots$activity_with_without_outliers <- 
  plot_activity_with_without_outliers(calls_per_night_final)

# 6.4.5 Synchrony Plot
message("  Creating synchrony...")
detector_plots$synchrony <- 
  plot_synchrony(calls_per_night_final)

# 6.4.6 Correlation Heatmap
message("  Creating correlation_heatmap...")
detector_plots$correlation_heatmap <- 
  plot_correlation_heatmap(calls_per_night_final)

# 6.4.7 Detector Rank Over Time
message("  Creating detector_rank_over_time...")
detector_plots$detector_rank_over_time <- 
  plot_detector_rank_over_time(calls_per_night_final)

n_detector_plots <- length(detector_plots)

message(sprintf("\n✓ Created %d detector plots", n_detector_plots))
all_plots$detector <- detector_plots

log_message(sprintf("[Stage 6.4] Created %d detector plots", n_detector_plots))

# Log detector plots generation
validation_context <- log_validation_event(
  validation_context,
  event_type = "plots_generated",
  description = sprintf("Created %d detector plots", n_detector_plots),
  count = n_detector_plots,
  details = list(
    plot_category = "detector",
    plot_types = names(detector_plots)
  )
)

# ==============================================================================
# STAGE 6.5: SPECIES COMPOSITION PLOTS
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 6.5: Species Composition Plots              │")
message("└─────────────────────────────────────────────────────────────────┘\n")

species_plots <- list()

if (has_species) {
  
  # 6.5.1 Species Composition Bar
  message("  Creating species_composition_bar...")
  species_plots$species_composition_bar <- 
    plot_species_composition_bar(kpro_master)
  
  # 6.5.2 Species by Detector Heatmap
  message("  Creating species_by_detector_heatmap...")
  species_plots$species_by_detector_heatmap <- 
    plot_species_by_detector_heatmap(kpro_master)
  
  # 6.5.3 Species Accumulation Curve
  message("  Creating species_accumulation_curve...")
  species_plots$species_accumulation_curve <- 
    plot_species_accumulation_curve(kpro_master)
  
  # 6.5.4 Species Hourly Profile (conditional on Hour_local)
  if (has_hour_local) {
    message("  Creating species_hourly_profile...")
    species_plots$species_hourly_profile <- 
      plot_species_hourly_profile(kpro_master)
  } else {
    message("  ⚠️  Skipping species_hourly_profile (no Hour_local column)")
  }
  
  # 6.5.5 NoID Proportion
  message("  Creating noid_proportion...")
  species_plots$noid_proportion <- 
    plot_noid_proportion(kpro_master)
  
  n_species_plots <- length(species_plots)
  
  message(sprintf("\n✓ Created %d species plots", n_species_plots))
  
  # Log species plots generation
  validation_context <- log_validation_event(
    validation_context,
    event_type = "plots_generated",
    description = sprintf("Created %d species plots", n_species_plots),
    count = n_species_plots,
    details = list(
      plot_category = "species",
      plot_types = names(species_plots)
    )
  )
  
} else {
  message("⚠️  Skipping all species plots (no 'species' column)")
  message("  To enable: Run Workflow 03 with species column unification")
}

all_plots$species <- species_plots

log_message(sprintf("[Stage 6.5] Created %d species plots (has_species=%s)", 
                    length(species_plots), has_species))

# ==============================================================================
# STAGE 6.6: TEMPORAL PATTERN PLOTS
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 6.6: Temporal Pattern Plots                 │")
message("└─────────────────────────────────────────────────────────────────┘\n")

temporal_plots <- list()

# 6.6.1 Activity Over Time
message("  Creating activity_over_time...")
temporal_plots$activity_over_time <- 
  plot_activity_over_time(calls_per_night_final)

# 6.6.2 Cumulative Calls Over Time
message("  Creating cumulative_calls_over_time...")
temporal_plots$cumulative_calls_over_time <- 
  plot_cumulative_calls_over_time(calls_per_night_final)

# 6.6.3 Hourly Activity Profile (from master, conditional on Hour_local)
if (has_hour_local) {
  message("  Creating hourly_activity_profile...")
  temporal_plots$hourly_activity_profile <- 
    plot_hourly_activity_profile(kpro_master)
} else {
  message("  ⚠️  Skipping hourly_activity_profile (no Hour_local column)")
}

# 6.6.4 CallsPerHour Distribution
message("  Creating callsperhour_distribution...")
temporal_plots$callsperhour_distribution <- 
  plot_callsperhour_distribution(calls_per_night_final)

# 6.6.5 Weekly Activity
message("  Creating weekly_activity...")
temporal_plots$weekly_activity <- 
  plot_weekly_activity(calls_per_night_final)

# 6.6.6 Monthly Activity
message("  Creating activity_by_month...")
temporal_plots$activity_by_month <- 
  plot_activity_by_month(calls_per_night_final)

n_temporal_plots <- length(temporal_plots)

message(sprintf("\n✓ Created %d temporal plots", n_temporal_plots))
all_plots$temporal <- temporal_plots

log_message(sprintf("[Stage 6.6] Created %d temporal plots", n_temporal_plots))

# Log temporal plots generation
validation_context <- log_validation_event(
  validation_context,
  event_type = "plots_generated",
  description = sprintf("Created %d temporal plots", n_temporal_plots),
  count = n_temporal_plots,
  details = list(
    plot_category = "temporal",
    plot_types = names(temporal_plots)
  )
)

# ==============================================================================
# STAGE 6.7: EXPORT PLOTS
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 6.7: Export Plots                           │")
message("└─────────────────────────────────────────────────────────────────┘\n")

files_created <- character()

# ------------------------------------------------------------------------------
# Helper function for saving plots
# ------------------------------------------------------------------------------

save_plot_to_disk <- function(plot_obj, plot_name, category, timestamp,
                              width = png_width, height = png_height, 
                              dpi = png_dpi, export_svg = FALSE) {
  
  paths_created <- character()
  
  # PNG export
  png_path <- file.path("results/figures/png", category, 
                        sprintf("%s_%s.png", plot_name, timestamp))
  
  ggsave(png_path, plot_obj, width = width, height = height, dpi = dpi,
         bg = "white")
  
  paths_created <- c(paths_created, png_path)
  
  # SVG export (optional)
  if (export_svg) {
    svg_path <- file.path("results/figures/svg", category,
                          sprintf("%s_%s.svg", plot_name, timestamp))
    
    ggsave(svg_path, plot_obj, width = width, height = height,
           device = svglite::svglite)
    
    paths_created <- c(paths_created, svg_path)
  }
  
  paths_created
}

# ------------------------------------------------------------------------------
# Export by category
# ------------------------------------------------------------------------------

for (category in names(all_plots)) {
  
  plots_in_category <- all_plots[[category]]
  
  if (length(plots_in_category) == 0) {
    message(sprintf("\nSkipping %s (no plots created)", category))
    next
  }
  
  message(sprintf("\nExporting %s plots (%d)...", category, length(plots_in_category)))
  
  for (plot_name in names(plots_in_category)) {
    plot_obj <- plots_in_category[[plot_name]]
    
    new_files <- save_plot_to_disk(
      plot_obj = plot_obj,
      plot_name = plot_name,
      category = category,
      timestamp = timestamp,
      export_svg = export_svg
    )
    
    files_created <- c(files_created, new_files)
    message(sprintf("  ✓ %s", plot_name))
  }
}

# Count PNG files
n_png_files <- sum(grepl("\\.png$", files_created))

# Log PNG exports
validation_context <- log_validation_event(
  validation_context,
  event_type = "files_exported",
  description = sprintf("Exported %d PNG files", n_png_files),
  count = n_png_files,
  details = list(
    export_format = "png",
    resolution = sprintf("%dx%d @ %d DPI", png_width, png_height, png_dpi)
  )
)

# Log SVG exports (if applicable)
if (export_svg) {
  n_svg_files <- sum(grepl("\\.svg$", files_created))
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "files_exported",
    description = sprintf("Exported %d SVG files", n_svg_files),
    count = n_svg_files,
    details = list(
      export_format = "svg"
    )
  )
}

# ------------------------------------------------------------------------------
# Export RDS (all plot objects)
# ------------------------------------------------------------------------------

message("\nExporting plot objects as RDS...")

rds_path <- file.path("results/rds", sprintf("plot_objects_%s.rds", timestamp))
saveRDS(all_plots, rds_path)
files_created <- c(files_created, rds_path)

message(sprintf("  ✓ %s", basename(rds_path)))

message(sprintf("\n✓ Exported %d files total", length(files_created)))

log_message(sprintf("[Stage 6.7] Exported %d files", length(files_created)))

# Log RDS export
validation_context <- log_validation_event(
  validation_context,
  event_type = "files_exported",
  description = "Exported plot objects as RDS",
  details = list(
    export_format = "rds",
    file = basename(rds_path),
    plot_categories = names(all_plots),
    total_plots = sum(sapply(all_plots, length))
  )
)

# -------------------------
# Register artifact
# -------------------------

message("\nRegistering artifact...")

# Initialize artifact registry
registry <- init_artifact_registry()

# Count plots by category
total_plots <- sum(sapply(all_plots, length))

# Register plot_objects RDS
registry <- register_artifact(
  registry = registry,
  artifact_name = sprintf("plot_objects_%s", timestamp),
  artifact_type = "plot_objects",
  workflow = "06",
  file_path = rds_path,
  input_artifacts = c("cpn_final", "kpro_master"),
  metadata = list(
    n_quality_plots = length(all_plots$quality),
    n_detector_plots = length(all_plots$detector),
    n_species_plots = length(all_plots$species),
    n_temporal_plots = length(all_plots$temporal),
    total_plots = total_plots,
    has_species_plots = has_species,
    png_exported = n_png_files,
    svg_exported = if (export_svg) sum(grepl("\\.svg$", files_created)) else 0
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
validation_context$summary$rows_processed <- total_plots

validation_report_path <- finalize_validation_report(
  validation_context,
  output_dir = here::here("results", "validation")
)

log_message(sprintf("[Workflow 06] Validation report: %s", basename(validation_report_path)))

# ==============================================================================
# STAGE 6.8: SUMMARY REPORT
# ==============================================================================

message("\n┌─────────────────────────────────────────────────────────────────┐")
message("│              STAGE 6.8: Summary Report                         │")
message("└─────────────────────────────────────────────────────────────────┘\n")

# Count plots by category
plot_counts <- sapply(all_plots, length)

message("╔═══════════════════════════════════════════════════════════════╗")
message("║                    PLOT GENERATION SUMMARY                    ║")
message("╚═══════════════════════════════════════════════════════════════╝")

message("\n📊 PLOTS CREATED BY CATEGORY")
for (cat in names(plot_counts)) {
  status <- if (plot_counts[cat] == 0) "(skipped)" else ""
  message(sprintf("   %s: %d plots %s", 
                  tools::toTitleCase(cat), 
                  plot_counts[cat],
                  status))
}
message("   ─────────────────────")
message(sprintf("   Total: %d plots", total_plots))

message("\n📁 OUTPUT LOCATIONS")
message("   PNG files: results/figures/png/")
if (export_svg) {
  message("   SVG files: results/figures/svg/")
}
message(sprintf("   RDS file:  %s", rds_path))

message("\n📋 PLOT INVENTORY")

for (category in names(all_plots)) {
  if (length(all_plots[[category]]) > 0) {
    message(sprintf("\n   %s:", toupper(category)))
    for (plot_name in names(all_plots[[category]])) {
      message(sprintf("     • %s", plot_name))
    }
  }
}

# Note any skipped plots
skipped <- character()
if (!has_species) skipped <- c(skipped, "species plots (no 'species' column)")
if (!has_hour_local && !has_datetime_local) {
  skipped <- c(skipped, "hourly plots (no Hour_local/DateTime_local columns)")
}

if (length(skipped) > 0) {
  message("\n⚠️  SKIPPED")
  for (s in skipped) {
    message(sprintf("   • %s", s))
  }
  message("\n   Note: Hour_local and DateTime_local are created by Workflow 02")
  message("         Species column is created by Workflow 03")
}

# ==============================================================================
# WORKFLOW 06 COMPLETE
# ==============================================================================

message("\n╔═══════════════════════════════════════════════════════════════╗")
message("║          WORKFLOW 06 COMPLETE: Plots Generated                ║")
message("╚═══════════════════════════════════════════════════════════════╝")

message("\n========================================")
message("✓ Workflow 06 Complete")
message("========================================")

message("\nData in environment:")
message("  • all_plots (nested list of ggplot objects)")
message(sprintf("  • Validation report: %s", basename(validation_report_path)))

message("\nTo access individual plots:")
message("  all_plots$quality$recording_status_summary")
message("  all_plots$quality$recording_effort_heatmap")
message("  all_plots$detector$correlation_heatmap")
if (has_species) {
  message("  all_plots$species$species_composition_bar")
}
message("  all_plots$temporal$activity_over_time")

message("\nTo customize a plot:")
message("  all_plots$quality$recording_status_summary +")
message("    ggplot2::labs(title = 'My Custom Title')")

message("\nTo load plots in Quarto:")
message(sprintf("  all_plots <- readRDS('%s')", rds_path))

message("\n📁 FILES CREATED")
message(sprintf("   • %d PNG files", n_png_files))
if (export_svg) {
  message(sprintf("  • %d SVG files", sum(grepl("\\.svg$", files_created))))
}
message(sprintf("   • %s", basename(rds_path)))
message(sprintf("   • %s", basename(validation_report_path)))

message("\nNext steps:")
message("  - Review plots in results/figures/png/")
message("  - Use all_plots for custom analysis")
message("  - Run 07_generate_report_and_release.R for final packaging\n")

log_message("=== WORKFLOW 06 COMPLETE ===")