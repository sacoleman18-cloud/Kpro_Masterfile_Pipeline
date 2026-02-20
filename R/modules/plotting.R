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
#     - quality: 7 plots (recording status, completeness, effort)
#     - detector: 6 plots (activity, correlations, ranking)
#     - species: 11 plots (composition, diversity, accumulation, phenology, turnover)
#     - temporal: 6 plots (trends, hourly, weekly, monthly)
#   - plotting$plots_rds: Path to RDS file with all plot objects
#   - plotting$files_created: Character vector of PNG file paths
#   - plotting$plot_counts: Named list of counts by category
#   - validation_html_paths: Character vector (1 HTML file)
#   - summary: Metadata about plots
#
# WRITES FILES
# -----------
#   - results/figures/png/quality/*.png — 7 quality plots
#   - results/figures/png/detector/*.png — 6 detector plots
#   - results/figures/png/species/*.png — 11 species plots
#   - results/figures/png/temporal/*.png — 6 temporal plots
#   - results/rds/plot_objects_*.rds — All ggplot object archive
#   - results/validation/*.html — Validation report
#
# PLOT COUNTS & CATEGORIES
# -------------------------
# **Quality (7):** Recording status summaries, assessment heatmaps
#   - plot_recording_status_percent()
#   - plot_recording_status_overall()
#   - plot_effort_by_detector()
#   - plot_nights_by_detector()
#   - plot_data_completeness_calendar()
#   - plot_missing_nights()
#   - plot_recording_effort_heatmap()
#
# **Detector (6):** Activity comparisons and correlations
#   - plot_total_calls_by_detector()
#   - plot_detector_activity_caterpillar()
#   - plot_detector_boxplots()
#   - plot_activity_with_without_outliers()
#   - plot_correlation_heatmap()
#   - plot_detector_rank_over_time()
#
# **Species (11):** Composition, diversity, and advanced detail plots
#   - plot_species_composition_bar()
#   - plot_species_by_detector_heatmap()
#   - plot_species_accumulation_curve()
#   - plot_species_hourly_profile()
#   - plot_noid_proportion()
#   - plot_species_nightly_activity()
#   - plot_species_phenology_heatmap()
#   - plot_species_turnover()
#   - plot_noid_richness_over_time()
#   - plot_species_by_detector_composition()
#   - plot_species_rank_abundance()
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
#   - functions/output/plot_species.R: 5 basic species plot functions
#   - functions/output/plot_species2.R: 6 advanced species plot functions
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
#' Phase 3, Stages 15-21: Generates 31 exploratory visualizations across
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
#'   - Stage 16: Generate quality plots (7 total)
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
#' - Generates 25+ exploratory plots (number may vary by species availability)
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
  
  # Initialize plots structure and failure tracking
  all_plots <- list(
    quality = list(),
    detector = list(),
    species = list(),
    temporal = list()
  )
  
  # Initialize per-plot failure ledger for non-fatal error tracking
  plot_ledger <- create_failure_ledger()
  
  files_created <- character()
  
  # ===========================================================================
  # STAGE 15: CONFIGURE PLOT SETTINGS
  # ===========================================================================
  
  log_stage_start("15", "Configure Plot Settings", verbose = verbose, phase_prefix = "Plots")
  
  # Create plot output directories
  create_plot_directories(verbose = verbose)
  
  if (verbose) message("  [OK] Plot directories ready")
  
  # ===========================================================================
  # STAGE 16: GENERATE QUALITY PLOTS (7 - with per-plot error isolation)
  # ===========================================================================
  
  log_stage_start("16", "Generate Quality Plots", verbose = verbose, phase_prefix = "Plots")
  
  quality_plots <- list()
  
  # Generate each quality plot with individual error isolation
  # If a plot fails, it logs to ledger and continues to next plot
  quality_plots$recording_status_percent <- generate_plot_safely(
    plot_function = plot_recording_status_percent,
    data = calls_per_night_final,
    plot_name = "recording_status_percent",
    category = "quality",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  quality_plots$recording_status_overall <- generate_plot_safely(
    plot_function = plot_recording_status_overall,
    data = calls_per_night_final,
    plot_name = "recording_status_overall",
    category = "quality",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  quality_plots$effort_by_detector <- generate_plot_safely(
    plot_function = plot_effort_by_detector,
    data = calls_per_night_final,
    plot_name = "effort_by_detector",
    category = "quality",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  quality_plots$nights_by_detector <- generate_plot_safely(
    plot_function = plot_nights_by_detector,
    data = calls_per_night_final,
    plot_name = "nights_by_detector",
    category = "quality",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  quality_plots$data_completeness_calendar <- generate_plot_safely(
    plot_function = plot_data_completeness_calendar,
    data = calls_per_night_final,
    plot_name = "data_completeness_calendar",
    category = "quality",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  quality_plots$missing_nights <- generate_plot_safely(
    plot_function = plot_missing_nights,
    data = calls_per_night_final,
    plot_name = "missing_nights",
    category = "quality",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  quality_plots$recording_effort_heatmap <- generate_plot_safely(
    plot_function = plot_recording_effort_heatmap,
    data = calls_per_night_final,
    plot_name = "recording_effort_heatmap",
    category = "quality",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  # Remove NULL values (failed plots) from list for clean export
  quality_plots <- Filter(Negate(is.null), quality_plots)
  
  if (verbose) {
    message(sprintf("  [OK] Generated %d quality plots", length(quality_plots)))
    if (plot_ledger$failure_count > 0) {
      message(sprintf("  [!] %d quality plot(s) failed - see ledger", 
                     sum(sapply(plot_ledger$failures, function(f) f$category == "quality"))))
    }
  }
  
  all_plots$quality <- quality_plots
  
  # ===========================================================================
  # STAGE 17: GENERATE DETECTOR PLOTS (7 - with per-plot error isolation)
  # ===========================================================================
  
  log_stage_start("17", "Generate Detector Plots", verbose = verbose, phase_prefix = "Plots")
  
  detector_plots <- list()
  
  # Generate each detector plot with individual error isolation
  detector_plots$total_calls_by_detector <- generate_plot_safely(
    plot_function = plot_total_calls_by_detector,
    data = kpro_master,
    plot_name = "total_calls_by_detector",
    category = "detector",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  detector_plots$detector_activity_caterpillar <- generate_plot_safely(
    plot_function = plot_detector_activity_caterpillar,
    data = calls_per_night_final,
    plot_name = "detector_activity_caterpillar",
    category = "detector",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  detector_plots$detector_boxplots <- generate_plot_safely(
    plot_function = plot_detector_boxplots,
    data = calls_per_night_final,
    plot_name = "detector_boxplots",
    category = "detector",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  detector_plots$activity_with_without_outliers <- generate_plot_safely(
    plot_function = plot_activity_with_without_outliers,
    data = calls_per_night_final,
    plot_name = "activity_with_without_outliers",
    category = "detector",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  detector_plots$correlation_heatmap <- generate_plot_safely(
    plot_function = plot_correlation_heatmap,
    data = calls_per_night_final,
    plot_name = "correlation_heatmap",
    category = "detector",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  detector_plots$detector_rank_over_time <- generate_plot_safely(
    plot_function = plot_detector_rank_over_time,
    data = calls_per_night_final,
    plot_name = "detector_rank_over_time",
    category = "detector",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  # Remove NULL values (failed plots) from list for clean export
  detector_plots <- Filter(Negate(is.null), detector_plots)
  
  if (verbose) {
    message(sprintf("  [OK] Generated %d detector plots", length(detector_plots)))
    if (plot_ledger$failure_count > 0) {
      message(sprintf("  [!] %d detector plot(s) failed - see ledger",
                     sum(sapply(plot_ledger$failures, function(f) f$category == "detector"))))
    }
  }
  
  all_plots$detector <- detector_plots
  
  # ===========================================================================
  # STAGE 18: GENERATE SPECIES PLOTS (11 - with per-plot error isolation)
  # ===========================================================================
  # Includes: 5 basic composition/diversity plots + 6 advanced detail plots
  
  log_stage_start("18", "Generate Species Plots", verbose = verbose, phase_prefix = "Plots")
  
  species_plots <- list()
  
  # Generate each species plot with individual error isolation
  # Basic species plots
  species_plots$species_composition_bar <- generate_plot_safely(
    plot_function = plot_species_composition_bar,
    data = kpro_master,
    plot_name = "species_composition_bar",
    category = "species",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  species_plots$species_by_detector_heatmap <- generate_plot_safely(
    plot_function = plot_species_by_detector_heatmap,
    data = kpro_master,
    plot_name = "species_by_detector_heatmap",
    category = "species",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  species_plots$species_accumulation_curve <- generate_plot_safely(
    plot_function = plot_species_accumulation_curve,
    data = kpro_master,
    plot_name = "species_accumulation_curve",
    category = "species",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  species_plots$species_hourly_profile <- generate_plot_safely(
    plot_function = plot_species_hourly_profile,
    data = kpro_master,
    plot_name = "species_hourly_profile",
    category = "species",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  species_plots$noid_proportion <- generate_plot_safely(
    plot_function = plot_noid_proportion,
    data = kpro_master,
    plot_name = "noid_proportion",
    category = "species",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  # Advanced species detail plots
  species_plots$species_nightly_activity <- generate_plot_safely(
    plot_function = plot_species_nightly_activity,
    data = kpro_master,
    plot_name = "species_nightly_activity",
    category = "species",
    ledger = plot_ledger,
    top_n = NULL,
    verbose = verbose
  )
  
  species_plots$species_phenology_heatmap <- generate_plot_safely(
    plot_function = plot_species_phenology_heatmap,
    data = kpro_master,
    plot_name = "species_phenology_heatmap",
    category = "species",
    ledger = plot_ledger,
    time_bin = "night",
    verbose = verbose
  )
  
  species_plots$species_turnover <- generate_plot_safely(
    plot_function = plot_species_turnover,
    data = kpro_master,
    plot_name = "species_turnover",
    category = "species",
    ledger = plot_ledger,
    time_bin = "night",
    verbose = verbose
  )
  
  species_plots$noid_richness_over_time <- generate_plot_safely(
    plot_function = plot_noid_richness_over_time,
    data = kpro_master,
    plot_name = "noid_richness_over_time",
    category = "species",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  species_plots$species_by_detector_composition <- generate_plot_safely(
    plot_function = plot_species_by_detector_composition,
    data = kpro_master,
    plot_name = "species_by_detector_composition",
    category = "species",
    ledger = plot_ledger,
    normalize = FALSE,
    verbose = verbose
  )
  
  species_plots$species_rank_abundance <- generate_plot_safely(
    plot_function = plot_species_rank_abundance,
    data = kpro_master,
    plot_name = "species_rank_abundance",
    category = "species",
    ledger = plot_ledger,
    log_scale = TRUE,
    verbose = verbose
  )
  
  # Remove NULL values (failed plots) from list for clean export
  species_plots <- Filter(Negate(is.null), species_plots)
  
  if (verbose) {
    message(sprintf("  [OK] Generated %d species plots", length(species_plots)))
    if (plot_ledger$failure_count > 0) {
      message(sprintf("  [!] %d species plot(s) failed - see ledger",
                     sum(sapply(plot_ledger$failures, function(f) f$category == "species"))))
    }
  }
  
  all_plots$species <- species_plots
  
  # ===========================================================================
  # STAGE 19: GENERATE TEMPORAL PLOTS (6 - with per-plot error isolation)
  # ===========================================================================
  
  log_stage_start("19", "Generate Temporal Plots", verbose = verbose, phase_prefix = "Plots")
  
  temporal_plots <- list()
  
  # Generate each temporal plot with individual error isolation
  temporal_plots$activity_over_time <- generate_plot_safely(
    plot_function = plot_activity_over_time,
    data = calls_per_night_final,
    plot_name = "activity_over_time",
    category = "temporal",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  temporal_plots$cumulative_calls_over_time <- generate_plot_safely(
    plot_function = plot_cumulative_calls_over_time,
    data = calls_per_night_final,
    plot_name = "cumulative_calls_over_time",
    category = "temporal",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  temporal_plots$hourly_activity_profile <- generate_plot_safely(
    plot_function = plot_hourly_activity_profile,
    data = kpro_master,
    plot_name = "hourly_activity_profile",
    category = "temporal",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  temporal_plots$callsperhour_distribution <- generate_plot_safely(
    plot_function = plot_callsperhour_distribution,
    data = calls_per_night_final,
    plot_name = "callsperhour_distribution",
    category = "temporal",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  temporal_plots$weekly_activity <- generate_plot_safely(
    plot_function = plot_weekly_activity,
    data = calls_per_night_final,
    plot_name = "weekly_activity",
    category = "temporal",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  temporal_plots$activity_by_month <- generate_plot_safely(
    plot_function = plot_activity_by_month,
    data = calls_per_night_final,
    plot_name = "activity_by_month",
    category = "temporal",
    ledger = plot_ledger,
    verbose = verbose
  )
  
  # Remove NULL values (failed plots) from list for clean export
  temporal_plots <- Filter(Negate(is.null), temporal_plots)
  
  if (verbose) {
    message(sprintf("  [OK] Generated %d temporal plots", length(temporal_plots)))
    if (plot_ledger$failure_count > 0) {
      message(sprintf("  [!] %d temporal plot(s) failed - see ledger",
                     sum(sapply(plot_ledger$failures, function(f) f$category == "temporal"))))
    }
  }
  
  all_plots$temporal <- temporal_plots
  
  # ===========================================================================
  # FAILURE LEDGER SUMMARY (Per-Plot Error Tracking)
  # ===========================================================================
  
  if (verbose && plot_ledger$failure_count > 0) {
    message(sprintf("\n  Plot Generation Failures: %d total", plot_ledger$failure_count))
    
    failure_summary <- summarize_plot_failures(plot_ledger, verbose = FALSE)
    for (i in seq_len(nrow(failure_summary))) {
      row <- failure_summary[i,]
      message(sprintf("    - %s (%s): %s",
                     row$plot_name,
                     row$category,
                     row$error_message))
    }
    
    # Log failures to validation context
    validation_context <- log_validation_event(
      validation_context,
      event_type = "warning",
      description = sprintf("%d plots failed to generate", plot_ledger$failure_count),
      count = plot_ledger$failure_count,
      details = failure_summary
    )
  } else if (plot_ledger$failure_count == 0) {
    if (verbose) message("  [OK] All plots generated successfully (no failures)")
  }
  
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
    ),
    failure_ledger = plot_ledger
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
    png_files_created = length(files_created),
    plot_generation_failures = plot_ledger$failure_count
  )
  
  return(result)
}


# ==============================================================================
# END OF FILE
# ==============================================================================
