

"""Fast follow-up: which county has ERA5's 16,436 missing tmin_c rows."""

import pandas as pd
from aggregation_utils import discover_input_files, resolve_data_root

input_dir = resolve_data_root(["/mnt/data_f/AnimalCollisionsWeatherData/ERA5/extracted/county_daily_year"])
paths = discover_input_files(input_dir, "era5_county_daily_*.csv")

missing_chunks = []
for path in paths:
    daily = pd.read_csv(
        path,
        usecols=["geoid", "date", "tmin_c"],
        parse_dates=["date"],
        dtype={"geoid": str},
    )
    missing_chunks.append(daily[daily["tmin_c"].isna()])

missing = pd.concat(missing_chunks, ignore_index=True)
print(missing["geoid"].value_counts())
print(missing["date"].min(), missing["date"].max())
