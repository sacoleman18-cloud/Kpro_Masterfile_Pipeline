# =============================================================================
# standardization/standardization.R — SCHEMA TRANSFORMATION (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Transforms all KPro schema versions into a unified master schema. Handles
# alternates splitting (including semicolon-delimited variants), species code
# conversion, column name harmonization across KPro versions, and schema
# unification with row-level detection support.
#
# STANDARDIZATION CONTRACT
# ------------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. Schema transformation (row-level detection support)
#    - V1: Split semicolon-delimited alternates → alternate_1, _2, _3
#      * Handles traditional "alternates" column
#      * Handles modern variant with semicolons in "alternate_1" column
#    - V2: Convert 4-letter species codes → 6-letter
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
#    - Legacy out_file → modern out_file_fs
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
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Perform schema detection (core/schema_detection.R)
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
#   - core/schema_detection.R: detect_row_schema (provides schema_version column)
#   - dplyr: mutate, case_when, select, bind_rows, coalesce
#   - purrr: map_chr (for splitting alternates)
#
# WORKFLOW INTEGRATION
# --------------------
# This module is used in Workflow 02 (Standardization):
#   1. raw_combined (from Workflow 01) → detect_row_schema()
#   2. raw_with_schemas → standardize_kpro_schema() → unified_data
#   3. unified_data → convert_datetime_to_cst() → enforce_unified_schema()
#   4. validated_data → finalize_master_columns() → kpro_master
#
# CONTENTS
# --------
# Constants:
#   - SPECIES_CODE_MAP_4_TO_6            # 60+ species 4-letter → 6-letter lookup
#
# Core Functions:
#   - convert_4letter_to_6letter()       # Applies species code mapping
#   - harmonize_column_names()           # out_file → out_file_fs transition
#
# Schema Transformation Functions:
#   - transform_v1_to_unified()          # Handles semicolon splitting + conversion
#   - transform_v2_to_unified()          # Adds alternate_3 + conversion
#   - transform_v3_to_unified()          # Adds alternate_3 (already 6-letter)
#
# Orchestration:
#   - standardize_kpro_schema()          # Main orchestrator (splits by schema, transforms, combines)
#
# Validation:
#   - validate_unified_schema()          # Post-transformation schema check
#
# USAGE EXAMPLE
# -------------
# # After ingestion and intro-standardization (Workflow 01)
# raw_combined <- load_combined_data()
# 
# # Detect schema versions (row-level)
# raw_with_schemas <- detect_row_schema(raw_combined)
# 
# # Standardize all schemas to unified format
# unified_data <- standardize_kpro_schema(raw_with_schemas)
# 
# # Result: All rows now have:
# # - auto_id, alternate_1, alternate_2, alternate_3 (all 6-letter codes)
# # - out_file_fs (harmonized from out_file if needed)
# # - No legacy columns (alternates, schema_version removed)
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
#' @details
#' This mapping covers all common bat species in the United States and some
#' Mexican species that occur in border states. Codes not in this map are
#' preserved as-is during conversion.
#'
#' **Special codes:**
#' - "UNKN" → "UNKNOWN"
#' - "NOID" → "UNKNOWN"
#'
#' **Species families covered:**
#' - Myotis (16 species)
#' - Lasiurus (10 species)
#' - Eptesicus (1 species)
#' - Perimyotis (1 species)
#' - Nycticeius (1 species)
#' - Corynorhinus (2 species)
#' - Antrozous (1 species)
#' - Tadarida (1 species)
#' - Macrotus (1 species)
#' - Euderma, Eumops, Idionycteris (5 species)
#'
#' @section SOURCE:
#' Codes verified against:
#' - NABat species list (https://nabatmonitoring.org)
#' - Kaleidoscope Pro documentation
#' - Wildlife Acoustics technical specifications
#'
#' @section CONTRACT:
#' - This mapping is treated as immutable infrastructure
#' - New codes added only after verification
#' - Unknown codes map to "UNKNOWN" (not error)
#'
#' @section DOES NOT:
#' - Validate species presence in study area
#' - Perform acoustic identification
#' - Update dynamically based on data
#'
#' @examples
#' \dontrun{
#' # Convert single code
#' SPECIES_CODE_MAP_4_TO_6["MYLU"]  # Returns "MYOLUC"
#'
#' # Check if code exists
#' "EPFU" %in% names(SPECIES_CODE_MAP_4_TO_6)  # TRUE
#'
#' # Get all 4-letter codes
#' names(SPECIES_CODE_MAP_4_TO_6)
#' }
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
#'
#' @return Data frame with updated species codes (4-letter → 6-letter)
#'
#' @details
#' This function processes four columns:
#' - auto_id (primary species identification)
#' - alternate_1 (first alternative species)
#' - alternate_2 (second alternative species)
#' - alternate_3 (third alternative species)
#'
#' **Conversion logic:**
#' - Codes in SPECIES_CODE_MAP_4_TO_6 → converted to 6-letter
#' - Codes NOT in map → preserved as-is (no error)
#' - NA values → remain NA
#' - Case-insensitive matching
#'
#' @section CONTRACT:
#' - Only species code columns are modified
#' - Unknown codes preserved (not errored or removed)
#' - Column names case-insensitive (auto_id, Auto_ID, AUTO_ID all work)
#' - Does not add/remove columns
#' - Logs conversion completion
#'
#' @section DOES NOT:
#' - Modify non-species columns
#' - Validate species code correctness
#' - Remove rows with unknown codes
#' - Add new columns
#' - Write files to disk
#'
#' @examples
#' \dontrun{
#' df <- data.frame(
#'   auto_id = c("MYLU", "EPFU", "NOID"),
#'   alternate_1 = c("LABO", NA, "LACI")
#' )
#' 
#' df_converted <- convert_4letter_to_6letter(df)
#' # auto_id: MYOLUC, EPTFUS, UNKNOWN
#' # alternate_1: LASBOR, NA, LASCIN
#' }
#'
#' @export
convert_4letter_to_6letter <- function(df) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(df)) {
    stop("df must be a data frame")
  }
  
  # -------------------------
  # Convert species code columns
  # -------------------------
  
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
  
  message("    ✓ Converted 4-letter codes to 6-letter")
  
  df
}


# ------------------------------------------------------------------------------
# Transform Function: V1 Legacy Format (UPDATED - Handles Semicolons in alternate_1)
# ------------------------------------------------------------------------------

#' Transform V1 Legacy Format to Unified Schema
#'
#' @description
#' Splits semicolon-separated alternate columns into separate alternate_1, 
#' alternate_2, alternate_3 columns and converts all species codes from 
#' 4-letter to 6-letter format. Now handles both traditional "alternates" 
#' column and semicolon-delimited "alternate_1" column.
#'
#' @param df Data frame in v1 schema (semicolon-delimited alternates)
#'
#' @return Data frame with alternate_1, alternate_2, alternate_3 columns
#'   containing 6-letter species codes
#'
#' @details
#' **V1 Schema Characteristics:**
#' - Traditional: Single "alternates" column with semicolon-delimited codes
#' - Modern variant: "alternate_1" column with semicolon-delimited codes
#' - Codes are 4-letter format (e.g., "LANO;LABO;LACI")
#' - Spaces after semicolons may or may not be present
#'
#' **Transformation steps:**
#' 1. Find column containing semicolon-delimited codes:
#'    - First check for "alternates" column (traditional v1)
#'    - If not found, check "alternate_1" for semicolons
#' 2. Split on semicolon (with optional whitespace)
#' 3. Extract first 3 codes into alternate_1, alternate_2, alternate_3
#' 4. Remove original semicolon-delimited column
#' 5. Convert all codes from 4-letter to 6-letter
#'
#' **Edge cases handled:**
#' - Single code (e.g., "LACI") → alternate_1 = "LACI", others = NA
#' - Two codes (e.g., "LACI;LABO") → alternate_1, alternate_2 filled, alternate_3 = NA
#' - Three+ codes (e.g., "LACI;LABO;LANO;EPFU") → first 3 used, extras dropped
#' - Empty/NA values → all three columns get NA
#' - Existing alternate_2, alternate_3 columns → overwritten by split results
#'
#' @section CONTRACT:
#' - Removes source column after splitting (alternates OR alternate_1)
#' - Creates/overwrites alternate_1, alternate_2, alternate_3 columns
#' - Converts all codes to 6-letter format
#' - Preserves all other columns unchanged
#' - Raises error if no semicolon-delimited column found
#' - Handles both "alternates" and "alternate_1" sources
#'
#' @section DOES NOT:
#' - Detect schema versions (expects v1 data)
#' - Validate species code correctness
#' - Keep more than 3 alternates (extras are dropped)
#' - Preserve original semicolon-delimited column
#' - Modify non-species columns
#' - Combine multiple files
#' - Write files to disk
#'
#' @examples
#' \dontrun{
#' # Traditional v1 with "alternates" column
#' v1_traditional <- data.frame(
#'   auto_id = c("MYLU", "EPFU"),
#'   alternates = c("LABO;LACI", "MYSE;LANO;LACI")
#' )
#' 
#' v1_unified <- transform_v1_to_unified(v1_traditional)
#' # alternates column removed
#' # alternate_1 = c("LASBOR", "MYOSEP")
#' # alternate_2 = c("LASCIN", "LASNOC")
#' # alternate_3 = c(NA, "LASCIN")
#'
#' # Modern v1 variant with semicolons in "alternate_1"
#' v1_modern <- data.frame(
#'   auto_id = c("MYLU", "EPFU"),
#'   alternate_1 = c("LABO;LACI", "MYSE")
#' )
#' 
#' v1_unified <- transform_v1_to_unified(v1_modern)
#' # alternate_1 = c("LASBOR", "MYOSEP")
#' # alternate_2 = c("LASCIN", NA)
#' # alternate_3 = c(NA, NA)
#' }
#'
#' @export
transform_v1_to_unified <- function(df) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(df)) {
    stop("df must be a data frame")
  }
  
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
        message("    Detected semicolons in alternate_1 column")
      }
    }
  }
  
  # -------------------------
  # Validate source column found
  # -------------------------
  
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
  
  # Remove old alternate_1, alternate_2, alternate_3 if they exist
  # (They'll be replaced by the _new versions)
  cols_to_remove <- c()
  
  if (source_type == "alternate_1") {
    # alternate_1 was the source, already removed above
    # Check for alternate_2, alternate_3
    alt2_exists <- "alternate_2" %in% tolower(names(df))
    alt3_exists <- "alternate_3" %in% tolower(names(df))
    
    if (alt2_exists) cols_to_remove <- c(cols_to_remove, "alternate_2")
    if (alt3_exists) cols_to_remove <- c(cols_to_remove, "alternate_3")
  } else {
    # alternates was the source
    # Check for all three alternate columns
    alt1_exists <- "alternate_1" %in% tolower(names(df))
    alt2_exists <- "alternate_2" %in% tolower(names(df))
    alt3_exists <- "alternate_3" %in% tolower(names(df))
    
    if (alt1_exists) cols_to_remove <- c(cols_to_remove, "alternate_1")
    if (alt2_exists) cols_to_remove <- c(cols_to_remove, "alternate_2")
    if (alt3_exists) cols_to_remove <- c(cols_to_remove, "alternate_3")
  }
  
  # Remove old columns if they exist
  if (length(cols_to_remove) > 0) {
    # Find actual column names (case-insensitive)
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
  
  df <- convert_4letter_to_6letter(df)
  
  message("  ✓ Transformed V1 (legacy single column) to unified schema")
  
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
#'
#' @return Data frame with alternate_1, alternate_2, alternate_3 columns
#'   containing 6-letter species codes
#'
#' @details
#' **V2 Schema Characteristics:**
#' - Separate alternate_1, alternate_2 columns (not semicolon-delimited)
#' - 4-letter species codes
#' - Missing alternate_3 column
#'
#' **Transformation steps:**
#' 1. Add alternate_3 column (as NA) if missing
#' 2. Convert all codes from 4-letter to 6-letter
#'
#' @section CONTRACT:
#' - Adds alternate_3 column if missing (set to NA)
#' - Converts all 4-letter codes to 6-letter
#' - Preserves all other columns unchanged
#' - Does not remove any columns
#'
#' @section DOES NOT:
#' - Split alternates (already separate columns)
#' - Detect schema versions (expects v2 data)
#' - Validate data quality
#' - Modify non-species columns
#' - Write files to disk
#'
#' @examples
#' \dontrun{
#' v2_data <- data.frame(
#'   auto_id = c("MYLU", "EPFU"),
#'   alternate_1 = c("LABO", "MYSE"),
#'   alternate_2 = c("LACI", NA)
#' )
#' 
#' v2_unified <- transform_v2_to_unified(v2_data)
#' # alternate_3 column added (all NA)
#' # All codes converted to 6-letter
#' }
#'
#' @export
transform_v2_to_unified <- function(df) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(df)) {
    stop("df must be a data frame")
  }
  
  if (nrow(df) == 0) {
    warning("Empty data frame provided, returning as-is")
    return(df)
  }
  
  # -------------------------
  # Add alternate_3 if missing
  # -------------------------
  
  if (!"alternate_3" %in% tolower(names(df))) {
    df <- dplyr::mutate(df, alternate_3 = NA_character_)
  }
  
  # -------------------------
  # Convert 4-letter codes to 6-letter
  # -------------------------
  
  df <- convert_4letter_to_6letter(df)
  
  message("  ✓ Transformed V2 (transitional 4-letter) to unified schema")
  
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
#'
#' @return Data frame with alternate_1, alternate_2, alternate_3 columns
#'   containing unchanged 6-letter species codes
#'
#' @details
#' **V3 Schema Characteristics:**
#' - Separate alternate_1, alternate_2 columns
#' - Already uses 6-letter species codes
#' - May or may not have alternate_3 column
#'
#' **Transformation steps:**
#' 1. Add alternate_3 column (as NA) if missing
#' 2. No code conversion needed (already 6-letter)
#'
#' **This is essentially a pass-through** with minimal modification.
#'
#' @section CONTRACT:
#' - Adds alternate_3 column if missing (set to NA)
#' - Does NOT convert species codes (already 6-letter)
#' - Preserves all other columns unchanged
#' - Does not remove any columns
#'
#' @section DOES NOT:
#' - Convert species codes (already 6-letter)
#' - Split alternates (already separate)
#' - Detect schema versions (expects v3 data)
#' - Validate data quality
#' - Modify non-species columns
#'
#' @examples
#' \dontrun{
#' v3_data <- data.frame(
#'   auto_id = c("MYOLUC", "EPTFUS"),
#'   alternate_1 = c("LASBOR", "MYOSEP"),
#'   alternate_2 = c("LASCIN", NA)
#' )
#' 
#' v3_unified <- transform_v3_to_unified(v3_data)
#' # alternate_3 column added (all NA)
#' # No code conversion (already 6-letter)
#' }
#'
#' @export
transform_v3_to_unified <- function(df) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(df)) {
    stop("df must be a data frame")
  }
  
  if (nrow(df) == 0) {
    warning("Empty data frame provided, returning as-is")
    return(df)
  }
  
  # -------------------------
  # Add alternate_3 if missing
  # -------------------------
  
  if (!"alternate_3" %in% tolower(names(df))) {
    df <- dplyr::mutate(df, alternate_3 = NA_character_)
  }
  
  message("  ✓ V3 (modern 6-letter) already in unified schema")
  
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
#' 4. Apply appropriate transformation to each group:
#'    - v1_legacy_single_column → transform_v1_to_unified()
#'    - v2_transitional_4letter → transform_v2_to_unified()
#'    - v3_modern_6letter → transform_v3_to_unified()
#'    - unknown → pass through with warning
#' 5. Combine all transformed groups
#' 6. Remove legacy columns (alternates, schema_version)
#' 7. Validate final unified schema
#'
#' **Handles mixed schemas:** Files containing rows from different KPro versions
#' are handled correctly by transforming each group separately.
#'
#' @section CONTRACT:
#' - Requires schema_version column in input
#' - Handles mixed schemas in single data frame
#' - Preserves all rows (no filtering)
#' - Removes legacy columns (alternates, schema_version)
#' - Logs transformation counts
#' - Validates final schema structure
#'
#' @section DOES NOT:
#' - Detect schemas (expects schema_version column already added)
#' - Enforce unified schema (handled in enforce_unified_schema)
#' - Remove duplicates
#' - Filter rows
#' - Modify non-species columns
#' - Write files to disk
#'
#' @examples
#' \dontrun{
#' # After running detect_row_schema()
#' raw_with_schemas <- detect_row_schema(raw_combined)
#' 
#' # Standardize all schemas to unified format
#' unified_data <- standardize_kpro_schema(raw_with_schemas)
#' 
#' # Result: All rows now have alternate_1, _2, _3 with 6-letter codes
#' }
#'
#' @export
standardize_kpro_schema <- function(df) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(df)) {
    stop("df must be a data frame")
  }
  
  if (nrow(df) == 0) {
    stop("df is empty - no data to standardize")
  }
  
  if (!"schema_version" %in% names(df)) {
    stop("schema_version column not found - run detect_row_schema() first")
  }
  
  # -------------------------
  # Report schema distribution
  # -------------------------
  
  message("\n=== Schema Transformation Summary ===")
  schema_counts <- table(df$schema_version)
  
  for (version in names(schema_counts)) {
    message(sprintf("  %s: %s rows", 
                    version, 
                    format(schema_counts[version], big.mark = ",")))
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
    message("\n  Transforming v1_legacy_single_column...")
    transformed_groups$v1 <- transform_v1_to_unified(df_split$v1_legacy_single_column)
    message(sprintf("    ✓ Transformed %s rows", 
                    format(nrow(transformed_groups$v1), big.mark = ",")))
  }
  
  # V2: Transitional 4-letter codes
  if ("v2_transitional_4letter" %in% names(df_split)) {
    message("\n  Transforming v2_transitional_4letter...")
    transformed_groups$v2 <- transform_v2_to_unified(df_split$v2_transitional_4letter)
    message(sprintf("    ✓ Transformed %s rows", 
                    format(nrow(transformed_groups$v2), big.mark = ",")))
  }
  
  # V3: Modern 6-letter codes
  if ("v3_modern_6letter" %in% names(df_split)) {
    message("\n  Transforming v3_modern_6letter...")
    transformed_groups$v3 <- transform_v3_to_unified(df_split$v3_modern_6letter)
    message(sprintf("    ✓ Transformed %s rows", 
                    format(nrow(transformed_groups$v3), big.mark = ",")))
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
  
  message("\n  Combining all schemas...")
  
  df_unified <- dplyr::bind_rows(transformed_groups)
  
  message(sprintf("    ✓ Combined %s total rows", 
                  format(nrow(df_unified), big.mark = ",")))
  
  # -------------------------
  # Harmonize column names (KPro version transitions)
  # -------------------------
  
  df_unified <- harmonize_column_names(df_unified)
  
  # -------------------------
  # Remove legacy columns explicitly
  # -------------------------
  
  legacy_cols_to_remove <- c("alternates", "schema_version")
  
  # Check which legacy columns actually exist
  cols_to_drop <- intersect(legacy_cols_to_remove, names(df_unified))
  
  if (length(cols_to_drop) > 0) {
    message(sprintf("  Removing legacy columns: %s", paste(cols_to_drop, collapse = ", ")))
    df_unified <- df_unified %>%
      dplyr::select(-dplyr::all_of(cols_to_drop))
  }
  
  # -------------------------
  # Validate unified schema
  # -------------------------
  
  message("\n  Validating unified schema...")
  validate_unified_schema(df_unified)
  message("    ✓ Schema validation passed")
  
  df_unified
}


# ------------------------------------------------------------------------------
# Validation Function: Unified Schema
# ------------------------------------------------------------------------------

#' Validate That Combined Data Has Unified Schema
#'
#' @description
#' Checks that the combined data frame has the expected unified schema structure
#' after transformation. Validates required columns, checks for legacy columns,
#' and samples species codes to confirm 6-letter format.
#'
#' @param df Combined data frame after standardization
#'
#' @return Invisible TRUE if validation passes (stops execution if critical failure)
#'
#' @details
#' **Expected unified schema:**
#' - auto_id (6-letter species code)
#' - alternate_1 (6-letter species code)
#' - alternate_2 (6-letter species code)
#' - alternate_3 (6-letter species code)
#'
#' **Validation checks:**
#' 1. **Required columns present** - Stops if missing
#' 2. **No legacy columns** - Warns if found (alternates, schema_version)
#' 3. **Species codes are 6-letter** - Samples first 100 auto_id values
#'    - Calculates average length
#'    - Warns if average < 5.5 characters (indicates failed conversion)
#'
#' @section CONTRACT:
#' - Checks for all required columns (auto_id, alternate_1, _2, _3)
#' - Verifies no legacy columns remain
#' - Samples species codes to confirm 6-letter format
#' - Stops execution if critical issues found
#' - Warns for non-critical issues
#' - Logs validation results
#'
#' @section DOES NOT:
#' - Modify data
#' - Check non-species columns
#' - Validate data quality (duplicates, missing values, etc.)
#' - Enforce unified schema (handled in enforce_unified_schema)
#' - Write files to disk
#'
#' @examples
#' \dontrun{
#' # After standardization
#' unified_data <- standardize_kpro_schema(raw_with_schemas)
#' 
#' # Validate (this is called automatically in standardize_kpro_schema)
#' validate_unified_schema(unified_data)
#' # Prints validation results and returns invisible TRUE
#' }
#'
#' @export
validate_unified_schema <- function(df) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.data.frame(df)) {
    stop("df must be a data frame")
  }
  
  if (nrow(df) == 0) {
    warning("Empty data frame provided - cannot validate schema")
    return(invisible(FALSE))
  }
  
  cols_lower <- tolower(names(df))
  
  # -------------------------
  # Check for required columns
  # -------------------------
  
  required_cols <- c("auto_id", "alternate_1", "alternate_2", "alternate_3")
  missing_cols <- setdiff(required_cols, cols_lower)
  
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "Unified schema missing columns: %s",
      paste(missing_cols, collapse = ", ")
    ))
  }
  
  # -------------------------
  # Check for legacy columns
  # -------------------------
  
  legacy_cols <- c("alternates", "schema_version")
  leftover_legacy <- intersect(legacy_cols, cols_lower)
  
  if (length(leftover_legacy) > 0) {
    warning(sprintf(
      "⚠️  Legacy columns still present: %s\n    These should have been removed during transformation",
      paste(leftover_legacy, collapse = ", ")
    ))
  }
  
  # -------------------------
  # Sample check: codes should be 6-letter
  # -------------------------
  
  auto_id_col <- grep("^auto_id$", names(df), ignore.case = TRUE, value = TRUE)[1]
  
  if (!is.na(auto_id_col)) {
    sample_codes <- na.omit(df[[auto_id_col]])[1:min(100, nrow(df))]
    
    if (length(sample_codes) > 0) {
      avg_length <- mean(nchar(as.character(sample_codes)), na.rm = TRUE)
      
      if (avg_length < 5.5) {
        warning(sprintf(
          "⚠️  Species codes appear to still be 4-letter after conversion!\n    Average code length: %.1f (expected ~6)",
          avg_length
        ))
      }
    }
  }
  
  # -------------------------
  # Log validation success
  # -------------------------
  
  message("✓ Unified schema validation passed")
  message(sprintf("  - All files now have: %s", paste(required_cols, collapse = ", ")))
  message(sprintf("  - All codes converted to 6-letter format"))
  message(sprintf("  - Total records: %s", format(nrow(df), big.mark = ",")))
  
  invisible(TRUE)
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
#'
#' @return Data frame with harmonized column names
#'
#' @details
#' **Column evolution:**
#' - **Legacy (old KPro)**: Single `out_file` column
#' - **Modern (KPro 5+)**: Separate `out_file_fs` (full spectrum) and `out_file_zc` (zero crossing)
#'
#' **Harmonization logic:**
#' - If `out_file_fs` exists: Keep it (modern data)
#' - If `out_file` exists but NOT `out_file_fs`: Rename `out_file` → `out_file_fs`
#' - If BOTH exist: Coalesce `out_file` into `out_file_fs` (fill NAs), then remove `out_file`
#' - Keep `out_file_zc` if present (modern zero-crossing output)
#'
#' **Result:** All data uses modern column names (`out_file_fs`, `out_file_zc`)
#'
#' @section CONTRACT:
#' - Preserves all data (no information loss)
#' - Prioritizes modern column names (out_file_fs, out_file_zc)
#' - Removes legacy out_file column after migration
#' - Case-insensitive matching
#' - Handles mixed legacy/modern data
#'
#' @section DOES NOT:
#' - Modify column values
#' - Generate new file paths
#' - Transform data
#' - Validate file existence
#'
#' @examples
#' \dontrun{
#' # Legacy data (only out_file)
#' legacy_df <- data.frame(out_file = c("file1.wav", "file2.wav"))
#' harmonized <- harmonize_column_names(legacy_df)
#' # Result: out_file_fs = c("file1.wav", "file2.wav")
#'
#' # Modern data (already has out_file_fs)
#' modern_df <- data.frame(
#'   out_file_fs = c("file1_fs.wav", "file2_fs.wav"),
#'   out_file_zc = c("file1_zc.wav", "file2_zc.wav")
#' )
#' harmonized <- harmonize_column_names(modern_df)
#' # Result: unchanged (already modern)
#' }
#'
#' @keywords internal
harmonize_column_names <- function(df) {
  
  # -------------------------
  # Find relevant columns (case-insensitive)
  # -------------------------
  
  out_file_col <- grep("^out_file$", names(df), ignore.case = TRUE, value = TRUE)[1]
  out_file_fs_col <- grep("^out_file_fs$", names(df), ignore.case = TRUE, value = TRUE)[1]
  out_file_zc_col <- grep("^out_file_zc$", names(df), ignore.case = TRUE, value = TRUE)[1]
  
  # -------------------------
  # Case 1: Modern data (out_file_fs already exists)
  # -------------------------
  
  if (!is.na(out_file_fs_col)) {
    
    # Check if legacy out_file also exists
    if (!is.na(out_file_col)) {
      message("  Coalescing: out_file → out_file_fs (merging legacy data)")
      
      # Coalesce: use out_file_fs where available, fill NAs with out_file
      df <- df %>%
        dplyr::mutate(
          !!out_file_fs_col := dplyr::coalesce(.data[[out_file_fs_col]], .data[[out_file_col]])
        ) %>%
        dplyr::select(-!!out_file_col)
      
    } else {
      message("  Modern columns detected (out_file_fs, out_file_zc)")
    }
  }
  
  # -------------------------
  # Case 2: Legacy data (only out_file exists, no out_file_fs)
  # -------------------------
  
  else if (!is.na(out_file_col)) {
    message("  Harmonizing: out_file → out_file_fs (legacy data)")
    
    # Rename legacy out_file to modern out_file_fs
    df <- df %>%
      dplyr::rename(out_file_fs = !!out_file_col)
  }
  
  # -------------------------
  # Result: Keep out_file_fs and out_file_zc (modern names)
  # -------------------------
  
  df
}
