# ==============================================================================
# APPENDICES
# ==============================================================================
# VERSION: 2.4
# LAST UPDATED: 2026-02-05
# PURPOSE: Templates, inventories, checklists, and quick reference
# ==============================================================================

## 1. CHECKLISTS

### 1.1 Before Adding a New Function

- [ ] Function name is clear and descriptive (verb_noun pattern)
- [ ] Complete Roxygen2 documentation (description, params, return, contract)
- [ ] Input validation at function entry using centralized assertions
- [ ] Helpful error messages with context
- [ ] Function does ONE thing well (< 50 lines)
- [ ] No hardcoded values (use parameters)
- [ ] No global variables used
- [ ] Added to appropriate module file
- [ ] Module header updated with new function
- [ ] **Verbose parameter added** (if function may be called from Shiny/orchestrating functions)

### 1.2 Before Adding a Plot Function

- [ ] Function has complete Roxygen2 header with CONTRACT/DOES NOT
- [ ] Uses `validate_plot_input()` for input validation
- [ ] Uses `theme_kpro()` for consistent styling
- [ ] Uses `kpro_palette_*()` or `kpro_status_colors()` for colors
- [ ] Returns ggplot object (doesn't print)
- [ ] Documents whether input is `calls_per_night_final` or `kpro_master`
- [ ] Added to appropriate `plot_*.R` file
- [ ] Added to plot stage in correct category
- [ ] Function file header updated with new function
- [ ] Total plot count updated in inventory
- [ ] **Verbose parameter added** with gated progress messages

### 1.3 Before Adding a GT Table Function

- [ ] Function has complete Roxygen2 header
- [ ] Uses consistent GT formatting patterns
- [ ] Returns GT object (not printed)
- [ ] Handles empty data gracefully
- [ ] Added to `tables.R`
- [ ] Added to summary stage in correct category
- [ ] Function file header updated
- [ ] **Verbose parameter added** for progress messages

### 1.4 Before Modifying a Chunk/Workflow

- [ ] Header documentation updated (stages, outputs, plot inventory)
- [ ] CHANGELOG entry added with date
- [ ] Stage numbers still sequential
- [ ] All message() calls gated by `if (verbose)` (for orchestrating functions)
- [ ] All message() calls use consistent formatting (or `print_stage_header()`)
- [ ] Log entries added for new operations (never gated)
- [ ] Validation events logged (if applicable)
- [ ] Artifacts registered (if applicable)
- [ ] Tested end-to-end with sample data
- [ ] **Structured return updated** (for orchestrating functions)

### 1.5 Before Committing Code

- [ ] Code follows style guide (2 spaces, snake_case)
- [ ] No commented-out code
- [ ] No debugging print() statements
- [ ] All file paths use here::here()
- [ ] Error messages are helpful
- [ ] Git commit message follows standards
- [ ] No sensitive data or credentials
- [ ] **Centralized assertions used** instead of custom validation
- [ ] **Verbose parameter gating correct** (message gated, warning/stop never gated)

### 1.6 Before Creating a Release Bundle

- [ ] All chunks (1-3) or workflows (01-06) completed successfully
- [ ] Artifact registry up to date
- [ ] Validation reports generated for all chunks/workflows
- [ ] CPN final passes validation
- [ ] Manifest metadata complete
- [ ] All hashes computed and recorded
- [ ] Data filters configuration documented in manifest

### 1.7 Before Adding an Orchestrating Function

- [ ] Header follows orchestrating function template (PIPELINE POSITION, DECISION POINTS, etc.)
- [ ] Function defaults to `verbose = FALSE`
- [ ] All `message()` calls gated with `if (verbose)`
- [ ] `warning()` and `stop()` calls NEVER gated
- [ ] `log_message()` calls NEVER gated
- [ ] Uses centralized `assert_*` functions for validation
- [ ] Returns structured list with: data, metadata, artifact_id, paths
- [ ] Registers artifacts at completion
- [ ] Renders validation HTML at completion
- [ ] File logging at start and end of chunk

---

## 2. QUICK REFERENCE

### 2.1 Good vs Bad Examples

**Paths:**
```r
# [X] BAD:
read.csv("C:/Users/John/data/file.csv")

# [OK] GOOD:
read.csv(here::here("data", "file.csv"))
```

**Error Messages:**
```r
# [X] BAD:
stop("Error")

# [OK] GOOD:
stop(sprintf("Required column '%s' not found. Did you run Chunk 1 first?", col_name))
```

**Function Design:**
```r
# [X] BAD:
f <- function(x) { x * 2 }

# [OK] GOOD:
double_value <- function(x, verbose = FALSE) {
  assert_numeric(x, "x")
  if (verbose) message("  Doubling value...")
  x * 2
}
```

**Input Validation:**
```r
# [X] BAD: Custom validation
if (!is.data.frame(df)) stop("df must be a data frame")
if (nrow(df) == 0) stop("df is empty")

# [OK] GOOD: Centralized assertions
assert_data_frame(df, "df")
assert_not_empty(df, "df")
assert_columns_exist(df, c("Detector", "Night"), source_hint = "Run Chunk 1 first")
```

**Plot Functions:**
```r
# [X] BAD:
plot_example <- function(df) {
  print(ggplot(df, aes(x, y)) + geom_point())
}

# [OK] GOOD:
plot_example <- function(df, verbose = FALSE) {
  validate_plot_input(df, required_cols = c("x", "y"))
  if (verbose) message("  Creating plot...")
  ggplot(df, aes(x = x, y = y)) +
    geom_point() +
    theme_kpro()
}
```

**GT Tables:**
```r
# [X] BAD:
gt_summary <- function(df) {
  df %>% gt() %>% print()
}

# [OK] GOOD:
gt_summary <- function(df, title = "Summary", verbose = FALSE) {
  assert_not_empty(df, "df")
  if (verbose) message("  Creating GT table...")
  
  df %>%
    gt() %>%
    tab_header(title = title) %>%
    fmt_number(columns = where(is.numeric), decimals = 1)
}
```

**Validation:**
```r
# [X] BAD:
df <- read_csv(file)

# [OK] GOOD:
assert_file_exists(file, hint = "Run Chunk 1 first")
df <- read_csv(file)
assert_not_empty(df, "loaded data")
```

**Documentation:**
```r
# [X] BAD:
# Function to process data
process <- function(d) { ... }

# [OK] GOOD:
#' Remove Duplicate Detections
#'
#' @description
#' Identifies and removes duplicate detection events based on
#' Detector, DateTime, and auto_id combination.
#'
#' @param df Data frame with detection events
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return Data frame with duplicates removed
#'
#' @section CONTRACT:
#' - Keeps first occurrence of each unique detection
#' - Logs number of duplicates removed
#' - Does not modify input data frame
#'
#' @export
remove_duplicates <- function(df, verbose = FALSE) { ... }
```

**Verbose Gating:**
```r
# [X] BAD: Inconsistent gating
my_function <- function(df, verbose = FALSE) {
  message("Starting...")           # Not gated!
  if (verbose) warning("Issue")    # Warning gated (wrong!)
  if (verbose) stop("Error")       # Error gated (wrong!)
}

# [OK] GOOD: Correct gating
my_function <- function(df, verbose = FALSE) {
  if (verbose) message("Starting...")  # Progress gated
  warning("Issue found")               # Warning never gated
  stop("Critical error")               # Error never gated
  log_message("Operation logged")      # File log never gated
}
```

**Orchestrating Function Returns:**
```r
# [X] BAD: Just returns data
run_chunk <- function(verbose = FALSE) {
  df <- process_data()
  df
}

# [OK] GOOD: Returns structured list
run_chunk <- function(verbose = FALSE) {
  df <- process_data()
  
  list(
    data = df,
    metadata = list(n_rows = nrow(df), filters_applied = filters),
    artifact_id = artifact_id,
    checkpoint_path = checkpoint_path,
    validation_html_path = validation_html_path
  )
}
```

---

## 3. TEMPLATES

### 3.1 Function Template

```r
#' [Function Title]
#'
#' @description
#' [Detailed description]
#'
#' @param param_name [Type]. [Description]
#' @param verbose Logical. Print progress messages. Default: FALSE.
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
function_name <- function(param1, param2 = default, verbose = FALSE) {
  
  # -------------------------
  # Input validation
  # -------------------------
  assert_data_frame(param1, "param1")
  assert_not_empty(param1, "param1")
  
  # -------------------------
  # Processing
  # -------------------------
  if (verbose) message("  Processing data...")
  
  result <- param1 %>%
    mutate(...)
  
  # -------------------------
  # Return
  # -------------------------
  if (verbose) message("  [OK] Processing complete")
  result
}
```

### 3.2 Plot Function Template

```r
#' [Plot Title]
#'
#' @description
#' [What this plot shows and when to use it]
#'
#' @param calls_per_night Data frame. CallsPerNight final from Chunk 3.
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return ggplot object
#'
#' @details
#' [Additional context about the visualization]
#'
#' @section DATA SOURCE:
#' - Input: `calls_per_night_final` from Chunk 3 / Workflow 04
#' - Required columns: [list columns]
#'
#' @section CONTRACT:
#' - Returns ggplot object (never prints)
#' - Uses theme_kpro() for consistent styling
#' - Uses kpro_palette_*() for colors
#'
#' @section DOES NOT:
#' - Print the plot (caller decides)
#' - Modify input data
#' - Save to file
#'
#' @examples
#' \dontrun{
#' p <- plot_example(calls_per_night_final)
#' ggsave("plot.png", p, width = 10, height = 6)
#' }
#'
#' @export
plot_example <- function(calls_per_night, verbose = FALSE) {
  
  # Validation
  validate_plot_input(calls_per_night, required_cols = c("Detector", "Night", "CallsPerNight"))
  
  if (verbose) message("  Creating example plot...")
  
  # Build plot
  p <- ggplot(calls_per_night, aes(x = Night, y = CallsPerNight)) +
    geom_line() +
    theme_kpro() +
    labs(
      title = "Example Plot Title",
      x = "Night",
      y = "Calls Per Night"
    )
  
  if (verbose) message("  [OK] Plot created")
  
  # Return (never print)
  p
}
```

### 3.3 GT Table Template

```r
#' [Table Title]
#'
#' @description
#' [What this table shows]
#'
#' @param data Data frame. [Source description]
#' @param title Character. Table title. Default: "[Default Title]"
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return gt object
#'
#' @section CONTRACT:
#' - Returns gt object (never prints)
#' - Handles empty data gracefully (returns NULL)
#' - Formats numbers consistently
#'
#' @export
gt_example <- function(data, title = "Example Table", verbose = FALSE) {
  
  # Handle empty data
  if (nrow(data) == 0) {
    if (verbose) message("  [!] No data for table")
    return(NULL)
  }
  
  if (verbose) message("  Creating GT table...")
  
  # Build table
  tbl <- data %>%
    gt() %>%
    tab_header(title = title) %>%
    fmt_number(columns = where(is.numeric), decimals = 1) %>%
    cols_label(
      col1 = "Column 1",
      col2 = "Column 2"
    )
  
  if (verbose) message("  [OK] Table created")
  
  tbl
}
```

### 3.4 Orchestrating Function Template

```r
# ==============================================================================
# R/pipeline/run_[chunk_name].R
# ==============================================================================
# PURPOSE
# -------
# [One paragraph description]
#
# PIPELINE POSITION
# -----------------
# Chunk [N] of 3 in the Shiny-driven pipeline:
#   run_ingest_standardize()  -> Raw CSVs to kpro_master
#   run_cpn_template()        -> Generate CPN template
#   run_finalize_to_report()  -> Finalize through report
#
# DECISION POINTS (handled by Shiny app):
#   After Chunk [N]: [What decision the user makes]
#
# PROCESSING STAGES
# -----------------
#   Stage 1: [Stage name]
#   Stage 2: [Stage name]
#   ...
#
# CONTRACT
# --------
# INPUTS:
#   - [Input 1]: [Description]
#
# OUTPUTS:
#   - [Output 1]: [Path pattern]
#
# GUARANTEES:
#   - All paths use here::here()
#   - Silent by default (verbose = FALSE)
#   - No interactive prompts
#   - Returns structured list
#   - Validation HTML always rendered
#
# DOES NOT:
#   - Accept configuration as parameters (reads from YAML)
#   - Modify global environment
#
# CHANGELOG
# ---------
# YYYY-MM-DD: Initial version
# ==============================================================================

#' Run [Chunk Name] Pipeline
#'
#' @description
#' Chunk [N] of the KPro pipeline. [Description]
#'
#' @param verbose Logical. Print progress messages. Default: FALSE.
#'
#' @return Named list containing:
#'   \describe{
#'     \item{data}{Tibble. Primary data output.}
#'     \item{metadata}{List. Processing metadata.}
#'     \item{artifact_id}{Character. Registered artifact identifier.}
#'     \item{checkpoint_path}{Character. Path to checkpoint file.}
#'     \item{validation_html_path}{Character. Path to validation report.}
#'   }
#'
#' @export
run_chunk_name <- function(verbose = FALSE) {
  
  # =========================================================================
  # FILE LOGGING (never gated)
  # =========================================================================
  log_message("=== CHUNK N: Chunk Name - START ===")
  
  # =========================================================================
  # STAGE 1: Load Configuration
  # =========================================================================
  if (verbose) print_stage_header("1", "Load Configuration")
  
  yaml_path <- here::here("inst", "config", "study_parameters.yaml")
  assert_file_exists(yaml_path, hint = "Configure study parameters first")
  
  if (verbose) message("  Loading study parameters...")
  config <- yaml::read_yaml(yaml_path)
  if (verbose) message("  [OK] Configuration loaded")
  
  log_message(sprintf("[Stage 1] Loaded configuration from %s", basename(yaml_path)))
  
  # =========================================================================
  # STAGE 2: [Next Stage]
  # =========================================================================
  if (verbose) print_stage_header("2", "Next Stage")
  
  # ... processing ...
  
  # =========================================================================
  # STAGE N: Register Artifact & Finalize
  # =========================================================================
  if (verbose) print_stage_header("N", "Register Artifact")
  
  # Initialize validation context
  validation_context <- create_validation_context(workflow = "chunk_name")
  
  # Register artifact
  registry <- init_artifact_registry()
  artifact_id <- sprintf("artifact_%s", format(Sys.time(), "%Y%m%d_%H%M%S"))
  
  registry <- register_artifact(
    registry = registry,
    artifact_name = artifact_id,
    artifact_type = "appropriate_type",
    workflow = "chunkN",
    file_path = checkpoint_path,
    metadata = list(
      n_rows = nrow(result_data),
      data_filters_applied = filters_config
    )
  )
  
  log_message(sprintf("[Stage N] Registered artifact: %s", artifact_id))
  
  # Finalize validation report
  validation_html_path <- finalize_validation_report(
    validation_context,
    output_dir = here::here("results", "validation")
  )
  
  # =========================================================================
  # SUMMARY (gated)
  # =========================================================================
  if (verbose) {
    print_workflow_summary(
      workflow = "CHUNK N",
      title = "Chunk Name Complete",
      items = list(
        "Rows processed" = format(nrow(result_data), big.mark = ","),
        "Checkpoint" = basename(checkpoint_path),
        "Validation" = basename(validation_html_path)
      )
    )
  }
  
  # =========================================================================
  # FILE LOGGING (never gated)
  # =========================================================================
  log_message("=== CHUNK N: Chunk Name - COMPLETE ===")
  
  # =========================================================================
  # RETURN STRUCTURED LIST
  # =========================================================================
  list(
    data = result_data,
    metadata = list(
      n_rows = nrow(result_data),
      data_filters_applied = filters_config
    ),
    artifact_id = artifact_id,
    checkpoint_path = checkpoint_path,
    validation_html_path = validation_html_path
  )
}
```

### 3.5 Function File Header Template

```r
# =============================================================================
# MODULE: [filename].R - [Module Description]
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
# result <- function_1(data, verbose = TRUE)
#
# CHANGELOG
# ---------
# YYYY-MM-DD: Added verbose parameter to all functions
# YYYY-MM-DD: Initial version
# =============================================================================
```

---

## 4. WORKFLOW/CHUNK INVENTORY

### 4.1 Pipeline Architecture

**Chunk Model (Shiny-Driven):**
```
run_ingest_standardize()     Chunk 1: Raw CSVs -> kpro_master
         |
         v
    [DECISION: Export for Manual ID?]
         |
         v
run_cpn_template()           Chunk 2: Generate CPN template
         |
         v
    [DECISION: Edit recording hours?]
         |
         v
run_finalize_to_report()     Chunk 3: Finalize -> Stats -> Plots -> Report
         |
         v
    [release_bundle.zip]
```

**Legacy Workflow Model:**
```
01_ingest_raw_data.R         Load and intro-standardize CSVs
         |
         v
02_standardize.R             Schema detection, transformation, master creation
         |
         v
03_generate_cpn_template.R   Generate CallsPerNight template
         |
         v
    [USER EDITS TEMPLATE]
         |
         v
04_finalize_cpn.R            Calculate Status, CallsPerHour
         |
         v
05_summary_stats.R           Generate summary statistics
         |
         v
06_exploratory_plots.R       Generate all plots
         |
         v
07_generate_report.R         Render Quarto report, create release bundle
```

### 4.2 Chunk-to-Workflow Mapping

| Chunk | Function | Equivalent Workflows | Primary Output |
|-------|----------|---------------------|----------------|
| 1 | `run_ingest_standardize()` | WF01 + WF02 | kpro_master |
| 2 | `run_cpn_template()` | WF03 | CPN template pair |
| 3 | `run_finalize_to_report()` | WF04 + WF05 + WF06 + WF07 | Final CPN, report, release |

### 4.3 Decision Points

| After | Decision | Options |
|-------|----------|---------|
| Chunk 1 | Export master for manual ID? | Yes: Export CSV for review / No: Continue |
| Chunk 2 | Edit recording hours in template? | Yes: User edits CSV / No: Use auto-generated |

---

## 5. FUNCTION INVENTORY

### 5.1 Core Module (`R/functions/core/`)

**config.R** (5 functions)
- `load_study_config()`: Load and validate study_parameters.yaml
- `get_config_value()`: Safe config value retrieval with defaults
- `validate_config_structure()`: Ensure required sections exist
- `get_detector_mapping()`: Extract detector ID -> name mapping
- `get_recording_schedule()`: Extract recording schedule parameters

**utilities.R** (11 functions)
- `%||%`: Null coalescing operator
- `ensure_dir_exists()`: Create directory if needed
- `safe_read_csv()`: Read CSV with error handling
- `convert_empty_to_na()`: Convert empty strings to NA
- `find_most_recent_file()`: Find most recent file by timestamp
- `setup_pipeline_context()`: Initialize pipeline context (YAML + validation)
- `load_most_recent_checkpoint()`: Load most recent checkpoint file
- `generate_timestamped_filename()`: Generate filename with timestamp
- `make_output_path()`: Generate output path for workflow
- `make_versioned_path()`: Generate versioned output path
- `fill_readme_template()`: Fill README template with values

**logging.R** (3 functions)
- `ensure_log_dir_exists()`: Create log directory if needed (internal)
- `log_message()`: Write timestamped message to log file
- `initialize_pipeline_log()`: Initialize pipeline run log

**console.R** (4 functions)
- `center_text()`: Center text within fixed width
- `print_stage_header()`: Print formatted stage header
- `print_workflow_summary()`: Print workflow completion summary
- `print_pipeline_complete()`: Print final pipeline completion

**artifacts.R** (11 functions)
- `init_artifact_registry()`: Create or load artifact registry
- `register_artifact()`: Add artifact with metadata and hash
- `get_artifact()`: Retrieve artifact by name
- `list_artifacts()`: List all artifacts (optionally filtered)
- `get_latest_artifact()`: Get most recent artifact by type
- `hash_file()`: Compute SHA256 hash of file
- `hash_dataframe()`: Compute hash of data frame contents
- `verify_artifact()`: Check if artifact matches registered hash
- `save_and_register_rds()`: Save RDS and register atomically
- `discover_pipeline_rds()`: Find summary_data and plot_objects RDS
- `validate_rds_structure()`: Validate RDS has required elements

**release.R** (4+ functions)
- `create_release_bundle()`: Create portable zip with all outputs
- `validate_release_inputs()`: Validate CPN and master before bundling
- `generate_manifest()`: Create manifest.yaml with provenance
- `build_analysis_bundle_rds()`: Create analysis_bundle.rds

### 5.2 Ingestion Module (`R/functions/ingestion/`)

**ingestion.R** (3 functions)
- `load_raw_data()`: Load CSV files from directory
- `apply_intro_standardization()`: Apply initial standardization
- `combine_raw_files()`: Combine multiple CSVs

**schema_detection.R** (5+ functions)
- `detect_schema_version()`: Identify KPro schema version
- `transform_schema_v1()`: Transform v1 legacy schema
- `transform_schema_v2()`: Transform v2 transitional schema
- `transform_schema_v3()`: Transform v3 modern schema
- `apply_schema_transformation()`: Apply appropriate transformation

### 5.3 Standardization Module (`R/functions/standardization/`)

**standardization.R** (7 functions)
- `convert_4letter_to_6letter()`: Convert 4-letter species codes to 6-letter
- `harmonize_column_names()`: Normalize column names (out_file -> out_file_fs)
- `transform_v1_to_unified()`: Transform v1 legacy schema to unified
- `transform_v2_to_unified()`: Transform v2 transitional schema to unified
- `transform_v3_to_unified()`: Transform v3 modern schema to unified
- `standardize_kpro_schema()`: Main orchestrator for schema transformation
- `create_unified_species_column()`: Create unified species field (manual_id > auto_id > NoID)

**datetime_helpers.R** (8 functions)
- `convert_datetime_to_local()`: Convert UTC to local timezone with DST handling
- `is.Date()`: Check if object is Date class
- `parse_datetime_safe()`: Safe multi-format datetime parsing
- `parse_date_safe()`: Safe multi-format date parsing
- `extract_time()`: Extract time component from datetime
- `format_datetime_for_log()`: Format datetime for edit log display
- `is_valid_timezone()`: Timezone validation (internal)
- `summarize_date_formats()`: Analyze date format patterns (internal)

### 5.4 Validation Module (`R/functions/validation/`)

**validation.R** (19 functions)
- `assert_data_frame()`: Assert object is data frame
- `assert_not_empty()`: Assert data frame has rows
- `assert_row_count()`: Assert exact row count
- `assert_columns_exist()`: Assert required columns exist
- `assert_column_type()`: Assert column has expected class
- `assert_not_na()`: Assert column has no NA values
- `assert_date_range()`: Assert valid date range
- `assert_time_format()`: Assert HH:MM:SS time format
- `assert_file_exists()`: Assert file exists with hints
- `assert_directory_exists()`: Assert/create directory
- `assert_scalar_string()`: Assert single string value
- `validate_data_frame()`: Combined assertions for common pattern
- `validate_cpn_data()`: Domain-specific CallsPerNight validation
- `validate_master_data()`: Domain-specific master file validation
- `enforce_unified_schema()`: Ensure master file schema compliance
- `finalize_master_columns()`: Remove unwanted columns and reorder
- `check_column_completeness()`: Report NA percentages per column
- `check_duplicates()`: Detect duplicate rows
- `validate_calls_per_night()`: Check CPN logical consistency

**validation_reporting.R** (6 functions)
- `create_validation_context()`: Initialize validation event tracking
- `log_validation_event()`: Record validation event to context
- `finalize_validation_report()`: Finalize context and save YAML + HTML
- `generate_validation_html()`: Generate HTML report from context
- `init_stage_validation()`: Initialize validation for stage (wrapper)
- `complete_stage_validation()`: Complete validation for stage (wrapper)

### 5.5 Analysis Module (`R/functions/analysis/`)

**callspernight.R** (6 functions)
- `calculate_recording_hours()`: Calculate recording duration (vectorized)
- `generate_calls_per_night_template()`: Generate CPN template with Excel formulas
- `apply_schedule()`: Apply recording schedule to template
- `save_callspernight_with_version()`: Save with auto-incrementing version
- `load_cpn_template()`: Load ORIGINAL or EDIT_THIS template
- `extract_template_timestamp()`: Extract timestamp from filename (internal)

**summarization.R** (3+ functions)
- `summarize_by_detector()`: Detector-level statistics
- `summarize_by_species()`: Species-level statistics
- `summarize_overall()`: Study-wide statistics

### 5.6 Output Module (`R/functions/output/`)

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
- `plot_recording_effort_heatmap()`: Date x Detector heatmap

**plot_detector.R** (7 functions)
- `plot_total_calls_by_detector()`: Bar chart from master
- `plot_detector_activity_caterpillar()`: Mean +/- CI
- `plot_detector_boxplots()`: Distribution boxplots
- `plot_activity_with_without_outliers()`: Side-by-side comparison
- `plot_synchrony()`: Multi-line time series
- `plot_correlation_heatmap()`: Correlation matrix
- `plot_detector_rank_over_time()`: Bump chart

**plot_species.R** (5 functions)
- `plot_species_composition_bar()`: Horizontal bar chart
- `plot_species_by_detector_heatmap()`: Species x Detector matrix
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

**tables.R** (3+ functions)
- `gt_study_overview()`: Study overview table
- `gt_detector_summary()`: Detector summary table
- `gt_species_composition()`: Species composition table

**report.R** (4+ functions)
- `snake_to_title()`: Convert snake_case to Title Case
- `make_caption()`: Generate plot captions
- `render_report()`: Orchestrate Quarto rendering
- Helper functions for report generation

### 5.7 Pipeline Module (`R/pipeline/`)

**run_ingest_standardize.R** (1 function)
- `run_ingest_standardize()`: Chunk 1 orchestrating function

**run_cpn_template.R** (1 function)
- `run_cpn_template()`: Chunk 2 orchestrating function

**run_finalize_to_report.R** (1 function)
- `run_finalize_to_report()`: Chunk 3 orchestrating function

### 5.8 Function Count Summary

| Module | File | Function Count |
|--------|------|----------------|
| Core | config.R | 5 |
| Core | utilities.R | 11 |
| Core | logging.R | 3 |
| Core | console.R | 4 |
| Core | artifacts.R | 11 |
| Core | release.R | 4+ |
| Ingestion | ingestion.R | 3 |
| Ingestion | schema_detection.R | 5+ |
| Standardization | standardization.R | 7 |
| Standardization | datetime_helpers.R | 8 |
| Validation | validation.R | 19 |
| Validation | validation_reporting.R | 6 |
| Analysis | callspernight.R | 6 |
| Analysis | summarization.R | 3+ |
| Output | plot_helpers.R | 6 |
| Output | plot_quality.R | 8 |
| Output | plot_detector.R | 7 |
| Output | plot_species.R | 5 |
| Output | plot_temporal.R | 6 |
| Output | tables.R | 3+ |
| Output | report.R | 4+ |
| Pipeline | run_*.R | 3 |
| **TOTAL** | | **~120+ functions** |

---

## 6. PLOT INVENTORY

### 6.1 Summary

- **Total plots:** 26
- **Quality:** 8 plots
- **Detector:** 7 plots
- **Species:** 5 plots (conditional on `species` column)
- **Temporal:** 6 plots

### 6.2 Quality Plots (8) - `plot_quality.R`

| Function | Input | Description |
|----------|-------|-------------|
| `plot_recording_status_summary` | CPN | Stacked bar of Pass/Partial/Fail by detector |
| `plot_recording_status_percent` | CPN | 100% stacked bar of status proportions |
| `plot_recording_status_overall` | CPN | Donut chart of overall status distribution |
| `plot_effort_by_detector` | CPN | Total recording hours by detector |
| `plot_nights_by_detector` | CPN | Night count by detector |
| `plot_data_completeness_calendar` | CPN | Calendar heatmap showing data presence |
| `plot_missing_nights` | CPN | Gap analysis visualization |
| `plot_recording_effort_heatmap` | CPN | Date x Detector hours heatmap |

### 6.3 Detector Plots (7) - `plot_detector.R`

| Function | Input | Description |
|----------|-------|-------------|
| `plot_total_calls_by_detector` | Master | Bar chart of total calls |
| `plot_detector_activity_caterpillar` | CPN | Mean +/- CI by detector |
| `plot_detector_boxplots` | CPN | Distribution of calls per detector |
| `plot_activity_with_without_outliers` | CPN | Side-by-side outlier comparison |
| `plot_synchrony` | CPN | Multi-line time series |
| `plot_correlation_heatmap` | CPN | Detector correlation matrix |
| `plot_detector_rank_over_time` | CPN | Bump chart of rankings |

### 6.4 Species Plots (5) - `plot_species.R`

| Function | Input | Description | Condition |
|----------|-------|-------------|-----------|
| `plot_species_composition_bar` | Master | Horizontal bar of species counts | Requires `species` column |
| `plot_species_by_detector_heatmap` | Master | Species x Detector matrix | Requires `species` column |
| `plot_species_accumulation_curve` | Master | Species discovery over time | Requires `species` column |
| `plot_species_hourly_profile` | Master | Activity by hour | Requires `species` + `Hour` |
| `plot_noid_proportion` | Master | NoID analysis by detector | Requires `species` column |

### 6.5 Temporal Plots (6) - `plot_temporal.R`

| Function | Input | Description | Condition |
|----------|-------|-------------|-----------|
| `plot_activity_over_time` | CPN | Line plot with smoothing | - |
| `plot_cumulative_calls_over_time` | CPN | Cumulative sum plot | - |
| `plot_hourly_activity_profile` | Master | Bar chart by hour | Requires `Hour` |
| `plot_callsperhour_distribution` | CPN | Histogram/density of CPH | - |
| `plot_weekly_activity` | CPN | Day-of-week patterns | - |
| `plot_activity_by_month` | CPN | Monthly aggregation | - |

### 6.6 Input Data Key

- **CPN:** `calls_per_night_final` from Chunk 3 / Workflow 04
- **Master:** `kpro_master` from Chunk 1 / Workflow 02-03

---

## 7. VERSION HISTORY

**v2.3 (2026-01-31)**
- Transitioned from workflow scripts to Shiny-driven orchestrating functions
- Added chunk model: run_ingest_standardize(), run_cpn_template(), run_finalize_to_report()
- Added orchestrating function template to templates section
- Updated all checklists with verbose parameter and centralized assertion requirements
- Added verbose gating examples to quick reference
- Added structured return examples
- Updated workflow inventory with chunk-to-workflow mapping
- Added pipeline module to function inventory
- Updated function count to ~95+

**v2.2 (2026-01-20)**
- Modularized standards into 9 focused documents
- Added artifact registry system (`artifacts.R`)
- Added dataset fingerprinting & hashing (SHA256)
- Added validation report system (HTML + YAML)
- Added console formatting functions (`print_stage_header()`, etc.)
- Added release bundle system (`release.R`)
- Added comprehensive manifest structure (9 sections)
- Updated Workflow 07 to include release bundle creation
- Added ~22 new functions to inventory
- Updated function count to ~85+

**v2.1 (2026-01-09)**
- Added Section 7.5: Workflow 07 Report Standards
- Added `reports/` directory for Quarto templates
- Added `results/reports/` directory for rendered HTML output
- Comprehensive standards for auto-generated Quarto reports

**v2.0 (2026-01-08)**
- Major update reflecting complete pipeline (Workflows 01-07)
- Added hierarchical directory structure with `results/` folder
- Added Layer Responsibilities section
- Added Function Script Headers section
- Expanded Quarto Integration section

**v1.0 (2025-12-26)**
- Initial comprehensive standards document
- Covered Workflows 01-03
- Established core philosophy and patterns

---

## 8. ACKNOWLEDGMENTS

This standards document synthesizes best practices from:
- Tidyverse style guide
- Google R style guide
- rOpenSci development guide
- Scientific reproducibility literature
- Bat acoustic analysis domain expertise
- Real-world pipeline development experience

---

**END OF APPENDICES**
