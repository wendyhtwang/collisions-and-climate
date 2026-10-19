/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
05/23/2021 [Rukhshan Arif Mian]: return list issue. the local variables disappear so have to call import file again in lines 84-86. 
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

*************************WA (jurisdiction is dropped)
/*----------------------------------------------------*/
      /* [>   1.  Total 09-15   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/WA/WA.TVC.09-15.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/3 {
		 
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(:J197) firstrow case(lower) clear
	
	gen year = `r(worksheet_`s')'

    rename collisionsbycounty county_name
    replace county_name=county_name[_n-1] if county_name==""


    keep if jurisdiction == "Total"

    drop jurisdiction

    rename numberoffatalities total_fatalities
    rename numberofseriousinjuries total_major_injuries
    rename numberofminorinjuries total_minor_injuries

 
	
    tempfile newstata`s'
    save `newstata`s'', replace
	
	//calling this here again
	clear
	local file_name = "$path/dataCSV/DVCs/WA/WA.TVC.09-15.CountySeverity.xlsx"
	import excel using "`file_name'" , describe
}

forvalue s = 4/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(:G45) firstrow case(lower) clear

    rename statewidecollisionsroadtype county_name

    gen year = `r(worksheet_`s')'

    tempfile newstata`s'
    save `newstata`s'', replace
}

local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

rename propertydamageonlycollisions total_pdo
rename minorinjurycollisions total_minor_injury
rename seriousinjurycollisions total_major_injury
rename fatalcollisions total_fatal
rename totalcollisions total_total

destring total_total ///
        total_fatal ///
        total_major_injury ///
        total_minor_injury ///
        total_fatalities ///
        total_major_injuries ///
        total_minor_injuries ///
        total_pdo ///
        year, ignore("," "NA" " ") replace

assert total_total>=0  ///
    & total_fatal >=0 ///
    & total_major_injury>=0 ///
    & total_minor_injury>=0 ///
    & total_fatalities>=0 ///
    & total_major_injuries>=0 ///
    & total_minor_injuries>=0 ///
    & total_pdo>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "statewide all roads"
drop if county_name == "city streets"
drop if county_name == "county roads"
drop if county_name == "other roads"
drop if county_name == "state routes"

duplicates list
duplicates drop
drop if county_name==""

drop unknowninjurycollisions
sort county_name year, stable

tempfile CSV
save `CSV', replace
 
/*----------------------------------------------------*/
      /* [>   2.  Total & Wild animal & Deer 05-19   <] */
/*----------------------------------------------------*/
clear
global path_wa "$path/dataRAW/DVCs/WA/records_level_data"
cd "$path_wa/"
local all_files : dir . files "All_roads_Statewide_*.csv"
display `all_files'


tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

foreach file in `all_files' {
    import delimited using "`file'", colrange(:38) stringcols(_all) clear

    keep county reportnumber year totalcrashes fatalcrashes seriousinjurycrashes evidentinjurycrashes possibleinjurycrashes  pdonoinjurycrashes totalfatalities totalseriousinjuries totalevidentinjuries totalpossibleinjuries firstcollisiontypeobjectstruck
	  
    ren county county_name
    ren reportnumber crashid
    ren firstcollisiontypeobjectstruck type
    ren totalcrashes total_total
    ren fatalcrashes total_fatal
    ren seriousinjurycrashes total_major_injury
    ren evidentinjurycrashes total_minor_injury
	ren possibleinjurycrashes total_possible_injury 
    ren pdonoinjurycrashes total_pdo
    ren totalfatalities total_fatalities
    ren totalseriousinjuries total_major_injuries
    ren totalevidentinjuries total_minor_injuries
	ren totalpossibleinjuries total_possible_injuries
 
    replace total_pdo = "" if strpos(total_pdo,"?") != 0
    replace total_major_injuries = "" if strpos(total_major_injuries,"?") != 0
	replace total_possible_injuries = "" if strpos(total_possible_injuries,"?") != 0
	replace total_possible_injury = "" if strpos(total_possible_injury,"?") != 0
	

    destring total_total ///
            total_fatal ///
            total_major_injury ///
            total_minor_injury ///
			total_possible_injury ///
            total_fatalities ///
            total_major_injuries ///
            total_minor_injuries ///
			total_possible_injuries ///
            total_pdo ///
            year, ignore("," "NA" " ") replace

    tempfile f
    save `f', replace

    collapse (sum) total_total total_fatal total_major_injury total_minor_injury total_possible_injury total_pdo total_fatalities total_major_injuries total_minor_injuries total_possible_injuries, by(county_name year)
    tempfile total
    save `total', replace

    if year >= 2009 {
        use `f', replace
        collapse (sum) total_total total_fatal total_major_injury total_minor_injury total_possible_injury total_pdo total_fatalities total_major_injuries total_minor_injuries total_possible_injuries if type == "Vehicle Strikes Deer", by(county_name year)
        ren total* deer*
        tempfile deer
        save `deer', replace
    }
 
    else {
        use `f', replace
        collapse (sum) total_total total_fatal total_major_injury total_minor_injury total_possible_injury total_pdo total_fatalities total_major_injuries total_minor_injuries total_possible_injuries if type == "Non-domestic animal (deer, bear, elk, etc)", by(county_name year)
        ren total* wild_animal*
        tempfile wild_animal
        save `wild_animal', replace
    }
	 	
    merge 1:1 county_name year using `total', nogenerate
	 
    append using `fullfile'
    save `fullfile', replace
}
 
drop if drop_me == 1
drop drop_me

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)

local pct "  · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |  \   、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
      replace county_name = subinstr(county_name, "`x'", "", .)
 }

sort county_name year, stable
 
tempfile RAW
save `RAW', replace

merge 1:1 county_name year using `CSV', update
br if _merge != 3
drop _merge

destring wild_animal_total ///
        wild_animal_fatal ///
        wild_animal_major_injury ///
        wild_animal_minor_injury ///
		wild_animal_possible_injury ///
        wild_animal_pdo ///
        total_total ///
        total_fatal ///
        total_major_injury ///
        total_minor_injury ///
		total_possible_injury ///
        total_pdo ///
        year, ignore("," "NA" " ") replace

/*Imputation*/
gen total_injury = total_major_injury + total_minor_injury + total_possible_injury
gen total_injuries = total_major_injuries + total_minor_injuries + total_possible_injuries
gen wild_animal_injury = wild_animal_major_injury + wild_animal_minor_injury + wild_animal_possible_injury
gen wild_animal_injuries = wild_animal_major_injuries + wild_animal_minor_injuries + wild_animal_possible_injuries
gen deer_injury = deer_major_injury + deer_minor_injury + deer_possible_injury
gen deer_injuries = deer_major_injuries + deer_minor_injuries + deer_possible_injuries

/*----------------------------------------------------*/
      /* [>   3.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/

*creating a balanced dataset 
/*
fillin year county_name
drop _fillin
*/

gen state_letter_code  = "WA" // add state abbreviation
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == "" | county_name == "total" | year == . | year == 2020

order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year total* wild_animal* deer*	

sort county_name year, stable
	
qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_WA_county_year_`T1'_`T2'.dta" ,replace
