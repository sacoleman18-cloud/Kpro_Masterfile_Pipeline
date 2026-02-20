# ==============================================================================
# MODULE: cpn_template.R
# ==============================================================================
# 
# Classification: Processing Module
# Subtitle: CallsPerNight template generation with recording schedule integration
#
# Description:
# This module generates the CallsPerNight template grid (Detector × Night) with
# pre-populated recording times for manual review and editing. It handles
# optional Manual ID integration, calculates study nights with timezone-aware
# logic, and formats the template for Excel editing.
#
# Module Stages:
#   Stage 1: Load configuration from study_parameters.yaml
#   Stage 2: Load or import kpro_master data
#   Stage 3: Optional Manual ID integration and species column creation
#   Stage 4: Calculate study nights with timezone-aware aggregation
#   Stage 5: Generate detector × night template grid (with schedule)
#   Stage 6: Verify recording schedule configuration
#   Stage 7: Format template for Excel (sort, datetime, formulas)
#   Stage 8: Save templates (ORIGINAL + EDIT_THIS), register artifacts
#   Stage 9: Render validation HTML
#
# Data Flow:
#   Input:  kpro_master tibble (from standardization) or manual ID file
#   Output: CPN template grid ready for user editing in Excel
#
# Dependencies:
#   - R/functions/core/config.R (load_study_parameters, get_schedule_config)
#   - R/functions/core/orchestration_helpers.R (setup_pipeline_context, log_stage_start, load_most_recent_checkpoint)
#   - R/functions/analysis/callspernight.R (generate_calls_per_night_template)
#   - R/functions/standardization/standardization.R (create_unified_species_column)
#   - R/functions/validation/validation.R (assert_columns_exist, log_validation_event)
#
# Functions Provided:
#   - module_cpn_template(): Main module function (exported)
#     Used by: R/modules/module_runner.R (run_module_cpn_template)
#     Used by: R/pipeline/run_phase2_template_generation.R
#
# Last Modified: 2026-02-09
# Changelog:
#   2026-02-09: Updated dependencies to reference orchestration_helpers.R
#   2026-02-08: Created as part of pipeline modularization refactor
#
# ==============================================================================

#' Generate CallsPerNight Template
#'
#' @description
#' Module Stages 1-9: Generates CallsPerNight template grid with recording
#' schedule, handles optional Manual ID integration, and prepares Excel-ready
#' template files for user editing.
#'
#' @param kpro_master Tibble. Master data from standardization module (or NULL
#'   to load from checkpoint).
#' @param manual_id_file Character. Path to manually-ID'd CSV file (optional).
#'   If provided, this overrides kpro_master parameter.
#' @param study_params List. Study parameters from load_study_parameters().
#' @param verbose Logical. Whether to print detailed progress messages.
#'   Default FALSE (silent operation).
#'
#' @return Named list containing:
#'   \itemize{
#'     \item \code{cpn_template}: Tibble with CPN template grid
#'     \item \code{validation_html_paths}: Character vector of validation HTML paths
#'     \item \code{metadata}: List with template dimensions and configuration
#'     \item \code{template_edit_path}: Path to EDIT_THIS template file
#'     \item \code{template_original_path}: Path to ORIGINAL template file
#'     \item \code{artifact_ids}: Named list of registered artifact IDs (original/edit)
#'   }
#'
#' @examples
#' \dontrun{
#' standardize_result <- module_data_standardization(...)
#' result <- module_cpn_template(
#'   kpro_master = standardize_result$standardization$kpro_master,
#'   study_params = standardize_result$study_params,
#'   verbose = TRUE
#' )
#' cpn_template <- result$cpn_template
#' }
#'
#' @export
module_cpn_template <- function(kpro_master = NULL,
                                manual_id_file = NULL,
                                study_params = NULL,
                                verbose = FALSE) {
  
  # ===========================================================================
  # INITIALIZATION
  # ===========================================================================
  
  print_stage_banner("CPN TEMPLATE GENERATION", verbose = verbose)
  
  result <- list(
    cpn_template = NULL,
    validation_html_paths = character(),
    metadata = list()
  )
  
  # ===========================================================================
  # STAGE 1: LOAD CONFIGURATION
  # ===========================================================================
  
  log_stage_start("1", "Load Configuration", verbose = verbose,
                  phase_prefix = "CPN Template")
  
  # Setup pipeline context (if not provided)
  if (is.null(study_params)) {
    ctx <- setup_pipeline_context("cpn_template")
    study_params <- ctx$study_params
    validation_context <- ctx$validation_context
  } else {
    validation_context <- init_stage_validation("cpn_template", study_params)
  }
  
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
  
  # Get study timezone for parsing datetime columns from CSV
  study_tz <- study_params$study_parameters$timezone %||% "America/Chicago"
  
  log_message(sprintf("[Stage 1] Configuration loaded: %s to %s",
                      start_date, end_date))
  
  # ===========================================================================
  # STAGE 2: LOAD MASTER DATA
  # ===========================================================================
  
  log_stage_start("2", "Load Master Data", verbose = verbose,
                  phase_prefix = "CPN Template")
  
  manual_id_used <- FALSE
  
  # Priority 1: Manual ID file (if provided)
  if (!is.null(manual_id_file) && file.exists(manual_id_file)) {
    
    if (verbose) message(sprintf("  [!] Loading Manual ID file: %s", basename(manual_id_file)))
    
    kpro_master <- safe_read_csv(manual_id_file)
    
    # Parse DateTime_local from CSV format back to POSIXct
    kpro_master <- parse_datetime_columns(kpro_master, target_tz = study_tz, verbose = verbose)
    
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
    
  } else if (!is.null(kpro_master)) {
    # Priority 2: kpro_master parameter
    if (verbose) message("  [OK] Using kpro_master from previous module")
    
    validation_context <- log_validation_event(
      validation_context,
      event_type = "data_loaded",
      description = "Master data from memory",
      count = nrow(kpro_master),
      details = list(source = "module_result")
    )
    
  } else {
    # Priority 3: Load from checkpoint
    if (verbose) message("  [!] Loading from most recent checkpoint...")
    
    kpro_master <- load_most_recent_checkpoint("02_kpro_master_.*\\.csv$")
    
    # Parse DateTime_local from CSV format back to POSIXct
    kpro_master <- parse_datetime_columns(kpro_master, target_tz = study_tz, verbose = verbose)
    
    validation_context <- log_validation_event(
      validation_context,
      event_type = "data_loaded",
      description = "Master data from checkpoint",
      count = nrow(kpro_master),
      details = list(source = "checkpoint")
    )
    
    if (verbose) message("  [OK] Loaded from checkpoint")
  }
  
  # Validate required columns
  required_cols <- c("Detector", "DateTime_local", "auto_id")
  assert_columns_exist(kpro_master, required_cols)
  
  log_message(sprintf("[Stage 2] Loaded master data: %d rows", nrow(kpro_master)))
  
  # ===========================================================================
  # STAGE 3: OPTIONAL MANUAL ID INTEGRATION
  # ===========================================================================
  
  log_stage_start("3", "Species Column Integration", verbose = verbose,
                  phase_prefix = "CPN Template")
  
  # Add manual_id column if missing (for consistency)
  if (!"manual_id" %in% names(kpro_master)) {
    kpro_master$manual_id <- NA_character_
    if (verbose) message("  [!] Added manual_id column (all NA)")
  }
  
  # Create unified species column using utility
  kpro_master <- create_unified_species_column(kpro_master)
  
  if (verbose) message("  [OK] Created unified species column")
  
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
        filter = "species == NoID",
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
  
  log_stage_start("4", "Calculate Study Nights", verbose = verbose,
                  phase_prefix = "CPN Template")
  
  # Get recording start from YAML
  recording_start <- study_params$processing_options$recording_start %||% "18:00:00"
  cutoff_hour <- as.numeric(substr(recording_start, 1, 2))
  
  if (verbose) {
    message(sprintf("  [OK] Study timezone: %s", study_tz))
    message(sprintf("  [OK] Night cutoff hour: %02d:00:00", cutoff_hour))
    message(sprintf("  [OK] Rule: Calls before %02d:00 -> previous calendar day", cutoff_hour))
  }
  
  # Force timezone on DateTime_local to prevent CSV timezone loss issues
  kpro_master <- kpro_master %>%
    dplyr::mutate(
      DateTime_local = lubridate::force_tz(DateTime_local, tzone = study_tz),
      
      # Calculate Night using timezone-aware date extraction
      Night = dplyr::if_else(
        lubridate::hour(DateTime_local) < cutoff_hour,
        lubridate::as_date(DateTime_local, tz = study_tz) - 1,
        lubridate::as_date(DateTime_local, tz = study_tz)
      )
    )

  # Save updated kpro_master checkpoint with species + Night for Phase 3
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  kpro_master_checkpoint <- here::here("outputs", "checkpoints",
                                       sprintf("02_kpro_master_%s.csv", timestamp))

  registry <- save_checkpoint_and_register(
    data = kpro_master,
    file_path = kpro_master_checkpoint,
    artifact_type = "checkpoint",
    phase_id = "cpn_template",
    metadata = list(
      n_rows = nrow(kpro_master),
      n_species = dplyr::n_distinct(kpro_master$species),
      n_nights = dplyr::n_distinct(kpro_master$Night),
      species_source = species_source,
      manual_id_used = manual_id_used,
      noid_removed = n_noid_removed,
      stage = "04_calculate_study_nights",
      checkpoint_name = "02_kpro_master"
    ),
    verbose = verbose
  )

  if (verbose) {
    message(sprintf("  [OK] Saved updated kpro_master checkpoint: %s", basename(kpro_master_checkpoint)))
  }
  
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
      timezone = study_tz,
      aggregation = "Detector × Night"
    )
  )
  
  if (verbose) {
    night_range <- range(kpro_master$Night, na.rm = TRUE)
    message(sprintf("  [OK] Night range: %s to %s", night_range[1], night_range[2]))
    message(sprintf("  [OK] Aggregated %s detector-nights", 
                    format(n_detector_nights, big.mark = ",")))
  }
  
  log_message(sprintf("[Stage 4] Aggregated %d detector-nights", n_detector_nights))
  
  # ===========================================================================
  # STAGE 5: GENERATE TEMPLATE GRID
  # ===========================================================================
  
  log_stage_start("5", "Generate Template Grid", verbose = verbose,
                  phase_prefix = "CPN Template")
  
  # Get recording schedule configuration
  schedule <- get_schedule_config(study_params)
  recording_start_for_template <- schedule$recording_start
  recording_end <- schedule$recording_end
  is_advanced_scheduling <- schedule$detector_specific_schedules
  
  if (verbose) {
    message(sprintf("  [OK] recording_start: %s", recording_start_for_template))
    message(sprintf("  [OK] recording_end: %s", recording_end))
    message(sprintf("  [OK] detector_specific_schedules: %s", is_advanced_scheduling))
  }
  
  # Determine schedule parameters for template generation
  if (!is_advanced_scheduling) {
    template_uniform_start <- recording_start_for_template
    template_uniform_end <- recording_end
  } else {
    template_uniform_start <- NULL
    template_uniform_end <- NULL
  }
  
  # Generate template with schedule
  cpn_template <- generate_calls_per_night_template(
    master_data = kpro_master,
    start_date = as.character(start_date),
    end_date = as.character(end_date),
    uniform_start = template_uniform_start,
    uniform_end = template_uniform_end,
    schedule_file = NULL
  )
  
  # Extract metadata
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
  
  log_stage_start("6", "Verify Recording Schedule", verbose = verbose,
                  phase_prefix = "CPN Template")
  
  if (!is_advanced_scheduling) {
    # Uniform schedule was applied
    if (!all(c("StartTime", "EndTime", "RecordingHours") %in% names(cpn_template))) {
      stop("Template missing expected schedule columns.")
    }
    
    if (verbose) {
      message(sprintf("  [OK] Uniform schedule applied: %s - %s",
                      recording_start_for_template, recording_end))
    }
  } else {
    # Advanced scheduling
    if (!all(c("StartDateTime", "EndDateTime", "RecordingHours") %in% names(cpn_template))) {
      stop("Template missing expected datetime columns for advanced scheduling.")
    }
    
    if (verbose) {
      message("  [!] Advanced scheduling mode - times must be filled manually")
    }
  }
  
  log_message("[Stage 6] Recording schedule verified")
  
  # ===========================================================================
  # STAGE 7: FORMAT TEMPLATE FOR EXCEL
  # ===========================================================================
  
  log_stage_start("7", "Format Template for Excel", verbose = verbose,
                  phase_prefix = "CPN Template")
  
  # Remove Warning column
  if ("Warning" %in% names(cpn_template)) {
    cpn_template <- cpn_template %>% dplyr::select(-Warning)
    if (verbose) message("  [OK] Removed Warning column")
  }
  
  # Sort by Detector, then Night
  cpn_template <- cpn_template %>%
    dplyr::arrange(Detector, Night)
  
  if (verbose) message("  [OK] Sorted by Detector, then Night")
  
  # Convert StartTime/EndTime to full DateTime values
  cpn_template <- cpn_template %>%
    dplyr::mutate(
      # StartDateTime: Combine Night date with StartTime
      StartDateTime_temp = dplyr::if_else(
        !is.na(StartTime),
        as.POSIXct(paste(Night, StartTime), format = "%Y-%m-%d %H:%M:%S", tz = study_tz),
        as.POSIXct(NA)
      ),
      
      # EndDateTime: Handle midnight crossing
      EndDateTime_temp = dplyr::if_else(
        !is.na(EndTime) & !is.na(StartTime),
        dplyr::if_else(
          EndTime < StartTime,
          as.POSIXct(paste(Night + 1, EndTime), format = "%Y-%m-%d %H:%M:%S", tz = study_tz),
          as.POSIXct(paste(Night, EndTime), format = "%Y-%m-%d %H:%M:%S", tz = study_tz)
        ),
        as.POSIXct(NA)
      ),
      
      # Format as readable text: "10/04/2025 06:00:00 PM"
      StartDateTime = dplyr::if_else(
        !is.na(StartDateTime_temp),
        format(StartDateTime_temp, "%m/%d/%Y %I:%M:%S %p"),
        NA_character_
      ),
      
      EndDateTime = dplyr::if_else(
        !is.na(EndDateTime_temp),
        format(EndDateTime_temp, "%m/%d/%Y %I:%M:%S %p"),
        NA_character_
      )
    ) %>%
    dplyr::select(-StartTime, -EndTime, -StartDateTime_temp, -EndDateTime_temp)
  
  if (verbose) message("  [OK] Converted to full DateTime format")
  
  # Reorder columns
  cpn_template <- cpn_template %>%
    dplyr::select(Detector, Night, CallsPerNight, StartDateTime, EndDateTime, RecordingHours)
  
  # Replace RecordingHours with Excel formula
  cpn_template <- cpn_template %>%
    dplyr::mutate(
      row_num = dplyr::row_number() + 1,
      RecordingHours = ifelse(
        !is.na(StartDateTime) & !is.na(EndDateTime),
        sprintf("=(VALUE(E%d)-VALUE(D%d))*24", row_num, row_num),
        NA_character_
      )
    ) %>%
    dplyr::select(-row_num)
  
  if (verbose) message("  [OK] Added Excel formulas for RecordingHours")
  
  log_message("[Stage 7] Template formatted for Excel")
  
  # ===========================================================================
  # STAGE 8: SAVE TEMPLATES & REGISTER
  # ===========================================================================
  
  log_stage_start("8", "Save Templates & Register", verbose = verbose,
                  phase_prefix = "CPN Template")
  
  # Save ORIGINAL template
  original_filename <- generate_timestamped_filename("03_CallsPerNight_Template", suffix = "ORIGINAL")
  original_path <- here::here("outputs", original_filename)
  
  artifact_id_original <- sub("\\.csv$", "", generate_timestamped_filename("cpn_template_original"))
  registry <- save_checkpoint_and_register(
    data = cpn_template,
    file_path = original_path,
    artifact_name = artifact_id_original,
    artifact_type = "cpn_template",
    phase_id = "cpn_template",
    metadata = list(
      n_rows = nrow(cpn_template),
      n_detectors = length(detectors),
      n_nights = n_nights,
      template_type = "ORIGINAL"
    ),
    verbose = verbose
  )
  
  if (verbose) message(sprintf("  [OK] Saved ORIGINAL: %s", basename(original_path)))
  
  # Save EDIT_THIS template
  edit_filename <- generate_timestamped_filename("03_CallsPerNight_Template", suffix = "EDIT_THIS")
  edit_path <- here::here("outputs", edit_filename)
  
  artifact_id_edit <- sub("\\.csv$", "", generate_timestamped_filename("cpn_template_edit"))
  registry <- save_checkpoint_and_register(
    data = cpn_template,
    file_path = edit_path,
    artifact_name = artifact_id_edit,
    artifact_type = "cpn_template",
    phase_id = "cpn_template",
    metadata = list(
      n_rows = nrow(cpn_template),
      n_detectors = length(detectors),
      n_nights = n_nights,
      template_type = "EDIT_THIS"
    ),
    verbose = verbose,
    registry = registry
  )
  
  if (verbose) message(sprintf("  [OK] Saved EDIT_THIS: %s", basename(edit_path)))
  
  log_message("[Stage 8] Templates saved and registered")
  
  # ===========================================================================
  # STAGE 9: RENDER VALIDATION HTML
  # ===========================================================================
  
  log_stage_start("9", "Render Validation Report", verbose = verbose,
                  phase_prefix = "CPN Template")
  
  validation_context$summary$rows_processed <- nrow(cpn_template)
  validation_context$summary$n_detectors <- length(detectors)
  validation_context$summary$n_nights <- n_nights
  
  validation_html_path <- finalize_stage_validation_report(
    validation_context,
    stage_name = "CPN TEMPLATE GENERATION",
    verbose = verbose,
    output_dir = here::here("results", "validation")
  )
  
  log_message(sprintf("[Stage 9] Validation report: %s", basename(validation_html_path)))
  
  # ===========================================================================
  # FINALIZATION
  # ===========================================================================
  
  if (verbose) {
    message("\n========================================")
    message("  CPN TEMPLATE GENERATION COMPLETE")
    message("========================================")
    message(sprintf("  Template rows: %s", format(nrow(cpn_template), big.mark = ",")))
    message(sprintf("  Detectors: %d", length(detectors)))
    message(sprintf("  Nights: %d", n_nights))
    message(sprintf("  EDIT THIS FILE: %s", basename(edit_path)))
    message("========================================\n")
  }
  
  result$cpn_template <- cpn_template
  result$kpro_master <- kpro_master  # Updated with species column for Phase 3
  result$validation_html_paths <- c(validation_html_path)
  result$metadata <- list(
    n_rows = nrow(cpn_template),
    n_detectors = length(detectors),
    detectors = detectors,
    n_nights = n_nights,
    date_range = c(as.character(start_date), as.character(end_date)),
    recording_schedule = list(
      start = recording_start_for_template,
      end = recording_end,
      detector_specific = is_advanced_scheduling
    ),
    manual_id_used = manual_id_used,
    rows_removed_noid = n_noid_removed,
    species_source = species_source
  )
  result$template_original_path <- original_path
  result$template_edit_path <- edit_path
  result$artifact_ids <- list(
    original = artifact_id_original,
    edit = artifact_id_edit
  )
  
  return(result)
}


# ==============================================================================
# END OF FILE
# ==============================================================================
