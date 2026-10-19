/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
10/22/2020 [Owen Shao ]: Add CALTRANS 2009-2019
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


/*-------------------------
  To Do:
     - [1] derive dta files for all the states
     - [2] merge dta files
-------------------------*/


/*----------------------------------------------------*/
      /* [>   1.  derive dta for CALTRANS 09-19 all collisons (~/dataCSV/DVCs/) <] */
/*----------------------------------------------------*/

clear
cd "$path/dataRAW/DVCs/CA/CALTRANS/2009-2019_Caltrans_All_Collision_Datasets/"
set excelxlsxlargefile on
local all_files : dir . files "*.xlsx"
display `all_files'

tempfile allcrashes
set obs 1
gen drop_me = 1
save `allcrashes', replace

foreach file in `all_files' {
  clear
  import excel using "`file'", firstrow clear
  keep C  SEVERITY_LEVEL ACC_DATE
  
  append using `allcrashes'
  save `allcrashes', replace
}

drop if drop_me == 1
drop drop_me

format %tdDD/NN/CCYY ACC_DATE

gen year = year(ACC_DATE)
ren C county_name
replace county_name = "Alameda" if county_name == "ALA"
replace county_name = "Alpine" if county_name == "ALP"
replace county_name = "Amador" if county_name == "AMA"
replace county_name = "Butte" if county_name == "BUT"
replace county_name = "Calaveras" if county_name == "CAL"
replace county_name = "Colusa" if county_name == "COL"
replace county_name = "Contra Costa" if county_name == "CC"
replace county_name = "Del Norte" if county_name == "DN"
replace county_name = "El Dorado" if county_name == "ED"
replace county_name = "Fresno" if county_name == "FRE"
replace county_name = "Glenn" if county_name == "GLE"
replace county_name = "Humboldt" if county_name == "HUM"
replace county_name = "Imperial" if county_name == "IMP"
replace county_name = "Inyo" if county_name == "INY"
replace county_name = "Kern" if county_name == "KER"
replace county_name = "Kings" if county_name == "KIN"
replace county_name = "Lake" if county_name == "LAK"
replace county_name = "Lassen" if county_name == "LAS"
replace county_name = "Los Angeles" if county_name == "LA"
replace county_name = "Madera" if county_name == "MAD"
replace county_name = "Marin" if county_name == "MRN"
replace county_name = "Mariposa" if county_name == "MPA"
replace county_name = "Mendocino" if county_name == "MEN"
replace county_name = "Merced" if county_name == "MER"
replace county_name = "Modoc" if county_name == "MOD"
replace county_name = "Mono" if county_name == "MNO"
replace county_name = "Monterey" if county_name == "MON"
replace county_name = "Napa" if county_name == "NAP"
replace county_name = "Nevada" if county_name == "NEV"
replace county_name = "Orange" if county_name == "ORA"
replace county_name = "Placer" if county_name == "PLA"
replace county_name = "Plumas" if county_name == "PLU"
replace county_name = "Riverside" if county_name == "RIV"
replace county_name = "Sacramento" if county_name == "SAC"
replace county_name = "San Benito" if county_name == "SBT"
replace county_name = "San Bernardino" if county_name == "SBD"
replace county_name = "San Diego" if county_name == "SD"
replace county_name = "San Francisco" if county_name == "SF"
replace county_name = "San Joaquin" if county_name == "SJ"
replace county_name = "San Luis Obispo" if county_name == "SLO"
replace county_name = "San Mateo" if county_name == "SM"
replace county_name = "Santa Barbara" if county_name == "SB"
replace county_name = "Santa Clara" if county_name == "SCL"
replace county_name = "Santa Cruz" if county_name == "SCR"
replace county_name = "Shasta" if county_name == "SHA"
replace county_name = "Sierra" if county_name == "SIE"
replace county_name = "Siskiyou" if county_name == "SIS"
replace county_name = "Solano" if county_name == "SOL"
replace county_name = "Sonoma" if county_name == "SON"
replace county_name = "Stanislaus" if county_name == "STA"
replace county_name = "Sutter" if county_name == "SUT"
replace county_name = "Tehama" if county_name == "TEH"
replace county_name = "Trinity" if county_name == "TRI"
replace county_name = "Tulare" if county_name == "TUL"
replace county_name = "Tuolumne" if county_name == "TUO"
replace county_name = "Ventura" if county_name == "VEN"
replace county_name = "Yolo" if county_name == "YOL"
replace county_name = "Yuba" if county_name == "YUB"

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1

* counting the number of accidents in a year. In the current dataset, each entry corresponds to an accident. 
bysort year county_name: egen total_total = count(year)
drop SEVERITY_LEVEL ACC_DATE
collapse total, by (year county_name)

tempfile final_CA
save `final_CA', replace
* total crashes by county in final_CA

/*----------------------------------------------------*/
      /* [>   2. Import CALTRANS (animal related  crashes) 2009-2019  <] */
/*----------------------------------------------------*/  
	  
clear
set excelxlsxlargefile on
local file_name = "$path/dataRaw/DVCs/CA/CALTRANS/Caltrans_TSN_2009-2019_Animal_Related_Crash_20200908.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    tempfile newstata`s'
    save `newstata`s'', replace
}

local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

keep county  severity_level year
ren county county_name


replace county_name = "Alameda" if county_name == "ALA"
replace county_name = "Alpine" if county_name == "ALP"
replace county_name = "Amador" if county_name == "AMA"
replace county_name = "Butte" if county_name == "BUT"
replace county_name = "Calaveras" if county_name == "CAL"
replace county_name = "Colusa" if county_name == "COL"
replace county_name = "Contra Costa" if county_name == "CC"
replace county_name = "Del Norte" if county_name == "DN"
replace county_name = "El Dorado" if county_name == "ED"
replace county_name = "Fresno" if county_name == "FRE"
replace county_name = "Glenn" if county_name == "GLE"
replace county_name = "Humboldt" if county_name == "HUM"
replace county_name = "Imperial" if county_name == "IMP"
replace county_name = "Inyo" if county_name == "INY"
replace county_name = "Kern" if county_name == "KER"
replace county_name = "Kings" if county_name == "KIN"
replace county_name = "Lake" if county_name == "LAK"
replace county_name = "Lassen" if county_name == "LAS"
replace county_name = "Los Angeles" if county_name == "LA"
replace county_name = "Madera" if county_name == "MAD"
replace county_name = "Marin" if county_name == "MRN"
replace county_name = "Mariposa" if county_name == "MPA"
replace county_name = "Mendocino" if county_name == "MEN"
replace county_name = "Merced" if county_name == "MER"
replace county_name = "Modoc" if county_name == "MOD"
replace county_name = "Mono" if county_name == "MNO"
replace county_name = "Monterey" if county_name == "MON"
replace county_name = "Napa" if county_name == "NAP"
replace county_name = "Nevada" if county_name == "NEV"
replace county_name = "Orange" if county_name == "ORA"
replace county_name = "Placer" if county_name == "PLA"
replace county_name = "Plumas" if county_name == "PLU"
replace county_name = "Riverside" if county_name == "RIV"
replace county_name = "Sacramento" if county_name == "SAC"
replace county_name = "San Benito" if county_name == "SBT"
replace county_name = "San Bernardino" if county_name == "SBD"
replace county_name = "San Diego" if county_name == "SD"
replace county_name = "San Francisco" if county_name == "SF"
replace county_name = "San Joaquin" if county_name == "SJ"
replace county_name = "San Luis Obispo" if county_name == "SLO"
replace county_name = "San Mateo" if county_name == "SM"
replace county_name = "Santa Barbara" if county_name == "SB"
replace county_name = "Santa Clara" if county_name == "SCL"
replace county_name = "Santa Cruz" if county_name == "SCR"
replace county_name = "Shasta" if county_name == "SHA"
replace county_name = "Sierra" if county_name == "SIE"
replace county_name = "Siskiyou" if county_name == "SIS"
replace county_name = "Solano" if county_name == "SOL"
replace county_name = "Sonoma" if county_name == "SON"
replace county_name = "Stanislaus" if county_name == "STA"
replace county_name = "Sutter" if county_name == "SUT"
replace county_name = "Tehama" if county_name == "TEH"
replace county_name = "Trinity" if county_name == "TRI"
replace county_name = "Tulare" if county_name == "TUL"
replace county_name = "Tuolumne" if county_name == "TUO"
replace county_name = "Ventura" if county_name == "VEN"
replace county_name = "Yolo" if county_name == "YOL"
replace county_name = "Yuba" if county_name == "YUB"


replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1


* gen state_letter_code  = "CA" // add state abbreviation

bysort year county_name: egen animal_total = count(year)
bysort year county_name: egen animal_fatal = count(severity_level) if severity_level == "1"
bysort year county_name: egen animal_injury = count(severity_level) if severity_level == "2"
bysort year county_name: egen animal_pdo = count(severity_level) if severity_level == "0"
drop severity_level

collapse animal_total animal_fatal animal_injury animal_pdo , by (year county_name)


destring year, replace


merge 1:1 year county_name using "`final_CA'", nogenerate


generate state_letter_code = "CA"

tempfile 09_19_CALTRANS
save `09_19_CALTRANS', replace



/*----------------------------------------------------*/
      /* [>   3. Import CALTRANS (all  crashes) 2002-2010  <] */
/*----------------------------------------------------*/  
	  

clear
set excelxlsxlargefile on
local file_name = "$path/dataRaw/DVCs/CA/road traffic injuries 2002-2010.xlsx"
import excel using "`file_name'", allstring cellrange(A1:M448950) firstrow case(lower)
keep reportyear county_name severity injuries mode geotype

keep if mode == "Vehicles" 
drop mode
keep if geotype == "CO" 
drop geotype

drop if strlen(reportyear)!=4

replace severity="total_fatalities" if severity=="Killed"
replace severity="total_injuries" if severity=="Severe Injury"
* spread severity injuries

* reshaping long form data to wide form data
ren reportyear year
egen id = group(year county_name)
reshape wide injuries, i(id year county_name) j(severity) string 
ren injuriestotal_fatalities total_fatalities
ren injuriestotal_injuries total_injuries
drop id



gen state_letter_code  = "CA" // add state abbreviation

destring total_fatalities ///
        total_injuries ///
        year , ignore("," "NA" " ") replace

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "new castle" if county_name == "newcastle"

merge 1:1 year county_name using "`09_19_CALTRANS'", nogenerate

// replace total_total = 0 if missing(total_total)
// replace animal_total = 0 if missing(animal_total)
// replace animal_fatal = 0 if missing(animal_fatal)
// replace animal_injury = 0  if missing(animal_injury)
// replace animal_pdo = 0 if missing(animal_pdo)
// replace total_fatalities = 0 if missing(total_fatalities)
// replace total_injuries = 0  if missing(total_injuries)

assert total_total >=0  ///
    & animal_total >=0 ///
    & animal_fatal >=0 ///
    & animal_injury >=0 ///
	& animal_pdo >= 0 ///
	& total_fatalities >= 0 ///
	& total_injuries >= 0, fast // sanity check

/*----------------------------------------------------*/
      /* [>   4.  Merge with state_county_identifiers  <] */
/*----------------------------------------------------*/

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

sort state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year, stable
	
qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_CA_county_year_`T1'_`T2'.dta" ,replace


