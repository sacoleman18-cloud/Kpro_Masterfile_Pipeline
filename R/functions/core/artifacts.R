# =============================================================================
# UTILITY: artifacts.R - Artifact Registry & File Provenance
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# - Manages artifact registry, hashing, and provenance tracking
# - Used by all modules and workflows
# PURPOSE
# -------
# Provides a formal artifact registry for tracking all pipeline outputs,
# including hashing for reproducibility verification and provenance tracking.
# Maintains a catalog of produced files with SHA256 hashes and metadata.
#
# This module is the authoritative source for file catalog and provenance.
# It tracks WHAT files were produced, not what happened during execution
# (see validation_reporting.R for execution tracking and reporting).
#
# DEPENDENCIES
# ------------
# R Packages: 
#   - yaml:  Registry file I/O
#   - digest: SHA256 hashing
#   - here: Path management
#
# Internal Dependencies: None
#
# FUNCTIONS PROVIDED
# ------------------
#
# Registry Management - Artifact tracking and discovery:
#
#   - init_artifact_registry():
#       Uses packages: yaml (read_yaml), here (here), base R (file operations)
#       Calls internal: none (YAML I/O + filesystem)
#       Purpose: Create/load artifact registry with all metadata
#
#   - register_artifact():
#       Uses packages: digest (sha256), base R (file operations)
#       Calls internal: none (list manipulation)
#       Purpose: Add artifact to registry with SHA256 hash and metadata
#
#   - get_artifact():
#       Uses packages: base R (list operations)
#       Calls internal: none
#       Purpose: Retrieve single artifact metadata by ID
#
#   - list_artifacts():
#       Uses packages: base R (data.frame operations, do.call)
#       Calls internal: none
#       Purpose: List all artifacts (optionally filtered by type/workflow)
#
#   - get_latest_artifact():
#       Uses packages: base R (list operations, max, which)
#       Calls internal: none
#       Purpose: Get most recent artifact by type (sorted by timestamp)
#
# Hashing & Provenance - Deterministic hashing:
#
#   - hash_file():
#       Uses packages: digest (sha256), base R (file operations)
#       Calls internal: none (pure I/O)
#       Purpose: Compute SHA256 hash of file for integrity checking
#
#   - hash_dataframe():
#       Uses packages: digest (sha256), base R (data.frame operations)
#       Calls internal: none
#       Purpose: Compute deterministic hash of data frame (sorted rows)
#
#   - verify_artifact():
#       Uses packages: digest (sha256), base R (file operations)
#       Calls internal: artifacts.R (hash_file)
#       Purpose: Check if artifact matches registered hash
#
# RDS Management - Atomic save + register operations:
#
#   - save_and_register_rds():
#       Uses packages: base R (saveRDS, file operations), digest (sha256)
#       Calls internal: artifacts.R (register_artifact, hash_file)
#       Purpose: Save RDS file and register with metadata atomically
#
# RDS Discovery - Load and validate pipeline outputs:
#
#   - discover_pipeline_rds():
#       Uses packages: base R (list.files, grep)
#       Calls internal: none (filesystem scanning)
#       Purpose: Discover summary_data and plot_objects RDS files
#
#   - validate_rds_structure():
#       Uses packages: base R (list operations, all, names)
#       Calls internal: none (validation only)
#       Purpose: Validate loaded RDS has required elements/structure
#
# USAGE
# -----
# # Initialize registry
# registry <- init_artifact_registry()
# 
# # Register artifacts
# register_artifact(registry, "kpro_master", "masterfile", "02", file_path)
# 
# # Save and register RDS atomically
# registry <- save_and_register_rds(
#   object = all_summaries,
#   file_path = here::here("results", "rds", "summary_data_20250203.rds"),
#   artifact_type = "summary_stats",
#   workflow = "summary_stats",
#   registry = registry,
#   metadata = list(n_summaries = 8, has_species = TRUE),
#   verbose = TRUE
# )
#
# CHANGELOG
# ---------
# 2026-02-05: DOCUMENTATION FIX - Removed duplicate CHANGELOG and orphaned text
#             - Removed lines 89-116 (duplicate CHANGELOG section + orphaned validation text)
#             - Single CHANGELOG now maintained per documentation standards
# 2026-02-03: Moved validation tracking/reporting to validation_reporting.R
#             - Removed create_validation_context() → validation_reporting.R
#             - Removed log_validation_event() → validation_reporting.R
#             - Removed finalize_validation_report() → validation_reporting.R
#             - Removed generate_validation_html() → validation_reporting.R
#             - Reduced from 1,541 to ~900 lines (41% reduction)
#             - Now focused purely on file catalog and provenance
#             - Improved separation of concerns (file catalog vs execution tracking)
# 2026-02-03: Added RDS management helper for orchestrator functions
#             - Added save_and_register_rds() to consolidate RDS save + registration
#             - Atomically saves RDS file and registers with SHA256 hash
#             - Reduces ~20 lines of boilerplate per usage (Summary Stats, Plotting stages)
#             - Added Internal Dependencies section to DEPENDENCIES
# 2026-02-01: Restored hash_dataframe() with enhanced documentation for 3-chunk system
#             - Added deterministic sorting recommendations for kpro_master and CPN data
#             - Enhanced CONTRACT and RECOMMENDED USAGE sections
#             - Ensures reproducibility tracking for all data artifacts
# 2026-01-30: Added filter_noid and filter_zero_pulses event tracking
# 2026-01-30: Enhanced Summary Metrics card with collapsible breakdown
# 2026-01-30: Added CSS styling for details/summary elements
# 2026-01-12: Enhanced HTML reports with collapsible details and workflow-specific sections
# 2026-01-12: Added additional summary metrics (files_loaded, schema_unknown, etc.)
# 2026-01-12: Initial version
# =============================================================================

library(yaml)
library(digest)
library(here)

# =============================================================================
# CONSTANTS
# =============================================================================

REGISTRY_PATH <- here::here("inst", "config", "artifact_registry.yaml")
PIPELINE_VERSION <- "2.1"

ARTIFACT_TYPES <- c(
  "raw_input",
  "checkpoint", 
  "masterfile",
  "cpn_template",
  "cpn_final",
  "summary_stats",
  "plot_objects",
  "report",
  "release_bundle",
  "validation_report"
)

# =============================================================================
# REGISTRY MANAGEMENT
# =============================================================================

#' Initialize or Load Artifact Registry
#'
#' @description
#' Creates a new artifact registry or loads an existing one. The registry
#' is a YAML file that tracks all pipeline artifacts with metadata. 
#'
#' @param registry_path Character. Path to registry file.  
#'   Defaults to inst/config/artifact_registry.yaml
#'
#' @return List. Registry object with artifacts and metadata.
#'
#' @section CONTRACT:
#' - Creates registry file if it doesn't exist
#' - Returns valid registry structure even if empty
#' - Never overwrites existing registry
#'
#' @section DOES NOT:
#' - Validate existing registry structure (assumes well-formed YAML)
#' - Create backups of registry file
#' - Handle concurrent access (not thread-safe)
#'
#' @export
init_artifact_registry <- function(registry_path = REGISTRY_PATH) {
  
  # Ensure directory exists
  registry_dir <- dirname(registry_path)
  if (!dir.exists(registry_dir)) {
    dir.create(registry_dir, recursive = TRUE)
  }
  
  # Load existing or create new
  if (file.exists(registry_path)) {
    registry <- yaml::read_yaml(registry_path)
    message(sprintf("[OK] Loaded artifact registry: %d artifacts", 
                    length(registry$artifacts)))
  } else {
    registry <- list(
      registry_version = "1.0",
      created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      pipeline_version = PIPELINE_VERSION,
      artifacts = list()
    )
    yaml::write_yaml(registry, registry_path)
    message("[OK] Created new artifact registry")
  }
  
  # Attach path for later saves
  attr(registry, "path") <- registry_path
  
  registry
}


#' Register an Artifact
#'
#' @description
#' Adds an artifact to the registry with full provenance metadata including
#' file hash, optional data hash for reproducibility, source workflow, and timestamps.
#'
#' @param registry List. Registry object from init_artifact_registry()
#' @param artifact_name Character. Unique name for this artifact
#' @param artifact_type Character. One of ARTIFACT_TYPES
#' @param workflow Character. Workflow that produced this (e.g., "ingest", "cpn_template")
#' @param file_path Character. Path to artifact file
#' @param input_artifacts Character vector. Names of input artifacts (for lineage)
#' @param metadata List. Additional metadata to store
#' @param data_hash Character. Optional SHA256 hash of data frame content for
#'   deterministic reproducibility. If provided, stored as data_hash_sha256. Default: NULL
#' @param quiet Logical. Suppress messages if TRUE
#'
#' @return List. Updated registry object (also saved to disk)
#'
#' @section CONTRACT:
#' - Computes SHA256 hash of file automatically
#' - Stores data_hash if provided for reproducibility tracking
#' - Adds timestamp and pipeline version
#' - Saves registry to disk
#' - Returns updated registry invisibly
#'
#' @section RECOMMENDED:
#' For data artifacts (checkpoints), provide data_hash:
#' ```r
#' data_hash <- hash_dataframe(kpro_master, sort_by = c("Detector", "DateTime_local"))
#' registry <- register_artifact(registry, "kpro_master", "masterfile", "ingest",
#'                                file_path, data_hash = data_hash)
#' ```
#'
#' @section DOES NOT:
#' - Validate that input_artifacts exist in registry
#' - Check for duplicate artifact names (overwrites silently)
#' - Verify file format matches artifact type
#'
#' @export
register_artifact <- function(registry, 
                              artifact_name,
                              artifact_type,
                              workflow,
                              file_path,
                              input_artifacts = NULL,
                              metadata = list(),
                              data_hash = NULL,
                              quiet = FALSE) {
  
  # Validate artifact type
  if (!artifact_type %in% ARTIFACT_TYPES) {
    stop(sprintf(
      "Invalid artifact_type '%s'. Must be one of: %s",
      artifact_type,
      paste(ARTIFACT_TYPES, collapse = ", ")
    ))
  }
  
  # Validate file exists
  if (!file.exists(file_path)) {
    stop(sprintf("Artifact file not found: %s", file_path))
  }
  
  # Compute hash
  file_hash <- hash_file(file_path)
  
  # Build artifact entry
  artifact_entry <- list(
    name = artifact_name,
    type = artifact_type,
    workflow = workflow,
    file_path = file_path,
    file_hash_sha256 = file_hash,
    file_size_bytes = file.info(file_path)$size,
    created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    pipeline_version = PIPELINE_VERSION,
    input_artifacts = input_artifacts,
    metadata = metadata
  )
  
  # Add data hash if provided (for reproducibility tracking)
  if (!is.null(data_hash)) {
    artifact_entry$data_hash_sha256 <- data_hash
  }
  
  # Add to registry
  registry$artifacts[[artifact_name]] <- artifact_entry
  registry$last_modified_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  
  # Save to disk
  registry_path <- attr(registry, "path")
  if (is.null(registry_path)) registry_path <- REGISTRY_PATH
  yaml::write_yaml(registry, registry_path)
  
  if (!quiet) {
    message(sprintf("[OK] Registered artifact: %s (%s)", artifact_name, artifact_type))
  }
  
  invisible(registry)
}


#' Get Artifact Metadata
#'
#' @description
#' Retrieves metadata for a specific artifact from the registry.
#'
#' @param registry List. Registry object
#' @param artifact_name Character. Name of artifact to retrieve
#'
#' @return List. Artifact metadata, or NULL if not found
#'
#' @section CONTRACT:
#' - Returns complete artifact metadata if found
#' - Returns NULL if artifact doesn't exist
#'
#' @export
get_artifact <- function(registry, artifact_name) {
  registry$artifacts[[artifact_name]]
}


#' List All Artifacts
#'
#' @description
#' Returns a data frame summary of all artifacts in the registry,
#' with optional filtering by type or workflow.
#'
#' @param registry List. Registry object
#' @param type Character. Optional filter by artifact type
#' @param workflow Character. Optional filter by workflow
#'
#' @return Data frame. Summary of matching artifacts
#'
#' @section CONTRACT:
#' - Returns empty data frame if no artifacts match
#' - Hash is truncated to first 8 characters for display
#' - Preserves chronological order from registry
#'
#' @export
list_artifacts <- function(registry, type = NULL, workflow = NULL) {
  
  if (length(registry$artifacts) == 0) {
    return(data.frame(
      name = character(),
      type = character(),
      workflow = character(),
      created_utc = character(),
      stringsAsFactors = FALSE
    ))
  }
  
  # Convert to data frame
  df <- purrr::map_dfr(registry$artifacts, function(a) {
    data.frame(
      name = a$name,
      type = a$type,
      workflow = a$workflow,
      created_utc = a$created_utc,
      file_path = a$file_path,
      file_hash = substr(a$file_hash_sha256, 1, 8),  # Truncated for display
      stringsAsFactors = FALSE
    )
  })
  
  # Apply filters
  if (!is.null(type)) {
    df <- df[df$type == type, ]
  }
  
  if (!is.null(workflow)) {
    df <- df[df$workflow == workflow, ]
  }
  
  df
}


#' Get Most Recent Artifact by Type
#'
#' @description
#' Finds and returns the most recently created artifact of a given type.
#'
#' @param registry List. Registry object
#' @param type Character. Artifact type to find
#'
#' @return List. Most recent artifact of that type, or NULL if none found
#'
#' @section CONTRACT:
#' - Sorts by created_utc timestamp (ISO 8601 format)
#' - Returns NULL if no artifacts of that type exist
#' - Only considers exact type matches
#'
#' @export
get_latest_artifact <- function(registry, type) {
  
  matching <- purrr::keep(registry$artifacts, ~ .x$type == type)
  
  if (length(matching) == 0) return(NULL)
  
  # Sort by created_utc descending
  sorted <- matching[order(sapply(matching, `[[`, "created_utc"), decreasing = TRUE)]
  
  sorted[[1]]
}


# =============================================================================
# HASHING FUNCTIONS
# =============================================================================

#' Compute SHA256 Hash of File
#'
#' @description
#' Computes a SHA256 hash of a file for integrity verification.
#'
#' @param file_path Character. Path to file
#'
#' @return Character. SHA256 hash string (64 hex characters)
#'
#' @section CONTRACT:
#' - Returns 64-character hexadecimal hash
#' - Hash is deterministic (same file -> same hash)
#' - Errors if file doesn't exist
#'
#' @export
hash_file <- function(file_path) {
  if (!file.exists(file_path)) {
    stop(sprintf("File not found: %s", file_path))
  }
  
  digest::digest(file_path, algo = "sha256", file = TRUE)
}


#' Compute Hash of Data Frame
#'
#' @description
#' Computes a content-based hash of a data frame for deterministic
#' reproducibility tracking. Ensures same data produces same hash
#' regardless of row order when sort_by is specified.
#'
#' @param df Data frame to hash
#' @param sort_by Character vector. Column names to sort by for deterministic
#'   order. If NULL, uses existing row order (not recommended). Default: NULL
#'
#' @return Character. SHA256 hash string (64 hex characters)
#'
#' @section CONTRACT:
#' - Hash is deterministic when sort_by is specified
#' - Ignores row names and attributes (only data content)
#' - Same data in different order produces same hash (with sort_by)
#'
#' @section DOES NOT:
#' - Validate that sort_by columns exist (will error if missing)
#' - Handle NA values specially (sorts NA to end)
#' - Include metadata or attributes in hash
#'
#' @section RECOMMENDED USAGE:
#' ```r
#' # For kpro_master: sort by detector, datetime, species
#' hash <- hash_dataframe(kpro_master, sort_by = c("Detector", "DateTime_local", "auto_id"))
#' 
#' # For CPN data: sort by detector and night
#' hash <- hash_dataframe(cpn_final, sort_by = c("Detector", "Night"))
#' ```
#'
#' @export
hash_dataframe <- function(df, sort_by = NULL) {
  
  if (!is.data.frame(df)) {
    stop("Input must be a data frame")
  }
  
  # Sort for deterministic order
  if (!is.null(sort_by)) {
    df <- df[do.call(order, df[sort_by]), ]
  }
  
  # Hash the serialized content
  digest::digest(df, algo = "sha256")
}


#' Verify Artifact Integrity
#'
#' @description
#' Checks if a file's current hash matches its registered hash.
#'
#' @param registry List. Registry object
#' @param artifact_name Character. Name of artifact to verify
#'
#' @return Logical. TRUE if hashes match, FALSE otherwise
#'
#' @section CONTRACT:
#' - Returns TRUE only if file exists and hash matches exactly
#' - Returns FALSE and warns if artifact not in registry
#' - Returns FALSE and warns if file missing or hash mismatch
#'
#' @export
verify_artifact <- function(registry, artifact_name) {
  
  artifact <- get_artifact(registry, artifact_name)
  
  if (is.null(artifact)) {
    warning(sprintf("Artifact not found in registry: %s", artifact_name))
    return(FALSE)
  }
  
  if (!file.exists(artifact$file_path)) {
    warning(sprintf("Artifact file not found: %s", artifact$file_path))
    return(FALSE)
  }
  
  current_hash <- hash_file(artifact$file_path)
  matches <- current_hash == artifact$file_hash_sha256
  
  if (!matches) {
    warning(sprintf(
      "Hash mismatch for %s:\n  Registered: %s\n  Current:    %s",
      artifact_name,
      artifact$file_hash_sha256,
      current_hash
    ))
  }
  
  matches
}

# =============================================================================
# RDS MANAGEMENT
# =============================================================================
# Atomic operations for saving RDS files and registering them in the artifact
# registry. Consolidates the save + register pattern used in orchestrators.
# =============================================================================


#' Save RDS File and Register Artifact
#'
#' @description
#' Atomically saves an R object as RDS file and registers it in the artifact
#' registry with SHA256 hash. Consolidates the RDS save + register pattern
#' used in Summary Stats and Plotting stages. Reduces ~20 lines of boilerplate
#' per usage.
#'
#' Standards Reference: 07_artifact_release_standards.md §2.1, §2.2
#'
#' @param object Any R object to save as RDS.
#' @param file_path Character. Full path to RDS file (e.g., 
#'   here::here("results", "rds", "summary_data_20250203.rds")).
#' @param artifact_type Character. Type identifier for registry (e.g.,
#'   "summary_stats", "plot_objects"). Used to generate artifact_name.
#' @param workflow Character. Workflow name for registry (e.g., "summary_stats",
#'   "exploratory_plots").
#' @param registry List. Current artifact registry from init_artifact_registry().
#' @param metadata List. Additional metadata for registry entry. Default: list().
#' @param verbose Logical. Print confirmation message to console? Default: FALSE.
#'
#' @return List. Updated artifact registry with new entry.
#'
#' @section CONTRACT:
#' - Creates output directory if needed
#' - Saves R object to file_path as RDS
#' - Generates artifact_name as "{artifact_type}_{YYYYMMDD}"
#' - Computes SHA256 hash automatically (via register_artifact)
#' - Registers artifact with type, workflow, path, and metadata
#' - Prints confirmation if verbose = TRUE
#' - Returns updated registry for chaining
#'
#' @section DOES NOT:
#' - Validate object structure
#' - Check if file already exists (overwrites)
#' - Compress RDS (uses default compression)
#' - Log to pipeline log (use log_message separately if needed)
#'
#' @examples
#' \dontrun{
#' # Initialize registry
#' registry <- init_artifact_registry()
#'
#' # Save and register summary statistics
#' summary_rds_path <- here::here("results", "rds", "summary_data_20250203.rds")
#' registry <- save_and_register_rds(
#'   object = all_summaries,
#'   file_path = summary_rds_path,
#'   artifact_type = "summary_stats",
#'   workflow = "summary_stats",
#'   registry = registry,
#'   metadata = list(
#'     n_summaries = length(all_summaries),
#'     has_species = TRUE,
#'     has_temporal = TRUE
#'   ),
#'   verbose = TRUE
#' )
#' # Prints: "  [OK] Saved: summary_data_20250203.rds"
#'
#' # Save and register plots
#' plots_rds_path <- here::here("results", "rds", "plot_objects_20250203.rds")
#' registry <- save_and_register_rds(
#'   object = all_plots,
#'   file_path = plots_rds_path,
#'   artifact_type = "plot_objects",
#'   workflow = "exploratory_plots",
#'   registry = registry,
#'   metadata = list(
#'     total_plots = 26,
#'     quality_plots = 8,
#'     detector_plots = 7,
#'     species_plots = 5,
#'     temporal_plots = 6
#'   ),
#'   verbose = TRUE
#' )
#' }
#'
#' @export
save_and_register_rds <- function(object,
                                  file_path,
                                  artifact_type,
                                  workflow,
                                  registry,
                                  metadata = list(),
                                  verbose = FALSE) {
  
  # Ensure output directory exists
  output_dir <- dirname(file_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    if (verbose) {
      message(sprintf("Created directory: %s", output_dir))
    }
  }
  
  # Save RDS file
  saveRDS(object, file_path)
  
  # Generate artifact ID from type and timestamp
  timestamp <- format(Sys.time(), "%Y%m%d")
  artifact_id <- sprintf("%s_%s", artifact_type, timestamp)
  
  # Register artifact (computes hash automatically)
  registry <- register_artifact(
    registry = registry,
    artifact_name = artifact_id,
    artifact_type = artifact_type,
    workflow = workflow,
    file_path = file_path,
    metadata = metadata,
    quiet = !verbose  # If verbose=TRUE, show registration message
  )
  
  # Print confirmation if verbose (in addition to registration message)
  if (verbose) {
    message(sprintf("  [OK] Saved: %s", basename(file_path)))
  }
  
  registry
}


# =============================================================================
# NOTE: Validation tracking and reporting functions have been moved to
#       core/validation_reporting.R for better separation of concerns.
#       See validation_reporting.R for:
#         - create_validation_context()
#         - log_validation_event()
#         - finalize_validation_report()
#         - generate_validation_html()
# =============================================================================


# RDS DISCOVERY & VALIDATION
# ==============================================================================


#' Discover Pipeline RDS Files
#'
#' @description
#' Finds the most recent summary_data and plot_objects RDS files from 
#' Workflows 05-06. Returns paths and validation status.
#'
#' @param rds_dir Character. Path to RDS directory (usually results/rds/)
#'
#' @return List with:
#'   - valid: Logical. TRUE if both files found
#'   - summary_path: Character. Path to summary_data RDS (or NULL)
#'   - plots_path: Character. Path to plot_objects RDS (or NULL)
#'   - errors: Character vector. Error messages if any
#'
#' @section CONTRACT:
#' - Finds most recent files matching expected patterns
#' - Returns NULL for missing files (doesn't error)
#' - Provides clear error messages
#'
#' @section DOES NOT:
#' - Load or validate RDS contents (use validate_rds_structure)
#' - Create directories
#' - Search recursively
#'
#' @examples
#' \dontrun{
#' discovery <- discover_pipeline_rds(here::here("results", "rds"))
#' if (discovery$valid) {
#'   all_summaries <- readRDS(discovery$summary_path)
#'   all_plots <- readRDS(discovery$plots_path)
#' }
#' }
#'
#' @export
discover_pipeline_rds <- function(rds_dir) {
  
  errors <- character()
  
  # Check directory exists
  if (!dir.exists(rds_dir)) {
    return(list(
      valid = FALSE,
      summary_path = NULL,
      plots_path = NULL,
      errors = sprintf("RDS directory not found: %s", rds_dir)
    ))
  }
  
  # Find summary_data file
  summary_files <- list.files(
    rds_dir,
    pattern = "^summary_data_.*\\.rds$",
    full.names = TRUE
  )
  
  if (length(summary_files) == 0) {
    errors <- c(errors, 
                "No summary_data RDS file found. Did you run Workflow 05?")
    summary_path <- NULL
  } else {
    # Get most recent by modification time
    summary_times <- file.info(summary_files)$mtime
    summary_path <- summary_files[which.max(summary_times)]
  }
  
  # Find plot_objects file
  plots_files <- list.files(
    rds_dir,
    pattern = "^plot_objects_.*\\.rds$",
    full.names = TRUE
  )
  
  if (length(plots_files) == 0) {
    errors <- c(errors,
                "No plot_objects RDS file found. Did you run Workflow 06?")
    plots_path <- NULL
  } else {
    # Get most recent by modification time
    plots_times <- file.info(plots_files)$mtime
    plots_path <- plots_files[which.max(plots_times)]
  }
  
  list(
    valid = length(errors) == 0,
    summary_path = summary_path,
    plots_path = plots_path,
    errors = errors
  )
}


#' Validate RDS Structure
#'
#' @description
#' Validates that loaded RDS objects contain required elements for
#' report generation. Checks summary_data and plot_objects structure.
#'
#' @param all_summaries List. Summary data from Workflow 05
#' @param all_plots List. Plot objects from Workflow 06
#'
#' @return List with:
#'   - valid: Logical. TRUE if structure is valid
#'   - errors: Character vector. Error messages if any
#'   - warnings: Character vector. Warning messages if any
#'   - has_species: Logical. TRUE if species plots available
#'   - plot_counts: Named list. Count of plots per category
#'   - total_plots: Integer. Total number of plots
#'
#' @section CONTRACT:
#' - Validates presence of required elements
#' - Counts plots by category
#' - Detects optional species data
#' - Returns validation status (doesn't error)
#'
#' @section REQUIRED ELEMENTS:
#' Summary data must contain:
#'   - detector_summary
#'   - study_summary
#'   - metadata
#'
#' Plot objects must contain categories:
#'   - quality
#'   - detector
#'   - temporal
#'   - species (optional)
#'
#' @section DOES NOT:
#' - Validate plot object types
#' - Check data frame schemas
#' - Modify input objects
#'
#' @examples
#' \dontrun{
#' all_summaries <- readRDS("results/rds/summary_data_20260109.rds")
#' all_plots <- readRDS("results/rds/plot_objects_20260109.rds")
#' 
#' validation <- validate_rds_structure(all_summaries, all_plots)
#' if (!validation$valid) {
#'   stop(paste(validation$errors, collapse = "\n"))
#' }
#' }
#'
#' @export
validate_rds_structure <- function(all_summaries, all_plots) {
  
  errors <- character()
  warnings <- character()
  
  # -------------------------
  # Validate summary structure
  # -------------------------
  
  required_summary_names <- c("detector_summary", "study_summary", "metadata")
  missing_summaries <- setdiff(required_summary_names, names(all_summaries))
  
  if (length(missing_summaries) > 0) {
    errors <- c(errors, sprintf(
      "summary_data RDS missing required elements: %s",
      paste(missing_summaries, collapse = ", ")
    ))
  }
  
  # -------------------------
  # Validate plot structure
  # -------------------------
  
  required_plot_categories <- c("quality", "detector", "temporal")
  missing_plots <- setdiff(required_plot_categories, names(all_plots))
  
  if (length(missing_plots) > 0) {
    errors <- c(errors, sprintf(
      "plot_objects RDS missing required categories: %s",
      paste(missing_plots, collapse = ", ")
    ))
  }
  
  # -------------------------
  # Count plots by category
  # -------------------------
  
  plot_counts <- list()
  total_plots <- 0
  
  for (category in c("quality", "detector", "species", "temporal")) {
    if (!is.null(all_plots[[category]])) {
      count <- length(all_plots[[category]])
    } else {
      count <- 0
    }
    plot_counts[[category]] <- count
    total_plots <- total_plots + count
  }
  
  # -------------------------
  # Check for species data
  # -------------------------
  
  has_species <- !is.null(all_plots$species) && length(all_plots$species) > 0
  
  if (!has_species) {
    warnings <- c(warnings, "Species plots not available (no species data)")
  }
  
  # -------------------------
  # Return validation result
  # -------------------------
  
  list(
    valid = length(errors) == 0,
    errors = errors,
    warnings = warnings,
    has_species = has_species,
    plot_counts = plot_counts,
    total_plots = total_plots
  )
}

# ==============================================================================
# END OF FILE
# ==============================================================================