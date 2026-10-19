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

*************************MO
/* [> explanation:
crashes.csv //10 incident level
NumberInjured //Number of persons injured in the crash
NumberMinorInjuries
NumberDisablingInjuries
NumberKilled //Number of persons killed in the crash
County //County code
CrashType == "01" //animal crashes

vehicles.csv //20 Stores Vehicle and Driver specific information.
AnimalCd1 == 60 //deer   Indicates the type of animal struck by vehicle if crash involved the
//collision with either an alive or dead animal.

persons.csv //30 person data for each active participant  involved in the crash.
PersonalInjuryLevel == 1 //fatal
PersonalInjuryLevel == 2 //major injury
                    3  4 //minor injury
<] */

/*-------------------------
    To Do:
     - [1] generate county code .dta file
     - [2] generate .dta file for each year
     - [3] append all years
     - [4] merge with county code .dta
     - [5] merge with state_county_identifiers.dta
-------------------------*/


/*----------------------------------------------------*/
      /* [>   1.  generate county code file   <] */
/*----------------------------------------------------*/
clear
set excelxlsxlargefile on
local file_name = "$path/dataRAW/DVCs/MO/county_code_MO.xlsx"
import excel using "`file_name'", clear case(lower)
rename A county
rename B county_name

compress
save "$working_data/MO/county_code_MO.dta" ,replace


/*----------------------------------------------------*/
      /* [>   2.  generate files for 2002-2018   <] */
/*----------------------------------------------------*/

forvalues n=2002/2018 {

    /* [> total <] */
    clear
    set excelxlsxlargefile on
    if `n' == 2016 {
        local file_name = "$path/dataRAW/DVCs/MO/2016_De-Personalised_with_VIN_Extract/2016_De-Personalised_Extract_with_VIN/crashes.xlsx"
        import excel using "`file_name'", clear allstring firstrow case(lower)
    }

    else if `n' == 2017 {
        local file_name = "$path/dataRAW/DVCs/MO/`n'_De-Personalized_with_VIN_Extract/crashes.csv"
        import delimited using "`file_name'", clear varnames(1) case(lower) stringcols(_all)
        rename ïcrashid crashid
    }
    else if `n' == 2018 {
        local file_name = "$path/dataRAW/DVCs/MO/`n'_De-Personalized_with_VIN_Extract/crash.csv"
        import delimited using "`file_name'", clear varnames(1) case(lower) stringcols(_all)
        rename ïcrashid crashid
    }
    else {
        local file_name = "$path/dataRAW/DVCs/MO/`n'_De-Personalised_with_VIN_Extract/crashes.csv"
        import delimited using "`file_name'", clear varnames(1) case(lower) stringcols(_all)
        rename ïcrashid crashid
    }
 
    keep crashid numberkilled numberinjured county crashtype
    destring numberkilled numberinjured county crashtype,replace

    gen year = `n'
    destring year, replace
	 
    egen total_fatal = total(numberkilled>0), by(county) // total_fatal
    egen total_injury = total(numberinjured>0 & numberkilled==0 ), by(county) // total_injury
    bys county: egen total_fatalities= total(numberkilled) // total_fatalities
    bys county: egen total_injuries =total(numberinjured) // total_injuries
    bys county: gen total_total =_N // total_total

    /* [> animal <] */
    egen animal_fatal = total(numberkilled>0 & crashtype ==1), by(county) // animal_fatal
    egen animal_injury = total(numberinjured>0 & numberkilled==0 & crashtype ==1), by(county) // animal_injury
    *bys county: gen wild_animal_fatalities=sum(numberkilled) if crashtype ==1
    egen animal_fatalities = total(numberkilled*(crashtype ==1)), by(county) // animal_fatalities
    egen animal_injuries = total(numberinjured*(crashtype ==1)), by(county) // animal_injuries
    egen animal_total = total(crashtype ==1), by(county) // animaltotal

    tempfile mo_total_animal
    save `mo_total_animal', replace
	
    /* [> deer <] */
    clear
    set excelxlsxlargefile on
    if `n' == 2016 {
        local file_name = "$path/dataRAW/DVCs/MO/2016_De-Personalised_with_VIN_Extract/2016_De-Personalised_Extract_with_VIN/vehicles.xlsx"
        import excel using "`file_name'", clear allstring firstrow case(lower)
    }

    else if `n' == 2017 {
        local file_name = "$path/dataRAW/DVCs/MO/`n'_De-Personalized_with_VIN_Extract/vehicles.csv"
        import delimited using "`file_name'", clear varnames(1) case(lower) stringcols(_all)
    }
    else if `n' == 2018 {
        local file_name = "$path/dataRAW/DVCs/MO/`n'_De-Personalized_with_VIN_Extract/vehicle.csv"
        import delimited using "`file_name'", clear varnames(1) case(lower) stringcols(_all)
    }
    else {
        local file_name = "$path/dataRAW/DVCs/MO/`n'_De-Personalised_with_VIN_Extract/vehicles.csv"
        import delimited using "`file_name'", clear varnames(1) case(lower) stringcols(_all)
    }
 
    keep crashid animalcd1

    merge m:m crashid using `mo_total_animal'
    br if _merge != 3
    sort year
    drop _merge

    egen deer_fatal = total(numberkilled>0 & animalcd1 == "60"), by(county) // deer_fatal
    egen deer_injury = total(numberinjured>0 & numberkilled==0 & animalcd1 == "60"), by(county) // deer_injury
    egen deer_fatalities = total(numberkilled*(animalcd1 == "60" )), by(county) // deer_fatalities
    egen deer_injuries = total(numberinjured*(animalcd1 == "60" )), by(county) // deer_injuries
    egen deer_total = total(animalcd1 == "60"), by(county) // wild_animaltotal

    qui summ year
    local T1 = `r(min)'
    local T2 = `r(max)'
    compress
    save "$working_data/MO/dvcs_MO_county_year_`T1'_`T2'.dta" ,replace
}


/*----------------------------------------------------*/
      /* [>   3.  append files for 2002-2018   <] */
/*----------------------------------------------------*/
clear
use "$working_data/MO/dvcs_MO_county_year_2018_2018.dta" ,replace

forvalues n = 2002/2017 {
    append using "$working_data/MO/dvcs_MO_county_year_`n'_`n'.dta", force
}

/*----------------------------------------------------*/
      /* [>   4.  merge with county code   <] */
/*----------------------------------------------------*/
local county_code "$working_data/MO/county_code_MO.dta"
merge m:1 county using "`county_code'", keep(1 3)
br if _merge==1
drop _merge
drop county

drop crashid animalcd1 crashtype numberinjured numberkilled

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/MO/dvcs_MO_county_year_`T1'_`T2'_mid.dta" ,replace

/*----------------------------------------------------*/
      /* [>   5.  merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = "st. francois" if county_name == "st. francios"
replace county_name = subinstr(county_name, " county", "", .)

duplicates drop
drop if county_name==""

// imputation
gen total_pdo = total_total - total_fatal - total_injury 
gen animal_pdo = animal_total - animal_fatal - animal_injury 
gen deer_pdo = deer_total - deer_fatal - deer_injury 
gen imputation_flag_animal_pdo = 1
gen imputation_flag_deer_pdo = 1
gen imputation_flag_pdo = 1

assert animal_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
	& animal_pdo>=0 ///
    & animal_fatalities>=0 ///
    & animal_injuries>=0 ///
    & total_total>=0 ///
    & total_fatal>=0 ///
    & total_injury>=0 ///
	& total_pdo>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & deer_total>=0 ///
    & deer_fatal>=0 ///
    & deer_fatalities>=0 ///
    & deer_injury>=0 ///
	& deer_pdo>=0 ///
    & deer_injuries>=0, fast // sanity check

sort county_name year, stable

* creating a balanced dataset
fillin year county_name
drop _fillin

gen state_letter_code  = "MO" // add state abbreviation

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

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_MO_county_year_`T1'_`T2'.dta" , replace

