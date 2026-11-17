/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
05/23/2021 [Rukhshan Arif Mian]: added line 131 to destring all deer* related variables.
04/18/2026 [Emily Price]: updated to 2024 data; fixed alcohol crash import section
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

global path "`rootDir'/VehicleCollisionsDataRepo"
global working_data "$path/dataSTATA/"

/*----------------------------------------------------*/
/* [> 1. Total 04-24 <] */
/*----------------------------------------------------*/

/* Here, we're using the spreadsheet of total crash data found in the dataCSV folder. Entries in that spreadsheet are taken from the PDFs in the dataRAW folder */

clear
local file_name = "$path/dataCSV/DVCs/DE/DE.TotalCrash.2004-2024.CountySeverity.xlsx"
import excel using "`file_name'", describe

forvalues s = 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(A1:E7) firstrow case(lower) clear
    gen year = `r(worksheet_`s')'
    tempfile newstata`s'
    save `newstata`s'', replace
}

local Nminus = `r(N_worksheet)' - 1
forvalues s = 1/`Nminus' {
    append using `newstata`s'', force
}

rename crashcomparisonbycounty crash_type
replace crash_type = lower(crash_type)
replace crash_type = subinstr(crash_type, " ", "_", .)

egen id = group(year crash_type)
rename newcastlecounty totalnewcastle
rename kentcounty      totalkent
rename sussexcounty    totalsussex
rename statewide       totalstatewide

reshape long total, i(id) j(county_name) string
drop id
reshape wide total, i(county_name year) j(crash_type) string

gen county_code = .
replace county_code = 1 if county_name == "kent"
replace county_code = 3 if county_name == "newcastle"
replace county_code = 5 if county_name == "sussex"

tostring county_code, replace
replace county_code = "0"  + county_code if length(county_code) == 2
replace county_code = "00" + county_code if length(county_code) == 1
gen fips = "10" + county_code
destring fips, replace

/* Changing naming conventions to match with other states */

rename totalfatal_crashes           fatal_collision
rename totalfatalities              total_fatalities
rename totalinjuries                total_injuries
rename totalpersonal_injury_crashes injury_collision
rename totalproperty_damage_crashes pdo_collision
rename totaltotal_crashes           total_all_cause

tempfile de_total
save `de_total', replace

/*----------------------------------------------------*/
/* [> 2. Deer 10-15 <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/DE/DE.DeerCrash.2010-2015.CountySeverity.Hyland.xlsx"

/* Still looking for where this data originated from, as it isn't in the original PDF files */

* Sheet 1: Deer Involved Crashes (Year, County, Crash Classification, # of Crashes)
import excel using "`file_name'", allstring sheet("Deer Involved Crashes") case(lower) clear
drop in 1
rename A year
rename B county_name
rename C crashclassification
rename D number
keep year county_name crashclassification number
tempfile deer_crashes
save `deer_crashes', replace

* Sheet 2: Injuries Related to Deer Crashes (Year, County, Injuries)
import excel using "`file_name'", allstring sheet("Injuries Related to Deer Crashe") case(lower) clear
drop in 1
rename A year
rename B county_name
rename C deer_injuries
keep year county_name deer_injuries
tempfile deer_injuries
save `deer_injuries', replace

* Sheet 3: Deaths Related to Deer Crashes (Year, County, Killed)
import excel using "`file_name'", allstring sheet("Deaths Related to Deer Crashes") case(lower) clear
drop in 1
rename A year
rename B county_name
rename C deer_fatalities
keep year county_name deer_fatalities
tempfile deer_deaths
save `deer_deaths', replace

* Merge all three sheets
use `deer_crashes', clear
merge m:1 county_name year using `deer_injuries', nogen
merge m:1 county_name year using `deer_deaths', nogen

replace county_name = lower(county_name)
replace county_name = subinstr(county_name, " ", "", .)

replace crashclassification = "fatal_deer_collision"  if crashclassification == "Fatality Crash "
replace crashclassification = "injury_collision_deer" if crashclassification == "Personal Injury Crash "
replace crashclassification = "pdo_collision_deer"    if crashclassification == "Property Damage Only "

destring year number deer_injuries deer_fatalities, replace

foreach var in deer_fatalities deer_injuries {
    replace `var' = 0 if `var' == .
}

egen id = group(year county_name)
reshape wide number, i(id year county_name deer_fatalities deer_injuries) j(crashclassification) string
drop id

rename numberfatal_deer_collision  fatal_deer_collision
rename numberinjury_collision_deer injury_collision_deer
rename numberpdo_collision_deer    pdo_collision_deer

foreach var in fatal_deer_collision deer_fatalities {
    replace `var' = 0 if `var' == . & year >= 2010 & year <= 2015
}

gen deer_total = fatal_deer_collision + injury_collision_deer + pdo_collision_deer
gen imputation_flag_deer_total = 1

tempfile de_deer
save `de_deer', replace

/*----------------------------------------------------*/
/* [> 3. Alcohol 05-24 <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/DE/DE.AlcoholCrash.2005-2024.xlsx"

/* Same process as the deer section. This information comes from the PDFs */

import excel using "`file_name'", allstring sheet("Alcohol Related Crashes") case(lower) clear
drop in 1
rename A year
rename B county_name
rename C crashclassification
rename D number
tempfile sheet1
save `sheet1', replace

import excel using "`file_name'", allstring sheet("Alcohol Related Injuries") case(lower) clear
drop in 1
rename A year
rename B county_name
rename C alcohol_injuries
tempfile sheet2
save `sheet2', replace

import excel using "`file_name'", allstring sheet("Alcohol Related Fatalities") case(lower) clear
drop in 1
rename A year
rename B county_name
rename C alcohol_fatalities
tempfile sheet3
save `sheet3', replace

use `sheet1', clear
merge m:1 county_name year using `sheet2', nogen
merge m:1 county_name year using `sheet3', nogen

replace county_name = lower(county_name)
replace county_name = subinstr(county_name, " ", "", .)

replace crashclassification = "pdo_collision_alcohol"    if crashclassification == "Property Damage Only"
replace crashclassification = "injury_collision_alcohol" if crashclassification == "Injury Crash"
replace crashclassification = "fatal_alcohol_collision"  if crashclassification == "Fatal Crash"

destring year number alcohol_injuries alcohol_fatalities, replace

egen id = group(year county_name)
reshape wide number, i(id year county_name alcohol_injuries alcohol_fatalities) j(crashclassification) string
drop id

rename numberfatal_alcohol_collision   fatal_alcohol_collision
rename numberinjury_collision_alcohol  injury_collision_alcohol
rename numberpdo_collision_alcohol     pdo_collision_alcohol

foreach var in fatal_alcohol_collision alcohol_fatalities {
    replace `var' = 0 if `var' == . & year >= 2005 & year <= 2024
}

tempfile de_alcohol
save `de_alcohol', replace

/*----------------------------------------------------*/
/* [> 4. Merge all <] */
/*----------------------------------------------------*/
use `de_total', clear
merge 1:1 year county_name using `de_deer',    keep(1 3) nogen
merge 1:1 year county_name using `de_alcohol', keep(1 3) nogen

gen state_letter_code = "DE"

destring total_all_cause  ///
         fatal_collision  ///
         injury_collision ///
         pdo_collision    ///
         total_fatalities ///
         total_injuries   ///
         fatal_deer_collision   ///
         injury_collision_deer  ///
         pdo_collision_deer     ///
         deer_fatalities  ///
         deer_injuries    ///
		 alcohol_fatalities ///
		 alcohol_injuries ///
		 fatal_alcohol_collision ///
		 injury_collision_alcohol ///
		 pdo_collision_alcohol, ignore("," "NA" " ") replace

assert total_fatalities >= 0 ///
     & fatal_collision >= 0 ///
     & injury_collision >= 0 ///
     & total_injuries >= 0 ///
     & pdo_collision >= 0 ///
     & total_all_cause >= 0 ///
     & fatal_deer_collision >= 0 ///
     & injury_collision_deer >= 0 ///
     & pdo_collision_deer >= 0 ///
     & deer_fatalities >= 0 ///
     & deer_injuries >= 0 ///
	 & alcohol_injuries >= 0 ///
	 & alcohol_fatalities >= 0 ///
	 & fatal_alcohol_collision >= 0 ///
	 & injury_collision_alcohol >= 0 ///
	 & pdo_collision_alcohol >= 0, fast

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name, "st ", "st. ", .) if strpos(county_name, "st") == 1
replace county_name = "new castle" if county_name == "newcastle"

/*----------------------------------------------------*/
/* [> 5. Merge with state_county_identifiers <] */
/*----------------------------------------------------*/
tostring fips, replace
replace fips = "0" + fips if length(fips) == 4
merge m:1 fips using "$path/dataSTATA/state_county_identifiers.dta", keep(1 3)
br if _merge == 1
drop _merge
drop if county_name == "" | county_name == "statewide"

destring fips, replace

tab year

order state_letter_code ///
    state_name          ///
    county_name         ///
    state_fips          ///
    county_fips         ///
    fips                ///
    year                ///
    total* deer* alcohol*

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
sort fips year
compress
save "$working_data/dvcs_DE_county_year_`T1'_`T2'.dta", replace
