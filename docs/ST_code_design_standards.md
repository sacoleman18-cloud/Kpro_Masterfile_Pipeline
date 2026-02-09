# ==============================================================================
# CODE DESIGN STANDARDS
# ==============================================================================
# VERSION: 3.0
# LAST UPDATED: 2026-02-08
# PURPOSE: Function design, error handling, variable naming, code style, and helper patterns
# ==============================================================================

## 1. FUNCTION DESIGN PRINCIPLES

### 1.1 Single Responsibility

- Each function does ONE thing well
- If you can't describe it in one sentence, it's too complex

### 1.2 Pure Functions (when possible)

- Same inputs -> same outputs
- No side effects (except logging)
- Don't modify global state

### 1.3 Defensive Programming

- Validate inputs at function entry
- Check for NA, NULL, empty data frames
- Provide helpful error messages
- Use centralized assertion functions

### 1.4 Return Values

- Be explicit about what you return
- Use `invisible()` for functions called for side effects
- Document return structure
- **Phase orchestrator functions return structured phase results** (see §1.9)

### 1.5 Pattern for Functions Returning ggplot Objects

```r
plot_example <- function(data, verbose = FALSE) {
  # Validation
  validate_plot_input(data, required_cols = c("x", "y"))
  
  if (verbose) message("  Creating plot...")
  
  # Build and return (never print)
  ggplot(data, aes(x = x, y = y)) +
    geom_point() +
    theme_kpro()
}
```

### 1.6 Quiet Mode for Quarto-Ready Functions

```r
generate_summary <- function(df, quiet = FALSE) {
  if (!quiet) message("Generating summary...")
  # ... processing ...
  if (!quiet) message("[OK] Summary complete")
  invisible(result)
}
```

### 1.7 Function Design Rules

- [OK] Functions should be < 50 lines (ideally < 30)
- [OK] Use early returns for error conditions
- [OK] Validate all inputs using centralized assertions
- [OK] Name functions as verbs (actions): `calculate_`, `validate_`, `transform_`
- [X] NEVER use global variables
- [X] NEVER modify data frames in place (return new ones)

### 1.8 Verbose Parameter for Shiny Compatibility

All functions that may be called from phase orchestrators or Shiny apps must support a `verbose` parameter:

```r
# Pattern: Default silent, optionally verbose
process_data <- function(df, verbose = FALSE) {
  
  # Progress messages: GATED
  if (verbose) message("  Processing data...")
  
  # Warnings: NEVER GATED (always shown)
  if (nrow(df) == 0) warning("Empty data frame provided")
  
  # Errors: NEVER GATED (always thrown)
  if (!is.data.frame(df)) stop("Input must be a data frame")
  
  # File logging: NEVER GATED (always writes)
  log_message("Data processed successfully")
  
  # Completion messages: GATED  
  if (verbose) message("  [OK] Processing complete")
  
  result
}
```

**Gating rules:**

| Output Type | Gate with `if (verbose)`? | Rationale |
|-------------|---------------------------|-----------|
| `message()` progress | [OK] Yes | Silent in Shiny |
| `message()` completion | [OK] Yes | Silent in Shiny |
| `warning()` | [X] Never | User must see issues |
| `stop()` | [X] Never | Errors must halt |
| `log_message()` | [X] Never | Audit trail required |

**Why this matters:** Phase orchestrators like `run_phase1_data_preparation()` default to `verbose = FALSE` for clean Shiny execution. Console messages would clutter the UI. Warnings and errors must always surface regardless of mode.

### 1.9 Structured Return Pattern for Phase Orchestrator Functions

> **NEW in v3.0:** Phase orchestrators replace legacy chunk orchestrators.
> See [ST_ORCHESTRATION_PHILOSOPHY.md](ST_ORCHESTRATION_PHILOSOPHY.md) for complete patterns.

Phase orchestrator functions must return comprehensive structured results with explicit phase information:

```r
# [OK] GOOD: Phase orchestrator return pattern (v3.0)
run_phase1_data_preparation <- function(verbose = FALSE) {
  
  # ... processing ...
  
  list(
    # Phase identification
    phase = 1L,
    phase_name = "Data Preparation",
    
    # Checkpoint management
    checkpoint_path = checkpoint_file_path,
    checkpoint_data = processed_df,
    
    # Human-in-the-loop flag
    human_action_required = FALSE,
    
    # Processing metadata
    metadata = list(
      n_rows = nrow(processed_df),
      n_detectors = n_distinct(processed_df$Detector),
      rows_removed = list(
        invalid = n_invalid,
        duplicates = n_duplicates
      ),
      filters_applied = list(
        remove_duplicates = TRUE,
        remove_noid = FALSE
      ),
      modules_executed = c("module_ingestion", "module_standardization")
    ),
    
    # Artifact tracking
    artifact_ids = c(artifact_id_1, artifact_id_2),
    validation_html_path = validation_html_path
  )
}

# [OK] GOOD: Phase orchestrator with human-in-the-loop (Phase 2 pattern)
run_phase2_template_generation <- function(phase1_result, verbose = FALSE) {
  
  # Use checkpoint_data from previous phase
  kpro_master <- phase1_result$checkpoint_data
  
  # ... processing to generate template ...
  
  list(
    # Phase identification
    phase = 2L,
    phase_name = "Template Generation",
    
    # Checkpoint for Phase 3 to use
    checkpoint_path = template_checkpoint_path,
    checkpoint_data = template_df,
    
    # CRITICAL: Flag that user must edit template before Phase 3
    human_action_required = TRUE,
    human_action_instructions = "Edit CPN_Template_EDIT_THIS.csv manually before proceeding to Phase 3",
    
    # Processing metadata
    metadata = list(
      n_rows = nrow(template_df),
      species_count = n_distinct(template_df$Common_Name),
      modules_executed = c("module_cpn_template")
    ),
    
    artifact_ids = c(template_artifact_id),
    validation_html_path = validation_html_path
  )
}

# [X] BAD: Just returning data (no phase info, no metadata)
run_phase1_data_preparation <- function() {
  # ... processing ...
  processed_df  # Missing phase structure!
}
```

**Required return fields for phase orchestrator functions:**

1. **phase** - Integer (1, 2, or 3)
2. **phase_name** - Descriptive phase name ("Data Preparation", etc.)
3. **checkpoint_path** - Path to saved checkpoint file
4. **checkpoint_data** - The actual data (tibble/data frame)
5. **human_action_required** - Logical flag for Phase 2 human-in-the-loop
6. **metadata** - Processing metadata (row counts, filters, modules executed)
7. **artifact_ids** - Vector of registered artifact identifiers
8. **validation_html_path** - Path to validation HTML report

**Phase Chaining Pattern (using structured results):**
```r
# Phase 1 → Phase 2 → Phase 3
phase1 <- run_phase1_data_preparation(verbose = TRUE)
phase2 <- run_phase2_template_generation(phase1, verbose = TRUE)

# [USER EDITS CPN_Template_EDIT_THIS.csv]
# Then load edited template before Phase 3

phase3 <- run_phase3_analysis_reporting(phase2, verbose = TRUE)
```

---

## 2. CUSTOM OPERATORS AND UTILITY PATTERNS

### 2.1 Null Coalescing Operator (`%||%`)

The null coalescing operator provides default values when dealing with NULL:

```r
# Definition (in utilities.R)
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# Usage: Provide defaults in function parameters
timezone <- config$timezone %||% "America/New_York"
detector_name <- mapping[[detector_id]] %||% detector_id
output_path <- user_path %||% here("outputs", "default.csv")

# Common pattern: Safe nested list access
study_name <- config$metadata$study_name %||% "Unknown Study"
```

**When to use:**
- Providing default values for optional parameters
- Safely accessing nested list elements
- Handling missing configuration values

**What it does NOT do:**
- Does NOT handle NA values (only NULL)
- Does NOT handle empty strings ("")
- Does NOT handle empty vectors (length 0)

### 2.2 Safe File Operations

**Pattern: Safe CSV Reading**
```r
# Use safe_read_csv() instead of readr::read_csv()
df <- safe_read_csv(file_path, col_types = cols(.default = "c"))

# Returns tibble on success, NULL on failure (never errors)
# Useful for optional file loading
external_data <- safe_read_csv(external_path) %||% tibble()
```

**Pattern: Ensure Directory Exists**
```r
# Always use before writing files
ensure_dir_exists(here("outputs", "checkpoints"))
write_csv(df, output_path)

# Safe for repeated calls - no error if already exists
ensure_dir_exists(output_dir)  # Creates with recursive = TRUE
```

### 2.3 Phase Orchestrator Helper Patterns

> **v3.0:** Phase orchestrators are the primary execution model.
> See [ST_ORCHESTRATION_PHILOSOPHY.md](ST_ORCHESTRATION_PHILOSOPHY.md) §4 for complete workflows.

**Pattern: Pipeline Context Setup**
```r
# Consolidates YAML loading + validation context initialization
run_phase1_data_preparation <- function(verbose = FALSE) {
  # Replaces ~20 lines of boilerplate
  context_result <- setup_pipeline_context("data_preparation")
  study_params <- context_result$study_params
  validation_context <- context_result$validation_context
  
  # ... rest of processing ...
}
```

**Pattern: Phase Result Aggregation**
```r
# For phases that execute multiple modules
# Consolidate module outputs into phase result structure

run_phase1_data_preparation <- function(verbose = FALSE) {
  
  # Module 1 execution
  r1 <- run_module_ingestion(verbose = verbose)
  
  # Module 2 execution  
  r2 <- run_module_standardization(r1$checkpoint_data, verbose = verbose)
  
  # Consolidate into phase result
  list(
    phase = 1L,
    phase_name = "Data Preparation",
    checkpoint_path = r2$checkpoint_path,
    checkpoint_data = r2$checkpoint_data,
    human_action_required = FALSE,
    metadata = list(
      n_rows = nrow(r2$checkpoint_data),
      modules_executed = c("module_ingestion", "module_standardization"),
      validation_context = context_result$validation_context
    ),
    artifact_ids = c(r1$artifact_id, r2$artifact_id),
    validation_html_path = r2$validation_html_path
  )
}
```

**Pattern: Checkpoint Loading (for subsequent phases)**
```r
# Pattern-based checkpoint discovery from previous phase
run_phase2_template_generation <- function(phase1_result, verbose = FALSE) {
  
  # Use checkpoint_data from previous phase
  kpro_master <- phase1_result$checkpoint_data
  
  # ... template generation processing ...
}
```

**Pattern: Timestamped Filenames**
```r
# Consistent timestamp format across pipeline
checkpoint_file <- generate_timestamped_filename(
  "02_kpro_master", 
  suffix = ".csv"
)
# Result: "02_kpro_master_20260205_143022.csv"

# Used with make_output_path for full paths
checkpoint_path <- here("outputs", "checkpoints", checkpoint_file)
```

**Pattern: Atomic RDS Save + Register**
```r
# Saves RDS and registers artifact in one operation
registry <- save_and_register_rds(
  object = summary_data,
  file_path = here("results", "rds", "summary_data.rds"),
  artifact_type = "summary_stats",
  workflow = "05",
  registry = registry,
  metadata = list(n_summaries = 8, has_species = TRUE),
  verbose = verbose
)

# Atomically: saves file, computes SHA256 hash, registers in artifact registry
```

**Pattern: Store Stage Results (Multi-Stage Orchestrators)**
```r
# For orchestrators with multiple stages (e.g., run_finalize_to_report)
# Consolidates stage outputs and tracks validation reports

# Initialize result object
result <- list(
  validation_html_paths = character()
)

# After each stage, store outputs
stage_outputs <- list(
  data = processed_data,
  metadata = list(n_rows = nrow(processed_data), stage_complete = TRUE),
  artifact_id = artifact_id,
  checkpoint_path = checkpoint_path
)

result <- store_stage_results(
  result,
  stage_key = "finalize_cpn",
  stage_outputs = stage_outputs,
  validation_html = validation_html_path
)

# Later stages can access previous outputs
previous_data <- result$finalize_cpn$data
all_validation_reports <- result$validation_html_paths
```

---

## 3. ERROR HANDLING STANDARDS

### 3.1 Error Message Requirements

**Every error message must:**
1. Explain WHAT went wrong
2. Explain WHERE it went wrong (filename, column, row)
3. Suggest HOW to fix it

### 3.2 Good Error Messages

```r
# [OK] GOOD: Actionable, specific, helpful
if (!file.exists(checkpoint_file)) {
  stop(sprintf(
    "Checkpoint file not found: %s\n  Did you run Phase 1 first?\n  Expected location: outputs/checkpoints/",
    basename(checkpoint_file)
  ))
}

# [OK] GOOD: Context + suggestion
missing_cols <- setdiff(required_cols, names(df))
if (length(missing_cols) > 0) {
  stop(sprintf(
    "Missing required columns: %s\n  Found columns: %s\n  This suggests schema detection failed. Check data format.",
    paste(missing_cols, collapse = ", "),
    paste(names(df), collapse = ", ")
  ))
}
```

### 3.3 Bad Error Messages

```r
# [X] BAD: Uninformative
stop("Error")

# [X] BAD: No context
stop("File not found")

# [X] BAD: No suggestion
stop("Invalid data")
```

### 3.4 Error Handling Rules

| Scope | Rule | Enforcement Example |
|-------|------|---------------------|
| Actionable errors | Must tell user what to do | [OK] "Run Phase 1 first" |
| Context inclusion | Include filename, column name, row count | [OK] `sprintf("Missing %d rows", n)` |
| Formatting | Use `sprintf()` for messages | [OK] `sprintf("AIC: %.2f", aic)` |
| Suggestions | Include fix suggestions | [OK] "Consider reviewing data ingestion" |
| Phase context | Reference phase not workflow | [OK] "Run Phase 1 first" not "Run Workflow 02" |
| Never generic | Never "Error occurred" alone | [X] `stop("Error")` |
| Never silent | Always throw error or warn | [X] `if (error) return(NULL)` silently |
| Severity matching | Use appropriate level | [X] `stop()` for optional missing column |

### 3.5 Centralized Assertion Functions

Use the centralized `assert_*` functions from `validation.R` instead of writing custom validation:

```r
# [OK] GOOD: Use centralized assertions
my_function <- function(df, config_path) {
  assert_data_frame(df, "df")
  assert_not_empty(df, "df")
  assert_columns_exist(df, c("Detector", "Night"), source_hint = "run_phase1_data_preparation()")
  assert_file_exists(config_path, hint = "Configure study parameters first")
  
  # ... processing ...
}

# [X] BAD: Custom validation (duplicates code, inconsistent messages)
my_function <- function(df, config_path) {
  if (!is.data.frame(df)) stop("df must be a data frame")
  if (nrow(df) == 0) stop("df is empty")
  if (!file.exists(config_path)) stop("Config not found")
  
  # ... processing ...
}
```

**Available assertion functions:**

| Function | Purpose | Example |
|----------|---------|---------|
| `assert_data_frame(x, arg_name)` | Validate is data frame | `assert_data_frame(df, "kpro_master")` |
| `assert_not_empty(df, arg_name)` | Validate has rows | `assert_not_empty(df, "cpn_final")` |
| `assert_columns_exist(df, cols, hint)` | Validate columns present | `assert_columns_exist(df, c("Detector", "Night"))` |
| `assert_file_exists(path, hint)` | Validate file exists | `assert_file_exists(yaml_path, hint = "Run Phase 1")` |
| `assert_directory_exists(path, create)` | Validate/create directory | `assert_directory_exists(output_dir, create = TRUE)` |
| `assert_scalar_string(x, arg_name)` | Validate single string | `assert_scalar_string(timezone, "timezone")` |
| `assert_date_range(start, end)` | Validate date order | `assert_date_range(start_date, end_date)` |
| `assert_column_type(df, col, type)` | Validate column class | `assert_column_type(df, "Night", "Date")` |

---

## 4. CONSOLE OUTPUT AND LOGGING HELPERS

### 4.1 Console Formatting Functions

**Stage Headers (from console.R):**
```r
# Use for numbered stages in orchestrator functions
if (verbose) print_stage_header("1", "Load Configuration")
if (verbose) print_stage_header("2.1", "Apply Detector Mapping")

# Output:
# +-----------------------------------------------------------------+
# |                   STAGE 1: Load Configuration                   |
# +-----------------------------------------------------------------+
```

**Workflow Summary (from console.R):**
```r
# Use at chunk/workflow completion
if (verbose) {
  print_workflow_summary(
    workflow = "CHUNK 1",
    title = "Ingest & Standardize Complete",
    items = list(
      "Rows processed" = format(nrow(df), big.mark = ","),
      "Checkpoint" = basename(checkpoint_path),
      "Validation HTML" = basename(validation_html)
    )
  )
}

# Output: Formatted box with workflow name, title, and key-value items
```

**Pipeline Complete (from console.R):**
```r
# Use at final pipeline completion
if (verbose) {
  print_pipeline_complete(
    outputs = list(
      "Final CPN" = "CallsPerNight_final_v1.csv",
      "Report" = "bat_activity_report.html"
    ),
    next_steps = c(
      "Review validation report",
      "Download release bundle"
    ),
    report_path = report_path
  )
}
```

### 4.2 File Logging Functions

**Always Active (Never Gated):**
```r
# From logging.R - file logging always happens regardless of verbose
log_message("=== CHUNK 1: Ingest & Standardize Started ===")
log_message(sprintf("Loaded %d rows from %d files", n_rows, n_files))
log_message("Checkpoint saved: outputs/checkpoints/02_kpro_master.csv")
log_message("=== CHUNK 1: Complete ===")

# Writes to logs/pipeline_YYYY-MM-DD.log with timestamps
# [2026-02-05 14:30:22] === CHUNK 1: Ingest & Standardize Started ===
```

**Initialize Pipeline Log:**
```r
# Initialize at start of orchestrator function
initialize_pipeline_log("run_ingest_standardize")

# Creates/appends to daily log file, writes header
```

### 4.3 Console Output Gating Pattern

**Orchestrator functions must gate all console output:**
```r
run_my_chunk <- function(verbose = FALSE) {
  
  # File logging: NEVER gated
  log_message("=== Starting chunk ===")
  
  # Stage headers: GATED
  if (verbose) print_stage_header("1", "Load Data")
  
  # Progress messages: GATED
  if (verbose) message("  Loading configuration...")
  
  # Warnings: NEVER gated
  if (nrow(df) == 0) warning("Empty data frame")
  
  # Errors: NEVER gated
  if (!file.exists(path)) stop("File not found")
  
  # Completion: GATED
  if (verbose) message("  [OK] Complete")
  
  # File logging: NEVER gated
  log_message("=== Chunk complete ===")
}
```

---

## 5. ARTIFACT MANAGEMENT AND VALIDATION REPORTING

### 5.1 Artifact Registry Pattern

**Initialize Registry:**
```r
# At start of orchestrator function
registry <- init_artifact_registry()
```

**Register Individual Artifacts:**
```r
# Register checkpoints, outputs, reports
registry <- register_artifact(
  registry = registry,
  artifact_name = "kpro_master",
  artifact_type = "checkpoint",
  workflow = "01",
  file_path = checkpoint_path,
  metadata = list(
    n_rows = nrow(df),
    data_hash = hash_dataframe(df)
  )
)
```

**Atomic RDS Save + Register:**
```r
# Best practice for RDS files - combines save + register
registry <- save_and_register_rds(
  object = plot_objects,
  file_path = here("results", "rds", "plot_objects.rds"),
  artifact_type = "plots",
  workflow = "06",
  registry = registry,
  metadata = list(n_plots = 26),
  verbose = verbose
)
```

### 5.2 Validation Reporting Pattern

**Initialize Validation Context:**
```r
# Option 1: Using helper wrapper
validation_context <- init_stage_validation("chunk_1", study_params)

# Option 2: Direct creation
validation_context <- create_validation_context(
  workflow = "chunk_1",
  study_name = study_params$study_name
)
```

**Log Events During Processing:**
```r
# Track important events during chunk execution
validation_context <- log_validation_event(
  validation_context,
  event_type = "data_loaded",
  description = "Raw CSV files loaded",
  count = n_files,
  details = list(local = n_local, external = n_external)
)

validation_context <- log_validation_event(
  validation_context,
  event_type = "filter_noid",
  description = "NoID detections removed",
  count = n_removed
)
```

**Finalize and Generate Report:**
```r
# Option 1: Using helper wrapper
validation_html_path <- complete_stage_validation(
  validation_context = validation_context,
  validation_dir = here("results", "validation"),
  stage_name = "CHUNK 1",
  verbose = verbose
)

# Option 2: Direct finalization
validation_context <- finalize_validation_report(
  validation_context,
  output_dir = here("results", "validation")
)
validation_html_path <- validation_context$html_path
```

### 5.3 Combined Pattern in Orchestrator

```r
run_my_chunk <- function(verbose = FALSE) {
  
  # Initialize both registry and validation
  registry <- init_artifact_registry()
  validation_context <- init_stage_validation("my_chunk", study_params)
  
  # ... processing stages ...
  
  # Log events
  validation_context <- log_validation_event(
    validation_context,
    event_type = "processing_complete",
    count = nrow(result_df)
  )
  
  # Register artifacts
  registry <- register_artifact(
    registry, "my_output", "checkpoint", "01", checkpoint_path
  )
  
  # Finalize validation
  validation_html <- complete_stage_validation(
    validation_context, validation_dir, "MY CHUNK", verbose
  )
  
  # Return structured list
  list(
    data = result_df,
    metadata = list(...),
    artifact_id = artifact_id,
    checkpoint_path = checkpoint_path,
    validation_html_path = validation_html
  )
}
```

---

## 6. VARIABLE NAMING

### 6.1 Snake_case for Everything in R

```r
detector_id          # [OK] Good
detectorId           # [X] Bad (camelCase)
detector.id          # [X] Bad (dot notation)
```

### 6.2 Descriptive Names

```r
recording_start_time # [OK] Good
rst                  # [X] Bad (unclear abbreviation)
time1                # [X] Bad (meaningless)
```

### 6.3 Boolean Variables

```r
is_valid             # [OK] Good
has_species_column   # [OK] Good
valid                # [X] Bad (unclear)
```

### 6.4 Variable Naming Rules

- [OK] Use full words (not abbreviations)
- [OK] Be specific (not `data`, but `calls_per_night`)
- [OK] Use consistent terminology across codebase
- [X] NEVER use single letters (except `i` in loops)
- [X] NEVER reuse variable names

---

## 7. CODE ORGANIZATION

### 7.1 Within a Function

```r
my_function <- function(df, verbose = FALSE) {
  
  # -------------------------
  # Input validation
  # -------------------------
  assert_data_frame(df, "df")
  assert_not_empty(df, "df")
  
  # -------------------------
  # Data preparation
  # -------------------------
  if (verbose) message("  Preparing data...")
  clean_df <- df %>%
    filter(!is.na(value))
  
  # -------------------------
  # Core processing
  # -------------------------
  if (verbose) message("  Processing...")
  result <- clean_df %>%
    summarise(total = sum(value))
  
  # -------------------------
  # Return
  # -------------------------
  if (verbose) message("  [OK] Complete")
  result
}
```

### 7.2 Within a Workflow Script

Use the standardized `print_stage_header()` function (see `ST_logging_console_standards.md`):

```r
# ==============================================================================
# STAGE 1.1: LOAD RAW DATA
# ==============================================================================

print_stage_header("1.1", "Load Raw Data")

# Stage code here...

# ==============================================================================
# STAGE 1.2: APPLY INTRO STANDARDIZATION
# ==============================================================================

print_stage_header("1.2", "Apply Intro Standardization")

# Stage code here...
```

### 7.3 Within an Orchestrating Function

Gate all console output with verbose:

```r
run_my_chunk <- function(verbose = FALSE) {
  
  # Stage headers gated
  if (verbose) print_stage_header("1", "Load Configuration")
  
  # Processing with gated messages
  if (verbose) message("  Loading YAML config...")
  config <- load_config()
  if (verbose) message("  [OK] Configuration loaded")
  
  # File logging always happens
  log_message("=== CHUNK N: Started ===")
  
  # ... rest of processing ...
}
```

---

## 8. STYLE STANDARDS

### 8.1 Spacing and Indentation

**Use 2 spaces for indentation:**
```r
# [OK] GOOD
if (condition) {
  do_something()
}

# [X] BAD: 4 spaces
if (condition) {
    do_something()
}

# [X] BAD: Tabs
if (condition) {
	do_something()
}
```

**Spaces around operators:**
```r
# [OK] GOOD
x <- 1 + 2
result <- df %>% filter(value > 0)

# [X] BAD
x<-1+2
result<-df%>%filter(value>0)
```

### 8.2 Line Length

**Keep lines under 80 characters when possible:**
```r
# [OK] GOOD: Readable, fits on screen
result <- df %>%
  filter(detector_id %in% active_detectors) %>%
  summarise(total = sum(calls, na.rm = TRUE))

# [X] BAD: Too long
result <- df %>% filter(detector_id %in% active_detectors) %>% summarise(total = sum(calls, na.rm = TRUE))
```

### 8.3 Piping Style

**Use %>% for clarity:**
```r
# [OK] GOOD: One operation per line
result <- raw_data %>%
  filter(!is.na(detector_id)) %>%
  mutate(date = ymd(date)) %>%
  group_by(detector_id, date) %>%
  summarise(total_calls = n(), .groups = "drop")

# [X] BAD: Everything on one line
result <- raw_data %>% filter(!is.na(detector_id)) %>% mutate(date = ymd(date)) %>% group_by(detector_id, date) %>% summarise(total_calls = n(), .groups = "drop")
```

---

## 9. QUICK REFERENCE

### Good vs Bad Examples

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

**Orchestrating Functions:**
```r
# [X] BAD: Just returns data
run_chunk <- function() {
  df <- process_data()
  df
}

# [OK] GOOD: Returns structured list
run_chunk <- function(verbose = FALSE) {
  if (verbose) message("  Processing...")
  df <- process_data()
  
  list(
    data = df,
    metadata = list(n_rows = nrow(df)),
    artifact_id = "chunk_20260131",
    checkpoint_path = here("outputs", "checkpoints", "chunk.csv"),
    validation_html_path = here("results", "validation", "chunk.html")
  )
}
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

**Helper Functions:**
```r
# [X] BAD: Manual null checking
config_tz <- if (is.null(config$timezone)) "America/New_York" else config$timezone

# [OK] GOOD: Use %||% operator
config_tz <- config$timezone %||% "America/New_York"

# [X] BAD: Manual checkpoint loading
files <- list.files("outputs/checkpoints", pattern = "02_kpro_master", full.names = TRUE)
checkpoint_file <- files[length(files)]
df <- read_csv(checkpoint_file)

# [OK] GOOD: Use helper function
df <- load_most_recent_checkpoint("02_kpro_master_.*")

# [X] BAD: Manual RDS save + register
saveRDS(summary_data, file_path)
file_hash <- digest::digest(file_path, algo = "sha256", file = TRUE)
registry <- register_artifact(registry, "summary_data", "summary", "05", file_path, 
                              metadata = list(hash = file_hash))

# [OK] GOOD: Atomic save + register
registry <- save_and_register_rds(
  summary_data, file_path, "summary", "05", registry, 
  metadata = list(n_summaries = 8), verbose = verbose
)
```

**Console Output:**
```r
# [X] BAD: Manual box drawing
message("\n+----------------------------------------------------------+")
message("|                STAGE 1: Load Data                         |")
message("+----------------------------------------------------------+\n")

# [OK] GOOD: Use helper function
if (verbose) print_stage_header("1", "Load Data")

# [X] BAD: No structured completion message
if (verbose) message("Complete!")

# [OK] GOOD: Use workflow summary
if (verbose) {
  print_workflow_summary(
    workflow = "CHUNK 1",
    title = "Processing Complete",
    items = list("Rows" = nrow(df), "Time" = elapsed_time)
  )
}
```

**Validation Reporting:**
```r
# [X] BAD: Manual validation tracking
events <- list()
events[[1]] <- list(type = "data_loaded", count = nrow(df))
# ... more manual tracking ...

# [OK] GOOD: Use validation helpers
validation_context <- init_stage_validation("chunk_1", study_params)
validation_context <- log_validation_event(
  validation_context, "data_loaded", "Raw data loaded", nrow(df)
)
validation_html <- complete_stage_validation(
  validation_context, validation_dir, "CHUNK 1", verbose
)
```

**Multi-Stage Result Storage:**
```r
# [X] BAD: Manual result building across stages
result <- list()
result$stage1_data <- data1
result$stage1_metadata <- meta1
result$validation_paths <- c(html1)
# ... manual tracking for each stage ...

# [OK] GOOD: Use store_stage_results helper
result <- list(validation_html_paths = character())

result <- store_stage_results(
  result,
  stage_key = "finalize_cpn",
  stage_outputs = list(data = cpn_final, metadata = list(...)),
  validation_html = validation_html_path
)

# Clean access to stage outputs
cpn <- result$finalize_cpn$data
all_reports <- result$validation_html_paths
```
