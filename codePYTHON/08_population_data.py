"""
Extract Census county-year (1981-2025) population estimates, 
to use as the collision-rate denominator. Does not extract any other variable 
(ex. demographics) besides population.

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

Open item to resolve before/while implementing: county FIPS codes are not
stable across 1980-2025 (an estimated 20 CONUS county FIPS codes have changed
b/w 1981-2025. e.g. Broomfield CO created 2001, Shannon SD ->
Oglala Lakota 2015, VA independent-city/county mergers). Need a
crosswalk/reconciliation step so panel keys match Charvi's and Nicole's
county-year datasets across the full period -- flag for Charvi before
finalizing.

Note on CT: the state adopted 9 planning regions (09110-09190) to replace the 
8 legacy counties (09001-09015, TIGER/2018/Counties, in the weather panel). Census's Vintage 
2022 population estimates (released 2023) are the using these planning regions. 
So 1981-2021 CT populationfrom Census sources should match the weather geometry fine, 
but 2022-2025 will not -- planning regions don't map 1:1 to legacy county boundaries, 
so there is no obvious/automatic crosswalk. 

Before finalizing, decide between: 
(a) an alternate CT source still reporting on legacy-county geography for 2022-2025, 
(b) a population-weighted areal apportionment of planning-region population back
onto the 8 counties, or 
(c) flagging 2022-2025 CT county population as unavailable/approximated 
in the data dictionary. Do not silently drop or silently relabel these rows.

STATUS: scaffolding only. No source has been queried, no output written.
Every function below is a stub (raise NotImplementedError) -- fill in
each TODO, and confirm the open items above, before running against the
network.
"""

import logging
from dataclasses import dataclass
from pathlib import Path

import pandas as pd
# import requests  # add to requirements.txt once implemented


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


@dataclass
class TestClass:


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
          estimate later superseded by an intercensal revision), keep
          only the row with the lower `priority` value (intercensal
          wins) -- decide this explicitly rather than silently dropping
          duplicates
        - reconcile county FIPS across vintages (boundary/code changes --
          see module docstring) before concatenating, not after
        - assert exactly one row per (geoid, year) across FULL_YEAR_RANGE
          before returning; log any gaps
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

    panel = build_population_panel(SOURCES)

    flagged = verify_state_totals_against_decennial(panel)
    if not flagged.empty:
        logging.warning(
            "%d state-year benchmark mismatch(es) -- see flagged output.",
            len(flagged),
        )

    # TODO: write panel to OUTPUT_DIR / "population_county_year_1981_2025.csv"
    # TODO: write flagged mismatches to
    #       OUTPUT_DIR / "population_state_total_review_flags.csv"
    # TODO: write/update variable documentation for Charvi's data
    #       dictionary (name, label, unit, source, notes -- per CLAUDE.md
    #       + task doc)


if __name__ == "__main__":
    main()
