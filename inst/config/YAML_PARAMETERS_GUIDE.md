# ==============================================================================
# STUDY_PARAMETERS.YAML CONFIGURATION GUIDE
# ==============================================================================
# VERSION: 2.4
# LAST UPDATED: 2026-02-01
# PURPOSE: Comprehensive guide for configuring KPro Masterfile Pipeline studies
# ==============================================================================

## OVERVIEW

The `study_parameters.yaml` file controls every aspect of your bat acoustic monitoring study. This file is automatically created by the Shiny app but can also be edited manually. All configuration is centralized in this single file.

**File Location:** `inst/config/study_parameters.yaml`

---

## FILE STRUCTURE

```yaml
config_version: 1
study_parameters:
  # Study identification and temporal scope
processing_options:
  # Recording schedules and workflow control
output_preferences:
  # File naming and output locations
```

---

## SECTION 1: CONFIG_VERSION

### config_version

**Type:** Integer  
**Required:** YES  
**Valid Values:** `1`  
**Default:** `1`

```yaml
config_version: 1
```

**Purpose:**  
Identifies the configuration schema version. Used by the pipeline to ensure compatibility.

**Rules:**
- Must always be `1` (current version)
- No quotes around the number
- Pipeline will error if missing or incorrect

---

## SECTION 2: STUDY_PARAMETERS

Contains all metadata about your study, detectors, and data sources.

### study_name

**Type:** String  
**Required:** YES  
**Format:** No special characters recommended  
**Example:** `SchmeeckleBatStudy`

```yaml
study_parameters:
  study_name: SchmeeckleBatStudy
```

**Purpose:**  
Human-readable study identifier used in reports and file names.

**Guidelines:**
- Use descriptive names that identify location or purpose
- Avoid spaces (use underscores or CamelCase)
- Keep under 50 characters
- Examples:
  - `NorthForest_2025`
  - `UrbanParkMonitoring`
  - `RiverCorridor_BatSurvey`

---

### start_date & end_date

**Type:** String (date)  
**Required:** YES  
**Format:** `'YYYY-MM-DD'` with quotes  
**Example:** `'2025-10-04'`

```yaml
study_parameters:
  start_date: '2025-10-04'
  end_date: '2025-10-31'
```

**Purpose:**  
Defines the temporal scope of your study. These are your INTENDED recording dates - the period you planned to have detectors in the field.

**Important Notes:**
- These dates define the study design, NOT the actual data range
- If you deployed late or retrieved early, keep these as intended dates
- The CallsPerNight template will include ALL nights in this range
- You'll edit the template to mark non-recording nights
- end_date must be >= start_date

**Examples:**

```yaml
# Full season monitoring
start_date: '2025-05-01'
end_date: '2025-09-30'

# Short-term survey
start_date: '2025-07-15'
end_date: '2025-07-21'

# Year-round monitoring
start_date: '2025-01-01'
end_date: '2025-12-31'
```

**Common Mistakes:**
- ❌ `start_date: 2025-10-04` (missing quotes)
- ❌ `start_date: '10/04/2025'` (wrong format)
- ❌ `start_date: 2025-10-4` (day must be 2 digits)
- ✅ `start_date: '2025-10-04'` (correct)

---

### detector_mapping

**Type:** Named list (detector ID: detector name)  
**Required:** YES  
**Format:** Indented key-value pairs

```yaml
study_parameters:
  detector_mapping:
    245AAA0666BC08AE: LPI
    245AAA0666BC1507: LPE
    247475035FDF1A0D: SMI
```

**Purpose:**  
Maps hardware serial numbers to human-readable detector names for analysis and reports.

**Detector ID (Serial Number):**
- Hexadecimal hardware identifier from Kaleidoscope Pro
- Automatically extracted from raw CSV files
- Cannot be changed (hardware-specific)
- Typically 16 characters
- Case-sensitive

**Detector Name (Your Label):**
- Short, memorable identifier (3-10 characters recommended)
- Used in all plots, tables, and reports
- Should reflect location or deployment context
- Examples:
  - Location codes: `NF1`, `NF2` (North Forest sites 1, 2)
  - Habitat types: `URB`, `FOR`, `WET` (Urban, Forest, Wetland)
  - Transect positions: `T1A`, `T1B`, `T2A`

**Best Practices:**
- Keep names short (3-5 characters ideal for plots)
- Use consistent naming scheme across study
- Consider alphabetical sorting (names appear sorted in outputs)
- Document your naming scheme separately

**Examples:**

```yaml
# Geographic naming
detector_mapping:
  ABC123: North
  ABC124: South
  ABC125: East
  ABC126: West

# Habitat naming
detector_mapping:
  ABC123: FRST
  ABC124: EDGE
  ABC125: OPEN

# Grid system
detector_mapping:
  ABC123: A1
  ABC124: A2
  ABC125: B1
  ABC126: B2
```

---

### timezone

**Type:** String  
**Required:** YES  
**Format:** IANA timezone identifier  
**Example:** `America/Chicago`

```yaml
study_parameters:
  timezone: America/Chicago
```

**Purpose:**  
Defines the local timezone for your study site. All datetime conversions use this timezone.

**Common US Timezones:**
- `America/New_York` - Eastern (EST/EDT)
- `America/Chicago` - Central (CST/CDT)
- `America/Denver` - Mountain (MST/MDT)
- `America/Phoenix` - Arizona (MST, no DST)
- `America/Los_Angeles` - Pacific (PST/PDT)
- `America/Anchorage` - Alaska (AKST/AKDT)
- `America/Honolulu` - Hawaii (HST, no DST)

**Find Your Timezone:**
- Full list: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
- Look for "TZ database name" column
- Format is always `Continent/City`
- Handles Daylight Saving Time automatically

**Important:**
- Use IANA format, NOT abbreviations
- ❌ `CST` or `CDT` (ambiguous)
- ✅ `America/Chicago` (correct)
- Pipeline converts UTC timestamps to this timezone

---

### external_data_sources

**Type:** String or List of strings  
**Required:** NO  
**Format:** File or folder paths  
**Example:** `F:/BatData/ManualIDs`

```yaml
study_parameters:
  external_data_sources: F:/BatData/Exports
  
  # OR multiple sources:
  external_data_sources:
    - F:/BatData/Exports
    - F:/BatData/ManualIDs
```

**Purpose:**  
Specifies additional CSV files or folders to merge with primary data. Used for manual species IDs or supplementary datasets.

**Use Cases:**
1. **Manual ID Integration:**
   - Export manual IDs from Kaleidoscope Pro
   - Specify the export folder here
   - Pipeline merges manual IDs with auto IDs

2. **Multi-Session Data:**
   - Multiple analysis sessions in Kaleidoscope Pro
   - Each session exported separately
   - List all export folders

3. **Supplementary Data:**
   - Weather data
   - Habitat classifications
   - Detection confidence scores

**Path Format:**
- Windows: Use forward slashes `/` (not backslashes `\`)
- Paths with spaces: Use quotes
- Absolute paths recommended
- Can be file or folder

**Examples:**

```yaml
# Single source
external_data_sources: F:/Schmeeckle analyzed 102725

# Multiple sources
external_data_sources:
  - F:/Session1_Export
  - F:/Session2_Export
  - F:/ManualIDs

# Path with spaces (quoted)
external_data_sources: 'F:/My Documents/Bat Data/Export'

# No external sources
external_data_sources: []
```

---

### data_filters

**Type:** Named list of booleans  
**Required:** NO (has defaults)  
**Format:** `key: true` or `key: false` (lowercase)

```yaml
study_parameters:
  data_filters:
    remove_noid: false
    remove_zero_pulse_calls: true
    remove_duplicates: true
```

**Purpose:**  
Controls optional data cleaning operations during ingestion.

#### remove_duplicates

**Default:** `true`  
**Recommended:** `true`

Removes exact duplicate detections (same Detector + DateTime + auto_id).

**When to use `true`:**
- Standard practice (most studies)
- Prevents inflated call counts
- Kaleidoscope Pro sometimes creates duplicates

**When to use `false`:**
- Troubleshooting data issues
- Investigating duplicate sources
- Comparing with pre-cleaned datasets

#### remove_noid

**Default:** `false`  
**Recommended:** `false` (keep NoID for quality analysis)

Removes all detections where auto_id = "NoID".

**When to use `true`:**
- Final analysis with only identified species
- Publication-ready datasets
- After manual ID verification

**When to use `false`:**
- Quality control analysis (see detection failure rates)
- Understanding detector performance
- Initial data exploration

#### remove_zero_pulse_calls

**Default:** `false`  
**Recommended:** `true` for most studies

Removes detections with zero pulses or NA pulse counts.

**When to use `true`:**
- Acoustic analysis (pulses required for metrics)
- Removing clearly erroneous detections
- Standard quality control

**When to use `false`:**
- Troubleshooting Kaleidoscope Pro exports
- Understanding zero-pulse sources
- Maximizing detection counts (not recommended)

---

## SECTION 3: PROCESSING_OPTIONS

Controls recording schedules and workflow behavior.

### detector_specific_schedules

**Type:** Boolean  
**Required:** YES  
**Valid Values:** `yes`, `no`, `true`, `false`  
**Default:** `no`  
**Recommended:** `no` (99% of studies)

```yaml
processing_options:
  detector_specific_schedules: no
```

**Purpose:**  
Determines if detectors have DIFFERENT intended recording times.

**What This Controls:**

**Option: `no` (Most Common)**
- All detectors have the SAME intended recording schedule
- Uses `recording_start` and `recording_end` below for ALL detectors
- Most bat studies use this (uniform deployment protocol)

**Option: `yes` (Rare)**
- Different detectors have DIFFERENT intended recording times
- Requires creating a `detector_schedules.csv` file
- Used for studies with detector-specific protocols

**When To Use `no`:**
- ✅ All detectors deployed with same protocol
- ✅ Standard monitoring program (e.g., all run 18:00-07:00)
- ✅ Equipment failures happened (handle with `generate_editable_template`)
- ✅ You need to edit specific nights (handle with template editing)

**When To Use `yes`:**
- Different detectors intentionally have different recording times
- Example: Detector A runs 18:00-07:00, Detector B runs 20:00-06:00
- Requires creating `detector_schedules.csv`:

```csv
Detector,StartTime,EndTime
LPI,18:00:00,07:00:00
LPE,20:00:00,06:00:00
SMI,19:00:00,08:00:00
```

**Common Confusion:**
- ❌ "I need to edit hours because detectors failed" → Use `no` + `generate_editable_template: yes`
- ❌ "Some nights had different recording times" → Use `no` + edit template manually
- ✅ "Detectors were DESIGNED to have different schedules" → Use `yes`

---

### generate_editable_template

**Type:** Boolean  
**Required:** YES  
**Valid Values:** `yes`, `no`, `true`, `false`  
**Default:** `yes`  
**Recommended:** `yes` (most studies)

```yaml
processing_options:
  generate_editable_template: yes
```

**Purpose:**  
Determines if the pipeline generates an EDIT_THIS template for manual recording hour adjustments.

**What This Controls:**

**Option: `yes` (Most Common)**
- Pipeline generates CallsPerNight template pre-filled with intended times
- Template saved as: `03_CallsPerNight_Template_EDIT_THIS_YYYYMMDD_HHMMSS.csv`
- You download, edit in Excel/Google Sheets, then re-upload
- Accounts for equipment failures, battery issues, SD card problems

**Option: `no` (Rare)**
- Pipeline applies schedule directly without manual editing
- Assumes PERFECT recording with no equipment failures
- Only use if you're absolutely certain no adjustments needed

**When To Use `yes`:**
- ✅ Any detector had equipment failures
- ✅ Batteries died mid-recording
- ✅ SD cards filled up
- ✅ Deployment times varied by detector
- ✅ Weather caused issues
- ✅ You're not 100% certain everything worked perfectly

**When To Use `no`:**
- Perfect controlled environment (e.g., lab calibration)
- Short-term study (<7 days) with constant monitoring
- You've already verified all detectors recorded full schedules

**Workflow with `yes`:**
1. Pipeline generates template with intended times
2. You download the EDIT_THIS CSV
3. Edit specific detector-nights with actual recording times
4. Save and re-upload edited file
5. Pipeline continues with your corrections

**Distinction from `detector_specific_schedules`:**
- `detector_specific_schedules`: **DESIGN** (intended different times)
- `generate_editable_template`: **REALITY** (equipment actually failed)

---

### recording_start & recording_end

**Type:** String (time)  
**Required:** YES (when `detector_specific_schedules: no`)  
**Format:** `'HH:MM:SS'` in 24-hour format with quotes  
**Example:** `'18:00:00'`

```yaml
processing_options:
  recording_start: '18:00:00'
  recording_end: '07:00:00'
```

**Purpose:**  
Defines the INTENDED uniform recording schedule for all detectors.

**Important Concepts:**

**These are INTENDED times, not ACTUAL times:**
- Set to your study design (what you planned)
- NOT the actual deployment times
- If you deployed late one night, keep these as intended
- Adjust actual times in the CallsPerNight template

**24-Hour Format:**
- `00:00:00` = Midnight
- `06:00:00` = 6:00 AM
- `12:00:00` = Noon
- `18:00:00` = 6:00 PM
- `23:59:59` = 11:59:59 PM

**Format Requirements:**
- MUST include quotes
- MUST use colons (`:`)
- MUST include seconds (`:00`)
- MUST use 2 digits for hour (e.g., `06:00:00`, not `6:00:00`)

**Common Recording Schedules:**

```yaml
# Sunset to sunrise (typical)
recording_start: '18:00:00'  # 6:00 PM
recording_end: '07:00:00'    # 7:00 AM

# Extended evening (summer)
recording_start: '20:00:00'  # 8:00 PM
recording_end: '06:00:00'    # 6:00 AM

# Full night (winter)
recording_start: '16:00:00'  # 4:00 PM
recording_end: '08:00:00'    # 8:00 AM

# Calibration test
recording_start: '12:00:00'  # Noon
recording_end: '13:00:00'    # 1:00 PM
```

**Time Conversion Reference:**

| 12-Hour | 24-Hour |
|---------|---------|
| 12:00 AM | `00:00:00` |
| 1:00 AM | `01:00:00` |
| 6:00 AM | `06:00:00` |
| 12:00 PM | `12:00:00` |
| 1:00 PM | `13:00:00` |
| 6:00 PM | `18:00:00` |
| 11:00 PM | `23:00:00` |

**Common Mistakes:**
- ❌ `recording_start: 18:00:00` (missing quotes)
- ❌ `recording_start: '18:00'` (missing seconds)
- ❌ `recording_start: '6:00:00'` (need 2 digits)
- ❌ `recording_start: '6:00:00 PM'` (use 24-hour format)
- ✅ `recording_start: '18:00:00'` (correct)

---

### intended_hours

**Type:** Numeric  
**Required:** YES  
**Format:** Number (no quotes)  
**Example:** `13`

```yaml
processing_options:
  intended_hours: 13
```

**Purpose:**  
Expected recording duration per night (hours). Used for validation and quality checks.

**Calculation:**
- If `recording_end` > `recording_start`: `end - start`
- If `recording_end` < `recording_start`: `(24 - start) + end` (crosses midnight)

**Examples:**

```yaml
# 18:00:00 to 07:00:00 (next day)
# (24 - 18) + 7 = 13 hours
intended_hours: 13

# 20:00:00 to 06:00:00 (next day)
# (24 - 20) + 6 = 10 hours
intended_hours: 10

# 16:00:00 to 08:00:00 (next day)
# (24 - 16) + 8 = 16 hours
intended_hours: 16

# 10:00:00 to 14:00:00 (same day)
# 14 - 10 = 4 hours
intended_hours: 4
```

**Usage:**
- Quality control reports flag nights < 90% of intended hours
- Helps identify equipment failures
- Used in recording effort calculations
- Can use decimals (e.g., `12.5` for 12.5 hours)

**Common Mistake:**
- ❌ `intended_hours: '13'` (quotes make it a string)
- ✅ `intended_hours: 13` (correct - no quotes)

---

## SECTION 4: OUTPUT_PREFERENCES

Controls file naming and output locations.

### master_filename

**Type:** String  
**Required:** YES  
**Format:** Filename with `.csv` extension  
**Default:** `final_master.csv`

```yaml
output_preferences:
  master_filename: final_master.csv
```

**Purpose:**  
Filename for the standardized master dataset (output of Chunk 1).

**Guidelines:**
- Must end in `.csv`
- Should be descriptive
- No spaces recommended (use underscores)

**Examples:**
```yaml
master_filename: kpro_master.csv
master_filename: SchmeeckleBats_Master_2025.csv
master_filename: BatData_Standardized.csv
```

---

### callspernight_filename

**Type:** String  
**Required:** YES  
**Format:** Filename with `.csv` extension  
**Default:** `CallsPerNight_final.csv`

```yaml
output_preferences:
  callspernight_filename: CallsPerNight_final.csv
```

**Purpose:**  
Filename for the finalized CallsPerNight dataset (output of Chunk 2).

**Guidelines:**
- Must end in `.csv`
- Clearly indicates it's the CPN dataset
- No spaces recommended

**Examples:**
```yaml
callspernight_filename: CPN_Schmeeckle_2025.csv
callspernight_filename: BatActivity_PerNight.csv
callspernight_filename: CallsPerNight_Final_v1.csv
```

---

### save_directory

**Type:** String  
**Required:** YES  
**Format:** Relative or absolute path  
**Default:** `results/csv`

```yaml
output_preferences:
  save_directory: results/csv
```

**Purpose:**  
Directory where final CSV outputs are saved.

**Path Guidelines:**
- Relative to project root recommended
- Use forward slashes `/`
- Pipeline creates directory if missing
- Don't include trailing slash

**Examples:**
```yaml
# Relative paths
save_directory: results/csv
save_directory: outputs/final
save_directory: data/processed

# Absolute paths (not recommended)
save_directory: C:/Projects/BatData/Results
save_directory: /home/user/bat-research/outputs
```

---

## COMPLETE EXAMPLE CONFIGURATIONS

### Example 1: Standard Urban Monitoring

```yaml
config_version: 1
study_parameters:
  study_name: UrbanParkStudy_2025
  start_date: '2025-06-01'
  end_date: '2025-08-31'
  detector_mapping:
    ABC001: PARK_N
    ABC002: PARK_S
    ABC003: PARK_E
    ABC004: PARK_W
  timezone: America/New_York
  external_data_sources: []
  data_filters:
    remove_noid: false
    remove_zero_pulse_calls: true
    remove_duplicates: true
processing_options:
  detector_specific_schedules: no
  generate_editable_template: yes
  recording_start: '20:00:00'
  recording_end: '06:00:00'
  intended_hours: 10
output_preferences:
  master_filename: UrbanPark_Master.csv
  callspernight_filename: UrbanPark_CPN.csv
  save_directory: results/csv
```

### Example 2: Multi-Site with Manual IDs

```yaml
config_version: 1
study_parameters:
  study_name: RiverCorridor_2025
  start_date: '2025-07-01'
  end_date: '2025-09-30'
  detector_mapping:
    DEF123: UP1
    DEF124: UP2
    DEF125: MID1
    DEF126: MID2
    DEF127: LOW1
    DEF128: LOW2
  timezone: America/Chicago
  external_data_sources:
    - F:/BatData/Session1_Export
    - F:/BatData/ManualIDs
  data_filters:
    remove_noid: false
    remove_zero_pulse_calls: true
    remove_duplicates: true
processing_options:
  detector_specific_schedules: no
  generate_editable_template: yes
  recording_start: '18:30:00'
  recording_end: '07:30:00'
  intended_hours: 13
output_preferences:
  master_filename: River_Master_2025.csv
  callspernight_filename: River_CPN_2025.csv
  save_directory: results/csv
```

### Example 3: Short Survey with Perfect Recording

```yaml
config_version: 1
study_parameters:
  study_name: WeekendSurvey
  start_date: '2025-10-18'
  end_date: '2025-10-20'
  detector_mapping:
    GHI789: LOC1
    GHI790: LOC2
  timezone: America/Los_Angeles
  external_data_sources: []
  data_filters:
    remove_noid: false
    remove_zero_pulse_calls: false
    remove_duplicates: true
processing_options:
  detector_specific_schedules: no
  generate_editable_template: no
  recording_start: '19:00:00'
  recording_end: '05:00:00'
  intended_hours: 10
output_preferences:
  master_filename: weekend_master.csv
  callspernight_filename: weekend_cpn.csv
  save_directory: results/csv
```

---

## VALIDATION CHECKLIST

Before saving your `study_parameters.yaml`, verify:

- ☐ `config_version: 1` is present (no quotes)
- ☐ All dates in `'YYYY-MM-DD'` format with quotes
- ☐ All times in `'HH:MM:SS'` format with quotes (24-hour)
- ☐ All Windows paths use forward slashes (`/`)
- ☐ All paths with spaces are quoted
- ☐ `detector_mapping` has one line per detector, properly indented (2 spaces)
- ☐ No tabs used for indentation (spaces only)
- ☐ All colons (`:`) have space after them
- ☐ Boolean values are lowercase (`yes`/`no` or `true`/`false`)
- ☐ Numeric values are not quoted (`intended_hours: 13`, not `'13'`)
- ☐ File saved as UTF-8 encoding (not ANSI or other)
- ☐ No trailing spaces after values
- ☐ Timezone is valid IANA format
- ☐ `end_date` >= `start_date`
- ☐ `recording_start` ≠ `recording_end`

---

## COMMON ERRORS AND SOLUTIONS

### Error: "detector_specific_schedules required"

**Problem:** Parameter is missing or misspelled  
**Solution:** Add `detector_specific_schedules: no` under `processing_options`

### Error: "recording_start required when detector_specific_schedules = no"

**Problem:** Uniform times not specified  
**Solution:** Add both `recording_start` and `recording_end` with proper format

### Error: "detector_schedules.csv required when detector_specific_schedules = yes"

**Problem:** Set to `yes` but CSV file missing  
**Solution:** Either create the CSV file OR change to `no`

### Error: "Invalid date format"

**Problem:** Date not in `YYYY-MM-DD` format or missing quotes  
**Solution:** Use `'2025-10-04'` format with quotes

### Error: "Invalid time format"

**Problem:** Time not in `HH:MM:SS` format or missing quotes  
**Solution:** Use `'18:00:00'` format with quotes and seconds

### Error: "Duplicate detector names"

**Problem:** Two detectors have the same name  
**Solution:** Ensure all detector names in `detector_mapping` are unique

---

## GETTING HELP

If you encounter issues with your YAML configuration:

1. **Check this guide** for parameter specifications
2. **Validate YAML syntax** using an online YAML validator
3. **Review error messages** - they usually indicate the specific problem
4. **Check the validation HTML** generated by the pipeline
5. **Consult the pipeline documentation** at the project repository

---

## VERSION HISTORY

**v2.4 (2026-02-01)**
- Added `detector_specific_schedules` parameter (renamed from `advanced_scheduling`)
- Added `generate_editable_template` parameter
- Enhanced documentation with comprehensive examples
- Added distinction between DESIGN and REALITY decisions

**v2.3 (2026-01-31)**
- Added `data_filters` section documentation
- Updated for Shiny app integration

**v2.2 (2026-01-20)**
- Added `external_data_sources` documentation
- Enhanced detector_mapping examples

**v2.1 (2025-12-26)**
- Initial comprehensive parameter guide
