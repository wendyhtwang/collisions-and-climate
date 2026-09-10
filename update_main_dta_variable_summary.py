#!/usr/bin/env python3
"""
update_main_dta_variable_summary.py

Regenerate the "Variables in the Main Merged Dataset" summary PDF (and a
plain-text/Markdown copy alongside it) straight from
main_data_county_year.dta's own header metadata -- the same file
build_main_data_county_year.do produces. Only the .dta header is read (via
the same fast, no-full-load approach as describe_dta.py), so this is cheap
to rerun after every build.

describe_dta.py already gives a flat, one-row-per-variable dump of a .dta's
metadata. This script does the same read, then organizes the ~250+ columns
of main_data_county_year.dta into the same narrative sections used in the
hand-built reference doc ("Variables in the main merged dataset.pdf/.md"):
ID/panel variables, PRISM weather, ERA5 snow, Census population, vehicle
collisions, wildlife harvest, winter severity, and merge-status flags --
collapsing the twelve-months-wide weather variables into single pattern
rows instead of listing all 132+24 of them individually.

The section/grouping rules below encode the project's variable-naming
conventions as of the 09/09/2026 build_main_data_county_year.do revision.
They are NOT derived from the data itself -- if a future build renames or
adds variables that don't match any rule, this script does not guess. It
lists them, unclassified, in a section at the end of the report titled
"Unclassified variables (script needs updating)" and prints a warning to
stderr, and (with --strict) exits non-zero. Either way nothing is ever
silently dropped from the count.

Usage:
    python3 update_main_dta_variable_summary.py
    python3 update_main_dta_variable_summary.py --dta /path/to/main_data_county_year.dta
    python3 update_main_dta_variable_summary.py --out-dir report --basename "Variables in the main merged dataset"
    python3 update_main_dta_variable_summary.py --strict     # exit 1 if anything is unclassified
    python3 update_main_dta_variable_summary.py --no-md      # write only the PDF

Requires: pandas, matplotlib. Optional: pyreadstat, used only as a fallback
for .dta files pandas itself can't parse (pip3 install pyreadstat) -- see
describe_dta.py, which this script reuses for that fallback path when it's
importable from the same directory.
"""

from __future__ import annotations

import argparse
import re
import sys
import tempfile
import textwrap
from dataclasses import dataclass, field
from pathlib import Path

try:
    import pandas as pd
except ImportError:
    sys.exit("This script requires pandas. Install it with: pip3 install pandas")

try:
    import matplotlib

    matplotlib.use("Agg")  # headless -- no display on the Kodama server
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_pdf import PdfPages
except ImportError:
    sys.exit("This script requires matplotlib. Install it with: pip3 install matplotlib")


# --------------------------------------------------------------------------
# Defaults -- override on the command line rather than editing these for a
# one-off run; edit them only if the project's own conventions change.
# --------------------------------------------------------------------------

DEFAULT_DTA = Path(
    "/mnt/data_d/Dropbox/Research/AnimalCollisionsWeather/dataSTATA/main_data_county_year.dta"
)
DEFAULT_OUT_DIR = Path(__file__).resolve().parent
DEFAULT_BASENAME = "Variables in the main merged dataset"


# --------------------------------------------------------------------------
# Step 1: read the .dta header (name, label, storage type -- no data rows)
# --------------------------------------------------------------------------

# Stata's on-disk type codes -> human-readable storage-type names.
_NAMED_TYPES = {"b": "byte", "h": "int", "l": "long", "f": "float", "d": "double", "Q": "strL"}
_READSTAT_TYPE_NAMES = {
    "int8": "byte",
    "int16": "int",
    "int32": "long",
    "int64": "long",
    "float": "float",
    "double": "double",
}


def _stata_type_name(code):
    if isinstance(code, str):
        return _NAMED_TYPES.get(code, code)
    if code == 32768:
        return "strL"
    return f"str{code}"


def _read_with_pandas(path: Path) -> dict:
    with pd.io.stata.StataReader(str(path)) as reader:
        var_labels = reader.variable_labels()
        varnames = list(var_labels.keys())
        typlist = list(reader._typlist)
        n_obs = reader._nobs

    if len(typlist) != len(varnames):
        raise ValueError(
            f"Parsed {len(varnames)} variable names but {len(typlist)} types -- "
            "the file may be in a format this script can't parse."
        )

    variables = [
        {"name": name, "label": var_labels.get(name, ""), "type": _stata_type_name(t)}
        for name, t in zip(varnames, typlist)
    ]
    return {"variables": variables, "n_vars": len(varnames), "n_obs": n_obs}


def _read_with_pyreadstat(path: Path) -> dict:
    import pyreadstat

    _, meta = pyreadstat.read_dta(str(path), metadataonly=True)
    variables = []
    for name in meta.column_names:
        label = meta.column_names_to_labels.get(name) or ""
        generic_type = meta.readstat_variable_types.get(name, "")
        if generic_type == "string":
            width = (meta.variable_storage_width or {}).get(name)
            type_name = f"str{width}" if width else "string"
        else:
            type_name = _READSTAT_TYPE_NAMES.get(generic_type, generic_type or "unknown")
        variables.append({"name": name, "label": label, "type": type_name})
    return {"variables": variables, "n_vars": meta.number_columns, "n_obs": meta.number_rows}


def read_dta_metadata(path: Path) -> tuple[dict, str | None]:
    """Read `path`'s header. Tries pandas first, falls back to describe_dta.py's
    pyreadstat path (reused if importable) for files pandas can't parse."""
    try:
        return _read_with_pandas(path), None
    except Exception as pandas_exc:
        # Reuse describe_dta.py's fallback logic if it's sitting next to this
        # script, rather than re-deriving it -- same repo, same rule.
        try:
            sys.path.insert(0, str(Path(__file__).resolve().parent))
            from describe_dta import read_dta_metadata as _describe_dta_read

            meta, note = _describe_dta_read(path)
            return meta, note or "pandas couldn't parse this file; used describe_dta.py's pyreadstat fallback."
        except Exception:
            pass

        try:
            import pyreadstat  # noqa: F401
        except ImportError:
            raise RuntimeError(
                f"pandas could not parse this file ({pandas_exc}), and pyreadstat "
                "isn't installed for a fallback. Try: pip3 install pyreadstat"
            ) from pandas_exc

        try:
            meta = _read_with_pyreadstat(path)
        except Exception as pyreadstat_exc:
            raise RuntimeError(
                f"Could not parse this file with pandas ({pandas_exc}) or "
                f"pyreadstat ({pyreadstat_exc}) either."
            ) from pyreadstat_exc

        return meta, "pandas couldn't parse this file; used pyreadstat as a fallback."


# --------------------------------------------------------------------------
# Step 2: group the flat variable list into the report's sections
# --------------------------------------------------------------------------

_NUMERIC_TYPES = {"byte", "int", "long", "float", "double"}


def summarize_types(types: list[str]) -> str:
    """Collapse a list of storage types to one display string: the shared
    type if they all agree, "num" if they're all numeric but differ (this
    mirrors the reference doc's own shorthand for mixed-numeric groups), or
    a sorted, comma-joined list as a last resort."""
    uniq = sorted(set(types))
    if len(uniq) == 1:
        return uniq[0]
    if all(t in _NUMERIC_TYPES for t in uniq):
        return "num"
    return ", ".join(uniq)


@dataclass
class Row:
    cells: list[str]


@dataclass
class Section:
    title: str
    columns: list[str]
    rows: list[Row] = field(default_factory=list)
    footnote: str | None = None


MONTH_RE = re.compile(r"^(?P<base>.+)_m(?P<month>[1-9]|1[0-2])$")

# Which collapsed monthly base variables belong to which weather source.
# A monthly-repeated variable whose base isn't in either list is left
# unclassified rather than guessed at.
PRISM_MONTHLY_BASES = {
    "n_days",
    "days_extremely_cold",
    "days_below_freezing_32f",
    "freeze_thaw_days",
    "days_precip_above_10mm",
    "heating_degree_days",
    "cooling_degree_days",
    "mean_temp_c",
    "tmean_variance_c2",
    "tmin_variance_c2",
    "tmax_variance_c2",
}
ERA5_MONTHLY_BASES = {
    "total_snowfall_mm",
    "mean_snow_depth",
    # Added 09/08/2026 per build_main_data_county_year.do; monthly only if
    # 06_build_derived_weather_vars.py has been rerun to produce them.
    "days_snow_depth_18in",
    "days_snow_depth_12in",
    "days_snow_depth_8in",
}

ID_PANEL_VARS = [
    "geoid",
    "fips_num",
    "state_fips",
    "county_fips",
    "county_name",
    "year",
    "n_incomplete_months",
]

POPULATION_PLAIN_VARS = ["population", "population_source", "age_source", "population_flag", "age_flag"]

WILDLIFE_VARS = [
    "state",
    "harvest_total",
    "source_harvest",
    "flag_total_constructed",
    "flag_hand_transcribed",
    "harvest_total_cwd_imputed",
    "in_window",
    "main_sample",
    "main_sample_agency",
]

WINTER_SEVERITY_PREFIXES = ("mean_winter_temp", "warm_winter_", "wsi_", "winter_severity_index")

COLLISIONS_PLAIN_VARS = ["state_letter_code", "state_name", "fips", "flag_data_issue"]

# Ordered vehicle-collision groups: first pattern to match a variable wins.
COLLISIONS_GROUPS = [
    (re.compile(r"^total_(total|fatal|fatalities|injury|injuries|pdo)$"), "Crash counts, all vehicle types"),
    (
        re.compile(r"^animal_(total|fatal|fatalities|injury|injuries|pdo|total_injury)$"),
        "Crash counts, animal-involved",
    ),
    (re.compile(r"^deer_(total|fatal|fatalities|injury|injuries|pdo)$"), "Crash counts, deer-involved"),
    (
        re.compile(r"^wild_animal_(fatal|injury|pdo|fatalities|injuries|total)$"),
        "Crash counts, wild-animal-involved",
    ),
    (re.compile(r"^imputation_flag_"), "Imputation flags"),
    (re.compile(r"^any_animal_"), "=1 if any animal-crash outcome present"),
    (
        re.compile(r"(_to_crashes|_to_pdo|_to_fatal)$|^totalfatal_to_deerfatal$"),
        "Ratio/rate variables",
    ),
]


def build_sections(variables: list[dict]) -> tuple[list[Section], list[dict]]:
    by_name = {v["name"]: v for v in variables}
    remaining = dict(by_name)  # names not yet claimed by any section
    sections: list[Section] = []

    def claim(names):
        for n in names:
            remaining.pop(n, None)

    # -- ID / panel variables --
    sec = Section("ID / panel variables", ["Variable", "Type", "Label"])
    for name in ID_PANEL_VARS:
        if name in by_name:
            v = by_name[name]
            sec.rows.append(Row([v["name"], v["type"], v["label"]]))
            claim([name])
    sections.append(sec)

    # -- Monthly-repeated groups (PRISM weather, ERA5 snow) --
    monthly_groups: dict[str, dict[int, dict]] = {}
    for name, v in by_name.items():
        m = MONTH_RE.match(name)
        if m:
            monthly_groups.setdefault(m.group("base"), {})[int(m.group("month"))] = v

    def monthly_section(title: str, bases: set[str]) -> Section:
        sec = Section(title, ["Variable pattern", "Type", "Base variable"])
        matched_bases = sorted(b for b in monthly_groups if b in bases)
        n_cols = 0
        for base in matched_bases:
            months = monthly_groups[base]
            n_present = len(months)
            any_month = next(iter(months.values()))
            pattern = f"{base}_m#" if n_present == 12 else f"{base}_m# ({n_present}/12 months present)"
            sec.rows.append(Row([pattern, any_month["type"], base]))
            claim(f"{base}_m{m}" for m in months)
            n_cols += n_present
        if matched_bases:
            sec.footnote = f"{len(matched_bases)} base vars x up to 12 months = {n_cols} columns"
        return sec

    sections.append(monthly_section("PRISM weather (repeats 12x: suffix _m1 ... _m12)", PRISM_MONTHLY_BASES))
    sections.append(monthly_section("ERA5 snow (repeats 12x: suffix _m1 ... _m12)", ERA5_MONTHLY_BASES))

    # Any monthly-repeated variable whose base wasn't recognized: leave for
    # the unclassified section (below) rather than guessing which source it
    # belongs to.

    # -- Population (Census) --
    sec = Section("Population (Census)", ["Variable", "Type", "Label"])
    pop_share_names = sorted(
        (n for n in remaining if re.match(r"^pop_share_(\d+_\d+|85plus)$", n)),
        key=lambda n: (0, int(n.split("_")[2])) if n.split("_")[2].isdigit() else (1, n),
    )
    if pop_share_names:
        types = summarize_types([by_name[n]["type"] for n in pop_share_names])
        sec.rows.append(
            Row(
                [
                    f"{pop_share_names[0]} ... {pop_share_names[-1]}",
                    types,
                    f"Share of population in each 5-yr age band ({len(pop_share_names)} vars)",
                ]
            )
        )
        claim(pop_share_names)
    for name in POPULATION_PLAIN_VARS:
        if name in remaining:
            v = remaining[name]
            sec.rows.append(Row([v["name"], v["type"], v["label"]]))
            claim([name])
    sections.append(sec)

    # -- Vehicle collisions --
    sec = Section(
        "Vehicle collisions (from collisions_CONUS_county_year_1985_2020.dta)",
        ["Variable(s)", "Type", "Notes"],
    )
    for name in COLLISIONS_PLAIN_VARS:
        if name in remaining:
            v = remaining[name]
            sec.rows.append(Row([v["name"], v["type"], v["label"]]))
            claim([name])
    for pattern, notes in COLLISIONS_GROUPS:
        matched = sorted(n for n in remaining if pattern.search(n))
        if not matched:
            continue
        types = summarize_types([remaining[n]["type"] for n in matched])
        var_list = ", ".join(matched)
        sec.rows.append(Row([var_list, types, f"{notes} ({len(matched)} vars)"]))
        claim(matched)
    sections.append(sec)

    # -- Wildlife harvest --
    sec = Section("Wildlife harvest (Nicole's panel)", ["Variable", "Type", "Label"])
    for name in WILDLIFE_VARS:
        if name in remaining:
            v = remaining[name]
            sec.rows.append(Row([v["name"], v["type"], v["label"]]))
            claim([name])
    sections.append(sec)

    # -- Winter severity variables --
    sec = Section("Winter severity variables", ["Variable", "Type", "Label"])
    winter_names = sorted(n for n in remaining if n.startswith(WINTER_SEVERITY_PREFIXES))
    for name in winter_names:
        v = remaining[name]
        sec.rows.append(Row([v["name"], v["type"], v["label"]]))
    claim(winter_names)
    sections.append(sec)

    # -- Merge-status flags --
    sec = Section("Merge-status flags", ["Variable", "Type", "Label"])
    merge_names = sorted(n for n in remaining if n.startswith("merge_"))
    for name in merge_names:
        v = remaining[name]
        sec.rows.append(Row([v["name"], v["type"], v["label"]]))
    claim(merge_names)
    sections.append(sec)

    # Drop empty sections (e.g. ERA5 snow if that CSV isn't merged in a
    # given run) so the report doesn't show hollow headers.
    sections = [s for s in sections if s.rows]

    unclassified = [remaining[n] for n in sorted(remaining)]
    return sections, unclassified


# --------------------------------------------------------------------------
# Step 3: render sections to a paginated PDF (and optionally a plain-text /
# Markdown twin, easier to diff in version control than a PDF).
# --------------------------------------------------------------------------

PAGE_W, PAGE_H = 8.5, 11.0
MARGIN = 0.75
LINE_HEIGHT = 0.145  # inches per monospace text line at the font size below
FONT_SIZE = 8.3
USABLE_HEIGHT = PAGE_H - 2 * MARGIN
LINES_PER_PAGE = int(USABLE_HEIGHT / LINE_HEIGHT)


def wrap_table(headers: list[str], rows: list[Row], max_line_width: int = 96) -> list[str]:
    """Format one section's table as monospace text lines, wrapping an
    overlong first cell (the long collision variable-name lists) onto
    continuation lines with blank type/notes cells.

    The first column's wrap width is derived from `max_line_width` minus
    whatever the other columns actually need, rather than a fixed constant --
    a table with a wide "Notes" column (vehicle collisions) needs a
    narrower first column than one with a short "Label" column (ID/panel),
    or the line runs past the page's right margin."""
    other_col_width = sum(
        max(len(headers[i]), max((len(r.cells[i]) for r in rows), default=0))
        for i in range(1, len(headers))
    )
    n_seps = 2 * (len(headers) - 1)  # "  " between each pair of columns
    first_col_wrap = max(24, max_line_width - other_col_width - n_seps)

    raw_rows: list[list[str]] = []
    for r in rows:
        first, rest = r.cells[0], r.cells[1:]
        wrapped = textwrap.wrap(first, first_col_wrap) or [""]
        raw_rows.append([wrapped[0]] + rest)
        for cont in wrapped[1:]:
            raw_rows.append([cont] + ["" for _ in rest])

    n_cols = len(headers)
    widths = [
        max(len(headers[i]), max((len(r[i]) for r in raw_rows), default=0)) for i in range(n_cols)
    ]

    def fmt(row):
        return "  ".join(str(c).ljust(widths[i]) for i, c in enumerate(row))

    lines = [fmt(headers), "  ".join("-" * w for w in widths)]
    lines.extend(fmt(r) for r in raw_rows)
    return lines


def render_pdf(
    out_path: Path,
    dta_name: str,
    n_vars: int,
    n_obs: int,
    sections: list[Section],
    unclassified: list[dict],
    parser_note: str | None,
) -> None:
    blocks: list[tuple[str | None, list[str], str | None]] = []
    for sec in sections:
        lines = wrap_table(sec.columns, sec.rows)
        blocks.append((sec.title, lines, sec.footnote))
    if unclassified:
        rows = [Row([v["name"], v["type"], v["label"]]) for v in unclassified]
        lines = wrap_table(["Variable", "Type", "Label"], rows)
        blocks.append(("Unclassified variables (script needs updating)", lines, None))

    with PdfPages(out_path) as pdf:
        fig, ax = _new_page()
        y = PAGE_H - MARGIN
        y = _draw_line(ax, y, f"Variables in the Main Merged Dataset", size=14, weight="bold")
        y -= LINE_HEIGHT * 0.4
        y = _draw_line(ax, y, dta_name, size=9.5, family="monospace", weight="bold")
        y = _draw_line(ax, y, f"{n_vars} vars, {n_obs:,} obs", size=9, style="italic")
        if parser_note:
            y = _draw_line(ax, y, f"Note: {parser_note}", size=7.5, style="italic")
        y -= LINE_HEIGHT

        for title, lines, footnote in blocks:
            block_len = 2 + len(lines) + (1 if footnote else 0)  # heading + blank + table (+ footnote)
            if y - block_len * LINE_HEIGHT < MARGIN:
                pdf.savefig(fig)
                plt.close(fig)
                fig, ax = _new_page()
                y = PAGE_H - MARGIN
            y = _draw_line(ax, y, title, size=10, weight="bold")
            for line in lines:
                if y < MARGIN:
                    pdf.savefig(fig)
                    plt.close(fig)
                    fig, ax = _new_page()
                    y = PAGE_H - MARGIN
                    y = _draw_line(ax, y, f"{title} (cont.)", size=10, weight="bold", style="italic")
                y = _draw_line(ax, y, line, size=FONT_SIZE, family="monospace")
            if footnote:
                y = _draw_line(ax, y, footnote, size=7.5, style="italic")
            y -= LINE_HEIGHT

        pdf.savefig(fig)
        plt.close(fig)


def _new_page():
    fig = plt.figure(figsize=(PAGE_W, PAGE_H))
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, PAGE_W)
    ax.set_ylim(0, PAGE_H)
    ax.axis("off")
    return fig, ax


def _draw_line(ax, y, text, size=FONT_SIZE, family="sans-serif", weight="normal", style="normal") -> float:
    ax.text(
        MARGIN,
        y,
        text,
        fontsize=size,
        family=family,
        fontweight=weight,
        fontstyle=style,
        va="top",
        ha="left",
    )
    return y - LINE_HEIGHT * max(1.0, size / FONT_SIZE)


def render_markdown(
    out_path: Path,
    dta_name: str,
    n_vars: int,
    n_obs: int,
    sections: list[Section],
    unclassified: list[dict],
    parser_note: str | None,
) -> None:
    lines = [
        "<!-- Auto-generated by update_main_dta_variable_summary.py -- do not edit by hand, rerun the script instead. -->",
        "",
        f"# Variables in the Main Merged Dataset",
        "",
        f"**{dta_name}**  ({n_vars} vars, {n_obs:,} obs)",
        "",
    ]
    if parser_note:
        lines += [f"*Note: {parser_note}*", ""]

    for sec in sections:
        lines.append(f"## {sec.title}")
        lines.append("")
        lines.append("```text")
        lines.extend(wrap_table(sec.columns, sec.rows, max_line_width=110))
        lines.append("```")
        if sec.footnote:
            lines.append(f"*{sec.footnote}*")
        lines.append("")

    if unclassified:
        lines.append("## Unclassified variables (script needs updating)")
        lines.append("")
        rows = [Row([v["name"], v["type"], v["label"]]) for v in unclassified]
        lines.append("```text")
        lines.extend(wrap_table(["Variable", "Type", "Label"], rows, max_line_width=110))
        lines.append("```")
        lines.append("")

    out_path.write_text("\n".join(lines), encoding="utf-8")


# --------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------


def _atomic_write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    import os

    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
        os.replace(tmp_name, path)
    except BaseException:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
        raise


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Regenerate the 'Variables in the Main Merged Dataset' summary PDF "
        "from main_data_county_year.dta's own header metadata."
    )
    parser.add_argument(
        "--dta",
        type=Path,
        default=DEFAULT_DTA,
        help=f"path to main_data_county_year.dta (default: {DEFAULT_DTA})",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=DEFAULT_OUT_DIR,
        help=f"directory to write the PDF/Markdown into (default: repo root, {DEFAULT_OUT_DIR})",
    )
    parser.add_argument(
        "--basename",
        default=DEFAULT_BASENAME,
        help=f"output filename without extension (default: '{DEFAULT_BASENAME}')",
    )
    parser.add_argument("--no-md", action="store_true", help="write only the PDF, skip the .md twin")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="exit with an error if any variable can't be classified into a known section",
    )
    args = parser.parse_args(argv)

    if not args.dta.exists():
        sys.exit(f"File not found: {args.dta}")

    try:
        meta, parser_note = read_dta_metadata(args.dta)
    except Exception as exc:
        sys.exit(f"Could not read {args.dta} as a Stata .dta file: {exc}")

    sections, unclassified = build_sections(meta["variables"])

    pdf_path = args.out_dir / f"{args.basename}.pdf"
    render_pdf(pdf_path, args.dta.name, meta["n_vars"], meta["n_obs"], sections, unclassified, parser_note)
    print(f"wrote: {pdf_path}")

    if not args.no_md:
        md_path = args.out_dir / f"{args.basename}.md"
        render_markdown(md_path, args.dta.name, meta["n_vars"], meta["n_obs"], sections, unclassified, parser_note)
        print(f"wrote: {md_path}")

    if unclassified:
        names = ", ".join(v["name"] for v in unclassified)
        print(
            f"\nWARNING: {len(unclassified)} variable(s) didn't match any known section "
            f"and were listed under 'Unclassified' instead: {names}\n"
            "This usually means main_data_county_year.dta gained (or renamed) columns "
            "since this script's section rules were written -- update the rules near "
            "the top of update_main_dta_variable_summary.py to classify them.",
            file=sys.stderr,
        )
        if args.strict:
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
