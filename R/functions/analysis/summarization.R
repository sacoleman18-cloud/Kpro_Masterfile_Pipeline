# =============================================================================
# analysis/summarization.R â€” SUMMARY STATISTICS (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Generates summary statistics and tables for exploratory analysis.
# Purely descriptive â€” no hypothesis testing.
#
# SUMMARIZATION CONTRACT
# ----------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Descriptive statistics only
#    - Mean, median, range, IQR, coefficient of variation
#    - No p-values, no hypothesis tests, no inference
#
# 2. Per-detector summaries
#    - Statistics calculated per detector
#    - Aggregated totals also provided
#
# 3. Recording effort metrics
#    - Total recording hours
#    - % nights with data
#    - % nights with >0 calls
#
# 4. Output format
#    - All functions return tibbles
#    - Ready for export to CSV or display in reports
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Perform statistical hypothesis testing
#   - Generate visualizations (output/visualization.R)
#   - Make ecological interpretations
#
# DEPENDENCIES
# ------------
#   - core/utilities.R: log_message
#   - dplyr: group_by, summarize, across
#
# CONTENTS
# --------
#   - calculate_coefficient_of_variation()
#   - create_effort_summary_table()
#   - save_master_with_timestamp()
#
# =============================================================================

# --------------------------------------------------
# Coefficient of Variation of Detector Activity
# --------------------------------------------------

#' Calculate coefficient of variation of detector activity
#'
#' @description
#' Computes mean calls, standard deviation, and coefficient of variation
#' for nightly detector activity.
#'
#' CONTRACT
#'   â€¢ Groups strictly by Detector
#'   â€¢ Uses sd / mean definition of CV
#'
#' DOES NOT
#'   â€¢ Perform filtering
#'   â€¢ Normalize detector identifiers
#'
#' @param calls_per_night Data frame with Detector and CallsPerNight columns.
#'
#' @return Tibble summarizing mean_calls, sd_calls, and cv per detector.
#' @export
calculate_coefficient_of_variation <- function(calls_per_night) {
  
  if (!is.data.frame(calls_per_night)) {
    stop("calls_per_night must be a data frame")
  }
  
  required <- c("Detector", "CallsPerNight")
  missing <- setdiff(required, names(calls_per_night))
  
  if (length(missing) > 0) {
    stop("Missing required columns: ", paste(missing, collapse = ", "))
  }
  
  if (!is.numeric(calls_per_night$CallsPerNight)) {
    stop("CallsPerNight must be numeric")
  }
  
  calls_per_night %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      mean_calls = mean(CallsPerNight, na.rm = TRUE),
      sd_calls   = sd(CallsPerNight, na.rm = TRUE),
      cv         = ifelse(mean_calls == 0, NA_real_, sd_calls / mean_calls),
      .groups    = "drop"
    )
}

#--------------------------------------------------
# Summary Table of Recording Effort by Detector
#--------------------------------------------------
#' Summary Table of Recording Effort by Detector
#'
#' Produces descriptive statistics summarizing deployment effort
#' for each detector.
#'
#' @param calls_per_night Data frame containing columns:
#'   - Detector: unique identifier for each detector
#'   - Night: date of recording (Date class)
#'   - RecordingHours: numeric recording duration for each night
#' @return Data frame summarizing total nights, nights with data,
#'   total recording hours, percent nights with data, mean hours per night,
#'   and date range for each detector.
#' @examples
#' \dontrun{
#' summary_table <- create_effort_summary_table(calls_per_night)
#' }
#' @export
create_effort_summary_table <- function(calls_per_night) {
  
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
  # Compute summary statistics
  # -------------------------------
  calls_per_night %>%
    group_by(Detector) %>%
    summarise(
      total_nights = n(),
      nights_with_data = sum(!is.na(RecordingHours)),
      total_recording_hours = sum(RecordingHours, na.rm = TRUE),
      percent_nights_with_data = round(100 * nights_with_data / total_nights, 1),
      mean_hours_per_night = round(mean(RecordingHours, na.rm = TRUE), 2),
      date_range = paste(min(Night, na.rm = TRUE), "to", max(Night, na.rm = TRUE)),
      .groups = "drop"
    )
}

#--------------------------------------------------
# Save Master File with Timestamp (UPDATED - DateTime formatting)
#--------------------------------------------------
#' Save Master File with Timestamp
#'
#' Saves master data as CSV with current timestamp in filename.
#' Optionally formats DateTime columns for US-friendly CSV export.
#'
#' @param data Data frame to save.
#' @param base_name Base name for file. Default is "Master".
#' @param output_dir Directory to save the file.
#' @param format_datetime Logical. Should DateTime columns be formatted for export?
#'   Default TRUE. Converts POSIXct to "MM/DD/YYYY HH:MM:SS AM/PM" format.
#' @return Full file path of saved CSV.
#' @export
save_master_with_timestamp <- function(data, 
                                       base_name = "Master", 
                                       output_dir = "results/csv",
                                       format_datetime = TRUE) {
  
  # -------------------------------
  # Input validation
  # -------------------------------
  if (!is.data.frame(data)) stop("data must be a data frame")
  if (!is.character(base_name) || length(base_name) != 1) stop("base_name must be a single string")
  if (!is.character(output_dir) || length(output_dir) != 1) stop("output_dir must be a single string")
  if (!is.logical(format_datetime) || length(format_datetime) != 1) stop("format_datetime must be TRUE or FALSE")
  
  # -------------------------------
  # Ensure directory
  # -------------------------------
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  
  # -------------------------------
  # Format DateTime columns if requested
  # -------------------------------
  if (format_datetime) {
    data <- format_datetime_for_export(data)
  }
  
  # -------------------------------
  # Save CSV
  # -------------------------------
  timestamp <- format(Sys.time(), "%Y-%m-%d_%H%M")
  file_path <- file.path(output_dir, paste0(base_name, "_", timestamp, ".csv"))
  readr::write_csv(data, file_path)
  message("✓ Master file saved: ", file_path)
  return(file_path)
}