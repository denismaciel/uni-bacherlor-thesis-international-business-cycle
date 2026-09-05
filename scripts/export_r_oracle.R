# Independent full-precision oracle for validating the Python implementation.
# Run: nix shell .#default -c Rscript scripts/export_r_oracle.R /tmp/bkk-r-oracle
args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args)) args[[1]] else "/tmp/bkk-r-oracle"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
source("R/main.R")
write.csv(results$panel, file.path(output_dir, "panel.csv"), row.names = FALSE)
write.csv(
  results$variable_results$employment$initial_timespan,
  file.path(output_dir, "employment_initial_timespan.csv"), row.names = FALSE
)
for (variable in names(results$variable_results)) {
  result <- results$variable_results[[variable]]
  write.csv(result$correlation, file.path(output_dir, paste0(variable, "_correlation.csv")))
  write.csv(result$stdv, file.path(output_dir, paste0(variable, "_stdv.csv")), row.names = FALSE)
}
message("R oracle exported to ", output_dir)
