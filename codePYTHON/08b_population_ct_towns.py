"""
Reconstructs Connecticut county-year population under the 8 legacy
counties (09001-09015, TIGER/2018/Counties -- see project memory:
county-geometry-vintage) for the FULL 1981-2025 span, by pulling CT
population at the TOWN (county-subdivision) level and aggregating up via
the pre-2022 town->county mapping.

WHY THIS IS ITS OWN SCRIPT rather than a CT branch inside
08a_population_county.py: Connecticut abolished county government as a
statistical geography in 2022; Census's Vintage 2022 population
estimates (released 2023) report CT under 9 planning regions
(09110-09190) instead of the 8 legacy counties. The planning regions do
NOT nest inside the legacy county boundaries, so there is no clean
region -> county crosswalk. But CT's counties were never an operating
government unit -- both the 8 legacy counties and the 9 planning regions
are just different aggregations of the same 169 towns, and town
identity/boundaries have been stable throughout both schemes. Going
through towns sidesteps the non-nesting problem entirely, but it's a
genuinely different fetch method (town-level source, different
crosswalk, different aggregation step) from everything else in 08a, not
just a different URL for the same shape of pull -- hence its own script,
same reasoning as the PRISM/ERA5 `_county` vs `_wma` split.

This script's output is a standalone CT-only county-year population
series covering ALL 45 years (not just the 4 affected ones,
2022-2025) -- 08a_population_county.py consumes it as a high-priority
override for CT's rows (see `PopulationSourceConfig(name=
"ct_town_reaggregation", priority=0, ...)` in 08a's SOURCES list).
Producing all 45 years, not just the affected 4, lets 1981-2021 double
as a cross-check against 08a's regular Census-sourced CT rows for those
years, where the two methods should agree closely -- see
cross_check_against_direct_county_pull below.

STATUS: scaffolding only. No source has been queried, no output written.
Every function below is a stub (raise NotImplementedError) -- fill in
each TODO before running against the network. In particular: the
town->legacy-county crosswalk (load_town_to_legacy_county_crosswalk) has
not been sourced yet -- this needs to happen before anything else here
is useful.
"""

import logging
from pathlib import Path

import pandas as pd

from population_utils import resolve_data_root


# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]

RAW_DIR = REPO_ROOT / "dataRAW" / "Population" / "CT_towns"
OUTPUT_DIR = REPO_ROOT / "dataCSV" / "Population"
OUTPUT_FILENAME = "ct_population_county_from_towns.csv"

# Same ID_COLS convention as 08a / the weather pipeline, so this merges
# cleanly wherever it's consumed.
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]

CT_STATE_FIPS = "09"

# CT's 8 legacy counties -- the target geography (matches the weather
# panel's TIGER/2018/Counties GEOIDs for CT). Names included for
# readability/logging only; geoid is the actual join key.
CT_LEGACY_COUNTIES = {
    "09001": "Fairfield",
    "09003": "Hartford",
    "09005": "Litchfield",
    "09007": "Middlesex",
    "09009": "New Haven",
    "09011": "New London",
    "09013": "Tolland",
    "09015": "Windham",
}

FULL_YEAR_RANGE = range(1981, 2026)  # matches 08a's FULL_YEAR_RANGE

# CT DPH's "Annual Town and County Population for Connecticut" page
# (portal.ct.gov/dph) confirmed to publish town-level estimates for
# 1996-2024 as of 8/31/26 (both PDF and Excel per year). TODO: confirm
# this is still current when implemented -- it's a living page, not a
# fixed archive.
DPH_TOWN_DATA_YEAR_RANGE = range(1996, 2025)

TOWN_COUNTY_CROSSWALK_PATH = RAW_DIR / "ct_town_to_legacy_county_crosswalk.csv"


# ---------------------------------------------------------------------
# Town -> legacy-county crosswalk (static, pre-2022, does not change by
# year -- this is NOT the same kind of "vintage" concern as the
# population figures themselves)
# ---------------------------------------------------------------------

def load_town_to_legacy_county_crosswalk() -> pd.DataFrame:
    """Load the static mapping of CT's 169 towns to their legacy county
    (one row per town: town_name, county_geoid). This mapping predates
    and is unaffected by the 2022 planning-region change -- it is a
    one-time lookup, not something to re-derive per run or per year.

    TODO:
        - source this from CT DPH's pre-2022 town-population
          documentation (e.g. the historical "poptowns" PDF reports,
          which already group towns by county -- a 2010-vintage example
          was found during research: portal.ct.gov/-/media/departments-
          and-agencies/dph/population/pdf/poptowns2010pdf.pdf) or a
          Census TIGER/Line county-subdivision file's COUNTYFP attribute
          for CT, any vintage strictly before 2022
        - assert exactly 169 towns, each mapped to exactly one of the 8
          CT_LEGACY_COUNTIES keys -- if the count is off, the source is
          probably already using the 9-planning-region scheme instead
        - save this as a static CSV under TOWN_COUNTY_CROSSWALK_PATH
          (not re-derived per run, unlike the population fetches below)
    """
    raise NotImplementedError


# ---------------------------------------------------------------------
# Town-level population, by source
# ---------------------------------------------------------------------

def fetch_ct_dph_town_population(year: int) -> pd.DataFrame:
    """Pull one year's town-level population from CT DPH's "Annual Town
    and County Population for Connecticut" page. Confirmed available for
    1996-2024 as of 8/31/26 (per DPH_TOWN_DATA_YEAR_RANGE).

    TODO:
        - portal.ct.gov/dph/health-information-systems--reporting/
          population/annual-town-and-county-population-for-connecticut
        - prefer the Excel file per year over the PDF where both exist
          (avoids a PDF-table-extraction step)
        - standardize output to columns: town_name, year, population
        - save the untouched raw download under RAW_DIR/<year>/ with a
          source.txt (URL + date obtained), per CLAUDE.md convention
    """
    raise NotImplementedError


def fetch_census_pep_county_subdivision(year: int) -> pd.DataFrame:
    """Pull one year's CT town-level ("county subdivision") population
    from the Census PEP API directly, for any year DPH's page doesn't
    cover (per DPH_TOWN_DATA_YEAR_RANGE, that's pre-1996 or post-2024).

    TODO:
        - confirm Census PEP's county-subdivision product actually
          covers CT for the specific gap years -- it may not exist for
          all of 1981-1995. If not, this period needs the same
          fallback-tier treatment as 08a's general 1981-1989 problem
          (ICPSR / PI's raw file) -- flag rather than leave silently
          missing, do not just skip those years
        - standardize output to columns: town_name, year, population
          (same schema as fetch_ct_dph_town_population's output, so both
          can feed the same aggregation step below without branching)
    """
    raise NotImplementedError


# ---------------------------------------------------------------------
# Aggregate towns -> legacy counties
# ---------------------------------------------------------------------

def aggregate_towns_to_legacy_counties(
    town_population: pd.DataFrame, crosswalk: pd.DataFrame
) -> pd.DataFrame:
    """Join town-level population onto the town->county crosswalk and
    sum to (county_geoid, year).

    TODO:
        - merge town_population with crosswalk on town_name -- validate
          every town in town_population matches exactly one crosswalk
          row; assert on unmatched towns rather than silently dropping
          them (per CLAUDE.md's "flag assumptions" principle). Town-name
          spelling/capitalization mismatches between DPH and PEP sources
          are the likely failure mode here, same class of issue as the
          city_name normalization in Charvi's CT collision pipeline.
        - groupby(["county_geoid", "year"])["population"].sum()
        - assert output has exactly 8 rows per year (one per
          CT_LEGACY_COUNTIES key) across FULL_YEAR_RANGE; log any gap
        - standardize to 08a's ID_COLS + ["year", "population", "source"]
          schema (source = "ct_town_reaggregation") so 08a's
          fetch_ct_town_reaggregation can consume this file directly
          with no further reshaping
    """
    raise NotImplementedError


# ---------------------------------------------------------------------
# Optional QA: cross-check against 08a's regular county-level CT pull
# ---------------------------------------------------------------------

def cross_check_against_direct_county_pull(
    reaggregated: pd.DataFrame, direct: pd.DataFrame
) -> pd.DataFrame:
    """For years where BOTH this script's town-reaggregation AND 08a's
    regular Census county-level pull exist for CT (i.e. 1981-2021, before
    the two are expected to diverge for structural reasons -- see module
    docstring), compare the two population series and flag any
    meaningful disagreement. This is a free correctness check on the
    town->county crosswalk itself: the two methods should agree closely
    wherever both exist, since they're ultimately built from the same
    underlying Census population estimates.

    TODO:
        - restrict the comparison to years < 2022 -- 2022-2025 are
          EXPECTED to differ (08a uses this script's output for those
          years, not an independent Census county-level pull), so
          comparing them would just flag the intentional fix as a
          discrepancy
        - compute % difference per (county_geoid, year); flag anything
          exceeding some tolerance -- TODO: confirm tolerance with
          Nicole/PI, same open question as 08a's decennial-benchmark
          check (verify_state_totals_against_decennial)
        - write flagged rows to
          OUTPUT_DIR / "ct_town_reaggregation_review_flags.csv", same
          *_review_flags.csv convention used elsewhere in codePYTHON/
    """
    raise NotImplementedError


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    # TODO: set up logging (see 08a's equivalent TODO -- factor out a
    # shared helper once one exists, rather than duplicating setup code
    # between 08a and this file)
    logging.info(
        "Reconstructing CT county-year population from town-level data, %d-%d...",
        FULL_YEAR_RANGE.start, FULL_YEAR_RANGE.stop - 1,
    )

    crosswalk = load_town_to_legacy_county_crosswalk()

    # TODO: for year in FULL_YEAR_RANGE: call fetch_ct_dph_town_population
    # if year in DPH_TOWN_DATA_YEAR_RANGE, else
    # fetch_census_pep_county_subdivision(year); concat all years into
    # one long town-year DataFrame
    town_population = None  # placeholder

    county_panel = aggregate_towns_to_legacy_counties(town_population, crosswalk)

    # TODO: load/compute 08a's direct CT pull for 1981-2021 and call
    # cross_check_against_direct_county_pull(county_panel, that_pull);
    # log/write any flagged years

    # TODO: write county_panel to OUTPUT_DIR / OUTPUT_FILENAME -- this is
    # the file 08a_population_county.py's fetch_ct_town_reaggregation
    # reads


if __name__ == "__main__":
    main()
