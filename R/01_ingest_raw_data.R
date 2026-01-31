# ==============================================================================
# WORKFLOW 01: 01_ingest_raw_data.R
# ==============================================================================
# PURPOSE
# -------
# This workflow performs Stage 1 ingestion - loading raw KPro id.csv files
# with minimal processing to get data into R environment.
#
# TWO DATA SOURCES:
# -----------------
# 1. Local data (data/raw/)
#    - Loads ALL CSV files from data/raw/ directory
#    - Each file -> separate dataframe (raw_file_001, raw_file_002, ...)
#
# 2. External data (from YAML configuration)
#    - Reads external_data_sources from study_parameters.yaml
#    - Recursively finds "id.csv" files in specified directories
#    - Combines all external files into single dataframe
#
# STAGE 1 PROCESSING (INTRO-STANDARDIZATION):
# --------------------------------------------
# Both sources apply the same light-touch processing:
#   - Remove N <= 0 or NA rows
#   - Clean column names with janitor
#   - Derive DetectorID
#   - Detect schema version PER ROW (v1/v2/v3)
#   - Track source file
#
# ROW-LEVEL SCHEMA DETECTION:
# ----------------------------
# Each row gets its own schema_version based on:
#   1. If "alternates" column exists -> v1_legacy_single_column
#   2. If no "alternates", check auto_id length: 
#      - 4 characters -> v2_transitional_4letter
#      - 6 characters -> v3_modern_6letter
#      - Other (NoID, NA, etc.) -> unknown
#
# This handles mixed-version files where rows 1-500 might be v3 (6-letter)
# and rows 501-1000 might be v2 (4-letter) from different KPro versions.
#
# OUTPUTS
# -------
# After Stage 1:
#   - raw_combined: Combined + intro-standardized data (in memory)
#   - Checkpoint CSV: outputs/checkpoints/01_intro_standardized_YYYYMMDD_HHMMSS.csv
#   - study_parameters.yaml: Validated/created configuration file
#
# Validation:
#   - results/validation/validation_01_YYYYMMDD_HHMMSS.html
#   - results/validation/validation_01_YYYYMMDD_HHMMSS.yaml
#
# Registry:
#   - inst/config/artifact_registry.yaml (updated)
#
# Future Stage 2 (Workflow 02) will transform this into kpro_master
#
# DEPENDENCIES
# ------------
#   R packages:
#     - tidyverse: data manipulation
#     - janitor: column name cleaning
#     - yaml: configuration file reading
#   Custom functions:
#     - core/utilities.R: log_message, initialize_pipeline_log
#     - ingestion/ingestion.R: load_local_raw_data, load_external_raw_data
#     - core/schema_detection.R: detect_row_schema
#     - core/config.R: load_study_parameters, ensure_study_parameters
#     - core/artifacts.R: init_artifact_registry, register_artifact,
#                        create_validation_context, log_validation_event,
#                        finalize_validation_report
#
# WORKFLOW STAGES
# ---------------
#   Stage 1.1: Load configuration from YAML
#   Stage 1.2: Load local data from data/raw/
#   Stage 1.3: Load external data (from YAML sources)
#   Stage 1.4: Combine datasets
#   Stage 1.5: Save checkpoint CSV
#   Stage 1.6: Clean workspace
#   Stage 1.7: Validate/generate study_parameters.yaml
#   Stage 1.8: Generate validation report
#
# VALIDATION TRACKING
# -------------------
# This workflow tracks the following validation events:
#   - files_loaded: Number of CSV files successfully loaded
#   - file_failed: Individual file load failures
#   - rows_removed: Rows filtered during intro-standardization
#   - schema_detection: Schema version distribution
#   - schema_unknown: Rows with undetectable schema
#   - source_breakdown: Local vs external data contribution
#   - rows_processed: Final row count after all processing
#
# CHANGELOG
# ---------
# 2026-01-20: Standards compliance refactor (here::here paths, print_stage_header)
# 2026-01-12: Fixed external file counting to use files_processed attribute from ingestion functions
# 2026-01-12: Enhanced validation tracking (rows_removed, schema_unknown, source_breakdown, file_failed)
# 2026-01-12: Added artifact registry and validation tracking
# 2025-12-XX: Initial CODING_STANDARDS compliant version
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Load all functions
# ------------------------------------------------------------------------------

source(here::here("R", "functions", "load_all.R"))

# ------------------------------------------------------------------------------
# Load required libraries
# ------------------------------------------------------------------------------

library(tidyverse)
library(janitor)
library(yaml)

# ------------------------------------------------------------------------------
# Initialize logging
# ------------------------------------------------------------------------------

initialize_pipeline_log(here::here("logs", "pipeline_log.txt"))
log_message("=== WORKFLOW 01: Ingest Raw Data ===")

# ------------------------------------------------------------------------------
# Initialize validation context
# ------------------------------------------------------------------------------

validation_context <- create_validation_context(
  workflow = "01",
  study_name = NULL  # Will be set later from YAML
)

# ==============================================================================
# STAGE 1.1: LOAD CONFIGURATION
# ==============================================================================

print_stage_header("1.1", "Load Configuration")

# Check if study_parameters.yaml exists
yaml_path <- here::here("inst", "config", "study_parameters.yaml")

if (file.exists(yaml_path)) {
  message("[OK] Loading configuration from study_parameters.yaml")
  params <- load_study_parameters(yaml_path)
  
  # Update validation context with study name
  validation_context$study_name <- params$study_parameters$study_name
  
  # Extract external data sources
  external_sources <- params$study_parameters$external_data_sources
  
  if (is.null(external_sources) || length(external_sources) == 0) {
    message("  [i] No external data sources configured")
    external_sources <- NULL
  } else {
    message(sprintf("  Found %d external data source(s):", length(external_sources)))
    for (i in seq_along(external_sources)) {
      message(sprintf("    %d. %s", i, external_sources[[i]]))
    }
  }
  
} else {
  message("[!] study_parameters.yaml not found")
  message("  Will create template after data ingestion")
  external_sources <- NULL
}

log_message("[Stage 1.1] Configuration loaded")

# ==============================================================================
# STAGE 1.2: LOAD LOCAL DATA
# ==============================================================================

print_stage_header("1.2", "Load Local Data")

# Check if data/raw/ directory exists
if (!dir.exists(here::here("data", "raw"))) {
  message("[!] data/raw/ directory not found - creating it")
  dir.create(here::here("data", "raw"), recursive = TRUE)
  message("\n  Please add CSV files to data/raw/ and re-run this script\n")
  stop("No data/raw/ directory found - created empty directory")
}

# Load all CSV files from data/raw/ (any filename)
message("Loading CSV files from data/raw/...")
n_local_files <- load_local_raw_data()

# Check if any files were actually loaded
if (n_local_files == 0) {
  message("\n[!] No CSV files found in data/raw/")
  
  # Check if we have external sources
  if (is.null(external_sources)) {
    message("\nNo local data and no external sources configured.")
    message("Please either:")
    message("  1. Add CSV files to data/raw/, OR")
    message("  2. Configure external_data_sources in study_parameters.yaml\n")
    stop("No data sources available - exiting")
  } else {
    message("\nNo local data found, but external sources configured.")
    message("Will proceed with external data only.\n")
  }
  
} else {
  # Log validation event for local files
  validation_context <- log_validation_event(
    validation_context,
    event_type = "files_loaded",
    description = "Loaded local CSV files from data/raw/",
    count = n_local_files
  )
  
  log_message(sprintf("[Stage 1.2] Loaded %d local files", n_local_files))
  
  # -------------------------
  # Track rows removed during intro-standardization
  # -------------------------
  
  # NOTE: This tracking captures row removal that happens inside load_local_raw_data()
  # Each file has N <= 0 or NA rows removed during intro-standardization
  
  total_rows_removed_local <- 0
  
  for (i in 1:n_local_files) {
    file_name <- sprintf("raw_file_%03d", i)
    
    if (exists(file_name)) {
      df <- get(file_name)
      
      # Check if the dataframe has a 'rows_removed' attribute
      # (This would be set by the ingestion function if it tracked removal)
      rows_removed <- attr(df, "rows_removed")
      
      if (!is.null(rows_removed) && rows_removed > 0) {
        total_rows_removed_local <- total_rows_removed_local + rows_removed
        
        # Log per-file removal
        validation_context <- log_validation_event(
          validation_context,
          event_type = "rows_removed",
          description = sprintf("%s: Removed invalid rows (N <= 0 or NA)", file_name),
          count = rows_removed,
          details = list(
            file = file_name,
            rows_removed = rows_removed,
            reason = "N <= 0 or NA values"
          )
        )
      }
    }
  }
  
  # Log total local rows removed if any
  if (total_rows_removed_local > 0) {
    message(sprintf("\n  [i] Removed %s invalid rows across %d local files", 
                    format(total_rows_removed_local, big.mark = ","),
                    n_local_files))
  }
  
  # -------------------------
  # Report schema distribution for each local file
  # -------------------------
  message("\nSchema Detection Summary:")
  
  for (i in 1:n_local_files) {
    file_name <- sprintf("raw_file_%03d", i)
    
    if (exists(file_name)) {
      df <- get(file_name)
      
      # Count schemas in this file
      schema_counts <- table(df$schema_version)
      
      message(sprintf("\n  %s:", file_name))
      for (version in names(schema_counts)) {
        count <- schema_counts[version]
        pct <- round(100 * count / nrow(df), 1)
        message(sprintf("    - %s: %s rows (%.1f%%)", 
                        version, 
                        format(count, big.mark = ","),
                        pct))
      }
      
      # Warn if multiple versions in one file
      if (length(schema_counts) > 1) {
        message("    [!] Multiple schema versions detected in this file")
      }
    }
  }
}

# ==============================================================================
# STAGE 1.3: LOAD EXTERNAL DATA
# ==============================================================================

print_stage_header("1.3", "Load External Data")

external_data <- NULL
n_external_sources_succeeded <- 0
total_rows_removed_external <- 0

if (!is.null(external_sources) && length(external_sources) > 0) {
  
  message(sprintf("Processing %d external data source(s)...\n", length(external_sources)))
  
  # Process each external source
  external_datasets <- list()
  
  for (i in seq_along(external_sources)) {
    external_dir <- external_sources[[i]]
    
    message(sprintf("[%d/%d] Processing: %s", i, length(external_sources), external_dir))
    
    # Validate path exists
    if (!dir.exists(external_dir)) {
      warning(sprintf("Directory not found: %s - skipping", external_dir))
      
      # Log failed source
      validation_context <- log_validation_event(
        validation_context,
        event_type = "file_failed",
        description = sprintf("External source directory not found: %s", basename(external_dir)),
        details = list(
          source_path = external_dir,
          error_reason = "Directory does not exist"
        )
      )
      
      next
    }
    
    # Load external data (recursively finds "id.csv" files)
    ext_data <- tryCatch({
      load_external_raw_data(external_dir)
    }, error = function(e) {
      warning(sprintf("Failed to load from %s: %s", external_dir, e$message))
      
      # Log failed source
      validation_context <<- log_validation_event(
        validation_context,
        event_type = "file_failed",
        description = sprintf("Failed to load external source: %s", basename(external_dir)),
        details = list(
          source_path = external_dir,
          error_message = e$message
        )
      )
      
      NULL
    })
    
    # Add to list if successful
    if (!is.null(ext_data) && nrow(ext_data) > 0) {
      external_datasets[[paste0("source_", i)]] <- ext_data
      n_external_sources_succeeded <- n_external_sources_succeeded + 1
      message(sprintf("  [OK] Loaded %s rows\n", format(nrow(ext_data), big.mark = ",")))
      
      # Track rows removed from this external source
      rows_removed <- attr(ext_data, "rows_removed")
      if (!is.null(rows_removed) && rows_removed > 0) {
        total_rows_removed_external <- total_rows_removed_external + rows_removed
        
        validation_context <- log_validation_event(
          validation_context,
          event_type = "rows_removed",
          description = sprintf("External source %d: Removed invalid rows (N <= 0 or NA)", i),
          count = rows_removed,
          details = list(
            source_path = external_dir,
            rows_removed = rows_removed,
            reason = "N <= 0 or NA values"
          )
        )
      }
    }
  }
  
  # Combine all external datasets
  if (length(external_datasets) > 0) {
    external_data <- dplyr::bind_rows(external_datasets)
    
    # Count total files from all external sources
    n_external_files_loaded <- sum(sapply(external_datasets, function(ds) {
      attr(ds, "files_processed") %||% 0  # Get files_processed attribute, default to 0
    }))
    
    # Log validation event for external files
    validation_context <- log_validation_event(
      validation_context,
      event_type = "files_loaded",
      description = sprintf("Loaded %d files from %d external source(s)", 
                            n_external_files_loaded,
                            length(external_datasets)),
      count = n_external_files_loaded
    )
    
    log_message(sprintf("[Stage 1.3] Loaded %s rows from %d external source(s)", 
                        format(nrow(external_data), big.mark = ","),
                        length(external_datasets)))
    
    # Report total external rows removed
    if (total_rows_removed_external > 0) {
      message(sprintf("\n  [i] Removed %s invalid rows from external sources", 
                      format(total_rows_removed_external, big.mark = ",")))
    }
    
    # -------------------------
    # Report schema distribution for external data
    # -------------------------
    message("\nSchema Detection Summary (external data):")
    
    schema_counts <- table(external_data$schema_version)
    
    for (version in names(schema_counts)) {
      count <- schema_counts[version]
      pct <- round(100 * count / nrow(external_data), 1)
      message(sprintf("  - %s: %s rows (%.1f%%)", 
                      version, 
                      format(count, big.mark = ","),
                      pct))
    }
    
    # Warn if multiple versions
    if (length(schema_counts) > 1) {
      message("  [!] Multiple schema versions detected in external data")
    }
    
  } else {
    message("[!] No external data loaded (all sources failed or empty)")
  }
  
} else {
  message("[i] No external data sources configured")
  message("  To add external sources, edit study_parameters.yaml:")
  message("  external_data_sources:")
  message("    - 'path/to/directory'")
}

# ==============================================================================
# STAGE 1.4: COMBINE DATASETS
# ==============================================================================

print_stage_header("1.4", "Combine Datasets")

# Initialize list to hold datasets
datasets_to_combine <- list()

# Add local files if they exist
if (n_local_files > 0) {
  for (i in 1:n_local_files) {
    file_name <- sprintf("raw_file_%03d", i)
    if (exists(file_name)) {
      datasets_to_combine[[file_name]] <- get(file_name)
    }
  }
  message(sprintf("  - Local files: %d dataframes", n_local_files))
}

# Add external data if it exists
if (!is.null(external_data) && nrow(external_data) > 0) {
  datasets_to_combine$external <- external_data
  message(sprintf("  - External data: %s rows", format(nrow(external_data), big.mark = ",")))
}

# Check if we have any data
if (length(datasets_to_combine) == 0) {
  stop("No data loaded from either local or external sources - cannot continue")
}

# Combine datasets
raw_combined <- dplyr::bind_rows(datasets_to_combine)

message(sprintf("\n[OK] Combined dataset: %s total rows", format(nrow(raw_combined), big.mark = ",")))

# -------------------------
# Log source breakdown
# -------------------------

# Calculate contribution from each source
n_local <- sum(sapply(datasets_to_combine[grepl("raw_file", names(datasets_to_combine))], nrow))
n_external <- if (!is.null(datasets_to_combine$external)) nrow(datasets_to_combine$external) else 0

validation_context <- log_validation_event(
  validation_context,
  event_type = "source_breakdown",
  description = "Data source contribution summary",
  details = list(
    local_rows = n_local,
    external_rows = n_external,
    local_percentage = round(100 * n_local / nrow(raw_combined), 1),
    external_percentage = round(100 * n_external / nrow(raw_combined), 1),
    total_rows = nrow(raw_combined),
    local_files = n_local_files,
    external_sources = n_external_sources_succeeded
  )
)

# Log validation event for combined data
validation_context <- log_validation_event(
  validation_context,
  event_type = "rows_processed",
  description = "Combined all datasets",
  count = nrow(raw_combined)
)
validation_context$summary$rows_processed <- nrow(raw_combined)

# -------------------------
# Show combined schema distribution
# -------------------------

message("\nCombined Schema Distribution:")

schema_counts <- table(raw_combined$schema_version)
for (version in names(schema_counts)) {
  count <- schema_counts[version]
  pct <- round(100 * count / nrow(raw_combined), 1)
  message(sprintf("  - %s: %s rows (%.1f%%)", 
                  version, 
                  format(count, big.mark = ","),
                  pct))
}

# Log schema distribution in validation context
validation_context <- log_validation_event(
  validation_context,
  event_type = "schema_detection",
  description = "Detected schema versions across all data",
  details = list(schema_distribution = as.list(schema_counts))
)
validation_context$summary$schema_distribution <- as.list(schema_counts)

# Warn if multiple versions
if (length(schema_counts) > 1) {
  message("  [!] Multiple schema versions in combined data")
}

log_message(sprintf("[Stage 1.4] Combined %d datasets into raw_combined", 
                    length(datasets_to_combine)))

# ==============================================================================
# STAGE 1.5: SAVE CHECKPOINT
# ==============================================================================

print_stage_header("1.5", "Save Checkpoint")

# Create outputs/checkpoints directory if it doesn't exist
checkpoint_dir <- here::here("outputs", "checkpoints")
if (!dir.exists(checkpoint_dir)) {
  dir.create(checkpoint_dir, recursive = TRUE)
  message("  Created outputs/checkpoints/ directory")
}

# Save with timestamp
checkpoint_file <- here::here("outputs", "checkpoints", 
                              sprintf("01_intro_standardized_%s.csv", 
                                      format(Sys.time(), "%Y%m%d_%H%M%S")))

readr::write_csv(raw_combined, checkpoint_file)

log_message(sprintf("[Stage 1.5] Saved intro-standardized checkpoint: %s (%s rows)", 
                    basename(checkpoint_file),
                    format(nrow(raw_combined), big.mark = ",")))

message(sprintf("[OK] Checkpoint saved: %s", basename(checkpoint_file)))
message(sprintf("  Location: %s", checkpoint_file))

# ------------------------------------------------------------------------------
# Initialize artifact registry and register checkpoint
# ------------------------------------------------------------------------------

message("\nRegistering artifact...")

# Initialize artifact registry
registry <- init_artifact_registry()

# Register checkpoint artifact
registry <- register_artifact(
  registry = registry,
  artifact_name = sprintf("intro_standardized_%s", format(Sys.time(), "%Y%m%d_%H%M%S")),
  artifact_type = "checkpoint",
  workflow = "01",
  file_path = checkpoint_file,
  metadata = list(
    n_rows = nrow(raw_combined),
    n_files = n_local_files + n_external_sources_succeeded,
    schema_distribution = as.list(table(raw_combined$schema_version)),
    rows_removed_total = total_rows_removed_local + total_rows_removed_external
  )
)

message("[OK] Artifact registered in registry")

# ==============================================================================
# STAGE 1.6: CLEAN WORKSPACE
# ==============================================================================

print_stage_header("1.6", "Clean Workspace")

# Remove individual raw_file objects
if (n_local_files > 0) {
  for (i in 1:n_local_files) {
    file_name <- sprintf("raw_file_%03d", i)
    if (exists(file_name)) {
      rm(list = file_name, envir = .GlobalEnv)
    }
  }
  message(sprintf("  Removed %d raw_file_* objects", n_local_files))
}

# Remove external_data
if (exists("external_data")) {
  rm(external_data, envir = .GlobalEnv)
  message("  Removed external_data")
}

# Remove datasets_to_combine
if (exists("datasets_to_combine")) {
  rm(datasets_to_combine, envir = .GlobalEnv)
  message("  Removed datasets_to_combine")
}

# Remove any stray df object
if (exists("df")) {
  rm(df, envir = .GlobalEnv)
  message("  Removed residual df")
}

# Remove external_datasets if exists
if (exists("external_datasets")) {
  rm(external_datasets, envir = .GlobalEnv)
  message("  Removed external_datasets")
}

message("[OK] Workspace cleaned")

log_message("[Stage 1.6] Workspace cleaned")

# ==============================================================================
# STAGE 1.7: VALIDATE/GENERATE STUDY PARAMETERS
# ==============================================================================

print_stage_header("1.7", "Validate Configuration")

# Validate or generate YAML
ensure_study_parameters(raw_combined, here::here("inst", "config", "study_parameters.yaml"))

message("[OK] study_parameters.yaml validated and synchronized")

log_message("[Stage 1.7] Configuration validated")

# ==============================================================================
# TRACK SCHEMA UNKNOWN ROWS
# ==============================================================================

# Check for rows with unknown schema
unknown_count <- sum(raw_combined$schema_version == "unknown", na.rm = TRUE)

if (unknown_count > 0) {
  validation_context <- log_validation_event(
    validation_context,
    event_type = "schema_unknown",
    description = sprintf("%d rows with undetectable schema version", unknown_count),
    count = unknown_count,
    details = list(
      percentage = round(100 * unknown_count / nrow(raw_combined), 2),
      possible_reasons = c("NoID rows", "Unexpected auto_id length", "Missing auto_id column"),
      impact = "These rows will be processed but may have limited metadata"
    )
  )
}

# ==============================================================================
# STAGE 1.8: FINALIZE VALIDATION REPORT
# ==============================================================================

print_stage_header("1.8", "Generate Validation Report")

# Finalize validation report
validation_report_path <- finalize_validation_report(
  validation_context,
  output_dir = here::here("results", "validation")
)

log_message(sprintf("[Workflow 01] Validation report: %s", basename(validation_report_path)))

# ==============================================================================
# WORKFLOW 01 COMPLETE
# ==============================================================================

message("\n========================================")
message("  WORKFLOW 01 COMPLETE: Intro-Standardization")
message("========================================\n")

message("Intro-standardization applied:")
message("  [OK] N <= 0 or NA rows removed")
message("  [OK] Column names cleaned (janitor)")
message("  [OK] DetectorID derived")
message("  [OK] Schema version detected PER ROW")
message("  [OK] Source file tracked")
message("  [OK] All data combined into raw_combined")
message(sprintf("  [OK] Checkpoint saved: %s", basename(checkpoint_file)))
message("  [OK] study_parameters.yaml validated")
message(sprintf("  [OK] Validation report: %s", basename(validation_report_path)))
message("  [OK] Artifact registered in registry")

# Show data quality summary
total_rows_removed <- total_rows_removed_local + total_rows_removed_external
if (total_rows_removed > 0) {
  message("\nData Quality:")
  message(sprintf("  - Rows removed (N <= 0 or NA): %s", format(total_rows_removed, big.mark = ",")))
}

if (unknown_count > 0) {
  message(sprintf("  - Unknown schema rows: %s (%.1f%%)", 
                  format(unknown_count, big.mark = ","),
                  100 * unknown_count / nrow(raw_combined)))
}

message(sprintf("\nFinal dataset: %s rows", format(nrow(raw_combined), big.mark = ",")))

# Show data sources summary
message("\nData sources:")
if (n_local_files > 0) {
  message(sprintf("  - Local: %d file(s) from data/raw/ (%s rows, %.1f%%)", 
                  n_local_files,
                  format(n_local, big.mark = ","),
                  100 * n_local / nrow(raw_combined)))
}
if (n_external_sources_succeeded > 0) {
  message(sprintf("  - External: %d source(s) from YAML (%s rows, %.1f%%)", 
                  n_external_sources_succeeded,
                  format(n_external, big.mark = ","),
                  100 * n_external / nrow(raw_combined)))
}

message("\n========================================")
message("[OK] Workflow 01 Complete")
message("========================================")

message("\nCurrent data in environment:")
message("  - raw_combined (ready for Workflow 02)")
message(sprintf("  - Checkpoint: %s", basename(checkpoint_file)))
message(sprintf("  - Validation report: %s", basename(validation_report_path)))

message("\nNext workflow:")
message("  source('R/workflows/02_standardize.R')  # Transform to master schema\n")

log_message("=== WORKFLOW 01 COMPLETE ===")