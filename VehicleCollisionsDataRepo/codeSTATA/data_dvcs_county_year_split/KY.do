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

*************************KY (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 89-18   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/KY/KY.TVC.89-18.CountySeverity.xlsx"
import excel using "`file_name'" , describe


forvalues s =1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(A1:G122) firstrow case(lower) clear
    gen year = `r(worksheet_`s')'

    tempfile newstata`s'
    save `newstata`s'', replace
}

clear
import excel using "`file_name'" , describe
forvalues s = 1/`r(N_worksheet)' {
    append using `newstata`s'', force
}

rename accidentsbycounty county_name
rename nonfatalinjuryaccidents total_injury
rename fatalaccidents total_fatal
rename totalaccidents total_total
rename prodamageaccidents total_pdo
rename personskilled total_fatalities
rename personsinjured total_injuries

foreach v of varlist total_total-total_injuries {
	list `v' if missing(real(`v'))
}


foreach x in total_total total_fatal total_fatalities total_injuries total_injury total_pdo {
	replace `x' = subinstr(`x', "429-", "428", .) // Boyle 1993 total_injuries
	replace `x' = subinstr(`x', "?A", "28", .) // Carlisle 1992 total_pdo
	replace `x' = subinstr(`x', "1.20,", "1207", .) // Graves 1990 total_total
	replace `x' = subinstr(`x', "14S", "148", .) // Henry 1990 total_injury
	replace `x' = subinstr(`x', "B", "8", .) // Carroll 1989 total_fatalities
	replace `x' = subinstr(`x', "Q", "0", .) // Elliott 1989 total_fatalities
	replace `x' = subinstr(`x', "1,02B", "1028", .) // Campbell 1989 total_injuries
	replace `x' = strtrim(`x')
	replace `x' = ustrtrim(`x')
	replace `x' = subinstr(`x', ",", "", .)
	replace `x' = subinstr(`x', " ", "", .)
	replace `x' = subinstr(`x', "-", "", .)
}

replace total_fatalities = "1" if county_name == "NICHOLAS" & year == 1989 // was blank


destring total_total ///
        total_fatal ///
        total_injury ///
        total_pdo ///
        total_fatalities ///
        total_injuries ///
        year, ignore("," "NA" " " ",pa" "-" "Feb" "/" "HJ" "i:;;") replace

assert total_fatal>=0 ///
    & total_fatalities>=0 ///
    & total_injury>=0 ///
    & total_injuries>=0 ///
    & total_pdo>=0 ///
    & total_total>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = subinstr(county_name,";","", .)
replace county_name = subinstr(county_name," ","", .) if strpos(county_name,"st") != 1
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
replace county_name = "bullitt" if county_name == "bulit"
replace county_name = "ballard" if county_name == "balard"
replace county_name = "barren" if county_name == "baren"
replace county_name = "bell" if county_name == "bel"
replace county_name = "breathitt" if county_name == "breathit"
replace county_name = "calloway" if county_name == "caloway"
replace county_name = "carroll" if county_name == "caroll"
replace county_name = "carroll" if county_name == "carrol"
replace county_name = "crittenden" if county_name == "critenden"
replace county_name = "cumberland" if county_name == "lumoerland"
replace county_name = "estill" if county_name == "estil"
replace county_name = "fayette" if county_name == "fayete"
replace county_name = "gallatin" if county_name == "galatin"
replace county_name = "garrard" if county_name == "garard"
replace county_name = "harrison" if county_name == "harison"
replace county_name = "jefferson" if county_name == "jeferson" | county_name =="jeﬀerson"
replace county_name = "magoffin" if county_name == "magoftin" | county_name =="magoﬃn"
replace county_name = "metcalfe" if county_name == "metacalfe"
replace county_name = "pendleton" if county_name == "pendlton"
replace county_name = "perry" if county_name == "pery"
replace county_name = "powell" if county_name == "powel"
replace county_name = "russell" if county_name == "russel"
replace county_name = "scott" if county_name == "scot"
replace county_name = "warren" if county_name == "waren"
replace county_name = "washington" if county_name == "wasington"
replace county_name = "whitley" if county_name == "whitely"

tempfile ky_total
save `ky_total', replace


/*----------------------------------------------------*/
      /* [>   Generate county names   <] */
/*----------------------------------------------------*/


clear
local file_name = "$path/dataCSV/DVCs/KY/KY_County_codes.xlsx"
import excel using "`file_name'", allstring firstrow cellrange(A1:B121) case(lower) clear 

destring county_code, replace

tempfile county_names
save `county_names', replace

/*----------------------------------------------------*/
      /* [>   2.  05-19   <]*/
/*----------------------------------------------------*/

/* [> loop thru all the files in the folder <] */
clear
global path_ky "$path/dataRAW/DVCs/KY/"
cd "$path_ky/"
local all_files : dir . files "KY*.TXT"
display `all_files'

tempfile fullfile
set obs 1
gen drop_me = 1
save `fullfile', replace

foreach file in `all_files' {
	import delimited using "`file'", stringcols(_all) clear 
    gen year =  substr("`file'",4,4) 
    destring year, replace 
   
    if year >= 2016 {
 
   	keep county numberkilled numberinjured diranalysiscode year
 	ren numberkilled killed 
 	ren numberinjured injured
 	ren diranalysiscode type
	}
   else {
   	keep countyname killed injured year directionalanalysis year
 	ren countyname county_code
 	ren directionalanalysis type
   }

   /* save as a dta file create a local with the .xls extension and space removed */
   append using `fullfile'
   save `fullfile', replace
   }

drop if drop_me == 1
drop drop_me

destring county_code, replace  
merge m:1 county_code using `county_names', nogenerate 

replace county_name = county if county_name == ""
replace county_name = lower(county_name)
drop county county_code 
destring killed injured, replace 
gen is_animal = 1 if strpos(type, "ANIMAL")
keep if is_animal == 1

/*
we get total from the above dataset
*/
// egen total_fatal = total(killed != 0), by(county_name year)
// egen total_injury = total(injured != 0), by(county_name year)
// egen total_total = count(type), by(county_name year)
// egen total_fatalities = total(killed), by(county_name year)
// egen total_injuries = total(injured), by(county_name year)
// gen total_pdo = total_total - total_fatal - total_injury

egen animal_fatal = total(killed != 0), by(county_name year)
egen animal_injury = total(injured != 0), by(county_name year)
egen animal_total = count(type), by(county_name year)
egen animal_fatalities = total(killed), by(county_name year)
egen animal_injuries = total(injured), by(county_name year)
gen animal_pdo = animal_total - animal_fatal - animal_injury
gen imputation_flag_animal_pdo = 1

drop killed injured type is_animal 
drop if county_name == ""
duplicates drop 

/*----------------------------------------------------*/
      /* [>    Merge with total   <] */
/*----------------------------------------------------*/
merge 1:1 year county_name using "`ky_total'"
br if _merge!=3
drop _merge

* creating a balanced dataset
fillin year county_name
drop _fillin

/*----------------------------------------------------*/
      /* [>   3.  Merge with state_county_identifiers <] */
/*----------------------------------------------------*/
gen state_letter_code  = "KY" // add state abbreviation
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

sort county_name year, stable 
drop if county_name == "" | county_name == "totals"  | county_name == "totals(state)" 

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
save "$working_data/dvcs_KY_county_year_`T1'_`T2'.dta" ,replace
