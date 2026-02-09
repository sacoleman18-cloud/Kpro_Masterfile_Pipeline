# =============================================================================
# UTILITY: release.R - Study Release Bundle Generator
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# - Generates portable release bundles for downstream projects
# - Used by modules in R/modules/
# PURPOSE
# -------
# Creates portable, self-contained release bundles (zip files) that can be
# consumed by downstream projects (e.g., NB GAMM Bat project) without any
# renaming or manual formatting steps. 
#
# DEPENDENCIES
# ------------
# R Packages:
#   - yaml:  Manifest generation
#   - zip: Cross-platform zip creation
#   - digest:  File hashing
#   - here: Path management
#
# Internal Dependencies:
#   - core/artifacts.R: hash_file(), register_artifact()
#
# FUNCTIONS PROVIDED
# ------------------
#
# Bundle Creation - Main entry point:
#
#   - create_release_bundle():
#       Uses packages: zip (zip_file), yaml (write_yaml), here (here),
#                      base R (file operations, dir.create)
#       Calls internal: release.R (validate_release_inputs, generate_manifest),
#                       artifacts.R (init_artifact_registry, register_artifact),
#                       utilities.R (ensure_dir_exists)
#       Purpose: Create portable zip bundle with all pipeline outputs
#
# Validation - Check bundle preconditions:
#
#   - validate_release_inputs():
#       Uses packages: base R (is.data.frame, file.exists, nrow)
#       Calls internal: none (input validation)
#       Purpose: Validate all input files and data frame structures
#
# Manifest - Generate provenance documentation:
#
#   - generate_manifest():
#       Uses packages: yaml (as.yaml), base R (list operations, Sys.time),
#                      digest (sha256 via artifacts.R)
#       Calls internal: artifacts.R (hash_file, hash_dataframe)
#       Purpose: Create manifest.yaml with file hashes and provenance metadata
#
# USAGE
# -----
# source("R/functions/core/release.R")
# zip_path <- create_release_bundle(
#   study_id = "SchmeeckleBatStudy",
#   calls_per_night_final = cpn_final,
#   kpro_master = master,
#   all_summaries = summaries,
#   all_plots = plots,
#   report_path = "results/reports/bat_activity_report.html"
# )
#
# Last Modified: 2026-02-09
#
# CHANGELOG
# ---------
# 2026-02-01: Verified deterministic behavior - no code-level variability parameters
# 2026-02-08: Confirmed integration with run_phase3_analysis_reporting() (Phase 3, Module 7)
# 2026-01-12: Initial version
# =============================================================================

library(yaml)
library(here)

# Check for zip package
if (!requireNamespace("zip", quietly = TRUE)) {
  stop("Package 'zip' is required for release bundle creation.\n",
       "  Install with: install.packages('zip')")
}

library(zip)

# =============================================================================
# CONSTANTS
# =============================================================================

RELEASE_DIR <- here::here("results", "releases")

# =============================================================================
# MAIN BUNDLE CREATION
# =============================================================================

#' Create Study Release Bundle
#'
#' @description
#' Creates a portable, self-contained zip file containing all pipeline outputs
#' in a standardized structure.  This zip can be directly consumed by downstream
#' projects (e.g., NB GAMM Bat project) without any renaming. 
#'
#' @param study_id Character. Study identifier (used in zip filename)
#' @param calls_per_night_final Data frame. Final CPN data from Module 4
#' @param kpro_master Data frame. Master detection file from Module 2
#' @param all_summaries List. Summary data from Module 5 (optional)
#' @param all_plots List. Plot objects from Module 6 (optional)
#' @param report_path Character. Path to rendered HTML report (optional)
#' @param study_params List. Study parameters from YAML (optional, auto-loaded)
#' @param output_dir Character. Directory for output zip
#' @param registry List.  Artifact registry (optional, auto-loaded)
#' @param quiet Logical.  Suppress messages if TRUE
#'
#' @return Character. Path to created zip file
#'
#' @section RELEASE STRUCTURE:
#' The zip contains: 
#' ```
#' kpro_release_<study_id>_<timestamp>/
#' |-- manifest.yaml
#' |-- data/
#' |   |-- calls_per_night_raw.csv      <- GAMM project input
#' |   |-- kpro_master.csv
#' |   `-- summary/
#' |       |-- detector_summary.csv
#' |       `-- ...
#' |-- figures/
#' |   |-- quality/
#' |   |-- detector/
#' |   |-- species/
#' |   `-- temporal/
#' |-- report/
#' |   `-- kpro_report.html
#' `-- analysis_bundle.rds
#' ```
#'
#' @section CONTRACT:
#' - Creates immutable, portable zip file
#' - Includes manifest.yaml with full provenance
#' - Computes SHA256 hashes for key files
#' - Registers bundle in artifact registry
#'
#' @export
create_release_bundle <- function(study_id,
                                  calls_per_night_final,
                                  kpro_master,
                                  all_summaries = NULL,
                                  all_plots = NULL,
                                  report_path = NULL,
                                  study_params = NULL,
                                  output_dir = RELEASE_DIR,
                                  registry = NULL,
                                  quiet = FALSE) {
  
  # -------------------------
  # Setup
  # -------------------------
  
  if (!quiet) message("\n[*] Creating Study Release Bundle...")
  
  # Load study params if not provided
  if (is.null(study_params)) {
    params_path <- here:: here("inst", "config", "study_parameters.yaml")
    if (file.exists(params_path)) {
      study_params <- yaml::read_yaml(params_path)
    }
  }
  
  # Load registry if not provided
  if (is.null(registry)) {
    registry <- init_artifact_registry()
  }
  
  # Generate release identifiers
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  release_name <- sprintf("kpro_release_%s_%s", study_id, timestamp)
  
  # Create staging directory
  staging_dir <- file.path(tempdir(), release_name)
  if (dir.exists(staging_dir)) unlink(staging_dir, recursive = TRUE)
  
  # Create directory structure
  dirs_to_create <- c(
    file.path(staging_dir, "data"),
    file.path(staging_dir, "data", "summary"),
    file.path(staging_dir, "figures", "quality"),
    file.path(staging_dir, "figures", "detector"),
    file.path(staging_dir, "figures", "species"),
    file.path(staging_dir, "figures", "temporal"),
    file.path(staging_dir, "report")
  )
  
  for (d in dirs_to_create) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
  }
  
  if (!quiet) message("  [OK] Created staging directory structure")
  
  # -------------------------
  # Validate inputs
  # -------------------------
  
  validation_result <- validate_release_inputs(
    calls_per_night_final = calls_per_night_final,
    kpro_master = kpro_master
  )
  
  if (!validation_result$valid) {
    stop(sprintf("Release validation failed:\n  %s", 
                 paste(validation_result$errors, collapse = "\n  ")))
  }
  
  if (!quiet) message("  [OK] Input validation passed")
  
  # -------------------------
  # Write data files
  # -------------------------
  
  # calls_per_night_raw.csv - THE KEY FILE for GAMM project
  cpn_path <- file.path(staging_dir, "data", "calls_per_night_raw.csv")
  readr::write_csv(calls_per_night_final, cpn_path)
  
  # kpro_master.csv
  master_path <- file.path(staging_dir, "data", "kpro_master.csv")
  readr::write_csv(kpro_master, master_path)
  
  if (!quiet) message("  [OK] Wrote core data files")
  
  # Summary CSVs (if provided)
  if (!is.null(all_summaries)) {
    if (!is.null(all_summaries$detector_summary)) {
      readr::write_csv(
        all_summaries$detector_summary,
        file.path(staging_dir, "data", "summary", "detector_summary.csv")
      )
    }
    if (!is.null(all_summaries$study_summary)) {
      # Convert single-row tibble to data frame for CSV
      readr::write_csv(
        as.data.frame(all_summaries$study_summary),
        file.path(staging_dir, "data", "summary", "study_summary.csv")
      )
    }
    if (!is.null(all_summaries$species_summary)) {
      readr::write_csv(
        all_summaries$species_summary,
        file.path(staging_dir, "data", "summary", "species_summary.csv")
      )
    }
    if (!is.null(all_summaries$hourly_summary_overall)) {
      readr::write_csv(
        all_summaries$hourly_summary_overall,
        file.path(staging_dir, "data", "summary", "hourly_summary.csv")
      )
    }
    if (!quiet) message("  [OK] Wrote summary CSVs")
  }
  
  # -------------------------
  # Copy figures
  # -------------------------
  
  figures_copied <- 0
  
  if (!is.null(all_plots)) {
    for (category in names(all_plots)) {
      if (length(all_plots[[category]]) > 0) {
        for (plot_name in names(all_plots[[category]])) {
          # Save each plot as PNG
          plot_path <- file.path(staging_dir, "figures", category, 
                                 sprintf("%s.png", plot_name))
          ggplot2::ggsave(
            plot_path, 
            all_plots[[category]][[plot_name]],
            width = 10, height = 6, dpi = 150, bg = "white"
          )
          figures_copied <- figures_copied + 1
        }
      }
    }
    if (!quiet) message(sprintf("  [OK] Saved %d figures", figures_copied))
  }
  
  # -------------------------
  # Copy report
  # -------------------------
  
  if (!is.null(report_path) && file.exists(report_path)) {
    file.copy(
      report_path,
      file.path(staging_dir, "report", "kpro_report.html")
    )
    if (!quiet) message("  [OK] Copied HTML report")
  }
  
  # -------------------------
  # Write analysis_bundle.rds
  # -------------------------
  
  analysis_bundle <- list(
    data = list(
      calls_per_night = calls_per_night_final,
      kpro_master = kpro_master
    ),
    summaries = all_summaries,
    plots = all_plots,
    metadata = list(
      study_id = study_id,
      release_name = release_name,
      created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      pipeline_version = PIPELINE_VERSION,
      n_detectors = dplyr::n_distinct(calls_per_night_final$Detector),
      n_nights = dplyr:: n_distinct(calls_per_night_final$Night),
      n_calls = nrow(kpro_master)
    )
  )
  
  rds_path <- file.path(staging_dir, "analysis_bundle.rds")
  saveRDS(analysis_bundle, rds_path)
  
  if (!quiet) message("  [OK] Created analysis_bundle.rds")
  
  # -------------------------
  # Generate manifest
  # -------------------------
  
  manifest <- generate_manifest(
    release_name = release_name,
    study_id = study_id,
    study_params = study_params,
    staging_dir = staging_dir,
    cpn_path = cpn_path,
    master_path = master_path,
    n_figures = figures_copied
  )
  
  manifest_path <- file.path(staging_dir, "manifest.yaml")
  yaml::write_yaml(manifest, manifest_path)
  
  if (!quiet) message("  [OK] Generated manifest.yaml")
  
  # -------------------------
  # Create zip
  # -------------------------
  
  # Ensure output directory exists
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  
  zip_path <- file.path(output_dir, paste0(release_name, ".zip"))
  
  # CRITICAL FIX for Windows: Use relative paths to avoid colon issues
  # Change to parent directory of staging_dir temporarily
  old_wd <- getwd()
  setwd(dirname(staging_dir))
  
  # Ensure we return to original directory even if error occurs
  on.exit(setwd(old_wd), add = TRUE)
  
  # Zip the release folder with all its contents
  zip::zip(
    zipfile = zip_path,
    files = basename(staging_dir),  # Just the folder name (relative path)
    recurse = TRUE                   # Include all contents recursively
  )
  
  if (!quiet) message(sprintf("  [OK] Created zip: %s", basename(zip_path)))
  
  # -------------------------
  # Register artifact
  # -------------------------
  
  # Count total files in the release bundle
  n_files_in_bundle <- length(list.files(staging_dir, recursive = TRUE))
  
  registry <- register_artifact(
    registry = registry,
    artifact_name = release_name,
    artifact_type = "release_bundle",
    workflow = "release",
    file_path = zip_path,
    input_artifacts = c("kpro_master", "cpn_final"),
    metadata = list(
      study_id = study_id,
      n_files = n_files_in_bundle,
      zip_size_bytes = file.info(zip_path)$size
    ),
    quiet = quiet
  )
  
  # -------------------------
  # Cleanup
  # -------------------------
  
  unlink(staging_dir, recursive = TRUE)
  
  # -------------------------
  # Summary
  # -------------------------
  
  zip_size_mb <- round(file.info(zip_path)$size / 1024 / 1024, 2)
  
  if (!quiet) {
    message("\n===============================================")
    message("|     STUDY RELEASE BUNDLE CREATED          |")
    message("===============================================")
    message(sprintf("\n[*] %s", basename(zip_path)))
    message(sprintf("   Size: %.2f MB", zip_size_mb))
    message(sprintf("   Location: %s", output_dir))
    message("\n[*] Contents:")
    message("   - manifest.yaml (provenance)")
    message("   - data/calls_per_night_raw.csv (GAMM input)")
    message("   - data/kpro_master.csv")
    message(sprintf("   - %d summary CSVs", 
                    length(list.files(file.path(staging_dir, "data", "summary")))))
    message(sprintf("   - %d figures", figures_copied))
    message("   - report/kpro_report.html")
    message("   - analysis_bundle.rds")
    message("\n[OK] Ready for NB GAMM project import")
  }
  
  invisible(zip_path)
}


#' Validate Release Inputs
#'
#' @description
#' Validates all required inputs before creating release bundle. 
#'
#' @param calls_per_night_final Data frame. CPN data
#' @param kpro_master Data frame. Master data
#'
#' @return List with `valid` (logical) and `errors` (character vector)
#'
#' @export
validate_release_inputs <- function(calls_per_night_final, kpro_master) {
  
  errors <- character()
  
  # -------------------------
  # Validate calls_per_night_final
  # -------------------------
  
  required_cpn <- c("Detector", "Night", "CallsPerNight", "RecordingHours")
  missing_cpn <- setdiff(required_cpn, names(calls_per_night_final))
  
  if (length(missing_cpn) > 0) {
    errors <- c(errors, sprintf(
      "calls_per_night_final missing required columns: %s",
      paste(missing_cpn, collapse = ", ")
    ))
  }
  
  if (!inherits(calls_per_night_final$Night, "Date")) {
    errors <- c(errors, "calls_per_night_final$Night must be Date class")
  }
  
  if (any(is.na(calls_per_night_final$Detector))) {
    errors <- c(errors, "calls_per_night_final$Detector contains NA values")
  }
  
  # -------------------------
  # Validate kpro_master
  # -------------------------
  
  required_master <- c("Detector", "DateTime_local", "auto_id")
  missing_master <- setdiff(required_master, names(kpro_master))
  
  if (length(missing_master) > 0) {
    errors <- c(errors, sprintf(
      "kpro_master missing required columns: %s",
      paste(missing_master, collapse = ", ")
    ))
  }
  
  list(
    valid = length(errors) == 0,
    errors = errors
  )
}


#' Generate Release Manifest
#'
#' @description
#' Creates the manifest.yaml file with full provenance information. 
#'
#' @param release_name Character. Release identifier
#' @param study_id Character.  Study identifier
#' @param study_params List. Study parameters
#' @param staging_dir Character. Path to staging directory
#' @param cpn_path Character. Path to CPN CSV
#' @param master_path Character. Path to master CSV
#' @param n_figures Numeric. Number of figures
#'
#' @return List.  Manifest structure
#'
#' @keywords internal
generate_manifest <- function(release_name,
                              study_id,
                              study_params,
                              staging_dir,
                              cpn_path,
                              master_path,
                              n_figures) {
  
  list(
    release = list(
      name = release_name,
      created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      pipeline_version = PIPELINE_VERSION,
      r_version = paste(R.version$major, R.version$minor, sep = ".")
    ),
    
    study = list(
      study_id = study_id,
      study_name = study_params$study_parameters$study_name %||% study_id,
      start_date = as.character(study_params$study_parameters$start_date),
      end_date = as.character(study_params$study_parameters$end_date),
      timezone = study_params$study_parameters$timezone %||% "Unknown"
    ),
    
    artifacts = list(
      data = list(
        list(
          path = "data/calls_per_night_raw.csv",
          description = "Detector --- Night grid for GAMM modeling",
          sha256 = hash_file(cpn_path)
        ),
        list(
          path = "data/kpro_master.csv",
          description = "Standardized master detection file",
          sha256 = hash_file(master_path)
        )
      ),
      figures = list(
        count = n_figures,
        categories = c("quality", "detector", "species", "temporal")
      ),
      report = list(
        path = "report/kpro_report.html"
      ),
      bundle = list(
        path = "analysis_bundle.rds",
        description = "All R objects for programmatic access"
      )
    ),
    
    validation = list(
      calls_per_night_schema_valid = TRUE,
      manifest_generated = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )
  )
}