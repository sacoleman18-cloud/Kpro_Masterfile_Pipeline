# ==============================================================================
# WORKFLOW 02: 02_standardize.R
# ==============================================================================
# PURPOSE
# -------
# Transform raw, mixed-schema Kaleidoscope Pro data into a unified master dataset
# with standardized columns, detector mapping, timezone conversions, and complete
# deduplication. This workflow bridges the gap between raw CSVs (which may use
# different Kaleidoscope schema versions) and analysis-ready data with consistent
# structure and semantics.
#
# This is the critical standardization step that ensures all downstream analyses
# work with clean, validated, well-structured data regardless of which Kaleidoscope
# Pro version generated the original files.
#
# WORKFLOW POSITION
# -----------------
# This is Workflow 02 in the processing pipeline:
#   01_ingest_raw_data.R  -> Load & intro-standardize raw CSVs (v1/v2/v3 detection)
#   02_standardize.R      -> [THIS SCRIPT] Transform to master schema
#   03_generate_cpn_template.R -> Generate CallsPerNight template
#   04_finalize_cpn.R     -> Process template & calculate metrics
#   05_summary_stats.R    -> Generate summary statistics and tables
#
# INPUTS
# ------
# In Memory (preferred):
#   - raw_combined (from Workflow 01, intro-standardized data)
#
# OR Checkpoint (fallback):
#   - outputs/checkpoints/01_intro_standardized_YYYYMMDD_HHMMSS.csv
#
# Configuration Files:
#   - inst/config/study_parameters.yaml (detector mappings, timezone)
#
# Optional Files:
#   - data/detector_mapping.csv (legacy support, YAML preferred)
#
# User Input (if needed):
#   - Friendly detector names for any unmapped DetectorIDs
#
# PROCESSING STAGES
# -----------------
# Stage 2.1: Load Data
#   - Checks for raw_combined in memory (from Workflow 01)
#   - Falls back to most recent checkpoint if not in memory
#   - Validates schema_version column exists
#
# Stage 2.2: Configure Detector Mapping
#   - Loads detector_mapping from study_parameters.yaml
#   - Prompts user for friendly names if any "ENTER_NAME_HERE" placeholders exist
#   - Validates no duplicate detector names
#   - Saves updated mappings back to YAML
#
# Stage 2.3: Schema Transformation
#   - Unifies v1, v2, and v3 schemas into single master format
#   - Handles schema-specific quirks (e.g., v3 manual_id column)
#   - Standardizes column names and data types
#   - Uses standardize_kpro_schema() function
#
# Stage 2.4: Apply Detector Mapping
#   - Joins detector_mapping to unified_data via detector_id
#   - Adds Detector (friendly name) column to dataset
#   - Validates all detectors were successfully mapped
#   - Reports mapping summary with call counts per detector
#
# Stage 2.5: Time Conversions
#   - Loads user's timezone from study_parameters.yaml
#   - Converts UTC timestamps to user's local time
#   - Creates unified DateTime_local column (POSIXct)
#   - Preserves original date/time columns for reference
#   - Uses convert_datetime_to_local() with explicit timezone
#
# Stage 2.6: Schema Enforcement & Finalization
#   - Validates all required master schema columns exist
#   - Enforces correct data types (character, numeric, POSIXct)
#   - Adds derived columns (Hour_local, Time_local from DateTime_local)
#   - Removes unwanted columns from intro-standardization
#   - Reorders columns to master schema layout
#
# Stage 2.7: Deduplication
#   - Identifies duplicate rows (same Detector, DateTime_local, auto_id)
#   - Removes duplicates keeping first occurrence
#   - Logs number of duplicates removed
#
# Stage 2.8: Save Master File
#   - Saves kpro_master with timestamp
#   - Uses auto-timestamping: 02_kpro_master_YYYYMMDD_HHMMSS.csv
#   - Writes to outputs/checkpoints/ directory
#
# Stage 2.9: Clean Workspace
#   - Removes intermediate objects (raw_combined, unified_data, etc.)
#   - Keeps only kpro_master in memory
#   - Frees up memory for downstream workflows
#
# OUTPUTS
# -------
# Files Created:
#   - outputs/checkpoints/02_kpro_master_YYYYMMDD_HHMMSS.csv (timestamped checkpoint)
#   - logs/workflow_log_YYYYMMDD.txt (processing log)
#   - results/validation/validation_02_YYYYMMDD_HHMMSS.yaml (validation log)
#   - results/validation/validation_02_YYYYMMDD_HHMMSS.html (validation report)
#   - inst/config/artifact_registry.yaml (updated with master file entry)
#
# In Memory:
#   - kpro_master (final standardized dataset, ready for analysis)
#
# Updated Files:
#   - inst/config/study_parameters.yaml (if detector names were added)
#
# DATA TRANSFORMATIONS APPLIED
# -----------------------------
# 1. Schema Unification (v1/v2/v3 -> Master):
#    - v1: Basic schema (6 core columns)
#    - v2: Extended schema (adds pulses, duration, etc.)
#    - v3: Latest schema (adds manual_id column)
#    - Master: Superset with all possible columns
#
# 2. Detector Mapping:
#    - 16-character DetectorID -> User-friendly Detector name
#    - Example: "S4U11651_20241015" -> "SMO"
#    - Preserves DetectorID in master for traceability
#
# 3. Timezone Conversion:
#    - AudioMoth outputs are ALWAYS UTC
#    - Converts to user's local timezone from YAML
#    - Handles DST transitions correctly
#    - Creates DateTime_local column for analysis
#
# 4. Column Standardization:
#    - Consistent naming: auto_id (not INDIR or IN DIR)
#    - Consistent types: DateTime_local (POSIXct), not character
#    - Derived columns: Hour, Time (from DateTime_local)
#    - All lowercase except proper names (Detector, DateTime_local)
#
# 5. Deduplication:
#    - Removes exact duplicates across all identifying columns
#    - Keeps first occurrence (temporal priority)
#    - Logs number removed for audit trail
#
# VALIDATION TRACKING
# -------------------
# This workflow tracks the following validation events:
#   - data_loaded: Rows loaded from intro-standardization
#   - detector_mapping: Detectors mapped to friendly names
#   - schema_transform: Schema version transformations applied
#   - timezone_conversion: UTC to local timezone conversion
#   - duplicate: Duplicate rows detected and removed
#   - rows_processed: Final row count after all processing
#
# PERFORMANCE EXPECTATIONS
# -------------------------
# Typical bat acoustic datasets:
#
# Small study (1 detector, 1 week):
#   - Rows: ~1,000-10,000
#   - Processing: < 10 seconds
#   - Memory: < 100 MB
#
# Medium study (5 detectors, 1 month):
#   - Rows: ~50,000-100,000
#   - Processing: 30-60 seconds
#   - Memory: 200-500 MB
#
# Large study (10 detectors, 3 months):
#   - Rows: 500,000-1,000,000
#   - Processing: 2-5 minutes
#   - Memory: 1-2 GB
#
# Very large study (20+ detectors, 6 months):
#   - Rows: 2,000,000+
#   - Processing: 5-15 minutes
#   - Memory: 3-5 GB
#
# Note: Time conversions are the slowest step (lubridate operations)
#
# DEPENDENCIES
# ------------
# R Packages (loaded via library()):
#   - tidyverse (dplyr, readr, purrr, stringr)
#   - lubridate (timezone conversions, datetime operations)
#   - yaml (configuration file parsing)
#
# Custom Functions (via load_all.R):
#   - core/utilities.R: log_message, safe_read_csv, load_intro_standardized
#   - core/artifacts.R: create_validation_context, log_validation_event, 
#                       finalize_validation_report, init_artifact_registry,
#                       register_artifact
#   - core/config.R: load_study_parameters, save_study_parameters
#   - standardization/standardization.R: standardize_kpro_schema
#   - standardization/datetime_conversion.R: convert_datetime_to_local
#   - validation/validation.R: enforce_unified_schema, finalize_master_columns,
#                              check_duplicates, assert_columns_exist,
#                              require_study_parameters
#
# Configuration Files:
#   - inst/config/study_parameters.yaml (detector mappings, timezone)
#
# TROUBLESHOOTING
# ---------------
# Issue: "raw_combined not found and no checkpoint available"
# Fix: Run 01_ingest_raw_data.R first
#
# Issue: "Required column 'schema_version' not found"
# Fix: Data may not be from Script 01 - re-run ingestion workflow
#
# Issue: "study_parameters.yaml not found"
# Fix: Run 01_ingest_raw_data.R which creates this file
#
# Issue: "Duplicate detector names found"
# Fix: Edit inst/config/study_parameters.yaml and ensure unique friendly names
#
# Issue: Detector name prompts appear every run
# Fix: Check YAML file saved correctly, may have file permission issue
#
# Issue: DateTime shows wrong timezone
# Fix: Verify timezone in study_parameters.yaml matches your location
#
# Issue: Memory error with large datasets
# Fix: Process in batches or increase available RAM
#
# Issue: Slow processing on large datasets
# Fix: Normal - time conversions are computationally expensive
#
# CHANGELOG
# ---------
# 2026-01-20: Standards compliance refactor (here::here paths, print_stage_header, stage renumbering)
# 2026-01-12: Enhanced validation tracking (schema_transform, timezone_conversion details)
# 2026-01-12: Added validation context tracking and artifact registration (v2.1)
# 2026-01-08: Updated appropriate callouts to datetime to datetime_local, along with time and hour
# 2025-12-29: Refactored to use helper functions (load_intro_standardized,
#             require_study_parameters, assert_columns_exist)
# 2025-12-27: Removed hardcoded timezone, now uses YAML configuration
# 2025-12-27: Updated to use convert_datetime_to_local() with explicit timezone
# 2025-12-27: Added comprehensive header documentation
# 2025-12-26: Initial CODING_STANDARDS compliant version
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Load all functions
# ------------------------------------------------------------------------------

source(here::here("R", "functions", "load_all.R"))

# ------------------------------------------------------------------------------
# Load required libraries
# ------------------------------------------------------------------------------

library(tidyverse)
library(lubridate)
library(yaml)

# ------------------------------------------------------------------------------
# Initialize logging
# ------------------------------------------------------------------------------

log_message("=== WORKFLOW 02: Standardize to Master Schema ===")

# ------------------------------------------------------------------------------
# Initialize validation context
# ------------------------------------------------------------------------------

validation_context <- create_validation_context(
  workflow = "02",
  study_name = NULL  # Will be set from params in Stage 2.2
)

# ==============================================================================
# STAGE 2.1: LOAD DATA
# ==============================================================================

print_stage_header("2.1", "Load Data")

# Load intro-standardized data (from memory or checkpoint)
raw_combined <- load_intro_standardized()

# Validate required column exists
assert_columns_exist(raw_combined, "schema_version", 
                     source_hint = "01_ingest_raw_data.R")

log_message(sprintf("[Stage 2.1] Loaded data: %s rows", nrow(raw_combined)))

# Log data loading
validation_context <- log_validation_event(
  validation_context,
  event_type = "data_loaded",
  description = "Loaded intro-standardized data",
  count = nrow(raw_combined)
)

# Store input row count for comparison
n_rows_input <- nrow(raw_combined)

# ==============================================================================
# STAGE 2.2: DETECTOR MAPPING
# ==============================================================================

print_stage_header("2.2", "Configure Detector Mapping")

# Load study parameters (validates file exists)
params <- require_study_parameters()

# Update validation context with study name
validation_context$study_name <- params$study_parameters$study_name

# Validate detector_mapping exists
if (is.null(params$study_parameters$detector_mapping)) {
  stop("No detector_mapping found in study_parameters.yaml")
}

# Convert to data frame
detector_mapping <- data.frame(
  detector_id = names(params$study_parameters$detector_mapping),
  Detector = unlist(params$study_parameters$detector_mapping),
  stringsAsFactors = FALSE
)

message(sprintf("Found %d detector mappings in YAML", nrow(detector_mapping)))

# ------------------------------------------------------------------------------
# INTERACTIVE: Prompt for any placeholders
# ------------------------------------------------------------------------------

placeholders <- detector_mapping %>%
  filter(Detector == "ENTER_NAME_HERE")

if (nrow(placeholders) > 0) {
  message("\n" %+% strrep("=", 80))
  message("DETECTOR MAPPING REQUIRED")
  message(strrep("=", 80))
  message(sprintf("\n%d detector(s) need friendly names:\n", nrow(placeholders)))
  
  # Prompt for each placeholder
  for (i in seq_len(nrow(placeholders))) {
    det_id <- placeholders$detector_id[i]
    
    message(sprintf("\n[%d/%d] Detector ID: %s", i, nrow(placeholders), det_id))
    detector_name <- readline("      Enter friendly name (e.g., 'SMO', 'LPE', 'Site_A'): ")
    detector_name <- trimws(detector_name)
    
    # Validate non-empty
    while (detector_name == "") {
      message("      [!] Name cannot be empty")
      detector_name <- trimws(readline("      Enter friendly name: "))
    }
    
    # Update mapping in data frame
    detector_mapping$Detector[detector_mapping$detector_id == det_id] <- detector_name
  }
  
  message("\n[OK] All detectors mapped")
  message(strrep("=", 80) %+% "\n")
  
  # Update YAML with new names
  params$study_parameters$detector_mapping <- setNames(
    detector_mapping$Detector,
    detector_mapping$detector_id
  )
  
  save_study_parameters(params, here::here("inst", "config", "study_parameters.yaml"))
  message("[OK] Saved detector names to study_parameters.yaml")
}

# ------------------------------------------------------------------------------
# VALIDATION: Check for duplicate names
# ------------------------------------------------------------------------------

duplicate_names <- detector_mapping$Detector[duplicated(detector_mapping$Detector)]

if (length(duplicate_names) > 0) {
  message("\n[X] ERROR: Duplicate detector names found:")
  for (dup_name in unique(duplicate_names)) {
    dups <- detector_mapping %>% filter(Detector == dup_name)
    message(sprintf("  '%s' used for: %s", 
                    dup_name, 
                    paste(dups$detector_id, collapse = ", ")))
  }
  stop("Detector names must be unique. Please edit study_parameters.yaml manually.")
}

message("[OK] No duplicate detector names found")

log_message(sprintf("[Stage 2.2] Configured %d detector mappings", nrow(detector_mapping)))

# ==============================================================================
# STAGE 2.3: SCHEMA TRANSFORMATION
# ==============================================================================

print_stage_header("2.3", "Transform to Unified Schema")

# Capture schema distribution before transformation
schema_before <- table(raw_combined$schema_version)

message("\nTransforming all schemas to unified format...")

# Use existing standardize_kpro_schema() function
# This should handle v1/v2/v3 transformation internally
unified_data <- standardize_kpro_schema(raw_combined)

message("[OK] Schema transformation complete")

log_message("[Stage 2.3] Transformed schemas to unified format")

# Log detailed schema transformation
validation_context <- log_validation_event(
  validation_context,
  event_type = "schema_transform",
  description = "Transformed all schema versions to unified master format",
  details = list(
    v1_rows = as.numeric(schema_before["v1_legacy_single_column"] %||% 0),
    v2_rows = as.numeric(schema_before["v2_transitional_4letter"] %||% 0),
    v3_rows = as.numeric(schema_before["v3_modern_6letter"] %||% 0),
    unknown_rows = as.numeric(schema_before["unknown"] %||% 0),
    total_rows = nrow(unified_data),
    transformation = "All schemas unified to master column set"
  )
)


# ==============================================================================
# STAGE 2.4: APPLY DETECTOR MAPPING
# ==============================================================================

print_stage_header("2.4", "Apply Detector Mapping")

message("Joining detector_mapping to unified_data...")

# Count detectors before mapping
n_detectors_before <- length(unique(unified_data$detector_id))

# Join detector_mapping to add Detector column
unified_data <- unified_data %>%
  left_join(detector_mapping, by = "detector_id")

# Validate all detectors were mapped
unmapped <- unified_data %>%
  filter(is.na(Detector)) %>%
  distinct(detector_id)

if (nrow(unmapped) > 0) {
  stop(sprintf(
    "ERROR: %d detector(s) not found in mapping:\n  %s\n  Please update study_parameters.yaml",
    nrow(unmapped),
    paste(unmapped$detector_id, collapse = ", ")
  ))
}

message(sprintf("[OK] Mapped %d detectors to friendly names", n_detectors_before))

# Show mapping summary
mapping_summary <- unified_data %>%
  group_by(detector_id, Detector) %>%
  summarise(calls = n(), .groups = "drop") %>%
  arrange(Detector)

message("\nDetector mapping applied:")
for (i in seq_len(nrow(mapping_summary))) {
  message(sprintf("  %s (%s): %s calls",
                  mapping_summary$Detector[i],
                  mapping_summary$detector_id[i],
                  format(mapping_summary$calls[i], big.mark = ",")))
}

log_message(sprintf("[Stage 2.4] Applied detector mapping: %d detectors", n_detectors_before))

# Log detector mapping with details
validation_context <- log_validation_event(
  validation_context,
  event_type = "detector_mapping",
  description = sprintf("Mapped %d detectors to friendly names", n_detectors_before),
  count = n_detectors_before,
  details = list(
    detectors = setNames(
      mapping_summary$Detector,
      mapping_summary$detector_id
    ),
    all_mapped_successfully = TRUE
  )
)

# ==============================================================================
# STAGE 2.5: TIME CONVERSIONS
# ==============================================================================

print_stage_header("2.5", "Time Conversions (UTC -> Local)")

# Load timezone from YAML configuration
if (is.null(params$study_parameters$timezone)) {
  stop("Timezone not set in study_parameters.yaml")
}

user_timezone <- params$study_parameters$timezone
message(sprintf("  Using study timezone: %s\n", user_timezone))

# Convert datetime_local using timezone-aware function
unified_data <- convert_datetime_to_local(
  df = unified_data,
  target_tz = user_timezone,
  date_col = "date",       # Lowercase = UTC columns from intro-standardization
  time_col = "time",       # These will be removed later
  source_tz = "UTC"
)

message(sprintf("[OK] Time conversion complete (UTC -> %s)", user_timezone))
message("  Created columns: DateTime_UTC, DateTime_local, Date_local, Time_local, Hour_local")

log_message(sprintf("[Stage 2.5] Converted times to %s", user_timezone))

# Log timezone conversion with date range details
date_range_utc <- range(unified_data$DateTime_UTC, na.rm = TRUE)
date_range_local <- range(unified_data$DateTime_local, na.rm = TRUE)

validation_context <- log_validation_event(
  validation_context,
  event_type = "timezone_conversion",
  description = sprintf("Converted UTC timestamps to %s local time", user_timezone),
  details = list(
    source_timezone = "UTC",
    target_timezone = user_timezone,
    utc_start = format(date_range_utc[1], "%Y-%m-%d %H:%M:%S"),
    utc_end = format(date_range_utc[2], "%Y-%m-%d %H:%M:%S"),
    local_start = format(date_range_local[1], "%Y-%m-%d %H:%M:%S"),
    local_end = format(date_range_local[2], "%Y-%m-%d %H:%M:%S"),
    duration_days = as.numeric(difftime(date_range_local[2], date_range_local[1], units = "days")),
    columns_created = c("DateTime_UTC", "DateTime_local", "Date_local", "Time_local", "Hour_local")
  )
)

# ==============================================================================
# STAGE 2.6: SCHEMA ENFORCEMENT & FINALIZATION
# ==============================================================================

print_stage_header("2.6", "Enforce and Finalize Schema")

# -------------------------
# Enforce unified schema (validate required columns & types)
# -------------------------

message("Validating unified schema...")
kpro_master <- enforce_unified_schema(unified_data)

# -------------------------
# Finalize columns (add Hour/Time from local timezone, remove unwanted, reorder)
# -------------------------

message("\nFinalizing master columns...")
kpro_master <- finalize_master_columns(kpro_master)

message("\n[OK] Schema enforcement and finalization complete")

log_message("[Stage 2.6] Enforced and finalized unified schema")


# ==============================================================================
# STAGE 2.7: DEDUPLICATION
# ==============================================================================

print_stage_header("2.7", "Remove Duplicates")

# Check for duplicates
dup_check <- check_duplicates(kpro_master)

n_before <- nrow(kpro_master)

# Remove duplicates (keep first occurrence)
# Duplicates defined as: same Detector, DateTime_local, auto_id
kpro_master <- kpro_master %>%
  distinct(Detector, DateTime_local, auto_id, .keep_all = TRUE)

n_after <- nrow(kpro_master)
n_removed <- n_before - n_after

if (n_removed > 0) {
  message(sprintf("[OK] Removed %s duplicate rows", format(n_removed, big.mark = ",")))
  log_message(sprintf("[Stage 2.7] Removed %d duplicates", n_removed))
  
  # Log to validation context
  validation_context <- log_validation_event(
    validation_context,
    event_type = "duplicate",
    description = "Removed duplicate detections",
    count = n_removed,
    details = list(
      deduplication_keys = c("Detector", "DateTime_local", "auto_id"),
      rows_before = n_before,
      rows_after = n_after,
      percentage_removed = round(100 * n_removed / n_before, 2)
    )
  )
} else {
  message("[OK] No duplicates found")
}

# ==============================================================================
# STAGE 2.8: SAVE MASTER FILE
# ==============================================================================

print_stage_header("2.8", "Save Master File")

# Use existing save_master_with_timestamp() function
master_file <- save_master_with_timestamp(kpro_master)

message(sprintf("[OK] Master file saved: %s", basename(master_file)))
message(sprintf("  Final row count: %s", format(nrow(kpro_master), big.mark = ",")))

log_message(sprintf("[Stage 2.8] Saved kpro_master: %s rows", nrow(kpro_master)))

# ------------------------------------------------------------------------------
# Register artifact and finalize validation
# ------------------------------------------------------------------------------

message("\nRegistering artifact...")

# Load or initialize registry
registry <- init_artifact_registry()

# Register master file artifact
registry <- register_artifact(
  registry = registry,
  artifact_name = sprintf("kpro_master_%s", format(Sys.time(), "%Y%m%d_%H%M%S")),
  artifact_type = "masterfile",
  workflow = "02",
  file_path = master_file,
  input_artifacts = c("intro_standardized"),
  metadata = list(
    n_rows = nrow(kpro_master),
    n_detectors = n_distinct(kpro_master$Detector),
    n_duplicates_removed = n_removed,
    timezone = user_timezone,
    date_range_start = format(min(kpro_master$DateTime_local, na.rm = TRUE)),
    date_range_end = format(max(kpro_master$DateTime_local, na.rm = TRUE))
  )
)

message("[OK] Artifact registered in registry")

# Finalize validation context
validation_context$summary$rows_processed <- nrow(kpro_master)

# Add input/output comparison for clarity
validation_context <- log_validation_event(
  validation_context,
  event_type = "rows_processed",
  description = sprintf("Pipeline complete: %d input -> %d output", n_rows_input, nrow(kpro_master)),
  count = nrow(kpro_master),
  details = list(
    rows_input = n_rows_input,
    rows_output = nrow(kpro_master),
    rows_removed_total = n_rows_input - nrow(kpro_master)
  )
)

validation_report_path <- finalize_validation_report(
  validation_context,
  output_dir = here::here("results", "validation")
)

log_message(sprintf("[Workflow 02] Validation report: %s", basename(validation_report_path)))

# ==============================================================================
# STAGE 2.9: CLEAN WORKSPACE
# ==============================================================================

print_stage_header("2.9", "Clean Workspace")

# Remove intermediate objects
if (exists("raw_combined")) {
  rm(raw_combined, envir = .GlobalEnv)
  message("  Removed raw_combined")
}

if (exists("unified_data")) {
  rm(unified_data, envir = .GlobalEnv)
  message("  Removed unified_data")
}

if (exists("detector_mapping")) {
  rm(detector_mapping, envir = .GlobalEnv)
  message("  Removed detector_mapping")
}

message("[OK] Workspace cleaned")

# ==============================================================================
# WORKFLOW 02 COMPLETE
# ==============================================================================

message("\n========================================")
message("  WORKFLOW 02 COMPLETE: Master Schema Created")
message("========================================\n")

message("Transformations applied:")
message("  [OK] DetectorID -> Detector mapping")
message("  [OK] Schema unification (v1/v2/v3 -> master)")
message(sprintf("  [OK] UTC -> %s time conversion", user_timezone))
message("  [OK] DateTime_local column created")
message("  [OK] Master schema enforced")
message("  [OK] Duplicates removed")
message(sprintf("  [OK] Saved: %s", basename(master_file)))

message(sprintf("\nFinal dataset: %s rows", format(nrow(kpro_master), big.mark = ",")))

# Show detector breakdown
message("\nDetector breakdown:")
detector_summary <- kpro_master %>%
  group_by(Detector) %>%
  summarise(calls = n(), .groups = "drop") %>%
  arrange(desc(calls))

for (i in seq_len(nrow(detector_summary))) {
  message(sprintf("  - %s: %s calls", 
                  detector_summary$Detector[i],
                  format(detector_summary$calls[i], big.mark = ",")))
}

message("\n========================================")
message("[OK] Workflow 02 Complete")
message("========================================")

message("\nCurrent data in environment:")
message("  - kpro_master (ready for analysis)")
message(sprintf("  - Checkpoint: %s", basename(master_file)))
message(sprintf("  - Validation report: %s", basename(validation_report_path)))

message("\nTo inspect data:")
message("  head(kpro_master)")
message("  summary(kpro_master)")
message("  table(kpro_master$Detector)")
message("  View(kpro_master)")

message("\nNext workflow:")
message("  03_generate_cpn_template.R - Generate CallsPerNight template\n")

log_message("=== WORKFLOW 02 COMPLETE ===")