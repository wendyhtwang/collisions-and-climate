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

*************************IL (all data except for "A-Injury Crashes" were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 12-18   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/IL/IL.TVC.12-18.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalues s =1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(`r(range_`s')') firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    tempfile newstata`s'
    save `newstata`s'', replace
}


clear
import excel using "`file_name'" , describe
forvalues s = 1/`r(N_worksheet)' {
    append using `newstata`s'', force
}

rename countymotorvehiclecrashstati county_name
rename injurycrashes total_injury
rename fatalcrashes total_fatal
rename crashes total_total

drop ainjurycrashes

destring total_total ///
        total_fatal ///
        total_injury ///
        year, ignore("," "NA" " ") replace

assert total_fatal>=0 ///
    & total_injury>=0 ///
    & total_total>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "vermilion" if county_name == "vermillion"
replace county_name = "rock island" if county_name == "rockisland"
replace county_name = "iroquois" if county_name == "iroqouis"
replace county_name = "dekalb" if county_name == "de kalb"
replace county_name = "dewitt" if county_name == "de witt"
replace county_name = "dupage" if county_name == "du page"
replace county_name = "jodaviess" if county_name == "jo daviess"
replace county_name = "lasalle" if county_name == "la salle"
replace county_name = "mcdonough" if county_name == "mc donough"
replace county_name = "mchenry" if county_name == "mc henry"
replace county_name = "mclean" if county_name == "mc lean"

tempfile CSV
save `CSV', replace

/*----------------------------------------------------*/
      /* [>   2.  Total & Animal 09-18   <] */
/*----------------------------------------------------*/
/* [> county_name file <] */
clear
local file_name = "$path/dataRAW/DVCs/IL/crash_records_level/CountyCode.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

// replace A = subinstr(A," ","", .) if strpos(A,"ST.") == 0
// gen county_code = real(regexs(1)) if regexm(A ,"([0-9]+)")
// generate county_name = substr(A, strpos(A,".") + 1,.)
// drop A

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)
replace county_name = "total" if county_name == "totals"
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "vermilion" if county_name == "vermillion"
replace county_name = "rock island" if county_name == "rockisland"
replace county_name = "iroquois" if county_name == "iroqouis"
replace county_name = "dekalb" if county_name == "de kalb"
replace county_name = "dewitt" if county_name == "de witt"
replace county_name = "dupage" if county_name == "du page"
replace county_name = "jodaviess" if county_name == "jo daviess"
replace county_name = "lasalle" if county_name == "la salle"
replace county_name = "mcdonough" if county_name == "mc donough"
replace county_name = "mchenry" if county_name == "mc henry"
replace county_name = "mclean" if county_name == "mc lean"


sort county_code

tempfile match_countyname
save `match_countyname', replace

/* [> record level data <] */
clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

forvalues n=2009/2018 {
    local file_name = "$path/dataRAW/DVCs/IL/crash_records_level/IllinoisCrashDataExtracts`n'/CrashExtract.txt"
	
    import delimited using "`file_name'", varnames(nonames) case(lower) colrange(:20) stringcols(_all) bindquote(strict) maxquotedrows(99999999) clear
    keep v3 v4 v13 v14 v15 v20
    ren v3 county_code
    ren v4 year
    ren v13 collision_type
    ren v14 killed
    ren v15 injured
    ren v20 severity

    append using `fullfile', force
    save `fullfile', replace
}

drop if drop_me == 1
drop drop_me
replace year = "20"+year

foreach v of varlist county_code - injured {
	list `v' if missing(real(`v'))
}

foreach x of varlist county_code - injured {
	drop if missing(real(`x'))
}

destring county_code year killed injured, replace
drop if county_code==. | county_code==0
 
merge m:1 county_code using `match_countyname', nogen
drop county_code

tempfile f
save `f', replace

egen total_fatal = total(severity=="Fatal"), by(county year)  //total
egen total_injury = total(severity=="Injury"), by(county year)
egen total_pdo = total(severity=="Property Damage"), by(county year)
bys county year: gen total_total =_N // total_total

egen animal_fatal = total(severity=="Fatal" & collision_type=="4"), by(county year) // animal
egen animal_injury = total(severity=="Injury" & collision_type=="4"), by(county year)
egen animal_pdo = total(severity=="Property Damage" & collision_type=="4"), by(county year)
bys county year: egen animal_total =total(collision_type=="4")

drop collision_type severity killed injured
duplicates drop
duplicates report county year
tempfile crash
save `crash', replace

use `f', replace
collapse (sum) killed injured, by(county year)
ren killed total_fatalities
ren injured total_injuries
tempfile total_person
save `total_person', replace

use `f', replace
collapse (sum) killed injured if collision_type =="4", by(county year)
ren killed animal_fatalities
ren injured animal_injuries

merge 1:1 county year using `total_person', nogen
merge 1:1 county year using `crash', nogen

replace county_name = "total" if county_name == "totals" 
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "vermilion" if county_name == "vermillion"
replace county_name = "rock island" if county_name == "rockisland"
replace county_name = "iroquois" if county_name == "iroqouis"
replace county_name = "dekalb" if county_name == "de kalb"
replace county_name = "dewitt" if county_name == "de witt"
replace county_name = "dupage" if county_name == "du page"
replace county_name = "jodaviess" if county_name == "jo daviess"
replace county_name = "lasalle" if county_name == "la salle"
replace county_name = "mcdonough" if county_name == "mc donough"
replace county_name = "mchenry" if county_name == "mc henry"
replace county_name = "mclean" if county_name == "mc lean"


sort county year, stable
tempfile 09_18
save `09_18', replace
/*----------------------------------------------------*/
      /* [>   2.  Total & Animal 04-08   <] */
/*----------------------------------------------------*/
clear
tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

forvalues n=2004/2008 {
    clear
    global path_il "$path/dataRAW/DVCs/IL/scrape_siyue/Year `n'"
    cd "$path_il/"
    local all_files : dir . files "*.xlsx"
    display `all_files'

    foreach file in `all_files' {

        import excel using "`file'", allstring clear
        gen county_year = subinstr("`file'", ".xlsx", "", .)
        replace county_year = lower(county_year)
        replace county_year = strtrim(county_year)
        replace county_year = ustrtrim(county_year)

        if strpos(county_year,"rock ") == 1 {
            gen county_name = "rock island"
        }

        else if strpos(county_year,"jo ") == 1 {
            gen county_name = "jodaviess"
        }

        else if strpos(county_year,"st ") == 1 | strpos(county_year,"st. ") == 1 {
            gen county_name = "st. clair"
        }

        else {
            gen county_name = word(county_year, 1)
        }

        gen year = substr(county_year,-4,.)

        replace county_name = lower(county_name)
        replace county_name = strtrim(county_name)
        replace county_name = ustrtrim(county_name)
        replace county_name = "total" if county_name == "totals"
        replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
        replace county_name = "vermilion" if county_name == "vermillion"
        replace county_name = "rock island" if county_name == "rockisland"
        replace county_name = "iroquois" if county_name == "iroqouis"
		replace county_name = "dekalb" if county_name == "de kalb"
		replace county_name = "dewitt" if county_name == "de witt"
		replace county_name = "dupage" if county_name == "du page"
		replace county_name = "jodaviess" if county_name == "jo daviess"
		replace county_name = "lasalle" if county_name == "la salle"
		replace county_name = "mcdonough" if county_name == "mc donough"
		replace county_name = "mchenry" if county_name == "mc henry"
		replace county_name = "mclean" if county_name == "mc lean"

        replace A = lower(A)
        replace A = strtrim(A)
        replace A = ustrtrim(A)

        keep if A == "animal" | A == "totals"
        duplicates drop
        append using `fullfile', force
        save `fullfile', replace
    }
}

drop if drop_me == 1
drop drop_me

tempfile f
save `f', replace

keep A B C D E G H county_name year
keep if A == "animal"
drop A
ren B animal_total
ren C animal_fatal
ren D animal_injury
ren E animal_pdo
ren G animal_fatalities
ren H animal_injuries
duplicates drop
tempfile animal
save `animal', replace

use `f', replace
keep A B C D E G H county_name year
keep if A == "totals"
drop A
ren B total_total
ren C total_fatal
ren D total_injury
ren E total_pdo
ren G total_fatalities
ren H total_injuries
duplicates drop
merge 1:1 county year using `animal', nogen

destring animal_total ///
        animal_fatal ///
        animal_injuries ///
        animal_injury ///
        animal_pdo ///
        animal_fatalities ///
        total_total ///
        total_fatal ///
        total_injuries ///
        total_injury ///
        total_pdo ///
        total_fatalities ///
        year, ignore("," "NA" " ") replace

tempfile 04_08
save `04_08', replace
use `04_08', replace

append using `09_18', force

merge 1:1 county_name year using `CSV'
br if _merge != 3
drop _merge


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


replace county_name = "dekalb" if county_name == "de kalb"
replace county_name = "dewitt" if county_name == "de witt"
replace county_name = "dupage" if county_name == "du page"
replace county_name = "rock island" if county_name == "rockisland"
replace county_name = "jodaviess" if county_name == "jo daviess"
replace county_name = "lasalle" if county_name == "la salle"
replace county_name = "mcdonough" if county_name == "mc donough"
replace county_name = "mchenry" if county_name == "mc henry"
replace county_name = "mclean" if county_name == "mc lean"

 
* creating a balanced dataset
fillin year county_name
drop _fillin
/*----------------------------------------------------*/
      /* [>   3.  Merge with state_county_identifiers   <] */
/*----------------------------------------------------*/
gen state_letter_code  = "IL" // add state abbreviation 
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

drop if county_name == "" | county_name == "totals"

order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year

/* [> imputation <] */
replace animal_fatalities = 0 if animal_fatal == 0 & animal_fatalities ==.
replace animal_injuries = 0 if animal_injury == 0 & animal_injuries ==.
replace animal_total = animal_fatal+animal_injury+animal_pdo if animal_total ==.
replace total_total = total_fatal+total_injury+total_pdo if total_total ==.

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_IL_county_year_`T1'_`T2'.dta" ,replace
