/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
07/26/2020 [Siyue Ouyang]: add data in ~dataRAW, update
05/23/2021 [Rukhshan Arif Mian]: it seems as if line 111 was being used to take into account a corner case. i commented it out in order for the code to run  (was breaking otherwise - there wasn't a need for a rename')

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

*************************FL (all data were kept)************************
/*Total 1990-2009*/

clear
global path_ia "$path/dataCSV/DVCs/FL/"
cd "$path_ia/"
local all_files : dir . files "FL.TVC*.xlsx"
display `all_files'


local i=0
foreach file in `all_files' {
    clear
    tempfile newstata
    import excel using "`file'" , describe
    forvalues s =1/`r(N_worksheet)' {
        clear
        import excel using "`file'" , describe
        import excel using "`file'", sheet(`r(worksheet_`s')') cellrange(:F70) case(lower) clear
		
        foreach v of varlist B-F {
          local year = `v'[1]
          *rename `v' `r(worksheet_`s')'_`year'
		  rename `v' total_`r(worksheet_`s')'`year'
        }
		
        ren A county_name
        drop in 1

        local pct " ' · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |     、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
        foreach x of local pct {
             replace county_name = subinstr(county_name, "`x'", "", .)
         }
        replace county_name = word(county_name,1) if county_name =="HILLSBOROUGH     6228    8362    8357    8441"
        replace county_name = lower(county_name)
        replace county_name = strtrim(county_name)
        replace county_name = ustrtrim(county_name)
        replace county_name = "total" if county_name == "total:"
        replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
        replace county_name = subinstr(county_name, " county", "", .)
        replace county_name = "desoto" if county_name == "de soto"
        replace county_name = "miami-dade" if county_name == "miamidade"
		replace county_name = "miami-dade" if county_name == "dade" //former name
        drop if county_name==""

        import excel using "`file'" , describe
		
		gen id = _n
		reshape long  total_`r(worksheet_`s')', i(id county_name) j(year)
		drop id
		
        if "`file'"=="FL.TVC.90-94.CountyTotalFatal.xlsx" {
            drop if year==1994
        }
		
        rename *, lower

        if `s' > 1{
            merge 1:1 county_name year using `newstata', nogen
        }

        save `newstata', replace
    }

    local i=`i'+1
    di `i'
    if `i' > 1 {
        merge 1:1 county_name year using `fullfile', update nogen
        save `fullfile', replace
    }
    if `i' == 1  {
        tempfile fullfile
        save `fullfile', replace
    }
}

replace total_fatality = total_fatal if total_fatality == .
drop total_fatal
rename total_injury total_injuries
rename total_fatality total_fatalities

drop if county_name=="unknown" | county_name=="statewide"

collapse (sum) total_pdo total_injuries total_fatalities total_total, by(county year)
duplicates report county year

destring total_total ///
        total_fatalities ///
        total_injuries ///
        total_pdo ///
        year, ignore("," "NA" " ") replace

assert total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_pdo>=0 ///
    & total_total>=0 , fast // sanity check

//FL.TVC.90-94.CountyTotalFatal.xlsx doesn't report total_pdo & total_injury
replace total_pdo = . if year>=1990 & year<=1993
replace total_injuries = . if year>=1990 & year<=1993 

tempfile CSV
save `CSV', replace

/*----------------------------------------------------*/
      /* [>   2.  TVCs AVCs 2010-19   <] */
/*----------------------------------------------------*/
/* [> county_name file <] */
clear
local file_name = "$path/dataRAW/DVCs/FL/USED/County_code.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

// replace A = subinstr(A," ","", .) if strpos(A,"ST.") == 0
// gen county_code = real(regexs(1)) if regexm(A ,"([0-9]+)")
// generate county_name = substr(A, strpos(A,".") + 1,.)
// drop A

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
sort county_code

tempfile match_countyname
save `match_countyname', replace


/* [> record level data <] */
clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace


forvalues n= 2010/2019 {
	clear 
	local file_name = "$path/dataRAW/DVCs/FL/USED/`n'/non_redacted_`n'_event.csv"
	import delimited using "`file_name'", varnames(1) case(lower)  bindquote(strict) maxquotedrows(99999999) clear
	
	keep report_number crash_year county_code first_harmful_event
	destring report_number crash_year county_code first_harmful_event, replace
	duplicates drop
	
	tempfile `n'_events
	save ``n'_events', replace
	
    local file_name = "$path/dataRAW/DVCs/FL/USED/`n'/non_redacted_`n'_driver.csv"
	import delimited using "`file_name'", varnames(1) case(lower) stringcols(_all)  bindquote(strict) maxquotedrows(99999999) clear

	keep report_number crash_year injury_severity
	if crash_year == "2011" {
		drop if crash_year == "FL"
		drop if strpos(injury_severity, "MDFD")
		foreach x in crash_year injury_severity{
			replace `x' = strtrim(`x')
			replace `x' = ustrtrim(`x')
			replace `x' = subinstr(`x', ",", "", .)
			replace `x' = subinstr(`x', " ", "", .)
			replace `x' = subinstr(`x', "-", "", .)
		}
	}

	destring report_number crash_year injury_severity, replace
	drop if report_number == .
	
	* only keep crash ids with highest injury severity
	collapse (max) injury_severity, by(report_number crash_year)
	
/*
	tempfile `n'_driver
	save ``n'_driver', replace
	
	clear 
	local file_name = "$path/dataRAW/DVCs/FL/USED/`n'/non_redacted_`n'_event.csv"
	import delimited using "`file_name'", varnames(1) case(lower)  bindquote(strict) maxquotedrows(99999999) clear
	
	keep report_number crash_year county_code first_harmful_event
	destring report_number crash_year county_code first_harmful_event, replace
	duplicates drop
*/

	merge m:1 report_number using ``n'_events', nogen
	drop if injury_severity == . 
	append using `fullfile', force
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me
rename crash_year year

merge m:1 county_code using `match_countyname', nogen
drop county_code
drop if county_name == "unknown" | county_name == "" | county_name == "statewide"

egen total_fatal = total(injury_severity== 5), by(county_name year) 
egen total_possible_injury = total(injury_severity== 2), by(county_name year)
egen total_major_injury = total(injury_severity== 4), by(county_name year)
egen total_minor_injury = total(injury_severity== 3), by(county_name year)
egen total_pdo = total(injury_severity== 1), by(county year)
gen total_injury = total_possible_injury + total_minor_injury + total_major_injury
bys county_name year: gen total_total =_N // total_total

egen animal_fatal = total(injury_severity==5 & first_harmful_event==13), by(county_name year) 
egen animal_possible_injury = total(injury_severity==2 & first_harmful_event==13), by(county_name year)
egen animal_minor_injury = total(injury_severity==3 & first_harmful_event==13), by(county_name year)
egen animal_major_injury = total(injury_severity==4 & first_harmful_event==13), by(county_name year)
gen animal_injury = animal_possible_injury + animal_minor_injury + animal_major_injury
egen animal_pdo = total(injury_severity==1 & first_harmful_event== 13), by(county year)
bys county_name year: egen animal_total = total(first_harmful_event==13)

drop report_number first_harmful_event injury_severity
duplicates drop

append using `CSV', force

assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_total>=0 , fast // sanity check
	
/*----------------------------------------------------*/
      /* [>   3.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/

* creating a balanced dataset
fillin year county_name
drop _fillin

gen state_letter_code  = "FL" // add state abbreviation

local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge!=3
drop _merge

drop if county_name == ""
drop if county_name == "statewide"

sort county_name year, stable

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
save "$working_data/dvcs_FL_county_year_`T1'_`T2'.dta" ,replace
