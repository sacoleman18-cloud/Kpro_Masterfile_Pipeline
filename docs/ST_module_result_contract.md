# ==============================================================================
# MODULE RESULT CONTRACT STANDARDS
# ==============================================================================
# VERSION: 1.0
# LAST UPDATED: 2026-02-21
# PURPOSE: Define canonical module result structures, deterministic handoff rules,
#          and validation-first payload standards for Modules 1-7
# ==============================================================================

## OVERVIEW

This standard defines the required return-object contract for pipeline modules and
phase orchestrators.

Primary goals:
1. Preserve the per-module stored list pattern for audit/debug.
2. Enforce deterministic in-memory handoff across linear phase execution.
3. Remove redundant or ambiguous checkpoint semantics after phase boundaries.
4. Make validation outputs prominent and consistent across all module payloads.
5. Use phase results for passing originals/intermediates rather than persistent files.

Key Design Decisions:
- Phase 1 writes `kpro_master.csv` checkpoint; Phase 2 conditionally loads it based on YAML `use_manual_ids` config
  - Set in study_parameters.yaml by Shiny app: `processing_options.use_manual_ids`
  - If `yes/true` → Phase 2 reads user-edited `kpro_master.csv` from Phase 1 checkpoint
  - If `no/false` (default) → Phase 2 uses in-memory `kpro_master` from Phase 1 result
- Phase 2 generates CPN template and saves ONLY `EDIT_THIS.csv` for user editing
- In-memory original is passed to Phase 3 for deterministic edit comparison (no persistent `ORIGINAL.csv` file)

This document is authoritative for result structure decisions in:
- `R/modules/*.R`
- `R/modules/module_runner.R`
- `R/pipeline/run_phase*.R`
- `inst/config/study_parameters.yaml` (for manual_id configuration)

**Context:** This is background code for a Shiny app. Users control pipeline behavior via the app UI,
which translates to YAML settings. Users do not edit R code directly.

---

## 1. CORE PRINCIPLES

### 1.1 Three-Phase Orchestration is Canonical

Production execution follows strict phase sequence with explicit boundaries:

```
Phase 1: Data Preparation (Modules 1-2)
         ↓ [Phase result with kpro_master]
Phase 2: Template Generation (Module 3)
         ↓ [Phase result with cpn_template + EDIT_THIS.csv]
         [USER EDITS TEMPLATE]
         ↓ [Phase result received with edited file]
Phase 3: Analysis & Reporting (Modules 4-7)
         ↓ [Final outputs]
```

Rules:
- Phase orchestrators (`run_phase1_*`, `run_phase2_*`, `run_phase3_*`) are the unit of execution.
- Modules within a phase are chained by the phase orchestrator.
- Phase results structure data and metadata for handoff to next phase.
- Module-to-module handoff within a phase is in-memory (via phase orchestrator).
- Phase-to-phase handoff is via structured phase result objects.

### 1.2 Phase Results Chain Between Phases (Structured Passing)

Phase orchestrators accept the previous phase's result as input and produce a phase result containing:
- All primary data outputs
- Metadata about execution
- In-memory module results for debugging
- Validation reports

Example flow:
```r
phase1_result <- run_phase1_data_preparation(verbose = TRUE)
phase2_result <- run_phase2_template_generation(phase1_result = phase1_result, verbose = TRUE)
phase3_result <- run_phase3_analysis_reporting(phase2_result = phase2_result, verbose = TRUE)
```

### 1.3 Deterministic Execution is Enforced at Phase Level

Within a phase:
- Modules receive in-memory outputs from prior modules (via phase orchestrator)
- Modules must not silently replace in-memory inputs with latest-on-disk artifacts
- Disk checkpoints are phase-boundary artifacts and recovery aids, not default in-phase inputs
- Same phase result → same outputs (no opportunistic file discovery)
- Exception: Human-in-the-loop re-entry points are YAML-controlled and explicit

At phase boundaries:
- Phase results are passed explicitly
- YAML configuration (`processing_options.use_manual_ids`) controls conditional re-entry (Phase 1→2 master file)
- Human edits are controlled, logged, and intentional
- In-memory originals passed via phase results enable deterministic comparisons

### 1.4 Per-Module Stored Lists are Required

Phase result objects must include complete `module_results` containing raw outputs from each module executed. This enables:
- Transparency: full audit trail of what each module produced
- Debuggability: easy inspection of intermediate states
- Audit trails: traceability of decisions and transformations

### 1.5 Validation is a First-Class Output

Validation artifacts are required outputs, not incidental metadata.
Each module result must surface `validation_html_paths` consistently.
Phase results must aggregate validation reports from all executed modules.

### 1.6 Checkpoint Semantics Must Be Precise and Phase-Aligned
### 1.6 Checkpoint Semantics Must Be Precise and Phase-Aligned

- Phase 1: `checkpoint_path` = `kpro_master.csv` (data restart boundary for Phase 2)
- Phase 2: `checkpoint_path` = `CPN_Template_EDIT_THIS.csv` (human-editable for Phase 3)
- Phase 3: No checkpoints (final outputs are `report_path`, `release_bundle_path`, etc.)
- In-memory originals (e.g., Phase 2's `cpn_template`) are NOT checkpoints
- Intermediate files not used as phase restart boundaries are NOT checkpoints

---

## 2. REQUIRED MODULE RESULT CONTRACT (Modules 1-7)

Every `run_module_*()` result must include these top-level keys:

1. `validation_html_paths` (character vector; may be length 0 for modules without validation report)
2. `artifact_ids` (character vector; may be length 0)
3. `summary` (named list of compact module KPIs)
4. `checkpoint_path` (character(1) or NULL; only meaningful when module emits true checkpoint)
5. Domain payload object (exactly one canonical key for the module)

Canonical domain payload keys:
- Module 1: `raw_data`
- Module 2: `standardization`
- Module 3: `cpn_template`
- Module 4: `finalize_cpn`
- Module 5: `summary_stats`
- Module 6: `plotting`
- Module 7: `report_release`

### 2.1 Suggested Skeleton

```r
result <- list()

result$<domain_key> <- list(...)
result$summary <- list(...)
result$validation_html_paths <- character(0)
result$artifact_ids <- character(0)
result$checkpoint_path <- NULL

return(result)
```

---

## 3. PHASE RESULT CONTRACT

Each `run_phase*()` return must include:

1. `phase`
2. `phase_name`
3. Primary phase data/output fields
4. `metadata`
5. `artifact_ids`
6. `validation_html_paths`
7. `module_results` (required; full per-module payloads)

### 3.1 Phase Checkpoint Rules

**Phase 1:**
- Always writes checkpoint: `kpro_master.csv` (data restart boundary)
- Also returns in-memory `kpro_master` in phase result
- Phase 2 uses YAML config to decide: re-read checkpoint from disk OR use in-memory version

**Phase 2:**
- Has meaningful `checkpoint_path` → `CPN_Template_EDIT_THIS.csv` (user-editable checkpoint)
- Also passes in-memory `cpn_template` (the original) to Phase 3 (NOT a checkpoint, NOT saved)
- In-memory original is used for edit detection, not for phase restart

**Phase 3:**
- Final outputs are not checkpoints. Use explicit names:
  - `report_path`
  - `release_bundle_path`
  - optional `primary_output_path`
  - optional `calls_per_night_final_path`

---

## 4. RUNNER INPUT/HANDOFF RULES

### 4.1 Module Input Chain in Phase 3

In phase orchestration (via module_runner functions):

- **Module 4 (finalize_cpn)**: 
  - Receives Phase 2 result containing `kpro_master` (in-memory) and `cpn_template` (in-memory)
  - Uses these for deterministic processing (edit tracking against in-memory original)

- **Module 5 (summary_stats)**: 
  - Receives Module 4 result, extracts `calls_per_night_final`
  - Loads `kpro_master` independently from latest checkpoint (for enhanced analyses)
  - Current limitation: Does not use in-memory passed values; relies on checkpoint disk file

- **Module 6 (plotting)**:
  - Receives Module 5 result
  - Loads `kpro_master` independently from latest checkpoint
  - Loads `calls_per_night_final` from latest result CSV file
  - Current limitation: Does not use in-memory values; relies on recent checkpoint files

- **Module 7 (report_release)**:
  - Receives Module 6 result and Module 5 result
  - Requires RDS paths from prior modules: `summary_rds_path`, `plots_rds_path`
  - All data comes from RDS files (not from in-memory module results)

Note: Modules 5-7 have fallback disk loading to support both phase orchestration and standalone module testing.
For full determinism, in-memory handoff between Modules 5-7 is a future enhancement.

### 4.2 Prohibited Behavior in Production Chain

- No implicit `load_most_recent_checkpoint()` substitution when in-memory upstream inputs are available.
- No implicit `find_most_recent_file()` substitution for core in-phase objects.
- No source-priority ladders/resolution modes in normal deterministic path.

Exception: YAML-configured re-entry (e.g., `use_manual_ids`) is explicitly allowed and expected.
The Phase 2 orchestrator intentionally reads YAML and passes a checkpoint file path (or NULL) to Module 3
based on configuration. This behavior is deterministic and logged in module metadata.

### 4.3 Explicitly Allowed Checkpoint Re-Entry (Human-in-the-Loop)

Allowed and expected:
- Reading user-edited checkpoint artifacts that are part of the formal phase contract.
- Example: Phase 2 `CPN_Template_EDIT_THIS.csv` edited by user, then read in Phase 3.
- Example: Phase 1 output master file optionally edited by user and re-read in Phase 2 (when `use_manual_ids: enabled` in YAML).

**Detailed Re-Entry Patterns:**

#### Pattern 1: Phase 2→3 CPN Template (Unconditional)
- User edits `CPN_Template_EDIT_THIS.csv` after Phase 2 completes.
- Phase 3 reads back `edited_template_file` from explicit path argument.
- Always occurs when Phase 3 is invoked (no config condition).
- Logged in Phase 3 metadata: source flagged as "user_edited_checkpoint".

#### Pattern 2: Phase 1→2 Master File (YAML-Controlled via `processing_options.use_manual_ids`)

**Configuration Location:** `inst/config/study_parameters.yaml`
```yaml
processing_options:
  use_manual_ids: no  # or yes/true to enable manual ID loading
```

**Behavior:**
- Phase 1 always writes `kpro_master.csv` to `outputs/checkpoints/` (checkpoint artifact).
- Phase 1 result contains in-memory `kpro_master` data.
- Phase 2 orchestrator reads YAML config and determines conditional behavior:
  - If `use_manual_ids: yes/true` → Phase 2 finds most recent `kpro_master.csv` checkpoint and passes it to Module 3
  - If `use_manual_ids: no/false` (default) → Phase 2 passes `NULL` to Module 3, which uses in-memory data from Phase 1
- Module 3 priority logic:
  1. If `manual_id_file` parameter is non-NULL → load from disk (user edits applied)
  2. Else if in-memory `kpro_master` available → use memory
  3. Else fallback → load from latest checkpoint
- Logged in Module 3 metadata: `manual_id_used: TRUE/FALSE` indicating which path was taken

**Shiny App Integration:**
This configuration is controlled by the Shiny app UI. Users select whether to use manual IDs via interface,
which sets `use_manual_ids` in YAML. No code editing required.

#### Pattern 3: Phase 2→3 CPN Template Edit Tracking (In-Memory Original)
- Phase 2 generates in-memory template and saves only `EDIT_THIS.csv` to disk (for user editing).
- Phase 2 returns in-memory `cpn_template` (the original/unedited version) in phase result.
- Phase 3 receives Phase 2 result containing in-memory original.
- Phase 3 loads user-edited `EDIT_THIS.csv` from disk.
- Phase 3 compares **in-memory original** (passed from Phase 2) to **edited version** (loaded from disk).
- No persistent `ORIGINAL.csv` file needed — deterministic handoff via phase result.
- Edit tracking logs all user changes with full audit trail.

Rules for this exception across all patterns:
- YAML configuration (`use_manual_ids`) controls conditional re-entry decisions
- When re-entry occurs, it must be logged and represented in module metadata with source attribution
- If re-entry does not occur, in-memory data from phase result is used deterministically
- No implicit disk substitution when in-memory data is available

### 4.4 Standalone Module Testing

When running modules individually (not via phase orchestrator):
- Modules accept explicit in-memory inputs via function parameters:
  - Example: `run_module_summary_stats(finalize_result, verbose = TRUE)`
  - In standalone mode, prior modules must be run first OR their `*.rds` checkpoints must exist
- If checkpoints missing, modules will error with clear messaging
- Standalone execution is for development/debugging only; production uses phase orchestration

---

## 5. VALIDATION-CENTRIC PAYLOAD GUIDANCE

Validation prominence requirements:

1. `validation_html_paths` always present at module and phase levels.
2. `summary` should include at least one validation-relevant KPI where applicable:
   - rows processed
   - outputs generated
   - failures/warnings counts
3. Validation failures/warnings must be reflected in `summary` and validation logs.

Note: Some modules may include a nested `validation` helper field for transparent validation state,
but this is implementation-specific. The canonical top-level `validation_html_paths` is mandatory.

---

## 6. CHECKPOINT TERMINOLOGY STANDARD

### 6.1 Use `checkpoint_path` ONLY when output is a phase restart boundary

Examples:
- Phase 1: `kpro_master.csv` — data checkpoint for phase restart
- Phase 2: `CPN_Template_EDIT_THIS.csv` — user-editable checkpoint (not for phase restart, for human review)
  - Note: In-memory original (`cpn_template`) is passed for edit detection but is NOT a checkpoint
- Phase 3: Final outputs (report, release bundle) — NOT checkpoints

### 6.2 Do NOT use `checkpoint_path` for final delivery artifacts or in-memory-only objects

Examples of non-checkpoints:
- Final report HTML
- Release bundle ZIP
- Intermediate convenience exports not used as phase restart boundaries
- In-memory originals passed via phase result (Phase 2 `cpn_template` for edit comparison)

---

## 7. MODULE-SPECIFIC NOTES (Current Refactor)

### Module 1 (Data Ingestion)
- Domain key: `raw_data`
- Checkpoint: None within phase

### Module 2 (Data Standardization)
- Domain key: `standardization` containing `kpro_master`
- Checkpoint: `kpro_master.csv` (Phase 1 boundary)

### Module 3 (CPN Template)
- Domain key: `cpn_template` containing generated template grid
- **kpro_master input (YAML-controlled):**
  - YAML config: `processing_options.use_manual_ids` (set by Shiny app)
  - If `yes/true` → Phase 2 orchestrator passes `manual_id_file` path to Module 3 (loads from Phase 1 checkpoint)
  - If `no/false` (default) → Phase 2 passes `NULL`, Module 3 uses in-memory `kpro_master` from Phase 1
- Disk Output: `CPN_Template_EDIT_THIS.csv` (human-editable, user adjusts recording hours)
- In-Memory Return: `cpn_template` in phase result (template original for edit comparison in Phase 3, NOT saved to disk)
- Module return includes: 
  - `template_edit_path` (path to EDIT_THIS file for user editing)
  - NOT `template_original_path` (original passed in-memory, not as file)
- Metadata includes: `manual_id_used: TRUE/FALSE` indicating which kpro_master source was used

### Modules 4-7
- Normalize top-level result contract keys to match Modules 1-3 style.
- Reduce ambiguous checkpoint usage.
- Keep domain-specific details (e.g., failure ledger in plotting) while preserving shared shape.

---

## 8. COMPLIANCE CHECKLIST

Use this checklist during refactors/reviews:

- [ ] Module result contains canonical domain payload key
- [ ] Module result contains `summary`
- [ ] Module result contains `validation_html_paths`
- [ ] Module result contains `artifact_ids`
- [ ] `checkpoint_path` used only when semantically valid
- [ ] Phase result retains full `module_results`
- [ ] Phase orchestrator passes in-memory outputs through module chain
- [ ] No implicit disk substitution in deterministic production path
- [ ] Phase 1→2 conditional re-entry: Module 3 checks YAML `use_manual_ids` to decide (disk CSV OR in-memory data)
- [ ] Phase 1→2 re-entry is logged in Module 3 metadata with source attribution
- [ ] Phase 2→3 CPN template: EDIT_THIS saved to disk, in-memory original passed to Phase 3
- [ ] Phase 2→3 CPN template: Phase 3 receives `cpn_template` (original) and loads `EDIT_THIS.csv` from disk

---

## 9. NON-GOALS

This standard does not:
- Redesign visualization content
- Change artifact output configuration policy
- Remove checkpoint infrastructure used for phase boundaries and recovery
- Prohibit standalone module testing workflows

---

## 10. RELATED STANDARDS

- `ST_ORCHESTRATION_PHILOSOPHY.md`
- `ST_architecture_standards.md`
- `ST_data_standards.md`
- `ST_artifact_release_standards.md`
- `ST_code_design_standards.md`

# ==============================================================================
# END OF FILE
# ==============================================================================