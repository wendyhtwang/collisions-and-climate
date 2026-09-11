"""Tier 1 -- internal QA and exploratory exhibits.

GENERATED FILE -- do not edit by hand.
Produced from codePYTHON/09_descriptive_weather_full.ipynb by make_scripts.py.
Edit the notebook, then re-run make_scripts.py.
"""


import weather_descriptives_utils as wx
from weather_descriptives_utils import *  # noqa: F401,F403
from weather_descriptives_utils import (
    _linear_trend, _numeric_weather_columns,
)

# Reading the CSVs and building the county-winter panel is an explicit
# call, not an import side effect. The panel's objects are bound into
# this script's namespace so the exhibit code below reads unchanged.
globals().update(wx.build_panel())


# Calendar-year coverage is asserted, not merely displayed, so a truncated or
# over-long input file fails here rather than silently reshaping every exhibit.
observed_years = {int(year) for year in df["year"].unique()}
missing_years = sorted(EXPECTED_YEARS - observed_years)
unexpected_years = sorted(observed_years - EXPECTED_YEARS)
assert not missing_years and not unexpected_years, (
    "Calendar-year coverage does not match EXPECTED_YEARS. "
    f"Missing: {missing_years}. Unexpected: {unexpected_years}."
)

coverage = {
    **load_diagnostics,
    **winter_diagnostics,
    "expected_calendar_years": f"{min(EXPECTED_YEARS)}–{max(EXPECTED_YEARS)}",
    "observed_calendar_years": f"{df['year'].min()}–{df['year'].max()}",
    "observed_complete_winters": (
        f"{county_winter['winter_year'].min()}–{county_winter['winter_year'].max()}"
    ),
}
coverage_table = pd.DataFrame(
    [{"metric": key, "value": value} for key, value in coverage.items()]
)
coverage_table.to_csv(TABLES_DIR / f"{config.name.lower()}_tier1_coverage_integrity.csv", index=False)
save_table_pdf(
    coverage_table,
    TABLES_DIR / f"{config.name.lower()}_tier1_coverage_integrity.pdf",
    f"{config.name}: Tier 1 data coverage and integrity",
)
display(coverage_table)


SUMMARY_QUANTILES = [0.01, 0.05, 0.50, 0.95, 0.99]

# Every numeric weather column must carry a unit before these tables are read
# by anyone outside the project.
missing_units = [v for v in _numeric_weather_columns(df) if v not in VARIABLE_UNITS]
assert not missing_units, f"Add entries to VARIABLE_UNITS for: {missing_units}"

def summarize_long(frame, group_cols=None):
    group_cols = list(group_cols or [])
    variables = _numeric_weather_columns(frame)
    records = []
    groups = [((), frame)] if not group_cols else frame.groupby(group_cols, dropna=False)
    for keys, group in groups:
        keys = keys if isinstance(keys, tuple) else (keys,)
        group_values = dict(zip(group_cols, keys))
        for variable in variables:
            values = group[variable].dropna()
            record = {
                **group_values,
                "variable": variable,
                "unit": VARIABLE_UNITS.get(variable, ""),
                "n": values.count(),
                "mean": values.mean(),
                "sd": values.std(),
                "min": values.min(),
                "p01": values.quantile(0.01),
                "p05": values.quantile(0.05),
                "median": values.quantile(0.50),
                "p95": values.quantile(0.95),
                "p99": values.quantile(0.99),
                "max": values.max(),
            }
            records.append(record)
    return pd.DataFrame(records)

summary_pooled = summarize_long(df)
summary_pooled.to_csv(TABLES_DIR / f"{config.name.lower()}_summary_pooled.csv", index=False)
save_table_pdf(
    summary_pooled,
    TABLES_DIR / f"{config.name.lower()}_summary_pooled.pdf",
    f"{config.name}: pooled county-month summary statistics",
    rows_per_page=24,
)
display(summary_pooled)


summary_by_month = summarize_long(df, ["month"])
summary_by_month.to_csv(
    TABLES_DIR / f"{config.name.lower()}_summary_by_calendar_month.csv", index=False
)
save_table_pdf(
    summary_by_month,
    TABLES_DIR / f"{config.name.lower()}_summary_by_calendar_month.pdf",
    f"{config.name}: summary statistics by calendar month",
    rows_per_page=30,
)
display(summary_by_month.head(24))

summary_by_county = summarize_long(df, ["geoid"])
county_names = df[["geoid", "state_fips", "county_name"]].drop_duplicates("geoid")
summary_by_county = summary_by_county.merge(county_names, on="geoid", how="left", validate="many_to_one")
summary_by_county.to_csv(
    TABLES_DIR / f"{config.name.lower()}_summary_by_county.csv", index=False
)

# Flag county-variable means that are unusually far from the national
# distribution of county means. These are review flags, not automatic errors.
county_mean_distribution = (
    summary_by_county.groupby("variable")["mean"]
    .agg(mean_across_counties="mean", std_across_counties="std")
)
flagged_counties = summary_by_county.merge(
    county_mean_distribution, left_on="variable", right_index=True,
)
flagged_counties["abs_z"] = (
    (flagged_counties["mean"] - flagged_counties["mean_across_counties"])
    / flagged_counties["std_across_counties"]
).abs()
flagged_counties = flagged_counties[
    flagged_counties["abs_z"].ge(OUTLIER_Z_THRESHOLD)
].sort_values(["variable", "abs_z"], ascending=[True, False])
flagged_counties.to_csv(
    TABLES_DIR / f"{config.name.lower()}_summary_by_county_review_flags.csv", index=False
)
flag_columns = ["geoid", "state_fips", "county_name", "variable", "unit", "mean", "sd", "min", "max", "abs_z"]
save_table_pdf(
    flagged_counties[flag_columns],
    TABLES_DIR / f"{config.name.lower()}_summary_by_county_review_flags.pdf",
    f"{config.name}: county-variable review flags (|z| ≥ {OUTLIER_Z_THRESHOLD:g})",
    rows_per_page=28,
)
display(flagged_counties[flag_columns].head(30))

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

def plot_national_winter_trend(frame, variable):
    annual = frame.groupby("winter_year", as_index=False)[variable].mean()
    trend = _linear_trend(annual["winter_year"], annual[variable])
    fig, ax = plt.subplots(figsize=(8.0, 4.6))
    ax.plot(annual["winter_year"], annual[variable], color="#4C78A8", lw=1.2, marker="o", ms=3,
            label="Annual mean across counties")
    if trend is not None:
        ax.plot(trend.x_line, trend.y_line, color="black", lw=2, ls="--",
                label=f"Linear trend {trend.slope:+.3f} per year "
                      f"(SE {trend.stderr:.3f}; R² {trend.r2:.2f}; n={trend.n})")
    ax.set(title=f"{config.name}: {variable_label(variable)}",
           xlabel="Winter year (December–February)", ylabel=variable_label(variable))
    ax.grid(alpha=0.2)
    ax.legend(frameon=False, fontsize=8)
    ax.text(0, -0.18, source_note(
                "Estimand: the average county. Counties are weighted equally, so this is not "
                "an area-, population- or road-weighted national average."),
            transform=ax.transAxes, fontsize=7.5, va="top", color="#555555")
    fig.tight_layout()
    return save_figure_pdf(fig, f"{config.name.lower()}_national_trend_{variable}.pdf")

national_trend_paths = [
    plot_national_winter_trend(county_winter, variable)
    for variable in PRIMARY_TREND_VARS if variable in county_winter
]


def save_state_trend_multipage(frame, variable, states_per_page=STATES_PER_PAGE,
                               n_cols=STATE_GRID_COLS):
    states = sorted(frame["state_fips"].dropna().unique())
    path = FIGURES_DIR / f"{config.name.lower()}_state_trends_{variable}.pdf"
    with PdfPages(path) as pdf:
        for start in range(0, len(states), states_per_page):
            page_states = states[start:start + states_per_page]
            n_rows, figsize = state_page_grid(len(page_states))
            fig, axes = plt.subplots(n_rows, n_cols, figsize=figsize, squeeze=False)
            for ax, state in zip(axes.flat, page_states):
                annual = (
                    frame[frame["state_fips"].eq(state)]
                    .groupby("winter_year", as_index=False)[variable].mean()
                )
                trend = _linear_trend(annual["winter_year"], annual[variable])
                ax.plot(annual["winter_year"], annual[variable], color="#4C78A8", lw=0.9)
                if trend is not None:
                    ax.plot(trend.x_line, trend.y_line, color="black", lw=1.4, ls="--")
                ax.set_title(state_label(state), fontsize=8)
                ax.tick_params(labelsize=6)
                ax.grid(alpha=0.15)
            for ax in list(axes.flat)[len(page_states):]:
                ax.axis("off")
            fig.suptitle(f"{config.name}: {variable_label(variable)} by state", fontsize=12)
            fig.supxlabel("Winter year", fontsize=9)
            fig.supylabel(variable_label(variable), fontsize=9)
            fig.tight_layout(rect=[0, 0, 1, 0.96])
            pdf.savefig(fig, bbox_inches="tight")
            display_figure_inline(fig)
            plt.close(fig)
    print(f"Saved {path}")
    return path

state_trend_paths = [
    save_state_trend_multipage(county_winter, variable)
    for variable in PRIMARY_TREND_VARS if variable in county_winter
]


def save_spaghetti_multipage(frame, variable, states_per_page=STATES_PER_PAGE,
                             n_cols=STATE_GRID_COLS):
    states = sorted(frame["state_fips"].dropna().unique())
    path = FIGURES_DIR / f"{config.name.lower()}_county_spaghetti_{variable}.pdf"
    with PdfPages(path) as pdf:
        for start in range(0, len(states), states_per_page):
            page_states = states[start:start + states_per_page]
            n_rows, figsize = state_page_grid(len(page_states), row_height=2.15)
            fig, axes = plt.subplots(n_rows, n_cols, figsize=figsize, squeeze=False)
            for ax, state in zip(axes.flat, page_states):
                state_frame = frame[frame["state_fips"].eq(state)]
                for _, county in state_frame.groupby("geoid"):
                    county = county.sort_values("winter_year")
                    ax.plot(county["winter_year"], county[variable],
                            color="#4C78A8", alpha=0.18, lw=0.45)
                annual_mean = state_frame.groupby("winter_year", as_index=False)[variable].mean()
                ax.plot(annual_mean["winter_year"], annual_mean[variable],
                        color="black", lw=1.6, label="Annual state mean")
                trend = _linear_trend(annual_mean["winter_year"], annual_mean[variable])
                if trend is not None:
                    ax.plot(trend.x_line, trend.y_line, color="#E45756", lw=1.2, ls="--",
                            label="State linear trend")
                ax.set_title(f"{state_label(state)} (n={state_frame['geoid'].nunique()})",
                             fontsize=8)
                ax.tick_params(labelsize=6)
                ax.grid(alpha=0.12)
            for ax in list(axes.flat)[len(page_states):]:
                ax.axis("off")
            fig.suptitle(
                f"{config.name}: county trajectories — {variable_label(variable)}",
                fontsize=12, y=0.995,
            )
            # Anchor the legend below the suptitle; at the default location the
            # two overprint each other and neither is legible.
            handles, labels = axes.flat[0].get_legend_handles_labels()
            if handles:
                fig.legend(handles, labels, loc="upper center",
                           bbox_to_anchor=(0.5, 0.962), ncol=2, frameon=False, fontsize=8)
            fig.supxlabel("Winter year", fontsize=9)
            fig.supylabel(variable_label(variable), fontsize=9)
            fig.tight_layout(rect=[0, 0, 1, 0.93])
            pdf.savefig(fig, bbox_inches="tight")
            display_figure_inline(fig)
            plt.close(fig)
    print(f"Saved {path}")
    return path

spaghetti_paths = [
    save_spaghetti_multipage(county_winter, variable)
    for variable in SPAGHETTI_VARS if variable in county_winter
]


def decade_label(year):
    if 2020 <= int(year) <= 2025:
        return "2020–2025"
    start = (int(year) // 10) * 10
    return f"{start}s"

county_winter["decade"] = county_winter["winter_year"].map(decade_label)

def save_decade_distributions(frame, variable="mean_temp_c",
                              states_per_page=STATES_PER_PAGE, n_cols=STATE_GRID_COLS):
    states = sorted(frame["state_fips"].dropna().unique())
    decades = sorted(frame["decade"].unique())
    path = FIGURES_DIR / f"{config.name.lower()}_state_decade_distributions_{variable}.pdf"
    with PdfPages(path) as pdf:
        for start in range(0, len(states), states_per_page):
            page_states = states[start:start + states_per_page]
            n_rows, figsize = state_page_grid(len(page_states), row_height=2.15)
            fig, axes = plt.subplots(n_rows, n_cols, figsize=figsize, squeeze=False)
            for ax, state in zip(axes.flat, page_states):
                sub = frame[frame["state_fips"].eq(state)]
                values = [sub.loc[sub["decade"].eq(decade), variable].dropna() for decade in decades]
                ax.boxplot(values, tick_labels=decades, showfliers=False, patch_artist=True,
                           boxprops={"facecolor":"#9ECAE1", "edgecolor":"#4C78A8"},
                           medianprops={"color":"black"})
                ax.set_title(state_label(state), fontsize=8)
                ax.tick_params(axis="x", rotation=45, labelsize=6)
                ax.tick_params(axis="y", labelsize=6)
                ax.grid(axis="y", alpha=0.15)
            for ax in list(axes.flat)[len(page_states):]:
                ax.axis("off")
            fig.suptitle(f"{config.name}: decade distributions of {variable_label(variable)}",
                         fontsize=12)
            fig.supylabel(variable_label(variable), fontsize=9)
            fig.tight_layout(rect=[0, 0, 1, 0.96])
            pdf.savefig(fig, bbox_inches="tight")
            display_figure_inline(fig)
            plt.close(fig)
    print(f"Saved {path}")
    return path

decade_distribution_path = save_decade_distributions(county_winter)


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

variability_by_state = (
    county_variability.groupby("state_fips")["winter_temp_sd"]
    .agg(n_counties="count", mean="mean", sd="std", min="min", median="median", max="max")
    .reset_index()
)
variability_by_state["state"] = variability_by_state["state_fips"].map(state_label)
variability_by_state = variability_by_state[
    ["state_fips", "state", "n_counties", "mean", "sd", "min", "median", "max"]
]
variability_by_state.to_csv(
    TABLES_DIR / f"{config.name.lower()}_interannual_variability_by_state.csv", index=False
)
save_table_pdf(
    variability_by_state,
    TABLES_DIR / f"{config.name.lower()}_interannual_variability_by_state.pdf",
    f"{config.name}: interannual SD of mean winter temperature by state",
    rows_per_page=28,
)
display(variability_by_state)


variability_map = merge_county_geometry(
    county_variability, "Interannual variability", columns=["geoid", "winter_temp_sd"]
)
fig, ax = plt.subplots(figsize=(8.0, 5.0))
variability_map.plot(
    column="winter_temp_sd", cmap="viridis", linewidth=0,
    legend=True, legend_kwds={"label": "SD of mean winter temperature (°C)"}, ax=ax,
)
draw_state_borders(ax)
ax.set_title(f"{config.name}: interannual variability in mean winter temperature")
ax.axis("off")
fig.tight_layout()
interannual_variability_map_path = save_figure_pdf(
    fig, f"{config.name.lower()}_interannual_variability_choropleth.pdf"
)


qa_findings = [
    {
        "check": "Duplicate county-year-month keys",
        "result": load_diagnostics["duplicate_monthly_keys"] + load_diagnostics["duplicate_derived_keys"],
        "status": "PASS" if not (load_diagnostics["duplicate_monthly_keys"] + load_diagnostics["duplicate_derived_keys"]) else "REVIEW",
    },
    {
        "check": "Rows appearing in only one merge source",
        "result": load_diagnostics["monthly_only_rows"] + load_diagnostics["derived_only_rows"],
        "status": "PASS" if not (load_diagnostics["monthly_only_rows"] + load_diagnostics["derived_only_rows"]) else "REVIEW",
    },
    {
        "check": "Incomplete county-months",
        "result": load_diagnostics["incomplete_months"],
        "status": "PASS" if not load_diagnostics["incomplete_months"] else "REVIEW",
    },
    {
        "check": "Excluded incomplete county-winters",
        "result": winter_diagnostics["excluded_incomplete_county_winters"],
        "status": "INFO",
    },
    {
        "check": f"County-variable mean flags (|z| ≥ {OUTLIER_Z_THRESHOLD:g})",
        "result": len(flagged_counties),
        "status": "REVIEW" if len(flagged_counties) else "PASS",
    },
]
qa_findings = pd.DataFrame(qa_findings)
qa_findings.to_csv(TABLES_DIR / f"{config.name.lower()}_tier1_qa_findings.csv", index=False)
save_table_pdf(
    qa_findings,
    TABLES_DIR / f"{config.name.lower()}_tier1_qa_findings.pdf",
    f"{config.name}: Tier 1 QA findings",
)
display(qa_findings)

print("Tier 1 outputs complete.")
print(f"Tables: {TABLES_DIR}")
print(f"Figures: {FIGURES_DIR}")

print("Tier 1 complete.")
