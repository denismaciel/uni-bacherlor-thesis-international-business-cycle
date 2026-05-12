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
    x <- data.frame(key = rownames(x), x, row.names = NULL, check.names = FALSE)
    names(x)[1] <- key
    write_table(x, path)
  }

  write_table(
    timespan,
    "output/tables/table_3_timespan.csv"
  )

  write_table(
    standard.deviations,
    "output/tables/table_4_standard_deviations.csv"
  )

  write_table(
    cor.with.gdp.def,
    "output/tables/table_5_within_country_correlations.csv"
  )

  write_table(
    usa.correlation.matrix,
    "output/tables/table_6_us_correlations.csv"
  )

  write_table_with_key(
    sum.cor,
    "Variable",
    "output/tables/table_7_average_cross_country_correlations.csv"
  )
}

main()
