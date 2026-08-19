/*==============================================================
FILE:         clean_IA.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Charvi Khandelwal

PURPOSE:      Build the Iowa county-year vehicle collision panel from
              crash-level records geocoded to county FIPS.

CHANGELOG:
  07/01/2020 [Siyue Ouyang]: created
  07/08/2020 [Siyue Ouyang]: code style change
  07/13/2020 [Siyue Ouyang]: add more states
  07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use,
    add more states
  05/23/2021 [Rukhshan Arif Mian]: commented out line 102 (dont drop
    county_num as it is used. just drop _merge)
  06/01/2025 [Emily Price]: updated for 2015-onwards, referencing
    shapefile conversion code in R
  08/17/2026 [Charvi Khandelwal]: dropped the 2004-2014 legacy section (source files
    iowa_counties.xlsx and the *county*.xlsx folder are not available)
    and rebuilt the crash-level section to follow the same
    severity-dummy / animal-dummy / single-collapse structure used in
    AZ.do, sourced entirely from CrashData_UoC.xlsx. This also meant
    renaming variables to match AZ.do's convention: total_fatal ->
    fatal_collision, total_major_injury -> major_injury_collision,
    total_minor_injury -> minor_injury_collision, total_injury ->
    injury_collision, total_pdo -> pdo_collision, animal_total ->
    animal_collision, animal_fatal -> fatal_animal_collision,
    animal_major_injury -> major_injury_animal_collision,
    animal_minor_injury -> minor_injury_animal_collision, animal_injury
    -> injury_animal_collision, animal_pdo -> pdo_animal. total_fatalities,
    total_injuries, and animal_fatalities/animal_injuries keep their
    prior names since AZ.do names these the same way. Fixed a real bug
    along the way: animal_collision previously matched on
    "Animal-Related" (no space) but the raw major_cause value is
    "Animal- Related" (space before hyphen), so animal_collision and
    every downstream animal_* variable were silently zero for the
    entire crash-level extract. Also added an unknown_severity_collision
    bucket so severity categories reconcile exactly to total_all_cause,
    since crashseverityclass includes an "Unknown" value (~2.7% of
    records) that fatal/major/minor/pdo do not otherwise cover. FIPS
    assignment is handled by an external R/Quarto script
    (Nicole_IA_Shapefile_Conversion.qmd) documented at the point it is
    called below; rows whose coordinates could not be matched to a
    county are split off and saved separately rather than silently
    dropped or merged into the wrong county. Also dropped lightingtype
    (unused anywhere in this pipeline, and fully missing for all of
    2015 in the raw file), and added the
    /mnt/data_d/Dropbox/Research confirmdir check in Section 0 alongside
    the existing C:/Dropbox and D:/Dropbox checks.
  08/18/2026 [Charvi Khandelwal]: confirmed state_county_identifiers.dta against the
    actual file (3,151 rows, one row per state_letter_code/fips pair, no
    duplicates or missing keys; 99 Iowa counties; fips is a zero-padded
    5-digit string, e.g. "19001", matching the string type produced by
    stringcols(4) on the crash-level fips import). The Section 3 merge
    key types now line up on both sides as far as static inspection can
    confirm. Also added a duplicates tag (not drop) on crash_year,
    crashmonth, crashseverityclass, major_cause, xcoord, ycoord,
    fatalities, serious_injuries, minor_injury, and possible_injuries,
    since the prior version had no duplicate check at all; flagged
    rather than dropped because rows sharing every visible field are
    not necessarily the same real-world crash recorded twice. Note that
    since the 2004-2014 legacy section was removed, the final saved
    panel's year range (t1/t2 in the output filename) now reflects only
    the 2015+ crash-level data and is narrower than in prior versions of
    this file that included the legacy years.
==============================================================*/

*---------------------------------------------------------------
* SECTION 0: SETUP
*---------------------------------------------------------------

cap log close
clear all
set more off, permanently
set matsize 11000
set maxvar 32767
set scheme s1mono

confirmdir "/mnt/data_d/Dropbox/Research"
if r(confirmdir) == "0" {
  local rootDir = "/mnt/data_d/Dropbox/Research"
}

confirmdir "C:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "C:/Dropbox/Research"
}

confirmdir "D:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "D:/Dropbox/Research"
}

global path "`rootDir'/VehicleCollisionsDataRepo"
global working_data "$path/dataSTATA"

*---------------------------------------------------------------
* SECTION 1: ASSIGN COUNTY FIPS TO CRASH COORDINATES
*---------------------------------------------------------------

* Nicole_IA_Shapefile_Conversion.qmd assigns crash_id (row order at
* import), spatially joins each crash's xcoord/ycoord to an Iowa county
* polygon, and exports crash_id/xcoord/ycoord/fips/fips_method to
* revised_crash_coords_to_fips.csv. fips_method records how each match
* was made:
*   direct               - point fell inside a county polygon directly
*   nearest_snap_clean   - <=75m from nearest county, snapped with confidence
*   nearest_snap_flagged - 75m-1000m from nearest county, snapped but uncertain
*   unmatched            - >1000m from nearest county (fips is missing)
*   no_coordinates       - xcoord/ycoord missing in the raw file entirely
* The join predicate used is st_within (a point counts as inside a
* county only if strictly interior to its polygon); st_intersects would
* also count points that land exactly on a boundary, which st_within
* can miss due to floating-point rounding after reprojection. The
* nearest_snap tiers cover most of what that would otherwise catch.
*
* This file is a Quarto document, so it is rendered through the quarto
* CLI rather than called directly with Stata's rscript command.
shell quarto render "$path/codeR/Nicole_IA_Shapefile_Conversion.qmd" --execute

*---------------------------------------------------------------
* SECTION 2: PROCESS CRASH-LEVEL DATA
*---------------------------------------------------------------

set excelxlsxlargefile on
local file_name = "$path/dataRAW/DVCs/IA/CrashData_UoC.xlsx"
import excel using "`file_name'", firstrow case(lower) clear

* crash_id reflects original row order in the raw file, generated
* immediately after import before any sort/merge/drop. This matches the
* crash_id assigned in Nicole_IA_Shapefile_Conversion.qmd, so the two
* align 1:1 as long as neither file's import step reorders or filters
* rows beforehand.
gen crash_id = _n

* lighting type is not used anywhere in this pipeline and is fully
* missing for all of 2015
drop lightingtype

* merge in county fips + fips_method
preserve
    import delimited ///
        "$path/dataRAW/DVCs/IA/revised_crash_coords_to_fips.csv", ///
        clear stringcols(4)
    tempfile fips_lookup
    save `fips_lookup', replace
restore

* many-to-one merge: many crash_id rows can share one (xcoord, ycoord)
* pair, and all of them correctly inherit that coordinate's
* fips/fips_method
merge m:1 xcoord ycoord using `fips_lookup'
assert _merge != 1
assert _merge != 2
drop _merge

tab fips_method, missing

* explicitly split off rows without a usable fips before collapsing;
* "unmatched" and "no_coordinates" rows have no real county assignment
* and would otherwise silently vanish or corrupt a county's totals if
* carried through
count if fips_method == "unmatched"
count if fips_method == "no_coordinates"
count if missing(fips)

preserve
    keep if fips_method == "unmatched" ///
        | fips_method == "no_coordinates" ///
        | missing(fips)
    save "$working_data/dvcs_IA_excluded_crashes.dta", replace
restore

drop if fips_method == "unmatched" ///
    | fips_method == "no_coordinates" ///
    | missing(fips)

* flag (not drop) exact-duplicate rows now that crash_id gives every row
* a real identity. Rows sharing every visible field are not necessarily
* the same real-world crash recorded twice, since this is common among
* rows sharing a coordinate; flag for review instead of deleting.
duplicates tag crash_year ///
               crashmonth ///
               crashseverityclass ///
               major_cause ///
               xcoord ///
               ycoord ///
               fatalities ///
               serious_injuries ///
               minor_injury ///
               possible_injuries, ///
               gen(dup_tag)
count if dup_tag > 0

rename crash_year year
rename crashseverityclass severity
rename fatalities total_fatalities
rename serious_injuries major_injuries
gen minor_injuries = minor_injury + possible_injuries
gen total_injuries = major_injuries + minor_injuries

* Summing the number of rows by county-year gives total_all_cause after
* collapsing
gen total_all_cause = 1

* severity dummies. "Unknown" (~2.7% of records) is its own bucket so
* that every crash lands in exactly one category.
gen fatal_collision        = (severity == "Fatal")
gen major_injury_collision = (severity == "Serious")
gen minor_injury_collision = (severity == "Minor" | severity == "Possible")
gen injury_collision       = (major_injury_collision == 1 | minor_injury_collision == 1)
gen pdo_collision          = (severity == "PDO")
gen unknown_severity_collision = (severity == "Unknown")

assert fatal_collision ///
       + major_injury_collision ///
       + minor_injury_collision ///
       + pdo_collision ///
       + unknown_severity_collision == total_all_cause

* animal collision dummy
* raw major_cause value is "Animal- Related" (space before hyphen)
gen animal_collision = (strpos(major_cause, "Animal- Related") > 0)

gen fatal_animal_collision        = animal_collision*fatal_collision
gen injury_animal_collision       = animal_collision&injury_collision
gen major_injury_animal_collision = animal_collision*major_injury_collision
gen minor_injury_animal_collision = animal_collision*minor_injury_collision
gen pdo_animal                    = animal_collision*pdo_collision
gen animal_fatalities             = animal_collision*total_fatalities
gen animal_injuries               = animal_collision*total_injuries

gen state_letter_code = "IA"

collapse (sum) total_all_cause ///
               fatal_collision ///
               injury_collision ///
               total_fatalities ///
               major_injury_collision ///
               minor_injury_collision ///
               total_injuries ///
               pdo_collision ///
               unknown_severity_collision ///
               animal_collision ///
               fatal_animal_collision ///
               injury_animal_collision ///
               major_injury_animal_collision ///
               minor_injury_animal_collision ///
               pdo_animal ///
               animal_fatalities ///
               animal_injuries, ///
               by(fips year state_letter_code)

assert fatal_collision ///
       + major_injury_collision ///
       + minor_injury_collision ///
       + pdo_collision ///
       + unknown_severity_collision == total_all_cause

assert animal_collision >= 0 ///
       & fatal_animal_collision >= 0 ///
       & major_injury_animal_collision >= 0 ///
       & minor_injury_animal_collision >= 0 ///
       & pdo_animal >= 0 ///
       & animal_fatalities >= 0 ///
       & animal_injuries >= 0 ///
       & total_all_cause >= 0 ///
       & fatal_collision >= 0 ///
       & major_injury_collision >= 0 ///
       & minor_injury_collision >= 0 ///
       & pdo_collision >= 0 ///
       & unknown_severity_collision >= 0 ///
       & total_fatalities >= 0 ///
       & total_injuries >= 0, fast

*---------------------------------------------------------------
* SECTION 3: MERGE COUNTY IDENTIFIERS
*---------------------------------------------------------------

merge m:1 state_letter_code fips using ///
    "$path/dataSTATA/state_county_identifiers.dta", keep(1 3)
count if _merge == 1
drop _merge

drop if county_name == ""

*---------------------------------------------------------------
* SECTION 4: FINAL SAVE
*---------------------------------------------------------------

sort county_name year, stable
order state_letter_code ///
      state_name ///
      county_name ///
      state_fips ///
      county_fips ///
      fips ///
      year ///
      total* ///
      animal*

qui summ year
local t1 = `r(min)'
local t2 = `r(max)'

compress
save "$working_data/dvcs_IA_county_year_`t1'_`t2'.dta", replace
log close
