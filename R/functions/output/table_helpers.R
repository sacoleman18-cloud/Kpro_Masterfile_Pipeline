# =============================================================================
# UTILITY: table_helpers.R - Shared GT Table Utilities
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# PURPOSE
# -------
# Provides shared utilities for GT table formatting modules. Centralizes
# reusable input validation and theme styling so table formatters remain DRY,
# consistent, and deterministic.
#
# This file MUST be sourced before tables.R, as tables.R depends on
# functions defined here.
#
# DEPENDENCIES
# ------------
# External Packages:
#   - gt: Table styling primitives (tab_header, tab_style, tab_options)
#
# Internal Dependencies:
#   - None (this is the base helper layer for table formatting)
#
# FUNCTIONS PROVIDED
# ------------------
#
# Validation Helpers:
#
#   - validate_summary_for_gt():
#       Uses packages: base R (is.data.frame, setdiff, paste, sprintf, stop)
#       Calls internal: none
#       Purpose: Validate summary data frame and required columns for GT formatters
#
# Theme Helpers:
#
#   - apply_kpro_gt_theme():
#       Uses packages: gt (tab_header, tab_style, tab_options, opt_row_striping)
#       Calls internal: none
#       Purpose: Apply standardized KPro GT styling across all table modules
#
# Export Helpers:
#
#   - export_summary_gt_artifact():
#       Uses packages: base R (tryCatch, warning, sprintf, is.function)
#       Calls internal: save_gt_table (from tables.R)
#       Purpose: Export one summary table to PNG/HTML with consistent error handling
#
# USAGE
# -----
# source("R/functions/output/table_helpers.R")
# source("R/functions/output/tables.R")
#
# CHANGELOG
# ---------
# 2026-02-20: Added shared GT export helper for Stage 15 PNG/HTML artifact export
# 2026-02-20: Added shared GT validation and theme helpers (moved from tables.R)
# 2026-02-20: Initial version
# =============================================================================

#' Validate Summary Input for GT Formatting
#'
#' @description
#' Validates that a summary object is a data frame and contains all required
#' columns for a GT formatter. Produces consistent, actionable error messages
#' aligned with deterministic table contracts.
#'
#' @param df Data frame to validate.
#' @param required_cols Character vector of required column names.
#' @param arg_name Character. Argument name used in error messages.
#' @param source_function Character. Expected upstream function name used in
#'   guidance text (e.g., "create_detector_activity_summary").
#'
#' @return Invisibly returns TRUE if validation passes.
#'
#' @section CONTRACT:
#' - Fails fast with clear error message for invalid input type
#' - Fails fast when required columns are missing
#' - Provides upstream function hint for remediation
#' - Does not modify input data
#'
#' @section DOES NOT:
#' - Coerce or repair input schemas
#' - Validate value distributions or ranges
#' - Perform any formatting
validate_summary_for_gt <- function(df,
                                    required_cols,
                                    arg_name,
                                    source_function) {
  if (!is.data.frame(df)) {
    stop(sprintf("%s must be a data frame", arg_name))
  }

  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "%s is missing required columns: %s\nDid you use %s()?",
      arg_name,
      paste(missing_cols, collapse = ", "),
      source_function
    ))
  }

  invisible(TRUE)
}


#' Apply KPro GT Theme
#'
#' @description
#' Applies a consistent, soft-contrast GT theme used across KPro summary
#' tables. Handles title/subtitle, column label styling, borders, typography,
#' and optional row striping.
#'
#' @param gt_table A gt table object.
#' @param title Character. Optional table title. Default NULL.
#' @param subtitle Character. Optional table subtitle. Default NULL.
#' @param table_font_size Numeric. Body font size in px. Default 11.
#' @param heading_title_font_size Numeric. Title font size in px. Default 16.
#' @param heading_subtitle_font_size Numeric. Subtitle font size in px. Default 12.
#' @param column_labels_font_size Numeric. Column-label font size in px. Default 11.
#' @param row_striping Logical. Whether to apply row striping. Default FALSE.
#' @param tab_options_extra List of additional gt::tab_options parameters.
#'
#' @return Styled gt table object.
#'
#' @section CONTRACT:
#' - Preserves input table content and structure
#' - Applies consistent KPro visual style
#' - Supports optional title/subtitle and row striping
#' - Allows controlled option overrides via tab_options_extra
#'
#' @section DOES NOT:
#' - Add domain-specific labels or spanners
#' - Format numeric values
#' - Save outputs to disk
apply_kpro_gt_theme <- function(gt_table,
                                title = NULL,
                                subtitle = NULL,
                                table_font_size = 11,
                                heading_title_font_size = 16,
                                heading_subtitle_font_size = 12,
                                column_labels_font_size = 11,
                                row_striping = FALSE,
                                tab_options_extra = list()) {
  if (!inherits(gt_table, "gt_tbl")) {
    stop("gt_table must be a gt object")
  }

  if (!is.null(title)) {
    gt_table <- gt_table %>%
      gt::tab_header(
        title = gt::md(paste0("**", title, "**")),
        subtitle = subtitle
      )
  }

  gt_table <- gt_table %>%
    gt::tab_style(
      style = list(
        gt::cell_fill(color = "#e8f0f7"),
        gt::cell_text(weight = "bold")
      ),
      locations = gt::cells_column_labels()
    )

  base_options <- list(
    table.font.size = gt::px(table_font_size),
    heading.title.font.size = gt::px(heading_title_font_size),
    heading.subtitle.font.size = gt::px(heading_subtitle_font_size),
    column_labels.font.size = gt::px(column_labels_font_size),
    table.border.top.style = "solid",
    table.border.top.width = gt::px(2),
    table.border.top.color = "#9CA3AF",
    table.border.bottom.style = "solid",
    table.border.bottom.width = gt::px(2),
    table.border.bottom.color = "#9CA3AF",
    heading.border.bottom.style = "solid",
    heading.border.bottom.width = gt::px(1),
    heading.border.bottom.color = "#D1D5DB"
  )

  if (length(tab_options_extra) > 0) {
    base_options <- c(base_options, tab_options_extra)
  }

  gt_table <- do.call(gt::tab_options, c(list(data = gt_table), base_options))

  if (isTRUE(row_striping)) {
    gt_table <- gt_table %>%
      gt::opt_row_striping()
  }

  gt_table
}


#' Export Summary GT Artifact
#'
#' @description
#' Exports a summary data frame as GT table artifacts (PNG and/or HTML) using a
#' formatter function and standardized error handling. Designed to eliminate
#' repetitive Stage 15 export boilerplate in module orchestration code.
#'
#' @param summary_df Data frame summary to format and export.
#' @param formatter_fn Function that accepts summary_df and returns gt_tbl.
#' @param base_name Character. Output file base name without extension.
#' @param output_dir Character. Directory for exported artifacts.
#' @param timestamp Character. Timestamp suffix appended to base_name.
#' @param export_png Logical. Whether PNG export is enabled in configuration.
#' @param export_html Logical. Whether HTML export is enabled in configuration.
#' @param has_webshot2 Logical. Whether webshot2 is available for PNG export.
#' @param error_label Character. Human-readable artifact label for warnings.
#' @param verbose Logical. Whether to emit optional success messages.
#' @param png_success_message Character or NULL. Optional message on PNG success.
#' @param html_success_message Character or NULL. Optional message on HTML success.
#'
#' @return Named list with integer counters: png_exports, html_exports.
#'
#' @section CONTRACT:
#' - Returns zero counters for NULL summaries
#' - Exports PNG only when export_png and has_webshot2 are TRUE
#' - Exports HTML only when export_html is TRUE
#' - Uses consistent warning format on export failure
#' - Does not modify input summary data
export_summary_gt_artifact <- function(summary_df,
                                       formatter_fn,
                                       base_name,
                                       output_dir,
                                       timestamp,
                                       export_png,
                                       export_html,
                                       has_webshot2,
                                       error_label,
                                       verbose = FALSE,
                                       png_success_message = NULL,
                                       html_success_message = NULL) {
  if (is.null(summary_df)) {
    return(list(png_exports = 0L, html_exports = 0L))
  }

  if (!is.function(formatter_fn)) {
    stop("formatter_fn must be a function")
  }

  png_exports <- 0L
  html_exports <- 0L
  file_base <- sprintf("%s_%s", base_name, timestamp)

  if (isTRUE(export_png) && isTRUE(has_webshot2)) {
    tryCatch({
      gt_tbl <- formatter_fn(summary_df)
      save_gt_table(gt_tbl, file_base, output_dir = output_dir, format = "png")
      png_exports <- png_exports + 1L
      if (verbose && !is.null(png_success_message)) {
        message(png_success_message)
      }
    }, error = function(e) {
      warning(sprintf("Failed to export %s PNG: %s", error_label, e$message))
    })
  }

  if (isTRUE(export_html)) {
    tryCatch({
      gt_tbl <- formatter_fn(summary_df)
      save_gt_table(gt_tbl, file_base, output_dir = output_dir, format = "html")
      html_exports <- html_exports + 1L
      if (verbose && !is.null(html_success_message)) {
        message(html_success_message)
      }
    }, error = function(e) {
      warning(sprintf("Failed to export %s HTML: %s", error_label, e$message))
    })
  }

  list(png_exports = png_exports, html_exports = html_exports)
}
