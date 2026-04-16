from pathlib import Path
import shutil


SOURCE_ROOT = Path("/mnt/gsdata/projects/icos_har/hemi_photo/vods")
TARGET_ROOT = Path("/mnt/gsdata/projects/other/salim_playground_directory/HemiLAI/data/vods_hartheim_normalized")
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".tif", ".tiff", ".bmp"}


def should_skip(path: Path) -> bool:
    lowered_parts = {part.lower() for part in path.parts}
    return "raw" in lowered_parts


def extract_plot_id(stem: str) -> str:
    return stem.split("_", 1)[0].lower()


def main() -> None:
    TARGET_ROOT.mkdir(parents=True, exist_ok=True)
    copied = 0

    for date_dir in sorted(p for p in SOURCE_ROOT.iterdir() if p.is_dir()):
        target_date_dir = TARGET_ROOT / date_dir.name
        target_date_dir.mkdir(parents=True, exist_ok=True)

        for source_file in sorted(date_dir.rglob("*")):
            if not source_file.is_file():
                continue
            if source_file.suffix.lower() not in IMAGE_SUFFIXES:
                continue
            if should_skip(source_file):
                continue

            plot_id = extract_plot_id(source_file.stem)
            target_name = f"{plot_id}_{date_dir.name}{source_file.suffix.lower()}"
            target_file = target_date_dir / target_name
            shutil.copy2(source_file, target_file)
            copied += 1

    print(f"Copied {copied} images to {TARGET_ROOT}")


if __name__ == "__main__":
    main()
