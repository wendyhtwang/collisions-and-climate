"""
Shared row-filtering logic for the ground-truth sample scripts --
07e_filter_prism_ground_truth_sample.py and
07g_filter_era5_ground_truth_sample.py. Both filter a production
county-month panel down to a small, explicit set of (geoid, year, month)
rows selected for station comparison, and both need to report (rather
than silently drop) any requested row not found in production. Extracted
here since the two scripts had independently written the same filter/
report logic for their respective datasets.
"""

import pandas as pd


def filter_to_target_rows(production: pd.DataFrame, targets, id_cols: list) -> pd.DataFrame:
    """
    Filter `production` down to the exact rows in `targets`.

    `targets` is an iterable of (geoid, year, month) triples -- pulled
    explicitly rather than a cross-product of separate geoid/year/month
    lists, so different counties can be checked against different periods.

    Reports (rather than silently drops) any requested triple not found,
    distinguishing "GEOID not in production at all" from "GEOID exists,
    just not for that year/month". Report order follows `targets`' own
    order, not an arbitrary sort.
    """
    targets = list(targets)
    target_set = set(targets)

    row_key = list(zip(production["geoid"], production["year"], production["month"]))
    selected = production[[key in target_set for key in row_key]].copy()

    found_triples = set(zip(selected["geoid"], selected["year"], selected["month"]))
    geoids_in_production = set(production["geoid"].unique())
    missing = [t for t in targets if t not in found_triples]
    if missing:
        for geoid, year, month in missing:
            reason = (
                "GEOID not in production at all"
                if geoid not in geoids_in_production
                else "GEOID exists, but not for this year/month"
            )
            print(f"Warning: no row for {geoid} {year}-{month:02d} -- {reason}.")

    return selected.sort_values(id_cols + ["year", "month"]).reset_index(drop=True)
