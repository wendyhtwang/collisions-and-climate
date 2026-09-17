# codePYTHON script overview

Reference document for the PRISM/ERA5 weather-extraction pipeline.

Each script's opening docstring now carries a condensed version of this same
1-sentence-purpose + key-decisions format; this doc includes more detailed
explanations regarding decisions that were not included in the code itself.

Scripts are numbered in pipeline order. A **bare number** is the sole or the
primary script at that step (`05` = aggregation, `06` = derived vars, `09` =
the descriptives notebook). A **letter suffix** marks a sibling at the same
step.

An earlier version of this key claimed "the first script gets `a`, never a
bare number". That has not been true since `06b` landed on 2026-09-09, and
`05` and `09` are bare too. The rule above is what the tree actually follows.

The more useful thing to know is that the `b` suffix encodes **four different
relationships**, so it does not by itself tell you what a `b` script does:

| Relationship | Examples | What the `b` script is |
|---|---|---|
| Manual verification | `01b`, `03b` | A `.js` Earth Engine Console check of the matching `a` script's output |
| Geographic variant | `02b`, `04b` | The same extraction against WMA polygons instead of counties (both unimplemented) |
| Output validation | `06b` | A check ON `06`'s output, run after it |
| Genuine second stage | `08b`, `09b` | A later step that consumes the `a` script's output |

The rest of the numbering: `01a` = small-scale PRISM test, `02a` = full-scale
PRISM extraction. `03a`/`04a` are the ERA5 counterparts. `05` = aggregation,
`06` = derived vars, `06c` = the winter severity index, `07a`-`07h` =
spot-checks, `08a`/`08b` = population data (`08a` = CT-specific town-level
reaggregation, `08b` = general county-level pull -- see "Other data" below for
why CT needed its own script rather than another `08b` source config),
`09`/`09a`/`09b` = the descriptive exhibits. Unnumbered `*_utils.py` files are
shared libraries.

**Seven scripts are what `codeSTATA/_project_main.do` actually runs:** `05`,
`06`, `06c`, `08a`, `08b`, `09a`, `09b`. Everything else is a test, a
spot-check, or a one-off, run by hand.

## Setup

### `00_setup_earth_engine.py`
Authenticates to Earth Engine and confirms the connection works.
- One-time/occasional sanity check, not part of the numbered pipeline. No
  data-handling decisions.

## PRISM extraction

### `01a_test_prism_extract.py`
Small-scale PRISM extraction test (IL/IN, 2020-2021), used to validate the
extraction method before running it at full CONUS scale.
- Tests only 4 of PRISM's 7 bands and 2 states/2 years -- same states/years
  used by the ERA5 test script, so results are directly comparable.
- Kept in the repo as a fast sanity check to rerun whenever
  `gee_extract_utils.py` changes, before trusting a full-scale run.
- Output validated against manual Earth Engine Console calculations (see
  `01b_verify_prism_gee_console.js`).

### `02a_extract_prism_county.py`
Full-scale PRISM extraction for all CONUS counties, 1981-2025, all 7 PRISM
variables, at daily resolution.
- Extracts at **daily** resolution even though the end target is monthly:
  compositing images with `.sum()`/`.mean()` before reducing to county
  means was found to shift results ~1-2% from reducing each day
  independently (root cause not fully diagnosed). Monthly aggregation
  instead happens client-side in `05_aggregate_daily_to_monthly.py`, which
  is validated correct.
- One Drive export task per calendar year (~45 tasks). A local JSON
  manifest tracks completed years, updated as each task finishes, so a
  rerun skips them instead of resubmitting.
- Output destination is resolved from a candidate-path list (Kodama path
  first, personal dev repo fallback second), not hardcoded, so the same
  script works on either machine.

### `02b_extract_prism_wma.py` -- not yet implemented
Placeholder for extracting PRISM data by wildlife-management-area (WMA)
polygon, using Nicole's shapefiles, instead of by county. No code written
yet.

## ERA5 extraction

### `03a_test_era5_extract.py`
Small-scale ERA5-Land extraction test (IL/IN, 2020-2021), used to validate
unit-conversion decisions before they're carried into the full-scale ERA5
script.
- Validates the same decisions listed below for `04a` (dataset choice, unit
  conversions, wind speed) before they're carried into the full-scale
  script.
- Adds `tmin_c`/`tmax_c` as a test addition to check whether they're worth
  keeping. PRISM already covers tmin/tmax, but PRISM is the main weather
  dataset and ERA5 exists as a robustness check against it, so ERA5 needs
  its own tmin/tmax for that comparison -- not redundant.
- Output validated against manual Earth Engine Console calculations (see
  `03b_verify_era5_gee_console.js`).

### `04a_extract_era5_county.py`
Full-scale ERA5-Land extraction for all CONUS counties, 1981-2025 --
mirrors `02a_extract_prism_county.py`'s structure for the parallel weather
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
  ERA5 variable list, after validating them in the small-scale test.
  PRISM already covers tmin/tmax, but since PRISM is the main weather
  dataset and ERA5 exists as a robustness check against it, ERA5 needs
  its own tmin/tmax for that comparison -- not redundant.
- Shares `gee_extract_utils.py`'s resumability-manifest (written
  incrementally as each task completes) and shared-Drive-folder mechanics
  with the PRISM script.

### `04b_extract_era5_wma.py` -- not yet implemented
Empty file. Placeholder for the ERA5 equivalent of `02b_extract_prism_wma.py`
(WMA-polygon extraction). No code written yet.

## Aggregation

### `05_aggregate_daily_to_monthly.py`
Aggregates the daily county-level PRISM and ERA5-Land CSVs into
county-year-month panels for both datasets -- one script parameterized by
a per-dataset `DatasetConfig` (same pattern as `06`), since the two
datasets' aggregation logic is identical and only the column
names/sum-vs-mean lists differ.
- PRISM: `ppt` is summed, `tmean`/`tmin`/`tmax`/`tdmean`/`vpdmin`/`vpdmax`
  are averaged -- matches PRISM's own documented convention (PRISM's
  documentation notes monthly grids aren't a pure average of the dailies,
  since the monthlies use more stations than the dailies do).
- ERA5: `precip_mm`/`snowfall_mm` are summed, everything else (temps,
  wind speed, `snow_depth`, `surface_pressure`) is averaged --
  `snow_depth` is a stock (snow currently on the ground), not a flux, so
  a mean is the meaningful summary, not a sum.
- PRISM-only: flags (doesn't silently average over) any county-month
  mixing PRISM's AN81/AN91 vintages, which happens at the 2020/2021
  boundary. No such vintage flag for ERA5-Land, which is a single
  reanalysis product with no vintage boundary in this period.
- Flags, and writes to a separate file, any county-month whose day count
  doesn't match the expected calendar days, rather than silently
  aggregating a partial month.
- Drops confirmed byte-identical duplicate rows automatically (confirmed
  to affect both datasets, since they draw counties from the same TIGER
  source); raises an error instead if any non-key column disagrees within
  a geoid/date group, since that needs a human look. **See "Wisconsin
  county duplication" below** for the root cause and "Duplicate-conflict
  detection fix" for the check itself.
- Reads one year/file at a time per dataset rather than loading all 45
  years into memory at once (~9GB across all years).
- File discovery, year-conflict checking, duplicate-row resolution, and
  the completeness check are shared with `06` -- see `aggregation_utils.py`.

### `06_build_derived_weather_vars.py`
Computes derived weather variables (per Phase 3 of the task doc) from the
raw daily PRISM/ERA5 county extracts -- one script for both datasets,
same `DatasetConfig` pattern as `05`, since the derivation logic is
identical and only the column names/units differ.
- Reads the same raw daily extracts as `05` directly (not `05`'s own
  monthly output), so `mean_temp_c` here can be cross-checked against
  `05`'s `tmean_mean`/`tmean_c_mean` as an independent consistency
  check.
- Derived variables: `days_extremely_cold` (daily TMIN <= 0F/-17.8C -- deer
  metabolic-stress threshold, lagged population-prediction instrument, and
  the WSI's cold-stress component), `days_below_freezing_32f` (daily
  TMIN < 32F/0C -- contemporaneous road-conditions covariate; resolved as a
  separate variable from `days_extremely_cold` at the 2026-08-14 team
  meeting, since the two serve different purposes and use different
  thresholds), `freeze_thaw_days`
  (daily TMIN < 0C AND TMAX > 0C),
  `mean_temp_c`, `tmean_variance_c2`/`tmin_variance_c2`/`tmax_variance_c2`
  (sample variance, ddof=1, on daily mean/min/max temp)
  `days_precip_above_10mm` (threshold configurable via
  `PRECIP_THRESHOLD_MM` -- task doc's example value),
  `heating_degree_days`/`cooling_degree_days` (base 65F/18.33C, per
  NOAA's degree-day definition), and ERA5-only `total_snowfall_mm` (summed)
  /`mean_snow_depth` (averaged, since it's a stock not a flux, native
  ERA5-Land meters -- same reasoning as `05`'s `snow_depth_mean`)
  /`days_snow_depth_18in`, `days_snow_depth_12in`, `days_snow_depth_8in`
  (see "Snow-depth day counts" below).
- **Two comparison operators differ deliberately.** `days_extremely_cold`
  and the snow-depth counts are INCLUSIVE (`<=` / `>=`) because they are
  the two components of the Kohn (1975) winter severity index, which is
  defined on "a minimum temperature of 0F or below" and "18 or more inches
  of snow on the ground". `days_below_freezing_32f` stays STRICT (`<`):
  it is the standard definition of a below-freezing day and is not part of
  the WSI. `days_extremely_cold` was changed from `<` to `<=` on
  2026-09-08; on the 1981 and 2025 extracts this moves zero county-days
  (no daily TMIN lands exactly on -17.7778C), so it is a definitional
  correction rather than a numbers-changing one.

#### Snow-depth day counts (ERA5-only, added 2026-09-08)
`days_snow_depth_18in` is the snow-hazard component of the winter severity
index, consumed by `codeSTATA/build_main_data_county_year.do` (SECTION 7)
as `wsi_snow_days`. 18in is the literature threshold (Kohn 1975 / WI DNR).
- Thresholds live in `SNOW_DEPTH_THRESHOLDS_IN = (18, 12, 8)`; adding a
  value there produces a matching `days_snow_depth_<N>in` column with no
  other change. The Stata side picks up 18/12/8 specifically.
- Units: ERA5-Land's `snow_depth` band is snow thickness on the ground in
  METRES -- not the separate `snow_depth_water_equivalent` band -- so the
  conversion is a straight `1in = 0.0254m` (18in = 0.4572m). PRISM has no
  snow variable, so these are ERA5-only (`has_snow`).
- A day COUNT is required, not a monthly mean: a month can average under
  18in while still containing qualifying days, and vice versa. Both are
  produced (`mean_snow_depth` alongside the counts).
- **12in and 8in are sensitivity variants, not competing definitions.**
  Kohn's 18in cutoff was calibrated on point station/snow-course
  observations, whereas `snow_depth` here is an ERA5-Land grid-box average
  averaged again over a whole county, and that spatial averaging strips out
  the local maxima an 18in cutoff is meant to catch. On the 1981 extract
  (winter 1980-81): Wisconsin recorded 8 county-days at >=18in statewide
  (all Vilas County), and Minnesota, Iowa, Illinois and Pennsylvania
  recorded none; most CONUS >=18in county-days fell in WY/WA/ID/MT mountain
  counties rather than the Great Lakes deer range the index was written
  for. Expect `winter_severity_index` to be driven almost entirely by its
  cold component across most of the study area -- the lower cuts exist so
  that can be shown in a robustness table.
- Missing readings compare False and so contribute 0 to a count, matching
  the temperature day counts. County 25019 (Nantucket, MA) has no
  ERA5-Land snow readings at all, so its counts are 0 rather than missing
  while its `mean_snow_depth` is missing -- worth remembering before
  reading a Nantucket WSI of 0 as a mild winter.
- Same completeness check and WI-county duplicate-row handling (per-column,
  see "Duplicate-conflict detection fix" below) as `05`.


### `06b_validate_ppt_total.py`
Cross-checks `06`'s monthly precipitation total against `05`'s, county-month
for county-month, and exits non-zero on any mismatch.
- Exists because `06` and `05` compute the same quantity from the same daily
  extracts by different routes; if they ever disagree, one of the two
  aggregations has drifted.
- `--dataset` defaults to `PRISM`, so a bare run checks **half** of what the
  script exists to check. Pass `--dataset PRISM --dataset ERA5` for both.
- NOT wired into `_project_main.do`, and should not be without changing its
  failure mode first: `sys.exit(1)` inside Stata's embedded interpreter raises
  `SystemExit`, which surfaces as a Stata error and halts the master script.
  The same applies to `07b`.

### `06c_build_winter_severity.py` -- added 2026-09-17
Builds the Winter Severity Index at county-**winter-year** grain from the two
`*_derived_weather_vars.csv` files `06` writes. Output:
`dataCSV/Weather/winter_severity_county_year.csv`.
- **Why it exists.** Until 2026-09-17 the index was built in SECTION 7 of
  `codeSTATA/build_main_data_county_year.do` and then READ BACK by `09b`. That
  made a Phase 4 exhibit depend on a Phase 6 output: on a clean end-to-end run
  the merged `.dta` did not exist yet, so `09b` skipped the two WSI exhibits
  and `10_generate_weather_report.do` silently produced a report one section
  short. The index is pure weather, so it belongs upstream of both consumers.
- Definition ported unchanged from SECTION 7 -- Kohn (1975) / WI DNR:
  `wsi_cold_days + wsi_snow_days`, each a count of qualifying days over
  Dec 1 - Apr 30. A day meeting both conditions counts in both tallies, which
  is the literature's "adds 2 points" rule.
- Winter year `t` spans Dec(`t-1`) through Apr(`t`). This is WIDER than the
  3-month DJF window `mean_winter_temp` uses; that variable, and
  `warm_winter_1sd`/`_2sd`, stay in the merge because `09b` recomputes them
  rather than reading them.
- Missing propagates, matching Stata's `gen`: any of the five months absent
  makes the season NaN, not a partial sum. So year `t` is NaN wherever
  December of `t-1` is out of panel -- including the panel's first year,
  exactly as `L1.` produced.
- Separate script rather than part of `06` because the grain differs:
  `06` is county-month, this is county-winter-year.
- Not tested against the local `dataCSV`: the Mac's
  `prism_derived_weather_vars.csv` is the 2020-2021 test slice and predates
  `days_extremely_cold`, and there is no local ERA5 derived file. It was
  verified on synthetic fixtures covering the four behaviours above, then
  against Kodama's panel.

## Spot-checks

### `07a_export_prism_monthly_spotcheck.py`
Independently reproduces a small PRISM county-month panel directly in
Earth Engine, without using any of this repo's own extraction/aggregation
code, so it can be compared against the production panel as a check on the
production pipeline's logic.
- Deliberately avoids importing `gee_extract_utils.py` or reusing any
  production function, so a bug shared between the two wouldn't be
  invisible to this check.
- Reduces each daily image to county means first, then aggregates to
  monthly inside GEE -- matches production's order of operations (see the
  1-2% compositing discrepancy noted under `02a`).
- Samples 8 explicit counties across 5 years (including the 2020/2021
  PRISM vintage boundary), not the full CONUS panel, to keep the check
  fast and its scope transparent/repeatable.
- Errors out if the source county collection contains more than one
  feature for a requested GEOID, rather than silently picking one (see WI
  duplication note below).

### `07b_compare_prism_monthly_spotcheck.py`
Compares the independent GEE panel from `07a_export_prism_monthly_spotcheck.py`
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
  passed and closed out the spot-check work.

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
  isolated-rural-county case actually wanted.
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
  07a/07b scripts were built to avoid.

### `07f_extract_era5_ground_truth_points.py`
Parses independently-downloaded ERA5-Land hourly GRIB files (pulled
directly from the Copernicus CDS, not GEE) for the ground-truth stations,
and aggregates each to an "ERA5-at-point" county-year-month value -- the
ERA5 counterpart to PRISM's Data Explorer point lookup.
- Independent of GEE and this repo's own extraction code: downloaded
  straight from the CDS, so a bug shared with production wouldn't be
  invisible to this check.
- Uses `cfgrib.open_datasets()` (plural): ERA5-Land hourly downloads
  bundle variables across incompatible GRIB groups (accumulated fields,
  skin temperature, and snow depth each land in their own group) that
  `open_dataset()` (singular) can't merge.
- Precip/snowfall are ERA5's "accumulated since reference time" fields --
  each day's total is the last available step of that day's own 24-step
  block, not a diff of consecutive hours. The last day of a requested
  month is often missing its final step (falls outside the requested
  range); that row is flagged (`n_days_flagged`) rather than silently
  under-counted.
- tmin/tmax/tmean and wind speed follow production's exact order of
  operations (`04a`'s `add_derived_bands()`): temperatures are the day's
  min/mean/max of 24 hourly readings; wind speed comes from the daily
  mean u/v components, not the mean of hourly speeds.
- Grid-cell selection uses nearest-neighbor with an explicit distance
  check, and falls back to the nearest unmasked cell if the closest one
  is land-sea-masked (see "ERA5-Land land-sea masking" below), flagging
  the row (`used_fallback_grid_cell`) rather than returning all-NaN.

### `07g_filter_era5_ground_truth_sample.py`
Filters the production ERA5 county-month panel down to the exact
county-year-month rows selected for the ground-truth comparison -- the
ERA5 counterpart to `07e`.
- Reuses the same three county-year-months already vetted for the PRISM
  ground-truth check (Blackford County, IN 2021-12; Chowan County, NC
  2000-01; Moore County, TN 1999-06) rather than re-running `07c`: the
  station-density selection logic is dataset-agnostic, and reusing the
  same sites gives a direct PRISM-vs-ERA5-vs-station comparison at
  identical locations.
- Keeps its `GROUND_TRUTH_CASES` list in sync by hand with `07f` and
  `07h` -- same convention this repo uses elsewhere for values that must
  match across scripts (e.g. `SCALE_METERS` between an extraction script
  and its console-verification counterpart).
- Does no aggregation or Earth Engine calls -- a pure row filter, same as
  `07e`.
- Reports (rather than silently drops) any requested row not found in
  production, same "GEOID missing entirely" vs. "GEOID exists, wrong
  year/month" distinction as `07e`.

### `07h_compare_era5_ground_truth.py`
Builds the three-way ground-truth decomposition for ERA5 -- joining real
NOAA station readings, the independently-extracted ERA5-at-point values
(`07f`), and the production ERA5 county-month panel (`07g`) -- the ERA5
counterpart to the manually-built `ground_truth_spotcheck_summary.xlsx`
used for PRISM.
- Same two-step decomposition as the PRISM version: (a) station vs.
  ERA5-at-point isolates ERA5-Land's own model behavior at that point;
  (b) ERA5-at-point vs. production county-mean isolates the effect of our
  own extraction/aggregation code. Step (a)'s interpretation differs from
  PRISM's, though: ERA5-Land doesn't directly assimilate station
  observations, so that gap reflects model/representativeness error, not
  a station-interpolation algorithm's behavior -- a bigger gap here isn't
  itself a red flag.
- Reuses `07d`'s NOAA station-month values as-is (dataset-agnostic, real
  station data); searches a short list of candidate paths since that file
  may only exist wherever `07d` was actually run (e.g. Kodama), not on
  every dev copy of this repo.
- No fixed pass/fail tolerance, matching the PRISM methodology: leaves a
  blank `notes` column for the same kind of human interpretation the
  PRISM summary used, rather than automating that judgment call.

## Other data

### `08a_population_ct_towns.py` -- implemented 2026-09-03
Reconstructs CT county-year population under the 8 legacy counties
(09001-09015, matching the weather panel's `TIGER/2018/Counties`) by
pulling town-level population and aggregating up via a static, pre-2022
town->county mapping.
- Why its own script rather than a branch inside 08b: Census's Vintage
  2022 population estimates (released 2023) switched CT to 9 planning
  regions (09110-09190), which do not nest inside the 8 legacy counties
  -- no clean region->county crosswalk exists. But CT's counties were
  never an operating government unit; both schemes are just different
  aggregations of the same 169 towns, whose identity has been stable
  throughout. Going through towns sidesteps the non-nesting problem, but
  it's a genuinely different fetch method (different source, different
  crosswalk, different aggregation step) from anything else in 08b --
  same reasoning as the PRISM/ERA5 `_county`/`_wma` split.
- SCOPE NARROWED 2026-09-03 from the original 45-year design, then WIDENED
  2026-09-04: production is **2021-2025, 40 rows**. The original 2022-2025
  scoping was right about the geography and wrong about the file -- Vintage
  2025 (`cc-est2025`) reports planning regions for EVERY year it covers,
  2020-2025, not just from the 2022 effective date, so 2021 fell through as
  8 missing county-years in the first full build.
- Validation years are **2015 and 2018** (2021 moved to production), where
  Census still published legacy counties so the two methods can be compared
  (`cross_check_against_direct_county_pull`). Two years validate a static
  mapping as well as forty would.
- TOTALS ONLY, no age. Census publishes sub-county population as totals
  in every vintage and CT DPH's town-level age data is not annual, so CT
  age shares are unavailable for 2021-2025. Those 40 county-years are
  flagged missing by 08b deliberately and should not be modelled down.
- The town->county mapping comes from a 2018 Gazetteer county-subdivision
  file, joined on COUSUB FIPS rather than town name -- name matching
  between sources is the predictable failure mode here.
- THIS DESIGN IS NOT RATIFIED BY THE PI. Eyal was asked about CT on
  9/1/26 and the answer that came back was about the Dorn PDF and the
  1980s; the CT question itself was never resolved.
- Collision data (Charvi's CT pipeline) was checked separately and
  confirmed to already key to the legacy 8 counties throughout
  1995-2025 -- no fix needed there. This script exists solely because
  Census's own population product, not anything else in the project,
  changed vintage in 2022. See project memory: county-geometry-vintage.

### `08b_population_county.py` -- implemented 2026-09-03, built 2026-09-04
Builds the county-year population panel 1981-2025 (CONUS + DC) from
Census sources: total resident population plus 18 five-year age shares,
keyed to `TIGER/2018/Counties` FIPS. Not an Earth Engine extraction.
- Scope includes AGE SHARES as of Eyal's 9/1/26 guidance (total
  population "all ages, all sexes at birth", plus population share in
  each standard bucket 0-4 ... 85+, as time-varying regression
  controls). Sex and race are collapsed, never broken out. The earlier
  "population only, no demographics" scope is superseded.
- Five stages, in this order, each with a rule about what it must not do:
  fetch (never recodes geography) -> stack (never dedupes silently) ->
  crosswalk (the only stage that changes a geoid; never fabricates) ->
  CT override (never crosswalked twice) -> validate (never mutates).
- Source map, verified 2026-09-03 against census.gov: 1981-89 PE-02 flat
  file; 1990-99 Census intercensal API (`int_charagegroups`); 2000-09
  CO-EST00INT; 2010-20 CC-EST2020INT; 2020-25 CC-EST2025. Everything
  except 2020-25 is intercensal (final, reconciled to the decennial
  count at both ends of its decade); 2020-25 is postcensal and
  provisional because the 2030 census has not yet anchored it. One
  vintage per period, never spliced mid-decade.
- 2020 comes from the 2010-2020 intercensal, not the postcensal file --
  that product reconciles through the 4/1/2020 census itself. The
  postcensal source still FETCHES 2020 so `assert_period_continuity` has
  an overlap year where two independent sources can be compared.
- County FIPS are not stable 1981-2025. Handled via a static crosswalk
  (`dataCSV/Population/fips_crosswalk_1980_2025.csv`, 10 verified rows)
  and `population_utils.apply_fips_crosswalk`.
- Does NOT fetch Connecticut for the affected years -- see `08a`.
- ALL ENCODINGS NOW VERIFIED against decennial counts (9/3-9/4/26).
  `AGEGRP` means three different things across the five products, and
  `YEAR` is a code whose layout differs per file -- `co-est00int` even
  carries a census row in the MIDDLE of its sequence. Nothing is assumed:
  `detect_agegrp_encoding` works the convention out from the data, every
  source is normalized and then re-verified, and `YEAR_CODE_RULES` takes
  an explicit map where inference can't work. See project memory
  (census-encoding-traps) for the full table and the evidence.
- BUILT: `population_county_year_1990_2025.{csv,dta}`, 111,888 rows =
  3,108 counties x 36 years. National totals track the decennial counts
  at 1990/2000/2010/2020 to within the Alaska+Hawaii exclusion plus the
  July-vs-April offset; 2020 is essentially exact.
- `validate_panel` checks MAGNITUDE as well as shape. Row counts, dtypes,
  uniqueness and key coverage all passed on an early build whose 2000s
  decade was 70x wrong, so the panel is also asserted to sit in a
  plausible national range with annualized change under 3%/yr.
- `fetch_pe02_1980s` was IMPLEMENTED 2026-09-08 (it previously raised
  `NotImplementedError` after its download step, because the PE-02 sheet
  layout could not be inspected). Layout confirmed against `pe-02-1985.xls`:
  one sheet per file named after the state, 3,141 counties x 6 race/sex rows
  = 18,846 data rows, collapsed to county totals. Other years assumed to
  share the layout.
- BUILT 2026-09-09 on Kodama: `population_county_year_1981_2025.{csv,dta}`,
  the panel `build_main_data_county_year.do` SECTION 3 now reads. Kodama
  holds both this and the older 1990-2025 pair side by side; **1981-2025 is
  canonical**. The Mac's `dataCSV/Population` has only the 1990-2025 vintage.
- Subset flags for small test runs before a full build:
  `--years`, `--states`, `--probe-api`, `--skip-ct`.

## Descriptive exhibits

### `09_descriptive_weather_full.ipynb`
The SOURCE for the two descriptive scripts. Edit this, never `09a`/`09b`.
- The notebook is the working surface: exhibits are judged by eye, and that
  iteration belongs in a notebook. `09a`/`09b` exist so `_project_main.do` can
  run the same code non-interactively.
- `_full` is a leftover disambiguator from a `09_descriptive_weather.ipynb`
  that no longer exists. Nothing is "partial"; the suffix no longer
  distinguishes anything.
- Page-geometry limits on the figures are strict and easy to break silently --
  see the `bbox_inches="tight"` trap in project memory
  (notebook-figure-page-constraints) before changing any figure size.

### `make_scripts.py`
Generates `09a`, `09b` and `weather_descriptives_utils.py` from the notebook.
- Run it after every notebook edit. Nothing enforces that the three generated
  files are newer than the `.ipynb`, so a stale pair is possible and silent.
- `split_module()` sorts top-level statements into definitions (which go to the
  shared module) and body work (which gets indented into `build_panel()`). A
  bare string expression counts as body work -- which is why the generated
  module's "do not edit by hand" banner used to end up buried inside
  `build_panel()`. Fixed 2026-09-17 by prepending `HEADER` after assembly
  rather than passing it through. Keep it that way.
- `NB` defaults to a bare relative path, so it only resolves when cwd is
  `codePYTHON/`.

### `_nb_patch.py`
Cell-targeted notebook editing, addressed by heading text because cell indices
shift. Hand-driven; imported by nothing.
- Written for the v2 exhibit revision (shipped 2026-09-11). Finished-purpose
  tool, kept because the next structural notebook edit will want it.

### `09a_descriptive_weather_tier1.py` -- GENERATED
Tier 1: internal QA and exploratory exhibits. Coverage integrity, per-county
and per-state sanity checks, QA findings. Written to `tables/weather/tier1/`
and `figures/weather/tier1/`.
- Internal only. These are the "eyeball it and say, okay, this checks out"
  exhibits; no outside reader ever sees them.
- Straight-line module code with no `__main__` guard, deliberately: Stata's
  `python script` runs a file top to bottom. The cost is that it cannot be
  imported without running everything.

### `09b_descriptive_weather_tier2.py` -- GENERATED
Tier 2: the polished exhibit set that `codeSTATA/10_generate_weather_report.do`
knits into the dated PI report. Written to `tables/weather/tier2/` and
`figures/weather/tier2/`.
- Must run before `10`, which asserts every exhibit it expects exists.
- Since 2026-09-17 it no longer reads the merged `.dta`: the two Winter
  Severity Index exhibits read `06c`'s CSV. That removed the one place where a
  Phase 4 output depended on a Phase 6 input.
- One output is named `*_tier2_decisions_for_eyal.csv` -- a PI's first name
  baked into a shipped filename. Harmless internally, worth renaming if these
  ever leave the project.

## Shared library

### `aggregation_utils.py`
Shared helpers for the aggregation stage (`05`, `06`, `06c`, `07d`):
`discover_input_files`, `load_daily_extract`, `flag_incomplete_months`,
`check_for_year_conflicts`, `resolve_data_root`, `resolve_duplicate_rows`.
- The aggregation stage's counterpart to `gee_extract_utils.py`'s role in the
  extraction stage: the QA rules live here once, so `05` and `06` cannot drift
  into two different definitions of "incomplete month" or two different
  duplicate policies.
- Duplicate policy: drop if identical, error if any non-key column disagrees.
  Never silently pick one.

### `era5_extract_utils.py`
ERA5-Land-specific extraction logic shared by `03a` and `04a`: unit conversions
(K->C, m->mm) and derived-band computation (`add_derived_bands`).
- Deliberately ERA5-specific, unlike `gee_extract_utils.py` which is
  dataset-agnostic. `03a` exists to validate exactly this logic at small scale
  before `04a` runs it across CONUS, so the two must share the code rather than
  keep two copies.

### `ground_truth_utils.py`
Row-filtering helpers shared by `07e` and `07g`, which pull the same
county-year-months out of the PRISM and ERA5 panels for the ground-truth
comparison.
- NOTE: the case lists themselves are NOT shared. `07f`/`07g`/`07h` each carry
  a hand-synced copy of `GROUND_TRUTH_CASES`, and `07e`'s list has drifted from
  them -- different counties AND different years. Reconcile before trusting a
  cross-dataset ground-truth comparison.

### `weather_descriptives_utils.py` -- GENERATED
Shared setup for `09a`/`09b`: the panel build, county/state geometry, the
colour and figure helpers, and the trend/decade blocks both tiers use.
- Generated by `make_scripts.py`. Do not edit by hand -- the banner is at the
  top of the file as of 2026-09-17.
- `build_panel()` is the only thing that does I/O; importing the module defines
  but does not read. Callers do `globals().update(build_panel())`.
- It resolves the project root by probing candidate paths rather than
  `__file__`, because the notebook it is generated from has no `__file__`. That
  candidate list is a notebook cell -- fix it THERE, or the next
  `make_scripts.py` run reverts you.

### `population_utils.py`
Shared library for the population scripts (08a/08b): FIPS crosswalk
mechanics (`load_fips_crosswalk`, `apply_fips_crosswalk`) for
reconciling county identity across 1981-2025, age-bucket constants and
the age-share pivot (`compute_age_shares`), the AGEGRP encoding guard
(`assert_agegrp_encoding`), the county-universe spine
(`load_county_universe`, `reindex_to_county_universe`), and the CSV/.dta
writer. `resolve_data_root` is re-exported from `aggregation_utils.py`
(identical logic, not duplicated here -- though note `gee_extract_utils.py`
does carry its own full copy of the same function); `setup_logging` is
reimplemented
rather than imported from `gee_extract_utils.py`, deliberately, so the
population stage does not depend on earthengine-api. Mirrors
`aggregation_utils.py`'s role for the aggregation stage.
- Harmonization direction: everything is recoded FORWARD onto TIGER/2018.
  Dorn's PDF goes the other way (modern codes back onto 1980-era codes,
  because his target is 1990 commuting zones). We take his change list,
  not his direction -- do not "fix" this back after reading him.
- The crosswalk relabels ALL years, not just post-change years. Sources
  are published under the geography vintage current at PUBLICATION, and
  for a merger a year-conditional rule would leave the absorbed county as
  an orphan geoid and undercount the survivor for years. This corrects
  the 8/31 scaffolding, which had the year-conditional rule.

### `test_population_logic.py`
Offline regression tests for the population stage -- crosswalk mechanics
for all four change types, the AGEGRP encoding guard, the age-share
pivot, the spine reindex, the Stata write, and stack priority resolution
including the one-year YEAR-code offset backstop. Synthetic fixtures, no
network. Run `python3 test_population_logic.py` before review.

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
- Resumability is a simple local JSON manifest of completed periods,
  written incrementally as each export task completes -- it doesn't check
  Drive/GCS directly, so the manifest and the actual exported files could
  in principle drift apart if a Drive file is deleted by hand.
- Progress monitoring surfaces EECU-seconds (compute time) per task, not
  just task state, since "RUNNING" alone doesn't show whether a job is
  stalled or making progress.
- **See "Drive folder duplication" below** for the shared-export-folder
  race-condition workaround (`start_exports_to_shared_folder()`).

## Manual verification (Earth Engine Console, not part of the pipeline)

### `01b_verify_prism_gee_console.js`
Manually recomputes one county's PRISM daily and monthly values directly
in the Earth Engine Code Editor console, to check them against
`01a_test_prism_extract.py` / `05_aggregate_daily_to_monthly.py`'s CSV
output. Reduces each day separately and aggregates in JS, mirroring the
Python pipeline's method (see the compositing discrepancy note under
`02a`), rather than compositing the ImageCollection first.

### `03b_verify_era5_gee_console.js`
Manually recomputes one county-day's ERA5-Land derived values directly in
the Earth Engine Code Editor console, to check them against
`03a_test_era5_extract.py`'s CSV output. Unlike the PRISM console check,
this recomputes real conversion math (Kelvin->Celsius, wind speed from
u/v, meters->mm), so it's testing `add_derived_bands()`'s logic, not just
band selection.

---

## Known issues / decisions log

Fuller writeups of a few things that are referenced above but were too
long to keep inline in the code.

### Wisconsin county duplication (affects `05`, `07a`)
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

### Duplicate-conflict detection fix (affects `05`, `06`)
`resolve_duplicate_rows()`'s original conflict check compared full rows
pairwise (`dup_rows.duplicated(keep=False)`): a row was "conflicting" only
if it had no exact match elsewhere in its geoid/date group. Blind spot: if
a group had two distinct value-sets each appearing an even number of times
(e.g. value A twice, value B twice), every row matches another row within
its own subgroup, so the check found nothing wrong and `keep="first"`
silently kept whichever value sorted first -- exactly the disagreement the
check exists to catch. Not triggered by the WI case above (genuinely
byte-identical), so this was a latent risk rather than an observed bug.
Fixed by counting distinct values (incl. NaN) per non-key column within
each geoid/date group (`groupby(...).nunique(dropna=False)`); any column
with >1 distinct value raises the conflict error.

### Drive folder duplication (affects `gee_extract_utils.py`, `02a`, `04a`)
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

### PRISM daily-vs-composited aggregation discrepancy (affects `02a`, `04a`, `07a`)
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
Two different verification strategies exist in this repo: `07a`/`07b`
independently reproduce PRISM values in Earth Engine and compare them to
production (a check on the pipeline's *processing* logic, since both
sides derive from the same PRISM source). `07c`-`07e` instead compare
production against real NOAA weather station readings (a check against an
independent ground truth). The station-based comparison is the one that
was carried through to a "passed" result; the GEE-reproduction approach
was the first strategy tried and remains in the repo as a still-useful,
independent check on processing logic, even though it wasn't the one that
closed out the verification work. `07f`-`07h` extend the station-based
approach to ERA5, reusing the same station-months and ground-truth sites
`07d`/`07e` already established for PRISM.


### ERA5-Land land-sea masking (affects `07f`)
Unlike PRISM, ERA5-Land only produces values for land grid cells -- a
cell sitting mostly over water is NaN for every variable, every hour.
This affected the Chowan County, NC ground-truth case: the nearest grid
cell to the Edenton station sits on Albemarle Sound and is masked
entirely (confirmed by inspection: 100% NaN across all time/step
combinations), the same water-dominated cell PRISM's own ground-truth
notes flagged for this station. `07f` checks the nearest cell's NaN
fraction first and, if it's masked, searches the rest of the downloaded
box for the nearest valid cell, flagging the row
(`used_fallback_grid_cell`) rather than returning all-NaN monthly stats.
