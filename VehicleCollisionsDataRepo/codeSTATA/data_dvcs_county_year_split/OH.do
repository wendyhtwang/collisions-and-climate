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

*************************OH (all data were kept, except for unknown crashes in total data)
/*----------------------------------------------------*/
      /* [>   1.  Total 01-15   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/OH/OH.TVC.01-15.Web.xlsx"
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

drop population unknowncrashes

rename county county_name
rename fatalcrashes total_fatal
rename deaths total_fatalities
rename injuries total_injuries
rename injurycrashes total_injury
rename pdocrashes total_pdo
rename totalcrashes total_total

destring total_total ///
        total_fatal ///
        total_injuries ///
        total_injury ///
        total_pdo ///
        total_fatalities ///
        year, ignore("," "NA" " ") replace

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = subinstr(county_name, " county", "", .)


duplicates drop
drop if county_name==""

sort county_name year, stable

tempfile total
save `total', replace

/*----------------------------------------------------*/
      /* [>   2.  Deer 01-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/OH/OH.DVC.01-14.CountyMonth.Web.xlsx"
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


keep county total year
rename county county_name
rename total deer_total


replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "state of ohio"
replace county_name = subinstr(county_name, " county", "", .)

duplicates drop
drop if county_name==""

destring deer_total ///
        year, ignore("," "NA" " ") replace

sort county_name year, stable

tempfile deer
save `deer', replace

/*----------------------------------------------------*/
      /* [>   3.  Total 94-00   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/OH/OH.TVC.94-00.CountySeverity.xlsx"
import excel using "`file_name'" , describe

tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

forvalue s = 1/`r(N_worksheet)' {
    import excel using "`file_name'" , describe
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    append using `fullfile'
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me
keep countyname totalcrashes fatalcrashes injurycrashes pdocrashes unknowncrashes deaths injuries year

rename countyname county_name
rename fatalcrashes total_fatal
rename deaths total_fatalities
rename injuries total_injuries
rename injurycrashes total_injury
rename pdocrashes total_pdo
rename unknowncrashes total_unknown_severity 
rename totalcrashes total_total

destring total_total ///
        total_fatal ///
        total_injuries ///
        total_injury ///
        total_pdo ///
		total_unknown_severity ///
        total_fatalities ///
        year, ignore("," "NA" " ") replace

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "state of ohio"
replace county_name = subinstr(county_name, " county", "", .)
drop if county_name ==""
replace county_name = "wyandot" if county_name == "w yandot"

sort county_name year, stable
append using `total', force
merge 1:1 year county_name using `deer'
drop _merge

tempfile 94_15
save `94_15', replace

/*----------------------------------------------------*/
      /* [>   4.  Total 86-93   <] */
/*----------------------------------------------------*/
clear
global path_ohc "$path/dataCSV/DVCs/OH/"
cd "$path_ohc/"
local all_files : dir . files "OH.TVC.19*.xlsx"
display `all_files'

tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

local i = 1986
foreach file in `all_files' {
    import excel using "`file'" , describe
    import excel using "`file'", allstring cellrange(:E90) case(lower) clear
    gen year = `i'  /* create variable suffix that will be added to crash data*/
    local i = `i' + 1

    drop in 1
    ren A county_name
    ren B total_total
    ren C total_fatal
    ren D total_injury
    ren E total_pdo
    append using `fullfile'
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me

//browse if missing(real(total_fatal))
destring total_total ///
        total_fatal ///
        total_injury ///
        total_pdo ///
        year, ignore("," "NA" " " "-" "") replace

local pct "  · ~ ～ ! ！ @ @ # # $ ￥ % % ^ ……  & & * × ( ) （ ） - - _  ——  =  = +  +  [ ] 『 』 { } 【 】  |  \   、 ; ； : ： , ， < > 《 》 . 。 / ? ？ ‘  ’  “  ” "
foreach x of local pct {
      replace county_name = subinstr(county_name, "`x'", "", .)
 }

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "state total"
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "tuscarawas" if county_name == "tuscaraw as"
replace county_name = "auglaize" if county_name == "auglalze"
replace county_name = "harrison" if county_name == "harris"
replace county_name = "shelby" if county_name == "ihelby"
replace county_name = "stark" if county_name == "'hark"

append using `94_15', force

tempfile CSV_86_15
save `CSV_86_15', replace

/*----------------------------------------------------*/
      /* [>   5.  Total & Animal & Year 10-19   <] */
/*----------------------------------------------------*/
clear
global path_oh "$path/dataRAW/DVCs/OH/"
cd "$path_oh/"
local all_files : dir . files "Crashes*.xlsx"
display `all_files'

tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace


foreach file in `all_files' {
  import excel using "`file'" , describe
  forvalue s = 1/`r(N_worksheet)' {
  	  import excel using "`file'", describe
      import excel using "`file'", allstring sheet(`"`r(worksheet_`s')'"') cellrange(`"`r(range_`s')'"') firstrow case(lower) clear
      local type `"`r(worksheet_`s')'"'
      gen year = substr("`file'", 9, 4)  
      keep county fatal seriousinjurysuspected minorinjurysuspected injurypossible propertydamageonly total fatalities injuries year
	   
      ren county county_name
      ren fatal t`s'_fatal
      ren seriousinjurysuspected t`s'_major_injury
      ren minorinjurysuspected t`s'_minor_injury
	  ren injurypossible t`s'_possible_injury
      ren propertydamageonly t`s'_pdo
      ren total t`s'_total
      ren fatalities t`s'_fatalities
      ren injuries t`s'_injuries 	

      if `s' == 1 {
          append using `fullfile', force
      }
      else {
          merge 1:1 county_name year using `fullfile', nogen
      }
      save `fullfile', replace

  }
}

drop if drop_me == 1
drop drop_me

destring t* year, replace 
rename t1* total*
rename t2* animal*
rename t3* deer*

// imputation
gen total_injury = total_major_injury + total_minor_injury + total_possible
gen animal_injury = animal_major_injury + animal_minor_injury + animal_possible
gen deer_injury = deer_major_injury + deer_minor_injury + deer_possible



replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "state of ohio"
replace county_name = subinstr(county_name, " county", "", .)
replace county_name = "wyandot" if county_name == "w yandot"
drop if county_name ==""

/*----------------------------------------------------*/
      /* [>   6.  Merge with CSV_86_15  <] */
/*----------------------------------------------------*/
sort county_name year, stable
merge 1:1 year county_name using `CSV_86_15', update 
drop _merge

assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_pdo>=0 ///
    & total_fatalities>=0 ///
    & total_injuries>=0 ///
    & total_total>=0 ///
    & deer_total>=0 , fast // sanity check


drop if year == 2020
drop if county_name == "total"

/*----------------------------------------------------*/
      /* [>   7.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
gen state_letter_code  = "OH" // add state abbreviation
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

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_OH_county_year_`T1'_`T2'.dta" ,replace
