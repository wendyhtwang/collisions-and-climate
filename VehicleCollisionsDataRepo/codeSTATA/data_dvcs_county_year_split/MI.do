	/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
10/05/2021 [Kaveri Chhikara]: addded 2000, 2005 and 2006 data for TVCs and DVCs.
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

*************************MI (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 92-18   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/MI/MI.TVC.92-18.CountySeverity.xlsx"
import excel using "`file_name'" , describe


foreach s of numlist 1/`r(N_worksheet)' {
    if `s' == 1 {
        import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(A1:G86) firstrow case(lower) clear
    }
    else {
        import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    }

    gen year = `r(worksheet_`s')'

    if year > = 2014 {
        rename reportedtrafficcrashesbycoun county
        rename allcrashes all
    }

    tempfile newstata`s'
    save `newstata`s'', replace
}

local Nminus = `r(N_worksheet)'-1

foreach s of numlist 1/`Nminus'  {
    append using `newstata`s'', force
}
 
drop h-x
 
rename county county_name
rename fatal total_fatal
rename personskilled total_fatalities
rename personsinjured total_injuries
rename injury total_injury
rename propertydamage total_pdo
rename all total_total

destring total_total ///
        total_fatal ///
        total_injuries ///
        total_injury ///
        total_pdo ///
        total_fatalities ///
        year, ignore("," "NA" " ") replace

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "totals"
drop if county_name==""

tempfile total
save `total', replace
 
/*----------------------------------------------------*/
      /* [>   2.  Deer 94-18   <] */
/*----------------------------------------------------*/

clear
local file_name = "$path/dataCSV/DVCs/MI/MI.DVC.94-18.CountySeverity.xlsx"
import excel using "`file_name'" , describe


foreach s of numlist 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    if year > = 2014 {
        rename allcrashes all
    }

    tempfile newstata`s'
    save `newstata`s'', replace
}

local Nminus = `r(N_worksheet)'-1

foreach s of numlist 1/`Nminus' {
    append using `newstata`s'', force
}
 
drop h-i 

rename county county_name
rename all deer_total
rename fatal deer_fatal
rename injury deer_injury
rename propertydamage deer_pdo
rename personskilled deer_fatalities
rename personsinjured deer_injuries

destring deer_total ///
        deer_fatal ///
        deer_injury ///
        deer_pdo ///
        deer_fatalities ///
        deer_injuries ///
        year, ignore("," "NA" " ") replace

drop if county_name==""
drop if county_name=="unknown"
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "van buren" if county_name == "van buren  "
replace county_name = "total" if county_name == "totals"

tempfile deer
save `deer', replace
 
/*----------------------------------------------------*/
      /* [>   3.  Merge   <] */
	  /* [> merge deer and total data <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `total'
br if _merge != 3
sort year
drop _merge
 
gen state_letter_code  = "MI" // add state abbreviation

assert total_fatal>=0 ///
    & total_fatalities>=0 ///
    & total_injury>=0 ///
    & total_injuries>=0 ///
    & total_pdo>=0 ///
    & total_total>=0 ///
    & deer_fatal>=0 ///
    & deer_fatalities>=0 ///
    & deer_injury>=0 ///
    & deer_injuries>=0 ///
    & deer_pdo>=0 ///
    & deer_total>=0 , fast // sanity check

replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "new castle" if county_name == "newcastle"
replace county_name = "total" if county_name == "statewide total"
drop if county_name=="unknown"

/*----------------------------------------------------*/
      /* [>   3.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == ""

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
save "$working_data/dvcs_MI_county_year_`T1'_`T2'.dta" ,replace
