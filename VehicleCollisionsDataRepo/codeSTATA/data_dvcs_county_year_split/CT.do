/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
07/26/2020 [Siyue Ouyang]: add data in ~dataRaw, update
07/19/2020 [Kaveri Chhikara]: updated code to define deer_total
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

*************************CT (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total & Animal & Deer 95-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/CT/CTDOT/export_29231_0.csv"
import delimited using "`file_name'", clear varnames(2) case(lower) stringcols(_all)
keep crashid towntextformat severitytextformat

tempfile crash
save `crash', replace

clear
local file_name = "$path/dataRAW/DVCs/CT/CTDOT/export_29231_1.csv"
import delimited using "`file_name'", clear colrange(:26) varnames(2) case(lower) stringcols(_all)

keep crashid year firstobjectstrucktextformat

duplicates drop crashid, force

tempfile crash_deer
save `crash_deer', replace

merge 1:1 crashid using `crash', nogen
drop crashid

ren severitytextformat severity
ren firstobjectstrucktextformat accdtype
ren towntextformat city_name

compress
save "$working_data/CT/dvcs_CT_MID1_CTDOT.dta" ,replace

replace city_name = lower(city_name)

gen state_fips="09"

local city_town_identifiers "$path/dataSTATA/_AUX/city_town_identifiers.dta"
merge m:1 state_fips city_name using "`city_town_identifiers'", keep(1 3)
br if _merge==1
drop _merge
drop city_name

egen total_fatal = total(severity =="Fatality"), by(county year) // total_fatal
egen total_injury = total(severity =="Injury (No fatality)"), by(county year) // total_injury
egen total_pdo = total(severity =="Property Damage Only"), by(county year) // total_pdo
bys county year: gen total_total =_N // total_total

egen animal_fatal = total(severity =="Fatality" & (accdtype=="Deer" | accdtype=="Animal other than Deer") ), by(county year) // wild_animal_fatal
egen animal_injury = total(severity =="Injury (No fatality)" & (accdtype=="Deer" | accdtype=="Animal other than Deer") ), by(county year) // wild_animal_injury
egen animal_pdo = total(severity =="Property Damage Only" & (accdtype=="Deer" | accdtype=="Animal other than Deer") ), by(county year) // wild_animal_pdo
bys county year: egen animal_total =total(accdtype=="Deer" | accdtype=="Animal other than Deer")

egen deer_fatal = total(severity =="Fatality" & accdtype=="Deer"), by(county year) // deer_fatal
egen deer_injury = total(severity =="Injury (No fatality)" & accdtype=="Deer"), by(county year) // deer_injury
egen deer_pdo = total(severity =="Property Damage Only" & accdtype=="Deer"), by(county year) // deer_pdo
bys county year: egen deer_total = total(accdtype=="Deer" ) // total_total

drop severity accdtype

destring year, replace

duplicates drop

sort county year, stable

compress
save "$working_data/CT/dvcs_CT_95_14.dta" ,replace

/*----------------------------------------------------*/
      /* [>   2.  Total & Animal & Deer 15-19   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/CT/MMUC/export_80783_0.csv"
import delimited using "`file_name'", clear colrange(5:44) varnames(2) case(lower) stringcols(_all)

keep townname year crashseveritytextformat firstharmfuleventtextformat

ren crashseveritytextformat severity
ren firstharmfuleventtextformat accdtype
ren townname city_name

compress
save "$working_data/CT/dvcs_CT_MID2_MMUC.dta" ,replace

replace city_name = lower(city_name)
drop if city_name==""
replace city_name ="ledyard" if city_name == "mashantucket" //The Mashantucket Pequot Indian Reservation is located in Ledyard, Connecticut
gen state_fips="09"

local city_town_identifiers "$path/dataSTATA/_AUX/city_town_identifiers.dta"
merge m:1 state_fips city_name using "`city_town_identifiers'", keep(1 3)
br if _merge==1
drop _merge
drop city_name

egen total_fatal = total(severity =="Fatal (Kill)"), by(county year) // total_fatal
egen total_injury = total(severity =="Injury of any type (Serious, Minor, Possible)"), by(county year) // total_injury
egen total_pdo = total(severity =="Property Damage Only"), by(county year) // total_pdo
bys county year: gen total_total =_N // total_total

egen animal_fatal = total(severity =="Fatal (Kill)" & (accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)") ), by(county year) // wild_animal_fatal
egen animal_injury = total(severity =="Injury of any type (Serious, Minor, Possible)" & (accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)") ), by(county year) // wild_animal_injury
egen animal_pdo = total(severity =="Property Damage Only" & (accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)") ), by(county year) // wild_animal_pdo
bys county year: egen animal_total =total(accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)")

egen deer_fatal = total(severity =="Fatal (Kill)" & accdtype=="Deer"), by(county year) // deer_fatal
egen deer_injury = total(severity =="Injury of any type (Serious, Minor, Possible)" & accdtype=="Deer"), by(county year) // deer_injury
egen deer_pdo = total(severity =="Property Damage Only" & accdtype=="Deer"), by(county year) // deer_pdo
bys county year: egen deer_total =total(accdtype=="Deer" ) // deer_total

drop severity accdtype

destring year, replace

duplicates drop

sort county year, stable

compress
save "$working_data/CT/dvcs_CT_15_19.dta" ,replace

/* [> append 95_14 <] */
append using "$working_data/CT/dvcs_CT_95_14.dta"

/*----------------------------------------------------*/
      /* [>   3.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state county_fips using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

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
    & animal_total>=0, fast // sanity check

sort county_name year, stable 

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
save "$working_data/dvcs_CT_county_year_`T1'_`T2'.dta" ,replace
