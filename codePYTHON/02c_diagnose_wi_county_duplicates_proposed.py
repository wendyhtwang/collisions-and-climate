"""
PROPOSED / NOT YET RUN -- diagnostic only, not wired into the numbered
pipeline. Requires Earth Engine credentials (this was drafted without
running it -- no `ee` package or EE auth available in the environment
this was written in). Doesn't export or write anything; read-only
queries against the county FeatureCollection.

Background: 04_aggregate_daily_to_monthly.py's duplicate check found that
18 of 72 Wisconsin counties have every daily row duplicated, byte-for-byte
identical, in both the 2020 and 2021 full-CONUS PRISM exports -- same 18
GEOIDs both years, so not a random export glitch.

Purpose: localize WHERE the duplication is introduced, since the fix
differs depending on the answer:
- If TIGER/2018/Counties itself has >1 feature for an affected GEOID,
  the duplication is a source-data issue -- dedupe in get_counties()
  (cheap: ~3,109 features).
- If TIGER has exactly 1 feature per affected GEOID, the duplication is
  being introduced during/after reduceRegions (e.g. a tileScale
  interaction where a feature straddling an internal computation tile
  boundary gets processed more than once) -- dedupe would need to happen
  on the final per-year flattened county-day collection instead (more
  expensive: ~1.1M features/year), or the reduceRegions call itself needs
  adjusting (e.g. a different tileScale).

Run this on Kodama (or wherever EE is authenticated) and read the printed
counts before deciding which fix to apply.
"""

import ee

import gee_extract_utils as geeutil

EE_PROJECT = "collisions-and-climate"

# The 18 GEOIDs found duplicated in both the 2020 and 2021 PRISM exports
# (from dataRAW/PRISM/prism_county_daily_2020_*.csv and *_2021_*.csv).
AFFECTED_GEOIDS = [
    "55001",  # Adams
    "55003",  # Ashland
    "55005",  # Barron
    "55007",  # Bayfield
    "55023",  # Crawford
    "55041",  # Forest
    "55065",  # Lafayette
    "55067",  # Langlade
    "55085",  # Oneida
    "55095",  # Polk
    "55113",  # Sawyer
    "55119",  # Taylor
    "55121",  # Trempealeau
    "55123",  # Vernon
    "55125",  # Vilas
    "55129",  # Washburn
    "55135",  # Waupaca
    "55137",  # Waushara
]

# A handful of WI counties NOT flagged as duplicated in the 2020/2021
# exports, as a control group -- if these also come back >1, the "18
# affected" list from the duplicate check may be incomplete rather than
# the unaffected counties genuinely being clean.
CONTROL_GEOIDS = ["55009", "55011", "55013", "55015", "55017"]


def count_features_per_geoid(geoids, county_collection=geeutil.COUNTY_COLLECTION):
    """Return {geoid: feature_count} from the raw TIGER collection (pre-filter/select)."""
    counties = ee.FeatureCollection(county_collection)
    return {
        geoid: counties.filter(ee.Filter.eq("GEOID", geoid)).size().getInfo()
        for geoid in geoids
    }


def main():
    geeutil.initialize_earth_engine(EE_PROJECT)

    print(f"Checking feature counts in {geeutil.COUNTY_COLLECTION}...\n")

    print("Affected GEOIDs (duplicated in 2020/2021 PRISM exports):")
    for geoid, n in count_features_per_geoid(AFFECTED_GEOIDS).items():
        flag = "  <-- duplicate feature in TIGER" if n > 1 else ""
        print(f"  {geoid}: {n} feature(s){flag}")

    print("\nControl GEOIDs (NOT flagged as duplicated):")
    for geoid, n in count_features_per_geoid(CONTROL_GEOIDS).items():
        flag = "  <-- unexpected duplicate!" if n > 1 else ""
        print(f"  {geoid}: {n} feature(s){flag}")

    print(
        "\nIf every affected GEOID above shows >1 feature and every "
        "control GEOID shows 1: the duplication is in TIGER/2018/Counties "
        "itself -- dedupe in get_counties() (see the proposed diff for "
        "that function). If affected GEOIDs also show exactly 1 feature: "
        "the duplication is introduced later (reduceRegions/tiling), and "
        "get_counties() is the wrong place to fix it -- flag back before "
        "changing anything, since that needs a different approach."
    )


if __name__ == "__main__":
    main()
