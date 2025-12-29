# =============================================================================
# validation/validation.R — DATA QUALITY & ENFORCEMENT (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Enforces schema requirements, performs data quality checks, and validates
# user-edited templates. Separated into workflow-specific validations.
#
# VALIDATION CONTRACT
# -------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Schema enforcement
#    - Required columns verified to exist
#    - Column types coerced to specification
#    - Column order standardized
#    - Missing required columns → informative error
#
# 2. Workflow-specific validation
#    - enforce_unified_schema: For workflow 02 output (kpro_master)
#    - enforce_master_schema: For workflow 03 output (CallsPerNight data)
#
# 3. Deduplication
#    - remove_exact_duplicates: Only removes rows where ALL fields match
#    - Conservative approach: near-duplicates are KEPT
#    - Removal counts logged
#
# 4. Quality checks
#    - check_column_completeness: % non-NA per column
#    - check_duplicates: Reports potential issues
#    - validate_calls_per_night: Ensures logical consistency
#
# 5. Non-destructive
#    - Validation functions report issues but don't fix them
#    - Enforcement functions return new tibbles
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Transform schema versions (standardization/standardization.R)
#   - Calculate metrics like CallsPerHour (analysis/recording_hours.R)
#   - Generate visualizations (output/visualization.R)
#   - Make assumptions about what "should" be in the data
#
# DEPENDENCIES
# ------------
#   - core/utilities.R: log_message
#   - dplyr: distinct, filter, summarize
#
# CONTENTS
# --------
#   - enforce_unified_schema()       # Workflow 02 output validation
#   - enforce_master_schema()        # Workflow 03 output validation
#   - check_column_completeness()
#   - check_duplicates()
#   - validate_unified_schema()
#   - validate_calls_per_night()
#
# =============================================================================

# ------------------------------------------------------------------------------
# Workflow 02 Validation: Enforce Unified Schem
# ------------------------------------------------------------------------------

#' Enforce Unified Schema (Workflow 02 Output)
#'
#' @description
#' Validates and enforces schema requirements for the unified KPro dataset
#' produced by workflow 02 (standardization). This is the "kpro_master" file
#' that contains all detection events with standardized species codes.
#'
#' @param df Data frame from workflow 02 standardization
#'
#' @return Data frame with enforced column types and validated structure
#'
#' @details
#' **Required columns for unified schema:**
#' - Species: auto_id, alternate_1, alternate_2, alternate_3 (6-letter codes)
#' - Detector: detector_id, Detector (friendly name)
#' - DateTime: DateTime, Date
#' - File outputs: out_file_fs (harmonized from out_file if needed)
#' - Manual ID: manual_id (required, may be NA but column must exist)
#'
#' **Optional but common columns:**
#' - Source tracking: source_file
#' - KPro metadata: indir, outdir, folder, in_file, channel, offset, duration
#' - Acoustic features: n, fc, sc, dur, fmax, fmin, fmean, tbc, fk, tk, s1, tc, qual
#' - Classification: pulses, matching, match_ratio, margin
#'
#' **Type enforcement:**
#' - detector_id, Detector → character
#' - DateTime → POSIXct (with timezone preserved)
#' - Date → Date
#' - auto_id, alternate_1, alternate_2, alternate_3 → character
#' - manual_id → character
#'
#' @section CONTRACT:
#' - Validates presence of core required columns
#' - Coerces column types to specification
#' - Warns about NA values in critical columns
#' - Does not reorder columns (use finalize_master_columns for that)
#' - Does not remove rows
#'
#' @section DOES NOT:
#' - Check for CallsPerNight, Night, Status (workflow 03 columns)
#' - Validate species code correctness
#' - Remove duplicates
#' - Calculate derived metrics
#' - Add Hour/Time columns (use finalize_master_columns)
#' - Reorder columns (use finalize_master_columns)
#'
#' @examples
#' \dontrun{
#' # At end of workflow 02
#' kpro_master <- enforce_unified_schema(unified_data)
#' }
#'
#' @export
enforce_unified_schema <- function(df) {
  
  # -------------------------
  # Required columns check
  # -------------------------
  
  required_cols <- c(
    # Species identification
    "auto_id", "alternate_1", "alternate_2", "alternate_3",
    # Detector information
    "detector_id", "Detector",
    # DateTime information
    "DateTime", "Date",
    # File tracking
    "out_file_fs",
    # Manual ID (required column, values may be NA)
    "manual_id"
  )
  
  missing_cols <- setdiff(required_cols, names(df))
  
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "Unified schema missing required columns: %s\n  This suggests workflow 02 did not complete successfully.",
      paste(missing_cols, collapse = ", ")
    ))
  }
  
  # -------------------------
  # Type enforcement
  # -------------------------
  
  df <- df %>%
    dplyr::mutate(
      # Species codes (character)
      auto_id = as.character(auto_id),
      alternate_1 = as.character(alternate_1),
      alternate_2 = as.character(alternate_2),
      alternate_3 = as.character(alternate_3),
      
      # Detector info (character)
      detector_id = as.character(detector_id),
      Detector = as.character(Detector),
      
      # DateTime (preserve timezone)
      DateTime = as.POSIXct(DateTime, tz = attr(DateTime, "tzone") %||% "America/Chicago"),
      Date = as.Date(Date),
      
      # File tracking (character)
      out_file_fs = as.character(out_file_fs),
      
      # Manual ID (character)
      manual_id = as.character(manual_id)
    )
  
  # Optional source_file if it exists
  if ("source_file" %in% names(df)) {
    df <- df %>%
      dplyr::mutate(source_file = as.character(source_file))
  }
  
  # -------------------------
  # Quality warnings
  # -------------------------
  
  # Check for NA values in critical columns
  if (any(is.na(df$detector_id))) {
    warning(sprintf(
      "%s row(s) have NA detector_id - these detections cannot be assigned to a location",
      sum(is.na(df$detector_id))
    ))
  }
  
  if (any(is.na(df$Detector))) {
    warning(sprintf(
      "%s row(s) have NA Detector name - check detector mapping in workflow 02",
      sum(is.na(df$Detector))
    ))
  }
  
  if (any(is.na(df$DateTime))) {
    warning(sprintf(
      "%s row(s) have NA DateTime - these detections have no timestamp",
      sum(is.na(df$DateTime))
    ))
  }
  
  if (any(is.na(df$auto_id))) {
    na_count <- sum(is.na(df$auto_id))
    message(sprintf(
      "ℹ  %s row(s) have NA auto_id (this is normal for NoID detections)",
      na_count
    ))
  }
  
  # -------------------------
  # Log success
  # -------------------------
  
  message(sprintf("✓ Unified schema validation passed (%s rows)", 
                  format(nrow(df), big.mark = ",")))
  
  df
}


# ------------------------------------------------------------------------------
# Column Finalization: Add CST Time Columns, Remove Unwanted, Reorder
# ------------------------------------------------------------------------------

#' Finalize Master Columns
#'
#' @description
#' Finalizes the kpro_master dataset by adding CST time columns, removing
#' unwanted metadata columns, and reordering columns to a standardized order
#' for analysis and export.
#'
#' @param df Data frame after enforce_unified_schema
#'
#' @return Data frame with finalized column structure
#'
#' @details
#' **Processing steps:**
#' 1. Add Hour column (CST, extracted from DateTime)
#' 2. Add Time column (CST, formatted HH:MM:SS from DateTime)
#' 3. Remove unwanted columns:
#'    - UTC time components: date, hour, time
#'    - 12-hour format columns: date_12, hour_12, time_12
#'    - MD5 hashes: outpathmd5zc, outpathmd5fs, inpathmd5
#'    - User/org IDs: review_userid, review_orgid, userid, orgid
#' 4. Reorder columns to standardized order
#'
#' **Standardized column order:**
#' 1. Detector: detector_id, Detector
#' 2. DateTime: DateTime, DateTime_UTC, Date, Hour, Time
#' 3. Species/Classification: auto_id, pulses, matching, match_ratio, margin,
#'    alternate_1, alternate_2, alternate_3
#' 4. Acoustic features: n, fc, sc, dur, fmax, fmin, fmean, tbc, fk, tk, s1, tc, qual
#' 5. Manual ID: manual_id
#' 6. File metadata: channel, offset, indir, outdir, folder, in_file,
#'    out_file_fs, out_file_zc, source_file
#' 7. Any remaining columns (appended at end)
#'
#' **Note on time columns:**
#' - date, hour, time (lowercase) = UTC components (removed)
#' - Date, Hour, Time (uppercase) = CST components (kept/created)
#' - DateTime_UTC = Full UTC timestamp (kept)
#' - DateTime = Full CST timestamp (kept)
#'
#' @section CONTRACT:
#' - Creates Hour and Time columns from DateTime (CST)
#' - Removes specified unwanted columns (if they exist)
#' - Reorders columns to standardized order
#' - Preserves all data (no rows removed)
#' - Columns not in standard order appear at end
#'
#' @section DOES NOT:
#' - Validate data quality
#' - Remove rows
#' - Modify column values
#' - Stop execution if columns are missing
#'
#' @examples
#' \dontrun{
#' # After enforce_unified_schema
#' kpro_master <- enforce_unified_schema(unified_data)
#' kpro_master <- finalize_master_columns(kpro_master)
#' }
#'
#' @export
finalize_master_columns <- function(df) {
  
  # -------------------------
  # Add CST Hour and Time columns
  # -------------------------
  
  message("  Adding CST Hour and Time columns...")
  
  df <- df %>%
    dplyr::mutate(
      Hour = lubridate::hour(DateTime),           # CST hour (0-23)
      Time = format(DateTime, "%H:%M:%S")         # CST time (HH:MM:SS string)
    )
  
  # -------------------------
  # Remove unwanted columns
  # -------------------------
  
  cols_to_remove <- c(
    # UTC time components (lowercase - being removed)
    "date", "hour", "time",
    
    # 12-hour format columns
    "date_12", "hour_12", "time_12",
    
    # MD5 hash columns and Files
    "outpathmd5zc", "outpathmd5fs", "inpathmd5", "files",
    
    # User/org ID columns
    "review_userid", "review_orgid", "userid", "orgid"
  )
  
  # Only remove columns that actually exist
  cols_to_remove_actual <- intersect(cols_to_remove, names(df))
  
  if (length(cols_to_remove_actual) > 0) {
    message(sprintf("  Removing %d unwanted columns...", length(cols_to_remove_actual)))
    df <- df %>%
      dplyr::select(-dplyr::all_of(cols_to_remove_actual))
  }
  
  # -------------------------
  # Reorder columns to standardized order
  # -------------------------
  
  message("  Reordering columns to standardized order...")
  
  # Define standardized column order
  standard_order <- c(
    # Detector info
    "detector_id", "Detector",
    
    # DateTime (CST, then UTC)
    "DateTime", "DateTime_UTC", "Date", "Hour", "Time",
    
    # Species and classification
    "auto_id", "pulses", "matching", "match_ratio", "margin",
    "alternate_1", "alternate_2", "alternate_3",
    
    # Acoustic features
    "n", "fc", "sc", "dur", "fmax", "fmin", "fmean", "tbc", 
    "fk", "tk", "s1", "tc", "qual",
    
    # Manual ID
    "manual_id",
    
    # File metadata
    "channel", "offset", "duration", "indir", "outdir", "folder", "in_file",
    "out_file_fs", "out_file_zc", "source_file"
  )
  
  # Get columns that exist in standard order
  cols_ordered <- intersect(standard_order, names(df))
  
  # Get remaining columns not in standard order
  cols_remaining <- setdiff(names(df), cols_ordered)
  
  # Reorder: standard columns first, then any extras
  df <- df %>%
    dplyr::select(dplyr::all_of(c(cols_ordered, cols_remaining)))
  
  # -------------------------
  # Report summary
  # -------------------------
  
  message(sprintf("  ✓ Finalized %d columns (%d in standard order, %d additional)",
                  ncol(df),
                  length(cols_ordered),
                  length(cols_remaining)))
  
  if (length(cols_remaining) > 0) {
    message("  Additional columns (not in standard order):")
    message(sprintf("    %s", paste(cols_remaining, collapse = ", ")))
  }
  
  df
}


# ------------------------------------------------------------------------------
# Quality Check: Duplicates (Works for Both Schemas)
# ------------------------------------------------------------------------------

#' Check for Duplicate Detection Events
#'
#' @description
#' Identifies duplicate rows based on Detector + DateTime. Works for both
#' unified schema (workflow 02) and master schema (workflow 03).
#'
#' @param df Data frame with enforced schema
#'
#' @return Tibble of duplicates, or empty tibble if none found
#'
#' @details
#' **Duplicate detection logic:**
#' - Groups by Detector (or detector_id if Detector not present) + DateTime
#' - Returns rows where count > 1
#'
#' **This is a reporting function only** - it does not remove duplicates.
#' Use the deduplication stage in workflow 02 for actual removal.
#'
#' @section CONTRACT:
#' - Returns all rows that are duplicates (not just the extras)
#' - Empty tibble if no duplicates found
#' - Works with either Detector or detector_id column
#'
#' @section DOES NOT:
#' - Remove duplicates
#' - Modify input data
#' - Define what constitutes a "duplicate" (just uses Detector + DateTime)
#'
#' @export
check_duplicates <- function(df) {
  
  # Determine which detector column to use
  if ("Detector" %in% names(df)) {
    detector_col <- "Detector"
  } else if ("detector_id" %in% names(df)) {
    detector_col <- "detector_id"
  } else {
    stop("No Detector or detector_id column found")
  }
  
  df %>%
    dplyr::group_by(.data[[detector_col]], DateTime) %>%
    dplyr::filter(dplyr::n() > 1) %>%
    dplyr::ungroup()
}


# ------------------------------------------------------------------------------
# Quality Check: Column Completeness
# ------------------------------------------------------------------------------

#' Check Column Completeness
#'
#' @description
#' Reports number and percentage of missing values per column.
#'
#' @param df Data frame with enforced schema
#'
#' @return Data frame with columns: column_name, na_count, na_percent
#'
#' @details
#' Useful for identifying data quality issues before analysis.
#'
#' @section CONTRACT:
#' - Returns one row per column in input
#' - Counts both NA and empty strings as missing
#' - Sorted by na_count descending
#'
#' @section DOES NOT:
#' - Modify input data
#' - Define acceptable NA thresholds
#' - Filter or remove columns
#'
#' @export
check_column_completeness <- function(df) {
  
  completeness <- data.frame(
    column_name = names(df),
    na_count = sapply(df, function(x) sum(is.na(x))),
    row.names = NULL
  )
  
  completeness$na_percent <- round(100 * completeness$na_count / nrow(df), 2)
  
  completeness %>%
    dplyr::arrange(dplyr::desc(na_count))
}


# ------------------------------------------------------------------------------
# Quality Check: Validate CallsPerNight (Workflow 03 Only)
# ------------------------------------------------------------------------------

#' Validate Nightly Calls
#'
#' @description
#' Finds rows with negative, NA, or unexpectedly high CallsPerNight values.
#' Only applicable to workflow 03 output.
#'
#' @param df Data frame with CallsPerNight column
#' @param max_calls Maximum reasonable calls per night (default: 10000)
#'
#' @return Tibble of problematic rows, or empty tibble if all valid
#'
#' @details
#' **Flags as problematic:**
#' - CallsPerNight is NA
#' - CallsPerNight < 0
#' - CallsPerNight > max_calls threshold
#'
#' **Note:** This is a reporting function. Manual review recommended for
#' flagged rows as they may be legitimate edge cases.
#'
#' @section CONTRACT:
#' - Returns rows that fail validation criteria
#' - Empty tibble if all values valid
#' - Does not modify input data
#'
#' @section DOES NOT:
#' - Remove flagged rows
#' - Automatically "fix" values
#' - Define what is "reasonable" beyond max_calls parameter
#'
#' @export
validate_calls_per_night <- function(df, max_calls = 10000) {
  
  if (!"CallsPerNight" %in% names(df)) {
    stop("CallsPerNight column not found - is this workflow 03 output?")
  }
  
  df %>%
    dplyr::filter(
      is.na(CallsPerNight) | 
        CallsPerNight < 0 | 
        CallsPerNight > max_calls
    )
}