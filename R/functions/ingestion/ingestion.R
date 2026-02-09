# =============================================================================
# UTILITY: ingestion.R - Raw Data Ingestion (LOCKED CONTRACT)
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# - Loads and intro-standardizes raw CSV data
# - Used by workflows/modules in R/pipeline/
# PURPOSE
# -------
# File discovery, reading, and intro-standardization. Provides two primary
# commands for loading data from local and external sources.
#
# INGESTION CONTRACT
# ------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. File discovery
#    - Recursively locates KPro Auto-ID CSV files (typically *id.csv)
#    - No assumptions made about directory structure
#    - Handles nested folders of arbitrary depth
#
# 2. Row semantics
#    - One row = one KPro detection event
#    - Rows with N <= 0 or NA are removed immediately (no bat = no data)
#    - Removal is logged with counts
#    - Removal count stored as attribute for validation tracking
#
# 3. Column handling
#    - ALL columns read as character type (preserves original data)
#    - janitor::clean_names() applied for consistent lowercase_snake_case
#
# 4. detector_id derivation
#    - Column 'detector_id' is ALWAYS created
#    - Derived as first 16 characters of 'in_file' column
#    - If 'in_file' missing, detector_id = NA with warning
#
# 5. Schema detection
#    - detect_row_schema() called on every dataframe
#    - Adds 'schema_version' column to each row
#
# 6. Provenance tracking
#    - 'source_file' column added with original file path
#
# 7. Error handling
#    - Individual file read failures are logged and skipped
#    - Pipeline continues with remaining files
#
# 8. Validation tracking
#    - Row removal counts stored as 'rows_removed' attribute
#    - Accessible via attr(df, "rows_removed")
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Transform alternates or auto_id columns
#   - Convert species codes
#   - Enforce master schema requirements
#   - Create 'Detector' column (happens in detector_mapping.R)
#   - Parse dates or calculate times
#
# DEPENDENCIES
# ------------
#   - core/utilities.R: safe_read_csv, log_message
#   - standardization/schema_helpers.R: detect_row_schema, get_dominant_schema, get_schema_summary
#   - validation/validation.R: assert_data_frame, assert_not_empty
#   - janitor: clean_names
#   - dplyr: filter, bind_rows, mutate
#
# FUNCTIONS PROVIDED
# ------------------
#
# Intro-Standardization (Internal Helper) - Apply minimal processing to single file:
#
#   - apply_intro_standardization():
#       Uses packages: janitor (clean_names), dplyr (filter, mutate), readr
#       Calls internal: standardization/schema_helpers.R (detect_row_schema),
#                       validation.R (assert_data_frame),
#                       utilities.R (log_message)
#       Purpose: Remove invalid rows, add detector_id, detect schema version
#
# Local Data Loading - Load from data/raw/ directory:
#
#   - load_local_raw_data():
#       Uses packages: base R (list.files, dir, file.path), dplyr (bind_rows),
#                      readr (read_csv)
#       Calls internal: utilities.R (safe_read_csv, log_message),
#                       ingestion.R (apply_intro_standardization)
#       Purpose: Recursively find *id.csv files and combine into single tibble
#
# External Data Loading - Load from external sources:
#
#   - load_external_raw_data():
#       Uses packages: readr (read_csv), base R (file operations),
#                      dplyr (bind_rows)
#       Calls internal: utilities.R (safe_read_csv, log_message),
#                       ingestion.R (apply_intro_standardization)
#       Purpose: Load pre-specified external CSV file with standardization
#
# CHANGELOG
# ---------
# 2026-02-05: DOCUMENTATION & STANDARDS - Fixed header format
#             - Updated header to MODULE: format per documentation standards
#             - Fixed CONTENTS → FUNCTIONS PROVIDED per documentation standards
#             - Updated schema_helpers.R reference (moved to standardization/)
# 2026-02-05: DEPENDENCIES UPDATE - Updated schema_helpers.R reference
#             - Changed core/schema_detection.R to standardization/schema_helpers.R
#             - Reflects module reorganization (schema detection moved to standardization)
#             - Fixed CONTENTS → FUNCTIONS PROVIDED per documentation standards
# 2026-01-30: Refactored to use centralized assert_* functions from validation.R
# 2026-01-27: Refactored load_local_raw_data() to return combined tibble by default
#             Added return_combined parameter (TRUE = tibble, FALSE = legacy global objects)
#             Added files_processed attribute to returned tibble
# 2026-01-26: Added verbose parameter to all functions (default: FALSE)
# 2026-01-26: Gated all console messages with if (verbose)
# 2026-01-26: Fixed emoji encoding (ASCII replacements)
# 2026-01-12: Added files_processed attribute tracking for validation system
# 2026-01-12: Added rows_removed attribute tracking for validation system
# 2025-12-XX: Initial CODING_STANDARDS compliant version
#
# ==============================================================================


# ------------------------------------------------------------------------------
# Internal Helper: Apply Intro-Standardization
# ------------------------------------------------------------------------------

#' Apply Intro-Standardization to Raw KPro Data
#'
#' @description
#' Applies minimal standardization to get data into R environment cleanly.
#' This is Stage 1 processing - light touch only.
#'
#' @param df Raw data frame from single CSV file
#' @param file_path Original file path (for tracking)
#' @param verbose Logical. Print status messages? Default: FALSE
#'
#' @return Data frame with intro-standardization applied, or NULL if no valid rows
#'
#' @details
#' Intro-standardization steps:
#' 1. Remove N <= 0 or NA rows (no bat detections)
#' 2. Derive DetectorID from "In File" column
#' 3. Detect schema version (v1/v2/v3)
#' 4. Clean column names with janitor
#' 5. Add source_file column
#' 6. Store row removal count as attribute
#'
#' @section CONTRACT:
#' - Returns data frame with cleaned structure
#' - All columns remain as character (no type coercion yet)
#' - Does NOT transform alternates or species codes
#' - Returns NULL if no valid rows remain
#' - Sets 'rows_removed' attribute on returned dataframe
#'
#' @section DOES NOT:
#' - Parse dates/times
#' - Map DetectorID to Detector
#' - Remove or reorder columns
#' - Deduplicate
#'
#' @keywords internal
apply_intro_standardization <- function(df, file_path, verbose = FALSE) {
  
  # ----------------------------------------------------------------------------
  # Input validation (using centralized assertions)
  # ----------------------------------------------------------------------------
  
  assert_data_frame(df, "df")
  
  if (nrow(df) == 0) {
    warning(sprintf("Empty data frame from file: %s", basename(file_path)))
    return(NULL)
  }
  
  # ----------------------------------------------------------------------------
  # Step 1: Clean column names FIRST (before any other operations)
  # ----------------------------------------------------------------------------
  
  # Standardize to lowercase with underscores (prevents duplicate column issues)
  # This MUST happen first so all subsequent operations work with consistent names
  df <- janitor::clean_names(df)
  
  if (verbose) message("  Column names cleaned")
  
  # ----------------------------------------------------------------------------
  # Step 2: Remove rows where n <= 0 or NA
  # ----------------------------------------------------------------------------
  
  # Initialize row removal tracking
  n_removed <- 0
  
  # Check for 'n' column (lowercase after janitor cleaning)
  if ("n" %in% names(df)) {
    n_before <- nrow(df)
    
    # Filter out invalid rows (no bat detections)
    df <- df %>%
      dplyr::filter(!is.na(n), as.numeric(n) > 0)
    
    n_removed <- n_before - nrow(df)
    
    # Report removal if any rows filtered
    if (verbose && n_removed > 0) {
      message(sprintf("  Removed %d rows with n <= 0 or NA", n_removed))
    }
    
    # Check if any valid rows remain
    if (nrow(df) == 0) {
      if (verbose) message("  [!] No valid rows remaining after n filter")
      return(NULL)
    }
  } else {
    # Warn if n column missing (can't validate data quality)
    warning(sprintf("Column 'n' not found in %s - cannot filter invalid rows", basename(file_path)))
  }
  
  # ----------------------------------------------------------------------------
  # Step 3: Derive detector_id from "in_file" column
  # ----------------------------------------------------------------------------
  
  # Check for 'in_file' column (lowercase after janitor cleaning)
  if ("in_file" %in% names(df)) {
    # Extract first 16 characters as detector_id
    df$detector_id <- substr(df$in_file, 1, 16)
    if (verbose) message("  Derived detector_id from 'in_file' column")
  } else {
    # Set to NA if source column missing
    df$detector_id <- NA_character_
    warning("Column 'in_file' not found - detector_id set to NA")
  }
  
  # ----------------------------------------------------------------------------
  # Step 4: Detect KPro schema version (after cleaning!)
  # ----------------------------------------------------------------------------
  
  # Add schema_version column to each row
  df <- detect_row_schema(df, verbose = verbose)
  
  # Log the dominant schema for this file
  dominant <- get_dominant_schema(df)
  if (verbose) message(sprintf("  Detected schema: %s", dominant))
  
  # Optional: Show full distribution if mixed schemas
  schema_summary <- get_schema_summary(df)
  if (verbose && nrow(schema_summary) > 1) {
    message("  [!] Mixed schemas detected:")
    for (i in seq_len(nrow(schema_summary))) {
      message(sprintf("    - %s: %d rows (%.1f%%)",
                      schema_summary$schema_version[i],
                      schema_summary$count[i],
                      schema_summary$percent[i]))
    }
  }
  
  # ----------------------------------------------------------------------------
  # Step 5: Track source file
  # ----------------------------------------------------------------------------
  
  # Add column to track which file each row came from
  df$source_file <- basename(file_path)
  
  # ----------------------------------------------------------------------------
  # Step 6: Store row removal count as attribute
  # ----------------------------------------------------------------------------
  
  # Attach rows_removed as attribute so workflow can access it
  attr(df, "rows_removed") <- n_removed
  
  if (verbose) message(sprintf("  [OK] Intro-standardization complete: %d rows", nrow(df)))
  
  df
}


# ------------------------------------------------------------------------------
# Command 1: Load Local Raw Data
# ------------------------------------------------------------------------------

#' Load Local Raw Data from Directory
#'
#' @description
#' Loads all CSV files from a local directory, applies intro-standardization
#' to each, and either returns a combined tibble (default) or assigns
#' separate dataframes to the global environment (legacy behavior).
#'
#' @param local_dir Character. Path to local raw data directory.
#'   Default: "data/raw/"
#' @param pattern Character. File pattern to match.
#'   Default: "\\.csv$" (all CSVs)
#' @param return_combined Logical. If TRUE (default), returns combined tibble.
#'   If FALSE, assigns separate dataframes to envir (legacy behavior).
#' @param envir Environment. Only used when return_combined = FALSE.
#'   Default: .GlobalEnv
#' @param verbose Logical. Print progress messages to console.
#'   Default: FALSE.
#'
#' @return
#'   If return_combined = TRUE: Tibble with combined data (or NULL if no files).
#'     Attributes: files_processed, rows_removed
#'   If return_combined = FALSE: Invisible integer (number of files loaded).
#'     Creates raw_file_001, raw_file_002, ... in envir.
#'
#' @details
#' All files go through intro-standardization:
#' - N <= 0 or NA rows removed
#' - DetectorID derived
#' - Schema version detected
#' - Column names cleaned
#'
#' @section CONTRACT:
#' - Loads ALL CSV files matching pattern from directory
#' - Applies intro-standardization to each file
#' - Tracks files_processed and rows_removed as attributes
#' - Skips unreadable files (does not stop)
#' - Returns NULL if directory missing or no files found
#'
#' @section DOES NOT:
#' - Apply full schema transformation (use standardize_kpro_schema)
#' - Map detectors or transform species codes
#' - Search subdirectories (recursive = FALSE)
#' - Stop execution on empty directory
#'
#' @examples
#' \dontrun{
#' # Default: return combined tibble (pipeline usage)
#' local_data <- load_local_raw_data(verbose = TRUE)
#' nrow(local_data)
#' attr(local_data, "files_processed")
#'
#' # Legacy: create separate global objects
#' n_files <- load_local_raw_data(return_combined = FALSE, verbose = TRUE)
#' ls(pattern = "^raw_file")
#' }
#'
#' @export
load_local_raw_data <- function(
    local_dir = "data/raw/",
    pattern = "\\.csv$",
    return_combined = TRUE,
    envir = .GlobalEnv,
    verbose = FALSE
) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!dir.exists(local_dir)) {
    if (verbose) message(sprintf("[!] Directory does not exist: %s", local_dir))
    
    if (return_combined) {
      return(NULL)
    } else {
      return(invisible(0))
    }
  }
  
  # -------------------------
  # Discovery: Find CSV files
  # -------------------------
  
  if (verbose) {
    message("\n=== Loading Local Raw Data ===")
    message(sprintf("  Directory: %s", local_dir))
  }
  
  file_paths <- list.files(
    path = local_dir,
    pattern = pattern,
    full.names = TRUE,
    recursive = FALSE
  )
  
  if (length(file_paths) == 0) {
    if (verbose) message(sprintf("  [!] No CSV files found in %s", local_dir))
    
    if (return_combined) {
      return(NULL)
    } else {
      return(invisible(0))
    }
  }
  
  if (verbose) message(sprintf("  Found %d CSV file(s)", length(file_paths)))
  
  # -------------------------
  # Process each file
  # -------------------------
  
  datasets <- list()
  total_rows_removed <- 0
  files_processed <- 0
  
  for (i in seq_along(file_paths)) {
    fp <- file_paths[i]
    
    if (verbose) message(sprintf("  [%d/%d] Processing: %s", i, length(file_paths), basename(fp)))
    
    # Read file safely
    df <- safe_read_csv(fp)
    
    if (is.null(df)) {
      if (verbose) message("    [X] Failed to read file - skipping")
      next
    }
    
    # Apply intro-standardization
    df_std <- apply_intro_standardization(df, fp, verbose = verbose)
    
    if (is.null(df_std) || nrow(df_std) == 0) {
      if (verbose) message("    [X] No valid rows after intro-standardization - skipping")
      next
    }
    
    # Track rows removed
    rows_removed <- attr(df_std, "rows_removed") %||% 0
    total_rows_removed <- total_rows_removed + rows_removed
    
    files_processed <- files_processed + 1
    
    if (return_combined) {
      # Store in list for later combination
      datasets[[basename(fp)]] <- df_std
      if (verbose) message(sprintf("    [OK] %s rows", format(nrow(df_std), big.mark = ",")))
      
    } else {
      # Legacy behavior: assign to global environment
      df_name <- sprintf("raw_file_%03d", files_processed)
      assign(df_name, df_std, envir = envir)
      if (verbose) message(sprintf("    [OK] Stored as: %s", df_name))
    }
  }
  
  # -------------------------
  # Return based on mode
  # -------------------------
  
  if (return_combined) {
    # Combined tibble mode
    if (length(datasets) == 0) {
      if (verbose) message("  [!] No files successfully processed")
      return(NULL)
    }
    
    combined <- dplyr::bind_rows(datasets)
    attr(combined, "files_processed") <- files_processed
    attr(combined, "rows_removed") <- total_rows_removed
    
    if (verbose) {
      message("========================================")
      message(sprintf("  [OK] Combined %d file(s): %s rows",
                      files_processed,
                      format(nrow(combined), big.mark = ",")))
      if (total_rows_removed > 0) {
        message(sprintf("  [*] Rows removed (invalid): %s",
                        format(total_rows_removed, big.mark = ",")))
      }
      message("========================================")
    }
    
    return(combined)
    
  } else {
    # Legacy mode: objects in global environment
    if (verbose) {
      message("========================================")
      message(sprintf("  [OK] Loaded %d file(s) into environment", files_processed))
      if (files_processed > 0) {
        message(sprintf("  Dataframes: raw_file_001 through raw_file_%03d", files_processed))
      }
      message("========================================")
    }
    
    return(invisible(files_processed))
  }
}


# ------------------------------------------------------------------------------
# Command 2: Load External Raw Data
# ------------------------------------------------------------------------------

#' Load External Raw Data from External Directory
#'
#' @description
#' Recursively searches external directory for files named "id.csv",
#' applies intro-standardization to each, and binds all into a single
#' dataframe.
#'
#' @param root_dir Root directory to search recursively
#' @param pattern File pattern (default: "id\\.csv$")
#' @param verbose Logical. Print status messages? Default: FALSE
#'
#' @return Single combined dataframe with all external data
#'
#' @details
#' All files go through intro-standardization:
#' - N <= 0 or NA rows removed
#' - DetectorID derived
#' - Schema version detected
#' - Column names cleaned
#'
#' Files are then combined with bind_rows().
#'
#' Total row removal count stored as 'rows_removed' attribute on returned dataframe.
#'
#' @section CONTRACT:
#' - Recursively searches for files matching pattern
#' - Applies same intro-standardization to each
#' - Combines all into single dataframe
#' - Skips unreadable files with warning
#' - Returns combined dataframe (or empty tibble if no valid files)
#' - Combined dataframe has 'rows_removed' attribute (sum across all files)
#'
#' @section DOES NOT:
#' - Store as separate dataframes (use load_local_raw_data for that)
#' - Apply full standardization (Stage 2)
#' - Deduplicate across files (happens in Stage 2)
#'
#' @examples
#' \dontrun{
#' # Load from external hard drive
#' external_data <- load_external_raw_data("E:/bat_data_2024")
#'
#' # Result: single dataframe with all id.csv files
#' nrow(external_data)
#'
#' # Check total rows removed
#' attr(external_data, "rows_removed")
#' }
#'
#' @export
load_external_raw_data <- function(root_dir, pattern = "id\\.csv$", verbose = FALSE) {
  
  # ----------------------------------------------------------------------------
  # Input validation (using centralized assertion)
  # ----------------------------------------------------------------------------
  
  assert_directory_exists(root_dir, create = FALSE)
  
  # ----------------------------------------------------------------------------
  # Discovery: Recursively find all matching files
  # ----------------------------------------------------------------------------
  
  if (verbose) {
    message("\n=== Loading External Raw Data ===")
    message(sprintf("Directory: %s", root_dir))
    message(sprintf("Pattern: %s", pattern))
    message("Searching recursively...\n")
  }
  
  # Recursive search for files matching pattern (e.g., "id.csv")
  file_paths <- list.files(
    path = root_dir,
    pattern = pattern,
    full.names = TRUE,
    recursive = TRUE  # Search all subdirectories
  )
  
  # Check if any files found
  if (length(file_paths) == 0) {
    stop(sprintf("No files matching '%s' found in %s", pattern, root_dir))
  }
  
  if (verbose) message(sprintf("Found %d files matching pattern\n", length(file_paths)))
  
  # ----------------------------------------------------------------------------
  # Process each file and collect results
  # ----------------------------------------------------------------------------
  
  processed_files <- list()  # Store processed dataframes
  total_rows_removed <- 0    # Track total rows removed across all files
  
  for (i in seq_along(file_paths)) {
    fp <- file_paths[i]
    
    # Show relative path for long external paths
    rel_path <- sub(paste0("^", root_dir, "/?"), "", fp)
    if (verbose) message(sprintf("[%d/%d] Processing: %s", i, length(file_paths), rel_path))
    
    # Read file safely (returns NULL if fails)
    df <- safe_read_csv(fp)
    
    if (is.null(df)) {
      if (verbose) message("  [X] Failed to read file - skipping\n")
      next  # Skip to next file
    }
    
    # Apply intro-standardization
    df_standardized <- apply_intro_standardization(df, fp, verbose = verbose)
    
    if (is.null(df_standardized)) {
      if (verbose) message("  [X] No valid data after intro-standardization - skipping\n")
      next  # Skip to next file
    }
    
    # Accumulate row removal count from this file
    rows_removed_this_file <- attr(df_standardized, "rows_removed")
    if (!is.null(rows_removed_this_file)) {
      total_rows_removed <- total_rows_removed + rows_removed_this_file
    }
    
    # Add to list of processed files
    processed_files[[length(processed_files) + 1]] <- df_standardized
    
    if (verbose) message("")  # Blank line for readability
  }
  
  # ----------------------------------------------------------------------------
  # Combine all processed files
  # ----------------------------------------------------------------------------
  
  # Check if any files were successfully processed
  if (length(processed_files) == 0) {
    warning("No valid files processed - returning empty tibble")
    return(dplyr::tibble())
  }
  
  if (verbose) message("=== Combining Files ===")
  
  # Bind all dataframes together
  combined_data <- dplyr::bind_rows(processed_files)
  
  # Store total rows removed as attribute on combined dataframe
  attr(combined_data, "rows_removed") <- total_rows_removed
  
  # Store number of files processed as attribute
  attr(combined_data, "files_processed") <- length(processed_files)
  
  # ----------------------------------------------------------------------------
  # Report summary
  # ----------------------------------------------------------------------------
  
  if (verbose) {
    message("========================================")
    message(sprintf("[OK] Combined %d files", length(processed_files)))
    message(sprintf("  Total rows: %s", format(nrow(combined_data), big.mark = ",")))
    message(sprintf("  Rows removed: %s", format(total_rows_removed, big.mark = ",")))
    message(sprintf("  Unique DetectorIDs: %d", length(unique(combined_data$detector_id))))
    
    # Show schema version distribution
    schema_dist <- table(combined_data$schema_version)
    message("\n  Schema distribution:")
    for (version in names(schema_dist)) {
      message(sprintf("    - %s: %d rows", version, schema_dist[version]))
    }
    
    message("========================================\n")
  }
  
  combined_data
}