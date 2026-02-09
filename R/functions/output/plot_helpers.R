# =============================================================================
# UTILITY: plot_helpers.R - Shared Plotting Utilities
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# PURPOSE
# -------
# Provides shared utilities for all visualization functions in the KPro
# Masterfile Pipeline. Ensures consistent styling, colorblind-accessible
# palettes, and standardized input validation across all plot modules.
#
# This file MUST be sourced before any other plot_*.R files, as they
# depend on functions defined here.
#
# DEPENDENCIES
# ------------
# External Packages:
#   - ggplot2: Theme construction and plot building
#
# Internal Dependencies:
#   - None (this is the base layer for plotting)
#
# FUNCTIONS PROVIDED
# ------------------
#
# Theme Functions - Standard ggplot2 theme configuration:
#
#   - theme_kpro():
#       Uses packages: ggplot2 (theme_minimal, element_* functions, margin, rel)
#       Calls internal: none
#       Purpose: Return publication-ready ggplot2 theme object with KPro styling
#
# Color Palette Functions - Colorblind-accessible color schemes:
#
#   - kpro_palette_cat():
#       Uses packages: base R (list operations)
#       Calls internal: none
#       Purpose: Return categorical color palette (colorblind-safe, N colors)
#
#   - kpro_palette_seq():
#       Uses packages: base R (list operations)
#       Calls internal: none
#       Purpose: Return sequential color palette (low to high values)
#
#   - kpro_status_colors():
#       Uses packages: base R (list operations)
#       Calls internal: none
#       Purpose: Return status-specific colors (success, warning, error)
#
# Validation Functions - Input checking:
#
#   - validate_plot_input():
#       Uses packages: base R (is.data.frame, inherits, stop)
#       Calls internal: none
#       Purpose: Validate data frame and required columns exist
#
# Formatting Utilities - Number and percentage formatting:
#
#   - format_number():
#       Uses packages: base R (format, round, scales)
#       Calls internal: none
#       Purpose: Format counts/decimals with thousands separator and precision
#
#   - format_pct():
#       Uses packages: base R (format, round, scales)
#       Calls internal: none
#       Purpose: Format percentages with specified decimal places
#
# USAGE
# -----
# This file is sourced automatically by load_all.R. All plot_*.R files
# depend on functions defined here.
#
# Last Modified: 2026-02-09
#
# CHANGELOG
# ---------
# 2026-02-01: Verified deterministic behavior - all functions follow standards
# 2026-02-01: Confirmed usage in all plot_* modules and run_finalize_to_report.R
# 2024-12-30: Initial creation with CODING_STANDARDS compliance
#
# =============================================================================

library(ggplot2)

# =============================================================================
# THEME FUNCTIONS
# =============================================================================

#' KPro Pipeline Standard ggplot2 Theme
#'
#' @description
#' Provides a consistent, publication-ready ggplot2 theme for all pipeline
#' visualizations. Based on theme_minimal() with customizations for
#' readability, professional appearance, and accessibility.
#'
#' @param base_size Numeric. Base font size in points. Default is 11.
#' @param rotate_x Logical. If TRUE, rotates x-axis labels 45 degrees for
#'   long labels. Default is FALSE.
#'
#' @return A ggplot2 theme object that can be added to any ggplot.
#'
#' @details
#' Theme customizations include:
#' - Bold title and axis labels for readability
#' - Subdued subtitle and caption colors
#' - Minimal grid lines (major only, light gray)
#' - Clean facet strip styling
#' - Right-positioned legend by default
#'
#' The theme is designed to work well for both screen display and
#' publication export at 300+ DPI.
#'
#' @section CONTRACT:
#' - Returns a complete ggplot2 theme object
#' - Does not modify global ggplot2 settings
#' - Works with all ggplot2 geoms
#' - Produces consistent output across R sessions
#'
#' @section DOES NOT:
#' - Set color scales (use kpro_palette_* functions)
#' - Modify data or mappings
#' - Save plots to disk
#' - Set plot dimensions (use ggsave() arguments)
#'
#' @examples
#' \dontrun{
#' library(ggplot2)
#'
#' # Basic usage
#' ggplot(mtcars, aes(x = wt, y = mpg)) +
#'   geom_point() +
#'   theme_kpro()
#'
#' # With rotated x-axis labels
#' ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
#'   geom_boxplot() +
#'   theme_kpro(rotate_x = TRUE)
#'
#' # Larger base size for presentations
#' ggplot(mtcars, aes(x = wt, y = mpg)) +
#'   geom_point() +
#'   theme_kpro(base_size = 14)
#' }
#'
#' @export
theme_kpro <- function(base_size = 11, rotate_x = FALSE) {
  
  # Build base theme from theme_minimal
  
  t <- theme_minimal(base_size = base_size) +
    theme(
      # Title styling - bold, slightly larger
      plot.title = element_text(
        face = "bold",
        size = base_size + 3,
        hjust = 0
      ),
      plot.subtitle = element_text(
        color = "gray40",
        size = base_size,
        hjust = 0
      ),
      plot.caption = element_text(
        color = "gray50",
        size = base_size - 2,
        hjust = 1
      ),
      
      # Axis styling - bold labels
      axis.title = element_text(
        face = "bold",
        size = base_size
      ),
      axis.text = element_text(size = base_size - 1),
      
      # Legend styling
      legend.title = element_text(
        face = "bold",
        size = base_size
      ),
      legend.text = element_text(size = base_size - 1),
      legend.position = "right",
      
      # Panel styling - minimal grid
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "gray90"),
      
      # Strip styling for facets
      strip.text = element_text(
        face = "bold",
        size = base_size
      ),
      strip.background = element_rect(
        fill = "gray95",
        color = NA
      )
    )
  
  # Optionally rotate x-axis labels for long text
  if (rotate_x) {
    t <- t + theme(
      axis.text.x = element_text(
        angle = 45,
        hjust = 1,
        vjust = 1
      )
    )
  }
  
  t
}

# =============================================================================
# COLOR PALETTE FUNCTIONS
# =============================================================================

#' Colorblind-Accessible Categorical Color Palette
#'
#' @description
#' Returns a vector of colorblind-accessible colors for categorical data.
#' Based on the Okabe-Ito palette, which is distinguishable by people with
#' all common forms of color vision deficiency.
#'
#' @param n Integer. Number of colors needed. Default is 8 (full palette).
#'
#' @return Character vector of hex color codes.
#'
#' @details
#' The Okabe-Ito palette includes 8 distinct colors:
#' 1. Orange (#E69F00)
#' 2. Sky Blue (#56B4E9)
#' 3. Bluish Green (#009E73)
#' 4. Yellow (#F0E442)
#' 5. Blue (#0072B2)
#' 6. Vermillion (#D55E00)
#' 7. Reddish Purple (#CC79A7)
#' 8. Gray (#999999)
#'
#' 4 additional colors chosen for most contrast
#' 9. Pale Blue (#88CCEE)
#' 10. Dark Green (#117733)
#' 11. Dark Purple (#882255)
#' 12. Mauve (#AA4499)
#' 
#' If more than 12 colors are requested, colors will recycle with a warning.
#'
#' @section CONTRACT:
#' - Returns exactly n colors
#' - Colors are always in the same order
#' - All colors are valid hex codes
#' - Colors are distinguishable for colorblind viewers
#'
#' @section DOES NOT:
#' - Apply colors to plots (use scale_color_manual)
#' - Validate that n is reasonable for visualization
#' - Modify global color settings
#'
#' @examples
#' \dontrun{
#' # Get 4 colors for a plot with 4 groups
#' colors <- kpro_palette_cat(4)
#' # Returns: "#E69F00" "#56B4E9" "#009E73" "#F0E442"
#'
#' # Use in ggplot
#' ggplot(data, aes(x = group, y = value, fill = group)) +
#'   geom_col() +
#'   scale_fill_manual(values = kpro_palette_cat(4))
#' }
#'
#' @export
kpro_palette_cat <- function(n = 8) {
  
  # Extended Okabe-Ito palette with 4 additional colorblind-safe colors
  # First 8: Original Okabe-Ito palette
  # Next 4: Carefully chosen supplements that maintain distinguishability
  colors <- c(
    "#E69F00",  # Orange
    "#56B4E9",  # Sky Blue
    "#009E73",  # Bluish Green
    "#F0E442",  # Yellow
    "#0072B2",  # Blue
    "#D55E00",  # Vermillion
    "#CC79A7",  # Reddish Purple
    "#999999",  # Gray
    # Supplementary colors (still colorblind-friendly)
    "#88CCEE",  # Pale Blue
    "#117733",  # Dark Green
    "#882255",  # Dark Purple
    "#AA4499"   # Mauve
  )
  
  if (n > length(colors)) {
    warning(
      sprintf(
        "Requested %d colors but palette has %d. Colors will recycle.",
        n, length(colors)
      )
    )
  }
  
  rep_len(colors, n)
}


#' Sequential Color Palette Option
#'
#' @description
#' Returns the name of a viridis palette option for use with continuous
#' or sequential data. Viridis palettes are perceptually uniform and
#' colorblind-accessible.
#'
#' @param option Character. Viridis palette name. One of: "viridis",
#'   "magma", "plasma", "inferno", "cividis". Default is "viridis".
#'
#' @return Character string matching the input option (validated).
#'
#' @details
#' This is a simple validation wrapper that ensures the palette option
#' is valid before passing to scale_fill_viridis_c() or similar functions.
#'
#' Palette descriptions:
#' - viridis: Blue-green-yellow (default, most common)
#' - magma: Black-red-yellow (good for heat maps)
#' - plasma: Blue-pink-yellow (high contrast)
#' - inferno: Black-red-yellow (similar to magma)
#' - cividis: Blue-yellow (optimized for color vision deficiency)
#'
#' @section CONTRACT:
#' - Returns a valid viridis option string
#' - Throws error for invalid options
#'
#' @section DOES NOT:
#' - Apply the palette to plots
#' - Return actual color values
#'
#' @examples
#' \dontrun{
#' # Use in ggplot with viridis scale
#' ggplot(data, aes(x = x, y = y, fill = value)) +
#'   geom_tile() +
#'   scale_fill_viridis_c(option = kpro_palette_seq("magma"))
#' }
#'
#' @export
kpro_palette_seq <- function(option = "viridis") {
  match.arg(option, c("viridis", "magma", "plasma", "inferno", "cividis"))
}


#' Recording Status Color Palette
#'
#' @description
#' Returns a named vector of colors for recording status categories.
#' These colors are used consistently across all data quality visualizations
#' to represent Success, Partial, and Fail status values.
#'
#' @return Named character vector with colors for "Success", "Partial", "Fail".
#'
#' @details
#' Color assignments:
#' - Success (#009E73): Bluish green - positive, complete recording
#' - Partial (#E69F00): Orange - warning, incomplete but usable
#' - Fail (#D55E00): Vermillion - negative, recording failure
#'
#' These colors are from the Okabe-Ito palette and are distinguishable
#' for colorblind viewers.
#'
#' @section CONTRACT:
#' - Returns exactly 3 named colors
#' - Names are always "Success", "Partial", "Fail"
#' - Colors are consistent across all calls
#'
#' @section DOES NOT:
#' - Accept custom status names
#' - Modify the returned colors based on context
#'
#' @examples
#' \dontrun{
#' # Use in ggplot
#' ggplot(data, aes(x = Detector, fill = Status)) +
#'   geom_bar() +
#'   scale_fill_manual(values = kpro_status_colors())
#' }
#'
#' @export
kpro_status_colors <- function() {
  c(
    "Success" = "#009E73",
    "Partial" = "#E69F00",
    "Fail"    = "#D55E00"
  )
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

#' Validate Plot Input Data
#'
#' @description
#' Validates common requirements for plot input data frames. Provides
#' consistent, informative error messages that help users diagnose
#' data issues before plotting fails.
#'
#' @param df Data frame to validate.
#' @param required_cols Character vector. Column names that must exist.
#'   Default is NULL (no column requirements).
#' @param date_cols Character vector. Column names that must be Date class.
#'   Default is NULL (no date requirements).
#' @param numeric_cols Character vector. Column names that must be numeric.
#'   Default is NULL (no numeric requirements).
#' @param df_name Character. Name of data frame for error messages.
#'   Default is "data".
#'
#' @return TRUE invisibly if all validations pass. Throws error otherwise.
#'
#' @details
#' Validation order:
#' 1. Check that df is a data frame
#' 2. Check that all required_cols exist
#' 3. Check that date_cols are Date class
#' 4. Check that numeric_cols are numeric
#'
#' Error messages include the df_name parameter to help users identify
#' which input caused the error when multiple data frames are in use.
#'
#' @section CONTRACT:
#' - Returns TRUE invisibly if all checks pass
#' - Throws informative error on first failure
#' - Checks are performed in consistent order
#' - Column name checks are case-sensitive
#'
#' @section DOES NOT:
#' - Modify the input data frame
#' - Check for empty data frames (use assert_not_empty separately)
#' - Validate column values (only types)
#' - Check for NA values
#'
#' @examples
#' \dontrun{
#' # Basic usage - check for required columns
#' validate_plot_input(
#'   df = calls_per_night,
#'   required_cols = c("Detector", "Night", "CallsPerNight"),
#'   df_name = "calls_per_night"
#' )
#'
#' # Check column types
#' validate_plot_input(
#'   df = cpn_data,
#'   required_cols = c("Night", "CallsPerNight"),
#'   date_cols = "Night",
#'   numeric_cols = "CallsPerNight",
#'   df_name = "cpn_data"
#' )
#' }
#'
#' @export
validate_plot_input <- function(df,
                                required_cols = NULL,
                                date_cols = NULL,
                                numeric_cols = NULL,
                                df_name = "data") {
  
  # Check that input is a data frame
  if (!is.data.frame(df)) {
    stop(
      sprintf("%s must be a data frame, not %s", df_name, class(df)[1]),
      call. = FALSE
    )
  }
  
  # Check that required columns exist
  if (!is.null(required_cols)) {
    missing <- setdiff(required_cols, names(df))
    if (length(missing) > 0) {
      stop(
        sprintf(
          "%s is missing required columns: %s\nAvailable columns: %s",
          df_name,
          paste(missing, collapse = ", "),
          paste(names(df), collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }
  
  # Check that date columns are Date class
  if (!is.null(date_cols)) {
    for (col in date_cols) {
      if (col %in% names(df) && !inherits(df[[col]], "Date")) {
        stop(
          sprintf(
            "%s$%s must be Date class (currently %s). Use as.Date() to convert.",
            df_name, col, class(df[[col]])[1]
          ),
          call. = FALSE
        )
      }
    }
  }
  
  # Check that numeric columns are numeric
  if (!is.null(numeric_cols)) {
    for (col in numeric_cols) {
      if (col %in% names(df) && !is.numeric(df[[col]])) {
        stop(
          sprintf(
            "%s$%s must be numeric (currently %s). Use as.numeric() to convert.",
            df_name, col, class(df[[col]])[1]
          ),
          call. = FALSE
        )
      }
    }
  }
  
  invisible(TRUE)
}

# =============================================================================
# FORMATTING UTILITIES
# =============================================================================

#' Format Large Numbers for Plot Labels
#'
#' @description
#' Formats numeric values with thousands separators for readability in
#' plot labels, titles, and annotations.
#'
#' @param x Numeric vector to format.
#'
#' @return Character vector with formatted numbers (e.g., "1,234,567").
#'
#' @details
#' Uses commas as thousands separators. Does not use scientific notation.
#' NA values are preserved as "NA" strings.
#'
#' @section CONTRACT:
#' - Returns character vector same length as input
#' - Never uses scientific notation
#' - Preserves NA as "NA"
#'
#' @section DOES NOT:
#' - Round numbers (use round() first if needed)
#' - Add units or suffixes
#' - Handle non-numeric input gracefully
#'
#' @examples
#' \dontrun{
#' format_number(1234567)
#' # Returns: "1,234,567"
#'
#' # Use in plot labels
#' geom_text(aes(label = format_number(TotalCalls)))
#' }
#'
#' @export
format_number <- function(x) {
  format(x, big.mark = ",", scientific = FALSE)
}


#' Format Decimal as Percentage
#'
#' @description
#' Converts decimal values (0-1) or raw percentages (0-100) to formatted
#' percentage strings with the % symbol.
#'
#' @param x Numeric value to format.
#' @param digits Integer. Number of decimal places. Default is 1.
#' @param already_pct Logical. If TRUE, x is already 0-100 scale.
#'   If FALSE (default), x is 0-1 scale and will be multiplied by 100.
#'
#' @return Character string with percentage (e.g., "45.6%").
#'
#' @details
#' Common usage patterns:
#' - Proportions from dplyr (0-1): format_pct(0.456) → "45.6%
#' - Pre-calculated percentages: format_pct(45.6, already_pct = TRUE) → "45.6%"
#'
#' @section CONTRACT:
#' - Returns character string with % symbol
#' - Respects digits parameter for decimal places
#' - Handles NA by returning "NA%"
#'
#' @section DOES NOT:
#' - Validate that input is in expected range
#' - Handle vector input (use sapply for vectors)
#'
#' @examples
#' \dontrun{
#' format_pct(0.456)
#' # Returns: "45.6%"
#'
#' format_pct(45.6, already_pct = TRUE)
#' # Returns: "45.6%"
#'
#' format_pct(0.456, digits = 0)
#' # Returns: "46%"
#' }
#'
#' @export
format_pct <- function(x, digits = 1, already_pct = FALSE) {
  if (!already_pct) x <- x * 100
  sprintf("%.*f%%", digits, x)
}


# ==============================================================================
# NEW HELPER FUNCTIONS (Added for Module Refactoring)
# ==============================================================================


#' Create Plot Output Directories
#'
#' @description
#' Sets up standardized directory structure for plot exports.
#' Creates subdirectories for quality, detector, species, and temporal plots.
#'
#' @param base_dir Character. Base directory for plots. Default: "results/figures/png".
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return Character vector of created directory paths (invisibly).
#'
#' @section CONTRACT:
#' - Creates all subdirectories if they don't exist
#' - Always creates: quality/, detector/, species/, temporal/
#' - Returns paths of all created directories
#' - Never fails (creates recursively, ignores existing dirs)
#'
#' @keywords internal
#' @export
create_plot_directories <- function(base_dir = "results/figures/png", verbose = FALSE) {
  
  categories <- c("quality", "detector", "species", "temporal")
  created_dirs <- character()
  
  for (category in categories) {
    dir_path <- file.path(base_dir, category)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
      if (verbose) message(sprintf("  [OK] Created directory: %s", dir_path))
    }
    created_dirs <- c(created_dirs, dir_path)
  }
  
  invisible(created_dirs)
}


#' Export Plots to PNG Files
#'
#' @description
#' Wrapper function to export a nested list of ggplot objects to PNG files.
#' Standardizes export settings (DPI, dimensions, error handling).
#'
#' @param all_plots List of nested lists. Structure:
#'   List(category1 = List(plot1 = ggplot(), plot2 = ggplot(), ...),
#'        category2 = List(...), ...)
#' @param base_dir Character. Base directory for exports (with category subdirs).
#'   Default: "results/figures/png".
#' @param width Numeric. Plot width in inches. Default: 10.
#' @param height Numeric. Plot height in inches. Default: 7.
#' @param dpi Numeric. DPI for PNG export. Default: 300.
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return List with elements:
#'   - total_exported: Numeric count of successfully exported plots
#'   - files_created: Character vector of exported file paths
#'   - failed_plots: Character vector of plot names that failed
#'
#' @section CONTRACT:
#' - Requires ggplot2 package for ggsave()
#' - Skips plots that are not ggplot objects
#' - Handles errors gracefully (warns and continues)
#' - Returns summary of export results
#'
#' @keywords internal
#' @export
export_plots_png <- function(all_plots, base_dir = "results/figures/png",
                             width = 10, height = 7, dpi = 300, verbose = FALSE) {
  
  total_exported <- 0
  files_created <- character()
  failed_plots <- character()
  
  for (category in names(all_plots)) {
    category_plots <- all_plots[[category]]
    
    if (!is.list(category_plots) || length(category_plots) == 0) {
      next
    }
    
    for (plot_name in names(category_plots)) {
      plot_obj <- category_plots[[plot_name]]
      
      # Skip non-ggplot objects
      if (!inherits(plot_obj, "ggplot")) {
        next
      }
      
      # Build file path
      plot_path <- file.path(base_dir, category, sprintf("%s.png", plot_name))
      
      # Export plot
      tryCatch({
        ggplot2::ggsave(
          plot_path,
          plot_obj,
          width = width,
          height = height,
          dpi = dpi,
          bg = "white"
        )
        
        files_created <- c(files_created, plot_path)
        total_exported <- total_exported + 1
      }, error = function(e) {
        warning(sprintf("Failed to export plot %s: %s", plot_name, e$message))
        failed_plots <<- c(failed_plots, plot_name)
      })
    }
  }
  
  if (verbose) {
    message(sprintf("  [OK] Exported %d PNG files", total_exported))
    if (length(failed_plots) > 0) {
      message(sprintf("  [!] Failed plots: %s", paste(failed_plots, collapse = ", ")))
    }
  }
  
  list(
    total_exported = total_exported,
    files_created = files_created,
    failed_plots = failed_plots
  )
}