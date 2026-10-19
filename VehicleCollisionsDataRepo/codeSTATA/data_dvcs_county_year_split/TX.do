*total_animal_10_14
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

*************************TX 
/*----------------------------------------------------*/
      /* [>   1.  Total 03-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/TX/Binder.xlsx"

tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace


local i=-1
forvalues n = 4(260)1564 {
    local nplus = `n'+254
    import excel using "`file_name'", sheet("TotalSeverity.County.2003-2010") cellrange(A`n':J`nplus') clear
	 
    local i=`i'+1
    di `i'

    gen year = 2003+`i'

    append using `fullfile'
    save `fullfile', replace
}
 
drop if drop_me == 1
drop drop_me

ren A county_name
ren B total_fatal
ren C total_fatalities
ren D total_major_injury
ren E total_major_injuries
ren F total_minor_injury
ren G total_minor_injuries
ren H total_pdo
ren I total_unknown_severity
ren J total_total
gen total_injury = total_major_injury + total_minor_injury

tempfile total_03_09
save `total_03_09', replace
 
************************
clear
local file_name = "$path/dataCSV/DVCs/TX/Binder.xlsx"

tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace


local i=-1
forvalues n = 4(259)1294 {
    local nplus = `n'+254
    import excel using "`file_name'", sheet("TotalSeverity.County.2010+") cellrange(A`n':N`nplus') clear

    drop K M

    local i=`i'+1
    di `i'

    gen year = 2010+`i'

    append using `fullfile'
    save `fullfile', replace
}
 
drop if drop_me == 1
drop drop_me

ren A county_name
ren B total_fatal
ren C total_fatalities
ren D total_major_injury
ren E total_major_injuries
ren F total_minor_injury
ren G total_minor_injuries
ren H total_possible_injury
ren I total_possible_injuries
ren J total_pdo 
ren L total_unknown_severity 
ren N total_total

tempfile total_10_14
save `total_10_14', replace

append using `total_03_09', force

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "la salle" if county_name == "lasalle"

tempfile total_03_14
save `total_03_14', replace
/*----------------------------------------------------*/
      /* [>   2.  Wild animal 10-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/TX/WildAnimalCrash.2010-2014.ContributingFactor.CountySeverity.Jeffcoat.xlsx"
import excel using "`file_name'", allstring sheet("Data") cellrange(A4:O1264) firstrow case(lower) clear

drop possibleinjuries noninjuries unknowninjuries

rename county county_name
rename crashyear year
rename fatalcrashes wild_animal_fatal
rename fatalities wild_animal_fatalities
rename nonincapacitatinginjurycrashe wild_animal_minor_injury
rename nonincapacitatinginjuries wild_animal_minor_injuries
rename incapacitatinginjurycrashes wild_animal_major_injury
rename incapacitatinginjuries wild_animal_major_injuries
rename possibleinjurycrashes wild_animal_possible_injury
rename noninjurycrashes wild_animal_pdo
rename unknowninjurycrashes wild_animal_unknown_severity
rename totalcrashes wild_animal_total



replace county_name=county_name[_n-1] if county_name==""
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "la salle" if county_name == "lasalle"

duplicates list
duplicates drop
drop if county_name==""

local pct "  · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |  \   、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
      replace county_name = subinstr(county_name, "`x'", "", .)
 }

 destring wild_animal_total ///
         wild_animal_fatal ///
         wild_animal_major_injury ///
         wild_animal_minor_injury ///
		 wild_animal_possible_injury ///
         wild_animal_fatalities ///
         wild_animal_major_injuries ///
         wild_animal_minor_injuries ///
		 wild_animal_unknown_severity ///
		 wild_animal_pdo ///
         year, ignore("," "NA" " ") replace
		 
gen wild_animal_injury = wild_animal_major_injury + wild_animal_minor_injury + wild_animal_possible_injury

tempfile animal_10_14
save `animal_10_14', replace
 
/*----------------------------------------------------*/
      /* [>   3.  Animal & Wild animal 10-18   <] */
/*----------------------------------------------------*/
clear
set excelxlsxlargefile on
local file_name = "$path/dataRAW/DVCs/TX/Jared Hernandez  7-17-20.xlsx"
import excel using "`file_name'" , describe

clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

forvalue s = 2/`r(N_worksheet)' {
    import excel using "`file_name'" , describe
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') case(lower) clear
	keep A C H I J K L M N O
	ren A county_name
	ren C date
	ren H animal_type
	ren I fatal
	ren J major_injury
	ren K minor_injury
	ren L possible_injury
	ren M pdo
	ren N unknown_severity
	ren O total
    gen year = substr(date,-4,.)
	drop date
    drop in 1/4

    append using `fullfile', force
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

save "$working_data/TX/dvcs_TX_county_year_mid.dta" ,replace //could not be loaded
use "$working_data/TX/dvcs_TX_county_year_mid.dta" ,replace

drop if county_name==""
destring fatal-year,replace
drop if year == 2020

gen wild_animal_dummy = 0
gen animal_dummy = 0
replace wild_animal_dummy = 1 if strpos(animal_type,"WILD") != 0
replace animal_dummy = 1 if strpos(animal_type,"ANIMAL") != 0
 
drop animal_type

tempfile f
save `f', replace

collapse (sum) fatal major_injury minor_injury possible_injury unknown_severity pdo total if animal_dummy == 1, by(county year)
ren fatal animal_fatal
ren major_injury animal_major_injury
ren minor_injury animal_minor_injury
ren possible_injury animal_possible_injury
ren pdo animal_pdo
ren unknown_severity animal_unknown_severity
ren total animal_total
gen animal_injury = animal_major_injury + animal_minor_injury + animal_possible_injury

tempfile animal
save `animal', replace

use `f', replace
collapse (sum) fatal major_injury minor_injury possible_injury unknown_severity pdo total  if wild_animal_dummy == 1, by(county year)
ren fatal wild_animal_fatal
ren major_injury wild_animal_major_injury
ren minor_injury wild_animal_minor_injury
ren possible_injury wild_animal_possible_injury
ren pdo wild_animal_pdo
ren unknown_severity wild_animal_unknown_severity
ren total wild_animal_total
gen wild_animal_injury = wild_animal_minor_injury+ wild_animal_major_injury + wild_animal_possible_injury

tempfile wild_animal
save `wild_animal', replace
 
merge 1:1 county year using `animal', nogenerate

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "la salle" if county_name == "lasalle"

duplicates list
duplicates drop
drop if county_name==""

local pct "  · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |  \   、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
      replace county_name = subinstr(county_name, "`x'", "", .)
 }

merge 1:1 county year using `animal_10_14', update nogen
merge 1:1 county year using `total_03_14', nogen

assert total_total>=0  ///
    & total_fatal >=0 ///
    & total_major_injury>=0 ///
    & total_minor_injury>=0 ///
	& total_possible_injury >=0 ///
	& total_injury >=0 ///
	& total_possible_injuries >=0 ///
    & total_fatalities>=0 ///
    & total_major_injuries>=0 ///
    & total_minor_injuries>=0 ///
    & total_total>=0  ///
    & wild_animal_fatal >=0 ///
    & wild_animal_major_injury>=0 ///
    & wild_animal_minor_injury>=0 ///
	& wild_animal_possible_injury>=0 ///
	& wild_animal_injury >=0 ///
	& wild_animal_pdo >=0 ///
    & wild_animal_fatalities>=0 ///
    & wild_animal_major_injuries>=0 ///
    & wild_animal_minor_injuries>=0 ///
    & animal_total>=0 ///
    & animal_fatal>=0 ///
    & animal_major_injury>=0 ///
    & animal_minor_injury>=0 ///
	& animal_possible_injury>=0 ///
	& animal_injury >=0 ///
    & animal_pdo>=0, fast // sanity check

sort county_name year, stable
gen state_letter_code  = "TX" // add state abbreviation

/*----------------------------------------------------*/
      /* [>   4.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == "" | county_name == "total"

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
save "$working_data/dvcs_TX_county_year_`T1'_`T2'.dta" ,replace
