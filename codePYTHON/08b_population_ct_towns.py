"""
Reconstruct Connecticut county-year population under the 8 LEGACY
counties (09001-09015, the TIGER/2018 geography the rest of this project
uses), by pulling CT population at the TOWN level and re-aggregating up.

WHY THIS EXISTS. Connecticut replaced its 8 legacy counties with 9
planning regions (09110-09190) as its county-equivalent geography. The
switch reaches the DATA more broadly than the 2022 effective date
suggests: Vintage 2025 reports planning regions for every year it covers,
2020-2025. Planning regions do NOT nest inside legacy county boundaries, so
there is no region -> county crosswalk to apply: a region can straddle
two old counties. But CT's counties were never an operating government
unit, and BOTH schemes are just different groupings of the same 169
towns, whose boundaries have been stable throughout. So the fix is to go
down a level rather than sideways:

                     169 towns          <- atomic, stable
                    /          \\
        8 legacy counties    9 planning regions
          (what we need)     (what Census now publishes)

Towns partition the state exhaustively, and both the county lines and the
region lines are drawn ALONG town boundaries, so town -> legacy county is
a clean many-to-one mapping. That is exactly the nesting property that
region -> county lacks, and it is the whole reason this approach works.

SCOPE (narrowed 9/3/26 from the 8/31 scaffolding's 45 years):
  * PRODUCTION  2021-2025 -- the years Census reports CT on the wrong
    geography. 5 years x 8 counties = 40 rows.
    Originally scoped as 2022-2025, on the reasoning that the planning
    regions arrived with Vintage 2022. That was right about the GEOGRAPHY
    and wrong about the FILE: Vintage 2025 (cc-est2025) reports planning
    regions for EVERY year it covers, 2020-2025. 2020 is rescued because
    the 2010-2020 intercensal supplies it under legacy counties, but 2021
    exists only in the Vintage 2025 file -- so it fell through as 8
    missing county-years in the first full build.
  * VALIDATION  2015, 2018 -- years where Census still published legacy
    counties, so 08a's direct pull and this script's re-aggregation can
    be compared. Two years validate the town->county mapping as well as
    forty would; the mapping is static. Both pass within 0.1%.
  * TOTALS ONLY, no age. CT age shares are not recoverable for 2021-2025:
    Census publishes sub-county population as totals in every vintage,
    and CT DPH's town-level age data exists only for 2000, 2010,
    2011-2014 and 2020 -- not annually. Those 40 county-years of age
    shares are flagged missing by 08a, deliberately, and should not be
    modelled down.

STATUS: this design is Wendy's own call and has NOT been ratified by
Eyal. He was asked about CT on 9/1 and the answer that came back was
about the Dorn PDF and the 1980s; the CT question itself was never
resolved. Raise it before treating the CT series as settled.

Run:
    python 08b_population_ct_towns.py --validate-only   # cheap first pass
    python 08b_population_ct_towns.py
"""

from __future__ import annotations

import argparse
import logging
from datetime import date
from pathlib import Path

import pandas as pd
import requests

from population_utils import FIPS_DTYPES, ID_COLS, setup_logging

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]

RAW_DIR = REPO_ROOT / "dataRAW" / "Population" / "CT_towns"
OUTPUT_DIR = REPO_ROOT / "dataCSV" / "Population"
OUTPUT_PATH = OUTPUT_DIR / "ct_population_county_from_towns.csv"
REVIEW_FLAGS_PATH = OUTPUT_DIR / "ct_town_reaggregation_review_flags.csv"
LOG_DIR = OUTPUT_DIR / "logs"

TOWN_COUNTY_CROSSWALK_PATH = RAW_DIR / "ct_town_to_legacy_county_crosswalk.csv"

CT_STATE_FIPS = "09"
CT_EXPECTED_TOWNS = 169

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

PRODUCTION_YEARS = range(2021, 2026)
VALIDATION_YEARS = [2015, 2018]

# Town -> legacy county comes from a 2018 Gazetteer county-subdivision
# file: a plain tab-delimited text file whose GEOID is
# state(2) + county(3) + cousub(5), i.e. the legacy county is carried in
# the identifier itself. Chosen over CT DPH's town reports (which group
# towns by county in prose, requiring name matching) and over a TIGER
# shapefile (which would pull in geopandas for one lookup). Any vintage
# strictly before 2022 works; 2018 matches the project's county vintage.
GAZETTEER_URL = (
    "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2018_Gazetteer/"
    "2018_gaz_cousubs_09.txt"
)

# Sub-county (county subdivision) population estimates. SUMLEV 061 is the
# county-subdivision level -- filtering to it is what stops incorporated
# places, which nest INSIDE towns, from being double-counted.
#
# URL NAMING, confirmed 9/3/26 after a 404: the per-state files use an
# UNPADDED state FIPS -- sub-est2025_1.csv is Alabama, _6 California, so
# Connecticut is _9 and NOT _09. That is the opposite of the zero-padded
# convention every other Census file in this pipeline uses, and the
# opposite of how state_fips is carried everywhere else in this repo, so
# it is worth the explicit note.
#
# Candidates are tried in order and the first that returns 200 wins,
# because the padding and the vintage/directory naming both varied by
# decade and neither is documented anywhere reachable. The winning URL is
# logged and recorded in source.txt, so a run's provenance is exact even
# though the lookup is a fallback chain.
_SUBCOUNTY_ROOT = "https://www2.census.gov/programs-surveys/popest/datasets"

SUBCOUNTY_SOURCES = {
    # Vintage 2019 is the last 2010s subcounty vintage: 2010-2019.
    "sub-est2019": {
        "urls": [
            f"{_SUBCOUNTY_ROOT}/2010-2019/cities/totals/sub-est2019_{{state_unpadded}}.csv",
            f"{_SUBCOUNTY_ROOT}/2010-2019/cities/totals/sub-est2019_{{state}}.csv",
            f"{_SUBCOUNTY_ROOT}/2010-2020/cities/totals/sub-est2020_{{state_unpadded}}.csv",
            f"{_SUBCOUNTY_ROOT}/2010-2019/cities/totals/sub-est2019_all.csv",
        ],
        "years": range(2010, 2020),
    },
    "sub-est2025": {
        "urls": [
            f"{_SUBCOUNTY_ROOT}/2020-2025/cities/totals/sub-est2025_{{state_unpadded}}.csv",
            f"{_SUBCOUNTY_ROOT}/2020-2025/cities/totals/sub-est2025_{{state}}.csv",
            f"{_SUBCOUNTY_ROOT}/2020-2025/cities/totals/sub-est2025.csv",
        ],
        "years": range(2020, 2026),
    },
}

SUMLEV_COUNTY_SUBDIVISION = "061"
REQUEST_TIMEOUT = 120
USER_AGENT = "collisions-and-climate research pipeline (08b_population_ct_towns.py)"

# The town->county mapping is exact by construction, so any disagreement
# with Census's own county figures is a real defect, not estimation noise.
CROSS_CHECK_TOLERANCE = 0.001


# ---------------------------------------------------------------------
# Download helper
# ---------------------------------------------------------------------

def download_to_raw(url: str, filename: str = "", *, force: bool = False) -> Path:
    """Idempotent download into dataRAW/, with a source.txt, per CLAUDE.md."""
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    dest = RAW_DIR / (filename or url.rsplit("/", 1)[-1])

    if dest.exists() and not force:
        logging.debug("Cached: %s", dest.name)
        return dest

    logging.info("Downloading %s", url)
    response = requests.get(url, timeout=REQUEST_TIMEOUT, headers={"User-Agent": USER_AGENT})
    response.raise_for_status()
    dest.write_bytes(response.content)

    source_txt = RAW_DIR / "source.txt"
    line = f"{dest.name}\t{url}\tobtained {date.today().isoformat()}\n"
    existing = source_txt.read_text() if source_txt.exists() else ""
    if dest.name not in existing:
        source_txt.write_text(existing + line)

    return dest


def download_first_available(url_templates: list, *, state: str, force: bool = False) -> Path:
    """
    Try each candidate URL in order; return the first that downloads.

    Exists because Census's subcounty file naming is not consistent across
    decades -- the state suffix is unpadded in some vintages, the vintage
    year in the filename doesn't always match the directory, and none of
    it is documented anywhere machine-readable. Rather than hardcode one
    guess and 404, try the known shapes and record which one answered.
    """
    formatted = [
        template.format(state=state, state_unpadded=str(int(state)))
        for template in url_templates
    ]

    attempts = []
    for url in formatted:
        candidate_name = url.rsplit("/", 1)[-1]
        if (RAW_DIR / candidate_name).exists() and not force:
            logging.info("Cached: %s", candidate_name)
            return RAW_DIR / candidate_name
        try:
            return download_to_raw(url, force=force)
        except requests.HTTPError as exc:
            status = exc.response.status_code if exc.response is not None else "?"
            attempts.append(f"  {status}  {url}")
            logging.info("Not found (%s), trying next candidate: %s", status, candidate_name)

    raise RuntimeError(
        "None of the candidate URLs resolved:\n" + "\n".join(attempts) +
        "\n\nCensus moves and renames these files between vintages. Find the current one "
        "from the product page (census.gov/data/tables/time-series/demo/popest/) and add "
        "it to SUBCOUNTY_SOURCES."
    )


# ---------------------------------------------------------------------
# Town -> legacy county crosswalk (static; not re-derived per year)
# ---------------------------------------------------------------------

def load_town_to_legacy_county_crosswalk(*, force: bool = False) -> pd.DataFrame:
    """
    Build (or load) the static mapping of CT's 169 towns to their legacy
    county. One row per town: cousub_fips, town_name, county_geoid.

    This mapping predates and is unaffected by the 2022 change -- it is a
    one-time lookup, not something to re-derive per run or per year.
    """
    if TOWN_COUNTY_CROSSWALK_PATH.exists() and not force:
        crosswalk = pd.read_csv(TOWN_COUNTY_CROSSWALK_PATH, dtype=str)
        logging.info("Loaded cached town crosswalk (%d towns)", len(crosswalk))
        return _assert_crosswalk_shape(crosswalk)

    path = download_to_raw(GAZETTEER_URL, force=force)
    gazetteer = pd.read_csv(path, sep="\t", dtype=str, encoding="latin-1")
    gazetteer.columns = [c.strip().upper() for c in gazetteer.columns]

    if "GEOID" not in gazetteer.columns:
        raise ValueError(
            f"{path.name}: no GEOID column (found {list(gazetteer.columns)}). The Gazetteer "
            "layout changed; the town->county mapping depends on GEOID being "
            "state(2)+county(3)+cousub(5)."
        )

    gazetteer["GEOID"] = gazetteer["GEOID"].str.strip().str.zfill(10)
    crosswalk = pd.DataFrame({
        "cousub_fips": gazetteer["GEOID"].str[5:10],
        "county_geoid": gazetteer["GEOID"].str[:5],
        "town_name": gazetteer["NAME"].str.strip(),
    })

    # The Gazetteer includes non-town entries ("County subdivisions not
    # defined", water-only records). Keep only rows whose county is one of
    # the legacy 8 and that carry a real cousub code.
    crosswalk = crosswalk[crosswalk["county_geoid"].isin(CT_LEGACY_COUNTIES)]
    crosswalk = crosswalk[crosswalk["cousub_fips"] != "00000"]
    crosswalk = crosswalk.drop_duplicates(subset="cousub_fips").sort_values("cousub_fips")

    TOWN_COUNTY_CROSSWALK_PATH.parent.mkdir(parents=True, exist_ok=True)
    crosswalk.to_csv(TOWN_COUNTY_CROSSWALK_PATH, index=False)
    logging.info("Wrote %s (%d towns)", TOWN_COUNTY_CROSSWALK_PATH, len(crosswalk))

    return _assert_crosswalk_shape(crosswalk)


def _assert_crosswalk_shape(crosswalk: pd.DataFrame) -> pd.DataFrame:
    """
    169 towns, each mapped to exactly one of the 8 legacy counties.

    If the town count is off, the likeliest cause is that the source is
    already using the 9-planning-region scheme -- in which case the county
    codes would be 09110-09190 and this check fails loudly rather than
    producing a plausible-looking wrong answer.
    """
    counties = set(crosswalk["county_geoid"])
    unexpected = counties - set(CT_LEGACY_COUNTIES)
    if unexpected:
        raise ValueError(
            f"Town crosswalk contains non-legacy county code(s) {sorted(unexpected)}. "
            "If these are 09110-09190, the source is on the planning-region scheme and a "
            "pre-2022 vintage is needed instead."
        )

    if len(crosswalk) != CT_EXPECTED_TOWNS:
        logging.warning(
            "Town crosswalk has %d towns, expected %d. Investigate before trusting the "
            "aggregation -- a missing town silently undercounts its county.",
            len(crosswalk), CT_EXPECTED_TOWNS,
        )

    multi = crosswalk.groupby("cousub_fips")["county_geoid"].nunique()
    if (multi > 1).any():
        raise ValueError(
            f"Town(s) mapped to more than one county: {multi[multi > 1].index.tolist()}. "
            "Town->county must be many-to-one for this method to be valid."
        )

    logging.info(
        "Town crosswalk validated: %d towns -> %d legacy counties.",
        len(crosswalk), crosswalk["county_geoid"].nunique(),
    )
    return crosswalk


# ---------------------------------------------------------------------
# Town-level population
# ---------------------------------------------------------------------

def fetch_town_population(years, *, force: bool = False) -> pd.DataFrame:
    """
    Pull CT town-level population for `years` from Census sub-county
    estimates. Returns long: cousub_fips, year, population.

    Census sub-county files are TOTALS ONLY in every vintage -- there is
    no age detail at this level, which is the structural reason CT age
    shares stop in 2021 (see module docstring).
    """
    wanted = set(years)
    frames = []

    for name, spec in SUBCOUNTY_SOURCES.items():
        overlap = wanted & set(spec["years"])
        if not overlap:
            continue

        path = download_first_available(spec["urls"], state=CT_STATE_FIPS, force=force)
        raw = pd.read_csv(path, dtype=str, encoding="latin-1")
        raw.columns = [c.strip().upper() for c in raw.columns]

        # A national fallback file carries every state; keep only CT.
        if "STATE" in raw.columns:
            raw = raw[raw["STATE"].str.zfill(2) == CT_STATE_FIPS]

        towns = raw[raw["SUMLEV"].str.zfill(3) == SUMLEV_COUNTY_SUBDIVISION].copy()
        if towns.empty:
            raise ValueError(
                f"{path.name}: no SUMLEV {SUMLEV_COUNTY_SUBDIVISION} (county subdivision) rows. "
                f"Levels present: {sorted(raw['SUMLEV'].unique())}."
            )
        towns["cousub_fips"] = towns["COUSUB"].str.zfill(5)

        for year in sorted(overlap):
            col = f"POPESTIMATE{year}"
            if col not in towns.columns:
                logging.warning("%s: no %s column; skipping %d.", path.name, col, year)
                continue
            frames.append(pd.DataFrame({
                "cousub_fips": towns["cousub_fips"],
                "town_name": towns["NAME"].str.strip(),
                "year": year,
                "population": pd.to_numeric(towns[col], errors="coerce"),
                "town_source": name,
            }))

    if not frames:
        raise RuntimeError(f"No town-level population fetched for years {sorted(wanted)}")

    out = pd.concat(frames, ignore_index=True)
    logging.info(
        "Town population: %d rows, %d towns, years %s",
        len(out), out["cousub_fips"].nunique(), sorted(out["year"].unique()),
    )
    return out


# ---------------------------------------------------------------------
# Aggregate towns -> legacy counties
# ---------------------------------------------------------------------

def aggregate_towns_to_legacy_counties(
    town_population: pd.DataFrame, crosswalk: pd.DataFrame
) -> pd.DataFrame:
    """
    Join town population onto the crosswalk and sum to (county, year).

    Joins on cousub_fips, not town name -- name matching between sources
    is the predictable failure mode here (the same class of problem as the
    city_name normalization in Charvi's CT collision pipeline), and the
    FIPS code makes it unnecessary.
    """
    merged = town_population.merge(
        crosswalk[["cousub_fips", "county_geoid"]], on="cousub_fips", how="left"
    )

    unmatched = merged[merged["county_geoid"].isna()]
    if len(unmatched):
        towns = sorted(unmatched["town_name"].dropna().unique())[:15]
        raise ValueError(
            f"{unmatched['cousub_fips'].nunique()} town(s) in the population data have no "
            f"crosswalk entry, e.g. {towns}. Assigning them to no county would silently "
            "undercount. Resolve before aggregating."
        )

    county = (
        merged.groupby(["county_geoid", "year"], as_index=False)["population"].sum()
        .rename(columns={"county_geoid": "geoid"})
    )
    county["state_fips"] = CT_STATE_FIPS
    county["county_fips"] = county["geoid"].str[2:]
    county["county_name"] = county["geoid"].map(CT_LEGACY_COUNTIES)
    county["source"] = "ct_town_reaggregation"

    for year, group in county.groupby("year"):
        if len(group) != len(CT_LEGACY_COUNTIES):
            logging.warning(
                "%d: got %d counties, expected %d.", year, len(group), len(CT_LEGACY_COUNTIES)
            )

    logging.info(
        "Aggregated to %d county-year rows across %s.",
        len(county), sorted(county["year"].unique()),
    )
    return county[ID_COLS + ["year", "population", "source"]]


# ---------------------------------------------------------------------
# QA: cross-check against Census's own county figures
# ---------------------------------------------------------------------

def cross_check_against_direct_county_pull(reaggregated: pd.DataFrame) -> pd.DataFrame:
    """
    For VALIDATION_YEARS -- years when Census still published CT under the
    legacy 8 counties -- compare this script's re-aggregation against
    Census's own county-level figures.

    This is a free correctness check on the town->county mapping: both
    sides derive from the same underlying estimates, so they should agree
    to rounding. A gap here means the crosswalk is wrong, not that the
    estimates differ. Restricted to pre-2022 by construction: 2022+ has no
    independent county-level figure to compare against, which is the whole
    reason this script exists.
    """
    check_years = [y for y in VALIDATION_YEARS if y < 2022]
    subject = reaggregated[reaggregated["year"].isin(check_years)]
    if subject.empty:
        logging.info("No validation years present; skipping cross-check.")
        return pd.DataFrame()

    frames = []
    for name, spec in SUBCOUNTY_SOURCES.items():
        overlap = set(check_years) & set(spec["years"])
        if not overlap:
            continue
        path = download_first_available(spec["urls"], state=CT_STATE_FIPS)
        raw = pd.read_csv(path, dtype=str, encoding="latin-1")
        raw.columns = [c.strip().upper() for c in raw.columns]
        if "STATE" in raw.columns:
            raw = raw[raw["STATE"].str.zfill(2) == CT_STATE_FIPS]

        # SUMLEV 050 is the county level within the same file, so the
        # comparison uses one download rather than a second product.
        counties = raw[raw["SUMLEV"].str.zfill(3) == "050"].copy()
        if counties.empty:
            logging.warning("%s has no SUMLEV 050 county rows; cross-check skipped.", path.name)
            continue
        counties["geoid"] = counties["STATE"].str.zfill(2) + counties["COUNTY"].str.zfill(3)

        for year in sorted(overlap):
            col = f"POPESTIMATE{year}"
            if col not in counties.columns:
                continue
            frames.append(pd.DataFrame({
                "geoid": counties["geoid"],
                "year": year,
                "census_county_population": pd.to_numeric(counties[col], errors="coerce"),
            }))

    if not frames:
        logging.warning("No direct county figures available for the validation years.")
        return pd.DataFrame()

    direct = pd.concat(frames, ignore_index=True)
    comparison = subject.merge(direct, on=["geoid", "year"], how="inner")
    if comparison.empty:
        logging.warning(
            "Cross-check found no overlapping county-years. If Census reports CT under "
            "planning regions in these files, that is itself the finding."
        )
        return pd.DataFrame()

    comparison["pct_diff"] = (
        (comparison["population"] - comparison["census_county_population"]).abs()
        / comparison["census_county_population"].clip(lower=1)
    )
    flagged = comparison[comparison["pct_diff"] > CROSS_CHECK_TOLERANCE]

    if len(flagged):
        logging.error(
            "Cross-check FAILED for %d county-year(s) (tolerance %.1f%%). The town->county "
            "mapping is the prime suspect:\n%s",
            len(flagged), CROSS_CHECK_TOLERANCE * 100,
            flagged[["geoid", "year", "population", "census_county_population", "pct_diff"]]
            .to_string(index=False),
        )
    else:
        logging.info(
            "Cross-check passed: %d county-year(s) agree with Census's own county figures "
            "to within %.1f%%.", len(comparison), CROSS_CHECK_TOLERANCE * 100,
        )

    return flagged


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--validate-only", action="store_true",
                        help="Build and cross-check the validation years only; write nothing.")
    parser.add_argument("--force-download", action="store_true")
    args = parser.parse_args()

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    setup_logging(LOG_DIR / f"08b_ct_towns_{date.today().isoformat()}.log")

    crosswalk = load_town_to_legacy_county_crosswalk(force=args.force_download)

    years = sorted(set(VALIDATION_YEARS) if args.validate_only
                   else set(PRODUCTION_YEARS) | set(VALIDATION_YEARS))
    logging.info("Building CT county series from towns for %s", years)

    towns = fetch_town_population(years, force=args.force_download)
    county = aggregate_towns_to_legacy_counties(towns, crosswalk)

    flagged = cross_check_against_direct_county_pull(county)
    if len(flagged):
        flagged.to_csv(REVIEW_FLAGS_PATH, index=False)
        logging.info("Wrote %s (%d flagged rows)", REVIEW_FLAGS_PATH, len(flagged))

    if args.validate_only:
        logging.info("--validate-only: nothing written.")
        return

    production = county[county["year"].isin(PRODUCTION_YEARS)]
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    production.to_csv(OUTPUT_PATH, index=False)
    logging.info(
        "Wrote %s (%d rows, %d counties x %d years). 08a consumes this as its CT override.",
        OUTPUT_PATH, len(production), production["geoid"].nunique(),
        production["year"].nunique(),
    )


if __name__ == "__main__":
    main()
