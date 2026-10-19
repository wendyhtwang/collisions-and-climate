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

*************************NY (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 96-00   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/NY/NY.TVC.96-00.CountySeverity.xlsx"
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

drop i j k l m population

rename county county_name
rename fatalaccidents total_fatal
rename deaths total_fatalities
rename injuries total_injuries
rename personalinjuryaccidents total_injury
rename propertydamageaccidents total_pdo
rename totalreportableaccidents total_total

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
replace county_name="total" if strpos(county_name, "total")
drop if county_name == ""

sort county_name year, stable

tempfile ny_total
save `ny_total', replace

/*----------------------------------------------------*/
      /* [>   2.  Animal 08-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/NY/NY.AVC.08-14.CountySeverity.xlsx"
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

rename crashesinvolvingacollisionwi county_name
rename totalcrashes animal_total
rename fatal animal_fatal
rename personalinjury animal_injury
rename propertydamage animal_pdo

destring animal_total ///
        animal_fatal ///
        animal_injury ///
        animal_pdo ///
        year, ignore("," "NA" " ") replace

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total nys crashes involving an animal"

sort county_name year, stable

tempfile ny_animal
save `ny_animal', replace

/*----------------------------------------------------*/
      /* [>   3.  Deer 08-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/NY/NY.DVC.08-14.CountySeverity.xlsx"
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

rename crashesinvolvingacollisionwi county_name
rename totalcrashes deer_total
rename fatal deer_fatal
rename personalinjury deer_injury
rename propertydamage deer_pdo

destring deer_total ///
        deer_fatal ///
        deer_injury ///
        deer_pdo ///
        year, ignore("," "NA" " ") replace

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total nys crashes involving deer"

sort county_name year, stable

 
/* [> merge with wild animal and total data <] */
merge 1:1 year county_name using `ny_animal'
*br if _merge != 3
drop _merge

*sort county_name ///
joinby county_name year using `ny_total', unmatched(both) ///
sorted by: county_name
sort county_name year, stable

merge 1:1 year county_name using `ny_total'
br if _merge != 3
sort year
drop _merge

tempfile CSV
save `CSV', replace


/*----------------------------------------------------*/
      /* [>   4.  Total 09-18   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/NY/TotalVC.2009-20.CountySeverity.Web.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring cellrange(`r(range_`s')') firstrow case(lower) clear

keep severitytype county total year
ren county county_name
replace severitytype = "total_total" if severitytype ==""
replace severitytype = "total_fatal" if severitytype =="Fatal"
replace severitytype = "total_injury" if severitytype =="Personal Injury"
replace severitytype = "total_pdo" if severitytype =="Property Damage"

drop if year =="2019 Preliminary*"
drop if year =="2020 Preliminary*"

*spread severitytype total
reshape wide total, i(county_name year) j(severitytype) string 
renpfix total 

destring total_total ///
        total_fatal ///
        total_injury ///
        total_pdo ///
        year, ignore("," "NA" " ") replace

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name==""

sort county_name year, stable


/*----------------------------------------------------*/
      /* [>   5.  Merge with CSV  & state_county_identifiers <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `CSV', update //CSV is newer
drop _merge

gen state_letter_code  = "NY" // add state abbreviation

assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_pdo>=0 ///
    & total_total>=0 ///
    & deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_pdo>=0 ///
    & deer_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_pdo>=0 ///
    & animal_total>=0 , fast // sanity check

drop if strpos(county_name, "unknown")

/*----------------------------------------------------*/
      /* [>   6.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
sort year
drop _merge
drop if county_name == "total"
order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year

/* [> imputation <] */ 
replace total_fatal = total_total-total_pdo-total_injury

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_NY_county_year_`T1'_`T2'.dta" ,replace
