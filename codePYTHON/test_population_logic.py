"""
Offline logic tests for population_utils.

Covers the parts of the pipeline that do not need network: crosswalk
mechanics for all four change types, the AGEGRP encoding guard, the
age-share pivot, the spine reindex, and the Stata write. Uses synthetic
fixtures so the expected numbers are known exactly.

Run: python3 test_population_logic.py
"""

import logging
import sys
import tempfile
from pathlib import Path

import pandas as pd

import population_utils as pu

logging.basicConfig(level=logging.WARNING)

FAILURES = []


def check(label, condition, detail=""):
    if condition:
        print(f"  PASS  {label}")
    else:
        print(f"  FAIL  {label} {detail}")
        FAILURES.append(label)


def long_rows(geoid, year, total, buckets=None):
    """Build one county-year's long AGEGRP rows summing to `total`."""
    buckets = buckets or [total // 18] * 18
    buckets = list(buckets)
    buckets[-1] += total - sum(buckets)
    rows = [{"geoid": geoid, "year": year, "agegrp": 0, "population": total}]
    rows += [
        {"geoid": geoid, "year": year, "agegrp": i + 1, "population": b}
        for i, b in enumerate(buckets)
    ]
    return rows


CROSSWALK_PATH = (
    Path(__file__).resolve().parents[1] / "dataCSV" / "Population" / "fips_crosswalk_1980_2025.csv"
)

print("\n== crosswalk file loads and validates ==")
crosswalk = pu.load_fips_crosswalk(CROSSWALK_PATH)
check("10 rows", len(crosswalk) == 10, f"got {len(crosswalk)}")
check("change types present",
      set(crosswalk["change_type"]) == {"rename", "merger", "split", "merge_split"})
check("South Boston 1995 present",
      ((crosswalk["old_geoid"] == "51780") & (crosswalk["new_geoid"] == "51083")).any())
check("Washabaugh 1983 present",
      ((crosswalk["old_geoid"] == "46131") & (crosswalk["new_geoid"] == "46071")).any())
check("splits have blank old_geoid",
      crosswalk.loc[crosswalk["change_type"] == "split", "old_geoid"].isna().all())

print("\n== parent parsing from notes ==")
broomfield = crosswalk[crosswalk["new_geoid"] == "08014"].iloc[0]
parents = pu._parse_parent_geoids(broomfield["notes"])
check("Broomfield has 4 parents", set(parents) == {"08001", "08013", "08059", "08123"},
      f"got {parents}")
cibola = crosswalk[crosswalk["new_geoid"] == "35006"].iloc[0]
check("Cibola parent is Valencia 35061", pu._parse_parent_geoids(cibola["notes"]) == ["35061"])
lapaz = crosswalk[crosswalk["new_geoid"] == "04012"].iloc[0]
check("La Paz parent is Yuma 04027", pu._parse_parent_geoids(lapaz["notes"]) == ["04027"])

print("\n== merger folds ALL years, not just post-change ==")
# South Boston (51780) separate through 1995; Halifax (51083) alongside it.
rows = []
rows += long_rows("51780", 1990, 1800)
rows += long_rows("51083", 1990, 29000)
rows += long_rows("51083", 2000, 36000)
merged = pu.apply_fips_crosswalk(pd.DataFrame(rows), crosswalk)

halifax_1990 = merged[(merged["geoid"] == "51083") & (merged["year"] == 1990) &
                      (merged["agegrp"] == 0)]["population"].iloc[0]
check("1990 Halifax = 29000 + 1800 folded in", halifax_1990 == 30800, f"got {halifax_1990}")
check("51780 no longer present", "51780" not in set(merged["geoid"]))
halifax_2000 = merged[(merged["geoid"] == "51083") & (merged["year"] == 2000) &
                      (merged["agegrp"] == 0)]["population"].iloc[0]
check("2000 Halifax unchanged", halifax_2000 == 36000, f"got {halifax_2000}")

print("\n== rename relabels without changing values ==")
rows = long_rows("12025", 1995, 2000000) + long_rows("12086", 2000, 2250000)
renamed = pu.apply_fips_crosswalk(pd.DataFrame(rows), crosswalk)
check("12025 gone", "12025" not in set(renamed["geoid"]))
dade = renamed[(renamed["geoid"] == "12086") & (renamed["year"] == 1995) &
               (renamed["agegrp"] == 0)]["population"].iloc[0]
check("Dade 1995 value preserved under 12086", dade == 2000000, f"got {dade}")

print("\n== split flags the parent's pre-change years ==")
rows = long_rows("08013", 1995, 250000) + long_rows("08013", 2005, 280000)
split = pu.apply_fips_crosswalk(pd.DataFrame(rows), crosswalk)
pre = split[(split["geoid"] == "08013") & (split["year"] == 1995)]
post = split[(split["geoid"] == "08013") & (split["year"] == 2005)]
check("Boulder 1995 flagged", pre[pu.POP_FLAG_COL].notna().all())
check("Boulder 1995 value retained", pre[pre["agegrp"] == 0]["population"].iloc[0] == 250000)
check("Boulder 2005 not flagged", post[pu.POP_FLAG_COL].isna().all())

print("\n== merge_split drops the dissolved county, flags targets ==")
rows = long_rows("30113", 1995, 52) + long_rows("30031", 1995, 60000)
ms = pu.apply_fips_crosswalk(pd.DataFrame(rows), crosswalk)
check("30113 dropped", "30113" not in set(ms["geoid"]))
check("Gallatin 1995 flagged as under-inclusive",
      ms[(ms["geoid"] == "30031") & (ms["year"] == 1995)][pu.POP_FLAG_COL].notna().all())
check("Gallatin value not inflated by the park",
      ms[(ms["geoid"] == "30031") & (ms["agegrp"] == 0)]["population"].iloc[0] == 60000)

print("\n== AGEGRP encoding guard ==")
good = pd.DataFrame(long_rows("09001", 2015, 900000))
try:
    pu.assert_agegrp_encoding(good, source_name="test")
    check("consistent encoding accepted", True)
except ValueError as exc:
    check("consistent encoding accepted", False, str(exc))

bad = good.copy()
bad.loc[bad["agegrp"] == 5, "population"] *= 3          # buckets no longer sum to total
try:
    pu.assert_agegrp_encoding(bad, source_name="test")
    check("shifted encoding rejected", False, "no exception raised")
except ValueError:
    check("shifted encoding rejected", True)

no_total = good[good["agegrp"] != 0]
try:
    pu.assert_agegrp_encoding(no_total, source_name="test")
    check("missing total row rejected", False, "no exception raised")
except ValueError as exc:
    check("missing total row rejected", "STCH-ICEN" in str(exc))

print("\n== age-code normalization: all three Census conventions ==")
# Codes as the 1990s endpoint actually returns them: 0 = under 1,
# 1 = 1-4, 2 = 5-9 ... 18 = 85+, no total row.
under_1, one_to_4 = 12_838, 51_000
stch = [{"geoid": "09001", "year": 1990, "agegrp": 0, "population": under_1},
        {"geoid": "09001", "year": 1990, "agegrp": 1, "population": one_to_4}]
stch += [{"geoid": "09001", "year": 1990, "agegrp": i, "population": 45_000}
         for i in range(2, 19)]
raw_total = under_1 + one_to_4 + 45_000 * 17

norm = pu.normalize_agegrp(pd.DataFrame(stch), source_name="stch")
check("total row synthesized", (norm["agegrp"] == 0).any())
synth = norm.loc[norm["agegrp"] == 0, "population"].iloc[0]
check("total = sum of ALL raw codes incl. under-1", synth == raw_total,
      f"got {synth} vs {raw_total}")
bucket_0_4 = norm.loc[norm["agegrp"] == 1, "population"].iloc[0]
check("under-1 folded into 0-4, not dropped", bucket_0_4 == under_1 + one_to_4,
      f"got {bucket_0_4}")
check("codes 2-18 unchanged",
      (norm[norm["agegrp"].between(2, 18)]["population"] == 45_000).all())
check("18 buckets plus a total", sorted(norm["agegrp"].unique()) == list(range(19)))
try:
    pu.assert_agegrp_encoding(norm, source_name="stch-normalized")
    check("normalized frame passes the encoding guard", True)
except ValueError as exc:
    check("normalized frame passes the encoding guard", False, str(exc)[:80])

# The guard must REJECT the raw form -- that is what caught this on 9/3.
try:
    pu.assert_agegrp_encoding(pd.DataFrame(stch), source_name="stch-raw")
    check("raw STCH-ICEN form is rejected", False, "no exception raised")
except ValueError:
    check("raw STCH-ICEN form is rejected", True)

# co-est00int: STCH-ICEN bins PLUS the total parked at code 99. Reading
# code 0 as the total here is what made the whole 2000s decade come out
# ~70x too small in the first full build.
co_est = list(stch) + [{"geoid": "09001", "year": 2005, "agegrp": 99,
                        "population": raw_total}]
co_est = [{**r, "year": 2005} for r in co_est]
enc = pu.detect_agegrp_encoding(pd.DataFrame(co_est), source_name="co-est")
check("code-99 total detected as stch_icen_99", enc == "stch_icen_99", f"got {enc}")
norm99 = pu.normalize_agegrp(pd.DataFrame(co_est), source_name="co-est")
check("code 99 dropped after use", 99 not in set(norm99.agegrp))
check("synthesized total matches the source's own 99 total",
      norm99.loc[norm99.agegrp == 0, "population"].iloc[0] == raw_total)
check("code 0 is NOT mistaken for the total",
      norm99.loc[norm99.agegrp == 0, "population"].iloc[0] != under_1)

# the standard cc-est shape must pass through untouched
std = [{"geoid": "17001", "year": 2015, "agegrp": 0, "population": 18 * 1000}]
std += [{"geoid": "17001", "year": 2015, "agegrp": i, "population": 1000} for i in range(1, 19)]
enc = pu.detect_agegrp_encoding(pd.DataFrame(std), source_name="cc-est")
check("cc-est shape detected as standard", enc == "standard", f"got {enc}")
passthru = pu.normalize_agegrp(pd.DataFrame(std), source_name="cc-est")
check("standard frame passes through unchanged", len(passthru) == len(std))

print("\n== age shares ==")
buckets = [10000] * 18
shares = pu.compute_age_shares(pd.DataFrame(long_rows("09001", 2015, 180000, buckets)))
check("one row per county-year", len(shares) == 1)
check("18 share columns", all(c in shares.columns for c in pu.AGE_SHARE_COLS))
row = shares.iloc[0]
check("shares sum to 1", abs(row[pu.AGE_SHARE_COLS].sum() - 1) < 1e-9)
check("equal buckets give equal shares", abs(row["pop_share_0_4"] - 1 / 18) < 1e-9)
check("total population retained", row["population"] == 180000)
check("no age flag when clean", pd.isna(row[pu.AGE_FLAG_COL]))

print("\n== age shares degrade without killing the total ==")
totals_only = pd.DataFrame([{"geoid": "09001", "year": 2023, "agegrp": 0, "population": 950000}])
degraded = pu.compute_age_shares(totals_only)
check("total kept", degraded.iloc[0]["population"] == 950000)
check("age flagged", pd.notna(degraded.iloc[0][pu.AGE_FLAG_COL]))
check("shares NA", degraded.iloc[0][pu.AGE_SHARE_COLS].isna().all())

print("\n== spine reindex ==")
universe = pd.DataFrame({
    "geoid": ["08013", "08014", "09001"],
    "state_fips": ["08", "08", "09"],
    "county_fips": ["013", "014", "001"],
    "county_name": ["Boulder", "Broomfield", "Fairfield"],
})
panel = pd.DataFrame([
    {"geoid": "08013", "year": 1995, "population": 250000},
    {"geoid": "08013", "year": 2005, "population": 280000},
    {"geoid": "08014", "year": 2005, "population": 50000},
    {"geoid": "09001", "year": 1995, "population": 800000},
    {"geoid": "09001", "year": 2005, "population": 900000},
])
spine = pu.reindex_to_county_universe(panel, universe, [1995, 2005], crosswalk)
check("3 counties x 2 years", len(spine) == 6, f"got {len(spine)}")
broom_1995 = spine[(spine["geoid"] == "08014") & (spine["year"] == 1995)].iloc[0]
check("Broomfield 1995 population is NaN", pd.isna(broom_1995["population"]))
check("Broomfield 1995 explained as a split, not a gap",
      "created 2001" in str(broom_1995[pu.POP_FLAG_COL]),
      f"got {broom_1995[pu.POP_FLAG_COL]!r}")

print("\n== output write, including .dta ==")
out = spine.copy()
for col in pu.AGE_SHARE_COLS:
    out[col] = 1 / 18
out["population_source"] = "test"
out["age_source"] = "test"
if pu.AGE_FLAG_COL not in out.columns:
    out[pu.AGE_FLAG_COL] = pd.NA

with tempfile.TemporaryDirectory() as tmp:
    csv_path = Path(tmp) / "p.csv"
    dta_path = Path(tmp) / "p.dta"
    pu.write_panel_outputs(out, csv_path, dta_path)
    check("csv written", csv_path.exists())
    check("dta written", dta_path.exists())

    back_csv = pd.read_csv(csv_path, dtype={"geoid": str})
    check("csv geoid keeps leading zero", back_csv["geoid"].iloc[0].startswith("0"),
          f"got {back_csv['geoid'].iloc[0]!r}")
    back_dta = pd.read_stata(dta_path)
    check("dta geoid is a 5-char string",
          isinstance(back_dta["geoid"].iloc[0], str) and len(back_dta["geoid"].iloc[0]) == 5,
          f"got {back_dta['geoid'].iloc[0]!r}")
    check("dta row count matches", len(back_dta) == len(out))

print("\n== cc-est YEAR code inference ==")
import importlib.util as _ilu

_s = _ilu.spec_from_file_location(
    "m08a_pre", Path(__file__).resolve().parent / "08a_population_county.py"
)
_m = _ilu.module_from_spec(_s)
sys.modules["m08a_pre"] = _m
_s.loader.exec_module(_m)

# The real cc-est2020int shape, from IL: codes 1-12 for an 11-year span.
# YEAR=1 is the 4/1/2010 base (IL 12,831,572 vs the 2010 census
# 12,830,632); YEAR=12 is 2020 (12,812,436 vs 12,812,508).
rule_2010s = _m.YEAR_CODE_RULES["cc-est2020int"]
mapped = rule_2010s.code_to_year(range(1, 13))
check("12 codes -> 11 years", len(mapped) == 11, f"got {len(mapped)}")
check("code 1 dropped as the base row", 1 not in mapped)
check("code 2 is 2010", mapped.get(2) == 2010, f"got {mapped.get(2)}")
check("code 12 is 2020", mapped.get(12) == 2020, f"got {mapped.get(12)}")

# Two leading rows (census + base) is also legal.
mapped13 = rule_2010s.code_to_year(range(1, 14))
check("13 codes -> drops 2, still ends at 2020",
      mapped13.get(3) == 2010 and mapped13.get(13) == 2020,
      f"got {mapped13.get(3)}, {mapped13.get(13)}")

# Too few codes for the span, and too many leading rows, both raise.
for label, codes in [("too few codes", range(1, 6)), ("too many leading rows", range(1, 17))]:
    try:
        rule_2010s.code_to_year(codes)
        check(f"{label} raises", False, "no exception")
    except ValueError:
        check(f"{label} raises", True)

print("\n== API YEAR: two-digit form, and Census's own junk cells ==")
api_cfg = [s for s in _m.SOURCES if s.fetch_fn == "fetch_intercensal_api"][0]


def api_frame(year_values, pops):
    return pd.DataFrame({
        "YEAR": year_values, "population": pops,
        "state": ["56"] * len(pops), "county": ["045"] * len(pops),
    })

clean = api_frame([str(y) for y in range(90, 100)], [1000] * 10)
got = _m._normalize_api_year(clean, api_cfg)
check("two-digit '90'-'99' -> 1990-1999",
      sorted(got["year"].unique()) == list(range(1990, 2000)))

# The real Wyoming row: YEAR='9', POP=0. Drop it, keep everything else.
with_junk = api_frame([str(y) for y in range(90, 100)] + ["9"], [1000] * 10 + [0])
got = _m._normalize_api_year(with_junk, api_cfg)
check("zero-population junk YEAR is dropped", len(got) == 10, f"got {len(got)}")
check("the other 10 years survive intact",
      sorted(got["year"].unique()) == list(range(1990, 2000)))

# Same junk value but carrying population -> must NOT be silently dropped.
with_real = api_frame([str(y) for y in range(90, 100)] + ["9"], [1000] * 11)
try:
    _m._normalize_api_year(with_real, api_cfg)
    check("unmappable YEAR carrying population raises", False, "no exception")
except RuntimeError:
    check("unmappable YEAR carrying population raises", True)

# A wholly shifted decade must still be fatal, not quietly dropped.
shifted = api_frame([str(y) for y in range(1, 11)], [1000] * 10)
try:
    _m._normalize_api_year(shifted, api_cfg)
    check("a fully shifted decade still raises", False, "no exception")
except RuntimeError:
    check("a fully shifted decade still raises", True)

print("\n== stack: priority resolution and the YEAR-offset backstop ==")
import importlib.util

_spec = importlib.util.spec_from_file_location(
    "m08a", Path(__file__).resolve().parent / "08a_population_county.py"
)
m08a = importlib.util.module_from_spec(_spec)
sys.modules["m08a"] = m08a
_spec.loader.exec_module(m08a)


# 20 counties with a realistic SPREAD of growth rates (0% to 9.5%/yr).
# Heterogeneity is the point: under a one-year shift each county moves by
# its own growth rate, so the upper tail separates a shift from a vintage
# revision. A fixture where every county grew at the same rate would make
# the two indistinguishable -- and would have quietly passed a check that
# cannot actually do its job on real data.
COUNTIES = [f"17{i:03d}" for i in range(1, 41, 2)]
GROWTH = {geoid: 1 + 0.005 * i for i, geoid in enumerate(COUNTIES)}
BASE_YEAR, BASE_POP = 2019, 100_000


def county_pop(geoid, year, *, year_offset=0):
    """Population of `geoid` in `year`; year_offset simulates a shifted YEAR code."""
    periods = (year + year_offset) - BASE_YEAR
    return int(BASE_POP * (GROWTH[geoid] ** periods))


def source_frame(name, years, priority, *, year_offset=0):
    rows = []
    for year in years:
        for geoid in COUNTIES:
            rows += long_rows(geoid, year, county_pop(geoid, year, year_offset=year_offset))
    df = pd.DataFrame(rows)
    df["state_fips"] = df["geoid"].str[:2]
    df["county_fips"] = df["geoid"].str[2:]
    df["county_name"] = "x"
    df["source"] = name
    df["is_intercensal"] = True
    cfg = m08a.PopulationSourceConfig(
        name=name, years=range(min(years), max(years) + 1),
        fetch_fn="", is_intercensal=True, priority=priority,
    )
    return cfg, df


# Aligned case: both sources agree on 2020.
frames = {
    "intercensal": source_frame("intercensal", [2019, 2020], priority=1),
    "postcensal": source_frame("postcensal", [2020, 2021, 2022], priority=2),
}
try:
    stacked = m08a.stack_sources(frames)
    check("aligned sources stack cleanly", True)
    n_2020 = stacked[(stacked["year"] == 2020)]["source"].unique()
    check("2020 resolved to the intercensal source", list(n_2020) == ["intercensal"],
          f"got {n_2020}")
    check("one row per county-year-agegrp",
          not stacked.duplicated(subset=["geoid", "year", "agegrp"]).any())
except Exception as exc:  # noqa: BLE001
    check("aligned sources stack cleanly", False, str(exc))

# A legitimate vintage revision: every county nudged by a small, broadly
# similar fraction. This must NOT trip the check, or the check is useless.
cfg_rev, df_rev = source_frame("postcensal", [2020, 2021, 2022], priority=2)
df_rev["population"] = (df_rev["population"] * 1.002).astype(int)
frames_revised = {
    "intercensal": source_frame("intercensal", [2019, 2020], priority=1),
    "postcensal": (cfg_rev, df_rev),
}
try:
    m08a.stack_sources(frames_revised)
    check("ordinary vintage revision does NOT trip the check", True)
except ValueError as exc:
    check("ordinary vintage revision does NOT trip the check", False, str(exc)[:90])

# Misaligned case: the postcensal source's YEAR codes are off by one, so
# what it labels 2020 is really 2021. This is exactly the failure mode the
# unconfirmed cc-est2025 offset would produce.
frames_bad = {
    "intercensal": source_frame("intercensal", [2019, 2020], priority=1),
    "postcensal": source_frame("postcensal", [2020, 2021, 2022], priority=2, year_offset=1),
}
try:
    m08a.stack_sources(frames_bad)
    check("one-year offset is caught", False, "no exception raised")
except ValueError as exc:
    check("one-year offset is caught", "continuity" in str(exc).lower(), str(exc)[:80])

print()
if FAILURES:
    print(f"{len(FAILURES)} FAILURE(S): {FAILURES}")
    sys.exit(1)
print("All logic tests passed.")
