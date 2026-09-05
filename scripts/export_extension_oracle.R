# Independent fixtures: no Python code or generated Python estimates are read.
source("R/extension_data.R")
source("R/extension_statistics.R")
args <- commandArgs(trailingOnly = TRUE)
output <- if (length(args)) args[1] else "reference/extension_oracle"
dir.create(output, recursive = TRUE, showWarnings = FALSE)
write_fixture <- function(rows, name) {
  write.csv(rows, file.path(output, paste0(name, ".csv")), row.names = FALSE)
}
samples <- list()
for (seed in c(0L, 42L, 20260905L, -1L)) {
  for (n in c(1L, 45L, 111L, 128L, 65536L, 65537L)) {
    set.seed(seed, kind = "Mersenne-Twister", sample.kind = "Rejection")
    samples[[length(samples) + 1L]] <- data.frame(seed = seed, n = n, draw = 1:1000,
                                               index = sample.int(n, 1000L, replace = TRUE) - 1L)
  }
}
write_fixture(do.call(rbind, samples), "random_indices")
set.seed(20260905, kind = "Mersenne-Twister", sample.kind = "Rejection")
blocks <- t(replicate(99L, circular_block_indices(111L, 8L) - 1L))
write_fixture(as.data.frame(blocks), "block_indices")

levels <- balanced_extension(read_current_extension())
old <- balanced_extension(read_original_extension(), "1996-Q1", "2015-Q1")
transformed <- intervals <- list()
for (method in c("hp1600", "growth", "hamilton")) {
  for (vintage in c("current", "original")) {
    input <- if (vintage == "current") levels else old
    sample <- extension_window(input, method, min(input$quarter) + 11L, max(input$quarter))
    for (i in seq_along(sample$countries)) {
      transformed[[length(transformed) + 1L]] <- data.frame(
        vintage = vintage, method = method, country = sample$countries[i], time = quarter_text(sample$quarter),
        output = sample$y[, i], consumption = sample$c[, i])
    }
    boot <- bootstrap_extension(sample, repetitions = 99L, seed = 42L)
    intervals[[length(intervals) + 1L]] <- data.frame(vintage = vintage, method = method, statistic = seq_along(boot$point),
                                                  point = boot$point, lower = boot$lower, upper = boot$upper)
  }
}
write_fixture(do.call(rbind, transformed), "transformed")
write_fixture(do.call(rbind, intervals), "bootstrap_99_seed42")
writeLines(sub("[[:blank:]]+$", "", capture.output(sessionInfo())), file.path(output, "session-info.txt"))
message("Independent R extension oracle: ", output)
