library(tibble)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
if (length(file_arg) > 0) {
  script_dir <- dirname(normalizePath(sub("^--file=", "", file_arg), winslash = "/", mustWork = TRUE))
} else {
  script_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)
results_dir <- file.path(project_root, "outputs", "results")
csv_path <- file.path(results_dir, "LAI_results_long.csv")

default_df <- data.frame(
  ID = character(),
  Longitude = numeric(),
  Latitude = numeric(),
  date = character(),
  LAI = numeric(),
  stringsAsFactors = FALSE
)

dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(default_df, csv_path, row.names = FALSE)

cat("✅ Empty LAI results CSV created. Preview:\n")
print(as_tibble(default_df))
