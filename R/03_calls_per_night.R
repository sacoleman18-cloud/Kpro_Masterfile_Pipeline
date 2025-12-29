# ==============================================================================
# MAINLINE WORKFLOW: 03_calls_per_night.R
# ==============================================================================
# PURPOSE
# -------
# Generate CallsPerNight template for manual recording hour adjustments, track
# edits, calculate metrics, and produce final CallsPerNight dataset for analysis.
# Handles equipment failures, SD card issues, recording schedule variations, and
# manual species identification workflows.
#
# WORKFLOW POSITION
# -----------------
# This is Workflow 03 in the processing pipeline:
#   01_ingest_raw_data.R  â†’ Load & intro-standardize raw CSVs
#   02_standardize.R      â†’ Transform to master schema
#   [OPTIONAL: Manual ID in Kaleidoscope]
#   03_calls_per_night.R  â†’ [THIS SCRIPT] Aggregate to nightly metrics
#
# INPUTS
# ------
# In Memory:
#   - kpro_master (from Workflow 02)
#
# OR File Import (if manually ID'd):
#   - User-selected CSV with manual_id column populated
#   - Selected via file.choose() dialog
#
# User-Edited File:
#   - outputs/03_CallsPerNight_Template_ORIGINAL_YYYYMMDD_HHMMSS.csv (after manual editing)
#
# MANUAL ID WORKFLOW (OPTIONAL)
# ------------------------------
# Users may manually review calls in Kaleidoscope Pro before running this workflow:
#
# 1. Run Workflow 02 â†’ produces kpro_master.csv
# 2. Load kpro_master.csv into Kaleidoscope Pro
# 3. Manually review calls, populate manual_id column
# 4. Save updated file
# 5. Run Workflow 03 â†’ import manually-ID'd file when prompted
#
# If manual ID was performed:
#   - NoID calls WITH manual_id values are KEPT (user confirmed species)
#   - NoID calls WITHOUT manual_id values are REMOVED (truly unidentifiable)
#
# If manual ID was NOT performed:
#   - All NoID calls are REMOVED (assumed unidentifiable)
#
# PROCESSING STAGES
# -----------------
# Stage 3.0: Manual ID Check & Import (OPTIONAL)
#   - Prompts if user manually ID'd calls in Kaleidoscope
#   - If YES: file.choose() to select manually-ID'd file
#   - Validates structure and loads as kpro_master
#   - If NO: Continue to normal loading workflow
#
# Stage 3.1: Load & Validate Data
#   - Checks for kpro_master in memory (from Stage 3.0 OR Workflow 02)
#   - Falls back to checkpoint loading if not in memory
#   - Validates required columns exist
#   - Adds manual_id column if missing (for consistency)
#
# Stage 3.2: Calculate Study Nights
#   - Applies study night logic (calls before noon â†’ previous date)
#   - Aggregates CallsPerNight by Detector Ã— Night
#
# Stage 3.3: Define Recording Period
#   - Prompts user for project start/end dates
#   - Prompts for uniform start/end times (or custom schedule)
#
# Stage 3.4: Generate Template
#   - Filters NoID calls (Option B: remove only if manual_id is NA)
#   - Creates Detector Ã— Night grid for full recording period
#   - Pre-fills uniform times if provided
#   - Adds Excel formula for RecordingHours
#   - Saves as _ORIGINAL for comparison
#
# Stage 3.5: User Manual Editing
#   - Pauses for user to edit template in Excel
#   - User adjusts StartTime/EndTime for failed nights, SD card issues, etc.
#   - User saves edited file
#
# Stage 3.6: Load Edited Template
#   - Prompts user for edited file path
#   - Validates structure
#   - Recalculates RecordingHours from edited times
#
# Stage 3.7: Track Edits
#   - Compares ORIGINAL vs EDITED
#   - Generates detailed edit log
#   - Logs all manual adjustments
#
# Stage 3.8: Set Status
#   - Fail: RecordingHours == 0 or NA
#   - Success: RecordingHours > 0 AND matches uniform times
#   - Partial: RecordingHours > 0 AND manually adjusted
#
# Stage 3.9: Calculate Metrics
#   - CallsPerHour = CallsPerNight / RecordingHours
#   - Removes "dead nights" (NA recording hours)
#
# Stage 3.10: Validate & Save
#   - Validates master schema (enforce_master_schema)
#   - Saves with auto-incrementing version (v1, v2, v3...)
#
# OUTPUTS
# -------
# Files Created:
#   - outputs/03_CallsPerNight_Template_ORIGINAL_YYYYMMDD_HHMMSS.csv (template for editing)
#   - outputs/03_CallsPerNight_EditLog_YYYYMMDD_HHMMSS.txt (edit tracking)
#   - outputs/03_CallsPerNight_Final_vX.csv (final versioned dataset)
#   - logs/workflow_log_YYYYMMDD.txt (processing log)
#
# In Memory:
#   - calls_per_night_final (ready for analysis)
#
# STUDY NIGHT LOGIC
# -----------------
# Bat acoustic studies use "study nights" that span calendar day boundaries:
#
# Rule: Calls before noon (00:00:00 - 11:59:59) belong to PREVIOUS calendar day
#
# Examples:
#   DateTime: 2024-10-25 22:30:00 â†’ Night: 2024-10-25 (same day)
#   DateTime: 2024-10-26 03:15:00 â†’ Night: 2024-10-25 (previous day)
#   DateTime: 2024-10-26 12:00:00 â†’ Night: 2024-10-26 (same day)
#
# This matches typical recording schedules (sunset to sunrise).
#
# RECORDING HOURS CALCULATION
# ----------------------------
# Handles overnight recordings correctly:
#
# Excel Formula: =IF(EndTime<StartTime, (1-StartTime)+EndTime, EndTime-StartTime)*24
#
# Examples:
#   StartTime: 20:00, EndTime: 06:00 â†’ 10 hours (crosses midnight)
#   StartTime: 18:00, EndTime: 08:00 â†’ 14 hours (crosses midnight)
#   StartTime: 06:00, EndTime: 18:00 â†’ 12 hours (same day)
#
# STATUS VALUES
# -------------
# Three possible statuses for each night:
#
# 1. "Fail" - Equipment failure or no recording
#    - RecordingHours == 0
#    - RecordingHours is NA
#    - StartTime or EndTime missing
#
# 2. "Success" - Full recording as scheduled
#    - RecordingHours > 0
#    - Matches uniform start/end times (if uniform schedule used)
#    - No manual adjustments needed
#
# 3. "Partial" - Reduced recording (equipment issue, SD card full, etc.)
#    - RecordingHours > 0
#    - Manually adjusted from uniform schedule
#    - User edited StartTime or EndTime in template
#
# MANUAL EDITING WORKFLOW
# ------------------------
# Users edit the template CSV in Excel to account for:
#   - Equipment failures (set RecordingHours to 0)
#   - SD card full (adjust EndTime to when card filled)
#   - Late deployment (adjust StartTime)
#   - Early retrieval (adjust EndTime)
#   - Power issues (adjust times or set to 0)
#
# All manual edits are tracked and logged for reproducibility.
#
# TEMPLATE STRUCTURE
# ------------------
# Initial template columns (ORIGINAL):
#   Detector       - Friendly detector name (e.g., "SMO", "LPE")
#   detector_id    - 16-character hardware ID
#   Night          - Study night date (YYYY-MM-DD)
#   CallsPerNight  - Count of calls detected (0 if none)
#   StartTime      - Recording start time (HH:MM:SS) - USER EDITABLE
#   EndTime        - Recording end time (HH:MM:SS) - USER EDITABLE
#   RecordingHours - Excel formula (auto-calculates from Start/End)
#
# After editing (EDITED):
#   Same structure, but StartTime/EndTime may be modified
#   RecordingHours recalculated based on edits
#
# Final dataset (FINAL):
#   Adds Status column (Fail/Success/Partial)
#   Adds CallsPerHour metric
#   Removes nights with NA RecordingHours
#
# PERFORMANCE EXPECTATIONS
# -------------------------
# Typical bat acoustic datasets:
#
# Small study (3 detectors, 30 nights):
#   - Template rows: ~90
#   - Edit time: 5-10 minutes
#   - Processing: < 30 seconds
#
# Medium study (10 detectors, 90 nights):
#   - Template rows: ~900
#   - Edit time: 20-30 minutes
#   - Processing: < 1 minute
#
# Large study (20+ detectors, 180 nights):
#   - Template rows: 3,600+
#   - Edit time: 1-2 hours
#   - Processing: 1-2 minutes
#
# DEPENDENCIES
# ------------
# R Packages:
#   - tidyverse (dplyr, readr, purrr)
#   - lubridate (date/time calculations)
#   - hms (time parsing)
#
# Custom Functions (via load_all.R):
#   - core/utilities.R: log_message, safe_read_csv
#   - analysis/callspernight.R: calculate_recording_hours, 
#                                  generate_calls_per_night_template,
#                                  apply_schedule,
#                                  save_callspernight_with_version
#   - validation/validation.R: enforce_master_schema
#
# TROUBLESHOOTING
# ---------------
# Issue: "kpro_master not found"
# Fix: Run Workflow 02 first, or load checkpoint manually
#
# Issue: "Invalid date format"
# Fix: Enter dates as YYYY-MM-DD (e.g., 2024-05-01)
#
# Issue: "Invalid time format"  
# Fix: Enter times as HH:MM:SS in 24-hour format (e.g., 20:00:00)
#
# Issue: Excel formula not calculating
# Fix: Ensure Excel is set to auto-calculate formulas (File â†’ Options â†’ Formulas)
#
# Issue: Edited template rejected
# Fix: Verify column names match original template exactly
#
# USAGE EXAMPLES
# --------------
# # Run after Workflow 02:
# source("R/workflows/02_standardize.R")
# source("R/workflows/03_calls_per_night.R")
#
# # Run standalone (loads kpro_master from checkpoint):
# source("R/workflows/03_calls_per_night.R")
#
# # Inspect results:
# head(calls_per_night_final)
# table(calls_per_night_final$Status)
# summary(calls_per_night_final$CallsPerHour)
#
# MAINTAINER NOTES
# ----------------
# - ASCII boxes: Single-line (â”Œâ”€â”) for all stages
# - Stage numbering: 3.0 - 3.10 (3.0 is optional manual ID import)
# - Always save _ORIGINAL before user edits
# - Edit log critical for reproducibility
# - Status classification must be deterministic
# - NoID filtering uses Option B logic (keep if manual_id present)
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
library(hms)

# ------------------------------------------------------------------------------
# Initialize logging
# ------------------------------------------------------------------------------

log_message("=== WORKFLOW 03: Generate CallsPerNight ===")

# ==============================================================================
# STAGE 3.0: MANUAL ID CHECK & IMPORT
# ==============================================================================

message("\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”")
message("â”‚          STAGE 3.0: Manual ID Check & Import                   â”‚")
message("â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n")

message("MANUAL SPECIES IDENTIFICATION")
message(strrep("â”€", 66))
message("\nHave you manually reviewed and identified calls in Kaleidoscope Pro?")
message("(This step is optional but improves species identification accuracy)\n")

manual_id_response <- tolower(trimws(readline("Manually ID'd calls? (y/n): ")))

if (manual_id_response == "y") {
  message("\nâœ“ Manual ID workflow detected")
  message("\nPlease select your manually-ID'd master file...")
  message("(A file chooser dialog will open)\n")
  
  # Small delay so user can read the message
  Sys.sleep(1)
  
  # Open file chooser
  manual_id_file <- tryCatch({
    file.choose()
  }, error = function(e) {
    stop("File selection cancelled or failed")
  })
  
  message(sprintf("  Selected: %s", basename(manual_id_file)))
  
  # Load manually-ID'd file
  message("\n  Loading manually-ID'd data...")
  kpro_master <- safe_read_csv(manual_id_file)
  
  if (is.null(kpro_master)) {
    stop("Failed to load manually-ID'd file")
  }
  
  # Validate required columns
  required_cols <- c("Detector", "detector_id", "DateTime", "auto_id", "manual_id")
  missing <- setdiff(required_cols, names(kpro_master))
  
  if (length(missing) > 0) {
    stop(sprintf("Manually-ID'd file missing required columns: %s\n  Did you export from Kaleidoscope with all columns?", 
                 paste(missing, collapse = ", ")))
  }
  
  # Check if Night column exists, calculate if missing
  if (!"Night" %in% names(kpro_master)) {
    message("  Calculating Night column (not present in file)...")
    kpro_master <- kpro_master %>%
      mutate(
        Night = if_else(
          hour(DateTime) < 12,
          as.Date(DateTime) - 1,
          as.Date(DateTime)
        )
      )
  }
  
  message(sprintf("âœ“ Loaded manually-ID'd data: %s rows", 
                  format(nrow(kpro_master), big.mark = ",")))
  
  # Count manual IDs
  manual_id_count <- sum(!is.na(kpro_master$manual_id), na.rm = TRUE)
  manual_id_pct <- 100 * manual_id_count / nrow(kpro_master)
  
  message(sprintf("  Manual IDs: %s rows (%.1f%%)", 
                  format(manual_id_count, big.mark = ","),
                  manual_id_pct))
  
  log_message(sprintf("[Stage 3.0] Loaded manually-ID'd file: %s rows, %d manual IDs",
                      nrow(kpro_master), manual_id_count))
  
} else {
  message("\nâœ“ No manual ID - will use auto_id only")
  message("  (NoID calls will be removed during template generation)")
  
  log_message("[Stage 3.0] No manual ID workflow - using auto_id only")
}

# ==============================================================================
# STAGE 3.1: LOAD & VALIDATE DATA
# ==============================================================================

message("\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”")
message("â”‚          STAGE 3.1: Load & Validate Data                       â”‚")
message("â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n")

# Check if kpro_master exists in memory (from Stage 3.0 OR Workflow 02)
if (exists("kpro_master")) {
  message("âœ“ Using kpro_master from memory")
  message(sprintf("  Rows: %s", format(nrow(kpro_master), big.mark = ",")))
  
} else {
  # Load most recent kpro_master checkpoint
  message("kpro_master not found in memory - loading from checkpoint...")
  
  checkpoint_files <- list.files("outputs", 
                                 pattern = "^02_kpro_master_.*\\.csv$",
                                 full.names = TRUE)
  
  if (length(checkpoint_files) == 0) {
    stop("No kpro_master checkpoint found. Please run 02_standardize.R first.")
  }
  
  # Get most recent checkpoint
  checkpoint_file <- checkpoint_files[order(file.mtime(checkpoint_files), decreasing = TRUE)][1]
  
  message(sprintf("  Loading: %s", basename(checkpoint_file)))
  
  kpro_master <- safe_read_csv(checkpoint_file)
  
  if (is.null(kpro_master)) {
    stop("Failed to load kpro_master checkpoint")
  }
  
  message(sprintf("âœ“ Loaded checkpoint: %s rows", format(nrow(kpro_master), big.mark = ",")))
}

# Validate required columns (manual_id may or may not be present)
required_cols <- c("Detector", "detector_id", "DateTime", "auto_id")
missing <- setdiff(required_cols, names(kpro_master))

if (length(missing) > 0) {
  stop(sprintf("kpro_master missing required columns: %s", 
               paste(missing, collapse = ", ")))
}

# Add manual_id column if it doesn't exist (for consistency)
if (!"manual_id" %in% names(kpro_master)) {
  message("  Note: manual_id column not present (no manual IDs performed)")
  kpro_master <- kpro_master %>%
    mutate(manual_id = NA_character_)
}

message("âœ“ All required columns present")

log_message(sprintf("[Stage 3.1] Loaded kpro_master: %s rows", nrow(kpro_master)))

# ==============================================================================
# STAGE 3.2: CALCULATE STUDY NIGHTS
# ==============================================================================

message("\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”")
message("â”‚          STAGE 3.2: Calculate Study Nights                     â”‚")
message("â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n")

message("Applying study night logic...")
message("  Rule: Calls before 12:00:00 â†’ previous calendar day")

# Calculate Night column
kpro_master <- kpro_master %>%
  mutate(
    Night = if_else(
      hour(DateTime) < 12,
      as.Date(DateTime) - 1,  # Before noon = previous night
      as.Date(DateTime)        # After noon = same night
    )
  )

message("âœ“ Study nights calculated")

# Show date range
night_range <- range(kpro_master$Night, na.rm = TRUE)
message(sprintf("  Night range: %s to %s", night_range[1], night_range[2]))
message(sprintf("  Total nights: %d", 
                as.numeric(diff(night_range)) + 1))

# Aggregate CallsPerNight
message("\nAggregating CallsPerNight...")

calls_per_night <- kpro_master %>%
  group_by(Detector, detector_id, Night) %>%
  summarise(CallsPerNight = n(), .groups = "drop")

message(sprintf("âœ“ Aggregated to %s DetectorÃ—Night combinations", 
                format(nrow(calls_per_night), big.mark = ",")))

log_message(sprintf("[Stage 3.2] Calculated %d detector-night combinations", 
                    nrow(calls_per_night)))

# ==============================================================================
# STAGE 3.3: DEFINE RECORDING PERIOD
# ==============================================================================

message("\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”")
message("â”‚          STAGE 3.3: Define Recording Period                    â”‚")
message("â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n")

message("Please define the project recording period.")
message("This should span ALL nights detectors were deployed,")
message("including nights with equipment failures.\n")

# Prompt for dates
start_date_input <- readline("Project start date (YYYY-MM-DD): ")
end_date_input   <- readline("Project end date (YYYY-MM-DD): ")

start_date <- as.Date(start_date_input)
end_date   <- as.Date(end_date_input)

# Validate dates
if (is.na(start_date) || is.na(end_date)) {
  stop("Invalid dates. Please use YYYY-MM-DD format (e.g., 2024-05-01)")
}

if (end_date < start_date) {
  stop("End date must be after start date")
}

total_nights <- as.numeric(end_date - start_date) + 1

message(sprintf("\nâœ“ Recording period: %s to %s (%d nights)", 
                start_date, end_date, total_nights))

# Prompt for uniform recording schedule
message("\n" %+% strrep("â”€", 66))
message("RECORDING SCHEDULE")
message(strrep("â”€", 66))
message("\nDo all nights have the same start and end times?")
message("(e.g., All detectors recorded 20:00 to 08:00 every night)\n")

uniform_response <- tolower(trimws(readline("Uniform schedule? (y/n): ")))

if (uniform_response == "y") {
  message("\nEnter uniform recording times (24-hour format):")
  uniform_start <- trimws(readline("  Start time (HH:MM:SS, e.g., 20:00:00): "))
  uniform_end   <- trimws(readline("  End time (HH:MM:SS, e.g., 08:00:00): "))
  
  # Validate time format
  if (!grepl("^\\d{2}:\\d{2}:\\d{2}$", uniform_start) || 
      !grepl("^\\d{2}:\\d{2}:\\d{2}$", uniform_end)) {
    stop("Invalid time format. Please use HH:MM:SS (e.g., 20:00:00)")
  }
  
  message(sprintf("\nâœ“ Uniform schedule: %s to %s", uniform_start, uniform_end))
  
  # Calculate expected recording hours
  expected_hours <- calculate_recording_hours(uniform_start, uniform_end)
  message(sprintf("  Recording hours per night: %.1f", expected_hours))
  
} else {
  message("\nNo uniform schedule - all times will need manual entry")
  uniform_start <- NA
  uniform_end <- NA
}

log_message(sprintf("[Stage 3.3] Recording period: %s to %s (%d nights)", 
                    start_date, end_date, total_nights))

# ==============================================================================
# STAGE 3.4: GENERATE TEMPLATE
# ==============================================================================

message("\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”")
message("â”‚          STAGE 3.4: Generate Template                          â”‚")
message("â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n")

# -------------------------
# Remove NoID calls without manual identification
# -------------------------

message("Filtering NoID calls...")

n_before_filter <- nrow(kpro_master)

# Option B: Remove NoID only if manual_id is also NA
# Keep NoID if user manually identified it
kpro_master_filtered <- kpro_master %>%
  filter(!(auto_id %in% c("NoID", "UNKNOWN") & is.na(manual_id)))

n_removed <- n_before_filter - nrow(kpro_master_filtered)

if (n_removed > 0) {
  message(sprintf("  Removed %s NoID calls without manual identification", 
                  format(n_removed, big.mark = ",")))
  
  # Show breakdown if manual IDs are present
  if (any(!is.na(kpro_master$manual_id))) {
    n_noid_kept <- sum(kpro_master$auto_id %in% c("NoID", "UNKNOWN") & 
                         !is.na(kpro_master$manual_id), na.rm = TRUE)
    if (n_noid_kept > 0) {
      message(sprintf("  Kept %s NoID calls WITH manual identification", 
                      format(n_noid_kept, big.mark = ",")))
    }
  }
} else {
  message("  No NoID calls to remove")
}

message(sprintf("  Remaining calls: %s", 
                format(nrow(kpro_master_filtered), big.mark = ",")))

# Use filtered data for template generation
kpro_master <- kpro_master_filtered

log_message(sprintf("[Stage 3.4] Filtered %d NoID calls", n_removed))

# -------------------------
# Generate template
# -------------------------

message("\nCreating CallsPerNight template...")

# Generate template using existing function
# IMPORTANT: Pass kpro_master (raw data), not calls_per_night (aggregated)
# The function needs raw data to count correctly
template <- generate_calls_per_night_template(
  master_data = kpro_master,  # Pass raw data with Night column
  start_date = as.character(start_date),
  end_date = as.character(end_date),
  uniform_start = uniform_start,
  uniform_end = uniform_end
)

message(sprintf("âœ“ Template created: %s rows", 
                format(nrow(template), big.mark = ",")))

# Remove Warning column (not needed in final template)
if ("Warning" %in% names(template)) {
  template <- template %>% select(-Warning)
}

# Remove detector_id if present (keep only Detector for template)
if ("detector_id" %in% names(template)) {
  template <- template %>% select(-detector_id)
}

# Reorder columns: Detector, Night, CallsPerNight, StartTime, EndTime, RecordingHours
# This maps to Excel columns: A, B, C, D, E, F
template <- template %>%
  select(Detector, Night, CallsPerNight, StartTime, EndTime, RecordingHours)

# Sort by Detector (alphabetical), then Night (chronological)
# This groups all nights for each detector together
template <- template %>%
  arrange(Detector, Night)

# Replace RecordingHours with Excel formula
# Column references: D=StartTime, E=EndTime, F=RecordingHours
# Formula must use relative references that update for each row
template <- template %>%
  mutate(
    # Create row-aware formula (starts at row 2, first data row after header)
    row_num = row_number() + 1,  # +1 because row 1 is header
    RecordingHours = ifelse(
      !is.na(StartTime) & !is.na(EndTime),
      sprintf("=IF(E%d<D%d, (1-D%d)+E%d, E%d-D%d)*24", 
              row_num, row_num, row_num, row_num, row_num, row_num),
      NA_character_
    )
  ) %>%
  select(-row_num)  # Remove helper column

# Save as _ORIGINAL for comparison
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
template_original_file <- sprintf("outputs/03_CallsPerNight_Template_ORIGINAL_%s.csv", 
                                  timestamp)

# Add instructions as first row (will appear above header in Excel)
# IMPORTANT: Match data types with template columns
instructions <- tibble(
  Detector = "INSTRUCTIONS: Edit StartTime/EndTime for equipment failures. RecordingHours auto-calculates. Delete this row when done.",
  Night = as.Date(NA),  # Must be Date type to match template
  CallsPerNight = NA_integer_,  # Integer to match
  StartTime = NA_character_,
  EndTime = NA_character_,
  RecordingHours = NA_character_
)

template_with_instructions <- bind_rows(instructions, template)

write_csv(template_with_instructions, template_original_file)

message(sprintf("âœ“ Template saved: %s", basename(template_original_file)))

# Show summary
detectors_count <- length(unique(template$Detector))
nights_count <- length(unique(template$Night))

message("\nTemplate summary:")
message(sprintf("  Detectors: %d", detectors_count))
message(sprintf("  Nights: %d", nights_count))
message(sprintf("  Total rows: %s", format(nrow(template), big.mark = ",")))

# Show detector grouping info
message("\nDetector grouping:")
detector_row_counts <- template %>%
  group_by(Detector) %>%
  summarise(nights = n(), .groups = "drop") %>%
  arrange(Detector)

for (i in seq_len(min(5, nrow(detector_row_counts)))) {
  message(sprintf("  %s: %d nights", 
                  detector_row_counts$Detector[i],
                  detector_row_counts$nights[i]))
}

if (nrow(detector_row_counts) > 5) {
  message(sprintf("  ... and %d more detectors", nrow(detector_row_counts) - 5))
}

message("\nâœ“ Template organized: All nights for each detector grouped together")

log_message(sprintf("[Stage 3.4] Generated template: %d rows", nrow(template)))

# ==============================================================================
# STAGE 3.5: USER MANUAL EDITING
# ==============================================================================

message("\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”")
message("â”‚          STAGE 3.5: Manual Editing Instructions                â”‚")
message("â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n")

message(strrep("=", 66))
message("USER ACTION REQUIRED")
message(strrep("=", 66))

message("\n1. Open this file in Excel:")
message(sprintf("   %s", template_original_file))

message("\n2. Template organization:")
message("   - Rows are grouped by Detector (all nights for each detector together)")
message("   - Nights are sorted chronologically within each detector")
message("   - Delete the instruction row at the top")

message("\n3. Edit StartTime and EndTime for nights with equipment issues:")
message("   - Equipment failure: Set both times to blank (delete values)")
message("   - SD card full: Adjust EndTime to when card filled")
message("   - Late deployment: Adjust StartTime")
message("   - Early retrieval: Adjust EndTime")

message("\n4. RecordingHours will auto-calculate from your edits")
message("   - Formula: =IF(E2<D2, (1-D2)+E2, E2-D2)*24")
message("   - Handles overnight recordings automatically")

message("\n5. Save the edited file (keep same filename or save as new)")

message("\n6. Return here and press Enter when ready to continue...")

message(strrep("=", 66))

# Pause for user editing
readline("\nPress Enter when you've finished editing the template...")

log_message("[Stage 3.5] User completed manual editing")

# ==============================================================================
# STAGE 3.6: LOAD EDITED TEMPLATE
# ==============================================================================

message("\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”")
message("â”‚          STAGE 3.6: Load Edited Template                       â”‚")
message("â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n")

message("Please provide the path to your edited template:")
message("(Press Enter to use the original filename if you edited in place)\n")

edited_file_input <- trimws(readline("Edited file path: "))

# Use original file if no input provided
if (edited_file_input == "") {
  edited_file <- template_original_file
  message("  Using original file (edited in place)")
} else {
  edited_file <- edited_file_input
}

# Validate file exists
if (!file.exists(edited_file)) {
  stop(sprintf("File not found: %s", edited_file))
}

message(sprintf("  Loading: %s", basename(edited_file)))

# Load edited template
template_edited <- safe_read_csv(edited_file)

if (is.null(template_edited)) {
  stop("Failed to load edited template")
}

# Remove instruction row if user forgot to delete it
if (nrow(template_edited) > 0 && 
    !is.na(template_edited$Detector[1]) && 
    grepl("INSTRUCTIONS:", template_edited$Detector[1], ignore.case = TRUE)) {
  message("  Removing instruction row...")
  template_edited <- template_edited[-1, ]
}

# Validate structure (detector_id should NOT be present)
required_template_cols <- c("Detector", "Night", "CallsPerNight",
                            "StartTime", "EndTime", "RecordingHours")
missing_template_cols <- setdiff(required_template_cols, names(template_edited))

if (length(missing_template_cols) > 0) {
  stop(sprintf("Edited template missing columns: %s", 
               paste(missing_template_cols, collapse = ", ")))
}

# Remove detector_id if user added it back
if ("detector_id" %in% names(template_edited)) {
  message("  Removing detector_id column (not needed)...")
  template_edited <- template_edited %>% select(-detector_id)
}

message("âœ“ Template structure validated")

# Recalculate RecordingHours from edited times
message("\nRecalculating RecordingHours from edited StartTime/EndTime...")

template_edited <- template_edited %>%
  mutate(
    RecordingHours = mapply(calculate_recording_hours, StartTime, EndTime)
  )

message(sprintf("âœ“ Recalculated RecordingHours for %s rows", 
                format(nrow(template_edited), big.mark = ",")))

log_message(sprintf("[Stage 3.6] Loaded edited template: %d rows", 
                    nrow(template_edited)))

# ==============================================================================
# STAGE 3.7: TRACK EDITS
# ==============================================================================

message("\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”")
message("â”‚          STAGE 3.7: Track Manual Edits                         â”‚")
message("â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n")

message("Comparing ORIGINAL vs EDITED templates...")

# Join original and edited for comparison (without detector_id)
comparison <- template %>%
  select(Detector, Night, 
         StartTime_orig = StartTime,
         EndTime_orig = EndTime) %>%
  inner_join(
    template_edited %>%
      select(Detector, Night,
             StartTime_edit = StartTime,
             EndTime_edit = EndTime,
             RecordingHours_edit = RecordingHours),
    by = c("Detector", "Night")
  ) %>%
  mutate(
    StartTime_changed = !identical(StartTime_orig, StartTime_edit),
    EndTime_changed = !identical(EndTime_orig, EndTime_edit),
    Any_change = StartTime_changed | EndTime_changed
  )

# Count edits
total_edits <- sum(comparison$Any_change, na.rm = TRUE)

message(sprintf("  Total manual edits: %d", total_edits))

# Generate edit log
if (total_edits > 0) {
  edit_log_file <- sprintf("outputs/03_CallsPerNight_EditLog_%s.txt", timestamp)
  
  edit_log <- comparison %>%
    filter(Any_change) %>%
    arrange(Detector, Night)
  
  # Write edit log
  sink(edit_log_file)
  cat("==================================================\n")
  cat("CALLSPERNIGHT TEMPLATE EDIT LOG\n")
  cat("==================================================\n\n")
  cat(sprintf("Generated: %s\n", Sys.time()))
  cat(sprintf("Original template: %s\n", template_original_file))
  cat(sprintf("Edited template: %s\n", edited_file))
  cat(sprintf("Total edits: %d\n\n", total_edits))
  cat("==================================================\n")
  cat("DETAILED EDIT LIST\n")
  cat("==================================================\n\n")
  
  for (i in seq_len(nrow(edit_log))) {
    row <- edit_log[i, ]
    cat(sprintf("[%d] Detector: %s | Night: %s\n", i, row$Detector, row$Night))
    if (row$StartTime_changed) {
      cat(sprintf("    StartTime: %s â†’ %s\n", 
                  row$StartTime_orig, row$StartTime_edit))
    }
    if (row$EndTime_changed) {
      cat(sprintf("    EndTime: %s â†’ %s\n", 
                  row$EndTime_orig, row$EndTime_edit))
    }
    cat(sprintf("    RecordingHours: %.2f\n\n", row$RecordingHours_edit))
  }
  sink()
  
  message(sprintf("  âœ“ Edit log saved: %s", basename(edit_log_file)))
}

log_message(sprintf("[Stage 3.7] Tracked %d manual edits", total_edits))

# ==============================================================================
# STAGE 3.8: SET STATUS
# ==============================================================================

message("\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”")
message("â”‚          STAGE 3.8: Set Recording Status                       â”‚")
message("â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n")

message("Classifying recording status (Fail/Success/Partial)...")

# Determine if each row matches uniform schedule
if (!is.na(uniform_start) && !is.na(uniform_end)) {
  template_edited <- template_edited %>%
    mutate(
      matches_uniform = (StartTime == uniform_start & EndTime == uniform_end)
    )
} else {
  # No uniform schedule - all non-zero hours are considered "Partial"
  template_edited <- template_edited %>%
    mutate(matches_uniform = FALSE)
}

# Set Status based on RecordingHours and manual edits
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

message("\nStatus distribution:")
for (status in names(status_counts)) {
  message(sprintf("  %s: %s nights", 
                  status,
                  format(status_counts[status], big.mark = ",")))
}

log_message(sprintf("[Stage 3.8] Set status: %d Fail, %d Success, %d Partial",
                    status_counts["Fail"] %||% 0,
                    status_counts["Success"] %||% 0,
                    status_counts["Partial"] %||% 0))

# ==============================================================================
# STAGE 3.9: CALCULATE METRICS
# ==============================================================================

message("\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”")
message("â”‚          STAGE 3.9: Calculate Metrics                          â”‚")
message("â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n")

message("Calculating CallsPerHour...")

# Calculate CallsPerHour (avoid division by zero)
calls_per_night_final <- template_edited %>%
  mutate(
    CallsPerHour = ifelse(
      RecordingHours > 0,
      CallsPerNight / RecordingHours,
      NA_real_
    )
  )

# Remove "dead nights" (NA recording hours)
n_before <- nrow(calls_per_night_final)

calls_per_night_final <- calls_per_night_final %>%
  filter(!is.na(RecordingHours))

n_after <- nrow(calls_per_night_final)
n_removed <- n_before - n_after

if (n_removed > 0) {
  message(sprintf("  Removed %s nights with NA RecordingHours", 
                  format(n_removed, big.mark = ",")))
}

message(sprintf("âœ“ Final dataset: %s rows", 
                format(nrow(calls_per_night_final), big.mark = ",")))

# Show summary statistics
message("\nSummary statistics:")
message(sprintf("  Total calls: %s", 
                format(sum(calls_per_night_final$CallsPerNight), big.mark = ",")))
message(sprintf("  Total recording hours: %.1f", 
                sum(calls_per_night_final$RecordingHours, na.rm = TRUE)))
message(sprintf("  Mean calls/night: %.1f", 
                mean(calls_per_night_final$CallsPerNight, na.rm = TRUE)))
message(sprintf("  Mean calls/hour: %.1f", 
                mean(calls_per_night_final$CallsPerHour, na.rm = TRUE)))

log_message(sprintf("[Stage 3.9] Calculated metrics: %d final rows", 
                    nrow(calls_per_night_final)))

# ==============================================================================
# STAGE 3.10: VALIDATE & SAVE
# ==============================================================================

message("\nâ”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”")
message("â”‚          STAGE 3.10: Validate & Save                           â”‚")
message("â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜\n")

# Reorder columns (no detector_id in user-facing output)
calls_per_night_final <- calls_per_night_final %>%
  select(Detector, Night, CallsPerNight, 
         RecordingHours, StartTime, EndTime, Status, CallsPerHour)

# Validate master schema
message("Validating master schema...")

# Note: enforce_master_schema expects DetectorID and detector_id
# Add them back temporarily for validation, then remove
detector_id_mapping <- kpro_master %>%
  select(Detector, detector_id) %>%
  distinct()

calls_per_night_validated <- calls_per_night_final %>%
  left_join(detector_id_mapping, by = "Detector") %>%
  mutate(
    DetectorID = detector_id,
    DateTime = as.POSIXct(paste(Night, "12:00:00"), tz = "America/Chicago")
  ) %>%
  select(Detector, DetectorID, Night, DateTime, CallsPerNight, Status, everything()) %>%
  select(-detector_id)  # Remove lowercase version

# Apply validation
calls_per_night_validated <- enforce_master_schema(calls_per_night_validated)

message("âœ“ Schema validation passed")

# Save with auto-incrementing version
message("\nSaving final CallsPerNight dataset...")

final_file <- save_callspernight_with_version(
  data = calls_per_night_validated,
  base_name = "CallsPerNight_final",
  output_dir = "outputs"
)

message(sprintf("âœ“ Final file saved: %s", basename(final_file)))

log_message(sprintf("[Stage 3.10] Saved final dataset: %s", basename(final_file)))

# ==============================================================================
# WORKFLOW 03 COMPLETE
# ==============================================================================

message("\nâ•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—")
message("â•‘          WORKFLOW 03 COMPLETE: CallsPerNight Generated         â•‘")
message("â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")

message("\nFiles created:")
message(sprintf("  âœ“ Template (original): %s", basename(template_original_file)))
if (total_edits > 0) {
  message(sprintf("  âœ“ Edit log: %s", basename(edit_log_file)))
}
message(sprintf("  âœ“ Final dataset: %s", basename(final_file)))

message("\nDataset summary:")
message(sprintf("  Detectors: %d", length(unique(calls_per_night_validated$Detector))))
message(sprintf("  Nights: %d", length(unique(calls_per_night_validated$Night))))
message(sprintf("  Total rows: %s", 
                format(nrow(calls_per_night_validated), big.mark = ",")))

# Status breakdown
message("\nRecording status:")
for (status in names(status_counts)) {
  pct <- 100 * status_counts[status] / sum(status_counts)
  message(sprintf("  %s: %s (%.1f%%)", 
                  status,
                  format(status_counts[status], big.mark = ","),
                  pct))
}

message("\n========================================")
message("âœ“ Workflow 03 Complete")
message("========================================")

message("\nCurrent data in environment:")
message("  â€¢ calls_per_night_final (ready for analysis)")
message(sprintf("  â€¢ Final file: %s", basename(final_file)))

message("\nTo inspect data:")
message("  head(calls_per_night_final)")
message("  summary(calls_per_night_final)")
message("  table(calls_per_night_final$Status)")
message("  View(calls_per_night_final)")

message("\nNext steps:")
message("  - Perform statistical analysis")
message("  - Generate visualizations")
message("  - Export for reporting\n")

log_message("=== WORKFLOW 03 COMPLETE ===")