# ==============================================================================
# DATA STANDARDS
# ==============================================================================
# VERSION: 2.4
# LAST UPDATED: 2026-02-05
# PURPOSE: Data handling, schema structures, quality validation, fingerprinting, and validation reports
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

## 2. KPRO SCHEMA STRUCTURES

### 2.1 Schema Evolution Overview

The pipeline handles three KPro schema versions, each with different column structures and species code formats. All schemas are transformed to a unified master schema during Chunk 1 processing.

| Schema | Era | Species Codes | Alternates | Key Identifier Column |
|--------|-----|---------------|------------|----------------------|
| V1 | Legacy | 4-letter | Semicolon-delimited in single column | `IN FILE` or `INFILE` |
| V2 | Transitional | 4-letter | Separate columns (alternate_1, alternate_2) | `INDIR` |
| V3 | Modern | 6-letter | Separate columns (alternate_1, alternate_2, alternate_3) | `FOLDER` |

### 2.2 Schema V1 (Legacy)

**Characteristics:**
- 4-letter species codes (e.g., "MYLU", "EPFU")
- Semicolon-delimited alternates in single column
- Two variants:
  - Traditional: `alternates` column with semicolons
  - Modern variant: `alternate_1` column with semicolons

**Key Columns:**
```
IN FILE, DATE, TIME, AUTO ID, alternates (or alternate_1 with semicolons)
```

**Example Data:**
```
AUTO ID: MYLU
alternates: EPFU;LACI;LANO
```

**Transformation:**
- Split alternates by semicolon → separate alternate_1, alternate_2, alternate_3
- Convert all 4-letter codes to 6-letter using species code map
- Result: `auto_id: MYOLUC, alternate_1: EPTFUS, alternate_2: LASCIN, alternate_3: LASNO D`

### 2.3 Schema V2 (Transitional)

**Characteristics:**
- 4-letter species codes (e.g., "MYLU", "EPFU")
- Separate alternate columns (no semicolons)
- May have alternate_1 and alternate_2, but not alternate_3

**Key Columns:**
```
INDIR, DATE, TIME, AUTO ID, alternate_1, alternate_2
```

**Transformation:**
- Add alternate_3 column (filled with NA if missing)
- Convert all 4-letter codes to 6-letter using species code map

### 2.4 Schema V3 (Modern)

**Characteristics:**
- 6-letter species codes (e.g., "MYOLUC", "EPTFUS")
- Separate alternate columns
- May have alternate_1 and alternate_2, but not alternate_3

**Key Columns:**
```
FOLDER, IN FILE, DATE, TIME, AUTO ID, alternate_1, alternate_2
```

**Transformation:**
- Add alternate_3 column (filled with NA if missing)
- Species codes already in target 6-letter format (no conversion needed)
- Pass through with minimal changes

### 2.5 Unified Master Schema

All schema versions are transformed into this unified format during Chunk 1:

**Required Columns:**
```r
# Core identification
Detector          # Character - detector name (from mapping or ID)
DateTime_local    # POSIXct - local timezone timestamp
Date_local        # Date - local date
Hour_local        # Integer - hour of day (0-23)

# Species identification (6-letter codes)
auto_id           # Character - automatic species ID
alternate_1       # Character - first alternate species
alternate_2       # Character - second alternate species
alternate_3       # Character - third alternate species
manual_id         # Character - manual review ID (optional)

# Call characteristics
N                 # Integer - number of pulses
Pulses            # Integer - alias for N (both present)

# File references
out_file_fs       # Character - full spectrum output file
out_file_zc       # Character - zero-crossing output file (optional)
```

**Optional Columns (if present in source):**
```r
Duration, Fmax, Fmin, Fc, TBC, S1, Sc, FcMedKhz, FmaxMedKhz, 
BwMedKhz, DurMedMs, TcMedS, FreqKneeMedKhz, and others
```

**Removed During Finalization:**
```r
# These columns are removed by finalize_master_columns()
orgid, userid, review_orig, review_userid, 
alternates (legacy v1), schema_version (temporary detection column)
```

### 2.6 Species Code Mapping

The pipeline uses a comprehensive species code map (60+ species) to convert 4-letter legacy codes to 6-letter modern codes:

**Example Mappings:**
```r
SPECIES_CODE_MAP_4_TO_6 <- c(
  # Myotis species
  "MYLU" = "MYOLUC",   # Little brown bat
  "MYSE" = "MYOSEP",   # Northern long-eared bat
  "MYSO" = "MYOSOD",   # Indiana bat
  
  # Eptesicus species
  "EPFU" = "EPTFUS",   # Big brown bat
  
  # Lasiurus species
  "LACI" = "LASCIN",   # Hoary bat
  "LABO" = "LASBOR",   # Eastern red bat
  "LANO" = "LASNOC",   # Silver-haired bat
  
  # ... 50+ more species
)
```

**Conversion Rules:**
- Applied to: auto_id, alternate_1, alternate_2, alternate_3
- Case-insensitive matching
- Unknown codes preserved (logged but not errored)
- NoID preserved as "NoID" (not converted)

### 2.7 Column Name Harmonization

The pipeline handles legacy-to-modern column name transitions:

**Key Harmonizations:**
```r
# Output file naming (KPro version change)
"out_file" → "out_file_fs"  # Full spectrum file
# Preserves "out_file_zc" if present (zero-crossing file)

# Coalescing: If both legacy and modern names exist, modern wins
out_file_fs = coalesce(out_file_fs, out_file)
```

### 2.8 Schema Transformation Contract

**Guarantees:**
1. **Non-destructive** - All rows preserved (no filtering)
2. **Deterministic** - Same input always produces same output
3. **Logged** - All transformations logged with row counts
4. **Type-safe** - Character columns remain character, numeric remain numeric
5. **Mixed-schema support** - Can process files with different schemas in same batch

**Validation Points:**
- Schema detection before transformation
- Required columns present after transformation
- Species code conversion completion logged
- Row count preserved across transformation

---

## 3. MISSING DATA

### 3.1 Explicit NA Handling

```r
# [OK] GOOD: Explicit about NA behavior
total_calls <- df %>%
  summarise(total = sum(calls, na.rm = TRUE))

# [X] BAD: Implicit (what happens to NAs?)
total_calls <- df %>%
  summarise(total = sum(calls))
```

### 3.2 Check for Completeness

```r
# Before critical operations
if (any(is.na(df$detector_id))) {
  warning("Found NA values in detector_id - these will be excluded")
}
```

### 3.3 Missing Data Rules

- [OK] Always specify `na.rm = TRUE/FALSE` explicitly
- [OK] Warn users about NA values in critical columns
- [OK] Document how NAs are handled
- [X] NEVER silently remove NAs without logging

---

## 4. DATE/TIME HANDLING

### 4.1 Use Lubridate

```r
library(lubridate)

# Parsing
date <- ymd("2025-01-15")
datetime <- ymd_hms("2025-01-15 14:30:00")

# Timezone handling (CRITICAL)
datetime_utc <- ymd_hms("2025-01-15 14:30:00", tz = "UTC")
datetime_local <- force_tz(datetime_utc, tzone = "America/Chicago")
```

### 4.2 Date/Time Rules

- [OK] Always specify timezone explicitly
- [OK] Use `force_tz()` when asserting timezone (not converting)
- [OK] Use `with_tz()` when converting between timezones
- [OK] Store dates as Date class, datetimes as POSIXct
- [X] NEVER use character strings for date arithmetic
- [X] NEVER assume local timezone

### 4.3 Timezone Column Naming Convention

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

## 5. DATA QUALITY VALIDATION

### 5.1 Validation Checkpoints by Chunk

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

### 5.2 Post-Load Validation Example

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

### 5.3 Validation Rules

| Scope | Rule | Enforcement Example |
|-------|------|---------------------|
| Post-load | Validate after every data load | [OK] Check `nrow()`, required columns |
| Post-transform | Validate after major transformations | [OK] Verify new column created |
| Pre-save | Validate before writing outputs | [OK] Check for duplicates |
| Column existence | Verify columns before accessing | [OK] `assert_columns_exist()` |
| Data types | Check class of critical columns | [OK] `assert_column_type()` |
| Valid ranges | Check numeric ranges | [OK] `recording_hours > 0` |

### 5.4 Schema Validation

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

### 5.5 Data Quality Reporting

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

## 6. VALIDATION REPORT SYSTEM

Every chunk/workflow generates a human-readable validation report documenting all operations performed, data quality checks, and transformation summaries. These reports provide QA documentation and audit trails.

### 6.1 Output Locations

- YAML: `results/validation/validation_[chunk]_YYYYMMDD_HHMMSS.yaml`
- HTML: `results/validation/validation_[chunk]_YYYYMMDD_HHMMSS.html`

### 6.2 Validation Context

A validation context tracks events throughout chunk/workflow execution. Validation context functions are provided in `validation_reporting.R`.

**Core Functions:**
```r
# From validation_reporting.R
create_validation_context(workflow, study_name = NULL)
log_validation_event(context, event_type, description, count, details)
finalize_validation_report(context, output_dir)
generate_validation_html(context, output_path)
```

**Helper Wrappers (Recommended):**
```r
# Convenience wrappers for orchestrators
init_stage_validation(stage_name, study_params)
complete_stage_validation(validation_context, validation_dir, stage_name, verbose)
```

**Pattern:**
```r
# Initialize at chunk start
validation_context <- init_stage_validation("chunk_1", study_params)
# Or directly:
validation_context <- create_validation_context(
  workflow = "ingest",
  study_name = study_params$study_name
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

# Finalize at chunk end (using wrapper)
validation_html_path <- complete_stage_validation(
  validation_context,
  validation_dir = here("results", "validation"),
  stage_name = "CHUNK 1",
  verbose = verbose
)
# Or directly:
validation_context <- finalize_validation_report(
  validation_context,
  output_dir = here("results", "validation")
)
```

### 6.3 Event Types

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
| `schema_helpers` | Schema version detection results | - |
| `data_filters_config` | User-configured filter settings | - |

**Status:**

| Event Type | Description | Auto-Accumulates |
|------------|-------------|------------------|
| `warning` | Non-fatal issues | count |
| `error` | Fatal issues | count |

### 6.4 Event Logging Pattern

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
  event_type = "schema_helpers",
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

### 6.5 HTML Report Structure

Generated HTML reports contain:

1. **Header** - Chunk/workflow name, timestamp, pipeline version
2. **Summary Statistics** - Auto-accumulated counts
3. **Data Quality Section** - Rows removed, duplicates, schema issues
4. **Transformation Section** - Applied transformations with details
5. **Event Log** - Chronological list of all events
6. **Status Box** - Pass/Warning/Error indicator

**Collapsible details:** Complex event details are hidden by default and expandable.

### 6.6 Integration Patterns

**Orchestrating Function Pattern (Preferred):**
```r
run_my_chunk <- function(verbose = FALSE) {
  
  # Initialize using helper wrapper
  validation_context <- init_stage_validation("chunk_name", study_params)
  
  # ... processing with log_validation_event() calls ...
  
  # Finalize using helper wrapper (always happens, not gated by verbose)
  validation_html_path <- complete_stage_validation(
    validation_context,
    validation_dir = here("results", "validation"),
    stage_name = "CHUNK NAME",
    verbose = verbose
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

### 6.7 Validation Report Naming

Reports are named with chunk/workflow identifier and timestamp:
```
validation_ingest_20260112_014129.html
validation_ingest_20260112_014129.yaml
validation_cpn_template_20260112_020905.html
validation_finalize_20260119_143420.html
```

This allows multiple runs to be preserved and compared.

### 6.8 User-Configured Data Filters

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

## 7. DATASET FINGERPRINTING & HASHING

Cryptographic hashing provides scientific reproducibility guarantees.

### 7.1 Purpose

1. **Integrity verification** - Detect any modification to artifacts
2. **Provenance tracking** - Link outputs to specific inputs
3. **Reproducibility proof** - Same inputs produce same hashes
4. **Audit trail** - Complete chain of custody for data

### 7.2 Hashing Functions

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

### 7.3 Hash Storage

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

### 7.4 Provenance Chain

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

### 7.5 When to Hash

**ALWAYS hash:**
- Final data outputs (Master, CPN)
- RDS files containing analytical objects
- Release bundle contents
- Source configuration files

**NEVER hash:**
- Temporary files
- Log files
- Validation reports (they document, not produce data)

### 7.6 Hash Verification Pattern

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

### 7.7 Combined Input Hash

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
