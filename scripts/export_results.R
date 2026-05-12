main <- function() {
  dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

  source("scripts/lib/csv_export.R")
  source("scripts/lib/latex_tables.R")
  source("scripts/lib/table_shapes.R")

  side_effect_files <- c(
    "output/figures/fraemployment.png",
    "output/figures/gbremployment.png",
    "output/figures/itaemployment.png"
  )

  on.exit(unlink(side_effect_files), add = TRUE)

  suppressWarnings(capture.output(source("R/main.R")))
  unlink(side_effect_files)

  tables <- build_publication_tables(results)

  write_csv_table(tables$timespan, "output/tables/table_3_timespan.csv")
  write_latex_tabular(
    tables$timespan,
    "output/tables/table_3_timespan.tex",
    align = "l *{12}{c}",
    header = latex_header(names(tables$timespan), numeric_columns = integer(0))
  )

  write_csv_table(tables$standard_deviations, "output/tables/table_4_standard_deviations.csv")
  write_latex_tabular(
    tables$standard_deviations,
    "output/tables/table_4_standard_deviations.tex",
    align = "l *{7}{S[table-format=1.3]}",
    header = latex_header(names(tables$standard_deviations))
  )

  write_csv_table(
    tables$within_country_correlations,
    "output/tables/table_5_within_country_correlations.csv"
  )
  write_latex_tabular(
    tables$within_country_correlations,
    "output/tables/table_5_within_country_correlations.tex",
    align = "l *{8}{S[table-format=-1.3]}",
    header = latex_header(names(tables$within_country_correlations))
  )

  write_csv_table(tables$usa_correlations_csv, "output/tables/table_6_us_correlations.csv")
  write_latex_tabular(
    tables$usa_correlations_latex,
    "output/tables/table_6_us_correlations.tex",
    align = "l *{7}{S[table-format=-1.3]}",
    header = latex_header(names(tables$usa_correlations_latex))
  )

  write_csv_table(
    tables$average_cross_country_correlations,
    "output/tables/table_7_average_cross_country_correlations.csv"
  )
  write_latex_tabular(
    tables$average_cross_country_correlations,
    "output/tables/table_7_average_cross_country_correlations.tex",
    align = "l *{11}{S[table-format=-1.3]}",
    header = latex_header(names(tables$average_cross_country_correlations))
  )
}

main()
