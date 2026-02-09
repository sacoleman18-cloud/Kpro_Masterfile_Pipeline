# ==============================================================================
# KPRO MASTERFILE PIPELINE - TEST HARNESS
# ==============================================================================
#
# PURPOSE: Test orchestration and module execution
#
# STRUCTURE:
#   Section 1: Phase Orchestration Testing (checkpointed pipeline)
#   Section 2: Module-Level Testing (individual module execution)
#
# ==============================================================================

library(here)
library(tidyverse)

# Load all functions and phase orchestrators
source(here("R", "functions", "load_all.R"))

# ==============================================================================
# SECTION 1: PHASE ORCHESTRATION TESTING
# ==============================================================================
# Tests the three-phase orchestrated pipeline with checkpointed result passing.
# This is the RECOMMENDED usage pattern for the complete pipeline.
#
# Data Flow:
#   Phase 1 → result1 (kpro_master checkpoint)
#   Phase 2 → result2 (CPN template checkpoint)
#   Phase 3 → result3 (final analysis outputs)

cat("\n")
cat("================================================================================\n")
cat("SECTION 1: PHASE ORCHESTRATION TESTING (Checkpointed Pipeline)\n")
cat("================================================================================\n")
cat("\n")

# ─────────────────────────────────────────────────────────────────────────────
# Phase 1: Data Preparation (Ingestion → Standardization)
# ─────────────────────────────────────────────────────────────────────────────

cat(">>> Running Phase 1: Data Preparation...\n")
cat("    Modules: 1-2 (Ingestion, Standardization)\n")
cat("    Output: kpro_master checkpoint\n\n")

result1 <- run_phase1_data_preparation(verbose = TRUE)

cat("\n✓ Phase 1 complete\n")
cat(sprintf("  Checkpoint: %s\n", result1$checkpoint_path))
cat(sprintf("  Rows: %d | Columns: %d\n", nrow(result1$kpro_master), ncol(result1$kpro_master)))
cat("\n")

# ─────────────────────────────────────────────────────────────────────────────
# Phase 2: Template Generation (CPN Template)
# ─────────────────────────────────────────────────────────────────────────────

cat(">>> Running Phase 2: Template Generation...\n")
cat("    Modules: 3 (CPN Template Generation)\n")
cat("    Input: result1 from Phase 1\n")
cat("    Output: CPN_Template_EDIT_THIS.csv and ORIGINAL\n\n")

result2 <- run_phase2_template_generation(
  phase1_result = result1,
  verbose = TRUE
)

cat("\n✓ Phase 2 complete\n")
cat(sprintf("  Template (EDIT): %s\n", result2$template_edit_path))
cat(sprintf("  Template (ORIGINAL): %s\n", result2$template_original_path))
cat("  ⚠ USER ACTION REQUIRED: Edit the CPN_Template_EDIT_THIS.csv file before Phase 3\n")
cat("\n")

# ─────────────────────────────────────────────────────────────────────────────
# Phase 3: Analysis & Reporting (Finalize → Report)
# ─────────────────────────────────────────────────────────────────────────────

cat(">>> Running Phase 3: Analysis & Reporting...\n")
cat("    Modules: 4-7 (Finalize CPN, Statistics, Plotting, Report)\n")
cat("    Input: result2 from Phase 2 (assumes template was edited)\n")
cat("    Output: HTML report, plots, CSV summaries, release bundle\n\n")

result3 <- run_phase3_analysis_reporting(
  phase2_result = result2,
  verbose = TRUE
)

cat("\n✓ Phase 3 complete\n")
cat(sprintf("  Report: %s\n", result3$report_path))
cat(sprintf("  Release Bundle: %s\n", result3$release_bundle_path))
cat("\n")

# ─────────────────────────────────────────────────────────────────────────────
# Phase Orchestration Summary
# ─────────────────────────────────────────────────────────────────────────────

cat("================================================================================\n")
cat("PHASE ORCHESTRATION COMPLETE\n")
cat("================================================================================\n")
cat(sprintf("Phase 1 Output: %d rows, %d columns\n", nrow(result1$kpro_master), ncol(result1$kpro_master)))
cat(sprintf("Phase 2 Output: Template with %s nights\n", result2$metadata$n_nights))
cat(sprintf("Phase 3 Output: Report + %d plots + release bundle\n", length(result3$metadata$all_plots)))
cat("\n")

# ==============================================================================
# SECTION 2: MODULE-LEVEL TESTING
# ==============================================================================
# Tests individual modules independently for development and debugging.
# Useful for isolating specific processing steps.
#
# NOTE: Module-level testing requires manual sourcing of module_runner.R
# to access the module execution layer functions.

cat("\n")
cat("================================================================================\n")
cat("SECTION 2: MODULE-LEVEL TESTING (Individual Modules)\n")
cat("================================================================================\n")
cat("\nNOTE: Uncomment the code blocks below to test individual modules.\n")
cat("This section is useful for development and debugging.\n\n")

# Uncomment and run as needed:

# ─────────────────────────────────────────────────────────────────────────────
# Test Module 1: Data Ingestion
# ─────────────────────────────────────────────────────────────────────────────
# cat("\n>>> Testing Module 1: Data Ingestion...\n")
# source(here("R", "modules", "module_runner.R"))
# m1_result <- run_module_ingestion(verbose = TRUE)
# cat(sprintf("✓ Module 1 complete: %d rows\n", nrow(m1_result$raw_data)))

# ─────────────────────────────────────────────────────────────────────────────
# Test Module 2: Data Standardization
# ─────────────────────────────────────────────────────────────────────────────
# cat("\n>>> Testing Module 2: Data Standardization...\n")
# source(here("R", "modules", "module_runner.R"))
# m2_result <- run_module_standardization(m1_result, verbose = TRUE)
# cat(sprintf("✓ Module 2 complete: %d rows\n", nrow(m2_result$kpro_master)))

# ─────────────────────────────────────────────────────────────────────────────
# Test Module 3: CPN Template Generation
# ─────────────────────────────────────────────────────────────────────────────
# cat("\n>>> Testing Module 3: CPN Template...\n")
# source(here("R", "modules", "module_runner.R"))
# m3_result <- run_module_cpn_template(m2_result, verbose = TRUE)
# cat(sprintf("✓ Module 3 complete: %d nights\n", m3_result$metadata$n_nights))

# ─────────────────────────────────────────────────────────────────────────────
# Test Module 4: Finalize CPN
# ─────────────────────────────────────────────────────────────────────────────
# cat("\n>>> Testing Module 4: Finalize CPN...\n")
# source(here("R", "modules", "module_runner.R"))
# m4_result <- run_module_finalize_cpn(m3_result, verbose = TRUE)
# cat(sprintf("✓ Module 4 complete: %d rows\n", nrow(m4_result$calls_per_night_final)))

# ─────────────────────────────────────────────────────────────────────────────
# Test Module 5: Summary Statistics
# ─────────────────────────────────────────────────────────────────────────────
# cat("\n>>> Testing Module 5: Summary Statistics...\n")
# source(here("R", "modules", "module_runner.R"))
# m5_result <- run_module_summary_stats(m4_result, verbose = TRUE)
# cat("✓ Module 5 complete: Summary statistics generated\n")

# ─────────────────────────────────────────────────────────────────────────────
# Test Module 6: Plotting
# ─────────────────────────────────────────────────────────────────────────────
# cat("\n>>> Testing Module 6: Plotting...\n")
# source(here("R", "modules", "module_runner.R"))
# m6_result <- run_module_plotting(m4_result, verbose = TRUE)
# cat(sprintf("✓ Module 6 complete: %d plots generated\n", length(m6_result$all_plots)))

# ─────────────────────────────────────────────────────────────────────────────
# Test Module 7: Report & Release
# ─────────────────────────────────────────────────────────────────────────────
# cat("\n>>> Testing Module 7: Report & Release...\n")
# source(here("R", "modules", "module_runner.R"))
# m7_result <- run_module_report_release(
# cat("✓ Module 7 complete: Report and release bundle generated\n")

cat("================================================================================\n")
cat("END OF TEST HARNESS\n")
cat("================================================================================\n\n")
