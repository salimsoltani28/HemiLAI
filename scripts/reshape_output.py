import pandas as pd
from pathlib import Path

script_dir = Path.cwd().resolve()
project_root = script_dir.parent
results_dir = project_root / "outputs" / "results"

# Load the data
file_path = results_dir / "LAI_results.csv"
df = pd.read_csv(file_path)

# Convert date to string (YYYYMMDD) to use as column name
df["date"] = df["date"].astype("Int64").astype(str)

# Pivot the table: IDs as rows, dates as columns, values = LAI
lai_wide = df.pivot_table(index="ID", 
                          columns="date", 
                          values="LAI", 
                          aggfunc="first")

# Reset index so ID becomes a column again
lai_wide = lai_wide.reset_index()

# Add coordinates (currently NaN, but keeps structure)
lai_wide["lat"] = None
lai_wide["lon"] = None

# Move lat/lon columns next to ID
cols = ["ID", "lat", "lon"] + [c for c in lai_wide.columns if c not in ["ID", "lat", "lon"]]
lai_wide = lai_wide[cols]

# Save reshaped table
output_path = results_dir / "LAI_results_processed.csv"
lai_wide.to_csv(output_path, index=False)

output_path
