"""
Shared helpers for the population-data scripts (08a_population_county.py,
08b_population_ct_towns.py) -- FIPS crosswalk mechanics, age-bucket
handling, and the panel-level assertions that protect the merge key.

Mirrors aggregation_utils.py's role for the weather aggregation stage
(05/06) -- see SCRIPT_OVERVIEW.md. resolve_data_root is re-exported from
aggregation_utils.py rather than duplicated, since the logic is identical
(first existing candidate path wins). setup_logging is reimplemented here
rather than imported from gee_extract_utils, deliberately: importing that
module pulls in earthengine-api, and nothing in the population stage
touches Earth Engine. Keep the two implementations in sync if either
changes.

DESIGN NOTES worth reading before modifying anything here:

1. HARMONIZATION DIRECTION. Every county-year is recoded FORWARD onto the
   TIGER/2018 FIPS set, because that is the weather panel's county
   universe and therefore the project's merge key (see project memory:
   county-geometry-vintage). David Dorn's FIPS_County_Code_Changes.pdf --
   the reference Eyal pointed to on 9/1/26 -- goes the OTHER way, mapping
   modern codes back onto 1980-era codes, because his target geography is
   1990 commuting zones ("replace FIPS code 12086 with the old code
   12025"). We take his change list and his case-by-case reasoning and
   invert his direction. Do not "fix" this back after reading Dorn.

2. RELABEL ALL YEARS, NOT JUST POST-CHANGE YEARS. apply_fips_crosswalk
   recodes every occurrence of an old_geoid regardless of year. This
   differs from the 8/31 scaffolding, which relabeled only rows at
   year >= effective_year. That rule was wrong in two ways:
     (a) Sources are published under the geography vintage current at
         PUBLICATION, not at the date being estimated -- the 1990s
         intercensal product may well report Miami-Dade as 12086 for
         1991. A year-conditional rule silently misses those.
     (b) For a merger it produced a real undercount. South Boston city
         (51780) was a separate county-equivalent through 1995; Halifax
         County (51083) covers that territory in 2018 geography. To make
         every year comparable to the 2018 unit, South Boston's
         population must be added to Halifax in the pre-1995 years too.
         Relabeling only post-1995 rows would leave 51780 as an orphan
         geoid (dropped at merge time) and leave Halifax undercounted for
         15 years.
   Recoding unconditionally is both simpler and correct: if a source
   already uses the modern code, the rule is a no-op.

3. FLAG, NEVER FABRICATE. Splits and merge_splits have no defensible
   county-level apportionment for a population DENOMINATOR. They are
   flagged and left NaN. See apply_fips_crosswalk for the per-type
   reasoning.
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from aggregation_utils import resolve_data_root  # re-exported, not duplicated

__all__ = [
    "resolve_data_root",
    "setup_logging",
    "ID_COLS",
    "POP_FLAG_COL",
    "AGE_FLAG_COL",
    "AGEGRP_TOTAL_CODE",
    "AGE_BUCKETS",
    "AGE_SHARE_COLS",
    "CONUS_STATE_FIPS",
    "FIPS_DTYPES",
    "load_fips_crosswalk",
    "apply_fips_crosswalk",
    "collapse_to_county_year_age",
    "detect_agegrp_encoding",
    "normalize_agegrp",
    "AGEGRP_ALT_TOTAL_CODE",
    "compute_age_shares",
    "assert_agegrp_encoding",
    "reindex_to_county_universe",
    "load_county_universe",
    "write_panel_outputs",
]


# ---------------------------------------------------------------------
# Column / dtype conventions
# ---------------------------------------------------------------------

# Same ID columns as the weather pipeline (gee_extract_utils.ID_COLS /
# aggregation_utils) so this merges cleanly on geoid with Charvi's
# collision data and Nicole's wildlife data.
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]

# Read these as strings ALWAYS. Without dtype=str pandas infers ints and
# silently drops leading zeros (geoid "01001" -> 1001), which corrupts
# every merge for any state whose FIPS starts with 0.
FIPS_DTYPES = {
    "geoid": str,
    "state_fips": str,
    "county_fips": str,
    "old_geoid": str,
    "new_geoid": str,
}

# Two flag columns, not one: age detail can fail where the total
# succeeds (CT 2021-2025 is the case in point). A gap in age shares must
# never blank out the total-population series, which is the collision-rate
# denominator and the thing the Phase 6 merge actually blocks on.
POP_FLAG_COL = "population_flag"
AGE_FLAG_COL = "age_flag"


# ---------------------------------------------------------------------
# Age buckets
# ---------------------------------------------------------------------

# This project's standard: 0 = total, 1-18 = 0-4 ... 85+. Only
# cc-est2020int and cc-est2025 arrive this way; the 1990s API and
# co-est00int use different conventions and are converted on the way in.
# detect_agegrp_encoding documents all three.
AGEGRP_TOTAL_CODE = 0

# co-est00int (2000s) puts its total at code 99 instead of 0, with 0
# meaning under-1. Same column name, third meaning -- see
# detect_agegrp_encoding.
AGEGRP_ALT_TOTAL_CODE = 99

AGE_BUCKETS = {
    1: "0_4",
    2: "5_9",
    3: "10_14",
    4: "15_19",
    5: "20_24",
    6: "25_29",
    7: "30_34",
    8: "35_39",
    9: "40_44",
    10: "45_49",
    11: "50_54",
    12: "55_59",
    13: "60_64",
    14: "65_69",
    15: "70_74",
    16: "75_79",
    17: "80_84",
    18: "85plus",
}

AGE_SHARE_COLS = [f"pop_share_{label}" for label in AGE_BUCKETS.values()]

# CONUS + DC. Convenience copy of gee_extract_utils.CONUS_STATE_FIPS,
# duplicated rather than imported to keep earthengine-api off this
# script's dependency list. This list is NOT the authority on the county
# universe -- load_county_universe() reads that from the weather panel
# itself, so a drift here can't silently change which counties we build.
CONUS_STATE_FIPS = [
    "01", "04", "05", "06", "08", "09", "10", "11", "12", "13",
    "16", "17", "18", "19", "20", "21", "22", "23", "24", "25",
    "26", "27", "28", "29", "30", "31", "32", "33", "34", "35",
    "36", "37", "38", "39", "40", "41", "42", "44", "45", "46",
    "47", "48", "49", "50", "51", "53", "54", "55", "56",
]


# ---------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------

def setup_logging(log_path):
    """
    Log to both console and a persistent file. Mirrors
    gee_extract_utils.setup_logging -- reimplemented rather than imported
    to avoid pulling earthengine-api into the population stage.
    """
    log_path = Path(log_path)
    log_path.parent.mkdir(parents=True, exist_ok=True)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[logging.FileHandler(log_path), logging.StreamHandler()],
        force=True,
    )
    logging.info("Logging to %s", log_path)


# ---------------------------------------------------------------------
# FIPS crosswalk
# ---------------------------------------------------------------------

VALID_CHANGE_TYPES = {"rename", "merger", "split", "merge_split"}


def load_fips_crosswalk(path) -> pd.DataFrame:
    """
    Load the static county FIPS-change crosswalk
    (dataCSV/Population/fips_crosswalk_1980_2025.csv).

    10 rows, CONUS + DC, 1981-2025, verified 9/3/26 against the Census
    Bureau's own "Substantial Changes to Counties and County Equivalent
    Entities" decade pages read directly (not via automated page
    summarization, which had missed 2 of the 10). Connecticut's 2022
    planning-region change is deliberately NOT in this file -- planning
    regions don't nest into the legacy counties, so it isn't a
    rename/merger/split relationship at all; 08b_population_ct_towns.py
    handles it by going down to the town level instead.

    Columns: old_geoid, new_geoid, change_type, effective_year, source,
    notes. `#`-prefixed comment lines precede the header.
    """
    path = Path(path)
    crosswalk = pd.read_csv(path, comment="#", dtype=FIPS_DTYPES)

    missing_cols = {
        "old_geoid", "new_geoid", "change_type", "effective_year",
    } - set(crosswalk.columns)
    if missing_cols:
        raise ValueError(f"{path.name}: missing required column(s) {sorted(missing_cols)}")

    crosswalk["effective_year"] = crosswalk["effective_year"].astype(int)

    bad_types = set(crosswalk["change_type"]) - VALID_CHANGE_TYPES
    if bad_types:
        raise ValueError(
            f"{path.name}: unrecognized change_type value(s) {sorted(bad_types)}. "
            f"Valid: {sorted(VALID_CHANGE_TYPES)}"
        )

    # A given old_geoid must not be mapped twice -- that would make the
    # recode order-dependent, which is exactly the kind of silent
    # ambiguity this file exists to remove.
    has_old = crosswalk["old_geoid"].notna()
    duplicated_olds = crosswalk.loc[has_old, "old_geoid"]
    duplicated_olds = duplicated_olds[duplicated_olds.duplicated()]
    if len(duplicated_olds):
        raise ValueError(
            f"{path.name}: old_geoid appears in more than one row "
            f"({sorted(set(duplicated_olds))}) -- the recode would be "
            "order-dependent. Resolve before using."
        )

    # "split" rows describe a county created from PARTS of one or more
    # parents; there is no single valid old_geoid, so the column is blank
    # by design and the parent(s) live in `notes`.
    splits_with_old = crosswalk[(crosswalk["change_type"] == "split") & has_old]
    if len(splits_with_old):
        raise ValueError(
            f"{path.name}: 'split' rows must leave old_geoid blank "
            f"(offending new_geoid: {splits_with_old['new_geoid'].tolist()})"
        )

    logging.info(
        "Loaded FIPS crosswalk: %d rows (%s)",
        len(crosswalk),
        ", ".join(
            f"{n} {t}" for t, n in crosswalk["change_type"].value_counts().items()
        ),
    )
    return crosswalk


def apply_fips_crosswalk(
    df: pd.DataFrame,
    crosswalk: pd.DataFrame,
    *,
    geoid_col: str = "geoid",
    year_col: str = "year",
    value_col: str = "population",
    group_cols: tuple = ("agegrp",),
) -> pd.DataFrame:
    """
    Recode `df`'s geoid column onto the TIGER/2018 FIPS set. Returns a new
    DataFrame; never mutates `df`.

    Adds POP_FLAG_COL (NA where clean). Behaviour by change_type:

    rename   -- relabel old_geoid -> new_geoid, ALL years (see module
                docstring note 2). Same geography, no value change.

    merger   -- relabel, ALL years, then sum within
                (new_geoid, year, *group_cols). In post-change years the
                source already reports only the survivor, so nothing is
                summed; in pre-change years the absorbed county's
                population is correctly folded into the survivor, which is
                what makes every year comparable to the 2018 unit.

    split    -- the new county's territory belonged to a parent before
                effective_year. Two consequences, both flagged, neither
                fabricated:
                  * child, year < effective_year: no separable population
                    exists. Left absent here; the spine reindex in
                    reindex_to_county_universe() materialises the row and
                    this function's flag text is attached there.
                  * parent, year < effective_year: the parent's reported
                    population INCLUDES territory that is a different
                    county in 2018 geography, so the series has a real
                    discontinuity at effective_year. Flagged, value kept
                    (dropping it would throw away good data for a small
                    boundary effect; county FE absorbs the level, and the
                    flag is what makes the break visible in the appendix).
                Areal apportionment is deliberately NOT attempted: this
                is a rate DENOMINATOR. Back-apportioning Broomfield to
                1981 would manufacture a denominator for county-years
                whose collision numerator is structurally zero (pre-2001
                Broomfield crashes were filed under the four parents),
                producing a fake ~0 collision rate for two decades. NaN
                correctly drops those rows from the regression.

    merge_split -- old_geoid dissolves into MULTIPLE targets (only
                Yellowstone NP/MT, 30113 -> 30031;30067). Assigning the
                whole value to one target or splitting it evenly are both
                fabrication. The old rows are dropped (30113 is not a 2018
                geoid) and the magnitude dropped is logged so its
                materiality is visible rather than assumed; the targets'
                pre-change rows are flagged as marginally under-inclusive.
    """
    out = df.copy()
    if POP_FLAG_COL not in out.columns:
        out[POP_FLAG_COL] = pd.NA

    group_cols = [c for c in group_cols if c in out.columns]
    relabelled = summed = flagged = dropped = 0

    # --- rename + merger: unconditional relabel, then sum -------------
    relabel_rows = crosswalk[crosswalk["change_type"].isin(["rename", "merger"])]
    mapping = dict(zip(relabel_rows["old_geoid"], relabel_rows["new_geoid"]))
    if mapping:
        to_relabel = out[geoid_col].isin(mapping)
        relabelled = int(to_relabel.sum())
        if relabelled:
            out.loc[to_relabel, geoid_col] = out.loc[to_relabel, geoid_col].map(mapping)

            # Collapse any (geoid, year, *group) now duplicated by a merger.
            key = [geoid_col, year_col, *group_cols]
            before = len(out)
            agg = {value_col: "sum"}
            for col in out.columns:
                if col in key or col == value_col:
                    continue
                agg[col] = "first"
            out = out.groupby(key, as_index=False, dropna=False).agg(agg)
            summed = before - len(out)

    # --- split: flag the parent's pre-change years --------------------
    for row in crosswalk[crosswalk["change_type"] == "split"].itertuples():
        for parent in _parse_parent_geoids(row.notes):
            mask = (out[geoid_col] == parent) & (out[year_col] < row.effective_year)
            if mask.any():
                out.loc[mask, POP_FLAG_COL] = (
                    f"includes territory that became {row.new_geoid} in "
                    f"{row.effective_year}; discontinuity at {row.effective_year}"
                )
                flagged += int(mask.sum())

    # --- merge_split: drop the dissolved county, flag the targets -----
    for row in crosswalk[crosswalk["change_type"] == "merge_split"].itertuples():
        mask = out[geoid_col] == row.old_geoid
        if mask.any():
            magnitude = out.loc[mask, value_col].sum()
            years = sorted(out.loc[mask, year_col].unique())
            logging.warning(
                "merge_split: dropping %d row(s) for %s (years %s-%s, summed %s = %s). "
                "Not apportioned between %s -- see crosswalk notes.",
                int(mask.sum()), row.old_geoid, years[0], years[-1],
                value_col, f"{magnitude:,.0f}", row.new_geoid,
            )
            dropped += int(mask.sum())
            out = out[~mask]

        for target in str(row.new_geoid).split(";"):
            t_mask = (out[geoid_col] == target.strip()) & (out[year_col] < row.effective_year)
            if t_mask.any():
                out.loc[t_mask, POP_FLAG_COL] = (
                    f"excludes {row.old_geoid}, which was absorbed in "
                    f"{row.effective_year} and is not separable"
                )
                flagged += int(t_mask.sum())

    logging.info(
        "Crosswalk applied: %d row(s) relabelled, %d collapsed by merger, "
        "%d flagged, %d dropped (merge_split).",
        relabelled, summed, flagged, dropped,
    )
    return out.reset_index(drop=True)


def _parse_parent_geoids(notes) -> list:
    """
    Pull parent county FIPS codes out of a crosswalk `notes` string.

    Parents live in prose because a split can have several of them
    (Broomfield has four) and there is no single old_geoid to put in a
    column. The convention the crosswalk file follows is that every
    parent appears as a bare 5-digit code inside parentheses, e.g.
    "created from parts of Adams (08001) / Boulder (08013) / ...".
    """
    import re

    if not isinstance(notes, str):
        return []
    return re.findall(r"\((\d{5})\)", notes)


# ---------------------------------------------------------------------
# Age handling
# ---------------------------------------------------------------------

def collapse_to_county_year_age(
    df: pd.DataFrame, *, value_col: str = "population"
) -> pd.DataFrame:
    """
    Sum over every dimension except (geoid, year, agegrp).

    Sources ship population broken out by sex and race (and sometimes
    Hispanic origin). Eyal's 9/1 spec is total population and age shares
    only -- "all ages, all sexes at birth" -- so sex and race are collapsed
    here, never carried downstream. Doing it in one place rather than per
    fetcher keeps the four sources from disagreeing about what "total"
    means.
    """
    keep = ["geoid", "year", "agegrp"]
    id_extras = [c for c in ID_COLS if c != "geoid" and c in df.columns]
    passthrough = [c for c in ("source", "is_intercensal") if c in df.columns]

    agg = {value_col: "sum"}
    for col in id_extras + passthrough:
        agg[col] = "first"

    return df.groupby(keep, as_index=False, dropna=False).agg(agg)


def detect_agegrp_encoding(
    df: pd.DataFrame, *, source_name: str, value_col: str = "population",
    tolerance: float = 0.001,
) -> str:
    """
    Work out, from the numbers themselves, which AGEGRP convention a
    source uses. Returns "standard", "stch_icen", or "stch_icen_99".

    THREE conventions appear across the five Census products in this
    pipeline, all using the same column name and overlapping code values:

      standard      cc-est2020int, cc-est2025
                    0 = TOTAL, 1 = 0-4, 2 = 5-9 ... 18 = 85+
      stch_icen     1990s intercensal API
                    0 = under 1, 1 = 1-4, 2 = 5-9 ... 18 = 85+, NO total
      stch_icen_99  co-est00int (2000s)
                    same bins as stch_icen, but the total sits at code 99

    Detecting rather than declaring is deliberate: a per-source config
    value is only as good as whoever typed it, whereas "does code 0 equal
    the sum of codes 1-18?" is checkable arithmetic that cannot be wrong
    about the file in front of it.
    """
    codes = {int(c) for c in df["agegrp"].unique()}

    if AGEGRP_ALT_TOTAL_CODE in codes:
        logging.info(
            "[%s] AGEGRP encoding: stch_icen_99 (total at code %d, 0 = under 1).",
            source_name, AGEGRP_ALT_TOTAL_CODE,
        )
        return "stch_icen_99"

    keys = ["geoid", "year"]
    zero = df[df["agegrp"] == 0].groupby(keys)[value_col].sum()
    bins = df[df["agegrp"].between(1, 18)].groupby(keys)[value_col].sum()
    comparison = pd.concat([zero.rename("zero"), bins.rename("bins")], axis=1).dropna()

    if comparison.empty:
        raise ValueError(
            f"[{source_name}] cannot detect the AGEGRP encoding: no county-year has both "
            f"a code-0 row and codes 1-18. Codes present: {sorted(codes)}."
        )

    rel = ((comparison["bins"] - comparison["zero"]).abs()
           / comparison["zero"].clip(lower=1)).median()

    if rel <= tolerance:
        logging.info("[%s] AGEGRP encoding: standard (code 0 is the total).", source_name)
        return "standard"

    logging.info(
        "[%s] AGEGRP encoding: stch_icen (code 0 is under-1, not a total -- "
        "codes 1-18 exceed it by %.0fx).", source_name, rel,
    )
    return "stch_icen"


def normalize_agegrp(
    df: pd.DataFrame, *, source_name: str, value_col: str = "population"
) -> pd.DataFrame:
    """
    Convert any of the three AGEGRP conventions to this project's
    standard: 0 = total, 1 = 0-4, 2 = 5-9 ... 18 = 85+.

    For the two STCH-ICEN variants, codes 0 and 1 are added together to
    form the 0-4 bucket -- the step that would otherwise drop every child
    under one -- and codes 2-18 keep their numbers, because from 5-9
    upward the schemes already agree. Where the source ships its own total
    (code 99) it is used to CHECK the synthesized one before being
    dropped, rather than simply discarded.
    """
    encoding = detect_agegrp_encoding(df, source_name=source_name, value_col=value_col)
    if encoding == "standard":
        return df

    out = df.copy()
    keys = [c for c in ("geoid", "year") if c in out.columns]
    passthrough = {
        c: "first" for c in out.columns if c not in keys + ["agegrp", value_col]
    }

    published_total = None
    if encoding == "stch_icen_99":
        published_total = (
            out[out["agegrp"] == AGEGRP_ALT_TOTAL_CODE]
            .groupby(keys)[value_col].sum()
        )
        out = out[out["agegrp"] != AGEGRP_ALT_TOTAL_CODE]

    # Fold under-1 (code 0) into 1-4 (code 1) to make the 0-4 bucket.
    out["agegrp"] = out["agegrp"].astype(int).clip(lower=1)
    buckets = out.groupby(keys + ["agegrp"], as_index=False).agg(
        {value_col: "sum", **passthrough}
    )

    totals = buckets.groupby(keys, as_index=False).agg({value_col: "sum", **passthrough})
    totals["agegrp"] = AGEGRP_TOTAL_CODE

    if published_total is not None:
        check = totals.set_index(keys)[value_col]
        joined = pd.concat(
            [check.rename("ours"), published_total.rename("theirs")], axis=1
        ).dropna()
        rel = ((joined["ours"] - joined["theirs"]).abs()
               / joined["theirs"].clip(lower=1))
        if rel.max() > 0.001:
            worst = rel.idxmax()
            raise ValueError(
                f"[{source_name}] our synthesized total disagrees with the source's own "
                f"code-{AGEGRP_ALT_TOTAL_CODE} total by up to {rel.max():.3%} "
                f"(worst: {worst}). The bins are not partitioning the population."
            )
        logging.info(
            "[%s] synthesized totals match the source's own code-%d total across "
            "%d county-years (max difference %.5f%%).",
            source_name, AGEGRP_ALT_TOTAL_CODE, len(joined), rel.max() * 100,
        )

    combined = pd.concat([totals, buckets], ignore_index=True)
    logging.info(
        "[%s] converted %s -> standard encoding (%d total rows synthesized).",
        source_name, encoding, len(totals),
    )
    return combined.sort_values(keys + ["agegrp"]).reset_index(drop=True)


def assert_agegrp_encoding(df: pd.DataFrame, *, source_name: str, tolerance: float = 0.001):
    """
    Verify that AGEGRP means what AGE_BUCKETS says it means, by checking
    that codes 1-18 reconcile to code 0 (the source's own total row).

    This exists because the Census API does NOT publish a code list for
    AGEGRP in variables.json -- the encoding is an assumption there, and a
    wrong assumption would shift every age bucket by one and silently drop
    the under-5s (which is exactly what happens if the 1990s fixed-width
    convention is in play instead). Cheap, and it catches the failure at
    the source rather than 3 stages downstream.

    Raises rather than warns: a frame that fails this is not usable.
    """
    codes = set(df["agegrp"].unique())

    if AGEGRP_TOTAL_CODE not in codes:
        raise ValueError(
            f"[{source_name}] no AGEGRP == {AGEGRP_TOTAL_CODE} (total) rows found. "
            f"Codes present: {sorted(codes)}. If this source has no total row it may "
            "be using the STCH-ICEN 1990s encoding (0 = under 1, no total) -- see "
            "detect_agegrp_encoding, which documents all three conventions."
        )

    unexpected = codes - set(AGE_BUCKETS) - {AGEGRP_TOTAL_CODE}
    if unexpected:
        raise ValueError(
            f"[{source_name}] unexpected AGEGRP code(s) {sorted(unexpected)}; "
            f"expected {AGEGRP_TOTAL_CODE} plus 1-18."
        )

    totals = (
        df[df["agegrp"] == AGEGRP_TOTAL_CODE]
        .set_index(["geoid", "year"])["population"]
    )
    summed = (
        df[df["agegrp"] != AGEGRP_TOTAL_CODE]
        .groupby(["geoid", "year"])["population"].sum()
    )

    comparison = pd.concat([totals.rename("total"), summed.rename("summed")], axis=1).dropna()
    if comparison.empty:
        raise ValueError(f"[{source_name}] could not compare totals to summed age buckets.")

    rel_diff = (comparison["summed"] - comparison["total"]).abs() / comparison["total"].clip(lower=1)
    worst = rel_diff.max()
    if worst > tolerance:
        offenders = rel_diff[rel_diff > tolerance].head(5)
        raise ValueError(
            f"[{source_name}] AGEGRP codes 1-18 do not sum to the AGEGRP == 0 total "
            f"(worst relative difference {worst:.4%}, tolerance {tolerance:.2%}). "
            f"The age encoding is not what AGE_BUCKETS assumes. Worst offenders:\n"
            f"{offenders.to_string()}"
        )

    logging.info(
        "[%s] AGEGRP encoding verified: codes 1-18 reconcile to the total "
        "(worst relative difference %.5f%%, %d county-years checked).",
        source_name, worst * 100, len(comparison),
    )


def compute_age_shares(df: pd.DataFrame) -> pd.DataFrame:
    """
    Pivot long AGEGRP rows into one row per (geoid, year) with a
    `population` total and 18 `pop_share_*` columns.

    Wide, not long, because these are regression controls -- columns in a
    Stata county-year panel, per Eyal's 9/1 spec ("population share in an
    age category"). Shares, not counts: counts stay out and are
    recoverable as share x population.

    Rows whose age detail is missing or inconsistent keep their total
    population and get AGE_FLAG_COL set, so a hole in the age series never
    blanks out the denominator.
    """
    long = df.copy()
    long["agegrp"] = long["agegrp"].astype(int)

    totals = (
        long[long["agegrp"] == AGEGRP_TOTAL_CODE]
        .drop(columns=["agegrp"])
        .rename(columns={"population": "population"})
    )

    buckets = long[long["agegrp"] != AGEGRP_TOTAL_CODE].copy()
    buckets["bucket"] = buckets["agegrp"].map(AGE_BUCKETS)

    wide = buckets.pivot_table(
        index=["geoid", "year"], columns="bucket", values="population", aggfunc="sum"
    )
    wide.columns = [f"pop_share_{c}" for c in wide.columns]
    wide = wide.reindex(columns=AGE_SHARE_COLS)

    denominator = wide.sum(axis=1, min_count=1)
    wide = wide.div(denominator, axis=0)

    out = totals.merge(wide.reset_index(), on=["geoid", "year"], how="outer")

    if AGE_FLAG_COL not in out.columns:
        out[AGE_FLAG_COL] = pd.NA

    share_sum = out[AGE_SHARE_COLS].sum(axis=1, min_count=1)
    incomplete = share_sum.isna() | ((share_sum - 1).abs() > 0.001)
    if incomplete.any():
        out.loc[incomplete, AGE_FLAG_COL] = out.loc[incomplete, AGE_FLAG_COL].fillna(
            "age detail unavailable or does not sum to 1"
        )
        out.loc[incomplete, AGE_SHARE_COLS] = pd.NA
        logging.warning(
            "%d county-year(s) have unusable age detail; shares set to NA and flagged "
            "(total population retained).",
            int(incomplete.sum()),
        )

    return out


# ---------------------------------------------------------------------
# County universe / spine
# ---------------------------------------------------------------------

def load_county_universe(weather_panel_path) -> pd.DataFrame:
    """
    Read the project's county universe from the weather panel itself.

    The universe is TIGER/2018/Counties, CONUS + DC -- 3,108 geoids as of
    the 9/3/26 check. Deriving it from the weather panel rather than
    hardcoding a count means the population panel cannot silently drift
    away from the thing it has to merge with.

    NOTE: take the GEOID SET from this file, not the year range. The PRISM
    CSVs currently in dataCSV/ are the 2020-2021 test-run slice; the full
    1981-2025 extraction lives on Kodama.
    """
    weather = pd.read_csv(weather_panel_path, dtype=FIPS_DTYPES, usecols=ID_COLS)
    universe = weather.drop_duplicates(subset=["geoid"]).sort_values("geoid")

    logging.info(
        "County universe: %d geoids from %s",
        len(universe), Path(weather_panel_path).name,
    )
    return universe.reset_index(drop=True)


def reindex_to_county_universe(
    panel: pd.DataFrame, universe: pd.DataFrame, years, crosswalk: pd.DataFrame
) -> pd.DataFrame:
    """
    Expand `panel` to the full (universe x years) spine, so a missing
    county-year becomes an explicit flagged row rather than an absent one.

    Rows materialised here fall into two groups:
      * structurally impossible -- a split county before it existed
        (Broomfield 1981-2000). Flagged with the reason, population NaN.
        Expected; not a defect.
      * everything else -- a genuine gap worth investigating, flagged as
        such so it shows up in the review file.

    The weather panel has the opposite property and the asymmetry is worth
    stating: weather is COMPUTED over 2018 polygons for every year, so
    Broomfield has weather back to 1981. Population cannot, because nobody
    enumerated that polygon before 2001. Weather present + population NaN
    is the correct output for those county-years, not a bug to repair.
    """
    spine = (
        universe.assign(key=1)
        .merge(pd.DataFrame({"year": list(years), "key": 1}), on="key")
        .drop(columns="key")
    )

    merged = spine.merge(
        panel.drop(columns=[c for c in ID_COLS if c != "geoid" and c in panel.columns]),
        on=["geoid", "year"],
        how="left",
    )

    if POP_FLAG_COL not in merged.columns:
        merged[POP_FLAG_COL] = pd.NA

    missing = merged["population"].isna()

    # Pre-existence of split counties: expected, explain it precisely.
    for row in crosswalk[crosswalk["change_type"] == "split"].itertuples():
        pre_existence = missing & (merged["geoid"] == row.new_geoid) & (
            merged["year"] < row.effective_year
        )
        if pre_existence.any():
            merged.loc[pre_existence, POP_FLAG_COL] = (
                f"county created {row.effective_year} from parts of other counties; "
                "no separable population exists at county level before then"
            )

    still_unexplained = missing & merged[POP_FLAG_COL].isna()
    if still_unexplained.any():
        merged.loc[still_unexplained, POP_FLAG_COL] = "no source covered this county-year"
        logging.warning(
            "%d county-year(s) have no population from any source and no structural "
            "explanation -- see the review-flags file.",
            int(still_unexplained.sum()),
        )

    logging.info(
        "Spine: %d county-years (%d geoids x %d years); %d missing population "
        "(%d structurally expected).",
        len(merged), len(universe), len(list(years)), int(missing.sum()),
        int(missing.sum() - still_unexplained.sum()),
    )
    return merged


# ---------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------

def write_panel_outputs(panel: pd.DataFrame, csv_path, dta_path=None):
    """
    Write the panel to CSV and (optionally) Stata .dta.

    The .dta matters because it is what this week's merge script consumes:
    a CSV that Stata has to `import delimited` with the right stringcols
    is a footgun at exactly the step where a dropped leading zero would
    lose every Alabama county silently.
    """
    csv_path = Path(csv_path)
    csv_path.parent.mkdir(parents=True, exist_ok=True)

    for col in ("geoid", "state_fips", "county_fips"):
        if col in panel.columns:
            panel[col] = panel[col].astype(str)

    panel.to_csv(csv_path, index=False)
    logging.info("Wrote %s (%d rows, %d cols)", csv_path, len(panel), panel.shape[1])

    if dta_path is None:
        return

    dta_path = Path(dta_path)
    stata = panel.copy()

    # Stata has no NA for strings and dislikes pandas' object-NA mix.
    for col in stata.columns:
        if stata[col].dtype == object:
            stata[col] = stata[col].fillna("").astype(str)

    # Variable labels carry the documentation into the .dta, per CLAUDE.md's
    # "document every variable produced" convention.
    labels = {
        "geoid": "County FIPS (TIGER/2018), string, leading zeros preserved",
        "population": "Total resident population, all ages, all sexes",
        "population_source": "Census product this county-year's total came from",
        "age_source": "Census product this county-year's age detail came from",
        POP_FLAG_COL: "Non-empty if total population is missing//approximate",
        AGE_FLAG_COL: "Non-empty if age shares are missing/unusable",
    }
    for label, col in zip(AGE_BUCKETS.values(), AGE_SHARE_COLS):
        labels[col] = f"Share of population aged {label.replace('_', '-').replace('85plus', '85+')}"

    stata.to_stata(
        dta_path,
        write_index=False,
        variable_labels={k: v[:80] for k, v in labels.items() if k in stata.columns},
        version=118,
    )
    logging.info("Wrote %s (%d rows)", dta_path, len(stata))
