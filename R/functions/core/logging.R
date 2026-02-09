# =============================================================================
# UTILITY: logging.R - File Logging (Audit Trail)
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# PURPOSE
# -------
# File logging utilities for audit trail and debugging. Provides timestamped
# log writing and pipeline run initialization. Separated from utilities.R
# for modularity and reduced file size.
#
# LOGGING CONTRACT
# ----------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Zero internal dependencies
#    - This file imports ONLY base R functions
#    - MUST NOT source or depend on any other project files
#
# 2. File Operations
#    - All logs written to logs/ directory
#    - Timestamps use ISO 8601 format
#    - Auto-creates directories as needed
#    - Append-only (never overwrites existing logs)
#
# 3. Silent Operation
#    - No console output (use console.R for that)
#    - Returns invisibly
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Write to console (use console.R)
#   - Perform data transformations
#   - Depend on any other project module
#   - Rotate or truncate logs
#
# DEPENDENCIES
# ------------
# External only:
#   - base R: cat, paste0, Sys.time, file, dirname, dir.exists, dir.create
#
# FUNCTIONS PROVIDED
# ------------------
#
# Directory Management - Internal logging setup:
#
#   - ensure_log_dir_exists():
#       Uses packages: base R (dir.exists, dir.create)
#       Calls internal: none (filesystem only)
#       Purpose: Create log directory if missing (internal helper, duplicated from utilities)
#
# Logging Functions - Timestamped audit trail:
#
#   - log_message():
#       Uses packages: base R (cat, paste0, Sys.time, file, sink)
#       Calls internal: logging.R (ensure_log_dir_exists)
#       Purpose: Write timestamped message to log file (append-only)
#
#   - initialize_pipeline_log():
#       Uses packages: base R (cat, file, paste0, Sys.time)
#       Calls internal: logging.R (ensure_log_dir_exists)
#       Purpose: Create new pipeline log file (ISO 8601 header)
#
# CHANGELOG
# ---------
# 2026-02-05: DOCUMENTATION FIX - Renamed "CONTENTS" to "FUNCTIONS PROVIDED"
#             - Updated to match documentation standards template
# 2026-02-04: Initial creation - split from utilities.R
#             - Moved log_message(), initialize_pipeline_log()
#             - Added internal ensure_log_dir_exists() helper
#             - Ensures utilities.R stays under LLM token limits
#
# =============================================================================


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================


#' Ensure Log Directory Exists (Internal)
#'
#' @description
#' Internal helper to create log directory if needed. Duplicated from
#' utilities.R to maintain zero-dependency principle.
#'
#' @param dir_path Character. Directory path to ensure exists.
#'
#' @return Invisible TRUE.
#'
#' @keywords internal
ensure_log_dir_exists <- function(dir_path) {
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
  }
  invisible(TRUE)
}


# ==============================================================================
# LOGGING FUNCTIONS
# ==============================================================================


#' Write a Timestamped Message to Log File
#'
#' @description
#' Appends a timestamped message to a log file, creating directories if needed.
#' All pipeline operations should be logged for audit trail. This function
#' writes to FILE only - no console output.
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
#' - Silent operation - use message() for console output
#'
#' @section DOES NOT:
#' - Write to console
#' - Rotate logs
#' - Silence errors
#' - Validate message format
#'
#' @section GATING GUIDANCE:
#' Per CODING_STANDARDS, log_message() should NEVER be gated by verbose:
#' ```r
#' # CORRECT: Always log to file
#' log_message("Processing started")
#'
#' # CORRECT: Gate console output separately
#' if (verbose) message("Processing started...")
#' log_message("Processing started")
#'
#' # WRONG: Never gate log_message
#' if (verbose) log_message("...")  # Don't do this!
#' ```
#'
#' @examples
#' \dontrun{
#' log_message("Processing started")
#' log_message("[Stage 2.1] Loaded 50,000 rows")
#' log_message(sprintf("[ERROR] Failed to load: %s", filename))
#'
#' # Custom log path
#' log_message("Debug info", log_path = "logs/debug.txt")
#' }
#'
#' @export
log_message <- function(msg, log_path = "logs/pipeline_log.txt") {
  
  # Ensure log directory exists
  ensure_log_dir_exists(dirname(log_path))
  
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
#' each workflow script or orchestrating function. The header provides
#' visual separation between pipeline runs in the log file.
#'
#' @param log_path Character. Path to log file. Default: "logs/pipeline_log.txt"
#'
#' @return Invisible TRUE.
#'
#' @section CONTRACT:
#' - Creates directories if needed
#' - Appends header to existing log (does not clear)
#' - Timestamps the run start
#' - Uses consistent header format for visual separation
#'
#' @section DOES NOT:
#' - Clear existing log
#' - Rotate logs
#' - Validate previous entries
#' - Write to console
#'
#' @examples
#' \dontrun{
#' # At start of pipeline run
#' initialize_pipeline_log()
#' log_message("=== CHUNK 1: Ingest & Standardize - START ===")
#'
#' # Custom log path
#' initialize_pipeline_log(log_path = "logs/debug.txt")
#' }
#'
#' @export
initialize_pipeline_log <- function(log_path = "logs/pipeline_log.txt") {
  
  # Ensure log directory exists
  ensure_log_dir_exists(dirname(log_path))
  
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
