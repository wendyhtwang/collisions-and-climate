/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
07/26/2020 [Siyue Ouyang]: add data in ~dataRAW, update
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
      /* [>   1.  Generate county names   <] */
/*----------------------------------------------------*/


clear
local file_name = "$path/dataCSV/DVCs/ND/County_codes.xlsx"
import excel using "`file_name'", allstring firstrow case(lower) clear

ren countycode county_num
destring county_num, replace 

tempfile county_names
save `county_names', replace

/*----------------------------------------------------*/
      /* [>   2.  TVCs, DVCs, AVCs 2007-2015 */
/*----------------------------------------------------*/

clear 
foreach s of numlist 2007/2015 { 

	if `s' == 2012 | `s' == 2013 {
		local file_name = "$path/dataRAW/DVCs/ND/`s'/ND `s' crash_master.TXT"
	}
	else {
		local file_name = "$path/dataRAW/DVCs/ND/`s'/crash_master.TXT"
	}
	
	
	import delimited using "`file_name'", clear case(lower) stringcols(_all)
	 
	keep v1 v2 v6 v21 v23
	ren v1 crash_date
	ren v2 crash_num
	ren v6 crash_severity
	ren v21 crash_type
	ren v23 county_num
	 
	gen year= substr(crash_date,1,4)
	drop crash_date
	 
	egen total_fatal = total(crash_severity =="1"), by(county_num year)
	egen total_minor_injury = total(crash_severity =="2"), by(county_num year)
	egen total_pdo = total(crash_severity =="3"), by(county_num year)
	egen total_major_injury = total(crash_severity =="4"), by(county_num year)
	egen total_possible_injury = total(crash_severity == "5"), by(county_num year)
	gen total_injury = total_minor_injury + total_major_injury + total_possible_injury
	gen total_total = total_fatal + total_injury + total_pdo

	egen deer_fatal = total(crash_severity =="1" & crash_type=="06 "), by(county_num year)
	egen deer_minor_injury = total(crash_severity =="2" & crash_type=="06 "), by(county_num year)
	egen deer_pdo = total(crash_severity =="3" & crash_type=="06 "), by(county_num year)
	egen deer_major_injury = total(crash_severity =="4" & crash_type=="06 "), by(county_num year)
	egen deer_possible_injury = total(crash_severity =="5" & crash_type=="06 "), by(county_num year)
	gen deer_injury = deer_minor_injury + deer_major_injury + deer_possible_injury
	gen deer_total = deer_fatal + deer_injury + deer_pdo

	egen animal_fatal = total(crash_severity =="1" & (crash_type=="06 " | crash_type == "07"| crash_type=="08" | crash_type == "09")), by(county_num year)
	egen animal_minor_injury = total(crash_severity =="2" & (crash_type=="06 " | crash_type == "07"| crash_type=="08" | crash_type == "09")), by(county_num year)
	egen animal_pdo = total(crash_severity =="3" & (crash_type=="06 " | crash_type == "07"| crash_type=="08" | crash_type == "09")), by(county_num year)
	egen animal_major_injury = total(crash_severity =="4" & (crash_type=="06 " | crash_type == "07"| crash_type=="08" | crash_type == "09")), by(county_num year)
	egen animal_possible_injury = total(crash_severity =="5" & (crash_type=="06 " | crash_type == "07"| crash_type=="08" | crash_type == "09")), by(county_num year)
	gen animal_injury = animal_minor_injury + animal_major_injury + animal_possible_injury
	gen animal_total = animal_fatal + animal_injury + animal_pdo
	
	
	 
	tempfile newstata`s'
	save `newstata`s'', replace
}

foreach s of numlist 2007/2014  {
    append using `newstata`s'', force
}

destring year county_num, replace
drop crash_num crash_severity crash_type
duplicates drop

merge m:1 county_num using `county_names', nogenerate 
drop county_num
ren countyname county_name 
order county_name year total* animal* 

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) 
drop if county_name == "summary"

/*----------------------------------------------------*/

      /* [>   3.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
gen state_letter_code  = "ND"
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
save "$working_data/dvcs_ND_county_year_`T1'_`T2'.dta" ,replace
