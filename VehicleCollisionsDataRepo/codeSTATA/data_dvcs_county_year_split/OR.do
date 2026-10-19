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

*************************OR (all data were kept)
/*----------------------------------------------------*/
      /* [>   1. Wild Animal 03-12   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/OR/OR.WAVC.03-12.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'", sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    tempfile newstata`s'
    save `newstata`s'', replace
}


local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

rename oregontrafficcrashesinvolving county_name
rename totalcrashes wild_animal_total
rename fatalcrahses wild_animal_fatal
rename nonfatalcrashes wild_animal_injury
rename peoplekilled wild_animal_fatalities
rename peopleinjured wild_animal_injuries
rename propertydamageonly wild_animal_pdo

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""

tempfile CSV
save `CSV', replace

/*----------------------------------------------------*/
      /* [>   2.  Total & Animal & Deer 02-18   <] */
/*----------------------------------------------------*/
clear
global path_or "$path/dataRAW/DVCs/OR/Crash records/"
cd "$path_or/"
local all_files : dir . files "CRASH*.xlsx"
display `all_files'


tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace
set excelxlsxlargefile on

foreach file in `all_files' {
    *import excel using "`file'" , describe
    import excel using "`file'", firstrow case(lower) clear
	 
    keep crash_yr_no cnty_nm crash_typ_short_desc crash_svrty_short_desc crash_evnt_1_cd tot_fatal_cnt tot_inj_cnt
	
    ren crash_yr_no year
    ren cnty_nm county_name
    ren crash_typ_short_desc accdtype
    ren crash_evnt_1_cd cause
    ren crash_svrty_short_desc severity
    ren tot_fatal_cnt totfatl
    ren tot_inj_cnt totinj

    destring totinj totfatl, replace
	replace accdtype = ustrtrim(accdtype)
	replace cause = ustrtrim(cause)
	
    egen total_fatal = total(severity =="FAT"), by(county year) // total_fatal
    egen total_injury = total(severity =="INJ"), by(county year) // total_injury
    egen total_pdo = total(severity =="PDO"), by(county year) // total_pdo
    bys county year: egen total_fatalities=total(totfatl) // total_fatalities
    bys county year: egen total_injuries =total(totinj) // total_injuries
    bys county year: gen total_total =_N // total_total

    egen animal_fatal = total(severity =="FAT" &  cause == "030" | cause == "031" | cause == "032" | cause == "033" | cause == "034" | cause == "035" | cause == "036" ), by(county year) // animal_fatal
    egen animal_injury = total(severity =="INJ" &  cause == "030" | cause == "031" | cause == "032" | cause == "033" | cause == "034" | cause == "035" | cause == "036"), by(county year) // animal_injury
    egen animal_pdo = total(severity =="PDO" & cause == "030" | cause == "031" | cause == "032" | cause == "033" | cause == "034" | cause == "035" | cause == "036"), by(county year) // animal_pdo
    egen animal_fatalities = total(totfatl*(cause == "030" | cause == "031" | cause == "032" | cause == "033" | cause == "034" | cause == "035" | cause == "036")), by(county year) // animal_fatalities
    egen animal_injuries = total(totinj*(cause == "030" | cause == "031" | cause == "032" | cause == "033" | cause == "034" | cause == "035" | cause == "036")), by(county year) // animal_injuries
    bys county year: egen animal_total =total(cause == "030" | cause == "031" | cause == "032" | cause == "033" | cause == "034" | cause == "035" | cause == "036")

    egen deer_fatal = total(severity =="FAT" & cause == "035"), by(county year) // deer_fatal
    egen deer_injury = total(severity =="INJ" & cause == "035"), by(county year) // deer_injury
    egen deer_pdo = total(severity =="PDO" & cause == "035"), by(county year) // deer_pdo
    egen deer_fatalities = total(totfatl*(cause == "035")), by(county year) // deer_fatalities
    egen deer_injuries = total(totinj*(cause == "035")), by(county year) // deer_injuries
    bys county year: egen deer_total =total(cause == "035") // deer_total
	
    drop severity accdtype totinj totfatl cause
    duplicates drop
    duplicates list county year
	

    /* save as a dta file*/
    append using `fullfile'
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

destring year, replace

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""

save "$working_data/OR/dvcs_OR_county_year_RAW_mid.dta", replace
/*----------------------------------------------------*/
      /* [>   2.  Merge with CSV   <] */
/*----------------------------------------------------*/
merge 1:1 county year using `CSV', update
br if _merge != 3
drop _merge

gen state_letter_code  = "OR" // add state abbreviation


assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_pdo>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_total>=0 ///
    & deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_pdo>=0 ///
    & deer_fatalities>=0 ///
    & deer_injuries>=0 ///
    & deer_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_pdo>=0 ///
    & animal_fatalities>=0 ///
    & animal_injuries>=0 ///
    & animal_total>=0 ///
    & wild_animal_total>=0 ///
    & wild_animal_fatal>=0 ///
    & wild_animal_injury>=0 ///
    & wild_animal_fatalities>=0 ///
    & wild_animal_injuries>=0 ///
    & wild_animal_pdo>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1

/*----------------------------------------------------*/
      /* [>   3.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == ""
drop if strpos(county_name , "total")

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
save "$working_data/dvcs_OR_county_year_`T1'_`T2'.dta" ,replace
