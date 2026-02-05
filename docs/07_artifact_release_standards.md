# ==============================================================================
# ARTIFACT & RELEASE STANDARDS
# ==============================================================================
# VERSION: 2.4
# LAST UPDATED: 2026-02-05
# PURPOSE: Artifact registry, tracking, and release bundle creation
# ==============================================================================

## 1. ARTIFACT REGISTRY SYSTEM

### 1.1 Overview

The artifact registry provides formal tracking of all pipeline outputs with cryptographic hashing for reproducibility verification. Every artifact produced by the pipeline is registered with metadata, provenance, and SHA256 hash.

**Registry location:** `inst/config/artifact_registry.yaml`

**Core module:** `R/functions/core/artifacts.R`

### 1.2 Artifact Types

The registry recognizes these artifact types:

| Type | Description | Typical Chunk/Workflow |
|------|-------------|------------------------|
| `raw_input` | Original source files | Chunk 1 / WF01 |
| `checkpoint` | Intermediate outputs | Chunk 1 / WF01-02 |
| `masterfile` | Unified master detection file | Chunk 1 / WF02 |
| `cpn_template` | CallsPerNight template (original + editable) | Chunk 2 / WF03 |
| `cpn_final` | Finalized CallsPerNight dataset | Chunk 3 / WF04 |
| `summary_stats` | Summary statistics RDS | Chunk 3 / WF05 |
| `plot_objects` | Plot objects RDS | Chunk 3 / WF06 |
| `report` | Rendered Quarto HTML report | Chunk 3 / WF07 |
| `release_bundle` | Portable zip for downstream projects | Chunk 3 / WF07 |
| `validation_report` | HTML validation report | Any |

### 1.3 Registry Structure

```yaml
registry_version: '1.0'
created_utc: '2026-01-12T06:34:34Z'
pipeline_version: '2.1'
artifacts:
  kpro_master_20260112_020904:
    name: kpro_master_20260112_020904
    type: masterfile
    workflow: 'chunk1'  # Or '02' for legacy workflows
    file_path: results/csv/Master_2026-01-12_0209.csv
    file_hash_sha256: 6746c39a45915e...
    file_size_bytes: 792575
    created_utc: '2026-01-12T08:09:04Z'
    pipeline_version: '2.1'
    input_artifacts: intro_standardized
    metadata:
      n_rows: 2008
      n_detectors: 9
      n_duplicates_removed: 123
      timezone: America/Chicago
      data_filters_applied:
        remove_duplicates: true
        remove_noid: false
        remove_zero_pulse_calls: false
last_modified_utc: '2026-01-19T20:34:17Z'
```

### 1.4 Registry Functions

**Core Module:** `R/functions/core/artifacts.R`

**Initialization:**
```r
# Load existing or create new registry
registry <- init_artifact_registry()
```

**Registration:**
```r
registry <- register_artifact(
  registry = registry,
  artifact_name = sprintf("kpro_master_%s", timestamp),
  artifact_type = "masterfile",
  workflow = "chunk1",  # Or "02" for legacy
  file_path = master_path,
  input_artifacts = "intro_standardized",
  metadata = list(
    n_rows = nrow(master),
    n_detectors = n_distinct(master$Detector),
    data_filters_applied = list(
      remove_duplicates = TRUE,
      remove_noid = FALSE
    )
  )
)
```

**Atomic RDS Save + Register (Recommended):**
```r
# Best practice: saves RDS and registers in one atomic operation
registry <- save_and_register_rds(
  object = summary_data,
  file_path = here("results", "rds", "summary_data.rds"),
  artifact_type = "summary_stats",
  workflow = "05",
  registry = registry,
  metadata = list(n_summaries = 8, has_species = TRUE),
  verbose = verbose
)
```

**Retrieval:**
```r
# Get specific artifact
artifact <- get_artifact(registry, "kpro_master_20260112")

# Get most recent by type
latest_master <- get_latest_artifact(registry, type = "masterfile")

# List all artifacts (optionally filtered)
all_checkpoints <- list_artifacts(registry, type = "checkpoint")
```

### 1.5 Registration Requirements

Every chunk/workflow that produces persistent output MUST register artifacts:

| Chunk | Legacy Workflow | Required Registrations |
|-------|-----------------|------------------------|
| 1 | 01 + 02 | `checkpoint` (intro_standardized), `masterfile` (kpro_master) |
| 2 | 03 | `cpn_template` (original + editable) |
| 3 | 04-07 | `cpn_final`, `summary_stats`, `plot_objects`, `report`, `release_bundle` |

**Registration pattern in orchestrating functions:**
```r
run_ingest_standardize <- function(verbose = FALSE) {
  
  # ... processing ...
  
  # Register artifact (at end of chunk)
  registry <- init_artifact_registry()
  
  artifact_id <- sprintf("kpro_master_%s", format(Sys.time(), "%Y%m%d_%H%M%S"))
  
  registry <- register_artifact(
    registry = registry,
    artifact_name = artifact_id,
    artifact_type = "masterfile",
    workflow = "chunk1",
    file_path = checkpoint_path,
    input_artifacts = c("raw_inputs"),
    metadata = list(
      n_rows = nrow(kpro_master),
      n_detectors = n_distinct(kpro_master$Detector),
      data_filters_applied = data_filters_config
    )
  )
  
  # File logging always happens
  log_message(sprintf("[Chunk 1] Registered artifact: %s", artifact_id))
  
  # Return artifact_id in structured result
  list(
    kpro_master = kpro_master,
    artifact_id = artifact_id,
    # ... other return values
  )
}
```

### 1.6 Artifact Naming Convention

Artifact names follow this pattern:
```
{base_name}_{YYYYMMDD}_{HHMMSS}
```

Examples:
- `intro_standardized_20260112_014124`
- `kpro_master_20260112_020904`
- `cpn_final_v6_20260112_214607`
- `plot_objects_20260119`

**RULES:**
- Use snake_case
- Include timestamp for uniqueness
- Version numbers allowed for user-edited artifacts (e.g., `cpn_final_v6`)
- Names must be valid YAML keys (no spaces, no special characters except underscore)

---

## 2. RELEASE BUNDLE SYSTEM

### 2.1 Purpose

Release bundles are portable, self-contained zip files designed for direct consumption by downstream projects (e.g., NB GAMM Bat project) without renaming or reformatting.

**Output location:** `results/releases/`

**Core module:** `R/functions/core/release.R`

### 2.2 Bundle Structure

```
kpro_release_<study_id>_<timestamp>/
├── manifest.yaml              # Full provenance and metadata
├── data/
│   ├── calls_per_night_raw.csv    # Primary GAMM input (key file)
│   ├── kpro_master.csv            # Full detection dataset
│   └── summary/
│       ├── detector_summary.csv
│       ├── study_summary.csv
│       ├── species_summary.csv
│       └── hourly_summary.csv
├── figures/
│   ├── quality/
│   │   └── *.png
│   ├── detector/
│   │   └── *.png
│   ├── species/
│   │   └── *.png
│   └── temporal/
│       └── *.png
├── report/
│   └── kpro_report.html
└── analysis_bundle.rds            # All R objects for programmatic access
```

### 2.3 Key Files

| File | Purpose | Consumer |
|------|---------|----------|
| `data/calls_per_night_raw.csv` | Primary modeling input | NB GAMM project |
| `data/kpro_master.csv` | Full detection data | Any downstream analysis |
| `manifest.yaml` | Provenance documentation | Reproducibility verification |
| `analysis_bundle.rds` | All R objects | Programmatic access |

### 2.4 Bundle Creation

```r
zip_path <- create_release_bundle(
  study_id = "SchmeeckleBatStudy",
  calls_per_night_final = cpn_final,
  kpro_master = master,
  all_summaries = all_summaries,    # From summary stage
  all_plots = all_plots,            # From plot stage
  report_path = report_path         # From Quarto render
)
```

**In orchestrating function context:**
```r
run_finalize_to_report <- function(verbose = FALSE) {
  
  # ... earlier stages ...
  
  # Stage N: Create Release Bundle
  if (verbose) print_stage_header("N", "Create Release Bundle")
  
  zip_path <- create_release_bundle(
    study_id = study_id,
    calls_per_night_final = cpn_final,
    kpro_master = kpro_master,
    all_summaries = all_summaries,
    all_plots = all_plots,
    report_path = report_path
  )
  
  log_message(sprintf("[Stage N] Release bundle created: %s", basename(zip_path)))
  
  # Return in structured result
  list(
    # ... other outputs ...
    release_bundle_path = zip_path
  )
}
```

### 2.5 Manifest Contents

The manifest.yaml in each release contains:

```yaml
release:
  name: kpro_release_SchmeeckleBatStudy_20260112_143022
  created_utc: '2026-01-12T14:30:22Z'
  pipeline_version: '2.1'
  r_version: '4.3.2'

study:
  study_id: SchmeeckleBatStudy
  study_name: "Schmeeckle Reserve Bat Acoustic Survey"
  start_date: '2025-10-04'
  end_date: '2025-10-31'
  timezone: America/Chicago

data_filters_applied:
  remove_duplicates: true
  remove_noid: false
  remove_zero_pulse_calls: false

artifacts:
  data:
    - path: data/calls_per_night_raw.csv
      description: "Detector x Night grid for GAMM modeling"
      sha256: d129f9ae2c1c...
    - path: data/kpro_master.csv
      description: "Standardized master detection file"
      sha256: 6746c39a4591...
  figures:
    count: 26
    categories: [quality, detector, species, temporal]
  report:
    path: report/kpro_report.html
  bundle:
    path: analysis_bundle.rds
    description: "All R objects for programmatic access"

validation:
  calls_per_night_schema_valid: true
  manifest_generated: '2026-01-12T14:30:22Z'
```

### 2.6 Input Validation

Before bundle creation, inputs are validated:

```r
validation_result <- validate_release_inputs(
  calls_per_night_final = cpn_final,
  kpro_master = master
)

if (!validation_result$valid) {
  stop(paste(validation_result$errors, collapse = "\n"))
}
```

**Required CPN columns:** `Detector`, `Night`, `CallsPerNight`, `RecordingHours`

**Required Master columns:** `Detector`, `DateTime_local`, `auto_id`

### 2.7 Analysis Bundle RDS

The `analysis_bundle.rds` provides programmatic access to all objects:

```r
# In downstream project
bundle <- readRDS("kpro_release_study_20260112/analysis_bundle.rds")

# Access components
cpn <- bundle$calls_per_night
master <- bundle$kpro_master
params <- bundle$study_parameters
summaries <- bundle$summaries
meta <- bundle$metadata  # n_detectors, n_nights, n_calls
```

### 2.8 Bundle Naming Convention

```
kpro_release_<study_id>_<YYYYMMDD>_<HHMMSS>.zip
```

Examples:
- `kpro_release_SchmeeckleBatStudy_20260112_143022.zip`
- `kpro_release_WisconsinBats2025_20260115_091500.zip`

### 2.9 Cross-Platform Considerations

The `create_release_bundle()` function handles Windows-specific issues:

- Uses relative paths internally to avoid colon issues in zip creation
- Temporarily changes working directory during zip operation
- Uses `zip::zip()` instead of base R for cross-platform compatibility

```r
# CRITICAL: Change to parent directory for relative paths
old_wd <- getwd()
setwd(dirname(staging_dir))
on.exit(setwd(old_wd), add = TRUE)

zip::zip(
  zipfile = zip_path,
  files = basename(staging_dir),  # Relative path only
  recurse = TRUE
)
```

### 2.10 Integration with Artifact Registry

Release bundles are automatically registered:

```r
registry <- register_artifact(
  registry = registry,
  artifact_name = release_name,
  artifact_type = "release_bundle",
  workflow = "chunk3",  # Or "07" for legacy
  file_path = zip_path,
  input_artifacts = c("kpro_master", "cpn_final"),
  metadata = list(
    study_id = study_id,
    n_files = n_files_in_bundle,
    zip_size_bytes = file.info(zip_path)$size
  )
)
```

---

## 3. CHUNK 3 / WORKFLOW 07: COMBINED REPORT & RELEASE

The final chunk (or Workflow 07) handles both report generation AND release bundle creation. This is the final packaging stage.

### 3.1 Stage Overview

**In Chunk Model (`run_finalize_to_report()`):**
```
Stage 1: Load User-Edited CPN Template
Stage 2: Calculate Status and CallsPerHour  
Stage 3: Save Final CPN
Stage 4: Generate Summary Statistics
Stage 5: Generate Plots
Stage 6: Generate Quarto Report
Stage 7: Create Release Bundle
Stage 8: Finalize Validation Report
```

**In Legacy Workflow 07:**
```
Stage 7.1: Load Configuration
Stage 7.2: Load Pre-computed Objects (RDS)
Stage 7.3: Generate Quarto Report
Stage 7.4: Create Release Bundle
Stage 7.5: Finalize Validation Report
Stage 7.6: Pipeline Complete Summary
```

### 3.2 Critical Principle

**The report/release stages are READ-ONLY with respect to analytical results.**

All computation happens in earlier stages/workflows. Report and release stages only:
- Load pre-computed objects
- Render reports
- Package outputs

### 3.3 RDS Discovery Pattern

```r
# Find most recent summary_data and plot_objects RDS files
rds_files <- discover_pipeline_rds(
  rds_dir = here::here("results", "rds"),
  required_types = c("summary_data", "plot_objects")
)

# Validate structure before use
validate_rds_structure(rds_files$summary_data, required = c("detector_summary", "study_summary"))
validate_rds_structure(rds_files$plot_objects, required = c("quality", "detector", "temporal"))
```

---

## 4. FUNCTION REFERENCE

### 4.1 Artifact Module (`R/functions/core/artifacts.R`)

**Registry Management:**
- `init_artifact_registry()` - Create or load artifact registry
- `register_artifact()` - Add artifact with metadata and hash
- `get_artifact()` - Retrieve artifact by name
- `list_artifacts()` - List all artifacts (optionally filtered by type)
- `get_latest_artifact()` - Get most recent artifact by type

**Hashing:**
- `hash_file()` - Compute SHA256 hash of file
- `hash_dataframe()` - Compute hash of data frame contents
- `verify_artifact()` - Check if artifact matches registered hash

**RDS Management:**
- `save_and_register_rds()` - Atomic RDS save + register (recommended for orchestrators)

**RDS Discovery:**
- `discover_pipeline_rds()` - Find summary_data and plot_objects RDS files
- `validate_rds_structure()` - Validate loaded RDS objects have required elements

### 4.2 Validation Reporting Module (`R/functions/validation/validation_reporting.R`)

**Note:** Validation tracking functions moved to separate module for separation of concerns.

**Validation Context:**
- `create_validation_context()` - Initialize validation tracking for chunk/workflow
- `log_validation_event()` - Record validation event with details
- `finalize_validation_report()` - Generate HTML/YAML validation report
- `generate_validation_html()` - Generate HTML from context

**Helper Wrappers (Recommended):**
- `init_stage_validation()` - Convenience wrapper for context initialization
- `complete_stage_validation()` - Convenience wrapper for report finalization

### 4.3 Release Module (`R/functions/core/release.R`)

**Bundle Creation:**
- `create_release_bundle()` - Create portable zip with all outputs
- `validate_release_inputs()` - Validate CPN and master data before bundling
- `generate_manifest()` - Create manifest.yaml with provenance

### 4.4 Validation Module (`R/functions/validation/validation.R`)

**Centralized Assertions:**
- `assert_data_frame()` - Assert object is data frame
- `assert_not_empty()` - Assert data frame has rows
- `assert_columns_exist()` - Assert required columns exist (with helpful hints)
- `assert_file_exists()` - Assert file exists (with creation hints)
- `assert_directory_exists()` - Assert/create directory
- `assert_scalar_string()` - Assert single string value
- `assert_date_range()` - Assert valid date range
- `assert_column_type()` - Assert column has expected class

---

## 5. QUICK REFERENCE

### 5.1 End-of-Chunk/Workflow Pattern

```r
# Register artifacts at end of every chunk/workflow
registry <- init_artifact_registry()

artifact_id <- sprintf("%s_%s", artifact_base, format(Sys.time(), "%Y%m%d_%H%M%S"))

registry <- register_artifact(
  registry = registry,
  artifact_name = artifact_id,
  artifact_type = "appropriate_type",
  workflow = "chunk1",  # Or "##" for legacy
  file_path = output_path,
  input_artifacts = c("upstream1", "upstream2"),
  metadata = list(
    n_rows = nrow(df),
    key_metric = value,
    data_filters_applied = filters_config
  )
)

# File logging (not gated by verbose)
log_message(sprintf("[Chunk N] Registered artifact: %s", artifact_id))
```

### 5.2 Downstream Usage Pattern

```r
# In NB GAMM project or other downstream analysis
bundle_dir <- "path/to/kpro_release_study_20260112"

# Option 1: Load RDS bundle
bundle <- readRDS(file.path(bundle_dir, "analysis_bundle.rds"))
cpn <- bundle$calls_per_night

# Option 2: Load CSV directly
cpn <- read_csv(file.path(bundle_dir, "data", "calls_per_night_raw.csv"))

# Verify integrity (optional)
manifest <- yaml::read_yaml(file.path(bundle_dir, "manifest.yaml"))
expected_hash <- manifest$artifacts$data[[1]]$sha256
actual_hash <- digest::digest(file = file.path(bundle_dir, "data", "calls_per_night_raw.csv"), algo = "sha256")
stopifnot(expected_hash == actual_hash)
```

### 5.3 Orchestrating Function Return Pattern

```r
run_finalize_to_report <- function(verbose = FALSE) {
  
  # ... processing stages ...
  
  # Return comprehensive structured list
  list(
    # Primary outputs
    cpn_final = cpn_final,
    summary_data = all_summaries,
    plot_objects = all_plots,
    
    # Metadata
    metadata = list(
      n_rows = nrow(cpn_final),
      n_detectors = n_distinct(cpn_final$Detector),
      date_range = as.character(range(cpn_final$Night))
    ),
    
    # File paths
    cpn_final_path = cpn_path,
    summary_rds_path = summary_rds_path,
    plots_rds_path = plots_rds_path,
    report_path = report_path,
    release_bundle_path = zip_path,
    validation_html_path = validation_html_path,
    
    # Artifact tracking
    artifact_ids = list(
      cpn_final = cpn_artifact_id,
      summary_data = summary_artifact_id,
      plot_objects = plots_artifact_id,
      report = report_artifact_id,
      release_bundle = release_artifact_id
    )
  )
}
```
