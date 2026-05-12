HP_FILTER_LAMBDA <- 1600
CAPITAL_SHARE <- 0.36
GDP_SUBJECT <- "Gross domestic product - expenditure approach"
LOCATION_COL <- "location"
OECD_LOCATION_COL <- "LOCATION"
TIME_COL <- "TIME"
VALUE_COL <- "Value"
FILTERED_COL <- "filtered"
VARIABLE_COL <- "variable"
SUBJECT_COL <- "Subject"

STANDARD_VARIABLES <- c(
  gdp = GDP_SUBJECT,
  consumption = "Private final consumption expenditure",
  investment = "Gross fixed capital formation",
  government = "General government final consumption expenditure"
)

STD_DEV_COLUMNS <- c(
  gdp = "gdp_stdv",
  consumption = "con_stdv",
  investment = "inv_stdv",
  government = "gov_stdv",
  net_exports = "net_stdv",
  employment = "emp_stdv",
  solow_residuals = "sol_stdv"
)

normalize_oecd_location <- function(data) {
  if (OECD_LOCATION_COL %in% names(data)) {
    data <- rename(data, !!LOCATION_COL := all_of(OECD_LOCATION_COL))
  }
  data
}

bind_series_rows <- function(...) {
  parts <- lapply(list(...), function(part) {
    part[[TIME_COL]] <- as.character(part[[TIME_COL]])
    part
  })
  result <- bind_rows(parts)
  result[[TIME_COL]] <- as.ordered(result[[TIME_COL]])
  result
}
