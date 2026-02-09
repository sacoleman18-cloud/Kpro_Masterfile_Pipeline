# ============================================================================
# PHASE ORCHESTRATOR: run_phase1_data_preparation.R
# Purpose: Phase 1 - Data Preparation (Ingestion → Standardization)
# Phase: 1 of 3
# Modules: 1-2
# ============================================================================
# 
# Classification: Phase Orchestrator
# Subtitle: Coordinates raw data ingestion and standardization
#
# Description:
# This phase orchestrator implements Phase 1 of the checkpointed pipeline.
# It coordinates the execution of Modules 1-2 (data ingestion and 
# standardization) and produces the kpro_master checkpoint for downstream phases.
#
# Checkpointed Phase Architecture:
#   PHASE 1: Data Preparation → kpro_master.csv checkpoint
#   PHASE 2: Template Generation → CPN_Template_EDIT_THIS.csv (HUMAN-IN-THE-LOOP)
#   PHASE 3: Analysis & Reporting → Final outputs
#
# Data Flow (This Phase):
#   Input:  Raw CSV files from data/raw/ and external sources
#   ├─→ Module 1: Data Ingestion → raw_data
#   ├─→ Module 2: Data Standardization → kpro_master
#   Output: kpro_master checkpoint + validation reports
#
# Module Execution:
#   - Calls run_module_ingestion() from module_runner
#   - Calls run_module_standardization() from module_runner
#   - Passes structured results between modules
#
# Checkpoint Output:
#   - outputs/checkpoints/02_kpro_master_YYYYMMDD_HHMMSS.csv
#   - results/validation/validation_*.html
#
# Dependencies:
#   - R/functions/load_all.R (master loader)
#   - R/modules/module_runner.R (module execution layer)
#
# Last Modified: 2026-02-08
# Note: Phase-based orchestrator using module execution layer
#
# ============================================================================

#' Run Phase 1: Data Preparation
#'
#' @description
#' Phase 1 of 3 in the checkpointed pipeline. Executes data ingestion and
#' standardization by calling module runners in sequence. Produces kpro_master
#' checkpoint for downstream phases.
#'
#' @param verbose Logical. Whether to print detailed progress messages.
#'   Default FALSE (silent operation).
#'
#' @return Named list containing:
#'   \itemize{
#'     \item \code{phase}: Phase number (1)
#'     \item \code{phase_name}: "Data Preparation"
#'     \item \code{kpro_master}: Tibble with standardized master data
#'     \item \code{metadata}: List with processing statistics
#'     \item \code{checkpoint_path}: Path to kpro_master checkpoint
#'     \item \code{validation_html_paths}: Character vector of validation reports
#'     \item \code{next_phase}: Instructions for Phase 2
#'   }
#'
#' @examples
#' \dontrun{
#' # Run Phase 1
#' phase1_result <- run_phase1_data_preparation(verbose = TRUE)
#' 
#' # Inspect checkpoint
#' kpro_master <- phase1_result$kpro_master
#' 
#' # Continue to Phase 2
#' phase2_result <- run_phase2_template_generation(
#'   phase1_result = phase1_result,
#'   verbose = TRUE
#' )
#' }
#'
#' @export
run_phase1_data_preparation <- function(verbose = FALSE) {
  
  # ===========================================================================
  # INITIALIZATION
  # ===========================================================================
  
  # Load all utilities and module runners
  source(file.path("R", "functions", "load_all.R"))
  source(file.path("R", "modules", "module_runner.R"))
  
  # Initialize pipeline log
  initialize_pipeline_log()
  log_message("=== PHASE 1: Data Preparation - START ===")
  
  if (verbose) {
    cat("\n")
    cat("========================================\n")
    cat("  PHASE 1: DATA PREPARATION\n")
    cat("========================================\n")
    cat("  Modules: 1-2\n")
    cat("  Checkpoint: kpro_master.csv\n")
    cat("========================================\n")
    cat("\n")
  }
  
  # ===========================================================================
  # MODULE 1: DATA INGESTION
  # ===========================================================================
  
  if (verbose) cat("\n>>> [Phase 1 - Module 1/2] Data Ingestion\n")
  
  module1_result <- tryCatch({
    run_module_ingestion(verbose = verbose)
  }, error = function(e) {
    stop("Phase 1 - Module 1 (Ingestion) failed: ", e$message)
  })
  
  if (verbose) cat("✓ Module 1 complete\n")
  
  # ===========================================================================
  # MODULE 2: DATA STANDARDIZATION
  # ===========================================================================
  
  if (verbose) cat("\n>>> [Phase 1 - Module 2/2] Data Standardization\n")
  
  module2_result <- tryCatch({
    run_module_standardization(
      ingestion_result = module1_result,
      verbose = verbose
    )
  }, error = function(e) {
    stop("Phase 1 - Module 2 (Standardization) failed: ", e$message)
  })
  
  if (verbose) cat("✓ Module 2 complete\n")
  
  # ===========================================================================
  # PHASE COMPLETION
  # ===========================================================================
  
  kpro_master <- module2_result$standardization$kpro_master
  metadata <- module2_result$standardization$metadata
  checkpoint_path <- module2_result$standardization$checkpoint_path
  
  log_message(sprintf("=== PHASE 1 COMPLETE: %d rows, %d detectors ===",
                      metadata$n_rows,
                      metadata$n_detectors))
  
  if (verbose) {
    cat("\n")
    cat("========================================\n")
    cat("  PHASE 1 COMPLETE\n")
    cat("========================================\n")
    cat(sprintf("  Rows: %s\n", format(metadata$n_rows, big.mark = ",")))
    cat(sprintf("  Detectors: %d\n", metadata$n_detectors))
    cat(sprintf("  Checkpoint: %s\n", basename(checkpoint_path)))
    cat("========================================\n")
    cat("\n")
    cat("NEXT: Run Phase 2 (Template Generation)\n")
    cat(sprintf("  phase2_result <- run_phase2_template_generation(phase1_result, verbose = TRUE)\n"))
    cat("\n")
  }
  
  # ===========================================================================
  # RETURN PHASE RESULT
  # ===========================================================================
  
  list(
    phase = 1,
    phase_name = "Data Preparation",
    kpro_master = kpro_master,
    metadata = metadata,
    checkpoint_path = checkpoint_path,
    validation_html_paths = module2_result$validation_html_paths,
    next_phase = "Phase 2: Template Generation (run_phase2_template_generation)",
    
    # Raw module results (for advanced use)
    module_results = list(
      ingestion = module1_result,
      standardization = module2_result
    )
  )
}


# ==============================================================================
# END OF FILE
# ==============================================================================
