hp_cycle <- function(values, lambda = HP_FILTER_LAMBDA) {
  hpfilter(values, type = "lambda", freq = lambda)$cycle
}

add_hp_filter <- function(panel, value_col = "value", lambda = HP_FILTER_LAMBDA) {
  panel %>%
    group_by(across(all_of(c(VARIABLE_COL, LOCATION_COL)))) %>%
    mutate(!!FILTERED_COL := hp_cycle(.data[[value_col]], lambda)) %>%
    ungroup()
}

cross_country_correlation <- function(data, value_col = FILTERED_COL) {
  panel <- subset(data, select = c(LOCATION_COL, TIME_COL, value_col))
  panel <- rename(panel, value = all_of(value_col))

  correlation_matrix <- panel %>%
    pivot_wider(names_from = all_of(LOCATION_COL), values_from = value, names_sort = TRUE) %>%
    select(-all_of(TIME_COL)) %>%
    cor(., use = "pairwise.complete.obs")

  round(correlation_matrix, 3)
}

usa_correlations <- function(correlation_matrix) {
  correlation_matrix["USA",]
}

standard_deviation_by_country <- function(data, value_col = FILTERED_COL, output_col = "stdv") {
  country_levels <- unique(data[[LOCATION_COL]])

  data %>%
    mutate(country_order = factor(.data[[LOCATION_COL]], levels = country_levels)) %>%
    group_by(across(all_of(LOCATION_COL))) %>%
    summarise(!!output_col := sd(.data[[value_col]]), .groups = "drop") %>%
    mutate(country_order = factor(.data[[LOCATION_COL]], levels = country_levels)) %>%
    arrange(country_order) %>%
    select(-country_order) %>%
    rename(country = all_of(LOCATION_COL)) %>%
    as.data.frame()
}

timespan_by_country <- function(data, country_col = "location") {
  country_levels <- unique(data[[country_col]])

  data %>%
    mutate(country_order = factor(.data[[country_col]], levels = country_levels)) %>%
    group_by(country_order, across(all_of(country_col))) %>%
    summarise(
      `Last Observation` = as.character(max(.data[[TIME_COL]])),
      `First Observation` = as.character(min(.data[[TIME_COL]])),
      .groups = "drop"
    ) %>%
    select(-country_order) %>%
    rename(Country = all_of(country_col)) %>%
    as.data.frame(check.names = FALSE)
}

summarize_cross_country_correlations <- function(correlation_matrix, usa_correlation) {
  probabilities <- c(0.0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 1.0)

  upper_triangle <- correlation_matrix
  upper_triangle[lower.tri(upper_triangle)] <- NA
  diag(upper_triangle) <- NA

  values <- as.vector(upper_triangle)
  values <- values[order(values)]
  values <- values[!is.na(values)]

  usa_entries <- names(usa_correlation) %in% c("USA")
  c(
    Mean = mean(values),
    `USA Mean` = mean(usa_correlation[!usa_entries]),
    quantile(values, prob = probabilities, type = 1)
  )
}
