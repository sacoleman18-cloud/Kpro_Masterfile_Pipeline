# =============================================================================
# core/utilities.R — FOUNDATIONAL UTILITIES (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Foundational utilities with ZERO internal dependencies. All other modules
# depend on this file. Must be loaded first. Provides logging, safe I/O,
# checkpoint management, and file discovery utilities.
#
# This module is the bedrock of the pipeline. By having zero dependencies on
# other project modules, it can be safely sourced first and provides the
# building blocks that all other modules use.
#
# UTILITIES CONTRACT
# ------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Zero internal dependencies
#    - This file imports ONLY external packages (base R, readr, lubridate)
#    - MUST NOT source or depend on any other project files
#
# 2. Logging
#    - All log functions write to logs/ directory
#    - Timestamps use ISO 8601 format
#    - Auto-creates directories as needed
#
# 3. File I/O
#    - safe_read_csv() ALWAYS returns tibble or NULL (never errors)
#    - All columns read as character by default (preserves original data)
#
# 4. Checkpoint Management
#    - Standard pattern for loading from memory or file
#    - find_most_recent_file() for locating latest outputs
#    - Workflow-specific loaders for common data types
#
# 5. Path Generation
#    - Timestamped paths for audit trail
#    - Versioned paths for incremental saves
#    - Consistent naming conventions
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Perform any data transformations specific to KPro data
#   - Contain domain logic (bat data, schemas, detectors)
#   - Depend on any other project module
#   - Perform complex input validation (use validation/validation.R)
#
# DEPENDENCIES
# ------------
# External only:
#   - readr: read_csv, write_csv
#   - lubridate: datetime parsing (for checkpoint type coercion)
#   - stringr: string manipulation
#   - base R: file operations
#
# CONTENTS
# --------
# Logging:
#   - log_message()
#   - initialize_pipeline_log()
#
# Safe I/O:
#   - safe_read_csv()
#   - convert_empty_to_na()
#   - ensure_dir_exists()
#
# File Discovery:
#   - find_most_recent_file()
#
# Checkpoint Management:
#   - load_or_checkpoint()
#   - load_intro_standardized()
#   - load_master_data()
#   - load_cpn_final()
#   - load_cpn_template_original()
#
# Path Generation:
#   - make_output_path()
#   - make_versioned_path()
#
# Template Utilities:
#   - fill_readme_template()
#
# Console Formatting:
#   - center_text()
#   - print_stage_header()
#   - print_workflow_summary()
#   - print_pipeline_complete()
#
# Operators:
#   - %||%
#
# CHECKPOINT FILE NAMING CONVENTIONS
# ----------------------------------
# All workflow outputs follow this pattern:
#   {workflow_num}_{base_name}_{timestamp_or_version}.csv
#
# Examples:
#   01_intro_standardized_20241229_143022.csv  (timestamped)
#   02_kpro_master_20241229_150315.csv         (timestamped)
#   03_CallsPerNight_Template_ORIGINAL_20241229_160000.csv
#   03_CallsPerNight_Template_EDIT_THIS_20241229_160000.csv
#   04_CallsPerNight_Final_v1.csv              (versioned)
#
# CHANGELOG
# ---------
# 2026-01-31: Refactored for standards compliance
#             - Added ensure_dir_exists() helper
#             - Added center_text() helper
#             - Added verbose parameter to safe_read_csv()
#             - Replaced Unicode checkmark with ASCII [OK]
#             - Standardized error messages to use sprintf
# 2024-12-29: Added find_most_recent_file()
# 2024-12-29: Added load_or_checkpoint() and workflow-specific loaders
# 2024-12-29: Added make_output_path() and make_versioned_path()
# 2024-12-26: Initial CODING_STANDARDS compliant version
#
# =============================================================================


# ==============================================================================
# DIRECTORY MANAGEMENT
# ==============================================================================


#' Ensure Directory Exists
#'
#' @description
#' Creates directory if it doesn't exist. Safe for repeated calls.
#' Used internally by logging and I/O functions to guarantee output
#' directories are available.
#'
#' @param dir_path Character. Directory path to ensure exists.
#'
#' @return Invisible TRUE.
#'
#' @section CONTRACT:
#' - Creates directory with recursive = TRUE
#' - Safe to call multiple times
#' - Never errors if directory already exists
#'
#' @section DOES NOT:
#' - Validate permissions
#' - Remove existing directories
#' - Create parent directories beyond recursive = TRUE
#'
#' @examples
#' \dontrun{
#' ensure_dir_exists("logs")
#' ensure_dir_exists("outputs/checkpoints")
#' }
#'
#' @export
ensure_dir_exists <- function(dir_path) {
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  invisible(TRUE)
}


# ==============================================================================
# LOGGING
# ==============================================================================


#' Write a Timestamped Message to Log File
#'
#' @description
#' Appends a timestamped message to a log file, creating directories if needed.
#' All pipeline operations should be logged for audit trail.
#'
#' @param msg Character. Message to log.
#' @param log_path Character. Path to log file. Default: "logs/pipeline_log.txt"
#'
#' @return Invisible NULL.
#'
#' @section CONTRACT:
#' - Append-only (never overwrites)
#' - Timestamped with ISO 8601 format
#' - Auto-creates log directory if missing
#' - Returns invisibly (no console output)
#'
#' @section DOES NOT:
#' - Rotate logs
#' - Silence errors
#' - Validate message format
#'
#' @examples
#' \dontrun{
#' log_message("Processing started")
#' log_message("[Stage 2.1] Loaded 50,000 rows")
#' }
#'
#' @export
log_message <- function(msg, log_path = "logs/pipeline_log.txt") {
  
  # Ensure log directory exists
  ensure_dir_exists(dirname(log_path))
  
  # Write timestamped message
  cat(
    paste0("[", Sys.time(), "] ", msg, "\n"),
    file = log_path,
    append = TRUE
  )
  
  invisible(NULL)
}


#' Initialize Pipeline Log
#'
#' @description
#' Creates log file with header for new pipeline run. Call at start of
#' each workflow script.
#'
#' @param log_path Character. Path to log file. Default: "logs/pipeline_log.txt"
#'
#' @return Invisible TRUE.
#'
#' @section CONTRACT:
#' - Creates directories if needed
#' - Appends header to existing log (does not clear)
#' - Timestamps the run start
#'
#' @section DOES NOT:
#' - Clear existing log
#' - Rotate logs
#' - Validate previous entries
#'
#' @export
initialize_pipeline_log <- function(log_path = "logs/pipeline_log.txt") {
  
  # Ensure log directory exists
  ensure_dir_exists(dirname(log_path))
  
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


# ==============================================================================
# SAFE I/O
# ==============================================================================


#' Safely Read a CSV File with Error Logging
#'
#' @description
#' Reads a CSV file from disk without interrupting pipeline execution.
#' On failure, logs the error and returns NULL instead of stopping.
#'
#' @param file_path Character. Path to CSV file.
#' @param error_log_path Character. Path to error log file.
#'   Default: "logs/error_log.txt"
#' @param verbose Logical. Print progress messages? Default: FALSE
#' @param ... Additional arguments passed to readr::read_csv().
#'
#' @return Tibble if read succeeds; NULL otherwise.
#'
#' @section CONTRACT:
#' - Reads all columns as character by default (preserves original data)
#' - Returns NULL on failure instead of stopping execution
#' - Logs read errors with timestamps
#' - Suppresses readr's column type messages
#' - Optional progress messages when verbose = TRUE
#'
#' @section DOES NOT:
#' - Guess column types (all columns are character)
#' - Modify data values
#' - Enforce schema requirements
#' - Stop execution on error
#'
#' @examples
#' \dontrun{
#' df <- safe_read_csv("data/raw.csv", verbose = TRUE)
#' if (is.null(df)) stop("Failed to load file")
#' }
#'
#' @export
safe_read_csv <- function(file_path,
                          error_log_path = "logs/error_log.txt",
                          verbose = FALSE,
                          ...) {
  
  # Input validation
  if (!is.character(file_path) || length(file_path) != 1) {
    stop("file_path must be a single character string")
  }
  
  if (!is.character(error_log_path) || length(error_log_path) != 1) {
    stop("error_log_path must be a single character string")
  }
  
  # Ensure log directory exists
  ensure_dir_exists(dirname(error_log_path))
  
  # Progress message
  if (verbose) {
    message(sprintf("  Reading: %s", basename(file_path)))
  }
  
  result <- NULL
  
  tryCatch(
    {
      result <- readr::read_csv(
        file_path,
        col_types = readr::cols(.default = readr::col_character()),
        ...
      )
      
      # Success message
      if (!is.null(result) && verbose) {
        message(sprintf("  [OK] Loaded %s rows", format(nrow(result), big.mark = ",")))
      }
    },
    error = function(e) {
      msg <- paste(Sys.time(), "-", file_path, "-", e$message)
      writeLines(msg, error_log_path, useBytes = TRUE)
    }
  )
  
  result
}


#' Convert Empty Strings to NA
#'
#' @description
#' Replaces empty or whitespace-only strings with NA in selected columns.
#' Useful for cleaning data after CSV import.
#'
#' @param df Data frame.
#' @param columns Character vector of column names to process.
#'
#' @return Data frame with empty strings replaced by NA in specified columns.
#'
#' @section CONTRACT:
#' - Operates only on specified columns
#' - Preserves column types
#' - Treats whitespace-only strings as empty
#'
#' @section DOES NOT:
#' - Rename columns
#' - Modify non-targeted columns
#' - Change column types
#'
#' @export
convert_empty_to_na <- function(df, columns) {
  
  # Input validation
  if (!is.data.frame(df)) {
    stop("df must be a data frame")
  }
  
  if (!is.character(columns)) {
    stop("columns must be a character vector")
  }
  
  missing_cols <- setdiff(columns, names(df))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "Columns not found: %s",
      paste(missing_cols, collapse = ", ")
    ))
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


# ==============================================================================
# FILE DISCOVERY
# ==============================================================================


#' Find Most Recent File Matching Pattern
#'
#' @description
#' Searches directory for files matching a regex pattern and returns
#' the most recently modified one. Essential for loading checkpoint files.
#'
#' @param directory Character. Directory to search.
#' @param pattern Character. Regex pattern to match filenames.
#' @param error_if_none Logical. Stop with error if no files found? Default: TRUE
#' @param hint Character or NULL. Hint message if no files found.
#'
#' @return Character. Full path to most recent matching file, or NULL if
#'   none found and error_if_none = FALSE.
#'
#' @section CONTRACT:
#' - Returns single file path (most recent by mtime)
#' - Stops if no matches found and error_if_none = TRUE
#' - Returns NULL if no matches and error_if_none = FALSE
#' - Pattern matches filename only (not full path)
#'
#' @section DOES NOT:
#' - Search subdirectories
#' - Validate file contents
#' - Load the file
#'
#' @examples
#' \dontrun{
#' # Find most recent master file
#' master_file <- find_most_recent_file(
#'   "outputs",
#'   "^02_kpro_master_.*\\.csv$",
#'   hint = "Run 02_standardize.R first"
#' )
#' }
#'
#' @export
find_most_recent_file <- function(directory,
                                  pattern,
                                  error_if_none = TRUE,
                                  hint = NULL) {
  
  # List matching files
  matching_files <- list.files(
    directory,
    pattern = pattern,
    full.names = TRUE
  )
  
  if (length(matching_files) == 0) {
    if (error_if_none) {
      hint_msg <- if (!is.null(hint)) {
        sprintf("\n  Hint: %s", hint)
      } else {
        ""
      }
      stop(sprintf(
        "No files matching '%s' found in %s/%s",
        pattern, directory, hint_msg
      ))
    } else {
      return(NULL)
    }
  }
  
  # Sort by modification time (most recent first)
  file_mtimes <- file.mtime(matching_files)
  most_recent <- matching_files[order(file_mtimes, decreasing = TRUE)][1]
  
  most_recent
}


# ==============================================================================
# CHECKPOINT MANAGEMENT
# ==============================================================================


#' Load Data from Memory or Checkpoint
#'
#' @description
#' Standard pattern for workflows: use data from memory if available,
#' otherwise load from most recent checkpoint file. Messages indicate
#' data source.
#'
#' @param var_name Character. Name of variable to check in global environment.
#' @param checkpoint_dir Character. Directory containing checkpoint files.
#' @param checkpoint_pattern Character. Regex pattern for checkpoint files.
#' @param loader_fn Function. Function to load file. Default: safe_read_csv
#' @param hint Character or NULL. Hint if checkpoint not found.
#' @param verbose Logical. Print status messages? Default: TRUE
#'
#' @return The data (from memory or loaded from file).
#'
#' @section CONTRACT:
#' - First checks if var_name exists in global environment
#' - If not, finds most recent checkpoint and loads it
#' - Returns the data (never NULL - stops on failure)
#' - Messages indicate source (memory vs file)
#'
#' @section DOES NOT:
#' - Validate data structure (do that after loading)
#' - Assign to global environment
#' - Cache the loaded data
#'
#' @examples
#' \dontrun{
#' # Generic usage
#' data <- load_or_checkpoint(
#'   "kpro_master",
#'   "outputs",
#'   "^02_kpro_master_.*\\.csv$",
#'   hint = "Run 02_standardize.R first"
#' )
#' }
#'
#' @export
load_or_checkpoint <- function(var_name,
                               checkpoint_dir,
                               checkpoint_pattern,
                               loader_fn = safe_read_csv,
                               hint = NULL,
                               verbose = TRUE) {
  
  # Check if variable exists in global environment
  if (exists(var_name, envir = .GlobalEnv)) {
    data <- get(var_name, envir = .GlobalEnv)
    
    if (verbose) {
      message(sprintf("[OK] Using %s from memory", var_name))
      if (is.data.frame(data)) {
        message(sprintf("  Rows: %s", format(nrow(data), big.mark = ",")))
      }
    }
    
    return(data)
  }
  
  # Load from checkpoint
  if (verbose) {
    message(sprintf("%s not found in memory - loading from checkpoint...", var_name))
  }
  
  checkpoint_file <- find_most_recent_file(
    checkpoint_dir,
    checkpoint_pattern,
    error_if_none = TRUE,
    hint = hint
  )
  
  if (verbose) {
    message(sprintf("  Loading: %s", basename(checkpoint_file)))
  }
  
  data <- loader_fn(checkpoint_file)
  
  if (is.null(data)) {
    stop(sprintf("Failed to load checkpoint: %s", checkpoint_file))
  }
  
  if (verbose) {
    if (is.data.frame(data)) {
      message(sprintf("[OK] Loaded checkpoint: %s rows",
                      format(nrow(data), big.mark = ",")))
    } else {
      message("[OK] Loaded checkpoint")
    }
  }
  
  data
}


#' Load Intro-Standardized Data (Workflow 01 Output)
#'
#' @description
#' Loads raw_combined from memory or most recent checkpoint.
#' Workflow-specific wrapper around load_or_checkpoint().
#'
#' @param verbose Logical. Print status messages? Default: TRUE
#'
#' @return Data frame with intro-standardized data.
#'
#' @section CONTRACT:
#' - Returns data from memory or checkpoint
#' - Stops if no data available
#'
#' @export
load_intro_standardized <- function(verbose = TRUE) {
  load_or_checkpoint(
    "raw_combined",
    "outputs",
    "^01_intro_standardized_.*\\.csv$",
    hint = "Run 01_ingest_raw_data.R first",
    verbose = verbose
  )
}


#' Load Master File (Workflow 02 Output)
#'
#' @description
#' Loads kpro_master from memory or most recent checkpoint.
#' Ensures DateTime is POSIXct if loaded from CSV.
#'
#' @param verbose Logical. Print status messages? Default: TRUE
#'
#' @return Data frame with master data.
#'
#' @section CONTRACT:
#' - Returns data from memory or checkpoint
#' - Converts DateTime to POSIXct if loaded from file
#' - Stops if no data available
#'
#' @export
load_master_data <- function(verbose = TRUE) {
  data <- load_or_checkpoint(
    "kpro_master",
    "outputs",
    "^02_kpro_master_.*\\.csv$",
    hint = "Run 02_standardize.R first",
    verbose = verbose
  )
  
  # Ensure DateTime is POSIXct if loaded from CSV
  # CSV files lose POSIXct class, so we need to restore it
  if ("DateTime" %in% names(data) && !inherits(data$DateTime, "POSIXt")) {
    data$DateTime <- lubridate::ymd_hms(data$DateTime)
  }
  
  data
}


#' Load CallsPerNight Final (Workflow 04 Output)
#'
#' @description
#' Loads calls_per_night_final from memory or most recent checkpoint.
#' Ensures Night is Date class and numeric columns are numeric.
#'
#' @param verbose Logical. Print status messages? Default: TRUE
#'
#' @return Data frame with CPN final data.
#'
#' @section CONTRACT:
#' - Returns data from memory or checkpoint
#' - Converts Night to Date if loaded from file
#' - Converts numeric columns (CallsPerNight, RecordingHours, CallsPerHour)
#' - Stops if no data available
#'
#' @export
load_cpn_final <- function(verbose = TRUE) {
  data <- load_or_checkpoint(
    "calls_per_night_final",
    "outputs",
    "^04_CallsPerNight_Final_.*\\.csv$",
    hint = "Run 04_finalize_cpn.R first",
    verbose = verbose
  )
  
  # Ensure Night is Date class if loaded from CSV
  if ("Night" %in% names(data) && !inherits(data$Night, "Date")) {
    data$Night <- as.Date(data$Night)
  }
  
  # Ensure numeric columns are numeric (CSV loads as character)
  numeric_cols <- c("CallsPerNight", "RecordingHours", "CallsPerHour")
  for (col in numeric_cols) {
    if (col %in% names(data) && !is.numeric(data[[col]])) {
      data[[col]] <- as.numeric(data[[col]])
    }
  }
  
  data
}


#' Load CPN Template Original (Workflow 03 Output)
#'
#' @description
#' Loads the original (unedited) CPN template for edit tracking.
#'
#' @param verbose Logical. Print status messages? Default: TRUE
#'
#' @return Data frame with original template.
#'
#' @export
load_cpn_template_original <- function(verbose = TRUE) {
  load_or_checkpoint(
    "template_original",
    "outputs",
    "^03_CallsPerNight_Template_ORIGINAL_.*\\.csv$",
    hint = "Run 03_generate_cpn_template.R first",
    verbose = verbose
  )
}


# ==============================================================================
# PATH GENERATION
# ==============================================================================


#' Generate Timestamped Output Path
#'
#' @description
#' Creates an output file path with workflow prefix and timestamp.
#' Standard naming convention for checkpoint files.
#'
#' @param workflow_num Character. Workflow number (e.g., "02", "04").
#' @param base_name Character. Base name for file (e.g., "kpro_master").
#' @param extension Character. File extension. Default: "csv"
#' @param output_dir Character. Output directory. Default: "outputs"
#'
#' @return Character. Full file path string.
#'
#' @section CONTRACT:
#' - Returns path in format: {output_dir}/{workflow_num}_{base_name}_{timestamp}.{ext}
#' - Timestamp format: YYYYMMDD_HHMMSS
#' - Does not create the file or directory
#'
#' @examples
#' \dontrun{
#' path <- make_output_path("02", "kpro_master")
#' # Returns: "outputs/02_kpro_master_20241229_143022.csv"
#' }
#'
#' @export
make_output_path <- function(workflow_num,
                             base_name,
                             extension = "csv",
                             output_dir = "outputs") {
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  filename <- sprintf("%s_%s_%s.%s", workflow_num, base_name, timestamp, extension)
  
  file.path(output_dir, filename)
}


#' Generate Versioned Output Path (Auto-Increment)
#'
#' @description
#' Creates output path with auto-incrementing version number.
#' Finds existing versions and increments. Use for files that may
#' be regenerated multiple times (like CallsPerNight_Final).
#'
#' @param workflow_num Character. Workflow number.
#' @param base_name Character. Base name for file.
#' @param extension Character. File extension. Default: "csv"
#' @param output_dir Character. Output directory. Default: "outputs"
#'
#' @return Character. Full file path string with version number.
#'
#' @section CONTRACT:
#' - Scans output_dir for existing versions
#' - Returns path with next version number
#' - Starts at v1 if no existing versions
#' - Does not create the file or directory
#'
#' @examples
#' \dontrun{
#' path <- make_versioned_path("04", "CallsPerNight_Final")
#' # If v1 and v2 exist, returns: "outputs/04_CallsPerNight_Final_v3.csv"
#' }
#'
#' @export
make_versioned_path <- function(workflow_num,
                                base_name,
                                extension = "csv",
                                output_dir = "outputs") {
  
  # Find existing versions
  # Pattern matches: {workflow_num}_{base_name}_v{number}.{extension}
  pattern <- sprintf("^%s_%s_v(\\d+)\\.%s$", workflow_num, base_name, extension)
  existing <- list.files(output_dir, pattern = pattern)
  
  if (length(existing) == 0) {
    next_version <- 1
  } else {
    # Extract version numbers from filenames
    versions <- as.integer(sub(pattern, "\\1", existing))
    next_version <- max(versions) + 1
  }
  
  filename <- sprintf("%s_%s_v%d.%s", workflow_num, base_name, next_version, extension)
  
  file.path(output_dir, filename)
}


# ==============================================================================
# TEMPLATE UTILITIES
# ==============================================================================


#' Fill README from Template
#'
#' @description
#' Fills a README template using study parameters and pipeline metadata.
#' Performs string substitution on template placeholders.
#'
#' @param template_path Character. Path to README template.
#' @param output_path Character. Path for output README.md.
#' @param parameters List. Parameters from load_study_parameters().
#' @param log_path Character. Path to pipeline log file.
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
#' - Does not modify input template
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
    stop(sprintf("Template not found: %s", template_path))
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
  
  # Perform substitutions using %||% for NULL safety
  filled <- template %>%
    stringr::str_replace_all(
      "\\[Study Name\\]",
      parameters$study_parameters$study_name %||% "Unnamed Study"
    ) %>%
    stringr::str_replace_all(
      "\\[Start date\\]",
      parameters$study_parameters$start_date %||% ""
    ) %>%
    stringr::str_replace_all(
      "\\[End date\\]",
      parameters$study_parameters$end_date %||% ""
    ) %>%
    stringr::str_replace_all(
      "\\[Start time\\]",
      parameters$processing_options$recording_start %||% ""
    ) %>%
    stringr::str_replace_all(
      "\\[End time\\]",
      parameters$processing_options$recording_end %||% ""
    ) %>%
    stringr::str_replace_all(
      "\\[List detector IDs\\]",
      paste(names(parameters$study_parameters$detector_mapping), collapse = ", ")
    ) %>%
    stringr::str_replace_all(
      "\\[Auto-filled from pipeline_log.txt\\]",
      processing_date
    )
  
  # Write output
  writeLines(filled, output_path)
  invisible(TRUE)
}


# ==============================================================================
# CONSOLE FORMATTING HELPERS
# ==============================================================================


#' Center Text Within Fixed Width
#'
#' @description
#' Centers text by adding padding on both sides to reach target width.
#' Used internally by console formatting functions for consistent
#' box-drawing layouts.
#'
#' @param text Character. Text to center.
#' @param width Integer. Total width including padding.
#'
#' @return Character. Centered text string with padding.
#'
#' @section CONTRACT:
#' - Returns string of exactly 'width' characters
#' - Centers text with equal padding on both sides
#' - Adds extra space to right if padding is odd
#'
#' @section DOES NOT:
#' - Truncate text if longer than width
#' - Validate width is positive
#' - Add any formatting characters (boxes, colors)
#'
#' @examples
#' \dontrun{
#' center_text("Hello", 20)
#' # Returns: "       Hello        " (7 spaces left, 8 right)
#' }
#'
#' @export
center_text <- function(text, width) {
  pad_total <- width - nchar(text)
  pad_left <- floor(pad_total / 2)
  pad_right <- ceiling(pad_total / 2)
  
  sprintf("%s%s%s", strrep(" ", pad_left), text, strrep(" ", pad_right))
}


#' Print Stage Header Box
#'
#' @description
#' Prints a consistently formatted single-line ASCII box for workflow stages.
#' Uses ASCII box-drawing characters per CODING_STANDARDS v2.3.
#'
#' @param stage_num Character. Stage number (e.g., "7.1", "2.3")
#' @param title Character. Stage title (e.g., "Load Configuration")
#' @param width Integer. Total width of box interior. Default: 65
#'
#' @return Invisible NULL.
#'
#' @section CONTRACT:
#' - Uses single-line ASCII box characters (+-|)
#' - Consistent width across all workflows
#' - Auto-pads title for centering
#'
#' @section DOES NOT:
#' - Write to log file (use log_message separately)
#' - Validate stage number format
#'
#' @examples
#' \dontrun{
#' print_stage_header("7.1", "Load Configuration")
#' print_stage_header("2.3", "Apply Detector Mapping")
#' }
#'
#' @export
print_stage_header <- function(stage_num, title, width = 65) {
  
  # Build stage text
  stage_text <- sprintf("STAGE %s: %s", stage_num, title)
  
  # Center text
  centered <- center_text(stage_text, width)
  
  # Print box
  message(sprintf("\n+%s+", strrep("-", width)))
  message(sprintf("|%s|", centered))
  message(sprintf("+%s+\n", strrep("-", width)))
  
  invisible(NULL)
}


#' Print Workflow Completion Summary
#'
#' @description
#' Prints a formatted double-line ASCII box with workflow completion details.
#' Used at the end of each workflow to summarize outputs.
#'
#' @param workflow Character. Workflow number (e.g., "07", "05")
#' @param title Character. Summary title
#' @param items Named list. Items to display (name = description)
#' @param width Integer. Total width of box interior. Default: 65
#'
#' @return Invisible NULL.
#'
#' @section CONTRACT:
#' - Uses double-line ASCII box characters (+|=)
#' - Displays each item on its own line
#' - Consistent width across all workflows
#'
#' @section DOES NOT:
#' - Write to log file
#' - Validate item content
#'
#' @examples
#' \dontrun{
#' print_workflow_summary(
#'   workflow = "07",
#'   title = "Report Generated",
#'   items = list(
#'     "Report" = "bat_activity_report_20260109.html",
#'     "Duration" = "12.3 seconds"
#'   )
#' )
#' }
#'
#' @export
print_workflow_summary <- function(workflow, title, items, width = 65) {
  
  # Build header text
  header_text <- sprintf("WORKFLOW %s COMPLETE: %s", workflow, title)
  
  # Center text
  centered <- center_text(header_text, width)
  
  # Print header box
  message(sprintf("\n+%s+", strrep("=", width)))
  message(sprintf("||%s||", centered))
  message(sprintf("+%s+", strrep("=", width)))
  
  # Print items
  if (length(items) > 0) {
    message("")
    for (name in names(items)) {
      message(sprintf("  - %s: %s", name, items[[name]]))
    }
  }
  
  invisible(NULL)
}


#' Print Pipeline Complete Summary
#'
#' @description
#' Prints a comprehensive pipeline completion summary with all outputs
#' and next steps guidance. Used only at the end of Workflow 07.
#'
#' @param outputs Named list. Output descriptions by workflow
#' @param next_steps Character vector. Suggested next steps
#' @param report_path Character. Path to final report (for browseURL hint)
#' @param width Integer. Total width of box interior. Default: 65
#'
#' @return Invisible NULL.
#'
#' @section CONTRACT:
#' - Uses double-line ASCII box characters for main header
#' - Lists all pipeline outputs
#' - Provides actionable next steps
#' - Shows browseURL command for report
#'
#' @section DOES NOT:
#' - Validate that outputs exist
#' - Write to log file
#'
#' @examples
#' \dontrun{
#' print_pipeline_complete(
#'   outputs = list(
#'     "Master Data" = "outputs/final/Master_20260109.csv",
#'     "Report" = "results/reports/bat_activity_report_20260109.html"
#'   ),
#'   next_steps = c(
#'     "Review the HTML report",
#'     "Share with collaborators"
#'   ),
#'   report_path = "results/reports/bat_activity_report_20260109.html"
#' )
#' }
#'
#' @export
print_pipeline_complete <- function(outputs, next_steps, report_path, width = 65) {
  
  # Header text
  header_text <- "PIPELINE COMPLETE"
  
  # Center text
  centered <- center_text(header_text, width)
  
  # Print main header
  message(sprintf("\n+%s+", strrep("=", width)))
  message(sprintf("||%s||", centered))
  message(sprintf("+%s+", strrep("=", width)))
  
  # Print outputs section
  message("\n[*] PIPELINE OUTPUTS")
  message(strrep("-", 40))
  for (name in names(outputs)) {
    message(sprintf("  %s:", name))
    message(sprintf("    %s", outputs[[name]]))
  }
  
  # Print next steps section
  message("\n[*] NEXT STEPS")
  message(strrep("-", 40))
  for (i in seq_along(next_steps)) {
    message(sprintf("  %d. %s", i, next_steps[i]))
  }
  
  # Print browseURL hint
  if (!is.null(report_path) && nchar(report_path) > 0) {
    message("\n[*] VIEW REPORT")
    message(strrep("-", 40))
    message(sprintf("  browseURL('%s')", report_path))
  }
  
  message("")
  
  invisible(NULL)
}


# ==============================================================================
# OPERATORS
# ==============================================================================


#' Null Coalescing Operator
#'
#' @description
#' Returns the left operand if not NULL, otherwise returns the right operand.
#' Common pattern for default values.
#'
#' @param x Left operand (value to check)
#' @param y Right operand (default value)
#'
#' @return x if not NULL, otherwise y
#'
#' @examples
#' \dontrun{
#' value <- NULL
#' result <- value %||% "default"  # Returns "default"
#'
#' value <- "actual"
#' result <- value %||% "default"  # Returns "actual"
#' }
#'
#' @export
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}