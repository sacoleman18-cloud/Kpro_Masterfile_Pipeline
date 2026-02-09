# =============================================================================
# UTILITY: report.R - Quarto Report Generation
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# - Renders Quarto markdown reports with parameterized data
# - Used by modules in R/modules/
# PURPOSE
# -------
# Provides a single function to generate the final Quarto report from
# pre-computed summary and plot objects.
#
# DEPENDENCIES
# ------------
# R Packages:
#   - quarto:  Report rendering
#   - yaml: Parameter handling
#   - here: Path management
#
# FUNCTIONS PROVIDED
# ------------------
#
# Report Generation - Main Quarto rendering function:
#
#   - generate_quarto_report():
#       Uses packages: quarto (quarto_render), yaml (read_yaml), here (here),
#                      readr (write_lines), base R (file operations, dir.create)
#       Calls internal: none (external Quarto rendering)
#       Purpose: Render .qmd template with pre-computed summaries/plots to HTML
#
# USAGE
# -----
# source("R/functions/output/report.R")
# report_path <- generate_quarto_report(all_summaries, all_plots)
#
# CHANGELOG
# ---------
# 2026-02-01: Verified deterministic behavior - all functions follow standards
# 2026-02-01: Confirmed usage in run_finalize_to_report.R (Chunk 3, Workflow 07)
# 2026-01-19: Fixed execute_dir parameter to ensure project root context
# 2026-01-12: Initial version (extracted from Workflow 07)
# =============================================================================

library(here)

# Check for quarto package
if (!requireNamespace("quarto", quietly = TRUE)) {
  stop("Package 'quarto' is required for report generation.\n",
       "  Install with: install.packages('quarto')\n",
       "  Also requires Quarto CLI: https://quarto.org/docs/get-started/")
}

library(quarto)

#' Generate Quarto Report
#'
#' @description
#' Renders the Quarto report template with pre-computed summary and plot
#' objects. This function is read-only with respect to analytical results—
#' no computation or transformation occurs.
#'
#' @param all_summaries List.  Summary data from Module 5 (or RDS path)
#' @param all_plots List.  Plot objects from Module 6 (or RDS path)
#' @param study_params_path Character. Path to study_parameters.yaml
#' @param template_path Character. Path to .qmd template
#' @param output_dir Character. Directory for rendered output
#' @param quiet Logical.  Suppress rendering messages if TRUE
#'
#' @return Character. Path to rendered HTML report
#'
#' @section CONTRACT:
#' - Does not compute any statistics
#' - Does not generate any new plots
#' - Uses only pre-computed objects from Workflows 05-06
#' - Produces self-contained HTML file
#'
#' @section IMPORTANT IMPLEMENTATION NOTE:
#' This function sets `execute_dir = here::here()` when calling quarto_render().
#' This is CRITICAL because:
#' 1. The .qmd template sources custom functions via load_all.R in setup chunk
#' 2. Plot objects contain lazy evaluation of format_number() and other custom functions
#' 3. Without setting execute_dir, Quarto may execute from a different working directory
#' 4. This causes "format_number() not found" errors when plots are rendered
#'
#' @export
generate_quarto_report <- function(all_summaries,
                                   all_plots,
                                   study_params_path = here::here("inst", "config", "study_parameters.yaml"),
                                   template_path = here::here("reports", "bat_activity_report.qmd"),
                                   output_dir = here::here("results", "reports"),
                                   quiet = FALSE) {
  
  # -------------------------
  # Resolve RDS paths if strings provided
  # -------------------------
  
  if (is.character(all_summaries)) {
    if (!file.exists(all_summaries)) {
      stop(sprintf("Summary RDS not found: %s", all_summaries))
    }
    summary_rds_path <- all_summaries
    all_summaries <- readRDS(all_summaries)
  } else {
    # Save to temp RDS for Quarto params
    summary_rds_path <- tempfile(fileext = ".rds")
    saveRDS(all_summaries, summary_rds_path)
  }
  
  if (is.character(all_plots)) {
    if (!file.exists(all_plots)) {
      stop(sprintf("Plots RDS not found: %s", all_plots))
    }
    plots_rds_path <- all_plots
    all_plots <- readRDS(all_plots)
  } else {
    # Save to temp RDS for Quarto params
    plots_rds_path <- tempfile(fileext = ".rds")
    saveRDS(all_plots, plots_rds_path)
  }
  
  # -------------------------
  # Validate inputs
  # -------------------------
  
  if (!file.exists(template_path)) {
    stop(sprintf("Quarto template not found: %s", template_path))
  }
  
  # Validate required elements
  required_summary_names <- c("detector_summary", "study_summary", "metadata")
  required_plot_categories <- c("quality", "detector", "temporal")
  
  missing_summaries <- setdiff(required_summary_names, names(all_summaries))
  missing_plots <- setdiff(required_plot_categories, names(all_plots))
  
  if (length(missing_summaries) > 0) {
    warning(sprintf("Summary data missing elements: %s",
                    paste(missing_summaries, collapse = ", ")))
  }
  
  if (length(missing_plots) > 0) {
    warning(sprintf("Plot objects missing categories: %s",
                    paste(missing_plots, collapse = ", ")))
  }
  
  # -------------------------
  # Setup output
  # -------------------------
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  timestamp <- format(Sys.Date(), "%Y%m%d")
  output_file <- sprintf("bat_activity_report_%s.html", timestamp)
  
  if (!quiet) {
    message("Rendering Quarto report...")
    message(sprintf("  Template: %s", basename(template_path)))
    message(sprintf("  Output: %s", output_file))
  }
  
  # -------------------------
  # Render
  # -------------------------
  
  render_start <- Sys.time()
  
  # CRITICAL: Set execute_dir to project root so that load_all.R can be found
  # when the Quarto document sources custom functions in its setup chunk.
  # Without this, Quarto's working directory may not be the project root,
  # causing "format_number() not found" errors when rendering plots.
  quarto::quarto_render(
    input = template_path,
    output_file = output_file,
    output_format = "html",
    execute_dir = here::here(),  # Execute from project root
    execute_params = list(
      summary_rds = summary_rds_path,
      plots_rds = plots_rds_path,
      study_params_path = study_params_path
    ),
    quiet = quiet
  )
  
  render_end <- Sys.time()
  render_time <- round(difftime(render_end, render_start, units = "secs"), 1)
  
  # -------------------------
  # Move to output directory
  # -------------------------
  
  rendered_path <- file.path(dirname(template_path), output_file)
  final_path <- file.path(output_dir, output_file)
  
  if (file.exists(rendered_path) && rendered_path != final_path) {
    file.rename(rendered_path, final_path)
  }
  
  # Verify output
  if (!file.exists(final_path)) {
    stop("Report generation failed - output file not found.")
  }
  
  file_size <- round(file.info(final_path)$size / 1024, 1)
  
  if (!quiet) {
    message(sprintf("✓ Report generated: %s (%.1f KB, %.1fs)",
                    basename(final_path), file_size, render_time))
  }
  
  final_path
}
