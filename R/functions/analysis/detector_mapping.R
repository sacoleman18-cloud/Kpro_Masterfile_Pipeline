# =============================================================================
# analysis/detector_mapping.R — DETECTOR ID MAPPING (LOCKED CONTRACT)
# =============================================================================
# PURPOSE
# -------
# Maps raw detector_id values to human-readable Detector names using a
# user-provided CSV mapping file.
#
# DETECTOR MAPPING CONTRACT
# -------------------------
# All functions in this file MUST adhere to the following guarantees:
#
# 1. File-based mapping
#    - User provides detector_mapping.csv with columns: detector_id, Detector
#    - Mapping applied via left join (preserves all data rows)
#    - Unmapped detector_ids get Detector = NA with warning
#
# 2. Template generation
#    - generate_mapping_template() creates CSV with unique detector_ids
#    - User fills in Detector column manually
#
# 3. Validation
#    - Warns if detector_ids in data are missing from mapping
#    - Warns if mapping contains detector_ids not in data
#
# 4. Non-destructive
#    - Original detector_id column always preserved
#    - Adds Detector column, never replaces
#
# NON-GOALS (EXPLICITLY OUT OF SCOPE)
# ------------------------------------
# This module MUST NOT:
#   - Guess or auto-generate detector names
#   - Modify detector_id values
#   - Remove rows with unmapped detectors
#
# DEPENDENCIES
# ------------
#   - core/utilities.R: safe_read_csv, log_message
#   - dplyr: left_join, distinct
#
# CONTENTS
# --------
#   - load_detector_mapping()
#   - apply_detector_names()
#   - validate_detector_mapping()
#   - generate_mapping_template()
#
# MAPPING FILE FORMAT
# -------------------
#   detector_id,Detector
#   AUDIOMOTH_ABC123,Site_A_North
#   AUDIOMOTH_DEF456,Site_B_Creek
#
# =============================================================================

# TODO: Migrate from your current 05_detector_mapping.R
