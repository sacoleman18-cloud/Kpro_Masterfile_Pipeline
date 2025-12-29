# =============================================================================
# 01_ingest_and_clean_raw.R
# =============================================================================
# Workflow script for ingesting raw Kaleidoscope Pro (KPro) ID CSV files.
#
# This script:
#   - Loads study parameters
#   - Ingests raw KPro ID files using the locked 01_ingestion contract
#   - Optionally appends user-selected CSV folders (interactive only)
#   - Performs NO schema interpretation or normalization
#
# Downstream logic begins in:
#   - 02_standardization.R
# =============================================================================

# -------------------------------
# Load required libraries
# -------------------------------
library(dplyr)

# -------------------------------
# Load all project functions
# -------------------------------
source("R/functions/load_all_functions.R")

# -------------------------------
# 1. Load Study Parameters
# -------------------------------
study_params <- load_study_parameters("study_parameters.yaml")

# -------------------------------
# 2. Ingest KPro ID CSV Files (LOCKED CONTRACT)
# -------------------------------
kpro_data <- ingest_kpro_files(
  kpro_path    = study_params$processing_options$kpro_directory,
  file_pattern = "id\\.csv$"
)

log_message(
  paste("[Pipeline] Initial KPro ingestion complete. Rows:", nrow(kpro_data))
)

# -------------------------------
# OPTIONAL: Append legacy folder data
# -------------------------------
legacy_dir <- "data/legacy/"

if (dir.exists(legacy_dir)) {
  
  log_message(paste("[Pipeline] Appending CSV files from legacy folder:", legacy_dir))
  
  legacy_files <- list.files(
    legacy_dir,
    pattern    = "\\.csv$",
    full.names = TRUE
  )
  
  if (length(legacy_files) > 0) {
    legacy_data <- ingest_files_raw(legacy_files)
    
    if (nrow(legacy_data) > 0) {
      kpro_data <- dplyr::bind_rows(kpro_data, legacy_data)
      log_message(paste("[Pipeline] Rows appended from legacy folder:", nrow(legacy_data)))
    } else {
      log_message("[Pipeline] No valid rows found in legacy folder")
    }
    
  } else {
    log_message("[Pipeline] No CSV files found in legacy folder")
  }
  
} else {
  log_message("[Pipeline] Legacy folder does not exist, skipping append")
}


# -------------------------------
# 4. Save Raw Combined Output (Optional but Recommended)
# -------------------------------
dir.create("results/raw", recursive = TRUE, showWarnings = FALSE)

raw_output_path <- file.path(
  "results/raw",
  paste0("kpro_raw_ingest_", Sys.Date(), ".csv")
)

readr::write_csv(kpro_data, raw_output_path)

log_message(
  paste("[Pipeline] Raw ingest saved to:", raw_output_path)
)

# -------------------------------
# 5. Completion Message
# -------------------------------
log_message("[Pipeline] 01_ingest_and_clean_raw completed successfully.")
