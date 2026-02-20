# ==============================================================================
# TABLE IMPROVEMENTS ANALYSIS
# ==============================================================================
# VERSION: 1.0
# DATE: 2026-02-19
# PURPOSE: Cross-reference user improvement notes with existing implementation
# COMPANION TO: TABLES_ECOSYSTEM_ANALYSIS.md
# ==============================================================================

## EXECUTIVE SUMMARY

This document analyzes your personal table improvement notes against the current GT table implementation to provide specific, actionable recommendations. One of your requests (hourly peak highlighting) is **already implemented** in the current codebase.

**Status Overview:**
- ✅ **ALREADY DONE:** Hourly Activity peak hour highlighting (gold background + bold)
- 🔄 **QUICK WIN:** Remove interpretation column from variance table (1 line change)
- 🔄 **MODERATE:** Detector Activity header rewording (requires consensus on terminology)
- 🔄 **COMPREHENSIVE:** Aesthetic improvements across all tables (color palette, spacing, fonts)

---

## 1. YOUR IMPROVEMENT REQUESTS (ANNOTATED)

### 1.1 Detector Activity Summary - Header Clarity

**Your Note:**
> "Detector Activity Summary: Headers need to be more interpretive/report-ready"

**Current Implementation:**
```r
# Current column labels (tables.R:160-168)
gt::cols_label(
  Detector = "**Detector**",
  n_nights = "Nights",
  total_hours = "Total Hrs",
  mean_hours = "Mean Hrs",
  pct_success = "Success %",
  total_calls = "Total Calls",
  mean_cph = "Mean CPH",
  median_cph = "Median CPH",
  sd_cph = "SD",
  cv_pct = "CV %",
  pct_zero = "Zero %"
)
```

**Analysis:**
- Current headers are **compact** and **technically accurate**
- Abbreviations: "CPH" (Calls Per Hour), "CV" (Coefficient of Variation), "SD" (Standard Deviation)
- Tradeoff: Verbosity vs. horizontal space in table

**Proposed Improvements:**

#### Option A: Subtle Clarification (Minimal Changes)
```r
gt::cols_label(
  Detector = "**Detector**",
  # Effort Metrics
  n_nights = "Nights Sampled",
  total_hours = "Total Hours",
  mean_hours = "Avg. Hours/Night",
  pct_success = "Detection Success %",
  # Activity Metrics
  total_calls = "Total Calls",
  mean_cph = "Mean Calls/Hour",
  median_cph = "Median Calls/Hour",
  # Variability Metrics
  sd_cph = "Std. Deviation",
  cv_pct = "Variability (CV%)",
  pct_zero = "Silent Nights %"
)
```

**Changes:**
- ✅ "Nights Sampled" → clarifies n_nights is sample count
- ✅ "Avg. Hours/Night" → clearer than "Mean Hrs"
- ✅ "Detection Success %" → interprets pct_success meaning
- ✅ "Mean/Median Calls/Hour" → expands CPH in context
- ✅ "Silent Nights %" → more interpretive than "Zero %"
- ✅ "Variability (CV%)" → explains coefficient of variation

#### Option B: Maximum Clarity (Report-Ready)
```r
gt::cols_label(
  Detector = "**Detector Site**",
  # Effort
  n_nights = "Number of Nights",
  total_hours = "Total Recording Hours",
  mean_hours = "Average Hours per Night",
  pct_success = "Bat Detection Success Rate",
  # Activity
  total_calls = "Total Bat Calls",
  mean_cph = "Average Call Rate (calls/hr)",
  median_cph = "Median Call Rate (calls/hr)",
  # Variability
  sd_cph = "Call Rate Std. Deviation",
  cv_pct = "Coefficient of Variation (%)",
  pct_zero = "Proportion of Silent Nights (%)"
)
```

**Tradeoffs:**
- ✅ Maximum interpretability for non-technical stakeholders
- ⚠️ Longer headers may cause wrapping or horizontal scroll
- ⚠️ Less compact for presentations

**Recommendation:** **Option A (Subtle Clarification)**
- Balances clarity with space efficiency
- Maintains professional aesthetics
- Still self-explanatory to report readers

---

### 1.2 Variance Table - Remove Interpretation Column

**Your Note:**
> "Variance table: Remove interpretation column"

**Current Implementation:**
```r
# From summarization.R:599 - calculate_variance_components() returns:
tibble::tibble(
  var_total = round(var_total, 2),
  var_between = round(var_between, 2),
  var_within = round(var_within, 2),
  pct_between = round(100 * var_between / var_total, 1),
  pct_within = round(100 * var_within / var_total, 1),
  icc = round(icc, 3),
  interpretation = interpretation  # ← REMOVE THIS
)
```

**Analysis:**
- `interpretation` column auto-generates text based on ICC thresholds:
  - ICC ≥ 0.75: "Very high spatial heterogeneity..."
  - ICC ≥ 0.50: "High spatial heterogeneity..."
  - ICC ≥ 0.25: "Moderate spatial heterogeneity..."
  - ICC ≥ 0.10: "Low spatial heterogeneity..."
  - ICC < 0.10: "Very low spatial heterogeneity..."
- **Issue:** Pre-baked interpretation limits reader's own analysis
- **Better:** Let ICC value speak for itself, or add interpretation in report narrative

**Proposed Fix:**
Remove `interpretation` from the tibble output:

```r
# summarization.R:595-607 (SIMPLIFIED)
tibble::tibble(
  var_total = round(var_total, 2),
  var_between = round(var_between, 2),
  var_within = round(var_within, 2),
  pct_between = round(100 * var_between / var_total, 1),
  pct_within = round(100 * var_within / var_total, 1),
  icc = round(icc, 3)
  # interpretation removed
)
```

**Impact:**
- ✅ Cleaner table output (no opinionated text column)
- ✅ ICC value is sufficient for statistical interpretation
- ✅ Report author can interpret in narrative context
- ⚠️ Remove interpretation logic entirely OR preserve in function comments as guidance

**Status:** **READY TO IMPLEMENT** (1 line deletion in summarization.R)

---

### 1.3 Hourly Activity - Highlight Peak Hour

**Your Note:**
> "Hourly Activity: Highlight peak hour"

**Current Implementation:**
```r
# tables.R:843-877 - format_hourly_summary_gt()

# Identify peak hour(s)
peak_rows <- display_df$n_calls == max(display_df$n_calls, na.rm = TRUE)

# Apply peak highlighting (if any peak hours exist)
if (any(peak_rows)) {
  gt_table <- gt_table %>%
    # Bold text for peak hours
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = peak_rows)
    ) %>%
    # Low alpha highlight background for peak hours
    gt::tab_style(
      style = gt::cell_fill(color = "#FFD70040"),  # Gold with 25% opacity
      locations = gt::cells_body(rows = peak_rows)
    )
}
```

**Analysis:**
- ✅ **ALREADY IMPLEMENTED** as of current codebase
- ✅ Gold background (#FFD70040) with 25% opacity for subtlety
- ✅ Bold text for peak hour rows
- ✅ Handles ties (multiple hours with same max calls)

**Status:** ✅ **COMPLETE - NO ACTION NEEDED**

**Visual Effect:**
- Peak hour row(s) stand out with soft gold tint
- Bold text reinforces emphasis
- Maintains table readability (low alpha prevents overwhelming)

---

### 1.4 General Aesthetics: Colors, Spacing, Fonts

**Your Note:**
> "General aesthetics: soft/easy colors across tables, spacing/formatting improvements, font size adjustments, header boldness"

**Current Aesthetic Baseline:**

#### 1.4.1 Color Palette (tables.R - all format_*_gt functions)

**Current Colors:**
```r
# Header background
gt::cell_fill(color = "#f0f0f0")  # Light gray (96% white)

# Peak hour highlight (hourly table only)
gt::cell_fill(color = "#FFD70040")  # Gold at 25% opacity

# Borders
table.border.top.color = "#333333"     # Dark gray (almost black)
table.border.bottom.color = "#333333"
heading.border.bottom.color = "#666666"  # Medium gray
```

**Analysis:**
- ✅ Current palette is professional and minimalist
- ✅ Gray headers (#f0f0f0) provide subtle visual separation
- ✅ Alternating row stripes (via `opt_row_striping()`) aid readability
- ⚠️ Borders are sharp (#333333) - could soften

**Proposed Soft Palette:**
```r
# Headers: Softer blue-gray
gt::cell_fill(color = "#e8f0f7")  # Very light blue-gray (calming, professional)

# Borders: Softer grays
table.border.top.color = "#9CA3AF"        # Soft slate gray
table.border.bottom.color = "#9CA3AF"
heading.border.bottom.color = "#D1D5DB"   # Lighter slate gray

# Peak hour highlight: Keep gold but slightly softer
gt::cell_fill(color = "#FCD34D30")  # Amber/gold at 19% opacity

# Spanner backgrounds (NEW): Subtle color-coding by section
# Effort metrics: Soft blue
gt::tab_style(
  style = gt::cell_fill(color = "#DBEAFE20"),  # Blue tint at 13% opacity
  locations = gt::cells_column_spanners(spanners = "**Effort**")
)

# Activity metrics: Soft green
gt::tab_style(
  style = gt::cell_fill(color = "#D1FAE520"),  # Green tint at 13% opacity
  locations = gt::cells_column_spanners(spanners = "**Activity**")
)

# Variability metrics: Soft amber
gt::tab_style(
  style = gt::cell_fill(color = "#FEF3C720"),  # Amber tint at 13% opacity
  locations = gt::cells_column_spanners(spanners = "**Variability**")
)
```

**Color Psychology:**
- **Blue (#DBEAFE)**: Trust, calmness, reliability → Effort metrics
- **Green (#D1FAE5)**: Growth, activity, vitality → Activity metrics
- **Amber (#FEF3C7)**: Caution, variability, attention → Variability metrics
- **Blue-gray headers (#e8f0f7)**: Professional, neutral, easy on eyes

#### 1.4.2 Spacing & Formatting

**Current Implementation:**
```r
# tables.R - all format_*_gt functions
gt::tab_options(
  table.font.size = gt::px(11),        # Body text
  heading.title.font.size = gt::px(16),  # Main title
  heading.subtitle.font.size = gt::px(12),  # Subtitle (if present)
  column_labels.font.size = gt::px(11)  # Column headers
)

# Row striping enabled
gt::opt_row_striping()
```

**Proposed Improvements:**

```r
gt::tab_options(
  # Font sizing (slightly larger for readability)
  table.font.size = gt::px(12),        # +1px for body (easier reading)
  heading.title.font.size = gt::px(18),  # +2px for titles (more prominent)
  heading.subtitle.font.size = gt::px(13),  # +1px for subtitle
  column_labels.font.size = gt::px(11),  # Keep compact
  
  # Spacing improvements
  data_row.padding = gt::px(8),        # More breathing room (default ~5px)
  column_labels.padding = gt::px(10),  # Spacious headers
  heading.padding = gt::px(12),        # Title padding
  
  # Row striping (keep enabled, already good)
  row_striping.include_table_body = TRUE
)
```

**Spacing Rationale:**
- ✅ `data_row.padding = 8px` prevents cramped rows (especially with 12px font)
- ✅ `column_labels.padding = 10px` makes headers more prominent
- ✅ `heading.padding = 12px` separates title from table body

#### 1.4.3 Font Weights & Boldness

**Current Implementation:**
```r
# Detector column values (detector summary table)
gt::tab_style(
  style = gt::cell_text(weight = "bold"),
  locations = gt::cells_body(columns = Detector)
)

# Column spanners (already bold via markdown)
gt::tab_spanner(label = gt::md("**Effort**"), ...)

# Column labels (already bold via styling)
gt::tab_style(
  style = gt::cell_text(weight = "bold"),
  locations = gt::cells_column_labels()
)

# Peak hour rows (hourly table)
gt::tab_style(
  style = gt::cell_text(weight = "bold"),
  locations = gt::cells_body(rows = peak_rows)
)
```

**Analysis:**
- ✅ Strategic boldness in current implementation:
  - Detector names (left anchor column)
  - Column headers (structural emphasis)
  - Column spanners (section grouping)
  - Peak hours (data emphasis)
- ⚠️ Could extend boldness to other "anchor" columns (e.g., species codes)

**Proposed Extensions:**
```r
# Bold "Hour" column in hourly summary (currently not bold)
gt::tab_style(
  style = gt::cell_text(weight = "bold"),
  locations = gt::cells_body(columns = Hour)
)

# Bold species codes in species summary (monospace + bold)
gt::tab_style(
  style = list(
    gt::cell_text(weight = "bold", font = "monospace")
  ),
  locations = gt::cells_body(columns = species)
)

# Optional: Semi-bold for numeric emphasis (600 weight instead of 700)
gt::tab_style(
  style = gt::cell_text(weight = 600),  # Semi-bold for subtle emphasis
  locations = gt::cells_body(columns = c(mean_cph, total_calls))
)
```

---

## 2. CROSS-REFERENCE WITH TABLES_ECOSYSTEM_ANALYSIS.md

### 2.1 DRY Violations Still Relevant

**From TABLES_ECOSYSTEM_ANALYSIS.md Section 2.2.1:**
> **VIOLATION: Input validation boilerplate duplicated 4 times**
> Total duplication: ~25 lines × 4 functions = 100 lines

**Impact on Your Improvements:**
- ✅ Aesthetic changes will need to be applied to **4 separate functions**
- ⚠️ Without DRY refactoring, color/spacing changes must be manually replicated
- 💡 **Recommendation:** Extract `apply_kpro_gt_theme()` helper BEFORE aesthetic overhaul

**Proposed Workflow:**
1. Extract shared GT theme function (saves 100-120 lines)
2. Apply your aesthetic preferences ONCE in theme function
3. All 4 tables inherit changes automatically

### 2.2 GT Export Usage

**From TABLES_ECOSYSTEM_ANALYSIS.md Section 3.2:**
> **Report Independence:**
> - ✅ Report loads RDS archive (efficient)
> - ✅ GT formatting happens inline in Quarto (flexibility)
> - ⚠️ Pre-generated PNG/HTML GT exports unused by report (disk waste?)

**Your Aesthetic Changes Impact:**
- 🔄 PNG/HTML exports in `results/figures/` will reflect new styling
- ⚠️ If these files are unused, aesthetic improvements are invisible
- 💡 **Clarification Needed:** Are you using pre-generated PNG/HTML files elsewhere (e.g., presentations, lab reports)?

**Decision Point:**
- **If YES (you use PNG/HTML):** Aesthetic improvements have immediate visual impact
- **If NO (unused):** Consider disabling PNG/HTML exports to save disk space (see ST_data_standards.md)

---

## 3. IMPLEMENTATION ROADMAP

### Phase 1: Quick Wins (15 minutes)
1. ✅ **Remove interpretation column** from variance_components (1 line in summarization.R)
2. ✅ **Verify hourly peak highlighting** works in your outputs (already implemented)

### Phase 2: Header Clarity (30 minutes)
1. 🔄 **Update Detector Activity headers** (choose Option A or B from Section 1.1)
2. 🔄 Apply header changes to `format_detector_summary_gt()` in tables.R

### Phase 3: Extract GT Theme (1-2 hours, foundational)
1. 🔄 **Create `apply_kpro_gt_theme()` helper function**
   - Consolidates color palette, spacing, font sizes, borders
   - Accepts parameters: title, subtitle, enable_row_striping, etc.
2. 🔄 **Refactor 4 format_*_gt() functions** to call theme helper
3. ✅ **Verify outputs unchanged** (regression test)

### Phase 4: Aesthetic Overhaul (1-2 hours)
1. 🔄 **Update `apply_kpro_gt_theme()` with soft palette**
   - Blue-gray headers (#e8f0f7)
   - Softer borders (#9CA3AF)
   - Increased padding (8px rows, 10px headers)
   - Larger fonts (+1-2px)
2. 🔄 **Add spanner color-coding** (optional)
   - Soft blue for Effort, green for Activity, amber for Variability
3. 🔄 **Test with actual data** (run Phase 3 Module 5)
4. 🔄 **Review PNG/HTML outputs** (if used)

### Phase 5: Documentation (30 minutes)
1. 🔄 **Update TABLES_ECOSYSTEM_ANALYSIS.md** with new aesthetic standards
2. 🔄 **Add color palette to ST_documentation_standards.md** (if not present)
3. 🔄 **Document theme function usage** in tables.R header

---

## 4. SPECIFIC CODE CHANGES READY FOR REVIEW

### 4.1 Remove Interpretation Column (READY NOW)

**File:** `R/functions/analysis/summarization.R`  
**Line:** 595-607  
**Change:** Delete `interpretation = interpretation` from tibble output

```diff
calculate_variance_components <- function(cpn_final) {
  # ... calculation logic ...
  
  tibble::tibble(
    var_total = round(var_total, 2),
    var_between = round(var_between, 2),
    var_within = round(var_within, 2),
    pct_between = round(100 * var_between / var_total, 1),
    pct_within = round(100 * var_within / var_total, 1),
-   icc = round(icc, 3),
-   interpretation = interpretation
+   icc = round(icc, 3)
  )
}
```

**Testing:** Verify variance_components CSV/Excel sheet has 6 columns (not 7)

---

### 4.2 Detector Activity Header Clarity (OPTION A - Recommended)

**File:** `R/functions/output/tables.R`  
**Line:** 160-168  
**Change:** Apply subtle clarifications to column labels

```diff
gt::cols_label(
  Detector = gt::md("**Detector**"),
- n_nights = "Nights",
- total_hours = "Total Hrs",
- mean_hours = "Mean Hrs",
- pct_success = "Success %",
+ n_nights = "Nights Sampled",
+ total_hours = "Total Hours",
+ mean_hours = "Avg. Hours/Night",
+ pct_success = "Detection Success %",
  total_calls = "Total Calls",
- mean_cph = "Mean CPH",
- median_cph = "Median CPH",
+ mean_cph = "Mean Calls/Hour",
+ median_cph = "Median Calls/Hour",
- sd_cph = "SD",
- cv_pct = "CV %",
- pct_zero = "Zero %"
+ sd_cph = "Std. Deviation",
+ cv_pct = "Variability (CV%)",
+ pct_zero = "Silent Nights %"
)
```

**Testing:** Check detector_summary PNG/HTML for horizontal overflow (if present, revert to shorter variants)

---

### 4.3 Soft Color Palette (AFTER THEME EXTRACTION)

**File:** `R/functions/output/tables.R`  
**Function:** `apply_kpro_gt_theme()` (NEW - to be created)  

```r
#' Apply KPro GT Table Theme
#'
#' @description
#' Applies consistent styling to all GT summary tables: soft color palette,
#' professional spacing, and accessibility-friendly fonts.
#'
#' @param gt_table gt object to style
#' @param title Character. Table title (NULL = no title)
#' @param subtitle Character. Subtitle (NULL = no subtitle)
#' @param enable_row_striping Logical. Alternating row colors? Default: TRUE
#'
#' @return Styled gt object
#'
#' @details
#' **Color Palette:**
#' - Headers: Soft blue-gray (#e8f0f7)
#' - Borders: Muted slate gray (#9CA3AF, #D1D5DB)
#' - Highlights: Context-dependent (handled by calling function)
#'
#' **Typography:**
#' - Body: 12px
#' - Headers: 11px (compact)
#' - Title: 18px
#'
#' **Spacing:**
#' - Row padding: 8px (comfortable)
#' - Header padding: 10px
#' - Title padding: 12px
#'
#' @export
apply_kpro_gt_theme <- function(gt_table, 
                                title = NULL, 
                                subtitle = NULL,
                                enable_row_striping = TRUE) {
  
  # Apply title/subtitle if provided
  if (!is.null(title)) {
    gt_table <- gt_table %>%
      gt::tab_header(
        title = gt::md(paste0("**", title, "**")),
        subtitle = subtitle
      )
  }
  
  # Core styling
  gt_table <- gt_table %>%
    # Header styling (soft blue-gray background)
    gt::tab_style(
      style = list(
        gt::cell_fill(color = "#e8f0f7"),  # Soft blue-gray
        gt::cell_text(weight = "bold")
      ),
      locations = gt::cells_column_labels()
    ) %>%
    
    # Table-wide options
    gt::tab_options(
      # Typography
      table.font.size = gt::px(12),        # +1px from original
      heading.title.font.size = gt::px(18),  # +2px from original
      heading.subtitle.font.size = gt::px(13),  # +1px from original
      column_labels.font.size = gt::px(11),
      
      # Spacing
      data_row.padding = gt::px(8),        # More breathing room
      column_labels.padding = gt::px(10),
      heading.padding = gt::px(12),
      
      # Borders (softer grays)
      table.border.top.style = "solid",
      table.border.top.width = gt::px(2),
      table.border.top.color = "#9CA3AF",  # Muted slate
      table.border.bottom.style = "solid",
      table.border.bottom.width = gt::px(2),
      table.border.bottom.color = "#9CA3AF",
      heading.border.bottom.style = "solid",
      heading.border.bottom.width = gt::px(1),
      heading.border.bottom.color = "#D1D5DB"  # Lighter slate
    )
  
  # Row striping (optional)
  if (enable_row_striping) {
    gt_table <- gt_table %>% gt::opt_row_striping()
  }
  
  gt_table
}
```

**Usage Example (in `format_detector_summary_gt`):**
```r
format_detector_summary_gt <- function(detector_summary,
                                       title = "Detector Activity Summary",
                                       subtitle = NULL) {
  # ... input validation ...
  # ... data selection ...
  
  gt_table <- display_df %>%
    gt::gt() %>%
    apply_kpro_gt_theme(title = title, subtitle = subtitle) %>%  # Apply theme
    
    # Table-specific styling (spanners, labels, formatting)
    gt::tab_spanner(...) %>%
    gt::cols_label(...) %>%
    # ... rest of function ...
}
```

---

## 5. QUESTIONS FOR YOU (DESIGN DECISIONS)

### 5.1 Header Clarity: Option A or B?
- **Option A (Subtle):** "Avg. Hours/Night", "Silent Nights %", "Detection Success %"
- **Option B (Maximum):** "Average Hours per Night", "Proportion of Silent Nights (%)", "Bat Detection Success Rate"

**My Recommendation:** Option A (balances clarity with space efficiency)

### 5.2 Spanner Color-Coding: Add or Skip?
- **Add:** Soft blue (Effort), green (Activity), amber (Variability) tints at 13% opacity
- **Skip:** Keep current gray headers for uniform look

**My Recommendation:** Add (helps readers mentally group related metrics, very subtle)

### 5.3 PNG/HTML Exports: Keep or Disable?
- **Keep:** You use pre-generated figures for presentations/reports outside Quarto
- **Disable:** Save disk space, only generate GT inline in Quarto reports

**Need Your Input:** Are you actively using files in `results/figures/`?

### 5.4 Variance Interpretation: Delete or Relocate?
- **Delete Logic Entirely:** Remove ICC interpretation from codebase
- **Relocate to Comments:** Keep interpretation thresholds as code comments for reference

**My Recommendation:** Relocate to comments (preserves domain knowledge without polluting output)

---

## 6. NEXT STEPS

**Awaiting Your Decisions:**
1. Approve header wording (Option A vs B)
2. Confirm spanner color-coding preference
3. Clarify PNG/HTML export usage

**Ready to Implement Now:**
1. ✅ Remove interpretation column from variance table (1 line)
2. ✅ Update detector activity headers (once you choose option)

**After Theme Extraction:**
1. 🔄 Apply soft color palette globally
2. 🔄 Test all 4 table outputs
3. 🔄 Update documentation

**Would you like me to:**
- A) Implement Quick Wins (variance interpretation removal) immediately?
- B) Wait for your design decisions on headers/colors?
- C) Start with GT theme extraction (foundational refactor)?
