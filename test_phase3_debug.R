# Debug script to find where basename(report_path) error occurs
source('R/functions/load_all.R')

tryCatch({
  run_phase3_analysis_reporting(verbose = TRUE)
}, error = function(e) {
  cat("\n=== ERROR DETAILS ===\n")
  cat("Message:", e$message, "\n")
  cat("Call:", paste(as.character(e$call), collapse = " "), "\n")
  cat("\nTraceback:\n")
  print(traceback())
})
