/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
05/23/2021 [Rukhshan Arif Mian]: commented out line 102 (dont drop county_num as it is used. just drop _merge)
06/01/2025 [Emily Price]: updated for 2015-onwards, referencing shapefile conversion code in R
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

/*-----------------SECTION 1: process data 2004-2014 --------------*/

clear
local file_name = "$path/dataCSV/DVCs/IA/iowa_counties.xlsx"
import excel using "`file_name'",firstrow case(lower) clear

rename countyname county_name
rename countynum county_num

sort county_num

tempfile match_countyname
save `match_countyname', replace

/* [> loop thru all the files in the folder <] */
clear
global path_ia "$path/dataCSV/DVCs/IA/"
cd "$path_ia/"
local all_files : dir . files "*county*.xlsx"
display `all_files'


tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

foreach file in `all_files' {
    import excel using "`file'" , describe

    import excel using "`file'", allstring cellrange(`r(range_1)') firstrow case(lower) clear
    gen year =  substr("`r(worksheet_1)'",-4,.)
    gen str12 suffix = substr("`file'", 1,1)  /* create variable suffix that will be added to crash data*/

    /* save as a dta file create a local with the .xls extension and space removed */
    append using `fullfile'
    save `fullfile', replace
}


drop if drop_me == 1
drop drop_me

rename county county_num
destring county_num count sum* year, replace
sort county_num


/* [> merge with county_name <] */
merge m:1 county_num using `match_countyname'
rename _all, lower
drop _merge
 
keep sum_fatalc ///
     sum_majorc ///
     sum_minorc ///
     sum_pdoc ///
     sum_possun  ///
     count ///
     sum_fatali ///
     sum_injuri ///
     county_name ///
     county_num ///
     year ///
     suffix
	

reshape wide sum_fatalc ///
             sum_majorc ///
             sum_minorc ///
             sum_pdoc ///
             sum_possun ///
             sum_fatali ///
             sum_injuri count, ///
             i(county_num year) ///
             j(suffix) ///
             string


drop county_num 


rename counta animal_total
rename sum_fatalca animal_fatal
rename sum_majorca animal_major_injury
gen    animal_minor_injury = sum_minorca + sum_possuna
rename sum_pdoca animal_pdo
rename sum_fatalia animal_fatalities 
rename sum_injuria animal_injuries 
rename countc total_all_cause
rename sum_fatalcc total_fatal
rename sum_majorcc total_major_injury
gen    total_minor_injury = sum_minorcc + sum_possunc
rename sum_pdocc total_pdo
rename sum_fatalic total_fatalities
rename sum_injuric total_injuries

destring animal_total ///
         animal_fatal ///
         animal_major_injury ///
         animal_minor_injury ///
         animal_pdo ///
         animal_fatalities ///
         animal_injuries ///
         total_all_cause ///
         total_fatal ///
         total_major_injury ///
         total_minor_injury ///
         total_pdo ///
         total_fatalities ///
         total_injuries ///
         year, ignore("," "NA" " ") replace

		
gen animal_injury = animal_major_injury + animal_minor_injury
gen total_injury = total_major_injury + total_minor_injury
drop sum_minorca sum_possuna sum_minorcc sum_possunc

gen state_letter_code  = "IA" // add state abbreviation

assert animal_total>=0 ///
       & animal_fatal>=0 ///
       & animal_major_injury>=0 ///
       & animal_minor_injury>=0 ///
       & animal_pdo>=0 ///
	   & animal_fatalities>=0 ///
	   & animal_injuries>=0 ///
       & total_all_cause>=0 ///
       & total_fatal>=0 ///
       & total_minor_injury>=0 ///
       & total_major_injury>=0 ///
	   & total_fatalities>=0 ///
	   & total_injuries>=0 ///
       & total_pdo>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "new castle" if county_name == "newcastle"
drop if county_name==""

tempfile old_data
save `old_data', replace

/*-----------------SECTION 2: processing 2015-2026 --------------*/

/** data processing begins here **/

* First, assign XY coordinates with their county identifiers, done in R
rscript using "$path/codeR/IA_Shapefile_Conversion.R"

clear
set excelxlsxlargefile on
local file_name = "$path/dataRAW/DVCs/IA/CrashData_UoC.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

* add crash_id to match with R spatial join output. we converted the shapefile into the correct projection in R 
*gen crash_id = _n

* merge in county fips from R
preserve
    import delimited "$path/dataRAW/DVCs/IA/crash_coords_to_fips.csv", clear stringcols(3)
    tempfile fips_lookup
    save `fips_lookup', replace
restore

merge m:1 xcoord ycoord using `fips_lookup'
* One PDO crash in 2015 does not have XY coordinates—will get dropped
assert _merge == 3 if !missing(xcoord) & !missing(ycoord)
keep if _merge == 3
drop _merge 

rename crash_year year
rename crashseverityclass severity

* create total_all_cause — one row per crash
gen total_all_cause = 1

* severity indicators
gen total_fatal       = (severity == "Fatal")
gen total_major_injury    = (severity == "Serious")
gen total_minor_injury    = (severity == "Minor" | severity == "Possible")
gen total_pdo         = (severity == "PDO")
gen total_injury      = total_major_injury + total_minor_injury

* fatalities and injuries from raw columns
rename fatalities total_fatalities
rename serious_injuries total_major_injuries
gen total_minor_injuries = minor_injury + possible_injuries

* animal collisions
gen animal_total          = (strpos(major_cause, "Animal-Related") > 0)
gen animal_fatal          = animal_total * total_fatal
gen animal_major_injury   = animal_total * total_major_injury
gen animal_minor_injury   = animal_total * total_minor_injury
gen animal_pdo            = animal_total * total_pdo
gen animal_fatalities     = animal_total * total_fatalities
gen animal_injuries       = animal_total * (total_major_injuries + total_minor_injuries)
gen animal_injury         = animal_major_injury + animal_minor_injury

gen state_letter_code = "IA"

* collapse to county-year level
collapse (sum) total_all_cause ///
               total_fatal ///
               total_major_injury ///
               total_minor_injury ///
               total_pdo ///
               total_fatalities ///
               total_major_injuries ///
               total_minor_injuries ///
               total_injury ///
               animal_total ///
               animal_fatal ///
               animal_major_injury ///
               animal_minor_injury ///
               animal_pdo ///
               animal_fatalities ///
               animal_injuries ///
               animal_injury, ///
               by(fips year state_letter_code)


* sanity check
assert animal_total >= 0 ///
       & animal_fatal >= 0 ///
       & animal_major_injury >= 0 ///
       & animal_minor_injury >= 0 ///
       & animal_pdo >= 0 ///
       & animal_fatalities >= 0 ///
       & animal_injuries >= 0 ///
       & total_all_cause >= 0 ///
       & total_fatal >= 0 ///
       & total_major_injury >= 0 ///
       & total_minor_injury >= 0 ///
       & total_pdo >= 0 ///
       & total_fatalities >= 0 ///
       & total_injury >= 0, fast

			  
/*-----------------SECTION 3: final processing --------------*/


local state_county_identifiers "$path/dataSTATA/state_county_identifiers.dta"

* new data: merge on fips to get county_name and other identifiers
merge m:1 state_letter_code fips using "`state_county_identifiers'", keep(1 3)
drop _merge

* append old data
append using `old_data'

count

* fill in missing identifiers for old data using county_name
merge m:1 state_letter_code county_name using "`state_county_identifiers'", update
drop if _merge == 2
drop _merge

drop if county_name == ""


sort county_name year, stable 
order state_letter_code ///
      state_name ///
      county_name ///
      state_fips ///
      county_fips ///
      fips year ///
      total* ///
      animal*


qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_IA_county_year_`T1'_`T2'.dta" ,replace
/* [> Any animal…domestic or wild…but most likely deer in Iowa (95%+) <] */
