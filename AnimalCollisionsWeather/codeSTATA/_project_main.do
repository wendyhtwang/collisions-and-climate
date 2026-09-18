/*==============================================================
FILE:         _project_main.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang (maintained jointly with Nicole Martinez)

PURPOSE:      Master script. Lists every stage of the project's pipeline in
              the order it has to run. Specification and design decisions
              live in the child scripts, not here.

CHANGELOG:
  09/11/2026 Wendy Wang: wired in the weather pipeline (02a, 04a, 05, 06)
    and the descriptive exhibits (09a, 09b, 10).
  09/15/2026 Wendy Wang: added the population scripts (08a, 08b) and
    build_main_data_county_year.do to SECTION 2; filled in SECTIONS 4 and 5.
    Earth Engine extracts and the two sibling-repo appends left commented.

  09/17/2026 Wendy Wang: wired in the remaining two pipelines and the WSI --
    - SECTION 2.2 runs 06c_build_winter_severity.py, so SECTION 3 no longer
      depends on the merge in 2.5.
    - SECTION 2.4 is live behind `run_upstream' (SECTION 0, default 0):
      Nicole's and Charvi's appends plus the copy steps that stage their
      output into this project. Charvi's output path is a placeholder that
      refuses to run until confirmed.
    - Documented the CENSUS_API_KEY requirement and the fact that a bare 08b
      call is the full CONUS x 45-year build.
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

* Kodama first: it is where the data live and where this runs. The Windows
* branches are the style guide's template, kept so the file resolves on a laptop.
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

if "`rootDir'" == "" {
    di as error "No Dropbox research root found. Add this machine's " ///
                "root to the confirmdir block above."
    exit 601
}

if "$path" == "" {
    global path = "`rootDir'/AnimalCollisionsWeather"
}

* Convenience globals, all subpaths of $path. Every child re-derives its own.
global codePYTHON "$path/codePYTHON"
global codeSTATA  "$path/codeSTATA"
global dataCSV    "$path/dataCSV"
global dataRAW    "$path/dataRAW"
global dataSTATA  "$path/dataSTATA"
global estimates  "$path/dataSTATA/estimates"
global figures    "$path/figures"
global tables     "$path/tables"
global reports    "$path/reports"
global pathUngulates  "`rootDir'/UngulatePopulationDataRepo"
global pathCollisions "`rootDir'/VehicleCollisionsDataRepo"

* Rebuild the two sibling-repo panels in SECTION 2.4 before merging? Off by
* default: those scripts belong to Nicole and Charvi, write into their own
* repos, and have not been run from here. See 2.4.
local run_upstream = 0

* 08b needs a Census API key for 1990-1999 on a cold cache, which the default
* full-range run hits. It is read from the environment, not passed as a flag:
*     export CENSUS_API_KEY=<key>      (before launching Stata)
* Without it 08b raises rather than silently skipping the decade.

* Named log: children open unnamed logs and would close this one otherwise.
cap mkdir "$codeSTATA/logs"
cap log close main
log using "$codeSTATA/logs/_project_main.log", replace text name(main)

* Uncomment to pin the interpreter used by every `python script` call below.
* python set exec "/mnt/data_d/Dropbox/Research/AnimalCollisionsWeather/.venv/bin/python", permanently

/* Call syntax:
       do     "$codeSTATA/<script>.do"
       rscript using "$codeSTATA/<script>.R"
       python script "$codePYTHON/<script>.py"                              */

*---------------------------------------------------------------
* SECTION 1: USER-WRITTEN PACKAGES
*---------------------------------------------------------------

/* Installed once per machine, not per run. The estimation and report scripts
   re-check the ones they need (reghdfe, ftools, require, estout, texdoc) and
   install what is missing, so a fresh Stata gets through without this block.

    ssc install coefplot
    ssc install estout
    ssc install confirmdir
    ssc install unique
    ssc install egenmore
    ssc install freqindex
    ssc install matchit
    ssc install clustse
    ssc install parmest
    ssc install tmpdir
    ssc install sutex
    ssc install synth
    ssc install binscatter
    ssc install _gwtmean
    ssc install spmap
    ssc install shp2dta
    ssc install geoinpoly
    ssc install geo2xy
    ssc install mif2dta
    ssc install ftools
    ssc install moremata
    ssc install ivreg2
    ssc install reghdfe
    ssc install ppmlhdfe
    ssc install require
    ssc install texdoc
    ssc install acreg

    mata: mata mlib index

    net install rscript, from("https://raw.githubusercontent.com/reifjulian/rscript") replace

   Python packages are pinned in codePYTHON/requirements.txt.                */

*---------------------------------------------------------------
* SECTION 2: PREPARING DATA
*---------------------------------------------------------------

* ---------- 2.1 Weather extraction (Earth Engine) -----------

* Already run to completion on Kodama; their outputs are what 05 reads.
* Re-enable only to rebuild from scratch (multi-hour, needs an Earth Engine
* credential from 00_setup_earth_engine.py and Google Drive space).

* python script "$codePYTHON/02a_extract_prism_county.py"
* python clear

* python script "$codePYTHON/04a_extract_era5_county.py"
* python clear

* [PLACEHOLDER] WMA-level extraction (02b, 04b), pending WMA shapefiles.

* ------ 2.2 Weather aggregation and derived variables -------

python script "$codePYTHON/05_aggregate_daily_to_monthly.py"
python clear

python script "$codePYTHON/06_build_derived_weather_vars.py"
python clear

* Winter severity index at county-winter-year grain, read by both the merge
* (2.5) and the Tier 2 exhibits (SECTION 3). Built here rather than in the
* merge so the descriptives do not depend on a Phase 6 output.
python script "$codePYTHON/06c_build_winter_severity.py"
python clear

* ------------------ 2.3 County population -------------------

* 08a is separate because CT reports planning regions, not counties.
* 08b's CT override reads 08a's output and raises if it isn't there.
* NOTE: 08b with no arguments is the full CONUS x 1981-2025 build, including
* downloads on a cold cache. Pass --years/--states to scope a test run.
python script "$codePYTHON/08a_population_ct_towns.py"
python clear

python script "$codePYTHON/08b_population_county.py"
python clear

* -------- 2.4 Upstream panels from the other two RAs --------

/* Nicole's and Charvi's appends, in their own repos. 2.5 reads staged copies
   inside this project, so this block is what refreshes them. Off unless
   `run_upstream' is 1 at the top of SECTION 0 -- these scripts are owned by
   their authors, write into their own trees, and have never been run from
   here.

   Two things must be settled before it is turned on:
     - Nicole's append writes US_deer_harvest_county_year.dta (no date), while
       2.5 reads US_deer_harvest_county_year_04sep2026.dta. Decide whether the
       staged copy stays date-stamped (and this block stamps it) or the merge
       follows the live name.
     - Charvi's append has no visible output in VehicleCollisionsDataRepo --
       no collisions_CONUS_*, no US_*, no dvcs_US_*. Its output path is the
       placeholder below and the block will refuse to run until it is filled
       in. That path is also what un-freezes the collisions sample: the
       snapshot in dataRAW predates her 2019-2020 updates.                   */

local collisions_append_output "<CONFIRM WITH CHARVI>"

if `run_upstream' {

    do "$pathUngulates/codeSTATA/deer_harvest_national_append.do"
    copy "$pathUngulates/dataCLEAN/US_deer_harvest_county_year.dta" ///
         "$dataSTATA/US_deer_harvest_county_year.dta", replace

    if "`collisions_append_output'" == "<CONFIRM WITH CHARVI>" {
        di as error "SECTION 2.4: collisions append output path is still the " ///
                    "placeholder. Fill in collisions_append_output above, or " ///
                    "set run_upstream = 0 to use the staged snapshot."
        exit 601
    }

    do "$pathCollisions/codeSTATA/data_append_state_collisions_files.do"
    copy "`collisions_append_output'" ///
         "$dataRAW/Collisions/collisions_CONUS_county_year.dta", replace
}

* ---------- 2.5 Merged county-year analysis panel -----------

* Writes $dataSTATA/main_data_county_year.dta, the input to SECTIONS 3-5.
* Merge posture and the four winter regressors: see that file's header.
do "$codeSTATA/build_main_data_county_year.do"

* Diagnostic only. Writes $tables/checks/animal_deer_backfill_violations.csv.
do "$codeSTATA/check_animal_deer_backfill.do"

*---------------------------------------------------------------
* SECTION 3: DESCRIPTIVE DATA ANALYSIS
*---------------------------------------------------------------

/* 09a and 09b are GENERATED from 09_descriptive_weather_full.ipynb by
   make_scripts.py -- edit the notebook, then regenerate. Do not edit by hand.
   09b must run before 10, which asserts every exhibit it expects exists.
   Since 09/17/2026 this section no longer depends on 2.5: the WSI exhibits
   read 06c's CSV rather than the merged .dta.                               */

python script "$codePYTHON/09a_descriptive_weather_tier1.py"
python clear

python script "$codePYTHON/09b_descriptive_weather_tier2.py"
python clear

do "$codeSTATA/10_generate_weather_report.do"

*---------------------------------------------------------------
* SECTION 4: REGRESSION ESTIMATION
*---------------------------------------------------------------

* --------- 4.1 Collisions on winter weather (Wendy) ---------

* Estimation only. Writes the 40-file .ster grid under
* $estimates/collisions_weather/ plus _run_settings.txt, which 5.1 reads back.
* Specification switches are SECTION 1 of that file.
do "$codeSTATA/estimates_generate_collisions_weather.do"

* ------- 4.2 Deer harvest on winter weather (Nicole) --------

* WP Tables 1-3, in this order. Each estimates AND writes its own table to
* $tables/wildlife_weather/, so they sit here rather than in SECTION 5.
do "$codeSTATA/regression_log_harvest.do"

do "$codeSTATA/regression_harvest_per1000.do"

do "$codeSTATA/regression_harvest_zscore.do"

*---------------------------------------------------------------
* SECTION 5: MAIN ANALYSIS TABLES & FIGURES
*---------------------------------------------------------------

* ---------- 5.1 Collision tables (Tables 4 and 5) -----------

* Reads 4.1's .ster grid back and writes
* $tables/collisions_weather/table_collisions_weather_{share,rate}.tex
* plus the four per-panel fragments each one \ExpandableInput's.
do "$codeSTATA/estimates_tables_collisions_weather.do"

* ---------- 5.2 Where the other exhibits come from ----------

* Tables 1-3: written by 4.2. Tier 2 exhibits and the PDF report: SECTION 3.

*---------------------------------------------------------------
* SECTION 6: ROBUSTNESS CHECKS
*---------------------------------------------------------------



*---------------------------------------------------------------
* END
*---------------------------------------------------------------

log close main
