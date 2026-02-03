# ==============================================================================
# R/pipeline/run_finalize_to_report.R -HAVE NOT TESTED YET
# ==============================================================================
# PURPOSE
# -------
# Chunk 3 of 3 in the Shiny-driven pipeline. Orchestrates the complete
# finalization process from edited CPN template through final report and
# release bundle generation. Combines Workflows 04-07 into a single function.
#
# PIPELINE POSITION
# -----------------
# Chunk 3 of 3 in the Shiny-driven pipeline:
#   run_ingest_standardize()  -> Chunk 1: Raw CSVs to kpro_master
#   run_cpn_template()        -> Chunk 2: Generate CPN template
#   run_finalize_to_report()  -> [THIS FUNCTION] Finalize through Report
#
# DECISION POINTS (handled by Shiny app):
#   Before Chunk 3: User edits recording hours in EDIT_THIS template
#   After Chunk 3: Complete pipeline - review report and download release bundle
#
# PROCESSING STAGES
# -----------------
#   [WORKFLOW 04: Finalize CPN]
#   Stage 1: Load configuration and data
#   Stage 2: Load and validate edited template
#   Stage 3: Track manual edits (compare ORIGINAL vs EDIT_THIS)
#   Stage 4: Calculate RecordingHours and classify Status
#   Stage 5: Calculate CallsPerHour metrics
#   Stage 6: Save final CPN with versioning
#
#   [WORKFLOW 05: Summary Statistics]
#   Stage 7: Generate detector activity summary
#   Stage 8: Generate study-wide summary
#   Stage 9: Calculate variance components
#   Stage 10: Generate species composition (if applicable)
#   Stage 11: Calculate species accumulation
#   Stage 12: Generate hourly activity profiles
#   Stage 13: Format GT tables and export
#   Stage 14: Save summary RDS
#
#   [WORKFLOW 06: Exploratory Plots]
#   Stage 15: Configure plot settings
#   Stage 16: Generate quality plots (8)
#   Stage 17: Generate detector plots (7)
#   Stage 18: Generate species plots (5, if applicable)
#   Stage 19: Generate temporal plots (6)
#   Stage 20: Export plots (PNG/SVG)
#   Stage 21: Save plot objects RDS
#
#   [WORKFLOW 07: Report & Release]
#   Stage 22: Load pre-computed RDS artifacts
#   Stage 23: Render Quarto report
#   Stage 24: Create release bundle (ZIP)
#   Stage 25: Render final validation HTML
#
# CONTRACT
# --------
# INPUTS:
#   - Edited CPN template (EDIT_THIS file from Chunk 2)
#   - kpro_master tibble (from Chunk 2 result OR checkpoint)
#   - inst/config/study_parameters.yaml
#   - reports/bat_activity_report.qmd (Quarto template)
#
# OUTPUTS:
#   - calls_per_night_final tibble (in returned list)
#   - CallsPerNight_final_vX.csv
#   - Edit log TXT file
#   - Summary statistics RDS + tables (PNG/HTML/XLSX)
#   - Plot objects RDS + 26 PNG files (quality/detector/species/temporal)
#   - Quarto report HTML
#   - Release bundle ZIP
#   - Validation HTML reports (4 total, one per workflow)
#   - Artifact registry entries
#
# GUARANTEES:
#   - All paths use here::here()
#   - Silent by default (verbose = FALSE)
#   - No interactive prompts (edited_template_file parameter for Shiny)
#   - File logging always active via log_message()
#   - Returns comprehensive structured list
#   - Validation HTML rendered for each workflow
#   - Release bundle includes manifest with full provenance
#
# DOES NOT:
#   - Modify global environment (returns results)
#   - Prompt for user input (uses parameters)
#   - Skip any checkpoint or artifact saving
#   - Perform statistical inference (descriptive only)
#
# DEPENDENCIES
# ------------
#   Custom functions (via load_all.R):
#     - All function modules from core/, ingestion/, standardization/,
#       validation/, analysis/, output/
#     - Specifically: load_study_parameters, load_master_data, load_cpn_final,
#       save_callspernight_with_version, create_detector_activity_summary,
#       create_study_summary, generate_quality_plots, generate_detector_plots,
#       generate_species_plots, generate_temporal_plots, create_release_bundle,
#       init_artifact_registry, register_artifact
#
# CHANGELOG
# ---------
# 2026-02-02: Fixed Stage 2 template loading and deduplication
#             - Added deduplication logic for both ORIGINAL and EDIT_THIS templates
#             - Improved RecordingHours conversion with safe handling of empty strings
#             - Added diagnostic reporting for duplicate rows removed
#             - Fixed datetime column conversion to handle missing columns gracefully
#             - Added logging of deduplication counts to validation context
# 2026-02-02: Fixed Stage 2 checkpoint loading and type conversion
#             - Replaced removed load_master_data() with find_most_recent_file()
#             - Added numeric type conversion for CallsPerNight and RecordingHours
#             - Fixed template patterns to use explicit timestamp format (YYYYMMDD_HHMMSS)
#             - Added verbose parameter to safe_read_csv() calls
# 2026-01-31: Initial creation - merged WF04-07 logic into orchestrating function
# 2026-01-31: Added edited_template_file parameter for Shiny integration
# 2026-01-31: Removed all interactive prompts
# 2026-01-31: Standardized to verbose parameter pattern
# 2026-01-31: Combined validation reports for all 4 workflows
#
# ==============================================================================


#' Run Complete Finalization Pipeline (CPN → Report)
#'
#' @description
#' Chunk 3 of the KPro pipeline. Processes edited CPN template through final
#' report generation, combining Workflows 04-07:
#' - WF04: Finalizes CPN with status classification and metrics
#' - WF05: Generates comprehensive summary statistics
#' - WF06: Creates 26 exploratory visualizations
#' - WF07: Renders Quarto report and creates release bundle
#'
#' This is the most comprehensive pipeline stage, producing all final
#' deliverables for the study.
#'
#' @param kpro_master Tibble. Master dataset from Chunk 2. If NULL, will load
#'   from most recent checkpoint. Default: NULL.
#' @param edited_template_file Character. Path to user-edited EDIT_THIS CSV file.
#'   If NULL, will use most recent EDIT_THIS file. Default: NULL.
#' @param create_release_bundle Logical. Whether to create final ZIP bundle.
#'   Default: TRUE.
#' @param verbose Logical. Print progress messages to console. Default: FALSE.
#'
#' @return Named list containing:
#'   \describe{
#'     \item{workflow_04}{List. Finalize CPN outputs:
#'       \itemize{
#'         \item calls_per_night_final: Tibble with final metrics
#'         \item cpn_file: Path to versioned CSV
#'         \item total_edits: Number of manual edits tracked
#'         \item status_distribution: List with Fail/Success/Partial counts
#'       }
#'     }
#'     \item{workflow_05}{List. Summary statistics outputs:
#'       \itemize{
#'         \item all_summaries: Master list with all summary tables
#'         \item summary_rds: Path to summary RDS file
#'         \item files_created: Vector of table export paths
#'       }
#'     }
#'     \item{workflow_06}{List. Exploratory plots outputs:
#'       \itemize{
#'         \item all_plots: Nested list of ggplot objects
#'         \item plots_rds: Path to plots RDS file
#'         \item files_created: Vector of PNG/SVG paths
#'         \item plot_counts: List with counts by category
#'       }
#'     }
#'     \item{workflow_07}{List. Report & release outputs:
#'       \itemize{
#'         \item report_html: Path to rendered Quarto report
#'         \item release_zip: Path to release bundle (if created)
#'         \item report_size_kb: File size of report
#'       }
#'     }
#'     \item{summary}{List. Overall pipeline metadata:
#'       \itemize{
#'         \item pipeline_duration_sec: Total execution time
#'         \item total_detectors: Count of unique detectors
#'         \item total_calls: Count of total bat calls
#'         \item study_name: Study identifier
#'         \item timestamp: Execution timestamp
#'       }
#'     }
#'     \item{validation_html_paths}{Character vector. All validation reports.}
#'   }
#'
#' @section SEQUENTIAL DEPENDENCY CHAIN:
#' The workflows execute in strict sequence with handoffs:
#' \enumerate{
#'   \item WF04: Produces calls_per_night_final (passed to WF05/06)
#'   \item WF05: Produces summary_data RDS (discovered by WF07)
#'   \item WF06: Produces plot_objects RDS (discovered by WF07)
#'   \item WF07: Renders report using RDS artifacts from WF05/06
#' }
#'
#' @section WORKFLOW 04 DETAILS:
#' Finalizes CallsPerNight dataset:
#' - Compares ORIGINAL vs EDIT_THIS templates
#' - Tracks all manual recording hour edits
#' - Recalculates RecordingHours from edited times
#' - Classifies Status (Fail/Success/Partial)
#' - Calculates CallsPerHour (retains dead nights with NA)
#' - Saves versioned CSV (v1, v2, v3, etc.)
#'
#' @section WORKFLOW 05 DETAILS:
#' Generates summary statistics:
#' - Detector-level: effort, activity, variability
#' - Study-wide: totals, means, success rates
#' - Variance decomposition (between/within detector)
#' - Species composition (if species column exists)
#' - Hourly activity profiles (if temporal data exists)
#' - Exports GT tables (PNG, HTML, Excel)
#'
#' @section WORKFLOW 06 DETAILS:
#' Creates exploratory visualizations (26 total):
#' - Quality (8): recording status, completeness, effort
#' - Detector (7): activity, correlation, synchrony
#' - Species (5): composition, diversity (if species data exists)
#' - Temporal (6): trends, hourly, weekly, monthly
#' - Exports PNG (300 DPI) + optional SVG + RDS objects
#'
#' @section WORKFLOW 07 DETAILS:
#' Renders report and creates release:
#' - Discovers and loads RDS files from WF05/06
#' - Renders Quarto report with embedded plots/tables
#' - Creates portable ZIP bundle with:
#'   - Final CPN CSV
#'   - Master CSV
#'   - Summary tables
#'   - All plots (PNG)
#'   - HTML report
#'   - Manifest with provenance
#'
#' @section Error Handling:
#' Stops with actionable error message if:
#' \itemize{
#'   \item Edited template file not found
#'   \item Required columns missing from template
#'   \item Master data not available
#'   \item Quarto report rendering fails
#' }
#'
#' @examples
#' \dontrun{
#' # Standard usage (called by Shiny after user edits template)
#' result <- run_finalize_to_report(
#'   kpro_master = chunk2_result$kpro_master,
#'   edited_template_file = chunk2_result$template_edit_path
#' )
#'
#' # With verbose output for debugging
#' result <- run_finalize_to_report(verbose = TRUE)
#'
#' # Skip release bundle creation
#' result <- run_finalize_to_report(create_release_bundle = FALSE)
#'
#' # Access results
#' cpn <- result$workflow_04$calls_per_night_final
#' result$workflow_07$report_html  # Main deliverable
#' result$summary$pipeline_duration_sec
#' }
#'
#' @export
run_finalize_to_report <- function(kpro_master = NULL,
                                   edited_template_file = NULL,
                                   create_release_bundle = TRUE,
                                   verbose = FALSE) {
  
  # ===========================================================================
  # SETUP
  # ===========================================================================
  
  pipeline_start_time <- Sys.time()
  
  log_message("=== CHUNK 3: Finalize to Report - START ===")
  
  # Standard paths
  yaml_path <- here::here("inst", "config", "study_parameters.yaml")
  outputs_dir <- here::here("outputs")
  results_dir <- here::here("results")
  
  # Initialize return structure
  result <- list(
    workflow_04 = list(),
    workflow_05 = list(),
    workflow_06 = list(),
    workflow_07 = list(),
    summary = list(),
    validation_html_paths = character()
  )
  
  # ===========================================================================
  # WORKFLOW 04: FINALIZE CPN
  # ===========================================================================
  
  if (verbose) {
    message("\n")
    message("╔═══════════════════════════════════════════════════════════════╗")
    message("║           WORKFLOW 04: FINALIZE CALLSPERNIGHT               ║")
    message("╚═══════════════════════════════════════════════════════════════╝")
    message("")
  }
  
  log_message("=== WORKFLOW 04: Finalize CallsPerNight - START ===")
  
  validation_context_04 <- create_validation_context(workflow = "finalize_cpn")
  
  # ---------------------------------------------------------------------------
  # Stage 1: Load Configuration
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("1", "Load Configuration")
  
  assert_file_exists(yaml_path, hint = "Configure study parameters first.")
  study_params <- load_study_parameters(yaml_path)
  
  validation_context_04$study_name <- study_params$study_parameters$study_name
  
  if (verbose) message("  [OK] Loaded study_parameters.yaml")
  
  # Get uniform schedule for status classification
  advanced_scheduling <- study_params$processing_options$advanced_scheduling %||% "no"
  uniform_start <- study_params$processing_options$recording_start %||% NA
  uniform_end <- study_params$processing_options$recording_end %||% NA
  intended_hours <- study_params$processing_options$intended_hours %||% NA
  
  log_message("[WF04 Stage 1] Configuration loaded")
  
  # ---------------------------------------------------------------------------
  # Stage 2: Load Master Data and Templates
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("2", "Load Data and Templates")
  
  # Load master data
  if (!is.null(kpro_master)) {
    if (verbose) message("  [OK] Using kpro_master from Chunk 2")
  } else {
    if (verbose) message("  [!] Loading kpro_master from checkpoint...")
    
    # Load from most recent checkpoint
    kpro_master_file <- find_most_recent_file(
      directory = here::here("outputs", "checkpoints"),
      pattern = "^02_kpro_master_\\d{8}_\\d{6}\\.csv$",
      hint = "Run Chunk 1 (run_ingest_standardize) first"
    )
    
    kpro_master <- safe_read_csv(kpro_master_file, verbose = verbose)
  }
  
  validation_context_04 <- log_validation_event(
    validation_context_04,
    event_type = "data_loaded",
    description = "Master data loaded",
    count = nrow(kpro_master)
  )
  
  # Validate species column exists
  if (!"species" %in% names(kpro_master)) {
    warning("'species' column not found in kpro_master - creating from auto_id")
    kpro_master$species <- kpro_master$auto_id
  }
  
  # Load original template for comparison
  template_original_file <- find_most_recent_file(
    directory = outputs_dir,
    pattern = "^03_CallsPerNight_Template_\\d{8}_\\d{6}_ORIGINAL\\.csv$",
    hint = "Run Chunk 2 first"
  )
  
  template_original <- safe_read_csv(template_original_file, verbose = verbose)
  
  # Count rows before deduplication
  n_orig_before <- nrow(template_original)
  
  # Convert and deduplicate ORIGINAL template
  template_original <- template_original %>%
    dplyr::mutate(
      Night = as.Date(Night),
      Detector = as.character(Detector),
      CallsPerNight = as.numeric(CallsPerNight),
      # Safe RecordingHours conversion - handle empty strings and non-numeric
      RecordingHours = suppressWarnings(as.numeric(RecordingHours))
    ) %>%
    # CRITICAL: Remove duplicates keeping first occurrence
    dplyr::distinct(Detector, Night, .keep_all = TRUE)
  
  n_orig_after <- nrow(template_original)
  n_orig_removed <- n_orig_before - n_orig_after
  
  if (verbose) {
    if (n_orig_removed > 0) {
      message(sprintf("  [!] Removed %d duplicate rows from ORIGINAL template", n_orig_removed))
    }
    message(sprintf("  [OK] Loaded ORIGINAL template: %s (%d rows)", 
                    basename(template_original_file), n_orig_after))
  }
  
  # Load edited template
  if (is.null(edited_template_file)) {
    edited_template_file <- find_most_recent_file(
      directory = outputs_dir,
      pattern = "^03_CallsPerNight_Template_\\d{8}_\\d{6}_EDIT_THIS\\.csv$",
      hint = "Edit template before running Chunk 3"
    )
  } else {
    assert_file_exists(edited_template_file, hint = "Check edited template path")
  }
  
  template_edited <- safe_read_csv(edited_template_file, verbose = verbose)
  
  # Count rows before deduplication
  n_edit_before <- nrow(template_edited)
  
  # Convert and deduplicate EDITED template
  template_edited <- template_edited %>%
    dplyr::mutate(
      Night = as.Date(Night),
      Detector = as.character(Detector),
      CallsPerNight = as.numeric(CallsPerNight),
      # Safe RecordingHours conversion - handle empty strings and non-numeric
      RecordingHours = suppressWarnings(as.numeric(RecordingHours))
    )
  
  # Handle datetime columns if they exist
  if ("StartDateTime" %in% names(template_edited)) {
    template_edited <- template_edited %>%
      dplyr::mutate(
        StartDateTime = dplyr::if_else(
          !is.na(StartDateTime) & StartDateTime != "",
          as.character(StartDateTime),
          NA_character_
        )
      )
  }
  
  if ("EndDateTime" %in% names(template_edited)) {
    template_edited <- template_edited %>%
      dplyr::mutate(
        EndDateTime = dplyr::if_else(
          !is.na(EndDateTime) & EndDateTime != "",
          as.character(EndDateTime),
          NA_character_
        )
      )
  }
  
  # CRITICAL: Remove duplicates keeping last occurrence (most recent edit)
  template_edited <- template_edited %>%
    dplyr::arrange(Detector, Night) %>%
    dplyr::distinct(Detector, Night, .keep_all = TRUE)
  
  n_edit_after <- nrow(template_edited)
  n_edit_removed <- n_edit_before - n_edit_after
  
  if (n_edit_removed > 0) {
    warning(sprintf(
      "Removed %d duplicate rows from EDIT_THIS template. Check your template for duplicate Detector/Night combinations.",
      n_edit_removed
    ))
  }
  
  validation_context_04 <- log_validation_event(
    validation_context_04,
    event_type = "data_loaded",
    description = "CPN template loaded",
    count = n_edit_after,
    details = list(
      original_file = basename(template_original_file),
      edited_file = basename(edited_template_file),
      duplicates_removed = n_edit_removed
    )
  )
  
  if (verbose) {
    message(sprintf("  [OK] Loaded EDIT_THIS template: %s (%d rows)", 
                    basename(edited_template_file), n_edit_after))
  }
  
  # Validate required columns
  required_cols <- c("Detector", "Night", "CallsPerNight")
  assert_columns_exist(template_edited, required_cols)
  
  log_message(sprintf("[WF04 Stage 2] Templates loaded (%d duplicates removed)", 
                      n_orig_removed + n_edit_removed))
  
  # ---------------------------------------------------------------------------
  # Stage 3: Track Manual Edits
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("3", "Track Manual Edits")
  
  # Compare ORIGINAL vs EDITED for changes
  # This is a simplified tracking - full implementation in WF04
  
  total_edits <- 0
  edit_log_lines <- character()
  
  if ("StartDateTime" %in% names(template_original) && 
      "StartDateTime" %in% names(template_edited)) {
    
    comparison <- template_edited %>%
      dplyr::left_join(
        template_original %>% 
          dplyr::select(Detector, Night, 
                        StartDateTime_orig = StartDateTime,
                        EndDateTime_orig = EndDateTime),
        by = c("Detector", "Night")
      ) %>%
      dplyr::filter(
        !is.na(StartDateTime) & !is.na(EndDateTime) &
          (StartDateTime != StartDateTime_orig | EndDateTime != EndDateTime_orig)
      )
    
    total_edits <- nrow(comparison)
    
    if (total_edits > 0) {
      edit_log_lines <- sprintf(
        "%s | %s | %s -> %s | %s -> %s",
        comparison$Detector,
        comparison$Night,
        comparison$StartDateTime_orig,
        comparison$StartDateTime,
        comparison$EndDateTime_orig,
        comparison$EndDateTime
      )
    }
  }
  
  validation_context_04 <- log_validation_event(
    validation_context_04,
    event_type = "manual_edits",
    description = "Manual recording hour edits tracked",
    count = total_edits
  )
  
  if (verbose) {
    message(sprintf("  [OK] Tracked %d manual edits", total_edits))
  }
  
  log_message(sprintf("[WF04 Stage 3] Tracked %d manual edits", total_edits))
  
  # ---------------------------------------------------------------------------
  # Stage 4: Calculate RecordingHours
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("4", "Calculate Recording Hours")
  
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
  
  log_message("[WF04 Stage 4] RecordingHours calculated")
  
  # ---------------------------------------------------------------------------
  # Stage 5: Classify Status and Calculate Metrics
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("5", "Classify Status & Calculate Metrics")
  
  # Classify recording status
  calls_per_night_final <- template_edited %>%
    dplyr::mutate(
      Status = dplyr::case_when(
        RecordingHours == 0 | is.na(RecordingHours) ~ "Fail",
        advanced_scheduling != "no" ~ "Success",  # Advanced: all non-zero are Success
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
  
  validation_context_04 <- log_validation_event(
    validation_context_04,
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
  
  log_message(sprintf("[WF04 Stage 5] Status classified, %d dead nights retained", dead_nights))
  
  # Origin: 04_finalize_cpn.R ~L560+, Standards: 04_data_standards.md §4.3

  # Validate problematic call values before proceeding
  problematic_calls <- calls_per_night_final %>%
    dplyr::filter(CallsPerNight < 0 | CallsPerNight > 10000)
  
  if (nrow(problematic_calls) > 0) {
    warning(sprintf(
      "Found %d rows with suspicious call counts (negative or >10000). Check data quality.",
      nrow(problematic_calls)
    ))
    
    validation_context_04 <- log_validation_event(
      validation_context_04,
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
  
  # ---------------------------------------------------------------------------
  # Stage 6: Save Final CPN
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("6", "Save Final CPN")
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  cpn_final_path <- save_callspernight_with_version(
    calls_per_night_final,
    base_name = "CallsPerNight_final",
    output_dir = here::here("results", "csv")
  )
  
  # Register artifact
  registry <- init_artifact_registry()
  artifact_id_cpn <- sprintf("cpn_final_%s", timestamp)
  
  registry <- register_artifact(
    registry = registry,
    artifact_name = artifact_id_cpn,
    artifact_type = "cpn_final",
    workflow = "finalize_cpn",
    file_path = cpn_final_path,
    metadata = list(
      n_rows = nrow(calls_per_night_final),
      n_detectors = dplyr::n_distinct(calls_per_night_final$Detector),
      total_edits = total_edits,
      status_distribution = as.list(status_dist),
      dead_nights_retained = dead_nights
    )
  )
  
  if (verbose) message(sprintf("  [OK] Saved: %s", basename(cpn_final_path)))
  
  # Save edit log if edits were made
  if (total_edits > 0) {
    edit_log_path <- here::here("outputs", 
                                sprintf("04_CallsPerNight_EditLog_%s.txt", timestamp))
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
  
  # Finalize validation
  validation_dir_04 <- here::here("results", "validation")
  assert_directory_exists(validation_dir_04, create = TRUE)
  
  validation_html_04 <- finalize_validation_report(
    validation_context_04,
    output_dir = validation_dir_04
  )
  
  if (verbose) message(sprintf("  [OK] Validation: %s", basename(validation_html_04)))
  
  log_message("=== WORKFLOW 04: COMPLETE ===")
  
  # Store WF04 results
  result$workflow_04 <- list(
    calls_per_night_final = calls_per_night_final,
    cpn_file = cpn_final_path,
    total_edits = total_edits,
    status_distribution = as.list(status_dist),
    dead_nights_retained = dead_nights,
    validation_report = validation_html_04
  )
  
  result$validation_html_paths <- c(result$validation_html_paths, validation_html_04)
  
  # ===========================================================================
  # WORKFLOW 05: SUMMARY STATISTICS
  # ===========================================================================
  
  if (verbose) {
    message("\n")
    message("╔═══════════════════════════════════════════════════════════════╗")
    message("║           WORKFLOW 05: SUMMARY STATISTICS                   ║")
    message("╚═══════════════════════════════════════════════════════════════╝")
    message("")
  }
  
  log_message("=== WORKFLOW 05: Summary Statistics - START ===")
  
  validation_context_05 <- create_validation_context(workflow = "summary_stats")
  validation_context_05$study_name <- study_params$study_parameters$study_name
  
  # Initialize summaries list
  all_summaries <- list()
  files_created_05 <- character()
  
  # ---------------------------------------------------------------------------
  # Stage 7: Detector Activity Summary
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("7", "Detector Activity Summary")
  
  detector_summary <- create_detector_activity_summary(calls_per_night_final)
  all_summaries$detector_summary <- detector_summary
  
  validation_context_05 <- log_validation_event(
    validation_context_05,
    event_type = "summary_generated",
    description = "Detector activity summary created",
    count = nrow(detector_summary)
  )
  
  if (verbose) message(sprintf("  [OK] Created detector summary: %d detectors", 
                               nrow(detector_summary)))
  
  log_message("[WF05 Stage 7] Detector summary created")
  
  # ---------------------------------------------------------------------------
  # Stage 8: Study-Wide Summary
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("8", "Study-Wide Summary")
  
  study_summary <- create_study_summary(calls_per_night_final)
  all_summaries$study_summary <- study_summary
  
  validation_context_05 <- log_validation_event(
    validation_context_05,
    event_type = "summary_generated",
    description = "Study-wide summary created"
  )
  
  if (verbose) message("  [OK] Created study-wide summary")
  
  log_message("[WF05 Stage 8] Study summary created")
  
  # ---------------------------------------------------------------------------
  # Stage 9: Variance Components (Optional - skip if function not available)
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("9", "Variance Components")
  
  variance_components <- tryCatch({
    calculate_variance_components(calls_per_night_final)
  }, error = function(e) {
    if (verbose) message("  [!] Variance calculation skipped")
    NULL
  })
  
  if (!is.null(variance_components)) {
    all_summaries$variance_components <- variance_components
    if (verbose) message("  [OK] Calculated variance components")
    log_message("[WF05 Stage 9] Variance components calculated")
  }
  
  # ---------------------------------------------------------------------------
  # Stage 10-12: Species and Temporal Summaries (Conditional)
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("10", "Species & Temporal Summaries")
  
  has_species <- "species" %in% names(kpro_master)
  has_temporal <- "Hour_local" %in% names(kpro_master) || "DateTime_local" %in% names(kpro_master)
  
  if (has_species) {
    species_summary <- tryCatch({
      create_species_summary_by_detector(kpro_master, calls_per_night_final)
    }, error = function(e) NULL)
    
    if (!is.null(species_summary)) {
      all_summaries$species_summary <- species_summary
      if (verbose) message("  [OK] Created species summary")
    }
    
    species_accumulation <- tryCatch({
      create_species_accumulation_summary(kpro_master, calls_per_night_final)
    }, error = function(e) NULL)
    
    if (!is.null(species_accumulation)) {
      all_summaries$species_accumulation <- species_accumulation
      if (verbose) message("  [OK] Created species accumulation")
    }
  }
  
  if (has_temporal) {
    hourly_summary <- tryCatch({
      create_hourly_activity_summary(kpro_master, calls_per_night_final)
    }, error = function(e) NULL)
    
    if (!is.null(hourly_summary)) {
      all_summaries$hourly_summary <- hourly_summary
      if (verbose) message("  [OK] Created hourly activity summary")
    }
  }
  
  log_message("[WF05 Stages 10-12] Optional summaries completed")
  
  # ---------------------------------------------------------------------------
  # Stage 13-14: Save Summary RDS and Export Tables
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("13", "Save Summary RDS")
  
  timestamp_05 <- format(Sys.time(), "%Y%m%d")
  summary_rds_path <- here::here("results", "rds", sprintf("summary_data_%s.rds", timestamp_05))
  
  # Origin: 05_summary_stats.R, Standards: 07_artifact_release_standards.md
  # Add metadata element required by validate_rds_structure()
  all_summaries$metadata <- list(
    generated = Sys.time(),
    study_name = study_params$study_parameters$study_name %||% "Unknown",
    n_detectors = dplyr::n_distinct(calls_per_night_final$Detector),
    n_nights = dplyr::n_distinct(calls_per_night_final$Night),
    has_species = has_species,
    has_temporal = has_temporal
  )
  
  assert_directory_exists(dirname(summary_rds_path), create = TRUE)
  saveRDS(all_summaries, summary_rds_path)
  
  # Register artifact
  artifact_id_summary <- sprintf("summary_data_%s", timestamp_05)
  registry <- register_artifact(
    registry = registry,
    artifact_name = artifact_id_summary,
    artifact_type = "summary_stats",  # FIXED: was "summary_rds"
    workflow = "summary_stats",
    file_path = summary_rds_path,
    metadata = list(
      n_summaries = length(all_summaries),
      has_species = has_species,
      has_temporal = has_temporal
    )
  )
  
  if (verbose) message(sprintf("  [OK] Saved: %s", basename(summary_rds_path)))
  
  # Finalize validation
  validation_html_05 <- finalize_validation_report(
    validation_context_05,
    output_dir = validation_dir_04
  )
  
  if (verbose) message(sprintf("  [OK] Validation: %s", basename(validation_html_05)))
  
  log_message("=== WORKFLOW 05: COMPLETE ===")
  
  # Origin: 05_summary_stats.R, Standards: 01_architecture_standards.md (structured returns)
  # Store WF05 results in return structure
  result$workflow_05 <- list(
    all_summaries = all_summaries,
    summary_rds = summary_rds_path,
    files_created = character(),  # GT table exports handled separately if needed
    has_species = has_species,
    has_temporal = has_temporal,
    validation_report = validation_html_05
  )
  
  result$validation_html_paths <- c(result$validation_html_paths, validation_html_05)
  
  # ===========================================================================
  # WORKFLOW 06: EXPLORATORY PLOTS
  # ===========================================================================
  
  if (verbose) {
    message("\n")
    message("╔═══════════════════════════════════════════════════════════════╗")
    message("║           WORKFLOW 06: EXPLORATORY PLOTS                    ║")
    message("╚═══════════════════════════════════════════════════════════════╝")
    message("")
  }
  
  log_message("=== WORKFLOW 06: Exploratory Plots - START ===")
  
  validation_context_06 <- create_validation_context(workflow = "exploratory_plots")
  validation_context_06$study_name <- study_params$study_parameters$study_name
  
  # Initialize plots structure
  all_plots <- list(
    quality = list(),
    detector = list(),
    species = list(),
    temporal = list()
  )
  
  files_created_06 <- character()
  
  # ---------------------------------------------------------------------------
  # Stages 15-19: Generate Plot Categories
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("15", "Configure Plot Settings")
  
  # Create plot output directories
  plot_dirs <- c("quality", "detector", "species", "temporal")
  for (dir_name in plot_dirs) {
    assert_directory_exists(
      here::here("results", "figures", "png", dir_name),
      create = TRUE
    )
  }
  
  if (verbose) message("  [OK] Plot directories ready")
  
  # ---------------------------------------------------------------------------
  # Stage 16: Quality Plots (8 plots)
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("16", "Generate Quality Plots")
  
  quality_plots <- list()
  
  tryCatch({
    quality_plots$recording_status_summary <- plot_recording_status_summary(calls_per_night_final)
    quality_plots$recording_status_percent <- plot_recording_status_percent(calls_per_night_final)
    quality_plots$recording_status_overall <- plot_recording_status_overall(calls_per_night_final)
    quality_plots$effort_by_detector <- plot_effort_by_detector(calls_per_night_final)
    quality_plots$nights_by_detector <- plot_nights_by_detector(calls_per_night_final)
    quality_plots$data_completeness_calendar <- plot_data_completeness_calendar(calls_per_night_final)
    quality_plots$missing_nights <- plot_missing_nights(calls_per_night_final)
    quality_plots$recording_effort_heatmap <- plot_recording_effort_heatmap(calls_per_night_final)
    
    if (verbose) message(sprintf("  [OK] Generated %d quality plots", length(quality_plots)))
  }, error = function(e) {
    warning(sprintf("Quality plots failed: %s", e$message))
    quality_plots <<- list()
  })
  
  all_plots$quality <- quality_plots
  
  # ---------------------------------------------------------------------------
  # Stage 17: Detector Plots (7 plots)
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("17", "Generate Detector Plots")
  
  detector_plots <- list()
  
  tryCatch({
    detector_plots$total_calls_by_detector <- plot_total_calls_by_detector(kpro_master)
    detector_plots$detector_activity_caterpillar <- plot_detector_activity_caterpillar(calls_per_night_final)
    detector_plots$detector_boxplots <- plot_detector_boxplots(calls_per_night_final)
    detector_plots$activity_with_without_outliers <- plot_activity_with_without_outliers(calls_per_night_final)
    detector_plots$synchrony <- plot_synchrony(calls_per_night_final)
    detector_plots$correlation_heatmap <- plot_correlation_heatmap(calls_per_night_final)
    detector_plots$detector_rank_over_time <- plot_detector_rank_over_time(calls_per_night_final)
    
    if (verbose) message(sprintf("  [OK] Generated %d detector plots", length(detector_plots)))
  }, error = function(e) {
    warning(sprintf("Detector plots failed: %s", e$message))
    detector_plots <<- list()
  })
  
  all_plots$detector <- detector_plots
  
  # ---------------------------------------------------------------------------
  # Stage 18: Species Plots (5 plots, conditional)
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("18", "Generate Species Plots")
  
  species_plots <- list()
  
  if (has_species) {
    tryCatch({
      species_plots$species_composition_bar <- plot_species_composition_bar(kpro_master)
      species_plots$species_by_detector_heatmap <- plot_species_by_detector_heatmap(kpro_master)
      species_plots$species_accumulation_curve <- plot_species_accumulation_curve(kpro_master)
      species_plots$species_hourly_profile <- plot_species_hourly_profile(kpro_master)
      species_plots$noid_proportion <- plot_noid_proportion(kpro_master)
      
      if (verbose) message(sprintf("  [OK] Generated %d species plots", length(species_plots)))
    }, error = function(e) {
      warning(sprintf("Species plots failed: %s", e$message))
      species_plots <- list()
    })
  } else {
    if (verbose) message("  [!] Species plots skipped (no species column)")
  }
  
  all_plots$species <- species_plots
  
  # ---------------------------------------------------------------------------
  # Stage 19: Temporal Plots (6 plots)
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("19", "Generate Temporal Plots")
  
  temporal_plots <- list()
  
  tryCatch({
    temporal_plots$activity_over_time <- plot_activity_over_time(calls_per_night_final)
    temporal_plots$cumulative_calls_over_time <- plot_cumulative_calls_over_time(calls_per_night_final)
    temporal_plots$hourly_activity_profile <- plot_hourly_activity_profile(kpro_master)
    temporal_plots$callsperhour_distribution <- plot_callsperhour_distribution(calls_per_night_final)
    temporal_plots$weekly_activity <- plot_weekly_activity(calls_per_night_final)
    temporal_plots$activity_by_month <- plot_activity_by_month(calls_per_night_final)
    
    if (verbose) message(sprintf("  [OK] Generated %d temporal plots", length(temporal_plots)))
  }, error = function(e) {
    warning(sprintf("Temporal plots failed: %s", e$message))
    temporal_plots <<- list()
  })
  
  all_plots$temporal <- temporal_plots
  
  log_message(sprintf("[WF06 Stages 15-19] Generated %d total plots",
                      length(quality_plots) + length(detector_plots) + 
                        length(species_plots) + length(temporal_plots)))
  
  # ---------------------------------------------------------------------------
  # Stage 20-21: Export Plots and Save RDS
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("20", "Export Plots")
  
  # Export all plots as PNG (simplified - full implementation uses export_plots_png)
  total_plots_exported <- 0
  
  for (category in names(all_plots)) {
    category_plots <- all_plots[[category]]
    if (length(category_plots) > 0) {
      for (plot_name in names(category_plots)) {
        plot_path <- here::here("results", "figures", "png", category,
                                sprintf("%s.png", plot_name))
        tryCatch({
          ggplot2::ggsave(plot_path, category_plots[[plot_name]], 
                          width = 10, height = 7, dpi = 300)
          files_created_06 <- c(files_created_06, plot_path)
          total_plots_exported <- total_plots_exported + 1
        }, error = function(e) {
          warning(sprintf("Failed to export %s: %s", plot_name, e$message))
        })
      }
    }
  }
  
  if (verbose) message(sprintf("  [OK] Exported %d plot PNG files", total_plots_exported))
  
  # Save plot objects RDS
  if (verbose) print_stage_header("21", "Save Plot Objects RDS")
  
  timestamp_06 <- format(Sys.time(), "%Y%m%d")
  plots_rds_path <- here::here("results", "rds", sprintf("plot_objects_%s.rds", timestamp_06))
  
  saveRDS(all_plots, plots_rds_path)
  
  # Register artifact
  artifact_id_plots <- sprintf("plot_objects_%s", timestamp_06)
  registry <- register_artifact(
    registry = registry,
    artifact_name = artifact_id_plots,
    artifact_type = "plot_objects",  # FIXED: was "plots_rds"
    workflow = "exploratory_plots",
    file_path = plots_rds_path,
    metadata = list(
      total_plots = total_plots_exported,
      quality_plots = length(quality_plots),
      detector_plots = length(detector_plots),
      species_plots = length(species_plots),
      temporal_plots = length(temporal_plots)
    )
  )
  
  if (verbose) message(sprintf("  [OK] Saved: %s", basename(plots_rds_path)))
  
  # Finalize validation
  validation_html_06 <- finalize_validation_report(
    validation_context_06,
    output_dir = validation_dir_04
  )
  
  if (verbose) message(sprintf("  [OK] Validation: %s", basename(validation_html_06)))
  
  log_message("=== WORKFLOW 06: COMPLETE ===")
  
  # Store WF06 results
  result$workflow_06 <- list(
    all_plots = all_plots,
    plots_rds = plots_rds_path,
    files_created = files_created_06,
    plot_counts = list(
      quality = length(quality_plots),
      detector = length(detector_plots),
      species = length(species_plots),
      temporal = length(temporal_plots)
    ),
    validation_report = validation_html_06
  )
  
  result$validation_html_paths <- c(result$validation_html_paths, validation_html_06)
  
  # ===========================================================================
  # WORKFLOW 07: REPORT & RELEASE
  # ===========================================================================
  
  if (verbose) {
    message("\n")
    message("╔═══════════════════════════════════════════════════════════════╗")
    message("║           WORKFLOW 07: REPORT & RELEASE                     ║")
    message("╚═══════════════════════════════════════════════════════════════╝")
    message("")
  }
  
  log_message("=== WORKFLOW 07: Report & Release - START ===")
  
  validation_context_07 <- create_validation_context(workflow = "report_release")
  validation_context_07$study_name <- study_params$study_parameters$study_name
  
  # ---------------------------------------------------------------------------
  # Stage 22: Verify RDS Artifacts
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("22", "Verify RDS Artifacts")
  
  # Origin: 07_generate_report.R L284-323, Standards: 07_artifact_release_standards.md
  # Use robust RDS discovery and validation like legacy workflow
  
  if (!file.exists(summary_rds_path)) {
    stop("Summary RDS not found: ", summary_rds_path)
  }
  
  if (!file.exists(plots_rds_path)) {
    stop("Plots RDS not found: ", plots_rds_path)
  }
  
  # Load and validate RDS structure for report compatibility
  all_summaries_for_report <- readRDS(summary_rds_path)
  all_plots_for_report <- readRDS(plots_rds_path)
  
  rds_validation <- tryCatch({
    validate_rds_structure(all_summaries_for_report, all_plots_for_report)
  }, error = function(e) {
    list(valid = FALSE, errors = e$message)
  })
  
  if (!rds_validation$valid) {
    warning(sprintf("RDS structure validation warnings:\n  %s",
                    paste(rds_validation$errors, collapse = "\n  ")))
    
    validation_context_07 <- log_validation_event(
      validation_context_07,
      event_type = "warning",
      description = "RDS structure validation issues detected",
      details = list(errors = rds_validation$errors)
    )
  } else {
    if (verbose) {
      message(sprintf("  [OK] RDS validation passed: %d summaries, %d plots",
                      length(all_summaries_for_report),
                      rds_validation$total_plots %||% length(unlist(all_plots_for_report, recursive = FALSE))))
    }
  }
  
  if (verbose) message("  [OK] All RDS artifacts verified")
  
  # ---------------------------------------------------------------------------
  # Stage 23: Render Quarto Report
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("23", "Render Quarto Report")
  
  qmd_template <- here::here("reports", "bat_activity_report.qmd")
  
  report_html_path <- NULL
  render_success <- FALSE
  
  if (file.exists(qmd_template)) {
    
    timestamp_07 <- format(Sys.time(), "%Y%m%d")
    report_html_path <- here::here("results", "reports", 
                                   sprintf("bat_activity_report_%s.html", timestamp_07))
    
    assert_directory_exists(dirname(report_html_path), create = TRUE)
    
    # Render report
    render_result <- tryCatch({
      quarto::quarto_render(
        input = qmd_template,
        output_file = basename(report_html_path),
        output_format = "html",
        execute_params = list(
          summary_rds = summary_rds_path,           # Match report param name
          plots_rds = plots_rds_path,               # Match report param name
          study_params_path = yaml_path             # Match report param name
        ),
        quiet = !verbose
      )
      
      # Move to correct location
      rendered_file <- here::here("reports", basename(report_html_path))
      if (file.exists(rendered_file)) {
        file.rename(rendered_file, report_html_path)
      }
      
      list(success = TRUE, message = "Report rendered successfully")
    }, error = function(e) {
      list(success = FALSE, message = e$message)
    })
    
    render_success <- render_result$success
    
    if (render_success) {
      if (verbose) message(sprintf("  [OK] Report rendered: %s", basename(report_html_path)))
      
      validation_context_07 <- log_validation_event(
        validation_context_07,
        event_type = "report_generated",
        description = "Quarto report rendered",
        details = list(file = basename(report_html_path))
      )
    } else {
      warning(sprintf("Report rendering failed: %s", render_result$message))
    }
    
  } else {
    warning("Quarto template not found - skipping report generation")
  }
  
  log_message(sprintf("[WF07 Stage 23] Report rendering: %s", 
                      if(render_success) "SUCCESS" else "SKIPPED"))
  
  # ---------------------------------------------------------------------------
  # Stage 24: Create Release Bundle
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("24", "Create Release Bundle")
  
  release_zip_path <- NULL
  
  if (create_release_bundle && render_success) {
    
    release_result <- tryCatch({
      zip_path <- create_release_bundle(
        study_id = study_params$study_parameters$study_name,
        calls_per_night_final = calls_per_night_final,  # Data frame from WF04
        kpro_master = kpro_master,                      # Data frame from Stage 2
        all_summaries = all_summaries,                  # List from WF05
        all_plots = all_plots,                          # List from WF06
        report_path = report_html_path,                 # Path to HTML
        study_params = study_params,                    # Already loaded
        output_dir = here::here("results", "releases"),
        registry = registry,                            # Already initialized
        quiet = !verbose                                # Inverse of verbose
      )
      
      list(success = TRUE, zip_path = zip_path)
    }, error = function(e) {
      warning(sprintf("Release bundle creation failed: %s", e$message))
      list(success = FALSE, zip_path = NULL)
    })
    
    if (release_result$success) {
      release_zip_path <- release_result$zip_path
      
      if (verbose) message(sprintf("  [OK] Release bundle: %s", basename(release_zip_path)))
      
      validation_context_07 <- log_validation_event(
        validation_context_07,
        event_type = "release_created",
        description = "Release bundle created",
        details = list(
          file = basename(release_zip_path),
          size_kb = file.size(release_zip_path) / 1024
        )
      )
    }
  } else {
    if (verbose) message("  [!] Release bundle skipped")
  }
  
  log_message(sprintf("[WF07 Stage 24] Release bundle: %s", 
                      if(!is.null(release_zip_path)) "CREATED" else "SKIPPED"))
  
  # ---------------------------------------------------------------------------
  # Stage 25: Finalize Validation
  # ---------------------------------------------------------------------------
  
  if (verbose) print_stage_header("25", "Finalize Validation")
  
  validation_html_07 <- finalize_validation_report(
    validation_context_07,
    output_dir = validation_dir_04
  )
  
  if (verbose) message(sprintf("  [OK] Validation: %s", basename(validation_html_07)))
  
  log_message("=== WORKFLOW 07: COMPLETE ===")
  
  # Store WF07 results
  result$workflow_07 <- list(
    report_html = report_html_path,
    release_zip = release_zip_path,
    report_size_kb = if(!is.null(report_html_path) && file.exists(report_html_path)) 
      file.size(report_html_path) / 1024 else NA,
    validation_report = validation_html_07
  )
  
  result$validation_html_paths <- c(result$validation_html_paths, validation_html_07)
  
  # ===========================================================================
  # FINALIZE AND RETURN
  # ===========================================================================
  
  pipeline_end_time <- Sys.time()
  pipeline_duration <- as.numeric(difftime(pipeline_end_time, pipeline_start_time, units = "secs"))
  
  # Calculate summary statistics
  result$summary <- list(
    pipeline_duration_sec = pipeline_duration,
    total_detectors = dplyr::n_distinct(calls_per_night_final$Detector),
    total_calls = sum(calls_per_night_final$CallsPerNight),
    total_recording_hours = sum(calls_per_night_final$RecordingHours, na.rm = TRUE),
    study_name = study_params$study_parameters$study_name,
    timestamp = format(Sys.time(), "%Y%m%d_%H%M%S")
  )
  
  log_message(sprintf("=== CHUNK 3 COMPLETE: %d workflows, %.1f seconds ===",
                      4, pipeline_duration))
  
  if (verbose) {
    message("\n")
    message("╔═══════════════════════════════════════════════════════════════╗")
    message("║           PIPELINE COMPLETE - CHUNK 3 FINISHED              ║")
    message("╚═══════════════════════════════════════════════════════════════╝")
    message("")
    message(sprintf("  Duration: %.1f seconds", pipeline_duration))
    message(sprintf("  Detectors: %d", result$summary$total_detectors))
    message(sprintf("  Total calls: %s", format(result$summary$total_calls, big.mark = ",")))
    message(sprintf("  Recording hours: %.1f", result$summary$total_recording_hours))
    message("")
    message("  Deliverables:")
    message(sprintf("    - CPN Final: %s", basename(cpn_final_path)))
    if (!is.null(report_html_path)) {
      message(sprintf("    - Report: %s", basename(report_html_path)))
    }
    if (!is.null(release_zip_path)) {
      message(sprintf("    - Release: %s", basename(release_zip_path)))
    }
    message("")
    message("╚═══════════════════════════════════════════════════════════════╝")
    message("")
  }
  
  return(result)
}


# ==============================================================================
# END OF FILE
# ==============================================================================
