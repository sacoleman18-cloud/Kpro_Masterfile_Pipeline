# =============================================================================
# standardization/datetime_conversion.R – DATE/TIME CONVERSION (LOCKED CONTRACT)
# =============================================================================
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
# 2024-12-27: Renamed convert_datetime_to_cst() → convert_datetime_to_local()
# 2024-12-27: Made target_tz a REQUIRED parameter (no default)
# 2024-12-27: Fixed all UTF-8 encoding corruption
# 2024-12-27: Removed all CST-specific references and hardcoded timezone assumptions
#
# =============================================================================


# ------------------------------------------------------------------------------
# Main Function: Convert DateTime to Local Timezone
# ------------------------------------------------------------------------------

#' Convert Date/Time Columns to User's Local Timezone
#'
#' @description
#' Parses date and time columns (which may have mixed formats), combines them
#' into datetime, and converts from UTC to user-specified timezone with
#' automatic DST handling.
#'
#' @param df Data frame containing date and time columns
#' @param target_tz Target timezone from YAML config (REQUIRED - no default)
#' @param date_col Name of date column (default: "date")
#' @param time_col Name of time column (default: "time")
#' @param source_tz Source timezone (default: "UTC")
#'
#' @return Data frame with three new columns:
#'   - DateTime_UTC: Combined datetime in UTC
#'   - DateTime: Datetime in user's local timezone
#'   - Date: Date in user's local timezone (may differ from original date after conversion)
#'
#' @details
#' **CRITICAL: target_tz is REQUIRED**
#' This function does NOT default to any timezone. You must provide the user's
#' timezone from the YAML configuration:
#' 
#' ```r
#' params <- load_study_parameters("inst/config/study_parameters.yaml")
#' user_tz <- params$study_parameters$timezone
#' df <- convert_datetime_to_local(df, target_tz = user_tz)
#' ```
#'
#' **Date format handling:**
#' This function tries multiple date formats in order:
#' - YYYY-MM-DD (e.g., "2024-10-15")
#' - YYYY/MM/DD (e.g., "2024/10/15")
#' - MM-DD-YYYY (e.g., "10-15-2024")
#' - MM/DD/YYYY (e.g., "10/15/2024")
#' - DD-MM-YYYY (e.g., "15-10-2024")
#'
#' **Time format handling:**
#' - HH:MM:SS (e.g., "23:45:30")
#' - HH:MM (e.g., "23:45")
#'
#' **Timezone conversion:**
#' - Assumes source data is in UTC (typical for AudioMoth/acoustic detectors)
#' - Converts to user's timezone specified in YAML configuration
#' - Automatically handles DST transitions (Spring forward, Fall back)
#' - Date may change after conversion (e.g., 2024-01-01 00:30 UTC → 2023-12-31 18:30 CST)
#'
#' **DST Warning:**
#' If data spans typical DST transition months, logs a warning that transitions occurred.
#' lubridate handles these automatically but users should be aware.
#'
#' **Parsing failures:**
#' - Logs count of failed date/time parses
#' - Failed parses result in NA for DateTime columns
#' - Does not stop execution (allows partial processing)
#'
#' @section CONTRACT:
#' - target_tz is REQUIRED (no default value)
#' - Creates three new datetime columns
#' - Preserves original date and time columns
#' - Removes intermediate parsing columns (date_parsed, time_parsed, DateTime_UTC_temp)
#' - Handles mixed date formats automatically
#' - Logs parsing success/failure counts
#' - Warns if DST transitions occurred in data
#' - Validates timezone is in OlsonNames() database
#'
#' @section DOES NOT:
#' - Default to any specific timezone
#' - Modify original date or time columns
#' - Validate recording schedules
#' - Filter rows with failed parses
#' - Calculate recording hours or effort
#' - Change system timezone settings
#'
#' @examples
#' \dontrun{
#' # Load user's timezone from YAML
#' params <- load_study_parameters("inst/config/study_parameters.yaml")
#' user_tz <- params$study_parameters$timezone
#'
#' # Mixed date formats
#' bat_data <- data.frame(
#'   date = c("2024-10-15", "10/16/2024", "2024/10/17"),
#'   time = c("23:45:30", "00:15:00", "01:30:45")
#' )
#'
#' # Convert to user's local timezone
#' bat_data_local <- convert_datetime_to_local(bat_data, target_tz = user_tz)
#'
#' # Result columns (example for America/Chicago):
#' # - DateTime_UTC: 2024-10-15 23:45:30 UTC, 2024-10-16 00:15:00 UTC, ...
#' # - DateTime: 2024-10-15 18:45:30 CDT, 2024-10-15 19:15:00 CDT, ...
#' # - Date: 2024-10-15, 2024-10-15, 2024-10-16
#'
#' # Different timezone (Pacific)
#' bat_data_pst <- convert_datetime_to_local(
#'   bat_data,
#'   target_tz = "America/Los_Angeles"
#' )
#' }
#'
#' @export
convert_datetime_to_local <- function(df,
                                      target_tz,
                                      date_col = "date",
                                      time_col = "time",
                                      source_tz = "UTC") {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(df)) {
    stop("df must be a data frame")
  }
  
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
  
  # Validate timezone is valid
  if (!target_tz %in% OlsonNames()) {
    stop(sprintf(
      "Invalid timezone: '%s'\n  Must be a valid timezone from OlsonNames()\n  Common options: America/New_York, America/Chicago, America/Los_Angeles, America/Phoenix",
      target_tz
    ))
  }
  
  # Check if required columns exist
  if (!date_col %in% names(df)) {
    stop(sprintf("Date column '%s' not found in data frame", date_col))
  }
  
  if (!time_col %in% names(df)) {
    stop(sprintf("Time column '%s' not found in data frame", time_col))
  }
  
  # -------------------------
  # Parse dates (multiple formats)
  # -------------------------
  
  message("  Parsing date column (handling mixed formats)...")
  
  df <- df %>%
    dplyr::mutate(
      date_parsed = lubridate::parse_date_time(
        .data[[date_col]],
        orders = c("ymd", "Ymd", "ymd HMS", "mdy", "dmy"),
        quiet = TRUE
      )
    )
  
  # Check for parsing failures
  failed_dates <- sum(is.na(df$date_parsed) & !is.na(df[[date_col]]))
  
  if (failed_dates > 0) {
    warning(sprintf(
      "%s date(s) failed to parse - will result in NA DateTime values",
      format(failed_dates, big.mark = ",")
    ))
  }
  
  message(sprintf("    ✓ Parsed %s dates (%s failed)",
                  format(nrow(df) - failed_dates, big.mark = ","),
                  format(failed_dates, big.mark = ",")))
  
  # -------------------------
  # Parse times (multiple formats)
  # -------------------------
  
  message("  Parsing time column...")
  
  df <- df %>%
    dplyr::mutate(
      time_parsed = lubridate::parse_date_time(
        .data[[time_col]],
        orders = c("HMS", "HM"),
        quiet = TRUE
      )
    )
  
  # Check for parsing failures
  failed_times <- sum(is.na(df$time_parsed) & !is.na(df[[time_col]]))
  
  if (failed_times > 0) {
    warning(sprintf(
      "%s time(s) failed to parse - will result in NA DateTime values",
      format(failed_times, big.mark = ",")
    ))
  }
  
  message(sprintf("    ✓ Parsed %s times (%s failed)",
                  format(nrow(df) - failed_times, big.mark = ","),
                  format(failed_times, big.mark = ",")))
  
  # -------------------------
  # Combine date + time into DateTime (UTC)
  # -------------------------
  
  message(sprintf("  Combining date and time (assuming %s timezone)...", source_tz))
  
  df <- df %>%
    dplyr::mutate(
      # Combine using paste and parse again (more robust than adding)
      DateTime_UTC_temp = lubridate::ymd_hms(
        paste(
          lubridate::as_date(date_parsed),
          format(time_parsed, "%H:%M:%S")
        ),
        tz = source_tz,
        quiet = TRUE
      )
    )
  
  # Count combined DateTime failures
  failed_datetime <- sum(is.na(df$DateTime_UTC_temp) & 
                           !is.na(df$date_parsed) & 
                           !is.na(df$time_parsed))
  
  if (failed_datetime > 0) {
    warning(sprintf(
      "%s date+time combination(s) failed",
      format(failed_datetime, big.mark = ",")
    ))
  }
  
  message(sprintf("    ✓ Created %s DateTime values in %s",
                  format(nrow(df) - sum(is.na(df$DateTime_UTC_temp)), big.mark = ","),
                  source_tz))
  
  
  # -------------------------
  # Convert to target timezone (with automatic DST handling)
  # -------------------------
  
  message(sprintf("  Converting %s → %s...", source_tz, target_tz))
  
  df <- df %>%
    dplyr::mutate(
      # Keep original UTC - EXPLICITLY FORCE timezone attribute
      # This ensures DateTime_UTC has tz="UTC" attribute set correctly
      DateTime_UTC = lubridate::force_tz(DateTime_UTC_temp, tzone = source_tz),
      
      # Convert to target timezone (automatic DST handling)
      # Note: with_tz() preserves the instant in time, just changes the display timezone
      DateTime = lubridate::with_tz(DateTime_UTC, tzone = target_tz),
      
      # Extract date in target timezone (may differ from original date after conversion)
      Date = lubridate::as_date(DateTime)
    )
  
  message(sprintf("    ✓ Converted to %s", target_tz))
  
  # -------------------------
  # Verify timezone conversion
  # -------------------------
  
  # Sample the first few rows to verify conversion
  if (nrow(df) > 0 && !all(is.na(df$DateTime_UTC)) && !all(is.na(df$DateTime))) {
    utc_tz <- attr(df$DateTime_UTC, "tzone")
    local_tz <- attr(df$DateTime, "tzone")
    
    if (!is.null(utc_tz) && !is.null(local_tz)) {
      message(sprintf("    Timezone attributes: DateTime_UTC=%s, DateTime=%s", 
                      utc_tz, local_tz))
    }
  }
  
  # -------------------------
  # Check for DST transitions
  # -------------------------
  
  # DST transitions typically occur in March and November (North America)
  # Some regions don't observe DST (Arizona, Hawaii, Saskatchewan)
  date_range <- range(df$Date, na.rm = TRUE)
  
  if (any(lubridate::month(date_range) %in% c(3, 11))) {
    message("    ⚠️  Data spans potential DST transition months (March/November)")
    message("       Times have been converted using lubridate's automatic DST handling")
    message(sprintf("       Date range: %s to %s", date_range[1], date_range[2]))
  }
  
  # -------------------------
  # Clean up intermediate columns
  # -------------------------
  
  df <- df %>%
    dplyr::select(-date_parsed, -time_parsed, -DateTime_UTC_temp)
  
  # -------------------------
  # Summary
  # -------------------------
  
  total_success <- sum(!is.na(df$DateTime))
  total_failed <- sum(is.na(df$DateTime))
  
  message(sprintf("\n  DateTime conversion complete:"))
  message(sprintf("    • Successful: %s rows", format(total_success, big.mark = ",")))
  message(sprintf("    • Failed: %s rows", format(total_failed, big.mark = ",")))
  message(sprintf("    • Success rate: %.1f%%", 100 * total_success / nrow(df)))
  
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
#'
#' @return Invisible NULL (prints summary to console)
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
#' - Prints summary to console
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
summarize_date_formats <- function(date_vector, n_sample = 3) {
  
  # Convert to character
  dates_char <- as.character(date_vector)
  dates_char <- dates_char[!is.na(dates_char)]
  
  if (length(dates_char) == 0) {
    message("No non-NA dates found")
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
  
  message("\n=== Date Format Summary ===")
  
  for (format_name in names(patterns)) {
    pattern <- patterns[[format_name]]
    matches <- grep(pattern, dates_char, value = TRUE)
    
    if (length(matches) > 0) {
      message(sprintf("\nFormat %s: %s date(s)", 
                      format_name, 
                      format(length(matches), big.mark = ",")))
      
      # Show examples
      n_show <- min(n_sample, length(matches))
      examples <- head(unique(matches), n_show)
      message(sprintf("  Examples: %s", paste(examples, collapse = ", ")))
    }
  }
  
  message("\n")
  
  invisible(NULL)
}

# ==============================================================================
# END OF FILE
# ==============================================================================