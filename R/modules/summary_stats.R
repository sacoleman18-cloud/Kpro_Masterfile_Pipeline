# ==============================================================================
# R/05_summary_stats_module.R — SUMMARY STATISTICS MODULE
# ==============================================================================
# PURPOSE
# -------
# Summary Statistics Module: Generates comprehensive summary statistics (Phase 3).
#
# PHASE ARCHITECTURE: Called by run_phase3_analysis_reporting() orchestrator
# ORCHESTRATION LAYER: Yes, module runner interface
#
# EXECUTION SEQUENCE
# ------------------
# This module is called as the SECOND step in Phase 3:
#   1. run_phase3_analysis_reporting() [phase orchestrator]
#      └→ run_module_finalize_cpn() — Stages 1-6
#      └→ run_module_summary_stats() [this module] — Stages 7-16
#      └→ run_module_plotting() — Stages 15-21
#      └→ run_module_report_release() — Stages 22-25
#
# INPUT REQUIREMENTS
# ------------------
# Parameters:
#   - calls_per_night_final: Tibble from finalize_cpn module
#   - kpro_master: Tibble for species/temporal analysis
#   - study_params: List from load_study_parameters()
#   - registry: Artifact registry (updated with new artifacts)
#   - verbose: Boolean for console output
#
# OUTPUTS GUARANTEES
# -------------------
# Returns a list {summary_stats, validation_html_paths, summary}:
#   - summary_stats$all_summaries: Master list with:
#     - detector_summary, study_summary, species_summary, hourly_summary_overall, etc.
#   - summary_stats$summary_rds: Path to RDS file with all summaries
#   - summary_stats$files_created: Character vector of exported file paths
#   - summary_stats$tables_exported: Numeric count of PNG/HTML tables
#   - validation_html_paths: Character vector (1 HTML file)
#   - summary: Metadata about summaries
#
# WRITES FILES
# -----------
#   - results/csv/summary_stats/*.csv — Individual summary tables
#   - results/xlsx/summary_stats_*.xlsx — Excel workbook (optional)
#   - results/figures/*.png — GT table PNG exports (optional)
#   - results/figures/*.html — GT table HTML exports (optional)
#   - results/rds/summary_data_*.rds — All summaries archived
#   - results/validation/*.html — Validation report
#
# DEPENDENCY CHAIN
# ----------------
# **Previous module dependency:**
#   - calls_per_night_final from finalize_cpn()
#   - kpro_master from original Phase 2 output (passed through)
#
# **Internal stages:**
#   - Stages 7-16 sequentially: 7 → 8 → 9 → 10 → 11 → 12 → 13 → 14 → 15 → 16
#
# **Depends on:**
#   - functions/analysis/summarization.R: all create_*_summary functions
#   - functions/output/tables.R: all format_*_summary_gt functions
#   - functions/core/utilities.R: CSV/Excel helpers
#   - functions/core/artifacts.R: save_and_register_rds, logging
#
# CHANGELOG
# ---------
# 2026-02-20: Refactored Stage 13 CSV exports to local helper (DRY)
# 2026-02-20: Refactored Stage 15 GT PNG/HTML exports to shared helper (DRY)
# 2026-02-08: Extracted from Phase 3 (run_phase3_analysis_reporting) as standalone module


#' Generate Summary Statistics
#'
#' @description
#' Phase 3, Stages 7-16: Generates detector/study/species/temporal summaries,
#' exports as CSV/Excel/PNG/HTML, and saves RDS archive for Report & Release
#' module.
#'
#' This is the SECOND module in the finalize-to-report pipeline. Consumes
#' output from finalize_cpn module.
#'
#' @param calls_per_night_final Tibble. Final CPN from finalize_cpn module.
#'   Must have columns: Detector, Night, CallsPerNight, RecordingHours, Status, CallsPerHour.
#' @param kpro_master Tibble. Master dataset from Phase 2. Required for
#'   species and temporal analyses.
#' @param study_params List. Study parameters from load_study_parameters().
#' @param registry List. Artifact registry (will be updated).
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return List with elements:
#'   - summary_stats: List containing:
#'     - all_summaries: Master list with all summary tables
#'     - summary_rds: Path to RDS file
#'     - files_created: Vector of exported file paths
#'     - tables_exported: Count of PNG/HTML tables
#'   - checkpoint_path: Character path to primary module checkpoint/output
#'   - artifact_ids: Character vector of artifacts registered in this module call
#'   - validation_html_paths: Character vector with validation report path
#'   - summary: Metadata list
#'
#' @details
#' **Stages executed:**
#'   - Stage 7: Detector activity summary (effort, activity, variability)
#'   - Stage 8: Study-wide summary (totals, means, success rates)
#'   - Stage 9: Variance components (optional - skips if function unavailable)
#'   - Stage 10: Species composition by detector
#'   - Stage 11: Species accumulation over time
#'   - Stage 12: Hourly activity profiles
#'   - Stage 13: Export individual CSV files
#'   - Stage 14: Compile Excel workbook from CSVs
#'   - Stage 15: Export summary tables as PNG/HTML
#'   - Stage 16: Save all summaries as RDS
#'
#' **CSV-First Architecture:**
#'   - Each summary exported as individual CSV first
#'   - Excel workbook compiled FROM CSV files (ensures consistency)
#'   - Each CSV registered with SHA256 hash
#'   - Metadata tracks both CSV and Excel artifacts
#'
#' **Artifact Export Configuration:**
#'   - Reads artifact_outputs section from study_parameters.yaml
#'   - Supports csv_*, png_*, html_*, rds_*, xlsx_* keys
#'   - Default: all artifacts enabled if config missing
#'   - Allows per-output granular control
#'
#' @section CONTRACT:
#' - Processes all 9 detectors × 28 nights (252 rows total)
#' - Skips variance calculation gracefully if function unavailable
#' - Requires species column in kpro_master (validated upstream)
#' - Registers all artifacts with metadata
#' - Returns all summary tables in all_summaries list
#' - Also saves to RDS for efficient Report & Release loading
#' - Does NOT modify input data
#'
#' @export
module_summary_stats <- function(calls_per_night_final,
                                 kpro_master,
                                 study_params,
                                 registry = NULL,
                                 verbose = FALSE) {
  
  # ===========================================================================
  # INITIALIZATION
  # ===========================================================================
  
  print_stage_banner("SUMMARY STATISTICS", verbose = verbose)
  
  # Ensure registry exists
  if (is.null(registry)) {
    registry <- list()
  }

  artifact_names_before <- names(registry$artifacts %||% list())
  
  result <- list(summary_stats = list(), validation_html_paths = character())
  
  # Create validation context
  validation_context <- init_stage_validation("summary_stats", study_params)
  
  # Initialize summaries list
  all_summaries <- list()
  files_created <- character()
  
  # Validate required columns for species analysis
  if (!"species" %in% names(kpro_master)) {
    stop(sprintf(
      "Missing required 'species' column in kpro_master.\n  Phase 2 (Template Generation) should have created this column in Stage 3.\n  \n  To remediate:\n  1. Verify Phase 2 (run_phase2_template_generation) completed successfully\n  2. Check that kpro_master checkpoint exists with species column\n  3. If running Phase 3 independently, ensure Phase 2 completed first\n  4. Review logs/ for any warnings in Phase 2 Module 3 (CPN Template)\n  \n  Current kpro_master columns: %s",
      paste(names(kpro_master), collapse = ", ")
    ))
  }
  
  if (verbose) {
    message(sprintf("  [OK] Schema validation passed: species column present (%d unique species)", 
                    dplyr::n_distinct(kpro_master$species)))
  }
  
  # ===========================================================================
  # STAGE 7: DETECTOR ACTIVITY SUMMARY
  # ===========================================================================
  
  log_stage_start("7", "Detector Activity Summary", verbose = verbose, phase_prefix = "Summary Stats")
  
  detector_summary <- create_detector_activity_summary(calls_per_night_final)
  all_summaries$detector_summary <- detector_summary
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "summary_generated",
    description = "Detector activity summary created",
    count = nrow(detector_summary)
  )
  
  message(sprintf("  [OK] Created detector summary: %d detectors", 
                  nrow(detector_summary)))
  
  # ===========================================================================
  # STAGE 8: STUDY-WIDE SUMMARY
  # ===========================================================================
  
  log_stage_start("8", "Study-Wide Summary", verbose = verbose, phase_prefix = "Summary Stats")
  
  study_summary <- create_study_summary(calls_per_night_final)
  all_summaries$study_summary <- study_summary
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "summary_generated",
    description = "Study-wide summary created"
  )
  
  message("  [OK] Created study-wide summary")
  
  # ===========================================================================
  # STAGE 9: VARIANCE COMPONENTS (Optional - skip if function not available)
  # ===========================================================================
  
  log_stage_start("9", "Variance Components", verbose = verbose, phase_prefix = "Summary Stats")
  
  variance_components <- tryCatch({
    calculate_variance_components(calls_per_night_final)
  }, error = function(e) {
    if (verbose) message("  [!] Variance calculation skipped")
    NULL
  })
  
  if (!is.null(variance_components)) {
    all_summaries$variance_components <- variance_components
    if (verbose) message("  [OK] Calculated variance components")
  }
  
  # ===========================================================================
  # STAGE 10: SPECIES COMPOSITION SUMMARY
  # ===========================================================================
  
  log_stage_start("10", "Species Composition Summary", verbose = verbose, phase_prefix = "Summary Stats")
  
  species_summary <- tryCatch({
    create_species_summary_by_detector(kpro_master)
  }, error = function(e) {
    stop(sprintf(
      "Failed to create species composition summary.\n  Original error: %s\n  Check that kpro_master has valid species data and required columns.",
      e$message
    ))
  })
  
  all_summaries$species_summary <- species_summary
  message("  [OK] Created species summary")
  
  # ===========================================================================
  # STAGE 11: SPECIES ACCUMULATION SUMMARY
  # ===========================================================================
  
  log_stage_start("11", "Species Accumulation Summary", verbose = verbose, phase_prefix = "Summary Stats")
  
  species_accumulation <- tryCatch({
    create_species_accumulation_summary(kpro_master)
  }, error = function(e) {
    stop(sprintf(
      "Failed to create species accumulation summary.\n  Original error: %s\n  Check that kpro_master has valid species and date data.",
      e$message
    ))
  })
  
  all_summaries$species_accumulation <- species_accumulation
  message("  [OK] Created species accumulation")
  
  # ===========================================================================
  # STAGE 12: HOURLY ACTIVITY SUMMARY
  # ===========================================================================
  
  log_stage_start("12", "Hourly Activity Summary", verbose = verbose, phase_prefix = "Summary Stats")
  
  hourly_summary <- tryCatch({
    create_hourly_activity_summary(kpro_master)
  }, error = function(e) {
    stop(sprintf(
      "Failed to create hourly activity summary.\n  Temporal columns (Hour_local, DateTime_local) were validated in Stage 2, but summary generation failed.\n  Original error: %s\n  Check that kpro_master has valid temporal data.",
      e$message
    ))
  })
  
  all_summaries$hourly_summary_overall <- hourly_summary
  message("  [OK] Created hourly activity summary")
  
  # ===========================================================================
  # STAGE 13: EXPORT INDIVIDUAL CSV FILES
  # ===========================================================================
  
  log_stage_start("13", "Export Individual CSV Files", verbose = verbose, phase_prefix = "Summary Stats")
  
  # Load configuration for artifact outputs
  artifact_config <- study_params$artifact_outputs
  
  # If no artifact config, use deterministic defaults optimized for Quarto-inline reports
  if (is.null(artifact_config)) {
    if (verbose) message("  [i] No artifact_outputs configuration found - using defaults (GT pre-render exports disabled; Quarto-inline expected)")
    artifact_config <- list(
      csv_detector_summary = TRUE,
      csv_study_summary = TRUE,
      csv_species_summary = TRUE,
      csv_species_accumulation = TRUE,
      csv_hourly_summary_overall = TRUE,
      csv_variance_components = TRUE,
      summary_stats_excel = TRUE,
      png_detector_summary = FALSE,
      png_study_summary = FALSE,
      png_species_summary = FALSE,
      png_hourly_summary_overall = FALSE,
      html_detector_summary = FALSE,
      html_study_summary = FALSE,
      html_species_summary = FALSE,
      html_hourly_summary_overall = FALSE,
      rds_summary_data = TRUE
    )
  }
  
  # Helper function to check if artifact should be generated
  should_export <- function(config_key) {
    result <- isTRUE(artifact_config[[config_key]]) || 
              (is.character(artifact_config[[config_key]]) && 
               tolower(artifact_config[[config_key]]) == "yes")
    return(result)
  }
  
  # Create CSV output directory
  csv_output_dir <- here::here("results", "csv", "summary_stats")
  assert_directory_exists(csv_output_dir, create = TRUE)
  
  timestamp_05 <- format(Sys.time(), "%Y%m%d")
  csv_files <- c()  # Track CSV files for Excel compilation
  csv_exports <- 0

  export_summary_csv_artifact <- function(summary_df,
                                          config_key,
                                          file_prefix,
                                          artifact_name_prefix,
                                          metadata,
                                          registry,
                                          csv_files,
                                          excel_sheet_name = NULL,
                                          transform_fn = NULL) {
    if (is.null(summary_df) || !should_export(config_key)) {
      return(list(
        registry = registry,
        csv_files = csv_files,
        csv_exports = 0L
      ))
    }

    export_df <- if (is.null(transform_fn)) summary_df else transform_fn(summary_df)
    csv_file <- sprintf("%s_%s.csv", file_prefix, timestamp_05)

    registry <- save_summary_csv(
      export_df,
      csv_file,
      output_dir = csv_output_dir,
      registry = registry,
      artifact_name = sprintf("%s_%s", artifact_name_prefix, timestamp_05),
      metadata = metadata,
      verbose = verbose
    )

    if (!is.null(excel_sheet_name)) {
      csv_path <- attr(registry, "file_path")
      csv_files[excel_sheet_name] <- csv_path
    }

    list(
      registry = registry,
      csv_files = csv_files,
      csv_exports = 1L
    )
  }
  
  detector_csv <- export_summary_csv_artifact(
    summary_df = all_summaries$detector_summary,
    config_key = "csv_detector_summary",
    file_prefix = "detector_summary",
    artifact_name_prefix = "csv_detector_summary",
    metadata = list(n_detectors = nrow(all_summaries$detector_summary)),
    registry = registry,
    csv_files = csv_files,
    excel_sheet_name = "Detector Summary"
  )
  registry <- detector_csv$registry
  csv_files <- detector_csv$csv_files
  csv_exports <- csv_exports + detector_csv$csv_exports

  study_csv <- export_summary_csv_artifact(
    summary_df = all_summaries$study_summary,
    config_key = "csv_study_summary",
    file_prefix = "study_summary",
    artifact_name_prefix = "csv_study_summary",
    metadata = list(
      n_detectors = all_summaries$study_summary$n_detectors,
      total_calls = all_summaries$study_summary$total_calls
    ),
    registry = registry,
    csv_files = csv_files,
    excel_sheet_name = "Study Summary",
    transform_fn = function(df) as.data.frame(t(as.matrix(df)))
  )
  registry <- study_csv$registry
  csv_files <- study_csv$csv_files
  csv_exports <- csv_exports + study_csv$csv_exports

  species_csv <- export_summary_csv_artifact(
    summary_df = all_summaries$species_summary,
    config_key = "csv_species_summary",
    file_prefix = "species_summary",
    artifact_name_prefix = "csv_species_summary",
    metadata = list(
      n_species = length(unique(all_summaries$species_summary$species)),
      n_detectors = length(unique(all_summaries$species_summary$Detector))
    ),
    registry = registry,
    csv_files = csv_files,
    excel_sheet_name = "Species by Detector"
  )
  registry <- species_csv$registry
  csv_files <- species_csv$csv_files
  csv_exports <- csv_exports + species_csv$csv_exports

  species_accumulation_csv <- export_summary_csv_artifact(
    summary_df = all_summaries$species_accumulation,
    config_key = "csv_species_accumulation",
    file_prefix = "species_accumulation",
    artifact_name_prefix = "csv_species_accumulation",
    metadata = list(
      final_richness = max(all_summaries$species_accumulation$cumulative_species, na.rm = TRUE),
      n_nights = nrow(all_summaries$species_accumulation)
    ),
    registry = registry,
    csv_files = csv_files,
    excel_sheet_name = "Species Accumulation"
  )
  registry <- species_accumulation_csv$registry
  csv_files <- species_accumulation_csv$csv_files
  csv_exports <- csv_exports + species_accumulation_csv$csv_exports

  hourly_csv <- export_summary_csv_artifact(
    summary_df = all_summaries$hourly_summary_overall,
    config_key = "csv_hourly_summary_overall",
    file_prefix = "hourly_summary_overall",
    artifact_name_prefix = "csv_hourly_summary",
    metadata = list(n_hours = nrow(all_summaries$hourly_summary_overall)),
    registry = registry,
    csv_files = csv_files,
    excel_sheet_name = "Hourly Profile"
  )
  registry <- hourly_csv$registry
  csv_files <- hourly_csv$csv_files
  csv_exports <- csv_exports + hourly_csv$csv_exports

  variance_csv <- export_summary_csv_artifact(
    summary_df = all_summaries$variance_components,
    config_key = "csv_variance_components",
    file_prefix = "variance_components",
    artifact_name_prefix = "csv_variance_components",
    metadata = list(n_components = length(all_summaries$variance_components)),
    registry = registry,
    csv_files = csv_files,
    transform_fn = function(df) {
      data.frame(
        component = names(df),
        value = unlist(df),
        row.names = NULL
      )
    }
  )
  registry <- variance_csv$registry
  csv_files <- variance_csv$csv_files
  csv_exports <- csv_exports + variance_csv$csv_exports
  
  if (verbose) message(sprintf("  [OK] Exported %d CSV files", csv_exports))
  
  # ===========================================================================
  # STAGE 14: BUILD EXCEL WORKBOOK FROM SUMMARY TIBBLES
  # ===========================================================================
  
  log_stage_start("14", "Build Excel Workbook from Summary Tibbles", verbose = verbose, phase_prefix = "Summary Stats")
  
  has_openxlsx <- requireNamespace("openxlsx", quietly = TRUE)
  
  if (has_openxlsx && should_export("summary_stats_excel")) {
    xlsx_file <- here::here("results", "xlsx", sprintf("summary_stats_%s.xlsx", timestamp_05))
    
    # Ensure xlsx directory exists
    xlsx_dir <- dirname(xlsx_file)
    assert_directory_exists(xlsx_dir, create = TRUE)
    
    # Define sheet names for cleaner Excel presentation
    sheet_names <- c(
      detector_summary = "Detector Activity",
      study_summary = "Study Overview",
      species_summary = "Species Composition",
      species_accumulation = "Species Accumulation",
      hourly_summary_overall = "Hourly Profile",
      variance_components = "Variance Components"
    )
    
    registry <- build_excel_from_summaries(
      summary_list = all_summaries,
      output_file = xlsx_file,
      sheet_names = sheet_names,
      registry = registry,
      artifact_name = sprintf("summary_stats_xlsx_%s", timestamp_05),
      phase_id = "summary_stats",
      metadata = list(
        generated_from = "summary_tibbles"
      ),
      verbose = verbose
    )
  } else if (!has_openxlsx) {
    if (verbose) message("  [SKIP] openxlsx not installed - Excel export skipped")
  } else {
    if (verbose) message("  [SKIP] Excel workbook (disabled in config)")
  }
  
  # ===========================================================================
  # STAGE 15: EXPORT SUMMARY TABLES (PNG/HTML)
  # ===========================================================================
  
  log_stage_start("15", "Export Summary Tables (PNG/HTML)", verbose = verbose, phase_prefix = "Summary Stats")
  
  tables_exported <- 0
  png_exports <- 0
  html_exports <- 0
  table_output_dir <- here::here("results", "figures")
  assert_directory_exists(table_output_dir, create = TRUE)
  
  has_webshot2 <- requireNamespace("webshot2", quietly = TRUE)
  
  detector_exports <- export_summary_gt_artifact(
    summary_df = all_summaries$detector_summary,
    formatter_fn = format_detector_summary_gt,
    base_name = "detector_summary",
    output_dir = table_output_dir,
    timestamp = timestamp_05,
    export_png = should_export("png_detector_summary"),
    export_html = should_export("html_detector_summary"),
    has_webshot2 = has_webshot2,
    error_label = "detector activity",
    verbose = verbose
  )
  png_exports <- png_exports + detector_exports$png_exports
  html_exports <- html_exports + detector_exports$html_exports

  study_exports <- export_summary_gt_artifact(
    summary_df = all_summaries$study_summary,
    formatter_fn = format_study_summary_gt,
    base_name = "study_summary",
    output_dir = table_output_dir,
    timestamp = timestamp_05,
    export_png = should_export("png_study_summary"),
    export_html = should_export("html_study_summary"),
    has_webshot2 = has_webshot2,
    error_label = "study summary",
    verbose = verbose
  )
  png_exports <- png_exports + study_exports$png_exports
  html_exports <- html_exports + study_exports$html_exports

  species_exports <- export_summary_gt_artifact(
    summary_df = all_summaries$species_summary,
    formatter_fn = format_species_summary_gt,
    base_name = "species_summary",
    output_dir = table_output_dir,
    timestamp = timestamp_05,
    export_png = should_export("png_species_summary"),
    export_html = should_export("html_species_summary"),
    has_webshot2 = has_webshot2,
    error_label = "species summary",
    verbose = verbose,
    png_success_message = "  [OK] Exported species summary PNG"
  )
  png_exports <- png_exports + species_exports$png_exports
  html_exports <- html_exports + species_exports$html_exports

  hourly_exports <- export_summary_gt_artifact(
    summary_df = all_summaries$hourly_summary_overall,
    formatter_fn = format_hourly_summary_gt,
    base_name = "hourly_summary_overall",
    output_dir = table_output_dir,
    timestamp = timestamp_05,
    export_png = should_export("png_hourly_summary_overall"),
    export_html = should_export("html_hourly_summary_overall"),
    has_webshot2 = has_webshot2,
    error_label = "hourly activity",
    verbose = verbose,
    png_success_message = "  [OK] Exported hourly activity summary PNG"
  )
  png_exports <- png_exports + hourly_exports$png_exports
  html_exports <- html_exports + hourly_exports$html_exports
  
  tables_exported <- png_exports + html_exports
  
  if (verbose) {
    message(sprintf("  [OK] Exported %d PNG tables", png_exports))
    message(sprintf("  [OK] Exported %d HTML tables", html_exports))
  }
  
  # ===========================================================================
  # STAGE 16: SAVE SUMMARY RDS ARCHIVE
  # ===========================================================================
  
  log_stage_start("16", "Save Summary RDS Archive", verbose = verbose, phase_prefix = "Summary Stats")
  
  summary_rds_path <- NULL
  
  if (should_export("rds_summary_data")) {
    summary_rds_path <- here::here("results", "rds", sprintf("summary_data_%s.rds", timestamp_05))
    
    # Add metadata element required by validate_rds_structure()
    all_summaries$metadata <- list(
      generated = Sys.time(),
      study_name = study_params$study_parameters$study_name %||% "Unknown",
      n_detectors = dplyr::n_distinct(calls_per_night_final$Detector),
      n_nights = dplyr::n_distinct(calls_per_night_final$Night),
      has_species = TRUE,
      has_temporal = TRUE
    )
    
    registry <- save_and_register_rds(
      object = all_summaries,
      file_path = summary_rds_path,
      artifact_type = "summary_stats",
      phase_id = "summary_stats",
      registry = registry,
      metadata = list(
        n_summaries = length(all_summaries),
        has_species = TRUE,
        has_temporal = TRUE,
        csv_artifacts_count = length(csv_files)
      ),
      verbose = verbose
    )
  } else {
    if (verbose) message("  [SKIP] RDS archive (disabled in config)")
  }
  
  if (verbose) message("  [OK] All CSV artifacts registered individually with SHA256 hashes")
  
  # ===========================================================================
  # FINALIZE AND RETURN
  # ===========================================================================
  
  validation_html <- finalize_stage_validation_report(
    validation_context = validation_context,
    stage_name = "SUMMARY STATISTICS",
    verbose = verbose
  )
  
  result$summary_stats <- list(
    all_summaries = all_summaries,
    summary_rds = summary_rds_path,
    files_created = files_created,
    has_species = TRUE,
    has_temporal = TRUE,
    tables_exported = tables_exported
  )
  
  result$validation_html_paths <- c(result$validation_html_paths, validation_html)

  result$checkpoint_path <- summary_rds_path %||% if (length(files_created) > 0) files_created[[1]] else NULL
  result$artifact_ids <- setdiff(names(registry$artifacts %||% list()), artifact_names_before)
  
  result$summary <- list(
    n_detectors = dplyr::n_distinct(calls_per_night_final$Detector),
    total_calls = sum(calls_per_night_final$CallsPerNight),
    summaries_generated = length(all_summaries) - 1,  # Exclude metadata
    csv_files_exported = csv_exports,
    tables_exported = tables_exported
  )
  
  return(result)
}


# ==============================================================================
# END OF FILE
# ==============================================================================
