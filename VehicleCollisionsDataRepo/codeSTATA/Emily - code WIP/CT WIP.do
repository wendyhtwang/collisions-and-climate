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

confirmdir "C:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "C:/Dropbox/Research"
}
confirmdir "D:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "D:/Dropbox/Research"
}

global path "`rootDir'/VehicleCollisionsDataRepo"
global working_data "$path/dataSTATA"

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

rename severitytextformat severity
rename firstobjectstrucktextformat accdtype
rename towntextformat city_name

compress
save "$working_data/dvcs_CT_MID1_CTDOT.dta" ,replace

replace city_name = lower(city_name)

gen state_fips="09"

local city_town_identifiers "$path/dataSTATA/city_town_identifiers.dta"
merge m:1 state_fips city_name using "`city_town_identifiers'", keep(1 3)
br if _merge==1
drop _merge
drop city_name

egen fatal_collision = total(severity =="Fatality"), by(county year) // total_fatal
egen injury_collision = total(severity =="Injury (No fatality)"), by(county year) // total_injury
egen pdo_collision = total(severity =="Property Damage Only"), by(county year) // total_pdo
bys county year: gen total_all_cause =_N // total_total

egen fatal_animal_collision = total(severity =="Fatality" & (accdtype=="Deer" | accdtype=="Animal other than Deer") ), by(county year) // wild_animal_fatal
egen injury_collision_animal = total(severity =="Injury (No fatality)" & (accdtype=="Deer" | accdtype=="Animal other than Deer") ), by(county year) // wild_animal_injury
egen pdo_collision_animal = total(severity =="Property Damage Only" & (accdtype=="Deer" | accdtype=="Animal other than Deer") ), by(county year) // wild_animal_pdo
bys county year: egen animal_total =total(accdtype=="Deer" | accdtype=="Animal other than Deer")

egen fatal_deer_collision = total(severity =="Fatality" & accdtype=="Deer"), by(county year) // deer_fatal
egen injury_collision_deer = total(severity =="Injury (No fatality)" & accdtype=="Deer"), by(county year) // deer_injury
egen pdo_collision_deer = total(severity =="Property Damage Only" & accdtype=="Deer"), by(county year) // deer_pdo
bys county year: egen deer_total = total(accdtype=="Deer" ) // total_total

drop severity accdtype

destring year, replace

duplicates drop

sort county year, stable

compress
save "$working_data/dvcs_CT_95_14.dta" ,replace

/*----------------------------------------------------*/
      /* [>   2.  Total & Animal & Deer 15-19   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/CT/MMUC/export_80783_0.csv"
import delimited using "`file_name'", clear colrange(5:44) varnames(2) case(lower) stringcols(_all)

keep townname year crashseveritytextformat firstharmfuleventtextformat

rename crashseveritytextformat severity
rename firstharmfuleventtextformat accdtype
rename townname city_name

compress
save "$working_data/dvcs_CT_MID2_MMUC.dta" ,replace

replace city_name = lower(city_name)
drop if city_name==""
replace city_name ="ledyard" if city_name == "mashantucket" //The Mashantucket Pequot Indian Reservation is located in Ledyard, Connecticut
gen state_fips="09"

local city_town_identifiers "$path/dataSTATA/city_town_identifiers.dta"
merge m:1 state_fips city_name using "`city_town_identifiers'", keep(1 3)
br if _merge==1
drop _merge
drop city_name

egen fatal_collision = total(severity =="Fatal (Kill)"), by(county year) // total_fatal
egen injury_collision = total(severity =="Injury of any type (Serious, Minor, Possible)"), by(county year) // total_injury
egen pdo_collision = total(severity =="Property Damage Only"), by(county year) // total_pdo
bys county year: gen total_all_cause =_N // total_total

egen fatal_animal_collision = total(severity =="Fatal (Kill)" & (accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)") ), by(county year) // wild_animal_fatal
egen injury_collision_animal = total(severity =="Injury of any type (Serious, Minor, Possible)" & (accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)") ), by(county year) // wild_animal_injury
egen pdo_collision_animal = total(severity =="Property Damage Only" & (accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)") ), by(county year) // wild_animal_pdo
bys county year: egen animal_total =total(accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)")

egen fatal_deer_collision = total(severity =="Fatal (Kill)" & accdtype=="Deer"), by(county year) // deer_fatal
egen injury_collision_deer = total(severity =="Injury of any type (Serious, Minor, Possible)" & accdtype=="Deer"), by(county year) // deer_injury
egen pdo_collision_deer = total(severity =="Property Damage Only" & accdtype=="Deer"), by(county year) // deer_pdo
bys county year: egen deer_total =total(accdtype=="Deer" ) // deer_total

drop severity accdtype

destring year, replace

duplicates drop

sort county year, stable

compress
save "$working_data/dvcs_CT_15_19.dta" ,replace

/* [> append 95_14 <] */
append using "$working_data/dvcs_CT_95_14.dta"

/*----------------------------------------------------*/
      /* [>   3.  Total & Animal & Deer 19-25   <] */
/*----------------------------------------------------*/

clear
set excelxlsxlargefile on
local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Crash summary 19-25 No Local.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

keep crashid year townname crashseveritytextformat firstharmfuleventtextformat

rename crashseveritytextformat severity
rename firstharmfuleventtextformat accdtype
rename townname city_name

replace city_name = lower(city_name)
drop if city_name == ""
replace city_name = "ledyard" if city_name == "mashantucket"
gen state_fips = "09"

local city_town_identifiers "$path/dataSTATA/city_town_identifiers.dta"
merge m:1 state_fips city_name using "`city_town_identifiers'", keep(1 3)
br if _merge == 1
drop _merge
drop city_name


egen fatal_collision = total(severity == "Fatal (Kill)"), by(county year)
egen injury_collision = total(severity == "Injury of any type (Serious, Minor, Possible)"), by(county year)
egen pdo_collision = total(severity == "Property Damage Only"), by(county year)
bys county year: gen total_all_cause = _N

egen fatal_animal_collision = total(severity == "Fatal (Kill)" & (accdtype == "Deer" | accdtype == "Animal Other Than Deer (live)")), by(county year)
egen injury_collision_animal = total(severity == "Injury of any type (Serious, Minor, Possible)" & (accdtype == "Deer" | accdtype == "Animal Other Than Deer (live)")), by(county year)
egen pdo_collision_animal = total(severity == "Property Damage Only" & (accdtype == "Deer" | accdtype == "Animal Other Than Deer (live)")), by(county year)
bys county year: egen animal_total = total(accdtype == "Deer" | accdtype == "Animal Other Than Deer (live)")

egen fatal_deer_collision = total(severity == "Fatal (Kill)" & accdtype == "Deer"), by(county year)
egen injury_collision_deer = total(severity == "Injury of any type (Serious, Minor, Possible)" & accdtype == "Deer"), by(county year)
egen pdo_collision_deer = total(severity == "Property Damage Only" & accdtype == "Deer"), by(county year)
bys county year: egen deer_total = total(accdtype == "Deer")

drop severity accdtype crashid

destring year, replace

duplicates drop

sort county year, stable

compress

/* append prior periods */
append using "$working_data/dvcs_CT_15_19.dta"
append using "$working_data/dvcs_CT_95_14.dta"


/*----------------------------------------------------*/
      /* [>   4.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/state_county_identifiers.dta"

merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)

drop _merge

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
sort county_name year 
save "$working_data/dvcs_CT_county_year_`T1'_`T2'.dta", replace
