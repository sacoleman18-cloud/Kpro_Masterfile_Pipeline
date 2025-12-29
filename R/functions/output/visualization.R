# =============================================================================
# output/visualization.R — EXPLORATORY VISUALIZATIONS (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Generates exploratory visualizations for data inspection and reporting.
# All plots are descriptive — no statistical annotations.
#
# VISUALIZATION CONTRACT
# ----------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Return ggplot objects
#    - All plot functions return ggplot2 objects
#    - Can be further customized by user
#    - Can be saved via ggsave()
#
# 2. Consistent styling
#    - Colorblind-accessible palettes by default
#    - Consistent theme across all plots
#    - Clear axis labels and titles
#
# 3. Plot categories
#    - Data completeness: effort heatmaps
#    - Activity patterns: time series, distributions
#    - Cross-detector: correlations, synchrony
#
# 4. High-resolution export
#    - Default sizing suitable for publication
#    - PNG export at 300 DPI minimum
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Perform statistical tests or add p-values
#   - Calculate summary statistics (analysis/summarization.R)
#   - Transform or validate data (standardization/, validation/)
#
# DEPENDENCIES
# ------------
#   - ggplot2: all plotting
#   - viridis or RColorBrewer: colorblind-safe palettes
#   - dplyr: data manipulation for plotting
#
# CONTENTS
# --------
#   Data Completeness:
#     - plot_recording_effort_heatmap()
#
#   Activity Patterns:
#     - plot_total_calls_by_detector()
#     - plot_activity_over_time()
#     - plot_hourly_activity_profile()
#     - plot_callsperhour_distribution()
#     - plot_activity_with_without_outliers()
#     - plot_detector_boxplots()
#
#   Cross-Detector:
#     - plot_correlation_heatmap()
#     - plot_synchrony()
#     - plot_detector_activity_caterpillar()
#
# =============================================================================


#--------------------------------------------------
# Total Calls by Detector
#--------------------------------------------------
#' Total Calls by Detector
#'
#' Displays cumulative bat activity per detector across the study.
#'
#' @param master_data Data frame containing at least the `Detector` column
#'   and one row per bat call.
#' @return ggplot object showing total calls per detector
#' @examples
#' \dontrun{
#' plot_total_calls_by_detector(master_data)
#' }
#' @export
plot_total_calls_by_detector <- function(master_data) {
  
  # -------------------------------
  # Input validation
  # -------------------------------
  if (!is.data.frame(master_data)) {
    stop("master_data must be a data frame")
  }
  
  if (!"Detector" %in% names(master_data)) {
    stop("master_data must contain column 'Detector'")
  }
  
  # -------------------------------
  # Compute totals
  # -------------------------------
  totals <- master_data %>%
    count(Detector, name = "TotalCalls")
  
  # -------------------------------
  # Plot
  # -------------------------------
  ggplot(totals, aes(x = Detector, y = TotalCalls)) +
    geom_col(fill = "steelblue") +
    labs(
      title = "Total Bat Calls by Detector",
      x = "Detector",
      y = "Total Calls"
    ) +
    theme_minimal()
}

#--------------------------------------------------
# Caterpillar Plot of Detector Activity
#--------------------------------------------------
#' Caterpillar Plot of Detector Activity
#'
#' Displays mean nightly bat activity per detector with approximate
#' 95% confidence intervals, ordered from least to most active.
#'
#' Confidence intervals are descriptive (mean ± 1.96 × SE) and intended
#' for visual comparison rather than formal inference.
#'
#' @param calls_per_night Data frame containing columns:
#'   - Detector: unique identifier for each detector
#'   - CallsPerNight: numeric call counts per night
#' @return ggplot object showing a caterpillar plot of detector activity
#' @examples
#' \dontrun{
#' plot_detector_activity_caterpillar(calls_per_night)
#' }
#' @export
plot_detector_activity_caterpillar <- function(calls_per_night) {
  
  # -------------------------------
  # Input validation
  # -------------------------------
  if (!is.data.frame(calls_per_night)) {
    stop("calls_per_night must be a data frame")
  }
  
  required_cols <- c("Detector", "CallsPerNight")
  missing_cols <- setdiff(required_cols, names(calls_per_night))
  
  if (length(missing_cols) > 0) {
    stop(
      "calls_per_night is missing required columns: ",
      paste(missing_cols, collapse = ", ")
    )
  }
  
  if (!is.numeric(calls_per_night$CallsPerNight)) {
    stop("calls_per_night$CallsPerNight must be numeric")
  }
  
  # -------------------------------
  # Summarise detector activity
  # -------------------------------
  summary_df <- calls_per_night %>%
    group_by(Detector) %>%
    summarise(
      mean_calls = mean(CallsPerNight, na.rm = TRUE),
      sd_calls   = sd(CallsPerNight, na.rm = TRUE),
      n          = sum(!is.na(CallsPerNight)),
      se         = ifelse(n > 0, sd_calls / sqrt(n), NA_real_),
      lower      = mean_calls - 1.96 * se,
      upper      = mean_calls + 1.96 * se,
      .groups    = "drop"
    ) %>%
    arrange(mean_calls) %>%
    mutate(Detector = factor(Detector, levels = Detector))
  
  # -------------------------------
  # Plot caterpillar chart
  # -------------------------------
  ggplot(summary_df, aes(x = mean_calls, y = Detector)) +
    geom_point() +
    geom_errorbarh(aes(xmin = lower, xmax = upper), height = 0.2) +
    labs(
      title = "Relative Detector Activity",
      subtitle = "Mean Calls Per Night with 95% CI (Descriptive)",
      x = "Mean Calls Per Night",
      y = "Detector"
    ) +
    theme_minimal()
}

#--------------------------------------------------
# Box Plots of Calls Per Night by Detector
#--------------------------------------------------
#' Box Plots of Calls Per Night by Detector
#'
#' Visualizes variability and outliers in CallsPerNight for each detector.
#'
#' @param calls_per_night Data frame containing:
#'   - Detector: detector identifier
#'   - Night: recording night (Date class)
#'   - CallsPerNight: numeric call counts
#' @return ggplot object showing CallsPerNight distributions by detector
#' @examples
#' \dontrun{
#' plot_detector_boxplots(calls_per_night)
#' }
#' @export
plot_detector_boxplots <- function(calls_per_night) {
  
  # -------------------------------
  # Input validation
  # -------------------------------
  if (!is.data.frame(calls_per_night)) {
    stop("calls_per_night must be a data frame")
  }
  
  required_cols <- c("Detector", "CallsPerNight")
  missing_cols <- setdiff(required_cols, names(calls_per_night))
  if (length(missing_cols) > 0) {
    stop(
      "calls_per_night is missing required columns: ",
      paste(missing_cols, collapse = ", ")
    )
  }
  
  if (!is.numeric(calls_per_night$CallsPerNight)) {
    stop("calls_per_night$CallsPerNight must be numeric")
  }
  
  # -------------------------------
  # Plot boxplots
  # -------------------------------
  ggplot(calls_per_night, aes(x = Detector, y = CallsPerNight)) +
    geom_boxplot(fill = "lightgreen") +
    labs(
      title = "Boxplots of Calls Per Night by Detector",
      x = "Detector",
      y = "Calls Per Night"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1)
    )
}

#--------------------------------------------------
# Compare Activity With and Without Outliers
#--------------------------------------------------
#' Compare Activity With and Without Outliers
#'
#' Compares CallsPerNight distributions with all data versus
#' outliers removed. Outliers are defined as values above the
#' 95th percentile within each detector.
#'
#' @param calls_per_night Data frame with Detector and CallsPerNight
#' @return ggplot object (side-by-side boxplots)
#' @examples
#' \dontrun{
#' plot_activity_with_without_outliers(calls_per_night)
#' }
#' @export
plot_activity_with_without_outliers <- function(calls_per_night) {
  
  # -------------------------------
  # Input validation
  # -------------------------------
  if (!is.data.frame(calls_per_night)) {
    stop("calls_per_night must be a data frame")
  }
  
  required_cols <- c("Detector", "CallsPerNight")
  missing <- setdiff(required_cols, names(calls_per_night))
  if (length(missing) > 0) {
    stop(
      "calls_per_night is missing required columns: ",
      paste(missing, collapse = ", ")
    )
  }
  
  # -------------------------------
  # Identify outliers per detector
  # -------------------------------
  calls_flagged <- calls_per_night %>%
    group_by(Detector) %>%
    mutate(
      outlier_threshold = quantile(CallsPerNight, 0.95, na.rm = TRUE),
      is_outlier = CallsPerNight > outlier_threshold
    ) %>%
    ungroup()
  
  # -------------------------------
  # Combine datasets
  # -------------------------------
  calls_combined <- bind_rows(
    calls_flagged %>%
      mutate(DataType = "All Data"),
    
    calls_flagged %>%
      filter(!is_outlier) %>%
      mutate(DataType = "Without Outliers")
  )
  
  # -------------------------------
  # Plot
  # -------------------------------
  ggplot(
    calls_combined,
    aes(x = Detector, y = CallsPerNight, fill = DataType)
  ) +
    geom_boxplot(position = position_dodge(width = 0.8)) +
    labs(
      title = "Comparison of Calls Per Night With vs. Without Outliers",
      x = "Detector",
      y = "Calls Per Night",
      fill = "Data Type"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1)
    )
}

#--------------------------------------------------
# Bat Activity Over Time by Detector
#--------------------------------------------------
#' Bat Activity Over Time by Detector
#'
#' Shows nightly bat activity trends for each detector.
#'
#' @param calls_per_night Data frame containing columns:
#'   - Detector: unique identifier for each detector
#'   - Night: date of recording (Date class)
#'   - CallsPerNight: numeric number of calls detected each night
#' @return ggplot object showing nightly bat activity trends
#' @examples
#' \dontrun{
#' plot_activity_over_time(calls_per_night)
#' }
#' @export
plot_activity_over_time <- function(calls_per_night) {
  
  # -------------------------------
  # Input validation
  # -------------------------------
  required_cols <- c("Detector", "Night", "CallsPerNight")
  
  if (!is.data.frame(calls_per_night)) {
    stop("calls_per_night must be a data frame")
  }
  
  missing_cols <- setdiff(required_cols, names(calls_per_night))
  if (length(missing_cols) > 0) {
    stop("calls_per_night is missing required columns: ", paste(missing_cols, collapse = ", "))
  }
  
  if (!inherits(calls_per_night$Night, "Date")) {
    stop("calls_per_night$Night must be of Date class")
  }
  
  if (!is.numeric(calls_per_night$CallsPerNight)) {
    stop("calls_per_night$CallsPerNight must be numeric")
  }
  
  # -------------------------------
  # Plot
  # -------------------------------
  ggplot(calls_per_night, aes(x = Night, y = CallsPerNight, color = Detector)) +
    geom_line(alpha = 0.7) +
    labs(
      title = "Bat Activity Over Time",
      x = "Night",
      y = "Calls Per Night"
    ) +
    theme_minimal()
}

#--------------------------------------------------
# Heatmap of Recording Effort by Detector and Night
#--------------------------------------------------
#' Heatmap of Recording Effort by Detector and Night
#'
#' Visualizes recording effort across detectors and nights to identify
#' deployment gaps and partial nights.
#'
#' @param calls_per_night Data frame containing columns:
#'   - Detector: unique identifier for each detector
#'   - Night: date of recording (Date class)
#'   - RecordingHours: numeric recording duration for each night
#' @return ggplot object showing a heatmap of recording hours.
#' @examples
#' \dontrun{
#' plot_recording_effort_heatmap(calls_per_night)
#' }
#' @export
plot_recording_effort_heatmap <- function(calls_per_night) {
  
  # -------------------------------
  # Input validation
  # -------------------------------
  required_cols <- c("Detector", "Night", "RecordingHours")
  
  if (!is.data.frame(calls_per_night)) {
    stop("calls_per_night must be a data frame")
  }
  
  missing_cols <- setdiff(required_cols, names(calls_per_night))
  if (length(missing_cols) > 0) {
    stop("calls_per_night is missing required columns: ", paste(missing_cols, collapse = ", "))
  }
  
  if (!inherits(calls_per_night$Night, "Date")) {
    stop("calls_per_night$Night must be of Date class")
  }
  
  if (!is.numeric(calls_per_night$RecordingHours)) {
    stop("calls_per_night$RecordingHours must be numeric")
  }
  
  # -------------------------------
  # Generate heatmap
  # -------------------------------
  ggplot(calls_per_night, aes(x = Night, y = Detector, fill = RecordingHours)) +
    geom_tile(color = "white") +
    scale_fill_viridis_c(option = "C", na.value = "grey80", name = "Recording Hours") +
    labs(title = "Recording Effort Heatmap", x = "Night", y = "Detector") +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      axis.text.y = element_text(size = 10),
      plot.title = element_text(face = "bold", size = 14)
    )
}

#--------------------------------------------------
# Hourly Activity Profile Across the Night
#--------------------------------------------------
#' Plot Hourly Bat Activity Profile
#'
#' Displays average bat activity by hour of night.
#'
#' @param master_data Master dataset with a `DateTime` column.
#' @return ggplot object showing mean calls per hour.
#' @examples
#' \dontrun{
#' plot_hourly_activity_profile(master_data)
#' }
#' @export
plot_hourly_activity_profile <- function(master_data) {
  
  # -------------------------------
  # Input validation
  # -------------------------------
  if (!is.data.frame(master_data)) stop("master_data must be a data frame")
  if (!"DateTime" %in% names(master_data)) stop("master_data must contain 'DateTime' column")
  
  # -------------------------------
  # Calculate mean calls per hour
  # -------------------------------
  hourly <- master_data %>%
    mutate(Hour = lubridate::hour(DateTime)) %>%
    group_by(Hour) %>%
    summarise(mean_calls = n(), .groups = "drop")
  
  # -------------------------------
  # Create plot
  # -------------------------------
  p <- ggplot(hourly, aes(x = Hour, y = mean_calls)) +
    geom_line(color = "#2c3e50", size = 1) +
    geom_point(color = "#e74c3c", size = 2) +
    scale_x_continuous(breaks = 0:23) +
    labs(
      title = "Average Bat Activity by Hour",
      x = "Hour of Night",
      y = "Mean Calls"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 0, hjust = 0.5),
      plot.title = element_text(hjust = 0.5, face = "bold")
    )
  
  # -------------------------------
  # Return plot
  # -------------------------------
  return(p)
}

#--------------------------------------------------
# Histogram of Calls Per Hour Distribution
#--------------------------------------------------
#' Histogram of Calls Per Hour Distribution
#'
#' Visualizes the distribution of CallsPerHour across all detectors and nights.
#' Useful for spotting outliers or unusually high-activity periods.
#'
#' @param calls_per_hour Data frame containing:
#'   - Detector: detector identifier
#'   - Night: recording night (Date class)
#'   - CallsPerHour: numeric call rate
#' @return ggplot object showing CallsPerHour distribution
#' @examples
#' \dontrun{
#' plot_callsperhour_distribution(calls_per_hour)
#' }
#' @export
plot_callsperhour_distribution <- function(calls_per_hour) {
  
  # -------------------------------
  # Input validation
  # -------------------------------
  if (!is.data.frame(calls_per_hour)) {
    stop("calls_per_hour must be a data frame")
  }
  
  required_cols <- c("Detector", "Night", "CallsPerHour")
  missing_cols <- setdiff(required_cols, names(calls_per_hour))
  if (length(missing_cols) > 0) {
    stop(
      "calls_per_hour is missing required columns: ",
      paste(missing_cols, collapse = ", ")
    )
  }
  
  if (!inherits(calls_per_hour$Night, "Date")) {
    stop("calls_per_hour$Night must be of Date class")
  }
  
  if (!is.numeric(calls_per_hour$CallsPerHour)) {
    stop("calls_per_hour$CallsPerHour must be numeric")
  }
  
  # -------------------------------
  # Plot histogram
  # -------------------------------
  ggplot(calls_per_hour, aes(x = CallsPerHour)) +
    geom_histogram(
      binwidth = 1,
      fill = "steelblue",
      color = "white"
    ) +
    labs(
      title = "Distribution of Calls Per Hour",
      x = "Calls Per Hour",
      y = "Frequency"
    ) +
    theme_minimal()
}

#--------------------------------------------------
# Synchrony Plot of Detector Activity
#--------------------------------------------------
#' Synchrony Plot of Detector Activity
#'
#' Overlays CallsPerNight time series for all detectors to visualize
#' shared temporal patterns in bat activity across the study period.
#'
#' @param calls_per_night Data frame containing columns:
#'   - Detector: unique identifier for each detector
#'   - Night: date of recording (Date class)
#'   - CallsPerNight: numeric call counts per night
#' @return ggplot object showing overlaid nightly activity trends
#' @examples
#' \dontrun{
#' plot_synchrony(calls_per_night)
#' }
#' @export
plot_synchrony <- function(calls_per_night) {
  
  # -------------------------------
  # Input validation
  # -------------------------------
  required_cols <- c("Detector", "Night", "CallsPerNight")
  
  if (!is.data.frame(calls_per_night)) {
    stop("calls_per_night must be a data frame")
  }
  
  missing_cols <- setdiff(required_cols, names(calls_per_night))
  if (length(missing_cols) > 0) {
    stop(
      "calls_per_night is missing required columns: ",
      paste(missing_cols, collapse = ", ")
    )
  }
  
  if (!inherits(calls_per_night$Night, "Date")) {
    stop("calls_per_night$Night must be of Date class")
  }
  
  if (!is.numeric(calls_per_night$CallsPerNight)) {
    stop("calls_per_night$CallsPerNight must be numeric")
  }
  
  # -------------------------------
  # Plot synchrony
  # -------------------------------
  ggplot(
    calls_per_night,
    aes(x = Night, y = CallsPerNight, group = Detector)
  ) +
    geom_line(alpha = 0.3) +
    labs(
      title = "Synchrony of Bat Activity Across Detectors",
      subtitle = "Transparent lines indicate shared temporal patterns",
      x = "Night",
      y = "Calls Per Night"
    ) +
    theme_minimal()
}

#--------------------------------------------------
# Pairwise Correlation Heatmap of Detector Activity
#--------------------------------------------------
#' Pairwise Correlation Heatmap of Detector Activity
#'
#' Visualizes Pearson correlations of nightly bat activity
#' (CallsPerNight) between all detector pairs to assess
#' similarity in temporal activity patterns.
#'
#' @param calls_per_night Data frame containing columns:
#'   - Detector: unique identifier for each detector
#'   - Night: date of recording (Date class)
#'   - CallsPerNight: numeric call counts per night
#' @return ggplot object showing a correlation heatmap
#' @examples
#' \dontrun{
#' plot_correlation_heatmap(calls_per_night)
#' }
#' @export
plot_correlation_heatmap <- function(calls_per_night) {
  
  # -------------------------------
  # Input validation
  # -------------------------------
  required_cols <- c("Detector", "Night", "CallsPerNight")
  
  if (!is.data.frame(calls_per_night)) {
    stop("calls_per_night must be a data frame")
  }
  
  missing_cols <- setdiff(required_cols, names(calls_per_night))
  if (length(missing_cols) > 0) {
    stop(
      "calls_per_night is missing required columns: ",
      paste(missing_cols, collapse = ", ")
    )
  }
  
  if (!inherits(calls_per_night$Night, "Date")) {
    stop("calls_per_night$Night must be of Date class")
  }
  
  if (!is.numeric(calls_per_night$CallsPerNight)) {
    stop("calls_per_night$CallsPerNight must be numeric")
  }
  
  # -------------------------------
  # Reshape to wide format
  # -------------------------------
  wide <- calls_per_night %>%
    select(Detector, Night, CallsPerNight) %>%
    tidyr::pivot_wider(
      names_from = Detector,
      values_from = CallsPerNight
    )
  
  # -------------------------------
  # Compute correlation matrix
  # -------------------------------
  cor_matrix <- cor(
    wide %>% select(-Night),
    use = "pairwise.complete.obs",
    method = "pearson"
  )
  
  cor_df <- as.data.frame(as.table(cor_matrix))
  names(cor_df) <- c("Detector1", "Detector2", "Correlation")
  
  # -------------------------------
  # Plot heatmap
  # -------------------------------
  ggplot(cor_df, aes(x = Detector1, y = Detector2, fill = Correlation)) +
    geom_tile(color = "white") +
    scale_fill_gradient2(
      low = "blue",
      mid = "white",
      high = "red",
      midpoint = 0,
      limits = c(-1, 1),
      name = "Pearson r"
    ) +
    labs(
      title = "Correlation of Nightly Activity Between Detectors",
      x = NULL,
      y = NULL
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1)
    )
}
