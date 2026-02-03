# Feature Parity Audit Report
## run_finalize_to_report.R (Chunk 3) vs Legacy Workflows 04-07

**Generated**: 2026-02-03  
**Standards Reference**: 00_STANDARDS_INDEX.md, 04_data_standards.md, 05_logging_console_standards.md

---

## 1. Summary

Chunk 3 (`run_finalize_to_report.R`) consolidates the functionality of four legacy workflows:
- `04_finalize_cpn.R` - CPN template processing and status classification
- `05_summary_stats.R` - Summary statistics generation
- `06_exploratory_plots.R` - Plot generation (26 total)
- `07_generate_report.R` - Quarto report rendering and release bundle

After this audit, Chunk 3 is **fully compliant** with legacy functionality, with the following patches applied.

---

## 2. Features Restored (Patches Applied)

### 2.1 Data Validation

| Feature | Origin | Patch Location | Standard Applied |
|---------|--------|----------------|------------------|
| Suspicious call values validation | 04_finalize_cpn.R ~L560 | Lines 620-649 | 04_data_standards.md §4.3 |
| Metadata element in all_summaries | 05_summary_stats.R | Lines 855-865 | 07_artifact_release_standards.md |
| WF05 result storage | 05_summary_stats.R | Lines 897-909 | 01_architecture_standards.md |
| RDS structure validation | 07_generate_report.R L318 | Lines 1152-1182 | 07_artifact_release_standards.md |

### 2.2 Warning Handling

| Warning | Origin | Patch Location | Solution |
|---------|--------|----------------|----------|
| "standard deviation is zero" | plot_detector.R | Lines 572-608 | Check SD before cor(), excludes constant-value detectors |
| "'from' must be a finite number" | plot_quality.R | Lines 819-833 | Handle all-NA Night values with fallback plot |
| "'from' must be a finite number" | plot_temporal.R | Lines 453-468 | Handle all-NA CallsPerHour with fallback plot |
| Missing values in geom_line() | plot_temporal.R | Lines 122-140 | Filter NA values before plotting |

---

## 3. Features Already Present (No Changes Needed)

| Feature | Chunk 3 Location | Status |
|---------|------------------|--------|
| Duplicate row removal | Lines 374-456 | ✅ Complete |
| Safe type conversion | Lines 378-424 | ✅ Complete |
| Datetime handling | Lines 426-448 | ✅ Complete |
| Species column validation | Lines 360-363 | ✅ Complete |
| Dead nights retention | Lines 589-594 | ✅ Complete |
| Status classification | Lines 583-594 | ✅ Complete |
| Artifact registry | Lines 635-651 | ✅ Complete |
| Validation context tracking | Multiple locations | ✅ Complete |

---

## 4. Features NOT Restored (Obsolete in 3-Chunk Model)

These features from legacy workflows are **intentionally excluded** from Chunk 3:

### 4.1 Interactive Prompts

| Feature | Legacy Location | Reason for Exclusion |
|---------|-----------------|---------------------|
| `readline()` for template selection | 04_finalize_cpn.R L~300-400 | Replaced by `edited_template_file` parameter |
| `menu()` for file selection | 04_finalize_cpn.R | Replaced by automatic file discovery |
| Manual confirmation prompts | Various | Shiny app handles user interaction |

### 4.2 Redundant Loading/Validation

| Feature | Legacy Location | Reason for Exclusion |
|---------|-----------------|---------------------|
| Raw data quality checks | WF01-02 | Already done in Chunk 1 |
| Master schema validation | WF02 | Delegated to Chunk 1 |
| Species column creation | WF03 | Delegated to Chunk 2 |

---

## 5. Standards Compliance Matrix

| Patch | 01_architecture | 02_documentation | 03_code_design | 04_data | 05_logging | 06_quarto | 07_artifact |
|-------|----------------|------------------|----------------|---------|------------|-----------|-------------|
| Call validation | ✓ | - | ✓ | ✓ | ✓ | - | - |
| SD=0 check | - | ✓ | ✓ | ✓ | - | - | - |
| NA filtering | - | - | ✓ | ✓ | - | - | - |
| Metadata | ✓ | - | - | - | - | - | ✓ |
| RDS validation | - | - | ✓ | ✓ | - | - | ✓ |

---

## 6. Warning Resolution Details

### 6.1 Duplicate Rows Removed

**Location**: `run_finalize_to_report.R` Lines 374-456

**Solution**: Uses `dplyr::distinct(Detector, Night, .keep_all = TRUE)` on both ORIGINAL and EDIT_THIS templates with diagnostic count reporting.

```r
n_orig_removed <- n_orig_before - n_orig_after
if (n_orig_removed > 0) {
  message(sprintf("Removed %d duplicate rows from ORIGINAL template", n_orig_removed))
}
```

### 6.2 Quality Plots Failed: 'from' must be a finite number

**Location**: `plot_quality.R` Lines 819-833, `plot_temporal.R` Lines 453-468

**Root Cause**: `seq(min(x), max(x))` or `scale_y_continuous(limits = range(x))` when all x values are NA.

**Solution**: Check for valid data before computing ranges, return fallback plot if insufficient.

```r
valid_nights <- calls_per_night$Night[!is.na(calls_per_night$Night)]
if (length(valid_nights) == 0) {
  warning("No valid Night values available for heatmap")
  return(ggplot() + annotate("text", ...))
}
```

### 6.3 Correlation Warning: Standard Deviation is Zero

**Location**: `plot_detector.R` Lines 572-608

**Root Cause**: `cor()` produces warnings when any column has zero variance (constant values).

**Solution**: Check SD before correlation, exclude zero-variance detectors with warning.

```r
detector_sds <- sapply(detector_data, function(x) sd(x, na.rm = TRUE))
zero_sd_detectors <- names(detector_sds[is.na(detector_sds) | detector_sds == 0])
if (length(zero_sd_detectors) > 0) {
  warning(sprintf("Detector(s) with zero variance excluded: %s", ...))
}
cor_matrix <- suppressWarnings(cor(...))
```

### 6.4 Missing Values Outside geom_line() / geom_col()

**Location**: `plot_temporal.R` Lines 122-140

**Solution**: Filter NA values before passing to ggplot.

```r
plot_data <- calls_per_night %>%
  dplyr::filter(!is.na(CallsPerNight), !is.na(Night))
```

---

## 7. Changelog

- **2026-02-03**: Initial audit and patches applied
  - Added suspicious call value validation (Lines 620-649)
  - Added SD=0 protection to correlation heatmap (plot_detector.R)
  - Added NA/Inf edge case handling to plot functions
  - Added metadata element to all_summaries
  - Added WF05 result storage
  - Added RDS structure validation in Stage 22

---

## 8. Files Modified

1. `R/pipeline/run_finalize_to_report.R`
   - Lines 620-649: Suspicious call validation
   - Lines 855-865: Metadata element
   - Lines 897-909: WF05 result storage
   - Lines 1152-1182: RDS validation

2. `R/functions/output/plot_detector.R`
   - Lines 572-608: SD=0 protection for correlation heatmap

3. `R/functions/output/plot_quality.R`
   - Lines 819-833: NA Night handling for heatmap

4. `R/functions/output/plot_temporal.R`
   - Lines 122-140: NA filtering for activity plot
   - Lines 453-468: NA handling for CPH distribution
