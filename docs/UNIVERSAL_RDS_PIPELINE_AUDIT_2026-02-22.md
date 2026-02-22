# Universal RDS Pipeline Audit

**Date:** 2026-02-22  
**Author:** GitHub Copilot (GPT-4.1)

---

## Executive Summary

This audit reviews all major modules and function scripts in the KPro Masterfile Pipeline, focusing on:
- Where transformation metadata and validation_context are created/updated
- Where persistent artifacts are read/written
- Cross-module dependencies
- Gaps, inconsistencies, and legacy patterns to address for a universal RDS migration

---

## 1. Module-by-Module Audit

### 1.1 Ingestion (Module 1)
- **File:** R/modules/data_ingestion.R
- **Creates:** validation_context (init_stage_validation), logs invalid rows, schema detection
- **Returns:** validation_context in result (not saved to RDS)
- **Artifacts:** No RDS/CSV/HTML saved directly
- **Dependency:** Passes validation_context to Module 2 in-memory

### 1.2 Standardization (Module 2)
- **File:** R/modules/data_standardization.R
- **Updates:** validation_context (logs duplicates, NoID, zero-pulse, detector mapping, timezone conversion)
- **Artifacts:** Saves kpro_master checkpoint (CSV), validation HTML (from validation_context)
- **Gaps:** Does not save validation_context or transformation metadata to RDS (critical for downstream)
- **Dependency:** Module 6 needs NoID/duplicate/zero-pulse counts

### 1.3 CPN Template (Module 3)
- **File:** R/modules/cpn_template.R
- **Creates/Updates:** validation_context (species integration, NoID removal, date range, detector mapping)
- **Artifacts:** Template CSV, validation HTML
- **Gaps:** No RDS save of validation_context or template metadata
- **Dependency:** Downstream modules may need template lineage

### 1.4 Finalize CPN (Module 4)
- **File:** R/modules/finalize_cpn.R
- **Creates/Updates:** validation_context (user edits, detector/night filtering)
- **Artifacts:** Finalized CPN CSV, validation HTML
- **Gaps:** No RDS save of validation_context or edit lineage

### 1.5 Summary Stats (Module 5)
- **File:** R/modules/summary_stats.R
- **Creates:** summary_data, validation_context (statistical summaries, aggregations)
- **Artifacts:** summary_data.rds (currently saved), validation HTML
- **Gaps:** summary_data.rds to be replaced by universal RDS

### 1.6 Plotting (Module 6)
- **File:** R/modules/plotting.R
- **Creates:** plot_objects, validation_context (plot generation, quality metrics)
- **Artifacts:** plot_objects.rds (currently saved), validation HTML
- **Gaps:** plot_objects.rds to be replaced by universal RDS; needs access to Module 2's transformation metadata

### 1.7 Report/Release (Module 7)
- **File:** R/modules/report_release.R
- **Creates:** validation_context, report metadata, release bundle
- **Artifacts:** HTML report, release bundle
- **Gaps:** No RDS save of validation_context or report lineage

---

## 2. Function Script Audit

### 2.1 validation_reporting.R
- **Creates/updates:** validation_context, logs events, generates validation HTML
- **Gaps:** No persistent RDS save of validation_context in early modules

### 2.2 artifacts.R
- **Handles:** save_and_register_rds, artifact registration, hashing
- **Gaps:** Only used for summary_data.rds and plot_objects.rds; needs to be used for universal RDS

### 2.3 orchestration_helpers.R
- **Handles:** Checkpointing, logging, phase orchestration
- **Gaps:** Checkpoint logic may need to be updated for universal RDS

### 2.4 Other helpers (summarization, plotting, reporting)
- **Gaps:** All outputs must be routed to universal RDS

---

## 3. Cross-Module Data Dependencies
- Module 6 (Plotting) needs transformation counts from Module 2 (Standardization)
- Module 7 (Report/Release) may need summary stats, plot objects, and all validation_contexts
- All such dependencies must be satisfied by reading from the universal RDS

---

## 4. Gaps & Legacy Patterns
- Per-module RDS artifacts (summary_data.rds, plot_objects.rds) must be deprecated
- All validation_contexts and metadata must be written to and read from the universal RDS
- Documentation and reporting must reference the new RDS structure

---

## 5. Recommendations
- Implement universal RDS structure as described in the architecture plan
- Refactor all modules and function scripts to read/write their section of the universal RDS
- Remove legacy per-module RDS logic
- Update documentation, validation HTMLs, and reporting to use the new structure

---

**End of Audit**
