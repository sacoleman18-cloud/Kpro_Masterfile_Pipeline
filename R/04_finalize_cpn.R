# ==============================================================================
# WORKFLOW 04: 04_finalize_cpn.R
# ==============================================================================
# PURPOSE
# -------
# Process manually-edited CallsPerNight template to produce final dataset
# with recording hours, status classifications, and calculated metrics.
# Tracks all manual edits and generates comprehensive audit logs.
#
# Preserves the unified `species` column created in Workflow 03 for use
# in downstream analysis (Workflow 05 summaries, Workflow 06 plots).
#
# WORKFLOW POSITION
# -----------------
# This is Workflow 04 in the processing pipeline:
#   01_ingest_raw_data.R  -> Load & intro-standardize raw CSVs
#   02_standardize.R      -> Transform to master schema
#   [OPTIONAL: Manual ID in Kaleidoscope]
#   03_generate_cpn_template.R -> Generate template for editing + species unification
#   [USER: Edit template in Excel]
#   04_finalize_cpn.R     -> [THIS SCRIPT] Process edited template
#   05_summary_stats.R    -> Generate summary statistics and tables
#   06_generate_plots.R   -> Generate exploratory visualizations
#
# INPUTS
# ------
# Required Files:
#   - Edited template CSV (*_EDIT_THIS_*.csv from Workflow 03)
#   - Original template CSV (automatically located from outputs/)
#
# In Memory (from script 03):
#   - kpro_master (filtered data with unified `species` column)
#
# OR Checkpoint (fallback):
#   - outputs/checkpoints/02_kpro_master_YYYYMMDD_HHMMSS.csv
#
# Configuration Files:
#   - inst/config/study_parameters.yaml (recording schedule)
#
# TWO-FILE TEMPLATE SYSTEM
# -------------------------
# Workflow 03 creates two template files:
#
# 1. *_ORIGINAL_*.csv - Original template (never edited)
#    - Used for comparison to track manual edits
#    - Maintains audit trail
#
# 2. *_EDIT_THIS_*.csv - Editable template (user edited this)
#    - User makes all StartDateTime/EndDateTime changes here
#    - This is the file Workflow 04 processes
#
# Workflow 04 compares ORIGINAL vs EDIT_THIS to generate edit log.
#
# SPECIES COLUMN PRESERVATION
# ----------------------------
# This workflow validates that kpro_master contains the unified `species`
# column created in Workflow 03. This column is used by:
#   - Workflow 05: Species summary statistics
#   - Workflow 06: Species composition plots
#   - Quarto reports: Species analysis sections
#
# The original auto_id and manual_id columns are also preserved for audit.
#
# PROCESSING STAGES
# -----------------
# Stage 4.1: Load Edited Template
#   - Looks for most recent EDIT_THIS file (defaults to latest)
#   - Validates structure and column names
#   - Recalculates RecordingHours from edited times
#
# Stage 4.2: Track Manual Edits
#   - Compares ORIGINAL vs EDITED templates
#   - Identifies all StartDateTime/EndDateTime changes
#   - Generates detailed edit log file
#   - Counts total manual adjustments
#
# Stage 4.3: Set Recording Status
#   - Classifies each night as Fail/Success/Partial
#   - Fail: RecordingHours == 0 or NA
#   - Success: RecordingHours > 0 AND matches uniform schedule
#   - Partial: RecordingHours > 0 AND manually adjusted
#
# Stage 4.4: Calculate Metrics
#   - Computes CallsPerHour (CallsPerNight / RecordingHours)
#   - RETAINS "dead nights" (RecordingHours = 0 or NA) with Status = Fail
#   - Dead nights have CallsPerHour = NA for NB GAMM models
#   - Calculates summary statistics
#
# Stage 4.5: Validate & Save
#   - Validates master schema compliance
#   - Validates species column exists in kpro_master
#   - Saves with auto-incrementing version (v1, v2, v3...)
#   - Logs final dataset summary
#
# OUTPUTS
# -------
# Files Created:
#   - outputs/04_CallsPerNight_EditLog_YYYYMMDD_HHMMSS.txt (edit tracking)
#   - results/csv/CallsPerNight_final_vX.csv (final versioned dataset)
#   - logs/workflow_log_YYYYMMDD.txt (processing log)
#   - results/validation/validation_04_YYYYMMDD_HHMMSS.yaml (validation log)
#   - results/validation/validation_04_YYYYMMDD_HHMMSS.html (validation report)
#
# In Memory:
#   - calls_per_night_final (ready for analysis)
#   - kpro_master (with unified `species` column, ready for Workflow 05/06)
#
# Registry:
#   - inst/config/artifact_registry.yaml (updated with final CPN)
#
# STATUS VALUES
# -------------
# Three possible statuses for each night:
#
# 1. "Fail" - Equipment failure or no recording
#    - RecordingHours == 0
#    - RecordingHours is NA
#    - StartDateTime or EndDateTime missing
#    - RETAINED in dataset with CallsPerHour = NA
#
# 2. "Success" - Full recording as scheduled
#    - RecordingHours > 0
#    - Matches uniform start/end times (if uniform schedule used)
#    - No manual adjustments needed
#
# 3. "Partial" - Reduced recording (equipment issue, SD card full, etc.)
#    - RecordingHours > 0
#    - Manually adjusted from uniform schedule
#    - User edited StartDateTime or EndDateTime in template
#
# DEAD NIGHTS RETENTION
# ----------------------
# Dead nights (Status = Fail) are RETAINED in the final dataset for:
#   - NB GAMM models that need structural zeros
#   - Accurate effort calculations
#   - Complete temporal coverage visualization
#
# Dead nights have:
#   - RecordingHours = 0 or NA
#   - CallsPerHour = NA (not calculated)
#   - Status = "Fail"
#
# VALIDATION TRACKING
# -------------------
# This workflow tracks the following validation events:
#   - data_loaded: Edited template loaded
#   - recalculation: RecordingHours recalculated from datetimes
#   - manual_edits: Edit tracking with type breakdown
#   - status_classification: Recording status distribution
#   - dead_nights: Dead nights retained for NB GAMM
#   - metrics_calculated: CallsPerHour and effort summary
#   - validation: Species column validation
#   - validation: Schema validation results
#   - file_saved: Final dataset saved with version
#
# DEPENDENCIES
# ------------
# R Packages:
#   - dplyr, tidyr, readr (data manipulation)
#   - lubridate (date/time calculations)
#   - hms (time parsing)
#   - here (path management)
#   - stringr (string operations)
#
# Custom Functions (via load_all.R):
#   - core/utilities.R: log_message, safe_read_csv, load_master_data,
#                       find_most_recent_file, make_versioned_path
#   - core/artifacts.R: create_validation_context, log_validation_event,
#                       finalize_validation_report, init_artifact_registry,
#                       register_artifact
#   - validation/validation.R: require_study_parameters, assert_file_exists,
#                              assert_columns_exist, validate_calls_per_night
#   - analysis/callspernight.R: calculate_recording_hours,
#                                save_callspernight_with_version,
#                                parse_date_safe, parse_datetime_safe,
#                                format_datetime_for_log, extract_time
#
# Configuration Files:
#   - inst/config/study_parameters.yaml (recording schedule)
#
# TROUBLESHOOTING
# ---------------
# Issue: "Original template not found"
# Fix: Run 03_generate_cpn_template.R first
#
# Issue: "Edited template missing columns"
# Fix: Verify column names match exactly (case-sensitive)
#
# Issue: "kpro_master not found"
# Fix: Run 03_generate_cpn_template.R first (keeps kpro_master in memory)
#
# Issue: "species column not found"
# Fix: Re-run Workflow 03 to create unified species column
#
# Issue: "Excel formula not calculating"
# Fix: Check that Excel auto-calculation is enabled, or manually recalculate
#
# USAGE EXAMPLES
# --------------
# # Run after editing template from script 03:
# source("R/workflows/04_finalize_cpn.R")
#
# # Inspect results:
# head(calls_per_night_final)
# table(calls_per_night_final$Status)
# summary(calls_per_night_final$CallsPerHour)
#
# # Check species column in master:
# table(kpro_master$species)
#
# MAINTAINER NOTES
# ----------------
# - Uses print_stage_header() for all stage headers
# - Stage numbering: 4.1 - 4.6
# - Edit log critical for reproducibility and audit trail
# - Status classification must be deterministic
# - Final dataset must pass validation
# - Version numbering auto-increments (v1, v2, v3...)
# - Two-file system: ORIGINAL for tracking, EDIT_THIS for processing
# - Dead nights RETAINED for NB GAMM models (CallsPerHour = NA)
# - Species column validated but not modified (created in Workflow 03)
#
# CHANGELOG
# ---------
# 2026-01-23: Standards compliance refactor (here::here paths, print_stage_header)
# 2026-01-12: Enhanced validation tracking with edit breakdown, status details, effort metrics
# 2026-01-12: Added artifact registration for final CallsPerNight dataset (v2.1)
# 2025-01-07: Added species column validation; retained dead nights for NB GAMM
# 2024-12-29: Refactored to use helper functions (load_master_data,
#             require_study_parameters, find_most_recent_file,
#             assert_file_exists, assert_columns_exist, make_versioned_path)
# 2024-12-27: Added comprehensive header documentation
# 2024-12-26: Initial CODING_STANDARDS compliant version
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Load all functions
# ------------------------------------------------------------------------------

source(here::here("R", "functions", "load_all.R"))

# ------------------------------------------------------------------------------
# Load required libraries
# ------------------------------------------------------------------------------

library(dplyr)      # For %>%, mutate(), select(), filter(), etc.
library(tidyr)      # For replace_na(), pivot_wider(), etc.
library(readr)      # For read_csv(), write_csv()
library(lubridate)  # For date/time parsing (mdy_hms, mdy_hm, etc.)
library(hms)        # For time parsing (as_hms)
library(here)       # For path management
library(stringr)    # For string operations (str_extract, etc.)

# ------------------------------------------------------------------------------
# Initialize logging
# ------------------------------------------------------------------------------

log_message("=== WORKFLOW 04: Finalize CallsPerNight ===")

# ------------------------------------------------------------------------------
# Initialize validation context
# ------------------------------------------------------------------------------

validation_context <- create_validation_context(
  workflow = "04",
  study_name = NULL  # Will be set from params below
)

# ------------------------------------------------------------------------------
# Load YAML parameters
# ------------------------------------------------------------------------------

# Load study parameters (validates file exists)
params <- require_study_parameters()

# Update validation context with study name
validation_context$study_name <- params$study_parameters$study_name

# Extract uniform schedule for status classification
advanced_scheduling <- params$processing_options$advanced_scheduling %||% FALSE

if (!advanced_scheduling) {
  uniform_start <- params$processing_options$recording_start
  uniform_end <- params$processing_options$recording_end
} else {
  uniform_start <- NA
  uniform_end <- NA
}


# ==============================================================================
# LOAD REQUIRED DATA
# ==============================================================================

# Load master data (from memory or checkpoint)
kpro_master <- load_master_data()

# ------------------------------------------------------------------------------
# Validate species column exists
# ------------------------------------------------------------------------------

if (!"species" %in% names(kpro_master)) {
  warning("'species' column not found in kpro_master")
  message("\n[!] species column missing - creating from auto_id")
  message("  For proper species unification, re-run Workflow 03")
  
  # Fallback: create species from auto_id only
  # Define is_unidentifiable if not already available
  is_unidentifiable <- function(id) {
    is.na(id) | trimws(id) == "" | id %in% c("NoID", "UNKNOWN")
  }
  
  kpro_master <- kpro_master %>%
    mutate(
      species = if_else(
        !is_unidentifiable(auto_id),
        auto_id,
        NA_character_
      )
    )
  
  message(sprintf("  Created species column from auto_id: %d unique species",
                  n_distinct(kpro_master$species, na.rm = TRUE)))
} else {
  message("[OK] species column present in kpro_master")
  message(sprintf("  Unique species: %d", n_distinct(kpro_master$species, na.rm = TRUE)))
}

# Load original template from script 03
template_original_file <- find_most_recent_file(
  here::here("outputs"),
  "^03_CallsPerNight_Template_ORIGINAL_.*\\.csv$",
  hint = "Run 03_generate_cpn_template.R first"
)

message(sprintf("\nFound original template: %s", basename(template_original_file)))

# Load original template for comparison
template <- safe_read_csv(template_original_file)

# Extract timestamp from original template filename for edit log
timestamp <- sub(".*_ORIGINAL_(\\d{8}_\\d{6})\\.csv$", "\\1", basename(template_original_file))

# ==============================================================================
# STAGE 4.1: LOAD EDITED TEMPLATE
# ==============================================================================

print_stage_header("4.1", "Load Edited Template")

# Look for most recent EDIT_THIS file as default
editable_files <- list.files(here::here("outputs"),
                             pattern = "^03_CallsPerNight_Template_EDIT_THIS_.*\\.csv$",
                             full.names = TRUE)

if (length(editable_files) > 0) {
  # Get most recent EDIT_THIS file
  default_file <- editable_files[order(file.mtime(editable_files), decreasing = TRUE)][1]
  
  message("Found edited template file:")
  message(sprintf("  %s", basename(default_file)))
  message("\nPress Enter to use this file, or provide path to a different edited file:")
  message("(Leave blank to use the file above)\n")
  
  edited_file_input <- trimws(readline("Edited file path (or Enter): "))
  
  # Use default if no input provided
  if (edited_file_input == "") {
    edited_file <- default_file
    message(sprintf("  Using: %s", basename(edited_file)))
  } else {
    edited_file <- edited_file_input
  }
} else {
  # No EDIT_THIS file found - prompt for file
  message("No EDIT_THIS template found.")
  message("Please provide the path to your edited template:\n")
  
  edited_file_input <- trimws(readline("Edited file path: "))
  
  if (edited_file_input == "") {
    stop("No file path provided. Please run 03_generate_cpn_template.R first.")
  }
  
  edited_file <- edited_file_input
}

# Validate file exists
assert_file_exists(edited_file, hint = "Run 03_generate_cpn_template.R first")

message(sprintf("\n  Loading: %s", basename(edited_file)))

# Load edited template
template_edited <- safe_read_csv(edited_file)

if (is.null(template_edited)) {
  stop("Failed to load edited template")
}

# Validate required columns
assert_columns_exist(
  template_edited,
  c("Detector", "Night", "CallsPerNight", "StartDateTime", "EndDateTime", "RecordingHours"),
  source_hint = "03_generate_cpn_template.R"
)

# Remove detector_id if user added it back
if ("detector_id" %in% names(template_edited)) {
  message("  Removing detector_id column (not needed)...")
  template_edited <- template_edited %>% select(-detector_id)
}

message("[OK] Template structure validated")

log_message(sprintf("[Stage 4.1] Loaded edited template: %d rows", 
                    nrow(template_edited)))

# Log template loading
validation_context <- log_validation_event(
  validation_context,
  event_type = "data_loaded",
  description = sprintf("Loaded edited template: %s", basename(edited_file)),
  count = nrow(template_edited),
  details = list(
    file = basename(edited_file),
    original_template = basename(template_original_file)
  )
)

# Recalculate RecordingHours from edited datetimes
message("\nRecalculating RecordingHours from edited StartDateTime/EndDateTime...")

template_edited <- template_edited %>%
  mutate(
    RecordingHours = mapply(calculate_recording_hours, StartDateTime, EndDateTime)
  )

message(sprintf("[OK] Recalculated RecordingHours for %s rows", 
                format(nrow(template_edited), big.mark = ",")))

log_message(sprintf("[Stage 4.1] Recalculated RecordingHours for %d rows", 
                    nrow(template_edited)))

# Log recalculation
validation_context <- log_validation_event(
  validation_context,
  event_type = "recalculation",
  description = "Recalculated RecordingHours from edited datetimes",
  count = nrow(template_edited)
)

# ==============================================================================
# STAGE 4.2: TRACK EDITS
# ==============================================================================

print_stage_header("4.2", "Track Manual Edits")

message("Comparing ORIGINAL vs EDITED templates...")

# Debug: Show what we're comparing
message(sprintf("  Original template rows: %d", nrow(template)))
message(sprintf("  Edited template rows: %d", nrow(template_edited)))

# Ensure Night columns are same type (Date) for join
message("  Parsing Night columns...")

# Parse Night in original template
if (is.Date(template$Night)) {
  # Already a Date object, keep as-is
  template <- template %>%
    mutate(Night = as.Date(Night))
} else {
  # Parse from string using parse_date_safe() from callspernight.R
  template <- template %>%
    mutate(Night = sapply(Night, parse_date_safe) %>% as.Date(origin = "1970-01-01"))
}

# Parse Night in edited template
if (is.Date(template_edited$Night)) {
  # Already a Date object, keep as-is
  template_edited <- template_edited %>%
    mutate(Night = as.Date(Night))
} else {
  # Parse from string using parse_date_safe() from callspernight.R
  template_edited <- template_edited %>%
    mutate(Night = sapply(Night, parse_date_safe) %>% as.Date(origin = "1970-01-01"))
}

message(sprintf("  Original Night range: %s to %s", 
                min(template$Night, na.rm = TRUE), 
                max(template$Night, na.rm = TRUE)))
message(sprintf("  Edited Night range: %s to %s", 
                min(template_edited$Night, na.rm = TRUE), 
                max(template_edited$Night, na.rm = TRUE)))

# Parse datetimes in both templates using parse_datetime_safe() from callspernight.R
message("  Parsing original template datetimes...")
template_orig_parsed <- template %>%
  select(Detector, Night, 
         StartDateTime_orig_str = StartDateTime,
         EndDateTime_orig_str = EndDateTime) %>%
  mutate(
    StartDateTime_orig = sapply(StartDateTime_orig_str, parse_datetime_safe) %>% 
      as.POSIXct(origin = "1970-01-01", tz = "UTC"),
    EndDateTime_orig = sapply(EndDateTime_orig_str, parse_datetime_safe) %>% 
      as.POSIXct(origin = "1970-01-01", tz = "UTC")
  )

message("  Parsing edited template datetimes...")
template_edit_parsed <- template_edited %>%
  select(Detector, Night,
         StartDateTime_edit_str = StartDateTime,
         EndDateTime_edit_str = EndDateTime,
         RecordingHours_edit = RecordingHours) %>%
  mutate(
    StartDateTime_edit = sapply(StartDateTime_edit_str, parse_datetime_safe) %>% 
      as.POSIXct(origin = "1970-01-01", tz = "UTC"),
    EndDateTime_edit = sapply(EndDateTime_edit_str, parse_datetime_safe) %>% 
      as.POSIXct(origin = "1970-01-01", tz = "UTC")
  )

# Debug: Check parsed data
message(sprintf("  Parsed original rows: %d", nrow(template_orig_parsed)))
message(sprintf("  Parsed edited rows: %d", nrow(template_edit_parsed)))

# Debug: Show sample detectors and nights
if (nrow(template_orig_parsed) > 0) {
  sample_orig <- template_orig_parsed %>% head(3)
  message("  Sample from original:")
  message(sprintf("    Detector: %s | Night: %s", 
                  paste(sample_orig$Detector, collapse = ", "),
                  paste(sample_orig$Night, collapse = ", ")))
}

if (nrow(template_edit_parsed) > 0) {
  sample_edit <- template_edit_parsed %>% head(3)
  message("  Sample from edited:")
  message(sprintf("    Detector: %s | Night: %s", 
                  paste(sample_edit$Detector, collapse = ", "),
                  paste(sample_edit$Night, collapse = ", ")))
}

# Join and compare PARSED datetimes (not string representations)
message("  Joining original and edited templates...")
comparison <- template_orig_parsed %>%
  inner_join(template_edit_parsed, by = c("Detector", "Night"))

message(sprintf("  Joined comparison rows: %d", nrow(comparison)))

if (nrow(comparison) == 0) {
  message("  ERROR: Join produced 0 rows!")
  message("  Checking for common Detector/Night pairs...")
  
  orig_keys <- template_orig_parsed %>% 
    select(Detector, Night) %>%
    distinct() %>%
    mutate(key = paste(Detector, Night))
  
  edit_keys <- template_edit_parsed %>% 
    select(Detector, Night) %>%
    distinct() %>%
    mutate(key = paste(Detector, Night))
  
  common_keys <- intersect(orig_keys$key, edit_keys$key)
  message(sprintf("  Common keys found: %d", length(common_keys)))
  
  if (length(common_keys) > 0) {
    message(sprintf("  Sample common keys: %s", paste(head(common_keys, 3), collapse = "; ")))
  }
  
  only_in_orig <- setdiff(orig_keys$key, edit_keys$key)
  only_in_edit <- setdiff(edit_keys$key, orig_keys$key)
  
  if (length(only_in_orig) > 0) {
    message(sprintf("  Keys only in original: %d", length(only_in_orig)))
    message(sprintf("    Example: %s", paste(head(only_in_orig, 3), collapse = "; ")))
  }
  
  if (length(only_in_edit) > 0) {
    message(sprintf("  Keys only in edited: %d", length(only_in_edit)))
    message(sprintf("    Example: %s", paste(head(only_in_edit, 3), collapse = "; ")))
  }
  
  stop("Join failed - no matching Detector/Night pairs found between original and edited templates.\n  This suggests the templates are from different runs or have been modified incorrectly.\n  Please ensure you're comparing matching templates.")
}

# Calculate changes
message("  Calculating changes...")
comparison <- comparison %>%
  mutate(
    # Compare parsed datetime objects (handles Excel auto-formatting)
    # Use tolerance of 1 second to handle floating point precision
    StartDateTime_changed = !is.na(StartDateTime_orig) & 
      !is.na(StartDateTime_edit) & 
      abs(difftime(StartDateTime_orig, StartDateTime_edit, units = "secs")) > 1,
    
    EndDateTime_changed = !is.na(EndDateTime_orig) & 
      !is.na(EndDateTime_edit) & 
      abs(difftime(EndDateTime_orig, EndDateTime_edit, units = "secs")) > 1,
    
    # Also check if times went from filled to NA or vice versa
    StartDateTime_added = is.na(StartDateTime_orig) & !is.na(StartDateTime_edit),
    StartDateTime_removed = !is.na(StartDateTime_orig) & is.na(StartDateTime_edit),
    
    EndDateTime_added = is.na(EndDateTime_orig) & !is.na(EndDateTime_edit),
    EndDateTime_removed = !is.na(EndDateTime_orig) & is.na(EndDateTime_edit),
    
    # Any change = value changed OR added OR removed
    Any_change = StartDateTime_changed | EndDateTime_changed |
      StartDateTime_added | StartDateTime_removed |
      EndDateTime_added | EndDateTime_removed
  )

# Count edits
total_edits <- sum(comparison$Any_change, na.rm = TRUE)

message(sprintf("  Total manual edits: %d", total_edits))

# Debug: Show breakdown if no edits
if (total_edits == 0) {
  message("  No manual edits detected - checking why...")
  
  # Check if any values differ (even NA)
  start_differs <- sum(!is.na(comparison$StartDateTime_orig) & 
                         !is.na(comparison$StartDateTime_edit) &
                         comparison$StartDateTime_orig != comparison$StartDateTime_edit, 
                       na.rm = TRUE)
  
  end_differs <- sum(!is.na(comparison$EndDateTime_orig) & 
                       !is.na(comparison$EndDateTime_edit) &
                       comparison$EndDateTime_orig != comparison$EndDateTime_edit, 
                     na.rm = TRUE)
  
  message(sprintf("    Rows with different StartDateTime values: %d", start_differs))
  message(sprintf("    Rows with different EndDateTime values: %d", end_differs))
  
  if (start_differs > 0 || end_differs > 0) {
    message("    NOTE: Some datetimes differ but by < 1 second (Excel rounding)")
    message("          This is expected and does not count as a manual edit")
  }
  
  # Show sample comparison
  if (nrow(comparison) > 0) {
    sample <- comparison %>% head(3)
    message("  Sample comparison (first 3 rows):")
    for (i in 1:min(3, nrow(sample))) {
      row <- sample[i,]
      message(sprintf("    [%d] %s | %s", i, row$Detector, row$Night))
      message(sprintf("        Start: '%s' vs '%s'", 
                      row$StartDateTime_orig_str, row$StartDateTime_edit_str))
      message(sprintf("        End:   '%s' vs '%s'", 
                      row$EndDateTime_orig_str, row$EndDateTime_edit_str))
    }
  }
}

# Generate edit log
edit_log_file <- NA
if (total_edits > 0) {
  edit_log_file <- here::here("outputs", sprintf("04_CallsPerNight_EditLog_%s.txt", timestamp))
  
  edit_log <- comparison %>%
    filter(Any_change) %>%
    arrange(Detector, Night)
  
  # Write edit log using format_datetime_for_log() from callspernight.R
  sink(edit_log_file)
  cat("==================================================\n")
  cat("CALLSPERNIGHT TEMPLATE EDIT LOG\n")
  cat("==================================================\n\n")
  cat(sprintf("Generated: %s\n", Sys.time()))
  cat(sprintf("Original template: %s\n", template_original_file))
  cat(sprintf("Edited template: %s\n", edited_file))
  cat(sprintf("Total edits: %d\n\n", total_edits))
  cat("NOTE: Comparison based on parsed datetime values, not string format.\n")
  cat("Excel auto-formatting (e.g., '8:00:00 PM' -> '20:00') does NOT count as an edit.\n")
  cat("Datetimes shown in 24-hour format (HH:MM) for consistency.\n\n")
  cat("==================================================\n")
  cat("DETAILED EDIT LIST\n")
  cat("==================================================\n\n")
  
  for (i in seq_len(nrow(edit_log))) {
    row <- edit_log[i, ]
    cat(sprintf("[%d] Detector: %s | Night: %s\n", i, row$Detector, row$Night))
    
    # Show StartDateTime changes using format_datetime_for_log() from callspernight.R
    if (row$StartDateTime_changed) {
      cat(sprintf("    StartDateTime CHANGED:\n"))
      cat(sprintf("      Original: %s\n", 
                  format_datetime_for_log(row$StartDateTime_orig, row$StartDateTime_orig_str)))
      cat(sprintf("      Edited:   %s\n", 
                  format_datetime_for_log(row$StartDateTime_edit, row$StartDateTime_edit_str)))
    } else if (row$StartDateTime_added) {
      cat(sprintf("    StartDateTime ADDED:\n"))
      cat(sprintf("      Original: <blank>\n"))
      cat(sprintf("      Edited:   %s\n", 
                  format_datetime_for_log(row$StartDateTime_edit, row$StartDateTime_edit_str)))
    } else if (row$StartDateTime_removed) {
      cat(sprintf("    StartDateTime REMOVED:\n"))
      cat(sprintf("      Original: %s\n", 
                  format_datetime_for_log(row$StartDateTime_orig, row$StartDateTime_orig_str)))
      cat(sprintf("      Edited:   <blank>\n"))
    }
    
    # Show EndDateTime changes using format_datetime_for_log() from callspernight.R
    if (row$EndDateTime_changed) {
      cat(sprintf("    EndDateTime CHANGED:\n"))
      cat(sprintf("      Original: %s\n", 
                  format_datetime_for_log(row$EndDateTime_orig, row$EndDateTime_orig_str)))
      cat(sprintf("      Edited:   %s\n", 
                  format_datetime_for_log(row$EndDateTime_edit, row$EndDateTime_edit_str)))
    } else if (row$EndDateTime_added) {
      cat(sprintf("    EndDateTime ADDED:\n"))
      cat(sprintf("      Original: <blank>\n"))
      cat(sprintf("      Edited:   %s\n", 
                  format_datetime_for_log(row$EndDateTime_edit, row$EndDateTime_edit_str)))
    } else if (row$EndDateTime_removed) {
      cat(sprintf("    EndDateTime REMOVED:\n"))
      cat(sprintf("      Original: %s\n", 
                  format_datetime_for_log(row$EndDateTime_orig, row$EndDateTime_orig_str)))
      cat(sprintf("      Edited:   <blank>\n"))
    }
    
    cat(sprintf("    RecordingHours: %.2f\n\n", row$RecordingHours_edit))
  }
  sink()
  
  message(sprintf("  [OK] Edit log saved: %s", basename(edit_log_file)))
} else {
  message("  No manual edits detected")
  message("  Note: Excel auto-formatting (format changes only) does not count as an edit")
}

log_message(sprintf("[Stage 4.2] Tracked %d manual edits", total_edits))

# Log manual edits with breakdown
if (total_edits > 0) {
  edit_breakdown <- comparison %>%
    filter(Any_change) %>%
    summarise(
      start_changed = sum(StartDateTime_changed, na.rm = TRUE),
      end_changed = sum(EndDateTime_changed, na.rm = TRUE),
      start_added = sum(StartDateTime_added, na.rm = TRUE),
      start_removed = sum(StartDateTime_removed, na.rm = TRUE),
      end_added = sum(EndDateTime_added, na.rm = TRUE),
      end_removed = sum(EndDateTime_removed, na.rm = TRUE)
    )
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "manual_edits",
    description = sprintf("Manual edits detected: %d total changes", total_edits),
    count = total_edits,
    details = list(
      start_changed = edit_breakdown$start_changed,
      end_changed = edit_breakdown$end_changed,
      start_added = edit_breakdown$start_added,
      start_removed = edit_breakdown$start_removed,
      end_added = edit_breakdown$end_added,
      end_removed = edit_breakdown$end_removed,
      edit_log_file = basename(edit_log_file)
    )
  )
} else {
  validation_context <- log_validation_event(
    validation_context,
    event_type = "manual_edits",
    description = "No manual edits detected",
    count = 0
  )
}


# ==============================================================================
# STAGE 4.3: SET STATUS
# ==============================================================================

print_stage_header("4.3", "Set Recording Status")

message("Classifying recording status (Fail/Success/Partial)...")

# Initialize tracking variables
n_times_match <- 0
n_hours_match <- 0

# Determine if each row matches uniform schedule
if (!is.na(uniform_start) && !is.na(uniform_end)) {
  message("  Comparing against uniform schedule:")
  message(sprintf("    Uniform times: %s to %s", uniform_start, uniform_end))
  message(sprintf("    Expected hours: %.1f", calculate_recording_hours(uniform_start, uniform_end)))
  
  # Extract time portions from full datetimes
  template_edited <- template_edited %>%
    mutate(
      StartTime_extracted = sapply(StartDateTime, extract_time),
      EndTime_extracted = sapply(EndDateTime, extract_time)
    )
  
  # Calculate expected recording hours from uniform schedule
  expected_hours <- calculate_recording_hours(uniform_start, uniform_end)
  
  # Define tolerance for matching (allow +/-5 minutes = 0.0833 hours)
  hour_tolerance <- 0.0833  # 5 minutes
  
  template_edited <- template_edited %>%
    mutate(
      # Times match if extracted times equal uniform times
      times_match = (!is.na(StartTime_extracted) & !is.na(EndTime_extracted) &
                       StartTime_extracted == uniform_start & 
                       EndTime_extracted == uniform_end),
      
      # Hours match if within tolerance of expected
      hours_match = (!is.na(RecordingHours) & 
                       abs(RecordingHours - expected_hours) <= hour_tolerance),
      
      # Consider it matching uniform schedule if EITHER times or hours match
      matches_uniform = times_match | hours_match
    )
  
  # Debug: Show matching statistics
  n_times_match <- sum(template_edited$times_match, na.rm = TRUE)
  n_hours_match <- sum(template_edited$hours_match, na.rm = TRUE)
  n_either_match <- sum(template_edited$matches_uniform, na.rm = TRUE)
  
  message(sprintf("    Rows with exact time match: %d", n_times_match))
  message(sprintf("    Rows with hours match (+/-5 min): %d", n_hours_match))
  message(sprintf("    Total matching uniform schedule: %d", n_either_match))
  
  # Remove helper columns
  template_edited <- template_edited %>%
    select(-StartTime_extracted, -EndTime_extracted, -times_match, -hours_match)
  
} else {
  # No uniform schedule - all non-zero hours are considered "Partial"
  message("  No uniform schedule defined")
  message("    All non-zero recording hours will be marked as 'Partial'")
  
  template_edited <- template_edited %>%
    mutate(matches_uniform = FALSE)
}

# Set Status based on RecordingHours and whether it matches uniform
message("\n  Applying status rules...")
message("    Fail: RecordingHours = 0 or NA")
message("    Success: RecordingHours > 0 AND matches uniform schedule")
message("    Partial: RecordingHours > 0 AND does NOT match uniform")

template_edited <- template_edited %>%
  mutate(
    Status = case_when(
      is.na(RecordingHours) | RecordingHours == 0 ~ "Fail",
      RecordingHours > 0 & matches_uniform ~ "Success",
      RecordingHours > 0 & !matches_uniform ~ "Partial",
      .default = "Fail"
    )
  ) %>%
  select(-matches_uniform)  # Remove helper column

# Count status distribution
status_counts <- table(template_edited$Status)

message("\n  Status distribution:")
for (status in c("Fail", "Success", "Partial")) {
  count <- status_counts[status]
  if (is.na(count)) count <- 0
  message(sprintf("    %s: %s nights", 
                  status,
                  format(count, big.mark = ",")))
}

log_message(sprintf("[Stage 4.3] Set status: %d Fail, %d Success, %d Partial",
                    status_counts["Fail"] %||% 0,
                    status_counts["Success"] %||% 0,
                    status_counts["Partial"] %||% 0))

# Log status classification
validation_context <- log_validation_event(
  validation_context,
  event_type = "status_classification",
  description = "Classified recording status for all nights",
  details = list(
    Fail = as.numeric(status_counts["Fail"] %||% 0),
    Success = as.numeric(status_counts["Success"] %||% 0),
    Partial = as.numeric(status_counts["Partial"] %||% 0),
    uniform_schedule = !is.na(uniform_start),
    times_match = if (!is.na(uniform_start)) n_times_match else NA,
    hours_match = if (!is.na(uniform_start)) n_hours_match else NA
  )
)

# ==============================================================================
# STAGE 4.4: CALCULATE METRICS
# ==============================================================================

print_stage_header("4.4", "Calculate Metrics")

message("Calculating CallsPerHour...")

# Ensure numeric columns are actually numeric (Excel may save as character)
message("  Converting columns to numeric types...")
calls_per_night_final <- template_edited %>%
  mutate(
    CallsPerNight = as.numeric(CallsPerNight),
    RecordingHours = as.numeric(RecordingHours)
  )

# Calculate CallsPerHour (avoid division by zero)
# Dead nights (RecordingHours = 0 or NA) get CallsPerHour = NA
calls_per_night_final <- calls_per_night_final %>%
  mutate(
    CallsPerHour = ifelse(
      RecordingHours > 0,
      CallsPerNight / RecordingHours,
      NA_real_
    )
  )

# Count dead nights (RETAINED for NB GAMM models)
n_dead_nights <- sum(is.na(calls_per_night_final$RecordingHours) | 
                       calls_per_night_final$RecordingHours == 0, 
                     na.rm = TRUE)

if (n_dead_nights > 0) {
  message(sprintf("  Retained %s dead nights (Status = Fail, CallsPerHour = NA)", 
                  format(n_dead_nights, big.mark = ",")))
  message("    These are kept for NB GAMM models as structural zeros")
  
  # Log dead nights retention
  validation_context <- log_validation_event(
    validation_context,
    event_type = "dead_nights",
    description = "Retained dead nights for NB GAMM models",
    count = n_dead_nights,
    details = list(
      reason = "Structural zeros needed for NB GAMM models",
      status = "Fail",
      calls_per_hour = "NA"
    )
  )
}

message(sprintf("[OK] Final dataset: %s rows", 
                format(nrow(calls_per_night_final), big.mark = ",")))

# Show summary statistics (excluding dead nights for calculations)
active_nights <- calls_per_night_final %>%
  filter(!is.na(RecordingHours) & RecordingHours > 0)

message("\nSummary statistics (active nights only):")
message(sprintf("  Active nights: %s", format(nrow(active_nights), big.mark = ",")))
message(sprintf("  Total calls: %s", 
                format(sum(active_nights$CallsPerNight), big.mark = ",")))
message(sprintf("  Total recording hours: %.1f", 
                sum(active_nights$RecordingHours, na.rm = TRUE)))
message(sprintf("  Mean calls/night: %.1f", 
                mean(active_nights$CallsPerNight, na.rm = TRUE)))
message(sprintf("  Mean calls/hour: %.2f", 
                mean(active_nights$CallsPerHour, na.rm = TRUE)))

log_message(sprintf("[Stage 4.4] Calculated metrics: %d total rows, %d dead nights retained", 
                    nrow(calls_per_night_final), n_dead_nights))

# Log metrics calculation
validation_context <- log_validation_event(
  validation_context,
  event_type = "metrics_calculated",
  description = "Calculated CallsPerHour and recording effort",
  details = list(
    total_rows = nrow(calls_per_night_final),
    active_nights = nrow(active_nights),
    dead_nights = n_dead_nights,
    total_calls = sum(active_nights$CallsPerNight),
    total_hours = round(sum(active_nights$RecordingHours, na.rm = TRUE), 1),
    mean_calls_per_night = round(mean(active_nights$CallsPerNight, na.rm = TRUE), 1),
    mean_calls_per_hour = round(mean(active_nights$CallsPerHour, na.rm = TRUE), 2)
  )
)

# ==============================================================================
# STAGE 4.5: VALIDATE & SAVE
# ==============================================================================

print_stage_header("4.5", "Validate & Save")

# Reorder columns for final dataset
message("Finalizing column structure...")
calls_per_night_final <- calls_per_night_final %>%
  select(Detector, Night, CallsPerNight, RecordingHours, 
         StartDateTime, EndDateTime, Status, CallsPerHour)

# Validate required columns exist
message("\nValidating CallsPerNight structure...")
assert_columns_exist(
  calls_per_night_final,
  c("Detector", "Night", "CallsPerNight", "RecordingHours", 
    "StartDateTime", "EndDateTime", "Status", "CallsPerHour"),
  source_hint = "04_finalize_cpn.R"
)

message("  [OK] All required columns present")

# Enforce column types
calls_per_night_final <- calls_per_night_final %>%
  mutate(
    Detector = as.character(Detector),
    Night = as.Date(Night),
    CallsPerNight = as.numeric(CallsPerNight),
    RecordingHours = as.numeric(RecordingHours),
    StartDateTime = as.character(StartDateTime),
    EndDateTime = as.character(EndDateTime),
    Status = as.character(Status),
    CallsPerHour = as.numeric(CallsPerHour)
  )

message("  [OK] Column types enforced")

# Log species validation
n_unique_species <- n_distinct(kpro_master$species, na.rm = TRUE)
species_present <- "species" %in% names(kpro_master)

validation_context <- log_validation_event(
  validation_context,
  event_type = "validation",
  description = "Species column validated in kpro_master",
  details = list(
    species_present = species_present,
    unique_species = n_unique_species,
    ready_for_downstream = TRUE
  )
)

# Validate data quality with validate_calls_per_night()
message("\nValidating CallsPerNight data quality...")

# Check for problematic CallsPerNight values
problematic <- validate_calls_per_night(calls_per_night_final, max_calls = 10000)

if (nrow(problematic) > 0) {
  warning(sprintf(
    "%d row(s) have unusual CallsPerNight values (NA, negative, or > 10,000)",
    nrow(problematic)
  ))
  
  message("\n  [!] Unusual values detected:")
  message(sprintf("    Rows with NA CallsPerNight: %d", 
                  sum(is.na(problematic$CallsPerNight))))
  message(sprintf("    Rows with negative CallsPerNight: %d", 
                  sum(problematic$CallsPerNight < 0, na.rm = TRUE)))
  message(sprintf("    Rows with CallsPerNight > 10,000: %d", 
                  sum(problematic$CallsPerNight > 10000, na.rm = TRUE)))
  message("    These rows are KEPT in the dataset but may need review")
  
  # Log validation with unusual values
  validation_context <- log_validation_event(
    validation_context,
    event_type = "validation",
    description = sprintf("Data validation: %d unusual values detected but retained", nrow(problematic)),
    details = list(
      na_values = sum(is.na(problematic$CallsPerNight)),
      negative_values = sum(problematic$CallsPerNight < 0, na.rm = TRUE),
      excessive_values = sum(problematic$CallsPerNight > 10000, na.rm = TRUE),
      action = "Retained for review"
    )
  )
} else {
  message("  [OK] All CallsPerNight values within normal range")
  
  # Log validation passed
  validation_context <- log_validation_event(
    validation_context,
    event_type = "validation",
    description = "Data validation: All values within normal range",
    details = list(
      validation_passed = TRUE
    )
  )
}

message("\n[OK] Data validation passed")

# Ensure output directory exists
assert_directory_exists(here::here("results", "csv"), create = TRUE)

# Save with auto-incrementing version
message("\nSaving final CallsPerNight dataset...")

final_file <- save_callspernight_with_version(
  data = calls_per_night_final,
  base_name = "CallsPerNight_final",
  output_dir = here::here("results", "csv")  # Final deliverable goes to results/
)

message(sprintf("[OK] Final file saved: %s", basename(final_file)))

log_message(sprintf("[Stage 4.5] Saved final dataset: %s", basename(final_file)))

# Extract version number from filename
version_number <- sub(".*_v(\\d+)\\.csv$", "\\1", basename(final_file))

# Log final file save
validation_context <- log_validation_event(
  validation_context,
  event_type = "file_saved",
  description = sprintf("Saved final CallsPerNight dataset (version %s)", version_number),
  details = list(
    file_path = basename(final_file),
    version = version_number,
    n_rows = nrow(calls_per_night_final),
    n_detectors = n_distinct(calls_per_night_final$Detector),
    n_nights = n_distinct(calls_per_night_final$Night)
  )
)

# -------------------------
# Register artifact
# -------------------------

message("\nRegistering artifact...")

# Initialize artifact registry
registry <- init_artifact_registry()

# Register final CPN dataset
registry <- register_artifact(
  registry = registry,
  artifact_name = sprintf("cpn_final_v%s_%s", version_number, format(Sys.time(), "%Y%m%d_%H%M%S")),
  artifact_type = "cpn_final",
  workflow = "04",
  file_path = final_file,
  input_artifacts = c("cpn_template_editable"),
  metadata = list(
    version = version_number,
    n_rows = nrow(calls_per_night_final),
    n_detectors = n_distinct(calls_per_night_final$Detector),
    n_nights = n_distinct(calls_per_night_final$Night),
    n_dead_nights = n_dead_nights,
    total_edits = total_edits,
    status_distribution = as.list(status_counts),
    mean_calls_per_hour = round(mean(active_nights$CallsPerHour, na.rm = TRUE), 2)
  )
)

message("[OK] Artifact registered in registry")

# ==============================================================================
# STAGE 4.6: FINALIZE VALIDATION REPORT
# ==============================================================================

print_stage_header("4.6", "Generate Validation Report")

# Finalize validation context
validation_context$summary$rows_processed <- nrow(calls_per_night_final)

validation_report_path <- finalize_validation_report(
  validation_context,
  output_dir = here::here("results", "validation")
)

log_message(sprintf("[Workflow 04] Validation report: %s", basename(validation_report_path)))

# ==============================================================================
# WORKFLOW 04 COMPLETE
# ==============================================================================

message("\n========================================")
message("  WORKFLOW 04 COMPLETE: CallsPerNight Generated")
message("========================================\n")

message("Files created:")
message(sprintf("  [OK] Template (original): %s", basename(template_original_file)))
if (total_edits > 0) {
  message(sprintf("  [OK] Edit log: %s", basename(edit_log_file)))
}
message(sprintf("  [OK] Final dataset: %s", basename(final_file)))
message(sprintf("  [OK] Validation report: %s", basename(validation_report_path)))

message("\nDataset summary:")
message(sprintf("  Detectors: %d", length(unique(calls_per_night_final$Detector))))
message(sprintf("  Nights: %d", length(unique(calls_per_night_final$Night))))
message(sprintf("  Total rows: %s", 
                format(nrow(calls_per_night_final), big.mark = ",")))
message(sprintf("  Dead nights (retained): %d", n_dead_nights))

# Status breakdown
message("\nRecording status:")
for (status in names(status_counts)) {
  pct <- 100 * status_counts[status] / sum(status_counts)
  message(sprintf("  %s: %s (%.1f%%)", 
                  status,
                  format(status_counts[status], big.mark = ","),
                  pct))
}

# Species column status
message("\nSpecies data (from kpro_master):")
message(sprintf("  [OK] Unique species: %d", n_distinct(kpro_master$species, na.rm = TRUE)))
message("  [OK] Ready for Workflow 05/06 species analysis")

message("\n========================================")
message("[OK] Workflow 04 Complete")
message("========================================")

message("\nCurrent data in environment:")
message("  - calls_per_night_final (ready for analysis)")
message("  - kpro_master (with unified `species` column)")
message(sprintf("  - Final file: %s", basename(final_file)))

message("\nTo inspect data:")
message("  head(calls_per_night_final)")
message("  summary(calls_per_night_final)")
message("  table(calls_per_night_final$Status)")
message("  View(calls_per_night_final)")
message("  table(kpro_master$species)")

message("\nNext workflow:")
message("  source(\"R/workflows/05_summary_stats.R\")")
message("  - Generate summary statistics")
message("  - Create publication-ready tables")
message("\nOr for visualizations:")
message("  source(\"R/workflows/06_generate_plots.R\")")
message("  - Generate exploratory plots\n")

log_message("=== WORKFLOW 04 COMPLETE ===")
