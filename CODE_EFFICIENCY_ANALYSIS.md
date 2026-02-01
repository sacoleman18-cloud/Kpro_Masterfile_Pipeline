# Code Efficiency Analysis - Critical Findings
**Date**: 2026-02-01  
**Analysis Type**: Code duplication, function usage, efficiency opportunities

---

## Critical Finding: ensure_study_parameters() Integration is PROBLEMATIC

### What I Did Previously
I integrated `ensure_study_parameters()` as Stage 3 of `run_ingest_standardize.R` (lines 403-430), which:
- Calls `ensure_study_parameters(raw_combined, yaml_path)` to reconcile detector mappings
- Reloads study_params to get the updated mappings
- Adds a new stage between data loading and schema transformation

### Why This Doesn't Make Sense

#### Problem 1: Timing is Backwards
```
Current flow:
Stage 1: assert YAML exists → load study_params
Stage 2: load raw data
Stage 3: ensure_study_parameters() → creates YAML if missing, reconciles detectors
Stage 4+: use study_params

Issue: Stage 1 FAILS if YAML missing, but Stage 3 creates it. Too late!
```

#### Problem 2: Redundant State Management
```r
# Line 218: Stage 1 loads YAML
study_params <- load_study_parameters(yaml_path)

# Line 412-418: Stage 3 modifies YAML on disk, then reloads
ensure_study_parameters(raw_data, yaml_path)
study_params <- load_study_parameters(yaml_path)  # ← Redundant reload

# This couples in-memory state to disk unnecessarily
```

#### Problem 3: Violates Design Intent
Stage 1 uses `assert_file_exists()` which says "YAML must exist before running pipeline."
Stage 3 creates YAML if missing, which contradicts Stage 1's assertion.

**This is a design smell: the pipeline both requires and creates the same file.**

### What Should Happen Instead

#### Option A: Ensure YAML Exists BEFORE Pipeline Runs (RECOMMENDED)
```r
# In Shiny app initialization:
if (!file.exists(yaml_path)) {
  # Create minimal YAML template
  cfg <- build_study_config(
    study_name = "NewStudy",
    start_date = Sys.Date(),
    end_date = Sys.Date() + 90,
    detector_mapping = c()  # Empty initially
  )
  save_study_parameters(cfg)
}

# Then run pipeline - Stage 1 will always succeed
run_ingest_standardize()
```

#### Option B: Make Reconciliation Conditional
```r
# Only reconcile if new detectors found (not create YAML)
discovered_ids <- unique(raw_combined$detector_id)
yaml_ids <- names(study_params$study_parameters$detector_mapping)

if (!setequal(discovered_ids, yaml_ids)) {
  message("[!] New detectors found - reconciling YAML")
  ensure_study_parameters(raw_combined, yaml_path)
  study_params <- load_study_parameters(yaml_path)
}
```

#### Option C: Remove Stage 3 Entirely (SIMPLEST)
If Stage 4 handles detector mapping through join operations (which it does), then Stage 3's reconciliation is optional for pipeline execution. It's a "nice-to-have" for keeping YAML in sync, not a requirement.

**My Recommendation: Option C - Remove Stage 3**
- Simpler pipeline flow
- YAML reconciliation can happen in Shiny app when user adds/removes data sources
- Pipeline assumes YAML is correct (user's responsibility via Shiny)

---

## Major Finding: 180+ Lines of Duplicated Code

### Duplication Pattern 1: YAML Loading & Validation Setup
**Impact: 60 lines across 3 scripts**

#### Current State (Duplicated 3 times)
```r
# run_ingest_standardize.R:204-236
yaml_path <- here::here("inst", "config", "study_parameters.yaml")
checkpoint_dir <- here::here("outputs", "checkpoints")
outputs_dir <- here::here("outputs")

assert_file_exists(yaml_path, hint = "Configure study parameters...")
study_params <- load_study_parameters(yaml_path)

validation_context <- create_validation_context(workflow = "ingest")
validation_context$study_name <- study_params$study_parameters$study_name

# run_cpn_template.R:214-237 - IDENTICAL
# run_finalize_to_report.R:268-309 - IDENTICAL
```

#### Recommended: Create Utility Function
```r
# Add to utilities.R
setup_pipeline_context <- function(workflow_name, verbose = FALSE) {
  yaml_path <- here::here("inst", "config", "study_parameters.yaml")
  
  assert_file_exists(
    yaml_path,
    hint = "Configure study parameters in Shiny app first."
  )
  
  study_params <- load_study_parameters(yaml_path)
  
  validation_context <- create_validation_context(workflow = workflow_name)
  validation_context$study_name <- study_params$study_parameters$study_name
  
  list(
    yaml_path = yaml_path,
    study_params = study_params,
    validation_context = validation_context,
    checkpoint_dir = here::here("outputs", "checkpoints"),
    outputs_dir = here::here("outputs")
  )
}

# Usage in each run_* script:
ctx <- setup_pipeline_context("ingest", verbose = verbose)
study_params <- ctx$study_params
validation_context <- ctx$validation_context
# ...
```

**Savings: 60 lines**

---

### Duplication Pattern 2: Checkpoint File Loading
**Impact: 45 lines across 2+ scripts**

#### Current State (Duplicated)
```r
# run_cpn_template.R:315-329
checkpoint_dir <- here::here("outputs", "checkpoints")
assert_directory_exists(checkpoint_dir)

checkpoint_files <- list.files(
  checkpoint_dir,
  pattern = "02_kpro_master_.*\\.csv$",
  full.names = TRUE
)

if (length(checkpoint_files) == 0) {
  stop("No kpro_master data available. Run Chunk 1 first.")
}

checkpoint_file <- checkpoint_files[length(checkpoint_files)]
kpro_master <- safe_read_csv(checkpoint_file)

# Similar pattern in run_finalize_to_report.R for template files
```

#### Recommended: Create Utility Function
```r
# Add to utilities.R
load_most_recent_checkpoint <- function(pattern, 
                                        checkpoint_dir = NULL,
                                        error_hint = "Run previous chunk first") {
  checkpoint_dir <- checkpoint_dir %||% here::here("outputs", "checkpoints")
  assert_directory_exists(checkpoint_dir)
  
  files <- list.files(checkpoint_dir, pattern = pattern, full.names = TRUE)
  
  if (length(files) == 0) {
    stop(sprintf(
      "No checkpoint files found matching pattern: %s\n  %s",
      pattern, error_hint
    ))
  }
  
  most_recent <- files[length(files)]
  
  if (verbose) {
    message(sprintf("  [OK] Loading checkpoint: %s", basename(most_recent)))
  }
  
  safe_read_csv(most_recent)
}

# Usage:
kpro_master <- load_most_recent_checkpoint(
  pattern = "02_kpro_master_.*\\.csv$",
  error_hint = "Run Chunk 1 first"
)
```

**Savings: 45 lines**

---

### Duplication Pattern 3: Timestamped Filename Generation
**Impact: 30 lines across 5+ locations**

#### Current State (Repeated 5+ times)
```r
# run_ingest_standardize.R:~650
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
checkpoint_filename <- sprintf("02_kpro_master_%s.csv", timestamp)

# run_cpn_template.R:603
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
original_filename <- sprintf("03_CallsPerNight_Template_ORIGINAL_%s.csv", timestamp)

# run_cpn_template.R:612
edit_filename <- sprintf("03_CallsPerNight_Template_EDIT_THIS_%s.csv", timestamp)

# run_cpn_template.R:630
artifact_id_original <- sprintf("cpn_template_original_%s", timestamp)

# ... and more
```

#### Recommended: Create Utility Function
```r
# Add to utilities.R
generate_timestamped_filename <- function(prefix, 
                                           suffix = "", 
                                           extension = ".csv",
                                           format = "%Y%m%d_%H%M%S",
                                           separator = "_") {
  timestamp <- format(Sys.time(), format)
  
  parts <- c(prefix, timestamp, suffix)
  parts <- parts[parts != ""]  # Remove empty parts
  
  base_name <- paste(parts, collapse = separator)
  paste0(base_name, extension)
}

# Usage:
checkpoint_filename <- generate_timestamped_filename("02_kpro_master")
# → "02_kpro_master_20260201_170830.csv"

original_filename <- generate_timestamped_filename(
  "03_CallsPerNight_Template", 
  suffix = "ORIGINAL"
)
# → "03_CallsPerNight_Template_20260201_170830_ORIGINAL.csv"

artifact_id <- generate_timestamped_filename(
  "cpn_template_original",
  extension = ""  # No extension for IDs
)
# → "cpn_template_original_20260201_170830"
```

**Savings: 30 lines**

---

### Duplication Pattern 4: Schedule Parameter Extraction
**Impact: 20 lines**

#### Current State (Duplicated in 2 scripts)
```r
# run_cpn_template.R:491-504
recording_start_for_template <- study_params$processing_options$recording_start %||% "18:00:00"
recording_end <- study_params$processing_options$recording_end %||% "07:00:00"

advanced_scheduling_raw <- study_params$processing_options$advanced_scheduling
is_advanced_scheduling <- if (is.null(advanced_scheduling_raw)) {
  FALSE
} else if (is.logical(advanced_scheduling_raw)) {
  advanced_scheduling_raw
} else if (is.character(advanced_scheduling_raw)) {
  tolower(advanced_scheduling_raw) %in% c("yes", "true", "1")
} else {
  FALSE
}

# run_finalize_to_report.R:312-325 - Similar pattern
```

#### Recommended: Create Utility Function
```r
# Add to utilities.R
get_schedule_config <- function(study_params, 
                                defaults = list(
                                  recording_start = "18:00:00",
                                  recording_end = "07:00:00",
                                  advanced_scheduling = FALSE,
                                  intended_hours = 13
                                )) {
  opts <- study_params$processing_options
  
  # Extract with defaults
  recording_start <- opts$recording_start %||% defaults$recording_start
  recording_end <- opts$recording_end %||% defaults$recording_end
  intended_hours <- opts$intended_hours %||% defaults$intended_hours
  
  # Normalize advanced_scheduling to logical
  advanced_raw <- opts$advanced_scheduling %||% defaults$advanced_scheduling
  advanced_scheduling <- if (is.logical(advanced_raw)) {
    advanced_raw
  } else if (is.character(advanced_raw)) {
    tolower(advanced_raw) %in% c("yes", "true", "1")
  } else {
    FALSE
  }
  
  list(
    recording_start = recording_start,
    recording_end = recording_end,
    advanced_scheduling = advanced_scheduling,
    intended_hours = intended_hours
  )
}

# Usage:
schedule <- get_schedule_config(study_params)
recording_start <- schedule$recording_start
is_advanced <- schedule$advanced_scheduling
```

**Savings: 20 lines**

---

### Duplication Pattern 5: Species Column Creation
**Impact: 20 lines**

#### Current State (Duplicated in 2 scripts)
```r
# run_cpn_template.R:366-378
kpro_master <- kpro_master %>%
  dplyr::mutate(
    species = dplyr::case_when(
      !is.na(manual_id) & manual_id != "" & 
        manual_id != "NoID" & manual_id != "UNKNOWN" ~ manual_id,
      !is.na(auto_id) & auto_id != "" & 
        auto_id != "NoID" & auto_id != "UNKNOWN" ~ auto_id,
      TRUE ~ "NoID"
    )
  )

# run_finalize_to_report.R - Similar pattern
```

#### Recommended: Create Utility Function
```r
# Add to utilities.R
create_unified_species_column <- function(data, 
                                          manual_col = "manual_id",
                                          auto_col = "auto_id",
                                          output_col = "species") {
  
  is_valid <- function(x) {
    !is.na(x) & x != "" & x != "NoID" & x != "UNKNOWN"
  }
  
  data %>%
    dplyr::mutate(
      !!output_col := dplyr::case_when(
        manual_col %in% names(.) & is_valid(.data[[manual_col]]) ~ .data[[manual_col]],
        auto_col %in% names(.) & is_valid(.data[[auto_col]]) ~ .data[[auto_col]],
        TRUE ~ "NoID"
      )
    )
}

# Usage:
kpro_master <- create_unified_species_column(kpro_master)
```

**Savings: 20 lines**

---

## Total Duplication Savings Summary

| Utility Function | Lines Saved | Impact |
|------------------|-------------|--------|
| setup_pipeline_context() | 60 | HIGH - Used in all 3 orchestrators |
| load_most_recent_checkpoint() | 45 | MEDIUM - Used in 2+ scripts |
| generate_timestamped_filename() | 30 | MEDIUM - Used 5+ times |
| get_schedule_config() | 20 | LOW - Used in 2 scripts |
| create_unified_species_column() | 20 | LOW - Used in 2 scripts |
| **TOTAL** | **175 lines** | **20-30% reduction** |

---

## Truly Unused Functions

### Category 1: Legacy Checkpoint Loaders (5 functions)
These were designed for the old 01-07 workflow scripts but are not used in the new run_* orchestrators:

| Function | File | Status |
|----------|------|--------|
| `load_or_checkpoint()` | utilities.R:~300 | ❌ Never called |
| `load_intro_standardized()` | utilities.R:~350 | ❌ Never called |
| `load_master_data()` | utilities.R:~400 | ⚠️ Only in legacy 07_generate_report.R |
| `load_cpn_final()` | utilities.R:~450 | ❌ Never called |
| `load_cpn_template_original()` | utilities.R:~500 | ❌ Never called |

**Why unused:** The new `run_*` orchestrators integrate all stages and return results directly rather than loading from checkpoints.

**Recommendation:** 
- Keep for backward compatibility if anyone uses legacy 01-07 scripts
- Add `@keywords internal` or deprecation note
- Document as "Legacy - use run_* orchestrators instead"

---

### Category 2: Validation (1 function)

| Function | File | Status |
|----------|------|--------|
| `require_study_parameters()` | validation.R:~150 | ❌ Never called |

**Why unused:** Replaced by `load_study_parameters()` + `assert_file_exists()` pattern

**Recommendation:** Remove (redundant)

---

### Category 3: Schema Detection (1 function)

| Function | File | Status |
|----------|------|--------|
| `validate_schema_detection()` | schema_detection.R:~200 | ❌ Never called |

**Why unused:** Schema validation happens at enforcement stage via `enforce_unified_schema()`

**Recommendation:** Mark as `@keywords internal` or remove

---

### Category 4: Artifacts (2 functions)

| Function | File | Status |
|----------|------|--------|
| `hash_dataframe()` | artifacts.R:~350 | ❌ Never called |
| `validate_rds_structure()` | artifacts.R:~400 | ❌ Awaits Chunk 3 |

**Why unused:**
- `hash_dataframe()`: Designed for provenance but never implemented
- `validate_rds_structure()`: Will be used in Chunk 3 (run_finalize_to_report)

**Recommendation:** 
- Remove `hash_dataframe()` if not needed
- Keep `validate_rds_structure()` for Chunk 3

---

## Action Plan

### Phase 1: Revert Problematic Integration (CRITICAL)
- [ ] Remove Stage 3 from run_ingest_standardize.R
- [ ] Renumber stages back (4→3, 5→4, 6→5, 7→6, 8→7, 9→8)
- [ ] Update all documentation
- [ ] Document ensure_study_parameters() as "for Shiny app use only"

### Phase 2: Create High-Value Utilities (HIGH IMPACT)
- [ ] Add setup_pipeline_context() to utilities.R
- [ ] Add load_most_recent_checkpoint() to utilities.R
- [ ] Add generate_timestamped_filename() to utilities.R
- [ ] Update all run_* scripts to use new utilities
- [ ] Test each script after changes

### Phase 3: Create Schedule & Species Utilities (MEDIUM IMPACT)
- [ ] Add get_schedule_config() to utilities.R
- [ ] Add create_unified_species_column() to utilities.R
- [ ] Update run_cpn_template and run_finalize_to_report

### Phase 4: Document Unused Functions (LOW PRIORITY)
- [ ] Add "LEGACY" section to utilities.R header
- [ ] Add deprecation notes to checkpoint loaders
- [ ] Mark internal functions with @keywords internal
- [ ] Consider removing truly unused functions

---

## Estimated Impact

**Before:**
- ensure_study_parameters() integration: Adds complexity, questionable value
- Duplicated code: 180+ lines across orchestrators
- Unused functions: 9 functions exported but never called

**After:**
- Revert Stage 3: Cleaner pipeline flow
- New utilities: 5 functions (+50 lines)
- Replace duplicated code: (-180 lines)
- **Net reduction: 130 lines (10-15% of orchestrator code)**
- Better maintainability and reusability

---

## Conclusion

The critical finding is that **ensure_study_parameters() integration should be reverted**. While the function itself is useful, its placement as Stage 3 adds complexity without clear benefit and violates design principles.

The major opportunity is **consolidating duplicated code into 5 new utility functions**, which would reduce orchestrator code by 175 lines and improve maintainability.

The 9 unused functions should be documented as legacy or removed to reduce codebase maintenance burden.
