library(dplyr)
library(readr)

script_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)
results_dir <- file.path(project_root, "outputs", "results")

# File paths
wood_removal_path <- file.path(results_dir, "wood_removal_results.csv")
lai_results_path <- file.path(results_dir, "LAI_results.csv")

# Read the data
wood_removal <- read_csv(wood_removal_path)
lai_results <- read_csv(lai_results_path)

# Define the plots without conifers
plot_ids_wo_conifer <- c("LT11", "LT13", "LT14", "LT23", "LT24",
                         "LT33", "LT41", "LT44", "LT34",
                         "LT51", "LT52", "LT53", "LT61", "LT62", "LT63")

# Filter baseline DHPLAI values where LTLAI == 0 for the selected plots
baseline <- wood_removal %>%
    rename(ID = plot) %>%
    filter(ID %in% plot_ids_wo_conifer, LTLAI == 0) %>%
    select(ID, DHPLAI) %>%
    rename(baseline_DHPLAI = DHPLAI)

# Apply correction only to the specified plots
lai_corrected <- lai_results %>%
  left_join(baseline, by = "ID") %>%
  mutate(
    LAI_corrected = ifelse(ID %in% plot_ids_wo_conifer, LAI - baseline_DHPLAI, NA)
  ) %>%
  select(ID, date, LAI, LAI_corrected, lat, lon)

# Preview the result
print(head(lai_corrected))

# Optionally save to CSV
write_csv(lai_corrected, file.path(results_dir, "LAI_corrected_deciduous.csv"))
