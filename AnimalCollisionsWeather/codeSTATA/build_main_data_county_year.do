/*==============================================================
FILE:         build_main_data_county_year.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang

PURPOSE:      Merge PRISM/ERA5 weather, Census population, vehicle
              collisions, and wildlife harvest data into the county-year
              main data file, and construct the four candidate winter
              weather regressors on top of it.

CHANGELOG:
  09/04/2026 Wendy Wang: initial version. Merges keep every row (no
    `assert _merge==3`, nothing dropped) rather than the style guide's
    assert/drop default; SECTION 5 exports unmatched-year diagnostics instead.
  09/05/2026 Wendy Wang: month-wide weather renamed to "_m1".."_m12"; added
    SECTION 2 (ERA5 snow depth, which PRISM has no equivalent for), SECTION 6
    (fips_num + xtset) and SECTION 7 (winter variables, built here rather than
    in the estimation files); corrected the SECTION 4-5 geoid blocks against
    the two files' confirmed schemas.
  09/08/2026 Wendy Wang: WSI snow-hazard component closed out -- 06 now builds
    days_snow_depth_18in (Kohn's threshold) plus 12in/8in sensitivity variants,
    SECTION 2 carries them through as OPTIONAL columns, and SECTION 7 populates
    wsi_snow_days and the indices. Upstream, days_extremely_cold moved from
    tmin < 0F to tmin <= 0F to match Kohn's "0F or below". REQUIRES a rerun of
    06 before this script picks any of it up.
  09/09/2026 Wendy Wang: merge diagnostics now distinguish EXPECTED gaps
    (outside a source's coverage window) from genuine ones (inside it) -- each
    panel captures its own min/max year, and SECTION 8 exports
    unmatched_<src>_in_window.csv alongside the existing by-county file.
  09/09/2026 Wendy Wang: SECTION 3 now reads
    population_county_year_1981_2025.dta, so min_year_population should read
    1981, not 1990 -- if it doesn't, the wrong file is being picked up.
  09/17/2026 Wendy Wang: SECTION 7 merges 06c's winter_severity_county_year.csv
    instead of building the index, so a Phase 4 exhibit no longer depends on a
    Phase 6 output. Definition ported unchanged and verified county-by-county
    against this script's prior output. mean_winter_temp and warm_winter_1sd/2sd
    stay here. merge_winter_severity is deliberately not in SECTION 8's loop:
    the panel's first year has no prior December and would list every county.
==============================================================*/

* Inputs (all under $path):
*   dataCSV/PRISM/prism_derived_weather_vars.csv    (reshaped wide, SECTION 1)
*   dataCSV/ERA5/era5_derived_weather_vars.csv      (snow columns, SECTION 2)
*   dataCSV/Weather/winter_severity_county_year.csv (06c, SECTION 7)
*   dataCSV/Population/population_county_year_1981_2025.dta
*   dataRAW/Collisions/collisions_CONUS_county_year_1985_2020.dta
*       (pre-2020 snapshot; Charvi's 2019/2020 updates are not in it yet)
*   dataSTATA/US_deer_harvest_county_year_04sep2026.dta
*       (Nicole's wildlife panel, date-stamped -- update when she ships a newer one)
*
* Output:
*   $path/dataSTATA/main_data_county_year.dta
*
* Open items -- flagged rather than assumed:
*   1. WSI INTERPRETATION (snow component itself resolved 9/8/26). Kohn's 18in
*      threshold was calibrated on point observations; county-averaged
*      ERA5-Land snow depth rarely reaches it outside mountain counties, so
*      winter_severity_index is effectively wsi_cold_days across most of the
*      study area. The _snow12/_snow8 variants exist to show that in a
*      robustness table -- raise before the WSI is a headline regressor.
*      Nantucket (25019) has no ERA5-Land snow readings, so its counts are 0.
*   2. Wildlife `year` is season start year, which may not align with the
*      calendar year used elsewhere. Not adjusted here; confirm with Nicole
*      before this feeds a harvest~weather regression with lags.
*   3. Known FIPS drift is NOT applied to collisions/wildlife (settled
*      9/1/26); SECTION 8 tracks and documents it instead.
*   4. ~17 collisions rows (St. Louis, 2004-2020) have an unresolved FIPS.
*      SECTION 4 builds geoid from state_fips+county_fips and reports any
*      still-malformed geoid, so the issue stays visible without blocking.

*---------------------------------------------------------------
* SECTION 0: SETUP
*---------------------------------------------------------------

cap log close
clear all
set more off, permanently
set matsize 11000
set maxvar 32767
set scheme s1mono

confirmdir "/mnt/data_d/Dropbox/Research"
if r(confirmdir) == "0" {
  local rootDir = "/mnt/data_d/Dropbox/Research"
}
confirmdir "C:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "C:/Dropbox/Research"
}
confirmdir "D:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "D:/Dropbox/Research"
}

if "$path" == "" {
    global path = "`rootDir'/AnimalCollisionsWeather"
}

global dataRAW    "$path/dataRAW"
global dataCSV    "$path/dataCSV"
global dataSTATA  "$path/dataSTATA"
global tables     "$path/tables"

cap mkdir "$dataSTATA"
cap mkdir "$tables/merge_diagnostics"

* Open log file in the codeSTATA directory
* Derive the codeSTATA path from the global path set above
local codeSTATA_dir = "$path/codeSTATA"
cap mkdir "`codeSTATA_dir'/logs"
local log_file = "`codeSTATA_dir'/logs/build_main_data_county_year.log"
cap log close
log using "`log_file'", replace text

*---------------------------------------------------------------
* SECTION 1: BUILD THE WEATHER COUNTY-YEAR PANEL (MASTER, PRISM)
*---------------------------------------------------------------
* PRISM is the project's main weather dataset for temperature and
* precipitation. ERA5's snow variables are merged in separately in
* SECTION 2, since PRISM has no snow equivalent.

local file_name = "$dataCSV/PRISM/prism_derived_weather_vars.csv"
import delimited using "`file_name'", clear varnames(1) stringcols(1 2 3)

* Collapse the per-month completeness metadata into one flag per
* county-year rather than reshaping it wide -- a monthly True/False and a
* categorical dataset-type code aren't analysis variables, just QA notes.
gen byte temp = (is_incomplete == "True")
bysort geoid year: egen n_incomplete_months = total(temp)
drop temp dataset_types expected_days is_incomplete

* Reshape every remaining monthly weather measure wide by calendar month.
ds
local allvars `r(varlist)'
local idvars geoid state_fips county_fips county_name year n_incomplete_months month
local weather_vars : list allvars - idvars

reshape wide `weather_vars', ///
        i(geoid ///
          state_fips ///
          county_fips ///
          county_name ///
          year ///
          n_incomplete_months) ///
        j(month)

* Stata's reshape appends the bare month number (e.g. "mean_temp_c1"..
* "mean_temp_c12"). Rename to a "_m1".."_m12" suffix instead, per the
* 9/5/26 call -- more readable, and matches how the team refers to these
* columns out loud.
foreach v of local weather_vars {
    forvalues m = 1/12 {
        rename `v'`m' `v'_m`m'
    }
}

isid geoid year
sort geoid year
tempfile weather_panel
save `weather_panel'

*---------------------------------------------------------------
* SECTION 2: MERGE IN ERA5 SNOW DEPTH (WIDE BY MONTH)
*---------------------------------------------------------------
* Per the 9/5/26 call: PRISM stays the source for temp/precip, but ERA5's
* snow depth (and snowfall) -- which PRISM has no equivalent for -- is
* needed for the winter severity index in SECTION 7, so it gets merged
* into the same panel.

use `weather_panel', clear

local file_name = "$dataCSV/ERA5/era5_derived_weather_vars.csv"

capture confirm file "`file_name'"
if _rc {
    di as error "ERA5 derived-vars file not found at `file_name' -- skipping the snow-depth merge. The winter severity index in SECTION 7 will be missing its snow component without this."
    gen byte merge_era5_snow = .
}
else {
    preserve
        import delimited using "`file_name'", clear varnames(1) stringcols(1 2 3)

        * REQUIRED: the two ERA5 snow variables 06 has always produced.
        local era5_snow_required mean_snow_depth total_snowfall_mm

        * OPTIONAL: the snow-depth day COUNTS added to 06 on 9/8/26 (18in is
        * Kohn's threshold; 12in/8in are sensitivity variants -- see SECTION 7).
        * Optional so this still runs against an ERA5 CSV built before that
        * change, in which case SECTION 7 falls back to a missing snow component.
        local era5_snow_optional days_snow_depth_18in ///
                                 days_snow_depth_12in ///
                                 days_snow_depth_8in

        local era5_vars_ok = 1
        foreach v of local era5_snow_required {
            capture confirm variable `v'
            if _rc local era5_vars_ok = 0
        }

        if !`era5_vars_ok' {
            di as error "Expected ERA5 variables (`era5_snow_required') not found in era5_derived_weather_vars.csv -- its actual column names haven't been verified against this script. Check and update SECTION 2."
            exit 111
        }

        local era5_snow_vars `era5_snow_required'
        foreach v of local era5_snow_optional {
            capture confirm variable `v'
            if !_rc {
                local era5_snow_vars `era5_snow_vars' `v'
            }
            else {
                di as text "NOTE: `v' not found in era5_derived_weather_vars.csv -- rerun codePYTHON/06_build_derived_weather_vars.py to build it. SECTION 7 will leave the corresponding winter-severity variable missing until then."
            }
        }

        keep geoid ///
             state_fips ///
             county_fips ///
             county_name ///
             year ///
             month ///
             `era5_snow_vars'

        reshape wide `era5_snow_vars', ///
                i(geoid ///
                  state_fips ///
                  county_fips ///
                  county_name ///
                  year) ///
                j(month)

        foreach v of local era5_snow_vars {
            forvalues m = 1/12 {
                rename `v'`m' `v'_m`m'
            }
        }

        isid geoid year

        quietly summarize year
        local min_year_era5_snow = r(min)
        local max_year_era5_snow = r(max)

        tempfile era5_snow_panel
        save `era5_snow_panel'
    restore

    * Same deliberate deviation as SECTION 3 below -- no assert/drop on
    * _merge; every row is kept regardless of match status.
    merge 1:1 geoid year using `era5_snow_panel'
    rename _merge merge_era5_snow
}

*---------------------------------------------------------------
* SECTION 3: MERGE IN POPULATION
*---------------------------------------------------------------

preserve
    local file_name = "$dataCSV/Population/population_county_year_1981_2025.dta"
    use "`file_name'", clear
    isid geoid year

    quietly summarize year
    local min_year_population = r(min)
    local max_year_population = r(max)

    tempfile population_panel
    save `population_panel'
restore

* Settled 9/1/26: keep every county-year row on both sides -- do NOT
* `assert _merge==3` or drop unmatched rows here, departing from the style
* guide's merge convention (Section 10). Population covers 1981-2025, so there
* is no expected 1980s gap; SECTION 8 documents any mismatches instead.
merge 1:1 geoid year using `population_panel'
rename _merge merge_population

*---------------------------------------------------------------
* SECTION 4: MERGE IN VEHICLE COLLISIONS
*---------------------------------------------------------------

local file_name = "$dataRAW/Collisions/collisions_CONUS_county_year_1985_2020.dta"

capture confirm file "`file_name'"
if _rc {
    di as error "Collisions file not found at `file_name' -- skipping this merge."
    di as error "A snapshot was placed there 9/1/26; check the path if this fires."
    gen byte merge_collisions = .
}
else {
    preserve
        use "`file_name'", clear

        * Confirmed schema (9/5/26): state_fips (str2) and county_fips
        * (str3) are already clean, zero-padded strings -- build geoid
        * from those directly rather than the numeric `fips` variable,
        * which is system-missing for a handful of rows (see open item 4
        * in the header: the St. Louis rows Wendy flagged 9/4/26).
        capture confirm variable geoid
        if _rc {
            capture confirm variable state_fips
            local have_state_fips = !_rc
            capture confirm variable county_fips
            local have_county_fips = !_rc

            if `have_state_fips' & `have_county_fips' {
                gen geoid = state_fips + county_fips
            }
            else {
                capture confirm variable fips
                if !_rc {
                    tostring fips, replace format(%05.0f)
                    rename fips geoid
                }
                else {
                    di as error "Could not construct geoid: none of geoid, state_fips+county_fips, or fips found in the collisions file."
                    exit 111
                }
            }
        }

        * Known issue, not fixed (settled 9/4/26) -- report it, don't
        * block on it. A malformed geoid here (not exactly 5 characters)
        * will show up as its own nonsense "county" in SECTION 8's
        * diagnostics rather than merging correctly.
        quietly count if strlen(geoid) != 5
        if r(N) > 0 {
            di as text "NOTE: `r(N)' collisions rows have a malformed geoid (not 5 characters) -- known issue (e.g. St. Louis), not urgent to fix (9/4/26)."
        }

        * missok: the ~17 known-missing-geoid rows (open item 4) would fail
        * isid on their own, since isid errors on ANY missing id value
        * separately from its duplicates check. Confirmed 9/5/26 that no true
        * duplicates exist, so missok lets those already-reported rows through.
        capture isid geoid year, missok
        if _rc {
            di as error "collisions_CONUS_county_year_1985_2020.dta is not unique on geoid-year -- check for duplicate state/year vintages (e.g. overlapping snapshots) before merging, and collapse/dedupe as appropriate."
            exit 459
        }

        quietly summarize year
        local min_year_collisions = r(min)
        local max_year_collisions = r(max)

        tempfile collisions_panel
        save `collisions_panel'
    restore

    * Same deliberate deviation as SECTION 3 -- no assert/drop on _merge.
    merge 1:1 geoid year using `collisions_panel'
    rename _merge merge_collisions
}

*---------------------------------------------------------------
* SECTION 5: MERGE IN WILDLIFE HARVEST DATA
*---------------------------------------------------------------
* Nicole added her harmonized panel to $dataSTATA on 9/4/26.

local file_name = "$dataSTATA/US_deer_harvest_county_year_04sep2026.dta"

capture confirm file "`file_name'"
if _rc {
    di as text "NOTE: wildlife panel not found at `file_name'."
    di as text "Confirm Nicole hasn't shipped a newer, differently-dated file -- update this path if so."
    gen byte merge_wildlife = .
}
else {
    preserve
        use "`file_name'", clear

        * Confirmed schema (9/5/26): despite its name, this file's
        * county_fips column already holds the full 5-digit code (str5),
        * not a 3-digit county-only segment -- there is no separate
        * state_fips column in Nicole's file. Simple rename, no
        * concatenation needed.
        capture confirm variable geoid
        if _rc {
            capture confirm variable county_fips
            if !_rc {
                rename county_fips geoid
            }
            else {
                capture confirm variable fips
                if !_rc rename fips geoid
                else {
                    di as error "Could not construct geoid in the wildlife panel: none of geoid, county_fips, or fips found -- check Nicole's current column names."
                    exit 111
                }
            }
        }

        * CAVEAT, not resolved here (open item 2 in the header): `year`
        * is documented as "season start year," which may not line up
        * one-to-one with the calendar year used elsewhere in this panel.

        capture isid geoid year
        if _rc {
            di as error "wildlife panel is not unique on geoid-year -- check before merging."
            exit 459
        }

        quietly summarize year
        local min_year_wildlife = r(min)
        local max_year_wildlife = r(max)

        tempfile wildlife_panel
        save `wildlife_panel'
    restore

    * Same deliberate deviation as SECTION 3 -- no assert/drop on _merge.
    merge 1:1 geoid year using `wildlife_panel'
    rename _merge merge_wildlife
}

*---------------------------------------------------------------
* SECTION 6: NUMERIC FIPS AND PANEL DECLARATION
*---------------------------------------------------------------
* Settled 9/5/26: keep geoid as the string merge key throughout, but also
* add a numeric FIPS ("fips_num", per the style guide's own convention)
* since reghdfe absorbs fixed effects much faster on a numeric identifier
* than a string one. fips_num doubles as the panel (i) variable for the
* xtset below, which SECTION 7's winter-variable construction needs for
* its L1. lag.

gen long fips_num = real(geoid)
label variable fips_num "Numeric county FIPS (real(geoid)); geoid remains the canonical string merge key"

xtset fips_num year

*---------------------------------------------------------------
* SECTION 7: WINTER WEATHER VARIABLES
*---------------------------------------------------------------
* Four candidate right-hand-side winter measures, per the 9/1 and 9/5
* calls -- built here, not in the estimation .do files, so every
* downstream script uses the identical construction. All four rely on
* the xtset from SECTION 6 to pull December from the PRIOR year via L1.

* --- (1) Mean winter temperature: Dec(t-1) + Jan(t) + Feb(t), averaged ---
gen double mean_winter_temp = (L1.mean_temp_c_m12 + mean_temp_c_m1 + mean_temp_c_m2) / 3
label variable mean_winter_temp "Mean of Dec(t-1)/Jan(t)/Feb(t) PRISM monthly mean temp, degrees C"

* --- (2)-(3) Warm-winter dummies: mean_winter_temp relative to the ---
* --- county's own 1-sigma/2-sigma local climatology (full sample) ---
* "Local climatology" = this county's own mean/SD of mean_winter_temp
* across the full panel, relative to that county's own '81-2025 record
* (settled 9/5). One-directional (warm side only).
bysort fips_num: egen double temp_v = mean(mean_winter_temp)   // county's own climatological mean winter temp
bysort fips_num: egen double temp_b = sd(mean_winter_temp)     // county's own climatological SD of winter temp

gen byte warm_winter_1sd = mean_winter_temp > (temp_v + temp_b) if !missing(mean_winter_temp)
gen byte warm_winter_2sd = mean_winter_temp > (temp_v + 2*temp_b) if !missing(mean_winter_temp)
label variable warm_winter_1sd "1 if mean_winter_temp > county's own full-sample mean + 1 SD"
label variable warm_winter_2sd "1 if mean_winter_temp > county's own full-sample mean + 2 SD"

drop temp_v temp_b

* --- (4) Winter Severity Index: merged in, not built here ---------
* Moved to codePYTHON/06c_build_winter_severity.py on 09/17/2026. The index is
* pure weather, so building it here and having 09b read it back out of
* main_data_county_year.dta made a Phase 4 exhibit depend on a Phase 6 output.
* Both this file and 09b now read 06c's CSV.
*
* Ported unchanged: Kohn (1975) / WI DNR, the Dec 1-Apr 30 window (wider than
* the DJF window mean_winter_temp uses above), a day COUNT rather than an
* approximation from mean_snow_depth, the 12in/8in variants, and
* missing-propagation. Verified county-by-county against this script's own
* prior output before the switch.

local file_name = "$dataCSV/Weather/winter_severity_county_year.csv"

capture confirm file "`file_name'"
if _rc {
    di as error "Winter severity file not found at `file_name' -- run codePYTHON/06c_build_winter_severity.py. wsi_cold_days, wsi_snow_days and every winter_severity_index* variable will be missing."
    gen wsi_cold_days = .
    gen wsi_snow_days = .
    gen wsi_snow_days_12in = .
    gen wsi_snow_days_8in = .
    gen winter_severity_index = .
    gen winter_severity_index_snow12 = .
    gen winter_severity_index_snow8 = .
    gen byte merge_winter_severity = .
}
else {
    preserve
        import delimited using "`file_name'", clear varnames(1) stringcols(1)
        isid geoid year

        tempfile winter_severity_panel
        save `winter_severity_panel'
    restore

    * 06c derives this from the same two derived-vars CSVs that build the
    * weather spine in SECTIONS 1-2, so every row here should match. Unlike
    * the collisions/wildlife merges, an unmatched USING row would mean the
    * two disagree about the county-year universe -- worth surfacing rather
    * than tracking, so keep master rows only and report the count.
    merge 1:1 geoid year using `winter_severity_panel', keep(master match)
    rename _merge merge_winter_severity

    quietly count if merge_winter_severity == 1
    if r(N) > 0 {
        di as text "NOTE: `r(N)' county-years have no winter-severity row. Expected for the panel's first year (December of the prior year is out of sample); investigate anything else."
    }
}

label variable wsi_cold_days "WSI cold-stress component: # days Dec 1-Apr 30 with PRISM min temp <=0F"
label variable wsi_snow_days "WSI snow-hazard component: # days Dec 1-Apr 30 with ERA5 county-mean snow depth >=18in (Kohn 1975)"
label variable winter_severity_index "Winter Severity Index (Kohn 1975 / WI DNR): wsi_cold_days + wsi_snow_days. Categories: <50 mild, 50-80 moderate, 80-100 moderately severe, >100 very severe"

* --- (4b) Sensitivity variants of the snow-hazard component ---
* Robustness only, NOT alternative definitions of the Kohn index. County
* averaging of ERA5-Land snow depth removes the local maxima an 18in cutoff is
* meant to catch, so wsi_snow_days is near-zero across most of the eastern deer
* range and the index there is effectively wsi_cold_days (open item 1). These
* let that be shown rather than asserted; report winter_severity_index.
foreach thr in 12 8 {
    label variable wsi_snow_days_`thr'in "SENSITIVITY (not Kohn): # days Dec 1-Apr 30 with ERA5 county-mean snow depth >=`thr'in"
    label variable winter_severity_index_snow`thr' "SENSITIVITY WSI: wsi_cold_days + wsi_snow_days_`thr'in (>=`thr'in snow instead of Kohn's >=18in)"
}

*---------------------------------------------------------------
* SECTION 8: MERGE DIAGNOSTICS
*---------------------------------------------------------------
* Settled 9/1/26: don't fix FIPS mismatches now, just track how many
* there are and which counties are affected -- county by county rather
* than row by row (a whole-decade coverage gap in one source, e.g., would
* otherwise dump thousands of expected-unmatched rows into the export).

foreach src in era5_snow population collisions wildlife {
    cap confirm variable merge_`src'
    if !_rc {
        di as text _newline "--- merge_`src' ---"
        tab merge_`src', missing

        * Decided 9/8/26: a year tab of the unmatched rows tells you
        * whether the gaps are the EXPECTED kind (before/after this
        * source's own coverage window) or a genuine glitch (a gap
        * *inside* the window where the source should have a record).
        * `min_year_`src'' / `max_year_`src'' were captured off the
        * source's own panel, above, when it was built.
        di as text "Year distribution of unmatched `src' rows:"
        tab year if merge_`src' != 3

        preserve
            gen byte temp = (merge_`src' != 3)
            collapse (sum) n_years_unmatched=temp (count) n_years_total=year, ///
                     by(geoid ///
                        state_fips ///
                        county_fips ///
                        county_name)
            gen double share_years_unmatched = n_years_unmatched / n_years_total
            keep if n_years_unmatched > 0
            gsort -share_years_unmatched -n_years_unmatched state_fips county_fips

            local file_name = "$tables/merge_diagnostics/unmatched_`src'_by_county.csv"
            export delimited geoid ///
                state_fips ///
                county_fips ///
                county_name ///
                n_years_unmatched ///
                n_years_total ///
                share_years_unmatched ///
                using "`file_name'", ///
                replace
        restore

        * Isolate unmatched rows INSIDE this source's own coverage window
        * (min_year_`src' to max_year_`src'') -- the ones that actually matter,
        * as opposed to rows unmatched only because the master panel extends
        * past the source's coverage. If the window wasn't captured (missing
        * input file), every unmatched row is written instead.
        preserve
            keep if merge_`src' != 3
            if "`min_year_`src''" != "" & "`max_year_`src''" != "" {
                keep if year >= `min_year_`src'' & year <= `max_year_`src''
            }
            gsort geoid year
            local n_flagged = _N
            local file_name = "$tables/merge_diagnostics/unmatched_`src'_in_window.csv"
            export delimited geoid ///
                state_fips ///
                county_fips ///
                county_name ///
                year ///
                merge_`src' ///
                using "`file_name'", ///
                replace
            di as result "  -> `n_flagged' in-window unmatched `src' row(s) written to `file_name''"
        restore
    }
}

*---------------------------------------------------------------
* SECTION 9: FINALIZE AND SAVE
*---------------------------------------------------------------

order geoid ///
      fips_num ///
      state_fips ///
      county_fips ///
      county_name ///
      year, first
order mean_winter_temp ///
      warm_winter_1sd ///
      warm_winter_2sd ///
      wsi_cold_days ///
      wsi_snow_days ///
      winter_severity_index ///
      wsi_snow_days_12in ///
      winter_severity_index_snow12 ///
      wsi_snow_days_8in ///
      winter_severity_index_snow8 ///
      merge_era5_snow ///
      merge_population ///
      merge_collisions ///
      merge_wildlife, last

label data "County-year main data file: PRISM weather + ERA5 snow (wide by month), winter severity variables, Census population, vehicle collisions, wildlife harvest. Built `c(current_date)'. See header for open items."

sort geoid year   // to keep saved files in a predictable order
compress
local file_name = "$dataSTATA/main_data_county_year.dta"
save "`file_name'", replace

di as result _newline "Saved `file_name'"
di as result "Merge diagnostics written to $tables/merge_diagnostics/"

* Wrap Up
log close
