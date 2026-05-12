files <- list.files(
  c("R", "scripts"),
  pattern = "[.][Rr]$",
  recursive = TRUE,
  full.names = TRUE
)

lints <- unlist(lapply(files, lintr::lint), recursive = FALSE)
print(lints)

quit(status = length(lints) > 0)
