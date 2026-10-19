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

*************************SC (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 99-17   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/SC/SC.TVC.99-17.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    tempfile newstata`s'
    save `newstata`s'', replace
}


local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

drop h i

rename motorvehicletrafficcollisions county_name
rename totalcollision total_total
rename fatalcollision total_fatal
rename injurycollision total_injury
rename personskilled total_fatalities
rename personsinjured total_injuries
rename pdo total_pdo


destring total_total ///
        total_fatal ///
        total_injury ///
        total_fatalities ///
        total_injuries ///
        total_pdo ///
        year, ignore("," "NA" " ") replace

assert total_total>=0 ///
    & total_fatal>=0 ///
    & total_injury>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_pdo>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "sc total"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""

tempfile CSV
save `CSV', replace

/*----------------------------------------------------*/
      /* [>   2.  Deer 07-15   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/SC/SC.DeerCrash.2007-2014.CountySeverity.Thomas.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(A5:G52) firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    tempfile newstata`s'
    save `newstata`s'', replace
}


local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}
 
rename a county_name
rename e deer_total
rename fatal deer_fatal
rename injury deer_injury
rename f deer_fatalities
rename g deer_injuries
rename propertydamageonly deer_pdo


destring deer_total ///
        deer_fatal ///
        deer_injury ///
        deer_fatalities ///
        deer_injuries ///
        deer_pdo ///
        year, ignore("," "NA" " ") replace

assert deer_total>=0 ///
    & deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_fatalities>=0 ///
    & deer_injuries>=0 ///
    & deer_pdo>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "sc total"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""


/*----------------------------------------------------*/
      /* [>   3.  Merge with CSV   <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `CSV'
br if _merge != 3
drop _merge

gen state_letter_code  = "SC" // add state abbreviation


/*----------------------------------------------------*/
      /* [>   2.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == "" | county_name == "total"
sort county_name year, stable 
order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_SC_county_year_`T1'_`T2'.dta" ,replace
