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

*************************NV (all data were kept)
clear
local file_name = "$path/dataRAW/DVCs/NV/NV.Total&DeerCrash.1994-2013.CountySeverity.Hartley.xls"
import excel using "`file_name'" , describe

/*----------------------------------------------------*/
      /* [>   1.  Total 94-13   <] */
/*----------------------------------------------------*/
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

local i=-1
forvalues n = 3(21)192 {
    local nplus = `n'+18
    local ranges "A`n':G`nplus' I`n':O`nplus' "
    foreach n of local ranges  {
        import excel using "`file_name'",sheet("COUNTS") cellrange("`n'") firstrow case(lower) clear

        ren county county_name
        ren propertydamageonly total_pdo
        ren injurycrashes total_injury
        ren injuries total_injuries
        ren fatalcrashes total_fatal
        ren fatalities total_fatalities
        ren totals total_total

        local i=`i'+1
        di `i'

        gen year = 1994+`i'

        append using `fullfile'
        save `fullfile', replace
    }
}

drop if drop_me == 1
drop drop_me

tempfile total
save `total', replace
/*----------------------------------------------------*/
      /* [>   2.  Deer 94-13   <] */
/*----------------------------------------------------*/
clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

local i=-1
forvalues n = 3(21)192 {
    local nplus = `n'+18
    local ranges "A`n':G`nplus' I`n':O`nplus' "
    foreach n of local ranges  {
        import excel using "`file_name'",sheet("DEER COUNTS") cellrange("`n'") firstrow case(lower) clear

        ren county county_name
        ren propertydamageonly deer_pdo
        ren injurycrashes deer_injury
        ren injuries deer_injuries
        ren fatalcrashes deer_fatal
        ren fatalities deer_fatalities
        ren totals deer_total

        local i=`i'+1
        di `i'

        gen year = 1994+`i'

        append using `fullfile'
        save `fullfile', replace
    }
}

drop if drop_me == 1
drop drop_me

/*----------------------------------------------------*/
      /* [>   3.  Merge with total   <] */
/*----------------------------------------------------*/
merge 1:1 county_name year using `total', nogen

replace county_name ="total" if county_name=="0"
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1

gen state_letter_code  = "NV" // add state abbreviation

destring total_total ///
        total_fatal ///
        total_injury ///
        total_fatalities ///
        total_injuries ///
        total_pdo ///
        deer_fatalities ///
        deer_injuries ///
        deer_fatal ///
        deer_injury ///
        deer_pdo ///
        deer_total ///
        year, ignore("," "NA" " ") replace

assert total_total>=0 ///
    & total_fatal>=0 ///
    & total_injury>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_pdo>=0 ///
    & deer_fatalities>=0 ///
    & deer_injuries>=0 ///
    & deer_fatal>=0 ///
    & deer_injury>=0 ///
    & deer_pdo>=0 ///
    & deer_total>=0 , fast // sanity check

/*----------------------------------------------------*/
      /* [>   4. Merge with  state_county_identifiers <] */
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
save "$working_data/dvcs_NV_county_year_`T1'_`T2'.dta" ,replace
