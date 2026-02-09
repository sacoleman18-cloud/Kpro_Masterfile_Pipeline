# KPro Pipeline: Quick Start Guide

This guide shows how to use the 3-chunk orchestrating functions for the KPro Masterfile Pipeline.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Pipeline Overview](#pipeline-overview)
3. [Chunk 1: Ingest & Standardize](#chunk-1-ingest--standardize)
4. [Chunk 2: Generate CPN Template](#chunk-2-generate-cpn-template)
5. [Chunk 3: Finalize to Report](#chunk-3-finalize-to-report)
6. [Complete Pipeline Example](#complete-pipeline-example)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### 1. Install R and Required Packages

```r
# Install required packages
install.packages(c(
  "tidyverse", "lubridate", "janitor", "hms", "yaml",
  "here", "digest", "gt", "scales", "quarto", "zip"
))

# Optional packages for enhanced features
install.packages(c("viridis", "svglite", "webshot2", "openxlsx"))
```

### 2. Prepare Data and Configuration

1. **Place raw KPro CSV files** in `data/raw/` directory
2. **Configure study parameters** in `inst/config/study_parameters.yaml`

Example YAML configuration:

```yaml
config_version: 1

study_parameters:
  study_name: "MyBatStudy2024"
  start_date: "2024-10-01"
  end_date: "2024-10-31"
  timezone: "America/Chicago"
  detector_mapping:
    245AAA0666BC08AE: "Detector_A"
    245AAA0666BC1507: "Detector_B"
  external_data_sources:
    - "F:/External_Data_Drive/KPro_Output"

processing_options:
  advanced_scheduling: no
  recording_start: "18:00:00"
  recording_end: "07:00:00"
  intended_hours: 13

  data_filters:
    remove_duplicates: true
    remove_noid: false
    remove_zero_pulse_calls: false

output_preferences:
  master_filename: "kpro_master.csv"
  callspernight_filename: "CallsPerNight_final.csv"
  save_directory: "results/csv"
```

---

## Pipeline Overview

The KPro pipeline consists of three orchestrating functions:

```
┌─────────────────────────────────────────────────────────────┐
│  Chunk 1: run_ingest_standardize()                         │
│  Raw CSVs → kpro_master                                     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Chunk 2: run_cpn_template()                                │
│  kpro_master → CPN template (ORIGINAL + EDIT_THIS)          │
└─────────────────────────────────────────────────────────────┘
                          ↓
              [USER EDITS RECORDING HOURS]
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Chunk 3: run_finalize_to_report()                          │
│  Edited template → Final report + release bundle            │
└─────────────────────────────────────────────────────────────┘
```

---

## Chunk 1: Ingest & Standardize

### Purpose
Load raw KPro CSV files, standardize schemas, map detectors, and convert timezones.

### Usage

```r
# Load all functions
source("R/functions/load_all.R")

# Run Chunk 1 (silent mode - default)
result1 <- run_ingest_standardize()

# OR with verbose output for debugging
result1 <- run_ingest_standardize(verbose = TRUE)
```

### Output Structure

```r
# Access results
kpro_master <- result1$kpro_master           # Main dataset
result1$metadata$n_rows                       # Total rows
result1$metadata$n_detectors                  # Number of detectors
result1$metadata$detectors                    # Detector names
result1$metadata$date_range                   # Study period
result1$metadata$rows_removed                 # Filtering summary
result1$checkpoint_path                       # Saved checkpoint CSV
result1$validation_html_path                  # Validation report
```

### What Gets Created

- `outputs/checkpoints/02_kpro_master_YYYYMMDD_HHMMSS.csv` - Checkpoint file
- `results/validation/validation_ingest_YYYYMMDD_HHMMSS.html` - Validation report
- Updated `inst/config/artifact_registry.yaml` - Artifact tracking

---

## Chunk 2: Generate CPN Template

### Purpose
Create detector × night grid template for recording hour review and manual editing.

### Standard Workflow

```r
# Run Chunk 2 using result from Chunk 1
result2 <- run_cpn_template(
  kpro_master = result1$kpro_master,
  verbose = TRUE
)
```

### Manual ID Workflow (Optional)

If you manually reviewed species IDs in Kaleidoscope Pro:

```r
# Run Chunk 2 with manually-ID'd file
result2 <- run_cpn_template(
  manual_id_file = "path/to/manually_reviewed.csv",
  verbose = TRUE
)
```

### Output Structure

```r
# Access results
cpn_template <- result2$cpn_template          # Template grid
kpro_master <- result2$kpro_master            # Master with species column
result2$metadata$n_nights                     # Number of study nights
result2$metadata$manual_id_used               # TRUE if manual ID used
result2$template_edit_path                    # File to edit
result2$template_original_path                # Tracking file (DO NOT EDIT)
```

### What Gets Created

- `outputs/03_CallsPerNight_Template_ORIGINAL_YYYYMMDD_HHMMSS.csv` - Original (tracking)
- `outputs/03_CallsPerNight_Template_EDIT_THIS_YYYYMMDD_HHMMSS.csv` - **USER EDITS THIS**
- `results/validation/validation_cpn_template_YYYYMMDD_HHMMSS.html` - Validation report
- Updated artifact registry

### Manual Editing Step

1. **Open the EDIT_THIS file** in Excel or R
2. **Review StartDateTime and EndDateTime** columns
3. **Edit recording times** if detectors failed or ran partial nights
4. **Save the edited file** (keep same filename)
5. **Proceed to Chunk 3**

---

## Chunk 3: Finalize to Report

### Purpose
Process edited template, generate statistics, create plots, render report, and package release bundle.

### Usage

```r
# Run Chunk 3 with edited template
result3 <- run_finalize_to_report(
  kpro_master = result2$kpro_master,
  edited_template_file = result2$template_edit_path,
  create_release_bundle = TRUE,
  verbose = TRUE
)
```

### Output Structure

```r
# Workflow 04: Finalize CPN
cpn_final <- result3$workflow_04$calls_per_night_final
result3$workflow_04$cpn_file                  # Final CPN CSV path
result3$workflow_04$total_edits               # Manual edits tracked
result3$workflow_04$status_distribution       # Fail/Success/Partial counts

# Workflow 05: Summary Statistics
all_summaries <- result3$workflow_05$all_summaries
result3$workflow_05$summary_rds               # Summary RDS path
result3$workflow_05$files_created             # Table exports

# Workflow 06: Exploratory Plots
all_plots <- result3$workflow_06$all_plots
result3$workflow_06$plots_rds                 # Plots RDS path
result3$workflow_06$plot_counts               # Counts by category

# Workflow 07: Report & Release
result3$workflow_07$report_html               # MAIN DELIVERABLE
result3$workflow_07$release_zip               # Portable bundle
result3$workflow_07$report_size_kb            # Report file size

# Overall Summary
result3$summary$pipeline_duration_sec         # Total execution time
result3$summary$total_detectors               # Detector count
result3$summary$total_calls                   # Total bat calls
```

### What Gets Created

**CallsPerNight:**
- `results/csv/CallsPerNight_final_v1.csv` - Final CPN dataset (versioned)
- `outputs/04_CallsPerNight_EditLog_YYYYMMDD_HHMMSS.txt` - Edit tracking

**Statistics:**
- `results/rds/summary_data_YYYYMMDD.rds` - All summary objects
- `results/figures/detector_summary_YYYYMMDD.{png,html}` - Detector table
- `results/figures/study_summary_YYYYMMDD.{png,html}` - Study overview
- `results/tables/summary_statistics_YYYYMMDD.xlsx` - Excel workbook (optional)

**Plots:**
- `results/rds/plot_objects_YYYYMMDD.rds` - All plot ggplot objects
- `results/figures/png/quality/*.png` - 8 quality plots
- `results/figures/png/detector/*.png` - 7 detector plots
- `results/figures/png/species/*.png` - 5 species plots (if applicable)
- `results/figures/png/temporal/*.png` - 6 temporal plots

**Report & Release:**
- `results/reports/bat_activity_report_YYYYMMDD.html` - **MAIN DELIVERABLE**
- `results/releases/kpro_release_<study_id>_<timestamp>.zip` - **PORTABLE BUNDLE**

**Validation:**
- `results/validation/validation_finalize_cpn_YYYYMMDD_HHMMSS.html`
- `results/validation/validation_summary_stats_YYYYMMDD_HHMMSS.html`
- `results/validation/validation_exploratory_plots_YYYYMMDD_HHMMSS.html`
- `results/validation/validation_report_release_YYYYMMDD_HHMMSS.html`

---

## Complete Pipeline Example

### End-to-End Execution

```r
# =============================================================================
# KPro Masterfile Pipeline - Complete Execution
# =============================================================================

# Load all functions
source("R/functions/load_all.R")

# -----------------------------------------------------------------------------
# CHUNK 1: Ingest & Standardize
# -----------------------------------------------------------------------------

cat("\n=== CHUNK 1: Ingest & Standardize ===\n")
result1 <- run_ingest_standardize(verbose = TRUE)

cat(sprintf("\n✓ Chunk 1 complete: %d rows, %d detectors\n",
            result1$metadata$n_rows,
            result1$metadata$n_detectors))

# -----------------------------------------------------------------------------
# CHUNK 2: Generate CPN Template
# -----------------------------------------------------------------------------

cat("\n=== CHUNK 2: Generate CPN Template ===\n")
result2 <- run_cpn_template(
  kpro_master = result1$kpro_master,
  verbose = TRUE
)

cat(sprintf("\n✓ Chunk 2 complete: %d nights\n",
            result2$metadata$n_nights))

cat("\n⚠ MANUAL STEP REQUIRED:\n")
cat(sprintf("   Edit this file: %s\n", basename(result2$template_edit_path)))
cat("   Review and adjust StartDateTime/EndDateTime as needed.\n")
cat("   Press Enter when done editing...\n")
readline()

# -----------------------------------------------------------------------------
# CHUNK 3: Finalize to Report
# -----------------------------------------------------------------------------

cat("\n=== CHUNK 3: Finalize to Report ===\n")
result3 <- run_finalize_to_report(
  kpro_master = result2$kpro_master,
  edited_template_file = result2$template_edit_path,
  create_release_bundle = TRUE,
  verbose = TRUE
)

cat(sprintf("\n✓ Chunk 3 complete: %.1f seconds\n",
            result3$summary$pipeline_duration_sec))

# -----------------------------------------------------------------------------
# PIPELINE COMPLETE
# -----------------------------------------------------------------------------

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                   PIPELINE COMPLETE                           ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")
cat("\n")
cat("Main Deliverables:\n")
cat(sprintf("  Report: %s\n", basename(result3$workflow_07$report_html)))
cat(sprintf("  Release: %s\n", basename(result3$workflow_07$release_zip)))
cat("\n")
cat(sprintf("Study: %s\n", result3$summary$study_name))
cat(sprintf("Detectors: %d\n", result3$summary$total_detectors))
cat(sprintf("Total Calls: %s\n", format(result3$summary$total_calls, big.mark = ",")))
cat(sprintf("Recording Hours: %.1f\n", result3$summary$total_recording_hours))
cat("\n")
```

---

## Troubleshooting

### Common Issues

#### Issue: "study_parameters.yaml not found"
**Solution:** Create configuration file at `inst/config/study_parameters.yaml` using the template above.

#### Issue: "No CSV files found"
**Solution:** 
- Check that CSV files are in `data/raw/` directory
- Verify filenames match KPro output patterns (`*id.csv`)
- Check `external_data_sources` paths in YAML

#### Issue: "Detector not mapped"
**Solution:** Add detector ID to `detector_mapping` section in YAML:

```yaml
detector_mapping:
  YOUR_DETECTOR_ID: "Friendly_Name"
```

#### Issue: "Timezone not configured"
**Solution:** Add timezone to YAML:

```yaml
study_parameters:
  timezone: "America/Chicago"  # Or your local timezone
```

Find valid timezones with: `OlsonNames()`

#### Issue: "Required columns missing"
**Solution:** 
- Ensure you ran previous chunks successfully
- Check that kpro_master has required columns (Detector, DateTime_local, auto_id)
- For Chunk 3, verify edited template has StartDateTime, EndDateTime columns

#### Issue: "Report rendering failed"
**Solution:**
- Check that Quarto is installed: `quarto::quarto_version()`
- Install Quarto from: https://quarto.org/docs/get-started/
- Verify template exists: `reports/bat_activity_report.qmd`

---

## Advanced Usage

### Skip Release Bundle Creation

```r
result3 <- run_finalize_to_report(
  kpro_master = result2$kpro_master,
  edited_template_file = result2$template_edit_path,
  create_release_bundle = FALSE,  # Skip ZIP creation
  verbose = TRUE
)
```

### Load from Checkpoints (Resume After Interruption)

```r
# Run Chunk 2 without Chunk 1 result (loads from checkpoint)
result2 <- run_cpn_template(verbose = TRUE)

# Run Chunk 3 without Chunk 2 result (loads from checkpoints)
result3 <- run_finalize_to_report(verbose = TRUE)
```

### Access Intermediate Artifacts

```r
# Load summary RDS manually
all_summaries <- readRDS(result3$workflow_05$summary_rds)
detector_summary <- all_summaries$detector_summary

# Load plot objects manually
all_plots <- readRDS(result3$workflow_06$plots_rds)
quality_plots <- all_plots$quality
```

---

## Next Steps

1. **Review validation reports** for quality checks
2. **Examine the HTML report** for study insights
3. **Download release bundle** for archival/sharing
4. **Use CallsPerNight_final.csv** for downstream modeling (GAMMs, GLMMs)

For detailed pipeline architecture and standards, see:
- `README.md` - High-level overview
- `docs/ST_architecture_standards.md` - File structure and organization
- `docs/ST_STANDARDS_INDEX.md` - Complete standards reference

---

**Need Help?** See [CONTRIBUTING.md](CONTRIBUTING.md) for support resources.
