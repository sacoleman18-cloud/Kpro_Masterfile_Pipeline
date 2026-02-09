# =============================================================================
# UTILITY: tables.R - GT Table Formatting (LOCKED CONTRACT)
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# PURPOSE
# -------
# Formats summary tibbles as publication-ready GT tables with consistent
# styling. Handles export to PNG and HTML formats.
#
# TABLE CONTRACT
# --------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Input: tibbles from analysis/summarization.R
#    - Functions expect specific column structures
#    - Input validation performed before formatting
#
# 2. Output: GT table objects
#    - All format_*_gt() functions return gt objects
#    - Can be further customized by user
#    - Can be saved via save_gt_table()
#
# 3. Consistent styling
#    - Clean, minimal design (white background)
#    - Bold headers and key metrics
#    - Appropriate number formatting (decimals, percentages)
#    - Readable font sizes
#    - Intuitive column grouping with spanners
#
# 4. Export options
#    - PNG at 300 DPI for standalone viewing
#    - HTML for Quarto embedding
#    - Consistent sizing across all tables
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Calculate summary statistics (analysis/summarization.R)
#   - Create visualizations (output/visualization.R)
#   - Read data files directly
#   - Make ecological interpretations
#
# DEPENDENCIES
# ------------
#   - gt: All table formatting
#   - webshot2: PNG export (optional, for gtsave)
#   - dplyr: Data manipulation for pivoting
#   - tidyr: Pivoting for wide format
#
# FUNCTIONS PROVIDED
# ------------------
#
# Table Formatting - Convert summaries to publication-ready GT tables:
#
#   - format_detector_summary_gt():
#       Uses packages: gt (gt, cols_label, tab_spanner, gtsave),
#                      dplyr (select, mutate)
#       Calls internal: none (pure formatting)
#       Purpose: Format detector activity summary as styled GT table
#
#   - format_species_summary_gt():
#       Uses packages: gt (gt, cols_label, tab_spanner, fmt_number),
#                      dplyr (select, mutate)
#       Calls internal: none (pure formatting)
#       Purpose: Format species composition summary as styled GT table
#
#   - format_study_summary_gt():
#       Uses packages: gt (gt, cols_label, fmt_number, fmt_percent),
#                      dplyr (select, mutate, across)
#       Calls internal: none (pure formatting)
#       Purpose: Format study-wide summary as styled GT table
#
#   - format_hourly_summary_gt():
#       Uses packages: gt (gt, cols_label, cols_width),
#                      dplyr (select, mutate)
#       Calls internal: none (pure formatting)
#       Purpose: Format hourly activity profile as styled GT table
#
# Export Functions - Save tables to disk:
#
#   - save_gt_table():
#       Uses packages: gt (gtsave), webshot2 (optional, for PNG),
#                      base R (file.path, dir.exists, dir.create)
#       Calls internal: none (pure I/O)
#       Purpose: Export GT table to PNG and/or HTML formats (300 DPI)
#
# Last Modified: 2026-02-09
#
# CHANGELOG
# ---------
# 2026-02-01: Verified deterministic behavior - all functions follow standards
# 2026-02-08: Confirmed usage in run_phase3_analysis_reporting() (Phase 3, Module 5)
# 2024-12-29: Initial version with core formatting functions
#
# =============================================================================


# ------------------------------------------------------------------------------
# Format Detector Activity Summary
# ------------------------------------------------------------------------------

#' Format Detector Activity Summary as GT Table
#'
#' @description
#' Formats the output of create_detector_activity_summary() as a
#' publication-ready GT table with appropriate styling and grouping.
#'
#' @param detector_summary Tibble from create_detector_activity_summary()
#' @param title Character. Table title. Default: "Detector Activity Summary"
#' @param subtitle Character. Table subtitle. Default: NULL (no subtitle)
#'
#' @return gt object ready for display or export
#'
#' @details
#' **Column grouping:**
#' - Effort: n_nights, total_hours, mean_hours, pct_success
#' - Activity: total_calls, mean_cph, median_cph
#' - Variability: sd_cph, cv_pct, pct_zero
#'
#' **Styling:**
#' - Clean white background
#' - Bold column group headers (spanners)
#' - Detector names in bold
#' - Alternating row shading for readability
#'
#' @section CONTRACT:
#' - Expects output from create_detector_activity_summary()
#' - Returns gt object (not tibble)
#' - Does not modify input data
#' - Applies consistent styling
#'
#' @section DOES NOT:
#' - Calculate statistics (expects pre-calculated tibble)
#' - Save to file (use save_gt_table)
#' - Create multiple tables
#'
#' @examples
#' \dontrun{
#' detector_summary <- create_detector_activity_summary(cpn_final)
#' gt_table <- format_detector_summary_gt(detector_summary)
#' gt_table
#' }
#'
#' @export
format_detector_summary_gt <- function(detector_summary,
                                       title = "Detector Activity Summary",
                                       subtitle = NULL) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(detector_summary)) {
    stop("detector_summary must be a data frame")
  }
  
  required_cols <- c("Detector", "n_nights", "total_hours", "mean_cph", 
                     "median_cph", "sd_cph", "cv_pct", "total_calls")
  missing_cols <- setdiff(required_cols, names(detector_summary))
  
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "detector_summary is missing required columns: %s\nDid you use create_detector_activity_summary()?",
      paste(missing_cols, collapse = ", ")
    ))
  }
  
  # -------------------------
  # Select and order columns for display
  # -------------------------
  
  display_df <- detector_summary %>%
    dplyr::select(
      Detector,
      # Effort
      n_nights, total_hours, mean_hours, pct_success,
      # Activity
      total_calls, mean_cph, median_cph,
      # Variability
      sd_cph, cv_pct, pct_zero
    )
  
  # -------------------------
  # Build GT table
  # -------------------------
  
  gt_table <- display_df %>%
    gt::gt() %>%
    
    # Title and subtitle
    gt::tab_header(
      title = gt::md(paste0("**", title, "**")),
      subtitle = subtitle
    ) %>%
    
    # Column spanners (grouping headers)
    gt::tab_spanner(
      label = gt::md("**Effort**"),
      columns = c(n_nights, total_hours, mean_hours, pct_success)
    ) %>%
    gt::tab_spanner(
      label = gt::md("**Activity**"),
      columns = c(total_calls, mean_cph, median_cph)
    ) %>%
    gt::tab_spanner(
      label = gt::md("**Variability**"),
      columns = c(sd_cph, cv_pct, pct_zero)
    ) %>%
    
    # Column labels (human-readable names)
    gt::cols_label(
      Detector = gt::md("**Detector**"),
      n_nights = "Nights",
      total_hours = "Total Hrs",
      mean_hours = "Mean Hrs",
      pct_success = "Success %",
      total_calls = "Total Calls",
      mean_cph = "Mean CPH",
      median_cph = "Median CPH",
      sd_cph = "SD",
      cv_pct = "CV %",
      pct_zero = "Zero %"
    ) %>%
    
    # Number formatting
    gt::fmt_number(
      columns = c(total_hours, mean_hours),
      decimals = 1
    ) %>%
    gt::fmt_number(
      columns = c(mean_cph, median_cph, sd_cph),
      decimals = 2
    ) %>%
    gt::fmt_number(
      columns = c(pct_success, cv_pct, pct_zero),
      decimals = 1,
      pattern = "{x}%"
    ) %>%
    gt::fmt_integer(
      columns = c(n_nights, total_calls)
    ) %>%
    
    # Bold the Detector column values
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(columns = Detector)
    ) %>%
    
    # Header styling
    gt::tab_style(
      style = list(
        gt::cell_fill(color = "#f0f0f0"),
        gt::cell_text(weight = "bold")
      ),
      locations = gt::cells_column_labels()
    ) %>%
    
    # Alternating row colors
    gt::opt_row_striping() %>%
    
    # Table options
    gt::tab_options(
      table.font.size = gt::px(12),
      heading.title.font.size = gt::px(16),
      heading.subtitle.font.size = gt::px(12),
      column_labels.font.size = gt::px(11),
      table.border.top.style = "solid",
      table.border.top.width = gt::px(2),
      table.border.top.color = "#333333",
      table.border.bottom.style = "solid",
      table.border.bottom.width = gt::px(2),
      table.border.bottom.color = "#333333",
      heading.border.bottom.style = "solid",
      heading.border.bottom.width = gt::px(1),
      heading.border.bottom.color = "#666666"
    ) %>%
    
    # Footnote explaining abbreviations
    gt::tab_footnote(
      footnote = "CPH = Calls Per Hour; CV = Coefficient of Variation; SD = Standard Deviation",
      locations = gt::cells_column_spanners(spanners = "**Variability**")
    )
  
  gt_table
}


# ------------------------------------------------------------------------------
# Format Species Summary
# ------------------------------------------------------------------------------

#' Format Species Summary as GT Table
#'
#' @description
#' Formats the output of create_species_summary_by_detector() as a
#' publication-ready GT table.
#'
#' @param species_summary Tibble from create_species_summary_by_detector()
#' @param format Character. Either "long" (default) or "wide".
#' @param title Character. Table title. Default: "Species Composition by Detector"
#' @param subtitle Character. Table subtitle. Default: NULL
#' @param top_n Integer. If provided, only show top N species per detector.
#'   Default: NULL (show all species)
#'
#' @return gt object ready for display or export
#'
#' @details
#' **Long format (default):**
#' - One row per Detector x Species
#' - Shows n_calls and pct_of_detector
#'
#' **Wide format:**
#' - Detectors as rows, Species as columns
#' - Cell values are n_calls
#'
#' @section CONTRACT:
#' - Expects output from create_species_summary_by_detector()
#' - Returns gt object
#' - Handles both long and wide formats
#' - top_n applied per detector, not globally
#'
#' @section DOES NOT:
#' - Filter species
#' - Calculate additional statistics
#'
#' @examples
#' \dontrun{
#' species_summary <- create_species_summary_by_detector(master)
#' gt_long <- format_species_summary_gt(species_summary)
#' gt_wide <- format_species_summary_gt(species_summary, format = "wide", top_n = 5)
#' }
#'
#' @export
format_species_summary_gt <- function(species_summary,
                                      format = "long",
                                      title = "Species Composition by Detector",
                                      subtitle = NULL,
                                      top_n = NULL) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(species_summary)) {
    stop("species_summary must be a data frame")
  }
  
  required_cols <- c("Detector", "species", "n_calls", "pct_of_detector")
  missing_cols <- setdiff(required_cols, names(species_summary))
  
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "species_summary is missing required columns: %s\nDid you use create_species_summary_by_detector()?",
      paste(missing_cols, collapse = ", ")
    ))
  }
  
  if (!format %in% c("long", "wide")) {
    stop("format must be 'long' or 'wide'")
  }
  
  # -------------------------
  # Apply top_n filter if specified
  # -------------------------
  
  if (!is.null(top_n)) {
    species_summary <- species_summary %>%
      dplyr::group_by(Detector) %>%
      dplyr::slice_max(n_calls, n = top_n, with_ties = FALSE) %>%
      dplyr::ungroup()
  }
  
  # -------------------------
  # Build table based on format
  # -------------------------
  
  if (format == "long") {
    # Long format: Detector x Species rows
    display_df <- species_summary %>%
      dplyr::select(Detector, species, n_calls, pct_of_detector)
    
    gt_table <- display_df %>%
      gt::gt(groupname_col = "Detector") %>%
      
      # Title
      gt::tab_header(
        title = gt::md(paste0("**", title, "**")),
        subtitle = subtitle
      ) %>%
      
      # Column labels
      gt::cols_label(
        species = gt::md("**Species**"),
        n_calls = "Calls",
        pct_of_detector = "% of Detector"
      ) %>%
      
      # Formatting
      gt::fmt_integer(columns = n_calls) %>%
      gt::fmt_number(
        columns = pct_of_detector,
        decimals = 1,
        pattern = "{x}%"
      ) %>%
      
      # Species code styling (monospace)
      gt::tab_style(
        style = gt::cell_text(font = gt::google_font("Roboto Mono"), size = gt::px(11)),
        locations = gt::cells_body(columns = species)
      ) %>%
      
      # Row group styling (Detector names)
      gt::tab_style(
        style = list(
          gt::cell_fill(color = "#e8e8e8"),
          gt::cell_text(weight = "bold", size = gt::px(12))
        ),
        locations = gt::cells_row_groups()
      ) %>%
      
      # Header styling
      gt::tab_style(
        style = list(
          gt::cell_fill(color = "#f0f0f0"),
          gt::cell_text(weight = "bold")
        ),
        locations = gt::cells_column_labels()
      ) %>%
      
      # Table options
      gt::tab_options(
        table.font.size = gt::px(11),
        heading.title.font.size = gt::px(16),
        row_group.padding = gt::px(6),
        table.border.top.style = "solid",
        table.border.top.width = gt::px(2),
        table.border.bottom.style = "solid",
        table.border.bottom.width = gt::px(2)
      )
    
  } else {
    # Wide format: Detectors as rows, Species as columns
    display_df <- species_summary %>%
      dplyr::select(Detector, species, n_calls) %>%
      tidyr::pivot_wider(
        names_from = species,
        values_from = n_calls,
        values_fill = 0
      )
    
    # Get species columns (everything except Detector)
    species_cols <- setdiff(names(display_df), "Detector")
    
    gt_table <- display_df %>%
      gt::gt() %>%
      
      # Title
      gt::tab_header(
        title = gt::md(paste0("**", title, "**")),
        subtitle = subtitle
      ) %>%
      
      # Bold Detector column
      gt::cols_label(
        Detector = gt::md("**Detector**")
      ) %>%
      
      # Format all species columns as integers
      gt::fmt_integer(columns = dplyr::all_of(species_cols)) %>%
      
      # Replace zeros with dash for readability
      gt::sub_zero(zero_text = "-") %>%
      
      # Detector column styling
      gt::tab_style(
        style = gt::cell_text(weight = "bold"),
        locations = gt::cells_body(columns = Detector)
      ) %>%
      
      # Species column headers in monospace
      gt::tab_style(
        style = gt::cell_text(font = gt::google_font("Roboto Mono"), size = gt::px(10)),
        locations = gt::cells_column_labels(columns = dplyr::all_of(species_cols))
      ) %>%
      
      # Header row styling
      gt::tab_style(
        style = list(
          gt::cell_fill(color = "#f0f0f0"),
          gt::cell_text(weight = "bold")
        ),
        locations = gt::cells_column_labels()
      ) %>%
      
      # Row striping
      gt::opt_row_striping() %>%
      
      # Table options
      gt::tab_options(
        table.font.size = gt::px(11),
        heading.title.font.size = gt::px(16),
        table.border.top.style = "solid",
        table.border.top.width = gt::px(2),
        table.border.bottom.style = "solid",
        table.border.bottom.width = gt::px(2)
      )
  }
  
  gt_table
}


# ------------------------------------------------------------------------------
# Format Study Summary
# ------------------------------------------------------------------------------

#' Format Study-Wide Summary as GT Table
#'
#' @description
#' Formats the output of create_study_summary() as a compact GT table
#' suitable for report headers. Supports horizontal (single row) or vertical
#' (Metric / Value) orientations, handling missing or NA values safely.
#'
#' @param study_summary Tibble from create_study_summary() (single row)
#' @param title Character. Table title. Default: "Study Overview"
#' @param orientation Character. Either "horizontal" (default) or "vertical".
#'
#' @return gt object ready for display or export
#'
#' @section CONTRACT:
#' - Expects single-row tibble from create_study_summary()
#' - Returns gt object
#' - Supports horizontal and vertical orientations
#' - Handles NA values without producing warnings
#'
#' @section DOES NOT:
#' - Handle multi-row input
#' - Calculate additional metrics
#'
#' @examples
#' \dontrun{
#' study_summary <- create_study_summary(cpn_final)
#' gt_horizontal <- format_study_summary_gt(study_summary)
#' gt_vertical <- format_study_summary_gt(study_summary, orientation = "vertical")
#' }
#'
#' @export
format_study_summary_gt <- function(study_summary,
                                    title = "Study Overview",
                                    orientation = "horizontal") {
  
  # -------------------------
  # Input validation
  # -------------------------
  if (!is.data.frame(study_summary)) {
    stop("study_summary must be a data frame")
  }
  
  if (nrow(study_summary) != 1) {
    stop(sprintf(
      "study_summary must have exactly 1 row, but has %d rows",
      nrow(study_summary)
    ))
  }
  
  if (!orientation %in% c("horizontal", "vertical")) {
    stop("orientation must be 'horizontal' or 'vertical'")
  }
  
  # -------------------------
  # Build table based on orientation
  # -------------------------
  if (orientation == "horizontal") {
    # Horizontal: single row with columns
    display_df <- study_summary %>%
      dplyr::select(
        n_detectors, n_detector_nights, study_start, study_end,
        study_duration_days, total_calls, total_hours,
        overall_mean_cph, overall_cv_pct, pct_success
      )
    
    gt_table <- display_df %>%
      gt::gt() %>%
      gt::tab_header(title = gt::md(paste0("**", title, "**"))) %>%
      gt::cols_label(
        n_detectors = "Detectors",
        n_detector_nights = "Detector-Nights",
        study_start = "Start",
        study_end = "End",
        study_duration_days = "Duration (days)",
        total_calls = gt::md("**Total Calls**"),
        total_hours = gt::md("**Total Hours**"),
        overall_mean_cph = "Mean CPH",
        overall_cv_pct = "CV %",
        pct_success = "Success %"
      ) %>%
      gt::fmt_integer(columns = c(n_detectors, n_detector_nights, 
                                  study_duration_days, total_calls)) %>%
      gt::fmt_number(columns = c(total_hours, overall_mean_cph), decimals = 1) %>%
      gt::fmt_number(columns = c(overall_cv_pct, pct_success), 
                     decimals = 1, pattern = "{x}%") %>%
      gt::fmt_date(columns = c(study_start, study_end), date_style = "yMd") %>%
      gt::tab_style(
        style = list(
          gt::cell_fill(color = "#f0f0f0"),
          gt::cell_text(weight = "bold")
        ),
        locations = gt::cells_column_labels()
      ) %>%
      gt::tab_style(
        style = gt::cell_text(weight = "bold", size = gt::px(14)),
        locations = gt::cells_body(columns = c(total_calls, total_hours))
      ) %>%
      gt::tab_options(
        table.font.size = gt::px(12),
        heading.title.font.size = gt::px(16),
        table.border.top.style = "solid",
        table.border.top.width = gt::px(2),
        table.border.bottom.style = "solid",
        table.border.bottom.width = gt::px(2)
      )
    
  } else {
    # Vertical: Metric and Value columns (safe numeric formatting)
    metric_labels <- c(
      n_detectors = "Number of Detectors",
      n_detector_nights = "Total Detector-Nights",
      study_start = "Study Start Date",
      study_end = "Study End Date",
      study_duration_days = "Study Duration (days)",
      total_calls = "Total Bat Calls",
      total_hours = "Total Recording Hours",
      overall_mean_cph = "Mean Calls Per Hour",
      overall_median_cph = "Median Calls Per Hour",
      overall_cv_pct = "Coefficient of Variation (%)",
      pct_success = "Nights with Full Recording (%)",
      pct_partial = "Nights with Partial Recording (%)",
      pct_fail = "Nights with No Recording (%)"
    )
    
    display_df <- study_summary %>%
      dplyr::select(dplyr::any_of(names(metric_labels))) %>%
      dplyr::mutate(dplyr::across(dplyr::everything(), as.character)) %>%  # <- ensures all types are character
      tidyr::pivot_longer(
        cols = dplyr::everything(),
        names_to = "metric_key",
        values_to = "value"
      ) %>%
      dplyr::mutate(
        Metric = metric_labels[metric_key],
        Value = dplyr::case_when(
          metric_key %in% c("study_start", "study_end") ~ value,
          metric_key %in% c("overall_cv_pct", "pct_success", "pct_partial", "pct_fail") ~
            ifelse(is.na(suppressWarnings(as.numeric(value))), "", 
                   paste0(round(as.numeric(value), 1), "%")),
          metric_key %in% c("overall_mean_cph", "overall_median_cph", "total_hours") ~
            ifelse(is.na(suppressWarnings(as.numeric(value))), "",
                   format(round(as.numeric(value), 1), nsmall = 1)),
          TRUE ~ ifelse(is.na(suppressWarnings(as.numeric(value))), "",
                        format(as.numeric(value), big.mark = ","))
        )
      ) %>%
      dplyr::select(Metric, Value)
    
    gt_table <- display_df %>%
      gt::gt() %>%
      gt::tab_header(title = gt::md(paste0("**", title, "**"))) %>%
      gt::cols_label(
        Metric = gt::md("**Metric**"),
        Value = gt::md("**Value**")
      ) %>%
      gt::tab_style(
        style = gt::cell_text(weight = "bold"),
        locations = gt::cells_body(columns = Metric)
      ) %>%
      gt::cols_align(align = "right", columns = Value) %>%
      gt::tab_style(
        style = list(
          gt::cell_fill(color = "#e8f4e8"),
          gt::cell_text(weight = "bold")
        ),
        locations = gt::cells_body(
          rows = Metric %in% c("Total Bat Calls", "Total Recording Hours")
        )
      ) %>%
      gt::tab_style(
        style = list(
          gt::cell_fill(color = "#f0f0f0"),
          gt::cell_text(weight = "bold")
        ),
        locations = gt::cells_column_labels()
      ) %>%
      gt::opt_row_striping() %>%
      gt::tab_options(
        table.font.size = gt::px(12),
        heading.title.font.size = gt::px(16),
        table.border.top.style = "solid",
        table.border.top.width = gt::px(2),
        table.border.bottom.style = "solid",
        table.border.bottom.width = gt::px(2)
      )
  }
  
  gt_table
}


# ------------------------------------------------------------------------------
# Format Hourly Activity Summary
# ------------------------------------------------------------------------------

#' Format Hourly Activity Profile as GT Table
#'
#' @description
#' Formats the output of create_hourly_activity_summary() as a GT table.
#' 
#' DETERMINISTIC DESIGN: This function expects a single, fixed schema from
#' create_hourly_activity_summary() with columns: Hour_local, n_calls, pct_of_total.
#' No branching logic for different formats.
#'
#' @param hourly_summary Tibble from create_hourly_activity_summary().
#'   Must contain: Hour_local, n_calls, pct_of_total.
#' @param title Character. Table title. Default: "Hourly Activity Profile"
#' @param subtitle Character. Table subtitle. Default: NULL
#' @param highlight_peak Logical. If TRUE (default), highlight the peak
#'   activity hour(s) with bold formatting.
#'
#' @return gt object ready for display or export
#'
#' @details
#' **Hour formatting:**
#' - Hour_local (0-23 integer) displayed as "HH:00" format
#'
#' **Peak highlighting:**
#' - Row with maximum n_calls displayed in bold
#'
#' @section CONTRACT:
#' - Expects output from create_hourly_activity_summary()
#' - Returns gt object
#' - Always study-wide format (no per-detector branching)
#' - Highlights peak hour in bold
#' - DETERMINISTIC: single input schema, single output format
#'
#' @section DOES NOT:
#' - Handle per-detector format (removed - violates determinism)
#' - Filter hours
#' - Adjust for recording schedule
#' - Create visualizations
#'
#' @examples
#' \dontrun{
#' hourly_summary <- create_hourly_activity_summary(kpro_master)
#' gt_hourly <- format_hourly_summary_gt(hourly_summary)
#' }
#'
#' @export
format_hourly_summary_gt <- function(hourly_summary,
                                     title = "Hourly Activity Profile",
                                     subtitle = NULL,
                                     highlight_peak = TRUE) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(hourly_summary)) {
    stop("hourly_summary must be a data frame")
  }
  
  # Expect fixed schema from create_hourly_activity_summary()
  required_cols <- c("Hour_local", "n_calls", "pct_of_total")
  missing_cols <- setdiff(required_cols, names(hourly_summary))
  
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "hourly_summary is missing required columns: %s\nDid you use create_hourly_activity_summary()?",
      paste(missing_cols, collapse = ", ")
    ))
  }
  
  # -------------------------
  # Format Hour as HH:00 (with robust type handling)
  # -------------------------
  
  display_df <- hourly_summary %>%
    dplyr::mutate(
      # Ensure Hour_local is integer before sprintf
      Hour_display = sprintf("%02d:00", as.integer(Hour_local))
    ) %>%
    dplyr::select(Hour = Hour_display, n_calls, pct_of_total)
  
  # -------------------------
  # Identify peak hours for highlighting
  # -------------------------
  
  peak_rows <- if (highlight_peak) {
    display_df$n_calls == max(display_df$n_calls, na.rm = TRUE) & 
      display_df$n_calls > 0 & 
      !is.na(display_df$n_calls)
  } else {
    rep(FALSE, nrow(display_df))
  }
  
  # -------------------------
  # Build GT table
  # -------------------------
  
  gt_table <- display_df %>%
    gt::gt() %>%
    
    # Title
    gt::tab_header(
      title = gt::md(paste0("**", title, "**")),
      subtitle = subtitle
    ) %>%
    
    # Column labels
    gt::cols_label(
      Hour = gt::md("**Hour**"),
      n_calls = "Calls",
      pct_of_total = "% of Total"
    ) %>%
    
    # Formatting
    gt::fmt_integer(columns = n_calls) %>%
    gt::fmt_number(columns = pct_of_total, decimals = 1, pattern = "{x}%") %>%
    
    # Hour column styling (monospace)
    gt::tab_style(
      style = gt::cell_text(font = gt::google_font("Roboto Mono")),
      locations = gt::cells_body(columns = Hour)
    ) %>%
    
    # Dim zero-call rows
    gt::tab_style(
      style = gt::cell_text(color = "#999999"),
      locations = gt::cells_body(rows = n_calls == 0)
    ) %>%
    
    # Header styling
    gt::tab_style(
      style = list(
        gt::cell_fill(color = "#f0f0f0"),
        gt::cell_text(weight = "bold")
      ),
      locations = gt::cells_column_labels()
    ) %>%
    
    # Table options
    gt::tab_options(
      table.font.size = gt::px(11),
      heading.title.font.size = gt::px(16),
      table.border.top.style = "solid",
      table.border.top.width = gt::px(2),
      table.border.bottom.style = "solid",
      table.border.bottom.width = gt::px(2)
    )
  
  # -------------------------
  # Apply peak highlighting (if any peak hours exist)
  # -------------------------
  
  if (any(peak_rows)) {
    gt_table <- gt_table %>%
      # Bold text for peak hours
      gt::tab_style(
        style = gt::cell_text(weight = "bold"),
        locations = gt::cells_body(rows = peak_rows)
      ) %>%
      # Low alpha highlight background for peak hours
      gt::tab_style(
        style = gt::cell_fill(color = "#FFD70040"),  # Gold with 25% opacity (40 in hex)
        locations = gt::cells_body(rows = peak_rows)
      )
  }
  
  gt_table
}


# ------------------------------------------------------------------------------
# Save GT Table to File
# ------------------------------------------------------------------------------

#' Save GT Table to PNG or HTML
#'
#' @description
#' Exports a GT table object to PNG (for standalone viewing) or HTML
#' (for Quarto embedding). Provides consistent sizing and resolution.
#'
#' @param gt_table gt object to save
#' @param filename Character. Output filename (with or without extension)
#' @param output_dir Character. Directory for output. Default: "results/figures"
#' @param format Character. Either "png" (default) or "html"
#' @param width_px Integer. Width in pixels for PNG. Default: 1200
#' @param dpi Integer. Resolution for PNG. Default: 300
#'
#' @return Character. Full path to saved file (invisibly)
#'
#' @details
#' **PNG export:**
#' - Requires webshot2 package
#' - 300 DPI suitable for publication
#'
#' **HTML export:**
#' - Self-contained HTML file
#' - Can be embedded in Quarto documents
#'
#' @section CONTRACT:
#' - Creates output directory if it doesn't exist
#' - Returns full path to saved file
#' - Overwrites existing files without warning
#' - Logs success message
#'
#' @section DOES NOT:
#' - Add timestamps to filenames
#' - Create multiple output formats in one call
#' - Modify the input gt object
#'
#' @examples
#' \dontrun{
#' gt_table <- format_detector_summary_gt(detector_summary)
#' save_gt_table(gt_table, "detector_summary", format = "png")
#' save_gt_table(gt_table, "detector_summary", format = "html")
#' }
#'
#' @export
save_gt_table <- function(gt_table,
                          filename,
                          output_dir = "results/figures",
                          format = "png",
                          width_px = 1200,
                          dpi = 300) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!inherits(gt_table, "gt_tbl")) {
    stop("gt_table must be a gt object")
  }
  
  if (!is.character(filename) || length(filename) != 1) {
    stop("filename must be a single character string")
  }
  
  if (!format %in% c("png", "html")) {
    stop("format must be 'png' or 'html'")
  }
  
  # -------------------------
  # Ensure output directory exists
  # -------------------------
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    message(sprintf("Created directory: %s", output_dir))
  }
  
  # -------------------------
  # Build file path
  # -------------------------
  
  # Remove extension if present
  filename_clean <- tools::file_path_sans_ext(basename(filename))
  
  # Add correct extension
  file_ext <- paste0(".", format)
  full_filename <- paste0(filename_clean, file_ext)
  file_path <- file.path(output_dir, full_filename)
  
  # -------------------------
  # Save file
  # -------------------------
  
  if (format == "png") {
    # Check for webshot2
    if (!requireNamespace("webshot2", quietly = TRUE)) {
      stop("Package 'webshot2' is required for PNG export. Install with: install.packages('webshot2')")
    }
    
    gt::gtsave(
      gt_table,
      filename = file_path,
      vwidth = width_px,
      zoom = dpi / 96  # Convert DPI to zoom factor (96 is base DPI)
    )
    
  } else {
    # HTML export
    gt::gtsave(
      gt_table,
      filename = file_path
    )
  }
  
  message(sprintf("✓ Saved table: %s", file_path))
  
  invisible(file_path)
}


# ------------------------------------------------------------------------------
# Save Summary CSV
# ------------------------------------------------------------------------------

#' Save Summary Statistic to CSV with Artifact Registration
#'
#' @description
#' Exports a summary data frame to CSV and optionally registers it as an
#' artifact with SHA256 hashing. Provides consistent directory structure
#' and naming conventions for all summary statistic exports.
#'
#' @param summary_df Data frame. Summary statistic to export
#' @param filename Character. Output filename (without path, with or without .csv extension)
#' @param output_dir Character. Directory for output. Default: "results/csv/summary_stats"
#' @param registry List. Artifact registry object (from init_artifact_registry()).
#'   If provided, artifact will be registered with hash. Default: NULL (no registration)
#' @param artifact_name Character. Name for artifact registry entry. Required if registry provided.
#' @param artifact_type Character. Type for artifact registry. Default: "summary_stats"
#' @param workflow Character. Workflow identifier. Default: "05"
#' @param metadata List. Additional metadata for registry. Default: list()
#' @param verbose Logical. Print progress messages? Default: TRUE
#'
#' @return Character. Full path to saved file (invisibly). If registry provided,
#'   returns updated registry (invisibly) with 'file_path' attribute.
#'
#' @details
#' **Directory structure:**
#' - Creates output_dir if it doesn't exist
#' - All summary CSVs go to results/csv/summary_stats/ by default
#'
#' **CSV format:**
#' - Uses write.csv() with row.names = FALSE
#' - Standard R CSV conventions (comma-delimited, quoted strings)
#'
#' **Artifact registration:**
#' - When registry provided, computes SHA256 hash
#' - Adds file size, creation timestamp
#' - Includes custom metadata
#'
#' @section CONTRACT:
#' - Creates output directory if needed
#' - Returns full path to saved file
#' - Overwrites existing files without warning
#' - If registry provided, returns updated registry with file_path attribute
#' - Logs success message (gated by verbose)
#'
#' @section DOES NOT:
#' - Add timestamps to filenames (caller's responsibility)
#' - Validate data frame content
#' - Create multiple output formats
#'
#' @examples
#' \dontrun{
#' # Simple CSV export
#' save_summary_csv(detector_summary, "detector_summary_20260208.csv")
#' 
#' # With artifact registration
#' registry <- init_artifact_registry()
#' registry <- save_summary_csv(
#'   detector_summary,
#'   "detector_summary_20260208.csv",
#'   registry = registry,
#'   artifact_name = "detector_summary_20260208",
#'   metadata = list(n_detectors = nrow(detector_summary))
#' )
#' }
#'
#' @export
save_summary_csv <- function(summary_df,
                             filename,
                             output_dir = "results/csv/summary_stats",
                             registry = NULL,
                             artifact_name = NULL,
                             artifact_type = "summary_stats",
                             workflow = "05",
                             metadata = list(),
                             verbose = TRUE) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(summary_df)) {
    stop("summary_df must be a data frame")
  }
  
  if (!is.character(filename) || length(filename) != 1) {
    stop("filename must be a single character string")
  }
  
  if (nrow(summary_df) == 0) {
    warning("Exporting empty data frame")
  }
  
  # If registry provided, artifact_name is required
  if (!is.null(registry) && is.null(artifact_name)) {
    stop("artifact_name is required when registry is provided")
  }
  
  # -------------------------
  # Ensure output directory exists
  # -------------------------
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    if (verbose) message(sprintf("Created directory: %s", output_dir))
  }
  
  # -------------------------
  # Build file path
  # -------------------------
  
  # Ensure .csv extension
  if (!grepl("\\.csv$", filename, ignore.case = TRUE)) {
    filename <- paste0(filename, ".csv")
  }
  
  file_path <- file.path(output_dir, filename)
  
  # -------------------------
  # Write CSV
  # -------------------------
  
  write.csv(summary_df, file_path, row.names = FALSE)
  
  if (verbose) {
    message(sprintf("✓ Saved CSV: %s", file_path))
  }
  
  # -------------------------
  # Register artifact (if requested)
  # -------------------------
  
  if (!is.null(registry)) {
    
    # Add file size to metadata
    metadata$n_rows <- nrow(summary_df)
    metadata$n_cols <- ncol(summary_df)
    
    registry <- register_artifact(
      registry = registry,
      artifact_name = artifact_name,
      artifact_type = artifact_type,
      workflow = workflow,
      file_path = file_path,
      metadata = metadata
    )
    
    if (verbose) {
      message(sprintf("✓ Registered artifact: %s", artifact_name))
    }
    
    # Return updated registry with file_path as attribute
    attr(registry, "file_path") <- file_path
    return(invisible(registry))
  }
  
  invisible(file_path)
}


# ------------------------------------------------------------------------------
# Build Excel Workbook from CSV Files
# ------------------------------------------------------------------------------

#' Build Excel Workbook from Summary CSV Files
#'
#' @description
#' Creates a multi-sheet Excel workbook by reading individual summary CSV files.
#' This ensures the Excel workbook is built from the same CSV artifacts that
#' are registered and validated, maintaining consistency across output formats.
#'
#' @param csv_files Named character vector. Paths to CSV files, with names
#'   being the sheet names. Example: c("Detector Summary" = "path/to/detector.csv")
#' @param output_file Character. Path for output Excel file
#' @param registry List. Artifact registry object. If provided, workbook will be registered.
#'   Default: NULL (no registration)
#' @param artifact_name Character. Name for artifact registry entry. Required if registry provided.
#' @param workflow Character. Workflow identifier. Default: "05"
#' @param metadata List. Additional metadata for registry. Default: list()
#' @param verbose Logical. Print progress messages? Default: TRUE
#'
#' @return Character. Path to saved Excel file (invisibly). If registry provided,
#'   returns updated registry (invisibly) with 'file_path' attribute.
#'
#' @details
#' **Workflow:**
#' 1. Reads each CSV file
#' 2. Creates Excel workbook with openxlsx
#' 3. Adds one sheet per CSV file
#' 4. Writes formatted data (auto column widths)
#' 5. Optionally registers as artifact
#'
#' **Sheet naming:**
#' - Uses names from csv_files vector as sheet names
#' - Sheet order matches csv_files order
#'
#' **Excel formatting:**
#' - Auto-sized columns for readability
#' - Header row frozen
#' - Standard formatting (no colors or complex styling)
#'
#' **Requires:** openxlsx package must be installed
#'
#' @section CONTRACT:
#' - All CSV files must exist and be readable
#' - Creates output directory if needed
#' - Overwrites existing Excel file
#' - Returns path to created file
#' - If registry provided, returns updated registry
#'
#' @section DOES NOT:
#' - Validate CSV content or structure
#' - Apply complex Excel formatting
#' - Create visualizations or charts
#' - Handle non-CSV input files
#'
#' @examples
#' \dontrun{
#' csv_files <- c(
#'   "Detector Summary" = "results/csv/summary_stats/detector_summary.csv",
#'   "Study Summary" = "results/csv/summary_stats/study_summary.csv"
#' )
#' 
#' build_excel_from_csv(
#'   csv_files,
#'   output_file = "results/xlsx/summary_stats.xlsx"
#' )
#' }
#'
#' @export
build_excel_from_csv <- function(csv_files,
                                 output_file,
                                 registry = NULL,
                                 artifact_name = NULL,
                                 workflow = "05",
                                 metadata = list(),
                                 verbose = TRUE) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required for Excel export. Install with: install.packages('openxlsx')")
  }
  
  if (!is.character(csv_files) || length(csv_files) == 0) {
    stop("csv_files must be a non-empty character vector")
  }
  
  if (is.null(names(csv_files)) || any(names(csv_files) == "")) {
    stop("csv_files must be a named vector with sheet names")
  }
  
  if (!is.character(output_file) || length(output_file) != 1) {
    stop("output_file must be a single character string")
  }
  
  # Check all CSV files exist
  missing_files <- csv_files[!file.exists(csv_files)]
  if (length(missing_files) > 0) {
    stop(sprintf(
      "CSV files not found:\n  %s",
      paste(missing_files, collapse = "\n  ")
    ))
  }
  
  # If registry provided, artifact_name is required
  if (!is.null(registry) && is.null(artifact_name)) {
    stop("artifact_name is required when registry is provided")
  }
  
  # -------------------------
  # Ensure output directory exists
  # -------------------------
  
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    if (verbose) message(sprintf("Created directory: %s", output_dir))
  }
  
  # -------------------------
  # Create Excel workbook
  # -------------------------
  
  if (verbose) {
    message(sprintf("Building Excel workbook from %d CSV files...", length(csv_files)))
  }
  
  wb <- openxlsx::createWorkbook()
  
  # Add each CSV as a sheet
  for (i in seq_along(csv_files)) {
    sheet_name <- names(csv_files)[i]
    csv_path <- csv_files[i]
    
    if (verbose) {
      message(sprintf("  Adding sheet: %s", sheet_name))
    }
    
    # Read CSV
    df <- read.csv(csv_path, stringsAsFactors = FALSE)
    
    # Add worksheet
    openxlsx::addWorksheet(wb, sheet_name)
    
    # Write data
    openxlsx::writeData(wb, sheet_name, df)
    
    # Auto-size columns for readability
    openxlsx::setColWidths(wb, sheet_name, cols = 1:ncol(df), widths = "auto")
    
    # Freeze header row
    openxlsx::freezePane(wb, sheet_name, firstRow = TRUE)
  }
  
  # -------------------------
  # Save workbook
  # -------------------------
  
  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
  
  if (verbose) {
    message(sprintf("✓ Saved Excel workbook: %s", output_file))
  }
  
  # -------------------------
  # Register artifact (if requested)
  # -------------------------
  
  if (!is.null(registry)) {
    
    # Add workbook metadata
    metadata$n_sheets <- length(csv_files)
    metadata$sheet_names <- names(csv_files)
    metadata$source_csvs <- unname(csv_files)
    
    registry <- register_artifact(
      registry = registry,
      artifact_name = artifact_name,
      artifact_type = "summary_stats",
      workflow = workflow,
      file_path = output_file,
      metadata = metadata
    )
    
    if (verbose) {
      message(sprintf("✓ Registered artifact: %s", artifact_name))
    }
    
    # Return updated registry with file_path as attribute
    attr(registry, "file_path") <- output_file
    return(invisible(registry))
  }
  
  invisible(output_file)
}


# ==============================================================================
# NEW HELPER FUNCTIONS (Added for Module Refactoring)
# ==============================================================================

# ==============================================================================
# END OF FILE
# ==============================================================================