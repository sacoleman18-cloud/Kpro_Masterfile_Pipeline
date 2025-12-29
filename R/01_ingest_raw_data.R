# ==============================================================================
# MAINLINE WORKFLOW: 01_ingest_raw_data.R
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
#    - Each file → separate dataframe (raw_file_001, raw_file_002, ...)
#
# 2. External data (from YAML configuration)
#    - Reads external_data_sources from study_parameters.yaml
#    - Recursively finds "id.csv" files in specified directories
#    - Combines all external files into single dataframe
#
# STAGE 1 PROCESSING (INTRO-STANDARDIZATION):
# --------------------------------------------
# Both sources apply the same light-touch processing:
#   - Remove N ≤ 0 or NA rows
#   - Clean column names with janitor
#   - Derive DetectorID
#   - Detect schema version PER ROW (v1/v2/v3)
#   - Track source file
#
# ROW-LEVEL SCHEMA DETECTION:
# ----------------------------
# Each row gets its own schema_version based on:
#   1. If "alternates" column exists → v1_legacy_single_column
#   2. If no "alternates", check auto_id length:
#      - 4 characters → v2_transitional_4letter
#      - 6 characters → v3_modern_6letter
#      - Other (NoID, NA, etc.) → unknown
#
# This handles mixed-version files where rows 1-500 might be v3 (6-letter)
# and rows 501-1000 might be v2 (4-letter) from different KPro versions.
#
# OUTPUTS
# -------
# After Stage 1:
#   - raw_combined: Combined + intro-standardized data (in memory)
#   - Checkpoint CSV: outputs/01_intro_standardized_YYYYMMDD_HHMMSS.csv
#   - study_parameters.yaml: Validated/created configuration file
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
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Load all functions
# ------------------------------------------------------------------------------

source("R/functions/load_all.R")

# ------------------------------------------------------------------------------
# Load required libraries
# ------------------------------------------------------------------------------

library(tidyverse)
library(janitor)
library(yaml)

# ------------------------------------------------------------------------------
# Initialize logging
# ------------------------------------------------------------------------------

initialize_pipeline_log("logs/pipeline_log.txt")
log_message("=== WORKFLOW 01: Ingest Raw Data ===")

# ==============================================================================
# STAGE 1.1: LOAD CONFIGURATION
# ==============================================================================

message("\n╔════════════════════════════════════════════════════════════════╗")
message("║          STAGE 1.1: Load Configuration                        ║")
message("╚════════════════════════════════════════════════════════════════╝\n")

# Check if study_parameters.yaml exists
yaml_path <- "inst/config/study_parameters.yaml"

if (file.exists(yaml_path)) {
  message("✓ Loading configuration from study_parameters.yaml")
  params <- load_study_parameters(yaml_path)
  
  # Extract external data sources
  external_sources <- params$study_parameters$external_data_sources
  
  if (is.null(external_sources) || length(external_sources) == 0) {
    message("  ℹ️  No external data sources configured")
    external_sources <- NULL
  } else {
    message(sprintf("  Found %d external data source(s):", length(external_sources)))
    for (i in seq_along(external_sources)) {
      message(sprintf("    %d. %s", i, external_sources[[i]]))
    }
  }
  
} else {
  message("⚠️  study_parameters.yaml not found")
  message("  Will create template after data ingestion")
  external_sources <- NULL
}

log_message("[Stage 1.1] Configuration loaded")

# ==============================================================================
# STAGE 1.2: LOAD LOCAL DATA
# ==============================================================================

message("\n╔════════════════════════════════════════════════════════════════╗")
message("║          STAGE 1.2: Load Local Data                          ║")
message("╚════════════════════════════════════════════════════════════════╝\n")

# Check if data/raw/ directory exists
if (!dir.exists("data/raw/")) {
  message("⚠️  data/raw/ directory not found - creating it")
  dir.create("data/raw/", recursive = TRUE)
  message("\n  Please add CSV files to data/raw/ and re-run this script\n")
  stop("No data/raw/ directory found - created empty directory")
}

# Load all CSV files from data/raw/ (any filename)
message("Loading CSV files from data/raw/...")
n_local_files <- load_local_raw_data()

# Check if any files were actually loaded
if (n_local_files == 0) {
  message("\n⚠️  No CSV files found in data/raw/")
  
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
  log_message(sprintf("[Stage 1.2] Loaded %d local files", n_local_files))
  
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
        message("    ⚠️  Multiple schema versions detected in this file")
      }
    }
  }
}

# ==============================================================================
# STAGE 1.3: LOAD EXTERNAL DATA
# ==============================================================================

message("\n╔════════════════════════════════════════════════════════════════╗")
message("║          STAGE 1.3: Load External Data                       ║")
message("╚════════════════════════════════════════════════════════════════╝\n")

external_data <- NULL

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
      next
    }
    
    # Load external data (recursively finds "id.csv" files)
    ext_data <- tryCatch({
      load_external_raw_data(external_dir)
    }, error = function(e) {
      warning(sprintf("Failed to load from %s: %s", external_dir, e$message))
      NULL
    })
    
    # Add to list if successful
    if (!is.null(ext_data) && nrow(ext_data) > 0) {
      external_datasets[[paste0("source_", i)]] <- ext_data
      message(sprintf("  ✓ Loaded %s rows\n", format(nrow(ext_data), big.mark = ",")))
    }
  }
  
  # Combine all external datasets
  if (length(external_datasets) > 0) {
    external_data <- dplyr::bind_rows(external_datasets)
    
    log_message(sprintf("[Stage 1.3] Loaded %s rows from %d external source(s)", 
                        format(nrow(external_data), big.mark = ","),
                        length(external_datasets)))
    
    # -------------------------
    # Report schema distribution for external data
    # -------------------------
    message("Schema Detection Summary (external data):")
    
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
      message("  ⚠️  Multiple schema versions detected in external data")
    }
    
  } else {
    message("⚠️  No external data loaded (all sources failed or empty)")
  }
  
} else {
  message("ℹ️  No external data sources configured")
  message("  To add external sources, edit study_parameters.yaml:")
  message("  external_data_sources:")
  message("    - 'path/to/directory'")
}

# ==============================================================================
# STAGE 1.4: COMBINE DATASETS
# ==============================================================================

message("\n╔════════════════════════════════════════════════════════════════╗")
message("║          STAGE 1.4: Combine Datasets                         ║")
message("╚════════════════════════════════════════════════════════════════╝\n")

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
  message(sprintf("  • Local files: %d dataframes", n_local_files))
}

# Add external data if it exists
if (!is.null(external_data) && nrow(external_data) > 0) {
  datasets_to_combine$external <- external_data
  message(sprintf("  • External data: %s rows", format(nrow(external_data), big.mark = ",")))
}

# Check if we have any data
if (length(datasets_to_combine) == 0) {
  stop("No data loaded from either local or external sources - cannot continue")
}

# Combine datasets
raw_combined <- dplyr::bind_rows(datasets_to_combine)

message(sprintf("\n✓ Combined dataset: %s total rows", format(nrow(raw_combined), big.mark = ",")))

# Show combined schema distribution
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

# Warn if multiple versions
if (length(schema_counts) > 1) {
  message("  ⚠️  Multiple schema versions in combined data")
}

log_message(sprintf("[Stage 1.4] Combined %d datasets into raw_combined", 
                    length(datasets_to_combine)))

# ==============================================================================
# STAGE 1.5: SAVE CHECKPOINT
# ==============================================================================

message("\n╔════════════════════════════════════════════════════════════════╗")
message("║          STAGE 1.5: Save Checkpoint                          ║")
message("╚════════════════════════════════════════════════════════════════╝\n")

# Create outputs directory if it doesn't exist
if (!dir.exists("outputs")) {
  dir.create("outputs", recursive = TRUE)
  message("  Created outputs/ directory")
}

# Save with timestamp
checkpoint_file <- sprintf("outputs/01_intro_standardized_%s.csv", 
                           format(Sys.time(), "%Y%m%d_%H%M%S"))

readr::write_csv(raw_combined, checkpoint_file)

log_message(sprintf("[Stage 1.5] Saved intro-standardized checkpoint: %s (%s rows)", 
                    basename(checkpoint_file),
                    format(nrow(raw_combined), big.mark = ",")))

message(sprintf("✓ Checkpoint saved: %s", basename(checkpoint_file)))
message(sprintf("  Location: %s", checkpoint_file))

# ==============================================================================
# STAGE 1.6: CLEAN WORKSPACE
# ==============================================================================

message("\n╔════════════════════════════════════════════════════════════════╗")
message("║          STAGE 1.6: Clean Workspace                          ║")
message("╚════════════════════════════════════════════════════════════════╝\n")

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

message("✓ Workspace cleaned")

log_message("[Stage 1.6] Workspace cleaned")

# ==============================================================================
# STAGE 1.7: VALIDATE/GENERATE STUDY PARAMETERS
# ==============================================================================

message("\n╔════════════════════════════════════════════════════════════════╗")
message("║          STAGE 1.7: Validate Configuration                   ║")
message("╚════════════════════════════════════════════════════════════════╝\n")

# Validate or generate YAML
ensure_study_parameters(raw_combined, "inst/config/study_parameters.yaml")

message("✓ study_parameters.yaml validated and synchronized")

log_message("[Stage 1.7] Configuration validated")

# ==============================================================================
# WORKFLOW 01 COMPLETE
# ==============================================================================

message("\n╔════════════════════════════════════════════════════════════════╗")
message("║          STAGE 1 COMPLETE: Intro-Standardization             ║")
message("╚════════════════════════════════════════════════════════════════╝\n")

message("Intro-standardization applied:")
message("  ✓ N ≤ 0 or NA rows removed")
message("  ✓ Column names cleaned (janitor)")
message("  ✓ DetectorID derived")
message("  ✓ Schema version detected PER ROW")
message("  ✓ Source file tracked")
message("  ✓ All data combined into raw_combined")
message(sprintf("  ✓ Checkpoint saved: %s", basename(checkpoint_file)))
message("  ✓ study_parameters.yaml validated")

# Check for unknown schemas
unknown_count <- sum(raw_combined$schema_version == "unknown", na.rm = TRUE)
if (unknown_count > 0) {
  message(sprintf("\n⚠️  Warning: %s rows (%.1f%%) have unknown schema", 
                  format(unknown_count, big.mark = ","),
                  100 * unknown_count / nrow(raw_combined)))
  message("    These may be NoID rows or have unexpected code lengths")
}

message(sprintf("\nFinal dataset: %s rows", format(nrow(raw_combined), big.mark = ",")))

# Show data sources summary
message("\nData sources:")
if (n_local_files > 0) {
  message(sprintf("  • Local: %d file(s) from data/raw/", n_local_files))
}
if (!is.null(external_sources) && length(external_sources) > 0) {
  message(sprintf("  • External: %d source(s) from YAML", length(external_sources)))
}

message("\n========================================")
message("✓ Workflow 01 Complete")
message("========================================")

message("\nCurrent data in environment:")
message("  • raw_combined (ready for Workflow 02)")
message(sprintf("  • Checkpoint: %s", basename(checkpoint_file)))

message("\nNext workflow:")
message("  source('02_standardize.R')  # Transform to master schema\n")

log_message("=== WORKFLOW 01 COMPLETE ===")