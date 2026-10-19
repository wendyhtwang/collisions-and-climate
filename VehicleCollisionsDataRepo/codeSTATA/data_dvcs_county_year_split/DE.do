/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
05/23/2021 [Rukhshan Arif Mian]: added line 131 to destring all deer* related variables.

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

*************************DE (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 04-19   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/DE/DE.TotalCrash.2004-2019.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalues s =1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(A1:E7) firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    tempfile newstata`s'
    save `newstata`s'', replace
}


local Nminus = `r(N_worksheet)'-1
forvalues s = 1/`Nminus' {
    append using `newstata`s'', force
}

rename crashcomparisonbycounty crash_type

replace crash_type = lower(crash_type)
replace crash_type = subinstr(crash_type," ","_",. )

egen id = group(year crash_type )
rename newcastlecounty totalnewcastle
rename kentcounty totalkent
rename sussexcounty totalsussex
rename statewide totalstatewide
reshape long total, i(id) j(county_name) string
drop id
reshape wide total, i(county_name year) j(crash_type) string
 
rename totalfatal_crashes total_fatal
rename totalfatalities total_fatalities
rename totalinjuries total_injuries
rename totalpersonal_injury_crashes total_injury
rename totalproperty_damage_crashes total_pdo
rename totaltotal_crashes total_total

tempfile de_total
save `de_total', replace

/*----------------------------------------------------*/
      /* [>   2.  Deer 10-15  <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/DE/DE.DeerCrash.2010-2015.CountySeverity.Hyland.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear

    rename a year

    tempfile newstata`s'
    save `newstata`s'', replace
}

merge 1:1 county year using `newstata2'
drop _merge
merge 1:m county year using `newstata1'
drop e f g h i j k l _merge

replace crashclassification = "deer_fatal" if crashclassification == "Fatality Crash "
replace crashclassification = "deer_injury" if crashclassification == "Personal Injury Crash "
replace crashclassification = "deer_pdo" if crashclassification == "Property Damage Only "
*spread crashclassification ofcrashes

rename killed deer_fatalities
rename injuries deer_injuries
rename county county_name
rename ofcrashes number

replace county_name = lower(county_name)
replace county_name = subinstr(county_name," ","",. )

destring year number, replace
destring deer*, replace

egen id = group(year county_name)
reshape wide number, i(id year county_name) j(crashclassification) string
drop id

rename numberdeer_fatal deer_fatal
rename numberdeer_injury deer_injury
rename numberdeer_pdo deer_pdo


foreach var in deer_fatal deer_fatalities {
    replace `var' = 0 if `var' ==. & year >=2010 & year<=2015
}

* imputation

gen deer_total = deer_fatal+deer_injury+deer_pdo
gen imputation_flag_deer_total = 1
/*----------------------------------------------------*/
      /* [>   3.  Merge with total data    <] */
/*----------------------------------------------------*/
merge 1:1 year county_name using `de_total'
drop _merge
gen state_letter_code  = "DE" // add state abbreviation

destring total_total ///
        total_fatal ///
        total_injury ///
        total_pdo ///
        total_fatalities ///
        total_injuries ///
        deer_fatal ///
        deer_injury ///
        deer_pdo ///
        deer_fatalities ///
        deer_injuries, ignore("," "NA" " ") replace

assert total_fatal>=0 ///
    & total_fatalities>=0 ///
    & total_injury>=0 ///
    & total_injuries>=0 ///
    & total_pdo>=0 ///
    & total_total>=0 ///
    & deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_pdo>=0 ///
    & deer_fatalities>=0 ///
    & deer_injuries>=0, fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "new castle" if county_name == "newcastle"


/*----------------------------------------------------*/
      /* [>   4. Merge with  state_county_identifiers <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name =="statewide"

order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year

sort state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_DE_county_year_`T1'_`T2'.dta" ,replace
