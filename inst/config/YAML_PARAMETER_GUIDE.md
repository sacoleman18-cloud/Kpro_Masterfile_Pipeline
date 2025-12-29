# YAML PARAMETER GUIDE - study_parameters.yaml
# ==============================================================================
# Complete reference for formatting every parameter in study_parameters.yaml
# 
# CRITICAL FORMATTING RULES:
# 1. YAML is WHITESPACE-SENSITIVE (use spaces, NOT tabs)
# 2. Indentation MUST be consistent (2 spaces per level)
# 3. Strings with spaces MUST be quoted
# 4. Windows paths: Use forward slashes (/) NOT backslashes (\)
# 5. Lists require dashes (-) on separate lines
# ==============================================================================

## SECTION 1: CONFIG VERSION
# ==============================================================================

  # ---------------------------------------------------------------------------
  # 1.1: CONFIG VERSION
  # ---------------------------------------------------------------------------
  # Purpose: Identifies YAML structure version for backward compatibility and validation
  # Format: Integer (no quotes, no decimals)
  # Required: YES (pipeline will fail without this)
  # Valid values: 1 (only version currently supported)
  # Used for: YAML schema validation, future-proofing against breaking changes
  # 
  # WHY THIS EXISTS:
  #   If the pipeline structure changes in future versions (e.g., parameter names,
  #   required fields, validation rules), this version number allows the code to
  #   detect which YAML format you're using and handle it appropriately.
  #   
  #   Think of it like file format versions:
  #     - Word .doc vs .docx (different formats, different features)
  #     - This prevents your YAML from breaking if pipeline updates
  #
  # VALIDATION BEHAVIOR:
  #   Pipeline checks: "Is config_version present? Is it = 1?"
  #   If missing → Error: "config_version is required"
  #   If not 1 → Error: "Only config_version 1 is supported"
  #
  # FUTURE-PROOFING:
  #   If version 2 is released (e.g., new required fields added):
  #     - Your old YAML will still have config_version: 1
  #     - Code can say "Oh, this is v1 format, I'll handle it the old way"
  #     - OR code can say "Please update to v2 format" with migration guide
  #
  # WHEN TO CHANGE THIS:
  #   NEVER change this yourself. Only change when:
  #     - Official documentation says a new version is available
  #     - You want to use new features that require v2+
  #     - Migration guide is provided
  #
  # EXAMPLES:

config_version: 1                         # ✓ Correct (current version)

  # ❌ WRONG: config_version: "1"         (don't quote numbers)
  # ❌ WRONG: config_version: 1.0         (must be integer, not decimal)
  # ❌ WRONG: config_version: 2           (only version 1 supported currently)
  # ❌ WRONG: # config_version: 1         (can't be commented out - required!)
  # ❌ WRONG: Config_Version: 1           (case matters - must be lowercase)
  # ❌ WRONG: configVersion: 1            (must use underscore, not camelCase)
  
  # ⚠️  COMMON MISTAKE: Omitting this line entirely
  #     Error message: "config_version is required in study_parameters.yaml"
  #     Fix: Add this line at the TOP of your YAML file


## SECTION 2: STUDY PARAMETERS
# ==============================================================================

study_parameters:

  # ---------------------------------------------------------------------------
  # 2.1: STUDY NAME
  # ---------------------------------------------------------------------------
  # Purpose: Human-readable identifier for your study, used in logs and output filenames
  # Format: String (quotes optional unless contains spaces or special characters)
  # Required: YES (pipeline will fail without this)
  # Character limits: No strict limit, but keep under 50 chars for readability
  # Allowed characters: Letters, numbers, underscores, hyphens
  # Used for: Log headers, output filenames, error messages, workflow identification
  # 
  # WHY THIS MATTERS:
  #   When you run the pipeline, logs will show:
  #     "=== Processing study: YourStudyName ==="
  #   Output files may include study name:
  #     "YourStudyName_kpro_master_20251228.csv"
  #   This helps when managing multiple studies or sharing code/outputs
  #
  # NAMING BEST PRACTICES:
  #   Good names are:
  #     - Descriptive: "Schmeeckle2025" better than "Study1"
  #     - Concise: "SchmeeckleBats" better than "SchmeeckleReserveBatAcousticMonitoring2025"
  #     - No spaces: Use underscores or camelCase for multi-word names
  #     - Unique: Different from other studies you're running
  #   
  #   Recommended patterns:
  #     - Location + Year: "Schmeeckle2025", "NorthCreek2024"
  #     - Location + Species + Year: "SchmeeckleBats2025"
  #     - Project code: "NSF_Grant_12345", "Thesis_Chapter2"
  #
  # FILE NAMING IMPLICATIONS:
  #   If your study_name has spaces, they'll be replaced with underscores in filenames:
  #     study_name: 'My Study'  → output: My_Study_kpro_master.csv
  #   Better to avoid spaces entirely for cleaner file handling
  #
  # EXAMPLES:
  
  study_name: SchmeeckleBatStudy          # ✓ No quotes (no spaces)
  # study_name: Schmeeckle2025            # ✓ Simple and clear
  # study_name: 'Schmeeckle Bat Study'    # ✓ Quotes needed (has spaces)
  # study_name: "My Study 2025"           # ✓ Double quotes work too
  # study_name: NSF_Bats_2024_2025        # ✓ Underscores OK
  # study_name: Site_A_Baseline           # ✓ Descriptive with underscores
  
  # ❌ WRONG: study_name: Schmeeckle Bat Study    (spaces without quotes)
  # ❌ WRONG: study_name:SchmeeckleBatStudy       (missing space after colon)
  # ❌ WRONG: study_name:                         (empty - must provide a name)
  # ❌ WRONG: study_name: 'Study#1'               (# is special in YAML - use quotes)
  # ❌ WRONG: study_name: Study: Bats             (colon inside name - use quotes)
  
  # ⚠️  COMMON MISTAKE #1: Using special characters without quotes
  #     Special chars in YAML: : { } [ ] , & * # ? | - < > = ! % @ \
  #     If your name has ANY of these, use quotes
  #     Example: study_name: 'Site #1: Baseline'  ✓
  #
  # ⚠️  COMMON MISTAKE #2: Very long names
  #     "SchmeeckleReserveBatAcousticSurvey2025OctoberDeployment" is too long
  #     Shorter is better: "Schmeeckle_Oct2025"
  #
  # ⚠️  COMMON MISTAKE #3: Starting with a number
  #     "2025_Schmeeckle" works but "2025Schmeeckle" might confuse some systems
  #     Best practice: Start with a letter

  # ---------------------------------------------------------------------------
  # 2.2: START DATE
  # ---------------------------------------------------------------------------
  # Purpose: First NIGHT of detector deployment (calendar date when first night began)
  # Format: 'YYYY-MM-DD' (MUST be quoted, 4-digit year, 2-digit month/day, hyphens)
  # Required: YES (pipeline will fail without this)
  # Validation: Must be a valid calendar date (no Feb 30, no month 13, etc.)
  # Used for: CallsPerNight template generation, defining study period boundaries
  # 
  # CRITICAL CONCEPT - "STUDY NIGHT" DEFINITION:
  #   A "study night" is NOT a 24-hour calendar day.
  #   It's the period from evening recording start to next morning recording end.
  #   
  #   Your recording schedule: 6:00 PM to 7:00 AM (13 hours)
  #   Night of October 4th = Oct 4 6:00 PM → Oct 5 7:00 AM
  #   
  #   The start_date is the CALENDAR DATE when recording STARTED that evening.
  #
  # HOW TO DETERMINE YOUR START_DATE:
  #   Step 1: When did you physically deploy detectors?
  #           Example: October 4th, 2:00 PM
  #   
  #   Step 2: When did recording actually begin?
  #           Example: October 4th, 6:00 PM (at recording_start time)
  #   
  #   Step 3: What calendar date is that?
  #           October 4th
  #   
  #   Step 4: Format as YYYY-MM-DD with quotes
  #           start_date: '2025-10-04'
  #
  # WORKED EXAMPLE:
  #   Deployment scenario:
  #     Oct 4, 2:00 PM  → You arrive, install detectors
  #     Oct 4, 3:30 PM  → Detectors configured and turned on
  #     Oct 4, 6:00 PM  → Recording automatically starts (recording_start)
  #     Oct 4, 11:59 PM → Recording ongoing (Night 1 in progress)
  #     Oct 5, 12:00 AM → Recording ongoing (still Night 1)
  #     Oct 5, 7:00 AM  → Recording stops (Night 1 ends)
  #   
  #   First complete night of data: October 4th (started Oct 4 6:00 PM)
  #   Therefore: start_date: '2025-10-04'
  #
  # PARTIAL FIRST NIGHT SCENARIOS:
  #   Scenario A: Deployed late
  #     Oct 4, 8:00 PM → Detectors turned on (after recording_start of 6:00 PM)
  #     Oct 5, 7:00 AM → Recording stops
  #     This is still "Night of Oct 4" (partial night, but belongs to Oct 4)
  #     start_date: '2025-10-04'
  #   
  #   Scenario B: Deployed very late
  #     Oct 4, 11:00 PM → Detectors turned on (very late)
  #     Oct 5, 7:00 AM → Recording stops
  #     Still "Night of Oct 4" (even though only 8 hours)
  #     start_date: '2025-10-04'
  #     Note: You'll manually adjust StartDateTime in CallsPerNight template
  #
  # DATE FORMAT RULES:
  #   MUST use: 'YYYY-MM-DD'
  #     YYYY = 4-digit year (2025, not 25)
  #     MM = 2-digit month (01-12, not 1-12)
  #     DD = 2-digit day (01-31, not 1-31)
  #     Hyphens required (not slashes, not dots)
  #     Quotes required (YAML needs them for date strings)
  #
  # CALENDAR VALIDATION:
  #   Pipeline validates real calendar dates:
  #     '2025-02-30' ❌ Feb only has 28/29 days
  #     '2025-13-01' ❌ Month 13 doesn't exist
  #     '2025-04-31' ❌ April only has 30 days
  #     '2024-02-29' ✓ Leap year (2024 is divisible by 4)
  #     '2025-02-29' ❌ Not a leap year
  #
  # RELATIONSHIP TO END_DATE:
  #   start_date must be <= end_date (can be same day for 1-night study)
  #   Pipeline will error if start_date > end_date
  #
  # EXAMPLES:
  
  start_date: '2025-10-04'                # ✓ Correct format (Oct 4, 2025)
  # start_date: '2025-01-01'              # ✓ January 1st (New Year's Day)
  # start_date: '2024-12-31'              # ✓ December 31st (New Year's Eve)
  # start_date: '2025-02-28'              # ✓ Last day of February (non-leap year)
  # start_date: '2024-02-29'              # ✓ Leap day (2024 is leap year)
  # start_date: '2025-07-04'              # ✓ July 4th
  
  # ❌ WRONG: start_date: 2025-10-04      (missing quotes)
  # ❌ WRONG: start_date: '10/04/2025'    (wrong format - use YYYY-MM-DD)
  # ❌ WRONG: start_date: '2025.10.04'    (use hyphens, not dots)
  # ❌ WRONG: start_date: '2025-1-4'      (must be 2 digits: 2025-01-04)
  # ❌ WRONG: start_date: 10-04-2025      (no quotes, wrong order)
  # ❌ WRONG: start_date: '25-10-04'      (year must be 4 digits: 2025)
  # ❌ WRONG: start_date: '2025-OCT-04'   (use numbers, not month names)
  # ❌ WRONG: start_date: 'October 4, 2025' (wrong format entirely)
  
  # ⚠️  COMMON MISTAKE #1: Using deployment date instead of first recording night
  #     Scenario: Deployed detectors on Oct 3 at 2:00 PM for testing
  #               First NIGHT of recording: Oct 4 6:00 PM → Oct 5 7:00 AM
  #     WRONG: start_date: '2025-10-03'  (deployment date)
  #     RIGHT: start_date: '2025-10-04'  (first night of actual study data)
  #
  # ⚠️  COMMON MISTAKE #2: American date format (MM/DD/YYYY)
  #     Americans write: 10/4/2025
  #     YAML needs: '2025-10-04'
  #     Remember: Year first, then month, then day (ISO 8601 standard)
  #
  # ⚠️  COMMON MISTAKE #3: Single-digit months/days
  #     January 4th: '2025-1-4' ❌  Should be: '2025-01-04' ✓
  #     October 4th: '2025-10-4' ❌  Should be: '2025-10-04' ✓
  #     Always pad with zero: 01, 02, 03, ... 09, 10, 11, 12

  # ---------------------------------------------------------------------------
  # 2.3: END DATE
  # ---------------------------------------------------------------------------
  # Purpose: Last NIGHT of detector deployment (calendar date when final night began)
  # Format: 'YYYY-MM-DD' (MUST be quoted, same rules as start_date)
  # Required: YES (pipeline will fail without this)
  # Validation: Must be >= start_date, must be valid calendar date
  # Used for: CallsPerNight template generation, defining study period boundaries
  # 
  # CRITICAL CONCEPT - "STUDY NIGHT" vs CALENDAR DAY vs RETRIEVAL DATE:
  #   A "study night" spans from evening of one calendar day to morning of the next.
  #   The end_date is the CALENDAR DATE when the LAST night of recording STARTED,
  #   NOT the calendar date when you physically retrieved the detectors.
  #
  #   Conceptual questions to ask yourself:
  #     Q: "What EVENING did I deploy detectors?"
  #     A: That's your start_date
  #     
  #     Q: "What EVENING did detectors last record a complete night?"
  #     A: That's your end_date
  #     
  #     Q: "What MORNING did I pick up detectors?"
  #     A: That's NOT your end_date (it's the morning AFTER end_date)
  #
  # WORKED EXAMPLE:
  #   Your recording schedule: 6:00 PM to 7:00 AM (recording_start/recording_end)
  #   
  #   Timeline:
  #     Oct 31, 6:00 PM  → Recording starts (Night begins)
  #     Oct 31, 11:59 PM → Still recording (same Night)
  #     Nov 1, 12:00 AM  → Still recording (still same Night - hasn't reached 6:00 PM yet)
  #     Nov 1, 6:59 AM   → Still recording (still same Night)
  #     Nov 1, 7:00 AM   → Recording stops (Night ends)
  #     Nov 1, 8:00 AM   → You arrive and pick up detectors
  #   
  #   This entire period (Oct 31 6:00 PM → Nov 1 7:00 AM) is ONE study night.
  #   That night belongs to October 31st (when it started at 6:00 PM).
  #   
  #   Therefore:
  #     end_date: '2025-10-31'  ✓ CORRECT (last night started Oct 31)
  #     end_date: '2025-11-01'  ❌ WRONG (would expect ANOTHER night: Nov 1 6:00 PM → Nov 2 7:00 AM)
  #
  # HOW TO DETERMINE YOUR END_DATE:
  #   Step 1: What morning did you retrieve detectors?
  #           Example: November 1st, 8:00 AM
  #   
  #   Step 2: Subtract one calendar day
  #           November 1st - 1 day = October 31st
  #   
  #   Step 3: That's your end_date
  #           end_date: '2025-10-31'
  #
  # WHY THIS MATTERS:
  #   The pipeline uses end_date to generate the CallsPerNight template.
  #   If you set end_date to Nov 1 (retrieval date), the template will include:
  #     - Night Nov 1 (6:00 PM Nov 1 → 7:00 AM Nov 2)
  #   But you didn't record that night because you already picked up detectors!
  #   This creates an empty row in your template with 0 calls and causes confusion.
  #
  # RELATIONSHIP TO RECORDING SCHEDULE:
  #   The recording_start time determines what "evening" means:
  #     recording_start: '18:00:00' (6 PM)  → Night starts at 6:00 PM
  #     recording_start: '20:00:00' (8 PM)  → Night starts at 8:00 PM
  #   
  #   The end_date is always the calendar date when that evening occurred.
  #   
  #   Example with 8:00 PM start:
  #     Last recording: Oct 31 8:00 PM → Nov 1 7:00 AM
  #     end_date: '2025-10-31' (night started on Oct 31)
  #
  # PARTIAL LAST NIGHT SCENARIOS:
  #   Scenario A: Early retrieval
  #     Oct 31, 6:00 PM → Recording starts
  #     Nov 1, 5:00 AM  → You pick up detectors (before recording_end)
  #     This is still "Night of Oct 31" (partial night)
  #     end_date: '2025-10-31'
  #     Note: You'll manually adjust EndDateTime in CallsPerNight template
  #   
  #   Scenario B: Equipment failure overnight
  #     Oct 31, 6:00 PM → Recording starts
  #     Oct 31, 11:30 PM → SD card fills up, recording stops
  #     Nov 1, 8:00 AM  → You pick up detectors
  #     This is still "Night of Oct 31" (partial night due to failure)
  #     end_date: '2025-10-31'
  #     Note: You'll manually adjust EndDateTime in CallsPerNight template
  #
  # CALCULATING STUDY DURATION:
  #   Total study nights = (end_date - start_date) + 1
  #   
  #   Example:
  #     start_date: '2025-10-04'
  #     end_date: '2025-10-31'
  #     Calculation: Oct 31 - Oct 4 = 27 days
  #     Total nights: 27 + 1 = 28 nights
  #     
  #   List of nights: Oct 4, Oct 5, Oct 6, ..., Oct 30, Oct 31
  #
  # VALIDATION AGAINST START_DATE:
  #   Pipeline checks: end_date >= start_date
  #   
  #   Valid examples:
  #     start: '2025-10-04', end: '2025-10-31'  ✓ 28-night study
  #     start: '2025-10-04', end: '2025-10-04'  ✓ 1-night study (same day)
  #   
  #   Invalid examples:
  #     start: '2025-10-04', end: '2025-10-03'  ❌ End before start
  #     Error: "end_date must be >= start_date"
  #
  # EXAMPLES:
  
  end_date: '2025-10-31'                  # ✓ Correct format (Oct 31, 2025)
  # end_date: '2025-11-15'                # ✓ Mid-November
  # end_date: '2025-01-15'                # ✓ January 15th
  # end_date: '2024-12-31'                # ✓ December 31st (New Year's Eve)
  
  # ❌ WRONG: end_date: '2025-09-01'      (before start_date example above)
  # ❌ WRONG: end_date: 2025-11-01        (missing quotes)
  # ❌ WRONG: end_date: '11/01/2025'      (wrong format - use YYYY-MM-DD)
  # ❌ WRONG: end_date: '2025-11-1'       (must be 2 digits: 2025-11-01)
  # ❌ WRONG: end_date: '2025-13-01'      (month 13 doesn't exist)
  # ❌ WRONG: end_date: '2025-11-31'      (November only has 30 days)
  
  # ⚠️  COMMON MISTAKE #1: Using retrieval date instead of last night
  #     Scenario: Picked up detectors on November 1st morning
  #     WRONG: end_date: '2025-11-01'  (this expects another night of data)
  #     RIGHT: end_date: '2025-10-31'  (last night started Oct 31 evening)
  #
  # ⚠️  COMMON MISTAKE #2: Confusing UTC timestamps with study nights
  #     Your data may have UTC timestamps like "2025-11-01 00:29:22"
  #     But in local time (CST), this is "2025-10-31 19:29:22" (Oct 31 evening)
  #     The study night is Oct 31, not Nov 1
  #     The pipeline handles timezone conversion - just set end_date correctly
  #
  # ⚠️  COMMON MISTAKE #3: Off-by-one errors in multi-month studies
  #     Deployed: October 4th evening
  #     Retrieved: November 1st morning
  #     Total nights: Oct 4, Oct 5, ..., Oct 30, Oct 31 (28 nights)
  #     start_date: '2025-10-04'
  #     end_date: '2025-10-31'  (NOT '2025-11-01')
  #
  # ⚠️  COMMON MISTAKE #4: Setting end_date to "today"
  #     If detectors are still deployed, end_date should be the LAST COMPLETE NIGHT
  #     Don't set it to today's date if tonight hasn't finished recording yet

  # ---------------------------------------------------------------------------
  # 2.4: DETECTOR MAPPING
  # ---------------------------------------------------------------------------
  # Purpose: Maps 16-character detector IDs to human-readable friendly names
  # Format: Multi-line YAML mapping (key: value pairs, one per detector)
  #   - Keys: 16-character hexadecimal detector IDs (no quotes)
  #   - Values: Friendly site names (no quotes unless contains spaces)
  #   - Indentation: 2 spaces from "detector_mapping:"
  # Required: YES (pipeline will fail without detector mappings)
  # Validation: All detector IDs in data must have mappings, no duplicates allowed
  # Used for: Column transformation, output labeling, data analysis, reports
  # 
  # WHAT IS A DETECTOR ID:
  #   Every acoustic detector has a unique 16-character hexadecimal identifier.
  #   This ID is embedded in all audio filenames and CSV data outputs.
  #   
  #   Example filename: 245AAA0666BC1507_20251101_002922T.WAV
  #                     ^^^^^^^^^^^^^^^^ This is the detector ID
  #   
  #   In Kaleidoscope Pro CSV output, this appears in the "IN FILE" column.
  #   The first 16 characters of every filename are the detector ID.
  #
  # WHY MAPPING IS NEEDED:
  #   Detector IDs are unique and reliable (never change for that device)
  #   But they're not human-readable: "245AAA0666BC1507" is hard to work with
  #   
  #   Friendly names like "LPE" (Lily Pond East) or "MCE" (Marsh Creek East)
  #   make data analysis, plotting, and communication much easier.
  #   
  #   The pipeline replaces detector IDs with friendly names throughout outputs.
  #
  # HOW TO CREATE YOUR DETECTOR MAPPING:
  #   Step 1: Find your detector IDs
  #           Look at your raw data filenames or IN FILE column
  #           Example: 245AAA0666BC1507_20251101_002922T.WAV
  #                    Detector ID: 245AAA0666BC1507
  #   
  #   Step 2: Decide on friendly names
  #           Use site codes, location abbreviations, or descriptive names
  #           Examples: "LPE" (Lily Pond East), "Site_A", "North_Creek"
  #   
  #   Step 3: Create one line per detector
  #           Format: DETECTOR_ID: FRIENDLY_NAME
  #           Indent 2 spaces from "detector_mapping:"
  #
  # AUTOMATIC GENERATION:
  #   Workflow 01 automatically generates a template mapping:
  #     1. Scans all data files
  #     2. Extracts unique detector IDs
  #     3. Creates mapping with placeholder "ENTER_NAME_HERE"
  #     4. Prompts you to replace placeholders with real names
  #   
  #   You only need to replace "ENTER_NAME_HERE" with actual site names.
  #
  # NAMING BEST PRACTICES:
  #   Good friendly names are:
  #     ✓ Short (2-4 characters ideal): LPE, MCE, SMO
  #     ✓ Descriptive: LPE = Lily Pond East (you remember what it means)
  #     ✓ Consistent format: All 3 letters, or all Site_X pattern
  #     ✓ Unique: No two detectors with same name
  #     ✓ No spaces: Use underscores if needed (Site_A, not "Site A")
  #   
  #   Recommended patterns:
  #     - Site codes: LPI, LPE, LPO (Lily Pond Interior/East/Outer)
  #     - Location abbreviations: SMI, SME, SMO (Schmeeckle Marsh I/E/O)
  #     - Numbered sites: Site_1, Site_2, Site_3
  #     - Descriptive: North_Creek, South_Marsh, East_Ridge
  #
  # CHARACTER RESTRICTIONS:
  #   Friendly names can contain:
  #     ✓ Letters (A-Z, a-z)
  #     ✓ Numbers (0-9)
  #     ✓ Underscores (_)
  #     ✓ Hyphens (-)
  #   
  #   Friendly names CANNOT contain (without quotes):
  #     ❌ Spaces (use underscores instead)
  #     ❌ Special YAML characters: : { } [ ] , & * # ? | - < > = ! % @ \
  #   
  #   If you MUST use spaces or special characters, wrap in quotes:
  #     24E144036484A442: 'North Creek'      # ✓ Quoted (has space)
  #     24E144036484A442: 'Site #1'          # ✓ Quoted (has #)
  #
  # DETECTOR ID FORMAT:
  #   Detector IDs are exactly 16 hexadecimal characters:
  #     - Characters: 0-9, A-F (case doesn't matter, but usually uppercase)
  #     - Length: Exactly 16 characters
  #     - Examples: 245AAA0666BC1507, 247475035FDF1A0D
  #   
  #   In this file:
  #     - NO quotes around detector IDs (YAML keys don't need quotes)
  #     - Case doesn't matter (245aaa... and 245AAA... are same)
  #     - But convention is UPPERCASE for consistency
  #
  # INDENTATION RULES:
  #   detector_mapping:
  #     245AAA0666BC1507: LPI    ← 2 spaces from left margin
  #     245AAA0666BC08AE: LPE    ← Exactly 2 spaces, same as line above
  #   
  #   Wrong indentation causes "scanner error" from YAML parser
  #
  # VALIDATION BEHAVIOR:
  #   Pipeline checks:
  #     1. All detector IDs in data have mappings (no unmapped detectors)
  #     2. No duplicate detector IDs in mapping
  #     3. No duplicate friendly names (each detector gets unique name)
  #     4. All detector IDs are 16 characters
  #   
  #   If validation fails:
  #     - Error: "Detector ID XXXXX found in data but not in mapping"
  #     - Error: "Duplicate detector ID in mapping: XXXXX"
  #     - Error: "Duplicate friendly name: LPE used for multiple detectors"
  #
  # UPDATING MAPPINGS:
  #   If you add/remove detectors mid-study:
  #     1. Run Workflow 01 again - it re-scans data
  #     2. New detector IDs appear with "ENTER_NAME_HERE"
  #     3. Add friendly names for new detectors
  #     4. Old mappings are preserved automatically
  #
  # EXAMPLES:
  
  detector_mapping:
    245AAA0666BC08AE: LPI                 # ✓ No quotes on either side
    245AAA0666BC1507: LPE                 # ✓ Short site codes (3 letters)
    247475035FDF1A0D: SMI                 # ✓ All caps OK
    247AA5015FDF19F3: SME                 # ✓ Alphanumeric OK
    248D9B025FDF0B90: MCO                 # ✓ 3-letter codes common
    249C600164F3532A: SMO                 # ✓ Consistent length recommended
    24A04F085FDF0C84: MCI                 # ✓ Another detector
    24A04F085FDF19C0: MCE                 # ✓ And another
    24E144036484A442: LPO                 # ✓ Last one
    # 24F1234567890ABC: 'North Creek'     # ✓ Quotes if name has spaces
    # 24F1234567890ABC: Site_A            # ✓ Underscores OK (no spaces)
    # 24F1234567890ABC: Site-1            # ✓ Hyphens OK
    # 24F1234567890ABC: Detector123       # ✓ Letters and numbers OK
  
  # ❌ WRONG: detector_mapping:           (nothing on following lines - need mappings!)
  # ❌ WRONG:   '245AAA0666BC08AE': LPI   (don't quote detector IDs)
  # ❌ WRONG:   245AAA0666BC08AE: "LPI"   (don't quote simple friendly names)
  # ❌ WRONG:   245AAA0666BC08AE:LPI      (missing space after colon)
  # ❌ WRONG: 245AAA0666BC08AE: LPI       (wrong indentation - needs 2 spaces)
  # ❌ WRONG:    245AAA0666BC08AE: LPI    (too much indentation - only 2 spaces)
  # ❌ WRONG:   245AAA0666BC08: LPI       (detector ID must be 16 chars)
  # ❌ WRONG:   245AAA0666BC08AE: North Creek  (space without quotes)
  # ❌ WRONG:   245AAA0666BC08AE:         (no friendly name provided)
  
  # ⚠️  COMMON MISTAKE #1: Using same friendly name for multiple detectors
  #     detector_mapping:
  #       245AAA0666BC08AE: Site1
  #       247475035FDF1A0D: Site1         ❌ Duplicate name!
  #     Each detector must have a UNIQUE friendly name
  #
  # ⚠️  COMMON MISTAKE #2: Spaces in friendly names without quotes
  #     247475035FDF1A0D: North Creek     ❌ No quotes around "North Creek"
  #     247475035FDF1A0D: 'North Creek'   ✓ Correct (quoted)
  #     Better: 247475035FDF1A0D: North_Creek  ✓ Use underscore instead
  #
  # ⚠️  COMMON MISTAKE #3: Tab characters instead of spaces
  #     detector_mapping:
  #     [TAB]245AAA0666BC08AE: LPI        ❌ Tab character causes YAML error
  #       245AAA0666BC08AE: LPI           ✓ Use 2 spaces, not tabs
  #
  # ⚠️  COMMON MISTAKE #4: Inconsistent indentation
  #     detector_mapping:
  #       245AAA0666BC08AE: LPI           ✓ 2 spaces
  #        247475035FDF1A0D: SMI          ❌ 3 spaces (inconsistent)
  #     All detector mappings must have SAME indentation (2 spaces)
  #
  # ⚠️  COMMON MISTAKE #5: Leaving "ENTER_NAME_HERE" placeholders
  #     detector_mapping:
  #       245AAA0666BC08AE: ENTER_NAME_HERE  ❌ Forgot to replace placeholder
  #     Replace ALL placeholders with real site names before running pipeline

  # ---------------------------------------------------------------------------
  # 2.5: TIMEZONE
  # ---------------------------------------------------------------------------
  # Purpose: Timezone for converting detector timestamps (UTC) to local time
  # Format: IANA timezone string (no quotes needed)
  # Required: YES (pipeline will fail without this)
  # Valid values: Any timezone from IANA tz database (OlsonNames() in R)
  # Used for: All DateTime conversions throughout pipeline, Night calculations
  # Reference: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  # 
  # WHY TIMEZONE MATTERS:
  #   Acoustic detectors typically record in UTC (Universal Coordinated Time).
  #   But bat activity is tied to LOCAL sunset/sunrise, not UTC.
  #   
  #   Example:
  #     Detector timestamp: 2025-10-31 23:00:00 UTC
  #     In Central Time (America/Chicago): 2025-10-31 18:00:00 CDT (6:00 PM)
  #     This is evening (bat active time), not nearly midnight!
  #   
  #   The pipeline converts ALL timestamps from UTC to your local timezone.
  #   This ensures:
  #     - Correct "Night" calculations (based on local evening/morning)
  #     - Accurate recording hours (based on local time)
  #     - Meaningful data analysis (aligned with actual sunset/sunrise)
  #
  # HOW TO FIND YOUR TIMEZONE:
  #   Step 1: What city are you closest to?
  #           Example: "I'm in central Wisconsin"
  #   
  #   Step 2: Look up your timezone on Wikipedia:
  #           https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  #           Find your region/city in the table
  #   
  #   Step 3: Use the "TZ identifier" column
  #           Example: America/Chicago for Central Time
  #   
  #   Common US timezones:
  #     - Eastern Time: America/New_York
  #     - Central Time: America/Chicago
  #     - Mountain Time: America/Denver
  #     - Pacific Time: America/Los_Angeles
  #     - Arizona (no DST): America/Phoenix
  #     - Alaska: America/Anchorage
  #     - Hawaii: Pacific/Honolulu
  #
  # IANA TIMEZONE FORMAT:
  #   Format: Region/City
  #     Region: Continent or ocean (America, Europe, Asia, Pacific, etc.)
  #     City: Major city in timezone
  #   
  #   Examples:
  #     America/Chicago      ✓ Correct format
  #     Europe/London        ✓ Correct format
  #     Asia/Tokyo           ✓ Correct format
  #     Australia/Sydney     ✓ Correct format
  #   
  #   NOT allowed:
  #     CST                  ❌ Abbreviation (ambiguous - Central? China?)
  #     Central Time         ❌ Not IANA format
  #     America\Chicago      ❌ Wrong slash direction
  #     chicago              ❌ Missing region, wrong case
  #
  # DAYLIGHT SAVING TIME (DST):
  #   IANA timezones automatically handle DST transitions!
  #   
  #   America/Chicago:
  #     - Spring forward: 2:00 AM → 3:00 AM (lose an hour)
  #     - Fall back: 2:00 AM → 1:00 AM (gain an hour)
  #   
  #   The pipeline handles this automatically using lubridate package.
  #   You don't need to specify "CDT" vs "CST" - it's automatic.
  #   
  #   Example:
  #     March 10, 2025, 2:30 AM doesn't exist (spring forward)
  #     lubridate correctly handles this: 2:00 AM → 3:00 AM
  #
  # TIMEZONES WITHOUT DST:
  #   Some regions don't observe DST:
  #     America/Phoenix    - Arizona (no DST)
  #     America/Saskatchewan - Saskatchewan (no DST)
  #     Pacific/Honolulu   - Hawaii (no DST)
  #     Asia/Tokyo         - Japan (no DST)
  #   
  #   These timezones stay constant year-round.
  #
  # VALIDATION BEHAVIOR:
  #   Pipeline checks: "Is this timezone in OlsonNames() database?"
  #   
  #   Valid:
  #     timezone: America/Chicago    ✓ Found in database
  #   
  #   Invalid:
  #     timezone: CST                ❌ Not in database
  #     Error: "Invalid timezone: 'CST'. Must be IANA format like America/Chicago"
  #
  # IMPACT ON NIGHT CALCULATIONS:
  #   The timezone determines when "evening" starts for Night assignment.
  #   
  #   Example with America/Chicago:
  #     UTC: 2025-10-31 23:00:00
  #     Local (Chicago): 2025-10-31 18:00:00 (6:00 PM)
  #     Hour = 18 (evening)
  #     Night = 2025-10-31 ✓
  #   
  #   If you used wrong timezone (e.g., UTC):
  #     UTC: 2025-10-31 23:00:00
  #     Hour = 23 (almost midnight)
  #     Night = 2025-10-31 ✓ (correct by accident)
  #   
  #   But morning calls would be wrong:
  #     UTC: 2025-11-01 05:00:00 (5:00 AM UTC)
  #     Local (Chicago): 2025-11-01 00:00:00 (midnight local)
  #     With correct timezone: Night = 2025-10-31 ✓ (before 6 PM next day)
  #     With UTC: Night = 2025-11-01 ❌ (wrong night!)
  #
  # CHANGING TIMEZONE MID-STUDY:
  #   If you physically moved detectors to different timezone:
  #     Option 1: Split data into two studies with different timezones
  #     Option 2: Use the dominant timezone (where most data was collected)
  #   
  #   DON'T change timezone in YAML mid-processing - it will cause confusion.
  #
  # EXAMPLES:
  
  timezone: America/Chicago               # ✓ Central Time (US & Canada)
  # timezone: America/New_York            # ✓ Eastern Time (US & Canada)
  # timezone: America/Los_Angeles         # ✓ Pacific Time (US & Canada)
  # timezone: America/Denver              # ✓ Mountain Time (US & Canada)
  # timezone: America/Phoenix             # ✓ Arizona (no DST)
  # timezone: America/Anchorage           # ✓ Alaska
  # timezone: Pacific/Honolulu            # ✓ Hawaii (no DST)
  # timezone: Europe/London               # ✓ UK (GMT/BST)
  # timezone: Europe/Paris                # ✓ Central European Time
  # timezone: Asia/Tokyo                  # ✓ Japan (no DST)
  # timezone: Australia/Sydney            # ✓ Australian Eastern Time
  # timezone: UTC                         # ✓ Keep as UTC (not recommended)
  
  # ❌ WRONG: timezone: 'America/Chicago' (quotes not needed)
  # ❌ WRONG: timezone: CST               (use IANA name, not abbreviation)
  # ❌ WRONG: timezone: CDT               (use IANA name, not abbreviation)
  # ❌ WRONG: timezone: Central           (use IANA format)
  # ❌ WRONG: timezone: Central Time      (use IANA format)
  # ❌ WRONG: timezone: America\Chicago   (use /, not \)
  # ❌ WRONG: timezone: america/chicago   (case matters - use proper case)
  # ❌ WRONG: timezone: Chicago           (missing region)
  # ❌ WRONG: timezone: US/Central        (old format - use America/Chicago)
  
  # ⚠️  COMMON MISTAKE #1: Using timezone abbreviations
  #     CST could mean: Central Standard Time, China Standard Time, Cuba ST
  #     EST could mean: Eastern Standard Time, Australian Eastern ST
  #     Always use full IANA format to avoid ambiguity
  #
  # ⚠️  COMMON MISTAKE #2: Not considering DST
  #     "My timezone is CST (UTC-6)"
  #     But in summer, you're in CDT (UTC-5) due to DST!
  #     Solution: Use America/Chicago - it handles both automatically
  #
  # ⚠️  COMMON MISTAKE #3: Using city instead of IANA format
  #     timezone: Chicago                ❌ Not valid
  #     timezone: America/Chicago        ✓ Correct
  #
  # ⚠️  COMMON MISTAKE #4: Using UTC when you shouldn't
  #     timezone: UTC                    ← Technically works, but wrong!
  #     Unless your detectors are at Greenwich Observatory, use your local timezone
  #     Bat ecology doesn't care about UTC - it cares about local sunset/sunrise

  # ---------------------------------------------------------------------------
  # 2.6: EXTERNAL DATA SOURCES (OPTIONAL)
  # ---------------------------------------------------------------------------
  # Purpose: Paths to directories containing additional Kaleidoscope id.csv files
  # Format: YAML list (dash-prefixed lines, one path per line)
  # Required: NO (can be empty or omitted)
  # Validation: Paths must exist, must be readable, must contain id.csv files
  # Used by: Workflow 01 (load_external_raw_data function)
  # 
  # WHAT ARE EXTERNAL DATA SOURCES:
  #   By default, the pipeline loads data from the "data/" directory in your project.
  #   External data sources let you ALSO load data from other locations:
  #     - External hard drives
  #     - Network shares
  #     - Different folders on your computer
  #     - Archived data from previous years
  #   
  #   This is useful when:
  #     - Your raw data is too large to copy into project folder
  #     - You want to keep original data on external drive
  #     - You're combining data from multiple locations
  #     - You're analyzing archived data alongside new data
  #
  # HOW IT WORKS:
  #   Workflow 01 scans each path you provide:
  #     1. Looks for any files named "id.csv" (Kaleidoscope output format)
  #     2. Recursively searches subdirectories
  #     3. Loads all found id.csv files
  #     4. Combines them with data from project data/ folder
  #   
  #   Example directory structure:
  #     F:/Schmeeckle analyzed 102725/
  #       ├── Elizabeth/
  #       │   └── TWS 1/
  #       │       └── id.csv         ← Found and loaded
  #       └── Site2/
  #           └── id.csv             ← Found and loaded
  #
  # PATH FORMAT RULES:
  #   1. Use FORWARD SLASHES (/) even on Windows
  #      Windows: F:/Data/Bats     ✓ Correct
  #      Windows: F:\Data\Bats     ❌ Wrong (backslashes cause errors)
  #   
  #   2. Use QUOTES if path contains spaces
  #      'F:/Schmeeckle analyzed 102725'    ✓ Quoted (has space in "analyzed 102725")
  #      F:/Data/Bats                       ✓ No quotes needed (no spaces)
  #   
  #   3. Absolute paths recommended
  #      F:/Data/Bats                       ✓ Absolute (starts with drive letter)
  #      /mnt/external/bats                 ✓ Absolute (starts with /)
  #      data/external                      ✓ Relative (from project root)
  #   
  #   4. Drive letters on Windows
  #      F:/                                ✓ Correct
  #      F:\                                ❌ Wrong slash direction
  #      //F/                               ❌ Wrong format
  #
  # YAML LIST FORMAT:
  #   external_data_sources:
  #     - 'Path/to/first/directory'
  #     - 'Path/to/second/directory'
  #     - 'Path/to/third/directory'
  #   
  #   Each path starts with dash (-) and space
  #   Each path is on its own line
  #   All paths indented 2 spaces from "external_data_sources:"
  #
  # EMPTY LIST (NO EXTERNAL SOURCES):
  #   If you don't have external data, use one of these:
  #   
  #   Option 1: Empty list
  #     external_data_sources: []
  #   
  #   Option 2: Empty (nothing after colon)
  #     external_data_sources:
  #   
  #   Option 3: Omit entirely (not recommended - be explicit)
  #     # external_data_sources: []
  #
  # WINDOWS PATH EXAMPLES:
  #   Single external drive:
  #     external_data_sources:
  #       - 'F:/Schmeeckle analyzed 102725'
  #   
  #   Multiple drives:
  #     external_data_sources:
  #       - 'F:/Schmeeckle analyzed 102725'
  #       - 'E:/BatData/2024'
  #       - 'D:/Archives/Field_Data'
  #   
  #   Network share (use forward slashes):
  #     external_data_sources:
  #       - '//NetworkDrive/BatData/2025'
  #
  # LINUX/MAC PATH EXAMPLES:
  #   Mounted external drive:
  #     external_data_sources:
  #       - '/mnt/external/bat_data'
  #       - '/Volumes/ExternalDrive/Bats'
  #   
  #   Home directory:
  #     external_data_sources:
  #       - '~/Documents/BatResearch/RawData'
  #
  # RELATIVE PATH EXAMPLES:
  #   Relative to project root:
  #     external_data_sources:
  #       - 'data/external'          # Project-root/data/external/
  #       - '../shared_data'         # One level up from project
  #   
  #   Note: Absolute paths are more reliable (no confusion about "where is root?")
  #
  # VALIDATION BEHAVIOR:
  #   For each path, pipeline checks:
  #     1. Does path exist?
  #        If no → Error: "External data path not found: F:/..."
  #     
  #     2. Is it readable?
  #        If no → Error: "Cannot read external data path: F:/..."
  #     
  #     3. Does it contain id.csv files (anywhere in subdirectories)?
  #        If no → Warning: "No id.csv files found in: F:/..."
  #        (Warning, not error - maybe you haven't processed data yet)
  #   
  #   Pipeline continues even if some paths have warnings (no id.csv found).
  #   Pipeline fails if paths don't exist or aren't readable.
  #
  # COMBINING WITH LOCAL DATA:
  #   The pipeline ALWAYS loads data from "data/" folder in project.
  #   External sources are ADDITIONAL to local data, not replacements.
  #   
  #   Example:
  #     Local: data/site1/id.csv                     (loaded)
  #     External: F:/ExternalDrive/site2/id.csv      (loaded)
  #     Result: Both combined into single dataset
  #
  # DUPLICATE DETECTION:
  #   If same data appears in multiple locations:
  #     data/site1/id.csv              (1000 rows)
  #     F:/External/site1/id.csv       (1000 rows - same data!)
  #   
  #   Pipeline will:
  #     1. Load both (2000 rows total)
  #     2. Detect duplicates in deduplication stage
  #     3. Remove duplicate rows
  #     4. Log: "Removed X duplicate rows"
  #   
  #   This is safe - deduplication protects against accidental duplicates.
  #
  # PERFORMANCE CONSIDERATIONS:
  #   Loading from external drives is slower than local data:
  #     - Local SSD: Fast (milliseconds per file)
  #     - External USB drive: Slower (seconds per file)
  #     - Network drive: Slowest (could be minutes for large datasets)
  #   
  #   If you have LOTS of data:
  #     Option 1: Copy critical data to local project folder
  #     Option 2: Be patient with external drive loading
  #     Option 3: Use external for archival, local for active analysis
  #
  # EXAMPLES:
  
  external_data_sources:
    - 'F:/Schmeeckle analyzed 102725'    # ✓ Windows path (forward slashes!)
  
  # Multiple sources:
  # external_data_sources:
  #   - 'F:/Schmeeckle analyzed 102725'  # ✓ First source
  #   - 'C:/Users/Rusty/BatData/2025'    # ✓ Second source
  #   - 'E:/Field Data/Site A'           # ✓ Third source (path with spaces)
  
  # Linux/Mac paths:
  # external_data_sources:
  #   - '/mnt/external/bat_data'         # ✓ Linux mounted drive
  #   - '/Volumes/BatDrive/Data'         # ✓ Mac external drive
  
  # Relative paths:
  # external_data_sources:
  #   - 'data/external'                  # ✓ Relative to project root
  #   - '../shared_data/bats'            # ✓ One level up from project
  
  # Empty list (no external sources):
  # external_data_sources: []            # ✓ No external data
  # external_data_sources:               # ✓ Also empty (nothing after colon)
  
  # ❌ WRONG: external_data_sources: F:\Schmeeckle analyzed 102725
  #           (not a list - missing dash, has backslashes, no quotes)
  # ❌ WRONG: external_data_sources: 'F:\Schmeeckle analyzed 102725'
  #           (backslashes wrong - use forward slashes)
  # ❌ WRONG: external_data_sources:
  #           - F:/Schmeeckle analyzed 102725
  #           (missing quotes - path has spaces)
  # ❌ WRONG: external_data_sources: ['F:/path1', 'F:/path2']
  #           (inline list format - use multi-line format instead)
  # ❌ WRONG: external_data_sources:
  #            - 'F:/Data/Bats'           (3 spaces - should be 2)
  # ❌ WRONG: external_data_sources:
  #           -'F:/Data/Bats'             (missing space after dash)
  
  # ⚠️  COMMON MISTAKE #1: Backslashes on Windows
  #     Windows Explorer shows: F:\Schmeeckle analyzed 102725
  #     You must change to:     F:/Schmeeckle analyzed 102725
  #     Remember: Forward slashes ALWAYS, even on Windows!
  #
  # ⚠️  COMMON MISTAKE #2: Forgetting quotes around paths with spaces
  #     F:/Field Data/Bats                ❌ Has space, no quotes
  #     'F:/Field Data/Bats'              ✓ Quoted
  #     F:/Field_Data/Bats                ✓ No space, no quotes needed
  #
  # ⚠️  COMMON MISTAKE #3: Not using list format
  #     external_data_sources: F:/Data   ❌ Not a list
  #     external_data_sources:
  #       - F:/Data                       ✓ Correct list format
  #
  # ⚠️  COMMON MISTAKE #4: Path doesn't exist
  #     external_data_sources:
  #       - 'F:/BatData/2025'             ← Typo in path or drive not connected
  #     Error: "External data path not found: F:/BatData/2025"
  #     Fix: Check path exists, check drive letter, check spelling
  #
  # ⚠️  COMMON MISTAKE #5: Path exists but no id.csv files
  #     external_data_sources:
  #       - 'F:/RawAudioFiles'            ← Has .WAV files, but no id.csv
  #     Warning: "No id.csv files found in: F:/RawAudioFiles"
  #     This path needs Kaleidoscope-processed data (id.csv), not raw audio


## SECTION 3: PROCESSING OPTIONS
# ==============================================================================

processing_options:

  # ---------------------------------------------------------------------------
  # 3.1: ADVANCED SCHEDULING
  # ---------------------------------------------------------------------------
  # Purpose: Enable/disable detector-specific recording schedules
  # Format: Boolean (yes/no or true/false, no quotes, lowercase)
  # Required: YES (must explicitly set to yes or no)
  # Valid values: yes, no, true, false (case-sensitive, lowercase only)
  # Used for: Determining whether to use uniform or detector-specific schedules
  # 
  # WHAT IS ADVANCED SCHEDULING:
  #   Most bat acoustic studies use the SAME recording schedule for ALL detectors:
  #     - All detectors: 6:00 PM to 7:00 AM every night
  #     - Simple, consistent, easy to manage
  #     - This is "uniform scheduling" (advanced_scheduling: no)
  #   
  #   But some studies have DIFFERENT schedules for different detectors:
  #     - Detector A: 6:00 PM to 7:00 AM (standard)
  #     - Detector B: 8:00 PM to 6:00 AM (different hours)
  #     - Detector C: 6:00 PM to 8:00 AM (longer recording)
  #     - This is "advanced scheduling" (advanced_scheduling: yes)
  #
  # WHEN TO USE UNIFORM SCHEDULING (no):
  #   Use advanced_scheduling: no when:
  #     ✓ All detectors have same recording times
  #     ✓ You want simple, straightforward setup
  #     ✓ You set recording_start and recording_end once for all detectors
  #     ✓ Most common scenario (90% of studies)
  #   
  #   Example use case:
  #     "All 10 detectors record 6:00 PM to 7:00 AM every night"
  #     → advanced_scheduling: no
  #     → Set recording_start: '18:00:00', recording_end: '07:00:00'
  #
  # WHEN TO USE ADVANCED SCHEDULING (yes):
  #   Use advanced_scheduling: yes when:
  #     ✓ Different detectors have different recording times
  #     ✓ You have a CSV file with detector-specific schedules
  #     ✓ Complex deployment scenarios (batteries, SD cards, etc.)
  #   
  #   Example use case:
  #     "Detector A records 6-7, Detector B records 8-6, Detector C records 6-8"
  #     → advanced_scheduling: yes
  #     → Create detector_schedules.csv with specific times per detector
  #
  # HOW UNIFORM SCHEDULING WORKS:
  #   When advanced_scheduling: no:
  #     1. Pipeline reads recording_start and recording_end from this YAML
  #     2. Applies same times to ALL detectors
  #     3. CallsPerNight template pre-fills these times for every night
  #     4. You only edit if equipment failures occurred
  #   
  #   Example YAML:
  #     advanced_scheduling: no
  #     recording_start: '18:00:00'
  #     recording_end: '07:00:00'
  #   
  #   Resulting template (every detector, every night):
  #     Detector: LPE, Night: 10/4, StartDateTime: 10/4/2025 6:00 PM, EndDateTime: 10/5/2025 7:00 AM
  #     Detector: LPE, Night: 10/5, StartDateTime: 10/5/2025 6:00 PM, EndDateTime: 10/6/2025 7:00 AM
  #     ... (all rows have same times)
  #
  # HOW ADVANCED SCHEDULING WORKS:
  #   When advanced_scheduling: yes:
  #     1. Pipeline looks for detector_schedules.csv file
  #     2. Reads detector-specific start/end times from CSV
  #     3. Applies different times to different detectors
  #     4. CallsPerNight template uses detector-specific times
  #   
  #   Example detector_schedules.csv:
  #     Detector,StartTime,EndTime
  #     LPE,18:00:00,07:00:00
  #     LPI,20:00:00,06:00:00
  #     SMO,18:00:00,08:00:00
  #   
  #   Resulting template:
  #     Detector: LPE, Night: 10/4, StartDateTime: 10/4 6:00 PM, EndDateTime: 10/5 7:00 AM
  #     Detector: LPI, Night: 10/4, StartDateTime: 10/4 8:00 PM, EndDateTime: 10/5 6:00 AM
  #     Detector: SMO, Night: 10/4, StartDateTime: 10/4 6:00 PM, EndDateTime: 10/5 8:00 AM
  #
  # REQUIRED PARAMETERS WHEN UNIFORM (no):
  #   When advanced_scheduling: no, you MUST set:
  #     ✓ recording_start: 'HH:MM:SS'
  #     ✓ recording_end: 'HH:MM:SS'
  #   
  #   Pipeline will error if these are missing:
  #     Error: "recording_start required when advanced_scheduling = no"
  #
  # REQUIRED FILES WHEN ADVANCED (yes):
  #   When advanced_scheduling: yes, you MUST create:
  #     ✓ detector_schedules.csv in data/ folder
  #   
  #   CSV format:
  #     Detector,StartTime,EndTime
  #     LPE,18:00:00,07:00:00
  #     LPI,20:00:00,06:00:00
  #   
  #   Pipeline will error if file is missing or malformed.
  #
  # BOOLEAN VALUE FORMAT:
  #   YAML booleans can be written four ways (all equivalent):
  #     yes = true
  #     no = false
  #   
  #   All of these mean "no":
  #     advanced_scheduling: no          ✓ Recommended (clear)
  #     advanced_scheduling: false       ✓ Also valid
  #   
  #   All of these mean "yes":
  #     advanced_scheduling: yes         ✓ Recommended (clear)
  #     advanced_scheduling: true        ✓ Also valid
  #   
  #   Case matters:
  #     advanced_scheduling: No          ❌ Capital N (must be lowercase)
  #     advanced_scheduling: YES         ❌ All caps (must be lowercase)
  #     advanced_scheduling: True        ❌ Capital T (must be lowercase)
  #
  # EXAMPLES:
  
  advanced_scheduling: no                 # ✓ Most common (uniform schedule)
  # advanced_scheduling: yes              # ✓ Detector-specific schedules
  # advanced_scheduling: false            # ✓ Same as 'no'
  # advanced_scheduling: true             # ✓ Same as 'yes'
  
  # ❌ WRONG: advanced_scheduling: 'no'   (don't quote booleans)
  # ❌ WRONG: advanced_scheduling: No     (case matters - use lowercase)
  # ❌ WRONG: advanced_scheduling: NO     (all caps - use lowercase)
  # ❌ WRONG: advanced_scheduling: 0      (use yes/no, not 1/0)
  # ❌ WRONG: advanced_scheduling: 1      (use yes/no, not 1/0)
  # ❌ WRONG: advanced_scheduling:        (missing value)
  
  # ⚠️  COMMON MISTAKE #1: Setting to 'yes' but not creating detector_schedules.csv
  #     advanced_scheduling: yes
  #     (but no detector_schedules.csv file exists)
  #     Error: "detector_schedules.csv required when advanced_scheduling = yes"
  #
  # ⚠️  COMMON MISTAKE #2: Setting to 'no' but not providing recording_start/end
  #     advanced_scheduling: no
  #     (but recording_start and recording_end are missing or commented out)
  #     Error: "recording_start required when advanced_scheduling = no"
  #
  # ⚠️  COMMON MISTAKE #3: Using wrong case
  #     advanced_scheduling: No          ❌ Must be lowercase
  #     advanced_scheduling: True        ❌ Must be lowercase
  #
  # ⚠️  COMMON MISTAKE #4: Quoting boolean values
  #     advanced_scheduling: 'no'        ❌ Don't quote
  #     advanced_scheduling: "yes"       ❌ Don't quote
  #     YAML treats quoted values as strings, not booleans

  # ---------------------------------------------------------------------------
  # 3.2: RECORDING START TIME
  # ---------------------------------------------------------------------------
  # Purpose: Time when detectors start recording each night (uniform schedule only)
  # Format: 'HH:MM:SS' (24-hour format, MUST be quoted, include seconds)
  # Required: YES (if advanced_scheduling = no), NO (if advanced_scheduling = yes)
  # Valid range: 00:00:00 to 23:59:59
  # Used for: CallsPerNight template generation, Night calculation cutoff
  # 
  # WHAT THIS CONTROLS:
  #   When advanced_scheduling = no, this time applies to ALL detectors.
  #   It's the time when recording begins each evening.
  #   
  #   This time determines:
  #     1. When "study night" begins (for Night calculation)
  #     2. Default StartDateTime in CallsPerNight template
  #     3. Expected recording start for calculating hours
  #
  # TIME FORMAT RULES:
  #   MUST use: 'HH:MM:SS' (24-hour format, quoted, with seconds)
  #     HH = Hour (00-23, two digits, 24-hour format)
  #     MM = Minute (00-59, two digits)
  #     SS = Seconds (00-59, two digits, usually :00)
  #     Quotes required
  #     Colons required between HH, MM, SS
  #   
  #   Examples:
  #     '18:00:00'  = 6:00 PM
  #     '20:00:00'  = 8:00 PM
  #     '19:30:00'  = 7:30 PM
  #     '00:00:00'  = Midnight
  #     '23:59:59'  = One second before midnight
  #
  # COMMON RECORDING START TIMES:
  #   Typical bat studies start at sunset or shortly after:
  #     - Summer (June): Earlier sunset → Start around 20:00:00 (8 PM)
  #     - Spring/Fall (March/October): Mid sunset → Start around 18:00:00 (6 PM)
  #     - Winter (December): Later sunset → Start around 16:00:00 (4 PM)
  #   
  #   Best practice: Check sunset time for your location/season
  #   Start 30-60 minutes before sunset to catch early activity
  #
  # RELATIONSHIP TO NIGHT CALCULATION:
  #   The recording_start time determines the "study night" cutoff.
  #   Calls BEFORE this time belong to PREVIOUS night.
  #   Calls AT OR AFTER this time belong to CURRENT night.
  #   
  #   Example with recording_start: '18:00:00':
  #     DateTime: 10/31/2025 17:59:59 → Hour=17 (<18) → Night=10/30
  #     DateTime: 10/31/2025 18:00:00 → Hour=18 (≥18) → Night=10/31
  #     DateTime: 10/31/2025 19:00:00 → Hour=19 (≥18) → Night=10/31
  #     DateTime: 11/01/2025 06:00:00 → Hour=6 (<18)  → Night=10/31
  #   
  #   This ensures all calls from 6 PM Oct 31 to 6 PM Nov 1 belong to "Night Oct 31"
  #
  # IMPACT ON CALLSPERNIGHT TEMPLATE:
  #   When you run Workflow 03, this time pre-fills StartDateTime column:
  #   
  #   Example with recording_start: '18:00:00':
  #     Detector: LPE, Night: 10/4, StartDateTime: 10/4/2025 6:00:00 PM
  #     Detector: LPE, Night: 10/5, StartDateTime: 10/5/2025 6:00:00 PM
  #     ... (all rows start at 6 PM)
  #   
  #   You can manually edit StartDateTime if:
  #     - Late deployment (deployed at 8 PM instead of 6 PM)
  #     - Equipment failure (detector restarted mid-night)
  #     - Battery issues (started late some nights)
  #
  # 12-HOUR vs 24-HOUR FORMAT:
  #   You MUST use 24-hour format (military time):
  #     6:00 PM  = 18:00:00  ✓
  #     8:00 PM  = 20:00:00  ✓
  #     12:00 PM = 12:00:00  ✓ (noon)
  #     12:00 AM = 00:00:00  ✓ (midnight)
  #   
  #   DO NOT use 12-hour format with AM/PM:
  #     '6:00 PM'   ❌ Wrong format
  #     '6:00:00 PM' ❌ Wrong format
  #     '18:00 PM'  ❌ Doesn't make sense (18 is already PM)
  #
  # ZERO-PADDING RULES:
  #   Hours, minutes, and seconds MUST be two digits:
  #     '18:00:00'  ✓ Correct
  #     '18:0:0'    ❌ Missing zeros (should be 18:00:00)
  #     '6:00:00'   ❌ Should be 06:00:00 (pad hour with zero)
  #   
  #   Even if hour is single digit:
  #     6 AM  = '06:00:00'  ✓
  #     9 PM  = '21:00:00'  ✓
  #     Midnight = '00:00:00' ✓
  #
  # SECONDS FIELD:
  #   Even if you don't care about seconds, you MUST include them:
  #     '18:00:00'  ✓ With seconds
  #     '18:00'     ❌ Missing seconds
  #   
  #   Usually seconds are :00 (on the hour or half-hour):
  #     '18:00:00'  ← Recording starts exactly at 6 PM
  #     '18:30:00'  ← Recording starts at 6:30 PM
  #
  # WHAT IF I DEPLOYED LATE?:
  #   Set recording_start to your INTENDED start time, not actual deployment.
  #   
  #   Example:
  #     Intended: 6:00 PM every night
  #     Actual Oct 4: Deployed at 8:30 PM (late)
  #     YAML: recording_start: '18:00:00'  ← Still use 6 PM
  #   
  #   Later, in CallsPerNight template, edit Oct 4 row:
  #     StartDateTime: 10/4/2025 8:30:00 PM  ← Manually adjust
  #   
  #   This keeps your study design clear (intended = 6 PM)
  #   while accounting for actual deployment time
  #
  # EXAMPLES:
  
  recording_start: '18:00:00'             # ✓ 6:00 PM (sunset)
  # recording_start: '20:00:00'           # ✓ 8:00 PM
  # recording_start: '19:30:00'           # ✓ 7:30 PM (half-hour OK)
  # recording_start: '00:00:00'           # ✓ Midnight
  # recording_start: '16:00:00'           # ✓ 4:00 PM (winter deployment)
  # recording_start: '21:00:00'           # ✓ 9:00 PM
  
  # ❌ WRONG: recording_start: 18:00:00   (missing quotes)
  # ❌ WRONG: recording_start: '18:00'    (missing seconds - use :00)
  # ❌ WRONG: recording_start: '6:00:00'  (use 2 digits: 06:00:00)
  # ❌ WRONG: recording_start: '6:00:00 PM'  (use 24-hour: 18:00:00)
  # ❌ WRONG: recording_start: '18:00 PM' (24-hour doesn't use PM)
  # ❌ WRONG: recording_start: '25:00:00' (hour must be 00-23)
  # ❌ WRONG: recording_start: '18:60:00' (minute must be 00-59)
  # ❌ WRONG: recording_start: '18.00.00' (use colons, not dots)
  
  # ⚠️  COMMON MISTAKE #1: Forgetting to convert PM to 24-hour
  #     6 PM ≠ 6:00:00
  #     6 PM = 18:00:00 (add 12 hours for PM times except midnight/noon)
  #     Conversion: If PM and not 12, add 12 to hour
  #     1 PM → 13:00, 6 PM → 18:00, 11 PM → 23:00
  #
  # ⚠️  COMMON MISTAKE #2: Missing leading zero
  #     recording_start: '6:00:00'        ❌ Should be '06:00:00'
  #     recording_start: '9:30:00'        ❌ Should be '09:30:00'
  #
  # ⚠️  COMMON MISTAKE #3: Missing seconds
  #     recording_start: '18:00'          ❌ Must include :00 for seconds
  #
  # ⚠️  COMMON MISTAKE #4: Setting to actual deployment, not intended time
  #     If you deployed late one night, don't change recording_start
  #     Keep recording_start as your DESIGN (what you intended)
  #     Fix actual times in CallsPerNight template later

  # ---------------------------------------------------------------------------
  # 3.3: RECORDING END TIME
  # ---------------------------------------------------------------------------
  # Purpose: Time when detectors stop recording each night/morning (uniform schedule only)
  # Format: 'HH:MM:SS' (24-hour format, MUST be quoted, include seconds)
  # Required: YES (if advanced_scheduling = no), NO (if advanced_scheduling = yes)
  # Valid range: 00:00:00 to 23:59:59
  # Used for: CallsPerNight template generation, recording hours calculation
  # 
  # WHAT THIS CONTROLS:
  #   When advanced_scheduling = no, this time applies to ALL detectors.
  #   It's the time when recording ends each morning.
  #   
  #   This time determines:
  #     1. Default EndDateTime in CallsPerNight template
  #     2. Expected recording duration (end - start)
  #     3. Recording hours calculation
  #
  # OVERNIGHT RECORDINGS:
  #   Bat studies typically record OVERNIGHT (evening → next morning).
  #   The recording_end time is usually LESS than recording_start time.
  #   
  #   Example:
  #     recording_start: '18:00:00'  (6 PM)
  #     recording_end: '07:00:00'    (7 AM next morning)
  #     Duration: 13 hours (6 PM → 7 AM)
  #   
  #   The pipeline automatically handles overnight math:
  #     If end < start → Crossed midnight → Add 1 day to end time
  #
  # CALCULATING RECORDING HOURS:
  #   The pipeline calculates hours from start to end:
  #   
  #   Example 1: Overnight (typical)
  #     Start: 18:00:00, End: 07:00:00
  #     Calculation: (24 - 18) + 7 = 13 hours
  #   
  #   Example 2: Longer overnight
  #     Start: 18:00:00, End: 08:00:00
  #     Calculation: (24 - 18) + 8 = 14 hours
  #   
  #   Example 3: Same day (unusual)
  #     Start: 06:00:00, End: 18:00:00
  #     Calculation: 18 - 6 = 12 hours
  #
  # COMMON RECORDING END TIMES:
  #   Typical bat studies end at sunrise or shortly after:
  #     - Summer (June): Early sunrise → End around 05:00:00 (5 AM)
  #     - Spring/Fall (March/October): Mid sunrise → End around 07:00:00 (7 AM)
  #     - Winter (December): Late sunrise → End around 08:00:00 (8 AM)
  #   
  #   Best practice: Check sunrise time for your location/season
  #   End 30-60 minutes after sunrise to catch late activity
  #
  # IMPACT ON CALLSPERNIGHT TEMPLATE:
  #   When you run Workflow 03, this time pre-fills EndDateTime column:
  #   
  #   Example with recording_end: '07:00:00':
  #     Detector: LPE, Night: 10/4, EndDateTime: 10/5/2025 7:00:00 AM
  #     Detector: LPE, Night: 10/5, EndDateTime: 10/6/2025 7:00:00 AM
  #     ... (all rows end at 7 AM next morning)
  #   
  #   The template shows the NEXT DAY for EndDateTime because overnight recording
  #
  # TIME FORMAT RULES:
  #   Same as recording_start (see section 3.2):
  #     - 24-hour format (00-23 for hours)
  #     - Two digits for all fields (HH:MM:SS)
  #     - Colons between fields
  #     - Quotes required
  #     - Include seconds (usually :00)
  #
  # WHAT IF RECORDING STOPPED EARLY?:
  #   Set recording_end to your INTENDED end time, not actual.
  #   
  #   Example:
  #     Intended: 7:00 AM every morning
  #     Actual Oct 5: SD card filled at 3:00 AM (stopped early)
  #     YAML: recording_end: '07:00:00'  ← Still use 7 AM
  #   
  #   Later, in CallsPerNight template, edit Oct 4 row:
  #     EndDateTime: 10/5/2025 3:00:00 AM  ← Manually adjust
  #
  # RELATIONSHIP TO RECORDING_START:
  #   Pipeline validates: end time must be different from start time
  #   
  #   Valid:
  #     start: '18:00:00', end: '07:00:00'  ✓ Overnight (13 hours)
  #     start: '18:00:00', end: '18:01:00'  ✓ Very short but valid
  #   
  #   Invalid:
  #     start: '18:00:00', end: '18:00:00'  ❌ Same time (0 hours)
  #     Error: "recording_start and recording_end cannot be identical"
  #
  # EXAMPLES:
  
  recording_end: '07:00:00'               # ✓ 7:00 AM (sunrise)
  # recording_end: '08:00:00'             # ✓ 8:00 AM
  # recording_end: '06:30:00'             # ✓ 6:30 AM (half-hour OK)
  # recording_end: '05:00:00'             # ✓ 5:00 AM (summer)
  # recording_end: '23:59:59'             # ✓ Just before midnight (unusual)
  
  # ❌ WRONG: recording_end: 07:00:00     (missing quotes)
  # ❌ WRONG: recording_end: '7:00:00'    (use 2 digits: 07:00:00)
  # ❌ WRONG: recording_end: '7:00 AM'    (use 24-hour: 07:00:00)
  # ❌ WRONG: recording_end: '07:00'      (missing seconds)
  # ❌ WRONG: recording_end: '25:00:00'   (hour must be 00-23)
  
  # ⚠️  COMMON MISTAKE #1: Confusing overnight with same-day
  #     If bats record 6 PM to 7 AM (overnight):
  #     Start: '18:00:00', End: '07:00:00'  ✓ Correct
  #     
  #     NOT:
  #     Start: '18:00:00', End: '19:00:00'  ← Only 1 hour!
  #
  # ⚠️  COMMON MISTAKE #2: Setting end = start
  #     recording_start: '18:00:00'
  #     recording_end: '18:00:00'           ❌ Can't be same time
  #
  # ⚠️  COMMON MISTAKE #3: Using next day's date
  #     DON'T include date in time - just time!
  #     recording_end: '07:00:00'           ✓ Time only
  #     recording_end: '2025-10-05 07:00:00' ❌ Don't include date

  # ---------------------------------------------------------------------------
  # 3.4: INTENDED HOURS
  # ---------------------------------------------------------------------------
  # Purpose: Expected recording duration per night (for validation/outlier detection)
  # Format: Numeric (no quotes, can be decimal)
  # Required: NO (optional, but recommended for validation)
  # Valid range: 0.1 to 24
  # Used for: Validating RecordingHours calculations, flagging outliers
  # 
  # WHAT THIS IS FOR:
  #   This is the EXPECTED number of hours each night should record.
  #   It's calculated from: recording_end - recording_start
  #   
  #   The pipeline uses this to:
  #     1. Validate your RecordingHours calculations
  #     2. Flag nights with unusual recording durations
  #     3. Detect equipment failures or early stops
  #   
  #   Example:
  #     recording_start: '18:00:00' (6 PM)
  #     recording_end: '07:00:00' (7 AM)
  #     Calculation: 7 AM next day - 6 PM = 13 hours
  #     intended_hours: 13
  #
  # HOW TO CALCULATE:
  #   Step 1: Calculate hours from start to end
  #   
  #   Overnight example:
  #     Start: 18:00 (6 PM)
  #     End: 07:00 (7 AM next day)
  #     Hours from 6 PM to midnight: 24 - 18 = 6 hours
  #     Hours from midnight to 7 AM: 7 hours
  #     Total: 6 + 7 = 13 hours
  #   
  #   Same-day example (unusual):
  #     Start: 06:00 (6 AM)
  #     End: 18:00 (6 PM same day)
  #     Total: 18 - 6 = 12 hours
  #
  # DECIMAL HOURS:
  #   You can use decimals for half-hours, quarter-hours, etc:
  #     13.5 hours  = 13 hours 30 minutes
  #     12.25 hours = 12 hours 15 minutes
  #     10.75 hours = 10 hours 45 minutes
  #   
  #   Example:
  #     Start: 18:00:00, End: 07:30:00
  #     Calculation: 13 hours + 0.5 hours = 13.5 hours
  #     intended_hours: 13.5
  #
  # VALIDATION BEHAVIOR:
  #   If you set intended_hours, the pipeline:
  #     1. Calculates RecordingHours for each night
  #     2. Compares to intended_hours
  #     3. Flags nights that differ significantly
  #   
  #   Example:
  #     intended_hours: 13
  #     Night Oct 4: RecordingHours = 13.0  ✓ Matches
  #     Night Oct 5: RecordingHours = 7.5   ⚠️  Warning: Only 7.5 hours (expected 13)
  #     Night Oct 6: RecordingHours = 13.2  ✓ Close enough (small difference)
  #   
  #   This helps you catch:
  #     - SD cards that filled early
  #     - Battery failures
  #     - Detectors that stopped recording
  #     - Manual errors in CallsPerNight template
  #
  # WHEN TO OMIT:
  #   You can omit intended_hours if:
  #     - You have advanced_scheduling (different hours per detector)
  #     - You don't want validation warnings
  #     - Your recording hours vary significantly by night
  #   
  #   If omitted, pipeline still works - just no validation warnings
  #
  # NUMBER FORMAT:
  #   intended_hours is a NUMBER, not a string:
  #     intended_hours: 13      ✓ Number (no quotes)
  #     intended_hours: 13.5    ✓ Decimal (no quotes)
  #     intended_hours: '13'    ❌ Don't quote numbers
  #     intended_hours: "13"    ❌ Don't quote numbers
  #
  # UNITS:
  #   Value is in HOURS, no units needed:
  #     intended_hours: 13      ✓ 13 hours
  #     intended_hours: 13 hours ❌ Don't include units
  #     intended_hours: 780     ❌ Don't use minutes (use 13 for 780 minutes)
  #
  # EXAMPLES:
  
  intended_hours: 13                      # ✓ 13 hours (18:00 to 07:00)
  # intended_hours: 10                    # ✓ 10 hours (20:00 to 06:00)
  # intended_hours: 12.5                  # ✓ 12.5 hours (12 hours 30 minutes)
  # intended_hours: 14                    # ✓ 14 hours (18:00 to 08:00)
  # intended_hours: 11.75                 # ✓ 11 hours 45 minutes
  
  # ❌ WRONG: intended_hours: '13'        (don't quote numbers)
  # ❌ WRONG: intended_hours: 13 hours    (don't include units)
  # ❌ WRONG: intended_hours: 13.0 hours  (no units)
  # ❌ WRONG: intended_hours: 780         (use hours, not minutes)
  # ❌ WRONG: intended_hours: 25          (can't be more than 24 hours)
  # ❌ WRONG: intended_hours: 0           (must be positive)
  
  # ⚠️  COMMON MISTAKE #1: Calculating wrong for overnight
  #     Start: 6 PM (18:00), End: 7 AM (07:00)
  #     WRONG: 7 - 18 = -11 hours        ❌ Negative!
  #     RIGHT: (24 - 18) + 7 = 13 hours  ✓
  #
  # ⚠️  COMMON MISTAKE #2: Using minutes instead of hours
  #     13 hours = 780 minutes
  #     But intended_hours should be 13, not 780
  #
  # ⚠️  COMMON MISTAKE #3: Including units in YAML
  #     intended_hours: 13 hours         ❌ YAML interprets as string
  #     intended_hours: 13               ✓ Just the number


## SECTION 4: OUTPUT PREFERENCES
# ==============================================================================

output_preferences:

  # ---------------------------------------------------------------------------
  # 4.1: MASTER FILENAME
  # ---------------------------------------------------------------------------
  # Purpose: Filename for final master dataset (all calls, all detectors, all nights)
  # Format: String with .csv extension (quotes optional unless spaces)
  # Required: NO (uses default if omitted)
  # Default: final_master.csv
  # Used for: Final output filename in Workflow 04
  # 
  # WHAT THIS FILE CONTAINS:
  #   The master file is the FINAL, COMPLETE dataset with:
  #     - All bat calls from all detectors
  #     - All nights of recording
  #     - Standardized columns (Detector, DateTime, auto_id, etc.)
  #     - Deduplication complete
  #     - Timezone conversion complete
  #     - Ready for analysis
  #   
  #   This is the "gold standard" dataset for your study.
  #
  # FILE LOCATION:
  #   Saved in: results/csv/ (or custom save_directory)
  #   Full path example: results/csv/final_master.csv
  #
  # FILENAME RULES:
  #   - MUST end with .csv extension
  #   - Use quotes if filename contains spaces
  #   - No path - just filename (directory set in save_directory)
  #   - Avoid special characters (stick to letters, numbers, underscores, hyphens)
  #
  # NAMING CONVENTIONS:
  #   Good filenames are:
  #     ✓ Descriptive: "Schmeeckle2025_master.csv"
  #     ✓ Dated: "master_2025-10-31.csv"
  #     ✓ Simple: "final_master.csv"
  #   
  #   Avoid:
  #     ❌ Generic: "data.csv" (not descriptive)
  #     ❌ No extension: "master" (needs .csv)
  #     ❌ Wrong extension: "master.xlsx" (pipeline creates CSV)
  #
  # EXAMPLES:
  
  master_filename: final_master.csv       # ✓ Default (simple)
  # master_filename: SchmeeckleMaster.csv # ✓ Study-specific
  # master_filename: master_2025.csv      # ✓ Year included
  # master_filename: 'My Master 2025.csv' # ✓ Quotes for spaces
  # master_filename: bat_calls_all.csv    # ✓ Descriptive
  
  # ❌ WRONG: master_filename: master     (missing .csv extension)
  # ❌ WRONG: master_filename: My Master.csv  (spaces without quotes)
  # ❌ WRONG: master_filename: master.xlsx    (wrong extension - pipeline creates CSV)
  # ❌ WRONG: master_filename: results/master.csv  (don't include path)
  
  # ⚠️  COMMON MISTAKE: Including directory path in filename
  #     master_filename: results/csv/master.csv  ❌ Don't include path
  #     master_filename: master.csv              ✓ Just filename
  #     (Directory is set separately in save_directory)

  # ---------------------------------------------------------------------------
  # 4.2: CALLSPERNIGHT FILENAME
  # ---------------------------------------------------------------------------
  # Purpose: Filename for final CallsPerNight dataset (nightly summaries)
  # Format: String with .csv extension (quotes optional unless spaces)
  # Required: NO (uses default if omitted)
  # Default: CallsPerNight_final.csv
  # Used for: Final output filename in Workflow 04
  # 
  # WHAT THIS FILE CONTAINS:
  #   The CallsPerNight file is a SUMMARY dataset with:
  #     - One row per Detector × Night combination
  #     - CallsPerNight counts
  #     - StartDateTime and EndDateTime (user-edited)
  #     - RecordingHours (calculated from user edits)
  #     - Ready for statistical analysis
  #   
  #   This is the primary dataset for analyzing bat activity patterns.
  #
  # FILE LOCATION:
  #   Saved in: results/csv/ (or custom save_directory)
  #   Full path example: results/csv/CallsPerNight_final.csv
  #
  # FILENAME RULES:
  #   Same as master_filename (see section 4.1):
  #     - MUST end with .csv extension
  #     - Use quotes if filename contains spaces
  #     - No path - just filename
  #
  # EXAMPLES:
  
  callspernight_filename: CallsPerNight_final.csv  # ✓ Default
  # callspernight_filename: NightlyCalls.csv       # ✓ Short and clear
  # callspernight_filename: CPNight_2025.csv       # ✓ Abbreviated with year
  # callspernight_filename: bat_activity.csv       # ✓ Descriptive
  
  # ❌ WRONG: callspernight_filename: CallsPerNight  (missing .csv)
  # ❌ WRONG: callspernight_filename: CPN.xlsx       (wrong extension)
  
  # ⚠️  NOTE: This filename is for the FINAL output from Workflow 04
  #     The TEMPLATE from Workflow 03 has a different name (auto-generated)

  # ---------------------------------------------------------------------------
  # 4.3: SAVE DIRECTORY
  # ---------------------------------------------------------------------------
  # Purpose: Directory where final output files are saved
  # Format: Path string (forward slashes, quotes if spaces, relative to project root)
  # Required: NO (uses default if omitted)
  # Default: results/csv
  # Used for: Output directory in Workflow 04
  # 
  # WHAT GETS SAVED HERE:
  #   Final outputs from Workflow 04:
  #     - final_master.csv (or custom master_filename)
  #     - CallsPerNight_final.csv (or custom callspernight_filename)
  #     - Any other final analysis outputs
  #   
  #   This is separate from:
  #     - outputs/ (intermediate checkpoint files)
  #     - logs/ (processing logs)
  #     - data/ (raw input data)
  #
  # PATH FORMAT:
  #   - Relative to project root (no leading /)
  #   - Use forward slashes (/)
  #   - Will be created if doesn't exist
  #   - Don't include trailing slash
  #
  # DIRECTORY STRUCTURE:
  #   Recommended structure:
  #     results/
  #       ├── csv/           ← Final CSV outputs
  #       ├── plots/         ← Figures and visualizations (future)
  #       └── reports/       ← Analysis reports (future)
  #
  # AUTO-CREATION:
  #   If directory doesn't exist, pipeline creates it automatically.
  #   You don't need to create it manually.
  #
  # EXAMPLES:
  
  save_directory: results/csv             # ✓ Default (simple)
  # save_directory: outputs                # ✓ Simple top-level
  # save_directory: results/final          # ✓ Subdirectory
  # save_directory: 'results/final output' # ✓ Quotes for spaces
  # save_directory: final_data/2025        # ✓ Year-specific
  
  # ❌ WRONG: save_directory: results\csv  (use /, not \)
  # ❌ WRONG: save_directory: results/csv/ (don't include trailing slash)
  # ❌ WRONG: save_directory: /results/csv (don't include leading slash)
  # ❌ WRONG: save_directory: C:/Users/Rusty/Project/results  (use relative path)
  
  # ⚠️  NOTE: Path is relative to project root
  #     If your project is at: C:/Users/Rusty/BatProject/
  #     And save_directory: results/csv
  #     Files will be saved to: C:/Users/Rusty/BatProject/results/csv/


# ==============================================================================
# COMPLETE EXAMPLE - COPY THIS TEMPLATE
# ==============================================================================

# config_version: 1
# 
# study_parameters:
#   study_name: SchmeeckleBatStudy
#   start_date: '2025-10-04'
#   end_date: '2025-10-31'
#   detector_mapping:
#     245AAA0666BC08AE: LPI
#     245AAA0666BC1507: LPE
#     247475035FDF1A0D: SMI
#     247AA5015FDF19F3: SME
#     248D9B025FDF0B90: MCO
#     249C600164F3532A: SMO
#     24A04F085FDF0C84: MCI
#     24A04F085FDF19C0: MCE
#     24E144036484A442: LPO
#   timezone: America/Chicago
#   external_data_sources:
#     - 'F:/Schmeeckle analyzed 102725'
# 
# processing_options:
#   advanced_scheduling: no
#   recording_start: '18:00:00'
#   recording_end: '07:00:00'
#   intended_hours: 13
# 
# output_preferences:
#   master_filename: final_master.csv
#   callspernight_filename: CallsPerNight_final.csv
#   save_directory: results/csv


# ==============================================================================
# TROUBLESHOOTING COMMON ERRORS
# ==============================================================================

# Error: "external_data_sources must be a list"
# Fix: Change from this:
#   external_data_sources: F:\path\to\data
# To this:
#   external_data_sources:
#     - 'F:/path/to/data'

# Error: "Invalid date format"
# Fix: Ensure dates are quoted and in YYYY-MM-DD format:
#   start_date: '2025-01-15'  (not 01/15/2025 or 2025-1-15)

# Error: "Invalid time format"
# Fix: Ensure times are quoted, 24-hour, with seconds:
#   recording_start: '18:00:00'  (not 6:00 PM or 18:00)

# Error: "Duplicated key"
# Fix: Each detector_id can only appear once in detector_mapping

# Error: "end_date must be >= start_date"
# Fix: Check your dates - end_date must be same or later than start_date

# Error: "scanner error" or "mapping values are not allowed here"
# Fix: Check indentation - use 2 spaces, NO tabs
# Fix: Check for missing colons after keys
# Fix: Check for missing quotes around values with spaces

# Error: "Invalid timezone"
# Fix: Use IANA format (America/Chicago, not CST)
# Fix: Check spelling and case (America/Chicago, not america/chicago)

# Error: "recording_start required when advanced_scheduling = no"
# Fix: Set recording_start and recording_end when using uniform schedule

# Error: "detector_schedules.csv required when advanced_scheduling = yes"
# Fix: Create detector_schedules.csv file when using advanced scheduling


# ==============================================================================
# VALIDATION CHECKLIST
# ==============================================================================

# Before saving your YAML file, verify:
# ☐ config_version: 1 is present (no quotes)
# ☐ All dates in 'YYYY-MM-DD' format with quotes
# ☐ All times in 'HH:MM:SS' format with quotes (24-hour)
# ☐ All Windows paths use forward slashes (/)
# ☐ All paths with spaces are quoted
# ☐ external_data_sources has dashes (-) for each path
# ☐ detector_mapping has one line per detector, properly indented (2 spaces)
# ☐ No tabs used for indentation (spaces only)
# ☐ All colons (:) have space after them
# ☐ Boolean values are lowercase (yes/no or true/false)
# ☐ Numeric values are not quoted (intended_hours: 13, not '13')
# ☐ File saved as UTF-8 encoding (not ANSI or other)
# ☐ No trailing spaces after values
# ☐ Timezone is valid IANA format (check https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
# ☐ end_date >= start_date
# ☐ recording_start ≠ recording_end


# ==============================================================================
# END OF PARAMETER GUIDE
# ==============================================================================