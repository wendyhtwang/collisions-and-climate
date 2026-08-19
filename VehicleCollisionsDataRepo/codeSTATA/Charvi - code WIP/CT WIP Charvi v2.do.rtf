{\rtf1\ansi\ansicpg1252\cocoartf2870
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 /*******************************************************************************\
Program: data_dvcs_county_year.do\
Current Lead:  Siyue Ouyang\
Major Versions/Revisions:\
07/01/2020 [Siyue Ouyang]: created\
07/08/2020 [Siyue Ouyang]: code style change\
07/13/2020 [Siyue Ouyang]: add more states\
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states\
07/26/2020 [Siyue Ouyang]: add data in ~dataRaw, update\
07/19/2020 [Kaveri Chhikara]: updated code to define deer_total\
*******************************************************************************/\
/**********************************************************************/\
/*  SECTION 0: root directory\
    Notes: */\
/**********************************************************************/\
cap log close\
clear all\
set more off, permanently\
set matsize 11000\
set maxvar 32767\
set scheme s1mono\
\
confirmdir "C:/Dropbox"\
if r(confirmdir) == "0" \{\
  local rootDir = "C:/Dropbox/Research"\
\}\
confirmdir "D:/Dropbox"\
if r(confirmdir) == "0" \{\
  local rootDir = "D:/Dropbox/Research"\
\}\
\
global path "`rootDir'/VehicleCollisionsDataRepo"\
global working_data "$path/dataSTATA"\
\
/*-----------------End of SECTION 0: root directory --------------*/\
\
/*-------------------------\
  To Do:\
     - [1] derive dta files for all the states\
     - [2] merge dta files\
-------------------------*/\
\
/*----------------------------------------------------*/\
      /* [>   1.  derive dta for 49 states in the folder (~/dataCSV/DVCs/) <] */\
/*----------------------------------------------------*/\
\
*************************CT (all data were kept)\
/*----------------------------------------------------*/\
      /* [>   1.  Total & Animal & Deer 95-14   <] */\
/*----------------------------------------------------*/\
clear\
local file_name = "$path/dataRAW/DVCs/CT/CTDOT/export_29231_0.csv"\
import delimited using "`file_name'", clear varnames(2) case(lower) stringcols(_all)\
keep crashid towntextformat severitytextformat contributingfactortextformat\
\
tempfile crash\
save `crash', replace\
\
clear\
local file_name = "$path/dataRAW/DVCs/CT/CTDOT/export_29231_1.csv"\
import delimited using "`file_name'", clear colrange(:28) varnames(2) case(lower) stringcols(_all)\
\
keep crashid year firstobjectstrucktextformat secondobjectstrucktextformat\
\
duplicates drop crashid, force\
\
tempfile crash_deer\
save `crash_deer', replace\
\
merge 1:1 crashid using `crash', nogen\
drop crashid\
\
rename severitytextformat severity\
rename firstobjectstrucktextformat accdtype\
rename secondobjectstrucktextformat accdtype2\
rename towntextformat city_name\
rename contributingfactortextformat dui_factor\
\
compress\
save "$working_data/dvcs_CT_MID1_CTDOT.dta" ,replace\
\
replace city_name = lower(city_name)\
\
gen state_fips="09"\
\
local city_town_identifiers "$path/dataSTATA/city_town_identifiers.dta"\
merge m:1 state_fips city_name using "`city_town_identifiers'", keep(1 3)\
br if _merge==1\
drop _merge\
drop city_name\
rename county_fips county\
\
egen fatal_collision = total(severity =="Fatality"), by(county year) // total_fatal\
egen injury_collision = total(severity =="Injury (No fatality)"), by(county year) // total_injury\
egen pdo_collision = total(severity =="Property Damage Only"), by(county year) // total_pdo\
bys county year: gen total_all_cause =_N // total_total\
\
egen fatal_animal_collision = total(severity =="Fatality" & (accdtype=="Deer" | accdtype=="Animal other than Deer" | accdtype2=="Deer" | accdtype2=="Animal other than Deer") ), by(county year) // wild_animal_fatal\
egen injury_collision_animal = total(severity =="Injury (No fatality)" & (accdtype=="Deer" | accdtype=="Animal other than Deer" | accdtype2=="Deer" | accdtype2=="Animal other than Deer") ), by(county year) // wild_animal_injury\
egen pdo_collision_animal = total(severity =="Property Damage Only" & (accdtype=="Deer" | accdtype=="Animal other than Deer" | accdtype2=="Deer" | accdtype2=="Animal other than Deer") ), by(county year) // wild_animal_pdo\
bys county year: egen animal_total =total(accdtype=="Deer" | accdtype=="Animal other than Deer" | accdtype2=="Deer" | accdtype2=="Animal other than Deer")\
\
egen fatal_deer_collision = total(severity =="Fatality" & (accdtype=="Deer" | accdtype2=="Deer")), by(county year) // deer_fatal\
egen injury_collision_deer = total(severity =="Injury (No fatality)" & (accdtype=="Deer" | accdtype2=="Deer")), by(county year) // deer_injury\
egen pdo_collision_deer = total(severity =="Property Damage Only" & (accdtype=="Deer" | accdtype2=="Deer")), by(county year) // deer_pdo\
bys county year: egen deer_total = total(accdtype=="Deer" | accdtype2=="Deer") // total_total\
\
/* NOTE: only "Under the Influence" has been confirmed as a value in    */\
/* contributingfactortextformat from a screenshot. The full set of      */\
/* alcohol/DUI-related labels in this column has not been verified      */\
/* against the raw file -- check `tab dui_factor` before trusting this. */\
egen fatal_dui_collision = total(severity =="Fatality" & dui_factor=="Under the Influence"), by(county year) // dui_fatal\
egen injury_collision_dui = total(severity =="Injury (No fatality)" & dui_factor=="Under the Influence"), by(county year) // dui_injury\
egen pdo_collision_dui = total(severity =="Property Damage Only" & dui_factor=="Under the Influence"), by(county year) // dui_pdo\
bys county year: egen dui_total = total(dui_factor=="Under the Influence") // dui_total\
\
drop severity accdtype accdtype2 dui_factor\
\
destring year, replace\
\
duplicates drop\
\
sort county year, stable\
\
compress\
save "$working_data/dvcs_CT_95_14.dta" ,replace\
\
/*----------------------------------------------------*/\
      /* [>   2.  Total & Animal & Deer 15-19   <] */\
/*----------------------------------------------------*/\
clear\
local file_name = "$path/dataRAW/DVCs/CT/MMUC/export_80783_0.csv"\
import delimited using "`file_name'", clear colrange(5:44) varnames(2) case(lower) stringcols(_all)\
\
keep crashid townname year crashseveritytextformat firstharmfuleventtextformat\
\
rename crashseveritytextformat severity\
rename firstharmfuleventtextformat accdtype\
rename townname city_name\
\
tempfile crash_15_19\
save `crash_15_19', replace\
\
/* NOTE: person-level DUI fields (Condition at Time of Crash /            */\
/* Condition at Time of Crash2) were confirmed against the actual         */\
/* export_80783_2.csv header via screenshot, and the value                */\
/* "Under the Influence of Medications/Drugs/Alcohol" was verified        */\
/* to exist in the equivalent 2019-2025 person files. Its presence in     */\
/* export_80783_2.csv itself has not been independently verified since    */\
/* only screenshots (not the raw file) were reviewed for this period --   */\
/* check `tab dui_factor1' / `tab dui_factor2' after import.              */\
clear\
local file_name = "$path/dataRAW/DVCs/CT/MMUC/export_80783_2.csv"\
import delimited using "`file_name'", clear varnames(2) case(lower) stringcols(_all)\
\
keep crashid conditionattimeofcrashtextformat conditionattimeofcrash2textformat\
\
rename conditionattimeofcrashtextformat dui_factor1\
rename conditionattimeofcrash2textformat dui_factor2\
\
gen byte person_dui = (dui_factor1=="Under the Influence of Medications/Drugs/Alcohol" | dui_factor2=="Under the Influence of Medications/Drugs/Alcohol")\
\
/* collapse person-level rows to crash-level: a crash counts as DUI-      */\
/* involved if ANY person in that crash was flagged                       */\
bys crashid: egen crash_dui = max(person_dui)\
duplicates drop crashid, force\
keep crashid crash_dui\
\
tempfile dui_15_19\
save `dui_15_19', replace\
\
use `crash_15_19', clear\
merge m:1 crashid using `dui_15_19', keep(1 3) nogen\
drop crashid\
replace crash_dui = 0 if missing(crash_dui)\
rename crash_dui dui_factor\
\
compress\
save "$working_data/dvcs_CT_MID2_MMUC.dta" ,replace\
\
replace city_name = lower(city_name)\
drop if city_name==""\
replace city_name ="ledyard" if city_name == "mashantucket" //The Mashantucket Pequot Indian Reservation is located in Ledyard, Connecticut\
gen state_fips="09"\
\
local city_town_identifiers "$path/dataSTATA/city_town_identifiers.dta"\
merge m:1 state_fips city_name using "`city_town_identifiers'", keep(1 3)\
br if _merge==1\
drop _merge\
drop city_name\
rename county_fips county\
\
egen fatal_collision = total(severity =="Fatal (Kill)"), by(county year) // total_fatal\
egen injury_collision = total(severity =="Injury of any type (Serious, Minor, Possible)"), by(county year) // total_injury\
egen pdo_collision = total(severity =="Property Damage Only"), by(county year) // total_pdo\
bys county year: gen total_all_cause =_N // total_total\
\
egen fatal_animal_collision = total(severity =="Fatal (Kill)" & (accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)") ), by(county year) // wild_animal_fatal\
egen injury_collision_animal = total(severity =="Injury of any type (Serious, Minor, Possible)" & (accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)") ), by(county year) // wild_animal_injury\
egen pdo_collision_animal = total(severity =="Property Damage Only" & (accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)") ), by(county year) // wild_animal_pdo\
bys county year: egen animal_total =total(accdtype=="Deer" | accdtype=="Animal Other Than Deer (live)")\
\
egen fatal_deer_collision = total(severity =="Fatal (Kill)" & accdtype=="Deer"), by(county year) // deer_fatal\
egen injury_collision_deer = total(severity =="Injury of any type (Serious, Minor, Possible)" & accdtype=="Deer"), by(county year) // deer_injury\
egen pdo_collision_deer = total(severity =="Property Damage Only" & accdtype=="Deer"), by(county year) // deer_pdo\
bys county year: egen deer_total =total(accdtype=="Deer" ) // deer_total\
\
egen fatal_dui_collision = total(severity =="Fatal (Kill)" & dui_factor==1), by(county year) // dui_fatal\
egen injury_collision_dui = total(severity =="Injury of any type (Serious, Minor, Possible)" & dui_factor==1), by(county year) // dui_injury\
egen pdo_collision_dui = total(severity =="Property Damage Only" & dui_factor==1), by(county year) // dui_pdo\
bys county year: egen dui_total = total(dui_factor==1) // dui_total\
\
drop severity accdtype dui_factor\
\
destring year, replace\
\
duplicates drop\
\
sort county year, stable\
\
compress\
save "$working_data/dvcs_CT_15_19.dta" ,replace\
\
/* [> append 95_14 <] */\
append using "$working_data/dvcs_CT_95_14.dta"\
\
/*----------------------------------------------------*/\
      /* [>   3.  Total & Animal & Deer & DUI 19-25   <] */\
/*----------------------------------------------------*/\
\
/* --- 3a. Crash summary: append local + non-local --- */\
clear\
set excelxlsxlargefile on\
local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Crash summary 19-25 No Local.xlsx"\
import excel using "`file_name'", firstrow case(lower) clear\
keep crashid year townname crashseveritytextformat firstharmfuleventtextformat\
tempfile crash_19_25\
save `crash_19_25', replace\
\
clear\
local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Crash summary 19-25 Local.xlsx"\
import excel using "`file_name'", firstrow case(lower) clear\
keep crashid year townname crashseveritytextformat firstharmfuleventtextformat\
append using `crash_19_25'\
\
duplicates drop crashid, force\
tempfile crash_19_25_all\
save `crash_19_25_all', replace\
\
/* --- 3b. Person: append local + non-local, derive crash-level DUI flag --- */\
/* Verified directly against the raw files: "Under the Influence of       */\
/* Medications/Drugs/Alcohol" appears in both Condition at Time of Crash  */\
/* and Condition at Time of Crash2 in both Person_19-25_No_Local.xlsx     */\
/* (10,171 + 370 occurrences) and Person_local.xlsx (7,325 + 560).        */\
clear\
set excelxlsxlargefile on\
local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Person_19-25_No_Local.xlsx"\
import excel using "`file_name'", firstrow case(lower) clear\
keep crashid conditionattimeofcrashtextformat conditionattimeofcrash2textformat\
tempfile person_19_25\
save `person_19_25', replace\
\
clear\
local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Person_local.xlsx"\
import excel using "`file_name'", firstrow case(lower) clear\
keep crashid conditionattimeofcrashtextformat conditionattimeofcrash2textformat\
append using `person_19_25'\
\
rename conditionattimeofcrashtextformat dui_factor1\
rename conditionattimeofcrash2textformat dui_factor2\
gen byte person_dui = (dui_factor1=="Under the Influence of Medications/Drugs/Alcohol" | dui_factor2=="Under the Influence of Medications/Drugs/Alcohol")\
\
bys crashid: egen crash_dui = max(person_dui)\
duplicates drop crashid, force\
keep crashid crash_dui\
\
tempfile dui_19_25\
save `dui_19_25', replace\
\
/* --- 3c. Vehicle: append local + non-local, derive crash-level animal flag --- */\
/* NOTE: this schema has no separate "Deer" category -- Most Harmful      */\
/* Event and Sequence of Events 1-4 only distinguish "Animal (live)" as   */\
/* one combined bucket. Deer cannot be isolated from other animals for    */\
/* 2019-2025; deer_* variables are set to missing for this period below.  */\
/* Verified against raw files: "Animal (live)" appears in Most Harmful    */\
/* Event Text Format (4,608 no-local / 3,251 local) and Sequence of       */\
/* Events 1-4 Text Format (combined 5,018 no-local / 3,627 local).        */\
clear\
set excelxlsxlargefile on\
local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Vehicle_19-25_No_Local.xlsx"\
import excel using "`file_name'", firstrow case(lower) clear\
keep crashid mostharmfuleventtextformat sequenceofevents1textformat sequenceofevents2textformat sequenceofevents3textformat sequenceofevents4textformat\
tempfile vehicle_19_25\
save `vehicle_19_25', replace\
\
clear\
local file_name = "$path/dataRAW/DVCs/CT/CTDOT_2019_2025/Vehicle_Local_Roads.xlsx"\
import excel using "`file_name'", firstrow case(lower) clear\
keep crashid mostharmfuleventtextformat sequenceofevents1textformat sequenceofevents2textformat sequenceofevents3textformat sequenceofevents4textformat\
append using `vehicle_19_25'\
\
gen byte vehicle_animal = (mostharmfuleventtextformat=="Animal (live)" | sequenceofevents1textformat=="Animal (live)" | sequenceofevents2textformat=="Animal (live)" | sequenceofevents3textformat=="Animal (live)" | sequenceofevents4textformat=="Animal (live)")\
\
bys crashid: egen crash_animal = max(vehicle_animal)\
duplicates drop crashid, force\
keep crashid crash_animal\
\
tempfile animal_19_25\
save `animal_19_25', replace\
\
/* --- 3d. Merge crash + person(DUI) + vehicle(animal) by CrashId --- */\
use `crash_19_25_all', clear\
merge m:1 crashid using `dui_19_25', keep(1 3) nogen\
merge m:1 crashid using `animal_19_25', keep(1 3) nogen\
replace crash_dui = 0 if missing(crash_dui)\
replace crash_animal = 0 if missing(crash_animal)\
\
rename crashseveritytextformat severity\
rename firstharmfuleventtextformat accdtype\
rename townname city_name\
rename crash_dui dui_factor\
rename crash_animal animal_factor\
\
replace city_name = lower(city_name)\
drop if city_name == ""\
replace city_name = "ledyard" if city_name == "mashantucket"\
gen state_fips = "09"\
\
local city_town_identifiers "$path/dataSTATA/city_town_identifiers.dta"\
merge m:1 state_fips city_name using "`city_town_identifiers'", keep(1 3)\
br if _merge == 1\
drop _merge\
drop city_name\
rename county_fips county\
\
\
egen fatal_collision = total(severity == "Fatal (Kill)"), by(county year)\
egen injury_collision = total(severity == "Injury of any type (Serious, Minor, Possible)"), by(county year)\
egen pdo_collision = total(severity == "Property Damage Only"), by(county year)\
bys county year: gen total_all_cause = _N\
\
/* animal_factor combines Deer + Animal other than Deer (indistinguishable */\
/* in this period's source schema -- see note above). accdtype ==         */\
/* "Animal Other Than Deer (live)" check retained from crash-summary in   */\
/* case that exact label also appears there, in addition to the vehicle-  */\
/* level animal_factor flag.                                              */\
egen fatal_animal_collision = total(severity == "Fatal (Kill)" & (accdtype == "Deer" | accdtype == "Animal Other Than Deer (live)" | animal_factor==1)), by(county year)\
egen injury_collision_animal = total(severity == "Injury of any type (Serious, Minor, Possible)" & (accdtype == "Deer" | accdtype == "Animal Other Than Deer (live)" | animal_factor==1)), by(county year)\
egen pdo_collision_animal = total(severity == "Property Damage Only" & (accdtype == "Deer" | accdtype == "Animal Other Than Deer (live)" | animal_factor==1)), by(county year)\
bys county year: egen animal_total = total(accdtype == "Deer" | accdtype == "Animal Other Than Deer (live)" | animal_factor==1)\
\
/* deer specifically cannot be isolated from other animals for 2019-2025  */\
/* (see note above) -- set to missing rather than silently undercounting */\
gen fatal_deer_collision = .\
gen injury_collision_deer = .\
gen pdo_collision_deer = .\
gen deer_total = .\
\
egen fatal_dui_collision = total(severity == "Fatal (Kill)" & dui_factor==1), by(county year)\
egen injury_collision_dui = total(severity == "Injury of any type (Serious, Minor, Possible)" & dui_factor==1), by(county year)\
egen pdo_collision_dui = total(severity == "Property Damage Only" & dui_factor==1), by(county year)\
bys county year: egen dui_total = total(dui_factor==1)\
\
drop severity accdtype crashid animal_factor dui_factor\
\
destring year, replace\
\
duplicates drop\
\
sort county year, stable\
\
compress\
\
/* append prior periods */\
append using "$working_data/dvcs_CT_15_19.dta"\
append using "$working_data/dvcs_CT_95_14.dta"\
\
\
/*----------------------------------------------------*/\
      /* [>   4.  Merge with state_county_identifiers   <] */\
/*----------------------------------------------------*/\
rename county county_fips\
\
local state_county_identifiers "$path/dataSTATA/state_county_identifiers.dta"\
\
merge m:1 state_fips county_fips using "`state_county_identifiers'", keep(1 3)\
\
drop _merge\
\
order state_letter_code ///\
    state_name ///\
    county_name ///\
    state_fips ///\
    county_fips ///\
    fips year\
\
qui summ year\
local T1 = `r(min)'\
local T2 = `r(max)'\
compress\
sort county_name year \
save "$working_data/dvcs_CT_county_year_`T1'_`T2'.dta", replace\
}