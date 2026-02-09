# =============================================================================
# UTILITY: validation_reporting.R - Validation Event Tracking & Reporting
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# - Tracks validation events and generates HTML reports
# - Used by all modules and workflows
# PURPOSE
# -------
# Tracks execution events during pipeline runs and generates comprehensive
# validation reports (HTML + YAML). Provides the complete validation reporting
# lifecycle: event tracking → context finalization → report generation.
#
# This module separates execution/runtime validation (what happened during
# the run) from data quality validation (is the data correct). By centralizing
# execution tracking and reporting here, we create a self-contained validation
# system that's independent of both artifact registry and data validation.
#
# VALIDATION REPORTING CONTRACT
# ------------------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Event Tracking
#    - create_validation_context: Initialize empty event tracker
#    - log_validation_event: Append events, update counters
#    - Events accumulate throughout workflow execution
#
# 2. Report Generation
#    - finalize_validation_report: Save YAML + generate HTML
#    - generate_validation_html: Self-contained HTML with embedded CSS
#    - Reports capture complete execution history
#
# 3. Orchestrator Convenience
#    - init_stage_validation: Wrapper around create_validation_context
#    - complete_stage_validation: Wrapper around finalize_validation_report
#    - Reduce boilerplate in run_* orchestrating functions
#
# 4. Self-Contained
#    - No dependencies on artifact registry
#    - No dependencies on data validation
#    - Complete validation lifecycle in one module
#
# 5. Standards Compliance
#    - All HTML generation follows web standards
#    - YAML output follows pipeline conventions
#    - Verbose parameter gating for Shiny integration
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Validate data quality (validation/validation.R)
#   - Manage artifact registry (core/artifacts.R)
#   - Perform data transformations
#   - Read or write data files (only YAML/HTML reports)
#
# DEPENDENCIES
# ------------
# R Packages:
#   - yaml: YAML file I/O for validation reports
#
# Internal Dependencies:
#   - core/utilities.R: log_message (file logging), %||% (null coalescing)
#
# FUNCTIONS PROVIDED
# ------------------
#
# Event Tracking - Record execution events throughout workflow:
#
#   - create_validation_context():
#       Uses packages: base R (list operations, Sys.time, format)
#       Calls internal: none
#       Purpose: Initialize empty context object with event tracking structure
#
#   - log_validation_event():
#       Uses packages: base R (list operations, c, append)
#       Calls internal: none
#       Purpose: Append single event to context, update cumulative counters
#
# Report Generation - Create validation outputs:
#
#   - finalize_validation_report():
#       Uses packages: yaml (write_yaml), here (here), base R (file.path, dir.create)
#       Calls internal: validation_reporting.R (generate_validation_html),
#                       utilities.R (log_message, ensure_dir_exists)
#       Purpose: Finalize context object, save YAML + HTML report
#
#   - generate_validation_html():
#       Uses packages: base R (paste, sprintf, HTML string building)
#       Calls internal: validation_reporting.R (sum_event_counts, format_details)
#       Purpose: Create self-contained HTML report with embedded CSS
#
# Orchestrator Convenience Wrappers - Simplified stage validation:
#
#   - init_stage_validation():
#       Uses packages: base R (list operations)
#       Calls internal: validation_reporting.R (create_validation_context)
#       Purpose: Wrapper around create_validation_context for orchestrator
#
#   - complete_stage_validation():
#       Uses packages: base R (file.path), here (here)
#       Calls internal: validation_reporting.R (finalize_validation_report),
#                       utilities.R (log_message, ensure_dir_exists)
#       Purpose: Wrapper around finalize_validation_report for orchestrator
#
# Internal Helper Functions - Support functions not exported:
#
#   - sum_event_counts():
#       Uses packages: base R (tapply, list operations, sum)
#       Calls internal: none
#       Purpose: Sum event counts by event type for summary display
#
#   - format_details():
#       Uses packages: base R (paste, sprintf, HTML formatting)
#       Calls internal: none
#       Purpose: Format event details as HTML table rows
#
# USAGE
# -----
# # In orchestrator function (e.g., run_finalize_to_report.R)
# 
# # Initialize tracking
# validation_context <- init_stage_validation("finalize_cpn", study_params)
# 
# # Log events during execution
# validation_context <- log_validation_event(
#   validation_context,
#   event_type = "data_loaded",
#   description = "Master data loaded",
#   count = nrow(kpro_master)
# )
# 
# # Complete and generate report
# validation_html <- complete_stage_validation(
#   validation_context,
#   validation_dir = here::here("results", "validation"),
#   stage_name = "FINALIZE CPN",
#   verbose = TRUE
# )
#
# EVENT TYPES REFERENCE
# ----------------------
# The following event types are recognized and auto-accumulate in summary:
#
# Data Loading:
#   - files_loaded: CSV files successfully loaded
#   - file_failed: Individual file load failures
#   - data_loaded: Data loaded into memory
#
# Data Quality:
#   - rows_removed: Rows filtered out (N <= 0, NA, invalid)
#   - schema_unknown: Rows with undetectable schema version
#   - duplicate: Duplicate rows detected/removed
#
# Data Filters:
#   - filter_noid: NoID detections removed via user filter
#   - filter_zero_pulses: Zero-pulse calls removed via user filter
#
# Transformations:
#   - schema_transform: Schema version transformations applied
#   - detector_mapping: Detector IDs mapped to friendly names
#   - timezone_conversion: UTC to local timezone conversion
#   - column_added: New columns created
#   - column_removed: Columns dropped
#
# Validation:
#   - rows_processed: Total rows in final output
#   - source_breakdown: Local vs external data contribution
#   - schema_detection: Schema version detection results
#
# Status:
#   - warning: Non-fatal issues
#   - error: Fatal issues
#
# Last Modified: 2026-02-09
#
# CHANGELOG
# ---------
# 2026-02-05: DOCUMENTATION FIX - Cleaned up orphaned comments
#             - Removed stray comment between sections (line 823-824)
#             - Improved ORCHESTRATOR HELPERS section header clarity
# 2026-02-03: Initial creation via extraction from artifacts.R and validation.R
#             - Extracted create_validation_context() from artifacts.R
#             - Extracted log_validation_event() from artifacts.R
#             - Extracted finalize_validation_report() from artifacts.R
#             - Extracted generate_validation_html() from artifacts.R
#             - Extracted init_stage_validation() from validation.R
#             - Extracted complete_stage_validation() from validation.R
#             - Created self-contained validation reporting module
#             - Separated execution validation from data validation
#             - Removed dependencies on artifact registry
# =============================================================================

library(yaml)

# =============================================================================
# CONSTANTS
# =============================================================================

PIPELINE_VERSION <- "2.1"


# =============================================================================
# EVENT TRACKING
# =============================================================================


#' Create Validation Context
#'
#' @description
#' Initializes a validation tracking context that accumulates
#' validation events throughout a workflow run.
#'
#' @param workflow Character. Workflow identifier (e.g., "01", "02")
#' @param study_name Character. Study name for context
#'
#' @return List. Validation context object
#'
#' @section CONTRACT:
#' - Creates empty events list ready for log_validation_event()
#' - Initializes all summary counters to 0
#' - Records start timestamp in UTC
#'
#' @section DOES NOT:
#' - Validate workflow identifier format
#' - Check if study exists
#'
#' @export
create_validation_context <- function(workflow, study_name = NULL) {
  list(
    workflow = workflow,
    study_name = study_name,
    started_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    pipeline_version = PIPELINE_VERSION,
    events = list(),
    summary = list(
      rows_processed = 0,
      rows_removed = 0,
      duplicates_detected = 0,
      files_loaded = 0,
      files_failed = 0,
      schema_unknown = 0,
      detectors_mapped = 0,
      timezone_conversions = 0,
      na_values = list(),
      schema_distribution = list(),
      warnings = 0,
      errors = 0
    )
  )
}


#' Log Validation Event
#'
#' @description
#' Records a validation event (row removal, duplicate detection, filter
#' application, etc.) to the validation context. Automatically updates 
#' summary counters based on event_type.
#'
#' @param context List. Validation context from create_validation_context()
#' @param event_type Character. Type of event (see module header for types)
#' @param description Character. Human-readable description
#' @param count Numeric. Count associated with event (optional)
#' @param details List. Additional details (optional)
#'
#' @return List. Updated validation context
#'
#' @section CONTRACT:
#' - Appends event to context$events
#' - Auto-updates relevant summary counters
#' - Records timestamp for each event
#' - Preserves all previous events
#' - Tracks user-configured data filters (filter_noid, filter_zero_pulses)
#'
#' @section DOES NOT:
#' - Validate event_type against known types
#' - Prevent duplicate events
#' - Limit number of events
#'
#' @export
log_validation_event <- function(context, 
                                 event_type, 
                                 description, 
                                 count = NULL,
                                 details = NULL) {
  
  event <- list(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    type = event_type,
    description = description,
    count = count,
    details = details
  )
  
  context$events <- c(context$events, list(event))
  
  # Update summary counters based on event type
  if (event_type == "rows_removed" && !is.null(count)) {
    context$summary$rows_removed <- context$summary$rows_removed + count
  }
  
  if (event_type == "duplicate" && !is.null(count)) {
    context$summary$duplicates_detected <- context$summary$duplicates_detected + count
    # ALSO add to rows_removed since duplicates ARE removed rows
    context$summary$rows_removed <- context$summary$rows_removed + count
  }
  
  # NEW: Track user-configured data filters
  if (event_type == "filter_noid" && !is.null(count)) {
    # Track NoID filter removals in rows_removed total
    context$summary$rows_removed <- context$summary$rows_removed + count
  }
  
  if (event_type == "filter_zero_pulses" && !is.null(count)) {
    # Track zero-pulse filter removals in rows_removed total
    context$summary$rows_removed <- context$summary$rows_removed + count
  }
  
  if (event_type == "files_loaded" && !is.null(count)) {
    context$summary$files_loaded <- context$summary$files_loaded + count
  }
  
  if (event_type == "file_failed") {
    context$summary$files_failed <- context$summary$files_failed + 1
  }
  
  if (event_type == "schema_unknown" && !is.null(count)) {
    context$summary$schema_unknown <- context$summary$schema_unknown + count
  }
  
  if (event_type == "detector_mapping" && !is.null(count)) {
    context$summary$detectors_mapped <- count  # Set, not accumulate
  }
  
  if (event_type == "timezone_conversion") {
    context$summary$timezone_conversions <- context$summary$timezone_conversions + 1
  }
  
  if (event_type == "warning") {
    context$summary$warnings <- context$summary$warnings + 1
  }
  
  if (event_type == "error") {
    context$summary$errors <- context$summary$errors + 1
  }
  
  context
}


# =============================================================================
# REPORT GENERATION
# =============================================================================


#' Finalize and Save Validation Report
#'
#' @description
#' Generates a validation report from the accumulated context
#' and saves it as both YAML and HTML. 
#'
#' @param context List. Validation context with accumulated events
#' @param output_dir Character. Directory for output files
#'
#' @return Character. Path to generated HTML report
#'
#' @section CONTRACT:
#' - Saves YAML file with complete context
#' - Generates HTML report with summary and events
#' - Creates output_dir if it doesn't exist
#' - Returns path to HTML file
#'
#' @section DOES NOT:
#' - Validate context structure
#' - Compress or archive old reports
#' - Send notifications
#'
#' @export
finalize_validation_report <- function(context, 
                                       output_dir = here::here("results", "validation")) {
  
  # Ensure directory exists
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Finalize context
  context$completed_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  context$duration_seconds <- as.numeric(
    difftime(
      as.POSIXct(context$completed_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      as.POSIXct(context$started_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      units = "secs"
    )
  )
  
  # Generate timestamp
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # Save YAML
  yaml_path <- file.path(output_dir, sprintf("validation_%s_%s.yaml", 
                                             context$workflow, timestamp))
  yaml::write_yaml(context, yaml_path)
  
  # Generate HTML report
  html_path <- file.path(output_dir, sprintf("validation_%s_%s.html",
                                             context$workflow, timestamp))
  
  generate_validation_html(context, html_path)
  
  message(sprintf("[OK] Validation report saved: %s", basename(html_path)))
  
  html_path
}


#' Generate Validation HTML Report
#'
#' @description
#' Internal function to generate HTML validation report with enhanced
#' formatting, collapsible details, workflow-specific sections, and
#' breakdown of rows removed by filter type.
#'
#' @param context List. Finalized validation context
#' @param output_path Character. Path for HTML output
#'
#' @section CONTRACT:
#' - Generates self-contained HTML file
#' - Includes inline CSS (no external dependencies)
#' - Formats event details as collapsible sections
#' - Creates workflow-specific metric cards
#' - Shows breakdown of rows removed by filter type
#'
#' @keywords internal
generate_validation_html <- function(context, output_path) {
  
  # ============================================================================
  # WORKFLOW-SPECIFIC CONFIGURATION
  # ============================================================================
  
  # Customize labels based on which workflow is running
  # Module 1: Ingestion (files -> rows)
  # Module 2: Transformation (input rows -> output rows)
  
  if (context$workflow == "02") {
    rows_label <- "Output Rows"
  } else {
    rows_label <- "Rows Processed"
  }
  
  # ============================================================================
  # CALCULATE ROWS REMOVED BREAKDOWN
  # ============================================================================
  
  # Helper function to sum counts by event type
  sum_event_counts <- function(events, event_type) {
    matching_events <- Filter(function(e) e$type == event_type, events)
    if (length(matching_events) == 0) return(0)
    
    counts <- sapply(matching_events, function(e) {
      if (is.null(e$count)) return(0)
      as.numeric(e$count)
    })
    
    sum(counts, na.rm = TRUE)
  }
  
  # Count rows removed by each type from events
  rows_removed_invalid <- sum_event_counts(context$events, "rows_removed")
  rows_removed_duplicates <- sum_event_counts(context$events, "duplicate")
  rows_removed_noid <- sum_event_counts(context$events, "filter_noid")
  rows_removed_zero_pulse <- sum_event_counts(context$events, "filter_zero_pulses")
  
  # Build breakdown HTML (only show non-zero items)
  rows_removed_breakdown <- ""
  breakdown_items <- character()
  
  if (rows_removed_invalid > 0) {
    breakdown_items <- c(breakdown_items, 
                         sprintf("<li>Invalid rows: %s</li>", format(rows_removed_invalid, big.mark = ",")))
  }
  if (rows_removed_duplicates > 0) {
    breakdown_items <- c(breakdown_items,
                         sprintf("<li>Duplicates: %s</li>", format(rows_removed_duplicates, big.mark = ",")))
  }
  if (rows_removed_noid > 0) {
    breakdown_items <- c(breakdown_items,
                         sprintf("<li>NoID filtered: %s</li>", format(rows_removed_noid, big.mark = ",")))
  }
  if (rows_removed_zero_pulse > 0) {
    breakdown_items <- c(breakdown_items,
                         sprintf("<li>Zero-pulse filtered: %s</li>", format(rows_removed_zero_pulse, big.mark = ",")))
  }
  
  if (length(breakdown_items) > 0) {
    rows_removed_breakdown <- sprintf('
      <details class="metric-details">
        <summary>View breakdown</summary>
        <ul>%s</ul>
      </details>',
                                      paste(breakdown_items, collapse = "\n          ")
    )
  }
  
  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================
  
  # Helper function to format details as HTML
  format_details <- function(details) {
    if (is.null(details) || length(details) == 0) return("")
    
    items <- sapply(names(details), function(name) {
      value <- details[[name]]
      
      # Handle vectors (character, numeric, etc.)
      if (is.vector(value) && length(value) > 1) {
        value <- paste(value, collapse = ", ")
      } else if (is.numeric(value)) {
        value <- format(value, big.mark = ",")
      } else if (is.list(value)) {
        value <- paste(names(value), value, sep = ": ", collapse = ", ")
      }
      
      sprintf("<li><strong>%s:</strong> %s</li>", name, value)
    })
    
    sprintf("<ul style='margin: 5px 0; padding-left: 20px;'>%s</ul>", 
            paste(items, collapse = ""))
  }
  
  # ============================================================================
  # BUILD EVENT TABLE ROWS
  # ============================================================================
  
  event_rows <- sapply(context$events, function(e) {
    details_html <- if (!is.null(e$details)) {
      sprintf("<br><details><summary style='cursor: pointer; color: #3498db;'>Details</summary>%s</details>",
              format_details(e$details))
    } else {
      ""
    }
    
    sprintf("<tr><td>%s</td><td>%s</td><td>%s%s</td><td>%s</td></tr>",
            substr(e$timestamp, 12, 19),  # Just time, not full timestamp
            e$type,
            e$description,
            details_html,
            if (is.null(e$count)) "-" else format(e$count, big.mark = ","))
  })
  
  # ============================================================================
  # BUILD WORKFLOW-SPECIFIC SECTIONS
  # ============================================================================
  
  # Build data quality section (if module 1)
  data_quality_section <- if (context$workflow == "01") {
    sprintf('
  <h2>Data Quality</h2>
  <div class="grid" style="grid-template-columns: repeat(3, 1fr);">
    <div class="card">
      <div class="metric">%s</div>
      <div class="label">Files Loaded</div>
    </div>
    <div class="card">
      <div class="metric">%s</div>
      <div class="label">Files Failed</div>
    </div>
    <div class="card">
      <div class="metric">%s</div>
      <div class="label">Unknown Schema</div>
    </div>
  </div>',
            format(context$summary$files_loaded, big.mark = ","),
            context$summary$files_failed,
            format(context$summary$schema_unknown, big.mark = ","))
  } else {
    ""
  }
  
  # Build transformation section (if module 2)
  transformation_section <- if (context$workflow == "02") {
    sprintf('
  <h2>Transformations</h2>
  <div class="grid" style="grid-template-columns: repeat(2, 1fr);">
    <div class="card">
      <div class="metric">%s</div>
      <div class="label">Detectors Mapped</div>
    </div>
    <div class="card">
      <div class="metric">%s</div>
      <div class="label">Timezone Conversions</div>
    </div>
  </div>',
            context$summary$detectors_mapped,
            context$summary$timezone_conversions)
  } else {
    ""
  }
  
  # Build schema distribution section (if available)
  schema_section <- if (length(context$summary$schema_distribution) > 0) {
    schema_items <- sapply(names(context$summary$schema_distribution), function(version) {
      count <- context$summary$schema_distribution[[version]]
      pct <- round(100 * count / context$summary$rows_processed, 1)
      sprintf("<li><strong>%s:</strong> %s rows (%.1f%%)</li>", 
              version, 
              format(count, big.mark = ","),
              pct)
    })
    sprintf('
  <h2>Schema Distribution</h2>
  <div class="summary-box">
    <ul style="margin: 10px 0; padding-left: 20px;">
      %s
    </ul>
  </div>', paste(schema_items, collapse = "\n"))
  } else {
    ""
  }
  
  # ============================================================================
  # GENERATE HTML DOCUMENT
  # ============================================================================
  
  # Main HTML template
  html <- sprintf('
<!DOCTYPE html>
<html>
<head>
  <title>Validation Report - Workflow %s</title>
  <style>
    body { 
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; 
      max-width: 1100px; 
      margin: 40px auto; 
      padding: 20px;
      background: #f5f5f5;
    }
    h1 { 
      color: #2c3e50; 
      border-bottom: 3px solid #3498db; 
      padding-bottom: 15px; 
      margin-bottom: 20px;
    }
    h2 { 
      color: #34495e; 
      margin-top: 40px;
      margin-bottom: 20px;
      border-bottom: 2px solid #ecf0f1;
      padding-bottom: 10px;
    }
    .summary-box { 
      background: white; 
      border-left: 4px solid #3498db; 
      padding: 20px; 
      margin: 20px 0;
      border-radius: 4px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .warning { border-left-color: #f39c12; }
    .error { border-left-color: #e74c3c; }
    .success { border-left-color: #27ae60; }
    table { 
      border-collapse: collapse; 
      width: 100%%; 
      margin: 20px 0;
      background: white;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    th, td { 
      border: 1px solid #ddd; 
      padding: 12px; 
      text-align: left; 
    }
    th { 
      background: #34495e;
      color: white;
      font-weight: 600;
    }
    tr:nth-child(even) { background: #f8f9fa; }
    tr:hover { background: #e8f4f8; }
    .metric { 
      font-size: 32px; 
      font-weight: bold; 
      color: #2c3e50; 
      margin-bottom: 5px;
    }
    .label { 
      font-size: 11px; 
      color: #7f8c8d; 
      text-transform: uppercase;
      letter-spacing: 0.5px;
      font-weight: 600;
    }
    .grid { 
      display: grid; 
      grid-template-columns: repeat(4, 1fr); 
      gap: 20px; 
      margin: 20px 0; 
    }
    .card { 
      background: white; 
      padding: 25px; 
      border-radius: 8px; 
      text-align: center;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      transition: transform 0.2s;
    }
    .card:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    }
    .metric-details {
      margin-top: 12px;
      font-size: 0.85em;
      text-align: left;
    }
    .metric-details summary {
      cursor: pointer;
      color: #3498db;
      font-weight: 500;
      padding: 6px 10px;
      border-radius: 4px;
      transition: background-color 0.2s;
      display: inline-block;
    }
    .metric-details summary:hover {
      background-color: rgba(52, 152, 219, 0.1);
      text-decoration: underline;
    }
    .metric-details ul {
      list-style: none;
      padding: 10px 0 0 0;
      margin: 0;
    }
    .metric-details li {
      padding: 4px 0;
      color: #555;
      font-size: 12px;
    }
    details {
      margin-top: 5px;
    }
    summary {
      font-size: 12px;
      padding: 4px 0;
    }
    summary:hover {
      text-decoration: underline;
    }
    .header-info {
      background: white;
      padding: 20px;
      border-radius: 8px;
      margin-bottom: 30px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .header-info p {
      margin: 8px 0;
      color: #34495e;
    }
  </style>
</head>
<body>
  <h1>KPro Pipeline Validation Report</h1>
  
  <div class="header-info">
    <p><strong>Workflow:</strong> %s | <strong>Study:</strong> %s</p>
    <p><strong>Generated:</strong> %s | <strong>Pipeline Version:</strong> %s</p>
    <p><strong>Duration:</strong> %.1f seconds</p>
  </div>
  
  <h2>Summary Metrics</h2>
  <div class="grid">
    <div class="card">
      <div class="metric">%s</div>
      <div class="label">%s</div>
    </div>
    <div class="card">
      <div class="metric">%s</div>
      <div class="label">Rows Removed</div>
      %s
    </div>
    <div class="card">
      <div class="metric">%s</div>
      <div class="label">Duplicates</div>
    </div>
    <div class="card">
      <div class="metric">%s</div>
      <div class="label">Warnings</div>
    </div>
  </div>
  
  %s
  %s
  %s
  
  <h2>Validation Events</h2>
  <table>
    <tr>
      <th>Time</th>
      <th>Event Type</th>
      <th>Description</th>
      <th>Count</th>
    </tr>
    %s
  </table>
  
  <div class="summary-box %s">
    <strong>Pipeline Status:</strong> %s
  </div>
  
  <hr style="margin-top: 40px; border: none; border-top: 1px solid #ddd;">
  <p style="font-size: 11px; color: #7f8c8d; text-align: center;">
    Generated by KPro Masterfile Pipeline v%s
  </p>
</body>
</html>',
                  # Title
                  context$workflow,
                  # Header info
                  context$workflow,
                  context$study_name %||% "Unknown",
                  context$completed_utc,
                  context$pipeline_version,
                  context$duration_seconds,
                  # Summary metrics
                  format(context$summary$rows_processed, big.mark = ","),
                  rows_label,
                  format(context$summary$rows_removed, big.mark = ","),
                  rows_removed_breakdown,
                  format(context$summary$duplicates_detected, big.mark = ","),
                  context$summary$warnings,
                  # Optional sections
                  data_quality_section,
                  transformation_section,
                  schema_section,
                  # Events table
                  paste(event_rows, collapse = "\n"),
                  # Status box
                  if (context$summary$errors > 0) "error" 
                  else if (context$summary$warnings > 0) "warning" 
                  else "success",
                  if (context$summary$errors > 0) "Completed with errors" 
                  else if (context$summary$warnings > 0) "Completed with warnings" 
                  else "All validations passed",
                  # Footer
                  context$pipeline_version
  )
  
  writeLines(html, output_path)
}

# ==============================================================================


# =============================================================================
# ORCHESTRATOR HELPERS
# =============================================================================
# Convenience wrappers to reduce boilerplate in run_* orchestrating functions.
# These eliminate ~9 lines of initialization and ~7 lines of finalization code
# per stage, making orchestrators cleaner and more maintainable.
# =============================================================================


#' Initialize Stage Validation Context
#'
#' @description
#' Initializes validation context for a pipeline stage with study name
#' automatically populated. Consolidates validation initialization pattern
#' used across all orchestrating functions. Reduces ~2 lines of boilerplate
#' per stage.
#'
#' Standards Reference: 07_artifact_release_standards.md §3.2
#'
#' @param stage_name Character. Internal stage name for validation tracking
#'   (e.g., "finalize_cpn", "summary_stats", "exploratory_plots", "report_release").
#' @param study_params List. Loaded study parameters from load_study_parameters().
#'
#' @return List. Validation context with workflow and study_name populated,
#'   ready for log_validation_event() calls.
#'
#' @section CONTRACT:
#' - Creates validation context with create_validation_context()
#' - Populates study_name from study_params$study_parameters$study_name
#' - Uses %||% to provide "Unknown" if study_name is NULL
#' - Returns context ready for immediate use
#'
#' @section DOES NOT:
#' - Validate stage_name format
#' - Check if study_params is complete
#' - Log any events (context is empty)
#' - Create validation HTML
#'
#' @examples
#' \dontrun{
#' study_params <- load_study_parameters("inst/config/study_parameters.yaml")
#'
#' # Initialize for Finalize CPN stage
#' validation_context <- init_stage_validation("finalize_cpn", study_params)
#'
#' # Now ready to log events
#' validation_context <- log_validation_event(
#'   validation_context,
#'   event_type = "data_loaded",
#'   description = "Master data loaded",
#'   count = nrow(kpro_master)
#' )
#' }
#'
#' @export
init_stage_validation <- function(stage_name, study_params) {
  
  # Create validation context
  context <- create_validation_context(workflow = stage_name)
  
  # Populate study name from parameters (use %||% for null coalescing)
  context$study_name <- study_params$study_parameters$study_name %||% "Unknown"
  
  context
}


#' Complete Stage Validation and Save Report
#'
#' @description
#' Finalizes validation context and saves HTML report for a pipeline stage.
#' Consolidates validation finalization pattern used across all orchestrating
#' functions. Reduces ~7 lines of boilerplate per stage.
#'
#' Standards Reference: 07_artifact_release_standards.md §3.2
#'
#' @param validation_context List. Validation context to finalize.
#' @param validation_dir Character. Directory for validation HTML output.
#' @param stage_name Character. Display name for stage (e.g., "FINALIZE CPN",
#'   "SUMMARY STATISTICS"). Used in completion message.
#' @param verbose Logical. Print confirmation message to console? Default: FALSE.
#'
#' @return Character. Path to validation HTML file.
#'
#' @section CONTRACT:
#' - Calls finalize_validation_report() to generate HTML
#' - Prints confirmation message if verbose = TRUE
#' - ALWAYS logs completion message to file (regardless of verbose)
#' - Returns path to validation HTML for result list storage
#'
#' @section DOES NOT:
#' - Create validation_dir (finalize_validation_report handles this)
#' - Validate context completeness
#' - Add completion event to context
#' - Store result in result list (caller's responsibility)
#'
#' @examples
#' \dontrun{
#' # After logging all validation events for a stage
#' validation_html <- complete_stage_validation(
#'   validation_context_finalize_cpn,
#'   validation_dir = here::here("results", "validation"),
#'   stage_name = "FINALIZE CPN",
#'   verbose = TRUE
#' )
#'
#' # Returns path and prints:
#' #   [OK] Validation: validation_finalize_cpn_20250203_141530.html
#' # Logs: "=== FINALIZE CPN: COMPLETE ==="
#' }
#'
#' @export
complete_stage_validation <- function(validation_context,
                                      validation_dir,
                                      stage_name,
                                      verbose = FALSE) {
  
  # Finalize and save validation report
  validation_html <- finalize_validation_report(
    validation_context,
    output_dir = validation_dir
  )
  
  # Print confirmation if verbose
  if (verbose) {
    message(sprintf("  [OK] Validation: %s", basename(validation_html)))
  }
  
  # Always log completion (not gated by verbose)
  log_message(sprintf("=== %s: COMPLETE ===", toupper(stage_name)))
  
  validation_html
}


# ==============================================================================
# END OF VALIDATION REPORTING MODULE
# ==============================================================================