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
#   Layer 7: pipeline/
#
# =============================================================================

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
# =============================================================================
message("[1/7] Loading Layer 1: core/")

source_module(file.path("R", "functions", "core", "utilities.R"), "utilities.R  (logging, I/O, checkpoints, paths)")
source_module(file.path("R", "functions", "core", "config.R"),    "config.R     (YAML parameter management)")
source_module(file.path("R", "functions", "core", "artifacts.R"), "artifacts.R  (artifact registry & provenance)")
source_module(file.path("R", "functions", "core", "release.R"),   "release.R    (release bundle generator)")

message("  └── Layer 1 loaded")


# =============================================================================
# LAYER 2: INGESTION
# =============================================================================
message("[2/7] Loading Layer 2: ingestion/")

source_module(file.path("R", "functions", "ingestion", "ingestion.R"),        "ingestion.R        (raw data loading)")
source_module(file.path("R", "functions", "ingestion", "schema_detection.R"), "schema_detection.R (row-level schema detection)")

message("  └── Layer 2 loaded")


# =============================================================================
# LAYER 3: STANDARDIZATION
# =============================================================================
message("[3/7] Loading Layer 3: standardization/")

source_module(file.path("R", "functions", "standardization", "standardization.R"),      "standardization.R     (schema transformation)")
source_module(file.path("R", "functions", "standardization", "datetime_conversion.R"), "datetime_conversion.R (timezone handling)")

message("  └── Layer 3 loaded")


# =============================================================================
# LAYER 4: VALIDATION
# =============================================================================
message("[4/7] Loading Layer 4: validation/")

source_module(file.path("R", "functions", "validation", "validation.R"),            "validation.R            (data quality validation)")
source_module(file.path("R", "functions", "validation", "validation_reporting.R"), "validation_reporting.R  (execution tracking & reporting)")

message("  └── Layer 4 loaded")


# =============================================================================
# LAYER 5: ANALYSIS
# =============================================================================
message("[5/7] Loading Layer 5: analysis/")

source_module(file.path("R", "functions", "analysis", "callspernight.R"),    "callspernight.R    (CPN templates, recording hours)")
source_module(file.path("R", "functions", "analysis", "detector_mapping.R"), "detector_mapping.R (detector name management)")
source_module(file.path("R", "functions", "analysis", "summarization.R"),    "summarization.R    (summary statistics)")

message("  └── Layer 5 loaded")


# =============================================================================
# LAYER 6: OUTPUT
# =============================================================================
message("[6/7] Loading Layer 6: output/")

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
# LAYER 7: PIPELINE
# =============================================================================
message("[7/7] Loading Layer 7: pipeline/")

# Pipeline scripts live in R/pipeline/
source_module(file.path("R", "pipeline", "run_ingest_standardize.R"),
              "run_ingest_standardize.R (Chunk 1 orchestrator)",
              optional = TRUE)

source_module(file.path("R", "pipeline", "run_cpn_template.R"),
              "run_cpn_template.R (Chunk 2 orchestrator - planned)",
              optional = TRUE)

source_module(file.path("R", "pipeline", "run_finalize_to_report.R"),
              "run_finalize_to_report.R (Chunk 3 orchestrator - planned)",
              optional = TRUE)

message("  └── Layer 7 loaded")


# =============================================================================
# CONFIRMATION
# =============================================================================

message("
================================================================================
 KPRO MASTERFILE PIPELINE - FUNCTIONS LOADED
================================================================================

 Layer 1: core/
          ├─ utilities.R ............  Logging, I/O, checkpoints, paths
          │                            (15 functions total)
          │                            • Directory: 1 | Logging: 2
          │                            • Safe I/O: 2 | File Discovery: 1
          │                            • Checkpoints: 5 | Paths: 2
          │                            • Templates: 1 | Operators: 1
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
          ├─ ingestion.R ............  Raw data loading + intro-standardization
          │                            (3 functions: 2 public + 1 internal)
          └─ schema_detection.R .....  Row-level KPro version detection
                                       (5 functions)

 Layer 3: standardization/
          ├─ standardization.R ......  Schema transformation + species codes
          │                            (8 functions + 1 constant)
          │                            • Constant(s): 1
          │                            • Functions: 8
          └─ datetime_conversion.R ..  Timezone handling
                                       (3 functions)

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

 Layer 7: pipeline/
          └─ run_ingest_standardize.R  Chunk 1: Ingest & Standardize
                                        (1 function)
              ├─ [run_cpn_template.R - PLANNED for Chunk 2]
              └─ [run_finalize_to_report.R - PLANNED for Chunk 3]

================================================================================
 TOTAL LOADED: 104 functions + 1 constant across 19 modules
 VALIDATION: 2-module system (data validation + execution reporting)
 ORCHESTRATION: 1 of 3 chunks implemented
================================================================================

 Ready to run:
   • Orchestrating functions: run_ingest_standardize()
   • Legacy workflow scripts: 01-07 (interactive/debug)

 Usage:
   source('R/functions/load_all.R')
   result <- run_ingest_standardize(verbose = TRUE)

================================================================================
")