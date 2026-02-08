# ==============================================================================
# R/07_report_release_module.R — REPORT & RELEASE MODULE
# ==============================================================================
# PURPOSE
# -------
# Extracted module from Chunk 3 orchestrator (run_finalize_to_report).
# Renders Quarto report and creates release bundle: Stages 22-25.
#
# EXTRACTED FROM: run_finalize_to_report.R (Lines ~1301-1450)
# ORCHESTRATION LAYER: Yes, called by run_finalize_to_report() orchestrator
#
# WORKFLOW SEQUENCE
# -----------------
# This module is called as the FINAL step in Chunk 3:
#   1. run_finalize_to_report() [orchestrator]
#      └→ finalize_cpn() — Stages 1-6
#      └→ module_summary_stats() — Stages 7-16
#      └→ module_plotting() — Stages 15-21
#      └→ module_report_release() [this module] — Stages 22-25
#
# INPUT REQUIREMENTS
# ------------------
# Parameters:
#   - calls_per_night_final: Tibble from finalize_cpn module
#   - kpro_master: Tibble (for context)
#   - all_summaries: List from module_summary_stats
#   - all_plots: List from module_plotting
#   - summary_rds_path: Path to RDS from module_summary_stats
#   - plots_rds_path: Path to RDS from module_plotting
#   - study_params: List from load_study_parameters()
#   - create_release_bundle: Boolean for ZIP creation
#   - registry: Artifact registry
#   - verbose: Boolean for console output
#
# OUTPUTS GUARANTEES
# -------------------
# Returns a list {report_release, validation_html_paths, summary}:
#   - report_release$report_html: Path to rendered HTML report
#   - report_release$release_zip: Path to ZIP bundle (or NULL)
#   - report_release$report_size_kb: File size of report
#   - validation_html_paths: Character vector (1 HTML file)
#   - summary: Metadata about report/release
#
# WRITES FILES
# -----------
#   - results/reports/bat_activity_report_*.html — Rendered Quarto report
#   - results/releases/*.zip — Release bundle with manifest
#   - results/validation/*.html — Validation report
#
# RELEASE BUNDLE CONTENTS
# ----------------------
# If create_release_bundle = TRUE:
#   - reports/bat_activity_report.html — Main deliverable
#   - data/CallsPerNight_final.csv — Final CPN data
#   - data/kpro_master.csv — Master dataset
#   - tables/detector_summary.csv — Summary statistics
#   - tables/study_summary.csv — Study-wide metrics
#   - figures/*.png — All 26 exploratory plots
#   - metadata/MANIFEST.txt — Provenance documentation
#   - metadata/study_parameters.yaml — Study configuration snapshot
#
# DEPENDENCY CHAIN
# ----------------
# **Previous module dependencies:**
#   - calls_per_night_final, all_summaries, all_plots from prior modules
#   - summary_rds_path from module_summary_stats
#   - plots_rds_path from module_plotting
#   - Master data and study parameters from Chunk 2
#
# **Internal stages:**
#   - Stages 22-25 sequentially: 22 → 23 → 24 → 25
#
# **Depends on:**
#   - reports/bat_activity_report.qmd: Quarto template
#   - functions/output/report.R: create_release_bundle function
#   - functions/core/utilities.R: new helper functions (render_report, create_and_register_release)
#   - functions/core/artifacts.R: validation logging
#
# CHANGELOG
# ---------
# 2026-02-08: Extracted from run_finalize_to_report.R as standalone module


#' Render Report and Create Release Bundle
#'
#' @description
#' Chunk 3, Stages 22-25: Verifies RDS artifacts, renders Quarto report with
#' embedded summaries and plots, creates portable ZIP release bundle, and
#' generates final validation report.
#'
#' This is the FINAL module in the finalize-to-report pipeline. Consumes all
#' outputs from prior modules (finalize_cpn, summary_stats, plotting) to
#' produce the main project deliverables.
#'
#' @param calls_per_night_final Tibble. Final CPN from finalize_cpn module.
#' @param kpro_master Tibble. Master dataset (for context/bundle inclusion).
#' @param all_summaries List. Summary statistics from module_summary_stats.
#' @param all_plots List. Plot objects from module_plotting.
#' @param summary_rds_path Character. Path to summary_data RDS file.
#' @param plots_rds_path Character. Path to plot_objects RDS file.
#' @param study_params List. Study parameters from load_study_parameters().
#' @param yaml_path Character. Path to study_parameters.yaml. Default: uses here::here().
#' @param create_release_bundle Logical. Whether to create ZIP bundle.
#'   Default: TRUE.
#' @param registry List. Artifact registry (will be updated). Default: NULL.
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return List with elements:
#'   - report_release: List containing:
#'     - report_html: Path to rendered HTML
#'     - release_zip: Path to ZIP bundle (or NULL if not created)
#'     - report_size_kb: File size of report
#'   - validation_html_paths: Character vector with validation report path
#'   - summary: Metadata list
#'
#' @details
#' **Stages executed:**
#'   - Stage 22: Verify RDS artifacts exist and have correct structure
#'   - Stage 23: Render Quarto report with embedded summaries + plots
#'   - Stage 24: Create ZIP release bundle (if requested)
#'   - Stage 25: Finalize validation reporting
#'
#' **Quarto Report Parameters:**
#'   The report receives these execute_params:
#'   - summary_rds: Path to summary statistics RDS
#'   - plots_rds: Path to plot objects RDS
#'   - study_params_path: Path to study YAML
#'
#'   The template (reports/bat_activity_report.qmd) uses these parameters
#'   to load and embed all summaries and visualizations.
#'
#' **Release Bundle:**
#'   - Portable ZIP file with all deliverables
#'   - Can be extracted on any machine for standalone viewing
#'   - Includes MANIFEST.txt with provenance documentation
#'   - Includes metadata/study_parameters.yaml for reproducibility
#'   - Size typically 50-300 MB depending on plot resolution
#'
#' @section CONTRACT:
#' - Verifies RDS structure before rendering (warns but doesn't stop)
#' - Renders report using all execute_params
#' - Creates ZIP only if render succeeds
#' - Logs all stages with validation context
#' - Returns structured output with all paths
#' - Does NOT modify input data
#'
#' @export
module_report_release <- function(calls_per_night_final,
                                  kpro_master,
                                  all_summaries,
                                  all_plots,
                                  summary_rds_path,
                                  plots_rds_path,
                                  study_params,
                                  yaml_path = NULL,
                                  create_release_bundle = TRUE,
                                  registry = NULL,
                                  verbose = FALSE) {
  
  # ===========================================================================
  # INITIALIZATION
  # ===========================================================================
  
  print_stage_banner("REPORT & RELEASE", verbose = verbose)
  
  # Ensure registry exists
  if (is.null(registry)) {
    registry <- list()
  }
  
  result <- list(report_release = list(), validation_html_paths = character())
  
  # Create validation context
  validation_context <- init_stage_validation("report_release", study_params)
  
  # Set default yaml_path if not provided
  if (is.null(yaml_path)) {
    yaml_path <- here::here("inst", "config", "study_parameters.yaml")
  }
  
  # ===========================================================================
  # STAGE 22: VERIFY RDS ARTIFACTS
  # ===========================================================================
  
  log_stage_start("22", "Verify RDS Artifacts", verbose = verbose, workflow_prefix = "Report & Release")
  
  # Load and validate RDS structure
  if (!file.exists(summary_rds_path)) {
    stop("Summary RDS not found: ", summary_rds_path)
  }
  
  if (!file.exists(plots_rds_path)) {
    stop("Plots RDS not found: ", plots_rds_path)
  }
  
  # Load RDS files
  all_summaries_for_report <- readRDS(summary_rds_path)
  all_plots_for_report <- readRDS(plots_rds_path)
  
  # Validate RDS structure
  rds_validation <- tryCatch({
    validate_rds_structure(summary_rds_path, plots_rds_path)
  }, error = function(e) {
    list(valid = FALSE, errors = e$message)
  })
  
  if (!rds_validation$valid) {
    warning(sprintf("RDS structure validation warnings:\n  %s",
                    paste(rds_validation$errors, collapse = "\n  ")))
    
    validation_context <- log_validation_event(
      validation_context,
      event_type = "warning",
      description = "RDS structure validation issues detected",
      details = list(errors = rds_validation$errors)
    )
  } else {
    if (verbose) {
      plot_count <- if (!is.null(rds_validation$total_plots)) {
        rds_validation$total_plots
      } else {
        sum(sapply(all_plots_for_report, length))
      }
      message(sprintf("  [OK] RDS validation passed: %d summaries, %d plots",
                      length(all_summaries_for_report), plot_count))
    }
  }
  
  if (verbose) message("  [OK] All RDS artifacts verified")
  
  # ===========================================================================
  # STAGE 23: RENDER QUARTO REPORT
  # ===========================================================================
  
  log_stage_start("23", "Render Quarto Report", verbose = verbose, workflow_prefix = "Report & Release")
  
  qmd_template <- here::here("reports", "bat_activity_report.qmd")
  
  report_html_path <- NULL
  render_success <- FALSE
  
  if (file.exists(qmd_template)) {
    
    timestamp_07 <- format(Sys.time(), "%Y%m%d")
    report_filename <- sprintf("bat_activity_report_%s.html", timestamp_07)
    
    # Use new render_report helper
    render_result <- render_report(
      qmd_template = qmd_template,
      output_file = report_filename,
      output_dir = here::here("results", "reports"),
      params = list(
        summary_rds = summary_rds_path,
        plots_rds = plots_rds_path,
        study_params_path = yaml_path
      ),
      verbose = verbose
    )
    
    if (render_result$success) {
      report_html_path <- render_result$output_path
      render_success <- TRUE
      
      validation_context <- log_validation_event(
        validation_context,
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
  
  log_message(sprintf("[Report & Release - Stage 23] Report rendering: %s", 
                      if(render_success) "SUCCESS" else "SKIPPED"))
  
  # ===========================================================================
  # STAGE 24: CREATE RELEASE BUNDLE
  # ===========================================================================
  
  log_stage_start("24", "Create Release Bundle", verbose = verbose, workflow_prefix = "Report & Release")
  
  release_zip_path <- NULL
  
  if (create_release_bundle && render_success) {
    
    release_result <- create_and_register_release(
      study_id = study_params$study_parameters$study_name,
      calls_per_night_final = calls_per_night_final,
      kpro_master = kpro_master,
      all_summaries = all_summaries,
      all_plots = all_plots,
      report_path = report_html_path,
      study_params = study_params,
      output_dir = here::here("results", "releases"),
      registry = registry,
      quiet = !verbose
    )
    
    if (release_result$success) {
      release_zip_path <- release_result$zip_path
      
      if (verbose) message(sprintf("  [OK] Release bundle: %s", basename(release_zip_path)))
      
      validation_context <- log_validation_event(
        validation_context,
        event_type = "release_created",
        description = "Release bundle created",
        details = list(
          file = basename(release_zip_path),
          size_kb = file.size(release_zip_path) / 1024
        )
      )
    } else {
      warning(sprintf("Release bundle creation failed: %s", release_result$message))
    }
  } else {
    if (verbose) message("  [!] Release bundle skipped")
  }
  
  log_message(sprintf("[Report & Release - Stage 24] Release bundle: %s", 
                      if(!is.null(release_zip_path)) "CREATED" else "SKIPPED"))
  
  # ===========================================================================
  # STAGE 25: FINALIZE VALIDATION
  # ===========================================================================
  
  log_stage_start("25", "Finalize Validation", verbose = verbose, workflow_prefix = "Report & Release")
  
  validation_html <- finalize_stage_validation_report(
    validation_context = validation_context,
    stage_name = "REPORT & RELEASE",
    verbose = verbose
  )
  
  log_message("=== REPORT & RELEASE: COMPLETE ===")
  
  # ===========================================================================
  # RETURN RESULTS
  # ===========================================================================
  
  result$report_release <- list(
    report_html = report_html_path,
    release_zip = release_zip_path,
    report_size_kb = if(!is.null(report_html_path) && file.exists(report_html_path)) 
      file.size(report_html_path) / 1024 else NA
  )
  
  result$validation_html_paths <- c(result$validation_html_paths, validation_html)
  
  result$summary <- list(
    report_generated = !is.null(report_html_path),
    report_size_kb = result$report_release$report_size_kb,
    release_bundle_created = !is.null(release_zip_path),
    release_size_kb = if(!is.null(release_zip_path)) 
      file.size(release_zip_path) / 1024 else NA
  )
  
  return(result)
}


# ==============================================================================
# END OF FILE
# ==============================================================================
