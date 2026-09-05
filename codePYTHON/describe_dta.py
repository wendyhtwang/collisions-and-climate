#!/usr/bin/env python3
"""
describe_dta.py

Read a Stata .dta file's header/metadata and print a variable table --
name, label, storage type -- plus variable/observation counts and the
dataset's sort order, similar to Stata's own `describe` command. Only
the file's header is parsed (the full dataset is never loaded into
memory), so this is fast even on large files.

Some .dta files -- typically ones written by a tool other than Stata
itself (R's `foreign`/`haven` packages, older exports, etc.) -- use type
codes that pandas' own parser doesn't recognize and fail with an opaque
error such as "list index out of range". When that happens, this script
automatically retries with pyreadstat (if installed), which uses the
more permissive ReadStat C library. That fallback path can't recover the
dataset's sort order (Stata doesn't expose it the same way through that
library) and reports slightly coarser storage types.

Usage:
    python3 describe_dta.py path/to/file.dta
    python3 describe_dta.py path/to/file.dta --csv out.csv

Requires: pandas. Optional: pyreadstat, used only as a fallback for
files pandas can't parse (pip3 install pyreadstat).
"""

import argparse
import csv
import sys
from pathlib import Path

try:
    import pandas as pd
except ImportError:
    sys.exit("This script requires pandas. Install it with: pip3 install pandas")


# Stata's on-disk type codes -> human-readable storage-type names.
# Numeric types use a fixed one-letter code; string types are encoded
# as the string's byte width itself (str1-str2045).
_NAMED_TYPES = {
    "b": "byte",
    "h": "int",
    "l": "long",
    "f": "float",
    "d": "double",
    "Q": "strL",
}

# pyreadstat's generic (readstat) type names -> Stata storage-type names,
# used only in the fallback path.
_READSTAT_TYPE_NAMES = {
    "int8": "byte",
    "int16": "int",
    "int32": "long",
    "int64": "long",
    "float": "float",
    "double": "double",
}


def stata_type_name(code):
    """Translate one raw type code from StataReader._typlist into Stata's
    own storage-type name, e.g. 'long', 'double', 'str10', 'strL'."""
    if isinstance(code, str):
        return _NAMED_TYPES.get(code, code)
    if code == 32768:
        return "strL"
    return f"str{code}"


def _read_with_pandas(path):
    """
    Primary parser. Opens `path` and pulls variable-level metadata plus
    file-level counts and sort order, without materializing the dataset.

    Returns a dict: variables (list of {name, label, type} dicts),
    n_vars, n_obs, sorted_by (list of variable names, possibly empty).
    """
    with pd.io.stata.StataReader(str(path)) as reader:
        var_labels = reader.variable_labels()  # public API; also parses the header
        varnames = list(var_labels.keys())
        typlist = list(reader._typlist)
        n_obs = reader._nobs

        try:
            srtlist = list(reader._srtlist)
        except AttributeError:
            # Sort-order metadata isn't exposed on this pandas version --
            # degrade gracefully rather than failing the whole read.
            srtlist = []

    if len(typlist) != len(varnames):
        raise ValueError(
            f"Parsed {len(varnames)} variable names but {len(typlist)} types -- "
            "the file may be in a format this script can't parse."
        )

    variables = [
        {"name": name, "label": var_labels.get(name, ""), "type": stata_type_name(t)}
        for name, t in zip(varnames, typlist)
    ]

    # srtlist holds 1-based variable positions, terminated by a 0. Guard
    # against out-of-range indices rather than crashing on a malformed list.
    sorted_by = [varnames[i - 1] for i in srtlist if i and 0 < i <= len(varnames)]

    return {
        "variables": variables,
        "n_vars": len(varnames),
        "n_obs": n_obs,
        "sorted_by": sorted_by,
    }


def _read_with_pyreadstat(path):
    """
    Fallback parser for files pandas can't read. Uses pyreadstat
    (ReadStat) in metadata-only mode -- still no need to load the actual
    data. Sort order isn't available through this library, so it's
    reported as None (distinct from an empty list, which means "no sort
    order").
    """
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

    return {
        "variables": variables,
        "n_vars": meta.number_columns,
        "n_obs": meta.number_rows,
        "sorted_by": None,
    }


def read_dta_metadata(path):
    """
    Read `path`'s metadata, trying pandas first and falling back to
    pyreadstat if pandas can't parse the file. Returns (meta, parser_note)
    where parser_note is None for the normal path, or a short string
    describing the fallback that was used.
    """
    try:
        return _read_with_pandas(path), None
    except Exception as pandas_exc:
        try:
            import pyreadstat  # noqa: F401
        except ImportError:
            raise RuntimeError(
                f"pandas could not parse this file ({pandas_exc}). This can happen "
                "with .dta files written by a tool other than Stata (e.g. R's "
                "`foreign`/`haven` packages). Installing pyreadstat gives this "
                "script a more permissive fallback parser -- try:\n"
                "    pip3 install pyreadstat\n"
                "and re-run."
            ) from pandas_exc

        try:
            meta = _read_with_pyreadstat(path)
        except Exception as pyreadstat_exc:
            raise RuntimeError(
                f"Could not parse this file with pandas ({pandas_exc}) or with "
                f"pyreadstat ({pyreadstat_exc}) either."
            ) from pyreadstat_exc

        note = (
            "pandas couldn't parse this file, so this used pyreadstat as a "
            "fallback -- sort order isn't available through that path, and "
            "storage types are approximate."
        )
        return meta, note


def format_table(variables):
    """Return the variable table (name/label/type) as plain-text lines."""
    headers = ("Variable", "Label", "Type")
    rows = [(v["name"], v["label"], v["type"]) for v in variables]

    widths = [
        max(len(headers[i]), max((len(r[i]) for r in rows), default=0))
        for i in range(3)
    ]

    def fmt_row(row):
        return "  ".join(str(cell).ljust(widths[i]) for i, cell in enumerate(row))

    lines = [fmt_row(headers), "  ".join("-" * w for w in widths)]
    lines.extend(fmt_row(row) for row in rows)
    return lines


def main():
    parser = argparse.ArgumentParser(
        description="Summarize a Stata .dta file: variable name, label, and "
        "storage type, plus variable/observation counts and sort order."
    )
    parser.add_argument("dta_file", help="Path to the .dta file")
    parser.add_argument(
        "--csv",
        metavar="OUT_FILE",
        help="Also write the variable table (name, label, type) to this CSV file",
    )
    args = parser.parse_args()

    dta_path = Path(args.dta_file)
    if not dta_path.exists():
        sys.exit(f"File not found: {dta_path}")

    try:
        meta, note = read_dta_metadata(dta_path)
    except Exception as exc:
        sys.exit(f"Could not read {dta_path} as a Stata .dta file: {exc}")

    print(f"\n{dta_path.name}\n")
    for line in format_table(meta["variables"]):
        print(line)

    if meta["sorted_by"] is None:
        sorted_by = "(not available -- read with fallback parser)"
    elif meta["sorted_by"]:
        sorted_by = " ".join(meta["sorted_by"])
    else:
        sorted_by = "(dataset has no sort order)"

    print()
    print(f"Number of variables:    {meta['n_vars']}")
    print(f"Number of observations: {meta['n_obs']}")
    print(f"Sorted by: {sorted_by}")

    if note:
        print(f"\nNote: {note}")

    if args.csv:
        with open(args.csv, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["variable", "label", "type"])
            for v in meta["variables"]:
                writer.writerow([v["name"], v["label"], v["type"]])
        print(f"\nVariable table written to {args.csv}")


if __name__ == "__main__":
    main()
