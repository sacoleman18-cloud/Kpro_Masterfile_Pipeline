# KPro Masterfile Pipeline

An R-based data pipeline for converting Kaleidoscope Pro bat acoustic monitoring data into standardized, analysis-ready datasets.

---

## What This Pipeline Does

Kaleidoscope Pro (KPro) produces CSV files containing bat call detections, but these files are difficult to use directly for ecological analysis due to schema inconsistencies, fragmented data across drives, and recording irregularities.

This pipeline transforms raw KPro outputs into:

1. **A unified master detection file** — all detections standardized to a common schema
2. **A Calls-Per-Night dataset** — effort-corrected activity metrics suitable for GAMMs, GLMMs, and occupancy models
3. **Summary statistics and visualizations** — 26 exploratory plots organized by category
4. **A publication-grade report** — self-contained HTML with all results
5. **A portable release bundle** — zip file ready for downstream projects

---

## Requirements

- **R** (≥ 4.1.0)
- **Quarto** (for report generation)
- Required R packages:
```r
  install.packages(c(
    "tidyverse", "here", "yaml", "janitor", "readr",
    "lubridate", "ggplot2", "gt", "quarto", "zip", "digest"
  ))
```

---

## Quick Start

### 1. Configure your study

Edit `inst/config/study_parameters.yaml`:
```yaml
config_version: 1

study_parameters:
  study_name: "MyBatStudy"
  start_date: "2025-06-01"
  end_date: "2025-08-31"
  timezone: "America/Chicago"
  detector_mapping:
    <HARDWARE_ID>: <FRIENDLY_NAME>
  external_data_sources: "E:/MyDetectorData"

processing_options:
  recording_start: "20:00:00"
  recording_end: "06:00:00"
  intended_hours: 10
```

### 2. Run the pipeline

Execute workflows in order:
```r
source("R/workflows/01_ingest_raw_data.R")
source("R/workflows/02_standardize.R")
source("R/workflows/03_generate_cpn_template.R")

# >>> PAUSE: Edit outputs/03_CallsPerNight_Template_EDIT_THIS_*.csv <
#     Correct recording hours for detector malfunctions if needed

source("R/workflows/04_finalize_cpn.R")
source("R/workflows/05_summary_stats.R")
source("R/workflows/06_exploratory_plots.R")
source("R/workflows/07_generate_report.R")
```

### 3. Collect outputs

After pipeline completion:

| Output | Location |
|--------|----------|
| Master detection file | `outputs/final/Master_*.csv` |
| Calls-Per-Night dataset | `results/csv/CallsPerNight_final_v*.csv` |
| Summary statistics | `results/rds/summary_data_*.rds` |
| Visualizations | `results/figures/*.png` |
| HTML report | `results/reports/bat_activity_report_*.html` |
| Release bundle | `results/releases/kpro_release_*.zip` |

---

## Pipeline Workflows

| Workflow | Purpose |
|----------|---------|
| **01** | Ingest raw KPro CSVs, detect schema versions |
| **02** | Standardize to unified master format |
| **03** | Generate Calls-Per-Night template for review |
| **04** | Finalize CPN with user corrections |
| **05** | Compute summary statistics |
| **06** | Generate exploratory visualizations |
| **07** | Render report and create release bundle |

**Note:** The only manual step is editing the CPN template between Workflows 03 and 04 to correct recording hours for detector malfunctions or partial nights.

---

## Outputs Explained

### Calls-Per-Night Dataset

The primary output for ecological modeling:

| Column | Description |
|--------|-------------|
| `Detector` | Detector name |
| `Night` | Recording night (date) |
| `CallsPerNight` | Total detections |
| `RecordingHours` | Actual recording hours |
| `Status` | Full / Partial / NoData |
| `CallsPerHour` | Effort-corrected activity |

### Visualizations (26 plots)

- **Quality** (6): Recording effort, data completeness, missing nights
- **Detector** (8): Activity comparisons, correlations, rankings
- **Species** (5): Composition, distributions, accumulation curves
- **Temporal** (7): Nightly trends, hourly profiles, seasonal patterns

---

## Data Sources

The pipeline accepts KPro data from two sources:

1. **Local files** — Place CSVs in `data/raw/`
2. **External directories** — Specify paths in `study_parameters.yaml`

Both sources are combined and processed identically. The pipeline handles mixed KPro schema versions automatically.

---

## Configuration Reference

Key parameters in `study_parameters.yaml`:

| Parameter                           | Description                             |
| ----------------------------------- | --------------------------------------- |
| `study_name`                        | Identifier used in outputs              |
| `start_date` / `end_date`           | Study period bounds                     |
| `timezone`                          | Local timezone for timestamp conversion |
| `detector_mapping`                  | Hardware ID → friendly name mapping     |
| `external_data_sources`             | Paths to external data directories      |
| `recording_start` / `recording_end` | Expected recording schedule             |
| `intended_hours`                    | Expected hours per night                |

See `inst/config/YAML_PARAMETER_GUIDE.md` for complete documentation.

---

## Downstream Integration

The release bundle (`results/releases/*.zip`) is designed for direct consumption by downstream projects:
```
kpro_release_<study>_<timestamp>/
├── manifest.yaml
├── data/
│   ├── calls_per_night_raw.csv  ← Primary modeling input
│   └── kpro_master.csv
├── figures/
│   └── [all PNG visualizations]
└── reports/
    └── bat_activity_report.html
```

Compatible with the NB GAMM Bat project without renaming or reformatting.

---

## Project Status

**Functional pipeline under active refinement.**

All workflows execute successfully and produce valid outputs. See `docs/Project_Overview.md` for architectural details and planned improvements.

---

## Repository Structure
```
├── R/
│   ├── workflows/       # Numbered pipeline scripts (01-07)
│   └── functions/       # Modular function libraries
├── inst/config/         # Configuration files
├── data/raw/            # Local input CSVs
├── outputs/             # Intermediate checkpoints
├── results/             # Final outputs (csv, rds, figures, reports)
├── reports/             # Quarto templates
├── logs/                # Pipeline logs
└── docs/                # Documentation
```

---

## Documentation

- **Architectural Overview**: `docs/Project_Overview.md`
- **Coding Standards**: `CODING_STANDARDS_v2.1.md`
- **YAML Guide**: `inst/config/YAML_PARAMETER_GUIDE.md`

---

## License

[Specify license]

---

## Citation

[Specify citation guidance]