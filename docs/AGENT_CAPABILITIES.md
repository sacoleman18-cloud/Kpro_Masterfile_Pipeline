# GitHub Copilot Coding Agent: Capabilities for KPro Masterfile Pipeline

**Version:** 1.0  
**Created:** January 2026  
**Repository:** Kpro_Masterfile_Pipeline  

---

## Overview

This document explains what the **GitHub Copilot Coding Agent** can do to help you develop, maintain, and improve the KPro Masterfile Pipeline. The agent is an advanced AI-powered assistant with deep coding expertise that can autonomously make changes to your repository.

---

## 1. Core Capabilities

### 1.1 Code Analysis & Understanding
The agent can:
- **Explore your codebase** to understand the R scripts, functions, and workflow structure
- **Analyze dependencies** between workflows (01-07) and function libraries
- **Map data flow** through the pipeline from raw KPro CSVs to final reports
- **Identify coding patterns** and architectural decisions in your bat acoustic monitoring pipeline
- **Review R package dependencies** and their usage across files

### 1.2 Code Modifications
The agent can make:
- **Bug fixes** in R scripts with minimal, surgical changes
- **Feature additions** that follow your existing code style and patterns
- **Refactoring** to improve code maintainability while preserving functionality
- **Performance optimizations** in data processing workflows
- **Schema updates** to handle new KPro version formats

### 1.3 Testing & Validation
The agent can:
- **Run existing tests** in the `tests/` directory
- **Create new test cases** that validate specific functionality
- **Execute workflows** to verify changes don't break the pipeline
- **Validate outputs** by comparing checkpoint files and results
- **Run linters and formatters** appropriate for R code

### 1.4 Documentation
The agent can:
- **Update documentation** to reflect code changes
- **Create technical guides** for new features or workflows
- **Generate inline comments** explaining complex logic
- **Write function documentation** in roxygen2 format
- **Update README** files with new instructions or examples

---

## 2. Specific Use Cases for KPro Pipeline

### 2.1 Data Processing Enhancements

#### Add Support for New KPro Schema Version
**What you can ask:**
> "KPro version 4 has changed the column names for frequency data. Add support for detecting and standardizing v4 schema in the ingestion workflow."

**What the agent will do:**
- Analyze `R/functions/ingestion/schema_detection.R`
- Add v4 schema detection logic
- Update `R/functions/standardization/standardization.R` to handle v4 columns
- Create test cases for v4 data
- Update documentation to note v4 support

#### Improve Duplicate Detection
**What you can ask:**
> "Enhance the deduplication logic in Workflow 02 to handle cases where detector timestamps are off by 1-2 seconds."

**What the agent will do:**
- Locate deduplication code in `R/02_standardize.R`
- Implement fuzzy timestamp matching with configurable tolerance
- Add logging for near-duplicate detection
- Test with sample data to verify behavior
- Document the new fuzzy matching parameter

### 2.2 Visualization & Reporting

#### Add New Plot Type
**What you can ask:**
> "Create a new plot showing species activity by moon phase. Add it to the temporal plots category in Workflow 06."

**What the agent will do:**
- Create new function in `R/functions/output/plot_temporal.R`
- Integrate with existing plot generation workflow
- Add moon phase calculation logic using suncalc or lunar package
- Store plot in `plot_objects_YYYYMMDD.rds`
- Update Quarto report template to display the new plot

#### Enhance Report Layout
**What you can ask:**
> "Improve the species composition section of the Quarto report with better table formatting and add a species richness metric."

**What the agent will do:**
- Modify `reports/bat_activity_report.qmd`
- Update `R/functions/output/tables.R` for better gt table styling
- Add species richness calculation to `R/05_summary_stats.R`
- Ensure changes maintain read-only contract in Workflow 07
- Preview the updated report HTML

### 2.3 Configuration & Usability

#### Add New Configuration Options
**What you can ask:**
> "Add a configuration option to exclude specific species from analysis (e.g., for filtering out NoID calls)."

**What the agent will do:**
- Update `inst/config/study_parameters.yaml` schema
- Modify config loading in `R/functions/core/config.R`
- Apply species filtering in appropriate workflows
- Add validation for species exclusion list
- Document the new parameter with examples

#### Improve Error Messages
**What you can ask:**
> "Make error messages more user-friendly when detector mapping is incomplete in the YAML config."

**What the agent will do:**
- Locate detector mapping validation code
- Rewrite error messages with actionable guidance
- Add suggestions for common mapping mistakes
- Include example correct mappings in error output
- Test with intentionally malformed configs

### 2.4 Performance & Efficiency

#### Optimize Large Dataset Processing
**What you can ask:**
> "Workflow 01 is slow when processing 50+ CSV files. Optimize the ingestion loop."

**What the agent will do:**
- Profile `R/01_ingest_raw_data.R` to identify bottlenecks
- Implement data.table or parallel processing if appropriate
- Benchmark improvements against original code
- Ensure optimizations preserve exact output format
- Document performance gains

#### Add Progress Indicators
**What you can ask:**
> "Add progress bars to long-running workflows so users know processing status."

**What the agent will do:**
- Integrate progress package (e.g., progressr, cli)
- Add progress tracking to file ingestion loops
- Update Workflow 02-06 with progress indicators
- Ensure compatibility with both interactive and batch execution
- Test progress output doesn't break logging

### 2.5 Validation & Quality Assurance

#### Strengthen Data Validation
**What you can ask:**
> "Add validation checks to ensure all detector-night combinations have non-negative recording hours in the CPN template."

**What the agent will do:**
- Update `R/functions/validation/validation.R`
- Add constraint checks for recording hours
- Generate warnings for negative or implausible values
- Update validation reports with new check results
- Add test cases for validation edge cases

#### Create Data Integrity Tests
**What you can ask:**
> "Create automated tests that verify masterfile schema consistency across all workflows."

**What the agent will do:**
- Create new test file in `tests/`
- Implement schema validation using testthat
- Check column names, types, and value ranges
- Run tests against checkpoint files
- Set up test to run on every workflow execution

### 2.6 Git & Repository Management

#### Clean Up Repository
**What you can ask:**
> "Remove the large .RData checkpoint files from git history and add them to .gitignore."

**What the agent will do:**
- Update `.gitignore` to exclude StartAt*.RData files
- Use git commands to remove files from tracking
- Commit the .gitignore changes
- Suggest using git-lfs if large files are needed in version control

#### Improve Commit Messages
**What you can ask:**
> "Review the recent commits and improve their messages to follow conventional commit standards."

**What the agent will do:**
- Analyze recent commit history
- Note: Agent cannot rewrite git history (no force push)
- Document recommended commit message format
- Provide a commit message template for future use

---

## 3. What the Agent CANNOT Do

### 3.1 Git & GitHub Limitations
- **Cannot force push** or rebase to rewrite git history
- **Cannot create new GitHub issues or PRs** (but can update the current PR)
- **Cannot resolve merge conflicts** that require pulling from remote
- **Cannot clone other repositories** or push to external repos
- **Cannot directly interact with GitHub Actions UI** (but can read workflow logs)

### 3.2 External System Limitations
- **Cannot modify raw audio files** or interact with Kaleidoscope Pro software
- **Cannot access external drives** directly (only through paths you configure)
- **Cannot send emails** or notifications outside GitHub
- **Cannot access private databases** or external APIs without proper configuration

### 3.3 Domain Limitations
- **Cannot replace ecological expertise** - you still need to validate species IDs
- **Cannot generate actual bat call recordings** or create synthetic acoustic data
- **Cannot perform statistical modeling** - that's for your downstream workflows
- **Cannot validate detector hardware** or troubleshoot recording equipment

---

## 4. How to Work Effectively with the Agent

### 4.1 Writing Good Requests

#### ✅ Good Request Examples

**Specific and actionable:**
> "Add a function to convert legacy 4-letter species codes to 6-letter codes in `R/functions/standardization/standardization.R`"

**Includes context:**
> "The CPN template generation in Workflow 03 is missing nights when detectors have recording gaps. Update the grid generation logic to fill all dates in the study period."

**Focuses on outcomes:**
> "Make the validation reports easier to read by improving the HTML layout and adding summary statistics at the top."

#### ❌ Vague Request Examples

**Too broad:**
> "Make the pipeline better"

**Lacks specifics:**
> "Fix the bugs"

**Outside agent scope:**
> "Deploy this pipeline to AWS Lambda"

### 4.2 Iterative Development

The agent works best with iterative refinement:

1. **Request a change** - Be specific about what you want
2. **Agent implements** - Makes minimal, focused changes
3. **Review results** - Check the commit and test the changes
4. **Refine if needed** - Ask for adjustments or additions
5. **Move to next task** - Build incrementally

### 4.3 Safety & Testing

The agent follows these safety practices:
- Makes **minimal changes** - only modifies what's necessary
- **Tests changes** before committing
- **Validates outputs** to ensure functionality is preserved
- **Documents changes** in commit messages and progress reports
- **Runs security scans** before finalizing

---

## 5. Common Workflows

### 5.1 Adding a New Feature

**You:** "I need to add a feature that calculates nightly species diversity (Shannon index) in the CPN dataset."

**Agent will:**
1. Analyze existing summary statistics code
2. Add Shannon diversity calculation to Workflow 05
3. Update summary tables to include diversity metric
4. Add diversity to the report template
5. Create test cases
6. Commit changes with descriptive message

### 5.2 Fixing a Bug

**You:** "There's a bug in datetime conversion - detector timestamps in CST are being incorrectly converted to UTC."

**Agent will:**
1. Locate timezone conversion code
2. Identify the incorrect logic
3. Fix the conversion while preserving other functionality
4. Test with sample data in multiple timezones
5. Verify checkpoints remain consistent
6. Commit the fix

### 5.3 Improving Documentation

**You:** "Update the README to include installation instructions for all required R packages."

**Agent will:**
1. Extract dependencies from R scripts
2. Create an installation section in README
3. Add step-by-step setup instructions
4. Include system requirements and version info
5. Test instructions on a clean environment if possible
6. Commit documentation update

### 5.4 Code Review & Refactoring

**You:** "The `R/functions/output/plot_detector.R` file is getting too long. Refactor it into smaller, more focused functions."

**Agent will:**
1. Analyze the current file structure
2. Identify logical function groupings
3. Split into multiple focused functions
4. Ensure all workflows still work correctly
5. Update function calls throughout codebase
6. Add documentation for refactored functions
7. Test entire plot generation workflow

---

## 6. Advanced Capabilities

### 6.1 Multi-file Refactoring
The agent can make coordinated changes across multiple files:
- Update function signatures and all their call sites
- Rename variables consistently across workflows
- Reorganize file structure while updating all imports

### 6.2 Dependency Management
The agent can:
- Check for security vulnerabilities in R packages
- Suggest package alternatives for better performance
- Update package versions in DESCRIPTION/renv.lock
- Add new package dependencies with proper installation

### 6.3 Custom Agents
The agent has access to specialized sub-agents:
- **explore**: Fast code exploration and question answering
- **task**: Command execution with summary reporting
- **general-purpose**: Complex multi-step tasks
- **code-review**: Focused code review with high signal-to-noise

### 6.4 Integration with GitHub
The agent can:
- Read GitHub Actions workflow logs to diagnose CI failures
- Download workflow artifacts for analysis
- List and analyze pull request reviews
- Search code across the repository efficiently

---

## 7. Getting Started

### Quick Start Examples

1. **Learn about the codebase:**
   > "Explain how the schema detection works in Workflow 01"

2. **Make a simple improvement:**
   > "Add better error handling when a CSV file is empty in the ingestion workflow"

3. **Create documentation:**
   > "Create a function reference guide for all the plotting functions"

4. **Optimize performance:**
   > "Profile Workflow 02 and suggest performance improvements"

5. **Add a feature:**
   > "Add support for generating summary statistics by week in addition to by night"

### Best Practices

- **Start small**: Begin with simple requests to learn how the agent works
- **Be specific**: Clearly describe what you want changed and why
- **Review changes**: Always review commits before merging
- **Test thoroughly**: Run your pipeline after changes to ensure everything works
- **Ask questions**: If you're unsure, ask the agent to explain before implementing

---

## 8. Example Dialogue

**You:** "Can you help me understand what's in the standardization workflow?"

**Agent:** "I'll analyze the standardization workflow for you..."
[Agent explores `R/02_standardize.R` and related functions]

**You:** "Great! Now can you add validation to ensure all detector names are mapped before standardization?"

**Agent:** "I'll add detector name validation with helpful error messages..."
[Agent modifies validation code and commits changes]

**You:** "Perfect! Can you also update the documentation to explain this new validation?"

**Agent:** "I'll update the relevant documentation sections..."
[Agent updates docs and commits]

---

## 9. Troubleshooting

### If the agent seems stuck:
- Provide more context about your goals
- Break your request into smaller steps
- Share specific file paths or function names
- Include example input/output data

### If changes don't work as expected:
- Ask the agent to review and explain what it changed
- Request specific tests to validate the changes
- Ask for a rollback and alternative approach
- Provide more details about the expected behavior

### If you're unsure about a capability:
- Just ask! "Can you [describe task]?"
- The agent will either complete it or explain limitations
- You can always refine your request based on the response

---

## 10. Summary

The GitHub Copilot Coding Agent is your autonomous development assistant for the KPro Masterfile Pipeline. It can:

✅ **Understand** your R-based bat acoustic monitoring pipeline  
✅ **Modify** code with surgical precision  
✅ **Test** changes to ensure correctness  
✅ **Document** improvements clearly  
✅ **Refactor** code for better maintainability  
✅ **Debug** issues across workflows  
✅ **Optimize** performance bottlenecks  
✅ **Add** new features following your patterns  

The agent excels at automating tedious tasks, implementing well-defined changes, and maintaining code quality while you focus on the ecological science and domain expertise.

---

## Need Help?

If you have questions about what the agent can do for your specific use case, just ask:

> "Can you help me with [your specific task]?"

The agent will either:
1. Complete the task autonomously
2. Ask clarifying questions
3. Explain if it's outside current capabilities

Start simple, experiment, and build confidence in the agent's capabilities!

---

**Document Version:** 1.0  
**Last Updated:** January 31, 2026  
**Maintained by:** KPro Pipeline Development Team
