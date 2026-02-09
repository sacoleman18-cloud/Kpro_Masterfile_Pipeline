# ==============================================================================
# TEST: Checkpointed Phase Orchestration Pipeline
# ==============================================================================
# 
# Purpose: Test the full 3-phase pipeline with checkpointed execution
# 
# Phase Structure:
#   PHASE 1: Data Preparation (Modules 1-2) → kpro_master checkpoint
#   PHASE 2: Template Generation (Module 3) → CPN template EDIT_THIS file
#   PHASE 3: Analysis & Reporting (Modules 4-7) → Final outputs
#
# Human-in-the-Loop:
#   After Phase 2, user MUST edit the CPN_Template_EDIT_THIS.csv file before
#   proceeding to Phase 3. This test demonstrates interrupted execution.
#
# ==============================================================================

library(here)
library(tidyverse)

# Source all functions (assumes R/functions/load_all.R exists)
source(here("R", "functions", "load_all.R"))

# Source phase orchestrators
source(here("R", "pipeline", "run_phase1_data_preparation.R"))
source(here("R", "pipeline", "run_phase2_template_generation.R"))
source(here("R", "pipeline", "run_phase3_analysis_reporting.R"))

# ==============================================================================
# PHASE 1: Data Preparation (Ingestion + Standardization)
# ==============================================================================

cat("\n")
cat("========================================\n")
cat("  STARTING PHASE 1\n")
cat("========================================\n")
cat("\n")

phase1_result <- run_phase1_data_preparation(verbose = TRUE)

cat("\n")
cat("✓ PHASE 1 COMPLETE\n")
cat(sprintf("  Checkpoint: %s\n", phase1_result$checkpoint_path))
cat("\n")

# ==============================================================================
# PHASE 2: Template Generation (CPN Template)
# ==============================================================================

cat("\n")
cat("========================================\n")
cat("  STARTING PHASE 2\n")
cat("========================================\n")
cat("\n")

phase2_result <- run_phase2_template_generation(
  phase1_result = phase1_result,
  verbose = TRUE
)

cat("\n")
cat("✓ PHASE 2 COMPLETE\n")
cat(sprintf("  Template: %s\n", phase2_result$template_edit_path))
cat("\n")

# ==============================================================================
# ⚠️  HUMAN-IN-THE-LOOP CHECKPOINT  ⚠️
# ==============================================================================

cat("\n")
cat("========================================\n")
cat("  ⚠️  ACTION REQUIRED  ⚠️\n")
cat("========================================\n")
cat("  BEFORE PHASE 3:\n")
cat("  1. Open the template file:\n")
cat(sprintf("     %s\n", phase2_result$template_edit_path))
cat("  2. Edit species identifications\n")
cat("  3. Save the file\n")
cat("  4. Un-comment Phase 3 code below\n")
cat("========================================\n")
cat("\n")

# ==============================================================================
# PHASE 3: Analysis & Reporting (Finalize → Report)
# ==============================================================================
# 
# ⚠️  UNCOMMENT AFTER EDITING TEMPLATE:

# cat("\n")
# cat("========================================\n")
# cat("  STARTING PHASE 3\n")
# cat("========================================\n")
# cat("\n")
# 
# phase3_result <- run_phase3_analysis_reporting(
#   phase2_result = phase2_result,
#   verbose = TRUE
# )
# 
# cat("\n")
# cat("✓ PHASE 3 COMPLETE\n")
# cat(sprintf("  Report: %s\n", phase3_result$report_path))
# cat(sprintf("  Bundle: %s\n", phase3_result$release_bundle_path))
# cat("\n")
# cat("========================================\n")
# cat("  ✅  PIPELINE COMPLETE  ✅\n")
# cat("========================================\n")
# cat("\n")