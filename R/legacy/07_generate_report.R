# ==============================================================================
# MAINLINE WORKFLOW: 07_generate_report_and_release.R
# ==============================================================================
# PURPOSE
# -------
# Final packaging workflow for the KPro Masterfile Pipeline. This workflow:
#   1. Loads all pre-computed analytical objects from Workflows 05-06
#   2. Renders a publication-grade Quarto report
#   3. Creates a portable release bundle for downstream projects
#   4. Generates a final validation report
#   5. Produces a comprehensive pipeline completion summary
#
# This workflow is READ-ONLY with respect to analysis - it performs no 
# computation, transformation, or plot generation. All analytical outputs
# come from Workflows 05-06.
#
# WORKFLOW POSITION
# -----------------
# This is Workflow 07 (final) in the processing pipeline:
#   01_ingest_raw_data.R      → Load & intro-standardize raw CSVs
#   02_standardize.R          → Transform to master schema
#   [OPTIONAL: Manual ID in Kaleidoscope]
#   03_generate_cpn_template.R → Generate template for editing
#   [USER: Edit template in Excel]
#   04_finalize_cpn.R         → Process edited template
#   05_summary_stats.R        → Generate summary statistics
#   06_exploratory_plots.R    → Generate exploratory plots
#   07_generate_report_and_release.R → [THIS SCRIPT] Package final outputs
#
# INPUTS
# ------
# RDS Files (from Workflows 05-06):
#   - results/rds/summary_data_YYYYMMDD.rds
#   - results/rds/plot_objects_YYYYMMDD.rds
#
# CSV Files (from Workflows 02, 04):
#   - outputs/final/Master_YYYYMMDD_HHMM.csv (or kpro_master in memory)
#   - results/csv/CallsPerNight_final_vN.csv (or in memory)
#
# Configuration:
#   - inst/config/study_parameters.yaml
#
# Template:
#   - reports/bat_activity_report.qmd
#
# OUTPUTS
# -------
# Report:
#   - results/reports/bat_activity_report_YYYYMMDD.html
#
# Release Bundle:
#   - results/releases/kpro_release_<study_id>_<timestamp>.zip
#
# Validation:
#   - results/validation/validation_07_YYYYMMDD.html
#
# Logs:
#   - logs/pipeline_log.txt (appended)
#
# PROCESSING STAGES
# -----------------
# Stage 7.1: Load Configuration
#   - Load study_parameters.yaml for report metadata
#   - Initialize validation context
#
# Stage 7.2: Load Pre-computed Objects
#   - Discover most recent RDS files from Workflows 05-06
#   - Load summary_data and plot_objects
#   - Validate required elements exist
#   - Load or discover CPN final and Master data
#
# Stage 7.3: Generate Quarto Report
#   - Render bat_activity_report.qmd with parameters
#   - Move output to results/reports/
#   - Register report artifact
#
# Stage 7.4: Create Release Bundle
#   - Package all outputs into portable zip
#   - Generate manifest with provenance
#   - Register bundle artifact
#
# Stage 7.5: Finalize Validation Report
#   - Generate validation HTML report
#   - Log all processing events
#
# Stage 7.6: Pipeline Complete Summary
#   - Console summary of all outputs
#   - Pipeline timing and statistics
#   - Next steps guidance
#
# DEPENDENCIES
# ------------
# R Packages (required):
#   - quarto: Report rendering
#   - yaml: Configuration loading
#   - here: Path management
#   - zip: Release bundle creation
#   - digest: File hashing
#   - readr: CSV I/O
#   - dplyr: Data manipulation
#
# Custom Functions (via load_all.R):
#   - core/utilities.R: log_message, find_most_recent_file, print_stage_header
#   - core/config.R: load_study_parameters
#   - output/artifacts.R: init_artifact_registry, register_artifact,
#                         create_validation_context, log_validation_event,
#                         finalize_validation_report, discover_pipeline_rds,
#                         validate_rds_structure
#   - output/report.R: generate_quarto_report
#   - output/release.R: create_release_bundle
#
# TROUBLESHOOTING
# ---------------
# Issue: "No summary_data RDS file found"
# Fix: Run Workflow 05 first
#
# Issue: "No plot_objects RDS file found"
# Fix: Run Workflow 06 first
#
# Issue: "Quarto template not found"
# Fix: Ensure reports/bat_activity_report.qmd exists
#
# Issue: "quarto not found"
# Fix: Install Quarto CLI (https://quarto.org/docs/get-started/)
#      Then install R package: install.packages("quarto")
#
# Issue: "CallsPerNight data not found"
# Fix: Run Workflow 04 first, or ensure CPN final is in results/csv/
#
# USAGE EXAMPLES
# --------------
# # Run after Workflows 05-06:
# source("R/workflows/07_generate_report_and_release.R")
#
# # View the generated report:
# browseURL("results/reports/bat_activity_report_20260109.html")
#
# # Find release bundle:
# list.files("results/releases/", pattern = "\\.zip$")
#
# MAINTAINER NOTES
# ----------------
# - This workflow is intentionally read-only for analytical content
# - All analytical work happens in Workflows 05-06
# - Report template lives at reports/bat_activity_report.qmd
# - Release bundles go to results/releases/
# - ASCII boxes: Single-line (┌─┐) for stage headers
# - Stage numbering: 7.1 - 7.6
# - Uses wrapper functions for major operations
#
# CHANGELOG
# ---------
# 2026-01-12: Enhanced version with release bundle and validation tracking
# 2026-01-09: Initial version per CODING_STANDARDS v2.1
#
# ==============================================================================

# ==============================================================================
# WORKFLOW INITIALIZATION
# ==============================================================================

workflow_start_time <- Sys.time()

# ------------------------------------------------------------------------------
# Load all functions
# ------------------------------------------------------------------------------

source("R/functions/load_all.R")

# ------------------------------------------------------------------------------
# Load required libraries
# ------------------------------------------------------------------------------

library(here)
library(yaml)
library(dplyr)
library(readr)

# Check for quarto package
if (!requireNamespace("quarto", quietly = TRUE)) {
  stop("Package 'quarto' is required but not installed.\n",
       "  Install with: install.packages('quarto')\n",
       "  Also requires Quarto CLI: https://quarto.org/docs/get-started/")
}

library(quarto)

# Check for zip package (for release bundles)
if (!requireNamespace("zip", quietly = TRUE)) {
  warning("Package 'zip' not installed - release bundle creation will be skipped.\n",
          "  Install with: install.packages('zip')")
  create_release <- FALSE
} else {
  library(zip)
  create_release <- TRUE
}

# ------------------------------------------------------------------------------
# Initialize logging and validation
# ------------------------------------------------------------------------------

log_message("=== WORKFLOW 07: Generate Report and Release Bundle ===")

# Initialize validation context
validation_context <- create_validation_context(
  workflow = "07",
  study_name = NULL  # Will be populated in Stage 7.1
)

# ==============================================================================
# STAGE 7.1: LOAD CONFIGURATION
# ==============================================================================

print_stage_header("7.1", "Load Configuration")

# Load study parameters for report metadata
study_params_path <- here::here("inst", "config", "study_parameters.yaml")

if (!file.exists(study_params_path)) {
  warning("study_parameters.yaml not found - using default metadata")
  study_params <- list(
    study_parameters = list(
      study_name = "Bat Acoustic Monitoring Study",
      study_location = "Study Site"
    )
  )
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "warning",
    description = "study_parameters.yaml not found, using defaults"
  )
} else {
  study_params <- yaml::read_yaml(study_params_path)
  message(sprintf("✓ Loaded study parameters: %s", basename(study_params_path)))
}

# Extract key parameters
study_name <- study_params$study_parameters$study_name %||% "Bat Acoustic Monitoring Study"
study_location <- study_params$study_parameters$study_location %||% "Study Site"
study_id <- study_params$study_parameters$study_id %||% 
  gsub("[^A-Za-z0-9]", "", study_name)

# Update validation context with study name
validation_context$study_name <- study_name

message(sprintf("  Study: %s", study_name))
message(sprintf("  Location: %s", study_location))
message(sprintf("  Study ID: %s", study_id))

# Initialize artifact registry
registry <- init_artifact_registry()

log_message("[Stage 7.1] Configuration loaded")

validation_context <- log_validation_event(
  validation_context,
  event_type = "data_loaded",
  description = "Study configuration loaded",
  details = list(study_name = study_name, study_id = study_id)
)

# ==============================================================================
# STAGE 7.2: LOAD PRE-COMPUTED OBJECTS
# ==============================================================================

print_stage_header("7.2", "Load Pre-computed Objects")

# ------------------------------------------------------------------------------
# 7.2.1: Discover RDS files from Workflows 05-06
# ------------------------------------------------------------------------------

message("Discovering RDS files from Workflows 05-06...")

rds_dir <- here::here("results", "rds")

# Check directory exists
if (!dir.exists(rds_dir)) {
  stop("RDS directory not found: ", rds_dir, "\n",
       "  Did you run Workflows 05-06 first?")
}

# Find most recent files using helper function
rds_discovery <- discover_pipeline_rds(rds_dir)

if (!rds_discovery$valid) {
  stop(sprintf("RDS discovery failed:\n  %s",
               paste(rds_discovery$errors, collapse = "\n  ")))
}

summary_file <- rds_discovery$summary_path
plots_file <- rds_discovery$plots_path

message(sprintf("✓ Found summary data: %s", basename(summary_file)))
message(sprintf("✓ Found plot objects: %s", basename(plots_file)))

validation_context <- log_validation_event(
  validation_context,
  event_type = "files_loaded",
  description = "Discovered RDS files from Workflows 05-06",
  count = 2,
  details = list(
    summary_file = basename(summary_file),
    plots_file = basename(plots_file)
  )
)

# ------------------------------------------------------------------------------
# 7.2.2: Load and validate RDS structures
# ------------------------------------------------------------------------------

message("\nLoading and validating RDS structures...")

all_summaries <- readRDS(summary_file)
all_plots <- readRDS(plots_file)

# Validate structure
rds_validation <- validate_rds_structure(all_summaries, all_plots)

if (!rds_validation$valid) {
  stop(sprintf("RDS validation failed:\n  %s",
               paste(rds_validation$errors, collapse = "\n  ")))
}

message(sprintf("✓ Validated RDS structure"))
message(sprintf("  Summary elements: %d", length(all_summaries)))
message(sprintf("  Plot categories: %d (%d plots total)", 
                length(all_plots), rds_validation$total_plots))

# Display plot counts by category
for (category in names(rds_validation$plot_counts)) {
  count <- rds_validation$plot_counts[[category]]
  suffix <- if (category == "species" && count == 0) " (not available)" else ""
  message(sprintf("    - %s: %d%s", 
                  tools::toTitleCase(category), count, suffix))
}

validation_context <- log_validation_event(
  validation_context,
  event_type = "data_loaded",
  description = "RDS structures validated",
  count = rds_validation$total_plots,
  details = list(
    summary_elements = length(all_summaries),
    plot_categories = length(all_plots),
    has_species = rds_validation$has_species
  )
)

# ------------------------------------------------------------------------------
# 7.2.3: Load CPN and Master data (for release bundle)
# ------------------------------------------------------------------------------

message("\nLoading CPN and Master data for release bundle...")

# Try to load from memory first, then from file
if (!exists("calls_per_night_final")) {
  cpn_final <- load_cpn_final()
  if (is.null(cpn_final)) {
    warning("CallsPerNight final not found - release bundle will be incomplete")
    cpn_final <- NULL
  } else {
    message(sprintf("✓ Loaded CPN final: %s rows", 
                    format(nrow(cpn_final), big.mark = ",")))
  }
} else {
  cpn_final <- calls_per_night_final
  message(sprintf("✓ Using CPN final from memory: %s rows", 
                  format(nrow(cpn_final), big.mark = ",")))
}

if (!exists("kpro_master")) {
  master_data <- load_master_data()
  if (is.null(master_data)) {
    warning("Master data not found - release bundle will be incomplete")
    master_data <- NULL
  } else {
    message(sprintf("✓ Loaded master data: %s rows", 
                    format(nrow(master_data), big.mark = ",")))
  }
} else {
  master_data <- kpro_master
  message(sprintf("✓ Using master data from memory: %s rows", 
                  format(nrow(master_data), big.mark = ",")))
}

log_message(sprintf("[Stage 7.2] Loaded %d summary elements, %d plot objects",
                    length(all_summaries), rds_validation$total_plots))

# ==============================================================================
# STAGE 7.3: GENERATE QUARTO REPORT
# ==============================================================================

print_stage_header("7.3", "Generate Quarto Report")

# Setup paths
timestamp <- format(Sys.Date(), "%Y%m%d")
report_output_dir <- here::here("results", "reports")
report_filename <- sprintf("bat_activity_report_%s.html", timestamp)
qmd_template <- here::here("reports", "bat_activity_report.qmd")

# Check template exists
if (!file.exists(qmd_template)) {
  stop(sprintf("Quarto template not found: %s\n", qmd_template),
       "  Ensure reports/bat_activity_report.qmd exists.")
}

message("Rendering Quarto report...")
message(sprintf("  Template: %s", basename(qmd_template)))
message(sprintf("  Output: %s", report_filename))

# Generate report using wrapper function
render_start <- Sys.time()

report_path <- generate_quarto_report(
  all_summaries = summary_file,  # Pass path for Quarto params
  all_plots = plots_file,
  study_params_path = study_params_path,
  template_path = qmd_template,
  output_dir = report_output_dir,
  quiet = FALSE
)

render_end <- Sys.time()
render_time <- round(difftime(render_end, render_start, units = "secs"), 1)

# Verify output exists
if (!file.exists(report_path)) {
  stop("Report generation failed - output file not found.\n",
       "  Check the Quarto rendering output above for errors.")
}

report_size_kb <- round(file.info(report_path)$size / 1024, 1)

message(sprintf("\n✓ Report generated successfully"))
message(sprintf("  Path: %s", report_path))
message(sprintf("  Size: %s KB", format(report_size_kb, big.mark = ",")))
message(sprintf("  Render time: %s seconds", render_time))

# Register artifact
registry <- register_artifact(
  registry = registry,
  artifact_name = sprintf("report_%s", timestamp),
  artifact_type = "report",
  workflow = "07",
  file_path = report_path,
  input_artifacts = c(basename(summary_file), basename(plots_file)),
  metadata = list(
    render_time_seconds = as.numeric(render_time),
    file_size_kb = report_size_kb
  ),
  quiet = TRUE
)

validation_context <- log_validation_event(
  validation_context,
  event_type = "rows_processed",
  description = sprintf("Quarto report generated: %s", report_filename),
  details = list(
    render_time = render_time,
    size_kb = report_size_kb
  )
)

log_message(sprintf("[Stage 7.3] Report rendered: %s (%.1f KB, %.1fs)", 
                    report_filename, report_size_kb, render_time))

# ==============================================================================
# STAGE 7.4: CREATE RELEASE BUNDLE
# ==============================================================================

print_stage_header("7.4", "Create Release Bundle")

if (!create_release) {
  message("⚠ Skipping release bundle - 'zip' package not installed")
  message("  Install with: install.packages('zip')")
  release_path <- NULL
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "warning",
    description = "Release bundle skipped - zip package not installed"
  )
  
} else if (is.null(cpn_final) || is.null(master_data)) {
  message("⚠ Skipping release bundle - CPN or Master data not available")
  release_path <- NULL
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "warning",
    description = "Release bundle skipped - required data not available"
  )
  
} else {
  message("Creating release bundle...")
  
  release_path <- create_release_bundle(
    study_id = study_id,
    calls_per_night_final = cpn_final,
    kpro_master = master_data,
    all_summaries = all_summaries,
    all_plots = all_plots,
    report_path = report_path,
    study_params = study_params,
    registry = registry,
    quiet = FALSE
  )
  
  validation_context <- log_validation_event(
    validation_context,
    event_type = "rows_processed",
    description = sprintf("Release bundle created: %s", basename(release_path)),
    details = list(
      zip_size_mb = round(file.info(release_path)$size / 1024 / 1024, 2)
    )
  )
  
  log_message(sprintf("[Stage 7.4] Release bundle created: %s", basename(release_path)))
}

# ==============================================================================
# STAGE 7.5: FINALIZE VALIDATION REPORT
# ==============================================================================

print_stage_header("7.5", "Finalize Validation Report")

# Set final row count (total plots generated)
validation_context$summary$rows_processed <- rds_validation$total_plots

# Generate validation report
validation_report_path <- finalize_validation_report(
  validation_context,
  output_dir = here::here("results", "validation")
)

message(sprintf("✓ Validation report generated: %s", basename(validation_report_path)))

log_message(sprintf("[Stage 7.5] Validation report: %s", basename(validation_report_path)))

# ==============================================================================
# STAGE 7.6: PIPELINE COMPLETE SUMMARY
# ==============================================================================

print_stage_header("7.6", "Pipeline Complete Summary")

# Calculate timing
workflow_end_time <- Sys.time()
workflow_duration <- round(difftime(workflow_end_time, workflow_start_time, units = "secs"), 1)

# Print workflow completion summary
print_workflow_summary(
  workflow = "07",
  title = "Report and Release Bundle Generated",
  items = list(
    "Report" = basename(report_path),
    "Release Bundle" = if (!is.null(release_path)) basename(release_path) else "(skipped)",
    "Validation" = basename(validation_report_path),
    "Duration" = sprintf("%.1f seconds", workflow_duration)
  )
)

# Print full pipeline completion summary
print_pipeline_complete(
  outputs = list(
    "Master Data" = "Workflow 02 → outputs/final/Master_*.csv",
    "CPN Final" = "Workflow 04 → results/csv/CallsPerNight_final_*.csv",
    "Summary Stats" = "Workflow 05 → results/rds/summary_data_*.rds",
    "Plot Objects" = "Workflow 06 → results/rds/plot_objects_*.rds",
    "HTML Report" = sprintf("Workflow 07 → %s", report_path),
    "Release Bundle" = if (!is.null(release_path)) 
      sprintf("Workflow 07 → %s", release_path) 
    else "(not created)"
  ),
  next_steps = c(
    "Review the HTML report in your browser",
    "Share the release bundle with collaborators",
    "Archive outputs for publication",
    "Import release into downstream analysis (e.g., NB GAMM project)"
  ),
  report_path = report_path
)

# ==============================================================================
# WORKFLOW 07 COMPLETE
# ==============================================================================

log_message("=== WORKFLOW 07 COMPLETE ===")
log_message("=== FULL PIPELINE COMPLETE ===")
log_message(sprintf("Total workflow duration: %.1f seconds", workflow_duration))

message("\n========================================")
message("✓ Workflow 07 Complete")
message("========================================\n")