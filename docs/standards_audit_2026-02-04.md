# Standards Audit – 2026-02-04

## Scope and Paths
- 00_standards_index: `docs/00_STANDARDS_INDEX.md`
- 01_architecture_standards: `docs/01_architecture_standards.md`
- 02_documentation_standards: `docs/02_documentation_standards.md`
- 03_code_design_standards: `docs/03_code_design_standards.md`
- 04_data_standards: `docs/04_data_standards.md`
- 05_logging_console_standards: `docs/05_logging_console_standards.md`
- 06_quarto_reporting_standards: `docs/06_quarto_reporting_standards.md`
- 07_artifact_release_standards: `docs/07_artifact_release_standards.md`
- 08_development_standards: `docs/08_development_standards.md`
- 09_appendices: `docs/09_appendices.md`

## Findings (drift since 2026-01-31)

### 01_architecture_standards.md — Severity: Medium  
**Outdated:** Pipeline orchestration now relies on shared helpers (`print_stage_banner()`, `init_stage_validation()`, `complete_stage_validation()`, `save_and_register_rds()`, `store_stage_results()`, `find_most_recent_checkpoint()`, `load_cpn_template()`), but these are not referenced in architecture conventions.  
**Update Needed (exact wording suggestion):** Under the “Directory Structure” or “Orchestrating Functions” section add a bullet:  
`- Orchestrators must use shared helpers: print_stage_banner(), init_stage_validation()/complete_stage_validation(), save_and_register_rds(), store_stage_results(), find_most_recent_checkpoint(), load_cpn_template()`  
**Links:** `R/pipeline/run_finalize_to_report.R`, `R/functions/core/utilities.R`, `R/functions/core/artifacts.R`, `R/functions/validation/validation_reporting.R`.

### 02_documentation_standards.md — Severity: Low  
**Outdated:** Recent helper adoption and validation reporting centralization aren’t called out in doc expectations (e.g., documenting helper usage in headers).  
**Update Needed:** Add to documentation checklist:  
`- Note use of shared orchestration helpers (banners, validation init/finalize, RDS save/register, checkpoint/template loaders) in function headers/changelogs.`  
**Links:** `R/pipeline/run_finalize_to_report.R` (header updated 2026-02-04).

### 03_code_design_standards.md — Severity: Medium  
**Outdated:** Standard patterns for stage result assembly and validation finalization still describe manual list assembly and direct `finalize_validation_report()` calls.  
**Update Needed:** In “Workflow orchestration” section add:  
`- Use store_stage_results() for result assembly and complete_stage_validation() for validation HTML generation; avoid manual list concatenation or direct finalize_validation_report() in orchestrators.`  
**Links:** `R/pipeline/run_finalize_to_report.R`, `R/functions/core/utilities.R`, `R/functions/validation/validation_reporting.R`.

### 04_data_standards.md — Severity: Low  
**Outdated:** Checkpoint discovery now standardized via `find_most_recent_checkpoint()`; template loading via `load_cpn_template()` (with deduplication and type coercion) is not referenced.  
**Update Needed:** Add bullets under checkpoint/data sourcing:  
`- Discover checkpoints with find_most_recent_checkpoint() instead of find_most_recent_file().`  
`- Load CPN templates with load_cpn_template() to enforce deduplication and typed Night/RecordingHours.`  
**Links:** `R/functions/core/utilities.R`, `R/pipeline/run_finalize_to_report.R`.

### 05_logging_console_standards.md — Severity: Low  
**Outdated:** New banner helper `print_stage_banner()` governs console output for orchestrators.  
**Update Needed:** Add note in console patterns:  
`- Use print_stage_banner() for major stage banners; message() calls remain gated by verbose.`  
**Links:** `R/pipeline/run_finalize_to_report.R`, `R/functions/core/utilities.R`.

### 06_quarto_reporting_standards.md — Severity: Low  
**Outdated:** Report rendering now uses pre-validated RDS artifacts located via standardized save/register helpers; standards don’t mention ensuring RDS structure validation prior to render.  
**Update Needed:** Add bullet under “Inputs to reports”:  
`- Validate summary/plot RDS via validate_rds_structure and ensure artifacts come from save_and_register_rds() outputs before quarto_render.`  
**Links:** `R/pipeline/run_finalize_to_report.R`, `R/functions/core/artifacts.R`.

### 07_artifact_release_standards.md — Severity: Medium  
**Outdated:** Artifact registration guidance predates `save_and_register_rds()` consolidation; release step now assumes registry is kept through helper use.  
**Update Needed:** Replace manual save+register pattern with:  
`- Prefer save_and_register_rds() for RDS artifacts (summary, plots) to ensure hashing/registry consistency.`  
`- Registry should be passed through orchestrator stages and into create_release_bundle().`  
**Links:** `R/pipeline/run_finalize_to_report.R`, `R/functions/core/artifacts.R`, `R/functions/core/release.R` (if present).

### 08_development_standards.md — Severity: Low  
**Outdated:** Does not mention new helper usage expectations when adding/altering orchestrators.  
**Update Needed:** In workflow change checklist add:  
`- Reuse shared orchestration helpers (banners, validation init/finalize, checkpoint discovery, template loading, result storage, artifact save/register) instead of bespoke code.`  
**Links:** `R/pipeline/run_finalize_to_report.R`.

### 09_appendices.md — Severity: Low  
**Outdated:** Checklist now partially updated but still references `print_stage_header()` as the formatting guidance without explicitly mentioning `print_stage_banner()` adoption for section banners.  
**Update Needed:** Add bullet to “Before Modifying a Chunk/Workflow”:  
`- Use print_stage_banner() for major section banners; keep print_stage_header() for numbered sub-stages.`  
**Links:** `R/pipeline/run_finalize_to_report.R`, `R/functions/core/utilities.R`.

### 00_STANDARDS_INDEX.md — Severity: Low  
**Outdated:** Index doesn’t reference new helper-driven patterns or point to validation_reporting.R for centralized validation helpers.  
**Update Needed:** Add quick pointers:  
`- Validation helpers: R/functions/validation/validation_reporting.R (init_stage_validation(), complete_stage_validation()).`  
`- Artifact helpers: R/functions/core/artifacts.R (save_and_register_rds()).`  
`- Orchestrator utilities: R/functions/core/utilities.R (print_stage_banner(), store_stage_results(), find_most_recent_checkpoint(), load_cpn_template()).`  
**Links:** files above.

## Additional Suggestions
- Consider adding a dedicated “Validation & Artifact Helper Standards” doc to consolidate expectations for validation HTML generation, artifact hashing/registration, and checkpoint discovery across workflows.
- Add a short “Pipeline Orchestration Patterns” appendix snippet pointing to shared helpers to reduce drift when new chunks/workflows are added.
