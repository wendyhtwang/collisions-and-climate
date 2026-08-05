"""
PROPOSED / NOT YET RUN -- diagnostic only, follow-up to
02e_diagnose_county_geometry_parts_proposed.py.

Ruled out so far:
- 02c: TIGER/2018/Counties has exactly 1 raw feature per affected GEOID
  (checked via ee.Filter.eq("GEOID", geoid) directly against the raw
  collection).
- 02d: exactly 1 image exists for a known-affected date, and tileScale=4
  vs tileScale=1 produce identical duplicate output (2 rows for every
  affected county) from that single image -- not a tiling artifact.
- 02e: every affected county's raw TIGER geometry is a single-part
  Polygon, identical in structure to the unaffected control counties --
  not a multi-part/MultiPolygon geometry issue.

Gap in the investigation so far: 02c and 02e both checked the RAW
TIGER/2018/Counties collection, filtered directly by exact GEOID match.
02d (and every production script) instead builds its counties collection
via gee_extract_utils.get_counties() -- which filters the whole TIGER
collection by STATEFP (ee.Filter.inList), then renames properties via
.select(propertySelectors=..., newProperties=...). That pipeline was
never checked directly for duplicate output. If get_counties() itself
returns 2 features for these 18 GEOIDs (before any image reduction runs
at all), that fully explains 02d's results and relocates the bug from
"reduceRegions" to "get_counties()'s filter/select chain" -- which would
also mean the originally-proposed distinct("geoid") fix to get_counties()
may have been correct after all, just never tested against the right
object in 02c.

This script checks get_counties()'s actual output directly: total feature
count (sanity check against the expected ~3,109 CONUS counties) and
per-GEOID feature count for the same 18 affected + 5 control GEOIDs,
with NO image/reduceRegions involved at all.

Read-only getInfo() calls only -- doesn't export or write anything.
"""

import ee

import gee_extract_utils as geeutil

EE_PROJECT = "collisions-and-climate"

# Same GEOIDs checked in 02c/02d/02e.
AFFECTED_GEOIDS = [
    "55001", "55003", "55005", "55007", "55023", "55041", "55065", "55067",
    "55085", "55095", "55113", "55119", "55121", "55123", "55125", "55129",
    "55135", "55137",
]
CONTROL_GEOIDS = ["55009", "55011", "55013", "55015", "55017"]


def count_by_geoid(feature_collection, geoids):
    """Count how many features in `feature_collection` have each geoid.

    One getInfo() call for the whole filtered-down collection rather than
    one call per geoid -- cheaper, and avoids masking a bug where the
    per-geoid .filter().size() path behaves differently than reading
    back the full collection's properties directly.
    """
    subset = feature_collection.filter(ee.Filter.inList("geoid", geoids))
    features = subset.getInfo()["features"]
    counts = {}
    for f in features:
        geoid = f["properties"]["geoid"]
        counts[geoid] = counts.get(geoid, 0) + 1
    return counts


def main():
    geeutil.initialize_earth_engine(EE_PROJECT)

    counties = geeutil.get_counties()

    total = counties.size().getInfo()
    print(f"geeutil.get_counties() total feature count: {total}")
    print("  (sanity check -- expected ~3,109 for full CONUS + DC)\n")

    counts = count_by_geoid(counties, AFFECTED_GEOIDS + CONTROL_GEOIDS)

    print("Affected GEOIDs (duplicated in reduceRegions output, per 02d):")
    for geoid in AFFECTED_GEOIDS:
        n = counts.get(geoid, 0)
        flag = "  <-- duplicate in get_counties() output" if n > 1 else ""
        print(f"  {geoid}: {n} feature(s){flag}")

    print("\nControl GEOIDs:")
    for geoid in CONTROL_GEOIDS:
        n = counts.get(geoid, 0)
        flag = "  <-- unexpected duplicate!" if n > 1 else ""
        print(f"  {geoid}: {n} feature(s){flag}")

    print(
        "\nIf every affected GEOID shows >1 feature here (unlike 02c's "
        "raw-TIGER check, which showed exactly 1): the duplication is "
        "introduced by get_counties()'s STATEFP filter + property "
        "rename/select chain, not by reduceRegions. In that case the "
        "originally-proposed distinct('geoid') fix to get_counties() "
        "(see the diff shared earlier) is the right fix after all -- "
        "flag back to confirm before applying it, since it wasn't tested "
        "against this object before. If affected GEOIDs show exactly 1 "
        "feature here too: the duplication is happening somewhere inside "
        "reduceRegions itself, independent of the input collection -- a "
        "more unusual case that would need a different, likely "
        "GEE-support-level explanation."
    )


if __name__ == "__main__":
    main()
