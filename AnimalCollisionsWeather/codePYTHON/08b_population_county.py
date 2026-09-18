"""
Builds the county-year population panel from Census sources: total resident
population plus 18 five-year age shares, keyed to TIGER/2018 county FIPS,
CONUS + DC, 1981-2025 (139,860 rows = 3,108 counties x 45 years). Feeds the
Phase 6 merge as the collision-rate denominator and as time-varying controls;
sex and race are collapsed, never broken out.

- Five stages, in order: fetch (native FIPS, never recodes) -> stack (never
  dedupes silently) -> crosswalk onto TIGER/2018 (the only stage that changes a
  geoid) -> CT overlay from 08a (already resolved, never crosswalked twice) ->
  validate (never mutates).
- One vintage per period, never spliced mid-decade: PE-02 1981-89, intercensal
  API 1990-99 (key required), co-est00int 2000-09, cc-est2020int 2010-20,
  cc-est2025 2020-25 (postcensal, provisional). 2020 comes from the intercensal
  file. The 1980s layout is confirmed against pe-02-1985.xls only.
- AGEGRP means three different things across those products and YEAR is a code
  whose layout differs per file, so both are worked out from the data rather
  than assumed -- see detect_agegrp_encoding, YEAR_CODE_RULES, SCRIPT_OVERVIEW.
- validate_panel checks MAGNITUDE, not just shape: an early build passed every
  structural check with its 2000s decade 70x wrong.

Run: python 08b_population_county.py [--probe-api] [--years ...] [--states ...]
"""

from __future__ import annotations

import argparse
import json
import logging
from dataclasses import dataclass
from datetime import date
from pathlib import Path

import pandas as pd
import requests

from population_utils import (
    AGE_FLAG_COL,
    AGE_SHARE_COLS,
    AGEGRP_TOTAL_CODE,
    CONUS_STATE_FIPS,
    FIPS_DTYPES,
    ID_COLS,
    POP_FLAG_COL,
    apply_fips_crosswalk,
    assert_agegrp_encoding,
    collapse_to_county_year_age,
    compute_age_shares,
    load_county_universe,
    load_fips_crosswalk,
    normalize_agegrp,
    reindex_to_county_universe,
    setup_logging,
    write_panel_outputs,
)

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]

RAW_DIR = REPO_ROOT / "dataRAW" / "Population"
OUTPUT_DIR = REPO_ROOT / "dataCSV" / "Population"
LOG_DIR = OUTPUT_DIR / "logs"

FIPS_CROSSWALK_PATH = OUTPUT_DIR / "fips_crosswalk_1980_2025.csv"
CT_TOWN_REAGGREGATION_PATH = OUTPUT_DIR / "ct_population_county_from_towns.csv"

OUTPUT_CSV = OUTPUT_DIR / "population_county_year_1981_2025.csv"
OUTPUT_DTA = OUTPUT_DIR / "population_county_year_1981_2025.dta"
REVIEW_FLAGS_CSV = OUTPUT_DIR / "population_review_flags.csv"

# Subset runs (--years / --states) write to their own filenames. Without this a
# 2-year, 1-state smoke test overwrites the production panel with 204 rows and
# nothing downstream can tell that it isn't the real thing.
SUBSET_PREFIX = "SUBSET_"

# The county universe comes from the weather panel, not from a hardcoded
# list -- see population_utils.load_county_universe. Take the GEOID SET
# from this file, not its year range: the PRISM CSVs in dataCSV are the
# 2020-2021 test-run slice, the full extraction lives on Kodama.
WEATHER_PANEL_PATH = REPO_ROOT / "dataCSV" / "PRISM" / "prism_county_month.csv"

FULL_YEAR_RANGE = range(1981, 2026)  # matches the weather pipeline
CT_STATE_FIPS = "09"
CT_LEGACY_GEOIDS = {"09001", "09003", "09005", "09007", "09009", "09011", "09013", "09015"}
CT_PLANNING_REGION_GEOIDS = {
    "09110", "09120", "09130", "09140", "09150", "09160", "09170", "09180", "09190",
}

# REQUIRED for the 1990s intercensal API path, and only for that path. Without
# a key the endpoint returns HTTP 200 carrying an HTML "Missing Key" page, not
# a 401, so _parse_api_json below checks the payload shape rather than the
# status code. Keys are free and instant:
# https://api.census.gov/data/key_signup.html. Set it in the shell, never
# commit it:
#     export CENSUS_API_KEY=...
CENSUS_API_KEY_ENV_VAR = "CENSUS_API_KEY"

API_KEY_HELP = (
    f"Set {CENSUS_API_KEY_ENV_VAR} in your environment. Keys are free and instant at "
    "https://api.census.gov/data/key_signup.html:\n"
    f"    export {CENSUS_API_KEY_ENV_VAR}=your_key_here\n"
    "Only the 1990-1999 source needs a key; every other period reads flat files. "
    "To build without it for now, restrict the run to 2000+ (--years 2000 ... )."
)

REQUEST_TIMEOUT = 120
USER_AGENT = "collisions-and-climate research pipeline (08b_population_county.py)"

CENSUS_FLATFILE_ROOT = "https://www2.census.gov/programs-surveys/popest"
CENSUS_API_ROOT = "https://api.census.gov/data"


# ---------------------------------------------------------------------
# YEAR code rules for the cc-est / co-est "-alldata" files
# ---------------------------------------------------------------------
# These files key time with a small integer, not a calendar year, and the
# leading codes are the decennial count and the estimates BASE -- two numbers
# for the same date. Keeping both double-counts the base year at each decade
# seam, so non-estimate codes are dropped here. `confirmed` records whether a
# mapping was checked against the file's layout PDF; where it is False,
# assert_period_continuity() is what protects the series.

# DESIGN: declare the file's YEAR SPAN, then derive the code->year map from the
# codes the file actually contains. Hardcoding an offset was tried first and was
# wrong for the 2010s (assumed 3->2010, actual 2->2010), filtering out every
# row. The span is statable from the product name; the number of leading
# census/base rows varies and is better read from the data.

@dataclass(frozen=True)
class YearCodeRule:
    first_year: int
    last_year: int
    confirmed: bool
    note: str = ""
    max_leading_nonestimate_codes: int = 2
    explicit_codes: tuple = ()   # ((code, year), ...) when inference can't work

    @property
    def n_years(self) -> int:
        return self.last_year - self.first_year + 1

    def code_to_year(self, observed_codes) -> dict:
        """Map the file's YEAR codes onto calendar years.

        Default: the highest `n_years` codes are the estimate series, anything
        below is a census/base row and is dropped -- true for cc-est2020int and
        cc-est2025. NOT true for co-est00int, whose 4/1/2010 census row sits at
        code 12, between 7/1/2009 and 7/1/2010, so that file supplies an
        explicit map. When `explicit_codes` is set it wins, and every code it
        names must exist in the file.
        """
        codes = sorted(int(c) for c in observed_codes)

        if self.explicit_codes:
            mapping = {int(c): int(y) for c, y in self.explicit_codes}
            missing = sorted(set(mapping) - set(codes))
            if missing:
                raise ValueError(
                    f"explicit YEAR mapping expects code(s) {missing}, which this file "
                    f"does not contain (it has {codes}). The layout has changed."
                )
            return mapping

        n_drop = len(codes) - self.n_years

        if n_drop < 0:
            raise ValueError(
                f"file has {len(codes)} YEAR codes {codes} but the declared span "
                f"{self.first_year}-{self.last_year} needs {self.n_years}. The span in "
                "YEAR_CODE_RULES is wrong, or this is not the file we think it is."
            )
        if n_drop > self.max_leading_nonestimate_codes:
            raise ValueError(
                f"file has {len(codes)} YEAR codes {codes} for a {self.n_years}-year span, "
                f"implying {n_drop} non-estimate rows -- more than the {self.max_leading_nonestimate_codes} "
                "expected (a census count and an estimates base). Read the layout PDF before "
                "assuming which codes to drop."
            )

        estimates = codes[n_drop:]
        return {code: self.first_year + i for i, code in enumerate(estimates)}


YEAR_CODE_RULES = {
    # EXPLICIT, because this file breaks the contiguous-tail assumption: code 1
    # is the 4/1/2000 base, codes 2-11 are 7/1/2000-2009, and a 4/1/2010 census
    # row sits BETWEEN those and code 13. Inferring "the top 11 codes are
    # 2000-2010" mapped the whole decade a year late. Verified against Illinois
    # 9/4/26. 2010 comes from cc-est2020int regardless, so codes 12-13 are
    # dropped here rather than mapped.
    "co-est00int": YearCodeRule(
        2000, 2009, confirmed=True,
        explicit_codes=tuple((code, 1998 + code) for code in range(2, 12)),
        note="explicit: codes 2-11 = 2000-2009; 1 (base), 12 (2010 census) "
             "and 13 (7/1/2010) dropped. Verified against IL, 9/4/26.",
    ),
    # CONFIRMED 9/3/26 against Illinois: 12 codes = 1 base row + 11 estimate
    # years, so codes 2-12 are 2010-2020. 2020 comes from HERE, not the
    # postcensal file -- this product reconciles through the 4/1/2020 census.
    "cc-est2020int": YearCodeRule(
        2010, 2020, confirmed=True,
        note="verified against IL 2010/2020 decennial counts, 9/3/26",
    ),
    # CONFIRMED 9/3/26: codes 1-7 = one base row plus six estimate years, so
    # codes 2-7 are 2020-2025. Verified on the 2020 overlap against
    # cc-est2020int (median difference 0.207%), ordinary revision noise rather
    # than the several-percent gap a one-year shift would leave.
    # assert_period_continuity() re-runs this check on every build.
    "cc-est2025": YearCodeRule(
        2020, 2025, confirmed=True,
        note="verified via the 2020 overlap against cc-est2020int, 9/3/26",
    ),
}


@dataclass
class PopulationSourceConfig:
    """One entry per data source/vintage feeding the combined series."""
    name: str
    years: range
    fetch_fn: str
    is_intercensal: bool
    priority: int              # lower wins where sources overlap on a year
    file_key: str = ""         # which YEAR_CODE_RULES entry applies
    url_template: str = ""
    api_base_year: int = 0     # for the intercensal API (1990 or 2000)


SOURCES = [
    PopulationSourceConfig(
        name="census_pe02_1980s",
        years=range(1981, 1990),
        fetch_fn="fetch_pe02_1980s",
        is_intercensal=True,
        priority=1,
        url_template=f"{CENSUS_FLATFILE_ROOT}/tables/1980-1990/counties/asrh/pe-02-{{year}}.xls",
    ),
    PopulationSourceConfig(
        name="census_intercensal_api_1990s",
        years=range(1990, 2000),
        fetch_fn="fetch_intercensal_api",
        is_intercensal=True,
        priority=1,
        api_base_year=1990,
    ),
    PopulationSourceConfig(
        name="census_intercensal_2000s",
        years=range(2000, 2010),
        fetch_fn="fetch_ccest_flatfile",
        is_intercensal=True,
        priority=1,
        file_key="co-est00int",
        url_template=f"{CENSUS_FLATFILE_ROOT}/datasets/2000-2010/intercensal/county/"
                     "co-est00int-alldata-{state}.csv",
    ),
    PopulationSourceConfig(
        name="census_intercensal_2010s",
        years=range(2010, 2021),  # through 2020 inclusive -- see YEAR_CODE_RULES
        fetch_fn="fetch_ccest_flatfile",
        is_intercensal=True,
        priority=1,
        file_key="cc-est2020int",
        url_template=f"{CENSUS_FLATFILE_ROOT}/datasets/2010-2020/intercensal/county/asrh/"
                     "cc-est2020int-alldata-{state}.csv",
    ),
    PopulationSourceConfig(
        name="census_postcensal_2020s",
        # Fetches 2020 as well as 2021-2025, DELIBERATELY. 2020 itself comes
        # from the intercensal source (higher priority), but the overlap gives
        # assert_period_continuity a year where two independent sources can be
        # compared. Do not narrow this back to 2021.
        years=range(2020, 2026),
        fetch_fn="fetch_ccest_flatfile",
        is_intercensal=False,
        priority=2,
        file_key="cc-est2025",
        url_template=f"{CENSUS_FLATFILE_ROOT}/datasets/2020-2025/counties/asrh/"
                     "cc-est2025-alldata-{state}.csv",
    ),
]


# ---------------------------------------------------------------------
# Download helper (idempotent, archives raw per CLAUDE.md)
# ---------------------------------------------------------------------

# Set from --force-download in main(); read by download_to_raw as the
# default whenever a call site doesn't pass force= explicitly. A module
# global rather than threading the flag through every fetcher signature,
# consistent with how this file already handles a handful of other
# CLI-wide switches (e.g. CENSUS_API_KEY_ENV_VAR).
FORCE_DOWNLOAD = False


def download_to_raw(url: str, source_name: str, filename: str = "", *, force: bool = False) -> Path:
    """Download `url` into dataRAW/Population/<source_name>/, skipping the fetch
    if the file is already cached, and recording provenance in source.txt.

    `force` (--force-download) re-downloads anyway -- use it if a cached file is
    suspected corrupt. The content check below only catches the "got an HTML
    error page" case, not a connection dropped mid-transfer.
    """
    dest_dir = RAW_DIR / source_name
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / (filename or url.rsplit("/", 1)[-1])

    if dest.exists() and not (force or FORCE_DOWNLOAD):
        logging.debug("Cached: %s", dest.name)
        return dest

    logging.info("Downloading %s", url)
    response = requests.get(url, timeout=REQUEST_TIMEOUT, headers={"User-Agent": USER_AGENT})
    response.raise_for_status()

    # A 2xx status is not proof the body is the file asked for: Census or a
    # proxy can serve an HTML error page with a 200, which then caches as if it
    # were data and surfaces later as something opaque like KeyError('YEAR').
    # A body starting with '<' is neither a CSV nor an .xls (which is a binary
    # zip/OLE blob), so catch that here.
    head = response.content[:200].lstrip()
    if head[:1] == b"<":
        raise RuntimeError(
            f"Downloading {url} returned HTTP {response.status_code} but the body looks "
            f"like HTML/XML, not data -- likely an error or rate-limit page served with a "
            f"200 status. First 200 bytes:\n{head[:200]!r}\n"
            "Not caching this. Re-run the fetch; pass --force-download if a bad copy of "
            "this file was already cached under this name from an earlier attempt."
        )

    dest.write_bytes(response.content)

    source_txt = dest_dir / "source.txt"
    line = f"{dest.name}\t{url}\tobtained {date.today().isoformat()}\n"
    existing = source_txt.read_text() if source_txt.exists() else ""
    if dest.name not in existing:
        source_txt.write_text(existing + line)

    return dest


# ---------------------------------------------------------------------
# Stage 1: fetch
# ---------------------------------------------------------------------

def _standardize(df: pd.DataFrame, config: PopulationSourceConfig) -> pd.DataFrame:
    """Every fetcher exits through here, so the contract is enforced once."""
    required = {"geoid", "year", "agegrp", "population"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"[{config.name}] fetcher returned no {sorted(missing)} column(s)")

    df = df.copy()
    df["geoid"] = df["geoid"].astype(str).str.zfill(5)
    df["state_fips"] = df["geoid"].str[:2]
    df["county_fips"] = df["geoid"].str[2:]
    df["year"] = df["year"].astype(int)
    df["agegrp"] = df["agegrp"].astype(int)
    df["population"] = pd.to_numeric(df["population"], errors="coerce")
    df["source"] = config.name
    df["is_intercensal"] = config.is_intercensal

    if "county_name" not in df.columns:
        df["county_name"] = pd.NA

    keep = ID_COLS + ["year", "agegrp", "population", "source", "is_intercensal"]
    return df[keep]


def fetch_ccest_flatfile(config: PopulationSourceConfig, states: list) -> pd.DataFrame:
    """Read a Census "-alldata" county characteristics file: one CSV per state,
    long on AGEGRP, wide on race/sex. Serves co-est00int, cc-est2020int and
    cc-est2025, which share a layout.

    Use `-alldata`, never `-agesex`: alldata is long with a clean AGEGRP key and
    5-year bins; agesex is wide with collapsed, partly overlapping groupings.
    """
    rule = YEAR_CODE_RULES[config.file_key]
    wanted_years = set(config.years)
    frames = []
    code_to_year = None

    for state in states:
        path = download_to_raw(
            config.url_template.format(state=state), config.name,
        )
        raw = pd.read_csv(path, dtype={"STATE": str, "COUNTY": str}, encoding="latin-1")
        raw.columns = [c.upper() for c in raw.columns]

        observed_codes = sorted(raw["YEAR"].astype(int).unique())
        try:
            mapping = rule.code_to_year(observed_codes)
        except ValueError as exc:
            raise ValueError(f"[{config.name}] state {state}: {exc}") from exc

        if code_to_year is None:
            code_to_year = mapping
            dropped = sorted(int(c) for c in set(observed_codes) - set(mapping))
            kept = sorted(mapping)
            logging.info(
                "[%s] YEAR codes %d-%d -> %d-%d; dropped %s (census/base rows).",
                config.name, kept[0], kept[-1],
                min(mapping.values()), max(mapping.values()),
                dropped or "none",
            )
        elif mapping != code_to_year:
            raise ValueError(
                f"[{config.name}] state {state} implies a different YEAR mapping than "
                f"earlier states ({mapping} vs {code_to_year}). Files in one product family "
                "must share an encoding; investigate before proceeding."
            )

        df = raw[raw["YEAR"].astype(int).isin(code_to_year)].copy()
        df["year"] = df["YEAR"].astype(int).map(code_to_year)
        df = df[df["year"].isin(wanted_years)]
        if df.empty:
            continue

        df["geoid"] = df["STATE"].str.zfill(2) + df["COUNTY"].str.zfill(3)
        df["agegrp"] = df["AGEGRP"].astype(int)
        # TOT_POP is the all-race, both-sex total for the AGEGRP; using it
        # is what "collapse over sex and race" means for this file family.
        df["population"] = df["TOT_POP"]
        # county_name here is cosmetic: the authoritative name comes from the
        # weather panel's county universe at the spine step, which is what
        # guarantees it matches the merge key. Read defensively -- Census ships
        # CTYNAME entirely BLANK for Connecticut in this product, so pandas
        # types the column float64 and .str raises.
        if "CTYNAME" in df.columns and df["CTYNAME"].notna().any():
            df["county_name"] = (
                df["CTYNAME"].astype(str).str.replace(r"\s+County$", "", regex=True)
            )

        frames.append(df)

    if not frames:
        available = sorted(set(code_to_year.values())) if code_to_year else "unknown"
        raise RuntimeError(
            f"[{config.name}] no rows fetched for states {states}. The file(s) parsed, but "
            f"nothing survived the year filter: asked for {sorted(wanted_years)}, file "
            f"covers {available}. Either this source's `years` in SOURCES is wrong, or the "
            "YEAR span in YEAR_CODE_RULES is."
        )

    out = pd.concat(frames, ignore_index=True)
    logging.info(
        "[%s] fetched %d rows, %d counties, years %s",
        config.name, len(out), out["geoid"].nunique(), sorted(out["year"].unique()),
    )
    return _standardize(out, config)


def _get_api_key() -> str:
    """Read the Census API key, with an actionable error if it's absent."""
    import os

    key = os.environ.get(CENSUS_API_KEY_ENV_VAR, "").strip()
    if not key:
        raise RuntimeError(
            f"The Census intercensal API requires a key and {CENSUS_API_KEY_ENV_VAR} is not "
            f"set.\n\n{API_KEY_HELP}"
        )
    return key


def _parse_api_json(response, context: str):
    """
    Turn an API response into JSON, or raise something a human can act on.

    The Census API does not signal auth failures with a status code -- a
    missing or bad key comes back as HTTP 200 with an HTML error page. So
    the status code is not sufficient evidence of success; the payload
    shape is what has to be checked.
    """
    body = response.text.lstrip()

    if body[:1] in ("<",):
        hint = ""
        lowered = body[:2000].lower()
        if "missing key" in lowered:
            hint = f"\n\nThe API says the key is missing.\n{API_KEY_HELP}"
        elif "invalid key" in lowered:
            hint = (
                f"\n\nThe API says the key is INVALID. Check {CENSUS_API_KEY_ENV_VAR} for "
                "stray whitespace or quotes, or request a new key at "
                "https://api.census.gov/data/key_signup.html"
            )
        raise RuntimeError(
            f"[{context}] Census returned HTML, not JSON (HTTP {response.status_code}). "
            f"Census signals auth failures this way rather than with a 4xx.{hint}"
        )

    # Parameter errors come back as a bare plain-text line, e.g.
    # "error: unknown variable 'NAME'". Surface that as the message rather
    # than burying it under a JSONDecodeError traceback.
    if body.lower().startswith("error"):
        raise RuntimeError(
            f"[{context}] Census rejected the request (HTTP {response.status_code}): "
            f"{body.splitlines()[0].strip()}\n"
            "Valid variables for int_charagegroups are POP, AGEGRP, RACE_SEX, HISP, YEAR, "
            "STATE, COUNTY, SUMLEV -- check the 'get' list against "
            f"{CENSUS_API_ROOT}/1990/pep/int_charagegroups/variables.html"
        )

    try:
        return response.json()
    except ValueError as exc:
        raise RuntimeError(
            f"[{context}] could not parse the API response as JSON (HTTP "
            f"{response.status_code}). First 300 characters:\n{body[:300]}"
        ) from exc


def fetch_intercensal_api(config: PopulationSourceConfig, states: list) -> pd.DataFrame:
    """Pull one decade of county intercensal estimates from the Census API
    (pep/int_charagegroups), one request per state per year.

    A DIFFERENT product line from the annual "Vintage YYYY" estimates that left
    the API after Vintage 2019. Its AGEGRP code list is not published in
    variables.json, so assert_agegrp_encoding() runs before anything trusts it.
    """
    # The key is fetched lazily, on the first cache MISS -- not up front.
    # A fully cached run makes no requests, so it must not require a key:
    # that is what lets a reviewer re-run the build from dataRAW without
    # signing up for their own key.
    api_key = None
    cache_dir = RAW_DIR / config.name
    cache_dir.mkdir(parents=True, exist_ok=True)
    frames = []

    # ONE REQUEST PER STATE, covering the whole decade. YEAR is a variable to
    # SELECT, not a predicate to filter on: passing YEAR=1995 returns HTTP 204
    # (valid request, no rows). This also cuts the call count 10x versus one
    # request per state-year.
    url = f"{CENSUS_API_ROOT}/{config.api_base_year}/pep/int_charagegroups"

    for state in states:
        cached = cache_dir / f"int_charagegroups_{state}.json"
        if cached.exists():
            payload = json.loads(cached.read_text())
        else:
            if api_key is None:
                api_key = _get_api_key()
            params = {
                # NAME is NOT a variable in this dataset (confirmed 9/3/26: the API
                # answers "unknown variable 'NAME'"). County names come from the
                # weather panel's county universe at the spine step instead, which
                # is the better source anyway -- it guarantees they match the merge
                # key rather than whatever spelling Census used in the 1990s.
                "get": "POP,YEAR,AGEGRP,RACE_SEX,HISP",
                "for": "county:*",
                "in": f"state:{state}",
                "key": api_key,
            }
            logging.info("API %s state=%s (whole decade)", url, state)
            response = requests.get(
                url, params=params, timeout=REQUEST_TIMEOUT,
                headers={"User-Agent": USER_AGENT},
            )
            if response.status_code == 204:
                raise RuntimeError(
                    f"[{config.name}] state {state}: HTTP 204, no content. The request was "
                    "accepted but matched no rows -- usually a predicate that filters "
                    "everything out. Do not add YEAR as a predicate here."
                )
            if not response.ok:
                raise RuntimeError(
                    f"[{config.name}] API returned {response.status_code} for state {state}:\n"
                    f"{response.text[:500]}\n"
                    "Run with --probe-api to inspect a single response. If this endpoint "
                    "turns out not to serve what we need, the documented fallback is the "
                    "STCH-ICEN fixed-width flat file -- see population_utils."
                    "AGEGRP_ENCODING_STCH_ICEN_1990S, and note it uses a DIFFERENT age "
                    "encoding (0 = under 1, no total row)."
                )
            payload = _parse_api_json(response, f"{config.name} state={state}")
            cached.write_text(json.dumps(payload))
            _record_api_source(cache_dir, cached.name, url, state)

        header, *rows = payload
        frames.append(pd.DataFrame(rows, columns=header))

    if not frames:
        raise RuntimeError(f"[{config.name}] no rows fetched for states {states}")

    out = pd.concat(frames, ignore_index=True)
    out["geoid"] = out["state"].str.zfill(2) + out["county"].str.zfill(3)
    out["agegrp"] = out["AGEGRP"].astype(int)
    # population first: _normalize_api_year needs it to tell an empty
    # malformed cell (droppable) from a genuinely shifted decade (fatal).
    out["population"] = pd.to_numeric(out["POP"], errors="coerce")
    out = _normalize_api_year(out, config)

    # The decade arrives whole; keep only the years this run asked for.
    out = out[out["year"].isin(set(config.years))]
    if out.empty:
        raise RuntimeError(
            f"[{config.name}] no rows left after filtering to {list(config.years)}."
        )
    # No county_name from this source by design -- the API has no NAME
    # variable, and the spine step fills names from the weather panel's
    # county universe, which is the authority for the merge key anyway.

    # The API returns every race/sex and Hispanic-origin combination as
    # separate rows. Sum them, but only over the rows that partition the
    # population -- if a "total" code is present, adding it to its own
    # components would double-count. (For the 1990s there is none:
    # RACE_SEX runs 01-08 and HISP runs 1-2, both pure partitions.)
    out = _collapse_api_race_sex_hisp(out)

    # Age-code normalization is NOT done here -- build_population_panel
    # runs it on every source uniformly, so no fetcher can quietly opt out.

    logging.info(
        "[%s] fetched %d rows, %d counties, years %s",
        config.name, len(out), out["geoid"].nunique(), sorted(out["year"].unique()),
    )
    return _standardize(out, config)


def _collapse_api_race_sex_hisp(df: pd.DataFrame) -> pd.DataFrame:
    """Reduce the API's race/sex/Hispanic-origin detail to one row per
    (geoid, year, agegrp).

    Uses the explicit "all categories" code where present rather than summing
    components, which would double-count if aggregate rows are also present.
    """
    has_totals = False
    subset = df

    for col, total_code in (("RACE_SEX", "0"), ("HISP", "0")):
        if col in df.columns and (df[col].astype(str) == total_code).any():
            subset = subset[subset[col].astype(str) == total_code]
            has_totals = True

    if has_totals:
        logging.info("API: using explicit all-category rows for race/sex/Hispanic origin.")
    else:
        logging.info("API: no all-category code found; summing race/sex/Hispanic components.")
        subset = df

    keep_cols = [c for c in ("geoid", "year", "agegrp", "county_name") if c in subset.columns]
    agg = {"population": "sum"}
    if "county_name" in keep_cols:
        keep_cols.remove("county_name")
        agg["county_name"] = "first"

    return subset.groupby(keep_cols, as_index=False).agg(agg)


def _normalize_api_year(
    df: pd.DataFrame, config: PopulationSourceConfig, *, value_col: str = "population"
) -> pd.DataFrame:
    """Add a calendar `year` column from the API's YEAR values.

    The 1990s endpoint returns TWO-DIGIT years (confirmed 9/3/26); both forms
    are handled, chosen by which covers more rows. The 1990s has no overlapping
    source for assert_period_continuity to catch a shift downstream, so this
    stays strict -- but rows whose YEAR doesn't map are dropped ONLY if they
    carry no population (Census ships the occasional empty cell), and the drop
    is logged. A genuinely shifted decade fails both tests and still raises.
    """
    years = pd.to_numeric(df["YEAR"], errors="coerce").astype("Int64")
    decade = sorted(range(config.api_base_year, config.api_base_year + 10))
    two_digit = sorted({y % 100 for y in decade})
    century = config.api_base_year - (config.api_base_year % 100)

    # Pick the form by row coverage rather than by assuming one.
    if years.isin(two_digit).sum() >= years.isin(decade).sum():
        mapped, form = years + century, "two-digit"
    else:
        mapped, form = years, "four-digit"

    good = mapped.isin(decade)
    out = df.copy()
    out["year"] = mapped

    if not good.all():
        stray = out.loc[~good]
        stray_pop = pd.to_numeric(stray[value_col], errors="coerce").fillna(0).abs().sum()
        observed = sorted(int(v) for v in years[~good].dropna().unique())

        if stray_pop > 0 or good.sum() == 0:
            raise RuntimeError(
                f"[{config.name}] {len(stray):,} row(s) have YEAR values {observed} that "
                f"don't map into {decade[0]}-{decade[-1]} (read as {form}), carrying "
                f"{stray_pop:,.0f} population. This is not an isolated empty cell -- "
                "refusing to guess, because a wrong mapping shifts the entire decade and "
                "nothing downstream would catch it."
            )

        where = sorted({f"{s}{c}" for s, c in zip(stray["state"], stray["county"])})
        logging.warning(
            "[%s] dropping %d row(s) with unmappable YEAR %s and zero population "
            "(county %s). Census data glitch, not a mapping error -- no information lost.",
            config.name, len(stray), observed, ", ".join(where[:5]),
        )
        out = out[good]

    out["year"] = out["year"].astype(int)
    logging.info(
        "[%s] YEAR read as %s; %d-%d.",
        config.name, form, out["year"].min(), out["year"].max(),
    )
    return out


def _record_api_source(cache_dir: Path, filename: str, url: str, state: str):
    """An API response is a download; archive its provenance like any other."""
    source_txt = cache_dir / "source.txt"
    line = (
        f"{filename}\t{url}?get=POP,YEAR,AGEGRP,RACE_SEX,HISP&for=county:*&in=state:{state}"
        f"\tobtained {date.today().isoformat()}\n"
    )
    existing = source_txt.read_text() if source_txt.exists() else ""
    if filename not in existing:
        source_txt.write_text(existing + line)


def fetch_pe02_1980s(config: PopulationSourceConfig, states: list) -> pd.DataFrame:
    """Read the PE-02 intercensal county file for one year of the 1980s (one
    .xls per year, county x 5-year age group x sex x race).

    CONFIRMED 9/8/26 against pe-02-1985.xls: headers on row 6, 3,141 counties
    x 6 race/sex rows, no Hispanic breakdown and no pre-summed total row -- so
    sex and race are collapsed here and the total row is synthesized below. The
    18 age-bucket labels map straight onto AGE_BUCKETS codes 1-18. Only 1985 is
    verified; other years are validated against the required columns first.
    """
    age_col_labels = [
        "Under 5 years", "5 to 9 years", "10 to 14 years", "15 to 19 years",
        "20 to 24 years", "25 to 29 years", "30 to 34 years", "35 to 39 years",
        "40 to 44 years", "45 to 49 years", "50 to 54 years", "55 to 59 years",
        "60 to 64 years", "65 to 69 years", "70 to 74 years", "75 to 79 years",
        "80 to 84 years", "85 years and over",
    ]
    label_to_code = dict(zip(age_col_labels, range(1, 19)))

    wanted_states = set(states)
    frames = []

    for year in config.years:
        path = download_to_raw(
            config.url_template.format(year=year), config.name,
            filename=f"pe-02-{year}.xls",
        )
        try:
            raw = pd.read_excel(path, sheet_name=str(year), header=5, dtype=str)
        except Exception as exc:  # noqa: BLE001 - want the filename in the message
            raise RuntimeError(
                f"[{config.name}] could not read {path.name} (sheet '{year}', header on "
                f"row 6): {exc}. PE-02 ships as .xls (xlrd handles it; openpyxl will not). "
                f"If the sheet name or header row differ from what this fetcher assumes, "
                f"inspect the file under {RAW_DIR / config.name} before changing anything "
                "here."
            ) from exc

        raw.columns = [str(c).strip() for c in raw.columns]
        required_cols = {
            "Year of Estimate", "FIPS State and County Codes", "Race/Sex Indicator",
            *age_col_labels,
        }
        missing_cols = required_cols - set(raw.columns)
        if missing_cols:
            raise ValueError(
                f"[{config.name}] {path.name} is missing column(s) {sorted(missing_cols)}. "
                f"Columns found: {list(raw.columns)}. The PE-02 layout may differ for this "
                "year -- re-inspect the file (see the docstring above) before editing the "
                "column list."
            )

        raw = raw.dropna(subset=["FIPS State and County Codes", "Race/Sex Indicator"])
        raw["geoid"] = raw["FIPS State and County Codes"].astype(str).str.strip().str.zfill(5)
        if raw["geoid"].str.len().ne(5).any():
            bad = sorted(raw.loc[raw["geoid"].str.len() != 5, "geoid"].unique())[:10]
            raise ValueError(
                f"[{config.name}] {path.name}: geoid values that are not 5 characters "
                f"after zero-fill: {bad}. The FIPS column may contain a state total, a "
                "footnote row, or something else that isn't a county."
            )

        if wanted_states:
            raw = raw[raw["geoid"].str[:2].isin(wanted_states)]
        if raw.empty:
            continue

        long = raw.melt(
            id_vars=["geoid"], value_vars=age_col_labels,
            var_name="age_label", value_name="population",
        )
        long["agegrp"] = long["age_label"].map(label_to_code)
        long["population"] = pd.to_numeric(long["population"], errors="coerce").fillna(0)
        long["year"] = year

        # Sum the 6 race/sex rows (White/Black/Other races x male/female) per
        # (geoid, agegrp) -- sex and race are collapsed everywhere else in this
        # pipeline (see the module docstring), and PE-02 has no pre-summed row
        # to use instead.
        collapsed = (
            long.groupby(["geoid", "year", "agegrp"], as_index=False)["population"].sum()
        )

        # Synthesize the AGEGRP_TOTAL_CODE row PE-02 doesn't ship. Its 18
        # buckets already ARE the standard encoding, so summing them is exact,
        # not an approximation -- and it lets detect_agegrp_encoding /
        # assert_agegrp_encoding run on this source like every other.
        totals = collapsed.groupby(["geoid", "year"], as_index=False)["population"].sum()
        totals["agegrp"] = AGEGRP_TOTAL_CODE
        collapsed = pd.concat([collapsed, totals], ignore_index=True)

        logging.info(
            "[%s] %d: %d counties, %d rows (18 age buckets + synthesized total).",
            config.name, year, collapsed["geoid"].nunique(), len(collapsed),
        )
        frames.append(collapsed)

    if not frames:
        raise RuntimeError(f"[{config.name}] no rows fetched for years {list(config.years)}")

    out = pd.concat(frames, ignore_index=True)
    return _standardize(out, config)


def fetch_ct_town_reaggregation(config: PopulationSourceConfig, states: list) -> pd.DataFrame:
    """
    Load 08a_population_ct_towns.py's output. Not a network fetch --
    a pipeline-ordering dependency: 08a must have been run first.
    """
    if not CT_TOWN_REAGGREGATION_PATH.exists():
        raise FileNotFoundError(
            f"{CT_TOWN_REAGGREGATION_PATH} not found. Run 08a_population_ct_towns.py "
            "before 08b, or pass --skip-ct to build without the CT override (CT 2022-2025 "
            "will then be missing or on the wrong geography)."
        )

    ct = pd.read_csv(CT_TOWN_REAGGREGATION_PATH, dtype=FIPS_DTYPES)
    stray = set(ct["state_fips"].unique()) - {CT_STATE_FIPS}
    if stray:
        raise ValueError(
            f"{CT_TOWN_REAGGREGATION_PATH.name} contains non-CT state_fips {sorted(stray)} -- "
            "08a's output looks corrupted or mixed with another source."
        )
    return ct


# ---------------------------------------------------------------------
# Stage 2: stack
# ---------------------------------------------------------------------

def stack_sources(frames: dict) -> pd.DataFrame:
    """
    Concatenate every source and resolve year overlaps by priority,
    per (geoid, year, agegrp) -- never per state, never per year alone.

    Resolution is logged rather than silent: a source that contributes
    zero rows is a bug, not a no-op.
    """
    priorities = {name: config.priority for name, (config, _) in frames.items()}
    stacked = []

    for name, (config, df) in frames.items():
        if df is None or df.empty:
            raise RuntimeError(f"[{name}] contributed 0 rows -- expected years {config.years}.")
        df = df.copy()
        df["_priority"] = priorities[name]
        stacked.append(df)
        logging.info("[%s] %d rows into the stack", name, len(df))

    panel = pd.concat(stacked, ignore_index=True)

    # Continuity must be checked HERE, before the dedup below removes the
    # overlapping rows it depends on. Once a year has been resolved to a
    # single source there is nothing left to compare it against, and the
    # check would pass vacuously.
    assert_period_continuity(panel)

    before = len(panel)
    panel = panel.sort_values("_priority").drop_duplicates(
        subset=["geoid", "year", "agegrp"], keep="first"
    )
    superseded = before - len(panel)
    if superseded:
        logging.info(
            "Stack: %d row(s) superseded by a higher-priority source on the same "
            "(geoid, year, agegrp).", superseded,
        )

    return panel.drop(columns="_priority").reset_index(drop=True)


# ---------------------------------------------------------------------
# Stage 4: CT override
# ---------------------------------------------------------------------

def assert_ct_geography(panel: pd.DataFrame, source_name: str):
    """
    Decide from the data which CT geography a source uses, instead of
    assuming. See module docstring, unverified item 3.
    """
    ct_geoids = set(panel.loc[panel["geoid"].str.startswith(CT_STATE_FIPS), "geoid"].unique())
    if not ct_geoids:
        return "none"

    if ct_geoids <= CT_LEGACY_GEOIDS:
        logging.info("[%s] CT reported under the legacy 8 counties.", source_name)
        return "legacy"

    if ct_geoids <= CT_PLANNING_REGION_GEOIDS:
        logging.warning(
            "[%s] CT reported under the 9 PLANNING REGIONS (%s). This is a scope finding, "
            "not just a parsing detail: CT's gap starts with this source's first year "
            "rather than 2022, and 08a must cover that whole span. Raise this before "
            "treating the CT series as complete.",
            source_name, sorted(ct_geoids),
        )
        return "planning_regions"

    logging.warning(
        "[%s] CT geoids are a mix of schemes or unrecognized: %s", source_name, sorted(ct_geoids)
    )
    return "mixed"


def apply_ct_override(panel: pd.DataFrame, ct: pd.DataFrame) -> pd.DataFrame:
    """Replace CT's rows with 08a's town-reaggregated series, by geoid so it
    cannot touch another state, and AFTER the crosswalk so CT's already
    resolved rows are never recoded twice.

    08a produces totals only -- CT age shares are not recoverable for 2022-2025
    -- so those rows carry an age flag and keep their totals.
    """
    ct_years = set(ct["year"].unique())
    keep = ~((panel["geoid"].isin(CT_LEGACY_GEOIDS)) & (panel["year"].isin(ct_years)))
    replaced = int((~keep).sum())

    # Count the planning-region rows too. In the years 08a covers Census
    # publishes CT under planning regions, so there are usually NO legacy rows
    # to displace and `replaced` is 0 -- which reads as if the override did
    # nothing when it is in fact the only thing supplying CT. The
    # planning-region rows fall out later at the spine step.
    superseded_regions = int(
        (panel["geoid"].isin(CT_PLANNING_REGION_GEOIDS) & panel["year"].isin(ct_years)).sum()
    )

    ct = ct.copy()
    if "agegrp" not in ct.columns:
        ct["agegrp"] = AGEGRP_TOTAL_CODE  # totals only
    ct["source"] = "ct_town_reaggregation"
    ct["is_intercensal"] = True

    out = pd.concat([panel[keep], ct], ignore_index=True)
    logging.info(
        "CT override %s-%s: %d row(s) from 08a; displaced %d legacy-county row(s) and "
        "supersedes %d planning-region row(s) (the latter drop at the spine, not here).",
        min(ct_years), max(ct_years), len(ct), replaced, superseded_regions,
    )
    if len(ct) == 0:
        raise ValueError(
            "CT override contributed no rows. 08a's output is empty or its years don't "
            "overlap this run -- CT would silently end up missing."
        )
    return out


# ---------------------------------------------------------------------
# Stage 5: validate
# ---------------------------------------------------------------------

def assert_period_continuity(
    panel: pd.DataFrame, *, median_tolerance: float = 0.01, tail_tolerance: float = 0.03
):
    """Where two sources cover the same year, compare them COUNTY BY COUNTY to
    catch a YEAR-code misalignment that nothing else would notice.

    County by county rather than on the national total: a one-year shift moves
    the national total by about as much as an ordinary vintage revision, but it
    moves each county by ITS OWN growth rate, so the upper tail discriminates.
    Fails on median_tolerance, or on tail_tolerance at the 95th percentile.
    """
    level = AGEGRP_TOTAL_CODE if (panel["agegrp"] == AGEGRP_TOTAL_CODE).any() else None
    subject = panel[panel["agegrp"] == level] if level is not None else panel
    by_county = (
        subject.groupby(["source", "year", "geoid"])["population"].sum().reset_index()
    )

    problems = []
    for year, group in by_county.groupby("year"):
        sources = sorted(group["source"].unique())
        if len(sources) < 2:
            continue

        reference = sources[0]
        ref = group[group["source"] == reference].set_index("geoid")["population"]

        for other in sources[1:]:
            cmp = group[group["source"] == other].set_index("geoid")["population"]
            joined = pd.concat([ref.rename("a"), cmp.rename("b")], axis=1).dropna()
            if joined.empty:
                continue

            diff = (joined["b"] - joined["a"]).abs() / joined["a"].clip(lower=1)
            median, p95, worst = diff.median(), diff.quantile(0.95), diff.max()

            logging.info(
                "Continuity %s: %s vs %s across %d counties -- median %.3f%%, "
                "p95 %.3f%%, max %.3f%%.",
                year, reference, other, len(joined),
                median * 100, p95 * 100, worst * 100,
            )

            if median > median_tolerance or p95 > tail_tolerance:
                problems.append((year, reference, other, median, p95, worst))
                logging.error(
                    "Continuity check FAILED at %s (%s vs %s): median county difference "
                    "%.2f%% (limit %.2f%%), p95 %.2f%% (limit %.2f%%). The most likely "
                    "cause is a wrong YEAR-code mapping in YEAR_CODE_RULES -- a one-year "
                    "shift shows up exactly like this. See the module docstring, "
                    "unverified item 2.",
                    year, reference, other, median * 100, median_tolerance * 100,
                    p95 * 100, tail_tolerance * 100,
                )

    if problems:
        raise ValueError(
            f"Period continuity failed for {len(problems)} source pair(s). "
            "Refusing to write a panel whose time axis may be shifted."
        )

    totals = by_county.groupby(["source", "year"])["population"].sum().reset_index()

    # Year-over-year national growth should be small; a one-year shift in a
    # whole period usually shows up here even without an overlap. Take the
    # max across sources rather than the sum -- in an overlap year two
    # sources each carry a full national total, and summing them would
    # manufacture a 100% jump.
    national = totals.groupby("year")["population"].max().sort_index()
    growth = national.pct_change().abs()
    suspicious = growth[growth > 0.03]
    if len(suspicious):
        logging.warning(
            "National population moves >3%% year-over-year at: %s. Not necessarily wrong "
            "(a source boundary can do this), but worth a look.",
            suspicious.index.tolist(),
        )


def validate_panel(panel: pd.DataFrame, universe: pd.DataFrame, years) -> pd.DataFrame:
    """Structural + merge-readiness assertions. Returns the review-flag rows."""
    problems = []

    dup = panel.duplicated(subset=["geoid", "year"], keep=False)
    if dup.any():
        raise ValueError(
            f"{int(dup.sum())} duplicate (geoid, year) row(s) in the final panel -- "
            "the stack/override step did not resolve cleanly."
        )

    for col in ("geoid", "state_fips", "county_fips"):
        if not pd.api.types.is_string_dtype(panel[col]):
            raise TypeError(
                f"{col} is {panel[col].dtype}, not string. A silent int cast here loses "
                "every leading-zero state at merge time."
            )
    bad_geoid = panel.loc[panel["geoid"].str.len() != 5, "geoid"].unique()
    if len(bad_geoid):
        raise ValueError(f"geoid values that are not 5 characters: {bad_geoid[:10]}")

    expected_geoids = set(universe["geoid"])
    actual_geoids = set(panel["geoid"])
    if actual_geoids != expected_geoids:
        extra = sorted(actual_geoids - expected_geoids)[:10]
        missing = sorted(expected_geoids - actual_geoids)[:10]
        raise ValueError(
            f"Panel geoid set does not match the weather panel's county universe. "
            f"{len(actual_geoids - expected_geoids)} extra (e.g. {extra}), "
            f"{len(expected_geoids - actual_geoids)} missing (e.g. {missing})."
        )

    expected_rows = len(expected_geoids) * len(list(years))
    if len(panel) != expected_rows:
        raise ValueError(
            f"Panel has {len(panel):,} rows; expected {expected_rows:,} "
            f"({len(expected_geoids)} counties x {len(list(years))} years)."
        )

    negative = panel["population"] < 0
    if negative.any():
        problems.append(panel[negative].assign(issue="negative population"))

    # MAGNITUDE CHECK. Everything above tests shape, and all of it passed while
    # the 2000s sat at ~4 million people instead of ~285 million. CONUS + DC ran
    # ~250M in 1990 and ~335M in 2025, so a 150M-400M band never fires on real
    # data but catches an order-of-magnitude error; national population has never
    # moved more than ~1.5% year-over-year, so 3% leaves headroom. Only
    # meaningful on a full-country build -- a state subset would false-alarm.
    national = panel.groupby("year")["population"].sum()
    is_full_country = set(panel["state_fips"]) == set(CONUS_STATE_FIPS)
    implausible = (
        national[(national < 150e6) | (national > 400e6)]
        if is_full_country else national.iloc[0:0]
    )
    if len(implausible):
        raise ValueError(
            "National population is implausible in "
            f"{len(implausible)} year(s): "
            + ", ".join(f"{y}={v:,.0f}" for y, v in implausible.head(8).items())
            + ". Expected 150M-400M for CONUS + DC. This is the signature of a "
            "misread age or year encoding -- check which source covers those years."
        )

    # ANNUALIZED, not raw, because --years can be non-contiguous: given
    # 2000 2009 2010 the naive year-over-year change compares 2009 against
    # 2000 and reads nine years of growth as one. Divide the change by the
    # actual gap so a sparse run isn't punished for its own sparseness.
    ordered = national.sort_index()
    gaps = ordered.index.to_series().diff()
    annualized = (ordered / ordered.shift(1)) ** (1.0 / gaps) - 1
    jumps = annualized.abs()
    jumps = jumps[jumps > 0.03]
    if len(jumps):
        raise ValueError(
            "Population moves more than 3% per year at "
            + ", ".join(f"{y} ({annualized[y]:+.1%}/yr)" for y in jumps.head(8).index)
            + ". Real population has never done this; a source boundary is "
            "misaligned or a decade is misparsed."
        )
    if not is_full_country:
        logging.info(
            "Magnitude check: level assertion skipped (%d of %d states); the "
            "year-over-year check below still applies.",
            panel["state_fips"].nunique(), len(CONUS_STATE_FIPS),
        )
    logging.info(
        "Magnitude check passed: population %s (%d) -> %s (%d), "
        "largest annualized move %.2f%%.",
        f"{ordered.iloc[0]:,.0f}", ordered.index[0],
        f"{ordered.iloc[-1]:,.0f}", ordered.index[-1],
        float(annualized.abs().max() or 0) * 100,
    )

    flagged = panel[panel[POP_FLAG_COL].notna() | panel[AGE_FLAG_COL].notna()]
    logging.info(
        "Validation passed: %d rows, %d counties x %d years. %d row(s) carry a flag "
        "(%d population, %d age).",
        len(panel), len(expected_geoids), len(list(years)), len(flagged),
        int(panel[POP_FLAG_COL].notna().sum()), int(panel[AGE_FLAG_COL].notna().sum()),
    )

    review = pd.concat([flagged, *problems], ignore_index=True) if problems else flagged
    return review


# ---------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------

FETCHERS = {
    "fetch_pe02_1980s": fetch_pe02_1980s,
    "fetch_intercensal_api": fetch_intercensal_api,
    "fetch_ccest_flatfile": fetch_ccest_flatfile,
    "fetch_ct_town_reaggregation": fetch_ct_town_reaggregation,
}


def resolve_output_paths(years, states) -> tuple:
    """
    Return (csv, dta, flags) paths, renamed if this is a partial build.

    A subset run is a diagnostic, not a deliverable. Naming its output
    distinctly is what stops a smoke test from masquerading as the
    production panel.
    """
    is_full_years = set(years) == set(FULL_YEAR_RANGE)
    is_full_states = set(states) == set(CONUS_STATE_FIPS)

    if is_full_years and is_full_states:
        return OUTPUT_CSV, OUTPUT_DTA, REVIEW_FLAGS_CSV

    # All states over a shorter span is a legitimate deliverable, not a
    # smoke test -- 1990-2025 is what Phase 6 merges against until PE-02
    # (1981-89) is implemented. Name it by its actual coverage so the file
    # is self-describing, and reserve the SUBSET_ prefix for runs that drop
    # states, which are always diagnostics.
    if is_full_states:
        stem = f"population_county_year_{min(years)}_{max(years)}"
        logging.info(
            "Building %d-%d for all %d states -> %s.*",
            min(years), max(years), len(states), stem,
        )
        return (
            OUTPUT_DIR / f"{stem}.csv",
            OUTPUT_DIR / f"{stem}.dta",
            OUTPUT_DIR / f"{stem}_review_flags.csv",
        )

    scope = ["st" + "-".join(sorted(states)[:4]) + ("+" if len(states) > 4 else "")]
    if not is_full_years:
        scope.append(f"{min(years)}-{max(years)}")
    tag = f"{SUBSET_PREFIX}{'_'.join(scope)}"

    logging.warning(
        "PARTIAL BUILD (%d of %d states, %d of %d years). Writing to %s* rather than the "
        "production filenames, so this cannot be mistaken for the full panel.",
        len(states), len(CONUS_STATE_FIPS), len(years), len(list(FULL_YEAR_RANGE)), tag,
    )
    return (
        OUTPUT_DIR / f"{tag}_population_county_year.csv",
        OUTPUT_DIR / f"{tag}_population_county_year.dta",
        OUTPUT_DIR / f"{tag}_population_review_flags.csv",
    )


def build_population_panel(
    years, states, crosswalk: pd.DataFrame, *, skip_ct: bool = False
) -> pd.DataFrame:
    """Stages 1-4. Returns the long (geoid, year, agegrp) panel."""
    # --- stage 1 ---
    frames = {}
    for config in SOURCES:
        wanted = sorted(set(config.years) & set(years))
        if not wanted:
            continue
        scoped = PopulationSourceConfig(**{**config.__dict__, "years": range(min(wanted), max(wanted) + 1)})
        df = FETCHERS[config.fetch_fn](scoped, states)

        # EVERY source is detected, normalized and then verified -- no
        # per-source special-casing. This used to run only on the API source,
        # which is exactly why the 2000s shipped 70x wrong: co-est00int uses a
        # THIRD convention (total at code 99, code 0 = under-1) and the guard
        # that would have caught it was never pointed at it.
        df = normalize_agegrp(df, source_name=config.name)
        assert_agegrp_encoding(df, source_name=config.name)
        assert_ct_geography(df, config.name)

        frames[config.name] = (scoped, df)

    # --- stage 2 ---
    panel = stack_sources(frames)
    panel = collapse_to_county_year_age(panel)

    # --- stage 3 ---
    panel = apply_fips_crosswalk(panel, crosswalk)

    # --- stage 4 ---
    if not skip_ct:
        panel = apply_ct_override(panel, fetch_ct_town_reaggregation(SOURCES[0], states))
    else:
        logging.warning("--skip-ct: CT rows come straight from Census, wrong geography for 2022+.")

    return panel


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--years", nargs="+", type=int, help="Subset of years (default 1981-2025)")
    parser.add_argument("--states", nargs="+", help="Subset of state FIPS (default CONUS + DC)")
    parser.add_argument("--skip-ct", action="store_true", help="Build without 08a's CT override")
    parser.add_argument("--probe-api", action="store_true",
                        help="Fetch and print one raw intercensal API response, then exit. "
                             "Use this first to confirm the AGEGRP/YEAR encoding.")
    parser.add_argument("--force-download", action="store_true", help="Re-download cached raw files")
    args = parser.parse_args()

    if args.force_download:
        global FORCE_DOWNLOAD
        FORCE_DOWNLOAD = True

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    setup_logging(LOG_DIR / f"08b_population_{date.today().isoformat()}.log")

    if args.probe_api:
        probe_api()
        return

    years = args.years or list(FULL_YEAR_RANGE)
    states = args.states or CONUS_STATE_FIPS
    logging.info("Building population panel: %d year(s), %d state(s)", len(years), len(states))

    # Fail fast rather than after downloading several hundred MB -- but
    # only if the run will actually issue an API request. The 1990s source
    # is the only one needing a key, and a state already in dataRAW needs
    # no request at all, so a re-run from cache stays keyless.
    for config in SOURCES:
        if config.fetch_fn != "fetch_intercensal_api" or not set(config.years) & set(years):
            continue
        cache_dir = RAW_DIR / config.name
        uncached = [s for s in states if not (cache_dir / f"int_charagegroups_{s}.json").exists()]
        if uncached:
            logging.info(
                "%d of %d states not yet cached for %s; an API key is required.",
                len(uncached), len(states), config.name,
            )
            _get_api_key()

    crosswalk = load_fips_crosswalk(FIPS_CROSSWALK_PATH)

    # Continuity is asserted inside stack_sources, where the overlapping
    # rows still exist -- see the note there.
    panel_long = build_population_panel(years, states, crosswalk, skip_ct=args.skip_ct)

    panel = compute_age_shares(panel_long)

    universe = load_county_universe(WEATHER_PANEL_PATH)
    if args.states:
        universe = universe[universe["state_fips"].isin(states)]
    panel = reindex_to_county_universe(panel, universe, years, crosswalk)

    panel = panel.rename(columns={"source": "population_source"})
    if "age_source" not in panel.columns:
        panel["age_source"] = panel["population_source"]

    ordered = ID_COLS + ["year", "population"] + AGE_SHARE_COLS + [
        "population_source", "age_source", POP_FLAG_COL, AGE_FLAG_COL,
    ]
    panel = panel[[c for c in ordered if c in panel.columns]].sort_values(["geoid", "year"])

    review = validate_panel(panel, universe, years)

    csv_path, dta_path, flags_path = resolve_output_paths(years, states)
    write_panel_outputs(panel, csv_path, dta_path)
    if len(review):
        review.to_csv(flags_path, index=False)
        logging.info("Wrote %s (%d flagged rows)", flags_path, len(review))

    logging.info("Done.")


def probe_api(state: str = "09", year: int = 1995):
    """Fetch one county-year from the intercensal API and check the AGEGRP
    encoding in a single command. Does the reconciliation itself -- whether
    codes 1-18 sum to code 0 -- rather than printing a wall of JSON.
    """
    try:
        api_key = _get_api_key()
    except RuntimeError as exc:
        print(exc)
        return

    url = f"{CENSUS_API_ROOT}/1990/pep/int_charagegroups"
    # No NAME variable, and no YEAR predicate -- YEAR is selected, not
    # filtered on. See fetch_intercensal_api for how both were found.
    params = {
        "get": "POP,YEAR,AGEGRP,RACE_SEX,HISP",
        "for": "county:001",
        "in": f"state:{state}",
        "key": api_key,
    }

    # Log without the key -- this goes to a file in the repo.
    logging.info(
        "Probing %s with %s", url, {k: v for k, v in params.items() if k != "key"}
    )

    response = requests.get(url, params=params, timeout=REQUEST_TIMEOUT,
                            headers={"User-Agent": USER_AGENT})
    logging.info("HTTP %s", response.status_code)

    # A probe is a diagnostic; report the problem rather than throwing a
    # traceback at someone who ran this precisely to find out what's wrong.
    try:
        payload = _parse_api_json(response, "probe")
    except RuntimeError as exc:
        print(f"\nPROBE FAILED\n{exc}")
        return

    header, *rows = payload
    df = pd.DataFrame(rows, columns=header)
    df["agegrp"] = df["AGEGRP"].astype(int)
    df["population"] = pd.to_numeric(df["POP"], errors="coerce")

    print("\nColumns returned:", header)
    print("Distinct AGEGRP :", sorted(int(a) for a in df["agegrp"].unique()))
    print("Distinct YEAR   :", sorted(df["YEAR"].unique()))
    if "RACE_SEX" in df.columns:
        print("Distinct RACE_SEX:", sorted(df["RACE_SEX"].unique()))
    if "HISP" in df.columns:
        print("Distinct HISP   :", sorted(df["HISP"].unique()))
    print(f"\nRows returned: {len(df)} (the whole decade for this county)")

    # The response covers every year; the encoding check only needs one.
    df["year_raw"] = pd.to_numeric(df["YEAR"], errors="coerce")
    probe_year = year if (df["year_raw"] == year).any() else df["year_raw"].min()
    if probe_year != year:
        print(f"\nNote: {year} not present in YEAR; checking {probe_year} instead.")
    df = df[df["year_raw"] == probe_year]

    collapsed = _collapse_api_race_sex_hisp(
        df.assign(geoid=f"{state}001", year=int(probe_year))
    )

    print("\n--- raw encoding, as returned ---")
    raw_zero = collapsed.loc[collapsed["agegrp"] == 0, "population"].sum()
    raw_rest = collapsed.loc[collapsed["agegrp"] != 0, "population"].sum()
    print(f"code 0            : {int(raw_zero):,}")
    print(f"codes 1-18 summed : {int(raw_rest):,}")
    print(f"all codes summed  : {int(raw_zero + raw_rest):,}")
    if raw_zero and abs(raw_rest - raw_zero) / max(raw_zero, 1) > 0.001:
        print("=> code 0 is NOT a total (it is far too small) -- this is the STCH-ICEN\n"
              "   convention: 0 = under 1, 1 = 1-4, 2 = 5-9 ... 18 = 85+, no total row.\n"
              "   The county total is the sum of ALL codes.")

    # Apply exactly what the fetcher applies, then re-run the real check.
    normalized = normalize_agegrp(collapsed, source_name="probe")
    print("\n--- after normalize_agegrp (what the pipeline uses) ---")
    try:
        assert_agegrp_encoding(normalized, source_name="probe")
        total = normalized.loc[normalized["agegrp"] == AGEGRP_TOTAL_CODE, "population"].iloc[0]
        print(f"synthesized total : {int(total):,}")
        print(f"buckets           : {sorted(int(a) for a in normalized['agegrp'].unique())}")
        print("\nPASS -- codes 1-18 reconcile to the total after normalization.")
    except ValueError as exc:
        print(f"\nFAIL -- {exc}")


if __name__ == "__main__":
    main()
