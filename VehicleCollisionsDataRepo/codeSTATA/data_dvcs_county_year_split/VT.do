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

*************************VT (unknown crash type is dropped)
/*----------------------------------------------------*/
      /* [>   1.  Total & Deer 92-14   <] */
/*----------------------------------------------------*/
/* [> total crash <] */
clear
local file_name = "$path/dataRAW/DVCs/VT/VT.Total&DeerCrash.1992-2014.CountySeverity.White.xlsx"
import excel using "`file_name'", allstring cellrange(A3:I371) firstrow case(lower) clear

rename a year
rename b county_name
rename injurycrashes total_injury
rename injuries total_injuries
rename fatalcrashes total_fatal
rename fatalities total_fatalities
rename propertydamageonlycrashes total_pdo
rename totalcrashes total_total
rename unknowncrashtype total_unknown_severity

replace year=year[_n-1] if year==""
drop if county_name==""

destring total_total ///
        total_fatal ///
        total_injuries ///
        total_injury ///
        total_pdo ///
        total_fatalities ///
		total_unknown_severity ///
        year, ignore("," "NA" " ") replace

sort county_name year, stable

tempfile vt_total
save `vt_total', replace
 
/* [> deer crash <] */
clear
local file_name = "$path/dataRAW/DVCs/VT/VT.Total&DeerCrash.1992-2014.CountySeverity.White.xlsx"
import excel using "`file_name'", describe
import excel using "`file_name'", allstring sheet(`r(worksheet_2)') cellrange(A3:I371) firstrow case(lower) clear

rename a year
rename b county_name
rename injurycrashes deer_injury
rename injuries deer_injuries
rename fatalcrashes deer_fatal
rename fatalities deer_fatalities
rename propertydamageonlycrashes deer_pdo
rename totalcrashes deer_total
rename unknowncrashtype deer_unknown_severity

replace year=year[_n-1] if year==""
drop if county_name==""

destring deer_total ///
        deer_fatal ///
        deer_injury ///
        deer_pdo ///
        deer_fatalities ///
        deer_injuries ///
		deer_unknown_severity ///
        year, ignore("," "NA" " ") replace

/* [> merge with total data <] */
sort county_name year, stable
merge m:m year county_name using `vt_total'
br if _merge !=3
drop _merge

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "totals"
replace county_name = subinstr(county_name, " co.", "", .)
replace county_name = subinstr(county_name, " county", "", .)

drop if county_name == ""

sort county_name year, stable
gen state_letter_code  = "VT" // add state abbreviation

/* [> Merge with state_county_identifiers <] */
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

tempfile CSV_92_14
save `CSV_92_14', replace
 
/*----------------------------------------------------*/
      /* [>   2.  Total & Animal & Deer 10-19   <] */
/*----------------------------------------------------*/
/* [> total <] */
clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

local city_town_identifiers "$path/dataSTATA/_AUX/city_town_identifiers.dta"

forvalues n=2010/2019 {
    clear
    set excelxlsxlargefile on
    global path_vt_total "$path/dataRAW/DVCs/VT/VT.TVC.`n'.Record/"
    cd "$path_vt_total/"
    local all_files : dir . files "`n'*.csv"
    display `all_files'

    foreach file in `all_files' {
        import delimited using "`file'", varnames(1) case(lower) stringcols(_all) clear

        keep objectid citytown crashdate crashtype
        append using `fullfile', force
        save `fullfile', replace
    }
}

drop if drop_me == 1
drop drop_me

split crashdate, gen(part) parse(", ")
gen year = part2
drop part* crashdate

ren citytown city_name

replace city_name = lower(city_name)
replace city_name = strtrim(city_name)
replace city_name = subinstr(city_name, " city", "", .)
replace city_name = subinstr(city_name, " town", "", .)
replace city_name = "enosburgh" if city_name == "enosburg"
replace city_name = "alburgh" if city_name == "alburg"
replace city_name = "isle la motte" if city_name == "isle lamotte"
replace city_name = "mount holly" if city_name == "mt. holly"
replace city_name = "mount tabor" if city_name == "mt. tabor"
replace city_name = "warren's gore" if city_name == "warrens gore"


gen state_fips="50"

merge m:1 state_fips city_name using "`city_town_identifiers'", keep(1 3)
br if _merge==1
drop _merge
drop city_name


egen total_fatal = total(crashtype=="Fatal"), by(county year)  //total
egen total_injury = total(crashtype=="Injury"), by(county year)
egen total_pdo = total(crashtype=="Property Damage Only"), by(county year)
bys county year: gen total_total =_N // total_total
drop crashtype objectid
duplicates drop

sort county year, stable

tempfile total
save `total', replace

/* [> animal <] */
clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

local city_town_identifiers "$path/dataSTATA/_AUX/city_town_identifiers.dta"

clear
set excelxlsxlargefile on
global path_vt_animal "$path/dataRAW/DVCs/VT/"
cd "$path_vt_animal/"
local all_files : dir . files "VT.AVC.*.csv"
display `all_files'

foreach file in `all_files' {
    import delimited using "`file'", varnames(1) case(lower) stringcols(_all) clear

    keep objectid citytown crashdate crashtype
    append using `fullfile', force
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

split crashdate, gen(part) parse(", ")
gen year = part2
drop part* crashdate

ren citytown city_name

replace city_name = lower(city_name)
replace city_name = strtrim(city_name)
replace city_name = subinstr(city_name, " city", "", .)
replace city_name = subinstr(city_name, " town", "", .)
replace city_name = "enosburgh" if city_name == "enosburg"
replace city_name = "alburgh" if city_name == "alburg"
replace city_name = "isle la motte" if city_name == "isle lamotte"
replace city_name = "mount holly" if city_name == "mt. holly"
replace city_name = "mount tabor" if city_name == "mt. tabor"
replace city_name = "warren's gore" if city_name == "warrens gore"


gen state_fips="50"

merge m:1 state_fips city_name using "`city_town_identifiers'", keep(1 3)
br if _merge==1
drop _merge
drop city_name


egen animal_fatal = total(crashtype=="Fatal"), by(county year)  //animal
egen animal_injury = total(crashtype=="Injury"), by(county year)
egen animal_pdo = total(crashtype=="Property Damage Only"), by(county year)
bys county year: gen animal_total =_N // animal_total
drop crashtype objectid
duplicates drop

sort county year, stable

tempfile animal
save `animal', replace


/* [> deer <] */
clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

local city_town_identifiers "$path/dataSTATA/_AUX/city_town_identifiers.dta"

clear
set excelxlsxlargefile on
global path_vt_animal "$path/dataRAW/DVCs/VT/"
cd "$path_vt_animal/"
local all_files : dir . files "VT.DVC.*.csv"
display `all_files'

foreach file in `all_files' {
    import delimited using "`file'", varnames(1) case(lower) stringcols(_all) clear

    keep objectid citytown crashdate crashtype
    append using `fullfile', force
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

split crashdate, gen(part) parse(", ")
gen year = part2
drop part* crashdate

ren citytown city_name

replace city_name = lower(city_name)
replace city_name = strtrim(city_name)
replace city_name = subinstr(city_name, " city", "", .)
replace city_name = subinstr(city_name, " town", "", .)
replace city_name = "enosburgh" if city_name == "enosburg"
replace city_name = "alburgh" if city_name == "alburg"
replace city_name = "isle la motte" if city_name == "isle lamotte"
replace city_name = "mount holly" if city_name == "mt. holly"
replace city_name = "mount tabor" if city_name == "mt. tabor"
replace city_name = "warren's gore" if city_name == "warrens gore"


gen state_fips="50"

merge m:1 state_fips city_name using "`city_town_identifiers'", keep(1 3)
br if _merge==1
drop _merge
drop city_name


egen deer_fatal = total(crashtype=="Fatal"), by(county year)  //deer
egen deer_injury = total(crashtype=="Injury"), by(county year)
egen deer_pdo = total(crashtype=="Property Damage Only"), by(county year)
bys county year: gen deer_total =_N // deer_total
drop crashtype objectid
duplicates drop

sort county year, stable

tempfile deer
save `deer', replace


merge 1:1 county year using `total', nogen
merge 1:1 county year using `animal', nogen

destring year, replace
drop if year == 2020

/* [> Merge with state_county_identifiers <] */
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state county_fips using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

tempfile 10_19
save `10_19', replace

/*----------------------------------------------------*/
      /* [>   4.  Merge with CSV_92_14   <] */
/*----------------------------------------------------*/
use `CSV_92_14', replace
merge 1:1 county_name year using `10_19', update
br if _merge != 3
drop _merge

drop if county_name == "total"

assert total_fatal>=0 ///
    & total_fatalities>=0 ///
    & total_injury>=0 ///
    & total_injuries>=0 ///
    & total_pdo>=0 ///
    & total_total>=0 ///
    & deer_fatal>=0 ///
    & deer_fatalities>=0 ///
    & deer_injury>=0 ///
    & deer_injuries>=0 ///
    & deer_pdo>=0 ///
    & deer_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_pdo>=0 ///
    & animal_total>=0, fast // sanity check

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
save "$working_data/dvcs_VT_county_year_`T1'_`T2'.dta" ,replace
