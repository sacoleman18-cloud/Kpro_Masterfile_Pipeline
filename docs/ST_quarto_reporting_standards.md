# ==============================================================================
# QUARTO & REPORTING STANDARDS
# ==============================================================================
# VERSION: 2.3
# LAST UPDATED: 2026-01-31
# PURPOSE: Quarto integration, report generation, and manifest structure
# ==============================================================================

## 1. QUIET/VERBOSE MODE IMPLEMENTATION

All analysis and visualization functions should support a `verbose` parameter for Shiny/Quarto compatibility:

```r
analyze_data <- function(df, verbose = FALSE) {
  if (verbose) message("Analyzing data...")
  
  result <- df %>%
    summarise(...)
  
  if (verbose) {
    message("[OK] Analysis complete")
    message(sprintf("  Rows processed: %s", format(nrow(df), big.mark = ",")))
  }
  
  invisible(result)
}
```

**Note:** The parameter name `verbose` (default `FALSE`) is preferred over `quiet` (default `FALSE`) for consistency with the orchestrating function pattern. Either is acceptable, but new functions should use `verbose`.

---

## 2. RETURN STRUCTURED RESULTS

Functions should return lists for complex outputs:

```r
generate_analysis <- function(df, verbose = FALSE) {
  if (verbose) message("  Generating analysis...")
  
  list(
    summary = summary_stats,
    table = gt_object,
    plot = ggplot_object,
    metadata = list(
      n_rows = nrow(df),
      generated = Sys.time(),
      version = "1.0"
    )
  )
}
```

**Orchestrating functions** (like `run_finalize_to_report()`) return comprehensive structured lists including:
- Primary data outputs
- Processing metadata
- Artifact IDs
- File paths (checkpoint, validation HTML)

---

## 3. RDS OUTPUT PATTERN FOR PLOT REUSE

Save all plots for Quarto documents:

```r
# In Chunk 3 / Workflow 06: Save all plots
all_plots <- list(
  quality = list(
    recording_status_summary = plot_recording_status_summary(cpn),
    recording_status_percent = plot_recording_status_percent(cpn),
    # ... etc
  ),
  detector = list(
    correlation_heatmap = plot_correlation_heatmap(cpn),
    # ... etc
  )
)

saveRDS(all_plots, here("results", "rds", 
        sprintf("plot_objects_%s.rds", format(Sys.Date(), "%Y%m%d"))))
```

```r
# In Quarto document: Load plots
all_plots <- readRDS(here("results", "rds", "plot_objects_20250107.rds"))

# Access individual plots
all_plots$quality$recording_status_summary
all_plots$detector$correlation_heatmap
```

---

## 4. QUARTO CHUNK BEST PRACTICES

```r
#| label: fig-activity-over-time
#| fig-cap: "Bat activity across the study period"
#| fig-width: 10
#| fig-height: 6

all_plots$temporal$activity_over_time
```

```r
#| label: tbl-detector-summary
#| tbl-cap: "Summary statistics by detector"

gt_detector_summary(calls_per_night_final)
```

**Quarto Integration Rules:**

| Scope | Rule | Enforcement Example |
|-------|------|---------------------|
| Verbose mode | All functions support `verbose = FALSE` | [OK] `if (verbose) message(...)` |
| Return objects | Return data/plots, never print | [OK] `invisible(result)` |
| Structured results | Return lists with named components | [OK] `list(table = ..., plot = ...)` |
| ggplot objects | Return ggplot, don't call `print()` | [OK] `ggplot(...) + theme_kpro()` |
| No hardcoded formats | Never specify PDF vs HTML | [X] `ggsave(..., device = "pdf")` |
| Config-driven | Parameters in YAML, not hardcoded | [OK] `smooth_k <- params$smooth_k` |

---

## 5. CHUNK 3 / WORKFLOW 07 REPORT STANDARDS

The report generation stage (part of Chunk 3 or standalone Workflow 07) auto-generates a publication-grade Quarto report from pre-computed objects. It is **read-only** with respect to analytical results—no computation, transformation, or plot generation occurs.

### 5.1 Directory Structure

**Template location:**

```
reports/
└── bat_activity_report.qmd    # Quarto template
```

**Output location:**

```
results/reports/
└── bat_activity_report_YYYYMMDD.html
```

**RULES:**

- [OK] Templates live in `reports/` at project root
- [OK] Rendered outputs go to `results/reports/`
- [OK] Output filenames include date stamp
- [X] NEVER put .qmd files in `R/` or `inst/`

### 5.2 Report Template Requirements

**YAML Header (required elements):**

```yaml
---
title: "Bat Acoustic Monitoring Report"
subtitle: "KPro Masterfile Pipeline Output"
date: today
format:
  html:
    theme: cosmo
    toc: true
    toc-depth: 3
    toc-location: left
    number-sections: true
    self-contained: true
    fig-width: 10
    fig-height: 6
    fig-dpi: 150
params:
  summary_rds: ""
  plots_rds: ""
  study_params_path: ""
execute:
  echo: false
  warning: false
  message: false
---
```

**RULES:**

- [OK] Use parameterized rendering (`params:` block)
- [OK] Self-contained HTML (`self-contained: true`)
- [OK] Suppress code/warnings/messages by default
- [OK] Consistent figure dimensions across all plots
- [X] NEVER hardcode RDS file paths in the template

### 5.3 Programmatic Plot Iteration

Reports must iterate over plot collections programmatically rather than referencing individual plots by name. This ensures completeness and reduces maintenance burden.

**Pattern using purrr::iwalk:**

```r
#| label: quality-plots
#| results: asis

purrr::iwalk(all_plots$quality, function(plot_obj, plot_name) {
  
  # Emit markdown header
  cat(sprintf("\n\n## %s\n\n", snake_to_title(plot_name)))
  
  # Print plot
  print(plot_obj)
  
  # Emit caption
  cat(sprintf("\n\n*%s*\n\n", make_caption(plot_name, "quality")))
})
```

**Key elements:**

- `results: asis` allows raw markdown output from `cat()`
- `purrr::iwalk()` provides both object and name
- `print()` required inside loops (ggplot doesn't auto-print)

**RULES:**

- [OK] Iterate over all plots in each category
- [OK] Use `results: asis` for dynamic headers
- [OK] Explicitly `print()` ggplot objects in loops
- [X] NEVER hardcode individual plot names
- [X] NEVER skip plots without documenting why

### 5.4 Caption Standards

Every plot must have an automatically generated caption. Captions should be descriptive, not interpretive.

**Helper function:**

```r
snake_to_title <- function(x) {
  x %>%
    str_replace_all("_", " ") %>%
    str_to_title()
}

make_caption <- function(plot_name, category) {
  base <- snake_to_title(plot_name)
  sprintf("%s. Generated from standardized pipeline output.", base)
}
```

**Caption requirements:**

- [OK] Describe what is shown (not what it means)
- [OK] Reference data source when relevant
- [OK] Use formal, neutral scientific language
- [X] NEVER include interpretation or inference
- [X] NEVER use casual language

**Examples:**

```
[OK] "Recording Status Summary. Generated from standardized pipeline output."
[OK] "Species composition by detector showing call counts per species."
[X] "This plot shows that Detector A performed poorly."
[X] "Interesting pattern in the correlation matrix!"
```

### 5.5 Conditional Sections

Some sections (e.g., species) may not apply to all datasets. Use conditional rendering.

**Pattern for optional sections:**

```r
#| label: species-section-check
#| results: asis

has_species <- !is.null(all_plots$species) && length(all_plots$species) > 0

if (has_species) {
  cat("\n\n# Species Composition\n\n")
  cat("This section presents species-level detection patterns.\n\n")
}
```

```r
#| label: species-plots
#| results: asis
#| eval: !expr has_species

# This chunk only runs if has_species is TRUE
purrr::iwalk(all_plots$species, function(plot_obj, plot_name) {
  # ... iteration logic
})
```

**RULES:**

- [OK] Check for data presence before rendering section
- [OK] Use `eval: !expr variable` for conditional chunks
- [OK] Document why sections may be skipped
- [X] NEVER show empty sections or error messages

### 5.6 Required Report Sections

Every auto-generated report must include these sections (in order):

| Section | Purpose | Data Source |
|---------|---------|-------------|
| Study Overview | Study metadata, parameters | `study_parameters.yaml`, `all_summaries$metadata` |
| Data Quality & Coverage | Recording status, effort, completeness | `all_plots$quality` |
| Detector Activity | Activity comparisons, correlations | `all_plots$detector` |
| Species Composition | Species patterns (conditional) | `all_plots$species` |
| Temporal Patterns | Time-based activity patterns | `all_plots$temporal` |
| Summary Statistics | Tables from summary stage | `all_summaries$detector_summary`, etc. |
| Reproducibility | Session info, file references | R session, params |

### 5.7 Reproducibility Footer

Every report must end with reproducibility information:

```r
#| label: session-info

tibble::tibble(
  Item = c("Report Generated", "R Version", "Platform",
           "Summary Data File", "Plot Objects File"),
  Value = c(
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    paste(R.version$major, R.version$minor, sep = "."),
    R.version$platform,
    basename(params$summary_rds),
    basename(params$plots_rds)
  )
) %>%
  gt() %>%
  tab_header(title = "Session Information")
```

**RULES:**

- [OK] Include timestamp of report generation
- [OK] Include R version and platform
- [OK] Reference source RDS files by name
- [OK] Include full `sessionInfo()` (can be collapsed)

### 5.8 Report Generation in Orchestrating Functions

When using the chunk model, report generation is part of `run_finalize_to_report()`:

```r
run_finalize_to_report <- function(verbose = FALSE) {
  
  # ... earlier stages (finalize CPN, generate stats, generate plots) ...
  
  # Stage N: Generate Quarto Report
  if (verbose) print_stage_header("N", "Generate Quarto Report")
  
  report_path <- render_report(
    summary_rds = summary_rds_path,
    plots_rds = plots_rds_path,
    study_params_path = yaml_path,
    verbose = verbose
  )
  
  # File logging always happens
  log_message(sprintf("[Stage N] Report rendered: %s", basename(report_path)))
  
  # Return path in structured result
  list(
    # ... other outputs ...
    report_path = report_path
  )
}
```

### 5.9 Legacy Workflow 07 Orchestration Script

For standalone Workflow 07 usage, the `07_generate_report.R` script must:

1. **Discover RDS files** - Find most recent `summary_data_*.rds` and `plot_objects_*.rds`
2. **Validate structure** - Check for required elements before rendering
3. **Load configuration** - Read `study_parameters.yaml` for metadata
4. **Render report** - Call `quarto::quarto_render()` with parameters
5. **Create release bundle** - Package outputs for downstream projects
6. **Move output** - Place rendered HTML in `results/reports/`

**Validation requirements:**

```r
# Required elements in summary_data RDS
required_summary_names <- c("detector_summary", "study_summary", "metadata")

# Required categories in plot_objects RDS
required_plot_categories <- c("quality", "detector", "temporal")

# Species is optional
has_species <- !is.null(all_plots$species) && length(all_plots$species) > 0
```

**RULES:**

- [OK] Fail fast if required RDS files missing
- [OK] Validate RDS structure before rendering
- [OK] Pass file paths via `execute_params`
- [OK] Log report generation to pipeline log
- [X] NEVER compute statistics in report generation
- [X] NEVER generate new plots in report generation

### 5.10 Report Rules Summary

| Scope | Rule | Enforcement |
|-------|------|-------------|
| Read-only | No computation or transformation | [X] `df %>% mutate(...)` |
| No new plots | Use pre-computed objects only | [X] `ggplot(df, ...)` |
| Parameterized | File paths via params, not hardcoded | [OK] `params$summary_rds` |
| Complete | All plots in RDS must appear in report | [OK] `purrr::iwalk()` |
| Deterministic | Same inputs -> same report | [OK] No random elements |
| Self-contained | Single HTML file, no external deps | [OK] `self-contained: true` |
| Captioned | Every plot has auto-generated caption | [OK] `make_caption()` |
| Reproducible | Session info in footer | [OK] `sessionInfo()` |

---

## 6. MANIFEST STRUCTURE

The manifest (`manifest.YAML`) provides comprehensive provenance documentation for the entire pipeline run. It serves as the single source of truth for reproducibility verification and audit compliance.

**Location:** Project root (`manifest.YAML`) and in each release bundle

### 6.1 Manifest Sections

The manifest contains 9 major sections:

| Section | Purpose |
|---------|---------|
| 1. Release Metadata | Pipeline version, timestamps, Git info |
| 2. Study Metadata | Ecological study parameters |
| 3. Source Inputs | Raw data files with hashes |
| 4. Artifacts | All outputs with provenance |
| 5. Processing Summary | Transformation statistics |
| 6. Validation Summary | QA results |
| 7. Data Integrity | SHA256 hashes and provenance chain |
| 8. Notes and Warnings | Human-readable issues |
| 9. Manifest Metadata | Self-documentation |

### 6.2 Release Metadata (Section 1)

```yaml
release_metadata:
  release_name: "kpro_release_<STUDY_ID>_<YYYYMMDD_HHMMSS>"
  release_id: "<UUID>"
  created_at_utc: "<YYYY-MM-DDTHH:MM:SSZ>"
  pipeline_version: "2.1"
  coding_standards_version: "2.3"
  
  git_info:
    commit_sha: "<40_CHAR_SHA>"
    branch: "main"
    tag: "v2.1.0"
    is_dirty: false
    remote_url: "https://github.com/user/repo"
  
  generator:
    script: "run_finalize_to_report.R"  # Or "07_generate_report.R"
    r_version: "4.3.2"
    platform: "x86_64-w64-mingw32"
    locale: "LC_COLLATE=English_United States.utf8"
```

### 6.3 Study Metadata (Section 2)

```yaml
study_metadata:
  study_id: "<STUDY_ID>"
  study_name: "<HUMAN_READABLE_NAME>"
  
  temporal_scope:
    start_date: "<YYYY-MM-DD>"
    end_date: "<YYYY-MM-DD>"
    duration_days: <INTEGER>
    timezone: "America/Chicago"
  
  spatial_scope:
    n_detectors: <INTEGER>
    detector_ids:
      - id: "<HARDWARE_ID>"
        name: "<FRIENDLY_NAME>"
  
  effort_summary:
    total_detector_nights: <INTEGER>
    total_recording_hours: <FLOAT>
    mean_hours_per_night: <FLOAT>
    
  recording_schedule:
    advanced_scheduling: false
    recording_start: "20:00:00"
    recording_end: "06:00:00"
    intended_hours_per_night: 10
```

### 6.4 Source Inputs (Section 3)

```yaml
source_inputs:
  local_sources:
    directory: "data/raw/"
    file_count: <INTEGER>
    total_rows: <INTEGER>
    files:
      - filename: "<FILENAME>.csv"
        rows: <INTEGER>
        size_bytes: <INTEGER>
        sha256: "<SHA256_HASH>"
        schema_versions_detected:
          - version: "v1_legacy_single_column"
            row_count: <INTEGER>
          - version: "v3_modern_6letter"
            row_count: <INTEGER>
  
  external_sources:
    - path: "<EXTERNAL_PATH>"
      files_found: <INTEGER>
      files_valid: <INTEGER>
      total_rows: <INTEGER>
      sha256_aggregate: "<SHA256_OF_ALL_FILE_HASHES>"
  
  input_totals:
    total_files_processed: <INTEGER>
    total_rows_ingested: <INTEGER>
    rows_removed_n_zero_or_na: <INTEGER>
```

### 6.5 Data Integrity (Section 7)

```yaml
data_integrity:
  algorithm: "SHA256"
  
  source_hashes:
    local_raw_files:
      - file: "<FILENAME>.csv"
        sha256: "<SHA256_HASH>"
    combined_input_hash: "<SHA256_HASH>"
  
  config_hash:
    study_parameters_yaml: "<SHA256_HASH>"
  
  artifact_hashes:
    checkpoint_01_intro_standardized: "<SHA256_HASH>"
    cpn_final: "<SHA256_HASH>"
    masterfile_final: "<SHA256_HASH>"
  
  provenance_chain:
    - step: 1
      name: "raw_inputs"
      hash: "<COMBINED_INPUT_HASH>"
      inputs: null
    - step: 2
      name: "intro_standardized"
      hash: "<SHA256_HASH>"
      inputs: ["raw_inputs", "study_parameters_yaml"]
    # ... continues through pipeline
  
  release_fingerprint: "<SHA256_HASH>"
```

### 6.6 Notes and Warnings (Section 8)

```yaml
notes_and_warnings:
  schema_notes:
    - severity: "info"
      code: "MIXED_SCHEMAS_DETECTED"
      message: "Multiple KPro schema versions detected"
      details:
        v1_count: 299
        v3_count: 1314
        recommendation: "Normal for multi-year studies"
  
  data_quality_notes:
    - severity: "warning"
      code: "PARTIAL_NIGHTS_DETECTED"
      message: "Some nights have < expected recording hours"
      details:
        count: 75
        percentage: 29.8
  
  data_filters_applied:
    remove_duplicates: true
    remove_noid: false
    remove_zero_pulse_calls: false
  
  summary:
    total_notes: <INTEGER>
    by_severity:
      info: <INTEGER>
      warning: <INTEGER>
      error: <INTEGER>
```

### 6.7 Manifest Self-Documentation (Section 9)

```yaml
manifest_metadata:
  manifest_version: "1.0"
  manifest_schema: "kpro_release_manifest_v1"
  generated_by: "run_finalize_to_report.R"
  generated_at_utc: "<YYYY-MM-DDTHH:MM:SSZ>"
  manifest_hash: "<SHA256_HASH>"  # Hash of manifest excluding this field
  
  documentation:
    project_overview: "docs/Project_Overview.md"
    coding_standards: "CODING_STANDARDS_v2.3.md"
    repository: "https://github.com/user/repo"
```

### 6.8 Manifest Generation

The manifest is generated during report/release stage:

```r
# Simplified pattern - actual implementation in release.R
manifest <- list(
  release_metadata = build_release_metadata(),
  study_metadata = build_study_metadata(study_params),
  source_inputs = build_source_inputs(registry),
  artifacts = build_artifacts_section(registry),
  data_integrity = build_integrity_section(registry),
  notes_and_warnings = collect_notes_and_warnings(),
  manifest_metadata = build_manifest_metadata()
)

yaml::write_yaml(manifest, "manifest.yaml")
```
