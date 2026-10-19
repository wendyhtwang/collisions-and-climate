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

*************************MD (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 04-13   <] */
/*----------------------------------------------------*/
/* [> total_total <] */
clear
local file_name = "$path/dataRAW/DVCs/MD/ARCHIVE/StatewideBR-13July25-14.xls"
import excel using "`file_name'" , describe
import excel using "`file_name'", sheet(`r(worksheet_3)') cellrange(B8:L33) firstrow case(lower) clear

foreach v of varlist c-l {
  local lb_var : var label `v'
  rename `v' total`lb_var'
}


gen id = _n
reshape long total, i(id) j(year) 
drop id

rename county county_name
rename total total_total
replace county_name="statewide" if county_name=="Total  Crashes"

tempfile total_total
save `total_total', replace


/* [> total_injury <] */
clear
import excel using "`file_name'" , describe
import excel using "`file_name'", sheet(`r(worksheet_3)') cellrange(B36:L61) firstrow case(lower) clear

foreach v of varlist c-l {
  local lb_var : var label `v'
  rename `v' total`lb_var'
}

gen id = _n
reshape long total, i(id) j(year) 
drop id

rename county county_name
rename total total_injury 
replace county_name="statewide" if county_name=="Injury  Crashes"

tempfile total_injury
save `total_injury', replace


/* [> total_fatal <] */
clear
import excel using "`file_name'" , describe
import excel using "`file_name'", sheet(`r(worksheet_3)') cellrange(B64:L89) firstrow case(lower) clear

foreach v of varlist c-l {
  local lb_var : var label `v'
  rename `v' total`lb_var'
}

gen id = _n
reshape long total, i(id) j(year) 
drop id
rename total total_fatal 
 
rename county county_name
replace county_name="statewide" if county_name=="Fatal  Crashes"

tempfile total_fatal
save `total_fatal', replace

merge 1:1 county_name year using `total_injury', nogenerate
merge 1:1 county_name year using `total_total', nogenerate

tempfile total
save `total', replace 

/*----------------------------------------------------*/
      /* [>   2.  Animal 04-13   <] */
/*----------------------------------------------------*/
/* [> animal_total <] */
clear
local file_name = "$path/dataRAW/DVCs/MD/ARCHIVE/AnimalBR-13July28-14.xls"
import excel using "`file_name'" , describe
import excel using "`file_name'", sheet(`r(worksheet_3)') cellrange(B8:L33) firstrow case(lower) clear

foreach v of varlist c-l {
  local lb_var : var label `v'
  rename `v' total`lb_var'
}

gen id = _n
reshape long total, i(id) j(year) 
drop id
rename total animal_total

rename county county_name
replace county_name="statewide" if county_name=="Total  Crashes"

tempfile animal_total
save `animal_total', replace


/* [> animal_injury <] */
clear
import excel using "`file_name'" , describe
import excel using "`file_name'", sheet(`r(worksheet_3)') cellrange(B36:L61) firstrow case(lower) clear

foreach v of varlist c-l {
  local lb_var : var label `v'
  rename `v' total`lb_var'
}

gen id = _n
reshape long total, i(id) j(year) 
drop id
rename total animal_injury 

rename county county_name
replace county_name="statewide" if county_name=="Injury  Crashes"

tempfile animal_injury
save `animal_injury', replace


/* [> animal_fatal <] */
clear
import excel using "`file_name'" , describe
import excel using "`file_name'", sheet(`r(worksheet_3)') cellrange(B64:L89) firstrow case(lower) clear

foreach v of varlist c-l {
  local lb_var : var label `v'
  rename `v' total`lb_var'
}

gen id = _n
reshape long total, i(id) j(year) 
drop id
rename total animal_fatal

rename county county_name
replace county_name="statewide" if county_name=="Fatal  Crashes"

tempfile animal_fatal
save `animal_fatal', replace

merge 1:1 county_name year using `animal_injury', nogenerate
merge 1:1 county_name year using `animal_total', nogenerate

tempfile animal
save `animal', replace

merge 1:1 county year using `total'
br if _merge != 3
drop _merge

local pct " ' · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |     、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
     replace county_name = subinstr(county_name, "`x'", "", .)
 }

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st ") == 1
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""
replace county_name = "anne arundel" if county_name == "anne  arundel" | county_name == "annearundel"
replace county_name = "baltimore" if county_name == "baltoco"
replace county_name = "baltimore city" if county_name == "baltimore  city" | county_name == "baltocity"
replace county_name = "prince george's" if county_name == "prgeorge" | county_name == "prince  georges"
replace county_name = "queen anne's" if county_name == "queenanne" | county_name == "queen  annes"
replace county_name = "st. mary's" if county_name == "stmary" | county_name == "st.  marys"

// destring year, replace

tempfile CSV
save `CSV', replace
/*----------------------------------------------------*/
      /* [>   2.  Total & Animal 10-19   <] */
/*----------------------------------------------------*/
clear
global path_md "$path/dataRAW/DVCs/MD/2019_County_All_Crashes/"
cd "$path_md/"
local all_files : dir . files "*.xls"
display `all_files'


tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace


foreach file in `all_files' {
    import excel using "`file'", allstring cellrange(B8:L22) firstrow case(lower) clear
    gen county_name =  substr("`file'",1,strpos("`file'","-")-1)

    replace category = "total_fatal" if category == "Fatal  Crashes"
    replace category = "total_fatalities" if category == "Total of All Fatalities"
    replace category = "total_injury" if category == "Injury  Crashes"
    replace category = "total_injuries" if category == "Total Number  Injured"
    replace category = "total_pdo" if category == "Property  Damage  Only Crashes"
    replace category = "total_total" if category == "Total  Crashes"

    drop if strpos(category,"_")==0

    /* save as a dta file create a local with the .xls extension and space removed */
    append using `fullfile'
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

foreach v of varlist c-l {
  local lb_var : var label `v'
  rename `v' crashes`lb_var'
}

gen id = _n
reshape long crashes, i(id) j(year)
drop id 
reshape wide crashes, i(county_name year) j(category) string
renpfix crashes 

sort county year, stable


local pct " ' · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |     、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
     replace county_name = subinstr(county_name, "`x'", "", .)
 }

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st ") == 1
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "anne arundel" if county_name == "anne  arundel" | county_name == "annearundel" | county_name == "annear"
replace county_name = "baltimore" if county_name == "baltoco"
replace county_name = "baltimore city" if county_name == "baltimore  city" | county_name == "baltocity"
replace county_name = "dorchester" if county_name == "dorc"
replace county_name = "frederick" if county_name == "fred"
replace county_name = "montgomery" if county_name == "montg"
replace county_name = "prince george's" if county_name == "prgeorge" | county_name == "prince  georges" | county_name == "prgeo"
replace county_name = "queen anne's" if county_name == "queenanne" | county_name == "queen  annes" |county_name ==  "qanne"
replace county_name = "somerset" if county_name == "somer"
replace county_name = "washington" if county_name == "wash"
replace county_name = "wicomico" if county_name == "wicom"
replace county_name = "worcester" if county_name == "worc"
replace county_name = "st. mary's" if county_name == "stmary" | county_name == "st.  marys"

tempfile total_10_19
save `total_10_19', replace

************************
clear
global path_md "$path/dataRAW/DVCs/MD/2019_County_Animal_Crashes/"
cd "$path_md/"
local all_files : dir . files "*.xls"
display `all_files'

tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

foreach file in `all_files' {
    import excel using "`file'", allstring cellrange(B8:L22) firstrow case(lower) clear

	di "`file'"
	
    gen county_name =  substr("`file'",1,strpos("`file'","animal")-1)
	tab county_name
	
    replace category = "animal_fatal" if category == "Fatal  Crashes"
    replace category = "animal_fatalities" if category == "Total of All Fatalities"
    replace category = "animal_injury" if category == "Injury  Crashes"
    replace category = "animal_injuries" if category == "Total Number  Injured"
    replace category = "animal_pdo" if category == "Property  Damage  Only Crashes"
    replace category = "animal_total" if category == "Total  Crashes"

    drop if strpos(category,"_")==0

    /* save as a dta file create a local with the .xls extension and space removed */
    append using `fullfile'
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

foreach v of varlist c-l {
  local lb_var : var label `v'
  rename `v' crashes`lb_var'
}

gen id = _n
reshape long crashes, i(id) j(year)
drop id 
reshape wide crashes, i(county_name year) j(category) string
renpfix crashes 

sort county year, stable


local pct " ' · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |     、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
     replace county_name = subinstr(county_name, "`x'", "", .)
 }
 
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st ") == 1
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "anne arundel" if county_name == "anne  arundel" | county_name == "annearundel" | county_name == "annear"
replace county_name = "baltimore" if county_name == "baltoco"
replace county_name = "baltimore city" if county_name == "baltimore  city" | county_name == "baltocity"
replace county_name = "dorchester" if county_name == "dorc"
replace county_name = "frederick" if county_name == "fred"
replace county_name = "montgomery" if county_name == "montg"
replace county_name = "prince george's" if county_name == "prgeorge" | county_name == "prince  georges" | county_name == "prgeo"
replace county_name = "queen anne's" if county_name == "queenanne" | county_name == "queen  annes" |county_name ==  "qanne"
replace county_name = "somerset" if county_name == "somer"
replace county_name = "washington" if county_name == "wash"
replace county_name = "wicomico" if county_name == "wicom"
replace county_name = "worcester" if county_name == "worc"
replace county_name = "st. mary's" if county_name == "stmary" | county_name == "st.  marys"

tempfile animal_10_19
save `animal_10_19', replace
 
 
* merge total andd animal 2010-19 
merge 1:1 county_name year using `total_10_19', nogenerate

destring animal_total animal_fatal animal_injury animal_pdo animal_fatalities animal_injuries total_total total_fatal total_injury total_pdo total_injuries total_fatalities, replace 

tempfile RAW
save `RAW', replace
/*----------------------------------------------------*/
      /* [>   4.  Merge with CSV   <] */
/*----------------------------------------------------*/
merge 1:1 county year using `CSV', update
br if _merge != 3
drop _merge

gen state_letter_code  = "MD" // add state abbreviation

assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_pdo>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_pdo>=0 ///
    & animal_fatalities>=0 ///
    & animal_injuries>=0 ///
    & animal_total>=0 , fast // sanity check
	
/*----------------------------------------------------*/
      /* [>   5.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == ""
drop if county_name == "statewide"

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

/* [> imputation <] */
replace total_pdo = total_total-(total_fatal+total_injury) if total_pdo ==. & year>=2004 & year<=2009
gen imputation_flag_total_pdo = 1
replace animal_pdo = animal_total-(animal_fatal+animal_injury) if animal_pdo ==. & year>=2004 & year<=2009
gen imputation_flag_animal_pdo = 1

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_MD_county_year_`T1'_`T2'.dta" ,replace
