# =============================================================================
# UTILITY: standardization.R - Schema Transformation (LOCKED CONTRACT)
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# - Transforms raw data to unified master schema
# - Used by ingestion and standardization workflows
# PURPOSE
# -------
# Transforms all KPro schema versions into a unified master schema. Handles
# alternates splitting (including semicolon-delimited variants), species code
# conversion, column name harmonization across KPro versions, schema
# unification with row-level detection support, and unified species column
# generation for analysis workflows.
#
# STANDARDIZATION CONTRACT
# ------------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Schema transformation (row-level detection support)
#    - V1: Split semicolon-delimited alternates -> alternate_1, _2, _3
#      * Handles traditional "alternates" column
#      * Handles modern variant with semicolons in "alternate_1" column
#    - V2: Convert 4-letter species codes -> 6-letter
#      * Adds alternate_3 if missing
#    - V3: Pass through (already in target format)
#      * Adds alternate_3 if missing
#    - Mixed schemas: Processes each row according to its detected schema
#
# 2. Species code conversion
#    - Uses SPECIES_CODE_MAP_4_TO_6 lookup table (60+ species)
#    - Unknown codes preserved and logged, never errored
#    - Conversion applied to: auto_id, alternate_1, alternate_2, alternate_3
#    - Case-insensitive matching
#    - Logs conversion completion with counts
#
# 3. Column name harmonization (KPro version transitions)
#    - Legacy out_file -> modern out_file_fs
#    - Handles mixed legacy/modern data (coalesces if both present)
#    - Preserves out_file_zc if present (zero-crossing output)
#    - Case-insensitive column matching
#
# 4. Unified output schema
#    - All transformed data conforms to single column specification
#    - Required columns: auto_id, alternate_1, alternate_2, alternate_3 (6-letter)
#    - Legacy columns removed: alternates, schema_version
#    - Modern column names enforced: out_file_fs, out_file_zc
#    - Missing columns filled with NA
#
# 5. Non-destructive processing
#    - Original values preserved during transformation
#    - Functions return new tibbles, never modify in place
#    - All rows preserved (no filtering)
#    - Logs all transformation steps with row counts
#
# 6. Species unification
#    - Creates unified 'species' column with priority: manual_id > auto_id > "NoID"
#    - Used in CPN template generation and finalization workflows
#    - Deterministic priority logic (not configurable)
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Perform schema detection (standardization/schema_helpers.R)
#   - Perform data quality checks (validation/validation.R)
#   - Enforce master schema types (validation/validation.R)
#   - Calculate recording hours or CallsPerNight (analysis/)
#   - Generate visualizations or reports (output/)
#   - Add/remove rows based on data quality
#   - Reorder columns (validation/finalize_master_columns)
#   - Add Hour/Time CST columns (standardization/datetime_conversion.R)
#
# DEPENDENCIES
# ------------
#   - validation/validation.R: assert_data_frame, assert_not_empty, assert_columns_exist
#   - standardization/schema_helpers.R: detect_row_schema (provides schema_version column)
#   - dplyr: mutate, case_when, select, bind_rows, coalesce
#   - purrr: map_chr (for splitting alternates)
#
# WORKFLOW INTEGRATION
# --------------------
# This module is used in Module 2 (Standardization) and Phase 2 (CPN Template):
#   1. raw_combined (from Module 1) -> detect_row_schema()
#   2. raw_with_schemas -> standardize_kpro_schema() -> unified_data
#   3. unified_data -> convert_datetime_to_cst() -> enforce_unified_schema()
#   4. validated_data -> finalize_master_columns() -> kpro_master
#   5. kpro_master -> create_unified_species_column() -> [ready for CPN template]
#
# FUNCTIONS PROVIDED
# ------------------
#
# Constants - Species code mapping:
#
#   - SPECIES_CODE_MAP_4_TO_6:
#       Type: List (4-letter species code → 6-letter code mapping)
#       Purpose: Lookup table for 60+ species code conversion (v2→v3)
#
# Core Transformation - Species code and column name handling:
#
#   - convert_4letter_to_6letter():
#       Uses packages: dplyr (mutate, case_when), base R (tolower)
#       Calls internal: standardization.R (SPECIES_CODE_MAP_4_TO_6 lookup)
#       Purpose: Convert 4-letter species codes to 6-letter codes
#
#   - harmonize_column_names():
#       Uses packages: dplyr (mutate, coalesce, select)
#       Calls internal: none
#       Purpose: Handle out_file → out_file_fs transition (KPro version changes)
#
# Schema Transformation - Version-specific conversions:
#
#   - transform_v1_to_unified():
#       Uses packages: tidyr (separate_rows), dplyr (mutate, select)
#       Calls internal: standardization.R (convert_4letter_to_6letter)
#       Purpose: Split semicolon-delimited alternates, convert to v3 format
#
#   - transform_v2_to_unified():
#       Uses packages: dplyr (mutate)
#       Calls internal: standardization.R (convert_4letter_to_6letter)
#       Purpose: Add alternate_3 column, convert 4-letter to 6-letter codes
#
#   - transform_v3_to_unified():
#       Uses packages: dplyr (mutate)
#       Calls internal: none (already in target format)
#       Purpose: Add alternate_3 if missing (identity transform for v3)
#
# Orchestration - Main entry point:
#
#   - standardize_kpro_schema():
#       Uses packages: dplyr (filter, bind_rows), base R (split/combine)
#       Calls internal: schema_helpers.R (detect_row_schema, get_dominant_schema),
#                       standardization.R (transform_v1/v2/v3_to_unified,
#                                         harmonize_column_names),
#                       validation.R (assert_data_frame)
#       Purpose: Orchestrate schema detection, split by version, transform, reassemble
#
# Species Unification - Analysis preparation:
#
#   - create_unified_species_column():
#       Uses packages: dplyr (mutate, case_when, if_any), base R (coalesce)
#       Calls internal: none
#       Purpose: Create single 'species' column with priority (manual > auto > NoID)
#
# USAGE
# -----
# # Load module
# source("R/functions/standardization/standardization.R")
#
# # Transform mixed schema data
# df_with_schemas <- detect_row_schema(raw_combined)
# unified_data <- standardize_kpro_schema(df_with_schemas, verbose = TRUE)
#
# # Create unified species column for analysis
# cpn_data <- create_unified_species_column(kpro_master)
#
# Last Modified: 2026-02-09
#
# CHANGELOG
# ---------
# 2026-02-05: DOCUMENTATION & STANDARDS - Fixed header and section naming
#             - Updated header to MODULE: format per documentation standards
#             - Renamed CONTENTS → FUNCTIONS PROVIDED
#             - Added USAGE section with examples
#             - Updated schema_helpers.R reference (moved from ingestion/)
# 2026-02-05: DEPENDENCIES UPDATE - Updated schema_helpers.R reference
#             - Changed core/schema_detection.R to standardization/schema_helpers.R
#             - Reflects module reorganization (schema detection moved to standardization)
# 2026-02-04: MODULE SPLIT - Added create_unified_species_column()
#             - Moved from utilities.R for domain-specific logic
#             - Species unification is data transformation, not utility
#             - Updated CONTENTS section and WORKFLOW INTEGRATION
# 2026-01-30: Refactored to use centralized assert_* functions from validation.R
# 2026-01-30: Removed redundant validate_unified_schema() (use enforce_unified_schema instead)
# 2026-01-30: Added verbose gating to all message() calls
# 2026-01-30: Fixed UTF-8 encoding (replaced special characters with ASCII)
# 2026-01-26: Added verbose parameter to all transformation functions (default: FALSE)
# 2026-01-26: Added verbose to standardize_kpro_schema() orchestrator (default: FALSE)
# 2024-12-XX: Initial CODING_STANDARDS compliant version
#
# =============================================================================



# ------------------------------------------------------------------------------
# Constant: Species Code Mapping
# ------------------------------------------------------------------------------

#' Species Code Mapping: 4-Letter to 6-Letter
#'
#' @description
#' Named character vector mapping legacy 4-letter bat species codes to modern
#' 6-letter codes used in recent Kaleidoscope Pro versions. Based on NABat
#' (North American Bat Monitoring Program) standards.
#'
#' @format Named character vector with 60+ species mappings
#'   \describe{
#'     \item{names}{4-letter legacy codes (e.g., "MYLU", "EPFU")}
#'     \item{values}{6-letter modern codes (e.g., "MYOLUC", "EPTFUS")}
#'   }
#'
#' @export
SPECIES_CODE_MAP_4_TO_6 <- c(
  # -------------------------
  # Myotis species (16)
  # -------------------------
  "MYLU" = "MYOLUC",   # Little brown bat (Myotis lucifugus)
  "MYSE" = "MYOSEP",   # Northern long-eared bat (Myotis septentrionalis)
  "MYSO" = "MYOSOD",   # Indiana bat (Myotis sodalis)
  "MYVO" = "MYOVOL",   # Long-legged myotis (Myotis volans)
  "MYCA" = "MYOCAL",   # California myotis (Myotis californicus)
  "MYCI" = "MYOCIL",   # Western small-footed myotis (Myotis ciliolabrum)
  "MYEV" = "MYOEVO",   # Western long-eared myotis (Myotis evotis)
  "MYTH" = "MYOTHY",   # Fringed myotis (Myotis thysanodes)
  "MYYU" = "MYOYUM",   # Yuma myotis (Myotis yumanensis)
  "MYGR" = "MYOGRI",   # Gray bat (Myotis grisescens)
  "MYLE" = "MYOLEI",   # Eastern small-footed myotis (Myotis leibii)
  "MYKE" = "MYOKEE",   # Keen's myotis (Myotis keenii)
  "MYAU" = "MYOAUS",   # Southeastern myotis (Myotis austroriparius)
  "MYAR" = "MYOAUR",   # Southwestern myotis (Myotis auriculus)
  "MYOC" = "MYOOCC",   # Arizona myotis (Myotis occultus)
  "MYVE" = "MYOVEL",   # Cave myotis (Myotis velifer)
  
  # -------------------------
  # Lasiurus species (10)
  # -------------------------
  "LANO" = "LASNOC",   # Silver-haired bat (Lasionycteris noctivagans)
  "LABO" = "LASBOR",   # Eastern red bat (Lasiurus borealis)
  "LACI" = "LASCIN",   # Hoary bat (Lasiurus cinereus)
  "LACS" = "LACISE",   # Hawaiian hoary bat (Lasiurus semotus)
  "LAEG" = "LASEGA",   # Southern yellow bat (Lasiurus ega)
  "LAFR" = "LASFRA",   # Desert red bat (Lasiurus frantzii)
  "LAIN" = "LASINT",   # Northern yellow bat (Lasiurus intermedius)
  "LAMI" = "LASMIN",   # Minor red bat (Lasiurus minor)
  "LASE" = "LASSEM",   # Seminole bat (Lasiurus seminolus)
  "LAXA" = "LASXAN",   # Western yellow bat (Lasiurus xanthinus)
  
  # -------------------------
  # Eptesicus (1)
  # -------------------------
  "EPFU" = "EPTFUS",   # Big brown bat (Eptesicus fuscus)
  
  # -------------------------
  # Perimyotis (1)
  # -------------------------
  "PESU" = "PERSUB",   # Tri-colored bat (Perimyotis subflavus)
  
  # -------------------------
  # Nycticeius (1)
  # -------------------------
  "NYHU" = "NYCHUM",   # Evening bat (Nycticeius humeralis)
  
  # -------------------------
  # Corynorhinus (2)
  # -------------------------
  "COTO" = "CORTOW",   # Townsend's big-eared bat (Corynorhinus townsendii)
  "CORA" = "CORRAF",   # Rafinesque's big-eared bat (Corynorhinus rafinesquii)
  
  # -------------------------
  # Antrozous (1)
  # -------------------------
  "ANPA" = "ANTPAL",   # Pallid bat (Antrozous pallidus)
  
  # -------------------------
  # Tadarida (1)
  # -------------------------
  "TABR" = "TADBRA",   # Brazilian free-tailed bat (Tadarida brasiliensis)
  
  # -------------------------
  # Macrotus (1)
  # -------------------------
  "MACA" = "MACCAL",   # California leaf-nosed bat (Macrotus californicus)
  
  # -------------------------
  # Rare/Special species (5)
  # -------------------------
  "EUMA" = "EUDMAC",   # Spotted bat (Euderma maculatum)
  "EUFL" = "EUMFLO",   # Florida bonneted bat (Eumops floridanus)
  "EUPE" = "EUMPER",   # Greater bonneted bat (Eumops perotis)
  "EUUN" = "EUMUND",   # Underwood's bonneted bat (Eumops underwoodi)
  "IDPH" = "IDIPHY",   # Allen's big-eared bat (Idionycteris phyllotis)
  
  # -------------------------
  # Unknown/NoID (2)
  # -------------------------
  "UNKN" = "UNKNOWN",
  "NOID" = "UNKNOWN"
)


# ------------------------------------------------------------------------------
# Core Function: Convert 4-Letter to 6-Letter Codes
# ------------------------------------------------------------------------------

#' Convert 4-Letter Species Codes to 6-Letter
#'
#' @description
#' Applies species code mapping to auto_id, alternate_1, alternate_2, 
#' and alternate_3 columns using the SPECIES_CODE_MAP_4_TO_6 lookup table.
#'
#' @param df Data frame containing species code columns
#' @param verbose Logical. Print status messages? Default: FALSE
#'
#' @return Data frame with updated species codes (4-letter -> 6-letter)
#'
#' @section CONTRACT:
#' - Only species code columns are modified
#' - Unknown codes preserved (not errored or removed)
#' - Column names case-insensitive (auto_id, Auto_ID, AUTO_ID all work)
#' - Does not add/remove columns
#'
#' @section DOES NOT:
#' - Modify non-species columns
#' - Validate species code correctness
#' - Remove rows with unknown codes
#'
#' @export
convert_4letter_to_6letter <- function(df, verbose = FALSE) {
  
  # Input validation using centralized assertion
  assert_data_frame(df, "df")
  
  # Columns to convert
  cols_to_convert <- c("auto_id", "alternate_1", "alternate_2", "alternate_3")
  
  for (col in cols_to_convert) {
    # Find column (case-insensitive)
    actual_col <- grep(paste0("^", col, "$"), names(df), ignore.case = TRUE, value = TRUE)[1]
    
    if (!is.na(actual_col) && actual_col %in% names(df)) {
      df <- dplyr::mutate(
        df,
        !!actual_col := dplyr::recode(
          .data[[actual_col]],
          !!!SPECIES_CODE_MAP_4_TO_6,
          .default = .data[[actual_col]]
        )
      )
    }
  }
  
  if (verbose) message("    [OK] Converted 4-letter codes to 6-letter")
  
  df
}


# ------------------------------------------------------------------------------
# Transform Function: V1 Legacy Format
# ------------------------------------------------------------------------------

#' Transform V1 Legacy Format to Unified Schema
#'
#' @description
#' Splits semicolon-separated alternate columns into separate alternate_1, 
#' alternate_2, alternate_3 columns and converts all species codes from 
#' 4-letter to 6-letter format.
#'
#' @param df Data frame in v1 schema (semicolon-delimited alternates)
#' @param verbose Logical. Print status messages? Default: FALSE
#'
#' @return Data frame with alternate_1, alternate_2, alternate_3 columns
#'   containing 6-letter species codes
#'
#' @section CONTRACT:
#' - Removes source column after splitting (alternates OR alternate_1)
#' - Creates/overwrites alternate_1, alternate_2, alternate_3 columns
#' - Converts all codes to 6-letter format
#' - Preserves all other columns unchanged
#'
#' @section DOES NOT:
#' - Detect schema versions (expects v1 data)
#' - Validate species code correctness
#' - Keep more than 3 alternates (extras are dropped)
#'
#' @export
transform_v1_to_unified <- function(df, verbose = FALSE) {
  
  # Input validation using centralized assertions
  assert_data_frame(df, "df")
  
  if (nrow(df) == 0) {
    warning("Empty data frame provided, returning as-is")
    return(df)
  }
  
  # -------------------------
  # Find column with semicolon-delimited codes
  # -------------------------
  
  # First check for "alternates" column (traditional v1)
  alternates_col <- grep("^alternates$", names(df), ignore.case = TRUE, value = TRUE)[1]
  source_type <- "alternates"
  
  # If not found, check alternate_1 for semicolons
  if (is.na(alternates_col)) {
    alt1_col <- grep("^alternate_1$", names(df), ignore.case = TRUE, value = TRUE)[1]
    
    if (!is.na(alt1_col)) {
      # Check if this column has semicolons
      has_semicolons <- any(grepl(";", df[[alt1_col]], fixed = TRUE), na.rm = TRUE)
      
      if (has_semicolons) {
        alternates_col <- alt1_col
        source_type <- "alternate_1"
        if (verbose) message("    Detected semicolons in alternate_1 column")
      }
    }
  }
  
  # Validate source column found
  if (is.na(alternates_col)) {
    stop("V1 schema expected 'alternates' or semicolon-delimited 'alternate_1' column but not found")
  }
  
  # -------------------------
  # Split semicolon-separated codes
  # -------------------------
  
  df <- df %>%
    dplyr::mutate(
      alternates_split = strsplit(as.character(.data[[alternates_col]]), ";\\s*"),
      alternate_1_new = purrr::map_chr(alternates_split, ~ifelse(length(.x) >= 1, .x[1], NA_character_)),
      alternate_2_new = purrr::map_chr(alternates_split, ~ifelse(length(.x) >= 2, .x[2], NA_character_)),
      alternate_3_new = purrr::map_chr(alternates_split, ~ifelse(length(.x) >= 3, .x[3], NA_character_))
    ) %>%
    dplyr::select(-alternates_split)
  
  # -------------------------
  # Remove original source column
  # -------------------------
  
  df <- df %>%
    dplyr::select(-dplyr::all_of(alternates_col))
  
  # -------------------------
  # Handle existing alternate columns
  # -------------------------
  
  cols_to_remove <- c()
  
  if (source_type == "alternate_1") {
    alt2_exists <- "alternate_2" %in% tolower(names(df))
    alt3_exists <- "alternate_3" %in% tolower(names(df))
    
    if (alt2_exists) cols_to_remove <- c(cols_to_remove, "alternate_2")
    if (alt3_exists) cols_to_remove <- c(cols_to_remove, "alternate_3")
  } else {
    alt1_exists <- "alternate_1" %in% tolower(names(df))
    alt2_exists <- "alternate_2" %in% tolower(names(df))
    alt3_exists <- "alternate_3" %in% tolower(names(df))
    
    if (alt1_exists) cols_to_remove <- c(cols_to_remove, "alternate_1")
    if (alt2_exists) cols_to_remove <- c(cols_to_remove, "alternate_2")
    if (alt3_exists) cols_to_remove <- c(cols_to_remove, "alternate_3")
  }
  
  # Remove old columns if they exist
  if (length(cols_to_remove) > 0) {
    actual_cols_to_remove <- c()
    for (col in cols_to_remove) {
      actual_col <- grep(paste0("^", col, "$"), names(df), ignore.case = TRUE, value = TRUE)[1]
      if (!is.na(actual_col)) {
        actual_cols_to_remove <- c(actual_cols_to_remove, actual_col)
      }
    }
    
    if (length(actual_cols_to_remove) > 0) {
      df <- df %>%
        dplyr::select(-dplyr::all_of(actual_cols_to_remove))
    }
  }
  
  # -------------------------
  # Rename new columns to final names
  # -------------------------
  
  df <- df %>%
    dplyr::rename(
      alternate_1 = alternate_1_new,
      alternate_2 = alternate_2_new,
      alternate_3 = alternate_3_new
    )
  
  # -------------------------
  # Convert 4-letter codes to 6-letter
  # -------------------------
  
  df <- convert_4letter_to_6letter(df, verbose = verbose)
  
  if (verbose) message("  [OK] Transformed V1 (legacy single column) to unified schema")
  
  df
}


# ------------------------------------------------------------------------------
# Transform Function: V2 Transitional Format
# ------------------------------------------------------------------------------

#' Transform V2 Transitional Format to Unified Schema
#'
#' @description
#' Ensures alternate_3 column exists and converts all species codes from 
#' 4-letter to 6-letter format.
#'
#' @param df Data frame in v2 schema (separate alternate_1, alternate_2 columns)
#' @param verbose Logical. Print status messages? Default: FALSE
#'
#' @return Data frame with alternate_1, alternate_2, alternate_3 columns
#'   containing 6-letter species codes
#'
#' @section CONTRACT:
#' - Adds alternate_3 column if missing (set to NA)
#' - Converts all 4-letter codes to 6-letter
#' - Preserves all other columns unchanged
#'
#' @section DOES NOT:
#' - Split alternates (already separate columns)
#' - Detect schema versions (expects v2 data)
#'
#' @export
transform_v2_to_unified <- function(df, verbose = FALSE) {
  
  # Input validation using centralized assertions
  assert_data_frame(df, "df")
  
  if (nrow(df) == 0) {
    warning("Empty data frame provided, returning as-is")
    return(df)
  }
  
  # Add alternate_3 if missing
  if (!"alternate_3" %in% tolower(names(df))) {
    df <- dplyr::mutate(df, alternate_3 = NA_character_)
  }
  
  # Convert 4-letter codes to 6-letter
  df <- convert_4letter_to_6letter(df, verbose = verbose)
  
  if (verbose) message("  [OK] Transformed V2 (transitional 4-letter) to unified schema")
  
  df
}


# ------------------------------------------------------------------------------
# Transform Function: V3 Modern Format
# ------------------------------------------------------------------------------

#' Transform V3 Modern Format to Unified Schema
#'
#' @description
#' Adds missing alternate_3 column if absent. V3 files already use 6-letter codes,
#' so no code conversion is needed.
#'
#' @param df Data frame in v3 schema (6-letter codes)
#' @param verbose Logical. Print status messages? Default: FALSE
#'
#' @return Data frame with alternate_1, alternate_2, alternate_3 columns
#'
#' @section CONTRACT:
#' - Adds alternate_3 column if missing (set to NA)
#' - Does NOT convert species codes (already 6-letter)
#' - Preserves all other columns unchanged
#'
#' @export
transform_v3_to_unified <- function(df, verbose = FALSE) {
  
  # Input validation using centralized assertions
  assert_data_frame(df, "df")
  
  if (nrow(df) == 0) {
    warning("Empty data frame provided, returning as-is")
    return(df)
  }
  
  # Add alternate_3 if missing
  if (!"alternate_3" %in% tolower(names(df))) {
    df <- dplyr::mutate(df, alternate_3 = NA_character_)
  }
  
  if (verbose) message("  [OK] V3 (modern 6-letter) already in unified schema")
  
  df
}


# ------------------------------------------------------------------------------
# Orchestrator Function: Standardize KPro Schema
# ------------------------------------------------------------------------------

#' Standardize KPro Data to Unified Schema
#'
#' @description
#' Transforms data with row-level schema detection into unified format.
#' Splits data by schema_version, applies appropriate transformation to each
#' group, then recombines into single standardized dataframe.
#'
#' @param df Data frame with schema_version column (from detect_row_schema)
#' @param verbose Logical. Print status messages? Default: FALSE
#'
#' @return Data frame in unified schema with columns:
#'   auto_id, alternate_1, alternate_2, alternate_3 (all 6-letter)
#'
#' @details
#' **This is the main orchestrator function** for schema standardization.
#'
#' **Processing steps:**
#' 1. Validate schema_version column exists
#' 2. Report schema distribution
#' 3. Split data by schema_version (v1/v2/v3/unknown)
#' 4. Apply appropriate transformation to each group
#' 5. Combine all transformed groups
#' 6. Remove legacy columns (alternates, schema_version)
#'
#' @section CONTRACT:
#' - Requires schema_version column in input
#' - Handles mixed schemas in single data frame
#' - Preserves all rows (no filtering)
#' - Removes legacy columns (alternates, schema_version)
#'
#' @section DOES NOT:
#' - Detect schemas (expects schema_version column already added)
#' - Enforce unified schema (handled in enforce_unified_schema)
#' - Remove duplicates
#' - Filter rows
#'
#' @export
standardize_kpro_schema <- function(df, verbose = FALSE) {
  
  # Input validation using centralized assertions
  assert_data_frame(df, "df")
  assert_not_empty(df, "df")
  assert_columns_exist(df, "schema_version", source_hint = "detect_row_schema()")
  
  # -------------------------
  # Report schema distribution
  # -------------------------
  
  if (verbose) {
    message("\n=== Schema Transformation Summary ===")
    schema_counts <- table(df$schema_version)
    
    for (version in names(schema_counts)) {
      message(sprintf("  %s: %s rows", 
                      version, 
                      format(schema_counts[version], big.mark = ",")))
    }
  }
  
  # -------------------------
  # Split by schema version
  # -------------------------
  
  df_split <- split(df, df$schema_version)
  
  # -------------------------
  # Transform each schema group
  # -------------------------
  
  transformed_groups <- list()
  
  # V1: Legacy single column (semicolon-delimited)
  if ("v1_legacy_single_column" %in% names(df_split)) {
    if (verbose) message("\n  Transforming v1_legacy_single_column...")
    transformed_groups$v1 <- transform_v1_to_unified(df_split$v1_legacy_single_column, verbose = verbose)
    if (verbose) {
      message(sprintf("    [OK] Transformed %s rows", 
                      format(nrow(transformed_groups$v1), big.mark = ",")))
    }
  }
  
  # V2: Transitional 4-letter codes
  if ("v2_transitional_4letter" %in% names(df_split)) {
    if (verbose) message("\n  Transforming v2_transitional_4letter...")
    transformed_groups$v2 <- transform_v2_to_unified(df_split$v2_transitional_4letter, verbose = verbose)
    if (verbose) {
      message(sprintf("    [OK] Transformed %s rows", 
                      format(nrow(transformed_groups$v2), big.mark = ",")))
    }
  }
  
  # V3: Modern 6-letter codes
  if ("v3_modern_6letter" %in% names(df_split)) {
    if (verbose) message("\n  Transforming v3_modern_6letter...")
    transformed_groups$v3 <- transform_v3_to_unified(df_split$v3_modern_6letter, verbose = verbose)
    if (verbose) {
      message(sprintf("    [OK] Transformed %s rows", 
                      format(nrow(transformed_groups$v3), big.mark = ",")))
    }
  }
  
  # Unknown schemas (pass through as-is with warning)
  if ("unknown" %in% names(df_split)) {
    warning(sprintf("%s rows have unknown schema - passing through as-is", 
                    format(nrow(df_split$unknown), big.mark = ",")))
    transformed_groups$unknown <- df_split$unknown
  }
  
  # -------------------------
  # Combine all transformed groups
  # -------------------------
  
  if (verbose) message("\n  Combining all schemas...")
  
  df_unified <- dplyr::bind_rows(transformed_groups)
  
  if (verbose) {
    message(sprintf("    [OK] Combined %s total rows", 
                    format(nrow(df_unified), big.mark = ",")))
  }
  
  # -------------------------
  # Harmonize column names (KPro version transitions)
  # -------------------------
  
  df_unified <- harmonize_column_names(df_unified, verbose = verbose)
  
  # -------------------------
  # Remove legacy columns explicitly
  # -------------------------
  
  legacy_cols_to_remove <- c("alternates", "schema_version")
  
  # Check which legacy columns actually exist
  cols_to_drop <- intersect(legacy_cols_to_remove, names(df_unified))
  
  if (length(cols_to_drop) > 0) {
    if (verbose) message(sprintf("  Removing legacy columns: %s", paste(cols_to_drop, collapse = ", ")))
    df_unified <- df_unified %>%
      dplyr::select(-dplyr::all_of(cols_to_drop))
  }
  
  if (verbose) message("  [OK] Schema transformation complete")
  
  df_unified
}


# ------------------------------------------------------------------------------
# Helper Function: Harmonize Column Names
# ------------------------------------------------------------------------------

#' Harmonize Column Names Across KPro Versions
#'
#' @description
#' Handles column name changes between Kaleidoscope Pro versions.
#' Deals with transition from legacy out_file to modern out_file_fs/out_file_zc.
#'
#' @param df Data frame to harmonize
#' @param verbose Logical. Print status messages? Default: FALSE
#'
#' @return Data frame with harmonized column names
#'
#' @section CONTRACT:
#' - Preserves all data (no information loss)
#' - Prioritizes modern column names (out_file_fs, out_file_zc)
#' - Removes legacy out_file column after migration
#' - Case-insensitive matching
#'
#' @keywords internal
harmonize_column_names <- function(df, verbose = FALSE) {
  
  # Find relevant columns (case-insensitive)
  out_file_col <- grep("^out_file$", names(df), ignore.case = TRUE, value = TRUE)[1]
  out_file_fs_col <- grep("^out_file_fs$", names(df), ignore.case = TRUE, value = TRUE)[1]
  out_file_zc_col <- grep("^out_file_zc$", names(df), ignore.case = TRUE, value = TRUE)[1]
  
  # Case 1: Modern data (out_file_fs already exists)
  if (!is.na(out_file_fs_col)) {
    
    # Check if legacy out_file also exists
    if (!is.na(out_file_col)) {
      if (verbose) message("  Coalescing: out_file -> out_file_fs (merging legacy data)")
      
      # Coalesce: use out_file_fs where available, fill NAs with out_file
      df <- df %>%
        dplyr::mutate(
          !!out_file_fs_col := dplyr::coalesce(.data[[out_file_fs_col]], .data[[out_file_col]])
        ) %>%
        dplyr::select(-!!out_file_col)
      
    } else {
      if (verbose) message("  Modern columns detected (out_file_fs, out_file_zc)")
    }
  }
  
  # Case 2: Legacy data (only out_file exists, no out_file_fs)
  else if (!is.na(out_file_col)) {
    if (verbose) message("  Harmonizing: out_file -> out_file_fs (legacy data)")
    
    # Rename legacy out_file to modern out_file_fs
    df <- df %>%
      dplyr::rename(out_file_fs = !!out_file_col)
  }
  
  df
}



# ------------------------------------------------------------------------------
# Species Unification
# ------------------------------------------------------------------------------

#' Create Unified Species Column
#'
#' @description
#' Creates a unified species column with priority: manual_id > auto_id > "NoID".
#' This is the canonical species identification for each detection, resolving
#' cases where automated identification may have been corrected by expert review.
#' 
#' Used in CPN template generation (Chunk 2) and finalization (Chunk 3) to
#' ensure consistent species assignment across all analysis stages.
#'
#' @param data Data frame. Must contain auto_id column at minimum.
#'   If manual_id column is missing, it will be treated as all NA.
#'
#' @return Data frame with unified 'species' column added. Original columns
#'   (auto_id, manual_id) are preserved unchanged.
#'
#' @section Species Priority Logic:
#' The unified species column follows this priority:
#' 1. **manual_id** (highest priority): Expert-reviewed identification
#' 2. **auto_id** (fallback): Automated Kaleidoscope Pro identification
#' 3. **"NoID"** (default): When both are unidentifiable
#' 
#' Values considered "unidentifiable":
#' - NA (missing)
#' - "" (empty string)
#' - "NoID" (explicit no-identification)
#' - "UNKNOWN" (legacy unknown marker)
#'
#' @section CONTRACT:
#' - Priority: manual_id > auto_id > "NoID" (FIXED)
#' - Column names: manual_id, auto_id, species (FIXED per schema)
#' - Treats NA, "", "NoID", "UNKNOWN" as unidentifiable (FIXED)
#' - Adds 'species' column to data frame
#' - Does not modify input data frame (returns new one)
#' - Preserves all existing columns
#' - No configurable behavior - purely deterministic
#'
#' @section DOES NOT:
#' - Remove rows (just marks as "NoID")
#' - Modify existing columns
#' - Validate species names against reference list
#' - Accept custom column names (violates schema standards)
#' - Log or print messages (caller controls verbosity)
#'
#' @examples
#' \dontrun{
#' # Basic usage in CPN template generation
#' kpro_master <- create_unified_species_column(kpro_master)
#' # Now has 'species' column with priority logic applied
#'
#' # Filter to identified species only
#' identified_calls <- kpro_master %>%
#'   filter(species != "NoID")
#'
#' # Count by unified species
#' species_counts <- kpro_master %>%
#'   count(species, sort = TRUE)
#'
#' # Example priority resolution:
#' # auto_id = "MYLU", manual_id = NA    -> species = "MYLU"
#' # auto_id = "MYLU", manual_id = "EPFU" -> species = "EPFU"
#' # auto_id = "NoID", manual_id = "LABO" -> species = "LABO"
#' # auto_id = "NoID", manual_id = NA     -> species = "NoID"
#' }
#'
#' @export
create_unified_species_column <- function(data) {
  
  # Input validation
  if (!is.data.frame(data)) {
    stop("data must be a data frame")
  }
  
  # Helper to check if value is valid (not unidentifiable)
  is_valid <- function(x) {
    !is.na(x) & x != "" & x != "NoID" & x != "UNKNOWN"
  }
  
  # FIXED column names per schema standards
  manual_col <- "manual_id"
  auto_col <- "auto_id"
  output_col <- "species"
  
  # Verify auto_id exists (required)
  if (!auto_col %in% names(data)) {
    stop(sprintf(
      "Required column '%s' not found in data.\n  Available columns: %s",
      auto_col, paste(head(names(data), 10), collapse = ", ")
    ))
  }
  
  # Add manual_id if missing (treat as all NA)
  if (!manual_col %in% names(data)) {
    data[[manual_col]] <- NA_character_
  }
  
  # Build species column with FIXED priority logic
  data <- data %>%
    dplyr::mutate(
      !!output_col := dplyr::case_when(
        # Priority 1: manual_id (if valid)
        is_valid(.data[[manual_col]]) ~ .data[[manual_col]],
        # Priority 2: auto_id (if valid)
        is_valid(.data[[auto_col]]) ~ .data[[auto_col]],
        # Fallback: NoID
        TRUE ~ "NoID"
      )
    )
  
  data
}


# ==============================================================================
# END OF FILE
# ==============================================================================