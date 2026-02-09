# ==============================================================================
# ORCHESTRATION PHILOSOPHY: CHECKPOINTED PHASE ORCHESTRATION
# ==============================================================================
# VERSION: 1.0
# LAST UPDATED: 2026-02-08
# PURPOSE: Authoritative reference for phase orchestration architecture and philosophy
# ==============================================================================

## EXECUTIVE SUMMARY

The KPro Masterfile Pipeline has transitioned from **chunk-based orchestration** to **checkpointed phase orchestration**. This document serves as the authoritative reference for understanding and implementing this architecture.

**Key Concepts:**
- **Phases:** 3 sequential pipeline stages with explicit checkpoints (not chunks)
- **Checkpoints:** Validated data artifacts produced at end of each phase
- **Human-in-the-Loop:** Phase 2 requires manual template editing before Phase 3
- **Module Execution Layer:** Provides callable interfaces for all 7 processing modules
- **Phase Orchestrators:** Thin wrappers composing the module execution layer
- **Structured Passing:** Phase results chain between orchestrators with full metadata

---

## 1. CORE CONCEPTS

### 1.1 Phases vs. Chunks

| Aspect | Phases (NEW) | Chunks (DEPRECATED) |
|--------|------|-----------|
| Terminology | Phase 1/2/3 | Chunk 1/2/3 |
| Orchestrator | `run_phase#_name()` | `run_ingest_standardize()` |
| Data Passing | Structured phase results | No structured passing |
| Checkpoints | Explicit at each phase end | Implicit |
| Validation | HTML reports per phase | Single reports |
| Human Loop | Explicit in Phase 2 | Implicit template editing |

### 1.2 The Three Phases

**Phase 1: Data Preparation (Modules 1-2)**
- Ingests raw CSVs
- Transforms schemas (v1/v2/v3 → unified)
- Produces: kpro_master.csv (checkpoint)
- Function: `run_phase1_data_preparation()`

**Phase 2: Template Generation (Module 3)**
- Generates CallsPerNight template with recording schedules
- Produces: CPN_Template_ORIGINAL & CPN_Template_EDIT_THIS.csv
- **Requires human editing before proceeding**
- Function: `run_phase2_template_generation(phase1_result)`

**Phase 3: Analysis & Reporting (Modules 4-7)**
- Finalizes CPN using edited template
- Generates statistics, plots, report, release bundle
- Produces: Final outputs in results/
- Function: `run_phase3_analysis_reporting(phase2_result)`

### 1.3 Core Principle: Explicit Checkpoints

Each phase produces an explicit checkpoint:

```
Phase 1 → [kpro_master.csv] → Phase 2 → [CPN_Template_EDIT_THIS.csv]
                                              ↓
                                         🛑 USER EDITS 🛑
                                              ↓
                                    Phase 3 → [Final Outputs]
```

Checkpoints enable:
- **Validation:** Review intermediate data with validation HTML
- **Recovery:** Restart from checkpoint if errors occur
- **Iteration:** Run Phase 3 multiple times with same Phase 1/2 outputs
- **Audit Trail:** Clear provenance of each artifact

### 1.4 Core Principle: Structured Passing

Phase results are structured objects:

```r
# Phase 1 result
phase1_result <- list(
  phase = 1,
  kpro_master = tibble,
  metadata = list(n_rows = 2000, ...),
  checkpoint_path = "outputs/checkpoints/02_kpro_master_*.csv",
  validation_html_paths = c("path1", "path2")
)

# Pass to Phase 2
phase2_result <- run_phase2_template_generation(phase1_result)

# Pass to Phase 3
phase3_result <- run_phase3_analysis_reporting(phase2_result)
```

Benefits:
- **Type Safety:** Structured results prevent errors
- **Metadata:** All processing context travels with data
- **Traceability:** Each phase knows where data came from
- **Testability:** Easy to verify intermediate results

---

## 2. MODULE EXECUTION LAYER

### 2.1 Module vs. Phase Orchestrator

**Processing Modules** (R/modules/*.R): Self-contained functional units
- 7 modules total (data_ingestion.R, data_standardization.R, etc.)
- Each contains internal "module stages" (numbered 1+)
- Called via run_module_*() functions from module_runner.R
- Have file I/O and save artifacts

**Module Execution Layer** (R/modules/module_runner.R): Callable interfaces
- 7 run_module_*() functions (one per module)
- 1 run_all_modules() utility function
- Pure functions suitable for composition
- Used by phase orchestrators OR for individual testing

**Phase Orchestrators** (R/pipeline/run_phase*.R): High-level coordination
- 3 phase orchestrators (one per phase)
- Compose module execution layer (call run_module_*())
- Handle error handling, logging, checkpointing
- Implement human-in-the-loop (Phase 2)
- Return structured phase results

### 2.2 Module Execution Layer Functions

Located in: `R/modules/module_runner.R`

**The 7 Module Runners:**

1. `run_module_ingestion(verbose = FALSE)`
   - Loads raw CSV files
   - Produces intro_standardized
   - Called by: Phase 1

2. `run_module_standardization(ingestion_result, verbose = FALSE)`
   - Transforms schemas, applies filters
   - Produces: kpro_master
   - Called by: Phase 1

3. `run_module_cpn_template(standardization_result, manual_id_file = NULL, verbose = FALSE)`
   - Generates CPN template
   - Produces: cpn_template pair
   - Called by: Phase 2

4. `run_module_finalize_cpn(cpn_template_result, edited_template_file = NULL, verbose = FALSE)`
   - Loads edited template, finalizes CPN
   - Produces: calls_per_night_final
   - Called by: Phase 3

5. `run_module_summary_stats(finalize_result, verbose = FALSE)`
   - Generates summary statistics
   - Produces: all_summaries
   - Called by: Phase 3

6. `run_module_plotting(summary_stats_result, verbose = FALSE)`
   - Generates plots
   - Produces: all_plots
   - Called by: Phase 3

7. `run_module_report_release(plotting_result, summary_stats_result, verbose = FALSE)`
   - Renders report, creates release bundle
   - Produces: final outputs
   - Called by: Phase 3

**Utility Function:**

8. `run_all_modules(verbose = FALSE)`
   - Executes all 7 modules sequentially with pause prompts
   - For testing or custom sequences
   - Not normally used in production

### 2.3 Using the Module Execution Layer

**Pattern 1: Called by Phase Orchestrators (Primary)**
```r
# Inside run_phase1_data_preparation.R
source(file.path("R", "modules", "module_runner.R"))

module1_result <- run_module_ingestion(verbose = verbose)
module2_result <- run_module_standardization(module1_result, verbose = verbose)
```

**Pattern 2: Individual Module Testing**
```r
source('R/functions/load_all.R')
source('R/modules/module_runner.R')

# Test modules one at a time
r1 <- run_module_ingestion(verbose = TRUE)
# [inspect r1]
r2 <- run_module_standardization(r1, verbose = TRUE)
# [inspect r2]
```

**Pattern 3: Custom Sequences**
```r
# Run modules in custom order or subset
r1 <- run_module_ingestion(verbose = TRUE)
r2 <- run_module_standardization(r1, verbose = TRUE)
# Skip templates, go straight to finalization if desired
```

---

## 3. LAYER ARCHITECTURE

### 3.1 Nine-Layer Architecture

```
LAYERS 1-6: Utility Functions (R/functions/)
  Layer 1: core/       - Config, utilities, logging, console, artifacts, release
  Layer 2: ingestion/  - Raw data loading
  Layer 3: standardization/ - Schema transformation
  Layer 4: validation/ - Data quality checks, validation reporting
  Layer 5: analysis/   - CPN, detector mapping, summarization
  Layer 6: output/     - Plotting, tables, report generation

LAYER 7: Phase Orchestrators (R/pipeline/)
  - run_phase1_data_preparation()
  - run_phase2_template_generation()
  - run_phase3_analysis_reporting()

LAYER 8: Processing Modules (R/modules/)
  - data_ingestion.R
  - data_standardization.R
  - cpn_template.R
  - finalize_cpn.R
  - summary_stats.R
  - plotting.R
  - report_release.R

LAYER 9: Module Execution Layer (R/modules/module_runner.R)
  - run_module_*() functions
  - Callable interfaces for all 7 modules
```

### 3.2 Data Flow

```
Utility Functions (1-6)
        ↑↑ (called by)
        ||
Phase Orchestrators (7) ← Entry points for execution
        ||
        ↓↓ (call)
Module Execution Layer (9) ← Callable interfaces
        ||
        ↓↓ (delegate to)
Processing Modules (8) ← Actual implementation
        ||
        ↓↓ (call)
Utility Functions (1-6) ← Building blocks
```

### 3.3 Dependency Rules

- Layer N may depend on layers 1 through N-1
- Layer N must NOT depend on layers N+1 or higher
- Forward only: data flows from Layer 7→9→8, never backward
- No circular dependencies allowed

---

## 4. PHASE ORCHESTRATION WORKFLOW

### 4.1 Complete Phase Chaining Pattern

**Recommended execution for production:**

```r
# Load all functions and orchestrators
source('R/functions/load_all.R')
source('R/pipeline/run_phase1_data_preparation.R')
source('R/pipeline/run_phase2_template_generation.R')
source('R/pipeline/run_phase3_analysis_reporting.R')

# PHASE 1: Data Preparation
cat("\n=== PHASE 1: Data Preparation ===\n")
phase1_result <- run_phase1_data_preparation(verbose = TRUE)

# Check Phase 1 results
cat(sprintf("Checkpoint: %s\n", phase1_result$checkpoint_path))
cat(sprintf("Rows: %s\n", format(nrow(phase1_result$kpro_master), big.mark = ",")))

# PHASE 2: Template Generation
cat("\n=== PHASE 2: Template Generation ===\n")
phase2_result <- run_phase2_template_generation(
  phase1_result = phase1_result,
  verbose = TRUE
)

# 🛑 CRITICAL: User must edit template
cat("\n⚠️  ACTION REQUIRED ⚠️\n")
cat("Edit template at: ", phase2_result$template_edit_path, "\n")
cat("Then run Phase 3...\n")
readline(prompt = "Press ENTER after editing template...")

# PHASE 3: Analysis & Reporting
cat("\n=== PHASE 3: Analysis & Reporting ===\n")
phase3_result <- run_phase3_analysis_reporting(
  phase2_result = phase2_result,
  edited_template_file = phase2_result$template_edit_path,
  verbose = TRUE
)

# Final results
cat("\n✅ PIPELINE COMPLETE ✅\n")
cat("Report: ", phase3_result$report_path, "\n")
cat("Bundle: ", phase3_result$release_bundle_path, "\n")
```

### 4.2 Module-Level Testing Pattern

**For individual module testing or debugging:**

```r
source('R/functions/load_all.R')
source('R/modules/module_runner.R')

# Test Module 1
r1 <- run_module_ingestion(verbose = TRUE)
str(r1)  # Inspect result

# Test Module 2 (given Module 1's output)
r2 <- run_module_standardization(r1, verbose = TRUE)
str(r2)  # Inspect result

# Test remaining modules
r3 <- run_module_cpn_template(r2, verbose = TRUE)
# ... etc ...
```

### 4.3 Shiny Integration Pattern

**Executing phases from Shiny event handlers:**

```r
# In shiny_app.R
observeEvent(input$run_phase1, {
  # Phase 1 is a pure function
  phase1_result <- run_phase1_data_preparation(verbose = FALSE)
  
  # Update UI based on results
  output$phase1_status <- renderUI({
    sprintf("Loaded %s rows", format(nrow(phase1_result$kpro_master)))
  })
  
  # Store result for next phase
  phase1 <<- phase1_result  # Store in reactive environment
})

observeEvent(input$run_phase2, {
  if (is.null(phase1)) return()
  
  phase2_result <- run_phase2_template_generation(
    phase1_result = phase1,
    verbose = FALSE
  )
  
  # Notify user to edit template
  showModal(modalDialog(
    sprintf("Edit: %s", phase2_result$template_edit_path),
    footer = actionButton("phase2_done", "Done Editing")
  ))
  
  phase2 <<- phase2_result
})

observeEvent(input$run_phase3, {
  if (is.null(phase2)) return()
  
  phase3_result <- run_phase3_analysis_reporting(
    phase2_result = phase2,
    edited_template_file = phase2$template_edit_path,
    verbose = FALSE
  )
  
  # Display final results
  output$final_report <- renderUI({
    a("View Report", href = phase3_result$report_path, target = "_blank")
  })
})
```

---

## 5. DESIGN PRINCIPLES

### 5.1 Pure Functions

Phase orchestrators are pure functions:
- No global side effects (no `<<-`, no global state modification)
- Same inputs always produce same outputs
- Dependencies injected as parameters
- Results returned in structured lists

### 5.2 Defensive Programming

- All inputs validated at entry
- Informative error messages
- Early returns for error conditions
- tryCatch with specific error handling

### 5.3 Explicit Logging

- All significant operations logged to files (not gated)
- Verbose mode for console output (gated)
- Validation HTML always generated (not gated)

### 5.4 Checkpoint Drive Design

- Every major computation produces a checkpoint
- Checkpoints are validated data CSVs or RDS objects
- Checkpoints registered in artifact registry with SHA256 hashes
- Validation HTML reports at checkpoint boundaries

### 5.5 Shiny-Ready

- No interactive prompts (all from YAML or parameters)
- No global state manipulation
- Structured return values for UI integration
- Silent by default, verbose on request

---

## 6. TERMINOLOGY STANDARDS

### 6.1 Correct Terms (Use These)

- **Phase**: Use to refer to phases 1-3
- **Phase orchestrator**: run_phase#_name() functions
- **Phase result**: Structured list returned by phases
- **Module**: Processing modules 1-7  
- **Module runner**: Functions in module_runner.R
- **Module execution layer**: R/modules/module_runner.R
- **Checkpoint**: Data artifacts between phases
- **Human-in-the-loop**: Manual template editing in Phase 2
- **Structured passing**: Phase results chaining
- **Artifact registry**: inst/config/artifact_registry.yaml

### 6.2 Deprecated Terms (Don't Use)

- ❌ "Chunk" → Use "Phase"
- ❌ "Chunk orchestrator" → Use "Phase orchestrator"
- ❌ "Debug tool" → Use "Module execution layer"
- ❌ "R/debug/module_runner.R" → Use "R/modules/module_runner.R"
- ❌ "Workflow script" → Use "Phase" or "Module"

---

## 7. MIGRATION FROM CHUNKS TO PHASES

### 7.1 Code Replacement Map

```r
# OLD PATTERN (Chunks)
result <- run_ingest_standardize(verbose = TRUE)

# NEW PATTERN (Phases)
result <- run_phase1_data_preparation(verbose = TRUE)
```

```r
# OLD PATTERN (No passing)
result2 <- run_cpn_template(
  kpro_master = result$kpro_master,
  verbose = TRUE
)

# NEW PATTERN (Structured passing)
result2 <- run_phase2_template_generation(
  phase1_result = result,
  verbose = TRUE
)
```

```r
# OLD PATTERN (Manual editing, no clear checkpoint)
result3 <- run_finalize_to_report(verbose = TRUE)

# NEW PATTERN (Explicit checkpoint and human loop)
# [Edit template at: result2$template_edit_path]
result3 <- run_phase3_analysis_reporting(
  phase2_result = result2,
  edited_template_file = result2$template_edit_path,
  verbose = TRUE
)
```

### 7.2 Documentation Updates

- All references to "Chunk 1" → "Phase 1"
- All examples using run_ingest_standardize() → run_phase1_data_preparation()
- All data passing examples → Use phase result objects
- All Shiny examples → Show process with structured results

---

## 8. BENEFITS OF PHASE ORCHESTRATION

### 8.1 Clarity

- Explicit phases with clear boundaries
- Named checkpoints for validation
- Transparent data flow between phases
- Human-in-the-loop clearly marked

### 8.2 Robustness

- Structured results prevent data loss errors
- Checkpoints enable recovery and restart
- Validation HTML at each phase
- Artifact registry tracks all versions

### 8.3 Testability

- Phase can be tested independently
- Modules can be tested individually
- Results can be inspected between phases
- Deterministic execution enables regression testing

### 8.4 Maintainability

- Clear separation of concerns
- Thin orchestrators are easy to understand
- Modules are self-contained
- Data contracts explicit through result structures

### 8.5 Shiny Integration

- Pure functions support reactive execution
- Structured results easy to integrate with UI
- Checkpoints can be displayed in UI
- Human-in-the-loop fits natural workflow

---

## CONCLUSION

Checkpointed phase orchestration represents a significant architectural improvement:

- **Before**: Implicit chunks, no structured passing, unclear checkpoints
- **After**: Explicit phases, structured results, clear checkpoints and human loops

This philosophy is implemented across all standards documents and should guide all development decisions.

---

**END OF DOCUMENT**
