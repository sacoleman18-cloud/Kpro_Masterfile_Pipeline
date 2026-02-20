# ==============================================================================
# TABLE ECOSYSTEM: ARCHITECTURE ANALYSIS & DRY EVALUATION
# ==============================================================================
# VERSION: 1.0
# DATE: 2026-02-19
# PURPOSE: Comprehensive analysis of summary statistics and GT table pipeline
# ==============================================================================

## EXECUTIVE SUMMARY

This document provides an in-depth analysis of the KPro Masterfile Pipeline's table generation ecosystem, including DRY (Don't Repeat Yourself) evaluation, architectural considerations, and improvement recommendations.

**Scope:** Summary statistics generation → CSV export → Excel compilation → GT formatting → Report integration

**Key Finding:** The table pipeline is well-architected with strong separation of concerns, but contains moderate DRY violations in GT formatting functions and configuration handling that could be consolidated.

---

## 1. ARCHITECTURE OVERVIEW

### 1.1 Data Flow

```
Phase 3 → Module 5 (summary_stats.R)
    ↓
[1] Summary Generation (summarization.R)
    ↓
[2] CSV Export (save_summary_csv)
    ↓
[3] Excel Compilation (build_excel_from_summaries)
    ↓
[4] GT Formatting (format_*_gt functions)
    ↓
[5] PNG/HTML Export (save_gt_table)
    ↓
[6] RDS Archive (saveRDS all_summaries)
    ↓
[7] Report Consumption (bat_activity_report.qmd)
```

### 1.2 Component Ownership

| Component | File | Lines | Role | Layer |
|-----------|------|-------|------|-------|
| Orchestration | `R/modules/summary_stats.R` | 685 | Phase 3 Module 5 | Module (Layer 8) |
| Statistics | `R/functions/analysis/summarization.R` | 877 | Pure calculation | Utility (Layer 1-6) |
| Formatting | `R/functions/output/tables.R` | 1371 | GT styling + I/O | Utility (Layer 6) |
| Report | `reports/bat_activity_report.qmd` | 468 | Quarto template | Report |

### 1.3 Key Design Decisions

**CSV-First Architecture:**
- ✅ CSV files are source of truth
- ✅ Each CSV independently hashed and registered
- ✅ Excel compiled FROM CSVs (not parallel generation)
- ⚠️ GT tables generated from tibbles (not CSVs) - minor inconsistency

**Separation of Concerns:**
- ✅ `summarization.R`: Pure calculation (tibbles out)
- ✅ `tables.R`: Pure formatting (GT objects out)
- ✅ `summary_stats.R`: Orchestration + I/O + registration

**Report Independence:**
- ✅ Report loads RDS archive (efficient)
- ✅ GT formatting happens inline in Quarto (flexibility)
- ⚠️ Pre-generated PNG/HTML GT exports unused by report (disk waste?)

---

## 2. DRY ANALYSIS

### 2.1 Summary Statistics Generation (summarization.R)

**DRY Score: 9/10 (Excellent)**

**Positive Patterns:**
- ✅ Each summary function has single responsibility
- ✅ Zero parameter redundancy (all deterministic)
- ✅ Consistent validation patterns using centralized helpers
- ✅ No logic duplication between functions

**Minor Repetition:**
```r
# Pattern repeated 5 times across functions:
validate_master_data(master_data)
assert_columns_exist(master_data, c("column1", "column2"))
```

**Recommendation:** Consider a `validate_summary_input()` helper:
```r
validate_summary_input <- function(data, required_cols) {
  validate_master_data(data)
  assert_columns_exist(data, required_cols)
}

# Usage:
validate_summary_input(master_data, c("Detector", "species"))
```

**Impact:** Minor - would save ~15 lines across 5 functions, improves consistency.

---

### 2.2 GT Formatting Functions (tables.R)

**DRY Score: 6/10 (Moderate violations)**

#### 2.2.1 Header Validation Repetition

**VIOLATION: Input validation boilerplate duplicated 4 times**

```r
# Pattern in format_detector_summary_gt():
if (!is.data.frame(detector_summary)) {
  stop("detector_summary must be a data frame")
}
required_cols <- c("Detector", "mean_cph", "total_calls", ...)
missing_cols <- setdiff(required_cols, names(detector_summary))
if (length(missing_cols) > 0) {
  stop(sprintf(
    "detector_summary is missing required columns: %s\nDid you use create_detector_activity_summary()?",
    paste(missing_cols, collapse = ", ")
  ))
}

# REPEATED in format_species_summary_gt()
# REPEATED in format_study_summary_gt()
# REPEATED in format_hourly_summary_gt()
```

**Total Duplication:** ~25 lines × 4 functions = 100 lines of redundant validation code

**Recommendation:** Extract to shared validator:
```r
validate_summary_for_gt <- function(df, required_cols, arg_name, source_function) {
  if (!is.data.frame(df)) {
    stop(sprintf("%s must be a data frame", arg_name))
  }
  
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "%s is missing required columns: %s\nDid you use %s()?",
      arg_name,
      paste(missing_cols, collapse = ", "),
      source_function
    ))
  }
  
  invisible(TRUE)
}

# Usage:
validate_summary_for_gt(
  detector_summary,
  required_cols = c("Detector", "mean_cph", "total_calls"),
  arg_name = "detector_summary",
  source_function = "create_detector_activity_summary"
)
```

**Impact:** High - would eliminate 80-100 lines, improve maintainability significantly.

#### 2.2.2 GT Styling Boilerplate Repetition

**VIOLATION: Common GT styling patterns repeated across 4 functions**

```r
# Repeated pattern in all format_*_gt() functions:
gt_table %>%
  gt::tab_header(
    title = gt::md(paste0("**", title, "**")),
    subtitle = subtitle
  ) %>%
  gt::tab_style(
    style = list(
      gt::cell_fill(color = "#f0f0f0"),
      gt::cell_text(weight = "bold")
    ),
    locations = gt::cells_column_labels()
  ) %>%
  gt::tab_options(
    table.font.size = gt::px(11),
    heading.title.font.size = gt::px(16),
    table.border.top.style = "solid",
    table.border.top.width = gt::px(2),
    table.border.bottom.style = "solid",
    table.border.bottom.width = gt::px(2)
  )
```

**Total Duplication:** ~30 lines × 4 functions = 120 lines

**Recommendation:** Extract styling pipeline functions:
```r
apply_kpro_gt_theme <- function(gt_table, title = NULL, subtitle = NULL) {
  if (!is.null(title)) {
    gt_table <- gt_table %>%
      gt::tab_header(
        title = gt::md(paste0("**", title, "**")),
        subtitle = subtitle
      )
  }
  
  gt_table %>%
    gt::tab_style(
      style = list(
        gt::cell_fill(color = "#f0f0f0"),
        gt::cell_text(weight = "bold")
      ),
      locations = gt::cells_column_labels()
    ) %>%
    gt::tab_options(
      table.font.size = gt::px(11),
      heading.title.font.size = gt::px(16),
      table.border.top.style = "solid",
      table.border.top.width = gt::px(2),
      table.border.bottom.style = "solid",
      table.border.bottom.width = gt::px(2)
    )
}

# Usage:
detector_summary %>%
  gt::gt() %>%
  # ... specific column formatting ...
  apply_kpro_gt_theme(title = "Detector Activity Summary")
```

**Impact:** High - would eliminate 100+ lines, ensure consistent styling, make theme changes trivial.

#### 2.2.3 Column Formatting Patterns

**MODERATE VIOLATION: Similar fmt_* patterns**

```r
# Percentage formatting repeated 3 times:
gt::fmt_number(columns = pct_success, decimals = 1, pattern = "{x}%")
gt::fmt_number(columns = pct_partial, decimals = 1, pattern = "{x}%")
gt::fmt_number(columns = pct_fail, decimals = 1, pattern = "{x}%")

# Could be:
fmt_as_percent <- function(gt_table, columns, decimals = 1) {
  gt::fmt_number(gt_table, columns = {{columns}}, decimals = decimals, pattern = "{x}%")
}
```

**Impact:** Low - only saves ~10-15 lines, but improves readability.

---

### 2.3 Module Orchestration (summary_stats.R)

**DRY Score: 7/10 (Moderate violations)**

#### 2.3.1 Configuration Checking Repetition

**VIOLATION: `should_export()` check repeated 15+ times**

```r
# Pattern repeated for every artifact export:
if (should_export("csv_detector_summary")) {
  # ... export logic ...
}

if (should_export("csv_study_summary")) {
  # ... export logic ...
}

# 15+ occurrences of identical if-pattern
```

**Impact:** Low - this is reasonable given different export logic per artifact.

**Alternative Consideration:** Table-driven approach:
```r
export_configs <- list(
  list(
    key = "csv_detector_summary",
    data = all_summaries$detector_summary,
    filename = "detector_summary_%s.csv",
    artifact_name = "csv_detector_summary_%s",
    sheet_name = "Detector Summary"
  ),
  # ... other configs ...
)

for (config in export_configs) {
  if (should_export(config$key)) {
    export_csv_artifact(config, timestamp, registry)
  }
}
```

**Recommendation:** Stick with current explicit pattern - more readable for this use case.

#### 2.3.2 GT Export Pattern Repetition

**VIOLATION: GT export blocks duplicated 4 times**

```r
# Repeated for detector/study/species/hourly:
if (!is.null(all_summaries$detector_summary)) {
  if (has_webshot2 && should_export("png_detector_summary")) {
    tryCatch({
      detector_gt <- format_detector_summary_gt(all_summaries$detector_summary)
      save_gt_table(detector_gt, sprintf("detector_summary_%s", timestamp_05), 
                    output_dir = table_output_dir, format = "png")
      png_exports <- png_exports + 1
    }, error = function(e) {
      warning(sprintf("Failed to export detector activity PNG: %s", e$message))
    })
  }
  
  if (should_export("html_detector_summary")) {
    tryCatch({
      detector_gt <- format_detector_summary_gt(all_summaries$detector_summary)
      save_gt_table(detector_gt, sprintf("detector_summary_%s", timestamp_05), 
                    output_dir = table_output_dir, format = "html")
      html_exports <- html_exports + 1
    }, error = function(e) {
      warning(sprintf("Failed to export detector activity HTML: %s", e$message))
    })
  }
}
```

**Total Duplication:** ~25 lines × 4 tables = 100 lines

**Recommendation:** Extract GT export helper:
```r
export_gt_table <- function(summary_data, summary_name, format_function, 
                            config_key_prefix, timestamp, output_dir,
                            has_webshot2, exports_counter) {
  if (is.null(summary_data)) return(exports_counter)
  
  formats <- c("png", "html")
  for (fmt in formats) {
    if (fmt == "png" && !has_webshot2) next
    
    config_key <- sprintf("%s_%s", fmt, config_key_prefix)
    if (!should_export(config_key)) next
    
    tryCatch({
      gt_table <- format_function(summary_data)
      save_gt_table(
        gt_table,
        sprintf("%s_%s", summary_name, timestamp),
        output_dir = output_dir,
        format = fmt
      )
      exports_counter[[fmt]] <- exports_counter[[fmt]] + 1
    }, error = function(e) {
      warning(sprintf("Failed to export %s %s: %s", summary_name, fmt, e$message))
    })
  }
  
  exports_counter
}

# Usage:
exports <- list(png = 0, html = 0)
exports <- export_gt_table(
  all_summaries$detector_summary,
  "detector_summary",
  format_detector_summary_gt,
  "detector_summary",
  timestamp_05,
  table_output_dir,
  has_webshot2,
  exports
)
```

**Impact:** High - would eliminate 80-100 lines, improve error handling consistency.

---

### 2.4 Report Integration (bat_activity_report.qmd)

**DRY Score: 8/10 (Good)**

**Positive Patterns:**
- ✅ Programmatic plot iteration (purrr::iwalk)
- ✅ Helper functions (`snake_to_title`, `make_caption`)
- ✅ Conditional rendering pattern

**Minor Repetition:**
```r
# Pattern repeated 4 times for plot sections:
purrr::iwalk(all_plots$quality, function(plot_obj, plot_name) {
  cat(sprintf("\n\n## %s\n\n", snake_to_title(plot_name)))
  print(plot_obj)
  cat(sprintf("\n\n*%s*\n\n", make_caption(plot_name, "quality")))
})
```

**Recommendation:** Already optimal for Quarto context - extracting would reduce readability.

---

## 3. ARCHITECTURAL CONSIDERATIONS

### 3.1 Data Source Architecture: Multi-Cache Decision Analysis

**The Question:** At each export stage, what should be the source of truth?

#### 3.1.1 Data Sources Available

During Module 5 execution, we have multiple representations of the same data:

| Source | Format | Availability | Size | Read Speed | Integrity |
|--------|--------|--------------|------|-----------|-----------|
| **In-memory tibbles** | R data.frame | During execution only | ~1-2 MB RAM | Instant | ✅ Source of truth |
| **RDS archive** | Compressed R binary | After Stage 16 | ~500 KB - 2 MB | Fast (~0.1s) | ✅ Exact R object |
| **CSV files** | Plain text | After Stage 13 | ~3-5 KB each | Slow (~0.01s each) | ✅ Registered SHA256 |
| **Excel workbook** | Binary spreadsheet | After Stage 14 | ~50-100 KB | Medium (~0.5s) | ⚠️ Derived |
| **GT PNG/HTML** | Rendered tables | After Stage 15 | ~200-400 KB each | N/A (not re-read) | ⚠️ Derived |

#### 3.1.2 Decision Points & Options

**DECISION POINT 1: CSV Export (Stage 13)**

*Question:* What generates the CSV files?

| Option | Source | Pros | Cons | Current? |
|--------|--------|------|------|----------|
| A | In-memory tibbles | ✅ Fast<br>✅ No intermediate I/O | ⚠️ Can't validate CSV write<br>⚠️ No integrity check | ✅ **YES** |
| B | RDS archive | ✅ Validates RDS first | ❌ Must write RDS before CSV<br>❌ Slower<br>❌ Wrong order | ❌ No |

**Analysis:** Option A is correct - CSV is the first serialization, written directly from in-memory tibbles.

---

**DECISION POINT 2: Excel Workbook (Stage 14)**

*Question:* What source does Excel read from?

| Option | Source | Pros | Cons | Current? |
|--------|--------|------|------|----------|
| A | In-memory tibbles | ✅ Fastest (no file I/O)<br>✅ No CSV parsing overhead<br>✅ Preserves R data types<br>✅ Parallel export with CSV | ⚠️ Excel could differ from CSV exports if writes diverge | ✅ **YES** |
| B | CSV files (registered) | ✅ Excel guaranteed identical to CSV exports | ⚠️ Re-reads files (~0.05s overhead)<br>⚠️ CSV parse overhead<br>⚠️ Type coercion issues<br>⚠️ Unnecessary I/O | ❌ No (Legacy) |
| C | RDS archive | ✅ Fast binary read<br>✅ Preserves R types | ❌ Must write RDS before Excel<br>❌ Wrong execution order | ❌ No |

**Analysis:** Option A (current) writes Excel directly from the in-memory tibbles, parallel to CSV export. Both CSV and Excel are independent serializations of the same source data, written simultaneously.

**Benefits:**
- Faster: No file I/O for re-reading (~50ms saved)
- Better data types: Dates remain dates, not strings
- Simpler: Single data flow from tibbles
- Parallel exports: CSV and Excel both written from same source

**Tradeoff:** 
- CSV and Excel are independent exports (both from tibbles)
- If one write fails, the other succeeds (isolated failures)
- No guarantee they're "identical" but they derive from same source

---

**DECISION POINT 3: GT PNG/HTML Export (Stage 15)**

*Question:* What source does GT formatting read from?

| Option | Source | Pros | Cons | Current? |
|--------|--------|------|------|----------|
| A | In-memory tibbles | ✅ Fastest<br>✅ No file I/O<br>✅ Preserves R data types | ⚠️ Could differ from CSV if CSV corrupt | ✅ **YES** |
| B | CSV files | ✅ Validates CSV integrity<br>✅ GT matches CSV exports | ❌ Loses data types (dates → strings)<br>❌ Slower<br>❌ Must parse all CSVs | ❌ No |
| C | RDS archive | ✅ Fast<br>✅ Preserves R types | ❌ Must write RDS before GT<br>❌ Wrong execution order | ❌ No |

**Analysis:** Option A (current) is optimal for GT exports during Module 5 execution. GT tables are **presentation artifacts**, not data artifacts, so they don't need to validate CSV integrity.

**Tradeoff:** GT exports show the "intended" data (from tibbles), not the "persisted" data (from CSVs). If CSV write fails, GT would still render correctly, masking the failure.

---

**DECISION POINT 4: Report GT Rendering (Report Execution)**

*Question:* What source does the report read from?

| Option | Source | Pros | Cons | Current? |
|--------|--------|------|------|----------|
| A | RDS archive | ✅ Fast (~0.1s)<br>✅ Preserves R types<br>✅ Single file load<br>✅ All summaries together | ⚠️ Report shows RDS, not CSV | ✅ **YES** |
| B | CSV files | ✅ Report validates CSV integrity<br>✅ Universal format | ❌ Must read 5-6 files<br>❌ Lose data types<br>❌ Slower (~0.3s)<br>❌ Must handle missing files | ❌ No |
| C | Pre-rendered GT HTML | ✅ No computation needed | ❌ Fixed formatting<br>❌ Large files<br>❌ No customization<br>❌ 8+ file reads | ❌ No |
| D | Excel workbook | ✅ Validates Excel integrity | ❌ Requires openxlsx<br>❌ Reads Excel in report (!)<br>❌ Slower<br>❌ Loses R types | ❌ No |

**Analysis:** Option A (current) is strongly preferred - RDS is the **report cache**, optimized for this exact use case.

**Tradeoff:** Report rendering is decoupled from CSV/Excel exports. If RDS is corrupt but CSV is fine, report fails. However, RDS is more reliable than CSV (binary format, less prone to encoding issues).

---

#### 3.1.3 Consistency Guarantees

**Current Architecture:**

```
In-memory tibbles (T0 - ground truth during execution)
    ├─→ CSV export [written from T0]
    ├─→ Excel workbook [written from T0] ← Parallel to CSV
    ├─→ GT formatting [reads from T0] ← Fast, preserves types
    └─→ RDS archive [writes T0] ← Independent write
            └─→ Report [reads RDS] ← Fast, preserves types
```

**Key Design:** CSV, Excel, and RDS are all **parallel independent exports** from the in-memory tibbles. No re-reading, no sequential dependencies.

**Consistency Model:**
- CSV ≡ T0 serialized to text format
- Excel ≡ T0 serialized to XLSX format (parallel export)
- GT ≡ T0 formatted for presentation
- RDS ≡ T0 serialized to binary format (parallel export)
- Report ≡ RDS (loads binary cache)

**All outputs originate from T0 (in-memory tibbles). Exports are parallel, not sequential.**

**Failure Modes:**
1. **CSV write fails:** Excel/RDS/GT unaffected (isolated failure)
2. **Excel write fails:** CSV/RDS/GT unaffected (isolated failure)
3. **RDS write fails:** Report rendering fails, CSV/Excel/GT unaffected
4. **GT export fails:** Warning logged, other exports continue

**Benefit:** Isolated failures - one export failure doesn't cascade to others

---

#### 3.1.4 Alternative Architectures

**OPTION 1: Full Validation Chain (Maximum Integrity)**

```
Tibbles → CSV → Read CSV → Excel
            ↓
          Read CSV → GT formatting
            ↓
          Read CSV → RDS archive → Report
```

**Pros:** Every export validates CSV integrity  
**Cons:** 4x file I/O overhead, loses R data types everywhere, ~200ms slower  
**Use Case:** When CSV is the legal/regulatory source of truth

---

**OPTION 2: Cache-First (Maximum Performance)**

```
Tibbles → RDS archive
            ├─→ Read RDS → CSV export
            ├─→ Read RDS → Excel compilation
            ├─→ Read RDS → GT formatting
            └─→ Report [reads RDS]
```

**Pros:** Single write, all reads from RDS (fast, preserves types)  
**Cons:** CSV/Excel are derived from RDS (not validated), RDS becomes single point of failure  
**Use Case:** When RDS is source of truth (internal R workflows)

---

**OPTION 3: Hybrid (Current + Validation)**

```
Tibbles → CSV + RDS (parallel writes)
            │       │
            │       └─→ Report [reads RDS]
            ↓
          Read CSV → validate → Excel
          Read CSV → validate → GT formatting
```

**Pros:** Fast report (RDS), validated exports (CSV), catches write failures  
**Cons:** More complex, GT formatting slower  
**Use Case:** When both external consumers (CSV) and reports (RDS) matter

---

#### 3.1.5 Recommendations by Priority

**If CSV is source of truth for external stakeholders:**
- ✅ Keep Excel reading from CSV (current)
- Consider: GT formatting from CSV (validates integrity)
- Consider: Report shows CSV validation status

**If RDS is source of truth for internal reporting:**
- ✅ Keep report reading from RDS (current)
- ✅ Keep GT formatting from tibbles (current)
- Consider: Excel from tibbles (faster, no validation benefit)

**If performance is critical:**
- Consider: Remove Excel re-read (saves 50ms)
- Consider: Remove GT exports entirely (saves 3-6s)
- Consider: Async/parallel GT rendering (saves 50%)

**If integrity is critical:**
- Consider: Add CSV validation after write (checksum verify)
- Consider: GT formatting from CSV (validates consistency)
- Consider: Report loads CSV for comparison (shows any RDS drift)

---

#### 3.1.6 Current Architecture Assessment

**Philosophy:** "Tibbles are source of truth during execution, CSV/RDS are persistence layers"

**Strengths:**
- Excel validates CSV integrity (catches write failures)
- Report uses efficient RDS cache (fast, preserves types)
- GT formatting uses tibbles (fast, no I/O)

**Weaknesses:**
- No mechanism to detect CSV/RDS drift
- GT exports could mask CSV corruption
- Excel re-read is only validation point (limited scope)

**Verdict:** **Good hybrid approach** - balances performance (RDS cache) with integrity (Excel validates CSV). Not perfect, but pragmatic.

**Priority Fix:** Add explicit CSV validation after write (checksum + row count match) rather than relying on Excel compilation as indirect validation.

### 3.2 Pre-Generated GT Files vs Inline Report Formatting

**Current:** 
- Module 5 generates PNG/HTML GT exports
- Report performs GT formatting inline (doesn't use pre-generated files)

**Analysis:**
- ✅ Inline formatting allows report customization
- ✅ RDS archive more efficient than loading PNGs
- ⚠️ Pre-generated PNG/HTML files unused (disk waste)
- ⚠️ Two separate GT formatting paths (module vs report)

**Options:**

**Option A: Remove pre-generated GT exports entirely**
```yaml
# In study_parameters.yaml:
artifact_outputs:
  png_detector_summary: no  # Disable standalone exports
  html_detector_summary: no
  # Keep RDS for report
```
**Pro:** Eliminates redundancy, saves disk space  
**Con:** Loses standalone table review capability

**Option B: Report uses pre-generated GT HTML files**
```r
# In report.qmd:
htmltools::includeHTML("results/figures/detector_summary_20260209.html")
```
**Pro:** Single GT formatting path  
**Con:** Less flexible, fixed styling, larger report file

**Option C: Keep current (status quo)**
**Pro:** Maximum flexibility + standalone review  
**Con:** Moderate disk usage (~2-5 MB)

**Recommendation:** **Option A** - disable pre-generated GT exports by default, enable via config flag for special use cases (presentations, publications).

### 3.3 Excel Workbook Value Proposition

**Current:** Multi-sheet XLSX compiled from individual CSVs

**Analysis:**
- ✅ Convenient for users (single file download)
- ✅ Preserves sheet structure from CSV names
- ⚠️ Requires openxlsx dependency
- ⚠️ Adds ~10-20 MB to outputs
- ⚠️ Compilation step adds latency (~5-10 seconds)

**Usage Patterns:**
- Primary: Researchers download XLSX for analysis in Excel/R
- Secondary: Release bundle includes both CSVs and XLSX

**Recommendation:** Keep Excel workbook, but:
1. Make it truly optional via config (currently defaults enabled)
2. Document that CSVs are source of truth (XLSX is convenience copy)
3. Consider lazy loading in Shiny app (generate on-demand)

### 3.4 Summary Function Determinism

**Current:** All `create_*_summary()` functions have zero parameters

**Analysis:**
- ✅ Perfect determinism (same input always → same output)
- ✅ Eliminates "what-if" logic complexity
- ✅ Clear contract documentation
- ⚠️ Inflexible for edge cases (e.g., exclude specific detectors)

**Edge Case Example:**
```r
# What if user wants to exclude malfunctioning detector?
detector_summary <- create_detector_activity_summary(cpn_final) %>%
  filter(Detector != "BadDetector")  # Post-hoc filtering
```

**Alternative:**
```r
create_detector_activity_summary(cpn_final, exclude_detectors = c("BadDetector"))
```

**Recommendation:** Keep zero-parameter design for pipeline calls. For ad-hoc analysis, users can:
1. Pre-filter input data
2. Post-filter summary tibbles
3. Use dplyr verbs directly instead of summary functions

### 3.5 Metadata Proliferation

**Observation:** Metadata attached at multiple levels:
- CSV artifact registration (n_rows, n_cols, n_detectors)
- Excel artifact registration (n_sheets, source_csvs)
- RDS archive (has_species, has_temporal, generated timestamp)
- GT table titles/subtitles

**Analysis:**
- ✅ Rich provenance tracking
- ⚠️ Some redundancy (n_detectors repeated 3 times)
- ⚠️ No central metadata source

**Recommendation:** Consider metadata aggregation helper:
```r
create_summary_metadata <- function(summaries, study_params) {
  list(
    generated = Sys.time(),
    study_name = study_params$study_parameters$study_name,
    n_detectors = n_distinct(summaries$detector_summary$Detector),
    n_nights = nrow(summaries$species_accumulation),
    has_species = !is.null(summaries$species_summary),
    has_temporal = !is.null(summaries$hourly_summary_overall),
    pipeline_version = "2.1"
  )
}

# Reuse across registration calls
metadata <- create_summary_metadata(all_summaries, study_params)
```

---

## 4. CONSOLIDATION OPPORTUNITIES

### 4.1 High-Impact Refactoring

**Priority 1: GT Validation Helper** (tables.R)
- **Lines saved:** 80-100
- **Effort:** 2 hours
- **Risk:** Low

**Priority 2: GT Theme Function** (tables.R)
- **Lines saved:** 100-120
- **Effort:** 3 hours
- **Risk:** Medium (need to test all tables)

**Priority 3: GT Export Helper** (summary_stats.R)
- **Lines saved:** 80-100
- **Effort:** 2 hours
- **Risk:** Low

**Total Potential Savings:** 260-320 lines (~20% reduction in GT code)

### 4.2 Configuration Standardization

**Current:** `artifact_outputs` mixes CSV/PNG/HTML/RDS/XLSX keys

**Proposal:** Nested structure:
```yaml
artifact_outputs:
  summaries:
    detector_summary:
      csv: yes
      png: yes
      html: no
    study_summary:
      csv: yes
      png: no
      html: yes
  compilations:
    excel_workbook: yes
    rds_archive: yes
```

**Benefits:**
- Clearer grouping
- Easier to enable/disable all formats for a summary
- More maintainable in YAML GUI

**Cost:** Migration effort for existing configs

---

## 5. PERFORMANCE ANALYSIS

### 5.1 Execution Time Breakdown (Estimated)

| Stage | Time | Percentage | Bottleneck |
|-------|------|------------|------------|
| Summary generation | 2-5s | 15% | dplyr operations |
| CSV export | 1-2s | 10% | Disk I/O |
| Excel compilation | 5-10s | 40% | openxlsx overhead |
| GT formatting | 3-5s | 20% | GT object creation |
| PNG export | 3-6s | 25% | webshot2 rendering |

**Total:** ~15-30 seconds for full suite

**Optimization Opportunities:**
1. **Excel compilation:** Parallelize sheet creation (4x speedup possible)
2. **PNG export:** Render in background/parallel (2x speedup)
3. **Conditional exports:** Skip disabled formats earlier (20-40% savings)

**Recommendation:** Profile first (may not be needed for current use case).

### 5.2 Memory Footprint

**RDS Archive:** ~500 KB - 2 MB (compressed tibbles)  
**PNG Exports:** ~200-400 KB each × 4 = 800 KB - 1.6 MB  
**Excel Workbook:** ~50-100 KB (small dataset)  
**CSV Suite:** ~50-200 KB total

**Total Disk Usage:** ~2-5 MB per run (acceptable)

---

## 6. TESTING GAPS

### 6.1 Current Testing Coverage

**summarization.R:** Likely 80-90% (mature, stable functions)  
**tables.R:** Likely 40-60% (GT output hard to test programmatically)  
**summary_stats.R:** Likely 50-70% (integration module)

### 6.2 Recommended Test Cases

**Unit Tests Needed:**
```r
test_that("create_detector_activity_summary handles edge cases", {
  # All-success nights
  # All-fail nights
  # Mixed status
  # Single detector
  # Zero calls detector
})

test_that("format_detector_summary_gt validates inputs", {
  # Missing columns
  # Empty data frame
  # NULL input
})

test_that("save_summary_csv handles errors gracefully", {
  # Unwritable directory
  # Disk full simulation
  # Invalid filename characters
})
```

**Integration Tests Needed:**
```r
test_that("summary_stats module produces all expected artifacts", {
  result <- module_summary_stats(test_cpn, test_master, test_params)
  
  expect_true(file.exists(result$summary_stats$summary_rds))
  expect_length(result$artifact_ids, expected = 10)  # 5 CSV + 1 XLSX + 4 GT
  expect_true(all(file.exists(result$summary_stats$files_created)))
})
```

---

## 7. RECOMMENDATIONS SUMMARY

### 7.1 Immediate Actions (High Value, Low Risk)

1. ✅ **COMPLETED: Excel from tibbles (not CSV)** → Saves 50ms, preserves types  
   *Was Priority: High | Effort: 2h | Status: Implemented 2026-02-19*

2. **Extract GT validation helper** → Save 80-100 lines  
   *Priority: High | Effort: 2h | Risk: Low*

3. ✅ **COMPLETED: Extract GT theme function** → Save 100-120 lines  
  *Was Priority: High | Effort: 3h | Status: Implemented 2026-02-20*

4. ✅ **COMPLETED: Disable pre-generated GT exports by default** → Save disk space  
  *Was Priority: Medium | Effort: 30min | Status: Implemented 2026-02-20*

5. **Document parallel export architecture in standards** → Clarify design  
   *Priority: Medium | Effort: 30min | Risk: None*

### 7.2 Medium-Term Actions (Moderate Value)

1. **Extract GT export helper in summary_stats** → Save 80-100 lines  
   *Priority: Medium | Effort: 2h | Risk: Low*

2. **Consolidate metadata creation** → Improve consistency  
   *Priority: Medium | Effort: 2h | Risk: Low*

3. **Add integration tests for Module 5** → Increase reliability  
   *Priority: Medium | Effort: 4h | Risk: None*

### 7.3 Future Considerations (Research Needed)

1. **Parallel Excel/PNG generation** → Performance improvement (if needed)  
   *Priority: Low | Research: 4h | Implementation: 8h*

2. **Nested YAML config structure** → Improved organization  
   *Priority: Low | Migration: 4h | Risk: Medium*

3. **On-demand GT generation in Shiny** → Memory optimization  
   *Priority: Low | Effort: 6h | Risk: Medium*

---

## 8. CONCLUSION

### 8.1 Overall Assessment

**Strengths:**
- ✅ Excellent separation of concerns (calculation vs formatting vs orchestration)
- ✅ Strong determinism in summary functions (zero-parameter design)
- ✅ Parallel export architecture - all outputs from tibbles (no re-reading)
- ✅ Flexible report integration via RDS archive
- ✅ **NEW (2026-02-19):** Excel now writes from tibbles (faster, preserves types)

**Weaknesses:**
- ⚠️ Moderate DRY violations in GT formatting functions (~200 lines duplication)
- ⚠️ Pre-generated GT exports unused by report (disk waste)
- ⚠️ Configuration checking patterns slightly verbose
- ⚠️ Testing coverage likely insufficient for GT functions

**Overall Grade: A- (Excellent with Minor Improvements Needed)**

*Upgraded from B+ after Excel optimization (2026-02-19)*

### 8.2 Prioritization Matrix

```
High Impact ↑
│                    
│  GT Validation     GT Theme
│  Helper            Function
│      ●                ●
│                          
│  GT Export                 Metadata
│  Helper        Config     Consolidation
│      ●         Nesting        ●
│                  ●
└─────────────────────────────────→ Risk →
  Low Risk                    High Risk
```

**Recommended Implementation Order:**
1. GT Validation Helper (2h, high impact, low risk)
2. GT Theme Function (3h, high impact, medium risk)  
3. Disable default GT exports (30min, medium impact, low risk)
4. GT Export Helper (2h, medium impact, low risk)
5. Add integration tests (4h, medium impact, no risk)

**Total Effort:** ~12 hours for all immediate + medium-term actions  
**Expected Benefit:** 260-320 line reduction + improved maintainability + better test coverage

---

## APPENDIX A: CODE METRICS

### Function Complexity (summarization.R)

| Function | Lines | Cyclomatic Complexity | Parameters |
|----------|-------|----------------------|------------|
| `create_detector_activity_summary()` | 85 | 12 | 1 (0 config) |
| `create_study_summary()` | 65 | 8 | 1 (0 config) |
| `create_species_summary_by_detector()` | 35 | 5 | 1 (0 config) |
| `create_species_accumulation_summary()` | 50 | 6 | 1 (0 config) |
| `create_hourly_activity_summary()` | 25 | 3 | 1 (0 config) |

**Assessment:** All functions are maintainable (<100 lines, <15 complexity)

### Function Complexity (tables.R)

| Function | Lines | Cyclomatic Complexity | Parameters |
|----------|-------|----------------------|------------|
| `format_detector_summary_gt()` | 180 | 18 | 3 |
| `format_species_summary_gt()` | 200 | 22 | 5 |
| `format_study_summary_gt()` | 180 | 20 | 4 |
| `format_hourly_summary_gt()` | 150 | 14 | 4 |
| `save_gt_table()` | 120 | 12 | 6 |

**Assessment:** Functions approaching complexity threshold (>20 = refactor needed)

---

## APPENDIX B: DEPENDENCY GRAPH

```
study_parameters.yaml
        ↓
module_summary_stats (orchestrator)
        ├→ create_detector_activity_summary()
        ├→ create_study_summary()
        ├→ create_species_summary_by_detector()
        ├→ create_species_accumulation_summary()
        ├→ create_hourly_activity_summary()
        │       ↓
        ├→ save_summary_csv() × 5
        │       ↓
        ├→ build_excel_from_summaries()
        │       ↓
        ├→ format_detector_summary_gt()
        ├→ format_study_summary_gt()
        ├→ format_species_summary_gt()
        ├→ format_hourly_summary_gt()
        │       ↓
        ├→ save_gt_table() × 8 (PNG + HTML)
        │       ↓
        └→ saveRDS(all_summaries)
                ↓
        bat_activity_report.qmd
                ↓
        final HTML report
```

**Critical Path:** summary generation → RDS archive → report rendering  
**Optional Paths:** CSV export, Excel compilation, GT standalone exports

---

## APPENDIX C: FILE OUTPUT INVENTORY

### Typical Phase 3 Run (9 detectors, 28 nights)

```
results/
├── csv/
│   └── summary_stats/
│       ├── detector_summary_20260209.csv          [✓ Registered, 1.2 KB]
│       ├── study_summary_20260209.csv             [✓ Registered, 0.2 KB]
│       ├── species_summary_20260209.csv           [✓ Registered, 0.9 KB]
│       ├── species_accumulation_20260209.csv      [✓ Registered, 0.2 KB]
│       ├── hourly_summary_overall_20260209.csv    [✓ Registered, 0.2 KB]
│       └── variance_components_20260209.csv       [✓ Registered, 0.2 KB]
├── xlsx/
│   └── summary_stats_20260209.xlsx                [✓ Registered, 16 KB]
├── figures/
│   ├── detector_summary_20260209.png              [⚠️ Unused, 400 KB]
│   ├── detector_summary_20260209.html             [⚠️ Unused, 50 KB]
│   ├── study_summary_20260209.png                 [⚠️ Unused, 200 KB]
│   ├── study_summary_20260209.html                [⚠️ Unused, 30 KB]
│   ├── species_summary_20260209.png               [⚠️ Unused, 300 KB]
│   ├── species_summary_20260209.html              [⚠️ Unused, 40 KB]
│   ├── hourly_summary_overall_20260209.png        [⚠️ Unused, 250 KB]
│   └── hourly_summary_overall_20260209.html       [⚠️ Unused, 35 KB]
├── rds/
│   └── summary_data_20260209.rds                  [✓ Used by report, 1.5 MB]
└── validation/
    └── validation_summary_stats_20260209.html     [✓ QA documentation]

Total: ~4.5 MB (with ~1.3 MB unused GT exports)
```

**Recommendation:** Disable PNG/HTML exports by default → save 30% disk space

---

*End of Document*
