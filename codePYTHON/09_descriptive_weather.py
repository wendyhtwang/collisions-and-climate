"""
Descriptive analysis (Phase 4) for the weather-extraction pipeline: summary
stats tables and trend/volatility/choropleth exhibits built on top of
05_aggregate_daily_to_monthly.py's raw county-year-month means and
06_build_derived_weather_vars.py's derived counts/degree-days.

- PRISM is the main dataset; ERA5 runs through the same DatasetConfig-driven
  loop as a robustness check, not a co-equal output. (See project memory:
  "Weather pipeline dataset roles.")
- Two-tier exhibit set, per Eyal (8/18/26 meeting w/ Nicole):
    1. SANITY_CHECK tier -- quick/unstyled figures for internal QA (values
       in plausible ranges, rough trends/distributions). Fully implemented
       below -- this is the proof-of-concept to run against the full
       county-year-month panel on Kodama (1M+ rows for PRISM alone).
    2. POLISHED tier -- paper/appendix-ready exhibits illustrating (a)
       long-run winter warming and (b) anomalous-winter shocks, the two
       "key driving forces" Eyal flagged. Still stubbed (NotImplementedError)
       -- main() catches that and reports it rather than crashing, so a
       live run still completes Tier 1 cleanly.
- "Winter" = Dec(t-1) + Jan(t) + Feb(t), grouped under winter_year = t.
  TODO: confirm this convention matches whatever Nicole's population-
  regression side assumes -- this gets shared across the weather/wildlife
  handshake Eyal described.
- Freezing-threshold variables are already split in 06 (per 8/14/26
  meeting): `days_below_freezing_32f` (contemporaneous road-conditions
  covariate) vs. `days_extremely_cold` (0F threshold, the population-
  prediction instrument). 06's derived-var column names (mean_temp_c,
  days_below_freezing_32f, freeze_thaw_days, ...) are identical for PRISM
  and ERA5, so the trend plots below don't need per-dataset column-name
  branching -- only the raw 05-output columns (tmean_mean vs. tmean_c_mean)
  differ by dataset, and this script doesn't touch those.
- Run directly: `python 09_descriptive_weather.py` from codePYTHON/, with
  the repo's dataCSV/ populated (Kodama path, once synced -- see
  DatasetConfig paths below, resolved relative to this file so they work
  unchanged on Kodama or a personal checkout as long as the repo layout
  matches).
- TODO before the Tier 2 choropleth functions can run for real: locate or
  source a CONUS county boundary shapefile.
"""

# Defers evaluation of type annotations (e.g. `str | None` below) to
# strings instead of executing them at import time -- lets this run on
# Python < 3.10 (the `X | Y` union syntax is otherwise only valid at
# runtime on 3.10+). Must be the first non-docstring/comment line.
from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # headless-safe -- Kodama has no display attached
import matplotlib.pyplot as plt
import pandas as pd

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]

FIGURES_DIR = REPO_ROOT / "figures" / "weather"
TABLES_DIR = REPO_ROOT / "tables" / "weather"

WINTER_MONTHS = {12, 1, 2}  # Dec, Jan, Feb

# Below this many distinct years present, the POLISHED-tier exhibits don't
# mean much yet (decade comparisons need multiple decades; anomaly
# detection needs a real multi-year baseline per county). Arbitrary
# starting threshold -- revisit once we know how ugly the small-n case
# looks. The full 1981-2025 extraction (45 years) clears this easily.
MIN_YEARS_FOR_POLISHED_TIER = 20

# Proof-of-concept state for the per-county spaghetti plot -- Illinois.
# Swap for whichever state is most useful to show Eyal; falls back to
# whatever state actually has data if this one is missing (see
# run_sanity_check_tier).
PROOF_OF_CONCEPT_STATE_FIPS = "17"


class DatasetConfig:
    """Per-dataset paths, mirroring 06_build_derived_weather_vars.py's
    DatasetConfig pattern so PRISM/ERA5 run through identical logic."""

    def __init__(self, name: str, monthly_path: Path, derived_path: Path, is_primary: bool = False):
        self.name = name
        self.monthly_path = monthly_path
        self.derived_path = derived_path
        self.is_primary = is_primary  # PRISM = True (main dataset); ERA5 = robustness check


PRISM_CONFIG = DatasetConfig(
    name="PRISM",
    monthly_path=REPO_ROOT / "dataCSV" / "PRISM" / "prism_county_month.csv",
    derived_path=REPO_ROOT / "dataCSV" / "PRISM" / "prism_derived_weather_vars.csv",
    is_primary=True,
)

ERA5_CONFIG = DatasetConfig(
    name="ERA5",
    monthly_path=REPO_ROOT / "dataCSV" / "ERA5" / "era5_county_month.csv",
    derived_path=REPO_ROOT / "dataCSV" / "ERA5" / "era5_derived_weather_vars.csv",
    is_primary=False,
)


# ---------------------------------------------------------------------
# Load + merge one dataset's county-year-month panel
# ---------------------------------------------------------------------

def load_weather_panel(config: DatasetConfig) -> pd.DataFrame:
    """Merge 05's raw monthly means with 06's derived vars into one
    county-year-month panel, keyed on geoid + year + month.

    Merging on geoid alone (not the full ID_COLS) is deliberate: geoid
    already uniquely identifies a county, and merging on the free-text
    county_name too risks a silent non-match from a formatting difference
    between the two scripts' outputs. monthly's copies of state_fips/
    county_fips/county_name are kept as canonical; derived's are dropped.
    """
    dtype = {"geoid": str, "state_fips": str, "county_fips": str}

    print(f"Loading {config.name} monthly panel from:\n  {config.monthly_path}")
    monthly = pd.read_csv(config.monthly_path, dtype=dtype)
    print(f"  {len(monthly):,} rows.")

    print(f"Loading {config.name} derived weather vars from:\n  {config.derived_path}")
    derived = pd.read_csv(config.derived_path, dtype=dtype)
    print(f"  {len(derived):,} rows.")

    merge_keys = ["geoid", "year", "month"]
    redundant_id_cols = [c for c in ID_COLS if c != "geoid"]

    # 05 and 06 both independently compute n_days/expected_days/
    # is_incomplete[/dataset_types for PRISM] from the same daily source --
    # check they agree before dropping derived's copies, so a silent
    # divergence between the two scripts doesn't go unnoticed.
    qa_cols = [
        c for c in ("n_days", "expected_days", "is_incomplete", "dataset_types")
        if c in monthly.columns and c in derived.columns
    ]
    if qa_cols:
        check = monthly[merge_keys + qa_cols].merge(
            derived[merge_keys + qa_cols], on=merge_keys, suffixes=("_monthly", "_derived")
        )
        for col in qa_cols:
            mismatched = check[f"{col}_monthly"] != check[f"{col}_derived"]
            if mismatched.any():
                print(
                    f"  Warning: {mismatched.sum():,} row(s) where '{col}' "
                    f"disagrees between the monthly and derived {config.name} "
                    "files -- investigate before trusting either QA column."
                )

    derived_slim = derived.drop(columns=redundant_id_cols + qa_cols)

    merged = monthly.merge(
        derived_slim, on=merge_keys, how="outer", indicator=True, validate="one_to_one"
    )

    unmatched = merged[merged["_merge"] != "both"]
    if not unmatched.empty:
        print(
            f"  Warning: {len(unmatched):,} county-month row(s) present in only "
            f"one of the monthly/derived {config.name} files -- see the "
            "'_merge' column before treating this panel as complete."
        )
    merged = merged.drop(columns="_merge")

    print(
        f"  Merged panel: {len(merged):,} county-month rows, "
        f"{merged['geoid'].nunique():,} counties, "
        f"{merged['year'].nunique()} year(s) "
        f"({merged['year'].min()}-{merged['year'].max()})."
    )
    return merged


def add_winter_year(df: pd.DataFrame) -> pd.DataFrame:
    """December rows belong to the *following* winter_year; Jan/Feb rows
    belong to their own calendar year's winter_year. e.g. Dec 2020, Jan
    2021, and Feb 2021 all get winter_year == 2021.

    TODO: confirm this is the convention Nicole's LASSO variable-selection
    step (population ~ lagged winter weather) will assume -- Eyal
    described this as a shared "handshake" between the weather and
    wildlife sides, so it should be settled once, not decided twice.
    """
    df = df.copy()
    df["winter_year"] = df["year"] + (df["month"] == 12).astype(int)
    return df


def restrict_to_winter(df: pd.DataFrame, complete_only: bool = True) -> pd.DataFrame:
    """Filter to Dec/Jan/Feb rows -- most Phase 4 exhibits are winter-only.

    complete_only=True (default) also drops the boundary winter_year(s)
    that can't have all 3 months present for a given county: the panel's
    very first winter_year has Jan/Feb only (no preceding Dec), and its
    very last has Dec only (no following Jan/Feb). Left in, those show up
    as partial "winters" on a trend/spaghetti plot -- e.g. a single Dec
    reading plotted as if it were a full winter mean, which reads as a
    misleading jump. Mirrors 05/06's convention of flagging incompleteness
    rather than silently averaging over it.
    """
    winter = df[df["month"].isin(WINTER_MONTHS)].copy()
    if not complete_only:
        return winter

    winter["_n_months_in_winter"] = winter.groupby(["geoid", "winter_year"])["month"].transform("nunique")
    incomplete_years = sorted(int(y) for y in winter.loc[winter["_n_months_in_winter"] < 3, "winter_year"].unique())
    if incomplete_years:
        print(
            f"  Note: dropping partial-winter row(s) for winter_year(s) "
            f"{incomplete_years} -- missing Dec and/or Jan/Feb at the panel's "
            "date boundary."
        )
    return winter[winter["_n_months_in_winter"] == 3].drop(columns="_n_months_in_winter")


# Columns that aren't weather variables -- excluded from summary_stats_table's
# auto-detected variable list.
_NON_WEATHER_COLS = {
    *ID_COLS, "year", "month", "winter_year",
    "n_days", "expected_days", "is_incomplete", "dataset_types",
}


def _weather_variable_columns(df: pd.DataFrame) -> list:
    """Every numeric column that isn't an ID/year/month/QA column."""
    return [
        c for c in df.columns
        if c not in _NON_WEATHER_COLS and pd.api.types.is_numeric_dtype(df[c])
    ]


# ---------------------------------------------------------------------
# TIER 1 -- sanity-check exhibits (fully implemented; run against the full
# panel on Kodama for today's proof of concept)
# ---------------------------------------------------------------------

def summary_stats_table(df: pd.DataFrame, by: str | None = None) -> pd.DataFrame:
    """One row per weather variable (by=None, pooled) or one row per
    group x variable (by="county" -> geoid, by="month" -> month):
    mean / sd / min / max / n. Matches the task-doc line item verbatim:
    'summary statistics tables for all weather variables, by county, by
    month, and pooled.'
    """
    variables = _weather_variable_columns(df)

    if by is None:
        stats = df[variables].agg(["mean", "std", "min", "max", "count"]).T
        stats.index.name = "variable"
        return stats.reset_index()

    group_col = {"county": "geoid", "month": "month"}.get(by)
    if group_col is None:
        raise ValueError(f"Unsupported `by` value: {by!r} (expected None, 'county', or 'month')")

    grouped = df.groupby(group_col)[variables].agg(["mean", "std", "min", "max", "count"])
    grouped.columns = [f"{var}_{stat}" for var, stat in grouped.columns]
    return grouped.reset_index()


def _set_year_axis_limits(ax, year_values):
    """Explicit x-limits with padding. matplotlib's autoscale on a single
    distinct x-value (as with today's 2-year PRISM test panel, which has
    only one complete winter after restrict_to_winter's boundary-drop)
    otherwise defaults to a huge, unreadable date-like range -- this
    keeps sparse-data sanity-check runs legible, not just the eventual
    45-year panel.
    """
    year_min, year_max = year_values.min(), year_values.max()
    pad = max(1, round(0.05 * (year_max - year_min)))
    ax.set_xlim(year_min - pad, year_max + pad)


def plot_national_trend(df: pd.DataFrame, variable: str, dataset_name: str, year_col: str = "winter_year"):
    """National mean of `variable` by year. Pass a winter-restricted df
    for the winter-temp / freezing-days / freeze-thaw-days trend asks.
    Unstyled -- sanity-check tier, not the paper version.
    """
    national = df.groupby(year_col)[variable].mean().reset_index()

    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(national[year_col], national[variable], marker="o", markersize=4, linewidth=1)
    _set_year_axis_limits(ax, national[year_col])
    ax.set_xlabel(year_col.replace("_", " ").title())
    ax.set_ylabel(variable)
    ax.set_title(f"[{dataset_name}] National mean {variable} by {year_col} -- SANITY CHECK, unstyled")

    out_path = FIGURES_DIR / f"{dataset_name.lower()}_sanity_national_trend_{variable}.png"
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {out_path}")
    return out_path


def plot_state_small_multiples(df: pd.DataFrame, variable: str, dataset_name: str, year_col: str = "winter_year"):
    """One subplot per state, state-mean trend line of `variable`."""
    state_year = df.groupby(["state_fips", year_col])[variable].mean().reset_index()
    states = sorted(state_year["state_fips"].unique())
    n_states = len(states)

    n_cols = 6
    n_rows = -(-n_states // n_cols)  # ceil division
    fig, axes = plt.subplots(
        n_rows, n_cols, figsize=(2.4 * n_cols, 1.8 * n_rows), sharex=True, sharey=True
    )
    axes = axes.flatten()

    for ax, state in zip(axes, states):
        sub = state_year[state_year["state_fips"] == state]
        ax.plot(sub[year_col], sub[variable], marker="o", markersize=2, linewidth=1)
        ax.set_title(state, fontsize=8)
        ax.tick_params(labelsize=6)

    _set_year_axis_limits(axes[0], state_year[year_col])  # shared axes -- setting one propagates

    for ax in axes[n_states:]:
        ax.axis("off")

    fig.suptitle(f"[{dataset_name}] State-level mean {variable} by {year_col} -- SANITY CHECK, unstyled")
    fig.tight_layout()

    out_path = FIGURES_DIR / f"{dataset_name.lower()}_sanity_state_small_multiples_{variable}.png"
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {out_path}")
    return out_path


def plot_county_spaghetti(df: pd.DataFrame, variable: str, state_fips: str, dataset_name: str, year_col: str = "winter_year"):
    """Eyal's 8/18 ask: one figure per state, one trend line per county
    within it, to eyeball within-state variation over time -- not just a
    single state-aggregate line.

    Proof-of-concept on a single state here -- with the full panel this
    could be 100+ overlapping lines for a large state, which may need a
    rethink (within-state quartile bands instead of literally every
    county) once we see how it actually looks on real data.
    """
    state_df = df[df["state_fips"] == state_fips]
    if state_df.empty:
        raise ValueError(f"No rows found for state_fips={state_fips!r}")

    county_year = state_df.groupby(["geoid", year_col])[variable].mean().reset_index()

    fig, ax = plt.subplots(figsize=(8, 5))
    for _, sub in county_year.groupby("geoid"):
        ax.plot(sub[year_col], sub[variable], marker="o", markersize=2, linewidth=0.6, alpha=0.5, color="steelblue")
    _set_year_axis_limits(ax, county_year[year_col])

    n_counties = county_year["geoid"].nunique()
    ax.set_xlabel(year_col.replace("_", " ").title())
    ax.set_ylabel(variable)
    ax.set_title(
        f"[{dataset_name}] {variable} by county, state_fips={state_fips} "
        f"({n_counties} counties) -- SANITY CHECK, unstyled"
    )

    out_path = FIGURES_DIR / f"{dataset_name.lower()}_sanity_county_spaghetti_{variable}_state{state_fips}.png"
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {out_path}")
    return out_path


# ---------------------------------------------------------------------
# TIER 2 -- polished/paper exhibits (BLOCKED until the full 1981-2025
# extraction lands -- see MIN_YEARS_FOR_POLISHED_TIER gate in main())
# ---------------------------------------------------------------------

def plot_decade_distributions(df: pd.DataFrame, variable: str, state_fips: str):
    """Overlaid density/histogram of `variable`, one distribution per
    decade, faceted by state -- Eyal's ask for visually showing the
    climate-change shift. Needs several decades of data to say anything.
    """
    raise NotImplementedError


def compute_interannual_std(df: pd.DataFrame, variable: str) -> pd.DataFrame:
    """Std dev of `variable` across years, by county. NOTE: the task doc
    already has 'maps showing regions with highest interannual
    variability' checked off as done -- confirm what that used before
    assuming this duplicates it vs. needs to feed a *new* map.
    """
    raise NotImplementedError


def compute_anomaly_frequency(
    df: pd.DataFrame, variable: str, threshold_sd: float = 1.5
) -> pd.DataFrame:
    """Count of 'anomalously warm' winters per county -- Eyal's 8/18 ask,
    distinct from compute_interannual_std: a county can be volatile
    without having many anomalies, or vice versa (steady but with one or
    two extreme shock years).

    TODO: anomaly definition here (winter mean > county's own long-run
    mean + threshold_sd * county's own std) is a placeholder -- confirm
    the actual definition/threshold with Eyal before treating as final.
    """
    raise NotImplementedError


def map_choropleth(df: pd.DataFrame, variable: str, county_shapefile_path: Path):
    """Shared choropleth renderer for: mean winter temp (early vs. recent
    period), change in mean winter temp over the full sample, and
    anomaly frequency.

    TODO: source a CONUS county boundary shapefile -- check whether one
    already exists in the repo/GEE assets (e.g. via Nicole's WMA
    shapefile work) before pulling a fresh Census TIGER/Line file.

    Color rule (per dataviz skill's color-formula): sequential single hue
    for magnitude exhibits (mean winter temp, anomaly frequency);
    diverging two-hue + neutral-gray-midpoint for the *change*-in-temp
    map, since that's a polarity measure (sign matters -- some counties
    could in principle have cooled). Never a rainbow / default colormap.
    """
    raise NotImplementedError


# ---------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------

def run_sanity_check_tier(df: pd.DataFrame, config: DatasetConfig):
    print(f"\n=== {config.name}: sanity-check tier ===")
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    TABLES_DIR.mkdir(parents=True, exist_ok=True)

    winter = restrict_to_winter(df)

    for by, label in ((None, "pooled"), ("county", "by_county"), ("month", "by_month")):
        table = summary_stats_table(df, by=by)
        out_path = TABLES_DIR / f"{config.name.lower()}_summary_{label}.csv"
        table.to_csv(out_path, index=False)
        print(f"  Saved {out_path} ({len(table):,} rows)")

    trend_vars = ["mean_temp_c", "days_below_freezing_32f", "freeze_thaw_days"]
    for var in trend_vars:
        if var not in winter.columns:
            print(f"  Skipping trend plots for {var!r}: not present in {config.name} panel.")
            continue
        plot_national_trend(winter, var, dataset_name=config.name)
        plot_state_small_multiples(winter, var, dataset_name=config.name)

    available_states = winter["state_fips"].unique()
    poc_state = (
        PROOF_OF_CONCEPT_STATE_FIPS if PROOF_OF_CONCEPT_STATE_FIPS in available_states
        else sorted(available_states)[0]
    )
    if "mean_temp_c" in winter.columns:
        plot_county_spaghetti(winter, "mean_temp_c", state_fips=poc_state, dataset_name=config.name)

    print(f"=== {config.name}: sanity-check tier complete ===")


def run_polished_tier(df: pd.DataFrame, config: DatasetConfig):
    n_years = df["year"].nunique()
    if n_years < MIN_YEARS_FOR_POLISHED_TIER:
        print(
            f"Skipping polished tier for {config.name}: only {n_years} "
            f"year(s) of data (need >= {MIN_YEARS_FOR_POLISHED_TIER}). "
            "Re-run once the full 1981-2025 extraction lands."
        )
        return

    print(f"\n=== {config.name}: polished tier ===")
    winter = restrict_to_winter(df)
    # plot_decade_distributions(winter, "mean_temp_c", state_fips=...)
    # compute_interannual_std(winter, "mean_temp_c")
    # compute_anomaly_frequency(winter, "mean_temp_c")
    # map_choropleth(df, "mean_temp_c", county_shapefile_path=...)
    raise NotImplementedError


def main():
    for config in (PRISM_CONFIG, ERA5_CONFIG):
        if not config.is_primary:
            print(f"\n({config.name} is the robustness-check dataset -- lower priority, get PRISM working first)")

        if not config.monthly_path.exists() or not config.derived_path.exists():
            print(f"Skipping {config.name}: expected input file(s) not found at\n  {config.monthly_path}\n  {config.derived_path}")
            continue

        df = load_weather_panel(config)
        df = add_winter_year(df)

        run_sanity_check_tier(df, config)

        try:
            run_polished_tier(df, config)
        except NotImplementedError:
            print(f"  (Tier 2 / polished exhibits not implemented yet for {config.name} -- Tier 1 output above is complete.)")


if __name__ == "__main__":
    main()
