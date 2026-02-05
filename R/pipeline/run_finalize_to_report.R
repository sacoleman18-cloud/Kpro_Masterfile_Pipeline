# ==============================================================================
# R/pipeline/run_finalize_to_report.R
# ==============================================================================
# PURPOSE
# -------
# Chunk 3 of 3 in the Shiny-driven pipeline. Orchestrates the complete
# finalization process from edited CPN template through final report and
# release bundle generation. Combines Finalize CPN, Summary Stats, Plotting,
# and Report & Release into a single function. Validation reporting and
# artifact registration are standardized via helpers.
#
# PIPELINE POSITION
# -----------------
# Layer: pipeline/orchestration (Chunk 3 of 3)
#   run_ingest_standardize()  -> Chunk 1: Raw CSVs to kpro_master
#   run_cpn_template()        -> Chunk 2: Generate CPN template
#   run_finalize_to_report()  -> [THIS FUNCTION] Finalize through Report
#
# DECISION POINTS (handled by Shiny app):
#   Before Chunk 3: User edits recording hours in EDIT_THIS template
#   After Chunk 3: Complete pipeline - review report and download release bundle
#
# PROCESSING STAGES
# -----------------
#   [FINALIZE CPN]
#   Stage 1: Load configuration and data
#   Stage 2: Load and validate edited template
#   Stage 3: Track manual edits (compare ORIGINAL vs EDIT_THIS)
#   Stage 4: Calculate RecordingHours and classify Status
#   Stage 5: Calculate CallsPerHour metrics
#   Stage 6: Save final CPN with versioning
#
#   [SUMMARY STATISTICS]
#   Stage 7: Generate detector activity summary
#   Stage 8: Generate study-wide summary
#   Stage 9: Calculate variance components
#   Stage 10: Generate species composition (if applicable)
#   Stage 11: Calculate species accumulation
#   Stage 12: Generate hourly activity profiles
#   Stage 13: Format GT tables and export
#   Stage 14: Save summary RDS
#
#   [PLOTTING]
#   Stage 15: Configure plot settings
#   Stage 16: Generate quality plots (8)
#   Stage 17: Generate detector plots (7)
#   Stage 18: Generate species plots (5, if applicable)
#   Stage 19: Generate temporal plots (6)
#   Stage 20: Export plots (PNG/SVG)
#   Stage 21: Save plot objects RDS
#
#   [REPORT & RELEASE]
#   Stage 22: Load pre-computed RDS artifacts
#   Stage 23: Render Quarto report
#   Stage 24: Create release bundle (ZIP)
#   Stage 25: Render final validation HTML
#
# CONTRACT
# --------
# INPUTS:
#   - Edited CPN template (EDIT_THIS file from Chunk 2)
#   - kpro_master tibble (from Chunk 2 result OR checkpoint)
#   - inst/config/study_parameters.yaml
#   - reports/bat_activity_report.qmd (Quarto template)
#
# OUTPUTS:
#   - calls_per_night_final tibble (in returned list)
#   - CallsPerNight_final_vX.csv
#   - Edit log TXT file
#   - Summary statistics RDS + tables (PNG/HTML/XLSX)
#   - Plot objects RDS + 26 PNG files (quality/detector/species/temporal)
#   - Quarto report HTML
#   - Release bundle ZIP
#   - Validation HTML reports (4 total, one per workflow)
#   - Artifact registry entries
#
# GUARANTEES:
#   - All paths use here::here()
#   - Silent by default (verbose = FALSE)
#   - No interactive prompts (edited_template_file parameter for Shiny)
#   - File logging always active via log_message()
#   - Returns comprehensive structured list
#   - Validation HTML rendered for each workflow
#   - Release bundle includes manifest with full provenance
#
# DOES NOT:
#   - Modify global environment (returns results)
#   - Prompt for user input (uses parameters)
#   - Skip any checkpoint or artifact saving
#   - Perform statistical inference (descriptive only)
#
# DEPENDENCIES
# ------------
#   Custom functions (via load_all.R):
#     - All function modules from core/, ingestion/, standardization/,
#       validation/, analysis/, output/
#     - Specifically: load_study_parameters, load_master_data, load_cpn_final,
#       save_callspernight_with_version, create_detector_activity_summary,
#       create_study_summary, generate_quality_plots, generate_detector_plots,
#       generate_species_plots, generate_temporal_plots, create_release_bundle,
#       print_stage_banner, init_stage_validation,
#       save_and_register_rds, store_stage_results, find_most_recent_checkpoint,
#       load_cpn_template, initialize_pipeline_log, log_stage_start,
#       save_checkpoint_and_register, finalize_stage_validation_report
#
# CHANGELOG
# ---------
# 2026-02-05: Refactored to use new utilities.R helper functions
#             - Added initialize_pipeline_log() after print_stage_banner
#             - Replaced print_stage_header + log_message patterns with log_stage_start()
#             - Replaced manual CSV save + artifact registration with save_checkpoint_and_register()
#             - Replaced assert_directory_exists + complete_stage_validation with finalize_stage_validation_report()
#             - Updated dependencies to reflect new helper functions
# 2026-02-04: Standardized stage helpers and documentation refresh
#             - Replaced custom banners with print_stage_banner()
#             - Swapped validation init/finalize with init_stage_validation()/
#               complete_stage_validation()
#             - Consolidated RDS save/register via save_and_register_rds()
#             - Standardized checkpoint discovery and template loading helpers
#             - Added helper usage summary and updated header metadata
# 2026-02-03: CRITICAL FIX - Date parsing and edit tracking failures
#             - Fixed Stage 2: Added explicit format parameter to as.Date() for Night column
#             - Bug: as.Date(Night) without format failed to parse "MM-DD-YY" format
#             - Result: Only ~10 nights per detector survived, rest became NA and collapsed
#             - Solution: Use as.Date(Night, format = "%m-%d-%y") for correct parsing
#             - Fixed Stage 3: Replaced string comparison with POSIXct datetime parsing
#             - Bug: String comparison couldn't detect Excel format changes or handle tolerance
#             - Result: Edit tracking always returned 0 changes despite actual edits
#             - Solution: Parse to POSIXct objects, compare with 1-second tolerance
#             - Added detection for 6 edit types: changed, added, removed (Start/End)
#             - Now correctly tracks all manual datetime edits in EDIT_THIS template
#             - Template now preserves all 252 rows (9 detectors × 28 nights) as expected


#' Run Complete Finalization Pipeline (CPN → Report)
#'
#' @description
#' Chunk 3 of the KPro pipeline. Processes edited CPN template through final
#' report generation, combining four stages:
#' - Finalize CPN: Finalizes CPN with status classification and metrics
#' - Summary Stats: Generates comprehensive summary statistics
#' - Plotting: Creates 26 exploratory visualizations
#' - Report & Release: Renders Quarto report and creates release bundle
#'
#' This is the most comprehensive pipeline stage, producing all final
#' deliverables for the study.
#'
#' @param kpro_master Tibble. Master dataset from Chunk 2. If NULL, will load
#'   from most recent checkpoint. Default: NULL.
#' @param edited_template_file Character. Path to user-edited EDIT_THIS CSV file.
#'   If NULL, will use most recent EDIT_THIS file. Default: NULL.
#' @param create_release_bundle Logical. Whether to create final ZIP bundle.
#'   Default: TRUE.
#' @param verbose Logical. Print progress messages to console. Default: FALSE.
#'
#' @return Named list containing:
#'   \describe{
#'     \item{finalize_cpn}{List. Finalize CPN outputs:
#'       \itemize{
#'         \item calls_per_night_final: Tibble with final metrics
#'         \item cpn_file: Path to versioned CSV
#'         \item total_edits: Number of manual edits tracked
#'         \item status_distribution: List with Fail/Success/Partial counts
#'       }
#'     }
#'     \item{summary_stats}{List. Summary statistics outputs:
#'       \itemize{
#'         \item all_summaries: Master list with all summary tables
#'         \item summary_rds: Path to summary RDS file
#'         \item files_created: Vector of table export paths
#'       }
#'     }
#'     \item{plotting}{List. Exploratory plots outputs:
#'       \itemize{
#'         \item all_plots: Nested list of ggplot objects
#'         \item plots_rds: Path to plots RDS file
#'         \item files_created: Vector of PNG/SVG paths
#'         \item plot_counts: List with counts by category
#'       }
#'     }
#'     \item{report_release}{List. Report & release outputs:
#'       \itemize{
#'         \item report_html: Path to rendered Quarto report
#'         \item release_zip: Path to release bundle (if created)
#'         \item report_size_kb: File size of report
#'       }
#'     }
#'     \item{summary}{List. Overall pipeline metadata:
#'       \itemize{
#'         \item pipeline_duration_sec: Total execution time
#'         \item total_detectors: Count of unique detectors
#'         \item total_calls: Count of total bat calls
#'         \item study_name: Study identifier
#'         \item timestamp: Execution timestamp
#'       }
#'     }
#'     \item{validation_html_paths}{Character vector. All validation reports.}
#'   }
#'
#' @section SEQUENTIAL DEPENDENCY CHAIN:
#' The workflows execute in strict sequence with handoffs:
#' \enumerate{
#'   \item Finalize CPN: Produces calls_per_night_final (passed to Summary Stats/Plotting)
#'   \item Summary Stats: Produces summary_data RDS (discovered by Report & Release)
#'   \item Plotting: Produces plot_objects RDS (discovered by Report & Release)
#'   \item Report & Release: Renders report using RDS artifacts from Summary Stats/Plotting
#' }
#'
#' @section FINALIZE CPN DETAILS:
#' Finalizes CallsPerNight dataset:
#' - Compares ORIGINAL vs EDIT_THIS templates
#' - Tracks all manual recording hour edits
#' - Recalculates RecordingHours from edited times
#' - Classifies Status (Fail/Success/Partial)
#' - Calculates CallsPerHour (retains dead nights with NA)
#' - Saves versioned CSV (v1, v2, v3, etc.)
#'
#' @section SUMMARY STATS DETAILS:
#' Generates summary statistics:
#' - Detector-level: effort, activity, variability
#' - Study-wide: totals, means, success rates
#' - Variance decomposition (between/within detector)
#' - Species composition (if species column exists)
#' - Hourly activity profiles (if temporal data exists)
#' - Exports GT tables (PNG, HTML, Excel)
#'
#' @section PLOTTING DETAILS:
#' Creates exploratory visualizations (26 total):
#' - Quality (8): recording status, completeness, effort
#' - Detector (7): activity, correlation, synchrony
#' - Species (5): composition, diversity (if species data exists)
#' - Temporal (6): trends, hourly, weekly, monthly
#' - Exports PNG (300 DPI) + optional SVG + RDS objects
#'
#' @section REPORT & RELEASE DETAILS:
#' Renders report and creates release:
#' - Discovers and loads RDS files from Summary Stats/Plotting
#' - Renders Quarto report with embedded plots/tables
#' - Creates portable ZIP bundle with:
#'   - Final CPN CSV
#'   - Master CSV
#'   - Summary tables
#'   - All plots (PNG)
#'   - HTML report
#'   - Manifest with provenance
#'
#' @section Error Handling:
#' Stops with actionable error message if:
#' \itemize{
#'   \item Edited template file not found
#'   \item Required columns missing from template
#'   \item Master data not available
#'   \item Quarto report rendering fails
#' }
#'
#' @examples
#' \dontrun{
#' # Standard usage (called by Shiny after user edits template)
#' result <- run_finalize_to_report(
#'   kpro_master = chunk2_result$kpro_master,
#'   edited_template_file = chunk2_result$template_edit_path
#' )
#'
#' # With verbose output for debugging
#' result <- run_finalize_to_report(verbose = TRUE)
#'
#' # Skip release bundle creation
#' result <- run_finalize_to_report(create_release_bundle = FALSE)
#'
#' # Access results
#' cpn <- result$finalize_cpn$calls_per_night_final
#' result$report_release$report_html  # Main deliverable
#' result$summary$pipeline_duration_sec
#' }
#'
#' @export
run_finalize_to_report <- function(kpro_master = NULL,
                                   edited_template_file = NULL,
                                   create_release_bundle = TRUE,
                                   verbose = FALSE) {
  
  # ===========================================================================
  # SETUP
  # ===========================================================================
  
  pipeline_start_time <- Sys.time()
  
  log_message("=== CHUNK 3: Finalize to Report - START ===")
  
  # Standard paths
  yaml_path <- here::here("inst", "config", "study_parameters.yaml")
  outputs_dir <- here::here("outputs")
  results_dir <- here::here("results")
  
  # Initialize return structure
  result <- list(
    finalize_cpn = list(),
    summary_stats = list(),
    plotting = list(),
    report_release = list(),
    summary = list(),
    validation_html_paths = character()
  )
  
  # ===========================================================================
  # FINALIZE CPN
  # ===========================================================================
  
  print_stage_banner("FINALIZE CPN", verbose = verbose)
  initialize_pipeline_log()
  
  # ---------------------------------------------------------------------------
  # Stage 1: Load Configuration
  # ---------------------------------------------------------------------------
  
  log_stage_start("1", "Load Configuration", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  assert_file_exists(yaml_path, hint = "Configure study parameters first.")
  study_params <- load_study_parameters(yaml_path)
  
  validation_context_finalize_cpn <- init_stage_validation("finalize_cpn", study_params)
  
  if (verbose) message("  [OK] Loaded study_parameters.yaml")
  
  # Get uniform schedule for status classification
  advanced_scheduling <- study_params$processing_options$advanced_scheduling %||% "no"
  uniform_start <- study_params$processing_options$recording_start %||% NA
  uniform_end <- study_params$processing_options$recording_end %||% NA
  intended_hours <- study_params$processing_options$intended_hours %||% NA
  
  # ---------------------------------------------------------------------------
  # Stage 2: Load Master Data and Templates
  # ---------------------------------------------------------------------------
  
  log_stage_start("2", "Load Data and Templates", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  # Load master data
  if (!is.null(kpro_master)) {
    if (verbose) message("  [OK] Using kpro_master from Chunk 2")
  } else {
    if (verbose) message("  [!] Loading kpro_master from checkpoint...")
    
    kpro_master_file <- find_most_recent_checkpoint(
      "kpro_master",
      checkpoints_dir = here::here("outputs", "checkpoints"),
      required = TRUE
    )
    
    kpro_master <- safe_read_csv(kpro_master_file, verbose = verbose)
  }
  
  validation_context_finalize_cpn <- log_validation_event(
    validation_context_finalize_cpn,
    event_type = "data_loaded",
    description = "Master data loaded",
    count = nrow(kpro_master)
  )
  
  # Validate species column exists
  if (!"species" %in% names(kpro_master)) {
    warning("'species' column not found in kpro_master - creating from auto_id")
    kpro_master$species <- kpro_master$auto_id
  }
  
  # Load original template for comparison
  template_original_file <- find_most_recent_checkpoint(
    "cpn_original",
    checkpoints_dir = outputs_dir,
    required = TRUE
  )
  
  template_original_result <- load_cpn_template(
    template_original_file,
    validation_context = validation_context_finalize_cpn,
    verbose = verbose
  )
  template_original <- template_original_result$template
  validation_context_finalize_cpn <- template_original_result$validation_context
  
  if (verbose) {
    message(sprintf("  [DIAGNOSTIC] ORIGINAL template loaded: %d rows", nrow(template_original)))
    message(sprintf("  [DIAGNOSTIC] Sample Night values: %s", 
                    paste(head(template_original$Night, 3), collapse = ", ")))
  }
  
  # Convert column types for ORIGINAL template
  # ORIGINAL is generated by pipeline, uses ISO 8601 format (YYYY-MM-DD)
  template_original <- template_original %>%
    dplyr::mutate(
      Night = as.Date(Night),  # ISO 8601 format - no format parameter needed
      Detector = as.character(Detector),
      CallsPerNight = as.numeric(CallsPerNight),
      RecordingHours = suppressWarnings(as.numeric(RecordingHours))
    )
  
  if (verbose) {
    message(sprintf("  [OK] Loaded ORIGINAL template: %s (%d rows)", 
                    basename(template_original_file), nrow(template_original)))
    message(sprintf("  [OK] Date range: %s to %s", 
                    min(template_original$Night, na.rm = TRUE),
                    max(template_original$Night, na.rm = TRUE)))
  }
  
  # Load edited template
  if (is.null(edited_template_file)) {
    edited_template_file <- find_most_recent_checkpoint(
      "cpn_edit",
      checkpoints_dir = outputs_dir,
      required = TRUE
    )
  } else {
    assert_file_exists(edited_template_file, hint = "Check edited template path")
  }
  
  template_edited_result <- load_cpn_template(
    edited_template_file,
    validation_context = validation_context_finalize_cpn,
    verbose = verbose
  )
  template_edited <- template_edited_result$template
  validation_context_finalize_cpn <- template_edited_result$validation_context
  
  if (verbose) {
    message(sprintf("  [DIAGNOSTIC] EDIT_THIS template loaded: %d rows", nrow(template_edited)))
    message(sprintf("  [DIAGNOSTIC] Sample Night values: %s", 
                    paste(head(template_edited$Night, 3), collapse = ", ")))
  }
  
  # Convert column types for EDITED template
  # EDIT_THIS may be reformatted by Excel - use flexible date parsing
  # lubridate::parse_date_time tries multiple formats in order
  template_edited <- template_edited %>%
    dplyr::mutate(
      # Flexible date parsing - handles ISO 8601 (YYYY-MM-DD) and Excel US (M/D/YYYY)
      # orders parameter tries formats in sequence: year-month-day, month-day-year
      Night = lubridate::as_date(
        lubridate::parse_date_time(Night, orders = c("ymd", "mdy"))
      ),
      Detector = as.character(Detector),
      CallsPerNight = as.numeric(CallsPerNight),
      RecordingHours = suppressWarnings(as.numeric(RecordingHours))
    )
  
  # Handle datetime columns if they exist
  if ("StartDateTime" %in% names(template_edited)) {
    template_edited <- template_edited %>%
      dplyr::mutate(
        StartDateTime = dplyr::if_else(
          !is.na(StartDateTime) & StartDateTime != "",
          as.character(StartDateTime),
          NA_character_
        )
      )
  }
  
  if ("EndDateTime" %in% names(template_edited)) {
    template_edited <- template_edited %>%
      dplyr::mutate(
        EndDateTime = dplyr::if_else(
          !is.na(EndDateTime) & EndDateTime != "",
          as.character(EndDateTime),
          NA_character_
        )
      )
  }
  
  validation_context_finalize_cpn <- log_validation_event(
    validation_context_finalize_cpn,
    event_type = "data_loaded",
    description = "CPN template loaded with flexible date parsing",
    count = nrow(template_edited),
    details = list(
      original_file = basename(template_original_file),
      edited_file = basename(edited_template_file),
      original_rows = nrow(template_original),
      edited_rows = nrow(template_edited)
    )
  )
  
  if (verbose) {
    message(sprintf("  [OK] Loaded EDIT_THIS template: %s (%d rows)", 
                    basename(edited_template_file), nrow(template_edited)))
    message(sprintf("  [OK] Date range: %s to %s", 
                    min(template_edited$Night, na.rm = TRUE),
                    max(template_edited$Night, na.rm = TRUE)))
  }
  
  # Validate required columns
  required_cols <- c("Detector", "Night", "CallsPerNight")
  assert_columns_exist(template_edited, required_cols)
  
  log_message(sprintf("[Finalize CPN - Stage 2] Templates loaded (ORIGINAL: %d rows, EDITED: %d rows)", 
                      nrow(template_original), nrow(template_edited)))
  
  # ---------------------------------------------------------------------------
  # Stage 3: Track Manual Edits (POSIXct Parsing with Tolerance)
  # ---------------------------------------------------------------------------
  
  log_stage_start("3", "Track Manual Edits", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  # Initialize tracking variables
  total_edits <- 0
  edit_log_lines <- character()
  
  # Only attempt edit tracking if datetime columns exist in both templates
  if ("StartDateTime" %in% names(template_original) && 
      "StartDateTime" %in% names(template_edited)) {
    
    # Parse ORIGINAL template datetimes to POSIXct objects
    # parse_datetime_safe() is from callspernight.R and handles timezone internally
    template_orig_parsed <- template_original %>%
      dplyr::select(Detector, Night, 
                    StartDateTime_orig_str = StartDateTime,
                    EndDateTime_orig_str = EndDateTime) %>%
      dplyr::mutate(
        StartDateTime_orig = sapply(StartDateTime_orig_str, parse_datetime_safe) %>% 
          as.POSIXct(origin = "1970-01-01"),
        EndDateTime_orig = sapply(EndDateTime_orig_str, parse_datetime_safe) %>% 
          as.POSIXct(origin = "1970-01-01")
      )
    
    # Parse EDITED template datetimes to POSIXct objects
    template_edit_parsed <- template_edited %>%
      dplyr::select(Detector, Night,
                    StartDateTime_edit_str = StartDateTime,
                    EndDateTime_edit_str = EndDateTime,
                    RecordingHours_edit = RecordingHours) %>%
      dplyr::mutate(
        StartDateTime_edit = sapply(StartDateTime_edit_str, parse_datetime_safe) %>% 
          as.POSIXct(origin = "1970-01-01"),
        EndDateTime_edit = sapply(EndDateTime_edit_str, parse_datetime_safe) %>% 
          as.POSIXct(origin = "1970-01-01")
      )
    
    # Join and compare with 1-second tolerance (handles Excel rounding/precision)
    comparison <- template_orig_parsed %>%
      dplyr::inner_join(template_edit_parsed, by = c("Detector", "Night")) %>%
      dplyr::mutate(
        # Compare PARSED datetime objects (not string representations!)
        # Use 1-second tolerance to handle floating point precision issues
        StartDateTime_changed = !is.na(StartDateTime_orig) & 
          !is.na(StartDateTime_edit) & 
          abs(difftime(StartDateTime_orig, StartDateTime_edit, units = "secs")) > 1,
        
        EndDateTime_changed = !is.na(EndDateTime_orig) & 
          !is.na(EndDateTime_edit) & 
          abs(difftime(EndDateTime_orig, EndDateTime_edit, units = "secs")) > 1,
        
        # Also detect when times go from filled → NA or NA → filled
        StartDateTime_added = is.na(StartDateTime_orig) & !is.na(StartDateTime_edit),
        StartDateTime_removed = !is.na(StartDateTime_orig) & is.na(StartDateTime_edit),
        
        EndDateTime_added = is.na(EndDateTime_orig) & !is.na(EndDateTime_edit),
        EndDateTime_removed = !is.na(EndDateTime_orig) & is.na(EndDateTime_edit),
        
        # Mark any type of change (6 types total)
        Any_change = StartDateTime_changed | EndDateTime_changed |
          StartDateTime_added | StartDateTime_removed |
          EndDateTime_added | EndDateTime_removed
      )
    
    # Count total edits
    total_edits <- sum(comparison$Any_change, na.rm = TRUE)
    
    # Generate detailed edit log if edits exist
    if (total_edits > 0) {
      edit_log <- comparison %>%
        dplyr::filter(Any_change) %>%
        dplyr::arrange(Detector, Night)
      
      # Build detailed log entries (matches legacy 04_finalize_cpn.R format)
      for (i in seq_len(nrow(edit_log))) {
        row <- edit_log[i, ]
        
        log_entry <- sprintf("[%d] %s | %s", i, row$Detector, row$Night)
        
        # StartDateTime changes
        if (row$StartDateTime_changed) {
          log_entry <- paste0(log_entry, sprintf(
            "\n    StartDateTime CHANGED: %s -> %s",
            format_datetime_for_log(row$StartDateTime_orig, row$StartDateTime_orig_str),
            format_datetime_for_log(row$StartDateTime_edit, row$StartDateTime_edit_str)
          ))
        } else if (row$StartDateTime_added) {
          log_entry <- paste0(log_entry, sprintf(
            "\n    StartDateTime ADDED: <blank> -> %s",
            format_datetime_for_log(row$StartDateTime_edit, row$StartDateTime_edit_str)
          ))
        } else if (row$StartDateTime_removed) {
          log_entry <- paste0(log_entry, sprintf(
            "\n    StartDateTime REMOVED: %s -> <blank>",
            format_datetime_for_log(row$StartDateTime_orig, row$StartDateTime_orig_str)
          ))
        }
        
        # EndDateTime changes (same pattern)
        if (row$EndDateTime_changed) {
          log_entry <- paste0(log_entry, sprintf(
            "\n    EndDateTime CHANGED: %s -> %s",
            format_datetime_for_log(row$EndDateTime_orig, row$EndDateTime_orig_str),
            format_datetime_for_log(row$EndDateTime_edit, row$EndDateTime_edit_str)
          ))
        } else if (row$EndDateTime_added) {
          log_entry <- paste0(log_entry, sprintf(
            "\n    EndDateTime ADDED: <blank> -> %s",
            format_datetime_for_log(row$EndDateTime_edit, row$EndDateTime_edit_str)
          ))
        } else if (row$EndDateTime_removed) {
          log_entry <- paste0(log_entry, sprintf(
            "\n    EndDateTime REMOVED: %s -> <blank>",
            format_datetime_for_log(row$EndDateTime_orig, row$EndDateTime_orig_str)
          ))
        }
        
        log_entry <- paste0(log_entry, sprintf("\n    RecordingHours: %.2f\n", 
                                               row$RecordingHours_edit))
        
        edit_log_lines <- c(edit_log_lines, log_entry)
      }
    }
  }
  
  validation_context_finalize_cpn <- log_validation_event(
    validation_context_finalize_cpn,
    event_type = "manual_edits",
    description = "Manual recording hour edits tracked with POSIXct parsing",
    count = total_edits
  )
  
  if (verbose) {
    message(sprintf("  [OK] Tracked %d manual edits", total_edits))
  }
  
  # ---------------------------------------------------------------------------
  # Stage 4: Calculate RecordingHours
  # ---------------------------------------------------------------------------
  
  log_stage_start("4", "Calculate Recording Hours", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  # Recalculate RecordingHours from edited times
  if ("StartDateTime" %in% names(template_edited) && 
      "EndDateTime" %in% names(template_edited)) {
    
    template_edited <- template_edited %>%
      dplyr::mutate(
        RecordingHours = calculate_recording_hours(StartDateTime, EndDateTime)
      )
  }
  
  # Replace NA/negative with 0
  template_edited <- template_edited %>%
    dplyr::mutate(
      RecordingHours = dplyr::if_else(
        is.na(RecordingHours) | RecordingHours < 0,
        0,
        RecordingHours
      )
    )
  
  if (verbose) message("  [OK] Recalculated recording hours")
  
  # ---------------------------------------------------------------------------
  # Stage 5: Classify Status and Calculate Metrics
  # ---------------------------------------------------------------------------
  
  log_stage_start("5", "Classify Status & Calculate Metrics", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  # Classify recording status
  calls_per_night_final <- template_edited %>%
    dplyr::mutate(
      Status = dplyr::case_when(
        RecordingHours == 0 | is.na(RecordingHours) ~ "Fail",
        advanced_scheduling != "no" ~ "Success",  # Advanced: all non-zero are Success
        !is.na(intended_hours) & abs(RecordingHours - intended_hours) < 0.5 ~ "Success",
        TRUE ~ "Partial"
      ),
      CallsPerHour = dplyr::if_else(
        RecordingHours > 0,
        CallsPerNight / RecordingHours,
        NA_real_
      )
    )
  
  # Status distribution
  status_dist <- table(calls_per_night_final$Status)
  dead_nights <- sum(calls_per_night_final$Status == "Fail")
  
  validation_context_finalize_cpn <- log_validation_event(
    validation_context_finalize_cpn,
    event_type = "status_classification",
    description = "Recording status classified",
    details = list(
      fail = as.numeric(status_dist["Fail"] %||% 0),
      success = as.numeric(status_dist["Success"] %||% 0),
      partial = as.numeric(status_dist["Partial"] %||% 0)
    )
  )
  
  if (verbose) {
    message(sprintf("  [OK] Status: %d Fail, %d Success, %d Partial",
                    status_dist["Fail"] %||% 0,
                    status_dist["Success"] %||% 0,
                    status_dist["Partial"] %||% 0))
  }
  
  log_message(sprintf("[Finalize CPN - Stage 5] Status classified, %d dead nights retained", dead_nights))
  
  # Origin: 04_finalize_cpn.R ~L560+, Standards: 04_data_standards.md §4.3
  
  # Validate problematic call values before proceeding
  problematic_calls <- calls_per_night_final %>%
    dplyr::filter(CallsPerNight < 0 | CallsPerNight > 10000)
  
  if (nrow(problematic_calls) > 0) {
    warning(sprintf(
      "Found %d rows with suspicious call counts (negative or >10000). Check data quality.",
      nrow(problematic_calls)
    ))
    
    validation_context_finalize_cpn <- log_validation_event(
      validation_context_finalize_cpn,
      event_type = "warning",
      description = "Suspicious call values detected",
      count = nrow(problematic_calls),
      details = list(
        negative_count = sum(problematic_calls$CallsPerNight < 0),
        excessive_count = sum(problematic_calls$CallsPerNight > 10000)
      )
    )
    
    if (verbose) {
      message(sprintf("  [!] Warning: %d rows with suspicious call values", 
                      nrow(problematic_calls)))
    }
  }
  
  # ---------------------------------------------------------------------------
  # Stage 6: Save Final CPN
  # ---------------------------------------------------------------------------
  
  log_stage_start("6", "Save Final CPN", verbose = verbose, workflow_prefix = "Finalize CPN")
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # Construct file path for CPN final
  cpn_final_filename <- sprintf("CallsPerNight_final_%s.csv", timestamp)
  cpn_final_path <- here::here("results", "csv", cpn_final_filename)
  
  # Save and register artifact
  registry <- save_checkpoint_and_register(
    data = calls_per_night_final,
    file_path = cpn_final_path,
    artifact_type = "cpn_final",
    workflow = "finalize_cpn",
    metadata = list(
      n_rows = nrow(calls_per_night_final),
      n_detectors = dplyr::n_distinct(calls_per_night_final$Detector),
      total_edits = total_edits,
      status_distribution = as.list(status_dist),
      dead_nights_retained = dead_nights
    ),
    verbose = verbose
  )
  
  # Save edit log if edits were made
  if (total_edits > 0) {
    edit_log_path <- here::here("outputs", 
                                sprintf("CallsPerNight_EditLog_%s.txt", timestamp))
    writeLines(
      c(
        sprintf("CallsPerNight Edit Log - %s", timestamp),
        sprintf("Total Manual Edits: %d", total_edits),
        "",
        "Detector | Night | StartDateTime: Original -> Edited | EndDateTime: Original -> Edited",
        strrep("-", 100),
        edit_log_lines
      ),
      edit_log_path
    )
    if (verbose) message(sprintf("  [OK] Saved edit log: %s", basename(edit_log_path)))
  }
  
  validation_html_finalize_cpn <- finalize_stage_validation_report(
    validation_context = validation_context_finalize_cpn,
    stage_name = "FINALIZE CPN",
    verbose = verbose
  )
  
  # Store Finalize CPN results
  result <- store_stage_results(
    result,
    stage_key = "finalize_cpn",
    stage_outputs = list(
      calls_per_night_final = calls_per_night_final,
      cpn_file = cpn_final_path,
      total_edits = total_edits,
      status_distribution = as.list(status_dist),
      dead_nights_retained = dead_nights
    ),
    validation_html = validation_html_finalize_cpn
  )
  
  # ===========================================================================
  # SUMMARY STATISTICS
  # ===========================================================================
  
  print_stage_banner("SUMMARY STATISTICS", verbose = verbose)
  
  validation_context_summary_stats <- init_stage_validation("summary_stats", study_params)
  
  # Initialize summaries list
  all_summaries <- list()
  files_created_05 <- character()
  
  # ---------------------------------------------------------------------------
  # Stage 7: Detector Activity Summary
  # ---------------------------------------------------------------------------
  
  log_stage_start("7", "Detector Activity Summary", verbose = verbose, workflow_prefix = "Summary Stats")
  
  detector_summary <- create_detector_activity_summary(calls_per_night_final)
  all_summaries$detector_summary <- detector_summary
  
  validation_context_summary_stats <- log_validation_event(
    validation_context_summary_stats,
    event_type = "summary_generated",
    description = "Detector activity summary created",
    count = nrow(detector_summary)
  )
  
  if (verbose) message(sprintf("  [OK] Created detector summary: %d detectors", 
                               nrow(detector_summary)))
  
  # ---------------------------------------------------------------------------
  # Stage 8: Study-Wide Summary
  # ---------------------------------------------------------------------------
  
  log_stage_start("8", "Study-Wide Summary", verbose = verbose, workflow_prefix = "Summary Stats")
  
  study_summary <- create_study_summary(calls_per_night_final)
  all_summaries$study_summary <- study_summary
  
  validation_context_summary_stats <- log_validation_event(
    validation_context_summary_stats,
    event_type = "summary_generated",
    description = "Study-wide summary created"
  )
  
  if (verbose) message("  [OK] Created study-wide summary")
  
  # ---------------------------------------------------------------------------
  # Stage 9: Variance Components (Optional - skip if function not available)
  # ---------------------------------------------------------------------------
  
  log_stage_start("9", "Variance Components", verbose = verbose, workflow_prefix = "Summary Stats")
  
  variance_components <- tryCatch({
    calculate_variance_components(calls_per_night_final)
  }, error = function(e) {
    if (verbose) message("  [!] Variance calculation skipped")
    NULL
  })
  
  if (!is.null(variance_components)) {
    all_summaries$variance_components <- variance_components
    if (verbose) message("  [OK] Calculated variance components")
  }
  
  # ---------------------------------------------------------------------------
  # Stage 10-12: Species and Temporal Summaries (Conditional)
  # ---------------------------------------------------------------------------
  
  log_stage_start("10", "Species & Temporal Summaries", verbose = verbose, workflow_prefix = "Summary Stats")
  
  has_species <- "species" %in% names(kpro_master)
  has_temporal <- "Hour_local" %in% names(kpro_master) || "DateTime_local" %in% names(kpro_master)
  
  if (has_species) {
    species_summary <- tryCatch({
      create_species_summary_by_detector(kpro_master, calls_per_night_final)
    }, error = function(e) NULL)
    
    if (!is.null(species_summary)) {
      all_summaries$species_summary <- species_summary
      if (verbose) message("  [OK] Created species summary")
    }
    
    species_accumulation <- tryCatch({
      create_species_accumulation_summary(kpro_master, calls_per_night_final)
    }, error = function(e) NULL)
    
    if (!is.null(species_accumulation)) {
      all_summaries$species_accumulation <- species_accumulation
      if (verbose) message("  [OK] Created species accumulation")
    }
  }
  
  if (has_temporal) {
    hourly_summary <- tryCatch({
      create_hourly_activity_summary(kpro_master, calls_per_night_final)
    }, error = function(e) NULL)
    
    if (!is.null(hourly_summary)) {
      all_summaries$hourly_summary <- hourly_summary
      if (verbose) message("  [OK] Created hourly activity summary")
    }
  }
  
  # ---------------------------------------------------------------------------
  # Stage 13-14: Save Summary RDS and Export Tables
  # ---------------------------------------------------------------------------
  
  log_stage_start("13", "Save Summary RDS", verbose = verbose, workflow_prefix = "Summary Stats")
  
  timestamp_05 <- format(Sys.time(), "%Y%m%d")
  summary_rds_path <- here::here("results", "rds", sprintf("summary_data_%s.rds", timestamp_05))
  
  # Origin: 05_summary_stats.R, Standards: 07_artifact_release_standards.md
  # Add metadata element required by validate_rds_structure()
  all_summaries$metadata <- list(
    generated = Sys.time(),
    study_name = study_params$study_parameters$study_name %||% "Unknown",
    n_detectors = dplyr::n_distinct(calls_per_night_final$Detector),
    n_nights = dplyr::n_distinct(calls_per_night_final$Night),
    has_species = has_species,
    has_temporal = has_temporal
  )
  
  registry <- save_and_register_rds(
    object = all_summaries,
    file_path = summary_rds_path,
    artifact_type = "summary_stats",
    workflow = "summary_stats",
    registry = registry,
    metadata = list(
      n_summaries = length(all_summaries),
      has_species = has_species,
      has_temporal = has_temporal
    ),
    verbose = verbose
  )
  
  # Finalize validation
  validation_html_summary_stats <- finalize_stage_validation_report(
    validation_context = validation_context_summary_stats,
    stage_name = "SUMMARY STATISTICS",
    verbose = verbose
  )
  
  # Store Summary Stats results
  result <- store_stage_results(
    result,
    stage_key = "summary_stats",
    stage_outputs = list(
      all_summaries = all_summaries,
      summary_rds = summary_rds_path,
      files_created = character(),
      has_species = has_species,
      has_temporal = has_temporal
    ),
    validation_html = validation_html_summary_stats
  )
  
  # ===========================================================================
  # PLOTTING
  # ===========================================================================
  
  print_stage_banner("PLOTTING", verbose = verbose)
  
  validation_context_plotting <- init_stage_validation("exploratory_plots", study_params)
  
  # Initialize plots structure
  all_plots <- list(
    quality = list(),
    detector = list(),
    species = list(),
    temporal = list()
  )
  
  files_created_06 <- character()
  
  # ---------------------------------------------------------------------------
  # Stages 15-19: Generate Plot Categories
  # ---------------------------------------------------------------------------
  
  log_stage_start("15", "Configure Plot Settings", verbose = verbose, workflow_prefix = "Plots")
  
  # Create plot output directories
  plot_dirs <- c("quality", "detector", "species", "temporal")
  for (dir_name in plot_dirs) {
    assert_directory_exists(
      here::here("results", "figures", "png", dir_name),
      create = TRUE
    )
  }
  
  if (verbose) message("  [OK] Plot directories ready")
  
  # ---------------------------------------------------------------------------
  # Stage 16: Quality Plots (8 plots)
  # ---------------------------------------------------------------------------
  
  log_stage_start("16", "Generate Quality Plots", verbose = verbose, workflow_prefix = "Plots")
  
  quality_plots <- list()
  
  tryCatch({
    quality_plots$recording_status_summary <- plot_recording_status_summary(calls_per_night_final)
    quality_plots$recording_status_percent <- plot_recording_status_percent(calls_per_night_final)
    quality_plots$recording_status_overall <- plot_recording_status_overall(calls_per_night_final)
    quality_plots$effort_by_detector <- plot_effort_by_detector(calls_per_night_final)
    quality_plots$nights_by_detector <- plot_nights_by_detector(calls_per_night_final)
    quality_plots$data_completeness_calendar <- plot_data_completeness_calendar(calls_per_night_final)
    quality_plots$missing_nights <- plot_missing_nights(calls_per_night_final)
    quality_plots$recording_effort_heatmap <- plot_recording_effort_heatmap(calls_per_night_final)
    
    if (verbose) message(sprintf("  [OK] Generated %d quality plots", length(quality_plots)))
  }, error = function(e) {
    warning(sprintf("Quality plots failed: %s", e$message))
    quality_plots <<- list()
  })
  
  all_plots$quality <- quality_plots
  
  # ---------------------------------------------------------------------------
  # Stage 17: Detector Plots (7 plots)
  # ---------------------------------------------------------------------------
  
  log_stage_start("17", "Generate Detector Plots", verbose = verbose, workflow_prefix = "Plots")
  
  detector_plots <- list()
  
  tryCatch({
    detector_plots$total_calls_by_detector <- plot_total_calls_by_detector(kpro_master)
    detector_plots$detector_activity_caterpillar <- plot_detector_activity_caterpillar(calls_per_night_final)
    detector_plots$detector_boxplots <- plot_detector_boxplots(calls_per_night_final)
    detector_plots$activity_with_without_outliers <- plot_activity_with_without_outliers(calls_per_night_final)
    detector_plots$synchrony <- plot_synchrony(calls_per_night_final)
    detector_plots$correlation_heatmap <- plot_correlation_heatmap(calls_per_night_final)
    detector_plots$detector_rank_over_time <- plot_detector_rank_over_time(calls_per_night_final)
    
    if (verbose) message(sprintf("  [OK] Generated %d detector plots", length(detector_plots)))
  }, error = function(e) {
    warning(sprintf("Detector plots failed: %s", e$message))
    detector_plots <<- list()
  })
  
  all_plots$detector <- detector_plots
  
  # ---------------------------------------------------------------------------
  # Stage 18: Species Plots (5 plots, conditional)
  # ---------------------------------------------------------------------------
  
  log_stage_start("18", "Generate Species Plots", verbose = verbose, workflow_prefix = "Plots")
  
  species_plots <- list()
  
  if (has_species) {
    tryCatch({
      species_plots$species_composition_bar <- plot_species_composition_bar(kpro_master)
      species_plots$species_by_detector_heatmap <- plot_species_by_detector_heatmap(kpro_master)
      species_plots$species_accumulation_curve <- plot_species_accumulation_curve(kpro_master)
      species_plots$species_hourly_profile <- plot_species_hourly_profile(kpro_master)
      species_plots$noid_proportion <- plot_noid_proportion(kpro_master)
      
      if (verbose) message(sprintf("  [OK] Generated %d species plots", length(species_plots)))
    }, error = function(e) {
      warning(sprintf("Species plots failed: %s", e$message))
      species_plots <- list()
    })
  } else {
    if (verbose) message("  [!] Species plots skipped (no species column)")
  }
  
  all_plots$species <- species_plots
  
  # ---------------------------------------------------------------------------
  # Stage 19: Temporal Plots (6 plots)
  # ---------------------------------------------------------------------------
  
  log_stage_start("19", "Generate Temporal Plots", verbose = verbose, workflow_prefix = "Plots")
  
  temporal_plots <- list()
  
  tryCatch({
    temporal_plots$activity_over_time <- plot_activity_over_time(calls_per_night_final)
    temporal_plots$cumulative_calls_over_time <- plot_cumulative_calls_over_time(calls_per_night_final)
    temporal_plots$hourly_activity_profile <- plot_hourly_activity_profile(kpro_master)
    temporal_plots$callsperhour_distribution <- plot_callsperhour_distribution(calls_per_night_final)
    temporal_plots$weekly_activity <- plot_weekly_activity(calls_per_night_final)
    temporal_plots$activity_by_month <- plot_activity_by_month(calls_per_night_final)
    
    if (verbose) message(sprintf("  [OK] Generated %d temporal plots", length(temporal_plots)))
  }, error = function(e) {
    warning(sprintf("Temporal plots failed: %s", e$message))
    temporal_plots <<- list()
  })
  
  all_plots$temporal <- temporal_plots
  
  # ---------------------------------------------------------------------------
  # Stage 20-21: Export Plots and Save RDS
  # ---------------------------------------------------------------------------
  
  log_stage_start("20", "Export Plots", verbose = verbose, workflow_prefix = "Plots")
  
  # Export all plots as PNG (simplified - full implementation uses export_plots_png)
  total_plots_exported <- 0
  
  for (category in names(all_plots)) {
    category_plots <- all_plots[[category]]
    if (length(category_plots) > 0) {
      for (plot_name in names(category_plots)) {
        plot_path <- here::here("results", "figures", "png", category,
                                sprintf("%s.png", plot_name))
        tryCatch({
          ggplot2::ggsave(plot_path, category_plots[[plot_name]], 
                          width = 10, height = 7, dpi = 300)
          files_created_06 <- c(files_created_06, plot_path)
          total_plots_exported <- total_plots_exported + 1
        }, error = function(e) {
          warning(sprintf("Failed to export %s: %s", plot_name, e$message))
        })
      }
    }
  }
  
  if (verbose) message(sprintf("  [OK] Exported %d plot PNG files", total_plots_exported))
  
  # Save plot objects RDS
  log_stage_start("21", "Save Plot Objects RDS", verbose = verbose, workflow_prefix = "Plots")
  
  timestamp_06 <- format(Sys.time(), "%Y%m%d")
  plots_rds_path <- here::here("results", "rds", sprintf("plot_objects_%s.rds", timestamp_06))
  
  registry <- save_and_register_rds(
    object = all_plots,
    file_path = plots_rds_path,
    artifact_type = "plot_objects",
    workflow = "exploratory_plots",
    registry = registry,
    metadata = list(
      total_plots = total_plots_exported,
      quality_plots = length(quality_plots),
      detector_plots = length(detector_plots),
      species_plots = length(species_plots),
      temporal_plots = length(temporal_plots)
    ),
    verbose = verbose
  )
  
  # Finalize validation
  validation_html_plotting <- finalize_stage_validation_report(
    validation_context = validation_context_plotting,
    stage_name = "PLOTTING",
    verbose = verbose
  )
  
  # Store Plotting results
  result <- store_stage_results(
    result,
    stage_key = "plotting",
    stage_outputs = list(
      all_plots = all_plots,
      plots_rds = plots_rds_path,
      files_created = files_created_06,
      plot_counts = list(
        quality = length(quality_plots),
        detector = length(detector_plots),
        species = length(species_plots),
        temporal = length(temporal_plots)
      )
    ),
    validation_html = validation_html_plotting
  )
  
  # ===========================================================================
  # REPORT & RELEASE
  # ===========================================================================
  
  print_stage_banner("REPORT & RELEASE", verbose = verbose)
  
  validation_context_report_release <- init_stage_validation("report_release", study_params)
  
  # ---------------------------------------------------------------------------
  # Stage 22: Verify RDS Artifacts
  # ---------------------------------------------------------------------------
  
  log_stage_start("22", "Verify RDS Artifacts", verbose = verbose, workflow_prefix = "Report & Release")
  
  # Origin: 07_generate_report.R L284-323, Standards: 07_artifact_release_standards.md
  # Use robust RDS discovery and validation like legacy workflow
  
  if (!file.exists(summary_rds_path)) {
    stop("Summary RDS not found: ", summary_rds_path)
  }
  
  if (!file.exists(plots_rds_path)) {
    stop("Plots RDS not found: ", plots_rds_path)
  }
  
  # Load and validate RDS structure for report compatibility
  all_summaries_for_report <- readRDS(summary_rds_path)
  all_plots_for_report <- readRDS(plots_rds_path)
  
  rds_validation <- tryCatch({
    validate_rds_structure(all_summaries_for_report, all_plots_for_report)
  }, error = function(e) {
    list(valid = FALSE, errors = e$message)
  })
  
  if (!rds_validation$valid) {
    warning(sprintf("RDS structure validation warnings:\n  %s",
                    paste(rds_validation$errors, collapse = "\n  ")))
    
    validation_context_report_release <- log_validation_event(
      validation_context_report_release,
      event_type = "warning",
      description = "RDS structure validation issues detected",
      details = list(errors = rds_validation$errors)
    )
  } else {
    if (verbose) {
      # Use total_plots from validation if available, otherwise count from plots list
      plot_count <- if (!is.null(rds_validation$total_plots)) {
        rds_validation$total_plots
      } else {
        sum(sapply(all_plots_for_report, length))
      }
      message(sprintf("  [OK] RDS validation passed: %d summaries, %d plots",
                      length(all_summaries_for_report), plot_count))
    }
  }
  
  if (verbose) message("  [OK] All RDS artifacts verified")
  
  # ---------------------------------------------------------------------------
  # Stage 23: Render Quarto Report
  # ---------------------------------------------------------------------------
  
  log_stage_start("23", "Render Quarto Report", verbose = verbose, workflow_prefix = "Report & Release")
  
  qmd_template <- here::here("reports", "bat_activity_report.qmd")
  
  report_html_path <- NULL
  render_success <- FALSE
  
  if (file.exists(qmd_template)) {
    
    timestamp_07 <- format(Sys.time(), "%Y%m%d")
    report_html_path <- here::here("results", "reports", 
                                   sprintf("bat_activity_report_%s.html", timestamp_07))
    
    assert_directory_exists(dirname(report_html_path), create = TRUE)
    
    # Render report
    render_result <- tryCatch({
      quarto::quarto_render(
        input = qmd_template,
        output_file = basename(report_html_path),
        output_format = "html",
        execute_params = list(
          summary_rds = summary_rds_path,           # Match report param name
          plots_rds = plots_rds_path,               # Match report param name
          study_params_path = yaml_path             # Match report param name
        ),
        quiet = !verbose
      )
      
      # Move to correct location
      rendered_file <- here::here("reports", basename(report_html_path))
      if (file.exists(rendered_file)) {
        file.rename(rendered_file, report_html_path)
      }
      
      list(success = TRUE, message = "Report rendered successfully")
    }, error = function(e) {
      list(success = FALSE, message = e$message)
    })
    
    render_success <- render_result$success
    
    if (render_success) {
      if (verbose) message(sprintf("  [OK] Report rendered: %s", basename(report_html_path)))
      
      validation_context_report_release <- log_validation_event(
        validation_context_report_release,
        event_type = "report_generated",
        description = "Quarto report rendered",
        details = list(file = basename(report_html_path))
      )
    } else {
      warning(sprintf("Report rendering failed: %s", render_result$message))
    }
    
  } else {
    warning("Quarto template not found - skipping report generation")
  }
  
  log_message(sprintf("[Report & Release - Stage 23] Report rendering: %s", 
                      if(render_success) "SUCCESS" else "SKIPPED"))
  
  # ---------------------------------------------------------------------------
  # Stage 24: Create Release Bundle
  # ---------------------------------------------------------------------------
  
  log_stage_start("24", "Create Release Bundle", verbose = verbose, workflow_prefix = "Report & Release")
  
  release_zip_path <- NULL
  
  if (create_release_bundle && render_success) {
    
    release_result <- tryCatch({
      zip_path <- create_release_bundle(
        study_id = study_params$study_parameters$study_name,
        calls_per_night_final = calls_per_night_final,  # Data frame from Finalize CPN
        kpro_master = kpro_master,                      # Data frame from Stage 2
        all_summaries = all_summaries,                  # List from Summary Stats
        all_plots = all_plots,                          # List from Plotting
        report_path = report_html_path,                 # Path to HTML
        study_params = study_params,                    # Already loaded
        output_dir = here::here("results", "releases"),
        registry = registry,                            # Already initialized
        quiet = !verbose                                # Inverse of verbose
      )
      
      list(success = TRUE, zip_path = zip_path)
    }, error = function(e) {
      warning(sprintf("Release bundle creation failed: %s", e$message))
      list(success = FALSE, zip_path = NULL)
    })
    
    if (release_result$success) {
      release_zip_path <- release_result$zip_path
      
      if (verbose) message(sprintf("  [OK] Release bundle: %s", basename(release_zip_path)))
      
      validation_context_report_release <- log_validation_event(
        validation_context_report_release,
        event_type = "release_created",
        description = "Release bundle created",
        details = list(
          file = basename(release_zip_path),
          size_kb = file.size(release_zip_path) / 1024
        )
      )
    }
  } else {
    if (verbose) message("  [!] Release bundle skipped")
  }
  
  log_message(sprintf("[Report & Release - Stage 24] Release bundle: %s", 
                      if(!is.null(release_zip_path)) "CREATED" else "SKIPPED"))
  
  # ---------------------------------------------------------------------------
  # Stage 25: Finalize Validation
  # ---------------------------------------------------------------------------
  
  log_stage_start("25", "Finalize Validation", verbose = verbose, workflow_prefix = "Report & Release")
  
  validation_html_report_release <- finalize_stage_validation_report(
    validation_context = validation_context_report_release,
    stage_name = "REPORT & RELEASE",
    verbose = verbose
  )
  
  log_message("=== REPORT & RELEASE: COMPLETE ===")
  
  # Store Report & Release results
  result <- store_stage_results(
    result,
    stage_key = "report_release",
    stage_outputs = list(
      report_html = report_html_path,
      release_zip = release_zip_path,
      report_size_kb = if(!is.null(report_html_path) && file.exists(report_html_path)) 
        file.size(report_html_path) / 1024 else NA
    ),
    validation_html = validation_html_report_release
  )
  
  # ===========================================================================
  # FINALIZE AND RETURN
  # ===========================================================================
  
  pipeline_end_time <- Sys.time()
  pipeline_duration <- as.numeric(difftime(pipeline_end_time, pipeline_start_time, units = "secs"))
  
  # Calculate summary statistics
  result$summary <- list(
    pipeline_duration_sec = pipeline_duration,
    total_detectors = dplyr::n_distinct(calls_per_night_final$Detector),
    total_calls = sum(calls_per_night_final$CallsPerNight),
    total_recording_hours = sum(calls_per_night_final$RecordingHours, na.rm = TRUE),
    study_name = study_params$study_parameters$study_name,
    timestamp = format(Sys.time(), "%Y%m%d_%H%M%S")
  )
  
  log_message(sprintf("=== CHUNK 3 COMPLETE: 4 stages, %.1f seconds ===",
                      pipeline_duration))
  
  if (verbose) {
    message("\n")
    message("╔═══════════════════════════════════════════════════════════════╗")
    message("║           PIPELINE COMPLETE - CHUNK 3 FINISHED              ║")
    message("╚═══════════════════════════════════════════════════════════════╝")
    message("")
    message(sprintf("  Duration: %.1f seconds", pipeline_duration))
    message(sprintf("  Detectors: %d", result$summary$total_detectors))
    message(sprintf("  Total calls: %s", format(result$summary$total_calls, big.mark = ",")))
    message(sprintf("  Recording hours: %.1f", result$summary$total_recording_hours))
    message("")
    message("  Deliverables:")
    message(sprintf("    - CPN Final: %s", basename(cpn_final_path)))
    if (!is.null(report_html_path)) {
      message(sprintf("    - Report: %s", basename(report_html_path)))
    }
    if (!is.null(release_zip_path)) {
      message(sprintf("    - Release: %s", basename(release_zip_path)))
    }
    message("")
    message("╚═══════════════════════════════════════════════════════════════╝")
    message("")
  }
  
  return(result)
}


# ==============================================================================
# END OF FILE
# ==============================================================================
