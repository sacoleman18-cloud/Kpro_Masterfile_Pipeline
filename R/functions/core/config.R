# =============================================================================
# core/config.R – STUDY CONFIGURATION MANAGEMENT (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Manages study_parameters.yaml configuration file with automatic reconciliation
# of detector mappings. Ensures YAML stays synchronized with actual data while
# preserving user-entered detector names.
#
# CONFIGURATION CONTRACT
# ----------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. YAML structure validation
#    - config_version must be 1
#    - Required sections: study_parameters, processing_options, output_preferences
#    - Enforces required fields in each section
#
# 2. Detector mapping reconciliation
#    - Automatically adds new detector IDs with placeholders
#    - Preserves existing user-entered detector names
#    - Removes detector IDs no longer in data
#    - Maintains deterministic sort order (alphabetical by ID)
#
# 3. File management
#    - Creates YAML if missing with sensible defaults
#    - Overwrites (not appends) on save for clean structure
#    - Returns NULL if file doesn't exist (triggers creation)
#
# 4. Default values
#    - Uses modifyList() to merge user options with defaults
#    - Suggests study dates from actual data range
#    - Provides standard processing options
#
# 5. External data sources (NEW)
#    - Handles both YAML parsing formats (list and character vector)
#    - Provides helper functions to normalize format
#    - Validates paths are provided but not existence
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Prompt users for detector names (handled in workflow scripts)
#   - Check for placeholder vs real names (workflow validation)
#   - Check for duplicate detector names (workflow validation)
#   - Process or transform data
#   - Validate external data paths exist on disk
#   - Validate timezone against OlsonNames()
#
# DEPENDENCIES
# ------------
#   - yaml: read_yaml, write_yaml
#   - lubridate: ymd (for date parsing)
#
# CONTENTS
# --------
# Core functions:
#   - load_study_parameters()      # Read YAML, return list or NULL
#   - save_study_parameters()      # Write list to YAML
#   - build_study_config()         # Construct config list with defaults
#   - validate_study_config()      # Ensure required structure exists
#
# Reconciliation functions:
#   - reconcile_detector_mapping() # Merge current IDs with existing names
#   - ensure_study_parameters()    # One-call setup/reconciliation
#
# Helper functions:
#   - get_external_sources()       # Normalize external data sources to character vector
#
# USAGE EXAMPLE
# -------------
# # In workflow script 01:
# ensure_study_parameters(raw_combined, "inst/config/study_parameters.yaml")
#
# # Result: YAML exists, all detector IDs mapped (some with placeholders)
#
# # In workflow script 02:
# params <- load_study_parameters("inst/config/study_parameters.yaml")
# timezone <- params$study_parameters$timezone
# external_sources <- get_external_sources(params)
# # Prompt user for any placeholder names
# # Validate no duplicates
# # Apply mapping
#
# CHANGELOG
# ---------
# 2024-12-27: Added external_data_sources support with dual-format handling
# 2024-12-27: Added get_external_sources() helper to normalize YAML formats
# 2024-12-27: Updated validate_study_config() to accept both list and character vector
#
# =============================================================================


# ------------------------------------------------------------------------------
# Core Function: Build Study Configuration
# ------------------------------------------------------------------------------

#' Build Study Configuration List
#'
#' @description
#' Constructs a complete study configuration list with all required sections
#' and default values. This list can be written to YAML via save_study_parameters().
#'
#' @param study_name Character string for study name
#' @param start_date Study start date (Date or character YYYY-MM-DD)
#' @param end_date Study end date (Date or character YYYY-MM-DD)
#' @param timezone Character string for study location timezone (default: "America/Chicago")
#' @param detector_mapping Named character vector (detector_id = detector_name)
#' @param external_data_sources Character vector or list of external data source paths (default: empty list)
#' @param processing_options Optional list to override default processing options
#' @param output_preferences Optional list to override default output preferences
#'
#' @return Named list with complete configuration structure
#'
#' @details
#' **External data sources format:**
#' Can be provided as either:
#' - Character vector: c("F:/Data1", "E:/Data2")
#' - List: list("F:/Data1", "E:/Data2")
#' 
#' Both formats will be written to YAML correctly and can be read back as either format.
#'
#' @section CONTRACT:
#' - Always includes config_version = 1
#' - Merges user options with defaults using modifyList()
#' - Converts dates to character format (YYYY-MM-DD)
#' - Includes timezone for datetime conversions
#' - Includes external_data_sources (empty list if not provided)
#' - Accepts external_data_sources as character vector or list
#'
#' @section DOES NOT:
#' - Validate detector mapping completeness
#' - Write to file (use save_study_parameters for that)
#' - Check for placeholders or duplicates
#' - Validate timezone names against OlsonNames()
#' - Validate external data paths exist on disk
#'
#' @examples
#' \dontrun{
#' # Simple format (character vector)
#' config <- build_study_config(
#'   study_name = "BatStudy2025",
#'   start_date = "2025-10-01",
#'   end_date = "2025-11-30",
#'   timezone = "America/Chicago",
#'   detector_mapping = c("ABC123" = "Site_A", "DEF456" = "Site_B"),
#'   external_data_sources = c("F:/FieldData2024", "E:/Backup2024")
#' )
#' 
#' # List format (also supported)
#' config <- build_study_config(
#'   study_name = "BatStudy2025",
#'   start_date = "2025-10-01",
#'   end_date = "2025-11-30",
#'   timezone = "America/Chicago",
#'   detector_mapping = c("ABC123" = "Site_A"),
#'   external_data_sources = list("F:/FieldData2024")
#' )
#' }
#'
#' @export
build_study_config <- function(
    study_name,
    start_date,
    end_date,
    timezone = "America/Chicago",
    detector_mapping,
    external_data_sources = list(),
    processing_options = list(),
    output_preferences = list()
) {
  list(
    config_version = 1,
    study_parameters = list(
      study_name = study_name,
      timezone = timezone,
      start_date = as.character(start_date),
      end_date = as.character(end_date),
      detector_mapping = detector_mapping,
      external_data_sources = external_data_sources
    ),
    processing_options = modifyList(
      list(
        advanced_scheduling = FALSE,
        remove_outliers = TRUE,
        intended_hours = 13,
        kpro_directory = ""
      ),
      processing_options
    ),
    output_preferences = modifyList(
      list(
        master_filename = "final_master.csv",
        callspernight_filename = "CallsPerNight_final.csv",
        save_directory = "results/csv"
      ),
      output_preferences
    )
  )
}


# ------------------------------------------------------------------------------
# Core Function: Validate Study Configuration
# ------------------------------------------------------------------------------

#' Validate Study Configuration Structure
#'
#' @description
#' Ensures configuration list has all required fields and correct types.
#' Throws error if validation fails.
#'
#' @param cfg Configuration list (from build_study_config or load_study_parameters)
#'
#' @return TRUE if validation passes (otherwise throws error)
#'
#' @details
#' **External data sources validation:**
#' Accepts both formats that YAML parsing may produce:
#' - List: list("F:/Data")
#' - Character vector: c("F:/Data")
#' 
#' This is necessary because different yaml package versions or YAML structures
#' may parse the same YAML differently. For example:
#' ```yaml
#' external_data_sources:
#'   - 'F:/Data'
#' ```
#' 
#' Can be read as either a list or character vector depending on yaml package version.
#'
#' @section CONTRACT:
#' - Checks for config_version = 1
#' - Validates all required study_parameters fields exist
#' - Ensures detector_mapping is named character vector
#' - Throws descriptive errors for missing/invalid fields
#' - Validates timezone is character (but not if valid tz database name)
#' - Accepts external_data_sources as list OR character vector
#'
#' @section DOES NOT:
#' - Check detector names for placeholders
#' - Validate detector names are unique
#' - Check date validity or format
#' - Validate timezone against OlsonNames()
#' - Validate external data paths exist on disk
#' - Modify cfg in any way
#'
#' @examples
#' \dontrun{
#' config <- load_study_parameters("study_parameters.yaml")
#' validate_study_config(config)  # Throws error if invalid
#' }
#'
#' @export
validate_study_config <- function(cfg) {
  
  # -------------------------
  # Input validation
  # -------------------------
  stopifnot(is.list(cfg))
  
  # -------------------------
  # Check config_version
  # -------------------------
  if (is.null(cfg$config_version))
    stop("Missing config_version")
  
  if (cfg$config_version != 1)
    stop("Unsupported config_version: ", cfg$config_version, " (expected 1)")
  
  # -------------------------
  # Check study_parameters block
  # -------------------------
  sp <- cfg$study_parameters
  if (is.null(sp))
    stop("Missing study_parameters block")
  
  required <- c("study_name", "start_date", "end_date", "detector_mapping")
  missing <- setdiff(required, names(sp))
  if (length(missing) > 0)
    stop("Missing study_parameters fields: ",
         paste(missing, collapse = ", "))
  
  # -------------------------
  # Validate detector_mapping type
  # -------------------------
  if (!is.character(sp$detector_mapping))
    stop("detector_mapping must be a named character vector")
  
  # -------------------------
  # Validate timezone if present
  # -------------------------
  if (!is.null(sp$timezone) && !is.character(sp$timezone))
    stop("timezone must be a character string")
  
  # -------------------------
  # Validate external_data_sources if present (UPDATED - dual format support)
  # -------------------------
  if (!is.null(sp$external_data_sources)) {
    # Accept BOTH list and character vector formats
    # YAML can parse simple arrays as either depending on version/content
    # Example YAML that could parse as either:
    #   external_data_sources:
    #     - 'F:/Data'
    if (!is.list(sp$external_data_sources) && !is.character(sp$external_data_sources)) {
      stop("external_data_sources must be a list or character vector")
    }
  }
  
  TRUE
}


# ------------------------------------------------------------------------------
# Core Function: Load Study Parameters
# ------------------------------------------------------------------------------

#' Load Study Parameters from YAML
#'
#' @description
#' Reads study_parameters.yaml and returns configuration as nested list.
#'
#' @param yaml_path Path to YAML file (default: "inst/config/study_parameters.yaml")
#'
#' @return Named list of study parameters, or NULL if file doesn't exist
#'
#' @section CONTRACT:
#' - Returns NULL if file not found (does not error)
#' - Returns nested list structure as-is from YAML
#' - Does not validate structure (use validate_study_config for that)
#' - Does not modify or normalize any values
#'
#' @section DOES NOT:
#' - Create file if missing
#' - Apply default values
#' - Stop execution if file not found
#' - Validate structure
#' - Normalize external_data_sources format
#'
#' @examples
#' \dontrun{
#' params <- load_study_parameters("inst/config/study_parameters.yaml")
#' if (is.null(params)) {
#'   message("YAML not found - will create template")
#' }
#' }
#'
#' @export
load_study_parameters <- function(yaml_path = "inst/config/study_parameters.yaml") {
  
  if (!file.exists(yaml_path)) {
    return(NULL)
  }
  
  yaml::read_yaml(yaml_path)
}


# ------------------------------------------------------------------------------
# Core Function: Save Study Parameters
# ------------------------------------------------------------------------------

#' Save Study Parameters to YAML
#'
#' @description
#' Writes configuration list to YAML file. Overwrites existing file.
#'
#' @param params List of study parameters (from build_study_config)
#' @param yaml_path Path to save YAML file
#'
#' @return Invisible TRUE
#'
#' @section CONTRACT:
#' - Writes parameters exactly as provided
#' - Creates file if it doesn't exist
#' - Overwrites existing file completely
#' - Creates parent directories if needed
#'
#' @section DOES NOT:
#' - Validate parameter structure
#' - Apply defaults
#' - Merge with existing parameters
#'
#' @examples
#' \dontrun{
#' config <- build_study_config(...)
#' save_study_parameters(config, "inst/config/study_parameters.yaml")
#' }
#'
#' @export
save_study_parameters <- function(params, yaml_path = "inst/config/study_parameters.yaml") {
  
  # -------------------------
  # Input validation
  # -------------------------
  if (!is.list(params)) {
    stop("params must be a list")
  }
  
  # -------------------------
  # Create parent directory if needed
  # -------------------------
  yaml_dir <- dirname(yaml_path)
  if (!dir.exists(yaml_dir)) {
    dir.create(yaml_dir, recursive = TRUE)
  }
  
  # -------------------------
  # Write YAML
  # -------------------------
  yaml::write_yaml(params, yaml_path)
  invisible(TRUE)
}


# ------------------------------------------------------------------------------
# Reconciliation Function: Reconcile Detector Mapping
# ------------------------------------------------------------------------------

#' Reconcile Detector Mapping with Current Data
#'
#' @description
#' Deterministically rebuilds detector_mapping from current detector IDs
#' while preserving user-entered names. Adds new detectors, removes old ones.
#'
#' @param detector_ids Character vector of detector IDs from current data
#' @param existing_mapping Named character vector or list of existing mappings
#'
#' @return Named character vector with reconciled mapping
#'
#' @section CONTRACT:
#' - New detector IDs added with "ENTER_NAME_HERE" placeholder
#' - Existing user-entered names preserved for overlapping IDs
#' - Detector IDs no longer in data are removed
#' - Results sorted alphabetically by detector ID
#' - Always returns named character vector (never NULL)
#'
#' @section DOES NOT:
#' - Validate detector names
#' - Check for duplicates
#' - Prompt user for names
#'
#' @examples
#' \dontrun{
#' current_ids <- c("ABC123", "DEF456", "GHI789")
#' existing <- c("ABC123" = "Site_A", "DEF456" = "Site_B")
#'
#' reconciled <- reconcile_detector_mapping(current_ids, existing)
#' # Returns: c("ABC123" = "Site_A", "DEF456" = "Site_B", "GHI789" = "ENTER_NAME_HERE")
#' }
#'
#' @export
reconcile_detector_mapping <- function(detector_ids, existing_mapping = NULL) {
  
  # -------------------------
  # Normalize detector IDs
  # -------------------------
  detector_ids <- sort(unique(detector_ids))
  
  # -------------------------
  # Normalize existing mapping
  # -------------------------
  if (is.null(existing_mapping)) {
    existing_mapping <- character(0)
  } else if (is.list(existing_mapping)) {
    existing_mapping <- unlist(existing_mapping)
  }
  
  if (is.null(names(existing_mapping))) {
    existing_mapping <- character(0)
  }
  
  # -------------------------
  # Build clean mapping (all current IDs with placeholders)
  # -------------------------
  mapping <- setNames(
    rep("ENTER_NAME_HERE", length(detector_ids)),
    detector_ids
  )
  
  # -------------------------
  # Preserve user-entered values for overlapping IDs
  # -------------------------
  overlap <- intersect(names(existing_mapping), detector_ids)
  mapping[overlap] <- existing_mapping[overlap]
  
  mapping
}


# ------------------------------------------------------------------------------
# Helper Function: Get External Data Sources (NEW - Dual Format Support)
# ------------------------------------------------------------------------------

#' Get External Data Sources as Character Vector
#'
#' @description
#' Extracts external data source paths from config, handling both
#' list and character vector formats that YAML parsing may produce.
#' Always returns a normalized character vector.
#'
#' @param params Study parameters list from load_study_parameters()
#'
#' @return Character vector of paths (may be empty character(0))
#'
#' @details
#' **Why this function exists:**
#' 
#' YAML parsing is inconsistent across versions and formats. The same YAML:
#' ```yaml
#' external_data_sources:
#'   - 'F:/Data'
#' ```
#' 
#' Can be parsed as either:
#' - A list: list("F:/Data")
#' - A character vector: c("F:/Data")
#' 
#' This function normalizes both formats to a character vector, so workflow
#' scripts don't have to worry about the format.
#'
#' @section CONTRACT:
#' - Returns character vector of paths
#' - Returns empty character(0) if no sources defined
#' - Handles both list and character vector inputs
#' - Preserves path order
#' - Always returns character vector (never list)
#'
#' @section DOES NOT:
#' - Validate paths exist on disk
#' - Modify params input
#' - Load any data
#' - Stop execution if no sources found
#' - Filter or transform paths
#'
#' @examples
#' \dontrun{
#' params <- load_study_parameters("inst/config/study_parameters.yaml")
#' sources <- get_external_sources(params)
#' 
#' # Use in workflow
#' for (source_path in sources) {
#'   message(sprintf("Loading from: %s", source_path))
#'   data <- load_external_raw_data(source_path)
#' }
#' }
#'
#' @export
get_external_sources <- function(params) {
  
  # -------------------------
  # Input validation
  # -------------------------
  if (!is.list(params)) {
    stop("params must be a list from load_study_parameters()")
  }
  
  # -------------------------
  # Extract external sources
  # -------------------------
  sources <- params$study_parameters$external_data_sources
  
  # Return empty character vector if no sources defined
  if (is.null(sources) || length(sources) == 0) {
    return(character(0))
  }
  
  # -------------------------
  # Normalize to character vector
  # -------------------------
  # Handle both list and character vector formats from YAML parsing
  if (is.list(sources)) {
    # Convert list to character vector
    sources <- unlist(sources, use.names = FALSE)
  }
  
  # Ensure character type and return
  as.character(sources)
}


# ------------------------------------------------------------------------------
# One-Call Function: Ensure Study Parameters
# ------------------------------------------------------------------------------

#' Ensure Study Parameters YAML Exists and is Synchronized
#'
#' @description
#' One-call function to create YAML if missing and reconcile detector_mapping
#' with current data. This is the main entry point for workflow scripts.
#'
#' @param raw_data Data frame containing detector_id column
#' @param yaml_path Path to YAML file (default: "inst/config/study_parameters.yaml")
#'
#' @return Invisible TRUE (function called for side effects)
#'
#' @section CONTRACT:
#' - Creates YAML with template if file doesn't exist
#' - Reconciles detector_mapping on every call
#' - Preserves user-entered detector names
#' - Validates final structure
#' - Overwrites YAML with clean version
#' - Logs actions to console
#' - Includes timezone and external_data_sources sections
#'
#' @section DOES NOT:
#' - Prompt user for detector names
#' - Validate detector names are not placeholders
#' - Check for duplicate detector names
#' - Transform data
#' - Validate external data paths exist
#'
#' @details
#' This function performs the following steps:
#' 1. Extract unique detector_id values from raw_data
#' 2. If YAML doesn't exist, create template with:
#'    - Suggested study dates from data
#'    - Default timezone (America/Chicago)
#'    - All detector IDs with "ENTER_NAME_HERE" placeholders
#'    - Empty external_data_sources list
#'    - Default processing options
#' 3. Load existing YAML
#' 4. Reconcile detector_mapping:
#'    - Add new detector IDs (with placeholders)
#'    - Preserve existing user-entered names
#'    - Remove detector IDs no longer in data
#' 5. Ensure timezone exists (add default if missing)
#' 6. Ensure external_data_sources exists (add empty list if missing)
#' 7. Validate final structure
#' 8. Save clean YAML
#'
#' @examples
#' \dontrun{
#' # In workflow script 01:
#' ensure_study_parameters(raw_combined, "inst/config/study_parameters.yaml")
#'
#' # YAML now exists with all current detector IDs mapped
#' # User names preserved, new detectors have placeholders
#' # Timezone and external_data_sources sections present
#' }
#'
#' @export
ensure_study_parameters <- function(raw_data,
                                    yaml_path = "inst/config/study_parameters.yaml") {
  
  # -------------------------
  # Extract detector IDs from data
  # -------------------------
  detector_ids <- raw_data$detector_id[!is.na(raw_data$detector_id)]
  detector_ids <- sort(unique(detector_ids))
  
  if (length(detector_ids) == 0) {
    stop("No detector_id values found in raw data")
  }
  
  # -------------------------
  # Create YAML if missing
  # -------------------------
  if (!file.exists(yaml_path)) {
    message("⚠️  study_parameters.yaml not found")
    
    # Suggest study dates from data
    dates <- if ("date" %in% names(raw_data)) {
      lubridate::ymd(raw_data$date)
    } else {
      Sys.Date()
    }
    
    # Build template configuration
    cfg <- build_study_config(
      study_name       = "YourStudyName",
      start_date       = min(dates, na.rm = TRUE),
      end_date         = max(dates, na.rm = TRUE),
      timezone         = "America/Chicago",
      detector_mapping = setNames(
        rep("ENTER_NAME_HERE", length(detector_ids)),
        detector_ids
      ),
      external_data_sources = list()  # Empty list - user can add sources later
    )
    
    yaml::write_yaml(cfg, yaml_path)
    message("✓ Created study_parameters.yaml template")
  }
  
  # -------------------------
  # Load existing config
  # -------------------------
  cfg <- load_study_parameters(yaml_path)
  
  # -------------------------
  # Ensure config_version exists
  # -------------------------
  if (is.null(cfg$config_version)) {
    cfg$config_version <- 1
  }
  
  # -------------------------
  # Ensure timezone exists (add default if missing)
  # -------------------------
  if (is.null(cfg$study_parameters$timezone)) {
    cfg$study_parameters$timezone <- "America/Chicago"
    message("ℹ️  Added default timezone: America/Chicago")
  }
  
  # -------------------------
  # Ensure external_data_sources exists (add empty list if missing)
  # -------------------------
  if (is.null(cfg$study_parameters$external_data_sources)) {
    cfg$study_parameters$external_data_sources <- list()
    message("ℹ️  Added empty external_data_sources section")
  }
  
  # -------------------------
  # Reconcile detector mapping (KEY STEP)
  # -------------------------
  # This adds new detectors, removes old ones, preserves user names
  cfg$study_parameters$detector_mapping <-
    reconcile_detector_mapping(
      detector_ids,
      cfg$study_parameters$detector_mapping
    )
  
  # -------------------------
  # Validate final structure
  # -------------------------
  validate_study_config(cfg)
  
  # -------------------------
  # Force YAML mapping format (not list)
  # -------------------------
  cfg$study_parameters$detector_mapping <-
    as.list(cfg$study_parameters$detector_mapping)
  
  # -------------------------
  # Save clean YAML (overwrite)
  # -------------------------
  yaml::write_yaml(cfg, yaml_path)
  
  message(sprintf(
    "✓ study_parameters.yaml reconciled (%d detectors)",
    length(detector_ids)
  ))
  
  invisible(TRUE)
}

# ==============================================================================
# END OF FILE
# ==============================================================================