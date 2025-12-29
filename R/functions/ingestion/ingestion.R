# =============================================================================
# ingestion/ingestion.R — PRIMARY INGESTION (LOCKED CONTRACT)
# =============================================================================
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
#    - Rows with N ≤ 0 or NA are removed immediately (no bat = no data)
#    - Removal is logged with counts
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
#   - core/schema_detection.R: detect_row_schema
#   - janitor: clean_names
#   - dplyr: filter, bind_rows, mutate
#
# CONTENTS
# --------
#   - load_local_raw_data()
#   - load_external_raw_data()
#   - apply_intro_standardization()
#
# =============================================================================


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
#'
#' @return Data frame with intro-standardization applied, or NULL if no valid rows
#'
#' @details
#' Intro-standardization steps:
#' 1. Remove N ≤ 0 or NA rows (no bat detections)
#' 2. Derive DetectorID from "In File" column
#' 3. Detect schema version (v1/v2/v3)
#' 4. Clean column names with janitor
#' 5. Add source_file column
#'
#' @section CONTRACT:
#' - Returns data frame with cleaned structure
#' - All columns remain as character (no type coercion yet)
#' - Does NOT transform alternates or species codes
#' - Returns NULL if no valid rows remain
#'
#' @section DOES NOT:
#' - Parse dates/times
#' - Map DetectorID to Detector
#' - Remove or reorder columns
#' - Deduplicate
#'
#' @keywords internal
apply_intro_standardization <- function(df, file_path) {
  
  # -----------------
  # Input validation
  # -----------------
  
  if (!is.data.frame(df)) {
    stop("df must be a data frame")
  }
  
  if (nrow(df) == 0) {
    warning(sprintf("Empty data frame from file: %s", basename(file_path)))
    return(NULL)
  }
  
  # ------------------------------------------------------------------------------
  # Step 1: Clean column names FIRST (before any other operations)
  # ------------------------------------------------------------------------------
  
  # Standardize to lowercase with underscores (prevents duplicate column issues)
  # This MUST happen first so all subsequent operations work with consistent names
  df <- janitor::clean_names(df)
  
  message("  Column names cleaned")
  
  # ------------------------------------------------------------------------------
  # Step 2: Remove rows where n ≤ 0 or NA
  # ------------------------------------------------------------------------------
  
  # Check for 'n' column (lowercase after janitor cleaning)
  if ("n" %in% names(df)) {
    n_before <- nrow(df)
    
    # Filter out invalid rows (no bat detections)
    df <- df %>%
      dplyr::filter(!is.na(n), as.numeric(n) > 0)
    
    n_removed <- n_before - nrow(df)
    
    # Report removal if any rows filtered
    if (n_removed > 0) {
      message(sprintf("  Removed %d rows with n ≤ 0 or NA", n_removed))
    }
    
    # Check if any valid rows remain
    if (nrow(df) == 0) {
      message(sprintf("  ⚠️  No valid rows remaining after n filter"))
      return(NULL)
    }
  } else {
    # Warn if n column missing (can't validate data quality)
    warning(sprintf("Column 'n' not found in %s - cannot filter invalid rows", basename(file_path)))
  }
  
  # ------------------------------------------------------------------------------
  # Step 3: Derive detector_id from "in_file" column
  # ------------------------------------------------------------------------------
  
  # Check for 'in_file' column (lowercase after janitor cleaning)
  if ("in_file" %in% names(df)) {
    # Extract first 16 characters as detector_id
    df$detector_id <- substr(df$in_file, 1, 16)
    message(sprintf("  Derived detector_id from 'in_file' column"))
  } else {
    # Set to NA if source column missing
    df$detector_id <- NA_character_
    warning(sprintf("Column 'in_file' not found - detector_id set to NA"))
  }
  
  # ------------------------------------------------------------------------------
  # Step 4: Detect KPro schema version (after cleaning!)
  # ------------------------------------------------------------------------------
  
  # Add schema_version column to each row
  df <- detect_row_schema(df)
  
  # Log the dominant schema for this file
  dominant <- get_dominant_schema(df)
  message(sprintf("  Detected schema: %s", dominant))
  
  # Optional: Show full distribution if mixed schemas
  schema_summary <- get_schema_summary(df)
  if (nrow(schema_summary) > 1) {
    message("  ⚠️  Mixed schemas detected:")
    for (i in seq_len(nrow(schema_summary))) {
      message(sprintf("    - %s: %d rows (%.1f%%)",
                      schema_summary$schema_version[i],
                      schema_summary$count[i],
                      schema_summary$percent[i]))
    }
  }
  
  # ------------------------------------------------------------------------------
  # Step 5: Track source file
  # ------------------------------------------------------------------------------
  
  # Add column to track which file each row came from
  df$source_file <- basename(file_path)
  
  message(sprintf("  ✓ Intro-standardization complete: %d rows", nrow(df)))
  
  df
}


# ------------------------------------------------------------------------------
# Command 1: Load Local Raw Data
# ------------------------------------------------------------------------------

#' Load Local Raw Data from data/raw/
#'
#' @description
#' Loads ALL CSV files from data/raw/ directory (regardless of filename),
#' applies intro-standardization to each, and stores each as a separate
#' dataframe in the global R environment.
#'
#' @param local_dir Path to local raw data directory (default: "data/raw/")
#' @param pattern File pattern to match (default: "\\.csv$" - all CSVs)
#' @param envir Environment to assign dataframes to (default: .GlobalEnv)
#'
#' @return Invisible integer - number of files successfully loaded
#'
#' @details
#' Each file is stored as: raw_file_001, raw_file_002, etc.
#'
#' All files go through intro-standardization:
#' - N ≤ 0 or NA rows removed
#' - DetectorID derived
#' - Schema version detected
#' - Column names cleaned
#'
#' @section CONTRACT:
#' - Loads ALL CSV files from directory (not just "id.csv")
#' - Each file becomes separate dataframe in R environment
#' - Applies same intro-standardization to each
#' - Skips unreadable files with warning
#'
#' @section DOES NOT:
#' - Combine files into one dataframe (use load_external_raw_data for that)
#' - Apply full standardization (Stage 2)
#' - Map detectors or transform species codes
#'
#' @examples
#' \dontrun{
#' # Load all CSVs from data/raw/
#' load_local_raw_data()
#'
#' # Result: raw_file_001, raw_file_002, ... in environment
#' ls(pattern = "^raw_file")
#' }
#'
#' @export
load_local_raw_data <- function(local_dir = "data/raw/",
                                pattern = "\\.csv$",
                                envir = .GlobalEnv) {
  
  # ------------------------------------------------------------------------------
  # Input validation
  # ------------------------------------------------------------------------------
  
  if (!dir.exists(local_dir)) {
    stop(sprintf("Directory does not exist: %s", local_dir))
  }
  
  # ------------------------------------------------------------------------------
  # Discovery: Find all CSV files in local directory
  # ------------------------------------------------------------------------------
  
  message("\n=== Loading Local Raw Data ===")
  message(sprintf("Directory: %s", local_dir))
  
  # List all CSV files (any filename, not just "id.csv")
  file_paths <- list.files(
    path = local_dir,
    pattern = pattern,
    full.names = TRUE,
    recursive = FALSE  # Only immediate directory (not subdirectories)
  )
  
  # Check if any files found
  if (length(file_paths) == 0) {
    message(sprintf("⚠️  No CSV files found in %s\n", local_dir))
    return(invisible(0))  # Return 0 (no files loaded) instead of stopping
  }
  
  message(sprintf("Found %d CSV files\n", length(file_paths)))
  
  # ------------------------------------------------------------------------------
  # Process each file individually
  # ------------------------------------------------------------------------------
  
  files_loaded <- 0  # Counter for successfully loaded files
  
  for (i in seq_along(file_paths)) {
    fp <- file_paths[i]
    
    message(sprintf("[%d/%d] Processing: %s", i, length(file_paths), basename(fp)))
    
    # Read file safely (returns NULL if fails)
    df <- safe_read_csv(fp)
    
    if (is.null(df)) {
      message("  ✗ Failed to read file - skipping\n")
      next  # Skip to next file
    }
    
    # Apply intro-standardization
    df_standardized <- apply_intro_standardization(df, fp)
    
    if (is.null(df_standardized)) {
      message("  ✗ No valid data after intro-standardization - skipping\n")
      next  # Skip to next file
    }
    
    # Create unique dataframe name
    df_name <- sprintf("raw_file_%03d", files_loaded + 1)
    
    # Assign to specified environment (default: global)
    assign(df_name, df_standardized, envir = envir)
    
    message(sprintf("  ✓ Stored as: %s\n", df_name))
    
    files_loaded <- files_loaded + 1
  }
  
  # ------------------------------------------------------------------------------
  # Report summary
  # ------------------------------------------------------------------------------
  
  message("========================================")
  message(sprintf("✓ Loaded %d files into R environment", files_loaded))
  
  if (files_loaded > 0) {
    message(sprintf("  Dataframes: raw_file_001 through raw_file_%03d", files_loaded))
    message("\n  Access with: raw_file_001, raw_file_002, etc.")
  }
  
  message("========================================\n")
  
  invisible(files_loaded)
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
#'
#' @return Single combined dataframe with all external data
#'
#' @details
#' All files go through intro-standardization:
#' - N ≤ 0 or NA rows removed
#' - DetectorID derived
#' - Schema version detected
#' - Column names cleaned
#'
#' Files are then combined with bind_rows().
#'
#' @section CONTRACT:
#' - Recursively searches for files matching pattern
#' - Applies same intro-standardization to each
#' - Combines all into single dataframe
#' - Skips unreadable files with warning
#' - Returns combined dataframe (or empty tibble if no valid files)
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
#' }
#'
#' @export
load_external_raw_data <- function(root_dir, pattern = "id\\.csv$") {
  
  # ------------------------------------------------------------------------------
  # Input validation
  # ------------------------------------------------------------------------------
  
  if (!dir.exists(root_dir)) {
    stop(sprintf("Directory does not exist: %s", root_dir))
  }
  
  # ------------------------------------------------------------------------------
  # Discovery: Recursively find all matching files
  # ------------------------------------------------------------------------------
  
  message("\n=== Loading External Raw Data ===")
  message(sprintf("Directory: %s", root_dir))
  message(sprintf("Pattern: %s", pattern))
  message("Searching recursively...\n")
  
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
  
  message(sprintf("Found %d files matching pattern\n", length(file_paths)))
  
  # ------------------------------------------------------------------------------
  # Process each file and collect results
  # ------------------------------------------------------------------------------
  
  processed_files <- list()  # Store processed dataframes
  
  for (i in seq_along(file_paths)) {
    fp <- file_paths[i]
    
    # Show relative path for long external paths
    rel_path <- sub(paste0("^", root_dir, "/?"), "", fp)
    message(sprintf("[%d/%d] Processing: %s", i, length(file_paths), rel_path))
    
    # Read file safely (returns NULL if fails)
    df <- safe_read_csv(fp)
    
    if (is.null(df)) {
      message("  ✗ Failed to read file - skipping\n")
      next  # Skip to next file
    }
    
    # Apply intro-standardization
    df_standardized <- apply_intro_standardization(df, fp)
    
    if (is.null(df_standardized)) {
      message("  ✗ No valid data after intro-standardization - skipping\n")
      next  # Skip to next file
    }
    
    # Add to list of processed files
    processed_files[[length(processed_files) + 1]] <- df_standardized
    
    message("")  # Blank line for readability
  }
  
  # ------------------------------------------------------------------------------
  # Combine all processed files
  # ------------------------------------------------------------------------------
  
  # Check if any files were successfully processed
  if (length(processed_files) == 0) {
    warning("No valid files processed - returning empty tibble")
    return(dplyr::tibble())
  }
  
  message("=== Combining Files ===")
  
  # Bind all dataframes together
  combined_data <- dplyr::bind_rows(processed_files)
  
  # ------------------------------------------------------------------------------
  # Report summary
  # ------------------------------------------------------------------------------
  
  message("========================================")
  message(sprintf("✓ Combined %d files", length(processed_files)))
  message(sprintf("  Total rows: %s", format(nrow(combined_data), big.mark = ",")))
  message(sprintf("  Unique DetectorIDs: %d", length(unique(combined_data$detector_id))))
  
  # Show schema version distribution
  schema_dist <- table(combined_data$schema_version)
  message("\n  Schema distribution:")
  for (version in names(schema_dist)) {
    message(sprintf("    - %s: %d files", version, schema_dist[version]))
  }
  
  message("========================================\n")
  
  combined_data
}

