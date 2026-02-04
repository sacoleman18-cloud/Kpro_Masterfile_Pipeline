# ==============================================================================
# KPro MASTERFILE PIPELINE: CODING STANDARDS INDEX
# ==============================================================================
# VERSION: 2.3
# LAST UPDATED: 2026-01-31
# PURPOSE: Navigation hub and core philosophy for modular coding standards
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

---

## STANDARDS DOCUMENT INDEX

The coding standards are organized into focused modules for targeted reference:

| File | Focus Area | Use When... |
|------|------------|-------------|
| `01_architecture_standards.md` | Project structure, file naming, paths, execution models | Organizing files, adding directories, understanding pipeline flow |
| `02_documentation_standards.md` | Headers, Roxygen2, comments, collaboration | Documenting functions, writing workflow/orchestrating headers |
| `03_code_design_standards.md` | Function design, error handling, style, assertions | Writing functions, handling errors, code review |
| `04_data_standards.md` | Data handling, quality, validation, hashing, filters | Validating data, adding quality checks, fingerprinting |
| `05_logging_console_standards.md` | Logging, console output, progress indicators, verbose gating | Adding logging, formatting console messages |
| `06_quarto_reporting_standards.md` | Quarto integration, reports, manifest | Working with Quarto, generating reports |
| `07_artifact_release_standards.md` | Artifact registry, release bundles | Registering outputs, creating release packages |
| `08_development_standards.md` | Git, testing, dependencies, YAML config | Version control, writing tests, managing packages |
| `10_validation_artifact_standards.md` | Validation contexts, artifact helpers, checkpoint/template loaders | Using validation HTML helpers, save/register RDS, and checkpoint/template discovery |
| `09_appendices.md` | Templates, inventories, checklists, quick reference | Looking up templates, function lists, checklists |

---

## QUICK REFERENCE

### Pipeline Architecture

**Shiny-Driven Chunks (Primary Execution Model):**
```
run_ingest_standardize()  ->  [DECISION: Manual ID?]  ->  run_cpn_template()
         |                                                      |
    [kpro_master]                                    [cpn_template]
    [validation HTML]                                      |
                                                    [DECISION: Edit hours?]
                                                           |
                                                           v
                                              run_finalize_to_report()
                                                           |
                                    +----------+-----------+-----------+
                                    v          v           v           v
                              [cpn_final] [summary.rds] [plots.rds] [report.html]
```

**Legacy Workflow Scripts (Interactive/Debug Use):**
```
01_ingest -> 02_standardize -> 03_cpn_template -> [USER EDIT] -> 04_finalize
                                                                      |
                                              07_report <- 06_plots <- 05_stats
```

### Key Directories
```
data/raw/           -> Input CSVs
outputs/checkpoints/-> Intermediate files  
outputs/final/      -> User-facing outputs (Master, templates)
results/csv/        -> Final data products (CPN)
results/figures/    -> Plots (PNG/SVG)
results/rds/        -> R objects for reuse
results/reports/    -> Rendered HTML reports
results/releases/   -> Portable zip bundles
results/validation/ -> Validation reports
```

### Essential Functions
```r
# Paths
here::here("results", "csv", "file.csv")

# Logging  
log_message("Processing started")

# Console formatting
print_stage_header("2.1", "Load Data")

# Artifact registration
registry <- init_artifact_registry()
register_artifact(registry, name, type, workflow, path)

# Validation tracking
context <- create_validation_context(workflow = "ingest")
log_validation_event(context, "files_loaded", "Loaded CSVs", count = 5)
finalize_validation_report(context)

# Orchestrating Functions (Shiny integration)
result <- run_ingest_standardize(verbose = TRUE)
result$kpro_master           # Access data
result$validation_html_path  # Review validation

# Centralized Assertions
assert_file_exists(path, hint = "Run Chunk 1 first")
assert_columns_exist(df, c("Detector", "Night"))
assert_not_empty(df, "kpro_master")
```

---

## VERSION HISTORY

**v2.3 (2026-01-31)**
- Transitioned from workflow scripts to Shiny-driven orchestrating functions
- Added chunk model: run_ingest_standardize(), run_cpn_template(), run_finalize_to_report()
- Updated pipeline flow diagrams for dual execution models
- Added orchestrating function examples to quick reference
- Documented verbose parameter pattern for Shiny integration
- Added centralized assertion functions documentation
- Added data filters (YAML-configured) documentation

**v2.2 (2026-01-20)**
- Modularized standards into 9 focused documents
- Added artifact registry system
- Added dataset fingerprinting & hashing
- Added validation report system  
- Added console formatting functions (print_stage_header, etc.)
- Added release bundle system
- Added comprehensive manifest structure
- Updated workflow 07 to include release bundle creation

**v2.1 (2026-01-09)**
- Added Workflow 07 Report Standards
- Comprehensive Quarto integration patterns

**v2.0 (2026-01-08)**
- Major update for complete pipeline (Workflows 01-07)
- Added hierarchical directory structure
- Added Layer Responsibilities section

**v1.0 (2025-12-26)**
- Initial comprehensive standards document
- Covered Workflows 01-03

---

## USAGE IN CLAUDE CHATS

Reference specific standards files:
```
"Using architecture_standards, help me add a new output directory"
"Using data_standards, add hash verification to this loader"  
"Using documentation_standards, write the header for this function"
"Using artifact_standards, register these new outputs"
```

---

## ACKNOWLEDGMENTS

This standards document synthesizes best practices from:
- Tidyverse style guide
- Google R style guide
- rOpenSci development guide
- Scientific reproducibility literature
- Bat acoustic analysis domain expertise
- Real-world pipeline development experience
