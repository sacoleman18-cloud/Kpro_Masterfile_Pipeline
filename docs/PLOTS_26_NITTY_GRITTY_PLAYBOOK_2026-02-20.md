# Plots Ecosystem Nitty-Gritty Playbook (All 26 Plots)

## Purpose
This deliverable provides plot-by-plot technical analysis for all 26 plots in Module 6, including:
- plot construction details
- relevant calculations and derived variables
- where input variables are created and stored upstream
- how plot objects and PNG outputs move through the pipeline
- concrete ideas for improvements/features/refactors/error-handling/DRY

This document is intentionally detailed and is meant to be cross-referenced with:
- `docs/PLOTS_ECOSYSTEM_HYPER_ANALYSIS_2026-02-20.md`

---

## 1) End-to-End Plot Data Lineage (Upstream -> Plot -> Report/Release)

## 1.1 Core upstream variable creation
- `calls_per_night_final` is finalized in Module 4 (`finalize_cpn`) where:
  - `RecordingHours` is recalculated and sanitized
  - `Status` is classified (`Fail/Success/Partial`)
  - `CallsPerHour` is computed as `CallsPerNight / RecordingHours` when hours > 0
- `kpro_master` is expected to already contain:
  - `species` (created in Phase 2 / Module 3)
  - `Hour_local` and `DateTime_local` (created in Phase 1 / Module 2)

## 1.2 Plot generation and storage
- Module 6 (`module_plotting`) builds four in-memory categories:
  - `all_plots$quality` (8)
  - `all_plots$detector` (7)
  - `all_plots$species` (5)
  - `all_plots$temporal` (6)
- Stage 20 exports every ggplot object in `all_plots` to PNG via `export_plots_png()`.
- Stage 21 saves full object graph to RDS: `results/rds/plot_objects_YYYYMMDD.rds`.

## 1.3 Movement downstream
- Module 7 (`report_release`) loads `summary_rds_path` and `plots_rds_path` using `readRDS()`.
- Quarto report (`reports/bat_activity_report.qmd`) iterates category lists and prints all plots.
- Release bundle includes report + data + plots via `create_and_register_release()`.

---

## 2) Plot Inventory with Technical Details (All 26)

Legend:
- **Input source**: `calls_per_night_final` or `kpro_master`
- **Derived vars**: intermediate calculations inside plot function
- **Edge handling**: explicit NA/empty/variance guards
- **Ideas**: targeted suggestions

---

## 2.1 Quality (8)

### Q1 `recording_status_summary`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `Status`
- **Derived vars**:
  - `n_nights` by detector/status
  - `total_nights` by detector
  - `pct` status share per detector
  - label positions via cumulative sums
- **Edge handling**:
  - factor-level standardization for status
- **Ideas**:
  - add deterministic tie-break ordering for equal success-rate detectors
  - optional label collision control for many detectors

### Q2 `recording_status_percent`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `Status`
- **Derived vars**:
  - detector/status night counts
  - per-detector percentages
  - sorted detector order by Success pct
- **Edge handling**:
  - uses position fill; 90% guideline line
- **Ideas**:
  - optional configurable threshold line from YAML
  - expose normalized values table in returned attrs for audit/debug

### Q3 `recording_status_overall`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Status`
- **Derived vars**:
  - `n_nights`, `pct`, center total label
- **Edge handling**:
  - status factor normalization
- **Ideas**:
  - accessibility mode: replace donut with horizontal bar for print-friendliness
  - optional include raw count labels in legend

### Q4 `effort_by_detector`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `RecordingHours`
- **Derived vars**:
  - `total_hours`, `n_nights`, `mean_hours`
  - `study_mean` ref line
- **Edge handling**:
  - `na.rm = TRUE`
- **Ideas**:
  - dual-axis alternative removed (avoid clutter), but optional facet for `total` vs `mean`
  - configurable precision and units text

### Q5 `nights_by_detector`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`
- **Derived vars**:
  - `n_nights` per detector
  - optional `below_threshold` flag
- **Edge handling**:
  - threshold mode optional
- **Ideas**:
  - threshold defaults from study config
  - optional sort by expected-minus-actual nights when expected window is known

### Q6 `data_completeness_calendar`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `Night`
- **Derived vars**:
  - full detector x night grid
  - binary `has_data`
  - `week = floor_date(Night, "week")`
- **Edge handling**:
  - complete grid guarantees explicit missingness
- **Ideas**:
  - optional alternative granularity (`day` vs `week` x-axis)
  - optional detector ordering by completeness

### Q7 `missing_nights`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `Night`
- **Derived vars**:
  - `expected_nights` from global date range
  - `actual_nights`, `missing_nights`, `pct_complete`
- **Edge handling**:
  - deterministic expected window from min/max night
- **Ideas**:
  - support staggered deployment windows from schedule metadata
  - explicit option to compute expected_nights per detector deployment start/end

### Q8 `recording_effort_heatmap`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `Night`, `RecordingHours`
- **Derived vars**:
  - full detector x night grid with joined hours
- **Edge handling**:
  - guard for all-NA `Night` (returns informative placeholder plot)
- **Ideas**:
  - optional mode to plot `CallsPerHour` heatmap using same scaffold (DRY helper)
  - make palette/theme consistent with `kpro_palette_seq()` wrapper

---

## 2.2 Detector (7)

### D1 `total_calls_by_detector`
- **Input source**: `kpro_master`
- **Required columns**: `Detector`
- **Derived vars**:
  - `TotalCalls = count(Detector)`
- **Edge handling**:
  - deterministic sort desc by total
- **Ideas**:
  - optionally normalize by effort (calls/hour) as companion overlay/secondary plot

### D2 `detector_activity_caterpillar`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `CallsPerNight`
- **Derived vars**:
  - `mean_calls`, `sd_calls`, `n`, `se`, CI bounds
  - `overall_mean` line
- **Edge handling**:
  - `n <= 1` gives NA SE/CI
- **Ideas**:
  - optional robust CI (bootstrap / quantile intervals)
  - optional switch mean vs median center metric

### D3 `detector_boxplots`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `CallsPerNight`
- **Derived vars**:
  - detector order by median
- **Edge handling**:
  - NA ignored via ggplot stat behavior
- **Ideas**:
  - optional log y-scale toggle for high skew datasets
  - optional jitter overlay toggle (small alpha)

### D4 `activity_with_without_outliers`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `CallsPerNight`
- **Derived vars**:
  - per-detector 95th percentile threshold
  - `is_outlier`
  - combined `All Data` vs `Without Outliers`
- **Edge handling**:
  - detector-specific threshold avoids global distortion
- **Ideas**:
  - parameterize percentile (`0.95`) via function arg/config
  - include retained fraction metric in subtitle by detector

### D5 `synchrony`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `Night`, `CallsPerNight`
- **Derived vars**:
  - none beyond grouping aesthetics
- **Edge handling**:
  - relies on input integrity
- **Ideas**:
  - optional rolling mean overlay to reduce noise
  - optional center/scale standardization by detector for shape-only synchrony view

### D6 `correlation_heatmap`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `Night`, `CallsPerNight`
- **Derived vars**:
  - wide detector matrix by night
  - zero-variance detector filtering
  - Pearson matrix with pairwise complete obs
  - long-form correlation table
- **Edge handling**:
  - excludes zero-variance detectors with warning
  - fallback placeholder when <2 detectors remain
- **Ideas**:
  - optional method parameter (`pearson`, `spearman`)
  - optional significance masking / sample-size per cell annotation

### D7 `detector_rank_over_time`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `Night`, `CallsPerNight`
- **Derived vars**:
  - rolling mean (`zoo::rollmean`) by detector
  - per-night rank from rolling values
- **Edge handling**:
  - removes rows without sufficient rolling window history
- **Ideas**:
  - handle missing `zoo` dependency gracefully with informative fallback
  - optional tie method parameter and rank-stability summary metrics

---

## 2.3 Species (5)

### S1 `species_composition_bar`
- **Input source**: `kpro_master`
- **Required columns**: `species`
- **Derived vars**:
  - species totals
  - optional top-N slicing
  - percentage within displayed set
- **Edge handling**:
  - optional `exclude_noid`
- **Ideas**:
  - if top-N is used, add explicit "Other" bin option to preserve full proportion context

### S2 `species_by_detector_heatmap`
- **Input source**: `kpro_master`
- **Required columns**: `Detector`, `species`
- **Derived vars**:
  - complete detector x species grid
  - `n_calls` per cell
  - species order by total
  - optional formatted cell labels
- **Edge handling**:
  - complete() fills zeros
- **Ideas**:
  - optional per-detector normalization mode (within-column percentages)
  - optional minimum count threshold for text labels

### S3 `species_accumulation_curve`
- **Input source**: `kpro_master`
- **Required columns**: `species`, plus `Night` or `DateTime`
- **Derived vars**:
  - first detection per species
  - nightly cumulative richness
  - `final_richness`
- **Edge handling**:
  - if `Night` absent, derives from `DateTime`
  - optional noid exclusion
- **Ideas**:
  - align with deterministic schema contract by requiring `Night` only (or document this intentional exception)
  - add optional effort-scaled x-axis (detector-nights)

### S4 `species_hourly_profile`
- **Input source**: `kpro_master`
- **Required columns**: `species`, `Hour_local`
- **Derived vars**:
  - top species by total calls
  - hourly count and within-species percentage
  - complete species x hour grid (0:23)
- **Edge handling**:
  - deterministic assumption: `Hour_local` pre-exists
- **Ideas**:
  - optional circular-time display variant (polar) for nocturnal activity interpretation
  - configurable top-N default in module settings

### S5 `noid_proportion`
- **Input source**: `kpro_master`
- **Required columns**: `Detector`, `species`
- **Derived vars**:
  - `is_noid` flag
  - `total_calls`, `noid_calls`, `pct_noid`
  - study-wide `overall_pct`
- **Edge handling**:
  - NA/empty/unknown species treated as NoID
- **Ideas**:
  - add confidence interval bars for proportion uncertainty where sample sizes are low

---

## 2.4 Temporal (6)

### T1 `activity_over_time`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Detector`, `Night`, `CallsPerNight`
- **Derived vars**:
  - filtered `plot_data` removing NA in key columns
  - detector count for palette sizing
- **Edge handling**:
  - placeholder plot when no valid data after filtering
- **Ideas**:
  - optional detector faceting mode for high-detector studies
  - optional trend smoother toggle (`geom_smooth`)

### T2 `cumulative_calls_over_time`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Night`, `CallsPerNight` (+ optional `Detector`)
- **Derived vars**:
  - detector-level or study-level cumulative sums
- **Edge handling**:
  - warns/falls back to study-wide if `by_detector=TRUE` but no Detector column
- **Ideas**:
  - return cumulative table as attribute for downstream diagnostics/QA

### T3 `hourly_activity_profile`
- **Input source**: `kpro_master`
- **Required columns**: `Hour_local`
- **Derived vars**:
  - hourly totals (or mean hourly calls by night)
  - complete hour grid 0:23
  - peak-hour annotation
- **Edge handling**:
  - deterministic assumption on pre-existing `Hour_local`
- **Ideas**:
  - avoid hard dependency on `DateTime_local` in mean mode by requiring/providing explicit nightly key

### T4 `callsperhour_distribution`
- **Input source**: `calls_per_night_final`
- **Required columns**: `CallsPerHour`
- **Derived vars**:
  - finite-data subset
  - `mean_cph`, `median_cph`
- **Edge handling**:
  - placeholder plot if all values NA/Inf
  - optional log scale
- **Ideas**:
  - configurable clipping/zoom for extreme tails
  - optional density overlay

### T5 `weekly_activity`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Night`, `CallsPerNight` (+ optional `Detector`)
- **Derived vars**:
  - week floor date, iso week
  - `total_calls`, `n_nights`, `mean_calls`
- **Edge handling**:
  - fallback to non-detector mode if detector missing
- **Ideas**:
  - optional normalize by nights active each week (currently totals only)

### T6 `activity_by_month`
- **Input source**: `calls_per_night_final`
- **Required columns**: `Night`, `CallsPerNight` (+ optional `Detector`)
- **Derived vars**:
  - month floor date
  - monthly totals (and optional stacked detector totals)
- **Edge handling**:
  - fallback to study-wide if detector column missing
- **Ideas**:
  - optional rate normalization by active nights per month
  - multi-year label strategy for long studies

---

## 3) How Plots Are Moved Around (Operational Lifecycle)

1. **Construction**: Module 6 Stages 16-19 creates ggplot objects into `quality_plots`, `detector_plots`, `species_plots`, `temporal_plots`.
2. **In-memory registry**: all categories are assembled under `all_plots`.
3. **File export**: Stage 20 `export_plots_png(all_plots, base_dir=results/figures/png, width=10, height=7, dpi=300)` writes PNG files by category.
4. **Object persistence**: Stage 21 saves `all_plots` into `plot_objects_YYYYMMDD.rds` using `save_and_register_rds()`.
5. **Report consumption**: Module 7 reads RDS and Quarto iterates through all categories with `purrr::iwalk()` to print every plot.
6. **Release packaging**: release bundle includes report plus figures and metadata.

---

## 4) Error Handling: Current State and Recommended Policy

## 4.1 Current state
- Category-level try/catch for quality/detector/temporal; failure clears entire category list.
- Species category is fail-fast (`stop()`), unlike other categories.
- Export helper catches per-plot export failures (good), but generation is still category-fragile.

## 4.2 Recommended policy
- Adopt **non-fatal per-plot generation policy**:
  - each plot wrapped individually
  - failures captured to `failed_plot_details`
  - module continues and exports successful plots
  - optionally enforce fail-fast only for truly mandatory plots via config

---

## 5) DRY Refactor Opportunities (Concrete)

## 5.1 In `module_plotting`
- Introduce helper `generate_plot_group_safely(group_name, builders_named_list, context_inputs, verbose)`
- Introduce helper `summarize_plot_group_result(group_result)`
- This removes repetitive stage blocks and standardizes diagnostics.

## 5.2 In plot modules
- Standardize repeated patterns:
  - complete hour/date grids
  - detector ordering by metric
  - empty-data placeholder plotting
- Add helper(s) in `plot_helpers.R`:
  - `build_empty_plot(title, message)`
  - `complete_hours_0_23(df, hour_col, fill_list)`
  - `order_factor_by_metric(df, group_col, metric_col, desc=TRUE)`

## 5.3 Export controls parity
- Add `artifact_outputs` toggles for plotting, matching summary/table design consistency:
  - `png_quality_plots`, `png_detector_plots`, `png_species_plots`, `png_temporal_plots`, `rds_plot_objects`

---

## 6) Feature Ideas (High Value, Low-to-Medium Risk)

1. **Configurable thresholds**
   - status threshold (currently 90%), outlier percentile (currently 95%), nights warning cutoff.
2. **Normalization modes**
   - optional effort-normalized variants where currently totals dominate.
3. **Per-plot metadata sidecar**
   - store calculation summaries for each plot (n rows, filters applied, key params) to improve auditability.
4. **Consistent placeholder plots**
   - standardized visual/message for no-data situations.
5. **Statistical context overlays**
   - optional CI bands / uncertainty markers where informative and non-overinterpreting.

---

## 7) Cross-Reference to Hyper Analysis Document

Reference doc:
- `docs/PLOTS_ECOSYSTEM_HYPER_ANALYSIS_2026-02-20.md`

Crosswalk:

| Hyper Analysis Topic | Nitty-Gritty Support in This Doc | Actionability |
|---|---|---|
| Contract drift in error policy | Sections 4.1, 4.2 | Specifies exact per-plot policy direction |
| Missing plot artifact controls | Sections 5.3, 6.1 | Proposes concrete config keys |
| Runner/lineage semantics | Sections 1.1-1.3, 3 | Shows full variable and artifact movement |
| Fault isolation granularity | Sections 4, 5.1 | Defines helper refactor pattern |
| Naming/doc drift | Section 3 + lifecycle notes | Clarifies actual movement and naming behavior |
| Manifest/docs drift | Sections 1, 3 | Provides canonical runtime behavior baseline |

---

## 8) Proposed Execution Order for Implementation

1. Standardize error policy (per-plot non-fatal with ledger).
2. Add plot artifact output controls and defaults.
3. Refactor module plotting stage blocks into group helper(s).
4. Add helper utilities for repeated empty/complete/order patterns.
5. Align docs/manifest examples to canonical behavior.
6. Validate end-to-end with one full Phase 3 run.

---

## 9) Notes for Upcoming User-Notes Merge
When user notes are provided, map each note to:
- plot ID(s): Q1-Q8, D1-D7, S1-S5, T1-T6
- type: feature / bug / style / policy / refactor / docs
- scope: single-plot vs ecosystem-wide
- risk level: low/medium/high
- implementation priority: P0/P1/P2

This will produce the final integrated plan across both analysis documents.
