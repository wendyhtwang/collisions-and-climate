/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
05/23/2021 [Rukhshan Arif Mian]: commented out  line 148 and added line 149
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

*************************UT (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 97_16   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/UT/UT.TVC.97-16.CountySeverity.xlsx"
import excel using "`file_name'" , describe
return list
local number_of_sheets = `r(N_worksheet)'


forvalue s = 1/`number_of_sheets'{
    * Get the number and names of all the sheets 
    * in the main spreadsheet 
    clear
    local file_name = "$path/dataCSV/DVCs/UT/UT.TVC.97-16.CountySeverity.xlsx"
    import excel using "`file_name'" , describe
	return list
	
    * Read in a specific sheet 
	import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') 	clear

    gen year = `r(worksheet_`s')'
	
	
	
    if year >= 2002 & year < 2007 { // for year 2002 non-injury crashes is taken as pdo crashes
        keep A B E H K year
        rename A county_name
        rename B total_pdo
        rename E total_injury
        rename H total_fatal
        rename K total_total
    }

    else if year >= 2007 {
        keep A B D F H year
        rename A county_name
        rename B total_pdo
        rename D total_injury
        rename F total_fatal
        rename H total_total
    }

    else {
        keep A B E H year
        rename A county_name
        rename B total_total
        rename E total_injury
        rename H total_fatal
    }

    drop in 1/2
	
    tempfile newstata`s'
    save `newstata`s'', replace
}


local Nminus = `number_of_sheets' - 1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

destring total_total ///
        total_fatal ///
        total_injury ///
        total_pdo ///
        year, ignore("," "NA" " ") replace

		
assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_pdo>=0 ///
    & total_total>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "van buren" if county_name == "vanburen"

duplicates list
duplicates drop

drop if county_name==""

local pct "  · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |  \   、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
      replace county_name = subinstr(county_name, "`x'", "", .)
 }

sort county_name year, stable
gen state_letter_code  = "UT" // add state abbreviation

tempfile TVC_97_16
save `TVC_97_16', replace

/*----------------------------------------------------*/
      /* [>   2.  animal_crashes 10_19   <] */
/*----------------------------------------------------*/
clear
*cd "$path/UT/crash_records/"
cd "$path/dataRAW/DVCs/UT/crash_records/"

set excelxlsxlargefile on
local all_files : dir . files "*.xlsx"
display `all_files'

tempfile animal_crashes
set obs 1
gen drop_me = 1
save `animal_crashes', replace

foreach file in `all_files' {
  clear
  import excel using "`file'", firstrow clear
  keep year  crash_severity_id county_id first_harmful_event_id
  
  append using `animal_crashes'
  save `animal_crashes', replace
}

drop if drop_me == 1
drop drop_me

ren county_id county_name
tostring county_name ,replace
replace county_name = "beaver" if county_name == "1" 
replace county_name = "box elder" if county_name =="3"
replace county_name = "cache" if county_name == "5"
replace county_name = "carbon" if county_name == "7"
replace county_name = "daggett" if county_name == "9"
replace county_name = "davis" if county_name == "11"
replace county_name = "duchesne" if county_name == "13"
replace county_name = "emery" if county_name == "15"
replace county_name = "garfield" if county_name == "17"
replace county_name = "grand" if county_name == "19"
replace county_name = "iron" if county_name == "21"
replace county_name = "juab" if county_name == "23"
replace county_name = "kane" if county_name == "25"
replace county_name = "millard" if county_name == "27"
replace county_name = "morgan" if county_name == "29"
replace county_name = "piute" if county_name == "31"
replace county_name = "rich" if county_name == "33"
replace county_name = "salt lake" if county_name == "35"
replace county_name = "san juan" if county_name == "37"
replace county_name = "sanpete" if county_name == "39"
replace county_name = "sevier" if county_name == "41"
replace county_name = "summit" if county_name == "43"
replace county_name = "tooele" if county_name == "45"
replace county_name = "uintah" if county_name == "47"
replace county_name = "utah" if county_name == "49"
replace county_name = "wasatch" if county_name == "51"
replace county_name = "washington" if county_name == "53"
replace county_name = "wayne" if county_name == "55"
replace county_name = "weber" if county_name == "57"


keep if first_harmful_event_id == 25 | first_harmful_event_id == 26 //25 and 26 specifically for animal-related(domestic and wild) crashes

bysort year county_name: egen animal_total = count(first_harmful_event_id)
bysort year county_name: egen animal_fatal = count(crash_severity_id) if crash_severity_id == 5
bysort year county_name: egen animal_injury = count(crash_severity_id) if crash_severity_id == 4
bysort year county_name: egen animal_pdo = count(crash_severity_id) if crash_severity_id == 1

drop crash_severity_id first_harmful_event_id

collapse animal_total animal_fatal animal_injury animal_pdo , by (year county_name)

replace animal_fatal = 0 if missing(animal_fatal) 
replace	animal_injury = 0 if missing(animal_injury)
replace	animal_pdo = 0 if  missing(animal_pdo)


generate state_letter_code = "UT"

merge 1:1 year county_name using "`TVC_97_16'"
br if _merge!=3
drop _merge


/*----------------------------------------------------*/
      /* [>   3.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name=="missing" | county_name == "statewide"

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
save "$working_data/dvcs_UT_county_year_`T1'_`T2'.dta" ,replace
