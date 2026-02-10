# Simple test to verify Phase 3 runs without basename errors
cat("Starting Phase 3 execution test...\n")
source('R/functions/load_all.R')

cat("\nCalling run_phase3_analysis_reporting...\n")

result <- tryCatch({
  run_phase3_analysis_reporting(verbose = FALSE)
}, error = function(e) {
  cat("\n=== ERROR CAUGHT ===\n")
  cat("Message:", e$message, "\n\n")
  NULL
})

if (!is.null(result)) {
  cat("\n✅ Phase 3 completed successfully!\n")
  cat("Report path:", result$report_release$report_html %||% "NULL", "\n")
  cat("Release bundle:", result$report_release$release_zip %||% "NULL", "\n")
} else {
  cat("\n❌ Phase 3 failed\n")
}
