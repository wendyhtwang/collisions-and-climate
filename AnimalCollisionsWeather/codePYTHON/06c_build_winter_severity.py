"""
Builds the Winter Severity Index (WSI) at county-WINTER-YEAR grain from the
county-month derived weather variables 06 writes.

Moved here from SECTION 7 of codeSTATA/build_main_data_county_year.do on
2026-09-17 so a Phase 4 exhibit no longer depends on a Phase 6 output;
definition ported unchanged.

- Kohn (1975) / WI DNR: wsi_cold_days + wsi_snow_days, each a count of
  qualifying days over Dec 1 - Apr 30 (a day meeting both counts in both).
- Winter year t spans Dec(t-1) through Apr(t), WIDER than the DJF window
  mean_winter_temp uses, which stays in the merge.
- Missing propagates, matching Stata's `gen`: any of the five months absent
  makes the season NaN, not a partial sum.
- Snow is a day COUNT, never approximated from mean_snow_depth; the 12in/8in
  variants are sensitivity only. If the ERA5 file is absent or lacks the
  counts, every index is written missing and the cold component still builds.
"""

import argparse
from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]

PRISM_DERIVED_PATH = REPO_ROOT / "dataCSV" / "PRISM" / "prism_derived_weather_vars.csv"
ERA5_DERIVED_PATH = REPO_ROOT / "dataCSV" / "ERA5" / "era5_derived_weather_vars.csv"

OUTPUT_DIR = REPO_ROOT / "dataCSV" / "Weather"
OUTPUT_CSV = OUTPUT_DIR / "winter_severity_county_year.csv"

# Dec of the prior year, then Jan-Apr of the winter year.
PRIOR_YEAR_MONTH = 12
CURRENT_YEAR_MONTHS = (1, 2, 3, 4)

# 18in is Kohn's literature threshold; 12/8 are sensitivity variants.
SNOW_THRESHOLDS_IN = (18, 12, 8)

COLD_COL = "days_extremely_cold"


# ---------------------------------------------------------------------
# Seasonal aggregation
# ---------------------------------------------------------------------


def season_sum(monthly, value_col):
    """Sum value_col over Dec(t-1) + Jan(t)..Apr(t), keyed (geoid, year).

    NaN wherever any of the five months is missing -- Series addition
    propagates NaN, as Stata's `gen a = L1.x + y + ...` did.
    """
    wide = (
        monthly.pivot_table(
            index=["geoid", "year"], columns="month", values=value_col, aggfunc="first"
        )
        .reset_index()
    )

    # December of the PRIOR year: relabel year -> year + 1 and join. A county
    # whose year t-1 row is absent gets no match, i.e. NaN, matching `L1.`.
    if PRIOR_YEAR_MONTH in wide.columns:
        december = wide[["geoid", "year", PRIOR_YEAR_MONTH]].copy()
        december["year"] = december["year"] + 1
        december = december.rename(columns={PRIOR_YEAR_MONTH: "_dec_prior"})
    else:
        december = wide[["geoid", "year"]].copy()
        december["_dec_prior"] = pd.NA

    out = wide[["geoid", "year"]].merge(december, on=["geoid", "year"], how="left")

    total = pd.to_numeric(out["_dec_prior"], errors="coerce")
    for month in CURRENT_YEAR_MONTHS:
        if month in wide.columns:
            total = total + pd.to_numeric(wide[month], errors="coerce")
        else:
            total = total * pd.NA
    out[value_col] = total
    return out[["geoid", "year", value_col]]


def load_monthly(path, required, label):
    """Read a derived-vars CSV, keeping geoid as a string (leading zeroes)."""
    if not path.exists():
        return None, f"{label} derived-vars file not found at {path}"
    frame = pd.read_csv(path, dtype={"geoid": str, "state_fips": str, "county_fips": str})
    missing = [c for c in required if c not in frame.columns]
    if missing:
        return None, f"{label} file is missing {missing}"
    return frame, None


def build(prism_path=PRISM_DERIVED_PATH, era5_path=ERA5_DERIVED_PATH):
    prism, err = load_monthly(prism_path, ["geoid", "year", "month", COLD_COL], "PRISM")
    if prism is None:
        # The cold component is not optional: without it there is no index.
        raise SystemExit(
            f"{err}. Rerun 06_build_derived_weather_vars.py -- {COLD_COL} has been "
            "built since 2026-09-08; a CSV predating that will not have it."
        )

    result = season_sum(prism, COLD_COL).rename(columns={COLD_COL: "wsi_cold_days"})
    print(f"  cold component: {len(result):,} county-years from {prism_path.name}")

    snow_cols = [f"days_snow_depth_{t}in" for t in SNOW_THRESHOLDS_IN]
    era5, err = load_monthly(era5_path, ["geoid", "year", "month"], "ERA5")
    if era5 is None:
        print(f"  NOTE: {err} -- snow component and all indices set to missing.")
        era5 = None

    for threshold, col in zip(SNOW_THRESHOLDS_IN, snow_cols):
        name = "wsi_snow_days" if threshold == 18 else f"wsi_snow_days_{threshold}in"
        if era5 is not None and col in era5.columns:
            seasonal = season_sum(era5, col).rename(columns={col: name})
            result = result.merge(seasonal, on=["geoid", "year"], how="left")
        else:
            if era5 is not None:
                print(
                    f"  NOTE: {col} not in {era5_path.name} -- {name} set to missing. "
                    "Rerun 06_build_derived_weather_vars.py to build it."
                )
            result[name] = pd.NA

    result["winter_severity_index"] = result["wsi_cold_days"] + result["wsi_snow_days"]
    for threshold in (12, 8):
        result[f"winter_severity_index_snow{threshold}"] = (
            result["wsi_cold_days"] + result[f"wsi_snow_days_{threshold}in"]
        )

    return result.sort_values(["geoid", "year"]).reset_index(drop=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prism", type=Path, default=PRISM_DERIVED_PATH)
    parser.add_argument("--era5", type=Path, default=ERA5_DERIVED_PATH)
    parser.add_argument("--out", type=Path, default=OUTPUT_CSV)
    args = parser.parse_args()

    print("Building the Winter Severity Index (county-winter-year)...")
    panel = build(args.prism, args.era5)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    panel.to_csv(args.out, index=False)

    built = panel["winter_severity_index"].notna().sum()
    print(
        f"  {len(panel):,} county-years, {built:,} with a complete index "
        f"({panel['geoid'].nunique():,} counties, "
        f"{panel['year'].min()}-{panel['year'].max()})"
    )
    print(f"Wrote {args.out}")
    print("Winter severity index complete.")


if __name__ == "__main__":
    main()
