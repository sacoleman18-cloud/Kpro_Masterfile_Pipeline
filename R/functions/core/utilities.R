# =============================================================================
# core/utilities.R - FOUNDATIONAL UTILITIES (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Foundational utilities with ZERO internal dependencies on domain logic.
# Provides safe I/O, checkpoint management, file discovery, path generation,
# and orchestrator helper functions.
#
# NOTE: Logging and console formatting have been split into separate modules:
#   - core/logging.R: log_message(), initialize_pipeline_log()
#   - core/console.R: center_text(), print_stage_header(), 
#                     print_workflow_summary(), print_pipeline_complete()
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
#    - This file imports ONLY external packages (base R, readr, lubridate, here)
#    - MUST NOT source or depend on any other project files
#    - May CALL functions from logging.R and console.R (but doesn't source them)
#
# 2. File I/O
#    - safe_read_csv() ALWAYS returns tibble or NULL (never errors)
#    - All columns read as character by default (preserves original data)
#
# 3. File Discovery
#    - find_most_recent_file() uses filename timestamps, not mtime
#    - Deterministic behavior across file systems
#
# 4. Path Generation
#    - Timestamped paths for audit trail
#    - Versioned paths for incremental saves
#    - Consistent naming conventions
#
# 5. Orchestrator Utilities
#    - setup_pipeline_context() consolidates YAML + validation setup
#    - load_most_recent_checkpoint() replaces legacy checkpoint loaders
#    - generate_timestamped_filename() provides consistent naming
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Perform any data transformations specific to KPro data
#   - Contain domain logic (bat data, schemas, detectors)
#   - Depend on any other project module (only external packages)
#   - Contain console formatting (use console.R)
#   - Contain file logging (use logging.R)
#
# DEPENDENCIES
# ------------
# External only:
#   - readr: read_csv
#   - lubridate: ymd_hms
#   - here: here
#   - dplyr: mutate, across, all_of
#   - base R: file operations
#
# CONTENTS
# --------
# Directory Management:
#   - ensure_dir_exists()
#
# Safe I/O:
#   - safe_read_csv()
#   - convert_empty_to_na()
#
# File Discovery:
#   - find_most_recent_file()
#
# Orchestrator Utilities:
#   - setup_pipeline_context()
#   - load_most_recent_checkpoint()
#   - generate_timestamped_filename()
#
# Path Generation:
#   - make_output_path()
#   - make_versioned_path()
#
# Template Utilities:
#   - fill_readme_template()
#
# Operators:
#   - %||%
#
# REMOVED (moved to other modules):
#   - log_message() -> logging.R
#   - initialize_pipeline_log() -> logging.R
#   - center_text() -> console.R
#   - print_stage_header() -> console.R
#   - print_stage_banner() -> console.R (deprecated - use print_workflow_summary)
#   - print_workflow_summary() -> console.R
#   - print_pipeline_complete() -> console.R
#   - create_unified_species_column() -> standardization.R
#
# LEGACY FUNCTIONS REMOVED (replaced by orchestrator utilities):
#   - load_or_checkpoint() -> use load_most_recent_checkpoint()
#   - load_intro_standardized() -> use load_most_recent_checkpoint("01_intro_.*")
#   - load_master_data() -> use load_most_recent_checkpoint("02_kpro_master_.*")
#   - load_cpn_final() -> use load_most_recent_checkpoint("04_CallsPerNight_Final_.*")
#   - load_cpn_template_original() -> use load_cpn_template() in callspernight.R
#
# CHANGELOG
# ---------
# 2026-02-04: MODULE SPLIT - Reduced file size for LLM compatibility
#             - Moved logging functions to core/logging.R (2 functions)
#             - Moved console formatting to core/console.R (4 functions)
#             - Moved create_unified_species_column() to standardization/standardization.R
#             - Added load_cpn_template() to analysis/callspernight.R
#             - Removed legacy checkpoint loaders (use load_most_recent_checkpoint instead)
#             - Updated header documentation
# 2026-02-03: Added orchestrator helper functions to reduce redundancy
# 2026-02-01: Changed find_most_recent_file() to read off of timestamp
# 2026-01-31: Refactored for standards compliance
# 2024-12-29: Initial CODING_STANDARDS compliant version
#
# =============================================================================


# ==============================================================================
# OPERATORS
# ==============================================================================

#' Null Coalescing Operator
#'
#' @description
#' Returns left operand if not NULL, otherwise returns right operand.
#' Useful for providing default values.
#'
#' @param x First value to test.
#' @param y Default value if x is NULL.
#'
#' @return x if not NULL, otherwise y.
#'
#' @section CONTRACT:
#' - Returns first non-NULL value
#' - Evaluates y only if x is NULL
#'
#' @section DOES NOT:
#' - Test for NA (only NULL)
#' - Test for empty strings
#'
#' @examples
#' \dontrun{
#' value <- NULL %||% "default"  # Returns "default"
#' value <- "actual" %||% "default"  # Returns "actual"
#' }
#'
#' @export
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}


# ==============================================================================
# DIRECTORY MANAGEMENT
# ==============================================================================


#' Ensure Directory Exists
#'
#' @description
#' Creates directory if it doesn't exist. Safe for repeated calls.
#' Used internally by I/O functions to guarantee output directories are available.
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
#' - Check write permissions
#' - Delete existing contents
#' - Validate path format
#'
#' @examples
#' \dontrun{
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
#' - Guess column types
#' - Modify data values
#' - Enforce schema requirements
#'
#' @examples
#' \dontrun{
#' df <- safe_read_csv("data/raw/detector_001.csv", verbose = TRUE)
#' if (is.null(df)) {
#'   warning("Failed to load file")
#' }
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
#' - Replaces "" with NA
#' - Trims whitespace before checking
#' - Preserves non-empty strings
#'
#' @section DOES NOT:
#' - Modify columns not in 'columns' parameter
#' - Remove rows
#' - Change data types
#'
#' @examples
#' \dontrun{
#' df <- convert_empty_to_na(df, c("auto_id", "manual_id"))
#' }
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
    stop(sprintf("Columns not found: %s", paste(missing_cols, collapse = ", ")))
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


#' Find Most Recent File Matching Pattern (by Filename Timestamp)
#'
#' @description
#' Searches a directory for files matching a regex pattern and returns the
#' file with the most recent timestamp embedded in its filename.
#'
#' @param directory Character. Directory to search (not recursive).
#' @param pattern Character. Regex pattern to match filenames.
#' @param error_if_none Logical. Stop with error if no files found? Default: TRUE
#' @param hint Character or NULL. Hint message if no files found. Default: NULL
#'
#' @return Character. Full path to most recent file, or NULL if none found
#'   and error_if_none = FALSE.
#'
#' @section Timestamp Extraction:
#' Expects filenames with YYYYMMDD_HHMMSS timestamp near the end:
#' - 02_kpro_master_20260201_180259.csv
#' - 03_CallsPerNight_Template_20260201_180259_ORIGINAL.csv
#'
#' @section CONTRACT:
#' - Uses filename timestamps (not file modification time)
#' - Deterministic across file systems
#' - Returns full path with here::here()
#' - Stops with actionable error if no files found and error_if_none = TRUE
#'
#' @section DOES NOT:
#' - Use file modification times (unreliable across systems)
#' - Create files
#' - Modify directory contents
#'
#' @examples
#' \dontrun{
#' latest <- find_most_recent_file(
#'   directory = "outputs/checkpoints",
#'   pattern = "^02_kpro_master_.*\\.csv$",
#'   hint = "Run Chunk 1 first"
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
      hint_msg <- if (!is.null(hint)) sprintf("\n  Hint: %s", hint) else ""
      stop(sprintf("No files matching '%s' found in %s%s", pattern, directory, hint_msg))
    } else {
      return(NULL)
    }
  }
  
  # Extract timestamps from filenames
  basenames <- basename(matching_files)
  timestamps <- sub(".*_(\\d{8}_\\d{6})(?:_.*?)?\\.\\w+$", "\\1", basenames)
  
  # Convert to POSIXct for proper datetime sorting
  timestamps_dt <- lubridate::ymd_hms(timestamps, quiet = TRUE)
  
  # Filter out files where timestamp parsing failed
  valid_idx <- !is.na(timestamps_dt)
  
  if (!any(valid_idx)) {
    if (error_if_none) {
      stop(sprintf(
        "No files with valid timestamps found matching '%s' in %s\n  Expected format: ..._YYYYMMDD_HHMMSS.ext",
        pattern, directory
      ))
    } else {
      return(NULL)
    }
  }
  
  # Keep only valid timestamped files
  matching_files <- matching_files[valid_idx]
  timestamps_dt <- timestamps_dt[valid_idx]
  
  # Sort by actual datetime (descending - most recent first)
  sorted_idx <- order(timestamps_dt, decreasing = TRUE)
  most_recent <- matching_files[sorted_idx[1]]
  
  most_recent
}


# ==============================================================================
# ORCHESTRATOR UTILITIES
# ==============================================================================


#' Setup Pipeline Context
#'
#' @description
#' Consolidates the standard initialization pattern used by all orchestrating
#' functions: load YAML config, create validation context, set up paths.
#'
#' @param workflow_name Character. Workflow identifier (e.g., "ingest")
#'
#' @return Named list with yaml_path, study_params, validation_context,
#'   checkpoint_dir, outputs_dir.
#'
#' @section CONTRACT:
#' - Loads study_parameters.yaml from inst/config/
#' - Creates validation context with workflow name
#' - Returns standard paths (checkpoints, outputs)
#' - Stops with actionable error if YAML not found
#'
#' @section DOES NOT:
#' - Create directories
#' - Validate YAML structure (config.R handles this)
#' - Write to log file (caller's responsibility)
#'
#' @examples
#' \dontrun{
#' ctx <- setup_pipeline_context("ingest")
#' study_name <- ctx$study_params$study_parameters$study_name
#' }
#'
#' @export
setup_pipeline_context <- function(workflow_name) {
  
  # Standard paths - FIXED by project structure
  yaml_path <- here::here("inst", "config", "study_parameters.yaml")
  checkpoint_dir <- here::here("outputs", "checkpoints")
  outputs_dir <- here::here("outputs")
  
  # Assert YAML exists
  if (!file.exists(yaml_path)) {
    stop(sprintf(
      "Configuration file not found: %s\n  Configure study parameters in Shiny app first.",
      yaml_path
    ))
  }
  
  # Load configuration (requires load_study_parameters from config.R)
  study_params <- load_study_parameters(yaml_path)
  
  # Create validation context (requires create_validation_context from validation.R)
  validation_context <- create_validation_context(workflow = workflow_name)
  validation_context$study_name <- study_params$study_parameters$study_name
  
  list(
    yaml_path = yaml_path,
    study_params = study_params,
    validation_context = validation_context,
    checkpoint_dir = checkpoint_dir,
    outputs_dir = outputs_dir
  )
}


#' Load Most Recent Checkpoint
#'
#' @description
#' Discovers and loads the most recent checkpoint file matching a pattern.
#' Replaces legacy checkpoint loaders with a generic pattern-based approach.
#'
#' @param pattern Character. Regex pattern for filename matching.
#'
#' @return Tibble loaded from most recent checkpoint file.
#'
#' @section CONTRACT:
#' - Searches outputs/checkpoints/ directory
#' - Uses filename timestamps for "most recent" determination
#' - Returns tibble with all columns as character
#' - Stops with actionable error if no files found
#'
#' @section DOES NOT:
#' - Convert column types (caller's responsibility)
#' - Validate data structure
#' - Create directories
#'
#' @examples
#' \dontrun{
#' # Load most recent kpro_master
#' kpro_master <- load_most_recent_checkpoint("^02_kpro_master_.*\\.csv$")
#'
#' # Load most recent CPN final
#' cpn_final <- load_most_recent_checkpoint("^04_CallsPerNight_Final_.*\\.csv$")
#' }
#'
#' @export
load_most_recent_checkpoint <- function(pattern) {
  
  checkpoint_dir <- here::here("outputs", "checkpoints")
  
  if (!dir.exists(checkpoint_dir)) {
    stop(sprintf("Checkpoint directory not found: %s\n  Run previous chunk first.", checkpoint_dir))
  }
  
  files <- list.files(checkpoint_dir, pattern = pattern, full.names = TRUE)
  
  if (length(files) == 0) {
    stop(sprintf(
      "No checkpoint files found matching pattern: %s\n  Directory: %s\n  Run previous chunk first.",
      pattern, checkpoint_dir
    ))
  }
  
  # Get most recent (last in sorted list)
  most_recent <- files[length(files)]
  
  safe_read_csv(most_recent)
}


#' Generate Timestamped Filename
#'
#' @description
#' Generates a filename with embedded timestamp in YYYYMMDD_HHMMSS format.
#' Used by orchestrating functions for consistent checkpoint naming.
#'
#' @param prefix Character. Filename prefix (e.g., "02_kpro_master")
#' @param suffix Character. Optional suffix before extension. Default: ""
#'
#' @return Character. Formatted filename string with .csv extension.
#'
#' @section CONTRACT:
#' - Timestamp format: YYYYMMDD_HHMMSS
#' - Pattern: {prefix}_{timestamp}_{suffix}.csv
#' - Returns filename only (not full path)
#'
#' @section DOES NOT:
#' - Create the file
#' - Include directory path
#' - Validate prefix format
#'
#' @examples
#' \dontrun{
#' filename <- generate_timestamped_filename("02_kpro_master")
#' # Returns: "02_kpro_master_20260204_143022.csv"
#'
#' filename <- generate_timestamped_filename("03_CallsPerNight_Template", "ORIGINAL")
#' # Returns: "03_CallsPerNight_Template_20260204_143022_ORIGINAL.csv"
#' }
#'
#' @export
generate_timestamped_filename <- function(prefix, suffix = "") {
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  parts <- c(prefix, timestamp)
  
  if (!is.null(suffix) && nchar(suffix) > 0) {
    parts <- c(parts, suffix)
  }
  
  base_name <- paste(parts, collapse = "_")
  paste0(base_name, ".csv")
}


# ==============================================================================
# PATH GENERATION
# ==============================================================================


#' Generate Timestamped Output Path
#'
#' @description
#' Creates an output file path with workflow prefix and timestamp.
#'
#' @param workflow_num Character. Workflow number (e.g., "02", "04").
#' @param base_name Character. Base name for file.
#' @param extension Character. File extension. Default: "csv"
#' @param output_dir Character. Output directory. Default: "outputs"
#'
#' @return Character. Full file path string.
#'
#' @section CONTRACT:
#' - Includes workflow number prefix
#' - Adds timestamp (YYYYMMDD_HHMMSS)
#' - Returns full path (does not create file or directory)
#'
#' @section DOES NOT:
#' - Create the file or directory
#' - Check if file exists
#' - Version the file
#'
#' @examples
#' \dontrun{
#' path <- make_output_path("01", "intro_standardized")
#' # Returns: "outputs/01_intro_standardized_20260204_141530.csv"
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
#' - Increments to next available version number
#' - Returns path only (does not create file)
#'
#' @section DOES NOT:
#' - Create directories
#' - Validate existing files
#' - Check if returned path exists
#'
#' @examples
#' \dontrun{
#' path <- make_versioned_path("04", "CallsPerNight_final", "csv", "results/csv")
#' # Returns: "results/csv/04_CallsPerNight_final_v1.csv"
#' # Next call returns v2, then v3, etc.
#' }
#'
#' @export
make_versioned_path <- function(workflow_num,
                                base_name,
                                extension = "csv",
                                output_dir = "outputs") {
  
  pattern <- sprintf("^%s_%s_v(\\d+)\\.%s$", workflow_num, base_name, extension)
  existing <- list.files(output_dir, pattern = pattern)
  
  if (length(existing) == 0) {
    next_version <- 1
  } else {
    versions <- as.integer(sub(pattern, "\\1", existing))
    next_version <- max(versions) + 1
  }
  
  filename <- sprintf("%s_%s_v%d.%s", workflow_num, base_name, next_version, extension)
  
  file.path(output_dir, filename)
}


# ==============================================================================
# TEMPLATE UTILITIES
# ==============================================================================


#' Fill README Template
#'
#' @description
#' Populates a README template with study parameters and pipeline metadata.
#' Used in release bundle generation.
#'
#' @param template_path Character. Path to README template file.
#' @param output_path Character. Path for output README.md.
#' @param parameters List. Study parameters from load_study_parameters().
#' @param log_path Character. Path to pipeline log file.
#'
#' @return Invisible TRUE.
#'
#' @section CONTRACT:
#' - Replaces {{PLACEHOLDER}} strings in template
#' - Creates output directory if needed
#' - Writes filled template to output_path
#'
#' @section DOES NOT:
#' - Validate template format
#' - Check parameter completeness
#' - Append to existing file
#'
#' @examples
#' \dontrun{
#' fill_readme_template(
#'   template_path = "templates/README_template.md",
#'   output_path = "results/releases/README.md",
#'   parameters = study_params,
#'   log_path = "logs/pipeline_log.txt"
#' )
#' }
#'
#' @export
fill_readme_template <- function(template_path,
                                 output_path,
                                 parameters,
                                 log_path) {
  
  # Read template
  template_text <- readLines(template_path)
  
  # Replace placeholders
  filled_text <- template_text
  filled_text <- gsub("{{STUDY_NAME}}", parameters$study_parameters$study_name, filled_text)
  filled_text <- gsub("{{TIMEZONE}}", parameters$study_parameters$timezone, filled_text)
  filled_text <- gsub("{{CUTOFF_HOUR}}", parameters$study_parameters$cutoff_hour, filled_text)
  
  # Ensure output directory exists
  ensure_dir_exists(dirname(output_path))
  
  # Write filled template
  writeLines(filled_text, output_path)
  
  invisible(TRUE)
}