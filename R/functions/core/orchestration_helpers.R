# ==============================================================================
# ORCHESTRATION HELPER FUNCTIONS
# ==============================================================================
#
# PURPOSE:
#   Convenience functions for orchestrator workflow scripts. These functions
#   consolidate common patterns in multi-stage pipeline orchestrators, reducing
#   boilerplate and ensuring consistent pipeline behavior across workflows.
#
#   Extracted from utilities.R (2026-02-09) to separate orchestrator-specific
#   logic from general utilities. Functions remain in core/ because they have
#   zero internal dependencies (only use base/readr/here).
#
# FUNCTIONS PROVIDED
# ------------------
#
# Pipeline Context Management - Initialize orchestrator state:
#
#   - setup_pipeline_context():
#       Uses packages: yaml (config.R), base R (list operations)
#       Calls internal: config.R (load_study_parameters),
#                       validation.R (create_validation_context),
#                       utilities.R (ensure_dir_exists)
#       Purpose: Initialize context object (config + validation context + paths)
#
#   - load_most_recent_checkpoint():
#       Uses packages: base R (list.files, grep, sort)
#       Calls internal: utilities.R (safe_read_csv, find_most_recent_file)
#       Purpose: Discover and load most recent checkpoint by filename pattern
#
#   - store_stage_results():
#       Uses packages: base R (list operations)
#       Calls internal: none (list consolidation)
#       Purpose: Consolidate stage outputs (data, metadata, paths) in result list
#
# Artifact Management - Checkpoint save + registration:
#
#   - generate_timestamped_filename():
#       Uses packages: base R (Sys.time, format, paste0)
#       Calls internal: none (string formatting)
#       Purpose: Generate filename with ISO timestamp (YYYYMMDD_HHMMSS)
#
#   - save_checkpoint_and_register():
#       Uses packages: readr (write_csv), here (here), base R (file.path)
#       Calls internal: artifacts.R (init_artifact_registry, register_artifact, hash_file),
#                       utilities.R (ensure_dir_exists, make_output_path)
#       Purpose: Atomically save CSV checkpoint and register with artifact system
#
# Stage Lifecycle - Start/finalize operations:
#
#   - log_stage_start():
#       Uses packages: base R (cat, message, sprintf)
#       Calls internal: logging.R (log_message), console.R (print_stage_banner)
#       Purpose: Print stage header to console and log to file
#
#   - finalize_stage_validation_report():
#       Uses packages: base R (file.path, dir.create)
#       Calls internal: validation_reporting.R (finalize_validation_report),
#                       utilities.R (ensure_dir_exists)
#       Purpose: Create validation directory and finalize HTML report
#
# DEPENDENCIES:
#   Internal:  
#     - utilities.R (ensure_dir_exists, safe_read_csv)
#     - config.R (load_study_parameters)
#     - validation.R (create_validation_context, finalize_validation_report, complete_stage_validation)
#     - console.R (print_stage_header)
#     - logging.R (log_message)
#     - artifacts.R (init_artifact_registry, register_artifact)
#   
#   External:  
#     - readr (write_csv)
#     - here (here)
#     - base (file operations, datetime formatting)
#
# USAGE:
#   source("R/functions/core/utilities.R")
#   source("R/functions/core/orchestration_helpers.R")
#   
#   # Initialize pipeline context
#   context <- setup_pipeline_context(workflow_name = "ingest")
#   
#   # Log stage start
#   log_stage_start("1", "Load Raw Data", verbose = TRUE)
#   
#   # Save and register checkpoint
#   registry <- save_checkpoint_and_register(
#     data = kpro_master,
#     checkpoint_name = "02_kpro_master",
#     artifact_type = "masterfile",
#     workflow = "ingest",
#     metadata = list(n_rows = nrow(kpro_master)),
#     verbose = TRUE
#   )
#   
#   # Finalize validation report
#   validation_html <- finalize_stage_validation_report(
#     validation_context,
#     stage_name = "INGEST & STANDARDIZE",
#     verbose = TRUE
#   )
#
# NOTES:
#   - These functions are orchestrator-specific convenience wrappers that reduce
#     ~50-100 lines of boilerplate per orchestrator function
#   - All functions preserve atomicity and error handling of underlying calls
#   - Functions do NOT log to pipeline log (caller's responsibility to use
#     log_message separately if needed, per CODING_STANDARDS gating pattern)
#   - save_checkpoint_and_register handles DateTime_local formatting for CSV export
#
# HISTORY:
#   2026-02-09: Extracted from utilities.R (lines 460-1140) to separate concerns
#               and reduce utilities.R from 1,543 lines
#
# ==============================================================================


# ==============================================================================
# PIPELINE CONTEXT MANAGEMENT
# ==============================================================================


#' Setup Pipeline Context
#'
#' @description
#' Initializes a structured context object for pipeline orchestrators.
#' Consolidates configuration loading, validation context creation, and
#' directory setup into a single call.
#'
#' @param workflow_name Character. Workflow identifier (e.g., "ingest", "finalize_cpn").
#' @param yaml_path Character. Path to study configuration YAML.
#'   Default: "inst/config/study_parameters.yaml"
#' @param checkpoint_dir Character. Checkpoint directory path.
#'   Default: "outputs/checkpoints"
#' @param outputs_dir Character. Outputs directory path.
#'   Default: "outputs"
#'
#' @return List containing:
#'   - yaml_path: Character, path to configuration file
#'   - study_params: List, loaded study parameters
#'   - validation_context: List, initialized validation context
#'   - checkpoint_dir: Character, checkpoint directory path
#'   - outputs_dir: Character, outputs directory path
#'
#' @section CONTRACT:
#' - Requires YAML configuration file to exist
#' - Loads study parameters via load_study_parameters()
#' - Creates validation context via create_validation_context()
#' - Does not create directories (caller's responsibility)
#' - Stops with actionable error if YAML not found
#'
#' @section DOES NOT:
#' - Create directories
#' - Validate study parameter structure
#' - Initialize artifact registry
#' - Log to file (caller's responsibility)
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' context <- setup_pipeline_context(workflow_name = "ingest")
#' study_name <- context$study_params$study_parameters$study_name
#' timezone <- context$study_params$study_parameters$timezone
#'
#' # Custom paths
#' context <- setup_pipeline_context(
#'   workflow_name = "finalize_cpn",
#'   yaml_path = "config/custom_study.yaml",
#'   checkpoint_dir = "data/checkpoints"
#' )
#' }
#'
#' @export
setup_pipeline_context <- function(workflow_name,
                                   yaml_path = "inst/config/study_parameters.yaml",
                                   checkpoint_dir = "outputs/checkpoints",
                                   outputs_dir = "outputs") {
  
  # Assert YAML exists
  if (!file.exists(yaml_path)) {
    stop(sprintf(
      "Configuration file not found: %s\n  Configure study parameters in Shiny app first.",
      yaml_path
    ))
  }
  
  # Load configuration (requires load_study_parameters from config.R)
  study_params <- load_study_parameters(yaml_path)
  
  # Create validation context (requires create_validation_context from validation.R)
  validation_context <- create_validation_context(workflow = workflow_name)
  validation_context$study_name <- study_params$study_parameters$study_name
  
  list(
    yaml_path = yaml_path,
    study_params = study_params,
    validation_context = validation_context,
    checkpoint_dir = checkpoint_dir,
    outputs_dir = outputs_dir
  )
}


#' Load Most Recent Checkpoint
#'
#' @description
#' Discovers and loads the most recent checkpoint file matching a pattern.
#' Replaces legacy checkpoint loaders with a generic pattern-based approach.
#'
#' @param pattern Character. Regex pattern for filename matching.
#'
#' @return Tibble loaded from most recent checkpoint file.
#'
#' @section CONTRACT:
#' - Searches outputs/checkpoints/ directory
#' - Uses filename timestamps for "most recent" determination
#' - Returns tibble with all columns as character
#' - Stops with actionable error if no files found
#'
#' @section DOES NOT:
#' - Convert column types (caller's responsibility)
#' - Validate data structure
#' - Create directories
#'
#' @examples
#' \dontrun{
#' # Load most recent kpro_master
#' kpro_master <- load_most_recent_checkpoint("^02_kpro_master_.*\\.csv$")
#'
#' # Load most recent CPN final
#' cpn_final <- load_most_recent_checkpoint("^04_CallsPerNight_Final_.*\\.csv$")
#' }
#'
#' @export
load_most_recent_checkpoint <- function(pattern) {
  
  checkpoint_dir <- here::here("outputs", "checkpoints")
  
  if (!dir.exists(checkpoint_dir)) {
    stop(sprintf("Checkpoint directory not found: %s\n  Run previous chunk first.", checkpoint_dir))
  }
  
  files <- list.files(checkpoint_dir, pattern = pattern, full.names = TRUE)
  
  if (length(files) == 0) {
    stop(sprintf(
      "No checkpoint files found matching pattern: %s\n  Directory: %s\n  Run previous chunk first.",
      pattern, checkpoint_dir
    ))
  }
  
  # Get most recent (last in sorted list)
  most_recent <- files[length(files)]
  
  safe_read_csv(most_recent)
}


#' Store Stage Results in Orchestrator Result Object
#'
#' @description
#' Consolidates stage outputs into a structured result object used by 
#' multi-stage orchestrator functions. Stores stage-specific outputs under 
#' a stage key and tracks validation HTML paths.
#'
#' @param result List. The result object being built (must have 
#'   `validation_html_paths` field).
#' @param stage_key Character. Unique identifier for the stage 
#'   (e.g., "ingest_standardize", "finalize_cpn").
#' @param stage_outputs List. Stage-specific outputs to store (typically 
#'   includes data, metadata, artifact_id, checkpoint_path).
#' @param validation_html Character. Optional. Path to validation HTML for 
#'   this stage.
#'
#' @return List. Updated result object with stage outputs stored and 
#'   validation_html added to tracking array.
#'
#' @section CONTRACT:
#' - Stores stage_outputs under result[[stage_key]]
#' - Appends validation_html to result$validation_html_paths if provided
#' - Returns modified result object
#' - Does not validate structure of stage_outputs (caller's responsibility)
#'
#' @section DOES NOT:
#' - Create or validate files
#' - Modify global state
#' - Write to log (caller's responsibility)
#' - Validate stage_key uniqueness (caller may overwrite)
#'
#' @examples
#' \dontrun{
#' # Initialize result object
#' result <- list(
#'   validation_html_paths = character()
#' )
#' 
#' # Store stage outputs
#' stage_outputs <- list(
#'   kpro_master = df,
#'   metadata = list(n_rows = nrow(df)),
#'   artifact_id = "kpro_master_20260205"
#' )
#' 
#' result <- store_stage_results(
#'   result,
#'   stage_key = "ingest_standardize",
#'   stage_outputs = stage_outputs,
#'   validation_html = "results/validation/validation_ingest_20260205.html"
#' )
#' 
#' # Access stored outputs
#' master <- result$ingest_standardize$kpro_master
#' all_reports <- result$validation_html_paths
#' }
#'
#' @export
store_stage_results <- function(result, 
                                stage_key, 
                                stage_outputs, 
                                validation_html = NULL) {
  
  # Store stage outputs under stage key
  result[[stage_key]] <- stage_outputs
  
  # Track validation HTML if provided
  if (!is.null(validation_html) && nchar(validation_html) > 0) {
    result$validation_html_paths <- c(result$validation_html_paths, validation_html)
  }
  
  result
}


# ==============================================================================
# ARTIFACT MANAGEMENT
# ==============================================================================


#' Generate Timestamped Filename
#'
#' @description
#' Generates a filename with embedded timestamp in YYYYMMDD_HHMMSS format.
#' Used by orchestrating functions for consistent checkpoint naming.
#'
#' @param prefix Character. Filename prefix (e.g., "02_kpro_master")
#' @param suffix Character. Optional suffix before extension. Default: ""
#'
#' @return Character. Formatted filename string with .csv extension.
#'
#' @section CONTRACT:
#' - Timestamp format: YYYYMMDD_HHMMSS
#' - Pattern: {prefix}_{timestamp}_{suffix}.csv
#' - Returns filename only (not full path)
#'
#' @section DOES NOT:
#' - Create the file
#' - Include directory path
#' - Validate prefix format
#'
#' @examples
#' \dontrun{
#' filename <- generate_timestamped_filename("02_kpro_master")
#' # Returns: "02_kpro_master_20260204_143022.csv"
#'
#' filename <- generate_timestamped_filename("03_CallsPerNight_Template", "ORIGINAL")
#' # Returns: "03_CallsPerNight_Template_20260204_143022_ORIGINAL.csv"
#' }
#'
#' @export
generate_timestamped_filename <- function(prefix, suffix = "") {
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  parts <- c(prefix, timestamp)
  
  if (!is.null(suffix) && nchar(suffix) > 0) {
    parts <- c(parts, suffix)
  }
  
  base_name <- paste(parts, collapse = "_")
  paste0(base_name, ".csv")
}


#' Save Checkpoint and Register as Artifact
#'
#' @description
#' Consolidates the common pattern of saving a CSV checkpoint and registering
#' it in the artifact registry. Atomically performs write_csv → init_artifact_registry
#' → register_artifact sequence in one call. Reduces ~35 lines of boilerplate
#' per usage.
#'
#' @param data Data frame to save as CSV checkpoint.
#' @param file_path Character. Full path to checkpoint file. If NULL, will be
#'   constructed from checkpoint_name, output_dir, and timestamp. Default: NULL.
#' @param checkpoint_name Character. Base name for checkpoint file (without extension).
#'   Used to construct file_path if file_path is NULL. Default: NULL.
#' @param output_dir Character. Output directory for checkpoint. Used with 
#'   checkpoint_name to construct file_path if file_path is NULL. Default: "outputs/checkpoints".
#' @param artifact_name Character. Unique name for artifact registry. If NULL,
#'   will be generated from checkpoint_name. Default: NULL.
#' @param artifact_type Character. Type of artifact (e.g., "checkpoint", "masterfile").
#' @param workflow Character. Workflow that produced this artifact.
#' @param metadata List. Additional metadata for registry entry. Default: list().
#' @param data_hash Character. Optional data frame hash for reproducibility.
#'   Default: NULL.
#' @param verbose Logical. Print confirmation messages? Default: FALSE.
#' @param registry List. Optional existing registry to use. If NULL, loads/creates
#'   registry automatically. Default: NULL.
#'
#' @return List. Updated artifact registry (invisibly).
#'
#' @section CONTRACT:
#' - Accepts either file_path (explicit) OR checkpoint_name + output_dir (constructed)
#' - Creates output directory if needed
#' - Writes data to CSV using readr::write_csv
#' - Generates artifact_name if not provided
#' - Initializes or loads artifact registry if not provided
#' - Registers artifact with file hash and optional data hash
#' - Prints confirmation if verbose = TRUE
#' - Returns updated registry invisibly
#'
#' @section DOES NOT:
#' - Validate data frame schema
#' - Check if file already exists (overwrites)
#' - Log to pipeline log (use log_message separately if needed)
#' - Handle errors in CSV writing (caller should wrap in tryCatch if needed)
#'
#' @examples
#' \dontrun{
#' # Method 1: Explicit file_path
#' registry <- save_checkpoint_and_register(
#'   data = kpro_master,
#'   file_path = here::here("outputs", "checkpoints", "02_kpro_master_20260205.csv"),
#'   artifact_name = "kpro_master_20260205",
#'   artifact_type = "masterfile",
#'   workflow = "ingest",
#'   metadata = list(n_rows = nrow(kpro_master)),
#'   verbose = TRUE
#' )
#'
#' # Method 2: Constructed from checkpoint_name + output_dir
#' registry <- save_checkpoint_and_register(
#'   data = cpn_final,
#'   checkpoint_name = "CallsPerNight_final",
#'   output_dir = here::here("results", "csv"),
#'   artifact_type = "cpn_final",
#'   workflow = "finalize_cpn",
#'   metadata = list(n_rows = nrow(cpn_final)),
#'   verbose = TRUE
#' )
#' # Automatically generates timestamped filename and artifact_name
#' }
#'
#' @export
save_checkpoint_and_register <- function(data,
                                        file_path = NULL,
                                        checkpoint_name = NULL,
                                        output_dir = "outputs/checkpoints",
                                        artifact_name = NULL,
                                        artifact_type,
                                        workflow,
                                        metadata = list(),
                                        data_hash = NULL,
                                        verbose = FALSE,
                                        registry = NULL) {
  
  # Construct file_path if not provided
  if (is.null(file_path)) {
    if (is.null(checkpoint_name)) {
      stop("Either file_path or checkpoint_name must be provided")
    }
    
    # Generate timestamped filename
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    filename <- sprintf("%s_%s.csv", checkpoint_name, timestamp)
    file_path <- file.path(output_dir, filename)
  }
  
  # Generate artifact_name if not provided
  if (is.null(artifact_name)) {
    if (!is.null(checkpoint_name)) {
      timestamp <- format(Sys.time(), "%Y%m%d")
      artifact_name <- sprintf("%s_%s", checkpoint_name, timestamp)
    } else {
      # Extract from file_path
      artifact_name <- tools::file_path_sans_ext(basename(file_path))
    }
  }
  
  # Ensure output directory exists
  output_dir_actual <- dirname(file_path)
  ensure_dir_exists(output_dir_actual)
  
  # Format DateTime_local column for CSV export if present
  # This converts POSIXct to character in MM/DD/YYYY HH:MM:SS format
  # to prevent ISO 8601 format and preserve timezone through CSV round-trip
  data_to_save <- data
  if ("DateTime_local" %in% names(data_to_save)) {
    if (inherits(data_to_save$DateTime_local, "POSIXct")) {
      # Store the timezone for metadata
      dt_tz <- attr(data_to_save$DateTime_local, "tzone")
      if (is.null(dt_tz) || dt_tz == "") {
        dt_tz <- "UTC"  # Default if no timezone set
      }
      
      # Format for CSV export
      data_to_save$DateTime_local <- format_datetime_for_csv(data_to_save$DateTime_local)
      
      # Add timezone to metadata for reconstruction
      if (is.null(metadata$datetime_timezone)) {
        metadata$datetime_timezone <- dt_tz
      }
    }
  }
  
  # Save CSV file
  readr::write_csv(data_to_save, file_path)
  
  # Initialize or use existing registry
  if (is.null(registry)) {
    registry <- init_artifact_registry()
  }
  
  # Register artifact (computes file hash automatically)
  registry <- register_artifact(
    registry = registry,
    artifact_name = artifact_name,
    artifact_type = artifact_type,
    workflow = workflow,
    file_path = file_path,
    metadata = metadata,
    data_hash = data_hash,
    quiet = !verbose
  )
  
  # Print confirmation if verbose
  if (verbose) {
    message(sprintf("  [OK] Saved and registered: %s", basename(file_path)))
  }
  
  invisible(registry)
}


# ==============================================================================
# STAGE LIFECYCLE HELPERS
# ==============================================================================


#' Log Stage Start with Console and File Output
#'
#' @description
#' Consolidates the common pattern of printing a stage header to console
#' and logging a stage message to file. Reduces boilerplate in orchestrator
#' functions by combining print_stage_header() + log_message() into one call.
#'
#' @param stage_num Character. Stage number (e.g., "1", "2.3", "7.1")
#' @param title Character. Stage title (e.g., "Load Configuration")
#' @param verbose Logical. Print to console? Default: FALSE
#' @param log_path Character. Path to log file. Default: "logs/pipeline_log.txt"
#' @param workflow_prefix Character. Optional prefix for log messages
#'   (e.g., "Finalize CPN"). Default: ""
#'
#' @return Invisible NULL.
#'
#' @section CONTRACT:
#' - Prints stage header box to console if verbose = TRUE
#' - Always logs to file (respects CODING_STANDARDS gating pattern)
#' - Formats log message as "[Stage X] Title" or "[Prefix - Stage X] Title"
#' - Returns invisibly
#'
#' @section DOES NOT:
#' - Validate stage number format
#' - Check if log file is writable
#' - Track validation events (use log_validation_event separately)
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' log_stage_start("1", "Load Configuration", verbose = TRUE)
#' # Console: +----STAGE 1: Load Configuration----+
#' # Log:     [2026-02-05 12:34:56] [Stage 1] Load Configuration
#'
#' # With workflow prefix
#' log_stage_start("2", "Generate Template", verbose = FALSE,
#'                workflow_prefix = "Finalize CPN")
#' # Console: (silent)
#' # Log:     [2026-02-05 12:34:56] [Finalize CPN - Stage 2] Generate Template
#' }
#'
#' @export
log_stage_start <- function(stage_num,
                           title,
                           verbose = FALSE,
                           log_path = "logs/pipeline_log.txt",
                           workflow_prefix = "") {
  
  # Print to console if verbose
  if (verbose) {
    print_stage_header(stage_num, title)
  }
  
  # Build log message
  if (nchar(workflow_prefix) > 0) {
    log_msg <- sprintf("[%s - Stage %s] %s", workflow_prefix, stage_num, title)
  } else {
    log_msg <- sprintf("[Stage %s] %s", stage_num, title)
  }
  
  # Always log to file (per CODING_STANDARDS)
  log_message(log_msg, log_path = log_path)
  
  invisible(NULL)
}


#' Finalize Stage Validation Report
#'
#' @description
#' Consolidates the common pattern of creating validation directory and
#' finalizing validation HTML report. Reduces ~10 lines of boilerplate
#' per orchestrator function.
#'
#' @param validation_context List. Validation context from create_validation_context().
#' @param stage_name Character. Optional stage name for display in report.
#'   Default: NULL (uses workflow from context).
#' @param verbose Logical. Print confirmation message? Default: FALSE.
#' @param output_dir Character. Directory for validation HTML.
#'   Default: "results/validation"
#'
#' @return Character. Path to generated validation HTML file.
#'
#' @section CONTRACT:
#' - Creates output directory if it doesn't exist
#' - Calls finalize_validation_report() or complete_stage_validation()
#' - Returns path to generated HTML file
#' - Prints confirmation if verbose = TRUE
#'
#' @section DOES NOT:
#' - Validate context structure (assumes well-formed)
#' - Open browser to view report
#' - Log to pipeline log (use log_message separately if needed)
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' validation_html_path <- finalize_stage_validation_report(
#'   validation_context,
#'   verbose = TRUE
#' )
#' # Prints: "  [OK] Validation report: validation_cpn_template_20260205.html"
#'
#' # With stage name
#' validation_html_path <- finalize_stage_validation_report(
#'   validation_context,
#'   stage_name = "INGEST & STANDARDIZE",
#'   verbose = TRUE,
#'   output_dir = here::here("results", "validation")
#' )
#' }
#'
#' @export
finalize_stage_validation_report <- function(validation_context,
                                            stage_name = NULL,
                                            verbose = FALSE,
                                            output_dir = "results/validation") {
  
  # Ensure output directory exists
  ensure_dir_exists(output_dir)
  
  # Generate validation HTML report
  # Check if complete_stage_validation exists (newer function)
  if (exists("complete_stage_validation", mode = "function")) {
    validation_html_path <- complete_stage_validation(
      validation_context,
      validation_dir = output_dir,
      stage_name = stage_name,
      verbose = verbose
    )
  } else {
    # Fall back to finalize_validation_report
    validation_html_path <- finalize_validation_report(
      validation_context,
      output_dir = output_dir
    )
  }
  
  # Print confirmation if verbose
  if (verbose && !is.null(validation_html_path)) {
    message(sprintf("  [OK] Validation report: %s", basename(validation_html_path)))
  }
  
  validation_html_path
}
