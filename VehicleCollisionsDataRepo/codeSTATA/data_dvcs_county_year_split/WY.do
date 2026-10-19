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

*************************WY (critical crashes & serious crashes are dropped)
/*----------------------------------------------------*/
      /* [>   1.  Total 94-19   <] */
/*----------------------------------------------------*/
/* [> 15-19 <] */
clear
local file_name = "$path/dataCSV/DVCs/WY/WY.TVC.15-19.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet("`r(worksheet_`s')'") cellrange(A1:I6) firstrow case(lower) clear

    gen county_name = "`r(worksheet_`s')'"

    tempfile newstata`s'
    save `newstata`s'', replace
}

local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

drop  criticalcrashes seriouscrashes

rename crashesbyyear year
rename fatalcrashes total_fatal
rename fatalities total_fatalities
rename injuries total_injuries
rename injurycrashes total_injury
rename pdocrashes total_pdo
rename totalcrashes total_total

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "uinta" if county_name == "unita"


local pct "  · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |  \   、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
      replace county_name = subinstr(county_name, "`x'", "", .)
 }
drop if county_name==""

tempfile 15_19
save `15_19', replace

/* [> 94-15 <] */
clear
local file_name = "$path/dataRAW/DVCs/WY/WY.TotalCrash.1994 - 2015.CountySeverity.Smith.xls"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring cellrange(A2:I530) firstrow case(lower) clear
 
drop damageamount

rename a year
rename b county_name
rename fatalcrashes total_fatal
rename fatalities total_fatalities
rename injuries total_injuries
rename injurycrashes total_injury
rename pdocrashes total_pdo
rename totalcrashes total_total

replace year = year[_n-1] if yea==""

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name, " county", "", .)

drop if county_name==""
drop if year == "2015"
merge 1:1 county_name year using `15_19', nogen
  
destring total_total ///
        total_fatal ///
        total_injuries ///
        total_injury ///
        total_pdo ///
        total_fatalities ///
        year, ignore("," "NA" " ") replace

assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_pdo>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_total>=0 , fast // sanity check


tempfile total
save `total', replace
 
/*----------------------------------------------------*/
      /* [>   2.  Deer 94-15   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/WY/WY.DeerCrash.1994 - 2015.CountySeverity.Smith.xls"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring cellrange(A2:I530) firstrow case(lower) clear

drop damageamount

rename a year
rename b county_name
rename fatalcrashes deer_fatal
rename fatalities deer_fatalities
rename injuries deer_injuries
rename injurycrashes deer_injury
rename pdocrashes deer_pdo
rename totalcrashes deer_total

replace year = year[_n-1] if yea==""

duplicates list
duplicates drop
drop if county_name==""

destring deer_total ///
        deer_fatal ///
        deer_injuries ///
        deer_injury ///
        deer_pdo ///
        deer_fatalities ///
        year, ignore("," "NA" " ") replace

assert deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_pdo>=0 ///
    & deer_fatalities>=0 ///
    & deer_injuries>=0 ///
    & deer_total>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name, " county", "", .)


merge 1:1 county_name year using `total', nogen 
 
sort year county_name, stable
gen state_letter_code  = "WY" // add state abbreviation


/*----------------------------------------------------*/
      /* [>   3.  Updated Total & Animal & Deer 94-19   <] */
/*----------------------------------------------------*/
clear
global path_wy "$path/dataRAW/DVCs/WY/"
cd "$path_wy/"
local all_files : dir . files "*Crash Counts by County 1994 - 2019.csv"
display `all_files'
 
// tempfile fullfile
// set obs 1
// gen drop_me = 1
// save `fullfile', replace 

local  x = 1 
foreach file in `all_files' {
    clear
    import delimited using "`file'", clear varnames(nonames) case(lower) stringcols(_all) bindquotes(strict)
	
    drop in 1/2
	drop v8
	*ren v1 v
	*split v, parse(,)
	 
    ren v1 county_name
	
    gen str12 year = county_name if ustrregexm(county_name, "([0-9])")==1
    replace year=year[_n-1] if year==""
    drop if ustrregexm(county_name, "([0-9])")==1
 
    compress

    local suffix= substr("`file'",1,4)
	 
    ren v2 `suffix'_total
    ren v3 `suffix'_fatal
    ren v4 `suffix'_fatalities
    ren v5 `suffix'_injury
    ren v6 `suffix'_injuries
    ren v7 `suffix'_pdo
	 
	
	if `x' == 1 {
	    tempfile fullfile
		local x = `x' + 1
	}
	else {
	    merge 1:1 county year using `fullfile', nogen
	}
	
	save `fullfile', replace 


}
 

ren anim_* animal_*
ren cras_* total_*

destring animal_* ///
        total_* ///
        deer_* ///
        year, ignore("," "NA" " ") replace

 
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st ") == 1
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""

gen state_letter_code  = "WY" // add state abbreviation

assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_pdo>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_total>=0 ///
    & deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_pdo>=0 ///
    & deer_fatalities>=0 ///
    & deer_injuries>=0 ///
    & deer_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_pdo>=0 ///
    & animal_fatalities>=0 ///
    & animal_injuries>=0 ///
    & animal_total>=0 , fast // sanity check

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

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_WY_county_year_`T1'_`T2'.dta" ,replace
