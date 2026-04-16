# Set CRAN mirror to avoid selection prompt
options(repos = c(CRAN = "https://cloud.r-project.org"))

# First check if required packages are ifunctionstalled. If not they get installed.
required_packages <- c("hemispheR", "stringr", "dplyr", "tidyr", "readr")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# Function to crop all images from input_dir into output_dir
##### This is done so we only analyze the image itself and set the Zenith angles right. Before the images ahd somne small black borders at the top and bottom
crop_images <- function(input_dir, cropped_dir) {
  if (!require("imager")) install.packages("imager")
  library(imager)
  
  if (!dir.exists(cropped_dir)) dir.create(cropped_dir, recursive = TRUE)
  
  image_files <- list.files(input_dir, pattern = "\\.(jpg|jpeg|png|tif|bmp|JPG|JPEG|PNG|TIF|BMP)$", 
                            full.names = TRUE, recursive = TRUE)
  image_files <- image_files[!grepl("(^|/)[Rr][Aa][Ww](/|$)", image_files)]
  
  for (image_path in image_files) {
    image <- tryCatch(load.image(image_path), error = function(e) NULL)
    if (is.null(image)) next
    
    cropped_image <- crop.borders(image, ny = c(220, 280))
    
    relative_path <- sub(input_dir, "", image_path)
    output_path <- file.path(cropped_dir, dirname(relative_path))
    if (!dir.exists(output_path)) dir.create(output_path, recursive = TRUE)
    
    output_file <- file.path(output_path, sub("\\.JPG$", ".jpg", basename(image_path)))
    
    tryCatch({
      save.image(cropped_image, output_file)
      cat("Processed:", image_path, "->", output_file, "\n")
    }, error = function(e) {
      cat("Failed to process:", image_path, "Error:", e$message, "\n")
    })
  }
}

# Helper to extract date from filename, falling back to the parent folder name.
extract_date <- function(image_path) {
  filename <- basename(image_path)
  date <- str_extract(filename, "\\d{8}")

  if (is.na(date)) {
    path_parts <- strsplit(normalizePath(image_path, winslash = "/", mustWork = FALSE), "/")[[1]]
    date_parts <- path_parts[grepl("^\\d{8}$", path_parts)]
    if (length(date_parts) > 0) {
      date <- tail(date_parts, 1)
    }
  }

  date
}

# Helper to extract plot/ID from filename
extract_plot <- function(filename) {
  tolower(strsplit(filename, "_", fixed = TRUE)[[1]][1])
}

# Function to process a single image
### These are mostly default settings. The range is from 0-20° Zenith angle as these were found to suit best. Lens is set to the lens used (Sigma 4.5mm). 
### Display should be set to False otherwise we display every image analysed.
process_image <- function(image_path, endVZA) {
  file_name <- basename(image_path)
  date <- extract_date(image_path)
  plot <- extract_plot(file_name)

  img <- import_fisheye(image_path,
                        channel = 3, #only use 1 if you increased the contrast with 2BG; DEFAULT: 3 we run the analysis on the blue channel
                        circular = TRUE,
                        gamma = 2.2,
                        stretch = FALSE,
                        display = FALSE,
                        message = TRUE)

  img.bw <- binarize_fisheye(img,
                             method = 'Otsu',
                             zonal = FALSE,
                             manual = NULL,
                             display = FALSE,
                             export = FALSE)

  gap.frac <- gapfrac_fisheye(img.bw,
                              maxVZA = 90,
                              lens = "Sigma-4.5",
                              startVZA = 0,
                              endVZA = endVZA,
                              nrings = 5,
                              nseg = 8,
                              display = FALSE,
                              message = FALSE)

  canopy <- canopy_fisheye(gap.frac)

  results <- data.frame(
  ID = as.character(plot),
  date = as.character(date),
  LAI = as.numeric(canopy$Le / canopy$LXG2),
  lat = as.numeric(NA),
  lon = as.numeric(NA),
  stringsAsFactors = FALSE
)

  return(results)
}
### This then updates the csv with the results. There were some issues with the format, so I needed to make this a bit longer and code it a bit more hard.

update_csv <- function(new_data, csv_path) {
  # Define expected structure
  enforce_types <- function(df) {
    df$ID   <- as.character(df$ID)
    df$date <- as.character(df$date)
    df$LAI  <- as.numeric(df$LAI)
    df$lat  <- as.numeric(df$lat)
    df$lon  <- as.numeric(df$lon)
    df
  }

  # Apply structure to new data
  new_data <- new_data[, c("ID", "date", "LAI", "lat", "lon"), drop = FALSE]
  new_data <- enforce_types(new_data)

  # Load or initialize existing data
  if (file.exists(csv_path)) {
    existing <- read.csv(csv_path, stringsAsFactors = FALSE)
    existing <- existing[, c("ID", "date", "LAI", "lat", "lon"), drop = FALSE]
    existing <- enforce_types(existing)
  } else {
    existing <- data.frame(
      ID = character(),
      date = character(),
      LAI = numeric(),
      lat = numeric(),
      lon = numeric(),
      stringsAsFactors = FALSE
    )
  }

  # Combine and write
  combined <- dplyr::bind_rows(existing, new_data)
  write.csv(combined, csv_path, row.names = FALSE)
}

load_points <- function(points_csv_path) {
  first_line <- readLines(points_csv_path, n = 1, warn = FALSE)
  delim <- if (grepl(";", first_line)) ";" else ","
  points <- readr::read_delim(points_csv_path, delim = delim, show_col_types = FALSE)

  id_col <- NULL
  if ("Name" %in% names(points)) {
    id_col <- "Name"
  } else if ("VOD-name" %in% names(points)) {
    id_col <- "VOD-name"
  } else {
    stop("Points CSV must contain either a 'Name' or 'VOD-name' column.")
  }

  points %>%
    dplyr::transmute(
      ID = tolower(as.character(.data[[id_col]])),
      Longitude = as.numeric(Longitude),
      Latitude = as.numeric(Latitude)
    ) %>%
    dplyr::distinct(ID, .keep_all = TRUE) %>%
    dplyr::arrange(ID)
}

build_wide_output <- function(long_results, points_df) {
  lai_wide <- long_results %>%
    dplyr::group_by(ID, date) %>%
    dplyr::summarise(LAI = dplyr::first(LAI), .groups = "drop") %>%
    dplyr::arrange(date) %>%
    tidyr::pivot_wider(
      names_from = date,
      values_from = LAI
    )

  points_df %>%
    dplyr::left_join(lai_wide, by = "ID") %>%
    dplyr::arrange(ID)
}
