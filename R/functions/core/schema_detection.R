# =============================================================================
# core/schema_detection.R â€” KPRO SCHEMA VERSION DETECTION (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Detects Kaleidoscope Pro schema version at the ROW level. Handles files
# containing mixed data from different KPro versions through simple, fast
# detection logic based on column existence and species code length.
#
# SCHEMA DETECTION CONTRACT
# -------------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Row-level detection
#    - Schema version is assigned to EVERY row individually
#    - Files may contain mixed schemas (this is expected and handled)
#    - Detection based on column existence and auto_id code length
#    - No sampling or averaging - every row checked
#
# 2. Detection logic (per row)
#    - Step 1: Does 'alternates' column exist? â†’ v1_legacy_single_column
#    - Step 2: If no 'alternates', check auto_id length:
#        - 4 characters â†’ v2_transitional_4letter
#        - 6 characters â†’ v3_modern_6letter
#        - Other (including "NoID") â†’ unknown
#
# 3. Output guarantee
#    - detect_row_schema() ALWAYS adds 'schema_version' column
#    - Every row has exactly one schema_version value
#    - Unknown schemas are flagged with "unknown", never error
#    - Returns modified data frame with new column
#
# 4. Non-destructive
#    - Original columns are NEVER modified
#    - Only adds schema_version column
#    - Input data frame structure preserved
#
# 5. Helper functions
#    - get_dominant_schema() returns single most common version
#    - summarize_schema_distribution() prints readable summary
#    - validate_schema_detection() checks for "unknown" rows
#    - get_schema_summary() returns data frame of counts
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Transform alternates or species codes
#   - Convert between schema versions
#   - Split semicolon-delimited alternates
#   - Remove or filter any rows
#   - Modify any existing column values
#   - Map species codes (4-letter â†” 6-letter)
#   - Perform data quality validation
#
# DEPENDENCIES
# ------------
#   - dplyr: mutate, case_when
#   - base R: nchar, trimws, table
#
# CONTENTS
# --------
# Primary function:
#   - detect_row_schema()         # Main workhorse - adds schema_version column
#
# Helper functions:
#   - get_dominant_schema()       # Returns most common schema (for logging)
#   - summarize_schema_distribution()  # Prints human-readable summary
#   - validate_schema_detection() # Checks for unknown schemas
#   - get_schema_summary()        # Returns counts as data frame
#
# SCHEMA VERSIONS RECOGNIZED
# --------------------------
#   v1_legacy_single_column   : Has 'alternates' column (semicolon-delimited)
#   v2_transitional_4letter   : Has 'alternate_1', auto_id is 4 characters
#   v3_modern_6letter         : Has 'alternate_1', auto_id is 6 characters
#   unknown                   : Could not determine schema version
#
# USAGE EXAMPLE
# -------------
# # Add schema version to each row
# df <- detect_row_schema(raw_data)
#
# # Quick check
# table(df$schema_version)
#
# # Detailed summary
# summarize_schema_distribution(df)
#
# # Get dominant for logging
# message(sprintf("Primary schema: %s", get_dominant_schema(df)))
#
# # Validate detection
# if (!validate_schema_detection(df)) {
#   warning("Some rows have unknown schema")
# }
#
# =============================================================================

# ------------------------------------------------------------------------------
# Core Function: Detect Row Schema (UPDATED - Handles Semicolons)
# ------------------------------------------------------------------------------

#' Detect Schema Version Per Row
#'
#' @description
#' Detects Kaleidoscope Pro schema version for each row individually, handling
#' mixed-version files where different rows may have different schemas. Now
#' includes detection of semicolon-delimited alternate columns.
#'
#' @param df Data frame to detect schemas for
#'
#' @return Data frame with schema_version column added
#'
#' @details
#' **Detection logic (applied per row):**
#'
#' **File-level check (applies to all rows):**
#' 1. If "alternates" column exists â†’ ALL rows are v1_legacy_single_column
#'
#' **Row-level checks (when no "alternates" column):**
#' 2. If alternate_1 OR alternate_2 contains semicolons â†’ v1_legacy_single_column
#' 3. Else if auto_id length is 4 characters â†’ v2_transitional_4letter
#' 4. Else if auto_id length is 6 characters â†’ v3_modern_6letter
#' 5. Else â†’ unknown
#'
#' **Why semicolon detection matters:**
#' Some v1 files have already been partially processed and have alternate_1
#' instead of alternates, but still contain semicolon-delimited codes like
#' "LACI;LABO;LANO". These must be detected and split properly.
#'
#' **Examples of detection:**
#' - Row with alternates column â†’ v1_legacy_single_column
#' - Row with alternate_1 = "LACI;LABO" â†’ v1_legacy_single_column
#' - Row with auto_id = "MYLU" (4 chars) â†’ v2_transitional_4letter
#' - Row with auto_id = "MYOLUC" (6 chars) â†’ v3_modern_6letter
#' - Row with auto_id = "NoID" (4 chars) â†’ v2_transitional_4letter
#'
#' @section CONTRACT:
#' - Adds schema_version column to input dataframe
#' - Never modifies existing columns (non-destructive)
#' - Returns same number of rows as input
#' - Handles NA values in auto_id (classified as unknown)
#' - Case-insensitive column name matching
#' - Detects semicolons using fixed matching (not regex)
#' - Each row classified independently
#'
#' @section DOES NOT:
#' - Transform or split data (only detects)
#' - Convert species codes
#' - Remove rows
#' - Validate data quality
#' - Modify auto_id, alternate_1, or any other columns
#' - Require all columns to be present (gracefully handles missing columns)
#'
#' @examples
#' \dontrun{
#' # Mixed schema data
#' mixed_data <- data.frame(
#'   auto_id = c("MYLU", "MYOLUC", "EPFU"),
#'   alternate_1 = c("LACI;LABO", "LASBOR", "MYOSEP")
#' )
#' 
#' # Detect schemas
#' detected <- detect_row_schema(mixed_data)
#' 
#' # Result:
#' # Row 1: v1_legacy_single_column (has semicolon in alternate_1)
#' # Row 2: v3_modern_6letter (auto_id is 6 chars)
#' # Row 3: v2_transitional_4letter (auto_id is 4 chars, no semicolons)
#' }
#'
#' @export
detect_row_schema <- function(df) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(df)) {
    stop("df must be a data frame")
  }
  
  if (nrow(df) == 0) {
    warning("Empty data frame provided - cannot detect schemas")
    df$schema_version <- character(0)
    return(df)
  }
  
  # -------------------------
  # File-level check: "alternates" column exists?
  # -------------------------
  
  alternates_col_exists <- "alternates" %in% tolower(names(df))
  
  if (alternates_col_exists) {
    message("  Detected 'alternates' column - all rows classified as v1_legacy_single_column")
    df$schema_version <- "v1_legacy_single_column"
    return(df)
  }
  
  # -------------------------
  # Row-level detection (no "alternates" column present)
  # -------------------------
  
  # Find alternate columns (case-insensitive)
  alt1_col <- grep("^alternate_1$", names(df), ignore.case = TRUE, value = TRUE)[1]
  alt2_col <- grep("^alternate_2$", names(df), ignore.case = TRUE, value = TRUE)[1]
  
  # Check for auto_id column
  auto_id_col <- grep("^auto_id$", names(df), ignore.case = TRUE, value = TRUE)[1]
  
  if (is.na(auto_id_col)) {
    warning("No auto_id column found - all rows classified as unknown")
    df$schema_version <- "unknown"
    return(df)
  }
  
  # -------------------------
  # Classify each row
  # -------------------------
  
  df <- df %>%
    dplyr::mutate(
      # Check for semicolons in alternate columns
      has_semicolons_alt1 = if (!is.na(alt1_col)) {
        grepl(";", .data[[alt1_col]], fixed = TRUE)
      } else {
        FALSE
      },
      
      has_semicolons_alt2 = if (!is.na(alt2_col)) {
        grepl(";", .data[[alt2_col]], fixed = TRUE)
      } else {
        FALSE
      },
      
      has_semicolons = has_semicolons_alt1 | has_semicolons_alt2,
      
      # Get auto_id length
      auto_id_length = nchar(as.character(.data[[auto_id_col]])),
      
      # Classify schema per row
      schema_version = dplyr::case_when(
        
        # V1: Semicolons found in alternate columns
        has_semicolons ~ "v1_legacy_single_column",
        
        # V2: 4-letter auto_id
        auto_id_length == 4 ~ "v2_transitional_4letter",
        
        # V3: 6-letter auto_id
        auto_id_length == 6 ~ "v3_modern_6letter",
        
        # Unknown (NA, unexpected lengths, etc.)
        .default = "unknown"
      )
    ) %>%
    dplyr::select(-has_semicolons_alt1, -has_semicolons_alt2, -has_semicolons, -auto_id_length)
  
  # -------------------------
  # Log detection summary
  # -------------------------
  
  schema_counts <- table(df$schema_version)
  message("  Schema detection complete:")
  for (version in names(schema_counts)) {
    message(sprintf("    - %s: %s rows", 
                    version, 
                    format(schema_counts[version], big.mark = ",")))
  }
  
  df
}


# ------------------------------------------------------------------------------
# Helper: Get Dominant Schema (for logging)
# ------------------------------------------------------------------------------
#' Get Dominant Schema Version
#'
#' @description
#' Returns the most common schema version in a dataframe.
#' Useful for simple logging when you don't need full distribution.
#'
#' @param df Data frame with schema_version column
#'
#' @return Character string of most common schema version
#'
#' @section CONTRACT:
#' - Returns single most common schema version as character string
#' - Requires schema_version column in input
#' - Stops with error if schema_version column missing
#' - Returns first schema alphabetically if tied frequencies
#'
#' @section DOES NOT:
#' - Calculate percentages or detailed distributions (use get_schema_summary)
#' - Modify input data frame
#' - Handle missing schema_version values (assumes column exists)
#' - Validate schema version values
#'
#' @export
get_dominant_schema <- function(df) {
  
  if (!"schema_version" %in% names(df)) {
    stop("Data frame must have schema_version column")
  }
  
  schema_counts <- table(df$schema_version)
  names(sort(schema_counts, decreasing = TRUE))[1]
}


# ------------------------------------------------------------------------------
# Helper: Schema Distribution Summary
# ------------------------------------------------------------------------------
#' Summarize Schema Distribution
#'
#' @description
#' Prints human-readable summary of schema versions in dataframe.
#'
#' @param df Data frame with schema_version column
#' @param verbose Logical: print detailed breakdown? Default TRUE
#'
#' @return Invisible data frame with schema counts
#'
#' @export
summarize_schema_distribution <- function(df, verbose = TRUE) {
  
  if (!"schema_version" %in% names(df)) {
    stop("Data frame must have schema_version column")
  }
  
  # Count schemas
  schema_counts <- as.data.frame(table(df$schema_version))
  names(schema_counts) <- c("schema_version", "count")
  schema_counts$percent <- round(100 * schema_counts$count / nrow(df), 1)
  
  if (verbose) {
    message("\n  Schema distribution:")
    for (i in seq_len(nrow(schema_counts))) {
      message(sprintf("    - %s: %s rows (%.1f%%)", 
                      schema_counts$schema_version[i],
                      format(schema_counts$count[i], big.mark = ","),
                      schema_counts$percent[i]))
    }
    
    # Warn if multiple schemas detected
    if (nrow(schema_counts) > 1) {
      message("  âš ï¸  Multiple schema versions detected in this file")
    }
  }
  
  invisible(schema_counts)
}


# ------------------------------------------------------------------------------
# Helper: Validate Schema Detection
# ------------------------------------------------------------------------------
#' Validate Schema Detection Results
#'
#' @description
#' Checks for unknown schemas and returns TRUE/FALSE.
#'
#' @param df Data frame with schema_version column
#'
#' @return Logical: TRUE if all schemas detected, FALSE otherwise
#'
#' @export
validate_schema_detection <- function(df) {
  
  if (!"schema_version" %in% names(df)) {
    warning("schema_version column not found")
    return(FALSE)
  }
  
  unknown_count <- sum(df$schema_version == "unknown", na.rm = TRUE)
  
  if (unknown_count > 0) {
    warning(sprintf(
      "%s rows have unknown schema (%.1f%%)",
      format(unknown_count, big.mark = ","),
      100 * unknown_count / nrow(df)
    ))
    return(FALSE)
  }
  
  TRUE
}


# ------------------------------------------------------------------------------
# Helper: Get Schema Summary (returns data, doesn't print)
# ------------------------------------------------------------------------------
#' Get Schema Summary Statistics
#'
#' @description
#' Returns schema distribution as a data frame (non-printing version).
#'
#' @param df Data frame with schema_version column
#'
#' @return Data frame with columns: schema_version, count, percent
#'
#' @export
get_schema_summary <- function(df) {
  
  if (!"schema_version" %in% names(df)) {
    stop("Data frame must have schema_version column")
  }
  
  schema_counts <- as.data.frame(table(df$schema_version))
  names(schema_counts) <- c("schema_version", "count")
  schema_counts$percent <- round(100 * schema_counts$count / nrow(df), 1)
  
  schema_counts
}