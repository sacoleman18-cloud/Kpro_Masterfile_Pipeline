# ==============================================================================
# DOCUMENTATION STANDARDS
# ==============================================================================
# VERSION: 3.0
# LAST UPDATED: 2026-02-08
# PURPOSE: Standards for documenting code, functions, and workflows
# ==============================================================================

## 1. LEGACY WORKFLOW SCRIPT HEADERS

> **Note (v3.0):** Legacy workflow scripts (01_ingest_raw_data.R, etc.) are deprecated.
> All new development should use **Phase Orchestrators** (see Section 2).
> For backward compatibility, legacy scripts may still have workflow headers.

Every legacy workflow script (01, 02, 03, etc.) must have this header:

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

## 2. PHASE ORCHESTRATOR FUNCTION HEADERS

> **NEW in v3.0:** Phase orchestrators replace legacy chunk orchestrators.
> See [ST_ORCHESTRATION_PHILOSOPHY.md](ST_ORCHESTRATION_PHILOSOPHY.md) for architecture overview.

Phase orchestrator functions require a specialized header format that documents phase position, checkpoints, human-in-the-loop requirements, and structured result passing.

**Required Template:**
```r
# ==============================================================================
# R/pipeline/run_phase[N]_[descriptive_name].R
# ==============================================================================
# PURPOSE
# -------
# [One paragraph description of what this phase accomplishes]
#
# PHASE POSITION
# --------------
# Phase [N] of 3 in the checkpointed phase orchestration:
#   Phase 1: run_phase1_data_preparation() → kpro_master.csv checkpoint
#   Phase 2: run_phase2_template_generation() → CPN_Template_EDIT_THIS.csv (USER EDITS)
#   Phase 3: run_phase3_analysis_reporting() → Final outputs (report, bundle)
#
# CHECKPOINT
# ----------
# Input checkpoint (from Phase [N-1]): [Description and location]
# Output checkpoint (for Phase [N+1]): [Description and location]
# Human-in-the-loop: [YES/NO] - [Describe if applicable]
#
# PROCESSING STAGES
# -----------------
#   Module [N]: [Module name and brief description]
#   Module [N]: [Module name and brief description]
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
#   - Returns structured result with: phase, phase_name, checkpoint_path, human_action_required
#   - All paths use here::here()
#   - Silent by default (verbose = FALSE)
#   - No interactive prompts
#   - Validation HTML always rendered
#   - No global side effects
#
# DOES NOT:
#   - Accept configuration as parameters (reads from YAML)
#   - Modify global environment
#   - Prompt for user input
#   - Perform conditional logic based on results (Shiny decides)
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

**Roxygen2 for Phase Orchestrator Functions:**

The Roxygen2 documentation for phase orchestrator functions should include the phase result structure as core documentation:

```r
#' Run Phase [N]: [Phase Name]
#'
#' @description
#' Phase [N] of the KPro Masterfile Pipeline's checkpointed phase orchestration.
#' [Detailed description of what this phase accomplishes and its role in the overall pipeline.]
#'
#' See [ST_ORCHESTRATION_PHILOSOPHY](ST_ORCHESTRATION_PHILOSOPHY.md) for architectural overview.
#'
#' @param phase_result (Phase [N-1] only) List. Result from previous phase containing
#'   checkpoint data and metadata. Typically: `phase1_result` or `phase2_result`.
#' @param verbose Logical. Print progress messages to console. Default: FALSE.
#'
#' @return Named list containing:
#'   \describe{
#'     \item{phase}{Integer. Phase number (e.g., 1, 2, or 3).}
#'     \item{phase_name}{Character. Descriptive phase name.}
#'     \item{checkpoint_path}{Character. Path to saved checkpoint file.}
#'     \item{human_action_required}{Logical. If TRUE, user must take action before next phase.}
#'     \item{checkpoint_data}{Tibble/Data Frame. Main data output (varies by phase).}
#'     \item{metadata}{List. Processing metadata including:
#'       \itemize{
#'         \item n_rows: Total rows in final dataset
#'         \item rows_removed: List with counts by filter type
#'         \item data_filters_applied: List showing filter configuration
#'         \item modules_executed: Character vector of module names
#'       }
#'     }
#'     \item{validation_html_path}{Character. Path to validation report.}
#'     \item{artifact_ids}{Character vector. Registered artifact identifiers.}
#'   }
#'
#' @section CONTRACT:
#' - Reads configuration from inst/config/study_parameters.yaml
#' - Always saves checkpoint to outputs/checkpoints/
#' - Always renders validation HTML to outputs/validation/
#' - Returns structured list (does not modify global environment)
#' - Gracefully handles missing input checkpoint (Phase 1)
#' 
#' @section PHASE [N] SPECIFIC:
#' [Phase-specific details about what makes this phase unique]
#' \itemize{
#'   \item Human-in-the-loop: [YES/NO]
#'   \item Checkpoint requirement: [Optional/Required]
#'   \item Interactive modules: [List any modules requiring user interaction]
#' }
#'
#' @section PHASE CHAINING:
#' This function is typically used in phase chaining pattern:
#' ```r
#' phase1 <- run_phase1_data_preparation(verbose = TRUE)
#' phase2 <- run_phase2_template_generation(phase1, verbose = TRUE)
#' # [USER EDITS TEMPLATE]
#' phase3 <- run_phase3_analysis_reporting(phase2, verbose = TRUE)
#' ```
#'
#' @export
```

**Example (run_phase2_template_generation.R):**
```r
#' Run Phase 2: CPN Template Generation
#'
#' @description
#' Phase 2 of the checkpointed pipeline orchestration. Generates the CPN template
#' from standardized data with user-editable parameters. Requires human review and
#' editing of the template before Phase 3 can proceed.
#'
#' See [ST_ORCHESTRATION_PHILOSOPHY](ST_ORCHESTRATION_PHILOSOPHY.md) §2 for module patterns.
#'
#' @param phase1_result List. Result from run_phase1_data_preparation() containing
#'   kpro_master.csv checkpoint and metadata.
#' @param verbose Logical. Print progress messages to console. Default: FALSE.
#'
#' @return Named list with phase structure and:
#'   \item{template_path}{Character. Path to CPN_Template_EDIT_THIS.csv}
#'   \item{template_df}{Data frame. Template ready for user editing.}
#'   \item{human_action_required}{Logical. TRUE - user MUST edit template.}
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
- [ ] Phase orchestrators have proper header with PHASE POSITION and CHECKPOINT sections (v3.0+)
- [ ] Phase orchestrators return structured results with phase, phase_name, checkpoint_path fields (v3.0+)
- [ ] No hardcoded paths anywhere
- [ ] All error messages are helpful and actionable
- [ ] Tests exist for new functions or modules
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
3. **Phase orchestrator header** - If phases, stages, or outputs changed (v3.0+)
4. **Workflow/Orchestrating header** - If stages or outputs changed (deprecated)
5. **CHANGELOG** - Always
6. **Coding standards** - If you're establishing a new pattern

---

## 8. DOCUMENTATION QUICK REFERENCE

### Required Documentation by File Type

| File Type | Header | Function Docs | Inline Comments | Changelog |
|-----------|--------|---------------|-----------------|-----------|
| Phase Orchestrator (`run_phase_*.R`) | Phase Orchest. template | Roxygen2 | [OK] Required | [OK] Required |
| Legacy Workflow (`##_name.R`) | Workflow template (deprecated) | N/A | [OK] Required | [OK] Required |
| Function module (`name.R`) | Module template | Roxygen2 | [OK] Required | [OK] Required |
| Config (`*.yaml`) | N/A | N/A | YAML comments | N/A |
| Quarto (`*.qmd`) | YAML frontmatter | N/A | HTML comments | N/A |

**Note (v3.0):** Phase orchestrators are now the primary execution model. Legacy workflow scripts are deprecated but documented for backward compatibility.

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
