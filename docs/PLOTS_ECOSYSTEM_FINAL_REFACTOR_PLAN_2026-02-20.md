# Final Plot Ecosystem Refactor Plan (Unified Master Deliverable)

Date: 2026-02-20  
Scope: Consolidates and operationalizes
- `docs/PLOTS_ECOSYSTEM_HYPER_ANALYSIS_2026-02-20.md`
- `docs/PLOTS_26_NITTY_GRITTY_PLAYBOOK_2026-02-20.md`
- User review notes (this round)

This is the canonical implementation blueprint for plot ecosystem refactor work.

---

## 1) Goals and Non-Goals

## 1.1 Goals
1. Fix known calculation correctness issues in quality plots.
2. Standardize detector/species palettes and remove ad hoc hard-coded colors.
3. Align plot behavior with a consistent non-fatal error policy and deterministic outputs.
4. Reduce duplication in plot generation and improve maintainability.
5. Add prioritized feature upgrades requested in user notes (species enhancements, labels, consolidation).

## 1.2 Non-Goals (for this phase)
1. Full redesign of report layout.
2. Rewriting all plots into a new framework.
3. Changing core study semantics without config guardrails.

---

## 2) Final Decisions (Merged from Analyses + User Notes)

## 2.1 Palette system
- Implement a detector palette with **16+ visually distinct colors** suitable for publication/reporting.
- Apply detector palette uniformly across all detector-grouped plots.
- Standardize species color behavior so species charts feel coherent.
- For recording-effort heatmap, replace current hard-coded colors with professional **red → yellow → green** gradient.

## 2.2 Quality plot consolidation
- Merge overlapping concepts from:
  - `recording_status_summary`
  - `recording_status_percent`
- Keep one canonical detector status plot that includes:
  - percentages
  - count labels
  - 90% threshold cue

## 2.3 NoID policy direction
- Keep `NoID` proportion plot now.
- Add pipeline/config pathway so `NoID` keep/remove behavior is user-configurable in future-safe way (without breaking master output expectations).

## 2.4 Error policy direction
- Move toward per-plot non-fatal generation policy with failure ledger.
- Continue pipeline execution when individual plots fail, unless explicitly configured as mandatory.

---

## 3) Priority-Ordered Workstreams

## 3.1 P0 (Correctness and trust)
1. Fix `data_completeness_calendar` calculations (currently showing all missing).
2. Fix `missing_nights` calculations (currently implying 100% completeness).
3. Fix `nights_by_detector` logic (currently showing uniform 28 nights incorrectly).
4. Add regression checks for these outputs.

## 3.2 P1 (Visual system consistency + requested behavior)
1. Implement and apply detector palette across all detector-grouped plots.
2. Apply unified palette to requested quality/detector/temporal plots.
3. Replace outlier dual view: keep only “without outlier” presentation for that plot.
4. Add missing legend to synchrony plot.
5. Add week labels on x-axis for weekly activity plot.

## 3.3 P2 (Feature expansion and architecture hardening)
1. Species nightly plot addition.
2. Species accumulation annotations for first-detection date + species name.
3. Configurable NoID inclusion policy in upstream pipeline.
4. Per-plot generation wrapper and failure ledger.

---

## 4) Per-Plot Change Spec (Final)

## 4.1 Quality

### Q1/Q2 consolidation (status by detector)
- **Current issue**: conceptual duplication between detector status summary and status breakdown percent.
- **Final change**:
  - Keep one consolidated detector status plot.
  - Include stacked percentages + counts + 90% threshold cue.
- **Implementation note**: deprecate one function and map report references to retained canonical plot.

### Q3 overall recording status
- **Action**: no major change required (user-approved as fine).

### Q4 total recording effort by detector
- **Action**: apply new detector palette uniformly.

### Q5 recording nights by detector
- **Issue**: currently appears constant (e.g., 28 for all).
- **Action**:
  - audit grouping/window logic and expected-night assumptions.
  - fix aggregation to true observed nights per detector.
  - apply detector palette.

### Q6 data completeness by detector
- **Issue**: currently rendering all missing by week.
- **Action**:
  - correct expected-vs-observed merge logic and date granularity.
  - verify full grid completion and join keys.

### Q7 missing recording nights by detector
- **Issue**: currently indicating 100% complete incorrectly.
- **Action**:
  - fix expected-night derivation and detector-specific actual-night counting.
  - verify denominator source and deployment assumptions.

### Q8 recording effort heatmap
- **Action**:
  - replace hard-coded palette with professional red-yellow-green gradient.
  - keep NA handling and placeholder behavior.

## 4.2 Detector

### D1 total bat calls by detector
- **Action**: apply detector palette.

### D2 detector activity caterpillar
- **Action**: apply detector palette.

### D3 distribution of nightly activity by detector
- **Action**: apply detector palette.

### D4 activity_with_without_outliers
- **Current issue**: duplicates already-available with-outlier concept.
- **Action**: convert to single “without outlier” plot only.

### D5 synchrony across detectors
- **Action**:
  - apply detector palette.
  - add legend explicitly.

### D6 correlation heatmap
- **Action**: no requested visual change; preserve current guardrails.

### D7 detector rank over time
- **Action**: apply detector palette consistently for detector identity mapping.

## 4.3 Species

### S1 species composition histogram/bar
- **Action**: align with standardized species palette behavior.

### S2 species by detector heatmap
- **Action**: keep as-is for now, ensure palette coherence where categorical species colors are shown.

### S3 species accumulation curve
- **Action**:
  - annotate dates when new species are added.
  - annotate/label which species was added at each novelty point.

### S4 species hourly profile
- **Action**: no immediate mandatory change; keep stable.

### S5 NoID proportion
- **Action**:
  - keep plot now.
  - support future config toggle so NoID can be retained/removed at user discretion upstream.

### New species feature
- Add **species nightly plot** (new plot artifact) with clear spec and optional top-N behavior.

## 4.4 Temporal

### T1 bat activity over time
- **Action**: apply detector palette consistency.

### T2 cumulative calls over time
- **Action**: no mandatory change now.

### T3 hourly activity profile
- **Action**: no mandatory change now.

### T4 calls per hour distribution
- **Action**: no mandatory change now.

### T5 weekly bat activity
- **Action**: add x-axis label for each week (readable date/week formatting).

### T6 activity by month
- **Action**: no mandatory change now.

---

## 5) Architecture and Refactor Tasks

## 5.1 Palette API additions (`plot_helpers.R`)
Add/extend helpers:
1. `kpro_palette_detector(n = 16+ , ...)` for stable detector mapping.
2. `kpro_scale_detector_fill(...)` and `kpro_scale_detector_color(...)` wrappers.
3. `kpro_palette_species(...)` wrapper for species charts.
4. `kpro_scale_effort_heatmap()` for red-yellow-green gradient.

Requirements:
- deterministic detector-to-color mapping across plots in one run.
- safe behavior when detector count exceeds default palette length.

## 5.2 Module 6 generation wrapper
- Introduce per-plot safe generation helper and failure ledger structure.
- Keep category-level reporting but avoid category-wide wipe on one plot error.

## 5.3 Config roadmap
Add or prepare config hooks in `study_parameters.yaml` for:
- plot output toggles (if not already completed)
- outlier percentile
- detector status threshold
- NoID inclusion policy (`keep`, `remove`)

---

## 6) Data Correctness Audit Plan (for Q5/Q6/Q7)

For each flagged quality plot:
1. Reconstruct expected table used by the plot from source data.
2. Validate keys and granularity used in joins (`Detector`, `Night`, `week`).
3. Compare computed values vs known truth sample slices.
4. Add focused diagnostics to log intermediate row counts and summaries.
5. Freeze behavior with lightweight regression checks.

Expected outcome:
- No false all-missing weeks.
- No false 100% completeness.
- No false uniform nights across detectors.

---

## 7) File-Level Implementation Map

Primary targets:
- `R/functions/output/plot_helpers.R` (palette/scales/helpers)
- `R/functions/output/plot_quality.R` (Q1/Q2/Q5/Q6/Q7/Q8)
- `R/functions/output/plot_detector.R` (D1/D2/D3/D4/D5/D7)
- `R/functions/output/plot_species.R` (S1/S3/S5 + new species nightly)
- `R/functions/output/plot_temporal.R` (T1/T5)
- `R/modules/plotting.R` (generation policy and canonical plot registry)
- `inst/config/study_parameters.yaml` (config flags)
- report references where consolidated/added plots must be reflected

---

## 8) Acceptance Criteria

## 8.1 Correctness
- Q6 no longer shows all-missing when data exists.
- Q7 no longer reports false 100% completeness.
- Q5 no longer reports false uniform night counts.

## 8.2 Visual consistency
- Detector-grouped plots share the same detector color mapping.
- Requested species/temporal charts follow coherent palette behavior.
- Q8 heatmap uses professional red-yellow-green gradient.

## 8.3 Functional behavior
- Status-by-detector duplication removed (single canonical plot with threshold + numbers).
- D4 presents only without-outlier variant.
- Synchrony includes legend.
- Weekly activity has week-by-week x-axis labels.

## 8.4 Feature additions
- Species nightly plot exists and is exported/reported.
- Species accumulation plot annotates new species + date additions.

## 8.5 Robustness
- Per-plot failures are isolated and logged.
- Successful plots continue through export and report stages.

---

## 9) Delivery Sequence (Execution Sprints)

### Sprint A (P0 correctness)
- Fix Q5/Q6/Q7 calculations + regression validation.

### Sprint B (palette + requested visual behavior)
- Implement detector/species/heatmap palette system and apply across requested plots.
- Apply D4, D5 legend, T5 axis label changes.

### Sprint C (feature additions)
- Add species nightly plot.
- Add species accumulation annotations.

### Sprint D (resilience + config hardening)
- Per-plot fault isolation ledger.
- NoID config pathway and plot-output config parity.

---

## 10) Cross-Reference Matrix

| Source | Key Findings Incorporated Here |
|---|---|
| `PLOTS_ECOSYSTEM_HYPER_ANALYSIS_2026-02-20.md` | policy alignment, DRY direction, config parity, fault isolation strategy |
| `PLOTS_26_NITTY_GRITTY_PLAYBOOK_2026-02-20.md` | per-plot internals, lineage, artifact movement, concrete refactor points |
| User notes (2026-02-20) | final behavior decisions, palette requirements, plot-level priority changes |

---

## 11) Ready-to-Execute Task Backlog (Developer-Facing)

1. Implement palette helpers and detector 16+ mapping.
2. Patch Q5/Q6/Q7 computations; add debug checks.
3. Consolidate Q1/Q2 into one canonical plot and report reference.
4. Convert D4 to without-outlier-only.
5. Add synchrony legend.
6. Apply detector palette across D1/D2/D3/D5/D7 and T1, Q4/Q5 as requested.
7. Add Q8 red-yellow-green heatmap scale.
8. Add T5 per-week x-axis labels.
9. Add species nightly plot.
10. Add S3 novelty annotations (species + date).
11. Prepare NoID config pathway for pipeline-level control.
12. Add per-plot failure ledger in Module 6.

This backlog is the direct implementation queue for the next coding pass.
