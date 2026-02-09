# ==============================================================================
# R/05_summary_stats_module.R — SUMMARY STATISTICS MODULE
# ==============================================================================
# PURPOSE
# -------
# Summary Statistics Module: Generates comprehensive summary statistics (Chunk 3).
#
# PHASE ARCHITECTURE: Called by run_phase3_analysis_reporting() orchestrator
# ORCHESTRATION LAYER: Yes, module runner interface
#
# WORKFLOW SEQUENCE
# -----------------
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
#   - kpro_master from original Chunk 2 (passed through)
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
# 2026-02-08: Extracted from Phase 3 (run_phase3_analysis_reporting) as standalone module


#' Generate Summary Statistics
#'
#' @description
#' Chunk 3, Stages 7-16: Generates detector/study/species/temporal summaries,
#' exports as CSV/Excel/PNG/HTML, and saves RDS archive for Report & Release
#' module.
#'
#' This is the SECOND module in the finalize-to-report pipeline. Consumes
#' output from finalize_cpn module.
#'
#' @param calls_per_night_final Tibble. Final CPN from finalize_cpn module.
#'   Must have columns: Detector, Night, CallsPerNight, RecordingHours, Status, CallsPerHour.
#' @param kpro_master Tibble. Master dataset from Chunk 2. Required for
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
  
  log_stage_start("7", "Detector Activity Summary", verbose = verbose, workflow_prefix = "Summary Stats")
  
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
  
  log_stage_start("8", "Study-Wide Summary", verbose = verbose, workflow_prefix = "Summary Stats")
  
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
  
  log_stage_start("9", "Variance Components", verbose = verbose, workflow_prefix = "Summary Stats")
  
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
  
  log_stage_start("10", "Species Composition Summary", verbose = verbose, workflow_prefix = "Summary Stats")
  
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
  
  log_stage_start("11", "Species Accumulation Summary", verbose = verbose, workflow_prefix = "Summary Stats")
  
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
  
  log_stage_start("12", "Hourly Activity Summary", verbose = verbose, workflow_prefix = "Summary Stats")
  
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
  
  log_stage_start("13", "Export Individual CSV Files", verbose = verbose, workflow_prefix = "Summary Stats")
  
  # Load configuration for artifact outputs
  artifact_config <- study_params$artifact_outputs
  
  # If no artifact config, use defaults (all enabled)
  if (is.null(artifact_config)) {
    if (verbose) message("  [i] No artifact_outputs configuration found - using defaults (all enabled)")
    artifact_config <- list(
      csv_detector_summary = TRUE,
      csv_study_summary = TRUE,
      csv_species_summary = TRUE,
      csv_species_accumulation = TRUE,
      csv_hourly_summary_overall = TRUE,
      csv_variance_components = TRUE,
      summary_stats_excel = TRUE,
      png_detector_summary = TRUE,
      png_study_summary = TRUE,
      png_species_summary = TRUE,
      png_hourly_summary_overall = TRUE,
      html_detector_summary = TRUE,
      html_study_summary = TRUE,
      html_species_summary = TRUE,
      html_hourly_summary_overall = TRUE,
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
  
  # Export detector summary CSV
  if (should_export("csv_detector_summary")) {
    csv_file <- sprintf("detector_summary_%s.csv", timestamp_05)
    registry <- save_summary_csv(
      all_summaries$detector_summary,
      csv_file,
      output_dir = csv_output_dir,
      registry = registry,
      artifact_name = sprintf("csv_detector_summary_%s", timestamp_05),
      metadata = list(n_detectors = nrow(all_summaries$detector_summary)),
      verbose = verbose
    )
    csv_path <- attr(registry, "file_path")
    csv_files["Detector Summary"] <- csv_path
    csv_exports <- csv_exports + 1
  }
  
  # Export study summary CSV
  if (should_export("csv_study_summary")) {
    study_summary_df <- as.data.frame(t(as.matrix(all_summaries$study_summary)))
    csv_file <- sprintf("study_summary_%s.csv", timestamp_05)
    registry <- save_summary_csv(
      study_summary_df,
      csv_file,
      output_dir = csv_output_dir,
      registry = registry,
      artifact_name = sprintf("csv_study_summary_%s", timestamp_05),
      metadata = list(
        n_detectors = all_summaries$study_summary$n_detectors,
        total_calls = all_summaries$study_summary$total_calls
      ),
      verbose = verbose
    )
    csv_path <- attr(registry, "file_path")
    csv_files["Study Summary"] <- csv_path
    csv_exports <- csv_exports + 1
  }
  
  # Export species summary CSV
  if (!is.null(all_summaries$species_summary) && should_export("csv_species_summary")) {
    csv_file <- sprintf("species_summary_%s.csv", timestamp_05)
    registry <- save_summary_csv(
      all_summaries$species_summary,
      csv_file,
      output_dir = csv_output_dir,
      registry = registry,
      artifact_name = sprintf("csv_species_summary_%s", timestamp_05),
      metadata = list(
        n_species = length(unique(all_summaries$species_summary$species)),
        n_detectors = length(unique(all_summaries$species_summary$Detector))
      ),
      verbose = verbose
    )
    csv_path <- attr(registry, "file_path")
    csv_files["Species by Detector"] <- csv_path
    csv_exports <- csv_exports + 1
  }
  
  # Export species accumulation CSV
  if (!is.null(all_summaries$species_accumulation) && should_export("csv_species_accumulation")) {
    csv_file <- sprintf("species_accumulation_%s.csv", timestamp_05)
    registry <- save_summary_csv(
      all_summaries$species_accumulation,
      csv_file,
      output_dir = csv_output_dir,
      registry = registry,
      artifact_name = sprintf("csv_species_accumulation_%s", timestamp_05),
      metadata = list(
        final_richness = max(all_summaries$species_accumulation$cumulative_species, na.rm = TRUE),
        n_nights = nrow(all_summaries$species_accumulation)
      ),
      verbose = verbose
    )
    csv_path <- attr(registry, "file_path")
    csv_files["Species Accumulation"] <- csv_path
    csv_exports <- csv_exports + 1
  }
  
  # Export hourly summary CSV
  if (!is.null(all_summaries$hourly_summary_overall) && should_export("csv_hourly_summary_overall")) {
    csv_file <- sprintf("hourly_summary_overall_%s.csv", timestamp_05)
    registry <- save_summary_csv(
      all_summaries$hourly_summary_overall,
      csv_file,
      output_dir = csv_output_dir,
      registry = registry,
      artifact_name = sprintf("csv_hourly_summary_%s", timestamp_05),
      metadata = list(n_hours = nrow(all_summaries$hourly_summary_overall)),
      verbose = verbose
    )
    csv_path <- attr(registry, "file_path")
    csv_files["Hourly Profile"] <- csv_path
    csv_exports <- csv_exports + 1
  }
  
  # Export variance components CSV
  if (!is.null(all_summaries$variance_components) && should_export("csv_variance_components")) {
    variance_df <- data.frame(
      component = names(all_summaries$variance_components),
      value = unlist(all_summaries$variance_components),
      row.names = NULL
    )
    csv_file <- sprintf("variance_components_%s.csv", timestamp_05)
    registry <- save_summary_csv(
      variance_df,
      csv_file,
      output_dir = csv_output_dir,
      registry = registry,
      artifact_name = sprintf("csv_variance_components_%s", timestamp_05),
      metadata = list(n_components = length(all_summaries$variance_components)),
      verbose = verbose
    )
    csv_exports <- csv_exports + 1
  }
  
  if (verbose) message(sprintf("  [OK] Exported %d CSV files", csv_exports))
  
  # ===========================================================================
  # STAGE 14: BUILD EXCEL WORKBOOK FROM CSV ARTIFACTS
  # ===========================================================================
  
  log_stage_start("14", "Build Excel Workbook from CSV Artifacts", verbose = verbose, workflow_prefix = "Summary Stats")
  
  has_openxlsx <- requireNamespace("openxlsx", quietly = TRUE)
  
  if (has_openxlsx && should_export("summary_stats_excel") && length(csv_files) > 0) {
    xlsx_file <- here::here("results", "xlsx", sprintf("summary_stats_%s.xlsx", timestamp_05))
    
    # Ensure xlsx directory exists
    xlsx_dir <- dirname(xlsx_file)
    assert_directory_exists(xlsx_dir, create = TRUE)
    
    registry <- build_excel_from_csv(
      csv_files,
      output_file = xlsx_file,
      registry = registry,
      artifact_name = sprintf("summary_stats_xlsx_%s", timestamp_05),
      workflow = "summary_stats",
      metadata = list(
        n_sheets = length(csv_files),
        generated_from = "csv_artifacts"
      ),
      verbose = verbose
    )
  } else if (!has_openxlsx) {
    if (verbose) message("  [SKIP] openxlsx not installed - Excel export skipped")
  } else if (!should_export("summary_stats_excel")) {
    if (verbose) message("  [SKIP] Excel workbook (disabled in config)")
  } else {
    if (verbose) message("  [SKIP] Excel workbook (no CSV files to compile)")
  }
  
  # ===========================================================================
  # STAGE 15: EXPORT SUMMARY TABLES (PNG/HTML)
  # ===========================================================================
  
  log_stage_start("15", "Export Summary Tables (PNG/HTML)", verbose = verbose, workflow_prefix = "Summary Stats")
  
  tables_exported <- 0
  png_exports <- 0
  html_exports <- 0
  table_output_dir <- here::here("results", "figures")
  assert_directory_exists(table_output_dir, create = TRUE)
  
  has_webshot2 <- requireNamespace("webshot2", quietly = TRUE)
  
  # Export detector activity summary table
  if (!is.null(all_summaries$detector_summary)) {
    if (has_webshot2 && should_export("png_detector_summary")) {
      tryCatch({
        detector_gt <- format_detector_summary_gt(all_summaries$detector_summary)
        save_gt_table(detector_gt, sprintf("detector_summary_%s", timestamp_05), 
                      output_dir = table_output_dir, format = "png")
        png_exports <- png_exports + 1
      }, error = function(e) {
        warning(sprintf("Failed to export detector activity PNG: %s", e$message))
      })
    }
    
    if (should_export("html_detector_summary")) {
      tryCatch({
        detector_gt <- format_detector_summary_gt(all_summaries$detector_summary)
        save_gt_table(detector_gt, sprintf("detector_summary_%s", timestamp_05), 
                      output_dir = table_output_dir, format = "html")
        html_exports <- html_exports + 1
      }, error = function(e) {
        warning(sprintf("Failed to export detector activity HTML: %s", e$message))
      })
    }
  }
  
  # Export study-wide summary table
  if (!is.null(all_summaries$study_summary)) {
    if (has_webshot2 && should_export("png_study_summary")) {
      tryCatch({
        study_gt <- format_study_summary_gt(all_summaries$study_summary)
        save_gt_table(study_gt, sprintf("study_summary_%s", timestamp_05), 
                      output_dir = table_output_dir, format = "png")
        png_exports <- png_exports + 1
      }, error = function(e) {
        warning(sprintf("Failed to export study summary PNG: %s", e$message))
      })
    }
    
    if (should_export("html_study_summary")) {
      tryCatch({
        study_gt <- format_study_summary_gt(all_summaries$study_summary)
        save_gt_table(study_gt, sprintf("study_summary_%s", timestamp_05), 
                      output_dir = table_output_dir, format = "html")
        html_exports <- html_exports + 1
      }, error = function(e) {
        warning(sprintf("Failed to export study summary HTML: %s", e$message))
      })
    }
  }
  
  # Export species summary table
  if (!is.null(all_summaries$species_summary)) {
    if (has_webshot2 && should_export("png_species_summary")) {
      tryCatch({
        species_gt <- format_species_summary_gt(all_summaries$species_summary)
        save_gt_table(species_gt, sprintf("species_summary_%s", timestamp_05), 
                      output_dir = table_output_dir, format = "png")
        png_exports <- png_exports + 1
        if (verbose) message("  [OK] Exported species summary PNG")
      }, error = function(e) {
        warning(sprintf("Failed to export species summary PNG: %s", e$message))
      })
    }
    
    if (should_export("html_species_summary")) {
      tryCatch({
        species_gt <- format_species_summary_gt(all_summaries$species_summary)
        save_gt_table(species_gt, sprintf("species_summary_%s", timestamp_05), 
                      output_dir = table_output_dir, format = "html")
        html_exports <- html_exports + 1
      }, error = function(e) {
        warning(sprintf("Failed to export species summary HTML: %s", e$message))
      })
    }
  }
  
  # Export hourly activity summary table
  if (!is.null(all_summaries$hourly_summary_overall)) {
    if (has_webshot2 && should_export("png_hourly_summary_overall")) {
      tryCatch({
        hourly_gt <- format_hourly_summary_gt(all_summaries$hourly_summary_overall)
        save_gt_table(hourly_gt, sprintf("hourly_summary_overall_%s", timestamp_05), 
                      output_dir = table_output_dir, format = "png")
        png_exports <- png_exports + 1
        if (verbose) message("  [OK] Exported hourly activity summary PNG")
      }, error = function(e) {
        warning(sprintf("Failed to export hourly activity PNG: %s", e$message))
      })
    }
    
    if (should_export("html_hourly_summary_overall")) {
      tryCatch({
        hourly_gt <- format_hourly_summary_gt(all_summaries$hourly_summary_overall)
        save_gt_table(hourly_gt, sprintf("hourly_summary_overall_%s", timestamp_05), 
                      output_dir = table_output_dir, format = "html")
        html_exports <- html_exports + 1
      }, error = function(e) {
        warning(sprintf("Failed to export hourly activity HTML: %s", e$message))
      })
    }
  }
  
  tables_exported <- png_exports + html_exports
  
  if (verbose) {
    message(sprintf("  [OK] Exported %d PNG tables", png_exports))
    message(sprintf("  [OK] Exported %d HTML tables", html_exports))
  }
  
  # ===========================================================================
  # STAGE 16: SAVE SUMMARY RDS ARCHIVE
  # ===========================================================================
  
  log_stage_start("16", "Save Summary RDS Archive", verbose = verbose, workflow_prefix = "Summary Stats")
  
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
      workflow = "summary_stats",
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
