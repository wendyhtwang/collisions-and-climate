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

global path "`rootDir'/VehicleCollisionsDataRepo"
global working_data "$path/dataSTATA"

/*-----------------End of SECTION 0: root directory --------------*/

/* Adding data from 2020 -24*/

/*-------------------------
  To Do:
     - [1] derive dta files for all the states
     - [2] merge dta files
-------------------------*/

/*----------------------------------------------------*/
      /* [>   1.  derive dta for 49 states in the folder (~/dataCSV/DVCs/) <] */
/*----------------------------------------------------*/

*************************MT (all data were kept)
/*----------------------------------------------------*/
      /* [>    Total and Animal 20-24  <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/MT/PublicCrashData2020-2024.xlsx"
import excel using "`file_name'", allstring sheet("2020_2024_Statewide") firstrow case(lower) clear

gen crashdate_d = date(crashdate, "MDY")
format crashdate_d %td
gen year = year(crashdate_d)

* Standardize county name
rename countyname county_name
replace county_name = lower(county_name)

* Map text severity labels to category strings matching the rest of the do-file
gen sev = ""
replace sev = "pdo"              if ustrregexm(lower(crashseverity), "property damage only")
replace sev = "possible_injury"  if ustrregexm(lower(crashseverity), "possible injury")
replace sev = "minor_injury"     if ustrregexm(lower(crashseverity), "suspected minor")
replace sev = "major_injury"     if ustrregexm(lower(crashseverity), "suspected serious")
replace sev = "fatal"            if ustrregexm(lower(crashseverity), "fatal")
replace sev = "unknown_severity" if sev == ""  // catches "Unknown" + any unmapped

gen n         = 1
gen is_wild   = ustrregexm(lower(collisiontype), "wild animal")
gen is_animal = ustrregexm(lower(collisiontype), "animal")   // wild + domestic

* Aggregate counts by crash type x severity
foreach sev in pdo possible_injury minor_injury major_injury fatal unknown_severity {
    egen total_`sev'       = total(n          * (sev == "`sev'")), by(county_name year)
    egen wild_animal_`sev' = total(is_wild    * (sev == "`sev'")), by(county_name year)
    egen animal_`sev'      = total(is_animal  * (sev == "`sev'")), by(county_name year)
 
}

drop n is_wild is_animal sev

duplicates drop county_name year ///
    total_* wild_animal_* animal_*, force

* Add statewide aggregate row
tempfile f_2024
save `f_2024', replace

collapse (sum) total_* wild_animal_* animal_*, by(year)
gen county_name = "statewide"
append using `f_2024', force

* Derived injury subtotals and grand totals
foreach prefix in total wild_animal animal{
    gen `prefix'_injury = `prefix'_major_injury + `prefix'_minor_injury + `prefix'_possible_injury
    gen `prefix'_total  = `prefix'_fatal + `prefix'_injury + `prefix'_pdo + `prefix'_unknown_severity
}

* Sanity check -- all counts must be non-negative
foreach prefix in total wild_animal animal {
    foreach sev in pdo possible_injury minor_injury major_injury fatal unknown_severity injury total {
        assert `prefix'_`sev' >= 0, fast
    }
}

drop if mi(county_name)
drop crashdate_d  cityname crashdate collisiontype crashseverity weather roadsurfacecondition lightingcondition xcoordinate ycoordinate crashtime corridorname referencep
tempfile 20_24
save `20_24', replace
/*----------------------------------------------------*/
      /* [>   1.   Total and Animal 95-14  <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/MT/MT.Total_WildAnimalCrash.1995-2014.CountySeverity.Keefe.xlsx"
import excel using "`file_name'", allstring sheet("Codes") cellrange(A1:B56) case(lower) clear

ren A county_name
ren B county_num

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name, "&", "and", .)
replace county_name = subinstr(county_name, "-", " ", .)


tempfile county_code
save `county_code', replace

*********************************
/* [> Wild animal <] */
clear
local file_name = "$path/dataRAW/DVCs/MT/MT.Total_WildAnimalCrash.1995-2014.CountySeverity.Keefe.xlsx"
import excel using "`file_name'", allstring sheet("critter-crashes-crash-severity") cellrange(D1:J14521) firstrow case(lower) clear
 
drop month1 occupant
keep if firstharm == "1371" //wild_animal
drop firstharm
ren county county_num

destring crash,replace
egen wild_animal_major_injury = total(crash*(crashsev == "4")), by(county_num year) 
egen wild_animal_minor_injury = total(crash*(crashsev == "3")), by(county_num year)
egen wild_animal_possible_injury = total(crash*(crashsev == "2")), by(county_num year) 
egen wild_animal_fatal = total(crash*(crashsev == "5")), by(county_num year)
egen wild_animal_pdo = total(crash*(crashsev == "1")), by(county_num year)
egen wild_animal_unknown_severity = total(crash*(crashsev == "6")), by(county_num year)


drop crash crashsev
duplicates drop

drop if county_num =="" // there are blanks for county, can't figure out which county the crash belongs to

tempfile f
save `f', replace

collapse (sum) wild_animal_major_injury  wild_animal_minor_injury wild_animal_possible_injury wild_animal_fatal wild_animal_pdo wild_animal_unknown_severity, by(year)
append using `f', force // add statewide (obs)

tempfile wild_animal_crash
save `wild_animal_crash', replace

/* [> Animal <] */
clear
local file_name = "$path/dataRAW/DVCs/MT/MT.Total_WildAnimalCrash.1995-2014.CountySeverity.Keefe.xlsx"
import excel using "`file_name'", allstring sheet("critter-crashes-crash-severity") cellrange(D1:J14521) firstrow case(lower) clear


drop month1 occupant firstharm
ren county county_num

destring crash,replace
egen animal_major_injury = total(crash*(crashsev == "4")), by(county_num year)
egen animal_minor_injury = total(crash*(crashsev == "3")), by(county_num year)
egen animal_possible_injury = total(crash*(crashsev == "2")), by(county_num year)
egen animal_fatal = total(crash*(crashsev == "5")), by(county_num year)
egen animal_pdo = total(crash*(crashsev == "1")), by(county_num year)
egen animal_unknown_severity = total(crash*(crashsev == "6")), by(county_num year)

drop crash crashsev
duplicates drop

drop if county_num =="" // there are blanks for county, can't figure out which county the crash belongs to

tempfile f
save `f', replace

collapse (sum) animal_major_injury  animal_minor_injury animal_possible_injur animal_fatal animal_pdo animal_unknown_severity, by(year)
append using `f', force // add statewide (obs)

merge 1:1 county_num year using `wild_animal_crash'
br if _merge!=3
drop _merge

tempfile animal_crash
save `animal_crash', replace

/* [> Total <] */
clear
local file_name = "$path/dataRAW/DVCs/MT/MT.Total_WildAnimalCrash.1995-2014.CountySeverity.Keefe.xlsx"
import excel using "`file_name'", allstring sheet("all-crash-severity") cellrange(D1:I42191) firstrow case(lower) clear

drop month1 occupant
ren county county_num

destring crash,replace
egen total_major_injury = total(crash*(crashsev == "4")), by(county_num year)
egen total_minor_injury = total(crash*(crashsev == "3")), by(county_num year)
egen total_possible_injury = total(crash*(crashsev == "2")), by(county_num year)
egen total_fatal = total(crash*(crashsev == "5")), by(county_num year)
egen total_pdo = total(crash*(crashsev == "1")), by(county_num year)
egen total_unknown_severity = total(crash*(crashsev == "6")), by(county_num year)

drop crash crashsev
duplicates drop

drop if county_num =="" // there are blanks for county, can't figure out which county the crash belongs to

tempfile f
save `f', replace

collapse (sum) total_major_injury  total_minor_injury total_possible_injury total_fatal total_pdo total_unknown_severity, by(year)
append using `f', force // add statewide (obs)

duplicates list county_num year

tempfile total_crash
save `total_crash', replace

merge 1:1 county_num year using `animal_crash', nogen


/* [> Merge with county code <] */
merge m:1 county_num using `county_code'
br if _merge!=3 //those can't be merged are "statewide"
drop _merge
drop county_num

replace county_name = "statewide" if county_name == ""
replace county_name = "sweet grass" if county_name == "sweetgrass"
 
destring year, replace
tempfile 95_14
save `95_14', replace

/*----------------------------------------------------*/
      /* [>   2.  Total & Animal 10-19   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/MT/animal-crash-2010-2019-09012020-eyal-frank.xlsx"
import excel using "`file_name'", allstring sheet("county-county-numbers") cellrange(B2:C57) clear
ren B county_num
ren C county_name

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name, "&", "and", .)
replace county_name = subinstr(county_name, "-", " ", .)

tempfile county_code
save `county_code', replace

************************
* total crashes
clear
local file_name = "$path/dataRAW/DVCs/MT/animal-crash-2010-2019-09012020-eyal-frank.xlsx"
import excel using "`file_name'", allstring sheet("datadump") cellrange(A4:BZ572) firstrow case(lower) clear
keep b r s-ab ar-ba bq-bz

foreach v of varlist s-ab {
  local lb_var : var label `v'
  rename `v' acctotal_crash_`lb_var'
}

foreach v of varlist ar-ba {
  local lb_var : var label `v'
  rename `v' accwild_crash_`lb_var'
}

foreach v of varlist bq-bz {
  local lb_var : var label `v'
  rename `v' accdomestic_crash_`lb_var'
}

ren r severity
ren b county_num
drop if county_num =="" | county_num =="county" | severity == ""
  
replace severity = "_pdo" if severity == "0"
replace severity = "_minor_injury" if severity == "2"
replace severity = "_major_injury" if severity == "3"
replace severity = "_possible_injury" if severity == "1"
replace severity = "_fatal" if severity == "4"
replace severity = "_unknown_severity" if severity == "9"

drop if ustrregexm(county_num, "([0-9])")==0
merge m:1 county_num using `county_code',nogen
replace county_name = county_num if county_name==""
drop county_num 

gen id = _n
reshape long acc@, i(id) j(type) string
drop id 
split type, parse(_) destring
rename type3 year
replace severity = type1+severity

drop type* 
reshape wide acc, i(county_name year) j(severity) string 
renpfix acc  

destring total* domestic* wild*, replace

gen animal_fatal = domestic_fatal + wild_fatal
gen animal_major_injury = domestic_major_injury + wild_major_injury
gen animal_minor_injury = domestic_minor_injury + wild_minor_injury
gen animal_possible_injury = domestic_possible_injury + wild_possible_injury
gen animal_pdo = domestic_pdo + wild_pdo
gen animal_unknown_severity = domestic_unknown_severity + wild_unknown_severity

drop domestic*
ren wild* wild_animal*

gen total_injury = total_major_injury + total_minor_injury + total_possible_injury
gen total_total = total_fatal + total_injury + total_pdo + total_unknown_severity
gen animal_injury = animal_major_injury + animal_minor_injury + animal_possible_injury
gen animal_total = animal_fatal + animal_injury + animal_pdo + animal_unknown_severity
gen wild_animal_injury = wild_animal_major_injury + wild_animal_minor_injury + wild_animal_possible_injury
gen wild_animal_total = wild_animal_fatal + wild_animal_injury + wild_animal_pdo + wild_animal_unknown_severity

local pct " ' · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |     、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
     replace county_name = subinstr(county_name, "`x'", "", .)
 }

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "sweet grass" if county_name == "sweetgrass"
replace county_name = "statewide" if county_name == "total"

tempfile crashes
save `crashes', replace

******************************
* persons 
clear
local file_name = "$path/dataRAW/DVCs/MT/animal-crash-2010-2019-09012020-eyal-frank.xlsx"
import excel using "`file_name'", allstring sheet("datadump") cellrange(A4:BZ572) firstrow case(lower) clear

keep b e f-o ae-an bd-bm

foreach v of varlist f-o {
  local lb_var : var label `v'
  rename `v' acctotal_person_`lb_var'
}

foreach v of varlist ae-an {
  local lb_var : var label `v'
  rename `v' accwild_person_`lb_var'
}

foreach v of varlist bd-bm {
  local lb_var : var label `v'
  rename `v' accdomestic_person_`lb_var'
}

drop if b=="" | b=="county"
drop if e == "6" | e == "0"
ren e severity
ren b county_num
 
replace severity = "_minor_injuries" if severity == "2"
replace severity = "_major_injuries" if severity == "3"
replace severity = "_possible_injuries" if severity == "1"
replace severity = "_fatalities" if severity == "4"
replace severity = "_injury_unknown" if severity == "5"

drop if ustrregexm(county_num, "([0-9])")==0
merge m:1 county_num using `county_code',nogen
replace county_name = county_num if county_name==""
drop county_num 


gen id = _n
reshape long acc@, i(id) j(type) string
drop id 
split type, parse(_) destring
rename type3 year
 
replace severity = type1+severity

drop type* 
reshape wide acc, i(county_name year) j(severity) string 
renpfix acc   
destring total* domestic* wild*, replace


gen animal_fatalities = domestic_fatalities + wild_fatalities
gen animal_major_injuries = domestic_major_injuries + wild_major_injuries
gen animal_minor_injuries = domestic_minor_injuries + wild_minor_injuries
gen animal_injury_unknown = domestic_injury_unknown + wild_injury_unknown
gen animal_possible_injuries = domestic_possible_injuries + wild_possible_injuries

drop domestic* total9 wild9
ren wild* wild_animal*

gen total_injuries = total_major_injuries + total_minor_injuries + total_possible_injuries + total_injury_unknown
gen animal_injuries = animal_major_injuries + animal_minor_injuries + animal_possible_injuries + animal_injury_unknown

local pct " ' · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |     、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
     replace county_name = subinstr(county_name, "`x'", "", .)
 }

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "sweet grass" if county_name == "sweetgrass"
replace county_name = "statewide" if county_name == "total"
 

merge 1:1 county year using `crashes', update nogen
 
/*----------------------------------------------------*/
      /* [>   3.  Merge   <] */
/*----------------------------------------------------*/
merge 1:1 county year using `95_14', update nogen

*imputation
gen imputation_flag_total_total = 1
gen imputation_flag_animal_total = 1
gen imputation_flag_wild_ani_total = 1

assert animal_fatal>=0 ///
    & animal_fatal>=0 ///
    & animal_major_injury>=0 ///
    & animal_minor_injury>=0 ///
    & animal_major_injuries>=0 ///
    & animal_minor_injuries>=0 ///
    & animal_pdo >=0 ///
	& animal_total >=0 ///
    & wild_animal_fatal>=0 ///
    & wild_animal_fatal>=0 ///
    & wild_animal_major_injury>=0 ///
    & wild_animal_minor_injury>=0 ///
    & wild_animal_major_injuries>=0 ///
    & wild_animal_minor_injuries>=0 ///
    & wild_animal_pdo>=0 ///
	& wild_animal_total>=0 ///
    & total_fatal>=0 ///
    & total_fatal>=0 ///
    & total_major_injury>=0 ///
    & total_minor_injury>=0 ///
    & total_major_injuries>=0 ///
    & total_minor_injuries>=0 ///
	& total_total>=0 ///
    & total_pdo>=0, fast // sanity check

/*----------------------------------------------------*/
      /* [>   4. Merge with  state_county_identifiers <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `20_24', update nogen

gen state_letter_code  = "MT" // add state abbreviation
local state_county_identifiers "$path/dataSTATA/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge
drop if county_name == "statewide"

order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year ///
    total_* ///
    wild_animal_*

sort state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year , stable

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_MT_county_year_`T1'_`T2'.dta" ,replace

