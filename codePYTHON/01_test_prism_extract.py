"""
Small-scale PRISM extraction test: IL/IN, 2020-21, county mean

Extracts daily county-level mean PRISM weather values for:
- Illinois and Indiana
- 2020 and 2021
- a few (of the 7) climate variables

Creates one Google Drive CSV export task per state/year pair
(2 states x 2 years = 4 files total).

CHANGE: refactored onto gee_extract_utils.py, the shared module now also
used by the full-scale 02_extract_prism_county.py and
03_extract_era5_county.py. This file's behavior is unchanged from before
the refactor (same counties, years, bands, scale, filenames, Drive
folder) -- it's kept around as the small, fast, already-validated-against-
the-GEE-console sanity check to rerun whenever gee_extract_utils.py
changes, before trusting it for a full-scale run.

After completion, move the CSV files to:
F:\\AnimalCollisionsWeatherData\\PRISM\\test
"""

import logging

import gee_extract_utils as geeutil

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

EE_PROJECT = "collisions-and-climate"

RUN_TIMESTAMP = geeutil.run_timestamp()

# Illinois = 17; Indiana = 18
STATE_FIPS = ["17", "18"]

YEARS = [2020, 2021]

PRISM_COLLECTION = "OREGONSTATE/PRISM/ANd"

# Start small. These can be expanded later -- see 02_extract_prism_county.py
# for the full 7-band version.
BANDS = ["ppt", "tmean", "tmin", "tmax"]

# PRISM's nominal pixel size is approximately 4.6 km.
SCALE_METERS = 4638.3
TILE_SCALE = 4

# Google Drive folder name, where the CSV will be exported.
DRIVE_FOLDER = "earth_engine_prism_test"

# How often (in seconds) to poll Earth Engine for export task status
# while the progress bar is running.
POLL_INTERVAL_SECONDS = 15


# ---------------------------------------------------------------------
# PRISM-specific: build one year's image collection
# ---------------------------------------------------------------------

def build_year_image_collection(year):
    """Return the PRISM ImageCollection for one calendar year, band-selected."""
    import ee  # local import: only needed here, keeps module-level imports light

    start_date = ee.Date.fromYMD(year, 1, 1)
    end_date = start_date.advance(1, "year")

    return (
        ee.ImageCollection(PRISM_COLLECTION)
        .filterDate(start_date, end_date)
        .select(BANDS)
    )


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    geeutil.initialize_earth_engine(EE_PROJECT)

    counties = geeutil.get_counties(state_fips_list=STATE_FIPS)

    # Small client-side check -- retrieves metadata only, not the full
    # extraction.
    county_count = counties.size().getInfo()
    logging.info("Selected %d counties.", county_count)

    tasks = []

    # Loop over each state (nested outside the year loop) so every
    # state/year combination is built and exported separately -- 2
    # states x 2 years = 4 tasks/files.
    for state_fips in STATE_FIPS:
        state_abbrev = geeutil.CONUS_STATE_ABBREVIATIONS[state_fips]
        state_counties = geeutil.filter_counties_by_state(counties, state_fips)

        for year in YEARS:
            logging.info("Building extraction for %s %d...", state_abbrev, year)

            image_collection = build_year_image_collection(year)
            annual_results = geeutil.build_period_collection(
                image_collection=image_collection,
                counties=state_counties,
                bands=BANDS,
                scale_meters=SCALE_METERS,
                tile_scale=TILE_SCALE,
                extra_property_names=["dataset_type"],
            )

            filename = f"prism_county_daily_{state_abbrev}_{year}_{RUN_TIMESTAMP}"
            task = geeutil.start_export(
                collection=annual_results,
                description=filename,
                drive_folder=DRIVE_FOLDER,
                filename=filename,
                selectors=geeutil.ID_COLS + ["date", "year", "dataset_type"] + BANDS,
            )
            tasks.append(task)

    logging.info("\nMonitoring export progress...")
    geeutil.monitor_export_tasks(tasks, poll_interval_seconds=POLL_INTERVAL_SECONDS)

    logging.info(
        "\nExports have finished.\nGoogle Drive folder: %s\n"
        "Move the CSV files to:\nF:\\AnimalCollisionsWeatherData\\PRISM\\test",
        DRIVE_FOLDER,
    )


if __name__ == "__main__":
    main()
