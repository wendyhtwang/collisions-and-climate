/*==============================================================
FILE:         check_animal_deer_backfill.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang

PURPOSE:      Verify a collisions-data assumption flagged on the 9/8/26
              call: switching the outcome from deer-only (`deer_*`) to
              all-animal (`animal_*`) should only ever GAIN observations,
              never lose any -- i.e. every non-missing deer value also
              carries a non-missing animal value.

              An upstream backfill is believed to do this but has never
              been confirmed, and the code that appends the state
              collisions files is not in this repo, so this checks the
              built data empirically instead.

USAGE:        Run standalone. Reads main_data_county_year.dta by default,
              which also checks that the merge introduced no new gaps;
              set check_raw_file below to 1 to test the raw collisions
              snapshot instead and isolate upstream issues.

OUTPUT:       Console pass/fail per outcome, plus a CSV of offending
              geoid-year rows at
              $tables/checks/animal_deer_backfill_violations.csv.

CHANGELOG:
  09/09/2026 Wendy Wang: initial version, per the 9/8/26 review.
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
di as text "(Rule: all_animal as the outcome should only ever GAIN observations vs. deer, never lose any.)"

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
        di as error "FAIL  deer_`s' (n=`n_deer'') -> animal_`s'' (n=`n_animal''): `n_gap'' row(s) have a non-missing deer_`s'' but a MISSING animal_`s''. The expected backfill does not hold for this outcome."

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
    di as error "OVERALL: FAIL -- the animal_*/deer_* backfill does NOT fully hold in `file_name'. See violations CSV above. Flag this before treating all_animal as a strict superset of deer."
}
else {
    di as result "OVERALL: PASS -- every non-missing deer_<suffix> has a non-missing animal_<suffix>, for every outcome checked, in `file_name'. Confirms the assumption; safe to use all_animal as the outcome without losing observations relative to deer."
}
di as result "============================================================"
