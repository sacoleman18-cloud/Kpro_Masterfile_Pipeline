# ==============================================================================
# TEST: run_ingest_standardize()
# ==============================================================================

library(here)
library(tidyverse)

# Source all functions (assumes R/functions/load_all.R exists)
source(here("R", "functions", "load_all.R"))

# ==============================================================================
# Test 1: Run with verbose output
# ==============================================================================

result <- run_ingest_standardize(verbose = TRUE)

result2 <- run_cpn_template(
  kpro_master = result$kpro_master,
  verbose = TRUE
  )

resultGiga2 <- run_finalize_to_report(
  kpro_master = result2$kpro_master,
  verbose = TRUE
)

# ==============================================================================
# Test 2: Inspect the results
# ==============================================================================

# Structure of returned list
str(result, max.level = 1)

# Master data dimensions
cat("\nMaster data shape:", nrow(result$kpro_master), "rows ×", 
    ncol(result$kpro_master), "columns\n")

# First few rows
head(result$kpro_master)

# Column names
names(result$kpro_master)

# Metadata summary
cat("\n=== METADATA ===\n")
print(result$metadata)

# Checkpoint location
cat("\nCheckpoint saved to:", result$checkpoint_path, "\n")

# Validation report
cat("Validation report:", result$validation_html_path, "\n\n")

# ==============================================================================
# Test 3: Open validation HTML to verify data quality
# ==============================================================================

# Uncomment to open in browser
# browseURL(result$validation_html_path)

# ==============================================================================
# Test 4: Verify data was actually processed
# ==============================================================================

# Check for expected columns
expected_cols <- c("detector_id", "DateTime_UTC", "auto_id", "fc", "sc")
missing <- setdiff(expected_cols, names(result$kpro_master))

if (length(missing) == 0) {
  cat("✓ All expected columns present\n")
} else {
  cat("✗ Missing columns:", paste(missing, collapse = ", "), "\n")
}

# Check row counts
cat("\nDetector coverage:\n")
result$kpro_master %>%
  group_by(detector_id) %>%
  summarize(n_detections = n(), .groups = "drop") %>%
  arrange(desc(n_detections)) %>%
  print()