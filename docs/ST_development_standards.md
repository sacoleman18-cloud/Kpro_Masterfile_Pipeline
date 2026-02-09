# ==============================================================================
# DEVELOPMENT STANDARDS
# ==============================================================================
# VERSION: 3.0
# LAST UPDATED: 2026-02-08
# PURPOSE: Version control, testing, dependencies, configuration, and enforcement
# ==============================================================================

## 1. VERSION CONTROL STANDARDS

### 1.1 Git Commit Messages

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

```
refactor: Add verbose parameter to all standardization functions

- Converted quiet=TRUE default to verbose=FALSE for consistency
- Gated all message() calls with if(verbose)
- Supports Shiny app integration
```

**RULES:**
- [OK] Use conventional commit format
- [OK] First line <= 50 characters
- [OK] Use imperative mood ("Add" not "Added")
- [OK] Reference issues when applicable
- [X] NEVER commit with message "updates" or "changes"

### 1.2 .gitignore Requirements

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
- [OK] Never commit user data
- [OK] Never commit outputs (use releases for sharing)
- [OK] Never commit credentials
- [OK] Commit .gitignore to repo
- [X] NEVER commit large files (> 10 MB)

### 1.3 UTF-8 Encoding Configuration

**Git configuration for UTF-8 preservation:**
```bash
git config --global core.autocrlf input
git config --global core.safecrlf true
```

**In .gitattributes:**
```
*.R text eol=lf
*.Rmd text eol=lf
*.qmd text eol=lf
*.md text eol=lf
*.yaml text eol=lf
```

---

## 2. TESTING STANDARDS

### 2.1 Testing Priority

| Priority | Functions | Coverage Target |
|----------|-----------|-----------------|
| Critical | `validate_*`, `detect_*_schema`, `assert_*` | 100% |
| High | `convert_datetime_*`, `calculate_recording_hours` | 90% |
| Medium | `plot_*`, `gt_*` | 75% |
| Low | `format_*`, `theme_*` | 50% |

### 2.2 Test File Naming

```
tests/
├── test_validation.R
├── test_assertions.R        # NEW: Centralized assertions
├── test_schema_helpers.R
├── test_datetime_conversion.R
├── test_callspernight.R
├── test_plot_functions.R
├── test_artifacts.R
├── test_release.R
└── test_phase_orchestrators.R  # NEW: Phase orchestrator tests
```

### 2.3 Testing Requirements

**Test coverage expectations:**
- Core functions: 100% coverage
- Validation/assertion functions: 100% coverage
- Artifact functions: 100% coverage
- Phase orchestrators: Integration tests
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

**Example assertion test:**
```r
test_that("assert_columns_exist provides helpful error messages", {
  df <- data.frame(a = 1:3, b = 4:6)
  
  # Should pass
  expect_silent(assert_columns_exist(df, c("a", "b")))
  
  # Should fail with helpful message
  expect_error(
    assert_columns_exist(df, c("a", "x"), source_hint = "run_phase1_data_preparation()"),
    regexp = "run_phase1_data_preparation"
  )
})
```

**Example phase orchestrator test:**
```r
test_that("run_phase1_data_preparation returns structured list", {
  skip_if_not(file.exists(here("data", "raw")))
  
  result <- run_phase1_data_preparation(verbose = FALSE)
  
  # Check structure
  expect_type(result, "list")
  expect_true("checkpoint_data" %in% names(result))
  expect_true("checkpoint_path" %in% names(result))
  expect_true("phase" %in% names(result))
  expect_true("phase_name" %in% names(result))
  expect_true("human_action_required" %in% names(result))
  expect_true("metadata" %in% names(result))
  expect_true("artifact_ids" %in% names(result))
  expect_true("validation_html_path" %in% names(result))
  
  # Check metadata structure
  expect_true("n_rows" %in% names(result$metadata))
  expect_true("rows_removed" %in% names(result$metadata))
  expect_true("data_filters_applied" %in% names(result$metadata))
  expect_true("modules_executed" %in% names(result$metadata))
})
```

**RULES:**
- [OK] Test edge cases (NA, empty, zero)
- [OK] Test expected behavior
- [OK] Test error conditions
- [OK] Use descriptive test names
- [OK] Test that phase orchestrators return proper structure
- [X] NEVER skip testing validation/assertion functions

---

## 3. DEPENDENCY MANAGEMENT STANDARDS

### 3.1 Package Loading

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

**In phase orchestrator functions:**
```r
# Packages loaded via load_all.R, not within function
# Functions assume packages are already loaded

run_phase1_data_preparation <- function(verbose = FALSE) {
  # No library() calls here
  # ...
}
```

**RULES:**
- [OK] Load all packages at top of script
- [OK] Use `library()` not `require()`
- [OK] Comment what each package is for
- [OK] Use `suppressPackageStartupMessages()` to reduce noise
- [X] NEVER use `library()` in functions
- [X] NEVER use `::` for frequently used functions (use for rare ones)

### 3.2 Package Dependencies

**Core dependencies (always loaded):**
```r
library(tidyverse)  # Data manipulation, ggplot2
library(lubridate)  # Date/time handling
library(hms)        # Time parsing
library(yaml)       # Configuration files
library(here)       # Path management
library(digest)     # SHA256 hashing
```

**Analysis dependencies (summary stage):**
```r
library(gt)         # GT table formatting
library(scales)     # Number/percent formatting
```

**Visualization dependencies (plot stage):**
```r
library(ggplot2)    # Already in tidyverse, but explicit
library(viridis)    # Color scales (optional)
library(svglite)    # SVG export (optional)
```

**Report dependencies (report stage):**
```r
library(quarto)     # Report rendering
library(zip)        # Cross-platform zip creation
```

---

## 4. PACKAGE DEPENDENCY STANDARDS

### 4.1 Required Packages

**Core packages:**
```r
# Data manipulation (always required)
library(tidyverse)   # Includes dplyr, tidyr, ggplot2, readr, etc.
library(lubridate)   # Date/time manipulation
library(hms)         # Time parsing
library(yaml)        # YAML file handling
library(here)        # Path management

# Summary Statistics
library(gt)          # GT table formatting
library(scales)      # Number/percent formatting

# Visualization
library(viridis)     # Color scales (optional)
library(svglite)     # SVG export (optional)

# Artifact & Release
library(digest)      # SHA256 hashing
library(zip)         # Cross-platform zip creation
library(quarto)      # Report rendering
```

### 4.2 Package Version Management

**Document package versions:**
```r
# In README or setup script
# Tested with:
# - R version 4.3.2
# - tidyverse 2.0.0
# - lubridate 1.9.2
# - here 1.0.1
# - digest 0.6.33
# - zip 2.3.0
# - quarto 1.3
```

---

## 5. YAML CONFIGURATION STANDARDS

### 5.1 study_parameters.yaml Structure

**Required sections:**
```yaml
config_version: 1

study_parameters:
  study_name: "My Bat Study 2025"
  study_id: "MyBatStudy2025"
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

# NEW: User-configurable data filters
data_filters:
  remove_duplicates: true       # Stage 6: Remove duplicate detections
  remove_noid: false            # Stage 7: Exclude auto_id == "NoID"
  remove_zero_pulse_calls: false  # Stage 7: Exclude pulses == 0 or NA

processing_options:
  use_alternate_ids: true
  filter_low_quality: false

recording_schedule:
  advanced_scheduling: false
  recording_start: "20:00:00"
  recording_end: "06:00:00"
  intended_hours_per_night: 10
```

### 5.2 Data Filters Configuration

The `data_filters` section controls optional filtering during Phase 1 processing:

```yaml
data_filters:
  # Remove exact duplicate detections (same Detector + DateTime + auto_id)
  # Applied in Phase 1 (module_standardization)
  # Default: true (recommended)
  remove_duplicates: true
  
  # Remove all rows where auto_id == "NoID"
  # Applied in Phase 1 (module_standardization)
  # Default: false (preserve for quality analysis)
  remove_noid: false
  
  # Remove all rows where pulses == 0 or is NA
  # Applied in Phase 1 (module_standardization)
  # Default: false (preserve for quality analysis)
  remove_zero_pulse_calls: false
```

**Filter behavior:**
- Filters are applied sequentially (duplicates → NoID → zero-pulse)
- Each filter logs a validation event with before/after row counts
- Filter configuration is included in return metadata
- Filters are recorded in the manifest for reproducibility

### 5.3 artifact_registry.yaml Structure

```yaml
registry_version: '1.0'
created_utc: '2026-01-12T06:34:34Z'
pipeline_version: '3.0'
artifacts:
  artifact_name:
    name: artifact_name
    type: checkpoint|masterfile|cpn_template|cpn_final|summary_stats|plot_objects|report|release_bundle
    workflow: 'phase1'  # Or '01' for legacy
    file_path: relative/path/to/file.csv
    file_hash_sha256: <64_char_hash>
    file_size_bytes: 12345
    created_utc: '2026-01-12T06:34:34Z'
    pipeline_version: '3.0'
    input_artifacts: [upstream_artifact_1, upstream_artifact_2]
    metadata:
      key: value
      data_filters_applied:
        remove_duplicates: true
        remove_noid: false
        remove_zero_pulse_calls: false
last_modified_utc: '2026-01-12T06:34:34Z'
```

### 5.4 YAML Best Practices

**RULES:**
- [OK] Use consistent indentation (2 spaces)
- [OK] Quote strings with spaces
- [OK] Use lowercase for keys
- [OK] Keep structure flat (avoid deep nesting)
- [OK] Comment complex sections
- [OK] Use ISO 8601 for timestamps
- [OK] Document data_filters defaults and behavior
- [X] NEVER use tabs
- [X] NEVER hard-code paths (use relative)

---

## 6. ENFORCEMENT

### 6.1 How to Use This Document

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

### 6.2 Updating This Document

**When to update:**
- New patterns emerge that should be standardized
- Common mistakes identified
- Best practices evolve
- New tools/packages adopted
- Architecture changes (e.g., chunk → phase model)

**How to update:**
- Propose changes via issue/PR
- Discuss with team (or self-document reasoning)
- Update version number
- Communicate changes
- Archive old versions

### 6.3 Code Review Checklist

Before merging code, verify:

- [ ] All functions have complete Roxygen2 documentation
- [ ] Phase orchestrators have proper header with PHASE POSITION and CHECKPOINT
- [ ] No hardcoded paths anywhere
- [ ] All error messages are helpful and actionable
- [ ] Tests exist for new functions
- [ ] CHANGELOG updated
- [ ] No commented-out code
- [ ] Consistent style (2 spaces, naming conventions)
- [ ] Git commit messages follow standards
- [ ] Artifacts registered (if applicable)
- [ ] Validation events logged (if applicable)
- [ ] **Verbose parameter added** for Shiny-compatible functions
- [ ] **Centralized assertions used** instead of custom validation
- [ ] **Structured returns** for phase orchestrators

### 6.4 Standards Violation Priority

| Priority | Violation | Action |
|----------|-----------|--------|
| Critical | Hardcoded paths | Fix immediately |
| Critical | Missing validation | Fix immediately |
| Critical | Silent data loss | Fix immediately |
| Critical | Phase orchestrator missing structured return | Fix immediately |
| High | Missing documentation | Fix before merge |
| High | No artifact registration | Fix before merge |
| High | Missing verbose parameter (Shiny functions) | Fix before merge |
| Medium | Style inconsistencies | Fix when touching file |
| Medium | Custom validation instead of assertions | Fix when touching file |
| Low | Missing tests for helpers | Track in backlog |

---

## 7. QUICK REFERENCE

### 7.1 New Project Setup

```bash
# Initialize Git
git init
git config core.autocrlf input

# Create .gitignore
cat > .gitignore << 'EOF'
data/
outputs/
results/
logs/
*.csv
.Rproj.user/
.Rhistory
.RData
EOF

# Create directory structure
mkdir -p R/{pipeline,workflows,functions/{core,ingestion,standardization,validation,analysis,output}}
mkdir -p inst/config
mkdir -p data/raw
mkdir -p outputs/{checkpoints,final}
mkdir -p results/{figures/{png/{quality,detector,species,temporal},svg},tables,csv,rds,reports,validation,releases}
mkdir -p logs docs tests reports
```

### 7.2 Standard Workflow Script Header (Deprecated)

```r
# ==============================================================================
# WORKFLOW ##: [NAME]
# ==============================================================================
# PURPOSE: [One line description]
# INPUTS: [List inputs]
# OUTPUTS: [List outputs]
# ==============================================================================

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(here)
  library(yaml)
})

# Load internal functions
source(here("R", "functions", "core", "load_all.R"))

# ==============================================================================
# STAGE ##.1: [STAGE NAME]
# ==============================================================================

print_stage_header("##.1", "Stage Name")

# ... implementation ...
```

### 7.3 Standard Phase Orchestrator Pattern

```r
#' Run Phase [N]: [Phase Name]
#'
#' @param verbose Logical. Print progress messages. Default: FALSE.
#' @return Named list with phase, checkpoint, metadata, and file paths.
#' @export
run_phase1_data_preparation <- function(verbose = FALSE) {
  
  # File logging (never gated)
  log_message("=== PHASE 1: Data Preparation - START ===")
  
  # Stage headers (gated by verbose)
  if (verbose) print_stage_header("1", "Load Configuration")
  
  # Use centralized assertions
  assert_file_exists(config_path, hint = "Configure study parameters first")
  
  # Progress messages (gated)
  if (verbose) message("  Loading configuration...")
  
  # ... processing stages ...
  
  # Register artifact
  registry <- init_artifact_registry()
  artifact_id <- sprintf("artifact_%s", format(Sys.time(), "%Y%m%d_%H%M%S"))
  registry <- register_artifact(...)
  
  # File logging (never gated)
  log_message("=== PHASE 1: Data Preparation - COMPLETE ===")
  
  # Return structured list
  list(
    phase = 1L,
    phase_name = "Data Preparation",
    checkpoint_path = checkpoint_path,
    checkpoint_data = result_data,
    human_action_required = FALSE,
    metadata = list(
      n_rows = nrow(result_data),
      data_filters_applied = filters_config
    ),
    artifact_ids = c(artifact_id),
    validation_html_path = validation_html_path
  )
}
```
