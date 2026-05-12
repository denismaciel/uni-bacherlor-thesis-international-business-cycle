hp_filter_lambda <- 1600
capital_share_value <- 0.36
gdp_subject <- "Gross domestic product - expenditure approach"
location_col <- "location"
time_col <- "time"
value_col <- "value"
filtered_col <- "filtered"
variable_col <- "variable"
subject_col <- "subject"

standard_variables <- c(
  gdp = gdp_subject,
  consumption = "Private final consumption expenditure",
  investment = "Gross fixed capital formation",
  government = "General government final consumption expenditure"
)

std_dev_columns <- c(
  gdp = "gdp_stdv",
  consumption = "con_stdv",
  investment = "inv_stdv",
  government = "gov_stdv",
  net_exports = "net_stdv",
  employment = "emp_stdv",
  solow_residuals = "sol_stdv"
)

normalize_oecd_location <- function(data) {
  rename(
    data,
    location = any_of("LOCATION"),
    time = any_of("TIME"),
    subject_code = any_of("SUBJECT"),
    subject = any_of("Subject"),
    value = any_of("Value")
  )
}

bind_series_rows <- function(...) {
  parts <- lapply(list(...), function(part) {
    part[[time_col]] <- as.character(part[[time_col]])
    part
  })
  result <- bind_rows(parts)
  result[[time_col]] <- as.ordered(result[[time_col]])
  result
}
