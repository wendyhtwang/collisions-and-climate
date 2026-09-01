"""
Extract Census county-year (1981-2025) population estimates,
to use as the collision-rate denominator. Does not extract any other
variable (ex. demographics) besides population.

Split from a single 08_population_data.py into 08a (this file, the
general county-level pull) + 08b_population_ct_towns.py (CT-specific
town-level reaggregation) once CT turned out to need a structurally
different fetch method, not just a different source URL -- see
SCRIPT_OVERVIEW.md's `a`/`b` numbering convention (same reason PRISM/ERA5
extraction split into `_county` vs `_wma` variants).

Sources, by period (task doc's fallback order: Census intercensal ->
ICPSR -> PI's raw pre-1990 file):
    - 2020-2025 : Census Population Estimates Program API, postcensal
                  (current vintage, not yet reconciled to the 2030 census)
    - 2010-2019 : Census intercensal county tables (final, revised)
    - 2000-2009 : Census intercensal county tables
    - 1990-1999 : Census intercensal county tables
    - 1981-1989 : Census intercensal county tables IF cleanly available;
                  else ICPSR harmonized county population series; else
                  escalate to PI per task doc for the pre-1990 raw file
    - 1980, 1990, 2000, 2010, 2020 decennial counts are pulled SEPARATELY;
      used only to verify state-level totals.
    - CT (all years, 09001-09015) : OVERRIDDEN by 08b_population_ct_towns.py's
      output rather than pulled directly here for 2022-2025 -- see the CT
      note below and the SOURCES list.

County FIPS codes are not stable across 1980-2025. RESOLVED (8/31/26):
pulled the Census Bureau's official "Substantial Changes to Counties and
County Equivalent Entities" decade pages directly and compiled the CONUS
+ DC, 1981-2025 list -- 8 rows (excluding CT, handled separately by 08b):
Cibola County NM (1981, split), La Paz County AZ (1983, split), Dade ->
Miami-Dade FL (1997, rename), Yellowstone NP/MT -> Gallatin+Park (1997,
merge_split -- dissolves into TWO targets, doesn't fit a clean crosswalk),
Broomfield County CO (2001, split), Clifton Forge city VA -> Alleghany
County (2001, merger), Bedford city VA -> Bedford County (2013, merger),
Shannon -> Oglala Lakota County SD (2015, rename). Populated (in draft
form -- see the file's own header) at dataCSV/Population/
fips_crosswalk_1980_2025.csv. RECOMMENDED APPROACH, implemented via
population_utils.py:
    1. Load the crosswalk table (population_utils.load_fips_crosswalk) --
       still needs a manual read-through of the actual Census pages to
       confirm the 8-row list is exhaustive, and 2 rows have an
       unverified parent-county FIPS code in their notes (Yuma AZ,
       Valencia NM) -- see the file itself before treating as final.
    2. Classify each entry (see population_utils.apply_fips_crosswalk):
         - pure rename/recode (same geography, new FIPS) -> trivial
           relabel to the 2018 FIPS
         - merger/absorption (old county folds entirely into a
           still-existing 2018 county) -> sum source populations under
           the 2018 FIPS
         - split/newly-created from PARTS of one or more source counties
           (e.g. Broomfield, Cibola, La Paz) -> no clean historical
           sub-county population exists to reallocate. Do NOT attempt
           fine-grained areal apportionment for a population DENOMINATOR
           -- flag those county-years as unavailable/approximated
           (population_utils.FLAG_COL, matching the *_review_flags.csv
           convention used elsewhere in codePYTHON/)
         - merge_split (old county dissolves into MULTIPLE targets, e.g.
           Yellowstone/MT) -> same flag-don't-fabricate principle as
           split, approached from the other direction
       Surface the short list of flagged county-years to Charvi + PI
       rather than deciding unilaterally, since it affects merge keys
       other RAs depend on.
    3. AUDIT ITEM, not yet done: check whether Charvi's collision data
       and Nicole's wildlife data (for AZ, NM, CO, MT, FL, VA, SD -- the
       affected states) already key to the post-change FIPS consistently,
       the same way the CT check below was done for collisions. Nothing
       has surfaced an actual problem in either dataset for these states
       yet -- this just hasn't been checked, unlike CT which was checked
       because an unrelated map assertion happened to surface it.

Note on CT: the state adopted 9 planning regions (09110-09190) to replace
the 8 legacy counties (09001-09015, TIGER/2018/Counties, in the weather
panel). Census's Vintage 2022 population estimates (released 2023) are
the first using these planning regions. So 1981-2021 CT population from
Census sources should match the weather geometry fine, but 2022-2025
will not -- planning regions don't map 1:1 to legacy county boundaries,
so there is no obvious/automatic crosswalk between the two AGGREGATIONS.

RESOLVED, see 08b_population_ct_towns.py: CT's counties were never an
operating government unit -- both the legacy 8 counties AND the 9
planning regions are just different aggregations of the same 169 towns,
and town identity/boundaries have been stable throughout. 08b pulls CT
population at the TOWN level for every year and aggregates up to the
legacy 8 counties using the pre-2022 town->county mapping, producing a
standalone CT county-year series for the full 1981-2025 span. This
script consumes 08b's output as a SOURCES entry (see below) that
overrides whatever this script's own Census-based fetch would have
returned for CT -- so this script's own fetch_* functions never need to
special-case CT themselves, and 08b's 1981-2021 output additionally
serves as a cross-check against this script's regular Census-sourced CT
rows for those years (see 08b's cross_check_against_direct_county_pull).

Also note (confirmed 8/31/26, see project memory: county-geometry-vintage):
Charvi's CT collision pipeline (VehicleCollisionsDataRepo/codeSTATA/
Charvi - code WIP/CT WIP Charvi.do) already keys to the legacy 8 counties
throughout 1995-2025 via city_town_identifiers.dta -- confirmed by
inspecting the .dta directly (8 distinct county_fips values, 09001-09015,
for state_fips == "09"). No collision-side fix was needed; this script's
CT handling exists purely because Census's OWN population product
changed vintage in 2022, not because of anything wrong elsewhere in the
project.

STATUS: scaffolding only. No source has been queried, no output written.
Every function below is a stub (raise NotImplementedError) -- fill in
each TODO, and confirm the open items above (especially the crosswalk
TEMPLATE's 2 example rows, which need FIPS-code verification), before
running against the network.
"""

import logging
from dataclasses import dataclass
from pathlib import Path

import pandas as pd
# import requests  # add to requirements.txt once implemented

from population_utils import FLAG_COL, apply_fips_crosswalk, load_fips_crosswalk, resolve_data_root


# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]

RAW_DIR = REPO_ROOT / "dataRAW" / "Population"
OUTPUT_DIR = REPO_ROOT / "dataCSV" / "Population"
LOG_DIR = OUTPUT_DIR / "logs"

# Match the ID column convention used by the weather pipeline
# (aggregation_utils.py / 06_build_derived_weather_vars.py) so this
# merges cleanly on geoid with Charvi's and Nicole's county-year data.
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]

CENSUS_API_KEY_ENV_VAR = "CENSUS_API_KEY"  # TODO: confirm where the key is stored/loaded from

# Decennial benchmark years for the state-total verification step
# (task doc: "Verify the series is consistent at state-level totals
# against Census decennial counts for 1980, 1990, 2000, 2010, and 2020").
DECENNIAL_BENCHMARK_YEARS = [1980, 1990, 2000, 2010, 2020]

FULL_YEAR_RANGE = range(1981, 2026)  # matches weather pipeline's 1981-2025

# TODO: populate this file from the Census Bureau's official change list
# -- the TEMPLATE alongside it has 2 example rows only, unverified FIPS
# codes flagged for confirmation. See population_utils.load_fips_crosswalk.
FIPS_CROSSWALK_PATH = OUTPUT_DIR / "fips_crosswalk_1980_2025.csv"

# 08b_population_ct_towns.py's output -- consumed as a SOURCES entry
# below (name="ct_town_reaggregation") that overrides this script's own
# CT rows. This script does not fetch CT directly; see module docstring.
CT_TOWN_REAGGREGATION_PATH = OUTPUT_DIR / "ct_population_county_from_towns.csv"
CT_STATE_FIPS = "09"


@dataclass
class PopulationSourceConfig:
    """One entry per data source/vintage feeding the combined series --
    mirrors the PRISM_CONFIG/ERA5_CONFIG dataclass pattern in
    06_build_derived_weather_vars.py so each source's fetch/parse logic
    stays isolated and swappable.
    """
    name: str            # e.g. "census_pep_postcensal"
    years: range          # years this source covers
    fetch_fn: str          # name of the fetch_* function below
    is_intercensal: bool     # True = final/revised; False = postcensal (provisional)
    priority: int              # lower = preferred when sources overlap on a year


# TODO: fill in real endpoints/URLs once confirmed
SOURCES = [
    PopulationSourceConfig(
        name="census_pep_postcensal",
        years=range(2020, 2026),
        fetch_fn="fetch_census_pep_api",
        is_intercensal=False,
        priority=2,
    ),
    PopulationSourceConfig(
        name="census_intercensal_2010s",
        years=range(2010, 2020),
        fetch_fn="fetch_census_intercensal",
        is_intercensal=True,
        priority=1,
    ),
    PopulationSourceConfig(
        name="census_intercensal_2000s",
        years=range(2000, 2010),
        fetch_fn="fetch_census_intercensal",
        is_intercensal=True,
        priority=1,
    ),
    PopulationSourceConfig(
        name="census_intercensal_1990s",
        years=range(1990, 2000),
        fetch_fn="fetch_census_intercensal",
        is_intercensal=True,
        priority=1,
    ),
    PopulationSourceConfig(
        name="census_intercensal_1980s",
        years=range(1981, 1990),
        fetch_fn="fetch_census_intercensal",
        is_intercensal=True,
        priority=1,
    ),
    # CT override: 08b_population_ct_towns.py's town-level reaggregation,
    # for ALL years (not just 2022-2025) -- priority=0 so it always wins
    # over whichever of the sources above also produced CT rows for a
    # given year. Only contains CT rows (state_fips == "09"); every other
    # state is untouched by this source. See build_population_panel's
    # TODO for how the override is applied (by geoid, not a blanket
    # state-level replace, so it can't accidentally clobber non-CT rows).
    PopulationSourceConfig(
        name="ct_town_reaggregation",
        years=FULL_YEAR_RANGE,
        fetch_fn="fetch_ct_town_reaggregation",
        is_intercensal=True,
        priority=0,
    ),
    # TODO: add an ICPSR fallback config here IF the 1980s Census
    # intercensal table doesn't hold up (task doc's second bullet), e.g.:
    # PopulationSourceConfig(name="icpsr_pre1990", years=range(1981, 1990),
    #                         fetch_fn="fetch_icpsr", is_intercensal=True,
    #                         priority=3),
]


# ---------------------------------------------------------------------
# Fetch functions -- one per source type, each returns a standardized
# DataFrame with ID_COLS + ["year", "population", "source", "is_intercensal"]
# ---------------------------------------------------------------------

def fetch_census_pep_api(config: PopulationSourceConfig) -> pd.DataFrame:
    """Pull postcensal county population estimates from the Census PEP API
    (api.census.gov/data/{year}/pep/population), one request per year in
    config.years.

    TODO:
        - confirm exact PEP API dataset/variable names for the current
          vintage (api.census.gov/data/{year}/pep/population/variables.html)
        - load the API key from CENSUS_API_KEY_ENV_VAR rather than
          hardcoding it
        - request all counties in one call per year (for=county:*) rather
          than looping counties individually
        - standardize output columns to ID_COLS + year/population/source
        - CT rows returned here (planning regions, 09110-09190, for
          2022+) are fine to leave in the output -- they get overridden
          by the ct_town_reaggregation source in build_population_panel,
          not filtered out here. Filtering here would just make this
          function CT-aware for no benefit.
    """
    raise NotImplementedError


def fetch_census_intercensal(config: PopulationSourceConfig) -> pd.DataFrame:
    """Pull one decade's intercensal county population table.

    TODO:
        - these are NOT all on the same modern JSON API -- 1990s/2000s
          may be API-accessible, 1980s is likely a flat-file download
          (census.gov/data/tables/time-series/demo/popest/1980s-county.html)
          -- confirm which per decade and branch accordingly
        - parse whatever format each decade ships in (fixed-width text,
          CSV, or XLSX depending on vintage) into ID_COLS + year/population
        - save the untouched raw download under
          dataRAW/Population/<source_name>/ with a source.txt (URL + date
          obtained), per CLAUDE.md convention
    """
    raise NotImplementedError


def fetch_icpsr(config: PopulationSourceConfig) -> pd.DataFrame:
    """Fallback for any period Census intercensal tables don't cleanly
    cover (task doc's second bullet). Only build this out if
    fetch_census_intercensal can't cover 1981-1989.

    TODO:
        - confirm which ICPSR study/series to use (harmonized county-year
          population, ideally already reconciled to consistent FIPS)
        - ICPSR requires an authenticated download -- confirm access
          (university subscription/login) before automating
    """
    raise NotImplementedError


def fetch_ct_town_reaggregation(config: PopulationSourceConfig) -> pd.DataFrame:
    """Load 08b_population_ct_towns.py's output
    (CT_TOWN_REAGGREGATION_PATH) -- NOT a network fetch. Pipeline
    ordering dependency: 08b must be run before this source can resolve;
    build_population_panel should raise a clear error (not a bare
    FileNotFoundError) if 08b hasn't been run yet.

    TODO:
        - read CT_TOWN_REAGGREGATION_PATH, already in ID_COLS +
          year/population/source schema per 08b's
          aggregate_towns_to_legacy_counties
        - assert every row has state_fips == CT_STATE_FIPS -- this
          source should NEVER contain non-CT rows; that would indicate
          08b's output got corrupted/mixed with something else
    """
    raise NotImplementedError


def fetch_decennial_benchmark(year: int) -> pd.DataFrame:
    """Pull actual decennial county population counts for one census
    year (1980, 1990, 2000, 2010, or 2020) -- used ONLY for the
    verification step below, never merged into the main output series.

    TODO:
        - Census decennial API (api.census.gov/data/{year}/dec/...) for
          2000/2010/2020; earlier years likely need historical tables
          instead
        - aggregate county counts to state totals here or in the verify
          step
        - for 2020: decide whether CT is represented as 8 counties or 9
          planning regions in the decennial product itself, and whether
          the panel's CT rows (post-crosswalk, always 8-county) need a
          matching state-total reaggregation for this one benchmark year
          -- flag rather than assume
    """
    raise NotImplementedError


# ---------------------------------------------------------------------
# Combine sources into a single county-year panel
# ---------------------------------------------------------------------

def build_population_panel(sources: list) -> pd.DataFrame:
    """Fetch every configured source and stack into one long county-year
    panel.

    TODO:
        - call each source's fetch_fn for its configured years
        - where two sources cover the same year (e.g. a postcensal
          estimate later superseded by an intercensal revision, or the
          ct_town_reaggregation override), keep only the row with the
          lower `priority` value -- decide this explicitly rather than
          silently dropping duplicates. Apply per (geoid, year), NOT per
          state, so the CT override only replaces CT's 8 geoids and
          never touches any other state's rows even though CT's source
          is configured for the FULL_YEAR_RANGE
        - load_fips_crosswalk(FIPS_CROSSWALK_PATH) and run
          apply_fips_crosswalk on the non-CT sources BEFORE applying the
          CT override above, not after -- CT's rows come pre-resolved
          from 08b and should not pass through the general crosswalk a
          second time
        - assert exactly one row per (geoid, year) across FULL_YEAR_RANGE
          before returning; log any gap (expected gaps: "split"-type
          FLAG_COL rows from apply_fips_crosswalk, and any period the
          1980s/ICPSR fallback chain didn't resolve)
    """
    raise NotImplementedError


# ---------------------------------------------------------------------
# Verification: state-level totals vs. decennial counts
# ---------------------------------------------------------------------

def verify_state_totals_against_decennial(panel: pd.DataFrame) -> pd.DataFrame:
    """For each year in DECENNIAL_BENCHMARK_YEARS, sum the panel's county
    populations to state level and compare against
    fetch_decennial_benchmark(year)'s actual state totals.

    TODO:
        - compute % difference per state per benchmark year
        - flag (don't silently drop) any state/year pair exceeding some
          tolerance -- TODO: confirm acceptable tolerance with Nicole/PI;
          mirrors the review-flag pattern in
          prism_summary_by_county_review_flags.csv
        - CT specifically for the 2020 benchmark: make sure the
          comparison is county-set-consistent (see
          fetch_decennial_benchmark's TODO) before flagging a mismatch
          that's actually just a geography-vintage artifact, not a real
          data problem
        - return the flagged rows as a DataFrame; caller writes it out
          alongside the main output, same convention as
          *_review_flags.csv / *_incomplete_flagged.csv elsewhere in
          codePYTHON/
    """
    raise NotImplementedError


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    # TODO: set up logging to LOG_DIR (mirror geeutil.setup_logging /
    # aggregation_utils' pattern -- factor out a shared helper if one
    # doesn't already exist by the time this is implemented)
    logging.info(
        "Building county-year population panel, %d-%d...",
        FULL_YEAR_RANGE.start, FULL_YEAR_RANGE.stop - 1,
    )

    if not CT_TOWN_REAGGREGATION_PATH.exists():
        raise FileNotFoundError(
            f"{CT_TOWN_REAGGREGATION_PATH} not found -- run "
            "08b_population_ct_towns.py first; this script's CT rows "
            "depend on its output (see module docstring)."
        )

    panel = build_population_panel(SOURCES)

    flagged = verify_state_totals_against_decennial(panel)
    if not flagged.empty:
        logging.warning(
            "%d state-year benchmark mismatch(es) -- see flagged output.",
            len(flagged),
        )

    # TODO: also surface a count of FLAG_COL rows from apply_fips_crosswalk
    # (the "split"-type unavailable/approximated county-years) separately
    # from the decennial-benchmark flags above -- different cause, same
    # "don't silently drop" principle

    # TODO: write panel to OUTPUT_DIR / "population_county_year_1981_2025.csv"
    # TODO: write flagged mismatches to
    #       OUTPUT_DIR / "population_state_total_review_flags.csv"
    # TODO: write/update variable documentation for Charvi's data
    #       dictionary (name, label, unit, source, notes -- per CLAUDE.md
    #       + task doc)


if __name__ == "__main__":
    main()
