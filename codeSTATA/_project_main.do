/*******************************************************************************
Program: _project_main.do

*******************************************************************************/

cap log close
clear all
set more off, permanently
set matsize 11000
set maxvar 32767
set scheme s1mono

confirmdir "C:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "C:/Dropbox/Research"
}
confirmdir "D:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "D:/Dropbox/Research"
}

global path "`rootDir'/AnimalCollisionsWeather"

/* Python interpreter used for all `python script` calls below.
   Uncomment and point at the project environment so the version that produced
   the results is documented. Run `python query` to see what is currently set. */

* python set exec "C:/Users/<user>/miniconda3/envs/acw/python.exe", permanently

/*

    Add files in the order they need to run, especially in the data building part

    To run Stata, R, and Python scripts, use: 

        do "$path/codeSTATA/<script_name>.do"

        rscript using "$path/codeSTATA/<script_name>.R"

        python script "$path/codePYTHON/<script_name>.py"

        where <script_name> is the file name you're trying to run

    Note: do NOT use `shell python.exe ...` -- Stata ignores the exit code of a
    shelled command, so a failed Python script will not stop this do-file.
    `python script` raises a Stata error on any uncaught Python exception.

*/


/* 
    Package installation 

    [ADD HERE NAMES OF USER-WRITTEN PACKAGES THAT NEED TO BE INSTALLED]

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
    ssc install texdoc

    net install rscript, from("https://raw.githubusercontent.com/reifjulian/rscript/master") replace

    [IN CASE WE USE R AND PYTHON, HAVE LIBRARY/PACKAGE INSTALLATION SCRIPTS HERE]
*/




********************************************************************************
***************************** Preparing Data ***********************************
********************************************************************************

/* Weather pipeline (PRISM/ERA5 extraction, aggregation, derived vars) */

python script "$path/codePYTHON/02a_extract_prism_county.py"
python clear

python script "$path/codePYTHON/04a_extract_era5_county.py"
python clear

python script "$path/codePYTHON/05_aggregate_daily_to_monthly.py"
python clear

python script "$path/codePYTHON/06_build_derived_weather_vars.py"
python clear


********************************************************************************
************************ Descriptive Data Analysis *****************************
********************************************************************************

/* Weather descriptives. Tier 1 is internal QA; Tier 2 is the exhibit set that
   10_generate_weather_report.do knits into the dated PDF report. Both are
   generated from codePYTHON/09_descriptive_weather_full.ipynb by
   codePYTHON/make_scripts.py -- edit the notebook, then regenerate.

   09b must run before 10, which asserts that every exhibit it expects exists.

   KNOWN ORDERING GAP (9/10/26). One exhibit in 09b -- the Winter Severity
   Index choropleth -- reads winter_severity_index from
   $path/dataSTATA/main_data_county_year.dta, because SECTION 7 of
   build_main_data_county_year.do is the single place the project's four winter
   measures are constructed, and recomputing the index here would create a
   second definition of it.

   That makes a Phase 4 output depend on a Phase 6 input, and this file runs the
   descriptives BEFORE the estimation section. So on a clean end-to-end run the
   .dta does not exist yet: 09b prints a NOTE, skips the two WSI exhibits, and
   10 omits that section. Everything else is unaffected -- the report still
   builds -- but it builds one section short, quietly.

   To get the WSI exhibits, run build_main_data_county_year.do first, then
   re-run 09b and 10.

   The real fix is to move the index's construction upstream into
   06_build_derived_weather_vars.py, where it belongs: it is PRISM cold days
   plus ERA5 snow days, both pure weather inputs, and the merge script would
   then read it rather than build it. That touches a script the PI has already
   signed off and that Table 1 was run against, so it is deferred to the code
   review rather than done here. */

python script "$path/codePYTHON/09a_descriptive_weather_tier1.py"
python clear

python script "$path/codePYTHON/09b_descriptive_weather_tier2.py"
python clear

do "$path/codeSTATA/10_generate_weather_report.do"



********************************************************************************
************************* Regression Estimation ********************************
********************************************************************************


********************************************************************************
*********************** Main Analysis Tables & Figures *************************
********************************************************************************


********************************************************************************
**************************** Robustness Checks *********************************
********************************************************************************



