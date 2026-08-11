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

/*

    Add files in the order they need to run, especially in the data building part

    To run Stata, R, and Python scripts, use: 

        do "$path/codeSTATA/<script_name>.do"

        rscript using "$path/codeSTATA/<script_name>.R"

        shell python.exe do "$path/codeSTATA/<script_name>.py"

        where <script_name> is the file name you're trying to run

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


********************************************************************************
************************ Descriptive Data Analysis *****************************
********************************************************************************


********************************************************************************
************************* Regression Estimation ********************************
********************************************************************************


********************************************************************************
*********************** Main Analysis Tables & Figures *************************
********************************************************************************


********************************************************************************
**************************** Robustness Checks *********************************
********************************************************************************



