### Main LAI processing script.
### Set the photo root and points CSV paths below, then run with Rscript.
### The script processes all photo folders and writes both long and wide outputs.
### Cropped images are used only as temporary working files and are deleted after processing.

library(dplyr)
library(parallel)

# User inputs
photo_root <- "/mnt/gsdata/projects/other/salim_playground_directory/HemiLAI/data/vods_hartheim_normalized"
points_csv_path <- "/mnt/gsdata/projects/icos_har/vod-positions/vod_positions.csv"
csv_output_name <- "LAI_processed_VOD_Hartheim2_"

# Set number of cores to use
num_cores <- 20

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
if (length(file_arg) > 0) {
  script_dir <- dirname(normalizePath(sub("^--file=", "", file_arg), winslash = "/", mustWork = TRUE))
} else {
  script_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)

source(file.path(script_dir, "functions.R"))

input_folder <- photo_root
cropped_folder <- file.path(project_root, "outputs", "hemi_photo_cropped")
results_folder <- file.path(project_root, "outputs", "results")
run_stamp <- format(Sys.Date(), "%Y%m%d")
long_csv_path <- file.path(results_folder, paste0("LAI_results_long_", run_stamp, ".csv"))
wide_csv_path <- file.path(results_folder, paste0(csv_output_name, run_stamp, ".csv"))

dir.create(cropped_folder, recursive = TRUE, showWarnings = FALSE)
dir.create(results_folder, recursive = TRUE, showWarnings = FALSE)

### -------- Logging setup (adds log file, does not change main logic) -------- ###
log_file <- file.path(
  results_folder,
  paste0("LAI_log_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt")
)

# Open a connection and redirect output + messages to it
log_con <- file(log_file, open = "wt")
sink(log_con, split = TRUE)                 # stdout (cat, print, etc.)
sink(log_con, type = "message")             # messages + warnings

cat("=== LAI script started at", format(Sys.time()), "===\n")
cat("Photo root:", input_folder, "\n")
cat("Points CSV:", points_csv_path, "\n")
### -------------------------------------------------------------------------- ###

# Get all immediate subfolders of input
input_subfolders <- list.dirs(input_folder, recursive = FALSE, full.names = TRUE)

if (length(input_subfolders) == 0) {
  cat("✅ No input folders to process.\n")
  mcl_res <- list()   # make sure this exists later
} else {
  mcl_res <- mclapply(input_subfolders, function(folder) {
    folder_name   <- basename(folder)
    this_cropped  <- file.path(cropped_folder, folder_name)

    cat("➡️ Processing folder:", folder_name, "\n")

    # Step 1: Crop images
    crop_images(folder, this_cropped)

    # Step 2 & 3: Process each image and collect results
    image_files <- list.files(
      this_cropped,
      pattern = "\\.(jpg|jpeg|png|JPG)$",
      full.names = TRUE,
      recursive = TRUE
    )

    folder_results <- list()  # 👈 collect all results for this folder

    for (img in image_files) {
      result <- tryCatch({
        process_image(img, endVZA = 20)
      }, error = function(e) {
        warning("⚠️ Skipping image due to error:", img)
        return(NULL)
      })

      if (!is.null(result) && is.data.frame(result)) {
        folder_results[[length(folder_results) + 1]] <- result
      }
    }

    # Step 4: Remove temporary cropped files
    unlink(this_cropped, recursive = TRUE)

    cat("✅ Finished folder:", folder_name, "\n\n")

    # 👇 Return combined results for this folder
    if (length(folder_results) > 0) {
      dplyr::bind_rows(folder_results)
    } else {
      NULL
    }
  }, mc.cores = num_cores)
}

## ---------- NEW PART: combine mclapply results and write CSV once ---------- ##

# Remove NULL entries (folders with no valid results)
mcl_res <- mcl_res[!sapply(mcl_res, is.null)]

if (length(mcl_res) > 0) {
  all_new <- dplyr::bind_rows(mcl_res)
  points_df <- load_points(points_csv_path)
  long_results <- all_new %>%
    dplyr::left_join(points_df, by = "ID") %>%
    dplyr::select(ID, Longitude, Latitude, date, LAI)

  wide_results <- build_wide_output(all_new, points_df)

  write.csv(long_results, long_csv_path, row.names = FALSE)
  write.csv(wide_results, wide_csv_path, row.names = FALSE)
  unlink(long_csv_path)
  cat("💾 Wide LAI results written to:", wide_csv_path, "\n")
  cat("🗑️ Removed intermediate long results:", long_csv_path, "\n")
} else {
  cat("ℹ️ No new LAI results to add to CSV.\n")
}

## -------------------------------------------------------------------------- ##

cat("=== LAI script finished at", format(Sys.time()), "===\n")

# Stop logging and close connection
sink(type = "message")
sink()
close(log_con)
