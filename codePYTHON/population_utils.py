"""
Shared helpers for the population-data scripts (08a_population_county.py,
08b_population_ct_towns.py) -- FIPS crosswalk mechanics for reconciling
county identity across 1980-2025.

Mirrors aggregation_utils.py's role for the weather aggregation stage
(05/06) -- see SCRIPT_OVERVIEW.md. resolve_data_root is re-exported from
aggregation_utils.py rather than duplicated, since the logic is identical
(first existing candidate path wins).
"""

from pathlib import Path

import pandas as pd

from aggregation_utils import resolve_data_root  # re-exported, not duplicated

__all__ = ["resolve_data_root", "load_fips_crosswalk", "apply_fips_crosswalk", "FLAG_COL"]

# Column added to any row whose population is reconstructed, approximated,
# or unavailable because of a FIPS change -- never silently drop or
# silently relabel a row; it's either untouched or explicitly flagged.
FLAG_COL = "population_source_note"


def load_fips_crosswalk(path) -> pd.DataFrame:
    """Load the static county FIPS-change crosswalk (see
    dataCSV/Population/fips_crosswalk_1980_2025.csv -- compiled 8/31/26
    from the Census Bureau's official "Substantial Changes to Counties
    and County Equivalent Entities" decade pages, CONUS + DC only,
    1981-2025: 8 rows across rename/merger/split/merge_split. Compiled
    via automated page fetches, not a manual read of the primary source
    -- the file's own header flags it as a strong draft, not final, until
    someone reads the actual Census pages directly. Two rows (Cibola
    County NM, La Paz County AZ) additionally have an unverified parent-
    county FIPS code in their notes -- see the file itself).

    Expected columns (`#`-prefixed header lines above the real header row
    -- pass comment="#" to whatever CSV reader loads this):
        old_geoid      : str, FIPS as it appears in a raw source. Empty/NaN
                          for change_type == "split" (there is no single
                          valid old_geoid for a county created from PARTS
                          of several source counties).
        new_geoid      : str, target 2018 TIGER FIPS (see project memory:
                          county-geometry-vintage). For change_type ==
                          "merge_split" ONLY, this is semicolon-separated
                          (old_geoid dissolves into multiple targets --
                          currently just Montana's Yellowstone NP portion,
                          30113 -> 30031;30067, 1997).
        change_type    : one of "rename", "merger", "split", "merge_split"
        effective_year : int, first year new_geoid should be used instead
                          of old_geoid
        notes          : free text (source, what changed, confidence)

    TODO:
        - read through the actual Census decade pages by hand (see
          module/file header for URLs) to confirm the 8-row list is
          exhaustive for CONUS + DC 1981-2025 -- this was compiled via
          automated fetches of those pages, which could plausibly have
          missed something not called out in the fetched summary
        - resolve the 2 unverified parent-county FIPS codes (Yuma AZ,
          Valencia NM) noted in the file
        - decide how to handle change_type == "merge_split" explicitly
          (currently just Yellowstone/MT) -- population is likely
          negligible (park administrative unit) but unverified; do NOT
          silently pick one of the two targets or split evenly
        - validate on load: every old_geoid appears in at most one row
          per effective_year (no ambiguous mappings); every change_type
          is one of the four valid values
    """
    raise NotImplementedError


def apply_fips_crosswalk(
    df: pd.DataFrame,
    crosswalk: pd.DataFrame,
    *,
    geoid_col: str = "geoid",
    year_col: str = "year",
    value_col: str = "population",
) -> pd.DataFrame:
    """Recode `df`'s geoid column onto the 2018 TIGER FIPS set, using
    `crosswalk` (see load_fips_crosswalk). Returns a new DataFrame --
    never mutates `df` in place.

    TODO, by change_type:
        - "rename": relabel geoid_col -> new_geoid for rows where
          year_col >= effective_year. Purely cosmetic, no value change.
        - "merger": relabel geoid_col -> new_geoid for rows where
          year_col >= effective_year, then
          groupby([new_geoid, year_col])[value_col].sum() so multiple
          old counties' populations combine correctly under the
          surviving 2018 FIPS.
        - "split": do NOT attempt areal apportionment (see
          08a_population_county.py's docstring for why -- this is a
          population DENOMINATOR, not a primary regression variable).
          Instead:
            - year_col >= effective_year: this function does not
              fabricate a row for new_geoid -- if the source itself
              doesn't have one, that's a genuine gap. The calling
              script's FULL_YEAR_RANGE x ID_COLS completeness assertion
              (see 08a's build_population_panel) is what surfaces it,
              not this function.
            - year_col < effective_year: the old source county's
              population is not separable into the pre-existing area
              that later became new_geoid. Set value_col to NaN for
              those rows and add
              FLAG_COL = f"pre-{effective_year} population not
              separable from {new_geoid} at county level (split)"
        - "merge_split" (old_geoid dissolves into MULTIPLE new_geoid
          targets, semicolon-separated -- currently just Yellowstone
          NP/MT, 30113 -> 30031;30067): do NOT silently assign the whole
          value to one target or split it evenly between targets -- both
          are fabrication. Set value_col to NaN for old_geoid's rows at
          year_col >= effective_year and add FLAG_COL = f"{old_geoid}
          dissolved into multiple counties ({new_geoid}) at
          {effective_year}; not auto-apportioned". This is a flag-only
          case, same principle as "split", just approached from the
          other direction.
        - log a one-line summary of rows relabeled / summed / flagged,
          by change_type, so a run's log shows what this step actually
          did
    """
    raise NotImplementedError
