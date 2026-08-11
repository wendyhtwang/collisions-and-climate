# codePYTHON script overview

Reference document for the PRISM/ERA5 weather-extraction pipeline.

Each script's opening docstring now carries a condensed version of this same
1-sentence-purpose + key-decisions format; this doc includes more detailed
explanations regarding decisions that were not included in the code itself.

Scripts are numbered in pipeline order: 
`01` = small-scale PRISM test, `02` = full-scale PRISM extraction (`b` suffix = WMA-polygon
variant). `05` = aggregation, `06` = derived vars
(not yet built), `07` = spot-checks, `08` = population data (not yet
built). `gee_extract_utils.py` = shared library (unnumbered).
`0X_verify_*_gee_console.js` = manual Earth Engine Console checks to verify 
small-scale test extractions

## Setup

### `00_setup_earth_engine.py`
Authenticates to Earth Engine and confirms the connection works.
- One-time/occasional sanity check, not part of the numbered pipeline. No
  data-handling decisions.

## PRISM extraction

### `01_test_prism_extract.py`
Small-scale PRISM extraction test (IL/IN, 2020-2021), used to validate the
extraction method before running it at full CONUS scale.
- Tests only 4 of PRISM's 7 bands and 2 states/2 years -- same states/years
  used by the ERA5 test script, so results are directly comparable.
- Kept in the repo as a fast sanity check to rerun whenever
  `gee_extract_utils.py` changes, before trusting a full-scale run.
- Output validated against manual Earth Engine Console calculations (see
  `01_verify_prism_gee_console.js`).

### `02_extract_prism_county.py`
Full-scale PRISM extraction for all CONUS counties, 1981-2025, all 7 PRISM
variables, at daily resolution.
- Extracts at **daily** resolution even though the end target is monthly:
  compositing images with `.sum()`/`.mean()` before reducing to county
  means was found to shift results ~1-2% from reducing each day
  independently (root cause not fully diagnosed). Monthly aggregation
  instead happens client-side in `05_aggregate_daily_to_monthly.py`, which
  is validated correct.
- One Drive export task per calendar year (~45 tasks). A local JSON
  manifest tracks completed years so a rerun skips them instead of
  resubmitting.
- Output destination is resolved from a candidate-path list (Kodama path
  first, personal dev repo fallback second), not hardcoded, so the same
  script works on either machine.

### `02b_extract_prism_wma.py` -- not yet implemented
Placeholder for extracting PRISM data by wildlife-management-area (WMA)
polygon, using Nicole's shapefiles, instead of by county. No code written
yet.

## ERA5 extraction

### `03_test_era5_extract.py`
Small-scale ERA5-Land extraction test (IL/IN, 2020-2021), used to validate
unit-conversion decisions before they're carried into the full-scale ERA5
script.
- Validates the same decisions listed below for `04` (dataset choice, unit
  conversions, wind speed) before they're carried into the full-scale
  script.
- Adds `tmin_c`/`tmax_c` as a test addition to check whether they're worth
  keeping (PRISM already covers tmin/tmax, so this may be redundant).
- Output validated against manual Earth Engine Console calculations (see
  `03_verify_era5_gee_console.js`).

### `04_extract_era5_county.py`
Full-scale ERA5-Land extraction for all CONUS counties, 1981-2025 --
mirrors `02_extract_prism_county.py`'s structure for the parallel weather
dataset.
- Uses `ECMWF/ERA5_LAND/DAILY_AGGR`, not plain `ERA5/DAILY`: only the
  -Land version has snowfall, snow depth, and skin temperature bands, at
  finer resolution (~11.1km vs ~28km).
- Converts temperature bands Kelvin->Celsius and precipitation/snowfall
  meters->mm **inline during extraction**, to match PRISM's Celsius/mm
  conventions. Wind speed is computed from u/v components since
  ERA5-Land has no direct wind-speed band. `surface_pressure` is left in
  native Pa.
- Adds `tmin_c`/`tmax_c` (daily extremes), which weren't in the original
  ERA5 variable list, after validating them in the small-scale test --
  worth confirming with the team whether this duplicates PRISM's own
  tmin/tmax.
- Shares `gee_extract_utils.py`'s resumability-manifest and
  shared-Drive-folder mechanics with the PRISM script.
- **Operational note:** a run in Aug 2026 was interrupted after 1981-2009
  completed but before the resumability manifest was written (the manifest
  only writes after every task reaches a terminal state). Recovered by
  manually trimming `YEARS` to the remaining range rather than rewriting
  the manifest from Earth Engine's task history -- confirmed via the GEE
  Tasks panel which years were actually done, and cancelled the
  still-pending tasks for that range before rerunning so it didn't
  resubmit duplicates. `YEARS` is back to the full 1981-2025 range now.

### `04b_extract_era5_wma.py` -- not yet implemented
Empty file. Placeholder for the ERA5 equivalent of `02b_extract_prism_wma.py`
(WMA-polygon extraction). No code written yet.

## Aggregation

### `05_aggregate_daily_to_monthly.py`
Aggregates the daily county-level PRISM CSVs into one county-year-month
panel (the final PRISM output): `ppt` summed to a monthly total, all other
variables averaged.
- `ppt` is summed; `tmean`, `tmin`, `tmax`, `tdmean`, `vpdmin`, `vpdmax` are
  averaged -- matches PRISM's own documented convention (PRISM's
  documentation notes monthly grids aren't a pure average of the dailies,
  since the monthlies use more stations than the dailies do).
- Flags (doesn't silently average over) any county-month mixing PRISM's
  AN81/AN91 vintages, which happens at the 2020/2021 boundary.
- Flags, and writes to a separate file, any county-month whose day count
  doesn't match the expected calendar days, rather than silently
  aggregating a partial month.
- Drops confirmed byte-identical duplicate rows automatically; raises an
  error instead if duplicate rows actually disagree in value, since that
  needs a human look. **See "Wisconsin county duplication"
  below** for the root cause.
- Reads one year/file at a time rather than loading all 45 years into
  memory at once (~9GB across all years).

### `06_build_derived_weather_vars.py` -- not yet implemented
Placeholder for computing derived weather variables (freeze-thaw days,
heating/cooling degree days) from the PRISM/ERA5 panels. No code written
yet.

## Spot-checks

### `07_export_prism_monthly_spotcheck.py`
Independently reproduces a small PRISM county-month panel directly in
Earth Engine, without using any of this repo's own extraction/aggregation
code, so it can be compared against the production panel as a check on the
production pipeline's logic.
- Deliberately avoids importing `gee_extract_utils.py` or reusing any
  production function, so a bug shared between the two wouldn't be
  invisible to this check.
- Reduces each daily image to county means first, then aggregates to
  monthly inside GEE -- matches production's order of operations (see the
  1-2% compositing discrepancy noted under `02`).
- Samples 8 explicit counties across 5 years (including the 2020/2021
  PRISM vintage boundary), not the full CONUS panel, to keep the check
  fast and its scope transparent/repeatable.
- Errors out if the source county collection contains more than one
  feature for a requested GEOID, rather than silently picking one (see WI
  duplication note below).

### `07b_compare_prism_monthly_spotcheck.py`
Compares the independent GEE panel from `07_export_prism_monthly_spotcheck.py`
against the production `prism_county_month.csv`, county-month by
county-month, within a numeric tolerance.
- Left-joins the small GEE sample onto production (not an outer join), so
  the comparison only touches the ~480 sampled rows rather than all ~1.7M
  production rows. (Originally used an outer join; switched because it
  kept every production row padded with NaN for no benefit -- the "missing
  from production" case is still caught via the join indicator.)
- A row passes only if its day count matches the calendar AND every
  variable is within tolerance (absolute or relative, whichever is looser)
  of production.
- Requires exactly one spot-check export file to be present before
  comparing, to avoid silently comparing against a stale prior run.
- Exits with a non-zero status (fails loudly) if any sampled county-month
  doesn't pass, rather than just printing a warning.
- **Result:** this GEE-reproduction approach was superseded by the
  ground-truth station comparison (`07c`-`07e`) as the check that actually
  passed and closed out the spot-check work (see git history / team
  discussion, 08.07.26).

### `07c_find_ground_truth_counties.py`
Identifies candidate CONUS counties served by only one (or very few) NOAA
weather stations, as candidates for a ground-truth spot check of PRISM
against real station data.
- Uses NOAA GHCN-Daily station density as a proxy for how many stations
  fed PRISM's interpolation for that county (PRISM's exact input station
  list isn't published, so this is an imperfect but reasonable stand-in).
- Requires a candidate station to report precipitation, max temp, and min
  temp for every one of the target years.
- Ranks candidates by land area ascending -- a smaller county means the
  one station covers more of it, a better ground-truth case.
- Excludes independent cities (e.g. Baltimore city, VA cities) even though
  they're legitimate Census county-equivalents: their qualifying stations
  are often literally water-treatment-plant or downtown sites (urban-heat-
  island microclimate effects), and a small city carved out of a
  well-instrumented metro area can look "isolated" by station count while
  actually sitting inside dense regional coverage -- a poor fit for the
  isolated-rural-county case actually wanted. This is a name/LSAD-code
  heuristic, not a guaranteed-correct classification, so candidates should
  still be reviewed by eye.
- Doesn't auto-pick a final county -- outputs a candidate list for manual
  review. No Earth Engine calls; needs real internet access, so run this
  locally (e.g. on Kodama), not from a network-restricted sandbox.

### `07d_aggregate_noaa_station_daily.py`
Aggregates downloaded NOAA station daily CSVs to station-year-month, in the
same style as the production PRISM aggregation, so they can be compared to
PRISM's county-month values.
- Derives station/year/month from the DATE column itself rather than
  trusting filenames, so input files can cover any date range. Each file
  must contain exactly one station.
- Matches production's aggregation convention: `ppt` is a monthly total,
  temperature variables are monthly means; `tmean` is computed per day as
  `(tmax+tmin)/2` before averaging, matching PRISM's own documented
  method.
- A missing daily reading is excluded from that variable's sum/mean (not
  treated as zero -- zero-filling a missing precip day would silently bias
  the total low); each variable's missing-day count is reported in its own
  column rather than silently dropped.
- Flags station-months whose day count doesn't match the calendar, same
  completeness check as production.

### `07e_filter_prism_ground_truth_sample.py`
Filters the production PRISM county-month panel down to the exact
county-year-month rows selected for the ground-truth station comparison.
- Pulls an explicit list of (geoid, year, month) triples rather than a
  cross-product of separate lists, so different counties can be checked
  against different periods.
- Reports (rather than silently drops) any requested row not found in
  production, distinguishing "GEOID not in production at all" from "GEOID
  exists, just not for that year/month."
- Does no aggregation or Earth Engine calls -- a pure row filter, so it
  can't introduce any of the independent-reimplementation concerns the
  07/07b scripts were built to avoid.

## Other data

### `08_population_data.py` -- not yet implemented
Placeholder for pulling county population data from Census/ICPSR (not a
Google Earth Engine extraction). No code written yet.

## Shared library

### `gee_extract_utils.py`
Shared library of Earth Engine extraction mechanics (auth, county
geometry, daily reduction, Drive export, progress monitoring,
resumability) used by both the PRISM and ERA5 extraction scripts, so
dataset-specific scripts only need to supply their own configuration.
- Deliberately dataset-agnostic: PRISM-/ERA5-specific logic (unit
  conversions, band lists) stays in the calling script, not here.
- CONUS scope (48 states + DC; excludes AK, HI, territories) is defined
  once here as the shared source of truth other scripts import.
- Cross-machine paths are resolved via a candidate-list pattern (try each
  path, use the first that exists, raise if none do) rather than
  hardcoding one machine's path -- mirrors the project's Stata style-guide
  convention.
- Resumability is a simple local JSON manifest of completed periods -- it
  doesn't check Drive/GCS directly, so the manifest and the actual
  exported files could in principle drift apart if a Drive file is
  deleted by hand.
- Progress monitoring surfaces EECU-seconds (compute time) per task, not
  just task state, since "RUNNING" alone doesn't show whether a job is
  stalled or making progress.
- **See "Drive folder duplication" below** for the shared-export-folder
  race-condition workaround (`start_exports_to_shared_folder()`).

## Manual verification (Earth Engine Console, not part of the pipeline)

### `01_verify_prism_gee_console.js`
Manually recomputes one county's PRISM daily and monthly values directly
in the Earth Engine Code Editor console, to check them against
`01_test_prism_extract.py` / `05_aggregate_daily_to_monthly.py`'s CSV
output. Reduces each day separately and aggregates in JS, mirroring the
Python pipeline's method (see the compositing discrepancy note under
`02`), rather than compositing the ImageCollection first.

### `03_verify_era5_gee_console.js`
Manually recomputes one county-day's ERA5-Land derived values directly in
the Earth Engine Code Editor console, to check them against
`03_test_era5_extract.py`'s CSV output. Unlike the PRISM console check,
this recomputes real conversion math (Kelvin->Celsius, wind speed from
u/v, meters->mm), so it's testing `add_derived_bands()`'s logic, not just
band selection.

---

## Known issues / decisions log

Fuller writeups of a few things that are referenced above but were too
long to keep inline in the code.

### Wisconsin county duplication (affects `05`, `07`)
18 WI counties (55001, 55003, 55005, 55007, 55023, 55041, 55065, 55067,
55085, 55095, 55113, 55119, 55121, 55123, 55125, 55129, 55135, 55137) had
every daily row duplicated, byte-for-byte identical, in both the 2020 and
2021 full-CONUS PRISM exports -- same 18 GEOIDs both years, so not a
random export glitch. Confirmed via an actual run on Kodama (2026-08-06):
the `TIGER/2018/Counties` FeatureCollection itself contains two separate
features for these GEOIDs (checked directly for 55001/55003), not a
downstream `reduceRegions`/`tileScale` artifact. Since extraction reduces
per feature, each duplicated GEOID gets the same PRISM value computed and
written twice. **Net effect: harmless** -- the values are identical, so
`05`'s automatic drop of byte-identical duplicates loses no information.
Not investigated further since this is treated as a routine, safety-net
case rather than something needing a fix at the extraction layer.

### Drive folder duplication (affects `gee_extract_utils.py`, `02`, `04`)
The 2020/2021 CONUS PRISM validation run created two separate Drive
folders both named "earth_engine_prism_full" instead of reusing one, even
though both years' export tasks used the exact same `drive_folder`
string. Root cause (confirmed via the earthengine-api's own
`Export.table.toDrive` docstring): the `folder` argument is a folder
*name* to look up or create, not a stable ID -- Drive permits multiple
folders with identical names, and two export tasks submitted back-to-back
against a not-yet-existing folder name can each independently decide it
doesn't exist yet and create their own copy. Fix: `gee_extract_utils.py`'s
`start_exports_to_shared_folder()` now submits the first export alone and
waits for it to leave the READY state (proxy for "the folder now exists")
before submitting the rest of a batch. This is a mitigation, not a
guarantee -- for full certainty, create the destination folder by hand in
Drive before the first run against a new folder name.

### ERA5 interrupted run / manifest gap (affects `04`)
`04_extract_era5_county.py` only writes its resumability manifest after
every submitted task reaches a terminal state, not incrementally. A run in
Aug 2026 had its terminal closed before all 45 tasks finished (1981-2009
had completed; 2010-2025 were still running/queued), so the manifest was
never written even though most of the work had succeeded. Recovered
manually: confirmed completed years via checkmarks in the GEE Tasks panel,
cancelled the still-pending 2010-2025 tasks so a rerun wouldn't submit
duplicates alongside them, and temporarily trimmed `YEARS` to just the
remaining range for the rerun. `YEARS` has since been reverted to the full
1981-2025 range. (A `rebuild_era5_manifest_from_tasks.py` utility was
written to automate this reconciliation but was ultimately not needed and
was removed from the repo, since GEE tasks run server-side independent of
the local machine and the manual fix above was sufficient.)

### PRISM daily-vs-composited aggregation discrepancy (affects `02`, `04`, `07`)
Compositing a PRISM `ImageCollection` with `.sum()`/`.mean()` and then
reducing once to county means gives values ~1-2% off from reducing each
day independently and then summing/averaging the per-day results, even
though the two approaches look mathematically equivalent (both operations
are linear). Most likely explanation: `ImageCollection.sum()`/`.mean()`
don't reliably preserve the exact per-image pixel grid each day's own
`reduceRegion()` call used, so the composite gets reduced over a subtly
different/resampled lattice. Root cause not fully diagnosed. Until it is,
every script in this pipeline (extraction, the GEE spot-check, and the
manual console checks) reduces day-by-day and aggregates afterward, never
composite-then-reduce.

### GEE spot-check vs. ground-truth spot-check
Two different verification strategies exist in this repo: `07`/`07b`
independently reproduce PRISM values in Earth Engine and compare them to
production (a check on the pipeline's *processing* logic, since both
sides derive from the same PRISM source). `07c`-`07e` instead compare
production against real NOAA weather station readings (a check against an
independent ground truth). The station-based comparison is the one that
was carried through to a "passed" result; the GEE-reproduction approach
was the first strategy tried and remains in the repo as a still-useful,
independent check on processing logic, even though it wasn't the one that
closed out the verification work.
