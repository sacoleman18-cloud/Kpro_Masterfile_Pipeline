# ==============================================================================
# PHASE ORCHESTRATION ARCHITECTURE AUDIT REPORT
# ==============================================================================
# Date: 2026-02-08
# Version: 3.0 Architecture Transition
# Purpose: Document required changes to align standards with phase orchestration
# ==============================================================================

## EXECUTIVE SUMMARY

The repository has been refactored from a **module-based orchestration** pattern to a **checkpointed phase orchestration** architecture. This report documents:

1. Completed implementation changes
2. Required documentation updates
3. Terminology changes throughout standards
4. Updated patterns and best practices

---

## 1. ARCHITECTURAL TRANSITION SUMMARY

### 1.1 Previous Architecture (Module-Based Orchestration)

**Pattern:**
- 3 "chunk" orchestrators directly calling 7 processing modules
- Orchestrators: run_ingest_standardize(), run_cpn_template(), run_finalize_to_report()
- Modules located in R/modules/ with internal staged execution
- module_runner.R treated as "debug tool" in R/debug/

**Characteristics:**
- Chunk-based terminology (Chunk 1, Chunk 2, Chunk 3)
- Orchestrators call module functions directly
- Human-in-the-loop checkpoint implicit (template editing)
- No structured result passing between orchestrators

### 1.2 Current Architecture (Checkpointed Phase Orchestration)

**Pattern:**
- 3 "phase" orchestrators composing module execution layer
- Phase orchestrators: run_phase1_data_preparation(), run_phase2_template_generation(), run_phase3_analysis_reporting()
- Module execution layer (module_runner.R) in R/modules/ provides callable interfaces
- Explicit checkpointed phases with structured result passing

**Characteristics:**
- Phase-based terminology (Phase 1, Phase 2, Phase 3)
- Phase orchestrators call run_module_*() functions from module_runner.R
- Explicit human-in-the-loop checkpoint in Phase 2 (human_action_required flag)
- Structured results chain between phases (phase1_result → Phase 2 → phase2_result → Phase 3)
- Module runner.R is core infrastructure (not a debug tool)

---

## 2. KEY TERMINOLOGY CHANGES

| Old Term | New Term | Context |
|----------|----------|---------|
| "Chunk 1/2/3" | "Phase 1/2/3" | Pipeline execution stages |
| "Chunk orchestrators" | "Phase orchestrators" | High-level pipeline coordination |
| "Debug tool" | "Module execution layer" | module_runner.R classification |
| "R/debug/module_runner.R" | "R/modules/module_runner.R" | File location and purpose |
| "Production orchestrators" | "Phase orchestrators" | Primary execution pattern |
| "Debug module runners" | "Module execution layer" | Module interface functions |

---

## 3. ARCHITECTURAL LAYER UPDATES

### 3.1 Layer 7: Pipeline Orchestrators (R/pipeline/)

**OLD DESCRIPTION:**
- "Entry point scripts that coordinate module execution"
- "Thin wrappers calling modules in sequence"
- "Three chunks: Ingest/Standardize, CPN Template, Finalize/Report"

**NEW DESCRIPTION:**
- **PHASE ORCHESTRATORS (Primary Pattern):**
  - run_phase1_data_preparation.R (Modules 1-2)
  - run_phase2_template_generation.R (Module 3 + human-in-the-loop)
  - run_phase3_analysis_reporting.R (Modules 4-7)
  - Checkpointed execution with structured result passing
- **Legacy orchestrators (deprecated):**
  - run_ingest_standardize.R, run_cpn_template.R, run_finalize_to_report.R

### 3.2 Layer 9: Module Execution Layer

**OLD:** Layer 9: debug/ (Optional Development Tools)
- module_runner.R in R/debug/
- Classified as "Individual module testing (7 runners)"
- Described as "Debug tools" and "Convenience functions for debugging"

**NEW:** Layer 9: modules/module_runner.R (Module Execution Layer)
- module_runner.R in R/modules/
- Classified as "Module Execution Interface (7 runners + 1 utility)"
- Described as:
  - "Provides callable interfaces for all 7 pipeline modules"
  - "Used by phase orchestrators to execute modules"
  - "Supports individual module testing and custom execution sequences"
  - "Core infrastructure for checkpointed phase orchestration"

---

## 4. CHECKPOINTED PHASE STRUCTURE

### 4.1 Phase Definitions

**PHASE 1: Data Preparation**
- **Modules:** 1-2 (ingestion, standardization)
- **Input:** Raw CSVs from data/ directory
- **Output:** kpro_master.csv checkpoint
- **Checkpoint:** outputs/checkpoints/02_kpro_master_*.csv
- **Function:** run_phase1_data_preparation(verbose = FALSE)
- **Returns:** phase1_result with kpro_master data + metadata

**PHASE 2: Template Generation**
- **Modules:** 3 (CPN template)
- **Input:** phase1_result (structured result from Phase 1)
- **Output:** CPN_Template_EDIT_THIS.csv (requires human editing)
- **Checkpoint:** outputs/03_CallsPerNight_Template_EDIT_THIS_*.csv
- **Function:** run_phase2_template_generation(phase1_result, manual_id_file, verbose)
- **Returns:** phase2_result with template path + human_action_required = TRUE
- **Human-in-the-Loop:** User MUST edit template before Phase 3

**PHASE 3: Analysis & Reporting**
- **Modules:** 4-7 (finalize_cpn, summary_stats, plotting, report_release)
- **Input:** phase2_result (structured result from Phase 2, edited template)
- **Output:** Final report, plots, release bundle
- **Outputs:**
  - results/bat_activity_report.html
  - results/figures/png/*.png (26 plots)
  - results/csv/summary_stats/*.csv
  - results/release_bundle_*.zip
- **Function:** run_phase3_analysis_reporting(phase2_result, edited_template_file, verbose)
- **Returns:** phase3_result with pipeline_complete = TRUE

### 4.2 Phase Chaining Pattern

```r
# Recommended execution pattern
source('R/functions/load_all.R')
source('R/pipeline/run_phase1_data_preparation.R')
source('R/pipeline/run_phase2_template_generation.R')
source('R/pipeline/run_phase3_analysis_reporting.R')

# Phase 1: Data Preparation
phase1_result <- run_phase1_data_preparation(verbose = TRUE)

# Phase 2: Template Generation
phase2_result <- run_phase2_template_generation(
  phase1_result = phase1_result,
  verbose = TRUE
)

# CHECKPOINT: User edits CPN_Template_EDIT_THIS.csv

# Phase 3: Analysis & Reporting
phase3_result <- run_phase3_analysis_reporting(
  phase2_result = phase2_result,
  verbose = TRUE
)
```

### 4.3 Phase Result Structure

Each phase returns a structured list with:
- `phase`: Integer (1, 2, or 3)
- `phase_name`: Character (e.g., "Data Preparation")
- Data artifacts (kpro_master, cpn_template, etc.)
- `checkpoint_path` or `template_edit_path`: Character (checkpoint file location)
- `metadata`: List with execution statistics
- `validation_html_paths`: Character vector (validation report paths)
- Phase 2 only: `human_action_required`: Logical (TRUE)
- Phase 3 only: `pipeline_complete`: Logical (TRUE)
- `module_results`: List with raw module outputs (for advanced use)

---

## 5. MODULE EXECUTION LAYER INTERFACE

### 5.1 module_runner.R Functions

**Location:** R/modules/module_runner.R

**7 Module Runner Functions:**
1. `run_module_ingestion(verbose = FALSE)`
2. `run_module_standardization(ingestion_result, verbose = FALSE)`
3. `run_module_cpn_template(standardization_result, manual_id_file = NULL, verbose = FALSE)`
4. `run_module_finalize_cpn(cpn_template_result, edited_template_file = NULL, verbose = FALSE)`
5. `run_module_summary_stats(finalize_result, verbose = FALSE)`
6. `run_module_plotting(summary_stats_result, verbose = FALSE)`
7. `run_module_report_release(plotting_result, summary_stats_result, verbose = FALSE)`

**Utility Function:**
8. `run_all_modules(verbose = FALSE)` - Executes all 7 modules with pause prompts

### 5.2 Usage Pattern

**By Phase Orchestrators (Primary):**
```r
# Inside run_phase1_data_preparation.R
source(file.path("R", "modules", "module_runner.R"))

module1_result <- run_module_ingestion(verbose = verbose)
module2_result <- run_module_standardization(module1_result, verbose = verbose)
```

**For Individual Testing:**
```r
source('R/functions/load_all.R')
source('R/modules/module_runner.R')

# Test individual modules
r1 <- run_module_ingestion(verbose = TRUE)
r2 <- run_module_standardization(r1, verbose = TRUE)
```

---

## 6. REQUIRED DOCUMENTATION UPDATES

### 6.1 Architecture Standards (ST_architecture_standards.md)

**Section 1: Directory Structure**
- Update R/pipeline/ description to show phase orchestrators as primary
- Update R/modules/ to mention module_runner.R as execution layer
- Remove R/debug/ references (no longer exists)

**Section 3: Orchestrator Function Structure**
- Update "Primary Execution Model" section:
  - Change "Shiny-Driven Chunks" → "Checkpointed Phase Orchestration"
  - Update table to show Phases 1-3 instead of Chunks 1-3
  - Add human-in-the-loop checkpoint documentation
  - Show structured result passing pattern
- Update header template to show phase orchestrator pattern
- Update helper functions documentation

**Section 4: Module Structure** (if exists)
- Document module execution layer concept
- Explain run_module_*() interface pattern
- Show how modules are called by phase orchestrators

**Section 5: Data Flow**
- Update to show phase → phase structured passing
- Document checkpoint files produced by each phase
- Show human-in-the-loop interruption in Phase 2

### 6.2 Code Design Standards (ST_code_design_standards.md)

**Function Naming:**
- Add pattern: Phase orchestrators use `run_phase#_descriptive_name()`
- Add pattern: Module runners use `run_module_name()`

**Return Value Standards:**
- Document structured phase result format
- Explain phase result chaining pattern
- Show metadata structure requirements

**Function Parameters:**
- Document phase orchestrator signature: (phaseN-1_result, verbose)
- Document module runner signature: (previous_module_result, verbose)

### 6.3 Development Standards (ST_development_standards.md)

**Testing Patterns:**
- Update Tester.R usage to show phase chaining
- Show individual module testing with module_runner.R
- Document interrupted execution for human-in-the-loop

**Debugging Patterns:**
- Remove "debug mode" terminology
- Replace with "module execution layer" for individual testing
- Update module_runner.R path from R/debug/ to R/modules/

### 6.4 Logging/Console Standards (ST_logging_console_standards.md)

**Phase Progress Messages:**
- Add guidelines for phase orchestrator banners
- Document "Phase X of 3" progress format
- Show checkpoint instruction messages
- Document human-in-the-loop warning messages

### 6.5 Quick Start Guide (QUICKSTART.md.md)

**Usage Examples:**
- Replace chunk-based examples with phase-based examples
- Show recommended phase chaining pattern
- Document human-in-the-loop pause in Phase 2
- Update all code examples to use new phase orchestrators

---

## 7. IMPLEMENTED CHANGES SUMMARY

### 7.1 Code Changes (COMPLETE)

✅ **File Relocation:**
- Moved R/debug/module_runner.R → R/modules/module_runner.R

✅ **File Updates:**
- Updated module_runner.R header (classification: Module Execution Layer)
- Created run_phase1_data_preparation.R (181 lines)
- Created run_phase2_template_generation.R (202 lines)
- Created run_phase3_analysis_reporting.R (286 lines)
- Updated tests/Tester.R to use phase chaining pattern
- Updated R/functions/load_all.R Layer 9 and usage examples

✅ **Phase Orchestrator Pattern:**
- All 3 phases implemented as callable functions
- Structured result passing between phases
- Explicit human-in-the-loop checkpoint in Phase 2
- Preserved verbose and logging behavior
- Maintained Shiny compatibility (pure functions, no global side effects)

### 7.2 Documentation Changes (IN PROGRESS)

⏳ **load_all.R:**
- ✅ Updated Layer 9 description
- ✅ Updated "Ready to run" section
- ✅ Updated usage examples
- ✅ Updated architecture overview

⏳ **Standards Documentation:**
- ⏳ ST_architecture_standards.md (requires comprehensive update)
- ⏳ ST_code_design_standards.md (requires pattern updates)
- ⏳ ST_logging_console_standards.md (requires phase message guidelines)
- ⏳ ST_development_standards.md (requires testing pattern updates)
- ⏳ QUICKSTART.md.md (requires usage example updates)
- ⏳ ST_STANDARDS_INDEX.md (may require version update)

---

## 8. NEXT ACTIONS

### Priority 1: Core Architecture Documentation

1. **Update ST_architecture_standards.md:**
   - Section 1: Directory structure (show phase orchestrators, module execution layer)
   - Section 3: Orchestrator structure (phase pattern, checkpoints, result passing)
   - Add Section: Phase Orchestration Pattern (comprehensive guide)
   - Add Section: Module Execution Layer (module_runner.R usage)
   - Update all examples to use phase orchestrators

2. **Update ST_code_design_standards.md:**
   - Add phase orchestrator naming pattern
   - Add module runner naming pattern
   - Document structured result format for phase chaining
   - Add function signature standards for phase orchestrators
   - Update return value standards

### Priority 2: Development & Usage Documentation

3. **Update ST_development_standards.md:**
   - Replace "debug mode" with "module execution layer"
   - Update testing patterns (phase chaining, individual modules)
   - Update module_runner.R path references
   - Document human-in-the-loop testing workflow

4. **Update QUICKSTART.md.md:**
   - Replace all chunk-based examples with phase-based examples
   - Show recommended phase chaining pattern
   - Document human-in-the-loop checkpoint clearly
   - Update all function names and paths

### Priority 3: Supporting Documentation

5. **Update ST_logging_console_standards.md:**
   - Add phase progress banner standards
   - Document checkpoint instruction format
   - Add human-in-the-loop warning message pattern

6. **Update ST_STANDARDS_INDEX.md:**
   - Increment version to 3.0 (architectural change)
   - Update change log with phase orchestration transition

### Priority 4: Cleanup & Deprecation

7. **Deprecation Strategy:**
   - Add deprecation notices to old orchestrators (run_ingest_standardize.R, etc.)
   - Document migration path from chunks to phases
   - Create DEPRECATION_NOTICE.md if needed

8. **File Cleanup:**
   - Remove or archive old orchestrator backup files (_NEW.R, _LEGACY.R)
   - Update .Rbuildignore if needed

---

## 9. TERMINOLOGY REFERENCE

### 9.1 Correct Terms (Use These)

- **Phase orchestrators** (not "chunk orchestrators")
- **Phase 1, Phase 2, Phase 3** (not "Chunk 1/2/3")
- **Phase-based orchestration** (not "chunk-based execution")
- **Checkpointed phase orchestration** (architecture name)
- **Module execution layer** (not "debug tools" or "module runners")
- **run_phase#_name()** (phase orchestrator functions)
- **run_module_name()** (module execution interface functions)
- **R/modules/module_runner.R** (not R/debug/module_runner.R)
- **Human-in-the-loop checkpoint** (explicit term for manual editing)
- **Structured result passing** (phase → phase data flow)
- **phase1_result, phase2_result, phase3_result** (result variable names)

### 9.2 Deprecated Terms (Do Not Use)

- ❌ "Chunk orchestrators" → Use "phase orchestrators"
- ❌ "Chunk 1/2/3" → Use "Phase 1/2/3"
- ❌ "Debug tools" → Use "module execution layer"
- ❌ "Debug mode" → Use "module execution" or "individual module testing"
- ❌ "R/debug/module_runner.R" → Use "R/modules/module_runner.R"
- ❌ "Production orchestrators" → Use "phase orchestrators"
- ❌ "Debug module runners" → Use "module execution layer"

---

## 10. VALIDATION CHECKLIST

Use this checklist to verify documentation updates:

### Architecture Standards
- [ ] Directory structure shows phase orchestrators
- [ ] Directory structure mentions module execution layer
- [ ] No references to R/debug/
- [ ] "Chunk" terminology replaced with "Phase" throughout
- [ ] Phase orchestration pattern documented
- [ ] Human-in-the-loop checkpoint documented
- [ ] Structured result passing explained
- [ ] Examples use run_phase#_name() functions

### Code Design Standards
- [ ] Phase orchestrator naming pattern documented
- [ ] Module runner naming pattern documented
- [ ] Structured result format specified
- [ ] Phase orchestrator function signature documented
- [ ] Module runner function signature documented

### Development Standards
- [ ] "Debug mode" terminology removed
- [ ] "Module execution layer" terminology used
- [ ] Testing patterns show phase chaining
- [ ] module_runner.R path updated to R/modules/
- [ ] Human-in-the-loop testing workflow documented

### Quick Start Guide
- [ ] All examples use phase orchestrators
- [ ] Phase chaining pattern shown
- [ ] Human-in-the-loop checkpoint explained
- [ ] No references to old chunk orchestrators
- [ ] Correct file paths (R/modules/module_runner.R)

### Logging Standards
- [ ] Phase progress banners documented
- [ ] Checkpoint instruction format specified
- [ ] Human-in-the-loop warning pattern shown

### Standards Index
- [ ] Version incremented to 3.0
- [ ] Change log updated with architecture transition

---

## 11. BENEFITS OF NEW ARCHITECTURE

### 11.1 Improved Clarity

- **Explicit checkpoints:** Each phase produces clear checkpoint files
- **Human-in-the-loop visibility:** Phase 2 explicitly flags manual editing requirement
- **Structured data flow:** phase_result objects chain between phases
- **Clear separation:** Phase orchestrators vs. module execution layer

### 11.2 Better Testability

- **Phase-by-phase testing:** Can test each phase independently
- **Module-by-module testing:** Can test individual modules via module_runner.R
- **Interrupted execution:** Can pause after Phase 2 for template editing
- **Result inspection:** Structured phase_result objects easy to inspect

### 11.3 Enhanced Maintainability

- **Thin orchestrators:** Phase orchestrators are simple wrappers
- **Reusable interfaces:** Module runners provide clean module interfaces
- **Consistent patterns:** All phases follow same structure
- **Clear dependencies:** Phase N depends on Phase N-1 result

### 11.4 Shiny Integration Ready

- **Pure functions:** Phase orchestrators have no global side effects
- **Structured returns:** Easy to extract data for UI updates
- **Checkpoint visibility:** Can show checkpoint paths in UI
- **Human-in-the-loop support:** Can interrupt pipeline for user input

---

## CONCLUSION

The transition from module-based to checkpointed phase orchestration represents a significant architectural improvement. The implementation is complete; documentation updates are the remaining priority to ensure consistency across all standards and guides.

Key achievements:
- ✅ 3 phase orchestrators created
- ✅ Module execution layer established
- ✅ Tester.R updated for phase chaining
- ✅ load_all.R updated with new architecture

Remaining work:
- ⏳ Update 5 key standards documents
- ⏳ Add deprecation notices to old orchestrators
- ⏳ Clean up backup files

The new architecture provides better separation of concerns, clearer checkpoints, and explicit human-in-the-loop support—critical for production pipeline workflows.

---

**END OF AUDIT REPORT**
