# KPro Masterfile Pipeline: Architectural Overview

**Version:** 2.1  
**Status:** Functional pipeline under active refinement  
**Domain:** Bat Acoustic Monitoring / Bioacoustics  

---

## 1. Project Purpose

Kaleidoscope Pro (KPro) is the dominant software for automated bat call identification, producing CSV files containing detection events with species classifications. However, KPro outputs present significant challenges for downstream ecological analysis:

- **Schema instability**: KPro has evolved through multiple versions, each with different column structures (4-letter vs. 6-letter species codes, varying column names, inconsistent date formats).
- **Fragmented data**: Field deployments typically produce data scattered across multiple external drives, detector folders, and file naming conventions.
- **Recording irregularities**: Detector malfunctions, partial-night failures, and variable recording schedules create gaps that must be documented and corrected before statistical modeling.
- **Manual effort**: Converting raw KPro outputs into analysis-ready datasets typically requires hours of manual spreadsheet manipulation, introducing transcription errors and destroying reproducibility.

The KPro Masterfile Pipeline solves these problems by providing a deterministic, auditable transformation from raw KPro CSVs to a standardized Calls-Per-Night dataset suitable for ecological inference (GAMMs, GLMMs, occupancy models). The pipeline assumes disorder in source data and imposes structure deliberately, transparently, and reproducibly.

---

## 2. Scope & Non-Goals

### What This Pipeline Does

- Ingests KPro `id.csv` files from local directories and external drives
- Detects KPro schema version per row (v1 legacy, v2 transitional, v3 modern)
- Harmonizes mixed-version data into a unified master schema
- Maps hardware detector IDs to human-readable names
- Converts timestamps to a consistent local timezone
- Generates a detector × night grid (Calls-Per-Night template) for manual review
- Calculates summary statistics (study-level, detector-level, species-level)
- Produces exploratory visualizations organized by analytical category
- Renders publication-grade Quarto reports from pre-computed artifacts
- Creates portable release bundles for downstream projects

### What This Pipeline Does Not Do

- **Does not perform species distribution modeling** — CPN output is designed as input for external modeling workflows (e.g., NB GAMM Bat project)
- **Does not modify raw audio files** — operates exclusively on KPro CSV outputs
- **Does not perform manual species validation** — that task belongs in Kaleidoscope Pro before data enters this pipeline
- **Does not recompute metrics during reporting** — Workflow 07 is strictly read-only with respect to analytical results
- **Does not replace Kaleidoscope Pro** — operates downstream of KPro as a standardization layer

### Operational Model

The intended end-state is a Shiny application where:

1. User fills out configuration fields (study name, dates, detector mappings, timezone, recording schedule)
2. Pipeline executes Workflows 01–03 automatically
3. User optionally edits the CPN template CSV (clearly labeled `EDIT_THIS` in outputs)
4. Pipeline executes Workflows 04–07 automatically
5. User receives final report and release bundle

This is the only manual intervention point in a complete pipeline run.

---

## 3. High-Level Pipeline Architecture
```
Raw KPro CSVs
     ↓
[01] Ingest & intro-standardize
     ↓
[02] Schema harmonization → Masterfile
     ↓
[03] CPN template generation
     ↓
 [USER EDIT - optional]
     ↓
[04] CPN finalization
     ↓
[05] Summary statistics → RDS
     ↓
[06] Exploratory plots → RDS
     ↓
[07] Quarto report + Release bundle
```

**Critical Design Principle**: All computation ends at Workflow 06. Workflow 07 is a presentation layer that renders pre-computed objects without transformation. This separation ensures:

- Reports are deterministic (same RDS inputs → same report)
- No analytical drift occurs during rendering
- Artifacts can be audited independently of report generation

---

## 4. Workflow Breakdown

### Workflow 01 — Raw Data Ingestion

| Attribute | Description |
|-----------|-------------|
| **Purpose** | Load raw KPro CSVs with minimal processing |
| **Inputs** | `data/raw/*.csv`, external directories (from YAML) |
| **Outputs** | `outputs/checkpoints/01_intro_standardized_YYYYMMDD_HHMMSS.csv` |
| **Guarantees** | Schema version detected per row; source file lineage preserved; invalid files logged but do not halt processing |

### Workflow 02 — Standardize to Master Schema

| Attribute | Description |
|-----------|-------------|
| **Purpose** | Transform mixed-schema data into unified master format |
| **Inputs** | Output from Workflow 01 (memory or checkpoint) |
| **Outputs** | `outputs/checkpoints/02_kpro_master_YYYYMMDD_HHMMSS.csv` |
| **Guarantees** | All rows conform to master schema; detector IDs mapped to friendly names; timestamps converted to local timezone; duplicates removed with logging |

### Workflow 03 — Generate CPN Template

| Attribute | Description |
|-----------|-------------|
| **Purpose** | Create detector × night grid for user review |
| **Inputs** | `kpro_master` from Workflow 02 |
| **Outputs** | `outputs/03_CallsPerNight_Template_EDIT_THIS_YYYYMMDD.csv`, `outputs/03_CallsPerNight_Template_ORIGINAL_YYYYMMDD.csv` |
| **Guarantees** | Complete grid for study period; recording hours pre-populated from schedule; original preserved for diff comparison |

### Workflow 04 — Finalize CPN

| Attribute | Description |
|-----------|-------------|
| **Purpose** | Process user-edited template, calculate derived metrics |
| **Inputs** | User-edited CPN template |
| **Outputs** | `results/csv/CallsPerNight_final_vN.csv` |
| **Guarantees** | Status column computed (Full/Partial/NoData); CallsPerHour calculated; version incremented on each run |

### Workflow 05 — Summary Statistics

| Attribute | Description |
|-----------|-------------|
| **Purpose** | Compute all summary statistics for reporting |
| **Inputs** | `CallsPerNight_final`, `kpro_master` |
| **Outputs** | `results/rds/summary_data_YYYYMMDD.rds` |
| **Guarantees** | Study-level, detector-level, and species-level summaries computed; gt table objects pre-rendered; no computation deferred to reporting |

### Workflow 06 — Exploratory Plots

| Attribute | Description |
|-----------|-------------|
| **Purpose** | Generate all visualization objects |
| **Inputs** | `CallsPerNight_final`, `kpro_master` |
| **Outputs** | `results/rds/plot_objects_YYYYMMDD.rds`, `results/figures/*.png` |
| **Guarantees** | All ggplot objects stored in categorized list structure; PNG exports for standalone use; no plot generation in Workflow 07 |

**Plot Inventory by Category:**

- **Quality** (6 plots): recording status summary, recording status percent, data completeness calendar, missing nights, recording effort heatmap, effort by detector
- **Detector** (8 plots): total calls by detector, detector boxplots, detector activity caterpillar, correlation heatmap, synchrony, detector rank over time, activity with/without outliers, nights by detector
- **Species** (5 plots): species composition bar, species by detector heatmap, species hourly profile, species accumulation curve, NoID proportion
- **Temporal** (7 plots): activity over time, hourly activity profile, weekly activity, activity by month, cumulative calls over time, calls-per-hour distribution

### Workflow 07 — Generate Report & Release Bundle

| Attribute | Description |
|-----------|-------------|
| **Purpose** | Render final outputs from pre-computed artifacts |
| **Inputs** | RDS files from Workflows 05–06, study_parameters.yaml |
| **Outputs** | `results/reports/bat_activity_report_YYYYMMDD.html`, `results/releases/kpro_release_<study_id>_<timestamp>.zip` |
| **Guarantees** | Read-only with respect to data; no computation or transformation; self-contained HTML; portable zip with manifest |

---

## 5. Data Contracts & Artifacts

### Masterfile (`kpro_master`)

The master detection file is the canonical record of all bat call detections for a study. Each row represents one detection event with standardized fields:

- `Detector`: Human-readable detector name
- `DateTime_local`: POSIXct timestamp in study timezone
- `Date_local`, `Time_local`, `Hour_local`: Derived temporal fields
- `auto_id`: KPro automated species identification (6-letter code)
- `alternate_1`, `alternate_2`: Secondary species candidates
- `match_ratio`, `margin`: Classification confidence metrics
- `pulses`, `dur`, `fc`, `fmax`, `fmin`: Acoustic parameters

**Contract**: Downstream workflows may read but never modify the masterfile.

### Calls-Per-Night (`CallsPerNight_final`)

The CPN dataset aggregates detections to the detector-night level for temporal analysis:

- `Detector`: Detector identifier
- `Night`: Date of the recording night (assigned by sunset rule)
- `CallsPerNight`: Total detections for that detector-night
- `RecordingHours`: Actual hours of recording (may be user-corrected)
- `Status`: Full | Partial | NoData
- `CallsPerHour`: Effort-corrected activity metric

**Contract**: This is the primary output for downstream modeling. Schema is stable and documented for external consumers.

### Summary RDS (`summary_data_YYYYMMDD.rds`)

Pre-computed analytical summaries stored as a named list:

- `study_summary`: Overall study metrics (detectors, nights, total calls, effort)
- `detector_summary`: Per-detector statistics (calls, hours, CPH, variability)
- `species_summary`: Species composition and frequency
- `metadata`: Generation timestamp, source files, pipeline version

**Contract**: Workflow 07 reads these objects directly into report. No transformation permitted.

### Plot RDS (`plot_objects_YYYYMMDD.rds`)

Pre-computed ggplot objects organized by category:
```r
list(
  quality = list(recording_status_summary, ...),
  detector = list(correlation_heatmap, ...),
  species = list(species_composition_bar, ...),
  temporal = list(activity_over_time, ...)
)
```

**Contract**: Workflow 07 iterates over this structure to render plots. No new plots generated during reporting.

---

## 6. Reproducibility & Provenance Model

### Deterministic Outputs

The pipeline guarantees that identical inputs produce identical outputs:

- No random seeds in processing logic
- Timestamp-based file naming for traceability
- Explicit column ordering in all exports

### Checkpointing

Each workflow produces a timestamped checkpoint file that can be used to:

- Resume processing after interruption
- Audit intermediate states
- Compare outputs across runs

### Artifact Registry

The pipeline maintains an artifact registry (`inst/config/artifact_registry.yaml`) that tracks:

- File paths and timestamps
- SHA256 hashes for integrity verification
- Input-output relationships (provenance chain)
- Pipeline version at generation time

### Validation Reports

Each workflow generates a validation report (`results/validation/validation_NN_YYYYMMDD.html`) documenting:

- Rows loaded, transformed, and removed
- Schema detection results
- Warnings and anomalies
- Processing timestamps

### Forward-Only Data Flow

Data flows strictly forward through the pipeline (01→02→03→04→05→06→07). No workflow modifies outputs from earlier stages. This ensures that any artifact can be traced back through the provenance chain to its source files.

---

## 7. Reporting Philosophy

The Quarto report generated by Workflow 07 operates under strict constraints:

1. **Presentation layer only**: The report renders pre-computed objects. It does not perform calculations, transformations, or aggregations.

2. **Frozen artifacts**: All plots and tables come from RDS files generated in Workflows 05–06. The report cannot generate new visualizations.

3. **Parameterized rendering**: File paths are passed via Quarto parameters, not hardcoded. The same template renders any study's artifacts.

4. **Self-contained output**: The HTML report embeds all resources (images, styles) for portability.

5. **Reproducible footer**: Every report includes session information documenting R version, platform, and source artifact filenames.

This design explicitly separates *what* is computed from *how* it is presented, enabling:

- Independent auditing of analytical results vs. report formatting
- Re-rendering reports without re-running analysis
- Guaranteed consistency between artifacts and their presentation

---

## 8. Configuration & Customization

### `study_parameters.yaml`

All study-specific configuration is declared in a single YAML file:
```yaml
config_version: 1

study_parameters:
  study_name: "SchmeeckleBatStudy"
  start_date: "2025-10-04"
  end_date: "2025-10-31"
  timezone: "America/Chicago"
  detector_mapping:
    245AAA0666BC08AE: LPI
    245AAA0666BC1507: LPE
    # ... additional detectors
  external_data_sources: "F:/Schmeeckle analyzed 102725"

processing_options:
  advanced_scheduling: no
  recording_start: "18:00:00"
  recording_end: "07:00:00"
  intended_hours: 13

output_preferences:
  master_filename: "final_master.csv"
  callspernight_filename: "CallsPerNight_final.csv"
  save_directory: "results/csv"
```

### User-Controllable Parameters

- Study metadata (name, dates, timezone)
- Detector ID → name mappings
- External data source paths
- Recording schedule (uniform or advanced)
- Output file naming preferences

### Pipeline-Controlled Behavior

- Schema detection logic
- Column transformations
- Deduplication rules
- Validation checks
- Report structure

Users configure *what* to process; the pipeline controls *how* it is processed.

---

## 9. Intended Users & Use Cases

### Primary Users

- **Wildlife researchers**: Processing acoustic monitoring data for ecological studies
- **Environmental consultants**: Producing defensible datasets for impact assessments
- **Long-term monitoring programs**: Standardizing multi-year, multi-site datasets

### Use Case Examples

- Processing a single field season (1 site, 10 detectors, 30 nights)
- Combining historical data spanning multiple KPro versions
- Preparing datasets for regulatory submission with full audit trail
- Generating exploratory reports for preliminary data review

### Prerequisites

- Basic R familiarity (running scripts, viewing outputs)
- Understanding of acoustic monitoring data structure
- Access to Kaleidoscope Pro for initial species classification

---

## 10. Project Maturity & Status

### Current State

The pipeline is **functional and producing valid outputs**. All seven workflows execute successfully on test datasets, producing:

- Standardized masterfiles
- Finalized CPN datasets
- Summary statistics
- Exploratory visualizations
- Quarto reports
- Release bundles

### Active Refinement Areas

The following areas are under ongoing development:

- **Hashing comprehensiveness**: Expanding artifact registry coverage
- **Validation report cleanup**: Improving HTML report formatting and content
- **Plot refinement**: Enhancing visual clarity and labeling
- **Report refinement**: Improving Quarto report structure and narrative
- **Table refinement**: Enhancing gt table formatting
- **Script cleanup**: Refactoring workflow and function scripts for maintainability

### Planned Future Work

- **Shiny application**: Full GUI wrapper with config-driven pipeline execution
- **Read-only mode enforcement**: Shiny safety controls preventing accidental data modification
- **Config-driven behavior expansion**: Additional YAML parameters for fine-grained control
- **JSON API layer**: Soft interface for programmatic pipeline invocation
- **Execution profiles**: More detailed performance and diagnostic logging

---

## 11. Repository Structure
```
project_root/
├── R/
│   ├── workflows/           # Numbered pipeline scripts (01-07)
│   └── functions/           # Modular function libraries
│       ├── core/            # config.R, utilities.R, load_all.R
│       ├── ingestion/       # ingestion.R, schema_detection.R
│       ├── standardization/ # standardization.R, datetime_conversion.R
│       ├── validation/      # validation.R
│       ├── analysis/        # callspernight.R, summarization.R
│       └── output/          # plot_*.R, tables.R, report.R, release.R
├── inst/
│   └── config/              # study_parameters.yaml, artifact_registry.yaml
├── data/
│   └── raw/                 # Local input CSVs
├── outputs/
│   └── checkpoints/         # Intermediate workflow outputs
├── results/
│   ├── csv/                 # Final CPN and master exports
│   ├── rds/                 # Pre-computed summary and plot objects
│   ├── figures/             # Exported PNG visualizations
│   ├── reports/             # Rendered Quarto HTML reports
│   ├── releases/            # Portable release bundles
│   └── validation/          # Workflow validation reports
├── reports/
│   └── bat_activity_report.qmd  # Quarto template
├── logs/                    # Pipeline and error logs
└── docs/                    # Project documentation
```

---

## 12. License & Attribution

See `README.md` for license information and citation guidance.