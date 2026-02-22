# ============================================================================
# PHASE ORCHESTRATOR: run_phase2_template_generation.R
# Purpose: Phase 2 - Template Generation (CPN Template)
# Phase: 2 of 3
# Modules: 3
# ============================================================================
# 
# Classification: Phase Orchestrator
# Subtitle: Coordinates CPN template generation with human-in-the-loop checkpoint
#
# Description:
# This phase orchestrator implements Phase 2 of the checkpointed pipeline.
# It coordinates the execution of Module 3 (CPN template generation) and 
# produces the EDIT_THIS template for manual editing before Phase 3.
#
# Checkpointed Phase Architecture:
#   PHASE 1: Data Preparation → kpro_master.csv checkpoint
#   PHASE 2: Template Generation → CPN_Template_EDIT_THIS.csv (HUMAN-IN-THE-LOOP)
#   PHASE 3: Analysis & Reporting → Final outputs
#
# Human-in-the-Loop Checkpoint:
#   After Phase 2 completes, the user MUST edit the CPN_Template_EDIT_THIS.csv
#   file to adjust recording hours before proceeding to Phase 3.
#
# Data Flow (This Phase):
#   Input:  kpro_master from Phase 1 
#           ├─→ If use_manual_ids (YAML): reads Phase 1 checkpoint kpro_master.csv
#           └─→ If not use_manual_ids (YAML): uses in-memory from Phase 1 result
#   ├─→ Module 3: CPN Template → CPN template grid
#   Output: CPN_Template_EDIT_THIS.csv (for user editing)
#           In-memory original for Phase 3 edit tracking
#
# Manual ID Configuration (Shiny App Control):
#   - YAML key: processing_options.use_manual_ids
#   - yes/true  → Load user-edited kpro_master.csv from Phase 1 checkpoint
#   - no/false  → Use in-memory kpro_master from Phase 1 result (default)
#   - Users control this via Shiny app UI (no R code editing)
#
# Module Execution:
#   - Calls run_module_cpn_template() from module_runner
#   - YAML-driven conditional master file re-entry
#   - Checkpoint path determines manual ID behavior
#
# Checkpoint Output:
#   - outputs/03_CallsPerNight_Template_YYYYMMDD_HHMMSS_EDIT_THIS.csv (user edits this)
#   - results/validation/validation_*.html
#
# Edit Tracking:
#   - In-memory template passed to Phase 3 for comparison with user-edited version
#   - No persistent ORIGINAL file (deterministic in-memory handoff)
#
# Dependencies:
#   - R/functions/load_all.R (master loader)
#   - R/modules/module_runner.R (module execution layer)
#
# Last Modified: 2026-02-08
# Note: Phase-based orchestrator using module execution layer
#
# ============================================================================

#' Run Phase 2: Template Generation
#'
#' @description
#' Phase 2 of 3 in the checkpointed pipeline. Executes CPN template generation
#' by calling module runner. Produces CPN template checkpoint requiring manual
#' editing before Phase 3.
#'
#' **Manual ID Configuration (YAML-Driven):**
#' Module 3 checks `use_manual_ids` setting in study_parameters.yaml:
#'   - If `yes/true` → Loads user-edited kpro_master.csv from Phase 1 checkpoint
#'   - If `no/false` → Uses in-memory kpro_master from Phase 1 result
#' This enables Shiny app users to control whether to use edited master data
#' without modifying R code.
#'
#' @param phase1_result Result from run_phase1_data_preparation() (or NULL to load
#'   from checkpoint).
#' @param verbose Logical. Whether to print detailed progress messages.
#'   Default FALSE (silent operation).
#'
#' @return Named list containing:
#'   \itemize{
#'     \item \code{phase}: Phase number (2)
#'     \item \code{phase_name}: "Template Generation"
#'     \item \code{cpn_template}: Tibble with CPN template grid (passed to Phase 3 for edit comparison)
#'     \item \code{template_edit_path}: Path to EDIT_THIS template (for user editing)
#'     \item \code{checkpoint_path}: Path to phase checkpoint artifact
#'     \item \code{metadata}: List with template dimensions
#'     \item \code{artifact_ids}: Character vector of registered artifact IDs
#'     \item \code{validation_html_paths}: Character vector of validation reports
#'     \item \code{next_phase}: Instructions for manual editing and Phase 3
#'   }
#'
#' @examples
#' \dontrun{
#' # Run Phase 2 (after Phase 1)
#' phase1_result <- run_phase1_data_preparation(verbose = TRUE)
#' phase2_result <- run_phase2_template_generation(
#'   phase1_result = phase1_result,
#'   verbose = TRUE
#' )
#' 
#' # User edits template in Excel
#' cat("Edit this file:", phase2_result$template_edit_path, "\n")
#' 
#' # Continue to Phase 3 (after editing)
#' phase3_result <- run_phase3_analysis_reporting(
#'   phase2_result = phase2_result,
#'   verbose = TRUE
#' )
#' }
#'
#' @export
run_phase2_template_generation <- function(phase1_result = NULL,
                                           verbose = FALSE) {
  
  # ===========================================================================
  # INITIALIZATION
  # ===========================================================================
  
  # Load all utilities and module runners
  source(file.path("R", "functions", "load_all.R"))
  source(file.path("R", "modules", "module_runner.R"))
  
  # Initialize pipeline log
  initialize_pipeline_log()
  log_message("=== PHASE 2: Template Generation - START ===")
  
  if (verbose) {
    cat("\n")
    cat("========================================\n")
    cat("  PHASE 2: TEMPLATE GENERATION\n")
    cat("========================================\n")
    cat("  Modules: 3\n")
    cat("  Checkpoint: CPN_Template_EDIT_THIS.csv\n")
    cat("  Human-in-the-loop: Edit template\n")
    cat("========================================\n")
    cat("\n")
  }
  
  # ===========================================================================
  # MODULE 3: CPN TEMPLATE
  # ===========================================================================
  
  if (verbose) cat("\n>>> [Phase 2 - Module 3/3] CPN Template Generation\n")
  
  # Load study parameters to check manual ID configuration
  study_params <- load_study_parameters(here::here("inst", "config", "study_parameters.yaml"))
  
  # Determine manual_id_file from YAML config
  use_manual_ids <- study_params$processing_options$use_manual_ids %||% FALSE
  
  # Convert yes/no/true/false to boolean
  if (is.character(use_manual_ids)) {
    use_manual_ids <- tolower(use_manual_ids) %in% c("yes", "true")
  } else {
    use_manual_ids <- as.logical(use_manual_ids)
  }
  
  # Determine which kpro_master to use based on YAML config
  manual_id_file <- NULL
  
  if (use_manual_ids) {
    # Look for most recent kpro_master checkpoint
    checkpoint_dir <- here::here("outputs", "checkpoints")
    
    if (dir.exists(checkpoint_dir)) {
      checkpoint_files <- list.files(
        checkpoint_dir,
        pattern = "^02_kpro_master_.*\\.csv$",
        full.names = TRUE,
        sort = TRUE
      )
      
      if (length(checkpoint_files) > 0) {
        # Use the most recent file
        manual_id_file <- tail(checkpoint_files, 1)
        if (verbose) {
          cat(sprintf("  [YAML Config] use_manual_ids: enabled\n"))
          cat(sprintf("  [YAML Config] Loading manual ID file: %s\n", basename(manual_id_file)))
        }
      } else {
        if (verbose) {
          cat(sprintf("  [YAML Config] use_manual_ids: enabled\n"))
          cat(sprintf("  [YAML Config] No kpro_master checkpoint found - will use in-memory\n"))
        }
      }
    } else {
      if (verbose) {
        cat(sprintf("  [YAML Config] use_manual_ids: enabled\n"))
        cat(sprintf("  [YAML Config] Checkpoint directory missing - will use in-memory\n"))
      }
    }
  } else {
    if (verbose) {
      cat(sprintf("  [YAML Config] use_manual_ids: disabled\n"))
      cat(sprintf("  [YAML Config] Using in-memory kpro_master from Phase 1\n"))
    }
  }
  
  # Extract kpro_master from Phase 1 result if provided
  standardization_result <- NULL
  if (!is.null(phase1_result)) {
    if ("module_results" %in% names(phase1_result)) {
      standardization_result <- phase1_result$module_results$standardization
    } else if ("kpro_master" %in% names(phase1_result)) {
      # Create minimal standardization result structure
      standardization_result <- list(
        standardization = list(
          kpro_master = phase1_result$kpro_master
        )
      )
    }
  }
  
  module3_result <- tryCatch({
    run_module_cpn_template(
      standardization_result = standardization_result,
      manual_id_file = manual_id_file,
      verbose = verbose
    )
  }, error = function(e) {
    stop("Phase 2 - Module 3 (CPN Template) failed: ", e$message)
  })
  
  if (verbose) cat("✓ Module 3 complete\n")
  
  # ===========================================================================
  # PHASE COMPLETION - CHECKPOINT FOR MANUAL EDITING
  # ===========================================================================
  
  cpn_template <- module3_result$cpn_template
  kpro_master <- module3_result$kpro_master  # Updated with species column for Phase 3
  metadata <- module3_result$metadata
  template_edit_path <- module3_result$template_edit_path
  checkpoint_path <- module3_result$checkpoint_path %||% template_edit_path
  phase_artifact_ids <- module3_result$artifact_ids %||% character(0)
  if (is.list(phase_artifact_ids)) {
    phase_artifact_ids <- unlist(phase_artifact_ids, use.names = TRUE)
  }
  
  log_message(sprintf("=== PHASE 2 COMPLETE: %d rows, %d nights ===",
                      metadata$n_rows,
                      metadata$n_nights))
  
  if (verbose) {
    cat("\n")
    cat("========================================\n")
    cat("  PHASE 2 COMPLETE\n")
    cat("========================================\n")
    cat(sprintf("  Template rows: %s\n", format(metadata$n_rows, big.mark = ",")))
    cat(sprintf("  Detectors: %d\n", metadata$n_detectors))
    cat(sprintf("  Nights: %d\n", metadata$n_nights))
    cat("========================================\n")
    cat("\n")
    cat("⚠️  HUMAN ACTION REQUIRED  ⚠️\n")
    cat("========================================\n")
    cat("  EDIT THIS FILE:\n")
    cat(sprintf("  %s\n", template_edit_path))
    cat("\n")
    cat("  Instructions:\n")
    cat("  1. Open the EDIT_THIS file in Excel\n")
    cat("  2. Review and adjust recording hours\n")
    cat("  3. Save the file\n")
    cat("  4. Run Phase 3 to generate report\n")
    cat("========================================\n")
    cat("\n")
    cat("NEXT: After editing, run Phase 3 (Analysis & Reporting)\n")
    cat(sprintf("  phase3_result <- run_phase3_analysis_reporting(phase2_result, verbose = TRUE)\n"))
    cat("\n")
  }
  
  # ===========================================================================
  # RETURN PHASE RESULT
  # ===========================================================================
  
  list(
    phase = 2,
    phase_name = "Template Generation",
    kpro_master = kpro_master,  # Updated with species column for Phase 3
    cpn_template = cpn_template,  # Passed in-memory to Phase 3 for edit comparison
    template_edit_path = template_edit_path,
    checkpoint_path = checkpoint_path,
    metadata = metadata,
    artifact_ids = phase_artifact_ids,
    validation_html_paths = module3_result$validation_html_paths,
    next_phase = "Phase 3: Analysis & Reporting (run_phase3_analysis_reporting)",
    human_action_required = TRUE,
    human_action_message = sprintf("Edit template: %s", if(!is.null(template_edit_path) && is.character(template_edit_path)) basename(template_edit_path) else "template_file.csv"),
    
    # Raw module result (for advanced use)
    module_results = list(
      cpn_template = module3_result
    )
  )
}


# ==============================================================================
# END OF FILE
# ==============================================================================
