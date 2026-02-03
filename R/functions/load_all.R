# =============================================================================
# load_all.R — MASTER FUNCTION LOADER
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
#            Base utilities with zero internal dependencies
#
#   Layer 2: ingestion/
#            File discovery, raw data loading, and schema detection
#
#   Layer 3: standardization/
#            Schema transformation and datetime handling
#
#   Layer 4: validation/
#            Input assertions and schema enforcement
#
#   Layer 5: analysis/
#            Recording hours, detector mapping, summarization
#
#   Layer 6: output/
#            Visualizations, GT tables, and report generation
#
#   Layer 7: pipeline/
#            Shiny-driven orchestrating functions
#
# ADDING NEW MODULES
# ------------------
# 1. Identify which layer the new module belongs to
# 2. Add source() call in the appropriate section below
# 3. Update the function listing in that section
# 4. Document dependencies in the module's header
#
# TROUBLESHOOTING
# ---------------
# "Object not found" errors usually mean:
#   - A module is sourced before its dependency
#   - A function was moved but load_all.R wasn't updated
#   - Check the layer ordering below
#
# =============================================================================


# =============================================================================
# LAYER 1: CORE
# =============================================================================
# Foundational utilities with ZERO internal dependencies.
# Everything else depends on these. Must be loaded first.
#
# Contents:
#   utilities.R — Logging, safe I/O, checkpoint loaders, path generation
#     Directory Management (1 function):
#       - ensure_dir_exists()
#
#     Logging (2 functions):
#       - log_message()
#       - initialize_pipeline_log()
#
#     Safe I/O (2 functions):
#       - safe_read_csv()
#       - convert_empty_to_na()
#
#     File Discovery (1 function):
#       - find_most_recent_file()
#
#     Checkpoint Management (5 functions):
#       - load_or_checkpoint()
#       - load_intro_standardized()
#       - load_master_data()
#       - load_cpn_final()
#       - load_cpn_template_original()
#
#     Path Generation (2 functions):
#       - make_output_path()
#       - make_versioned_path()
#
#     Template Utilities (1 function):
#       - fill_readme_template()
#
#     Console Formatting (4 functions):
#       - center_text()
#       - print_stage_header()
#       - print_workflow_summary()
#       - print_pipeline_complete()
#
#     Operators (1 function):
#       - %||%
#
#   config.R — YAML parameter management (7 functions)
#     - load_study_parameters()
#     - save_study_parameters()
#     - build_study_config()
#     - ensure_study_parameters()
#     - validate_study_config()
#     - get_external_sources()
#     - reconcile_detector_mapping()
#
#   artifacts.R — Artifact Registry & Provenance System (15 functions)
#     Registry Management (5 functions):
#       - init_artifact_registry()
#       - register_artifact()
#       - get_artifact()
#       - list_artifacts()
#       - get_latest_artifact()
#
#     Hashing & Provenance (3 functions):
#       - hash_file()
#       - hash_dataframe()
#       - verify_artifact()
#
#     Validation Tracking (4 functions):
#       - create_validation_context()
#       - log_validation_event()
#       - finalize_validation_report()
#       - generate_validation_html() (internal)
#
#     RDS Discovery (3 internal functions):
#       - discover_pipeline_rds()
#       - validate_rds_structure()
#       - sum_event_counts() + format_details() (internal helpers)
#
#   release.R — Study Release Bundle Generator (3 functions)
#     - create_release_bundle()
#     - validate_release_inputs()
#     - generate_manifest() (internal)
# -----------------------------------------------------------------------------

source(here::here("R", "functions", "core", "utilities.R"))
source(here::here("R", "functions", "core", "config.R"))
source(here::here("R", "functions", "core", "artifacts.R"))
source(here::here("R", "functions", "core", "release.R"))


# =============================================================================
# LAYER 2: INGESTION
# =============================================================================
# File discovery, reading, intro-standardization, and schema detection.
#
# Dependencies: core/utilities.R
#
# Contents:
#   ingestion.R — Raw data loading and intro-standardization (3 functions)
#     - load_local_raw_data()
#     - load_external_raw_data()
#     - apply_intro_standardization() (internal helper)
#
#   schema_detection.R — Row-level KPro version detection (5 functions)
#     - detect_row_schema()
#     - get_schema_summary()
#     - summarize_schema_distribution()
#     - get_dominant_schema()
#     - validate_schema_detection()
# -----------------------------------------------------------------------------

source(here::here("R", "functions", "ingestion", "ingestion.R"))
source(here::here("R", "functions", "ingestion", "schema_detection.R"))


# =============================================================================
# LAYER 3: STANDARDIZATION
# =============================================================================
# Schema transformation, species code conversion, datetime handling.
#
# Dependencies: core/, ingestion/
#
# Contents:
#   standardization.R — Schema transformation and species codes (9 items)
#     Constants (1 item):
#       - SPECIES_CODE_MAP_4_TO_6
#
#     Functions (8 functions):
#       - convert_4letter_to_6letter()
#       - harmonize_column_names()
#       - transform_v1_to_unified()
#       - transform_v2_to_unified()
#       - transform_v3_to_unified()
#       - standardize_kpro_schema()
#       - validate_unified_schema()
#       - enforce_unified_schema()
#
#   datetime_conversion.R — Timezone handling (3 functions)
#     - convert_datetime_to_local()
#     - is_valid_timezone()
#     - summarize_date_formats()
# -----------------------------------------------------------------------------

source(here::here("R", "functions", "standardization", "standardization.R"))
source(here::here("R", "functions", "standardization", "datetime_conversion.R"))


# =============================================================================
# LAYER 4: VALIDATION
# =============================================================================
# Data quality checks, input assertions, schema enforcement.
#
# Dependencies: core/utilities.R, core/config.R
#
# Contents:
#   validation.R — Comprehensive validation utilities (20 functions)
#
#     Universal Assertions (11 functions):
#       - assert_data_frame()
#       - assert_not_empty()
#       - assert_row_count()
#       - assert_columns_exist()
#       - assert_column_type()
#       - assert_not_na()
#       - assert_date_range()
#       - assert_time_format()
#       - assert_file_exists()
#       - assert_directory_exists()
#       - assert_scalar_string()
#
#     Composite Validators (3 functions):
#       - validate_data_frame()
#       - validate_cpn_data()
#       - validate_master_data()
#
#     Config Loaders (1 function):
#       - require_study_parameters()
#
#     Schema Enforcement (2 functions):
#       - enforce_unified_schema()
#       - finalize_master_columns()
#
#     Quality Checks (3 functions):
#       - check_column_completeness()
#       - check_duplicates()
#       - validate_calls_per_night()
# -----------------------------------------------------------------------------

source(here::here("R", "functions", "validation", "validation.R"))


# =============================================================================
# LAYER 5: ANALYSIS
# =============================================================================
# Recording hours, CallsPerNight workflow, detector mapping, summarization.
#
# Dependencies: core/, validation/
#
# Contents:
#   callspernight.R — Template generation and recording hours (9 functions)
#     - calculate_recording_hours()
#     - generate_calls_per_night_template()
#     - apply_schedule()
#     - save_callspernight_with_version()
#     - extract_time()
#     - parse_date_safe()
#     - parse_datetime_safe()
#     - is_Date()
#     - format_datetime_for_log()
#
#   detector_mapping.R — Detector name management (3 functions)
#     - load_detector_mapping()
#     - apply_detector_names()
#     - generate_mapping_template()
#
#   summarization.R — Summary statistics generation (9 functions)
#     - create_detector_activity_summary()
#     - create_study_summary()
#     - calculate_variance_components()
#     - create_species_summary_by_detector()
#     - create_species_accumulation_summary()
#     - create_hourly_activity_summary()
#     - create_effort_summary_table()
#     - calculate_coefficient_of_variation()
#     - save_master_with_timestamp()
# -----------------------------------------------------------------------------

source(here::here("R", "functions", "analysis", "callspernight.R"))
source(here::here("R", "functions", "analysis", "detector_mapping.R"))
source(here::here("R", "functions", "analysis", "summarization.R"))


# =============================================================================
# LAYER 6: OUTPUT
# =============================================================================
# Visualizations, GT tables, and report generation helpers.
#
# Dependencies: core/, analysis/
#
# OUTPUT LAYER STRUCTURE
# ----------------------
# The output layer consists of specialized plotting modules organized by
# visualization category. All modules depend on plot_helpers.R which provides
# shared utilities.
#
# Contents:
#   plot_helpers.R — Shared plotting utilities (6 functions)
#     Theme Functions (1 function):
#       - theme_kpro()
#
#     Color Palette Functions (3 functions):
#       - kpro_palette_cat()
#       - kpro_palette_seq()
#       - kpro_status_colors()
#
#     Validation Functions (1 function):
#       - validate_plot_input()
#
#     Formatting Utilities (2 functions):
#       - format_number()
#       - format_pct()
#
#   plot_quality.R — Data quality and effort visualizations (8 functions)
#     Recording Status (3 functions):
#       - plot_recording_status_summary()
#       - plot_recording_status_percent()
#       - plot_recording_status_overall()
#
#     Effort Analysis (3 functions):
#       - plot_effort_by_detector()
#       - plot_nights_by_detector()
#       - plot_recording_effort_heatmap()
#
#     Completeness (2 functions):
#       - plot_data_completeness_calendar()
#       - plot_missing_nights()
#
#   plot_detector.R — Detector performance and comparison (7 functions)
#     Activity Comparison (4 functions):
#       - plot_total_calls_by_detector()
#       - plot_detector_activity_caterpillar()
#       - plot_detector_boxplots()
#       - plot_activity_with_without_outliers()
#
#     Correlation Analysis (2 functions):
#       - plot_correlation_heatmap()
#       - plot_synchrony()
#
#     Ranking (1 function):
#       - plot_detector_rank_over_time()
#
#   plot_species.R — Species composition and diversity (5 functions)
#     Composition (2 functions):
#       - plot_species_composition_bar()
#       - plot_species_by_detector_heatmap()
#
#     Temporal Patterns (2 functions):
#       - plot_species_accumulation_curve()
#       - plot_species_hourly_profile()
#
#     Quality (1 function):
#       - plot_noid_proportion()
#
#   plot_temporal.R — Temporal activity patterns (6 functions)
#     Nightly Patterns (2 functions):
#       - plot_activity_over_time()
#       - plot_cumulative_calls_over_time()
#
#     Within-Night Patterns (2 functions):
#       - plot_hourly_activity_profile()
#       - plot_callsperhour_distribution()
#
#     Seasonal Patterns (2 functions):
#       - plot_weekly_activity()
#       - plot_activity_by_month()
#
#   tables.R — GT table formatting and export (5 functions)
#     Summary Tables (4 functions):
#       - format_detector_summary_gt()
#       - format_species_summary_gt()
#       - format_study_summary_gt()
#       - format_hourly_summary_gt()
#
#     Export Utilities (1 function):
#       - save_gt_table()
#
#   report.R — Quarto Report Generation (1 function)
#     - generate_quarto_report()
# -----------------------------------------------------------------------------

# Load plot helpers FIRST (all other plot modules depend on it)
source(here::here("R", "functions", "output", "plot_helpers.R"))

# Load plot modules in any order (they only depend on plot_helpers)
source(here::here("R", "functions", "output", "plot_quality.R"))
source(here::here("R", "functions", "output", "plot_detector.R"))
source(here::here("R", "functions", "output", "plot_species.R"))
source(here::here("R", "functions", "output", "plot_temporal.R"))

# Load GT table formatting
source(here::here("R", "functions", "output", "tables.R"))

# Load Quarto report generator
source(here::here("R", "functions", "output", "report.R"))


# =============================================================================
# LAYER 7: PIPELINE
# =============================================================================
# Shiny-driven orchestrating functions that combine multiple workflows.
# Each returns a structured list with data, metadata, and artifact paths.
#
# Dependencies: ALL previous layers (1-6)
#
# CHUNK MODEL
# -----------
# The pipeline consists of three chunks executed sequentially in the Shiny app:
#
#   Chunk 1: Ingest & Standardize
#            Raw CSVs → kpro_master + validation HTML
#            Decision Point: Export for Manual ID?
#
#   Chunk 2: Generate CPN Template
#            kpro_master → CPN template pair (original + editable)
#            Decision Point: Edit recording hours?
#
#   Chunk 3: Finalize to Report
#            Edited template → Final CPN + plots + report + release bundle
#            Decision Point: None (end of pipeline)
#
# CHARACTERISTICS
# ---------------
# All orchestrating functions:
#   - Silent by default (verbose = FALSE)
#   - Read all configuration from YAML
#   - Return structured lists (data + metadata + paths)
#   - Generate validation HTML reports
#   - Register artifacts in artifact_registry.yaml
#   - Use here::here() for all paths
#   - Never modify global environment
#   - Never prompt for user input
#
# Contents:
#   run_ingest_standardize.R — Chunk 1 orchestrating function (1 function)
#     - run_ingest_standardize()
#
#   run_cpn_template.R — Chunk 2 orchestrating function (PLANNED)
#     - run_cpn_template()
#
#   run_finalize_to_report.R — Chunk 3 orchestrating function (PLANNED)
#     - run_finalize_to_report()
# -----------------------------------------------------------------------------

# Source existing orchestrating functions from R/pipeline/ (NOT R/functions/pipeline/)
if (file.exists(here::here("R", "pipeline", "run_ingest_standardize.R"))) {
  source(here::here("R", "pipeline", "run_ingest_standardize.R"))
}

# Chunk 2 and 3 will be sourced when implemented
if (file.exists(here::here("R", "pipeline", "run_cpn_template.R"))) {
  source(here::here("R", "pipeline", "run_cpn_template.R"))
}

if (file.exists(here::here("R", "pipeline", "run_finalize_to_report.R"))) {
  source(here::here("R", "pipeline", "run_finalize_to_report.R"))
}


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
          │                            (15 functions: 12 public + 3 internal)
          └─ release.R ..............  Release bundle generator
                                       (3 functions: 2 public + 1 internal)

 Layer 2: ingestion/
          ├─ ingestion.R ............  Raw data loading
          │                            (3 functions: 2 public + 1 internal)
          └─ schema_detection.R .....  Row-level KPro version detection
                                       (5 functions)

 Layer 3: standardization/
          ├─ standardization.R ......  Schema transformation
          │                            (8 functions + 1 constant)
          └─ datetime_conversion.R ..  Timezone handling
                                       (3 functions)

 Layer 4: validation/
          └─ validation.R ...........  Assertions, validators, enforcement
                                       (20 functions)
                                       • Universal Assertions: 11
                                       • Composite Validators: 3
                                       • Config Loaders: 1
                                       • Schema Enforcement: 2
                                       • Quality Checks: 3

 Layer 5: analysis/
          ├─ callspernight.R ........  Template generation, recording hours
          │                            (9 functions)
          ├─ detector_mapping.R .....  Detector name management
          │                            (3 functions)
          └─ summarization.R ........  Summary statistics
                                       (9 functions)

 Layer 6: output/
          ├─ plot_helpers.R .........  Shared plotting utilities
          │                            (6 functions: 1 theme, 3 palette,
          │                             1 validation, 2 formatting)
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
              [run_cpn_template.R - PLANNED for Chunk 2]
              [run_finalize_to_report.R - PLANNED for Chunk 3]

================================================================================
 TOTAL LOADED: 104 functions + 1 constant across 19 modules
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