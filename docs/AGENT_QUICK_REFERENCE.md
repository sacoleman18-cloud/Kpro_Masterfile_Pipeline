# Agent Quick Reference Guide

**TL;DR:** Ask the agent to make changes to your KPro Pipeline, and it will implement them autonomously!

---

## 🚀 Quick Examples

### Code Changes
```
"Add validation to check for negative recording hours in Workflow 03"
"Fix the timezone conversion bug in datetime standardization"
"Optimize the CSV reading loop in Workflow 01 for better performance"
```

### New Features
```
"Add a plot showing activity by lunar phase to the temporal plots"
"Create a function to calculate species diversity per night"
"Add support for KPro version 4 schema"
```

### Documentation
```
"Update README with R package installation instructions"
"Add inline comments explaining the deduplication logic"
"Create a user guide for editing the CPN template"
```

### Testing & Debugging
```
"Run the pipeline and check for errors"
"Create unit tests for the schema detection functions"
"Debug why Workflow 05 is failing on large datasets"
```

### Code Quality
```
"Refactor plot_detector.R into smaller functions"
"Add error handling to all file reading operations"
"Make validation error messages more user-friendly"
```

---

## ✅ What Agent CAN Do

- ✅ Modify R scripts, functions, and workflows
- ✅ Add/update documentation
- ✅ Create and run tests
- ✅ Debug code issues
- ✅ Optimize performance
- ✅ Add new features
- ✅ Refactor code
- ✅ Analyze codebase
- ✅ Update configurations
- ✅ Generate reports

---

## ❌ What Agent CANNOT Do

- ❌ Modify raw audio files
- ❌ Run Kaleidoscope Pro
- ❌ Rewrite git history (force push)
- ❌ Access external drives directly
- ❌ Create new GitHub PRs
- ❌ Perform statistical modeling
- ❌ Validate species IDs

---

## 💡 Tips for Best Results

1. **Be specific**: "Fix timezone bug in line 45 of standardization.R" > "Fix bugs"
2. **Start small**: Test with simple changes before complex refactoring
3. **Review commits**: Always check what changed before merging
4. **Ask questions**: "Can you..." or "How do I..." - agent will guide you
5. **Iterate**: Request → Review → Refine → Repeat

---

## 📚 Common Tasks

| Task | Example Request |
|------|----------------|
| **Fix Bug** | "The detector mapping is failing when detector IDs have spaces - fix it" |
| **Add Plot** | "Create a barplot of calls per species in plot_species.R" |
| **Update Config** | "Add a max_file_size parameter to study_parameters.yaml" |
| **Improve Docs** | "Add examples to the function documentation in utilities.R" |
| **Optimize Code** | "Speed up the masterfile loading in Workflow 02" |
| **Add Tests** | "Create tests for the datetime conversion functions" |

---

## 🔍 Need More Detail?

See the full [AGENT_CAPABILITIES.md](AGENT_CAPABILITIES.md) for comprehensive documentation.

---

## 🎯 Try It Now!

Just describe what you want:

> "I need to add a function that filters out NoID calls from the species summary statistics"

The agent will:
1. Understand your request ✓
2. Make the changes ✓
3. Test them ✓
4. Commit with a clear message ✓
5. Report progress ✓

**That's it!** You focus on the science, the agent handles the code.
