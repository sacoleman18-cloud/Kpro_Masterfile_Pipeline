# =============================================================================
# UTILITY: console.R - Console Formatting & Output
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# PURPOSE
# -------
# Console formatting utilities for visual output. Provides consistent
# stage headers, workflow summaries, and pipeline completion displays.
# Separated from utilities.R for modularity and reduced file size.
#
# CONSOLE CONTRACT
# ----------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Zero internal dependencies
#    - This file imports ONLY base R functions
#    - MUST NOT source or depend on any other project files
#    - MUST NOT write to log files (use logging.R for that)
#
# 2. Console Output Only
#    - All output via message() function
#    - No file writes
#    - Returns invisibly
#
# 3. Consistent Formatting
#    - ASCII box characters (+-|=)
#    - Configurable width (default: 65)
#    - Stage headers: single-line boxes
#    - Workflow summaries: double-line boxes
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Write to log files
#   - Perform data transformations
#   - Load or save files
#   - Depend on any other project module
#
# DEPENDENCIES
# ------------
# External only:
#   - base R: sprintf, strrep, message, nchar, floor, ceiling
#
# FUNCTIONS PROVIDED
# ------------------
#
# Text Utilities - Center text for formatting:
#
#   - center_text():
#       Uses packages: base R (nchar, floor, ceiling, strrep, paste0)
#       Calls internal: none
#       Purpose: Center text string within fixed width (used by all format functions)
#
# Stage Formatting - Single-line stage headers:
#
#   - print_stage_header():
#       Uses packages: base R (message, sprintf)
#       Calls internal: console.R (center_text)
#       Purpose: Print stage header in single-line box (stage number + description)
#
#   - print_stage_banner():
#       Uses packages: base R (message, sprintf)
#       Calls internal: console.R (center_text)
#       Purpose: Print stage banner in single-line box with verbose gating
#
# Workflow Output - Multi-line workflow summaries:
#
#   - print_workflow_summary():
#       Uses packages: base R (message, sprintf, strrep)
#       Calls internal: console.R (center_text)
#       Purpose: Print workflow completion summary in double-line box
#
#   - print_pipeline_complete():
#       Uses packages: base R (message, strrep, nchar, ceiling, sprintf)
#       Calls internal: console.R (center_text)
#       Purpose: Print final pipeline completion message with double-line box
#
# CHANGELOG
# ---------
# 2026-02-05: DOCUMENTATION & FEATURE - Standards compliance + print_stage_banner
#             - Renamed "CONTENTS" section to "FUNCTIONS PROVIDED"
#             - Added print_stage_banner() for orchestrator stage headers
#             - Implements verbose parameter gating pattern
#             - Completes console formatting API for run_* orchestrators
# 2026-02-04: Initial creation - split from utilities.R
#             - Moved center_text(), print_stage_header()
#             - Moved print_workflow_summary(), print_pipeline_complete()
#             - Ensures utilities.R stays under LLM token limits
#
# =============================================================================


# ==============================================================================
# TEXT HELPERS
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


# ==============================================================================
# STAGE FORMATTING
# ==============================================================================


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
#' # Output:
#' # +----------------------------------------------------------------+
#' # |                 STAGE 7.1: Load Configuration                  |
#' # +----------------------------------------------------------------+
#'
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


#' Print Stage Banner (for Orchestrators)
#'
#' @description
#' Prints a large, prominent banner for major pipeline stages in orchestrator
#' functions (run_* files). Uses double-line ASCII box for visual prominence.
#' Supports verbose parameter gating for Shiny integration.
#'
#' @param stage_name Character. Stage name (e.g., "INGEST & STANDARDIZE",
#'   "FINALIZE CPN", "SUMMARY STATISTICS")
#' @param verbose Logical. Print banner to console? Default: FALSE
#'   When FALSE, function returns silently (for Shiny UI mode)
#' @param width Integer. Total width of box interior. Default: 65
#'
#' @return Invisible NULL.
#'
#' @section CONTRACT:
#' - Uses double-line ASCII box characters (+|=)
#' - Gated by verbose parameter for Shiny compatibility
#' - Consistent width across all orchestrators
#' - Auto-centers stage name
#'
#' @section DOES NOT:
#' - Write to log file (use log_message separately)
#' - Validate stage name format
#' - Display stage numbers (use print_stage_header for numbered stages)
#'
#' @section GATING PATTERN:
#' Per CODING_STANDARDS, console output should be gated by verbose:
#' ```r
#' # In orchestrator functions:
#' print_stage_banner("FINALIZE CPN", verbose = verbose)
#' 
#' # User controls verbosity:
#' result <- run_phase3_analysis_reporting(verbose = TRUE)   # Shows banners
#' result <- run_phase3_analysis_reporting(verbose = FALSE)  # Silent (Shiny mode)
#' ```
#'
#' @examples
#' \dontrun{
#' # In orchestrator function
#' print_stage_banner("INGEST & STANDARDIZE", verbose = TRUE)
#' # Output:
#' # +==================================================================+
#' # ||                  INGEST & STANDARDIZE                         ||
#' # +==================================================================+
#'
#' # Silent mode for Shiny
#' print_stage_banner("FINALIZE CPN", verbose = FALSE)
#' # No output
#' }
#'
#' @export
print_stage_banner <- function(stage_name, verbose = FALSE, width = 65) {
  
  # Gate by verbose parameter
  if (!verbose) {
    return(invisible(NULL))
  }
  
  # Center text
  centered <- center_text(stage_name, width)
  
  # Print double-line box
  message(sprintf("\n+%s+", strrep("=", width)))
  message(sprintf("||%s||", centered))
  message(sprintf("+%s+\n", strrep("=", width)))
  
  invisible(NULL)
}


# ==============================================================================
# SUMMARY FORMATTING
# ==============================================================================


#' Print Workflow Completion Summary
#'
#' @description
#' Prints a formatted double-line ASCII box with workflow completion details.
#' Used at the end of each workflow to summarize outputs.
#'
#' @param workflow Character. Workflow number (e.g., "07", "05") or chunk
#'   identifier (e.g., "CHUNK 1", "CHUNK 3")
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
#' # Output:
#' # +==================================================================+
#' # ||         WORKFLOW 07 COMPLETE: Report Generated                ||
#' # +==================================================================+
#' #
#' #   - Report: bat_activity_report_20260109.html
#' #   - Duration: 12.3 seconds
#'
#' print_workflow_summary(
#'   workflow = "CHUNK 1",
#'   title = "Ingest & Standardize Complete",
#'   items = list(
#'     "Rows" = "50,000",
#'     "Checkpoint" = "02_kpro_master_20260201_143022.csv"
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
#' and next steps guidance. Used only at the end of Phase 3 /
#' run_phase3_analysis_reporting().
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
#' - Open the report automatically
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
#' # Output:
#' # +==================================================================+
#' # ||                     PIPELINE COMPLETE                         ||
#' # +==================================================================+
#' #
#' # [*] PIPELINE OUTPUTS
#' # ----------------------------------------
#' #   Master Data:
#' #     outputs/final/Master_20260109.csv
#' #   Report:
#' #     results/reports/bat_activity_report_20260109.html
#' #
#' # [*] NEXT STEPS
#' # ----------------------------------------
#' #   1. Review the HTML report
#' #   2. Share with collaborators
#' #
#' # [*] VIEW REPORT
#' # ----------------------------------------
#' #   browseURL('results/reports/bat_activity_report_20260109.html')
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
