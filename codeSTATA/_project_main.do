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
  09/17/2026 Wendy Wang: cut the commentary down to one or two lines per
    step; the context it carried is in the child scripts' own headers, and
    the open items are tracked separately.
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

* ------------------ 2.3 County population -------------------

* 08a is separate because CT reports planning regions, not counties.
* 08b's CT override reads 08a's output and raises if it isn't there.
python script "$codePYTHON/08a_population_ct_towns.py"
python clear

python script "$codePYTHON/08b_population_county.py"
python clear

* -------- 2.4 Upstream panels from the other two RAs --------

/* Nicole's and Charvi's, in their own repos. 2.5 reads the .dta they produce,
   already staged here. Left commented until they confirm these are the right
   entry points and how the output should be copied across.                  */

* do "$pathUngulates/codeSTATA/deer_harvest_national_append.do"
* do "$pathCollisions/codeSTATA/data_append_state_collisions_files.do"

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
   09b must run before 10, and after 2.5: one 09b exhibit reads
   winter_severity_index out of the merged .dta.                             */

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
