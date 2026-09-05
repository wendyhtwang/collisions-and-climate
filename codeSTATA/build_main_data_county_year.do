/*==============================================================
FILE:         build_main_data_county_year.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang

PURPOSE:      Merge PRISM/ERA5 weather, Census population, vehicle
              collisions, and wildlife harvest data into the county-year
              main data file, and construct the four candidate winter
              weather regressors on top of it.

CHANGELOG:
  09/04/2026 Wendy Wang: initial version -- per Eyal (9/1/26 meeting),
    merges deliberately keep every row (no `assert _merge==3`, nothing
    dropped) instead of following the style guide's default assert/drop
    convention; SECTION 5 exports per-county unmatched-year diagnostics
    in its place.
  09/05/2026 Wendy Wang: per the 9/4/26 and 9/5/26 team calls --
    (a) month-wide weather variables renamed to a "_m1".."_m12" suffix
        instead of a bare trailing digit, for readability;
    (b) added SECTION 2, merging ERA5's snow depth (and snowfall) into
        the panel alongside PRISM, since the winter severity index needs
        snow depth and PRISM has no equivalent;
    (c) added SECTION 6 (fips_num numeric FIPS + xtset) and SECTION 7
        (mean_winter_temp, warm_winter_1sd/2sd, winter_severity_index),
        built here rather than in the estimation .do files;
    (d) corrected the collisions and wildlife geoid-construction blocks
        (SECTIONS 4-5) against the two files' actual confirmed schemas
        (previously unverified guesses) and the wildlife file's real
        path/name;
    (e) fips variable naming settled on "fips_num" (matches the style
        guide's own convention, resolving the earlier fips/fips_numeric
        naming question).
==============================================================*/

* Inputs:
*   $path/dataCSV/PRISM/prism_derived_weather_vars.csv
*       (county-year-month; reshaped wide by month in SECTION 1)
*   $path/dataCSV/ERA5/era5_derived_weather_vars.csv
*       (county-year-month; only its snow columns are used, SECTION 2)
*   $path/dataCSV/Population/population_county_year_1990_2025.dta
*   $path/dataRAW/Collisions/collisions_CONUS_county_year_1985_2020.dta
*       (pre-2020 snapshot Eyal placed here 9/1/26; Charvi's updates since
*       then -- 2019/2020 for some states, more for others -- are not yet
*       in this snapshot)
*   $path/dataSTATA/US_deer_harvest_county_year_04sep2026.dta
*       (Nicole's harmonized wildlife panel, added 9/4/26. Filename is
*       date-stamped -- update this path when she ships a newer version)
*
* Output:
*   $path/dataSTATA/main_data_county_year.dta
*
* Open items -- flagged rather than assumed, per CLAUDE.md:
*   1. WSI snow-hazard component (SECTION 7) is set to missing: it needs
*      a county-month COUNT of days with snow depth >=18in, which doesn't
*      exist anywhere in the pipeline yet (only a monthly MEAN snow depth
*      does). Per Wendy (9/5/26), left missing rather than approximated --
*      add a "days with snow depth >=18in" derived variable to ERA5's
*      processing in 06_build_derived_weather_vars.py (same pattern as
*      days_extremely_cold for temperature); SECTION 7 auto-detects it
*      once it exists.
*   2. Wildlife's `year` is "season start year" (Nicole's convention),
*      which may not align one-to-one with the calendar year used by
*      weather/collisions/population -- e.g. a hunting season labeled
*      "2000" could span into early 2001. Not adjusted here; confirm with
*      Nicole before this feeds a harvest~weather regression with lags.
*   3. Known FIPS drift (Broomfield 2001, CT planning regions 2022,
*      Yellowstone/Gallatin-Park 1997, etc. -- see
*      dataCSV/Population/fips_crosswalk_1980_2025.csv) is NOT applied to
*      collisions/wildlife here. Eyal was explicit (9/1/26) that isn't
*      worth fixing yet; SECTION 8 tracks and documents it instead.
*   4. Known collisions data-quality issue, not fixed here per Eyal
*      (9/4/26): a handful of rows (~17, St. Louis, 2004-2020) have an
*      unresolved FIPS in the source data. SECTION 4 now builds geoid
*      from state_fips+county_fips rather than the numeric `fips` column
*      (which is system-missing for these rows and was producing the
*      literal string "." that Wendy flagged), and reports a count of any
*      still-malformed geoid so the issue stays visible without blocking.

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
        rename `v'`m' `v'_m`m''
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

        local era5_snow_vars mean_snow_depth total_snowfall_mm
        local era5_vars_ok = 1
        foreach v of local era5_snow_vars {
            capture confirm variable `v'
            if _rc local era5_vars_ok = 0
        }

        if !`era5_vars_ok' {
            di as error "Expected ERA5 variables (`era5_snow_vars') not found in era5_derived_weather_vars.csv -- its actual column names haven't been verified against this script. Check and update SECTION 2."
            exit 111
        }

        keep geoid ///
             state_fips ///
             county_fips ///
             county_name ///
             year ///
             month ///
             mean_snow_depth ///
             total_snowfall_mm

        reshape wide `era5_snow_vars', ///
                i(geoid ///
                  state_fips ///
                  county_fips ///
                  county_name ///
                  year) ///
                j(month)

        foreach v of local era5_snow_vars {
            forvalues m = 1/12 {
                rename `v'`m' `v'_m`m''
            }
        }

        isid geoid year
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
    local file_name = "$dataCSV/Population/population_county_year_1990_2025.dta"
    use "`file_name'", clear
    isid geoid year
    tempfile population_panel
    save `population_panel'
restore

* Per Eyal (9/1/26): keep every county-year row on both sides -- do NOT
* `assert _merge==3` or drop unmatched observations here, which departs
* from the style guide's default merge convention (Section 10). Population
* is only built 1990-2025 so far (1980s not implemented yet), so
* weather-only rows for 1981-1989 are an EXPECTED gap, not a bug. SECTION 8
* tracks and documents mismatches instead of asserting them away.
merge 1:1 geoid year using `population_panel'
rename _merge merge_population

*---------------------------------------------------------------
* SECTION 4: MERGE IN VEHICLE COLLISIONS
*---------------------------------------------------------------

local file_name = "$dataRAW/Collisions/collisions_CONUS_county_year_1985_2020.dta"

capture confirm file "`file_name'"
if _rc {
    di as error "Collisions file not found at `file_name' -- skipping this merge."
    di as error "Eyal said (9/1/26) he placed a snapshot there; check the path if this fires."
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

        * Known issue, not fixed per Eyal (9/4/26) -- report it, don't
        * block on it. A malformed geoid here (not exactly 5 characters)
        * will show up as its own nonsense "county" in SECTION 8's
        * diagnostics rather than merging correctly.
        quietly count if strlen(geoid) != 5
        if r(N) > 0 {
            di as text "NOTE: `r(N)' collisions rows have a malformed geoid (not 5 characters) -- known issue (e.g. St. Louis), Eyal said not urgent to fix (9/4/26)."
        }

        capture isid geoid year
        if _rc {
            di as error "collisions_CONUS_county_year_1985_2020.dta is not unique on geoid-year -- check for duplicate state/year vintages (e.g. overlapping snapshots) before merging, and collapse/dedupe as appropriate."
            exit 459
        }

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
* Eyal (9/5/26): keep geoid as the string merge key throughout, but also
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
* Four candidate right-hand-side winter measures, per Eyal (9/1 and 9/5
* calls) -- built here, not in the estimation .do files, so every
* downstream script uses the identical construction. All four rely on
* the xtset from SECTION 6 to pull December from the PRIOR year via L1.

* --- (1) Mean winter temperature: Dec(t-1) + Jan(t) + Feb(t), averaged ---
gen double mean_winter_temp = (L1.mean_temp_c_m12 + mean_temp_c_m1 + mean_temp_c_m2) / 3
label variable mean_winter_temp "Mean of Dec(t-1)/Jan(t)/Feb(t) PRISM monthly mean temp, degrees C"

* --- (2)-(3) Warm-winter dummies: mean_winter_temp relative to the ---
* --- county's own 1-sigma/2-sigma local climatology (full sample) ---
* "Local climatology" = this county's own mean/SD of mean_winter_temp
* across the full panel, per Eyal's "relative to your local long run
* '81 to 2025 climatology" (9/5). One-directional (warm side only).
bysort fips_num: egen double temp_v = mean(mean_winter_temp)   // county's own climatological mean winter temp
bysort fips_num: egen double temp_b = sd(mean_winter_temp)     // county's own climatological SD of winter temp

gen byte warm_winter_1sd = mean_winter_temp > (temp_v + temp_b) if !missing(mean_winter_temp)
gen byte warm_winter_2sd = mean_winter_temp > (temp_v + 2*temp_b) if !missing(mean_winter_temp)
label variable warm_winter_1sd "1 if mean_winter_temp > county's own full-sample mean + 1 SD"
label variable warm_winter_2sd "1 if mean_winter_temp > county's own full-sample mean + 2 SD"

drop temp_v temp_b

* --- (4) Winter Severity Index (Kohn 1975 / WI DNR definition, per the ---
* --- literature review): sum of (a) # days Dec 1-Apr 30 with min temp
* --- <=0F, and (b) # days Dec 1-Apr 30 with >=18in snow depth on the
* --- ground. A day meeting both conditions counts in both tallies, which
* --- is exactly the "adds 2 points" rule in the literature quote -- no
* --- special-case code needed, it falls out of summing the two counts.
* --- Window is Dec(t-1) through Apr(t) -- wider than the 3-month DJF
* --- window used for mean_winter_temp above.
gen wsi_cold_days = L1.days_extremely_cold_m12 ///
                   + days_extremely_cold_m1 ///
                   + days_extremely_cold_m2 ///
                   + days_extremely_cold_m3 ///
                   + days_extremely_cold_m4
label variable wsi_cold_days "WSI cold-stress component: # days Dec 1-Apr 30 with PRISM min temp <=0F"

* The snow-hazard component needs a county-month COUNT of days with snow
* depth >=18in. Only a monthly MEAN snow depth exists right now
* (mean_snow_depth, from SECTION 2), not a daily threshold count -- see
* open item 1 in the header. Per Wendy (9/5/26): leave this component
* missing rather than approximate it from the monthly mean (a month can
* average under 18in while still having qualifying days, or vice versa).
* This block auto-detects the proper variable once someone adds it to
* ERA5's processing -- rename it here if its eventual name differs from
* "days_snow_depth_18in".
capture confirm variable days_snow_depth_18in_m1
if _rc {
    di as text "NOTE: no county-month count of days with snow depth >=18in exists yet -- wsi_snow_days and winter_severity_index's snow component are set to missing. Add that derived variable to ERA5's processing (06_build_derived_weather_vars.py) to complete this."
    gen wsi_snow_days = .
}
else {
    gen wsi_snow_days = L1.days_snow_depth_18in_m12 ///
                       + days_snow_depth_18in_m1 ///
                       + days_snow_depth_18in_m2 ///
                       + days_snow_depth_18in_m3 ///
                       + days_snow_depth_18in_m4
}
label variable wsi_snow_days "WSI snow-hazard component: # days Dec 1-Apr 30 with snow depth >=18in -- MISSING until the upstream derived variable exists (see header, open item 1)"

gen winter_severity_index = wsi_cold_days + wsi_snow_days
label variable winter_severity_index "Winter Severity Index (Kohn 1975 / WI DNR): wsi_cold_days + wsi_snow_days. Categories: <50 mild, 50-80 moderate, 80-100 moderately severe, >100 very severe"

*---------------------------------------------------------------
* SECTION 8: MERGE DIAGNOSTICS
*---------------------------------------------------------------
* Per Eyal (9/1/26): don't fix FIPS mismatches now, just track how many
* there are and which counties are affected -- county by county rather
* than row by row (a 1981-1989 population gap, e.g., would otherwise dump
* thousands of expected-unmatched rows into the export).

foreach src in era5_snow population collisions wildlife {
    cap confirm variable merge_`src'
    if !_rc {
        di as text _newline "--- merge_`src' ---"
        tab merge_`src', missing

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
cap log close   // safe even though this script doesn't open its own log
