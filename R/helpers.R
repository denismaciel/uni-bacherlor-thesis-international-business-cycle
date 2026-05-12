HP_FILTER_LAMBDA <- 1600
CAPITAL_SHARE <- 0.36
GDP_SUBJECT <- "Gross domestic product - expenditure approach"
LOCATION_COL <- "location"
OECD_LOCATION_COL <- "LOCATION"
TIME_COL <- "TIME"
VALUE_COL <- "Value"
FILTERED_COL <- "filtered"

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
