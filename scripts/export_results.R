main <- function() {
  dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

  side_effect_files <- c(
    "output/figures/fraemployment.png",
    "output/figures/gbremployment.png",
    "output/figures/itaemployment.png"
  )

  on.exit(unlink(side_effect_files), add = TRUE)

  suppressWarnings(capture.output(source("R/main.R")))
  unlink(side_effect_files)

  write_table <- function(x, path) {
    write.csv(x, path, row.names = FALSE, na = "")
  }

  write_table_with_key <- function(x, key, path) {
    key_column <- data.frame(row_key = rownames(x), row.names = NULL, check.names = FALSE)
    names(key_column) <- key
    x <- data.frame(key_column, x, check.names = FALSE)
    write_table(x, path)
  }

  write_table(
    results$tables$timespan,
    "output/tables/table_3_timespan.csv"
  )

  write_table(
    results$tables$standard_deviations,
    "output/tables/table_4_standard_deviations.csv"
  )

  write_table(
    results$tables$within_country_correlations,
    "output/tables/table_5_within_country_correlations.csv"
  )

  table_6_us_correlations <- results$tables$usa_correlation_matrix
  names(table_6_us_correlations) <- c(
    "Row.names",
    "usa.gdpcor",
    "usa.concor",
    "usa.invcor",
    "usa.govcor",
    "usa.netcor",
    "usa.empcor",
    "usa.solcor"
  )

  write_table(
    table_6_us_correlations,
    "output/tables/table_6_us_correlations.csv"
  )

  write_table_with_key(
    results$tables$average_cross_country_correlations,
    "Variable",
    "output/tables/table_7_average_cross_country_correlations.csv"
  )
}

main()
