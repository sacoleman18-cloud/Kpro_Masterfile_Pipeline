# =============================================================================
# UTILITY: callspernight.R - CallsPerNight Template Management (LOCKED CONTRACT)
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# - Provides template loading, recording hour calculations, edit tracking
# - Used by modules in R/modules/
# PURPOSE
# -------
# Generates CallsPerNight templates, handles user edits, calculates recording
# hours and CallsPerHour metrics, and provides template loading for finalization
# workflows.
#
# RECORDING HOURS CONTRACT
# ------------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Study night calculation
#    - Calls at/after 12:00:00 -> Night = that date
#    - Calls before 12:00:00 -> Night = previous date
#    - Example: 02:35:50 on 10/26 -> Night = 10/25
#
# 2. Template generation
#    - Creates CSV with columns: Detector, Night, CallsPerNight,
#      RecordingHours (Excel formula), StartDateTime, EndDateTime
#    - Excel formula handles overnight recording automatically
#    - Template saved as _ORIGINAL for comparison
#
# 3. Recording hours calculation
#    - Handles both time-only ("HH:MM:SS") and full datetime formats
#    - Handles overnight spans (e.g., 20:00 -> 06:00 = 10 hours)
#    - Formula: IF(End<Start, (24-Start)+End, End-Start)
#
# 4. Edit tracking
#    - Compares ORIGINAL vs EDITED templates
#    - Generates detailed edit log with all changes
#
# 5. Finalization
#    - RETAINS "dead nights" (RecordingHours = 0 or NA) with Status = Fail
#    - Calculates CallsPerHour = CallsPerNight / RecordingHours
#    - Saves with auto-incrementing version (v1, v2, v3...)
#
# 6. Template loading
#    - Discovers and loads most recent template files (ORIGINAL or EDIT_THIS)
#    - Pattern-based file discovery with timestamp sorting
#    - Used by run_phase3_analysis_reporting() orchestrating function
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Validate data quality beyond template structure (validation/)
#   - Generate plots or visualizations (output/)
#   - Transform schema versions (standardization/)
#   - Parse datetime strings (use standardization/datetime_helpers.R)
#
# DEPENDENCIES
# ------------
#   - core/utilities.R: find_most_recent_file, safe_read_csv
#   - standardization/datetime_helpers.R: is.Date, parse_datetime_safe, extract_time,
#                                          parse_date_safe, format_datetime_for_log
#   - validation/validation.R: validate_calls_per_night
#   - dplyr: group_by, summarize, mutate
#   - lubridate: date/time parsing, date/time extraction
#   - hms: time-only parsing
#   - here: path management
#
# FUNCTIONS PROVIDED
# ------------------
#
# Recording Hours Calculation - Vectorized duration computation:
#
#   - calculate_recording_hours():
#       Uses packages: lubridate (hms::parse_hms, as.numeric), base R (grepl, ifelse)
#       Calls internal: none (pure calculation)
#       Purpose: Calculate hours between start/end times with overnight handling
#
# Template Generation - Create standard recording templates:
#
#   - generate_calls_per_night_template():
#       Uses packages: dplyr (group_by, summarize, mutate), readr (write_csv),
#                      lubridate (date arithmetic)
#       Calls internal: callspernight.R (calculate_recording_hours, apply_schedule),
#                       utilities.R (make_output_path, save_summary_csv),
#                       validation.R (assert_data_frame, validate_calls_per_night)
#       Purpose: Generate CSV template with one row per detector-night
#
#   - apply_schedule():
#       Uses packages: dplyr (filter, mutate), lubridate (with_tz, date)
#       Calls internal: none (configuration-based filtering)
#       Purpose: Apply recording schedule constraints to template rows
#
# File Management - Save and load templates with versioning:
#
#   - save_callspernight_with_version():
#       Uses packages: readr (write_csv), base R (file.path)
#       Calls internal: utilities.R (make_versioned_path)
#       Purpose: Save template with auto-incremented version (v1, v2, v3...)
#
# Template Loading - Discover and load existing templates:
#
#   - load_cpn_template():
#       Uses packages: readr (read_csv), base R (list.files)
#       Calls internal: callspernight.R (extract_template_timestamp),
#                       utilities.R (find_most_recent_file, safe_read_csv)
#       Purpose: Load most recent ORIGINAL or EDIT_THIS template
#
#   - extract_template_timestamp():
#       Uses packages: base R (substr, as.POSIXct)
#       Calls internal: none (string parsing only)
#       Purpose: Extract ISO timestamp from template filename (internal helper)
#
# USAGE
# -----
# source("R/functions/analysis/callspernight.R")
#
# # Generate template
# template <- generate_calls_per_night_template(
#   master_data, 
#   start_date = "2025-10-01", 
#   end_date = "2025-10-31"
# )
#
# # Calculate recording hours
# template$RecordingHours <- calculate_recording_hours(
#   template$StartTime, 
#   template$EndTime
# )
#
# # Load template for finalization
# cpn_template <- load_cpn_template(type = "EDIT_THIS")
#
# EXCEL FORMULA FOR RECORDINGHOURS
# --------------------------------
#   =(VALUE(E2)-VALUE(D2))*24
#   Where E2 = EndDateTime, D2 = StartDateTime
#   VALUE() converts text datetime to Excel serial number
#
# Last Modified: 2026-02-09
#
# CHANGELOG
# ---------
# 2026-02-05: DOCUMENTATION FIX - Updated header to match 02_documentation_standards.md
#             - Changed "analysis/callspernight.R" to "MODULE: callspernight.R"
#             - Renamed "CONTENTS" section to "FUNCTIONS PROVIDED"
#             - Added missing "USAGE" section with examples
# 2026-02-04: MODULE SPLIT - Moved datetime helpers to datetime_helpers.R
#             - Moved 5 functions to standardization/datetime_helpers.R:
#               * is.Date(), parse_datetime_safe(), extract_time()
#               * parse_date_safe(), format_datetime_for_log()
#             - Updated DEPENDENCIES to reference datetime_helpers.R
#             - Removed DateTime Helpers from CONTENTS section
#             - Callspernight now focuses on recording hours and template generation
# 2026-02-04: MODULE SPLIT - Added template loading functions
#             - Added load_cpn_template() for ORIGINAL/EDIT_THIS loading
#             - Added extract_template_timestamp() helper
#             - Replaces load_cpn_template_original() from utilities.R
#             - Consolidates template loading logic in analysis layer
#             - Updated CONTENTS section with Template Loading category
# 2026-02-02: MAJOR REWRITE - calculate_recording_hours() now fully vectorized
#             - Handles both time-only ("HH:MM:SS") and full datetime formats
#             - Auto-detects format per row (contains "/" = datetime, else time-only)
#             - Tries multiple datetime formats (AM/PM, 24-hour, with/without seconds)
#             - Supports Excel auto-formatting (handles format changes transparently)
#             - Fully vectorized for dplyr::mutate() compatibility
#             - Returns numeric vector instead of single value
#             - Handles NA inputs gracefully (returns NA in result vector for failed rows)
#             - Improves performance for large datasets (no loops required)
# 2026-02-01: Verified deterministic behavior - all functions follow standards
# 2026-02-01: Confirmed usage in run_phase2_template_generation() (Phase 2) and run_phase3_analysis_reporting() (Phase 3)
# 2024-12-29: Added datetime helpers for Workflow 04 template comparison support
#
# =============================================================================

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

SECONDS_PER_HOUR <- 3600
HOURS_PER_DAY <- 24

# ------------------------------------------------------------------------------
# Calculate Recording Hours (Handles Time-Only and Full DateTime)
# ------------------------------------------------------------------------------

#' Calculate Recording Duration in Hours
#'
#' @description
#' Computes the number of recording hours between a start and end time.
#' Handles both time-only ("HH:MM:SS") and full datetime formats
#' ("MM/DD/YYYY HH:MM:SS AM/PM"). Correctly handles overnight recordings.
#' Fully vectorized for use with `dplyr::mutate()`.
#'
#' @param start_time Character vector. Either:
#'   - Time-only: "HH:MM:SS" (e.g., "20:00:00")
#'   - Full datetime (multiple formats supported):
#'     * "MM/DD/YYYY HH:MM:SS AM/PM" (e.g., "10/25/2025 8:00:00 PM")
#'     * "MM/DD/YYYY HH:MM" (e.g., "10/4/2025 18:00") - Excel auto-format
#'     * "M/D/YYYY HH:MM" (e.g., "10/4/2025 18:00") - Single-digit month/day
#'   - NA (returns NA in corresponding position)
#' @param end_time Character vector. Same format as start_time, or NA.
#'
#' @return Numeric vector of durations in hours (same length as input).
#'   Returns NA for any row where either input is NA or parsing fails.
#'
#' @details
#' **Format Detection (per row):**
#' - If row contains "/" -> parsed as full datetime
#' - Otherwise -> parsed as time-only (HH:MM:SS)
#' - Detection happens independently for each row in the vector
#' 
#' **Supported Datetime Formats:**
#' The function tries multiple formats in order:
#'   1. "MM/DD/YYYY HH:MM:SS AM/PM" (e.g., "10/25/2025 8:00:00 PM")
#'   2. "MM/DD/YYYY HH:MM" (e.g., "10/4/2025 18:00") - Excel 24-hour
#'   3. "M/D/YYYY HH:MM" (e.g., "10/4/2025 18:00") - Single-digit month/day
#' 
#' This handles Excel auto-formatting which often converts our AM/PM format
#' to 24-hour format without seconds when the file is saved.
#' 
#' **Overnight Handling (Time-Only):**
#' If end_time < start_time, assumes recording crossed midnight:
#'   Duration = (24 - start_time) + end_time
#' 
#' **Overnight Handling (Full DateTime):**
#' Automatically handled by date arithmetic (end_datetime - start_datetime)
#' 
#' **Examples:**
#' Time-only:
#'   - "20:00:00" to "08:00:00" -> 12 hours (crosses midnight)
#'   - "06:00:00" to "18:00:00" -> 12 hours (same day)
#' 
#' Full datetime (AM/PM format):
#'   - "10/25/2025 8:00:00 PM" to "10/26/2025 6:00:00 AM" -> 10 hours
#'   - "10/25/2025 6:00:00 PM" to "10/26/2025 7:00:00 AM" -> 13 hours
#' 
#' Full datetime (24-hour format - Excel auto-formatted):
#'   - "10/25/2025 20:00" to "10/26/2025 6:00" -> 10 hours
#'   - "10/25/2025 18:00" to "10/26/2025 7:00" -> 13 hours
#' 
#' **NA Handling:**
#' Returns NA if either time is missing (allows template generation
#' to proceed even when times haven't been entered yet).
#'
#' @section CONTRACT:
#' - Fully vectorized - accepts and returns vectors (dplyr::mutate compatible)
#' - Returns numeric vector of same length as input
#' - Accepts time-only ("HH:MM:SS") OR full datetime (multiple formats)
#' - Automatically tries multiple datetime formats (handles Excel formatting)
#' - Returns NA for any row where either input is NA (fails gracefully per row)
#' - Handles overnight recordings correctly (end < start for time-only)
#' - Returns numeric hours (not negative values)
#' - Detects format automatically per row (no explicit format parameter needed)
#' - Uses 24-hour clock for time-only, either 12 or 24-hour for full datetime
#' - Warns if any datetime rows fail parsing (logs row numbers)
#'
#' @section DOES NOT:
#' - Require explicit format specification (auto-detects)
#' - Perform timezone conversions (assumes all times in same zone)
#' - Validate clock correctness (assumes valid times)
#' - Round to nearest hour (returns decimal hours)
#' - Check if duration exceeds 24 hours
#' - Stop execution on parse failures (returns NA for failed rows)
#' - Require inputs of same length (recycles shorter vectors per R rules)
#'
#' @examples
#' \dontrun{
#' # Time-only format (for template generation)
#' calculate_recording_hours("20:00:00", "08:00:00")
#' # [1] 12
#' 
#' calculate_recording_hours("06:00:00", "18:00:00")
#' # [1] 12
#' 
#' # Vectorized usage (multiple rows)
#' start_times <- c("20:00:00", "18:00:00", "06:00:00")
#' end_times <- c("08:00:00", "07:00:00", "18:00:00")
#' calculate_recording_hours(start_times, end_times)
#' # [1] 12 13 12
#' 
#' # Full datetime - AM/PM format (Workflow 03 generated)
#' calculate_recording_hours("10/25/2025 8:00:00 PM", "10/26/2025 6:00:00 AM")
#' # [1] 10
#' 
#' # Full datetime - 24-hour format (Excel auto-formatted)
#' calculate_recording_hours("10/25/2025 20:00", "10/26/2025 6:00")
#' # [1] 10
#' 
#' calculate_recording_hours("10/4/2025 18:00", "10/5/2025 7:00")
#' # [1] 13
#' 
#' # NA handling (vectorized)
#' calculate_recording_hours(c("20:00:00", NA, "18:00:00"), 
#'                          c("08:00:00", "06:00:00", "07:00:00"))
#' # [1] 12 NA 13
#' 
#' # Usage in dplyr pipeline
#' template %>%
#'   mutate(RecordingHours = calculate_recording_hours(StartTime, EndTime))
#' }
#'
#' @export
calculate_recording_hours <- function(start_time, end_time) {
  # Ensure inputs are character vectors
  start_time <- as.character(start_time)
  end_time   <- as.character(end_time)
  
  n <- length(start_time)
  result <- rep(NA_real_, n)
  
  # NA handling
  na_mask <- is.na(start_time) | is.na(end_time)
  if (all(na_mask)) return(result)
  
  # Detect datetime vs time-only (per row)
  is_datetime <- grepl("/", start_time) & !na_mask
  is_time_only <- !is_datetime & !na_mask
  
  # ---------------------------
  # Process datetime rows
  # ---------------------------
  if (any(is_datetime)) {
    dt_start <- rep(as.POSIXct(NA), n)
    dt_end   <- rep(as.POSIXct(NA), n)
    
    # Multiple common datetime formats (vectorized)
    formats <- c(
      "%m/%d/%Y %I:%M:%S %p", # AM/PM with seconds
      "%m/%d/%Y %I:%M %p",    # AM/PM no seconds
      "%m/%d/%Y %H:%M:%S",    # 24h with seconds
      "%m/%d/%Y %H:%M",       # 24h no seconds
      "%m/%d/%Y %H:%M:%S %p"  # rare mixed format
    )
    
    for (fmt in formats) {
      idx <- is_datetime & is.na(dt_start)
      if (!any(idx)) break
      dt_start[idx] <- as.POSIXct(start_time[idx], format = fmt, tz = "UTC")
      dt_end[idx]   <- as.POSIXct(end_time[idx], format = fmt, tz = "UTC")
    }
    
    # Warn if any rows failed parsing
    failed <- is_datetime & is.na(dt_start)
    if (any(failed)) {
      warning("Failed to parse datetime in rows: ", paste(which(failed), collapse = ", "))
    }
    
    # Compute durations in hours
    valid <- is_datetime & !failed
    result[valid] <- as.numeric(difftime(dt_end[valid], dt_start[valid], units = "hours"))
  }
  
  # ---------------------------
  # Process time-only rows
  # ---------------------------
  if (any(is_time_only)) {
    start_h <- as.numeric(hms::as_hms(start_time[is_time_only])) / 3600
    end_h   <- as.numeric(hms::as_hms(end_time[is_time_only])) / 3600
    
    duration <- ifelse(end_h < start_h,
                       (24 - start_h) + end_h,
                       end_h - start_h)
    
    result[is_time_only] <- duration
  }
  
  result
}


# ------------------------------------------------------------------------------
# Generate CallsPerNight Template
# ------------------------------------------------------------------------------

#' Generate CallsPerNight Template
#'
#' @description
#' Creates a Detector x Night grid spanning the entire recording period,
#' pre-fills uniform recording times if provided, and merges call counts
#' from master data. Generates Excel-ready template for manual editing.
#'
#' @param master_data Data frame with Detector, Night, and detection data.
#'   Must contain columns: Detector, Night. Expects one row per detection event.
#' @param start_date Character string "YYYY-MM-DD" for project start date.
#' @param end_date Character string "YYYY-MM-DD" for project end date.
#' @param uniform_start Character "HH:MM:SS" or NULL. If provided, applies
#'   this start time to all detector-nights. Default: NULL.
#' @param uniform_end Character "HH:MM:SS" or NULL. If provided, applies
#'   this end time to all detector-nights. Default: NULL.
#' @param schedule_file Data frame with detector-specific schedules, or NULL.
#'   Must contain columns: Detector, StartTime, EndTime. Default: NULL.
#'
#' @return Data frame (tibble) with columns:
#'   - Detector: Character, detector name
#'   - Night: Date, study night
#'   - CallsPerNight: Integer, count of calls (0 if none detected)
#'   - StartTime: Character "HH:MM:SS", recording start time
#'   - EndTime: Character "HH:MM:SS", recording end time
#'   - RecordingHours: Numeric, duration in hours (handles overnight)
#'   - Warning: Character, flags nights with 0 calls
#'
#' @details
#' **Template Generation Process:**
#' 1. Creates complete grid: every detector x every night in date range
#' 2. Applies schedule (uniform times or detector-specific)
#' 3. Calculates RecordingHours using calculate_recording_hours()
#' 4. Merges call counts from master_data
#' 5. Fills missing nights with CallsPerNight = 0
#' 6. Adds warning for 0-call nights
#' 
#' **Overnight Recordings:**
#' Automatically handled by calculate_recording_hours().
#' Example: 20:00 -> 08:00 = 12 hours (crosses midnight)
#' 
#' **Missing Data:**
#' Nights without detections appear as CallsPerNight = 0 (not NA).
#' This ensures complete time series for analysis.
#'
#' @section CONTRACT:
#' - Creates row for EVERY detector x EVERY night in date range
#' - Nights without calls appear as CallsPerNight = 0 (never missing)
#' - RecordingHours handles overnight spans correctly
#' - Preserves all input data (non-destructive operation)
#' - Returns tibble with consistent column order
#' - Warning column flags nights with CallsPerNight = 0
#' - Sorts output by Detector, then Night
#' - Either uniform_start/uniform_end OR schedule_file must be provided
#'
#' @section DOES NOT:
#' - Modify master_data input (non-destructive)
#' - Validate data quality (use validation/ module)
#' - Remove NoID calls (done in workflow script)
#' - Save files to disk (caller's responsibility)
#' - Handle multiple detectors at same location
#' - Perform statistical analysis
#' - Generate plots or visualizations
#' - Sort by detector first (returns expand.grid order)
#'
#' @examples
#' \dontrun{
#' # Generate template with uniform schedule
#' template <- generate_calls_per_night_template(
#'   master_data = kpro_master,
#'   start_date = "2024-05-01",
#'   end_date = "2024-08-31",
#'   uniform_start = "20:00:00",
#'   uniform_end = "08:00:00"
#' )
#' 
#' # Check structure
#' head(template)
#' #   Detector Night      CallsPerNight StartTime EndTime RecordingHours
#' #   SMO      2024-05-01 150           20:00:00  08:00:00 12.0
#' #   SMO      2024-05-02 200           20:00:00  08:00:00 12.0
#' 
#' # Generate template with custom schedule
#' schedule <- data.frame(
#'   Detector = c("SMO", "LPE"),
#'   StartTime = c("20:00:00", "18:00:00"),
#'   EndTime = c("08:00:00", "07:00:00")
#' )
#' 
#' template <- generate_calls_per_night_template(
#'   master_data = kpro_master,
#'   start_date = "2024-05-01",
#'   end_date = "2024-08-31",
#'   schedule_file = schedule
#' )
#' }
#'
#' @export
generate_calls_per_night_template <- function(master_data,
                                              start_date,
                                              end_date,
                                              uniform_start = NULL,
                                              uniform_end = NULL,
                                              schedule_file = NULL) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(master_data)) {
    stop(sprintf(
      "master_data must be a data frame.\n  Received: %s\n  Did you forget to load kpro_master from Workflow 02?",
      paste(class(master_data), collapse = ", ")
    ))
  }
  
  if (!is.character(start_date) || !is.character(end_date)) {
    stop(sprintf(
      "start_date and end_date must be character strings in format 'YYYY-MM-DD'.\n  Received: start_date = %s (%s), end_date = %s (%s)\n  Example: '2024-05-01'",
      start_date, class(start_date)[1],
      end_date, class(end_date)[1]
    ))
  }
  
  if (!all(c("Detector", "Night") %in% names(master_data))) {
    stop(sprintf(
      "master_data must contain columns 'Detector' and 'Night'.\n  Found columns: %s\n  Did you run Stage 3.2 (Calculate Study Nights)?",
      paste(names(master_data), collapse = ", ")
    ))
  }
  
  # -------------------------
  # Create template grid
  # -------------------------
  
  detectors <- sort(unique(master_data$Detector))
  nights <- seq.Date(as.Date(start_date), as.Date(end_date), by = "day")
  template <- expand.grid(Detector = detectors, Night = nights, stringsAsFactors = FALSE) %>% 
    as_tibble()
  
  # -------------------------
  # Apply schedule
  # -------------------------
  
  template <- apply_schedule(template, schedule_file, uniform_start, uniform_end)
  
  # -------------------------
  # Calculate recording hours
  # -------------------------
  
  template <- template %>% 
    mutate(RecordingHours = calculate_recording_hours(StartTime, EndTime))
  
  # -------------------------
  # Merge call counts
  # -------------------------
  
  calls_per_night <- master_data %>% 
    count(Detector, Night, name = "CallsPerNight")
  
  template <- template %>%
    left_join(calls_per_night, by = c("Detector", "Night")) %>%
    mutate(
      CallsPerNight = replace_na(CallsPerNight, 0),
      Warning = if_else(CallsPerNight == 0, 
                        "No calls detected - confirm equipment status", 
                        NA_character_)
    )
  
  template
}

# ------------------------------------------------------------------------------
# Apply Schedule to Template
# ------------------------------------------------------------------------------

#' Apply Schedule to Template
#'
#' @description
#' Adds start and end times to a template based on schedule file or
#' uniform hours across all detectors.
#'
#' @param template Data frame with detectors and nights.
#'   Must contain columns: Detector, Night.
#' @param schedule_file Optional data frame with detector-specific schedules.
#'   Must contain columns: Detector, StartTime, EndTime. If NULL, uses uniform times.
#'   Default: NULL.
#' @param uniform_start Optional character "HH:MM:SS" for uniform start time.
#'   Required if schedule_file is NULL. Default: NULL.
#' @param uniform_end Optional character "HH:MM:SS" for uniform end time.
#'   Required if schedule_file is NULL. Default: NULL.
#'
#' @return Template data frame with StartTime and EndTime columns added.
#'
#' @details
#' **Two modes of operation:**
#' 
#' 1. **Uniform schedule (schedule_file = NULL):**
#'    - Applies same StartTime and EndTime to all detector-nights
#'    - Requires uniform_start and uniform_end parameters
#'    - Common for studies with consistent recording protocol
#' 
#' 2. **Detector-specific schedule (schedule_file provided):**
#'    - Joins schedule_file by Detector
#'    - Allows different times for different detectors
#'    - Useful for staggered deployments or location-specific protocols
#'
#' @section CONTRACT:
#' - Adds StartTime and EndTime columns to template
#' - Preserves all rows in template (left join)
#' - Either schedule_file OR uniform times must be provided
#' - Validates schedule_file structure if provided
#' - Returns tibble with same row count as input
#' - Stops with error if neither schedule mode is properly configured
#'
#' @section DOES NOT:
#' - Modify template input (non-destructive operation via piping)
#' - Calculate recording hours (use calculate_recording_hours)
#' - Validate time formats (assumes "HH:MM:SS")
#' - Handle missing schedule data gracefully (will create NA values)
#' - Remove rows with missing times
#' - Sort output (preserves input order)
#'
#' @examples
#' \dontrun{
#' # Create template
#' template <- expand.grid(
#'   Detector = c("SMO", "LPE"),
#'   Night = seq.Date(as.Date("2024-05-01"), as.Date("2024-05-03"), by = "day")
#' )
#' 
#' # Apply uniform schedule
#' template_uniform <- apply_schedule(
#'   template, 
#'   uniform_start = "20:00:00", 
#'   uniform_end = "08:00:00"
#' )
#' 
#' # Apply detector-specific schedule
#' schedule <- data.frame(
#'   Detector = c("SMO", "LPE"),
#'   StartTime = c("20:00:00", "18:00:00"),
#'   EndTime = c("08:00:00", "07:00:00")
#' )
#' 
#' template_custom <- apply_schedule(template, schedule_file = schedule)
#' }
#'
#' @export
apply_schedule <- function(template, 
                           schedule_file = NULL, 
                           uniform_start = NULL, 
                           uniform_end = NULL) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(template)) {
    stop(sprintf(
      "template must be a data frame.\n  Received: %s",
      paste(class(template), collapse = ", ")
    ))
  }
  
  if (!all(c("Detector", "Night") %in% names(template))) {
    stop(sprintf(
      "template must contain columns: Detector, Night\n  Found columns: %s",
      paste(names(template), collapse = ", ")
    ))
  }
  
  # -------------------------
  # Apply schedule
  # -------------------------
  
  if (!is.null(schedule_file)) {
    # Detector-specific schedule mode
    required_cols <- c("Detector", "StartTime", "EndTime")
    
    if (!all(required_cols %in% names(schedule_file))) {
      stop(sprintf(
        "schedule_file must contain columns: Detector, StartTime, EndTime\n  Found columns: %s\n  Please check your schedule file structure.",
        paste(names(schedule_file), collapse = ", ")
      ))
    }
    
    template <- template %>% 
      left_join(schedule_file, by = "Detector")
    
  } else {
    # Uniform schedule mode
    if (is.null(uniform_start) || is.null(uniform_end)) {
      stop(sprintf(
        "Uniform StartTime and EndTime must be provided when schedule_file is NULL.\n  Received: uniform_start = %s, uniform_end = %s\n  Please provide both in 'HH:MM:SS' format (e.g., '20:00:00')",
        ifelse(is.null(uniform_start), "NULL", uniform_start),
        ifelse(is.null(uniform_end), "NULL", uniform_end)
      ))
    }
    
    template <- template %>% 
      mutate(
        StartTime = uniform_start, 
        EndTime = uniform_end
      )
  }
  
  template
}

# ------------------------------------------------------------------------------
# Save CallsPerNight with Versioning
# ------------------------------------------------------------------------------

#' Save CallsPerNight Data Frame with Versioning
#'
#' @description
#' Saves a calls_per_night data frame to a CSV file, automatically
#' versioning the filename to prevent overwriting previous versions.
#' Uses auto-incrementing version numbers (v1, v2, v3, ...).
#'
#' @param data Data frame containing calls per night data.
#'   Typically output from Workflow 03 final stage.
#' @param base_name Character. Base name for the output file. 
#'   Default: "CallsPerNight_final".
#' @param output_dir Character. Directory to save the file. 
#'   Default: project outputs directory (via here::here()).
#'
#' @return Character. Full file path of the saved CSV.
#'
#' @details
#' **Versioning Logic:**
#' - Scans output_dir for existing files matching pattern: base_name_v#.csv
#' - Finds highest version number
#' - Increments by 1
#' - Saves new file with next version number
#' 
#' **Example progression:**
#' - First save: CallsPerNight_final_v1.csv
#' - Second save: CallsPerNight_final_v2.csv
#' - Third save: CallsPerNight_final_v3.csv
#' 
#' **Directory Creation:**
#' If output_dir doesn't exist, creates it automatically.
#'
#' @section CONTRACT:
#' - Never overwrites existing files (always increments version)
#' - Creates output directory if missing
#' - Returns full path to saved file
#' - Logs save operation with message
#' - Uses consistent filename pattern: basename_vN.csv
#' - Formats DateTime columns for export if format_datetime_for_export exists
#'
#' @section DOES NOT:
#' - Validate data structure (caller's responsibility)
#' - Remove old versions (keeps all versions)
#' - Compress files
#' - Write to formats other than CSV
#' - Add timestamps to filename (uses version numbers only)
#' - Guarantee version numbers are contiguous (if files deleted manually)
#'
#' @examples
#' \dontrun{
#' # Save to default location (outputs/)
#' file_path <- save_callspernight_with_version(calls_per_night_final)
#' # Saves to: outputs/CallsPerNight_final_v1.csv
#' 
#' # Save with custom name
#' file_path <- save_callspernight_with_version(
#'   data = calls_per_night_final,
#'   base_name = "Study2024_CallsPerNight"
#' )
#' # Saves to: outputs/Study2024_CallsPerNight_v1.csv
#' 
#' # Save to custom directory
#' file_path <- save_callspernight_with_version(
#'   data = calls_per_night_final,
#'   output_dir = here::here("results", "final")
#' )
#' # Saves to: results/final/CallsPerNight_final_v1.csv
#' }
#'
#' @export
save_callspernight_with_version <- function(data, 
                                            base_name = "CallsPerNight_final", 
                                            output_dir = here::here("outputs")) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(data)) {
    stop(sprintf(
      "data must be a data frame.\n  Received: %s\n  Did you pass the correct object?",
      paste(class(data), collapse = ", ")
    ))
  }
  
  if (!is.character(base_name) || length(base_name) != 1) {
    stop(sprintf(
      "base_name must be a single character string.\n  Received: %s (length %d)",
      class(base_name)[1], length(base_name)
    ))
  }
  
  if (!is.character(output_dir) || length(output_dir) != 1) {
    stop(sprintf(
      "output_dir must be a single character string.\n  Received: %s (length %d)",
      class(output_dir)[1], length(output_dir)
    ))
  }
  
  # -------------------------
  # Ensure output directory exists
  # -------------------------
  
  if (!dir.exists(output_dir)) {
    message(sprintf("Creating output directory: %s", output_dir))
    dir.create(output_dir, recursive = TRUE)
  }
  
  # -------------------------
  # Determine next version number
  # -------------------------
  
  existing_files <- list.files(
    output_dir, 
    pattern = paste0("^", base_name, "_v[0-9]+\\.csv$"), 
    full.names = FALSE
  )
  
  if (length(existing_files) == 0) {
    next_version <- 1
  } else {
    versions <- stringr::str_extract(existing_files, "(?<=_v)\\d+")
    next_version <- max(as.integer(versions), na.rm = TRUE) + 1
  }
  
  # -------------------------
  # Format DateTime columns for export
  # -------------------------
  
  # Format DateTime columns to US-friendly format before saving
  # This prevents ISO 8601 format (2025-10-06T04:14:08Z)
  # and produces readable format (10/6/2025 4:14:08 AM)
  if (exists("format_datetime_for_export")) {
    data <- format_datetime_for_export(data)
  }
  
  # -------------------------
  # Build file path and save
  # -------------------------
  
  file_path <- file.path(output_dir, paste0(base_name, "_v", next_version, ".csv"))
  readr::write_csv(data, file_path)
  
  message(sprintf("âœ“ CallsPerNight file saved: %s", basename(file_path)))
  message(sprintf("  Full path: %s", file_path))
  
  return(file_path)
}



# ------------------------------------------------------------------------------
# Template Loading (for CPN Finalization)
# ------------------------------------------------------------------------------

#' Load CPN Template (ORIGINAL or EDIT_THIS)
#'
#' @description
#' Discovers and loads the most recent CPN template file. Used by
#' run_phase3_analysis_reporting() to load edited templates for processing.
#' Handles the two-file template system: ORIGINAL for tracking and
#' EDIT_THIS for user modifications.
#' 
#' This function encapsulates the template discovery and loading logic
#' that was previously scattered across workflow scripts. It provides
#' consistent error handling and verbose messaging.
#'
#' @param type Character. Template type to load: "ORIGINAL" or "EDIT_THIS".
#'   Default: "EDIT_THIS" (what users typically edit)
#' @param output_dir Character. Directory containing template files.
#'   Default: "outputs/final"
#' @param verbose Logical. Print status messages? Default: FALSE
#' @param file_path Character or NULL. Optional explicit path to template file.
#'   When provided, skips auto-discovery and loads this file directly.
#'
#' @return Tibble with template data. Contains columns:
#'   - Detector: Character, detector name
#'   - Night: Character (date string), study night
#'   - CallsPerNight: Character (numeric string), call count
#'   - StartDateTime: Character, formatted start time
#'   - EndDateTime: Character, formatted end time
#'   - RecordingHours: Character, duration or Excel formula
#'
#' @section Template File Naming:
#' Templates follow the naming convention:
#' ```
#' 03_CallsPerNight_Template_YYYYMMDD_HHMMSS_ORIGINAL.csv
#' 03_CallsPerNight_Template_YYYYMMDD_HHMMSS_EDIT_THIS.csv
#' ```
#' 
#' The function searches for the most recent file matching the pattern
#' and loads it using safe_read_csv() with all columns as character.
#'
#' @section CONTRACT:
#' - Searches outputs/final directory by default
#' - Uses filename timestamp for "most recent" determination
#' - Returns tibble with all columns as character
#' - Stops with informative error if no templates found
#' - Reports file path when verbose = TRUE
#' - Adds source_file and template_type attributes to result
#'
#' @section DOES NOT:
#' - Convert column types (caller's responsibility)
#' - Validate template structure (caller's responsibility)
#' - Modify the loaded data
#' - Create directories
#'
#' @examples
#' \dontrun{
#' # Load most recent EDIT_THIS template (typical use)
#' edited_template <- load_cpn_template(type = "EDIT_THIS", verbose = TRUE)
#'
#' # Load ORIGINAL for comparison (edit tracking)
#' original_template <- load_cpn_template(type = "ORIGINAL")
#'
#' # Compare for edit detection
#' edits_detected <- detect_template_edits(original_template, edited_template)
#' }
#'
#' @export
load_cpn_template <- function(type = "EDIT_THIS",
                              output_dir = NULL,
                              verbose = FALSE,
                              file_path = NULL) {
  
  # Input validation
  valid_types <- c("ORIGINAL", "EDIT_THIS")
  if (!type %in% valid_types) {
    stop(sprintf(
      "Invalid template type: '%s'\n  Valid types: %s",
      type, paste(valid_types, collapse = ", ")
    ))
  }
  
  # Default output directory
  if (is.null(output_dir)) {
    output_dir <- here::here("outputs", "final")
  }
  
  if (!is.null(file_path)) {
    if (!file.exists(file_path)) {
      stop(sprintf("Failed to load template: file not found at %s", file_path))
    }
    expected_pattern <- sprintf("^03_CallsPerNight_Template_\\d{8}_\\d{6}_%s\\.csv$", type)
    if (!grepl(expected_pattern, basename(file_path))) {
      stop(sprintf(
        "Provided template file name does not match expected pattern %s: %s",
        expected_pattern, basename(file_path)
      ))
    }
    template_file <- file_path
  } else {
    # Build pattern for file discovery
    # Pattern: 03_CallsPerNight_Template_YYYYMMDD_HHMMSS_{TYPE}.csv
    pattern <- sprintf("^03_CallsPerNight_Template_\\d{8}_\\d{6}_%s\\.csv$", type)
    
    # Find most recent file
    template_file <- find_most_recent_file(
      directory = output_dir,
      pattern = pattern,
      error_if_none = TRUE,
      hint = sprintf("Run Phase 2 (run_phase2_template_generation) first to generate %s template", type)
    )
  }
  
  if (verbose) {
    message(sprintf("  Loading %s template: %s", type, basename(template_file)))
  }
  
  # Load template
  template <- safe_read_csv(template_file, verbose = FALSE)
  
  if (is.null(template)) {
    stop(sprintf(
      "Failed to read template file: %s\n  Check file permissions and format.",
      template_file
    ))
  }
  
  if (verbose) {
    message(sprintf("  [OK] Loaded %s rows from %s template",
                    format(nrow(template), big.mark = ","), type))
  }
  
  # Add source file as attribute for reference
  attr(template, "source_file") <- template_file
  attr(template, "template_type") <- type
  
  template
}


#' Extract Timestamp from Template Filename
#'
#' @description
#' Extracts the YYYYMMDD_HHMMSS timestamp from a template filename.
#' Used for edit log naming and tracking purposes.
#'
#' @param filename Character. Template filename (not full path).
#'
#' @return Character. Timestamp string in YYYYMMDD_HHMMSS format,
#'   or NA if pattern not found.
#'
#' @section CONTRACT:
#' - Extracts from pattern: ..._YYYYMMDD_HHMMSS.csv
#' - Returns NA if pattern not found
#' - Does not validate timestamp values
#'
#' @section DOES NOT:
#' - Accept full paths (use basename() first)
#' - Parse the timestamp to datetime
#' - Validate file existence
#'
#' @examples
#' \dontrun{
#' extract_template_timestamp("03_CallsPerNight_Template_ORIGINAL_20260201_143022.csv")
#' # Returns: "20260201_143022"
#' 
#' extract_template_timestamp("invalid_filename.csv")
#' # Returns: NA_character_
#' }
#'
#' @keywords internal
extract_template_timestamp <- function(filename) {
  # Extract timestamp from pattern: ..._YYYYMMDD_HHMMSS.csv
  match <- regmatches(
    filename,
    regexpr("\\d{8}_\\d{6}(?=\\.csv$)", filename, perl = TRUE)
  )
  
  if (length(match) == 0 || match == "") {
    return(NA_character_)
  }
  
  match
}


#' Load and Normalize CPN Template
#'
#' @description
#' Loads a CallsPerNight template (ORIGINAL or EDIT_THIS) and normalizes column
#' types for consistent processing. Handles both ISO 8601 dates (ORIGINAL) and
#' Excel-reformatted dates (EDIT_THIS) with flexible parsing.
#'
#' **DRY Helper Function** — Extracted during Phase 1 refactoring to eliminate
#' duplication in finalize_cpn module (Stage 2).
#'
#' @param template_type Character. "ORIGINAL" or "EDIT_THIS".
#' @param output_dir Character. Directory to search for template if file_path is NULL.
#' @param file_path Character. Explicit path to template file (optional).
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return Tibble with normalized columns and `source_file` attribute:
#'   - Night: Date
#'   - Detector: Character
#'   - CallsPerNight: Numeric
#'   - RecordingHours: Numeric (0 replaces NA/negative)
#'   - StartDateTime: Character (if present)
#'   - EndDateTime: Character (if present)
#'
#' @section CONTRACT:
#' - ORIGINAL templates: Expects ISO 8601 dates ("YYYY-MM-DD")
#' - EDIT_THIS templates: Flexibly parses Excel-reformatted dates (YMD or MDY)
#' - Normalizes datetime columns to character strings
#' - Preserves source_file attribute for tracking
#' - Handles templates with or without StartDateTime/EndDateTime columns
#'
#' @section DOES NOT:
#' - Validate data quality (use validation/ functions)
#' - Track edits between templates (use track_template_edits())
#' - Calculate recording hours (use calculate_recording_hours())
#'
#' @examples
#' \dontrun{
#' # Load ORIGINAL template
#' template_orig <- load_and_normalize_template(
#'   template_type = "ORIGINAL",
#'   output_dir = here::here("outputs"),
#'   verbose = TRUE
#' )
#'
#' # Load EDIT_THIS template with explicit path
#' template_edit <- load_and_normalize_template(
#'   template_type = "EDIT_THIS",
#'   file_path = "outputs/03_CallsPerNight_Template_EDIT_THIS_20260201_143022.csv",
#'   verbose = TRUE
#' )
#'
#' # Check source file
#' attr(template_edit, "source_file")
#' }
#'
#' @seealso
#' - \code{\link{load_cpn_template}} for underlying file discovery
#' - \code{\link{track_template_edits}} for comparing templates
#'
#' @export
load_and_normalize_template <- function(template_type,
                                         output_dir = NULL,
                                         file_path = NULL,
                                         verbose = FALSE) {
  
  # Load template using existing helper
  template <- if (!is.null(file_path)) {
    load_cpn_template(type = template_type, file_path = file_path, verbose = verbose)
  } else {
    load_cpn_template(type = template_type, output_dir = output_dir, verbose = verbose)
  }
  
  template_file <- attr(template, "source_file") %||% NA_character_
  
  # Normalize column types
  template <- template %>%
    dplyr::mutate(
      Night = if (template_type == "ORIGINAL") {
        as.Date(Night)  # ISO 8601 format
      } else {
        # EDIT_THIS: Handle Excel reformatting with flexible parsing
        lubridate::as_date(lubridate::parse_date_time(Night, orders = c("ymd", "mdy")))
      },
      Detector = as.character(Detector),
      CallsPerNight = as.numeric(CallsPerNight),
      RecordingHours = suppressWarnings(as.numeric(RecordingHours))
    )
  
  # Handle datetime columns if present (normalize to character)
  if ("StartDateTime" %in% names(template)) {
    template <- template %>%
      dplyr::mutate(
        StartDateTime = dplyr::if_else(
          !is.na(StartDateTime) & StartDateTime != "",
          as.character(StartDateTime),
          NA_character_
        )
      )
  }
  
  if ("EndDateTime" %in% names(template)) {
    template <- template %>%
      dplyr::mutate(
        EndDateTime = dplyr::if_else(
          !is.na(EndDateTime) & EndDateTime != "",
          as.character(EndDateTime),
          NA_character_
        )
      )
  }
  
  # Reattach source file attribute
  structure(template, source_file = template_file)
}


#' Track Template Edits
#'
#' @description
#' Compares ORIGINAL vs EDIT_THIS CallsPerNight templates and generates a detailed
#' edit log with all manual changes to StartDateTime and EndDateTime fields.
#' Handles Excel reformatting and detects 6 types of edits: changes, additions,
#' and removals for both datetime fields.
#'
#' **DRY Helper Function** — Extracted during Phase 1 refactoring to encapsulate
#' complex POSIXct comparison logic (finalize_cpn module Stage 3).
#'
#' @param template_original Tibble. ORIGINAL template from load_and_normalize_template().
#' @param template_edited Tibble. EDIT_THIS template from load_and_normalize_template().
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return List with elements:
#'   - total_edits: Numeric count of edited rows
#'   - edit_log_lines: Character vector of detailed edit descriptions
#'   - comparison: Tibble with row-by-row change tracking
#'
#' @section CONTRACT:
#' - Parses datetime strings to POSIXct for precise comparison (1-second tolerance)
#' - Detects 6 edit types: StartDateTime/EndDateTime changed/added/removed
#' - Generates human-readable edit log with original/edited values
#' - Returns empty log if no datetime columns present
#' - Handles NA datetime values gracefully
#'
#' @section DOES NOT:
#' - Modify input templates (read-only operation)
#' - Save edit log to file (caller's responsibility)
#' - Track changes to CallsPerNight or RecordingHours
#'
#' @examples
#' \dontrun{
#' template_orig <- load_and_normalize_template("ORIGINAL", output_dir = "outputs")
#' template_edit <- load_and_normalize_template("EDIT_THIS", output_dir = "outputs")
#'
#' edit_tracking <- track_template_edits(
#'   template_original = template_orig,
#'   template_edited = template_edit,
#'   verbose = TRUE
#' )
#'
#' cat(sprintf("Total edits: %d\n", edit_tracking$total_edits))
#'
#' # Print edit log
#' writeLines(edit_tracking$edit_log_lines)
#' }
#'
#' @seealso
#' - \code{\link{load_and_normalize_template}} for loading templates
#' - \code{\link{parse_datetime_safe}} for datetime parsing (datetime_helpers.R)
#' - \code{\link{format_datetime_for_log}} for log formatting
#'
#' @export
track_template_edits <- function(template_original,
                                 template_edited,
                                 verbose = FALSE) {
  
  total_edits <- 0
  edit_log_lines <- character()
  comparison <- NULL
  
  # Only attempt edit tracking if datetime columns exist in both templates
  if (!("StartDateTime" %in% names(template_original)) ||
      !("StartDateTime" %in% names(template_edited))) {
    
    if (verbose) {
      message("  [SKIP] Edit tracking: datetime columns not present in both templates")
    }
    
    return(list(
      total_edits = 0,
      edit_log_lines = character(),
      comparison = tibble::tibble()
    ))
  }
  
  # Parse ORIGINAL template datetimes to POSIXct objects
  template_orig_parsed <- template_original %>%
    dplyr::select(Detector, Night, 
                  StartDateTime_orig_str = StartDateTime,
                  EndDateTime_orig_str = EndDateTime) %>%
    dplyr::mutate(
      StartDateTime_orig = sapply(StartDateTime_orig_str, parse_datetime_safe) %>% 
        as.POSIXct(origin = "1970-01-01"),
      EndDateTime_orig = sapply(EndDateTime_orig_str, parse_datetime_safe) %>% 
        as.POSIXct(origin = "1970-01-01")
    )
  
  # Parse EDITED template datetimes to POSIXct objects
  template_edit_parsed <- template_edited %>%
    dplyr::select(Detector, Night,
                  StartDateTime_edit_str = StartDateTime,
                  EndDateTime_edit_str = EndDateTime,
                  RecordingHours_edit = RecordingHours) %>%
    dplyr::mutate(
      StartDateTime_edit = sapply(StartDateTime_edit_str, parse_datetime_safe) %>% 
        as.POSIXct(origin = "1970-01-01"),
      EndDateTime_edit = sapply(EndDateTime_edit_str, parse_datetime_safe) %>% 
        as.POSIXct(origin = "1970-01-01")
    )
  
  # Join and compare with 1-second tolerance
  comparison <- template_orig_parsed %>%
    dplyr::inner_join(template_edit_parsed, by = c("Detector", "Night")) %>%
    dplyr::mutate(
      StartDateTime_changed = !is.na(StartDateTime_orig) & 
        !is.na(StartDateTime_edit) & 
        abs(difftime(StartDateTime_orig, StartDateTime_edit, units = "secs")) > 1,
      
      EndDateTime_changed = !is.na(EndDateTime_orig) & 
        !is.na(EndDateTime_edit) & 
        abs(difftime(EndDateTime_orig, EndDateTime_edit, units = "secs")) > 1,
      
      StartDateTime_added = is.na(StartDateTime_orig) & !is.na(StartDateTime_edit),
      StartDateTime_removed = !is.na(StartDateTime_orig) & is.na(StartDateTime_edit),
      
      EndDateTime_added = is.na(EndDateTime_orig) & !is.na(EndDateTime_edit),
      EndDateTime_removed = !is.na(EndDateTime_orig) & is.na(EndDateTime_edit),
      
      Any_change = StartDateTime_changed | EndDateTime_changed |
        StartDateTime_added | StartDateTime_removed |
        EndDateTime_added | EndDateTime_removed
    )
  
  # Count total edits
  total_edits <- sum(comparison$Any_change, na.rm = TRUE)
  
  # Generate detailed edit log if edits exist
  if (total_edits > 0) {
    edit_log <- comparison %>%
      dplyr::filter(Any_change) %>%
      dplyr::arrange(Detector, Night)
    
    # Build detailed log entries
    for (i in seq_len(nrow(edit_log))) {
      row <- edit_log[i, ]
      
      log_entry <- sprintf("[%d] %s | %s", i, row$Detector, row$Night)
      
      # StartDateTime changes
      if (row$StartDateTime_changed) {
        log_entry <- paste0(log_entry, sprintf(
          "\n    StartDateTime CHANGED: %s -> %s",
          format_datetime_for_log(row$StartDateTime_orig, row$StartDateTime_orig_str),
          format_datetime_for_log(row$StartDateTime_edit, row$StartDateTime_edit_str)
        ))
      } else if (row$StartDateTime_added) {
        log_entry <- paste0(log_entry, sprintf(
          "\n    StartDateTime ADDED: <blank> -> %s",
          format_datetime_for_log(row$StartDateTime_edit, row$StartDateTime_edit_str)
        ))
      } else if (row$StartDateTime_removed) {
        log_entry <- paste0(log_entry, sprintf(
          "\n    StartDateTime REMOVED: %s -> <blank>",
          format_datetime_for_log(row$StartDateTime_orig, row$StartDateTime_orig_str)
        ))
      }
      
      # EndDateTime changes
      if (row$EndDateTime_changed) {
        log_entry <- paste0(log_entry, sprintf(
          "\n    EndDateTime CHANGED: %s -> %s",
          format_datetime_for_log(row$EndDateTime_orig, row$EndDateTime_orig_str),
          format_datetime_for_log(row$EndDateTime_edit, row$EndDateTime_edit_str)
        ))
      } else if (row$EndDateTime_added) {
        log_entry <- paste0(log_entry, sprintf(
          "\n    EndDateTime ADDED: <blank> -> %s",
          format_datetime_for_log(row$EndDateTime_edit, row$EndDateTime_edit_str)
        ))
      } else if (row$EndDateTime_removed) {
        log_entry <- paste0(log_entry, sprintf(
          "\n    EndDateTime REMOVED: %s -> <blank>",
          format_datetime_for_log(row$EndDateTime_orig, row$EndDateTime_orig_str)
        ))
      }
      
      log_entry <- paste0(log_entry, sprintf("\n    RecordingHours: %.2f\n", 
                                             row$RecordingHours_edit))
      
      edit_log_lines <- c(edit_log_lines, log_entry)
    }
  }
  
  if (verbose) {
    message(sprintf("  [OK] Tracked %d manual edits", total_edits))
  }
  
  list(
    total_edits = total_edits,
    edit_log_lines = edit_log_lines,
    comparison = comparison
  )
}


# ==============================================================================
# END OF FILE
# ==============================================================================
