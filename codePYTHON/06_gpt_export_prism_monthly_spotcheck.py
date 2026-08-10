"""
Independent PRISM county-month spot check in Google Earth Engine.

Have GEE produce a small county-year-month panel from PRISM, 
then compare that panel with the production file created by the 
daily-extraction -> local-aggregation pipeline.

This script deliberately DOES NOT import gee_extract_utils.py and DOES NOT
call any production extraction or aggregation functions.

It independently:
1. selects a small, explicit set of counties;
2. reduces each PRISM daily image to county spatial means;
3. aggregates those daily county means to county-month values inside GEE;
4. exports one small monthly CSV to Google Drive.

The order of operations matches the production estimand:

    daily image -> county spatial mean -> monthly sum/mean

Do not replace that with ImageCollection.sum()/mean() followed by one spatial
reduction, because that can change the effective raster grid/resampling.

Workflow
--------
1. Review SPOT_CHECK_GEOIDS and SPOT_CHECK_YEARS below.
2. Run this script.
3. When the export finishes, download/sync the resulting CSV into:
       dataCSV/PRISM/spot_check/monthly_gee/raw/
4. Run 06b_compare_prism_monthly_spotcheck.py.
"""

from __future__ import annotations

import logging
import time
from datetime import datetime

import ee


# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

EE_PROJECT = "collisions-and-climate"
PRISM_COLLECTION = "OREGONSTATE/PRISM/ANd"
COUNTY_COLLECTION = "TIGER/2018/Counties"

# Match the production extraction parameters.
BANDS = ["ppt", "tmean", "tmin", "tmax", "tdmean", "vpdmin", "vpdmax"]
SCALE_METERS = 4638.3
TILE_SCALE = 4

# Explicit counties make the verification sample transparent and repeatable.
# They span different climates and regions. Edit as desired.
SPOT_CHECK_GEOIDS = [
    "17121",  # Marion County, IL
    "18039",  # Elkhart County, IN
    "06037",  # Los Angeles County, CA
    "04013",  # Maricopa County, AZ
    "12086",  # Miami-Dade County, FL
    "27053",  # Hennepin County, MN
    "48201",  # Harris County, TX
    "53033",  # King County, WA
]

# Five years across the PRISM period, including the 2020/2021 product-vintage
# boundary. All 12 months are exported for each selected year.
SPOT_CHECK_YEARS = [2000, 2010, 2020, 2021, 2025]

DRIVE_FOLDER = "earth_engine_prism_monthly_spotcheck"
RUN_TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
EXPORT_NAME = f"prism_spotcheck_monthly_{RUN_TIMESTAMP}"

POLL_SECONDS = 15


# ---------------------------------------------------------------------
# Earth Engine setup
# ---------------------------------------------------------------------

def initialize_earth_engine() -> None:
    """Initialize Earth Engine, authenticating only when necessary."""
    try:
        ee.Initialize(project=EE_PROJECT)
    except Exception:
        ee.Authenticate()
        ee.Initialize(project=EE_PROJECT)


# ---------------------------------------------------------------------
# Geography
# ---------------------------------------------------------------------

def get_spot_check_counties() -> ee.FeatureCollection:
    """
    Return the requested TIGER counties with standardized identifiers.

    The source and geometry match the production pipeline, but the code path is
    independent of gee_extract_utils.py.
    """
    counties = (
        ee.FeatureCollection(COUNTY_COLLECTION)
        .filter(ee.Filter.inList("GEOID", SPOT_CHECK_GEOIDS))
        .select(
            propertySelectors=["GEOID", "STATEFP", "COUNTYFP", "NAME"],
            newProperties=["geoid", "state_fips", "county_fips", "county_name"],
        )
    )
    return counties


# ---------------------------------------------------------------------
# Independent daily reduction and monthly aggregation
# ---------------------------------------------------------------------

def reduce_one_day_to_counties(
    image: ee.Image,
    counties: ee.FeatureCollection,
) -> ee.FeatureCollection:
    """Calculate county spatial means for one PRISM daily image."""
    image = ee.Image(image)
    date = ee.Date(image.get("system:time_start"))

    reduced = image.select(BANDS).reduceRegions(
        collection=counties,
        reducer=ee.Reducer.mean(),
        scale=SCALE_METERS,
        tileScale=TILE_SCALE,
    )

    def add_day_fields(feature: ee.Feature) -> ee.Feature:
        feature = ee.Feature(feature)
        return (
            feature
            .set("date", date.format("YYYY-MM-dd"))
            .set("dataset_type", image.get("dataset_type"))
            .setGeometry(None)
        )

    return reduced.map(add_day_fields)


def build_one_month_panel(
    counties: ee.FeatureCollection,
    year: int,
    month: int,
) -> ee.FeatureCollection:
    """
    Build one row per county for one year-month.

    This first reduces every daily image to county means and only then performs
    monthly temporal aggregation.
    """
    start = ee.Date.fromYMD(year, month, 1)
    end = start.advance(1, "month")

    daily_images = (
        ee.ImageCollection(PRISM_COLLECTION)
        .filterDate(start, end)
        .select(BANDS)
    )

    nested_daily = daily_images.map(
        lambda img: reduce_one_day_to_counties(ee.Image(img), counties)
    )
    daily_county = ee.FeatureCollection(nested_daily).flatten()

    def summarize_county(county: ee.Feature) -> ee.Feature:
        county = ee.Feature(county)
        geoid = county.get("geoid")
        rows = daily_county.filter(ee.Filter.eq("geoid", geoid))

        result = ee.Feature(
            None,
            {
                "geoid": geoid,
                "state_fips": county.get("state_fips"),
                "county_fips": county.get("county_fips"),
                "county_name": county.get("county_name"),
                "year": year,
                "month": month,
                "n_days": rows.size(),
                "dataset_types": ee.List(
                    rows.aggregate_array("dataset_type")
                ).distinct().sort().join(","),
            },
        )

        # Monthly precipitation total: sum daily county means.
        result = result.set("ppt_total", rows.aggregate_sum("ppt"))

        # Monthly means: average daily county means.
        for band in ["tmean", "tmin", "tmax", "tdmean", "vpdmin", "vpdmax"]:
            result = result.set(f"{band}_mean", rows.aggregate_mean(band))

        return result

    return counties.map(summarize_county)


def build_spot_check_panel(
    counties: ee.FeatureCollection,
) -> ee.FeatureCollection:
    """Merge all requested county-year-month panels into one collection."""
    panel = ee.FeatureCollection([])

    for year in SPOT_CHECK_YEARS:
        for month in range(1, 13):
            panel = panel.merge(build_one_month_panel(counties, year, month))

    return panel


# ---------------------------------------------------------------------
# Export and monitoring
# ---------------------------------------------------------------------

def export_panel(panel: ee.FeatureCollection) -> ee.batch.Task:
    """Export the small county-month verification panel to Google Drive."""
    selectors = [
        "geoid",
        "state_fips",
        "county_fips",
        "county_name",
        "year",
        "month",
        "n_days",
        "dataset_types",
        "ppt_total",
        "tmean_mean",
        "tmin_mean",
        "tmax_mean",
        "tdmean_mean",
        "vpdmin_mean",
        "vpdmax_mean",
    ]

    task = ee.batch.Export.table.toDrive(
        collection=panel,
        description=EXPORT_NAME,
        folder=DRIVE_FOLDER,
        fileNamePrefix=EXPORT_NAME,
        fileFormat="CSV",
        selectors=selectors,
    )
    task.start()
    return task


def monitor_task(task: ee.batch.Task) -> None:
    """Poll until the export reaches a terminal state."""
    terminal = {"COMPLETED", "FAILED", "CANCELLED"}
    previous_state = None

    while True:
        status = task.status()
        state = status["state"]

        if state != previous_state:
            logging.info("Task state: %s", state)
            previous_state = state

        if state in terminal:
            if state != "COMPLETED":
                raise RuntimeError(
                    f"Earth Engine export ended in state {state}: "
                    f"{status.get('error_message', '(no error message)')}"
                )
            logging.info("Export completed.")
            return

        time.sleep(POLL_SECONDS)


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
    )

    initialize_earth_engine()
    counties = get_spot_check_counties()

    found_geoids = sorted(counties.aggregate_array("geoid").getInfo())
    missing_geoids = sorted(set(SPOT_CHECK_GEOIDS) - set(found_geoids))
    if missing_geoids:
        raise ValueError(
            f"These requested GEOIDs were not found in {COUNTY_COLLECTION}: "
            f"{missing_geoids}"
        )

    if len(found_geoids) != len(set(found_geoids)):
        raise ValueError(
            "The selected TIGER collection contains duplicate county features "
            "for at least one requested GEOID. Choose a different verification "
            "county or investigate the source duplication before proceeding."
        )

    logging.info(
        "Building independent monthly panel: %d counties x %d years x 12 months "
        "= %d expected rows.",
        len(found_geoids),
        len(SPOT_CHECK_YEARS),
        len(found_geoids) * len(SPOT_CHECK_YEARS) * 12,
    )
    logging.info("GEOIDs: %s", found_geoids)
    logging.info("Years: %s", SPOT_CHECK_YEARS)

    panel = build_spot_check_panel(counties)
    task = export_panel(panel)

    logging.info("Started export '%s' (task ID: %s).", EXPORT_NAME, task.id)
    monitor_task(task)

    logging.info(
        "Download/sync the CSV from Google Drive folder '%s' into:\n"
        "  dataCSV/PRISM/spot_check/monthly_gee/raw/\n"
        "Then run 06b_compare_prism_monthly_spotcheck.py.",
        DRIVE_FOLDER,
    )


if __name__ == "__main__":
    main()
