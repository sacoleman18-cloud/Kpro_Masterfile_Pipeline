# =============================================================================
# load_all.R - MASTER FUNCTION LOADER
# =============================================================================
#
# PURPOSE
# -------
# Sources all function modules in strict dependency order. Run this once at
# the top of any workflow script to load the complete function library.
#
# USAGE
# -----
#   source("R/functions/load_all.R")
#
# DEPENDENCY LAYERS
# -----------------
# Functions are organized into layers. Each layer may depend on previous
# layers but NEVER on subsequent layers. This prevents circular dependencies.
#
#   Layer 1: core/
#   Layer 2: ingestion/
#   Layer 3: standardization/
#   Layer 4: validation/
#   Layer 5: analysis/
#   Layer 6: output/
#   Layer 7: pipeline/ (Phase Orchestrators - Checkpointed Execution)
#   Layer 8: modules/  (7 Processing Modules)
#   Layer 9: modules/module_runner.R (Module Execution Layer)
#
# =============================================================================

# Load required packages
library(dplyr, quietly = TRUE)
library(tidyr, quietly = TRUE)
library(quarto, quietly = TRUE)
library(zip, quietly = TRUE)
library(here, quietly = TRUE)

# -----------------------------------------------------------------------------
# Helper: consistent module sourcing with clean messaging
# -----------------------------------------------------------------------------
source_module <- function(path, label = NULL, optional = FALSE) {
  full_path <- here::here(path)
  
  if (!file.exists(full_path)) {
    if (optional) {
      message(sprintf("  └── [SKIP] %s (missing)", basename(full_path)))
      return(invisible(FALSE))
    } else {
      stop(sprintf("Required module missing: %s", full_path))
    }
  }
  
  source(full_path)
  
  if (!is.null(label)) {
    message(sprintf("  ├── [OK] %s", label))
  } else {
    message(sprintf("  ├── [OK] %s", basename(full_path)))
  }
  
  invisible(TRUE)
}


# =============================================================================
# LAYER 1: CORE
# ==============================================================================
message("[1/9] Loading Layer 1: core/")

source_module(file.path("R", "functions", "core", "utilities.R"), "utilities.R                   (I/O, paths, templates)")
source_module(file.path("R", "functions", "core", "orchestration_helpers.R"), "orchestration_helpers.R       (orchestrator convenience functions)")
source_module(file.path("R", "functions", "core", "logging.R"),   "logging.R                     (file logging)")
source_module(file.path("R", "functions", "core", "console.R"),   "console.R                     (console formatting)")
source_module(file.path("R", "functions", "core", "config.R"),    "config.R                      (YAML parameter management)")
source_module(file.path("R", "functions", "core", "artifacts.R"), "artifacts.R                   (artifact registry & provenance)")
source_module(file.path("R", "functions", "core", "release.R"),   "release.R                     (release bundle generator)")

message("  └── Layer 1 loaded")


# =============================================================================
# LAYER 2: INGESTION
# =============================================================================
message("[2/9] Loading Layer 2: ingestion/")

source_module(file.path("R", "functions", "ingestion", "ingestion.R"), "ingestion.R (raw data loading)")

message("  └── Layer 2 loaded")


# =============================================================================
# LAYER 3: STANDARDIZATION
# =============================================================================
message("[3/9] Loading Layer 3: standardization/")

source_module(file.path("R", "functions", "standardization", "schema_helpers.R"),   "schema_helpers.R       (schema version detection)")
source_module(file.path("R", "functions", "standardization", "standardization.R"),  "standardization.R      (schema transformation)")
source_module(file.path("R", "functions", "standardization", "datetime_helpers.R"), "datetime_helpers.R     (timezone handling)")

message("  └── Layer 3 loaded")


# =============================================================================
# LAYER 4: VALIDATION
# =============================================================================
message("[4/9] Loading Layer 4: validation/")

source_module(file.path("R", "functions", "validation", "validation.R"),            "validation.R            (data quality validation)")
source_module(file.path("R", "functions", "validation", "validation_reporting.R"), "validation_reporting.R  (execution tracking & reporting)")

message("  └── Layer 4 loaded")


# =============================================================================
# LAYER 5: ANALYSIS
# =============================================================================
message("[5/9] Loading Layer 5: analysis/")

source_module(file.path("R", "functions", "analysis", "callspernight.R"),    "callspernight.R    (CPN templates, recording hours)")
source_module(file.path("R", "functions", "analysis", "detector_mapping.R"), "detector_mapping.R (detector name management)")
source_module(file.path("R", "functions", "analysis", "summarization.R"),    "summarization.R    (summary statistics)")

message("  └── Layer 5 loaded")


# =============================================================================
# LAYER 6: OUTPUT
# =============================================================================
message("[6/9] Loading Layer 6: output/")

# Plot helpers FIRST
source_module(file.path("R", "functions", "output", "plot_helpers.R"), "plot_helpers.R (shared plotting utilities)")

# Plot modules
source_module(file.path("R", "functions", "output", "plot_quality.R"),   "plot_quality.R   (data quality visualizations)")
source_module(file.path("R", "functions", "output", "plot_detector.R"),  "plot_detector.R  (detector performance plots)")
source_module(file.path("R", "functions", "output", "plot_species.R"),   "plot_species.R   (species composition plots)")
source_module(file.path("R", "functions", "output", "plot_temporal.R"),  "plot_temporal.R  (temporal activity plots)")

# Tables + report
source_module(file.path("R", "functions", "output", "tables.R"), "tables.R (GT table formatting)")
source_module(file.path("R", "functions", "output", "report.R"), "report.R (Quarto report generator)")

message("  └── Layer 6 loaded")


# =============================================================================
# LAYER 7: PHASE ORCHESTRATORS (CHECKPOINTED PIPELINE)
# =============================================================================
message("[7/9] Loading Layer 7: pipeline/ (Phase Orchestrators)")

# Phase-based orchestrators (execute modules in checkpointed phases)
source_module(file.path("R", "pipeline", "run_phase1_data_preparation.R"),
              "run_phase1_data_preparation.R (Phase 1: Modules 1-2)",
              optional = TRUE)

source_module(file.path("R", "pipeline", "run_phase2_template_generation.R"),
              "run_phase2_template_generation.R (Phase 2: Module 3 + Human-in-Loop)",
              optional = TRUE)

source_module(file.path("R", "pipeline", "run_phase3_analysis_reporting.R"),
              "run_phase3_analysis_reporting.R (Phase 3: Modules 4-7)",
              optional = TRUE)

message("  └── Layer 7 loaded")


# =============================================================================
# LAYER 8: MODULES (Complete Pipeline)
# =============================================================================
message("[8/9] Loading Layer 8: modules/")

# Chunk 1 modules (Data Ingestion & Standardization)
source_module(file.path("R", "modules", "data_ingestion.R"),
              "data_ingestion.R (Raw data loading - Module Stages 1-2)",
              optional = TRUE)

source_module(file.path("R", "modules", "data_standardization.R"),
              "data_standardization.R (Schema transform & filters - Module Stages 3-8)",
              optional = TRUE)

# Chunk 2 modules (CPN Template)
source_module(file.path("R", "modules", "cpn_template.R"),
              "cpn_template.R (CPN template generation - Module Stages 1-9)",
              optional = TRUE)

# Chunk 3 modules (Finalize to Report)
source_module(file.path("R", "modules", "finalize_cpn.R"),
              "finalize_cpn.R (CPN finalization - Module Stages 1-6)",
              optional = TRUE)

source_module(file.path("R", "modules", "summary_stats.R"),
              "summary_stats.R (Summary statistics - Module Stages 7-16)",
              optional = TRUE)

source_module(file.path("R", "modules", "plotting.R"),
              "plotting.R (Exploratory plots - Module Stages 15-21)",
              optional = TRUE)

source_module(file.path("R", "modules", "report_release.R"),
              "report_release.R (Report & release - Module Stages 22-25)",
              optional = TRUE)

message("  └── Layer 8 loaded")


# =============================================================================
# CONFIRMATION
# =============================================================================

message("
================================================================================
 KPRO MASTERFILE PIPELINE - FUNCTIONS LOADED
================================================================================

 Layer 1: core/
          ├─ utilities.R ............  I/O, checkpoints, paths
          │                            (12 functions total)
          │                            • Directory: 1 | Safe I/O: 2
          │                            • File Discovery: 1 | Checkpoints: 5
          │                            • Paths: 2 | Templates: 1
          │                            • Operators: 1 (excludes logging)
          ├─ logging.R ..............  File logging
          │                            (2 functions + 1 internal helper)
          │                            • log_message()
          │                            • initialize_pipeline_log()
          ├─ console.R ..............  Console formatting
          │                            (5 functions)
          │                            • center_text()
          │                            • print_stage_header()
          │                            • print_stage_banner()
          │                            • print_workflow_summary()
          │                            • print_pipeline_complete()
          ├─ config.R ...............  YAML parameter management
          │                            (7 functions)
          ├─ artifacts.R ............  Artifact registry & provenance
          │                            (11 functions total)
          │                            • Registry: 5
          │                            • Hashing & Provenance: 3
          │                            • RDS Management: 1
          │                            • RDS Discovery: 2
          └─ release.R ..............  Release bundle generator
                                       (3 functions: 2 public + 1 internal)

 Layer 2: ingestion/
          └─ ingestion.R ............  Raw data loading + intro-standardization
                                       (3 functions: 2 public + 1 internal)

 Layer 3: standardization/
          ├─ schema_helpers.R .......  Schema version detection
          │                            (3 functions)
          ├─ standardization.R ......  Schema transformation + species codes
          │                            (8 functions + 1 constant)
          │                            • Constant(s): 1
          │                            • Functions: 8
          └─ datetime_helpers.R .....  Timezone handling + date/time parsing
                                       (8 functions)

 Layer 4: validation/
          ├─ validation.R ...........  Assertions, validators, enforcement
          │                            (20 functions)
          │                            • Universal Assertions: 11
          │                            • Composite Validators: 3
          │                            • Schema Enforcement: 2
          │                            • Master Finalization: 1
          │                            • Quality Checks: 3
          └─ validation_reporting.R .  Execution tracking & HTML validation reports
                                       (6 functions)
                                       • Event Tracking: 2
                                       • Report Generation: 2
                                       • Orchestrator Helpers: 2

 Layer 5: analysis/
          ├─ callspernight.R ........  Template generation, recording hours
          │                            (9 functions)
          ├─ detector_mapping.R .....  Detector name management
          │                            (3 functions)
          └─ summarization.R ........  Summary statistics
                                       (9 functions)

 Layer 6: output/
          ├─ plot_helpers.R .........  Shared plotting utilities
          │                            (6 functions)
          │                            • Theme: 1
          │                            • Palettes: 3
          │                            • Validation: 1
          │                            • Formatting: 2
          ├─ plot_quality.R .........  Data quality visualizations
          │                            (8 functions)
          ├─ plot_detector.R ........  Detector performance plots
          │                            (7 functions)
          ├─ plot_species.R .........  Species composition plots
          │                            (5 functions)
          ├─ plot_temporal.R ........  Temporal pattern plots
          │                            (6 functions)
          ├─ tables.R ...............  GT table formatting
          │                            (5 functions)
          └─ report.R ...............  Quarto report generation
                                       (1 function)

 Layer 7: pipeline/ (Phase Orchestrators - Checkpointed Pipeline)
          ├─ run_phase1_data_preparation.R    Phase 1: Data Preparation (Modules 1-2)
          ├─ run_phase2_template_generation.R Phase 2: Template Generation (Module 3)
          └─ run_phase3_analysis_reporting.R  Phase 3: Analysis & Reporting (Modules 4-7)

 Layer 8: modules/ (Complete Pipeline - 7 Modules)
          [Chunk 1: Ingestion & Standardization]
          ├─ data_ingestion.R ...........  Raw data loading (1 function)
          └─ data_standardization.R .....  Schema transform & filters (1 function)
          
          [Chunk 2: CPN Template]
          └─ cpn_template.R .............  CPN template generation (1 function)
          
          [Chunk 3: Finalize to Report]
          ├─ finalize_cpn.R .............  CPN finalization (1 function)
          ├─ summary_stats.R ............  Summary statistics (1 function)
          ├─ plotting.R .................  Exploratory visualizations (1 function)
          └─ report_release.R ...........  Report generation & release (1 function)

 Layer 9: modules/ (Module Execution Layer)
          └─ module_runner.R ............  Module execution interface (7 runners + 1 runner)

 ARCHITECTURE OVERVIEW
 ──────────────────────
 Layer 1-6: Utility/Helper Functions (R/functions/)
            - Reusable functions organized by domain
            - No orchestration logic
            - Safe I/O, validation, analysis, and visualization helpers

 Layer 7: Pipeline Orchestrators (R/pipeline/)
          - PHASE ORCHESTRATORS (Official Pattern):
            * run_phase1_data_preparation()    - Phase 1: Data Preparation (Modules 1-2)
            * run_phase2_template_generation() - Phase 2: Template with Human-in-Loop (Module 3)
            * run_phase3_analysis_reporting()  - Phase 3: Analysis & Reporting (Modules 4-7)
            * Checkpointed execution with structured result passing
            * Strict separation: orchestration ↔ processing modules

 Layer 8: Processing Modules (R/modules/)
          - Thematic subsystems with internal staged execution
          - 7 total modules across 3 pipeline chunks
          - Each module contains internal 'module stages' numbered sequentially
          - Modules are self-contained: load → process → save → validate

 Layer 9: Module Execution Layer (R/modules/module_runner.R)
          - Provides callable interfaces for all 7 pipeline modules
          - Used by phase orchestrators to execute modules
          - Supports individual module testing and custom execution sequences
          - Core infrastructure for checkpointed phase orchestration

 LEGACY: Original 01-07 workflow scripts remain in R/ root (preserved for reference)

================================================================================
 TOTAL LOADED: 120+ functions across 27+ modules
 VALIDATION: 2-module system (data validation + execution reporting)
 ORCHESTRATION: All 3 chunks fully modularized
================================================================================

 Ready to run:
   • Phase Orchestrators (Checkpointed Pipeline - RECOMMENDED):
     - run_phase1_data_preparation(verbose=TRUE)      # Phase 1: Data Preparation
     - run_phase2_template_generation(phase1_result)  # Phase 2: Template Generation
     - run_phase3_analysis_reporting(phase2_result)   # Phase 3: Analysis & Reporting
   
   • Module Execution Layer (for testing individual modules):
     - source('R/modules/module_runner.R')
     - run_module_ingestion()
     - run_module_standardization()
     - run_module_cpn_template()
     - run_module_finalize_cpn()
     - run_module_summary_stats()
     - run_module_plotting()
     - run_module_report_release()

 Usage (Phase Orchestration - RECOMMENDED):
   # Phase scripts are automatically loaded, no need to source explicitly
   phase1_result <- run_phase1_data_preparation(verbose = TRUE)
   phase2_result <- run_phase2_template_generation(phase1_result, verbose = TRUE)
   # [User edits CPN_Template_EDIT_THIS.csv]
   phase3_result <- run_phase3_analysis_reporting(phase2_result, verbose = TRUE)

 Usage (Module-Level Testing):
   # For testing individual modules independently
   source('R/modules/module_runner.R')
   r1 <- run_module_ingestion(verbose = TRUE)
   r2 <- run_module_standardization(r1, verbose = TRUE)
   r3 <- run_module_cpn_template(r2, verbose = TRUE)

================================================================================
")