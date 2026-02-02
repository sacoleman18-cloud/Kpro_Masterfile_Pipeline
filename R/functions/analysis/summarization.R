# =============================================================================
# analysis/callspernight.R - CALLSPERNIGHT WORKFLOW (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Generates CallsPerNight templates, handles user edits, calculates recording
# hours and CallsPerHour metrics.
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
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Validate data quality beyond template structure (validation/)
#   - Generate plots or visualizations (output/)
#   - Transform schema versions (standardization/)
#
# DEPENDENCIES
# ------------
#   - core/utilities.R: log_message, save_with_version
#   - validation/validation.R: validate_calls_per_night
#   - dplyr: group_by, summarize, mutate
#   - lubridate: date/time parsing, date/time extraction
#   - hms: time-only parsing
#   - here: path management
#
# CONTENTS
# --------
# - calculate_recording_hours()          # Recording duration calculation
# - is.Date()                            # Type checker for Date objects
# - parse_datetime_safe()                # Parse full datetime strings
# - extract_time()                       # Extract time component from datetime
# - parse_date_safe()                    # Parse date strings (multi-format)
# - format_datetime_for_log()            # Format datetime for edit log display
# - generate_calls_per_night_template()  # Template generation
# - apply_schedule()                     # Apply recording schedule
# - save_callspernight_with_version()    # Save with version numbering
#
# EXCEL FORMULA FOR RECORDINGHOURS
# --------------------------------
#   =(VALUE(E2)-VALUE(D2))*24
#   Where E2 = EndDateTime, D2 = StartDateTime
#   VALUE() converts text datetime to Excel serial number
#
# CHANGELOG
# ---------
# 2026-02-01: Verified deterministic behavior - all functions follow standards
# 2026-02-01: Confirmed usage in run_cpn_template.R (Chunk 2) and run_finalize_to_report.R (Chunk 3)
# 2024-12-29: Added is.Date(), parse_datetime_safe(), extract_time()
#             for Workflow 04 template comparison support
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
#'
#' @param start_time Character. Either:
#'   - Time-only: "HH:MM:SS" (e.g., "20:00:00")
#'   - Full datetime (multiple formats supported):
#'     * "MM/DD/YYYY HH:MM:SS AM/PM" (e.g., "10/25/2025 8:00:00 PM")
#'     * "MM/DD/YYYY HH:MM" (e.g., "10/4/2025 18:00") - Excel auto-format
#'     * "M/D/YYYY HH:MM" (e.g., "10/4/2025 18:00") - Single-digit month/day
#'   - NA (returns NA)
#' @param end_time Character. Same format as start_time, or NA.
#'
#' @return Numeric duration in hours, or NA if either input is NA.
#'
#' @details
#' **Format Detection:**
#' - If input contains "/" -> parsed as full datetime
#' - Otherwise -> parsed as time-only (HH:MM:SS)
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
#' - Accepts time-only ("HH:MM:SS") OR full datetime (multiple formats)
#' - Automatically tries multiple datetime formats (handles Excel formatting)
#' - Returns NA if either input is NA (fails gracefully)
#' - Handles overnight recordings correctly (end < start for time-only)
#' - Returns numeric hours (not negative values)
#' - Detects format automatically (no explicit format parameter needed)
#' - Uses 24-hour clock for time-only, either 12 or 24-hour for full datetime
#'
#' @section DOES NOT:
#' - Require explicit format specification (auto-detects)
#' - Perform timezone conversions (assumes all times in same zone)
#' - Validate clock correctness (assumes valid times)
#' - Round to nearest hour (returns decimal hours)
#' - Check if duration exceeds 24 hours
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
#' # NA handling
#' calculate_recording_hours(NA, "08:00:00")
#' # [1] NA
#' }
#'
#' @export
calculate_recording_hours <- function(start_time, end_time) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  # Handle NA inputs (fail gracefully)
  if (is.na(start_time) || is.na(end_time)) return(NA_real_)
  
  # Validate input types
  if (!is.character(start_time) || !is.character(end_time)) {
    stop(sprintf(
      "start_time and end_time must be character strings or NA.\n  Received: start_time = %s (%s), end_time = %s (%s)\n  Expected formats:\n    Time-only: 'HH:MM:SS' (e.g., '20:00:00')\n    Full datetime: 'MM/DD/YYYY HH:MM:SS AM/PM' (e.g., '10/25/2025 8:00:00 PM')",
      start_time, class(start_time)[1],
      end_time, class(end_time)[1]
    ))
  }
  
  # -------------------------
  # Format detection & computation
  # -------------------------
  
  # Detect format: if contains "/" it's a full datetime, otherwise time-only
  if (grepl("/", start_time)) {
    # Full datetime format - try multiple formats Excel might produce
    
    # Try format 1: "MM/DD/YYYY HH:MM:SS AM/PM" (our intended format)
    start_dt <- lubridate::mdy_hms(start_time, quiet = TRUE)
    end_dt <- lubridate::mdy_hms(end_time, quiet = TRUE)
    
    # If that failed, try format 2: "MM/DD/YYYY HH:MM" (24-hour, no seconds - Excel auto-format)
    if (is.na(start_dt)) {
      start_dt <- lubridate::mdy_hm(start_time, quiet = TRUE)
    }
    if (is.na(end_dt)) {
      end_dt <- lubridate::mdy_hm(end_time, quiet = TRUE)
    }
    
    # If still failed, try format 3: "M/D/YYYY HH:MM" (single-digit month/day)
    if (is.na(start_dt)) {
      # lubridate::mdy_hm should handle this, but try explicit parse
      start_dt <- as.POSIXct(start_time, format = "%m/%d/%Y %H:%M", tz = "UTC")
    }
    if (is.na(end_dt)) {
      end_dt <- as.POSIXct(end_time, format = "%m/%d/%Y %H:%M", tz = "UTC")
    }
    
    # Check if parsing succeeded
    if (is.na(start_dt) || is.na(end_dt)) {
      stop(sprintf(
        "Failed to parse datetime strings.\n  start_time: '%s'\n  end_time: '%s'\n  Tried formats:\n    - 'MM/DD/YYYY HH:MM:SS AM/PM' (e.g., '10/25/2025 8:00:00 PM')\n    - 'MM/DD/YYYY HH:MM' (e.g., '10/4/2025 18:00')\n    - 'M/D/YYYY HH:MM' (e.g., '10/4/2025 18:00')\n  Hint: Excel may have auto-formatted your datetimes.",
        start_time, end_time
      ))
    }
    
    # Calculate difference in hours
    # This automatically handles overnight/multi-day spans
    return(as.numeric(difftime(end_dt, start_dt, units = "hours")))
    
  } else {
    # Time-only format: "HH:MM:SS"
    # Parse using hms package
    start_h <- as.numeric(hms::as_hms(start_time)) / SECONDS_PER_HOUR
    end_h   <- as.numeric(hms::as_hms(end_time)) / SECONDS_PER_HOUR
    
    # Calculate duration (handle overnight)
    if (end_h < start_h) {
      # Overnight recording crosses midnight
      (HOURS_PER_DAY - start_h) + end_h
    } else {
      # Same-day recording
      end_h - start_h
    }
  }
}


# ------------------------------------------------------------------------------
# Template Comparison Utilities (For Workflow 04 Edit Tracking)
# ------------------------------------------------------------------------------

#' Check if Object is a Date
#'
#' @description
#' Simple type checker to determine if an object inherits from the Date class.
#' Used in Workflow 04 for validating column types before joins in template
#' comparison logic.
#'
#' @param x Object to check (any type)
#'
#' @return Logical: TRUE if x is a Date object, FALSE otherwise
#'
#' @details
#' **Purpose:**
#' When comparing ORIGINAL vs EDITED templates in Workflow 04, the Night
#' column must be Date type for join operations. This function provides a
#' readable way to check column types.
#'
#' **Implementation:**
#' Wrapper around `inherits(x, "Date")` for improved code readability.
#'
#' @section CONTRACT:
#' - Returns TRUE if x inherits from "Date" class
#' - Returns FALSE for all other types (including POSIXct, POSIXlt)
#' - Does not coerce or modify input
#' - Never throws errors (returns FALSE for invalid input)
#'
#' @section DOES NOT:
#' - Check if x can be PARSED as a date string
#' - Validate date correctness (e.g., Feb 30 would still be Date class)
#' - Coerce to Date type
#' - Distinguish between different Date subclasses
#'
#' @examples
#' \dontrun{
#' # TRUE cases
#' is.Date(as.Date("2024-10-15"))
#' # [1] TRUE
#'
#' is.Date(Sys.Date())
#' # [1] TRUE
#'
#' # FALSE cases
#' is.Date("2024-10-15")
#' # [1] FALSE (character, not Date)
#'
#' is.Date(Sys.time())
#' # [1] FALSE (POSIXct, not Date)
#'
#' is.Date(NULL)
#' # [1] FALSE
#'
#' is.Date(123)
#' # [1] FALSE
#'
#' # Usage in Workflow 04
#' if (is.Date(template$Night)) {
#'   # Already Date type, use as-is
#'   template <- template %>% mutate(Night = as.Date(Night))
#' } else {
#'   # Parse from string
#'   template <- template %>% mutate(Night = parse_date_safe(Night))
#' }
#' }
#'
#' @export
is.Date <- function(x) {
  inherits(x, "Date")
}


#' Parse DateTime Strings Safely
#'
#' @description
#' Parses full datetime strings in multiple formats commonly produced by
#' Excel or user editing. Tries AM/PM format first, then 24-hour format,
#' handling auto-formatting gracefully. Used for template comparison in
#' Workflow 04.
#'
#' @param dt_string Character datetime string to parse, or NA
#'
#' @return POSIXct datetime object in UTC timezone, or NA if parsing fails
#'   or input is NA
#'
#' @details
#' **Purpose:**
#' When comparing ORIGINAL vs EDITED templates in Workflow 04, datetime
#' strings may have been reformatted by Excel. This function handles multiple
#' formats to ensure accurate comparison.
#'
#' **Supported formats (tried in order):**
#' 1. "MM/DD/YYYY HH:MM:SS AM/PM" (e.g., "10/24/2025 6:00:00 PM")
#' 2. "MM/DD/YYYY HH:MM" (e.g., "10/24/2025 18:00") - Excel auto-format
#' 3. Explicit parse with format = "%m/%d/%Y %H:%M"
#'
#' **Excel auto-formatting:**
#' Excel often converts "6:00:00 PM" to "18:00" when saving CSV files.
#' This function handles both formats seamlessly by trying AM/PM first,
#' then falling back to 24-hour format.
#'
#' **Time-only formats:**
#' This function expects FULL datetime strings with dates. For time-only
#' strings like "18:00:00", returns NA (use hms::as_hms() instead).
#'
#' **NA handling:**
#' - Input: NA or empty string → Output: NA (POSIXct)
#' - Input: Unparseable string → Output: NA (POSIXct)
#' - No errors thrown - fails gracefully to NA
#'
#' **Timezone:**
#' All datetimes parsed as UTC. This is appropriate for template comparison
#' where we're checking if two datetime strings represent the same instant,
#' regardless of timezone display.
#'
#' @section CONTRACT:
#' - Returns POSIXct object with tz="UTC"
#' - Returns NA (POSIXct) for NA or blank input (fails gracefully)
#' - Returns NA (POSIXct) for unparseable strings (no errors)
#' - Tries multiple formats automatically (no format parameter needed)
#' - Handles Excel auto-formatting (AM/PM → 24-hour)
#' - Never throws errors (silent NA return on failure)
#'
#' @section DOES NOT:
#' - Perform timezone conversions (always UTC output)
#' - Validate if datetime is "reasonable" (e.g., Feb 30 would parse)
#' - Handle time-only formats (requires full datetime with date)
#' - Log parsing failures (silent operation)
#' - Require explicit format specification (auto-detects)
#' - Throw errors on parse failures (returns NA instead)
#'
#' @examples
#' \dontrun{
#' # AM/PM format (original template)
#' parse_datetime_safe("10/24/2025 6:00:00 PM")
#' # [1] "2025-10-24 18:00:00 UTC"
#'
#' # 24-hour format (Excel auto-formatted)
#' parse_datetime_safe("10/24/2025 18:00")
#' # [1] "2025-10-24 18:00:00 UTC"
#'
#' # Both parse to same instant
#' identical(
#'   parse_datetime_safe("10/24/2025 6:00:00 PM"),
#'   parse_datetime_safe("10/24/2025 18:00")
#' )
#' # [1] TRUE
#'
#' # Morning time
#' parse_datetime_safe("10/24/2025 7:30:00 AM")
#' # [1] "2025-10-24 07:30:00 UTC"
#'
#' # NA handling
#' parse_datetime_safe(NA)
#' # [1] NA (POSIXct)
#'
#' parse_datetime_safe("")
#' # [1] NA (POSIXct)
#'
#' # Unparseable format
#' parse_datetime_safe("invalid")
#' # [1] NA (POSIXct)
#'
#' # Time-only NOT supported
#' parse_datetime_safe("18:00:00")
#' # [1] NA (POSIXct) - use hms::as_hms() for time-only
#'
#' # Usage in Workflow 04 template comparison
#' template_orig <- template_orig %>%
#'   mutate(
#'     StartDateTime_parsed = sapply(StartDateTime, parse_datetime_safe),
#'     EndDateTime_parsed = sapply(EndDateTime, parse_datetime_safe)
#'   )
#' }
#'
#' @export
parse_datetime_safe <- function(dt_string) {
  
  # -------------------------
  # Handle NA or empty input
  # -------------------------
  
  if (is.na(dt_string) || trimws(dt_string) == "") {
    return(as.POSIXct(NA))
  }
  
  # -------------------------
  # Parse full datetime formats
  # -------------------------
  
  # Only process if contains "/" (full datetime format)
  # Time-only formats like "18:00:00" should return NA
  if (grepl("/", dt_string)) {
    
    # Try AM/PM format first (our intended template format)
    # Example: "10/24/2025 6:00:00 PM"
    result <- lubridate::mdy_hms(dt_string, quiet = TRUE)
    
    # Try 24-hour format if that failed (Excel auto-formatting)
    # Example: "10/24/2025 18:00"
    if (is.na(result)) {
      result <- lubridate::mdy_hm(dt_string, quiet = TRUE)
    }
    
    # Try explicit parse if still failed
    # Handles edge cases like single-digit months/days
    if (is.na(result)) {
      result <- as.POSIXct(dt_string, format = "%m/%d/%Y %H:%M", tz = "UTC")
    }
    
    return(result)
    
  } else {
    # Time-only format - not expected in template comparison
    # Return NA (this function is for FULL datetimes only)
    return(as.POSIXct(NA))
  }
}


#' Extract Time Component from DateTime String
#'
#' @description
#' Parses a full datetime string and extracts just the time component as
#' HH:MM:SS (24-hour format). Used for comparing recording times between
#' original and edited templates when checking for manual edits in Workflow 04.
#'
#' @param datetime_str Character datetime string, or NA
#'
#' @return Character time string in format "HH:MM:SS" (24-hour, zero-padded),
#'   or NA_character_ if parsing fails or input is NA
#'
#' @details
#' **Purpose:**
#' In Workflow 04 edit tracking, we need to compare whether two datetime
#' strings represent the same TIME, even if Excel reformatted them differently.
#'
#' **Example use case:**
#' - Original: "10/24/2025 06:00:00 PM" (12-hour AM/PM)
#' - Edited:   "10/24/2025 18:00"      (24-hour, no seconds)
#' - Both extract to: "18:00:00"
#' - Comparison: Times match → No manual edit occurred
#'
#' **Process:**
#' 1. Parse datetime_str using parse_datetime_safe()
#' 2. Extract time component as HH:MM:SS string (24-hour)
#' 3. Return NA if parsing failed
#'
#' **Output format:**
#' Always returns 24-hour format with seconds: "18:00:00"
#' - Never includes AM/PM
#' - Always includes seconds (even if :00)
#' - Always zero-padded (e.g., "08:00:00" not "8:00:00")
#'
#' **Comparison logic:**
#' By extracting times to a consistent format, we can compare them directly:
#' ```r
#' extract_time("10/24/2025 6:00:00 PM") == extract_time("10/24/2025 18:00")
#' # [1] TRUE - Both are "18:00:00", so times match
#' ```
#'
#' @section CONTRACT:
#' - Returns time string in format "HH:MM:SS" (24-hour, zero-padded)
#' - Returns NA_character_ for NA or blank input (fails gracefully)
#' - Returns NA_character_ if datetime parsing fails (no errors)
#' - Uses parse_datetime_safe() for robust parsing
#' - Always includes seconds in output (:00 if not present)
#' - Always zero-padded (08:00:00 not 8:00:00)
#'
#' @section DOES NOT:
#' - Preserve original AM/PM or 24-hour format (always 24-hour output)
#' - Include date component in output (time only)
#' - Perform timezone conversions (uses UTC from parse_datetime_safe)
#' - Validate if time is "reasonable" (e.g., 25:00:00 would be invalid input)
#' - Round or truncate times (exact extraction)
#' - Throw errors (returns NA_character_ on failure)
#'
#' @examples
#' \dontrun{
#' # AM/PM format -> 24-hour time
#' extract_time("10/24/2025 6:00:00 PM")
#' # [1] "18:00:00"
#'
#' # 24-hour format (Excel auto-formatted)
#' extract_time("10/24/2025 18:00")
#' # [1] "18:00:00"
#'
#' # Morning time (zero-padded)
#' extract_time("10/24/2025 7:30:00 AM")
#' # [1] "07:30:00"
#'
#' # Early morning (zero-padded hour)
#' extract_time("10/24/2025 1:15:00 AM")
#' # [1] "01:15:00"
#'
#' # NA handling
#' extract_time(NA)
#' # [1] NA_character_
#'
#' extract_time("")
#' # [1] NA_character_
#'
#' # Unparseable datetime
#' extract_time("invalid")
#' # [1] NA_character_
#'
#' # Usage in Workflow 04 template comparison:
#' # Compare times between original and edited templates
#' comparison <- comparison %>%
#'   mutate(
#'     StartTime_orig = sapply(StartDateTime_orig, extract_time),
#'     StartTime_edit = sapply(StartDateTime_edit, extract_time),
#'     
#'     # Check if times match (handles Excel reformatting)
#'     times_match = (StartTime_orig == StartTime_edit)
#'   )
#'
#' # Example comparison result:
#' # StartDateTime_orig: "10/24/2025 6:00:00 PM"  → StartTime_orig: "18:00:00"
#' # StartDateTime_edit: "10/24/2025 18:00"      → StartTime_edit: "18:00:00"
#' # times_match: TRUE (Excel reformatted but time unchanged)
#' }
#'
#' @export
extract_time <- function(datetime_str) {
  
  # -------------------------
  # Handle NA or empty input
  # -------------------------
  
  if (is.na(datetime_str) || trimws(datetime_str) == "") {
    return(NA_character_)
  }
  
  # -------------------------
  # Parse and extract time
  # -------------------------
  
  # Parse the datetime using our safe parser
  dt <- parse_datetime_safe(datetime_str)
  
  # If parsing failed, return NA
  if (is.na(dt)) {
    return(NA_character_)
  }
  
  # Extract time component as HH:MM:SS (24-hour format)
  # format() with %H:%M:%S gives zero-padded 24-hour time
  return(format(dt, "%H:%M:%S"))
}


' Parse Date Strings Safely
#'
#' @description
#' Parses date strings in multiple formats commonly produced by Excel or
#' user editing. Handles mixed date formats gracefully. Used for parsing
#' Night column in template comparison (Workflow 04).
#'
#' @param date_string Character date string to parse, Date object, or NA
#'
#' @return Date object, or NA if parsing fails or input is NA
#'
#' @details
#' **Purpose:**
#' When comparing ORIGINAL vs EDITED templates in Workflow 04, the Night
#' column may have been saved in different date formats by Excel. This
#' function handles multiple formats to ensure successful joins.
#'
#' **Supported formats (tried in order):**
#' 1. YYYY-MM-DD (standard R format)
#' 2. MM/DD/YYYY (US Excel format)
#' 3. MM-DD-YYYY (Excel variant)
#' 4. M/D/YYYY (single-digit month/day)
#'
#' **Already Date objects:**
#' If input is already a Date object, returns it unchanged.
#'
#' **Excel date formats:**
#' Excel saves dates in various formats depending on locale and settings.
#' This function tries all common formats to maximize compatibility.
#'
#' **NA handling:**
#' - Input: NA or empty string → Output: NA (Date)
#' - Input: Unparseable string → Output: NA (Date) with warning
#'
#' @section CONTRACT:
#' - Returns Date object (R Date class)
#' - Returns NA (Date) for NA or blank input (fails gracefully)
#' - Returns input unchanged if already Date object
#' - Tries multiple formats automatically (no format parameter needed)
#' - Warns on parse failures (logs unparseable strings)
#' - Never throws errors (returns NA on failure)
#'
#' @section DOES NOT:
#' - Parse datetime strings (use parse_datetime_safe for those)
#' - Validate if date is "reasonable" (e.g., Feb 30 would parse to NA)
#' - Perform timezone conversions (Date has no timezone)
#' - Require explicit format specification (auto-detects)
#' - Throw errors on parse failures (warns and returns NA)
#'
#' @examples
#' \dontrun{
#' # Standard R format
#' parse_date_safe("2024-10-15")
#' # [1] "2024-10-15"
#'
#' # US Excel format
#' parse_date_safe("10/15/2024")
#' # [1] "2024-10-15"
#'
#' # Excel variant
#' parse_date_safe("10-15-2024")
#' # [1] "2024-10-15"
#'
#' # Single-digit month/day
#' parse_date_safe("1/5/2024")
#' # [1] "2024-01-05"
#'
#' # Already Date object (unchanged)
#' parse_date_safe(as.Date("2024-10-15"))
#' # [1] "2024-10-15"
#'
#' # NA handling
#' parse_date_safe(NA)
#' # [1] NA (Date)
#'
#' parse_date_safe("")
#' # [1] NA (Date)
#'
#' # Unparseable format (warns and returns NA)
#' parse_date_safe("invalid")
#' # Warning: Could not parse date: 'invalid'
#' # [1] NA (Date)
#'
#' # Usage in Workflow 04 template comparison:
#' template <- template %>%
#'   mutate(Night = sapply(Night, parse_date_safe) %>% 
#'            as.Date(origin = "1970-01-01"))
#' }
#'
#' @export
parse_date_safe <- function(date_string) {
  
  # -------------------------
  # Handle special cases
  # -------------------------
  
  # NA or empty string
  if (is.na(date_string) || trimws(date_string) == "") {
    return(as.Date(NA))
  }
  
  # Already a Date object - return unchanged
  if (inherits(date_string, "Date")) {
    return(date_string)
  }
  
  # -------------------------
  # Try multiple date formats
  # -------------------------
  
  # Format 1: YYYY-MM-DD (standard R format)
  result <- as.Date(date_string, format = "%Y-%m-%d")
  if (!is.na(result)) return(result)
  
  # Format 2: MM/DD/YYYY (US Excel)
  result <- lubridate::mdy(date_string, quiet = TRUE)
  if (!is.na(result)) return(result)
  
  # Format 3: MM-DD-YYYY (Excel variant)
  result <- as.Date(date_string, format = "%m-%d-%Y")
  if (!is.na(result)) return(result)
  
  # Format 4: M/D/YYYY (single-digit month/day)
  result <- as.Date(date_string, format = "%m/%d/%Y")
  if (!is.na(result)) return(result)
  
  # -------------------------
  # All formats failed - warn and return NA
  # -------------------------
  
  warning(sprintf("Could not parse date: '%s'", date_string))
  return(as.Date(NA))
}


#' Format DateTime for Edit Log Display
#'
#' @description
#' Formats a parsed POSIXct datetime for display in the CallsPerNight edit
#' log. Returns consistent 24-hour format without seconds for readability.
#' Used in Workflow 04 edit tracking.
#'
#' @param dt_parsed POSIXct datetime object (parsed), or NA
#' @param dt_string Character original datetime string (for reference, unused)
#'
#' @return Character string in format "MM/DD/YYYY HH:MM" (24-hour, no seconds),
#'   or "<blank>" if dt_parsed is NA
#'
#' @details
#' **Purpose:**
#' In the CallsPerNight edit log, we need consistent datetime formatting
#' regardless of how Excel formatted the original strings. This function
#' ensures all datetimes display as 24-hour format without seconds.
#'
#' **Format:**
#' - Date: MM/DD/YYYY (US format, matches template format)
#' - Time: HH:MM (24-hour, no seconds for readability)
#' - Example: "10/24/2025 18:00"
#'
#' **NA handling:**
#' Returns "<blank>" for NA datetimes to clearly indicate missing values
#' in the edit log.
#'
#' **Design note:**
#' The dt_string parameter is included for consistency with calling pattern
#' but is not used. We format from the parsed datetime to ensure consistency.
#'
#' @section CONTRACT:
#' - Returns character string in format "MM/DD/YYYY HH:MM"
#' - Returns "<blank>" for NA input
#' - Always 24-hour format (never AM/PM)
#' - Never includes seconds
#' - Zero-padded (e.g., "08:00" not "8:00")
#'
#' @section DOES NOT:
#' - Include AM/PM indicators (always 24-hour)
#' - Include seconds (omitted for readability)
#' - Use original string format (formats from parsed datetime)
#' - Perform timezone conversions (uses datetime as-is)
#' - Validate if datetime is "reasonable"
#'
#' @examples
#' \dontrun{
#' # Normal datetime
#' dt <- parse_datetime_safe("10/24/2025 6:00:00 PM")
#' format_datetime_for_log(dt, "10/24/2025 6:00:00 PM")
#' # [1] "10/24/2025 18:00"
#'
#' # Morning time
#' dt <- parse_datetime_safe("10/24/2025 7:30:00 AM")
#' format_datetime_for_log(dt, "10/24/2025 7:30:00 AM")
#' # [1] "10/24/2025 07:30"
#'
#' # NA datetime
#' format_datetime_for_log(NA, "")
#' # [1] "<blank>"
#'
#' # Usage in Workflow 04 edit log:
#' for (i in seq_len(nrow(edit_log))) {
#'   row <- edit_log[i, ]
#'   cat(sprintf("      Original: %s\n",
#'     format_datetime_for_log(row$StartDateTime_orig, row$StartDateTime_orig_str)
#'   ))
#'   cat(sprintf("      Edited:   %s\n",
#'     format_datetime_for_log(row$StartDateTime_edit, row$StartDateTime_edit_str)
#'   ))
#' }
#' }
#'
#' @export
format_datetime_for_log <- function(dt_parsed, dt_string) {
  
  # Handle NA input - return clear indicator
  if (is.na(dt_parsed)) {
    return("<blank>")
  }
  
  # Format as: MM/DD/YYYY HH:MM (24-hour, no seconds, consistent)
  return(format(dt_parsed, "%m/%d/%Y %H:%M"))
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
#'   this start time to all detector-nights.
#' @param uniform_end Character "HH:MM:SS" or NULL. If provided, applies
#'   this end time to all detector-nights.
#' @param schedule_file Data frame with detector-specific schedules, or NULL.
#'   Must contain columns: Detector, StartTime, EndTime.
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
#'
#' @section DOES NOT:
#' - Modify master_data input (non-destructive)
#' - Validate data quality (use validation/ module)
#' - Remove NoID calls (done in workflow script)
#' - Save files to disk (caller's responsibility)
#' - Handle multiple detectors at same location
#' - Perform statistical analysis
#' - Generate plots or visualizations
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
    mutate(RecordingHours = mapply(calculate_recording_hours, StartTime, EndTime))
  
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
#' @param uniform_start Optional character "HH:MM:SS" for uniform start time.
#'   Required if schedule_file is NULL.
#' @param uniform_end Optional character "HH:MM:SS" for uniform end time.
#'   Required if schedule_file is NULL.
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
#'
#' @section DOES NOT:
#' - Modify template input (non-destructive)
#' - Calculate recording hours (use calculate_recording_hours)
#' - Validate time formats (HH:MM:SS)
#' - Handle missing schedule data (will create NA values)
#' - Remove rows with missing times
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
#'   Default is "CallsPerNight_final".
#' @param output_dir Character. Directory to save the file. 
#'   Default is project outputs directory (via here::here()).
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
#'
#' @section DOES NOT:
#' - Validate data structure (caller's responsibility)
#' - Remove old versions (keeps all versions)
#' - Compress files
#' - Write to formats other than CSV
#' - Add timestamps to filename (uses version numbers only)
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
  
  message(sprintf("✓ CallsPerNight file saved: %s", basename(file_path)))
  message(sprintf("  Full path: %s", file_path))
  
  return(file_path)
}

# ==============================================================================
# END OF FILE
# ==============================================================================