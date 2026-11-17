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

* The panel is built from two deliveries that overlap in 2019 and 2020, so the
* boundary between them is set here rather than hardcoded in three places.
* Crashes are taken from the legacy AccdMain export through `legacy_end_year'
* and from the annual UofChicago_YYYY.xlsx exports from `new_start_year' on.
*
* The cut is at 2018/2019 and not later because the legacy AccdEvent export is
* truncated from mid-2019 (see section 2), so legacy 2019 and 2020 cannot
* support an animal count at all. The annual exports are complete on events in
* every year they cover, which is why they take over the moment they begin.
*
* The two sources do not agree exactly on the overlap years: the annual export
* has 27,255 crashes in 2019 against 27,136 in the legacy file, and 22,835 in
* 2020 against 22,637. The gaps are +0.4% and +0.9%, consistent with crashes
* reported late and added after the November 2021 legacy export was pulled.
* Section 3B prints the comparison so the size of the seam stays visible
*
* Moving 2019 back to the legacy side was considered and rejected. AccdEvent
* reaches only 64.72% of 2019 crashes, below the 0.99 threshold in section 5,
* so legacy 2019 would carry no animal series at all rather than a slightly
* worse one. If it is ever wanted for a non-animal purpose it is a single edit
* to these two locals: the section 3B seam checks and the section 5 coverage
* guard are both written against them
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

* ID gives us four legacy files, all keyed on fldAccidentID, at four different
* levels of aggregation:
*   AccdMain              one row per crash    (severity, county, year, conditions)
*   AccdEvent             one row per event    (what the vehicle struck)
*   AccdUnit_ContribCirc  one row per unit     (why the crash happened)
*   AccdPerson_Injury     one row per person   (who was hurt and how badly)
* Sections 1-3 flatten the middle two down to one row per crash before
* anything is merged. Section 3B does the same job for the 2019-2025 annual
* exports, which arrive as a single flat file per year rather than as four
* files, and appends onto the legacy years. Section 4 explains why the fourth
* legacy file is not used
*
* Everything from here to the end of section 3 is LEGACY YEARS ONLY. The full
* AccdMain id list is saved before the year restriction so that the orphan
* checks in sections 2, 3 and 3B still run against every crash the state has
* ever reported, not just the ones this run keeps

clear
local file_name = "$raw/AccdMain.xlsx"
import excel using "`file_name'" , describe
* Sheet name captured and quoted: r(worksheet_1) unquoted is a syntax error the
* moment a sheet name contains a space
local sheet_name = "`r(worksheet_1)'"
import excel using "`file_name'", allstring sheet("`sheet_name'") firstrow case(lower) clear

* Of the twenty columns in AccdMain, two are dropped on purpose rather than
* by oversight. isreportable is the constant "Y" on all 595,514 rows, so it
* carries no information. urbantype is missing on 545,145 rows (91.5%), i.e.
* it was only ever populated for a recent subset, so a county-year urban share
* built from it would be an artefact of coverage rather than of geography.
* fldlatitude and fldlongitude are real but do not aggregate to county-year
keep fldaccidentid ///
     fldaccidentyyyy ///
     fldaccidentmonth ///
     fldcountyname ///
     severityname ///
     fldfatalities ///
     fldinjuries ///
     fldpersons ///
     fldlightcondition ///
     fldroadsurfaceconditionname ///
     fldweathercondition1name

rename fldaccidentyyyy year
rename fldaccidentmonth month
rename fldcountyname county_name
rename severityname severity
rename fldfatalities total_fatalities
rename fldinjuries total_injuries
rename fldpersons total_persons
rename fldlightcondition light_condition
rename fldroadsurfaceconditionname road_surface
rename fldweathercondition1name weather

* ignore(",") mirrors the AZ file. None of these three currently arrive with a
* thousands separator, but a later delivery formatted in Excel would, and
* destring errors out rather than warning when it hits one
destring year, replace ignore(",")
destring total_fatalities, replace ignore(",")
destring total_injuries, replace ignore(",")
destring total_persons, replace ignore(",")

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

* A single crash can carry more than one animal event (a domestic and a
* wild strike in the same collision), so this is collapsed to crash level
* with (max) before it goes anywhere near the main file
*
* "Animal - Wild" and "Animal - Domestic" are the only two animal codes in
* the file; verified against all 66 distinct values of EventCodeName
*
* This export is clipped at Excel's ceiling of 1,048,575 rows and the clip is
* CHRONOLOGICAL, not scattered. It reaches only 563,065 of the 595,514 crashes
* and stops partway through 2019. Coverage is at or above 99.87% every year
* from 1997 to 2017, falls to 99.40% in 2018, then to 64.72% in 2019 and to
* ZERO in 2020: not one 2020 crash has an event record. Because a crash with
* no event record is read as "no animal strike", the animal series built from
* this file is understated by about a third in 2019 and is identically zero
* across all counties in 2020
*
* THAT IS WHY THE SOURCE CUT IS AT 2018. This file is now used for 1997-2018
* only, where the worst year is 2018 at 99.40%, and the annual exports in
* section 3B supply 2019 onward with complete event coverage. The coverage
* measurement and blanking machinery in section 5 is KEPT rather than deleted:
* it now passes in every year, and that is a result worth continuing to verify
* on each delivery rather than an invariant to assume
*
* Figures verified 09/01/2026 against AccdEvent.xlsx and AccdMain.xlsx. Note
* the denominator when quoting the 2019 number: 64.72% is against the legacy
* AccdMain count of 27,136, and 64.44% against the annual export's 27,255

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
    if `write_cache' == 1 {
        save "$working_data/_cache_event_coverage.dta", replace
    }
restore

keep if eventcodename == "Animal - Domestic" | eventcodename == "Animal - Wild"

destring fldeventorder, replace ignore(",")

gen animal_collision = 1
gen wild_collision = (eventcodename == "Animal - Wild")

* fldeventorder == 1 means the animal was the first harmful event, rather
* than something struck after the driver had already lost control. 29,227 of
* the 29,536 animal crashes in the full legacy export are order 1, so the
* distinction is small, but it separates a direct strike from a swerve that
* ended in a second collision. Those two figures describe the whole export;
* this block now keeps only its 1997-2018 rows
gen animal_first_collision = (fldeventorder == 1)
gen wild_first_collision = (fldeventorder == 1 & wild_collision == 1)

drop eventcodename fldeventorder

collapse (max) animal_collision ///
               wild_collision ///
               animal_first_collision ///
               wild_first_collision, ///
               by(fldaccidentid)

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

* This file is unit-level, roughly 1.77 units per crash, and a circumstance
* can be coded in ANY of the three fields rather than only the first, so all
* three are checked. Collapsing with (max) means a crash counts as flagged if
* any unit in it was flagged
*
* The November 2021 export has exactly 1,048,575 data rows, which is Excel's
* row ceiling, so it is clipped. It still reaches 593,773 of the 595,514
* crashes (99.71%). The gap is not spread evenly: 2001 loses 1.88% of its
* crashes and 2005 loses 1.63%, with 2016 at 1.07% and every other year under
* 0.31%. Section 5 codes unmatched crashes as zero, so all circumstance counts
* below are very slightly understated, worst in those three years
*
* This is a legacy-years-only problem now. 2019-2025 circumstances come from
* the annual exports in section 3B, which are not truncated. The understatement
* therefore stops at 2018 and never exceeded 1.88% in any year

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
gen drowsy_collision = 0
gen distracted_collision = 0
gen speeding_collision = 0

* THE CLIP SCATTERS RATHER THAN TRUNCATING CHRONOLOGICALLY. The file is sorted
* by fldUnitID, so the rows lost are those with the highest unit ids, which is
* why the shortfall lands in 2001, 2005 and 2016 rather than at the end of the
* panel. Three files, three different clip shapes: do not generalise
*
* Slot count matches the annual exports: exactly three circumstance fields,
* with unused ones filled with the literal string "None" rather than left blank
* ONE CODE IS MOJIBAKED IN THE ANNUAL EXPORTS AND CLEAN HERE. This file has
* "Emotional [en dash] Depressed, Angry, Disturbed"; the annual exports carry
* the same code with the en dash mis-decoded as three Latin-1 characters.
* Nothing below matches it, so no current variable is affected, and all seven
* circumstance strings that ARE matched are pure ASCII and present in both
* vocabularies. But an emotional-state flag added later would silently pick up
* one era and not the other, so match that code on a substring if it is ever
* needed. The two vocabularies otherwise share 39 codes and differ only in
* "Fatigued", which is legacy-only and already handled below
*
* The labels below are the exact strings ID uses. "Asleep, Drowsy, Fatigued"
* and "Fatigued" are separate codes in the same field and both mean drowsy,
* so they are pooled. Likewise "Speed Too Fast For Conditions" is a judgment
* about conditions and "Exceeded Posted Speed" is a limit violation; pooled
* here as speeding, but they can be split if that distinction matters
forvalues circumstance = 1(1)3 {
    replace alcohol_collision = 1 ///
        if strtrim(fldcontributingcircumstance`circumstance') == "Alcohol Impaired"
    replace drug_collision = 1 ///
        if strtrim(fldcontributingcircumstance`circumstance') == "Drug Impaired"
    replace animal_circ_collision = 1 ///
        if strtrim(fldcontributingcircumstance`circumstance') == "Animal(s) in Roadway"
    replace drowsy_collision = 1 ///
        if strtrim(fldcontributingcircumstance`circumstance') == "Asleep, Drowsy, Fatigued"
    replace drowsy_collision = 1 ///
        if strtrim(fldcontributingcircumstance`circumstance') == "Fatigued"
    replace distracted_collision = 1 ///
        if strtrim(fldcontributingcircumstance`circumstance') == "Distracted IN or ON Vehicle"
    replace speeding_collision = 1 ///
        if strtrim(fldcontributingcircumstance`circumstance') == "Speed Too Fast For Conditions"
    replace speeding_collision = 1 ///
        if strtrim(fldcontributingcircumstance`circumstance') == "Exceeded Posted Speed"
}

drop fldcontributingcircumstance*

collapse (max) alcohol_collision ///
               drug_collision ///
               animal_circ_collision ///
               drowsy_collision ///
               distracted_collision ///
               speeding_collision, ///
               by(fldaccidentid)

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

* These seven workbooks replace all four legacy files for 2019 onward. Each is
* a single "Person Level Standard Report" of about 70,000 rows and 28 columns
* covering one calendar year, and each carries in one file what the legacy
* delivery split across AccdMain, AccdEvent and AccdUnit_ContribCirc:
*
*   crash attributes   Severity, County, Accident Month/Year, Number Of
*                      Fatalities/Injuries/Persons, Light Condition,
*                      Road Surface Condition, Weather Condition 1
*   what was struck    Events (an ORDERED, comma-delimited list per unit) and
*                      Most Harmful Event, in place of AccdEvent
*   why it happened    Contrib Circ 1-3, in place of AccdUnit_ContribCirc
*   who was hurt       Injury Type, in place of AccdPerson_Injury
*
* Rows are person level, 2.48 per crash on average and up to 61. The row count
* equals Number Of Persons for 95.8% of crashes and exceeds it for the rest,
* never falling short; the excess rows are units with no counted occupant, such
* as a struck parked car. Each person's row repeats their UNIT's events and
* contributing circumstances, so the flags are built at row level and maxed up
* to the crash exactly as the legacy unit and event files are. The crash
* attributes repeat identically on every row of a crash, which is asserted
* below rather than assumed
*
* Coverage is what makes these usable where the legacy files were not. At
* least one Events or Most Harmful Event value is present for 99.94% of 2019
* crashes, 99.98% of 2020 and 100.00% of 2021-2025, against 64.72% and 0.00%
* for legacy 2019 and 2020. Summing Fatal Injury rows reproduces Number Of
* Fatalities EXACTLY in all seven years, against the 69% the truncated
* AccdPerson_Injury managed, so the note in section 4 no longer applies to
* these years even though the variables are still not built here
*
* Two fields these files populate and the legacy delivery did not are noted at
* the end of this section rather than used

* Five preamble rows sit above the header in every workbook, hence
* cellrange(A6). The sheet name carries a space ("UofChicago 2019"), so
* r(worksheet_1) is passed in double quotes; unquoted it splits on the space
* and errors, which is why this differs from sections 1-3
*
* All seven workbooks are structurally identical: 28 columns, the same header
* row 6, the same five preamble rows, one sheet named "UofChicago YYYY". The
* four columns the animal and impairment flags are built from are
*
*   U   Events                  ordered comma-delimited list, one per unit
*   V   Most Harmful Event      single value
*   W   Contrib Circ 1
*   X   Contrib Circ 2
*   Y   Contrib Circ 3
*
* U IS INCLUDED DELIBERATELY AND IS NOT OPTIONAL. V is the tidier column, but
* it holds only the MOST HARMFUL event, so an animal struck in a crash whose
* worst event was something else does not appear in it. Dropping U loses 109
* animal crashes in 2019, 78 in 2020, then 88, 63, 54, 40 and 44 in 2021-2025,
* i.e. 2.0-6.2% of the event-based animal count every year. The legacy
* AccdEvent side counts an animal at ANY event position, so V-only here would
* put a 2-6% step in animal_collision exactly at the 2018/2019 seam
*
* The union measure is less sensitive, because most of those crashes also
* carry "Animal(s) in Roadway" in W:Y and so are recovered from the
* circumstance side: animal_any_collision loses only 8, 8, 13, 2, 5, 2 and 6
* crashes a year if U is dropped. That is the reason to keep BOTH constructs
* rather than to conclude U does not matter

local first_year_processed = 1
tempfile new_crashes

* Flags built at row level and maxed up to the crash. Listed once here so that
* a flag added below cannot be left out of the flatten and end up carrying an
* arbitrary row's value into the panel
local rowflags animal_collision       ///
               wild_collision         ///
               animal_first_collision ///
               wild_first_collision   ///
               has_event_record       ///
               alcohol_collision      ///
               drug_collision         ///
               animal_circ_collision  ///
               drowsy_collision       ///
               distracted_collision   ///
               speeding_collision

* Crash attributes, which must be constant within a crash
local crashvars year month county_name severity total_fatalities ///
                total_injuries total_persons light_condition     ///
                road_surface weather

forvalues yr = `new_start_year'/`new_end_year' {

    di as text _newline "==== Processing UofChicago_`yr'.xlsx ===="

    clear
    local file_name = "${annual_`yr'}"
    import excel using "`file_name'" , describe
    local sheet_name = "`r(worksheet_1)'"

    * Header row read on its own first, WITHOUT firstrow, so the variables are
    * named for their Excel column letters and the layout can be checked by
    * position. The name-based check below catches a RENAMED column; this
    * catches a MOVED one, which the name check cannot see because import excel
    * takes the names from wherever the headers happen to sit.
    *
    * Worth having because the animal and impairment definitions are specified
    * by column letter (U:Y) in the request this file answers, and a delivery
    * that inserts a column upstream of U would shift all five without changing
    * a single header string
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
    foreach v in accidentid accidentyear accidentmonth county severity      ///
                 numberoffatalities numberofinjuries numberofpersons       ///
                 lightcondition roadsurfacecondition weathercondition1     ///
                 events mostharmfulevent contribcirc1 contribcirc2         ///
                 contribcirc3 {
        capture confirm variable `v'
        if _rc != 0 {
            di as error "UofChicago_`yr'.xlsx: expected column `v' not found."
            di as error "Check the header row and the Fields: line at the top of the sheet."
            error 111
        }
    }

    * serialnumber, fldserialnbr, reportdistrict, dayofweek, accidenttime,
    * accidenthourtime, latitude, longitude, weathercondition2, accidentdate
    * and injurytype are all present and all dropped. accidentdate duplicates
    * accidentmonth and accidentyear exactly (verified: zero mismatches across
    * all seven years), and the rest either do not aggregate to county-year or
    * have no legacy counterpart to append onto
    keep accidentid    ///
         accidentyear  ///
         accidentmonth ///
         county        ///
         severity      ///
         numberoffatalities ///
         numberofinjuries   ///
         numberofpersons    ///
         lightcondition       ///
         roadsurfacecondition ///
         weathercondition1    ///
         events           ///
         mostharmfulevent ///
         contribcirc1 contribcirc2 contribcirc3

    rename accidentyear year
    rename accidentmonth month
    rename county county_name
    rename numberoffatalities total_fatalities
    rename numberofinjuries total_injuries
    rename numberofpersons total_persons
    rename lightcondition light_condition
    rename roadsurfacecondition road_surface
    rename weathercondition1 weather

    destring year, replace ignore(",")
    destring total_fatalities, replace ignore(",")
    destring total_injuries, replace ignore(",")
    destring total_persons, replace ignore(",")

    * Each workbook should contain exactly its own year and nothing else
    assert year == `yr'

    /* [> what the vehicle struck <] */

    * The annual exports give no numeric event order. Instead, events is an
    * ordered comma-delimited list of the events for that unit, so position in
    * the string carries the ordering that fldeventorder carried in AccdEvent:
    * "Loss of Control,Utility/Light Support,Mailbox," is order 1, 2, 3
    *
    * Matched on the substring "Animal - " rather than on equality with the two
    * full codes. Both animal codes begin with it, no other code among the 66
    * contains it, and one row in 2019 carries a corrupted "AniAnimal -
    * Domestic" that a strict equality test would silently score as no animal
    gen byte animal_collision = (strpos(events, "Animal - ") > 0 | ///
                                 strpos(mostharmfulevent, "Animal - ") > 0)
    gen byte wild_collision   = (strpos(events, "Animal - Wild") > 0 | ///
                                 strpos(mostharmfulevent, "Animal - Wild") > 0)

    * mostharmfulevent is included in the two tests above only to catch the 21
    * crashes across 2019-2021 that have a most-harmful event but an empty
    * events list. For every other crash it is one of the events already in the
    * list, so it cannot widen the definition, only fill a hole in it

    * First element of the list, i.e. the analogue of fldeventorder == 1
    gen event_first = events
    replace event_first = substr(events, 1, strpos(events, ",") - 1) ///
        if strpos(events, ",") > 0
    replace event_first = strtrim(event_first)

    * AZ keys its animal flag on firstharmfulevent, so these two are the
    * AZ-comparable series, not animal_collision and wild_collision above
    *
    * This is the one flag whose DEFINITION changes at the seam, so it was
    * tested rather than assumed. Legacy reads fldEventOrder == 1 from a long
    * event file; here there is no order column and the position has to come
    * from the comma list. If the list order did not track fldEventOrder the
    * series would step at 2018/2019. It does not: the share of animal crashes
    * whose FIRST event is the animal runs 98.1, 98.5, 98.8, 99.1, 98.8, 99.0
    * and 99.3 percent in 2019-2025, against 29,227 of 29,536 or 98.95 percent
    * in the whole legacy file. The two sides sit inside each other's spread
    gen byte animal_first_collision = (strpos(event_first, "Animal - ") > 0)
    gen byte wild_first_collision   = (strpos(event_first, "Animal - Wild") > 0)
    drop event_first

    * A crash with neither field populated has no event information at all and
    * is the analogue of a crash missing from the truncated AccdEvent export.
    * This feeds event_record_coverage in section 5 on exactly the same footing
    * as the legacy has_event_record, so the coverage test is a real test in
    * these years rather than a tautology from every crash being present in the
    * file by construction. Seven crashes across 2019-2025 fail it
    gen byte has_event_record = (events != "" | mostharmfulevent != "")

    drop events mostharmfulevent

    /* [> why it happened <] */

    * Same label matching as section 3. One difference: the standalone
    * "Fatigued" code does not appear in these exports, only "Asleep, Drowsy,
    * Fatigued". The test for it is kept so one block covers both deliveries
    *
    * THERE IS NO COMBINED "Alcohol/Drug Impaired" CODE. ID writes impairment as
    * two independent circumstances and a unit can carry both, so matching a
    * single combined string would return nothing and dui_collision would be
    * identically zero from 2019 on. The two are matched separately and OR'd
    * into dui_collision after the flatten, as section 3 does for legacy years
    *
    * AN UNUSED CIRCUMSTANCE SLOT HOLDS THE STRING "None", NOT A BLANK, and it
    * is the most common value in all three columns. Exact-equality matching
    * handles it, but anything reasoning about these columns with missing() will
    * conclude the fields are almost always populated and be wrong about it
    gen byte alcohol_collision = 0
    gen byte drug_collision = 0
    gen byte animal_circ_collision = 0
    gen byte drowsy_collision = 0
    gen byte distracted_collision = 0
    gen byte speeding_collision = 0

    forvalues circumstance = 1(1)3 {
        replace alcohol_collision = 1 ///
            if strtrim(contribcirc`circumstance') == "Alcohol Impaired"
        replace drug_collision = 1 ///
            if strtrim(contribcirc`circumstance') == "Drug Impaired"
        replace animal_circ_collision = 1 ///
            if strtrim(contribcirc`circumstance') == "Animal(s) in Roadway"
        replace drowsy_collision = 1 ///
            if strtrim(contribcirc`circumstance') == "Asleep, Drowsy, Fatigued"
        replace drowsy_collision = 1 ///
            if strtrim(contribcirc`circumstance') == "Fatigued"
        replace distracted_collision = 1 ///
            if strtrim(contribcirc`circumstance') == "Distracted IN or ON Vehicle"
        replace speeding_collision = 1 ///
            if strtrim(contribcirc`circumstance') == "Speed Too Fast For Conditions"
        replace speeding_collision = 1 ///
            if strtrim(contribcirc`circumstance') == "Exceeded Posted Speed"
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
    * THIS IS WHAT STOPS THE DOUBLE COUNTING, and the margin is not small: the
    * same animal appears in more than one of V:Y on 17,580 of the 22,763
    * person-rows carrying any animal criterion, and the rows are person level
    * at 2.48 per crash with each person repeating their unit's events
    *
    * Both are handled by the same step, because each flag is a 0/1 indicator
    * per row rather than a count of matches: (max) over a crash's rows gives 1
    * either way. Counting matches and summing would inflate animals by ~77%
    foreach v of local rowflags {
        bysort accidentid: egen byte crashmax_`v' = max(`v')
        drop `v'
        rename crashmax_`v' `v'
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

* Crashes that appear in BOTH deliveries. Expected: 2019 and 2020, since the
* legacy export runs through 2020 and those years are now taken from here
* instead. What must NOT appear is a crash the legacy file dated 2018 or
* earlier, because section 1 would keep that crash and so would this section,
* and it would be counted twice in the panel
*
* The comparison is done on a separate copy of the ids rather than by merging
* into the data in memory, because both files carry a variable called year and
* the whole point is to compare the two rather than let one overwrite the other
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

    * A year conflict between the two deliveries on the same crash would break
    * the source cut, since the cut is applied on each file's own year variable
    *
    * A warning rather than a fatal assert, because the fatal test below is the
    * one the source cut depends on and this one is strictly weaker. A crash the
    * legacy file dates 2020 and the annual export dates 2021 is dropped by
    * section 1 and kept once by section 3B, so it is still counted exactly
    * once, just in the later year. The 09/03/2026 run found 2 such crashes out
    * of 49,772 shared. Reported rather than silenced: a handful is a date
    * correction between deliveries, thousands would mean the two files disagree
    * about what a year is
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

* Two columns are dropped above that the legacy delivery could not support,
* and both are worth revisiting when the panel no longer has to match 1997:
*
*   urban        Populated on 99.99% of 2019-2025 crashes. Section 1 drops the
*                legacy urbantype because it is missing on 91.5% of rows, so an
*                urban share is available from 2019 forward but cannot be
*                carried back. A county-year urban share built from these files
*                alone would be sound
*   injurytype   Person-level KABCO, and it reconciles exactly: summing Fatal
*                Injury rows gives 224 in 2019, 215 in 2020, 273, 215, 275, 238
*                and 251, matching Number Of Fatalities in every year. This is
*                the file section 4 asks for. It is still not merged, because
*                doing so would add person-injury counts that exist for seven
*                years of a twenty-nine year panel
*
* Both would need the same treatment: build them here, leave them missing for
* 1997-2018, and document the coverage break the way animal_data_usable does

tempfile new_crashes_final
save `new_crashes_final', replace

/*-----------------SECTION 4: AccdPerson_Injury coverage report --------------*/


/* [> person level injuries, reported on but NOT merged <] */

* AccdPerson_Injury would give person-level KABCO detail that the crash-level
* severity in AccdMain cannot: how many people sustained a suspected serious
* injury, not just how many crashes had one. It is not used, and the reason is
* coverage, not preference.
*
* The export is clipped at Excel's ceiling of 1,048,575 rows like the
* circumstance file, but it lands far worse: it reaches only 411,243 of the
* 595,514 crashes, so 30.9% of crashes have no person record at all. The gap
* is spread almost uniformly across every year in the panel, from 27.3% in
* 2003 to 34.3% in 1997, which means it cannot be fixed by restricting the
* sample to well-covered years. Summing "Fatal Injury" persons gives 3,984
* against 5,754 fatalities in AccdMain, i.e. about 69%, which is the same
* shortfall seen from the other direction.
*
* Coding unmatched crashes as zero, the way section 5 does for animal and
* circumstance flags, is defensible when 0.29% are missing and indefensible
* when 31% are. Any county-year person-injury count built from this file would
* understate by roughly a third, unevenly across counties.
*
* To use it, request the export again split across sheets or as CSV so it is
* not truncated, then flatten it to crash level with a collapse (sum) of
* indicators per injury name and merge it in section 5 alongside the others.
* The block below only reports coverage so the next person does not have to
* rediscover the problem
*
* PARTLY SUPERSEDED for 2019-2025. The annual exports in section 3B carry an
* Injury Type column that reconciles exactly against Number Of Fatalities in
* all seven years, so the request above is only needed for 1997-2018 now. The
* variables are still not built, because they would exist for seven years of a
* twenty-nine year panel; see the note at the end of section 3B
*
*
* Verified 09/01/2026 against AccdPerson_Injury.xlsx. 63 rows carry a BLANK
* injury name, which would need a decision (drop or treat as unknown) if these
* variables are ever built.
*
* THE TWO TRUNCATIONS ARE INDEPENDENT AND SHAPED DIFFERENTLY. AccdEvent's clip
* is chronological and hits zero in 2020; this one is near-uniform at roughly a
* third in every year. So 2020 has NO event records but does have person
* records at the usual rate. Do not infer one file's coverage from the other's

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
replace animal_collision = 0 if missing(animal_collision)
replace wild_collision = 0 if missing(wild_collision)
replace animal_first_collision = 0 if missing(animal_first_collision)
replace wild_first_collision = 0 if missing(wild_first_collision)
replace alcohol_collision = 0 if missing(alcohol_collision)
replace drug_collision = 0 if missing(drug_collision)
replace dui_collision = 0 if missing(dui_collision)
replace animal_circ_collision = 0 if missing(animal_circ_collision)
replace drowsy_collision = 0 if missing(drowsy_collision)
replace distracted_collision = 0 if missing(distracted_collision)
replace speeding_collision = 0 if missing(speeding_collision)

drop fldaccidentid

/* [> append the 2019-2025 crash records <] */

* Appended HERE, after the legacy merges and zero-filling and before anything
* is derived, so that every variable built below is built once and identically
* for both deliveries. The alternative, deriving severity and the interactions
* separately in each source block, is how the two halves of a panel drift apart
*
* The zero-filling above is a legacy-only step: it exists because a crash can
* be absent from AccdEvent or AccdUnit_ContribCirc entirely. In the annual
* exports a crash's events and circumstances live in that crash's own rows, so
* section 3B generates every flag as a 0/1 byte with no missings to fill. A
* crash with nothing recorded gets a 0, which is the same substantive statement
* the zero-filling above makes
*
* accidentid is dropped rather than appended alongside fldaccidentid. They are
* the same identifier and could be unified, but nothing below section 5 uses a
* crash id and carrying one would only invite a merge on it later
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

* Info from the ID severity code list. ID reports five categories on the
* KABCO scale; AZ reports a numeric code where 4 is major injury and 2 and 3
* are both folded into minor. To keep minor_injury_collision comparable across
* the two states, B and C injuries are pooled here the same way AZ pools 2 and
* 3. possible_injury_collision then carries the C injuries on their own as an
* ID-only detail, so it is a SUBSET of minor_injury_collision, not a sibling.
* B injuries alone are minor_injury_collision - possible_injury_collision
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

/* [> conditions at the time of the crash <] */

* These come from AccdMain for 1997-2018 and from Light Condition, Road
* Surface Condition and Weather Condition 1 in the annual exports for
* 2019-2025. Close to complete in both. Legacy: light_condition missing on
* 0.24% of crashes, road_surface 0.24%, weather 0.27%. Annual exports: 0.15%,
* 0.48% and 0.11%. A missing value scores 0 on every flag below, so the flags
* understate very slightly rather than going missing. The
* darkness variables matter for this project specifically because deer
* movement peaks around dawn and dusk, so the animal crossings below are the
* point of including them at all
gen dark_collision = inlist(light_condition, ///
                            "Dark, No Street Lights", ///
                            "Dark, Street Lights On", ///
                            "Dark, Street Lights Off")
gen dawn_dusk_collision = (light_condition == "Dawn or Dusk")

* "Water - standing/moving" is matched on a substring because ID writes it
* with an en dash, which does not survive every editor and encoding this file
* passes through
gen wet_surface_collision = (road_surface == "Wet" | ///
                             strpos(road_surface, "standing/moving") > 0)
gen ice_snow_collision = inlist(road_surface, "Ice", "Snow", "Slush")

gen adverse_weather_collision = inlist(weather, ///
                                       "Rain", ///
                                       "Snow", ///
                                       "Blowing Snow", ///
                                       "Sleet/Hail", ///
                                       "Fog", ///
                                       "Smoke/Smog", ///
                                       "Severe Cross Winds", ///
                                       "Blowing Dust/Sand")

* month arrives as a name, not a number. October through December is the
* rut and the peak DVC window, and it is also the seasonal peak in the raw
* data: December, November and October are the three heaviest months of the
* year for all crashes
gen fall_collision = inlist(month, "October", "November", "December")

drop light_condition road_surface weather month

/* [> animal collisions, all animals <] */

gen fatal_animal_collision = animal_collision*fatal_collision
gen injury_animal_collision = animal_collision*injury_collision
gen major_injury_animal_collision = animal_collision*major_injury_collision
gen minor_injury_animal_collision = animal_collision*minor_injury_collision
gen possible_injury_animal_collision = animal_collision*possible_injury_collision
gen pdo_animal = animal_collision*pdo_collision
gen animal_fatalities = animal_collision*total_fatalities
gen animal_injuries = animal_collision*total_injuries
gen animal_persons = animal_collision*total_persons

gen dark_animal = animal_collision*dark_collision
gen dawn_dusk_animal = animal_collision*dawn_dusk_collision
gen ice_snow_animal = animal_collision*ice_snow_collision
gen fall_animal = animal_collision*fall_collision

/* [> wild animal collisions <] */

* "wild" throughout this file means the Animal - Wild event code, i.e. a
* subset of animal_collision rather than an alternative to it
gen fatal_wild_collision = wild_collision*fatal_collision
gen injury_wild_collision = wild_collision*injury_collision
gen major_injury_wild_collision = wild_collision*major_injury_collision
gen minor_injury_wild_collision = wild_collision*minor_injury_collision
gen possible_injury_wild_collision = wild_collision*possible_injury_collision
gen pdo_wild = wild_collision*pdo_collision
gen wild_fatalities = wild_collision*total_fatalities
gen wild_injuries = wild_collision*total_injuries
gen wild_persons = wild_collision*total_persons

gen dark_wild = wild_collision*dark_collision
gen dawn_dusk_wild = wild_collision*dawn_dusk_collision
gen ice_snow_wild = wild_collision*ice_snow_collision
gen fall_wild = wild_collision*fall_collision

/* [> animal, from the circumstance file instead of the event file <] */

* animal_circ_collision is an independent measurement of the same thing. The
* event side records that a vehicle struck an animal (AccdEvent for 1997-2018,
* the Events column for 2019-2025); the circumstance side records that an
* animal in the roadway contributed to the crash (AccdUnit_ContribCirc, then
* Contrib Circ 1-3). They will not agree, and the disagreement is informative
* rather than a bug: a swerve ending in a rollover with no strike is a
* circumstance and not an event, and a strike the officer did not treat as
* causal is the reverse. Carrying both plus the union lets the analysis file
* pick a definition
*
* animal_any_collision below IS THE UNION MEASURE, built in section 3B from
* columns U:Y and deduplicated to one row per crash; see the note at the head
* of that section for why U is kept in
gen animal_any_collision = (animal_collision == 1 | animal_circ_collision == 1)
gen fatal_animal_any = animal_any_collision*fatal_collision
gen injury_animal_any = animal_any_collision*injury_collision
gen major_injury_animal_any = animal_any_collision*major_injury_collision
gen minor_injury_animal_any = animal_any_collision*minor_injury_collision
gen pdo_animal_any = animal_any_collision*pdo_collision
gen animal_any_fatalities = animal_any_collision*total_fatalities
gen animal_any_injuries = animal_any_collision*total_injuries

* Severity splits on the circumstance-only measure, so that all three animal
* constructs carry the same breakdown and an analysis can switch between them
* without discovering that one of them stops at a bare count
gen fatal_animal_circ = animal_circ_collision*fatal_collision
gen injury_animal_circ = animal_circ_collision*injury_collision
gen pdo_animal_circ = animal_circ_collision*pdo_collision
gen animal_circ_fatalities = animal_circ_collision*total_fatalities
gen animal_circ_injuries = animal_circ_collision*total_injuries

* The event and circumstance measures should overlap heavily but not exactly
tab animal_collision animal_circ_collision

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

* These are the crashes the DVC counts should arguably not include: an animal
* strike reported by a driver who was also flagged as impaired. Carrying them
* as their own variables rather than silently dropping them means the
* county-year file supports both the full series and the excluded series
gen dui_animal_collision = dui_collision*animal_collision
gen fatal_dui_animal = dui_animal_collision*fatal_collision
gen injury_dui_animal = dui_animal_collision*injury_collision
gen pdo_dui_animal = dui_animal_collision*pdo_collision
gen dui_animal_fatalities = dui_animal_collision*total_fatalities
gen dui_animal_injuries = dui_animal_collision*total_injuries

gen dui_wild_collision = dui_collision*wild_collision
gen fatal_dui_wild = dui_wild_collision*fatal_collision
gen injury_dui_wild = dui_wild_collision*injury_collision
gen pdo_dui_wild = dui_wild_collision*pdo_collision
gen dui_wild_fatalities = dui_wild_collision*total_fatalities
gen dui_wild_injuries = dui_wild_collision*total_injuries

* Same overlap on the other two animal constructs. Previously only the event
* measure and its wild subset carried these, so an analysis that used the union
* had no way to net out impaired drivers and would have been comparing a
* DUI-inclusive animal count against a DUI-exclusive one
gen dui_animal_any_collision = dui_collision*animal_any_collision
gen fatal_dui_animal_any = dui_animal_any_collision*fatal_collision
gen injury_dui_animal_any = dui_animal_any_collision*injury_collision
gen pdo_dui_animal_any = dui_animal_any_collision*pdo_collision
gen dui_animal_any_fatalities = dui_animal_any_collision*total_fatalities
gen dui_animal_any_injuries = dui_animal_any_collision*total_injuries

gen dui_animal_circ_collision = dui_collision*animal_circ_collision
gen fatal_dui_animal_circ = dui_animal_circ_collision*fatal_collision
gen injury_dui_animal_circ = dui_animal_circ_collision*injury_collision
gen pdo_dui_animal_circ = dui_animal_circ_collision*pdo_collision

* There is usually a tiny overlap between animal and impaired collisions
tab animal_collision dui_collision
tab wild_collision dui_collision

/* [> county name cleaning <] */

* All 44 Idaho counties appear under their standard names in both deliveries,
* and all 44 appear in all seven annual exports. Legacy AccdMain carries one
* row with a blank county, dropped after the collapse; the annual exports carry
* none. Confirmed 09/01/2026: fldCountyName takes 45 distinct values in
* AccdMain, the 44 counties plus a single null on one 2007 crash, which is why
* the drop below is a one-row operation and not a data quality problem.
*
* There is no "St." county in Idaho, so the subinstr fix that earlier versions
* of this file carried over from other states was doing nothing here and has
* been removed. The name that actually needs watching on the merge in section
* 6 is "nez perce", which some crosswalks store closed up as "nezperce"
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
               dark_collision ///
               dawn_dusk_collision ///
               wet_surface_collision ///
               ice_snow_collision ///
               adverse_weather_collision ///
               fall_collision ///
               animal_collision ///
               animal_first_collision ///
               has_event_record ///
               fatal_animal_collision ///
               injury_animal_collision ///
               major_injury_animal_collision ///
               minor_injury_animal_collision ///
               possible_injury_animal_collision ///
               pdo_animal ///
               animal_fatalities ///
               animal_injuries ///
               animal_persons ///
               dark_animal ///
               dawn_dusk_animal ///
               ice_snow_animal ///
               fall_animal ///
               wild_collision ///
               wild_first_collision ///
               fatal_wild_collision ///
               injury_wild_collision ///
               major_injury_wild_collision ///
               minor_injury_wild_collision ///
               possible_injury_wild_collision ///
               pdo_wild ///
               wild_fatalities ///
               wild_injuries ///
               wild_persons ///
               dark_wild ///
               dawn_dusk_wild ///
               ice_snow_wild ///
               fall_wild ///
               animal_circ_collision ///
               fatal_animal_circ ///
               injury_animal_circ ///
               pdo_animal_circ ///
               animal_circ_fatalities ///
               animal_circ_injuries ///
               animal_any_collision ///
               fatal_animal_any ///
               injury_animal_any ///
               major_injury_animal_any ///
               minor_injury_animal_any ///
               pdo_animal_any ///
               animal_any_fatalities ///
               animal_any_injuries ///
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
               dui_wild_collision ///
               fatal_dui_wild ///
               injury_dui_wild ///
               pdo_dui_wild ///
               dui_wild_fatalities ///
               dui_wild_injuries ///
               dui_animal_any_collision ///
               fatal_dui_animal_any ///
               injury_dui_animal_any ///
               pdo_dui_animal_any ///
               dui_animal_any_fatalities ///
               dui_animal_any_injuries ///
               dui_animal_circ_collision ///
               fatal_dui_animal_circ ///
               injury_dui_animal_circ ///
               pdo_dui_animal_circ ///
               drowsy_collision ///
               distracted_collision ///
               speeding_collision ///
               (max) source_new_export, ///
               by(county_name year)

* Cleanup. One crash in legacy AccdMain has no county and cannot be placed in
* the panel; no crash in the annual exports is missing one. "total" is not
* present in either ID delivery but is dropped for symmetry with the AZ file,
* where the source spreadsheet does carry a total row
drop if county_name == "" | county_name == "total"

/* [> derived series <] */

* Share of this county-year's crashes with event information recorded. Where
* this is below 1 the animal counts are mechanically understated, because a
* crash with no event record contributes a zero to animal_collision
*
* The measure means the same thing on both sides of the source cut but is
* built differently: for 1997-2018 it is whether the crash appears in the
* truncated AccdEvent export at all, and for 2019-2025 it is whether the
* crash's own rows carry any Events or Most Harmful Event value. See the notes
* in sections 2 and 3B
rename has_event_record crashes_with_event_rec
gen event_record_coverage = crashes_with_event_rec / total_all_cause

* Threshold is deliberately strict. At 99% the understatement is within the
* noise of a county-year count; below that it starts to be the whole series.
* Anything failing this cannot support a DVC count no matter how the
* regression is specified
gen animal_data_usable = (event_record_coverage >= 0.99)

di as text "Event coverage by year. Animal counts are only usable where this is at or near 1:"
tabstat event_record_coverage, by(year) statistics(mean min max) format(%9.4f)

* Before the source cut this warning fired across 2019 and 2020 by design,
* because the legacy AccdEvent export reached 64.72% of 2019 crashes and none
* at all in 2020. With those years now coming from the annual exports, every
* year should clear the threshold and this block should stay silent. If it
* fires it is news about a delivery, not a known defect being restated
qui count if animal_data_usable == 0
if r(N) > 0 {
    di as error "WARNING: `r(N)' county-year cells have incomplete event coverage."
    di as error "Their animal and wild variables are NOT usable. No year is expected to fail this."
    qui levelsof year if animal_data_usable == 0, local(bad_years)
    di as error "Affected years: `bad_years'"
    di as error "Check whether a new delivery is truncated the way AccdEvent was."
}

* 2020 IS CARRIED AS AN ORDINARY PANEL YEAR and there is deliberately no
* covid_year indicator. 2020 is complete in the data: all twelve months,
* crashes through 31 December, and the low all-cause count is the pandemic
* itself rather than a coverage gap. The flag is dropped for cross-state
* consistency, since no other state file in this repo carries one and it is
* only ever (year == 2020) if an analysis wants it

* Blanking the animal variables where the event file does not cover them.
* Set to 0 to keep the raw sums instead, but then nothing stops a regression
* from reading a truncated cell as a real zero, which would show up as a large
* and entirely spurious drop in deer collisions. Missing is the honest value
* here: the count is unknown, not low
*
* No cell is expected to be blanked any more. The block is kept because it is
* the guard that made the old AccdEvent truncation visible instead of silent,
* and the next delivery is not guaranteed to be clean either
local blank_animal_when_incomplete = 1

if `blank_animal_when_incomplete' == 1 {

    * Pattern rather than a hand-kept list, so that a variable added to the
    * animal or wild families later cannot quietly escape the blanking. Two
    * exclusions: animal_data_usable is the flag doing the blanking and must
    * survive it, and nothing in the animal_circ family comes from the event
    * file at all, so the truncation does not apply to any of it
    *
    * The circ exemption is matched on the substring rather than named variable
    * by variable, because that family now has severity splits and a DUI
    * interaction and the next one added would get blanked by accident
    foreach v of varlist *animal* *wild* {
        if "`v'" != "animal_data_usable" & strpos("`v'", "animal_circ") == 0 {
            replace `v' = . if animal_data_usable == 0
        }
    }
}

* animal_circ_collision is left populated deliberately. It does not come from
* the event side of either delivery, so a truncation there does not touch it.
* It is a different construct from the event-based flag, counting crashes an
* animal in the roadway contributed to rather than crashes where a vehicle
* struck one, and the two are worth carrying side by side
*
* animal_any_collision and its severity splits are blanked with the rest,
* because the union embeds the event flag and so inherits any truncation in it

* Animal collisions excluding the impaired-driver overlap. Generated by
* subtraction so the two series can never disagree with each other
gen animal_collision_no_dui = animal_collision - dui_animal_collision
gen fatal_animal_no_dui = fatal_animal_collision - fatal_dui_animal
gen injury_animal_no_dui = injury_animal_collision - injury_dui_animal
gen pdo_animal_no_dui = pdo_animal - pdo_dui_animal
gen animal_fatalities_no_dui = animal_fatalities - dui_animal_fatalities
gen animal_injuries_no_dui = animal_injuries - dui_animal_injuries

gen wild_collision_no_dui = wild_collision - dui_wild_collision
gen fatal_wild_no_dui = fatal_wild_collision - fatal_dui_wild
gen injury_wild_no_dui = injury_wild_collision - injury_dui_wild
gen pdo_wild_no_dui = pdo_wild - pdo_dui_wild
gen wild_fatalities_no_dui = wild_fatalities - dui_wild_fatalities
gen wild_injuries_no_dui = wild_injuries - dui_wild_injuries

* Same treatment for the union and circumstance measures, added so that the
* "an impaired driver's animal strike counts as impaired, not as an animal
* crash" rule can be applied to whichever animal definition the analysis picks
* rather than only to the event-based one
gen animal_any_no_dui = animal_any_collision - dui_animal_any_collision
gen fatal_animal_any_no_dui = fatal_animal_any - fatal_dui_animal_any
gen injury_animal_any_no_dui = injury_animal_any - injury_dui_animal_any
gen pdo_animal_any_no_dui = pdo_animal_any - pdo_dui_animal_any

gen animal_circ_no_dui = animal_circ_collision - dui_animal_circ_collision
gen fatal_animal_circ_no_dui = fatal_animal_circ - fatal_dui_animal_circ
gen injury_animal_circ_no_dui = injury_animal_circ - injury_dui_animal_circ
gen pdo_animal_circ_no_dui = pdo_animal_circ - pdo_dui_animal_circ

* Sanity check: no negative counts, and every subset no larger than the
* superset it was built from. possible_injury is checked against minor rather
* than against injury because it is defined as a subset of minor
*
* Checks that do not touch the event file, so they hold in every cell
assert possible_injury_collision <= minor_injury_collision ///
       & major_injury_collision + minor_injury_collision == injury_collision ///
       & fatal_collision + injury_collision + pdo_collision == total_all_cause ///
       & alcohol_collision <= dui_collision ///
       & drug_collision <= dui_collision ///
       & crashes_with_event_rec <= total_all_cause

* Animal checks are restricted to cells the event file actually covers. Where
* animal_data_usable is 0 these variables are missing by design, and Stata
* orders missing above every number, so an unrestricted "animal_collision <=
* total_all_cause" would fail on exactly the rows that were blanked on purpose
assert animal_collision_no_dui >= 0 ///
       & wild_collision_no_dui >= 0 ///
       & animal_any_no_dui >= 0 ///
       & wild_collision <= animal_collision ///
       & animal_first_collision <= animal_collision ///
       & wild_first_collision <= wild_collision ///
       & dui_animal_collision <= dui_collision ///
       & dui_animal_any_collision <= dui_collision ///
       & dui_animal_collision <= dui_animal_any_collision ///
       & animal_collision <= animal_any_collision ///
       & animal_circ_collision <= animal_any_collision ///
       & major_injury_animal_any + minor_injury_animal_any == injury_animal_any ///
       & animal_collision <= total_all_cause ///
       if animal_data_usable == 1

* Circumstance-side checks, which hold in EVERY cell rather than only the
* usable ones, because this family is exempt from the blanking above
assert animal_circ_no_dui >= 0 ///
       & dui_animal_circ_collision <= dui_collision ///
       & dui_animal_circ_collision <= animal_circ_collision ///
       & fatal_animal_circ + injury_animal_circ + pdo_animal_circ ///
         == animal_circ_collision ///
       & animal_circ_collision <= total_all_cause

* And where they are not usable, they should be uniformly missing rather than
* partly blanked, which would mean the foreach varlist above missed a variable
if `blank_animal_when_incomplete' == 1 {
    assert missing(animal_collision) & missing(wild_collision) ///
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

order state_letter_code ///
      state_name          ///
      county_name         ///
      state_fips          ///
      county_fips         ///
      fips                ///
      year                ///
      source_new_export   ///
      event_record_coverage ///
      crashes_with_event_rec ///
      total*              ///
      animal*             ///
      wild*               ///
      alcohol*            ///
      drug*               ///
      dui*

* animal_data_usable is placed here rather than in the varlist above, where
* naming it explicitly and letting animal* match it listed it twice
order animal_data_usable, after(source_new_export)

label variable source_new_export ///
    "1 = year built from the annual UofChicago export, 0 = legacy AccdMain delivery"

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
compress
save "$working_data/dvcs_ID_county_year_`T1'_`T2'.dta", replace

di as text _newline "Saved: $working_data/dvcs_ID_county_year_`T1'_`T2'.dta"
di as text "Log:   $working_data/dvcs_ID_build.log"

cap log close
