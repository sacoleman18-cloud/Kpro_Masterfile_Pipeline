# Function Integration Guide
**Quick Reference for Integrating Unused Functions**

---

## 🔴 HIGH PRIORITY: ensure_study_parameters()

### What It Does
One-call function to:
1. Create YAML template if missing
2. Extract detector IDs from raw data
3. Reconcile detector mappings (add new, preserve existing, remove old)
4. Validate final structure

### Where to Integrate
**File**: `R/pipeline/run_ingest_standardize.R`  
**Location**: Stage 1 - after loading and combining raw data

### Code Snippet
```r
# In run_ingest_standardize.R, after Stage 1 (around line 240)
# After: raw_combined <- bind_rows(local_data, external_data)

# ===========================================================================
# STAGE 1B: ENSURE YAML PARAMETERS & RECONCILE DETECTORS
# ===========================================================================

if (verbose) print_stage_header("1B", "Validate & Reconcile Configuration")

# Ensure YAML exists and detector mappings are synchronized
ensure_study_parameters(
  raw_data = raw_combined,
  yaml_path = yaml_path
)

validation_context <- log_validation_event(
  validation_context,
  event_type = "config_reconciled",
  description = "Detector mappings reconciled with YAML",
  details = list(
    n_detectors = length(unique(raw_combined$detector_id))
  )
)

if (verbose) message("  [OK] YAML validated and detector mappings reconciled")

log_message("[Stage 1B] Configuration validated")

# Then continue with Stage 2 (Schema Detection)
```

### Benefits
- ✅ Auto-creates YAML template on first run
- ✅ Automatically adds new detector IDs discovered in data
- ✅ Preserves user-entered detector names from previous runs
- ✅ Removes obsolete detector IDs no longer in data
- ✅ Validates YAML structure before workflow continues

---

## 🟡 MEDIUM PRIORITY: validate_study_config()

### What It Does
Validates YAML structure has all required fields before saving

### Where to Integrate
**File**: Shiny app configuration save handler  
**Location**: Before calling `save_study_parameters()`

### Code Snippet
```r
# In Shiny app (wherever that is)
observeEvent(input$save_config_btn, {
  
  # Build configuration from UI inputs
  cfg <- build_study_config(
    study_name = input$study_name,
    start_date = as.character(input$start_date),
    end_date = as.character(input$end_date),
    detector_mapping = detector_ids,  # from reactive values
    processing_options = list(
      advanced_scheduling = input$use_advanced_scheduling,
      recording_start = input$recording_start,
      recording_end = input$recording_end,
      intended_hours = input$intended_hours
    )
  )
  
  # Validate structure BEFORE saving
  tryCatch(
    {
      validate_study_config(cfg)
      save_study_parameters(cfg)
      showNotification("Configuration saved successfully!", type = "message")
    },
    error = function(e) {
      showNotification(
        paste("Configuration invalid:", e$message),
        type = "error",
        duration = 10
      )
    }
  )
})
```

### Benefits
- ✅ Catches missing required fields before save
- ✅ Prevents corrupt YAML files
- ✅ Clear error messages in Shiny UI

---

## ℹ️ OPTIONAL: Pre-Flight Validation in run_* Scripts

### What It Does
Validates all required config keys exist before running expensive operations

### Where to Integrate
**Files**: All `R/pipeline/run_*.R` orchestrators  
**Location**: Early (Stage 1 or 2), after loading YAML

### Code Snippet
```r
# In any run_* function, after loading study_params

# ===========================================================================
# STAGE 1B: VALIDATE REQUIRED CONFIG KEYS
# ===========================================================================

if (verbose) print_stage_header("1B", "Validate Configuration")

# Define required keys for this workflow
required_config <- list(
  "study_parameters.study_name" = "Study name",
  "study_parameters.start_date" = "Study start date",
  "study_parameters.end_date" = "Study end date",
  "processing_options.recording_start" = "Recording start time",
  "processing_options.recording_end" = "Recording end time"
)

# Helper function to get nested config value
get_nested <- function(config, path) {
  parts <- strsplit(path, "\\.")[[1]]
  val <- config
  for (part in parts) {
    val <- val[[part]]
    if (is.null(val)) return(NULL)
  }
  val
}

# Check each required key
missing_keys <- c()
for (key in names(required_config)) {
  val <- get_nested(study_params, key)
  if (is.null(val) || (is.character(val) && val == "")) {
    missing_keys <- c(missing_keys, sprintf("  - %s (%s)", key, required_config[[key]]))
  }
}

if (length(missing_keys) > 0) {
  stop(sprintf(
    "Required configuration keys missing or empty:\n%s\n\nPlease configure in Shiny app or edit inst/config/study_parameters.yaml",
    paste(missing_keys, collapse = "\n")
  ))
}

if (verbose) message("  [OK] All required configuration keys present")

log_message("[Stage 1B] Configuration validated")
```

### Benefits
- ✅ Fail fast with clear error messages
- ✅ Prevents partial execution with missing config
- ✅ Better user experience (actionable errors)

---

## 📊 FUTURE: Chunk 3 Functions (awaiting run_finalize_to_report)

These functions are defined and ready but waiting for orchestrator implementation:

### Analysis Functions
- `calculate_summary_statistics()` - aggregate metrics
- `calculate_detector_summary()` - per-detector stats
- `calculate_species_summary()` - per-species stats
- `calculate_nightly_summary()` - temporal patterns
- `calculate_quality_metrics()` - data completeness

### Output Functions
- All plotting functions (34 functions)
  - `plot_temporal_*()` - time series plots
  - `plot_detector_*()` - detector-specific visualizations
  - `plot_species_*()` - species distribution plots
  - `plot_quality_*()` - data quality visualizations
- All GT table functions (5 functions)
- `render_quarto_report()` - final HTML report generation

**Status**: ✅ These will be integrated when `run_finalize_to_report()` is implemented

---

## Integration Testing

After integrating any of the above functions, run this checklist:

### Test: ensure_study_parameters()
```r
# 1. Delete existing YAML
unlink("inst/config/study_parameters.yaml")

# 2. Run Chunk 1 (should auto-create YAML)
result <- run_ingest_standardize(verbose = TRUE)

# 3. Verify YAML was created
stopifnot(file.exists("inst/config/study_parameters.yaml"))

# 4. Check detector mappings
cfg <- yaml::read_yaml("inst/config/study_parameters.yaml")
stopifnot(!is.null(cfg$study_parameters$detector_mapping))
```

### Test: validate_study_config()
```r
# Test invalid config (should error)
bad_cfg <- list(config_version = 1)
expect_error(validate_study_config(bad_cfg))

# Test valid config (should pass)
good_cfg <- build_study_config(
  study_name = "Test",
  start_date = "2025-01-01",
  end_date = "2025-12-31",
  detector_mapping = c("ABC123" = "Detector 1")
)
expect_silent(validate_study_config(good_cfg))
```

---

## Quick Reference Table

| Function | Priority | File to Edit | Stage | Lines to Add |
|----------|----------|--------------|-------|--------------|
| ensure_study_parameters | 🔴 HIGH | run_ingest_standardize.R | After Stage 1 | ~20 |
| validate_study_config | 🟡 MED | Shiny app | Save handler | ~5 |
| Pre-flight validation | ℹ️ OPT | All run_*.R | Stage 1B | ~30 |

---

**Integration Priority Order:**
1. Fix Stage 5 bug (✅ DONE)
2. Add ensure_study_parameters() to run_ingest_standardize
3. Add validate_study_config() to Shiny save handler
4. Add pre-flight validation to run_* scripts (optional but recommended)
5. Implement run_finalize_to_report() to use analysis/output functions
