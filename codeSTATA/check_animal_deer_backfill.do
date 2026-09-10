/*==============================================================
FILE:         check_animal_deer_backfill.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang

PURPOSE:      Verify the collisions-data assumption Eyal flagged on the
              9/8/26 call: using all-animal collisions (`animal_*`) as
              the outcome instead of deer-only (`deer_*`) should ONLY
              ever gain observations, never lose any. His words: "if
              there is a non-missing deer value, that should also be a
              minimum [floor] and non-missing any_animal value... you
              should not lose any observations from using the any_animal
              whatsoever. You should only be gaining observations."

              Eyal believes a backfill step already exists upstream (in
              whatever code produced collisions_CONUS_county_year_1985_2020
              .dta) that replaces a missing animal_* with a non-missing
              deer_* value, but asked Wendy to check it rather than
              assume it. This script checks it empirically, on the built
              data, rather than tracing code Wendy doesn't have (the file
              that appends the state-level collisions data together is
              not in this repo -- Eyal placed a finished snapshot at
              $dataRAW/Collisions/collisions_CONUS_county_year_1985_2020
              .dta, per SECTION 4 of build_main_data_county_year.do).

USAGE:        Run standalone. Defaults to reading the built
              main_data_county_year.dta (so it also implicitly checks
              that the merge in build_main_data_county_year.do didn't
              introduce new gaps). To check the raw collisions snapshot
              directly instead -- e.g. if you want to isolate whether an
              issue is upstream vs from the county-year merge -- set
              check_raw_file below to 1.

OUTPUT:       Console summary (pass/fail per outcome category) plus, for
              any category that fails, a CSV of the offending geoid-year
              rows at $tables/checks/animal_deer_backfill_violations.csv.

CHANGELOG:
  09/09/2026 Wendy Wang: initial version, per Eyal's 9/8/26 ask.
==============================================================*/

cap log close
clear all
set more off, permanently

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
global dataSTATA  "$path/dataSTATA"
global tables     "$path/tables"

cap mkdir "$tables/checks"

* -------------------------------------------------------------
* Set to 1 to check the raw collisions snapshot directly instead
* of the built county-year main data file.
* -------------------------------------------------------------
local check_raw_file = 0

if `check_raw_file' {
    local file_name = "$dataRAW/Collisions/collisions_CONUS_county_year_1985_2020.dta"
}
else {
    local file_name = "$dataSTATA/main_data_county_year.dta"
}

capture confirm file "`file_name'"
if _rc {
    di as error "File not found at `file_name' -- update the path (or check_raw_file) above and rerun."
    exit 601
}

use "`file_name'", clear

* Per "Variables in the main merged dataset.md": animal_* and deer_*
* both carry these six outcome suffixes (animal_* also has a seventh,
* total_injury, with no deer_* counterpart -- nothing to check there).
local suffixes total fatal fatalities injury injuries pdo

di as text _newline "Checking: does every non-missing deer_<suffix> row also have a non-missing animal_<suffix>?"
di as text "(Eyal's rule: all_animal as the outcome should only ever GAIN observations vs. deer, never lose any.)"

local any_failures = 0
tempname violations_all
tempfile violations_file
local first_export = 1

foreach s of local suffixes {
    capture confirm variable deer_`s'
    local have_deer = !_rc
    capture confirm variable animal_`s'
    local have_animal = !_rc

    if !`have_deer' | !`have_animal' {
        di as error "SKIPPED deer_`s' / animal_`s'' -- one or both variables not found in `file_name'. Check the variable names haven't changed."
        continue
    }

    quietly count if !missing(deer_`s')
    local n_deer = r(N)
    quietly count if !missing(animal_`s')
    local n_animal = r(N)
    quietly count if !missing(deer_`s') & missing(animal_`s')
    local n_gap = r(N)
    quietly count if missing(deer_`s') & !missing(animal_`s')
    local n_gain = r(N)

    if `n_gap' == 0 {
        di as result "PASS  deer_`s' (n=`n_deer'') -> animal_`s'' (n=`n_animal''): no gaps. Using all-animal gains `n_gain'' observation(s), loses 0."
    }
    else {
        local any_failures = 1
        di as error "FAIL  deer_`s' (n=`n_deer'') -> animal_`s'' (n=`n_animal''): `n_gap'' row(s) have a non-missing deer_`s'' but a MISSING animal_`s''. The backfill Eyal expects does not hold for this outcome."

        preserve
            keep if !missing(deer_`s') & missing(animal_`s')
            keep geoid state_fips county_fips county_name year deer_`s' animal_`s'
            gen str20 outcome_suffix = "`s'"
            order outcome_suffix, first

            if `first_export' {
                save `violations_file', replace
                local first_export = 0
            }
            else {
                append using `violations_file'
                save `violations_file', replace
            }
        restore
    }
}

if !`first_export' {
    use `violations_file', clear
    local out_file = "$tables/checks/animal_deer_backfill_violations.csv"
    export delimited using "`out_file'", replace
    di as error _newline "Violations written to `out_file' -- `c(N)' row(s) across all failing outcome(s)."
}

di as result _newline "============================================================"
if `any_failures' {
    di as error "OVERALL: FAIL -- the animal_*/deer_* backfill does NOT fully hold in `file_name'. See violations CSV above. Flag this to Eyal before treating all_animal as a strict superset of deer."
}
else {
    di as result "OVERALL: PASS -- every non-missing deer_<suffix> has a non-missing animal_<suffix>, for every outcome checked, in `file_name'. Confirms Eyal's assumption; safe to use all_animal as the outcome without losing observations relative to deer."
}
di as result "============================================================"
