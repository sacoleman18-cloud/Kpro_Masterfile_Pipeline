# =============================================================================
# UTILITY: utilities.R - Foundational Utilities (LOCKED CONTRACT)
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# - Zero dependencies on other project modules
# - Sourced first by load_all.R
# PURPOSE
# -------
# Foundational utilities with ZERO internal dependencies on domain logic.
# Provides safe I/O, file discovery, path generation, and template utilities.
#
# NOTE: Related modules have been split out for focused concerns:
#   - core/logging.R: log_message(), initialize_pipeline_log()
#   - core/console.R: center_text(), print_stage_header(), 
#                     print_workflow_summary(), print_pipeline_complete()
#   - core/orchestration_helpers.R: setup_pipeline_context(), log_stage_start(),
#                                   save_checkpoint_and_register(), etc.
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
# FUNCTIONS PROVIDED
# ------------------
#
# Operators - Null handling:
#
#   - %||%:
#       Uses packages: base R (is.null)
#       Calls internal: none
#       Purpose: Null coalescing operator (returns left if not NULL, else right)
#
# Directory Management - Safe filesystem operations:
#
#   - ensure_dir_exists():
#       Uses packages: base R (dir.exists, dir.create)
#       Calls internal: none
#       Purpose: Create directory if missing (recursive, safe to repeat)
#
# Safe I/O - Non-stopping file operations:
#
#   - safe_read_csv():
#       Uses packages: readr (read_csv), base R (file operations)
#       Calls internal: none (pure I/O)
#       Purpose: Read CSV with error logging (returns NULL, never stops)
#
#   - convert_empty_to_na():
#       Uses packages: dplyr (mutate, if_all), base R (is.na)
#       Calls internal: none
#       Purpose: Convert empty strings/spaces to NA values
#
# File Discovery - Timestamp-based file location:
#
#   - find_most_recent_file():
#       Uses packages: base R (list.files, grepl, sort)
#       Calls internal: none
#       Purpose: Find newest file matching pattern (deterministic by timestamp)
#
# Path Generation - Timestamped and versioned paths:
#
#   - make_output_path():
#       Uses packages: here (here), base R (file.path)
#       Calls internal: none (pure path construction)
#       Purpose: Generate timestamped output path for audit trail
#
#   - make_versioned_path():
#       Uses packages: base R (file.path, list.files, grep)
#       Calls internal: none
#       Purpose: Generate version-incremented path (v1, v2, v3...)
#
# Template Utilities - File template processing:
#
#   - fill_readme_template():
#       Uses packages: base R (readLines, writeLines, gsub)
#       Calls internal: none
#       Purpose: Replace placeholders in README template files
#
# Module-Specific Helpers - Domain utilities:
#
#   - save_summary_csv():
#       Uses packages: readr (write_csv), base R (file.path)
#       Calls internal: none (pure I/O)
#       Purpose: Save summary table as CSV with timestamped filename
#
#   - build_excel_from_csv():
#       Uses packages: readxl, writexl, dplyr (read operations)
#       Calls internal: none
#       Purpose: Convert CSV to Excel workbook format
#
#   - verify_rds_artifacts():
#       Uses packages: base R (file.exists, readRDS)
#       Calls internal: none
#       Purpose: Verify RDS artifact files exist and are readable
#
#   - render_report():
#       Uses packages: rmarkdown (render), base R (file operations)
#       Calls internal: none
#       Purpose: Render R Markdown reports to HTML/PDF
#
#   - create_and_register_release():
#       Uses packages: zip (zip), yaml (write_yaml)
#       Calls internal: none (calls artifacts.R functions if present)
#       Purpose: Create release bundle and register with artifact system
#
# REMOVED (moved to other modules):
#   Logging functions -> logging.R:
#     - log_message()
#     - initialize_pipeline_log()
#   
#   Console formatting -> console.R:
#     - center_text()
#     - print_stage_header()
#     - print_stage_banner() (deprecated - use print_workflow_summary)
#     - print_workflow_summary()
#     - print_pipeline_complete()
#   
#   Orchestrator helpers -> orchestration_helpers.R:
#     - setup_pipeline_context()
#     - load_most_recent_checkpoint()
#     - generate_timestamped_filename()
#     - store_stage_results()
#     - log_stage_start()
#     - save_checkpoint_and_register()
#     - finalize_stage_validation_report()
#   
#   Domain-specific processing -> standardization.R:
#     - create_unified_species_column()
#
# LEGACY FUNCTIONS REMOVED (replaced by orchestrator utilities):
#   - load_or_checkpoint() -> use load_most_recent_checkpoint()
#   - load_intro_standardized() -> use load_most_recent_checkpoint("01_intro_.*")
#   - load_master_data() -> use load_most_recent_checkpoint("02_kpro_master_.*")
#   - load_cpn_final() -> use load_most_recent_checkpoint("04_CallsPerNight_Final_.*")
#   - load_cpn_template_original() -> use load_cpn_template() in callspernight.R
#
# Last Modified: 2026-02-09
#
# CHANGELOG
# ---------
# 2026-02-09: Extracted orchestrator helpers to orchestration_helpers.R
#             (7 functions, ~680 lines) to separate orchestrator-specific
#             convenience functions from general utilities
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
# MODULE-SPECIFIC HELPER FUNCTIONS (Added for Module Refactoring)
# ==============================================================================

#' Log the start of a stage
#'
#' @description
#' Consolidates stage lifecycle logging by combining print_stage_header() + log_message()
#' into one call. Reduces boilerplate when starting each orchestrator workflow stage.
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
  
  # Format DateTime_local column for CSV export if present
  # This converts POSIXct to character in MM/DD/YYYY HH:MM:SS format
  # to prevent ISO 8601 format and preserve timezone through CSV round-trip
  data_to_save <- data
  if ("DateTime_local" %in% names(data_to_save)) {
    if (inherits(data_to_save$DateTime_local, "POSIXct")) {
      # Store the timezone for metadata
      dt_tz <- attr(data_to_save$DateTime_local, "tzone")
      if (is.null(dt_tz) || dt_tz == "") {
        dt_tz <- "UTC"  # Default if no timezone set
      }
      
      # Format for CSV export
      data_to_save$DateTime_local <- format_datetime_for_csv(data_to_save$DateTime_local)
      
      # Add timezone to metadata for reconstruction
      if (is.null(metadata$datetime_timezone)) {
        metadata$datetime_timezone <- dt_tz
      }
    }
  }
  
  # Save CSV file
  readr::write_csv(data_to_save, file_path)
  
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


# ==============================================================================
# NEW HELPER FUNCTIONS (Added for Module Refactoring - Stage 13-25)
# ==============================================================================


#' Save Summary CSV with Artifact Registration
#'
#' @description
#' Saves a summary tibble/dataframe as CSV and registers it as an artifact.
#' Used by summary_stats module for consistent CSV export.
#'
#' @param data Tibble or data.frame. Summary data to export.
#' @param filename Character. Filename (e.g., "detector_summary_20260205.csv").
#' @param output_dir Character. Output directory path. Default: "results/csv/summary_stats".
#' @param registry List. Artifact registry from save_checkpoint_and_register().
#' @param artifact_name Character. Name for artifact registry entry.
#' @param metadata List. Additional metadata for artifact registration.
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return List with registry attribute containing file path reference.
#'
#' @section CONTRACT:
#' - Ensures output directory exists
#' - Saves data as CSV using readr::write_csv
#' - Registers artifact with SHA256 hash
#' - Adds file_path attribute for downstream use
#' - Returns registry with updated artifact entries
#'
#' @keywords internal
#' @export
save_summary_csv <- function(data, filename, output_dir = "results/csv/summary_stats",
                             registry = NULL, artifact_name = NULL, metadata = NULL,
                             verbose = FALSE) {
  
  # Ensure directory exists
  ensure_dir_exists(output_dir)
  
  # Build full file path
  file_path <- file.path(output_dir, filename)
  
  # Save CSV
  readr::write_csv(data, file_path)
  
  if (verbose) {
    message(sprintf("  [OK] Saved CSV: %s", basename(file_path)))
  }
  
  # Register artifact if registry provided
  if (!is.null(registry) && !is.null(artifact_name)) {
    registry <- save_and_register_rds(
      object = NULL,  # Dummy - we're just registering the file
      file_path = file_path,
      artifact_type = "summary_stats",
      artifact_name = artifact_name,
      registry = registry,
      metadata = metadata,
      verbose = FALSE
    )
  }
  
  # Add path attribute for easy reference
  structure(registry, file_path = file_path)
}


#' Build Excel Workbook from CSV Files
#'
#' @description
#' Compiles multiple CSV files into a single Excel workbook with one
#' sheet per CSV. Ensures consistency between CSV and Excel formats.
#'
#' @param csv_files Named character vector. Names are sheet names, values are file paths.
#'   Example: c("Detector Summary" = "path/to/detector.csv", ...)
#' @param output_file Character. Path to output XLSX file.
#' @param registry List. Artifact registry for registration.
#' @param artifact_name Character. Name for artifact entry.
#' @param workflow Character. Workflow name for metadata. Default: "summary_stats".
#' @param metadata List. Additional metadata for artifact registration.
#' @param verbose Logical. Print progress. Default: FALSE.
#'
#' @return List with registry attribute.
#'
#' @section CONTRACT:
#' - Requires openxlsx package (returns TRUE if unavailable)
#' - Creates output directory if needed
#' - Reads CSVs and creates sheets in workbook
#' - Registers completed Excel file as artifact
#' - Returns updated registry with file_path attribute
#'
#' @keywords internal
#' @export
build_excel_from_csv <- function(csv_files, output_file, registry = NULL,
                                 artifact_name = NULL, workflow = "summary_stats",
                                 metadata = NULL, verbose = FALSE) {
  
  # Check if openxlsx is available
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    if (verbose) message("  [SKIP] openxlsx not installed - Excel export skipped")
    return(structure(registry, file_path = NA_character_))
  }
  
  # Ensure output directory exists
  ensure_dir_exists(dirname(output_file))
  
  # Create new workbook
  wb <- openxlsx::createWorkbook()
  
  # Add each CSV as a sheet
  for (sheet_name in names(csv_files)) {
    csv_path <- csv_files[[sheet_name]]
    
    if (!file.exists(csv_path)) {
      warning(sprintf("CSV file not found: %s", csv_path))
      next
    }
    
    # Read CSV
    df <- readr::read_csv(csv_path, show_col_types = FALSE)
    
    # Add sheet to workbook
    openxlsx::addWorksheet(wb, sheet_name)
    openxlsx::writeData(wb, sheet = sheet_name, df)
  }
  
  # Save workbook
  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
  
  if (verbose) {
    message(sprintf("  [OK] Compiled Excel: %s (%d sheets)",
                    basename(output_file), length(csv_files)))
  }
  
  # Register artifact
  if (!is.null(registry) && !is.null(artifact_name)) {
    registry <- save_and_register_rds(
      object = NULL,
      file_path = output_file,
      artifact_type = "xlsx",
      artifact_name = artifact_name,
      workflow = workflow,
      registry = registry,
      metadata = metadata,
      verbose = FALSE
    )
  }
  
  structure(registry, file_path = output_file)
}


#' Verify RDS Artifact Structure
#'
#' @description
#' Loads and validates RDS files for report compatibility. Checks that
#' required elements exist and are properly structured.
#'
#' @param summary_rds Character. Path to RDS file with summaries.
#' @param plots_rds Character. Path to RDS file with plots.
#' @param verbose Logical. Print progress. Default: FALSE.
#'
#' @return List with elements:
#'   - valid: Logical, TRUE if structure is valid
#'   - errors: Character vector of validation errors (if any)
#'   - total_plots: Numeric count of all plots found
#'
#' @section CONTRACT:
#' - Loads files via readRDS and checks key elements
#' - Returns list with valid status and error details
#' - Does not stop on errors (allows pipeline to continue with warnings)
#'
#' @keywords internal
#' @export
verify_rds_artifacts <- function(summary_rds, plots_rds, verbose = FALSE) {
  
  errors <- character()
  total_plots <- 0
  
  # Check summary RDS
  if (!file.exists(summary_rds)) {
    errors <- c(errors, sprintf("Summary RDS not found: %s", summary_rds))
  } else {
    all_summaries <- tryCatch({
      readRDS(summary_rds)
    }, error = function(e) {
      errors <<- c(errors, sprintf("Cannot load summary RDS: %s", e$message))
      NULL
    })
    
    if (!is.null(all_summaries)) {
      # Check for expected elements
      expected_elements <- c("detector_summary", "study_summary")
      missing <- setdiff(expected_elements, names(all_summaries))
      if (length(missing) > 0) {
        errors <- c(errors, sprintf("Summary missing elements: %s", paste(missing, collapse = ", ")))
      }
    }
  }
  
  # Check plots RDS
  if (!file.exists(plots_rds)) {
    errors <- c(errors, sprintf("Plots RDS not found: %s", plots_rds))
  } else {
    all_plots <- tryCatch({
      readRDS(plots_rds)
    }, error = function(e) {
      errors <<- c(errors, sprintf("Cannot load plots RDS: %s", e$message))
      NULL
    })
    
    if (!is.null(all_plots)) {
      # Count total plots
      total_plots <- sum(sapply(all_plots, function(x) {
        if (is.list(x)) length(x) else 0
      }, USE.NAMES = FALSE))
    }
  }
  
  list(
    valid = length(errors) == 0,
    errors = errors,
    total_plots = total_plots
  )
}


#' Render Quarto Report with Error Handling
#'
#' @description
#' Wrapper for quarto::quarto_render with standardized error handling,
#' parameter passing, and path management.
#'
#' @param qmd_template Character. Path to .qmd Quarto template.
#' @param output_file Character. Output HTML filename.
#' @param output_dir Character. Output directory. Default: "results/reports".
#' @param params List. Execute parameters to pass to Quarto.
#' @param verbose Logical. Print progress. Default: FALSE.
#'
#' @return List with elements:
#'   - success: Logical, TRUE if rendering succeeded
#'   - output_path: Character, path to rendered HTML (or NA if failed)
#'   - message: Character, status message
#'
#' @section CONTRACT:
#' - Ensures template exists before rendering
#' - Ensures output directory exists
#' - Passes execute_params to quarto::quarto_render
#' - Handles file relocation if quarto renders to different location
#' - Returns structured result with success status
#'
#' @keywords internal
#' @export
render_report <- function(qmd_template, output_file, output_dir = "results/reports",
                          params = NULL, verbose = FALSE) {
  
  # Check template exists
  if (!file.exists(qmd_template)) {
    return(list(
      success = FALSE,
      output_path = NA_character_,
      message = sprintf("Quarto template not found: %s", qmd_template)
    ))
  }
  
  # Ensure output directory exists
  ensure_dir_exists(output_dir)
  
  # Full output path
  output_path <- file.path(output_dir, output_file)
  
  # Render report
  result <- tryCatch({
    quarto::quarto_render(
      input = qmd_template,
      output_file = basename(output_path),
      output_format = "html",
      execute_params = params,
      quiet = !verbose
    )
    
    # Check if quarto rendered to template directory
    template_rendered <- file.path(dirname(qmd_template), basename(output_path))
    if (file.exists(template_rendered) && template_rendered != output_path) {
      file.rename(template_rendered, output_path)
    }
    
    list(
      success = TRUE,
      output_path = output_path,
      message = "Report rendered successfully"
    )
  }, error = function(e) {
    list(
      success = FALSE,
      output_path = NA_character_,
      message = e$message
    )
  })
  
  if (verbose && result$success) {
    message(sprintf("  [OK] Report rendered: %s", if(!is.null(result$output_path) && !is.na(result$output_path) && is.character(result$output_path)) basename(result$output_path) else "report.html"))
  }
  
  result
}


#' Create and Register Release Bundle
#'
#' @description
#' Wrapper for create_release_bundle with standardized artifact registration.
#'
#' @param study_id Character. Study identifier.
#' @param calls_per_night_final Tibble. Final CPN data.
#' @param kpro_master Tibble. Master dataset.
#' @param all_summaries List. Summary statistics.
#' @param all_plots List. Plot objects.
#' @param report_path Character. Path to HTML report.
#' @param study_params List. Study parameters.
#' @param output_dir Character. Output directory for bundle.
#' @param registry List. Artifact registry.
#' @param quiet Logical. Suppress quarto messages. Default: TRUE.
#'
#' @return List with elements:
#'   - success: Logical
#'   - zip_path: Character, path to bundle ZIP
#'   - message: Character, status message
#'
#' @section CONTRACT:
#' - Ensures output directory exists
#' - Calls create_release_bundle function from release.R
#' - Registers ZIP file as artifact
#' - Returns structured result with success status
#'
#' @keywords internal
#' @export
create_and_register_release <- function(study_id, calls_per_night_final, kpro_master,
                                        all_summaries, all_plots, report_path,
                                        study_params, output_dir = "results/releases",
                                        registry = NULL, quiet = TRUE) {
  
  ensure_dir_exists(output_dir)
  
  result <- tryCatch({
    zip_path <- create_release_bundle(
      study_id = study_id,
      calls_per_night_final = calls_per_night_final,
      kpro_master = kpro_master,
      all_summaries = all_summaries,
      all_plots = all_plots,
      report_path = report_path,
      study_params = study_params,
      output_dir = output_dir,
      registry = registry,
      quiet = quiet
    )
    
    list(
      success = TRUE,
      zip_path = zip_path,
      message = "Release bundle created successfully"
    )
  }, error = function(e) {
    list(
      success = FALSE,
      zip_path = NA_character_,
      message = e$message
    )
  })
  
  result
}