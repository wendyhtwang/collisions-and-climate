"""
PROPOSED / NOT YET RUN -- diagnostic only, follow-up to
02f_diagnose_get_counties_output_proposed.py.

02f confirmed the 18 previously-known-affected GEOIDs each have 2
features in geeutil.get_counties()'s output (vs 1 for the 5 control
GEOIDs) -- localizing the duplication to get_counties() itself, before
any image reduction runs.

But 02f also reported get_counties().size() == 3108 total, which is
arithmetically inconsistent with what was directly measured from the
actual 2020 PRISM export: that export has exactly 3,108 DISTINCT county
geoids (confirmed two independent ways -- monthly aggregation produced
exactly 3108*12 = 37,296 rows after deduplication, and the raw file's
total row count of 1,144,116 exactly equals 366*(3108+18), accounting for
18 counties being doubled every single day). If 18 of get_counties()'s
features are true duplicates on top of full CONUS+DC coverage, the TOTAL
should be 3,108 + 18 = 3,126, not 3,108 -- so either get_counties() is
missing roughly 18 counties it should have (a distinct, separate
problem), there are more duplicated GEOIDs than the 18 already found, or
the "~3,109" sanity-check baseline used in 02f was simply the wrong
number to expect. Guessing which isn't worth it when this is cheap to
just check directly.

This script resolves it exhaustively, without hand-picking GEOIDs:
computes get_counties()'s total feature count, its DISTINCT geoid count
(via aggregate_array("geoid").distinct().size()), and -- if those two
numbers differ -- lists every geoid whose feature count isn't exactly 1,
with its count. This is the full audit that 02c/02f's spot checks (a
hand-picked 23-county list) only approximated.

Read-only getInfo()/aggregate calls only -- doesn't export or write
anything. Slightly heavier than the prior diagnostics (operates over the
full ~3,100-3,200-feature collection instead of ~23 features), but still
far cheaper than any image reduction -- no scale/reducer/image involved.
"""

import ee

import gee_extract_utils as geeutil

EE_PROJECT = "collisions-and-climate"


def main():
    geeutil.initialize_earth_engine(EE_PROJECT)

    counties = geeutil.get_counties()

    total = counties.size().getInfo()
    n_distinct = ee.List(counties.aggregate_array("geoid")).distinct().size().getInfo()

    print(f"get_counties() total feature count:    {total}")
    print(f"get_counties() distinct geoid count:   {n_distinct}")
    print(f"Difference (extra duplicate features): {total - n_distinct}\n")

    if total == n_distinct:
        print(
            "No duplicates anywhere in get_counties() output -- this "
            "contradicts 02f's per-GEOID spot check, which found 2 "
            "features for all 18 previously-affected GEOIDs. Flag back "
            "before doing anything else; something changed between runs, "
            "or one of the two checks has a bug worth re-examining."
        )
        return

    # Pull every (geoid -> count) pair back client-side and report any
    # geoid whose count isn't exactly 1. One getInfo() round trip over
    # ~3,100-3,200 values is cheap.
    all_geoids = counties.aggregate_array("geoid").getInfo()
    counts = {}
    for geoid in all_geoids:
        counts[geoid] = counts.get(geoid, 0) + 1

    duplicated = {g: n for g, n in counts.items() if n != 1}
    print(f"{len(duplicated)} geoid(s) with a feature count other than 1:")
    for geoid, n in sorted(duplicated.items()):
        print(f"  {geoid}: {n} feature(s)")

    print(
        "\nCompare len(duplicated) against 18 (the previously-known WI "
        "count). If it's exactly 18 and matches the same GEOIDs already "
        "found: the 'total should be 3126' expectation was simply wrong "
        "somewhere (e.g. the true full CONUS+DC count from TIGER/2018 is "
        "actually 3090, not 3108, and the 3108 seen in the 2020 export "
        "was itself already inflated by these 18 duplicates on top of a "
        "3090 base -- worth re-deriving that baseline rather than "
        "assuming). If it's a different count or different GEOIDs: there "
        "are more affected counties than previously known, and the fix "
        "needs to account for all of them, not just the WI 18."
    )


if __name__ == "__main__":
    main()
