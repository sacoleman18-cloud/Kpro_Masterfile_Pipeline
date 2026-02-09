# ==============================================================================
# LOGGING & CONSOLE OUTPUT STANDARDS
# ==============================================================================
# VERSION: 3.0
# LAST UPDATED: 2026-02-08
# PURPOSE: File logging, console output formatting, progress indicators, verbose gating
# ==============================================================================

## 1. LOG FILE MANAGEMENT

### 1.1 Log File Requirements

**Log files must:**
- Be written to `logs/` directory
- Use ISO 8601 timestamps
- Be named: `pipeline_YYYY-MM-DD.log`
- Be appended (not overwritten)

### 1.2 Implementation

**Core Module:** `R/functions/core/logging.R`

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

### 1.3 Initialize Phase Log

Use `initialize_pipeline_log()` at the start of phase orchestrator functions to write a formatted header:

```r
# From logging.R
initialize_pipeline_log <- function(phase_name) {
  log_message(sprintf("===== %s =====", phase_name))
  log_message(sprintf("Started: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
  log_message("")
}

# Usage in phase orchestrator
run_phase1_data_preparation <- function(verbose = FALSE) {
  initialize_pipeline_log("PHASE 1: Data Preparation")
  # ... processing ...
}
```

---

## 2. WHAT TO LOG

### 2.1 ALWAYS Log

- Phase/workflow start/end times
- Files loaded (path and row count)
- Major transformations (what was done)
- Validation failures/warnings
- Files written (path and row count)
- Errors and their context
- Artifact registrations

### 2.2 NEVER Log

- Sensitive data (detector locations, etc.)
- Full data frames
- Passwords or credentials

### 2.3 Example Logging in Phase Orchestrator

```r
run_phase1_data_preparation <- function(verbose = FALSE) {
  
  # File logging always happens (not gated)
  log_message("=== PHASE 1: Data Preparation - START ===")
  
  log_message(sprintf("Loading CSV files from: %s", raw_data_dir))
  log_message(sprintf("Found %d CSV files", length(csv_files)))
  
  # ... processing ...
  
  log_message(sprintf("Loaded %s rows from %d files", 
                     format(nrow(raw_combined), big.mark = ","),
                     length(csv_files)))
  
  log_message(sprintf("Applied schema transformation"))
  log_message(sprintf("Saved checkpoint: %s", checkpoint_file))
  
  log_message("=== PHASE 1: Data Preparation - COMPLETE ===")
  
  # Return structured result
  list(...)
}
```

---

## 3. CONSOLE FORMATTING FUNCTIONS

**Core Module:** `R/functions/core/console.R`

All console formatting functions are provided in `console.R` (split from utilities.R on 2026-02-04 for modularity).

### 3.1 Stage Header Function

Replace manual ASCII box drawing with the standardized `print_stage_header()` function:

**OLD (deprecated):**
```r
message("\n+------------------------------------------------------------------+")
message("|               STAGE 2.1: Load Configuration                     |")
message("+------------------------------------------------------------------+\n")
```

**NEW (required):**
```r
print_stage_header("2.1", "Load Configuration")
```

**Output:**
```
+-----------------------------------------------------------------+
|                 STAGE 2.1: Load Configuration                   |
+-----------------------------------------------------------------+
```

### 3.2 Phase Summary Function

Use `print_workflow_summary()` for phase/workflow completion messages:

```r
print_workflow_summary(
  workflow = "PHASE 1",
  title = "Data Preparation Complete",
  items = list(
    "Rows processed" = format(nrow(df), big.mark = ","),
    "Checkpoint" = basename(checkpoint_path),
    "Validation" = basename(validation_html_path)
  )
)
```

**Output:**
```
+================================================================+
||    PHASE 1 COMPLETE: Data Preparation Complete                ||
+================================================================+

  - Rows processed: 1,975
  - Checkpoint: 02_kpro_master_20260131_002136.csv
  - Validation: validation_ingest_20260131_002136.html
```

### 3.3 Pipeline Complete Function

Use `print_pipeline_complete()` only at the end of Phase 3 / Workflow 07:

```r
print_pipeline_complete(
  outputs = list(
    "Master Data" = "outputs/final/Master_20260112.csv",
    "CPN Final" = "results/csv/CallsPerNight_final_v6.csv",
    "Report" = "results/reports/bat_activity_report_20260112.html",
    "Release Bundle" = "results/releases/kpro_release_study_20260112.zip"
  ),
  next_steps = c(
    "Review the HTML report",
    "Share release bundle with collaborators",
    "Import CPN into NB GAMM project"
  ),
  report_path = "results/reports/bat_activity_report_20260112.html"
)
```

### 3.4 Box Character Reference

The formatting functions use these box-drawing characters:

**Single-line boxes** (for stage headers):
```
Top-left: +    Horizontal: -    Top-right: +
Vertical: |                     Vertical: |
Bot-left: +    Horizontal: -    Bot-right: +
```

**Double-line boxes** (for workflow/pipeline completion):
```
Top-left: +    Horizontal: =    Top-right: +
Vertical: ||                    Vertical: ||
Bot-left: +    Horizontal: =    Bot-right: +
```

### 3.5 Verbose Gating for Shiny Compatibility

All console output functions should be gated by `verbose` parameter when called from phase orchestrator functions:

```r
run_phase1_data_preparation <- function(verbose = FALSE) {
  
  # Stage headers: GATED
  if (verbose) print_stage_header("1", "Load Configuration")
  
  # Progress messages: GATED  
  if (verbose) message("  Loading study parameters...")
  
  # Completion messages: GATED
  if (verbose) message("  [OK] Configuration loaded")
  
  # Workflow summary: GATED
  if (verbose) {
    print_workflow_summary(
      workflow = "PHASE 1",
      title = "Data Preparation Complete",
      items = list("Rows" = format(nrow(df), big.mark = ","))
    )
  }
  
  # File logging: NEVER GATED
  log_message("=== PHASE 1: Data Preparation - START ===")
  log_message(sprintf("[Stage 1] Loaded configuration from %s", yaml_path))
  
  # Warnings: NEVER GATED
  if (n_unmapped > 0) warning(sprintf("%d detectors unmapped", n_unmapped))
  
  # Errors: NEVER GATED
  if (nrow(df) == 0) stop("No data loaded")
}
```

**Gating summary:**

| Output | Function | Gate? | Rationale |
|--------|----------|-------|-----------|
| Stage headers | `print_stage_header()` | [OK] Yes | Visual noise in Shiny |
| Progress | `message()` | [OK] Yes | Visual noise in Shiny |
| Summaries | `print_workflow_summary()` | [OK] Yes | Visual noise in Shiny |
| File log | `log_message()` | [X] Never | Audit trail required |
| Warnings | `warning()` | [X] Never | User must see issues |
| Errors | `stop()` | [X] Never | Must halt execution |

### 3.6 Phase vs Workflow Terminology

When logging from phase orchestrator functions, use "Phase" terminology:

```r
# [OK] GOOD: Phase terminology for phase orchestrators
log_message("=== PHASE 1: Data Preparation - START ===")
log_message("=== PHASE 1: Data Preparation - COMPLETE ===")

# [OK] ALSO GOOD: Legacy workflow terminology for workflow scripts
log_message("=== WORKFLOW 01: INGEST RAW DATA - START ===")

# [X] BAD: Mixed terminology
log_message("=== WORKFLOW 1: Ingest & Standardize - START ===")  # Don't mix
```

**Terminology mapping:**

| Context | Terminology | Example |
|---------|-------------|---------|
| Phase orchestrator | "PHASE N" | `"=== PHASE 1: Data Preparation ==="` |
| Legacy workflow script | "WORKFLOW ##" | `"=== WORKFLOW 01: INGEST RAW DATA ==="` |
| Stage within either | "Stage N" | `print_stage_header("3", "Apply Filters")` |

---

## 4. MESSAGE FORMATTING RULES

### 4.1 DO Use

```r
# In workflow scripts (always shown)
print_stage_header("3.2", "Generate Template")
message("  Loading master data...")
message(sprintf("  Rows: %s", format(nrow(df), big.mark = ",")))
message("  [OK] Template generated")

# In orchestrating functions (gated)
if (verbose) print_stage_header("3.2", "Generate Template")
if (verbose) message("  Loading master data...")
if (verbose) message(sprintf("  Rows: %s", format(nrow(df), big.mark = ",")))
if (verbose) message("  [OK] Template generated")
```

### 4.2 DO NOT Use

```r
# Manual box drawing (use print_stage_header instead)
message("+------------------------------------------+")

# Cat for console output (use message instead)
cat("Processing complete\n")

# Print statements (use message instead)
print("Done")

# Ungated console output in orchestrating functions
message("Processing...")  # BAD: Should be gated
```

---

## 5. PROGRESS INDICATORS

### 5.1 Long-Running Operations

For long-running operations, use consistent progress indicators:

```r
# Start of operation (gated in orchestrating functions)
if (verbose) message("  Processing detectors...")

# Progress updates (for loops)
for (i in seq_along(detectors)) {
  if (i %% 10 == 0 || i == length(detectors)) {
    if (verbose) message(sprintf("    [%d/%d] %s", i, length(detectors), detectors[i]))
  }
}

# Completion (gated)
if (verbose) message(sprintf("  [OK] Processed %d detectors", length(detectors)))
```

### 5.2 Batch Processing Pattern

```r
if (verbose) message(sprintf("  Processing %d files...", length(files)))

results <- purrr::map(files, function(f) {
  # Process file
  result <- process_file(f)
  if (verbose) message(sprintf("    [OK] %s", basename(f)))
  result
})

if (verbose) message(sprintf("  [OK] All %d files processed", length(files)))
```

---

## 6. STATUS INDICATORS

Use these consistent status prefixes:

| Prefix | Meaning | Example |
|--------|---------|---------|
| `[OK]` | Success | `message("  [OK] File saved")` |
| `[*]` | In progress | `message("[*] Loading data...")` |
| `[!]` | Warning | `message("  [!] Missing 3 nights")` |
| `[X]` | Error | `message("  [X] File not found")` |
| `[?]` | Information | `message("  [?] Optional step skipped")` |

---

## 7. NUMERIC FORMATTING

### 7.1 Large Numbers

Always format large numbers with separators:

```r
# Good
message(sprintf("  Rows processed: %s", format(nrow(df), big.mark = ",")))
# Output: "  Rows processed: 2,008"

# Bad
message(sprintf("  Rows processed: %d", nrow(df)))
# Output: "  Rows processed: 2008"
```

### 7.2 Percentages

```r
message(sprintf("  Filtered: %.1f%%", 100 * removed / total))
# Output: "  Filtered: 12.5%"
```

### 7.3 File Sizes

```r
size_mb <- file.info(path)$size / 1024^2
message(sprintf("  File size: %.1f MB", size_mb))
```

### 7.4 Durations

```r
elapsed <- difftime(Sys.time(), start_time, units = "secs")
message(sprintf("  Duration: %.1f seconds", as.numeric(elapsed)))
```

---

## 8. UTILITY FUNCTIONS

### 8.1 Module Organization

Console and logging functions are organized into separate modules for clarity:

**`R/functions/core/logging.R`:**
- `log_message()` - Write timestamped messages to log file
- `initialize_pipeline_log()` - Write formatted header to log
- `ensure_log_dir_exists()` - Internal helper (creates log directory)

**`R/functions/core/console.R`:**
- `center_text()` - Center text within fixed width (internal helper)
- `print_stage_header()` - Print formatted stage header box
- `print_workflow_summary()` - Print phase/workflow completion summary
- `print_pipeline_complete()` - Print pipeline completion with next steps

**`R/functions/core/utilities.R`:**
- `%||%` - Null coalescing operator (for default values)
- Other general utilities (not console/logging specific)

### 8.2 Console Formatting Functions (in console.R)

```r
#' Print Stage Header
#'
#' @param stage_num Character. Stage number (e.g., "2.1")
#' @param title Character. Stage title
#' @param width Integer. Box width (default: 65)
#'
#' @return NULL (called for side effect)
print_stage_header <- function(stage_num, title, width = 65) {
  # Implementation details in utilities.R
}

#' Print Workflow Summary
#'
#' @param workflow Character. Phase/workflow identifier (e.g., "PHASE 1")
#' @param title Character. Summary title
#' @param items Named list. Items to display
#' @param width Integer. Box width (default: 65)
#'
#' @return NULL (called for side effect)
print_workflow_summary <- function(workflow, title, items, width = 65) {
  # Implementation details in utilities.R
}

#' Print Pipeline Complete Summary
#'
#' @param outputs Named list. Output files by workflow
#' @param next_steps Character vector. Suggested next steps
#' @param report_path Character. Path to HTML report
#' @param width Integer. Box width (default: 65)
#'
#' @return NULL (called for side effect)
print_pipeline_complete <- function(outputs, next_steps, report_path, width = 65) {
  # Implementation details in utilities.R
}
```

---

## 9. QUICK REFERENCE

### 9.1 Patterns

**Phase Orchestrator Pattern:**
```r
run_phase1_data_preparation <- function(verbose = FALSE) {
  
  # File logging always
  log_message("=== PHASE 1: Data Preparation - START ===")
  
  # Console output gated
  if (verbose) print_stage_header("1", "Load Configuration")
  if (verbose) message("  Loading study parameters...")
  if (verbose) message(sprintf("  [OK] Loaded: %s", basename(config_path)))
  
  # ... processing ...
  
  # Summary gated
  if (verbose) {
    print_workflow_summary(
      workflow = "PHASE 1",
      title = "Phase Complete",
      items = list(
        "Rows processed" = format(nrow(df), big.mark = ","),
        "Output file" = basename(output_path)
      )
    )
  }
  
  # File logging always
  log_message("=== PHASE 1: Data Preparation - COMPLETE ===")
}
```

**Legacy Workflow Script Pattern:**
```r
# At workflow start
log_message(sprintf("=== WORKFLOW %s: %s - START ===", wf_num, wf_name))

# At each stage
print_stage_header("1.1", "Load Configuration")
message("  Loading study parameters...")
message(sprintf("  [OK] Loaded: %s", basename(config_path)))

# At workflow end
print_workflow_summary(
  workflow = wf_num,
  title = "Workflow Complete",
  items = list(
    "Rows processed" = format(nrow(df), big.mark = ","),
    "Output file" = basename(output_path)
  )
)
log_message(sprintf("=== WORKFLOW %s: %s - COMPLETE ===", wf_num, wf_name))
```

### 9.2 Error Logging

```r
tryCatch({
  # Risky operation
}, error = function(e) {
  log_message(sprintf("[ERROR] %s: %s", operation_name, e$message))
  stop(e)
})
```

### 9.3 Gating Quick Reference

| In Orchestrating Functions | Gate with `if (verbose)`? |
|---------------------------|---------------------------|
| `print_stage_header()` | [OK] Yes |
| `message()` | [OK] Yes |
| `print_workflow_summary()` | [OK] Yes |
| `log_message()` | [X] Never |
| `warning()` | [X] Never |
| `stop()` | [X] Never |
