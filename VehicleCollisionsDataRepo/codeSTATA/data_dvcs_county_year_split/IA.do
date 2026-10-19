/*******************************************************************************
Current Lead:  Charvi Khandelwal
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
05/23/2021 [Rukhshan Arif Mian]: commented out line 102 (dont drop county_num as
  it is used. just drop _merge)
06/01/2025 [Emily Price]: updated for 2015-onwards, referencing shapefile
  conversion code in R
08/17/2026 [Charvi Khandelwal]: dropped the legacy section and rebuilt the
  crash-level section on AZ.do's severity-dummy / animal-dummy / single-collapse
  structure, with AZ.do's variable names. Fixed a real bug: animal_collision
  matched "Animal-Related" but the raw major_cause value is "Animal- Related"
  (space before hyphen), so every animal_* variable was silently zero
08/18/2026 [Charvi Khandelwal]: verified state_county_identifiers.dta (3,151
  rows, 99 Iowa counties, fips a zero-padded 5-digit string). Added a duplicates
  tag (not drop) on the crash-level extract
08/27/2026 [Charvi Khandelwal]: restored 2004-2014 coverage (Section 3),
  expanded the injury and property damage variables, and reconciled severity
  across the 2015 seam. READ THE SOURCE DIFFERENCES BLOCK BELOW before using
  the panel
09/04/2026 [Charvi Khandelwal - code review]: made the file run end to end and
  fixed several silent-failure bugs. No change to the intended data logic.
  Run environment:
  - Section 1 called the shapefile script via `shell quarto render' on a .qmd.
    quarto is not installed on the MATE server, and `shell' does not halt a do
    file on failure, so the render failed silently and surfaced as "file not
    found" many lines later. Now calls the plain .R script via rscript, which
    checks the exit code. R is located by searching known paths and passed via
    rpath()
  - Section 0 auto-installs the two SSC commands this file needs but does not
    ship with: confirmdir and rscript
  - added a check that $path resolved, and restored the `log using' that had
    gone missing (every run ended in error 606)
  - $ia_legacy pointed at dataRAW/DVCs/IA/legacy_county_dbf, which does not
    exist. The files are .xlsx in dataCSV/DVCs/IA. Section 3 now accepts .csv,
    .xlsx or .dbf, whichever it finds
  - the legacy branch is conditional: if no files are found it warns loudly and
    continues with 2015+ alone instead of dying on a missing tempfile after
    Section 2 had already succeeded
  Data bugs:
  - stringcols(4) -> stringcols(3) on the fips CSV import. The CSV has 4
    columns, so fips is column 3; stringcols(4) left fips NUMERIC and would
    have failed the Section 5 merge against state_county_identifiers.dta's
    string fips. Caught by Wendy Wang
  - animal_fatalities and the other three animal injury-count variables were
    animal_collision*<count>. In Stata 0*. is missing, so a NON-animal crash
    with missing injury data produced a missing animal count instead of a
    structural zero. Now cond()
  - dup_tag was computed and commented "flagged for review" but collapse
    dropped it, so the flag reached no output. Tagged rows now save to
    dvcs_IA_duplicate_flagged_crashes.dta and a county-year count rides into
    the panel as n_duplicate_flagged (2015+ only; missing, not zero, for
    legacy rows)
  - Section 5's `count if _merge == 1' only printed, so an unmatched fips would
    be silently dropped by the following `drop if county_name == ""'. Now
    asserts
  - the final `table year' used statistic(), which requires Stata 17. This
    server runs 16.1, so it failed with r(198) as the last command before the
    save. Replaced with a preserve/collapse block that runs in any version and
    also prints the animal share by year and source, for checking the
    2014/2015 seam
  - spelled out the `order' list; made the final `log close' capture
  EDITING CAUTION: do not write an asterisk immediately followed by a forward
  slash anywhere in this comment block, including in prose or when naming
  variable wildcards. That sequence closes the block and Stata parses the rest
  of the documentation as commands
*******************************************************************************/

/*******************************************************************************
SOURCE DIFFERENCES ACROSS THE 2015 SEAM - READ BEFORE USING

This file builds the Iowa county-year vehicle collision panel, 2004 onwards,
from two structurally different sources:
  2004-2014  pre-aggregated county-year files in dataCSV/DVCs/IA, currently
             .xlsx (county_YYYY, animal_county_YYYY)
  2015+      crash-level records (CrashData_UoC.xlsx) geocoded to county FIPS

1. SEVERITY. The legacy files collapse Possible and Unknown severity into one
   field (sum_possun, 16.4% of legacy crashes); the crash-level data keeps them
   apart (Possible 13.2%, Unknown 2.7%). They are therefore COMBINED on both
   sides as poss_unknown_collision. possible_collision and
   unknown_severity_collision are provided for 2015+ only if you want to net
   Unknown out of the later years.

   Consequence: injury_collision includes unknown-severity crashes in BOTH
   periods, unlike AZ.do, which excludes them. Excluding Unknown is impossible
   pre-2015 and would put a ~2.7pp discontinuity at 2015, so comparability
   across the seam was prioritised. Revisit if AZ/IA cross-state comparison
   matters more than the IA time series.

2. INJURIES. total_injuries is major + minor (minor = minor + possible) in both
   periods, EXCLUDING unknown injuries, because the crash-level extract has no
   unknown-injury column. unknown_injuries is therefore 2004-2014 only. Legacy
   sum_injuri (which includes unknown) is asserted against its components and
   dropped.

3. PROPERTY DAMAGE. Legacy only (sum_propdm, dollars). Missing 2015+.

4. LEGACY COVERAGE IS COMPLETE. Verified 09/04/2026: all 22 files present in
   dataCSV/DVCs/IA, both families for every year 2004-2014, so every legacy
   year has both animal and all-cause counts. If a future refresh does drop a
   file, Section 3 reports it by year and leaves that side MISSING rather than
   zero - check the log, not this note.

   Every file has 99 rows after dropping the county == 0 row present in the
   2007 files, except animal_county_2006 which has 98 (a county with no animal
   collisions produced no row). The 99-county skeleton in Section 3 fills that
   as a structural zero.

   Animal share by legacy year, for spotting future import errors: 2004 14.3%,
   2005 12.5%, 2006 15.2%, 2007 13.1%, 2008 11.8%, 2009 13.8%, 2010 11.9%,
   2011 13.2%, 2012 13.0%, 2013 12.0%, 2014 12.3%.

5. Pre-2015 rows have no crash-level detail: no month, no coordinates, no
   duplicate flags, no excluded-crash accounting. data_source marks which side
   of the seam each row came from.

6. NO ALCOHOL / DUI DATA IS AVAILABLE FROM EITHER SOURCE. The legacy files
   carry 14 fields, none impairment-related. The crash-level extract has 73
   distinct major_cause values, none identifying alcohol or drug involvement
   (the closest, "Operating vehicle in a reckless, erratic, careless,
   negligent manner" and "Aggressive driving/road rage", are not DUI
   indicators). Iowa records impairment in separate crash- and driver-level
   fields not included in this extract. To add DUI counts, either request a
   re-pull from Iowa DOT including the drug/alcohol indicator, or merge in
   FARS (county-level, 1975+, but fatal crashes only).
*******************************************************************************/

*---------------------------------------------------------------
* SECTION 0: SETUP
*---------------------------------------------------------------

cap log close
clear all
set more off, permanently
set matsize 11000
set maxvar 32767
set scheme s1mono

* CHANGE (09/04/2026): this file depends on two user-written SSC
* commands. Install into the user's own ado directory if missing (no
* admin rights needed). confirmdir is used immediately below; rscript is
* used in Section 1.
foreach pkg in confirmdir rscript {
    cap which `pkg'
    if _rc != 0 {
        di as txt "Installing missing SSC command: `pkg'"
        cap noi ssc install `pkg'
        cap which `pkg'
        if _rc != 0 {
            di as err "Could not install `pkg' from SSC."
            di as err "If the server blocks SSC, ask an admin to install it."
            error 111
        }
    }
}

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

* CHANGE (09/04/2026): stop here if none of the three checks
* above matched, rather than letting an empty `rootDir' produce a broken
* $path that only fails several sections later.
if "`rootDir'" == "" {
    di as err "None of the expected Dropbox roots were found."
    di as err "Add this machine's root directory to the confirmdir"
    di as err "checks above before running."
    error 601
}

global path "`rootDir'/VehicleCollisionsDataRepo"
global working_data "$path/dataSTATA"
global ia_raw "$path/dataRAW/DVCs/IA"

di as txt "Using path: $path"

* location of the legacy county-year .dbf files; adjust if they live
* somewhere else in the repo
* Location of the legacy county-year files (2004-2014). CONFIRMED
* 09/04/2026. The import loop in Section 3 accepts .csv, .xlsx or .dbf
* and picks whichever it finds, so this needs to be the directory only.
global ia_legacy "$path/dataCSV/DVCs/IA"

cap mkdir "$path/logs"
log using "$path/logs/clean_IA.log", replace text

*---------------------------------------------------------------
* SECTION 1: ASSIGN COUNTY FIPS TO CRASH COORDINATES (2015+)
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
* CHANGE (09/04/2026): was
*   shell quarto render "$path/codeR/Nicole_IA_Shapefile_Conversion.qmd" --execute
* Now calls the plain .R script through rscript. Note that `shell' does
* not stop a do file when the shelled command fails, so a failed render
* used to fall through to the import below and surface as a confusing
* "file not found"; rscript checks the exit code and halts.
*
* rscript's own search does not find R on the MATE server, so look for
* the executable in the usual places and pass it explicitly via rpath()
* when found. Detected rather than hardcoded so this still runs on
* machines where R lives elsewhere or where auto-detection works.
local rexe ""
foreach cand in "/usr/bin/Rscript" ///
                "/usr/local/bin/Rscript" ///
                "/opt/R/bin/Rscript" {
    if "`rexe'" == "" {
        cap confirm file "`cand'"
        if _rc == 0 local rexe "`cand'"
    }
}

local rfile "$path/codeR/Nicole_IA_Shapefile_Conversion_082126_edited.R"
cap confirm file "`rfile'"
if _rc != 0 {
    di as err "R script not found at:"
    di as err "`rfile'"
    error 601
}

if "`rexe'" != "" {
    di as txt "Calling R via: `rexe'"
    rscript using "`rfile'", rpath("`rexe'")
}
else {
    di as txt "No known Rscript path found; letting rscript auto-detect."
    rscript using "`rfile'"
}

* confirm the R step actually produced the lookup this section needs
cap confirm file "$ia_raw/revised_crash_coords_to_fips.csv"
if _rc != 0 {
    di as err "The R script ran but revised_crash_coords_to_fips.csv is"
    di as err "not at $ia_raw. Check the write path in the R script."
    error 601
}

*---------------------------------------------------------------
* SECTION 2: PROCESS CRASH-LEVEL DATA (2015+)
*---------------------------------------------------------------

set excelxlsxlargefile on
local file_name = "$ia_raw/CrashData_UoC.xlsx"
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
    * CHANGE (09/04/2026): stringcols(3), not stringcols(4). The
    * exported CSV has 4 columns (xcoord, ycoord, fips, fips_method), so
    * fips is column 3. stringcols(4) forced fips_method (already text)
    * to string while leaving fips NUMERIC, which would have failed the
    * Section 5 merge against state_county_identifiers.dta's
    * string-typed fips.
    import delimited ///
        "$ia_raw/revised_crash_coords_to_fips.csv", ///
        clear stringcols(3)
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

drop if fips_method == "unmatched"  | ///
                       fips_method == "no_coordinates" | ///
                       missing(fips)

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

* CHANGE (09/04/2026): collapse drops dup_tag, so the flag never
* reached any output. A binary indicator carries a county-year count
* into the panel; the tagged rows themselves are saved for review after
* the partial-year drop below, so the review file matches the panel's
* scope.
* Legacy rows have no crash-level detail, so n_duplicate_flagged stays
* missing for them rather than being zero-filled -- "not checkable" is
* not "none found".
gen byte dup_tag_flagged = (dup_tag > 0)

rename crash_year year
rename crashseverityclass severity

* --- drop incomplete calendar years -------------------------------
* The extract runs past the end of the last complete year (as of this
* writing it reaches March 2026). A county-year row built from a
* partial year reads as a collapse in collisions rather than as missing
* data, so any year without all 12 months present is dropped. This is
* written generally so it keeps working as the extract is refreshed.
egen ym_tag = tag(year crashmonth)
bysort year: egen months_present = total(ym_tag)
levelsof year if months_present < 12, local(partial_years)
if "`partial_years'" != "" {
    display as text "Dropping incomplete calendar year(s): `partial_years'"
    tab crashmonth if months_present < 12
}
drop if months_present < 12
drop ym_tag months_present

* CHANGE (09/04/2026): saved here, after the partial-year drop,
* so the review file covers exactly the years that reach the panel.
preserve
    keep if dup_tag_flagged == 1
    save "$working_data/dvcs_IA_duplicate_flagged_crashes.dta", replace
restore

rename fatalities total_fatalities
rename serious_injuries major_injuries
gen minor_injuries = minor_injury + possible_injuries
gen total_injuries = major_injuries + minor_injuries

* Summing the number of rows by county-year gives total_all_cause after
* collapsing
gen total_all_cause = 1

* --- severity dummies ----------------------------------------------
* Possible and Unknown are combined into poss_unknown_collision to
* match the legacy sum_possun field. possible_collision and
* unknown_severity_collision keep the finer distinction for 2015+ only.
gen fatal_collision            = (severity == "Fatal")
gen major_injury_collision     = (severity == "Serious")
gen minor_injury_collision     = (severity == "Minor")
gen poss_unknown_collision     = (severity == "Possible" | severity == "Unknown")
gen possible_collision         = (severity == "Possible")
gen unknown_severity_collision = (severity == "Unknown")
gen pdo_collision              = (severity == "PDO")

gen injury_collision = (major_injury_collision == 1 | ///
                        minor_injury_collision == 1 | ///
                        poss_unknown_collision == 1)

assert fatal_collision ///
       + major_injury_collision ///
       + minor_injury_collision ///
       + poss_unknown_collision ///
       + pdo_collision == total_all_cause

assert possible_collision + unknown_severity_collision == poss_unknown_collision

* --- animal collision dummy ----------------------------------------
* raw major_cause value is "Animal- Related" (space before hyphen).
* "Driver Distraction: Unrestrained animal" is a separate cause and is
* correctly NOT matched by this string.
gen animal_collision = (strpos(major_cause, "Animal- Related") > 0)

gen fatal_animal_collision            = animal_collision*fatal_collision
gen major_injury_animal_collision     = animal_collision*major_injury_collision
gen minor_injury_animal_collision     = animal_collision*minor_injury_collision
gen poss_unknown_animal_collision     = animal_collision*poss_unknown_collision
gen possible_animal_collision         = animal_collision*possible_collision
gen unknown_severity_animal_coll      = animal_collision*unknown_severity_collision
gen pdo_animal                        = animal_collision*pdo_collision
gen injury_animal_collision           = animal_collision*injury_collision

* CHANGE (09/04/2026): cond(), not multiplication, for the four
* variables built from INJURY COUNTS rather than 0/1 dummies. In Stata
* 0*. is missing, so a non-animal crash with missing injury data used to
* produce a missing animal count instead of the structural zero it
* should be. Missing data on an actual animal crash stays missing. The
* dummy-times-dummy variables above cannot be missing and are left as-is.
gen animal_fatalities      = cond(animal_collision == 1, total_fatalities, 0)
gen animal_major_injuries  = cond(animal_collision == 1, major_injuries, 0)
gen animal_minor_injuries  = cond(animal_collision == 1, minor_injuries, 0)
gen animal_injuries        = cond(animal_collision == 1, total_injuries, 0)

* report crashes with incomplete injury data. collapse (sum) ignores
* missings, so these quietly understate their county-year's totals.
count if missing(major_injuries) | missing(minor_injuries)
if r(N) > 0 {
    di as txt "NOTE: `r(N)' crash(es) have incomplete injury data and"
    di as txt "will not contribute to their county-year injury totals."
}

gen state_letter_code = "IA"

* unknown_injuries and property_damage are deliberately NOT created
* here. They exist only in the legacy files, and appending rather than
* generating them as missing keeps collapse(sum) from turning an
* all-missing column into a column of zeros.
collapse (sum) total_all_cause ///
               fatal_collision ///
               major_injury_collision ///
               minor_injury_collision ///
               poss_unknown_collision ///
               possible_collision ///
               unknown_severity_collision ///
               pdo_collision ///
               injury_collision ///
               total_fatalities ///
               major_injuries ///
               minor_injuries ///
               total_injuries ///
               animal_collision ///
               fatal_animal_collision ///
               major_injury_animal_collision ///
               minor_injury_animal_collision ///
               poss_unknown_animal_collision ///
               possible_animal_collision ///
               unknown_severity_animal_coll ///
               pdo_animal ///
               injury_animal_collision ///
               animal_fatalities ///
               animal_major_injuries ///
               animal_minor_injuries ///
               animal_injuries ///
               dup_tag_flagged, ///
               by(fips year state_letter_code)

rename dup_tag_flagged n_duplicate_flagged

assert fatal_collision ///
       + major_injury_collision ///
       + minor_injury_collision ///
       + poss_unknown_collision ///
       + pdo_collision == total_all_cause

gen data_source = "crash_level"

tempfile crashlevel
save `crashlevel', replace

*---------------------------------------------------------------
* SECTION 3: PROCESS LEGACY COUNTY-YEAR DATA (2004-2014)
*---------------------------------------------------------------

* These files are already aggregated to county-year, one row per county,
* so there is no collapse step. Two families per year:
*   county_YYYY.dbf         all-cause collisions
*   animal_county_YYYY.dbf  animal-related collisions only
*
* Both share the same 14-field schema. Known quirks handled below:
*   - the county field is Iowa's 1-99 county code, NOT FIPS
*   - county == 0 appears in the 2007 files (one PDO crash with no
*     county assigned); dropped, mirroring the unmatched-coordinate
*     handling in Section 2
*   - a county with zero matching crashes produces NO ROW at all (e.g.
*     animal_county_2006.dbf has 98 rows; county 83 is absent). These
*     are structural zeros, so each year is built off a full 99-county
*     skeleton and missing values are filled with 0 rather than left
*     missing, which would silently unbalance the panel.

* CHANGE (09/04/2026): check the legacy directory exists before
* the loop, so the failure mode is one clear message rather than eleven
* "neither legacy file found" lines.
capture confirmdir "$ia_legacy"
if r(confirmdir) != "0" {
    di as err "-------------------------------------------------------"
    di as err "LEGACY DIRECTORY NOT FOUND:"
    di as err "  $ia_legacy"
    di as err "The 2004-2014 section will be skipped entirely and the"
    di as err "panel will cover 2015+ only. If the .dbf files exist"
    di as err "elsewhere in the repo, update the \$ia_legacy global in"
    di as err "Section 0. To locate them, run in a terminal:"
    di as err "  find $path/dataRAW/DVCs/IA -iname '*county*.dbf'"
    di as err "-------------------------------------------------------"
}

* full county skeleton, used every year so structural zeros get filled
tempfile skeleton legacy
clear
set obs 99
gen county_num = _n
save `skeleton', replace

local allcause_vars total_all_cause ///
                    fatal_collision ///
                    major_injury_collision ///
                    minor_injury_collision ///
                    poss_unknown_collision ///
                    pdo_collision /// 
                    injury_collision ///
                    total_fatalities ///
                    major_injuries ///
                    minor_injuries ///
                    total_injuries ///
                    unknown_injuries ///
                    property_damage

local animal_vars animal_collision ///
                  fatal_animal_collision ///
                  major_injury_animal_collision ///
                  minor_injury_animal_collision ///
                  poss_unknown_animal_collision ///
                  pdo_animal ///
                  injury_animal_collision ///
                  animal_fatalities /// 
                  animal_major_injuries ///
                  animal_minor_injuries ///
                  animal_injuries /// 
                  animal_unknown_injuries /// 
                  animal_property_damage

local legacy_started = 0

forvalues yr = 2004/2014 {

    * CHANGE (09/04/2026): the legacy files may be .csv, .xlsx or
    * .dbf depending on which export the repo is carrying. Look for each
    * in turn and record which was found, rather than hardcoding .dbf.
    * All three carry the same 14-field schema (COUNTY, COUNT, SUM_*),
    * verified against the 2004-2014 .xlsx exports on 09/04/2026.
    local f_all ""
    local ext_all ""
    local f_anm ""
    local ext_anm ""

    foreach ext in csv xlsx dbf {
        if "`f_all'" == "" {
            cap confirm file "$ia_legacy/county_`yr'.`ext'"
            if _rc == 0 {
                local f_all "$ia_legacy/county_`yr'.`ext'"
                local ext_all "`ext'"
            }
        }
        if "`f_anm'" == "" {
            cap confirm file "$ia_legacy/animal_county_`yr'.`ext'"
            if _rc == 0 {
                local f_anm "$ia_legacy/animal_county_`yr'.`ext'"
                local ext_anm "`ext'"
            }
        }
    }

    local has_all = ("`f_all'" != "")
    local has_anm = ("`f_anm'" != "")

    if `has_all' == 0 & `has_anm' == 0 {
        display as error "  `yr': neither legacy file found, year skipped"
        continue
    }
    if `has_all' == 0 {
        display as error "  `yr': county_`yr' (any format) not found - animal counts only, all-cause left MISSING"
    }
    if `has_anm' == 0 {
        display as error "  `yr': animal_county_`yr' (any format) not found - all-cause only, animal counts left MISSING"
    }

    * ---- all-cause file ----
    tempfile t_all
    if `has_all' {
        if "`ext_all'" == "csv"  import delimited using "`f_all'", clear case(lower) varnames(1)
        if "`ext_all'" == "xlsx" import excel using "`f_all'", clear firstrow case(lower)
        if "`ext_all'" == "dbf"  import dbase using "`f_all'", clear case(lower)

        count if county == 0
        drop if county == 0
        rename county county_num
        isid county_num

        rename count      total_all_cause
        rename sum_fatalc fatal_collision
        rename sum_majorc major_injury_collision
        rename sum_minorc minor_injury_collision
        rename sum_possun poss_unknown_collision
        rename sum_pdoc   pdo_collision
        rename sum_fatali total_fatalities
        rename sum_majinj major_injuries
        rename sum_unkinj unknown_injuries
        rename sum_propdm property_damage

        gen minor_injuries = sum_mininj + sum_possin

        * total_injuries excludes unknown injuries so that it means the
        * same thing as the 2015+ version, which has no unknown column
        gen total_injuries = major_injuries + minor_injuries
        assert sum_injuri == major_injuries + minor_injuries + unknown_injuries

        gen injury_collision = major_injury_collision ///
                             + minor_injury_collision ///
                             + poss_unknown_collision

        assert fatal_collision ///
               + major_injury_collision ///
               + minor_injury_collision ///
               + poss_unknown_collision ///
               + pdo_collision == total_all_cause

        keep county_num `allcause_vars'
        save `t_all', replace
    }

    * ---- animal file ----
    tempfile t_anm
    if `has_anm' {
        if "`ext_anm'" == "csv"  import delimited using "`f_anm'", clear case(lower) varnames(1)
        if "`ext_anm'" == "xlsx" import excel using "`f_anm'", clear firstrow case(lower)
        if "`ext_anm'" == "dbf"  import dbase using "`f_anm'", clear case(lower)

        count if county == 0
        drop if county == 0
        rename county county_num
        isid county_num

        rename count      animal_collision
        rename sum_fatalc fatal_animal_collision
        rename sum_majorc major_injury_animal_collision
        rename sum_minorc minor_injury_animal_collision
        rename sum_possun poss_unknown_animal_collision
        rename sum_pdoc   pdo_animal
        rename sum_fatali animal_fatalities
        rename sum_majinj animal_major_injuries
        rename sum_unkinj animal_unknown_injuries
        rename sum_propdm animal_property_damage

        gen animal_minor_injuries = sum_mininj + sum_possin
        gen animal_injuries = animal_major_injuries + animal_minor_injuries

        gen injury_animal_collision = major_injury_animal_collision ///
                                    + minor_injury_animal_collision ///
                                    + poss_unknown_animal_collision

        assert fatal_animal_collision ///
               + major_injury_animal_collision ///
               + minor_injury_animal_collision ///
               + poss_unknown_animal_collision ///
               + pdo_animal == animal_collision

        keep county_num `animal_vars'
        save `t_anm', replace
    }

    * ---- assemble the year off the 99-county skeleton ----
    use `skeleton', clear
    gen year = `yr'

    if `has_all' {
        merge 1:1 county_num using `t_all'
        assert _merge != 2
        drop _merge
        foreach v of local allcause_vars {
            replace `v' = 0 if missing(`v')
        }
    }

    if `has_anm' {
        merge 1:1 county_num using `t_anm'
        assert _merge != 2
        drop _merge
        foreach v of local animal_vars {
            replace `v' = 0 if missing(`v')
        }
    }

    if `legacy_started' == 1 {
        append using `legacy'
    }
    save `legacy', replace
    local legacy_started = 1
}

* CHANGE (09/04/2026): the loop may find nothing at all, in which
* case `legacy' was never created and `use' below died with r(601) after
* Section 2 had already succeeded. Guard the whole legacy branch instead.
tempfile legacy_clean
if `legacy_started' == 0 {
    global legacy_available 0
    di as err "======================================================="
    di as err "NO LEGACY FILES FOUND FOR ANY YEAR 2004-2014."
    di as err "Continuing with the 2015+ crash-level data ONLY."
    di as err "The saved panel will NOT cover 2004-2014, and its"
    di as err "filename will reflect the narrower range."
    di as err "unknown_injuries and property_damage will be entirely"
    di as err "missing, since both are legacy-only fields."
    di as err "======================================================="
}
else {
    global legacy_available 1
    use `legacy', clear

    * Iowa numbers its counties alphabetically 1-99, and Iowa county FIPS
    * codes are the odd numbers assigned in that same alphabetical order,
    * so county n maps to FIPS 19 + (2n-1). This is VERIFIED against
    * county_name in Section 5 below rather than taken on trust.
    gen fips = "19" + string(2*county_num - 1, "%03.0f")
    assert length(fips) == 5

    gen state_letter_code = "IA"
    gen data_source = "legacy_county_aggregate"

    isid fips year

    save `legacy_clean', replace
}

*---------------------------------------------------------------
* SECTION 4: APPEND THE TWO PERIODS
*---------------------------------------------------------------

use `crashlevel', clear

if $legacy_available == 1 {
    append using `legacy_clean'

    * variables that exist on only one side of the 2015 seam stay missing
    * on the other side; this confirms they were not silently zero-filled
    tab data_source, missing
    count if missing(unknown_injuries) & data_source == "legacy_county_aggregate"
    assert r(N) == 0
    count if !missing(unknown_injuries) & data_source == "crash_level"
    assert r(N) == 0
    count if !missing(unknown_severity_collision) & data_source == "legacy_county_aggregate"
    assert r(N) == 0

    * n_duplicate_flagged is crash-level-only by construction (see 09/04/2026 changelog entry);
    * it must be missing, not zero, on the legacy side
    count if !missing(n_duplicate_flagged) & data_source == "legacy_county_aggregate"
    assert r(N) == 0
    count if missing(n_duplicate_flagged) & data_source == "crash_level"
    assert r(N) == 0
}
else {
    * CHANGE (09/04/2026): no legacy data, so the legacy-only
    * fields were never created. Create them as ALL MISSING here, after
    * the collapse, so the checks and labels in Section 6 still work.
    * Doing this after the collapse is what makes it safe -- the original
    * reason for not generating them was to stop collapse(sum) turning an
    * all-missing column into a column of zeros.
    gen unknown_injuries = .
    gen property_damage  = .
    label var unknown_injuries "Unknown-severity injuries (NO DATA - legacy files absent)"
    label var property_damage  "Property damage (NO DATA - legacy files absent)"
    tab data_source, missing
}

isid fips year

*---------------------------------------------------------------
* SECTION 5: MERGE COUNTY IDENTIFIERS
*---------------------------------------------------------------

merge m:1 state_letter_code fips using ///
    "$path/dataSTATA/state_county_identifiers.dta", keep(1 3)

* CHANGE (09/04/2026): assert, not count. An unmatched fips was
* previously dropped without comment by the `drop if county_name == ""'
* below, and the file still saved.
count if _merge == 1
assert _merge == 3
drop _merge

* retained as a second line of defence; should now be a no-op
drop if county_name == ""

* --- verify the legacy county-number -> FIPS crosswalk --------------
* If Iowa's county numbering really is alphabetical, then sorting the
* merged county names within a legacy year must reproduce county_num
* exactly. A failure here means the 2n-1 mapping is wrong and every
* pre-2015 row is attributed to the wrong county.
preserve
    keep if data_source == "legacy_county_aggregate"
    if _N > 0 {
        bysort year (county_name): gen alpha_rank = _n
        count if alpha_rank != county_num
        if r(N) > 0 {
            list year county_num county_name alpha_rank ///
                if alpha_rank != county_num, sepby(year)
            display as error "CROSSWALK CHECK FAILED: county_num does not match alphabetical order."
            display as error "Do not use the pre-2015 rows until this is resolved."
            exit 459
        }
        display as text "Crosswalk check passed: county_num matches alphabetical order of county_name."
    }
restore

* county_num only exists if the legacy section ran; it is created off the
* 99-county skeleton there and never in the crash-level branch
cap drop county_num

*---------------------------------------------------------------
* SECTION 6: CHECKS AND FINAL SAVE
*---------------------------------------------------------------

* no negative counts anywhere
foreach v of varlist total_all_cause fatal_collision ///
    major_injury_collision minor_injury_collision poss_unknown_collision ///
    possible_collision unknown_severity_collision pdo_collision ///
    injury_collision total_fatalities major_injuries minor_injuries ///
    total_injuries unknown_injuries property_damage animal_collision ///
    fatal_animal_collision major_injury_animal_collision ///
    minor_injury_animal_collision poss_unknown_animal_collision ///
    pdo_animal injury_animal_collision animal_fatalities ///
    animal_major_injuries animal_minor_injuries animal_injuries {
    assert `v' >= 0 if !missing(`v')
}

* severity categories reconcile in both periods
assert fatal_collision ///
       + major_injury_collision ///
       + minor_injury_collision ///
       + poss_unknown_collision ///
       + pdo_collision == total_all_cause if !missing(total_all_cause)

* animal collisions never exceed all-cause collisions
assert animal_collision <= total_all_cause ///
    if !missing(animal_collision) & !missing(total_all_cause)

* panel structure: 99 counties every year, and eyeball the seam
tab year data_source
bysort year: gen n_counties = _N
assert n_counties == 99
drop n_counties

* CHANGE (09/04/2026): was
*   table year, statistic(sum total_all_cause) statistic(sum animal_collision)
* statistic() requires Stata 17; this server runs 16.1, so that line
* failed with r(198) as the last command before the save. Replaced with
* a preserve/collapse block that works in any version AND prints the
* animal share, which is the number that actually matters for judging
* whether the two sources are comparable across the 2015 seam.
preserve
    collapse (sum) total_all_cause animal_collision, by(year data_source)
    gen animal_share = 100 * animal_collision / total_all_cause
    format animal_share %5.1f
    format total_all_cause animal_collision %12.0gc
    label var animal_share "animal % of all-cause"
    di as txt ""
    di as txt "ANNUAL TOTALS AND ANIMAL SHARE - CHECK THE 2014/2015 SEAM"
    di as txt "A jump in animal_share at 2015 means the legacy and"
    di as txt "crash-level sources are not measuring the same thing."
    list year data_source total_all_cause animal_collision animal_share, ///
        noobs sepby(data_source) abbrev(16)
restore

label var total_all_cause        "All-cause collisions"
label var animal_collision       "Animal-related collisions"
label var poss_unknown_collision "Possible + unknown severity collisions (comparable across 2015)"
label var unknown_injuries       "Unknown-severity injuries (2004-2014 only)"
label var property_damage        "Property damage, dollars (2004-2014 only)"
label var data_source            "Which source the county-year row came from"
label var n_duplicate_flagged    "Crash rows flagged as exact duplicates (2015+ only)"

sort county_name year, stable
order state_letter_code ///
      state_name ///
      county_name ///
      state_fips ///
      county_fips ///
      fips ///
      year ///
      data_source ///
      total_all_cause ///
      total_fatalities ///
      total_injuries ///
      major_injuries ///
      minor_injuries ///
      unknown_injuries ///
      property_damage ///
      fatal_collision ///
      major_injury_collision ///
      minor_injury_collision ///
      poss_unknown_collision ///
      possible_collision ///
      unknown_severity_collision ///
      injury_collision ///
      pdo_collision ///
      animal_collision ///
      fatal_animal_collision ///
      major_injury_animal_collision ///
      minor_injury_animal_collision ///
      poss_unknown_animal_collision ///
      possible_animal_collision ///
      unknown_severity_animal_coll ///
      injury_animal_collision ///
      pdo_animal ///
      animal_fatalities ///
      animal_major_injuries ///
      animal_minor_injuries ///
      animal_injuries ///
      n_duplicate_flagged

qui summ year
local t1 = `r(min)'
local t2 = `r(max)'

compress
save "$working_data/dvcs_IA_county_year_`t1'_`t2'.dta", replace

di as txt "Saved: $working_data/dvcs_IA_county_year_`t1'_`t2'.dta"
cap log close
