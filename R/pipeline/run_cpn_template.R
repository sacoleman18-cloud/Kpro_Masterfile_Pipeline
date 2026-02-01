# ==============================================================================
# R/pipeline/run_cpn_template.R
# ==============================================================================
# PURPOSE
# -------
# Chunk 2 of 3 in the Shiny-driven pipeline. Orchestrates the CallsPerNight
# template generation process, creating a detector × night grid with
# pre-populated recording times for manual review and editing.
#
# PIPELINE POSITION
# -----------------
# Chunk 2 of 3 in the Shiny-driven pipeline:
#   run_ingest_standardize()  -> Chunk 1: Raw CSVs to kpro_master
#   run_cpn_template()        -> [THIS FUNCTION] Generate CPN template
#   run_finalize_to_report()  -> Chunk 3: Finalize CPN through Report
#
# DECISION POINTS (handled by Shiny app):
#   Before Chunk 2: User may export Master for Manual ID in Kaleidoscope
#   After Chunk 2: User may edit recording hours in CPN template (EDIT_THIS file)
#
# PROCESSING STAGES
# -----------------
#   Stage 1: Load configuration from study_parameters.yaml
#   Stage 2: Load or import kpro_master data
#   Stage 3: Optional Manual ID integration
#   Stage 4: Calculate study nights and aggregate calls
#   Stage 5: Generate detector × night template grid (with schedule)
#   Stage 6: Verify recording schedule configuration
#   Stage 7: Save templates (ORIGINAL + EDIT_THIS), register artifacts
#   Stage 8: Render validation HTML
#
# CONTRACT
# --------
# INPUTS:
#   - kpro_master tibble (from Chunk 1 result OR checkpoint)
#   - OR: Manually-ID'd CSV file (if user performed Manual ID step)
#   - inst/config/study_parameters.yaml (recording period, schedule)
#
# OUTPUTS:
#   - cpn_template tibble (in returned list)
#   - Original template: outputs/03_CallsPerNight_Template_ORIGINAL_YYYYMMDD_HHMMSS.csv
#   - Editable template: outputs/03_CallsPerNight_Template_EDIT_THIS_YYYYMMDD_HHMMSS.csv
#   - Validation HTML: results/validation/validation_cpn_template_YYYYMMDD_HHMMSS.html
#   - Artifact registry entries (2 templates)
#
# GUARANTEES:
#   - All paths use here::here()
#   - Silent by default (verbose = FALSE)
#   - No interactive prompts (manual_id_file parameter for Shiny)
#   - File logging always active via log_message()
#   - Returns structured list with all outputs
#   - Validation HTML rendered for user review
#   - Two-file system: ORIGINAL (tracking) + EDIT_THIS (user edits)
#
# DOES NOT:
#   - Calculate final metrics (that's Chunk 3)
#   - Modify global environment (returns results)
#   - Prompt for user input (uses parameters)
#
# DEPENDENCIES
# ------------
#   Custom functions (via load_all.R):
#     - config.R: load_study_parameters
#     - utilities.R: log_message, print_stage_header, safe_read_csv, %||%
#     - callspernight.R: generate_calls_per_night_template, apply_schedule
#     - validation.R: create_validation_context, log_validation_event,
#                     finalize_validation_report, assert_file_exists,
#                     assert_directory_exists, assert_not_empty, assert_columns_exist
#     - artifacts.R: init_artifact_registry, register_artifact
#
# CHANGELOG
# ---------
# 2026-01-31: Initial creation - merged WF03 logic into orchestrating function
# 2026-01-31: Added manual_id_file parameter for Shiny integration
# 2026-01-31: Removed interactive prompts, added structured return
# 2026-01-31: Standardized to verbose parameter pattern
# 2026-01-31: Fixed Stage 5 - removed invalid detectors/verbose parameters
# 2026-01-31: Fixed Stage 5 - pass schedule to generate_calls_per_night_template()
# 2026-01-31: Fixed Stage 6 - changed from "Apply" to "Verify" (schedule applied in Stage 5)
# 2026-01-31: Refactored to use get_advanced_scheduling() helper for YAML normalization
#
# ==============================================================================
#' Run CallsPerNight Template Generation
#'
#' @description
#' Chunk 2 of the KPro pipeline. Generates a detector × night grid template
#' for the CallsPerNight dataset. Pre-populates recording times from YAML
#' configuration if uniform schedule is specified. Creates both an ORIGINAL
#' template (for tracking) and an EDIT_THIS template (for user editing).
#'
#' All configuration is read from `inst/config/study_parameters.yaml`.
#' Optionally accepts a manually-ID'd master file if user performed species
#' identification in Kaleidoscope Pro between Chunks 1 and 2.
#'
#' @param kpro_master Tibble. Master dataset from Chunk 1. If NULL, will load
#'   from most recent checkpoint. Default: NULL.
#' @param manual_id_file Character. Path to manually-ID'd CSV file (optional).
#'   If provided, this file is loaded instead of using kpro_master parameter.
#'   File must contain manual_id column. Default: NULL.
#' @param verbose Logical. Print progress messages to console. Default: FALSE.
#'
#' @return Named list containing:
#'   \describe{
#'     \item{cpn_template}{Tibble. Detector × Night grid with recording times.}
#'     \item{kpro_master}{Tibble. Master data with unified species column.}
#'     \item{metadata}{List. Processing metadata including:
#'       \itemize{
#'         \item n_rows: Total rows in template
#'         \item n_detectors: Number of unique detectors
#'         \item detectors: Character vector of detector names
#'         \item n_nights: Number of study nights in period
#'         \item date_range: Character vector of start/end dates
#'         \item recording_schedule: List with start/end times
#'         \item manual_id_used: Logical indicating if manual ID file was used
#'         \item rows_removed_noid: Number of unidentifiable calls removed
#'         \item species_source: "auto_id", "manual_id", or "unified"
#'       }
#'     }
#'     \item{artifact_ids}{List. Artifact IDs for both templates.}
#'     \item{template_original_path}{Character. Path to ORIGINAL template CSV.}
#'     \item{template_edit_path}{Character. Path to EDIT_THIS template CSV.}
#'     \item{validation_html_path}{Character. Path to validation HTML report.}
#'   }
#'
#' @section CONTRACT:
#' - Reads configuration from inst/config/study_parameters.yaml
#' - Accepts kpro_master from Chunk 1 OR loads from checkpoint
#' - Optionally accepts manual_id_file for Manual ID workflow
#' - Calculates study nights using recording_start cutoff from YAML
#' - Creates unified species column (manual_id > auto_id priority)
#' - Removes only calls where BOTH auto_id AND manual_id are unidentifiable
#' - Pre-fills recording times if uniform schedule configured
#' - Always saves two templates: ORIGINAL and EDIT_THIS
#' - Always renders validation HTML
#' - Registers both templates in artifact_registry.yaml
#' - Returns structured list (does not modify global environment)
#'
#' @section STUDY NIGHT LOGIC:
#' Bat studies use "study nights" that span calendar day boundaries.
#' The Night cutoff is set to recording_start time from YAML.
#'
#' Rule: Calls before recording_start belong to PREVIOUS calendar day.
#'
#' Example (recording_start = "18:00:00"):
#' \itemize{
#'   \item 2024-10-25 22:30 (hour 22 >= 18) -> Night: 2024-10-25
#'   \item 2024-10-26 03:15 (hour 3 < 18) -> Night: 2024-10-25 (previous)
#'   \item 2024-10-26 18:00 (hour 18 >= 18) -> Night: 2024-10-26
#' }
#'
#' @section MANUAL ID WORKFLOW:
#' Users may manually review calls in Kaleidoscope Pro before running Chunk 2:
#' \enumerate{
#'   \item Run Chunk 1 -> exports kpro_master.csv
#'   \item Load into Kaleidoscope Pro
#'   \item Manually review, populate manual_id column
#'   \item Save updated file
#'   \item Run Chunk 2 with manual_id_file parameter
#' }
#'
#' NoID filtering removes row only if BOTH auto_id AND manual_id are unidentifiable.
#' Unidentifiable = NA, blank, "NoID", or "UNKNOWN".
#'
#' @section DOES NOT:
#' - Calculate final metrics (CallsPerHour, Status - that's Chunk 3)
#' - Modify global environment
#' - Prompt for user input (uses parameters)
#' - Skip checkpoint saving (always saves both templates)
#'
#' @section Error Handling:
#' Stops with actionable error message if:
#' \itemize{
#'   \item study_parameters.yaml not found
#'   \item Recording period not configured
#'   \item No kpro_master data available (parameter or checkpoint)
#'   \item Required columns missing from master data
#' }
#'
#' @examples
#' \dontrun{
#' # Standard usage (called by Shiny after Chunk 1)
#' result <- run_cpn_template(kpro_master = chunk1_result$kpro_master)
#'
#' # With manual ID file
#' result <- run_cpn_template(
#'   manual_id_file = "path/to/manually_reviewed.csv",
#'   verbose = TRUE
#' )
#'
#' # Load from checkpoint (no Chunk 1 result)
#' result <- run_cpn_template()
#'
#' # Access results
#' template <- result$cpn_template
#' result$metadata$n_nights
#' result$template_edit_path  # File user should edit
#' }
#'
#' @export
run_cpn_template <- function(kpro_master = NULL,
                             manual_id_file = NULL,
                             verbose = FALSE) {
  
  # ===========================================================================
  # SETUP
  # ===========================================================================
  
  log_message("=== CHUNK 2: Generate CallsPerNight Template - START ===")
  
  # Initialize validation context
  validation_context <- create_validation_context(workflow = "cpn_template")
  
  # Standard paths
  yaml_path <- here::here("inst", "config", "study_parameters.yaml")
  checkpoint_dir <- here::here("outputs", "checkpoints")
  outputs_dir <- here::here("outputs")
  
  # ===========================================================================
  # STAGE 1: LOAD CONFIGURATION
  # ===========================================================================
  
  if (verbose) print_stage_header("1", "Load Configuration")
  
  assert_file_exists(
    yaml_path,
    hint = "Configure study parameters in Shiny app first."
  )
  
  study_params <- load_study_parameters(yaml_path)
  if (verbose) message("  [OK] Loaded study_parameters.yaml")
  
  # Update validation context with study name
  validation_context$study_name <- study_params$study_parameters$study_name
  
  # Validate recording period
  if (is.null(study_params$study_parameters$start_date) ||
      is.null(study_params$study_parameters$end_date)) {
    stop(
      "Recording period not configured in study_parameters.yaml.\n",
      "  Add start_date and end_date in Shiny app configuration."
    )
  }
  
  start_date <- as.Date(study_params$study_parameters$start_date)
  end_date <- as.Date(study_params$study_parameters$end_date)
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "config_loaded",
    description = "Recording period configured",
    details = list(
      start_date = as.character(start_date),
      end_date = as.character(end_date),
      n_days = as.numeric(end_date - start_date) + 1
    )
  )
  
  log_message("[Stage 1] Configuration loaded")
  
  # ===========================================================================
  # STAGE 2: LOAD MASTER DATA
  # ===========================================================================
  
  if (verbose) print_stage_header("2", "Load Master Data")
  
  manual_id_used <- FALSE
  
  # Priority 1: Manual ID file (if provided)
  if (!is.null(manual_id_file) && file.exists(manual_id_file)) {
    
    if (verbose) message(sprintf("  [!] Loading Manual ID file: %s", basename(manual_id_file)))
    
    kpro_master <- safe_read_csv(manual_id_file)
    manual_id_used <- TRUE
    
    validation_context <- log_validation_event(
      validation_context,
      event_type = "data_loaded",
      description = "Manual ID file imported",
      count = nrow(kpro_master),
      details = list(
        source = "manual_id",
        file_path = manual_id_file,
        file_name = basename(manual_id_file)
      )
    )
    
    if (verbose) message(sprintf("  [OK] Loaded %s rows from manual ID file", 
                                 format(nrow(kpro_master), big.mark = ",")))
    
    # Priority 2: kpro_master parameter
  } else if (!is.null(kpro_master)) {
    
    if (verbose) message("  [OK] Using kpro_master from Chunk 1")
    
    validation_context <- log_validation_event(
      validation_context,
      event_type = "data_loaded",
      description = "Master data from memory",
      count = nrow(kpro_master),
      details = list(source = "chunk1_result")
    )
    
    # Priority 3: Load from checkpoint
  } else {
    
    if (verbose) message("  [!] Loading from most recent checkpoint...")
    
    assert_directory_exists(checkpoint_dir)
    
    checkpoint_files <- list.files(
      checkpoint_dir,
      pattern = "02_kpro_master_.*\\.csv$",
      full.names = TRUE
    )
    
    if (length(checkpoint_files) == 0) {
      stop(
        "No kpro_master data available.\n",
        "  Run Chunk 1 first or provide kpro_master parameter."
      )
    }
    
    # Get most recent
    checkpoint_file <- checkpoint_files[length(checkpoint_files)]
    kpro_master <- safe_read_csv(checkpoint_file)
    
    validation_context <- log_validation_event(
      validation_context,
      event_type = "data_loaded",
      description = "Master data from checkpoint",
      count = nrow(kpro_master),
      details = list(
        source = "checkpoint",
        file_path = checkpoint_file,
        file_name = basename(checkpoint_file)
      )
    )
    
    if (verbose) message(sprintf("  [OK] Loaded from: %s", basename(checkpoint_file)))
  }
  
  # Validate required columns
  required_cols <- c("Detector", "DateTime_local", "auto_id")
  assert_columns_exist(kpro_master, required_cols)
  
  log_message(sprintf("[Stage 2] Loaded master data: %d rows", nrow(kpro_master)))
  
  # ===========================================================================
  # STAGE 3: OPTIONAL MANUAL ID INTEGRATION
  # ===========================================================================
  
  if (verbose) print_stage_header("3", "Species Column Integration")
  
  # Add manual_id column if missing (for consistency)
  if (!"manual_id" %in% names(kpro_master)) {
    kpro_master$manual_id <- NA_character_
    if (verbose) message("  [!] Added manual_id column (all NA)")
  }
  
  # Create unified species column (manual_id takes priority)
  kpro_master <- kpro_master %>%
    dplyr::mutate(
      species = dplyr::case_when(
        # Priority 1: manual_id (if valid)
        !is.na(manual_id) & manual_id != "" & 
          manual_id != "NoID" & manual_id != "UNKNOWN" ~ manual_id,
        # Priority 2: auto_id (if valid)
        !is.na(auto_id) & auto_id != "" & 
          auto_id != "NoID" & auto_id != "UNKNOWN" ~ auto_id,
        # Fallback: NoID
        TRUE ~ "NoID"
      )
    )
  
  # Determine species source for metadata
  if (manual_id_used) {
    n_manual <- sum(!is.na(kpro_master$manual_id) & 
                      kpro_master$manual_id != "" & 
                      kpro_master$manual_id != "NoID" & 
                      kpro_master$manual_id != "UNKNOWN")
    species_source <- if (n_manual > 0) "unified" else "auto_id"
  } else {
    species_source <- "auto_id"
  }
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "column_added",
    description = "Unified species column created",
    details = list(
      source = species_source,
      manual_id_used = manual_id_used
    )
  )
  
  if (verbose) message(sprintf("  [OK] Species column created (source: %s)", species_source))
  
  # Filter unidentifiable calls (only if BOTH IDs are unidentifiable)
  n_before <- nrow(kpro_master)
  kpro_master <- kpro_master %>%
    dplyr::filter(species != "NoID")
  
  n_noid_removed <- n_before - nrow(kpro_master)
  
  if (n_noid_removed > 0) {
    validation_context <- log_validation_event(
      validation_context,
      event_type = "rows_removed",
      description = "Unidentifiable calls filtered",
      count = n_noid_removed,
      details = list(
        filter = "species == NoID (both auto_id AND manual_id unidentifiable)",
        rows_before = n_before,
        rows_after = nrow(kpro_master)
      )
    )
    
    if (verbose) {
      message(sprintf("  [OK] Removed %s unidentifiable calls", 
                      format(n_noid_removed, big.mark = ",")))
    }
  }
  
  log_message(sprintf("[Stage 3] Species integration: %d NoID removed", n_noid_removed))
  
  # ===========================================================================
  # STAGE 4: CALCULATE STUDY NIGHTS
  # ===========================================================================
  
  if (verbose) print_stage_header("4", "Calculate Study Nights")
  
  # Get recording_start from YAML for night cutoff
  recording_start <- study_params$processing_options$recording_start %||% "18:00:00"
  cutoff_hour <- as.numeric(substr(recording_start, 1, 2))
  
  # Apply study night logic
  kpro_master <- kpro_master %>%
    dplyr::mutate(
      Hour_local = lubridate::hour(DateTime_local),
      Night = dplyr::if_else(
        Hour_local >= cutoff_hour,
        as.Date(DateTime_local),
        as.Date(DateTime_local) - 1
      )
    )
  
  # Aggregate by Detector × Night
  calls_per_night_raw <- kpro_master %>%
    dplyr::group_by(Detector, Night) %>%
    dplyr::summarise(CallsPerNight = dplyr::n(), .groups = "drop")
  
  n_detector_nights <- nrow(calls_per_night_raw)
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "rows_processed",
    description = "Study nights aggregated",
    count = n_detector_nights,
    details = list(
      cutoff_hour = cutoff_hour,
      recording_start = recording_start,
      aggregation = "Detector × Night"
    )
  )
  
  if (verbose) {
    message(sprintf("  [OK] Aggregated %s detector-nights", 
                    format(n_detector_nights, big.mark = ",")))
  }
  
  log_message(sprintf("[Stage 4] Aggregated %d detector-nights", n_detector_nights))
  
  # ===========================================================================
  # STAGE 5: GENERATE TEMPLATE GRID
  # ===========================================================================
  # I RUN INTO ISSUES HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  # Error in apply_schedule(template, schedule_file, uniform_start, uniform_end) :    
  # Uniform StartTime and EndTime must be provided when schedule_file is NULL.   
  # Received: uniform_start = NULL, uniform_end = NULL   Please provide both in 
  # 'HH:MM:SS' format (e.g., '20:00:00') Called from: apply_schedule(template,
  # schedule_file, uniform_start, uniform_end)
  
  if (verbose) print_stage_header("5", "Generate Template Grid")
  
  # Extract recording schedule parameters using helpers for robust YAML handling
  recording_start_for_template <- study_params$processing_options$recording_start %||% "18:00:00"
  recording_end <- study_params$processing_options$recording_end %||% "07:00:00"
  is_advanced_scheduling <- get_advanced_scheduling(study_params)  # Normalized boolean
  
  if (verbose) {
    message(sprintf("  [OK] recording_start: %s", recording_start_for_template))
    message(sprintf("  [OK] recording_end: %s", recording_end))
    message(sprintf("  [OK] advanced_scheduling: %s (uniform=%s)", 
                    is_advanced_scheduling, !is_advanced_scheduling))
  }
  
  # Determine schedule parameters for template generation
  if (!is_advanced_scheduling) {
    # Uniform schedule - pass times to template function
    template_uniform_start <- recording_start_for_template
    template_uniform_end <- recording_end
  } else {
    # Advanced scheduling - pass NULL (template will have empty times)
    template_uniform_start <- NULL
    template_uniform_end <- NULL
  }
  
  # Generate template with schedule
  cpn_template <- generate_calls_per_night_template(
    master_data = kpro_master,
    start_date = as.character(start_date),  # Convert Date to character
    end_date = as.character(end_date),      # Convert Date to character
    uniform_start = template_uniform_start,
    uniform_end = template_uniform_end,
    schedule_file = NULL   # No custom schedule file
  )
  
  # Extract metadata for reporting (detectors extracted from template)
  detectors <- sort(unique(cpn_template$Detector))
  n_nights <- dplyr::n_distinct(cpn_template$Night)
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "rows_processed",
    description = "Template grid generated",
    count = nrow(cpn_template),
    details = list(
      n_detectors = length(detectors),
      n_nights = n_nights,
      total_cells = nrow(cpn_template)
    )
  )
  
  if (verbose) {
    message(sprintf("  [OK] Generated %d rows (%d detectors × %d nights)",
                    nrow(cpn_template), length(detectors), n_nights))
  }
  
  log_message(sprintf("[Stage 5] Template grid: %d rows", nrow(cpn_template)))
  
  # ===========================================================================
  # STAGE 6: VERIFY RECORDING SCHEDULE
  # ===========================================================================
  
  if (verbose) print_stage_header("6", "Verify Recording Schedule")
  
  # Schedule was already applied in Stage 5 by generate_calls_per_night_template()
  # This stage just validates and reports the schedule configuration
  
  if (advanced_scheduling == "no") {
    # Uniform schedule was applied - verify columns exist
    if (!all(c("StartTime", "EndTime", "RecordingHours") %in% names(cpn_template))) {
      stop("Template missing expected schedule columns. Check generate_calls_per_night_template().")
    }
    
    if (verbose) {
      message(sprintf("  [OK] Uniform schedule applied: %s - %s",
                      recording_start, recording_end))
      
      # Report on RecordingHours calculation
      hours_summary <- summary(cpn_template$RecordingHours)
      message(sprintf("  [OK] RecordingHours calculated: %.1f to %.1f hours",
                      hours_summary["Min."], hours_summary["Max."]))
    }
    
  } else {
    # Advanced scheduling - verify empty columns were created
    if (!all(c("StartDateTime", "EndDateTime", "RecordingHours") %in% names(cpn_template))) {
      stop("Template missing expected datetime columns for advanced scheduling.")
    }
    
    if (verbose) {
      message("  [!] Advanced scheduling mode - times must be filled manually")
      message(sprintf("  [!] User should edit: %s", 
                      "03_CallsPerNight_Template_EDIT_THIS_*.csv"))
    }
  }
  
  log_message("[Stage 6] Recording schedule verified")
  
  # ===========================================================================
  # STAGE 7: SAVE TEMPLATES & REGISTER
  # ===========================================================================
  
  if (verbose) print_stage_header("7", "Save Templates & Register")
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # Create output directory
  assert_directory_exists(outputs_dir, create = TRUE)
  
  # Save ORIGINAL template (for tracking)
  original_filename <- sprintf("03_CallsPerNight_Template_ORIGINAL_%s.csv", timestamp)
  original_path <- here::here("outputs", original_filename)
  readr::write_csv(cpn_template, original_path)
  
  if (verbose) message(sprintf("  [OK] Saved ORIGINAL: %s", basename(original_path)))
  
  # Save EDIT_THIS template (for user editing)
  edit_filename <- sprintf("03_CallsPerNight_Template_EDIT_THIS_%s.csv", timestamp)
  edit_path <- here::here("outputs", edit_filename)
  readr::write_csv(cpn_template, edit_path)
  
  if (verbose) message(sprintf("  [OK] Saved EDIT_THIS: %s", basename(edit_path)))
  
  # Register artifacts
  registry <- init_artifact_registry()
  
  artifact_id_original <- sprintf("cpn_template_original_%s", timestamp)
  registry <- register_artifact(
    registry = registry,
    artifact_name = artifact_id_original,
    artifact_type = "template",
    workflow = "cpn_template",
    file_path = original_path,
    metadata = list(
      n_rows = nrow(cpn_template),
      n_detectors = length(detectors),
      n_nights = n_nights,
      template_type = "ORIGINAL",
      recording_schedule = advanced_scheduling
    )
  )
  
  artifact_id_edit <- sprintf("cpn_template_edit_%s", timestamp)
  registry <- register_artifact(
    registry = registry,
    artifact_name = artifact_id_edit,
    artifact_type = "template",
    workflow = "cpn_template",
    file_path = edit_path,
    metadata = list(
      n_rows = nrow(cpn_template),
      n_detectors = length(detectors),
      n_nights = n_nights,
      template_type = "EDIT_THIS",
      recording_schedule = advanced_scheduling
    )
  )
  
  if (verbose) message("  [OK] Artifacts registered")
  
  log_message(sprintf("[Stage 7] Templates saved and registered"))
  
  # ===========================================================================
  # STAGE 8: RENDER VALIDATION HTML
  # ===========================================================================
  
  if (verbose) print_stage_header("8", "Render Validation Report")
  
  validation_context$summary$rows_processed <- nrow(cpn_template)
  validation_context$summary$n_detectors <- length(detectors)
  validation_context$summary$n_nights <- n_nights
  
  validation_dir <- here::here("results", "validation")
  assert_directory_exists(validation_dir, create = TRUE)
  
  validation_html_path <- finalize_validation_report(
    validation_context,
    output_dir = validation_dir
  )
  
  if (verbose) message(sprintf("  [OK] Validation report: %s", basename(validation_html_path)))
  
  log_message(sprintf("[Stage 8] Validation report: %s", basename(validation_html_path)))
  
  # ===========================================================================
  # RETURN
  # ===========================================================================
  
  log_message(sprintf("=== CHUNK 2 COMPLETE: %d rows, %d nights ===",
                      nrow(cpn_template), n_nights))
  
  if (verbose) {
    message("\n========================================")
    message("  CPN TEMPLATE GENERATION COMPLETE")
    message("========================================")
    message(sprintf("  Template rows: %s", format(nrow(cpn_template), big.mark = ",")))
    message(sprintf("  Detectors: %d", length(detectors)))
    message(sprintf("  Nights: %d", n_nights))
    message(sprintf("  EDIT THIS FILE: %s", basename(edit_path)))
    message(sprintf("  ORIGINAL (tracking): %s", basename(original_path)))
    message("========================================\n")
  }
  
  list(
    cpn_template = cpn_template,
    kpro_master = kpro_master,
    
    metadata = list(
      n_rows = nrow(cpn_template),
      n_detectors = length(detectors),
      detectors = detectors,
      n_nights = n_nights,
      date_range = c(as.character(start_date), as.character(end_date)),
      recording_schedule = list(
        start = recording_start,
        end = recording_end,
        advanced = advanced_scheduling
      ),
      manual_id_used = manual_id_used,
      rows_removed_noid = n_noid_removed,
      species_source = species_source
    ),
    
    artifact_ids = list(
      original = artifact_id_original,
      edit = artifact_id_edit
    ),
    template_original_path = original_path,
    template_edit_path = edit_path,
    validation_html_path = validation_html_path
  )
}
# ==============================================================================
# END OF FILE
# ==============================================================================