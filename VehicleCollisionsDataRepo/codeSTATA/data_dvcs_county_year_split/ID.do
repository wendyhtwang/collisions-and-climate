/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
07/26/2020 [Siyue Ouyang]: add data in ~dataRAW, update
11/19/2021 [Kaveri Chhikara]: Changed code file to include new data
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

*************************ID (Data received in November 2021)
/*----------------------------------------------------*/
      /* [>   1.  Total, Animal and Wild-animal 97-19  <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/ID/AccdMain.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_1)') cellrange(` r(range_1)') firstrow case(lower) clear
keep fldaccidentid fldaccidentyyyy fldcountyname severityname fldfatalities fldinjuries
ren fldaccidentyyyy year
ren fldcountyname county_name
ren severityname severity
ren fldfatalities fatalities 
ren fldinjuries injuries 

tempfile main
save `main', replace

clear
local file_name = "$path/dataRAW/DVCs/ID/AccdEvent.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_1)') cellrange(` r(range_1)') firstrow case(lower) clear
keep fldaccidentid eventcodename
keep if eventcodename == "Animal - Domestic" | eventcodename == "Animal - Wild"

merge m:1 fldaccidentid using `main', nogen
drop fldaccidentid
destring year fatalities injuries, replace 

replace severity = "pdo" if severity == "Property Dmg Report"
replace severity = "fatal" if severity == "Fatal Accident"
replace severity = "major_injury" if severity == "A Injury Accident"
replace severity = "minor_injury" if severity == "B Injury Accident"
replace severity = "possible_injury" if severity == "C Injury Accident"

bysort year county_name: egen total_total = count(year)
bysort year county_name: egen total_fatal = sum(severity == "fatal")
bysort year county_name: egen total_pdo = sum(severity == "pdo")
bysort year county_name: egen total_major_injury = sum(severity == "major_injury")
bysort year county_name: egen total_minor_injury = sum(severity == "minor_injury")
bysort year county_name: egen total_possible_injury = sum(severity == "possible_injury")
bysort year county_name: egen total_injuries = sum(injuries)
bysort year county_name: egen total_fatalities = sum(fatalities)


bysort year county_name: egen animal_total = sum(eventcodename != "")
bysort year county_name: egen animal_fatal = sum(severity == "fatal" & eventcodename != "")
bysort year county_name: egen animal_pdo = sum(severity == "pdo" & eventcodename != "")
bysort year county_name: egen animal_major_injury = sum(severity == "major_injury" & eventcodename != "")
bysort year county_name: egen animal_minor_injury = sum(severity == "minor_injury" & eventcodename != "")
bysort year county_name: egen animal_possible_injury = sum(severity == "possible_injury" & eventcodename != "")
bysort year county_name (injuries): egen animal_injuries = sum(injuries) if eventcodename != ""
bysort year county_name (fatalities): egen animal_fatalities = sum(fatalities) if eventcodename != ""
 
bysort year county_name: egen wild_animal_total = sum(eventcodename == "Animal - Wild")
bysort year county_name: egen wild_animal_fatal = sum(severity == "fatal" & eventcodename == "Animal - Wild")
bysort year county_name: egen wild_animal_pdo = sum(severity == "pdo" & eventcodename == "Animal - Wild")
bysort year county_name: egen wild_animal_major_injury = sum(severity == "major_injury" & eventcodename == "Animal - Wild")
bysort year county_name: egen wild_animal_minor_injury = sum(severity == "minor_injury" & eventcodename == "Animal - Wild")
bysort year county_name: egen wild_animal_possible_injury = sum(severity == "possible_injury" & eventcodename == "Animal - Wild")
bysort year county_name (injuries): egen wild_animal_injuries = sum(injuries) if eventcodename == "Animal - Wild"
bysort year county_name (fatalities): egen wild_animal_fatalities = sum(fatalities) if eventcodename == "Animal - Wild"

drop eventcodename severity fatalities injuries
collapse total* animal* wild_animal*, by (year county_name)

/*Imputation*/
gen total_injury = total_major_injury + total_minor_injury + total_possible_injury
gen animal_injury = animal_major_injury + animal_minor_injury + animal_possible_injury
gen wild_animal_injury = wild_animal_major_injury + wild_animal_minor_injury + wild_animal_possible_injury

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
    & wild_animal_fatal>=0 ///
    & wild_animal_injury>=0 ///
    & wild_animal_pdo>=0 ///
    & wild_animal_fatalities>=0 ///
    & wild_animal_injuries>=0, fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1

/*----------------------------------------------------*/
      /* [>   2. Merge with  state_county_identifiers <] */
/*----------------------------------------------------*/
gen state_letter_code  = "ID" // add state abbreviation
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
drop _merge
drop if county_name == "" | year == 2020

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
save "$working_data/dvcs_ID_county_year_`T1'_`T2'.dta" ,replace
