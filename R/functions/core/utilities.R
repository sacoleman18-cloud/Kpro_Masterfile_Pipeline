# =============================================================================
# MODULE: utilities.R - Foundational Utilities (ZERO DEPENDENCIES)
# =============================================================================
# PURPOSE
# -------
# Foundational utilities with ZERO internal dependencies. All other modules
# depend on this file. Must be loaded first. Provides logging, safe I/O,
# checkpoint management, file discovery, console formatting, and orchestrator
# helper functions. Updated to reduce code redundancy in orchestrating functions.
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
# 5. Console Formatting
#    - Consistent stage headers, banners, and summaries
#    - All formatting respects verbose parameter
#
# 6. Path Generation
#    - All paths use here::here()
#    - Timestamped output paths with configurable precision
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Depend on validation.R, config.R, or any other internal modules
#   - Perform data transformations
#   - Enforce schemas
#   - Make API calls
#
# DEPENDENCIES
# ------------
# R Packages:
#   - base: File operations, string manipulation
#   - readr: read_csv
#   - lubridate: ymd_hms
#   - here: here
#   - dplyr: tibble, n_distinct, filter, bind_rows
#
# Internal Dependencies:
#   NONE - This is Layer 1
#
# FUNCTIONS PROVIDED
# ------------------
# Directory Management (1 function):
#   - ensure_dir_exists(): Create directory if missing
#
# Logging (2 functions):
#   - log_message(): Append message to pipeline log
#   - initialize_pipeline_log(): Start new log section
#
# Safe I/O (2 functions):
#   - safe_read_csv(): Read CSV with error handling
#   - convert_empty_to_na(): Convert empty strings to NA
#
# File Discovery (2 functions):
#   - find_most_recent_file(): Find latest file matching pattern
#   - find_most_recent_checkpoint(): Discover checkpoint by type
#
# Checkpoint Management (5 functions):
#   - load_or_checkpoint(): Load from memory or file
#   - load_intro_standardized(): Load 01 output
#   - load_master_data(): Load 02 output
#   - load_cpn_final(): Load 04 output
#   - load_cpn_template_original(): Load 03 ORIGINAL template
#
# Path Generation (2 functions):
#   - make_output_path(): Generate output path with timestamp
#   - make_timestamped_output_path(): Generate timestamped result path
#
# Template Utilities (1 function):
#   - fill_readme_template(): Populate README template
#
# Console Formatting (5 functions):
#   - center_text(): Center text in fixed width
#   - print_stage_header(): Print stage number and title
#   - print_stage_banner(): Print large stage banner with box
#   - print_workflow_summary(): Print workflow completion summary
#   - print_pipeline_complete(): Print final pipeline summary
#
# Orchestrator Helpers (3 functions):
#   - store_stage_results(): Add stage outputs to result list
#   - load_cpn_template(): Load and standardize CPN template
#
# Operators (1 function):
#   - %||%: Null coalescing operator
#
# USAGE
# -----
# source("R/functions/core/utilities.R")
# 
# # Logging
# initialize_pipeline_log()
# log_message("Processing started")
#
# # File discovery
# latest_csv <- find_most_recent_file("outputs", "^02_.*\\.csv$")
# checkpoint <- find_most_recent_checkpoint("kpro_master")
#
# # Console formatting
# print_stage_banner("FINALIZE CPN", verbose = TRUE)
# print_stage_header("1", "Load Configuration", verbose = TRUE)
#
# # Orchestrator helpers
# result <- list()
# result <- store_stage_results(result, "finalize_cpn", outputs, validation_html)
# template_result <- load_cpn_template(template_path, validation_context)
#
# CHANGELOG
# ---------
# 2026-02-03: Added orchestrator helper functions to reduce redundancy
#             - Added print_stage_banner() for major stage headers
#             - Added find_most_recent_checkpoint() for checkpoint discovery
#             - Added make_timestamped_output_path() for results/ output files
#             - Added store_stage_results() for result list assembly
#             - Added load_cpn_template() for template loading with deduplication
# 2026-01-31: Added center_text() helper for banner formatting
# 2025-12-29: Added load_cpn_template_original() for template loading
# 2025-12-26: Initial CODING_STANDARDS compliant version
# =============================================================================


# ==============================================================================
# OPERATORS
# ==============================================================================

#' Null Coalescing Operator
#'
#' @description
#' Returns left-hand side if not NULL, otherwise returns right-hand side.
#' Equivalent to `x %||% y` in rlang package.
#'
#' @param x Value to check for NULL.
#' @param y Default value if x is NULL.
#'
#' @return Either x or y.
#'
#' @section CONTRACT:
#' - Returns x if !is.null(x)
#' - Returns y if is.null(x)
#' - No side effects
#'
#' @section DOES NOT:
#' - Check for NA (only NULL)
#' - Evaluate y unless needed (lazy evaluation)
#'
#' @examples
#' \dontrun{
#' config_value <- user_value %||% default_value
#' timezone <- params$timezone %||% "America/Chicago"
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
#' Creates directory if it doesn't exist. Safe to call multiple times.
#'
#' @param dir_path Character. Directory path to ensure exists.
#'
#' @return Invisible TRUE on success.
#'
#' @section CONTRACT:
#' - Creates directory if missing (including parent directories)
#' - No-op if directory already exists
#' - Messages when creating new directory
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
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    message(sprintf("Created directory: %s", dir_path))
  }
  
  invisible(TRUE)
}


# ==============================================================================
# LOGGING
# ==============================================================================

#' Log Message to Pipeline Log
#'
#' @description
#' Appends timestamped message to pipeline log file. Creates log directory
#' if needed. Always writes regardless of verbose parameter.
#'
#' @param message Character. Message to log.
#' @param log_path Character. Path to log file. Default: "logs/pipeline_log.txt"
#'
#' @return Invisible TRUE.
#'
#' @section CONTRACT:
#' - ALWAYS writes to log (not gated by verbose)
#' - Creates log directory if needed
#' - Appends to existing log (does not overwrite)
#' - Timestamps each message
#'
#' @section DOES NOT:
#' - Rotate logs
#' - Clear old entries
#' - Print to console
#'
#' @examples
#' \dontrun{
#' log_message("=== WORKFLOW 01: START ===")
#' log_message("[Stage 1] Configuration loaded")
#' }
#'
#' @export
log_message <- function(message, log_path = "logs/pipeline_log.txt") {
  
  # Ensure log directory exists
  ensure_dir_exists(dirname(log_path))
  
  # Create timestamped entry
  timestamp <- format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  log_entry <- paste(timestamp, message)
  
  # Append to log
  cat(log_entry, "\n", file = log_path, append = TRUE)
  
  invisible(TRUE)
}


#' Initialize Pipeline Log
#'
#' @description
#' Writes a section header to the log file to mark start of new pipeline run.
#' Call at start of each workflow script.
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
#' - Returns tibble on success
#' - Returns NULL on failure (never stops execution)
#' - Logs all errors to error_log.txt
#' - Reads all columns as character by default
#'
#' @section DOES NOT:
#' - Stop execution on errors
#' - Guess column types
#' - Skip malformed rows
#'
#' @examples
#' \dontrun{
#' df <- safe_read_csv("data/raw/detector_001.csv")
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
  
  tryCatch({
    # Read all columns as character to preserve original data
    df <- readr::read_csv(
      file_path,
      col_types = readr::cols(.default = readr::col_character()),
      ...
    )
    
    if (verbose) {
      message(sprintf("  [OK] Read %d rows from %s", nrow(df), basename(file_path)))
    }
    
    df
    
  }, error = function(e) {
    
    # Log error
    ensure_dir_exists(dirname(error_log_path))
    error_msg <- sprintf(
      "[%s] Failed to read %s: %s\n",
      Sys.time(),
      file_path,
      e$message
    )
    cat(error_msg, file = error_log_path, append = TRUE)
    
    if (verbose) {
      warning(sprintf("Failed to read %s: %s", basename(file_path), e$message))
    }
    
    NULL
  })
}


#' Convert Empty Strings to NA
#'
#' @description
#' Converts empty strings ("") to NA across all columns in a data frame.
#' Useful for cleaning imported CSV data.
#'
#' @param df Data frame to clean.
#'
#' @return Data frame with empty strings replaced by NA.
#'
#' @section CONTRACT:
#' - Replaces "" with NA
#' - Works on all character columns
#' - Preserves column types
#'
#' @section DOES NOT:
#' - Convert whitespace-only strings
#' - Trim whitespace
#' - Modify non-character columns
#'
#' @export
convert_empty_to_na <- function(df) {
  df %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::where(is.character),
        ~ dplyr::na_if(., "")
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
        "No files matching '%s' found in %s%s",
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


#' Find Most Recent Checkpoint by Type
#'
#' @description
#' Discovers the most recent checkpoint file of specified type using
#' standard naming patterns. Consolidates checkpoint discovery logic
#' used across orchestrating functions.
#'
#' Standards Reference: 01_architecture_standards.md §3.2
#'
#' @param checkpoint_type Character. Type of checkpoint:
#'   - "kpro_master": 02_kpro_master_YYYYMMDD_HHMMSS.csv
#'   - "cpn_original": CallsPerNight_ORIGINAL_YYYYMMDD_HHMMSS.csv
#'   - "cpn_edit": CallsPerNight_EDIT_THIS_YYYYMMDD_HHMMSS.csv
#'   - "summary_rds": summary_data_YYYYMMDD.rds
#'   - "plots_rds": plot_objects_YYYYMMDD.rds
#' @param checkpoints_dir Character. Directory to search.
#'   Default: here::here("outputs", "checkpoints")
#' @param required Logical. Stop if not found (vs return NULL). Default: TRUE
#'
#' @return Character. Path to most recent checkpoint, or NULL if not found
#'   and required = FALSE.
#'
#' @section CONTRACT:
#' - Uses standardized checkpoint naming patterns
#' - Returns most recent file (alphabetically last due to timestamp)
#' - Stops with clear error if required = TRUE and not found
#' - Returns NULL if required = FALSE and not found
#'
#' @section DOES NOT:
#' - Load the checkpoint file
#' - Validate checkpoint contents
#' - Search subdirectories
#'
#' @examples
#' \dontrun{
#' # Find most recent master checkpoint (required)
#' master_path <- find_most_recent_checkpoint("kpro_master")
#'
#' # Find most recent RDS (optional)
#' rds_path <- find_most_recent_checkpoint("summary_rds", required = FALSE)
#' if (is.null(rds_path)) {
#'   message("No summary RDS found, will create new")
#' }
#' }
#'
#' @export
find_most_recent_checkpoint <- function(checkpoint_type,
                                        checkpoints_dir = here::here("outputs", "checkpoints"),
                                        required = TRUE) {
  
  # Define patterns for each checkpoint type
  patterns <- list(
    kpro_master = "^02_kpro_master_\\d{8}_\\d{6}\\.csv$",
    cpn_original = "^(?:03_)?CallsPerNight(?:_Template)?_\\d{8}_\\d{6}_ORIGINAL\\.csv$",
    cpn_edit = "^(?:03_)?CallsPerNight(?:_Template)?_\\d{8}_\\d{6}_EDIT_THIS\\.csv$",
    summary_rds = "^summary_data_\\d{8}\\.rds$",
    plots_rds = "^plot_objects_\\d{8}\\.rds$"
  )
  
  if (!checkpoint_type %in% names(patterns)) {
    stop(sprintf("Unknown checkpoint_type: '%s'. Valid types: %s",
                 checkpoint_type,
                 paste(names(patterns), collapse = ", ")))
  }
  
  # Search for files
  files <- list.files(
    checkpoints_dir,
    pattern = patterns[[checkpoint_type]],
    full.names = TRUE
  )
  
  if (length(files) == 0) {
    if (required) {
      stop(sprintf("No %s checkpoint found in %s\n  Run previous pipeline stages first.",
                   checkpoint_type, checkpoints_dir))
    }
    return(NULL)
  }
  
  # Return most recent (last in alphabetical order due to timestamp)
  files[length(files)]
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
#'
#' @return Data from memory or loaded from checkpoint.
#'
#' @section CONTRACT:
#' - Checks global environment first
#' - Falls back to most recent checkpoint
#' - Messages source (memory vs file)
#' - Stops if neither available
#'
#' @section DOES NOT:
#' - Modify the data
#' - Validate data structure
#' - Create checkpoints
#'
#' @export
load_or_checkpoint <- function(var_name,
                               checkpoint_dir,
                               checkpoint_pattern,
                               loader_fn = safe_read_csv,
                               hint = NULL) {
  
  # Check if variable exists in global environment
  if (exists(var_name, envir = .GlobalEnv)) {
    message(sprintf("Using %s from R environment", var_name))
    return(get(var_name, envir = .GlobalEnv))
  }
  
  # Load from checkpoint
  message(sprintf("Loading %s from checkpoint...", var_name))
  checkpoint_path <- find_most_recent_file(
    checkpoint_dir,
    checkpoint_pattern,
    hint = hint
  )
  
  loader_fn(checkpoint_path)
}


#' Load Intro-Standardized Data (Workflow 01 Output)
#'
#' @description
#' Convenience wrapper for loading intro-standardized data from
#' Workflow 01 checkpoint.
#'
#' @param checkpoint_dir Character. Checkpoint directory. Default: "outputs/checkpoints"
#'
#' @return Tibble with intro-standardized data.
#'
#' @export
load_intro_standardized <- function(checkpoint_dir = "outputs/checkpoints") {
  load_or_checkpoint(
    var_name = "raw_combined",
    checkpoint_dir = checkpoint_dir,
    checkpoint_pattern = "^01_intro_standardized_.*\\.csv$",
    hint = "Run 01_ingest_raw_data.R first"
  )
}


#' Load Master Data (Workflow 02 Output)
#'
#' @description
#' Convenience wrapper for loading master data from Workflow 02 checkpoint.
#'
#' @param checkpoint_dir Character. Checkpoint directory. Default: "outputs/checkpoints"
#'
#' @return Tibble with master data.
#'
#' @export
load_master_data <- function(checkpoint_dir = "outputs/checkpoints") {
  load_or_checkpoint(
    var_name = "kpro_master",
    checkpoint_dir = checkpoint_dir,
    checkpoint_pattern = "^02_kpro_master_.*\\.csv$",
    hint = "Run 02_standardize.R first"
  )
}


#' Load Finalized CallsPerNight Data (Workflow 04 Output)
#'
#' @description
#' Convenience wrapper for loading finalized CPN data from Workflow 04.
#'
#' @param checkpoint_dir Character. Checkpoint directory. Default: "outputs/checkpoints"
#'
#' @return Tibble with finalized CallsPerNight data.
#'
#' @export
load_cpn_final <- function(checkpoint_dir = "outputs/checkpoints") {
  load_or_checkpoint(
    var_name = "calls_per_night_final",
    checkpoint_dir = checkpoint_dir,
    checkpoint_pattern = "^04_CallsPerNight_Final_.*\\.csv$",
    hint = "Run 04_finalize_cpn.R first"
  )
}


#' Load Original CallsPerNight Template (Workflow 03 Output)
#'
#' @description
#' Convenience wrapper for loading ORIGINAL template from Workflow 03.
#'
#' @param checkpoint_dir Character. Checkpoint directory. Default: "outputs/checkpoints"
#'
#' @return Tibble with original CPN template.
#'
#' @export
load_cpn_template_original <- function(checkpoint_dir = "outputs/checkpoints") {
  load_or_checkpoint(
    var_name = "calls_per_night_original",
    checkpoint_dir = checkpoint_dir,
    checkpoint_pattern = "^CallsPerNight_ORIGINAL_.*\\.csv$",
    hint = "Run 03_generate_cpn_template.R first"
  )
}


# ==============================================================================
# PATH GENERATION
# ==============================================================================

#' Generate Output Path with Timestamp
#'
#' @description
#' Creates output file path with timestamp. Standard pattern for
#' saving workflow outputs.
#'
#' @param workflow_num Character. Workflow number (e.g., "01", "02").
#' @param base_name Character. Base filename.
#' @param extension Character. File extension. Default: "csv"
#' @param output_dir Character. Output directory. Default: "outputs"
#'
#' @return Character. Full file path with timestamp.
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
#' # Returns: "outputs/01_intro_standardized_20250203_141530.csv"
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


#' Generate Timestamped Output Path in results/
#'
#' @description
#' Creates timestamped file path in results/ directory structure.
#' Used for final deliverables (vs checkpoints in outputs/).
#'
#' Standards Reference: 01_architecture_standards.md §2.1
#'
#' @param base_name Character. Base filename without extension.
#' @param output_subdir Character. Subdirectory in results/ (e.g., "csv", "rds", "reports").
#' @param extension Character. File extension without dot (e.g., "csv", "rds", "html").
#' @param include_time Logical. Include HHMMSS in timestamp? Default: FALSE
#'
#' @return Character. Full path with here::here().
#'
#' @section CONTRACT:
#' - Uses results/ directory (not outputs/)
#' - Timestamp format: YYYYMMDD or YYYYMMDD_HHMMSS
#' - Returns path only (does not create file/directory)
#' - Uses here::here() for reproducibility
#'
#' @section DOES NOT:
#' - Create directories
#' - Check if file exists
#' - Version the file (use save_callspernight_with_version for versioning)
#'
#' @examples
#' \dontrun{
#' # Date-only timestamp (typical for RDS files)
#' path <- make_timestamped_output_path("summary_data", "rds", "rds")
#' # Returns: "results/rds/summary_data_20250203.rds"
#'
#' # Include time (typical for CSV outputs)
#' path <- make_timestamped_output_path("CallsPerNight_final", "csv", "csv", 
#'                                     include_time = TRUE)
#' # Returns: "results/csv/CallsPerNight_final_20250203_141530.csv"
#' }
#'
#' @export
make_timestamped_output_path <- function(base_name,
                                         output_subdir,
                                         extension,
                                         include_time = FALSE) {
  
  timestamp_format <- if (include_time) "%Y%m%d_%H%M%S" else "%Y%m%d"
  timestamp <- format(Sys.time(), timestamp_format)
  
  filename <- sprintf("%s_%s.%s", base_name, timestamp, extension)
  here::here("results", output_subdir, filename)
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
#' @export
fill_readme_template <- function(template_path,
                                 output_path,
                                 parameters,
                                 log_path) {
  
  # Read template
  template_text <- readLines(template_path)
  
  # Replace placeholders
  filled_text <- template_text
  filled_text <- gsub("{{STUDY_NAME}}", 
                      parameters$study_parameters$study_name %||% "Unknown",
                      filled_text)
  filled_text <- gsub("{{START_DATE}}",
                      parameters$study_parameters$start_date %||% "Unknown",
                      filled_text)
  filled_text <- gsub("{{END_DATE}}",
                      parameters$study_parameters$end_date %||% "Unknown",
                      filled_text)
  filled_text <- gsub("{{TIMEZONE}}",
                      parameters$study_parameters$timezone %||% "Unknown",
                      filled_text)
  filled_text <- gsub("{{TIMESTAMP}}",
                      format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                      filled_text)
  
  # Ensure output directory exists
  ensure_dir_exists(dirname(output_path))
  
  # Write filled template
  writeLines(filled_text, output_path)
  
  invisible(TRUE)
}


# ==============================================================================
# CONSOLE FORMATTING
# ==============================================================================

#' Center Text in Fixed Width
#'
#' @description
#' Centers text within fixed width by padding with spaces on both sides.
#' Helper for print_stage_banner().
#'
#' @param text Character. Text to center.
#' @param width Integer. Total width for centering. Default: 63
#'
#' @return Character. Centered text with padding.
#'
#' @section CONTRACT:
#' - Pads with spaces to reach exact width
#' - Truncates text if longer than width
#' - Left-aligns if perfect centering impossible
#'
#' @section DOES NOT:
#' - Add line breaks
#' - Validate text encoding
#'
#' @examples
#' \dontrun{
#' centered <- center_text("FINALIZE CPN", width = 63)
#' # Returns: "                        FINALIZE CPN                         "
#' }
#'
#' @export
center_text <- function(text, width = 63) {
  
  text_width <- nchar(text)
  
  if (text_width >= width) {
    return(substr(text, 1, width))
  }
  
  left_pad <- floor((width - text_width) / 2)
  right_pad <- width - text_width - left_pad
  
  sprintf("%s%s%s",
          strrep(" ", left_pad),
          text,
          strrep(" ", right_pad))
}


#' Print Stage Number and Title
#'
#' @description
#' Prints small stage header (e.g., "Stage 1: Load Configuration").
#' Used for numbered stages within major pipeline sections.
#'
#' @param stage_num Character. Stage number (e.g., "1", "2a").
#' @param stage_title Character. Stage title.
#' @param verbose Logical. Print to console? Default: TRUE
#'
#' @return Invisible NULL.
#'
#' @section CONTRACT:
#' - Only prints if verbose = TRUE
#' - Uses consistent formatting
#' - No logging (console only)
#'
#' @section DOES NOT:
#' - Log to file
#' - Print if verbose = FALSE
#'
#' @examples
#' \dontrun{
#' print_stage_header("1", "Load Configuration", verbose = TRUE)
#' # Prints: "--- Stage 1: Load Configuration ---"
#' }
#'
#' @export
print_stage_header <- function(stage_num, stage_title, verbose = TRUE) {
  
  if (verbose) {
    message(sprintf("--- Stage %s: %s ---", stage_num, stage_title))
  }
  
  invisible(NULL)
}


#' Print Large Stage Banner
#'
#' @description
#' Prints large box banner for major pipeline stages (Finalize CPN,
#' Summary Stats, Plotting, Report & Release). Consolidates banner
#' printing logic used across orchestrating functions.
#'
#' Standards Reference: 05_logging_console_standards.md §2.3
#'
#' @param stage_name Character. Name of stage (e.g., "FINALIZE CPN",
#'   "SUMMARY STATISTICS"). Will be centered in box.
#' @param verbose Logical. Print to console? Default: FALSE
#'
#' @return Invisible NULL. Side effect: prints banner and logs message.
#'
#' @section CONTRACT:
#' - Only prints to console if verbose = TRUE
#' - ALWAYS logs to file via log_message() (regardless of verbose)
#' - Centers stage name in 63-character box
#' - Uses Unicode box-drawing characters
#'
#' @section DOES NOT:
#' - Skip logging (always logs even if verbose = FALSE)
#' - Print stage details (only the banner)
#' - Accept custom box characters
#'
#' @examples
#' \dontrun{
#' print_stage_banner("FINALIZE CPN", verbose = TRUE)
#' # Prints:
#' #
#' # ╔═══════════════════════════════════════════════════════════════╗
#' # ║                        FINALIZE CPN                         ║
#' # ╚═══════════════════════════════════════════════════════════════╝
#' #
#' # Also logs: "=== FINALIZE CPN: START ==="
#' }
#'
#' @export
print_stage_banner <- function(stage_name, verbose = FALSE) {
  
  if (verbose) {
    message("\n")
    message("╔═══════════════════════════════════════════════════════════════╗")
    message(sprintf("║%s║", center_text(stage_name, width = 63)))
    message("╚═══════════════════════════════════════════════════════════════╝")
    message("")
  }
  
  # Always log (regardless of verbose)
  log_message(sprintf("=== %s: START ===", toupper(stage_name)))
  
  invisible(NULL)
}


#' Print Workflow Summary
#'
#' @description
#' Prints completion summary for a workflow with key statistics.
#'
#' @param workflow_name Character. Workflow name.
#' @param duration_sec Numeric. Execution time in seconds.
#' @param summary_stats List. Named list of summary statistics to display.
#'
#' @return Invisible NULL.
#'
#' @section CONTRACT:
#' - Prints formatted box with statistics
#' - Duration shown in seconds with 1 decimal place
#' - Each stat on its own line
#'
#' @section DOES NOT:
#' - Log to file (console only)
#' - Calculate statistics
#' - Validate inputs
#'
#' @export
print_workflow_summary <- function(workflow_name, duration_sec, summary_stats) {
  
  message("\n")
  message("╔═══════════════════════════════════════════════════════════════╗")
  message(sprintf("║  WORKFLOW COMPLETE: %-40s ║", workflow_name))
  message("╚═══════════════════════════════════════════════════════════════╝")
  message("")
  message(sprintf("  Duration: %.1f seconds", duration_sec))
  
  for (stat_name in names(summary_stats)) {
    message(sprintf("  %s: %s", stat_name, summary_stats[[stat_name]]))
  }
  
  message("")
  
  invisible(NULL)
}


#' Print Pipeline Complete Banner
#'
#' @description
#' Prints final pipeline completion banner with overall statistics.
#'
#' @param total_duration_sec Numeric. Total pipeline duration in seconds.
#' @param summary_stats List. Named list of summary statistics.
#'
#' @return Invisible NULL.
#'
#' @section CONTRACT:
#' - Prints large completion banner
#' - Shows total duration and key metrics
#' - Always prints (not gated by verbose)
#'
#' @section DOES NOT:
#' - Log to file
#' - Calculate statistics
#'
#' @export
print_pipeline_complete <- function(total_duration_sec, summary_stats) {
  
  message("\n")
  message("╔═══════════════════════════════════════════════════════════════╗")
  message("║           PIPELINE COMPLETE - ALL STAGES FINISHED           ║")
  message("╚═══════════════════════════════════════════════════════════════╝")
  message("")
  message(sprintf("  Total Duration: %.1f seconds", total_duration_sec))
  
  for (stat_name in names(summary_stats)) {
    message(sprintf("  %s: %s", stat_name, summary_stats[[stat_name]]))
  }
  
  message("")
  message("╚═══════════════════════════════════════════════════════════════╝")
  message("")
  
  invisible(NULL)
}


# ==============================================================================
# ORCHESTRATOR HELPER FUNCTIONS
# ==============================================================================

#' Store Stage Results in Master Result List
#'
#' @description
#' Adds stage outputs to result list with validation tracking. Consolidates
#' the result storage pattern used across all orchestrating functions.
#' Reduces ~10 lines of boilerplate per stage.
#'
#' Standards Reference: 01_architecture_standards.md §4.2
#'
#' @param result_list List. Master result list being built (passed by reference).
#' @param stage_key Character. Key for this stage (e.g., "finalize_cpn",
#'   "summary_stats", "plotting", "report_release").
#' @param stage_outputs List. Stage-specific outputs to store.
#' @param validation_html Character. Path to validation HTML file for this stage.
#'
#' @return List. Updated result list with stage outputs and validation tracking.
#'
#' @section CONTRACT:
#' - Adds validation_report to stage_outputs automatically
#' - Stores complete stage outputs under stage_key
#' - Appends validation HTML to validation_html_paths vector
#' - Returns updated result list (functional style)
#'
#' @section DOES NOT:
#' - Validate stage_outputs structure
#' - Check if stage_key already exists
#' - Create validation HTML (must be provided)
#' - Log the storage operation
#'
#' @examples
#' \dontrun{
#' result <- list(validation_html_paths = character())
#'
#' # Store Finalize CPN results
#' finalize_outputs <- list(
#'   calls_per_night_final = cpn_final,
#'   cpn_file = cpn_path,
#'   total_edits = 5
#' )
#' result <- store_stage_results(result, "finalize_cpn", 
#'                               finalize_outputs, validation_html)
#' }
#'
#' @export
store_stage_results <- function(result_list,
                                stage_key,
                                stage_outputs,
                                validation_html) {
  
  # Add validation report to outputs
  stage_outputs$validation_report <- validation_html
  
  # Store stage results under stage key
  result_list[[stage_key]] <- stage_outputs
  
  # Track validation HTML path
  result_list$validation_html_paths <- c(
    result_list$validation_html_paths,
    validation_html
  )
  
  result_list
}


#' Load and Standardize CPN Template
#'
#' @description
#' Loads CPN template CSV (ORIGINAL or EDIT_THIS), applies deduplication,
#' standardizes data types, and optionally tracks changes in validation context.
#' Consolidates template loading logic used in Finalize CPN stage.
#' Eliminates ~80 lines of duplicate code.
#'
#' Standards Reference: 04_data_standards.md §4.1
#'
#' @param template_path Character. Path to template CSV file.
#' @param validation_context List or NULL. Validation context to log events.
#'   If NULL, deduplication is not logged. Default: NULL
#' @param verbose Logical. Print progress messages? Default: FALSE
#'
#' @return List with three elements:
#'   \describe{
#'     \item{template}{Tibble. Cleaned and standardized template data}
#'     \item{validation_context}{Updated validation context (if provided)}
#'     \item{n_duplicates}{Integer. Number of duplicate rows removed}
#'   }
#'
#' @section CONTRACT:
#' - Reads CSV with safe_read_csv()
#' - Removes exact duplicates (Detector + Night)
#' - Converts Night to Date with format "%m-%d-%y"
#' - Converts CallsPerNight and RecordingHours to numeric
#' - Converts StartDateTime and EndDateTime to POSIXct (if present)
#' - Logs deduplication to validation context (if provided)
#' - Returns standardized tibble ready for use
#'
#' @section DOES NOT:
#' - Validate template completeness
#' - Calculate RecordingHours (preserves existing values)
#' - Classify Status (that happens in next stage)
#' - Stop on missing columns (handles gracefully)
#'
#' @examples
#' \dontrun{
#' # Load ORIGINAL template with validation tracking
#' result <- load_cpn_template(
#'   "outputs/checkpoints/CallsPerNight_ORIGINAL_20250203_141530.csv",
#'   validation_context = validation_context_finalize_cpn,
#'   verbose = TRUE
#' )
#' template_original <- result$template
#' validation_context_finalize_cpn <- result$validation_context
#'
#' # Load EDIT_THIS template without validation
#' result <- load_cpn_template(
#'   "outputs/checkpoints/CallsPerNight_EDIT_THIS_20250203_141530.csv",
#'   verbose = TRUE
#' )
#' template_edited <- result$template
#' }
#'
#' @export
load_cpn_template <- function(template_path,
                              validation_context = NULL,
                              verbose = FALSE) {
  
  # Load CSV
  template <- safe_read_csv(template_path, na = c("", "NA"), verbose = verbose)
  
  if (is.null(template)) {
    stop(sprintf("Failed to load template: %s", template_path))
  }
  
  nrow_before <- nrow(template)
  
  # Deduplicate by Detector + Night
  template <- template %>%
    dplyr::distinct(Detector, Night, .keep_all = TRUE)
  
  n_duplicates <- nrow_before - nrow(template)
  
  if (verbose && n_duplicates > 0) {
    message(sprintf("  [!] Removed %d duplicate rows", n_duplicates))
  }
  
  # Standardize data types
  template <- template %>%
    dplyr::mutate(
      # Parse Night with explicit format (CRITICAL: prevents date parsing failures)
      Night = as.Date(Night, format = "%m-%d-%y"),
      
      # Convert to numeric
      CallsPerNight = as.numeric(CallsPerNight),
      
      # Safe RecordingHours conversion (handle empty strings)
      RecordingHours = dplyr::if_else(
        RecordingHours == "" | is.na(RecordingHours),
        NA_real_,
        as.numeric(RecordingHours)
      )
    )
  
  # Convert datetime columns if present
  if ("StartDateTime" %in% names(template)) {
    template <- template %>%
      dplyr::mutate(
        StartDateTime = lubridate::ymd_hms(StartDateTime, quiet = TRUE),
        EndDateTime = lubridate::ymd_hms(EndDateTime, quiet = TRUE)
      )
  }
  
  # Log deduplication if validation context provided
  if (!is.null(validation_context) && n_duplicates > 0) {
    validation_context <- log_validation_event(
      validation_context,
      event_type = "data_cleaning",
      description = sprintf("Template deduplication (%s)", basename(template_path)),
      count = n_duplicates
    )
  }
  
  list(
    template = template,
    validation_context = validation_context,
    n_duplicates = n_duplicates
  )
}


# ==============================================================================
# END OF UTILITIES MODULE
# ==============================================================================
