# ==============================================================================
# ARCHITECTURE STANDARDS
# ==============================================================================
# VERSION: 3.0
# LAST UPDATED: 2026-02-08
# PURPOSE: Checkpointed phase orchestration, file organization, and pipeline design
# ==============================================================================

## OVERVIEW: CHECKPOINTED PHASE ORCHESTRATION

The KPro Masterfile Pipeline uses a **three-phase checkpointed orchestration** architecture:

1. **Phase 1: Data Preparation** (Modules 1-2) → Produces `kpro_master.csv` checkpoint
2. **Phase 2: Template Generation** (Module 3) → Produces `CPN_Template_EDIT_THIS.csv` (requires human editing)
3. **Phase 3: Analysis & Reporting** (Modules 4-7) → Produces final outputs (report, release bundle)

This architecture provides:
- **Explicit checkpoints** between phases for validation and human review
- **Structured data passing** between phases (phase results chain)
- **Human-in-the-loop support** with manual template editing in Phase 2
- **Shiny integration** via pure callable phase orchestrator functions
- **Reproducibility** through artifact registration and hashing

---

## 1. DIRECTORY STRUCTURE

```
project_root/
├── R/
│   ├── pipeline/
│   │   ├── run_phase1_data_preparation.R      # Phase 1: Ingestion + Standardization
│   │   ├── run_phase2_template_generation.R   # Phase 2: CPN Template + human edit
│   │   └── run_phase3_analysis_reporting.R    # Phase 3: Finalization → Report
│   │   │
│   │   ├── [LEGACY - Deprecated]
│   │   ├── run_ingest_standardize.R           # Deprecated: Use Phase 1
│   │   ├── run_cpn_template.R                 # Deprecated: Use Phase 2
│   │   └── run_finalize_to_report.R           # Deprecated: Use Phase 3
│   │
│   ├── modules/
│   │   ├── module_runner.R                    # MODULE EXECUTION LAYER (7 runners)
│   │   │                                      # Core infrastructure for phase orchestration
│   │   ├── data_ingestion.R                   # Module 1: Raw data loading
│   │   ├── data_standardization.R             # Module 2: Schema transformation
│   │   ├── cpn_template.R                     # Module 3: CPN template generation
│   │   ├── finalize_cpn.R                     # Module 4: CPN finalization
│   │   ├── summary_stats.R                    # Module 5: Summary statistics
│   │   ├── plotting.R                         # Module 6: Visualization generation
│   │   └── report_release.R                   # Module 7: Report & release bundle
│   │
│   ├── functions/
│   │   ├── core/
│   │   │   ├── config.R                       # YAML configuration management
│   │   │   ├── utilities.R                    # Foundational utilities
│   │   │   ├── logging.R                      # File logging
│   │   │   ├── console.R                      # Console formatting
│   │   │   ├── artifacts.R                    # Artifact registry & provenance
│   │   │   ├── release.R                      # Release bundle creation
│   │   │   └── load_all.R                     # Master loader (9-layer architecture)
│   │   ├── ingestion/
│   │   │   └── ingestion.R
│   │   ├── standardization/
│   │   │   ├── standardization.R              # Schema transformation logic
│   │   │   └── datetime_helpers.R             # Timezone handling
│   │   ├── validation/
│   │   │   ├── validation.R                   # Data quality validation
│   │   │   └── validation_reporting.R         # HTML validation reports
│   │   ├── analysis/
│   │   │   ├── callspernight.R
│   │   │   ├── detector_mapping.R
│   │   │   └── summarization.R
│   │   └── output/
│   │       ├── plot_helpers.R
│   │       ├── plot_quality.R
│   │       ├── plot_detector.R
│   │       ├── plot_species.R
│   │       ├── plot_temporal.R
│   │       ├── tables.R
│   │       └── report.R
│   │
│   └── [LEGACY WORKFLOWS - Optional]
│       ├── 01_ingest_raw_data.R
│       ├── 02_standardize.R
│       ├── 03_generate_cpn_template.R
│       ├── 04_finalize_cpn.R
│       ├── 05_summary_stats.R
│       ├── 06_exploratory_plots.R
│       └── 07_generate_report.R
│
├── inst/
│   └── config/
│       ├── study_parameters.yaml              # YAML configuration
│       ├── artifact_registry.yaml             # Artifact tracking with SHA256 hashes
│       └── YAML_PARAMETERS_GUIDE.md
│
├── reports/
│   └── bat_activity_report.qmd                # Quarto report template
│
├── data/
│   └── raw/                                   # Input CSVs (user-provided)
│
├── outputs/
│   ├── checkpoints/                           # Phase 1 → Phase 2 checkpoints
│   │   └── 02_kpro_master_*.csv               # Phase 1 output
│   │
│   └── [LEGACY]
│       └── final/                             # Deprecated
│
├── results/                                   # FINAL OUTPUTS
│   ├── csv/                                   # Final data (Phase 3)
│   │   └── CallsPerNight_final_v*.csv
│   ├── figures/
│   │   ├── png/
│   │   │   ├── quality/                       # Data quality plots
│   │   │   ├── detector/                      # Detector analysis plots
│   │   │   ├── species/                       # Species composition plots
│   │   │   └── temporal/                      # Temporal pattern plots
│   │   └── svg/
│   ├── tables/                                # GT table outputs
│   ├── rds/                                   # Serialized R objects
│   │   ├── summary_data_*.rds                 # Phase 3 summary statistics
│   │   └── plot_objects_*.rds                 # Phase 3 plot objects
│   ├── reports/                               # Rendered HTML reports (Phase 3)
│   │   └── bat_activity_report_*.html
│   ├── releases/                              # Release bundles (Phase 3)
│   │   └── kpro_release_*.zip
│   └── validation/
│       ├── validation_phase1_*.html           # Phase 1 validation
│       ├── validation_phase2_*.html           # Phase 2 validation
│       ├── validation_phase3_*.html           # Phase 3 validation
│       └── *.yaml                             # Validation metadata
│
├── logs/                                      # Pipeline execution logs
│   └── pipeline_YYYY-MM-DD.log
│
├── docs/
│   ├── ST_STANDARDS_INDEX.md
│   ├── ST_architecture_standards.md           # THIS FILE
│   ├── ST_documentation_standards.md
│   ├── ST_code_design_standards.md
│   ├── ST_data_standards.md
│   ├── ST_logging_console_standards.md
│   ├── ST_quarto_reporting_standards.md
│   ├── ST_artifact_release_standards.md
│   ├── ST_development_standards.md
│   └── ST_ORCHESTRATION_PHILOSOPHY.md         # NEW: Authoritative orchestration reference
│
├── tests/
│   ├── Tester.R                               # Phase chaining test script
│   └── testthat/                              # Unit tests
│
├── manifest.YAML                              # Comprehensive provenance
└── KPro_Masterfile_Pipeline.Rproj
```

**RULES:**
- All paths must be relative to project root
- Use `here::here()` for cross-platform compatibility
- `outputs/checkpoints/` for Phase 1 → Phase 2 intermediate files
- `results/` for final outputs (Phase 3 analysis results)
- `results/validation/` for validation reports from all phases
- `results/releases/` for release bundles
- `inst/config/artifact_registry.yaml` for artifact tracking
- Absolute paths are prohibited
- Parent directory references (`../`) are prohibited
- User data must not be committed to version control

---

## 2. FILE NAMING CONVENTIONS

### 2.1 Phase Orchestrator Functions

```
run_phase1_data_preparation.R
run_phase2_template_generation.R
run_phase3_analysis_reporting.R
```
Format: `run_phase#_descriptive_name.R` (phase number, snake_case)

**Naming Rule:**
- Phase number (1, 2, or 3) always comes immediately after `phase`
- Descriptive name captures the primary purpose
- Examples: `run_phase1_data_preparation`, `run_phase2_template_generation`, `run_phase3_analysis_reporting`

### 2.2 Module Execution Layer

**File:** `R/modules/module_runner.R`

**Pattern:** Single central file providing callable interfaces for all 7 modules

**Functions:**
- `run_module_ingestion()`
- `run_module_standardization()`
- `run_module_cpn_template()`
- `run_module_finalize_cpn()`
- `run_module_summary_stats()`
- `run_module_plotting()`
- `run_module_report_release()`

### 2.3 Processing Modules

```
data_ingestion.R          # Module 1
data_standardization.R    # Module 2
cpn_template.R            # Module 3
finalize_cpn.R            # Module 4
summary_stats.R           # Module 5
plotting.R                # Module 6
report_release.R          # Module 7
```
Format: `descriptive_name.R` (noun-based, descriptive)

### 2.4 Function Files in R/functions/

```
schema_helpers.R
datetime_helpers.R
plot_helpers.R
validation.R
validation_reporting.R
```
Format: `noun_helpers.R` or `noun.R` (descriptive, snake_case)

### 2.5 Output Files

**Phase 1 Checkpoint:**
```
outputs/checkpoints/02_kpro_master_YYYYMMDD_HHMMSS.csv
results/validation/validation_phase1_YYYYMMDD_HHMMSS.html
```

**Phase 2 Checkpoints:**
```
outputs/03_CallsPerNight_Template_ORIGINAL_YYYYMMDD_HHMMSS.csv
outputs/03_CallsPerNight_Template_EDIT_THIS_YYYYMMDD_HHMMSS.csv
results/validation/validation_phase2_YYYYMMDD_HHMMSS.html
```

**Phase 3 Outputs:**
```
results/csv/CallsPerNight_final_v1.csv
results/tables/gt_study_overview_YYYYMMDD.html
results/figures/png/quality/recording_status_summary_YYYYMMDD.png
results/rds/summary_data_YYYYMMDD.rds
results/rds/plot_objects_YYYYMMDD.rds
results/reports/bat_activity_report_YYYYMMDD.html
results/releases/kpro_release_<study_id>_YYYYMMDD_HHMMSS.zip
results/validation/validation_phase3_YYYYMMDD_HHMMSS.html
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

## 3. CHECKPOINTED PHASE ORCHESTRATION ARCHITECTURE

### 3.1 Phase Orchestrator Pattern

Phase orchestrators are callable functions that compose the module execution layer to implement high-level pipeline phases. Each phase is a complete unit of work with explicit checkpoints.

**Core Characteristics:**
- Pure functions (no global side effects)
- Silent by default (`verbose = FALSE`)
- All configuration from YAML (no interactive prompts)
- Return structured lists with data, metadata, and paths
- Always save checkpoints and register artifacts
- Always render validation HTML at completion
- Support result passing between phases (phase1_result → phase2, etc.)

**Design Principles:**
- **Thin wrappers** - Phase orchestrators are simple compositions of module runners
- **Checkpoint-driven** - Each phase produces a clear checkpoint for validation
- **Structured passing** - Results chain between phases with full metadata
- **Human-in-the-loop** - Phase 2 explicitly flags manual editing requirement
- **Shiny-compatible** - Pure functions suitable for Shiny event handlers

### 3.2 Phase Result Structure

All phase orchestrators return a structured list:

```r
list(
  # Phase metadata
  phase = integer,               # 1, 2, or 3
  phase_name = character,        # "Data Preparation", "Template Generation", etc.
  
  # Primary data outputs
  [primary_data] = tibble,       # kpro_master, cpn_template, calls_per_night_final, etc.
  
  # Processing metadata
  metadata = list(
    n_rows = integer,
    processing_time = difftime,
    filters_applied = character_vector,
    # Phase-specific metrics
  ),
  
  # Checkpoint/artifact paths
  checkpoint_path = character,   # Data checkpoint for next phase
  # Or for Phase 2:
  template_edit_path = character,   # Path to template requiring human edit
  
  # Validation reports
  validation_html_paths = character_vector,  # Validation reports
  
  # Flags specific to phases
  # Phase 2 only:
  human_action_required = TRUE,     # User must edit template
  
  # Phase 3 only:
  report_path = character,
  release_bundle_path = character,
  pipeline_complete = TRUE,
  
  # Advanced use
  module_results = list(...)     # Raw outputs from each module
)
```

### 3.3 Phase Chaining Pattern

Phase orchestrators are designed to chain together:

```r
source('R/functions/load_all.R')
source('R/pipeline/run_phase1_data_preparation.R')
source('R/pipeline/run_phase2_template_generation.R')
source('R/pipeline/run_phase3_analysis_reporting.R')

# Phase 1: Data Preparation
phase1_result <- run_phase1_data_preparation(verbose = TRUE)

# Phase 2: Template Generation
phase2_result <- run_phase2_template_generation(
  phase1_result = phase1_result,
  verbose = TRUE
)

# ⚠️  CHECKPOINT: User must edit CPN_Template_EDIT_THIS.csv
# Edit file located at: phase2_result$template_edit_path

# Phase 3: Analysis & Reporting
phase3_result <- run_phase3_analysis_reporting(
  phase2_result = phase2_result,
  edited_template_file = phase2_result$template_edit_path,  # After editing
  verbose = TRUE
)
```

### 3.4 Phase 1: Data Preparation (Modules 1-2)

**Function:** `run_phase1_data_preparation(verbose = FALSE)`

**Purpose:** Transform raw KPro CSVs into unified kpro_master dataset.

**Module Execution:**
1. `run_module_ingestion()` - Load and intro-standardize raw data
2. `run_module_standardization()` - Transform schemas and apply filters

**Checkpoint:** `outputs/checkpoints/02_kpro_master_YYYYMMDD_HHMMSS.csv`

**Returns:**
```r
list(
  phase = 1,
  phase_name = "Data Preparation",
  kpro_master = tibble,
  metadata = list(
    n_rows = integer,
    rows_removed = list(duplicates, noid, zero_pulse),
    data_filters_applied = character_vector,
    processing_time = difftime
  ),
  checkpoint_path = "outputs/checkpoints/02_kpro_master_*.csv",
  validation_html_paths = character_vector
)
```

### 3.5 Phase 2: Template Generation (Module 3)

**Function:** `run_phase2_template_generation(phase1_result = NULL, manual_id_file = NULL, verbose = FALSE)`

**Purpose:** Generate CallsPerNight template with recording schedules and prepare for human review.

**Input:** phase1_result from Phase 1 (contains kpro_master)

**Module Execution:**
1. `run_module_cpn_template()` - Generate CPN template with recording hours

**Checkpoints:** 
- `outputs/03_CallsPerNight_Template_ORIGINAL_*.csv` (template before editing)
- `outputs/03_CallsPerNight_Template_EDIT_THIS_*.csv` (template for user to edit)

**Human-in-the-Loop:** User MUST edit the EDIT_THIS file before Phase 3 can proceed

**Returns:**
```r
list(
  phase = 2,
  phase_name = "Template Generation",
  cpn_template = tibble,
  metadata = list(
    n_detectors = integer,
    n_nights = integer,
    processing_time = difftime
  ),
  template_edit_path = "outputs/03_CallsPerNight_Template_EDIT_THIS_*.csv",
  validation_html_paths = character_vector,
  human_action_required = TRUE  # Critical flag
)
```

### 3.6 Phase 3: Analysis & Reporting (Modules 4-7)

**Function:** `run_phase3_analysis_reporting(phase2_result = NULL, edited_template_file = NULL, verbose = FALSE)`

**Purpose:** Finalize CPN, calculate statistics, generate plots, and produce final report and release bundle.

**Input:** phase2_result from Phase 2 + edited template file (modified by user)

**Module Execution:**
1. `run_module_finalize_cpn()` - Load edited template and finalize CPN
2. `run_module_summary_stats()` - Generate summary statistics
3. `run_module_plotting()` - Generate visualizations
4. `run_module_report_release()` - Render report and create release bundle

**Outputs:**
- results/csv/CallsPerNight_final_v*.csv
- results/reports/bat_activity_report_*.html
- results/releases/kpro_release_*.zip
- All intermediate RDS, PNG, and metadata files

**Returns:**
```r
list(
  phase = 3,
  phase_name = "Analysis & Reporting",
  calls_per_night_final = tibble,
  report_path = character,
  release_bundle_path = character,
  metadata = list(
    n_detectors = integer,
    n_nights = integer,
    n_plots = integer,
    processing_time = difftime
  ),
  validation_html_paths = character_vector,
  pipeline_complete = TRUE
)
```

---

## 4. MODULE EXECUTION LAYER

### 4.1 Module Runner Overview

**File:** `R/modules/module_runner.R`

**Classification:** Core infrastructure for checkpointed phase orchestration (not a debug tool)

**Purpose:** Provide callable interfaces for all 7 processing modules

**Seven Module Runners:**

1. `run_module_ingestion(verbose = FALSE)` 
   - Source: data/
   - Output: intro_standardized (ingestion result)

2. `run_module_standardization(ingestion_result, verbose = FALSE)`
   - Input: ingestion_result
   - Output: kpro_master (standardized dataset)

3. `run_module_cpn_template(standardization_result, manual_id_file = NULL, verbose = FALSE)`
   - Input: kpro_master
   - Output: cpn_template (template pair)

4. `run_module_finalize_cpn(cpn_template_result, edited_template_file = NULL, verbose = FALSE)`
   - Input: cpn_template + edited template file
   - Output: calls_per_night_final (finalized CPN)

5. `run_module_summary_stats(finalize_result, verbose = FALSE)`
   - Input: calls_per_night_final
   - Output: all_summaries (summary objects)

6. `run_module_plotting(summary_stats_result, verbose = FALSE)`
   - Input: calls_per_night_final, summary_stats
   - Output: all_plots (ggplot objects)

7. `run_module_report_release(plotting_result, summary_stats_result, verbose = FALSE)`
   - Input: all_plots, summary_stats
   - Output: report, release_bundle

**Utility Function:**

8. `run_all_modules(verbose = FALSE)`
   - Executes all 7 modules in sequence with pause prompts
   - Used for testing or custom execution sequences

### 4.2 Module Execution Patterns

**Pattern 1: Called by Phase Orchestrators (Primary)**
```r
# Inside run_phase1_data_preparation.R
source(file.path("R", "modules", "module_runner.R"))

module1_result <- run_module_ingestion(verbose = verbose)
module2_result <- run_module_standardization(module1_result, verbose = verbose)
```

**Pattern 2: Individual Module Testing**
```r
source('R/functions/load_all.R')
source('R/modules/module_runner.R')

# Test individual modules
r1 <- run_module_ingestion(verbose = TRUE)
r2 <- run_module_standardization(r1, verbose = TRUE)
```

**Pattern 3: Custom Execution Sequences**
```r
source('R/functions/load_all.R')
source('R/modules/module_runner.R')

# Custom sequence: run specific modules
r1 <- run_module_ingestion(verbose = TRUE)
# [inspect data]
r2 <- run_module_standardization(r1, verbose = TRUE)
# [may stop here for inspection]
```

### 4.3 Module Result Structure

Each module runner returns a structured result:

```r
# Example: run_module_ingestion()
list(
  ingestion = list(
    raw_combined = tibble,        # Raw combined data
    csv_files = character_vector  # Files loaded
  ),
  metadata = list(
    n_rows = integer,
    n_files = integer,
    processing_time = difftime
  ),
  validation_html_paths = character_vector,
  # ... module-specific components ...
)
```

---

## 5. PROCESSING MODULES

### 5.1 Process Modules vs. Functions

**Processing Modules** (R/modules/):
- Thematic subsystems that coordinate multiple stages
- Each module contains internal "module stages" numbered sequentially
- 7 modules total across 3 phases
- Each module has its own internal logic and file I/O
- Called via module_runner.R by phase orchestrators

**Utility Functions** (R/functions/):
- Reusable helper functions organized by domain
- No orchestration logic
- Used by modules and phase orchestrators
- Testable units with specific contracts

### 5.2 Module Stage Numbering

Each module has internal numbered stages. For example:

**Module 1 (Ingestion) - Stages 1-2:**
- Stage 1: Discover CSV files
- Stage 2: Load and combine CSVs

**Module 2 (Standardization) - Stages 3-8:**
- Stage 3: Detect schema versions
- Stage 4: Transform schemas (v1/v2/v3 → unified)
- Stage 5: Apply detector mapping
- Stage 6: Convert timezones
- Stage 7: Finalize master schema
- Stage 8: Apply data filters

**Module 3 (CPN Template) - Stages 9-17:**
- Stage 9: Load configuration
- Stage 10: Generate recording schedules
- ... etc ...

**Module 4 (Finalize CPN) - Stages 18-23:**
- Stage 18-23: Finalization pipeline

**Modules 5-7:** Continue stage numbering

This sequential stage numbering across modules allows precise logging and error tracking.

### 5.3 Module Self-Containment Pattern

Each module is self-contained:

```r
module_function <- function(input_data, verbose = FALSE) {
  
  # LOAD: Load dependencies and configuration
  source(file.path("R", "functions", "load_all.R"))
  
  # VALIDATE: Validate inputs
  assert_not_empty(input_data)
  assert_columns_exist(input_data, required_cols)
  
  # PROCESS: Execute module stages
  # Stage N.1: Description
  # Stage N.2: Description
  # ... internal processing ...
  
  # SAVE: Save outputs (checkpoints/artifacts)
  saveRDS(result, checkpoint_path)
  registry <- register_artifact(...)
  
  # VALIDATE OUTPUT: Validation reporting
  context <- create_validation_context(...)
  finalize_validation_report(context)
  
  # RETURN: Structured result
  list(
    module_output = result,
    metadata = ...,
    validation_html_paths = ...
  )
}
```

---

## 6. LAYER ARCHITECTURE

The 9-layer architecture in `load_all.R`:

```
Layer 1-6: Utility Functions (R/functions/)
           - Core, ingestion, standardization, validation, analysis, output
           - Focused, testable, reusable

Layer 7: Phase Orchestrators (R/pipeline/)
         - run_phase1_data_preparation()
         - run_phase2_template_generation()
         - run_phase3_analysis_reporting()
         - High-level pipeline coordination with checkpoints

Layer 8: Processing Modules (R/modules/)
         - 7 self-contained modules with staged execution
         - Module 1: data_ingestion.R
         - Module 2: data_standardization.R
         - Module 3: cpn_template.R
         - Module 4: finalize_cpn.R
         - Module 5: summary_stats.R
         - Module 6: plotting.R
         - Module 7: report_release.R

Layer 9: Module Execution Layer (R/modules/module_runner.R)
         - Callable interfaces for all 7 modules
         - run_module_*(.) functions
         - Core infrastructure for phase orchestration
```

**Data Flow:**
- Layer 1-6 functions are called by Layers 7, 8, 9
- Layers 7 (phase orchestrators) call Layer 9 (module runners)
- Modules (Layer 8) call Layer 1-6 functions
- Each layer may read from previous layers but only write forward

---

## 7. PIPELINE EXECUTION MODELS

### 7.1 Phase-Driven Execution (Recommended)

**For production use and Shiny integration:**

```
      run_phase1_data_preparation()
             ↓
      [kpro_master checkpoint]
             ↓
      run_phase2_template_generation()
             ↓
      [CPN_Template_EDIT_THIS checkpoint]
             ↓
    🛑 USER EDITS TEMPLATE 🛑
             ↓
      run_phase3_analysis_reporting()
             ↓
      [Final outputs: report, release bundle]
```

**Advantages:**
- Explicit checkpoints for validation
- Human-in-the-loop support
- Structured result passing
- Shiny-compatible pure functions
- Clear separation of concerns

### 7.2 Module Execution (Advanced Use)

**For testing individual modules or custom sequences:**

```
      run_module_ingestion()
             ↓
      run_module_standardization()
             ↓
      run_module_cpn_template()
             ↓
      [Edit template manually]
             ↓
      run_module_finalize_cpn()
             ↓
      run_module_summary_stats()
             ↓
      run_module_plotting()
             ↓
      run_module_report_release()
```

### 7.3 Legacy Workflow Execution (Deprecated)

**For backward compatibility and interactive exploration:**

```
01_ingest_raw_data.R  →  02_standardize.R  →  03_cpn_template.R
    ↓                        ↓                        ↓
[intro_std]            [kpro_master]          [cpn_templates]
                                                      ↓
                                               [USER EDIT]
                                                      ↓
04_finalize_cpn.R  →  05_summary_stats.R  →  06_exploratory_plots.R  →  07_generate_report.R
    ↓                        ↓                        ↓                        ↓
[cpn_final]         [summary.rds]             [plots.rds]            [report.html]
```

---

## 8. PATH MANAGEMENT

### 8.1 Using here::here()

**All file paths must use here::here():**

```r
library(here)

# CORRECT: Cross-platform, relative to project root
data_file <- here("data", "raw", "detector_A1.csv")
output_file <- here("outputs", "checkpoints", "02_kpro_master.csv")

# INCORRECT: Hardcoded absolute path
data_file <- "C:/Users/John/bat_project/data/raw/detector_A1.csv"

# INCORRECT: Relative path
data_file <- "data/raw/detector_A1.csv"
```

**RULES:**
- Use `here::here()` for ALL file paths
- Build paths from components (not concatenated strings)
- Use forward slashes (/) even on Windows
- `setwd()` is prohibited
- Absolute paths are prohibited
- Parent directory notation (`../`) is prohibited

### 8.2 Dynamic Path Generation

```r
# For timestamped outputs
make_timestamped_path <- function(base_dir, prefix, extension = "csv") {
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  filename <- sprintf("%s_%s.%s", prefix, timestamp, extension)
  here::here(base_dir, filename)
}

# Usage
output_path <- make_timestamped_path("outputs/checkpoints", "02_kpro_master")
# Result: /path/to/project/outputs/checkpoints/02_kpro_master_20260208_125034.csv
```

---

## 9. NAMING CONVENTIONS

### 9.1 Phase Orchestrator Naming

**Pattern:** `run_phase#_descriptive_name()`

```r
# CORRECT: Clear phase number and purpose
run_phase1_data_preparation()
run_phase2_template_generation()
run_phase3_analysis_reporting()

# INCORRECT: Missing phase number
run_data_preparation()

# INCORRECT: Unclear ordering
run_first_data_preparation()
```

### 9.2 Module Function Naming

**Pattern:** `run_module_name()`

```r
# CORRECT
run_module_ingestion()
run_module_standardization()
run_module_cpn_template()
run_module_finalize_cpn()

# INCORRECT
ingestion()
module1()
run_ingestion()
```

### 9.3 Utility Function Naming

**Pattern:** `verb_noun()` or `verb_noun_context()`

```r
# CORRECT
load_raw_data()
calculate_recording_hours()
validate_study_config()
plot_species_composition()
assert_columns_exist()
register_artifact()

# INCORRECT
data()
hours()
config()
species()
```

### 9.4 Plot Function Naming

**Pattern:** `plot_[what]_[how]()`

```r
# CORRECT
plot_recording_status_summary()
plot_species_by_detector_heatmap()
plot_activity_over_time()

# INCORRECT
quality_plot()
plot1()
activity_vis()
```

### 9.5 GT Table Function Naming

**Pattern:** `gt_[what]_[scope]()`

```r
# CORRECT
gt_study_overview()
gt_detector_summary()
gt_species_composition()

# INCORRECT
table_study()
gt1()
summary_table()
```

### 9.6 Consistent Terminology

**Use these terms consistently:**

| Term | Use | Don't Use |
|------|-----|-----------|
| phase | Phases 1-3 in orchestration | chunk, stage |
| phase orchestrator | run_phase#_*() functions | chunk orchestrator, workflow |
| module | Processing modules 1-7 | workflow, orchestrator |
| module runner | Functions in module_runner.R | debug runner, test runner |
| detector | Sensors/units in acoustic array | sensor, unit, device |
| auto_id | Automatic species identification | species, species_code, id |
| calls_per_night | CallsPerNight dataset | cpn, nightly_calls |
| recording_hours | Recording time per detector-night | hours, duration |
| checkpoint | Phase-ending data output | intermediate, artifact |
| artifact | Registered output in artifact_registry.yaml | output, product, result |
| verbose | Console output control parameter | quiet |
| timestamp | Date/time stamps in filenames | time, date |

---

## 10. ORCHESTRATOR DESIGN PRINCIPLES

### 10.1 Pure Function Contract

Phase orchestrators must be pure functions:

```r
# [OK] GOOD: Pure function, no global side effects
run_phase1_data_preparation <- function(verbose = FALSE) {
  # Load dependencies, process, save outputs, return results
  list(...)
}

# [X] BAD: Uses global variable
MY_CONFIG <- NULL  # Don't do this
run_phase1_data_preparation <- function(verbose = FALSE) {
  MY_CONFIG <<- load_config()  # WRONG
}

# [X] BAD: Modifies global environment
run_phase1_data_preparation <- function(verbose = FALSE) {
  kpro_master <<- load_and_process()  # WRONG
}
```

### 10.2 Structured Return Contracts

All phase orchestrators must return comprehensive structured lists:

```r
# [OK] GOOD: Rich structure with data, metadata, paths
run_phase1_data_preparation <- function(verbose = FALSE) {
  list(
    phase = 1,
    phase_name = "Data Preparation",
    kpro_master = data,
    metadata = list(...),
    checkpoint_path = path,
    validation_html_paths = vector
  )
}

# [X] BAD: Just returning raw data
run_phase1_data_preparation <- function(verbose = FALSE) {
  kpro_master  # No metadata, no paths
}
```

### 10.3 Error Handling

```r
# [OK] GOOD: Informative error messages
run_phase1_data_preparation <- function(verbose = FALSE) {
  module1_result <- tryCatch({
    run_module_ingestion(verbose = verbose)
  }, error = function(e) {
    stop("Phase 1 - Module 1 (Ingestion) failed: ", e$message)
  })
}

# [X] BAD: Generic error messages
run_phase1_data_preparation <- function(verbose = FALSE) {
  module1_result <- run_module_ingestion()  # Error handling missing
}
```

---

## 11. ARCHITECTURE GUARANTEES

The checkpointed phase orchestration architecture guarantees:

1. **Determinism:** Same inputs → same outputs every time
2. **Reproducibility:** All transformations logged and tracked
3. **Checkpointing:** Explicit intermediate outputs for validation
4. **Human Review:** Phase 2 requires manual editing before Phase 3
5. **Auditability:** All artifacts registered with SHA256 hashes
6. **Composability:** Phases can be tested independently or chained together
7. **Shiny Compatibility:** Pure functions with structured returns
8. **Version Tracking:** Artifact registry tracks all versions
9. **Validation:** HTML reports at each phase completion
10. **Forward Data Flow:** Data flows forward through phases, never backward

---

## 12. DEPRECATION NOTES

**Deprecated (still available, not recommended):**
- `run_ingest_standardize()` → Use `run_phase1_data_preparation()`
- `run_cpn_template()` → Use `run_phase2_template_generation()`
- `run_finalize_to_report()` → Use `run_phase3_analysis_reporting()`
- Legacy workflow scripts 01-07 → Use phase orchestrators

**Why deprecated:**
- Chunk-based terminology replaced by phase-based architecture
- No structured result passing between chunks
- No human-in-the-loop support
- Less clear checkpointing

**Migration path:**
1. Replace `run_ingest_standardize()` calls with `run_phase1_data_preparation()`
2. Replace `run_cpn_template()` calls with `run_phase2_template_generation(phase1_result)`
3. Replace `run_finalize_to_report()` calls with `run_phase3_analysis_reporting(phase2_result)`
4. Update to phase result passing pattern

---

## VERSION HISTORY

**v3.0 (2026-02-08)**
- Major architecture transition to checkpointed phase orchestration
- Introduced 3-phase model with explicit checkpoints
- Added module execution layer architecture  
- Documented phase result passing pattern
- Added human-in-the-loop checkpoint documentation
- Moved module_runner.R from R/debug/ to R/modules/ as core infrastructure
- Updated all terminology from "chunks" to "phases"
- Marked legacy orchestrators as deprecated
- Total rewrite: 787 lines → 600 lines (consolidated)
- Added new sections: Overview, Phase Orchestration, Module Execution Layer
- Removed Chunk-specific processing stage definitions

**v2.5 (2026-02-05)**
- Updated to modularized 7-module pipeline
- Added module stage numbering
- Documented layer responsibilities

**v2.4 (2026-02-02)**
- Minor updates to orchestrator patterns

**v2.3 (2026-01-31)**
- Updated chunk-based terminology
- Added structured return documentation

---

**END OF DOCUMENT**
