load_raw_data <- function(data_dir = "data/raw") {
  read_data <- function(path) {
    read_csv(path, show_col_types = FALSE)
  }

  list(
    gdp = read_data(file.path(data_dir, "oecd/gdp.csv")),
    consumption = read_data(file.path(data_dir, "oecd/consumption.csv")),
    investment = read_data(file.path(data_dir, "oecd/investment.csv")),
    government = read_data(file.path(data_dir, "oecd/government.csv")),
    net_exports = read_data(file.path(data_dir, "oecd/net_exports.csv")),
    employment = read_data(file.path(data_dir, "oecd/employment.csv")),
    fred_employment = list(
      gbr = read_data(file.path(data_dir, "fred/gbr_employment.csv")),
      ita = read_data(file.path(data_dir, "fred/ita_employment.csv")),
      fra = read_data(file.path(data_dir, "fred/fra_employment.csv"))
    )
  )
}
