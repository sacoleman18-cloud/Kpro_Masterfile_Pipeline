# ==============================================================================
# BAT ACOUSTIC ANALYSIS PIPELINE: CODING STANDARDS
# ==============================================================================
# VERSION: 2.1
# LAST UPDATED: 2026-01-09
# PURPOSE: Single source of truth for all code development in this project
# ==============================================================================

## CORE PHILOSOPHY

This pipeline is designed to be:

1. **Safe** - Never corrupts data, always validates inputs
2. **Defensive** - Assumes things will go wrong and handles gracefully
3. **Reproducible** - Same inputs → same outputs, every time
4. **Replicable** - Works on any computer, any operating system
5. **Portable** - No hardcoded paths, no environment dependencies
6. **User-Friendly** - Designed for researchers who may not know R
7. **Audit-Compliant** - Every transformation logged and tracked
8. **Publication-Ready** - Meets scientific reporting standards
9. **Future-Proof** - Designed for Quarto reports and Shiny apps
10. **Maintainable** - Clear, documented, modular code

---

## 1. PROJECT ARCHITECTURE STANDARDS

### 1.1 Directory Structure

```
project_root/
├── R/
│   ├── workflows/
│   │   ├── 01_ingest_raw_data.R
│   │   ├── 02_standardize.R
│   │   ├── 03_generate_cpn_template.R
│   │   ├── 04_finalize_cpn.R
│   │   ├── 05_summary_stats.R
│   │   ├── 06_generate_plots.R
│   │   └── 07_generate_report.R
│   └── functions/
│       ├── core/
│       │   ├── config.R
│       │   ├── utilities.R
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
│           └── tables.R
├── inst/
│   └── config/
│       └── study_parameters.yaml
├── reports/ 
│	 └── bat_activity_report.qmd
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
│   └── rds/
├── logs/
├── docs/
└── tests/
```

**RULES:**
- ✅ All paths relative to project root
- ✅ Use `here::here()` for cross-platform compatibility
- ✅ `results/` directory for Workflow 05/06 outputs
- ✅ `checkpoints/` vs `final/` distinction in outputs
- ❌ NEVER hardcode absolute paths
- ❌ NEVER reference parent directories (`../`)
- ❌ NEVER commit user data to version control
- ❌ NEVER put analysis outputs in `outputs/` (use `results/`)

### 1.2 File Naming Conventions

**Workflow scripts:**
```
01_ingest_raw_data.R
02_standardize.R
03_generate_cpn_template.R
04_finalize_cpn.R
05_summary_stats.R
06_generate_plots.R
07_generate_report.R
```
Format: `##_verb_noun.R` (numbered, descriptive, snake_case)

**Function files:**
```
schema_detection.R
datetime_conversion.R
recording_hours.R
```
Format: `noun_noun.R` or `verb_noun.R` (descriptive, snake_case)

**Plot module files:**
```
plot_quality.R
plot_detector.R
plot_species.R
plot_temporal.R
plot_helpers.R
```
Format: `plot_[category].R`

**Output files from Workflow 05:**
```
results/tables/gt_study_overview_YYYYMMDD.html
results/tables/gt_detector_summary_YYYYMMDD.html
results/csv/summary_stats_YYYYMMDD.csv
```

**Output files from Workflow 06:**
```
results/figures/png/quality/recording_status_summary_YYYYMMDD.png
results/figures/png/detector/correlation_heatmap_YYYYMMDD.png
results/figures/svg/species/species_composition_bar_YYYYMMDD.svg
results/rds/plot_objects_YYYYMMDD.rds
```

**Checkpoint files:**
```
outputs/checkpoints/01_intro_standardized_YYYYMMDD_HHMMSS.csv
outputs/checkpoints/02_kpro_master_YYYYMMDD_HHMMSS.csv
outputs/final/03_CallsPerNight_Template_ORIGINAL_YYYYMMDD_HHMMSS.csv
results/csv/CallsPerNight_final_v1.csv
```
Format: `##_description_YYYYMMDD_HHMMSS.csv` or `description_vN.csv`

**RULES:**
- ✅ Use snake_case for all files
- ✅ Include timestamps for checkpoints
- ✅ Version numbers for final outputs
- ✅ Descriptive names (no abbreviations like `tmp`, `data1`, `final_FINAL_v2`)
- ❌ NEVER use spaces in filenames
- ❌ NEVER use special characters except `_` and `-`

### 1.3 Layer Responsibilities

Each workflow has a distinct purpose. These roles are architectural guarantees, not suggestions.

#### Workflows 01-02: Data Ingestion & Standardization Layer

**Purpose:** Load raw KPro CSVs, detect schemas, transform to unified master format.

**Allowed actions:**
- Read raw CSV files from `data/raw/`
- Apply intro standardization
- Detect and transform schemas (v1/v2/v3)
- Write checkpoints to `outputs/checkpoints/`

**Explicitly forbidden:**
- Analysis or aggregation
- Plotting or visualization
- Modifying study_parameters.yaml after initial setup

#### Workflow 03: Template Generation Layer

**Purpose:** Generate CallsPerNight template, optional manual ID import, species unification.

**Allowed actions:**
- Read kpro_master from Workflow 02
- Generate CPN template with recording schedules
- Import manual ID files (optional)
- Create unified `species` column
- Write template to `outputs/` for user editing

**Explicitly forbidden:**
- Modifying kpro_master source
- Final CPN calculations (that's Workflow 04)
- Plotting or analysis

#### Workflow 04: CPN Finalization Layer

**Purpose:** Process user-edited template, calculate Status and CallsPerHour.

**Allowed actions:**
- Read user-edited template
- Calculate recording hours, Status, CallsPerHour
- Validate data quality
- Write final CPN to `results/csv/`

**Explicitly forbidden:**
- Modifying the original template
- Analysis beyond Status/CPH calculation
- Plotting

#### Workflow 05: Analysis Layer

**Purpose:** Generate summary statistics and GT tables.

**Allowed actions:**
- Read `calls_per_night_final` from Workflow 04
- Calculate summary statistics
- Generate GT tables
- Write to `results/tables/` and `results/csv/`

**Explicitly forbidden:**
- Modifying source data
- Generating plots (that's Workflow 06)

#### Workflow 06: Visualization Layer

**Purpose:** Generate exploratory plots for data inspection and reporting.

**Allowed actions:**
- Read `calls_per_night_final` and `kpro_master`
- Generate ggplot objects
- Export PNG/SVG to `results/figures/`
- Export RDS to `results/rds/`

**Explicitly forbidden:**
- Modifying source data
- Statistical analysis or inference
- Writing to `outputs/`

#### Workflow 07: Reporting Layer

**Purpose:** Generate final Quarto report combining all results.

**Allowed actions:**
- Read all outputs from Workflows 05-06
- Load plot objects from RDS
- Render Quarto document

**Explicitly forbidden:**
- Any data transformation
- Generating new plots or tables (use existing)

#### Layer Responsibility Rules

| Scope | Rule | Enforcement Example |
|-------|------|---------------------|
| Data flow | Data flows forward only (01→02→03→04→05→06→07) | ❌ Workflow 05 modifying Workflow 02 output |
| Layer separation | Each workflow has one purpose | ❌ Plotting in Workflow 04 |
| Output locations | Analysis outputs go to `results/`, not `outputs/` | ✅ `results/figures/png/` for plots |
| Source immutability | Never modify upstream outputs | ❌ Workflow 06 editing `calls_per_night_final` |

---

[[2. DOCUMENTATION STANDARDS -edit]]

Every workflow script (01, 02, 03, etc.) must have this header:

```r
# ==============================================================================
# WORKFLOW ##: [WORKFLOW NAME]
# ==============================================================================
# PURPOSE
# -------
# [One paragraph description of what this workflow does]
#
# INPUTS
# ------
# - [Source 1]: [Description]
# - [Source 2]: [Description]
#
# OUTPUTS
# -------
# - [Output 1]: [Path/Description]
# - [Output 2]: [Path/Description]
#
# DEPENDENCIES
# ------------
# R Packages:
#   - [package]: [what for]
#
# Internal Functions:
#   - [file.R]: [functions used]
#
# STAGES
# ------
# Stage #.#: [Stage Name] - [Brief description]
# Stage #.#: [Stage Name] - [Brief description]
#
# PLOT INVENTORY (for visualization workflows)
# --------------------------------------------
# Category (N plots):
#   - function_name: brief description
#
# TABLE INVENTORY (for analysis workflows)
# ----------------------------------------
# - gt_table_name: brief description
#
# DATA TRANSFORMATIONS APPLIED
# ----------------------------
# 1. Transformation name: description
# 2. Another transformation: description
#
# USAGE
# -----
# source("R/workflows/##_workflow_name.R")
# [OR] Run interactively in RStudio
#
# CHANGELOG
# ---------
# YYYY-MM-DD: Description of changes
# YYYY-MM-DD: Initial version
# ==============================================================================
```

### 2.3 Inline Comments

**Use inline comments for:**
- Complex logic that isn't obvious
- Why a particular approach was chosen
- Known edge cases or gotchas
- TODO items (with date and initials)

**Examples:**
```r
# Use lubridate::force_tz() instead of with_tz() because we're 
# asserting what timezone the data SHOULD BE in, not converting
datetime_local <- force_tz(datetime_utc, tzone = "America/Chicago")

# Schema v1 uses semicolon-delimited alternates; split and keep first
auto_id <- str_split(auto_id_raw, ";")[[1]][1]

# TODO (2025-12-26, RSC): Add validation for missing detector names
```

**RULES:**
- ✅ Explain WHY, not WHAT (code shows what)
- ✅ Keep comments up-to-date with code
- ✅ Use full sentences with proper grammar
- ❌ NEVER leave commented-out code (use Git)
- ❌ NEVER use comments as version control

### 2.4 Function Script Headers

All function files (e.g., `plot_quality.R`, `summarization.R`) must have a standardized header at the top of the file, separate from individual function Roxygen documentation.

**Required Template:**
```r
# =============================================================================
# MODULE: [filename].R — [Module Description]
# =============================================================================
# PURPOSE
# -------
# [One paragraph description of what this module provides]
#
# DEPENDENCIES
# ------------
# R Packages:
#   - [package]: [what for]
#
# Internal Dependencies:
#   - [file.R]: [functions used]
#
# FUNCTIONS PROVIDED
# ------------------
# [Category 1]:
#   - function_1(): brief description
#   - function_2(): brief description
#
# [Category 2]:
#   - function_3(): brief description
#
# USAGE
# -----
# source("R/functions/[path]/[filename].R")
# result <- function_1(data)
#
# CHANGELOG
# ---------
# YYYY-MM-DD: [Description of changes]
# YYYY-MM-DD: Initial version
# =============================================================================
```

**Example (plot_quality.R):**
```r
# =============================================================================
# MODULE: plot_quality.R — Data Quality Visualization Functions
# =============================================================================
# PURPOSE
# -------
# Provides functions for visualizing recording quality, effort, and
# data completeness across detectors and nights. All plots use consistent
# theme_kpro() styling and return ggplot objects for Quarto integration.
#
# DEPENDENCIES
# ------------
# R Packages:
#   - ggplot2: All plotting
#   - dplyr: Data manipulation
#   - scales: Axis formatting
#
# Internal Dependencies:
#   - plot_helpers.R: theme_kpro(), kpro_palette_*(), validate_plot_input()
#
# FUNCTIONS PROVIDED
# ------------------
# Recording Status (3):
#   - plot_recording_status_summary(): Stacked bar by detector
#   - plot_recording_status_percent(): 100% stacked bar
#   - plot_recording_status_overall(): Donut chart
#
# Effort Analysis (3):
#   - plot_effort_by_detector(): Total hours by detector
#   - plot_nights_by_detector(): Night count by detector
#   - plot_recording_effort_heatmap(): Date × Detector heatmap
#
# Completeness (2):
#   - plot_data_completeness_calendar(): Calendar view
#   - plot_missing_nights(): Gap analysis
#
# USAGE
# -----
# source("R/functions/output/plot_helpers.R")
# source("R/functions/output/plot_quality.R")
#
# p <- plot_recording_status_summary(calls_per_night_final)
# ggsave("results/figures/png/quality/status_summary.png", p)
#
# CHANGELOG
# ---------
# 2026-01-07: Added plot_recording_effort_heatmap (moved from plot_temporal.R)
# 2026-01-05: Initial version with 7 functions
# =============================================================================
```

---

## 3. CODE DESIGN STANDARDS

### 3.1 Function Design Principles

**Single Responsibility:**
- Each function does ONE thing well
- If you can't describe it in one sentence, it's too complex

**Pure Functions (when possible):**
- Same inputs → same outputs
- No side effects (except logging)
- Don't modify global state

**Defensive Programming:**
- Validate inputs at function entry
- Check for NA, NULL, empty data frames
- Provide helpful error messages

**Return Values:**
- Be explicit about what you return
- Use `invisible()` for functions called for side effects
- Document return structure

**Pattern for functions returning ggplot objects:**
```r
plot_example <- function(data) {
  # Validation
  validate_plot_input(data, required_cols = c("x", "y"))
  
  # Build and return (never print)
  ggplot(data, aes(x = x, y = y)) +
    geom_point() +
    theme_kpro()
}
```

**Quiet mode for Quarto-ready functions:**
```r
generate_summary <- function(df, quiet = FALSE) {
  if (!quiet) message("Generating summary...")
  # ... processing ...
  if (!quiet) message("✓ Summary complete")
  invisible(result)
}
```

**RULES:**
- ✅ Functions should be < 50 lines (ideally < 30)
- ✅ Use early returns for error conditions
- ✅ Validate all inputs
- ✅ Name functions as verbs (actions): `calculate_`, `validate_`, `transform_`
- ❌ NEVER use global variables
- ❌ NEVER modify data frames in place (return new ones)

### 3.2 Error Handling Standards

**Every error message must:**
1. Explain WHAT went wrong
2. Explain WHERE it went wrong (filename, column, row)
3. Suggest HOW to fix it

**Good error messages:**
```r
# ✅ GOOD: Actionable, specific, helpful
if (!file.exists(checkpoint_file)) {
  stop(sprintf(
    "Checkpoint file not found: %s\n  Did you run Workflow 02 first?\n  Expected location: outputs/checkpoints/",
    basename(checkpoint_file)
  ))
}

# ✅ GOOD: Context + suggestion
missing_cols <- setdiff(required_cols, names(df))
if (length(missing_cols) > 0) {
  stop(sprintf(
    "Missing required columns: %s\n  Found columns: %s\n  This suggests schema detection failed. Check data format.",
    paste(missing_cols, collapse = ", "),
    paste(names(df), collapse = ", ")
  ))
}
```

**Bad error messages:**
```r
# ❌ BAD: Uninformative
stop("Error")

# ❌ BAD: No context
stop("File not found")

# ❌ BAD: No suggestion
stop("Invalid data")
```

**Error Handling Rules:**

| Scope | Rule | Enforcement Example |
|-------|------|---------------------|
| Actionable errors | Must tell user what to do | ✅ "Run Workflow 02 first" |
| Context inclusion | Include filename, column name, row count | ✅ `sprintf("Missing %d rows", n)` |
| Formatting | Use `sprintf()` for messages | ✅ `sprintf("AIC: %.2f", aic)` |
| Suggestions | Include fix suggestions | ✅ "Consider reviewing data ingestion" |
| Never generic | Never "Error occurred" alone | ❌ `stop("Error")` |
| Never silent | Always throw error or warn | ❌ `if (error) return(NULL)` silently |
| Severity matching | Use appropriate level | ❌ `stop()` for optional missing column |

### 3.3 Variable Naming

**Snake_case for everything in R:**
```r
detector_id          # ✅ Good
detectorId           # ❌ Bad (camelCase)
detector.id          # ❌ Bad (dot notation)
```

**Descriptive names:**
```r
recording_start_time # ✅ Good
rst                  # ❌ Bad (unclear abbreviation)
time1                # ❌ Bad (meaningless)
```

**Boolean variables:**
```r
is_valid             # ✅ Good
has_species_column   # ✅ Good
valid                # ❌ Bad (unclear)
```

**RULES:**
- ✅ Use full words (not abbreviations)
- ✅ Be specific (not `data`, but `calls_per_night`)
- ✅ Use consistent terminology across codebase
- ❌ NEVER use single letters (except `i` in loops)
- ❌ NEVER reuse variable names

### 3.4 Code Organization

**Within a function:**
```r
my_function <- function(df) {
  
  # -------------------------
  # Input validation
  # -------------------------
  if (!is.data.frame(df)) stop("df must be a data frame")
  
  # -------------------------
  # Data preparation
  # -------------------------
  clean_df <- df %>%
    filter(!is.na(value))
  
  # -------------------------
  # Core processing
  # -------------------------
  result <- clean_df %>%
    summarise(total = sum(value))
  
  # -------------------------
  # Return
  # -------------------------
  result
}
```

**Within a workflow script:**
```r
# ==============================================================================
# STAGE 1.1: LOAD RAW DATA
# ==============================================================================

message("\n┌────────────────────────────────────────────┐")
message("│      STAGE 1.1: Load Raw Data              │")
message("└────────────────────────────────────────────┘\n")

# Stage code here...

# ==============================================================================
# STAGE 1.2: APPLY INTRO STANDARDIZATION
# ==============================================================================

message("\n┌────────────────────────────────────────────┐")
message("│  STAGE 1.2: Apply Intro Standardization   │")
message("└────────────────────────────────────────────┘\n")

# Stage code here...
```

---

## 4. DATA HANDLING STANDARDS

### 4.1 Data Frame Conventions

**Use tibbles:**
```r
library(tidyverse)

df <- tibble(
  detector_id = c("A1", "A2"),
  calls = c(10, 20)
)
```

**Column names:**
- snake_case always
- Descriptive and unambiguous
- No spaces, no special characters

**RULES:**
- ✅ Use `tibble()` instead of `data.frame()`
- ✅ Keep column names consistent across workflow
- ✅ Document expected columns in function headers
- ❌ NEVER modify column names after standardization
- ❌ NEVER use row names (use explicit ID column)

### 4.2 Missing Data

**Explicit NA handling:**
```r
# ✅ GOOD: Explicit about NA behavior
total_calls <- df %>%
  summarise(total = sum(calls, na.rm = TRUE))

# ❌ BAD: Implicit (what happens to NAs?)
total_calls <- df %>%
  summarise(total = sum(calls))
```

**Check for completeness:**
```r
# Before critical operations
if (any(is.na(df$detector_id))) {
  warning("Found NA values in detector_id - these will be excluded")
}
```

**RULES:**
- ✅ Always specify `na.rm = TRUE/FALSE` explicitly
- ✅ Warn users about NA values in critical columns
- ✅ Document how NAs are handled
- ❌ NEVER silently remove NAs without logging

### 4.3 Date/Time Handling

**Use lubridate:**
```r
library(lubridate)

# Parsing
date <- ymd("2025-01-15")
datetime <- ymd_hms("2025-01-15 14:30:00")

# Timezone handling (CRITICAL)
datetime_utc <- ymd_hms("2025-01-15 14:30:00", tz = "UTC")
datetime_local <- force_tz(datetime_utc, tzone = "America/Chicago")
```

**RULES:**
- ✅ Always specify timezone explicitly
- ✅ Use `force_tz()` when asserting timezone (not converting)
- ✅ Use `with_tz()` when converting between timezones
- ✅ Store dates as Date class, datetimes as POSIXct
- ❌ NEVER use character strings for date arithmetic
- ❌ NEVER assume local timezone

---

## 5. DATA QUALITY STANDARDS

### 5.1 Validation Checkpoints

**Validation Points by Workflow:**

| Workflow | Validation Points |
|----------|-------------------|
| 01 | After loading each CSV, after combining, before checkpoint |
| 02 | After schema detection, after transformation, before save |
| 03 | After loading master, after filtering NoID, after species unification |
| 04 | After loading CPN, after status calculation, after merging |
| 05 | After loading CPN final, before each GT table generation |
| 06 | After loading data, before each plot generation |

**Post-Load Validation Example:**
```r
df <- readRDS(here("results", "csv", "CallsPerNight_final.rds"))

# Checkpoint 1: Non-empty
if (nrow(df) == 0) {
  stop("Loaded data is empty - check source file")
}

# Checkpoint 2: Required columns
required_cols <- c("Detector", "Night", "TotalCalls", "Status", "CallsPerHour")
missing <- setdiff(required_cols, names(df))
if (length(missing) > 0) {
  stop(sprintf("Missing required columns: %s", paste(missing, collapse = ", ")))
}

# Checkpoint 3: Data types
if (!inherits(df$Night, "Date")) {
  stop("Column 'Night' must be of class Date")
}

message("✓ Data loaded and validated")
message(sprintf("  Rows: %s", format(nrow(df), big.mark = ",")))
```

**Validation Rules:**

| Scope | Rule | Enforcement Example |
|-------|------|---------------------|
| Post-load | Validate after every data load | ✅ Check `nrow()`, required columns |
| Post-transform | Validate after major transformations | ✅ Verify new column created |
| Pre-save | Validate before writing outputs | ✅ Check for duplicates |
| Column existence | Verify columns before accessing | ✅ `setdiff(required, names(df))` |
| Data types | Check class of critical columns | ✅ `inherits(df$Night, "Date")` |
| Valid ranges | Check numeric ranges | ✅ `recording_hours > 0` |

### 5.2 Schema Validation

**After detecting schema:**
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

### 5.3 Data Quality Reporting

**Always report:**
- Number of rows processed
- Number of rows excluded (with reason)
- Number of NAs in critical columns
- Date range of data
- Unique detectors found

**Example:**
```r
message("✓ Data processing complete")
message(sprintf("  Total rows: %s", format(nrow(df_original), big.mark = ",")))
message(sprintf("  Rows after filtering: %s", format(nrow(df_clean), big.mark = ",")))
message(sprintf("  Rows excluded: %s (%.1f%%)", 
                format(nrow(df_original) - nrow(df_clean), big.mark = ","),
                100 * (nrow(df_original) - nrow(df_clean)) / nrow(df_original)))
message(sprintf("  Date range: %s to %s", min(df_clean$date), max(df_clean$date)))
message(sprintf("  Unique detectors: %d", n_distinct(df_clean$detector)))
```

---

## 6. LOGGING STANDARDS

### 6.1 Log File Management

**Log files must:**
- Be written to `logs/` directory
- Use ISO 8601 timestamps
- Be named: `pipeline_YYYY-MM-DD.log`
- Be appended (not overwritten)

**Implementation:**
```r
log_message <- function(message) {
  log_dir <- here::here("logs")
  if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)
  
  log_file <- file.path(log_dir, sprintf("pipeline_%s.log", Sys.Date()))
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  
  cat(sprintf("[%s] %s\n", timestamp, message), 
      file = log_file, 
      append = TRUE)
}
```

### 6.2 What to Log

**ALWAYS log:**
- Workflow start/end times
- Files loaded (path and row count)
- Major transformations (what was done)
- Validation failures/warnings
- Files written (path and row count)
- Errors and their context

**NEVER log:**
- Sensitive data (detector locations, etc.)
- Full data frames
- Passwords or credentials

**Example logging in workflow:**
```r
log_message("=== WORKFLOW 01: INGEST RAW DATA - START ===")

log_message(sprintf("Loading CSV files from: %s", raw_data_dir))
log_message(sprintf("Found %d CSV files", length(csv_files)))

# ... processing ...

log_message(sprintf("Loaded %s rows from %d files", 
                   format(nrow(raw_combined), big.mark = ","),
                   length(csv_files)))

log_message(sprintf("Applied intro standardization"))
log_message(sprintf("Saved checkpoint: %s", checkpoint_file))

log_message("=== WORKFLOW 01: INGEST RAW DATA - COMPLETE ===")
```

---

## 7. QUARTO INTEGRATION STANDARDS

### 7.1 Quiet Mode Implementation

All analysis and visualization functions should support a `quiet` parameter for Quarto documents:

```r
analyze_data <- function(df, quiet = FALSE) {
  if (!quiet) message("Analyzing data...")
  
  result <- df %>%
    summarise(...)
  
  if (!quiet) {
    message("✓ Analysis complete")
    message(sprintf("  Rows processed: %s", format(nrow(df), big.mark = ",")))
  }
  
  invisible(result)
}
```

### 7.2 Return Structured Results

Functions should return lists for complex outputs:

```r
generate_analysis <- function(df) {
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

### 7.3 RDS Output Pattern for Plot Reuse

Save all plots for Quarto documents:

```r
# In Workflow 06: Save all plots
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

### 7.4 Quarto Chunk Best Practices

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
| Quiet mode | All functions support `quiet = FALSE` | ✅ `if (!quiet) message(...)` |
| Return objects | Return data/plots, never print | ✅ `invisible(result)` |
| Structured results | Return lists with named components | ✅ `list(table = ..., plot = ...)` |
| ggplot objects | Return ggplot, don't call `print()` | ✅ `ggplot(...) + theme_kpro()` |
| No hardcoded formats | Never specify PDF vs HTML | ❌ `ggsave(..., device = "pdf")` |
| Config-driven | Parameters in YAML, not hardcoded | ✅ `smooth_k <- params$smooth_k` |

### 7.5 Workflow 07 Report Standards

Workflow 07 auto-generates a publication-grade Quarto report from pre-computed objects. It is **read-only** with respect to analytical results—no computation, transformation, or plot generation occurs.

#### 7.5.1 Directory Structure

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

- ✅ Templates live in `reports/` at project root
- ✅ Rendered outputs go to `results/reports/`
- ✅ Output filenames include date stamp
- ❌ NEVER put .qmd files in `R/` or `inst/`

#### 7.5.2 Report Template Requirements

**YAML Header (required elements):**

yaml

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

- ✅ Use parameterized rendering (`params:` block)
- ✅ Self-contained HTML (`self-contained: true`)
- ✅ Suppress code/warnings/messages by default
- ✅ Consistent figure dimensions across all plots
- ❌ NEVER hardcode RDS file paths in the template

#### 7.5.3 Programmatic Plot Iteration

Reports must iterate over plot collections programmatically rather than referencing individual plots by name. This ensures completeness and reduces maintenance burden.

**Pattern using purrr::iwalk:**

r

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

- ✅ Iterate over all plots in each category
- ✅ Use `results: asis` for dynamic headers
- ✅ Explicitly `print()` ggplot objects in loops
- ❌ NEVER hardcode individual plot names
- ❌ NEVER skip plots without documenting why

#### 7.5.4 Caption Standards

Every plot must have an automatically generated caption. Captions should be descriptive, not interpretive.

**Helper function:**

r

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

- ✅ Describe what is shown (not what it means)
- ✅ Reference data source when relevant
- ✅ Use formal, neutral scientific language
- ❌ NEVER include interpretation or inference
- ❌ NEVER use casual language

**Examples:**

```
✅ "Recording Status Summary. Generated from standardized pipeline output."
✅ "Species composition by detector showing call counts per species."
❌ "This plot shows that Detector A performed poorly."
❌ "Interesting pattern in the correlation matrix!"
```

#### 7.5.5 Conditional Sections

Some sections (e.g., species) may not apply to all datasets. Use conditional rendering.

**Pattern for optional sections:**

r

```r
#| label: species-section-check
#| results: asis

has_species <- !is.null(all_plots$species) && length(all_plots$species) > 0

if (has_species) {
  cat("\n\n# Species Composition\n\n")
  cat("This section presents species-level detection patterns.\n\n")
}
```

r

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

- ✅ Check for data presence before rendering section
- ✅ Use `eval: !expr variable` for conditional chunks
- ✅ Document why sections may be skipped
- ❌ NEVER show empty sections or error messages

#### 7.5.6 Required Report Sections

Every auto-generated report must include these sections (in order):

|Section|Purpose|Data Source|
|---|---|---|
|Study Overview|Study metadata, parameters|`study_parameters.yaml`, `all_summaries$metadata`|
|Data Quality & Coverage|Recording status, effort, completeness|`all_plots$quality`|
|Detector Activity|Activity comparisons, correlations|`all_plots$detector`|
|Species Composition|Species patterns (conditional)|`all_plots$species`|
|Temporal Patterns|Time-based activity patterns|`all_plots$temporal`|
|Summary Statistics|Tables from Workflow 05|`all_summaries$detector_summary`, etc.|
|Reproducibility|Session info, file references|R session, params|

#### 7.5.7 Reproducibility Footer

Every report must end with reproducibility information:

r

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

- ✅ Include timestamp of report generation
- ✅ Include R version and platform
- ✅ Reference source RDS files by name
- ✅ Include full `sessionInfo()` (can be collapsed)

#### 7.5.8 Workflow 07 Orchestration Script

The `07_generate_report.R` script must:

1. **Discover RDS files** - Find most recent `summary_data_*.rds` and `plot_objects_*.rds`
2. **Validate structure** - Check for required elements before rendering
3. **Load configuration** - Read `study_parameters.yaml` for metadata
4. **Render report** - Call `quarto::quarto_render()` with parameters
5. **Move output** - Place rendered HTML in `results/reports/`

**Validation requirements:**

r

```r
# Required elements in summary_data RDS
required_summary_names <- c("detector_summary", "study_summary", "metadata")

# Required categories in plot_objects RDS
required_plot_categories <- c("quality", "detector", "temporal")

# Species is optional
has_species <- !is.null(all_plots$species) && length(all_plots$species) > 0
```

**RULES:**

- ✅ Fail fast if required RDS files missing
- ✅ Validate RDS structure before rendering
- ✅ Pass file paths via `execute_params`
- ✅ Log report generation to pipeline log
- ❌ NEVER compute statistics in Workflow 07
- ❌ NEVER generate new plots in Workflow 07

#### 7.5.9 Workflow 07 Report Rules Summary

|Scope|Rule|Enforcement|
|---|---|---|
|Read-only|No computation or transformation|❌ `df %>% mutate(...)`|
|No new plots|Use pre-computed objects only|❌ `ggplot(df, ...)`|
|Parameterized|File paths via params, not hardcoded|✅ `params$summary_rds`|
|Complete|All plots in RDS must appear in report|✅ `purrr::iwalk()`|
|Deterministic|Same inputs → same report|✅ No random elements|
|Self-contained|Single HTML file, no external deps|✅ `self-contained: true`|
|Captioned|Every plot has auto-generated caption|✅ `make_caption()`|
|Reproducible|Session info in footer|✅ `sessionInfo()`|

---

## 8. PATH MANAGEMENT STANDARDS

### 8.1 Using here::here()

**ALWAYS use here::here() for paths:**
```r
library(here)

# ✅ GOOD: Cross-platform, relative to project root
data_file <- here("data", "raw", "detector_A1.csv")
output_file <- here("outputs", "checkpoints", "01_intro_standardized.csv")

# ❌ BAD: Hardcoded absolute path
data_file <- "C:/Users/John/bat_project/data/raw/detector_A1.csv"

# ❌ BAD: Relative path (breaks if working directory changes)
data_file <- "data/raw/detector_A1.csv"
```

**RULES:**
- ✅ Use `here::here()` for ALL file paths
- ✅ Build paths from components (not strings)
- ✅ Use forward slashes (/) even on Windows
- ❌ NEVER use `setwd()`
- ❌ NEVER use absolute paths
- ❌ NEVER use `../` parent directory notation

### 8.2 Dynamic Path Generation

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

## 9. VERSION CONTROL STANDARDS

### 9.1 Git Commit Messages

**Format:**
```
type: Brief description (50 chars max)

Longer explanation if needed (wrap at 72 chars)
- Bullet points for details
- Why the change was made
- Any side effects

Closes #123
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code restructuring (no behavior change)
- `test`: Adding/updating tests
- `chore`: Maintenance (dependencies, etc.)

**Examples:**
```
feat: Add manual ID import workflow to Script 03

- Add Stage 3.0 for manual ID file selection
- Implement NoID filtering with Option B logic
- Update documentation for manual ID workflow

Closes #42
```

```
fix: Correct Excel formula column references in template

Template was referencing columns F/E instead of E/D.
Updated row-aware formula generation to use correct refs.
```

**RULES:**
- ✅ Use conventional commit format
- ✅ First line ≤ 50 characters
- ✅ Use imperative mood ("Add" not "Added")
- ✅ Reference issues when applicable
- ❌ NEVER commit with message "updates" or "changes"

### 9.2 .gitignore Requirements

**ALWAYS ignore:**
```gitignore
# User data (never commit sensitive or large data)
data/
*.csv
*.wav
*.txt

# Outputs (reproducible, shouldn't be in repo)
outputs/
results/
logs/

# R/RStudio files
.Rproj.user/
.Rhistory
.RData
.Ruserdata

# Operating system
.DS_Store
Thumbs.db

# Credentials
*.yaml  # If contains sensitive info
.env
```

**RULES:**
- ✅ Never commit user data
- ✅ Never commit outputs (use releases for sharing)
- ✅ Never commit credentials
- ✅ Commit .gitignore to repo
- ❌ NEVER commit large files (> 10 MB)

---

## 10. TESTING STANDARDS

### 10.1 Testing Priority

| Priority | Functions | Coverage Target |
|----------|-----------|-----------------|
| Critical | `validate_*`, `detect_*_schema` | 100% |
| High | `convert_datetime_*`, `calculate_recording_hours` | 90% |
| Medium | `plot_*`, `gt_*` | 75% |
| Low | `format_*`, `theme_*` | 50% |

### 10.2 Test File Naming

```
tests/
├── test_validation.R
├── test_schema_detection.R
├── test_datetime_conversion.R
├── test_callspernight.R
└── test_plot_functions.R
```

### 10.3 Testing Requirements

**Test coverage expectations:**
- Core functions: 100% coverage
- Validation functions: 100% coverage
- Workflow scripts: Integration tests

**Example test:**
```r
test_that("calculate_recording_hours handles overnight correctly", {
  # Test overnight recording
  hours <- calculate_recording_hours("20:00:00", "08:00:00")
  expect_equal(hours, 12)
  
  # Test same-day recording
  hours <- calculate_recording_hours("06:00:00", "18:00:00")
  expect_equal(hours, 12)
  
  # Test NA handling
  hours <- calculate_recording_hours(NA, "08:00:00")
  expect_true(is.na(hours))
})
```

**RULES:**
- ✅ Test edge cases (NA, empty, zero)
- ✅ Test expected behavior
- ✅ Test error conditions
- ✅ Use descriptive test names
- ❌ NEVER skip testing validation functions

---

## 11. DEPENDENCY MANAGEMENT STANDARDS

### 11.1 Package Loading

**At top of each workflow script:**
```r
# ==============================================================================
# DEPENDENCIES
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)   # Data manipulation
  library(lubridate)   # Date/time handling
  library(here)        # Path management
  library(yaml)        # Config files
})
```

**RULES:**
- ✅ Load all packages at top of script
- ✅ Use `library()` not `require()`
- ✅ Comment what each package is for
- ✅ Use `suppressPackageStartupMessages()` to reduce noise
- ❌ NEVER use `library()` in functions
- ❌ NEVER use `::` for frequently used functions (use for rare ones)

### 11.2 Package Dependencies

**Core dependencies (always loaded):**
```r
library(tidyverse)  # Data manipulation, ggplot2
library(lubridate)  # Date/time handling
library(hms)        # Time parsing
library(yaml)       # Configuration files
library(here)       # Path management
```

**Analysis dependencies (Workflow 05):**
```r
library(gt)         # GT table formatting
library(scales)     # Number/percent formatting
```

**Visualization dependencies (Workflow 06):**
```r
library(ggplot2)    # Already in tidyverse, but explicit
library(viridis)    # Color scales (optional)
library(svglite)    # SVG export (optional)
```

---

## 12. STYLE STANDARDS

### 12.1 Spacing and Indentation

**Use 2 spaces for indentation:**
```r
# ✅ GOOD
if (condition) {
  do_something()
}

# ❌ BAD: 4 spaces
if (condition) {
    do_something()
}

# ❌ BAD: Tabs
if (condition) {
	do_something()
}
```

**Spaces around operators:**
```r
# ✅ GOOD
x <- 1 + 2
result <- df %>% filter(value > 0)

# ❌ BAD
x<-1+2
result<-df%>%filter(value>0)
```

### 12.2 Line Length

**Keep lines under 80 characters when possible:**
```r
# ✅ GOOD: Readable, fits on screen
result <- df %>%
  filter(detector_id %in% active_detectors) %>%
  summarise(total = sum(calls, na.rm = TRUE))

# ❌ BAD: Too long
result <- df %>% filter(detector_id %in% active_detectors) %>% summarise(total = sum(calls, na.rm = TRUE))
```

### 12.3 Piping Style

**Use %>% for clarity:**
```r
# ✅ GOOD: One operation per line
result <- raw_data %>%
  filter(!is.na(detector_id)) %>%
  mutate(date = ymd(date)) %>%
  group_by(detector_id, date) %>%
  summarise(total_calls = n(), .groups = "drop")

# ❌ BAD: Everything on one line
result <- raw_data %>% filter(!is.na(detector_id)) %>% mutate(date = ymd(date)) %>% group_by(detector_id, date) %>% summarise(total_calls = n(), .groups = "drop")
```

---

## 13. YAML CONFIGURATION STANDARDS

### 13.1 study_parameters.yaml Structure

**Required sections:**
```yaml
config_version: 1

study_parameters:
  study_name: "My Bat Study 2025"
  study_start_date: "2025-05-01"
  study_end_date: "2025-08-31"
  timezone: "America/Chicago"

detector_mapping:
  SN001: "North_Ridge"
  SN002: "South_Creek"
  SN003: "East_Forest"

external_data_sources:
  - "data/raw/manual_ids/species_confirmation.csv"
  - "data/raw/weather/weather_log.csv"

processing_options:
  use_alternate_ids: true
  filter_low_quality: false
```

### 13.2 YAML Best Practices

**RULES:**
- ✅ Use consistent indentation (2 spaces)
- ✅ Quote strings with spaces
- ✅ Use lowercase for keys
- ✅ Keep structure flat (avoid deep nesting)
- ✅ Comment complex sections
- ❌ NEVER use tabs
- ❌ NEVER hard-code paths (use relative)

---

## 14. COLLABORATION STANDARDS

### 14.1 Code Review Checklist

Before merging code, verify:

- [ ] All functions have complete Roxygen2 documentation
- [ ] No hardcoded paths anywhere
- [ ] All error messages are helpful and actionable
- [ ] Tests exist for new functions
- [ ] CHANGELOG updated
- [ ] No commented-out code
- [ ] Consistent style (2 spaces, naming conventions)
- [ ] Git commit messages follow standards

### 14.2 Communication

**When asking for help:**
1. Describe what you expected to happen
2. Describe what actually happened
3. Include minimal reproducible example
4. Include error message (complete, not truncated)
5. List what you've already tried

**When providing help:**
1. Ask clarifying questions first
2. Provide working examples
3. Explain WHY, not just WHAT
4. Link to relevant documentation
5. Be patient and encouraging

---

## 15. PACKAGE DEPENDENCY STANDARDS

### 15.1 Required Packages

**Core packages:**
```r
# Data manipulation (always required)
library(tidyverse)   # Includes dplyr, tidyr, ggplot2, readr, etc.
library(lubridate)   # Date/time manipulation
library(hms)         # Time parsing
library(yaml)        # YAML file handling
library(here)        # Path management

# Summary Statistics (Workflow 05)
library(gt)          # GT table formatting
library(scales)      # Number/percent formatting

# Visualization (Workflow 06)
library(viridis)     # Color scales (optional)
library(svglite)     # SVG export (optional)
```

### 15.2 Package Version Management

**Document package versions:**
```r
# In README or setup script
# Tested with:
# - R version 4.3.0
# - tidyverse 2.0.0
# - lubridate 1.9.2
# - here 1.0.1
```

---

## 16. NAMING CONVENTIONS

### 16.1 Function Naming

**Pattern: verb_noun() or verb_noun_context()**

```r
# ✅ GOOD: Action-oriented, clear purpose
load_raw_data()
calculate_recording_hours()
validate_study_config()
plot_species_composition()
gt_detector_summary()

# ❌ BAD: Vague or noun-only
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

### 16.2 File Naming

**Plot module file naming:**
```r
# Pattern: plot_[category].R
plot_quality.R    # Recording quality plots
plot_detector.R   # Detector activity plots
plot_species.R    # Species composition plots
plot_temporal.R   # Temporal pattern plots
plot_helpers.R    # Shared utilities
```

### 16.3 Consistent Terminology

**Use these terms consistently:**
- `detector` (not sensor, unit, device)
- `auto_id` (not species, species_code, id)
- `calls_per_night` (not cpn, nightly_calls)
- `recording_hours` (not hours, duration)

---

## 17. CHECKLISTS

### 17.1 Before Adding a New Function

- [ ] Function name is clear and descriptive (verb_noun pattern)
- [ ] Complete Roxygen2 documentation (description, params, return, contract)
- [ ] Input validation at function entry
- [ ] Helpful error messages with context
- [ ] Function does ONE thing well (< 50 lines)
- [ ] No hardcoded values (use parameters)
- [ ] No global variables used
- [ ] Added to appropriate module file
- [ ] Module header updated with new function

### 17.2 Before Adding a Plot Function

- [ ] Function has complete Roxygen2 header with CONTRACT/DOES NOT
- [ ] Uses `validate_plot_input()` for input validation
- [ ] Uses `theme_kpro()` for consistent styling
- [ ] Uses `kpro_palette_*()` or `kpro_status_colors()` for colors
- [ ] Returns ggplot object (doesn't print)
- [ ] Documents whether input is `calls_per_night_final` or `kpro_master`
- [ ] Added to appropriate `plot_*.R` file
- [ ] Added to Workflow 06 in correct stage
- [ ] Function file header updated with new function
- [ ] Total plot count updated in Workflow 06 header

### 17.3 Before Adding a GT Table Function

- [ ] Function has complete Roxygen2 header
- [ ] Uses consistent GT formatting patterns
- [ ] Returns GT object (not printed)
- [ ] Handles empty data gracefully
- [ ] Added to `tables.R`
- [ ] Added to Workflow 05 in correct stage
- [ ] Function file header updated

### 17.4 Before Modifying a Workflow

- [ ] Header documentation updated (stages, outputs, plot inventory)
- [ ] CHANGELOG entry added with date
- [ ] Stage numbers still sequential
- [ ] All message() calls use consistent formatting
- [ ] Log entries added for new operations
- [ ] Tested end-to-end with sample data

### 17.5 Before Committing Code

- [ ] Code follows style guide (2 spaces, snake_case)
- [ ] No commented-out code
- [ ] No debugging print() statements
- [ ] All file paths use here::here()
- [ ] Error messages are helpful
- [ ] Git commit message follows standards
- [ ] No sensitive data or credentials

---

## 18. ENFORCEMENT

### 18.1 How to Use This Document

**For new code:**
1. Reference this document before writing
2. Use templates and examples provided
3. Self-review against checklists
4. Get peer review if collaborating

**For existing code:**
1. Audit against standards
2. Prioritize critical violations (hardcoded paths, missing docs)
3. Refactor incrementally
4. Update this document if standards evolve

### 18.2 Updating This Document

**When to update:**
- New patterns emerge that should be standardized
- Common mistakes identified
- Best practices evolve
- New tools/packages adopted

**How to update:**
- Propose changes via issue/PR
- Discuss with team (or self-document reasoning)
- Update version number
- Communicate changes
- Archive old versions

---

## APPENDIX A: QUICK REFERENCE

### Good vs Bad Examples

**Paths:**
```r
# ❌ BAD:
read.csv("C:/Users/John/data/file.csv")

# ✅ GOOD:
read.csv(here::here("data", "file.csv"))
```

**Error Messages:**
```r
# ❌ BAD:
stop("Error")

# ✅ GOOD:
stop(sprintf("Required column '%s' not found. Did you run workflow 02 first?", col_name))
```

**Function Design:**
```r
# ❌ BAD:
f <- function(x) { x * 2 }

# ✅ GOOD:
double_value <- function(x) {
  if (!is.numeric(x)) stop("x must be numeric")
  x * 2
}
```

**Plot Functions:**
```r
# ❌ BAD:
plot_example <- function(df) {
  print(ggplot(df, aes(x, y)) + geom_point())
}

# ✅ GOOD:
plot_example <- function(df) {
  validate_plot_input(df, required_cols = c("x", "y"))
  ggplot(df, aes(x = x, y = y)) +
    geom_point() +
    theme_kpro()
}
```

**GT Tables:**
```r
# ❌ BAD:
gt_summary <- function(df) {
  df %>% gt() %>% print()
}

# ✅ GOOD:
gt_summary <- function(df, title = "Summary") {
  if (nrow(df) == 0) return(NULL)
  
  df %>%
    gt() %>%
    tab_header(title = title) %>%
    fmt_number(columns = where(is.numeric), decimals = 1)
}
```

**Validation:**
```r
# ❌ BAD:
df <- read_csv(file)

# ✅ GOOD:
if (!file.exists(file)) {
  stop(sprintf("File not found: %s\n  Run Workflow 04 first.", file))
}
df <- read_csv(file)
if (nrow(df) == 0) stop("Loaded data is empty")
```

**Documentation:**
```r
# ❌ BAD:
# Function to process data
process <- function(d) { ... }

# ✅ GOOD:
#' Remove Duplicate Detections
#'
#' @description
#' Identifies and removes duplicate detection events based on
#' Detector, DateTime, and auto_id combination.
#'
#' @param df Data frame with detection events
#'
#' @return Data frame with duplicates removed
#'
#' @section CONTRACT:
#' - Keeps first occurrence of each unique detection
#' - Logs number of duplicates removed
#' - Does not modify input data frame
#'
#' @export
remove_duplicates <- function(df) { ... }
```

---

## APPENDIX B: TEMPLATES

### Function Template

```r
#' [Function Title]
#'
#' @description
#' [Detailed description]
#'
#' @param param_name [Type]. [Description]
#'
#' @return [Description of return value]
#'
#' @details
#' [Additional context]
#'
#' @section CONTRACT:
#' - [Guarantee 1]
#' - [Guarantee 2]
#'
#' @section DOES NOT:
#' - [Exclusion 1]
#' - [Exclusion 2]
#'
#' @examples
#' \dontrun{
#' # [Example code]
#' }
#'
#' @export
function_name <- function(param1, param2 = default) {
  
  # -------------------------
  # Input validation
  # -------------------------
  if (!is.data.frame(param1)) {
    stop("param1 must be a data frame")
  }
  
  # -------------------------
  # Processing
  # -------------------------
  result <- param1 %>%
    mutate(...)
  
  # -------------------------
  # Return
  # -------------------------
  result
}
```

### Plot Function Template

```r
#' [Plot Title]
#'
#' @description
#' [What this plot shows and when to use it]
#'
#' @param calls_per_night Data frame. CallsPerNight final from Workflow 04.
#'   Required columns: [list columns]
#'
#' @return ggplot2 object
#'
#' @section CONTRACT:
#' - Returns ggplot object (never prints)
#' - Uses theme_kpro() for consistent styling
#' - Uses kpro_palette_*() for colors
#' - Handles empty data gracefully
#'
#' @section DOES NOT:
#' - Modify input data
#' - Save to disk
#' - Print to console
#'
#' @section DATA SOURCE:
#' Input from: Workflow 04 (04_finalize_cpn.R)
#'
#' @examples
#' \dontrun{
#' p <- plot_example(calls_per_night_final)
#' ggsave("output.png", p, width = 10, height = 6)
#' }
#'
#' @export
plot_example <- function(calls_per_night) {
  
  # -------------------------
  # Input validation
  # -------------------------
  validate_plot_input(
    calls_per_night,
    required_cols = c("Detector", "Night", "TotalCalls"),
    data_name = "calls_per_night"
  )
  
  # -------------------------
  # Data preparation
  # -------------------------
  plot_data <- calls_per_night %>%
    group_by(Detector) %>%
    summarise(total = sum(TotalCalls, na.rm = TRUE))
  
  # -------------------------
  # Build plot
  # -------------------------
  ggplot(plot_data, aes(x = reorder(Detector, total), y = total)) +
    geom_col(fill = kpro_palette_cat(1)) +
    coord_flip() +
    labs(
      title = "Plot Title",
      subtitle = "What this shows",
      x = NULL,
      y = "Total Calls"
    ) +
    theme_kpro()
}
```

### GT Table Template

```r
#' [Table Title]
#'
#' @description
#' [What this table shows]
#'
#' @param data Data frame with summary data.
#' @param title Character. Table title.
#'
#' @return gt object
#'
#' @section CONTRACT:
#' - Returns gt object (never prints)
#' - Uses consistent formatting
#' - Handles empty data gracefully (returns NULL with warning)
#'
#' @section DOES NOT:
#' - Modify input data
#' - Save to disk
#'
#' @export
gt_example <- function(data, title = "Example Table") {
  
  # -------------------------
  # Input validation
  # -------------------------
  if (!is.data.frame(data)) {
    stop("data must be a data frame")
  }
  
  if (nrow(data) == 0) {
    warning("Empty data provided to gt_example")
    return(NULL)
  }
  
  # -------------------------
  # Build table
  # -------------------------
  data %>%
    gt() %>%
    tab_header(
      title = title,
      subtitle = "Generated by KPro Pipeline"
    ) %>%
    fmt_number(
      columns = where(is.numeric),
      decimals = 1,
      use_seps = TRUE
    ) %>%
    cols_align(align = "center") %>%
    tab_options(
      table.font.size = px(12),
      heading.title.font.size = px(16)
    )
}
```

### Function File Header Template

```r
# =============================================================================
# MODULE: [filename].R — [Module Description]
# =============================================================================
# PURPOSE
# -------
# [One paragraph description]
#
# DEPENDENCIES
# ------------
# R Packages:
#   - [package]: [what for]
#
# Internal Dependencies:
#   - [file.R]: [functions used]
#
# FUNCTIONS PROVIDED
# ------------------
# [Category 1] (N):
#   - function_1(): description
#   - function_2(): description
#
# [Category 2] (N):
#   - function_3(): description
#
# USAGE
# -----
# source("R/functions/[path]/[filename].R")
# result <- function_1(data)
#
# CHANGELOG
# ---------
# YYYY-MM-DD: [Description]
# =============================================================================
```

### Workflow Stage Template

```r
# ==============================================================================
# STAGE X.Y: [STAGE NAME]
# ==============================================================================

message("\n┌────────────────────────────────────────────────────────────────┐")
message("│          STAGE X.Y: [Stage Name]                               │")
message("└────────────────────────────────────────────────────────────────┘\n")

message("[Description of what this stage does]...")

# -------------------------
# Sub-step 1
# -------------------------

# Code here

message("✓ [Sub-step 1 complete]")

# -------------------------
# Sub-step 2
# -------------------------

# Code here

message("✓ [Sub-step 2 complete]")

log_message("[Stage X.Y] [Summary of what happened]")
```

---

## APPENDIX C: WORKFLOW INVENTORY

### Pipeline Overview

```
Raw CSVs → 01 → 02 → 03 → [User Edit] → 04 → 05 → 06 → 07 → Report
           ↓    ↓    ↓                   ↓    ↓    ↓
         intro master template         final stats plots
```

### Workflow Details

**01_ingest_raw_data.R**
- Purpose: Load raw KPro CSVs, apply intro standardization
- Inputs: `data/raw/*.csv`, `inst/config/study_parameters.yaml`
- Outputs: `outputs/checkpoints/01_intro_standardized_YYYYMMDD_HHMMSS.csv`
- Key functions: `load_local_raw_data()`, `apply_intro_standardization()`

**02_standardize.R**
- Purpose: Detect schemas, transform to unified master format
- Inputs: Output from Workflow 01 (in memory or checkpoint)
- Outputs: `outputs/checkpoints/02_kpro_master_YYYYMMDD_HHMMSS.csv`
- Key functions: `detect_row_schema()`, `transform_to_unified_schema()`

**03_generate_cpn_template.R**
- Purpose: Generate CallsPerNight template, optional manual ID import, species unification
- Inputs: `kpro_master` from Workflow 02
- Outputs: `outputs/03_CallsPerNight_Template_YYYYMMDD_HHMMSS.csv`
- Key functions: `generate_calls_per_night_template()`, `apply_schedule()`
- User action required: Edit template in Excel before Workflow 04

**04_finalize_cpn.R**
- Purpose: Process user-edited template, calculate Status/CallsPerHour
- Inputs: User-edited template, recording hours data
- Outputs: `results/csv/CallsPerNight_final_vX.csv`
- Key functions: `calculate_recording_hours()`, `validate_cpn_data()`

**05_summary_stats.R**
- Purpose: Generate GT summary tables and statistics
- Inputs: `calls_per_night_final` from Workflow 04
- Outputs: `results/tables/*.html`, `results/csv/summary_*.csv`
- Key functions: `gt_study_overview()`, `gt_detector_summary()`

**06_generate_plots.R**
- Purpose: Generate exploratory visualizations (26 plots)
- Inputs: `calls_per_night_final`, `kpro_master`
- Outputs: `results/figures/png/*/*.png`, `results/rds/plot_objects_YYYYMMDD.rds`
- Key functions: All `plot_*()` functions from plot modules

**07_generate_report.R**
- Purpose: Generate final Quarto report
- Inputs: All results from Workflows 05-06
- Outputs: `report.html` or `report.pdf`

---

## APPENDIX D: FUNCTION INVENTORY

### Core Module (`R/functions/core/`)

**config.R** (5 functions)
- `build_study_config()`: Create study configuration object
- `validate_study_config()`: Validate configuration structure
- `load_study_parameters()`: Load parameters from YAML
- `save_study_parameters()`: Save parameters to YAML
- `ensure_study_parameters()`: Interactive parameter setup

**utilities.R** (Multiple functions)
- `log_message()`: Write to log file
- `is_unidentifiable()`: Check if species ID is NoID/Unknown
- `format_number()`: Format numbers with commas
- `format_pct()`: Format percentages
- `safe_read_csv()`: Safe CSV reading with error handling
- `find_most_recent_file()`: Locate latest checkpoint
- `load_or_checkpoint()`: Load from memory or file
- `make_output_path()`: Generate timestamped paths
- `make_versioned_path()`: Generate versioned paths

**load_all.R**
- Sources all function files in correct order

### Ingestion Module (`R/functions/ingestion/`)

**ingestion.R** (3 functions)
- `apply_intro_standardization()`: Initial column standardization
- `load_local_raw_data()`: Load CSVs from local directory
- `load_external_raw_data()`: Load CSVs from external sources

**schema_detection.R** (Multiple functions)
- `detect_row_schema()`: Identify KPro schema version
- `transform_to_unified_schema()`: Convert any schema to unified
- `transform_v1_to_unified()`: Schema v1 specific transformation
- `transform_v2_to_unified()`: Schema v2 specific transformation
- `transform_v3_to_unified()`: Schema v3 specific transformation

### Standardization Module (`R/functions/standardization/`)

**standardization.R** (Multiple functions)
- `standardize_column_names()`: Normalize column names
- `convert_species_codes()`: Convert between code formats
- `unify_species_column()`: Create unified species field
- `apply_detector_mapping()`: Map detector IDs to names

**datetime_conversion.R** (Multiple functions)
- `convert_datetime_to_local()`: Convert UTC to local timezone
- `parse_datetime_safe()`: Safe datetime parsing
- `parse_date_safe()`: Safe date parsing
- `parse_time_safe()`: Safe time parsing

### Validation Module (`R/functions/validation/`)

**validation.R** (Multiple functions)
- `validate_cpn_data()`: Validate CallsPerNight data
- `validate_master_data()`: Validate master file
- `assert_data_frame()`: Assert object is data frame
- `assert_columns_exist()`: Assert required columns exist
- `assert_not_empty()`: Assert data frame has rows
- `enforce_unified_schema()`: Ensure unified schema compliance
- `check_column_completeness()`: Check for NA values
- `validate_calls_per_night()`: Logical consistency checks

### Analysis Module (`R/functions/analysis/`)

**callspernight.R** (4 functions)
- `generate_calls_per_night_template()`: Generate CPN template
- `apply_schedule()`: Apply recording schedule
- `calculate_recording_hours()`: Calculate hours from times
- `save_callspernight_with_version()`: Save with version number

**summarization.R** (Multiple functions)
- `summarize_by_detector()`: Detector-level statistics
- `summarize_by_species()`: Species-level statistics
- `summarize_overall()`: Study-wide statistics

### Output Module (`R/functions/output/`)

**plot_helpers.R** (6 functions)
- `theme_kpro()`: Consistent ggplot theme
- `kpro_palette_cat()`: Categorical color palette
- `kpro_palette_seq()`: Sequential color palette
- `kpro_status_colors()`: Pass/Partial/Fail colors
- `validate_plot_input()`: Validate plot input data
- `format_number()`: Format numbers for display

**plot_quality.R** (8 functions)
- `plot_recording_status_summary()`: Stacked bar by detector
- `plot_recording_status_percent()`: 100% stacked bar
- `plot_recording_status_overall()`: Donut chart
- `plot_effort_by_detector()`: Total hours by detector
- `plot_nights_by_detector()`: Night count by detector
- `plot_data_completeness_calendar()`: Calendar heatmap
- `plot_missing_nights()`: Gap analysis
- `plot_recording_effort_heatmap()`: Date × Detector heatmap

**plot_detector.R** (7 functions)
- `plot_total_calls_by_detector()`: Bar chart from master
- `plot_detector_activity_caterpillar()`: Mean ± CI
- `plot_detector_boxplots()`: Distribution boxplots
- `plot_activity_with_without_outliers()`: Side-by-side comparison
- `plot_synchrony()`: Multi-line time series
- `plot_correlation_heatmap()`: Correlation matrix
- `plot_detector_rank_over_time()`: Bump chart

**plot_species.R** (5 functions)
- `plot_species_composition_bar()`: Horizontal bar chart
- `plot_species_by_detector_heatmap()`: Species × Detector matrix
- `plot_species_accumulation_curve()`: Discovery curve
- `plot_species_hourly_profile()`: Activity by hour
- `plot_noid_proportion()`: NoID analysis

**plot_temporal.R** (6 functions)
- `plot_activity_over_time()`: Line with smoothing
- `plot_cumulative_calls_over_time()`: Cumulative sum
- `plot_hourly_activity_profile()`: Bar by hour
- `plot_callsperhour_distribution()`: Histogram/density
- `plot_weekly_activity()`: Day-of-week patterns
- `plot_activity_by_month()`: Monthly aggregation

**tables.R** (Multiple functions)
- `gt_study_overview()`: Study overview table
- `gt_detector_summary()`: Detector summary table
- `gt_species_composition()`: Species composition table

### Total: ~60+ functions

---

## APPENDIX E: PLOT INVENTORY

### Summary
- **Total plots:** 26
- **Quality:** 8 plots
- **Detector:** 7 plots
- **Species:** 5 plots (conditional on `species` column)
- **Temporal:** 6 plots

### Quality Plots (8) — `plot_quality.R`

| Function | Input | Description |
|----------|-------|-------------|
| `plot_recording_status_summary` | CPN | Stacked bar of Pass/Partial/Fail by detector |
| `plot_recording_status_percent` | CPN | 100% stacked bar of status proportions |
| `plot_recording_status_overall` | CPN | Donut chart of overall status distribution |
| `plot_effort_by_detector` | CPN | Total recording hours by detector |
| `plot_nights_by_detector` | CPN | Night count by detector |
| `plot_data_completeness_calendar` | CPN | Calendar heatmap showing data presence |
| `plot_missing_nights` | CPN | Gap analysis visualization |
| `plot_recording_effort_heatmap` | CPN | Date × Detector hours heatmap |

### Detector Plots (7) — `plot_detector.R`

| Function | Input | Description |
|----------|-------|-------------|
| `plot_total_calls_by_detector` | Master | Bar chart of total calls |
| `plot_detector_activity_caterpillar` | CPN | Mean ± CI by detector |
| `plot_detector_boxplots` | CPN | Distribution of calls per detector |
| `plot_activity_with_without_outliers` | CPN | Side-by-side outlier comparison |
| `plot_synchrony` | CPN | Multi-line time series |
| `plot_correlation_heatmap` | CPN | Detector correlation matrix |
| `plot_detector_rank_over_time` | CPN | Bump chart of rankings |

### Species Plots (5) — `plot_species.R`

| Function | Input | Description | Condition |
|----------|-------|-------------|-----------|
| `plot_species_composition_bar` | Master | Horizontal bar of species counts | Requires `species` column |
| `plot_species_by_detector_heatmap` | Master | Species × Detector matrix | Requires `species` column |
| `plot_species_accumulation_curve` | Master | Species discovery over time | Requires `species` column |
| `plot_species_hourly_profile` | Master | Activity by hour | Requires `species` + `Hour` |
| `plot_noid_proportion` | Master | NoID analysis by detector | Requires `species` column |

### Temporal Plots (6) — `plot_temporal.R`

| Function | Input | Description | Condition |
|----------|-------|-------------|-----------|
| `plot_activity_over_time` | CPN | Line plot with smoothing | — |
| `plot_cumulative_calls_over_time` | CPN | Cumulative sum plot | — |
| `plot_hourly_activity_profile` | Master | Bar chart by hour | Requires `Hour` |
| `plot_callsperhour_distribution` | CPN | Histogram/density of CPH | — |
| `plot_weekly_activity` | CPN | Day-of-week patterns | — |
| `plot_activity_by_month` | CPN | Monthly aggregation | — |

### Input Data Key
- **CPN:** `calls_per_night_final` from Workflow 04
- **Master:** `kpro_master` from Workflow 02/03

---

## VERSION HISTORY

**v2.1 (2026-01-09)**
- Added Section 7.5: Workflow 07 Report Standards
- Added `reports/` directory for Quarto templates
- Added `results/reports/` directory for rendered HTML output
- Comprehensive standards for auto-generated Quarto reports including:
    - Parameterized rendering patterns
    - Programmatic plot iteration with `purrr::iwalk()`
    - Caption generation standards
    - Conditional section rendering
    - Reproducibility footer requirements
    - Report section inventory
- Updated directory structure diagram

**v2.0 (2026-01-08)**
- Major update reflecting complete pipeline (Workflows 01-07)
- Added hierarchical directory structure with `results/` folder
- Added Layer Responsibilities section (1.3) defining workflow architectural guarantees
- Added Function Script Headers section (2.4) with module header template
- Expanded Quarto Integration section (7) with quiet mode, structured returns, RDS patterns
- Added testing priority table and test file naming conventions
- Updated package dependencies for Workflows 05-06 (gt, scales, viridis)
- Added checklists for plots, tables, and workflow modifications
- Added Appendix C: Workflow Inventory with pipeline flowchart
- Added Appendix D: Function Inventory (~60+ functions by module)
- Added Appendix E: Plot Inventory (26 plots categorized)
- Added templates for plot functions, GT tables, and function file headers
- Updated naming conventions for plot/table functions and plot module files
- Expanded validation checkpoints with workflow-specific guidance
- Added Quarto integration rules table
- Added error handling rules table
- Enhanced documentation with DATA SOURCE sections for plot functions

**v1.0 (2025-12-26)**
- Initial comprehensive standards document
- Covered Workflows 01-03
- Established core philosophy and patterns
- Included collaboration standards
- Ready for Claude Project Knowledge integration

---

## ACKNOWLEDGMENTS

This standards document synthesizes best practices from:
- Tidyverse style guide
- Google R style guide
- rOpenSci development guide
- Scientific reproducibility literature
- Bat acoustic analysis domain expertise
- Real-world pipeline development experience

---

**END OF CODING STANDARDS v2.1**
