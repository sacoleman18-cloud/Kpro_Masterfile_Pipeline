# ==============================================================================
# CODE DESIGN STANDARDS
# ==============================================================================
# VERSION: 2.3
# LAST UPDATED: 2026-01-31
# PURPOSE: Function design, error handling, variable naming, and code style
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
- Orchestrating functions return structured lists

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

All functions that may be called from orchestrating functions or Shiny apps must support a `verbose` parameter:

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

**Why this matters:** Orchestrating functions like `run_ingest_standardize()` default to `verbose = FALSE` for clean Shiny execution. Console messages would clutter the UI. Warnings and errors must always surface regardless of mode.

### 1.9 Structured Return Pattern for Orchestrating Functions

Orchestrating functions must return comprehensive structured lists, not just data:

```r
# [OK] GOOD: Orchestrating function return pattern
run_my_chunk <- function(verbose = FALSE) {
  
  # ... processing ...
  
  list(
    # Primary data output
    result_data = processed_df,
    
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
      )
    ),
    
    # File paths for downstream use
    artifact_id = artifact_id,
    checkpoint_path = checkpoint_path,
    validation_html_path = validation_html_path
  )
}

# [X] BAD: Just returning data
run_my_chunk <- function() {
  # ... processing ...
  processed_df  # No metadata, no paths
}
```

### 1.10 Workflow Orchestration Patterns

- Use `store_stage_results()` for result assembly and attach validation reports via that helper.
- Use `complete_stage_validation()` for validation HTML generation; avoid direct calls to
  `finalize_validation_report()` inside orchestrators.
- Maintain a shared `registry` when saving RDS artifacts; prefer `save_and_register_rds()` over
  manual save + register patterns.

**Required return elements for orchestrating functions:**
1. **Primary data** - The main tibble/data frame
2. **Metadata** - Row counts, filter counts, configuration used
3. **Artifact ID** - Registered artifact identifier
4. **File paths** - Checkpoint and validation report locations

---

## 2. ERROR HANDLING STANDARDS

### 2.1 Error Message Requirements

**Every error message must:**
1. Explain WHAT went wrong
2. Explain WHERE it went wrong (filename, column, row)
3. Suggest HOW to fix it

### 2.2 Good Error Messages

```r
# [OK] GOOD: Actionable, specific, helpful
if (!file.exists(checkpoint_file)) {
  stop(sprintf(
    "Checkpoint file not found: %s\n  Did you run Chunk 1 first?\n  Expected location: outputs/checkpoints/",
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

### 2.3 Bad Error Messages

```r
# [X] BAD: Uninformative
stop("Error")

# [X] BAD: No context
stop("File not found")

# [X] BAD: No suggestion
stop("Invalid data")
```

### 2.4 Error Handling Rules

| Scope | Rule | Enforcement Example |
|-------|------|---------------------|
| Actionable errors | Must tell user what to do | [OK] "Run Chunk 1 first" |
| Context inclusion | Include filename, column name, row count | [OK] `sprintf("Missing %d rows", n)` |
| Formatting | Use `sprintf()` for messages | [OK] `sprintf("AIC: %.2f", aic)` |
| Suggestions | Include fix suggestions | [OK] "Consider reviewing data ingestion" |
| Chunk context | Reference chunk not workflow | [OK] "Run Chunk 1 first" not "Run Workflow 02" |
| Never generic | Never "Error occurred" alone | [X] `stop("Error")` |
| Never silent | Always throw error or warn | [X] `if (error) return(NULL)` silently |
| Severity matching | Use appropriate level | [X] `stop()` for optional missing column |

### 2.5 Centralized Assertion Functions

Use the centralized `assert_*` functions from `validation.R` instead of writing custom validation:

```r
# [OK] GOOD: Use centralized assertions
my_function <- function(df, config_path) {
  assert_data_frame(df, "df")
  assert_not_empty(df, "df")
  assert_columns_exist(df, c("Detector", "Night"), source_hint = "run_ingest_standardize()")
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
| `assert_file_exists(path, hint)` | Validate file exists | `assert_file_exists(yaml_path, hint = "Run Chunk 1")` |
| `assert_directory_exists(path, create)` | Validate/create directory | `assert_directory_exists(output_dir, create = TRUE)` |
| `assert_scalar_string(x, arg_name)` | Validate single string | `assert_scalar_string(timezone, "timezone")` |
| `assert_date_range(start, end)` | Validate date order | `assert_date_range(start_date, end_date)` |
| `assert_column_type(df, col, type)` | Validate column class | `assert_column_type(df, "Night", "Date")` |

---

## 3. VARIABLE NAMING

### 3.1 Snake_case for Everything in R

```r
detector_id          # [OK] Good
detectorId           # [X] Bad (camelCase)
detector.id          # [X] Bad (dot notation)
```

### 3.2 Descriptive Names

```r
recording_start_time # [OK] Good
rst                  # [X] Bad (unclear abbreviation)
time1                # [X] Bad (meaningless)
```

### 3.3 Boolean Variables

```r
is_valid             # [OK] Good
has_species_column   # [OK] Good
valid                # [X] Bad (unclear)
```

### 3.4 Variable Naming Rules

- [OK] Use full words (not abbreviations)
- [OK] Be specific (not `data`, but `calls_per_night`)
- [OK] Use consistent terminology across codebase
- [X] NEVER use single letters (except `i` in loops)
- [X] NEVER reuse variable names

---

## 4. CODE ORGANIZATION

### 4.1 Within a Function

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

### 4.2 Within a Workflow Script

Use the standardized `print_stage_header()` function (see `05_logging_console_standards.md`):

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

### 4.3 Within an Orchestrating Function

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

## 5. STYLE STANDARDS

### 5.1 Spacing and Indentation

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

### 5.2 Line Length

**Keep lines under 80 characters when possible:**
```r
# [OK] GOOD: Readable, fits on screen
result <- df %>%
  filter(detector_id %in% active_detectors) %>%
  summarise(total = sum(calls, na.rm = TRUE))

# [X] BAD: Too long
result <- df %>% filter(detector_id %in% active_detectors) %>% summarise(total = sum(calls, na.rm = TRUE))
```

### 5.3 Piping Style

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

## 6. QUICK REFERENCE

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
