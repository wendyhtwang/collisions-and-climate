#!/usr/bin/env python3
"""
describe_dta.py

Read a Stata .dta file's header/metadata and print a variable table --
name, label, storage type -- plus variable/observation counts and the
dataset's sort order, similar to Stata's own `describe` command. Only
the file's header is parsed (the full dataset is never loaded into
memory), so this is fast even on large files.

Usage:
    python3 describe_dta.py path/to/file.dta
    python3 describe_dta.py path/to/file.dta --csv out.csv

Requires: pandas (no other dependencies).
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


def stata_type_name(code):
    """Translate one raw type code from StataReader._typlist into Stata's
    own storage-type name, e.g. 'long', 'double', 'str10', 'strL'."""
    if isinstance(code, str):
        return _NAMED_TYPES.get(code, code)
    if code == 32768:
        return "strL"
    return f"str{code}"


def read_dta_metadata(path):
    """
    Open `path` and pull variable-level metadata plus file-level counts
    and sort order, without materializing the dataset.

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

    # srtlist holds 1-based variable positions, terminated by a 0.
    sorted_by = [varnames[i - 1] for i in srtlist if i]

    return {
        "variables": variables,
        "n_vars": len(varnames),
        "n_obs": n_obs,
        "sorted_by": sorted_by,
    }


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
        meta = read_dta_metadata(dta_path)
    except Exception as exc:
        sys.exit(f"Could not read {dta_path} as a Stata .dta file: {exc}")

    print(f"\n{dta_path.name}\n")
    for line in format_table(meta["variables"]):
        print(line)

    if meta["sorted_by"]:
        sorted_by = " ".join(meta["sorted_by"])
    else:
        sorted_by = "(dataset has no sort order)"

    print()
    print(f"Number of variables:    {meta['n_vars']}")
    print(f"Number of observations: {meta['n_obs']}")
    print(f"Sorted by: {sorted_by}")

    if args.csv:
        with open(args.csv, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["variable", "label", "type"])
            for v in meta["variables"]:
                writer.writerow([v["name"], v["label"], v["type"]])
        print(f"\nVariable table written to {args.csv}")


if __name__ == "__main__":
    main()
