main <- function() {
  dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

  suppressWarnings(capture.output(source("R/main.R")))
  raw_data <- load_raw_data("data/raw")

  write_png <- function(path, plot, width = 2600, height = 2000, res = 300) {
    png(filename = path, width = width, height = height, res = res)
    print(plot)
    dev.off()
  }

  write_base_png <- function(path, expression, width = 2600, height = 2000, res = 300) {
    png(filename = path, width = width, height = height, res = res)
    force(expression)
    dev.off()
  }

  gdp_usa <- results$series$gdp[results$series$gdp$location == "USA", ]
  gdp_hp_filter <- hpfilter(gdp_usa$Value, type = "lambda", freq = HP_FILTER_LAMBDA)
  gdp_hp_filter$xname <- "Logged GDP of the United States"
  write_base_png(
    "output/figures/filteredgdp.png",
    plot(gdp_hp_filter)
  )

  correlation_distribution_plot <- function(correlation_matrix) {
    upper_triangle <- correlation_matrix
    upper_triangle[lower.tri(upper_triangle)] <- NA
    diag(upper_triangle) <- NA

    data <- subset(as.data.frame(as.table(upper_triangle), responseName = "Corr"), !is.na(Corr))
    data <- data[order(data$Corr), ]

    ggplot(data, aes(x = seq_len(nrow(data)), y = Corr, col = Var2 == "USA")) +
      geom_point(size = 4) +
      scale_color_discrete(name = "Country", labels = c("Other Countries", "USA")) +
      ylab("Correlation Magnitude") +
      xlab("Correlations in Ascending Order") +
      theme(plot.title = element_text(size = rel(1.5)))
  }

  write_png(
    "output/figures/gdpcor.png",
    correlation_distribution_plot(results$correlations$gdp)
  )
  write_png(
    "output/figures/concor.png",
    correlation_distribution_plot(results$correlations$consumption)
  )

  gdp_correlations <- results$correlations$gdp
  gdp_correlations[lower.tri(gdp_correlations)] <- NA
  diag(gdp_correlations) <- NA
  gdp_pairs <- na.omit(as.data.frame(as.table(gdp_correlations)))

  consumption_correlations <- results$correlations$consumption
  consumption_correlations[lower.tri(consumption_correlations)] <- NA
  diag(consumption_correlations) <- NA
  consumption_pairs <- na.omit(as.data.frame(as.table(consumption_correlations)))

  pair_correlations <- merge(gdp_pairs, consumption_pairs, by = c("Var1", "Var2"))
  names(pair_correlations)[names(pair_correlations) == "Freq.x"] <- "gdp"
  names(pair_correlations)[names(pair_correlations) == "Freq.y"] <- "consumption"
  pair_correlations$gdp_above_consumption <- pair_correlations$gdp >= pair_correlations$consumption

  gdp_consumption_correlation_plot <- ggplot(
    pair_correlations,
    aes(consumption, gdp, color = gdp_above_consumption)
  ) +
    geom_point(size = 5) +
    xlim(-1, 1) +
    ylim(-1, 1) +
    ylab("Output Correlation") +
    xlab("Consumption Correlation") +
    geom_abline(intercept = 0, slope = 1) +
    theme(
      axis.text = element_text(size = 20),
      axis.title = element_text(size = 20, face = "bold"),
      legend.position = "none"
    )
  write_png("output/figures/gdpconplot.png", gdp_consumption_correlation_plot)

  employment_comparison <- function(country, fred_employment, raw_employment) {
    employment <- normalize_oecd_location(raw_employment)
    employment <- employment[employment$SUBJECT == "LFEMTTTT", ]
    employment[[TIME_COL]] <- as.ordered(employment[[TIME_COL]])

    fred <- fred_employment
    names(fred) <- c(TIME_COL, VALUE_COL)
    oecd <- employment[employment$location == country, c(LOCATION_COL, TIME_COL, VALUE_COL)]

    if (country == "FRA") {
      fra_reference_value <- oecd[oecd$TIME == "2005-Q2", ]$Value
      fred$Value <- fred$Value * fra_reference_value / 100
    }

    fred <- format_fred_quarters(fred)
    bind_rows(
      data.frame(TIME = as.character(fred$TIME), value = fred$Value, source = "FRED"),
      data.frame(TIME = as.character(oecd$TIME), value = oecd$Value, source = "OECD")
    )
  }

  write_employment_plot <- function(country, fred_employment, path) {
    comparison <- employment_comparison(country, fred_employment, raw_data$employment)
    comparison$quarter <- as.yearqtr(comparison$TIME, format = "%Y-Q%q")

    plot <- ggplot(comparison, aes(quarter, value, color = source)) +
      geom_line(linewidth = 0.7, na.rm = TRUE) +
      xlab("Quarter") +
      ylab("Employment") +
      theme(legend.title = element_blank())

    write_png(path, plot)
  }

  write_employment_plot("FRA", raw_data$fred_employment$fra, "output/figures/fraemployment.png")
  write_employment_plot("GBR", raw_data$fred_employment$gbr, "output/figures/gbremployment.png")
  write_employment_plot("ITA", raw_data$fred_employment$ita, "output/figures/itaemployment.png")
}

main()
