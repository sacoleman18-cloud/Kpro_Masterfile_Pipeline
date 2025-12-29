# =============================================================================
# core/utilities.R — FOUNDATIONAL UTILITIES (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Foundational utilities with ZERO internal dependencies. All other modules
# depend on this file. Must be loaded first.
#
# UTILITIES CONTRACT
# ------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Zero internal dependencies
#    - This file imports ONLY external packages (base R, readr, yaml, etc.)
#    - MUST NOT source or depend on any other project files
#
# 2. Logging
#    - All log functions write to logs/ directory
#    - Timestamps use ISO 8601 format
#    - Log levels: INFO, WARNING, ERROR
#
# 3. File I/O
#    - safe_read_csv() ALWAYS returns tibble or NULL (never errors)
#    - All columns read as character by default
#    - Versioned saves auto-increment (v1, v2, v3...)
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Perform any data transformations specific to KPro data
#   - Contain domain logic (bat data, schemas, detectors)
#   - Depend on any other project module
#
# DEPENDENCIES
# ------------
# External only:
#   - readr: read_csv, write_csv
#   - base R: file operations
#
# CONTENTS
# --------
#   - safe_read_csv()
#   - log_message()
#   - initialize_pipeline_log()
#   - convert_empty_to_na()
#   - fill_readme_template()
#   - format_datetime_for_export()  [NEW - DateTime formatting]
#
# =============================================================================


# ------------------------------------------------------------------------------
# Safe CSV Reader with Error Logging
# ------------------------------------------------------------------------------

#' Safely read a CSV file with error logging
#'
#' @description
#' Reads a CSV file from disk without interrupting pipeline execution.
#'
#' @param file_path Character scalar. Path to CSV file.
#' @param error_log_path Character scalar. Path to error log file.
#' @param ... Additional arguments passed to readr::read_csv()
#'
#' @return Tibble if read succeeds; NULL otherwise.
#'
#' @section CONTRACT:
#' - Reads all columns as character by default
#' - Returns NULL on failure instead of stopping execution
#' - Logs read errors with timestamps
#'
#' @section DOES NOT:
#' - Guess column types
#' - Modify data values
#' - Enforce schema requirements
#'
#' @export
safe_read_csv <- function(file_path,
                          error_log_path = "logs/error_log.txt",
                          ...) {
  
  # Input validation
  if (!is.character(file_path) || length(file_path) != 1) {
    stop("file_path must be a single character string")
  }
  
  if (!is.character(error_log_path) || length(error_log_path) != 1) {
    stop("error_log_path must be a single character string")
  }
  
  # Ensure log directory exists
  log_dir <- dirname(error_log_path)
  if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)
  
  result <- NULL
  
  tryCatch(
    {
      result <- readr::read_csv(
        file_path,
        col_types = readr::cols(.default = readr::col_character()),
        ...
      )
    },
    error = function(e) {
      msg <- paste(Sys.time(), "-", file_path, "-", e$message)
      writeLines(msg, error_log_path, useBytes = TRUE)
    }
  )
  
  result
}


# ------------------------------------------------------------------------------
# Convert Empty Strings to NA
# ------------------------------------------------------------------------------

#' Convert empty strings to NA
#'
#' @description
#' Replaces empty or whitespace-only strings with NA in selected columns.
#'
#' @param df Data frame.
#' @param columns Character vector of column names.
#'
#' @return Data frame with empty strings replaced by NA.
#'
#' @section CONTRACT:
#' - Operates only on specified columns
#' - Preserves column types
#'
#' @section DOES NOT:
#' - Rename columns
#' - Modify non-targeted columns
#'
#' @export
convert_empty_to_na <- function(df, columns) {
  
  # Input validation
  if (!is.data.frame(df)) stop("df must be a data frame")
  if (!is.character(columns)) stop("columns must be a character vector")
  
  missing_cols <- setdiff(columns, names(df))
  if (length(missing_cols) > 0) {
    stop("Columns not found: ", paste(missing_cols, collapse = ", "))
  }
  
  # Replace empty strings with NA
  df %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(columns),
        ~ ifelse(trimws(.) == "", NA, .)
      )
    )
}

# ------------------------------------------------------------------------------
# Fill README from Template
# ------------------------------------------------------------------------------

#' Fill README.md from template
#'
#' @description
#' Fills a README template using study parameters and pipeline metadata.
#'
#' @param template_path Path to README template.
#' @param output_path Path for README.md.
#' @param parameters List from load_study_parameters().
#' @param log_path Path to pipeline log file.
#'
#' @return Invisible TRUE.
#'
#' @details
#' Performs string substitution on template placeholders:
#' - [Study Name], [Start date], [End date]
#' - [Start time], [End time]
#' - [List detector IDs]
#' - [Auto-filled from pipeline_log.txt]
#'
#' @section CONTRACT:
#' - Performs string substitution only
#' - Writes output deterministically
#'
#' @section DOES NOT:
#' - Infer missing parameters
#' - Modify input template
#' - Validate parameter structure
#'
#' @export
fill_readme_template <- function(template_path,
                                 output_path = "README.md",
                                 parameters,
                                 log_path = "logs/pipeline_log.txt") {
  
  # Input validation
  if (!file.exists(template_path)) {
    stop("Template not found: ", template_path)
  }
  
  if (!is.list(parameters)) {
    stop("parameters must be a list")
  }
  
  # Read template
  template <- readLines(template_path)
  
  # Extract processing date from log
  processing_date <- if (file.exists(log_path)) {
    stringr::str_extract(tail(readLines(log_path), 1), "\\d{4}-\\d{2}-\\d{2}")
  } else {
    as.character(Sys.Date())
  }
  
  # Perform substitutions
  filled <- template %>%
    stringr::str_replace_all(
      "\\[Study Name\\]",
      parameters$study_parameters$study_name %||% "Unnamed Study"
    ) %>%
    stringr::str_replace_all(
      "\\[Start date\\]",
      parameters$study_parameters$start_date
    ) %>%
    stringr::str_replace_all(
      "\\[End date\\]",
      parameters$study_parameters$end_date
    ) %>%
    stringr::str_replace_all(
      "\\[Start time\\]",
      parameters$study_parameters$recording_start
    ) %>%
    stringr::str_replace_all(
      "\\[End time\\]",
      parameters$study_parameters$recording_end
    ) %>%
    stringr::str_replace_all(
      "\\[List detector IDs\\]",
      paste(parameters$study_parameters$detectors, collapse = ", ")
    ) %>%
    stringr::str_replace_all(
      "\\[Auto-filled from pipeline_log.txt\\]",
      processing_date
    )
  
  # Write output
  writeLines(filled, output_path)
  invisible(TRUE)
}


# ------------------------------------------------------------------------------
# Initialize Pipeline Log
# ------------------------------------------------------------------------------

#' Initialize pipeline log
#'
#' @description
#' Creates log file with header for new pipeline run.
#'
#' @param log_path Path to log file.
#'
#' @return Invisible TRUE.
#'
#' @section CONTRACT:
#' - Creates directories if needed
#' - Appends header to existing log
#' - Timestamps run
#'
#' @section DOES NOT:
#' - Clear existing log
#' - Rotate logs
#' - Validate previous entries
#'
#' @export
initialize_pipeline_log <- function(log_path = "logs/pipeline_log.txt") {
  
  # Ensure log directory exists
  log_dir <- dirname(log_path)
  if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)
  
  # Write header
  cat(
    paste0(
      "\n========================================\n",
      "PIPELINE RUN: ", Sys.time(), "\n",
      "========================================\n\n"
    ),
    file = log_path,
    append = TRUE
  )
  
  invisible(TRUE)
}


# ------------------------------------------------------------------------------
# Log Message with Timestamp
# ------------------------------------------------------------------------------

#' Write a timestamped message to a log file
#'
#' @description
#' Appends a timestamped message to a log file, creating directories if needed.
#'
#' @param msg Character message.
#' @param log_path Path to log file.
#'
#' @return Invisible NULL.
#'
#' @section CONTRACT:
#' - Append-only
#' - Timestamped
#' - Auto-creates directories
#'
#' @section DOES NOT:
#' - Rotate logs
#' - Silence errors
#' - Validate message format
#'
#' @export
log_message <- function(msg, log_path = "logs/pipeline_log.txt") {
  
  # Ensure log directory exists
  log_dir <- dirname(log_path)
  if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)
  
  # Write timestamped message
  cat(
    paste0("[", Sys.time(), "] ", msg, "\n"),
    file = log_path,
    append = TRUE
  )
  
  invisible(NULL)
}


# ------------------------------------------------------------------------------
# Format DateTime Columns for CSV Export (NEW)
# ------------------------------------------------------------------------------

#' Format DateTime Columns for US-Friendly CSV Export
#'
#' @description
#' Converts POSIXct DateTime columns to character strings with US-friendly
#' format before CSV export. This prevents readr::write_csv() from using
#' ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ).
#'
#' @param df Data frame containing DateTime columns.
#' @param datetime_cols Character vector of DateTime column names to format.
#'   Default: c("DateTime", "DateTime_UTC")
#' @param format Character string for strftime format.
#'   Default: "%m/%d/%Y %I:%M:%S %p" produces "10/6/2025  4:14:08 AM"
#'
#' @return Data frame with DateTime columns converted to formatted character strings.
#'
#' @details
#' **Default Format Breakdown:**
#' - %m = month (01-12)
#' - %d = day (01-31)
#' - %Y = 4-digit year
#' - %I = hour (01-12, 12-hour clock)
#' - %M = minute (00-59)
#' - %S = second (00-59)
#' - %p = AM/PM
#'
#' **Platform Differences:**
#' On Linux/Mac, use %-m and %-d to remove leading zeros.
#' On Windows, use %#m and %#d instead.
#'
#' **Usage:**
#' Call this function immediately before write_csv() to format DateTime
#' columns for human-readable export:
#'
#' ```r
#' # Format and save
#' data_formatted <- format_datetime_for_export(kpro_master)
#' readr::write_csv(data_formatted, "output.csv")
#' ```
#'
#' @section CONTRACT:
#' - Only formats columns that exist in datetime_cols parameter
#' - Only formats POSIXct columns (leaves character columns unchanged)
#' - Returns new data frame (non-destructive)
#' - Preserves all other columns unchanged
#' - Returns original data frame if no DateTime columns exist
#'
#' @section DOES NOT:
#' - Modify timezone (use convert_datetime_to_cst first)
#' - Write files to disk (caller's responsibility)
#' - Validate data quality
#' - Handle Date-only columns (only POSIXct)
#' - Modify the input data frame (returns new data frame)
#'
#' @examples
#' \dontrun{
#' # Format with default US format
#' formatted <- format_datetime_for_export(kpro_master)
#'
#' # Format with custom format (24-hour clock)
#' formatted <- format_datetime_for_export(
#'   kpro_master,
#'   format = "%m/%d/%Y %H:%M:%S"
#' )
#'
#' # Format only specific columns
#' formatted <- format_datetime_for_export(
#'   kpro_master,
#'   datetime_cols = c("DateTime")
#' )
#'
#' # Full workflow
#' data_formatted <- format_datetime_for_export(kpro_master)
#' readr::write_csv(data_formatted, "master_file.csv")
#' }
#'
#' @export
format_datetime_for_export <- function(df,
                                       datetime_cols = c("DateTime", "DateTime_UTC"),
                                       format = "%m/%d/%Y %I:%M:%S %p") {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(df)) {
    stop("df must be a data frame")
  }
  
  if (!is.character(datetime_cols)) {
    stop("datetime_cols must be a character vector")
  }
  
  if (!is.character(format) || length(format) != 1) {
    stop("format must be a single character string")
  }
  
  # -------------------------
  # Find which datetime_cols actually exist
  # -------------------------
  
  existing_cols <- intersect(datetime_cols, names(df))
  
  if (length(existing_cols) == 0) {
    # No DateTime columns to format - return as-is
    return(df)
  }
  
  # -------------------------
  # Format each DateTime column
  # -------------------------
  
  for (col in existing_cols) {
    # Only format if it's actually a POSIXct column
    if (inherits(df[[col]], "POSIXct") || inherits(df[[col]], "POSIXt")) {
      df[[col]] <- format(df[[col]], format = format)
    }
  }
  
  df
}