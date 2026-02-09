# ============================================================================
# PHASE ORCHESTRATOR: run_phase3_analysis_reporting.R
# Purpose: Phase 3 - Analysis & Reporting (Finalize → Report)
# Phase: 3 of 3
# Modules: 4-7
# ============================================================================
# 
# Classification: Phase Orchestrator
# Subtitle: Coordinates finalization, statistics, visualization, and report generation
#
# Description:
# This phase orchestrator implements Phase 3 of the checkpointed pipeline.
# It coordinates the execution of Modules 4-7 (finalize CPN, summary statistics,
# plotting, and report release) and produces final analysis outputs.
#
# Checkpointed Phase Architecture:
#   PHASE 1: Data Preparation → kpro_master.csv checkpoint
#   PHASE 2: Template Generation → CPN_Template_EDIT_THIS.csv (HUMAN-IN-THE-LOOP)
#   PHASE 3: Analysis & Reporting → Final outputs
#
# Prerequisites:
#   - User MUST have edited the CPN_Template_EDIT_THIS.csv file from Phase 2
#   - Edited template is loaded automatically by Module 4 (finalize_cpn)
#
# Data Flow (This Phase):
#   Input:  Edited CPN template from Phase 2 (user-modified)
#   ├─→ Module 4: Finalize CPN → calls_per_night_final
#   ├─→ Module 5: Summary Statistics → all_summaries, summary_rds
#   ├─→ Module 6: Plotting → all_plots, plots_rds
#   ├─→ Module 7: Report & Release → Final report, release bundle
#   Output: HTML report, plots, release ZIP
#
# Module Execution:
#   - Calls run_module_finalize_cpn() from module_runner
#   - Calls run_module_summary_stats() from module_runner
#   - Calls run_module_plotting() from module_runner
#   - Calls run_module_report_release() from module_runner
#   - Passes structured results between modules
#
# Final Outputs:
#   - results/bat_activity_report.html
#   - results/figures/*.png (26 plots)
#   - results/csv/summary_stats/*.csv
#   - results/release_bundle_YYYYMMDD_HHMMSS.zip
#
# Dependencies:
#   - R/functions/load_all.R (master loader)
#   - R/modules/module_runner.R (module execution layer)
#
# Last Modified: 2026-02-08
# Note: Phase-based orchestrator using module execution layer
#
# ============================================================================

#' Run Phase 3: Analysis & Reporting
#'
#' @description
#' Phase 3 of 3 in the checkpointed pipeline. Executes finalization, statistics,
#' plotting, and report generation by calling module runners in sequence. Produces
#' final analysis outputs and release bundle.
#'
#' @param phase2_result Result from run_phase2_template_generation() (optional,
#'   mainly for metadata tracking).
#' @param edited_template_file Character. Path to edited template file (optional).
#'   If NULL, will use most recent EDIT_THIS template.
#' @param verbose Logical. Whether to print detailed progress messages.
#'   Default FALSE (silent operation).
#'
#' @return Named list containing:
#'   \itemize{
#'     \item \code{phase}: Phase number (3)
#'     \item \code{phase_name}: "Analysis & Reporting"
#'     \item \code{calls_per_night_final}: Final CPN tibble
#'     \item \code{report_path}: Path to generated HTML report
#'     \item \code{release_bundle_path}: Path to release ZIP
#'     \item \code{metadata}: List with output statistics
#'     \item \code{validation_html_paths}: Character vector of validation reports
#'     \item \code{pipeline_complete}: TRUE
#'   }
#'
#' @examples
#' \dontrun{
#' # Run Phase 3 (after editing template from Phase 2)
#' phase2_result <- run_phase2_template_generation(phase1_result, verbose = TRUE)
#' # [User edits template]
#' phase3_result <- run_phase3_analysis_reporting(
#'   phase2_result = phase2_result,
#'   verbose = TRUE
#' )
#' 
#' # Access final outputs
#' report_path <- phase3_result$report_path
#' release_bundle <- phase3_result$release_bundle_path
#' }
#'
#' @export
run_phase3_analysis_reporting <- function(phase2_result = NULL,
                                          edited_template_file = NULL,
                                          verbose = FALSE) {
  
  # ===========================================================================
  # INITIALIZATION
  # ===========================================================================
  
  # Load all utilities and module runners
  source(file.path("R", "functions", "load_all.R"))
  source(file.path("R", "modules", "module_runner.R"))
  
  # Initialize pipeline log
  initialize_pipeline_log()
  log_message("=== PHASE 3: Analysis & Reporting - START ===")
  
  if (verbose) {
    cat("\n")
    cat("========================================\n")
    cat("  PHASE 3: ANALYSIS & REPORTING\n")
    cat("========================================\n")
    cat("  Modules: 4-7\n")
    cat("  Final outputs: Report + Release bundle\n")
    cat("========================================\n")
    cat("\n")
  }
  
  # ===========================================================================
  # MODULE 4: FINALIZE CPN
  # ===========================================================================
  
  if (verbose) cat("\n>>> [Phase 3 - Module 4/7] Finalize CPN\n")
  
  # Extract template path from Phase 2 result if available
  if (is.null(edited_template_file) && !is.null(phase2_result)) {
    if ("template_edit_path" %in% names(phase2_result)) {
      edited_template_file <- phase2_result$template_edit_path
    }
  }
  
  module4_result <- tryCatch({
    run_module_finalize_cpn(
      cpn_template_result = phase2_result,
      edited_template_file = edited_template_file,
      verbose = verbose
    )
  }, error = function(e) {
    stop("Phase 3 - Module 4 (Finalize CPN) failed: ", e$message)
  })
  
  if (verbose) cat("✓ Module 4 complete\n")
  
  # ===========================================================================
  # MODULE 5: SUMMARY STATISTICS
  # ===========================================================================
  
  if (verbose) cat("\n>>> [Phase 3 - Module 5/7] Summary Statistics\n")
  
  module5_result <- tryCatch({
    run_module_summary_stats(
      finalize_result = module4_result,
      verbose = verbose
    )
  }, error = function(e) {
    stop("Phase 3 - Module 5 (Summary Statistics) failed: ", e$message)
  })
  
  if (verbose) cat("✓ Module 5 complete\n")
  
  # ===========================================================================
  # MODULE 6: PLOTTING
  # ===========================================================================
  
  if (verbose) cat("\n>>> [Phase 3 - Module 6/7] Plotting\n")
  
  module6_result <- tryCatch({
    run_module_plotting(
      summary_stats_result = module5_result,
      verbose = verbose
    )
  }, error = function(e) {
    stop("Phase 3 - Module 6 (Plotting) failed: ", e$message)
  })
  
  if (verbose) cat("✓ Module 6 complete\n")
  
  # ===========================================================================
  # MODULE 7: REPORT & RELEASE
  # ===========================================================================
  
  if (verbose) cat("\n>>> [Phase 3 - Module 7/7] Report & Release\n")
  
  module7_result <- tryCatch({
    run_module_report_release(
      plotting_result = module6_result,
      summary_stats_result = module5_result,
      verbose = verbose
    )
  }, error = function(e) {
    stop("Phase 3 - Module 7 (Report & Release) failed: ", e$message)
  })
  
  if (verbose) cat("✓ Module 7 complete\n")
  
  # ===========================================================================
  # PHASE COMPLETION - PIPELINE COMPLETE
  # ===========================================================================
  
  calls_per_night_final <- module4_result$finalize_cpn$calls_per_night_final
  n_summaries <- length(module5_result$summary_stats$all_summaries)
  n_plots <- sum(unlist(module6_result$plotting$plot_counts))
  report_path <- module7_result$report_release$report_html
  release_bundle_path <- module7_result$report_release$release_zip
  
  log_message("=== PHASE 3 COMPLETE: Pipeline finished successfully ===")
  
  if (verbose) {
    cat("\n")
    cat("========================================\n")
    cat("  PHASE 3 COMPLETE\n")
    cat("========================================\n")
    cat(sprintf("  CPN rows: %s\n", format(nrow(calls_per_night_final), big.mark = ",")))
    cat(sprintf("  Summaries: %d\n", n_summaries))
    cat(sprintf("  Plots: %d\n", n_plots))
    cat(sprintf("  Report: %s\n", if(!is.null(report_path)) basename(report_path) else "NOT GENERATED"))
    cat(sprintf("  Release bundle: %s\n", if(!is.null(release_bundle_path)) basename(release_bundle_path) else "NOT CREATED"))
    cat("========================================\n")
    cat("\n")
    cat("✅  PIPELINE COMPLETE  ✅\n")
    cat("========================================\n")
    cat("  All phases executed successfully!\n")
    cat("  Review outputs:\n")
    cat(sprintf("  - Report: %s\n", if(!is.null(report_path)) report_path else "NOT GENERATED"))
    cat(sprintf("  - Bundle: %s\n", if(!is.null(release_bundle_path)) release_bundle_path else "NOT CREATED"))
    cat("========================================\n")
    cat("\n")
  }
  
  # ===========================================================================
  # RETURN PHASE RESULT
  # ===========================================================================
  
  # Collect all validation HTML paths from all modules
  all_validation_paths <- c(
    module4_result$validation_html_paths,
    module5_result$validation_html_paths,
    module6_result$validation_html_paths,
    module7_result$validation_html_paths
  )
  
  list(
    phase = 3,
    phase_name = "Analysis & Reporting",
    calls_per_night_final = calls_per_night_final,
    report_path = report_path,
    release_bundle_path = release_bundle_path,
    metadata = list(
      n_cpn_rows = nrow(calls_per_night_final),
      n_summaries = n_summaries,
      n_plots = n_plots,
      report_generated = file.exists(report_path),
      release_bundle_created = file.exists(release_bundle_path)
    ),
    validation_html_paths = all_validation_paths,
    pipeline_complete = TRUE,
    
    # Raw module results (for advanced use)
    module_results = list(
      finalize_cpn = module4_result,
      summary_stats = module5_result,
      plotting = module6_result,
      report_release = module7_result
    )
  )
}


# ==============================================================================
# END OF FILE
# ==============================================================================
