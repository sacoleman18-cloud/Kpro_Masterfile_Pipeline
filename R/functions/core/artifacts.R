# =============================================================================
# MODULE: artifacts.R - Artifact Registry & Provenance System
# =============================================================================
# PURPOSE
# -------
# Provides a formal artifact registry for tracking all pipeline outputs,
# including hashing for reproducibility verification and provenance tracking.
# Also provides comprehensive validation tracking with detailed HTML reports
# that capture dataset-specific operations and transformations.
#
# DEPENDENCIES
# ------------
# R Packages: 
#   - yaml:  Registry file I/O
#   - digest: SHA256 hashing
#   - here: Path management
#
# FUNCTIONS PROVIDED
# ------------------
# Registry Management:
#   - init_artifact_registry(): Create/load registry
#   - register_artifact(): Add artifact to registry
#   - get_artifact(): Retrieve artifact metadata
#   - list_artifacts(): List all artifacts (optionally filtered)
#   - get_latest_artifact(): Get most recent artifact by type
#
# Hashing: 
#   - hash_file(): Compute SHA256 of file
#   - hash_dataframe(): Compute hash of data frame
#   - verify_artifact(): Check if artifact matches registered hash
#
# Validation Tracking:
#   - create_validation_context(): Start validation tracking
#   - log_validation_event(): Record validation event
#   - finalize_validation_report(): Generate validation summary
#
# Internal Functions:
#   - generate_validation_html(): Create HTML report from context
#   - format_event_details(): Format event details as HTML
#
# USAGE
# -----
# # Initialize registry
# registry <- init_artifact_registry()
# 
# # Register artifacts
# register_artifact(registry, "kpro_master", "masterfile", "02", file_path)
# 
# # Validation tracking
# context <- create_validation_context(workflow = "01")
# context <- log_validation_event(context, "files_loaded", "Loaded CSVs", count = 5)
# report_path <- finalize_validation_report(context)
#
# VALIDATION EVENT TYPES
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
# Data Filters (NEW):
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
# CHANGELOG
# ---------
# 2026-01-30: Added filter_noid and filter_zero_pulses event tracking
# 2026-01-30: Enhanced Summary Metrics card with collapsible breakdown
# 2026-01-30: Added CSS styling for details/summary elements
# 2026-01-12: Enhanced HTML reports with collapsible details and workflow-specific sections
# 2026-01-12: Added additional summary metrics (files_loaded, schema_unknown, etc.)
# 2026-01-12: Initial version
# =============================================================================

library(yaml)
library(digest)
library(here)

# =============================================================================
# CONSTANTS
# =============================================================================

REGISTRY_PATH <- here::here("inst", "config", "artifact_registry.yaml")
PIPELINE_VERSION <- "2.1"

ARTIFACT_TYPES <- c(
  "raw_input",
  "checkpoint", 
  "masterfile",
  "cpn_template",
  "cpn_final",
  "summary_stats",
  "plot_objects",
  "report",
  "release_bundle",
  "validation_report"
)

# =============================================================================
# REGISTRY MANAGEMENT
# =============================================================================

#' Initialize or Load Artifact Registry
#'
#' @description
#' Creates a new artifact registry or loads an existing one. The registry
#' is a YAML file that tracks all pipeline artifacts with metadata. 
#'
#' @param registry_path Character. Path to registry file.  
#'   Defaults to inst/config/artifact_registry.yaml
#'
#' @return List. Registry object with artifacts and metadata.
#'
#' @section CONTRACT:
#' - Creates registry file if it doesn't exist
#' - Returns valid registry structure even if empty
#' - Never overwrites existing registry
#'
#' @section DOES NOT:
#' - Validate existing registry structure (assumes well-formed YAML)
#' - Create backups of registry file
#' - Handle concurrent access (not thread-safe)
#'
#' @export
init_artifact_registry <- function(registry_path = REGISTRY_PATH) {
  
  # Ensure directory exists
  registry_dir <- dirname(registry_path)
  if (!dir.exists(registry_dir)) {
    dir.create(registry_dir, recursive = TRUE)
  }
  
  # Load existing or create new
  if (file.exists(registry_path)) {
    registry <- yaml::read_yaml(registry_path)
    message(sprintf("[OK] Loaded artifact registry: %d artifacts", 
                    length(registry$artifacts)))
  } else {
    registry <- list(
      registry_version = "1.0",
      created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      pipeline_version = PIPELINE_VERSION,
      artifacts = list()
    )
    yaml::write_yaml(registry, registry_path)
    message("[OK] Created new artifact registry")
  }
  
  # Attach path for later saves
  attr(registry, "path") <- registry_path
  
  registry
}


#' Register an Artifact
#'
#' @description
#' Adds an artifact to the registry with full provenance metadata including
#' file hash, source workflow, and timestamps.
#'
#' @param registry List. Registry object from init_artifact_registry()
#' @param artifact_name Character. Unique name for this artifact
#' @param artifact_type Character. One of ARTIFACT_TYPES
#' @param workflow Character. Workflow that produced this (e.g., "01", "02")
#' @param file_path Character. Path to artifact file
#' @param input_artifacts Character vector. Names of input artifacts (for lineage)
#' @param metadata List. Additional metadata to store
#' @param quiet Logical. Suppress messages if TRUE
#'
#' @return List. Updated registry object (also saved to disk)
#'
#' @section CONTRACT:
#' - Computes SHA256 hash of file
#' - Adds timestamp and pipeline version
#' - Saves registry to disk
#' - Returns updated registry invisibly
#'
#' @section DOES NOT:
#' - Validate that input_artifacts exist in registry
#' - Check for duplicate artifact names (overwrites silently)
#' - Verify file format matches artifact type
#'
#' @export
register_artifact <- function(registry, 
                              artifact_name,
                              artifact_type,
                              workflow,
                              file_path,
                              input_artifacts = NULL,
                              metadata = list(),
                              quiet = FALSE) {
  
  # Validate artifact type
  if (!artifact_type %in% ARTIFACT_TYPES) {
    stop(sprintf(
      "Invalid artifact_type '%s'. Must be one of: %s",
      artifact_type,
      paste(ARTIFACT_TYPES, collapse = ", ")
    ))
  }
  
  # Validate file exists
  if (!file.exists(file_path)) {
    stop(sprintf("Artifact file not found: %s", file_path))
  }
  
  # Compute hash
  file_hash <- hash_file(file_path)
  
  # Build artifact entry
  artifact_entry <- list(
    name = artifact_name,
    type = artifact_type,
    workflow = workflow,
    file_path = file_path,
    file_hash_sha256 = file_hash,
    file_size_bytes = file.info(file_path)$size,
    created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    pipeline_version = PIPELINE_VERSION,
    input_artifacts = input_artifacts,
    metadata = metadata
  )
  
  # Add to registry
  registry$artifacts[[artifact_name]] <- artifact_entry
  registry$last_modified_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  
  # Save to disk
  registry_path <- attr(registry, "path")
  if (is.null(registry_path)) registry_path <- REGISTRY_PATH
  yaml::write_yaml(registry, registry_path)
  
  if (!quiet) {
    message(sprintf("[OK] Registered artifact: %s (%s)", artifact_name, artifact_type))
  }
  
  invisible(registry)
}


#' Get Artifact Metadata
#'
#' @description
#' Retrieves metadata for a specific artifact from the registry.
#'
#' @param registry List. Registry object
#' @param artifact_name Character. Name of artifact to retrieve
#'
#' @return List. Artifact metadata, or NULL if not found
#'
#' @section CONTRACT:
#' - Returns complete artifact metadata if found
#' - Returns NULL if artifact doesn't exist
#'
#' @export
get_artifact <- function(registry, artifact_name) {
  registry$artifacts[[artifact_name]]
}


#' List All Artifacts
#'
#' @description
#' Returns a data frame summary of all artifacts in the registry,
#' with optional filtering by type or workflow.
#'
#' @param registry List. Registry object
#' @param type Character. Optional filter by artifact type
#' @param workflow Character. Optional filter by workflow
#'
#' @return Data frame. Summary of matching artifacts
#'
#' @section CONTRACT:
#' - Returns empty data frame if no artifacts match
#' - Hash is truncated to first 8 characters for display
#' - Preserves chronological order from registry
#'
#' @export
list_artifacts <- function(registry, type = NULL, workflow = NULL) {
  
  if (length(registry$artifacts) == 0) {
    return(data.frame(
      name = character(),
      type = character(),
      workflow = character(),
      created_utc = character(),
      stringsAsFactors = FALSE
    ))
  }
  
  # Convert to data frame
  df <- purrr::map_dfr(registry$artifacts, function(a) {
    data.frame(
      name = a$name,
      type = a$type,
      workflow = a$workflow,
      created_utc = a$created_utc,
      file_path = a$file_path,
      file_hash = substr(a$file_hash_sha256, 1, 8),  # Truncated for display
      stringsAsFactors = FALSE
    )
  })
  
  # Apply filters
  if (!is.null(type)) {
    df <- df[df$type == type, ]
  }
  
  if (!is.null(workflow)) {
    df <- df[df$workflow == workflow, ]
  }
  
  df
}


#' Get Most Recent Artifact by Type
#'
#' @description
#' Finds and returns the most recently created artifact of a given type.
#'
#' @param registry List. Registry object
#' @param type Character. Artifact type to find
#'
#' @return List. Most recent artifact of that type, or NULL if none found
#'
#' @section CONTRACT:
#' - Sorts by created_utc timestamp (ISO 8601 format)
#' - Returns NULL if no artifacts of that type exist
#' - Only considers exact type matches
#'
#' @export
get_latest_artifact <- function(registry, type) {
  
  matching <- purrr::keep(registry$artifacts, ~ .x$type == type)
  
  if (length(matching) == 0) return(NULL)
  
  # Sort by created_utc descending
  sorted <- matching[order(sapply(matching, `[[`, "created_utc"), decreasing = TRUE)]
  
  sorted[[1]]
}


# =============================================================================
# HASHING FUNCTIONS
# =============================================================================

#' Compute SHA256 Hash of File
#'
#' @description
#' Computes a SHA256 hash of a file for integrity verification.
#'
#' @param file_path Character. Path to file
#'
#' @return Character. SHA256 hash string (64 hex characters)
#'
#' @section CONTRACT:
#' - Returns 64-character hexadecimal hash
#' - Hash is deterministic (same file -> same hash)
#' - Errors if file doesn't exist
#'
#' @export
hash_file <- function(file_path) {
  if (!file.exists(file_path)) {
    stop(sprintf("File not found: %s", file_path))
  }
  
  digest::digest(file_path, algo = "sha256", file = TRUE)
}


#' Compute Hash of Data Frame
#'
#' @description
#' Computes a content-based hash of a data frame, independent of
#' row order or attribute metadata.
#'
#' @param df Data frame
#' @param sort_by Character vector. Columns to sort by for deterministic order
#'
#' @return Character. SHA256 hash string
#'
#' @section CONTRACT:
#' - Hash is deterministic if sort_by is specified
#' - Ignores row names and attributes
#' - Only considers data content
#'
#' @section DOES NOT:
#' - Validate that sort_by columns exist
#' - Handle NA values specially in sorting
#'
#' @export
#' Verify Artifact Integrity
#'
#' @description
#' Checks if a file's current hash matches its registered hash.
#'
#' @param registry List. Registry object
#' @param artifact_name Character. Name of artifact to verify
#'
#' @return Logical. TRUE if hashes match, FALSE otherwise
#'
#' @section CONTRACT:
#' - Returns TRUE only if file exists and hash matches exactly
#' - Returns FALSE and warns if artifact not in registry
#' - Returns FALSE and warns if file missing or hash mismatch
#'
#' @export
verify_artifact <- function(registry, artifact_name) {
  
  artifact <- get_artifact(registry, artifact_name)
  
  if (is.null(artifact)) {
    warning(sprintf("Artifact not found in registry: %s", artifact_name))
    return(FALSE)
  }
  
  if (!file.exists(artifact$file_path)) {
    warning(sprintf("Artifact file not found: %s", artifact$file_path))
    return(FALSE)
  }
  
  current_hash <- hash_file(artifact$file_path)
  matches <- current_hash == artifact$file_hash_sha256
  
  if (!matches) {
    warning(sprintf(
      "Hash mismatch for %s:\n  Registered: %s\n  Current:    %s",
      artifact_name,
      artifact$file_hash_sha256,
      current_hash
    ))
  }
  
  matches
}


# =============================================================================
# VALIDATION TRACKING
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
  # Workflow 01: Ingestion (files -> rows)
  # Workflow 02: Transformation (input rows -> output rows)
  
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
  
  # Build data quality section (if workflow 01)
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
  
  # Build transformation section (if workflow 02)
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
# RDS DISCOVERY & VALIDATION
# ==============================================================================


#' Discover Pipeline RDS Files
#'
#' @description
#' Finds the most recent summary_data and plot_objects RDS files from 
#' Workflows 05-06. Returns paths and validation status.
#'
#' @param rds_dir Character. Path to RDS directory (usually results/rds/)
#'
#' @return List with:
#'   - valid: Logical. TRUE if both files found
#'   - summary_path: Character. Path to summary_data RDS (or NULL)
#'   - plots_path: Character. Path to plot_objects RDS (or NULL)
#'   - errors: Character vector. Error messages if any
#'
#' @section CONTRACT:
#' - Finds most recent files matching expected patterns
#' - Returns NULL for missing files (doesn't error)
#' - Provides clear error messages
#'
#' @section DOES NOT:
#' - Load or validate RDS contents (use validate_rds_structure)
#' - Create directories
#' - Search recursively
#'
#' @examples
#' \dontrun{
#' discovery <- discover_pipeline_rds(here::here("results", "rds"))
#' if (discovery$valid) {
#'   all_summaries <- readRDS(discovery$summary_path)
#'   all_plots <- readRDS(discovery$plots_path)
#' }
#' }
#'
#' @export
discover_pipeline_rds <- function(rds_dir) {
  
  errors <- character()
  
  # Check directory exists
  if (!dir.exists(rds_dir)) {
    return(list(
      valid = FALSE,
      summary_path = NULL,
      plots_path = NULL,
      errors = sprintf("RDS directory not found: %s", rds_dir)
    ))
  }
  
  # Find summary_data file
  summary_files <- list.files(
    rds_dir,
    pattern = "^summary_data_.*\\.rds$",
    full.names = TRUE
  )
  
  if (length(summary_files) == 0) {
    errors <- c(errors, 
                "No summary_data RDS file found. Did you run Workflow 05?")
    summary_path <- NULL
  } else {
    # Get most recent by modification time
    summary_times <- file.info(summary_files)$mtime
    summary_path <- summary_files[which.max(summary_times)]
  }
  
  # Find plot_objects file
  plots_files <- list.files(
    rds_dir,
    pattern = "^plot_objects_.*\\.rds$",
    full.names = TRUE
  )
  
  if (length(plots_files) == 0) {
    errors <- c(errors,
                "No plot_objects RDS file found. Did you run Workflow 06?")
    plots_path <- NULL
  } else {
    # Get most recent by modification time
    plots_times <- file.info(plots_files)$mtime
    plots_path <- plots_files[which.max(plots_times)]
  }
  
  list(
    valid = length(errors) == 0,
    summary_path = summary_path,
    plots_path = plots_path,
    errors = errors
  )
}


#' Validate RDS Structure
#'
#' @description
#' Validates that loaded RDS objects contain required elements for
#' report generation. Checks summary_data and plot_objects structure.
#'
#' @param all_summaries List. Summary data from Workflow 05
#' @param all_plots List. Plot objects from Workflow 06
#'
#' @return List with:
#'   - valid: Logical. TRUE if structure is valid
#'   - errors: Character vector. Error messages if any
#'   - warnings: Character vector. Warning messages if any
#'   - has_species: Logical. TRUE if species plots available
#'   - plot_counts: Named list. Count of plots per category
#'   - total_plots: Integer. Total number of plots
#'
#' @section CONTRACT:
#' - Validates presence of required elements
#' - Counts plots by category
#' - Detects optional species data
#' - Returns validation status (doesn't error)
#'
#' @section REQUIRED ELEMENTS:
#' Summary data must contain:
#'   - detector_summary
#'   - study_summary
#'   - metadata
#'
#' Plot objects must contain categories:
#'   - quality
#'   - detector
#'   - temporal
#'   - species (optional)
#'
#' @section DOES NOT:
#' - Validate plot object types
#' - Check data frame schemas
#' - Modify input objects
#'
#' @examples
#' \dontrun{
#' all_summaries <- readRDS("results/rds/summary_data_20260109.rds")
#' all_plots <- readRDS("results/rds/plot_objects_20260109.rds")
#' 
#' validation <- validate_rds_structure(all_summaries, all_plots)
#' if (!validation$valid) {
#'   stop(paste(validation$errors, collapse = "\n"))
#' }
#' }
#'
#' @export
validate_rds_structure <- function(all_summaries, all_plots) {
  
  errors <- character()
  warnings <- character()
  
  # -------------------------
  # Validate summary structure
  # -------------------------
  
  required_summary_names <- c("detector_summary", "study_summary", "metadata")
  missing_summaries <- setdiff(required_summary_names, names(all_summaries))
  
  if (length(missing_summaries) > 0) {
    errors <- c(errors, sprintf(
      "summary_data RDS missing required elements: %s",
      paste(missing_summaries, collapse = ", ")
    ))
  }
  
  # -------------------------
  # Validate plot structure
  # -------------------------
  
  required_plot_categories <- c("quality", "detector", "temporal")
  missing_plots <- setdiff(required_plot_categories, names(all_plots))
  
  if (length(missing_plots) > 0) {
    errors <- c(errors, sprintf(
      "plot_objects RDS missing required categories: %s",
      paste(missing_plots, collapse = ", ")
    ))
  }
  
  # -------------------------
  # Count plots by category
  # -------------------------
  
  plot_counts <- list()
  total_plots <- 0
  
  for (category in c("quality", "detector", "species", "temporal")) {
    if (!is.null(all_plots[[category]])) {
      count <- length(all_plots[[category]])
    } else {
      count <- 0
    }
    plot_counts[[category]] <- count
    total_plots <- total_plots + count
  }
  
  # -------------------------
  # Check for species data
  # -------------------------
  
  has_species <- !is.null(all_plots$species) && length(all_plots$species) > 0
  
  if (!has_species) {
    warnings <- c(warnings, "Species plots not available (no species data)")
  }
  
  # -------------------------
  # Return validation result
  # -------------------------
  
  list(
    valid = length(errors) == 0,
    errors = errors,
    warnings = warnings,
    has_species = has_species,
    plot_counts = plot_counts,
    total_plots = total_plots
  )
}

# ==============================================================================
# END OF FILE
# ==============================================================================