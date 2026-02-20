# Plots Ecosystem Hyper-Analysis (2026-02-20)

## Purpose
This document captures a full architectural and implementation analysis of the plotting ecosystem in the KPro Masterfile Pipeline, then proposes concrete improvements and a phased implementation path.

It is designed to be cross-referenced with upcoming user notes so we can converge on one final execution plan.

---

## Scope Analyzed
- Module orchestration and phase flow for plotting
- Plot function modules and shared helper layer
- PNG export and plot-object RDS archival path
- Artifact/config control surface and determinism characteristics
- Alignment with ST standards and reporting philosophy

Primary files analyzed:
- `R/modules/plotting.R`
- `R/modules/module_runner.R`
- `R/functions/output/plot_helpers.R`
- `R/functions/output/plot_quality.R`
- `R/functions/output/plot_detector.R`
- `R/functions/output/plot_species.R`
- `R/functions/output/plot_temporal.R`
- `R/pipeline/run_phase3_analysis_reporting.R`
- `inst/config/study_parameters.yaml`
- `manifest.YAML`
- Relevant ST docs in `docs/ST_*.md`

---

## Current Architecture (As Implemented)

### Flow
1. Phase 3 orchestrator calls Module 6 plotting.
2. Module 6 builds all plot objects in-memory (quality/detector/species/temporal).
3. Module 6 exports PNG files for all generated plots.
4. Module 6 saves full `all_plots` object to `plot_objects_YYYYMMDD.rds`.
5. Module 7 (report/release) consumes pre-computed plot objects.

### Functional Topology
- **Orchestration layer:** `module_plotting()` + `run_module_plotting()`
- **Shared plotting primitives:** `plot_helpers.R`
  - `theme_kpro()`, palettes, `validate_plot_input()`, format helpers
  - `create_plot_directories()`, `export_plots_png()`
- **Domain modules:** quality / detector / species / temporal plotting modules

### Output Model
- PNG files under `results/figures/png/{quality,detector,species,temporal}/`
- Plot object archive under `results/rds/plot_objects_YYYYMMDD.rds`

---

## What Is Strong Already
1. **Good layering and separation of concerns**
   - Plot generation is modular and domain-scoped.
2. **Reusable helper base exists**
   - Shared validation/theme/export helper module is in place.
3. **Quarto-compatible object architecture**
   - Plot objects are persisted and reused downstream (no report-time recompute).
4. **Mostly deterministic plotting behavior**
   - Ordering and transformations are generally explicit (`arrange`, factor ordering).
5. **Output structure is predictable**
   - Category-specific directories and stable plot object structure.

---

## Key Gaps / Risks

### 1) Contract Drift in Error Policy (High)
- Module-level docs state failures are logged and non-fatal.
- Species plot stage currently `stop()`s on failure, making it fatal.
- This creates mismatch between stated and actual behavior.

**Impact:** Unexpected pipeline hard-stop and contract inconsistency.

---

### 2) Runner Input Semantics Drift (High)
- `run_module_plotting(summary_stats_result, ...)` accepts upstream result but reloads artifacts from disk rather than using the passed object.
- This can couple behavior to filesystem recency/state instead of explicit in-memory lineage.

**Impact:** Lower determinism/traceability in module-only runs and debugging contexts.

---

### 3) Missing Artifact Output Controls for Plots (High)
- Summary module has granular `artifact_outputs` toggles.
- Plot module currently always exports PNG + saves plot-object RDS.
- No plot-specific controls (e.g., disable PNG but keep RDS for Quarto-inline workflows).

**Impact:** Reduced flexibility and policy inconsistency across module ecosystems.

---

### 4) Fault Isolation Granularity (Medium)
- Try/catch wraps whole categories.
- One failing plot can zero out an entire category result list.

**Impact:** Preventable loss of successful plots and reduced resilience.

---

### 5) Filename/Doc Canonical Drift (Medium)
- Some docs/manifests imply timestamped PNG names.
- Exporter writes stable names (`<plot_name>.png`) under category folders.

**Impact:** Documentation confusion and release-audit ambiguity.

---

### 6) Manifest Template Drift vs Reality (Medium)
- Template category counts/listings do not consistently match actual implemented plot counts and assignments.

**Impact:** Audit/provenance templates can mislead and require manual interpretation.

---

## Proposed Improvements (Prioritized)

## P0 (Do First)

### P0-A: Align Error Handling Contract
Choose one canonical policy and enforce it consistently:
- **Option A (recommended):** non-fatal per-plot failure, with warnings + failed-plot ledger.
- **Option B:** explicit fail-fast for required categories, documented in contract.

**Recommendation:** Option A for module robustness + report continuity.

### P0-B: Add Plot Artifact Output Controls
Extend `artifact_outputs` with plot controls, e.g.:
- `png_quality_plots`
- `png_detector_plots`
- `png_species_plots`
- `png_temporal_plots`
- `rds_plot_objects`

Default policy can be tuned to your reporting mode (Quarto-inline vs external PNG distribution).

### P0-C: Repair Runner Semantics
Make `run_module_plotting()` either:
- consume passed objects explicitly (preferred), or
- rename API to indicate file-reload behavior.

---

## P1 (Next)

### P1-A: Per-Plot Fault Isolation
Refactor category generation into per-plot safe wrappers:
- collect `success`, `failed`, and `error_message` per plot
- keep partial successes
- expose failure ledger in module result summary

### P1-B: Shared Plot Build/Export Helpers
Reduce duplication in `module_plotting()` by introducing helper patterns similar to table refactors:
- `generate_plot_group_safely()`
- `export_plot_group_png()`
- consolidated stage summary logging

### P1-C: Canonical Naming Policy
Decide one policy for PNG names and document everywhere:
- Stable names (current implementation)
- or timestamped names

If stable names remain canonical, update architecture/docs/manifest examples accordingly.

---

## P2 (Polish)

### P2-A: Observability Upgrade
Add structured summary payload in result object:
- `plots_attempted`
- `plots_succeeded`
- `plots_failed`
- `failed_plot_details`

### P2-B: Manifest/Template Synchronization
Update `manifest.YAML` template category counts and plot inventories to match canonical module outputs.

### P2-C: Optional Style-Consistency Sweep
Audit all plot modules for strict consistency in:
- title/subtitle patterns
- legend positioning rules
- axis label conventions

(Only where this does not conflict with plot-specific readability.)

---

## Suggested Implementation Sequence
1. Policy decision: fatal vs non-fatal plot generation failures.
2. Add plot artifact output toggles + defaults.
3. Refactor `run_module_plotting()` semantics to explicit input lineage.
4. Introduce per-plot fault isolation wrappers.
5. Update docs/manifest naming + count canonicalization.
6. Run targeted validation and one end-to-end phase test.

---

## Validation Checklist for Refactor
- [ ] Plot module still returns `all_plots` with same category schema
- [ ] Report module reads `plot_objects` unchanged
- [ ] PNG export count matches generated/successful plots
- [ ] `artifact_outputs` controls respected for plot artifacts
- [ ] Failures are surfaced in summary (not silently dropped)
- [ ] ST docs and manifest examples match code behavior

---

## Cross-Reference Matrix (For Your Notes)
Use this matrix to map your notes directly against this analysis.

| Area | My Current Recommendation | Your Notes | Final Decision | Priority |
|---|---|---|---|---|
| Error handling policy | Non-fatal per-plot; log + ledger |  |  | P0 |
| Plot artifact toggles | Add plot-specific `artifact_outputs` keys |  |  | P0 |
| Runner semantics | Consume passed object vs disk reload |  |  | P0 |
| Fault isolation | Per-plot try/catch instead of per-category |  |  | P1 |
| DRY refactor | Add plot-group helper functions |  |  | P1 |
| PNG naming policy | Canonicalize stable vs timestamped names |  |  | P1 |
| Manifest alignment | Sync template counts/list with implementation |  |  | P2 |
| Styling sweep | Optional consistency pass across modules |  |  | P2 |

---

## Decision-Ready Questions
1. Should plot-generation failures be **non-fatal** (resilient) or **fail-fast** (strict)?
2. Do you want standalone PNG exports always on, or configurable per category?
3. Should runner wrappers prioritize passed objects (in-memory lineage) over latest-on-disk discovery?
4. Keep current stable PNG filenames, or move to timestamped PNG artifacts?

---

## Recommended Baseline for Final Plan (Proposed)
- Non-fatal per-plot failure policy
- Configurable plot artifact outputs (with Quarto-friendly defaults)
- Runner semantics aligned to explicit input lineage
- Per-plot failure ledger in module result summary
- Full docs/manifest canonicalization after code changes

This baseline gives maximum determinism, resilience, and operational transparency while preserving current plot outputs and report compatibility.
