# =============================================================================
# UTILITY: plot_species2.R - Species Advanced Visualizations
# =============================================================================
# Classification: Helper/Utility Function Module
# - Part of R/functions/ → Contains reusable helper functions only
# PURPOSE
# -------
# Provides additional species-focused plots to extend the species
# visualization ecosystem without overloading plot_species.R.
#
# All functions return ggplot2 objects that can be further customized,
# combined with other plots, or saved using ggsave().
#
# DEPENDENCIES
# ------------
# External Packages:
#   - ggplot2: All plotting
#   - dplyr: Data manipulation for plot preparation
#   - tidyr: complete() and pivoting
#   - lubridate: Date/time manipulation
#   - scales: Axis formatting
#
# Internal Dependencies:
#   - plot_helpers.R: theme_kpro(), validate_plot_input(), kpro_palette_species(),
#                     kpro_scale_detector_fill(), format_number()
#
# FUNCTIONS PROVIDED
# ------------------
#
# Species Temporal Detail:
#   - plot_species_nightly_activity(): Nightly activity by species (faceted)
#   - plot_species_phenology_heatmap(): Species x time heatmap (night/week/month)
#   - plot_species_turnover(): New species per period with cumulative line
#   - plot_noid_richness_over_time(): NoID % and richness over time
#
# Species Composition Detail:
#   - plot_species_by_detector_composition(): Stacked species composition by detector
#   - plot_species_rank_abundance(): Rank-abundance plot of species counts
#
# USAGE
# -----
# source("R/functions/output/plot_helpers.R")  # Must be first
# source("R/functions/output/plot_species2.R")
#
# Last Modified: 2026-02-20
# =============================================================================


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

derive_species_night <- function(df) {
  if ("Night" %in% names(df)) {
    df$Night <- as.Date(df$Night)
    return(df)
  }

  if ("DateTime_local" %in% names(df)) {
    df$Night <- as.Date(df$DateTime_local)
    return(df)
  }

  if ("DateTime" %in% names(df)) {
    df$Night <- as.Date(df$DateTime)
    return(df)
  }

  stop(
    "master_data must contain 'Night', 'DateTime_local', or 'DateTime' column",
    call. = FALSE
  )
}

filter_noid_species <- function(df) {
  df %>%
    dplyr::filter(
      !is.na(species),
      !species %in% c("NoID", "UNKNOWN", "")
    )
}

# =============================================================================
# SPECIES TEMPORAL DETAIL
# =============================================================================

#' Nightly Activity by Species
#'
#' @description
#' Shows nightly call counts by species. Intended to reveal short-term
#' variation in species activity across the study period.
#'
#' @param master_data Data frame. Must contain species and a date/time column.
#' @param top_n Integer or NULL. If set, limits to top N species by total calls.
#'   Default is NULL (all species).
#' @param exclude_noid Logical. If TRUE (default), exclude NoID calls.
#' @param show_points Logical. If TRUE, show points on top of lines.
#'
#' @return ggplot object showing nightly activity per species (faceted).
#'
#' @export
plot_species_nightly_activity <- function(master_data,
                                          top_n = NULL,
                                          exclude_noid = TRUE,
                                          show_points = FALSE) {
  validate_plot_input(
    master_data,
    required_cols = "species",
    df_name = "master_data"
  )

  master_data <- derive_species_night(master_data)
  validate_plot_input(master_data, required_cols = "Night", date_cols = "Night")

  if (exclude_noid) {
    master_data <- filter_noid_species(master_data)
  }

  nightly_counts <- master_data %>%
    dplyr::count(species, Night, name = "n_calls")

  if (!is.null(top_n)) {
    top_species <- nightly_counts %>%
      dplyr::group_by(species) %>%
      dplyr::summarise(total = sum(n_calls), .groups = "drop") %>%
      dplyr::arrange(dplyr::desc(total)) %>%
      dplyr::slice_head(n = top_n) %>%
      dplyr::pull(species)

    nightly_counts <- nightly_counts %>%
      dplyr::filter(species %in% top_species)
  }

  species_order <- nightly_counts %>%
    dplyr::group_by(species) %>%
    dplyr::summarise(total = sum(n_calls), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(total)) %>%
    dplyr::pull(species)

  nightly_counts <- nightly_counts %>%
    dplyr::mutate(species = factor(species, levels = species_order))

  n_species <- dplyr::n_distinct(nightly_counts$species)

  p <- ggplot(
    nightly_counts,
    aes(x = Night, y = n_calls, color = species, group = species)
  ) +
    geom_line(alpha = 0.8) +
    scale_color_manual(values = kpro_palette_species(n_species)) +
    labs(
      title = "Nightly Activity by Species",
      x = "Night",
      y = "Calls Per Night",
      color = "Species"
    ) +
    theme_kpro() +
    theme(legend.position = "none")

  if (show_points) {
    p <- p + geom_point(size = 1.2, alpha = 0.7)
  }

  p + facet_wrap(~species, scales = "free_y")
}


#' Species Phenology Heatmap
#'
#' @description
#' Heatmap of species detections across time (night/week/month bins).
#'
#' @param master_data Data frame. Must contain species and a date/time column.
#' @param time_bin Character. One of "night", "week", "month".
#' @param top_n Integer or NULL. If set, limits to top N species by total calls.
#' @param exclude_noid Logical. If TRUE (default), exclude NoID calls.
#'
#' @return ggplot object showing species activity heatmap.
#'
#' @export
plot_species_phenology_heatmap <- function(master_data,
                                           time_bin = c("night", "week", "month"),
                                           top_n = NULL,
                                           exclude_noid = TRUE) {
  validate_plot_input(
    master_data,
    required_cols = "species",
    df_name = "master_data"
  )

  time_bin <- match.arg(time_bin)
  master_data <- derive_species_night(master_data)
  validate_plot_input(master_data, required_cols = "Night", date_cols = "Night")

  if (exclude_noid) {
    master_data <- filter_noid_species(master_data)
  }

  time_col <- dplyr::case_when(
    time_bin == "night" ~ master_data$Night,
    time_bin == "week" ~ lubridate::floor_date(master_data$Night, "week"),
    TRUE ~ lubridate::floor_date(master_data$Night, "month")
  )

  master_data <- master_data %>%
    dplyr::mutate(TimeBin = time_col)

  counts <- master_data %>%
    dplyr::count(species, TimeBin, name = "n_calls")

  if (!is.null(top_n)) {
    top_species <- counts %>%
      dplyr::group_by(species) %>%
      dplyr::summarise(total = sum(n_calls), .groups = "drop") %>%
      dplyr::arrange(dplyr::desc(total)) %>%
      dplyr::slice_head(n = top_n) %>%
      dplyr::pull(species)

    counts <- counts %>%
      dplyr::filter(species %in% top_species)
  }

  species_order <- counts %>%
    dplyr::group_by(species) %>%
    dplyr::summarise(total = sum(n_calls), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(total)) %>%
    dplyr::pull(species)

  counts <- counts %>%
    dplyr::mutate(species = factor(species, levels = rev(species_order))) %>%
    tidyr::complete(
      species,
      TimeBin,
      fill = list(n_calls = 0)
    )

  ggplot(counts, aes(x = TimeBin, y = species, fill = n_calls)) +
    geom_tile(color = "white") +
    scale_fill_viridis_c(
      option = "viridis",
      trans = "log1p",
      labels = scales::comma,
      name = "Calls"
    ) +
    labs(
      title = "Species Phenology",
      subtitle = sprintf("Time bin: %s", time_bin),
      x = "Time",
      y = "Species"
    ) +
    theme_kpro(rotate_x = TRUE) +
    theme(panel.grid = element_blank())
}


#' Species Turnover Over Time
#'
#' @description
#' Shows how many new species are detected per time bin, with a cumulative
#' species line overlaid.
#'
#' @param master_data Data frame. Must contain species and a date/time column.
#' @param time_bin Character. One of "night", "week", "month".
#' @param exclude_noid Logical. If TRUE (default), exclude NoID calls.
#'
#' @return ggplot object showing new species per time bin.
#'
#' @export
plot_species_turnover <- function(master_data,
                                  time_bin = c("night", "week", "month"),
                                  exclude_noid = TRUE) {
  validate_plot_input(
    master_data,
    required_cols = "species",
    df_name = "master_data"
  )

  time_bin <- match.arg(time_bin)
  master_data <- derive_species_night(master_data)
  validate_plot_input(master_data, required_cols = "Night", date_cols = "Night")

  if (exclude_noid) {
    master_data <- filter_noid_species(master_data)
  }

  first_detections <- master_data %>%
    dplyr::group_by(species) %>%
    dplyr::summarise(first_night = min(Night, na.rm = TRUE), .groups = "drop")

  first_detections <- first_detections %>%
    dplyr::mutate(
      TimeBin = dplyr::case_when(
        time_bin == "night" ~ first_night,
        time_bin == "week" ~ lubridate::floor_date(first_night, "week"),
        TRUE ~ lubridate::floor_date(first_night, "month")
      )
    )

  turnover <- first_detections %>%
    dplyr::count(TimeBin, name = "new_species") %>%
    dplyr::arrange(TimeBin) %>%
    dplyr::mutate(cumulative_species = cumsum(new_species))

  ggplot(turnover, aes(x = TimeBin)) +
    geom_col(aes(y = new_species), fill = "#56B4E9") +
    geom_line(aes(y = cumulative_species), color = "#0072B2", linewidth = 1) +
    geom_point(aes(y = cumulative_species), color = "#0072B2", size = 2) +
    labs(
      title = "Species Turnover",
      subtitle = sprintf("New species per %s with cumulative line", time_bin),
      x = "Time",
      y = "Count"
    ) +
    theme_kpro(rotate_x = TRUE)
}


#' NoID Rate and Species Richness Over Time
#'
#' @description
#' Compares unidentified call rate with species richness across time.
#'
#' @param master_data Data frame. Must contain species and a date/time column.
#'
#' @return ggplot object with two facets (NoID % and richness).
#'
#' @export
plot_noid_richness_over_time <- function(master_data) {
  validate_plot_input(
    master_data,
    required_cols = "species",
    df_name = "master_data"
  )

  master_data <- derive_species_night(master_data)
  validate_plot_input(master_data, required_cols = "Night", date_cols = "Night")

  nightly_summary <- master_data %>%
    dplyr::mutate(
      is_noid = is.na(species) | species %in% c("NoID", "UNKNOWN", "")
    ) %>%
    dplyr::group_by(Night) %>%
    dplyr::summarise(
      total_calls = dplyr::n(),
      noid_calls = sum(is_noid),
      pct_noid = ifelse(total_calls > 0, noid_calls / total_calls * 100, NA_real_),
      richness = dplyr::n_distinct(species[!is_noid]),
      .groups = "drop"
    )

  plot_data <- nightly_summary %>%
    dplyr::select(Night, pct_noid, richness) %>%
    tidyr::pivot_longer(
      cols = c(pct_noid, richness),
      names_to = "metric",
      values_to = "value"
    ) %>%
    dplyr::mutate(
      metric = dplyr::recode(
        metric,
        pct_noid = "NoID %",
        richness = "Species Richness"
      )
    )

  ggplot(plot_data, aes(x = Night, y = value)) +
    geom_line(color = "#0072B2", linewidth = 1) +
    geom_point(color = "#0072B2", size = 1.5) +
    facet_wrap(~metric, scales = "free_y", ncol = 1) +
    labs(
      title = "NoID Rate and Species Richness Over Time",
      x = "Night",
      y = "Value"
    ) +
    theme_kpro()
}


# =============================================================================
# SPECIES COMPOSITION DETAIL
# =============================================================================

#' Species Composition by Detector
#'
#' @description
#' Shows species composition at each detector using stacked bars.
#'
#' @param master_data Data frame. Must contain Detector and species columns.
#' @param top_n Integer or NULL. If set, limits to top N species by total calls.
#' @param exclude_noid Logical. If TRUE (default), exclude NoID calls.
#' @param normalize Logical. If TRUE, shows percentages within detector.
#'
#' @return ggplot object showing species composition by detector.
#'
#' @export
plot_species_by_detector_composition <- function(master_data,
                                                 top_n = NULL,
                                                 exclude_noid = TRUE,
                                                 normalize = FALSE) {
  validate_plot_input(
    master_data,
    required_cols = c("Detector", "species"),
    df_name = "master_data"
  )

  if (exclude_noid) {
    master_data <- filter_noid_species(master_data)
  }

  species_counts <- master_data %>%
    dplyr::count(Detector, species, name = "n_calls")

  if (!is.null(top_n)) {
    top_species <- species_counts %>%
      dplyr::group_by(species) %>%
      dplyr::summarise(total = sum(n_calls), .groups = "drop") %>%
      dplyr::arrange(dplyr::desc(total)) %>%
      dplyr::slice_head(n = top_n) %>%
      dplyr::pull(species)

    species_counts <- species_counts %>%
      dplyr::filter(species %in% top_species)
  }

  species_order <- species_counts %>%
    dplyr::group_by(species) %>%
    dplyr::summarise(total = sum(n_calls), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(total)) %>%
    dplyr::pull(species)

  species_counts <- species_counts %>%
    dplyr::mutate(species = factor(species, levels = species_order))

  n_species <- dplyr::n_distinct(species_counts$species)

  p <- ggplot(species_counts, aes(x = Detector, y = n_calls, fill = species)) +
    geom_col(position = if (normalize) "fill" else "stack") +
    scale_fill_manual(values = kpro_palette_species(n_species)) +
    labs(
      title = "Species Composition by Detector",
      subtitle = if (normalize) "Percent within detector" else "Raw call counts",
      x = "Detector",
      y = if (normalize) "Percent" else "Calls",
      fill = "Species"
    ) +
    theme_kpro(rotate_x = TRUE)

  if (normalize) {
    p <- p + scale_y_continuous(labels = scales::percent)
  } else {
    p <- p + scale_y_continuous(labels = scales::comma)
  }

  p
}


#' Species Rank-Abundance Plot
#'
#' @description
#' Shows species abundance ranked from most to least common.
#'
#' @param master_data Data frame. Must contain species column.
#' @param exclude_noid Logical. If TRUE (default), exclude NoID calls.
#' @param log_scale Logical. If TRUE (default), use log10 y-axis.
#'
#' @return ggplot object showing rank-abundance.
#'
#' @export
plot_species_rank_abundance <- function(master_data,
                                        exclude_noid = TRUE,
                                        log_scale = TRUE) {
  validate_plot_input(
    master_data,
    required_cols = "species",
    df_name = "master_data"
  )

  if (exclude_noid) {
    master_data <- filter_noid_species(master_data)
  }

  species_counts <- master_data %>%
    dplyr::count(species, name = "n_calls") %>%
    dplyr::arrange(dplyr::desc(n_calls)) %>%
    dplyr::mutate(rank = dplyr::row_number())

  p <- ggplot(species_counts, aes(x = rank, y = n_calls)) +
    geom_line(color = "#0072B2", linewidth = 1) +
    geom_point(color = "#0072B2", size = 2) +
    labs(
      title = "Species Rank-Abundance",
      x = "Rank (most common to rarest)",
      y = "Total Calls"
    ) +
    theme_kpro()

  if (log_scale) {
    p <- p + scale_y_log10(labels = scales::comma)
  } else {
    p <- p + scale_y_continuous(labels = scales::comma)
  }

  p
}
