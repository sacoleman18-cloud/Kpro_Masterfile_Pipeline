# ==============================================================================
# ARCHITECTURE STANDARDS
# ==============================================================================
# VERSION: 2.5
# LAST UPDATED: 2026-02-05
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
│       │   ├── config.R              # YAML configuration management
│       │   ├── utilities.R           # Foundational utilities (I/O, paths, orchestrator helpers)
│       │   ├── logging.R             # File logging utilities
│       │   ├── console.R             # Console formatting utilities
│       │   ├── artifacts.R           # Artifact registry & file provenance
│       │   ├── release.R             # Release bundle creation
│       │   └── load_all.R
│       ├── ingestion/
│       │   ├── ingestion.R
│       │   └── schema_detection.R
│       ├── standardization/
│       │   ├── standardization.R     # Schema transformation
│       │   └── datetime_helpers.R    # Datetime parsing & timezone conversion
│       ├── validation/
│       │   ├── validation.R          # Data validation & assertions
│       │   └── validation_reporting.R # Execution tracking & report generation
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
- All paths must be relative to project root
- Use `here::here()` for cross-platform compatibility
- `results/` directory for Workflow 05/06/07 outputs
- `checkpoints/` vs `final/` distinction in outputs
- `results/validation/` for all workflow validation reports
- `results/releases/` for portable release bundles
- `inst/config/artifact_registry.yaml` for artifact tracking
- Absolute paths are prohibited
- Parent directory references (`../`) are prohibited
- User data must not be committed to version control
- Analysis outputs must not be placed in `outputs/` (use `results/`)

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
- Use snake_case for all files
- Include timestamps for checkpoints
- Version numbers for final outputs
- Descriptive names (no abbreviations like `tmp`, `data1`, `final_FINAL_v2`)
- Spaces in filenames are prohibited
- Special characters except `_` and `-` are prohibited

---

## 3. ORCHESTRATOR FUNCTION STRUCTURE

### 3.1 Primary Execution Model: Shiny-Driven Chunks

Orchestrating functions (`run_*`) are designed for Shiny app integration. Each function is a self-contained pipeline stage that returns structured data and has no global side effects.

| Chunk | Function | Input | Output | Decision Point |
|-------|----------|-------|--------|----------------|
| 1 | `run_ingest_standardize()` | Raw CSVs, YAML config | kpro_master, validation HTML | Export for Manual ID? |
| 2 | `run_cpn_template()` | kpro_master | CPN template | Edit recording hours? |
| 3 | `run_finalize_to_report()` | Edited CPN template | Final CPN, plots, report | - |

**Design Principles:**
- Silent by default (`verbose = FALSE`)
- All configuration from YAML (no interactive prompts)
- Return structured lists with data, metadata, and paths
- Always save checkpoints and register artifacts
- Always render validation HTML at completion
- Use helper functions for common orchestration patterns

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

### 3.2 Orchestrator Function Header Template

All orchestrator functions must follow this standardized header structure (see `run_finalize_to_report.R`):

```r
# ==============================================================================
# R/pipeline/run_[chunk_name].R
# ==============================================================================
# PURPOSE
# -------
# Brief description of what this chunk accomplishes in the pipeline.
#
# PIPELINE POSITION
# -----------------
# Layer: pipeline/orchestration (Chunk X of 3)
#   run_ingest_standardize()  -> Chunk 1: Raw CSVs to kpro_master
#   run_cpn_template()        -> Chunk 2: Generate CPN template
#   run_finalize_to_report()  -> Chunk 3: Finalize through Report
#
# DECISION POINTS (handled by Shiny app):
#   Before/After this chunk: User decisions required
#
# PROCESSING STAGES
# -----------------
#   Stage 1: [Description]
#   Stage 2: [Description]
#   ...
#
# CONTRACT
# --------
# INPUTS:
#   - List of required input files/data
#
# OUTPUTS:
#   - List of all generated outputs
#
# GUARANTEES:
#   - All paths use here::here()
#   - Silent by default (verbose = FALSE)
#   - No interactive prompts
#   - File logging always active
#   - Returns comprehensive structured list
#
# DOES NOT:
#   - Modify global environment
#   - Prompt for user input
#   - Skip checkpoints or artifact saving
#
# DEPENDENCIES
# ------------
# Custom functions: List of required function modules
#
# CHANGELOG
# ---------
# Version history with dates
```

### 3.3 Orchestrator Helper Functions

The following helper functions standardize common orchestration tasks (see `core/utilities.R`):

**Pipeline Context Setup:**
```r
setup_pipeline_context(workflow_name)
# Loads YAML config and initializes validation context
```

**Checkpoint Management:**
```r
load_most_recent_checkpoint(pattern)
# Discovers and loads most recent checkpoint file by pattern
# Example: load_most_recent_checkpoint("02_kpro_master_.*")
```

**Path Generation:**
```r
generate_timestamped_filename(prefix, suffix = "")
make_output_path(workflow_num, description, extension = "csv")
make_versioned_path(workflow_num, description, version, extension = "csv")
```

**Artifact Management:**
```r
save_and_register_rds(object, file_path, artifact_type, workflow, registry, metadata, verbose)
# Atomically saves RDS file and registers with SHA256 hash
```

**Validation Reporting:**
```r
init_stage_validation(stage_name, study_params)
complete_stage_validation(validation_context, validation_dir, stage_name, verbose)
# Standardized validation lifecycle for each workflow stage
```

**Console Formatting (see `core/console.R`):**
```r
print_stage_header(stage_name, width = 65)
print_workflow_summary(workflow_name, duration, metadata, width = 65)
print_pipeline_complete(total_duration, chunk_count, width = 65)
```

**File Logging (see `core/logging.R`):**
```r
log_message(message)
initialize_pipeline_log(workflow_name)
# Always active regardless of verbose setting
```

### 3.4 Structured Return Format

All orchestrator functions must return a structured list containing:

```r
list(
  # Primary data output
  data = tibble_or_list,
  
  # Execution metadata
  metadata = list(
    n_rows = integer,
    processing_time = difftime,
    filters_applied = character_vector,
    # Stage-specific metrics
  ),
  
  # Artifact identification
  artifact_id = character,
  
  # Output file paths
  checkpoint_path = character,
  validation_html_path = character,
  # Additional output paths as needed
)
```

### 3.5 Legacy Workflow Scripts (Interactive/Debug)

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
- When structured return values are required

---

## 4. LAYER RESPONSIBILITIES AND PROCESSING STAGES

Each chunk has a distinct purpose with defined processing stages. These roles are architectural guarantees enforced through standardized orchestration patterns.

### 4.1 Chunk-to-Workflow Mapping

| Chunk Function | Equivalent Workflows | Primary Output |
|---------------|---------------------|----------------|
| `run_ingest_standardize()` | WF01 + WF02 | kpro_master |
| `run_cpn_template()` | WF03 | CPN template pair |
| `run_finalize_to_report()` | WF04 + WF05 + WF06 + WF07 | Final CPN, report |

### 4.2 Chunk 1: Ingest & Standardize Layer

**Purpose:** Transform raw KPro CSVs into unified kpro_master dataset.

**Processing Stages:**
```
Stage 1: Load configuration (YAML)
Stage 2: Discover and load CSV files (local + external)
Stage 3: Transform schemas (v1/v2/v3 -> unified)
Stage 4: Apply detector mapping
Stage 5: Convert timestamps (UTC -> local timezone)
Stage 6: Finalize schema + optional deduplication
Stage 7: Apply user-configured data filters (NoID, zero-pulse)
Stage 8: Save checkpoint, register artifact, render validation HTML
```

**Data Filters (YAML-configured):**
```yaml
data_filters:
  remove_duplicates: true      # Applied in Stage 6
  remove_noid: false           # Applied in Stage 7
  remove_zero_pulse_calls: false  # Applied in Stage 7
```

**Returns:**
```r
list(
  kpro_master = tibble,
  metadata = list(
    n_rows = integer,
    rows_removed = list(duplicates, noid, zero_pulse),
    data_filters_applied = character_vector,
    processing_time = difftime
  ),
  artifact_id = "kpro_master_YYYYMMDD_HHMMSS",
  checkpoint_path = "outputs/checkpoints/02_kpro_master_*.csv",
  validation_html_path = "results/validation/validation_ingest_*.html"
)
```

**Allowed Operations:**
- Read raw CSV files from `data/raw/` and external sources
- Apply intro standardization
- Detect and transform schemas (v1/v2/v3)
- Write checkpoints to `outputs/checkpoints/`
- Register artifacts in registry
- Generate validation reports

**Prohibited Operations:**
- Analysis or aggregation operations
- Plotting or visualization generation
- Modifying study_parameters.yaml after initial setup

### 4.3 Chunk 2: Template Generation Layer

**Purpose:** Generate CallsPerNight template with recording schedules, optional manual ID import, and species unification.

**Processing Stages:**
```
Stage 1: Load configuration and kpro_master
Stage 2: Generate CPN template with recording schedules
Stage 3: Import manual ID files (optional)
Stage 4: Create unified species column
Stage 5: Write template pair (ORIGINAL + EDIT_THIS)
Stage 6: Register artifacts
```

**Returns:**
```r
list(
  cpn_template = tibble,
  metadata = list(
    n_detectors = integer,
    n_nights = integer,
    manual_id_imported = logical,
    processing_time = difftime
  ),
  artifact_id = "cpn_template_YYYYMMDD_HHMMSS",
  template_original_path = "outputs/final/03_CallsPerNight_Template_ORIGINAL_*.csv",
  template_editable_path = "outputs/final/03_CallsPerNight_Template_EDIT_THIS_*.csv"
)
```

**Allowed Operations:**
- Read kpro_master from Chunk 1
- Generate CPN template with recording schedules
- Import manual ID files (optional)
- Create unified `species` column
- Write template to `outputs/` for user editing
- Register artifacts in registry

**Prohibited Operations:**
- Modifying kpro_master source data
- Final CPN calculations (reserved for Chunk 3)
- Plotting or analysis operations

### 4.4 Chunk 3: Finalize Through Report Layer

**Purpose:** Process user-edited template, calculate Status/CallsPerHour, generate comprehensive statistics, plots, and final report.

**Processing Stages (4 integrated workflows):**

**[FINALIZE CPN - Workflow 04]**
```
Stage 1: Load configuration and data
Stage 2: Load and validate edited template
Stage 3: Track manual edits (compare ORIGINAL vs EDIT_THIS)
Stage 4: Calculate RecordingHours and classify Status
Stage 5: Calculate CallsPerHour metrics
Stage 6: Save final CPN with versioning
```

**[SUMMARY STATISTICS - Workflow 05]**
```
Stage 7: Generate detector activity summary
Stage 8: Generate study-wide summary
Stage 9: Calculate variance components
Stage 10: Generate species composition (if applicable)
Stage 11: Calculate species accumulation
Stage 12: Generate hourly activity profiles
Stage 13: Format GT tables and export
Stage 14: Save summary RDS
```

**[PLOTTING - Workflow 06]**
```
Stage 15: Configure plot settings
Stage 16: Generate quality plots (8)
Stage 17: Generate detector plots (7)
Stage 18: Generate species plots (5, if applicable)
Stage 19: Generate temporal plots (6)
Stage 20: Export plots (PNG/SVG)
Stage 21: Save plot objects RDS
```

**[REPORT & RELEASE - Workflow 07]**
```
Stage 22: Load pre-computed RDS artifacts
Stage 23: Render Quarto report
Stage 24: Create release bundle (ZIP)
Stage 25: Render final validation HTML
```

**Returns:**
```r
list(
  calls_per_night_final = tibble,
  metadata = list(
    n_detectors = integer,
    n_nights = integer,
    n_edits_tracked = integer,
    n_plots_generated = integer,
    processing_time = difftime
  ),
  artifact_ids = list(
    cpn_final = character,
    summary_data = character,
    plot_objects = character,
    report = character,
    release_bundle = character
  ),
  paths = list(
    cpn_final_csv = character,
    summary_data_rds = character,
    plot_objects_rds = character,
    report_html = character,
    release_bundle_zip = character
  ),
  validation_html_paths = character_vector  # One per workflow
)
```

**Allowed Operations:**
- Read user-edited template
- Calculate recording hours, Status, CallsPerHour
- Validate data quality
- Generate summary statistics and GT tables
- Generate ggplot objects and save PNG/SVG
- Render Quarto report to HTML
- Create release bundle zip
- Write final CPN to `results/csv/`
- Register all artifacts

**Prohibited Operations:**
- Modifying the original template files
- Modifying any upstream outputs from Chunks 1 or 2

**Critical Principle:** Chunk 3 integrates four legacy workflows but maintains their separation of concerns through distinct processing stages.

### 4.5 Layer Responsibility Enforcement

| Scope | Rule | Violation Example |
|-------|------|-------------------|
| Data flow | Data flows forward only (Chunk 1 -> 2 -> 3) | Chunk 3 modifying Chunk 1 output |
| Layer separation | Each chunk has defined stages | Plotting in finalization stage |
| Output locations | Analysis outputs go to `results/`, not `outputs/` | Plots in `outputs/` directory |
| Source immutability | Never modify upstream outputs | Chunk 3 editing `kpro_master` |
| Artifact registration | All persistent outputs must be registered | Skipping `register_artifact()` |
| Validation reports | Every chunk must generate validation report | Missing `finalize_validation_report()` |

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

**All file paths must use here::here():**
```r
library(here)

# CORRECT: Cross-platform, relative to project root
data_file <- here("data", "raw", "detector_A1.csv")
output_file <- here("outputs", "checkpoints", "01_intro_standardized.csv")

# INCORRECT: Hardcoded absolute path
data_file <- "C:/Users/John/bat_project/data/raw/detector_A1.csv"

# INCORRECT: Relative path (breaks if working directory changes)
data_file <- "data/raw/detector_A1.csv"
```

**RULES:**
- Use `here::here()` for ALL file paths
- Build paths from components (not concatenated strings)
- Use forward slashes (/) even on Windows
- `setwd()` is prohibited
- Absolute paths are prohibited
- Parent directory notation (`../`) is prohibited

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
# CORRECT: Action-oriented, clear purpose
load_raw_data()
calculate_recording_hours()
validate_study_config()
plot_species_composition()
gt_detector_summary()
register_artifact()
create_release_bundle()
run_ingest_standardize()      # Orchestrating function

# INCORRECT: Vague or noun-only
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
