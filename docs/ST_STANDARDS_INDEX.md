# ==============================================================================
# KPro MASTERFILE PIPELINE: CODING STANDARDS INDEX
# ==============================================================================
# VERSION: 3.0
# LAST UPDATED: 2026-02-08
# PURPOSE: Navigation hub for modular coding standards and checkpointed phase orchestration
# ==============================================================================

## CORE PHILOSOPHY

This pipeline is designed to be:

1. **Safe** - Never corrupts data, always validates inputs
2. **Defensive** - Assumes things will go wrong and handles gracefully
3. **Reproducible** - Same inputs → same outputs, every time
4. **Replicable** - Works on any computer, any operating system
5. **Portable** - No hardcoded paths, no environment dependencies
6. **User-Friendly** - Designed for researchers who may not know R
7. **Audit-Compliant** - Every transformation logged and tracked
8. **Publication-Ready** - Meets scientific reporting standards
9. **Future-Proof** - Designed for Quarto reports and Shiny apps
10. **Maintainable** - Clear, documented, modular code
11. **Shiny-Ready** - Orchestrating functions return structured results, no global side effects
12. **Checkpointed** - Explicit phases with validation and human-in-the-loop

---

## ARCHITECTURE: CHECKPOINTED PHASE ORCHESTRATION

The pipeline uses a **three-phase checkpointed orchestration** architecture (NEW in v3.0):

```
Phase 1: Data Preparation          → kpro_master.csv checkpoint
Phase 2: Template Generation       → CPN_Template_EDIT_THIS.csv (USER EDITS)
Phase 3: Analysis & Reporting      → Final outputs (report, bundle)
```

**Authoritative Reference:** See [ST_ORCHESTRATION_PHILOSOPHY.md](ST_ORCHESTRATION_PHILOSOPHY.md)

Key improvements in v3.0:
- Explicit phases with clear checkpoints (not implicit chunks)
- Structured result passing between phases
- Human-in-the-loop checkpoint in Phase 2
- Module execution layer for reusable module interface
- Clear separation: Phase orchestrators (high-level) vs. Modules (implementation)

---

## STANDARDS DOCUMENT INDEX

The coding standards are organized into focused documents for targeted reference:

| File | Version | Focus Area | Use When... |
|------|---------|------------|-------------|
| **[ST_ORCHESTRATION_PHILOSOPHY.md](ST_ORCHESTRATION_PHILOSOPHY.md)** | **NEW v1.0** | **Phase orchestration architecture** | **Understanding checkpointed phases, module execution layer, phase result passing** |
| `ST_architecture_standards.md` | v3.0 | Project structure, phases, file naming, paths | Organizing files, understanding phase flow, adding directories |
| `ST_documentation_standards.md` | v2.3 | Headers, Roxygen2, comments, collaboration | Documenting functions, writing phase orchestrator headers |
| `ST_code_design_standards.md` | v2.4 | Function design, error handling, style, assertions | Writing functions, handling errors, code review |
| `ST_data_standards.md` | v2.4 | Data handling, quality, validation, hashing, filters | Validating data, adding quality checks, fingerprinting |
| `ST_logging_console_standards.md` | v2.4 | Logging, console output, progress indicators, verbose gating | Adding logging, formatting console messages |
| `ST_quarto_reporting_standards.md` | v2.3 | Quarto integration, reports, manifest | Working with Quarto, generating reports |
| `ST_artifact_release_standards.md` | v2.4 | Artifact registry, release bundles | Registering outputs, creating release packages |
| `ST_development_standards.md` | v2.3 | Git, testing, dependencies, YAML config | Version control, writing tests, managing packages |
| `ST_appendices.md` | v2.2 | Templates, inventories, checklists, quick reference | Looking up templates, function lists, checklists |

---

## QUICK REFERENCE

### Pipeline Architecture (Phase-Based)

**Checkpointed Phase Execution (Recommended for Production):**
```
run_phase1_data_preparation()
         ↓
    [kpro_master checkpoint]
         ↓
run_phase2_template_generation()
         ↓
    [CPN_Template_EDIT_THIS checkpoint]
         ↓
    🛑 USER EDITS TEMPLATE 🛑
         ↓
run_phase3_analysis_reporting()
         ↓
    [Final outputs: report, release bundle]
```

**Module Execution (Advanced/Testing):**
```
run_all_modules() or individual module runners:
  → run_module_ingestion()
  → run_module_standardization()
  → run_module_cpn_template()
  → run_module_finalize_cpn()
  → run_module_summary_stats()
  → run_module_plotting()
  → run_module_report_release()
```

### Key Directories
```
R/pipeline/               → Phase orchestrators (run_phase*.R)
R/modules/                → Modules + module_runner.R (execution layer)
R/functions/              → Utility functions (6 layers)
outputs/checkpoints/      → Phase 1 & 2 data checkpoints
results/                  → Final outputs (Phase 3)
docs/                     → Standards documents (this directory)
```

### Essential Functions

**Phase Orchestration:**
```r
# Phase execution (recommended pattern)
phase1 <- run_phase1_data_preparation(verbose = TRUE)
phase2 <- run_phase2_template_generation(phase1, verbose = TRUE)
phase3 <- run_phase3_analysis_reporting(phase2, edited_template, verbose = TRUE)
```

**Module Execution:**
```r
# For testing individual modules
source("R/modules/module_runner.R")
r1 <- run_module_ingestion(verbose = TRUE)
r2 <- run_module_standardization(r1, verbose = TRUE)
```

**Paths:**
```r
here::here("results", "csv", "file.csv")  # All paths use here::here()
```

**Logging & Console:**
```r
log_message("Processing started")         # File logging (always)
print_stage_header("2.1", "Load Data")    # Console formatting
print_phase_complete(...)                 # Phase completion display
```

**Artifacts & Validation:**
```r
registry <- init_artifact_registry()
validate_data(df, required_cols = c("Detector", "Night"))
finalize_validation_report(context)
```

**Assertions:**
```r
assert_file_exists(path)
assert_columns_exist(df, c("col1", "col2"))
assert_not_empty(df)
```

---

## DOCUMENTATION HIERARCHY

### Level 1: Master Reference (Start Here)
- **[ST_ORCHESTRATION_PHILOSOPHY.md](ST_ORCHESTRATION_PHILOSOPHY.md)** - Understanding phase architecture
- **[ST_architecture_standards.md](ST_architecture_standards.md)** - File structure and design

### Level 2: Implementation Standards
- **[ST_documentation_standards.md](ST_documentation_standards.md)** - How to document
- **[ST_code_design_standards.md](ST_code_design_standards.md)** - How to design functions
- **[ST_data_standards.md](ST_data_standards.md)** - Data handling and validation
- **[ST_logging_console_standards.md](ST_logging_console_standards.md)** - Logging and output

### Level 3: Specific Topics
- **[ST_quarto_reporting_standards.md](ST_quarto_reporting_standards.md)** - Report generation
- **[ST_artifact_release_standards.md](ST_artifact_release_standards.md)** - Artifacts and releases
- **[ST_development_standards.md](ST_development_standards.md)** - Version control and testing
- **[ST_appendices.md](ST_appendices.md)** - Templates and checklists

---

## USAGE IN DEVELOPMENT

### When Writing Phase Orchestrators
1. Read [ST_ORCHESTRATION_PHILOSOPHY.md](ST_ORCHESTRATION_PHILOSOPHY.md) - understand concept
2. Read [ST_architecture_standards.md](ST_architecture_standards.md) - architecture specifics
3. Read [ST_documentation_standards.md](ST_documentation_standards.md) - header template
4. Implement following phase orchestrator pattern

### When Writing Modules
1. Read [ST_ORCHESTRATION_PHILOSOPHY.md](ST_ORCHESTRATION_PHILOSOPHY.md) - module role
2. Read [ST_code_design_standards.md](ST_code_design_standards.md) - function design
3. Read [ST_data_standards.md](ST_data_standards.md) - data handling
4. Implement module following self-containment pattern

### When Writing Utility Functions
1. Read [ST_code_design_standards.md](ST_code_design_standards.md) - design principles
2. Read [ST_data_standards.md](ST_data_standards.md) or relevant section
3. Read [ST_documentation_standards.md](ST_documentation_standards.md) - Roxygen2

### When Working with Git
1. Read [ST_development_standards.md](ST_development_standards.md) - commit messages

### When Writing Tests
1. Read [ST_development_standards.md](ST_development_standards.md) - testing standards
2. Check [ST_appendices.md](ST_appendices.md) - test templates

---

## VERSION HISTORY AND MAJOR CHANGES

### v3.0 (2026-02-08) - CHECKPOINTED PHASE ORCHESTRATION
**MAJOR ARCHITECTURE TRANSITION**

**New Concepts:**
- Checkpointed phase orchestration (replacing chunk-based model)
- 3 explicit phases with human-in-the-loop checkpoint
- Phase result passing (structured result chaining)
- Module execution layer (callable module interfaces)
- Phase orchestrators (thin wrappers composing modules)

**New Documents:**
- ✨ ST_ORCHESTRATION_PHILOSOPHY.md (v1.0) - Authoritative orchestration reference

**Updated Documents:**
- ST_architecture_standards.md (v2.5 → v3.0) - Complete rewrite for phases
- All other documents remain compatible (minor terminology updates recommended)

**Terminology Changes:**
- "Chunk 1/2/3" → "Phase 1/2/3"
- "Chunk orchestrator" → "Phase orchestrator"  
- "R/debug/module_runner.R" → "R/modules/module_runner.R" (core infrastructure)
- "Debug tool" → "Module execution layer"

**Migration:**
- Old chunk-based functions still work (deprecated)
- New phase orchestrators recommended for all development
- See ST_ORCHESTRATION_PHILOSOPHY.md §7 for migration guide

### v2.3 (2026-01-31)
- Transitioned to Shiny-driven orchestrating functions
- Chunk model: run_ingest_standardize(), run_cpn_template(), run_finalize_to_report()
- Documented verbose parameter for Shiny integration

### v2.2 (2026-01-20)
- Modularized standards into 9 focused documents
- Added artifact registry system, dataset hashing, validation reports
- Added console formatting functions
- Added release bundle system

### v2.1 (2026-01-09)
- Added Workflow 07 Report Standards
- Comprehensive Quarto integration patterns

### v2.0 (2026-01-08)
- Major update for complete 7-workflow pipeline
- Hierarchical directory structure, Layer Responsibilities

### v1.0 (2025-12-26)
- Initial comprehensive standards document
- Covered Workflows 01-03

---

## USAGE IN CLAUDE CHATS

Reference specific standards files when asking for help:

```
"Using ST_ORCHESTRATION_PHILOSOPHY, explain how phases work"
"Using ST_architecture_standards, help me add a new output directory"
"Using ST_code_design_standards, review this function"  
"Using ST_data_standards, add hash verification to this loader"
"Using ST_documentation_standards, write the header for this orchestrator"
"Using ST_artifact_release_standards, register these new outputs"
```

---

## KEY STANDARDS COMPLIANCE CHECKLIST

### Before Committing Code
- [ ] Followed file naming conventions (phases, modules, functions)
- [ ] Added Roxygen2 or header documentation
- [ ] Validated inputs with assertions
- [ ] Logged significant operations
- [ ] Created checkpoints (modules) or returned structured results (orchestrators)
- [ ] Registered artifacts in registry
- [ ] Rendered validation HTML reports
- [ ] Tested for errors with informative messages
- [ ] No global variables or side effects

### Before Calling Phase Orchestrators
- [ ] Sourced R/functions/load_all.R
- [ ] Sourced phase orchestrator files
- [ ] Prepared for structured result passing
- [ ] Ready to handle human-in-the-loop (Phase 2)

### Before Writing New Standards
- [ ] Reviewed ST_ORCHESTRATION_PHILOSOPHY.md
- [ ] Checked existing standards for overlaps
- [ ] Aligned with phase orchestration philosophy
- [ ] Updated terminology to current standards

---

## ACKNOWLEDGMENTS

This standards system synthesizes best practices from:
- Tidyverse style guide
- Google R style guide
- rOpenSci development guide
- Scientific reproducibility literature
- Bat acoustic analysis domain expertise
- Real-world pipeline development experience
- Phase orchestration architecture patterns

---

**Version 3.0 - Checkpointed Phase Orchestration (2026-02-08)**

For the most current architecture concepts, always consult [ST_ORCHESTRATION_PHILOSOPHY.md](ST_ORCHESTRATION_PHILOSOPHY.md) first.

