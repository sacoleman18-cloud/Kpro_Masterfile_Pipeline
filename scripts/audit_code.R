# ==============================================================================
# COMPREHENSIVE CODE AUDIT: CODING_STANDARDS.md Enforcement
# ==============================================================================
# PURPOSE: Automated enforcement of ALL standards from CODING_STANDARDS.md
# USAGE: source("scripts/audit_code.R")
# OUTPUT: 
#   - Console: Summary with priority levels
#   - logs/audit_report.txt: Detailed findings
# ==============================================================================

library(here)

audit_code <- function() {
  
  cat("\n")
  cat(strrep("=", 80), "\n")
  cat("🔍 COMPREHENSIVE CODE AUDIT: CODING_STANDARDS.md\n")
  cat(strrep("=", 80), "\n\n")
  
  r_dir <- here::here("R")
  
  # Violation counters by severity
  critical_count <- 0
  important_count <- 0
  style_count <- 0
  info_count <- 0
  
  # Initialize report
  report_lines <- c(
    strrep("=", 80),
    "COMPREHENSIVE CODE AUDIT REPORT",
    sprintf("Generated: %s", Sys.time()),
    sprintf("Scanned directory: %s", r_dir),
    sprintf("Standards: CODING_STANDARDS.md"),
    strrep("=", 80),
    ""
  )
  
  # ============================================================================
  # SECTION 1: PATH MANAGEMENT (CRITICAL)
  # ============================================================================
  
  cat(strrep("=", 80), "\n")
  cat("SECTION 1: PATH MANAGEMENT (CRITICAL)\n")
  cat(strrep("=", 80), "\n\n")
  
  report_lines <- c(report_lines, strrep("=", 80))
  report_lines <- c(report_lines, "SECTION 1: PATH MANAGEMENT (CRITICAL)")
  report_lines <- c(report_lines, strrep("=", 80), "")
  
  # 1.1: No hardcoded Windows paths
  result <- check_pattern(
    pattern = "C:/",
    label = "Hardcoded Windows paths (C:/)",
    level = "CRITICAL",
    r_dir = r_dir,
    explanation = "Use here::here() or config parameters instead",
    exclude_files = c("audit_code.R", "audit_code_COMPREHENSIVE.R")
  )
  critical_count <- critical_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  result <- check_pattern(
    pattern = "C:\\\\\\\\",
    label = "Hardcoded Windows paths (C:\\\\)",
    level = "CRITICAL",
    r_dir = r_dir,
    explanation = "Use here::here() or config parameters instead",
    exclude_files = c("audit_code.R", "audit_code_COMPREHENSIVE.R")
  )
  critical_count <- critical_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 1.2: No drive letters in paths
  result <- check_pattern(
    pattern = '(^|\\s|["\'])[A-Z]:[/\\\\]',
    label = "Drive letters in paths (D:/, E:/, etc.)",
    level = "CRITICAL",
    r_dir = r_dir,
    explanation = "Use relative paths with here::here() or config YAML",
    exclude_comments = TRUE,
    exclude_files = c("audit_code.R", "audit_code_COMPREHENSIVE.R")
  )
  critical_count <- critical_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 1.3: No hardcoded user paths
  result <- check_pattern(
    pattern = "Users/",
    label = "Hardcoded user directory paths",
    level = "CRITICAL",
    r_dir = r_dir,
    explanation = "Use here::here() or ~ for user-relative paths",
    exclude_comments = TRUE,
    exclude_files = c("audit_code.R", "audit_code_COMPREHENSIVE.R")
  )
  critical_count <- critical_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 1.4: No setwd()
  result <- check_pattern(
    pattern = "setwd\\(",
    label = "setwd() calls",
    level = "CRITICAL",
    r_dir = r_dir,
    explanation = "Use here::here() for portable paths instead",
    exclude_files = c("audit_code.R", "audit_code_COMPREHENSIVE.R")
  )
  critical_count <- critical_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 1.5: Detector mapping should use YAML
  result <- check_hardcoded_detectors(r_dir = r_dir)
  critical_count <- critical_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # ============================================================================
  # SECTION 2: DOCUMENTATION STANDARDS (IMPORTANT)
  # ============================================================================
  
  cat("\n", strrep("=", 80), "\n")
  cat("SECTION 2: DOCUMENTATION STANDARDS (IMPORTANT)\n")
  cat(strrep("=", 80), "\n\n")
  
  report_lines <- c(report_lines, "", strrep("=", 80))
  report_lines <- c(report_lines, "SECTION 2: DOCUMENTATION STANDARDS (IMPORTANT)")
  report_lines <- c(report_lines, strrep("=", 80), "")
  
  # 2.1: Roxygen2 completeness (CONTRACT, DOES NOT)
  result <- check_roxygen_completeness(r_dir = r_dir)
  important_count <- important_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 2.2: File headers
  result <- check_file_headers(r_dir = r_dir)
  important_count <- important_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 2.3: @param documentation
  result <- check_param_docs(r_dir = r_dir)
  important_count <- important_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # ============================================================================
  # SECTION 3: CODE QUALITY (IMPORTANT)
  # ============================================================================
  
  cat("\n", strrep("=", 80), "\n")
  cat("SECTION 3: CODE QUALITY (IMPORTANT)\n")
  cat(strrep("=", 80), "\n\n")
  
  report_lines <- c(report_lines, "", strrep("=", 80))
  report_lines <- c(report_lines, "SECTION 3: CODE QUALITY (IMPORTANT)")
  report_lines <- c(report_lines, strrep("=", 80), "")
  
  # 3.1: No print(), use message()
  result <- check_pattern(
    pattern = "print\\(",
    label = "print() calls (use message() instead)",
    level = "IMPORTANT",
    r_dir = r_dir,
    explanation = "message() is better for user communication",
    exclude_comments = TRUE
  )
  important_count <- important_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 3.2: Informative error messages
  result <- check_pattern(
    pattern = 'stop\\("Error',
    label = 'Generic error messages (stop("Error...))',
    level = "IMPORTANT",
    r_dir = r_dir,
    explanation = "Provide specific, actionable error messages"
  )
  important_count <- important_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 3.3: Input validation
  result <- check_input_validation(r_dir = r_dir)
  important_count <- important_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 3.4: No global state modification
  result <- check_pattern(
    pattern = "<<-",
    label = "Global assignment (<<-)",
    level = "IMPORTANT",
    r_dir = r_dir,
    explanation = "Avoid global state; use function returns instead",
    exclude_comments = TRUE
  )
  important_count <- important_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # ============================================================================
  # SECTION 4: NAMING CONVENTIONS (STYLE)
  # ============================================================================
  
  cat("\n", strrep("=", 80), "\n")
  cat("SECTION 4: NAMING CONVENTIONS (STYLE)\n")
  cat(strrep("=", 80), "\n\n")
  
  report_lines <- c(report_lines, "", strrep("=", 80))
  report_lines <- c(report_lines, "SECTION 4: NAMING CONVENTIONS (STYLE)")
  report_lines <- c(report_lines, strrep("=", 80), "")
  
  # 4.1: snake_case for functions
  result <- check_function_naming(r_dir = r_dir)
  style_count <- style_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 4.2: Descriptive names (no x, tmp, df)
  result <- check_pattern(
    pattern = " <- function\\(.*\\bx\\b",
    label = "Non-descriptive parameter names (x, y, z)",
    level = "STYLE",
    r_dir = r_dir,
    explanation = "Use descriptive names like 'data', 'values', 'input'",
    exclude_comments = TRUE
  )
  style_count <- style_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # ============================================================================
  # SECTION 5: SECURITY & SAFETY (CRITICAL)
  # ============================================================================
  
  cat("\n", strrep("=", 80), "\n")
  cat("SECTION 5: SECURITY & SAFETY (CRITICAL)\n")
  cat(strrep("=", 80), "\n\n")
  
  report_lines <- c(report_lines, "", strrep("=", 80))
  report_lines <- c(report_lines, "SECTION 5: SECURITY & SAFETY (CRITICAL)")
  report_lines <- c(report_lines, strrep("=", 80), "")
  
  # 5.1: No credentials
  result <- check_pattern(
    pattern = "password\\s*=|api_key\\s*=|secret\\s*=",
    label = "Potential credentials in code",
    level = "CRITICAL",
    r_dir = r_dir,
    explanation = "Use environment variables or config files for credentials",
    exclude_comments = TRUE
  )
  critical_count <- critical_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 5.2: No PII in examples
  result <- check_pattern(
    pattern = "@examples.*\\b\\d{3}-\\d{2}-\\d{4}\\b",
    label = "Potential SSN in examples",
    level = "CRITICAL",
    r_dir = r_dir,
    explanation = "Use fake/sanitized data in examples"
  )
  critical_count <- critical_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # ============================================================================
  # SECTION 6: INTEGRATION REQUIREMENTS (IMPORTANT)
  # ============================================================================
  
  cat("\n", strrep("=", 80), "\n")
  cat("SECTION 6: INTEGRATION REQUIREMENTS (IMPORTANT)\n")
  cat(strrep("=", 80), "\n\n")
  
  report_lines <- c(report_lines, "", strrep("=", 80))
  report_lines <- c(report_lines, "SECTION 6: INTEGRATION REQUIREMENTS (IMPORTANT)")
  report_lines <- c(report_lines, strrep("=", 80), "")
  
  # 6.1: here::here() usage
  result <- check_pattern(
    pattern = 'file\\.path\\(getwd\\(\\)',
    label = "Using getwd() instead of here::here()",
    level = "IMPORTANT",
    r_dir = r_dir,
    explanation = "Use here::here() for project-relative paths"
  )
  important_count <- important_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # 6.2: Dependencies documented
  result <- check_dependencies_documented(r_dir = r_dir)
  important_count <- important_count + result$count
  report_lines <- c(report_lines, result$report_text)
  
  # ============================================================================
  # SECTION 7: INFORMATIONAL CHECKS
  # ============================================================================
  
  cat("\n", strrep("=", 80), "\n")
  cat("SECTION 7: INFORMATIONAL (Review Suggested)\n")
  cat(strrep("=", 80), "\n\n")
  
  report_lines <- c(report_lines, "", strrep("=", 80))
  report_lines <- c(report_lines, "SECTION 7: INFORMATIONAL (Review Suggested)")
  report_lines <- c(report_lines, strrep("=", 80), "")
  
  # 7.1: Hardcoded timezone (now in config)
  result <- check_pattern(
    pattern = "America/Chicago",
    label = "Hardcoded timezone (should be in config)",
    level = "INFO",
    r_dir = r_dir,
    explanation = "Move timezone to study_parameters.yaml",
    exclude_comments = TRUE,
    exclude_files = c("config.R", "datetime_conversion.R"),  # OK in these files
    count_toward_total = FALSE
  )
  report_lines <- c(report_lines, result$report_text)
  
  # 7.2: Long functions (>100 lines)
  result <- check_long_functions(r_dir = r_dir)
  report_lines <- c(report_lines, result$report_text)
  
  # 7.3: TODO/FIXME comments
  result <- check_pattern(
    pattern = "# TODO|# FIXME",
    label = "TODO/FIXME comments (track these)",
    level = "INFO",
    r_dir = r_dir,
    explanation = "Consider creating GitHub issues for these",
    count_toward_total = FALSE
  )
  report_lines <- c(report_lines, result$report_text)
  
  # ============================================================================
  # FINAL SUMMARY
  # ============================================================================
  
  cat("\n", strrep("=", 80), "\n")
  cat("AUDIT SUMMARY\n")
  cat(strrep("=", 80), "\n\n")
  
  report_lines <- c(report_lines, "", strrep("=", 80))
  report_lines <- c(report_lines, "AUDIT SUMMARY")
  report_lines <- c(report_lines, strrep("=", 80), "")
  
  total_violations <- critical_count + important_count + style_count
  
  # Build summary table
  summary_lines <- c(
    sprintf("  CRITICAL violations:  %3d  (Fix immediately)", critical_count),
    sprintf("  IMPORTANT violations: %3d  (Fix this week)", important_count),
    sprintf("  STYLE violations:     %3d  (Fix when convenient)", style_count),
    sprintf("  ───────────────────────────"),
    sprintf("  TOTAL violations:     %3d", total_violations),
    ""
  )
  
  cat(paste(summary_lines, collapse = "\n"), "\n")
  report_lines <- c(report_lines, summary_lines)
  
  # Status message
  if (critical_count > 0) {
    status_msg <- "❌ CRITICAL violations must be fixed before production use"
    cat(status_msg, "\n")
    report_lines <- c(report_lines, status_msg)
  } else if (important_count > 0) {
    status_msg <- "⚠️  No critical issues, but important improvements needed"
    cat(status_msg, "\n")
    report_lines <- c(report_lines, status_msg)
  } else if (style_count > 0) {
    status_msg <- "✅ No critical/important issues. Only style improvements suggested."
    cat(status_msg, "\n")
    report_lines <- c(report_lines, status_msg)
  } else {
    status_msg <- "✅ EXCELLENT! Code meets all CODING_STANDARDS.md requirements!"
    cat(status_msg, "\n")
    report_lines <- c(report_lines, status_msg)
  }
  
  cat("\n")
  
  # ============================================================================
  # SAVE REPORT
  # ============================================================================
  
  logs_dir <- here::here("logs")
  if (!dir.exists(logs_dir)) {
    dir.create(logs_dir, recursive = TRUE)
  }
  
  report_file <- file.path(logs_dir, "audit_report.txt")
  writeLines(report_lines, report_file)
  cat(sprintf("📄 Full report: %s\n\n", report_file))
  
  # Return violation counts for programmatic use
  invisible(list(
    critical = critical_count,
    important = important_count,
    style = style_count,
    total = total_violations
  ))
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Check Pattern with Enhanced Reporting
check_pattern <- function(pattern, label, level, r_dir,
                          explanation = "",
                          exclude_comments = FALSE,
                          exclude_files = NULL,
                          count_toward_total = TRUE) {
  
  cat(sprintf("[%s] %s\n", level, label))
  
  # Get all R files
  r_files <- list.files(r_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  
  # Exclude specified files
  if (!is.null(exclude_files)) {
    r_files <- r_files[!basename(r_files) %in% exclude_files]
  }
  
  matches <- list()
  
  # Search each file
  for (file in r_files) {
    lines <- tryCatch(readLines(file, warn = FALSE), error = function(e) character(0))
    
    for (i in seq_along(lines)) {
      line <- lines[i]
      
      # Skip comments if requested
      if (exclude_comments && grepl("^\\s*#", line)) next
      
      # Check pattern
      if (grepl(pattern, line, perl = TRUE)) {
        rel_path <- gsub(paste0("^", normalizePath(r_dir), "[\\\\/]"), "", 
                         normalizePath(file))
        matches[[length(matches) + 1]] <- list(
          file = rel_path,
          line_num = i,
          line_text = trimws(line)
        )
      }
    }
  }
  
  # Build report
  report_text <- c(sprintf("[%s] %s", level, label))
  if (explanation != "") {
    report_text <- c(report_text, sprintf("  Why: %s", explanation))
  }
  
  if (length(matches) == 0) {
    cat("  ✓ None found\n\n")
    report_text <- c(report_text, "  ✓ None found", "")
    return(list(count = 0, report_text = report_text))
  }
  
  cat(sprintf("  ❌ Found %d violation(s)\n", length(matches)))
  report_text <- c(report_text, sprintf("  ❌ Found %d violation(s)", length(matches)))
  
  # Show first 5 in console
  for (i in 1:min(5, length(matches))) {
    m <- matches[[i]]
    cat(sprintf("    %s:%d\n", m$file, m$line_num))
    line_preview <- if (nchar(m$line_text) > 60) paste0(substr(m$line_text, 1, 60), "...") else m$line_text
    cat(sprintf("      %s\n", line_preview))
  }
  
  if (length(matches) > 5) {
    cat(sprintf("    ... and %d more (see full report)\n", length(matches) - 5))
  }
  
  # Add ALL to report
  for (i in seq_along(matches)) {
    m <- matches[[i]]
    report_text <- c(report_text, sprintf("  [%d] %s:%d", i, m$file, m$line_num))
    report_text <- c(report_text, sprintf("      %s", m$line_text))
  }
  
  cat("\n")
  report_text <- c(report_text, "")
  
  count <- if (count_toward_total) length(matches) else 0
  list(count = count, report_text = report_text)
}

#' Check Roxygen2 Documentation Completeness
check_roxygen_completeness <- function(r_dir) {
  cat("[IMPORTANT] Roxygen2 completeness (CONTRACT, DOES NOT, @param, @return)\n")
  
  r_files <- list.files(r_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  missing_docs <- list()
  
  for (file in r_files) {
    lines <- tryCatch(readLines(file, warn = FALSE), error = function(e) character(0))
    
    # Find @export
    for (i in seq_along(lines)) {
      if (grepl("@export", lines[i])) {
        
        # Find function name
        func_name <- NA
        func_line <- NA
        for (j in (i-1):max(1, i-30)) {
          if (grepl("^[a-zA-Z_][a-zA-Z0-9_.]* <- function", lines[j])) {
            func_line <- j
            func_name <- gsub(" <-.*", "", trimws(lines[j]))
            break
          }
        }
        
        if (!is.na(func_line)) {
          roxygen_start <- max(1, func_line - 50)
          roxygen_block <- lines[roxygen_start:i]
          
          has_contract <- any(grepl("@section CONTRACT:", roxygen_block))
          has_does_not <- any(grepl("@section DOES NOT:", roxygen_block))
          has_param <- any(grepl("@param", roxygen_block))
          has_return <- any(grepl("@return", roxygen_block))
          
          if (!has_contract || !has_does_not || !has_param || !has_return) {
            rel_path <- gsub(paste0("^", normalizePath(r_dir), "[\\\\/]"), "",
                             normalizePath(file))
            
            missing_parts <- c()
            if (!has_contract) missing_parts <- c(missing_parts, "CONTRACT")
            if (!has_does_not) missing_parts <- c(missing_parts, "DOES NOT")
            if (!has_param) missing_parts <- c(missing_parts, "@param")
            if (!has_return) missing_parts <- c(missing_parts, "@return")
            
            missing_docs[[length(missing_docs) + 1]] <- list(
              file = rel_path,
              line_num = func_line,
              func_name = func_name,
              missing_parts = missing_parts
            )
          }
        }
      }
    }
  }
  
  report_text <- c("[IMPORTANT] Roxygen2 completeness (CONTRACT, DOES NOT, @param, @return)")
  
  if (length(missing_docs) == 0) {
    cat("  ✓ All exported functions properly documented\n\n")
    report_text <- c(report_text, "  ✓ All exported functions properly documented", "")
    return(list(count = 0, report_text = report_text))
  }
  
  cat(sprintf("  ❌ Found %d function(s) with incomplete documentation\n", length(missing_docs)))
  report_text <- c(report_text, sprintf("  ❌ Found %d function(s) with incomplete documentation", length(missing_docs)))
  
  for (i in seq_along(missing_docs)) {
    item <- missing_docs[[i]]
    cat(sprintf("    %s:%d - %s() missing: %s\n",
                item$file, item$line_num, item$func_name,
                paste(item$missing_parts, collapse = ", ")))
    
    report_text <- c(report_text, sprintf("  [%d] %s:%d", i, item$file, item$line_num))
    report_text <- c(report_text, sprintf("      Function: %s()", item$func_name))
    report_text <- c(report_text, sprintf("      Missing: %s", paste(item$missing_parts, collapse = ", ")))
  }
  
  cat("\n")
  report_text <- c(report_text, "")
  list(count = length(missing_docs), report_text = report_text)
}

#' Check File Headers
check_file_headers <- function(r_dir) {
  cat("[IMPORTANT] File headers (PURPOSE, DEPENDENCIES, CONTENTS)\n")
  
  r_files <- list.files(r_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  # Skip small files (likely just stubs)
  r_files <- r_files[file.size(r_files) > 500]
  
  missing_headers <- list()
  
  for (file in r_files) {
    lines <- tryCatch(readLines(file, warn = FALSE, n = 50), error = function(e) character(0))
    header_text <- paste(lines[1:min(50, length(lines))], collapse = "\n")
    
    has_purpose <- grepl("PURPOSE", header_text, ignore.case = TRUE)
    has_deps <- grepl("DEPENDENCIES|DEPENDS", header_text, ignore.case = TRUE)
    has_contents <- grepl("CONTENTS", header_text, ignore.case = TRUE)
    
    if (!has_purpose || !has_deps || !has_contents) {
      rel_path <- gsub(paste0("^", normalizePath(r_dir), "[\\\\/]"), "",
                       normalizePath(file))
      
      missing_parts <- c()
      if (!has_purpose) missing_parts <- c(missing_parts, "PURPOSE")
      if (!has_deps) missing_parts <- c(missing_parts, "DEPENDENCIES")
      if (!has_contents) missing_parts <- c(missing_parts, "CONTENTS")
      
      missing_headers[[length(missing_headers) + 1]] <- list(
        file = rel_path,
        missing_parts = missing_parts
      )
    }
  }
  
  report_text <- c("[IMPORTANT] File headers (PURPOSE, DEPENDENCIES, CONTENTS)")
  
  if (length(missing_headers) == 0) {
    cat("  ✓ All files have proper headers\n\n")
    report_text <- c(report_text, "  ✓ All files have proper headers", "")
    return(list(count = 0, report_text = report_text))
  }
  
  cat(sprintf("  ❌ Found %d file(s) with incomplete headers\n", length(missing_headers)))
  report_text <- c(report_text, sprintf("  ❌ Found %d file(s) with incomplete headers", length(missing_headers)))
  
  for (i in seq_along(missing_headers)) {
    item <- missing_headers[[i]]
    cat(sprintf("    %s missing: %s\n", item$file, paste(item$missing_parts, collapse = ", ")))
    report_text <- c(report_text, sprintf("  [%d] %s", i, item$file))
    report_text <- c(report_text, sprintf("      Missing: %s", paste(item$missing_parts, collapse = ", ")))
  }
  
  cat("\n")
  report_text <- c(report_text, "")
  list(count = length(missing_headers), report_text = report_text)
}

#' Check Input Validation
check_input_validation <- function(r_dir) {
  cat("[IMPORTANT] Input validation (stopifnot, is.data.frame, etc.)\n")
  
  r_files <- list.files(r_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  missing_validation <- list()
  
  for (file in r_files) {
    lines <- tryCatch(readLines(file, warn = FALSE), error = function(e) character(0))
    
    # Find exported functions
    for (i in seq_along(lines)) {
      if (grepl("@export", lines[i])) {
        
        # Find function definition
        func_line <- NA
        for (j in (i-1):max(1, i-30)) {
          if (grepl("^[a-zA-Z_][a-zA-Z0-9_.]* <- function\\(", lines[j])) {
            func_line <- j
            break
          }
        }
        
        if (!is.na(func_line)) {
          # Check next 20 lines for validation
          check_lines <- lines[func_line:min(length(lines), func_line + 20)]
          
          has_validation <- any(grepl("stopifnot|is\\.|stop\\(|if \\(!is", check_lines))
          
          if (!has_validation) {
            rel_path <- gsub(paste0("^", normalizePath(r_dir), "[\\\\/]"), "",
                             normalizePath(file))
            func_name <- gsub(" <-.*", "", trimws(lines[func_line]))
            
            missing_validation[[length(missing_validation) + 1]] <- list(
              file = rel_path,
              line_num = func_line,
              func_name = func_name
            )
          }
        }
      }
    }
  }
  
  report_text <- c("[IMPORTANT] Input validation")
  
  if (length(missing_validation) == 0) {
    cat("  ✓ All exported functions have input validation\n\n")
    report_text <- c(report_text, "  ✓ All exported functions have input validation", "")
    return(list(count = 0, report_text = report_text))
  }
  
  cat(sprintf("  ⚠️  Found %d function(s) without obvious input validation\n", length(missing_validation)))
  report_text <- c(report_text, sprintf("  ⚠️  Found %d function(s) without obvious input validation", length(missing_validation)))
  
  for (i in 1:min(5, length(missing_validation))) {
    item <- missing_validation[[i]]
    cat(sprintf("    %s:%d - %s()\n", item$file, item$line_num, item$func_name))
  }
  if (length(missing_validation) > 5) {
    cat(sprintf("    ... and %d more\n", length(missing_validation) - 5))
  }
  
  # Add all to report
  for (i in seq_along(missing_validation)) {
    item <- missing_validation[[i]]
    report_text <- c(report_text, sprintf("  [%d] %s:%d - %s()", i, item$file, item$line_num, item$func_name))
  }
  
  cat("\n")
  report_text <- c(report_text, "")
  list(count = length(missing_validation), report_text = report_text)
}

#' Check Function Naming (snake_case)
check_function_naming <- function(r_dir) {
  cat("[STYLE] Function naming (should be snake_case)\n")
  
  r_files <- list.files(r_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  bad_names <- list()
  
  for (file in r_files) {
    lines <- tryCatch(readLines(file, warn = FALSE), error = function(e) character(0))
    
    for (i in seq_along(lines)) {
      # Match function definitions
      if (grepl("^[a-zA-Z_][a-zA-Z0-9_.]* <- function", lines[i])) {
        func_name <- gsub(" <-.*", "", trimws(lines[i]))
        
        # Check if NOT snake_case (has camelCase or PascalCase)
        if (grepl("[a-z][A-Z]", func_name)) {
          rel_path <- gsub(paste0("^", normalizePath(r_dir), "[\\\\/]"), "",
                           normalizePath(file))
          
          bad_names[[length(bad_names) + 1]] <- list(
            file = rel_path,
            line_num = i,
            func_name = func_name
          )
        }
      }
    }
  }
  
  report_text <- c("[STYLE] Function naming (should be snake_case)")
  
  if (length(bad_names) == 0) {
    cat("  ✓ All functions use snake_case\n\n")
    report_text <- c(report_text, "  ✓ All functions use snake_case", "")
    return(list(count = 0, report_text = report_text))
  }
  
  cat(sprintf("  ⚠️  Found %d function(s) not using snake_case\n", length(bad_names)))
  report_text <- c(report_text, sprintf("  ⚠️  Found %d function(s) not using snake_case", length(bad_names)))
  
  for (i in seq_along(bad_names)) {
    item <- bad_names[[i]]
    cat(sprintf("    %s:%d - %s\n", item$file, item$line_num, item$func_name))
    report_text <- c(report_text, sprintf("  [%d] %s:%d - %s", i, item$file, item$line_num, item$func_name))
  }
  
  cat("\n")
  report_text <- c(report_text, "")
  list(count = length(bad_names), report_text = report_text)
}

#' Check Dependencies Documented
check_dependencies_documented <- function(r_dir) {
  cat("[IMPORTANT] Dependencies documented in file headers\n")
  
  # This is covered by check_file_headers, so just report
  cat("  ℹ️  See 'File headers' check above\n\n")
  
  report_text <- c(
    "[IMPORTANT] Dependencies documented",
    "  ℹ️  See 'File headers' check above",
    ""
  )
  
  list(count = 0, report_text = report_text)
}

#' Check Hardcoded Detectors
check_hardcoded_detectors <- function(r_dir) {
  cat("[CRITICAL] Hardcoded detector names/IDs (should use YAML)\n")
  
  r_files <- list.files(r_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  hardcoded <- list()
  
  for (file in r_files) {
    # Skip config.R (detector mapping lives there)
    if (basename(file) == "config.R") next
    
    lines <- tryCatch(readLines(file, warn = FALSE), error = function(e) character(0))
    
    for (i in seq_along(lines)) {
      # Look for detector assignment patterns like:
      # detectors <- c("SMO", "LPI", "MCO")
      # detector_mapping <- c("ABC123" = "Site_A")
      if (grepl('detector.*<-.*c\\(.*["\']', lines[i], ignore.case = TRUE) &&
          !grepl("#", lines[i])) {  # Skip comments
        
        rel_path <- gsub(paste0("^", normalizePath(r_dir), "[\\\\/]"), "",
                         normalizePath(file))
        
        hardcoded[[length(hardcoded) + 1]] <- list(
          file = rel_path,
          line_num = i,
          line_text = trimws(lines[i])
        )
      }
    }
  }
  
  report_text <- c("[CRITICAL] Hardcoded detector names/IDs")
  
  if (length(hardcoded) == 0) {
    cat("  ✓ No hardcoded detector mappings found\n\n")
    report_text <- c(report_text, "  ✓ No hardcoded detector mappings found", "")
    return(list(count = 0, report_text = report_text))
  }
  
  cat(sprintf("  ❌ Found %d potential hardcoded detector mapping(s)\n", length(hardcoded)))
  report_text <- c(report_text, sprintf("  ❌ Found %d potential hardcoded detector mapping(s)", length(hardcoded)))
  
  for (i in seq_along(hardcoded)) {
    item <- hardcoded[[i]]
    cat(sprintf("    %s:%d\n", item$file, item$line_num))
    report_text <- c(report_text, sprintf("  [%d] %s:%d", i, item$file, item$line_num))
    report_text <- c(report_text, sprintf("      %s", item$line_text))
  }
  
  cat("\n")
  report_text <- c(report_text, "")
  list(count = length(hardcoded), report_text = report_text)
}

#' Check @param Documentation
check_param_docs <- function(r_dir) {
  cat("[IMPORTANT] @param documentation matches function parameters\n")
  
  # This is partially covered by check_roxygen_completeness
  # For now, just note it
  cat("  ℹ️  See 'Roxygen2 completeness' check above\n\n")
  
  report_text <- c(
    "[IMPORTANT] @param documentation",
    "  ℹ️  See 'Roxygen2 completeness' check above",
    ""
  )
  
  list(count = 0, report_text = report_text)
}

#' Check Long Functions
check_long_functions <- function(r_dir) {
  cat("[INFO] Long functions (>100 lines - consider refactoring)\n")
  
  r_files <- list.files(r_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  long_funcs <- list()
  
  for (file in r_files) {
    lines <- tryCatch(readLines(file, warn = FALSE), error = function(e) character(0))
    
    i <- 1
    while (i <= length(lines)) {
      # Find function start
      if (grepl("^[a-zA-Z_][a-zA-Z0-9_.]* <- function", lines[i])) {
        func_name <- gsub(" <-.*", "", trimws(lines[i]))
        func_start <- i
        
        # Find function end (next function or end of file)
        func_end <- i
        brace_count <- 0
        started <- FALSE
        
        for (j in i:length(lines)) {
          if (grepl("\\{", lines[j])) {
            brace_count <- brace_count + 1
            started <- TRUE
          }
          if (grepl("\\}", lines[j])) {
            brace_count <- brace_count - 1
          }
          if (started && brace_count == 0) {
            func_end <- j
            break
          }
        }
        
        func_length <- func_end - func_start + 1
        
        if (func_length > 100) {
          rel_path <- gsub(paste0("^", normalizePath(r_dir), "[\\\\/]"), "",
                           normalizePath(file))
          
          long_funcs[[length(long_funcs) + 1]] <- list(
            file = rel_path,
            line_num = func_start,
            func_name = func_name,
            length = func_length
          )
        }
        
        i <- func_end + 1
      } else {
        i <- i + 1
      }
    }
  }
  
  report_text <- c("[INFO] Long functions (>100 lines)")
  
  if (length(long_funcs) == 0) {
    cat("  ✓ No excessively long functions\n\n")
    report_text <- c(report_text, "  ✓ No excessively long functions", "")
    return(list(count = 0, report_text = report_text))
  }
  
  cat(sprintf("  ℹ️  Found %d function(s) over 100 lines\n", length(long_funcs)))
  report_text <- c(report_text, sprintf("  ℹ️  Found %d function(s) over 100 lines", length(long_funcs)))
  
  for (i in seq_along(long_funcs)) {
    item <- long_funcs[[i]]
    cat(sprintf("    %s:%d - %s() [%d lines]\n", 
                item$file, item$line_num, item$func_name, item$length))
    report_text <- c(report_text, sprintf("  [%d] %s:%d - %s() [%d lines]",
                                          i, item$file, item$line_num, item$func_name, item$length))
  }
  
  cat("\n")
  report_text <- c(report_text, "")
  list(count = 0, report_text = report_text)  # Don't count as violations
}

# ==============================================================================
# RUN AUDIT
# ==============================================================================

audit_code()
