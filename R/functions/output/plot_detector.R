# =============================================================================
# UTILITY: plot_detector.R - Detector Activity Visualizations
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# PURPOSE
# -------
# Provides visualization functions focused on detector-level bat activity
# patterns. These plots help researchers compare activity across monitoring
# sites, identify high/low activity detectors, and assess spatial synchrony
# in bat activity.
#
# All functions return ggplot2 objects that can be further customized,
# combined with other plots, or saved using ggsave().
#
# DEPENDENCIES
# ------------
# External Packages:
#   - ggplot2: All plotting
#   - dplyr: Data manipulation for plot preparation
#   - tidyr: pivot_wider for correlation matrix
#   - scales: Axis formatting (comma, percent)
#   - zoo: Rolling means (plot_detector_rank_over_time only)
#
# Internal Dependencies:
#   - plot_helpers.R: theme_kpro(), validate_plot_input(), kpro_palette_cat(),
#                     format_number()
#
# FUNCTIONS PROVIDED
# ------------------
#
# Single Detector Summaries - Per-detector total activity:
#
#   - plot_total_calls_by_detector():
#       Uses packages: ggplot2 (ggplot, aes, geom_col), dplyr (count, arrange)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Bar chart of cumulative calls per detector (ordered high to low)
#
#   - plot_detector_activity_caterpillar():
#       Uses packages: ggplot2 (ggplot, aes, geom_point, geom_errorbarh),
#                      dplyr (group_by, summarize), stats (mean, sd, qt)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Ordered dot plot with 95% CI whiskers (mean ± CI calls per night)
#
#   - plot_detector_boxplots():
#       Uses packages: ggplot2 (ggplot, aes, geom_boxplot, facet_wrap)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Boxplots of nightly call distribution per detector
#
# Outlier Analysis - Impact of extreme nights:
#
#   - plot_activity_with_without_outliers():
#       Uses packages: ggplot2 (ggplot, aes, geom_col, facet_wrap),
#                      dplyr (filter, mutate, group_by)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Side-by-side bars comparing mean with/without high-activity nights
#
# Cross-Detector Patterns - Comparing activity across sites:
#
#   - plot_synchrony():
#       Uses packages: ggplot2 (ggplot, aes, geom_line, scale_color_manual),
#                      dplyr (select, pivot_longer)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Overlaid time series comparing nightly activity patterns
#
#   - plot_correlation_heatmap():
#       Uses packages: ggplot2 (ggplot, aes, geom_tile, scale_fill_gradient2),
#                      dplyr (select), stats (cor), tidyr (pivot_longer)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       format_number)
#       Purpose: Heatmap of Pearson correlations in activity patterns between detectors
#
#   - plot_detector_rank_over_time():
#       Uses packages: ggplot2 (ggplot, aes, geom_line, facet_wrap),
#                      dplyr (group_by, mutate, rank), zoo (rollmean),
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Rank stability visualization (which detectors rank highest over time)
# USAGE
# -----
# # Source via load_all.R or directly:
# source("R/functions/output/plot_helpers.R")  # Must be first
# source("R/functions/output/plot_detector.R")
#
# # Generate plot
# p <- plot_total_calls_by_detector(kpro_master)
#
# # Save plot
# ggsave("outputs/total_calls_by_detector.png", p, width = 10, height = 6)
#
# Last Modified: 2026-02-09
#
# CHANGELOG
# ---------
# 2026-02-01: Verified deterministic behavior - all functions follow standards
# 2026-02-08: Confirmed usage in run_phase3_analysis_reporting() (Phase 3, Module 6)
# 2024-12-30: Initial creation with CODING_STANDARDS compliance
#
# =============================================================================


# =============================================================================
# SINGLE DETECTOR SUMMARIES
# =============================================================================

#' Total Calls by Detector Bar Chart
#'
#' @description
#' Creates a bar chart showing the total number of bat calls detected at
#' each monitoring site across the entire study period. Bars are ordered
#' from highest to lowest activity for easy comparison.
#'
#' @param master_data Data frame. Must contain at least a `Detector` column.
#'   Each row represents one bat call detection.
#'
#' @return ggplot object showing total calls per detector.
#'
#' @details
#' This is typically one of the first plots generated to understand overall
#' detector performance and site activity levels. High-activity sites may
#' represent better habitat, flyways, or roost proximity.
#'
#' The plot includes:
#' - Bars ordered by total calls (descending)
#' - Value labels above each bar
#' - Comma-formatted y-axis for large numbers
#' - Rotated x-axis labels to fit detector names
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Bars are ordered by descending total calls
#' - Works with any number of detectors
#' - Handles detectors with zero calls (shows bar with 0)
#'
#' @section DOES NOT:
#' - Filter or subset the input data
#' - Normalize by recording effort
#' - Calculate statistical tests
#' - Save the plot to disk
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' p <- plot_total_calls_by_detector(kpro_master)
#' print(p)
#'
#' # Save to file
#' ggsave("outputs/total_calls_by_detector.png", p, width = 10, height = 6)
#'
#' # Customize further
#' p + labs(caption = "Data collected Oct-Nov 2024")
#' }
#'
#' @export
plot_total_calls_by_detector <- function(master_data) {
  
  # Validate input
  validate_plot_input(
    master_data,
    required_cols = "Detector",
    df_name = "master_data"
  )
  
  # Calculate totals and order by descending counts
  totals <- master_data %>%
    dplyr::count(Detector, name = "TotalCalls") %>%
    dplyr::arrange(dplyr::desc(TotalCalls)) %>%
    dplyr::mutate(Detector = factor(Detector, levels = Detector))
  
  # Build plot
  ggplot(totals, aes(x = Detector, y = TotalCalls)) +
    geom_col(fill = "#0072B2") +
    geom_text(
      aes(label = format_number(TotalCalls)),
      vjust = -0.5,
      size = 3
    ) +
    scale_y_continuous(
      labels = scales::comma,
      expand = expansion(mult = c(0, 0.1))
    ) +
    labs(
      title = "Total Bat Calls by Detector",
      x = "Detector",
      y = "Total Calls"
    ) +
    theme_kpro(rotate_x = TRUE)
}


#' Caterpillar Plot of Detector Activity
#'
#' @description
#' Creates a caterpillar plot (forest plot style) showing mean nightly bat
#' activity per detector with approximate 95% confidence intervals. Detectors
#' are ordered from least to most active, making it easy to identify
#' relative site quality.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - CallsPerNight: Numeric. Number of calls per night.
#'
#' @return ggplot object showing caterpillar plot with mean ± 95% CI.
#'
#' @details
#' Confidence intervals are calculated as mean ± 1.96 × SE, where
#' SE = SD / sqrt(n). These are descriptive intervals intended for
#' visual comparison, NOT formal statistical inference.
#'
#' A vertical dashed line shows the overall mean across all detectors,
#' helping identify which sites are above or below average.
#'
#' This plot is useful for:
#' - Identifying high/low activity sites
#' - Comparing variability across sites
#' - Visualizing uncertainty in mean estimates
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Detectors ordered by ascending mean activity
#' - CI calculated as mean ± 1.96 × SE
#' - Works with any number of detectors (≥1)
#' - NA values in CallsPerNight are excluded from calculations
#'
#' @section DOES NOT:
#' - Perform formal statistical tests
#' - Account for non-normal distributions
#' - Weight by recording effort
#' - Handle detectors with only 1 night (SE undefined, shown without CI)
#'
#' @examples
#' \dontrun{
#' p <- plot_detector_activity_caterpillar(calls_per_night_final)
#' print(p)
#'
#' # Compare with boxplots
#' p1 <- plot_detector_activity_caterpillar(cpn)
#' p2 <- plot_detector_boxplots(cpn)
#' }
#'
#' @export
plot_detector_activity_caterpillar <- function(calls_per_night) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "CallsPerNight"),
    numeric_cols = "CallsPerNight",
    df_name = "calls_per_night"
  )
  
  # Calculate summary statistics per detector
  summary_df <- calls_per_night %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      mean_calls = mean(CallsPerNight, na.rm = TRUE),
      sd_calls   = sd(CallsPerNight, na.rm = TRUE),
      n          = sum(!is.na(CallsPerNight)),
      se         = ifelse(n > 1, sd_calls / sqrt(n), NA_real_),
      lower      = mean_calls - 1.96 * se,
      upper      = mean_calls + 1.96 * se,
      .groups    = "drop"
    ) %>%
    dplyr::arrange(mean_calls) %>%
    dplyr::mutate(Detector = factor(Detector, levels = Detector))
  
  # Calculate overall mean for reference line
  overall_mean <- mean(summary_df$mean_calls, na.rm = TRUE)
  
  # Build plot
  ggplot(summary_df, aes(x = mean_calls, y = Detector)) +
    geom_point(size = 3, color = "#0072B2") +
    geom_errorbarh(
      aes(xmin = lower, xmax = upper),
      height = 0.2,
      color = "#0072B2"
    ) +
    geom_vline(
      xintercept = overall_mean,
      linetype = "dashed",
      color = "gray50"
    ) +
    scale_x_continuous(labels = scales::comma) +
    labs(
      title = "Relative Detector Activity",
      subtitle = "Mean calls per night ± 95% CI (descriptive)",
      x = "Mean Calls Per Night",
      y = "Detector"
    ) +
    theme_kpro()
}


#' Box Plots of Calls Per Night by Detector
#'
#' @description
#' Creates box plots showing the distribution of nightly bat activity for
#' each detector. Useful for visualizing variability, skewness, and outliers
#' across monitoring sites.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - CallsPerNight: Numeric. Number of calls per night.
#'
#' @return ggplot object showing boxplots ordered by median activity.
#'
#' @details
#' Detectors are ordered by median nightly activity (highest to lowest),
#' which may differ from the ordering by mean in the caterpillar plot
#' if distributions are skewed.
#'
#' Boxplot elements:
#' - Box: Interquartile range (IQR, 25th to 75th percentile)
#' - Line in box: Median (50th percentile)
#' - Whiskers: Extend to min/max within 1.5 × IQR
#' - Points beyond whiskers: Potential outliers
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Detectors ordered by descending median activity
#' - Standard ggplot2 boxplot outlier detection (1.5 × IQR)
#' - Works with any number of detectors
#'
#' @section DOES NOT:
#' - Remove or flag outliers
#' - Calculate statistical tests
#' - Normalize by recording effort
#' - Show individual data points (use geom_jitter to add)
#'
#' @examples
#' \dontrun{
#' p <- plot_detector_boxplots(calls_per_night_final)
#' print(p)
#'
#' # Add jittered points
#' p + geom_jitter(width = 0.2, alpha = 0.3)
#' }
#'
#' @export
plot_detector_boxplots <- function(calls_per_night) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "CallsPerNight"),
    numeric_cols = "CallsPerNight",
    df_name = "calls_per_night"
  )
  
  # Order detectors by median activity (descending)
  detector_order <- calls_per_night %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(med = median(CallsPerNight, na.rm = TRUE), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(med)) %>%
    dplyr::pull(Detector)
  
  calls_per_night <- calls_per_night %>%
    dplyr::mutate(Detector = factor(Detector, levels = detector_order))
  
  # Build plot
  ggplot(calls_per_night, aes(x = Detector, y = CallsPerNight)) +
    geom_boxplot(fill = "#56B4E9", outlier.alpha = 0.5) +
    scale_y_continuous(labels = scales::comma) +
    labs(
      title = "Distribution of Nightly Activity by Detector",
      subtitle = "Ordered by median calls per night",
      x = "Detector",
      y = "Calls Per Night"
    ) +
    theme_kpro(rotate_x = TRUE)
}


# =============================================================================
# OUTLIER ANALYSIS
# =============================================================================

#' Compare Activity With and Without Outliers
#'
#' @description
#' Creates side-by-side boxplots comparing CallsPerNight distributions
#' with all data versus with outliers removed. Outliers are defined as
#' values above the 95th percentile within each detector.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - CallsPerNight: Numeric. Number of calls per night.
#'
#' @return ggplot object showing paired boxplots (all data vs. filtered).
#'
#' @details
#' This plot helps assess whether summary statistics are unduly influenced
#' by a few high-activity nights. Each detector has its own 95th percentile
#' threshold, so outlier detection is relative to each site's typical range.
#'
#' The subtitle reports the total number of outlier nights removed, helping
#' contextualize how much data is affected.
#'
#' Use case: If boxplots look substantially different after outlier removal,
#' consider reporting both "all data" and "typical nights" summaries.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Outliers defined as > 95th percentile per detector
#' - Both datasets shown side-by-side for each detector
#' - Reports count of removed outliers in subtitle
#'
#' @section DOES NOT:
#' - Actually remove outliers from the original data
#' - Use a global threshold (each detector has its own)
#' - Modify the input data frame
#' - Test whether outliers are "real" or errors
#'
#' @examples
#' \dontrun{
#' p <- plot_activity_with_without_outliers(calls_per_night_final)
#' print(p)
#' }
#'
#' @export
plot_activity_with_without_outliers <- function(calls_per_night) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "CallsPerNight"),
    numeric_cols = "CallsPerNight",
    df_name = "calls_per_night"
  )
  
  # Flag outliers within each detector (> 95th percentile)
  calls_flagged <- calls_per_night %>%
    dplyr::group_by(Detector) %>%
    dplyr::mutate(
      outlier_threshold = quantile(CallsPerNight, 0.95, na.rm = TRUE),
      is_outlier = CallsPerNight > outlier_threshold
    ) %>%
    dplyr::ungroup()
  
  n_outliers <- sum(calls_flagged$is_outlier, na.rm = TRUE)
  
  # Create combined dataset with both versions
  calls_combined <- dplyr::bind_rows(
    calls_flagged %>% dplyr::mutate(DataType = "All Data"),
    calls_flagged %>%
      dplyr::filter(!is_outlier) %>%
      dplyr::mutate(DataType = "Without Outliers (>95th %ile)")
  ) %>%
    dplyr::mutate(
      DataType = factor(
        DataType,
        levels = c("All Data", "Without Outliers (>95th %ile)")
      )
    )
  
  # Build plot
  ggplot(calls_combined, aes(x = Detector, y = CallsPerNight, fill = DataType)) +
    geom_boxplot(position = position_dodge(width = 0.8), outlier.alpha = 0.3) +
    scale_fill_manual(values = c("#0072B2", "#56B4E9")) +
    scale_y_continuous(labels = scales::comma) +
    labs(
      title = "Effect of Outlier Removal on Activity Distributions",
      subtitle = sprintf(
        "%s outlier nights removed (>95th percentile per detector)",
        format_number(n_outliers)
      ),
      x = "Detector",
      y = "Calls Per Night",
      fill = NULL
    ) +
    theme_kpro(rotate_x = TRUE) +
    theme(legend.position = "top")
}


# =============================================================================
# CROSS-DETECTOR PATTERNS
# =============================================================================

#' Synchrony Plot of Detector Activity
#'
#' @description
#' Overlays CallsPerNight time series for all detectors to visualize
#' shared temporal patterns. High overlap in activity patterns suggests
#' environmental drivers (weather, moon phase, insect emergence) are
#' more important than site-specific factors.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Night: Date. Night of recording.
#'   - CallsPerNight: Numeric. Number of calls per night.
#'
#' @return ggplot object showing overlaid time series with transparency.
#'
#' @details
#' Lines are semi-transparent (alpha = 0.4) so overlapping patterns are
#' visible. When multiple detectors peak on the same nights, the plot
#' appears darker in those regions.
#'
#' Interpretation:
#' - Parallel lines: Strong synchrony (environmental drivers dominate)
#' - Independent lines: Weak synchrony (site factors dominate)
#' - Mix: Both factors contribute
#'
#' For formal synchrony analysis, see plot_correlation_heatmap().
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - All detectors shown on same axes
#' - Uses transparency for overplotting
#' - Works with any number of detectors
#'
#' @section DOES NOT:
#' - Calculate synchrony metrics
#' - Statistically test for correlation
#' - Color-code individual detectors (use plot_activity_over_time for that)
#'
#' @examples
#' \dontrun{
#' p <- plot_synchrony(calls_per_night_final)
#' print(p)
#' }
#'
#' @export
plot_synchrony <- function(calls_per_night) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Night", "CallsPerNight"),
    date_cols = "Night",
    numeric_cols = "CallsPerNight",
    df_name = "calls_per_night"
  )
  
  # Build plot with overlaid transparent lines
  ggplot(calls_per_night, aes(x = Night, y = CallsPerNight, group = Detector)) +
    geom_line(alpha = 0.4, color = "#0072B2") +
    scale_y_continuous(labels = scales::comma) +
    labs(
      title = "Synchrony of Bat Activity Across Detectors",
      subtitle = "Overlapping patterns suggest shared environmental drivers",
      x = "Night",
      y = "Calls Per Night"
    ) +
    theme_kpro()
}


#' Pairwise Correlation Heatmap of Detector Activity
#'
#' @description
#' Creates a heatmap showing Pearson correlations of nightly bat activity
#' between all pairs of detectors. High correlations indicate sites with
#' similar temporal activity patterns.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Night: Date. Night of recording.
#'   - CallsPerNight: Numeric. Number of calls per night.
#'
#' @return ggplot object showing correlation matrix heatmap.
#'
#' @details
#' Correlations are calculated using Pearson's r with pairwise complete
#' observations (nights where both detectors have data).
#'
#' Color scale:
#' - Red (r = -1): Perfect negative correlation (rare in bat data)
#' - White (r = 0): No correlation
#' - Blue (r = 1): Perfect positive correlation
#'
#' Correlation values are printed in each cell. Text color adapts
#' (white for |r| > 0.5, black otherwise) for readability.
#'
#' Interpretation:
#' - High correlations (r > 0.7): Sites respond similarly to conditions
#' - Moderate (0.3 < r < 0.7): Some shared patterns
#' - Low (r < 0.3): Independent activity patterns
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Uses Pearson correlation with pairwise complete observations
#' - Displays correlation values in cells
#' - Symmetric matrix (same value above/below diagonal)
#'
#' @section DOES NOT:
#' - Test for statistical significance
#' - Handle non-linear relationships
#' - Account for autocorrelation
#' - Remove the diagonal (r = 1)
#'
#' @examples
#' \dontrun{
#' p <- plot_correlation_heatmap(calls_per_night_final)
#' print(p)
#' }
#'
#' @export
plot_correlation_heatmap <- function(calls_per_night) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Night", "CallsPerNight"),
    date_cols = "Night",
    numeric_cols = "CallsPerNight",
    df_name = "calls_per_night"
  )
  
  # Reshape to wide format (Detectors as columns, Nights as rows)
  wide <- calls_per_night %>%
    dplyr::select(Detector, Night, CallsPerNight) %>%
    tidyr::pivot_wider(names_from = Detector, values_from = CallsPerNight)
  
  # Origin: 06_exploratory_plots.R, Standards: 04_data_standards.md §2.1 (NA handling)
  # Check for detectors with zero variance (SD = 0) to avoid correlation warnings
  detector_data <- wide %>% dplyr::select(-Night)
  detector_sds <- sapply(detector_data, function(x) sd(x, na.rm = TRUE))
  
  zero_sd_detectors <- names(detector_sds[is.na(detector_sds) | detector_sds == 0])
  if (length(zero_sd_detectors) > 0) {
    warning(sprintf(
      "Detector(s) with zero variance excluded from correlation: %s",
      paste(zero_sd_detectors, collapse = ", ")
    ))
    # Remove constant-value detectors from correlation calculation
    detector_data <- detector_data %>% 
      dplyr::select(-dplyr::any_of(zero_sd_detectors))
  }
  
  # Return empty plot if not enough detectors after filtering
  if (ncol(detector_data) < 2) {
    warning("Not enough detectors with variance for correlation matrix")
    return(
      ggplot() +
        annotate("text", x = 0.5, y = 0.5, 
                 label = "Insufficient data\nfor correlation matrix",
                 size = 6, hjust = 0.5) +
        theme_void() +
        labs(title = "Correlation of Nightly Activity Between Detectors")
    )
  }
  
  # Compute Pearson correlation matrix with suppressWarnings for any remaining edge cases
  cor_matrix <- suppressWarnings(cor(
    detector_data,
    use = "pairwise.complete.obs",
    method = "pearson"
  ))
  
  # Convert to long format for ggplot
  cor_df <- as.data.frame(as.table(cor_matrix))
  names(cor_df) <- c("Detector1", "Detector2", "Correlation")
  
  # Build heatmap
  ggplot(cor_df, aes(x = Detector1, y = Detector2, fill = Correlation)) +
    geom_tile(color = "white") +
    geom_text(
      aes(label = sprintf("%.2f", Correlation)),
      size = 3,
      color = ifelse(abs(cor_df$Correlation) > 0.5, "white", "black")
    ) +
    scale_fill_gradient2(
      low = "#D55E00",
      mid = "white",
      high = "#0072B2",
      midpoint = 0,
      limits = c(-1, 1),
      name = "Pearson r"
    ) +
    labs(
      title = "Correlation of Nightly Activity Between Detectors",
      x = NULL,
      y = NULL
    ) +
    theme_kpro(rotate_x = TRUE) +
    theme(panel.grid = element_blank())
}


#' Detector Activity Rank Over Time
#'
#' @description
#' Shows how detector rankings by activity change across the study period.
#' Stable, non-crossing lines suggest consistent site differences. Frequent
#' crossings suggest temporal variation overrides spatial patterns.
#'
#' @param calls_per_night Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - Night: Date. Night of recording.
#'   - CallsPerNight: Numeric. Number of calls per night.
#' @param window Integer. Rolling window size in days for smoothing.
#'   Default is 7.
#'
#' @return ggplot object showing rank trajectories over time.
#'
#' @details
#' This plot uses a rolling mean to smooth nightly variation before
#' ranking. The window parameter controls how much smoothing is applied:
#' - Smaller window (3-5): More responsive to short-term changes
#' - Larger window (7-14): Smoother, emphasizes longer trends
#'
#' Ranks are displayed with 1 = most active (top). The y-axis is reversed
#' so higher-ranked detectors appear at the top of the plot.
#'
#' Requires the zoo package for rollmean().
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Rank 1 = most active detector on each date
#' - Uses rolling mean with specified window
#' - Dates without enough history for rolling mean are excluded
#'
#' @section DOES NOT:
#' - Handle ties in ranking (uses average rank)
#' - Work without the zoo package
#' - Show raw (unsmoothed) rankings
#'
#' @examples
#' \dontrun{
#' # Default 7-day smoothing
#' p <- plot_detector_rank_over_time(calls_per_night_final)
#'
#' # Less smoothing (3-day window)
#' p <- plot_detector_rank_over_time(calls_per_night_final, window = 3)
#' }
#'
#' @export
plot_detector_rank_over_time <- function(calls_per_night, window = 7) {
  
  # Validate input
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Night", "CallsPerNight"),
    date_cols = "Night",
    numeric_cols = "CallsPerNight",
    df_name = "calls_per_night"
  )
  
  # Calculate rolling mean activity per detector
  ranked <- calls_per_night %>%
    dplyr::arrange(Detector, Night) %>%
    dplyr::group_by(Detector) %>%
    dplyr::mutate(
      rolling_calls = zoo::rollmean(
        CallsPerNight,
        k = window,
        fill = NA,
        align = "right"
      )
    ) %>%
    dplyr::ungroup() %>%
    dplyr::filter(!is.na(rolling_calls))
  
  # Rank detectors within each night (1 = highest activity)
  ranked <- ranked %>%
    dplyr::group_by(Night) %>%
    dplyr::mutate(rank = rank(-rolling_calls, ties.method = "average")) %>%
    dplyr::ungroup()
  
  n_detectors <- dplyr::n_distinct(ranked$Detector)
  
  # Build plot with reversed y-axis (rank 1 at top)
  ggplot(ranked, aes(x = Night, y = rank, color = Detector, group = Detector)) +
    geom_line(linewidth = 1, alpha = 0.8) +
    scale_y_reverse(breaks = 1:n_detectors) +
    scale_color_manual(values = kpro_palette_cat(n_detectors)) +
    labs(
      title = "Detector Activity Rankings Over Time",
      subtitle = sprintf("%d-day rolling average", window),
      x = "Night",
      y = "Rank (1 = most active)"
    ) +
    theme_kpro()
}