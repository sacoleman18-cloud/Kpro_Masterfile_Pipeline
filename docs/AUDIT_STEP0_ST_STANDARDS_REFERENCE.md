# ==============================================================================
# AUDIT STEP 0: ST_ STANDARDS REFERENCE FOR FUNCTION LIBRARY AUDIT
# ==============================================================================
# Date: 2026-02-09
# Purpose: Comprehensive reference document extracting key patterns from all ST_ 
#          documents to guide systematic audit of R/functions/ and R/modules/
# ==============================================================================

## DOCUMENT OVERVIEW

This reference synthesizes **11 ST_ standards documents** to establish the baseline for auditing function library uniformity, documentation completeness, and architectural compliance.

### ST_ Documents Reviewed

| Document | Version | Primary Focus | Audit Relevance |
|----------|---------|---------------|-----------------|
| `ST_STANDARDS_INDEX.md` | v3.0 | Navigation hub | Overall architecture understanding |
| `ST_ORCHESTRATION_PHILOSOPHY.md` | v1.0 | Phase orchestration | Module execution patterns |
| `ST_documentation_standards.md` | v3.0 | Headers, Roxygen2, comments | **PRIMARY** - Documentation audit |
| `ST_code_design_standards.md` | v3.0 | Function design, patterns | Function structure patterns |
| `ST_architecture_standards.md` | v3.0 | Directory structure, naming | File organization verification |
| `ST_data_standards.md` | v2.4 | Data validation, quality | Validation function patterns |
| `ST_logging_console_standards.md` | v2.4 | Logging, console output | Verbose gating patterns |
| `ST_quarto_reporting_standards.md` | v2.3 | Quarto integration | Report function patterns |
| `ST_artifact_release_standards.md` | v2.4 | Artifact registry | Provenance tracking patterns |
| `ST_development_standards.md` | v2.3 | Git, testing, YAML | Development workflow |
| `ST_appendices.md` | v2.2 | Templates, checklists | Quick reference lookup |

---

## PART 1: FILE HEADER STANDARDS

### 1.1 Function Script Header Template

**Required for all files in R/functions/ and R/modules/**

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

**Key Requirements:**
- Clear PURPOSE paragraph
- Complete DEPENDENCIES list (external packages + internal files)
- FUNCTIONS PROVIDED section with categorization
- USAGE examples
- CHANGELOG with dates

### 1.2 Module Header Template

**Required for processing modules in R/modules/**

```r
# ==============================================================================
# MODULE: [filename].R
# ==============================================================================
# 
# Classification: Processing Module
# Subtitle: [Brief one-line description]
#
# Description:
# [Detailed paragraph about what this module accomplishes]
#
# Module Stages:
#   Stage N: [Stage name and brief description]
#   Stage N+1: [Stage name and brief description]
#
# Data Flow:
#   Input:  [Description of input data and source]
#   Output: [Description of output data and format]
#
# Dependencies:
#   - R/functions/[category]/[file.R] (function_list)
#   - R/functions/[category]/[file.R] (function_list)
#
# Last Modified: YYYY-MM-DD
# Changelog: [Major changes description]
# ==============================================================================
```

**Key Requirements:**
- Classification as "Processing Module"
- Subtitle for quick identification
- Module Stages enumeration
- Data Flow (Input → Output) documentation
- Dependencies with explicit file paths and function lists
- Last Modified date

### 1.3 CONTENTS Section Requirements

**Critical for audit:** The CONTENTS/FUNCTIONS PROVIDED section must map:

1. **Function name** with proper prefix (verb-based)
2. **Brief description** (one line)
3. **Usage location** - internal only vs. used by modules/orchestrators
4. **Categorization** - group related functions

**Example (from standards):**
```r
# FUNCTIONS PROVIDED
# ------------------
# Recording Status (3):
#   - plot_recording_status_summary(): Stacked bar by detector
#     Used by: plotting.R module
#   - plot_recording_status_percent(): 100% stacked bar
#     Used by: plotting.R module, report.qmd
#   - plot_recording_status_overall(): Donut chart
#     Used by: plotting.R module (internal)
```

**Audit Action:** Verify every function is listed, categorized, and usage-mapped.

---

## PART 2: ROXYGEN2 DOCUMENTATION STANDARDS

### 2.1 Required Roxygen2 Sections

| Section | Required? | Purpose |
|---------|-----------|---------|
| Title (first line) | ✅ Yes | Brief one-line description |
| `@description` | ✅ Yes | Detailed multi-paragraph explanation |
| `@param` | ✅ Yes (for each parameter) | Parameter documentation |
| `@param verbose` | ⚠️ Recommended | For Shiny-compatible functions |
| `@return` | ✅ Yes | Return value description |
| `@section CONTRACT:` | ⚠️ Recommended | Function guarantees |
| `@section DOES NOT:` | ⚠️ Recommended | Explicit non-goals |
| `@examples` | ⚠️ Recommended | Usage examples |
| `@export` | ⚠️ If public | Mark as exported |
| `@keywords internal` | ⚠️ If private | Mark as internal |

### 2.2 Roxygen2 Template

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

### 2.3 Roxygen2 Audit Checklist

For each function, verify:

- [ ] Title line exists and is concise
- [ ] `@description` provides detailed context
- [ ] Every parameter has `@param` documentation
- [ ] `@return` describes return value and type
- [ ] `@section CONTRACT:` lists function guarantees (if applicable)
- [ ] `@section DOES NOT:` lists explicit non-goals (if applicable)
- [ ] `@examples` provides usage demonstration
- [ ] `@export` or `@keywords internal` properly marks visibility
- [ ] Verbose parameter documented if function supports it

---

## PART 3: FUNCTION DESIGN PATTERNS

### 3.1 Verbose Parameter Gating Pattern

**Standard pattern for Shiny-compatible functions:**

```r
process_data <- function(df, verbose = FALSE) {
  
  # Progress messages: GATED ✅
  if (verbose) message("  Processing data...")
  
  # Warnings: NEVER GATED ❌
  if (nrow(df) == 0) warning("Empty data frame provided")
  
  # Errors: NEVER GATED ❌
  if (!is.data.frame(df)) stop("Input must be a data frame")
  
  # File logging: NEVER GATED ❌
  log_message("Data processed successfully")
  
  # Completion messages: GATED ✅
  if (verbose) message("  [OK] Processing complete")
  
  result
}
```

**Gating Rules:**

| Output Type | Gate with `if (verbose)`? | Rationale |
|-------------|---------------------------|-----------|
| `message()` progress | ✅ Yes | Silent in Shiny |
| `message()` completion | ✅ Yes | Silent in Shiny |
| `warning()` | ❌ Never | User must see issues |
| `stop()` | ❌ Never | Errors must halt |
| `log_message()` | ❌ Never | Audit trail required |

### 3.2 Function Naming Conventions

**Verb-based naming for actions:**

```r
# ✅ GOOD: Verb-based function names (actions)
calculate_summary_stats()
validate_detector_names()
transform_schema_v1()
generate_cpn_template()
plot_recording_status()
load_raw_data()

# ❌ BAD: Noun-based or ambiguous
summary_stats()
detector_checker()
schema()
template()
recording()
```

**Helper functions may use noun + _helpers:**
```r
# ✅ GOOD: Helper function patterns
theme_kpro()              # Theme generator
kpro_palette_default()    # Palette provider
format_datetime_for_csv() # Formatter
```

### 3.3 Return Value Patterns

**Explicit returns:**
```r
# ✅ GOOD: Explicit return
calculate_effort <- function(df) {
  result <- df %>% summarize(hours = sum(RecordingHours))
  return(result)
}

# ✅ GOOD: Invisible return for side effect functions
save_checkpoint <- function(df, path) {
  write_csv(df, path)
  invisible(TRUE)
}

# ❌ BAD: Implicit return from pipeline
calculate_effort <- function(df) {
  df %>% summarize(hours = sum(RecordingHours))  # Unclear intent
}
```

---

## PART 4: MODULE STRUCTURE PATTERNS

### 4.1 Module File Organization

**R/modules/ structure:**

```
R/modules/
├── module_runner.R          ← Central execution layer (7 run_module_* functions)
├── data_ingestion.R         ← Module 1: Raw data loading
├── data_standardization.R   ← Module 2: Schema transformation
├── cpn_template.R           ← Module 3: CPN template generation
├── finalize_cpn.R           ← Module 4: CPN finalization
├── summary_stats.R          ← Module 5: Summary statistics
├── plotting.R               ← Module 6: Visualization generation
└── report_release.R         ← Module 7: Report & release bundle
```

**Each module must:**
1. Have module header following template in §1.2
2. Declare explicit dependencies (function files used)
3. Document data flow (Input → Output)
4. List module stages with stage numbers
5. Support `verbose` parameter for console gating

### 4.2 Function Library Organization (9 Layers)

**R/functions/ structure:**

```
R/functions/
├── core/                     ← Layer 1: Foundational utilities
│   ├── utilities.R           ← I/O, paths, templates
│   ├── orchestration_helpers.R  ← NEW: Orchestrator convenience functions
│   ├── logging.R             ← File logging
│   ├── console.R             ← Console formatting
│   ├── config.R              ← YAML configuration
│   ├── artifacts.R           ← Artifact registry
│   ├── release.R             ← Release bundle generator
│   └── load_all.R            ← Master loader
│
├── ingestion/                ← Layer 2: Data ingestion
│   └── ingestion.R
│
├── standardization/          ← Layer 3: Schema transformation
│   ├── standardization.R
│   ├── schema_helpers.R
│   └── datetime_helpers.R
│
├── validation/               ← Layer 4: Data validation
│   ├── validation.R
│   └── validation_reporting.R
│
├── analysis/                 ← Layer 5: Analysis functions
│   ├── callspernight.R
│   ├── detector_mapping.R
│   └── summarization.R
│
└── output/                   ← Layer 6: Visualization & output
    ├── plot_helpers.R
    ├── plot_quality.R
    ├── plot_detector.R
    ├── plot_species.R
    ├── plot_temporal.R
    ├── tables.R
    └── report.R
```

**Dependency rules:**
- Each layer may depend on previous layers ONLY
- No circular dependencies
- Layer 1 (core/) has ZERO internal dependencies
- All function files must declare dependencies in header

---

## PART 5: DEPENDENCY MAPPING REQUIREMENTS

### 5.1 Internal Dependencies Section Format

**Header requirement for all function files:**

```r
# DEPENDENCIES
# ------------
# R Packages:
#   - dplyr: Data manipulation
#   - ggplot2: Plotting
#   - here: Path management
#
# Internal Dependencies:
#   - R/functions/core/utilities.R (ensure_dir_exists, safe_read_csv)
#   - R/functions/core/logging.R (log_message)
#   - R/functions/validation/validation.R (validate_data, assert_file_exists)
```

**Format rules:**
- List R packages first with purpose
- List internal dependencies by file path
- Specify which functions are used (in parentheses)
- Keep alphabetically sorted within each category

### 5.2 Usage Mapping in FUNCTIONS PROVIDED

**Enhanced CONTENTS section with usage tracking:**

```r
# FUNCTIONS PROVIDED
# ------------------
# Data Loading (2):
#   - load_local_raw_data(): Load CSVs from data/raw/
#     Used by: data_ingestion.R module (Stage 2)
#   
#   - load_external_raw_data(): Load CSVs from configured external paths
#     Used by: data_ingestion.R module (Stage 2)
#
# Schema Detection (1):
#   - detect_schema_version(): Auto-detect v1/v2/v3 from column names
#     Used by: data_standardization.R module (Stage 3), [INTERNAL]
```

**Audit requirement:** Every function must specify where it's used:
- `Used by: [module_name].R module (Stage N)` - If called by specific module
- `Used by: [function_file].R ([calling_function])` - If called by another function
- `[INTERNAL]` - If only used within the same file

---

## PART 6: CHANGELOG AND VERSION TRACKING

### 6.1 Changelog Format

```r
# CHANGELOG
# ---------
# 2026-02-09: Extracted orchestrator helpers to orchestration_helpers.R
# 2026-02-05: Added orchestrator convenience functions
# 2026-01-31: Added verbose parameter for Shiny compatibility
# 2026-01-20: Added artifact registration
# 2026-01-15: Initial version
```

**Format:** `YYYY-MM-DD: Brief description of change`

**What to log:**
- ✅ New features or functions
- ✅ Bug fixes
- ✅ Breaking changes
- ✅ Moved/renamed functionality
- ✅ Dependency changes
- ✅ Parameter additions (especially verbose)

**What NOT to log:**
- ❌ Typo fixes
- ❌ Comment updates
- ❌ Whitespace changes

---

## PART 7: KNOWN ARCHITECTURAL PATTERNS

### 7.1 Orchestrator Helper Functions Pattern

**NEW in 2026-02-09:** Orchestrator-specific convenience functions extracted to dedicated file.

**File:** `R/functions/core/orchestration_helpers.R`

**Functions:**
- `setup_pipeline_context()` - Initialize workflow context
- `load_most_recent_checkpoint()` - Generic checkpoint loader
- `generate_timestamped_filename()` - Consistent filename generation
- `store_stage_results()` - Consolidate multi-stage outputs
- `log_stage_start()` - Combined console + file logging
- `save_checkpoint_and_register()` - Atomic CSV save + artifact registration
- `finalize_stage_validation_report()` - Validation HTML generation

**Usage:** Called by modules in R/modules/ (data_ingestion, data_standardization, cpn_template, finalize_cpn)

### 7.2 Plot Function Return Pattern

**ALL plot functions must:**
1. Return ggplot object (never print directly)
2. Use `theme_kpro()` for consistent styling
3. Support `verbose` parameter
4. Validate inputs using `validate_plot_input()`

```r
plot_detector_summary <- function(data, verbose = FALSE) {
  # Validation
  validate_plot_input(data, required_cols = c("Detector", "Nights"))
  
  if (verbose) message("  Creating detector summary plot...")
  
  # Build and return (never print)
  p <- ggplot(data, aes(x = Detector, y = Nights)) +
    geom_col() +
    theme_kpro()
  
  return(p)
}
```

### 7.3 Validation Event Logging Pattern

**Functions that perform validation should:**
1. Use `log_validation_event()` to track quality checks
2. Document validation in VALIDATION TRACKING section
3. Return validation context for HTML report generation

```r
validate_detector_names <- function(df, validation_context = NULL) {
  
  # Perform validation
  invalid <- df %>% filter(is.na(Detector) | Detector == "")
  
  # Log validation event
  if (!is.null(validation_context)) {
    log_validation_event(
      validation_context,
      event_type = "detector_names",
      severity = if (nrow(invalid) > 0) "warning" else "pass",
      message = sprintf("Found %d invalid detector names", nrow(invalid)),
      data_snapshot = list(invalid_count = nrow(invalid))
    )
  }
  
  # Return cleaned data
  df %>% filter(!is.na(Detector), Detector != "")
}
```

---

## PART 8: AUDIT PRIORITIES AND FOCUS AREAS

### 8.1 Critical Audit Items (Must Fix)

**Priority 1: Documentation Completeness**
- [ ] All functions have complete Roxygen2 documentation
- [ ] All files have proper headers (PURPOSE, DEPENDENCIES, FUNCTIONS PROVIDED)
- [ ] CHANGELOG exists and is current

**Priority 2: Dependency Mapping**
- [ ] All internal dependencies explicitly listed
- [ ] All external package dependencies listed with purpose
- [ ] FUNCTIONS PROVIDED section maps usage locations

**Priority 3: Architectural Compliance**
- [ ] Verbose parameter added where needed (Shiny-compatible functions)
- [ ] Function naming follows verb-based convention
- [ ] No hardcoded paths anywhere
- [ ] Validation events logged where applicable

### 8.2 Consistency Audit Items

**Priority 4: Formatting Consistency**
- [ ] Header formatting matches template exactly
- [ ] Roxygen2 sections follow standard order
- [ ] Changelog date format is YYYY-MM-DD
- [ ] Function categories are consistent across files

**Priority 5: Pattern Adherence**
- [ ] Plot functions return ggplot (never print)
- [ ] Verbose gating follows standard pattern
- [ ] Error messages are actionable
- [ ] Return values are documented

### 8.3 Files Requiring Special Attention

**Newly created files (2026-02-09):**
- ✅ `R/functions/core/orchestration_helpers.R` - NEW, needs dependency audit

**Recently modified files:**
- ⚠️ `R/functions/core/utilities.R` - Needs cleanup after extraction
- ⚠️ Module files (4) - Need dependency headers updated to reference orchestration_helpers.R

**Module execution layer:**
- ⚠️ `R/modules/module_runner.R` - Central infrastructure, validate documentation

---

## PART 9: EDGE CASES AND SPECIAL SCENARIOS

### 9.1 Legacy Code Exceptions

**Deprecated but documented:**
- Legacy workflow scripts (01_ingest_raw_data.R, etc.) use old header format
- Legacy chunk orchestrators may not follow phase result pattern
- Mark as deprecated in documentation: `# [DEPRECATED - Use Phase N]`

### 9.2 Internal-Only Functions

**Functions used only within same file:**
- Mark with `@keywords internal` in Roxygen2
- List as `[INTERNAL]` in FUNCTIONS PROVIDED usage mapping
- Still require complete documentation

### 9.3 Helper Function Clusters

**Example: plot_helpers.R provides utilities for other plot files**
- Must document which files use each helper
- FUNCTIONS PROVIDED should map usage: "Used by: plot_quality.R, plot_detector.R"

### 9.4 Multi-Stage Module Functions

**Modules like data_standardization.R have internal stage functions:**
- Document stage breakdown in module header
- Stage helper functions should be internal (not exported)
- Main module function should be the only public interface

---

## PART 10: AUDIT EXECUTION PLAN

### Step-by-Step Audit Approach

**Step 1: Module Documentation (4 files)**
1. Update dependency headers in 4 module files to reference orchestration_helpers.R
2. Ensure MODULE header matches template (§1.2)
3. Verify DEPENDENCIES section lists all function files used
4. Ensure Data Flow section is accurate

**Step 2: Header Audit (23 function files)**
1. Review all 23 function library files for header completeness
2. Verify PURPOSE is clear and concise
3. Check DEPENDENCIES sections (external + internal)
4. Audit FUNCTIONS PROVIDED sections (categorization + usage mapping)
5. Identify inconsistencies, WIP language, missing information

**Step 3: Roxygen2 Consistency (All functions)**
1. Scan all functions for Roxygen2 documentation
2. Verify required sections (§2.1) are present
3. Check verbose parameter documentation
4. Ensure CONTRACT/DOES NOT sections where applicable
5. Normalize formatting according to template (§2.2)

**Step 4: Pattern Documentation**
1. Generate summary of design/documentation patterns observed
2. Note deviations from ST_ standards
3. Suggest necessary changes to ST_ documents
4. Document new patterns for future standards updates

---

## SUMMARY: KEY PATTERNS TO ENFORCE

1. **Headers:** All files must have complete headers with PURPOSE, DEPENDENCIES, FUNCTIONS PROVIDED, CHANGELOG
2. **Roxygen2:** All functions must document @param, @return, @description at minimum
3. **Dependencies:** Explicit internal dependency mapping required (file + functions)
4. **Usage Mapping:** FUNCTIONS PROVIDED must specify where each function is used
5. **Verbose Pattern:** Shiny-compatible functions must have verbose parameter with proper gating
6. **Function Naming:** Verb-based actions (calculate_, validate_, transform_, generate_, plot_, load_)
7. **Categorization:** Functions grouped logically in FUNCTIONS PROVIDED section
8. **Changelog:** YYYY-MM-DD format with descriptive entries for meaningful changes
9. **No Hardcoded Paths:** All paths use here::here()
10. **orchestration_helpers.R:** New file (2026-02-09) must be referenced by 4 module files

---

## AUDIT OUTPUT REQUIREMENTS

Each audit step will produce a Markdown report including:

1. **Files Reviewed:** Complete list with line counts
2. **Changes Made:** File-by-file detailed summary
3. **Inconsistencies Found:** Specific violations with line numbers
4. **Decisions and Rationale:** Why changes were made
5. **Uncertainties/Edge Cases:** Items requiring clarification
6. **Exhaustiveness Confirmation:** Statement that scan was complete

---

## DOCUMENT VERSION

- **Date:** 2026-02-09
- **Author:** AI Assistant (Claude Sonnet 4.5)
- **Purpose:** Step 0 baseline reference for systematic function library audit
- **Next Step:** Begin Step 1 - Module Documentation Updates

