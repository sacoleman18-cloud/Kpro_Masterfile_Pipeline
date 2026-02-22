# Universal RDS Architecture Audit Plan

**Date:** 2026-02-22
**Author:** GitHub Copilot (GPT-4.1)

---

## Executive Summary

This audit plan provides a comprehensive review of the KPro Masterfile Pipeline's data transformation, artifact, and metadata tracking systems, with the goal of migrating to a single, universal RDS file (pipeline_data_<timestamp>.rds) per pipeline run. The plan covers all pipeline phases, modules, and key function scripts, and identifies all points where data, metadata, or validation information must be tracked, updated, or refactored.

---

## 1. Scope of Audit

- **Pipeline Phases:** All (Ingestion, Standardization, CPN Template, Finalize CPN, Summary Stats, Plotting, Report/Release)
- **Modules:** All R/modules/*.R scripts corresponding to each phase
- **Function Scripts:** All R/functions/* scripts involved in data transformation, validation, artifact registration, and reporting
- **Artifacts:** All outputs currently saved as RDS, CSV, HTML, or other persistent formats

---

## 2. Audit Objectives

1. **Identify all transformation metadata and validation_context creation points**
2. **Catalog all current RDS/CSV/HTML artifact outputs and their structure**
3. **Map all cross-module data dependencies**
4. **Document all code that reads/writes persistent artifacts**
5. **Assess all reporting, plotting, and summary generation logic for RDS usage**
6. **Prepare for migration to a single universal RDS structure**

---

## 3. Module-by-Module Audit Checklist

### 3.1 Ingestion (Module 1)
- Track: validation_context, raw data inventory, schema detection, invalid row removal
- Audit: Where is validation_context created, updated, and returned?
- Artifact: Is any RDS/CSV/HTML saved? (Should be included in universal RDS)

### 3.2 Standardization (Module 2)
- Track: validation_context, duplicate/NoID/zero-pulse removal, detector mapping, timezone conversion
- Audit: Where is validation_context updated? Where is metadata stored?
- Artifact: Any RDS/CSV/HTML outputs? (All must be included in universal RDS)

### 3.3 CPN Template (Module 3)
- Track: validation_context, species integration, template metadata
- Audit: All transformation events and metadata
- Artifact: Any outputs to be included in universal RDS

### 3.4 Finalize CPN (Module 4)
- Track: validation_context, user edits, detector/night filtering
- Audit: All transformation and user action metadata
- Artifact: Any outputs to be included in universal RDS

### 3.5 Summary Stats (Module 5)
- Track: validation_context, summary_data
- Audit: Where is summary_data created? Where is validation_context updated?
- Artifact: summary_data.rds (to be replaced by universal RDS)

### 3.6 Plotting (Module 6)
- Track: validation_context, plot_objects, plot metadata
- Audit: Where are plot objects created and saved? Where is validation_context updated?
- Artifact: plot_objects.rds (to be replaced by universal RDS)

### 3.7 Report/Release (Module 7)
- Track: validation_context, report metadata, release bundle
- Audit: All reporting and release outputs
- Artifact: All must be included in universal RDS

---

## 4. Function Script Audit Checklist

- **validation_reporting.R:** All validation_context creation, event logging, HTML/report generation
- **artifacts.R:** All save_and_register_rds, artifact registration, and hash logic
- **orchestration_helpers.R:** All checkpointing, logging, and phase orchestration logic
- **Any custom summary/plot/report helpers:** Ensure all outputs are routed to universal RDS

---

## 5. Cross-Module Data Dependency Audit

- Identify all places where downstream modules require upstream transformation metadata (e.g., Module 6 needs NoID counts from Module 2)
- Ensure all such dependencies are satisfied by reading from the universal RDS

---

## 6. Reporting & Documentation Audit

- All validation HTMLs, summary reports, and user-facing outputs must reference the new universal RDS structure for provenance and reproducibility
- Update documentation to describe the new RDS structure and access patterns

---

## 7. Migration & Refactor Preparation

- List all code locations to update for universal RDS read/write
- Plan for deprecating old per-module RDS artifacts
- Prepare a migration/testing checklist to validate correctness after refactor

---

## 8. Deliverables

- This audit plan (/docs/UNIVERSAL_RDS_AUDIT_PLAN_2026-02-22.md)
- Refactor plan (to be created next)
- Updated documentation and codebase

---

**End of Audit Plan**
