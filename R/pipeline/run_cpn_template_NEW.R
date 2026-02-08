# ============================================================================
# ORCHESTRATOR: run_cpn_template.R
# Purpose: Pipeline entry point for Chunk 2 (CallsPerNight Template Generation)
# Chunk: 2
# Module Stages: CPN Template Processing
# ============================================================================
# 
# Classification: Pipeline Orchestrator
# Subtitle: Coordinates CallsPerNight template generation with recording schedule
#
# Description:
# This orchestrator coordinates the CallsPerNight template generation workflow.
# It loads master data (with optional Manual ID integration) and generates
# Excel-ready template files for user editing.
#
# Data Flow:
#   Input:  kpro_master from Chunk 1 (or Manual ID file or checkpoint)
#   ├─→ Module: cpn_template → CPN template grid
#   Output: Excel-ready CPN template (ORIGINAL + EDIT_THIS files)
#
# Module Stages:
#   Stage 1-9: CPN template generation (module_cpn_template)
#
# Dependencies:
#   - R/functions/load_all.R (master loader)
#   - R/modules/cpn_template.R (template generation module)
#
# Last Modified: 2026-02-08
# Note: Modular orchestrator - calls dedicated module instead of inline logic
#
# ============================================================================

#' Run CallsPerNight Template Generation Pipeline
#'
#' @description
#' Chunk 2 of 3 in the Shiny-driven pipeline. Orchestrates CPN template
#' generation by calling dedicated module.
#'
#' @param kpro_master Tibble. Master data from Chunk 1 (or NULL to load from checkpoint).
#' @param manual_id_file Character. Path to manually-ID'd CSV file (optional).
#' @param verbose Logical. Whether to print detailed progress messages.
#'   Default FALSE (silent operation).
#'
#' @return Named list containing:
#'   \itemize{
#'     \item \code{cpn_template}: CPN template tibble
#'     \item \code{validation_html_paths}: Character vector of validation HTML paths
#'     \item \code{metadata}: List with template dimensions and configuration
#'     \item \code{template_edit_path}: Path to EDIT_THIS template file
#'   }
#'
#' @examples
#' \dontrun{
#' ingest_result <- run_ingest_standardize(verbose = TRUE)
#' result <- run_cpn_template(
#'   kpro_master = ingest_result$ingest_standardize$kpro_master,
#'   verbose = TRUE
#' )
#' template_path <- result$template_edit_path
#' }
#'
#' @export
run_cpn_template <- function(kpro_master = NULL,
                             manual_id_file = NULL,
                             verbose = FALSE) {
  
  # ===========================================================================
  # STAGE 1: INITIALIZATION AND UTILITY LOADING
  # ===========================================================================
  
  # Load all utilities, configurations, and module loaders
  source(file.path("R", "functions", "load_all.R"))
  
  # Initialize pipeline log
  initialize_pipeline_log()
  log_message("=== CHUNK 2: Generate CallsPerNight Template - START ===")
  
  # Verify module availability
  required_modules <- c("module_cpn_template")
  missing_modules <- required_modules[!sapply(required_modules, function(x) exists(x) && is.function(get(x)))]
  if (length(missing_modules) > 0) {
    stop("Missing modules: ", paste(missing_modules, collapse = ", "))
  }
  
  # ===========================================================================
  # STAGE 2: CPN TEMPLATE MODULE
  # ===========================================================================
  
  cat("\n>>> [Chunk 2/Stages 1-9] Executing CPN Template Module...\n")
  
  result <- tryCatch({
    module_cpn_template(
      kpro_master = kpro_master,
      manual_id_file = manual_id_file,
      study_params = NULL,  # Will be loaded by module
      verbose = verbose
    )
  }, error = function(e) {
    stop("CPN Template module failed: ", e$message)
  })
  
  cat("✓ CPN Template Generation complete\n")
  
  # ===========================================================================
  # FINALIZATION
  # ===========================================================================
  
  log_message(sprintf("=== CHUNK 2 COMPLETE: %d rows, %d nights ===",
                      result$metadata$n_rows,
                      result$metadata$n_nights))
  
  cat("\n>>> [Chunk 2] CPN Template complete - Edit template ready\n")
  cat(sprintf("    EDIT THIS FILE: %s\n", basename(result$template_edit_path)))
  
  return(result)
}


# ==============================================================================
# END OF FILE
# ==============================================================================
