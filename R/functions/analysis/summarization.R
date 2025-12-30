# =============================================================================
# analysis/summarization.R — SUMMARY STATISTICS (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Generates comprehensive summary statistics and tables for exploratory
# analysis of bat acoustic data. Provides per-detector summaries, study-wide
# aggregations, species composition analysis, and temporal activity profiles.
#
# All functions are purely descriptive — no hypothesis testing or statistical
# inference. Output is designed for use in reports, publications, and as input
# to visualization functions.
#
# SUMMARIZATION CONTRACT
# ----------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Descriptive statistics only
#    - Mean, median, range, IQR, coefficient of variation
#    - No p-values, no hypothesis tests, no inference
#    - No ecological interpretations
#
# 2. Input validation
#    - All functions validate inputs using validation.R helpers
#    - Clear error messages with source hints
#    - Type checking for critical columns
#
# 3. Output format
#    - All functions return tibbles
#    - Consistent column naming (snake_case)
#    - Ready for export to CSV or use in reports
#    - Ready for formatting with output/tables.R
#
# 4. Non-destructive
#    - Input data frames are never modified
#    - Functions return new tibbles
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Perform statistical hypothesis testing
#   - Generate visualizations (output/visualization.R)
#   - Format tables for display (output/tables.R)
#   - Make ecological interpretations
#   - Read or write files directly
#
# DEPENDENCIES
# ------------
#   - core/utilities.R: log_message
#   - validation/validation.R: validate_data_frame, validate_cpn_data,
#     assert_column_type, assert_columns_exist
#   - dplyr: group_by, summarize, across, n, n_distinct
#   - tidyr: pivot_wider (for species summaries)
#
# CONTENTS
# --------
# Detector-Level Summaries:
#   - create_detector_activity_summary()   # Comprehensive per-detector metrics
#   - calculate_coefficient_of_variation() # CV per detector
#   - create_effort_summary_table()        # Recording effort by detector
#
# Study-Wide Summaries:
#   - create_study_summary()               # Single-row study overview
#   - calculate_variance_components()      # Between/within detector variance
#
# Species Analysis:
#   - create_species_summary_by_detector() # Species composition per detector
#   - create_species_accumulation_summary() # Species over time
#
# Temporal Analysis:
#   - create_hourly_activity_summary()     # Activity by hour of night
#
# File I/O:
#   - save_master_with_timestamp()         # Save with timestamp in filename
#
# USAGE EXAMPLE
# -------------
# # After loading CallsPerNight final data
# cpn_final <- load_cpn_final()
#
# # Generate summaries
# detector_summary <- create_detector_activity_summary(cpn_final)
# study_summary <- create_study_summary(cpn_final)
# species_summary <- create_species_summary_by_detector(kpro_master)
#
# # Format as GT tables
# detector_gt <- format_detector_summary_gt(detector_summary)
# study_gt <- format_study_summary_gt(study_summary)
#
# CHANGELOG
# ---------
# 2024-12-29: Added new summary functions for Workflow 05
# 2024-12-29: Refactored to use validation.R helpers
# 2024-12-26: Initial CODING_STANDARDS compliant version
#
# =============================================================================


# ==============================================================================
# DETECTOR-LEVEL SUMMARIES
# ==============================================================================


#' Create Comprehensive Detector Activity Summary
#'
#' @description
#' Creates a comprehensive per-detector summary combining effort metrics,
#' activity metrics, and variability metrics. This is the primary summary
#' for assessing detector performance and bat activity patterns.
#'
#' @param cpn_final Data frame. CallsPerNight final data from Workflow 04.
#'   Must contain: Detector, Night, CallsPerNight, RecordingHours, Status,
#'   CallsPerHour.
#'
#' @return Tibble with one row per detector and columns:
#'   \describe{
#'     \item{Detector}{Detector name}
#'     \item{n_nights}{Number of nights in study period}
#'     \item{total_hours}{Total recording hours}
#'     \item{mean_hours}{Mean hours per night}
#'     \item{pct_success}{Percent of nights with full recording}
#'     \item{pct_partial}{Percent of nights with partial recording}
#'     \item{pct_fail}{Percent of nights with no recording}
#'     \item{total_calls}{Total bat calls detected}
#'     \item{mean_cpn}{Mean calls per night}
#'     \item{mean_cph}{Mean calls per hour}
#'     \item{median_cph}{Median calls per hour}
#'     \item{sd_cph}{Standard deviation of calls per hour}
#'     \item{min_cph}{Minimum calls per hour}
#'     \item{max_cph}{Maximum calls per hour}
#'     \item{cv_pct}{Coefficient of variation (percent)}
#'     \item{pct_zero}{Percent of nights with zero calls}
#'     \item{first_night}{First night of recording}
#'     \item{last_night}{Last night of recording}
#'   }
#'
#' @section CONTRACT:
#' - Returns one row per detector
#' - All metrics calculated with na.rm = TRUE
#' - Percentages are 0-100 scale
#' - CV calculated as sd/mean * 100
#'
#' @section DOES NOT:
#' - Make ecological interpretations
#' - Filter out any detectors
#' - Modify input data
#'
#' @examples
#' \dontrun{
#' cpn_final <- load_cpn_final()
#' detector_summary <- create_detector_activity_summary(cpn_final)
#' }
#'
#' @export
create_detector_activity_summary <- function(cpn_final) {
  
  
  # Input validation using helpers
  validate_cpn_data(cpn_final, require_status = TRUE, require_cph = TRUE)
  
  # Calculate comprehensive summary
  cpn_final %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      # Effort metrics
      n_nights = dplyr::n(),
      total_hours = round(sum(RecordingHours, na.rm = TRUE), 1),
      mean_hours = round(mean(RecordingHours, na.rm = TRUE), 1),
      pct_success = round(100 * sum(Status == "Success", na.rm = TRUE) / dplyr::n(), 1),
      pct_partial = round(100 * sum(Status == "Partial", na.rm = TRUE) / dplyr::n(), 1),
      pct_fail = round(100 * sum(Status == "Fail", na.rm = TRUE) / dplyr::n(), 1),
      
      # Activity metrics
      total_calls = sum(CallsPerNight, na.rm = TRUE),
      mean_cpn = round(mean(CallsPerNight, na.rm = TRUE), 1),
      mean_cph = round(mean(CallsPerHour, na.rm = TRUE), 2),
      median_cph = round(median(CallsPerHour, na.rm = TRUE), 2),
      
      # Variability metrics
      sd_cph = round(sd(CallsPerHour, na.rm = TRUE), 2),
      min_cph = round(min(CallsPerHour, na.rm = TRUE), 2),
      max_cph = round(max(CallsPerHour, na.rm = TRUE), 2),
      cv_pct = round(100 * sd(CallsPerHour, na.rm = TRUE) /
                       mean(CallsPerHour, na.rm = TRUE), 1),
      pct_zero = round(100 * sum(CallsPerNight == 0, na.rm = TRUE) / dplyr::n(), 1),
      
      # Date range
      first_night = min(Night, na.rm = TRUE),
      last_night = max(Night, na.rm = TRUE),
      
      .groups = "drop"
    )
}


#' Calculate Coefficient of Variation by Detector
#'
#' @description
#' Computes mean calls, standard deviation, and coefficient of variation
#' for nightly detector activity. Simpler alternative to full detector summary.
#'
#' @param calls_per_night Data frame. Must contain Detector and CallsPerNight.
#'
#' @return Tibble with columns: Detector, mean_calls, sd_calls, cv.
#'
#' @section CONTRACT:
#' - Groups strictly by Detector
#' - Uses sd / mean definition of CV
#' - Returns NA for cv if mean_calls is 0
#'
#' @section DOES NOT:
#' - Perform filtering
#' - Normalize detector identifiers
#'
#' @export
calculate_coefficient_of_variation <- function(calls_per_night) {
  
  # Input validation using helpers
  validate_data_frame(
    calls_per_night,
    required_cols = c("Detector", "CallsPerNight"),
    arg_name = "calls_per_night"
  )
  assert_column_type(calls_per_night, "CallsPerNight", "numeric")
  
  calls_per_night %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      mean_calls = mean(CallsPerNight, na.rm = TRUE),
      sd_calls = sd(CallsPerNight, na.rm = TRUE),
      cv = ifelse(mean_calls == 0, NA_real_, sd_calls / mean_calls),
      .groups = "drop"
    )
}


#' Summary Table of Recording Effort by Detector
#'
#' @description
#' Produces descriptive statistics summarizing deployment effort for each
#' detector. Focused on recording hours and data completeness.
#'
#' @param calls_per_night Data frame. Must contain Detector, Night, RecordingHours.
#'
#' @return Tibble with columns: Detector, total_nights, nights_with_data,
#'   total_recording_hours, percent_nights_with_data, mean_hours_per_night,
#'   date_range.
#'
#' @section CONTRACT:
#' - One row per detector
#' - date_range is character string "YYYY-MM-DD to YYYY-MM-DD"
#' - Percentages rounded to 1 decimal
#'
#' @section DOES NOT:
#' - Include call counts (use create_detector_activity_summary)
#' - Filter detectors
#'
#' @export
create_effort_summary_table <- function(calls_per_night) {
  
  # Input validation using helpers
  validate_data_frame(
    calls_per_night,
    required_cols = c("Detector", "Night", "RecordingHours"),
    arg_name = "calls_per_night"
  )
  assert_column_type(calls_per_night, "Night", "Date")
  assert_column_type(calls_per_night, "RecordingHours", "numeric")
  
  calls_per_night %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      total_nights = dplyr::n(),
      nights_with_data = sum(!is.na(RecordingHours) & RecordingHours > 0),
      total_recording_hours = round(sum(RecordingHours, na.rm = TRUE), 1),
      percent_nights_with_data = round(100 * nights_with_data / total_nights, 1),
      mean_hours_per_night = round(mean(RecordingHours, na.rm = TRUE), 2),
      date_range = paste(min(Night, na.rm = TRUE), "to", max(Night, na.rm = TRUE)),
      .groups = "drop"
    )
}


# ==============================================================================
# STUDY-WIDE SUMMARIES
# ==============================================================================


#' Create Study-Wide Summary
#'
#' @description
#' Creates a single-row summary of the entire study. Aggregates across all
#' detectors and nights. Useful for report headers and study overview tables.
#'
#' @param cpn_final Data frame. CallsPerNight final data from Workflow 04.
#'
#' @return Single-row tibble with columns:
#'   \describe{
#'     \item{n_detectors}{Number of unique detectors}
#'     \item{n_detector_nights}{Total detector-nights}
#'     \item{study_start}{First night of study}
#'     \item{study_end}{Last night of study}
#'     \item{study_duration_days}{Number of days in study}
#'     \item{total_calls}{Total bat calls across all detectors}
#'     \item{total_hours}{Total recording hours}
#'     \item{overall_mean_cph}{Mean calls per hour (study-wide)}
#'     \item{overall_median_cph}{Median calls per hour}
#'     \item{overall_sd_cph}{Standard deviation of CPH}
#'     \item{overall_cv_pct}{Coefficient of variation}
#'     \item{pct_success}{Percent detector-nights with full recording}
#'     \item{pct_partial}{Percent with partial recording}
#'     \item{pct_fail}{Percent with no recording}
#'   }
#'
#' @section CONTRACT:
#' - Returns exactly one row
#' - Aggregates across ALL detectors
#' - CV calculated as sd/mean * 100
#'
#' @section DOES NOT:
#' - Break down by detector (use create_detector_activity_summary)
#' - Include species information
#'
#' @export
create_study_summary <- function(cpn_final) {
  
  # Input validation
  validate_cpn_data(cpn_final, require_status = TRUE, require_cph = TRUE)
  
  tibble::tibble(
    n_detectors = dplyr::n_distinct(cpn_final$Detector),
    n_detector_nights = nrow(cpn_final),
    study_start = min(cpn_final$Night, na.rm = TRUE),
    study_end = max(cpn_final$Night, na.rm = TRUE),
    study_duration_days = as.integer(study_end - study_start) + 1L,
    total_calls = sum(cpn_final$CallsPerNight, na.rm = TRUE),
    total_hours = round(sum(cpn_final$RecordingHours, na.rm = TRUE), 1),
    overall_mean_cph = round(mean(cpn_final$CallsPerHour, na.rm = TRUE), 2),
    overall_median_cph = round(median(cpn_final$CallsPerHour, na.rm = TRUE), 2),
    overall_sd_cph = round(sd(cpn_final$CallsPerHour, na.rm = TRUE), 2),
    overall_cv_pct = round(100 * overall_sd_cph / overall_mean_cph, 1),
    pct_success = round(100 * sum(cpn_final$Status == "Success", na.rm = TRUE) /
                          nrow(cpn_final), 1),
    pct_partial = round(100 * sum(cpn_final$Status == "Partial", na.rm = TRUE) /
                          nrow(cpn_final), 1),
    pct_fail = round(100 * sum(cpn_final$Status == "Fail", na.rm = TRUE) /
                       nrow(cpn_final), 1)
  )
}


#' Calculate Variance Components
#'
#' @description
#' Decomposes total variance in calls per hour into between-detector and
#' within-detector components. Helps understand whether variation is
#' primarily spatial (between sites) or temporal (within sites).
#'
#' @param cpn_final Data frame. CallsPerNight final data.
#'
#' @return Single-row tibble with columns:
#'   \describe{
#'     \item{var_total}{Total variance in CPH}
#'     \item{var_between}{Between-detector variance}
#'     \item{var_within}{Within-detector variance (residual)}
#'     \item{pct_between}{Percent of variance between detectors}
#'     \item{pct_within}{Percent of variance within detectors}
#'     \item{icc}{Intraclass correlation coefficient}
#'   }
#'
#' @section CONTRACT:
#' - Returns single row
#' - ICC = var_between / var_total
#' - pct_between + pct_within = 100 (approximately)
#'
#' @section DOES NOT:
#' - Perform formal ANOVA or hypothesis testing
#' - Account for temporal autocorrelation
#'
#' @export
calculate_variance_components <- function(cpn_final) {
  
  # Input validation
  validate_cpn_data(cpn_final, require_cph = TRUE)
  
  # Calculate detector means
  detector_means <- cpn_final %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      detector_mean = mean(CallsPerHour, na.rm = TRUE),
      n_obs = dplyr::n(),
      .groups = "drop"
    )
  
  # Grand mean
  grand_mean <- mean(cpn_final$CallsPerHour, na.rm = TRUE)
  
  # Total variance
  var_total <- var(cpn_final$CallsPerHour, na.rm = TRUE)
  
  # Between-detector variance (variance of detector means)
  var_between <- var(detector_means$detector_mean, na.rm = TRUE)
  
  # Within-detector variance (mean of within-detector variances)
  within_vars <- cpn_final %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      var_within = var(CallsPerHour, na.rm = TRUE),
      .groups = "drop"
    )
  var_within <- mean(within_vars$var_within, na.rm = TRUE)
  
  tibble::tibble(
    var_total = round(var_total, 2),
    var_between = round(var_between, 2),
    var_within = round(var_within, 2),
    pct_between = round(100 * var_between / var_total, 1),
    pct_within = round(100 * var_within / var_total, 1),
    icc = round(var_between / var_total, 3)
  )
}


# ==============================================================================
# SPECIES ANALYSIS
# ==============================================================================


#' Create Species Summary by Detector
#'
#' @description
#' Summarizes species composition for each detector. Shows call counts
#' and percentages for each species detected.
#'
#' @param master_data Data frame. Master file from Workflow 02.
#'   Must contain Detector and auto_id columns.
#' @param species_col Character. Column containing species ID.
#'   Default: "auto_id"
#' @param min_calls Integer. Minimum calls to include species.
#'   Default: 1 (include all)
#'
#' @return Tibble with columns:
#'   \describe{
#'     \item{Detector}{Detector name}
#'     \item{species}{Species code}
#'     \item{n_calls}{Number of calls}
#'     \item{pct_of_detector}{Percent of detector's total calls}
#'   }
#'
#' @section CONTRACT:
#' - One row per detector-species combination
#' - Excludes NoID/UNKNOWN unless they meet min_calls
#' - Percentages sum to 100 within each detector
#' - Sorted by Detector, then n_calls descending
#'
#' @section DOES NOT:
#' - Make species richness comparisons
#' - Account for detection probability
#'
#' @export
create_species_summary_by_detector <- function(master_data,
                                               species_col = "auto_id",
                                               min_calls = 1) {
  
  # Input validation
  validate_master_data(master_data)
  assert_columns_exist(master_data, species_col)
  
  master_data %>%
    dplyr::filter(!is.na(.data[[species_col]])) %>%
    dplyr::group_by(Detector, species = .data[[species_col]]) %>%
    dplyr::summarise(
      n_calls = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::group_by(Detector) %>%
    dplyr::mutate(
      pct_of_detector = round(100 * n_calls / sum(n_calls), 1)
    ) %>%
    dplyr::ungroup() %>%
    dplyr::filter(n_calls >= min_calls) %>%
    dplyr::arrange(Detector, dplyr::desc(n_calls))
}


#' Create Species Accumulation Summary
#'
#' @description
#' Shows cumulative species count over time. Useful for assessing
#' whether sampling effort was sufficient to detect most species.
#'
#' @param master_data Data frame. Master file with DateTime and auto_id.
#' @param species_col Character. Column containing species ID.
#'   Default: "auto_id"
#' @param date_col Character. Column containing date. Default: "DateTime"
#'
#' @return Tibble with columns:
#'   \describe{
#'     \item{date}{Date}
#'     \item{new_species}{Number of new species detected that date}
#'     \item{cumulative_species}{Running total of unique species}
#'     \item{new_species_list}{Character, comma-separated new species}
#'   }
#'
#' @section CONTRACT:
#' - One row per date with detections
#' - Excludes NoID/UNKNOWN from species counts
#' - cumulative_species is monotonically increasing
#'
#' @section DOES NOT:
#' - Account for detection probability
#' - Weight by effort
#'
#' @export
create_species_accumulation_summary <- function(master_data,
                                                species_col = "auto_id",
                                                date_col = "DateTime") {
  
  # Input validation
  validate_master_data(master_data)
  assert_columns_exist(master_data, c(species_col, date_col))
  
  # Extract date from DateTime if needed
  if (inherits(master_data[[date_col]], "POSIXt")) {
    master_data <- master_data %>%
      dplyr::mutate(.date = as.Date(.data[[date_col]]))
  } else {
    master_data <- master_data %>%
      dplyr::mutate(.date = as.Date(.data[[date_col]]))
  }
  
  # Exclude unidentified
  valid_species <- master_data %>%
    dplyr::filter(
      !is.na(.data[[species_col]]),
      !.data[[species_col]] %in% c("NoID", "UNKNOWN", "NOISE", "")
    )
  
  # Get first detection date for each species
  first_detections <- valid_species %>%
    dplyr::group_by(species = .data[[species_col]]) %>%
    dplyr::summarise(
      first_date = min(.date, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Accumulate by date
  accumulation <- first_detections %>%
    dplyr::group_by(date = first_date) %>%
    dplyr::summarise(
      new_species = dplyr::n(),
      new_species_list = paste(species, collapse = ", "),
      .groups = "drop"
    ) %>%
    dplyr::arrange(date) %>%
    dplyr::mutate(
      cumulative_species = cumsum(new_species)
    )
  
  accumulation
}


# ==============================================================================
# TEMPORAL ANALYSIS
# ==============================================================================


#' Create Hourly Activity Summary
#'
#' @description
#' Summarizes bat activity by hour of the night. Can be calculated overall
#' or per-detector. Useful for identifying peak activity periods.
#'
#' @param master_data Data frame. Master file with DateTime or Hour column.
#' @param by_detector Logical. Summarize by detector? Default: FALSE
#'
#' @return Tibble with columns:
#'   \describe{
#'     \item{Hour}{Hour of day (0-23)}
#'     \item{Detector}{(if by_detector=TRUE) Detector name}
#'     \item{n_calls}{Number of calls in that hour}
#'     \item{pct_of_total}{Percent of total calls}
#'   }
#'
#' @section CONTRACT:
#' - One row per hour (or per hour-detector)
#' - Hour is 0-23 integer
#' - Percentages sum to 100 (within detector if by_detector)
#'
#' @section DOES NOT:
#' - Account for recording effort differences between hours
#' - Adjust for seasonal variation in night length
#'
#' @export
create_hourly_activity_summary <- function(master_data,
                                           by_detector = FALSE) {
  
  # Input validation
  validate_master_data(master_data)
  
  # Get hour from DateTime if Hour column doesn't exist
  if (!"Hour" %in% names(master_data)) {
    if ("DateTime" %in% names(master_data)) {
      master_data <- master_data %>%
        dplyr::mutate(Hour = lubridate::hour(DateTime))
    } else {
      stop("master_data must have either 'Hour' or 'DateTime' column")
    }
  }
  
  if (by_detector) {
    summary <- master_data %>%
      dplyr::group_by(Detector, Hour) %>%
      dplyr::summarise(
        n_calls = dplyr::n(),
        .groups = "drop"
      ) %>%
      dplyr::group_by(Detector) %>%
      dplyr::mutate(
        pct_of_total = round(100 * n_calls / sum(n_calls), 1)
      ) %>%
      dplyr::ungroup() %>%
      dplyr::arrange(Detector, Hour)
  } else {
    summary <- master_data %>%
      dplyr::group_by(Hour) %>%
      dplyr::summarise(
        n_calls = dplyr::n(),
        .groups = "drop"
      ) %>%
      dplyr::mutate(
        pct_of_total = round(100 * n_calls / sum(n_calls), 1)
      ) %>%
      dplyr::arrange(Hour)
  }
  
  summary
}


# ==============================================================================
# FILE I/O
# ==============================================================================


#' Save Master File with Timestamp
#'
#' @description
#' Saves data frame as CSV with current timestamp in filename. Creates
#' output directory if it doesn't exist.
#'
#' @param data Data frame to save.
#' @param base_name Character. Base name for file. Default: "Master"
#' @param output_dir Character. Directory to save the file.
#'   Default: "results/csv"
#'
#' @return Character. Full file path of saved CSV.
#'
#' @section CONTRACT:
#' - Creates directory if needed
#' - Filename format: {base_name}_{YYYY-MM-DD_HHMM}.csv
#' - Messages on success
#'
#' @section DOES NOT:
#' - Overwrite existing files
#' - Validate data structure
#'
#' @export
save_master_with_timestamp <- function(data,
                                       base_name = "Master",
                                       output_dir = "results/csv") {
  
  # Input validation using helpers
  assert_data_frame(data, "data")
  assert_scalar_string(base_name, "base_name")
  assert_scalar_string(output_dir, "output_dir")
  assert_directory_exists(output_dir, create = TRUE)
  
  # Build filename with timestamp
  timestamp <- format(Sys.time(), "%Y-%m-%d_%H%M")
  file_path <- file.path(output_dir, paste0(base_name, "_", timestamp, ".csv"))
  
  # Save
  readr::write_csv(data, file_path)
  message("\u2713 Master file saved: ", file_path)
  
  return(file_path)
}