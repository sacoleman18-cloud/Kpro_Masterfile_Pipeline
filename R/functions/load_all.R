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
#            └── Zero internal dependencies. Loaded first.
#
#   Layer 2: ingestion/
#            └── Depends on core/
#
#   Layer 3: standardization/
#            └── Depends on core/, ingestion/
#
#   Layer 4: validation/
#            └── Depends on core/
#
#   Layer 5: analysis/
#            └── Depends on core/, validation/
#
#   Layer 6: output/
#            └── Depends on core/, analysis/
#
# ADDING NEW MODULES
# ------------------
# 1. Identify which layer the new module belongs to
# 2. Add source() call in the appropriate section below
# 3. Update the confirmation message
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
#   utilities.R        - Logging, safe I/O, config, versioned saves
#   schema_detection.R - Row-level KPro version detection
#   config.R           - Creates the study_parameters.yaml
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
#   ingestion.R - load_local_raw_data(), load_external_raw_data(),
#                 apply_intro_standardization()
# -----------------------------------------------------------------------------

source(file.path(base_path, "ingestion/ingestion.R"))


# =============================================================================
# LAYER 3: STANDARDIZATION
# =============================================================================
# Schema transformation, species code conversion, master file creation.
#
# Dependencies: core/utilities.R, core/schema_detection.R, ingestion/ingestion.R
#
# Contents:
#   standardization.R - transform_v1/v2/v3_to_unified(), convert_4letter_to_6letter(),
#                       standardize_kpro_schema(), SPECIES_CODE_MAP_4_TO_6
# -----------------------------------------------------------------------------

source(file.path(base_path, "standardization/standardization.R"))
source(file.path(base_path, "standardization/datetime_conversion.R"))


# =============================================================================
# LAYER 4: VALIDATION
# =============================================================================
# Data quality checks, schema enforcement, template validation.
#
# Dependencies: core/utilities.R
#
# Contents:
#   validation.R - enforce_master_schema(), check_column_completeness(),
#                  check_duplicates(), validate_calls_per_night()
# -----------------------------------------------------------------------------

source(file.path(base_path, "validation/validation.R"))


# =============================================================================
# LAYER 5: ANALYSIS
# =============================================================================
# Recording hours, CallsPerNight workflow, detector mapping, summarization.
#
# Dependencies: core/utilities.R, validation/validation.R
#
# Contents:
#   callspernight.R    - calculate_recording_hours(), generate_calls_per_night_template(),
#                        apply_schedule(), save_callspernight_with_version()
#   detector_mapping.R - load_detector_mapping(), apply_detector_names(),
#                        generate_mapping_template()
#   summarization.R    - create_detector_activity_summary(), create_study_summary(),
#                        calculate_variance_components(), create_species_summary_by_detector(),
#                        create_species_accumulation_summary(), create_hourly_activity_summary(),
#                        calculate_coefficient_of_variation(), create_effort_summary_table()
# -----------------------------------------------------------------------------

source(file.path(base_path, "analysis/callspernight.R"))
source(file.path(base_path, "analysis/detector_mapping.R"))
source(file.path(base_path, "analysis/summarization.R"))


# =============================================================================
# LAYER 6: OUTPUT
# =============================================================================
# Visualizations, GT tables, and report generation helpers.
#
# Dependencies: core/utilities.R, analysis/summarization.R
#
# Contents:
#   visualization.R - plot_recording_effort_heatmap(), plot_activity_over_time(),
#                     plot_correlation_heatmap(), plot_synchrony(), etc.
#   tables.R        - format_detector_summary_gt(), format_species_summary_gt(),
#                     format_study_summary_gt(), format_hourly_summary_gt(),
#                     save_gt_table()
# -----------------------------------------------------------------------------

source(file.path(base_path, "output/visualization.R"))
source(file.path(base_path, "output/tables.R"))


# =============================================================================
# CONFIRMATION
# =============================================================================

message("
================================================================================
 KPRO MASTERFILE PIPELINE — FUNCTIONS LOADED
================================================================================

 Layer 1: core/
          ├── utilities.R
          ├── schema_detection.R
          └── config.R

 Layer 2: ingestion/
          └── ingestion.R

 Layer 3: standardization/
          ├── standardization.R
          └── datetime_conversion.R

 Layer 4: validation/
          └── validation.R

 Layer 5: analysis/
          ├── callspernight.R
          ├── detector_mapping.R
          └── summarization.R

 Layer 6: output/
          ├── visualization.R
          └── tables.R

================================================================================
 Ready. Run your workflow scripts.
================================================================================
")