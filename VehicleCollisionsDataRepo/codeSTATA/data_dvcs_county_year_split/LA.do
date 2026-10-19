/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
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

*************************LA (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 05-19   <] */
/*----------------------------------------------------*/
/* [> loop thru all the files in the folder <] */
clear
global path_la "$path/dataRAW/DVCs/LA/"
cd "$path_la/"
local all_files : dir . files "D8*.csv"
display `all_files'


tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

set excelxlsxlargefile on

foreach file in `all_files' {

  import delimited using "`file'", rowrange(4:76) colrange(:8) case(lower) clear
  gen year =  substr("`file'",4,4)

  /* save as a dta file*/
  append using `fullfile'
  save `fullfile', replace
}


drop if drop_me == 1
drop drop_me

keep ï fatalâ  v3  injuryâ  v6 pdoâ  year v1 fatal injury pdo
ren ï county_name
ren fatalâ total_fatal
ren v3 total_fatalities
ren injuryâ total_injury
ren v6 total_injuries
ren pdoâ total_pdo

replace county_name = v1 if year == "2005"
replace total_fatal = fatal if year == "2005"
replace total_injury = injury if year == "2005"
replace total_pdo = pdo if year == "2005"

drop if total_fatal==.
drop if county_name =="Driver Average"
drop if county_name == "PARISHES WITH LICENSED DRIVERS BETWEEN 10000-20000"
drop if county_name == "PARISHES WITH LICENSED DRIVERS BETWEEN 20000-50000"
drop if county_name == "PARISHES WITH LICENSED DRIVERS BETWEEN 50000-100000"
drop v1 fatal injury pdo 

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "de soto" if county_name == "desoto"

tempfile total
save `total', replace

 
/*----------------------------------------------------*/
      /* [>   2.  Animal 05-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/LA/LA.AnimalCrash.2005-2014.CountySeverity.Hutchinson.xlsx"

import excel using "`file_name'", allstring cellrange(A5:G564) firstrow case(lower) clear

rename rowlabels county_name
rename fatal animal_fatal
rename severe animal_major_injury
rename moderate animal_minor_injury
gen animal_injury = animal_major_injury + animal_minor_injury
gen animal_pdo = complaint + noinjury
drop complaint noinjury
rename grandtotal animal_total

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "de soto" if county_name == "desoto"

egen year = sieve(county_name), keep(n)
replace year= year[_n-1] if year== ""

 * replaces the years to total. regexm(s, re) ~ regular expression, replaces the specified expressions in the selected string 
 
replace county_name = "total" if  regexm(county_name,"^[0-9]+[0-9]+[0-9]+[0-9]")
*also: replace county_name = "total" if ustrregexm(county_name, "^[0-9]") == 1


/*----------------------------------------------------*/
      /* [>   3.  Merge with Total   <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `total', nogen 
sort county_name year, stable
drop if county_name == "total"

gen state_letter_code  = "LA" // add state abbreviation

destring animal_total ///
        animal_fatal ///
        animal_major_injury ///
        animal_minor_injury ///
		animal_injury ///
		animal_pdo ///
        year, ignore("," "NA" " ") replace

assert  animal_fatal>=0 ///
        & animal_major_injury>=0 ///
        & animal_minor_injury>=0 ///
		& animal_injury>= 0 ///
		& animal_pdo>= 0 ///
        & animal_total>=0 ///
        & total_fatal>=0 ///
        & total_fatalities>=0 ///
        & total_injury>=0 ///
        & total_injuries>=0 ///
        & total_pdo>=0 , fast // sanity check

/*----------------------------------------------------*/
      /* [>   4. Merge with  state_county_identifiers <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

sort county_name year, stable 

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
    fips year

/* [> imputation <] */
foreach var in animal_fatal animal_major_injury animal_minor_injury animal_injury animal_total {
    replace `var'= 0 if `var'==. & year>=2005 & year<=2014
}

gen total_total = total_fatal+total_injury+total_pdo

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_LA_county_year_`T1'_`T2'.dta" ,replace
