"""Tier 2 -- polished exhibits for the PI report.

GENERATED FILE -- do not edit by hand.
Produced from codePYTHON/09_descriptive_weather_full.ipynb by make_scripts.py.
Edit the notebook, then re-run make_scripts.py.
"""


import weather_descriptives_utils as wx
from weather_descriptives_utils import *  # noqa: F401,F403
from weather_descriptives_utils import (
    _linear_trend,
)

# Reading the CSVs and building the county-winter panel is an explicit
# call, not an import side effect. The panel's objects are bound into
# this script's namespace so the exhibit code below reads unchanged.
globals().update(wx.build_panel())


# Tier 2 outputs are kept separate from Tier 1 QA artifacts.
TIER2_TABLES_DIR = REPO_ROOT / "tables" / "weather" / "tier2"
TIER2_FIGURES_DIR = REPO_ROOT / "figures" / "weather" / "tier2"
TIER2_TABLES_DIR.mkdir(parents=True, exist_ok=True)
TIER2_FIGURES_DIR.mkdir(parents=True, exist_ok=True)
tier2_outputs = []

TIER2_COLORS = {"annual": "#0072B2", "trend": "#D55E00", "warm": "#B2182B",
                "weighted": "#117733"}

# Every county is weighted equally unless an exhibit says otherwise. Both strings
# travel with the figure's notes rather than living only in the notebook.
ESTIMAND_NOTE = (
    "Estimand: the average county (counties weighted equally), not an area-, "
    "population- or road-weighted national average."
)
ESTIMAND_NOTE_AREA = (
    "Estimand: the average square kilometre of the contiguous United States "
    "(counties weighted by land area). Eyal ruled out population weighting (8/28); "
    "counties in the west are much larger than counties in the east, so the "
    "unweighted and area-weighted series answer different questions."
)

# --------------------------------------------------------------------------
# Figure conventions for v2 (Eyal, Slack 8/28)
#
#   1. "You can remove the title (already repeated in the figure caption) and
#      the notes from the image itself (worth having those notes in the figure
#      notes)."
#   2. "I hate to make readers ... turn their heads to read anything off a
#      graph. Would it be possible to move the legend text so it is horizontal
#      and positioned at south-west kind of direction?"
#
# So: no exhibit carries its own title, and no exhibit carries its source note
# as a text artist. Notes are collected here and written to a CSV that
# codeSTATA/10_generate_weather_report.do reads, which keeps each caption's
# Notes paragraph in sync with the figure that produced it -- they cannot drift
# the way hand-copied caption text does. Panel labels ("Early period:
# 1982-1991") are NOT titles and stay: they are not repeated in the caption.
# --------------------------------------------------------------------------
EXHIBIT_NOTES = {}


def finalize_tier2(fig, filename, panel_titles_ok=False):
    """Assert an exhibit carries no title and no in-image note.

    Checked rather than silently stripped: a title that reappears because a new
    figure was copied from an old one should fail the run, not be quietly
    removed and forgotten.
    """
    problems = []
    suptitle = getattr(fig, "_suptitle", None)
    if suptitle is not None and suptitle.get_text().strip():
        problems.append(f"suptitle {suptitle.get_text()!r}")
    if fig.texts:
        problems.append(f"{len(fig.texts)} figure-level text artist(s): "
                        + "; ".join(t.get_text()[:40] for t in fig.texts))
    for ax in fig.axes:
        title = ax.get_title().strip()
        if title and not panel_titles_ok:
            problems.append(f"axes title {title!r}")
        for text in ax.texts:
            if text.get_transform() is ax.transAxes:
                _, y = text.get_position()
                if y < -0.01 or y > 1.01:
                    problems.append(f"text outside the axes: {text.get_text()[:40]!r}")
    assert not problems, f"{filename}: " + "; ".join(problems)


def save_tier2_figure(fig, filename, note=None, panel_titles_ok=False):
    finalize_tier2(fig, filename, panel_titles_ok=panel_titles_ok)
    if note is not None:
        clean = " ".join(str(note).split())
        # Stata expands $ as a global macro and reads ` as a macro open, so a
        # note containing either would break 10_generate_weather_report.do in a
        # way that is hard to trace back to here.
        assert "$" not in clean and "`" not in clean, (
            f"{filename}: note contains a character Stata cannot read literally."
        )
        EXHIBIT_NOTES[filename] = clean
    path = TIER2_FIGURES_DIR / filename
    fig.savefig(path, format="pdf", bbox_inches="tight",
                metadata={"Creator": "09_descriptive_weather_full.ipynb"})
    display_figure_inline(fig)
    plt.close(fig)
    tier2_outputs.append(path)
    print(f"Saved {path}")
    return path


def add_southwest_colorbar(ax, cmap, vmin, vmax, label, fmt=None,
                           width=0.31, height=0.024, x=0.015, y=0.07):
    """Horizontal colorbar inset at the lower-left of a map.

    GeoPandas' default legend is a vertical bar at the right edge with a
    90-degree-rotated label -- the text Eyal was tilting his head to read. In an
    EPSG:5070 Albers projection of the contiguous US the lower-left corner is
    open ocean, so the bar sits inside the axes without covering land.
    """
    cax = ax.inset_axes([x, y, width, height])
    mappable = plt.cm.ScalarMappable(cmap=cmap, norm=plt.Normalize(vmin, vmax))
    mappable.set_array([])
    cbar = ax.figure.colorbar(mappable, cax=cax, orientation="horizontal")
    cbar.ax.xaxis.set_label_position("top")
    cbar.set_label(label, fontsize=8, labelpad=5)
    cbar.ax.tick_params(labelsize=7, length=2.5, pad=1.5)
    if fmt is not None:
        cbar.ax.xaxis.set_major_formatter(mticker.FormatStrFormatter(fmt))
    cbar.outline.set_linewidth(0.5)
    return cbar


# --------------------------------------------------------------------------
# Area weighting (Eyal, 8/28: "an area-weighted mean is also a sensible way to
# think about that", and "these distributions ... probably should have an
# area-weighted version as well").
#
# scipy is deliberately not used: it is absent from requirements.txt and from
# the Kodama environment, and a missing dependency there has already cost this
# project a day. A weighted Gaussian KDE is fifteen lines of numpy.
# --------------------------------------------------------------------------
def weighted_annual_mean(frame, value_col, weight_col=None, group_col="winter_year"):
    """Collapse the county panel to one row per year, weighted or not."""
    work = frame[[group_col, value_col, "geoid"]].copy()
    work["_w"] = 1.0 if weight_col is None else frame[weight_col].to_numpy()
    work = work.dropna(subset=[value_col, "_w"])
    work["_wv"] = work[value_col] * work["_w"]
    out = work.groupby(group_col, as_index=False).agg(
        _wv=("_wv", "sum"), _w=("_w", "sum"), n_counties=("geoid", "nunique")
    )
    out[value_col] = out["_wv"] / out["_w"]
    return out.drop(columns=["_wv", "_w"])


def weighted_quantile(values, weights, q):
    values = np.asarray(values, dtype=float)
    weights = np.asarray(weights, dtype=float)
    order = np.argsort(values)
    values, weights = values[order], weights[order]
    cumulative = np.cumsum(weights) - 0.5 * weights
    cumulative /= weights.sum()
    return float(np.interp(q, cumulative, values))


def weighted_kde(values, weights, grid, chunk=20000):
    """Gaussian KDE with Silverman bandwidth on Kish's effective sample size.

    Evaluated in chunks: the pooled violins carry ~10^5 county-winters and a
    dense (grid x values) matrix would be hundreds of megabytes.
    """
    values = np.asarray(values, dtype=float)
    weights = (np.ones_like(values) if weights is None
               else np.asarray(weights, dtype=float))
    keep = np.isfinite(values) & np.isfinite(weights) & (weights > 0)
    values, weights = values[keep], weights[keep]
    if values.size == 0:
        return np.zeros_like(grid)
    w = weights / weights.sum()
    mean = float(np.sum(w * values))
    std = float(np.sqrt(np.sum(w * (values - mean) ** 2)))
    n_eff = 1.0 / float(np.sum(w ** 2))
    bandwidth = std * n_eff ** (-1.0 / 5.0)
    if not np.isfinite(bandwidth) or bandwidth <= 0:
        bandwidth = max(std, 1e-6)
    density = np.zeros_like(grid, dtype=float)
    norm = 1.0 / (bandwidth * np.sqrt(2.0 * np.pi))
    for start in range(0, values.size, chunk):
        block = values[start:start + chunk]
        block_w = w[start:start + chunk]
        z = (grid[:, None] - block[None, :]) / bandwidth
        density += (np.exp(-0.5 * z * z) * block_w[None, :]).sum(axis=1)
    return density * norm


# --------------------------------------------------------------------------
# Exhibit 1 -- national long-run warming, unweighted and area-weighted.
# --------------------------------------------------------------------------
def plot_national_warming(frame, weight_col, filename, note):
    annual = weighted_annual_mean(frame, "mean_temp_c", weight_col)
    fit = _linear_trend(annual["winter_year"], annual["mean_temp_c"])
    span = annual["winter_year"].max() - annual["winter_year"].min()
    change = fit.slope * span
    colour = TIER2_COLORS["weighted"] if weight_col else TIER2_COLORS["annual"]

    fig, ax = plt.subplots(figsize=(8.0, 4.3))
    ax.plot(annual["winter_year"], annual["mean_temp_c"], color=colour, lw=1.5,
            marker="o", ms=3.5, label="Annual county mean")
    ax.plot(fit.x_line, fit.y_line, color=TIER2_COLORS["trend"], lw=2.5,
            label=f"Linear trend {fit.decade_label()}")
    ax.text(0.02, 0.05,
            f"Fitted change across sample: {change:+.2f}°C   (R² {fit.r2:.2f}, n={fit.n} winters)",
            transform=ax.transAxes, fontsize=9)
    ax.set(xlabel="Winter year (December–February)",
           ylabel="Mean winter temperature (°C)")
    ax.grid(axis="y", alpha=0.2)
    ax.spines[["top", "right"]].set_visible(False)
    ax.legend(frameon=False, ncol=2, fontsize=9, loc="upper left")
    fig.tight_layout()
    path = save_tier2_figure(fig, filename, note=note)
    return path, fit


national_warming_path, national_fit = plot_national_warming(
    county_winter, None,
    f"{config.name.lower()}_national_long_run_warming.pdf",
    f"Source: {config.name}; complete DJF winters only. {ESTIMAND_NOTE}",
)
national_warming_area_path, national_fit_area = plot_national_warming(
    county_winter, "land_area_km2",
    f"{config.name.lower()}_national_long_run_warming_area_weighted.pdf",
    f"Source: {config.name}; complete DJF winters only. {ESTIMAND_NOTE_AREA}",
)
print(f"Unweighted trend {national_fit.per_decade:+.3f} °C/decade "
      f"(SE {national_fit.per_decade_stderr:.3f}); "
      f"area-weighted {national_fit_area.per_decade:+.3f} °C/decade "
      f"(SE {national_fit_area.per_decade_stderr:.3f}).")


state_annual = county_winter.groupby(
    ["state_fips", "winter_year"], as_index=False
)["mean_temp_c"].mean()
states = sorted(state_annual["state_fips"].dropna().unique())
state_warming_path = TIER2_FIGURES_DIR / f"{config.name.lower()}_state_long_run_warming.pdf"

with PdfPages(state_warming_path,
              metadata={"Creator": "09_descriptive_weather_full.ipynb"}) as pdf:
    for start in range(0, len(states), STATES_PER_PAGE):
        page_states = states[start:start + STATES_PER_PAGE]
        n_rows, figsize = state_page_grid(len(page_states), row_height=2.15)
        fig, axes = plt.subplots(n_rows, STATE_GRID_COLS, figsize=figsize,
                                 sharex=True, squeeze=False)
        for ax, state in zip(axes.flat, page_states):
            annual = state_annual[state_annual["state_fips"].eq(state)]
            state_trend = _linear_trend(annual["winter_year"], annual["mean_temp_c"])
            ax.plot(annual["winter_year"], annual["mean_temp_c"],
                    color=TIER2_COLORS["annual"], lw=1)
            slope_text = "trend unavailable"
            if state_trend is not None:
                ax.plot(state_trend.x_line, state_trend.y_line,
                        color=TIER2_COLORS["trend"], lw=1.8)
                slope_text = (f"{state_trend.per_decade:+.2f} °C/dec "
                              f"(SE {state_trend.per_decade_stderr:.2f})")
            ax.set_title(f"{STATE_FIPS_TO_NAME.get(str(state).zfill(2), state)}\n{slope_text}",
                         fontsize=8)
            ax.grid(axis="y", alpha=0.15)
            ax.tick_params(labelsize=6)
            ax.spines[["top", "right"]].set_visible(False)
        for ax in list(axes.flat)[len(page_states):]:
            ax.axis("off")
        fig.supxlabel("Winter year", fontsize=9)
        fig.supylabel("Unweighted county mean (°C)", fontsize=9)
        fig.tight_layout(rect=[0.02, 0.01, 1, 0.99])
        pdf.savefig(fig, bbox_inches="tight")
        display_figure_inline(fig)
        plt.close(fig)

EXHIBIT_NOTES[state_warming_path.name] = " ".join(
    f"Source: {config.name}; complete DJF winters. One panel per state, ordered by FIPS "
    f"code. Blue traces the annual unweighted county mean; orange is that state's linear "
    f"trend, with the per-decade slope and its standard error in the panel label. "
    f"Y-axis ranges differ by panel deliberately: forcing a common range across states "
    f"whose mean winter temperature spans roughly 40°C would flatten every trend to "
    f"invisibility.".split()
)
tier2_outputs.append(state_warming_path)
print(f"Saved {state_warming_path}")


# Eyal, 8/28: "If you could pull all of these state-specific lines into one
# figure ... you don't need to label each of the lines, so they can be the same
# colour. Might help to have some transparency ... seeing how they have different
# intercepts and have different slopes." And: "Definitely not a figure that we'd
# want each state to be separately legible."
#
# Fitted lines rather than raw series: 49 connect-the-dots traces is an ink blob,
# and what the figure is for is the spread of intercepts and slopes. He also
# asked to flag the outliers -- "maybe it's worth annotating them with, like, a
# small line and a two-letter code for that state next to it."
STATE_FIPS_TO_USPS = {
    "01":"AL","04":"AZ","05":"AR","06":"CA","08":"CO","09":"CT","10":"DE","11":"DC",
    "12":"FL","13":"GA","16":"ID","17":"IL","18":"IN","19":"IA","20":"KS","21":"KY",
    "22":"LA","23":"ME","24":"MD","25":"MA","26":"MI","27":"MN","28":"MS","29":"MO",
    "30":"MT","31":"NE","32":"NV","33":"NH","34":"NJ","35":"NM","36":"NY","37":"NC",
    "38":"ND","39":"OH","40":"OK","41":"OR","42":"PA","44":"RI","45":"SC","46":"SD",
    "47":"TN","48":"TX","49":"UT","50":"VT","51":"VA","53":"WA","54":"WV","55":"WI",
    "56":"WY",
}
# Eyal floated EPA ecoregions (Slack, 8/28) but they cut across state lines, which
# would need a county-level spatial join. Wendy's suggestion on the call -- EPA's
# own climate-impact regions -- assigns whole states, so it drops straight onto a
# state-level figure. Great Plains split north/south, as EPA does.
NCA_REGION_BY_USPS = {}
for _region, _states in {
    "Northeast": "CT DE DC ME MD MA NH NJ NY PA RI VT WV",
    "Southeast": "AL AR FL GA KY LA MS NC SC TN VA",
    "Midwest": "IL IN IA MI MN MO OH WI",
    "Northern Great Plains": "MT NE ND SD WY",
    "Southern Great Plains": "KS OK TX",
    "Northwest": "ID OR WA",
    "Southwest": "AZ CA CO NM NV UT",
}.items():
    for _code in _states.split():
        NCA_REGION_BY_USPS[_code] = _region
NCA_REGION_COLORS = {
    "Northeast": "#332288", "Southeast": "#88CCEE", "Midwest": "#44AA99",
    "Northern Great Plains": "#117733", "Southern Great Plains": "#DDCC77",
    "Northwest": "#CC6677", "Southwest": "#AA4499",
}

state_trend_fits = []
for state in states:
    annual = state_annual[state_annual["state_fips"].eq(state)]
    fit = _linear_trend(annual["winter_year"], annual["mean_temp_c"])
    if fit is None:
        continue
    state_trend_fits.append({
        "state_fips": state,
        "usps": STATE_FIPS_TO_USPS.get(str(state).zfill(2), "??"),
        "state_name": STATE_FIPS_TO_NAME.get(str(state).zfill(2), state),
        "per_decade": fit.per_decade,
        "per_decade_stderr": fit.per_decade_stderr,
        "intercept_1982_c": float(fit.y_line[0]),
        "fit": fit,
    })
state_trend_table = pd.DataFrame(
    [{k: v for k, v in row.items() if k != "fit"} for row in state_trend_fits]
).sort_values("per_decade", ascending=False)
state_trend_table.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_state_trend_slopes.csv", index=False
)

ranked = sorted(state_trend_fits, key=lambda row: row["per_decade"])
flagged_states = {row["state_fips"] for row in ranked[:3] + ranked[-3:]}


def plot_pooled_state_trends(colour_by_region, filename, note):
    fig, ax = plt.subplots(figsize=(8.0, 4.8))
    for row in state_trend_fits:
        region = NCA_REGION_BY_USPS.get(row["usps"])
        colour = NCA_REGION_COLORS.get(region, "#666666") if colour_by_region else "#3f4a55"
        emphasis = row["state_fips"] in flagged_states
        ax.plot(row["fit"].x_line, row["fit"].y_line, color=colour,
                lw=1.6 if emphasis else 0.9,
                alpha=0.85 if emphasis else (0.55 if colour_by_region else 0.32),
                zorder=3 if emphasis else 2)

    # Leader line plus two-letter code for the six extreme slopes only. Labels are
    # nudged apart vertically: several states can end the sample within a tenth of
    # a degree of each other, and stacked labels are worse than no labels.
    x_end = max(row["fit"].x_line[-1] for row in state_trend_fits)
    x_start = min(row["fit"].x_line[0] for row in state_trend_fits)
    label_x = x_end + 0.012 * (x_end - x_start)
    y_lo, y_hi = ax.get_ylim()
    min_gap = 0.042 * (y_hi - y_lo)

    endpoints = sorted(
        ((float(row["fit"].y_line[-1]), row) for row in state_trend_fits
         if row["state_fips"] in flagged_states),
        key=lambda pair: pair[0],
    )
    placed_y = []
    for y_true, _ in endpoints:
        y = y_true if not placed_y else max(y_true, placed_y[-1] + min_gap)
        placed_y.append(y)

    for (y_true, row), y_label in zip(endpoints, placed_y):
        ax.plot([x_end, label_x], [y_true, y_label], color="#888888", lw=0.6,
                clip_on=False, zorder=5)
        ax.annotate(
            f"{row['usps']} {row['per_decade']:+.2f}",
            xy=(label_x, y_label), xytext=(3, 0), textcoords="offset points",
            fontsize=7.5, va="center", ha="left", color="#222222",
            annotation_clip=False, zorder=6,
        )
    ax.set(xlabel="Winter year (December–February)",
           ylabel="State mean winter temperature (°C)")
    ax.set_xlim(None, x_end + 0.085 * (x_end - x_start))
    ax.grid(axis="y", alpha=0.2)
    ax.spines[["top", "right"]].set_visible(False)
    if colour_by_region:
        handles = [plt.Line2D([], [], color=colour, lw=2, label=region)
                   for region, colour in NCA_REGION_COLORS.items()]
        ax.legend(handles=handles, fontsize=7.5, ncol=2, loc="lower left",
                  handlelength=1.6, columnspacing=1.2, frameon=True, framealpha=0.92,
                  edgecolor="#cccccc", facecolor="white", borderpad=0.5)
    fig.tight_layout()
    return save_tier2_figure(fig, filename, note=note)


_annotated = ", ".join(f"{row['usps']} ({row['per_decade']:+.2f})" for row in ranked[-3:][::-1])
_annotated_low = ", ".join(f"{row['usps']} ({row['per_decade']:+.2f})" for row in ranked[:3])
pooled_state_trends_path = plot_pooled_state_trends(
    False, f"{config.name.lower()}_state_trends_pooled.pdf",
    note=(f"Source: {config.name}; complete DJF winters. One fitted linear trend per state "
          f"(48 contiguous states plus DC), drawn in a single colour with transparency — the "
          f"figure shows the spread of intercepts and slopes, and is not meant to make any "
          f"individual state legible. Labelled: the three steepest warming trends "
          f"({_annotated}) and the three shallowest ({_annotated_low}), in °C per decade."),
)
pooled_state_trends_region_path = plot_pooled_state_trends(
    True, f"{config.name.lower()}_state_trends_pooled_by_region.pdf",
    note=(f"Source: {config.name}; the same fitted state trends coloured by EPA climate-impact "
          f"region. Regions are assigned whole states, so no state is split; EPA Level I "
          f"ecoregions cut across state lines and would need a county-level assignment."),
)
display(state_trend_table.head(8))


# Ten-winter windows balance temporal contrast with resistance to single-winter
# noise. Both panels are period means, not single-year endpoints.
EARLY_PERIOD = (1982, 1991)
RECENT_PERIOD = (2016, 2025)
PERIOD_NOTE = (
    f"Each county value is a mean over the {EARLY_PERIOD[1] - EARLY_PERIOD[0] + 1} winters in "
    f"its period ({EARLY_PERIOD[0]}–{EARLY_PERIOD[1]} and {RECENT_PERIOD[0]}–{RECENT_PERIOD[1]}), "
    "not a comparison of single winters or of sample endpoints."
)

def period_mean(frame, variable, period, output_name):
    lo, hi = period
    return (frame[frame["winter_year"].between(lo, hi)]
            .groupby("geoid", as_index=False)
            .agg(**{output_name: (variable, "mean")}, n_winters=(variable, "count")))

early_temp = period_mean(county_winter, "mean_temp_c", EARLY_PERIOD, "early_temp_c")
recent_temp = period_mean(county_winter, "mean_temp_c", RECENT_PERIOD, "recent_temp_c")
temperature_periods = early_temp.merge(
    recent_temp, on="geoid", suffixes=("_early", "_recent"), validate="one_to_one"
)
temperature_periods.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_county_temperature_early_recent.csv", index=False
)
temperature_map = merge_county_geometry(temperature_periods, "Early vs recent temperature")

common_min = float(temperature_map[["early_temp_c", "recent_temp_c"]].min().min())
common_max = float(temperature_map[["early_temp_c", "recent_temp_c"]].max().max())
fig, axes = plt.subplots(1, 2, figsize=(8.0, 4.0))
fig.subplots_adjust(left=0.02, right=0.98, top=0.97, bottom=0.03, wspace=0.02)
for ax, column, period, title in zip(
    axes,
    ["early_temp_c", "recent_temp_c"],
    [EARLY_PERIOD, RECENT_PERIOD],
    ["Early period", "Recent period"],
):
    temperature_map.plot(column=column, cmap="coolwarm", vmin=common_min, vmax=common_max,
                         linewidth=0, ax=ax)
    draw_state_borders(ax)
    # Panel labels, not exhibit titles: they identify which period each map shows
    # and are not repeated in the caption.
    ax.set_title(f"{title}: {period[0]}–{period[1]}", fontsize=11)
    ax.axis("off")
add_southwest_colorbar(axes[0], "coolwarm", common_min, common_max,
                       "Mean winter temperature (°C)", width=0.62, x=0.03, y=0.02)
early_recent_map_path = save_tier2_figure(
    fig, f"{config.name.lower()}_winter_temperature_early_vs_recent.pdf",
    panel_titles_ok=True,
    note=(f"Source: {config.name}; complete DJF winters. Both panels share one colour scale, "
          f"so they are directly comparable. County borders are suppressed; state borders are "
          f"drawn in black. {PERIOD_NOTE}"),
)


temperature_periods["change_temp_c"] = (
    temperature_periods["recent_temp_c"] - temperature_periods["early_temp_c"]
)
change_map = merge_county_geometry(
    temperature_periods, "Temperature change", columns=["geoid", "change_temp_c"]
)

change_limit = float(np.nanmax(np.abs(change_map["change_temp_c"])))
fig, ax = plt.subplots(figsize=(8.0, 5.0))
change_map.plot(
    column="change_temp_c", cmap="RdBu_r", vmin=-change_limit, vmax=change_limit,
    linewidth=0, ax=ax,
)
draw_state_borders(ax)
add_southwest_colorbar(ax, "RdBu_r", -change_limit, change_limit,
                       "Change in mean winter temperature (°C)")
ax.axis("off")
fig.tight_layout()
warming_change_map_path = save_tier2_figure(
    fig, f"{config.name.lower()}_winter_temperature_change.pdf",
    note=(f"Source: {config.name}; complete DJF winters. Red is warming, blue is cooling, on a "
          f"diverging scale centred at zero. The comparison is "
          f"{RECENT_PERIOD[0]}–{RECENT_PERIOD[1]} minus {EARLY_PERIOD[0]}–{EARLY_PERIOD[1]}. "
          f"{PERIOD_NOTE}"),
)


# Eyal, 8/28, looking at the change map and the two period maps: "I can see this
# being like the top panel of the figure, and then these two panels at the bottom
# below that to show the two periods. That would be, like, a super nice figure in
# the Data section."
#
# Built as a third exhibit rather than as a replacement: the standalone change and
# early/recent maps stay, because they read better on a slide than a three-panel
# composite does.
fig = plt.figure(figsize=(8.0, 6.5))
grid = fig.add_gridspec(2, 2, height_ratios=[1.30, 1.0], hspace=0.02, wspace=0.01,
                        left=0.01, right=0.99, top=0.99, bottom=0.01)

ax_change = fig.add_subplot(grid[0, :])
change_map.plot(column="change_temp_c", cmap="RdBu_r", vmin=-change_limit, vmax=change_limit,
                linewidth=0, ax=ax_change)
draw_state_borders(ax_change)
add_southwest_colorbar(ax_change, "RdBu_r", -change_limit, change_limit,
                       "Change in mean winter temperature (°C)", width=0.26, y=0.06)
ax_change.set_title("Change between the two periods", fontsize=10.5)
ax_change.axis("off")

for column, period, label, position in [
    ("early_temp_c", EARLY_PERIOD, "Early period", grid[1, 0]),
    ("recent_temp_c", RECENT_PERIOD, "Recent period", grid[1, 1]),
]:
    ax = fig.add_subplot(position)
    temperature_map.plot(column=column, cmap="coolwarm", vmin=common_min, vmax=common_max,
                         linewidth=0, ax=ax)
    draw_state_borders(ax, linewidth=0.35)
    ax.set_title(f"{label}: {period[0]}–{period[1]}", fontsize=9.5)
    ax.axis("off")
    if column == "early_temp_c":
        add_southwest_colorbar(ax, "coolwarm", common_min, common_max,
                               "Mean winter temperature (°C)", width=0.52, x=0.02, y=0.03)

data_section_composite_path = save_tier2_figure(
    fig, f"{config.name.lower()}_winter_warming_data_section.pdf", panel_titles_ok=True,
    note=(f"Source: {config.name}; complete DJF winters. Top: the change in mean winter "
          f"temperature between the two periods, on a diverging scale centred at zero. Bottom: "
          f"the two period means on a shared scale. {PERIOD_NOTE} County borders are suppressed; "
          f"state borders are drawn in black."),
)


# Phase 4 checklist item still open from 8/18: a choropleth of mean winter
# temperature. The early/recent pair shows two ten-winter windows; this is the
# single full-sample climatology, which is what the regressions actually
# condition on.
full_sample_temp = (
    county_winter.groupby("geoid", as_index=False)
    .agg(mean_winter_temp_c=("mean_temp_c", "mean"), n_winters=("mean_temp_c", "count"))
)
full_sample_temp.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_county_mean_winter_temperature.csv", index=False
)
mean_temp_map = merge_county_geometry(
    full_sample_temp, "Mean winter temperature", columns=["geoid", "mean_winter_temp_c"]
)
temp_lo = float(mean_temp_map["mean_winter_temp_c"].min())
temp_hi = float(mean_temp_map["mean_winter_temp_c"].max())

fig, ax = plt.subplots(figsize=(8.0, 4.8))
mean_temp_map.plot(column="mean_winter_temp_c", cmap="coolwarm",
                   vmin=temp_lo, vmax=temp_hi, linewidth=0, ax=ax)
draw_state_borders(ax)
add_southwest_colorbar(ax, "coolwarm", temp_lo, temp_hi, "Mean winter temperature (°C)")
ax.axis("off")
fig.tight_layout()
mean_temp_map_path = save_tier2_figure(
    fig, f"{config.name.lower()}_mean_winter_temperature.pdf",
    note=(f"Source: {config.name}; mean of each county's complete DJF winters, 1982–2025. This "
          f"is the climatology each county's warm-winter anomalies are measured against, so it "
          f"is the baseline the anomaly maps standardise away."),
)


extreme_cold = (
    county_winter.groupby("geoid", as_index=False)
    .agg(mean_extreme_cold_days=("days_extremely_cold", "mean"),
         n_winters=("days_extremely_cold", "count"))
)
extreme_cold.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_county_extreme_cold_days.csv", index=False
)
extreme_cold_map = merge_county_geometry(extreme_cold, "Extreme-cold days")

fig, ax = plt.subplots(figsize=(8.0, 5.0))
cold_limit = float(extreme_cold_map["mean_extreme_cold_days"].max())
extreme_cold_map.plot(
    column="mean_extreme_cold_days", cmap="cividis_r", vmin=0, vmax=cold_limit,
    linewidth=0, ax=ax,
)
draw_state_borders(ax)
add_southwest_colorbar(ax, "cividis_r", 0, cold_limit,
                       "Mean extreme-cold days per winter")
ax.axis("off")
fig.tight_layout()
extreme_cold_map_path = save_tier2_figure(
    fig, f"{config.name.lower()}_extreme_cold_day_count.pdf",
    note=(f"Source: {config.name}; days with a daily minimum below 0°F, averaged over complete "
          f"DJF winters. The 0°F threshold follows the metabolic-stress cutoff in the wildlife "
          f"literature, not the 32°F road-conditions threshold used elsewhere in the panel. "
          f"This is NOT the Winter Severity Index: the WSI adds a snow-depth hazard component "
          f"and runs December through April. See the Winter Severity Index exhibit for that."),
)


# Eyal, 8/28, on the extreme-cold map: "could you do a version of these cold
# extremes like you did here for [the temperature change] -- like the first
# decade, last decade, and the difference?"
early_cold = period_mean(county_winter, "days_extremely_cold", EARLY_PERIOD, "early_cold_days")
recent_cold = period_mean(county_winter, "days_extremely_cold", RECENT_PERIOD, "recent_cold_days")
cold_periods = early_cold.merge(
    recent_cold, on="geoid", suffixes=("_early", "_recent"), validate="one_to_one"
)
cold_periods["change_cold_days"] = (
    cold_periods["recent_cold_days"] - cold_periods["early_cold_days"]
)
cold_periods.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_county_extreme_cold_early_recent.csv", index=False
)
cold_map = merge_county_geometry(cold_periods, "Extreme-cold periods")

cold_period_max = float(cold_map[["early_cold_days", "recent_cold_days"]].max().max())
cold_change_limit = float(np.nanmax(np.abs(cold_map["change_cold_days"])))

fig = plt.figure(figsize=(8.0, 6.5))
grid = fig.add_gridspec(2, 2, height_ratios=[1.0, 1.30], hspace=0.02, wspace=0.01,
                        left=0.01, right=0.99, top=0.99, bottom=0.01)
for column, period, label, position in [
    ("early_cold_days", EARLY_PERIOD, "Early period", grid[0, 0]),
    ("recent_cold_days", RECENT_PERIOD, "Recent period", grid[0, 1]),
]:
    ax = fig.add_subplot(position)
    cold_map.plot(column=column, cmap="cividis_r", vmin=0, vmax=cold_period_max,
                  linewidth=0, ax=ax)
    draw_state_borders(ax, linewidth=0.35)
    ax.set_title(f"{label}: {period[0]}–{period[1]}", fontsize=9.5)
    ax.axis("off")
    if column == "early_cold_days":
        add_southwest_colorbar(ax, "cividis_r", 0, cold_period_max,
                               "Extreme-cold days per winter", width=0.52, x=0.02, y=0.03)

ax_change_cold = fig.add_subplot(grid[1, :])
# RdBu, NOT RdBu_r: the quantity is a count of cold days, so a DECREASE is the
# warming signal and has to read red. Reusing the temperature map's colormap here
# would invert the meaning of the figure.
cold_map.plot(column="change_cold_days", cmap="RdBu", vmin=-cold_change_limit,
              vmax=cold_change_limit, linewidth=0, ax=ax_change_cold)
draw_state_borders(ax_change_cold)
add_southwest_colorbar(ax_change_cold, "RdBu", -cold_change_limit, cold_change_limit,
                       "Change in extreme-cold days per winter", width=0.26, y=0.06)
ax_change_cold.set_title("Change between the two periods", fontsize=10.5)
ax_change_cold.axis("off")

extreme_cold_triptych_path = save_tier2_figure(
    fig, f"{config.name.lower()}_extreme_cold_early_recent_change.pdf", panel_titles_ok=True,
    note=(f"Source: {config.name}; days with a daily minimum below 0°F, averaged over the "
          f"complete DJF winters in each period. Top panels share one scale. In the bottom "
          f"panel RED marks counties that now get FEWER extreme-cold days — the colour scale is "
          f"deliberately reversed relative to the temperature-change map, because for a count of "
          f"cold days a decrease is the warming signal. {PERIOD_NOTE}"),
)


# --------------------------------------------------------------------------
# Warm-winter anomalies, defined to MATCH the regression variable.
#
# Conflict found while auditing on 9/10/26: this notebook previously flagged a
# DETRENDED residual above 1.5 residual SD, with a >=30-complete-winter filter,
# while codeSTATA/build_main_data_county_year.do SECTION 7 builds
# warm_winter_1sd / warm_winter_2sd as the RAW mean winter temperature above the
# county's own full-sample mean plus k SD -- undetrended, unfiltered. Figure 5
# and Table 1 were therefore describing different objects, which defeats the
# stated purpose of these exhibits ("as a collage of descriptive evidence, this
# all helps us think about where the identifying variation is coming from",
# Eyal, 8/28).
#
# Eyal also asked on 8/28 to drop the arbitrary 1.5 SD cut in favour of a
# 1-sigma and a 2-sigma version ("someone would ask, well, why one and a half?"),
# each with its own companion time series. That rebuild is the moment to make
# the descriptive exhibit describe the regressor.
#
# The detrended construction is kept as a Tier 1 diagnostic: it answers a
# different and still useful question -- which winters were anomalous relative
# to where that county's climate was heading, rather than relative to its
# whole-sample average.
# --------------------------------------------------------------------------
ANOMALY_THRESHOLDS = (1.0, 2.0)


def threshold_tag(threshold):
    return f"{threshold:g}".replace(".", "p") + "sd"


def classify_warm_anomalies(frame, threshold, detrend=False, min_winters=0):
    """Flag county-winters warmer than the county's own climatology by `threshold` SD.

    detrend=False reproduces SECTION 7 of build_main_data_county_year.do exactly:
    the reference mean and SD are the county's own over the full sample, taken on
    raw levels. detrend=True removes each county's linear trend first and
    standardises the residual, which is the Tier 1 diagnostic.
    """
    work = frame.dropna(subset=["mean_temp_c", "winter_year"]).copy()
    grouped = work.groupby("geoid")["mean_temp_c"]

    if detrend:
        def _residual(block):
            block = block.sort_values("winter_year")
            slope, intercept = np.polyfit(block["winter_year"], block["mean_temp_c"], 1)
            block["fitted_temp_c"] = intercept + slope * block["winter_year"]
            block["county_trend_c_per_decade"] = slope * 10
            return block
        work = (work.groupby("geoid", group_keys=False)[work.columns]
                .apply(_residual))
        work["deviation_c"] = work["mean_temp_c"] - work["fitted_temp_c"]
        reference_sd = work.groupby("geoid")["deviation_c"].transform("std")
    else:
        work["county_mean_temp_c"] = grouped.transform("mean")
        work["deviation_c"] = work["mean_temp_c"] - work["county_mean_temp_c"]
        reference_sd = grouped.transform("std")   # pandas uses ddof=1, as Stata's egen sd does

    work["reference_sd_c"] = reference_sd
    work["anomaly_z"] = np.where(reference_sd > 0, work["deviation_c"] / reference_sd, np.nan)
    work["anomalously_warm"] = work["anomaly_z"] > threshold

    if min_winters:
        eligible = work.groupby("geoid")["winter_year"].transform("nunique") >= min_winters
        work = work[eligible].copy()
    return work


warm_anomalies = {
    threshold: classify_warm_anomalies(county_winter, threshold)
    for threshold in ANOMALY_THRESHOLDS
}
for threshold, flagged in warm_anomalies.items():
    flagged.to_csv(
        TIER2_TABLES_DIR
        / f"{config.name.lower()}_county_winter_warm_anomalies_{threshold_tag(threshold)}.csv",
        index=False,
    )

# Kept for the Kodama run: these counts must equal `count if warm_winter_1sd==1`
# (and the 2sd equivalent) in the merged county-year .dta. A mismatch means the
# two pipelines disagree about which winters are complete, or about how the
# three monthly means are averaged -- see the mean-winter-temperature row in
# decisions_for_eyal.
anomaly_crosscheck = pd.DataFrame([
    {
        "threshold": f"{threshold:g} SD",
        "stata_variable": f"warm_winter_{threshold:g}sd",
        "flagged_county_winters": int(flagged["anomalously_warm"].sum()),
        "eligible_county_winters": int(len(flagged)),
        "counties": int(flagged["geoid"].nunique()),
        "share_flagged": float(flagged["anomalously_warm"].mean()),
    }
    for threshold, flagged in warm_anomalies.items()
])
anomaly_crosscheck.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_anomaly_crosscheck_vs_merged_dta.csv", index=False
)

ANOMALY_CAVEATS = [
    "The reference distribution is each county's own full 1982–2025 sample, so later winters "
    "inform how earlier winters are classified. A fixed early baseline (e.g. 1982–2000) would "
    "remove the look-ahead at the cost of a shorter reference period.",
    "The measure is one-directional: only unusually WARM winters are flagged, which is the "
    "shock the wildlife channel runs through.",
    "No trend is removed, so a county that warmed steadily accumulates flagged winters at the "
    "end of the sample. This matches the regression variable; the detrended alternative is "
    "reported as a Tier 1 diagnostic.",
    "A county's mapped frequency partly reflects the shape of its own temperature distribution, "
    "not exposure to warm shocks alone.",
    "Definition and construction are identical to warm_winter_1sd / warm_winter_2sd in "
    "codeSTATA/build_main_data_county_year.do SECTION 7, so these maps describe the regressor.",
]
anomaly_definition = pd.DataFrame([{
    "status": "Matches the regression variable (build_main_data_county_year.do SECTION 7)",
    "metric": "county-winter mean temperature (DJF)",
    "reference_distribution": "county-specific full sample (1982–2025), raw levels",
    "trend_treatment": "none (undetrended)",
    "thresholds": ", ".join(f"> {t:g} SD" for t in ANOMALY_THRESHOLDS),
    "minimum_complete_winters": "none",
    "frequency_measure": "share of complete winters",
}])
anomaly_definition.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_anomaly_definition.csv", index=False
)
anomaly_caveats = pd.DataFrame(
    {"caveat": ANOMALY_CAVEATS}, index=pd.RangeIndex(1, len(ANOMALY_CAVEATS) + 1)
).reset_index(names="n")
anomaly_caveats.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_anomaly_definition_caveats.csv", index=False
)

# Tier 1 diagnostic: the same winters under the detrended definition, for comparison.
warm_anomalies_detrended = classify_warm_anomalies(
    county_winter, 1.0, detrend=True, min_winters=30
)
warm_anomalies_detrended.to_csv(
    TABLES_DIR / f"{config.name.lower()}_county_winter_warm_anomalies_detrended_diagnostic.csv",
    index=False,
)
print(anomaly_crosscheck.to_string(index=False))
display(anomaly_definition)
display(anomaly_caveats)


# One map per threshold. The colour scales are deliberately INDEPENDENT: 2-sigma
# winters are far rarer, and a shared scale renders the 2-sigma map almost blank.
anomaly_frequency_paths = {}
anomaly_frequency_tables = {}

for threshold in ANOMALY_THRESHOLDS:
    tag = threshold_tag(threshold)
    flagged = warm_anomalies[threshold]
    frequency = (
        flagged.groupby(["geoid", "state_fips", "county_name"], as_index=False)
        .agg(anomalous_warm_winters=("anomalously_warm", "sum"),
             eligible_winters=("anomalously_warm", "size"))
    )
    frequency["anomalous_warm_share"] = (
        frequency["anomalous_warm_winters"] / frequency["eligible_winters"]
    )
    frequency.to_csv(
        TIER2_TABLES_DIR
        / f"{config.name.lower()}_county_anomalous_warm_winter_frequency_{tag}.csv",
        index=False,
    )
    anomaly_frequency_tables[threshold] = frequency

    anomaly_map = merge_county_geometry(
        frequency, f"Warm-anomaly frequency ({threshold:g} SD)",
        columns=["geoid", "anomalous_warm_share"],
    )
    share_limit = float(anomaly_map["anomalous_warm_share"].max())

    fig, ax = plt.subplots(figsize=(8.0, 4.8))
    anomaly_map.plot(column="anomalous_warm_share", cmap="YlOrRd",
                     vmin=0, vmax=share_limit, linewidth=0, ax=ax)
    draw_state_borders(ax)
    add_southwest_colorbar(ax, "YlOrRd", 0, share_limit,
                           f"Share of winters warmer than +{threshold:g} SD", fmt="%.2f")
    ax.axis("off")
    fig.tight_layout()
    anomaly_frequency_paths[threshold] = save_tier2_figure(
        fig, f"{config.name.lower()}_anomalous_warm_winter_frequency_{tag}.pdf",
        note=(f"Source: {config.name}; complete DJF winters, 1982–2025. A winter is flagged when "
              f"the county's mean winter temperature exceeds that county's own full-sample mean "
              f"by more than {threshold:g} standard deviations — the identical construction to "
              f"warm_winter_{threshold:g}sd in the merged county-year panel, so this map "
              f"describes the regressor used in the collisions model. Colour scales differ "
              f"between the 1 SD and 2 SD maps; 2 SD winters are far rarer."),
    )


# Eyal, 8/28: "a figure like this will go with each map." The map is
# cross-sectional -- which counties run warm relative to their own climatology --
# and this is the time-series companion showing those shocks are episodic rather
# than a steady drift.
anomaly_time_paths = {}

for threshold in ANOMALY_THRESHOLDS:
    tag = threshold_tag(threshold)
    flagged = warm_anomalies[threshold]
    annual = (
        flagged.groupby("winter_year", as_index=False)
        .agg(anomalous_counties=("anomalously_warm", "sum"),
             eligible_counties=("anomalously_warm", "size"))
    )
    annual["anomalous_county_share"] = (
        annual["anomalous_counties"] / annual["eligible_counties"]
    )
    annual.to_csv(
        TIER2_TABLES_DIR
        / f"{config.name.lower()}_annual_anomalous_warm_winter_frequency_{tag}.csv",
        index=False,
    )

    fig, ax = plt.subplots(figsize=(8.0, 4.3))
    ax.bar(annual["winter_year"], annual["anomalous_county_share"] * 100,
           color=TIER2_COLORS["annual"], width=0.8)
    ax.axhline(100 * flagged["anomalously_warm"].mean(), color=TIER2_COLORS["trend"],
               lw=2, ls="--", label="Full-sample county-winter share")
    ax.set(xlabel="Winter year (December–February)",
           ylabel=f"Counties above +{threshold:g} SD (%)", ylim=(0, None))
    ax.grid(axis="y", alpha=0.2)
    ax.spines[["top", "right"]].set_visible(False)
    ax.legend(frameon=False, loc="upper left")
    fig.tight_layout()
    anomaly_time_paths[threshold] = save_tier2_figure(
        fig, f"{config.name.lower()}_anomalous_warm_winter_time_series_{tag}.pdf",
        note=(f"Source: {config.name}; complete DJF winters. Each bar is the share of counties "
              f"whose winter mean exceeded that county's own full-sample mean by more than "
              f"{threshold:g} standard deviations. Warm winters arrive as national episodes "
              f"rather than as a steady drift, and they are spread across the sample rather "
              f"than concentrated in recent years. Companion to the {threshold:g} SD frequency map."),
    )


decade_order = [d for d in ["1980s", "1990s", "2000s", "2010s", "2020–2025"]
                if d in set(county_winter["decade"])]

# Periods hold unequal numbers of winters (the 1980s begin at the first complete
# winter, 1982; 2020–2025 covers six), so each label carries its own sample size.
decade_summary = (
    county_winter.groupby("decade")
    .agg(first_winter=("winter_year", "min"), last_winter=("winter_year", "max"),
         n_winters=("winter_year", "nunique"), n_county_winters=("mean_temp_c", "size"),
         median_temp_c=("mean_temp_c", "median"))
    .reindex(decade_order)
)
decade_summary.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_decade_distribution_sample_sizes.csv"
)
decade_ticks = [
    f"{decade}\n{int(row.first_winter)}–{int(row.last_winter)} ({int(row.n_winters)} winters)"
    for decade, row in decade_summary.iterrows()
]
decade_counts_note = "; ".join(
    f"{decade}: n={int(row.n_county_winters):,}" for decade, row in decade_summary.iterrows()
)


def draw_violins(ax, datasets, weights=None, color=None, center_line=None):
    """Draw one violin per period from a (optionally weighted) Gaussian KDE.

    Both the unweighted and the area-weighted exhibits go through this same
    path so the two are visually comparable; matplotlib's own violinplot takes
    no weights, and mixing the two renderers would make a difference in method
    look like a difference in the data.
    """
    colour = color or TIER2_COLORS["annual"]
    finite = np.concatenate([np.asarray(d, dtype=float) for d in datasets])
    finite = finite[np.isfinite(finite)]
    pad = 0.04 * (finite.max() - finite.min())
    grid = np.linspace(finite.min() - pad, finite.max() + pad, 320)

    densities, medians = [], []
    for position, values in enumerate(datasets):
        w = None if weights is None else weights[position]
        densities.append(weighted_kde(values, w, grid))
        medians.append(weighted_quantile(
            values, np.ones_like(values) if w is None else w, 0.5))
    peak = max(float(d.max()) for d in densities) or 1.0

    for position, (density, median) in enumerate(zip(densities, medians)):
        half = 0.42 * density / peak
        ax.fill_betweenx(grid, position - half, position + half,
                         facecolor=colour, edgecolor="white", linewidth=0.6, alpha=0.78)
        half_at_median = float(np.interp(median, grid, half))
        ax.plot([position - half_at_median, position + half_at_median], [median, median],
                color="black", lw=2, solid_capstyle="butt", zorder=3)
    if center_line is not None:
        ax.axhline(center_line, color="#888888", lw=1, ls="--", zorder=0)
    ax.set_xticks(np.arange(len(decade_order)), decade_ticks, fontsize=8)
    ax.set_xlim(-0.6, len(decade_order) - 0.4)
    ax.grid(axis="y", alpha=0.2)
    ax.spines[["top", "right"]].set_visible(False)


def period_values(column, weight_col=None):
    values, weights = [], []
    for decade in decade_order:
        block = county_winter.loc[county_winter["decade"].eq(decade), [column]
                                  + ([weight_col] if weight_col else [])].dropna()
        values.append(block[column].to_numpy())
        weights.append(block[weight_col].to_numpy() if weight_col else None)
    return values, (None if weight_col is None else weights)


# --- Tier 1 only: pooled levels ------------------------------------------------
# Eyal, 8/28: "this is nice, but to be honest, I don't think this will make it to
# the paper or the appendix ... I don't think this adds a whole lot of information
# relative to the other figures already." Demoted rather than deleted: it is the
# reference the county-demeaned exhibit below is implicitly compared against.
level_values, _ = period_values("mean_temp_c")
fig, ax = plt.subplots(figsize=(8.0, 4.6))
draw_violins(ax, level_values)
ax.set(title="Distribution of county winter temperatures by period",
       xlabel="Winter period", ylabel="County-winter mean temperature (°C)")
ax.text(0, -0.24, source_note(
            f"Source: {config.name}; all complete county-winters. Tier 1 diagnostic — the spread "
            f"is dominated by persistent geography, so see the county-demeaned exhibit for the "
            f"temporal shift. County-winters per period — {decade_counts_note}."),
        transform=ax.transAxes, fontsize=7.5, va="top", color="#555555")
fig.tight_layout()
decade_levels_tier1_path = save_figure_pdf(
    fig, f"{config.name.lower()}_winter_temperature_distributions_by_decade_tier1.pdf"
)

# --- Tier 2: county-demeaned, unweighted and area-weighted ---------------------
# Removing each county's own mean strips out persistent geography, which is what
# makes the temporal shift visible at all.
county_winter["temp_deviation_c"] = (
    county_winter["mean_temp_c"] - county_winter.groupby("geoid")["mean_temp_c"].transform("mean")
)

deviation_values, _ = period_values("temp_deviation_c")
fig, ax = plt.subplots(figsize=(8.0, 4.5))
draw_violins(ax, deviation_values, center_line=0.0)
ax.set(xlabel="Winter period", ylabel="Deviation from the county's own 1982–2025 mean (°C)")
fig.tight_layout()
decade_demeaned_path = save_tier2_figure(
    fig, f"{config.name.lower()}_national_winter_temperature_deviations_by_decade.pdf",
    note=(f"Source: {config.name}; all complete county-winters, each expressed as a deviation "
          f"from its own county's full-sample mean. Black bars mark medians; violin width shows "
          f"density. Removing persistent geography isolates the temporal shift. Periods contain "
          f"unequal numbers of winters — {decade_counts_note}. {ESTIMAND_NOTE}"),
)

weighted_deviation_values, deviation_weights = period_values(
    "temp_deviation_c", "land_area_km2"
)
fig, ax = plt.subplots(figsize=(8.0, 4.5))
draw_violins(ax, weighted_deviation_values, weights=deviation_weights,
             color=TIER2_COLORS["weighted"], center_line=0.0)
ax.set(xlabel="Winter period", ylabel="Deviation from the county's own 1982–2025 mean (°C)")
fig.tight_layout()
decade_demeaned_area_path = save_tier2_figure(
    fig, f"{config.name.lower()}_national_winter_temperature_deviations_by_decade_area_weighted.pdf",
    note=(f"Source: {config.name}; the same county-winter deviations as the preceding exhibit, "
          f"with each county weighted by its land area rather than counted once. Densities are "
          f"weighted Gaussian kernel estimates and medians are weighted medians. "
          f"{ESTIMAND_NOTE_AREA}"),
)
display(decade_summary)


# ERA5 is a targeted robustness check, not a co-equal dataset.
assert ERA5_CONFIG.monthly_path.exists() and ERA5_CONFIG.derived_path.exists(), (
    "ERA5 robustness inputs are missing. Expected:\n"
    f"  - {ERA5_CONFIG.monthly_path}\n  - {ERA5_CONFIG.derived_path}\n"
    "Run the ERA5 extraction and aggregation steps (03-06) before this notebook."
)

era5_monthly, _ = load_weather_panel(ERA5_CONFIG)
era5_winter, _, _ = construct_county_winter_panel(era5_monthly)
prism_national = (county_winter.groupby("winter_year", as_index=False)["mean_temp_c"]
                  .mean().rename(columns={"mean_temp_c": "PRISM"}))
era5_national = (era5_winter.groupby("winter_year", as_index=False)["mean_temp_c"]
                 .mean().rename(columns={"mean_temp_c": "ERA5"}))
comparison = prism_national.merge(era5_national, on="winter_year", validate="one_to_one")
comparison["era5_minus_prism_c"] = comparison["ERA5"] - comparison["PRISM"]
comparison.to_csv(
    TIER2_TABLES_DIR / "prism_era5_national_winter_temperature_comparison.csv", index=False
)
mean_offset = comparison["era5_minus_prism_c"].mean()
offset_range = (comparison["era5_minus_prism_c"].min(), comparison["era5_minus_prism_c"].max())
correlation = comparison["PRISM"].corr(comparison["ERA5"])

fig, ax = plt.subplots(figsize=(8.0, 4.6))
ax.plot(comparison["winter_year"], comparison["PRISM"], label="PRISM",
        color=TIER2_COLORS["annual"], lw=1.7)
ax.plot(comparison["winter_year"], comparison["ERA5"], label="ERA5",
        color=TIER2_COLORS["trend"], lw=1.5)
ax.set(xlabel="Winter year", ylabel="Unweighted county mean (°C)")
ax.legend(frameon=False, loc="upper left")
ax.grid(axis="y", alpha=0.2)
ax.spines[["top", "right"]].set_visible(False)
fig.tight_layout()
era5_comparison_path = save_tier2_figure(
    fig, "prism_era5_national_winter_temperature_comparison.pdf",
    note=(f"ERA5 minus PRISM: mean {mean_offset:+.2f}°C (range {offset_range[0]:+.2f} to "
          f"{offset_range[1]:+.2f}); correlation {correlation:.3f}. The two products track each "
          f"other closely and the gap does not widen or close systematically over the sample, "
          f"which is the property that matters for robustness. PRISM is the analysis dataset; "
          f"ERA5 is a robustness check only. {ESTIMAND_NOTE}"),
)

# Area-weighted companion (Eyal, 8/28, on the exhibits that pool counties into a
# national number).
prism_national_area = weighted_annual_mean(
    county_winter, "mean_temp_c", "land_area_km2").rename(columns={"mean_temp_c": "PRISM"})
era5_area = era5_winter.merge(
    county_geometry[["geoid", "land_area_km2"]], on="geoid", how="left", validate="many_to_one")
era5_national_area = weighted_annual_mean(
    era5_area, "mean_temp_c", "land_area_km2").rename(columns={"mean_temp_c": "ERA5"})
comparison_area = prism_national_area[["winter_year", "PRISM"]].merge(
    era5_national_area[["winter_year", "ERA5"]], on="winter_year", validate="one_to_one")
area_offset = (comparison_area["ERA5"] - comparison_area["PRISM"]).mean()
area_correlation = comparison_area["PRISM"].corr(comparison_area["ERA5"])

fig, ax = plt.subplots(figsize=(8.0, 4.3))
ax.plot(comparison_area["winter_year"], comparison_area["PRISM"], label="PRISM",
        color=TIER2_COLORS["weighted"], lw=1.7)
ax.plot(comparison_area["winter_year"], comparison_area["ERA5"], label="ERA5",
        color=TIER2_COLORS["trend"], lw=1.5)
ax.set(xlabel="Winter year", ylabel="Area-weighted county mean (°C)")
ax.legend(frameon=False, loc="upper left")
ax.grid(axis="y", alpha=0.2)
ax.spines[["top", "right"]].set_visible(False)
fig.tight_layout()
era5_comparison_area_path = save_tier2_figure(
    fig, "prism_era5_national_winter_temperature_comparison_area_weighted.pdf",
    note=(f"The same PRISM–ERA5 comparison with counties weighted by land area: mean offset "
          f"{area_offset:+.2f}°C, correlation {area_correlation:.3f}. {ESTIMAND_NOTE_AREA}"),
)
print(f"ERA5 minus PRISM national winter temperature: mean {mean_offset:+.3f}°C, "
      f"correlation {correlation:.4f}")


# Phase 4 checklist item open since 8/18, buildable only since 9/8/26 when
# days_snow_depth_18in landed upstream and SECTION 7 of
# build_main_data_county_year.do started populating winter_severity_index.
#
# The index is READ from the merged county-year panel rather than recomputed
# here. The merge script's header is explicit that the four winter measures are
# "built here, not in the estimation .do files, so every downstream script uses
# the identical construction" -- recomputing in Python would create a third
# definition, which is exactly the failure this notebook already has one of (see
# the anomaly section).
MERGED_PANEL_PATH = REPO_ROOT / "dataSTATA" / "main_data_county_year.dta"
wsi_map_path = None
wsi_sensitivity_path = None

if not MERGED_PANEL_PATH.exists():
    # Deliberately a loud skip rather than an assertion: the exhibit depends on a
    # different pipeline's output, and a missing merge should not cost the whole
    # weather report.
    print(f"NOTE: {MERGED_PANEL_PATH} not found -- the Winter Severity Index exhibits are "
          f"skipped. Run codeSTATA/build_main_data_county_year.do first.")
else:
    merged = pd.read_stata(MERGED_PANEL_PATH, convert_categoricals=False)
    key = next((c for c in ("geoid", "fips", "fips_num", "county_fips") if c in merged.columns), None)
    assert key is not None, (
        f"No recognisable county key in {MERGED_PANEL_PATH.name}; columns include "
        f"{sorted(merged.columns)[:15]}"
    )
    merged["geoid"] = (merged[key].astype("Int64").astype(str).str.zfill(5)
                       if pd.api.types.is_numeric_dtype(merged[key])
                       else merged[key].astype(str).str.zfill(5))

    wsi_columns = [c for c in ("winter_severity_index", "winter_severity_index_snow12",
                               "wsi_cold_days", "wsi_snow_days") if c in merged.columns]
    assert "winter_severity_index" in wsi_columns, (
        "winter_severity_index is not in the merged panel -- rerun SECTION 7 of "
        "build_main_data_county_year.do."
    )
    wsi_county = (merged.groupby("geoid", as_index=False)[wsi_columns].mean()
                  .rename(columns={c: f"mean_{c}" for c in wsi_columns}))
    wsi_county = wsi_county[wsi_county["mean_winter_severity_index"].notna()]
    wsi_county.to_csv(
        TIER2_TABLES_DIR / f"{config.name.lower()}_county_winter_severity_index.csv", index=False
    )

    wsi_geo = merge_county_geometry(
        wsi_county, "Winter Severity Index", columns=["geoid", "mean_winter_severity_index"]
    )
    wsi_hi = float(wsi_geo["mean_winter_severity_index"].max())
    fig, ax = plt.subplots(figsize=(8.0, 4.8))
    wsi_geo.plot(column="mean_winter_severity_index", cmap="magma_r", vmin=0, vmax=wsi_hi,
                 linewidth=0, ax=ax)
    draw_state_borders(ax)
    add_southwest_colorbar(ax, "magma_r", 0, wsi_hi, "Mean Winter Severity Index")
    ax.axis("off")
    fig.tight_layout()
    wsi_map_path = save_tier2_figure(
        fig, f"{config.name.lower()}_winter_severity_index.pdf",
        note=("Winter Severity Index (Kohn 1975 / Wisconsin DNR): the count of days from 1 "
              "December to 30 April with a minimum temperature at or below 0°F, plus the count "
              "of days with at least 18 inches of snow on the ground; a day meeting both "
              "conditions counts twice. Conventional bands: below 50 mild, 50–80 moderate, "
              "80–100 moderately severe, above 100 very severe. Read from the merged county-year "
              "panel, not recomputed here. CAVEAT: snow depth is an ERA5-Land grid-box average "
              "averaged again over a county, and that spatial averaging removes the local maxima "
              "an 18-inch cutoff is meant to catch, so across most of the eastern and midwestern "
              "deer range the index is driven almost entirely by its cold-day component."),
    )

    if "mean_winter_severity_index_snow12" in wsi_county.columns:
        sens = merge_county_geometry(
            wsi_county, "WSI sensitivity",
            columns=["geoid", "mean_winter_severity_index_snow12"],
        )
        sens_hi = float(sens["mean_winter_severity_index_snow12"].max())
        shared_hi = max(wsi_hi, sens_hi)
        fig, axes = plt.subplots(1, 2, figsize=(8.0, 3.4))
        for ax, frame, column, label in [
            (axes[0], wsi_geo, "mean_winter_severity_index", "Kohn: snow depth ≥ 18 in"),
            (axes[1], sens, "mean_winter_severity_index_snow12", "Sensitivity: snow depth ≥ 12 in"),
        ]:
            frame.plot(column=column, cmap="magma_r", vmin=0, vmax=shared_hi, linewidth=0, ax=ax)
            draw_state_borders(ax, linewidth=0.35)
            ax.set_title(label, fontsize=9.5)
            ax.axis("off")
        add_southwest_colorbar(axes[0], "magma_r", 0, shared_hi,
                               "Mean Winter Severity Index", width=0.58, x=0.02, y=0.03)
        fig.tight_layout()
        wsi_sensitivity_path = save_tier2_figure(
            fig, f"{config.name.lower()}_winter_severity_index_sensitivity.pdf",
            panel_titles_ok=True,
            note=("The same index with the snow-hazard component's threshold lowered from Kohn's "
                  "18 inches to 12 inches, on a shared colour scale. This is a robustness check, "
                  "not an alternative definition of the Kohn index: it shows how much of the "
                  "mapped variation is carried by the cold-day component alone once county-level "
                  "spatial averaging has flattened the snow signal."),
        )


# Eyal, 9/1: "is it the case that a county has warmed by one degree Celsius in
# the summer, does that provide me everything I need to know about how our winter
# is now? ... It might be, but it also could be that summers have gone up by one
# degree Celsius, winters have only gone up by point two. If that's the case,
# that's super interesting, because then it means that what we know from the
# literature on climate change impacts ... doesn't provide us all the information
# about how winters are becoming [warmer]."
#
# Two exhibits, both binscatters rather than maps -- he was explicit that these
# are not maps, and ~140,000 county-years would be an unreadable ink blob as a
# raw scatter.
SEASONS = {"Winter": (12, 1, 2), "Spring": (3, 4, 5),
           "Summer": (6, 7, 8), "Fall": (9, 10, 11)}
SEASON_ORDER = ["Winter", "Spring", "Summer", "Fall"]
MONTH_TO_SEASON = {month: season for season, months in SEASONS.items() for month in months}


def construct_county_season_panel(monthly):
    """County-season-year means, built the same way as the winter panel.

    Same completeness rules and the same day-count weighting, so the Winter rows
    of this panel are identical to county_winter -- asserted below. December is
    keyed to the FOLLOWING year, matching winter_year and the L1. construction in
    build_main_data_county_year.do.
    """
    work = monthly.dropna(subset=["mean_temp_c"]).copy()
    work["season"] = work["month"].map(MONTH_TO_SEASON)
    work["season_year"] = work["year"] + (work["month"] == 12).astype(int)
    work["month_days"] = [
        calendar.monthrange(int(y), int(m))[1] for y, m in zip(work["year"], work["month"])
    ]

    keys = ["geoid", "state_fips", "season", "season_year"]
    completeness = work.groupby(keys, as_index=False).agg(
        n_months=("month", "nunique"), observed_days=("n_days", "sum"),
        expected_days=("month_days", "sum"),
    )
    completeness["complete_season"] = (
        completeness["n_months"].eq(3)
        & completeness["observed_days"].eq(completeness["expected_days"])
    )
    if "is_incomplete" in work:
        flags = work.groupby(keys, as_index=False)["is_incomplete"].any()
        completeness = completeness.merge(flags, on=keys, validate="one_to_one")
        completeness["complete_season"] &= ~completeness["is_incomplete"]

    work = work.merge(completeness[keys + ["complete_season"]], on=keys, validate="many_to_one")
    work = work[work["complete_season"]].copy()
    work["_wv"] = work["mean_temp_c"] * work["n_days"]
    panel = work.groupby(keys, as_index=False).agg(
        _wv=("_wv", "sum"), _w=("n_days", "sum"), n_months=("month", "nunique")
    )
    panel["mean_temp_c"] = panel["_wv"] / panel["_w"]
    return panel.drop(columns=["_wv", "_w"])


season_panel = construct_county_season_panel(df)

# The winter slice of this panel must reproduce the winter panel exactly. If it
# does not, the seasonal anomalies below are not comparable with the winter
# exhibits and nothing downstream should be trusted.
_winter_check = (
    season_panel[season_panel["season"].eq("Winter")]
    .rename(columns={"season_year": "winter_year", "mean_temp_c": "season_temp_c"})
    .merge(county_winter[["geoid", "winter_year", "mean_temp_c"]],
           on=["geoid", "winter_year"], how="inner", validate="one_to_one")
)
_max_gap = float((_winter_check["season_temp_c"] - _winter_check["mean_temp_c"]).abs().max())
assert _max_gap < 1e-9, (
    f"Season panel disagrees with the winter panel by up to {_max_gap:.3g}°C; the two "
    f"aggregations have diverged."
)
print(f"Season panel: {len(season_panel):,} county-season-years; winter slice matches the "
      f"winter panel to {_max_gap:.1e}°C across {len(_winter_check):,} rows.")

# --- standardised anomalies, same definition as the winter exhibits (WP4) ------
grouped = season_panel.groupby(["geoid", "season"])["mean_temp_c"]
season_panel["season_mean_c"] = grouped.transform("mean")
season_panel["season_sd_c"] = grouped.transform("std")
season_panel["anomaly_z"] = np.where(
    season_panel["season_sd_c"] > 0,
    (season_panel["mean_temp_c"] - season_panel["season_mean_c"]) / season_panel["season_sd_c"],
    np.nan,
)

anomaly_wide = season_panel.pivot_table(
    index=["geoid", "season_year"], columns="season", values="anomaly_z"
).reset_index().dropna(subset=SEASON_ORDER)
anomaly_wide.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_county_season_anomalies.csv", index=False
)

# --- per-county, per-season warming trends ------------------------------------
def season_trends(panel):
    rows = []
    for (geoid, season), block in panel.groupby(["geoid", "season"]):
        block = block.dropna(subset=["mean_temp_c", "season_year"])
        if block["season_year"].nunique() < 10:
            continue
        slope = np.polyfit(block["season_year"], block["mean_temp_c"], 1)[0]
        rows.append({"geoid": geoid, "season": season, "trend_c_per_decade": slope * 10})
    return pd.DataFrame(rows)


season_trend_long = season_trends(season_panel)
trend_wide = season_trend_long.pivot_table(
    index="geoid", columns="season", values="trend_c_per_decade"
).reset_index().dropna(subset=SEASON_ORDER)
trend_wide.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_county_season_trends.csv", index=False
)


def binscatter(ax, x, y, bins=20, colour=None, point_alpha=None):
    """Equal-count bins of x, plotting the within-bin means."""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    keep = np.isfinite(x) & np.isfinite(y)
    x, y = x[keep], y[keep]
    colour = colour or TIER2_COLORS["annual"]
    if point_alpha:
        ax.scatter(x, y, s=3, color=colour, alpha=point_alpha, linewidths=0, zorder=1)
    edges = np.quantile(x, np.linspace(0, 1, bins + 1))
    edges[-1] += 1e-9
    index = np.clip(np.searchsorted(edges, x, side="right") - 1, 0, bins - 1)
    bin_x = np.array([x[index == b].mean() if (index == b).any() else np.nan for b in range(bins)])
    bin_y = np.array([y[index == b].mean() if (index == b).any() else np.nan for b in range(bins)])
    ax.scatter(bin_x, bin_y, s=26, color=colour, edgecolor="white", linewidth=0.6, zorder=3)
    slope, intercept = np.polyfit(x, y, 1)
    line_x = np.array([x.min(), x.max()])
    ax.plot(line_x, intercept + slope * line_x, color=TIER2_COLORS["trend"], lw=1.8, zorder=4)
    lo = min(x.min(), y.min())
    hi = max(x.max(), y.max())
    ax.plot([lo, hi], [lo, hi], color="#999999", lw=1, ls="--", zorder=2)
    ax.set_xlim(x.min() - 0.03 * (x.max() - x.min()), x.max() + 0.03 * (x.max() - x.min()))
    return float(np.corrcoef(x, y)[0, 1]), float(slope)


def cross_season_panel_figure(frame, value_label, short_label, filename, note,
                              point_alpha=None):
    fig, axes = plt.subplots(1, 3, figsize=(8.0, 3.3), sharey=True)
    stats = {}
    for ax, season in zip(axes, ["Spring", "Summer", "Fall"]):
        r, slope = binscatter(ax, frame[season], frame["Winter"], point_alpha=point_alpha)
        stats[season] = (r, slope)
        ax.set_xlabel(f"{season} {short_label}", fontsize=9)
        ax.text(0.04, 0.94, f"r = {r:.2f}\nslope = {slope:.2f}", transform=ax.transAxes,
                fontsize=8, va="top", ha="left")
        ax.grid(alpha=0.15)
        ax.spines[["top", "right"]].set_visible(False)
    axes[0].set_ylabel(f"Winter {value_label}", fontsize=9)
    fig.tight_layout(w_pad=1.8)
    path = save_tier2_figure(fig, filename, note=note)
    return path, stats


season_anomaly_path, anomaly_stats = cross_season_panel_figure(
    anomaly_wide, "temperature anomaly (SD)", "anomaly (SD)",
    f"{config.name.lower()}_cross_season_anomaly_correlation.pdf",
    note=("Source: PRISM; one observation per county-year, standardised within county and "
          "season against that county-season's own 1982–2025 mean and standard deviation — the "
          "same construction as the warm-winter exhibits. Dots are the means of 20 equal-count "
          "bins; the orange line is the pooled OLS fit and the grey dashed line is the 45° line. "
          "Points on the 45° line would mean a season's anomaly is fully informative about the "
          "same year's winter anomaly."),
)
season_trend_path, trend_stats = cross_season_panel_figure(
    trend_wide, "warming trend (°C per decade)", "trend (°C/decade)",
    f"{config.name.lower()}_cross_season_trend_correlation.pdf",
    note=("Source: PRISM; one observation per county — the OLS trend in that county's seasonal "
          "mean temperature, 1982–2025, in °C per decade. Grey points are counties, coloured "
          "dots are the means of 20 equal-count bins, orange is the pooled fit and the grey "
          "dashed line is the 45° line. Counties below the 45° line have warmed LESS in winter "
          "than in the season on the horizontal axis."),
    point_alpha=0.12,
)

# The table is what answers Eyal's question in numbers; the binscatters show the shape.
trend_summary = (
    season_trend_long.groupby("season")["trend_c_per_decade"]
    .agg(mean="mean", p25=lambda s: s.quantile(0.25), median="median",
         p75=lambda s: s.quantile(0.75), sd="std", counties="size")
    .reindex(SEASON_ORDER).reset_index()
)
trend_correlations = trend_wide[SEASON_ORDER].corr().round(3)
trend_summary.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_season_trend_summary.csv", index=False
)
trend_correlations.to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_season_trend_correlations.csv"
)
anomaly_wide[SEASON_ORDER].corr().round(3).to_csv(
    TIER2_TABLES_DIR / f"{config.name.lower()}_season_anomaly_correlations.csv"
)
display(trend_summary)
display(trend_correlations)


# Report order. `None` entries are exhibits whose upstream input was missing on
# this run (currently only the Winter Severity Index pair, which needs the merged
# county-year panel); they drop out of the index and the report's expected list
# rather than failing the run.
_ordered = [
    ("National long-run warming", national_warming_path),
    ("National long-run warming, area-weighted", national_warming_area_path),
    ("State trends pooled", pooled_state_trends_path),
    ("State trends pooled, by EPA region", pooled_state_trends_region_path),
    ("Data-section composite (change + both periods)", data_section_composite_path),
    ("Mean winter temperature", mean_temp_map_path),
    ("Early versus recent temperature", early_recent_map_path),
    ("Change in winter temperature", warming_change_map_path),
    ("Extreme-cold-day count", extreme_cold_map_path),
    ("Extreme cold: early, recent, change", extreme_cold_triptych_path),
    ("Winter Severity Index", wsi_map_path),
    ("Winter Severity Index, snow-threshold sensitivity", wsi_sensitivity_path),
    ("Warm-anomaly frequency, 1 SD", anomaly_frequency_paths.get(1.0)),
    ("Warm-anomaly time series, 1 SD", anomaly_time_paths.get(1.0)),
    ("Warm-anomaly frequency, 2 SD", anomaly_frequency_paths.get(2.0)),
    ("Warm-anomaly time series, 2 SD", anomaly_time_paths.get(2.0)),
    ("Winter temperature deviations by period", decade_demeaned_path),
    ("Winter temperature deviations, area-weighted", decade_demeaned_area_path),
    ("Cross-season anomaly correlation", season_anomaly_path),
    ("Cross-season trend correlation", season_trend_path),
    ("PRISM–ERA5 comparison", era5_comparison_path),
    ("PRISM–ERA5 comparison, area-weighted", era5_comparison_area_path),
    ("State long-run warming (Appendix A, multi-page)", state_warming_path),
]
exhibit_index = pd.DataFrame(
    [{"order": n, "exhibit": label, "filename": path.name, "path": str(path)}
     for n, (label, path) in enumerate(
         [(label, path) for label, path in _ordered if path is not None], start=1)]
)
exhibit_index.to_csv(TIER2_TABLES_DIR / f"{config.name.lower()}_tier2_exhibit_index.csv", index=False)

# The note each exhibit used to print inside its own image. Eyal asked (Slack,
# 8/28) for those to move into the figure notes; 10_generate_weather_report.do
# reads this file and emits each one as the Notes paragraph under its figure, so
# the caption cannot drift from the figure that produced it.
missing_notes = [row.filename for row in exhibit_index.itertuples()
                 if row.filename not in EXHIBIT_NOTES]
assert not missing_notes, f"No note recorded for: {missing_notes}"
exhibit_notes = pd.DataFrame(
    [{"filename": name, "note": EXHIBIT_NOTES[name]} for name in exhibit_index["filename"]]
)
exhibit_notes.to_csv(TIER2_TABLES_DIR / f"{config.name.lower()}_tier2_exhibit_notes.csv", index=False)

manifest_rows = [{"artifact_type": "figure", "path": str(path)} for path in tier2_outputs]
manifest_rows += [{"artifact_type": "table", "path": str(path)}
                  for path in sorted(TIER2_TABLES_DIR.glob("*"))]
output_manifest = pd.DataFrame(manifest_rows).drop_duplicates().sort_values(["artifact_type", "path"])
output_manifest.to_csv(TIER2_TABLES_DIR / f"{config.name.lower()}_tier2_output_manifest.csv", index=False)

decisions_for_eyal = pd.DataFrame([
    {
        "decision": "Mean winter temperature: two constructions",
        "current_choice": ("This notebook takes a DAY-COUNT-WEIGHTED mean of the three monthly "
                           "means and keeps only winters complete on both month and day counts. "
                           "build_main_data_county_year.do line 512 takes a simple average of the "
                           "three monthly means."),
        "issue": ("The gap is hundredths of a degree, but it is enough to move a county-winter "
                  "across a sigma threshold, so the anomaly counts here and in the merged panel "
                  "will not match exactly. Harmonise the merge script to the day-weighted mean, "
                  "or accept the difference and document it? Table 1 has already been run off "
                  "the current merge script."),
        "status": "DECIDE",
    },
    {
        "decision": "Anomaly definition",
        "current_choice": ("Raw winter mean above the county's own full-sample mean by 1 or 2 SD "
                           "— identical to warm_winter_1sd / warm_winter_2sd in SECTION 7 of the "
                           "merge script."),
        "issue": ("Changed in this pass. The v1 exhibits used a DETRENDED residual above 1.5 SD "
                  "with a 30-winter filter, which described a different object from the "
                  "regressor. The detrended version is retained as a Tier 1 diagnostic. Flagging "
                  "in case the detrended construction should be the headline instead."),
        "status": "CHANGED — confirm",
    },
    {
        "decision": "Geographic weighting",
        "current_choice": ("Unweighted is primary; an area-weighted companion ships for each "
                           "exhibit that pools counties into a national number."),
        "issue": ("Population weighting was ruled out on 8/28. For the collisions stage the "
                  "relevant exposure weight may be vehicle-miles travelled or road miles rather "
                  "than land area."),
        "status": "CONFIRM",
    },
    {
        "decision": "Comparison periods",
        "current_choice": f"{EARLY_PERIOD[0]}–{EARLY_PERIOD[1]} versus {RECENT_PERIOD[0]}–{RECENT_PERIOD[1]}",
        "issue": "Symmetric ten-winter period means, not 1982-versus-2025 endpoints.",
        "status": "CONFIRM",
    },
    {
        "decision": "Region scheme for the pooled state figure",
        "current_choice": "EPA climate-impact regions, assigned whole states (both variants ship).",
        "issue": ("EPA Level I ecoregions cut across state lines and would need a county-level "
                  "spatial join. Pick the plain or the region-coloured version for the paper."),
        "status": "PICK ONE",
    },
    {
        "decision": "Winter Severity Index exhibit",
        "current_choice": "Read from the merged county-year panel; Kohn 1975 / WI DNR definition.",
        "issue": ("County-level averaging of ERA5-Land snow depth under-detects the 18-inch "
                  "threshold, so across most of the eastern deer range the index is effectively "
                  "its cold-day component. The 12-inch sensitivity panel shows this."),
        "status": "DOCUMENTED",
    },
    {
        "decision": "Extreme-cold change colour scale",
        "current_choice": "Reversed relative to the temperature-change map: red marks FEWER cold days.",
        "issue": "Deliberate — for a count of cold days, a decrease is the warming signal.",
        "status": "DOCUMENTED",
    },
])
decisions_for_eyal.to_csv(TIER2_TABLES_DIR / f"{config.name.lower()}_tier2_decisions_for_eyal.csv", index=False)

display(exhibit_index)
display(decisions_for_eyal)
print(f"Tier 2 complete: {len(exhibit_index)} exhibits in {TIER2_FIGURES_DIR}")


print("Tier 2 complete.")
