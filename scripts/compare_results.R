reference_dir <- "reference/tables"
output_dir <- "output/tables"

files <- c(
  "table_3_timespan.csv",
  "table_4_standard_deviations.csv",
  "table_5_within_country_correlations.csv",
  "table_6_us_correlations.csv",
  "table_7_average_cross_country_correlations.csv"
)

read_lines <- function(path) {
  if (!file.exists(path)) {
    stop("Missing file: ", path, call. = FALSE)
  }

  readLines(path, warn = FALSE)
}

failures <- c()

for (file in files) {
  reference_path <- file.path(reference_dir, file)
  output_path <- file.path(output_dir, file)

  reference <- read_lines(reference_path)
  output <- read_lines(output_path)

  if (!identical(reference, output)) {
    failures <- c(failures, file)
  }
}

if (length(failures) > 0) {
  message("Result comparison failed for:")
  message(paste0("  - ", failures, collapse = "\n"))
  message("Regenerate output with: nix develop -c Rscript scripts/export_results.R")
  quit(status = 1)
}

message("All exported thesis tables match reference artifacts.")
