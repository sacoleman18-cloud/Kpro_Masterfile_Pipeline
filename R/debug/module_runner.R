# ==============================================================================
# R/debug/module_runner.R
# ==============================================================================
# PURPOSE
# -------
# Debug and testing runner for individual pipeline modules. Allows executing
# modules one at a time for development, testing, and debugging purposes.
#
# USAGE
# -----
# # Source this file to load all modules
# source("R/debug/module_runner.R")
#
# # Run individual modules:
# result1 <- run_module_ingestion(verbose = TRUE)
# result2 <- run_module_standardization(result1, verbose = TRUE)
# result3 <- run_module_cpn_template(result2, verbose = TRUE)
# result4 <- run_module_finalize_cpn(result3, verbose = TRUE)
# result5 <- run_module_summary_stats(result4, verbose = TRUE)
# result6 <- run_module_plotting(result5, verbose = TRUE)
# result7 <- run_module_report_release(result6, verbose = TRUE)
#
# MODULES AVAILABLE
# -----------------
# MODULE 1: Data Ingestion (Stages 1-2)
# MODULE 2: Data Standardization (Stages 3-8)
# MODULE 3: CPN Template (Stages 1-9)
# MODULE 4: Finalize CPN (Stages 1-6)
# MODULE 5: Summary Statistics (Stages 7-16)
# MODULE 6: Plotting (Stages 15-21)
# MODULE 7: Report & Release (Stages 22-25)
#
# NOTES
# -----
# - Each function returns results compatible with the next module's input
# - Use verbose = TRUE for detailed progress messages
# - Modules can be run independently if you have intermediate results
# - Checkpoint files will be saved as usual during module execution
#
# ==============================================================================

# Load all utilities and modules
source(file.path("R", "functions", "load_all.R"))

cat("\n")
cat("===============================================\n")
cat("  KPro Pipeline Module Runner (Debug Mode)\n")
cat("===============================================\n")
cat("\n")
cat("Available modules:\n")
cat("  1. run_module_ingestion()\n")
cat("  2. run_module_standardization(ingestion_result)\n")
cat("  3. run_module_cpn_template(standardization_result)\n")
cat("  4. run_module_finalize_cpn(cpn_template_result)\n")
cat("  5. run_module_summary_stats(finalize_result)\n")
cat("  6. run_module_plotting(summary_stats_result)\n")
cat("  7. run_module_report_release(plotting_result)\n")
cat("\n")
cat("Example workflow:\n")
cat("  r1 <- run_module_ingestion(verbose = TRUE)\n")
cat("  r2 <- run_module_standardization(r1, verbose = TRUE)\n")
cat("  r3 <- run_module_cpn_template(r2, verbose = TRUE)\n")
cat("  # ... continue with remaining modules\n")
cat("\n")
cat("===============================================\n")
cat("\n")


# ==============================================================================
# MODULE 1: DATA INGESTION
# ==============================================================================

#' Run Module: Data Ingestion
#'
#' @description
#' Execute data ingestion module independently for debugging/testing.
#' Loads raw CSV files from local and external sources.
#'
#' @param verbose Logical. Print detailed progress.
#'
#' @return Module result with raw_data, study_params, validation_context
#'
#' @export
run_module_ingestion <- function(verbose = FALSE) {
  cat("\n>>> Running MODULE 1: Data Ingestion\n\n")
  
  result <- module_data_ingestion(verbose = verbose)
  
  cat(sprintf("\n✓ Module complete: %d rows loaded from %d source(s)\n",
              result$metadata$total_rows,
              result$metadata$sources_count))
  
  return(result)
}


# ==============================================================================
# MODULE 2: DATA STANDARDIZATION
# ==============================================================================

#' Run Module: Data Standardization
#'
#' @description
#' Execute data standardization module independently for debugging/testing.
#' Transforms raw data into standardized kpro_master format.
#'
#' @param ingestion_result Result from run_module_ingestion() or NULL to use defaults.
#' @param verbose Logical. Print detailed progress.
#'
#' @return Module result with kpro_master
#'
#' @export
run_module_standardization <- function(ingestion_result = NULL, verbose = FALSE) {
  cat("\n>>> Running MODULE 2: Data Standardization\n\n")
  
  # If no ingestion result provided, run ingestion first
  if (is.null(ingestion_result)) {
    cat("  [!] No ingestion result provided - running ingestion first...\n\n")
    ingestion_result <- run_module_ingestion(verbose = verbose)
  }
  
  result <- module_data_standardization(
    raw_data = ingestion_result$raw_data,
    study_params = ingestion_result$study_params,
    validation_context = ingestion_result$validation_context,
    ingestion_metadata = ingestion_result$metadata,
    verbose = verbose
  )
  
  cat(sprintf("\n✓ Module complete: %d rows, %d detectors\n",
              result$standardization$metadata$n_rows,
              result$standardization$metadata$n_detectors))
  
  return(result)
}


# ==============================================================================
# MODULE 3: CPN TEMPLATE
# ==============================================================================

#' Run Module: CPN Template
#'
#' @description
#' Execute CPN template generation module independently for debugging/testing.
#' Generates CallsPerNight template grid.
#'
#' @param standardization_result Result from run_module_standardization() or NULL to use checkpoint.
#' @param manual_id_file Character. Path to manual ID file (optional).
#' @param verbose Logical. Print detailed progress.
#'
#' @return Module result with cpn_template
#'
#' @export
run_module_cpn_template <- function(standardization_result = NULL,
                                    manual_id_file = NULL,
                                    verbose = FALSE) {
  cat("\n>>> Running MODULE 3: CPN Template\n\n")
  
  # Extract kpro_master if provided
  kpro_master <- NULL
  if (!is.null(standardization_result)) {
    kpro_master <- standardization_result$standardization$kpro_master
  }
  
  result <- module_cpn_template(
    kpro_master = kpro_master,
    manual_id_file = manual_id_file,
    study_params = NULL,  # Will be loaded by module
    verbose = verbose
  )
  
  cat(sprintf("\n✓ Module complete: %d rows, %d nights\n",
              result$metadata$n_rows,
              result$metadata$n_nights))
  cat(sprintf("  EDIT THIS FILE: %s\n", basename(result$template_edit_path)))
  
  return(result)
}


# ==============================================================================
# MODULE 4: FINALIZE CPN
# ==============================================================================

#' Run Module: Finalize CPN
#'
#' @description
#' Execute finalize CPN module independently for debugging/testing.
#' Loads edited template and finalizes CPN calculations.
#'
#' @param cpn_template_result Result from run_module_cpn_template() or NULL to use checkpoint.
#' @param edited_template_file Character. Path to edited template file (optional).
#' @param verbose Logical. Print detailed progress.
#'
#' @return Module result with calls_per_night_final
#'
#' @export
run_module_finalize_cpn <- function(cpn_template_result = NULL,
                                    edited_template_file = NULL,
                                    verbose = FALSE) {
  cat("\n>>> Running MODULE 4: Finalize CPN\n\n")
  
  # Extract kpro_master if provided
  kpro_master <- NULL
  # Note: finalize_cpn module will load from checkpoint if not provided
  
  # Load study parameters
  study_params <- load_study_parameters(here::here("inst", "config", "study_parameters.yaml"))
  registry <- list()
  
  result <- finalize_cpn(
    kpro_master = kpro_master,
    edited_template_file = edited_template_file,
    study_params = study_params,
    registry = registry,
    verbose = verbose
  )
  
  cat(sprintf("\n✓ Module complete: %d rows finalized\n",
              nrow(result$finalize_cpn$calls_per_night_final)))
  
  return(result)
}


# ==============================================================================
# MODULE 5: SUMMARY STATISTICS
# ==============================================================================

#' Run Module: Summary Statistics
#'
#' @description
#' Execute summary statistics module independently for debugging/testing.
#' Generates comprehensive summary tables.
#'
#' @param finalize_result Result from run_module_finalize_cpn().
#' @param verbose Logical. Print detailed progress.
#'
#' @return Module result with all_summaries
#'
#' @export
run_module_summary_stats <- function(finalize_result, verbose = FALSE) {
  cat("\n>>> Running MODULE 5: Summary Statistics\n\n")
  
  # Load study parameters
  study_params <- load_study_parameters(here::here("inst", "config", "study_parameters.yaml"))
  registry <- list()
  
  # Load kpro_master from checkpoint
  kpro_master <- load_most_recent_checkpoint("02_kpro_master_.*\\.csv$")
  study_tz <- study_params$study_parameters$timezone %||% "America/Chicago"
  kpro_master <- parse_datetime_columns(kpro_master, target_tz = study_tz, verbose = verbose)
  
  result <- module_summary_stats(
    calls_per_night_final = finalize_result$finalize_cpn$calls_per_night_final,
    kpro_master = kpro_master,
    study_params = study_params,
    registry = registry,
    verbose = verbose
  )
  
  cat(sprintf("\n✓ Module complete: %d summaries generated\n",
              length(result$summary_stats$all_summaries)))
  
  return(result)
}


# ==============================================================================
# MODULE 6: PLOTTING
# ==============================================================================

#' Run Module: Plotting
#'
#' @description
#' Execute plotting module independently for debugging/testing.
#' Generates all quality, detector, species, and temporal plots.
#'
#' @param summary_stats_result Result from run_module_summary_stats().
#' @param verbose Logical. Print detailed progress.
#'
#' @return Module result with all_plots
#'
#' @export
run_module_plotting <- function(summary_stats_result, verbose = FALSE) {
  cat("\n>>> Running MODULE 6: Plotting\n\n")
  
  # Load study parameters
  study_params <- load_study_parameters(here::here("inst", "config", "study_parameters.yaml"))
  registry <- list()
  
  # Load kpro_master from checkpoint
  kpro_master <- load_most_recent_checkpoint("02_kpro_master_.*\\.csv$")
  study_tz <- study_params$study_parameters$timezone %||% "America/Chicago"
  kpro_master <- parse_datetime_columns(kpro_master, target_tz = study_tz, verbose = verbose)
  
  # Load calls_per_night_final from checkpoint
  calls_per_night_final <- load_cpn_final(verbose = verbose)
  
  result <- module_plotting(
    calls_per_night_final = calls_per_night_final,
    kpro_master = kpro_master,
    study_params = study_params,
    registry = registry,
    verbose = verbose
  )
  
  cat(sprintf("\n✓ Module complete: %d total plots generated\n",
              sum(unlist(result$plotting$plot_counts))))
  
  return(result)
}


# ==============================================================================
# MODULE 7: REPORT & RELEASE
# ==============================================================================

#' Run Module: Report & Release
#'
#' @description
#' Execute report & release module independently for debugging/testing.
#' Renders Quarto report and creates release bundle.
#'
#' @param plotting_result Result from run_module_plotting().
#' @param summary_stats_result Result from run_module_summary_stats().
#' @param verbose Logical. Print detailed progress.
#'
#' @return Module result with report paths
#'
#' @export
run_module_report_release <- function(plotting_result,
                                      summary_stats_result,
                                      verbose = FALSE) {
  cat("\n>>> Running MODULE 7: Report & Release\n\n")
  
  # Load study parameters
  study_params <- load_study_parameters(here::here("inst", "config", "study_parameters.yaml"))
  registry <- list()
  
  # Load kpro_master from checkpoint
  kpro_master <- load_most_recent_checkpoint("02_kpro_master_.*\\.csv$")
  study_tz <- study_params$study_parameters$timezone %||% "America/Chicago"
  kpro_master <- parse_datetime_columns(kpro_master, target_tz = study_tz, verbose = verbose)
  
  # Load calls_per_night_final from checkpoint
  calls_per_night_final <- load_cpn_final(verbose = verbose)
  
  result <- module_report_release(
    calls_per_night_final = calls_per_night_final,
    kpro_master = kpro_master,
    all_summaries = summary_stats_result$summary_stats$all_summaries,
    all_plots = plotting_result$plotting$all_plots,
    summary_rds_path = summary_stats_result$summary_stats$summary_rds,
    plots_rds_path = plotting_result$plotting$plots_rds,
    study_params = study_params,
    yaml_path = here::here("inst", "config", "study_parameters.yaml"),
    create_release_bundle = TRUE,
    registry = registry,
    verbose = verbose
  )
  
  cat("\n✓ Module complete: Report and release bundle generated\n")
  
  return(result)
}


# ==============================================================================
# CONVENIENCE FUNCTION: RUN ALL MODULES
# ==============================================================================

#' Run All Pipeline Modules in Sequence
#'
#' @description
#' Execute complete pipeline by running all 7 modules in sequence.
#' Useful for full end-to-end testing.
#'
#' @param verbose Logical. Print detailed progress.
#'
#' @return List with all module results
#'
#' @export
run_all_modules <- function(verbose = FALSE) {
  cat("\n")
  cat("===============================================\n")
  cat("  Running ALL Pipeline Modules\n")
  cat("===============================================\n")
  
  # Module 1: Ingestion
  r1 <- run_module_ingestion(verbose = verbose)
  
  # Module 2: Standardization
  r2 <- run_module_standardization(r1, verbose = verbose)
  
  # Module 3: CPN Template
  r3 <- run_module_cpn_template(r2, verbose = verbose)
  
  # Module 4: Finalize CPN
  # Note: User may need to edit template before running this
  cat("\n")
  cat("==============================================\n")
  cat("  PAUSE: Edit CPN template before continuing\n")
  cat("==============================================\n")
  cat(sprintf("  Edit this file: %s\n", basename(r3$template_edit_path)))
  cat("  Press ENTER when ready to continue...\n")
  readline()
  
  r4 <- run_module_finalize_cpn(r3, verbose = verbose)
  
  # Module 5: Summary Statistics
  r5 <- run_module_summary_stats(r4, verbose = verbose)
  
  # Module 6: Plotting
  r6 <- run_module_plotting(r5, verbose = verbose)
  
  # Module 7: Report & Release
  r7 <- run_module_report_release(r6, r5, verbose = verbose)
  
  cat("\n")
  cat("===============================================\n")
  cat("  ALL MODULES COMPLETE\n")
  cat("===============================================\n")
  cat("\n")
  
  list(
    ingestion = r1,
    standardization = r2,
    cpn_template = r3,
    finalize_cpn = r4,
    summary_stats = r5,
    plotting = r6,
    report_release = r7
  )
}


# ==============================================================================
# END OF FILE
# ==============================================================================
