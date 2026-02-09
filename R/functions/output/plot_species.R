# =============================================================================
# UTILITY: plot_species.R - Species Composition Visualizations
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# PURPOSE
# -------
# Provides visualization functions focused on species-level bat activity
# patterns. These plots help researchers understand species diversity,
# composition, and detection patterns across monitoring sites.
#
# All functions return ggplot2 objects that can be further customized,
# combined with other plots, or saved using ggsave().
#
# DEPENDENCIES
# ------------
# External Packages:
#   - ggplot2: All plotting
#   - dplyr: Data manipulation for plot preparation
#   - tidyr: complete() for filling missing combinations
#   - lubridate: Hour extraction from DateTime
#
# Internal Dependencies:
#   - plot_helpers.R: theme_kpro(), validate_plot_input(), kpro_palette_cat(),
#                     format_number()
#
# FUNCTIONS PROVIDED
# ------------------
#
# Overall Composition - Study-wide species summaries:
#
#   - plot_species_composition_bar():
#       Uses packages: ggplot2 (ggplot, aes, geom_col, coord_flip),
#                      dplyr (count, arrange, mutate)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Horizontal bar chart of total calls by species (ordered high to low)
#
#   - plot_species_by_detector_heatmap():
#       Uses packages: ggplot2 (ggplot, aes, geom_tile, scale_fill_gradient),
#                      dplyr (group_by, summarize), tidyr (pivot_wider)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       format_number)
#       Purpose: Heatmap of species × detector with call counts
#
# Sampling Adequacy - Species accumulation over time:
#
#   - plot_species_accumulation_curve():
#       Uses packages: ggplot2 (ggplot, aes, geom_line, geom_point),
#                      dplyr (group_by, mutate, cumsum)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Line plot of cumulative unique species over study period
#
# Activity Patterns - Species-specific temporal patterns:
#
#   - plot_species_hourly_profile():
#       Uses packages: ggplot2 (ggplot, aes, geom_col, facet_wrap),
#                      dplyr (group_by, summarize, slice_max)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_palette_cat, format_number)
#       Purpose: Activity by hour for top N species (subset to prevent crowding)
#
# Data Quality - Identification rates:
#
#   - plot_noid_proportion():
#       Uses packages: ggplot2 (ggplot, aes, geom_col),
#                      dplyr (group_by, summarize, mutate)
#       Calls internal: plot_helpers.R (theme_kpro, validate_plot_input,
#                       kpro_status_colors, format_number)
#       Purpose: Stacked bar showing ID success rate by detector
# SPECIES COLUMN NOTE
# -------------------
# All functions in this module use the unified `species` column created
# in Module 3. This column contains either:
#   - auto_id values (if user chose automatic ID only)
#   - manual_id values with auto_id fallback (if user chose manual ID path)
#
# The original auto_id and manual_id columns are preserved in the master
# file for audit purposes, but all species-level analysis uses `species`.
#
# USAGE
# -----
# # Source via load_all.R or directly:
# source("R/functions/output/plot_helpers.R")  # Must be first
# source("R/functions/output/plot_species.R")
#
# # Generate plot
# p <- plot_species_composition_bar(kpro_master)
#
# # Save plot
# ggsave("outputs/species_composition.png", p, width = 10, height = 6)
#
# Last Modified: 2026-02-09
#
# CHANGELOG
# ---------
# 2026-02-01: Verified deterministic behavior - all functions follow standards
# 2026-02-08: Confirmed usage in run_phase3_analysis_reporting() (Phase 3, Module 6)
# 2025-01-07: Updated to use unified `species` column (was auto_id)
# 2024-12-30: Initial creation with CODING_STANDARDS compliance
#
# =============================================================================


# =============================================================================
# OVERALL COMPOSITION
# =============================================================================

#' Species Composition Bar Chart
#'
#' @description
#' Creates a bar chart showing the total number of bat calls for each
#' species detected across the entire study. Bars are ordered from most
#' to least common species, with percentages shown.
#'
#' @param master_data Data frame. Must contain a `species` column with
#'   species identification codes (unified from auto_id or manual_id
#'   in Module 3). Each row represents one bat call.
#' @param top_n Integer or NULL. If specified, only show the top N species
#'   by total calls. Default is NULL (show all species).
#' @param exclude_noid Logical. If TRUE (default), exclude NoID and
#'   unidentified calls from the plot.
#'
#' @return ggplot object showing species composition bar chart.
#'
#' @details
#' This plot provides an overview of species composition for the entire
#' study. It answers the question: "What species did we detect and how
#' common was each?"
#'
#' The plot includes:
#' - Bars ordered by descending total calls
#' - Count and percentage labels above each bar
#' - Total call count in subtitle
#'
#' Species codes depend on the schema version used:
#' - 4-letter codes (e.g., MYLU, EPFU) for v2 schema
#' - 6-letter codes (e.g., MYOLUC, EPTFUS) for v3 schema
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Bars ordered by descending total calls
#' - Percentages calculated from displayed species only
#' - NoID excluded by default (can be included with exclude_noid = FALSE)
#'
#' @section DOES NOT:
#' - Account for detection probability
#' - Normalize by recording effort
#' - Validate species codes
#' - Distinguish original source (auto_id vs manual_id)
#'
#' @examples
#' \dontrun{
#' # All species
#' p <- plot_species_composition_bar(kpro_master)
#'
#' # Top 10 species only
#' p <- plot_species_composition_bar(kpro_master, top_n = 10)
#'
#' # Include NoID calls
#' p <- plot_species_composition_bar(kpro_master, exclude_noid = FALSE)
#' }
#'
#' @export
plot_species_composition_bar <- function(master_data,
                                         top_n = NULL,
                                         exclude_noid = TRUE) {
  
  # Validate input
  validate_plot_input(
    master_data,
    required_cols = "species",
    df_name = "master_data"
  )
  
  # Optionally filter out NoID/Unknown values
  if (exclude_noid) {
    master_data <- master_data %>%
      dplyr::filter(
        !is.na(species),
        !species %in% c("NoID", "UNKNOWN", "")
      )
  }
  
  # Count calls by species, ordered by descending count
  species_counts <- master_data %>%
    dplyr::count(species, name = "TotalCalls") %>%
    dplyr::arrange(dplyr::desc(TotalCalls))
  
  # Optionally limit to top N species
  if (!is.null(top_n) && top_n < nrow(species_counts)) {
    species_counts <- species_counts %>%
      dplyr::slice_head(n = top_n)
    title_suffix <- sprintf(" (Top %d)", top_n)
  } else {
    title_suffix <- ""
  }
  
  # Convert to factor for proper ordering
  species_counts <- species_counts %>%
    dplyr::mutate(species = factor(species, levels = species))
  
  # Calculate percentages
  total <- sum(species_counts$TotalCalls)
  species_counts <- species_counts %>%
    dplyr::mutate(pct = TotalCalls / total * 100)
  
  # Build plot
  ggplot(species_counts, aes(x = species, y = TotalCalls)) +
    geom_col(fill = "#009E73") +
    geom_text(
      aes(label = sprintf("%s\n(%.1f%%)", format_number(TotalCalls), pct)),
      vjust = -0.2,
      size = 3
    ) +
    scale_y_continuous(
      labels = scales::comma,
      expand = expansion(mult = c(0, 0.15))
    ) +
    labs(
      title = paste0("Species Composition", title_suffix),
      subtitle = sprintf("Total: %s calls", format_number(total)),
      x = "Species",
      y = "Total Calls"
    ) +
    theme_kpro(rotate_x = TRUE)
}


#' Species × Detector Heatmap
#'
#' @description
#' Creates a heatmap showing which species were detected at which detectors
#' and in what quantities. Useful for understanding species-habitat
#' associations and identifying detector-specific species assemblages.
#'
#' @param master_data Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - species: Character. Species identification code.
#' @param exclude_noid Logical. If TRUE (default), exclude NoID calls.
#' @param show_values Logical. If TRUE (default), display call counts in cells.
#'
#' @return ggplot object showing species × detector heatmap.
#'
#' @details
#' The heatmap uses a log1p-transformed color scale to handle the wide
#' range of call counts typically seen (from 1 to thousands). This prevents
#' common species from washing out the signal from rare species.
#'
#' Cells with zero detections are shown in the lightest color. Species
#' are ordered by total calls across all detectors (most common at top).
#'
#' Use cases:
#' - Identify which species occur at which sites
#' - Spot detectors with unusual species assemblages
#' - Find species that are site-specialists vs. generalists
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - All detector × species combinations shown (including zeros)
#' - Log1p color scale for wide-range data
#' - Species ordered by total calls (descending)
#'
#' @section DOES NOT:
#' - Normalize by recording effort
#' - Account for detection probability
#' - Test for significant associations
#' - Handle very long species lists well (>20 species)
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' p <- plot_species_by_detector_heatmap(kpro_master)
#'
#' # Without cell values (cleaner for many species)
#' p <- plot_species_by_detector_heatmap(kpro_master, show_values = FALSE)
#' }
#'
#' @export
plot_species_by_detector_heatmap <- function(master_data,
                                             exclude_noid = TRUE,
                                             show_values = TRUE) {
  
  # Validate input
  validate_plot_input(
    master_data,
    required_cols = c("Detector", "species"),
    df_name = "master_data"
  )
  
  # Optionally filter out NoID
  if (exclude_noid) {
    master_data <- master_data %>%
      dplyr::filter(
        !is.na(species),
        !species %in% c("NoID", "UNKNOWN", "")
      )
  }
  
  # Create complete species × detector matrix with counts
  species_detector <- master_data %>%
    dplyr::count(Detector, species, name = "n_calls") %>%
    tidyr::complete(
      Detector,
      species,
      fill = list(n_calls = 0)
    )
  
  # Order species by total calls (most common first, but reversed for y-axis)
  species_order <- species_detector %>%
    dplyr::group_by(species) %>%
    dplyr::summarise(total = sum(n_calls), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(total)) %>%
    dplyr::pull(species)
  
  species_detector <- species_detector %>%
    dplyr::mutate(species = factor(species, levels = rev(species_order)))
  
  # Build base heatmap
  p <- ggplot(species_detector, aes(x = Detector, y = species, fill = n_calls)) +
    geom_tile(color = "white") +
    scale_fill_viridis_c(
      option = "viridis",
      trans = "log1p",
      name = "Calls",
      labels = scales::comma
    ) +
    labs(
      title = "Species Detections by Detector",
      x = "Detector",
      y = "Species"
    ) +
    theme_kpro(rotate_x = TRUE) +
    theme(panel.grid = element_blank())
  
  # Optionally add value labels
  if (show_values) {
    # Only label cells with detections; format large numbers
    species_detector_labeled <- species_detector %>%
      dplyr::filter(n_calls > 0) %>%
      dplyr::mutate(
        label = ifelse(
          n_calls < 1000,
          as.character(n_calls),
          sprintf("%.1fk", n_calls / 1000)
        )
      )
    
    p <- p + geom_text(
      data = species_detector_labeled,
      aes(label = label),
      size = 2.5,
      color = "white"
    )
  }
  
  p
}


# =============================================================================
# SAMPLING ADEQUACY
# =============================================================================

#' Species Accumulation Curve
#'
#' @description
#' Shows cumulative species richness over the study period. A plateau
#' suggests most species present have been detected; a continuing upward
#' trend suggests more species would be detected with additional sampling.
#'
#' @param master_data Data frame. Must contain columns:
#'   - species: Character. Species identification code.
#'   - Night: Date. Night of detection (or DateTime to derive Night).
#' @param exclude_noid Logical. If TRUE (default), exclude NoID calls.
#'
#' @return ggplot object showing species accumulation curve.
#'
#' @details
#' This is a simple observed accumulation curve (not rarefied). It shows
#' the cumulative count of unique species detected as the study progresses.
#'
#' Interpretation:
#' - Sharp initial rise: Many common species detected quickly
#' - Plateau: Species pool likely well-sampled
#' - Continued rise: More sampling would likely yield more species
#'
#' Points mark nights when new species were first detected, helping
#' identify when key species entered the study.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Shows cumulative (not nightly) species count
#' - Points indicate first detection of each species
#' - Final species count shown as annotation
#'
#' @section DOES NOT:
#' - Perform rarefaction analysis
#' - Estimate true species richness
#' - Account for detection probability
#' - Project future accumulation
#'
#' @examples
#' \dontrun{
#' p <- plot_species_accumulation_curve(kpro_master)
#' print(p)
#' }
#'
#' @export
plot_species_accumulation_curve <- function(master_data, exclude_noid = TRUE) {
  
  # Validate input
  validate_plot_input(
    master_data,
    required_cols = "species",
    df_name = "master_data"
  )
  
  # Derive Night from DateTime if not present
  if (!"Night" %in% names(master_data)) {
    if ("DateTime" %in% names(master_data)) {
      master_data <- master_data %>%
        dplyr::mutate(Night = as.Date(DateTime))
    } else {
      stop(
        "master_data must contain 'Night' or 'DateTime' column",
        call. = FALSE
      )
    }
  }
  
  # Optionally filter out NoID
  if (exclude_noid) {
    master_data <- master_data %>%
      dplyr::filter(
        !is.na(species),
        !species %in% c("NoID", "UNKNOWN", "")
      )
  }
  
  # Find first detection date for each species
  first_detections <- master_data %>%
    dplyr::group_by(species) %>%
    dplyr::summarise(first_night = min(Night, na.rm = TRUE), .groups = "drop") %>%
    dplyr::arrange(first_night)
  
  # Build accumulation curve for each night in the study
  all_nights <- seq(
    min(master_data$Night),
    max(master_data$Night),
    by = 1
  )
  
  accumulation <- tibble::tibble(Night = all_nights) %>%
    dplyr::mutate(
      cumulative_species = sapply(Night, function(n) {
        sum(first_detections$first_night <= n)
      })
    )
  
  final_richness <- max(accumulation$cumulative_species)
  
  # Build plot
  ggplot(accumulation, aes(x = Night, y = cumulative_species)) +
    geom_line(color = "#009E73", linewidth = 1.2) +
    # Mark nights when new species were detected
    geom_point(
      data = accumulation %>%
        dplyr::filter(Night %in% first_detections$first_night),
      color = "#009E73",
      size = 2
    ) +
    geom_hline(
      yintercept = final_richness,
      linetype = "dashed",
      color = "gray50"
    ) +
    annotate(
      "text",
      x = max(accumulation$Night),
      y = final_richness,
      label = sprintf("%d species", final_richness),
      hjust = 1,
      vjust = -0.5,
      size = 3.5
    ) +
    scale_y_continuous(breaks = seq(0, final_richness + 2, by = 2)) +
    labs(
      title = "Species Accumulation Curve",
      subtitle = "Cumulative species detected over study period",
      x = "Night",
      y = "Cumulative Species"
    ) +
    theme_kpro()
}


# =============================================================================
# ACTIVITY PATTERNS
# =============================================================================

#' Species-Specific Hourly Activity Profiles
#'
#' @description
#' Shows when different species are most active during the night.
#' 
#' DETERMINISTIC DESIGN: This function expects Hour_local column to exist,
#' created deterministically by Module 2. No conditional column creation.
#'
#' @param master_data Data frame. Must contain columns:
#'   - species: Character. Species identification code.
#'   - Hour_local: Integer (0-23). Hour of detection.
#' @param top_n Integer. Number of most common species to display.
#'   Default is 6 to keep the plot readable.
#' @param exclude_noid Logical. If TRUE (default), exclude NoID calls.
#'
#' @return ggplot object showing hourly activity profiles by species.
#'
#' @details
#' Activity is shown as percentage of each species' total calls occurring
#' in each hour. This normalization allows comparison across species with
#' very different total call counts.
#'
#' Common patterns:
#' - Early-active species: Peak in hours 20-22 (shortly after sunset)
#' - Late-active species: Peak in hours 02-04 (early morning)
#' - Bimodal species: Peaks at both dusk and dawn
#'
#' Only the top_n species (by total calls) are shown to keep the plot
#' readable. Use a larger top_n if needed.
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Shows percentage (not count) of each species' activity by hour
#' - Only top_n species displayed
#' - All 24 hours shown on x-axis
#' - Hour_local MUST pre-exist (created in Workflow 02)
#' - DETERMINISTIC: no conditional column creation
#'
#' @section DOES NOT:
#' - Create Hour_local column (expects it pre-created in Workflow 02)
#' - Extract hours from DateTime_local (Hour_local must exist)
#' - Account for variable sunset/sunrise times
#' - Show confidence intervals
#' - Normalize for recording effort differences by hour
#'
#' @examples
#' \dontrun{
#' # Hour_local must exist from Module 2
#' p <- plot_species_hourly_profile(kpro_master)
#'
#' # More species
#' p <- plot_species_hourly_profile(kpro_master, top_n = 10)
#' }
#'
#' @export
plot_species_hourly_profile <- function(master_data,
                                        top_n = 6,
                                        exclude_noid = TRUE) {
  
  # Validate input - Hour_local MUST exist
  validate_plot_input(
    master_data,
    required_cols = c("species", "Hour_local"),
    df_name = "master_data"
  )
  
  # Ensure Hour_local is integer for consistent join operations
  master_data <- master_data %>%
    dplyr::mutate(Hour_local = as.integer(Hour_local))
  
  # Optionally filter out NoID
  if (exclude_noid) {
    master_data <- master_data %>%
      dplyr::filter(
        !is.na(species),
        !species %in% c("NoID", "UNKNOWN", "")
      )
  }
  
  # Identify top N species by total calls
  top_species <- master_data %>%
    dplyr::count(species, sort = TRUE) %>%
    dplyr::slice_head(n = top_n) %>%
    dplyr::pull(species)
  
  # Calculate hourly profiles for top species
  hourly_species <- master_data %>%
    dplyr::filter(species %in% top_species) %>%
    dplyr::count(species, Hour_local, name = "n_calls") %>%
    dplyr::group_by(species) %>%
    dplyr::mutate(pct = n_calls / sum(n_calls) * 100) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(species = factor(species, levels = top_species))
  
  # Ensure all hours represented for each species
  # Complete with integer sequence to match Hour_local type
  hourly_species <- hourly_species %>%
    tidyr::complete(
      species,
      Hour_local = 0L:23L,  # Explicit integer sequence
      fill = list(n_calls = 0, pct = 0)
    )
  
  # Build plot
  ggplot(hourly_species, aes(x = Hour_local, y = pct, color = species)) +
    geom_line(linewidth = 1, alpha = 0.8) +
    geom_point(size = 1.5) +
    scale_x_continuous(breaks = seq(0, 23, by = 2)) +
    scale_color_manual(values = kpro_palette_cat(top_n)) +
    labs(
      title = "Hourly Activity by Species",
      subtitle = sprintf("Top %d species by total calls", top_n),
      x = "Hour of Night",
      y = "% of Species' Calls",
      color = "Species"
    ) +
    theme_kpro()
}


# =============================================================================
# DATA QUALITY
# =============================================================================

#' NoID Proportion by Detector
#'
#' @description
#' Shows what percentage of calls are unidentified (NoID) at each detector.
#' High NoID rates may indicate acoustic interference, unusual species,
#' poor recording quality, or equipment issues.
#'
#' @param master_data Data frame. Must contain columns:
#'   - Detector: Character. Unique detector identifier.
#'   - species: Character. Species identification code.
#'
#' @return ggplot object showing NoID proportion by detector.
#'
#' @details
#' NoID calls are defined as rows where species is:
#' - NA
#' - "NoID"
#' - "UNKNOWN"
#' - Empty string ""
#'
#' Detectors are ordered by descending NoID proportion (worst first),
#' making it easy to identify problematic sites.
#'
#' A horizontal dashed line shows the study-wide average NoID rate
#' for reference.
#'
#' Interpretation:
#' - 0-10%: Excellent (most calls identified)
#' - 10-30%: Typical for field deployments
#' - >30%: May warrant investigation
#'
#' @section CONTRACT:
#' - Returns a ggplot object
#' - Detectors ordered by descending NoID proportion
#' - Study average shown as reference line
#' - Percentage labels on each bar
#'
#' @section DOES NOT:
#' - Diagnose why NoID rates differ
#' - Filter out any data
#' - Account for species-specific identification difficulty
#'
#' @examples
#' \dontrun{
#' p <- plot_noid_proportion(kpro_master)
#' print(p)
#' }
#'
#' @export
plot_noid_proportion <- function(master_data) {
  
  # Validate input
  validate_plot_input(
    master_data,
    required_cols = c("Detector", "species"),
    df_name = "master_data"
  )
  
  # Calculate NoID proportion per detector
  noid_summary <- master_data %>%
    dplyr::mutate(
      is_noid = is.na(species) | species %in% c("NoID", "UNKNOWN", "")
    ) %>%
    dplyr::group_by(Detector) %>%
    dplyr::summarise(
      total_calls = dplyr::n(),
      noid_calls = sum(is_noid),
      pct_noid = noid_calls / total_calls * 100,
      .groups = "drop"
    ) %>%
    dplyr::arrange(dplyr::desc(pct_noid)) %>%
    dplyr::mutate(Detector = factor(Detector, levels = Detector))
  
  # Calculate study-wide average
  overall_pct <- sum(noid_summary$noid_calls) / sum(noid_summary$total_calls) * 100
  
  # Build plot
  ggplot(noid_summary, aes(x = Detector, y = pct_noid)) +
    geom_col(fill = "#D55E00") +
    geom_hline(
      yintercept = overall_pct,
      linetype = "dashed",
      color = "gray40"
    ) +
    geom_text(
      aes(label = sprintf("%.1f%%", pct_noid)),
      vjust = -0.5,
      size = 3
    ) +
    annotate(
      "text",
      x = nrow(noid_summary),
      y = overall_pct,
      label = sprintf("Study avg: %.1f%%", overall_pct),
      hjust = 1,
      vjust = -0.5,
      size = 3,
      color = "gray40"
    ) +
    scale_y_continuous(
      labels = function(x) paste0(x, "%"),
      expand = expansion(mult = c(0, 0.1))
    ) +
    labs(
      title = "Unidentified Calls by Detector",
      subtitle = "Proportion of NoID/Unknown calls",
      x = "Detector",
      y = "% Unidentified"
    ) +
    theme_kpro(rotate_x = TRUE)
}