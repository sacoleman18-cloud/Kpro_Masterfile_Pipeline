# ==============================================================================
# MAINLINE WORKFLOW: 03_generate_cpn_template.R
# ==============================================================================
# PURPOSE
# -------
# Generate CallsPerNight template for manual recording hour adjustments.
# Creates detector × night grid with pre-filled recording times (if uniform)
# and Excel formulas for calculating recording hours.
#
# WORKFLOW POSITION
# -----------------
# This is Workflow 03 in the processing pipeline:
#   01_ingest_raw_data.R  → Load & intro-standardize raw CSVs
#   02_standardize.R      → Transform to master schema
#   [OPTIONAL: Manual ID in Kaleidoscope]
#   03_generate_cpn_template.R → [THIS SCRIPT] Generate template for editing
#   [USER: Edit template in Excel]
#   04_finalize_cpn.R     → Process edited template & calculate metrics
#
# INPUTS
# ------
# In Memory (preferred):
#   - kpro_master (from Workflow 02)
#
# OR File Import (if manually ID'd):
#   - User-selected CSV with manual_id column populated
#   - Selected via file.choose() dialog
#
# OR Checkpoint (fallback):
#   - outputs/02_kpro_master_YYYYMMDD_HHMMSS.csv
#
# MANUAL ID WORKFLOW (OPTIONAL)
# ------------------------------
# Users may manually review calls in Kaleidoscope Pro before running this workflow:
#
# 1. Run Workflow 02 → produces kpro_master.csv
# 2. Load kpro_master.csv into Kaleidoscope Pro
# 3. Manually review calls, populate manual_id column
# 4. Save updated file
# 5. Run Workflow 03 → import manually-ID'd file when prompted
#
# NoID Filtering Logic:
#   - Row is REMOVED only if BOTH auto_id AND manual_id are unidentifiable
#   - Unidentifiable = NA, blank string, "NoID", or "UNKNOWN"
#   - Row is KEPT if at least ONE ID is valid (identified species)
#
# Examples:
#   auto_id="NoID", manual_id="EPFU"        → KEEP (manual ID is valid)
#   auto_id="EPFU",  manual_id="NoID"        → KEEP (auto ID is valid)
#   auto_id="NoID",  manual_id="NoID"        → REMOVE (both unidentifiable)
#   auto_id="NoID",  manual_id=NA            → REMOVE (both unidentifiable)
#   auto_id="EPFU",  manual_id="MYLU"        → KEEP (both valid, prioritize manual_id)
#
# This ensures we only remove calls that are truly unidentifiable,
# while preserving calls where the user or algorithm provided a valid ID.
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
# Stage 3.2: Load Recording Period from YAML
#   - Loads study parameters from YAML configuration
#   - Extracts start_date, end_date, recording times
#   - Validates uniform vs. advanced scheduling
#
# Stage 3.3: Calculate Study Nights
#   - Applies study night logic using recording_start cutoff
#   - Aggregates CallsPerNight by Detector × Night
#
# Stage 3.4: Generate Template
#   - Filters unidentifiable calls (removes only if BOTH auto_id AND manual_id are unidentifiable)
#   - Creates Detector × Night grid for full recording period
#   - Pre-fills uniform times if provided
#   - Adds Excel formula for RecordingHours
#   - Saves TWO files: ORIGINAL (for tracking) and EDIT_THIS (for user)
#
# Stage 3.5: Save & Display Instructions
#   - Displays detailed editing instructions
#   - Clarifies which file to edit (EDIT_THIS)
#   - Tells user to run 04_finalize_cpn.R after editing
#
# OUTPUTS
# -------
# Files Created:
#   - outputs/03_CallsPerNight_Template_ORIGINAL_YYYYMMDD_HHMMSS.csv (DO NOT EDIT)
#   - outputs/03_CallsPerNight_Template_EDIT_THIS_YYYYMMDD_HHMMSS.csv (USER EDITS)
#   - logs/workflow_log_YYYYMMDD.txt (processing log)
#
# In Memory:
#   - cpn_template (template data for reference)
#   - kpro_master (filtered data, for use in script 04)
#
# STUDY NIGHT LOGIC
# -----------------
# Bat acoustic studies use "study nights" that span calendar day boundaries.
# The Night cutoff is dynamically set to match the recording_start time from YAML.
#
# Rule: Calls before recording_start time belong to PREVIOUS calendar day
#
# Examples (with recording_start = "18:00:00"):
#   DateTime: 2024-10-25 22:30:00 → hour=22 (≥18) → Night: 2024-10-25 (same day)
#   DateTime: 2024-10-26 03:15:00 → hour=3 (<18) → Night: 2024-10-25 (previous day)
#   DateTime: 2024-10-26 07:45:00 → hour=7 (<18) → Night: 2024-10-25 (previous day)
#   DateTime: 2024-10-26 18:00:00 → hour=18 (≥18) → Night: 2024-10-26 (same day)
#
# This ensures perfect alignment: Night date = calendar day when recording started.
# For typical recording schedule (18:00 to 07:00):
#   - Night 2024-10-25 spans 2024-10-25 18:00 to 2024-10-26 07:00
#   - All calls in this period get Night = 2024-10-25
#   - No daytime calls (07:00-18:00) contaminate the night count
#
# RECORDING HOURS CALCULATION
# ----------------------------
# Uses full DateTime values for unambiguous calculation:
#
# Excel Formula: =(VALUE(E2)-VALUE(D2))*24
#
# How it works:
#   - VALUE() converts text datetime to Excel serial number
#   - Excel stores datetimes as days since 1900-01-01
#   - Subtracting datetimes gives difference in days
#   - Multiply by 24 to convert days to hours
#
# Examples:
#   StartDateTime: "10/25/2025 8:00:00 PM", EndDateTime: "10/26/2025 6:00:00 AM"
#   → (Oct 26 6:00 AM - Oct 25 8:00 PM) = 0.4167 days = 10 hours
#
#   StartDateTime: "10/25/2025 6:00:00 PM", EndDateTime: "10/26/2025 8:00:00 AM"
#   → (Oct 26 8:00 AM - Oct 25 6:00 PM) = 0.5833 days = 14 hours
#
# Equipment failure:
#   StartDateTime: "10/25/2025 8:00:00 PM", EndDateTime: "10/26/2025 3:00:00 AM"
#   → (Oct 26 3:00 AM - Oct 25 8:00 PM) = 0.2917 days = 7 hours
#
# TEMPLATE STRUCTURE
# ------------------
# Template columns (user will edit in Excel):
#   Detector         - Friendly detector name (e.g., "SMO", "LPE")
#   Night            - Study night date (YYYY-MM-DD)
#   CallsPerNight    - Count of calls detected (0 if none)
#   StartDateTime    - Recording start datetime (MM/DD/YYYY HH:MM:SS AM/PM) - USER EDITABLE
#   EndDateTime      - Recording end datetime (MM/DD/YYYY HH:MM:SS AM/PM) - USER EDITABLE
#   RecordingHours   - Excel formula (auto-calculates from Start/End)
#
# DateTime Format:
#   Full datetime values eliminate ambiguity about which date a time refers to.
#   Format: MM/DD/YYYY HH:MM:SS AM/PM (e.g., "10/25/2025 8:00:00 PM")
#   
#   Examples for Night = 2025-10-25:
#     StartDateTime: 10/25/2025 8:00:00 PM (8:00 PM on Oct 25)
#     EndDateTime:   10/26/2025 6:00:00 AM (6:00 AM on Oct 26 - next morning)
#   
#   Equipment failure examples:
#     Failure at Oct 25 11:00 PM: EndDateTime = 10/25/2025 11:00:00 PM
#     Failure at Oct 26 3:00 AM:  EndDateTime = 10/26/2025 3:00:00 AM
#
# User edits StartDateTime/EndDateTime to account for:
#   - Equipment failures (set both to blank)
#   - SD card full (adjust EndDateTime to when card filled)
#   - Late deployment (adjust StartDateTime)
#   - Early retrieval (adjust EndDateTime)
#   - Power issues (adjust times or set to blank)
#
# Template organization:
#   - Rows grouped by Detector (all nights for each detector together)
#   - Nights sorted chronologically within each detector
#
# TWO-FILE SYSTEM
# ---------------
# Workflow 03 saves TWO identical template files:
#
# 1. *_ORIGINAL_*.csv - Original template (DO NOT EDIT)
#    - Used in Workflow 04 for edit tracking
#    - Compares original vs edited to log changes
#    - Maintains audit trail
#
# 2. *_EDIT_THIS_*.csv - Editable template (USER EDITS THIS)
#    - User opens this file in Excel
#    - Makes all edits to StartDateTime/EndDateTime
#    - Saves changes
#
# Why two files?
#   - Preserves original for comparison
#   - Enables edit tracking and audit log
#   - Prevents accidental loss of original data
#
# PERFORMANCE EXPECTATIONS
# -------------------------
# Typical bat acoustic datasets:
#
# Small study (3 detectors, 30 nights):
#   - Template rows: ~90
#   - Processing: < 30 seconds
#
# Medium study (10 detectors, 90 nights):
#   - Template rows: ~900
#   - Processing: < 1 minute
#
# Large study (20+ detectors, 180 nights):
#   - Template rows: 3,600+
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
#                                  generate_calls_per_night_template
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
# USAGE EXAMPLES
# --------------
# # Run after Workflow 02:
# source("R/workflows/02_standardize.R")
# source("R/workflows/03_generate_cpn_template.R")
#
# # Run standalone (loads kpro_master from checkpoint):
# source("R/workflows/03_generate_cpn_template.R")
#
# # After template generated, edit in Excel, then:
# source("R/workflows/04_finalize_cpn.R")
#
# MAINTAINER NOTES
# ----------------
# - ASCII boxes: Single-line (┌─┐) for all stages
# - Stage numbering: 3.0 - 3.5
# - No interactive pause - user edits template offline
# - Template timestamp used for tracking in script 04
# - NoID filtering: Remove only if BOTH IDs are unidentifiable
# - Two-file system: ORIGINAL + EDIT_THIS for edit tracking
# - This script does NOT calculate final metrics (that's script 04)
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

log_message("=== WORKFLOW 03: Generate CallsPerNight Template ===")

# STAGE 3.0: MANUAL ID CHECK & IMPORT
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 3.0: Manual ID Check & Import                   │")
message("└────────────────────────────────────────────────────────────────┘\n")

message("MANUAL SPECIES IDENTIFICATION")
message(strrep("─", 66))
message("\nHave you manually reviewed and identified calls in Kaleidoscope Pro?")
message("(This step is optional but improves species identification accuracy)\n")

manual_id_response <- tolower(trimws(readline("Manually ID'd calls? (y/n): ")))

if (manual_id_response == "y") {
  message("\n✓ Manual ID workflow detected")
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
    message("    Using noon cutoff temporarily - will recalculate in Stage 3.2 with correct timezone")
    
    # Temporary calculation - will be recalculated in Stage 3.2 with proper timezone
    kpro_master <- kpro_master %>%
      mutate(
        Night = if_else(
          lubridate::hour(DateTime) < 12,
          lubridate::as_date(DateTime) - 1,
          lubridate::as_date(DateTime)
        )
      )
  }
  
  message(sprintf("✓ Loaded manually-ID'd data: %s rows", 
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
  message("\n✓ No manual ID - will use auto_id only")
  message("  (NoID calls will be removed during template generation)")
  
  log_message("[Stage 3.0] No manual ID workflow - using auto_id only")
}

# ==============================================================================
# STAGE 3.1: LOAD & VALIDATE DATA
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 3.1: Load & Validate Data                       │")
message("└────────────────────────────────────────────────────────────────┘\n")

# Check if kpro_master exists in memory (from Stage 3.0 OR Workflow 02)
if (exists("kpro_master")) {
  message("✓ Using kpro_master from memory")
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
  
  message(sprintf("✓ Loaded checkpoint: %s rows", format(nrow(kpro_master), big.mark = ",")))
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

message("✓ All required columns present")

log_message(sprintf("[Stage 3.1] Loaded kpro_master: %s rows", nrow(kpro_master)))

# ==============================================================================
# STAGE 3.2: LOAD RECORDING PERIOD FROM YAML
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 3.2: Load Recording Period from Config          │")
message("└────────────────────────────────────────────────────────────────┘\n")

# Load study parameters from YAML
if (!file.exists("inst/config/study_parameters.yaml")) {
  stop("inst/config/study_parameters.yaml not found. Please run 01_ingest_raw_data.R first.")
}

params <- load_study_parameters("inst/config/study_parameters.yaml")

# Extract recording period dates
start_date <- as.Date(params$study_parameters$start_date)
end_date <- as.Date(params$study_parameters$end_date)

# Validate dates loaded correctly
if (is.na(start_date) || is.na(end_date)) {
  stop("Invalid dates in YAML. Check study_parameters.yaml: start_date and end_date must be 'YYYY-MM-DD'")
}

if (end_date < start_date) {
  stop("End date before start date in YAML. Check study_parameters.yaml")
}

total_nights <- as.numeric(end_date - start_date) + 1

message(sprintf("✓ Recording period (from YAML): %s to %s (%d nights)", 
                start_date, end_date, total_nights))

# Extract recording schedule
advanced_scheduling <- params$processing_options$advanced_scheduling %||% FALSE

if (!advanced_scheduling) {
  # Uniform schedule - get start/end times from YAML
  uniform_start <- params$processing_options$recording_start
  uniform_end <- params$processing_options$recording_end
  
  # Validate times exist
  if (is.null(uniform_start) || is.null(uniform_end)) {
    stop("Uniform schedule enabled but recording_start/recording_end missing in YAML.\n  Check inst/config/study_parameters.yaml")
  }
  
  # Validate time format
  if (!grepl("^\\d{2}:\\d{2}:\\d{2}$", uniform_start) || 
      !grepl("^\\d{2}:\\d{2}:\\d{2}$", uniform_end)) {
    stop("Invalid time format in YAML. Times must be 'HH:MM:SS' (e.g., '20:00:00')")
  }
  
  message(sprintf("✓ Uniform schedule (from YAML): %s to %s", uniform_start, uniform_end))
  
  # Calculate expected recording hours
  expected_hours <- calculate_recording_hours(uniform_start, uniform_end)
  message(sprintf("  Recording hours per night: %.1f", expected_hours))
  
} else {
  # Advanced scheduling - detector-specific times
  message("✓ Advanced scheduling enabled (detector-specific times)")
  message("  Note: Template will need custom schedule file")
  uniform_start <- NA
  uniform_end <- NA
}

log_message(sprintf("[Stage 3.2] Recording period: %s to %s (%d nights)", 
                    start_date, end_date, total_nights))


# ==============================================================================
# STAGE 3.3: CALCULATE STUDY NIGHTS
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 3.3: Calculate Study Nights                     │")
message("└────────────────────────────────────────────────────────────────┘\n")

# Calculate Night column using cutoff that matches recording schedule
# Note: This (re)calculates Night regardless of whether it exists from Stage 3.0
# to ensure correct cutoff based on actual recording_start time
# CRITICAL: Must force timezone on DateTime to prevent CSV timezone loss issues
# Determine cutoff hour from recording_start time
if (is.na(uniform_start)) {
  # Advanced scheduling enabled - use conservative default (noon)
  recording_start_hour <- 12
  message("Applying study night logic...")
  message("  Advanced scheduling enabled - using 12:00 (noon) cutoff as default")
  message("  Rule: Calls before 12:00:00 → previous calendar day")
} else {
  # Extract hour from uniform recording start time
  recording_start_hour <- as.integer(substr(uniform_start, 1, 2))
  message("Applying study night logic...")
  message(sprintf("  Cutoff matches recording start: %02d:00:00", recording_start_hour))
  message(sprintf("  Rule: Calls before %02d:00:00 → previous calendar day", recording_start_hour))
}

# Get timezone from YAML for Night calculation
study_tz <- params$study_parameters$timezone

# Force DateTime to have correct timezone (may have been lost if loaded from CSV)
kpro_master <- kpro_master %>%
  mutate(
    # Ensure DateTime has correct timezone attribute
    DateTime = lubridate::force_tz(DateTime, tzone = study_tz),
    
    # Calculate Night using timezone-aware date extraction
    Night = if_else(
      lubridate::hour(DateTime) < recording_start_hour,
      lubridate::as_date(DateTime, tz = study_tz) - 1,
      lubridate::as_date(DateTime, tz = study_tz)
    )
  )

message("✓ Study nights calculated")

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

message(sprintf("✓ Aggregated to %s Detector×Night combinations", 
                format(nrow(calls_per_night), big.mark = ",")))

log_message(sprintf("[Stage 3.3] Calculated %d detector-night combinations", 
                    nrow(calls_per_night)))

# ==============================================================================

# ==============================================================================
# STAGE 3.4: GENERATE TEMPLATE
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 3.4: Generate Template                          │")
message("└────────────────────────────────────────────────────────────────┘\n")

# -------------------------
# Remove NoID calls without manual identification
# -------------------------

message("Filtering NoID calls...")

n_before_filter <- nrow(kpro_master)

# Helper function: Check if an ID value is unidentifiable
# Unidentifiable = NA, blank, "NoID", or "UNKNOWN"
is_unidentifiable <- function(id) {
  is.na(id) | trimws(id) == "" | id %in% c("NoID", "UNKNOWN")
}

# Remove row only if BOTH auto_id AND manual_id are unidentifiable
# Keep row if at least ONE ID is valid (identified species)
kpro_master_filtered <- kpro_master %>%
  filter(!(is_unidentifiable(auto_id) & is_unidentifiable(manual_id)))

n_removed <- n_before_filter - nrow(kpro_master_filtered)

if (n_removed > 0) {
  message(sprintf("  Removed %s calls where both auto_id and manual_id are unidentifiable", 
                  format(n_removed, big.mark = ",")))
  
  # Show breakdown if manual IDs are present
  if (any(!is.na(kpro_master$manual_id))) {
    n_auto_noid_kept <- sum(is_unidentifiable(kpro_master$auto_id) & 
                              !is_unidentifiable(kpro_master$manual_id), na.rm = TRUE)
    if (n_auto_noid_kept > 0) {
      message(sprintf("  Kept %s calls where auto_id=NoID but manual_id is valid", 
                      format(n_auto_noid_kept, big.mark = ",")))
    }
  }
} else {
  message("  No unidentifiable calls to remove")
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

message(sprintf("✓ Template created: %s rows", 
                format(nrow(template), big.mark = ",")))

# Remove Warning column (not needed in final template)
if ("Warning" %in% names(template)) {
  template <- template %>% select(-Warning)
}

# Remove detector_id if present (keep only Detector for template)
if ("detector_id" %in% names(template)) {
  template <- template %>% select(-detector_id)
}

# Reorder columns: Detector, Night, CallsPerNight, StartDateTime, EndDateTime, RecordingHours
# This maps to Excel columns: A, B, C, D, E, F
template <- template %>%
  select(Detector, Night, CallsPerNight, StartTime, EndTime, RecordingHours)

# Sort by Detector (alphabetical), then Night (chronological)
# This groups all nights for each detector together
template <- template %>%
  arrange(Detector, Night)

# Convert StartTime/EndTime to full DateTime values, then format as readable text
# StartTime is on the Night date, EndTime is typically next morning
template <- template %>%
  mutate(
    # StartDateTime: Combine Night date with StartTime
    StartDateTime_temp = if_else(
      !is.na(StartTime),
      as.POSIXct(paste(Night, StartTime), format = "%Y-%m-%d %H:%M:%S", tz = "America/Chicago"),
      as.POSIXct(NA)
    ),
    
    # EndDateTime: Combine with appropriate date
    # If EndTime < StartTime, it's on the next day (crossed midnight)
    # Otherwise, it's on the same day (rare - daytime recording)
    EndDateTime_temp = if_else(
      !is.na(EndTime) & !is.na(StartTime),
      if_else(
        EndTime < StartTime,
        # Crossed midnight: EndTime is on next day
        as.POSIXct(paste(Night + 1, EndTime), format = "%Y-%m-%d %H:%M:%S", tz = "America/Chicago"),
        # Same day: EndTime is on Night date
        as.POSIXct(paste(Night, EndTime), format = "%Y-%m-%d %H:%M:%S", tz = "America/Chicago")
      ),
      as.POSIXct(NA)
    ),
    
    # Format as readable text: "10/6/2025 6:00:00 PM"
    StartDateTime = if_else(
      !is.na(StartDateTime_temp),
      format(StartDateTime_temp, "%m/%d/%Y %I:%M:%S %p"),
      NA_character_
    ),
    
    EndDateTime = if_else(
      !is.na(EndDateTime_temp),
      format(EndDateTime_temp, "%m/%d/%Y %I:%M:%S %p"),
      NA_character_
    )
  ) %>%
  select(-StartTime, -EndTime, -StartDateTime_temp, -EndDateTime_temp)

# Reorder to put DateTime columns where time columns were
template <- template %>%
  select(Detector, Night, CallsPerNight, StartDateTime, EndDateTime, RecordingHours)

# Replace RecordingHours with Excel formula that handles text-formatted datetimes
# Excel will auto-recognize "10/6/2025 6:00:00 PM" format as datetime
template <- template %>%
  mutate(
    row_num = row_number() + 1,  # +1 because row 1 is header
    RecordingHours = ifelse(
      !is.na(StartDateTime) & !is.na(EndDateTime),
      # Excel formula: Convert text to datetime, subtract, multiply by 24
      # Using VALUE() to ensure Excel treats as datetime even if stored as text
      sprintf("=(VALUE(E%d)-VALUE(D%d))*24", row_num, row_num),
      NA_character_
    )
  ) %>%
  select(-row_num)

# -------------------------
# Save TWO template files
# -------------------------

# Save template twice:
# 1. ORIGINAL (never touch - for edit tracking in Workflow 04)
# 2. EDIT_THIS (user edits this one)
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

template_original_file <- sprintf("outputs/03_CallsPerNight_Template_ORIGINAL_%s.csv", 
                                  timestamp)
template_editable_file <- sprintf("outputs/03_CallsPerNight_Template_EDIT_THIS_%s.csv", 
                                  timestamp)

# Save both files (identical content initially)
write_csv(template, template_original_file)
write_csv(template, template_editable_file)

message(sprintf("✓ Templates saved:"))
message(sprintf("  Original (DO NOT EDIT): %s", basename(template_original_file)))
message(sprintf("  Edit this file:         %s", basename(template_editable_file)))

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

message("\n✓ Template organized: All nights for each detector grouped together")

log_message(sprintf("[Stage 3.4] Generated template: %d rows (saved as ORIGINAL and EDIT_THIS)", 
                    nrow(template)))

# ==============================================================================
# STAGE 3.5: SAVE & DISPLAY INSTRUCTIONS
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE 3.5: Save & Display Instructions                │")
message("└────────────────────────────────────────────────────────────────┘\n")

message(strrep("=", 66))
message("TEMPLATE GENERATED - READY FOR MANUAL EDITING")
message(strrep("=", 66))

message("\n✓ Two template files created:")
message(sprintf("  1. ORIGINAL (for tracking): %s", basename(template_original_file)))
message(sprintf("  2. EDIT THIS (your copy):   %s", basename(template_editable_file)))
message(sprintf("  Total rows: %s", format(nrow(template), big.mark = ",")))

message("\n" %+% strrep("─", 66))
message("NEXT STEPS")
message(strrep("─", 66))

message("\n1. Open the EDIT_THIS file in Excel:")
message(sprintf("   %s", template_editable_file))
message("   ⚠️  DO NOT edit the ORIGINAL file - it's for tracking changes!")

message("\n2. Template organization:")
message("   • Rows are grouped by Detector (all nights for each detector together)")
message("   • Nights are sorted chronologically within each detector")

message("\n3. Edit StartDateTime and EndDateTime for nights with equipment issues:")
message("   • Format: MM/DD/YYYY HH:MM:SS AM/PM (e.g., '10/25/2025 8:00:00 PM')")
message("   • Equipment failure: Set both to blank (delete values)")
message("   • SD card full: Adjust EndDateTime to when card filled")
message("   • Late deployment: Adjust StartDateTime")
message("   • Early retrieval: Adjust EndDateTime")

message("\n4. RecordingHours will auto-calculate from your edits")
message("   • Formula: =(VALUE(E2)-VALUE(D2))*24")
message("   • Calculates hours between datetimes automatically")

message("\n5. Save your edits (overwrite the EDIT_THIS file)")
message("   • Keep the same filename")
message("   • Leave the ORIGINAL file untouched")

message("\n6. After editing, run the next workflow:")
message("   source(\"R/workflows/04_finalize_cpn.R\")")

message("\n" %+% strrep("=", 66))

log_message("[Stage 3.5] Templates saved - ready for user editing")

# ==============================================================================
# WORKFLOW 03 COMPLETE
# ==============================================================================

message("\n╔══════════════════════════════════════════════════════════════╗")
message("║          WORKFLOW 03 COMPLETE: Template Generated              ║")
message("╚══════════════════════════════════════════════════════════════╝")

message("\nTemplates created:")
message(sprintf("  ✓ ORIGINAL: %s", basename(template_original_file)))
message(sprintf("  ✓ EDIT_THIS: %s", basename(template_editable_file)))
message(sprintf("  ✓ Detectors: %d", detectors_count))
message(sprintf("  ✓ Nights: %d", nights_count))
message(sprintf("  ✓ Total rows: %s", format(nrow(template), big.mark = ",")))

message("\n========================================")
message("✓ Workflow 03 Complete")
message("========================================")

message("\nData in environment:")
message("  • kpro_master (filtered, ready for script 04)")
message("  • cpn_template (template data for reference)")
message(sprintf("  • EDIT_THIS file: %s", basename(template_editable_file)))

message("\nTo edit template:")
message(sprintf("  1. Open: %s", basename(template_editable_file)))
message("  2. Edit StartDateTime/EndDateTime for equipment failures")
message("     Format: MM/DD/YYYY HH:MM:SS AM/PM (e.g., '10/25/2025 8:00:00 PM')")
message("  3. Save the file (overwrite EDIT_THIS)")
message("  4. DO NOT edit the ORIGINAL file")

message("\nAfter editing template:")
message("  source(\"R/workflows/04_finalize_cpn.R\")\n")

log_message("=== WORKFLOW 03 COMPLETE ===")

# Store template in environment for reference
cpn_template <- template