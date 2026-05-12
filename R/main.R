suppressPackageStartupMessages({
  library(mFilter)
  library(dplyr)
  library(tidyr)
  library(xtable)
  library(ggplot2)
  library(zoo)
})

source("R/run_analysis.R")

results <- run_analysis()

if (sys.nframe() == 0) {
  message("Thesis code completed.")
}
