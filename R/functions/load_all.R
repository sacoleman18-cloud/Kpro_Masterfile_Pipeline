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
#            File discovery and raw data loading
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
#            Visualizations and GT tables
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

base_path <- "R/functions"


# =============================================================================
# LAYER 1: CORE
# =============================================================================
# Foundational utilities with ZERO internal dependencies.
# Everything else depends on these. Must be loaded first.
#
# Contents:
#   utilities.R — Logging, safe I/O, checkpoint loaders, path generation
#     - log_message()
#     - initialize_pipeline_log()
#     - safe_read_csv()
#     - convert_empty_to_na()
#     - fill_readme_template()
#     - find_most_recent_file()
#     - load_or_checkpoint()
#     - load_intro_standardized()
#     - load_master_data()
#     - load_cpn_final()
#     - load_cpn_template_original()
#     - make_output_path()
#     - make_versioned_path()
#
#   schema_detection.R — Row-level KPro version detection
#     - detect_row_schema()
#     - get_schema_summary()
#
#   config.R — YAML parameter management
#     - load_study_parameters()
#     - save_study_parameters()
#     - create_study_parameters_template()
# -----------------------------------------------------------------------------

source(file.path(base_path, "core/utilities.R"))
source(file.path(base_path, "core/schema_detection.R"))
source(file.path(base_path, "core/config.R"))


# =============================================================================
# LAYER 2: INGESTION
# =============================================================================
# File discovery, reading, and intro-standardization.
#
# Dependencies: core/utilities.R, core/schema_detection.R
#
# Contents:
#   ingestion.R — Raw data loading and intro-standardization
#     - load_local_raw_data()
#     - load_external_raw_data()
#     - apply_intro_standardization()
# -----------------------------------------------------------------------------

source(file.path(base_path, "ingestion/ingestion.R"))


# =============================================================================
# LAYER 3: STANDARDIZATION
# =============================================================================
# Schema transformation, species code conversion, datetime handling.
#
# Dependencies: core/, ingestion/
#
# Contents:
#   standardization.R — Schema transformation and species codes
#     - SPECIES_CODE_MAP_4_TO_6 (constant)
#     - convert_4letter_to_6letter()
#     - harmonize_column_names()
#     - transform_v1_to_unified()
#     - transform_v2_to_unified()
#     - transform_v3_to_unified()
#     - standardize_kpro_schema()
#
#   datetime_conversion.R — Timezone handling
#     - convert_datetime_to_local()
#     - add_derived_time_columns()
# -----------------------------------------------------------------------------

source(file.path(base_path, "standardization/standardization.R"))
source(file.path(base_path, "standardization/datetime_conversion.R"))


# =============================================================================
# LAYER 4: VALIDATION
# =============================================================================
# Data quality checks, input assertions, schema enforcement.
#
# Dependencies: core/utilities.R, core/config.R
#
# Contents:
#   validation.R — Comprehensive validation utilities
#
#     Universal Assertions:
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
#     Composite Validators:
#       - validate_data_frame()
#       - validate_cpn_data()
#       - validate_master_data()
#
#     Config Loaders:
#       - require_study_parameters()
#
#     Schema Enforcement:
#       - enforce_unified_schema()
#
#     Quality Checks:
#       - check_column_completeness()
#       - check_duplicates()
#       - validate_calls_per_night()
# -----------------------------------------------------------------------------

source(file.path(base_path, "validation/validation.R"))


# =============================================================================
# LAYER 5: ANALYSIS
# =============================================================================
# Recording hours, CallsPerNight workflow, detector mapping, summarization.
#
# Dependencies: core/, validation/
#
# Contents:
#   callspernight.R — Template generation and recording hours
#     - calculate_recording_hours()
#     - generate_calls_per_night_template()
#     - apply_schedule()
#     - save_callspernight_with_version()
#
#   detector_mapping.R — Detector name management
#     - load_detector_mapping()
#     - apply_detector_names()
#     - generate_mapping_template()
#
#   summarization.R — Summary statistics generation
#     - create_detector_activity_summary()
#     - create_study_summary()
#     - calculate_variance_components()
#     - create_species_summary_by_detector()
#     - create_species_accumulation_summary()
#     - create_hourly_activity_summary()
#     - calculate_coefficient_of_variation()
#     - create_effort_summary_table()
#     - save_master_with_timestamp()
# -----------------------------------------------------------------------------

source(file.path(base_path, "analysis/callspernight.R"))
source(file.path(base_path, "analysis/detector_mapping.R"))
source(file.path(base_path, "analysis/summarization.R"))


# =============================================================================
# LAYER 6: OUTPUT
# =============================================================================
# Visualizations, GT tables, and report generation helpers.
#
# Dependencies: core/, analysis/
#
# Contents:
#   visualization.R — Plotting functions
#     - plot_recording_effort_heatmap()
#     - plot_activity_over_time()
#     - plot_correlation_heatmap()
#     - plot_synchrony()
#     - plot_species_composition()
#
#   tables.R — GT table formatting and export
#     - format_detector_summary_gt()
#     - format_species_summary_gt()
#     - format_study_summary_gt()
#     - format_hourly_summary_gt()
#     - save_gt_table()
# -----------------------------------------------------------------------------

source(file.path(base_path, "output/visualization.R"))
source(file.path(base_path, "output/tables.R"))


# =============================================================================
# CONFIRMATION
# =============================================================================

message("
================================================================================
 KPRO MASTERFILE PIPELINE - FUNCTIONS LOADED
================================================================================

 Layer 1: core/
          |- utilities.R ............ Logging, I/O, checkpoints, paths
          |- schema_detection.R ..... Row-level KPro version detection
          |- config.R ............... YAML parameter management

 Layer 2: ingestion/
          |- ingestion.R ............ Raw data loading

 Layer 3: standardization/
          |- standardization.R ...... Schema transformation
          |- datetime_conversion.R .. Timezone handling

 Layer 4: validation/
          |- validation.R ........... Assertions, validators, enforcement

 Layer 5: analysis/
          |- callspernight.R ........ Template generation, recording hours
          |- detector_mapping.R ..... Detector name management
          |- summarization.R ........ Summary statistics

 Layer 6: output/
          |- visualization.R ........ Plots and figures
          |- tables.R ............... GT tables and export

================================================================================
 Ready. Run your workflow scripts.
================================================================================
")