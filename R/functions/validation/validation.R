# =============================================================================
# UTILITY: validation.R - Data Validation Assertions (LOCKED CONTRACT)
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# - Provides centralized assertion and validation functions
# - Used by all modules and workflows
# PURPOSE
# -------
# Provides comprehensive data validation, input assertion, and schema
# enforcement for all pipeline workflows. Contains both universal helpers
# (usable across any script) and domain-specific validators for KPro data.
#
# This module is the central authority for data quality validation. It focuses
# purely on validating DATA (is the data correct?) and does NOT handle
# execution tracking or reporting (see validation_reporting.R for that).
#
# By centralizing validation logic here, we ensure consistent error messages,
# reduce code duplication across workflows, and make the codebase easier to
# maintain.
#
# VALIDATION CONTRACT
# -------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Universal input validation (assert_* functions)
#    - Stop execution immediately on invalid input
#    - Provide clear, actionable error messages
#    - Include hints about how to fix the problem
#    - Zero dependencies on domain logic
#
# 2. Composite validators (validate_* functions)
#    - Combine multiple assertions for common patterns
#    - Reduce boilerplate in workflow scripts
#    - Domain-aware where appropriate
#
# 3. Schema enforcement (enforce_* functions)
#    - enforce_unified_schema: For Module 2 output (kpro_master)
#    - Returns new tibbles, never modifies in place
#
# 4. Quality checks (check_* functions)
#    - check_column_completeness: % non-NA per column
#    - check_duplicates: Reports potential issues
#    - validate_calls_per_night: Ensures logical consistency
#
# 5. Non-destructive
#    - Assertion functions stop or return invisibly
#    - Validation functions report issues but don't fix them
#    - Enforcement functions return new tibbles
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Transform schema versions (standardization/standardization.R)
#   - Calculate metrics like CallsPerHour (analysis/callspernight.R)
#   - Generate visualizations (output/visualization.R)
#   - Read or write files (core/utilities.R)
#   - Track execution events (core/validation_reporting.R)
#   - Generate HTML/YAML reports (core/validation_reporting.R)
#   - Make assumptions about what "should" be in the data
#
# DEPENDENCIES
# ------------
# R Packages:
#   - dplyr: distinct, filter, summarize, mutate, select, arrange
#   - purrr: map_dfr (for check_column_completeness)
#   - tibble: tibble (for data structure creation)
#
# Internal Dependencies: None
#
# FUNCTIONS PROVIDED
# ------------------
#
# Universal Assertions - Input validation with clear error messages:
#
#   - assert_data_frame():
#       Uses packages: base R (is.data.frame, class)
#       Calls internal: none
#       Purpose: Validate input is data frame
#
#   - assert_not_empty():
#       Uses packages: base R (nrow)
#       Calls internal: none
#       Purpose: Validate data frame has at least one row
#
#   - assert_columns_exist():
#       Uses packages: base R (setdiff)
#       Calls internal: none
#       Purpose: Validate required columns present with helpful hints
#
#   - assert_column_type():
#       Uses packages: base R (class, inherits)
#       Calls internal: assert_columns_exist()
#       Purpose: Validate column data type
#
#   - assert_not_na():
#       Uses packages: base R (any, is.na)
#       Calls internal: none
#       Purpose: Validate column has no missing values
#
#   - assert_date_range():
#       Uses packages: base R (all, is.na)
#       Calls internal: none
#       Purpose: Validate date order (not decreasing)
#
#   - assert_time_format():
#       Uses packages: base R (grepl)
#       Calls internal: none
#       Purpose: Validate HH:MM:SS time format
#
#   - assert_row_count():
#       Uses packages: base R (nrow)
#       Calls internal: none
#       Purpose: Validate exact row count
#
#   - assert_file_exists():
#       Uses packages: base R (file.exists)
#       Calls internal: none
#       Purpose: Validate file exists with helpful hints
#
#   - assert_directory_exists():
#       Uses packages: base R (dir.exists, dir.create)
#       Calls internal: none
#       Purpose: Validate/create directory
#
#   - assert_scalar_string():
#       Uses packages: base R (is.character, length)
#       Calls internal: none
#       Purpose: Validate single character string
#
# Composite Validators - Combine assertions for common validation patterns:
#
#   - validate_data_frame():
#       Uses packages: none
#       Calls internal: assert_data_frame(), assert_not_empty(), assert_columns_exist()
#       Purpose: Run combined checks for standard data frame validation
#
#   - validate_cpn_data():
#       Uses packages: dplyr (select, across)
#       Calls internal: assert_data_frame(), assert_columns_exist(),
#                       assert_not_na(), assert_date_range()
#       Purpose: Domain-specific validation for CallsPerNight templates
#
#   - validate_master_data():
#       Uses packages: dplyr (select)
#       Calls internal: assert_data_frame(), assert_columns_exist()
#       Purpose: Domain-specific validation for master file
#
# Schema Enforcement - Ensure data conforms to unified schema:
#
#   - enforce_unified_schema():
#       Uses packages: dplyr (mutate, select, all_of)
#       Calls internal: assert_data_frame(), assert_columns_exist()
#       Purpose: Reorder columns and ensure unified schema compliance
#
# Quality Checks - Generate reports on data quality:
#
#   - check_column_completeness():
#       Uses packages: purrr (map_dfr), dplyr (summarize, mutate), base R (sum, is.na)
#       Calls internal: assert_data_frame()
#       Purpose: Report percentage of missing (NA) values per column
#
#   - check_duplicates():
#       Uses packages: dplyr (distinct, filter, n), base R (nrow)
#       Calls internal: assert_data_frame()
#       Purpose: Detect and report duplicate rows
#
#   - validate_calls_per_night():
#       Uses packages: base R (all, is.na, >=, <=)
#       Calls internal: assert_data_frame(), assert_columns_exist()
#       Purpose: Check logical consistency (calls >= 0, hours >= 0)
#
# USAGE
# -----
# # Universal assertions
# assert_data_frame(df)
# assert_columns_exist(df, c("Detector", "Night"), source_hint = "Module 3")
#
# # Domain validators
# validate_cpn_data(calls_per_night_df)
# validate_master_data(kpro_master)
#
# # Quality checks
# completeness <- check_column_completeness(df)
# duplicates <- check_duplicates(df, key_cols = c("Detector", "DateTime_local"))
#
# CHANGELOG
# ---------
# 2026-02-05: DOCUMENTATION FIX - Renamed "CONTENTS" to "FUNCTIONS PROVIDED"
#             - Updated to match documentation standards template
#             - Cleaned up orphaned changelog entries
#             - Consolidated historical entries for clarity
# 2026-02-03: Moved orchestrator helpers to validation_reporting.R
#             - Removed init_stage_validation() → validation_reporting.R
#             - Removed complete_stage_validation() → validation_reporting.R
#             - Reduced from 1,279 to ~1,150 lines
#             - Now focused purely on data quality validation
#             - Improved separation of concerns (data validation vs execution tracking)
#             - Updated NON-GOALS to clarify scope
# 2026-02-03: Added orchestrator helpers for run_* functions
#             - Added init_stage_validation() to reduce initialization boilerplate
#             - Added complete_stage_validation() to reduce finalization boilerplate
#             - Eliminates ~16 lines per orchestrator stage
# 2026-01-15: Enhanced domain validators with better error messages
# 2026-01-12: Added check_column_completeness() and check_duplicates()
# 2026-01-10: Initial version with core assertions
# 2024-12-29: Added composite validators (validate_*)
# 2024-12-27: Split into enforce_unified_schema and enforce_master_schema
# 2024-12-26: Initial CODING_STANDARDS compliant version
#
# =============================================================================


# ==============================================================================
# UNIVERSAL ASSERTIONS
# ==============================================================================
# These functions validate inputs and stop execution with clear errors.
# They have zero domain dependencies and can be used anywhere.
# ==============================================================================


#' Assert Input is a Data Frame
#'
#' @description
#' Validates that input is a data frame or tibble. Stops with clear error if not.
#'
#' Standards Reference: 03_code_design_standards.md §2.1
#'
#' @param x Object to check.
#' @param arg_name Character. Name of argument for error message. Default: "Input"
#'
#' @return Invisible TRUE if valid, otherwise stops execution.
#'
#' @section CONTRACT:
#' - Stops if x is not a data frame or tibble
#' - Error message includes actual type received
#' - Returns invisibly on success (no output)
#'
#' @section DOES NOT:
#' - Check for empty data frames (use assert_not_empty)
#' - Validate column structure (use assert_columns_exist)
#' - Modify the input in any way
#'
#' @examples
#' \dontrun{
#' assert_data_frame(my_data)
#' assert_data_frame(cpn_final, "cpn_final")
#' }
#'
#' @export
assert_data_frame <- function(x, arg_name = "Input") {
  if (!is.data.frame(x)) {
    stop(sprintf(
      "%s must be a data frame.\n  Received: %s",
      arg_name,
      paste(class(x), collapse = ", ")
    ))
  }
  invisible(TRUE)
}


#' Assert Data Frame is Not Empty
#'
#' @description
#' Validates that data frame has at least one row. Use after assert_data_frame().
#'
#' Standards Reference: 03_code_design_standards.md §2.1
#'
#' @param df Data frame to check.
#' @param arg_name Character. Name of argument for error message. Default: "Data"
#'
#' @return Invisible TRUE if valid, otherwise stops execution.
#'
#' @section CONTRACT:
#' - Stops if df has zero rows
#' - Error message identifies the empty data frame
#' - Returns invisibly on success
#'
#' @section DOES NOT:
#' - Check if input is a data frame (use assert_data_frame first)
#' - Check for NULL inputs
#' - Validate column structure
#'
#' @examples
#' \dontrun{
#' assert_not_empty(cpn_final, "cpn_final")
#' }
#'
#' @export
assert_not_empty <- function(df, arg_name = "Data") {
  if (nrow(df) == 0) {
    stop(sprintf("%s is empty - no data to process", arg_name))
  }
  invisible(TRUE)
}


#' Assert Data Frame Has Expected Row Count
#'
#' @description
#' Validates that data frame has exactly N rows. Useful for single-row
#' summaries or fixed-structure data like study_summary.
#'
#' Standards Reference: 03_code_design_standards.md §2.1
#'
#' @param df Data frame to check.
#' @param expected_rows Integer. Expected number of rows.
#' @param arg_name Character. Name of argument for error message. Default: "Data"
#'
#' @return Invisible TRUE if valid, otherwise stops execution.
#'
#' @section CONTRACT:
#' - Stops if row count doesn't match exactly
#' - Error message shows actual vs expected
#' - Returns invisibly on success
#'
#' @section DOES NOT:
#' - Check minimum rows (use validate_data_frame with min_rows)
#' - Validate data frame structure
#'
#' @examples
#' \dontrun{
#' # Ensure study summary is single row
#' assert_row_count(study_summary, 1, "study_summary")
#' }
#'
#' @export
assert_row_count <- function(df, expected_rows, arg_name = "Data") {
  actual_rows <- nrow(df)
  if (actual_rows != expected_rows) {
    stop(sprintf(
      "%s must have exactly %d row(s), but has %d rows",
      arg_name, expected_rows, actual_rows
    ))
  }
  invisible(TRUE)
}


#' Assert Required Columns Exist
#'
#' @description
#' Validates that all required columns are present in data frame. Provides
#' helpful hints about which workflow produces the expected data.
#'
#' Standards Reference: 03_code_design_standards.md §2.2
#'
#' @param df Data frame to check.
#' @param required_cols Character vector. Required column names.
#' @param source_hint Character or NULL. Optional hint about which function/script
#'   produces this data structure (e.g., "run_phase1_data_preparation()", "02_standardize.R").
#'
#' @return Invisible TRUE if valid, otherwise stops execution.
#'
#' @section CONTRACT:
#' - Stops if any required columns are missing
#' - Error lists ALL missing columns (not just first)
#' - source_hint helps user know what to run
#' - Returns invisibly on success
#'
#' @section DOES NOT:
#' - Check column types (use assert_column_type)
#' - Check for extra columns
#' - Modify column order
#'
#' @examples
#' \dontrun{
#' assert_columns_exist(
#'   cpn_final,
#'   c("Detector", "Night", "CallsPerNight"),
#'   source_hint = "run_phase3_analysis_reporting()"
#' )
#' }
#'
#' @export
assert_columns_exist <- function(df, required_cols, source_hint = NULL) {
  
  missing_cols <- setdiff(required_cols, names(df))
  
  if (length(missing_cols) > 0) {
    hint_msg <- if (!is.null(source_hint)) {
      sprintf("\n  Hint: Did you run %s?", source_hint)
    } else {
      ""
    }
    
    stop(sprintf(
      "Missing required columns: %s%s",
      paste(missing_cols, collapse = ", "),
      hint_msg
    ))
  }
  
  invisible(TRUE)
}


#' Assert Column is Specific Type
#'
#' @description
#' Validates that a specific column has the expected type. Supports common
#' R types including Date and POSIXct.
#'
#' Standards Reference: 03_code_design_standards.md §2.1
#'
#' @param df Data frame containing the column.
#' @param col_name Character. Name of column to check.
#' @param expected_type Character. Expected type: "numeric", "character",
#'   "Date", "POSIXct", "POSIXt", "logical", "integer".
#'
#' @return Invisible TRUE if valid, otherwise stops execution.
#'
#' @section CONTRACT:
#' - Stops if column type doesn't match
#' - Error shows actual type received
#' - Returns invisibly on success
#'
#' @section DOES NOT:
#' - Coerce types
#' - Check column values
#'
#' @examples
#' \dontrun{
#' assert_column_type(cpn_final, "Night", "Date")
#' assert_column_type(cpn_final, "CallsPerNight", "numeric")
#' }
#'
#' @export
assert_column_type <- function(df, col_name, expected_type) {
  
  assert_columns_exist(df, col_name)
  
  actual_type <- class(df[[col_name]])[1]
  
  # Handle special cases where multiple types are acceptable
  if (expected_type == "POSIXct" && inherits(df[[col_name]], "POSIXt")) {
    return(invisible(TRUE))
  }
  
  if (!inherits(df[[col_name]], expected_type)) {
    stop(sprintf(
      "Column '%s' must be type '%s'.\n  Received: %s",
      col_name,
      expected_type,
      actual_type
    ))
  }
  
  invisible(TRUE)
}


#' Assert Column Has No NA Values
#'
#' @description
#' Validates that a column has no missing values.
#'
#' Standards Reference: 03_code_design_standards.md §2.1
#'
#' @param df Data frame containing the column.
#' @param col_name Character. Name of column to check.
#'
#' @return Invisible TRUE if valid, otherwise stops execution.
#'
#' @section CONTRACT:
#' - Stops if any NA values found
#' - Error includes count of NA values
#' - Returns invisibly on success
#'
#' @section DOES NOT:
#' - Remove NA values
#' - Fill NA values
#'
#' @examples
#' \dontrun{
#' assert_not_na(cpn_final, "Detector")
#' }
#'
#' @export
assert_not_na <- function(df, col_name) {
  
  assert_columns_exist(df, col_name)
  
  n_na <- sum(is.na(df[[col_name]]))
  
  if (n_na > 0) {
    stop(sprintf(
      "Column '%s' contains %d NA values (%.1f%% of %d rows)",
      col_name,
      n_na,
      100 * n_na / nrow(df),
      nrow(df)
    ))
  }
  
  invisible(TRUE)
}


#' Assert Valid Date Range
#'
#' @description
#' Validates that end_date >= start_date. Coerces character inputs to Date.
#'
#' Standards Reference: 03_code_design_standards.md §2.1
#'
#' @param start_date Date or character. Start date.
#' @param end_date Date or character. End date.
#'
#' @return Invisible TRUE if valid, otherwise stops execution.
#'
#' @section CONTRACT:
#' - Coerces to Date if character
#' - Stops if end < start
#' - Stops if either date is NA
#' - Returns invisibly on success
#'
#' @section DOES NOT:
#' - Validate date format (relies on as.Date)
#' - Check for future dates
#'
#' @examples
#' \dontrun{
#' assert_date_range("2024-05-01", "2024-08-31")
#' }
#'
#' @export
assert_date_range <- function(start_date, end_date) {
  
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  
  if (is.na(start_date)) {
    stop("start_date is invalid or NA")
  }
  
  if (is.na(end_date)) {
    stop("end_date is invalid or NA")
  }
  
  if (end_date < start_date) {
    stop(sprintf(
      "end_date (%s) cannot be before start_date (%s)",
      end_date, start_date
    ))
  }
  
  invisible(TRUE)
}


#' Assert Valid Time Format (HH:MM:SS)
#'
#' @description
#' Validates that a time string matches HH:MM:SS format (24-hour clock).
#'
#' Standards Reference: 03_code_design_standards.md §2.1
#'
#' @param time_string Character. Time string to validate.
#' @param arg_name Character. Name for error message. Default: "Time"
#'
#' @return Invisible TRUE if valid, otherwise stops execution.
#'
#' @section CONTRACT:
#' - Stops if not character
#' - Stops if doesn't match HH:MM:SS pattern
#' - Returns invisibly on success
#'
#' @section DOES NOT:
#' - Validate that time is logical (e.g., 25:00:00 would pass regex)
#' - Parse the time
#'
#' @examples
#' \dontrun{
#' assert_time_format("20:00:00", "recording_start")
#' }
#'
#' @export
assert_time_format <- function(time_string, arg_name = "Time") {
  
  if (is.na(time_string) || !is.character(time_string)) {
    stop(sprintf("%s must be a character string", arg_name))
  }
  
  if (!grepl("^\\d{2}:\\d{2}:\\d{2}$", time_string)) {
    stop(sprintf(
      "%s must be in HH:MM:SS format (e.g., '20:00:00').\n  Received: '%s'",
      arg_name, time_string
    ))
  }
  
  invisible(TRUE)
}


#' Assert File Exists
#'
#' @description
#' Validates that a file exists at the given path. Provides helpful hint
#' about how to create the file if missing.
#'
#' Standards Reference: 03_code_design_standards.md §2.2
#'
#' @param file_path Character. Path to check.
#' @param hint Character or NULL. Optional hint about how to create the file.
#'
#' @return Invisible TRUE if exists, otherwise stops execution.
#'
#' @section CONTRACT:
#' - Stops if file doesn't exist
#' - Error includes full path
#' - hint appears as additional guidance
#' - Returns invisibly on success
#'
#' @section DOES NOT:
#' - Check file permissions
#' - Check file contents
#' - Create the file
#'
#' @examples
#' \dontrun{
#' assert_file_exists(
#'   "inst/config/study_parameters.yaml",
#'   hint = "Run Shiny app to configure study parameters"
#' )
#' }
#'
#' @export
assert_file_exists <- function(file_path, hint = NULL) {
  
  if (!file.exists(file_path)) {
    hint_msg <- if (!is.null(hint)) {
      sprintf("\n  Hint: %s", hint)
    } else {
      ""
    }
    
    stop(sprintf("File not found: %s%s", file_path, hint_msg))
  }
  
  invisible(TRUE)
}


#' Assert Directory Exists (Create if Needed)
#'
#' @description
#' Checks if directory exists. Optionally creates it if missing.
#'
#' Standards Reference: 03_code_design_standards.md §2.1
#'
#' @param dir_path Character. Directory path.
#' @param create Logical. Create directory if missing? Default: TRUE
#'
#' @return Invisible TRUE on success.
#'
#' @section CONTRACT:
#' - If create=TRUE: Creates directory (including parents) if missing
#' - If create=FALSE: Stops if directory missing
#' - Messages when creating directory
#' - Returns invisibly on success
#'
#' @section DOES NOT:
#' - Check write permissions
#' - Remove existing contents
#'
#' @export
assert_directory_exists <- function(dir_path, create = TRUE) {
  
  if (!dir.exists(dir_path)) {
    if (create) {
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
      message(sprintf("Created directory: %s", dir_path))
    } else {
      stop(sprintf("Directory not found: %s", dir_path))
    }
  }
  
  invisible(TRUE)
}


#' Assert Value is a Single Character String
#'
#' @description
#' Validates that a value is a character vector of length 1.
#'
#' Standards Reference: 03_code_design_standards.md §2.1
#'
#' @param x Value to check.
#' @param arg_name Character. Name for error message. Default: "Value"
#'
#' @return Invisible TRUE if valid, otherwise stops execution.
#'
#' @section CONTRACT:
#' - Stops if not character or length != 1
#' - Error shows actual type and length
#' - Returns invisibly on success
#'
#' @section DOES NOT:
#' - Check for empty string
#' - Check string content
#'
#' @examples
#' \dontrun{
#' assert_scalar_string(file_path, "file_path")
#' }
#'
#' @export
assert_scalar_string <- function(x, arg_name = "Value") {
  
  if (!is.character(x) || length(x) != 1) {
    stop(sprintf(
      "%s must be a single character string.\n  Received: %s (length %d)",
      arg_name,
      paste(class(x), collapse = ", "),
      length(x)
    ))
  }
  
  invisible(TRUE)
}


# ==============================================================================
# COMPOSITE VALIDATORS
# ==============================================================================
# These combine multiple assertions for common patterns, reducing boilerplate.
# ==============================================================================


#' Validate Data Frame with Standard Checks
#'
#' @description
#' Performs standard validation: is data frame, not empty, has required columns.
#' Combines multiple assertions into one call for cleaner workflow code.
#'
#' Standards Reference: 03_code_design_standards.md §2.5
#'
#' @param df Data frame to validate.
#' @param required_cols Character vector or NULL. Required column names.
#' @param arg_name Character. Name for error messages. Default: "Data"
#' @param source_hint Character or NULL. Hint about data source function.
#' @param min_rows Integer. Minimum required rows. Default: 1 (not empty)
#'
#' @return Invisible TRUE if all checks pass.
#'
#' @section CONTRACT:
#' - Checks: is data frame, has min_rows, has required_cols
#' - Stops on first failure with clear message
#' - Returns invisibly on success
#'
#' @section DOES NOT:
#' - Check column types (use assert_column_type separately)
#' - Validate data values
#'
#' @examples
#' \dontrun{
#' validate_data_frame(
#'   cpn_final,
#'   required_cols = c("Detector", "Night", "CallsPerNight"),
#'   arg_name = "cpn_final",
#'   source_hint = "run_phase3_analysis_reporting()"
#' )
#' }
#'
#' @export
validate_data_frame <- function(df,
                                required_cols = NULL,
                                arg_name = "Data",
                                source_hint = NULL,
                                min_rows = 1) {
  
  # Check is data frame
  assert_data_frame(df, arg_name)
  
  # Check minimum rows
  if (nrow(df) < min_rows) {
    stop(sprintf(
      "%s must have at least %d row(s), but has %d rows",
      arg_name, min_rows, nrow(df)
    ))
  }
  
  # Check required columns
  if (!is.null(required_cols)) {
    assert_columns_exist(df, required_cols, source_hint)
  }
  
  invisible(TRUE)
}


#' Validate CallsPerNight Data Structure
#'
#' @description
#' Domain-specific validator for CallsPerNight data. Checks for standard
#' CPN columns and validates their types.
#'
#' Standards Reference: 04_data_standards.md §4.1
#'
#' @param cpn_data Data frame to validate.
#' @param require_status Logical. Require Status column? Default: FALSE
#' @param require_cph Logical. Require CallsPerHour column? Default: FALSE
#'
#' @return Invisible TRUE if valid.
#'
#' @section CONTRACT:
#' - Validates: Detector, Night, CallsPerNight, RecordingHours
#' - Optionally validates: Status, CallsPerHour
#' - Checks Night is Date, numeric columns are numeric
#' - Stops on first failure
#'
#' @section DOES NOT:
#' - Validate data values (e.g., negative hours)
#' - Check for duplicates
#'
#' @examples
#' \dontrun{
#' validate_cpn_data(cpn_final, require_status = TRUE, require_cph = TRUE)
#' }
#'
#' @export
validate_cpn_data <- function(cpn_data,
                              require_status = FALSE,
                              require_cph = FALSE) {
  
  # Base required columns
  required <- c("Detector", "Night", "CallsPerNight", "RecordingHours")
  
  if (require_status) required <- c(required, "Status")
  if (require_cph) required <- c(required, "CallsPerHour")
  
  validate_data_frame(
    cpn_data,
    required_cols = required,
    arg_name = "CallsPerNight data",
    source_hint = "run_phase3_analysis_reporting()"
  )
  
  # Type checks
  assert_column_type(cpn_data, "Night", "Date")
  assert_column_type(cpn_data, "CallsPerNight", "numeric")
  assert_column_type(cpn_data, "RecordingHours", "numeric")
  
  if (require_cph) {
    assert_column_type(cpn_data, "CallsPerHour", "numeric")
  }
  
  invisible(TRUE)
}


#' Validate Master File Data Structure
#'
#' @description
#' Domain-specific validator for Master file data. Checks for standard
#' master columns from Module 2.
#'
#' Standards Reference: 04_data_standards.md §2.2
#'
#' @param master_data Data frame to validate.
#'
#' @return Invisible TRUE if valid.
#'
#' @section CONTRACT:
#' - Validates: Detector, DateTime_local, auto_id
#' - Stops on first failure
#'
#' @section DOES NOT:
#' - Validate all possible master columns
#' - Check DateTime timezone
#'
#' @examples
#' \dontrun{
#' validate_master_data(kpro_master)
#' }
#'
#' @export
validate_master_data <- function(master_data) {
  
  required <- c("Detector", "DateTime_local", "auto_id")
  
  validate_data_frame(
    master_data,
    required_cols = required,
    arg_name = "Master data",
    source_hint = "run_phase1_data_preparation()"
  )
  
  invisible(TRUE)
}


# ==============================================================================
# SCHEMA ENFORCEMENT
# ==============================================================================


#' Enforce Unified Schema on Master Data
#'
#' @description
#' Validates that master data conforms to unified schema requirements.
#' Returns new tibble with enforced schema, never modifies input.
#'
#' Standards Reference: 04_data_standards.md §2.2
#'
#' @param df Data frame after standardization.
#' @param verbose Logical. Print progress messages? Default: FALSE
#'
#' @return Tibble with enforced unified schema.
#'
#' @section CONTRACT:
#' - Validates required core columns exist
#' - Ensures Detector and auto_id are character
#' - Returns new tibble (input unchanged)
#'
#' @section DOES NOT:
#' - Add missing columns
#' - Transform schema versions
#' - Modify column values
#'
#' @export
enforce_unified_schema <- function(df, verbose = FALSE) {
  
  # Core required columns for unified schema
  required_cols <- c("Detector", "DateTime_local", "auto_id")
  
  validate_data_frame(
    df,
    required_cols = required_cols,
    arg_name = "Master data for schema enforcement",
    source_hint = "run_phase1_data_preparation()"
  )
  
  # Ensure key columns are character
  df <- df %>%
    dplyr::mutate(
      Detector = as.character(Detector),
      auto_id = as.character(auto_id)
    )
  
  if (verbose) {
    message(sprintf("  [OK] Unified schema enforced on %d rows", nrow(df)))
  }
  
  df
}


#' Finalize Master Columns
#'
#' @description
#' Removes unwanted columns, ensures all required columns exist, and reorders
#' to master schema layout.
#'
#' Standards Reference: 04_data_standards.md §2.2
#'
#' @param df Data frame after datetime_local conversion.
#' @param verbose Logical. Print status messages? Default: FALSE
#'
#' @return Data frame with finalized column structure.
#'
#' @section CONTRACT:
#' - Removes unwanted metadata columns (orgid, userid, etc.)
#' - Reorders columns to standard master layout
#' - Preserves all data rows
#'
#' @section DOES NOT:
#' - Filter rows
#' - Modify column values
#' - Validate data quality
#'
#' @export
finalize_master_columns <- function(df, verbose = FALSE) {
  
  # -------------------------
  # Remove unwanted columns
  # -------------------------
  
  columns_to_remove <- c(
    "orgid", "userid", "review_orig", "review_userid",
    "inpathmd5", "outpathmd5fs", "outpathmd5zc",
    "date", "time", "hour",  # Remove lowercase UTC columns
    "date_12", "time_12", "hour_12"  # Remove 12-hour format columns
  )
  
  # Find which columns actually exist (case-insensitive)
  cols_to_drop <- c()
  for (col in columns_to_remove) {
    actual_col <- grep(paste0("^", col, "$"), names(df), ignore.case = TRUE, value = TRUE)
    if (length(actual_col) > 0) {
      cols_to_drop <- c(cols_to_drop, actual_col)
    }
  }
  
  if (length(cols_to_drop) > 0) {
    if (verbose) message(sprintf("  Removing %d unwanted columns", length(cols_to_drop)))
    df <- df %>%
      dplyr::select(-dplyr::all_of(cols_to_drop))
  }
  
  # -------------------------
  # Define master column order
  # -------------------------
  
  # Core identification columns
  core_cols <- c(
    "Detector",
    "DateTime_local",
    "Date_local",
    "Time_local",
    "Hour_local"
  )
  
  # Species identification columns (auto_id through margin)
  species_cols <- c(
    "auto_id", "match_ratio", "match_dist_1", "match_dist_2", "match_dist_3",
    "match_dist_4", "reject_class_1", "reject_class_2", "reject_class_3",
    "fc", "sc", "slope", "offset", "margin"
  )
  
  # Alternate species columns
  alternate_cols <- c("alternate_1", "alternate_2", "alternate_3")
  
  # Manual ID
  manual_cols <- c("manual_id")
  
  # Acoustic parameters (n through files)
  acoustic_cols <- c(
    "n", "pulses", "dur", "frq_max", "frq_min", "frq_bw", "te",
    "pulse_max", "dur_pulse", "frq_max_pulse", "frq_min_pulse",
    "frq_bw_pulse", "frq_ctr_pulse", "frq_knee", "frq_ctr", "body",
    "toe", "calls", "files"
  )
  
  # Call characteristics (channel through duration)
  call_cols <- c(
    "channel", "fmax", "fmin", "duration"
  )
  
  # Metadata columns
  metadata_cols <- c(
    "detector_id", "source_file", "folder", "in_file",
    "out_file_fs", "out_file_zc"
  )
  
  # Combine in requested order
  desired_order <- c(
    core_cols,
    species_cols,
    alternate_cols,
    manual_cols,
    acoustic_cols,
    call_cols,
    metadata_cols
  )
  
  # -------------------------
  # Reorder columns
  # -------------------------
  
  # Find which desired columns exist
  existing_desired <- intersect(desired_order, names(df))
  
  # Find any columns not in desired order (put at end)
  extra_cols <- setdiff(names(df), desired_order)
  
  # Reorder: desired columns first, then extras
  final_order <- c(existing_desired, extra_cols)
  
  df <- df %>%
    dplyr::select(dplyr::all_of(final_order))
  
  if (verbose) {
    message(sprintf("  [OK] Finalized %d columns in master schema order", ncol(df)))
  }
  
  df
}


# ==============================================================================
# QUALITY CHECKS
# ==============================================================================


#' Check Column Completeness
#'
#' @description
#' Reports percentage of non-NA values for each column. Useful for
#' data quality assessment.
#'
#' Standards Reference: 04_data_standards.md §5.1
#'
#' @param df Data frame to check.
#'
#' @return Tibble with columns: column_name, n_total, n_complete, pct_complete.
#'
#' @section CONTRACT:
#' - Reports ALL columns
#' - Returns tibble sorted by pct_complete ascending (worst first)
#' - Does not stop on any completeness level
#'
#' @section DOES NOT:
#' - Fix incomplete data
#' - Filter out incomplete columns
#'
#' @export
check_column_completeness <- function(df) {
  
  assert_data_frame(df, "df")
  
  completeness <- purrr::map_dfr(names(df), function(col) {
    tibble::tibble(
      column_name = col,
      n_total = nrow(df),
      n_complete = sum(!is.na(df[[col]])),
      pct_complete = round(100 * n_complete / n_total, 1)
    )
  })
  
  completeness %>%
    dplyr::arrange(pct_complete)
}


#' Check for Duplicate Rows
#'
#' @description
#' Reports duplicate rows based on specified columns. Does not remove
#' duplicates - just reports them for review.
#'
#' Standards Reference: 04_data_standards.md §5.1
#'
#' @param df Data frame to check.
#' @param key_cols Character vector. Columns that define uniqueness.
#'   Default: NULL (use all columns).
#'
#' @return List with: n_total, n_unique, n_duplicates, duplicate_rows (tibble).
#'
#' @section CONTRACT:
#' - Reports counts of total, unique, and duplicate rows
#' - Returns tibble of duplicate rows for inspection
#' - Does not modify input
#'
#' @section DOES NOT:
#' - Remove duplicates (use dplyr::distinct for that)
#' - Stop on finding duplicates
#'
#' @export
check_duplicates <- function(df, key_cols = NULL) {
  
  assert_data_frame(df, "df")
  
  if (is.null(key_cols)) {
    key_cols <- names(df)
  }
  
  # Find duplicates
  dup_check <- df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(key_cols))) %>%
    dplyr::mutate(.n_occurrences = dplyr::n()) %>%
    dplyr::ungroup()
  
  duplicates <- dup_check %>%
    dplyr::filter(.n_occurrences > 1) %>%
    dplyr::select(-.n_occurrences)
  
  list(
    n_total = nrow(df),
    n_unique = nrow(dplyr::distinct(df, dplyr::across(dplyr::all_of(key_cols)))),
    n_duplicates = nrow(duplicates),
    duplicate_rows = duplicates
  )
}


#' Validate CallsPerNight Logical Consistency
#'
#' @description
#' Checks for logically inconsistent CallsPerNight values: NA, negative,
#' or unusually high values that may indicate data entry errors.
#'
#' Standards Reference: 04_data_standards.md §4.1
#'
#' @param df Data frame with CallsPerNight column.
#' @param max_calls Numeric. Maximum plausible calls per night. Default: 10000.
#'
#' @return Tibble of rows with problematic values.
#'
#' @section CONTRACT:
#' - Returns rows where CallsPerNight is NA, negative, or > max_calls
#' - Returns empty tibble if all values are valid
#' - Does not modify input
#'
#' @section DOES NOT:
#' - Fix problematic values
#' - Stop on finding issues
#'
#' @export
validate_calls_per_night <- function(df, max_calls = 10000) {
  
  assert_columns_exist(df, "CallsPerNight")
  
  df %>%
    dplyr::filter(
      is.na(CallsPerNight) |
        CallsPerNight < 0 |
        CallsPerNight > max_calls
    )
}

# ==============================================================================
# END OF VALIDATION MODULE
# ==============================================================================