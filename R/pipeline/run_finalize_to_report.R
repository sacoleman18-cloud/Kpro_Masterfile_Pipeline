# ============================================================================
# ORCHESTRATOR: run_finalize_to_report_REFACTORED.R
# Purpose: Pipeline entry point for Chunk 3 (Finalize CPN Template → Report)
# Chunk: 3
# Module Stages: Summary Statistics → Plotting → Report Release
# ============================================================================
# 
# Classification: Pipeline Orchestrator
# Subtitle: Central hub coordinating finalization, statistics, visualization, and report release
#
# Description:
# This orchestrator coordinates the complete finalization workflow from CPN 
# template preparation through final report release. It manages the execution
# of three processing modules in sequence and handles inter-module dependencies.
#
# Data Flow:
#   Input:  Finalized CPN template (from Chunk 2 - kpro_master)
#   ├─→ Stage 1-6: finalize_cpn() → calls_per_night_final
#   ├─→ Stage 7-16: module_summary_stats() → all_summaries, summary_rds_path
#   ├─→ Stage 15-21: module_plotting() → all_plots, plots_rds_path
#   ├─→ Stage 22-25: module_report_release() → Final report release
#   Output: Release-ready report artifacts with metadata
#
# Module Stages:
#   Stage 1-6: Finalize CPN template (finalize_cpn module)
#   Stage 7-16: Generate summary statistics (module_summary_stats)
#   Stage 15-21: Create visualizations (module_plotting)
#   Stage 22-25: Generate report and release artifacts (module_report_release)
#
# Dependencies:
#   - R/functions/load_all.R (master loader)
#   - R/modules/finalize_cpn.R (finalization module)
#   - R/modules/summary_stats.R (statistics module)
#   - R/modules/plotting.R (visualization module)
#   - R/modules/report_release.R (release coordination module)
#
# Last Modified: 2024
# Note: REFACTORED version - uses modularized approach with DRY helper functions
#
# ============================================================================

# ============================================================================
# STAGE 1: INITIALIZATION AND UTILITY LOADING
# ============================================================================

# Load all utilities, configurations, and module loaders
source(file.path("R", "functions", "load_all.R"))

# Verify module availability
required_modules <- c("finalize_cpn", "module_summary_stats", "module_plotting", "module_report_release")
missing_modules <- required_modules[!sapply(required_modules, function(x) exists(x) && is.function(get(x)))]
if (length(missing_modules) > 0) {
  stop("Missing modules: ", paste(missing_modules, collapse = ", "))
}

# Load study parameters and prepare inputs
study_params <- load_study_parameters(here::here("inst", "config", "study_parameters.yaml"))
registry <- list()
verbose <- TRUE

# ============================================================================
# STAGE 2: FINALIZE CPN TEMPLATE MODULE
# ============================================================================

cat("\n>>> [Chunk 3/Stages 1-6] Executing Finalize CPN Module...\n")

finalize_result <- tryCatch({
  finalize_cpn(
    kpro_master = kpro_master,           # From Chunk 2
    edited_template_file = NULL,
    study_params = study_params,
    registry = registry,
    verbose = verbose
  )
}, error = function(e) {
  stop("Finalize CPN module failed: ", e$message)
})

calls_per_night_final <- finalize_result$finalize_cpn$calls_per_night_final
cat("✓ Finalize CPN complete\n")

# ============================================================================
# STAGE 3: SUMMARY STATISTICS MODULE
# ============================================================================

cat("\n>>> [Chunk 3/Stages 7-16] Executing Summary Statistics Module...\n")

stats_result <- tryCatch({
  module_summary_stats(
    calls_per_night_final = calls_per_night_final,
    kpro_master = kpro_master,           # From Chunk 2
    study_params = study_params,
    registry = registry,
    verbose = verbose
  )
}, error = function(e) {
  stop("Summary Statistics module failed: ", e$message)
})

all_summaries <- stats_result$summary_stats$all_summaries
summary_rds_path <- stats_result$summary_stats$summary_rds
cat("✓ Summary Statistics complete\n")

# ============================================================================
# STAGE 4: PLOTTING AND VISUALIZATION MODULE
# ============================================================================

cat("\n>>> [Chunk 3/Stages 15-21] Executing Plotting Module...\n")

plot_result <- tryCatch({
  module_plotting(
    calls_per_night_final = calls_per_night_final,
    kpro_master = kpro_master,           # From Chunk 2
    study_params = study_params,
    registry = registry,
    verbose = verbose
  )
}, error = function(e) {
  stop("Plotting module failed: ", e$message)
})

all_plots <- plot_result$plotting$all_plots
plots_rds_path <- plot_result$plotting$plots_rds
cat("✓ Plotting complete\n")

# ============================================================================
# STAGE 5: REPORT GENERATION AND RELEASE MODULE
# ============================================================================

cat("\n>>> [Chunk 3/Stages 22-25] Executing Report Release Module...\n")

release_result <- tryCatch({
  module_report_release(
    calls_per_night_final = calls_per_night_final,
    kpro_master = kpro_master,           # From Chunk 2
    all_summaries = all_summaries,
    all_plots = all_plots,
    summary_rds_path = summary_rds_path,
    plots_rds_path = plots_rds_path,
    study_params = study_params,
    yaml_path = here::here("inst", "config", "study_parameters.yaml"),
    create_release_bundle = TRUE,
    registry = registry,
    verbose = verbose
  )
}, error = function(e) {
  stop("Report Release module failed: ", e$message)
})

cat("✓ Report Release complete\n")

# ============================================================================
# FINALIZATION
# ============================================================================

cat("\n>>> [Chunk 3] Finalization complete - Report artifacts ready\n")

# Return results for inspection if needed
list(
  finalize = finalize_result,
  stats = stats_result,
  plots = plot_result,
  release = release_result
)
