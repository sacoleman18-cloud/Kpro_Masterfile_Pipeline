# Contributing to KPro Masterfile Pipeline

Thank you for your interest in contributing to the KPro Masterfile Pipeline! This document provides guidelines for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [Project Structure](#project-structure)
5. [Coding Standards](#coding-standards)
6. [Testing](#testing)
7. [Submitting Changes](#submitting-changes)
8. [Documentation](#documentation)
9. [Questions and Support](#questions-and-support)

---

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

---

## Getting Started

### Prerequisites

- **R 4.0+** installed on your system
- **RStudio** (recommended for development)
- **Git** for version control
- Familiarity with bat acoustic monitoring and Kaleidoscope Pro software (helpful but not required)

### Areas for Contribution

We welcome contributions in the following areas:

- **Bug fixes**: Identify and fix issues in existing code
- **New features**: Implement items from the project roadmap
- **Documentation**: Improve clarity, add examples, fix typos
- **Testing**: Expand test coverage, add edge case tests
- **Performance**: Optimize slow operations, reduce memory usage
- **Visualization**: Enhance plot clarity, add new plot types
- **Configuration**: Expand YAML parameter options

---

## Development Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR-USERNAME/Kpro_Masterfile_Pipeline.git
cd Kpro_Masterfile_Pipeline
```

### 2. Install Dependencies

```r
# Install required packages
install.packages(c(
  "tidyverse", "lubridate", "janitor", "hms", "yaml",
  "here", "digest", "gt", "scales", "quarto", "zip"
))

# Install development dependencies
install.packages(c("testthat", "devtools", "lintr", "styler"))
```

### 3. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b bugfix/issue-number-description
```

---

## Project Structure

```
R/
├── workflows/           # Main pipeline scripts (01-07)
└── functions/
    ├── core/            # Configuration, utilities, artifacts
    ├── ingestion/       # Data loading, schema detection
    ├── standardization/ # Column mapping, datetime conversion
    ├── validation/      # Input validation
    ├── analysis/        # CPN, detector mapping, summaries
    └── output/          # Plots, tables, reports, releases

inst/config/             # YAML configuration files
data/                    # Input data (not version controlled)
outputs/                 # Checkpoints (not version controlled)
results/                 # Final outputs (not version controlled)
tests/testthat/          # Test files
docs/                    # Standards and design documentation
```

**Key Principle:** Functions in `R/functions/` should be modular, reusable, and testable. Workflows in `R/workflows/` orchestrate these functions.

---

## Coding Standards

This project follows comprehensive coding standards documented in `docs/03_code_design_standards.md`. Key highlights:

### Function Design

```r
#' Brief one-line description
#'
#' Detailed description with context and examples.
#'
#' @param param_name Description of parameter (type, constraints)
#' @return Description of return value (type, structure)
#' @export
#' @examples
#' \dontrun{
#'   result <- function_name(param_name = "value")
#' }
function_name <- function(param_name) {
  # Input validation
  stopifnot(is.character(param_name))
  
  # Main logic
  result <- perform_operation(param_name)
  
  # Return
  return(result)
}
```

### Code Style

- Use `snake_case` for function and variable names
- Use `<-` for assignment (not `=`)
- Maximum line length: 80 characters (prefer 100 for readability)
- Use meaningful variable names (no single-letter names except in loops)
- Add comments for complex logic, not obvious operations
- Use tidyverse style: [tidyverse.org/style](https://style.tidyverse.org/)

### Error Handling

```r
# Always validate inputs
if (!file.exists(path)) {
  stop("File not found: ", path)
}

# Use tryCatch for risky operations
result <- tryCatch(
  read.csv(file_path),
  error = function(e) {
    warning("Failed to read ", file_path, ": ", e$message)
    return(NULL)
  }
)
```

### Console Output

- Use `cat()` for user-facing messages
- Use `message()` for informational logs
- Use `warning()` for non-fatal issues
- Use `stop()` for fatal errors
- Include timestamps for long operations
- See `docs/05_logging_console_standards.md` for details

---

## Testing

All code changes should include tests. We use the `testthat` framework.

### Running Tests

```r
# Run all tests
testthat::test_dir("tests/testthat")

# Run specific test file
testthat::test_file("tests/testthat/test_ingest.R")
```

### Writing Tests

Create test files in `tests/testthat/` with the naming convention `test_*.R`:

```r
# tests/testthat/test_my_function.R
test_that("my_function handles valid input correctly", {
  result <- my_function("valid_input")
  expect_type(result, "character")
  expect_length(result, 1)
})

test_that("my_function rejects invalid input", {
  expect_error(my_function(NULL))
  expect_error(my_function(123))
})
```

### Test Coverage Goals

- All exported functions should have tests
- Aim for 80%+ code coverage
- Include edge cases and error conditions
- Test critical data transformations thoroughly

---

## Submitting Changes

### 1. Commit Guidelines

- **Atomic commits**: One logical change per commit
- **Descriptive messages**: Explain *what* and *why*, not *how*

```bash
# Good commit messages
git commit -m "Add validation for missing detector names in config"
git commit -m "Fix timezone conversion bug for daylight saving time transitions"
git commit -m "Update documentation for CPN template generation"

# Poor commit messages (avoid these)
git commit -m "fix bug"
git commit -m "update"
git commit -m "changes"
```

### 2. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub with:

- **Clear title**: Summarize the change in one line
- **Description**: Explain the problem and solution
- **Testing**: Describe how you tested the change
- **Related issues**: Reference any related issue numbers (#123)

### 3. Pull Request Checklist

Before submitting, ensure:

- [ ] Code follows project style guidelines
- [ ] All tests pass (`testthat::test_dir("tests/testthat")`)
- [ ] New tests added for new functionality
- [ ] Documentation updated (roxygen2 comments, README, etc.)
- [ ] CHANGELOG.md updated with your changes
- [ ] No merge conflicts with main branch
- [ ] Commit messages are clear and descriptive

---

## Documentation

### Code Documentation (Roxygen2)

All exported functions must have roxygen2 documentation:

```r
#' @title Function Title
#' @description Detailed description
#' @param param1 Description of param1
#' @param param2 Description of param2
#' @return Description of return value
#' @export
#' @examples
#' \dontrun{
#'   result <- my_function(param1 = "value")
#' }
```

### Standards Documentation

When adding significant features, update relevant standards docs:

- `docs/01_architecture_standards.md` - File structure, paths
- `docs/03_code_design_standards.md` - Design patterns
- `docs/04_data_standards.md` - Data contracts, validation

### User Documentation

Update user-facing docs when needed:

- `README.md` - High-level architecture and overview
- `INSTALL.md` - Installation and setup instructions
- `inst/config/YAML_PARAMETER_GUIDE.md` - Configuration options

---

## Questions and Support

### Getting Help

- **Issues**: Check [existing issues](https://github.com/sacoleman18-cloud/Kpro_Masterfile_Pipeline/issues) first
- **Discussions**: Use GitHub Discussions for questions and ideas
- **Documentation**: Review `docs/` folder for detailed standards

### Reporting Bugs

When reporting bugs, include:

1. **Description**: What went wrong?
2. **Steps to reproduce**: Minimal example to trigger the bug
3. **Expected behavior**: What should have happened?
4. **Actual behavior**: What actually happened?
5. **Environment**: R version, OS, package versions
6. **Data**: Sample data or file structure (if applicable)

### Feature Requests

When requesting features:

1. **Use case**: Why is this feature needed?
2. **Proposed solution**: How should it work?
3. **Alternatives considered**: Other approaches you evaluated
4. **Impact**: Who would benefit from this feature?

---

## License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to the KPro Masterfile Pipeline! Your efforts help advance bat acoustic monitoring research. 🦇
