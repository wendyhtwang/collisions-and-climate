/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
05/23/2021 [Rukhshan Arif Mian]: adding line 77 and line 78. code was breaking otherwise. this is done to reinstate the return list for the excel sheet.
07/18/2021 [Kaveri Chhikara]: Updated code to import and append crash dataset. Consistent with other files.
03/29/2026 [Emily Price]: Updated code to reflect new data system to 2024
*******************************************************************************/

/*-----------------SECTION 0: root directory --------------*/

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

/*-----------------End of SECTION 0: root directory --------------*/


/*-----------------SECTION 1: Old Records 2000-2006 --------------*/

clear
local file_name = "$path/dataRAW/DVCs/CO/ARCHIVE/CO.Total_DeerCrash.2000-2014.CountySeverity.Hogle.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

rename countyname county_name
rename pdo pdo_collision
rename injuredcrash injury_collision
rename fatalcrashes fatal_collision
rename countyyeartotalcrashes total_all_cause

rename injuriesnumber total_injuries
rename fatalitiesnumber total_fatalities

rename deerpdocrashes pdo_deer_collision
rename deercrasheswithinjured injury_deer_collision
rename deercrashwithinjuriesnumber deer_injuries
rename deercrasheswithkilled fatal_deer_collision
rename deercrashnumberfatalities deer_fatalities
rename deercrashescountytotals deer_collision

gen state_letter_code = "CO"
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
drop if county_name == "" | county_name == "total"

* Get fips from the identifiers file, then drop name-based variables
merge m:1 state_letter_code county_name using "$path/dataSTATA/state_county_identifiers.dta", keep(3) nogen

keep if year >= 2000 & year <= 2006

keep 	year ///
		fips ///
		county_name ///
		state_letter_code ///
		state_name ///
		state_fips ///
		county_fips ///
		total_all_cause ///
		total_fatalities ///
		total_injuries ///
		fatal_collision ///
		injury_collision ///
		pdo_collision ///
		deer_collision ///
		fatal_deer_collision ///
		injury_deer_collision ///
		pdo_deer_collision ///
		deer_fatalities ///
		deer_injuries


tempfile historical_data
save `historical_data', replace


/*-----------------SECTION 2: crash records 2007-2020 --------------*/

clear
tempfile fullfile_early
set obs 1
gen drop_me = 1
save `fullfile_early', replace

forvalues file_year = 2007(1)2020 {
    clear
    set excelxlsxlargefile on
    local file_name = "$path/dataRAW/DVCs/CO/CDOTRM_CD_Crash_Listing_-_`file_year'.xlsx"
    import excel using "`file_name'", case(lower) firstrow clear

    rename county county_name
    rename injury00 injury_00
    rename injury01 injury_01
    rename injury02 injury_02
    rename injury03 injury_03
    rename injury04 injury_04

    gen year = `file_year'
    gen state_letter_code = "CO"

    keep county_name ///
         year ///
         state_letter_code ///
         severity ///
         wan_type ///
         dui_1 ///
         dui_2 ///
         dui_3 ///
         injury_00 ///
         injury_01 ///
         injury_02 ///
         injury_03 ///
         injury_04

    replace county_name = lower(county_name)
    replace county_name = strtrim(county_name)
    replace county_name = ustrtrim(county_name)
    replace county_name = ustrregexra(county_name, "\s+", " ")
    replace county_name = subinstr(county_name, "st ", "st. ", .) if strpos(county_name, "st ") == 1

    destring injury_00, replace
    destring injury_01, replace
    destring injury_02, replace
    destring injury_03, replace
    destring injury_04, replace

    * Severity classifications from CO instruction manual
    gen fatal_collision        = (severity == "FAT")
    gen minor_injury_collision = ((injury_02 > 0 & !missing(injury_02)) | (injury_01 > 0 & !missing(injury_01)))
    gen major_injury_collision = (injury_03 > 0 & !missing(injury_03))
    gen injury_collision       = (minor_injury_collision == 1 | major_injury_collision == 1)
    gen pdo_collision          = (severity == "PDO")

    gen total_injuries   = injury_01 + injury_02 + injury_03
    gen total_fatalities = injury_04

    * One row = one crash record before collapse
    gen total_all_cause = 1

    gen animal_collision = (wan_type != "" & wan_type != ".")
    gen fatal_animal_collision = animal_collision * fatal_collision
    gen injury_collision_animal = animal_collision * injury_collision
    gen major_injury_animal_collision = animal_collision * major_injury_collision
    gen minor_injury_animal_collision = animal_collision * minor_injury_collision
    gen pdo_animal_collision = animal_collision * pdo_collision
    gen animal_fatalities = animal_collision * total_fatalities
    gen animal_injuries = animal_collision * total_injuries

    gen deer_collision = (wan_type == "DEER")
    gen fatal_deer_collision = deer_collision * fatal_collision
    gen injury_collision_deer = deer_collision * injury_collision
    gen major_injury_deer_collision = deer_collision * major_injury_collision
    gen minor_injury_deer_collision = deer_collision * minor_injury_collision
    gen pdo_deer_collision = deer_collision * pdo_collision
    gen deer_fatalities = deer_collision * total_fatalities
    gen deer_injuries = deer_collision * total_injuries

    gen alcohol_collision = (dui_1 == "Y" | dui_2 == "Y" | dui_3 == "Y")
    gen fatal_alcohol_collision = alcohol_collision * fatal_collision
    gen injury_collision_alcohol = alcohol_collision * injury_collision
    gen major_injury_alcohol_collision = alcohol_collision * major_injury_collision
    gen minor_injury_alcohol_collision = alcohol_collision * minor_injury_collision
    gen pdo_alcohol_collision = alcohol_collision * pdo_collision
    gen alcohol_fatalities = alcohol_collision * total_fatalities
    gen alcohol_injuries = alcohol_collision * total_injuries

    tab animal_collision alcohol_collision
    tab deer_collision alcohol_collision

    * Merge to get fips before collapsing so we can collapse by fips + year
    merge m:1 state_letter_code county_name using "$path/dataSTATA/state_county_identifiers.dta", keep(1 3)
    drop _merge
	drop if missing(fips)

    collapse (sum) total_all_cause ///
                   fatal_collision ///
				   injury_collision ///
				   major_injury_collision ///
                   minor_injury_collision ///
				   pdo_collision ///
                   total_fatalities ///
				   total_injuries ///
                   animal_collision ///
				   fatal_animal_collision ///
                   injury_collision_animal ///
				   major_injury_animal_collision ///
                   minor_injury_animal_collision ///
				   pdo_animal_collision ///
                   animal_fatalities ///
				   animal_injuries ///
                   deer_collision ///
				   fatal_deer_collision ///
				   injury_collision_deer ///
                   major_injury_deer_collision ///
				   minor_injury_deer_collision ///
                   pdo_deer_collision ///
				   deer_fatalities ///
				   deer_injuries ///
                   alcohol_collision ///
				   fatal_alcohol_collision ///
                   injury_collision_alcohol ///
				   major_injury_alcohol_collision ///
                   minor_injury_alcohol_collision ///
				   pdo_alcohol_collision ///
                   alcohol_fatalities ///
				   alcohol_injuries, ///
                   by(fips year)

    append using `fullfile_early'
    save `fullfile_early', replace
}

drop if drop_me == 1
drop drop_me

/* double check to make sure everything's loading correctly */

tab year

/*-----------------SECTION 3: crash records 2021-2024 --------------*/

/* slight data structure/naming change from 2021 onwards, but the overall information is the same */

clear
tempfile fullfile_late
set obs 1
gen drop_me = 1
save `fullfile_late', replace

forvalues file_year = 2021(1)2024 {
    clear
    set excelxlsxlargefile on
    local file_name = "$path/dataRAW/DVCs/CO/CDOTRM_CD_Crash_Listing_-_`file_year'.xlsx"
    import excel using "`file_name'", case(lower) firstrow clear

    gen year = `file_year'
    gen state_letter_code = "CO"

    rename county county_name
    rename injury00 injury_00
    rename injury01 injury_01
    rename injury02 injury_02
    rename injury03 injury_03
    rename injury04 injury_04
    rename tu1alcoholsuspected dui_1
    rename tu2alcoholsuspected dui_2
    rename wildanimal wan_type

    keep county_name year state_letter_code wan_type dui_1 dui_2 ///
         injury_00 injury_01 injury_02 injury_03 injury_04

    destring injury_00, replace
    destring injury_01, replace
    destring injury_02, replace
    destring injury_03, replace
    destring injury_04, replace

    replace county_name = lower(county_name)
    replace county_name = strtrim(county_name)
    replace county_name = ustrtrim(county_name)
    replace county_name = ustrregexra(county_name, "\s+", " ")
    replace county_name = subinstr(county_name, "st ", "st. ", .) if strpos(county_name, "st ") == 1

    * Severity derived from injury counts (2021+ data lacks severity string)
    gen fatal_collision        = (injury_04 > 0 & !missing(injury_04))
    gen minor_injury_collision = (injury_02 > 0 & !missing(injury_02) | injury_01 > 0 & !missing(injury_01))
    gen major_injury_collision = (injury_03 > 0 & !missing(injury_03))
    gen injury_collision       = (minor_injury_collision == 1 | major_injury_collision == 1)
    gen pdo_collision          = (injury_00 > 0 & !missing(injury_00))

    gen total_injuries   = injury_01 + injury_02 + injury_03
    gen total_fatalities = injury_04

    gen total_all_cause = 1

    gen animal_collision = (wan_type != "" & wan_type != ".")
    gen fatal_animal_collision = animal_collision * fatal_collision
    gen injury_collision_animal = animal_collision * injury_collision
    gen major_injury_animal_collision = animal_collision * major_injury_collision
    gen minor_injury_animal_collision = animal_collision * minor_injury_collision
    gen pdo_animal_collision = animal_collision * pdo_collision
    gen animal_fatalities = animal_collision * total_fatalities
    gen animal_injuries = animal_collision * total_injuries

    gen deer_collision = (wan_type == "DEER")
    gen fatal_deer_collision = deer_collision * fatal_collision
    gen injury_collision_deer = deer_collision * injury_collision
    gen major_injury_deer_collision = deer_collision * major_injury_collision
    gen minor_injury_deer_collision = deer_collision * minor_injury_collision
    gen pdo_deer_collision = deer_collision * pdo_collision
    gen deer_fatalities = deer_collision * total_fatalities
    gen deer_injuries = deer_collision * total_injuries

    gen alcohol_collision = (dui_1 == "Yes - Observed" | dui_1 == "Yes - Preliminary Breath Test" | dui_1 == "Yes - Other Method" | dui_1 == "Yes - SFST" | dui_2 == "Yes - Observed" | dui_2 == "Yes - Preliminary Breath Test" |dui_2 == "Yes - Other Method" | dui_2 == "Yes - SFST")
    gen fatal_alcohol_collision = alcohol_collision * fatal_collision
    gen injury_collision_alcohol = alcohol_collision * injury_collision
    gen major_injury_alcohol_collision = alcohol_collision * major_injury_collision
    gen minor_injury_alcohol_collision = alcohol_collision * minor_injury_collision
    gen pdo_alcohol_collision = alcohol_collision * pdo_collision
    gen alcohol_fatalities = alcohol_collision * total_fatalities
    gen alcohol_injuries = alcohol_collision * total_injuries

    tab animal_collision alcohol_collision
    tab deer_collision alcohol_collision

    merge m:1 state_letter_code county_name using "$path/dataSTATA/state_county_identifiers.dta", keep(1 3)
    drop _merge
	drop if missing(fips)

    collapse (sum) 		total_all_cause ///
						fatal_collision ///
						injury_collision ///
						major_injury_collision ///
						minor_injury_collision ///
						pdo_collision ///
						total_fatalities ///
						total_injuries ///
						animal_collision ///
						fatal_animal_collision ///
						injury_collision_animal ///
						major_injury_animal_collision ///
						minor_injury_animal_collision ///
						pdo_animal_collision ///
						animal_fatalities ///
						animal_injuries ///
						deer_collision ///
						fatal_deer_collision ///
						injury_collision_deer ///
						major_injury_deer_collision ///
						minor_injury_deer_collision ///
						pdo_deer_collision /// 
						deer_fatalities /// 
						deer_injuries ///
						alcohol_collision ///
						fatal_alcohol_collision ///
						injury_collision_alcohol ///
						major_injury_alcohol_collision ///
						minor_injury_alcohol_collision ///
						pdo_alcohol_collision ///
						alcohol_fatalities ///
						alcohol_injuries, ///
						by(fips year)

    append using `fullfile_late'
    save `fullfile_late', replace
}

drop if drop_me == 1
drop drop_me

tab year


/*-----------------SECTION 4: finalize, merge identifiers, and save --------------*/

use `historical_data', clear
count
tab year

append using `fullfile_early'
count
tab year

append using `fullfile_late'
count
tab year


* historical_data already has name/fips variables from its merge in Section 1;
* Sections 2 and 3 collapsed to fips+year so we re-attach name variables here
* for any rows that came through without them
merge m:1 fips using "$path/dataSTATA/state_county_identifiers.dta", update replace
keep if _merge == 3 | _merge == 4 /* matched: updated and not updated*/
drop _merge

drop if county_name == "" | county_name == "total"
drop drop_me

tab year

order state_letter_code         ///
      state_name                ///
      county_name               ///
      state_fips                ///
      county_fips               ///
      fips                      ///
      year                      ///
      total_all_cause           ///
      total_fatalities          ///
      total_injuries            ///
      fatal_collision           ///
      injury_collision          ///
      major_injury_collision    ///
      minor_injury_collision    ///
      pdo_collision             ///
      animal*                   ///
      deer*                     ///
      alcohol*

sort fips year

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_CO_county_year_`T1'_`T2'.dta", replace
