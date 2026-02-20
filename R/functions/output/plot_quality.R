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
#                       kpro_palette_detector, format_number)
#       Purpose: Bar chart of total recording hours per detector
#
#   - plot_nights_by_detector():
#       Uses packages: ggplot2 (ggplot, aes, geom_col), dplyr (arrange)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_detector, format_number)
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
#' Partial/Fail nights for each detector, with count labels inside bars.
#' Easier to compare relative data quality across detectors than raw counts.
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
#' - Show a separate raw-count-only view (counts are embedded here)
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
  ggplot(status_pct, aes(x = Detector, y = n_nights, fill = Status)) +
    geom_col(position = "fill") +
    scale_fill_manual(values = kpro_status_colors()) +
    scale_y_continuous(
      labels = scales::percent,
      expand = expansion(mult = c(0, 0))
    ) +
    geom_hline(yintercept = 0.9, linetype = "dashed", color = "gray30") +
    geom_text(
      data = status_pct %>% dplyr::filter(n_nights > 0),
      aes(label = n_nights),
      position = position_stack(vjust = 0.5),
      size = 3,
      color = "white"
    ) +
    labs(
      title = "Recording Status by Detector",
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
  detector_color_map <- get_detector_color_mapping(unique(calls_per_night$Detector))
  
  # Build plot
  ggplot(effort_summary, aes(x = total_hours, y = Detector, fill = Detector)) +
    geom_col() +
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
    scale_fill_manual(values = detector_color_map) +
    labs(
      title = "Total Recording Effort by Detector",
      subtitle = sprintf("Dashed line = study mean (%.0f hrs)", study_mean),
      x = "Total Recording Hours",
      y = "Detector"
    ) +
    theme_kpro() +
    theme(legend.position = "none")
}


#' Number of Recording Nights by Detector
#'
#' @description
#' Creates a horizontal bar chart showing how many nights each detector
#' successfully recorded (i.e., had RecordingHours > 0). Useful for
#' understanding deployment coverage and identifying detectors with fewer
#' active nights than expected.
#'
#' A "recording night" is defined as any night where the detector had
#' RecordingHours > 0. Nights with RecordingHours = 0 or NA are excluded.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - RecordingHours: Numeric. Hours of recording for each night (can be 0).
#' @param highlight_threshold Integer or NULL. If specified, detectors with
#'   fewer nights than this threshold are highlighted in a warning color.
#'   Default is NULL (no highlighting).
#'
#' @return ggplot object showing number of active recording nights by detector.
#'
#' @details
#' Data structure: Input typically contains one row per detector × night
#' combination within the study period. The complete grid may include rows
#' with RecordingHours = 0 for gaps or non-deployment nights.
#'
#' Counting logic: Only rows where `!is.na(RecordingHours) & RecordingHours > 0`
#' are counted as "nights with data". Rows with RecordingHours = 0 (gaps,
#' failed equipment, or non-deployment) are correctly excluded.
#'
#' Ordering: Detectors are sorted by ascending night count, so detectors with
#' the fewest nights appear at the top for easy identification.
#'
#' Highlighting: If `highlight_threshold` is set, detectors below the threshold
#' are shown in orange to draw attention to potentially problematic deployments.
#'
#' @section CONTRACT:
#' - Returns a ggplot object with detector names and night counts
#' - Detectors ordered by ascending night count (fewest first)
#' - Count labels on each bar showing exact number of nights
#' - Only counts nights where RecordingHours > 0
#' - Optional threshold highlighting with distinct fill colors
#' - Detector palette applied if no threshold specified
#'
#' @section DOES NOT:
#' - Show total recording hours (use plot_effort_by_detector for that)
#' - Account for expected deployment length or detector schedules
#' - Distinguish between Success/Partial/Fail status categories
#' - Include nights with zero recording hours in the count
#' - Provide statistical testing for differences in night counts
#'
#' @examples
#' \dontrun{
#' # Basic usage - all detectors colored by palette
#' p <- plot_nights_by_detector(calls_per_night_final)
#'
#' # Highlight detectors with fewer than 20 nights in warning color
#' p <- plot_nights_by_detector(cpn, highlight_threshold = 20)
#' }
#'
#' @export
plot_nights_by_detector <- function(calls_per_night, highlight_threshold = NULL) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "RecordingHours"),
    numeric_cols = "RecordingHours",
    df_name = "calls_per_night"
  )
  
  # DETERMINISTIC: Data structure validation
  # Expected: One row per Detector × Night combination within study period
  #         RecordingHours: numeric values (0, NA, or positive)
  # Output: Summary per detector showing count of rows where RecordingHours > 0
  
  # Count nights with recording present per detector
  # Only counts rows where RecordingHours > 0 (excludes zeros and NAs)
  nights_summary <- calls_per_night %>%
    dplyr::mutate(has_data = !is.na(RecordingHours) & RecordingHours > 0) %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      n_nights = sum(has_data, na.rm = TRUE),
      .groups = "drop"
    ) %>%
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
    detector_color_map <- get_detector_color_mapping(unique(nights_summary$Detector))
    p <- ggplot(nights_summary, aes(x = n_nights, y = Detector, fill = Detector)) +
      geom_col() +
      scale_fill_manual(values = detector_color_map) +
      theme(legend.position = "none")
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
#' Creates a calendar-style heatmap showing which nights have recording data
#' for each detector. Provides a quick visual for identifying gaps in coverage
#' across the study period.
#'
#' A night is marked as "data present" if that detector × night combination
#' has RecordingHours > 0. All other rows (including those with RecordingHours = 0)
#' are marked as "missing".
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Night: Date. Night of recording (must be valid Date class).
#'   - RecordingHours: Numeric. Hours of recording (0 = missing data).
#'
#' @return ggplot object showing data completeness grid by detector and week.
#'
#' @details
#' Grid construction: The function expands to a complete Detector × Night grid
#' for the entire study period, then marks each cell as having data (green) or
#' missing data (red) based on whether RecordingHours > 0.
#'
#' Time binning: Nights are grouped into weeks for the x-axis to reduce visual
#' density. Green cells indicate at least one night with RecordingHours > 0
#' in that week for that detector.
#'
#' Visual elements:
#' - Green cells: Data present (RecordingHours > 0)
#' - Red/pink cells: Data missing (RecordingHours = 0 or NA)
#' - White borders: Week boundaries
#'
#' Use cases: Helps identify:
#' - Equipment failures mid-study
#' - Delayed deployments
#' - Early retrievals  
#' - Systematic gaps (e.g., weekly maintenance windows)
#' - Detectors with incomplete coverage
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Complete detector × week grid shown for study period
#' - Binary coloring (green = has data, red = missing)
#' - Data presence defined by RecordingHours > 0
#' - Accurate representation of input data structure
#'
#' @section DOES NOT:
#' - Show recording hours or quality metrics
#' - Distinguish partial from complete coverage nights
#' - Account for intentional non-deployment periods
#' - Provide statistical summaries of completeness
#' - Include row labels on y-axis if detector count is very high
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
    required_cols = c("Detector", "Night", "RecordingHours"),
    date_cols = "Night",
    numeric_cols = "RecordingHours",
    df_name = "calls_per_night"
  )
  
  # DETERMINISTIC: Complete grid construction
  # Step 1: Identify study period date range from all valid Night values
  # Step 2: Expand to full Detector × Night grid (all combinations)
  # Step 3: Left-join with input data, marking has_data = RecordingHours > 0
  # Step 4: Group nights into weeks for display
  # Output: Binary heatmap (presence/absence of data)
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Night", "RecordingHours"),
    date_cols = "Night",
    numeric_cols = "RecordingHours",
    df_name = "calls_per_night"
  )
  
  # Create complete grid for study period
  valid_nights <- calls_per_night$Night[!is.na(calls_per_night$Night)]
  if (length(valid_nights) == 0) {
    warning("No valid Night values available for completeness calendar")
    return(
      ggplot() +
        annotate(
          "text",
          x = 0.5,
          y = 0.5,
          label = "No valid date data\nfor completeness calendar",
          size = 5,
          hjust = 0.5
        ) +
        theme_void() +
        labs(title = "Data Completeness by Detector")
    )
  }

  date_range <- range(valid_nights)
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
        dplyr::group_by(Detector, Night) %>%
        dplyr::summarise(
          has_data = any(!is.na(RecordingHours) & RecordingHours > 0),
          .groups = "drop"
        ),
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
#' Creates a bar chart showing the number of missing nights per detector,
#' calculated as the difference between expected nights (full study period)
#' and actual recording nights (nights where RecordingHours > 0).
#'
#' Important: "Expected nights" is defined as the global study date range
#' (first Night to last Night across ALL detectors), not per-detector
#' deployment schedules. All detectors are held to the same expected window.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Night: Date. Night of recording (must be valid Date class).
#'   - RecordingHours: Numeric. Hours of recording (0 = missing data).
#'
#' @return ggplot object showing missing night counts and completion percentages.
#'
#' @details
#' Expected nights calculation:
#'   All unique Night values (across all detectors) define range_min to range_max.
#'   expected_nights = (range_max - range_min + 1) day
#'   This applies uniformly to all detectors.
#'
#' Actual nights calculation:
#'   Per detector: count rows where RecordingHours > 0
#'   Excludes rows with RecordingHours = 0 or NA
#'
#' Missing nights calculation:
#'   missing = max(0, expected - actual)
#'   Percentage complete = (actual / expected) × 100%
#'
#' Ordering: Detectors ordered by descending missing count, so detectors
#' with the most problems appear first (most missing count at top).
#'
#' Labels: Each bar shows both absolute missing count and percentage
#' complete, making it easy to assess both size and relative impact.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Expected nights derived from global study date range (min/max Night)
#' - Actual nights counted per detector (RecordingHours > 0)
#' - Missing = max(0, expected - actual)
#' - Percentage complete calculated and displayed
#' - Detectors ordered by descending missing count
#' - Detector palette applied to bar fills
#'
#' @section DOES NOT:
#' - Account for intentional staggered deployments or partial schedules
#' - Distinguish "RecordingHours = 0" from "no detections"
#' - Show which specific dates/nights are missing
#' - Provide per-detector expected night configurability
#' - Test statistical significance of differences
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
    required_cols = c("Detector", "Night", "RecordingHours"),
    date_cols = "Night",
    numeric_cols = "RecordingHours",
    df_name = "calls_per_night"
  )
  
  # DETERMINISTIC: Expected vs Actual calculation
  # Step 1: Determine global study date range from ALL valid Night values
  # Step 2: Calculate expected_nights = full date range
  # Step 3: Per detector: count rows where RecordingHours > 0
  # Step 4: Calculate missing = expected - actual (never negative)
  # Step 5: Calculate pct_complete for display labels
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Night", "RecordingHours"),
    date_cols = "Night",
    numeric_cols = "RecordingHours",
    df_name = "calls_per_night"
  )
  
  # Normalize key types for deterministic counting
  calls_per_night <- calls_per_night %>%
    dplyr::mutate(
      Night = as.Date(Night),
      RecordingHours = as.numeric(RecordingHours)
    )

  # Calculate expected vs actual nights
  valid_nights <- calls_per_night$Night[!is.na(calls_per_night$Night)]
  if (length(valid_nights) == 0) {
    warning("No valid Night values available for missing nights plot")
    return(
      ggplot() +
        annotate(
          "text",
          x = 0.5,
          y = 0.5,
          label = "No valid date data\nfor missing nights plot",
          size = 5,
          hjust = 0.5
        ) +
        theme_void() +
        labs(title = "Missing Recording Nights by Detector")
    )
  }

  expected_nights <- dplyr::n_distinct(valid_nights)
  
  # Calculate actual nights with corrected filtering logic
  missing_summary <- calls_per_night %>%
    dplyr::mutate(has_data = !is.na(RecordingHours) & RecordingHours > 0) %>%
    dplyr::filter(has_data) %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      actual_nights = dplyr::n_distinct(Night),
      .groups = "drop"
    )
  
  # Store expected_nights as local variable to avoid scoping issues
  total_expected <- expected_nights
  
  missing_summary <- missing_summary %>%
    dplyr::mutate(
      missing_nights = pmax(0, total_expected - actual_nights),
      pct_complete = (actual_nights / total_expected) * 100
    ) %>%
    dplyr::arrange(dplyr::desc(missing_nights)) %>%
    dplyr::mutate(Detector = factor(Detector, levels = Detector))
  
  # Build plot
  detector_color_map <- get_detector_color_mapping(unique(missing_summary$Detector))

  ggplot(missing_summary, aes(x = Detector, y = missing_nights, fill = Detector)) +
    geom_col() +
    geom_text(
      aes(
        label = sprintf(
          "%d\n(%.1f%% complete)",
          missing_nights,
          pct_complete
        )
      ),
      vjust = -0.2,
      size = 3
    ) +
    scale_fill_manual(values = detector_color_map) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = "Missing Recording Nights by Detector",
      subtitle = sprintf("Expected: %d nights per detector", expected_nights),
      x = "Detector",
      y = "Missing Nights"
    ) +
    theme_kpro(rotate_x = TRUE) +
    theme(legend.position = "none")
}

#' Recording Effort Heatmap
#'
#' @description
#' Creates a heatmap showing recording effort (RecordingHours) across detectors
#' and nights. Provides spatial-temporal visualization of deployment coverage
#' and helps identify deployment gaps, partial nights, and equipment failures
#' that affect data quality.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Night: Date. Night of recording (must be valid Date class).
#'   - RecordingHours: Numeric. Hours of recording per night (0, NA, or positive).
#'
#' @return ggplot object showing recording effort (hours) heatmap by detector × night.
#'
#' @details
#' Color scale: Professional red-yellow-green gradient
#'   - Red     (#d73027): Little/no recording hours (poor effort)
#'   - Yellow  (#fee08b): Moderate recording hours (partial nights)
#'   - Green   (#1a9850): Full recording hours (complete coverage)
#'   - Gray    : No data (detector not deployed or data missing)
#'
#' Grid structure: Automatically fills in missing detector × night combinations
#' with NA (shown as gray), making gaps in coverage visually apparent.
#'
#' Use cases:
#' - Identify nights when detectors failed or were inactive
#' - Spot partial recording nights (battery issues, equipment problems)
#' - Verify consistent deployment across all detectors
#' - Visualize effort patterns over time (e.g., seasonal deployments)
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Complete detector × date grid shown for study period
#' - Professional red-yellow-green gradient for effort visualization
#' - Missing data shown as gray (NA values)
#' - Accurate representation of RecordingHours values
#'
#' @section DOES NOT:
#' - Flag specific threshold values (e.g., "partial" nights)
#' - Calculate expected recording hours per deployment
#' - Interpolate missing values
#' - Show per-night call counts (use detector plots for activity)
#' - Distinguish between zero hours and missing data in color
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
  
  # DETERMINISTIC: Red-yellow-green gradient color scale
  # Red = low/no effort, Yellow = moderate, Green = full effort
  # Gray = missing/no data (NA values)
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
