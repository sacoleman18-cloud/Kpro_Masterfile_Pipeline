# =============================================================================
# UTILITY: config.R - Study Configuration Management (LOCKED CONTRACT)
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# PURPOSE
# -------
# Manages study_parameters.yaml configuration file with automatic reconciliation
# of detector mappings and extraction of schedule parameters. YAML is generated 
# deterministically by Shiny app, so no format normalization is needed - just 
# read/write operations and parameter extraction.
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
# 5. Schedule parameter extraction
#    - Normalizes boolean values (TRUE/FALSE/"yes"/"no" -> logical)
#    - Provides FIXED defaults for bat study standards
#    - Handles both old (advanced_scheduling) and new (detector_specific_schedules) parameters
#    - Returns complete parameter list for orchestrators
#
# 6. Shiny integration
#    - Assumes YAML written by Shiny app (deterministic format)
#    - No normalization of boolean/string/list formats needed (except schedule params)
#    - Direct field access without type coercion
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Normalize YAML formats (Shiny writes deterministically)
#   - Prompt users for detector names (handled in workflow scripts)
#   - Check for placeholder vs real names (workflow validation)
#   - Check for duplicate detector names (workflow validation)
#   - Process or transform data
#   - Validate external data paths exist on disk
#   - Validate timezone against OlsonNames()
#   - Validate time formats (HH:MM:SS) - handled by orchestrators
#
# DEPENDENCIES
# ------------
#   - yaml: read_yaml, write_yaml
#   - lubridate: ymd (for date parsing)
#
# FUNCTIONS PROVIDED
# ------------------
#
# Core Configuration - YAML read/write operations:
#
#   - load_study_parameters():
#       Uses packages: yaml (read_yaml), base R (file.exists)
#       Calls internal: none (pure YAML I/O)
#       Purpose: Read study_parameters.yaml, return list or NULL if missing
#
#   - save_study_parameters():
#       Uses packages: yaml (write_yaml), base R (dir.exists, dir.create)
#       Calls internal: none (pure YAML I/O)
#       Purpose: Write configuration list to study_parameters.yaml (overwrites)
#
# Configuration Management - Build default configs:
#
#   - build_study_config():
#       Uses packages: base R (list operations, do.call)
#       Calls internal: config.R (reconcile_detector_mapping)
#       Purpose: Construct YAML config list with defaults and detector mapping
#
#   - validate_study_config():
#       Uses packages: base R (all operations, stop)
#       Calls internal: none (validation only)
#       Purpose: Ensure required structure and fields exist in config
#
# Schedule Extraction - Normalize schedule parameters:
#
#   - get_schedule_config():
#       Uses packages: base R (list operations, as.logical)
#       Calls internal: none (parameter extraction + normalization)
#       Purpose: Extract and normalize schedule parameters from loaded YAML
#
# Detector Mapping - Reconcile detector IDs:
#
#   - reconcile_detector_mapping():
#       Uses packages: base R (list operations, alphabetical sort)
#       Calls internal: none
#       Purpose: Merge new detector IDs with existing user-entered names
#
#   - ensure_study_parameters():
#       Uses packages: yaml (read_yaml, write_yaml), base R (file operations)
#       Calls internal: config.R (load_study_parameters, build_study_config,
#                                 save_study_parameters, validate_study_config)
#       Purpose: One-call setup and reconciliation of YAML file
#
# USAGE EXAMPLE
# -------------
# # Shiny app creates/updates YAML:
# cfg <- build_study_config(
#   study_name = input$study_name,
#   start_date = as.character(input$start_date),
#   detector_mapping = detected_ids,
#   processing_options = list(
#     detector_specific_schedules = input$detector_specific_schedules,  # TRUE/FALSE
#     generate_editable_template = input$generate_editable_template,    # TRUE/FALSE
#     recording_start = input$recording_start                           # "HH:MM:SS"
#   )
# )
# save_study_parameters(cfg)
#
# # Orchestrating functions extract schedule config:
# params <- load_study_parameters()
# schedule <- get_schedule_config(params)
# 
# # Access normalized schedule parameters
# needs_detector_csv <- schedule$detector_specific_schedules  # Logical
# needs_template <- schedule$generate_editable_template       # Logical
# rec_start <- schedule$recording_start                       # "HH:MM:SS"
#
# CHANGELOG
# ---------
# 2026-02-05: DOCUMENTATION FIX - Renamed "CONTENTS" to "FUNCTIONS PROVIDED"
#             - Updated to match documentation standards template
# 2026-02-01: Added get_schedule_config() - moved from utilities.R
#             - Properly belongs in config module (parses YAML, has domain knowledge)
#             - Updated to support detector_specific_schedules (renamed from advanced_scheduling)
#             - Added generate_editable_template parameter for workflow control
#             - Maintains backward compatibility with advanced_scheduling (deprecated)
#             - Normalizes boolean values from YAML to logical
# 2026-01-31: Simplified for Shiny integration
#             - Removed get_advanced_scheduling() (not needed)
#             - Removed get_external_sources() (not needed)
#             - Removed internal normalization helpers
#             - Assumes deterministic YAML format from Shiny
#             - Direct field access without type coercion
# 2024-12-27: Added external_data_sources support
# 2024-12-27: Added YAML format normalization helpers
#
# =============================================================================



# ==============================================================================
# CORE FUNCTIONS
# ==============================================================================


# ------------------------------------------------------------------------------
# Core Function: Load Study Parameters
# ------------------------------------------------------------------------------

#' Load Study Parameters from YAML
#'
#' @description
#' Reads study_parameters.yaml and returns configuration as nested list.
#' Assumes YAML was written by Shiny app with deterministic format.
#'
#' @param yaml_path Character. Path to YAML file.
#'   Default: "inst/config/study_parameters.yaml"
#'
#' @return Named list of study parameters, or NULL if file doesn't exist
#'
#' @details
#' **Shiny integration:**
#' This function assumes the YAML was written by the Shiny app using
#' `save_study_parameters()` or `build_study_config()`, which means:
#' - All boolean values are TRUE/FALSE (not "yes"/"no" strings)
#' - All paths are character vectors (not lists)
#' - All structure is deterministic and validated
#'
#' **Field access:**
#' ```r
#' params <- load_study_parameters()
#' 
#' # Direct access - no normalization needed
#' is_advanced <- params$processing_options$advanced_scheduling  # TRUE/FALSE
#' rec_start <- params$processing_options$recording_start        # "HH:MM:SS"
#' sources <- params$study_parameters$external_data_sources      # character()
#' ```
#'
#' @section CONTRACT:
#' - Returns NULL if file not found (does not error)
#' - Returns nested list structure as-is from YAML
#' - Does not validate structure (use validate_study_config for that)
#' - Does not modify or normalize any values
#' - Assumes deterministic YAML format
#'
#' @section DOES NOT:
#' - Create file if missing
#' - Apply default values
#' - Stop execution if file not found
#' - Validate structure
#' - Normalize boolean/string/list formats (not needed)
#'
#' @examples
#' \dontrun{
#' params <- load_study_parameters("inst/config/study_parameters.yaml")
#' if (is.null(params)) {
#'   message("YAML not found - will create template")
#' }
#' 
#' # Direct field access
#' study_name <- params$study_parameters$study_name
#' is_advanced <- params$processing_options$advanced_scheduling
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
#' Used by Shiny app to persist user configuration.
#'
#' @param cfg Named list. Configuration structure (from build_study_config())
#' @param yaml_path Character. Path to YAML file.
#'   Default: "inst/config/study_parameters.yaml"
#'
#' @return Invisible TRUE
#'
#' @details
#' **Shiny integration:**
#' This function is called by the Shiny app when users save configuration.
#' All values are written deterministically:
#' - Booleans as TRUE/FALSE (not "yes"/"no")
#' - Numbers as numeric (not strings)
#' - Paths as character vectors
#'
#' **Example Shiny usage:**
#' ```r
#' observeEvent(input$save_config, {
#'   cfg <- build_study_config(
#'     study_name = input$study_name,
#'     start_date = as.character(input$start_date),
#'     detector_mapping = detector_ids,
#'     processing_options = list(
#'       advanced_scheduling = input$use_advanced_scheduling,  # TRUE/FALSE
#'       recording_start = input$recording_start_time         # "HH:MM:SS"
#'     )
#'   )
#'   
#'   save_study_parameters(cfg)
#'   showNotification("Configuration saved!")
#' })
#' ```
#'
#' @section CONTRACT:
#' - Overwrites existing file (does not append)
#' - Creates parent directory if missing
#' - Validates cfg is a list before writing
#' - Uses yaml::write_yaml() with default options
#' - Writes deterministic format for orchestrating functions
#'
#' @section DOES NOT:
#' - Validate cfg structure (use validate_study_config first)
#' - Prompt for confirmation before overwriting
#' - Create backup of existing file
#' - Log the save operation
#'
#' @examples
#' \dontrun{
#' cfg <- build_study_config(
#'   study_name = "My Study",
#'   start_date = "2025-01-01",
#'   end_date = "2025-12-31",
#'   detector_mapping = c("ABC123" = "Detector 1")
#' )
#'
#' save_study_parameters(cfg, "inst/config/study_parameters.yaml")
#' }
#'
#' @export
save_study_parameters <- function(cfg,
                                  yaml_path = "inst/config/study_parameters.yaml") {
  
  # Input validation
  if (!is.list(cfg)) {
    stop(sprintf(
      "cfg must be a list.\n  Received: %s\n  Use build_study_config() to create valid configuration.",
      paste(class(cfg), collapse = ", ")
    ))
  }
  
  # Ensure directory exists
  yaml_dir <- dirname(yaml_path)
  if (!dir.exists(yaml_dir)) {
    dir.create(yaml_dir, recursive = TRUE)
  }
  
  # Write YAML
  yaml::write_yaml(cfg, yaml_path)
  
  invisible(TRUE)
}


# ------------------------------------------------------------------------------
# Core Function: Build Study Configuration
# ------------------------------------------------------------------------------

#' Build Study Configuration List
#'
#' @description
#' Constructs a complete study_parameters.yaml structure with required sections
#' and sensible defaults. Called by Shiny app to create configuration from UI inputs.
#'
#' @param study_name Character. Study name
#' @param start_date Study start date (Date or character YYYY-MM-DD)
#' @param end_date Study end date (Date or character YYYY-MM-DD)
#' @param timezone Character. Study location timezone. Default: "America/Chicago"
#' @param detector_mapping Named character vector (detector_id = detector_name)
#' @param external_data_sources Character vector of external data source paths.
#'   Default: character(0)
#' @param processing_options Optional list to override default processing options
#' @param output_preferences Optional list to override default output preferences
#'
#' @return Named list with complete configuration structure
#'
#' @details
#' **Default processing options:**
#' - advanced_scheduling: FALSE (boolean)
#' - recording_start: "18:00:00" (character)
#' - recording_end: "07:00:00" (character)
#' - intended_hours: 13 (numeric)
#'
#' **Default output preferences:**
#' - master_filename: "final_master.csv"
#' - callspernight_filename: "CallsPerNight_final.csv"
#' - save_directory: "results/csv"
#'
#' **Shiny integration example:**
#' ```r
#' observeEvent(input$save_config, {
#'   cfg <- build_study_config(
#'     study_name = input$study_name,
#'     start_date = as.character(input$start_date),
#'     end_date = as.character(input$end_date),
#'     detector_mapping = detector_ids,
#'     processing_options = list(
#'       advanced_scheduling = input$use_custom_schedule,  # TRUE/FALSE
#'       recording_start = input$rec_start,                # "HH:MM:SS"
#'       recording_end = input$rec_end                     # "HH:MM:SS"
#'     )
#'   )
#'   save_study_parameters(cfg)
#' })
#' ```
#'
#' @section CONTRACT:
#' - Returns complete YAML-ready structure
#' - All required fields populated
#' - Uses modifyList() to merge custom options with defaults
#' - Converts Date objects to character strings
#' - Validates detector_mapping is named vector
#' - All booleans are TRUE/FALSE (not strings)
#' - All paths are character vectors (not lists)
#'
#' @section DOES NOT:
#' - Write to disk (use save_study_parameters)
#' - Validate dates are reasonable
#' - Check detector names for placeholders
#' - Validate external data paths exist
#'
#' @examples
#' \dontrun{
#' cfg <- build_study_config(
#'   study_name = "Summer Bat Survey 2025",
#'   start_date = "2025-06-01",
#'   end_date = "2025-08-31",
#'   detector_mapping = c(
#'     "ABC123" = "North Ridge",
#'     "ABC124" = "South Creek"
#'   ),
#'   external_data_sources = c("F:/Backup/AdditionalData")
#' )
#'
#' save_study_parameters(cfg)
#' }
#'
#' @export
build_study_config <- function(study_name,
                               start_date,
                               end_date,
                               timezone = "America/Chicago",
                               detector_mapping,
                               external_data_sources = character(0),
                               processing_options = list(),
                               output_preferences = list()) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.character(detector_mapping) || is.null(names(detector_mapping))) {
    stop(sprintf(
      "detector_mapping must be a named character vector.\n  Example: c('ABC123' = 'North Ridge')\n  Received: %s",
      paste(class(detector_mapping), collapse = ", ")
    ))
  }
  
  # -------------------------
  # Convert dates to character if needed
  # -------------------------
  
  if (inherits(start_date, "Date")) {
    start_date <- as.character(start_date)
  }
  
  if (inherits(end_date, "Date")) {
    end_date <- as.character(end_date)
  }
  
  # -------------------------
  # Default processing options (Shiny-friendly types)
  # -------------------------
  
  default_processing <- list(
    advanced_scheduling = FALSE,        # Boolean (not string)
    recording_start = "18:00:00",       # Character
    recording_end = "07:00:00",         # Character
    intended_hours = 13                 # Numeric
  )
  
  processing_options <- modifyList(default_processing, processing_options)
  
  # -------------------------
  # Default output preferences
  # -------------------------
  
  default_output <- list(
    master_filename = "final_master.csv",
    callspernight_filename = "CallsPerNight_final.csv",
    save_directory = "results/csv"
  )
  
  output_preferences <- modifyList(default_output, output_preferences)
  
  # -------------------------
  # Build configuration structure
  # -------------------------
  
  list(
    config_version = 1,
    
    study_parameters = list(
      study_name = study_name,
      start_date = start_date,
      end_date = end_date,
      timezone = timezone,
      detector_mapping = as.list(detector_mapping),
      external_data_sources = as.list(external_data_sources)
    ),
    
    processing_options = processing_options,
    output_preferences = output_preferences
  )
}


# ------------------------------------------------------------------------------
# Core Function: Validate Study Configuration
# ------------------------------------------------------------------------------

#' Validate Study Configuration Structure
#'
#' @description
#' Validates that a configuration list contains all required fields and correct types.
#' Used before saving to YAML to catch structural errors early.
#'
#' @param cfg Named list. Configuration structure to validate
#'
#' @return Logical TRUE if valid (stops with error if invalid)
#'
#' @details
#' **Validation checks:**
#' - config_version = 1
#' - study_parameters block exists
#' - Required fields: study_name, start_date, end_date, detector_mapping
#' - detector_mapping is named character vector
#' - timezone is character (if present)
#'
#' **Does NOT validate:**
#' - Date validity or format
#' - Timezone against OlsonNames()
#' - Detector names for placeholders
#' - External data paths exist on disk
#' - Field types (assumes Shiny provides correct types)
#'
#' @section CONTRACT:
#' - Checks for config_version = 1
#' - Validates all required study_parameters fields exist
#' - Ensures detector_mapping is named character vector
#' - Throws descriptive errors for missing/invalid fields
#' - Validates timezone is character (if present)
#'
#' @section DOES NOT:
#' - Check detector names for placeholders
#' - Validate detector names are unique
#' - Check date validity or format
#' - Validate timezone against OlsonNames()
#' - Validate external data paths exist on disk
#' - Modify cfg in any way
#' - Validate field types (trusts Shiny)
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
  
  if (!is.list(cfg)) {
    stop(sprintf(
      "cfg must be a list.\n  Received: %s",
      paste(class(cfg), collapse = ", ")
    ))
  }
  
  # -------------------------
  # Check config_version
  # -------------------------
  
  if (is.null(cfg$config_version)) {
    stop("Missing config_version in configuration")
  }
  
  if (cfg$config_version != 1) {
    stop(sprintf(
      "Unsupported config_version: %s (expected 1)",
      cfg$config_version
    ))
  }
  
  # -------------------------
  # Check study_parameters block
  # -------------------------
  
  sp <- cfg$study_parameters
  
  if (is.null(sp)) {
    stop("Missing study_parameters block in configuration")
  }
  
  # Check required fields
  required <- c("study_name", "start_date", "end_date", "detector_mapping")
  missing <- setdiff(required, names(sp))
  
  if (length(missing) > 0) {
    stop(sprintf(
      "Missing required study_parameters fields: %s",
      paste(missing, collapse = ", ")
    ))
  }
  
  # -------------------------
  # Validate detector_mapping type
  # -------------------------
  
  if (!is.character(sp$detector_mapping)) {
    stop("detector_mapping must be a named character vector")
  }
  
  # -------------------------
  # Validate timezone if present
  # -------------------------
  
  if (!is.null(sp$timezone) && !is.character(sp$timezone)) {
    stop("timezone must be a character string")
  }
  
  TRUE
}

# ------------------------------------------------------------------------------
# Core Function: Get Schedule Configuration
# ------------------------------------------------------------------------------

#' Get Schedule Configuration
#'
#' @description
#' Extracts and normalizes schedule configuration from study_parameters.
#' Consolidates the parameter extraction pattern used in multiple orchestrators.
#' Handles both boolean and string values for scheduling parameters.
#' Reduces ~15 lines of boilerplate per usage.
#' 
#' This is a DETERMINISTIC helper - defaults are FIXED by bat study standards.
#' No parameters to override defaults (violates deterministic principle).
#'
#' @param study_params List. Study parameters from load_study_parameters()
#'
#' @return Named list with:
#'   \describe{
#'     \item{recording_start}{Character. Start time (e.g., "18:00:00")}
#'     \item{recording_end}{Character. End time (e.g., "07:00:00")}
#'     \item{detector_specific_schedules}{Logical. TRUE for detector-specific, FALSE for uniform}
#'     \item{generate_editable_template}{Logical. TRUE to generate EDIT_THIS template}
#'     \item{intended_hours}{Numeric. Expected recording duration}
#'     \item{advanced_scheduling}{Logical. DEPRECATED - use detector_specific_schedules}
#'   }
#'
#' @section CONTRACT:
#' - Normalizes boolean parameters (handles TRUE/FALSE/"yes"/"no")
#' - Uses FIXED defaults for bat studies (18:00:00 / 07:00:00 / 13 hours / FALSE / TRUE)
#' - Maintains backward compatibility with advanced_scheduling parameter (deprecated)
#' - Always returns complete list
#' - No configurable behavior - purely deterministic
#'
#' @section DOES NOT:
#' - Validate time format (orchestrators should validate)
#' - Modify study_params
#' - Check if times are reasonable
#' - Accept custom defaults (violates determinism)
#' - Load YAML file (expects pre-loaded params)
#'
#' @examples
#' \dontrun{
#' study_params <- load_study_parameters()
#' schedule <- get_schedule_config(study_params)
#' 
#' recording_start <- schedule$recording_start
#' needs_detector_schedules <- schedule$detector_specific_schedules
#' needs_manual_edits <- schedule$generate_editable_template
#' }
#'
#' @export
get_schedule_config <- function(study_params) {
  
  # Extract processing options
  opts <- study_params$processing_options
  
  # FIXED defaults per bat study standards - NOT customizable
  default_recording_start <- "18:00:00"
  default_recording_end <- "07:00:00"
  default_detector_specific_schedules <- FALSE
  default_generate_editable_template <- TRUE
  default_intended_hours <- 13
  
  # Get values with FIXED defaults
  recording_start <- opts$recording_start %||% default_recording_start
  recording_end <- opts$recording_end %||% default_recording_end
  intended_hours <- opts$intended_hours %||% default_intended_hours
  
  # Handle new parameter name with backward compatibility
  # Priority: detector_specific_schedules > advanced_scheduling > default
  detector_specific_raw <- opts$detector_specific_schedules %||% 
    opts$advanced_scheduling %||% 
    default_detector_specific_schedules
  
  # Normalize detector_specific_schedules to logical
  detector_specific_schedules <- if (is.logical(detector_specific_raw)) {
    detector_specific_raw
  } else if (is.character(detector_specific_raw)) {
    tolower(detector_specific_raw) %in% c("yes", "true", "1")
  } else {
    FALSE
  }
  
  # Get generate_editable_template parameter
  generate_template_raw <- opts$generate_editable_template %||% 
    default_generate_editable_template
  
  # Normalize generate_editable_template to logical
  generate_editable_template <- if (is.logical(generate_template_raw)) {
    generate_template_raw
  } else if (is.character(generate_template_raw)) {
    tolower(generate_template_raw) %in% c("yes", "true", "1")
  } else {
    TRUE
  }
  
  list(
    recording_start = recording_start,
    recording_end = recording_end,
    detector_specific_schedules = detector_specific_schedules,
    generate_editable_template = generate_editable_template,
    intended_hours = intended_hours,
    # Deprecated - maintain for backward compatibility
    advanced_scheduling = detector_specific_schedules
  )
}



# ==============================================================================
# RECONCILIATION FUNCTIONS
# ==============================================================================


# ------------------------------------------------------------------------------
# Reconciliation Function: Detector Mapping
# ------------------------------------------------------------------------------

#' Reconcile Detector Mapping
#'
#' @description
#' Merges current detector IDs from data with existing user-entered names from
#' YAML. Adds new IDs with placeholders, preserves existing names, removes
#' obsolete IDs.
#'
#' @param current_ids Character vector. Detector IDs from current data
#' @param existing_mapping Named character vector. Current detector mapping from YAML
#'
#' @return Named character vector with reconciled mapping
#'
#' @details
#' **Reconciliation logic:**
#' 1. New detector IDs -> Add with placeholder "ENTER_NAME_HERE"
#' 2. Existing detector IDs -> Keep user-entered name
#' 3. Removed detector IDs -> Remove from mapping
#' 4. Sort alphabetically by detector ID (deterministic)
#'
#' **Example:**
#' ```
#' Current: c("ABC123", "ABC124", "ABC125")
#' Existing: c(ABC123 = "North", ABC124 = "South")
#' Result: c(ABC123 = "North", ABC124 = "South", ABC125 = "ENTER_NAME_HERE")
#' ```
#'
#' @section CONTRACT:
#' - Preserves all user-entered names for IDs still in data
#' - Adds placeholders for new IDs
#' - Removes mappings for IDs no longer in data
#' - Returns alphabetically sorted mapping
#' - Deterministic output (same inputs -> same output)
#'
#' @section DOES NOT:
#' - Validate detector names are not placeholders
#' - Check for duplicate detector names
#' - Modify input parameters
#' - Log changes to console
#' - Write to YAML file
#'
#' @examples
#' \dontrun{
#' current <- c("ABC123", "ABC124", "ABC125")
#' existing <- c(ABC123 = "North Ridge", ABC124 = "South Creek")
#'
#' reconciled <- reconcile_detector_mapping(current, existing)
#' # Returns: c(ABC123 = "North Ridge",
#' #            ABC124 = "South Creek",
#' #            ABC125 = "ENTER_NAME_HERE")
#' }
#'
#' @export
reconcile_detector_mapping <- function(current_ids, existing_mapping) {
  
  # -------------------------
  # Input validation
  # -------------------------
  
  if (!is.character(current_ids)) {
    stop(sprintf(
      "current_ids must be a character vector.\n  Received: %s",
      paste(class(current_ids), collapse = ", ")
    ))
  }
  
  # existing_mapping can be NULL for initial setup
  if (is.null(existing_mapping)) {
    existing_mapping <- character(0)
  }
  
  if (!is.character(existing_mapping)) {
    stop(sprintf(
      "existing_mapping must be a named character vector or NULL.\n  Received: %s",
      paste(class(existing_mapping), collapse = ", ")
    ))
  }
  
  # -------------------------
  # Reconcile mapping
  # -------------------------
  
  # Create empty mapping for new IDs
  new_mapping <- setNames(
    rep("ENTER_NAME_HERE", length(current_ids)),
    current_ids
  )
  
  # Preserve existing names where IDs still exist
  common_ids <- intersect(current_ids, names(existing_mapping))
  new_mapping[common_ids] <- existing_mapping[common_ids]
  
  # Sort alphabetically by ID
  new_mapping[sort(names(new_mapping))]
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
#' @param yaml_path Character. Path to YAML file.
#'   Default: "inst/config/study_parameters.yaml"
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
#'    - Empty external_data_sources
#'    - Default processing options
#' 3. Load existing YAML
#' 4. Reconcile detector_mapping:
#'    - Add new detector IDs (with placeholders)
#'    - Preserve existing user-entered names
#'    - Remove detector IDs no longer in data
#' 5. Ensure timezone exists (add default if missing)
#' 6. Ensure external_data_sources exists (add empty if missing)
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
    stop("No detector_id values found in raw_data.\n  Check that raw_data contains detector_id column with values.")
  }
  
  # -------------------------
  # Create YAML template if missing
  # -------------------------
  
  if (!file.exists(yaml_path)) {
    message("[*] study_parameters.yaml not found - creating template")
    
    # Suggest dates from data (if DATE column exists)
    dates <- if ("DATE" %in% names(raw_data)) {
      lubridate::ymd(raw_data$DATE, quiet = TRUE)
    } else {
      NULL
    }
    
    cfg <- list(
      config_version = 1,
      study_parameters = list(
        study_name = "YourStudyName",
        start_date = as.character(min(dates, na.rm = TRUE)),
        end_date = as.character(max(dates, na.rm = TRUE)),
        timezone = "America/Chicago",
        detector_mapping = setNames(
          rep("ENTER_NAME_HERE", length(detector_ids)),
          detector_ids
        ),
        external_data_sources = character(0)
      ),
      processing_options = list(
        advanced_scheduling = FALSE,
        recording_start = "18:00:00",
        recording_end = "07:00:00",
        intended_hours = 13
      ),
      output_preferences = list(
        master_filename = "final_master.csv",
        callspernight_filename = "CallsPerNight_final.csv",
        save_directory = "results/csv"
      )
    )
    
    yaml::write_yaml(cfg, yaml_path)
    message("[OK] Created study_parameters.yaml template")
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
    message("[!] Added default timezone: America/Chicago")
  }
  
  # -------------------------
  # Ensure external_data_sources exists (add empty if missing)
  # -------------------------
  
  if (is.null(cfg$study_parameters$external_data_sources)) {
    cfg$study_parameters$external_data_sources <- character(0)
    message("[!] Added empty external_data_sources")
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
    "[OK] study_parameters.yaml reconciled (%d detectors)",
    length(detector_ids)
  ))
  
  invisible(TRUE)
}

# ==============================================================================
# END OF FILE
# ==============================================================================