/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
04/02/2022 [Kaveri Chhikara]: added new data from 2000-2020
02/25/2026 [Emily Price]: added new data from 2020-2024, added alcohol variable
*******************************************************************************/
/**********************************************************************/
/*-----------------SECTION 0: root directory --------------*/

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

/*-----------------SECTION 1: County-level records, 1997-199 --------------*/


/* [> county_name file <] */
clear
local file_name = "$path/dataRAW/DVCs/AZ/county_code.xlsx"
import excel using "`file_name'", firstrow case(lower) clear
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
sort county_code

drop if county_code == 999

tempfile match_countyname
save `match_countyname', replace

clear
local file_name = "$path/dataCSV/DVCs/AZ/AZ.TVC.97-18.County.Severity.Web.xlsx"

import excel using "`file_name'" , describe

** importing data only from 1997-99
forvalues s =1/3 {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(A1:G17) firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    if year > = 2005 {
        rename pdo pdos

	if year > = 2006 {
        rename killed fatalities
        rename injured injuries
        }
    }
    tempfile newstata`s'
    save `newstata`s'', replace
}

clear
forvalues s = 1/3 {
    append using `newstata`s'', force
}

rename crashesbycounty county_name
rename fatal fatal_collision
rename fatalities totalfatalities
rename injury injury_collision
rename injuries totalinjuries
rename pdos pdo_collision

drop if county_name == "Total"

destring fatal_collision ///
         injury_collision ///
         totalfatalities ///
         totalinjuries ///
         pdo_collision ///
         total ///
         year, ///
         ignore("," "NA" " ") ///
         replace 
		
rename total total_all_cause
rename totalfatalities total_fatalities
rename totalinjuries total_injuries

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)


merge m:1 county_name using `match_countyname'
assert _merge == 3 
drop _merge



* Create the FIPS code 
tostring county_code, replace
replace county_code = "0" + county_code if length(county_code) == 2
replace county_code = "00" + county_code if length(county_code) == 1
gen fips = "04" + county_code  /* AZ state FIPS code is 04 */
destring fips, replace

drop county_name

tempfile CSV
save `CSV', replace



/*-----------------SECTION 2: crash records 2000-2024 --------------*/


/* [> crash record level data <] */

clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

* I prefer to not use reserved names or letters in Stata, like "n"
* My code, for better or worse, opts to be verbose so it removes a bit 
* of guesswork when reading it many weeks or months after it was written,
* so even if "y" or "t" would have worked just fine for the index, having 
* "file_year" is super explicit about what the index is counting
* Finally, even if the default is to jump in increments of 1, I always prefer
* specifying it
forvalues file_year = 2000(1)2024 {
    clear
    set excelxlsxlargefile on
    local file_name = "$path/dataRAW/DVCs/AZ/`file_year'/Incident_`file_year'.csv"
    import delimited using "`file_name'", case(lower) stringcols(_all) clear

    * With commands that change existing data, I try to not use 
    * their abbreviations. In general, my goal is for the code to be as close as 
    * possible to broken English 
    rename incidentyear year
	destring year, replace
    rename countyid county_code
    rename injuryseverity severity

    * Create the FIPS code 
    replace county_code = "0" + county_code if length(county_code) == 2
    replace county_code = "00" + county_code if length(county_code) == 1
    gen fips = "04" + county_code  /* AZ state FIPS code is 04 */
    destring fips, replace

    * Destringing several variables in one go is totally fine
    * My weak preference is to do variable by variable only because if there 
    * is an error, it makes it easier and faster to see which of the variables
    * caused the command to fail 
    destring totalinjuries, replace
    destring totalfatalities, replace
    destring alcoholinvolvementflag, replace
    destring severity, replace

    rename totalfatalities total_fatalities
    rename totalinjuries total_injuries

    * Summing the number of rows by county-year will provide the total_all_cause
    * after collapsing the data
    gen total_all_cause = 1 

    * Info from severity in AZ Instruction Manual 
    gen fatal_collision = (severity == 5)
    gen major_injury_collision = (severity == 4) 
    gen minor_injury_collision = (severity == 2 | severity == 3)    
    gen injury_collision = (major_injury_collision == 1 | minor_injury_collision == 1)
    gen pdo_collision = (severity == 1)

    * Using the "///" (continue on the next line) just helps making the code
    * more vertical, which is just easier to read
    gen animal_collision = (firstharmfulevent == "21" | ///
                            firstharmfulevent == "22" | ///
                            firstharmfulevent == "23" | ///
                            firstharmfulevent == "24")

    gen fatal_animal_collision = animal_collision*fatal_collision
    gen injury_animal_collision = animal_collision&injury_collision
    gen major_injury_animal_collision = animal_collision*major_injury_collision
    gen minor_injury_animal_collision = animal_collision*minor_injury_collision
    gen pdo_animal = animal_collision*pdo_collision
    gen animal_fatalities = animal_collision*total_fatalities
    gen animal_injuries = animal_collision*total_injuries
        
    gen alcohol_collision = (alcoholinvolvementflag == 1)
    gen fatal_alcohol_collision = alcohol_collision*fatal_collision
    gen injury_alcohol_collision = alcohol_collision*injury_collision
    gen major_injury_alcohol_collision = alcohol_collision*major_injury_collision
    gen minor_injury_alcohol_collision = alcohol_collision*minor_injury_collision
    gen pdo_alcohol = alcohol_collision*pdo_collision
    gen alcohol_fatalities = alcohol_collision*total_fatalities 
    gen alcohol_injuries = alcohol_collision*total_injuries
    
    * There is usually a tiny overlap between animal and alcohol collisions 
    tab animal_collision alcohol_collision
    
    collapse (sum) total_all_cause /// 
                   fatal_collision ///
                   injury_collision /// 
                   total_fatalities ///
                   major_injury_collision /// 
                   minor_injury_collision /// 
                   total_injuries /// 
                   pdo_collision /// 
                   animal_collision /// 
                   fatal_animal_collision /// 
                   injury_animal_collision /// 
                   major_injury_animal_collision ///
                   minor_injury_animal_collision /// 
                   pdo_animal /// 
                   animal_fatalities /// 
                   animal_injuries /// 
                   alcohol_collision /// 
                   fatal_alcohol_collision ///
                   injury_alcohol_collision /// 
                   major_injury_alcohol_collision ///
                   minor_injury_alcohol_collision /// 
                   pdo_alcohol /// 
                   alcohol_fatalities /// 
                   alcohol_injuries, ///
                   by(fips year)

    append using `fullfile', force
    save `fullfile', replace
}

* Cleanup 
drop if drop_me == 1
drop drop_me

* Add 1997-1999
append using `CSV', force


drop county_code  /* we have the FIPS code now, this is not necessary anymore */

/*-----------------SECTION 3: merge with state_county_identifiers --------------*/
tostring fips, replace
replace fips = "0" + fips if length(fips) == 4
merge m:1 fips using "$path/dataSTATA/state_county_identifiers.dta", keep(1 3)
br if _merge == 1
drop _merge
drop if county_name == "" | county_name == "total"

destring fips, replace 

tab year


order state_letter_code ///
      state_name          ///
      county_name         ///
      state_fips          ///
      county_fips         ///
      fips                ///
      year                ///
      total* /// 
      animal* ///
      alcohol*

sort fips year

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_PA_county_year_`T1'_`T2'.dta", replace


