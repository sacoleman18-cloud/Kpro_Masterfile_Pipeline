# ============================================================================
# ORCHESTRATOR: run_ingest_standardize.R
# Purpose: Pipeline entry point for Chunk 1 (Data Ingestion → Standardization)
# Chunk: 1
# Module Stages: Ingestion → Standardization
# ============================================================================
# 
# Classification: Pipeline Orchestrator
# Subtitle: Coordinates raw data loading and transformation into analysis-ready master file
#
# Description:
# This orchestrator coordinates the complete data ingestion and standardization
# workflow. It manages the execution of two processing modules in sequence.
#
# Data Flow:
#   Input:  Raw CSV files from data/raw/ and external sources
#   ├─→ Module: data_ingestion → raw_data combined
#   ├─→ Module: data_standardization → kpro_master
#   Output: Analysis-ready kpro_master tibble with full validation
#
# Module Stages:
#   Stage 1-2: Data ingestion (module_data_ingestion)
#   Stage 3-8: Data standardization (module_data_standardization)
#
# Dependencies:
#   - R/functions/load_all.R (master loader)
#   - R/modules/data_ingestion.R (ingestion module)
#   - R/modules/data_standardization.R (standardization module)
#
# Last Modified: 2026-02-08
# Note: Modular orchestrator - calls dedicated modules instead of inline logic
#
# ============================================================================

#' Run Data Ingestion and Standardization Pipeline
#'
#' @description
#' Chunk 1 of 3 in the Shiny-driven pipeline. Orchestrates data ingestion
#' and standardization by calling dedicated modules in sequence.
#'
#' @param verbose Logical. Whether to print detailed progress messages.
#'   Default FALSE (silent operation).
#'
#' @return Named list containing:
#'   \itemize{
#'     \item \code{ingest_standardize}: List with kpro_master and metadata
#'     \item \code{validation_html_paths}: Character vector of validation HTML paths
#'   }
#'
#' @examples
#' \dontrun{
#' result <- run_ingest_standardize(verbose = TRUE)
#' kpro_master <- result$ingest_standardize$kpro_master
#' }
#'
#' @export
run_ingest_standardize <- function(verbose = FALSE) {
  
  # ===========================================================================
  # STAGE 1: INITIALIZATION AND UTILITY LOADING
  # ===========================================================================
  
  # Load all utilities, configurations, and module loaders
  source(file.path("R", "functions", "load_all.R"))
  
  # Initialize pipeline log
  initialize_pipeline_log()
  log_message("=== CHUNK 1: Ingest & Standardize - START ===")
  
  # Verify module availability
  required_modules <- c("module_data_ingestion", "module_data_standardization")
  missing_modules <- required_modules[!sapply(required_modules, function(x) exists(x) && is.function(get(x)))]
  if (length(missing_modules) > 0) {
    stop("Missing modules: ", paste(missing_modules, collapse = ", "))
  }
  
  # ===========================================================================
  # STAGE 2: DATA INGESTION MODULE
  # ===========================================================================
  
  cat("\n>>> [Chunk 1/Stages 1-2] Executing Data Ingestion Module...\n")
  
  ingestion_result <- tryCatch({
    module_data_ingestion(verbose = verbose)
  }, error = function(e) {
    stop("Data Ingestion module failed: ", e$message)
  })
  
  raw_data <- ingestion_result$raw_data
  study_params <- ingestion_result$study_params
  validation_context <- ingestion_result$validation_context
  ingestion_metadata <- ingestion_result$metadata
  
  cat("✓ Data Ingestion complete\n")
  
  # ===========================================================================
  # STAGE 3: DATA STANDARDIZATION MODULE
  # ===========================================================================
  
  cat("\n>>> [Chunk 1/Stages 3-8] Executing Data Standardization Module...\n")
  
  standardization_result <- tryCatch({
    module_data_standardization(
      raw_data = raw_data,
      study_params = study_params,
      validation_context = validation_context,
      ingestion_metadata = ingestion_metadata,
      verbose = verbose
    )
  }, error = function(e) {
    stop("Data Standardization module failed: ", e$message)
  })
  
  kpro_master <- standardization_result$standardization$kpro_master
  cat("✓ Data Standardization complete\n")
  
  # ===========================================================================
  # FINALIZATION
  # ===========================================================================
  
  log_message(sprintf("=== CHUNK 1 COMPLETE: %d rows, %d detectors ===",
                      nrow(kpro_master),
                      standardization_result$standardization$metadata$n_detectors))
  
  cat("\n>>> [Chunk 1] Ingest & Standardize complete - kpro_master ready\n")
  
  # Return consolidated results
  list(
    ingest_standardize = list(
      kpro_master = kpro_master,
      metadata = standardization_result$standardization$metadata,
      checkpoint_path = standardization_result$standardization$checkpoint_path
    ),
    validation_html_paths = standardization_result$validation_html_paths
  )
}


# ==============================================================================
# END OF FILE
# ==============================================================================
