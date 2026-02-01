# ==============================================================================
# R/pipeline/run_ingest_standardize.R
# ==============================================================================
# PURPOSE
# -------
# Chunk 1 of 3 in the Shiny-driven pipeline. Orchestrates the complete
# ingestion and standardization process, transforming raw KPro CSV files
# into a unified, analysis-ready kpro_master dataset.
#
# PIPELINE POSITION
# -----------------
# Chunk 1 of 3 in the Shiny-driven pipeline:
#   run_ingest_standardize()  -> [THIS FUNCTION] Raw CSVs to kpro_master
#   run_cpn_template()        -> Generate CallsPerNight template
#   run_finalize_to_report()  -> Finalize CPN through Report generation
#
# DECISION POINTS (handled by Shiny app):
#   After Chunk 1: User may export Master for Manual ID in Kaleidoscope
#   After Chunk 2: User may edit recording hours in CPN template
#
# PROCESSING STAGES
# -----------------
#   Stage 1: Load configuration from study_parameters.yaml
#   Stage 2: Discover and load raw CSV files (local + external)
#   Stage 3: Validate & reconcile configuration (detector mappings)
#   Stage 4: Transform schemas (v1/v2/v3 -> unified master)
#   Stage 5: Apply detector mapping (ID -> friendly name)
#   Stage 6: Convert timestamps (UTC -> local timezone)
#   Stage 7: Finalize schema and apply optional deduplication
#   Stage 8: Apply user-configured data filters (NoID, zero-pulse)
#   Stage 9: Save checkpoint, register artifact, render validation HTML
#
# CONTRACT
# --------
# INPUTS:
#   - Raw CSV files in data/raw/ and/or external directories (from YAML)
#   - inst/config/study_parameters.yaml (created by Shiny app)
#
# OUTPUTS:
#   - kpro_master tibble (in returned list)
#   - Checkpoint CSV: outputs/checkpoints/02_kpro_master_YYYYMMDD_HHMMSS.csv
#   - Validation HTML: results/validation/validation_ingest_YYYYMMDD_HHMMSS.html
#   - Artifact registry entry
#
# GUARANTEES:
#   - All paths use here::here()
#   - Silent by default (verbose = FALSE)
#   - No interactive prompts (unmapped detectors use detector_id)
#   - File logging always active via log_message()
#   - Returns structured list with all outputs
#   - Validation HTML rendered for user review before Manual ID decision
#   - User-configured data filters applied based on YAML settings
#
# DOES NOT:
#   - Accept configuration as parameters (reads from YAML)
#   - Modify global environment (returns results)
#   - Prompt for user input
#
# DEPENDENCIES
# ------------
#   Custom functions (via load_all.R):
#     - ingestion.R: load_local_raw_data, load_external_raw_data
#     - schema_detection.R: detect_row_schema
#     - standardization.R: standardize_kpro_schema
#     - datetime_conversion.R: convert_datetime_to_local
#     - validation.R: enforce_unified_schema, finalize_master_columns,
#                     create_validation_context, log_validation_event,
#                     finalize_validation_report, assert_file_exists,
#                     assert_directory_exists, assert_not_empty
#     - config.R: load_study_parameters, ensure_study_parameters
#     - artifacts.R: init_artifact_registry, register_artifact
#     - utilities.R: log_message, print_stage_header, safe_read_csv, %||%
#
# CHANGELOG
# ---------
# 2026-02-01: Added Stage 3 (validate & reconcile configuration) using ensure_study_parameters()
#             - Renumbered all subsequent stages (old Stage 3 -> new Stage 4, etc.)
#             - Auto-creates YAML template if missing
#             - Reconciles detector mappings (add new, preserve existing, remove old)
#             - Validates YAML structure before continuing
#             - Reloads study_params to get reconciled mappings for Stage 5
# 2026-01-30: Renumbered stages to integers (Stage 6.5 -> Stage 7, Stage 7 -> Stage 8)
# 2026-01-30: Made deduplication optional via data_filters (default: TRUE)
# 2026-01-30: Added Stage 7 user-configured data filters (NoID, zero-pulse)
# 2026-01-30: Refactored to use centralized assert_* functions from validation.R
# 2026-01-30: Replaced <<- operator with cleaner error handling pattern
# 2026-01-29: Simplified to single verbose parameter for Shiny integration
# 2026-01-29: Added validation HTML rendering at end of chunk
# 2026-01-24: Initial creation - merged WF01 + WF02 into single function
#
# ==============================================================================


#' Run Ingestion and Standardization Pipeline
#'
#' @description
#' Chunk 1 of the KPro pipeline. Loads raw CSV files from configured sources,
#' applies schema transformation, detector mapping, timezone conversion, and
#' optional user-configured data filters to produce the unified kpro_master dataset.
#'
#' All configuration is read from `inst/config/study_parameters.yaml`, which
#' is created/populated by the Shiny app. Raw data is loaded from `data/raw/`
#' and any external sources specified in the YAML.
#'
#' At completion, renders a validation HTML report for user review before
#' the Manual ID decision point.
#'
#' @param verbose Logical. Print progress messages to console. Default: FALSE.
#'
#' @return Named list containing:
#'   \describe{
#'     \item{kpro_master}{Tibble. Unified master dataset with all detections.}
#'     \item{metadata}{List. Processing metadata including:
#'       \itemize{
#'         \item n_rows: Total rows in final dataset
#'         \item n_detectors: Number of unique detectors
#'         \item detectors: Character vector of detector names
#'         \item date_range: Character vector of start/end dates
#'         \item timezone: Target timezone used for conversion
#'         \item rows_removed: List with invalid, duplicates, noid, zero_pulse counts
#'         \item data_filters_applied: List showing which filters were enabled
#'         \item schema_distribution: List of row counts by schema version
#'         \item sources: List with local_rows and external_rows counts
#'       }
#'     }
#'     \item{artifact_id}{Character. Registered artifact identifier.}
#'     \item{checkpoint_path}{Character. Path to saved checkpoint CSV.}
#'     \item{validation_html_path}{Character. Path to validation HTML report.}
#'   }
#'
#' @section CONTRACT:
#' - Reads configuration from inst/config/study_parameters.yaml
#' - Loads data from data/raw/ and external_data_sources in YAML
#' - Transforms all schema versions (v1/v2/v3) to unified master format
#' - Converts timestamps from UTC to configured timezone
#' - Applies optional data filters based on YAML configuration (Stage 6-7)
#' - Always saves checkpoint to outputs/checkpoints/
#' - Always renders validation HTML to results/validation/
#' - Registers artifact in inst/config/artifact_registry.yaml
#' - Returns structured list (does not modify global environment)
#'
#' @section DATA FILTERS:
#' Optional data filters configured in study_parameters.yaml:
#' \itemize{
#'   \item remove_duplicates: TRUE/FALSE - Remove duplicate detections 
#'         (based on Detector + DateTime_local + auto_id). Default: TRUE.
#'         Applied in Stage 6.
#'   \item remove_noid: TRUE/FALSE - Exclude all auto_id == "NoID" calls. 
#'         Default: FALSE. Applied in Stage 7.
#'   \item remove_zero_pulse_calls: TRUE/FALSE - Exclude pulses == 0 or NA. 
#'         Default: FALSE. Applied in Stage 7.
#' }
#' Filters run sequentially: duplicates (Stage 6) -> NoID (Stage 7) -> zero-pulse (Stage 7).
#' Each filter logs validation events with before/after row counts.
#'
#' @section DOES NOT:
#' - Accept data paths as parameters (uses YAML configuration)
#' - Skip checkpoint saving (always saves)
#' - Skip validation HTML (always renders)
#' - Modify global environment
#' - Prompt for user input
#' - Stop on unmapped detectors (uses detector_id as fallback)
#'
#' @section Error Handling:
#' Stops with actionable error message if:
#' \itemize{
#'   \item study_parameters.yaml not found
#'   \item Timezone not configured in YAML
#'   \item No CSV files found in any data source
#'   \item Schema transformation fails
#' }
#'
#' @examples
#' \dontrun{
#' # Standard usage (called by Shiny app)
#' result <- run_ingest_standardize()
#'
#' # With console output for debugging
#' result <- run_ingest_standardize(verbose = TRUE)
#'
#' # Access results
#' kpro_master <- result$kpro_master
#' result$metadata$n_rows
#' result$metadata$rows_removed  # Lists all filter counts
#' result$metadata$data_filters_applied  # Shows filter configuration
#' result$checkpoint_path
#' result$validation_html_path
#' }
#'
#' @export
run_ingest_standardize <- function(verbose = FALSE) {
  
  # ===========================================================================
  # SETUP
  # ===========================================================================
  
  log_message("=== CHUNK 1: Ingest & Standardize - START ===")
  
  # Initialize validation context
  validation_context <- create_validation_context(workflow = "ingest")
  
  # Standard paths (not configurable - derived from project structure)
  raw_data_dir <- here::here("data", "raw")
  yaml_path <- here::here("inst", "config", "study_parameters.yaml")
  
  # ===========================================================================
  # STAGE 1: LOAD CONFIGURATION
  # ===========================================================================
  
  if (verbose) print_stage_header("1", "Load Configuration")
  
  # Load study parameters from YAML (created by Shiny app)
  # Using centralized assertion for file existence
  assert_file_exists(
    yaml_path,
    hint = "Configure study parameters in Shiny app first."
  )
  
  study_params <- load_study_parameters(yaml_path)
  if (verbose) message("  [OK] Loaded study_parameters.yaml")
  
  # Update validation context with study name
  validation_context$study_name <- study_params$study_parameters$study_name
  
  # Validate required configuration
  if (is.null(study_params$study_parameters$timezone)) {
    stop(
      "Timezone not configured in study_parameters.yaml.\n",
      "  Add timezone in Shiny app configuration."
    )
  }
  
  # Get external sources from YAML (may be NULL)
  external_sources <- study_params$study_parameters$external_data_sources
  
  log_message("[Stage 1] Configuration loaded")
  
  # ===========================================================================
  # STAGE 2: LOAD RAW DATA
  # ===========================================================================
  
  if (verbose) print_stage_header("2", "Load Raw Data")
  
  # Initialize tracking variables
  local_data <- NULL
  external_data <- NULL
  external_datasets <- list()
  total_rows_removed <- 0
  
  # -------------------------
  # Load local data
  # -------------------------
  
  if (dir.exists(raw_data_dir)) {
    local_data <- load_local_raw_data(
      local_dir = raw_data_dir,
      return_combined = TRUE,
      verbose = verbose
    )
    
    if (!is.null(local_data) && nrow(local_data) > 0) {
      rows_removed_local <- attr(local_data, "rows_removed") %||% 0
      total_rows_removed <- total_rows_removed + rows_removed_local
      
      validation_context <- log_validation_event(
        validation_context,
        event_type = "files_loaded",
        description = "Loaded local CSV files",
        count = attr(local_data, "files_processed") %||% 1,
        details = list(
          source = "local",
          directory = raw_data_dir,
          rows = nrow(local_data),
          rows_removed = rows_removed_local
        )
      )
      
      if (verbose) {
        message(sprintf("  [OK] Local data: %s rows from %d file(s)",
                        format(nrow(local_data), big.mark = ","),
                        attr(local_data, "files_processed") %||% 1))
      }
    }
  } else {
    if (verbose) message(sprintf("  [!] Local data directory not found: %s", raw_data_dir))
  }
  
  # -------------------------
  # Load external data (REFACTORED - no more <<- operator)
  # -------------------------
  
  if (!is.null(external_sources) && length(external_sources) > 0) {
    
    for (i in seq_along(external_sources)) {
      ext_dir <- external_sources[[i]]
      
      if (!dir.exists(ext_dir)) {
        if (verbose) message(sprintf("  [!] External source not found: %s", ext_dir))
        
        validation_context <- log_validation_event(
          validation_context,
          event_type = "file_failed",
          description = sprintf("External directory not found: %s", basename(ext_dir)),
          details = list(path = ext_dir)
        )
        next
      }
      
      # Load with error handling (cleaner pattern - no <<-)
      load_result <- tryCatch({
        list(
          data = load_external_raw_data(ext_dir, verbose = verbose),
          error = NULL
        )
      }, error = function(e) {
        list(data = NULL, error = e$message)
      })
      
      # Handle error case
      if (!is.null(load_result$error)) {
        if (verbose) message(sprintf("  [X] Failed to load %s: %s", ext_dir, load_result$error))
        
        validation_context <- log_validation_event(
          validation_context,
          event_type = "file_failed",
          description = sprintf("External load failed: %s", basename(ext_dir)),
          details = list(path = ext_dir, error = load_result$error)
        )
        next
      }
      
      ext_data <- load_result$data
      
      if (!is.null(ext_data) && nrow(ext_data) > 0) {
        external_datasets[[paste0("ext_", i)]] <- ext_data
        rows_removed_ext <- attr(ext_data, "rows_removed") %||% 0
        total_rows_removed <- total_rows_removed + rows_removed_ext
        
        if (verbose) {
          message(sprintf("  [OK] External source %d: %s rows",
                          i, format(nrow(ext_data), big.mark = ",")))
        }
      }
    }
    
    if (length(external_datasets) > 0) {
      external_data <- dplyr::bind_rows(external_datasets)
      
      validation_context <- log_validation_event(
        validation_context,
        event_type = "files_loaded",
        description = "Loaded external data sources",
        count = length(external_datasets),
        details = list(
          source = "external",
          sources_succeeded = length(external_datasets),
          rows = nrow(external_data)
        )
      )
    }
  }
  
  # -------------------------
  # Combine all data
  # -------------------------
  
  raw_combined <- dplyr::bind_rows(local_data, external_data)
  
  # Using centralized assertion for empty data check
  if (is.null(raw_combined) || nrow(raw_combined) == 0) {
    stop(
      "No data loaded from any source.\n",
      "  Local directory: ", raw_data_dir, "\n",
      "  External sources: ", length(external_sources %||% list()), "\n",
      "  Add CSV files to data/raw/ or configure external_data_sources in Shiny app."
    )
  }
  
  # Log source breakdown
  n_local <- if (!is.null(local_data)) nrow(local_data) else 0
  n_external <- if (!is.null(external_data)) nrow(external_data) else 0
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "source_breakdown",
    description = "Combined data sources",
    details = list(
      local_rows = n_local,
      external_rows = n_external,
      total_rows = nrow(raw_combined),
      rows_removed_invalid = total_rows_removed
    )
  )
  
  log_message(sprintf("[Stage 2] Loaded %d rows from %d source(s)",
                      nrow(raw_combined),
                      (n_local > 0) + length(external_datasets)))
  
  # ===========================================================================
  # STAGE 2B: VALIDATE & RECONCILE CONFIGURATION
  # ===========================================================================
  
  if (verbose) print_stage_header("3", "Validate & Reconcile Configuration")
  
  # Ensure YAML exists and detector mappings are synchronized
  # This will:
  #   1. Create YAML template if missing (with suggested dates from data)
  #   2. Add new detector IDs discovered in raw_combined
  #   3. Preserve existing user-entered detector names
  #   4. Remove obsolete detector IDs no longer in data
  #   5. Validate final YAML structure
  ensure_study_parameters(
    raw_data = raw_combined,
    yaml_path = yaml_path
  )
  
  # Reload study_params to get reconciled detector mappings
  study_params <- load_study_parameters(yaml_path)
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "config_reconciled",
    description = "Detector mappings reconciled with YAML",
    details = list(
      n_detectors = length(unique(raw_combined$detector_id[!is.na(raw_combined$detector_id)]))
    )
  )
  
  if (verbose) message("  [OK] YAML validated and detector mappings reconciled")
  
  log_message("[Stage 3] Configuration validated and reconciled")
  
  # ===========================================================================
  # STAGE 4: SCHEMA TRANSFORMATION
  # ===========================================================================
  
  if (verbose) print_stage_header("4", "Schema Transformation")
  
  # Capture schema distribution before transformation
  schema_before <- table(raw_combined$schema_version)
  
  # Transform all schemas to unified format
  unified_data <- standardize_kpro_schema(raw_combined, verbose = verbose)
  
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
  
  log_message("[Stage 3] Transformed schemas to unified format")
  
  # ===========================================================================
  # STAGE 4: DETECTOR MAPPING
  # ===========================================================================
  
  if (verbose) print_stage_header("4", "Detector Mapping")
  
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
  
  log_message(sprintf("[Stage 4] Applied detector mapping: %d detectors", n_detectors))
  
  # ===========================================================================
  # STAGE 5: TIME CONVERSION
  # ===========================================================================
  
  if (verbose) print_stage_header("5", "Time Conversion")
  
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
  # CHANGED: Made deduplication optional via YAML configuration
  # ===========================================================================
  
  if (verbose) print_stage_header("6", "Finalize & Deduplicate")
  
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
  
  log_message(sprintf("[Stage 6] Finalized: %d rows, %d duplicates removed",
                      nrow(kpro_master), n_duplicates))
  
  # ===========================================================================
  # STAGE 7: USER-CONFIGURED DATA FILTERS
  # ===========================================================================
  # CHANGED: Updated `n_before > 0` to be more dynamic
  # NEW STAGE: Optional NoID and zero-pulse filtering
  # ===========================================================================
  
  if (verbose) print_stage_header("7", "Data Filters")
  
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
    
    # FIXED: Only log validation event if rows were actually removed
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
    
    # FIXED: Only log validation event if rows were actually removed
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
  # STAGE 8: SAVE, REGISTER & RENDER VALIDATION
  # ===========================================================================
  # CHANGED: Renumbered from Stage 7 to Stage 8
  # CHANGED: Updated metadata and artifact registry to include filter tracking
  # ===========================================================================
  
  if (verbose) print_stage_header("8", "Save, Register & Validate")
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  artifact_id <- sprintf("kpro_master_%s", timestamp)
  
  # -------------------------
  # Save checkpoint (using centralized assertion for directory)
  # -------------------------
  
  checkpoint_dir <- here::here("outputs", "checkpoints")
  assert_directory_exists(checkpoint_dir, create = TRUE)
  
  checkpoint_path <- here::here("outputs", "checkpoints",
                                sprintf("02_kpro_master_%s.csv", timestamp))
  
  readr::write_csv(kpro_master, checkpoint_path)
  
  if (verbose) message(sprintf("  [OK] Checkpoint saved: %s", basename(checkpoint_path)))
  
  # -------------------------
  # Register artifact
  # -------------------------
  
  registry <- init_artifact_registry()
  
  registry <- register_artifact(
    registry = registry,
    artifact_name = artifact_id,
    artifact_type = "masterfile",
    workflow = "ingest",
    file_path = checkpoint_path,
    metadata = list(
      n_rows_final = nrow(kpro_master),
      n_rows_removed_invalid = total_rows_removed,
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
        local_rows = n_local,
        external_rows = n_external
      ),
      data_filters = list(
        remove_duplicates = remove_duplicates,
        remove_noid = remove_noid,
        remove_zero_pulse_calls = remove_zero_pulse
      )
    )
  )
  
  if (verbose) message("  [OK] Artifact registered")
  
  # -------------------------
  # Finalize validation context
  # -------------------------
  
  validation_context$summary$rows_processed <- nrow(kpro_master)
  validation_context$summary$n_detectors <- n_detectors
  validation_context$summary$date_range <- as.character(date_range)
  
  # -------------------------
  # Render validation HTML (using centralized assertion for directory)
  # -------------------------
  
  validation_dir <- here::here("results", "validation")
  assert_directory_exists(validation_dir, create = TRUE)
  
  validation_html_path <- finalize_validation_report(
    validation_context,
    output_dir = validation_dir
  )
  
  if (verbose) message(sprintf("  [OK] Validation report: %s", basename(validation_html_path)))
  
  log_message(sprintf("[Stage 9] Registered artifact: %s", artifact_id))
  log_message(sprintf("[Stage 9] Validation report: %s", basename(validation_html_path)))
  
  # ===========================================================================
  # RETURN
  # ===========================================================================
  
  log_message(sprintf("=== CHUNK 1 COMPLETE: %d rows, %d detectors ===",
                      nrow(kpro_master), n_detectors))
  
  if (verbose) {
    message("\n========================================")
    message("  INGEST & STANDARDIZE COMPLETE")
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
  
  list(
    kpro_master = kpro_master,
    
    metadata = list(
      n_rows = nrow(kpro_master),
      n_detectors = n_detectors,
      detectors = unique(kpro_master$Detector),
      date_range = as.character(date_range),
      timezone = target_tz,
      rows_removed = list(
        invalid = total_rows_removed,
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
      schema_distribution = as.list(schema_before),
      sources = list(
        local_rows = n_local,
        external_rows = n_external
      )
    ),
    
    artifact_id = artifact_id,
    checkpoint_path = checkpoint_path,
    validation_html_path = validation_html_path
  )
}


# ==============================================================================
# END OF FILE
# ==============================================================================