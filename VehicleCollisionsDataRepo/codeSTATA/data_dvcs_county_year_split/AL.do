/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
*******************************************************************************/
/**********************************************************************/
/*  SECTION 0: root directory
    Notes: */
/**********************************************************************/
cap log close
clear all
set more off, permanently
set matsize 11000
set maxvar 32767
set scheme s1mono

confirmdir "F:/GDrive/"
if r(confirmdir) == "0" {
  local rootDir = "F:/GDrive/"
}

confirmdir "E:/GDrive/"
if r(confirmdir) == "0" {
  local rootDir = "E:/GDrive/"
}

confirmdir "D:/GoogleDrive/"
if r(confirmdir) == "0" {
  local rootDir = "D:/GoogleDrive/"
}
confirmdir "C:/GoogleDrive/"
if r(confirmdir) == "0" {
  local rootDir = "C:/GoogleDrive/"
}
confirmdir "/Users/air/Google Drive/"
if r(confirmdir) == "0" {
  local rootDir = "/Users/air/Google Drive/"
}


global path "`rootDir'/WolvesImpacts/"

global working_data "$path/dataSTATA/intermediate/collisions/"

/*-----------------End of SECTION 0: root directory --------------*/

/*-------------------------
  To Do:
     - [1] derive dta files for all the states
     - [2] merge dta files
-------------------------*/

/*----------------------------------------------------*/
      /* [>   1.  derive dta for 49 states in the folder (~/dataCSV/DVCs/) <] */
/*----------------------------------------------------*/
*************************AL (data not ready)
*clear

*local file_name = "`file_name'"

*import excel using "`file_name'" , describe

*forvalues s =1/`r(N_worksheet)' {

*import excel using "`file_name'", sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear

*tempfile newstata`s'
*save `newstata`s'', replace

*}


*clear

*import excel using "`file_name'" , describe
*forvalues s = 1/`r(N_worksheet)' {

*append using `newstata`s'', force

*}

*gen state_letter_code  = "AL" // add state abbreviation

*import excel using "`file_name'" , describe
*save "$working_data/dvcs_county_year_`r(worksheet_1)'_`r(worksheet_`r(N_worksheet)')'.dta" ,replace




