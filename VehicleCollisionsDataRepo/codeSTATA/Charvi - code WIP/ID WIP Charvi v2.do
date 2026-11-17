/*******************************************************************************
Program: data_dvcs_county_year.do
Current Lead:  Charvi Khandelwal
Major Versions/Revisions:
07/01/2020 [Siyue Ouyang]: created
07/08/2020 [Siyue Ouyang]: code style change
07/13/2020 [Siyue Ouyang]: add more states
07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
07/26/2020 [Siyue Ouyang]: add data in ~dataRAW, update
11/19/2021 [Kaveri Chhikara]: Changed code file to include new data
08/25/2026 [Charvi Khandelwal]: added impairment flags, restructured to AZ code style
08/26/2026 [Charvi Khandelwal]: AZ parity on severity and alcohol, flagged AccdEvent truncation
08/27/2026 [Charvi Khandelwal]: extended data to 2025, removed covid flag
09/01/2026 [Charvi Khandelwal]: pinned V:Y columns, DUI netting on union measures, verified sources
09/01/2026 [Charvi Khandelwal - code review]: setup, path handling, sheet-name
  quoting, crosswalk join and logging fixes so the file runs end to end. No
  analytical logic, variable definition, source cut or assert was altered
09/15/2026 [Charvi Khandelwal]: acted on the review comments. Dropped write_cache,
  the condition and behaviour dummies and the no_dui series; renamed the animal
  families to animal, wild_animal and non_wild_animal (NOTE 5)
09/17/2026 [Charvi Khandelwal]: first full run. Fixed a 32-character name-length
  error in the section 3B flatten; corrected the coverage claim, since 25
  county-years do fail the 0.99 threshold and are blanked (NOTE 4); moved the
  standing data notes into the block below
*******************************************************************************/

/*******************************************************************************
DATA NOTES - READ BEFORE USING THE PANEL

Output: one file, dataSTATA/dvcs_ID_county_year_1997_2025.dta, 44 Idaho
counties by 29 years. Everything below is a standing property of the ID data
rather than a description of the code, verified on the current delivery. The
body refers back to these by number.

1. TWO DELIVERIES, CUT AT 2018/2019. 1997-2018 comes from four legacy exports
   keyed on fldAccidentID, at four levels of aggregation:
     AccdMain              one row per crash   (severity, county, year)
     AccdEvent             one row per event   (what the vehicle struck)
     AccdUnit_ContribCirc  one row per unit    (why the crash happened)
     AccdPerson_Injury     one row per person  (NOT USED, see NOTE 3)
   2019-2025 comes from seven annual UofChicago_YYYY.xlsx exports, each a
   person-level report carrying in one file what the legacy delivery split
   across three. Sections 1-3 flatten the legacy files to crash level and
   section 3B does the same for the annual ones, then appends.

   The cut is at 2018 because AccdEvent is truncated from mid-2019 (NOTE 2).
   Moving 2019 back to the legacy side was considered and rejected: AccdEvent
   reaches only 64.72% of 2019 crashes, so legacy 2019 would carry no animal
   series at all rather than a slightly worse one. If it is ever wanted for a
   non-animal purpose it is a two-line edit to the locals in section 0.

   The deliveries disagree slightly on the overlap years. The annual export has
   27,255 crashes in 2019 against the legacy 27,136, and 22,835 in 2020 against
   22,637: +0.4% and +0.9%, consistent with late-reported crashes added after
   the November 2021 legacy pull. Section 3B prints the comparison so the size
   of the seam stays visible.

2. THREE TRUNCATED LEGACY EXPORTS, THREE DIFFERENT SHAPES. Each is clipped at
   Excel's ceiling of 1,048,575 rows, and each is clipped differently. Do not
   infer one file's coverage from another's.
     AccdEvent             reaches 563,065 of 595,514 crashes. CHRONOLOGICAL:
                           at or above 99.87% for 1997-2017, 99.40% in 2018,
                           64.72% in 2019 and ZERO in 2020, where not one crash
                           has an event record
     AccdUnit_ContribCirc  reaches 593,773 (99.71%). SCATTERED, because the
                           file is sorted by fldUnitID and the rows lost are
                           those with the highest unit ids: 2001 loses 1.88%,
                           2005 1.63%, 2016 1.07%, every other year under
                           0.31%. Section 5 codes unmatched crashes as zero, so
                           circumstance counts are slightly understated in
                           those three years
     AccdPerson_Injury     reaches 411,243 (69.1%). NEAR-UNIFORM at roughly a
                           third missing in every year, 27.3% in 2003 to 34.3%
                           in 1997
   Because a crash with no event record reads as "no animal strike", the animal
   series from AccdEvent is understated by about a third in 2019 and is
   identically zero across all counties in 2020. That is the whole reason for
   the source cut. Figures verified 09/01/2026 against the workbooks; note the
   denominator when quoting the 2019 number, 64.72% against the legacy count of
   27,136 and 64.44% against the annual export's 27,255.

3. NO PERSON-LEVEL INJURY VARIABLES. AccdPerson_Injury would give the KABCO
   detail that crash-level severity cannot: how many people sustained a serious
   injury, not just how many crashes had one. With 31% of crashes missing,
   coding the remainder as zero is indefensible, and any county-year count
   would understate by roughly a third, unevenly across counties. Summing its
   fatal-injury persons gives 3,984 against 5,754 fatalities in AccdMain, the
   same shortfall from the other direction. Section 4 reports coverage and
   builds nothing, and the report is off by default because it costs a full
   pass over a million-row workbook.

   To use it, re-request the export split across sheets or as CSV so it is not
   truncated, then flatten to crash level with a collapse (sum) of indicators
   per injury name and merge in section 5. 63 rows carry a BLANK injury name
   and would need a decision, drop or treat as unknown. This is only needed for
   1997-2018 now: the annual exports carry an Injury Type column that
   reproduces Number Of Fatalities EXACTLY in all seven years.

4. COVERAGE IS TESTED PER COUNTY-YEAR, NOT STATEWIDE, and the two are not the
   same. Every percentage in NOTE 2 is one number for the whole state.
   animal_data_usable in section 5 tests each county-year against 0.99, and a
   small county can fall well below it in a year the state clears comfortably.
   Measured 09/15/2026: 25 county-year cells fail, in 2002 and 2014-2018, the
   worst at 0.6714 in 2018 against a statewide 99.40% that year.

   Those cells have their animal variables set to MISSING, not zero, because
   the count is unknown rather than low. A count near 25 in those same years is
   the known state of the data; a materially larger count, or any cell from
   2019 on, means a delivery has been truncated the way AccdEvent was.

5. ANIMAL NAMING. Three families, and only three:
     animal_            ANY animal involvement: the event side (a vehicle
                        struck an animal) OR the circumstance side (an animal
                        in the roadway contributed). This is the union measure,
                        and it is the family that matches animal_collision in
                        the other state files, so cross-state work uses it
     wild_animal_       the "Animal - Wild" event code. Subset of animal_
     non_wild_animal_   the "Animal - Domestic" event code. Subset of animal_

   THE SPECIES FAMILIES DO NOT PARTITION animal_. A crash can carry both a wild
   and a domestic strike and is counted in both, and a circumstance-only crash
   records no species at all and so appears in animal_ alone. Do not expect
   wild plus non_wild to equal animal at county-year level.

   Before 09/15/2026 this file exported the event side as animal_, the
   circumstance side as animal_circ_ and the union as animal_any_, which meant
   ID's animal_collision measured something narrower than the same-named
   variable in every other state, and an append or a cross-state regression
   would have treated the two as one series. The union now carries the name and
   the event side is reported as its two species codes. That is where
   "non_wild" comes from: it is the domestic event code, not "animal minus
   wild". The two inputs are built in sections 2 and 3B as intermediates and
   dropped in section 5 once the union exists.

   The event and circumstance sides do not agree, and the disagreement is
   informative rather than a bug: a swerve ending in a rollover with no strike
   is a circumstance and not an event, and a strike the officer did not treat
   as causal is the reverse. Taking the union keeps both.

6. SEVERITY MAPS ONTO AZ BY POOLING. ID reports five KABCO categories; AZ
   reports a numeric code where 4 is major injury and 2 and 3 are both folded
   into minor. B and C injuries are therefore pooled into
   minor_injury_collision the way AZ pools 2 and 3. possible_injury_collision
   then carries the C injuries on their own as an ID-only detail, so it is a
   SUBSET of minor, not a sibling; B alone is minor minus possible.

7. THERE IS NO COMBINED ALCOHOL-OR-DRUG CODE. ID writes impairment as two
   independent circumstances and a unit can carry both, so matching a single
   combined string would return nothing. alcohol_collision and drug_collision
   are matched separately and OR'd into dui_collision. alcohol_collision is the
   AZ-comparable series and dui_collision is the ID superset.

   The animal-by-impairment interactions are carried for all three animal
   families, so a DVC count can be netted of impaired drivers by subtraction in
   the analysis file, e.g. animal_collision - dui_animal_collision.

8. FIELDS PRESENT AND NOT BUILT. urban is populated on 99.99% of 2019-2025
   crashes, but the legacy urbantype is missing on 91.5% of rows, so an urban
   share is available from 2019 forward and cannot be carried back. injurytype
   is covered in NOTE 3. Both would need the same treatment: build them here,
   leave them missing for 1997-2018, and document the coverage break the way
   animal_data_usable is documented.

9. 2020 IS AN ORDINARY PANEL YEAR and there is deliberately no covid
   indicator. 2020 is complete in the data, all twelve months with crashes
   through 31 December, and the low all-cause count is the pandemic itself
   rather than a coverage gap. No other state file in this repo carries such a
   flag, and it is only ever (year == 2020) if an analysis wants it.

EDITING CAUTION: do not write an asterisk immediately followed by a forward
slash anywhere in this block, including when naming variable wildcards. That
sequence closes the comment and Stata parses the rest of the documentation as
commands.
*******************************************************************************/
/**********************************************************************/
/*-----------------SECTION 0: root directory --------------*/

cap log close _all
clear all
set more off, permanently
set scheme s1mono

* The legacy workbooks are large: AccdMain is ~600k rows and AccdEvent,
* AccdUnit_ContribCirc and AccdPerson_Injury all sit at 1,048,575 rows. The
* seven annual exports are ~70k rows each and do not need this, but the setting
* is global. Without it, import excel can fail or silently run out of room
set excelxlsxlargefile on

* To run from a location not listed here, set the global before the do-file:
*   global rootDir "/your/path/Research"
if "$rootDir" == "" {
  foreach d in /mnt/data_d/Dropbox/Research ///
               C:/Dropbox/Research          ///
               D:/Dropbox/Research {
    if "$rootDir" == "" {
      local dirok = 0
      mata: st_local("dirok", strofreal(direxists("`d'")))
      if `dirok' == 1 {
        global rootDir "`d'"
      }
    }
  }
}

if "$rootDir" == "" {
  di as error "No research directory found. Checked:"
  di as error "  /mnt/data_d/Dropbox/Research"
  di as error "  C:/Dropbox/Research"
  di as error "  D:/Dropbox/Research"
  di as error `"Set it by hand first:  global rootDir "/your/path/Research""'
  error 601
}

global path "$rootDir/VehicleCollisionsDataRepo"
global working_data "$path/dataSTATA"

global raw "$path/dataRAW/DVCs/ID"

di as text "Research directory: $rootDir"

local pathok = 0
mata: st_local("pathok", strofreal(direxists("$path")))
if `pathok' == 0 {
  di as error "$path does not exist."
  di as error "rootDir resolved to $rootDir but it holds no VehicleCollisionsDataRepo."
  error 601
}

cap mkdir "$working_data"
log using "$working_data/dvcs_ID_build.log", replace text

* Set to 0 to skip the AccdPerson_Injury coverage report in section 4. It costs
* one full pass over a 1m row workbook and produces no variables
local check_person_injury = 0

* collapse writes "(sum) x" or "(max) x" as the variable label of everything it
* touches. Those artefacts then head every tab and tabstat for the rest of the
* run and travel into the delivered dta, so each of the three collapses below
* is followed by a call to this
*
* Matched on the prefix rather than cleared wholesale, so that the labels the
* crosswalk supplies for state_name and the FIPS columns survive section 6
capture program drop strip_collapse_labels
program define strip_collapse_labels
    foreach v of varlist _all {
        local lbl : variable label `v'
        if substr("`lbl'", 1, 6) == "(sum) " | substr("`lbl'", 1, 6) == "(max) " {
            label var `v' ""
        }
    }
end

* The panel is built from two deliveries, cut at 2018/2019; see NOTE 1. The
* boundary lives here rather than hardcoded in three places, so moving it is a
* two-line edit: the section 3B seam checks and the section 5 coverage guard
* are both written against these locals
local legacy_end_year = 2018
local new_start_year  = 2019
local new_end_year    = 2025

* The last year the LEGACY delivery covers, as distinct from the last year this
* run takes from it. Used by the seam report in section 3B
local legacy_file_last_year = 2020


/*-----------------SECTION 0B: resolve inputs before reading any of them -----*/

* The crosswalk path differs between this file (dataSTATA/_AUX/) and the IA and
* CT files in this repo (dataSTATA/), so both are checked and whichever exists
* is used
local xw_aux  "$path/dataSTATA/_AUX/state_county_identifiers.dta"
local xw_flat "$path/dataSTATA/state_county_identifiers.dta"
global xwalk ""
capture confirm file "`xw_aux'"
if _rc == 0 {
    global xwalk "`xw_aux'"
}
if "$xwalk" == "" {
    capture confirm file "`xw_flat'"
    if _rc == 0 {
        global xwalk "`xw_flat'"
    }
}
if "$xwalk" == "" {
    di as error "state_county_identifiers.dta not found at either:"
    di as error "  `xw_aux'"
    di as error "  `xw_flat'"
    error 601
}
di as text "County crosswalk: $xwalk"

local missing_inputs = 0

foreach f in AccdMain AccdEvent AccdUnit_ContribCirc {
    capture confirm file "$raw/`f'.xlsx"
    if _rc != 0 {
        di as error "MISSING: $raw/`f'.xlsx"
        local missing_inputs = 1
    }
    else {
        di as text "  ok: `f'.xlsx"
    }
}

if `check_person_injury' == 1 {
    capture confirm file "$raw/AccdPerson_Injury.xlsx"
    if _rc != 0 {
        di as error "MISSING: $path/dataRAW/DVCs/ID/AccdPerson_Injury.xlsx"
        di as error "  (or set check_person_injury to 0 in section 0)"
        local missing_inputs = 1
    }
}

* The annual exports are located by pattern as well as by exact name, because
* the folder spells them with a space rather than an underscore in some years
*
* Whatever is found is stored in $annual_YYYY and section 3B reads it from
* there, so the name appears in exactly one place
di as text "Annual exports:"
forvalues yr = `new_start_year'/`new_end_year' {

    global annual_`yr' ""

    * Named candidates, tried in order. The underscore form is what the code
    * was originally written against; the space form is what the ID folder
    * actually holds, which the first run of the pattern search discovered.
    * Both are listed so neither spelling needs the fallback below
    local cand1 "UofChicago_`yr'.xlsx"
    local cand2 "UofChicago `yr'.xlsx"

    forvalues k = 1/2 {
        if "${annual_`yr'}" == "" {
            capture confirm file "$raw/`cand`k''"
            if _rc == 0 {
                global annual_`yr' "$raw/`cand`k''"
                di as text "  `yr': `cand`k''"
            }
        }
    }

    * Fallback: anything with the year in its name
    if "${annual_`yr'}" == "" {

        local hits : dir "$raw" files "*`yr'*.xls*"

        * Drop editor lock and temp files before counting: LibreOffice writes
        * ".~lock.<name>#" and Excel writes "~$<name>" next to an open
        * workbook, and neither is a spreadsheet
        local clean ""
        foreach h of local hits {
            if substr("`h'", 1, 1) != "." & substr("`h'", 1, 2) != "~$" {
                local clean `"`clean' "`h'""'
            }
        }
        local nhits : word count `clean'

        if `nhits' == 1 {
            local hit : word 1 of `clean'
            global annual_`yr' "$raw/`hit'"
            di as text "  `yr': matched by pattern -> `hit'"
        }
        else if `nhits' == 0 {
            di as error "  `yr': nothing in $raw has `yr' in its name"
            local missing_inputs = 1
        }
        else {
            * refusing to guess is the right behaviour here. Picking one of
            * several candidates silently is how a panel ends up built from a
            * superseded export that nobody remembers dropping in the folder
            di as error "  `yr': `nhits' candidates, cannot choose between them:"
            foreach h of local clean {
                di as error "        `h'"
            }
            di as error `"        set it by hand, before the do-file:"'
            di as error `"        global annual_`yr' "$raw/<filename>.xlsx""'
            local missing_inputs = 1
        }
    }
}

if `missing_inputs' == 1 {

    di as error _newline "Contents of $raw:"
    capture noisily dir "$raw"

    di as error _newline "One or more required inputs are missing. Nothing has been read yet."
    di as error "If a file above is the one that is wanted, either rename it to"
    di as error "the expected name or set its global by hand before the do-file."
    error 601
}

di as text "All required inputs located. Starting the build."


/*-----------------SECTION 1: crash records, 1997-2018 --------------*/


/* [> crash record level data <] */

* The four legacy files and what each one holds are listed in NOTE 1.
*
* Everything from here to the end of section 3 is LEGACY YEARS ONLY. The full
* AccdMain id list is saved before the year restriction below, so the orphan
* checks in sections 2, 3 and 3B run against every crash the state has ever
* reported rather than only the ones this run keeps

clear
local file_name = "$raw/AccdMain.xlsx"
import excel using "`file_name'" , describe
* Sheet name captured and quoted: r(worksheet_1) unquoted is a syntax error the
* moment a sheet name contains a space
local sheet_name = "`r(worksheet_1)'"
import excel using "`file_name'", allstring sheet("`sheet_name'") firstrow case(lower) clear

* Most of AccdMain's twenty columns are dropped deliberately rather than by
* oversight: isreportable is the constant "Y" on all 595,514 rows, urbantype is
* missing on 91.5% (NOTE 8), the coordinates do not aggregate to county-year,
* and month, light condition, road surface and weather only ever fed the
* condition dummies dropped on 09/15/2026
keep fldaccidentid ///
     fldaccidentyyyy ///
     fldcountyname ///
     severityname ///
     fldfatalities ///
     fldinjuries ///
     fldpersons

rename fldaccidentyyyy year
rename fldcountyname county_name
rename severityname severity
rename fldfatalities total_fatalities
rename fldinjuries total_injuries
rename fldpersons total_persons

* ignore(",") mirrors the AZ file. None of these three currently arrive with a
* thousands separator, but a later delivery formatted in Excel would, and
* destring errors out rather than warning when it hits one
destring year, replace ignore(",")
destring total_fatalities, replace ignore(",")
destring total_injuries, replace ignore(",")
destring total_persons, replace ignore(",")

* Set here rather than in section 7, so that the tabs and tabstats between here
* and the save stop heading the column "fldAccidentYYYY". year is the by()
* variable on the section 5 collapse, so this label survives it
label var year "Crash year"

* One row per crash is what everything downstream assumes, so verify it
* here rather than discovering a duplicate after three merges
isid fldaccidentid

* Every crash in the legacy delivery with its year, saved BEFORE the year
* restriction below. The merges in sections 2, 3 and 3B check against this,
* which is what lets "an event record with no parent crash" stay a hard error
* rather than becoming indistinguishable from "an event record for a year this
* run takes from the other source"
preserve
    keep fldaccidentid year
    tempfile all_crash_ids
    save `all_crash_ids', replace    
restore

di as text "Legacy AccdMain crash counts by year, before the source cut:"
tab year

* The legacy file runs to 2020 but 2019 and 2020 are dropped here and taken
* from the annual exports instead. Dropping rather than keeping both and
* de-duplicating, because the two sources disagree slightly on the overlap
* years (see the note in section 0) and a de-duplication would silently pick
* one row per crash without recording which delivery it came from
qui count
local n_legacy_all = r(N)
keep if year <= `legacy_end_year'
qui count
di as text "Legacy crashes kept (year <= `legacy_end_year'): `r(N)' of `n_legacy_all'"

gen byte source_new_export = 0

tempfile main
save `main', replace


/*-----------------SECTION 2: animal event flags --------------*/


/* [> what the vehicle struck, one row per event <] */

* AccdEvent is the chronologically truncated export of NOTE 2, and its clip is
* why the source cut sits at 2018. The coverage measurement and blanking in
* section 5 are KEPT rather than deleted: they are what makes a future
* truncation visible instead of silent (NOTE 4)
*
* A single crash can carry more than one animal event, a domestic and a wild
* strike in the same collision, so this is collapsed to crash level with (max)
* before it goes anywhere near the main file

clear
local file_name = "$raw/AccdEvent.xlsx"
import excel using "`file_name'" , describe
local sheet_name = "`r(worksheet_1)'"
import excel using "`file_name'", allstring sheet("`sheet_name'") firstrow case(lower) clear

keep fldaccidentid eventcodename fldeventorder

* Every crash that appears in the event file at all, animal or not. This is
* what makes the truncation measurable downstream: without it, a crash that
* is missing from the export is indistinguishable from a crash that was
* recorded as involving no animal
preserve
    keep fldaccidentid
    duplicates drop fldaccidentid, force
    gen has_event_record = 1

    * Restricted to the legacy years, so that the 1:1 merge in section 5 has no
    * using-only rows and its assert can stay as it was. The orphan check runs
    * first and against the unrestricted id list, so an event record for a
    * crash that AccdMain never reported is still a hard error
    merge 1:1 fldaccidentid using `all_crash_ids', keepusing(year)
    count if _merge == 1
    assert r(N) == 0
    keep if _merge == 3 & year <= `legacy_end_year'
    drop _merge year

    tempfile event_coverage
    save `event_coverage', replace
restore

keep if eventcodename == "Animal - Domestic" | eventcodename == "Animal - Wild"

destring fldeventorder, replace ignore(",")

* THE TWO SPECIES FAMILIES OF NOTE 5 COME FROM HERE. "Animal - Wild" and
* "Animal - Domestic" are the only two animal codes among the 66 distinct
* EventCodeName values, and the assert below is what keeps that true on the
* next delivery. animal_event_collision is the intermediate that section 5 ORs
* with the circumstance flag to build the animal family, then drops
gen animal_event_collision = 1
gen wild_animal_collision = (eventcodename == "Animal - Wild")
gen non_wild_animal_collision = (eventcodename == "Animal - Domestic")

assert wild_animal_collision + non_wild_animal_collision == 1

* fldeventorder == 1 means the animal was the first harmful event rather than
* something struck after the driver had already lost control. 29,227 of the
* 29,536 animal crashes in the full legacy export are order 1
gen animal_first_collision = (fldeventorder == 1)
gen wild_animal_first_collision = (fldeventorder == 1 & wild_animal_collision == 1)
gen non_wild_animal_first_coll = (fldeventorder == 1 & non_wild_animal_collision == 1)

drop eventcodename fldeventorder

collapse (max) animal_event_collision ///
               wild_animal_collision ///
               non_wild_animal_collision ///
               animal_first_collision ///
               wild_animal_first_collision ///
               non_wild_animal_first_coll, ///
               by(fldaccidentid)

strip_collapse_labels

* Same pattern as event_coverage above: orphan check against every crash the
* legacy delivery reported, then keep the legacy years only
merge 1:1 fldaccidentid using `all_crash_ids', keepusing(year)
count if _merge == 1
assert r(N) == 0
keep if _merge == 3 & year <= `legacy_end_year'
drop _merge year

tempfile animal_flags
save `animal_flags', replace


/*-----------------SECTION 3: circumstance flags --------------*/


/* [> contributing circumstances, one row per unit <] */

* Unit-level, roughly 1.77 units per crash, and a circumstance can be coded in
* ANY of the three fields, so all three are checked and (max) flags the crash
* if any of its units was flagged. This is the scattered truncation of NOTE 2:
* unmatched crashes are coded zero in section 5, so these counts are slightly
* understated in 2001, 2005 and 2016

clear
local file_name = "$raw/AccdUnit_ContribCirc.xlsx"
import excel using "`file_name'" , describe
local sheet_name = "`r(worksheet_1)'"
import excel using "`file_name'", allstring sheet("`sheet_name'") firstrow case(lower) clear

keep fldaccidentid ///
     fldcontributingcircumstance1 ///
     fldcontributingcircumstance2 ///
     fldcontributingcircumstance3

gen alcohol_collision = 0
gen drug_collision = 0
gen animal_circ_collision = 0

* An unused circumstance slot holds the literal string "None", not a blank,
* and it is the most common value in all three columns. Exact-equality matching
* handles that; anything reasoning about these columns with missing() will
* conclude they are almost always populated and be wrong about it
*
* ONE CODE IS MOJIBAKED IN THE ANNUAL EXPORTS AND CLEAN HERE: "Emotional [en
* dash] Depressed, Angry, Disturbed". Nothing below matches it, so no current
* variable is affected, but a flag added later must match it on a substring or
* it will silently pick up one era and not the other. The two vocabularies
* otherwise share 39 codes and differ only in "Fatigued", legacy-only and no
* longer read
*
* The strings below are exact. Only the three codes that feed a panel variable
* are matched; drowsy, distracted and speeding were dropped on 09/15/2026
forvalues circumstance = 1(1)3 {
    replace alcohol_collision = 1 ///
        if strtrim(fldcontributingcircumstance`circumstance') == "Alcohol Impaired"
    replace drug_collision = 1 ///
        if strtrim(fldcontributingcircumstance`circumstance') == "Drug Impaired"
    replace animal_circ_collision = 1 ///
        if strtrim(fldcontributingcircumstance`circumstance') == "Animal(s) in Roadway"
}

drop fldcontributingcircumstance*

collapse (max) alcohol_collision ///
               drug_collision ///
               animal_circ_collision, ///
               by(fldaccidentid)

strip_collapse_labels

* Impaired driving of any kind. Kept as its own variable because the AZ file
* has a single alcohol flag and no drug flag, so alcohol_collision is the
* cross-state comparable series and dui_collision is the ID superset
gen dui_collision = (alcohol_collision == 1 | drug_collision == 1)

* Legacy years only, orphan check first, as in section 2
merge 1:1 fldaccidentid using `all_crash_ids', keepusing(year)
count if _merge == 1
assert r(N) == 0
keep if _merge == 3 & year <= `legacy_end_year'
drop _merge year

tempfile circumstance_flags
save `circumstance_flags', replace


/*-----------------SECTION 3B: crash records, 2019-2025 --------------*/


/* [> the annual UofChicago exports, one flat file per year <] */

* Seven workbooks, one per year, each a person-level report of about 70,000
* rows and 28 columns. NOTE 1 lists what they replace.
*
* Rows are person level, 2.48 per crash on average and up to 61, and each
* person's row repeats their UNIT's events and circumstances. So the flags are
* built at row level and maxed up to the crash exactly as the legacy unit and
* event files are, and the crash attributes, which repeat identically on every
* row, are asserted constant below rather than assumed
*
* Event coverage is what makes these usable where legacy 2019 and 2020 were
* not: an Events or Most Harmful Event value is present for 99.94% of 2019
* crashes, 99.98% of 2020 and 100.00% of 2021-2025

* Five preamble rows sit above the header in every workbook, hence
* cellrange(A6). The sheet name carries a space ("UofChicago 2019"), so
* r(worksheet_1) is passed in double quotes; unquoted it splits on the space
* and errors, which is why this differs from sections 1-3
*
* U IS KEPT ALONGSIDE V DELIBERATELY AND IS NOT OPTIONAL. V is the tidier
* column but holds only the MOST HARMFUL event, so an animal struck in a crash
* whose worst event was something else does not appear in it. Dropping U loses
* 109 animal crashes in 2019, 78 in 2020, then 88, 63, 54, 40 and 44 in
* 2021-2025, i.e. 2.0-6.2% of the event-based count every year. The legacy side
* counts an animal at ANY event position, so V-only here would put a 2-6% step
* in animal_collision exactly at the 2018/2019 seam

local first_year_processed = 1
tempfile new_crashes

* Flags built at row level and maxed up to the crash. Listed once here so that
* a flag added below cannot be left out of the flatten and end up carrying an
* arbitrary row's value into the panel
local rowflags animal_event_collision      ///
               wild_animal_collision       ///
               non_wild_animal_collision   ///
               animal_first_collision      ///
               wild_animal_first_collision ///
               non_wild_animal_first_coll  ///
               has_event_record            ///
               alcohol_collision           ///
               drug_collision              ///
               animal_circ_collision

* Crash attributes, which must be constant within a crash
local crashvars year county_name severity total_fatalities ///
                total_injuries total_persons

forvalues yr = `new_start_year'/`new_end_year' {

    di as text _newline "==== Processing UofChicago_`yr'.xlsx ===="

    clear
    local file_name = "${annual_`yr'}"
    import excel using "`file_name'" , describe
    local sheet_name = "`r(worksheet_1)'"

    * The header row is read on its own first, WITHOUT firstrow, so the
    * variables are named for their Excel column letters and the layout can be
    * checked by position. The name check below catches a RENAMED column; this
    * catches a MOVED one, which the name check cannot see. Worth having
    * because the animal and impairment definitions are specified by column
    * letter, so a column inserted upstream of U would shift all five without
    * changing a single header string
    import excel using "`file_name'", allstring sheet("`sheet_name'") ///
        cellrange(A6:AB6) clear

    local col_P "AccidentID"
    local col_U "Events"
    local col_V "Most Harmful Event"
    local col_W "Contrib Circ 1"
    local col_X "Contrib Circ 2"
    local col_Y "Contrib Circ 3"

    foreach L in P U V W X Y {
        local found = strtrim(`L'[1])
        if "`found'" != "`col_`L''" {
            di as error "UofChicago_`yr'.xlsx: column `L' header is `found'"
            di as error "but `col_`L'' was expected. The sheet layout has changed."
            di as error "Animal and impairment flags are defined on U:Y, so do not"
            di as error "run this file until the mapping is re-checked by hand."
            error 459
        }
    }

    import excel using "`file_name'", allstring sheet("`sheet_name'") ///
        cellrange(A6) firstrow case(lower) clear

    * import excel derives names from the header text, so a renamed column in a
    * future delivery would otherwise surface as a missing variable twenty
    * lines later. Failing here names the file and the column instead
    foreach v in accidentid accidentyear county severity                   ///
                 numberoffatalities numberofinjuries numberofpersons       ///
                 events mostharmfulevent contribcirc1 contribcirc2         ///
                 contribcirc3 {
        capture confirm variable `v'
        if _rc != 0 {
            di as error "UofChicago_`yr'.xlsx: expected column `v' not found."
            di as error "Check the header row and the Fields: line at the top of the sheet."
            error 111
        }
    }

    * Eleven further columns are present and dropped. They either duplicate
    * accidentyear exactly, do not aggregate to county-year, have no legacy
    * counterpart to append onto, or only ever fed the dropped condition
    * dummies
    keep accidentid    ///
         accidentyear  ///
         county        ///
         severity      ///
         numberoffatalities ///
         numberofinjuries   ///
         numberofpersons    ///
         events           ///
         mostharmfulevent ///
         contribcirc1 contribcirc2 contribcirc3

    rename accidentyear year
    rename county county_name
    rename numberoffatalities total_fatalities
    rename numberofinjuries total_injuries
    rename numberofpersons total_persons

    destring year, replace ignore(",")
    destring total_fatalities, replace ignore(",")
    destring total_injuries, replace ignore(",")
    destring total_persons, replace ignore(",")

    * As in section 1, so the annual-export tabs do not head it "Accident Year"
    label var year "Crash year"

    * Each workbook should contain exactly its own year and nothing else
    assert year == `yr'

    /* [> what the vehicle struck <] */

    * events is an ORDERED comma-delimited list per unit, so position in the
    * string carries the ordering that fldeventorder carried in AccdEvent
    *
    * Matched on the substring "Animal - " rather than on equality with the two
    * full codes, because one row in 2019 carries a corrupted "AniAnimal -
    * Domestic" that a strict test would silently score as no animal. No other
    * code among the 66 contains the substring
    gen byte animal_event_collision = (strpos(events, "Animal - ") > 0 | ///
                                 strpos(mostharmfulevent, "Animal - ") > 0)
    gen byte wild_animal_collision = (strpos(events, "Animal - Wild") > 0 | ///
                                 strpos(mostharmfulevent, "Animal - Wild") > 0)

    * The species split, matching the two legacy event codes. The corrupted
    * "AniAnimal - Domestic" value in 2019 still contains the full
    * "Animal - Domestic" substring, so it is caught here as well
    gen byte non_wild_animal_collision = ///
        (strpos(events, "Animal - Domestic") > 0 | ///
         strpos(mostharmfulevent, "Animal - Domestic") > 0)

    * mostharmfulevent is included in the two tests above only to catch the 21
    * crashes across 2019-2021 that have a most-harmful event but an empty
    * events list. For every other crash it is one of the events already in the
    * list, so it cannot widen the definition, only fill a hole in it

    * First element of the list, i.e. the analogue of fldeventorder == 1
    gen event_first = events
    replace event_first = substr(events, 1, strpos(events, ",") - 1) ///
        if strpos(events, ",") > 0
    replace event_first = strtrim(event_first)

    * AZ keys its animal flag on firstharmfulevent, so these three are the
    * AZ-comparable series rather than the any-position flags above
    *
    * This is the one flag whose DEFINITION changes at the seam, so it was
    * tested rather than assumed: the share of animal crashes whose first event
    * is the animal runs 98.1 to 99.3 percent across 2019-2025 against 98.95
    * percent in the whole legacy file, so the comma-list position does track
    * fldEventOrder
    gen byte animal_first_collision = (strpos(event_first, "Animal - ") > 0)
    gen byte wild_animal_first_collision = ///
        (strpos(event_first, "Animal - Wild") > 0)
    gen byte non_wild_animal_first_coll = ///
        (strpos(event_first, "Animal - Domestic") > 0)
    drop event_first

    * A crash with neither field populated has no event information at all,
    * the analogue of a crash missing from the truncated AccdEvent export. This
    * feeds event_record_coverage on the same footing as the legacy
    * has_event_record, so the coverage test is real in these years rather than
    * a tautology. Seven crashes across 2019-2025 fail it
    gen byte has_event_record = (events != "" | mostharmfulevent != "")

    drop events mostharmfulevent

    /* [> why it happened <] */

    * Same matching as section 3, including the "None" slot and the mojibake
    * warning noted there. NOTE 7 covers why alcohol and drugs are matched
    * separately rather than as one code. The standalone "Fatigued" code does
    * not appear in these exports, and neither it nor "Asleep, Drowsy,
    * Fatigued" is read any more
    gen byte alcohol_collision = 0
    gen byte drug_collision = 0
    gen byte animal_circ_collision = 0

    forvalues circumstance = 1(1)3 {
        replace alcohol_collision = 1 ///
            if strtrim(contribcirc`circumstance') == "Alcohol Impaired"
        replace drug_collision = 1 ///
            if strtrim(contribcirc`circumstance') == "Drug Impaired"
        replace animal_circ_collision = 1 ///
            if strtrim(contribcirc`circumstance') == "Animal(s) in Roadway"
    }

    drop contribcirc*

    /* [> flatten to one row per crash <] */

    * The crash attributes are carried on every row of a crash and must agree,
    * or taking the first row would be picking arbitrarily among conflicting
    * values. Currently clean in all seven files
    gen byte inconsistent = 0
    foreach v of local crashvars {
        bysort accidentid: replace inconsistent = 1 if `v' != `v'[1]
    }
    qui count if inconsistent == 1
    if r(N) > 0 {
        di as error "UofChicago_`yr'.xlsx: `r(N)' rows disagree with the first row of their crash"
        di as error "on a field that should be constant within a crash. Cannot flatten safely."
        error 459
    }
    drop inconsistent

    * (max) up to the crash, matching how sections 2 and 3 collapse the legacy
    * unit and event files: a crash is flagged if any of its rows is
    *
    * THIS IS WHAT STOPS THE DOUBLE COUNTING, and the margin is not small. The
    * same animal appears in more than one of V:Y on 17,580 of the 22,763
    * person-rows carrying any animal criterion. Each flag is a 0/1 indicator
    * per row, so (max) gives 1 either way; counting matches and summing would
    * inflate animals by about 77%
    *
    * A TEMPVAR, not a "crashmax_" prefix. Stata caps a variable name at 32
    * characters, so a nine-character prefix capped every name in the list
    * above at 23, and non_wild_animal_collision is 25
    foreach v of local rowflags {
        tempvar crashmax
        bysort accidentid: egen byte `crashmax' = max(`v')
        qui replace `v' = `crashmax'
        drop `crashmax'
    }

    bysort accidentid: keep if _n == 1
    isid accidentid

    * Generated AFTER the flatten, not before it, so that it is the crash-level
    * OR of the two crash-level flags. Built at row level and maxed instead it
    * would give the same answer here, but section 3 builds it this way and the
    * two blocks have to stay comparable
    gen byte dui_collision = (alcohol_collision == 1 | drug_collision == 1)

    gen byte source_new_export = 1

    if `first_year_processed' == 1 {
        save `new_crashes', replace
        local first_year_processed = 0
    }
    else {
        append using `new_crashes'
        save `new_crashes', replace
    }
}

clear
use `new_crashes'

* No crash may appear in two annual workbooks, or it would be counted twice
isid accidentid

di as text _newline "Crash counts by year from the annual exports:"
tab year

/* [> the seam between the two deliveries <] */

* Crashes that appear in BOTH deliveries. Expected: 2019 and 2020. What must
* NOT appear is a crash the legacy file dated 2018 or earlier, which sections 1
* and 3B would both keep and which would therefore be counted twice
*
* Compared on a separate copy of the ids rather than by merging into the data
* in memory, because both files carry a variable called year and the point is
* to compare them rather than let one overwrite the other
preserve
    keep accidentid year
    rename year year_new
    tempfile new_ids
    save `new_ids', replace

    use `all_crash_ids', clear
    rename fldaccidentid accidentid
    rename year year_legacy
    merge 1:1 accidentid using `new_ids', keep(3) nogenerate

    * Both id variables are imported allstring, so they are compared as text.
    * If the two deliveries render the same id differently the merge matches
    * nothing, every check below passes vacuously, and the double-count guard
    * stops guarding. 2019 and 2020 appear in both deliveries, so a zero match
    * here means a format problem and not clean data
    qui count
    if r(N) == 0 {
        di as error "No crash matched across the two deliveries, but 2019 and 2020 are in both."
        di as error "fldaccidentid and AccidentID have most likely imported in different"
        di as error "string formats. Compare a few values from each before trusting this run."
        error 459
    }
    di as text "`r(N)' crashes appear in both deliveries."

    di as text "Crashes present in BOTH deliveries, cross-tabulated by the year each assigns:"
    tab year_legacy year_new

    * A warning rather than a fatal assert, because the test below is the one
    * the source cut depends on and this one is strictly weaker: a crash the
    * legacy file dates 2020 and the annual export dates 2021 is still counted
    * exactly once, just in the later year. Two such crashes out of 49,772
    * shared. Reported so a small correction stays visible and a large one is
    * obvious
    qui count if year_legacy != year_new
    if r(N) > 0 {
        di as error _newline "WARNING: `r(N)' crash(es) dated differently by the two deliveries."
        di as error "Each is still counted exactly once, under the annual export's year."
        di as error "Not fatal. Listed here so a small correction stays visible and a"
        di as error "large one is obvious:"
        list accidentid year_legacy year_new if year_legacy != year_new, ///
            noobs sep(0)
    }

    * THIS is the double-count guard the source cut depends on
    count if year_legacy <= `legacy_end_year'
    if r(N) > 0 {
        di as error "`r(N)' crashes are dated <= `legacy_end_year' in the legacy export and also"
        di as error "appear in an annual export. These would be double counted in the panel."
        list accidentid year_legacy year_new if year_legacy <= `legacy_end_year', ///
            noobs sep(0)
        error 459
    }

    * Size of the seam: how many crashes the legacy delivery reported in the
    * overlap years, against how many the annual exports report. The annual
    * figure is expected to run slightly higher, because it was pulled later
    * and picked up crashes reported after the November 2021 legacy export
    use `all_crash_ids', clear
    di as text "Overlap-year crash counts, LEGACY delivery (these rows are discarded):"
    tab year if year >= `new_start_year'
restore

di as text "Overlap-year crash counts, ANNUAL exports (these rows are kept):"
tab year if year <= `legacy_file_last_year'

/* [> fields these exports add and this file does not yet use <] */

* Two columns these exports populate and this file does not build, urban and
* injurytype, are described in NOTE 8

tempfile new_crashes_final
save `new_crashes_final', replace

/*-----------------SECTION 4: AccdPerson_Injury coverage report --------------*/


/* [> person level injuries, reported on but NOT merged <] */

* AccdPerson_Injury is NOT USED, and the reason is coverage rather than
* preference: see NOTE 3, which also says what to request in order to make it
* usable. The block below only reports coverage by year, so the next person
* does not have to rediscover the problem, and it is off by default because it
* costs a full pass over a million-row workbook

if `check_person_injury' == 1 {

    clear
    local file_name = "$raw/AccdPerson_Injury.xlsx"
    import excel using "`file_name'" , describe
    local sheet_name = "`r(worksheet_1)'"
    import excel using "`file_name'", allstring sheet("`sheet_name'") firstrow case(lower) clear

    keep fldaccidentid
    duplicates drop fldaccidentid, force
    gen in_person_file = 1

    * Merged against the unrestricted id list, not against `main'. `main' now
    * stops at `legacy_end_year', so merging into it would classify every
    * 2019 and 2020 person record as an orphan and trip the assert below
    merge 1:1 fldaccidentid using `all_crash_ids', keepusing(year)
    count if _merge == 1
    assert r(N) == 0  /* a person record with no parent crash would be a data error */

    replace in_person_file = 0 if missing(in_person_file)

    * tabstat rather than the newer table syntax, because the rest of this
    * repo still runs on versions where statistic() is not available
    di as text "AccdPerson_Injury coverage by year (share of crashes with a person record):"
    tabstat in_person_file, by(year) statistics(mean n) format(%9.4f)

    clear
}


/*-----------------SECTION 5: assemble and collapse to county-year --------------*/


/* [> crash level file with all flags attached <] */

use `main', clear

* Merged without keep() so that the _merge tables actually show using-only
* rows. With keep(1 3) those are dropped before the tab runs, which hides an
* event or circumstance record that has no parent crash. Both files are
* subsets of AccdMain today, so the asserts below should pass silently
merge 1:1 fldaccidentid using `animal_flags'
tab _merge
count if _merge == 2
assert r(N) == 0
drop _merge

* Separate from the animal merge above: this says whether the crash appears
* in AccdEvent at all, which is the only way to tell a genuine "no animal"
* from a crash the truncated export never reached
merge 1:1 fldaccidentid using `event_coverage'
tab _merge
count if _merge == 2
assert r(N) == 0
drop _merge
replace has_event_record = 0 if missing(has_event_record)

merge 1:1 fldaccidentid using `circumstance_flags'
tab _merge
count if _merge == 2
assert r(N) == 0
drop _merge

* A crash absent from the event or circumstance file has no animal strike
* and no flagged circumstance recorded, so it is coded 0 rather than left
* missing. For the event file this is a substantive statement about the crash.
* For the circumstance file it is partly an artefact of the truncation
* described in section 3, affecting 0.29% of crashes
foreach v in animal_event_collision wild_animal_collision            ///
             non_wild_animal_collision animal_first_collision        ///
             wild_animal_first_collision non_wild_animal_first_coll  ///
             alcohol_collision drug_collision dui_collision          ///
             animal_circ_collision {
    replace `v' = 0 if missing(`v')
}

drop fldaccidentid

/* [> append the 2019-2025 crash records <] */

* Appended HERE, after the legacy merges and zero-filling and before anything
* is derived, so that every variable built below is built once and identically
* for both deliveries. Deriving severity and the interactions separately in
* each source block is how the two halves of a panel drift apart
*
* The zero-filling above is a legacy-only step: a crash can be absent from
* AccdEvent or AccdUnit_ContribCirc entirely, whereas in the annual exports a
* crash's events and circumstances live in its own rows and section 3B
* generates every flag as a 0/1 byte with no missings to fill
append using `new_crashes_final'
drop accidentid

* Both deliveries must land the same variables, or a variable present in only
* one of them would be silently missing for that source's years and would
* collapse to a missing county-year cell
foreach v of varlist _all {
    qui count if missing(`v')
    if r(N) > 0 {
        qui count if missing(`v') & source_new_export == 0
        local n_legacy_miss = r(N)
        qui count if missing(`v') & source_new_export == 1
        di as text "`v': `n_legacy_miss' missing in 1997-`legacy_end_year', `r(N)' missing in `new_start_year'-`new_end_year'"
    }
}

di as text _newline "Assembled crash-level file, crashes by year and source:"
tab year source_new_export

* No year may draw on both deliveries. If this fails the source cut leaked and
* some year is a mix of the two, which would show up as an inflated count
bysort year: assert source_new_export == source_new_export[1]

/* [> severity <] */

* NOTE 6 covers the pooling: B and C are pooled into minor_injury_collision to
* match AZ, and possible_injury_collision is a SUBSET of minor, not a sibling
gen fatal_collision = (severity == "Fatal Accident")
gen major_injury_collision = (severity == "A Injury Accident")
gen minor_injury_collision = (severity == "B Injury Accident" | ///
                              severity == "C Injury Accident")
gen possible_injury_collision = (severity == "C Injury Accident")
gen injury_collision = (major_injury_collision == 1 | ///
                        minor_injury_collision == 1)
gen pdo_collision = (severity == "Property Dmg Report")

* Every crash should land in exactly one severity category; a new code in
* a later data delivery would show up here as a zero. Currently clean in both
* deliveries: all 595,514 rows of the legacy AccdMain export and all 190,446
* crashes across the seven annual exports carry one of the five known labels
assert fatal_collision + injury_collision + pdo_collision == 1
drop severity

* Summing the number of rows by county-year will provide the total_all_cause
* after collapsing the data
gen total_all_cause = 1

/* [> animal collisions: the three families <] */

* THE THREE ANIMAL FAMILIES, defined in full in NOTE 5 along with the reason
* for the naming and the warning that wild and non_wild do NOT partition
* animal. In short: animal is the union of the event and circumstance sides and
* is the cross-state comparable family, while wild_animal and non_wild_animal
* are the two event codes

* The event and circumstance measures should overlap heavily but not exactly
tab animal_event_collision animal_circ_collision

gen animal_collision = (animal_event_collision == 1 | ///
                        animal_circ_collision == 1)

* Both inputs have now done their job. They are dropped rather than carried
* into the panel, so nothing downstream can pick up the narrow event-side
* count under a name that reads like the broad one. To export either, add it
* to the collapse below and to the order list in section 7
drop animal_event_collision animal_circ_collision

/* [> any animal <] */

* These names match the other state files exactly, which is the point of the
* family
gen fatal_animal_collision = animal_collision*fatal_collision
gen injury_animal_collision = animal_collision*injury_collision
gen major_injury_animal_collision = animal_collision*major_injury_collision
gen minor_injury_animal_collision = animal_collision*minor_injury_collision
gen possible_injury_animal_collision = animal_collision*possible_injury_collision
gen pdo_animal = animal_collision*pdo_collision
gen animal_fatalities = animal_collision*total_fatalities
gen animal_injuries = animal_collision*total_injuries
gen animal_persons = animal_collision*total_persons

/* [> wild animal <] */

* The two subset families drop the "_collision" suffix on their severity
* splits, because Stata caps a variable name at 32 characters and
* major_injury_wild_animal_collision is 34. The base count keeps it
gen fatal_wild_animal = wild_animal_collision*fatal_collision
gen injury_wild_animal = wild_animal_collision*injury_collision
gen major_injury_wild_animal = wild_animal_collision*major_injury_collision
gen minor_injury_wild_animal = wild_animal_collision*minor_injury_collision
gen possible_injury_wild_animal = wild_animal_collision*possible_injury_collision
gen pdo_wild_animal = wild_animal_collision*pdo_collision
gen wild_animal_fatalities = wild_animal_collision*total_fatalities
gen wild_animal_injuries = wild_animal_collision*total_injuries
gen wild_animal_persons = wild_animal_collision*total_persons

/* [> non-wild, i.e. domestic, animal <] */

gen fatal_non_wild_animal = non_wild_animal_collision*fatal_collision
gen injury_non_wild_animal = non_wild_animal_collision*injury_collision
gen major_injury_non_wild_animal = non_wild_animal_collision*major_injury_collision
gen minor_injury_non_wild_animal = non_wild_animal_collision*minor_injury_collision
gen possible_injury_non_wild_animal = non_wild_animal_collision*possible_injury_collision
gen pdo_non_wild_animal = non_wild_animal_collision*pdo_collision
gen non_wild_animal_fatalities = non_wild_animal_collision*total_fatalities
gen non_wild_animal_injuries = non_wild_animal_collision*total_injuries
gen non_wild_animal_persons = non_wild_animal_collision*total_persons

/* [> alcohol, the AZ comparable series <] */

* This block is the reason for the 08/26 revision. AZ carries a full severity
* breakdown on its alcohol flag and the previous version of this file carried
* alcohol only as a bare count, which made the one genuinely cross-state
* comparable impairment variable the one variable that could not be used
gen fatal_alcohol_collision = alcohol_collision*fatal_collision
gen injury_alcohol_collision = alcohol_collision*injury_collision
gen major_injury_alcohol_collision = alcohol_collision*major_injury_collision
gen minor_injury_alcohol_collision = alcohol_collision*minor_injury_collision
gen pdo_alcohol = alcohol_collision*pdo_collision
gen alcohol_fatalities = alcohol_collision*total_fatalities
gen alcohol_injuries = alcohol_collision*total_injuries

/* [> drugs <] */

* No AZ counterpart. ID codes "Drug Impaired" separately from "Alcohol
* Impaired" and a unit can carry both
gen fatal_drug_collision = drug_collision*fatal_collision
gen injury_drug_collision = drug_collision*injury_collision
gen major_injury_drug_collision = drug_collision*major_injury_collision
gen minor_injury_drug_collision = drug_collision*minor_injury_collision
gen pdo_drug = drug_collision*pdo_collision
gen drug_fatalities = drug_collision*total_fatalities
gen drug_injuries = drug_collision*total_injuries

/* [> impaired driving, alcohol or drugs <] */

gen fatal_dui_collision = dui_collision*fatal_collision
gen injury_dui_collision = dui_collision*injury_collision
gen major_injury_dui_collision = dui_collision*major_injury_collision
gen minor_injury_dui_collision = dui_collision*minor_injury_collision
gen pdo_dui = dui_collision*pdo_collision
gen dui_fatalities = dui_collision*total_fatalities
gen dui_injuries = dui_collision*total_injuries

/* [> the animal and impaired overlap <] */

* The crashes a DVC count should arguably exclude: an animal strike reported by
* a driver who was also flagged as impaired. Carried as their own variables,
* for all three families, rather than dropped, so the county-year file supports
* both the full series and the netted one. NOTE 7
gen dui_animal_collision = dui_collision*animal_collision
gen fatal_dui_animal = dui_animal_collision*fatal_collision
gen injury_dui_animal = dui_animal_collision*injury_collision
gen pdo_dui_animal = dui_animal_collision*pdo_collision
gen dui_animal_fatalities = dui_animal_collision*total_fatalities
gen dui_animal_injuries = dui_animal_collision*total_injuries

gen dui_wild_animal_collision = dui_collision*wild_animal_collision
gen fatal_dui_wild_animal = dui_wild_animal_collision*fatal_collision
gen injury_dui_wild_animal = dui_wild_animal_collision*injury_collision
gen pdo_dui_wild_animal = dui_wild_animal_collision*pdo_collision
gen dui_wild_animal_fatalities = dui_wild_animal_collision*total_fatalities
gen dui_wild_animal_injuries = dui_wild_animal_collision*total_injuries

gen dui_non_wild_animal_collision = dui_collision*non_wild_animal_collision
gen fatal_dui_non_wild_animal = dui_non_wild_animal_collision*fatal_collision
gen injury_dui_non_wild_animal = dui_non_wild_animal_collision*injury_collision
gen pdo_dui_non_wild_animal = dui_non_wild_animal_collision*pdo_collision
gen dui_non_wild_animal_fatalities = dui_non_wild_animal_collision*total_fatalities
gen dui_non_wild_animal_injuries = dui_non_wild_animal_collision*total_injuries

* There is usually a tiny overlap between animal and impaired collisions
tab animal_collision dui_collision
tab wild_animal_collision dui_collision

/* [> county name cleaning <] */

* All 44 Idaho counties appear under their standard names in both deliveries.
* Legacy AccdMain carries one row with a blank county, dropped after the
* collapse; the annual exports carry none. The name that needs watching on the
* section 6 merge is "nez perce", which some crosswalks store as "nezperce"
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)

collapse (sum) total_all_cause ///
               total_fatalities ///
               total_injuries ///
               total_persons ///
               fatal_collision ///
               injury_collision ///
               major_injury_collision ///
               minor_injury_collision ///
               possible_injury_collision ///
               pdo_collision ///
               has_event_record ///
               animal_collision ///
               animal_first_collision ///
               fatal_animal_collision ///
               injury_animal_collision ///
               major_injury_animal_collision ///
               minor_injury_animal_collision ///
               possible_injury_animal_collision ///
               pdo_animal ///
               animal_fatalities ///
               animal_injuries ///
               animal_persons ///
               wild_animal_collision ///
               wild_animal_first_collision ///
               fatal_wild_animal ///
               injury_wild_animal ///
               major_injury_wild_animal ///
               minor_injury_wild_animal ///
               possible_injury_wild_animal ///
               pdo_wild_animal ///
               wild_animal_fatalities ///
               wild_animal_injuries ///
               wild_animal_persons ///
               non_wild_animal_collision ///
               non_wild_animal_first_coll ///
               fatal_non_wild_animal ///
               injury_non_wild_animal ///
               major_injury_non_wild_animal ///
               minor_injury_non_wild_animal ///
               possible_injury_non_wild_animal ///
               pdo_non_wild_animal ///
               non_wild_animal_fatalities ///
               non_wild_animal_injuries ///
               non_wild_animal_persons ///
               alcohol_collision ///
               fatal_alcohol_collision ///
               injury_alcohol_collision ///
               major_injury_alcohol_collision ///
               minor_injury_alcohol_collision ///
               pdo_alcohol ///
               alcohol_fatalities ///
               alcohol_injuries ///
               drug_collision ///
               fatal_drug_collision ///
               injury_drug_collision ///
               major_injury_drug_collision ///
               minor_injury_drug_collision ///
               pdo_drug ///
               drug_fatalities ///
               drug_injuries ///
               dui_collision ///
               fatal_dui_collision ///
               injury_dui_collision ///
               major_injury_dui_collision ///
               minor_injury_dui_collision ///
               pdo_dui ///
               dui_fatalities ///
               dui_injuries ///
               dui_animal_collision ///
               fatal_dui_animal ///
               injury_dui_animal ///
               pdo_dui_animal ///
               dui_animal_fatalities ///
               dui_animal_injuries ///
               dui_wild_animal_collision ///
               fatal_dui_wild_animal ///
               injury_dui_wild_animal ///
               pdo_dui_wild_animal ///
               dui_wild_animal_fatalities ///
               dui_wild_animal_injuries ///
               dui_non_wild_animal_collision ///
               fatal_dui_non_wild_animal ///
               injury_dui_non_wild_animal ///
               pdo_dui_non_wild_animal ///
               dui_non_wild_animal_fatalities ///
               dui_non_wild_animal_injuries ///
               (max) source_new_export, ///
               by(county_name year)

strip_collapse_labels

* Cleanup. One crash in legacy AccdMain has no county and cannot be placed in
* the panel; no crash in the annual exports is missing one. "total" is not
* present in either ID delivery but is dropped for symmetry with the AZ file,
* where the source spreadsheet does carry a total row
drop if county_name == "" | county_name == "total"

/* [> derived series <] */

* Share of this county-year's crashes with event information recorded. Where
* this is below 1 the animal counts are mechanically understated, because a
* crash with no event record contributes a zero. Built differently either side
* of the source cut but meaning the same thing; see NOTE 4
rename has_event_record crashes_with_event_rec
gen event_record_coverage = crashes_with_event_rec / total_all_cause

* Threshold is deliberately strict. At 99% the understatement is within the
* noise of a county-year count; below that it starts to be the whole series.
* Anything failing this cannot support a DVC count no matter how the
* regression is specified
gen animal_data_usable = (event_record_coverage >= 0.99)

di as text "Event coverage by year. Animal counts are only usable where this is at or near 1:"
tabstat event_record_coverage, by(year) statistics(mean min max) format(%9.4f)

* THIS BLOCK IS EXPECTED TO FIRE. NOTE 4 has the baseline: 25 cells, in 2002
* and 2014-2018. The count is the thing to watch, not the fact that it fired
qui count if animal_data_usable == 0
if r(N) > 0 {
    di as error "WARNING: `r(N)' county-year cells have incomplete event coverage."
    di as error "Their animal, wild_animal and non_wild_animal variables are NOT usable."
    di as error "Expected baseline is 25 cells, in 2002 and 2014-2018 (see the note above)."
    qui levelsof year if animal_data_usable == 0, local(bad_years)
    di as error "Affected years: `bad_years'"
    di as error "A materially larger count, or any cell from 2019 on, means a delivery"
    di as error "has been truncated the way AccdEvent was. Check before using the panel."
}

* 2020 is carried as an ordinary panel year with no covid indicator; NOTE 9

* Blanking rather than zeroing where the event file does not cover the cell.
* Missing is the honest value: the count is unknown, not low. Set the local to
* 0 to keep the raw sums instead, but then nothing stops a regression from
* reading a truncated cell as a real zero. NOTE 4
local blank_animal_when_incomplete = 1

if `blank_animal_when_incomplete' == 1 {

    * Pattern rather than a hand-kept list, so a variable added to one of the
    * families later cannot quietly escape the blanking. Every family carries
    * "animal" in its name, including the DUI interactions, so one pattern
    * reaches all of them. animal_data_usable is the flag doing the blanking
    * and is the only thing that has to survive it
    foreach v of varlist *animal* {
        if "`v'" != "animal_data_usable" {
            qui replace `v' = . if animal_data_usable == 0
        }
    }
}

* The no_dui series that used to be built here are gone. Each was x minus
* dui_x, and both x and dui_x are in the panel, so they carried no information
* it did not already have

/* [> sanity checks <] */

* No count anywhere in the panel may be negative. Every numeric variable is
* either a count, a share in [0,1] or a 0/1 flag, so this can be a sweep
* rather than a hand-kept list that the next variable gets left out of
foreach v of varlist _all {
    capture confirm numeric variable `v'
    if _rc == 0 {
        assert `v' >= 0 if !missing(`v')
    }
}

* Checks that do not touch the event file, so they hold in every cell.
* possible_injury_collision is checked against minor rather than against
* injury because it is defined as a subset of minor
assert possible_injury_collision <= minor_injury_collision ///
       & major_injury_collision + minor_injury_collision == injury_collision ///
       & fatal_collision + injury_collision + pdo_collision == total_all_cause ///
       & alcohol_collision <= dui_collision ///
       & drug_collision <= dui_collision ///
       & crashes_with_event_rec <= total_all_cause

* Restricted to the cells the event file actually covers. Where
* animal_data_usable is 0 these are missing by design, and Stata orders missing
* above every number, so an unrestricted comparison would fail on exactly the
* rows that were blanked on purpose. The species families are asserted to be
* subsets of animal and deliberately NOT asserted to sum to it (NOTE 5)
assert animal_collision <= total_all_cause ///
       & wild_animal_collision <= animal_collision ///
       & non_wild_animal_collision <= animal_collision ///
       & animal_first_collision <= animal_collision ///
       & wild_animal_first_collision <= wild_animal_collision ///
       & non_wild_animal_first_coll <= non_wild_animal_collision ///
       & fatal_animal_collision + injury_animal_collision + pdo_animal ///
         == animal_collision ///
       & major_injury_animal_collision + minor_injury_animal_collision ///
         == injury_animal_collision ///
       & possible_injury_animal_collision <= minor_injury_animal_collision ///
       & fatal_wild_animal + injury_wild_animal + pdo_wild_animal ///
         == wild_animal_collision ///
       & fatal_non_wild_animal + injury_non_wild_animal ///
         + pdo_non_wild_animal == non_wild_animal_collision ///
       & dui_animal_collision <= dui_collision ///
       & dui_animal_collision <= animal_collision ///
       & dui_wild_animal_collision <= dui_animal_collision ///
       & dui_non_wild_animal_collision <= dui_animal_collision ///
       if animal_data_usable == 1

* And where they are not usable, they should be uniformly missing rather than
* partly blanked, which would mean the foreach varlist above missed a variable
if `blank_animal_when_incomplete' == 1 {
    assert missing(animal_collision) & missing(wild_animal_collision) ///
           & missing(non_wild_animal_collision) ///
           if animal_data_usable == 0
}


/*-----------------SECTION 6: merge with state_county_identifiers --------------*/

* ID reports the county name but not a county code, so the crosswalk has
* to be joined on the name rather than on FIPS as in the AZ file
gen state_letter_code = "ID"

* county_name is lowercased and trimmed at the end of section 5, so the
* crosswalk is put in the same shape before the join rather than assuming it
* already stores lowercase names
preserve
    use "$xwalk", clear
    keep if state_letter_code == "ID"
    replace county_name = lower(county_name)
    replace county_name = strtrim(county_name)
    replace county_name = ustrtrim(county_name)
    isid state_letter_code county_name
    tempfile xwalk_id
    save `xwalk_id', replace
restore

merge m:1 state_letter_code county_name using `xwalk_id', keep(1 3)

* Naming the unmatched counties before asserting, because "assert _merge == 3"
* on its own tells you that a name failed to match but not which one. All 44
* Idaho counties are present in the raw data under standard spellings, so a
* clean crosswalk should leave nothing here
count if _merge == 1
if r(N) > 0 {
    levelsof county_name if _merge == 1, local(unmatched_counties)
    di as error "County names not matched to the crosswalk: `unmatched_counties'"

    * Print what the crosswalk holds alongside what failed, so a broken join
    * shows whether the cause is a spelling difference or a missing row
    preserve
        use `xwalk_id', clear
        levelsof county_name, local(xwalk_names)
        di as error "Crosswalk holds for ID: `xwalk_names'"
    restore
}
assert _merge == 3
drop _merge

tab year


/*-----------------SECTION 7: order, sort, save --------------*/

* Spelled out rather than done with wildcards. animal* does not reach
* major_injury_animal_collision and wild* no longer reaches anything, now that
* the wild family is prefixed wild_animal, so the pattern version left half
* the panel wherever the collapse happened to put it
order state_letter_code                ///
      state_name                       ///
      county_name                      ///
      state_fips                       ///
      county_fips                      ///
      fips                             ///
      year                             ///
      source_new_export                ///
      animal_data_usable               ///
      crashes_with_event_rec           ///
      event_record_coverage            ///
      total_all_cause                  ///
      total_fatalities                 ///
      total_injuries                   ///
      total_persons                    ///
      fatal_collision                  ///
      injury_collision                 ///
      major_injury_collision           ///
      minor_injury_collision           ///
      possible_injury_collision        ///
      pdo_collision                    ///
      animal_collision                 ///
      animal_first_collision           ///
      fatal_animal_collision           ///
      injury_animal_collision          ///
      major_injury_animal_collision    ///
      minor_injury_animal_collision    ///
      possible_injury_animal_collision ///
      pdo_animal                       ///
      animal_fatalities                ///
      animal_injuries                  ///
      animal_persons                   ///
      wild_animal_collision            ///
      wild_animal_first_collision      ///
      fatal_wild_animal                ///
      injury_wild_animal               ///
      major_injury_wild_animal         ///
      minor_injury_wild_animal         ///
      possible_injury_wild_animal      ///
      pdo_wild_animal                  ///
      wild_animal_fatalities           ///
      wild_animal_injuries             ///
      wild_animal_persons              ///
      non_wild_animal_collision        ///
      non_wild_animal_first_coll       ///
      fatal_non_wild_animal            ///
      injury_non_wild_animal           ///
      major_injury_non_wild_animal     ///
      minor_injury_non_wild_animal     ///
      possible_injury_non_wild_animal  ///
      pdo_non_wild_animal              ///
      non_wild_animal_fatalities       ///
      non_wild_animal_injuries         ///
      non_wild_animal_persons          ///
      alcohol_collision                ///
      fatal_alcohol_collision          ///
      injury_alcohol_collision         ///
      major_injury_alcohol_collision   ///
      minor_injury_alcohol_collision   ///
      pdo_alcohol                      ///
      alcohol_fatalities               ///
      alcohol_injuries                 ///
      drug_collision                   ///
      fatal_drug_collision             ///
      injury_drug_collision            ///
      major_injury_drug_collision      ///
      minor_injury_drug_collision      ///
      pdo_drug                         ///
      drug_fatalities                  ///
      drug_injuries                    ///
      dui_collision                    ///
      fatal_dui_collision              ///
      injury_dui_collision             ///
      major_injury_dui_collision       ///
      minor_injury_dui_collision       ///
      pdo_dui                          ///
      dui_fatalities                   ///
      dui_injuries                     ///
      dui_animal_collision             ///
      fatal_dui_animal                 ///
      injury_dui_animal                ///
      pdo_dui_animal                   ///
      dui_animal_fatalities            ///
      dui_animal_injuries              ///
      dui_wild_animal_collision        ///
      fatal_dui_wild_animal            ///
      injury_dui_wild_animal           ///
      pdo_dui_wild_animal              ///
      dui_wild_animal_fatalities       ///
      dui_wild_animal_injuries         ///
      dui_non_wild_animal_collision    ///
      fatal_dui_non_wild_animal        ///
      injury_dui_non_wild_animal       ///
      pdo_dui_non_wild_animal          ///
      dui_non_wild_animal_fatalities   ///
      dui_non_wild_animal_injuries

* The collapse artefacts were already stripped at each collapse, so everything
* not named here carries no label, which reads better in the browser than
* "(sum) fatal_dui_wild_animal". Labelled below where the name alone is not
* enough
label var source_new_export         "1 = annual UofChicago export, 0 = legacy AccdMain"
label var crashes_with_event_rec    "Crashes with an event record"
label var event_record_coverage     "Share of crashes with an event record"
label var animal_data_usable        "1 = coverage at or above 0.99, animal families usable"
label var total_all_cause           "All-cause collisions"
label var possible_injury_collision "C injuries, a SUBSET of minor_injury_collision"
label var animal_collision          "Animal collisions, event or circumstance (NOTE 5)"
label var wild_animal_collision     "Animal collisions, Animal - Wild event code"
label var non_wild_animal_collision "Animal collisions, Animal - Domestic event code"
label var alcohol_collision         "Alcohol impaired, the AZ-comparable series"
label var dui_collision             "Alcohol or drug impaired, the ID superset"
label var dui_animal_collision      "Animal collisions with an impaired driver (NOTE 7)"

sort fips year

* The panel should be 44 counties by every year in it, with no county-year
* silently absent because a county recorded no crashes in some year. Reported
* rather than asserted, because a genuinely crash-free county-year is possible
* in the small counties and is a substantive zero, not an error
qui levelsof year, local(all_years)
foreach y of local all_years {
    qui count if year == `y'
    if r(N) != 44 {
        di as error "Year `y' has `r(N)' county rows, not 44."
    }
}

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
* qui, because the type-change list runs to 88 lines and says nothing a
* reader of this log needs
qui compress
save "$working_data/dvcs_ID_county_year_`T1'_`T2'.dta", replace

di as text _newline "Saved: $working_data/dvcs_ID_county_year_`T1'_`T2'.dta"
di as text "Log:   $working_data/dvcs_ID_build.log"

cap log close
