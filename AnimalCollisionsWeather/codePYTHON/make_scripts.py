"""Generate the Tier 1 / Tier 2 .py scripts from the notebook.

Eyal, 8/28: "at some point, when working with data of some ... size and
complexity, [notebooks] just are not a good vehicle ... you're just better off
with just like a .py script", and "having the main file that orchestrates all of
the other files, in terms of like: you press go once, it runs through everything
and produces all the outputs." He also asked for Tier 1 and Tier 2 to be
"definitely separated" but each kept in ONE file for now -- per-figure scripts
come later, when the replication package is assembled.

Generated from the notebook rather than retyped, so the scripts cannot drift from
the cells they came from. Re-run this after any notebook change.
"""
import json
import re
import sys
from pathlib import Path

NB = Path(sys.argv[1] if len(sys.argv) > 1 else "09_descriptive_weather_full.ipynb")
OUT_DIR = NB.parent

COMMON = "weather_descriptives_utils.py"
TIER1 = "09a_descriptive_weather_tier1.py"
TIER2 = "09b_descriptive_weather_tier2.py"

# Cell 27 holds both the shared geometry helpers and a Tier 1 exhibit. This marker
# is where it splits.
GEOMETRY_SPLIT = "variability_map = merge_county_geometry("

HEADER = '''"""{title}

GENERATED FILE -- do not edit by hand.
Produced from codePYTHON/09_descriptive_weather_full.ipynb by make_scripts.py.
Edit the notebook, then re-run make_scripts.py.
"""
'''

SHIM = '''
# --- notebook compatibility ------------------------------------------------
# The notebook renders every figure inline; a script does not. matplotlib runs
# headless and the inline preview becomes a no-op, so the figure PDFs are the
# only output either way.
import matplotlib
matplotlib.use("Agg")


def display(*args, **kwargs):
    """No-op stand-in for IPython's display() outside a notebook."""
    for item in args:
        try:
            print(item.to_string() if hasattr(item, "to_string") else item)
        except Exception:
            pass
# ---------------------------------------------------------------------------
'''


def cell_source(cell):
    src = cell.get("source", "")
    return src if isinstance(src, str) else "".join(src)


def to_script(text):
    """Strip the notebook-only constructs from a cell's source."""
    text = re.sub(r'^\s*get_ipython\(\).*\n', '', text, flags=re.MULTILINE)
    text = text.replace("from IPython.display import SVG, display\n", "")
    # display_figure_inline exists to draw in the notebook; in a script it would
    # render an SVG nobody sees.
    text = text.replace(
        '''def display_figure_inline(fig):
    """Embed a vector SVG in notebook output, independent of backend."""
    buffer = io.StringIO()
    fig.savefig(buffer, format="svg", bbox_inches="tight")
    display(SVG(data=buffer.getvalue()))
    buffer.close()''',
        '''def display_figure_inline(fig):
    """No-op in script form; the notebook uses this to draw inline."""
    return None''')
    return text



RETURNED = ["config", "df", "load_diagnostics", "county_winter", "winter_completeness",
            "winter_diagnostics", "county_geometry", "state_geometry", "county_variability"]


def split_module(text):
    """Separate top-level DEFINITIONS from top-level WORK.

    Definitions -- imports, functions, classes, CONSTANTS -- stay at module level
    so importing the module is free. Everything else at top level (reading the
    CSVs, building the panel, loading the shapefile, writing a table) is work, and
    moves inside build_panel() so it happens when a script asks for it.
    """
    import ast
    tree = ast.parse(text)
    lines = text.splitlines(keepends=True)
    defs, work, assigned = [], [], []
    previous_end = 0

    for node in tree.body:
        start = node.lineno - 1
        if getattr(node, "decorator_list", None):
            start = min(d.lineno for d in node.decorator_list) - 1
        # carry any comment block immediately above the statement with it
        lead = start
        while lead > previous_end and lines[lead - 1].lstrip().startswith("#"):
            lead -= 1
        chunk = "".join(lines[lead:node.end_lineno])
        previous_end = node.end_lineno

        is_definition = isinstance(node, (ast.Import, ast.ImportFrom,
                                          ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))
        if isinstance(node, ast.Assign):
            names = [t.id for t in node.targets if isinstance(t, ast.Name)]
            is_definition = bool(names) and all(n.isupper() or n.startswith("_") for n in names)
        if is_definition:
            defs.append(chunk)
        else:
            work.append(chunk)
            for sub in ast.walk(node):
                if isinstance(sub, ast.Name) and isinstance(sub.ctx, ast.Store):
                    assigned.append(sub.id)
    return "".join(defs), "".join(work), sorted(set(assigned))


def assemble_utils(parts):
    definitions, work, assigned = split_module("\n\n".join(parts))
    globals_line = ", ".join(assigned)
    body = "".join("    " + line if line.strip() else line
                   for line in work.splitlines(keepends=True))
    returned = ",\n".join(f'        "{name}": {name}' for name in RETURNED)
    return f'''{definitions}

# Placeholders. build_panel() fills these in; see the note on that function.
{chr(10).join(f"{name} = None" for name in RETURNED)}

_BUILT = False


def build_panel():
    """Read the weather CSVs and build the county-winter panel.

    Importing this module does no I/O -- it only defines things. This function is
    where the work happens, so a script (or a test, or an interactive session)
    decides when to pay for it. Idempotent: calling it twice does the work once.

    Returns a dict of the objects both tiers need, for the caller to bind:

        globals().update(build_panel())
    """
    global _BUILT, {globals_line}
    if _BUILT:
        return _panel()
{body}
    _BUILT = True
    return _panel()


def _panel():
    return {{
{returned},
    }}
'''

def main():
    nb = json.loads(NB.read_text(encoding="utf-8"))
    cells = nb["cells"]

    def index_of(needle, kind="markdown"):
        for i, cell in enumerate(cells):
            if cell["cell_type"] == kind and needle in cell_source(cell):
                return i
        raise LookupError(needle)

    tier1_start = index_of("# Tier 1 — Internal QA")
    tier2_start = index_of("# Tier 2 — Polished explanatory exhibits")

    setup = [to_script(cell_source(c)) for c in cells[:tier1_start]
             if c["cell_type"] == "code"]

    geometry_cell = next(
        cell_source(c) for c in cells
        if c["cell_type"] == "code" and GEOMETRY_SPLIT in cell_source(c)
    )
    shared_geometry, tier1_variability = geometry_cell.split(GEOMETRY_SPLIT, 1)
    tier1_variability = GEOMETRY_SPLIT + tier1_variability

    tier1_cells = []
    for cell in cells[tier1_start:tier2_start]:
        if cell["cell_type"] != "code":
            continue
        text = cell_source(cell)
        tier1_cells.append(tier1_variability if GEOMETRY_SPLIT in text else to_script(text))

    tier2_cells = [to_script(cell_source(c)) for c in cells[tier2_start:]
                   if c["cell_type"] == "code"]

    decade_cell = next(cell_source(c) for c in cells
                       if c["cell_type"] == "code" and re.search(r"^def decade_label\(", cell_source(c), re.M))
    assert "def save_decade_distributions" in decade_cell, "decade cell not the expected one"
    decade_block = decade_cell.split("def save_decade_distributions")[0].rstrip() + "\n"

    variability_cell = next(cell_source(c) for c in cells
                            if c["cell_type"] == "code"
                            and "county_variability = (" in cell_source(c))
    variability_block = variability_cell.split("variability_by_state = (")[0].rstrip() + "\n"

    common = [HEADER.format(title="Shared setup for the weather descriptive scripts."), SHIM]
    common += setup
    common.append(to_script(shared_geometry))
    # TrendFit and _linear_trend are defined in a Tier 1 cell but every Tier 2
    # exhibit that reports a slope calls them.
    trend_cell = next(cell_source(c) for c in cells
                      if c["cell_type"] == "code" and "def _linear_trend(" in cell_source(c))
    assert "def plot_national_winter_trend" in trend_cell, "trend cell not the expected one"
    trend_block = trend_cell.split("def plot_national_winter_trend")[0].rstrip() + "\n"

    common.append("# Needed by both tiers, so built once here rather than in either script.\n"
                  + trend_block)
    common.append(decade_block)
    common.append(variability_block)
    (OUT_DIR / COMMON).write_text(assemble_utils(common), encoding="utf-8")

    # `import *` skips names beginning with an underscore, and the notebook has
    # several private helpers (_linear_trend, _numeric_weather_columns, ...) that
    # both tiers call. Import those explicitly, discovered rather than listed by
    # hand so a new helper cannot be missed.
    common_text = "\n\n".join(common)
    private = sorted(set(re.findall(r"^def (_\w+)", common_text, re.M))
                     | set(re.findall(r"^(_[A-Za-z]\w*) *=", common_text, re.M)))

    def make_preamble(body_text):
        used = [name for name in private if re.search(rf"\b{name}\b", body_text)]
        lines = ["import weather_descriptives_utils as wx",
                 "from weather_descriptives_utils import *  # noqa: F401,F403"]
        if used:
            lines.append("from weather_descriptives_utils import (")
            lines.append("    " + ", ".join(used) + ",")
            lines.append(")")
        lines += [
            "",
            "# Reading the CSVs and building the county-winter panel is an explicit",
            "# call, not an import side effect. The panel's objects are bound into",
            "# this script's namespace so the exhibit code below reads unchanged.",
            "globals().update(wx.build_panel())",
        ]
        return "\n".join(lines) + "\n"
    tier1_body = "\n\n".join(tier1_cells)
    tier1 = [HEADER.format(title="Tier 1 -- internal QA and exploratory exhibits."),
             make_preamble(tier1_body)]
    tier1 += tier1_cells
    tier1.append('print("Tier 1 complete.")\n')
    (OUT_DIR / TIER1).write_text("\n\n".join(tier1), encoding="utf-8")

    tier2_body = "\n\n".join(tier2_cells)
    tier2 = [HEADER.format(title="Tier 2 -- polished exhibits for the PI report."),
             make_preamble(tier2_body)]
    tier2 += tier2_cells
    tier2.append('print("Tier 2 complete.")\n')
    (OUT_DIR / TIER2).write_text("\n\n".join(tier2), encoding="utf-8")

    for name in (COMMON, TIER1, TIER2):
        path = OUT_DIR / name
        print(f"wrote {path} ({len(path.read_text().splitlines())} lines)")


if __name__ == "__main__":
    main()
