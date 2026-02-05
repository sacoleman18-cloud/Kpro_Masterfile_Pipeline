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
#   - store_stage_results()
#
# Orchestrator Convenience Functions:
#   - log_stage_start()
#   - save_checkpoint_and_register()
#   - finalize_stage_validation_report()
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
# 2026-02-05: Added orchestrator convenience functions to reduce code duplication
#             - Added log_stage_start() to consolidate print_stage_header + log_message
#             - Added save_checkpoint_and_register() to consolidate CSV save + artifact registration
#             - Added finalize_stage_validation_report() to consolidate validation HTML generation
#             - Reduces ~100-150 lines of boilerplate per orchestrator file
#             - Updated FUNCTIONS PROVIDED section
# 2026-02-05: Added store_stage_results() orchestrator helper
#             - Consolidates stage output storage in result object
#             - Tracks validation HTML paths across multiple stages
#             - Used by multi-stage orchestrators (run_finalize_to_report)
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


#' Store Stage Results in Orchestrator Result Object
#'
#' @description
#' Consolidates stage outputs into a structured result object used by 
#' multi-stage orchestrator functions. Stores stage-specific outputs under 
#' a stage key and tracks validation HTML paths.
#'
#' @param result List. The result object being built (must have 
#'   `validation_html_paths` field).
#' @param stage_key Character. Unique identifier for the stage 
#'   (e.g., "ingest_standardize", "finalize_cpn").
#' @param stage_outputs List. Stage-specific outputs to store (typically 
#'   includes data, metadata, artifact_id, checkpoint_path).
#' @param validation_html Character. Optional. Path to validation HTML for 
#'   this stage.
#'
#' @return List. Updated result object with stage outputs stored and 
#'   validation_html added to tracking array.
#'
#' @section CONTRACT:
#' - Stores stage_outputs under result[[stage_key]]
#' - Appends validation_html to result$validation_html_paths if provided
#' - Returns modified result object
#' - Does not validate structure of stage_outputs (caller's responsibility)
#'
#' @section DOES NOT:
#' - Create or validate files
#' - Modify global state
#' - Write to log (caller's responsibility)
#' - Validate stage_key uniqueness (caller may overwrite)
#'
#' @examples
#' \dontrun{
#' # Initialize result object
#' result <- list(
#'   validation_html_paths = character()
#' )
#' 
#' # Store stage outputs
#' stage_outputs <- list(
#'   kpro_master = df,
#'   metadata = list(n_rows = nrow(df)),
#'   artifact_id = "kpro_master_20260205"
#' )
#' 
#' result <- store_stage_results(
#'   result,
#'   stage_key = "ingest_standardize",
#'   stage_outputs = stage_outputs,
#'   validation_html = "results/validation/validation_ingest_20260205.html"
#' )
#' 
#' # Access stored outputs
#' master <- result$ingest_standardize$kpro_master
#' all_reports <- result$validation_html_paths
#' }
#'
#' @export
store_stage_results <- function(result, 
                                stage_key, 
                                stage_outputs, 
                                validation_html = NULL) {
  
  # Store stage outputs under stage key
  result[[stage_key]] <- stage_outputs
  
  # Track validation HTML if provided
  if (!is.null(validation_html) && nchar(validation_html) > 0) {
    result$validation_html_paths <- c(result$validation_html_paths, validation_html)
  }
  
  result
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


# ==============================================================================
# ORCHESTRATOR CONVENIENCE FUNCTIONS
# ==============================================================================


#' Log Stage Start with Console and File Output
#'
#' @description
#' Consolidates the common pattern of printing a stage header to console
#' and logging a stage message to file. Reduces boilerplate in orchestrator
#' functions by combining print_stage_header() + log_message() into one call.
#'
#' @param stage_num Character. Stage number (e.g., "1", "2.3", "7.1")
#' @param title Character. Stage title (e.g., "Load Configuration")
#' @param verbose Logical. Print to console? Default: FALSE
#' @param log_path Character. Path to log file. Default: "logs/pipeline_log.txt"
#' @param workflow_prefix Character. Optional prefix for log messages
#'   (e.g., "Finalize CPN"). Default: ""
#'
#' @return Invisible NULL.
#'
#' @section CONTRACT:
#' - Prints stage header box to console if verbose = TRUE
#' - Always logs to file (respects CODING_STANDARDS gating pattern)
#' - Formats log message as "[Stage X] Title" or "[Prefix - Stage X] Title"
#' - Returns invisibly
#'
#' @section DOES NOT:
#' - Validate stage number format
#' - Check if log file is writable
#' - Track validation events (use log_validation_event separately)
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' log_stage_start("1", "Load Configuration", verbose = TRUE)
#' # Console: +----STAGE 1: Load Configuration----+
#' # Log:     [2026-02-05 12:34:56] [Stage 1] Load Configuration
#'
#' # With workflow prefix
#' log_stage_start("2", "Generate Template", verbose = FALSE,
#'                workflow_prefix = "Finalize CPN")
#' # Console: (silent)
#' # Log:     [2026-02-05 12:34:56] [Finalize CPN - Stage 2] Generate Template
#' }
#'
#' @export
log_stage_start <- function(stage_num,
                           title,
                           verbose = FALSE,
                           log_path = "logs/pipeline_log.txt",
                           workflow_prefix = "") {
  
  # Print to console if verbose
  if (verbose) {
    print_stage_header(stage_num, title)
  }
  
  # Build log message
  if (nchar(workflow_prefix) > 0) {
    log_msg <- sprintf("[%s - Stage %s] %s", workflow_prefix, stage_num, title)
  } else {
    log_msg <- sprintf("[Stage %s] %s", stage_num, title)
  }
  
  # Always log to file (per CODING_STANDARDS)
  log_message(log_msg, log_path = log_path)
  
  invisible(NULL)
}


#' Save Checkpoint and Register as Artifact
#'
#' @description
#' Consolidates the common pattern of saving a CSV checkpoint and registering
#' it in the artifact registry. Atomically performs write_csv → init_artifact_registry
#' → register_artifact sequence in one call. Reduces ~35 lines of boilerplate
#' per usage.
#'
#' @param data Data frame to save as CSV checkpoint.
#' @param file_path Character. Full path to checkpoint file. If NULL, will be
#'   constructed from checkpoint_name, output_dir, and timestamp. Default: NULL.
#' @param checkpoint_name Character. Base name for checkpoint file (without extension).
#'   Used to construct file_path if file_path is NULL. Default: NULL.
#' @param output_dir Character. Output directory for checkpoint. Used with 
#'   checkpoint_name to construct file_path if file_path is NULL. Default: "outputs/checkpoints".
#' @param artifact_name Character. Unique name for artifact registry. If NULL,
#'   will be generated from checkpoint_name. Default: NULL.
#' @param artifact_type Character. Type of artifact (e.g., "checkpoint", "masterfile").
#' @param workflow Character. Workflow that produced this artifact.
#' @param metadata List. Additional metadata for registry entry. Default: list().
#' @param data_hash Character. Optional data frame hash for reproducibility.
#'   Default: NULL.
#' @param verbose Logical. Print confirmation messages? Default: FALSE.
#' @param registry List. Optional existing registry to use. If NULL, loads/creates
#'   registry automatically. Default: NULL.
#'
#' @return List. Updated artifact registry (invisibly).
#'
#' @section CONTRACT:
#' - Accepts either file_path (explicit) OR checkpoint_name + output_dir (constructed)
#' - Creates output directory if needed
#' - Writes data to CSV using readr::write_csv
#' - Generates artifact_name if not provided
#' - Initializes or loads artifact registry if not provided
#' - Registers artifact with file hash and optional data hash
#' - Prints confirmation if verbose = TRUE
#' - Returns updated registry invisibly
#'
#' @section DOES NOT:
#' - Validate data frame schema
#' - Check if file already exists (overwrites)
#' - Log to pipeline log (use log_message separately if needed)
#' - Handle errors in CSV writing (caller should wrap in tryCatch if needed)
#'
#' @examples
#' \dontrun{
#' # Method 1: Explicit file_path
#' registry <- save_checkpoint_and_register(
#'   data = kpro_master,
#'   file_path = here::here("outputs", "checkpoints", "02_kpro_master_20260205.csv"),
#'   artifact_name = "kpro_master_20260205",
#'   artifact_type = "masterfile",
#'   workflow = "ingest",
#'   metadata = list(n_rows = nrow(kpro_master)),
#'   verbose = TRUE
#' )
#'
#' # Method 2: Constructed from checkpoint_name + output_dir
#' registry <- save_checkpoint_and_register(
#'   data = cpn_final,
#'   checkpoint_name = "CallsPerNight_final",
#'   output_dir = here::here("results", "csv"),
#'   artifact_type = "cpn_final",
#'   workflow = "finalize_cpn",
#'   metadata = list(n_rows = nrow(cpn_final)),
#'   verbose = TRUE
#' )
#' # Automatically generates timestamped filename and artifact_name
#' }
#'
#' @export
save_checkpoint_and_register <- function(data,
                                        file_path = NULL,
                                        checkpoint_name = NULL,
                                        output_dir = "outputs/checkpoints",
                                        artifact_name = NULL,
                                        artifact_type,
                                        workflow,
                                        metadata = list(),
                                        data_hash = NULL,
                                        verbose = FALSE,
                                        registry = NULL) {
  
  # Construct file_path if not provided
  if (is.null(file_path)) {
    if (is.null(checkpoint_name)) {
      stop("Either file_path or checkpoint_name must be provided")
    }
    
    # Generate timestamped filename
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    filename <- sprintf("%s_%s.csv", checkpoint_name, timestamp)
    file_path <- file.path(output_dir, filename)
  }
  
  # Generate artifact_name if not provided
  if (is.null(artifact_name)) {
    if (!is.null(checkpoint_name)) {
      timestamp <- format(Sys.time(), "%Y%m%d")
      artifact_name <- sprintf("%s_%s", checkpoint_name, timestamp)
    } else {
      # Extract from file_path
      artifact_name <- tools::file_path_sans_ext(basename(file_path))
    }
  }
  
  # Ensure output directory exists
  output_dir_actual <- dirname(file_path)
  ensure_dir_exists(output_dir_actual)
  
  # Save CSV file
  readr::write_csv(data, file_path)
  
  # Initialize or use existing registry
  if (is.null(registry)) {
    registry <- init_artifact_registry()
  }
  
  # Register artifact (computes file hash automatically)
  registry <- register_artifact(
    registry = registry,
    artifact_name = artifact_name,
    artifact_type = artifact_type,
    workflow = workflow,
    file_path = file_path,
    metadata = metadata,
    data_hash = data_hash,
    quiet = !verbose
  )
  
  # Print confirmation if verbose
  if (verbose) {
    message(sprintf("  [OK] Saved and registered: %s", basename(file_path)))
  }
  
  invisible(registry)
}


#' Finalize Stage Validation Report
#'
#' @description
#' Consolidates the common pattern of creating validation directory and
#' finalizing validation HTML report. Reduces ~10 lines of boilerplate
#' per orchestrator function.
#'
#' @param validation_context List. Validation context from create_validation_context().
#' @param stage_name Character. Optional stage name for display in report.
#'   Default: NULL (uses workflow from context).
#' @param verbose Logical. Print confirmation message? Default: FALSE.
#' @param output_dir Character. Directory for validation HTML.
#'   Default: "results/validation"
#'
#' @return Character. Path to generated validation HTML file.
#'
#' @section CONTRACT:
#' - Creates output directory if it doesn't exist
#' - Calls finalize_validation_report() or complete_stage_validation()
#' - Returns path to generated HTML file
#' - Prints confirmation if verbose = TRUE
#'
#' @section DOES NOT:
#' - Validate context structure (assumes well-formed)
#' - Open browser to view report
#' - Log to pipeline log (use log_message separately if needed)
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' validation_html_path <- finalize_stage_validation_report(
#'   validation_context,
#'   verbose = TRUE
#' )
#' # Prints: "  [OK] Validation report: validation_cpn_template_20260205.html"
#'
#' # With stage name
#' validation_html_path <- finalize_stage_validation_report(
#'   validation_context,
#'   stage_name = "INGEST & STANDARDIZE",
#'   verbose = TRUE,
#'   output_dir = here::here("results", "validation")
#' )
#' }
#'
#' @export
finalize_stage_validation_report <- function(validation_context,
                                            stage_name = NULL,
                                            verbose = FALSE,
                                            output_dir = "results/validation") {
  
  # Ensure output directory exists
  ensure_dir_exists(output_dir)
  
  # Generate validation HTML report
  # Check if complete_stage_validation exists (newer function)
  if (exists("complete_stage_validation", mode = "function")) {
    validation_html_path <- complete_stage_validation(
      validation_context,
      validation_dir = output_dir,
      stage_name = stage_name,
      verbose = verbose
    )
  } else {
    # Fall back to finalize_validation_report
    validation_html_path <- finalize_validation_report(
      validation_context,
      output_dir = output_dir
    )
  }
  
  # Print confirmation if verbose
  if (verbose && !is.null(validation_html_path)) {
    message(sprintf("  [OK] Validation report: %s", basename(validation_html_path)))
  }
  
  validation_html_path
}