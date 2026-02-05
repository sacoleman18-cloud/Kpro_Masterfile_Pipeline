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
#   Stage 7: Format template for Excel (sort, datetime, formulas)
#   Stage 8: Save templates (ORIGINAL + EDIT_THIS), register artifacts
#   Stage 9: Render validation HTML
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
#   - Template sorted by Detector, then Night (groups nights per detector)
#   - DateTime columns formatted for Excel recognition
#   - RecordingHours as Excel formula for user editing
#
# DOES NOT:
#   - Calculate final metrics (that's Chunk 3)
#   - Modify global environment (returns results)
#   - Prompt for user input (uses parameters)
#
# DEPENDENCIES
# ------------
#   Custom functions (via load_all.R):
#     - config.R: load_study_parameters, get_schedule_config
#     - logging.R: initialize_pipeline_log, log_message
#     - console.R: print_stage_banner
#     - utilities.R: setup_pipeline_context, load_most_recent_checkpoint,
#                    generate_timestamped_filename, create_unified_species_column,
#                    log_stage_start, save_checkpoint_and_register, 
#                    finalize_stage_validation_report, safe_read_csv, %||%
#     - callspernight.R: generate_calls_per_night_template
#     - validation.R: log_validation_event, assert_columns_exist
#     - artifacts.R: (used internally by save_checkpoint_and_register)
#
# CHANGELOG
# ---------
# 2026-02-05: REFACTORING - Enhanced helper function utilization
#             - Added initialize_pipeline_log() at startup for proper log initialization
#             - Replaced all print_stage_header + log_message pairs with log_stage_start()
#             - Replaced manual CSV save + artifact registration with save_checkpoint_and_register()
#             - Replaced manual validation HTML finalization with finalize_stage_validation_report()
#             - Removed direct calls to assert_directory_exists (handled by helper functions)
#             - Savings: ~60 lines of boilerplate code
#             - Improved consistency across all orchestration modules
#             - Updated DEPENDENCIES section to reflect new helper functions
# 2026-02-02: CRITICAL FIX - Timezone handling in Night calculation (CallsPerNight accuracy)
#             - Stage 4 now forces timezone on DateTime_local using lubridate::force_tz()
#             - When CSV reloaded, POSIXct loses timezone → interpreted as UTC → wrong hours
#             - Changed logic to match legacy: hour < cutoff (was hour >= cutoff)
#             - Uses lubridate::as_date() with explicit timezone parameter
#             - Fixes systematic CallsPerNight count errors (calls assigned to wrong nights)
#             - Example: 22:00 CDT became 04:00 UTC, shifting Night by 1 day
#             - CallsPerNight counts now match legacy workflow exactly
#             - Restored proper template formatting for Excel
#             - Added Stage 7: Format Template for Excel (from legacy workflow)
#             - Sorts by Detector then Night (groups all nights per detector)
#             - Converts time strings to full DateTime format ("10/04/2025 06:00:00 PM")
#             - Replaces RecordingHours with Excel formula (=(VALUE(E2)-VALUE(D2))*24)
#             - Removes Warning column from final template
#             - Renumbered old Stages 7-8 to 8-9
#             - Updated header PROCESSING STAGES section
#             - Fixed artifact_type from "template" to "cpn_template" (correct enum)
#             - Template now matches legacy workflow output exactly
# 2026-02-01: Integrated new utility functions to eliminate code duplication
#             - Added setup_pipeline_context() for YAML/validation setup (saves ~20 lines)
#             - Added load_most_recent_checkpoint() for checkpoint loading (saves ~15 lines)
#             - Added get_schedule_config() for schedule extraction (saves ~18 lines)
#             - Added create_unified_species_column() for species logic (saves ~15 lines)
#             - Added generate_timestamped_filename() for timestamps (saves ~8 lines)
#             - Total savings: ~76 lines of boilerplate code
#             - Updated DEPENDENCIES section with new utilities
# 2026-02-01: CRITICAL BUG FIX - Removed call to undefined get_advanced_scheduling()
#             - Replaced with inline normalization of advanced_scheduling YAML value
#             - Fixed undefined variable references (advanced_scheduling -> is_advanced_scheduling)
#             - Fixed variable name consistency (recording_start -> recording_start_for_template)
#             - Ensures uniform_start/uniform_end are always set correctly from YAML with defaults
# 2026-01-31: Initial creation - merged WF03 logic into orchestrating function
# 2026-01-31: Added manual_id_file parameter for Shiny integration
# 2026-01-31: Removed interactive prompts, added structured return
# 2026-01-31: Standardized to verbose parameter pattern
# 2026-01-31: Fixed Stage 5 - removed invalid detectors/verbose parameters
# 2026-01-31: Fixed Stage 5 - pass schedule to generate_calls_per_night_template()
# 2026-01-31: Fixed Stage 6 - changed from "Apply" to "Verify" (schedule applied in Stage 5)
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
#' - Sorts template by Detector, then Night (groups nights per detector)
#' - Formats DateTime columns for Excel recognition
#' - Generates Excel formulas for RecordingHours calculation
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
  
  print_stage_banner("CPN TEMPLATE GENERATION", verbose = verbose)
  
  # Initialize pipeline log with header
  initialize_pipeline_log()
  log_message("=== CHUNK 2: Generate CallsPerNight Template - START ===")
  
  # ===========================================================================
  # STAGE 1: LOAD CONFIGURATION
  # ===========================================================================
  
  log_stage_start("1", "Load Configuration", verbose = verbose)
  
  # Use utility to setup pipeline context (DETERMINISTIC - no parameters)
  ctx <- setup_pipeline_context("cpn_template")
  study_params <- ctx$study_params
  validation_context <- ctx$validation_context
  yaml_path <- ctx$yaml_path
  checkpoint_dir <- ctx$checkpoint_dir
  outputs_dir <- ctx$outputs_dir
  
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
  
  # ===========================================================================
  # STAGE 2: LOAD MASTER DATA
  # ===========================================================================
  
  log_stage_start("2", "Load Master Data", verbose = verbose)
  
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
    
    kpro_master <- load_most_recent_checkpoint("02_kpro_master_.*\\.csv$")
    
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
  
  log_stage_start("3", "Species Column Integration", verbose = verbose)
  
  # Add manual_id column if missing (for consistency)
  if (!"manual_id" %in% names(kpro_master)) {
    kpro_master$manual_id <- NA_character_
    if (verbose) message("  [!] Added manual_id column (all NA)")
  }
  
  # Create unified species column using utility (DETERMINISTIC - no parameters)
  # Priority: manual_id > auto_id > "NoID"
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
  
  log_stage_start("4", "Calculate Study Nights", verbose = verbose)
  
  # Get timezone and recording start from YAML
  study_tz <- study_params$study_parameters$timezone %||% "America/Chicago"
  recording_start <- study_params$processing_options$recording_start %||% "18:00:00"
  cutoff_hour <- as.numeric(substr(recording_start, 1, 2))
  
  if (verbose) {
    message(sprintf("  [OK] Study timezone: %s", study_tz))
    message(sprintf("  [OK] Night cutoff hour: %02d:00:00", cutoff_hour))
    message(sprintf("  [OK] Rule: Calls before %02d:00 -> previous calendar day", cutoff_hour))
  }
  
  # Force timezone on DateTime_local to prevent CSV timezone loss issues
  # CRITICAL: When loaded from CSV, POSIXct loses timezone attribute and defaults to UTC
  # This causes hour extraction to be wrong (e.g., 22:00 CDT becomes 04:00 UTC)
  # Result: Calls assigned to wrong nights, breaking CallsPerNight counts
  kpro_master <- kpro_master %>%
    dplyr::mutate(
      # FIRST: Ensure DateTime has correct timezone attribute
      DateTime_local = lubridate::force_tz(DateTime_local, tzone = study_tz),
      
      # THEN: Calculate Night using timezone-aware date extraction
      # Rule: Calls BEFORE cutoff hour belong to PREVIOUS calendar day
      Night = dplyr::if_else(
        lubridate::hour(DateTime_local) < cutoff_hour,
        lubridate::as_date(DateTime_local, tz = study_tz) - 1,
        lubridate::as_date(DateTime_local, tz = study_tz)
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
    description = "Study nights aggregated with timezone-aware calculation",
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
    message(sprintf("  [OK] Total nights observed: %d", 
                    as.numeric(diff(night_range)) + 1))
    message(sprintf("  [OK] Aggregated %s detector-nights", 
                    format(n_detector_nights, big.mark = ",")))
  }
  
  log_message(sprintf("[Stage 4] Aggregated %d detector-nights (timezone: %s)", 
                      n_detector_nights, study_tz))
  
  # ===========================================================================
  # STAGE 5: GENERATE TEMPLATE GRID
  # ===========================================================================
  
  log_stage_start("5", "Generate Template Grid", verbose = verbose)
  
  # Get recording schedule configuration using utility (DETERMINISTIC)
  # Handles TRUE/FALSE/"yes"/"no" for detector_specific_schedules with FIXED defaults
  schedule <- get_schedule_config(study_params)
  recording_start_for_template <- schedule$recording_start
  recording_end <- schedule$recording_end
  is_advanced_scheduling <- schedule$detector_specific_schedules
  
  if (verbose) {
    message(sprintf("  [OK] recording_start: %s", recording_start_for_template))
    message(sprintf("  [OK] recording_end: %s", recording_end))
    message(sprintf("  [OK] detector_specific_schedules: %s (uniform=%s)", 
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
    start_date = as.character(start_date),
    end_date = as.character(end_date),
    uniform_start = template_uniform_start,
    uniform_end = template_uniform_end,
    schedule_file = NULL
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
  
  log_stage_start("6", "Verify Recording Schedule", verbose = verbose)
  
  # Schedule was already applied in Stage 5 by generate_calls_per_night_template()
  # This stage validates and reports the schedule configuration
  
  if (!is_advanced_scheduling) {
    # Uniform schedule was applied - verify columns exist
    if (!all(c("StartTime", "EndTime", "RecordingHours") %in% names(cpn_template))) {
      stop("Template missing expected schedule columns. Check generate_calls_per_night_template().")
    }
    
    if (verbose) {
      message(sprintf("  [OK] Uniform schedule applied: %s - %s",
                      recording_start_for_template, recording_end))
      
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
  # STAGE 7: FORMAT TEMPLATE FOR EXCEL
  # ===========================================================================
  
  log_stage_start("7", "Format Template for Excel", verbose = verbose)
  
  # Remove Warning column (not needed in final template)
  if ("Warning" %in% names(cpn_template)) {
    cpn_template <- cpn_template %>% dplyr::select(-Warning)
    if (verbose) message("  [OK] Removed Warning column")
  }
  
  # Sort by Detector (alphabetical), then Night (chronological)
  # This groups all nights for each detector together
  cpn_template <- cpn_template %>%
    dplyr::arrange(Detector, Night)
  
  if (verbose) message("  [OK] Sorted by Detector, then Night")
  
  # Convert StartTime/EndTime to full DateTime values with readable formatting
  # StartTime is on the Night date, EndTime is typically next morning
  study_tz <- study_params$study_parameters$timezone %||% "America/Chicago"
  
  cpn_template <- cpn_template %>%
    dplyr::mutate(
      # StartDateTime: Combine Night date with StartTime
      StartDateTime_temp = dplyr::if_else(
        !is.na(StartTime),
        as.POSIXct(paste(Night, StartTime), format = "%Y-%m-%d %H:%M:%S", tz = study_tz),
        as.POSIXct(NA)
      ),
      
      # EndDateTime: Combine with appropriate date
      # If EndTime < StartTime, it's on the next day (crossed midnight)
      EndDateTime_temp = dplyr::if_else(
        !is.na(EndTime) & !is.na(StartTime),
        dplyr::if_else(
          EndTime < StartTime,
          # Crossed midnight: EndTime is on next day
          as.POSIXct(paste(Night + 1, EndTime), format = "%Y-%m-%d %H:%M:%S", tz = study_tz),
          # Same day: EndTime is on Night date
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
  
  # Reorder columns: Detector, Night, CallsPerNight, StartDateTime, EndDateTime, RecordingHours
  # This maps to Excel columns: A, B, C, D, E, F
  cpn_template <- cpn_template %>%
    dplyr::select(Detector, Night, CallsPerNight, StartDateTime, EndDateTime, RecordingHours)
  
  # Replace RecordingHours with Excel formula
  # Excel will auto-recognize "10/04/2025 06:00:00 PM" format as datetime
  cpn_template <- cpn_template %>%
    dplyr::mutate(
      row_num = dplyr::row_number() + 1,  # +1 because row 1 is header
      RecordingHours = ifelse(
        !is.na(StartDateTime) & !is.na(EndDateTime),
        # Excel formula: Convert text to datetime, subtract, multiply by 24
        # Using VALUE() to ensure Excel treats as datetime even if stored as text
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
  
  log_stage_start("8", "Save Templates & Register", verbose = verbose)
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # Save ORIGINAL template (for tracking)
  original_filename <- generate_timestamped_filename("03_CallsPerNight_Template", suffix = "ORIGINAL")
  original_path <- here::here("outputs", original_filename)
  
  # Save and register ORIGINAL template
  artifact_id_original <- sub("\\.csv$", "", generate_timestamped_filename("cpn_template_original"))
  registry <- save_checkpoint_and_register(
    data = cpn_template,
    file_path = original_path,
    artifact_name = artifact_id_original,
    artifact_type = "cpn_template",
    workflow = "cpn_template",
    metadata = list(
      n_rows = nrow(cpn_template),
      n_detectors = length(detectors),
      n_nights = n_nights,
      template_type = "ORIGINAL",
      recording_schedule = is_advanced_scheduling
    ),
    verbose = verbose
  )
  
  if (verbose) message(sprintf("  [OK] Saved ORIGINAL: %s", basename(original_path)))
  
  # Save and register EDIT_THIS template (for user editing)
  edit_filename <- generate_timestamped_filename("03_CallsPerNight_Template", suffix = "EDIT_THIS")
  edit_path <- here::here("outputs", edit_filename)
  
  artifact_id_edit <- sub("\\.csv$", "", generate_timestamped_filename("cpn_template_edit"))
  registry <- save_checkpoint_and_register(
    data = cpn_template,
    file_path = edit_path,
    artifact_name = artifact_id_edit,
    artifact_type = "cpn_template",
    workflow = "cpn_template",
    metadata = list(
      n_rows = nrow(cpn_template),
      n_detectors = length(detectors),
      n_nights = n_nights,
      template_type = "EDIT_THIS",
      recording_schedule = is_advanced_scheduling
    ),
    verbose = verbose,
    registry = registry
  )
  
  if (verbose) message(sprintf("  [OK] Saved EDIT_THIS: %s", basename(edit_path)))
  
  # ===========================================================================
  # STAGE 9: RENDER VALIDATION HTML
  # ===========================================================================
  
  log_stage_start("9", "Render Validation Report", verbose = verbose)
  
  validation_context$summary$rows_processed <- nrow(cpn_template)
  validation_context$summary$n_detectors <- length(detectors)
  validation_context$summary$n_nights <- n_nights
  
  # Use helper function to finalize validation report
  validation_html_path <- finalize_stage_validation_report(
    validation_context,
    verbose = verbose,
    output_dir = here::here("results", "validation")
  )
  
  log_message(sprintf("[Stage 9] Validation report: %s", basename(validation_html_path)))
  
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
        start = recording_start_for_template,
        end = recording_end,
        detector_specific = is_advanced_scheduling
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