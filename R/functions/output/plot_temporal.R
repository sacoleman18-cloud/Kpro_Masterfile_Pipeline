# =============================================================================
# UTILITY: plot_temporal.R - Temporal Pattern Visualizations
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# PURPOSE
# -------
# Provides visualization functions focused on temporal bat activity patterns.
# These plots help researchers understand when bats are active (within nights,
# across nights, across weeks/months) and how activity changes over the study.
#
# All functions return ggplot2 objects that can be further customized,
# combined with other plots, or saved using ggsave().
#
# DEPENDENCIES
# ------------
# External Packages:
#   - ggplot2: All plotting
#   - dplyr: Data manipulation for plot preparation
#   - tidyr: complete() for filling gaps
#   - lubridate: Date/time manipulation
#   - scales: Axis formatting (comma, percent, date labels)
#
# Internal Dependencies:
#   - plot_helpers.R: theme_kpro(), validate_plot_input(), kpro_palette_cat(),
#                     format_number()
#
# FUNCTIONS PROVIDED
# ------------------
#
# Nightly Patterns - Temporal activity trends across nights:
#
#   - plot_activity_over_time():
#       Uses packages: ggplot2 (ggplot, aes, geom_line, geom_point, facet_wrap)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Line plot of calls per night by detector over study period
#
#   - plot_cumulative_calls_over_time():
#       Uses packages: ggplot2 (ggplot, aes, geom_line, geom_area, facet_wrap),
#                      dplyr (group_by, mutate, cumsum)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Running total (cumulative sum) of calls over time by detector
#
# Within-Night Patterns - Activity by hour of night:
#
#   - plot_hourly_activity_profile():
#       Uses packages: ggplot2 (ggplot, aes, geom_col, facet_wrap),
#                      dplyr (group_by, summarize)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Bar plot of call counts by hour, aggregated across all nights
#
#   - plot_callsperhour_distribution():
#       Uses packages: ggplot2 (ggplot, aes, geom_histogram, facet_wrap),
#                      dplyr (group_by, mutate)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Histogram of calls per hour (samples one hour per night)
#
# Seasonal Patterns - Aggregations over longer time periods:
#
#   - plot_weekly_activity():
#       Uses packages: ggplot2 (ggplot, aes, geom_col, facet_wrap),
#                      dplyr (group_by, summarize), lubridate (week, year)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Bar plot of activity by week across study period
#
#   - plot_activity_by_month():
#       Uses packages: ggplot2 (ggplot, aes, geom_col, facet_wrap),
#                      dplyr (group_by, summarize), lubridate (month, year)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Bar plot of activity by month across study period
# USAGE
# -----
# # Source via load_all.R or directly:
# source("R/functions/output/plot_helpers.R")  # Must be first
# source("R/functions/output/plot_temporal.R")
#
# # Generate plot
# p <- plot_activity_over_time(calls_per_night_final)
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
# NIGHTLY PATTERNS
# =============================================================================

#' Bat Activity Over Time by Detector
#'
#' @description
#' Creates a line plot showing nightly bat activity trends for each detector.
#' Useful for visualizing temporal patterns and comparing activity levels
#' across monitoring sites throughout the study period.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Night: Date. Night of recording.
#'   - CallsPerNight: Numeric. Number of calls per night.
#' @param show_points Logical. If TRUE, show data points in addition to
#'   lines. Default is FALSE.
#'
#' @return ggplot object showing nightly activity by detector.
#'
#' @details
#' Each detector is shown as a separate colored line. Colors are assigned
#' from the colorblind-accessible kpro_palette_cat().
#'
#' For studies with many detectors (>8), the legend may become crowded.
#' Consider faceting by detector or using plot_synchrony() instead.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Each detector shown as separate line
#' - Colors are colorblind-accessible
#' - Works with any number of detectors
#'
#' @section DOES NOT:
#' - Interpolate missing dates
#' - Smooth the data
#' - Normalize by recording effort
#' - Facet by detector (add + facet_wrap(~Detector) if needed)
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' p <- plot_activity_over_time(calls_per_night_final)
#'
#' # With data points
#' p <- plot_activity_over_time(cpn, show_points = TRUE)
#'
#' # Faceted by detector
#' p + facet_wrap(~Detector, scales = "free_y")
#' }
#'
#' @export
plot_activity_over_time <- function(calls_per_night, show_points = FALSE) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Night", "CallsPerNight"),
    date_cols = "Night",
    numeric_cols = "CallsPerNight",
    df_name = "calls_per_night"
  )
  
  # Origin: 06_exploratory_plots.R, Standards: 04_data_standards.md §2.1 (NA handling)
  # Filter out NA values to prevent geom_line() missing value warnings
  plot_data <- calls_per_night %>%
    dplyr::filter(!is.na(CallsPerNight), !is.na(Night))
  
  if (nrow(plot_data) == 0) {
    warning("No valid data available for activity over time plot")
    return(
      ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No valid data\nfor activity plot",
                 size = 5, hjust = 0.5) +
        theme_void() +
        labs(title = "Bat Activity Over Time")
    )
  }
  
  n_detectors <- dplyr::n_distinct(plot_data$Detector)
  
  # Build base plot
  p <- ggplot(
    plot_data,
    aes(x = Night, y = CallsPerNight, color = Detector)
  ) +
    geom_line(alpha = 0.8) +
    scale_y_continuous(labels = scales::comma) +
    scale_color_manual(values = kpro_palette_cat(n_detectors)) +
    labs(
      title = "Bat Activity Over Time",
      x = "Night",
      y = "Calls Per Night",
      color = "Detector"
    ) +
    theme_kpro()
  
  # Optionally add points
  if (show_points) {
    p <- p + geom_point(alpha = 0.6, size = 1)
  }
  
  p
}


#' Cumulative Calls Over Time
#'
#' @description
#' Shows the running total of bat calls through the study period. The slope
#' of the line indicates activity intensity: steeper sections represent
#' periods of higher activity.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Night: Date. Night of recording.
#'   - CallsPerNight: Numeric. Number of calls per night.
#' @param by_detector Logical. If TRUE, show separate cumulative lines for
#'   each detector. Requires Detector column. Default is FALSE.
#'
#' @return ggplot object showing cumulative activity curve.
#'
#' @details
#' Cumulative plots help visualize:
#' - Overall sampling effort (final total)
#' - Activity periods (steep slopes)
#' - Low-activity periods (flat sections)
#' - Relative contribution of each detector (if by_detector = TRUE)
#'
#' The study-wide version (by_detector = FALSE) first sums activity across
#' all detectors for each night, then calculates the running total.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Cumulative sum never decreases
#' - Final value equals total calls in dataset
#' - Works with gaps in dates (cumulative continues from previous value)
#'
#' @section DOES NOT:
#' - Interpolate missing dates
#' - Normalize by expected effort
#' - Reset cumulative count at any point
#'
#' @examples
#' \dontrun{
#' # Study-wide cumulative
#' p <- plot_cumulative_calls_over_time(calls_per_night_final)
#'
#' # By detector
#' p <- plot_cumulative_calls_over_time(cpn, by_detector = TRUE)
#' }
#'
#' @export
plot_cumulative_calls_over_time <- function(calls_per_night,
                                            by_detector = FALSE) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Night", "CallsPerNight"),
    date_cols = "Night",
    numeric_cols = "CallsPerNight",
    df_name = "calls_per_night"
  )
  
  if (by_detector && !"Detector" %in% names(calls_per_night)) {
    warning("Detector column not found. Showing study-wide cumulative.")
    by_detector <- FALSE
  }
  
  if (by_detector) {
    # Calculate cumulative sum per detector
    cumulative <- calls_per_night %>%
      dplyr::arrange(Detector, Night) %>%
      dplyr::group_by(Detector) %>%
      dplyr::mutate(cumulative_calls = cumsum(CallsPerNight)) %>%
      dplyr::ungroup()
    
    n_detectors <- dplyr::n_distinct(cumulative$Detector)
    
    p <- ggplot(
      cumulative,
      aes(x = Night, y = cumulative_calls, color = Detector)
    ) +
      geom_line(linewidth = 1) +
      scale_color_manual(values = kpro_palette_cat(n_detectors))
    
  } else {
    # Calculate study-wide cumulative
    cumulative <- calls_per_night %>%
      dplyr::arrange(Night) %>%
      dplyr::group_by(Night) %>%
      dplyr::summarise(
        daily_total = sum(CallsPerNight, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::mutate(cumulative_calls = cumsum(daily_total))
    
    p <- ggplot(cumulative, aes(x = Night, y = cumulative_calls)) +
      geom_line(color = "#0072B2", linewidth = 1)
  }
  
  # Add common elements
  p +
    scale_y_continuous(labels = scales::comma) +
    labs(
      title = "Cumulative Bat Calls Over Time",
      subtitle = "Slope indicates activity intensity",
      x = "Night",
      y = "Cumulative Calls"
    ) +
    theme_kpro()
}


# =============================================================================
# WITHIN-NIGHT PATTERNS
# =============================================================================

#' Study-Wide Hourly Activity Profile
#'
#' @description
#' Shows the overall temporal pattern of bat activity across the entire study.
#' 
#' DETERMINISTIC DESIGN: This function expects Hour_local column to exist,
#' created deterministically by Module 2. No conditional column creation.
#'
#' @param master_data Data frame. Must contain Hour_local column (integer 0-23).
#' @param metric Character. One of "total" (sum of all calls) or "mean"
#'   (average calls per hour per night). Default is "total".
#'
#' @return ggplot object showing hourly activity profile.
#'
#' @details
#' The plot shows all 24 hours on the x-axis (0-23). Activity is represented
#' by an area chart with line overlay for clear visibility.
#'
#' A vertical dashed line marks the peak activity hour with an annotation
#' showing the specific hour.
#'
#' For bat studies, typical patterns show:
#' - Low activity during daylight hours (06-18)
#' - Rising activity after sunset (19-21)
#' - Peak activity in early night (21-00)
#' - Declining activity toward dawn (03-05)
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - All 24 hours shown (including zero-activity hours)
#' - Peak hour annotated
#' - Hour_local MUST pre-exist (created in Workflow 02)
#' - DETERMINISTIC: no conditional column creation
#'
#' @section DOES NOT:
#' - Create Hour_local column (expects it pre-created in Workflow 02)
#' - Extract hours from DateTime_local (Hour_local must exist)
#' - Separate by species (use plot_species_hourly_profile)
#' - Account for sunset/sunrise time variation
#' - Separate by detector
#' - Normalize for recording effort by hour
#'
#' @examples
#' \dontrun{
#' # Hour_local must exist from Module 2
#' p <- plot_hourly_activity_profile(kpro_master)
#'
#' # Mean calls per hour per night
#' p <- plot_hourly_activity_profile(kpro_master, metric = "mean")
#' }
#'
#' @export
plot_hourly_activity_profile <- function(master_data, metric = "total") {
  
  # Validate input - Hour_local MUST exist
  validate_plot_input(
    master_data,
    required_cols = "Hour_local",
    df_name = "master_data"
  )
  
  metric <- match.arg(metric, c("total", "mean"))
  
  # Ensure Hour_local is integer for consistent operations
  master_data <- master_data %>%
    dplyr::mutate(Hour_local = as.integer(Hour_local))
  
  # Calculate activity by hour
  if (metric == "total") {
    hourly_activity <- master_data %>%
      dplyr::count(Hour_local, name = "activity")
  } else {
    # Mean: average calls per hour across all nights
    hourly_activity <- master_data %>%
      dplyr::mutate(Night = as.Date(DateTime_local)) %>%
      dplyr::group_by(Night, Hour_local) %>%
      dplyr::summarise(calls_that_hour = dplyr::n(), .groups = "drop") %>%
      dplyr::group_by(Hour_local) %>%
      dplyr::summarise(activity = mean(calls_that_hour), .groups = "drop")
  }
  
  # Ensure all 24 hours are present (fill with 0 if missing)
  hourly_activity <- hourly_activity %>%
    tidyr::complete(
      Hour_local = 0L:23L,  # Explicit integer sequence
      fill = list(activity = 0)
    )
  
  # Find peak hour
  peak_hour <- hourly_activity %>%
    dplyr::slice_max(activity, n = 1) %>%
    dplyr::pull(Hour_local) %>%
    head(1)
  
  # Build plot
  ggplot(hourly_activity, aes(x = Hour_local, y = activity)) +
    geom_area(fill = "#56B4E9", alpha = 0.4) +
    geom_line(color = "#0072B2", linewidth = 1.2) +
    geom_vline(
      xintercept = peak_hour,
      linetype = "dashed",
      color = "gray40"
    ) +
    annotate(
      "text",
      x = peak_hour,
      y = max(hourly_activity$activity) * 0.95,
      label = sprintf("Peak: %02d:00", peak_hour),
      hjust = ifelse(peak_hour > 12, 1.1, -0.1),
      size = 3.5
    ) +
    scale_x_continuous(breaks = seq(0, 23, by = 2)) +
    labs(
      title = "Hourly Activity Profile",
      subtitle = if (metric == "total") {
        "Total bat calls by hour of night"
      } else {
        "Mean calls per hour per night"
      },
      x = "Hour of Night",
      y = if (metric == "total") "Total Calls" else "Mean Calls per Night"
    ) +
    theme_kpro()
}

#' Distribution of Calls Per Hour
#'
#' @description
#' Creates a histogram showing the distribution of CallsPerHour values
#' across all detectors and nights. Useful for identifying typical activity
#' levels and spotting unusually high-activity periods.
#'
#' @param calls_per_night Data frame. Must contain column:
#'   - CallsPerHour: Numeric. Call rate (calls per recording hour).
#' @param binwidth Numeric or NULL. Histogram bin width. Default is NULL
#'   (auto-determined by ggplot2).
#' @param log_scale Logical. If TRUE, use log10 scale for x-axis.
#'   Useful for right-skewed distributions. Default is FALSE.
#'
#' @return ggplot object showing CallsPerHour histogram.
#'
#' @details
#' CallsPerHour normalizes activity by recording effort, making it more
#' comparable across nights with different recording durations.
#'
#' Vertical lines show mean (orange, dashed) and median (green, dashed)
#' with labels. For right-skewed distributions typical of bat data,
#' the median is often more representative than the mean.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Mean and median shown as reference lines
#' - NA and Inf values removed before plotting
#' - Works with any binwidth
#'
#' @section DOES NOT:
#' - Test for normality
#' - Identify specific outliers
#' - Separate by detector or species
#' - Transform the raw data
#'
#' @examples
#' \dontrun{
#' # Default histogram
#' p <- plot_callsperhour_distribution(calls_per_night_final)
#'
#' # With log scale for skewed data
#' p <- plot_callsperhour_distribution(cpn, log_scale = TRUE)
#' }
#'
#' @export
plot_callsperhour_distribution <- function(calls_per_night,
                                           binwidth = NULL,
                                           log_scale = FALSE) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = "CallsPerHour",
    numeric_cols = "CallsPerHour",
    df_name = "calls_per_night"
  )
  
  # Remove NA and Inf values
  # Origin: 06_exploratory_plots.R, Standards: 04_data_standards.md §2.1 (NA handling)
  plot_data <- calls_per_night %>%
    dplyr::filter(!is.na(CallsPerHour), is.finite(CallsPerHour))
  
  # Handle edge case where all data filtered out (prevents "from must be finite" error)
  if (nrow(plot_data) == 0) {
    warning("No finite CallsPerHour values available for histogram")
    return(
      ggplot() +
        annotate("text", x = 0.5, y = 0.5,
                 label = "No data available\n(all CallsPerHour values are NA or Inf)",
                 size = 5, hjust = 0.5) +
        theme_void() +
        labs(title = "Distribution of Calls Per Hour")
    )
  }
  
  # Calculate summary statistics
  mean_cph <- mean(plot_data$CallsPerHour, na.rm = TRUE)
  median_cph <- median(plot_data$CallsPerHour, na.rm = TRUE)
  
  # Build plot
  p <- ggplot(plot_data, aes(x = CallsPerHour)) +
    geom_histogram(
      binwidth = binwidth,
      fill = "#56B4E9",
      color = "white"
    ) +
    geom_vline(
      xintercept = mean_cph,
      color = "#D55E00",
      linetype = "dashed"
    ) +
    geom_vline(
      xintercept = median_cph,
      color = "#009E73",
      linetype = "dashed"
    ) +
    annotate(
      "text",
      x = mean_cph,
      y = Inf,
      label = sprintf("Mean: %.1f", mean_cph),
      hjust = -0.1,
      vjust = 2,
      size = 3,
      color = "#D55E00"
    ) +
    annotate(
      "text",
      x = median_cph,
      y = Inf,
      label = sprintf("Median: %.1f", median_cph),
      hjust = -0.1,
      vjust = 4,
      size = 3,
      color = "#009E73"
    ) +
    labs(
      title = "Distribution of Calls Per Hour",
      x = "Calls Per Hour",
      y = "Frequency (nights)"
    ) +
    theme_kpro()
  
  # Optionally use log scale
  if (log_scale) {
    p <- p + scale_x_log10()
  }
  
  p
}


# =============================================================================
# SEASONAL PATTERNS
# =============================================================================

#' Weekly Activity Summary
#'
#' @description
#' Aggregates bat activity by week to show seasonal patterns at a coarser
#' temporal resolution. Useful for identifying migration periods, phenological
#' changes, or weather-related activity patterns.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Night: Date. Night of recording.
#'   - CallsPerNight: Numeric. Number of calls per night.
#' @param by_detector Logical. If TRUE, facet by detector. Requires Detector
#'   column. Default is FALSE.
#'
#' @return ggplot object showing weekly activity summary.
#'
#' @details
#' Weeks are defined using ISO week numbering (Monday start). The x-axis
#' shows the start date of each week.
#'
#' This plot smooths out day-to-day variation to reveal longer-term patterns
#' like:
#' - Seasonal increase/decrease in activity
#' - Migration pulses
#' - Weather-related activity bursts
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Weeks defined by ISO week (Monday start)
#' - Shows total calls per week (not mean)
#' - Works with partial weeks at study start/end
#'
#' @section DOES NOT:
#' - Normalize by number of active nights per week
#' - Show confidence intervals
#' - Handle multi-year studies gracefully
#'
#' @examples
#' \dontrun{
#' # Study-wide weekly totals
#' p <- plot_weekly_activity(calls_per_night_final)
#'
#' # Faceted by detector
#' p <- plot_weekly_activity(cpn, by_detector = TRUE)
#' }
#'
#' @export
plot_weekly_activity <- function(calls_per_night, by_detector = FALSE) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Night", "CallsPerNight"),
    date_cols = "Night",
    numeric_cols = "CallsPerNight",
    df_name = "calls_per_night"
  )
  
  if (by_detector && !"Detector" %in% names(calls_per_night)) {
    warning("Detector column not found. Showing study-wide summary.")
    by_detector <- FALSE
  }
  
  # Add week column (ISO week, starts Monday)
  weekly_data <- calls_per_night %>%
    dplyr::mutate(
      Week = lubridate::floor_date(Night, "week"),
      week_num = lubridate::isoweek(Night)
    )
  
  # Aggregate by week (and optionally by detector)
  if (by_detector) {
    weekly_summary <- weekly_data %>%
      dplyr::group_by(Detector, Week) %>%
      dplyr::summarise(
        total_calls = sum(CallsPerNight, na.rm = TRUE),
        n_nights = dplyr::n(),
        mean_calls = mean(CallsPerNight, na.rm = TRUE),
        .groups = "drop"
      )
  } else {
    weekly_summary <- weekly_data %>%
      dplyr::group_by(Week) %>%
      dplyr::summarise(
        total_calls = sum(CallsPerNight, na.rm = TRUE),
        n_nights = dplyr::n(),
        mean_calls = mean(CallsPerNight, na.rm = TRUE),
        .groups = "drop"
      )
  }
  
  # Build plot
  p <- ggplot(weekly_summary, aes(x = Week, y = total_calls)) +
    geom_col(fill = "#009E73") +
    scale_y_continuous(labels = scales::comma) +
    scale_x_date(date_labels = "%b %d", date_breaks = "2 weeks") +
    labs(
      title = "Weekly Bat Activity",
      x = "Week Starting",
      y = "Total Calls"
    ) +
    theme_kpro(rotate_x = TRUE)
  
  # Optionally facet by detector
  if (by_detector) {
    p <- p + facet_wrap(~Detector, scales = "free_y")
  }
  
  p
}


#' Monthly Activity Summary
#'
#' @description
#' Aggregates bat activity by month for studies spanning multiple months.
#' Useful for comparing overall activity levels across different parts
#' of the season.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Night: Date. Night of recording.
#'   - CallsPerNight: Numeric. Number of calls per night.
#' @param by_detector Logical. If TRUE, show stacked bars by detector.
#'   Requires Detector column. Default is FALSE.
#'
#' @return ggplot object showing monthly activity summary.
#'
#' @details
#' For single-month studies, this plot is less informative than weekly
#' summaries. It's most useful for studies spanning 2+ months.
#'
#' When by_detector = TRUE, bars are stacked showing each detector's
#' contribution to the monthly total.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Months shown with "Mon YYYY" labels
#' - Shows total calls per month
#' - Works with partial months at study start/end
#'
#' @section DOES NOT:
#' - Normalize by number of active nights per month
#' - Handle multi-year studies with same-month comparisons
#' - Show error bars or variation
#'
#' @examples
#' \dontrun{
#' # Study-wide monthly totals
#' p <- plot_activity_by_month(calls_per_night_final)
#'
#' # Stacked by detector
#' p <- plot_activity_by_month(cpn, by_detector = TRUE)
#' }
#'
#' @export
plot_activity_by_month <- function(calls_per_night, by_detector = FALSE) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Night", "CallsPerNight"),
    date_cols = "Night",
    numeric_cols = "CallsPerNight",
    df_name = "calls_per_night"
  )
  
  if (by_detector && !"Detector" %in% names(calls_per_night)) {
    warning("Detector column not found. Showing study-wide summary.")
    by_detector <- FALSE
  }
  
  # Add month column
  monthly_data <- calls_per_night %>%
    dplyr::mutate(Month = lubridate::floor_date(Night, "month"))
  
  if (by_detector) {
    monthly_summary <- monthly_data %>%
      dplyr::group_by(Detector, Month) %>%
      dplyr::summarise(
        total_calls = sum(CallsPerNight, na.rm = TRUE),
        .groups = "drop"
      )
    
    n_detectors <- dplyr::n_distinct(monthly_summary$Detector)
    
    p <- ggplot(
      monthly_summary,
      aes(x = Month, y = total_calls, fill = Detector)
    ) +
      geom_col(position = "stack") +
      scale_fill_manual(values = kpro_palette_cat(n_detectors))
    
  } else {
    monthly_summary <- monthly_data %>%
      dplyr::group_by(Month) %>%
      dplyr::summarise(
        total_calls = sum(CallsPerNight, na.rm = TRUE),
        n_nights = dplyr::n(),
        .groups = "drop"
      )
    
    p <- ggplot(monthly_summary, aes(x = Month, y = total_calls)) +
      geom_col(fill = "#0072B2")
  }
  
  # Add common elements
  p +
    scale_y_continuous(labels = scales::comma) +
    scale_x_date(date_labels = "%b %Y", date_breaks = "1 month") +
    labs(
      title = "Monthly Bat Activity",
      x = "Month",
      y = "Total Calls"
    ) +
    theme_kpro(rotate_x = TRUE)
}
