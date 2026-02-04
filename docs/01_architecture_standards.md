# ==============================================================================
# ARCHITECTURE STANDARDS
# ==============================================================================
# VERSION: 2.3
# LAST UPDATED: 2026-01-31
# PURPOSE: Project structure, file naming, paths, and workflow organization
# ==============================================================================

## 1. DIRECTORY STRUCTURE

```
project_root/
├── R/
│   ├── pipeline/
│   │   ├── run_ingest_standardize.R   # Chunk 1: Raw CSVs -> kpro_master
│   │   ├── run_cpn_template.R         # Chunk 2: Generate CPN template
│   │   └── run_finalize_to_report.R   # Chunk 3: Finalize -> Report
│   ├── workflows/
│   │   ├── 01_ingest_raw_data.R
│   │   ├── 02_standardize.R
│   │   ├── 03_generate_cpn_template.R
│   │   ├── 04_finalize_cpn.R
│   │   ├── 05_summary_stats.R
│   │   ├── 06_exploratory_plots.R
│   │   └── 07_generate_report.R
│   └── functions/
│       ├── core/
│       │   ├── config.R
│       │   ├── utilities.R
│       │   ├── artifacts.R          # Artifact registry & hashing
│       │   ├── release.R            # Release bundle creation
│       │   └── load_all.R
│       ├── ingestion/
│       │   ├── ingestion.R
│       │   └── schema_detection.R
│       ├── standardization/
│       │   ├── standardization.R
│       │   └── datetime_conversion.R
│       ├── validation/
│       │   └── validation.R
│       ├── analysis/
│       │   ├── callspernight.R
│       │   └── summarization.R
│       └── output/
│           ├── plot_helpers.R
│           ├── plot_quality.R
│           ├── plot_detector.R
│           ├── plot_species.R
│           ├── plot_temporal.R
│           ├── tables.R
│           └── report.R
├── inst/
│   └── config/
│       ├── study_parameters.yaml
│       └── artifact_registry.yaml   # Formal artifact tracking
├── reports/
│   └── bat_activity_report.qmd
├── data/
│   └── raw/
├── outputs/
│   ├── checkpoints/
│   └── final/
├── results/
│   ├── figures/
│   │   ├── png/
│   │   │   ├── quality/
│   │   │   ├── detector/
│   │   │   ├── species/
│   │   │   └── temporal/
│   │   └── svg/
│   ├── tables/
│   ├── csv/
│   ├── rds/
│   ├── reports/
│   ├── validation/                  # Validation HTML/YAML reports
│   └── releases/                    # Release bundle zips
├── logs/
├── docs/
│   └── standards/                   # Modular coding standards
├── tests/
├── manifest.YAML                    # Comprehensive provenance manifest
└── CODING_STANDARDS_v2.3.md         # Combined reference (optional)
```

**RULES:**
- [OK] All paths relative to project root
- [OK] Use `here::here()` for cross-platform compatibility
- [OK] `results/` directory for Workflow 05/06/07 outputs
- [OK] `checkpoints/` vs `final/` distinction in outputs
- [OK] `results/validation/` for all workflow validation reports
- [OK] `results/releases/` for portable release bundles
- [OK] `inst/config/artifact_registry.yaml` for artifact tracking
- [X] NEVER hardcode absolute paths
- [X] NEVER reference parent directories (`../`)
- [X] NEVER commit user data to version control
- [X] NEVER put analysis outputs in `outputs/` (use `results/`)
- [OK] Orchestrators must use shared helpers:
  `print_stage_banner()`, `init_stage_validation()/complete_stage_validation()`,
  `save_and_register_rds()`, `store_stage_results()`,
  `find_most_recent_checkpoint()`, `load_cpn_template()`

---

## 2. FILE NAMING CONVENTIONS

### 2.1 Orchestrating Functions (Pipeline)

```
run_ingest_standardize.R
run_cpn_template.R
run_finalize_to_report.R
```
Format: `run_verb_noun.R` (action-oriented, snake_case)

### 2.2 Workflow Scripts (Legacy)

```
01_ingest_raw_data.R
02_standardize.R
03_generate_cpn_template.R
04_finalize_cpn.R
05_summary_stats.R
06_exploratory_plots.R
07_generate_report.R
```
Format: `##_verb_noun.R` (numbered, descriptive, snake_case)

### 2.3 Function Files

```
schema_detection.R
datetime_conversion.R
recording_hours.R
artifacts.R
release.R
```
Format: `noun_noun.R` or `verb_noun.R` (descriptive, snake_case)

### 2.4 Plot Module Files

```
plot_quality.R
plot_detector.R
plot_species.R
plot_temporal.R
plot_helpers.R
```
Format: `plot_[category].R`

### 2.5 Output Files

**From Chunk 1 / Workflows 01-02:**
```
outputs/checkpoints/02_kpro_master_YYYYMMDD_HHMMSS.csv
results/validation/validation_ingest_YYYYMMDD_HHMMSS.html
```

**From Chunk 2 / Workflow 03:**
```
outputs/final/03_CallsPerNight_Template_ORIGINAL_YYYYMMDD_HHMMSS.csv
outputs/final/03_CallsPerNight_Template_EDIT_THIS_YYYYMMDD_HHMMSS.csv
```

**From Chunk 3 / Workflows 04-07:**
```
results/csv/CallsPerNight_final_v1.csv
results/tables/gt_study_overview_YYYYMMDD.html
results/figures/png/quality/recording_status_summary_YYYYMMDD.png
results/rds/summary_data_YYYYMMDD.rds
results/rds/plot_objects_YYYYMMDD.rds
results/reports/bat_activity_report_YYYYMMDD.html
results/releases/kpro_release_<study_id>_YYYYMMDD_HHMMSS.zip
```

**Validation Reports (any chunk/workflow):**
```
results/validation/validation_ingest_YYYYMMDD_HHMMSS.html
results/validation/validation_ingest_YYYYMMDD_HHMMSS.yaml
```

Format: `##_description_YYYYMMDD_HHMMSS.csv` or `description_vN.csv`

**RULES:**
- [OK] Use snake_case for all files
- [OK] Include timestamps for checkpoints
- [OK] Version numbers for final outputs
- [OK] Descriptive names (no abbreviations like `tmp`, `data1`, `final_FINAL_v2`)
- [X] NEVER use spaces in filenames
- [X] NEVER use special characters except `_` and `-`

---

## 3. EXECUTION MODELS

The pipeline supports two execution models:

### 3.1 Shiny-Driven Chunks (Primary)

Orchestrating functions designed for Shiny app integration. Each returns a structured list and has no global side effects.

| Chunk | Function | Input | Output | Decision Point |
|-------|----------|-------|--------|----------------|
| 1 | `run_ingest_standardize()` | Raw CSVs, YAML config | kpro_master, validation HTML | Export for Manual ID? |
| 2 | `run_cpn_template()` | kpro_master | CPN template | Edit recording hours? |
| 3 | `run_finalize_to_report()` | Edited CPN template | Final CPN, plots, report | - |

**Chunk characteristics:**
- Silent by default (`verbose = FALSE`)
- All configuration from YAML (no interactive prompts)
- Return structured lists with data, metadata, and paths
- Always save checkpoints and register artifacts
- Always render validation HTML at completion

**Example Shiny integration:**
```r
# Button click handler
observeEvent(input$run_chunk1, {
  result <- run_ingest_standardize(verbose = FALSE)
  
  # Update UI with results
  output$row_count <- renderText(result$metadata$n_rows)
  output$validation_link <- renderUI(
    a("View Validation", href = result$validation_html_path)
  )
})
```

### 3.2 Legacy Workflow Scripts (Interactive/Debug)

Individual R scripts for interactive execution in RStudio. Still functional but not recommended for production.

```
R/workflows/
├── 01_ingest_raw_data.R      # Source: data/raw/, external
├── 02_standardize.R          # Source: WF01 checkpoint
├── 03_generate_cpn_template.R
├── 04_finalize_cpn.R
├── 05_summary_stats.R
├── 06_exploratory_plots.R
└── 07_generate_report.R
```

**When to use legacy scripts:**
- Debugging specific transformation steps
- Exploring data interactively
- Running single workflows in isolation
- Teaching/demonstration purposes

**When NOT to use:**
- Production Shiny app execution
- Automated pipelines
- When you need structured return values

---

## 4. LAYER RESPONSIBILITIES

Each workflow/chunk has a distinct purpose. These roles are architectural guarantees, not suggestions.

### 4.1 Chunk-to-Workflow Mapping

| Chunk Function | Equivalent Workflows | Primary Output |
|---------------|---------------------|----------------|
| `run_ingest_standardize()` | WF01 + WF02 | kpro_master |
| `run_cpn_template()` | WF03 | CPN template pair |
| `run_finalize_to_report()` | WF04 + WF05 + WF06 + WF07 | Final CPN, report |

### 4.2 Chunk 1: Ingest & Standardize Layer

**Purpose:** Transform raw KPro CSVs into unified kpro_master dataset.

**Processing Stages:**
1. Load YAML configuration
2. Discover/load local + external CSV files
3. Transform schemas (v1/v2/v3 -> unified)
4. Apply detector mapping
5. Convert timestamps (UTC -> local timezone)
6. Finalize schema + optional deduplication
7. Apply user-configured data filters (NoID, zero-pulse)
8. Save checkpoint, register artifact, render validation HTML

**Data Filters (YAML-configured):**
```yaml
data_filters:
  remove_duplicates: true      # Stage 6
  remove_noid: false           # Stage 7
  remove_zero_pulse_calls: false  # Stage 7
```

**Returns:**
```r
list(
  kpro_master = tibble,
  metadata = list(n_rows, rows_removed, data_filters_applied, ...),
  artifact_id = "kpro_master_YYYYMMDD_HHMMSS",
  checkpoint_path = "outputs/checkpoints/02_kpro_master_*.csv",
  validation_html_path = "results/validation/validation_ingest_*.html"
)
```

**Allowed actions:**
- Read raw CSV files from `data/raw/` and external sources
- Apply intro standardization
- Detect and transform schemas (v1/v2/v3)
- Write checkpoints to `outputs/checkpoints/`
- Register artifacts in registry
- Generate validation reports

**Explicitly forbidden:**
- Analysis or aggregation
- Plotting or visualization
- Modifying study_parameters.yaml after initial setup

### 4.3 Chunk 2: Template Generation Layer

**Purpose:** Generate CallsPerNight template, optional manual ID import, species unification.

**Allowed actions:**
- Read kpro_master from Chunk 1
- Generate CPN template with recording schedules
- Import manual ID files (optional)
- Create unified `species` column
- Write template to `outputs/` for user editing
- Register artifacts in registry

**Explicitly forbidden:**
- Modifying kpro_master source
- Final CPN calculations (that's Chunk 3)
- Plotting or analysis

### 4.4 Chunk 3: Finalize Through Report Layer

**Purpose:** Process user-edited template, calculate Status/CallsPerHour, generate stats/plots/report.

**Allowed actions:**
- Read user-edited template
- Calculate recording hours, Status, CallsPerHour
- Validate data quality
- Generate summary statistics and GT tables
- Generate ggplot objects and save PNG/SVG
- Render Quarto report to HTML
- Create release bundle zip
- Write final CPN to `results/csv/`
- Register all artifacts

**Explicitly forbidden:**
- Modifying the original template
- Modifying any upstream outputs

**Critical principle:** Chunk 3 integrates four legacy workflows but maintains their separation of concerns internally.

### 4.5 Layer Responsibility Rules

| Scope | Rule | Enforcement Example |
|-------|------|---------------------|
| Data flow | Data flows forward only (Chunk 1 -> 2 -> 3) | [X] Chunk 3 modifying Chunk 1 output |
| Layer separation | Each chunk has defined stages | [X] Plotting in finalization stage |
| Output locations | Analysis outputs go to `results/`, not `outputs/` | [OK] `results/figures/png/` for plots |
| Source immutability | Never modify upstream outputs | [X] Chunk 3 editing `kpro_master` |
| Artifact registration | All persistent outputs registered | `register_artifact()` at chunk end |
| Validation reports | Every chunk generates validation report | `finalize_validation_report()` |

### 4.6 Pipeline Flow Diagram

**Chunk Model (Shiny-Driven):**
```
  run_ingest_standardize()
         |
         +---> [kpro_master]
         +---> [validation_ingest.html]
         +---> artifact_registry
               |
               v
     +===========================+
     |  DECISION: Manual ID?     |
     +===========================+
               |
               v
  run_cpn_template()
         |
         +---> [cpn_template_original]
         +---> [cpn_template_editable] ---> USER EDITS
         +---> artifact_registry
               |
               v
     +===========================+
     |  DECISION: Edit hours?    |
     +===========================+
               |
               v
  run_finalize_to_report()
         |
         +---> [cpn_final]
         +---> [summary_data.rds]
         +---> [plot_objects.rds]
         +---> [report.html]
         +---> [release_bundle.zip]
         +---> artifact_registry
```

**Legacy Workflow Model:**
```
  01_ingest  ->  02_standardize  ->  03_cpn_template  ->  [USER EDIT]
       |              |                   |
       v              v                   v
  [intro_std]    [kpro_master]    [cpn_templates]
                                         |
                                         v
                              04_finalize  ->  05_stats  ->  06_plots  ->  07_report
                                   |            |            |            |
                                   v            v            v            v
                              [cpn_final]  [summary.rds] [plots.rds] [report.html]
```

---

## 5. PATH MANAGEMENT

### 5.1 Using here::here()

**ALWAYS use here::here() for paths:**
```r
library(here)

# [OK] GOOD: Cross-platform, relative to project root
data_file <- here("data", "raw", "detector_A1.csv")
output_file <- here("outputs", "checkpoints", "01_intro_standardized.csv")

# [X] BAD: Hardcoded absolute path
data_file <- "C:/Users/John/bat_project/data/raw/detector_A1.csv"

# [X] BAD: Relative path (breaks if working directory changes)
data_file <- "data/raw/detector_A1.csv"
```

**RULES:**
- [OK] Use `here::here()` for ALL file paths
- [OK] Build paths from components (not strings)
- [OK] Use forward slashes (/) even on Windows
- [X] NEVER use `setwd()`
- [X] NEVER use absolute paths
- [X] NEVER use `../` parent directory notation

### 5.2 Dynamic Path Generation

**For timestamped outputs:**
```r
make_timestamped_path <- function(base_dir, prefix, extension = "csv") {
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  filename <- sprintf("%s_%s.%s", prefix, timestamp, extension)
  here::here(base_dir, filename)
}

# Usage
output_path <- make_timestamped_path("outputs/checkpoints", "01_intro_standardized")
# Result: /path/to/project/outputs/checkpoints/01_intro_standardized_20251226_143022.csv
```

---

## 6. NAMING CONVENTIONS

### 6.1 Function Naming

**Pattern: verb_noun() or verb_noun_context()**

```r
# [OK] GOOD: Action-oriented, clear purpose
load_raw_data()
calculate_recording_hours()
validate_study_config()
plot_species_composition()
gt_detector_summary()
register_artifact()
create_release_bundle()
run_ingest_standardize()      # Orchestrating function

# [X] BAD: Vague or noun-only
data()
hours()
config()
species()
```

**Plot function naming:**
```r
# Pattern: plot_[what]_[how]()
plot_recording_status_summary()
plot_species_by_detector_heatmap()
plot_activity_over_time()
```

**GT table function naming:**
```r
# Pattern: gt_[what]_[scope]()
gt_study_overview()
gt_detector_summary()
gt_species_composition()
```

**Console formatting function naming:**
```r
# Pattern: print_[what]_[type]()
print_stage_header()
print_workflow_summary()
print_pipeline_complete()
```

**Assertion function naming:**
```r
# Pattern: assert_[condition]()
assert_file_exists()
assert_columns_exist()
assert_not_empty()
assert_data_frame()
```

### 6.2 File Naming

**Orchestrating function files:**
```r
# Pattern: run_[chunk_name].R
run_ingest_standardize.R
run_cpn_template.R
run_finalize_to_report.R
```

**Plot module file naming:**
```r
# Pattern: plot_[category].R
plot_quality.R    # Recording quality plots
plot_detector.R   # Detector activity plots
plot_species.R    # Species composition plots
plot_temporal.R   # Temporal pattern plots
plot_helpers.R    # Shared utilities
```

### 6.3 Consistent Terminology

**Use these terms consistently:**
- `detector` (not sensor, unit, device)
- `auto_id` (not species, species_code, id)
- `calls_per_night` (not cpn, nightly_calls)
- `recording_hours` (not hours, duration)
- `artifact` (not output, product, result) - for registered outputs
- `validation_context` (not log, tracker) - for validation tracking
- `chunk` (not workflow) - for orchestrating functions
- `verbose` (not quiet) - for console output control
