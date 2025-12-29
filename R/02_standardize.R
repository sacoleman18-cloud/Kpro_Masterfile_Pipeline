# ==============================================================================
# MAINLINE WORKFLOW: 02_standardize.R
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
#   01_ingest_raw_data.R  → Load & intro-standardize raw CSVs (v1/v2/v3 detection)
#   02_standardize.R      → [THIS SCRIPT] Transform to master schema
#   03_generate_cpn_template.R → Generate CallsPerNight template
#   04_finalize_cpn.R     → Process template & calculate metrics
#
# INPUTS
# ------
# In Memory (preferred):
#   - raw_combined (from Workflow 01, intro-standardized data)
#
# OR Checkpoint (fallback):
#   - outputs/01_intro_standardized_YYYYMMDD_HHMMSS.csv
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
# Stage 2.3.5: Apply Detector Mapping to Data
#   - Joins detector_mapping to unified_data via detector_id
#   - Adds Detector (friendly name) column to dataset
#   - Validates all detectors were successfully mapped
#   - Reports mapping summary with call counts per detector
#
# Stage 2.4: Time Conversions
#   - Loads user's timezone from study_parameters.yaml
#   - Converts UTC timestamps to user's local time
#   - Creates unified DateTime column (POSIXct)
#   - Preserves original date/time columns for reference
#   - Uses convert_datetime_to_local() with explicit timezone
#
# Stage 2.5: Schema Enforcement & Finalization
#   - Validates all required master schema columns exist
#   - Enforces correct data types (character, numeric, POSIXct)
#   - Adds derived columns (Hour, Time from DateTime)
#   - Removes unwanted columns from intro-standardization
#   - Reorders columns to master schema layout
#
# Stage 2.6: Deduplication
#   - Identifies duplicate rows (same Detector, DateTime, auto_id)
#   - Removes duplicates keeping first occurrence
#   - Logs number of duplicates removed
#
# Stage 2.7: Save Master File
#   - Saves kpro_master with timestamp
#   - Uses auto-timestamping: 02_kpro_master_YYYYMMDD_HHMMSS.csv
#   - Writes to outputs/ directory
#
# Stage 2.8: Clean Workspace
#   - Removes intermediate objects (raw_combined, unified_data, etc.)
#   - Keeps only kpro_master in memory
#   - Frees up memory for downstream workflows
#
# OUTPUTS
# -------
# Files Created:
#   - outputs/02_kpro_master_YYYYMMDD_HHMMSS.csv (timestamped checkpoint)
#   - logs/workflow_log_YYYYMMDD.txt (processing log)
#
# In Memory:
#   - kpro_master (final standardized dataset, ready for analysis)
#
# Updated Files:
#   - inst/config/study_parameters.yaml (if detector names were added)
#
# DATA TRANSFORMATIONS APPLIED
# -----------------------------
# 1. Schema Unification (v1/v2/v3 → Master):
#    - v1: Basic schema (6 core columns)
#    - v2: Extended schema (adds pulses, duration, etc.)
#    - v3: Latest schema (adds manual_id column)
#    - Master: Superset with all possible columns
#
# 2. Detector Mapping:
#    - 16-character DetectorID → User-friendly Detector name
#    - Example: "S4U11651_20241015" → "SMO"
#    - Preserves DetectorID in master for traceability
#
# 3. Timezone Conversion:
#    - AudioMoth outputs are ALWAYS UTC
#    - Converts to user's local timezone from YAML
#    - Handles DST transitions correctly
#    - Creates DateTime column for analysis
#
# 4. Column Standardization:
#    - Consistent naming: auto_id (not INDIR or IN DIR)
#    - Consistent types: DateTime (POSIXct), not character
#    - Derived columns: Hour, Time (from DateTime)
#    - All lowercase except proper names (Detector, DateTime)
#
# 5. Deduplication:
#    - Removes exact duplicates across all identifying columns
#    - Keeps first occurrence (temporal priority)
#    - Logs number removed for audit trail
#
# MASTER SCHEMA DEFINITION
# -------------------------
# Final kpro_master columns (in order):
#
#   Detector       - User-friendly detector name (e.g., "SMO", "LPE")
#   DetectorID     - Original 16-char hardware ID (for traceability)
#   DateTime       - Local timestamp (POSIXct, user's timezone)
#   date           - Date component (Date type)
#   time           - Time component (hms type)
#   Hour           - Hour of day (0-23, for temporal analysis)
#   Time           - Time as decimal (0.0-23.999, for plotting)
#   auto_id        - Auto-identified species/call type
#   manual_id      - Manual identification (NA if not performed)
#   pulses         - Number of pulses detected (v2+ only)
#   duration       - Call duration in ms (v2+ only)
#   fmax           - Maximum frequency in kHz (v2+ only)
#   fmin           - Minimum frequency in kHz (v2+ only)
#   fctr           - Center frequency in kHz (v2+ only)
#   bandwidth      - Bandwidth in kHz (v2+ only)
#   fmean          - Mean frequency in kHz (v2+ only)
#   fmax_amp       - Frequency at max amplitude (v2+ only)
#   dur_ms         - Call duration (v2+ only)
#   qualityscore   - Quality score 0-100 (v2+ only)
#   file           - Original audio filename
#   schema_version - Source schema (v1/v2/v3, for provenance)
#
# Missing columns (v1 data): Set to NA with correct type
# Extra columns: Removed during finalization
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
#   - core/config.R: load_study_parameters, save_study_parameters
#   - core/utilities.R: log_message, safe_read_csv
#   - standardization/standardization.R: standardize_kpro_schema
#   - standardization/datetime_conversion.R: convert_datetime_to_local
#   - validation/validation.R: enforce_unified_schema, 
#                              finalize_master_columns,
#                              check_duplicates
#   - core/utilities.R: save_master_with_timestamp
#
# Configuration Files:
#   - inst/config/study_parameters.yaml (detector mappings, timezone)
#
# TROUBLESHOOTING
# ---------------
# Issue: "raw_combined not found"
# Fix: Run 01_ingest_raw_data.R first, or load checkpoint manually
#
# Issue: "schema_version column not found"
# Fix: Data may not be from Script 01 - re-run ingestion workflow
#
# Issue: "Timezone not set in study_parameters.yaml"
# Fix: Run 01_ingest_raw_data.R which prompts for timezone
#
# Issue: "Duplicate detector names found"
# Fix: Edit inst/config/study_parameters.yaml and ensure unique friendly names
#
# Issue: Detector name prompts appear every run
# Fix: Check YAML file saved correctly, may have file permission issue
#
# Issue: "Failed to load checkpoint file"
# Fix: Check outputs/ directory exists and contains intro_standardized CSVs
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
# USAGE EXAMPLES
# --------------
# # Run after Workflow 01:
# source("R/workflows/01_ingest_raw_data.R")
# source("R/workflows/02_standardize.R")
#
# # Run standalone (loads from checkpoint):
# source("R/workflows/02_standardize.R")
#
# # Inspect results:
# head(kpro_master)
# summary(kpro_master)
# table(kpro_master$Detector)
# table(kpro_master$schema_version)
# range(kpro_master$DateTime)
# View(kpro_master)
#
# # Check for missing values:
# colSums(is.na(kpro_master))
#
# # Export for external analysis:
# write_csv(kpro_master, "data/kpro_master_for_analysis.csv")
#
# MAINTAINER NOTES
# ----------------
# - ASCII boxes: Single-line (┌─┐) for stage headers
# - Stage numbering: 2.1 - 2.8 (8 stages total)
# - Detector mapping is critical - must be unique and descriptive
# - Timezone handling changed in Dec 2024 - now requires user timezone in YAML
# - Schema detection happens in Script 01, transformation in Script 02
# - Never modify timezone assumptions - always use YAML configuration
# - Deduplication uses Detector, DateTime, auto_id (not file or other fields)
# - Master schema is additive - new columns can be added without breaking
# - All validation functions are in validation/validation.R
# - Time conversion function is timezone-aware (no hardcoded CST)
#
# CHANGELOG
# ---------
# 2024-12-27: Removed hardcoded timezone, now uses YAML configuration
# 2024-12-27: Updated to use convert_datetime_to_local() with explicit timezone
# 2024-12-27: Added comprehensive header documentation
# 2024-12-26: Initial CODING_STANDARDS compliant version
#
# ==============================================================================

# OUTPUTS
# -------
# - kpro_master (in memory, ready for analysis)
# - outputs/02_kpro_master_YYYYMMDD_HHMMSS.csv (timestamped checkpoint)
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
library(lubridate)
library(yaml)

# ------------------------------------------------------------------------------
# Initialize logging
# ------------------------------------------------------------------------------

log_message("=== WORKFLOW 02: Standardize to Master Schema ===")

# ==============================================================================
# STAGE 2.1: LOAD DATA
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 2.1: Load Data                                  │")
message("└────────────────────────────────────────────────────────────────┘\n")

# Check if raw_combined exists in memory
if (exists("raw_combined")) {
  message("✓ Using raw_combined from memory")
  message(sprintf("  Rows: %s", format(nrow(raw_combined), big.mark = ",")))
  
} else {
  # Load most recent checkpoint from outputs/
  message("raw_combined not found in memory - loading from checkpoint...")
  
  checkpoint_files <- list.files("outputs", 
                                 pattern = "^01_intro_standardized_.*\\.csv$",
                                 full.names = TRUE)
  
  if (length(checkpoint_files) == 0) {
    stop("No checkpoint files found in outputs/. Please run 01_ingest_raw_data.R first.")
  }
  
  # Get most recent checkpoint
  checkpoint_file <- checkpoint_files[order(file.mtime(checkpoint_files), decreasing = TRUE)][1]
  
  message(sprintf("  Loading: %s", basename(checkpoint_file)))
  
  raw_combined <- safe_read_csv(checkpoint_file)
  
  if (is.null(raw_combined)) {
    stop("Failed to load checkpoint file")
  }
  
  message(sprintf("✓ Loaded checkpoint: %s rows", format(nrow(raw_combined), big.mark = ",")))
}

# Validate schema_version column exists
if (!"schema_version" %in% names(raw_combined)) {
  stop("schema_version column not found - data may not be from Script 01")
}

log_message(sprintf("[Stage 2.1] Loaded data: %s rows", nrow(raw_combined)))

# ==============================================================================
# STAGE 2.2: DETECTOR MAPPING
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 2.2: Configure Detector Mapping                 │")
message("└────────────────────────────────────────────────────────────────┘\n")

# Load study parameters (guaranteed to exist by Script 01)
if (!file.exists("inst/config/study_parameters.yaml")) {
  stop("inst/config/study_parameters.yaml not found. Please run 01_ingest_raw_data.R first.")
}

params <- load_study_parameters("inst/config/study_parameters.yaml")

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
      message("      ⚠️  Name cannot be empty")
      detector_name <- trimws(readline("      Enter friendly name: "))
    }
    
    # Update mapping in data frame
    detector_mapping$Detector[detector_mapping$detector_id == det_id] <- detector_name
  }
  
  message("\n✓ All detectors mapped")
  message(strrep("=", 80) %+% "\n")
  
  # Update YAML with new names
  params$study_parameters$detector_mapping <- setNames(
    detector_mapping$Detector,
    detector_mapping$detector_id
  )
  
  save_study_parameters(params, "inst/config/study_parameters.yaml")
  message("✓ Saved detector names to study_parameters.yaml")
}

# ------------------------------------------------------------------------------
# VALIDATION: Check for duplicate names
# ------------------------------------------------------------------------------

duplicate_names <- detector_mapping$Detector[duplicated(detector_mapping$Detector)]

if (length(duplicate_names) > 0) {
  message("\n❌ ERROR: Duplicate detector names found:")
  for (dup_name in unique(duplicate_names)) {
    dups <- detector_mapping %>% filter(Detector == dup_name)
    message(sprintf("  '%s' used for: %s", 
                    dup_name, 
                    paste(dups$detector_id, collapse = ", ")))
  }
  stop("Detector names must be unique. Please edit study_parameters.yaml manually.")
}

message("✓ No duplicate detector names found")

log_message(sprintf("[Stage 2.2] Configured %d detector mappings", nrow(detector_mapping)))

# ==============================================================================
# STAGE 2.3: SCHEMA TRANSFORMATION
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 2.3: Transform to Unified Schema                │")
message("└────────────────────────────────────────────────────────────────┘\n")

# Use existing standardize_kpro_schema() function
# This should handle v1/v2/v3 transformation internally
message("\nTransforming all schemas to unified format...")

unified_data <- standardize_kpro_schema(raw_combined)

message("✓ Schema transformation complete")

log_message("[Stage 2.3] Transformed schemas to unified format")


# ==============================================================================
# STAGE 2.3.5: APPLY DETECTOR MAPPING (NEW STAGE - CRITICAL FIX)
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 2.3.5: Apply Detector Mapping to Data          │")
message("└────────────────────────────────────────────────────────────────┘\n")

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

message(sprintf("✓ Mapped %d detectors to friendly names", n_detectors_before))

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

log_message(sprintf("[Stage 2.3.5] Applied detector mapping: %d detectors", n_detectors_before))

# ==============================================================================
# STAGE 2.4: TIME CONVERSIONS
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 2.4: Time Conversions (UTC → Local Time)        │")
message("└────────────────────────────────────────────────────────────────┘\n")

# -------------------------
# Load timezone from YAML configuration
# -------------------------

if (is.null(params$study_parameters$timezone)) {
  stop("Timezone not set in study_parameters.yaml. Please run 01_ingest_raw_data.R first.")
}

user_timezone <- params$study_parameters$timezone
message(sprintf("  Using study timezone from config: %s\n", user_timezone))

# -------------------------
# Convert datetime using timezone-aware function
# -------------------------

unified_data <- convert_datetime_to_local(
  df = unified_data,
  target_tz = user_timezone,
  date_col = "date",
  time_col = "time",
  source_tz = "UTC"
)

message(sprintf("✓ Time conversion complete (UTC → %s)", user_timezone))

log_message(sprintf("[Stage 2.4] Converted times to %s", user_timezone))

# ==============================================================================
# STAGE 2.5: SCHEMA ENFORCEMENT & FINALIZATION
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 2.5: Enforce & Finalize Schema                  │")
message("└────────────────────────────────────────────────────────────────┘\n")

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

message("\n✓ Schema enforcement and finalization complete")

log_message("[Stage 2.5] Enforced and finalized unified schema")


# ==============================================================================
# STAGE 2.6: DEDUPLICATION
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 2.6: Remove Duplicates                          │")
message("└────────────────────────────────────────────────────────────────┘\n")

# Check for duplicates
dup_check <- check_duplicates(kpro_master)

n_before <- nrow(kpro_master)

# Remove duplicates (keep first occurrence)
# Duplicates defined as: same Detector, DateTime, auto_id
kpro_master <- kpro_master %>%
  distinct(Detector, DateTime, auto_id, .keep_all = TRUE)

n_after <- nrow(kpro_master)
n_removed <- n_before - n_after

if (n_removed > 0) {
  message(sprintf("✓ Removed %s duplicate rows", format(n_removed, big.mark = ",")))
  log_message(sprintf("[Stage 2.6] Removed %d duplicates", n_removed))
} else {
  message("✓ No duplicates found")
}

# ==============================================================================
# STAGE 2.7: SAVE MASTER FILE
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 2.7: Save Master File                           │")
message("└────────────────────────────────────────────────────────────────┘\n")

# Use existing save_master_with_timestamp() function
master_file <- save_master_with_timestamp(kpro_master)

message(sprintf("✓ Master file saved: %s", basename(master_file)))
message(sprintf("  Final row count: %s", format(nrow(kpro_master), big.mark = ",")))

log_message(sprintf("[Stage 2.7] Saved kpro_master: %s rows", nrow(kpro_master)))

# ==============================================================================
# STAGE 2.8: CLEAN WORKSPACE
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 2.8: Clean Workspace                            │")
message("└────────────────────────────────────────────────────────────────┘\n")

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

message("✓ Workspace cleaned")

# ==============================================================================
# STAGE 2 COMPLETE
# ==============================================================================

message("\n╔══════════════════════════════════════════════════════════════╗")
message("║          STAGE 2 COMPLETE: Master Schema Created               ║")
message("╚══════════════════════════════════════════════════════════════╝")

message("\nTransformations applied:")
message("  ✓ DetectorID → Detector mapping")
message("  ✓ Schema unification (v1/v2/v3 → master)")
message(sprintf("  ✓ UTC → %s time conversion", user_timezone))
message("  ✓ DateTime column created")
message("  ✓ Master schema enforced")
message("  ✓ Duplicates removed")
message(sprintf("  ✓ Saved: %s", basename(master_file)))

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
message("✓ Workflow 02 Complete")
message("========================================")
message("\nCurrent data in environment:")
message("  • kpro_master (ready for analysis)")
message(sprintf("  • Checkpoint: %s", basename(master_file)))

message("\nTo inspect data:")
message("  head(kpro_master)")
message("  summary(kpro_master)")
message("  table(kpro_master$Detector)")
message("  View(kpro_master)")

message("\nNext workflow:")
message("  03_calls_per_night.R - Generate CallsPerNight template\n")

log_message("=== WORKFLOW 02 COMPLETE ===")
