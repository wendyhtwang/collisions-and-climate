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

*************************GA (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 05-15   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/GA/GA.TVC.05-15.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalues s =1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    tempfile newstata`s'
    save `newstata`s'', replace
}


local Nminus = `r(N_worksheet)'-1
forvalues s = 1/`Nminus' {
    append using `newstata`s'', force
}

rename collisionsbycounty county_name
rename totalinjurycollisions total_injury
rename numberinjured total_injuries
rename totalfatalcollisions total_fatal
rename numberkilled total_fatalities
rename totalpropertydamage total_pdo
rename totalcollisions total_total
drop if county_name ==""

gen state_letter_code  = "GA" // add state abbreviation

destring total_total ///
        total_fatal ///
        total_injury ///
        total_pdo ///
        total_fatalities ///
        total_injuries ///
        year, ignore("," "NA" " ") replace

assert total_fatal>=0 ///
    & total_fatalities>=0 ///
    & total_injury>=0 ///
    & total_injuries>=0 ///
    & total_pdo>=0 ///
    & total_total>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "new castle" if county_name == "newcastle"

tempfile ga_total
save `ga_total', replace

/*----------------------------------------------------*/
      /* [>   2.  Deer 05-15   <] */
/*----------------------------------------------------*/
/* [> generate 05-15 <] */
**********************
clear
local file_name = "$path/dataRAW/DVCs/GA/GA.DeerCrash.2005-2015.CountySeverity.Hammack.xlsx"
import excel using "`file_name'", allstring cellrange(A6:B161) firstrow case(lower) clear
gen year = 2005
tempfile 05_total
save `05_total', replace

clear
import excel using "`file_name'", allstring cellrange(D6:F132) firstrow case(lower) clear
gen year = 2005
tempfile 05_injury
save `05_injury', replace

clear
import excel using "`file_name'", allstring cellrange(H6:J10) firstrow case(lower) clear
gen year = 2005

merge 1:1 county using `05_total'
br if _merge !=3
drop _merge
merge 1:1 county using `05_injury'
br if _merge !=3
drop _merge

tempfile 5
save `5', replace

**********************
clear
local file_name = "$path/dataRAW/DVCs/GA/GA.DeerCrash.2005-2015.CountySeverity.Hammack.xlsx"
import excel using "`file_name'", allstring cellrange(L6:M163) firstrow case(lower) clear
gen year = 2006
tempfile 06_total
save `06_total', replace

clear
import excel using "`file_name'", allstring cellrange(O6:Q128) firstrow case(lower) clear
gen year = 2006
tempfile 06_injury
save `06_injury', replace

clear
import excel using "`file_name'", allstring cellrange(S6:U11) firstrow case(lower) clear
gen year = 2006

merge 1:1 county using `06_total'
br if _merge !=3
drop _merge
merge 1:1 county using `06_injury'
br if _merge !=3
drop _merge

tempfile 6
save `6', replace

**********************
clear
local file_name = "$path/dataRAW/DVCs/GA/GA.DeerCrash.2005-2015.CountySeverity.Hammack.xlsx"
import excel using "`file_name'", allstring cellrange(W6:X163) firstrow case(lower) clear
gen year = 2007
tempfile 07_total
save `07_total', replace

clear
import excel using "`file_name'", allstring cellrange(Z6:AB134) firstrow case(lower) clear
gen year = 2007
tempfile 07_injury
save `07_injury', replace

clear
import excel using "`file_name'", allstring cellrange(AD6:AF12) firstrow case(lower) clear
gen year = 2007

merge 1:1 county using `07_total'
br if _merge !=3
drop _merge
merge 1:1 county using `07_injury'
br if _merge !=3
drop _merge

tempfile 7
save `7', replace

**********************
clear
local file_name = "$path/dataRAW/DVCs/GA/GA.DeerCrash.2005-2015.CountySeverity.Hammack.xlsx"
import excel using "`file_name'", allstring cellrange(AH6:AI165) firstrow case(lower) clear
gen year = 2008
tempfile 08_total
save `08_total', replace

clear
import excel using "`file_name'", allstring cellrange(AK6:AM136) firstrow case(lower) clear
gen year = 2008
tempfile 08_injury
save `08_injury', replace

clear
import excel using "`file_name'", allstring cellrange(AO6:AQ12) firstrow case(lower) clear
gen year = 2008

merge 1:1 county using `08_total'
br if _merge !=3
drop _merge
merge 1:1 county using `08_injury'
br if _merge !=3
drop _merge

tempfile 8
save `8', replace

**********************
clear
local file_name = "$path/dataRAW/DVCs/GA/GA.DeerCrash.2005-2015.CountySeverity.Hammack.xlsx"
import excel using "`file_name'", allstring cellrange(AS6:AT163) firstrow case(lower) clear
gen year = 2009
tempfile 09_total
save `09_total', replace

clear
import excel using "`file_name'", allstring cellrange(AV6:AX133) firstrow case(lower) clear
gen year = 2009
tempfile 09_injury
save `09_injury', replace

clear
import excel using "`file_name'", allstring cellrange(AZ6:BB10) firstrow case(lower) clear
gen year = 2009

merge 1:1 county using `09_total'
br if _merge !=3
drop _merge
merge 1:1 county using `09_injury'
br if _merge !=3
drop _merge

tempfile 9
save `9', replace

**********************
clear
local file_name = "$path/dataRAW/DVCs/GA/GA.DeerCrash.2005-2015.CountySeverity.Hammack.xlsx"
import excel using "`file_name'", allstring cellrange(BD6:BE143) firstrow case(lower) clear
gen year = 2010
tempfile 10_total
save `10_total', replace

clear
import excel using "`file_name'", allstring cellrange(BG6:BI100) firstrow case(lower) clear
gen year = 2010
tempfile 10_injury
save `10_injury', replace

clear
import excel using "`file_name'", allstring cellrange(BK6:BM8) firstrow case(lower) clear
gen year = 2010

merge 1:1 county using `10_total'
br if _merge !=3
drop _merge
merge 1:1 county using `10_injury'
br if _merge !=3
drop _merge

tempfile 10
save `10', replace

**********************
clear
local file_name = "$path/dataRAW/DVCs/GA/GA.DeerCrash.2005-2015.CountySeverity.Hammack.xlsx"
import excel using "`file_name'", allstring cellrange(BO6:BP127) firstrow case(lower) clear
gen year = 2011
tempfile 11_total
save `11_total', replace

clear
import excel using "`file_name'", allstring cellrange(BR6:BT78) firstrow case(lower) clear
gen year = 2011
tempfile 11_injury
save `11_injury', replace

clear
import excel using "`file_name'", allstring cellrange(BV6:BX7) firstrow case(lower) clear
gen year = 2011

merge 1:1 county using `11_total'
br if _merge !=3
drop _merge
merge 1:1 county using `11_injury'
br if _merge !=3
drop _merge

tempfile 11
save `11', replace


**********************
clear
local file_name = "$path/dataRAW/DVCs/GA/GA.DeerCrash.2005-2015.CountySeverity.Hammack.xlsx"
import excel using "`file_name'", allstring cellrange(BZ6:CA126) firstrow case(lower) clear
gen year = 2012
tempfile 12_total
save `12_total', replace

clear
import excel using "`file_name'", allstring cellrange(CC6:CE71) firstrow case(lower) clear
gen year = 2012
tempfile 12_injury
save `12_injury', replace

clear
import excel using "`file_name'", allstring cellrange(CG6:CI7) firstrow case(lower) clear
gen year = 2012

merge 1:1 county using `12_total'
br if _merge !=3
drop _merge
merge 1:1 county using `12_injury'
br if _merge !=3
drop _merge

tempfile 12
save `12', replace

**********************
clear
local file_name = "$path/dataRAW/DVCs/GA/GA.DeerCrash.2005-2015.CountySeverity.Hammack.xlsx"
import excel using "`file_name'", allstring cellrange(CK6:CL128) firstrow case(lower) clear
gen year = 2013
tempfile 13_total
save `13_total', replace

clear
import excel using "`file_name'", allstring cellrange(CN6:CP73) firstrow case(lower) clear
gen year = 2013
tempfile 13_injury
save `13_injury', replace

clear
import excel using "`file_name'", allstring cellrange(CR6:CT9) firstrow case(lower) clear
gen year = 2013

merge 1:1 county using `13_total'
br if _merge !=3
drop _merge
merge 1:1 county using `13_injury'
br if _merge !=3
drop _merge

tempfile 13
save `13', replace

**********************
clear
local file_name = "$path/dataRAW/DVCs/GA/GA.DeerCrash.2005-2015.CountySeverity.Hammack.xlsx"
import excel using "`file_name'", allstring cellrange(CV6:CW126) firstrow case(lower) clear
gen year = 2014
tempfile 14_total
save `14_total', replace

clear
import excel using "`file_name'", allstring cellrange(CY6:DA76) firstrow case(lower) clear
gen year = 2014
tempfile 14_injury
save `14_injury', replace

clear
import excel using "`file_name'", allstring cellrange(DC6:DE10) firstrow case(lower) clear
gen year = 2014

merge 1:1 county using `14_total'
br if _merge !=3
drop _merge
merge 1:1 county using `14_injury'
br if _merge !=3
drop _merge

tempfile 14
save `14', replace

**********************
clear
local file_name = "$path/dataRAW/DVCs/GA/GA.DeerCrash.2005-2015.CountySeverity.Hammack.xlsx"
import excel using "`file_name'", allstring cellrange(DG6:DH102) firstrow case(lower) clear
gen year = 2015
tempfile 15_total
save `15_total', replace

clear
import excel using "`file_name'", allstring cellrange(DJ6:DL46) firstrow case(lower) clear
gen year = 2015
tempfile 15_injury
save `15_injury', replace

clear
import excel using "`file_name'", allstring cellrange(DN6:DP8) firstrow case(lower) clear
gen year = 2015

merge 1:1 county using `15_total'
br if _merge !=3
drop _merge
merge 1:1 county using `15_injury'
br if _merge !=3
drop _merge

tempfile 15
save `15', replace



/* [> append 05-15 <] */
forvalues n = 5/14 {
    append using ``n''
}

rename county county_name
rename injurycollisions deer_injury
rename numberofinjuries deer_injuries
rename fatalitycollisions deer_fatal
rename numberoffatalities deer_fatalities
rename totaldeercollisions deer_total

gen state_letter_code  = "GA" // add state abbreviation

destring deer_total ///
        deer_fatal ///
        deer_injury ///
        deer_fatalities ///
        deer_injuries ///
        year, ignore("," "NA" " ") replace

assert deer_fatal>=0 ///
    & deer_fatalities>=0 ///
    & deer_injury>=0 ///
    & deer_injuries>=0 ///
    & deer_total>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "new castle" if county_name == "newcastle"
duplicates drop

/*----------------------------------------------------*/
      /* [>   3.    Merge with  total 05-15   <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `ga_total'
br if _merge !=3
drop _merge


/*----------------------------------------------------*/
      /* [>   4.  Merge with  state_county_identifiers  <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name ==""
drop if county_name == "total" | county_name == "totals" | county_name == "no deer fatalities 2011" 

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
save "$working_data/dvcs_GA_county_year_`T1'_`T2'.dta" ,replace
