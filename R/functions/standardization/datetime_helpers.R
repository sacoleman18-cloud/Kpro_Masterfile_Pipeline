# ==============================================================================
# standardization/datetime_helpers.R - DATETIME UTILITIES (LOCKED CONTRACT)
# ==============================================================================
# PURPOSE
# -------
# Comprehensive datetime/time utilities for parsing, formatting, and converting
# bat acoustic monitoring data. Consolidates all date/time functionality across
# the pipeline including timezone conversion, multi-format parsing, type checking,
# and display formatting.
#
# DATETIME HELPERS CONTRACT
# -------------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Flexible parsing
#    - Handles multiple date formats (YYYY-MM-DD, MM/DD/YYYY, MM-DD-YYYY)
#    - Handles multiple datetime formats (AM/PM, 24-hour, with/without seconds)
#    - Handles time-only formats (HH:MM:SS, HH:MM)
#    - Graceful failure (returns NA instead of errors)
#
# 2. Timezone handling
#    - Converts from UTC to user-specified timezone
#    - Handles DST transitions automatically via lubridate
#    - Creates both UTC and local datetime columns
#    - NO HARDCODED TIMEZONES - user must provide via YAML
#
# 3. Type safety
#    - Type checking functions for Date objects
#    - Safe parsing with fallback to NA
#    - Validation against OlsonNames() for timezones
#
# 4. Excel compatibility
#    - Handles Excel auto-formatting (6:00 PM → 18:00)
#    - Supports multiple date formats from Excel CSV exports
#    - Consistent 24-hour format output for comparisons
#
# 5. Non-destructive operations
#    - Functions return new values (never modify in place)
#    - Original columns preserved in transformations
#    - Silent NA returns for unparseable inputs
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Calculate recording hours or durations (analysis/callspernight.R)
#   - Validate recording schedules (analysis/)
#   - Generate CallsPerNight templates (analysis/)
#   - Filter data by date/time criteria
#   - Modify global timezone settings
#   - Assume any default timezone (always require explicit parameter)
#
# DEPENDENCIES
# ------------
#   - validation/validation.R: assert_data_frame, assert_columns_exist, assert_scalar_string
#   - lubridate: parse_date_time, with_tz, as_date, force_tz, mdy, mdy_hms, mdy_hm
#   - dplyr: mutate, select
#
# WORKFLOW INTEGRATION
# --------------------
# This module is used across multiple workflows:
#   - Workflow 02 (Standardization): convert_datetime_to_local()
#   - Workflow 04 (CPN Finalization): parse_datetime_safe(), extract_time(), parse_date_safe()
#   - Edit tracking: format_datetime_for_log()
#
# CONTENTS
# --------
# Timezone Conversion (for master data):
#   - convert_datetime_to_local()      # Main UTC -> local timezone conversion
#   - is_valid_timezone()              # Timezone validation (internal)
#
# Date/DateTime Parsing (for template comparison):
#   - parse_datetime_safe()            # Parse full datetime strings (multi-format)
#   - parse_date_safe()                # Parse date strings (multi-format)
#   - extract_time()                   # Extract time component from datetime
#
# Type Checking:
#   - is.Date()                        # Check if object is Date class
#
# Formatting:
#   - format_datetime_for_log()        # Format datetime for edit log display
#
# Debugging:
#   - summarize_date_formats()         # Analyze date format patterns (internal)
#
# CHANGELOG
# ---------
# 2026-02-04: MODULE CONSOLIDATION - Created comprehensive datetime helpers module
#             - Moved convert_datetime_to_local() from datetime_conversion.R
#             - Moved 5 template helper functions from callspernight.R:
#               * is.Date(), parse_datetime_safe(), extract_time()
#               * parse_date_safe(), format_datetime_for_log()
#             - Moved debugging helpers: is_valid_timezone(), summarize_date_formats()
#             - Unified all datetime functionality in single module
#             - Renamed file from datetime_conversion.R to datetime_helpers.R
# 2026-01-30: Refactored to use centralized assert_* functions from validation.R
# 2026-01-26: Added verbose parameter to convert_datetime_to_local() (default: FALSE)
# 2024-12-29: Added template comparison helpers for Workflow 04
# 2024-12-27: Made target_tz REQUIRED (no default timezone)
#
# ==============================================================================


# ------------------------------------------------------------------------------
# Timezone Conversion (Master Data Processing)
# ------------------------------------------------------------------------------

#' Convert Date/Time Columns to User's Local Timezone
#'
#' @description
#' Parses date and time columns, combines them into datetime, and converts from 
#' UTC to user-specified timezone. Creates both UTC and local datetime columns
#' with derived time components. Used in Workflow 02 standardization.
#'
#' @param df Data frame containing date and time columns
#' @param target_tz Target timezone from YAML config (REQUIRED)
#' @param date_col Name of date column (default: "date")
#' @param time_col Name of time column (default: "time")
#' @param source_tz Source timezone (default: "UTC")
#' @param verbose Logical. Print status messages? Default: FALSE
#'
#' @return Data frame with datetime columns:
#'   - DateTime_UTC: Combined datetime in UTC (POSIXct)
#'   - DateTime_local: Datetime in user's local timezone (POSIXct)
#'   - Date_local: Date in user's local timezone (Date)
#'   - Time_local: Time in user's local timezone (character HH:MM:SS)
#'   - Hour_local: Hour in user's local timezone (integer 0-23)
#'
#' @section CONTRACT:
#' - Requires target_tz parameter (no default timezone)
#' - Validates timezone against OlsonNames()
#' - Creates DateTime_UTC and DateTime_local columns
#' - Handles mixed date formats automatically
#' - Removes intermediate parsing columns
#' - Preserves original date/time columns
#'
#' @section DOES NOT:
#' - Use hardcoded timezones
#' - Modify original date/time columns
#' - Filter rows based on date/time
#' - Calculate recording durations
#'
#' @examples
#' \dontrun{
#' # Load timezone from YAML
#' params <- load_study_parameters('inst/config/study_parameters.yaml')
#' target_tz <- params$study_parameters$timezone
#'
#' # Convert to local timezone
#' kpro_master <- convert_datetime_to_local(
#'   raw_combined,
#'   target_tz = target_tz,
#'   verbose = TRUE
#' )
#' }
#'
#' @export
convert_datetime_to_local <- function(df,
                                      target_tz,
                                      date_col = "date",
                                      time_col = "time",
                                      source_tz = "UTC",
                                      verbose = FALSE) {
  
  # ----------------------------------------------------------------------------
  # Input validation (using centralized assertions)
  # ----------------------------------------------------------------------------
  
  assert_data_frame(df, "df")
  
  if (nrow(df) == 0) {
    warning("Empty data frame provided, returning as-is")
    return(df)
  }
  
  # CRITICAL: Validate target_tz is provided
  if (missing(target_tz)) {
    stop(
      "target_tz is REQUIRED. Load from YAML configuration:\n",
      "  params <- load_study_parameters('inst/config/study_parameters.yaml')\n",
      "  target_tz <- params$study_parameters$timezone"
    )
  }
  
  assert_scalar_string(target_tz, "target_tz")
  
  # Validate timezone against OlsonNames
  if (!target_tz %in% OlsonNames()) {
    stop(sprintf(
      "Invalid timezone: '%s'\n  Use OlsonNames() to see valid timezone names.",
      target_tz
    ))
  }
  
  # Check required columns exist
  assert_columns_exist(df, c(date_col, time_col), source_hint = "raw data ingestion")
  
  # ----------------------------------------------------------------------------
  # Parse dates
  # ----------------------------------------------------------------------------
  
  if (verbose) message("  Parsing date column (handling mixed formats)...")
  df <- df %>%
    dplyr::mutate(
      date_parsed = lubridate::parse_date_time(
        .data[[date_col]],
        orders = c("ymd", "Ymd", "ymd HMS", "mdy", "dmy"),
        quiet = TRUE
      )
    )
  
  failed_dates <- sum(is.na(df$date_parsed) & !is.na(df[[date_col]]))
  if (failed_dates > 0) {
    warning(sprintf("%s date(s) failed to parse", format(failed_dates, big.mark = ",")))
  }
  if (verbose) {
    message(sprintf("    [OK] Parsed %s dates", format(nrow(df) - failed_dates, big.mark = ",")))
  }
  
  # ----------------------------------------------------------------------------
  # Parse times
  # ----------------------------------------------------------------------------
  
  if (verbose) message("  Parsing time column...")
  df <- df %>%
    dplyr::mutate(
      time_parsed = lubridate::parse_date_time(
        .data[[time_col]],
        orders = c("HMS", "HM"),
        quiet = TRUE
      )
    )
  
  failed_times <- sum(is.na(df$time_parsed) & !is.na(df[[time_col]]))
  if (failed_times > 0) {
    warning(sprintf("%s time(s) failed to parse", format(failed_times, big.mark = ",")))
  }
  if (verbose) {
    message(sprintf("    [OK] Parsed %s times", format(nrow(df) - failed_times, big.mark = ",")))
  }
  
  # ----------------------------------------------------------------------------
  # Combine date + time into DateTime_UTC
  # ----------------------------------------------------------------------------
  
  if (verbose) message(sprintf("  Combining date and time (assuming %s timezone)...", source_tz))
  df <- df %>%
    dplyr::mutate(
      DateTime_UTC_temp = lubridate::ymd_hms(
        paste(
          lubridate::as_date(date_parsed),
          format(time_parsed, "%H:%M:%S")
        ),
        tz = source_tz,
        quiet = TRUE
      )
    )
  
  # Force UTC timezone attribute explicitly
  df <- df %>%
    dplyr::mutate(
      DateTime_UTC = lubridate::force_tz(DateTime_UTC_temp, tzone = "UTC")
    )
  
  if (verbose) message("    [OK] Created DateTime_UTC in UTC")
  
  # ----------------------------------------------------------------------------
  # Convert to target timezone
  # ----------------------------------------------------------------------------
  
  if (verbose) message(sprintf("  Converting UTC -> %s...", target_tz))
  df <- df %>%
    dplyr::mutate(
      # Convert to local timezone (preserves instant, changes display)
      DateTime_local = lubridate::with_tz(DateTime_UTC, tzone = target_tz),
      
      # Extract local date (may differ from UTC date!)
      Date_local = lubridate::as_date(DateTime_local),
      
      # Extract local time components
      Time_local = format(DateTime_local, "%H:%M:%S"),
      Hour_local = as.integer(lubridate::hour(DateTime_local))
    )
  
  if (verbose) message(sprintf("    [OK] Converted to %s", target_tz))
  
  # ----------------------------------------------------------------------------
  # Verify timezone conversion worked
  # ----------------------------------------------------------------------------
  
  if (verbose) {
    sample_utc <- df$DateTime_UTC[1]
    sample_local <- df$DateTime_local[1]
    
    if (!is.na(sample_utc) && !is.na(sample_local)) {
      utc_tz <- attr(sample_utc, "tzone")
      local_tz <- attr(sample_local, "tzone")
      
      message("    Verification:")
      message(sprintf("      UTC:   %s (tz=%s)", sample_utc, utc_tz))
      message(sprintf("      Local: %s (tz=%s)", sample_local, local_tz))
    }
  }
  
  # ----------------------------------------------------------------------------
  # Check for DST transitions
  # ----------------------------------------------------------------------------
  
  if (verbose) {
    date_range <- range(df$Date_local, na.rm = TRUE)
    if (any(lubridate::month(date_range) %in% c(3, 11))) {
      message("    [!] Data spans potential DST transition months")
    }
  }
  
  # ----------------------------------------------------------------------------
  # Clean up intermediate columns
  # ----------------------------------------------------------------------------
  
  df <- df %>%
    dplyr::select(-date_parsed, -time_parsed, -DateTime_UTC_temp)
  
  # ----------------------------------------------------------------------------
  # Summary
  # ----------------------------------------------------------------------------
  
  if (verbose) {
    total_success <- sum(!is.na(df$DateTime_local))
    message(sprintf("\n  DateTime conversion complete: %s successful", 
                    format(total_success, big.mark = ",")))
  }
  
  df
}


# ------------------------------------------------------------------------------
# Type Checking
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
#' @return Logical scalar: TRUE if x inherits from Date class, FALSE otherwise
#'
#' @section CONTRACT:
#' - Returns TRUE if x inherits from "Date" class
#' - Returns FALSE for all other types (including POSIXct, POSIXlt)
#' - Does not coerce or modify input
#' - Never throws errors (returns FALSE for invalid input)
#' - Returns single logical value (not vectorized)
#'
#' @section DOES NOT:
#' - Check if x can be PARSED as a date string
#' - Validate date correctness (e.g., Feb 30 would still be Date class)
#' - Coerce to Date type
#' - Work element-wise on vectors (checks the vector's class, not elements)
#'
#' @examples
#' \dontrun{
#' is.Date(as.Date("2024-10-15"))  # TRUE
#' is.Date("2024-10-15")           # FALSE (character, not Date)
#' is.Date(Sys.time())             # FALSE (POSIXct, not Date)
#' 
#' # Usage in template comparison
#' if (is.Date(template$Night)) {
#'   template_ready <- template
#' } else {
#'   template <- template %>% mutate(Night = parse_date_safe(Night))
#' }
#' }
#'
#' @export
is.Date <- function(x) {
  inherits(x, "Date")
}


# ------------------------------------------------------------------------------
# DateTime Parsing (Template Comparison)
# ------------------------------------------------------------------------------

#' Parse DateTime Strings Safely
#'
#' @description
#' Parses full datetime strings in multiple formats commonly produced by
#' Excel or user editing. Tries AM/PM format first, then 24-hour format,
#' handling auto-formatting gracefully. Used for template comparison in
#' Workflow 04.
#'
#' @param dt_string Character scalar datetime string to parse, or NA
#'
#' @return POSIXct datetime object in UTC timezone, or NA (POSIXct) if 
#'   parsing fails or input is NA
#'
#' @details
#' **Supported formats (tried in order):**
#' 1. "MM/DD/YYYY HH:MM:SS AM/PM" (e.g., "10/24/2025 6:00:00 PM")
#' 2. "MM/DD/YYYY HH:MM" (e.g., "10/24/2025 18:00") - Excel auto-format
#' 3. Explicit parse with format = "%m/%d/%Y %H:%M"
#'
#' **Excel auto-formatting:**
#' Excel often converts "6:00:00 PM" to "18:00" when saving CSV files.
#' This function handles both formats seamlessly.
#'
#' @section CONTRACT:
#' - Returns POSIXct object with tz="UTC"
#' - Returns NA (POSIXct) for NA or blank input (fails gracefully)
#' - Tries multiple formats automatically (no format parameter needed)
#' - Handles Excel auto-formatting (AM/PM → 24-hour)
#' - Never throws errors (silent NA return on failure)
#' - Non-vectorized (use sapply for vectors)
#'
#' @section DOES NOT:
#' - Perform timezone conversions (always UTC output)
#' - Handle time-only formats (requires full datetime with date)
#' - Log parsing failures (silent operation)
#' - Throw errors on parse failures (returns NA instead)
#'
#' @examples
#' \dontrun{
#' # AM/PM and 24-hour both work
#' parse_datetime_safe("10/24/2025 6:00:00 PM")  # "2025-10-24 18:00:00 UTC"
#' parse_datetime_safe("10/24/2025 18:00")       # "2025-10-24 18:00:00 UTC"
#' 
#' # Vectorization
#' sapply(c("10/24/2025 6:00:00 PM", "10/24/2025 18:00"), parse_datetime_safe)
#' }
#'
#' @export
parse_datetime_safe <- function(dt_string) {
  
  # Handle NA or empty input
  if (is.na(dt_string) || trimws(dt_string) == "") {
    return(as.POSIXct(NA))
  }
  
  # Only process if contains "/" (full datetime format)
  if (grepl("/", dt_string)) {
    
    # Try AM/PM format first
    result <- lubridate::mdy_hms(dt_string, quiet = TRUE)
    
    # Try 24-hour format if that failed
    if (is.na(result)) {
      result <- lubridate::mdy_hm(dt_string, quiet = TRUE)
    }
    
    # Try explicit parse if still failed
    if (is.na(result)) {
      result <- as.POSIXct(dt_string, format = "%m/%d/%Y %H:%M", tz = "UTC")
    }
    
    return(result)
    
  } else {
    # Time-only format - not expected
    return(as.POSIXct(NA))
  }
}


#' Parse Date Strings Safely
#'
#' @description
#' Parses date strings in multiple formats commonly produced by Excel or
#' user editing. Handles mixed date formats gracefully. Used for parsing
#' Night column in template comparison (Workflow 04).
#'
#' @param date_string Character date string to parse, Date object, or NA
#'
#' @return Date object, or NA (Date) if parsing fails or input is NA
#'
#' @details
#' **Supported formats (tried in order):**
#' 1. YYYY-MM-DD (standard R format)
#' 2. MM/DD/YYYY (US Excel format)
#' 3. MM-DD-YYYY (Excel variant)
#' 4. M/D/YYYY (single-digit month/day)
#'
#' @section CONTRACT:
#' - Returns Date object (R Date class)
#' - Returns NA (Date) for NA or blank input (fails gracefully)
#' - Returns input unchanged if already Date object
#' - Tries multiple formats automatically
#' - Warns on parse failures (logs unparseable strings)
#' - Never throws errors (returns NA on failure)
#' - Non-vectorized (use sapply for vectors)
#'
#' @section DOES NOT:
#' - Parse datetime strings (use parse_datetime_safe for those)
#' - Validate if date is "reasonable"
#' - Require explicit format specification
#' - Throw errors on parse failures (warns and returns NA)
#'
#' @examples
#' \dontrun{
#' parse_date_safe("2024-10-15")    # [1] "2024-10-15"
#' parse_date_safe("10/15/2024")    # [1] "2024-10-15"
#' parse_date_safe(as.Date("2024-10-15"))  # [1] "2024-10-15" (unchanged)
#' }
#'
#' @export
parse_date_safe <- function(date_string) {
  
  # Handle special cases
  if (is.na(date_string) || trimws(date_string) == "") {
    return(as.Date(NA))
  }
  
  # Already a Date object - return unchanged
  if (inherits(date_string, "Date")) {
    return(date_string)
  }
  
  # Try multiple date formats
  result <- as.Date(date_string, format = "%Y-%m-%d")
  if (!is.na(result)) return(result)
  
  result <- lubridate::mdy(date_string, quiet = TRUE)
  if (!is.na(result)) return(result)
  
  result <- as.Date(date_string, format = "%m-%d-%Y")
  if (!is.na(result)) return(result)
  
  result <- as.Date(date_string, format = "%m/%d/%Y")
  if (!is.na(result)) return(result)
  
  # All formats failed - warn and return NA
  warning(sprintf("Could not parse date: '%s'", date_string))
  return(as.Date(NA))
}


#' Extract Time Component from DateTime String
#'
#' @description
#' Parses a full datetime string and extracts just the time component as
#' HH:MM:SS (24-hour format). Used for comparing recording times between
#' original and edited templates when checking for manual edits in Workflow 04.
#'
#' @param datetime_str Character scalar datetime string, or NA
#'
#' @return Character time string in format "HH:MM:SS" (24-hour, zero-padded),
#'   or NA_character_ if parsing fails or input is NA
#'
#' @section CONTRACT:
#' - Returns time string in format "HH:MM:SS" (24-hour, zero-padded)
#' - Returns NA_character_ for NA or blank input (fails gracefully)
#' - Uses parse_datetime_safe() for robust parsing
#' - Always includes seconds in output (:00 if not present)
#' - Non-vectorized (use sapply for vectors)
#'
#' @section DOES NOT:
#' - Preserve original AM/PM or 24-hour format (always 24-hour output)
#' - Include date component in output (time only)
#' - Perform timezone conversions
#' - Throw errors (returns NA_character_ on failure)
#'
#' @examples
#' \dontrun{
#' extract_time("10/24/2025 6:00:00 PM")  # [1] "18:00:00"
#' extract_time("10/24/2025 18:00")       # [1] "18:00:00"
#' extract_time("10/24/2025 7:30:00 AM")  # [1] "07:30:00"
#' }
#'
#' @export
extract_time <- function(datetime_str) {
  
  # Handle NA or empty input
  if (is.na(datetime_str) || trimws(datetime_str) == "") {
    return(NA_character_)
  }
  
  # Parse the datetime using our safe parser
  dt <- parse_datetime_safe(datetime_str)
  
  # If parsing failed, return NA
  if (is.na(dt)) {
    return(NA_character_)
  }
  
  # Extract time component as HH:MM:SS (24-hour format)
  return(format(dt, "%H:%M:%S"))
}


# ------------------------------------------------------------------------------
# Formatting (Edit Log Display)
# ------------------------------------------------------------------------------

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
#' @section CONTRACT:
#' - Returns character string in format "MM/DD/YYYY HH:MM"
#' - Returns "<blank>" for NA input
#' - Always 24-hour format (never AM/PM)
#' - Never includes seconds
#' - Zero-padded (e.g., "08:00" not "8:00")
#' - Non-vectorized (processes single datetime at a time)
#'
#' @section DOES NOT:
#' - Include AM/PM indicators (always 24-hour)
#' - Include seconds (omitted for readability)
#' - Perform timezone conversions (uses datetime as-is)
#' - Work on vectors (processes single value)
#'
#' @examples
#' \dontrun{
#' dt <- parse_datetime_safe("10/24/2025 6:00:00 PM")
#' format_datetime_for_log(dt, "")  # [1] "10/24/2025 18:00"
#' 
#' format_datetime_for_log(NA, "")  # [1] "<blank>"
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
# Internal Helpers
# ------------------------------------------------------------------------------

#' Check if Timezone Name is Valid
#'
#' @description
#' Validates that a timezone name exists in the tz database.
#' Helper function for convert_datetime_to_local().
#'
#' @param tz_name Timezone name (e.g., "America/Chicago")
#'
#' @return Logical: TRUE if valid, FALSE otherwise
#'
#' @section CONTRACT:
#' - Returns TRUE for valid tz database names
#' - Returns FALSE for invalid names (no error)
#' - Case-sensitive matching
#'
#' @section DOES NOT:
#' - Stop execution on invalid timezones
#' - Suggest alternative timezone names
#' - Modify system timezone settings
#'
#' @keywords internal
is_valid_timezone <- function(tz_name) {
  tz_name %in% OlsonNames()
}


#' Summarize Date Formats Present in Data
#'
#' @description
#' Analyzes a date column to identify different format patterns.
#' Useful for debugging mixed date format issues.
#'
#' @param date_vector Character or Date vector to analyze
#' @param n_sample Number of examples to show per format (default: 3)
#' @param verbose Logical. Print summary? Default: TRUE
#'
#' @return Invisible NULL (prints summary to console when verbose = TRUE)
#'
#' @section CONTRACT:
#' - Prints summary to console when verbose = TRUE
#' - Returns invisible NULL
#' - Samples n_sample examples per format
#'
#' @section DOES NOT:
#' - Modify input data
#' - Parse dates
#' - Validate date correctness
#'
#' @keywords internal
summarize_date_formats <- function(date_vector, n_sample = 3, verbose = TRUE) {
  
  # Convert to character
  dates_char <- as.character(date_vector)
  dates_char <- dates_char[!is.na(dates_char)]
  
  if (length(dates_char) == 0) {
    if (verbose) message("No non-NA dates found")
    return(invisible(NULL))
  }
  
  # Pattern matching
  patterns <- list(
    "YYYY-MM-DD" = "^\\d{4}-\\d{2}-\\d{2}",
    "YYYY/MM/DD" = "^\\d{4}/\\d{2}/\\d{2}",
    "MM-DD-YYYY" = "^\\d{2}-\\d{2}-\\d{4}",
    "MM/DD/YYYY" = "^\\d{2}/\\d{2}/\\d{4}",
    "DD-MM-YYYY" = "^\\d{2}-\\d{2}-\\d{4}",
    "Other" = ".*"
  )
  
  if (verbose) message("\n=== Date Format Summary ===")
  
  for (format_name in names(patterns)) {
    pattern <- patterns[[format_name]]
    matches <- grep(pattern, dates_char, value = TRUE)
    
    if (length(matches) > 0 && verbose) {
      message(sprintf("\nFormat %s: %s date(s)", 
                      format_name, 
                      format(length(matches), big.mark = ",")))
      
      # Show examples
      n_show <- min(n_sample, length(matches))
      examples <- head(unique(matches), n_show)
      message(sprintf("  Examples: %s", paste(examples, collapse = ", ")))
    }
  }
  
  if (verbose) message("\n")
  
  invisible(NULL)
}


# ==============================================================================
# END OF FILE
# ==============================================================================