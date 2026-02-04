# Pipeline Orchestrator Refactor Plan (Chunks 1–3)

**Date:** 2026-02-04  
**Scope:** Identify redundant patterns across `run_ingest_standardize.R`, `run_cpn_template.R`, and `run_finalize_to_report.R`, and outline helper-driven reductions. Focus for this pass is Chunks 1 and 2; Chunk 3 is already partially standardized.

---

## Current Redundancies (by file)

### run_ingest_standardize.R (Chunk 1)
- Custom banners: uses `print_stage_header()` only; no `print_stage_banner()`.
- Validation lifecycle: direct `create_validation_context()` and `finalize_validation_report()` calls; no `init_stage_validation()` / `complete_stage_validation()`.
- Result assembly: returns custom list; does not use `store_stage_results()`.
- Checkpoint/validation dir handling: manual `assert_directory_exists()` and path assembly.
- Artifact registration: manual `register_artifact()`; no `save_and_register_rds()` (CSV use-case may remain custom but registry init/flow can align with other chunks).

### run_cpn_template.R (Chunk 2)
- Same banner/validation patterns as Chunk 1 (manual context/finalize, no banner helper).
- Checkpoint discovery: uses bespoke `load_most_recent_checkpoint()` instead of `find_most_recent_checkpoint()` (naming drift).
- Result assembly: manual list, no `store_stage_results()`.
- Validation dir creation and logging duplicated.
- Manual artifact registration (two templates) with repeated metadata scaffolding.

### run_finalize_to_report.R (Chunk 3)
- Already uses `print_stage_banner()`, `init_stage_validation()`, `complete_stage_validation()`, `save_and_register_rds()`, `store_stage_results()`, `find_most_recent_checkpoint()`, `load_cpn_template()`.
- Serves as reference implementation for helper adoption.

---

## Cross-Chunk Repeated Patterns
- Stage banners and numbered stage headers.
- Validation lifecycle (init → log events → finalize HTML).
- Validation directory creation and messaging.
- Artifact registry initialization and per-artifact registration.
- Checkpoint discovery + template loading.
- Structured result assembly + accumulation of validation HTML paths.
- Timestamped output naming.

---

## Helper Mappings to Reduce Redundancy
- **Banners:** replace manual/absent banners with `print_stage_banner()`.
- **Validation:** use `init_stage_validation()` at stage start and `complete_stage_validation()` at completion; drop direct `finalize_validation_report()`.
- **Results:** use `store_stage_results()` to attach stage outputs and track `validation_html_paths`.
- **Checkpoints/Templates:** use `find_most_recent_checkpoint()` and `load_cpn_template()` (where applicable).
- **Artifacts:** prefer `save_and_register_rds()` when saving RDS outputs; for CSV artifacts keep `register_artifact()` but centralize registry init and metadata patterns.
- **Directories:** rely on helper outputs/validation dirs where possible (or add a small helper if needed).

---

## Gameplan (Phased, minimal change)
1. **Chunk 1 (ingest) quick wins**
   - Add `print_stage_banner("INGEST & STANDARDIZE", verbose)` at start.
   - Swap validation init/finalize to `init_stage_validation("ingest", study_params)` and `complete_stage_validation(...)`.
   - Use `store_stage_results()` for return assembly (stage key `ingest_standardize`).
   - Keep CSV save/registry pattern but centralize registry init/flow similar to Chunk 3.
2. **Chunk 2 (cpn template) quick wins**
   - Add `print_stage_banner("CPN TEMPLATE", verbose)`.
   - Replace validation init/finalize with helpers; use `store_stage_results()`.
   - Replace checkpoint loader with `find_most_recent_checkpoint("kpro_master", ...)`.
   - Use `load_cpn_template()` for template loading if re-used; otherwise keep generation logic but align validation/report flow.
   - Consider consolidating dual artifact registration into a small helper or reuse `save_and_register_rds()` if an RDS is introduced later; otherwise standardize metadata blocks.
3. **Shared utility alignment**
   - Ensure both chunks append validation HTML via `store_stage_results()` to maintain a consistent `validation_html_paths` contract.
   - Normalize validation_dir handling to a single pattern (helper already creates when absent via `complete_stage_validation()`).
4. **Future (post-quick wins)**
   - Consider a thin wrapper for CSV save + register to mirror `save_and_register_rds()` for CSV artifacts.
   - Add a lightweight orchestrator scaffold helper to create `result` skeletons with `validation_html_paths`.

---

## Additional Repeated Blocks to Target
- Manual logging of chunk start/complete banners → use `print_stage_banner()` plus existing `log_message()` start/end lines.
- Manual date/timestamp creation → prefer existing `generate_timestamped_filename()` where applicable.
- Manual validation summary population → keep minimal, rely on events + `complete_stage_validation()` for HTML generation.

---

## Minimal-Risk Implementation Order
1) Apply banner + validation helper + `store_stage_results()` to Chunk 1.  
2) Apply same set to Chunk 2 plus checkpoint helper swap.  
3) Evaluate need for CSV save/register helper (optional after alignment).  
4) Reassess remaining duplication (artifact metadata scaffolding, validation dir handling).  

This preserves behavior while reducing boilerplate and aligning Chunks 1–2 with the already-standardized Chunk 3.
