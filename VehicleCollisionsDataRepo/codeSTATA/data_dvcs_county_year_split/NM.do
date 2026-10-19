/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
07/26/2020 [Siyue Ouyang]: add data in ~dataRAW, update
09/02/2022 [Kaveri Chhikara]: incorporate new data
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

confirmdir "D:/Dropbox/Research/"
if r(confirmdir) == "0" {
  local rootDir = "D:/Dropbox/Research/"
}

/*
// confirmdir "F:/GDrive/"
// if r(confirmdir) == "0" {
//   local rootDir = "F:/GDrive/"
// }
//
// confirmdir "E:/GDrive/"
// if r(confirmdir) == "0" {
//   local rootDir = "E:/GDrive/"
// }
//
// confirmdir "D:/GoogleDrive/"
// if r(confirmdir) == "0" {
//   local rootDir = "D:/GoogleDrive/"
// }
// confirmdir "C:/GoogleDrive/"
// if r(confirmdir) == "0" {
//   local rootDir = "C:/GoogleDrive/"
// }
// confirmdir "/Users/air/Google Drive/"
// if r(confirmdir) == "0" {
//   local rootDir = "/Users/air/Google Drive/"
// }

*/
global path "`rootDir'/WolvesImpacts"

global working_data "$path/dataSTATA/intermediate/collisions/"

/*-----------------End of SECTION 0: root directory --------------*/

/*-------------------------
  To Do:
     - [1] derive dta files for all the states
     - [2] merge dta files
-------------------------*/
/*
/*----------------------------------------------------*/
      /* [>   1.  derive dta for 49 states in the folder (~/dataCSV/DVCs/) <] */
/*----------------------------------------------------*/

*************************NM (only new data were kept)***************************

/*----------------------------------------------------*/
      /* [>   1.  Total 96-18   <] */
/*----------------------------------------------------*/
// clear
// local file_name = "$path/dataCSV/DVCs/NM/NM.TVC.96-18.CountySeverity.xlsx"
// import excel using "`file_name'" , describe
//
// forvalue s = 1/`r(N_worksheet)' {
//     import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
//     gen year = `r(worksheet_`s')'
//
//     if year >= 2010 {
//         rename severityofcrashesbycounty newmexicocrashesbycounty
//         rename propertydamageonlycrashes propertydamagecrashes
//     }
//
//     tempfile newstata`s'
//     save `newstata`s'', replace
// }
//
//
// local Nminus = `r(N_worksheet)'-1
//
// forvalue s = 1/`Nminus' {
//     append using `newstata`s'', force
// }
//
// drop h-k
//
// rename newmexicocrashesbycounty county_name
// rename totalcrashes total_total
// rename fatalcrashes total_fatal
// rename injurycrashes total_injury
// rename peoplekilled total_fatalities
// rename peopleinjured total_injuries
// rename propertydamagecrashes total_pdo
//
// replace county_name = "total" if county_name == "total crashes"
// replace county_name = lower(county_name)
// replace county_name = strtrim(county_name)
// replace county_name = ustrtrim(county_name)
// replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
// replace county_name = "doña ana" if county_name == "dona ana"
// drop if county_name == ""
//
// tempfile total
// save `total', replace

/*----------------------------------------------------*/
      /* [>   2.  Deer 07-13   <] */
/*----------------------------------------------------*/
/* [> Deer 07-11 <] */
// clear
// local file_name = "$path/dataRAW/DVCs/NM/NM.DVC.2007-2013.Record.xlsx"
// import excel using "`file_name'" , describe
// import excel using "`file_name'", allstring sheet(`r(worksheet_1)') cellrange(D1:X4029) firstrow case(lower) clear
//
//
// keep crashyear county numberofpeoplekilled numberofpeoplewithincapacita numberofpeoplewithvisiblein numberofpeoplewithpossiblei crashseverity crashanalysis
//
// ren crashyear year
// ren county county_name
// ren numberofpeoplekilled deer_fatalities
// ren numberofpeoplewithincapacita deer_major_injuries
// ren numberofpeoplewithvisiblein deer_minor_injuries
// ren numberofpeoplewithpossiblei deer_possible_injuries
// ren crashanalysis animal_type
//
// drop if animal_type!="Deer"
// drop animal_type
//
// tempfile f
// save `f',replace
//
// keep county_name year crashseverity
// egen deer_fatal = total(crashseverity=="Fatal Crash"), by(county_name year)
// egen deer_injury = total(crashseverity=="Injury Crash"), by(county_name year)
// egen deer_pdo = total(crashseverity=="Property Damage Only Crash"), by(county_name year)
//
// drop crashseverity
// duplicates drop
// duplicates list county_name year
//
// tempfile deer_crash
// save `deer_crash',replace
//
// *******************
// use `f',replace
//
// destring deer_fatalities-deer_possible_injuries, replace
// collapse (sum) deer_fatalities-deer_possible_injuries, by(county_name year)
// 
// merge 1:1 county_name year using `deer_crash', nogen
//
// tempfile deer_07
// save `deer_07', replace
//
// /* [> Deer 12-13 <] */
// clear
// local file_name = "$path/dataRAW/DVCs/NM/NM.DVC.2007-2013.Record.xlsx"
// import excel using "`file_name'" , describe
// import excel using "`file_name'", allstring sheet(`r(worksheet_2)') cellrange(C1:Y1047) firstrow case(lower) clear
//
// keep year county killed incapacitatinginjury nonincapacitatinginjury nonvisibleinjury  injured severity
//
// ren county county_name
// ren killed deer_fatalities
// ren incapacitatinginjury deer_major_injuries
// ren nonincapacitatinginjury deer_minor_injuries
// ren nonvisibleinjury deer_possible_injuries
// ren injured deer_injuries
//
// tempfile f
// save `f',replace
//
// keep county_name year severity
// egen deer_fatal = total(severity=="Fatal Crash"), by(county_name year)
// egen deer_injury = total(severity=="Injury Crash"), by(county_name year)
// egen deer_pdo = total(severity=="Property Damage Only Crash"), by(county_name year)
//
// drop severity
// duplicates drop
// duplicates list county_name year
//
// tempfile deer_crash
// save `deer_crash',replace
//
// *******************
// use `f',replace
//
// destring deer_fatalities deer_major_injuries deer_minor_injuries deer_possible_injuries  deer_injuries, replace
// collapse (sum) deer_fatalities deer_major_injuries deer_minor_injuries deer_possible_injuries deer_injuries, by(county_name year)
//
// merge 1:1 county_name year using `deer_crash', nogen
// 
// append using `deer_07', force
//
// replace county_name = "total" if county_name == "total crashes"
// replace county_name = lower(county_name)
// replace county_name = strtrim(county_name)
// replace county_name = ustrtrim(county_name)
// replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
// replace county_name = "doña ana" if county_name == "dona ana"
// drop if county_name == ""
//
// destring year, replace
//
// tempfile deer
// save `deer',replace
//
// /*----------------------------------------------------*/
//       /* [>   3.  Merge with total   <] */
// /*----------------------------------------------------*/
// merge 1:1 county_name year using `total'
// br if _merge !=3
// drop _merge
//
// replace county_name = "total" if county_name == "total crashes"
// drop if county_name =="missing data"
//
// gen state_letter_code  = "NM" // add state abbreviation
//
// destring total_total ///
//         total_fatal ///
//         total_injury ///
//         total_fatalities ///
//         total_injuries ///
//         total_pdo ///
//         deer_fatalities ///
//         deer_major_injuries ///
//         deer_minor_injuries ///
//         deer_injuries ///
//         deer_fatal ///
//         deer_injury ///
//         deer_pdo ///
//         year, ignore("," "NA" " ") replace
//
// assert total_total>=0 ///
//     & total_fatal>=0 ///
//     & total_injury>=0 ///
//     & total_fatalities>=0 ///
//     & total_injuries>=0 ///
//     & total_pdo>=0 ///
//     & deer_fatalities>=0 ///
//     & deer_major_injuries>=0 ///
//     & deer_minor_injuries>=0 ///
//     & deer_injuries>=0 ///
//     & deer_fatal>=0 ///
//     & deer_injury>=0 ///
//     & deer_pdo>=0 , fast // sanity check

*/
/*----------------------------------------------------*/
      /* [>   1. Data from DR2090_NMCrash90-20 <] */
/*----------------------------------------------------*/

clear
local file_name = "$path/dataRAW/DVCs/NM/DR2090_NMCrash90-20.csv"

import delimited using "`file_name'", clear case(lower) maxquotedrows(9999999) bindquote(strict)

keep crashreportnumber crashyear county crashseverity numberofpeoplekilledincrash numberofpeoplewithsuspectedserio numberofpeoplewithsuspectedminor numberofpeoplewithpossibleinjuri numberofpeopleinjuredclassabcinc  firstharmfuleventoccurred crashclassification crashanalysis firstharmfulevent firstharmfuleventanalysis
**numberofpeoplenotinjuredclassoin totalnumberofpeopleincrash numberofvehiclesbicyclesandpedes numberofpeopleinmotorvehicles numberofmotorvehiclesinvolved

rename crashyear year
rename county county_name
rename crashseverity severity
rename numberofpeoplekilledincrash fatalities
rename numberofpeoplewithsuspectedserio major_injuries
rename numberofpeoplewithsuspectedminor minor_injuries
rename numberofpeoplewithpossibleinjuri possible_injuries
rename numberofpeopleinjuredclassabcinc injuries

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
drop if county_name == "left blank"
replace county_name = "doña ana" if county_name == "dona ana" 

replace severity = "pdo" if severity == "Property Damage Only Crash"
replace severity = "fatal" if severity == "Fatal Crash"
replace severity = "injury" if severity == "Injury Crash"

** TVCs
bysort year county_name: egen total_total = count(year)
bysort year county_name: egen total_fatal = sum(severity == "fatal")
bysort year county_name: egen total_pdo = sum(severity == "pdo")
bysort year county_name: egen total_injury = sum(severity == "injury")
bysort year county_name: egen total_fatalities = sum(fatalities)
bysort year county_name: egen total_major_injuries = sum(major_injuries)
bysort year county_name: egen total_minor_injuries = sum(minor_injuries)
bysort year county_name: egen total_possible_injuries = sum(possible_injuries)
bysort year county_name: egen total_injuries = sum(injuries)

** for AVCs , use  crashclassification == "Animal"
gen is_animal = 1 if crashclassification == "Animal"
bysort year county_name: egen animal_total = count(is_animal == 1)
bysort year county_name: egen animal_fatal = sum(severity == "fatal" & is_animal == 1)
bysort year county_name: egen animal_pdo = sum(severity == "pdo" & is_animal == 1)
bysort year county_name: egen animal_injury = sum(severity == "injury" & is_animal == 1)
bysort year county_name: egen animal_fatalities = sum(fatalities) if is_animal == 1
bysort year county_name: egen animal_major_injuries = sum(major_injuries) if is_animal == 1
bysort year county_name: egen animal_minor_injuries = sum(minor_injuries) if is_animal == 1
bysort year county_name: egen animal_possible_injuries = sum(possible_injuries) if is_animal == 1
bysort year county_name: egen animal_injuries = sum(injuries) if is_animal == 1 

** for DVCs , use crashanalysis == "Animal - Deer"
gen is_deer = 1 if crashanalysis == "Animal - Deer"
bysort year county_name: egen deer_total = count(is_deer == 1)
bysort year county_name: egen deer_fatal = sum(severity == "fatal" & is_deer == 1)
bysort year county_name: egen deer_pdo = sum(severity == "pdo" & is_deer == 1)
bysort year county_name: egen deer_injury = sum(severity == "injury" & is_deer == 1)
bysort year county_name: egen deer_fatalities = sum(fatalities) if is_deer == 1
bysort year county_name: egen deer_major_injuries = sum(major_injuries) if is_deer == 1
bysort year county_name: egen deer_minor_injuries = sum(minor_injuries) if is_deer == 1
bysort year county_name: egen deer_possible_injuries = sum(possible_injuries) if is_deer == 1
bysort year county_name: egen deer_injuries = sum(injuries) if is_deer == 1 

drop severity fatalities major_injuries minor_injuries possible_injuries injuries firstharmfuleventoccurred crashclassification crashanalysis firstharmfulevent firstharmfuleventanalysis

collapse total* animal* deer*, by (year county_name)

assert total_fatal>=0 ///
    & total_fatalities>=0 ///
    & total_injury>=0 ///
    & total_injuries>=0 ///
    & total_pdo>=0 ///
	& animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_pdo>=0 ///
    & animal_fatalities>=0 ///
    & animal_injuries>=0 ///
    & deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_pdo>=0 ///
    & deer_fatalities>=0 ///
    & deer_injuries>=0, fast // sanity check

gen state_letter_code = "NM"
	
/*----------------------------------------------------*/
      /* [>   Merge with  state_county_identifiers <] */
/*----------------------------------------------------*/

local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

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
    fips year, stable

/*
/* [> imputation <] */
replace deer_injuries = deer_major_injuries+deer_minor_injuries + deer_possible_injuries if deer_injuries ==.
replace deer_minor_injuries = deer_injuries- deer_major_injuries + deer_possible_injuries if deer_minor_injuries ==.

foreach var of varlist deer_fatalities deer_major_injuries deer_injuries deer_fatal deer_injury deer_pdo deer_minor_injuries deer_possible_injuries  {
    replace `var'= 0 if `var'==. & year>=2007 & year<=2013
}
*/
drop if county_name=="total"

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_NM_county_year_`T1'_`T2'.dta" ,replace
