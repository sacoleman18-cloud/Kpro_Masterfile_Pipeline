# Deterministic Pipeline Compliance - Final Summary
**Date**: 2026-02-01  
**Status**: ✅ COMPLETE  
**Critical Issue**: Parameters violated deterministic pipeline principle

---

## Problem Statement

The user identified that I had added parameters to utility functions that violated a core architectural principle:

> **This pipeline is 100% deterministic. The USER never alters code.**
> 
> - USER clicks one button in Shiny UI to run `run_*` functions
> - All variability comes from YAML configuration and input data
> - NO code-level variability allowed

Additionally, changelogs were missing from the utilities.R cleanup work.

---

## Root Cause

I had added "helpful" parameters to utility functions (verbose, defaults, column names, etc.) thinking it would make them more flexible. However, this violated the deterministic principle by allowing developers to customize behavior at the code level rather than forcing all configuration through YAML.

---

## Changes Made

### 1. Added Missing Changelogs ✅

Updated utilities.R header with complete 2026-02-01 changelog entries:
- Documented removal of 5 legacy functions (workflow 01-07 pattern)
- Documented addition of 5 new orchestrator utilities
- Explained purpose: deterministic 3-chunk run_* system

### 2. Removed ALL Inappropriate Parameters ✅

#### setup_pipeline_context()
**Before:**
```r
setup_pipeline_context(workflow_name, verbose = FALSE)
```

**After:**
```r
setup_pipeline_context(workflow_name)
```

**Removed:**
- `verbose` parameter - orchestrator controls all console output

**Result:** Completely deterministic context setup

---

#### load_most_recent_checkpoint()
**Before:**
```r
load_most_recent_checkpoint(pattern,
                            checkpoint_dir = NULL,
                            error_hint = "Run previous chunk first",
                            verbose = FALSE)
```

**After:**
```r
load_most_recent_checkpoint(pattern)
```

**Removed:**
- `checkpoint_dir` - violates project structure (must always be outputs/checkpoints)
- `error_hint` - makes error messages variable per call
- `verbose` - orchestrator controls console output

**Result:** Uses FIXED checkpoint directory, standardized error messages

---

#### generate_timestamped_filename()
**Before:**
```r
generate_timestamped_filename(prefix,
                              suffix = "",
                              extension = ".csv",
                              format = "%Y%m%d_%H%M%S",
                              separator = "_")
```

**After:**
```r
generate_timestamped_filename(prefix, suffix = "")
```

**Removed:**
- `extension` - always .csv per project standards (FIXED)
- `format` - always YYYYMMDD_HHMMSS per project standards (FIXED)
- `separator` - always underscore per project standards (FIXED)

**Result:** Completely FIXED timestamp format, only prefix and optional suffix vary

---

#### get_schedule_config()
**Before:**
```r
get_schedule_config(study_params,
                   defaults = list(
                     recording_start = "18:00:00",
                     recording_end = "07:00:00",
                     advanced_scheduling = FALSE,
                     intended_hours = 13
                   ))
```

**After:**
```r
get_schedule_config(study_params)
```

**Removed:**
- `defaults` parameter - allows code-level override of defaults

**Result:** FIXED defaults hardcoded per bat study standards (18:00:00 / 07:00:00 / 13 hours)

---

#### create_unified_species_column()
**Before:**
```r
create_unified_species_column(data,
                              manual_col = "manual_id",
                              auto_col = "auto_id",
                              output_col = "species",
                              verbose = FALSE)
```

**After:**
```r
create_unified_species_column(data)
```

**Removed:**
- `manual_col`, `auto_col`, `output_col` - violates schema standards (FIXED column names)
- `verbose` - orchestrator controls console output

**Result:** FIXED column names per schema standards (manual_id, auto_id, species)

---

### 3. Updated Orchestrators ✅

**run_ingest_standardize.R:**
```r
# Before:
ctx <- setup_pipeline_context("ingest", verbose = verbose)
artifact_id <- generate_timestamped_filename("kpro_master", extension = "")

# After:
ctx <- setup_pipeline_context("ingest")
artifact_id <- sub("\\.csv$", "", generate_timestamped_filename("kpro_master"))
```

**run_cpn_template.R:**
```r
# Before:
ctx <- setup_pipeline_context("cpn_template", verbose = verbose)
kpro_master <- load_most_recent_checkpoint(
  pattern = "02_kpro_master_.*\\.csv$",
  checkpoint_dir = checkpoint_dir,
  error_hint = "Run Chunk 1 first",
  verbose = verbose
)
kpro_master <- create_unified_species_column(
  kpro_master,
  manual_col = "manual_id",
  auto_col = "auto_id",
  output_col = "species",
  verbose = verbose
)

# After:
ctx <- setup_pipeline_context("cpn_template")
kpro_master <- load_most_recent_checkpoint("02_kpro_master_.*\\.csv$")
kpro_master <- create_unified_species_column(kpro_master)
```

---

### 4. Updated Documentation ✅

All function Roxygen2 documentation updated:

**Added to @description:**
- "This is a DETERMINISTIC helper - [explanation of what's fixed]"

**Added to CONTRACT section:**
- "No configurable behavior - purely deterministic"
- Explicit notes about FIXED values and project standards

**Added to DOES NOT section:**
- "Accept verbose parameter (orchestrator controls console output)"
- "Allow custom [X] (violates [Y] standards)"

**Removed:**
- @param entries for deleted parameters
- Examples showing parameter customization

---

## Key Principles Enforced

### 1. 100% Deterministic
Same inputs (data + YAML) → Same outputs, every time

### 2. YAML-Driven Configuration
All variability comes from:
- study_parameters.yaml
- Input data in data/raw/

### 3. No Code Editing by USER
USER never touches code - only:
- Clicks buttons in Shiny UI
- Edits YAML in Shiny UI
- Provides data files

### 4. FIXED Project Standards
Everything is standardized:
- Directory structure (outputs/checkpoints)
- File naming (prefix_YYYYMMDD_HHMMSS.csv)
- Column names (manual_id, auto_id, species)
- Time formats (%Y%m%d_%H%M%S)
- Default values (18:00:00 / 07:00:00 / 13 hours)

---

## Standards Compliance

✅ **00_STANDARDS_INDEX.md**  
- Core Philosophy: "User-Friendly - Designed for researchers who may not know R"
- "Shiny-Ready - Orchestrating functions return structured results, no global side effects"

✅ **01_architecture_standards.md**  
- "All configuration from YAML (no interactive prompts)"
- "Silent by default (verbose = FALSE)" - handled at orchestrator level

✅ **03_code_design_standards.md**  
- Functions must be deterministic
- No hidden state or variable behavior

---

## Verification

### Before This Fix
❌ Functions accepted parameters that allowed code-level customization  
❌ Developer could change behavior by altering function calls  
❌ Multiple ways to achieve same result (violates principle of least surprise)  
❌ Error messages varied based on call site  

### After This Fix
✅ Functions are completely deterministic  
✅ NO parameters for customizing behavior  
✅ ONE way to use each function - no options  
✅ Standardized error messages  
✅ All variability comes from YAML/data only  

---

## Example: Completely Deterministic Call Chain

```r
# Orchestrator controls verbose (from YAML)
verbose <- study_params$processing_options$verbose %||% FALSE

# Utility functions - NO parameters for behavior
ctx <- setup_pipeline_context("ingest")
kpro_master <- load_most_recent_checkpoint("02_kpro_master_.*\\.csv$")
kpro_master <- create_unified_species_column(kpro_master)
schedule <- get_schedule_config(study_params)
filename <- generate_timestamped_filename("02_kpro_master")

# Orchestrator controls console output
if (verbose) message(sprintf("Loaded %d rows", nrow(kpro_master)))
```

**Every call is deterministic - no behavior customization possible.**

---

## Files Modified

1. **R/functions/core/utilities.R**
   - Added 2026-02-01 changelog entries
   - Removed inappropriate parameters from 5 functions
   - Updated Roxygen2 documentation

2. **R/pipeline/run_ingest_standardize.R**
   - Updated all utility function calls
   - Removed parameter passing

3. **R/pipeline/run_cpn_template.R**
   - Updated all utility function calls
   - Removed parameter passing

4. **DETERMINISTIC_COMPLIANCE.md** (this file)
   - Complete documentation of changes

---

## Lesson Learned

**Never add parameters that allow code-level behavior customization.**

In a deterministic pipeline:
- ✅ Parameters for data: `pattern`, `data`, `study_params`
- ❌ Parameters for behavior: `verbose`, `defaults`, `format`, `column_names`

All behavior must be FIXED or come from YAML configuration.

---

## Status

✅ **Changelogs added**  
✅ **Parameters removed**  
✅ **Orchestrators updated**  
✅ **Documentation updated**  
✅ **Deterministic principle enforced**  

**Ready for**: Production use in Shiny app with "one button" execution model
