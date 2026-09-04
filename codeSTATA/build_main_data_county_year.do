/*==============================================================
FILE:         build_main_data_county_year.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang

PURPOSE:      Merge PRISM weather, Census population, vehicle collisions,
              and wildlife harvest data into the county-year main data file.

CHANGELOG:
  09/04/2026 Wendy Wang: initial version -- per Eyal (9/1/26 meeting),
    merges deliberately keep every row (no `assert _merge==3`, nothing
    dropped) instead of following the style guide's default assert/drop
    convention; SECTION 5 exports per-county unmatched-year diagnostics
    in its place.
==============================================================*/

* Inputs:
*   $path/dataCSV/PRISM/prism_derived_weather_vars.csv
*       (county-year-month; reshaped wide by month in SECTION 1)
*   $path/dataCSV/Population/population_county_year_1990_2025.dta
*   $path/dataRAW/Collisions/collisions_CONUS_county_year_1985_2020.dta
*       (pre-2020 snapshot Eyal placed here 9/1/26; Charvi's updates since
*       then -- 2019/2020 for some states, more for others -- are not yet
*       in this snapshot)
*   $path/dataRAW/Wildlife/wildlife_harvest_county_year.dta
*       (Nicole's harmonized wildlife panel -- NOT YET DELIVERED as of
*       9/1/26; SECTION 4 checks for the file and skips the merge
*       gracefully, with a console note, if it isn't there yet)
*
* Output:
*   $path/dataSTATA/main_data_county_year.dta
*
* Open questions -- flagged rather than assumed, per CLAUDE.md:
*   1. Weather reshape: this reshapes monthly PRISM variables wide by
*      calendar month (mean_temp_c1..mean_temp_c12, etc.) to get one row
*      per county-year -- confirm this "super-wide" structure is what
*      Eyal wants before the estimation scripts are built against it.
*   2. Only PRISM is merged, not ERA5 -- PRISM is the project's main
*      weather dataset and ERA5 a robustness check, not a co-equal
*      source; confirm that's still right for this file specifically.
*   3. The collisions/wildlife geoid-construction blocks (SECTIONS 3-4)
*      are written against the project's naming conventions, not
*      verified against the actual files -- those only exist on Kodama.
*      Check and adjust once this runs there.
*   4. Known FIPS drift (Broomfield 2001, CT planning regions 2022,
*      Yellowstone/Gallatin-Park 1997, etc. -- see
*      dataCSV/Population/fips_crosswalk_1980_2025.csv) is NOT applied to
*      collisions/wildlife here. Eyal was explicit (9/1/26) that isn't
*      worth fixing yet; SECTION 5 tracks and documents it instead.

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
* PRISM is the project's main weather dataset; ERA5 is a robustness check
* and is not merged into the main data file here (open question 2 above).

local file_name = "$dataCSV/PRISM/prism_derived_weather_vars.csv"
import delimited using "`file_name'", clear varnames(1) stringcols(1 2 3)

* Rename the squared-units variable before reshaping so its trailing "2"
* doesn't collide with the month suffix reshape is about to append
* (mean_temp_c2 + month "12" would otherwise read as mean_temp_c212).
rename tmean_variance_c2 tmean_var_c_sq

* Collapse the per-month completeness metadata into one flag per
* county-year rather than reshaping it wide -- a monthly True/False and a
* categorical dataset-type code aren't analysis variables, just QA notes.
gen byte temp = (is_incomplete == "True")
bysort geoid year: egen n_incomplete_months = total(temp)
drop temp dataset_types expected_days is_incomplete

* Reshape every remaining monthly weather measure wide by calendar month.
* This is the "county-year-monthly super-wide" structure from the 9/1
* call (open question 1 above).
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

isid geoid year
sort geoid year
tempfile weather_panel
save `weather_panel'

*---------------------------------------------------------------
* SECTION 2: MERGE IN POPULATION
*---------------------------------------------------------------

use `weather_panel', clear

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
* weather-only rows for 1981-1989 are an EXPECTED gap, not a bug. SECTION 5
* tracks and documents mismatches instead of asserting them away.
merge 1:1 geoid year using `population_panel'
rename _merge merge_population

*---------------------------------------------------------------
* SECTION 3: MERGE IN VEHICLE COLLISIONS
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

        * Open question 3: verify these variable names once run on Kodama
        * and adjust this block if Charvi's actual geoid/year variables
        * differ.
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
            di as error "collisions_CONUS_county_year_1985_2020.dta is not unique on geoid-year -- check for duplicate state/year vintages (e.g. overlapping snapshots) before merging, and collapse/dedupe as appropriate."
            exit 459
        }

        tempfile collisions_panel
        save `collisions_panel'
    restore

    * Same deliberate deviation as SECTION 2 -- no assert/drop on _merge.
    merge 1:1 geoid year using `collisions_panel'
    rename _merge merge_collisions
}

*---------------------------------------------------------------
* SECTION 4: MERGE IN WILDLIFE HARVEST DATA
*---------------------------------------------------------------
* Nicole's harmonized county-year (or WMA-year) wildlife panel was still in
* progress as of the 9/1/26 meeting -- Eyal asked her to drop it in
* $dataRAW/Wildlife/ once ready. Confirm the actual filename with Nicole;
* this is a placeholder guess.

local file_name = "$dataRAW/Wildlife/wildlife_harvest_county_year.dta"

capture confirm file "`file_name'"
if _rc {
    di as text "NOTE: wildlife panel not found at `file_name'."
    di as text "Nicole's wildlife harmonization script was still in progress as of 9/1/26 -- re-run this .do file once her output lands, and confirm the filename above matches what she actually produces."
    gen byte merge_wildlife = .
}
else {
    preserve
        use "`file_name'", clear

        * Open question 3, same caveat as SECTION 3: verify against
        * Nicole's actual variable names. Some states report at the WMA
        * level rather than county level; WMA-keyed rows won't have a
        * geoid and won't merge here. Eyal's guidance was not to crosswalk
        * WMA to county, so those rows are expected to stay unmatched
        * until the WMA-level weather extraction (still open) exists to
        * merge them against.
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

    * Same deliberate deviation as SECTION 2 -- no assert/drop on _merge.
    merge 1:1 geoid year using `wildlife_panel'
    rename _merge merge_wildlife
}

*---------------------------------------------------------------
* SECTION 5: MERGE DIAGNOSTICS
*---------------------------------------------------------------
* Per Eyal (9/1/26): don't fix FIPS mismatches now, just track how many
* there are and which counties are affected -- county by county rather
* than row by row (a 1981-1989 population gap, e.g., would otherwise dump
* thousands of expected-unmatched rows into the export).

foreach src in population collisions wildlife {
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
* SECTION 6: FINALIZE AND SAVE
*---------------------------------------------------------------

order geoid ///
      state_fips ///
      county_fips ///
      county_name ///
      year, first
order merge_population merge_collisions merge_wildlife, last

label data "County-year main data file: PRISM weather (wide by month), Census population, vehicle collisions, wildlife harvest. Built `c(current_date)'. See header for open confirmations."

sort geoid year   // to keep saved files in a predictable order
compress
local file_name = "$dataSTATA/main_data_county_year.dta"
save "`file_name'", replace

di as result _newline "Saved `file_name'"
di as result "Merge diagnostics written to $tables/merge_diagnostics/"

* Wrap Up
cap log close   // safe even though this script doesn't open its own log
