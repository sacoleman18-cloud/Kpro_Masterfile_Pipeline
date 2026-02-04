# ==============================================================================
# VALIDATION & ARTIFACT HELPER STANDARDS
# ==============================================================================
# VERSION: 1.0
# LAST UPDATED: 2026-02-04
# PURPOSE: Standardize usage of validation and artifact helpers across
#          orchestrating workflows and supporting modules.
# ==============================================================================

## 1. VALIDATION HELPERS

- Use centralized helpers from `R/functions/validation/validation_reporting.R`:
  - `init_stage_validation(stage_name, study_params)` to initialize contexts.
  - `log_validation_event()` for all validation events.
  - `complete_stage_validation()` to finalize HTML outputs.
- Do **not** call `finalize_validation_report()` directly in orchestrators.
- Always pass `validation_dir = here::here("results", "validation")` (create if missing).
- Validation completion must log via `complete_stage_validation()` (logs regardless of verbose).
- Orchestrators should store validation outputs using `store_stage_results()` to keep
  `validation_html_paths` up to date.

## 2. ARTIFACT HELPERS

- Use `save_and_register_rds()` (in `R/functions/core/artifacts.R`) for all RDS saves that
  must be tracked. Do not re-implement save + register manually.
- Maintain a single `registry` object through orchestrator stages and pass into
  `create_release_bundle()` so hashing/manifest stay consistent.
- Artifact types should align with existing patterns (`summary_stats`, `plot_objects`,
  `cpn_final`, etc.). Add new types sparingly and document in `artifacts.R` if added.

## 3. CHECKPOINT & TEMPLATE LOADING

- Discover checkpoints with `find_most_recent_checkpoint()` instead of `find_most_recent_file()`
  for the supported patterns (kpro_master, cpn_original, cpn_edit, summary_rds, plots_rds).
- Load CPN templates with `load_cpn_template()` to enforce deduplication and type coercion,
  and to log deduplication into the validation context when provided.

## 4. BANNERS AND STAGE STRUCTURE

- Use `print_stage_banner()` for major section banners in orchestrators.
- Continue using `print_stage_header()` (or existing numbered headers) for within-stage steps,
  but keep banner usage consistent for stage entry.

## 5. STRUCTURED RETURNS

- Use `store_stage_results()` to attach stage outputs and validation reports to the result list.
- Ensure `result$validation_html_paths` accumulates via `store_stage_results()` (do not append manually).

## 6. DOCUMENTATION EXPECTATIONS

- Orchestrator headers must note use of shared helpers (banner, validation init/finalize,
  checkpoint/template loaders, RDS save/register, stage result storage).
- Changelogs should record adoption of these helpers when modified.

## 7. TESTING & VERIFICATION

- When adding/changing orchestrator logic, run targeted stages that exercise helper flows
  (e.g., validation HTML generation, RDS save/register).
- Ensure verbose mode prints banner and validation confirmations; logging must occur even when silent.

## 8. WHEN TO EXTEND

- If a new artifact type or validation workflow is introduced, update:
  - `R/functions/core/artifacts.R` (type metadata/comments)
  - `R/functions/validation/validation_reporting.R` (if new validation behaviors)
  - This document to describe the new pattern.
