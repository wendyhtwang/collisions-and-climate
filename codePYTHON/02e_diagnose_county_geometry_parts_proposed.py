"""
PROPOSED / NOT YET RUN -- diagnostic only, follow-up to
02d_diagnose_reduceregions_duplication_proposed.py.

02c ruled out duplicate TIGER features (every affected GEOID had exactly
1 feature). 02d ruled out both a multi-image-per-day issue (exactly 1
image found for the test date) and a tileScale artifact (tileScale=4 and
tileScale=1 produced identical output: 2 rows for every affected county,
1 row for every control county, from that single image).

That leaves the leading remaining hypothesis: reduceRegions() emits one
output row per disjoint polygon part when an input feature's geometry is
a MultiPolygon (e.g. an island, or a small disconnected fragment from how
the TIGER boundary was digitized) rather than merging all parts into one
reduced row. Wisconsin has substantial Great Lakes shoreline, and
multi-part TIGER county geometries (islands, boundary-digitizing
artifacts near water) are a mundane, plausible explanation for exactly
this kind of subset-of-counties duplication.

This script checks that directly: for each of the 18 affected + 5
control GEOIDs, look at the raw TIGER/2018/Counties geometry type and how
many disjoint polygon parts it has.

Read-only getInfo() calls only -- doesn't export or write anything.
"""

import ee

import gee_extract_utils as geeutil

EE_PROJECT = "collisions-and-climate"

# Same GEOIDs checked in 02c/02d.
AFFECTED_GEOIDS = [
    "55001", "55003", "55005", "55007", "55023", "55041", "55065", "55067",
    "55085", "55095", "55113", "55119", "55121", "55123", "55125", "55129",
    "55135", "55137",
]
CONTROL_GEOIDS = ["55009", "55011", "55013", "55015", "55017"]


def check_geometry_parts(geoids, county_collection=geeutil.COUNTY_COLLECTION):
    """Return {geoid: (geometry_type, n_parts)} from the raw TIGER collection."""
    counties = ee.FeatureCollection(county_collection)
    results = {}
    for geoid in geoids:
        feature = ee.Feature(counties.filter(ee.Filter.eq("GEOID", geoid)).first())
        geometry = feature.geometry()
        geom_type = geometry.type().getInfo()
        # .geometries() enumerates the constituent parts of a composite
        # geometry (MultiPolygon/GeometryCollection). A plain Polygon has
        # no such decomposition, so treat any non-composite type as 1 part
        # rather than calling .geometries() on it.
        if geom_type in ("MultiPolygon", "GeometryCollection"):
            n_parts = geometry.geometries().size().getInfo()
        else:
            n_parts = 1
        results[geoid] = (geom_type, n_parts)
    return results


def main():
    geeutil.initialize_earth_engine(EE_PROJECT)

    print(f"Checking geometry structure in {geeutil.COUNTY_COLLECTION}...\n")

    print("Affected GEOIDs (duplicated in reduceRegions output):")
    for geoid, (geom_type, n_parts) in check_geometry_parts(AFFECTED_GEOIDS).items():
        flag = "  <-- multi-part geometry" if n_parts > 1 else ""
        print(f"  {geoid}: {geom_type}, {n_parts} part(s){flag}")

    print("\nControl GEOIDs (NOT duplicated in reduceRegions output):")
    for geoid, (geom_type, n_parts) in check_geometry_parts(CONTROL_GEOIDS).items():
        flag = "  <-- unexpected multi-part geometry!" if n_parts > 1 else ""
        print(f"  {geoid}: {geom_type}, {n_parts} part(s){flag}")

    print(
        "\nIf every affected GEOID shows >1 part and every control GEOID "
        "shows exactly 1: multi-part geometry is confirmed as the cause. "
        "The fix would then belong in build_period_collection() (dedupe "
        "the final per-year flattened collection by geoid+date before "
        "export) rather than get_counties() -- collapsing a MultiPolygon "
        "into a single feature there could change which pixels get "
        "reduced together, so that needs a deliberate choice (e.g. "
        "confirm an area-weighted merge isn't needed instead of a plain "
        "duplicate-row drop) rather than a blind fix. If any affected "
        "GEOID shows exactly 1 part: this hypothesis is wrong too -- "
        "flag back before changing anything."
    )


if __name__ == "__main__":
    main()
