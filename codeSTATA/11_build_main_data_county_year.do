/*==============================================================
FILE:         11_build_main_data_county_year.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang

PURPOSE:      Build the county-year "main data file" that feeds the
              collisions~weather and wildlife~weather reduced-form
              regressions: merges PRISM weather, Census population, vehicle
              collisions, and wildlife harvest data into one panel, keyed
              on geoid + year. Per Eyal (Tue 9/1/26 meeting): read weather
              first (most complete county-year source), then merge in
              population, collisions, and wildlife. Keep every record --
              do NOT drop rows that fail to merge -- and track/document
              how many fail and which FIPS/geoids are involved. Getting a
              perfectly reconciled sample is explicitly NOT the goal this
              week; having the pipeline connected is.

INPUTS:       $path/dataCSV/PRISM/prism_derived_weather_vars.csv
                  (county-year-month; reshaped wide by month here)
              $path/dataCSV/Population/population_county_year_1990_2025.dta
              $path/dataRAW/Collisions/collisions_CONUS_county_year_1985_2020.dta
                  (the pre-2020 snapshot Eyal placed here on 9/1/26; Charvi's
                  updates -- 2019/2020 for some states, more elsewhere --
                  are not yet in this snapshot)
              $path/dataRAW/Wildlife/wildlife_harvest_county_year.dta
                  (Nicole's harmonized wildlife panel -- NOT YET DELIVERED
                  as of 9/1/26; this script checks for the file and skips
                  the wildlife merge gracefully if it isn't there yet, so
                  the rest of the pipeline still runs. CONFIRM the actual
                  filename with Nicole once she ships it and update SECTION 4)

OUTPUT:       $path/dataSTATA/main_data_county_year.dta

CONFIRM / OPEN QUESTIONS (flagged per CLAUDE.md -- ask before assuming):
  1. Weather reshape: Eyal asked for "county-year-monthly super-wide"
     weather data. This script reshapes the monthly PRISM derived
     variables wide by calendar month (mean_temp_c1..mean_temp_c12, etc.)
     to get one row per county-year. Confirm this is the intended shape
     before the estimation scripts are written against it.
  2. Only PRISM is merged in, not ERA5. Per project convention, PRISM is
     the main weather dataset and ERA5 is a robustness check, not a
     co-equal source for the regression file -- confirm that's still right
     for the main data file specifically.
  3. Collisions/wildlife variable names below (geoid construction, outcome
     var names) are written against the project style guide's naming
     conventions (fips as string, county-year granularity already
     collapsed). They have not been verified against the actual files,
     since collisions_CONUS_county_year_1985_2020.dta and Nicole's
     wildlife file are not available outside Kodama. Check the geoid
     construction block in each section once run on Kodama and adjust if
     the real variable names differ.
  4. Known FIPS-code drift (Broomfield CO 2001 split, CT planning regions
     2022, Yellowstone/Gallatin-Park 1997, etc. -- see
     dataCSV/Population/fips_crosswalk_1980_2025.csv) is NOT applied to
     collisions/wildlife here. Eyal was explicit (9/1/26) that this isn't
     worth fixing yet ("hopefully that number will be small and not too
     meaningful") -- this script only tracks and documents unmatched
     geoids per SECTION 5, it doesn't crosswalk them.

CHANGELOG:
  09/04/2026 Wendy Wang: initial version.
==============================================================*/

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
* SECTION 1: BUILD THE WEATHER COUNTY-YEAR PANEL (MASTER)
*---------------------------------------------------------------
* PRISM is the project's main weather dataset; ERA5 is a robustness check,
* not merged into the main data file here (CONFIRM #2 above).

local file_name = "$dataCSV/PRISM/prism_derived_weather_vars.csv"
import delimited using "`file_name'", clear varnames(1) stringcols(1 2 3)

* Rename the squared-units variable before reshaping so its trailing "2"
* doesn't collide with the month suffix reshape is about to append
* (mean_temp_c2 + month "12" would otherwise read as mean_temp_c212).
rename tmean_variance_c2 tmean_var_c_sq

* Collapse the per-month completeness metadata into one flag per
* county-year rather than reshaping it wide -- a monthly True/False and a
* categorical dataset-type code aren't analysis variables, just QA notes.
gen byte _month_incomplete = (is_incomplete == "True")
bysort geoid year: egen n_incomplete_months = total(_month_incomplete)
drop _month_incomplete dataset_types expected_days is_incomplete

* Reshape every remaining monthly weather measure wide by calendar month.
* This is the "county-year-monthly super-wide" structure from the 9/1 call
* (CONFIRM #1 above).
ds
local allvars `r(varlist)'
local idvars geoid state_fips county_fips county_name year n_incomplete_months month
local weather_vars : list allvars - idvars

reshape wide `weather_vars', ///
        i(geoid state_fips county_fips county_name year n_incomplete_months) ///
        j(month)

isid geoid year
sort geoid year
tempfile weather_panel
save `weather_panel'

*---------------------------------------------------------------
* SECTION 2: MERGE IN POPULATION
*---------------------------------------------------------------

use `weather_panel', clear

preserve
    use "$dataCSV/Population/population_county_year_1990_2025.dta", clear
    isid geoid year
    tempfile population_panel
    save `population_panel'
restore

* Keep every record on both sides -- do not assert _merge==3 or drop
* unmatched rows. Population is only built 1990-2025 so far (1980s not
* implemented yet, see project memory), so weather-only rows for
* 1981-1989 are an EXPECTED gap, not a bug.
merge 1:1 geoid year using `population_panel'
rename _merge merge_population

*---------------------------------------------------------------
* SECTION 3: MERGE IN VEHICLE COLLISIONS
*---------------------------------------------------------------

local collisions_file = "$dataRAW/Collisions/collisions_CONUS_county_year_1985_2020.dta"

capture confirm file "`collisions_file'"
if _rc {
    di as error "Collisions file not found at `collisions_file' -- skipping this merge."
    di as error "Eyal said (9/1/26) he placed a snapshot there; check the path if this fires."
    gen byte merge_collisions = .
}
else {
    preserve
        use "`collisions_file'", clear

        * CONFIRM #3: verify these variable names once run on Kodama and
        * adjust this block if Charvi's actual geoid/year variables differ.
        capture confirm variable geoid
        if _rc {
            capture confirm variable fips
            if !_rc {
                rename fips geoid
            }
            else {
                capture confirm string variable state_fips
                if _rc tostring state_fips, replace format(%02.0f)
                capture confirm string variable county_fips
                if _rc tostring county_fips, replace format(%03.0f)
                gen geoid = state_fips + county_fips
            }
        }
        capture confirm string variable geoid
        if _rc tostring geoid, replace format(%05.0f)
        replace geoid = string(real(geoid), "%05.0f") if strlen(geoid) < 5

        capture isid geoid year
        if _rc {
            di as error "collisions_CONUS_county_year_1985_2020.dta is not unique on geoid-year -- check for duplicate state/year vintages before merging (e.g. overlapping snapshots) and collapse/dedupe as appropriate."
            exit 459
        }

        tempfile collisions_panel
        save `collisions_panel'
    restore

    merge 1:1 geoid year using `collisions_panel'
    rename _merge merge_collisions
}

*---------------------------------------------------------------
* SECTION 4: MERGE IN WILDLIFE HARVEST DATA
*---------------------------------------------------------------
* Nicole's harmonized county-year (or WMA-year) wildlife panel was still in
* progress as of the 9/1/26 meeting -- Eyal asked her to drop it in
* $dataRAW/Wildlife/ once ready. CONFIRM the actual filename with Nicole;
* this is a placeholder guess.

local wildlife_file = "$dataRAW/Wildlife/wildlife_harvest_county_year.dta"

capture confirm file "`wildlife_file'"
if _rc {
    di as text "NOTE: wildlife panel not found at `wildlife_file'."
    di as text "Nicole's wildlife harmonization script was still in progress as of 9/1/26 -- re-run this .do file once her output lands, and confirm the filename above matches what she actually produces."
    gen byte merge_wildlife = .
}
else {
    preserve
        use "`wildlife_file'", clear

        * CONFIRM #3: same caveat as the collisions block -- verify against
        * Nicole's actual variable names. Some states report at the WMA
        * level rather than county level (per Nicole's task list); WMA-keyed
        * rows won't have a geoid and will not merge here. Eyal's guidance
        * was not to crosswalk WMA to county, so those rows are expected to
        * stay unmatched/master-of-their-own until the WMA-level weather
        * extraction (Phase 3, still open) exists to merge them against.
        capture confirm variable geoid
        if _rc {
            capture confirm variable fips
            if !_rc rename fips geoid
        }
        capture confirm string variable geoid
        if _rc tostring geoid, replace format(%05.0f)

        capture isid geoid year
        if _rc {
            di as error "wildlife panel is not unique on geoid-year (species-level rows not yet collapsed to county-year?) -- check before merging."
            exit 459
        }

        tempfile wildlife_panel
        save `wildlife_panel'
    restore

    merge 1:1 geoid year using `wildlife_panel'
    rename _merge merge_wildlife
}

*---------------------------------------------------------------
* SECTION 5: MERGE DIAGNOSTICS
*---------------------------------------------------------------
* Per Eyal (9/1/26): don't fix FIPS mismatches now, just track how many
* there are and which geoids are affected, county by county rather than
* row by row (a 1981-1989 population gap, e.g., would otherwise dump
* thousands of "expected" unmatched rows into the export).

foreach src in population collisions wildlife {
    cap confirm variable merge_`src'
    if !_rc {
        di as text _newline "--- merge_`src' ---"
        tab merge_`src', missing

        preserve
            gen byte _unmatched_`src' = (merge_`src' != 3)
            collapse (sum) n_years_unmatched=_unmatched_`src' ///
                     (count) n_years_total=year, ///
                     by(geoid state_fips county_fips county_name)
            gen double frac_years_unmatched = n_years_unmatched / n_years_total
            keep if n_years_unmatched > 0
            gsort -frac_years_unmatched -n_years_unmatched state_fips county_fips
            export delimited geoid state_fips county_fips county_name ///
                n_years_unmatched n_years_total frac_years_unmatched ///
                using "$tables/merge_diagnostics/unmatched_`src'_by_county.csv", ///
                replace
        restore
    }
}

*---------------------------------------------------------------
* SECTION 6: FINALIZE AND SAVE
*---------------------------------------------------------------

order geoid state_fips county_fips county_name year, first
order merge_population merge_collisions merge_wildlife, last

label data "County-year main data file: PRISM weather (wide by month), Census population, vehicle collisions, wildlife harvest. Built `c(current_date)'. See header for open confirmations."

sort geoid year
compress
save "$dataSTATA/main_data_county_year.dta", replace

di as result _newline "Saved $dataSTATA/main_data_county_year.dta"
di as result "Merge diagnostics written to $tables/merge_diagnostics/"
