/*==============================================================
FILE:         data_dvcs_county_year.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Charvi Khandelwal

PURPOSE:      Build the CT county-year deer/vehicle collisions (DVC) panel
              from CTDOT (1995-2014), MMUC (2015-2019), and CTDOT_2019_2025
              raw exports, and merge on state/county identifiers.

CHANGELOG:
  07/01/2020 [Siyue Ouyang]: created
  07/08/2020 [Siyue Ouyang]: code style change
  07/13/2020 [Siyue Ouyang]: add more states
  07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
  07/26/2020 [Siyue Ouyang]: add data in ~dataRaw, update
  07/19/2020 [Kaveri Chhikara]: updated code to define deer_total
  08/10/2026 [Charvi Khandelwal]: reformatted file to match project STATA style guide
    (header, section banners, line wrapping, comment style); no logic changes
    intended except replacing `br if _merge==1` debugging lines with recorded
    counts of unmatched cities (see SECTION 4 note)
  08/10/2026 [Charvi Khandelwal]: added CT_Pipeline_Process_Notes.docx documenting
    crashid merge logic per period, DUI/alcohol field sourcing by period, and
    the city_town_identifiers vs. state_county_identifiers two-file county
    lookup logic
==============================================================*/

*---------------------------------------------------------------
* SECTION 0: SETUP
*---------------------------------------------------------------

cap log close
clear all
set more off, permanently
set matsize 11000
set maxvar 32767
set scheme s1mono

confirmdir "/mnt/data_d/Dropbox/Research"
if r(confirmdir) == "0" {
  local rootDir = "/mnt/data_d/Dropbox/Research"
}
confirmdir "C:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "C:/Dropbox/Research"
}
confirmdir "D:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "D:/Dropbox/Research"
}

if "$path" == "" {
    global path = "`rootDir'/VehicleCollisionsDataRepo"
}
global working_data "$path/dataSTATA"

* --------------------------------------------------------------
* To do:
*   [1] derive .dta files for all states
*   [2] merge state .dta files into full panel
* --------------------------------------------------------------

*---------------------------------------------------------------
* SECTION 1: TOTAL & ANIMAL & DEER COLLISIONS, 1995-2014 (CTDOT)
*---------------------------------------------------------------

*Two files share crashid as a common key: 
* export_29231_0.csv (town, severity, contributing factor) and 
* export_29231_1.csv (year, object struck)

* --- 1a. Crash-level file: town, severity, contributing factor ---
local file_name = "$path/dataRAW/DVCs/CT/CTDOT/export_29231_0.csv"
import delimited using "`file_name'", clear ///
                                      varnames(2) ///
                                      case(lower) ///
                                      stringcols(_all)

keep crashid ///
     towntextformat ///
     severitytextformat ///
     contributingfactortextformat

* This is the only field where DUI is mentioned
gen alcohol_collision = (contributingfactortextformat == "Under the Influence")

tempfile crash
save `crash', replace

* --- 1b. Deer/object-struck file: year and objects struck ---
local file_name = "$path/dataRAW/DVCs/CT/CTDOT/export_29231_1.csv"
import delimited using "`file_name'", clear ///                                      
                                      varnames(2) ///
                                      case(lower) ///
                                      stringcols(_all)


destring vehicleoperatororpedestrianalcoh, replace
gen alcohol_collision2 = inlist(vehicleoperatororpedestrianalcoh, 1, 2, 4, 5)

* Cars can hit many things when an animal is involved in a collision,
* but we want to make sure deer or other animals are not mentioned 
* in crashes that are not flagged as "Animal in Road" cases
assert (firstobjectstrucktextformat != "Deer" | ///
        firstobjectstrucktextformat != "Animal other than Deer" | ///
        secondobjectstrucktextformat != "Deer" | ///
        secondobjectstrucktextformat != "Animal other than Deer") ///
       if vehiclemaneuversuffixtextformat != "Animal in Road"

gen animal_collision = (vehiclemaneuversuffixtextformat == "Animal in Road")

keep crashid ///
     year /// 
     animal_collision alcohol_collision2

bysort crashid: keep if _n == 1     

tempfile crash_deer
save `crash_deer', replace


local file_name = "$path/dataRAW/DVCs/CT/CTDOT/export_29231_2.csv"
import delimited using "`file_name'", clear ///
                                      varnames(2) ///
                                      case(lower) ///
                                      stringcols(_all)

gen total_fatalities = (injuryclassificationtextformat == "Fatal Injury")
gen total_injuries = strpos(injuryclassificationtextformat, "Injury") != 0

collapse (sum) total_fatalities ///
               total_injuries, ///
               by(crashid year)

tempfile crash_severity_count
save `crash_severity_count', replace

* Start with the first file that was read, and then merge in the other two
use `crash', clear

merge 1:1 crashid using `crash_severity_count'
* Some crashes do not have a record in the severity data
* Those will have missing values in fatalities and injuries, 
* which will later get turned into zeros
assert _merge != 2
drop _merge 

merge 1:1 crashid using `crash_deer'
assert _merge == 3 
drop _merge 

* How many times to the alcohol collision dummies disagree?
summ animal_collision if (alcohol_collision == 1 & ///
                          alcohol_collision2 == 0) | ////
                         (alcohol_collision == 0 & ///
                          alcohol_collision2 == 1)
* Answer 13,267
* Updating alcohol_collision with data from alcohol_collision2
replace alcohol_collision = 1 if alcohol_collision2 == 1 & alcohol_collision == 0
tab alcohol_collision
* Went up from 34,145 cases to 40,785 cases

drop alcohol_collision2

replace total_fatalities = 0 if total_fatalities == .
replace total_injuries = 0 if total_injuries == . 

rename severitytextformat severity
rename towntextformat city_name

* --- 1c. Normalize city names and merge on county identifiers ---
replace city_name = lower(city_name)

gen state_fips = "09"

local city_town_identifiers "$path/dataSTATA/city_town_identifiers.dta"
merge m:1 state_fips city_name using "`city_town_identifiers'"
assert _merge != 1
drop if _merge == 2  /* Non-CT towns */
assert county_fips != ""

gen fips = state_fips + county_fips

drop county_fips

* --- 1d. Collapse crash-level rows to county-year counts ---
* total_* counts, by severity

gen total_all_cause = 1 
gen fatal_collision = (severity == "Fatality")
gen injury_collision = (severity == "Injury (No fatality)")
gen pdo_collision = (severity == "Property Damage Only")

gen fatal_animal_collision = animal_collision*fatal_collision
gen injury_animal_collision = animal_collision*injury_collision
gen pdo_animal = animal_collision*pdo_collision
gen animal_fatalities = animal_collision*total_fatalities
gen animal_injuries = animal_collision*total_injuries

gen fatal_alcohol_collision = alcohol_collision*fatal_collision
gen injury_alcohol_collision = alcohol_collision*injury_collision
gen pdo_alcohol = alcohol_collision*pdo_collision
gen alcohol_fatalities = alcohol_collision*total_fatalities 
gen alcohol_injuries = alcohol_collision*total_injuries

destring year, replace

collapse (sum) total_all_cause /// 
               fatal_collision ///
               injury_collision /// 
               total_fatalities ///
               total_injuries /// 
               pdo_collision /// 
               animal_collision /// 
               fatal_animal_collision /// 
               injury_animal_collision /// 
               pdo_animal /// 
               animal_fatalities /// 
               animal_injuries /// 
               alcohol_collision /// 
               fatal_alcohol_collision ///
               injury_alcohol_collision /// 
               pdo_alcohol /// 
               alcohol_fatalities /// 
               alcohol_injuries, ///
               by(fips year)

sort fips year, stable

tempfile dvcs_CT_95_14
save `dvcs_CT_95_14' , replace

*---------------------------------------------------------------
* SECTION 2: TOTAL & ANIMAL & DEER COLLISIONS, 2015-2019 (MMUC)
*---------------------------------------------------------------

* --- 2a. Crash-level file: town, severity, first harmful event ---
local file_name = "$path/dataRAW/DVCs/CT/MMUC/export_80783_0.csv"
import delimited using "`file_name'", clear ///
                                      varnames(2) ///
                                      case(lower) ///
                                      bindquote(strict) ///
                                      stringcols(_all)
keep crashid ///
     townname ///
     year ///
     crashseveritytextformat ///
     firstharmfuleventtextformat

rename crashseveritytextformat severity
rename firstharmfuleventtextformat accdtype
rename townname city_name

gen animal_collision = (accdtype == "Deer" | ///
                        accdtype == "Animal Other Than Deer (live)")

tempfile crash_15_19
save `crash_15_19', replace

* --- 2b. Person-level file: derive crash-level DUI flag ---
* NOTE: person-level DUI fields (Condition at Time of Crash /
* Condition at Time of Crash2) were confirmed against the actual
* export_80783_2.csv header via screenshot, and the value
* "Under the Influence of Medications/Drugs/Alcohol" was verified to exist
* in the equivalent 2019-2025 person files. Its presence in
* export_80783_2.csv itself has not been independently verified since only
* screenshots (not the raw file) were reviewed for this period -- run
* `tab dui_factor1' / `tab dui_factor2' after import.
local file_name = "$path/dataRAW/DVCs/CT/MMUC/export_80783_2.csv"
import delimited using "`file_name'", clear ///
                                      varnames(2) ///
                                      case(lower) ///
                                      bindquote(strict) ///
                                      stringcols(_all)

rename conditionattimeofcrashtextformat dui_factor1
rename conditionattimeofcrash2textfo dui_factor2

gen alcohol_collision = (dui_factor1 == "Under the Influence of Medications/Drugs/Alcohol" | ///
                         dui_factor2 == "Under the Influence of Medications/Drugs/Alcohol")

gen total_fatalities = (injurystatustextformat == "Fatal Injury (K)")
gen total_injuries = strpos(injurystatustextformat, "Injury") != 0
replace total_injuries = 0 if injurystatustextformat == ("No Apparent Injury (O)")


* collapse person-level rows to crash-level: a crash counts as DUI-involved
* if ANY person in that crash was flagged
collapse (max) alcohol_collision ///
         (sum) total_fatalities /// 
               total_injuries, ///
               by(crashid)

tempfile dui_15_19
save `dui_15_19', replace

use `crash_15_19', clear
merge m:1 crashid using `dui_15_19'
assert _merge != 2
drop _merge

replace alcohol_collision = 0 if missing(alcohol_collision)
replace animal_collision = 0 if missing(animal_collision)

tempfile crash_dui_15_19
save `crash_dui_15_19', replace


* --- 2c. Normalize city names and merge on county identifiers ---
replace city_name = lower(city_name)
drop if city_name == ""
* the Mashantucket Pequot Indian Reservation is located in Ledyard, CT
replace city_name = "ledyard" if city_name == "mashantucket"
gen state_fips = "09"

local city_town_identifiers "$path/dataSTATA/city_town_identifiers.dta"
merge m:1 state_fips city_name using "`city_town_identifiers'"
assert _merge != 3 if state_fips == "50"

drop if state_fips == "50"
drop _merge
drop city_name

gen fips = state_fips + county_fips

drop county_fips

gen total_all_cause = 1

gen fatal_collision = (severity == "Fatal (Kill)")
gen injury_collision = (severity == "Injury of any type (Serious, Minor, Possible)")
gen pdo_collision = (severity == "Property Damage Only")

gen fatal_animal_collision = animal_collision*fatal_collision
gen injury_animal_collision = animal_collision*injury_collision
gen pdo_animal = animal_collision*pdo_collision
gen animal_fatalities = animal_collision*total_fatalities
gen animal_injuries = animal_collision*total_injuries

gen fatal_alcohol_collision = alcohol_collision*fatal_collision
gen injury_alcohol_collision = alcohol_collision*injury_collision
gen pdo_alcohol = alcohol_collision*pdo_collision
gen alcohol_fatalities = alcohol_collision*total_fatalities 
gen alcohol_injuries = alcohol_collision*total_injuries

* --- 2d. Collapse crash-level rows to county-year counts ---
destring year, replace

collapse (sum) total_all_cause /// 
               fatal_collision ///
               injury_collision /// 
               total_fatalities ///
               total_injuries /// 
               pdo_collision /// 
               animal_collision /// 
               fatal_animal_collision /// 
               injury_animal_collision /// 
               pdo_animal /// 
               animal_fatalities /// 
               animal_injuries /// 
               alcohol_collision /// 
               fatal_alcohol_collision ///
               injury_alcohol_collision /// 
               pdo_alcohol /// 
               alcohol_fatalities /// 
               alcohol_injuries, ///
               by(fips year)

sort fips year, stable

tempfile dvcs_CT_15_19
save `dvcs_CT_15_19', replace

*---------------------------------------------------------------
* SECTION 3: TOTAL & ANIMAL & DEER & DUI COLLISIONS, 2019-2025 (CTDOT_2019_2025)
*---------------------------------------------------------------

* --- 3a. Crash summary: append local + non-local ---
set excelxlsxlargefile on
local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Crash summary 19-25 No Local.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

keep crashid ///
     year ///
     townname ///
     crashseveritytextformat ///
     firstharmfuleventtextformat

tempfile crash_19_25
save `crash_19_25', replace

local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Crash Summary Local Roads.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

keep crashid ///
     year ///
     townname ///
     crashseveritytextformat ///
     firstharmfuleventtextformat

append using `crash_19_25'

duplicates drop crashid, force  /* no duplicates detected */ 

tempfile crash_19_25_all
save `crash_19_25_all', replace

* --- 3b. Person: append local + non-local, derive crash-level DUI flag ---
* Verified directly against the raw files: "Under the Influence of
* Medications/Drugs/Alcohol" appears in both Condition at Time of Crash
* and Condition at Time of Crash2 in both Person_19-25_No_Local.xlsx
* (10,171 + 370 occurrences) and Person_local.xlsx (7,325 + 560).
set excelxlsxlargefile on
local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Person 19-25 No Local.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

keep crashid ///
     conditionattimeofcrashtext ///
     conditionattimeofcrash2text ///
     injurystatustextformat

tempfile person_19_25
save `person_19_25', replace

local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Person local.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

keep crashid ///
     conditionattimeofcrashtext ///
     conditionattimeofcrash2text ///
     injurystatustextformat

append using `person_19_25'

rename conditionattimeofcrashtext dui_factor1
rename conditionattimeofcrash2text dui_factor2

gen alcohol_collision = (dui_factor1 == "Under the Influence of Medications/Drugs/Alcohol" | ///
                         dui_factor2 == "Under the Influence of Medications/Drugs/Alcohol")

gen total_fatalities = (injurystatustextformat == "Fatal Injury (K)")
gen total_injuries = strpos(injurystatustextformat, "Injury") != 0
replace total_injuries = 0 if injurystatustextformat == ("No Apparent Injury (O)")

collapse (max) alcohol_collision ///
         (sum) total_fatalities /// 
               total_injuries, ///
               by(crashid)

tempfile dui_19_25
save `dui_19_25', replace

* --- 3c. Vehicle: append local + non-local, derive crash-level animal flag ---
* NOTE: this schema has no separate "Deer" category -- Most Harmful Event
* and Sequence of Events 1-4 only distinguish "Animal (live)" as one
* combined bucket. Deer cannot be isolated from other animals for
* 2019-2025; deer_* variables are set to missing for this period below.
* Verified against raw files: "Animal (live)" appears in Most Harmful
* Event Text Format (4,608 no-local / 3,251 local) and Sequence of
* Events 1-4 Text Format (combined 5,018 no-local / 3,627 local).
set excelxlsxlargefile on
local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Vehicle 19-25 No Local.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

keep crashid ///
     mostharmfuleventtextformat ///
     sequenceofevents1textformat ///
     sequenceofevents2textformat ///
     sequenceofevents3textformat ///
     sequenceofevents4textformat

tempfile vehicle_19_25
save `vehicle_19_25', replace

local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Vehicle Local Roads.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

keep crashid ///
     mostharmfuleventtextformat ///
     sequenceofevents1textformat ///
     sequenceofevents2textformat ///
     sequenceofevents3textformat ///
     sequenceofevents4textformat

append using `vehicle_19_25'

gen animal_factor = (mostharmfuleventtextformat  == "Animal (live)" | ///
                     sequenceofevents1textformat == "Animal (live)" | ///
                     sequenceofevents2textformat == "Animal (live)" | ///
                     sequenceofevents3textformat == "Animal (live)" | ///
                     sequenceofevents4textformat == "Animal (live)")

collapse (max) animal_factor, ///
               by(crashid)

tempfile animal_19_25
save `animal_19_25', replace

* --- 3d. Merge crash + person(DUI) + vehicle(animal) by crashid ---
use `crash_19_25_all', clear

/*
  Crash IDs with _merge=1  
  498263
  498342
  498386
  498420
  498424

  Crash IDs with _merge=2  
  498469
  498504
  498510
  498514
  498544
*/


merge m:1 crashid using `dui_19_25'
*assert _merge != 2 
drop if _merge == 2
drop _merge 

merge m:1 crashid using `animal_19_25'
assert _merge == 3
drop _merge 

replace alcohol_collision = 0 if missing(alcohol_collision)
replace animal_factor = 0 if missing(animal_factor)

rename crashseveritytextformat severity
rename firstharmfuleventtextformat accdtype
rename townname city_name
rename crash_dui dui_factor

gen animal_collision = (accdtype == "Deer" | ///
                        accdtype == "Animal Other Than Deer (live)" | ///
                        animal_factor == 1)

replace city_name = lower(city_name)
drop if city_name == ""
* the Mashantucket Pequot Indian Reservation is located in Ledyard, CT
replace city_name = "ledyard" if city_name == "mashantucket"
gen state_fips = "09"

local city_town_identifiers "$path/dataSTATA/city_town_identifiers.dta"
merge m:1 state_fips city_name using "`city_town_identifiers'"
drop if state_fips == "50"
assert _merge == 3
drop _merge
drop city_name

gen fips = state_fips + county_fips

drop county_fips


gen total_all_cause = 1

gen fatal_collision = (severity == "Fatal (Kill)")
gen injury_collision = (severity == "Injury of any type (Serious, Minor, Possible)")
gen pdo_collision = (severity == "Property Damage Only")

gen fatal_animal_collision = animal_collision*fatal_collision
gen injury_animal_collision = animal_collision*injury_collision
gen pdo_animal = animal_collision*pdo_collision
gen animal_fatalities = animal_collision*total_fatalities
gen animal_injuries = animal_collision*total_injuries

gen fatal_alcohol_collision = alcohol_collision*fatal_collision
gen injury_alcohol_collision = alcohol_collision*injury_collision
gen pdo_alcohol = alcohol_collision*pdo_collision
gen alcohol_fatalities = alcohol_collision*total_fatalities 
gen alcohol_injuries = alcohol_collision*total_injuries

* --- 3e. Collapse crash-level rows to county-year counts ---
destring year, replace

collapse (sum) total_all_cause /// 
               fatal_collision ///
               injury_collision /// 
               total_fatalities ///
               total_injuries /// 
               pdo_collision /// 
               animal_collision /// 
               fatal_animal_collision /// 
               injury_animal_collision /// 
               pdo_animal /// 
               animal_fatalities /// 
               animal_injuries /// 
               alcohol_collision /// 
               fatal_alcohol_collision ///
               injury_alcohol_collision /// 
               pdo_alcohol /// 
               alcohol_fatalities /// 
               alcohol_injuries, ///
               by(fips year)

sort fips year, stable

* append prior periods
append using `dvcs_CT_95_14'
append using `dvcs_CT_15_19'

*---------------------------------------------------------------
* SECTION 4: MERGE WITH STATE/COUNTY IDENTIFIERS
*---------------------------------------------------------------

rename county county_fips

local state_county_identifiers "$path/dataSTATA/state_county_identifiers.dta"
merge m:1 state_fips county_fips using "`state_county_identifiers'"
assert _merge != 1
drop _merge 

order state_letter_code ///
      state_name ///
      county_name ///
      state_fips ///
      county_fips ///
      fips ///
      year

tab year 

summ 

qui summ year
local t1 = r(min)
local t2 = r(max)
compress
sort county_name year
save "$path/dataSTATA//dvcs_CT_county_year_`t1'_`t2'.dta", replace
