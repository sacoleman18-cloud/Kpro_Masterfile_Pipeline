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

resultG <- run_finalize_to_report(
  kpro_master = result2$kpro_master,
  verbose = TRUE
)
