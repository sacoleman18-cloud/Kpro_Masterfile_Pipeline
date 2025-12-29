# =============================================================================
# analysis/summarization.R — SUMMARY STATISTICS (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Generates summary statistics and tables for exploratory analysis.
# Purely descriptive — no hypothesis testing.
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
# 4. Species composition metrics
#    - Counts and proportions per detector
#    - Species richness per detector
#    - Accumulation over study period
# 
# 5. Temporal activity metrics
#    - Hourly activity profiles (overall and per-detector)
#    - Peak activity hours
#
# 6. Output format
#    - All functions return tibbles
#    - Ready for export to CSV or display in reports
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Perform statistical hypothesis testing
#   - Generate visualizations (output/visualization.R)
#   - Format tables for presentation (output/tables.R)
#   - Make ecological interpretations
#   - Perform species identification validation
#
# DEPENDENCIES
# ------------
#   - dplyr: group_by, summarize, across, n, n_distinct
#   - tidyr: pivot_wider (for species matrices)
#   - lubridate: hour (for temporal summaries)
#
# CONTENTS
# --------
# Existing Functions:
#   - calculate_coefficient_of_variation()
#   - create_effort_summary_table()
#   - save_master_with_timestamp()
#
# New Functions (Aggregated Data - CallsPerNight):
#   - create_detector_activity_summary()
#   - create_study_summary()
#   - calculate_variance_components()
#
# New Functions (Row-Level Data - Master):
#   - create_species_summary_by_detector()
#   - create_species_accumulation_summary()
#   - create_hourly_activity_summary()
#
# CHANGELOG
# ---------
# 2024-12-29: Added species, temporal, and comprehensive summary functions
# 2024-12-27: Initial version with CV and effort functions
#
# =============================================================================


# ==============================================================================
# EXISTING FUNCTIONS
# ==============================================================================


# ------------------------------------------------------------------------------
# Coefficient of Variation of Detector Activity
# ------------------------------------------------------------------------------

#' Calculate Coefficient of Variation of Detector Activity
#'
#' @description
#' Computes mean calls, standard deviation, and coefficient of variation
#' for nightly detector activity.
#'
#' @param calls_per_night Data frame with Detector and CallsPerNight columns.
#'
#' @return Tibble summarizing mean_calls, sd_calls, and cv per detector.
#'
#' @section CONTRACT:
#' - Groups strictly by Detector
#' - Uses sd / mean definition of CV
#'
#' @section DOES NOT:
#' - Perform filtering
#' - Normalize detector identifiers
#'
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


# ------------------------------------------------------------------------------
# Summary Table of Recording Effort by Detector
# ------------------------------------------------------------------------------

#' Summary Table of Recording Effort by Detector
#'
#' @description
#' Produces descriptive statistics summarizing deployment effort
#' for each detector.
#'
#' @param calls_per_night Data frame containing columns:
#'   - Detector: unique identifier for each detector
#'   - Night: date of recording (Date class)
#'   - RecordingHours: numeric recording duration for each night
#'
#' @return Data frame summarizing total nights, nights with data,
#'   total recording hours, percent nights with data, mean hours per night,
#'   and date range for each detector.
#'
#' @section CONTRACT:
#' - Groups by Detector
#' - Calculates effort metrics only
#' - Returns tibble
#'
#' @section DOES NOT:
#' - Calculate activity metrics
#' - Filter data
#'
#' @export
create_effort_summary_table <- function(calls_per_night) {
  
  # Input validation
  required_cols <- c("Detector", "Night", "RecordingHours")
  
  if (!is.data.frame(calls_per_night)) {
    stop("calls_per_night must be a data frame")
  }
  
  missing_cols <- setdiff(required_cols, names(calls_per_night))
  if (length(missing_cols) > 0) {
    stop("calls_per_night is missing required columns: ", 
         paste(missing_cols, collapse = ", "))
  }
  
  if (!inherits(calls_per_night$Night, "Date")) {
    stop("calls_per_night$Night must be of Date class")
  }
  
  if (!is.numeric(calls_per_night$RecordingHours)) {
    stop("calls_per_night$RecordingHours must be numeric")
  }
  
  # Compute summary statistics
  calls_per_night %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      total_nights = dplyr::n(),
      nights_with_data = sum(!is.na(RecordingHours)),
      total_recording_hours = sum(RecordingHours, na.rm = TRUE),
      percent_nights_with_data = round(100 * nights_with_data / total_nights, 1),
      mean_hours_per_night = round(mean(RecordingHours, na.rm = TRUE), 2),
      date_range = paste(min(Night, na.rm = TRUE), "to", max(Night, na.rm = TRUE)),
      .groups = "drop"
    )
}


# ------------------------------------------------------------------------------
# Save Master File with Timestamp
# ------------------------------------------------------------------------------

#' Save Master File with Timestamp
#'
#' @description
#' Saves master data as CSV with current timestamp in filename.
#'
#' @param data Data frame to save.
#' @param base_name Base name for file. Default is "Master".
#' @param output_dir Directory to save the file.
#'
#' @return Full file path of saved CSV.
#'
#' @section CONTRACT:
#' - Creates directory if needed
#' - Adds timestamp to filename
#' - Returns file path
#'
#' @section DOES NOT:
#' - Validate data structure
#' - Modify data before saving
#'
#' @export
save_master_with_timestamp <- function(data, 
                                       base_name = "Master", 
                                       output_dir = "results/csv") {
  
  # Input validation
  if (!is.data.frame(data)) stop("data must be a data frame")
  if (!is.character(base_name) || length(base_name) != 1) {
    stop("base_name must be a single string")
  }
  if (!is.character(output_dir) || length(output_dir) != 1) {
    stop("output_dir must be a single string")
  }
  
  # Ensure directory exists
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  
  # Save CSV with timestamp
  
  timestamp <- format(Sys.time(), "%Y-%m-%d_%H%M")
  file_path <- file.path(output_dir, paste0(base_name, "_", timestamp, ".csv"))
  readr::write_csv(data, file_path)
  message("✓ Master file saved: ", file_path)
  
  return(file_path)
}


# ==============================================================================
# NEW FUNCTIONS: From CallsPerNight (Aggregated Data)
# ==============================================================================


# ------------------------------------------------------------------------------
# Comprehensive Detector Activity Summary
# ------------------------------------------------------------------------------

#' Comprehensive Detector Activity Summary
#'
#' @description
#' Creates a complete summary table combining effort, activity, and variability
#' metrics for each detector. This is the primary detector-level output table.
#'
#' @param cpn_final Data frame containing CallsPerNight final data with columns:
#'   - Detector: Unique identifier for each detector
#'   - Night: Date of recording (Date class)
#'   - CallsPerNight: Count of bat calls per night
#'   - CallsPerHour: Standardized activity rate
#'   - RecordingHours: Hours of recording effort
#'   - Status: Recording status (Success, Partial, Fail)
#'
#' @return Tibble with one row per detector containing:
#'   \describe{
#'     \item{Detector}{Detector name}
#'     \item{n_nights}{Total study nights}
#'     \item{total_hours}{Sum of RecordingHours}
#'     \item{mean_hours}{Mean hours per night}
#'     \item{pct_success}{Percent of nights with Status = "Success"}
#'     \item{pct_partial}{Percent of nights with Status = "Partial"}
#'     \item{pct_fail}{Percent of nights with Status = "Fail"}
#'     \item{total_calls}{Sum of CallsPerNight}
#'     \item{mean_cpn}{Mean CallsPerNight}
#'     \item{mean_cph}{Mean CallsPerHour}
#'     \item{median_cph}{Median CallsPerHour}
#'     \item{sd_cph}{Standard deviation of CallsPerHour}
#'     \item{min_cph}{Minimum CallsPerHour}
#'     \item{max_cph}{Maximum CallsPerHour}
#'     \item{cv_pct}{Coefficient of variation as percentage}
#'     \item{pct_zero}{Percent of nights with zero calls}
#'     \item{first_night}{First night in study period}
#'     \item{last_night}{Last night in study period}
#'   }
#'
#' @section CONTRACT:
#' - Returns one row per unique Detector
#' - All numeric columns rounded appropriately
#' - CV calculated as (SD / Mean) x 100
#' - Handles NA values gracefully (na.rm = TRUE)
#' - Returns tibble (not data.frame)
#'
#' @section DOES NOT:
#' - Filter rows based on Status or any criteria
#' - Perform statistical tests
#' - Make recommendations about detector performance
#' - Modify input data
#' - Format for presentation (use output/tables.R)
#'
#' @examples
#' \dontrun{
#' cpn_final <- read_csv("results/csv/CallsPerNight_final_v1.csv")
#' detector_summary <- create_detector_activity_summary(cpn_final)
#' print(detector_summary)
#' }
#'
#' @export
create_detector_activity_summary <- function(cpn_final) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(cpn_final)) {
    stop("cpn_final must be a data frame")
  }
  
  required_cols <- c("Detector", "Night", "CallsPerNight", 
                     "CallsPerHour", "RecordingHours", "Status")
  missing_cols <- setdiff(required_cols, names(cpn_final))
  
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "cpn_final is missing required columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
  }
  
  if (nrow(cpn_final) == 0) {
    stop("cpn_final is empty - no data to summarize")
  }
  
  # -------------------------
  # Calculate summary statistics
  # -------------------------
  
  summary_df <- cpn_final %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      # Effort metrics
      n_nights = dplyr::n(),
      total_hours = round(sum(RecordingHours, na.rm = TRUE), 1),
      mean_hours = round(mean(RecordingHours, na.rm = TRUE), 2),
      pct_success = round(100 * sum(Status == "Success", na.rm = TRUE) / dplyr::n(), 1),
      pct_partial = round(100 * sum(Status == "Partial", na.rm = TRUE) / dplyr::n(), 1),
      pct_fail = round(100 * sum(Status == "Fail", na.rm = TRUE) / dplyr::n(), 1),
      
      # Activity metrics
      total_calls = sum(CallsPerNight, na.rm = TRUE),
      mean_cpn = round(mean(CallsPerNight, na.rm = TRUE), 2),
      mean_cph = round(mean(CallsPerHour, na.rm = TRUE), 2),
      median_cph = round(median(CallsPerHour, na.rm = TRUE), 2),
      sd_cph = round(sd(CallsPerHour, na.rm = TRUE), 2),
      min_cph = round(min(CallsPerHour, na.rm = TRUE), 2),
      max_cph = round(max(CallsPerHour, na.rm = TRUE), 2),
      
      # Variability metrics
      cv_pct = round(ifelse(mean(CallsPerHour, na.rm = TRUE) == 0,
                            NA_real_,
                            100 * sd(CallsPerHour, na.rm = TRUE) / 
                              mean(CallsPerHour, na.rm = TRUE)), 1),
      pct_zero = round(100 * sum(CallsPerNight == 0, na.rm = TRUE) / dplyr::n(), 1),
      
      # Date range
      first_night = min(Night, na.rm = TRUE),
      last_night = max(Night, na.rm = TRUE),
      
      .groups = "drop"
    )
  
  message(sprintf("✓ Created detector activity summary for %d detectors", 
                  nrow(summary_df)))
  
  summary_df
}


# ------------------------------------------------------------------------------
# Study-Wide Summary (Single Row)
# ------------------------------------------------------------------------------

#' Study-Wide Summary Statistics
#'
#' @description
#' Creates a single-row summary of study-wide totals and averages.
#' Provides high-level overview of entire monitoring effort.
#'
#' @param cpn_final Data frame containing CallsPerNight final data with columns:
#'   - Detector: Unique identifier for each detector
#'   - Night: Date of recording (Date class)
#'   - CallsPerNight: Count of bat calls per night
#'   - CallsPerHour: Standardized activity rate
#'   - RecordingHours: Hours of recording effort
#'   - Status: Recording status (Success, Partial, Fail)
#'
#' @return Tibble with single row containing study-wide metrics.
#'
#' @section CONTRACT:
#' - Returns exactly one row
#' - Aggregates across all detectors and nights
#' - Date range reflects actual data, not YAML configuration
#' - Returns tibble (not data.frame)
#'
#' @section DOES NOT:
#' - Break down by detector (use create_detector_activity_summary)
#' - Include species information
#' - Perform statistical tests
#'
#' @examples
#' \dontrun{
#' cpn_final <- read_csv("results/csv/CallsPerNight_final_v1.csv")
#' study_summary <- create_study_summary(cpn_final)
#' print(study_summary)
#' }
#'
#' @export
create_study_summary <- function(cpn_final) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(cpn_final)) {
    stop("cpn_final must be a data frame")
  }
  
  required_cols <- c("Detector", "Night", "CallsPerNight", 
                     "CallsPerHour", "RecordingHours", "Status")
  missing_cols <- setdiff(required_cols, names(cpn_final))
  
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "cpn_final is missing required columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
  }
  
  if (nrow(cpn_final) == 0) {
    stop("cpn_final is empty - no data to summarize")
  }
  
  # -------------------------
  # Calculate study-wide statistics
  # -------------------------
  
  study_start <- min(cpn_final$Night, na.rm = TRUE)
  study_end <- max(cpn_final$Night, na.rm = TRUE)
  
  summary_df <- dplyr::tibble(
    # Scope
    n_detectors = dplyr::n_distinct(cpn_final$Detector),
    n_detector_nights = nrow(cpn_final),
    study_start = study_start,
    study_end = study_end,
    study_duration_days = as.integer(study_end - study_start) + 1L,
    
    # Effort totals
    total_calls = sum(cpn_final$CallsPerNight, na.rm = TRUE),
    total_hours = round(sum(cpn_final$RecordingHours, na.rm = TRUE), 1),
    
    # Activity rates
    overall_mean_cph = round(mean(cpn_final$CallsPerHour, na.rm = TRUE), 2),
    overall_median_cph = round(median(cpn_final$CallsPerHour, na.rm = TRUE), 2),
    overall_sd_cph = round(sd(cpn_final$CallsPerHour, na.rm = TRUE), 2),
    overall_cv_pct = round(ifelse(
      mean(cpn_final$CallsPerHour, na.rm = TRUE) == 0,
      NA_real_,
      100 * sd(cpn_final$CallsPerHour, na.rm = TRUE) / 
        mean(cpn_final$CallsPerHour, na.rm = TRUE)
    ), 1),
    
    # Status breakdown
    pct_success = round(100 * sum(cpn_final$Status == "Success", na.rm = TRUE) / 
                          nrow(cpn_final), 1),
    pct_partial = round(100 * sum(cpn_final$Status == "Partial", na.rm = TRUE) / 
                          nrow(cpn_final), 1),
    pct_fail = round(100 * sum(cpn_final$Status == "Fail", na.rm = TRUE) / 
                       nrow(cpn_final), 1)
  )
  
  message(sprintf(
    "✓ Created study summary: %d detectors, %d nights, %s total calls",
    summary_df$n_detectors,
    summary_df$n_detector_nights,
    format(summary_df$total_calls, big.mark = ",")
  ))
  
  summary_df
}


# ------------------------------------------------------------------------------
# Variance Components (Descriptive)
# ------------------------------------------------------------------------------

#' Calculate Variance Components by Detector
#'
#' @description
#' Decomposes total variance in CallsPerHour into between-detector and
#' within-detector components. Purely descriptive — useful for understanding
#' whether detectors differ substantially from each other.
#'
#' @param cpn_final Data frame containing CallsPerNight final data with columns:
#'   - Detector: Unique identifier for each detector
#'   - CallsPerHour: Standardized activity rate
#'
#' @return Tibble with single row containing:
#'   \describe{
#'     \item{grand_mean}{Overall mean CallsPerHour across all data}
#'     \item{var_between}{Variance of detector means around grand mean}
#'     \item{var_within}{Mean of within-detector variances (pooled)}
#'     \item{var_total}{Total variance (var_between + var_within)}
#'     \item{pct_between}{Percent of total variance due to detector differences}
#'     \item{pct_within}{Percent of total variance due to night-to-night variation}
#'     \item{interpretation}{Plain-English description of what this means}
#'   }
#'
#' @details
#' **Interpretation guide:**
#' - High pct_between (>50%): Detectors differ substantially from each other.
#'   Some sites may have consistently higher or lower activity.
#' - High pct_within (>50%): Most variation is night-to-night fluctuation.
#'   Detectors behave similarly on average.
#'
#' @section CONTRACT:
#' - Returns exactly one row
#' - Purely descriptive calculation (no inference)
#' - Interpretation field uses plain English
#' - Returns tibble (not data.frame)
#'
#' @section DOES NOT:
#' - Perform ANOVA or hypothesis tests
#' - Calculate p-values or confidence intervals
#' - Make recommendations about model structure
#'
#' @examples
#' \dontrun{
#' cpn_final <- read_csv("results/csv/CallsPerNight_final_v1.csv")
#' variance_components <- calculate_variance_components(cpn_final)
#' print(variance_components$interpretation)
#' }
#'
#' @export
calculate_variance_components <- function(cpn_final) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(cpn_final)) {
    stop("cpn_final must be a data frame")
  }
  
  required_cols <- c("Detector", "CallsPerHour")
  missing_cols <- setdiff(required_cols, names(cpn_final))
  
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "cpn_final is missing required columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
  }
  
  if (nrow(cpn_final) == 0) {
    stop("cpn_final is empty - no data to analyze")
  }
  
  # -------------------------
  # Calculate grand mean
  # -------------------------
  
  grand_mean <- mean(cpn_final$CallsPerHour, na.rm = TRUE)
  
  # -------------------------
  # Calculate detector means
  # -------------------------
  
  detector_stats <- cpn_final %>%
    dplyr::filter(!is.na(CallsPerHour)) %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      det_mean = mean(CallsPerHour, na.rm = TRUE),
      det_var = var(CallsPerHour, na.rm = TRUE),
      det_n = dplyr::n(),
      .groups = "drop"
    )
  
  # -------------------------
  # Calculate variance components
  # -------------------------
  
  # Between-detector variance: variance of detector means
  var_between <- var(detector_stats$det_mean, na.rm = TRUE)
  
  # Within-detector variance: mean of within-detector variances
  # Exclude detectors with only 1 observation (var = NA)
  var_within <- mean(detector_stats$det_var, na.rm = TRUE)
  
  # Total variance (simple sum for descriptive purposes)
  var_total <- var_between + var_within
  
  # Percent of variance due to each component
  pct_between <- ifelse(var_total > 0, 
                        round(100 * var_between / var_total, 1), 
                        NA_real_)
  pct_within <- ifelse(var_total > 0, 
                       round(100 * var_within / var_total, 1), 
                       NA_real_)
  
  # -------------------------
  # Generate interpretation
  # -------------------------
  
  interpretation <- dplyr::case_when(
    is.na(pct_between) ~ "Insufficient data to calculate variance components",
    pct_between < 20 ~ "Low detector effect: Most variation is night-to-night within detectors. Detectors behave similarly on average.",
    pct_between < 50 ~ "Moderate detector effect: Some detectors have consistently higher or lower activity than others.",
    TRUE ~ "High detector effect: Detectors differ substantially. Site-level factors may strongly influence activity."
  )
  
  # -------------------------
  # Build output tibble
  # -------------------------
  
  result <- dplyr::tibble(
    grand_mean = round(grand_mean, 2),
    var_between = round(var_between, 4),
    var_within = round(var_within, 4),
    var_total = round(var_total, 4),
    pct_between = pct_between,
    pct_within = pct_within,
    interpretation = interpretation
  )
  
  message(sprintf(
    "✓ Variance decomposition: %.1f%% between-detector, %.1f%% within-detector",
    pct_between, pct_within
  ))
  
  result
}


# ==============================================================================
# NEW FUNCTIONS: From Master File (Row-Level Data)
# ==============================================================================


# ------------------------------------------------------------------------------
# Species Summary by Detector
# ------------------------------------------------------------------------------

#' Species Composition Summary by Detector
#'
#' @description
#' Summarizes species detected at each detector, including counts and
#' proportions. Uses auto_id as primary species identification.
#'
#' @param master Data frame containing Master file data with columns:
#'   - Detector: Unique identifier for each detector
#'   - auto_id: Species identification code (6-letter NABat format)
#'
#' @return Tibble with one row per Detector x Species combination containing:
#'   \describe{
#'     \item{Detector}{Detector name}
#'     \item{species}{Species code (auto_id)}
#'     \item{n_calls}{Number of calls for this species at this detector}
#'     \item{pct_of_detector}{Percent of detector's total calls}
#'     \item{pct_of_species}{Percent of species' total calls at this detector}
#'   }
#'
#' @details
#' **Species filtering:**
#' - Excludes "NoID", "UNKNOWN", NA, and blank auto_id values
#' - Only counts positively identified calls
#'
#' @section CONTRACT:
#' - Returns one row per Detector x Species combination
#' - Excludes unidentified calls (NoID, UNKNOWN, NA, blank)
#' - Proportions sum to 100% within each Detector
#' - Species codes preserved as-is (6-letter format)
#' - Returns tibble (not data.frame)
#'
#' @section DOES NOT:
#' - Validate species codes against NABat list
#' - Include manual_id (only uses auto_id)
#' - Make ecological interpretations
#' - Calculate diversity indices
#'
#' @examples
#' \dontrun{
#' master <- read_csv("outputs/02_Master_20241215_143022.csv")
#' species_summary <- create_species_summary_by_detector(master)
#'
#' # View top species per detector
#' species_summary %>%
#'   group_by(Detector) %>%
#'   slice_max(n_calls, n = 3)
#' }
#'
#' @export
create_species_summary_by_detector <- function(master) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(master)) {
    stop("master must be a data frame")
  }
  
  required_cols <- c("Detector", "auto_id")
  missing_cols <- setdiff(required_cols, names(master))
  
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "master is missing required columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
  }
  
  if (nrow(master) == 0) {
    stop("master is empty - no data to summarize")
  }
  
  # -------------------------
  # Define unidentified values to exclude
  # -------------------------
  
  unidentified_values <- c("NoID", "NOID", "noid", "UNKNOWN", "Unknown", 
                           "unknown", "", " ", NA_character_)
  
  # -------------------------
  # Filter to identified calls only
  # -------------------------
  
  identified_calls <- master %>%
    dplyr::filter(!auto_id %in% unidentified_values,
                  !is.na(auto_id),
                  nchar(trimws(auto_id)) > 0)
  
  if (nrow(identified_calls) == 0) {
    warning("No identified calls found in master data")
    return(dplyr::tibble(
      Detector = character(),
      species = character(),
      n_calls = integer(),
      pct_of_detector = numeric(),
      pct_of_species = numeric()
    ))
  }
  
  # -------------------------
  # Calculate detector totals
  # -------------------------
  
  detector_totals <- identified_calls %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      detector_total = dplyr::n(),
      .groups = "drop"
    )
  
  # -------------------------
  # Calculate species totals
  # -------------------------
  
  species_totals <- identified_calls %>%
    dplyr::group_by(auto_id) %>%
    dplyr::summarise(
      species_total = dplyr::n(),
      .groups = "drop"
    )
  
  # -------------------------
  # Calculate counts per Detector x Species
  # -------------------------
  
  summary_df <- identified_calls %>%
    dplyr::group_by(Detector, auto_id) %>%
    dplyr::summarise(
      n_calls = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::rename(species = auto_id) %>%
    # Join detector totals for pct_of_detector
    dplyr::left_join(detector_totals, by = "Detector") %>%
    dplyr::mutate(
      pct_of_detector = round(100 * n_calls / detector_total, 1)
    ) %>%
    dplyr::select(-detector_total) %>%
    # Join species totals for pct_of_species
    dplyr::left_join(species_totals, by = c("species" = "auto_id")) %>%
    dplyr::mutate(
      pct_of_species = round(100 * n_calls / species_total, 1)
    ) %>%
    dplyr::select(-species_total) %>%
    # Sort by Detector, then by n_calls descending
    dplyr::arrange(Detector, dplyr::desc(n_calls))
  
  n_species <- dplyr::n_distinct(summary_df$species)
  n_detectors <- dplyr::n_distinct(summary_df$Detector)
  
  message(sprintf(
    "✓ Created species summary: %d species across %d detectors",
    n_species, n_detectors
  ))
  
  summary_df
}


# ------------------------------------------------------------------------------
# Species Accumulation Summary
# ------------------------------------------------------------------------------

#' Species Accumulation Over Study Period
#'
#' @description
#' Calculates cumulative species richness over the study period.
#' Useful for assessing whether sampling effort was sufficient to
#' detect all species present.
#'
#' @param master Data frame containing Master file data with columns:
#'   - Detector: Unique identifier for each detector (optional, for per-detector)
#'   - Night: Study night date (or DateTime to extract from)
#'   - auto_id: Species identification code (6-letter NABat format)
#'
#' @param by_detector Logical. If TRUE, calculate accumulation per detector.
#'   If FALSE (default), calculate study-wide accumulation.
#'
#' @return Tibble containing:
#'   \describe{
#'     \item{Detector}{Detector name (only if by_detector = TRUE)}
#'     \item{Night}{Study night date}
#'     \item{night_number}{Sequential night number (1, 2, 3, ...)}
#'     \item{new_species}{Count of species first detected on this night}
#'     \item{cumulative_species}{Running total of unique species detected}
#'     \item{species_list}{Comma-separated list of new species (if any)}
#'   }
#'
#' @section CONTRACT:
#' - Excludes unidentified calls (NoID, UNKNOWN, NA, blank)
#' - Night numbering starts at 1
#' - Cumulative count never decreases
#' - Returns tibble (not data.frame)
#'
#' @section DOES NOT:
#' - Fit accumulation curve models
#' - Estimate total species richness
#' - Calculate confidence intervals
#'
#' @examples
#' \dontrun{
#' master <- read_csv("outputs/02_Master_20241215_143022.csv")
#'
#' # Study-wide accumulation
#' accum_overall <- create_species_accumulation_summary(master)
#'
#' # Per-detector accumulation
#' accum_by_detector <- create_species_accumulation_summary(master, by_detector = TRUE)
#' }
#'
#' @export
create_species_accumulation_summary <- function(master, by_detector = FALSE) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(master)) {
    stop("master must be a data frame")
  }
  
  required_cols <- c("auto_id")
  if (by_detector) required_cols <- c(required_cols, "Detector")
  
  missing_cols <- setdiff(required_cols, names(master))
  
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "master is missing required columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
  }
  
  # -------------------------
  # Determine Night column
  # -------------------------
  
  if ("Night" %in% names(master)) {
    # Use existing Night column
    master <- master %>%
      dplyr::mutate(Night = as.Date(Night))
  } else if ("DateTime" %in% names(master)) {
    # Derive Night from DateTime using noon boundary rule
    master <- master %>%
      dplyr::mutate(
        Night = dplyr::case_when(
          lubridate::hour(DateTime) < 12 ~ as.Date(DateTime) - 1L,
          TRUE ~ as.Date(DateTime)
        )
      )
  } else if ("Date" %in% names(master)) {
    # Use Date column as Night
    master <- master %>%
      dplyr::mutate(Night = as.Date(Date))
  } else {
    stop("master must have Night, DateTime, or Date column")
  }
  
  # -------------------------
  # Define unidentified values to exclude
  # -------------------------
  
  unidentified_values <- c("NoID", "NOID", "noid", "UNKNOWN", "Unknown", 
                           "unknown", "", " ", NA_character_)
  
  # -------------------------
  # Filter to identified calls
  # -------------------------
  
  identified_calls <- master %>%
    dplyr::filter(!auto_id %in% unidentified_values,
                  !is.na(auto_id),
                  nchar(trimws(auto_id)) > 0)
  
  if (nrow(identified_calls) == 0) {
    warning("No identified calls found in master data")
    return(dplyr::tibble())
  }
  
  # -------------------------
  # Calculate accumulation
  # -------------------------
  
  if (by_detector) {
    # Per-detector accumulation
    result <- identified_calls %>%
      dplyr::group_by(Detector) %>%
      dplyr::group_modify(~ calculate_accumulation_for_group(.x)) %>%
      dplyr::ungroup()
  } else {
    # Study-wide accumulation
    result <- calculate_accumulation_for_group(identified_calls)
  }
  
  message(sprintf(
    "✓ Created species accumulation summary: %d nights",
    dplyr::n_distinct(result$Night)
  ))
  
  result
}


#' Helper: Calculate Accumulation for a Single Group
#'
#' @description
#' Internal helper function to calculate species accumulation for a subset
#' of data (either entire study or single detector).
#'
#' @param df Data frame with Night and auto_id columns
#'
#' @return Tibble with accumulation data
#'
#' @keywords internal
calculate_accumulation_for_group <- function(df) {
  
  # Get unique species per night
  species_by_night <- df %>%
    dplyr::group_by(Night) %>%
    dplyr::summarise(
      species_detected = list(unique(auto_id)),
      .groups = "drop"
    ) %>%
    dplyr::arrange(Night)
  
  # Initialize tracking
  all_species_seen <- character()
  results <- list()
  
  for (i in seq_len(nrow(species_by_night))) {
    night <- species_by_night$Night[i]
    tonight_species <- species_by_night$species_detected[[i]]
    
    # Find new species (not seen before)
    new_species <- setdiff(tonight_species, all_species_seen)
    
    # Update running total
    all_species_seen <- union(all_species_seen, tonight_species)
    
    results[[i]] <- dplyr::tibble(
      Night = night,
      night_number = i,
      new_species = length(new_species),
      cumulative_species = length(all_species_seen),
      species_list = ifelse(length(new_species) > 0,
                            paste(sort(new_species), collapse = ", "),
                            NA_character_)
    )
  }
  
  dplyr::bind_rows(results)
}


# ------------------------------------------------------------------------------
# Hourly Activity Summary
# ------------------------------------------------------------------------------

#' Hourly Activity Profile Summary
#'
#' @description
#' Summarizes bat activity by hour of night. Creates hourly profiles
#' for the overall study and optionally per detector.
#'
#' @param master Data frame containing Master file data with columns:
#'   - Detector: Unique identifier for each detector
#'   - Hour: Hour of day (0-23) or DateTime to extract hour from
#'
#' @param by_detector Logical. If TRUE, calculate profiles per detector.
#'   If FALSE (default), calculate study-wide profile only.
#'
#' @return Tibble containing:
#'   \describe{
#'     \item{Detector}{Detector name (only if by_detector = TRUE)}
#'     \item{Hour}{Hour of day (0-23)}
#'     \item{n_calls}{Number of calls in this hour}
#'     \item{pct_of_total}{Percent of total calls in this hour}
#'   }
#'
#' @section CONTRACT:
#' - Returns one row per Hour (0-23) or per Detector x Hour
#' - All 24 hours included (even if zero calls)
#' - Proportions sum to 100%
#' - Returns tibble (not data.frame)
#'
#' @section DOES NOT:
#' - Adjust for sunrise/sunset times
#' - Account for recording schedule gaps
#' - Filter by species
#' - Create visualizations
#'
#' @examples
#' \dontrun{
#' master <- read_csv("outputs/02_Master_20241215_143022.csv")
#'
#' # Study-wide hourly profile
#' hourly_overall <- create_hourly_activity_summary(master)
#'
#' # Per-detector hourly profiles
#' hourly_by_detector <- create_hourly_activity_summary(master, by_detector = TRUE)
#' }
#'
#' @export
create_hourly_activity_summary <- function(master, by_detector = FALSE) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(master)) {
    stop("master must be a data frame")
  }
  
  if (nrow(master) == 0) {
    stop("master is empty - no data to summarize")
  }
  
  # -------------------------
  # Determine Hour column
  # -------------------------
  
  if ("Hour" %in% names(master)) {
    # Use existing Hour column
    master <- master %>%
      dplyr::mutate(Hour = as.integer(Hour))
  } else if ("DateTime" %in% names(master)) {
    # Extract Hour from DateTime
    master <- master %>%
      dplyr::mutate(Hour = lubridate::hour(DateTime))
  } else {
    stop("master must have Hour or DateTime column")
  }
  
  # -------------------------
  # Validate Detector column if needed
  # -------------------------
  
  if (by_detector && !"Detector" %in% names(master)) {
    stop("master must have Detector column when by_detector = TRUE")
  }
  
  # -------------------------
  # Create complete hour grid (0-23)
  # -------------------------
  
  all_hours <- dplyr::tibble(Hour = 0:23)
  
  # -------------------------
  # Calculate hourly summary
  # -------------------------
  
  if (by_detector) {
    # Per-detector hourly summary
    detectors <- unique(master$Detector)
    
    # Create complete grid: all detectors x all hours
    complete_grid <- tidyr::expand_grid(
      Detector = detectors,
      Hour = 0:23
    )
    
    # Count calls
    hourly_counts <- master %>%
      dplyr::group_by(Detector, Hour) %>%
      dplyr::summarise(
        n_calls = dplyr::n(),
        .groups = "drop"
      )
    
    # Calculate detector totals for percentages
    detector_totals <- master %>%
      dplyr::group_by(Detector) %>%
      dplyr::summarise(
        total_calls = dplyr::n(),
        .groups = "drop"
      )
    
    # Join and fill zeros
    result <- complete_grid %>%
      dplyr::left_join(hourly_counts, by = c("Detector", "Hour")) %>%
      dplyr::mutate(n_calls = dplyr::coalesce(n_calls, 0L)) %>%
      dplyr::left_join(detector_totals, by = "Detector") %>%
      dplyr::mutate(
        pct_of_total = round(100 * n_calls / total_calls, 1)
      ) %>%
      dplyr::select(-total_calls) %>%
      dplyr::arrange(Detector, Hour)
    
  } else {
    # Study-wide hourly summary
    hourly_counts <- master %>%
      dplyr::group_by(Hour) %>%
      dplyr::summarise(
        n_calls = dplyr::n(),
        .groups = "drop"
      )
    
    total_calls <- nrow(master)
    
    result <- all_hours %>%
      dplyr::left_join(hourly_counts, by = "Hour") %>%
      dplyr::mutate(
        n_calls = dplyr::coalesce(n_calls, 0L),
        pct_of_total = round(100 * n_calls / total_calls, 1)
      ) %>%
      dplyr::arrange(Hour)
  }
  
  # Find peak hour
  peak_hour <- result %>%
    dplyr::slice_max(n_calls, n = 1) %>%
    dplyr::pull(Hour) %>%
    `[`(1)
  
  message(sprintf(
    "✓ Created hourly activity summary (peak activity: %02d:00)",
    peak_hour
  ))
  
  result
}


# ==============================================================================
# END OF FILE
# ==============================================================================