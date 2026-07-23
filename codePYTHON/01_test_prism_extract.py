"""
Small-scale PRISM extraction test.

Extracts daily county-level mean PRISM weather values for:
- Illinois and Indiana
- 2020 and 2021
- a single variable

Creates one Google Drive CSV export task per year.
After completion, move the CSV files to:
F:\\AnimalCollisionsWeatherData\\PRISM\\test
"""

import ee

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

EE_PROJECT = "collisions-and-climate"

# Illinois = 17; Indiana = 18
STATE_FIPS = ["17", "18"]

YEARS = [2020, 2021]

PRISM_COLLECTION = "OREGONSTATE/PRISM/ANd"
COUNTY_COLLECTION = "TIGER/2018/Counties"

# Start small. These can be expanded later.
BANDS = [
    "ppt",
    "tmean",
    "tmin",
    "tmax",
]

# PRISM's nominal pixel size is approximately 4.6 km.
SCALE_METERS = 4638.3

# Google Drive folder name, where the CSV will be exported.
DRIVE_FOLDER = "earth_engine_prism_test"


# ---------------------------------------------------------------------
# Earth Engine setup
# ---------------------------------------------------------------------

def initialize_earth_engine() -> None:
    """Initialize Earth Engine, authenticating only if necessary."""
    try:
        ee.Initialize(project=EE_PROJECT)
    except Exception:
        ee.Authenticate()
        ee.Initialize(project=EE_PROJECT)

    print("Earth Engine initialized.")


# ---------------------------------------------------------------------
# Geography
# ---------------------------------------------------------------------

def get_test_counties() -> ee.FeatureCollection:
    """
    Return counties in Illinois and Indiana.

    Retains selected identifiers and county geometry.
    """
    counties = (
        ee.FeatureCollection(COUNTY_COLLECTION)
        .filter(ee.Filter.inList("STATEFP", STATE_FIPS))
        .select(
            propertySelectors=["GEOID", "STATEFP", "COUNTYFP", "NAME"],
            newProperties=["geoid", "state_fips", "county_fips", "county_name"],
        )
    )

    return counties


# ---------------------------------------------------------------------
# Daily extraction
# ---------------------------------------------------------------------

def extract_image_by_county(
    image: ee.Image,
    counties: ee.FeatureCollection,
) -> ee.FeatureCollection:
    """
    Calculate county-level spatial means for one PRISM daily image.

    Each resulting feature represents one county-day.
    """
    image = ee.Image(image)

    date = ee.Date(image.get("system:time_start")).format("YYYY-MM-dd")
    year = ee.Date(image.get("system:time_start")).get("year")

    county_stats = image.select(BANDS).reduceRegions(
        collection=counties,
        reducer=ee.Reducer.mean(),
        scale=SCALE_METERS,
        tileScale=4,
    )

    def add_date_fields(feature: ee.Feature) -> ee.Feature:
        return (
            ee.Feature(feature)
            .set("date", date)
            .set("year", year)
            .set("dataset_type", image.get("dataset_type"))
            .setGeometry(None)
        )

    return county_stats.map(add_date_fields)


def build_year_collection(
    year: int,
    counties: ee.FeatureCollection,
) -> ee.FeatureCollection:
    """
    Build a county-day FeatureCollection for one calendar year.
    """
    start_date = ee.Date.fromYMD(year, 1, 1)
    end_date = start_date.advance(1, "year")

    prism = (
        ee.ImageCollection(PRISM_COLLECTION)
        .filterDate(start_date, end_date)
        .select(BANDS)
    )

    # Map the county reduction over each daily image.
    nested_results = prism.map(
        lambda image: extract_image_by_county(image, counties)
    )

    # The map operation produces a collection of collections.
    # Flatten it into one county-day table.
    return ee.FeatureCollection(nested_results).flatten()


# ---------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------

def start_export(
    collection: ee.FeatureCollection,
    year: int,
) -> ee.batch.Task:
    """Start a CSV export to Google Drive."""
    filename = f"prism_county_daily_IL_IN_{year}"

    task = ee.batch.Export.table.toDrive(
        collection=collection,
        description=filename,
        folder=DRIVE_FOLDER,
        fileNamePrefix=filename,
        fileFormat="CSV",
        selectors=[
            "geoid",
            "state_fips",
            "county_fips",
            "county_name",
            "date",
            "year",
            "dataset_type",
            "ppt",
            "tmean",
            "tmin",
            "tmax",
        ],
    )

    task.start()
    return task


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:
    initialize_earth_engine()

    counties = get_test_counties()

    # Small client-side checks are appropriate here because they only
    # retrieve metadata, not the full extraction.
    county_count = counties.size().getInfo()
    print(f"Selected {county_count} counties.")

    for year in YEARS:
        print(f"Building extraction for {year}...")

        annual_results = build_year_collection(
            year=year,
            counties=counties,
        )

        task = start_export(
            collection=annual_results,
            year=year,
        )

        print(
            f"Started export for {year}. "
            f"Task ID: {task.id}"
        )

    print(
        "\nExports have been submitted to Earth Engine.\n"
        f"Google Drive folder: {DRIVE_FOLDER}\n"
        "After they finish, move the CSV files to:\n"
        r"F:\AnimalCollisionsWeatherData\PRISM\test"
    )


if __name__ == "__main__":
    main()