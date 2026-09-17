# --- notebook compatibility ------------------------------------------------
# The notebook renders every figure inline; a script does not. matplotlib runs
# headless and the inline preview becomes a no-op, so the figure PDFs are the
# only output either way.
import matplotlib
def display(*args, **kwargs):
    """No-op stand-in for IPython's display() outside a notebook."""
    for item in args:
        try:
            print(item.to_string() if hasattr(item, "to_string") else item)
        except Exception:
            pass
from dataclasses import dataclass
from pathlib import Path
import calendar
import io
import os
import textwrap
import warnings
import geopandas as gpd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from matplotlib.backends.backend_pdf import PdfPages
import numpy as np
import pandas as pd
def resolve_repo_root():
    """Resolve the project checkout on either Kodama or a local Mac.

    Unlike a .py file, a notebook has no reliable __file__. Jupyter's current
    working directory depends on how the server/editor was launched, so search
    plausible roots and accept the first directory with this repo's structure.
    Set COLLISIONS_WEATHER_ROOT to override discovery explicitly.
    """
    cwd = Path.cwd().resolve()
    candidates = []
    env_root = os.environ.get("COLLISIONS_WEATHER_ROOT")
    if env_root:
        candidates.append(Path(env_root).expanduser())
    # Prefer the documented production roots before generic cwd discovery.
    candidates.extend([
        Path("/mnt/data_d/Dropbox/Research/AnimalCollisionsWeather"),
        Path("/Users/wendyhtw/Documents/CAPP ('25-'27)/Q4 - Summer'26/EPIC/Repos/collisions-and-climate"),
    ])
    for base in (cwd, *cwd.parents):
        candidates.extend([
            base,
            base / "collisions-and-climate",
            base / "Repos" / "collisions-and-climate",
        ])
    checked = []
    for candidate in candidates:
        candidate = candidate.resolve()
        if candidate in checked:
            continue
        checked.append(candidate)
        required = [
            candidate / "codePYTHON",
            candidate / "dataCSV" / "PRISM" / "prism_county_month.csv",
            candidate / "dataCSV" / "PRISM" / "prism_derived_weather_vars.csv",
        ]
        if required[0].is_dir() and all(path.is_file() for path in required[1:]):
            return candidate
    attempted = "\n  - ".join(str(path) for path in checked)
    raise FileNotFoundError(
        "Could not locate the collisions-and-climate project root. Checked:\n  - "
        + attempted
        + "\nSet COLLISIONS_WEATHER_ROOT to the project directory and rerun."
    )
REPO_ROOT = resolve_repo_root()
DATA_DIR = REPO_ROOT / "dataCSV"
TABLES_DIR = REPO_ROOT / "tables" / "weather" / "tier1"
FIGURES_DIR = REPO_ROOT / "figures" / "weather" / "tier1"
ID_COLS = ["geoid", "state_fips", "county_fips", "county_name"]
WINTER_MONTHS = (12, 1, 2)
EXPECTED_YEARS = set(range(1981, 2026))
PRIMARY_TREND_VARS = [
    "mean_temp_c",
    "days_extremely_cold",
    "days_below_freezing_32f",
    "freeze_thaw_days",
]
SPAGHETTI_VARS = ["mean_temp_c"]
OUTLIER_Z_THRESHOLD = 5.0
# The exported report prints on 11 x 8.5in landscape pages. Figures wider than
# roughly 8.5in are clipped at the right edge and figures taller than roughly
# 6.5in are split across a page break, so every multi-panel exhibit is sized to
# fit inside one printed page. Nine panels per page also avoids a single
# orphaned state on the final page: the sample has 49 states plus DC-equivalents
# (48 CONUS states + DC), and 49 = 5 pages of 9 + 4.
FIGURE_WIDTH_IN = 8.0
STATES_PER_PAGE = 9
STATE_GRID_COLS = 3
# The study universe is the contiguous US plus DC: 48 states + DC = 49 units.
# Alaska (02), Hawaii (15) and the territories (60, 66, 69, 72, 78) are out of
# scope -- PRISM's AN81m grid does not cover them, and the extraction already
# filters on gee_extract_utils.CONUS_STATE_FIPS. This dictionary is the same
# universe, spelled out here because importing gee_extract_utils would pull in
# the Earth Engine client just to read a constant.
STATE_FIPS_TO_NAME = {
    "01":"Alabama","04":"Arizona","05":"Arkansas","06":"California",
    "08":"Colorado","09":"Connecticut","10":"Delaware","11":"District of Columbia",
    "12":"Florida","13":"Georgia","16":"Idaho","17":"Illinois",
    "18":"Indiana","19":"Iowa","20":"Kansas","21":"Kentucky","22":"Louisiana",
    "23":"Maine","24":"Maryland","25":"Massachusetts","26":"Michigan",
    "27":"Minnesota","28":"Mississippi","29":"Missouri","30":"Montana",
    "31":"Nebraska","32":"Nevada","33":"New Hampshire","34":"New Jersey",
    "35":"New Mexico","36":"New York","37":"North Carolina","38":"North Dakota",
    "39":"Ohio","40":"Oklahoma","41":"Oregon","42":"Pennsylvania",
    "44":"Rhode Island","45":"South Carolina","46":"South Dakota",
    "47":"Tennessee","48":"Texas","49":"Utah","50":"Vermont","51":"Virginia",
    "53":"Washington","54":"West Virginia","55":"Wisconsin","56":"Wyoming",
}
CONUS_STATE_FIPS = frozenset(STATE_FIPS_TO_NAME)
VARIABLE_LABELS = {
    "mean_temp_c": "Mean winter temperature (°C)",
    "days_extremely_cold": "Extreme-cold days per winter (TMIN < 0°F)",
    "days_below_freezing_32f": "Freezing days per winter (TMIN < 32°F)",
    "freeze_thaw_days": "Freeze–thaw days per winter",
    "days_precip_above_10mm": "Days with precipitation > 10 mm",
    "ppt_total": "Total precipitation (mm)",
    "heating_degree_days": "Heating degree days",
    "cooling_degree_days": "Cooling degree days",
}
# Units are asserted against the panel's numeric columns in Section 4, so a new
# derived variable cannot reach PI's tables with a blank unit column.
# PRISM distributes vapour-pressure deficit in hPa (Earth Engine band docs for
# OREGONSTATE/PRISM/AN81m); observed vpdmax values of 1-77 confirm hPa, not kPa.
VARIABLE_UNITS = {
    "ppt_total": "mm",
    "tmean_mean": "°C",
    "tmin_mean": "°C",
    "tmax_mean": "°C",
    "tdmean_mean": "°C",
    "vpdmin_mean": "hPa",
    "vpdmax_mean": "hPa",
    "days_extremely_cold": "days",
    "days_below_freezing_32f": "days",
    "freeze_thaw_days": "days",
    "days_precip_above_10mm": "days",
    "heating_degree_days": "degree-days",
    "cooling_degree_days": "degree-days",
    "mean_temp_c": "°C",
    "tmean_variance_c2": "°C²",
    "tmin_variance_c2": "°C²",
    "tmax_variance_c2": "°C²",
    # County-level measures constructed in Sections 11-12.
    "winter_temp_sd": "°C",
    "winter_temp_mean": "°C",
    "interannual_sd_c": "°C",
    "n_winters": "winters",
}
@dataclass(frozen=True)
class DatasetConfig:
    name: str
    monthly_path: Path
    derived_path: Path
    is_primary: bool = False
PRISM_CONFIG = DatasetConfig(
    "PRISM", DATA_DIR / "PRISM" / "prism_county_month.csv",
    DATA_DIR / "PRISM" / "prism_derived_weather_vars.csv", True,
)
ERA5_CONFIG = DatasetConfig(
    "ERA5", DATA_DIR / "ERA5" / "era5_county_month.csv",
    DATA_DIR / "ERA5" / "era5_derived_weather_vars.csv", False,
)
def variable_label(variable):
    return VARIABLE_LABELS.get(variable, variable.replace("_", " ").title())
def source_note(text, width=105):
    """Wrap a source or caveat note to a fixed character width.

    Matplotlib grows the saved bounding box to enclose any artist that extends
    past the axes, so a long single-line note silently widens the exported PDF
    until it runs off the page edge. Wrapping keeps the note inside the figure.
    """
    return textwrap.fill(" ".join(text.split()), width=width)
def state_label(fips):
    code = str(fips).zfill(2)
    return f"{code} — {STATE_FIPS_TO_NAME.get(code, '(unmapped)')}"
def state_page_grid(n_states_on_page, row_height=2.1):
    """Return (n_rows, figsize) for a small-multiple page that fits one page."""
    n_rows = int(np.ceil(n_states_on_page / STATE_GRID_COLS))
    return n_rows, (FIGURE_WIDTH_IN, min(6.6, row_height * n_rows + 0.9))
def display_figure_inline(fig):
    """No-op in script form; the notebook uses this to draw inline."""
    return None
def save_figure_pdf(fig, filename):
    path = FIGURES_DIR / filename
    fig.savefig(path, format="pdf", bbox_inches="tight")
    display_figure_inline(fig)
    plt.close(fig)
    print(f"Saved {path}")
    return path
def _format_table_values(table, decimals=3):
    """Format each numeric column consistently.

    Formatting cell by cell produced ragged columns, because a value that
    happened to be integral printed with no decimals while its neighbours
    printed three. Decide once per column instead.
    """
    formatted_table = table.copy()
    for col in formatted_table.select_dtypes(include="number"):
        values = formatted_table[col].dropna()
        integral = bool(values.map(lambda v: float(v).is_integer()).all()) if len(values) else True
        pattern = "{:,.0f}" if integral else f"{{:,.{decimals}f}}"
        formatted_table[col] = formatted_table[col].map(
            lambda x: "" if pd.isna(x) else pattern.format(x)
        )
    return formatted_table
def save_table_pdf(table, path, title, rows_per_page=32, fontsize=7):
    """Save a DataFrame as one or more vector-PDF table pages."""
    formatted_table = _format_table_values(table)
    with PdfPages(path) as pdf:
        for start in range(0, max(len(formatted_table), 1), rows_per_page):
            page = formatted_table.iloc[start:start + rows_per_page]
            fig_height = max(3.0, 0.30 * (len(page) + 4))
            fig, ax = plt.subplots(figsize=(7.5, fig_height))
            ax.axis("off")
            ax.set_title(title, loc="left", fontsize=12, pad=12)
            if page.empty:
                # A legitimate outcome for review-flag tables: no rows flagged.
                ax.text(0.01, 0.88, "No rows.", transform=ax.transAxes,
                        ha="left", va="top", fontsize=10)
            else:
                artist = ax.table(
                    cellText=page.values, colLabels=page.columns,
                    loc="upper left", cellLoc="right", colLoc="center",
                    bbox=[0, 0, 1, 0.94],
                )
                artist.auto_set_font_size(False)
                artist.set_fontsize(fontsize)
                artist.auto_set_column_width(col=list(range(len(page.columns))))
            pdf.savefig(fig, bbox_inches="tight")
            display_figure_inline(fig)
            plt.close(fig)
    print(f"Saved {path}")
    return path
def load_weather_panel(dataset_config):
    dtype = {"geoid": str, "state_fips": str, "county_fips": str}
    monthly = pd.read_csv(dataset_config.monthly_path, dtype=dtype)
    derived = pd.read_csv(dataset_config.derived_path, dtype=dtype)

    keys = ["geoid", "year", "month"]
    duplicate_monthly = int(monthly.duplicated(keys).sum())
    duplicate_derived = int(derived.duplicated(keys).sum())
    if duplicate_monthly or duplicate_derived:
        raise ValueError(
            f"Duplicate keys: monthly={duplicate_monthly:,}, derived={duplicate_derived:,}"
        )

    redundant_ids = [c for c in ID_COLS if c != "geoid"]
    qa_cols = [
        c for c in ("n_days", "expected_days", "is_incomplete", "dataset_types")
        if c in monthly.columns and c in derived.columns
    ]
    qa_mismatches = {}
    if qa_cols:
        check = monthly[keys + qa_cols].merge(
            derived[keys + qa_cols], on=keys, how="inner",
            suffixes=("_monthly", "_derived"), validate="one_to_one",
        )
        for col in qa_cols:
            left, right = check[f"{col}_monthly"], check[f"{col}_derived"]
            qa_mismatches[col] = int((left.fillna("<NA>") != right.fillna("<NA>")).sum())

    slim = derived.drop(columns=redundant_ids + qa_cols, errors="ignore")
    merged = monthly.merge(
        slim, on=keys, how="outer", indicator=True, validate="one_to_one"
    )
    merge_counts = merged["_merge"].value_counts().to_dict()
    merged = merged.drop(columns="_merge")

    # Belt and braces. The PRISM extraction filters to CONUS upstream, but ERA5-Land
    # is a global product, so a future re-extraction could quietly widen the panel.
    outside = sorted(set(merged["state_fips"].dropna()) - CONUS_STATE_FIPS)
    if outside:
        dropped = int(merged["state_fips"].isin(outside).sum())
        print(f"NOTE: dropping {dropped:,} rows from non-CONUS state FIPS {outside} "
              f"-- the study universe is the contiguous US plus DC.")
        merged = merged[merged["state_fips"].isin(CONUS_STATE_FIPS)].copy()

    diagnostics = {
        "dataset": dataset_config.name,
        "monthly_rows": len(monthly),
        "derived_rows": len(derived),
        "merged_rows": len(merged),
        "counties": merged["geoid"].nunique(),
        "first_year": int(merged["year"].min()),
        "last_year": int(merged["year"].max()),
        "duplicate_monthly_keys": duplicate_monthly,
        "duplicate_derived_keys": duplicate_derived,
        "monthly_only_rows": int(merge_counts.get("left_only", 0)),
        "derived_only_rows": int(merge_counts.get("right_only", 0)),
        "incomplete_months": int(merged.get("is_incomplete", pd.Series(False, index=merged.index)).fillna(False).sum()),
        **{f"qa_mismatch_{key}": value for key, value in qa_mismatches.items()},
    }
    if diagnostics["monthly_only_rows"] or diagnostics["derived_only_rows"]:
        warnings.warn("Monthly and derived files do not match completely; inspect coverage table.")
    return merged, diagnostics
NON_WEATHER_COLS = {
    *ID_COLS, "year", "month", "winter_year", "n_days", "expected_days",
    "is_incomplete", "complete_winter", "dataset_types",
}
# Explicit exceptions prevent count variables whose names do not begin with
# `days_` from being misclassified as monthly means. These quantities are
# additive across December, January, and February.
WINTER_SUM_VARIABLES = {
    "freeze_thaw_days",
    "heating_degree_days",
    "cooling_degree_days",
    "ppt_total",
    "total_snowfall",
}
WINTER_SUM_PREFIXES = ("days_",)
VARIANCE_TO_MEAN = {
    "tmean_variance_c2": "tmean_mean",
    "tmin_variance_c2": "tmin_mean",
    "tmax_variance_c2": "tmax_mean",
}
def _numeric_weather_columns(frame):
    return [
        c for c in frame.columns
        if c not in NON_WEATHER_COLS and pd.api.types.is_numeric_dtype(frame[c])
    ]
def _is_total_variable(variable):
    return variable in WINTER_SUM_VARIABLES or variable.startswith(WINTER_SUM_PREFIXES)
def construct_county_winter_panel(monthly):
    """Collapse county-months to complete county-winters with vectorized rules."""
    work = monthly.copy()
    work["winter_year"] = work["year"] + (work["month"] == 12).astype(int)
    work = work[work["month"].isin(WINTER_MONTHS)].copy()

    group_keys = ID_COLS + ["winter_year"]
    completeness = (
        work.groupby(["geoid", "winter_year"], as_index=False)
        .agg(n_months=("month", "nunique"), observed_days=("n_days", "sum"))
    )
    completeness["expected_winter_days"] = completeness["winter_year"].map(
        lambda y: 31 + calendar.monthrange(int(y), 2)[1] + 31
    )
    completeness["complete_winter"] = (
        completeness["n_months"].eq(3)
        & completeness["observed_days"].eq(completeness["expected_winter_days"])
    )
    if "is_incomplete" in work:
        monthly_flags = (
            work.groupby(["geoid", "winter_year"], as_index=False)["is_incomplete"]
            .any().rename(columns={"is_incomplete": "has_flagged_month"})
        )
        completeness = completeness.merge(
            monthly_flags, on=["geoid", "winter_year"], validate="one_to_one"
        )
        completeness["complete_winter"] &= ~completeness["has_flagged_month"]

    complete = work.merge(
        completeness[["geoid", "winter_year", "complete_winter"]],
        on=["geoid", "winter_year"], validate="many_to_one",
    )
    complete = complete[complete["complete_winter"]].copy()
    grouped = complete.groupby(group_keys, sort=True, dropna=False)
    county_winter = grouped["n_days"].sum().rename("n_days").reset_index()

    variables = _numeric_weather_columns(complete)
    variance_vars = [v for v in VARIANCE_TO_MEAN if v in variables and VARIANCE_TO_MEAN[v] in complete]
    total_vars = [v for v in variables if _is_total_variable(v)]
    mean_vars = [v for v in variables if v not in total_vars and v not in variance_vars]

    # Counts and accumulated quantities are additive across Dec/Jan/Feb.
    if total_vars:
        totals = grouped[total_vars].sum(min_count=1).reset_index()
        county_winter = county_winter.merge(totals, on=group_keys, validate="one_to_one")

    # Monthly means are combined using observed county-month day counts.
    for variable in mean_vars:
        valid = complete[variable].notna() & complete["n_days"].gt(0)
        temp = complete.loc[valid, group_keys].copy()
        temp["_weighted_value"] = complete.loc[valid, variable] * complete.loc[valid, "n_days"]
        temp["_weight"] = complete.loc[valid, "n_days"]
        weighted = temp.groupby(group_keys, as_index=False)[["_weighted_value", "_weight"]].sum()
        weighted[variable] = weighted["_weighted_value"] / weighted["_weight"]
        county_winter = county_winter.merge(
            weighted[group_keys + [variable]], on=group_keys, how="left", validate="one_to_one"
        )

    # Combine monthly daily-sample variances exactly:
    # SS = sum[(n_m-1)s_m^2 + n_m*mean_m^2] - (sum[n_m*mean_m])^2/N.
    for variance_col in variance_vars:
        mean_col = VARIANCE_TO_MEAN[variance_col]
        valid = complete[[*group_keys, "n_days", mean_col, variance_col]].dropna()
        valid = valid[valid["n_days"].gt(0)].copy()
        valid["_sum_x"] = valid["n_days"] * valid[mean_col]
        valid["_sum_x2"] = (
            (valid["n_days"] - 1) * valid[variance_col]
            + valid["n_days"] * valid[mean_col].pow(2)
        )
        combined = (
            valid.groupby(group_keys, as_index=False)
            .agg(_n=("n_days", "sum"), _sum_x=("_sum_x", "sum"), _sum_x2=("_sum_x2", "sum"))
        )
        numerator = combined["_sum_x2"] - combined["_sum_x"].pow(2) / combined["_n"]
        combined[variance_col] = numerator.clip(lower=0) / (combined["_n"] - 1)
        combined.loc[combined["_n"].le(1), variance_col] = np.nan
        county_winter = county_winter.merge(
            combined[group_keys + [variance_col]],
            on=group_keys, how="left", validate="one_to_one"
        )

    winter_diagnostics = {
        "candidate_county_winters": len(completeness),
        "complete_county_winters": int(completeness["complete_winter"].sum()),
        "excluded_incomplete_county_winters": int((~completeness["complete_winter"]).sum()),
        "first_complete_winter": (
            int(county_winter["winter_year"].min()) if not county_winter.empty else None
        ),
        "last_complete_winter": (
            int(county_winter["winter_year"].max()) if not county_winter.empty else None
        ),
    }
    return county_winter, completeness, winter_diagnostics
# The weather panel is aggregated over Earth Engine's TIGER/2018/Counties
# (gee_extract_utils.COUNTY_COLLECTION), so the map must use the matching 2018
# cartographic-boundary vintage. Connecticut abolished its eight counties in
# 2022; the 2023 vintage carries nine planning regions (09110-09190) instead,
# and those boundaries do not nest inside the legacy counties.
COUNTY_GEOMETRY_VINTAGE = "2018"
COUNTY_GEOMETRY_CANDIDATES = [
    REPO_ROOT / "dataRAW" / "shapefiles" / f"cb_{COUNTY_GEOMETRY_VINTAGE}_us_county_20m.shp",
    REPO_ROOT / "dataRAW" / f"cb_{COUNTY_GEOMETRY_VINTAGE}_us_county_20m.shp",
]
CENSUS_COUNTY_URL = (
    f"https://www2.census.gov/geo/tiger/GENZ{COUNTY_GEOMETRY_VINTAGE}/shp/"
    f"cb_{COUNTY_GEOMETRY_VINTAGE}_us_county_20m.zip"
)
def load_county_geometry():
    local = next((path for path in COUNTY_GEOMETRY_CANDIDATES if path.exists()), None)
    source = local if local is not None else CENSUS_COUNTY_URL
    print(f"County geometry source: {source}")
    geometry = gpd.read_file(source)
    geometry["geoid"] = geometry["GEOID"].astype(str).str.zfill(5)
    # ALAND is land area in square metres. It is kept because Eyal asked (8/28)
    # for area-weighted companions to the national exhibits: counties in the
    # west are far larger than counties in the east, so an unweighted county
    # mean is not the same estimand as an area-weighted one. Land area, not
    # ALAND + AWATER: open water should not carry temperature weight.
    geometry["land_area_km2"] = geometry["ALAND"] / 1e6

    # The Census cartographic file covers Alaska, Hawaii, Puerto Rico and the
    # territories. They never carry weather data -- every choropleth merge is an
    # inner join against the panel -- but state_geometry below is dissolved from
    # THIS frame, and in an Albers CONUS projection Alaska sits far to the
    # north-west. Left in, drawing state borders expands each map's axes to
    # enclose it and shrinks the lower 48 to roughly half size in the frame.
    outside = sorted(set(geometry["geoid"].str[:2]) - CONUS_STATE_FIPS)
    if outside:
        geometry = geometry[geometry["geoid"].str[:2].isin(CONUS_STATE_FIPS)].copy()
        print(f"Dropped non-CONUS geometry: {', '.join(outside)}")
    return geometry[["geoid", "land_area_km2", "geometry"]]
def draw_state_borders(ax, linewidth=0.45, color="black"):
    """Overlay state outlines on a county choropleth."""
    state_geometry.boundary.plot(ax=ax, linewidth=linewidth, color=color, zorder=5)
def merge_county_geometry(frame, exhibit, columns=None):
    """Attach county polygons and verify that every county in `frame` matched.

    An inner join drops counties whose GEOIDs are absent from the shapefile
    vintage without any visible symptom: the map simply renders without them.
    Connecticut's 2022 replacement of counties by planning regions is the
    realistic failure mode here, so the match is asserted rather than assumed.
    """
    payload = frame if columns is None else frame[columns]
    merged = county_geometry.merge(payload, on="geoid", how="inner", validate="one_to_one")
    unmatched = sorted(set(payload["geoid"]) - set(merged["geoid"]))
    assert not unmatched, (
        f"{exhibit}: {len(unmatched)} of {payload['geoid'].nunique():,} counties have no "
        f"polygon in this shapefile vintage (first 10: {unmatched[:10]})."
    )
    print(f"{exhibit}: mapped {len(merged):,} of {payload['geoid'].nunique():,} counties.")
    return merged.to_crs("EPSG:5070")
# Needed by both tiers, so built once here rather than in either script.
@dataclass(frozen=True, eq=False)
class TrendFit:
    """An OLS linear trend with the inference needed to report it responsibly."""
    x_line: np.ndarray
    y_line: np.ndarray
    slope: float
    stderr: float
    r2: float
    n: int

    @property
    def per_decade(self):
        return self.slope * 10

    @property
    def per_decade_stderr(self):
        return self.stderr * 10

    def decade_label(self, unit="°C"):
        return f"{self.per_decade:+.2f} {unit}/decade (SE {self.per_decade_stderr:.2f})"
def _linear_trend(x, y):
    """Fit y = a + b*x and return the slope with its standard error and R^2."""
    valid = pd.DataFrame({"x": x, "y": y}).dropna()
    if valid["x"].nunique() < 2 or len(valid) < 3:
        return None
    x_values = valid["x"].to_numpy(dtype=float)
    y_values = valid["y"].to_numpy(dtype=float)
    slope, intercept = np.polyfit(x_values, y_values, 1)
    residuals = y_values - (intercept + slope * x_values)
    n = len(valid)
    residual_ss = float(residuals @ residuals)
    total_ss = float(((y_values - y_values.mean()) ** 2).sum())
    slope_variance = (residual_ss / (n - 2)) / float(((x_values - x_values.mean()) ** 2).sum())
    x_line = np.array([x_values.min(), x_values.max()])
    return TrendFit(
        x_line=x_line,
        y_line=intercept + slope * x_line,
        slope=float(slope),
        stderr=float(np.sqrt(slope_variance)),
        r2=float(1 - residual_ss / total_ss) if total_ss > 0 else np.nan,
        n=n,
    )
def decade_label(year):
    if 2020 <= int(year) <= 2025:
        return "2020–2025"
    start = (int(year) // 10) * 10
    return f"{start}s"


# Placeholders. build_panel() fills these in; see the note on that function.
config = None
df = None
load_diagnostics = None
county_winter = None
winter_completeness = None
winter_diagnostics = None
county_geometry = None
state_geometry = None
county_variability = None

_BUILT = False


def build_panel():
    """Read the weather CSVs and build the county-winter panel.

    Importing this module does no I/O -- it only defines things. This function is
    where the work happens, so a script (or a test, or an interactive session)
    decides when to pay for it. Idempotent: calling it twice does the work once.

    Returns a dict of the objects both tiers need, for the caller to bind:

        globals().update(build_panel())
    """
    global _BUILT, config, county_geometry, county_variability, county_winter, df, load_diagnostics, missing_area, state_geometry, winter_completeness, winter_diagnostics
    if _BUILT:
        return _panel()
    """Shared setup for the weather descriptive scripts.

    GENERATED FILE -- do not edit by hand.
    Produced from codePYTHON/09_descriptive_weather_full.ipynb by make_scripts.py.
    Edit the notebook, then re-run make_scripts.py.
    """
    matplotlib.use("Agg")
    TABLES_DIR.mkdir(parents=True, exist_ok=True)
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    assert len(CONUS_STATE_FIPS) == 49, f"Expected 48 states + DC, got {len(CONUS_STATE_FIPS)}"
    config = PRISM_CONFIG
    print(f"Dataset: {config.name}")
    print(f"Repository root: {REPO_ROOT}")
    print(f"Monthly input: {config.monthly_path}")
    print(f"Derived input: {config.derived_path}")
    print(f"Table outputs: {TABLES_DIR}")
    print(f"Figure outputs: {FIGURES_DIR}")
    df, load_diagnostics = load_weather_panel(config)
    display(pd.DataFrame([load_diagnostics]))
    display(df.head())
    county_winter, winter_completeness, winter_diagnostics = construct_county_winter_panel(df)
    display(pd.DataFrame([winter_diagnostics]))
    display(county_winter.head())
    county_geometry = load_county_geometry()
    # State outlines, dissolved from the same county vintage so the two layers cannot
    # disagree. Eyal (8/28): keep county borders invisible -- "getting ink to a minimum
    # ... totally the correct call" -- but add state borders in black.
    state_geometry = (
        county_geometry.assign(state_fips=county_geometry["geoid"].str[:2])
        .dissolve(by="state_fips")[["geometry"]]
        .to_crs("EPSG:5070")
    )
    assert len(state_geometry) == 49, (
        f"state_geometry has {len(state_geometry)} units, expected 48 states + DC. "
        f"A non-CONUS polygon would push every map's extent out to enclose it."
    )
    # Land area travels with the winter panel so every weighted exhibit downstream
    # uses one definition of the weight rather than re-merging it per figure.
    if "land_area_km2" not in county_winter.columns:
        county_winter = county_winter.merge(
            county_geometry[["geoid", "land_area_km2"]], on="geoid",
            how="left", validate="many_to_one",
        )
    missing_area = int(county_winter["land_area_km2"].isna().sum())
    assert missing_area == 0, (
        f"{missing_area:,} county-winters have no land area; the shapefile vintage and the "
        "weather panel disagree on county coverage."
    )
    county_winter["decade"] = county_winter["winter_year"].map(decade_label)
    county_variability = (
        county_winter.groupby(["geoid", "state_fips", "county_name"], as_index=False)
        .agg(
            winter_temp_sd=("mean_temp_c", "std"),
            winter_temp_mean=("mean_temp_c", "mean"),
            n_winters=("mean_temp_c", "count"),
        )
    )
    # A coefficient of variation is not reported here. Mean winter temperature is an
    # interval-scale quantity whose county means pass through zero, so SD / |mean|
    # explodes near 0 degrees C and is not comparable across counties.
    county_variability.to_csv(
        TABLES_DIR / f"{config.name.lower()}_county_interannual_variability.csv", index=False
    )

    _BUILT = True
    return _panel()


def _panel():
    return {
        "config": config,
        "df": df,
        "load_diagnostics": load_diagnostics,
        "county_winter": county_winter,
        "winter_completeness": winter_completeness,
        "winter_diagnostics": winter_diagnostics,
        "county_geometry": county_geometry,
        "state_geometry": state_geometry,
        "county_variability": county_variability,
    }
