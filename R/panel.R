build_standard_panel <- function(raw_data, variable_name) {
  data <- normalize_oecd_location(raw_data)
  data[[TIME_COL]] <- as.character(data[[TIME_COL]])

  data |>
    transmute(
      variable = .env$variable_name,
      location = .data[[LOCATION_COL]],
      TIME = .data[[TIME_COL]],
      Subject = .data[[SUBJECT_COL]],
      value = log(.data[[VALUE_COL]])
    ) |>
    as.data.frame()
}

build_net_exports_panel <- function(raw_net_exports) {
  net <- normalize_oecd_location(raw_net_exports)
  net[[TIME_COL]] <- as.character(net[[TIME_COL]])

  exports <- net[net$Subject == "Exports of goods and services",]
  imports <- net[net$Subject == "Imports of goods and services",]
  gdp_current_prices <- net[net$Subject == GDP_SUBJECT,]

  exports$net_exports <- exports[[VALUE_COL]] - imports[[VALUE_COL]]
  net_exports <- subset(exports, select = c(LOCATION_COL, TIME_COL, "net_exports"))
  gdp <- subset(gdp_current_prices, select = c(LOCATION_COL, TIME_COL, VALUE_COL))
  gdp <- rename(gdp, gdp = all_of(VALUE_COL))

  merge(net_exports, gdp, by = c(LOCATION_COL, TIME_COL), all = TRUE) |>
    transmute(
      variable = "net_exports",
      location = .data[[LOCATION_COL]],
      TIME = .data[[TIME_COL]],
      Subject = "Net Exports",
      value = net_exports / gdp
    ) |>
    as.data.frame()
}

build_employment_panel <- function(raw_employment, fred_employment) {
  emp <- normalize_oecd_location(raw_employment)
  emp <- emp[emp$SUBJECT == "LFEMTTTT",]
  emp[[TIME_COL]] <- as.ordered(emp[[TIME_COL]])

  emp_timespan_initial <- timespan_by_country(emp)

  gbr_emp_fred <- fred_employment$gbr
  names(gbr_emp_fred) <- c(TIME_COL, VALUE_COL)
  gbr_emp_oecd <- emp[emp$location == "GBR", c(LOCATION_COL, TIME_COL, VALUE_COL)]
  gbr_emp_fred <- format_fred_quarters(gbr_emp_fred)
  gbr_employment_splice <- merge(gbr_emp_fred, gbr_emp_oecd, by = TIME_COL, all = TRUE)
  gbr_employment_splice <- rename(gbr_employment_splice, fred_value = Value.x, oecd_value = Value.y)
  gbr_emp_def <- splice_employment_series(gbr_employment_splice, "GBR", "2011-Q4", "2015-Q1")

  ita_emp_fred <- fred_employment$ita
  names(ita_emp_fred) <- c(TIME_COL, VALUE_COL)
  ita_emp_oecd <- emp[emp$location == "ITA", c(LOCATION_COL, TIME_COL, VALUE_COL)]
  ita_emp_fred <- format_fred_quarters(ita_emp_fred)
  ita_employment_splice <- merge(ita_emp_fred, ita_emp_oecd, by = TIME_COL, all = TRUE)
  ita_employment_splice <- rename(ita_employment_splice, fred_value = Value.x, oecd_value = Value.y)
  ita_emp_def <- splice_employment_series(ita_employment_splice, "ITA", "2011-Q4", "2015-Q1")

  fra_emp_fred <- fred_employment$fra
  names(fra_emp_fred) <- c(TIME_COL, VALUE_COL)
  fra_emp_oecd <- emp[emp$location == "FRA", c(LOCATION_COL, TIME_COL, VALUE_COL)]
  fra_reference_value <- fra_emp_oecd[fra_emp_oecd$TIME == "2005-Q2",]$Value
  fra_emp_fred$Value <- fra_emp_fred$Value * fra_reference_value / 100
  fra_emp_fred <- format_fred_quarters(fra_emp_fred)
  fra_employment_splice <- merge(fra_emp_fred, fra_emp_oecd, by = TIME_COL, all = TRUE)
  fra_employment_splice <- rename(fra_employment_splice, fred_value = Value.x, oecd_value = Value.y)
  fra_emp_def <- splice_employment_series(fra_employment_splice, "FRA", "2011-Q4", "2015-Q1")
  fra_emp_def <- head(fra_emp_def, -5)

  emp_base <- subset(
    emp,
    emp$location != "GBR" & emp$location != "FRA" & emp$location != "ITA" &
      emp$location != "CHE" & emp$location != "EA19",
    select = c("location", "TIME", "Value")
  )

  emp <- bind_series_rows(emp_base, gbr_emp_def, ita_emp_def, fra_emp_def)

  list(
    panel = emp |>
      transmute(
        variable = "employment",
        location = .data[[LOCATION_COL]],
        TIME = as.character(.data[[TIME_COL]]),
        Subject = "civilian employment",
        value = log(.data[[VALUE_COL]])
      ) |>
      as.data.frame(),
    initial_timespan = emp_timespan_initial
  )
}

build_solow_residual_panel <- function(panel, capital_share = CAPITAL_SHARE) {
  panel |>
    filter(.data[[VARIABLE_COL]] %in% c("gdp", "employment")) |>
    select(all_of(c(LOCATION_COL, TIME_COL, VARIABLE_COL)), value) |>
    pivot_wider(names_from = all_of(VARIABLE_COL), values_from = value) |>
    filter(!is.na(gdp), !is.na(employment)) |>
    arrange(.data[[LOCATION_COL]], .data[[TIME_COL]]) |>
    transmute(
      variable = "solow_residuals",
      location = .data[[LOCATION_COL]],
      TIME = .data[[TIME_COL]],
      Subject = "Solow Residulas",
      value = gdp - (1 - capital_share) * employment
    ) |>
    as.data.frame()
}

build_analysis_panel <- function(raw_data) {
  standard_panel <- bind_rows(lapply(names(STANDARD_VARIABLES), function(variable) {
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
  data[[TIME_COL]] <- as.yearqtr(data[[TIME_COL]], format = "%Y-%m-%d")
  data[[TIME_COL]] <- as.character(data[[TIME_COL]])
  substr(data[[TIME_COL]], 5, 5) <- "-"
  data[[TIME_COL]] <- as.ordered(data[[TIME_COL]])
  data
}

splice_employment_series <- function(splice, country, switch_time, end_time) {
  splice <- splice[splice[[TIME_COL]] <= end_time,]
  splice[[LOCATION_COL]] <- country

  switch_row <- splice[splice[[TIME_COL]] == switch_time,]
  splice_factor <- switch_row$fred_value / switch_row$oecd_value
  splice$oecd_value <- splice_factor * splice$oecd_value
  splice[[VALUE_COL]] <- ifelse(
    splice[[TIME_COL]] <= switch_time,
    splice$fred_value,
    splice$oecd_value
  )

  splice[c(LOCATION_COL, TIME_COL, VALUE_COL)]
}
