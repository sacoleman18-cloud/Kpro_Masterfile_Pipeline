# ==============================================================================
# DATA STANDARDS
# ==============================================================================
# VERSION: 2.3
# LAST UPDATED: 2026-01-31
# PURPOSE: Data handling, quality validation, fingerprinting, and validation reports
# ==============================================================================

## 1. DATA FRAME CONVENTIONS

### 1.1 Use Tibbles

```r
library(tidyverse)

df <- tibble(
  detector_id = c("A1", "A2"),
  calls = c(10, 20)
)
```

### 1.2 Column Names

- snake_case always
- Descriptive and unambiguous
- No spaces, no special characters

### 1.3 Data Frame Rules

- [OK] Use `tibble()` instead of `data.frame()`
- [OK] Keep column names consistent across workflow
- [OK] Document expected columns in function headers
- [X] NEVER modify column names after standardization
- [X] NEVER use row names (use explicit ID column)

---

## 2. MISSING DATA

### 2.1 Explicit NA Handling

```r
# [OK] GOOD: Explicit about NA behavior
total_calls <- df %>%
  summarise(total = sum(calls, na.rm = TRUE))

# [X] BAD: Implicit (what happens to NAs?)
total_calls <- df %>%
  summarise(total = sum(calls))
```

### 2.2 Check for Completeness

```r
# Before critical operations
if (any(is.na(df$detector_id))) {
  warning("Found NA values in detector_id - these will be excluded")
}
```

### 2.3 Missing Data Rules

- [OK] Always specify `na.rm = TRUE/FALSE` explicitly
- [OK] Warn users about NA values in critical columns
- [OK] Document how NAs are handled
- [X] NEVER silently remove NAs without logging

### 2. DATA SOURCING & CHECKPOINTS

- Prefer `find_most_recent_checkpoint()` (for supported patterns) instead of manual file searches.
- Use `safe_read_csv()` with explicit `na` parameters.
- Validate required columns with `assert_columns_exist()`.
- Log file source and row counts.
- Load CPN templates with `load_cpn_template()` to enforce deduplication and typed Night/RecordingHours (and log deduplication if validation context provided).

---

## 3. DATE/TIME HANDLING

### 3.1 Use Lubridate

```r
library(lubridate)

# Parsing
date <- ymd("2025-01-15")
datetime <- ymd_hms("2025-01-15 14:30:00")

# Timezone handling (CRITICAL)
datetime_utc <- ymd_hms("2025-01-15 14:30:00", tz = "UTC")
datetime_local <- force_tz(datetime_utc, tzone = "America/Chicago")
```

### 3.2 Date/Time Rules

- [OK] Always specify timezone explicitly
- [OK] Use `force_tz()` when asserting timezone (not converting)
- [OK] Use `with_tz()` when converting between timezones
- [OK] Store dates as Date class, datetimes as POSIXct
- [X] NEVER use character strings for date arithmetic
- [X] NEVER assume local timezone

### 3.3 Timezone Column Naming Convention

Use explicit timezone suffixes to prevent ambiguity:

```r
# [OK] GOOD: Explicit timezone in column name
DateTime_local
Hour_local
Date_local
DateTime_UTC

# [X] BAD: Ambiguous
DateTime
Hour
Date
```

---

## 4. DATA QUALITY VALIDATION

### 4.1 Validation Checkpoints by Chunk

| Chunk | Function | Validation Points |
|-------|----------|-------------------|
| 1 | `run_ingest_standardize()` | After loading CSVs, after schema transform, after filters, before checkpoint |
| 2 | `run_cpn_template()` | After loading master, after template generation, before save |
| 3 | `run_finalize_to_report()` | After loading CPN, after status calc, after plot generation, before report |

**Legacy Workflow Mapping:**

| Workflow | Equivalent Chunk Stage | Validation Points |
|----------|------------------------|-------------------|
| 01 + 02 | Chunk 1 | After loading each CSV, after schema detection, after transformation |
| 03 | Chunk 2 | After loading master, after filtering NoID, after species unification |
| 04-07 | Chunk 3 | After CPN finalization, after stats, after plots, before report |

### 4.2 Post-Load Validation Example

```r
df <- readRDS(here("results", "csv", "CallsPerNight_final.rds"))

# Checkpoint 1: Non-empty
assert_not_empty(df, "cpn_final")

# Checkpoint 2: Required columns
assert_columns_exist(df, 
  c("Detector", "Night", "TotalCalls", "Status", "CallsPerHour"),
  source_hint = "run_finalize_to_report()"
)

# Checkpoint 3: Data types
assert_column_type(df, "Night", "Date")

if (verbose) message("[OK] Data loaded and validated")
if (verbose) message(sprintf("  Rows: %s", format(nrow(df), big.mark = ",")))
```

### 4.3 Validation Rules

| Scope | Rule | Enforcement Example |
|-------|------|---------------------|
| Post-load | Validate after every data load | [OK] Check `nrow()`, required columns |
| Post-transform | Validate after major transformations | [OK] Verify new column created |
| Pre-save | Validate before writing outputs | [OK] Check for duplicates |
| Column existence | Verify columns before accessing | [OK] `assert_columns_exist()` |
| Data types | Check class of critical columns | [OK] `assert_column_type()` |
| Valid ranges | Check numeric ranges | [OK] `recording_hours > 0` |

### 4.4 Schema Validation

```r
# Validate schema was detected
if (is.na(schema_version)) {
  stop("Could not detect schema version - data may be corrupted")
}

# Validate expected columns for schema
expected_cols <- if (schema_version == "v1") {
  c("IN FILE", "DATE", "TIME", "AUTO ID")
} else if (schema_version == "v2") {
  c("INDIR", "DATE", "TIME", "AUTO ID")
} else {
  c("FOLDER", "IN FILE", "DATE", "TIME", "AUTO ID")
}

missing <- setdiff(expected_cols, names(df))
if (length(missing) > 0) {
  stop(sprintf(
    "Schema v%s detected but missing expected columns: %s",
    schema_version,
    paste(missing, collapse = ", ")
  ))
}
```

### 4.5 Data Quality Reporting

**Always report:**
- Number of rows processed
- Number of rows excluded (with reason)
- Number of NAs in critical columns
- Date range of data
- Unique detectors found

**Example:**
```r
if (verbose) {
  message("[OK] Data processing complete")
  message(sprintf("  Total rows: %s", format(nrow(df_original), big.mark = ",")))
  message(sprintf("  Rows after filtering: %s", format(nrow(df_clean), big.mark = ",")))
  message(sprintf("  Rows excluded: %s (%.1f%%)", 
                  format(nrow(df_original) - nrow(df_clean), big.mark = ","),
                  100 * (nrow(df_original) - nrow(df_clean)) / nrow(df_original)))
  message(sprintf("  Date range: %s to %s", min(df_clean$date), max(df_clean$date)))
  message(sprintf("  Unique detectors: %d", n_distinct(df_clean$detector)))
}
```

---

## 5. VALIDATION REPORT SYSTEM

Every chunk/workflow generates a human-readable validation report documenting all operations performed, data quality checks, and transformation summaries. These reports provide QA documentation and audit trails.

### 5.1 Output Locations

- YAML: `results/validation/validation_[chunk]_YYYYMMDD_HHMMSS.yaml`
- HTML: `results/validation/validation_[chunk]_YYYYMMDD_HHMMSS.html`

### 5.2 Validation Context

A validation context tracks events throughout chunk/workflow execution:

```r
# Initialize at chunk start
validation_context <- create_validation_context(
  workflow = "ingest",
  workflow_name = "Ingest & Standardize"
)

# Log events during processing
validation_context <- log_validation_event(
  validation_context,
  event_type = "files_loaded",
  description = "Loaded CSV files from data/raw/",
  count = 5,
  details = list(
    directory = "data/raw/",
    file_names = c("file1.csv", "file2.csv", ...)
  )
)

# Finalize at chunk end
report_path <- finalize_validation_report(
  validation_context,
  output_dir = here::here("results", "validation")
)
```

### 5.3 Event Types

The following event types are recognized and auto-accumulate in summaries:

**Data Loading:**

| Event Type | Description | Auto-Accumulates |
|------------|-------------|------------------|
| `files_loaded` | CSV files successfully loaded | count |
| `file_failed` | Individual file load failures | count |
| `data_loaded` | Data loaded into memory | rows |

**Data Quality:**

| Event Type | Description | Auto-Accumulates |
|------------|-------------|------------------|
| `rows_removed` | Rows filtered out (N <= 0, NA, invalid) | count |
| `schema_unknown` | Rows with undetectable schema version | count |
| `duplicate` | Duplicate rows detected/removed | count |
| `filter_noid` | NoID detections removed (user filter) | count |
| `filter_zero_pulses` | Zero-pulse calls removed (user filter) | count |

**Transformations:**

| Event Type | Description | Auto-Accumulates |
|------------|-------------|------------------|
| `schema_transform` | Schema version transformations applied | count |
| `detector_mapping` | Detector IDs mapped to friendly names | count |
| `timezone_conversion` | UTC to local timezone conversion | - |
| `column_added` | New columns created | count |
| `column_removed` | Columns dropped | count |

**Validation:**

| Event Type | Description | Auto-Accumulates |
|------------|-------------|------------------|
| `rows_processed` | Total rows in final output | count |
| `source_breakdown` | Local vs external data contribution | - |
| `schema_detection` | Schema version detection results | - |
| `data_filters_config` | User-configured filter settings | - |

**Status:**

| Event Type | Description | Auto-Accumulates |
|------------|-------------|------------------|
| `warning` | Non-fatal issues | count |
| `error` | Fatal issues | count |

### 5.4 Event Logging Pattern

```r
# Simple event
validation_context <- log_validation_event(
  validation_context,
  event_type = "rows_removed",
  description = "Removed rows with N <= 0",
  count = 1523
)

# Event with details
validation_context <- log_validation_event(
  validation_context,
  event_type = "schema_detection",
  description = "Detected schema versions",
  details = list(
    v1_legacy = 299,
    v2_transitional = 518,
    v3_modern = 1314,
    unknown = 0
  )
)

# Warning event
validation_context <- log_validation_event(
  validation_context,
  event_type = "warning",
  description = "Some detectors have no data for certain nights",
  details = list(
    affected_detectors = c("Det_A", "Det_B"),
    missing_nights = 12
  )
)
```

### 5.5 HTML Report Structure

Generated HTML reports contain:

1. **Header** - Chunk/workflow name, timestamp, pipeline version
2. **Summary Statistics** - Auto-accumulated counts
3. **Data Quality Section** - Rows removed, duplicates, schema issues
4. **Transformation Section** - Applied transformations with details
5. **Event Log** - Chronological list of all events
6. **Status Box** - Pass/Warning/Error indicator

**Collapsible details:** Complex event details are hidden by default and expandable.

### 5.6 Integration Patterns

**Orchestrating Function Pattern (Preferred):**
```r
run_my_chunk <- function(verbose = FALSE) {
  
  # Initialize at chunk start
  validation_context <- create_validation_context(workflow = "chunk_name")
  
  # ... processing with log_validation_event() calls ...
  
  # Finalize (always happens, not gated by verbose)
  validation_html_path <- finalize_validation_report(
    validation_context,
    output_dir = here::here("results", "validation")
  )
  
  # Return path in structured result
  list(
    data = result_data,
    validation_html_path = validation_html_path
  )
}
```

**Legacy Workflow Script Pattern:**
```r
# ==============================================================================
# STAGE #.1: INITIALIZE VALIDATION
# ==============================================================================

validation_context <- create_validation_context(
  workflow = "##",
  workflow_name = "Workflow Name"
)

# ... processing with log_validation_event() calls ...

# ==============================================================================
# FINALIZE VALIDATION REPORT
# ==============================================================================

validation_report_path <- finalize_validation_report(
  validation_context,
  output_dir = here::here("results", "validation")
)

log_message(sprintf("[Workflow ##] Validation report: %s", 
                    basename(validation_report_path)))
```

### 5.7 Validation Report Naming

Reports are named with chunk/workflow identifier and timestamp:
```
validation_ingest_20260112_014129.html
validation_ingest_20260112_014129.yaml
validation_cpn_template_20260112_020905.html
validation_finalize_20260119_143420.html
```

This allows multiple runs to be preserved and compared.

### 5.8 User-Configured Data Filters

The pipeline supports YAML-configured data filters that are applied during Chunk 1 processing. These are tracked as validation events.

**Configuration (in `study_parameters.yaml`):**
```yaml
data_filters:
  remove_duplicates: true       # Stage 6: Remove duplicate detections
  remove_noid: false            # Stage 7: Exclude auto_id == "NoID"
  remove_zero_pulse_calls: false  # Stage 7: Exclude pulses == 0 or NA
```

**Filter Application Order:**
1. **Stage 6:** Deduplication (if `remove_duplicates: true`)
2. **Stage 7:** NoID removal (if `remove_noid: true`)
3. **Stage 7:** Zero-pulse removal (if `remove_zero_pulse_calls: true`)

**Validation Event Types for Filters:**

| Event Type | Description | Logged When |
|------------|-------------|-------------|
| `duplicate` | Duplicate rows removed | `remove_duplicates: true` |
| `filter_noid` | NoID detections removed | `remove_noid: true` |
| `filter_zero_pulses` | Zero-pulse calls removed | `remove_zero_pulse_calls: true` |

**Example validation logging:**
```r
validation_context <- log_validation_event(
  validation_context,
  event_type = "filter_noid",
  description = "Removed NoID detections (user-configured filter)",
  count = 342,
  details = list(
    filter_enabled = TRUE,
    rows_before = 2000,
    rows_after = 1658
  )
)
```

**Return metadata includes filter status:**
```r
result$metadata$data_filters_applied
# Returns: list(remove_duplicates = TRUE, remove_noid = FALSE, remove_zero_pulse_calls = FALSE)

result$metadata$rows_removed
# Returns: list(invalid = 50, duplicates = 12, noid = 0, zero_pulse = 0)
```

---

## 6. DATASET FINGERPRINTING & HASHING

Cryptographic hashing provides scientific reproducibility guarantees.

### 6.1 Purpose

1. **Integrity verification** - Detect any modification to artifacts
2. **Provenance tracking** - Link outputs to specific inputs
3. **Reproducibility proof** - Same inputs produce same hashes
4. **Audit trail** - Complete chain of custody for data

### 6.2 Hashing Functions

**File hashing:**
```r
# Compute SHA256 hash of any file
file_hash <- hash_file("results/csv/Master_20260112.csv")
# Returns: "6746c39a45915e966e7337c9504afc3c10decfb1f00c8198140b98ccd52bcc33"
```

**Data frame hashing:**
```r
# Compute hash of data frame contents (order-independent)
df_hash <- hash_dataframe(calls_per_night_final)
```

**Verification:**
```r
# Check if artifact matches registered hash
is_valid <- verify_artifact(registry, "kpro_master_20260112")
# Returns: TRUE if current file hash matches registered hash
```

### 6.3 Hash Storage

Hashes are stored in two locations:

**1. Artifact Registry** (`inst/config/artifact_registry.yaml`):
```yaml
artifacts:
  cpn_final_v6_20260112:
    file_hash_sha256: d129f9ae2c1c006e64342efe811c409685a5dcf64d0a55487839376fd5a17aba
```

**2. Release Manifest** (`manifest.yaml` in release bundle):
```yaml
data_integrity:
  algorithm: "SHA256"
  artifact_hashes:
    cpn_final: "<SHA256_HASH>"
    masterfile_final: "<SHA256_HASH>"
  release_fingerprint: "<SHA256_HASH>"
```

### 6.4 Provenance Chain

The manifest tracks a complete provenance chain showing how each artifact derives from its inputs:

```yaml
provenance_chain:
  - step: 1
    name: "raw_inputs"
    hash: "<COMBINED_INPUT_HASH>"
    inputs: null
  
  - step: 2
    name: "intro_standardized"
    hash: "<SHA256_HASH>"
    inputs:
      - "raw_inputs"
      - "study_parameters_yaml"
  
  - step: 3
    name: "kpro_master"
    hash: "<SHA256_HASH>"
    inputs:
      - "intro_standardized"
      - "study_parameters_yaml"
  
  # ... continues through all pipeline steps
```

### 6.5 When to Hash

**ALWAYS hash:**
- Final data outputs (Master, CPN)
- RDS files containing analytical objects
- Release bundle contents
- Source configuration files

**NEVER hash:**
- Temporary files
- Log files
- Validation reports (they document, not produce data)

### 6.6 Hash Verification Pattern

Use this pattern when loading artifacts that require integrity:

```r
# Load with verification
load_verified_artifact <- function(artifact_name, registry) {
  
  artifact <- get_artifact(registry, artifact_name)
  
  if (is.null(artifact)) {
    stop(sprintf("Artifact not found in registry: %s", artifact_name))
  }
  
  # Verify hash
  if (!verify_artifact(registry, artifact_name)) {
    warning(sprintf(
      "Hash mismatch for %s. File may have been modified since registration.",
      artifact_name
    ))
  }
  
  # Load based on file type
  if (grepl("\\.csv$", artifact$file_path)) {
    return(readr::read_csv(artifact$file_path, show_col_types = FALSE))
  } else if (grepl("\\.rds$", artifact$file_path)) {
    return(readRDS(artifact$file_path))
  }
}
```

### 6.7 Combined Input Hash

For reproducibility, the manifest computes a combined hash of all source inputs:

```r
# Conceptual implementation
compute_combined_input_hash <- function(file_paths) {
  # Sort for deterministic order
  sorted_paths <- sort(file_paths)
  
  # Compute individual hashes
  individual_hashes <- sapply(sorted_paths, hash_file)
  
  # Concatenate and hash again
  combined <- paste(individual_hashes, collapse = "")
  digest::digest(combined, algo = "sha256", serialize = FALSE)
}
```

This ensures that the same set of input files always produces the same combined hash, regardless of processing order.
