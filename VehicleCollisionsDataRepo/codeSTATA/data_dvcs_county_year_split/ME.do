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

*************************ME (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 96-05   <] */
/*----------------------------------------------------*/
clear
global path_me "$path/dataCSV/DVCs/ME/"
cd "$path_me/"
local all_files : dir . files "ME.TVC*.xlsx"
display `all_files'

tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

foreach file in `all_files' {
    import excel using "`file'" , describe
    import excel using "`file'", allstring cellrange(:G97) firstrow case(lower) clear
	 
    ren mainehighwaycrashseverityby county_name
	replace county_name = lower(county_name)
	replace county_name = strtrim(county_name)
	replace county_name = ustrtrim(county_name)

    replace county_name= county_name[_n-1] if county_name==""
    replace injurytype = "total_total" if injurytype == "COUNTY SUBTOTAL"
	replace injurytype = "total_total" if injurytype == "COUNlY SUBTOTAL"
	replace injurytype = "total_total" if injurytype == "GRANDTOTAL"
	
	replace injurytype = "total_fatal" if injurytype == "FATAL (K)"
	replace injurytype = "total_fatal" if injurytype == "FATAL(K)"
	replace injurytype = "total_possible_injury" if injurytype == "FOSSIBLE INJURY (C)"
	replace injurytype = "total_possible_injury" if injurytype == "POSSIBLE INJURY (C}"
	replace injurytype = "total_possible_injury" if injurytype == "POSSIBLE INJURY (C)"
	replace injurytype = "total_major_injury" if injurytype == "INCAPACITATING (A)"
	replace injurytype = "total_minor_injury" if injurytype == "NON-INCAPACITATING (B)"
	replace injurytype = "total_minor_injury" if injurytype == "NON-INCAPACITATING(B)"
	replace injurytype = "total_pdo" if injurytype == "PROPERTY DAMAGE ONLY (PDO)"


    foreach v of varlist c -g {
      local lb_var : var label `v'
      rename `v' crashes`lb_var'
    }
	
	gen id = _n
	reshape long crashes, i(id) j(year)
	drop id
	reshape wide crashes, i(county_name year) j(injurytype) string
	renpfix crashes 

    append using `fullfile'
    save `fullfile', replace
}

sort county_name year 
drop if drop_me == 1
drop drop_me
drop if year == . 



// clean data
local pct "  · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |  \   、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
    foreach var in total_minor_injury total_pdo total_total {
        replace `var' = subinstr(`var', "`x'", "", .)
    }
 }

* check nonnumeric entries
list total_total if missing(real(total_total))
list total_major_injury if missing(real(total_major_injury))
list total_possible_injury if missing(real(total_possible_injury))
list total_minor_injury if missing(real(total_minor_injury))
list total_pdo if missing(real(total_pdo))
list total_fatal if missing(real(total_fatal))


foreach x in total_total  total_pdo {
	replace `x' = subinstr(`x', "43B", "438", .) //total_total 2002 piscataquis
	replace `x' = subinstr(`x', "·  262", "262", .) // ttal_possible_injury Oxford 1997
	replace `x' = strtrim(`x')
	replace `x' = ustrtrim(`x')
	replace `x' = subinstr(`x', ",", "", .)
	replace `x' = subinstr(`x', " ", "", .)
	replace `x' = subinstr(`x', "-", "", .)
}

destring total_fatal-total_total,  ignore("," "NA" " " "·  ") replace

tempfile total_96_05
save `total_96_05', replace
 
/*----------------------------------------------------*/
      /* [>   2.  Animal 96-98   <] */
/*----------------------------------------------------*/

clear
local file_name = "$path/dataCSV/DVCs/ME/ME.AVC.96-98.County.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_2)') cellrange(:K4) firstrow case(lower) clear

keep year deer deerfatalaccidents total totalfatalanimalaccidents
ren deer deer_total
ren deerfatalaccidents deer_fatal
ren total animal_total
ren totalfatalanimalaccidents animal_fatal

replace deer_fatal = "0" if deer_fatal == "o"

gen county_name = "total"
destring year-animal_fatal, replace

tempfile animal_96_98
save `animal_96_98', replace


//we only have total here, cause county level data don't specify year
/*----------------------------------------------------*/
      /* [>   3.  Animal & Deer 99-03   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/ME/ME.DVC.AVC.99-03.CountySeverity.xlsx"
import excel using "`file_name'" , describe
local Nminus = `r(N_worksheet)'-1

forvalues s =1/`r(N_worksheet)' {
    import excel using "`file_name'" , describe
	local type_animal = "`r(worksheet_`s')'"

    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(:F18) case(lower) clear

    drop in 1
	
    gen type_animal = "`type_animal'"
	tab type_animal
	
    ren A county_name
    local i= 1999
    foreach v of varlist B-F {
      rename `v' crashes`i'
      local i=`i'+1
    }

    tempfile newstata`s'
    save `newstata`s'', replace
}

forvalues s = 1/`Nminus' {
    append using `newstata`s'', force
}

drop if county_name == "TOTAL" 
replace county_name = "WASHINGTON" if county_name == "W HINGTON"
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name, ".","",.)
 
gen id = _n
reshape long crashes, i(id) j(year)
drop id

replace type_animal = "all_others" if type_animal == "ALL OTHER ANIMALS"
reshape wide crashes, i(county_name year) j(type_animal) string
renpfix crashes 

*check for non-numeric chars
foreach v of varlist BEAR-all_others{
	list `v' if missing(real(`v'))
}

foreach x in MOOSE {
	replace `x' = strtrim(`x')
	replace `x' = ustrtrim(`x')
	replace `x' = subinstr(`x', ",", "", .)
	replace `x' = subinstr(`x', " ", "", .)
	replace `x' = subinstr(`x', "-", "", .)
} 
 

destring BEAR-all_others, replace
egen animal_total = rowtotal(BEAR DEER MOOSE all_others)
ren DEER deer_total 
drop BEAR MOOSE all_others

append using `animal_96_98'
merge 1:1 county_name year using `total_96_05', nogen

replace county_name = "statewide" if county_name == "total"

tempfile CSV_96_05
save `CSV_96_05', replace
 
/*----------------------------------------------------*/
      /* [>   4.  Total 03-19   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/ME/Animal Crashes by Year-County-Severity Lvl.xlsx"

tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

local i=-1
forvalues n = 4(9)148 {
    local nplus = `n'+6
    import excel using "`file_name'", sheet("All") cellrange(A`n':R`nplus') firstrow case(lower) clear

    replace injurylevel = "total_major_injury" if injurylevel =="A"
    replace injurylevel = "total_minor_injury" if injurylevel =="B"
    replace injurylevel = "total_possible_injury" if injurylevel =="C"
    replace injurylevel = "total_fatal" if injurylevel =="K"
    replace injurylevel = "total_pdo" if injurylevel =="PD"
    replace injurylevel = "total_total" if injurylevel =="Grand Total"
    rename grandtotal statewide
	 
    sort injurylevel
    levelsof injurylevel, local(wordlist) clean
    xpose, clear varname
	
    ren _varname county_name
    ren (v*) (`wordlist')
    drop in 1
	
    local i=`i'+1
    gen year = 2003+`i'

    append using `fullfile'
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

tempfile total
save `total', replace

/*----------------------------------------------------*/
      /* [>   5.  Wild animal & Deer 03-19   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/ME/Animal Crashes by Year-County-Severity Lvl.xlsx"

tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

local i=-1
local ranges "A4:S24 A27:S46 A49:S68 A71:S89 A92:S112 A115:S132 A135:S154 A157:S177 A180:S200 A203:S223 A226:S243 A246:S266 A269:S289 A292:S311 A314:S332 A335:S354 A357:S376"
foreach n of local ranges  {
    import excel using "`file_name'", sheet("Animal") cellrange("`n'") firstrow case(lower) clear

    if "`n'"=="A4:S24" {
        local typeofcrash "typeofcrash"
    }
    else {
        local typeofcrash "typeofcrashdescr"
    }

    replace `typeofcrash'=`typeofcrash'[_n-1] if `typeofcrash'==""
    keep if `typeofcrash' =="Deer"
    drop `typeofcrash'

    rename grandtotal statewide
    replace injurylevel = "deer_major_injury" if injurylevel =="A"
    replace injurylevel = "deer_minor_injury" if injurylevel =="B"
	replace injurylevel = "deer_possible_injury" if injurylevel =="C"
    replace injurylevel = "deer_fatal" if injurylevel =="K"
    replace injurylevel = "deer_pdo" if injurylevel =="PD"
    tempfile f
    save "`f'", replace
	 
    import excel using "`file_name'", sheet("Animal") cellrange("`n'") firstrow case(lower) clear
    replace `typeofcrash'=`typeofcrash'[_n-1] if `typeofcrash'==""

    rename grandtotal statewide
    replace injurylevel = "animal_total" if `typeofcrash' =="Grand Total" 
    collapse (sum) androscoggin-statewide, by(injurylevel)
    append using "`f'"

    replace injurylevel = "animal_major_injury" if injurylevel =="A"
    replace injurylevel = "animal_minor_injury" if injurylevel =="B"
	replace injurylevel = "animal_possible_injury" if injurylevel == "C"
    replace injurylevel = "animal_fatal" if injurylevel =="K"
    replace injurylevel = "animal_pdo" if injurylevel =="PD"

    tempfile t
    save "`t'", replace

    sort injurylevel
    levelsof injurylevel, local(wordlist) clean 
    xpose, clear varname
    ren _varname county_name
    ren (v*) (`wordlist')

    drop in 1

    local i=`i'+1

    gen year = 2003+`i' 
    append using `fullfile'
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

tempfile wild_animal_deer
save `wild_animal_deer', replace

/*----------------------------------------------------*/
      /* [>   6.  Merge Together   <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `total', nogen

tempfile 03_19
save `03_19', replace

merge 1:1 county_name year using `CSV_96_05', update //96-05
br if _merge != 3
drop _merge

sort county_name year, stable

gen state_letter_code  = "ME" // add state abbreviation

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "totals"
replace county_name = subinstr(county_name, " co.", "", .)

destring animal_total ///
        animal_fatal ///
        animal_major_injury ///
        animal_minor_injury ///
		animal_possible_injury ///
        animal_pdo ///
        year, ignore("," "NA" " ") replace

gen deer_injury = deer_major_injury + deer_minor_injury + deer_possible_injury
gen animal_injury = animal_major_injury + animal_minor_injury +animal_possible_injury
gen total_injury = total_major_injury + total_minor_injury + total_possible_injury
	
	
assert total_fatal>=0 ///
    & total_major_injury>=0 ///
    & total_minor_injury>=0 ///
	& total_possible_injury >=0 ///
	& total_injury >= 0 ///
    & total_pdo>=0 ///
    & total_total>=0 ///
    & deer_fatal>=0 ///
    & deer_major_injury>=0 ///
    & deer_major_injury>=0 ///
	& deer_possible_injury >= 0 ///
	& deer_injury >=0 ///
    & deer_pdo>=0 ///
    & deer_total>=0 ///
    & animal_total>=0 ///
    & animal_fatal>=0 ///
    & animal_major_injury>=0 ///
    & animal_minor_injury>=0 ///
	& animal_possible_injury >=0 ///
	& animal_injury >=0 ///
    & animal_pdo>=0 , fast // sanity check

/*----------------------------------------------------*/
      /* [>   7.  Merge with state_county_identifiers  <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == "statewide"

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
    fips year ///
    total_* ///
    animal_* ///
    deer_* , stable

/* [> imputation <] */
foreach var of varlist animal_major_injury-deer_total  {
    replace `var'= 0 if `var'==. & year>=2003 & year<=2019
}

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_ME_county_year_`T1'_`T2'.dta" ,replace
