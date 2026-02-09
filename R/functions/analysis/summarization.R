# =============================================================================
# UTILITY: summarization.R - Summary Statistics Generators (DETERMINISTIC)
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# - Provides statistical summary calculation functions
# - Used by modules in R/modules/
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
# DETERMINISTIC DESIGN PHILOSOPHY
# --------------------------------
# This module strictly follows the pipeline's deterministic philosophy:
#
# 1. NO AMBIGUOUS PARAMETERS
#    - Functions called once in the pipeline have ZERO configurable parameters
#    - Column names are FIXED (species, Night, Hour_local, Detector)
#    - No "what-if" logic or conditional branching
#
# 2. SCHEMA CONTRACT ENFORCEMENT
#    - All functions expect columns created by upstream workflows
#    - species column: created in Module 3 (run_phase2_template_generation)
#    - Hour_local column: created in Module 2 (run_phase1_data_preparation)
#    - Night column: created in Module 2 (run_phase1_data_preparation)
#
# 3. HELPER FUNCTIONS VS WORKFLOW FUNCTIONS
#    - Helper functions (reused multiple times): CAN have parameters
#    - Workflow functions (called once): NO configurable parameters
#    - save_master_with_timestamp() has parameters because it's a helper
#    - All summary functions have NO parameters because they're called once
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
#   - Have ambiguous parameters for single-use functions
#
# DEPENDENCIES
# ------------
#   - core/utilities.R: log_message
#   - validation/validation.R: validate_data_frame, validate_cpn_data,
#     assert_column_type, assert_columns_exist
#   - dplyr: group_by, summarize, across, n, n_distinct
#   - tidyr: pivot_wider (for species summaries)
#
# FUNCTIONS PROVIDED
# ------------------
#
# Detector-Level Summaries - Per-detector metrics and statistics:
#
#   - create_detector_activity_summary():
#       Uses packages: dplyr (group_by, summarize, across, n, n_distinct)
#       Calls internal: validation.R (validate_data_frame, validate_cpn_data,
#                       assert_column_type, assert_columns_exist),
#                       utilities.R (log_message)
#       Purpose: Generate comprehensive per-detector activity metrics
#
#   - calculate_coefficient_of_variation():
#       Uses packages: dplyr (mutate, across)
#       Calls internal: validation.R (assert_column_type)
#       Purpose: Calculate CV = sd/mean for each detector's hourly calls
#
#   - create_effort_summary_table():
#       Uses packages: dplyr (group_by, summarize, n_distinct)
#       Calls internal: validation.R (validate_data_frame)
#       Purpose: Summarize recording effort (night count, hour count) by detector
#
# Study-Wide Summaries - Aggregated statistics across all detectors:
#
#   - create_study_summary():
#       Uses packages: dplyr (summarize, n, n_distinct)
#       Calls internal: validation.R (validate_cpn_data)
#       Purpose: Generate single-row study-level overview statistics
#
#   - calculate_variance_components():
#       Uses packages: dplyr (group_by, summarize)
#       Calls internal: none (variance calculations via base R)
#       Purpose: Decompose variance into between-detector and within-detector components
#
# Species Analysis - Species composition summaries (DETERMINISTIC):
#
#   - create_species_summary_by_detector():
#       Uses packages: dplyr (group_by, summarize, across), tidyr (pivot_wider)
#       Calls internal: validation.R (assert_columns_exist)
#       Purpose: Species composition matrix per detector (requires species column)
#
#   - create_species_accumulation_summary():
#       Uses packages: dplyr (group_by, summarize, n_distinct), tidyr (pivot_wider)
#       Calls internal: validation.R (assert_columns_exist)
#       Purpose: Cumulative species richness over time (requires species column)
#
# Temporal Analysis - Time-based activity patterns (DETERMINISTIC):
#
#   - create_hourly_activity_summary():
#       Uses packages: dplyr (group_by, summarize, n)
#       Calls internal: validation.R (assert_columns_exist)
#       Purpose: Activity by hour of night (requires Hour_local column)
#
# File I/O - Timestamp-based file saving (HELPER function):
#
#   - save_master_with_timestamp():
#       Uses packages: readr (write_csv), base R (file.path, format, Sys.time)
#       Calls internal: utilities.R (make_output_path)
#       Purpose: Save data frame with ISO timestamp appended to filename
#
# USAGE
# -----
# # After loading CallsPerNight final data and kpro_master
# cpn_final <- load_cpn_final()
# kpro_master <- load_most_recent_checkpoint("^02_kpro_master_.*\\.csv$")
#
# # CRITICAL: kpro_master must have these columns created upstream:
# #   - species: created in Module 3 via create_unified_species_column()
# #   - Hour_local: created in Module 2 via add_temporal_columns()
# #   - Night: created in Module 2 via standardization
#
# # Generate summaries (deterministic - no parameters)
# detector_summary <- create_detector_activity_summary(cpn_final)
# study_summary <- create_study_summary(cpn_final)
# species_summary <- create_species_summary_by_detector(kpro_master)
# species_accum <- create_species_accumulation_summary(kpro_master)
# hourly_summary <- create_hourly_activity_summary(kpro_master)
#
# # Format as GT tables
# detector_gt <- format_detector_summary_gt(detector_summary)
# study_gt <- format_study_summary_gt(study_summary)
#
# Last Modified: 2026-02-09
#
# CHANGELOG
# ---------
# 2026-02-05: DETERMINISTIC REFACTOR - Removed all ambiguous parameters
#             - create_species_summary_by_detector(): removed species_col parameter
#             - create_species_accumulation_summary(): removed species_col and date_col parameters
#             - create_hourly_activity_summary(): removed by_detector parameter
#             - Removed all conditional logic for column detection
#             - Enforces schema contract: species, Night, Hour_local must exist
#             - Updated module header with DETERMINISTIC DESIGN PHILOSOPHY section
#             - All functions now expect deterministically-created columns from upstream
# 2026-02-05: DOCUMENTATION FIX - Updated header to match 02_documentation_standards.md
# 2026-02-01: Verified deterministic behavior - all functions follow standards
# 2024-12-29: Added new summary functions for Module 5
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
#' activity metrics (both per-night and per-hour), and variability metrics.
#' This is the primary summary for assessing detector performance and bat 
#' activity patterns.
#' 
#' Handles edge cases gracefully: detectors with all-NA CallsPerHour values
#' (e.g., all failed nights) will have NA for CPH metrics rather than Inf/-Inf.
#' This ensures downstream plotting and table generation functions don't break.
#'
#' @param cpn_final Data frame. CallsPerNight final data from Workflow 04.
#'   Must contain columns: Detector, Night, CallsPerNight, RecordingHours, 
#'   Status, CallsPerHour.
#'
#' @return Tibble with one row per detector and the following columns:
#'   \describe{
#'     \item{Detector}{Character. Detector name}
#'     \item{n_nights}{Integer. Number of nights in study period}
#'     \item{total_hours}{Numeric. Total recording hours (1 decimal)}
#'     \item{mean_hours}{Numeric. Mean hours per night (1 decimal)}
#'     \item{pct_success}{Numeric. Percent of nights with full recording (1 decimal)}
#'     \item{pct_partial}{Numeric. Percent of nights with partial recording (1 decimal)}
#'     \item{pct_fail}{Numeric. Percent of nights with no recording (1 decimal)}
#'     \item{total_calls}{Numeric. Total bat calls detected}
#'     \item{mean_cpn}{Numeric. Mean calls per night (1 decimal)}
#'     \item{median_cpn}{Numeric. Median calls per night (1 decimal)}
#'     \item{sd_cpn}{Numeric. Standard deviation of calls per night (1 decimal)}
#'     \item{min_cpn}{Numeric. Minimum calls per night (1 decimal)}
#'     \item{max_cpn}{Numeric. Maximum calls per night (1 decimal)}
#'     \item{mean_cph}{Numeric. Mean calls per hour (2 decimals, NA if all CallsPerHour are NA)}
#'     \item{median_cph}{Numeric. Median calls per hour (2 decimals, NA if all CallsPerHour are NA)}
#'     \item{sd_cph}{Numeric. Standard deviation of calls per hour (2 decimals, NA if all CallsPerHour are NA)}
#'     \item{min_cph}{Numeric. Minimum calls per hour (2 decimals, NA if all CallsPerHour are NA)}
#'     \item{max_cph}{Numeric. Maximum calls per hour (2 decimals, NA if all CallsPerHour are NA)}
#'     \item{cv_pct}{Numeric. Coefficient of variation in CPH as percentage (1 decimal). Measures relative variability: Low CV (~20%) = consistent activity, High CV (~100%+) = highly variable. NA if all CallsPerHour are NA or mean is 0}
#'     \item{pct_zero}{Numeric. Percent of nights with zero calls (1 decimal). Detector recorded but no bats detected. Different from pct_fail (equipment failure)}
#'     \item{first_night}{Date. First night of recording}
#'     \item{last_night}{Date. Last night of recording}
#'   }
#'
#' @section CONTRACT:
#' - Returns one row per detector, ordered alphabetically by Detector
#' - All metrics calculated with na.rm = TRUE
#' - Percentages on 0-100 scale
#' - CV calculated as (sd/mean) * 100 for CallsPerHour
#' - pct_zero based on CallsPerNight (nights with 0 calls but RecordingHours > 0)
#' - pct_fail based on Status column (nights with Fail status)
#' - Handles all-NA CallsPerHour gracefully (returns NA instead of Inf/-Inf)
#' - Input validation enforced via validate_cpn_data()
#'
#' @section DOES NOT:
#' - Make ecological interpretations
#' - Filter out any detectors (even those with all failures)
#' - Modify input data
#' - Perform statistical inference or hypothesis testing
#' - Sort output (returns in group_by order, typically alphabetical)
#'
#' @section Dependencies:
#' - validation/validation.R: validate_cpn_data()
#' - dplyr: group_by(), summarise(), n()
#'
#' @examples
#' \dontrun{
#' cpn_final <- load_cpn_final()
#' detector_summary <- create_detector_activity_summary(cpn_final)
#' 
#' # Check for detectors with all failures
#' detector_summary %>% filter(pct_fail == 100)
#' 
#' # Identify high-variability sites
#' detector_summary %>% filter(cv_pct > 100)
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
      
      # Activity metrics - Calls Per Night
      total_calls = sum(CallsPerNight, na.rm = TRUE),
      mean_cpn = round(mean(CallsPerNight, na.rm = TRUE), 1),
      median_cpn = round(median(CallsPerNight, na.rm = TRUE), 1),
      sd_cpn = round(sd(CallsPerNight, na.rm = TRUE), 1),
      min_cpn = round(min(CallsPerNight, na.rm = TRUE), 1),
      max_cpn = round(max(CallsPerNight, na.rm = TRUE), 1),
      
      # Activity metrics - Calls Per Hour (handle all-NA case)
      mean_cph = if (all(is.na(CallsPerHour))) {
        NA_real_
      } else {
        round(mean(CallsPerHour, na.rm = TRUE), 2)
      },
      median_cph = if (all(is.na(CallsPerHour))) {
        NA_real_
      } else {
        round(median(CallsPerHour, na.rm = TRUE), 2)
      },
      sd_cph = if (all(is.na(CallsPerHour))) {
        NA_real_
      } else {
        round(sd(CallsPerHour, na.rm = TRUE), 2)
      },
      min_cph = if (all(is.na(CallsPerHour))) {
        NA_real_
      } else {
        round(min(CallsPerHour, na.rm = TRUE), 2)
      },
      max_cph = if (all(is.na(CallsPerHour))) {
        NA_real_
      } else {
        round(max(CallsPerHour, na.rm = TRUE), 2)
      },
      
      # Variability metrics (handle all-NA and zero-mean cases)
      cv_pct = if (all(is.na(CallsPerHour))) {
        NA_real_
      } else {
        mean_val <- mean(CallsPerHour, na.rm = TRUE)
        sd_val <- sd(CallsPerHour, na.rm = TRUE)
        if (is.na(mean_val) || is.nan(mean_val) || mean_val == 0) {
          NA_real_
        } else {
          round(100 * sd_val / mean_val, 1)
        }
      },
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
#'     \item{overall_mean_cpn}{Mean calls per night (study-wide)}
#'     \item{overall_median_cpn}{Median calls per night}
#'     \item{overall_sd_cpn}{Standard deviation of CPN}
#'     \item{overall_min_cpn}{Minimum calls per night}
#'     \item{overall_max_cpn}{Maximum calls per night}
#'     \item{overall_mean_cph}{Mean calls per hour (study-wide)}
#'     \item{overall_median_cph}{Median calls per hour}
#'     \item{overall_sd_cph}{Standard deviation of CPH}
#'     \item{overall_min_cph}{Minimum calls per hour}
#'     \item{overall_max_cph}{Maximum calls per hour}
#'     \item{overall_cv_pct}{Coefficient of variation in CPH. Low (~20%) = consistent, High (~100%+) = variable}
#'     \item{pct_success}{Percent detector-nights with full recording}
#'     \item{pct_partial}{Percent with partial recording}
#'     \item{pct_fail}{Percent with no recording (equipment failure)}
#'   }
#'
#' @section CONTRACT:
#' - Returns exactly one row
#' - Aggregates across ALL detectors
#' - CV calculated as (sd/mean) * 100 for CallsPerHour
#' - All percentages sum to 100 (Success + Partial + Fail)
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
    
    # Calls Per Night metrics
    overall_mean_cpn = round(mean(cpn_final$CallsPerNight, na.rm = TRUE), 1),
    overall_median_cpn = round(median(cpn_final$CallsPerNight, na.rm = TRUE), 1),
    overall_sd_cpn = round(sd(cpn_final$CallsPerNight, na.rm = TRUE), 1),
    overall_min_cpn = round(min(cpn_final$CallsPerNight, na.rm = TRUE), 1),
    overall_max_cpn = round(max(cpn_final$CallsPerNight, na.rm = TRUE), 1),
    
    # Calls Per Hour metrics
    overall_mean_cph = round(mean(cpn_final$CallsPerHour, na.rm = TRUE), 2),
    overall_median_cph = round(median(cpn_final$CallsPerHour, na.rm = TRUE), 2),
    overall_sd_cph = round(sd(cpn_final$CallsPerHour, na.rm = TRUE), 2),
    overall_min_cph = round(min(cpn_final$CallsPerHour, na.rm = TRUE), 2),
    overall_max_cph = round(max(cpn_final$CallsPerHour, na.rm = TRUE), 2),
    overall_cv_pct = round(100 * overall_sd_cph / overall_mean_cph, 1),
    
    # Recording status percentages
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
#'     \item{interpretation}{Plain-English interpretation of spatial heterogeneity}
#'   }
#'
#' @section CONTRACT:
#' - Returns single row
#' - ICC = var_between / var_total
#' - pct_between + pct_within = 100 (approximately)
#' - Interpretation based on ICC thresholds
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
  
  # Calculate ICC
  icc <- var_between / var_total
  
  # Generate interpretation based on ICC
  interpretation <- dplyr::case_when(
    icc >= 0.75 ~ "Very high spatial heterogeneity (most variation between sites)",
    icc >= 0.50 ~ "High spatial heterogeneity (more variation between than within sites)",
    icc >= 0.25 ~ "Moderate spatial heterogeneity (balanced spatial and temporal variation)",
    icc >= 0.10 ~ "Low spatial heterogeneity (more variation within sites over time)",
    TRUE ~ "Very low spatial heterogeneity (most variation is temporal)"
  )
  
  tibble::tibble(
    var_total = round(var_total, 2),
    var_between = round(var_between, 2),
    var_within = round(var_within, 2),
    pct_between = round(100 * var_between / var_total, 1),
    pct_within = round(100 * var_within / var_total, 1),
    icc = round(icc, 3),
    interpretation = interpretation
  )
}


# ==============================================================================
# SPECIES ANALYSIS
# ==============================================================================


#' Create Species Summary by Detector
#'
#' @description
#' Summarizes species composition for each detector using the unified 'species'
#' column created by Workflow 03. Shows call counts and percentages for each
#' species detected.
#' 
#' DETERMINISTIC DESIGN: This function has NO configurable parameters. It
#' always uses the 'species' column created by create_unified_species_column()
#' in Workflow 03, which deterministically applies priority: manual_id > auto_id > "NoID".
#'
#' @param master_data Data frame. Master file from Workflow 02 with unified
#'   species column added by Workflow 03. Must contain Detector and species columns.
#'
#' @return Tibble with columns:
#'   \describe{
#'     \item{Detector}{Detector name}
#'     \item{species}{Species code from unified column}
#'     \item{n_calls}{Number of calls}
#'     \item{pct_of_detector}{Percent of detector's total calls}
#'   }
#'
#' @section CONTRACT:
#' - One row per detector-species combination
#' - Uses ONLY the 'species' column (no configurable column names)
#' - Species column MUST pre-exist (created in Workflow 03)
#' - Excludes NA species values
#' - Percentages sum to 100 within each detector
#' - Sorted by Detector, then n_calls descending
#' - DETERMINISTIC: no configurable parameters, no conditional logic
#'
#' @section DOES NOT:
#' - Create the species column (expects it pre-created in Workflow 03)
#' - Accept alternate species column names (violates determinism)
#' - Make species richness comparisons
#' - Account for detection probability
#' - Have any configurable behavior
#'
#' @examples
#' \dontrun{
#' # Species column must be created first by Workflow 03
#' kpro_master <- create_unified_species_column(kpro_master)
#' 
#' # Then generate summary (no parameters needed)
#' species_summary <- create_species_summary_by_detector(kpro_master)
#' }
#'
#' @export
create_species_summary_by_detector <- function(master_data) {
  
  # Input validation - species column MUST exist
  validate_master_data(master_data)
  assert_columns_exist(master_data, c("Detector", "species"))
  
  # Summarize by detector and species (deterministic - no parameters)
  master_data %>%
    dplyr::filter(!is.na(species)) %>%
    dplyr::group_by(Detector, species) %>%
    dplyr::summarise(
      n_calls = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::group_by(Detector) %>%
    dplyr::mutate(
      pct_of_detector = round(100 * n_calls / sum(n_calls), 1)
    ) %>%
    dplyr::ungroup() %>%
    dplyr::arrange(Detector, dplyr::desc(n_calls))
}


#' Create Species Accumulation Summary
#'
#' @description
#' Shows cumulative species count over time using the unified 'species' column
#' created by Workflow 03 and the 'Night' column created by Workflow 02.
#' Useful for assessing whether sampling effort was sufficient to detect most species.
#' 
#' DETERMINISTIC DESIGN: This function has NO configurable parameters. It
#' always uses 'species' and 'Night' columns created deterministically by
#' upstream workflows.
#'
#' @param master_data Data frame. Master file with Night column and unified
#'   species column. Must contain species and Night columns.
#'
#' @return Tibble with columns:
#'   \describe{
#'     \item{Night}{Date}
#'     \item{new_species}{Number of new species detected that date}
#'     \item{cumulative_species}{Running total of unique species}
#'     \item{new_species_list}{Character, comma-separated new species}
#'   }
#'
#' @section CONTRACT:
#' - One row per date with detections
#' - Uses ONLY 'species' and 'Night' columns (no configurable column names)
#' - Both columns MUST pre-exist (created in Workflows 02-03)
#' - Excludes NoID/UNKNOWN/NOISE from species counts
#' - cumulative_species is monotonically increasing
#' - Returns Night column for consistency with workflow
#' - DETERMINISTIC: no configurable parameters, no conditional logic
#'
#' @section DOES NOT:
#' - Create the species or Night columns (expects them pre-created)
#' - Accept alternate column names (violates determinism)
#' - Check for column type (Night is always Date, not POSIXt)
#' - Account for detection probability
#' - Weight by effort
#'
#' @examples
#' \dontrun{
#' # Species and Night columns must exist from upstream workflows
#' species_accum <- create_species_accumulation_summary(kpro_master)
#' }
#'
#' @export
create_species_accumulation_summary <- function(master_data) {
  
  # Input validation - species and Night columns MUST exist
  validate_master_data(master_data)
  assert_columns_exist(master_data, c("species", "Night"))
  
  # Exclude unidentified species (deterministic - no parameter)
  valid_species <- master_data %>%
    dplyr::filter(
      !is.na(species),
      !species %in% c("NoID", "UNKNOWN", "NOISE", "")
    )
  
  # Get first detection date for each species
  first_detections <- valid_species %>%
    dplyr::group_by(species) %>%
    dplyr::summarise(
      first_date = min(Night, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Accumulate by date
  accumulation <- first_detections %>%
    dplyr::group_by(Night = first_date) %>%
    dplyr::summarise(
      new_species = dplyr::n(),
      new_species_list = paste(species, collapse = ", "),
      .groups = "drop"
    ) %>%
    dplyr::arrange(Night) %>%
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
#' Summarizes bat activity by hour of the night using the Hour_local column
#' created by Workflow 02. Provides study-wide hourly activity patterns.
#' 
#' DETERMINISTIC DESIGN: This function has NO configurable parameters. It
#' always uses the 'Hour_local' column created deterministically in Workflow 02,
#' and always returns study-wide summaries (not per-detector).
#'
#' @param master_data Data frame. Master file with Hour_local column.
#'   Must contain Hour_local column.
#'
#' @return Tibble with columns:
#'   \describe{
#'     \item{Hour_local}{Hour of day (0-23)}
#'     \item{n_calls}{Number of calls in that hour}
#'     \item{pct_of_total}{Percent of total calls}
#'   }
#'
#' @section CONTRACT:
#' - One row per hour (0-23)
#' - Uses ONLY Hour_local column (no conditional DateTime extraction)
#' - Hour_local MUST pre-exist (created in Workflow 02)
#' - Returns study-wide summary (not per-detector)
#' - Percentages sum to 100
#' - DETERMINISTIC: no configurable parameters, no conditional logic
#'
#' @section DOES NOT:
#' - Create Hour_local column (expects it pre-created in Workflow 02)
#' - Extract hours from DateTime_local (Hour_local must exist)
#' - Provide per-detector breakdown (single output schema only)
#' - Account for recording effort differences between hours
#' - Adjust for seasonal variation in night length
#'
#' @examples
#' \dontrun{
#' # Hour_local column must exist from Workflow 02
#' hourly_summary <- create_hourly_activity_summary(kpro_master)
#' 
#' # Identify peak activity hours
#' hourly_summary %>% filter(pct_of_total > 10)
#' }
#'
#' @export
create_hourly_activity_summary <- function(master_data) {
  
  # Input validation - Hour_local MUST exist
  validate_master_data(master_data)
  assert_columns_exist(master_data, "Hour_local")
  
  # Calculate study-wide hourly summary (deterministic - no parameters)
  master_data %>%
    dplyr::group_by(Hour_local) %>%
    dplyr::summarise(
      n_calls = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      pct_of_total = round(100 * n_calls / sum(n_calls), 1)
    ) %>%
    dplyr::arrange(Hour_local)
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