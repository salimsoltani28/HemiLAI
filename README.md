# HemiLAI

This repository contains a small R-based pipeline for extracting leaf area index (LAI) from hemispherical canopy photographs. The original scripts are preserved in `processing_scripts/` as-is. A cleaned project layout is provided at the repository root, and the new main script is configured by two input paths:

- the root folder containing the photo folders
- the CSV containing plot coordinates

## Project Structure

`processing_scripts/`
Legacy/original scripts kept unchanged.

`scripts/`
Active copies of the pipeline scripts using repo-local paths.

`data/all_data/`
Input data root. Put one or more folders of hemispherical photos here.

`outputs/hemi_photo_cropped/`
Temporary cropped images created during processing and deleted after the run.

`outputs/results/`
CSV outputs and log files.

`env/`
Environment file copied from the original project.

## Expected Image Naming

The processing functions assume filenames include both plot ID and date, for example:

```text
LT11_20240920.JPG
```

The plot ID becomes `ID` and the `YYYYMMDD` part becomes `date` in the results.

## Scripts

[`scripts/run_lai_pipeline.R`](scripts/run_lai_pipeline.R)
Main pipeline. It reads the configured photo root and points CSV, processes all photo folders, writes a date-stamped final reshaped wide output, and saves a timestamped log.

[`scripts/functions.R`](scripts/functions.R)
Shared helper functions:
- `crop_images()` removes the image borders before analysis.
- `process_image()` runs fisheye import, binarization, gap fraction, and canopy metrics.
- `update_csv()` is retained for compatibility with the old sequential workflow.

[`scripts/create_default_csv.R`](scripts/create_default_csv.R)
Creates an empty long-format CSV with the expected columns if you need one for debugging.

[`scripts/reshape_output.py`](scripts/reshape_output.py)
Legacy helper copy for reshaping a long-format LAI CSV into a wide table. The main R pipeline now writes the wide output directly.

[`scripts/woody_component_removal.R`](scripts/woody_component_removal.R)
Applies a woody component correction for the specific Ecosense deciduous plots listed in the script. It expects `wood_removal_results.csv` to already exist in `outputs/results/`.

## How the Main Pipeline Works

1. Set `photo_root` and `points_csv_path` at the top of `scripts/run_lai_pipeline.R`.
2. Run `scripts/run_lai_pipeline.R`.
3. The script skips any input files located inside subfolders named `raw`.
4. The script crops each image into `outputs/hemi_photo_cropped/`.
5. Each cropped image is processed with `hemispheR`.
6. The long results are joined to the point coordinates by `ID == Name`.
7. The final wide output is created with `ID`, `Longitude`, `Latitude`, and one column per date.
8. The long intermediate CSV is removed after the wide output is written.
9. Temporary cropped files are deleted.
10. A log file is written to `outputs/results/`.

## Running

The current script is already configured for:

```bash
/mnt/gsdata/projects/other/salim_playground_directory/HemiLAI/data/vods_hartheim_normalized
/mnt/gsdata/projects/icos_har/vod-positions/vod_positions.csv
```

Run from the repository root:

```bash
Rscript scripts/run_lai_pipeline.R
```

The final output will be written as:

```bash
outputs/results/LAI_processed_results_YYYYMMDD.csv
```

## Notes

- The original scripts in `processing_scripts/` were not modified.
- The new pipeline joins coordinates from the points CSV using `ID` from the photo filename and `Name` from the points file.
- The previous `LAI_processed_results.csv` in this repo does not match the points CSV for many rows, so the reconstructed pipeline uses the points CSV as the source of truth for coordinates.
- `functions.R` still installs missing R packages if they are not already available.
