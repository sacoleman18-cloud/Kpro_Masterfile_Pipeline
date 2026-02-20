# ==============================================================================
# R/06_plotting_module.R — PLOTTING MODULE
# ==============================================================================
# PURPOSE
# -------
# Plotting Module: Generates exploratory visualizations (Phase 3).
#
# PHASE ARCHITECTURE: Called by run_phase3_analysis_reporting() orchestrator
# ORCHESTRATION LAYER: Yes, module runner interface
#
# EXECUTION SEQUENCE
# ------------------
# This module is called as the THIRD step in Phase 3:
#   1. run_phase3_analysis_reporting() [phase orchestrator]
#      └→ run_module_finalize_cpn() — Stages 1-6
#      └→ run_module_summary_stats() — Stages 7-16
#      └→ run_module_plotting() [this module] — Stages 15-21
#      └→ run_module_report_release() — Stages 22-25
#
# INPUT REQUIREMENTS
# ------------------
# Parameters:
#   - calls_per_night_final: Tibble from finalize_cpn module
#   - kpro_master: Tibble for species and temporal plots
#   - study_params: List from load_study_parameters()
#   - registry: Artifact registry (updated with new artifacts)
#   - verbose: Boolean for console output
#
# OUTPUTS GUARANTEES
# -------------------
# Returns a list {plotting, validation_html_paths, summary}:
#   - plotting$all_plots: Nested list with 4 categories:
#     - quality: 8 plots (recording status, completeness, effort)
#     - detector: 7 plots (activity, correlations, synchrony)
#     - species: 5 plots (composition, diversity, accumulation)
#     - temporal: 6 plots (trends, hourly, weekly, monthly)
#   - plotting$plots_rds: Path to RDS file with all plot objects
#   - plotting$files_created: Character vector of PNG file paths
#   - plotting$plot_counts: Named list of counts by category
#   - validation_html_paths: Character vector (1 HTML file)
#   - summary: Metadata about plots
#
# WRITES FILES
# -----------
#   - results/figures/png/quality/*.png — 8 quality plots
#   - results/figures/png/detector/*.png — 7 detector plots
#   - results/figures/png/species/*.png — 5 species plots
#   - results/figures/png/temporal/*.png — 6 temporal plots
#   - results/rds/plot_objects_*.rds — All ggplot object archive
#   - results/validation/*.html — Validation report
#
# PLOT COUNTS & CATEGORIES
# -------------------------
# **Quality (8):** Recording status summaries, assessment heatmaps
#   - plot_recording_status_summary()
#   - plot_recording_status_percent()
#   - plot_recording_status_overall()
#   - plot_effort_by_detector()
#   - plot_nights_by_detector()
#   - plot_data_completeness_calendar()
#   - plot_missing_nights()
#   - plot_recording_effort_heatmap()
#
# **Detector (7):** Activity comparisons and correlations
#   - plot_total_calls_by_detector()
#   - plot_detector_activity_caterpillar()
#   - plot_detector_boxplots()
#   - plot_activity_with_without_outliers()
#   - plot_synchrony()
#   - plot_correlation_heatmap()
#   - plot_detector_rank_over_time()
#
# **Species (5):** Composition and diversity (conditional on species data)
#   - plot_species_composition_bar()
#   - plot_species_by_detector_heatmap()
#   - plot_species_accumulation_curve()
#   - plot_species_hourly_profile()
#   - plot_noid_proportion()
#
# **Temporal (6):** Time-based patterns
#   - plot_activity_over_time()
#   - plot_cumulative_calls_over_time()
#   - plot_hourly_activity_profile()
#   - plot_callsperhour_distribution()
#   - plot_weekly_activity()
#   - plot_activity_by_month()
#
# DEPENDENCY CHAIN
# ----------------
# **Previous module dependencies:**
#   - calls_per_night_final from finalize_cpn()
#   - kpro_master from original Phase 2 output (passed through)
#
# **Internal stages:**
#   - Stages 15-21 sequentially: 15 → 16 → 17 → 18 → 19 → 20 → 21
#
# **Depends on:**
#   - functions/output/plot_quality.R: all quality plot functions
#   - functions/output/plot_detector.R: all detector plot functions
#   - functions/output/plot_species.R: all species plot functions
#   - functions/output/plot_temporal.R: all temporal plot functions
#   - functions/output/plot_helpers.R: theme_kpro, create_plot_directories, export_plots_png
#   - functions/core/utilities.R: logging, artifact registration
#
# CHANGELOG
# ---------
# 2026-02-08: Extracted from Phase 3 (run_phase3_analysis_reporting) as standalone module


#' Generate Exploratory Plots
#'
#' @description
#' Phase 3, Stages 15-21: Generates 26 exploratory visualizations across
#' quality, detector, species, and temporal categories. Exports PNG files
#' and RDS object archive.
#'
#' This is the THIRD module in the finalize-to-report pipeline. Consumes
#' output from finalize_cpn and optionally uses kpro_master for enhanced analyses.
#'
#' @param calls_per_night_final Tibble. Final CPN from finalize_cpn module.
#'   Must have columns: Detector, Night, CallsPerNight, RecordingHours, Status, CallsPerHour.
#' @param kpro_master Tibble. Master dataset from Phase 2. Required for
#'   species and temporal plot generation.
#' @param study_params List. Study parameters from load_study_parameters().
#' @param registry List. Artifact registry (will be updated).
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return List with elements:
#'   - plotting: List containing:
#'     - all_plots: Master list with all plot objects grouped by category
#'     - plots_rds: Path to RDS file with plot objects
#'     - files_created: Vector of exported PNG file paths
#'     - plot_counts: Named list with counts by category
#'   - checkpoint_path: Character path to primary module checkpoint/output
#'   - artifact_ids: Character vector of artifacts registered in this module call
#'   - validation_html_paths: Character vector with validation report path
#'   - summary: Metadata list
#'
#' @details
#' **Stages executed:**
#'   - Stage 15: Configure plot settings and directories
#'   - Stage 16: Generate quality plots (8 total)
#'   - Stage 17: Generate detector plots (7 total)
#'   - Stage 18: Generate species plots (5 total)
#'   - Stage 19: Generate temporal plots (6 total)
#'   - Stage 20: Export all plots as PNG (300 DPI)
#'   - Stage 21: Save plot objects as RDS
#'
#' **Plot Export Format:**
#'   - PNG format: 10 inches × 7 inches, 300 DPI for publication
#'   - White background
#'   - ggplot2::ggsave() with consistent settings
#'   - Organized by category in results/figures/png/[category]/
#'
#' **Plot Object Archive:**
#'   - RDS contains nested list: quality, detector, species, temporal
#'   - Each subcategory contains named ggplot objects
#'   - Can be reloaded and customized without regenerating from raw data
#'   - Used by Report & Release module for report embedding
#'
#' @section CONTRACT:
#' - Generates 26+ exploratory plots (number may vary by species availability)
#' - Skips species plots gracefully if species column unavailable
#' - Each plot is a complete ggplot2 object (not modified by export)
#' - PNG exports use consistent 300 DPI quality
#' - RDS archive preserves plot objects for future customization
#' - Does NOT modify input data
#' - All plot generation failures are logged but don't stop execution
#'
#' @export
module_plotting <- function(calls_per_night_final,
                            kpro_master,
                            study_params,
                            registry = NULL,
                            verbose = FALSE) {
  
  # ===========================================================================
  # INITIALIZATION
  # ===========================================================================
  
  print_stage_banner("PLOTTING", verbose = verbose)
  
  # Ensure registry exists
  if (is.null(registry)) {
    registry <- list()
  }

  artifact_names_before <- names(registry$artifacts %||% list())
  
  result <- list(plotting = list(), validation_html_paths = character())
  
  # Create validation context
  validation_context <- init_stage_validation("exploratory_plots", study_params)
  
  # Initialize plots structure
  all_plots <- list(
    quality = list(),
    detector = list(),
    species = list(),
    temporal = list()
  )
  
  files_created <- character()
  
  # ===========================================================================
  # STAGE 15: CONFIGURE PLOT SETTINGS
  # ===========================================================================
  
  log_stage_start("15", "Configure Plot Settings", verbose = verbose, phase_prefix = "Plots")
  
  # Create plot output directories
  create_plot_directories(verbose = verbose)
  
  if (verbose) message("  [OK] Plot directories ready")
  
  # ===========================================================================
  # STAGE 16: GENERATE QUALITY PLOTS (8)
  # ===========================================================================
  
  log_stage_start("16", "Generate Quality Plots", verbose = verbose, phase_prefix = "Plots")
  
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
  
  # ===========================================================================
  # STAGE 17: GENERATE DETECTOR PLOTS (7)
  # ===========================================================================
  
  log_stage_start("17", "Generate Detector Plots", verbose = verbose, phase_prefix = "Plots")
  
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
  
  # ===========================================================================
  # STAGE 18: GENERATE SPECIES PLOTS (5)
  # ===========================================================================
  
  log_stage_start("18", "Generate Species Plots", verbose = verbose, phase_prefix = "Plots")
  
  species_plots <- list()
  
  tryCatch({
    species_plots$species_composition_bar <- plot_species_composition_bar(kpro_master)
    species_plots$species_by_detector_heatmap <- plot_species_by_detector_heatmap(kpro_master)
    species_plots$species_accumulation_curve <- plot_species_accumulation_curve(kpro_master)
    species_plots$species_hourly_profile <- plot_species_hourly_profile(kpro_master)
    species_plots$noid_proportion <- plot_noid_proportion(kpro_master)
    
    if (verbose) message(sprintf("  [OK] Generated %d species plots", length(species_plots)))
  }, error = function(e) {
    stop(sprintf(
      "Failed to generate species plots.\n  Species column was validated in Stage 2, but plot generation failed.\n  Original error: %s\n  Check that kpro_master has valid species data for visualization.",
      e$message
    ))
  })
  
  all_plots$species <- species_plots
  
  # ===========================================================================
  # STAGE 19: GENERATE TEMPORAL PLOTS (6)
  # ===========================================================================
  
  log_stage_start("19", "Generate Temporal Plots", verbose = verbose, phase_prefix = "Plots")
  
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
  
  # ===========================================================================
  # STAGE 20: EXPORT PLOTS AS PNG
  # ===========================================================================
  
  log_stage_start("20", "Export Plots to PNG", verbose = verbose, phase_prefix = "Plots")
  
  export_result <- export_plots_png(
    all_plots,
    base_dir = here::here("results", "figures", "png"),
    width = 10,
    height = 7,
    dpi = 300,
    verbose = verbose
  )
  
  files_created <- export_result$files_created
  total_plots_exported <- export_result$total_exported
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "files_exported",
    description = sprintf("Exported %d PNG files", total_plots_exported),
    count = total_plots_exported,
    details = list(export_format = "png", dpi = 300)
  )
  
  # ===========================================================================
  # STAGE 21: SAVE PLOT OBJECTS RDS
  # ===========================================================================
  
  log_stage_start("21", "Save Plot Objects RDS", verbose = verbose, phase_prefix = "Plots")
  
  timestamp_06 <- format(Sys.time(), "%Y%m%d")
  plots_rds_path <- here::here("results", "rds", sprintf("plot_objects_%s.rds", timestamp_06))
  
  registry <- save_and_register_rds(
    object = all_plots,
    file_path = plots_rds_path,
    artifact_type = "plot_objects",
    phase_id = "exploratory_plots",
    registry = registry,
    metadata = list(
      total_plots = total_plots_exported,
      quality_plots = length(quality_plots),
      detector_plots = length(detector_plots),
      species_plots = length(species_plots),
      temporal_plots = length(temporal_plots)
    ),
    verbose = verbose
  )
  
  # ===========================================================================
  # FINALIZE AND RETURN
  # ===========================================================================
  
  validation_html <- finalize_stage_validation_report(
    validation_context = validation_context,
    stage_name = "PLOTTING",
    verbose = verbose
  )
  
  result$plotting <- list(
    all_plots = all_plots,
    plots_rds = plots_rds_path,
    files_created = files_created,
    plot_counts = list(
      quality = length(quality_plots),
      detector = length(detector_plots),
      species = length(species_plots),
      temporal = length(temporal_plots)
    )
  )
  
  result$validation_html_paths <- c(result$validation_html_paths, validation_html)

  result$checkpoint_path <- plots_rds_path
  result$artifact_ids <- setdiff(names(registry$artifacts %||% list()), artifact_names_before)
  
  result$summary <- list(
    total_plots_exported = total_plots_exported,
    plot_counts = list(
      quality = length(quality_plots),
      detector = length(detector_plots),
      species = length(species_plots),
      temporal = length(temporal_plots)
    ),
    png_files_created = length(files_created)
  )
  
  return(result)
}


# ==============================================================================
# END OF FILE
# ==============================================================================
