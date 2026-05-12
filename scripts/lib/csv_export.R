write_csv_table <- function(x, path) {
  write.csv(x, path, row.names = FALSE, na = "")
}
