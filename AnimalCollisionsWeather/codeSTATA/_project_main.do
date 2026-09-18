/*==============================================================
FILE:     _project_main.do
PROJECT:  Weather Changes, Ungulate Populations, & Vehicle Collisions

PURPOSE:  Master script. Every production stage, in run order. Package
          installs, validators and diagnostics are documented in
          STATA_OVERVIEW.md and run by hand, not from here.

CHANGELOG:
  09/18/2026:
    - Populated Sections 2-5 w/ the scripts covering up to the preliminary
    regression analysis (July-September'2026).
    - 2.4 in Data Preparation is provenance only -- 
    the collisions and wildlife panels are built in the sibling repos 
    and copied in; nothing there runs from here.
    - Python is called with `python script', not template's Windows-only
      shell form.
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

local rootDir = ""

confirmdir "/mnt/data_d/Dropbox/Research"
if r(confirmdir) == "0" local rootDir = "/mnt/data_d/Dropbox/Research"

if "`rootDir'" == "" {
    confirmdir "C:/Dropbox/Research"
    if r(confirmdir) == "0" local rootDir = "C:/Dropbox/Research"
}

if "`rootDir'" == "" {
    confirmdir "D:/Dropbox/Research"
    if r(confirmdir) == "0" local rootDir = "D:/Dropbox/Research"
}

if "`rootDir'" == "" {
    di as error "No Dropbox research root found. Add this machine's root above."
    exit 601
}

if "$path" == "" {
    global path = "`rootDir'/AnimalCollisionsWeather"
}

global codePYTHON "$path/codePYTHON"
global codeSTATA  "$path/codeSTATA"
global dataCSV    "$path/dataCSV"
global dataRAW    "$path/dataRAW"
global dataSTATA  "$path/dataSTATA"
global estimates  "$path/dataSTATA/estimates"
global figures    "$path/figures"
global tables     "$path/tables"
global reports    "$path/reports"

* Named log: children open unnamed logs and would close this one otherwise.
cap mkdir "$codeSTATA/logs"
cap log close main
log using "$codeSTATA/logs/_project_main.log", replace text name(main)

*---------------------------------------------------------------
* SECTION 1: USER-WRITTEN PACKAGES
*---------------------------------------------------------------

/* Installed once per machine:

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

   Python packages are pinned in codePYTHON/requirements.txt.                */

*---------------------------------------------------------------
* SECTION 2: PREPARING DATA
*---------------------------------------------------------------

* ---------- 2.1 Weather extraction (Earth Engine) -----------

* Run to completion; their outputs are what 05 reads. Multi-hour rebuild,
* needs an Earth Engine credential from 00_setup_earth_engine.py.

* python script "$codePYTHON/02a_extract_prism_county.py"
* python clear

* python script "$codePYTHON/04a_extract_era5_county.py"
* python clear

* ------ 2.2 Weather aggregation and derived variables -------

python script "$codePYTHON/05_aggregate_daily_to_monthly.py"
python clear

python script "$codePYTHON/06_build_derived_weather_vars.py"
python clear

* Winter severity index, read by the merge (2.5) and the Tier 2 exhibits.
python script "$codePYTHON/06c_build_winter_severity.py"
python clear

* ------------------ 2.3 County population -------------------

* 08b's CT override reads 08a's output, so 08a runs first. A bare 08b call is
* the full CONUS x 1981-2025 build and needs CENSUS_API_KEY in the environment.
python script "$codePYTHON/08a_population_ct_towns.py"
python clear

python script "$codePYTHON/08b_population_county.py"
python clear

* -------- 2.4 Panels from the sibling data repos ------------

/* Built outside this project and copied in; does not append state files here.
   Sibling repos of $path:
     UngulatePopulationDataRepo/codeSTATA/deer_harvest_national_append.do
       -> $dataSTATA/US_deer_harvest_county_year_04sep2026.dta
     VehicleCollisionsDataRepo/codeSTATA/data_append_state_collisions_files.do
       -> $dataRAW/Collisions/collisions_CONUS_county_year_1985_2020.dta
   The collisions repo has no national append output as of 9/18/26; the file
   above is an earlier snapshot.                                             */

* ---------- 2.5 Merged county-year analysis panel -----------

* Writes $dataSTATA/main_data_county_year.dta, the input to SECTIONS 3-5.
do "$codeSTATA/build_main_data_county_year.do"

*---------------------------------------------------------------
* SECTION 3: DESCRIPTIVE DATA ANALYSIS
*---------------------------------------------------------------

* 09a and 09b are generated from 09_descriptive_weather_full.ipynb by
* make_scripts.py -- do not edit by hand. 09b must run before 10.
python script "$codePYTHON/09a_descriptive_weather_tier1.py"
python clear

python script "$codePYTHON/09b_descriptive_weather_tier2.py"
python clear

do "$codeSTATA/10_generate_weather_report.do"

*---------------------------------------------------------------
* SECTION 4: REGRESSION ESTIMATION
*---------------------------------------------------------------

* Writes the .ster grid under $estimates/collisions_weather/ plus
* _run_settings.txt, which SECTION 5 reads back.
do "$codeSTATA/estimates_generate_collisions_weather.do"

* WP Tables 1-3, in this order. Each writes its own .tex to
* $tables/wildlife_weather/, so they have nothing in SECTION 5.
do "$codeSTATA/regression_log_harvest.do"

do "$codeSTATA/regression_harvest_per1000.do"

do "$codeSTATA/regression_harvest_zscore.do"

*---------------------------------------------------------------
* SECTION 5: MAIN ANALYSIS TABLES & FIGURES
*---------------------------------------------------------------

* WP Tables 4 and 5, plus the four per-panel fragments each \ExpandableInput's.
do "$codeSTATA/estimates_tables_collisions_weather.do"


*---------------------------------------------------------------
* SECTION 6: ROBUSTNESS CHECKS
*---------------------------------------------------------------

* Nothing wired yet. Candidates are listed in 
/AnimalCollisionsWeather/codeSTATA/STATA_OVERVIEW.md.

*---------------------------------------------------------------
* END
*---------------------------------------------------------------

log close main
