source("R/extension_run.R")
source("R/extension_export.R")

args <- commandArgs(trailingOnly = TRUE)
snapshot <- if (length(args) >= 1L) args[1] else extension_snapshot
repetitions <- if (length(args) >= 2L) as.integer(args[2]) else 1999L
if (length(args) > 2L || is.na(repetitions)) stop("Usage: run_extension.R [snapshot] [bootstrap_replications]")
results <- run_extension(snapshot, repetitions)
output <- file.path("output/extension", snapshot)
export_extension(results, output)
print(results$summary[c("period", "method", "gap", "gap_lower", "gap_upper")], row.names = FALSE)
message("Extension report: ", file.path(output, "REPORT.md"))
