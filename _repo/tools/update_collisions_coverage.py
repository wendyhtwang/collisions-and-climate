"""Inventory the collision data repo and write the state x year coverage matrix.

Reads the Dropbox tree directly (not the git clone), so run it from anywhere:
    python3 _repo/tools/update_collisions_coverage.py
    python3 _repo/tools/update_collisions_coverage.py --root <folder holding VehicleCollisionsDataRepo>

- Scans raw files, state scripts, state output files, the 1985-2020 snapshot
  and the Collisions2026 request tracker (contact column skipped).
- Writes CSVs to VehicleCollisionsDataRepo/output/coverage/.
- Read-only everywhere else. Years parsed from file names are a heuristic.
"""

import argparse
import datetime as dt
import re
import shutil
import sys
from pathlib import Path

import pandas as pd

STATES = ("AL AR AZ CA CO CT DC DE FL GA IA ID IL IN KS KY LA MA MD ME MI MN MO MS MT NC "
          "ND NE NH NJ NM NV NY OH OK OR PA RI SC SD TN TX UT VA VT WA WI WV WY").split()
STATE_FIPS = {
    "01": "AL", "04": "AZ", "05": "AR", "06": "CA", "08": "CO", "09": "CT", "10": "DE",
    "11": "DC", "12": "FL", "13": "GA", "16": "ID", "17": "IL", "18": "IN", "19": "IA",
    "20": "KS", "21": "KY", "22": "LA", "23": "ME", "24": "MD", "25": "MA", "26": "MI",
    "27": "MN", "28": "MS", "29": "MO", "30": "MT", "31": "NE", "32": "NV", "33": "NH",
    "34": "NJ", "35": "NM", "36": "NY", "37": "NC", "38": "ND", "39": "OH", "40": "OK",
    "41": "OR", "42": "PA", "44": "RI", "45": "SC", "46": "SD", "47": "TN", "48": "TX",
    "49": "UT", "50": "VT", "51": "VA", "53": "WA", "54": "WV", "55": "WI", "56": "WY",
}
YEARS = range(1985, 2026)

# Variable families, matched on column names (old snapshot names and new names)
FAMILIES = {
    "all_cause": r"^(total_all_cause|total_total|total_collisions?)$",
    "severity": r"^(fatal_collision|injury_collision|pdo_collision|total_fatal|total_injury|total_pdo)$",
    "animal": r"^(animal_collision|any_animal_total|animal_total|wild_animal_total)$",
    "deer": r"^(deer_total|deer_fatal_collision|fatal_deer_collision|deer_collision)$",
    "alcohol": r"^(alcohol_collision|alcohol_total|any_alcohol_total|dui_total|dui_collision)$",
}
EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+")


def years_in_name(text):
    """Years mentioned in a file or folder name, e.g. 2005-2016, 97-18, (19-01-01 to 19-12-31)."""
    yy = lambda s: int(s) + (1900 if int(s) >= 80 else 2000)
    found = set()
    for a, b, b_md in re.findall(r"\((\d{2})-\d{2}-\d{2} to (\d{2})-(\d{2}-\d{2})\)", text):
        end = yy(b) - 1 if b_md == "01-01" else yy(b)  # "to 21-01-01" ends in 2020
        found.update(range(yy(a), end + 1))
    text = re.sub(r"\(\d{2}-\d{2}-\d{2} to \d{2}-\d{2}-\d{2}\)", " ", text)
    text = re.sub(r"(?<!\d)\d{2}-\d{2}-\d{2}(?!\d)", " ", text)  # request dates, not data years
    for a, b in re.findall(r"(?<!\d)((?:19|20)\d{2})-((?:19|20)\d{2}|\d{2})(?!\d)", text):
        end = int(b) if len(b) == 4 else yy(b)
        if int(a) <= end <= 2026:
            found.update(range(int(a), end + 1))
    for a, b in re.findall(r"(?<![\d.])(\d{2})-(\d{2})(?![\d-])", text):
        if yy(a) <= yy(b) and yy(b) <= 2026:
            found.update(range(yy(a), yy(b) + 1))
    found.update(int(y) for y in re.findall(r"(?<!\d)((?:198|199|200|201|202)\d)(?!\d)", text))
    return sorted(y for y in found if 1975 <= y <= 2026)


def read_text(path):
    try:
        return path.read_text(errors="replace")
    except OSError as e:
        return f"__READ_ERROR__ {e}"


def inventory_raw(vcd):
    """One row per raw file under dataRAW/DVCs/<ST>/ and dataCSV/DVCs/<ST>/."""
    rows = []
    for area in ("dataRAW", "dataCSV"):
        base = vcd / area / "DVCs"
        for st in STATES:
            folder = base / st
            if not folder.is_dir():
                continue
            for f in folder.rglob("*"):
                if not f.is_file() or f.name.startswith((".", "~$")):
                    continue
                rel = f.relative_to(folder)
                try:
                    stat = f.stat()
                    size, mtime = stat.st_size, dt.datetime.fromtimestamp(stat.st_mtime).date()
                except OSError:
                    size, mtime = None, None
                yrs = years_in_name(str(rel))
                rows.append({
                    "state": st, "area": area, "path": str(rel), "ext": f.suffix.lower(),
                    "size_mb": round(size / 1e6, 2) if size else None, "modified": mtime,
                    "is_archive": "archive" in str(rel).lower(),
                    "years_in_name": ";".join(map(str, yrs)),
                    "year_min": min(yrs) if yrs else None, "year_max": max(yrs) if yrs else None,
                })
    return pd.DataFrame(rows)


def inventory_scripts(vcd):
    """One row per state: what its .do file points at, saves and last changed."""
    split = vcd / "codeSTATA" / "data_dvcs_county_year_split"
    wip = [p for p in (vcd / "codeSTATA").glob("*WIP*/*.do")]
    rows = []
    for st in STATES:
        f = split / f"{st}.do"
        row = {"state": st, "script_exists": f.is_file()}
        names = [p.parent.name + "/" + p.name for p in wip if re.search(rf"(?<![A-Z]){st}(?![A-Z])", p.name)]
        row["wip_files"] = "; ".join(names)
        if f.is_file():
            text = read_text(f)
            row["script_read_error"] = text.startswith("__READ_ERROR__")
            row["script_modified"] = dt.datetime.fromtimestamp(f.stat().st_mtime).date()
            row["script_lines"] = text.count("\n")
            if "/mnt/data_d/Dropbox" in text:
                root = "kodama"
            elif re.search(r"GDrive|GoogleDrive|Google Drive|WolvesImpacts", text):
                root = "old_google_drive"
            elif re.search(r"[CD]:/Dropbox", text):
                root = "windows_dropbox"
            else:
                root = "unknown"
            row["script_root"] = root
            row["header_style_guide"] = bool(re.search(r"^/\*=+\s*\n\s*FILE:", text, re.M))
            lead = re.search(r"(?:CURRENT LEAD|Current Lead):\s*(.+)", text)
            row["current_lead"] = lead.group(1).strip() if lead else None
            log = re.findall(r"(\d{2})/(\d{2})/(\d{4})\s*\[([^\]]+)\]", text[:20000])
            if log:
                last = max(log, key=lambda m: (m[2], m[0], m[1]))
                row["last_changelog"] = f"{last[2]}-{last[0]}-{last[1]}"
                row["last_changelog_by"] = last[3].split("-")[0].strip()
            loops = re.findall(r"forvalues\s+\w+\s*=\s*((?:19|20)\d{2})\s*(?:\(\s*1\s*\)|/)\s*((?:19|20)\d{2})", text)
            if loops:
                row["loop_year_max"] = max(int(b) for _, b in loops)
            row["n_browse_lines"] = len(re.findall(r"^\s*(?:br|browse)\b", text, re.M))
            row["has_log_using"] = "log using" in text
            save_lines = [ln for ln in text.splitlines()
                          if re.match(r"\s*(save|local\s+file_name)\b", ln) and "dvcs_" in ln]
            saves = [m for ln in save_lines for m in re.findall(r"(dvcs_([A-Z]{2})_[^\s\",]*)", ln)]
            row["saves"] = "; ".join(sorted({s for s, _ in saves}))
            row["save_state_mismatch"] = any(code != st for _, code in saves)
        rows.append(row)
    return pd.DataFrame(rows)


def family_table(df, state_col, source):
    """State x year rows: which families have data, their sums, and statewide zeros."""
    cols = {fam: [c for c in df.columns if re.match(pat, c)] for fam, pat in FAMILIES.items()}
    out = []
    for (st, yr), g in df.groupby([state_col, "year"]):
        row = {"state": st, "year": int(yr), "source": source, "n_counties": len(g)}
        for fam, cs in cols.items():
            vals = g[cs].apply(pd.to_numeric, errors="coerce") if cs else pd.DataFrame()
            has = bool(cs) and vals.notna().any().any()
            row[f"{fam}_has_data"] = has
            if has and fam != "severity":
                s = vals[cs[0]].sum(min_count=1) if vals[cs[0]].notna().any() else vals.max(axis=1).sum()
                row[f"{fam}_sum"] = s
                row[f"{fam}_statewide_zero"] = bool(s == 0)
        out.append(row)
    return pd.DataFrame(out)


def to_state(df):
    """Two-letter state code from state_letter_code or the first two digits of fips."""
    if "state_letter_code" in df.columns:
        return df["state_letter_code"].astype(str).str.upper().str.strip()
    fips = df["fips"].astype(str).str.replace(r"\.0$", "", regex=True).str.zfill(5)
    return fips.str[:2].map(STATE_FIPS)


def inventory_outputs(vcd):
    """Per-file summary and state x year table for VehicleCollisionsDataRepo/dataSTATA/dvcs_*.dta."""
    files, tables = [], []
    for f in sorted((vcd / "dataSTATA").glob("dvcs_*.dta")):
        m = re.match(r"dvcs_([A-Z]{2})_", f.name)
        row = {"file": f.name, "state": m.group(1) if m else None,
               "modified": dt.datetime.fromtimestamp(f.stat().st_mtime).date(),
               "size_mb": round(f.stat().st_size / 1e6, 2)}
        if re.search(r"crash_level|duplicate|_build", f.name):
            row["note"] = "not county-year; not read"
            files.append(row)
            continue
        try:
            df = pd.read_stata(f, convert_categoricals=False)
        except Exception as e:  # noqa: BLE001 - record and move on
            row["note"] = f"read error: {e}"
            files.append(row)
            continue
        try:
            row.update({"n_rows": len(df), "columns": ";".join(df.columns)})
            if "fips" in df.columns:
                row["fips_type"] = "numeric" if pd.api.types.is_numeric_dtype(df.fips) else "string"
                row["n_counties"] = df.fips.nunique()
            row["families"] = ";".join(f for f, p in FAMILIES.items() if any(re.match(p, c) for c in df.columns))
            if "year" in df.columns:
                row["year_type"] = "numeric" if pd.api.types.is_numeric_dtype(df.year) else "string"
                df["year"] = pd.to_numeric(df["year"], errors="coerce")
                n_bad = int(df["year"].isna().sum())
                if n_bad:
                    row["note"] = f"{n_bad} rows with blank or non-numeric year left out"
                df = df[df["year"].notna()]
                if len(df):
                    row.update({"year_min": int(df.year.min()), "year_max": int(df.year.max())})
            if len(df) and "year" in df.columns and ("fips" in df.columns or "state_letter_code" in df.columns):
                df["_st"] = to_state(df)
                tables.append(family_table(df, "_st", f.name))
        except Exception as e:  # noqa: BLE001 - record and move on
            row["note"] = f"summary error: {e!r}"
        files.append(row)
    return pd.DataFrame(files), (pd.concat(tables) if tables else pd.DataFrame())


def inventory_snapshot(path):
    """State x year table for the 1985-2020 snapshot the merge reads today."""
    if not path.is_file():
        return pd.DataFrame(), [f"snapshot not found: {path}"]
    df = pd.read_stata(path, convert_categoricals=False)
    df["year"] = pd.to_numeric(df["year"], errors="coerce")
    df = df[df["year"].notna()]
    df["_st"] = to_state(df)
    flags = [c for c in df.columns if c.startswith("imputation_flag")]
    t = family_table(df, "_st", "snapshot")
    if flags:
        f = df.groupby(["_st", "year"])[flags].max().reset_index().rename(columns={"_st": "state"})
        f["year"] = f["year"].astype(int)
        t = t.merge(f, on=["state", "year"], how="left")
    return t, [f"snapshot columns: {';'.join(df.columns)}"]


def read_tracker(path):
    """Collisions2026 sheet of the request tracker; contacts skipped, emails redacted."""
    if not path.is_file():
        return pd.DataFrame(), f"tracker not found: {path}"
    try:
        import openpyxl
        ws = openpyxl.load_workbook(path, data_only=True)["Collisions2026"]
    except (ImportError, KeyError) as e:
        return pd.DataFrame(), f"tracker not read: {e!r}"
    header = [str(c.value).strip() if c.value else "" for c in ws[2]]
    keep = {"State": "state", "Code": "updated_code", "Data": "updated_data", "Up to": "up_to",
            "Deer": "deer", "Animals": "animals", "DUIs": "duis", "Records": "records",
            "Aggregated": "aggregated", "Interacted on": "last_contacted", "Comments": "comments"}
    rows = []
    for r in ws.iter_rows(min_row=3):
        vals = dict(zip(header, r))
        st = vals.get("State")
        if not st or not st.value:
            continue
        row = {new: (vals[old].value if old in vals else None) for old, new in keep.items()}
        row["state"] = str(row["state"]).strip().upper()
        if row["comments"]:
            row["comments"] = EMAIL.sub("[email]", str(row["comments"]))
        fill = st.fill.fgColor if st.fill is not None and st.fill.fill_type else None
        row["highlight"] = (fill.rgb if fill is not None and fill.type == "rgb"
                            else f"theme{fill.theme}" if fill is not None and fill.type == "theme" else None)
        if isinstance(row["last_contacted"], dt.datetime):
            row["last_contacted"] = row["last_contacted"].date()
        if row["up_to"] is not None:
            m = re.match(r"\s*(\d{4})", str(row["up_to"]))
            row["up_to"] = int(m.group(1)) if m else None
        rows.append(row)
    return pd.DataFrame(rows).drop_duplicates("state"), None


def status(r):
    """One label per state-year, most advanced stage first."""
    if r.get("in_state_file"):
        return "state_file"
    if r.get("in_snapshot"):
        return "snapshot_only"
    if r.get("raw_year_named") or r.get("tracker_received"):
        return "raw_not_processed"
    if r.get("tracker_contacted"):
        return "requested"
    return "none"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--root", default="/mnt/data_d/Dropbox/Research",
                   help="folder holding VehicleCollisionsDataRepo and AnimalCollisionsWeather")
    p.add_argument("--out", default=None, help="default: <root>/VehicleCollisionsDataRepo/output/coverage")
    a = p.parse_args()
    root = Path(a.root).expanduser()
    vcd = root / "VehicleCollisionsDataRepo"
    if not vcd.is_dir():
        sys.exit(f"Not found: {vcd}")
    out = Path(a.out) if a.out else vcd / "output" / "coverage"
    out.mkdir(parents=True, exist_ok=True)
    notes = [f"run: {dt.datetime.now():%Y-%m-%d %H:%M}", f"root: {root}", f"pandas {pd.__version__}"]

    raw = inventory_raw(vcd)
    scripts = inventory_scripts(vcd)
    out_files, out_sy = inventory_outputs(vcd)
    snap_sy, snap_notes = inventory_snapshot(root / "AnimalCollisionsWeather" / "dataRAW" / "Collisions"
                                             / "collisions_CONUS_county_year_1985_2020.dta")
    notes += snap_notes
    tracker, err = read_tracker(vcd / "dataRAW" / "Data sources and contacts summary.xlsx")
    if err:
        notes.append(err)

    append = vcd / "codeSTATA" / "data_append_state_collisions_files.do"
    if append.is_file():
        shutil.copy(append, out / "data_append_state_collisions_files.do.txt")
    else:
        notes.append(f"append script not found: {append}")

    # State x year grid
    grid = pd.DataFrame([(s, y) for s in STATES for y in YEARS], columns=["state", "year"])
    fams = list(FAMILIES)
    if not out_sy.empty:
        agg = out_sy.groupby(["state", "year"]).agg(
            **{f"file_{f}": (f"{f}_has_data", "max") for f in fams},
            state_files=("source", lambda s: "; ".join(sorted(set(s))))).reset_index()
        grid = grid.merge(agg, on=["state", "year"], how="left")
    if not snap_sy.empty:
        keep = ["state", "year", "n_counties"] + [c for c in snap_sy.columns
                                                  if c.endswith(("_has_data", "_statewide_zero"))
                                                  or c.startswith("imputation_flag")]
        s = snap_sy[keep].rename(columns=lambda c: c if c in ("state", "year") else f"snap_{c}")
        grid = grid.merge(s, on=["state", "year"], how="left")
    named = raw[raw.years_in_name != ""].assign(year=raw.years_in_name.str.split(";")).explode("year") \
        if not raw.empty else pd.DataFrame(columns=["state", "year", "path", "area"])
    if not named.empty:
        named["year"] = named.year.astype(int)
        r = named.groupby(["state", "year"]).agg(
            raw_files=("path", lambda s: "; ".join(sorted(set(s))[:8]) + (" …" if s.nunique() > 8 else "")),
            raw_n_files=("path", "nunique")).reset_index()
        grid = grid.merge(r, on=["state", "year"], how="left")
    if not tracker.empty:
        grid = grid.merge(tracker[["state", "updated_data", "up_to", "last_contacted"]], on="state", how="left")

    has = lambda c: grid[c].fillna(False).astype(bool) if c in grid else pd.Series(False, index=grid.index)
    grid["in_state_file"] = has("file_all_cause") | has("file_animal")
    grid["in_snapshot"] = has("snap_all_cause_has_data") | has("snap_animal_has_data")
    grid["raw_year_named"] = grid.get("raw_n_files", pd.Series(0, index=grid.index)).fillna(0) > 0
    last_built = grid[grid.in_state_file | grid.in_snapshot].groupby("state").year.max()
    grid["last_built_year"] = grid.state.map(last_built)
    received = grid.get("updated_data", pd.Series(None, index=grid.index)).astype(str).str.upper().eq("X")
    upto = pd.to_numeric(grid.get("up_to"), errors="coerce")
    grid["tracker_received"] = received & (grid.year > grid.last_built_year.fillna(1984)) & (grid.year <= upto)
    grid["tracker_contacted"] = grid.get("last_contacted", pd.Series(None, index=grid.index)).notna() \
        & (grid.year > grid.last_built_year.fillna(1984))
    grid["status"] = grid.apply(status, axis=1)

    # One row per state
    state = scripts.copy()
    if not tracker.empty:
        state = state.merge(tracker, on="state", how="left")
    if not raw.empty:
        rs = raw.groupby("state").agg(raw_n_files=("path", "count"),
                                      raw_formats=("ext", lambda s: ";".join(sorted(set(s) - {""}))),
                                      raw_year_max=("year_max", "max"),
                                      raw_newest_file=("modified", "max")).reset_index()
        state = state.merge(rs, on="state", how="left")
    if not out_files.empty:
        of = out_files.groupby("state").agg(state_files=("file", "; ".join),
                                            state_file_year_max=("year_max", "max"),
                                            fips_type=("fips_type", "first")).reset_index()
        state = state.merge(of, on="state", how="left")
    state = state.merge(grid.groupby("state").last_built_year.max().reset_index(), on="state", how="left")
    counts = grid.pivot_table(index="state", columns="status", values="year", aggfunc="count", fill_value=0)
    state = state.merge(counts.add_prefix("years_").reset_index(), on="state", how="left")

    grid.to_csv(out / "coverage_state_year.csv", index=False)
    state.to_csv(out / "coverage_state.csv", index=False)
    raw.to_csv(out / "coverage_raw_files.csv", index=False)
    out_files.to_csv(out / "coverage_state_files.csv", index=False)
    if not snap_sy.empty:
        snap_sy.to_csv(out / "coverage_snapshot_state_year.csv", index=False)
    (out / "coverage_run_notes.txt").write_text("\n".join(notes) + "\n")

    print(f"Wrote {out}")
    print(grid.status.value_counts().to_string())
    print(f"{len(raw)} raw files, {len(out_files)} state output files, "
          f"{int(scripts.script_exists.sum())} state scripts, {len(tracker)} tracker rows")
    for n in notes[3:]:
        print("NOTE:", n[:200])


if __name__ == "__main__":
    main()
