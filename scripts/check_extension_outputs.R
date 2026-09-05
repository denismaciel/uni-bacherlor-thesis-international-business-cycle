# Independent check of the serialized growth estimates against raw panel levels.
# Run after scripts/run_extension.R; does not use extension transformation helpers.
snapshot <- "2026-09-05T221752Z"
input <- read.csv(file.path("data/processed/oecd", snapshot, "panel.csv"))
output <- file.path("output/extension", snapshot)
summary <- read.csv(file.path(output, "summary.csv"))
diagnostics <- read.csv(file.path(output, "episode_diagnostics.csv"))
countries <- sort(unique(input$location))
quarters <- sort(unique(input$time[input$time >= "1996-Q1"]))
growth <- lapply(c("gdp", "consumption"), function(variable) {
  sapply(countries, function(country) {
    series <- input[input$variable == variable & input$location == country, ]
    diff(log(series$value[match(quarters, series$time)]))
  })
})
dates <- quarters[-1]
independent_gap <- function(keep) {
  # Mean of all off-diagonal entries equals the mean of unordered pairs.
  means <- vapply(growth, function(matrix) {
    correlations <- stats::cor(matrix[keep, ])
    mean(correlations[row(correlations) != col(correlations)])
  }, numeric(1))
  means[1] - means[2]
}
for (i in which(summary$method == "growth")) {
  row <- summary[i, ]
  keep <- dates >= row$start & dates <= row$end
  stopifnot(sum(keep) == row$quarters, abs(independent_gap(keep) - row$gap) < 1e-12)
}
keep <- dates >= "1998-Q4" & !substr(dates, 1, 4) %in% c("2008", "2009", "2020", "2021")
row <- diagnostics[diagnostics$method == "growth" & diagnostics$diagnostic == "excluding_both", ]
stopifnot(nrow(row) == 1L, sum(keep) == row$quarters, abs(independent_gap(keep) - row$gap) < 1e-12)
stopifnot(nrow(summary) == 12L, all(summary$gap_lower <= summary$gap_upper))
message("Serialized extension estimates agree with independent growth-correlation calculations.")
