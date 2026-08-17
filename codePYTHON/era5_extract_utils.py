"""
Shared ERA5-Land-specific extraction logic used by both the small-scale
test (03a_test_era5_extract.py) and full-scale (04a_extract_era5_county.py)
extraction scripts -- 03 exists specifically to validate this logic at
small scale before 04 runs it at full CONUS scale, so the two need to run
the exact same code, not two independently-maintained copies of it.

Deliberately ERA5-specific (unlike gee_extract_utils.py, which is
dataset-agnostic): unit conversions and derived-band computation live
here; general Earth Engine mechanics (auth, county reduction, export,
monitoring, and the generic build_year_image_collection() assembly step)
stay in gee_extract_utils.py.
"""

import ee

ERA5_COLLECTION = "ECMWF/ERA5_LAND/DAILY_AGGR"

# Raw bands read from the collection before derived-band preprocessing.
RAW_BANDS = [
    "temperature_2m",
    "temperature_2m_min",
    "temperature_2m_max",
    "dewpoint_temperature_2m",
    "skin_temperature",
    "u_component_of_wind_10m",
    "v_component_of_wind_10m",
    "snow_depth",
    "snowfall_sum",
    "surface_pressure",
    "total_precipitation_sum",
]

# Final band names after unit conversion / derived-band computation (see
# add_derived_bands() below for the reasoning behind each choice).
FINAL_BANDS = [
    "tmean_c",
    "tmin_c",
    "tmax_c",
    "dewpoint_c",
    "skin_temp_c",
    "wind_speed_10m",
    "snow_depth",
    "snowfall_mm",
    "surface_pressure",
    "precip_mm",
]


def add_derived_bands(image):
    """
    Convert temperature bands Kelvin -> Celsius, precip/snowfall
    meters -> mm, and compute wind speed from the u/v components.
    """
    image = ee.Image(image)

    tmean_c = image.select("temperature_2m").subtract(273.15).rename("tmean_c")
    tmin_c = image.select("temperature_2m_min").subtract(273.15).rename("tmin_c")
    tmax_c = image.select("temperature_2m_max").subtract(273.15).rename("tmax_c")
    dewpoint_c = (
        image.select("dewpoint_temperature_2m").subtract(273.15).rename("dewpoint_c")
    )
    skin_temp_c = image.select("skin_temperature").subtract(273.15).rename("skin_temp_c")

    wind_speed_10m = (
        image.select("u_component_of_wind_10m")
        .pow(2)
        .add(image.select("v_component_of_wind_10m").pow(2))
        .sqrt()
        .rename("wind_speed_10m")
    )

    precip_mm = (
        image.select("total_precipitation_sum").multiply(1000).rename("precip_mm")
    )
    snowfall_mm = image.select("snowfall_sum").multiply(1000).rename("snowfall_mm")

    # addBands() on `image` preserves image-level metadata (including
    # system:time_start), so no explicit copyProperties() is needed.
    return image.addBands(
        [
            tmean_c, tmin_c, tmax_c, dewpoint_c, skin_temp_c,
            wind_speed_10m, precip_mm, snowfall_mm,
        ]
    )
