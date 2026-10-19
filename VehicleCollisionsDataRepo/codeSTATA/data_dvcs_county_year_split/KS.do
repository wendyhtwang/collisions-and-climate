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

*************************KS (all data were kept)
/*----------------------------------------------------*/
      /* [>   1.  Total 90-18 <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/KS/KS.TVC.90-14.CountySeverity.xlsx"
import excel using "`file_name'", allstring cellrange(A1:H2731) firstrow case(lower) clear

drop if year== "2015**"
rename motorvehicleaccidentsummarys county_name
rename fatalaccidents total_fatal
rename deathspeople total_fatalities
rename injuriespeople total_injuries
rename injuryaccidents total_injury
rename pdoaccidents total_pdo
rename totalaccidents total_total
replace county_name=county_name[_n-1] if county_name==""

tempfile TVC_90_14
save `TVC_90_14', replace


clear
local file_name = "$path/dataCSV/DVCs/KS/KS.TVC.15-18.CountySeverity.xlsx"
import excel using "`file_name'" , describe

forvalues s =1/`r(N_worksheet)' {
    import excel using "`file_name'", allstring sheet(`r(worksheet_`s')') cellrange(A1:L107) firstrow case(lower) clear
    gen year = "`r(worksheet_`s')'"

    tempfile newstata`s'
    save `newstata`s'', replace
}

local Nminus = `r(N_worksheet)'-1

forvalues s = 1/`Nminus' {
    append using `newstata`s'', force
}

rename countysummaries county_name
rename totalcrashes total_total
rename fatalcrashes total_fatal
rename injurycrashes total_injury
rename pdocrashes total_pdo
rename deathspeople total_fatalities
rename injuriespeople total_injuries

append using `TVC_90_14', force
drop peds restraintuse deercrashes speedrelatedcrashesrelated alcoholrelatedcrashesrelated

replace total_fatal ="." if total_fatal == "-"
replace total_pdo ="." if total_pdo == "-"
replace total_fatalities ="." if total_fatalities == "-"

destring total_total ///
        total_fatal ///
        total_injuries ///
        total_injury ///
        total_pdo ///
        total_fatalities ///
        year, ignore("," "NA" " ") replace

duplicates list county_name year
duplicates drop

tempfile ks_total
save `ks_total', replace

/*----------------------------------------------------*/
      /* [>   2.  Deer 90-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/KS/KS.DVC.90-14.CountySeverity.xlsx"
import excel using "`file_name'", allstring firstrow case(lower) clear

replace year = "2015" if year=="2015**"
rename motorvehicleaccidentsummarys county_name
rename totalaccidents deer_total
rename fatalaccidents deer_fatal
rename injuryaccidents deer_injury
rename pdoaccidents deer_pdo
rename deathspeople deer_fatalities
rename injuriespeople deer_injuries
replace county_name=county_name[_n-1] if county_name==""

destring deer_total ///
        deer_fatal ///
        deer_injury ///
        deer_pdo ///
        deer_fatalities ///
        deer_injuries ///
        year, ignore("," "NA" " ") replace

duplicates list
duplicates drop

tempfile ks_deer
save `ks_deer', replace


/*----------------------------------------------------*/
      /* [>   3.  Animal 10-14   <] */
/*----------------------------------------------------*/
clear
local file_name = "$path/dataCSV/DVCs/KS/KS.AVC.10-14.CountySeverity.xlsx"
import excel using "`file_name'", allstring firstrow case(lower) clear


ren statewideanimalcrashesbycoun county_name
ren totalcrashes animal_total
ren fatalcrashes animal_fatal
ren injurycrashes animal_injury
ren pdocrashes animal_pdo
ren numberofdeaths animal_fatalities
ren numberofinjuries animal_injuries

replace county_name=county_name[_n-1] if county_name==""

destring animal_total ///
        animal_fatal ///
        animal_injury ///
        animal_pdo ///
        animal_fatalities ///
        animal_injuries ///
        year, ignore("," "NA" " ") replace

merge 1:1 year county_name year using `ks_total', nogenerate
merge 1:1 year county_name year using `ks_deer', nogenerate

tempfile CSV
save `CSV', replace

/*----------------------------------------------------*/
      /* [>   3.  Total & Animal & Deer 15-19   <] */
/*----------------------------------------------------*/
/* [> generate county code <] */
clear
local file_name = "$path/dataRAW/DVCs/KS/DataExport_07_16_2020/STWD Accs_2015-2020_Hernandez/Data/COUNTY_TABLE.xlsx"
import excel using "`file_name'", allstring firstrow case(lower) clear
keep county_nbr county_name

tempfile county_code
save `county_code', replace

/* [> main data <] */
clear
set excelxlsxlargefile on
local file_name = "$path/dataRAW/DVCs/KS/DataExport_07_16_2020/STWD Accs_2015-2020_Hernandez/Data/ACCIDENTS_TABLE.xlsx"
import excel using "`file_name'", allstring cellrange(E1:CT337185) firstrow case(lower) clear

keep county_nbr date_of_accident accident_class_mhe animal_type reporting_severity
gen year = substr(date_of_accident,-4,.)
drop date_of_accident

* page 35 for crash class / page 38 for deer / page 7 for injury fatal or pdo
egen total_fatal = total(reporting_severity=="F"), by(county_nbr year)  //total
egen total_injury = total(reporting_severity=="I"), by(county_nbr year)
egen total_pdo = total(reporting_severity=="PO"), by(county_nbr year)

egen animal_fatal = total(accident_class_mhe == "07" & reporting_severity=="F"), by(county_nbr year)  //animal column AX & reporting_severity CT
egen animal_injury = total(accident_class_mhe == "07" & reporting_severity=="I"), by(county_nbr year)
egen animal_pdo = total(accident_class_mhe == "07" & reporting_severity=="PO"), by(county_nbr year)

egen deer_fatal = total(animal_type == "01" & reporting_severity=="F"), by(county_nbr year) //deer column BM
egen deer_injury = total(animal_type == "01" & reporting_severity=="I"), by(county_nbr year)
egen deer_pdo = total(animal_type == "01" & reporting_severity=="PO"), by(county_nbr year)

drop animal_type accident_class_mhe reporting_severity

merge m:1 county_nbr using `county_code', nogenerate
drop county_nbr

duplicates drop
duplicates list county_name year

drop if year == ""
destring year, replace

/* [> merge with data in dataCSV <] */
merge 1:1 year county_name year using `CSV'
br if _merge!=3
drop _merge
gen state_letter_code  = "KS" // add state abbreviation

assert total_fatal>=0 ///
    & total_fatalities>=0 ///
    & total_injury>=0 ///
    & total_injuries>=0 ///
    & total_pdo>=0 ///
    & total_total>=0 ///
    & deer_fatal>=0 ///
    & deer_fatalities>=0 ///
    & deer_injury>=0 ///
    & deer_injuries>=0 ///
    & deer_pdo>=0 ///
    & deer_total>=0 ///
    & animal_fatal>=0 ///
    & animal_injury>=0 ///
    & animal_pdo>=0 , fast // sanity check

replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = subinstr(county_name,"st ","st. ", .) if strpos(county_name,"st") == 1
drop if year == 2020
/*----------------------------------------------------*/
      /* [>   4. Merge with  state_county_identifiers <] */
/*----------------------------------------------------*/
local state_county_identifiers "$path/dataSTATA/_AUX/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`state_county_identifiers'", keep(1 3)
br if _merge==1
drop _merge

sort county_name year, stable
drop if county_name == "total"
drop if year == .

order state_letter_code ///
    state_name ///
    county_name ///
    state_fips ///
    county_fips ///
    fips year ///
    total* ///
    animal* ///
    deer*

/* [> imputation <] */
replace total_total = total_fatal +total_injury + total_pdo
replace animal_total = animal_fatal+animal_injury+animal_pdo if animal_total ==.
replace deer_total = deer_fatal+deer_injury+deer_pdo if deer_total ==.

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
compress
save "$working_data/dvcs_KS_county_year_`T1'_`T2'.dta" ,replace
