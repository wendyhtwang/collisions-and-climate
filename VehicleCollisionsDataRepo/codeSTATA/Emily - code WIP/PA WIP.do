/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
10/15/2020 [Owen Shao]: Data update in 2001 and 2019
03/05/2026 [Emily Price]: Data update for 2020-2024, add alcohol variable
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

/*-----------------SECTION 1: Historical data 1985-2018 --------------*/

/* [> county_name file <] */
clear
local file_name = "$path/dataRAW/DVCs/PA/County_codes_PA.csv"
import delimited using "`file_name'", clear varnames(1) case(lower) stringcols(_all)
rename ïcounty_code county_code
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
destring county_code, replace
drop if county_code == 999

tempfile match_countyname
save `match_countyname', replace

/* [> 2015-2018 data <] */
clear
local file_name = "$path/dataCSV/DVCs/PA/PA.TVC.15-18.CountySeverity.xlsx"
import excel using "`file_name'", describe

forvalue sheet_num = 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`sheet_num')') cellrange(`r(range_`sheet_num')') firstrow case(lower) clear
    gen year = `r(worksheet_`sheet_num')'
    tempfile newstata`sheet_num'
    save `newstata`sheet_num'', replace
}

local Nminus = `r(N_worksheet)'-1
forvalue sheet_num = 1/`Nminus' {
    append using `newstata`sheet_num'', force
}

drop g h population
replace totalcrashes = word(totalcrashes,1)

rename pennsylvaniacrashesbycounty county_name
rename totalcrashes total_total
rename fatalinjurycrashes total_fatal
rename injurycrashes total_injury
rename pdocrashes total_pdo

tempfile 15_18
save `15_18', replace

/* [> 1985-1998 data <] */
clear
local file_name = "$path/dataCSV/DVCs/PA/PA.TVC.85-98.CountySeverity.xlsx"
import excel using "`file_name'", describe
local Nminus = `r(N_worksheet)'-1

forvalues sheet_num = 1/`r(N_worksheet)' {
    clear
    local file_name = "$path/dataCSV/DVCs/PA/PA.TVC.85-98.CountySeverity.xlsx"
    import excel using "`file_name'", describe
    local year `r(worksheet_`sheet_num')'
    if `year' < 1996 {
        import excel using "`file_name'", allstring sheet(`r(worksheet_`sheet_num')') cellrange(A1:E69) clear
        gen year = `year'
        drop in 1
        rename A county_name
        rename B total_fatal
        rename C total_injury
        rename D total_pdo
        rename E total_total
    }
    else {
        import excel using "`file_name'", allstring sheet(`r(worksheet_`sheet_num')') cellrange(A1:F69) clear
        gen year = `year'
        drop in 1
        drop B
        rename A county_name
        rename C total_fatal
        rename D total_injury
        rename E total_pdo
        rename F total_total
    }
    tempfile newstata`sheet_num'
    save `newstata`sheet_num'', replace
}

forvalue sheet_num = 1/`Nminus' {
    append using `newstata`sheet_num'', force
}

foreach lname in total_fatal total_injury total_pdo total_total {
    replace `lname' = substr(`lname',1,strpos(`lname'," ")-1) if strpos(`lname'," ")!=0
    replace `lname' = substr(`lname',1,strpos(`lname',"(")-1) if strpos(`lname',"(")!=0
    replace `lname' = substr(`lname',1,strpos(`lname',"%")-1) if strpos(`lname',"%")!=0
    replace `lname' = subinstr(`lname',"S","5", .)
    replace `lname' = subinstr(`lname',"I","1", .)
    replace `lname' = subinstr(`lname',"l","1", .)
    replace `lname' = subinstr(`lname',"T","7", .)
    replace `lname' = subinstr(`lname',",","", .)
    replace `lname' = subinstr(`lname',".","", .)
    replace `lname' = subinstr(`lname',"·","", .)
    replace `lname' ="" if strpos(`lname',"Jun")!=0
}

append using `15_18', force

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "armstrong"     if county_name == "annstrong"
replace county_name = "cumberland"    if county_name == "cumberiand"
replace county_name = "fayette"       if county_name == "fayene"
replace county_name = "fayette"       if county_name == "fayetie"
replace county_name = "lehigh"        if county_name == "lehi h"
replace county_name = "luzerne"       if county_name == "luzeme"
replace county_name = "northumberland" if county_name == "northumberiand"
replace county_name = "sullivan"      if county_name == "suluvan"
replace county_name = "venango"       if county_name == "venago"
replace county_name = "westmoreland"  if county_name == "westrnoreland"

drop if county_name == "" | county_name == "total" | county_name == "totals"

destring total*, ignore("," "NA" " " ".") replace

/* [> merge in county codes and create FIPS <] */
merge m:1 county_name using `match_countyname'
assert _merge == 3
drop _merge

tostring county_code, replace
replace county_code = "0" + county_code if length(county_code) == 2
replace county_code = "00" + county_code if length(county_code) == 1
gen fips = "42" + county_code  /* PA state FIPS code is 42 */
destring fips, replace
drop county_code

tempfile historical_data
save `historical_data', replace

/*-----------------SECTION 2: Crash-level data 2001-2024 --------------*/

clear
local file_name = "$path/dataRAW/DVCs/PA/log#22251 Hit Other Anmial Crashes.csv"
import delimited using "`file_name'", clear case(lower) stringcols(_all)
ren v1 crn
ren v2 year
destring crn year, replace
gen other_animal_related = 1
tempfile other_animal
save `other_animal', replace

clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

forvalues file_year = 2001(1)2024 {
    if `file_year' == 2004 continue

    display "Processing year `file_year'..."

    tempfile crashdata flagdata

    // BUILD CRASH DATA
    clear
    save `crashdata', emptyok replace

    cd "$path/dataRAW/DVCs/PA/Statewide_`file_year'/"

    local crashfiles "CRASH_`file_year'.csv CRASH2_`file_year'.csv"

    foreach cf of local crashfiles {
        capture confirm file "`cf'"
        if _rc continue

        import delimited using "`cf'", ///
            clear varnames(1) case(lower) stringcols(_all)

        gen year = `file_year'

        capture confirm variable fatal_count
        if _rc {
            capture confirm variable fatal_cnt
            if !_rc rename fatal_cnt fatal_count
        }

        capture confirm variable injury_count
        if _rc {
            capture confirm variable injury_cnt
            if !_rc rename injury_cnt injury_count
        }

        capture confirm variable county
        if !_rc rename county county_code

        keep crn fatal_count injury_count county_code year
        destring crn fatal_count injury_count county_code, replace

        append using `crashdata'
        save `crashdata', replace
    }

    use `crashdata', clear
    duplicates drop crn year, force
    save `crashdata', replace

    // BUILD FLAG DATA
    clear
    save `flagdata', emptyok replace

    local flagfiles "FLAG_`file_year'.csv FLAG2_`file_year'.csv"

    foreach ff of local flagfiles {
        capture confirm file "`ff'"
        if _rc continue

        import delimited using "`ff'", ///
            clear varnames(1) case(lower) stringcols(_all)

        gen year = `file_year'

        keep crn property_damage_only injury fatal deer_related alcohol_related year

        capture confirm string variable property_damage_only
        if !_rc {
            if inlist(property_damage_only[1], "Yes", "No") {
                foreach x in property_damage_only injury fatal deer_related alcohol_related {
                    gen `x'_1 = inlist(`x', "Yes")
                    replace `x' = ""
                    destring `x', replace
                    replace `x' = `x'_1
                    drop `x'_1
                }
            }
        }

        destring crn property_damage_only injury fatal deer_related alcohol_related, replace ignore("")

        append using `flagdata'
        save `flagdata', replace
    }

    use `flagdata', clear
    duplicates drop crn year, force
    save `flagdata', replace

    // MERGE AND CREATE FLAGS
    use `flagdata', clear
    merge 1:1 crn year using `crashdata', keep(3) nogen

    gen other_animal_related = 0
    merge 1:1 crn year using "`other_animal'", keep(1 3) nogen
    replace other_animal_related = 0 if missing(other_animal_related)

    /* [> create county FIPS directly from county_code <] */
    tostring county_code, replace
    replace county_code = "0" + county_code if length(county_code) == 2
    replace county_code = "00" + county_code if length(county_code) == 1
    gen fips = "42" + county_code  /* PA state FIPS code is 42 */
    destring fips county_code, replace
    drop county_code

    gen fatal_collision = (fatal == 1)
    gen injury_collision = (injury == 1)
    gen pdo_collision = (property_damage_only == 1)

    gen animal_collision = (deer_related == 1 | other_animal_related == 1)
	gen fatal_animal_collision = animal_collision * fatal_collision
	gen injury_animal_collision = animal_collision * injury_collision
	gen animal_fatalities = animal_collision * fatal_count
	gen animal_injuries = animal_collision * injury_count

    gen deer_collision = (deer_related == 1)
	gen fatal_deer_collision = deer_collision * fatal_collision
    gen injury_deer_collision = deer_collision * injury_collision
    gen deer_fatalities = deer_collision * fatal_count
    gen deer_injuries = deer_collision * injury_count

    gen alcohol_collision = (alcohol_related == 1)
    gen fatal_alcohol_collision = alcohol_collision * fatal_collision
    gen injury_alcohol_collision = alcohol_collision * injury_collision
    gen alcohol_fatalities = alcohol_collision * fatal_count
    gen alcohol_injuries = alcohol_collision * injury_count

    collapse (sum) fatal_collision ///
                   fatal_count ///
                   injury_collision ///
                   injury_count ///
                   pdo_collision ///
                   animal_collision ///
                   fatal_animal_collision ///
                   injury_animal_collision ///
                   animal_fatalities ///
                   animal_injuries ///
                   deer_collision ///
                   fatal_deer_collision ///
                   injury_deer_collision ///
                   deer_fatalities ///
                   deer_injuries ///
                   alcohol_collision ///
                   fatal_alcohol_collision ///
                   injury_alcohol_collision ///
                   alcohol_fatalities ///
                   alcohol_injuries, ///
                   by(fips year)

    rename fatal_collision total_fatal
    rename injury_collision total_injury
    rename pdo_collision total_pdo
    rename fatal_count total_fatalities
    rename injury_count total_injuries
    rename animal_collision animal_total
    rename fatal_animal_collision animal_fatal
    rename injury_animal_collision animal_injury
    rename deer_collision deer_total
    rename fatal_deer_collision deer_fatal
    rename injury_deer_collision deer_injury
    rename alcohol_collision alcohol_total
    rename fatal_alcohol_collision alcohol_fatal
    rename injury_alcohol_collision alcohol_injury

    append using `fullfile', force
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

append using `historical_data', force

/*-----------------SECTION 3: Merge with state_county_identifiers --------------*/

local state_county_identifiers "$path/dataSTATA/state_county_identifiers.dta"
tostring(fips), gen(fips_string)
replace fips_string = "0" + fips_string if length(fips_string) == 4
merge m:1 fips_string using "`state_county_identifiers'", keep(1 3)
* Why not "assert _merge == 3" here?
br if _merge == 1
drop _merge
drop if county_name == "" | county_name == "total"
drop fips_string



order state_letter_code ///
    state_name          ///
    county_name         ///
    state_fips          ///
    county_fips         ///
    fips                ///
    year                ///
    total* animal* deer* alcohol*

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_PA_county_year_`T1'_`T2'.dta", replace

tempfile PA_1999_2004
use "$path/dataRAW/DVCs/PA/dvcs_PA_county_year_1985_2019.dta", clear
keep if year == 1999 | year == 2000 | year == 2004
save `PA_1999_2004', replace

use "$working_data/dvcs_PA_county_year_`T1'_`T2'.dta", clear
append using `PA_1999_2004', force
qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_PA_county_year_`T1'_`T2'.dta", replace