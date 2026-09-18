"""
Ad hoc check: how often are individual daily readings missing (NaN) in the
PRISM/ERA5 daily extracts, as opposed to whole days/months being absent
(which 05/06's is_incomplete flag already checks). Run on Kodama, where the
full 1981-2025 daily extracts are mounted -- the local dev fallback data is
only a partial sample and will understate this.
"""

import pandas as pd
from aggregation_utils import discover_input_files, load_daily_extract, resolve_data_root

DATASETS = [
    {
        "name": "PRISM",
        "input_dir_candidates": ["/mnt/data_f/AnimalCollisionsWeatherData/PRISM/extracted/county_daily_year"],
        "input_pattern": "prism_county_daily_*.csv",
        "value_cols": ["tmin", "tmax", "tmean", "ppt"],
    },
    {
        "name": "ERA5",
        "input_dir_candidates": ["/mnt/data_f/AnimalCollisionsWeatherData/ERA5/extracted/county_daily_year"],
        "input_pattern": "era5_county_daily_*.csv",
        "value_cols": ["tmin_c", "tmax_c", "tmean_c", "precip_mm", "snowfall_mm", "snow_depth"],
    },
]

for ds in DATASETS:
    print(f"\n=== {ds['name']} ===")
    input_dir = resolve_data_root(ds["input_dir_candidates"])
    paths = discover_input_files(input_dir, ds["input_pattern"])

    total_rows = 0
    na_counts = {col: 0 for col in ds["value_cols"]}

    for path in paths:
        daily = load_daily_extract(path)
        total_rows += len(daily)
        for col in ds["value_cols"]:
            if col in daily.columns:
                na_counts[col] += daily[col].isna().sum()

    print(f"Total daily county-day rows: {total_rows:,}")
    for col, n_missing in na_counts.items():
        pct = 100 * n_missing / total_rows if total_rows else 0
        print(f"  {col}: {n_missing:,} missing ({pct:.4f}%)")

