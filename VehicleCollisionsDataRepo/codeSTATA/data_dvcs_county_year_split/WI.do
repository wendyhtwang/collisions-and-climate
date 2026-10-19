/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
07/26/2020 [Siyue Ouyang]: add data in ~dataRaw, update
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

*************************WI******************************


/*----------------------------------------------------*/
      /* [>  Total & Deer 1988   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/WI/County - Lyden DOT/WI.Total&DeerCrash.1988-2013.CountySeverity.Lyden.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", sheet(`r(worksheet_1)') cellrange(A5:W78) firstrow case(lower) clear
keep a r-injured

gen year = 1988

ren a county_name
ren r total_fatal
ren s total_injury
ren t total_pdo
ren u total_total
ren killed total_fatalities
ren injured total_injuries

tempfile total_88
save `total_88', replace

clear
local file_name = "$path/dataRAW/DVCs/WI/County - Lyden DOT/WI.Total&DeerCrash.1988-2013.CountySeverity.Lyden.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", sheet(`r(worksheet_2)') cellrange(A5:W78) firstrow case(lower) clear
keep a r-injured

gen year = 1988

ren a county_name
ren r deer_fatal
ren s deer_injury
ren t deer_pdo
ren u deer_total
ren killed deer_fatalities
ren injured deer_injuries

merge 1:1 county using `total_88', nogen
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""
drop if county_name=="total"

tempfile 88
save `88', replace
 
/*----------------------------------------------------*/
      /* [>   Total & Animal & Deer 1989-2019   <](updated the code to include NEW VERSION data) */
/*----------------------------------------------------*/

/* 1989-1994 */
clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

forvalues n = 89/94 {
	clear 
	set excelxlsxlargefile on 
	local file_name = "$path/dataRAW/DVCs/WI/Record - Lange TOPs/NEW_VERSION - WDOT/1989-1994/`n'crash.csv"
	import delimited using "`file_name'", stringcols(_all) clear 
	 
	keep accddate cntycode accdtype accdsvr totfatl totinj 
	
	gen year = substr(accddate,-2,.)
	replace year = "19" + year
	drop accddate

	ren cntycode county_name
    destring totfatl totinj year, replace
	
	egen total_fatal = total(accdsvr=="FATAL"), by(county_name year) 
    egen total_injury = total(accdsvr=="INJURY"), by(county_name year)
    egen total_pdo = total(accdsvr=="PROPERTY DAMAGE"), by(county_name year)
    bys county year: egen total_fatalities=total(totfatl) // total_fatalities
    bys county year: egen total_injuries =total(totinj) // total_injuries
    bys county_name year: gen total_total = _N // total_total

    egen animal_fatal = total(accdsvr=="FATAL" & (accdtype=="DEER" | accdtype=="OTHER ANIMAL") ), by(county_name) // animal
    egen animal_injury = total(accdsvr=="INJURY" & (accdtype=="DEER" | accdtype=="OTHER ANIMAL") ), by(county_name) // animal
    egen animal_pdo = total(accdsvr=="PROPERTY DAMAGE" & (accdtype=="DEER" | accdtype=="OTHER ANIMAL") ), by(county_name) // animal
    egen animal_fatalities = total(totfatl*(accdtype=="DEER" | accdtype=="OTHER ANIMAL") ), by(county_name) // animal
    egen animal_injuries = total(totinj*(accdtype=="DEER" | accdtype=="OTHER ANIMAL") ), by(county_name) // animal
    bys county_name: egen animal_total = total(accdtype=="DEER" | accdtype=="OTHER ANIMAL")

    egen deer_fatal = total(accdsvr=="FATAL" & (accdtype=="DEER" ) ), by(county_name) // deer
    egen deer_injury = total(accdsvr=="INJURY" & (accdtype=="DEER" ) ), by(county_name) // deer
    egen deer_pdo = total(accdsvr=="PROPERTY DAMAGE" & (accdtype=="DEER" ) ), by(county_name) // deer
    egen deer_fatalities = total(totfatl*(accdtype=="DEER" ) ), by(county_name) // deer
    egen deer_injuries = total(totinj*(accdtype=="DEER" ) ), by(county_name) // deer
    bys county_name: egen deer_total =total(accdtype=="DEER" )
 
    drop accdtype accdsvr totfatl totinj
    duplicates drop
	drop if county_name==""
	if year == 1989 {
		drop if year== 1988
	}
	if year == 1991 {
		drop if year== 1990
	}
	if year == 1993 {
		drop if year== 1992
	}
	
    append using `fullfile', force
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""
drop if year == 1988 | year == 1995 

tempfile 89_94
save `89_94', replace
  
/* 2017-2019 */
/* for AVCs, use crshtype ==  Domesticated Animal - Alive, Domesticated Animal - Dead , Non Domesticated Animal (Alive) , Non Domesticated Animal (Dead)  */ 
clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

forvalues n = 17/20 {
	clear 
	set excelxlsxlargefile on 
	local file_name = "$path/dataRAW/DVCs/WI/Record - Lange TOPs/NEW_VERSION - WDOT/2017-2020/`n'crash.csv"
	import delimited using "`file_name'", stringcols(_all) clear 
	  
	keep crshdate totfatl totinj anmlty01 cntyname crshtype crshsvr
	
	gen year = substr(crshdate,-4,.)
	drop crshdate

	ren cntyname county_name
	ren crshsvr severity
    destring totfatl totinj year, replace
	
	gen animal_dummy = inlist(crshtype, "Domesticated Animal - Alive" "Domesticated Animal - Dead", "Non Domesticated Animal (Alive)", " Non Domesticated Animal (Dead)")
	gen wild_animal_dummy = inlist(crshtype, "Non Domesticated Animal (Alive)", " Non Domesticated Animal (Dead)")
	
	egen total_fatal = total(severity=="Fatal"), by(county_name year)  //total
    egen total_injury = total(severity=="Injury"), by(county_name year)
    egen total_pdo = total(severity	=="Property Damage"), by(county_name year)
    bys county year: egen total_fatalities=total(totfatl) // total_fatalities
    bys county year: egen total_injuries =total(totinj) // total_injuries
    bys county_name year: gen total_total = _N // total_total
	
    egen animal_fatal = total(severity =="Fatal" &  animal_dummy ==1 ), by(county year) // animal_fatal
	egen animal_injury = total(severity =="Injury" &  animal_dummy ==1 ), by(county year) // animal_injury
	egen animal_pdo = total(severity =="Property Damage" & animal_dummy ==1 ), by(county year) // animal_pdo
	egen animal_fatalities = total(totfatl*(animal_dummy ==1)), by(county year) // animal_fatalities
	egen animal_injuries = total(totinj*(animal_dummy ==1)), by(county year) // animal_injuries
	bys county year: egen animal_total =total(animal_dummy ==1)

	egen wild_animal_fatal = total(severity =="Fatal" &  wild_animal_dummy ==1 ), by(county year) // wild_animal_fatal
	egen wild_animal_injury = total(severity =="Injury" &  wild_animal_dummy ==1 ), by(county year) // wild_animal_injury
	egen wild_animal_pdo = total(severity =="Property Damage" & wild_animal_dummy ==1 ), by(county year) // wild_animal_pdo
	egen wild_animal_fatalities = total(totfatl*(wild_animal_dummy ==1)), by(county year) // wild_animal_fatalities
	egen wild_animal_injuries = total(totinj*(wild_animal_dummy ==1)), by(county year) // wild_animal_injuries
	bys county year: egen wild_animal_total =total( wild_animal_dummy ==1)

	egen deer_fatal = total(severity =="Fatal" & anmlty01=="Deer"), by(county year) // deer_fatal
	egen deer_injury = total(severity =="Injury" & anmlty01=="Deer"), by(county year) // deer_injury
	egen deer_pdo = total(severity =="Property Damage" & anmlty01=="Deer"), by(county year) // deer_pdo
	egen deer_fatalities = total(totfatl*(anmlty01=="Deer")), by(county year) // deer_fatalities
	egen deer_injuries = total(totinj*(anmlty01=="Deer")), by(county year) // deer_injuries
	bys county year: egen deer_total =total(anmlty01=="Deer" ) //deer_total
 
    drop crshtype severity totfatl totinj anmlty01 animal_dummy wild_animal_dummy
    duplicates drop

    drop if county_name==""

    append using `fullfile', force
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""
drop if year == 2020 

append using `89_94', force

tempfile 89_94_17_19
save `89_94_17_19', replace
 

/*1995-2016*/
clear
local file_name = "$path/dataRAW/DVCs/WI/Record - Lange TOPs/NEW_VERSION - WDOT/95_16crash.csv"
import delimited using "`file_name'", stringcols(_all) 
 
keep crshdate cntycode totinj totfatl crshtype crshsvr

gen year = substr(crshdate, 1, 4)
drop crshdate

ren cntycode county_name
ren crshsvr severity
destring totfatl totinj year, replace
gen animal_dummy = inlist(crshtype, "DEER", "OTHER ANIMAL")

egen total_fatal = total(severity =="Fatal"), by(county year) // total_fatal
egen total_injury = total(severity =="Injury"), by(county year) // total_injury
egen total_pdo = total(severity =="Property Damage"), by(county year) // total_pdo
bys county year: egen total_fatalities= total(totfatl) // total_fatalities
bys county year: egen total_injuries =total(totinj) // total_injuries
bys county year: gen total_total =_N // total_total

egen animal_fatal = total(severity =="Fatal" &  animal_dummy ==1 ), by(county year) // animal_fatal
egen animal_injury = total(severity =="Injury" &  animal_dummy ==1 ), by(county year) // animal_injury
egen animal_pdo = total(severity =="Property Damage" & animal_dummy ==1 ), by(county year) // animal_pdo
egen animal_fatalities = total(totfatl*(animal_dummy ==1)), by(county year) // animal_fatalities
egen animal_injuries = total(totinj*(animal_dummy ==1)), by(county year) // animal_injuries
bys county year: egen animal_total =total( animal_dummy ==1)

egen deer_fatal = total(severity =="Fatal" & crshtype=="DEER"), by(county year) // deer_fatal
egen deer_injury = total(severity =="Injury" & crshtype=="DEER"), by(county year) // deer_injury
egen deer_pdo = total(severity =="Property Damage" & crshtype=="DEER"), by(county year) // deer_pdo
egen deer_fatalities = total(totfatl*(crshtype=="DEER")), by(county year) // deer_fatalities
egen deer_injuries = total(totinj*(crshtype=="DEER")), by(county year) // deer_injuries
bys county year: egen deer_total =total(crshtype=="DEER" ) 

drop severity crshtype totinj totfatl animal_dummy
duplicates drop
duplicates list county year

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "total:"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name==""

append using `89_94_17_19', force

tempfile 89_19
save `89_19', replace
 

/*----------------------------------------------------*/
      /* [>   3.  Merge   <] */
/*----------------------------------------------------*/
append using `88', force 

gen state_letter_code  = "WI" // add state abbreviation

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
    & wild_animal_fatalities>=0 ///
    & wild_animal_injuries>=0 ///
    & wild_animal_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_pdo>=0 ///
    & animal_fatalities>=0 ///
    & animal_injuries>=0 ///
    & animal_total>=0, fast // sanity check


/*----------------------------------------------------*/
      /* [>   4.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == ""

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
save "$working_data/dvcs_WI_county_year_`T1'_`T2'.dta" ,replace
