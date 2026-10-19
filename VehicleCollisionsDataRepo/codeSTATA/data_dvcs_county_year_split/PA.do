/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Siyue Ouyang
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
10/15/2020 [Owen Shao]: Data update in 2001 and 2019
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

*************************PA (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 85-98 15-18   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/PA/PA.TVC.15-18.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    tempfile newstata`s'
    save `newstata`s'', replace
}


local Nminus = `r(N_worksheet)'-1

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

drop g h population
replace totalcrashes = word(totalcrashes,1)

rename pennsylvaniacrashesbycounty county_name
rename totalcrashes total_total
rename fatalinjurycrashes total_fatal
rename injurycrashes total_injury
rename pdocrashes total_pdo

tempfile 15_18
save `15_18', replace

clear
local file_name = "$path/dataCSV/DVCs/PA/PA.TVC.85-98.CountySeverity.xlsx"
import excel using "`file_name'" , describe
local Nminus = `r(N_worksheet)'- 1

forvalues s = 1/`r(N_worksheet)' {
    clear
    local file_name = "$path/dataCSV/DVCs/PA/PA.TVC.85-98.CountySeverity.xlsx"
    import excel using "`file_name'" , describe
    local year `r(worksheet_`s')'
    if `year' < 1996 {
        import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(A1:E69) clear
        gen year = `year'
        drop in 1
        rename A county_name
        rename B total_fatal
        rename C total_injury
        rename D total_pdo
        rename E total_total
    }
    else {
        import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(A1:F69) clear
        gen year = `year'
        drop in 1
        drop B
        rename A county_name
        rename C total_fatal
        rename D total_injury
        rename E total_pdo
        rename F total_total
    }

    tempfile newstata`s'
    save `newstata`s'', replace
	
}

forvalue s = 1/`Nminus' {
    append using `newstata`s'', force
}

tempfile f
save `f', replace

foreach var of varlist total_fatal-total_total{
	list if missing(real(`var'))
}

foreach lname in total_fatal total_injury total_pdo total_total {
    replace `lname' = substr(`lname',1,strpos(`lname'," ")-1) if strpos(`lname'," ")!=0
    replace `lname' = substr(`lname',1,strpos(`lname',"(")-1) if strpos(`lname',"(")!=0
    replace `lname' = substr(`lname',1,strpos(`lname',"%")-1) if strpos(`lname',"%")!=0
    replace `lname' = subinstr(`lname',"S","5", .)
    replace `lname' = subinstr(`lname',"I","1", .)
    replace `lname' = subinstr(`lname',"l","1", .)
    replace `lname' = subinstr(`lname',"T","7", .)
    replace `lname' = subinstr(`lname',",","", .)
    replace `lname' = subinstr(`lname',".","", .)
    replace `lname' = subinstr(`lname',"·","", .)
    replace `lname' ="" if strpos(`lname',"Jun")!=0
}

append using `15_18', force

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "armstrong" if county_name == "annstrong"
replace county_name = "cumberland" if county_name == "cumberiand"
replace county_name = "fayette" if county_name == "fayene"
replace county_name = "fayette" if county_name == "fayetie"
replace county_name = "lehigh" if county_name == "lehi h"
replace county_name = "luzerne" if county_name == "luzeme"
replace county_name = "northumberland" if county_name == "northumberiand"
replace county_name = "sullivan" if county_name == "suluvan"
replace county_name = "venango" if county_name == "venago"
replace county_name = "westmoreland" if county_name == "westrnoreland"
replace county_name = "total" if county_name == "totals"

destring total*, ignore("," "NA" " " ".") replace

tempfile CSV
save `CSV', replace
 
/*----------------------------------------------------*/
      /* [>   2.  generate Total & Animal & Deer 1999-2018 (except for 2001)  <] */
/*----------------------------------------------------*/

*****************************county codes and names***************************
clear
local file_name = "$path/dataRAW/DVCs/PA/County_codes_PA.csv"
import delimited using "`file_name'", clear varnames(1) case(lower) stringcols(_all)

rename ïcounty_code county_code 
destring county_code, replace 

tempfile county_code
save `county_code', replace
 
*****************************other animal crashes***************************

clear
local file_name = "$path/dataRAW/DVCs/PA/log#22251 Hit Other Anmial Crashes.csv"
import delimited using "`file_name'", clear case(lower) stringcols(_all)

ren v1 crn
ren v2 year

destring crn year, replace

gen other_animal_related = 1

tempfile other_animal
save `other_animal', replace
 

************************crashhes 1999-2019***********************************
* start with 1999
foreach n of numlist 1999/2019 {
    clear
    set excelxlsxlargefile on
	gen year = `n'
    cd "$path/dataRAW/DVCs/PA/Statewide_`n'/"
    if `n' == 2001 | `n' == 2017 {
        local file_name = "CRASH_`n'.csv" 
	}
	else if `n' == 2018 {
		local file_name = "CRASH_V_`n'.csv"
	}
    else  {
        local file_name = "CRASH_`n'_Statewide.csv" 
    }
    
    import delimited using `file_name', clear varnames(1) case(lower) stringcols(_all)
	gen year = `n'
    keep crn fatal_count injury_count county year
	rename county county_code
    destring crn fatal_count injury_count county_code ,replace
	 
    tempfile f
    save `f', replace
 
    ************************deer related, pdo, fatal, injury******************
	clear 
    cd "$path/dataRAW/DVCs/PA/Statewide_`n'/"
    *local file_name : dir . files "FLAG*Statewide.csv"
    if `n' == 2001 | `n' == 2017 {
        local file_name = "FLAG_`n'.csv"
    }
	else if `n' == 2018{
		local file_name = "FLAG_V_`n'.csv"
	}
    else {
        local file_name = "FLAG_`n'_Statewide.csv"  
    }
	
    import delimited using `file_name', clear varnames(1) case(lower) stringcols(_all)
	gen year = `n'
	keep crn property_damage_only injury fatal deer_related year
	
    if inlist(property_damage_only,"Yes","No") == 1 {
		foreach x in property_damage_only injury fatal deer_related {
			gen `x'_1 = inlist(`x',"Yes")
            replace `x' =""
            destring `x', replace
            replace `x' = `x'_1
			drop `x'_1
        }
	}

	destring crn property_damage_only injury fatal deer_related year, replace 

    merge 1:1 crn using `f', nogen
    merge 1:1 crn year using "`other_animal'", keep(1 3) nogen
	
	merge m:1 county_code using `county_code' 
	drop _merge county_code
    save `f', replace	
	
 
    /* [> total crashes <] */
    egen total_fatal = total(fatal ==1 ), by(county year)
    egen total_injury = total(injury ==1 ), by(county year)
    egen total_pdo = total(property_damage_only ==1 ), by(county year)
    bys county year: gen total_total =_N // total_total


    egen deer_fatal = total(fatal ==1 & deer_related ==1), by(county year)
    egen deer_injury = total(injury ==1 & deer_related ==1), by(county year)
    egen deer_pdo = total(property_damage_only ==1 & deer_relate ==1), by(county year)
    egen deer_total = total(deer_related ==1), by(county year)


    egen animal_fatal = total(fatal ==1 & (deer_related ==1 | other_animal_related == 1)), by(county year)
    egen animal_injury = total(injury ==1 & (deer_related ==1 | other_animal_related == 1)), by(county year)
    egen animal_pdo = total(property_damage_only ==1 & (deer_related ==1 | other_animal_related == 1)), by(county year)
    egen animal_total = total(deer_related ==1 | other_animal_related == 1), by(county year)


    keep total_* animal_* deer_* county year
    drop deer_related
    duplicates drop

    tempfile crash
    save `crash', replace

    use `f', replace
    collapse (sum) fatal_count injury_count, by(county year)
    ren fatal_count total_fatalities
    ren injury_count total_injuries

    tempfile total_person
    save `total_person', replace

    use `f', replace
    collapse (sum) fatal_count injury_count if deer_related ==1, by(county)
    ren fatal_count deer_fatalities
    ren injury_count deer_injuries

    tempfile deer_person
    save `deer_person', replace

    use `f', replace
    collapse (sum) fatal_count injury_count if deer_related ==1 | other_animal_related == 1, by(county)
    ren fatal_count animal_fatalities
    ren injury_count animal_injuries

    tempfile animal_person
    save `animal_person', replace

    merge 1:1 county using `deer_person',nogen
    merge 1:1 county using `animal_person',nogen
    merge 1:1 county using `total_person',nogen
    merge 1:1 county using `crash', nogen

    tempfile `n'
    save ``n'', replace
}

foreach n of numlist 1999/2019 {
    clear
    use ``n'', replace
    save "$working_data/PA/dvcs_PA_county_year_`n'.dta" ,replace
}

 
/*----------------------------------------------------*/
      /* [>   3.  append files for 1999-2019   <] */
/*----------------------------------------------------*/
clear
use `1999', replace

foreach n of numlist 2000/2019 {
    append using ``n'', force
}

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "armstrong" if county_name == "annstrong"
replace county_name = "cumberland" if county_name == "cumberiand"
replace county_name = "fayette " if county_name == "fayene"
replace county_name = "fayette" if county_name == "fayetie"
replace county_name = "lehigh" if county_name == "lehi h"
replace county_name = "luzerne" if county_name == "luzeme"
replace county_name = "northumberland" if county_name == "northumberiand"
replace county_name = "sullivan" if county_name == "suluvan"
replace county_name = "venango" if county_name == "venago"
replace county_name = "westmoreland" if county_name == "westrnoreland"
replace county_name = "total" if county_name == "totals"
drop if county_name == ""


/*----------------------------------------------------*/
      /* [>   4.  Merge with CSV   <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `CSV'
br if _merge != 3
drop _merge

gen state_letter_code  = "PA" // add state abbreviation

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
    & animal_total>=0 ///
    & deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_pdo>=0 ///
    & deer_fatalities>=0 ///
    & deer_injuries>=0 ///
    & deer_total>=0 , fast // sanity check
/*----------------------------------------------------*/
      /* [>   5.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
drop _merge

drop if county_name == "" | county_name == "total" 

sort county_name year

order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips ///
	year ///
	total* animal* deer* 

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_PA_county_year_`T1'_`T2'.dta" ,replace
