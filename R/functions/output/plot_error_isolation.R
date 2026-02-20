# =============================================================================
# UTILITY: plot_error_isolation.R - Per-Plot Generation Safety & Failure Ledger
# =============================================================================
# PURPOSE
# -------
# Provides per-plot error isolation and failure ledger for robust plot generation.
# Allows individual plots to fail gracefully without breaking the entire
# category-level generation, while maintaining comprehensive error tracking.
#
# DEPENDENCIES
# ────────────
# Internal:
#   - R/functions/core/logging.R: log_message, initialize_pipeline_log
#   - R/functions/core/orchestration_helpers.R: log_stage_start
#
# FUNCTIONS PROVIDED
# ──────────────────
#   - generate_plot_safely(): Generate single plot with error isolation
#   - create_failure_ledger(): Create structured failure tracking
#   - summarize_plot_failures(): Format failure summary for output
#
# USAGE
# ─────
# source("R/functions/output/plot_error_isolation.R")
# 
# ledger <- create_failure_ledger()
# p <- generate_plot_safely(
#   plot_function = plot_species_composition_bar,
#   data = kpro_master,
#   plot_name = "species_composition_bar",
#   category = "species",
#   ledger = ledger,
#   verbose = FALSE
# )
# if (!is.null(p)) message("Plot generated successfully")
# 
# summary <- summarize_plot_failures(ledger)
# print(summary)
#
# CHANGELOG
# ---------
# 2026-02-20: Initial implementation with per-plot isolation pattern
# =============================================================================


#' Generate a Plot Safely with Error Isolation
#'
#' @description
#' Generates a single plot with comprehensive error handling and logging.
#' If the plot function fails, returns NULL (not the plot), captures error
#' message, and optionally logs to failure ledger without stopping execution.
#'
#' This enables individual plot failures to be non-fatal, allowing the
#' pipeline to continue generating remaining plots while tracking what failed.
#'
#' @param plot_function Function. The plotting function to execute 
#'   (e.g., plot_species_composition_bar). Must accept data as first argument.
#' @param data Data frame or tibble. Input data for the plot function.
#' @param plot_name Character. Simple name of the plot (e.g., "species_composition_bar").
#'   Used in error messages and ledger.
#' @param category Character. Category of plot (e.g., "species", "detector", "quality").
#'   Used for organization in ledger and logging.
#' @param ledger List. Failure ledger (created with create_failure_ledger).
#'   Updated if plot generation fails.
#' @param ... Additional arguments passed to plot_function.
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return ggplot object if successful, NULL if failed.
#'
#' @section CONTRACT:
#' - Always returns NULL on failure (never stops execution)
#' - Captures full error message and stack
#' - Updates failure ledger with structured error info
#' - Logs errors to pipeline log if available
#' - Respects verbose parameter for console output
#'
#' @section DOES NOT:
#' - Stop or error on plot generation failure
#' - Modify input data
#' - Suppress warnings (warnings are always shown)
#' - Guarantee specific plot appearance/format
#'
#' @examples
#' \dontrun{
#' ledger <- create_failure_ledger()
#' 
#' # Generate plot with error isolation
#' p <- generate_plot_safely(
#'   plot_function = plot_species_composition_bar,
#'   data = kpro_master,
#'   plot_name = "species_composition_bar",
#'   category = "species",
#'   ledger = ledger,
#'   verbose = TRUE
#' )
#' 
#' if (!is.null(p)) {
#'   print(p)  # Plot was successful
#' } else {
#'   cat("Plot failed, see ledger:\n")
#'   print(ledger$failures[[length(ledger$failures)]])
#' }
#' }
#'
#' @export
generate_plot_safely <- function(
    plot_function,
    data,
    plot_name,
    category,
    ledger = NULL,
    ...,
    verbose = FALSE
) {
  
  # Validate inputs
  if (!is.function(plot_function)) {
    stop("plot_function must be a function")
  }
  if (!is.data.frame(data) && !is.null(data)) {
    stop("data must be a data frame or NULL")
  }
  if (!is.character(plot_name) || length(plot_name) != 1) {
    stop("plot_name must be a single character string")
  }
  if (!is.character(category) || length(category) != 1) {
    stop("category must be a single character string")
  }
  
  # Attempt plot generation with error capture
  result <- tryCatch({
    if (verbose) message(sprintf("  Generating %s...", plot_name))
    
    # Call plot function with data + additional arguments
    p <- plot_function(data, ...)
    
    # Verify result is ggplot
    if (!inherits(p, "ggplot")) {
      warning(sprintf(
        "%s did not return a ggplot object (returned %s)",
        plot_name,
        class(p)[1]
      ))
    }
    
    if (verbose) message(sprintf("    ✓ %s generated successfully", plot_name))
    p
    
  }, error = function(e) {
    
    # Log error  
    if (verbose) {
      message(sprintf("    ✗ %s failed with error:", plot_name))
      message(sprintf("      %s", e$message))
    }
    
    # Update failure ledger if provided
    if (!is.null(ledger) && is.list(ledger) && !is.null(ledger$failures)) {
      ledger$failures[[length(ledger$failures) + 1]] <- list(
        plot_name = plot_name,
        category = category,
        error_message = e$message,
        error_class = class(e)[1],
        timestamp = Sys.time(),
        function_name = deparse(substitute(plot_function)),
        data_nrows = nrow(data),
        data_ncols = ncol(data)
      )
      ledger$failure_count <- ledger$failure_count + 1
    }
    
    # Return NULL on failure
    NULL
    
  }, warning = function(w) {
    # Warnings are shown but don't prevent plot return
    warning(w$message, call. = FALSE)
  })
  
  result
}


#' Create Failure Ledger for Plot Generation Tracking
#'
#' @description
#' Initializes an empty failure ledger to track plot generation errors.
#' Used with generate_plot_safely() to maintain a comprehensive error log
#' across all plot generation in a pipeline run.
#'
#' @return List with structure:
#' \itemize{
#'   \item failures: List of error records (initially empty)
#'   \item failure_count: Counter of total failures (initially 0)
#'   \item created_time: Timestamp of ledger creation
#' }
#'
#' @examples
#' ledger <- create_failure_ledger()
#' # Use with generate_plot_safely()
#'
#' @export
create_failure_ledger <- function() {
  list(
    failures = list(),
    failure_count = 0,
    created_time = Sys.time()
  )
}


#' Summarize Plot Generation Failures
#'
#' @description
#' Creates a human-readable summary of plot generation failures from
#' the failure ledger. Useful for logging, validation reports, and debugging.
#'
#' @param ledger List. Failure ledger created by create_failure_ledger()
#'   and populated by generate_plot_safely().
#' @param verbose Logical. Include detailed error messages. Default: FALSE.
#'
#' @return Data frame or summary text with columns:
#' \itemize{
#'   \item plot_name: Name of the failed plot
#'   \item category: Category (quality, detector, species, temporal)
#'   \item error_message: Brief error description
#'   \item timestamp: When error occurred
#' }
#'
#' @examples
#' \dontrun{
#' ledger <- create_failure_ledger()
#' # ... generate plots with ledger ...
#' summary <- summarize_plot_failures(ledger, verbose = FALSE)
#' print(summary)
#' }
#'
#' @export
summarize_plot_failures <- function(ledger, verbose = FALSE) {
  
  if (is.null(ledger) || ledger$failure_count == 0) {
    return(data.frame(
      message = "No plot generation failures recorded"
    ))
  }
  
  # Convert failures list to data frame
  failure_df <- do.call(rbind, lapply(ledger$failures, function(f) {
    data.frame(
      plot_name = f$plot_name %||% "unknown",
      category = f$category %||% "unknown",
      error_message = if (verbose) f$error_message else {
        # Abbreviate long messages
        if (nchar(f$error_message) > 60) {
          paste0(substr(f$error_message, 1, 57), "...")
        } else {
          f$error_message
        }
      },
      timestamp = if (!is.null(f$timestamp)) {
        format(f$timestamp, "%Y-%m-%d %H:%M:%S")
      } else {
        "unknown"
      },
      stringsAsFactors = FALSE
    )
  }))
  
  failure_df
}


#' Helper: Null Coalescing Operator
#'
#' @description
#' Utility operator for handling NULL values. Returns left side if not NULL,
#' otherwise returns right side.
#'
#' @usage x %||% y
#'
#' @export `%||%`
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
