/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Kaveri Chhikara
Major Versions/Revisions:
09/21/2021 [Kaveri Chhikara]: created
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
      /* [>   TVCs 2001-2018  */
/*----------------------------------------------------*/

/* total fatal */  
clear 
local file_name = "$path/dataCSV/DVCs/NJ/NJ.TVC.01-18.County.Fatal.xlsx"
import excel using "`file_name'" , firstrow clear

foreach v of var Atlantic-Total{
    rename `v' total_fatal`v'
}

reshape long total_fatal, i(Year) j(county_name) string  

tempfile total_fatal
save `total_fatal', replace

/* total injury */ 
clear 
local file_name = "$path/dataCSV/DVCs/NJ/NJ.TVC.01-18.County.Injury.xlsx"
import excel using "`file_name'" , firstrow cellrange(A1:W19) clear

foreach v of var Atlantic-Total{
    rename `v' total_injury`v'
}


reshape long total_injury, i(Year) j(county_name) string  
 
merge 1:1 Year county_name using `total_fatal' , nogen

tempfile total_injury_fatal
save  `total_injury_fatal', replace

/* total total*/ 
clear 
local file_name = "$path/dataCSV/DVCs/NJ/NJ.TVC.01-18.County.Total.xlsx"
import excel using "`file_name'" , firstrow cellrange(A1:W19) clear

foreach v of var Atlantic-Total{
    rename `v' total_total`v'
}

reshape long total_total, i(Year) j(county_name) string  
 
merge 1:1 Year county_name using `total_injury_fatal' , nogen


foreach x in total_total total_injury total_fatal {
	replace `x'  = strtrim(`x')
 	replace `x' = ustrtrim(`x')
 	replace `x' = subinstr(`x', ",", "", .)
 	replace `x' = subinstr(`x', " ", "", .)
 	replace `x' = subinstr(`x', "-", "", .)
	}

rename Year year
order county_name year total*
sort county_name year
destring year- total_fatal, replace

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "cape may" if county_name == "capemay"

/*
imputation
*/

gen total_pdo = total_total - total_fatal - total_injury 
gen imputation_flag_pdo = 1

/*----------------------------------------------------*/
      /* [>   Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/

generate state_letter_code = "NJ"
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name=="missing" | county_name == "total"

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
save "$working_data/dvcs_NJ_county_year_`T1'_`T2'.dta" ,replace
