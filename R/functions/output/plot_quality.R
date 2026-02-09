# =============================================================================
# UTILITY: plot_quality.R - Data Quality Visualizations
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# PURPOSE
# -------
# Provides visualization functions focused on data quality and recording
# effort metrics. These plots help researchers and land managers understand
# the reliability and completeness of their acoustic monitoring data.
#
# All functions return ggplot2 objects that can be further customized,
# combined with other plots, or saved using ggsave().
#
# DEPENDENCIES
# ------------
# External Packages:
#   - ggplot2: All plotting
#   - dplyr: Data manipulation for plot preparation
#   - tidyr: expand_grid for complete grids
#   - lubridate: Date manipulation
#
# Internal Dependencies:
#   - plot_helpers.R: theme_kpro(), validate_plot_input(), kpro_status_colors(),
#                     format_number()
#
# FUNCTIONS PROVIDED
# ------------------
#
# Recording Status Summaries - Deployment success rates:
#
#   - plot_recording_status_summary():
#       Uses packages: ggplot2 (ggplot, aes, geom_col, position_stack),
#                      dplyr (group_by, mutate, arrange)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_status_colors, format_number)
#       Purpose: Stacked bar of Success/Partial/Fail nights by detector
#
#   - plot_recording_status_percent():
#       Uses packages: ggplot2 (ggplot, aes, geom_col, position_fill),
#                      dplyr (group_by, mutate), scales (percent)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_status_colors, format_number)
#       Purpose: 100% stacked bar of status percentages by detector
#
#   - plot_recording_status_overall():
#       Uses packages: ggplot2 (ggplot, aes, geom_bar, coord_polar),
#                      dplyr (group_by, summarize)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_status_colors)
#       Purpose: Donut chart of status distribution (study-wide)
#
# Effort Summaries - Recording deployment metrics:
#
#   - plot_effort_by_detector():
#       Uses packages: ggplot2 (ggplot, aes, geom_col), dplyr (arrange)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Bar chart of total recording hours per detector
#
#   - plot_nights_by_detector():
#       Uses packages: ggplot2 (ggplot, aes, geom_col), dplyr (arrange)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Bar chart of recording nights per detector
#
# Data Completeness - Missing data visualization:
#
#   - plot_data_completeness_calendar():
#       Uses packages: ggplot2 (ggplot, aes, geom_tile, facet_wrap, scale_fill_gradient),
#                      dplyr (group_by, mutate), tidyr (expand_grid),
#                      lubridate (week, wday)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       format_number)
#       Purpose: Calendar heatmap of nights recorded (light to dark = few to many)
#
#   - plot_missing_nights():
#       Uses packages: ggplot2 (ggplot, aes, geom_col), dplyr (anti_join),
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_status_colors, format_number)
#       Purpose: Bar chart of missing night count per detector
#
#   - plot_recording_effort_heatmap():
#       Uses packages: ggplot2 (ggplot, aes, geom_tile, facet_wrap, scale_fill_gradient),
#                      dplyr (group_by, summarize), tidyr (pivot_wider, expand_grid)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       format_number)
#       Purpose: Heatmap of effort (hours or calls) by detector × night
# USAGE
# -----
# # Source via load_all.R or directly:
# source("R/functions/output/plot_helpers.R")  # Must be first
# source("R/functions/output/plot_quality.R")
#
# # Generate plot
# p <- plot_recording_status_summary(calls_per_night_final)
#
# Last Modified: 2026-02-09
#
# CHANGELOG
# ---------
# 2026-02-01: Verified deterministic behavior - all functions follow standards
# 2026-02-08: Confirmed usage in run_phase3_analysis_reporting() (Phase 3, Module 6)
# 2026-01-07: Moved plot_recording_effort_heatmap() from plot_temporal.R to plot_quality.R
# 2025-12-30: Initial creation with CODING_STANDARDS compliance
#
# =============================================================================


# =============================================================================
# RECORDING STATUS SUMMARIES
# =============================================================================

#' Recording Status Summary by Detector
#'
#' @description
#' Creates a stacked bar chart showing the count of Success/Partial/Fail
#' nights for each detector. This is a critical data quality visualization
#' that helps identify problematic deployments.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Status: Character. Recording status ("Success", "Partial", "Fail").
#' @param show_counts Logical. If TRUE (default), display count labels in
#'   bar segments.
#'
#' @return ggplot object showing stacked status bars by detector.
#'
#' @details
#' Detectors are ordered by success rate (highest to lowest), making it
#' easy to identify which sites had the most reliable recordings.
#'
#' Status definitions (from CallsPerNight generation):
#' - Success: Full night of recording with expected hours
#' - Partial: Recording started or ended unexpectedly (battery, weather)
#' - Fail: No usable recording (equipment failure, SD card error)
#'
#' Color coding uses the standard kpro_status_colors():
#' - Success: Green (#009E73)
#' - Partial: Orange (#E69F00)
#' - Fail: Vermillion (#D55E00)
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Detectors ordered by descending success rate
#' - Uses standard status colors
#' - Works with any subset of status values
#'
#' @section DOES NOT:
#' - Define what constitutes Success/Partial/Fail (uses Status column as-is)
#' - Calculate percentages (use plot_recording_status_percent for that)
#' - Flag specific thresholds for acceptable quality
#'
#' @examples
#' \dontrun{
#' # With count labels (default)
#' p <- plot_recording_status_summary(calls_per_night_final)
#'
#' # Without count labels (cleaner for many detectors)
#' p <- plot_recording_status_summary(cpn, show_counts = FALSE)
#' }
#'
#' @export
plot_recording_status_summary <- function(calls_per_night, show_counts = TRUE) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Status"),
    df_name = "calls_per_night"
  )
  
  # Standardize Status as factor with consistent ordering
  calls_per_night <- calls_per_night %>%
    dplyr::mutate(
      Status = factor(
        Status,
        levels = c("Success", "Partial", "Fail")
      )
    )
  
  # Calculate counts per detector and status
  status_counts <- calls_per_night %>%
    dplyr::count(Detector, Status, name = "n_nights") %>%
    dplyr::group_by(Detector) %>%
    dplyr::mutate(
      total_nights = sum(n_nights),
      pct = n_nights / total_nights * 100
    ) %>%
    dplyr::ungroup()
  
  # Order detectors by success rate (descending)
  detector_order <- status_counts %>%
    dplyr::filter(Status == "Success") %>%
    dplyr::arrange(dplyr::desc(pct)) %>%
    dplyr::pull(Detector)
  
  status_counts <- status_counts %>%
    dplyr::mutate(Detector = factor(Detector, levels = detector_order))
  
  # Build base plot
  p <- ggplot(status_counts, aes(x = Detector, y = n_nights, fill = Status)) +
    geom_col(position = "stack") +
    scale_fill_manual(values = kpro_status_colors()) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
    labs(
      title = "Recording Status by Detector",
      subtitle = "Ordered by success rate (highest to lowest)",
      x = "Detector",
      y = "Number of Nights",
      fill = "Status"
    ) +
    theme_kpro(rotate_x = TRUE) +
    theme(legend.position = "top")
  
  # Optionally add count labels
  if (show_counts) {
    status_counts_labeled <- status_counts %>%
      dplyr::filter(n_nights > 0) %>%
      dplyr::group_by(Detector) %>%
      dplyr::arrange(dplyr::desc(Status)) %>%
      dplyr::mutate(
        cumsum = cumsum(n_nights),
        label_y = cumsum - n_nights / 2
      ) %>%
      dplyr::ungroup()
    
    p <- p + geom_text(
      data = status_counts_labeled,
      aes(y = label_y, label = n_nights),
      size = 3,
      color = "white"
    )
  }
  
  p
}


#' Recording Status Percentage by Detector
#'
#' @description
#' Creates a 100% stacked bar chart showing the proportion of Success/
#' Partial/Fail nights for each detector. Easier to compare relative data
#' quality across detectors than raw counts.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Status: Character. Recording status ("Success", "Partial", "Fail").
#'
#' @return ggplot object showing percentage stacked bars.
#'
#' @details
#' A horizontal dashed line at 90% provides a reference threshold. Detectors
#' below this line may warrant investigation for equipment or deployment
#' issues.
#'
#' This plot complements plot_recording_status_summary() by normalizing
#' for different numbers of deployment nights across detectors.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - All bars sum to 100%
#' - Detectors ordered by success rate
#' - 90% threshold line shown for reference
#'
#' @section DOES NOT:
#' - Show raw counts (use plot_recording_status_summary)
#' - Define quality thresholds (90% line is suggestive only)
#'
#' @examples
#' \dontrun{
#' p <- plot_recording_status_percent(calls_per_night_final)
#' print(p)
#' }
#'
#' @export
plot_recording_status_percent <- function(calls_per_night) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Status"),
    df_name = "calls_per_night"
  )
  
  # Standardize and calculate percentages
  status_pct <- calls_per_night %>%
    dplyr::mutate(
      Status = factor(Status, levels = c("Success", "Partial", "Fail"))
    ) %>%
    dplyr::count(Detector, Status, name = "n_nights") %>%
    dplyr::group_by(Detector) %>%
    dplyr::mutate(pct = n_nights / sum(n_nights) * 100) %>%
    dplyr::ungroup()
  
  # Order by success rate
  detector_order <- status_pct %>%
    dplyr::filter(Status == "Success") %>%
    dplyr::arrange(dplyr::desc(pct)) %>%
    dplyr::pull(Detector)
  
  status_pct <- status_pct %>%
    dplyr::mutate(Detector = factor(Detector, levels = detector_order))
  
  # Build plot
  ggplot(status_pct, aes(x = Detector, y = pct, fill = Status)) +
    geom_col(position = "fill") +
    scale_fill_manual(values = kpro_status_colors()) +
    scale_y_continuous(
      labels = scales::percent,
      expand = expansion(mult = c(0, 0))
    ) +
    geom_hline(yintercept = 0.9, linetype = "dashed", color = "gray30") +
    labs(
      title = "Recording Status Breakdown by Detector",
      subtitle = "Dashed line = 90% threshold",
      x = "Detector",
      y = "Percentage",
      fill = "Status"
    ) +
    theme_kpro(rotate_x = TRUE) +
    theme(legend.position = "top")
}


#' Study-Wide Recording Status Donut Chart
#'
#' @description
#' Creates a donut chart showing overall proportion of Success/Partial/Fail
#' nights across the entire study. Provides a quick summary of overall
#' data quality.
#'
#' @param calls_per_night Data frame. Must contain column:
#'   - Status: Character. Recording status ("Success", "Partial", "Fail").
#'
#' @return ggplot object showing donut chart with total nights in center.
#'
#' @details
#' The center of the donut displays the total number of recording nights
#' across all detectors. Segment labels show the percentage for each status.
#'
#' This plot is useful for executive summaries or quick quality assessments
#' when detailed per-detector information is not needed.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Percentages sum to 100%
#' - Total night count shown in center
#' - Uses standard status colors
#'
#' @section DOES NOT:
#' - Show detector-level breakdown
#' - Display raw counts by status (only percentages and total)
#'
#' @examples
#' \dontrun{
#' p <- plot_recording_status_overall(calls_per_night_final)
#' print(p)
#' }
#'
#' @export
plot_recording_status_overall <- function(calls_per_night) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = "Status",
    df_name = "calls_per_night"
  )
  
  # Calculate totals by status
  status_totals <- calls_per_night %>%
    dplyr::mutate(
      Status = factor(Status, levels = c("Success", "Partial", "Fail"))
    ) %>%
    dplyr::count(Status, name = "n_nights") %>%
    dplyr::mutate(
      pct = n_nights / sum(n_nights) * 100,
      label = sprintf(
        "%s\n%s (%.1f%%)",
        Status,
        format_number(n_nights),
        pct
      )
    )
  
  total_nights <- sum(status_totals$n_nights)
  
  # Build donut chart using coord_polar
  ggplot(status_totals, aes(x = 2, y = n_nights, fill = Status)) +
    geom_col(width = 1) +
    coord_polar(theta = "y") +
    xlim(c(0.5, 2.5)) +
    scale_fill_manual(values = kpro_status_colors()) +
    geom_text(
      aes(label = sprintf("%.0f%%", pct)),
      position = position_stack(vjust = 0.5),
      color = "white",
      size = 4,
      fontface = "bold"
    ) +
    annotate(
      "text",
      x = 0.5,
      y = 0,
      label = sprintf("%s\nnights", format_number(total_nights)),
      size = 5,
      fontface = "bold"
    ) +
    labs(
      title = "Overall Recording Status",
      fill = "Status"
    ) +
    theme_void() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
      legend.position = "bottom"
    )
}


# =============================================================================
# EFFORT SUMMARIES
# =============================================================================

#' Recording Effort by Detector
#'
#' @description
#' Creates a horizontal bar chart showing total recording hours per detector.
#' Useful for understanding sampling effort distribution across monitoring
#' sites.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - RecordingHours: Numeric. Recording hours per night.
#'
#' @return ggplot object showing total recording hours by detector.
#'
#' @details
#' Detectors are ordered by total recording hours (ascending), so the
#' most-sampled detector appears at the top. A vertical dashed line
#' shows the mean effort across all detectors.
#'
#' This plot helps identify:
#' - Under-sampled detectors
#' - Equipment that may have failed early
#' - Uneven deployment schedules
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Detectors ordered by ascending total hours
#' - Mean effort shown as reference line
#' - Hour labels on each bar
#'
#' @section DOES NOT:
#' - Show number of nights (use plot_nights_by_detector)
#' - Distinguish between few full nights vs. many partial nights
#' - Account for expected deployment length
#'
#' @examples
#' \dontrun{
#' p <- plot_effort_by_detector(calls_per_night_final)
#' print(p)
#' }
#'
#' @export
plot_effort_by_detector <- function(calls_per_night) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "RecordingHours"),
    numeric_cols = "RecordingHours",
    df_name = "calls_per_night"
  )
  
  # Calculate total effort per detector
  effort_summary <- calls_per_night %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      total_hours = sum(RecordingHours, na.rm = TRUE),
      n_nights = dplyr::n(),
      mean_hours = mean(RecordingHours, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::arrange(total_hours) %>%
    dplyr::mutate(Detector = factor(Detector, levels = Detector))
  
  study_mean <- mean(effort_summary$total_hours)
  
  # Build plot
  ggplot(effort_summary, aes(x = total_hours, y = Detector)) +
    geom_col(fill = "#0072B2") +
    geom_vline(
      xintercept = study_mean,
      linetype = "dashed",
      color = "#D55E00"
    ) +
    geom_text(
      aes(label = sprintf("%.0f hrs", total_hours)),
      hjust = -0.1,
      size = 3
    ) +
    scale_x_continuous(
      expand = expansion(mult = c(0, 0.15)),
      labels = scales::comma
    ) +
    labs(
      title = "Total Recording Effort by Detector",
      subtitle = sprintf("Dashed line = study mean (%.0f hrs)", study_mean),
      x = "Total Recording Hours",
      y = "Detector"
    ) +
    theme_kpro()
}


#' Number of Recording Nights by Detector
#'
#' @description
#' Creates a horizontal bar chart showing how many nights each detector
#' was active. Useful for understanding deployment coverage and identifying
#' detectors with fewer recording nights than expected.
#'
#' @param calls_per_night Data frame. Must contain column:
#'   - Detector: Character. Unique detector identifier.
#' @param highlight_threshold Integer or NULL. If specified, detectors with
#'   fewer nights than this threshold are highlighted in a warning color.
#'   Default is NULL (no highlighting).
#'
#' @return ggplot object showing number of nights by detector.
#'
#' @details
#' Detectors are ordered by ascending number of nights, so detectors with
#' the fewest nights appear at the top for easy identification.
#'
#' If highlight_threshold is set, detectors below the threshold are shown
#' in orange/vermillion to draw attention to potentially problematic
#' deployments.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Detectors ordered by ascending night count
#' - Count labels on each bar
#' - Optional threshold highlighting
#'
#' @section DOES NOT:
#' - Show recording hours (use plot_effort_by_detector)
#' - Account for expected deployment length
#' - Distinguish Success/Partial/Fail nights
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' p <- plot_nights_by_detector(calls_per_night_final)
#'
#' # Highlight detectors with fewer than 20 nights
#' p <- plot_nights_by_detector(cpn, highlight_threshold = 20)
#' }
#'
#' @export
plot_nights_by_detector <- function(calls_per_night, highlight_threshold = NULL) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = "Detector",
    df_name = "calls_per_night"
  )
  
  # Count nights per detector
  nights_summary <- calls_per_night %>%
    dplyr::count(Detector, name = "n_nights") %>%
    dplyr::arrange(n_nights) %>%
    dplyr::mutate(Detector = factor(Detector, levels = Detector))
  
  # Add highlight flag if threshold specified
  if (!is.null(highlight_threshold)) {
    nights_summary <- nights_summary %>%
      dplyr::mutate(below_threshold = n_nights < highlight_threshold)
    
    p <- ggplot(
      nights_summary,
      aes(x = n_nights, y = Detector, fill = below_threshold)
    ) +
      geom_col() +
      scale_fill_manual(
        values = c("FALSE" = "#0072B2", "TRUE" = "#D55E00"),
        guide = "none"
      )
  } else {
    p <- ggplot(nights_summary, aes(x = n_nights, y = Detector)) +
      geom_col(fill = "#0072B2")
  }
  
  # Add common elements
  p +
    geom_text(
      aes(label = n_nights),
      hjust = -0.2,
      size = 3
    ) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.1))) +
    labs(
      title = "Recording Nights by Detector",
      x = "Number of Nights",
      y = "Detector"
    ) +
    theme_kpro()
}


# =============================================================================
# DATA COMPLETENESS
# =============================================================================

#' Data Completeness Calendar
#'
#' @description
#' Creates a calendar-style heatmap showing which nights have data for each
#' detector. Provides a quick visual for identifying gaps in coverage across
#' the study period.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Night: Date. Night of recording.
#'
#' @return ggplot object showing data completeness grid.
#'
#' @details
#' The plot shows every night in the study period for every detector:
#' - Green cells: Data present
#' - Red/pink cells: Data missing
#'
#' This makes gaps in coverage immediately visible, helping identify:
#' - Equipment failures mid-study
#' - Delayed deployments
#' - Early retrievals
#' - Systematic gaps (e.g., weekly maintenance)
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - All dates from study start to end shown
#' - All detectors shown
#' - Binary (present/missing) visualization
#'
#' @section DOES NOT:
#' - Show recording hours or quality
#' - Distinguish partial from complete nights
#' - Account for intentional non-deployment periods
#'
#' @examples
#' \dontrun{
#' p <- plot_data_completeness_calendar(calls_per_night_final)
#' print(p)
#' }
#'
#' @export
plot_data_completeness_calendar <- function(calls_per_night) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Night"),
    date_cols = "Night",
    df_name = "calls_per_night"
  )
  
  # Create complete grid for study period
  date_range <- range(calls_per_night$Night)
  all_nights <- seq(date_range[1], date_range[2], by = 1)
  all_detectors <- unique(calls_per_night$Detector)
  
  complete_grid <- tidyr::expand_grid(
    Detector = all_detectors,
    Night = all_nights
  )
  
  # Mark which combinations have data
  completeness <- complete_grid %>%
    dplyr::left_join(
      calls_per_night %>%
        dplyr::select(Detector, Night) %>%
        dplyr::distinct() %>%
        dplyr::mutate(has_data = TRUE),
      by = c("Detector", "Night")
    ) %>%
    dplyr::mutate(has_data = ifelse(is.na(has_data), FALSE, has_data))
  
  # Add week info for x-axis grouping
  completeness <- completeness %>%
    dplyr::mutate(
      week = lubridate::floor_date(Night, "week")
    )
  
  # Build heatmap
  ggplot(completeness, aes(x = week, y = Detector, fill = has_data)) +
    geom_tile(color = "white", linewidth = 0.3) +
    scale_fill_manual(
      values = c("FALSE" = "#ffcccc", "TRUE" = "#009E73"),
      labels = c("Missing", "Present"),
      name = "Data"
    ) +
    labs(
      title = "Data Completeness by Detector",
      subtitle = sprintf("%s to %s", date_range[1], date_range[2]),
      x = "Week",
      y = "Detector"
    ) +
    theme_kpro(rotate_x = TRUE) +
    theme(
      panel.grid = element_blank(),
      legend.position = "top"
    )
}


#' Missing Recording Nights by Detector
#'
#' @description
#' Creates a bar chart showing the number of missing nights per detector.
#' Missing nights are calculated as the difference between expected nights
#' (study date range) and actual recorded nights.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Night: Date. Night of recording.
#'
#' @return ggplot object showing missing night counts.
#'
#' @details
#' Expected nights are calculated from the overall study date range
#' (first night to last night across all detectors). Detectors deployed
#' for the full study should have zero missing nights.
#'
#' Each bar is labeled with both the missing count and the percentage
#' complete, making it easy to assess both absolute and relative gaps.
#'
#' Detectors are ordered by descending missing nights (most missing first),
#' so problematic deployments are immediately visible.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Expected nights based on study date range
#' - Shows both count and percentage complete
#' - Detectors ordered by descending missing count
#'
#' @section DOES NOT:
#' - Account for intentional staggered deployments
#' - Distinguish "no recording" from "no detections"
#' - Show which specific dates are missing
#'
#' @examples
#' \dontrun{
#' p <- plot_missing_nights(calls_per_night_final)
#' print(p)
#' }
#'
#' @export
plot_missing_nights <- function(calls_per_night) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Night"),
    date_cols = "Night",
    df_name = "calls_per_night"
  )
  
  # Calculate expected vs actual nights
  date_range <- range(calls_per_night$Night)
  expected_nights <- as.numeric(diff(date_range)) + 1
  
  missing_summary <- calls_per_night %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      actual_nights = dplyr::n_distinct(Night),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      missing_nights = expected_nights - actual_nights,
      pct_complete = actual_nights / expected_nights * 100
    ) %>%
    dplyr::arrange(dplyr::desc(missing_nights)) %>%
    dplyr::mutate(Detector = factor(Detector, levels = Detector))
  
  # Build plot
  ggplot(missing_summary, aes(x = Detector, y = missing_nights)) +
    geom_col(fill = "#D55E00") +
    geom_text(
      aes(
        label = sprintf(
          "%d\n(%.0f%% complete)",
          missing_nights,
          pct_complete
        )
      ),
      vjust = -0.2,
      size = 3
    ) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = "Missing Recording Nights by Detector",
      subtitle = sprintf("Expected: %d nights per detector", expected_nights),
      x = "Detector",
      y = "Missing Nights"
    ) +
    theme_kpro(rotate_x = TRUE)
}

#' Recording Effort Heatmap
#'
#' @description
#' Creates a heatmap showing recording effort (hours) across detectors and
#' nights. Helps identify deployment gaps, partial nights, and equipment
#' failures that affect data quality.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Night: Date. Night of recording.
#'   - RecordingHours: Numeric. Hours of recording per night.
#'
#' @return ggplot object showing effort heatmap.
#'
#' @details
#' The heatmap uses a viridis color scale where:
#' - Darker colors = more recording hours
#' - Lighter colors = fewer recording hours
#' - Gray = no data (detector not active or data missing)
#'
#' The plot automatically fills in missing detector × night combinations
#' with NA (shown as gray), making gaps in coverage visually apparent.
#'
#' Typical use cases:
#' - Identify nights when detectors failed
#' - Spot partial recording nights (equipment issues, battery)
#' - Verify consistent deployment across all sites
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - All dates in study period shown (including gaps)
#' - Missing data shown as gray (NA)
#' - Uses viridis color scale for accessibility
#'
#' @section DOES NOT:
#' - Flag specific thresholds (e.g., "partial" nights)
#' - Calculate expected recording hours
#' - Interpolate missing values
#'
#' @examples
#' \dontrun{
#' p <- plot_recording_effort_heatmap(calls_per_night_final)
#' print(p)
#' }
#'
#' @export
plot_recording_effort_heatmap <- function(calls_per_night) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Night", "RecordingHours"),
    date_cols = "Night",
    numeric_cols = "RecordingHours",
    df_name = "calls_per_night"
  )
  
  # Origin: 06_exploratory_plots.R, Standards: 04_data_standards.md §2.1 (NA handling)
  # Handle edge case where Night contains only NA values (prevents "from must be finite")
  valid_nights <- calls_per_night$Night[!is.na(calls_per_night$Night)]
  if (length(valid_nights) == 0) {
    warning("No valid Night values available for heatmap")
    return(
      ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No valid date data\nfor effort heatmap",
                 size = 5, hjust = 0.5) +
        theme_void() +
        labs(title = "Recording Effort Heatmap")
    )
  }
  
  # Create complete grid of all detector × night combinations
  all_nights <- seq(
    min(calls_per_night$Night),
    max(calls_per_night$Night),
    by = 1
  )
  all_detectors <- unique(calls_per_night$Detector)
  
  complete_grid <- tidyr::expand_grid(
    Detector = all_detectors,
    Night = all_nights
  ) %>%
    dplyr::left_join(
      calls_per_night %>% dplyr::select(Detector, Night, RecordingHours),
      by = c("Detector", "Night")
    )
  
  # Build heatmap
  ggplot(complete_grid, aes(x = Night, y = Detector, fill = RecordingHours)) +
    geom_tile(color = "white", linewidth = 0.2) +
    scale_fill_gradientn(
      colours = c("#d73027", "#fee08b", "#1a9850"),
      na.value = "gray80",
      name = "Hours"
    ) +
    labs(
      title = "Recording Effort Heatmap",
      subtitle = "Gray = no data; darker = more recording hours",
      x = "Night",
      y = "Detector"
    ) +
    theme_kpro(rotate_x = TRUE) +
    theme(panel.grid = element_blank())
}
