# ==============================================================================
# DOCUMENTATION STANDARDS
# ==============================================================================
# VERSION: 2.3
# LAST UPDATED: 2026-01-31
# PURPOSE: Standards for documenting code, functions, and workflows
# ==============================================================================

## 1. WORKFLOW SCRIPT HEADERS

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
# VALIDATION TRACKING
# -------------------
# Events tracked:
#   - event_type: description
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

---

## 2. ORCHESTRATING FUNCTION HEADERS

Orchestrating functions (chunk functions for Shiny integration) require a specialized header format that documents pipeline position, decision points, and structured returns.

**Required Template:**
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
#   run_ingest_standardize()  -> [describe]
#   run_cpn_template()        -> [describe]
#   run_finalize_to_report()  -> [describe]
#
# DECISION POINTS (handled by Shiny app):
#   After Chunk [N]: [What decision the user makes]
#
# PROCESSING STAGES
# -----------------
#   Stage 1: [Stage name and brief description]
#   Stage 2: [Stage name and brief description]
#   ...
#
# CONTRACT
# --------
# INPUTS:
#   - [Input 1]: [Description and source]
#   - [Input 2]: [Description and source]
#
# OUTPUTS:
#   - [Output 1]: [Path pattern and description]
#   - [Output 2]: [Path pattern and description]
#
# GUARANTEES:
#   - All paths use here::here()
#   - Silent by default (verbose = FALSE)
#   - No interactive prompts
#   - Returns structured list
#   - Uses shared helpers (banners, validation init/finalize, checkpoint/template loaders,
#     RDS save/register, stage result storage) where applicable
#   - Validation HTML always rendered
#
# DOES NOT:
#   - Accept configuration as parameters (reads from YAML)
#   - Modify global environment
#   - Prompt for user input
#
# DEPENDENCIES
# ------------
#   Custom functions (via load_all.R):
#     - [module.R]: [functions used]
#
# CHANGELOG
# ---------
# YYYY-MM-DD: [Description]
# ==============================================================================
```

**Roxygen2 for Orchestrating Functions:**

The Roxygen2 documentation for orchestrating functions should include:

```r
#' Run [Chunk Name] Pipeline
#'
#' @description
#' Chunk [N] of the KPro pipeline. [Detailed description of what this
#' chunk accomplishes and its role in the overall pipeline.]
#'
#' @param verbose Logical. Print progress messages to console. Default: FALSE.
#'
#' @return Named list containing:
#'   \describe{
#'     \item{[primary_data]}{Tibble. [Description of main data output.]}
#'     \item{metadata}{List. Processing metadata including:
#'       \itemize{
#'         \item n_rows: Total rows in final dataset
#'         \item rows_removed: List with counts by filter type
#'         \item data_filters_applied: List showing filter configuration
#'       }
#'     }
#'     \item{artifact_id}{Character. Registered artifact identifier.}
#'     \item{checkpoint_path}{Character. Path to saved checkpoint.}
#'     \item{validation_html_path}{Character. Path to validation report.}
#'   }
#'
#' @section CONTRACT:
#' - Reads configuration from inst/config/study_parameters.yaml
#' - Always saves checkpoint
#' - Always renders validation HTML
#' - Returns structured list (does not modify global environment)
#'
#' @section DATA FILTERS:
#' Optional filters configured in study_parameters.yaml:
#' \itemize{
#'   \item remove_duplicates: TRUE/FALSE (default: TRUE)
#'   \item remove_noid: TRUE/FALSE (default: FALSE)
#'   \item remove_zero_pulse_calls: TRUE/FALSE (default: FALSE)
#' }
#'
#' @export
```

---

## 3. FUNCTION DOCUMENTATION (Roxygen2)

All exported functions must have complete Roxygen2 documentation:

```r
#' Brief One-Line Description
#'
#' @description
#' Detailed description of what the function does. Can be multiple
#' paragraphs if needed for complex functions.
#'
#' @param param_name Type. Description of parameter.
#' @param another_param Type. Description. Default: value
#' @param verbose Logical. Print progress messages to console. Default: FALSE.
#'
#' @return Type. Description of what is returned.
#'
#' @section CONTRACT:
#' - Guarantee 1
#' - Guarantee 2
#'
#' @section DOES NOT:
#' - Non-goal 1
#' - Non-goal 2
#'
#' @examples
#' \dontrun{
#' result <- my_function(input)
#' }
#'
#' @export
my_function <- function(param_name, another_param = "default", verbose = FALSE) {
  # Implementation
}
```

### Required Sections

| Section | Required? | Purpose |
|---------|-----------|---------|
| Title (first line) | [OK] Yes | Brief description |
| `@description` | [OK] Yes | Detailed explanation |
| `@param` | [OK] Yes (for each) | Parameter documentation |
| `@param verbose` | Recommended | For Shiny-compatible functions |
| `@return` | [OK] Yes | Return value description |
| `@section CONTRACT:` | Recommended | Guarantees the function makes |
| `@section DOES NOT:` | Recommended | Explicit non-goals |
| `@examples` | Recommended | Usage examples |
| `@export` | If public | Mark as exported |

### CONTRACT and DOES NOT Sections

These sections make function behavior explicit:

```r
#' @section CONTRACT:
#' - Returns NULL on failure instead of stopping execution
#' - Logs read errors with timestamps
#' - Reads all columns as character by default
#'
#' @section DOES NOT:
#' - Guess column types
#' - Modify data values
#' - Enforce schema requirements
```

### Verbose Parameter Pattern

All functions that may be called from Shiny (or orchestrating functions) should support a `verbose` parameter:

```r
#' @param verbose Logical. Print progress messages to console. Default: FALSE.
```

**Implementation pattern:**
```r
my_function <- function(data, verbose = FALSE) {
  
  # Progress messages gated by verbose
  if (verbose) message("  Processing data...")
  
  # Warnings always shown (not gated)
  if (nrow(data) == 0) warning("Empty data frame provided")
  
  # Errors always shown (not gated)
  if (!is.data.frame(data)) stop("Input must be a data frame")
  
  # Stage completion gated by verbose
  if (verbose) message("  [OK] Processing complete")
  
  result
}
```

**Rules:**
- [OK] Gate `message()` calls with `if (verbose)`
- [OK] Default to `verbose = FALSE` for Shiny compatibility
- [X] NEVER gate `warning()` or `stop()` calls
- [X] NEVER gate file logging (`log_message()` always writes)

---

## 4. FUNCTION SCRIPT HEADERS

All function files (e.g., `plot_quality.R`, `summarization.R`) must have a standardized header at the top of the file, separate from individual function Roxygen documentation.

**Required Template:**
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
# MODULE: plot_quality.R - Data Quality Visualization Functions
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
#   - plot_recording_effort_heatmap(): Date x Detector heatmap
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

## 5. INLINE COMMENTS

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

# CRITICAL FIX for Windows: Use relative paths to avoid colon issues
# in zip creation (see release.R for context)
setwd(dirname(staging_dir))

# Gate console output for Shiny compatibility
if (verbose) message("  Processing complete")
```

**RULES:**
- [OK] Explain WHY, not WHAT (code shows what)
- [OK] Keep comments up-to-date with code
- [OK] Use full sentences with proper grammar
- [OK] Mark critical fixes with `# CRITICAL:` or `# FIX:`
- [X] NEVER leave commented-out code (use Git)
- [X] NEVER use comments as version control

---

## 6. CHANGELOG STANDARDS

### In-File Changelogs

Every workflow and function file should have a CHANGELOG section:

```r
# CHANGELOG
# ---------
# 2026-01-31: Added verbose parameter for Shiny compatibility
# 2026-01-20: Added artifact registration
# 2026-01-15: Fixed timezone conversion bug
# 2026-01-10: Added validation report generation
# 2026-01-05: Initial version
```

**Format:** `YYYY-MM-DD: Brief description of change`

**What to log:**
- New features or functions
- Bug fixes
- Breaking changes
- Moved/renamed functionality
- Dependency changes
- Parameter additions (especially verbose)

**What NOT to log:**
- Typo fixes
- Comment updates
- Whitespace changes

---

## 7. COLLABORATION STANDARDS

### 7.1 Code Review Checklist

Before merging code, verify:

- [ ] All functions have complete Roxygen2 documentation
- [ ] Orchestrating functions have proper header with PIPELINE POSITION
- [ ] No hardcoded paths anywhere
- [ ] All error messages are helpful and actionable
- [ ] Tests exist for new functions
- [ ] CHANGELOG updated
- [ ] No commented-out code
- [ ] Consistent style (2 spaces, naming conventions)
- [ ] Git commit messages follow standards
- [ ] Artifacts registered (if applicable)
- [ ] Validation events logged (if applicable)
- [ ] Verbose parameter added for Shiny-compatible functions

### 7.2 Communication

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

### 7.3 Documentation Updates

When you change code, also update:

1. **Function Roxygen** - If parameters or behavior changed
2. **Module header** - If functions added/removed
3. **Workflow/Orchestrating header** - If stages or outputs changed
4. **CHANGELOG** - Always
5. **Coding standards** - If you're establishing a new pattern

---

## 8. DOCUMENTATION QUICK REFERENCE

### Required Documentation by File Type

| File Type | Header | Function Docs | Inline Comments | Changelog |
|-----------|--------|---------------|-----------------|-----------|
| Orchestrating (`run_*.R`) | Orchestrating template | Roxygen2 | [OK] Required | [OK] Required |
| Workflow (`##_name.R`) | Workflow template | N/A | [OK] Required | [OK] Required |
| Function module (`name.R`) | Module template | Roxygen2 | [OK] Required | [OK] Required |
| Config (`*.yaml`) | N/A | N/A | YAML comments | N/A |
| Quarto (`*.qmd`) | YAML frontmatter | N/A | HTML comments | N/A |

### Documentation Symbols

```r
# [OK] Allowed/Recommended
# [X] Forbidden/Avoid
# TODO (YYYY-MM-DD, initials): Future work
# FIXME: Known issue to address
# HACK: Workaround, explain why
# NOTE: Important context
# CRITICAL: Must not change without understanding
```
