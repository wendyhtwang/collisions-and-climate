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

*************************OK (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 93-18   <] */
/*----------------------------------------------------*/
/* [> combining OHP and MUN <] */
clear
local file_name = "$path/dataCSV/DVCs/OK/OK.TVC.93-18.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'" , describe
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') case(lower) clear
    gen year = `r(worksheet_`s')'

    drop in 1/2
    ren A county_name

    if year < 1997 {
        if `s' == 1 {
            destring B-L, ignore("," "NA" " ") replace //characters in numbers
            egen total_fatal = rowtotal(B C)
            egen total_injury = rowtotal(D E)
            egen total_pdo = rowtotal(F G)
            ren H total_total

            egen total_fatalities = rowtotal(I J)
            egen total_injuries = rowtotal(K L)
            keep county_name total_fatal total_injury total_pdo total_fatalities total_injuries total_total year
        }
        else {
            destring B-H, ignore("," "NA" " ") replace //characters in numbers
            egen total_fatal = rowtotal(B C)
            egen total_injury = rowtotal(D E)
            egen total_pdo = rowtotal(F G)
            ren H total_total
            keep county_name total_fatal total_injury total_pdo total_total year
        }
    }


    if year >= 1997  {
        if year >= 2007 {
            destring B-L, ignore("," "NA" " ") replace //characters in numbers
            ren L total_total
			gen total_unknown_severity = .
        }
        else {
            destring B-N, ignore("," "NA" " ") replace //characters in numbers
            ren N total_total
			egen total_unknown_severity = rowtotal(L M)
        }
		
        egen total_fatal = rowtotal(B C)
        egen total_major_injury = rowtotal(D E)
        egen total_minor_injury = rowtotal(F G)
		egen total_possible_injury = rowtotal(H I)
        egen total_pdo = rowtotal(J K)
		
        keep county_name total_fatal total_major_injury total_minor_injury total_possible_injury total_pdo total_unknown_severity total_total year
    }

    drop if missing(total_total)
    ds, has(type numeric)
	 
    foreach v in `r(varlist)' {
    replace `v' = 0 if `v'==.
    }

    tempfile newstata`s'
    save `newstata`s'', replace
}
 
import excel using "`file_name'" , describe
local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

local pct " ' · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |     、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
     replace county_name = subinstr(county_name, "`x'", "", .)
 }
 

drop if county_name == "Total"
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == ""
replace county_name = "total" if county_name == "statewide"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st ") == 1
replace county_name = "le flore" if county_name == "leflore"
duplicates drop county year, force

sort county_name year, stable
compress
tempfile total
save `total', replace

/*----------------------------------------------------*/
      /* [>   2.  Animal 00-10   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/OK/OK.AVC.00-10.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'" , describe
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') case(lower) clear
    gen year = `r(worksheet_`s')'

    drop in 1/2
    ren A county_name

    if year >= 2007 {
        destring B-L, ignore("," "NA" " ") replace //characters in numbers
        ren L animal_total
		gen animal_unknown_severity = .
    }
    else {
        destring B-N, ignore("," "NA" " ") replace //characters in numbers
        ren N animal_total
		egen animal_unknown_severity = rowtotal(L M)
    }

    egen animal_fatal = rowtotal(B C)
    egen animal_major_injury = rowtotal(D E)
    egen animal_minor_injury = rowtotal(F G)
	egen animal_possible_injury = rowtotal(H I)	
    egen animal_pdo = rowtotal(J K)

    keep county_name animal_fatal animal_major_injury animal_minor_injury animal_possible_injury animal_pdo animal_total animal_unknown_severity year

    drop if missing(animal_total)
    ds, has(type numeric)
    foreach v in `r(varlist)' {
    replace `v' = 0 if `v'==.
    }

    tempfile newstata`s'
    save `newstata`s'', replace
}

import excel using "`file_name'" , describe
local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

local pct " ' · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |     、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
     replace county_name = subinstr(county_name, "`x'", "", .)
 }
drop if county_name == "Total"
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == ""
replace county_name = "total" if county_name == "statewide"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st ") == 1
replace county_name = "le flore" if county_name == "leflore"

/* [> merge with total data <] */
*sort county_name ///
joinby county_name year using `ny_total', unmatched(both) ///
sorted by: county_name
merge 1:1 year county_name using `total'
br if _merge != 3
drop _merge
compress
order county_name year
compress
tempfile CSV
save `CSV', replace

/*----------------------------------------------------*/
      /* [>   3.  Deer 92-13   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/OK/OK.DeerCras.1992-2013.StateSeverity.CountyTotal.Evans.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_2)') cellrange(A2:W80) firstrow case(lower) clear

foreach v of varlist b-w {
  local lb_var : var label `v'
  rename `v' deer`lb_var'
}
 
*gather deer*, variable(year) value(deer_total)
*replace year =  substr(year,-4,.)
reshape long deer, i(county) j(year) string 
ren county county_name
ren deer deer_total
destring deer_total year, replace

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == ""
replace county_name = "total" if county_name == "statewide"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st ") == 1
replace county_name = "le flore" if county_name == "leflore"
drop if county_name==""

tempfile deer_by_county
save `deer_by_county', replace

*******************************
// import excel using "`file_name'", sheet(`r(worksheet_1)') cellrange(A3:AS11) firstrow case(lower) clear
//
// foreach v of varlist b-as {
//   local lb_var : var label `v'
//   rename `v' s_`lb_var'_`v'
// }
// drop in 1
// destring s*,replace
//
// replace injuryseverity = subinstr(injuryseverity,"-", "_",.)
// order injuryseverity
// levelsof injuryseverity, local(wordlist) clean
// xpose, clear varname
// ren _varname type
// ren (v*) (`wordlist')
// drop in 1
//
// gen county_name = "total"
// gen str12 year = substr(type, 3, 4) if ustrregexm(type, "([0-9])")==1
// replace year=year[_n-1] if year==""
//
// replace type= "crash" if ustrregexm(type, "([0-9])")==1
// replace type= "person" if type!= "crash"
//
// drop  Possible Unknown None
//
// reshape wide Fatal-Total, i(year) j(type) string
//
// drop  Totalperson
// ren Fatalcrash deer_fatal
// ren Incapacitatingcrash deer_major_injury
// ren Non_incapacitatingcrash deer_minor_injury
// ren Totalcrash deer_total
// ren Fatalperson deer_fatalities
// ren Incapacitatingperson deer_major_injuries
// ren Non_incapacitatingperson deer_minor_injuries
// destring year, replace
//
// tempfile statewide
// save `statewide', replace
// merge 1:1 county year using `deer_by_county', nogen
/*----------------------------------------------------*/
      /* [>   4.  Merge with CSV   <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `CSV', nogen

gen state_letter_code  = "OK" // add state abbreviation

assert deer_total>=0 ///
    & animal_total>=0 ///
	& animal_unknown_severity>=0 ///
    & animal_fatal>=0 ///
    & animal_major_injury>=0 ///
    & animal_minor_injury>=0 ///
	& animal_possible_injury>=0 ///
    & animal_pdo>=0 ///
    & total_major_injury>=0 ///
    & total_minor_injury>=0 ///
	& total_possible_injury>=0 ///
	& total_unknown_severity >=0 ///
    & total_fatal>=0 ///
    & total_injury>=0 ///
    & total_pdo>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_total>=0, fast // sanity check

/*----------------------------------------------------*/
      /* [>   5.  Merge with  state_county_identifiers  <] */
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
    fips year ///
    total_* ///
    animal_* ///
    deer_*

sort state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year, stable

/* [> imputation <] */
drop if county_name=="total"
//there's none and possible so sum-ups don't match with total crashes

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_OK_county_year_`T1'_`T2'.dta" ,replace
