# ==============================================================================
# MODULE: data_ingestion.R
# ==============================================================================
# 
# Classification: Processing Module
# Subtitle: Raw data discovery, loading, and initial validation
#
# Description:
# This module handles the complete data ingestion process for the KPro pipeline.
# It discovers and loads raw CSV files from local and external data sources,
# performs initial validation, and prepares combined raw data for standardization.
#
# Module Stages:
#   Stage 1: Load configuration from study_parameters.yaml
#   Stage 2: Discover and load raw CSV files (local + external sources)
#
# Data Flow:
#   Input:  Raw CSV files from data/raw/ and configured external sources
#   Output: Combined raw data tibble with schema version detection
#
# Dependencies:
#   - R/functions/core/config.R (load_study_parameters, setup_pipeline_context)
#   - R/functions/core/logging.R (log_message, log_stage_start)
#   - R/functions/core/console.R (print_stage_banner)
#   - R/functions/ingestion/ingestion.R (load_local_raw_data, load_external_raw_data)
#   - R/functions/validation/validation.R (init_stage_validation, log_validation_event)
#   - R/functions/core/utilities.R (%||%)
#
# Last Modified: 2026-02-08
# Changelog: Created as part of pipeline modularization refactor
#
# ==============================================================================

#' Load Raw Data from All Sources
#'
#' @description
#' Module Stage 1-2: Loads configuration and discovers/loads raw CSV files
#' from local directory and configured external sources.
#'
#' @param verbose Logical. Whether to print detailed progress messages.
#'   Default FALSE (silent operation).
#'
#' @return Named list containing:
#'   \itemize{
#'     \item \code{raw_data}: Tibble with combined raw data from all sources
#'     \item \code{study_params}: List from load_study_parameters()
#'     \item \code{validation_context}: Validation context object
#'     \item \code{metadata}: List with source breakdown and row counts
#'   }
#'
#' @examples
#' \dontrun{
#' result <- module_data_ingestion(verbose = TRUE)
#' raw_data <- result$raw_data
#' study_params <- result$study_params
#' }
#'
#' @export
module_data_ingestion <- function(verbose = FALSE) {
  
  # ===========================================================================
  # INITIALIZATION
  # ===========================================================================
  
  print_stage_banner("DATA INGESTION", verbose = verbose)
  
  result <- list(
    raw_data = NULL,
    study_params = NULL,
    validation_context = NULL,
    metadata = list()
  )
  
  # ===========================================================================
  # STAGE 1: LOAD CONFIGURATION
  # ===========================================================================
  
  log_stage_start("1", "Load Configuration", verbose = verbose, 
                  workflow_prefix = "Data Ingestion")
  
  # Setup pipeline context (deterministic - no parameters)
  ctx <- setup_pipeline_context("ingest")
  study_params <- ctx$study_params
  validation_context <- init_stage_validation("ingest", study_params)
  yaml_path <- ctx$yaml_path
  
  # Get external sources from YAML (may be NULL)
  external_sources <- study_params$study_parameters$external_data_sources
  
  # Standard paths (not configurable - derived from project structure)
  raw_data_dir <- here::here("data", "raw")
  
  log_message(sprintf("[Stage 1] Configuration loaded from %s", yaml_path))
  
  # ===========================================================================
  # STAGE 2: LOAD RAW DATA
  # ===========================================================================
  
  log_stage_start("2", "Load Raw Data", verbose = verbose,
                  workflow_prefix = "Data Ingestion")
  
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
  # Load external data
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
      
      # Load with error handling
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
  
  # Validate non-empty data
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
  # FINALIZATION
  # ===========================================================================
  
  result$raw_data <- raw_combined
  result$study_params <- study_params
  result$validation_context <- validation_context
  result$metadata <- list(
    local_rows = n_local,
    external_rows = n_external,
    total_rows = nrow(raw_combined),
    sources_count = (n_local > 0) + length(external_datasets),
    rows_removed_invalid = total_rows_removed
  )
  
  return(result)
}


# ==============================================================================
# END OF FILE
# ==============================================================================
