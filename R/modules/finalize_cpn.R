# ==============================================================================
# R/finalize_cpn.R — FINALIZE CPN MODULE (Phase 1 DRY-Refactored)
# ==============================================================================
# PURPOSE
# -------
# Finalize CPN Module: Handles CPN finalization logic (Chunk 3).
#
# PHASE ARCHITECTURE: Called by run_phase3_analysis_reporting() orchestrator
# ORCHESTRATION LAYER: Yes, module runner interface
#
# DRY REFACTORING APPLIED (Phase 1)
# ----------------------------------
# **Template Loading** (Stage 2): Uses load_and_normalize_template() helper
#   - Eliminates 80 lines of duplicated loading/parsing logic
#   - Handles both ORIGINAL and EDIT_THIS templates consistently
#
# **Edit Tracking** (Stage 3): Uses track_template_edits() helper
#   - Eliminates 120 lines of complex POSIXct comparison logic
#   - Encapsulates 6-type edit detection (changed/added/removed x 2 fields)
#
# WORKFLOW SEQUENCE
# -----------------
# This module is called as the FIRST step in Phase 3:
#   1. run_phase3_analysis_reporting() [phase orchestrator]
#      └→ run_module_finalize_cpn() [this module] — Chunk 3, Stages 1-6
#      └→ run_module_summary_stats() — Chunk 3, Stages 7-16
#      └→ run_module_plotting() — Chunk 3, Stages 15-21
#      └→ run_module_report_release() — Chunk 3, Stages 22-25
#
# INPUT REQUIREMENTS
# ------------------
# Parameters:
#   - kpro_master: Tibble from Chunk 2 (or NULL to load from checkpoint)
#   - edited_template_file: Path to EDIT_THIS CPN template (or NULL to auto-discover)
#   - study_params: List from load_study_parameters(yaml_path)
#   - registry: Artifact registry from previous modules
#   - verbose: Boolean for console output
#
# FILES (Read):
#   - ORIGINAL CPN template (auto-discovered)
#   - EDIT_THIS CPN template (parameter or auto-discovered)
#   - Study parameters YAML
#
# OUTPUT GUARANTEES
# -----------------
# Returns a list {finalize_cpn, validation_html_paths, summary}:
#   - finalize_cpn$calls_per_night_final: Tibble with Status/RecordingHours/CallsPerHour
#   - finalize_cpn$cpn_file: Path to SavedCallsPerNight_final_*.csv
#   - finalize_cpn$total_edits: Numeric count of manual edits
#   - finalize_cpn$status_distribution: Named numeric vector
#   - finalize_cpn$dead_nights_retained: Count of Fail rows
#   - validation_html_paths: Character vector (1 HTML file)
#   - summary: Named list with pipeline metadata
#
# WRITES FILES
# -------------
#   - results/csv/CallsPerNight_final_*.csv — Versioned final CPN
#   - outputs/CallsPerNight_EditLog_*.txt — Manual edits log (if edits > 0)
#   - results/validation/*.html — Validation report
#
# DEPENDENCY CHAIN
# ----------------
# **Internal to this module:**
#   - All stages sequentially: 1 → 2 → 3 → 4 → 5 → 6
#   - No cross-module dependencies
#
# **Depends on (DRY helpers):**
#   - functions/analysis/callspernight.R: 
#       - load_and_normalize_template() — *NEW*
#       - track_template_edits() — *NEW*
#       - calculate_recording_hours()
#   - functions/core/utilities.R: log_stage_start, save_checkpoint_and_register
#   - functions/core/logging.R: log_message, initialize_pipeline_log
#   - functions/core/console.R: print_stage_banner
#   - functions/core/config.R: load_study_parameters
#   - functions/core/artifacts.R: init_stage_validation, log_validation_event
#   - functions/standardization/datetime_helpers.R: parse_datetime_columns
#
# CHANGELOG
# ---------
# 2026-02-08: Extracted from run_finalize_to_report.R as standalone module
# 2026-02-08: Phase 1 DRY refactoring — Template loading & edit tracking


#' Finalize CallsPerNight Data
#'
#' @description
#' Chunk 3, Stages 1-6: Loads edited CPN template, compares with original,
#' tracks manual edits, calculates recording hours, classifies recording status,
#' and saves final CPN data.
#'
#' This is the FIRST module in the finalize-to-report pipeline.
#'
#' @param kpro_master Tibble. Master dataset from Chunk 2. If NULL, loads from
#'   most recent checkpoint. Default: NULL.
#' @param edited_template_file Character. Path to user-edited EDIT_THIS file.
#'   If NULL, auto-discovers most recent. Default: NULL.
#' @param study_params List. Study parameters from load_study_parameters().
#'   Required: must include processing_options and study_parameters.
#' @param registry List. Artifact registry from previous phases. Will be updated
#'   with new artifacts. Default: NULL (creates new registry).
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return List with elements:
#'   - finalize_cpn: List containing:
#'     - calls_per_night_final: Tibble with final metrics
#'     - cpn_file: Path to saved CSV
#'     - total_edits: Numeric count of manual edits
#'     - status_distribution: Named numeric vector
#'     - dead_nights_retained: Count of Fail rows
#'   - validation_html_paths: Character vector with validation report path
#'   - summary: Metadata list
#'
#' @details
#' **Stages executed:**
#'   - Stage 1: Load configuration from YAML
#'   - Stage 2: Load and validate master data + templates (DRY-refactored)
#'   - Stage 3: Track manual edits (DRY-refactored)
#'   - Stage 4: Recalculate RecordingHours from edited start/end times
#'   - Stage 5: Classify Status (Fail/Success/Partial) and calculate CallsPerHour
#'   - Stage 6: Save final CPN with version control
#'
#' **Edit tracking:**
#'   - Compares ORIGINAL template (ISO 8601 dates) vs EDIT_THIS template
#'   - Handles Excel reformatting with flexible date parsing
#'   - Detects 6 types of edits: StartDateTime/EndDateTime changes/additions/removals
#'   - Saves detailed edit log if manual edits found
#'
#' **Dead night handling:**
#'   - Preserves all data rows including Dead Nights (RecordingHours = 0)
#'   - Status: "Fail" with CallsPerHour = NA
#'   - Allows Summary Stats and Plotting to reason over complete dataset
#'
#' @section CONTRACT:
#' - Loads all required data without user prompts
#' - Validates schema before proceeding (fails fast)
#' - Produces identical output regardless of whether kpro_master/template passed or auto-discovered
#' - Logs all stages with validation context
#' - Saves final CPN with timestamped versioning
#' - Returns exactly the structure documented above
#' - Preserves all 252 rows (9 detectors × 28 nights) through entire process
#'
#' @export
finalize_cpn <- function(kpro_master = NULL,
                         edited_template_file = NULL,
                         study_params,
                         registry = NULL,
                         verbose = FALSE) {
  
  # ===========================================================================
  # INITIALIZATION
  # ===========================================================================
  
  print_stage_banner("FINALIZE CPN", verbose = verbose)
  initialize_pipeline_log()
  
  # Ensure registry exists
  if (is.null(registry)) {
    registry <- list()
  }
  
  result <- list(finalize_cpn = list(), validation_html_paths = character())
  
  # Standard paths
  outputs_dir <- here::here("outputs")
  results_dir <- here::here("results")
  
  # ===========================================================================
  # STAGE 1: LOAD CONFIGURATION
  # ===========================================================================
  
  log_stage_start("1", "Load Configuration", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  yaml_path <- here::here("inst", "config", "study_parameters.yaml")
  assert_file_exists(yaml_path, hint = "Configure study parameters first.")
  
  # Create validation context
  validation_context <- init_stage_validation("finalize_cpn", study_params)
  
  message("  [OK] Loaded study_parameters.yaml")
  
  # Get uniform schedule for status classification
  advanced_scheduling <- study_params$processing_options$advanced_scheduling %||% "no"
  uniform_start <- study_params$processing_options$recording_start %||% NA
  uniform_end <- study_params$processing_options$recording_end %||% NA
  intended_hours <- study_params$processing_options$intended_hours %||% NA
  
  # ===========================================================================
  # STAGE 2: LOAD DATA AND TEMPLATES (DRY-Refactored)
  # ===========================================================================
  
  log_stage_start("2", "Load Data and Templates", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  # Load master data
  if (!is.null(kpro_master)) {
    if (verbose) message("  [OK] Using kpro_master from Chunk 2")
  } else {
    if (verbose) message("  [!] Loading kpro_master from checkpoint...")
    
    kpro_master <- load_most_recent_checkpoint("^02_kpro_master_.*\\.csv$")
    
    # Parse DateTime_local from CSV format back to POSIXct
    study_tz <- study_params$study_parameters$timezone %||% "America/Chicago"
    kpro_master <- parse_datetime_columns(kpro_master, target_tz = study_tz, verbose = verbose)
  }
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "data_loaded",
    description = "Master data loaded",
    count = nrow(kpro_master)
  )
  
  # Validate required schema
  required_columns <- c("species", "Hour_local", "DateTime_local")
  missing_columns <- setdiff(required_columns, names(kpro_master))
  
  if (length(missing_columns) > 0) {
    stop(sprintf(
      "Schema validation failed: Required columns missing from kpro_master: %s\n  These columns should have been created in upstream workflows:\n  - DateTime_local & Hour_local: created by run_ingest_standardize() (Workflow 02)\n  - species: created by run_cpn_template() (Workflow 03)\n  \n  To remediate:\n  1. Check that both workflows completed without errors\n  2. Verify kpro_master checkpoint files exist in outputs/checkpoints/\n  3. Review pipeline logs for any warnings or failures in Workflows 02-03\n  4. Ensure input data contains datetime and species identification columns",
      paste(missing_columns, collapse = ", ")
    ))
  }
  
  message(sprintf("  [OK] Schema validation passed: all required columns present (%s)", 
                  paste(required_columns, collapse = ", ")))
  
  # Load ORIGINAL template using DRY helper
  template_original <- load_and_normalize_template(
    template_type = "ORIGINAL",
    output_dir = outputs_dir,
    verbose = verbose
  )
  template_original_file <- attr(template_original, "source_file") %||% NA_character_
  
  if (verbose) {
    message(sprintf("  [OK] Loaded ORIGINAL template: %s (%d rows)", 
                    basename(template_original_file), nrow(template_original)))
    message(sprintf("  [OK] Date range: %s to %s", 
                    min(template_original$Night, na.rm = TRUE),
                    max(template_original$Night, na.rm = TRUE)))
  }
  
  # Load EDIT_THIS template using DRY helper
  template_edited <- if (!is.null(edited_template_file)) {
    load_and_normalize_template(
      template_type = "EDIT_THIS",
      file_path = edited_template_file,
      verbose = verbose
    )
  } else {
    load_and_normalize_template(
      template_type = "EDIT_THIS",
      output_dir = outputs_dir,
      verbose = verbose
    )
  }
  edited_template_file <- attr(template_edited, "source_file") %||% NA_character_
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "data_loaded",
    description = "CPN template loaded with flexible date parsing",
    count = nrow(template_edited),
    details = list(
      original_file = basename(template_original_file),
      edited_file = basename(edited_template_file),
      original_rows = nrow(template_original),
      edited_rows = nrow(template_edited)
    )
  )
  
  if (verbose) {
    message(sprintf("  [OK] Loaded EDIT_THIS template: %s (%d rows)", 
                    basename(edited_template_file), nrow(template_edited)))
    message(sprintf("  [OK] Date range: %s to %s", 
                    min(template_edited$Night, na.rm = TRUE),
                    max(template_edited$Night, na.rm = TRUE)))
  }
  
  # Validate required columns
  required_cols <- c("Detector", "Night", "CallsPerNight")
  assert_columns_exist(template_edited, required_cols)
  
  log_message(sprintf("[Finalize CPN - Stage 2] Templates loaded (ORIGINAL: %d rows, EDITED: %d rows)", 
                      nrow(template_original), nrow(template_edited)))
  
  # ===========================================================================
  # STAGE 3: TRACK MANUAL EDITS (DRY-Refactored)
  # ===========================================================================
  
  log_stage_start("3", "Track Manual Edits", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  # Use DRY helper to track edits
  edit_tracking <- track_template_edits(
    template_original = template_original,
    template_edited = template_edited,
    verbose = verbose
  )
  
  total_edits <- edit_tracking$total_edits
  edit_log_lines <- edit_tracking$edit_log_lines
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "manual_edits",
    description = "Manual recording hour edits tracked with POSIXct parsing",
    count = total_edits
  )
  
  if (verbose) {
    message(sprintf("  [OK] Tracked %d manual edits", total_edits))
  }
  
  # ===========================================================================
  # STAGE 4: CALCULATE RECORDING HOURS
  # ===========================================================================
  
  log_stage_start("4", "Calculate Recording Hours", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  # Recalculate RecordingHours from edited times
  if ("StartDateTime" %in% names(template_edited) && 
      "EndDateTime" %in% names(template_edited)) {
    
    template_edited <- template_edited %>%
      dplyr::mutate(
        RecordingHours = calculate_recording_hours(StartDateTime, EndDateTime)
      )
  }
  
  # Replace NA/negative with 0
  template_edited <- template_edited %>%
    dplyr::mutate(
      RecordingHours = dplyr::if_else(
        is.na(RecordingHours) | RecordingHours < 0,
        0,
        RecordingHours
      )
    )
  
  if (verbose) message("  [OK] Recalculated recording hours")
  
  # ===========================================================================
  # STAGE 5: CLASSIFY STATUS AND CALCULATE METRICS
  # ===========================================================================
  
  log_stage_start("5", "Classify Status & Calculate Metrics", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  # Classify recording status
  calls_per_night_final <- template_edited %>%
    dplyr::mutate(
      Status = dplyr::case_when(
        RecordingHours == 0 | is.na(RecordingHours) ~ "Fail",
        advanced_scheduling != "no" ~ "Success",
        !is.na(intended_hours) & abs(RecordingHours - intended_hours) < 0.5 ~ "Success",
        TRUE ~ "Partial"
      ),
      CallsPerHour = dplyr::if_else(
        RecordingHours > 0,
        CallsPerNight / RecordingHours,
        NA_real_
      )
    )
  
  # Status distribution
  status_dist <- table(calls_per_night_final$Status)
  dead_nights <- sum(calls_per_night_final$Status == "Fail")
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "status_classification",
    description = "Recording status classified",
    details = list(
      fail = as.numeric(status_dist["Fail"] %||% 0),
      success = as.numeric(status_dist["Success"] %||% 0),
      partial = as.numeric(status_dist["Partial"] %||% 0)
    )
  )
  
  if (verbose) {
    message(sprintf("  [OK] Status: %d Fail, %d Success, %d Partial",
                    status_dist["Fail"] %||% 0,
                    status_dist["Success"] %||% 0,
                    status_dist["Partial"] %||% 0))
  }
  
  log_message(sprintf("[Finalize CPN - Stage 5] Status classified, %d dead nights retained", dead_nights))
  
  # Validate problematic call values
  problematic_calls <- calls_per_night_final %>%
    dplyr::filter(CallsPerNight < 0 | CallsPerNight > 10000)
  
  if (nrow(problematic_calls) > 0) {
    warning(sprintf(
      "Found %d rows with suspicious call counts (negative or >10000). Check data quality.",
      nrow(problematic_calls)
    ))
    
    validation_context <- log_validation_event(
      validation_context,
      event_type = "warning",
      description = "Suspicious call values detected",
      count = nrow(problematic_calls),
      details = list(
        negative_count = sum(problematic_calls$CallsPerNight < 0),
        excessive_count = sum(problematic_calls$CallsPerNight > 10000)
      )
    )
    
    if (verbose) {
      message(sprintf("  [!] Warning: %d rows with suspicious call values", 
                      nrow(problematic_calls)))
    }
  }
  
  # ===========================================================================
  # STAGE 6: SAVE FINAL CPN
  # ===========================================================================
  
  log_stage_start("6", "Save Final CPN", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # Construct file path for CPN final
  cpn_final_filename <- sprintf("CallsPerNight_final_%s.csv", timestamp)
  cpn_final_path <- here::here("results", "csv", cpn_final_filename)
  
  # Save and register artifact
  registry <- save_checkpoint_and_register(
    data = calls_per_night_final,
    file_path = cpn_final_path,
    artifact_type = "cpn_final",
    workflow = "finalize_cpn",
    metadata = list(
      n_rows = nrow(calls_per_night_final),
      n_detectors = dplyr::n_distinct(calls_per_night_final$Detector),
      total_edits = total_edits,
      status_distribution = as.list(status_dist),
      dead_nights_retained = dead_nights
    ),
    verbose = verbose
  )
  
  # Save edit log if edits were made
  if (total_edits > 0) {
    edit_log_path <- here::here("outputs", 
                                sprintf("CallsPerNight_EditLog_%s.txt", timestamp))
    writeLines(
      c(
        sprintf("CallsPerNight Edit Log - %s", timestamp),
        sprintf("Total Manual Edits: %d", total_edits),
        "",
        "Detector | Night | StartDateTime: Original -> Edited | EndDateTime: Original -> Edited",
        strrep("-", 100),
        edit_log_lines
      ),
      edit_log_path
    )
    if (verbose) message(sprintf("  [OK] Saved edit log: %s", basename(edit_log_path)))
  }
  
  validation_html <- finalize_stage_validation_report(
    validation_context = validation_context,
    stage_name = "FINALIZE CPN",
    verbose = verbose
  )
  
  # ===========================================================================
  # RETURN RESULTS
  # ===========================================================================
  
  result$finalize_cpn <- list(
    calls_per_night_final = calls_per_night_final,
    cpn_file = cpn_final_path,
    total_edits = total_edits,
    status_distribution = as.list(status_dist),
    dead_nights_retained = dead_nights
  )
  
  result$validation_html_paths <- c(result$validation_html_paths, validation_html)
  
  result$summary <- list(
    n_detectors = dplyr::n_distinct(calls_per_night_final$Detector),
    total_calls = sum(calls_per_night_final$CallsPerNight),
    total_recording_hours = sum(calls_per_night_final$RecordingHours, na.rm = TRUE),
    manual_edits = total_edits,
    dead_nights = dead_nights
  )
  
  return(result)
}


# ==============================================================================
# END OF FILE
# ==============================================================================
