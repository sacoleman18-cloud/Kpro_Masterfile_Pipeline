# ==============================================================================
# MODULE: data_standardization.R
# ==============================================================================
# 
# Classification: Processing Module
# Subtitle: Schema transformation, detector mapping, timezone conversion, and data filtering
#
# Description:
# This module handles the complete data standardization process for the KPro pipeline.
# It transforms multiple schema versions to unified format, applies detector mappings,
# converts timestamps to local timezone, performs optional deduplication, and applies
# configured data filters.
#
# Module Stages:
#   Stage 3: Schema transformation (v1/v2/v3 → unified master)
#   Stage 4: Detector mapping (ID → friendly names)
#   Stage 5: Timezone conversion (UTC → local)
#   Stage 6: Finalize schema and optional deduplication
#   Stage 7: Apply configured data filters (NoID, zero-pulse)
#   Stage 8: Save checkpoint, register artifact, render validation HTML
#
# Data Flow:
#   Input:  Raw combined data from ingestion module
#   Output: Standardized kpro_master tibble ready for analysis
#
# Dependencies:
#   - R/functions/standardization/standardization.R (standardize_kpro_schema)
#   - R/functions/standardization/datetime_helpers.R (convert_datetime_to_local)
#   - R/functions/validation/validation.R (enforce_unified_schema, finalize_master_columns, log_validation_event)
#   - R/functions/core/orchestration_helpers.R (log_stage_start, save_checkpoint_and_register, finalize_stage_validation_report)
#   - R/functions/core/utilities.R (hash_dataframe)
#   - R/functions/core/logging.R (log_message)
#
# Functions Provided:
#   - module_data_standardization(): Main module function (exported)
#     Used by: R/modules/module_runner.R (run_module_standardization)
#     Used by: R/pipeline/run_phase1_data_preparation.R
#
# Last Modified: 2026-02-09
# Changelog:
#   2026-02-09: Updated dependencies to reference orchestration_helpers.R
#   2026-02-08: Created as part of pipeline modularization refactor
#
# ==============================================================================

#' Standardize Raw Data into Analysis-Ready Master File
#'
#' @description
#' Module Stages 3-8: Transforms raw data into unified schema, applies mappings
#' and filters, and saves analysis-ready master file with full validation.
#'
#' @param raw_data Tibble. Combined raw data from ingestion module.
#' @param study_params List. Study parameters from load_study_parameters().
#' @param validation_context Validation context object from ingestion module.
#' @param ingestion_metadata List. Metadata from ingestion module (for tracking).
#' @param verbose Logical. Whether to print detailed progress messages.
#'   Default FALSE (silent operation).
#'
#' @return Named list containing:
#'   \itemize{
#'     \item \code{standardization}: List with kpro_master, metadata, artifact_id, and checkpoint_path
#'     \item \code{validation_html_paths}: Character vector of validation HTML paths
#'   }
#'
#' @examples
#' \dontrun{
#' ingestion_result <- module_data_ingestion(verbose = TRUE)
#' result <- module_data_standardization(
#'   raw_data = ingestion_result$raw_data,
#'   study_params = ingestion_result$study_params,
#'   validation_context = ingestion_result$validation_context,
#'   ingestion_metadata = ingestion_result$metadata,
#'   verbose = TRUE
#' )
#' kpro_master <- result$standardization$kpro_master
#' }
#'
#' @export
module_data_standardization <- function(raw_data,
                                        study_params,
                                        validation_context,
                                        ingestion_metadata,
                                        verbose = FALSE) {
  
  # ===========================================================================
  # INITIALIZATION
  # ===========================================================================
  
  print_stage_banner("DATA STANDARDIZATION", verbose = verbose)
  
  result <- list(
    standardization = list(),
    validation_html_paths = character()
  )
  
  # ===========================================================================
  # STAGE 3: SCHEMA TRANSFORMATION
  # ===========================================================================
  
  log_stage_start("3", "Schema Transformation", verbose = verbose,
                  phase_prefix = "Data Standardization")
  
  # Capture schema distribution before transformation
  schema_before <- table(raw_data$schema_version)
  
  # Transform all schemas to unified format
  unified_data <- standardize_kpro_schema(raw_data, verbose = verbose)
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "schema_transform",
    description = "Unified schema versions",
    details = list(
      v1_rows = as.numeric(schema_before["v1_legacy_single_column"] %||% 0),
      v2_rows = as.numeric(schema_before["v2_transitional_4letter"] %||% 0),
      v3_rows = as.numeric(schema_before["v3_modern_6letter"] %||% 0),
      unknown_rows = as.numeric(schema_before["unknown"] %||% 0),
      output_rows = nrow(unified_data)
    )
  )
  
  if (verbose) message("  [OK] Schema transformation complete")
  
  log_message(sprintf("[Stage 3] Schema transformation complete: %d rows", nrow(unified_data)))
  
  # ===========================================================================
  # STAGE 4: DETECTOR MAPPING
  # ===========================================================================
  
  log_stage_start("4", "Detector Mapping", verbose = verbose,
                  phase_prefix = "Data Standardization")
  
  # Get detector mapping from configuration
  detector_mapping <- study_params$study_parameters$detector_mapping
  
  if (!is.null(detector_mapping) && length(detector_mapping) > 0) {
    # Convert to tibble for join
    mapping_df <- tibble::tibble(
      detector_id = names(detector_mapping),
      Detector = unlist(detector_mapping)
    )
    
    # Replace placeholders with detector_id
    mapping_df <- mapping_df %>%
      dplyr::mutate(
        Detector = dplyr::if_else(
          Detector == "ENTER_NAME_HERE",
          detector_id,
          Detector
        )
      )
    
    # Join mapping
    unified_data <- unified_data %>%
      dplyr::left_join(mapping_df, by = "detector_id")
    
    # Fill any unmapped with detector_id (no interactive prompts)
    unmapped_count <- sum(is.na(unified_data$Detector))
    if (unmapped_count > 0) {
      unified_data <- unified_data %>%
        dplyr::mutate(Detector = dplyr::coalesce(Detector, detector_id))
      
      if (verbose) {
        message(sprintf("  [!] %d rows unmapped - using detector_id as Detector", unmapped_count))
      }
    }
    
  } else {
    # No mapping configured - use detector_id directly
    unified_data$Detector <- unified_data$detector_id
    
    if (verbose) message("  [!] No detector mapping configured - using detector_id")
  }
  
  n_detectors <- dplyr::n_distinct(unified_data$Detector)
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "detector_mapping",
    description = sprintf("Mapped %d detectors", n_detectors),
    count = n_detectors,
    details = list(
      detectors = unique(unified_data$Detector)
    )
  )
  
  if (verbose) message(sprintf("  [OK] Mapped %d detectors", n_detectors))
  
  log_message(sprintf("[Stage 4] Detector mapping: %d detectors", n_detectors))
  
  # ===========================================================================
  # STAGE 5: TIME CONVERSION
  # ===========================================================================
  
  log_stage_start("5", "Time Conversion", verbose = verbose,
                  phase_prefix = "Data Standardization")
  
  target_tz <- study_params$study_parameters$timezone
  
  unified_data <- convert_datetime_to_local(
    df = unified_data,
    target_tz = target_tz,
    date_col = "date",
    time_col = "time",
    source_tz = "UTC",
    verbose = verbose
  )
  
  # Get date range for metadata
  date_range <- range(unified_data$DateTime_local, na.rm = TRUE)
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "timezone_conversion",
    description = sprintf("Converted UTC -> %s", target_tz),
    details = list(
      source_tz = "UTC",
      target_tz = target_tz,
      date_start = as.character(date_range[1]),
      date_end = as.character(date_range[2])
    )
  )
  
  if (verbose) message(sprintf("  [OK] Converted timestamps to %s", target_tz))
  
  log_message(sprintf("[Stage 5] Converted times to %s", target_tz))
  
  # ===========================================================================
  # STAGE 6: FINALIZE & OPTIONAL DEDUPLICATION
  # ===========================================================================
  
  log_stage_start("6", "Finalize & Deduplicate", verbose = verbose,
                  phase_prefix = "Data Standardization")
  
  # Enforce unified schema (using validation.R function)
  kpro_master <- enforce_unified_schema(unified_data)
  
  # Finalize column order and remove unwanted columns
  kpro_master <- finalize_master_columns(kpro_master, verbose = verbose)
  
  # -------------------------
  # Optional deduplication (configurable via YAML)
  # -------------------------
  
  # Read dedupe configuration (default TRUE for backward compatibility)
  remove_duplicates <- study_params$study_parameters$data_filters$remove_duplicates %||% TRUE
  
  n_duplicates <- 0
  
  if (remove_duplicates) {
    if (verbose) message("  [!] Applying deduplication...")
    
    n_before <- nrow(kpro_master)
    
    kpro_master <- kpro_master %>%
      dplyr::distinct(Detector, DateTime_local, auto_id, .keep_all = TRUE)
    
    n_duplicates <- n_before - nrow(kpro_master)
    
    if (n_duplicates > 0) {
      validation_context <- log_validation_event(
        validation_context,
        event_type = "duplicate",
        description = "Removed duplicate detections",
        count = n_duplicates,
        details = list(
          keys = c("Detector", "DateTime_local", "auto_id"),
          rows_before = n_before,
          rows_after = nrow(kpro_master),
          percent_removed = round(100 * n_duplicates / n_before, 2)
        )
      )
      
      if (verbose) {
        message(sprintf("  [OK] Removed %s duplicates", 
                        format(n_duplicates, big.mark = ",")))
      }
    } else {
      if (verbose) message("  [OK] No duplicates found")
    }
  } else {
    if (verbose) message("  [!] Deduplication disabled - retaining all rows")
  }
  
  if (verbose) {
    message(sprintf("  [OK] Final dataset: %s rows", 
                    format(nrow(kpro_master), big.mark = ",")))
  }
  
  log_message(sprintf("[Stage 6] Finalization: %d rows after deduplication", nrow(kpro_master)))
  
  # ===========================================================================
  # STAGE 7: DATA FILTERS
  # ===========================================================================
  
  log_stage_start("7", "Data Filters", verbose = verbose,
                  phase_prefix = "Data Standardization")
  
  # Read filter configuration from YAML (with defensive defaults)
  data_filters <- study_params$study_parameters$data_filters
  remove_noid <- data_filters$remove_noid %||% FALSE
  remove_zero_pulse <- data_filters$remove_zero_pulse_calls %||% FALSE
  
  # Initialize filter counters
  n_noid_removed <- 0
  n_zero_removed <- 0
  
  # -------------------------
  # Filter 1: NoID exclusion
  # -------------------------
  
  if (remove_noid) {
    if (verbose) message("  [!] Applying NoID filter...")
    
    n_before <- nrow(kpro_master)
    kpro_master <- kpro_master %>%
      dplyr::filter(auto_id != "NoID" | is.na(auto_id))
    
    n_noid_removed <- n_before - nrow(kpro_master)
    
    if (n_noid_removed > 0) {
      validation_context <- log_validation_event(
        validation_context,
        event_type = "filter_noid",
        description = "Removed NoID detections",
        count = n_noid_removed,
        details = list(
          filter = "NoID exclusion",
          rows_before = n_before,
          rows_removed = n_noid_removed,
          rows_after = nrow(kpro_master),
          percent_removed = round(100 * n_noid_removed / n_before, 2)
        )
      )
      
      if (verbose) {
        message(sprintf("  [OK] Removed %s NoID rows", 
                        format(n_noid_removed, big.mark = ",")))
      }
    } else {
      if (verbose) message("  [OK] No NoID rows to remove")
    }
  }
  
  # -------------------------
  # Filter 2: Zero-pulse exclusion
  # -------------------------
  
  if (remove_zero_pulse) {
    if (verbose) message("  [!] Applying zero-pulse filter...")
    
    n_before <- nrow(kpro_master)
    kpro_master <- kpro_master %>%
      dplyr::filter(pulses > 0 & !is.na(pulses))
    
    n_zero_removed <- n_before - nrow(kpro_master)
    
    if (n_zero_removed > 0) {
      validation_context <- log_validation_event(
        validation_context,
        event_type = "filter_zero_pulses",
        description = "Removed zero-pulse calls",
        count = n_zero_removed,
        details = list(
          filter = "Zero/NA pulse exclusion",
          rows_before = n_before,
          rows_removed = n_zero_removed,
          rows_after = nrow(kpro_master),
          percent_removed = round(100 * n_zero_removed / n_before, 2)
        )
      )
      
      if (verbose) {
        message(sprintf("  [OK] Removed %s zero-pulse rows", 
                        format(n_zero_removed, big.mark = ",")))
      }
    } else {
      if (verbose) message("  [OK] No zero-pulse rows to remove")
    }
  }
  
  if (remove_noid || remove_zero_pulse) {
    log_message(sprintf("[Stage 7] Data filters: %d NoID, %d zero-pulse removed",
                        n_noid_removed, n_zero_removed))
  }
  
  # ===========================================================================
  # STAGE 8: SAVE, REGISTER & VALIDATE
  # ===========================================================================
  
  log_stage_start("8", "Save, Register & Validate", verbose = verbose,
                  phase_prefix = "Data Standardization")
  
  # Generate timestamped checkpoint filename
  checkpoint_filename <- generate_timestamped_filename("02_kpro_master")
  checkpoint_path <- here::here("outputs", "checkpoints", checkpoint_filename)
  
  # Compute deterministic hash of data content
  data_hash <- hash_dataframe(kpro_master, 
                              sort_by = c("Detector", "DateTime_local", "auto_id"))
  
  # Generate artifact ID
  artifact_id <- sub("\\.csv$", "", generate_timestamped_filename("kpro_master"))
  
  # Save checkpoint and register artifact
  registry <- save_checkpoint_and_register(
    data = kpro_master,
    file_path = checkpoint_path,
    artifact_name = artifact_id,
    artifact_type = "masterfile",
    phase_id = "standardize",
    data_hash = data_hash,
    metadata = list(
      n_rows_final = nrow(kpro_master),
      n_rows_removed_invalid = ingestion_metadata$rows_removed_invalid,
      n_rows_removed_duplicates = n_duplicates,
      n_rows_removed_noid = n_noid_removed,
      n_rows_removed_zero_pulse = n_zero_removed,
      n_detectors = n_detectors,
      detectors = unique(kpro_master$Detector),
      timezone = target_tz,
      date_range_start = as.character(as.Date(date_range[1])),
      date_range_end = as.character(as.Date(date_range[2])),
      schema_distribution = as.list(schema_before),
      sources = list(
        local_rows = ingestion_metadata$local_rows,
        external_rows = ingestion_metadata$external_rows
      ),
      data_filters = list(
        remove_duplicates = remove_duplicates,
        remove_noid = remove_noid,
        remove_zero_pulse_calls = remove_zero_pulse
      )
    ),
    verbose = verbose
  )
  
  # -------------------------
  # Finalize validation context
  # -------------------------
  
  validation_context$summary$rows_processed <- nrow(kpro_master)
  validation_context$summary$n_detectors <- n_detectors
  validation_context$summary$date_range <- as.character(date_range)
  
  # Render validation HTML
  validation_html_path <- finalize_stage_validation_report(
    validation_context,
    stage_name = "DATA STANDARDIZATION",
    verbose = verbose,
    output_dir = here::here("results", "validation")
  )
  
  log_message(sprintf("[Stage 8] Registered artifact: %s", artifact_id))
  log_message(sprintf("[Stage 8] Validation report: %s", basename(validation_html_path)))
  
  # ===========================================================================
  # FINALIZATION
  # ===========================================================================
  
  if (verbose) {
    message("\n========================================")
    message("  DATA STANDARDIZATION COMPLETE")
    message("========================================")
    message(sprintf("  Rows: %s", format(nrow(kpro_master), big.mark = ",")))
    message(sprintf("  Detectors: %d", n_detectors))
    message(sprintf("  Date range: %s to %s",
                    as.Date(date_range[1]), as.Date(date_range[2])))
    message(sprintf("  Timezone: %s", target_tz))
    message(sprintf("  Checkpoint: %s", basename(checkpoint_path)))
    message(sprintf("  Validation: %s", basename(validation_html_path)))
    message("========================================\n")
  }
  
  result$standardization <- list(
    kpro_master = kpro_master,
    metadata = list(
      n_rows = nrow(kpro_master),
      n_detectors = n_detectors,
      detectors = unique(kpro_master$Detector),
      date_range = as.character(date_range),
      timezone = target_tz,
      rows_removed = list(
        invalid = ingestion_metadata$rows_removed_invalid,
        duplicates = n_duplicates,
        noid = n_noid_removed,
        zero_pulse = n_zero_removed,
        total_filtered = n_duplicates + n_noid_removed + n_zero_removed
      ),
      data_filters_applied = list(
        remove_duplicates = remove_duplicates,
        remove_noid = remove_noid,
        remove_zero_pulse_calls = remove_zero_pulse
      ),
      schema_distribution = as.list(schema_before)
    ),
    artifact_id = artifact_id,
    checkpoint_path = checkpoint_path
  )
  
  result$validation_html_paths <- c(validation_html_path)
  
  return(result)
}


# ==============================================================================
# END OF FILE
# ==============================================================================
