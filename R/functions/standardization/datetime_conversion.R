# ==============================================================================
# datetime_conversion.R - DATE/TIME CONVERSION (LOCKED CONTRACT)
# ==============================================================================
# PURPOSE
# -------
# Parses mixed date/time formats and converts to standardized datetime columns
# with timezone handling. Designed for Kaleidoscope Pro data which may have
# inconsistent date formats across different KPro versions or user systems.
#
# DATETIME CONTRACT
# -----------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Flexible parsing
#    - Handles multiple date formats (YYYY-MM-DD, MM-DD-YYYY, YYYY/MM/DD, etc.)
#    - Handles multiple time formats (HH:MM:SS, HH:MM)
#    - Logs parsing failures with counts
#
# 2. Timezone handling
#    - Assumes input is UTC (detector timezone)
#    - Converts to user-specified timezone from YAML configuration
#    - Handles DST transitions automatically via lubridate
#    - Creates both UTC and local datetime columns
#    - NO HARDCODED TIMEZONES - user must provide via YAML
#
# 3. Column creation
#    - DateTime_UTC: Original datetime in UTC
#    - DateTime: Converted to user's local timezone (with DST)
#    - Date: Date in local timezone (may differ from UTC date)
#
# 4. Non-destructive
#    - Original date and time columns preserved
#    - Intermediate parsing columns removed
#    - Returns new tibble
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Validate recording schedules (analysis/)
#   - Calculate recording hours (analysis/)
#   - Filter data by date/time
#   - Modify timezone settings globally
#   - Default to any specific timezone (user must provide)
#
# DEPENDENCIES
# ------------
#   - validation/validation.R: assert_data_frame, assert_columns_exist, assert_scalar_string
#   - lubridate: parse_date_time, with_tz, as_date, force_tz
#   - dplyr: mutate, select
#
# CONTENTS
# --------
#   - convert_datetime_to_local()  # Main conversion function
#   - is_valid_timezone()          # Timezone validation helper
#   - summarize_date_formats()     # Date format debugging helper
#
# CHANGELOG
# ---------
# 2026-01-30: Refactored to use centralized assert_* functions from validation.R
# 2026-01-26: Added verbose parameter to convert_datetime_to_local() (default: FALSE)
# 2026-01-26: Gated all console messages with if (verbose)
# 2026-01-26: Fixed emoji encoding (ASCII replacements)
# 2024-12-27: Renamed convert_datetime_to_cst() -> convert_datetime_to_local()
# 2024-12-27: Made target_tz a REQUIRED parameter (no default)
# 2024-12-27: Fixed all UTF-8 encoding corruption
# 2024-12-27: Removed all CST-specific references and hardcoded timezone assumptions
#
# ==============================================================================


# ------------------------------------------------------------------------------
# Main Function: Convert DateTime to Local Timezone
# ------------------------------------------------------------------------------

#' Convert Date/Time Columns to User's Local Timezone
#'
#' @description
#' Parses date and time columns, combines them into datetime, and converts from 
#' UTC to user-specified timezone. Creates both UTC and local datetime columns
#' with derived time components.
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
#'
#' @section DOES NOT:
#' - Use hardcoded timezones
#' - Modify original date/time columns
#' - Filter rows based on date/time
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
# Helper Function: Check Timezone Validity
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


# ------------------------------------------------------------------------------
# Helper Function: Summarize Date Formats in Data
# ------------------------------------------------------------------------------

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
#' @details
#' Identifies common date format patterns:
#' - YYYY-MM-DD
#' - YYYY/MM/DD
#' - MM-DD-YYYY
#' - MM/DD/YYYY
#' - DD-MM-YYYY
#'
#' Prints count and examples of each format found.
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
#' @examples
#' \dontrun{
#' dates <- c("2024-10-15", "10/16/2024", "2024/10/17", "2024-10-18")
#' summarize_date_formats(dates)
#' # Output:
#' # Format YYYY-MM-DD: 2 dates
#' #   Examples: 2024-10-15, 2024-10-18
#' # Format MM/DD/YYYY: 1 date
#' #   Example: 10/16/2024
#' # Format YYYY/MM/DD: 1 date
#' #   Example: 2024/10/17
#' }
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