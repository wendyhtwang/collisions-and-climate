"""
Spot-check the aggregated PRISM county-year-month panel
(dataCSV/PRISM/prism_county_month.csv, built by 04_aggregate_daily_to_monthly.py)
against an independently-computed PRISM panel for the same counties/months,
pulled directly from Earth Engine.

Eventually also want to spot-check the ERA5 county-year-month panel (dataCSV/ERA5/era5_county_month.csv),
once that extraction/aggregation is complete.

METHOD -- deliberately mirrors the production pipeline exactly, not the
"quick" composite-then-reduce shortcut:
  1. For each sampled county x year, call the exact same per-day
     reduceRegions reduction 02_extract_prism_county.py uses (same
     reducer, SCALE_METERS, TILE_SCALE), via gee_extract_utils functions
     shared with production.
  2. Aggregate those daily county means to monthly IN PYTHON, by importing
     and calling 04_aggregate_daily_to_monthly.py's own
     aggregate_file_to_month() -- not by re-implementing the sum/mean
     logic here, and NOT by compositing the ImageCollection with
     .sum()/.mean() before reduceRegions. That composite-then-reduce
     shortcut is already documented as ~1-2% off for reasons not yet
     diagnosed (see the "Deliberately kept at DAILY resolution" note in
     02_extract_prism_county.py, and step 3 of verify_prism_gee_console.js)
     -- using it here would risk mistaking that known artifact for a bug
     in the production pipeline, or vice versa.
Reusing aggregate_file_to_month() also means this script's duplicate-row
handling matches production's exactly (see resolve_duplicate_rows() below).

KNOWN OPEN ISSUE -- Wisconsin county duplication:
02c/02d_diagnose_*_proposed.py found that 18 WI counties have every daily
PRISM row duplicated (byte-identical) in the 2020 and 2021 exports; root
cause not yet confirmed (TIGER geometry vs. reduceRegions/tileScale
interaction -- see those two files). 04_aggregate_daily_to_monthly.py
already tolerates this (drops confirmed byte-identical duplicates, raises
on anything else it can't explain). By default this script deliberately
FORCE-INCLUDES two of the affected GEOIDs (55001, 55003), one WI control
GEOID (55009), and Marion County, IL (17121 -- the county already
hand-validated in verify_prism_gee_console.js) alongside a random sample,
so this spot check also indicates whether that known duplication survives
into the final monthly output, not just the raw daily exports. Set
FORCE_INCLUDE_GEOIDS = [] to sample purely randomly instead.

OUTPUT: writes ONLY under dataCSV/PRISM/spot_check/ -- never touches
dataCSV/PRISM/prism_county_month.csv itself.

Requires Earth Engine credentials (earthengine-api). Not part of the
numbered pipeline -- run manually whenever the extraction/aggregation code
changes and you want an independent check. Written but not yet run against
live Earth Engine -- review before trusting the numbers, per CLAUDE.md's
peer-review convention, and start with the default (small) sample before
raising MAX_COUNTY_YEAR_COMBINATIONS.
"""

import importlib.util
import logging
from pathlib import Path

import ee
import numpy as np
import pandas as pd
from tqdm import tqdm

import gee_extract_utils as geeutil

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

EE_PROJECT = "collisions-and-climate"
PRISM_COLLECTION = "OREGONSTATE/PRISM/ANd"

# Match 02_extract_prism_county.py exactly -- any difference here would
# make a mismatch ambiguous (real bug vs. different reduction params).
# Eyal's suggestion said "some of the variables" -- trim this list for a
# faster/cheaper run if checking all 7 isn't needed.
BANDS = ["ppt", "tmean", "tmin", "tmax", "tdmean", "vpdmin", "vpdmax"]
SCALE_METERS = 4638.3
TILE_SCALE = 4

# --- county sample ---
N_RANDOM_COUNTIES = 10
SAMPLE_SEED = 42  # fixed so reruns pick the same random counties

# Always included regardless of the random sample -- see the "KNOWN OPEN
# ISSUE" note above. Set to [] to sample purely randomly.
FORCE_INCLUDE_GEOIDS = [
    "17121",  # Marion County, IL -- already hand-validated (verify_prism_gee_console.js)
    "55001",  # Adams County, WI -- known duplicated in 2020/2021 exports
    "55003",  # Ashland County, WI -- known duplicated in 2020/2021 exports
    "55009",  # Buffalo County, WI -- WI control, NOT flagged as duplicated
]

# --- years ---
# Spans the PRISM period and includes both years where the WI duplication
# was found (2020, 2021) plus the AN81->AN91 vintage boundary.
SPOT_CHECK_YEARS = [2000, 2010, 2020, 2021, 2025]

# Guardrail so a config typo (e.g. N_RANDOM_COUNTIES=500) doesn't turn this
# into an accidental full-scale run -- raise deliberately if a bigger spot
# check is genuinely wanted. Per CLAUDE.md: don't run large jobs without
# explicit approval.
MAX_COUNTY_YEAR_COMBINATIONS = 150

# Flag a comparison row if any variable's absolute percent difference
# exceeds this. Differences below this are treated as expected
# floating-point/rounding noise, per verify_prism_gee_console.js's
# console-check guidance ("first or second decimal place... worth
# investigating").
TOLERANCE_PCT = 0.5

REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = REPO_ROOT / "dataCSV" / "PRISM" / "spot_check"
RUN_TIMESTAMP = geeutil.run_timestamp()
LOG_PATH = OUTPUT_DIR / "logs" / f"prism_gee_spotcheck_{RUN_TIMESTAMP}.log"

AGGREGATE_MODULE_PATH = REPO_ROOT / "codePYTHON" / "04_aggregate_daily_to_monthly.py"


# ---------------------------------------------------------------------
# Reuse 04_aggregate_daily_to_monthly.py's own aggregation + dedup logic
# ---------------------------------------------------------------------

def load_aggregate_module():
    """
    Import 04_aggregate_daily_to_monthly.py by file path.

    A plain `import` won't work -- its filename starts with a digit, which
    isn't a legal Python module name -- but importing it this way (rather
    than copying its aggregation/dedup logic into this script) guarantees
    this spot check uses the exact same monthly-aggregation and
    duplicate-row handling as production, so any divergence found below
    reflects a real GEE-vs-pipeline difference, not a second, possibly
    inconsistent reimplementation of the same math.
    """
    spec = importlib.util.spec_from_file_location(
        "aggregate_daily_to_monthly", AGGREGATE_MODULE_PATH
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# ---------------------------------------------------------------------
# County sample
# ---------------------------------------------------------------------

def build_county_sample(counties):
    """
    Return a FeatureCollection of FORCE_INCLUDE_GEOIDS plus
    N_RANDOM_COUNTIES more, chosen via a seeded
    ee.FeatureCollection.randomColumn() so reruns are reproducible.
    """
    forced = counties.filter(ee.Filter.inList("geoid", FORCE_INCLUDE_GEOIDS))

    remaining = counties.filter(ee.Filter.inList("geoid", FORCE_INCLUDE_GEOIDS).Not())
    random_sample = (
        remaining.randomColumn("rand", seed=SAMPLE_SEED)
        .sort("rand")
        .limit(N_RANDOM_COUNTIES)
    )

    return forced.merge(random_sample)


# ---------------------------------------------------------------------
# Fetch: same per-day reduceRegions call the production pipeline uses,
# fetched one calendar month at a time (see CHANGE note below).
# ---------------------------------------------------------------------

def month_date_ranges(year):
    """Yield (start_date, end_date, label) ee.Date windows for each calendar month in `year`."""
    for month in range(1, 13):
        start = ee.Date.fromYMD(year, month, 1)
        end = start.advance(1, "month")
        yield start, end, f"{year}-{month:02d}"


def fetch_daily_county_chunk(sampled_counties, start_date, end_date):
    """
    Return daily county-mean PRISM rows for one date window, as a
    DataFrame with the same columns 02_extract_prism_county.py's exports
    have (ID_COLS + date + year + dataset_type + BANDS).

    CHANGE: originally fetched a full calendar year per getInfo() call
    (~365 chained daily reduceRegions calls). That hit Earth Engine's
    interactive-compute timeout ("Computation timed out", ~5 min
    wall-clock) once run against the real sample on Kodama -- chaining
    365 daily reduceRegions calls behind one synchronous getInfo() is too
    much for EE's interactive/value:compute endpoint, even though the
    same per-image reduction is exactly what the async Drive-export path
    production uses (02_extract_prism_county.py) handles fine at full
    CONUS scale. Fetching one calendar month at a time (~28-31 images
    instead of ~365) keeps each request small enough to finish before
    that timeout; see fetch_daily_county_panel() below for the per-year
    wrapper that chunks and concatenates these.
    """
    image_collection = (
        ee.ImageCollection(PRISM_COLLECTION)
        .filterDate(start_date, end_date)
        .select(BANDS)
    )

    daily_fc = geeutil.build_period_collection(
        image_collection=image_collection,
        counties=sampled_counties,
        bands=BANDS,
        scale_meters=SCALE_METERS,
        tile_scale=TILE_SCALE,
        extra_property_names=["dataset_type"],
    )

    selectors = geeutil.ID_COLS + ["date", "year", "dataset_type"] + BANDS
    features = daily_fc.select(selectors).getInfo()["features"]
    rows = [f["properties"] for f in features]

    daily = pd.DataFrame(rows)
    if daily.empty:
        return daily

    daily["date"] = pd.to_datetime(daily["date"])
    daily["year"] = daily["year"].astype(int)
    for col in ("geoid", "state_fips", "county_fips"):
        daily[col] = daily[col].astype(str)

    return daily


def fetch_daily_county_panel(sampled_counties, year):
    """Return one calendar year's daily county-mean PRISM rows, fetched one month at a time."""
    month_frames = [
        fetch_daily_county_chunk(sampled_counties, start, end)
        for start, end, _ in month_date_ranges(year)
    ]
    return pd.concat(month_frames, ignore_index=True)


# ---------------------------------------------------------------------
# Compare to production output
# ---------------------------------------------------------------------

def compare_to_production(spot_check_monthly, aggregate_module):
    """
    Merge the GEE-computed spot-check panel against the production
    dataCSV/PRISM/prism_county_month.csv on geoid/year/month, and compute
    absolute + percent differences for every aggregated variable.

    Reports (but doesn't silently drop) county-months present on one side
    only -- e.g. a sampled county-year not yet extracted in production, or
    vice versa -- rather than letting an outer-join gap quietly disappear.
    """
    prod_path = aggregate_module.OUTPUT_DIR / aggregate_module.OUTPUT_FILENAME
    if not prod_path.exists():
        raise FileNotFoundError(
            f"Production monthly file not found at {prod_path} -- run "
            "04_aggregate_daily_to_monthly.py first."
        )

    id_cols = aggregate_module.ID_COLS
    dtype_map = {c: str for c in id_cols}
    production = pd.read_csv(prod_path, dtype=dtype_map)

    key_cols = id_cols + ["year", "month"]
    compare_cols = (
        [f"{v}_total" for v in aggregate_module.SUM_VARS]
        + [f"{v}_mean" for v in aggregate_module.MEAN_VARS]
    )

    merged = spot_check_monthly.merge(
        production[key_cols + compare_cols],
        on=key_cols,
        how="outer",
        suffixes=("_gee", "_prod"),
        indicator=True,
    )

    gee_only = merged[merged["_merge"] == "left_only"]
    prod_only = merged[merged["_merge"] == "right_only"]
    if not gee_only.empty:
        print(
            f"\nNote: {len(gee_only)} sampled county-month(s) have a GEE "
            "spot-check value but no matching row in production output "
            "(not yet extracted/aggregated there?):"
        )
        print(gee_only[key_cols].to_string(index=False))
    if not prod_only.empty:
        print(
            f"\nNote: {len(prod_only)} sampled county-month(s) exist in "
            "production but returned no GEE spot-check row (unexpected -- "
            "investigate before trusting this comparison)."
        )

    both = merged[merged["_merge"] == "both"].copy()

    for col in compare_cols:
        gee_col, prod_col = f"{col}_gee", f"{col}_prod"
        abs_diff_col, pct_diff_col = f"{col}_abs_diff", f"{col}_pct_diff"
        both[abs_diff_col] = (both[gee_col] - both[prod_col]).abs()
        # Percent difference is unstable/misleading near zero (e.g. a
        # near-zero monthly ppt_total, or a temperature mean near 0degC) --
        # leave it NaN there rather than reporting a meaningless huge
        # percentage; the abs_diff column still shows the real-units gap.
        near_zero = both[prod_col].abs() < 1e-6
        both[pct_diff_col] = np.where(
            near_zero, np.nan, 100 * both[abs_diff_col] / both[prod_col].abs()
        )

    pct_diff_cols = [f"{c}_pct_diff" for c in compare_cols]
    both["max_pct_diff"] = both[pct_diff_cols].max(axis=1, skipna=True)
    both["flagged"] = both["max_pct_diff"] > TOLERANCE_PCT

    return both.drop(columns="_merge").reset_index(drop=True)


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    geeutil.setup_logging(LOG_PATH)
    geeutil.initialize_earth_engine(EE_PROJECT)

    aggregate_module = load_aggregate_module()

    n_combinations = (N_RANDOM_COUNTIES + len(FORCE_INCLUDE_GEOIDS)) * len(SPOT_CHECK_YEARS)
    if n_combinations > MAX_COUNTY_YEAR_COMBINATIONS:
        raise ValueError(
            f"{n_combinations} county-year combinations requested, over the "
            f"{MAX_COUNTY_YEAR_COMBINATIONS} guardrail -- this script is meant "
            "for a small spot check, not a full-scale extraction. Reduce "
            "N_RANDOM_COUNTIES/SPOT_CHECK_YEARS, or raise "
            "MAX_COUNTY_YEAR_COMBINATIONS deliberately if a bigger spot "
            "check is genuinely wanted."
        )

    all_counties = geeutil.get_counties()
    sampled_counties = build_county_sample(all_counties)

    sampled_geoids = sorted(sampled_counties.aggregate_array("geoid").getInfo())
    logging.info(
        "Spot-checking %d counties x %d years (%s) -- GEOIDs: %s",
        len(sampled_geoids), len(SPOT_CHECK_YEARS), SPOT_CHECK_YEARS, sampled_geoids,
    )

    # Flat list of (year, start, end) month-chunks across all SPOT_CHECK_YEARS,
    # so the progress bar reflects the actual unit of work (one getInfo()
    # call per month, not per year -- see fetch_daily_county_chunk()'s
    # CHANGE note for why a whole year in one call times out).
    month_chunks = [
        (year, start, end)
        for year in SPOT_CHECK_YEARS
        for start, end, _label in month_date_ranges(year)
    ]

    daily_frames = []
    for _year, start, end in tqdm(month_chunks, desc="Fetching GEE daily panels", unit="month"):
        daily_frames.append(fetch_daily_county_chunk(sampled_counties, start, end))

    daily = pd.concat(daily_frames, ignore_index=True)
    logging.info("Fetched %d daily county-day rows from Earth Engine.", len(daily))

    # Same dedup handling production uses on its exported CSVs -- raises on
    # genuine conflicts, drops confirmed byte-identical duplicates (relevant
    # for the WI GEOIDs forced into the sample above).
    duplicate_mask = daily.duplicated(subset=["geoid", "date"], keep=False)
    if duplicate_mask.any():
        daily = aggregate_module.resolve_duplicate_rows(
            daily, duplicate_mask, Path(f"gee_spotcheck_{RUN_TIMESTAMP}")
        )

    spot_check_monthly = aggregate_module.aggregate_file_to_month(daily)
    spot_check_monthly = spot_check_monthly.sort_values(
        aggregate_module.ID_COLS + ["year", "month"]
    ).reset_index(drop=True)

    spot_check_path = OUTPUT_DIR / f"prism_gee_spotcheck_{RUN_TIMESTAMP}.csv"
    spot_check_monthly.to_csv(spot_check_path, index=False)
    logging.info("Saved GEE-computed spot-check panel to: %s", spot_check_path)

    comparison = compare_to_production(spot_check_monthly, aggregate_module)
    comparison_path = OUTPUT_DIR / f"prism_gee_spotcheck_comparison_{RUN_TIMESTAMP}.csv"
    comparison.to_csv(comparison_path, index=False)
    logging.info("Saved comparison to: %s", comparison_path)

    flagged = comparison[comparison["flagged"]]
    print(
        f"\n{len(comparison)} county-month(s) compared; {len(flagged)} flagged "
        f"(max percent difference across variables > {TOLERANCE_PCT}%)."
    )
    if not flagged.empty:
        print("\nFlagged rows:")
        print(
            flagged[aggregate_module.ID_COLS + ["year", "month", "max_pct_diff"]]
            .to_string(index=False)
        )
    else:
        print(
            "No rows exceeded the tolerance -- production output matches the "
            "independent GEE computation for this sample."
        )


if __name__ == "__main__":
    main()
