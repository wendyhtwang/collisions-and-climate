"""
PROPOSED / NOT YET RUN -- diagnostic only, follow-up to
02c_diagnose_county_duplication.py.

02c ruled out the "TIGER/2018/Counties has duplicate features" hypothesis:
every one of the 18 affected Wisconsin GEOIDs (and the 5 control GEOIDs)
came back with exactly 1 feature in TIGER/2018/Counties. So the
duplication observed in the 2020/2021 PRISM exports -- every daily row
for those 18 counties appearing twice, byte-identical -- is being
introduced downstream of get_counties(), not in the source county
geometry. The previously-proposed get_counties() distinct("geoid") fix
is therefore the wrong fix (nothing to dedupe there) and should NOT be
applied.

This script narrows down WHERE downstream it happens, by testing two
remaining candidates for a single known-affected day:

1. Does OREGONSTATE/PRISM/ANd actually contain more than one image for
   that date (e.g. a mosaic/tile structure where two images both cover
   the affected counties)? If ee.ImageCollection(...).filterDate(...)
   .size() is >1 for a date that should have exactly one daily
   composite, that alone explains it -- 02_extract_prism_county.py's
   .map() over the ImageCollection (via build_period_collection()) would
   reduce each image separately, doubling any county covered by both.

2. If there's exactly one image for the date, does reduceRegions'
   tileScale parameter change the duplicate count for the affected
   counties? Comparing tileScale=4 (current production setting, chosen
   for memory headroom -- see 02_extract_prism_county.py) against
   tileScale=1 on the SAME image/counties isolates whether the internal
   tiling is duplicating output rows for counties that straddle a tile
   boundary.

Read-only getInfo() calls only -- doesn't export or write anything, and
kept to a single test date (not a full year) to stay cheap.
"""

import ee

import gee_extract_utils as geeutil

EE_PROJECT = "collisions-and-climate"
PRISM_COLLECTION = "OREGONSTATE/PRISM/ANd"
BANDS = ["ppt", "tmean", "tmin", "tmax", "tdmean", "vpdmin", "vpdmax"]
SCALE_METERS = 4638.3

# An arbitrary date known to be duplicated in the 2020 export -- any date
# in 2020 or 2021 works, since the duplicate check found the issue on
# every day of both years for these 18 counties.
TEST_DATE = "2020-01-01"

# Same GEOIDs checked in 02c.
AFFECTED_GEOIDS = [
    "55001", "55003", "55005", "55007", "55023", "55041", "55065", "55067",
    "55085", "55095", "55113", "55119", "55121", "55123", "55125", "55129",
    "55135", "55137",
]
CONTROL_GEOIDS = ["55009", "55011", "55013", "55015", "55017"]


def check_images_per_day(date_str):
    """How many images does the collection have for this single date?"""
    start = ee.Date(date_str)
    end = start.advance(1, "day")
    collection = ee.ImageCollection(PRISM_COLLECTION).filterDate(start, end)
    return collection.size().getInfo(), collection


def check_reduce_output_counts(image, counties, tile_scale):
    """Run reduceRegions once and count output features per GEOID."""
    result = image.select(BANDS).reduceRegions(
        collection=counties,
        reducer=ee.Reducer.mean(),
        scale=SCALE_METERS,
        tileScale=tile_scale,
    )
    # One getInfo() call for the whole (small) result, rather than
    # looping a per-county getInfo() -- cheaper and avoids 23 round trips.
    features = result.getInfo()["features"]
    counts = {}
    for f in features:
        geoid = f["properties"]["geoid"]
        counts[geoid] = counts.get(geoid, 0) + 1
    return counts


def main():
    geeutil.initialize_earth_engine(EE_PROJECT)

    print(f"Checking {PRISM_COLLECTION} for {TEST_DATE}...")
    n_images, collection = check_images_per_day(TEST_DATE)
    print(f"  {n_images} image(s) found for this date.")
    if n_images != 1:
        print(
            "  <-- unexpected: expected exactly 1 daily composite image. "
            "This alone may explain the duplication -- each image would "
            "get reduced separately by build_period_collection()'s .map()."
        )

    image = ee.Image(collection.first())
    counties = geeutil.get_counties().filter(
        ee.Filter.inList("geoid", AFFECTED_GEOIDS + CONTROL_GEOIDS)
    )

    for tile_scale in (4, 1):
        print(f"\nreduceRegions with tileScale={tile_scale}:")
        counts = check_reduce_output_counts(image, counties, tile_scale)
        for geoid in AFFECTED_GEOIDS:
            n = counts.get(geoid, 0)
            flag = "  <-- duplicate output row" if n > 1 else ""
            print(f"  {geoid} (affected): {n} row(s){flag}")
        for geoid in CONTROL_GEOIDS:
            n = counts.get(geoid, 0)
            flag = "  <-- unexpected duplicate!" if n > 1 else ""
            print(f"  {geoid} (control):  {n} row(s){flag}")

    print(
        "\nIf tileScale=4 shows duplicates for affected counties but "
        "tileScale=1 doesn't: the tiling is the cause -- consider "
        "lowering tileScale (memory-usage tradeoff) or deduping the "
        "final flattened collection in build_period_collection() instead "
        "of get_counties(). If both tileScale settings show duplicates "
        "identically: the cause is upstream of reduceRegions (e.g. the "
        "image itself, or something in build_period_collection()'s "
        ".map()/.flatten() step) -- flag back before changing anything."
    )


if __name__ == "__main__":
    main()
