build_standard_panel <- function(raw_data, variable_name) {
  data <- normalize_oecd_location(raw_data)
  data[[time_col]] <- as.character(data[[time_col]])

  data |>
    transmute(
      variable = .env$variable_name,
      location = .data[[location_col]],
      time = .data[[time_col]],
      subject = .data[[subject_col]],
      value = log(.data[[value_col]])
    )
}

build_net_exports_panel <- function(raw_net_exports) {
  net <- normalize_oecd_location(raw_net_exports)
  net[[time_col]] <- as.character(net[[time_col]])

  exports <- net[net$subject == "Exports of goods and services", ]
  imports <- net[net$subject == "Imports of goods and services", ]
  gdp_current_prices <- net[net$subject == gdp_subject, ]

  exports$net_exports <- exports[[value_col]] - imports[[value_col]]
  net_exports <- subset(exports, select = c(location_col, time_col, "net_exports"))
  gdp <- subset(gdp_current_prices, select = c(location_col, time_col, value_col))
  gdp <- rename(gdp, gdp = all_of(value_col))

  left_join(net_exports, gdp, by = c(location_col, time_col)) |>
    transmute(
      variable = "net_exports",
      location = .data[[location_col]],
      time = .data[[time_col]],
      subject = "net_exports",
      value = net_exports / gdp
    )
}

build_employment_panel <- function(raw_employment, fred_employment) {
  emp <- normalize_oecd_location(raw_employment)
  emp <- emp[emp$subject_code == "LFEMTTTT", ]
  emp[[time_col]] <- as.ordered(emp[[time_col]])

  emp_timespan_initial <- timespan_by_country(emp)

  gbr_emp_fred <- fred_employment$gbr
  names(gbr_emp_fred) <- c(time_col, value_col)
  gbr_emp_oecd <- emp[emp$location == "GBR", c(location_col, time_col, value_col)]
  gbr_emp_fred <- format_fred_quarters(gbr_emp_fred)
  gbr_emp_fred[[time_col]] <- as.character(gbr_emp_fred[[time_col]])
  gbr_emp_oecd[[time_col]] <- as.character(gbr_emp_oecd[[time_col]])
  gbr_employment_splice <- full_join(gbr_emp_fred, gbr_emp_oecd, by = time_col)
  gbr_employment_splice <- rename(gbr_employment_splice, fred_value = value.x, oecd_value = value.y)
  gbr_emp_def <- splice_employment_series(gbr_employment_splice, "GBR", "2011-Q4", "2015-Q1")

  ita_emp_fred <- fred_employment$ita
  names(ita_emp_fred) <- c(time_col, value_col)
  ita_emp_oecd <- emp[emp$location == "ITA", c(location_col, time_col, value_col)]
  ita_emp_fred <- format_fred_quarters(ita_emp_fred)
  ita_emp_fred[[time_col]] <- as.character(ita_emp_fred[[time_col]])
  ita_emp_oecd[[time_col]] <- as.character(ita_emp_oecd[[time_col]])
  ita_employment_splice <- full_join(ita_emp_fred, ita_emp_oecd, by = time_col)
  ita_employment_splice <- rename(ita_employment_splice, fred_value = value.x, oecd_value = value.y)
  ita_emp_def <- splice_employment_series(ita_employment_splice, "ITA", "2011-Q4", "2015-Q1")

  fra_emp_fred <- fred_employment$fra
  names(fra_emp_fred) <- c(time_col, value_col)
  fra_emp_oecd <- emp[emp$location == "FRA", c(location_col, time_col, value_col)]
  fra_reference_value <- fra_emp_oecd[fra_emp_oecd$time == "2005-Q2", ]$value
  fra_emp_fred$value <- fra_emp_fred$value * fra_reference_value / 100
  fra_emp_fred <- format_fred_quarters(fra_emp_fred)
  fra_emp_fred[[time_col]] <- as.character(fra_emp_fred[[time_col]])
  fra_emp_oecd[[time_col]] <- as.character(fra_emp_oecd[[time_col]])
  fra_employment_splice <- full_join(fra_emp_fred, fra_emp_oecd, by = time_col)
  fra_employment_splice <- rename(fra_employment_splice, fred_value = value.x, oecd_value = value.y)
  fra_emp_def <- splice_employment_series(fra_employment_splice, "FRA", "2011-Q4", "2015-Q1")
  fra_emp_def <- head(fra_emp_def, -5)

  emp_base <- subset(
    emp,
    emp$location != "GBR" & emp$location != "FRA" & emp$location != "ITA" &
      emp$location != "CHE" & emp$location != "EA19",
    select = c("location", "time", "value")
  )

  emp <- bind_series_rows(emp_base, gbr_emp_def, ita_emp_def, fra_emp_def)

  list(
    panel = emp |>
      transmute(
        variable = "employment",
        location = .data[[location_col]],
        time = as.character(.data[[time_col]]),
        subject = "employment",
        value = log(.data[[value_col]])
      ),
    initial_timespan = emp_timespan_initial
  )
}

build_solow_residual_panel <- function(panel, capital_share = capital_share_value) {
  panel |>
    filter(.data[[variable_col]] %in% c("gdp", "employment")) |>
    select(all_of(c(location_col, time_col, variable_col)), value) |>
    pivot_wider(names_from = all_of(variable_col), values_from = value) |>
    filter(!is.na(gdp), !is.na(employment)) |>
    arrange(.data[[location_col]], .data[[time_col]]) |>
    transmute(
      variable = "solow_residuals",
      location = .data[[location_col]],
      time = .data[[time_col]],
      subject = "solow_residuals",
      value = gdp - (1 - capital_share) * employment
    )
}

build_analysis_panel <- function(raw_data) {
  standard_panel <- bind_rows(lapply(names(standard_variables), function(variable) {
    build_standard_panel(raw_data[[variable]], variable)
  }))
  net_exports_panel <- build_net_exports_panel(raw_data$net_exports)
  employment_data <- build_employment_panel(raw_data$employment, raw_data$fred_employment)

  base_panel <- bind_rows(standard_panel, net_exports_panel, employment_data$panel)
  solow_panel <- build_solow_residual_panel(base_panel)

  list(
    panel = add_hp_filter(bind_rows(base_panel, solow_panel)),
    employment_initial_timespan = employment_data$initial_timespan
  )
}

format_fred_quarters <- function(data) {
  data[[time_col]] <- as.yearqtr(data[[time_col]], format = "%Y-%m-%d")
  data[[time_col]] <- as.character(data[[time_col]])
  substr(data[[time_col]], 5, 5) <- "-"
  data[[time_col]] <- as.ordered(data[[time_col]])
  data
}

splice_employment_series <- function(splice, country, switch_time, end_time) {
  splice <- splice[splice[[time_col]] <= end_time, ]
  splice[[location_col]] <- country

  switch_row <- splice[splice[[time_col]] == switch_time, ]
  splice_factor <- switch_row$fred_value / switch_row$oecd_value
  splice$oecd_value <- splice_factor * splice$oecd_value
  splice[[value_col]] <- ifelse(
    splice[[time_col]] <= switch_time,
    splice$fred_value,
    splice$oecd_value
  )

  splice[c(location_col, time_col, value_col)]
}
