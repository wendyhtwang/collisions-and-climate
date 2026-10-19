/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
05/23/2021 [Rukhshan Arif Mian]: commented out line 57. added line 58
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

*************************SD (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 97-17   <] */
/*----------------------------------------------------*/
clear
*local file_name = "$path/dataCSV/DVCs/SD/SC.TVC.97-17.CountySeverity.xlsx"
local file_name = "$path/dataCSV/DVCs/SD/SD.TVC.97-17.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    if year == 1997 | year == 1998 {
        rename reportedtrafficaccidentssouth motorvehicletrafficcrashesby
    }
    tempfile newstata`s'
    save `newstata`s'', replace
}

local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

rename motorvehicletrafficcrashesby county_name
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

duplicates list
duplicates drop
drop if county_name==""

local pct "  · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |  \   、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
      replace county_name = subinstr(county_name, "`x'", "", .)
 }

replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "mcpherson" if county_name == "mc pherson" | county_name == "m c pherson"
replace county_name = "hutchinson" if county_name == "hutch inson"
replace county_name = "jones" if county_name == "jon es"
replace county_name = "mccook" if county_name == "mc cook"
replace county_name = "mellette" if county_name == "me lle tte"
replace county_name = "pennington" if county_name == "penningto n"
replace county_name = "roberts" if county_name == "robert s"
replace county_name = "yankton" if county_name == "yank ton"
replace county_name = "ziebach" if county_name == "zie bach"
replace county_name = "oglala lakota" if county_name == "shannon"  //Shannon County: renamed Oglala Lakota County in 2015

sort county_name year, stable


foreach v of varlist total_total-total_injuries {
	list `v' if missing(real(`v'))
}

foreach x in total_total {
	replace `x' = strtrim(`x')
	replace `x' = ustrtrim(`x')
	replace `x' = subinstr(`x', ",", "", .)
	replace `x' = subinstr(`x', " ", "", .)
	replace `x' = subinstr(`x', "-", "", .)
}

* some non-numeric entries remains 
foreach v of varlist total_total-total_injuries {
	list `v' if missing(real(`v'))
}

destring total*, replace

tempfile sd_total
save `sd_total', replace
 
/*----------------------------------------------------*/
      /* [>   2.  Deer 97-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/SD/SD.DVC.97-14.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(A1:G68) firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    if year <=2003 {
        rename statewidewildanimalhits statewidewildanimalhitsbyco
    }

    if year ==2008 | year ==2011 | year ==2012 {
        rename pdq pdo
    }

    tempfile newstata`s'
    save `newstata`s'', replace
}

local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

drop countynumber

rename statewidewildanimalhitsbyco county_name
rename total deer_total
rename fatal deer_fatal
rename injury deer_injury
rename nok deer_fatalities
rename noi deer_injuries
rename pdo deer_pdo

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "state of ohio"
replace county_name = subinstr(county_name, " county", "", .)

drop if county_name==""

foreach v of varlist deer_total-deer_injuries {
	list `v' if missing(real(`v'))
}
 
foreach x in deer_injury deer_fatalities deer_injuries {
	replace `x' = strtrim(`x')
	replace `x' = ustrtrim(`x')
	replace `x' = subinstr(`x', ",", "", .)
	replace `x' = subinstr(`x', " ", "", .)
	replace `x' = subinstr(`x', "-", "", .)
	replace `x' = subinstr(`x', "D", "0", .)
}

local pct " ' · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |  \   、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
    foreach var in county_name deer_injury deer_fatalities {
        replace `var' = subinstr(`var', "`x'", "", .)
    }
 }

destring deer_injury deer_fatalities, replace

replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "mcpherson" if county_name == "mc pherson" | county_name == "m c pherson" | county_name == "hcpherson"
replace county_name = "hutchinson" if county_name == "hutch inson"
replace county_name = "jones" if county_name == "jon es"
replace county_name = "mccook" if county_name == "mc cook"
replace county_name = "mellette" if county_name == "me lle tte"
replace county_name = "pennington" if county_name == "penningto n"
replace county_name = "roberts" if county_name == "robert s"
replace county_name = "yankton" if county_name == "yank ton"
replace county_name = "ziebach" if county_name == "zie bach"
replace county_name = "marshall" if county_name == "mars hall"
replace county_name = "kingsbury" if county_name == "kingsbury "
replace county_name = "oglala lakota" if county_name == "shannon"  //Shannon County: renamed Oglala Lakota County in 2015

duplicates drop
duplicates list county_name year

sort county_name year, stable
merge 1:1 year county_name using `sd_total'
br if _merge != 3
sort county_name year
drop _merge


tempfile CSV
save `CSV', replace
/*----------------------------------------------------*/
      /* [>   3.  Wild animal 05-14   <] */
/*----------------------------------------------------*/
clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

forvalues n=2005/2014 {

    clear
    set excelxlsxlargefile on
    local file_name = "$path/dataRAW/DVCs/SD/SDARSFiles`n'/Accident`n'.txt"
    import delimited using "`file_name'", delimiter("|") varnames(1) case(lower) stringcols(_all) clear
	 
    keep countyname severity iswildanimalhitind

    ren countyname county_name

    egen total_fatal = total(severity=="Fatal"), by(county_name)  //total
    egen total_injury = total(severity=="Injury"), by(county_name)
    egen total_pdo = total(severity=="PDO"), by(county_name)
    bys county_name: gen total_total =_N // total_total

    egen wild_animal_fatal = total(severity =="Fatal" & iswildanimalhitind =="True" ), by(county_name) // wild_animal_fatal
    egen wild_animal_injury = total(severity =="Injury" & iswildanimalhitind =="True" ), by(county_name) // wild_animal_injury
    egen wild_animal_pdo = total(severity =="PDO" & iswildanimalhitind =="True" ), by(county_name) // wild_animal_pdo
    bys county_name: egen wild_animal_total =total(iswildanimalhitind =="True")
	
    drop severity iswildanimalhitind
    duplicates drop

    gen year =  substr("`file_name'",-8,4)

    /* save as a dta file create a local with the .xls extension and space removed */
    append using `fullfile', force
    save `fullfile', replace

}

drop if drop_me == 1
drop drop_me

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = strrtrim(county_name)


sort county_name year, stable
destring year, replace

tempfile wild_animal
save `wild_animal', replace

/*----------------------------------------------------*/
      /* [>   3.  Merge with CSV   <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `CSV', force
br if _merge != 3
drop _merge


destring total_total ///
        total_fatal ///
        total_injuries ///
        total_injury ///
        total_pdo ///
        total_fatalities ///
        deer_total ///
        deer_fatal ///
        deer_injury ///
        deer_fatalities ///
        deer_injuries ///
        deer_pdo ///
        wild_animal_fatal ///
        wild_animal_injury ///
        wild_animal_pdo ///
        wild_animal_total ///
        year, ignore("," "NA" " ") replace

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
    & wild_animal_fatal>=0 ///
    & wild_animal_injury>=0 ///
    & wild_animal_pdo>=0 ///
    & wild_animal_total>=0, fast // sanity check


gen state_letter_code  = "SD" // add state abbreviation


/*----------------------------------------------------*/
      /* [>   2.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == "" | county_name == "total " | county_name == "total"

order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year ///
    total_* ///
    wild_animal_* ///
    deer_*

sort state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year, stable

/* [> imputation <] */
foreach var of varlist deer_total-deer_fatalities  {
    replace `var'= 0 if `var'==. & year>=1997 & year<=2014
}

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_SD_county_year_`T1'_`T2'.dta" ,replace
