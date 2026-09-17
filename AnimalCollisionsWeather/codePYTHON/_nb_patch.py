"""Cell-targeted edits for 09_descriptive_weather_full.ipynb.

The notebook is ~24MB when executed, so loading it into an editor or an
assistant's context is impractical. Every structural edit in the v2 revision
goes through this module instead: locate a cell by its markdown heading,
read or rewrite just that cell, and save.

Cells are addressed by HEADING TEXT rather than by index, because inserting a
section shifts every index after it. Always re-locate after an insert.
"""
import json
import re
import uuid
from pathlib import Path

NB_PATH = Path(__file__).resolve().parent / "09_descriptive_weather_full.ipynb"


def load(path=NB_PATH):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def save(nb, path=NB_PATH):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(nb, handle, indent=1, ensure_ascii=False)
        handle.write("\n")


def clear_outputs(nb):
    """Drop every output and execution count so the next run is a true fresh run."""
    cleared = 0
    for cell in nb["cells"]:
        if cell.get("cell_type") == "code":
            if cell.get("outputs") or cell.get("execution_count") is not None:
                cleared += 1
            cell["outputs"] = []
            cell["execution_count"] = None
    return cleared


def source(cell):
    src = cell.get("source", "")
    return src if isinstance(src, str) else "".join(src)


def get_source(nb, idx):
    return source(nb["cells"][idx])


def set_source(nb, idx, text):
    nb["cells"][idx]["source"] = text.splitlines(keepends=True)


def find_heading(nb, needle):
    """Index of the markdown cell whose text contains `needle` (case-sensitive)."""
    hits = [
        i for i, cell in enumerate(nb["cells"])
        if cell.get("cell_type") == "markdown" and needle in source(cell)
    ]
    if len(hits) != 1:
        raise LookupError(f"{needle!r} matched {len(hits)} markdown cells, expected 1")
    return hits[0]


def find_code(nb, needle):
    """Index of the single code cell containing `needle`."""
    hits = [
        i for i, cell in enumerate(nb["cells"])
        if cell.get("cell_type") == "code" and needle in source(cell)
    ]
    if len(hits) != 1:
        raise LookupError(f"{needle!r} matched {len(hits)} code cells, expected 1")
    return hits[0]


def code_under(nb, heading_needle):
    """Index of the first code cell after the markdown heading containing `needle`."""
    start = find_heading(nb, heading_needle)
    for i in range(start + 1, len(nb["cells"])):
        if nb["cells"][i].get("cell_type") == "code":
            return i
    raise LookupError(f"no code cell after heading {heading_needle!r}")


def replace_in_cell(nb, idx, old, new, count=1):
    """Exact substring replacement inside one cell; raises if `old` is not found."""
    text = get_source(nb, idx)
    found = text.count(old)
    if found < count:
        raise AssertionError(
            f"cell {idx}: expected >={count} occurrence(s) of {old[:70]!r}, found {found}"
        )
    set_source(nb, idx, text.replace(old, new, count))
    return found


def sub_in_cell(nb, idx, pattern, repl, flags=0, expect=None):
    """Regex replacement inside one cell, with an optional expected match count."""
    text = get_source(nb, idx)
    new_text, n = re.subn(pattern, repl, text, flags=flags)
    if expect is not None and n != expect:
        raise AssertionError(f"cell {idx}: {pattern!r} matched {n} times, expected {expect}")
    set_source(nb, idx, new_text)
    return n


def _new_cell(kind, text):
    cell = {
        "cell_type": kind,
        "id": uuid.uuid4().hex[:12],
        "metadata": {},
        "source": text.splitlines(keepends=True),
    }
    if kind == "code":
        cell["outputs"] = []
        cell["execution_count"] = None
    return cell


def insert_after(nb, idx, markdown=None, code=None):
    """Insert a markdown and/or code cell directly after `idx`. Returns the new indices."""
    new_cells = []
    if markdown is not None:
        new_cells.append(_new_cell("markdown", markdown))
    if code is not None:
        new_cells.append(_new_cell("code", code))
    nb["cells"][idx + 1:idx + 1] = new_cells
    return list(range(idx + 1, idx + 1 + len(new_cells)))


def append_to_cell(nb, idx, extra):
    set_source(nb, idx, get_source(nb, idx).rstrip("\n") + "\n\n" + extra.lstrip("\n"))


def outline(nb):
    """One line per cell: index, type, and either the heading or the first code line."""
    rows = []
    for i, cell in enumerate(nb["cells"]):
        text = source(cell)
        if cell.get("cell_type") == "markdown":
            head = next((l.strip() for l in text.splitlines() if l.strip().startswith("#")), "")
            rows.append(f"[{i:2d}] MD   {head[:96]}")
        else:
            first = next((l for l in text.splitlines() if l.strip()), "")
            rows.append(f"[{i:2d}] CODE ({len(text.splitlines()):3d} ln) {first[:80]}")
    return "\n".join(rows)


if __name__ == "__main__":
    import sys
    nb = load()
    if len(sys.argv) > 1 and sys.argv[1] == "clear":
        n = clear_outputs(nb)
        save(nb)
        print(f"cleared outputs from {n} code cells")
    else:
        print(outline(nb))
