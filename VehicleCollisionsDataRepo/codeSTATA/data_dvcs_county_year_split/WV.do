/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
07/26/2020 [Siyue Ouyang]: add data in ~dataRaw, update
05/23/2021 [Rukhshan Arif Mian]: moved gen year command to line 73. added year in all the keep commands. year is generated based off a return list local variable. thus it needs to be added as soon as that local variable is defined otherwise we end up losing it.
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

*************************WV
/*----------------------------------------------------*/
      /* [>   1.  Total 08-14   <] */
/*----------------------------------------------------*/
clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

clear
local file_name = "$path/dataRAW/DVCs/WV/TotalCrash.2008-2014.CountySeverity.Kinsey.xls"
import excel using "`file_name'" , describe

forvalues s = 1/`r(N_worksheet)' {
    clear
    local file_name = "$path/dataRAW/DVCs/WV/TotalCrash.2008-2014.CountySeverity.Kinsey.xls"
    import excel using "`file_name'" , describe
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    di "`s'"
	gen year = substr("`r(worksheet_`s')'",1,4)

    if `s' ==1 {
	    
        keep b e h k year
        ren b county_name
        ren e total_total
        ren h total_injury
        ren k total_injuries
        drop in 1
    }
 
    else if `s' ==2 | `s' ==3 {
        ren b county_name
        ren crashes total_total
        ren injurycrashes total_injury
        ren totalinjuries total_injuries
        keep county_name total_total total_injury total_injuries year
    }
 
    else if `s' >= 4 {
        if `s' ==5 {
            ren b county_name
        }
        else {
            ren a county_name
        }
        ren crashes total_total
        ren injurycrashes total_injury
        ren totalinjuries total_injuries
        ren fatalities total_fatalities
        keep county_name total_total total_injury total_injuries total_fatalities year
    }
	

    append using `fullfile', force
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me
drop if county_name == ""
destring total_injury total_injuries total_fatalities total_total year, replace
sort county_name year, stable


tempfile total
save `total', replace
 
/*----------------------------------------------------*/
      /* [>   2.  Animal 07-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/WV/AnimalCrash.2007-2014.Intersection.Kinsey.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring firstrow case(lower) clear

keep countyname date numberofinjuries numberoffatalities
ren countyname county_name
gen year = substr(date, -4,.)
drop date

destring numberoffatalities numberofinjuries year, replace


egen animal_fatal = total(numberoffatalities>0), by(county year) // animal_fatal
egen animal_injury = total(numberofinjuries>0 & numberoffatalities==0 ), by(county year) // animal_injury
bys county year: gen animal_total =_N // animal_total
bys county year: egen animal_fatalities=total(numberoffatalities) // animal_fatalities
bys county year: egen animal_injuries =total(numberofinjuries) // animal_injuries
drop numberoffatalities numberofinjuries

duplicates drop

tempfile animal
save `animal', replace

/*----------------------------------------------------*/
      /* [>   3.  Deer 13   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/WV/DeerCarcass.2013.County.Kinsey.xls"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring cellrange(A3:O68) firstrow case(lower) clear

keep districtcounty countytotal
ren districtcounty county_name
ren countytotal deer_total
drop if county_name=="TOTAL"

destring deer_total, replace
gen year = 2013

tempfile deer
save `deer', replace

merge 1:1 county_name year using `total', nogen
merge 1:1 county_name year using `animal', nogen

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""



assert  total_injury>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_fatalities>=0 ///
    & animal_injuries>=0 ///
    & animal_total>=0 ///
    & deer_total>=0, fast // sanity check


/*----------------------------------------------------*/
      /* [>   4.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/

* creating a balanced dataset
fillin year county_name
drop _fillin	

gen state_letter_code  = "WV" // add state abbreviation
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == "" | county_name == "statewide"

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
save "$working_data/dvcs_WV_county_year_`T1'_`T2'.dta" ,replace
