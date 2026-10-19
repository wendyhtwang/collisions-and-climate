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

*************************IN (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 2015   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/IN/IN.TVC.15.CountySeverity.xlsx"
import excel using "`file_name'" , describe
import excel using "`file_name'", allstring sheet(`r(worksheet_1)') cellrange(`r(range_1)') firstrow case(lower) clear
gen year = `r(worksheet_1)'


rename indianacollisionsbyseverity county_name
rename totalcollisions total_total
rename fatal total_fatal
rename nonfatalinjury total_injury
rename propertydamageonly total_pdo

tempfile in_total
save `in_total', replace

/*----------------------------------------------------*/
      /* [>   2.  Total & deer 05-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataRAW/DVCs/IN/IN.Total&DeerCrashes.2005-2014.CountySeverity.Baker.xlsx"
import excel using "`file_name'" , describe
local Nminus = `r(N_worksheet)'-2

forvalues s =1/`r(N_worksheet)' {
    import excel using "`file_name'" , describe
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(:K95) firstrow case(lower) clear
    gen year = substr("`r(worksheet_`s')'",1,4)
    rename county county_name
    drop totalpossibleinjuriesreported collisionsresultinginpossible

    if mod(`s',2) == 0 {
        rename totalcollisions deer_total
        rename fatalitycollisions deer_fatal
        rename injurycollisions deer_injury
        rename propdamagecollisions deer_pdo
        rename totalinjuriesreported deer_injuries
        rename incapacitatinginjurycollisions deer_major_injury
        rename totalincapacitatinginjuriesre deer_major_injuries
        rename totalfatalitiesreported deer_fatalities

        local sminus = `s'-1
        merge 1:1 county_name year using `x_`sminus'', nogenerate

    }

    else if mod(`s',2) == 1 {
        rename totalcollisions total_total
        rename fatalitycollisions total_fatal
        rename injurycollisions total_injury
        rename propdamagecollisions total_pdo
        rename totalinjuriesreported total_injuries
        rename incapacitatinginjurycollisions total_major_injury
        rename totalincapacitatinginjuriesre total_major_injuries
        rename totalfatalitiesreported total_fatalities
    }


    drop if county_name == ""
    tempfile x_`s'
    save `x_`s'', replace
}

forvalues s = 2(2)`Nminus' {
    append using `x_`s'', force
}
 
destring year, replace
append using `in_total', force

gen state_letter_code  = "IN" // add state abbreviation
  
destring total_total ///
        total_fatal ///
        total_injury ///
        total_pdo ///
        total_fatalities ///
        total_injuries ///
        total_major_injury ///
        total_major_injuries ///
		deer_total ///
        deer_fatal ///
        deer_injury ///
        deer_major_injury ///
        deer_major_injuries ///
        deer_pdo ///
        deer_fatalities ///
        deer_injuries, ignore("," "NA" " ") replace

replace deer_total = 0 if deer_total == .		
		
assert total_fatal>=0 ///
    & total_fatalities>=0 ///
    & total_injury>=0 ///
    & total_injuries>=0 ///
    & total_major_injury>=0 ///
    & total_major_injuries>=0 ///
    & total_pdo>=0 ///
    & total_total>=0 ///
    & deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_major_injury>=0 ///
    & deer_major_injuries>=0 ///
    & deer_pdo>=0 ///
    & deer_fatalities>=0 ///
    & deer_injuries>=0, fast // sanity check
	
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1


/*----------------------------------------------------*/
      /* [>   3.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == "all counties" | county_name == "total"

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

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_IN_county_year_`T1'_`T2'.dta" ,replace
