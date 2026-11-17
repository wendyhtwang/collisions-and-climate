/*******************************************************************************
Program: data_dvcs_county_year.do  [ILLINOIS]
Current Lead:  Charvi Khandelwal
Major Versions/Revisions:
09/09/2026 [Charvi Khandelwal]: added 2009-2024 data
09/15/2026 [Charvi Khandelwal]: adapted the IL code to match IA
09/18/2026 [Charvi Khandelwal]: troubleshooted the code; it now runs end to end
*******************************************************************************/
/**********************************************************************/
/*-----------------SECTION 0: root directory --------------*/

cap log close _all
clear all
set more off, permanently
set scheme s1mono

* VERSION FLOOR, and it is a real constraint rather than boilerplate. Every
* import in this file passes bindquote() to import delimited, which was added
* in Stata 15. The option is not optional here: the IL fields are quoted AND
* several of them contain commas inside the quotes ("Divided, No Median
* Barrier", "Darkness, Lighted Road", "50,000 and OVER"), so how quotes are
* treated decides whether a row has 73 fields or 78, and the row-count guard
* in section 1A depends on being able to ask for nobind specifically
*
* The ID file notes that this repo still runs on versions old enough to lack
* table's statistic() option, which is why this is checked out loud rather
* than assumed. On Stata 14 or earlier, read the extracts with insheet or
* preprocess them to tab-delimited first; do not simply drop the option
if c(stata_version) < 15 {
    di as error "This file needs Stata 15 or later. Running: " c(stata_version)
    di as error "import delimited's bindquote() option was added in Stata 15, and"
    di as error "the IL extracts cannot be parsed correctly without it: several"
    di as error "fields contain commas inside their quotes, so quote handling"
    di as error "determines the field count. See the note in section 0."
    error 9
}

* NOT set here, unlike the ID file. set excelxlsxlargefile applies to
* import excel and this file never calls it: every IL input is delimited text
* read with import delimited, which has no row ceiling. That absence is the
* single biggest structural difference between the two states and it is good
* news. The three Excel truncations that shape the entire ID file (AccdEvent
* clipped at 1,048,575 rows and chronologically, AccdUnit_ContribCirc clipped
* and scattered, AccdPerson_Injury clipped to 69% of fatalities) have no
* analogue here. Coverage was measured on the 2009 delivery and every file is
* complete; see the figures in sections 2 and 3

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

* One level deeper than the ID file. ID keeps its workbooks directly in
* dataRAW/DVCs/ID; IL splits the delivery into one folder per year under
* crash_records_level, so $raw is the parent of those folders and the year
* folder name is built in section 0B
global raw "$path/dataRAW/DVCs/IL/crash_records_level"

di as text "Research directory: $rootDir"

local pathok = 0
mata: st_local("pathok", strofreal(direxists("$path")))
if `pathok' == 0 {
  di as error "$path does not exist."
  di as error "rootDir resolved to $rootDir but it holds no VehicleCollisionsDataRepo."
  error 601
}

cap mkdir "$working_data"
log using "$working_data/dvcs_IL_build.log", replace text

* Set to 0 to see everything import delimited, destring and merge have to say.
*
* WHAT THIS SUPPRESSES AND WHY. import delimited prints a note for EVERY row
* where it meets an unmatched quote, and the free-text object-struck and
* hospital fields produce those in bulk: several hundred notes in a bad year,
* each four lines long, which buries the reporting this file actually does.
* They are not warnings about anything the file has not already measured.
* Every one of them is either a stray inch mark, which bindquote(loose)
* handles correctly, or an embedded newline, which the row-validity filters
* catch and count in the misparse table at the end of section 1.
*
* The same prefix quiets destring, which otherwise prints a line per variable
* per year, and merge, which prints a match table on every call. Both are
* replaced by explicit counts in the code below, so nothing is lost
*
* SET IT TO 0 IF A YEAR MISBEHAVES. Stata's own notes name the offending row
* numbers, which is the fastest way to find a malformed record by hand.
* Errors are never suppressed: quietly hides output, not failures
local terse = 1

if `terse' == 1 {
    local q "quietly"
}
else {
    local q ""
}

* collapse writes "(sum) x" or "(max) x" as the variable label of everything
* it touches. Those artefacts then head every tab and tabstat for the rest of
* the run and travel into the delivered dta, so each of the three collapses
* below is followed by a call to this. Ported from the ID file
*
* Matched on the prefix rather than cleared wholesale, so that the labels the
* crosswalk supplies for state_name and the FIPS columns survive section 5
capture program drop strip_collapse_labels
program define strip_collapse_labels
    foreach v of varlist _all {
        local lbl : variable label `v'
        if substr("`lbl'", 1, 6) == "(sum) " | substr("`lbl'", 1, 6) == "(max) " {
            label var `v' ""
        }
    }
end

* Set to 0 to skip the person-file injury reconciliation report in section 3.
* It costs no extra pass (the person file is already open) and it is what
* establishes that the KABCO codes mean what section 3 assumes, so leaving it
* on is cheap
local check_person_injury = 1

* Folder naming. Every year sits in $raw/IllinoisCrashDataExtracts<YYYY> and
* holds the same three files. Held in a local rather than hardcoded three
* times so a delivery that renames the folders is a one-line edit
local folder_stub "IllinoisCrashDataExtracts"

* Years to look for. This is a SEARCH RANGE, not an assertion: section 0B keeps
* whatever exists and reports the rest, so widening it costs nothing and a
* missing year is visible in the log rather than silently absent from the panel
*
* There is deliberately no legacy/new source cut in this file. The ID panel is
* built from two deliveries that overlap in 2019-2020 and needs
* `legacy_end_year' and `new_start_year' to arbitrate between them. IL is one
* delivery in one format, so a crash comes from exactly one place by
* construction and the seam machinery in ID section 3B has nothing to do here
local scan_first_year = 1990
local scan_last_year  = 2030


/*-----------------SECTION 0B: resolve inputs before reading any of them -----*/

* The crosswalk path differs between files in this repo (dataSTATA/_AUX/ vs
* dataSTATA/), so both are checked and whichever exists is used
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

local rawok = 0
mata: st_local("rawok", strofreal(direxists("$raw")))
if `rawok' == 0 {
    di as error "$raw does not exist."
    di as error "Expected the per-year folders under:"
    di as error "  $path/dataRAW/DVCs/IL/crash_records_level"
    error 601
}

* Discover which years are actually present, and require all three files in
* each. A year folder holding only two of the three is treated as an error
* rather than as a partial year: the animal flags come from VehicleExtract and
* the impairment flags from PersonExtract, so a crash-file-only year would
* enter the panel with every flag at zero and look like a real absence of deer
di as text _newline "Scanning $raw for year folders named `folder_stub'<YYYY>:"

global il_years ""
local bad_years ""

forvalues yr = `scan_first_year'/`scan_last_year' {

    local ydir "$raw/`folder_stub'`yr'"
    local yrok = 0
    mata: st_local("yrok", strofreal(direxists("`ydir'")))

    if `yrok' == 1 {

        local nmiss = 0
        foreach f in CrashExtract VehicleExtract PersonExtract {
            capture confirm file "`ydir'/`f'.txt"
            if _rc != 0 {
                di as error "  `yr': MISSING `f'.txt"
                local nmiss = `nmiss' + 1
            }
        }

        if `nmiss' == 0 {
            global il_years "$il_years `yr'"
            di as text "  `yr': ok (Crash, Vehicle, Person)"
        }
        else {
            local bad_years "`bad_years' `yr'"
        }
    }
}

if "`bad_years'" != "" {
    di as error _newline "Year folders present but incomplete:`bad_years'"
    di as error "Each year needs CrashExtract.txt, VehicleExtract.txt and"
    di as error "PersonExtract.txt. A year with only some of the three would"
    di as error "enter the panel with its animal or impairment flags all zero,"
    di as error "which is indistinguishable from a real absence. Fix the folder"
    di as error "or move it aside, then rerun."
    error 601
}

if "$il_years" == "" {
    di as error _newline "No usable year folders found in $raw."
    di as error "Contents:"
    capture noisily dir "$raw"
    di as error "Expected folders named `folder_stub'<YYYY>, e.g. `folder_stub'2009."
    error 601
}

local n_years : word count $il_years
di as text _newline "`n_years' year(s) located:$il_years"
di as text "All required inputs located. Starting the build."


/*-----------------SECTION 0C: the positional column layout --------------*/

* THIS IS THE SECTION TO READ BEFORE CHANGING ANYTHING ELSE.
*
* The IL extracts have NO HEADER ROW. Every field is double-quoted, comma
* delimited, and identified only by its position. import delimited therefore
* names the columns v1, v2, ... vN and the mapping from position to meaning
* lives here and nowhere else.
*
* That makes this file structurally more fragile than the ID file and the
* fragility is of a specific kind. ID section 3B can check that column U is
* still called "Events" and stop if it is not. Here there is no name to check,
* so a delivery that INSERTS OR DROPS A COLUMN would shift everything to its
* right and the file would keep running, reading (say) road surface as
* lighting. The guard that replaces the header check is a VALUE DOMAIN test:
* each column this file uses is asserted to hold only values from its known
* vocabulary, which is what a shift would break. See `layout guard' in
* sections 1, 2 and 3. Do not remove those blocks to save a pass over the data
*
* FIELD COUNTS ARE A FLOOR, NOT A FIXTURE, and this is the most important
* thing to know before running this file on a new year:
*
*               2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 needs
*   CrashExtract  73   77   77   77   77   77   77   77   77   77   82   82   82   83   83   83  >=73
*   VehicleExtract 39  40   40   40   41   41   41   41   41   41   46   46   46   47   47   47  >=39
*   PersonExtract 32   33   33   33   34   34   34   34   34   34   38   37   37   39   39   41  >=32
*
* 2019 ONWARD IS PIPE DELIMITED, not comma. The counts above are the
* pipe-parsed counts for those years; read as CSV they come back as one or
* two fields per row. See the delimiter block at the head of section 1A
*
* A FILE CAN SHRINK. PersonExtract goes from 38 fields in 2019 to 37 in 2020
* because the date of birth was dropped, which is why the field-count guards
* are a floor and not a running maximum
*
* AND A FILE CAN SHIFT NON-UNIFORMLY. 2020 inserts a column at position 2 and
* removes one at position 5 in the person file, so the net offset is +1 for
* columns 2-4 and 0 from column 5 on. One offset per file is not enough to
* describe that, which is why the person type code is located by content
* instead. See the note in section 1C
*
* 2010 APPENDED its new columns, so positions kept their meaning. 2013 does
* something different and worse: the vehicle and person files INSERT a record
* id at position 2, so every column after it moves by one. The most harmful
* event goes from v29 to v30, the injury classification from v13 to v14, the
* driver condition from v24 to v25.
*
* POSITIONS ARE THEREFORE NO LONGER HARDCODED. Each of the three import blocks
* searches for an ANCHOR column with an unmistakable vocabulary, computes the
* offset from where the anchor should be, and applies that offset to the
* baseline map recorded below. The anchors are severity (mostly "Property
* Damage"), the most harmful event (mostly "Motor Vehicle in Traffic") and the
* person type (mostly "Driver"). Position 1 is the crash id in all three files
* and is never shifted, because an insertion at position 2 leaves it alone.
*
* The baseline map is the 2009-2012 layout. The offset is 0 for all three
* files in 2009-2012, 0 for the crash file in every year so far, and 1 for the
* vehicle and person files from 2013 on.
*
* THE FIELD COUNT IS STILL ONLY A FLOOR, and it is no longer the thing that
* establishes alignment: a delivery can insert one column and append another
* and come out at the same count. The anchor search is what pins the layout,
* and the value-domain checks are what confirm it landed correctly
*
* The four columns 2010 adds to CrashExtract are v74 (constant "N"), v75
* (constant "(N/A)"), v76 (constant "N") and v77, a WORK ZONE TYPE taking
* Construction on 5,593 crashes, Maintenance on 162, Unknown on 159 and
* Utility on 100. VehicleExtract gains v40, "N" on all but one row, and
* PersonExtract gains v33, "(N/A)" on all but eight. 2011 carries the same
* four, still near-constant. None are built into
* variables here, for the reason ID gives for its urban and injurytype
* columns: they would exist for one year of a multi-year panel. v77 is worth
* revisiting once enough years carry it, since 2009 can only approximate a
* work zone through the road-defect column
*
* Many fields arrive TWICE, once as a numeric code and once as a decoded
* string. Where both exist this file reads the STRING, for two reasons: the
* strings are self-documenting in the code below, and the numeric code books
* are not in the repo. The code column is used only where there is no string
* counterpart (county code, the A/B/C injury counts, the date parts)
*
* CrashExtract.txt, the columns this file uses:
*   v1   crash id                    12-char, e.g. 200901010101. See the note
*                                    on id formats below
*   v3   county code                 001-102, IDOT's alphabetical sequence
*   v4   year, 2 digit               constant within a file
*   v5   month, 01-12                numeric, unlike ID where month is a name
*   v7   number of units             matches the VehicleExtract row count for
*                                    292,435 of 292,436 crashes
*   v14  persons killed              sums to 911 for 2009, which is the
*                                    published IL total for that year
*   v15  persons injured             equals v17+v18+v19 exactly
*   v17  A injuries                  13,009 in 2009
*   v18  B injuries                  40,786
*   v19  C injuries                  35,420
*   v20  crash severity              Fatal / Injury / Property Damage
*   v49  county name                 all 102 counties, no blanks
*   v51  crash type                  15 values, one of which is "Animal"
*   v54  road class                  carries the urban/rural split
*   v55  cause 1                     36 values
*   v56  cause 2                     37 values
*   v59  road surface condition
*   v62  lighting condition
*   v63  weather condition
*
* Dropped on purpose: v2 (a second internal id), v6 (day), v8/v50 (day of
* week), v9 (hour), v10/v52 (city), v11/v53 (population group), v22/v23 (route
* and milepost), v34 (time of day), v38 (date, duplicates v4 and v5), v45-v48
* (coordinates), v57/v58 (traffic control), v60 (road defect), v64 (alignment),
* v65 (trafficway type), v66 (functional class), v71-v73 (report number parts).
* None aggregate usefully to county-year or have a counterpart in the other
* state files in this repo
*
* NOT USED, AND THE REASON MATTERS:
*   v16   "number of persons". It undercounts: it sums to 601,465 against
*         683,640 person rows and agrees with the person row count on only
*         76.5% of crashes. total_persons is therefore built by COUNTING
*         PERSON ROWS in section 3 rather than read from here. The ID file
*         takes fldPersons at face value because there it reconciles; this
*         field does not, so it is left alone
*   v61,  most severe injury, decoded and coded. Both are unusable as
*   v68   delivered: v68 mixes two coding systems in the same column (letters
*         A/B/C/0 on some rows, digits 0-4 on others) and v61 decodes only the
*         digit era, so it is blank on 275,091 of 292,437 rows. Crash severity
*         is taken from v20 and the A/B/C split from the v17-v19 counts, both
*         of which are complete and internally consistent
*   v69,  free-text description of the object struck ("Deer", "DEER",
*   v70   "FENCE", "UTILITY POLE"). 6,547 distinct spellings in one year,
*         case-inconsistent, and it is the field that carries the CSV defect
*         described in section 1. VehicleExtract gives the same information as
*         a controlled vocabulary, so this is redundant as well as messy
*
* VehicleExtract.txt, the columns this file uses:
*   v1   crash id
*   v2   unit number                 01-16
*   v29  most harmful event          45 values, decoded
*   v31  event sequence 1            42 values, decoded
*   v32  event sequence 2
*   v33  event sequence 3
*
*   v14/v17/v18/v19 are the numeric codes for v29/v31/v32/v33 and v16 is the
*   number of events in the sequence. v15/v20/v21/v22 and v30/v34/v35/v36 are
*   the LOCATION of each event (on pavement, intersection, off pavement),
*   which is worth revisiting for a road-position analysis and is not used
*   here. v3 (VIN), v23-v28 (direction, defect, maneuver, vehicle type, use)
*   and v37-v39 (year, make, model) are dropped
*
* PersonExtract.txt, the columns this file uses:
*   v1   crash id
*   v2   person type code            1 Driver, 7 Passenger, 2 Pedestrian,
*                                    3 Pedalcyclist, 6 NCV, 5 NMV, 4 Equestrian
*   v13  injury classification       0 none, 1 C, 2 B, 3 A, 4 fatal. Coding
*                                    established by reconciliation, not by a
*                                    code book: see section 3
*   v22  person type, decoded
*   v24  driver physical condition   11 values including Alcohol Impaired,
*                                    Drug Impaired, Had Been Drinking,
*                                    Asleep/Fainted, Fatigued
*
*   v3 (unit number), v4-v7 (DOB, age, sex, licence state), v14/v32 (safety
*   equipment), v15/v25 (airbag), v16/v28 (ejection), v17/v18 (EMS agency and
*   hospital, free text), v11/v29 (driver action), v10/v31 (vision obscured),
*   v9/v27 (BAC test) and v19-v21/v23/v26/v30 (pedestrian detail) are dropped.
*   BAC in particular is tempting and is left out: v27 is "Test not offered"
*   on 321,421 of 683,640 rows and holds a numeric result on only a few
*   hundred, so a BAC-based measure would be a measure of testing policy
*
* CRASH ID FORMATS ARE MIXED AND THAT IS FINE. Most ids are 12 characters
* (200901010101) but 38,923 person rows carry an 8-character id (96079116).
* Every one of them matches a crash in CrashExtract, so the two formats
* coexist within a year rather than one being an error. All ids are therefore
* kept as STRINGS and never destrung: destringing would map the two formats
* into incomparable integers and every merge below would fail. The ID file
* makes the same choice for the same reason (see its section 3B seam check)

* VOCABULARY DRIFT LOG, 2009 onward. This is what forced the matching style
* used from here on, so it is recorded rather than silently absorbed. All of
* the 2009-to-2010 movement below persists into 2011 unchanged, i.e. 2010 is
* where the delivery was re-tooled and 2011 simply matches it:
*
*   sentinels     unused cause slots went from "NA" to "(N/A)"; empty event
*                 slots went from blank to "(UNK)"; the person file's "No
*                 Data" became "Not Reported"
*   case          "Exceeding Safe Speed for Conditions" became "...For...";
*                 "Motor Vehicle in Traffic" became "...In..."; crash types
*                 went from sentence case ("Rear end") to title case ("Rear
*                 End"); county and city names went from upper to mixed case
*   renamed       "Operating Vehicle in Reckless Manner" became "Operating
*                 vehicle in erractic, reckless, careless, negligent or
*                 aggressive manner", misspelling included
*   duplicated    2010 carries BOTH "Failing to Yield Right of Way" and
*                 "Failing to yield right-of-way" as separate codes
*   mojibake      2009 mis-decodes the en dash in one distraction code, 2010
*                 and 2011 in three of the four. The dash is unreliable in
*                 both directions and nothing here may match on it
*   retired       2011 drops the "Unmarked Highway Urban" and "Unmarked
*                 Highway Rural" road classes entirely, then 2012 brings both
*                 back. See section 3
*   free text     the object-struck field carries unescaped double quotes
*                 (inch marks) in every year, and in 2012 an embedded NEWLINE
*                 as well. This dictates the parser settings in section 1A
*   commas out    2013 replaces commas inside values with slashes, presumably
*                 to stop them colliding with the delimiter: "Darkness,
*                 Lighted Road" becomes "Darkness/ Lighted Road" (note the
*                 space AFTER the slash), "Sand, Mud, Dirt" becomes "Sand /
*                 Mud / Dirt", and the electronic-device distraction code
*                 loses its commas too
*   punctuation   and then 2015 moves the space: "Darkness / Lighted Road".
*                 Three spellings of one category in three years. The domain
*                 checks canonicalise punctuation rather than listing them
*   cause codes   2021 splits the wireless-phone distraction code into
*                 "Texting" and "Cell Phone Use Other Than Texting", neither
*                 carrying the word "distraction", and drops both "Exceeding"
*                 speed codes without replacement. The first is matched
*                 explicitly; the second cannot be fixed, only reported
*   dropped col   2020 removes the date of birth from the person file, the
*                 first time any column has been taken away rather than
*                 added, and it shifts the columns after it back by one
*   DELIMITER     2019 switches the whole delivery from comma to PIPE. This
*                 is the most disruptive change in the series and the least
*                 visible: nothing about the columns moves, so a file read
*                 with the wrong delimiter fails everywhere at once rather
*                 than in one place. Detected per file in section 1A
*   weather       2019 splits out Freezing Rain, Blowing Snow and Blowing
*                 Sand, all adverse, all previously folded into Rain, Snow
*                 and Other. Both are then reworded: "Blowing Sand" becomes
*                 "Blowing Sand, Soil or Dirt" in 2022 and "Freezing Rain"
*                 becomes "Freezing Rain or Freezing Drizzle" in 2023. Every
*                 weather code introduced in 2019 has been renamed since, so
*                 all of them are matched by substring
*   impairment    2019 adds "Impaired-Alcohol and Drugs" to the person
*                 condition, a combined code that belongs in both series
*   dash back     the outside-vehicle distraction code reverts from the
*                 mojibaked en dash to a plain hyphen in 2015. The substring
*                 match on "distraction" has never cared
*   new value     2013 adds "Cloudy/Overcast" to weather, which 2009-2012
*                 must have been folding into "Clear"
*   new sentinel  2014 adds "(UNK)" to road class on 13 crashes, which is
*                 neither Urban nor Rural and scores 0 on both flags, and
*                 2016 adds "(UNK)" to COUNTY on 10 crashes, with county code
*                 0. The county one is fatal if not handled: see section 4
*   county name   2016 closes up "Jo Daviess" to "JoDaviess". The normalised
*                 join key in section 5 strips spaces, so this needed no
*                 change. It is the case that key was written for
*   merged        the person file drops "Asleep/Fainted" in 2013 and
*                 "Fatigued" roughly doubles. Nothing in the panel reads
*                 either code any more, since the drowsy flag was dropped on
*                 09/09/2026; recorded because the vocabulary moved
*
* None of those changes is announced anywhere in the delivery, and every one
* of them would silently zero out a variable under exact-equality matching.
* So: ALL string comparisons below are made on the LOWERCASED value, and the
* cause matches use distinctive substrings rather than full labels. Anything
* added later should follow the same style
*
* Value domains, asserted in section 1A. Held in LOWER CASE because that is
* how they are compared, and carrying the sentinels of both eras so a year
* using either spelling passes. A genuinely blank value is allowed separately
* in the check itself rather than listed here
* STORED IN CANONICAL FORM AND WITHOUT QUOTES, which is not cosmetic. The
* first version of this held them as quoted lists, `""fatal" "injury" ..."',
* and consumed them with a one-line `if "`chk'" == "severity" local dom
* `dom_severity''. Stata cannot parse that: the expanded command is
* `local dom "fatal" "injury" "property damage"' sitting after an `if'
* expression, and it fails with "too few quotes", r(132), on the first year.
*
* The fix removes the need for quotes at all. The check below canonicalises
* every observed value by lowercasing it, stripping SPACES and folding "/"
* to ",", so no canonical value can contain a space. That means the domains
* can be written as plain space-separated tokens and read with a bare
* `foreach d of local dom', with nothing to quote and nothing to misparse.
*
* So the entries below are the canonical forms, not the raw labels:
* "property damage" is propertydamage, "snow or slush" is snoworslush,
* "darkness, lighted road" and "darkness / lighted road" are both
* darkness,lightedroad, and "cloudy/overcast" is cloudy,overcast. Add new
* values in that form
*
* Named dom_<varname> so the loop can build the name with `dom_`chk'' and
* the four ifs disappear along with the bug
local dom_severity        fatal injury propertydamage
local dom_road_surface    dry wet snoworslush ice sand,mud,dirt other unknown (unk) (n/a)
local dom_light_condition daylight darkness darkness,lightedroad dawn dusk unknown (unk) (n/a)
local dom_weather         clear cloudy,overcast rain snow sleet,hail fog,smoke,haze severecrosswind freezingrain freezingrainorfreezingdrizzle blowingsnow blowingsand blowingsand,soilordirt other unknown (unk) (n/a)


/*-----------------SECTION 1: crash records, one year at a time --------------*/


/* [> the per-year loop <] */

* Unlike the ID file, which reads four whole-panel workbooks and then cuts
* them by year, IL is processed a year at a time from start to finish: crash
* records, then the vehicle events for that year, then the person records,
* merged to crash level, then appended onto the panel. Two reasons:
*
*   the delivery is already one folder per year, so there is nothing to cut
*   only one year of three files is in memory at once, which matters because
*   2009 alone is 292k crashes, 540k units and 684k persons
*
* An orphan check equivalent to the ID file's `all_crash_ids' still runs, but
* it runs WITHIN each year rather than against a panel-wide id list, which is
* the right scope here: a unit or person record whose crash is not in the same
* year's CrashExtract is a defect in that year's delivery. On 2009 there are
* none in either direction (all 292,437 vehicle-file crash ids and all 292,328
* person-file crash ids are present in CrashExtract)

local first_year_processed = 1
tempfile panel

* Declared ONCE, outside the loop, and overwritten each pass. Year-suffixed
* tempfiles would work but would leave four full copies of every year on disk
* until the do-file ended, which on a long panel is tens of gigabytes for no
* benefit: nothing outside an iteration ever reads them
tempfile crash_yr ids_yr animal_yr person_yr

* Running tally of misparsed rows dropped, stored as one local per year per
* file and printed as a table once the loop finishes. The per-year notes are
* easy to lose in a sixteen-year log and "which other years does this
* affect" is exactly the question that gets asked, so it is answered in one
* place.
*
* Keyed off the year rather than accumulated into a list, because a list of
* multi-field entries cannot be walked with `foreach ... of local': that
* splits on spaces, not on whatever separator the entries were built with

foreach yr of global il_years {

    local ydir "$raw/`folder_stub'`yr'"

    di as text _newline "{hline 70}"
    di as text "==== Processing `folder_stub'`yr' ===="
    di as text "{hline 70}"

    /*-------------- 1A: crash records --------------*/

    * WHY bindquote(loose) AND NOT bindquote(strict). This is the single most
    * consequential line in the file and it was wrong until 2012 forced the
    * issue, so the reasoning is recorded in full.
    *
    * The free-text object-struck field (v69/v70) regularly contains an
    * unescaped double quote: an inch mark on a guardrail height or a tree
    * diameter ("TREE 10 6" TREES", "20" MAJESTIC MAGNA"), or a quoted phrase
    * ("LEFT TURN ONLY SIGN"). Each one leaves that physical line with an ODD
    * number of quotes.
    *
    * Under bindquote(strict) a quote binds ANYWHERE, so an odd line leaves the
    * parser inside an open field and it keeps consuming lines until the NEXT
    * odd line closes it. Everything in between is absorbed into one record and
    * silently disappears. That is not a rounding error:
    *
    *   2012 CrashExtract has TEN odd-parity lines, which pair into five spans
    *   of 11,611 / 44,020 / 43,809 / 21,413 / 1 lines. 120,854 of 274,397
    *   records, FORTY-FOUR PERCENT of the year, would vanish.
    *   2012 VehicleExtract has thirty-two such lines.
    *   2009-2011 have one each, and one odd line with no partner means the
    *   parser runs to end of file, losing everything after it.
    *
    * Under bindquote(loose) a quote binds only at the START of a field. Every
    * field in these extracts is quoted, and every stray quote is mid-field, so
    * loose parses the inch marks as ordinary characters and the record count
    * comes out right. On 2012 it misparses exactly ONE record out of 274,396.
    *
    * DO NOT "TIGHTEN" THIS TO strict. It looks like the safer option and it
    * destroys almost half the data without raising an error.
    *
    * ROW COUNT GUARD. The file is counted twice: once with bindquote(nobind),
    * which cannot cross a line ending and so returns the true physical line
    * count, and once as it is actually read. Small deltas are expected and
    * reported; a large one means the quoting convention moved again and is
    * fatal, because a silent 44% loss is exactly what this exists to prevent
    /* [> which delimiter <] */

    * 2019 SWITCHES THE DELIMITER FROM COMMA TO PIPE. Not announced, and it
    * changes nothing else: the same columns in the same order, just separated
    * differently. Read with delimiters(",") a 2019 file comes back as one or
    * two enormous fields per row and every guard downstream fails at once.
    *
    * So the delimiter is DETECTED rather than assumed. One row is imported
    * with each candidate and whichever yields a plausible field count wins.
    * The test separates the two cleanly: a pipe file read as CSV splits only
    * on the commas inside free text and comes back with a handful of fields,
    * and a CSV file read as pipe-delimited comes back with exactly one
    *
    * The pipe is an improvement and it is worth saying why. Every malformed
    * row this file has had to work around since 2009 came from a comma or a
    * quote inside the free-text object-struck field. 2019 has ZERO malformed
    * rows in all three files, because officers do not type pipes
    local delim_c ""
    foreach d in "|" "," {
        if "`delim_c'" == "" {
            capture qui import delimited using "`ydir'/CrashExtract.txt", ///
                varnames(nonames) stringcols(_all) delimiters("`d'") ///
                bindquote(loose) rowrange(1:1) clear
            if _rc == 0 {
                qui describe, varlist
                local nf : word count `r(varlist)'
                if `nf' >= 73 local delim_c "`d'"
            }
        }
    }

    if "`delim_c'" == "" {
        di as error "CrashExtract.txt `yr': cannot work out the delimiter."
        di as error "Tried pipe and comma; neither produced at least 73 fields on the"
        di as error "first row. Either the file uses a third delimiter, or it is not the"
        di as error "file this expects. Look at the first line before going further."
        error 459
    }
    if "`delim_c'" != "," {
        di as text "  CrashExtract.txt `yr': delimiter is `delim_c', not comma"
    }

    clear
    `q' import delimited using "`ydir'/CrashExtract.txt", ///
        varnames(nonames) stringcols(_all) delimiters("`delim_c'") ///
        bindquote(nobind) colrange(1:1) clear
    qui count
    local n_lines_crash = r(N)

    clear
    `q' import delimited using "`ydir'/CrashExtract.txt", ///
        varnames(nonames) stringcols(_all) delimiters("`delim_c'") ///
        bindquote(loose) clear
    qui count
    local n_read_crash = r(N)

    * Held for the whole iteration, because the orphan checks in 1B and 1C
    * need it: a crash line lost here turns that crash's unit and person
    * records into orphans, and they must not be read as a delivery defect
    local n_lost_crash = `n_lines_crash' - `n_read_crash'

    * Tolerance: a handful of records is the embedded-newline defect described
    * below. Anything past this is a parsing failure, not a data quirk
    local max_lost = max(20, ceil(0.001 * `n_lines_crash'))

    di as text "CrashExtract `yr': `n_read_crash' records read from `n_lines_crash' lines"

    if `n_lost_crash' > `max_lost' {
        di as error "CrashExtract `yr': `n_lost_crash' of `n_lines_crash' lines did not survive"
        di as error "parsing, which is past the tolerance of `max_lost'."
        di as error "This is what a quote-binding failure looks like: a line with an odd"
        di as error "number of double quotes leaves the parser inside an open field, and"
        di as error "every line until the next odd one is absorbed into it."
        di as error "Count the double quotes per line in the raw file and look for the odd"
        di as error "ones before trusting anything downstream. See the note above this block."
        di as error "Refusing to build a panel from a partial year."
        error 459
    }

    if `n_lost_crash' > 0 {
        di as error "NOTE: `n_lost_crash' CrashExtract line(s) did not survive parsing in `yr'."
        di as error "Within tolerance. The usual cause is an EMBEDDED NEWLINE inside the"
        di as error "free-text object-struck field: 2012 line 54,511 holds a description"
        di as error "that runs onto a second physical line, so one crash arrives split in"
        di as error "two. The first part keeps columns 1-68 intact, which is everything"
        di as error "this file reads; the second part becomes a junk row and is dropped by"
        di as error "the validity filter below."
        di as error "The orphan checks in 1B and 1C will tolerate up to `n_lost_crash'"
        di as error "orphaned crash id(s) on that basis and no more."
    }

    /* [> layout guard <] */

    * This block replaces the header check in ID section 3B. There are no
    * column names to compare, so the test is that each column still holds
    * only values from the vocabulary recorded in section 0C. A delivery that
    * inserts or removes a column upstream shifts every column to its right
    * and fails here, which is the whole point
    qui describe, varlist
    local n_fields : word count `r(varlist)'
    di as text "  CrashExtract `yr': `n_fields' fields"
    if `n_fields' < 73 {
        di as error "CrashExtract `yr': `n_fields' fields, at least 73 needed."
        di as error "The layout in section 0C no longer describes this delivery."
        di as error "Every column below is addressed by POSITION, so do not run"
        di as error "this file until the mapping has been re-checked by hand."
        error 459
    }
    if `n_fields' > 73 {
        di as text "  (`=`n_fields'-73' column(s) beyond the 73 this file reads."
        di as text "   Harmless while they are APPENDED, which every delivery so far"
        di as text "   has done; an INSERTED column is what the domain checks catch)"
    }

    /* [> locate the columns <] */

    * SELF-LOCATING, NOT HARDCODED, and 2013 is why. Until then every delivery
    * APPENDED its new columns, so positions 1..73 kept their meaning and a
    * fixed map worked. 2013 breaks that in the vehicle and person files by
    * INSERTING a record id at position 2, which shifts everything after it by
    * one. The crash file has not shifted in any year so far, but the same
    * machinery is used here so that all three files behave identically and
    * the next insertion is absorbed rather than silently misread
    *
    * The method: `basemap' below records the 2009-2012 layout, which is the
    * baseline. An ANCHOR column with an unmistakable vocabulary is searched
    * for near its baseline position, and the difference is the offset applied
    * to every other column. Position 1 is the crash id in every file and every
    * year and is never shifted, because an insertion at position 2 leaves it
    * alone
    *
    * Severity is the anchor here: three values, one of which is on roughly
    * four rows in five, and it has been spelled the same way in every year
    local anchor_base 20
    local offset = -1
    forvalues o = 0/4 {
        if `offset' == -1 {
            local j = `anchor_base' + `o'
            capture confirm variable v`j'
            if _rc == 0 {
                qui count if inlist(lower(strtrim(v`j')), "property damage", "injury", "fatal")
                if r(N) > 0.5 * _N {
                    local offset = `o'
                }
            }
        }
    }

    if `offset' == -1 {
        di as error "CrashExtract `yr': cannot find the severity column."
        di as error "Searched v`anchor_base' to v`=`anchor_base'+4' for a column that is mostly"
        di as error "Property Damage / Injury / Fatal, and found none. Either the layout has"
        di as error "moved further than this searches, or severity has been respelled."
        di as error "Section 0C records the baseline layout; re-check it by hand."
        error 459
    }

    if `offset' != 0 {
        di as text "  CrashExtract `yr': columns are shifted by +`offset' from the baseline."
        di as text "  (a column was inserted upstream; every position past 1 is remapped)"
    }

    * Baseline positions, 2009-2012 layout. This is the ONLY place a column
    * number appears for the crash file
    local basemap  county_code 3      ///
                   rawyear 4          ///
                   total_units 7      ///
                   total_fatalities 14 ///
                   total_injuries 15  ///
                   a_injuries 17      ///
                   b_injuries 18      ///
                   c_injuries 19      ///
                   severity 20        ///
                   county_name 49     ///
                   cause1 55          ///
                   cause2 56          ///
                   road_surface 59    ///
                   light_condition 62 ///
                   weather 63

    local nmap : word count `basemap'
    local keeplist v1

    forvalues k = 1(2)`nmap' {
        local pos : word `=`k'+1' of `basemap'
        local col = `pos' + `offset'
        capture confirm variable v`col'
        if _rc != 0 {
            local nm : word `k' of `basemap'
            di as error "CrashExtract `yr': `nm' should be at v`col' (baseline `pos' plus offset `offset')"
            di as error "but that variable does not exist. The file is shorter than the layout expects."
            error 459
        }
        local keeplist `keeplist' v`col'
    }

    keep `keeplist'

    rename v1 crash_id
    forvalues k = 1(2)`nmap' {
        local nm  : word `k' of `basemap'
        local pos : word `=`k'+1' of `basemap'
        rename v`=`pos'+`offset'' `nm'
    }

    /* [> record validity filter <] */

    * A row is valid if its id is all digits and its year field is this
    * folder's year. Two independent things get caught here and they need
    * opposite responses, which is why this is a filter with a ceiling rather
    * than a plain assert:
    *
    *   A JUNK ROW is the tail of a record split by an embedded newline in the
    *   free-text object-struck field. 2012 produces exactly one, whose id
    *   reads DEAF SIGN POLE" and whose remaining columns are the tail of the
    *   real record's fields. Its parent row keeps columns 1-68 and enters the
    *   panel correctly, so the junk row is pure noise and is dropped. Leaving
    *   it in would fail the domain checks below and stop a build over one bad
    *   row in 274,000
    *
    *   A WRONG-YEAR FOLDER, or a year column that is no longer the year, would
    *   fail on nearly every row. That is a real error and must stop the build
    *
    * The ceiling separates the two. Same tolerance as the row-count guard
    qui gen byte _valid = real(strtrim(crash_id)) < .    ///
                        & strtrim(crash_id) != ""        ///
                        & "20" + strtrim(rawyear) == "`yr'"

    qui count if _valid == 0
    local n_junk = r(N)

    if `n_junk' > `max_lost' {
        di as error "CrashExtract `yr': `n_junk' of `n_read_crash' rows have a non-numeric"
        di as error "crash id or a year other than `yr'."
        di as error "At this scale that is not stray free text. Either the folder holds the"
        di as error "wrong year, or the id and year columns have moved, or the file did not"
        di as error "parse. Nothing has been kept."
        qui levelsof rawyear if _valid == 0, local(badyrs)
        di as error `"Values found in the year column: `badyrs'"'
        error 459
    }

    if `n_junk' > 0 {
        di as error "NOTE: dropping `n_junk' unusable row(s) from CrashExtract `yr'."
        di as error "First few, at most ten:"
        preserve
            qui keep if _valid == 0
            local nshow = min(10, _N)
            * A 60-character excerpt: these ids are the tail of a whole record
            * and run to 96 characters, which list wraps over several blocks
            qui gen str60 _excerpt = substr(crash_id, 1, 60)
            list _excerpt in 1/`nshow', noobs sep(0) string(60)
        restore
        di as error "These are fragments of records split by an embedded newline in the"
        di as error "free-text object-struck field. The parent records are intact."
        drop if _valid == 0
    }
    drop _valid rawyear

    * RECAST THE ID BACK TO str#, and this is not housekeeping. A misparsed row
    * carries the whole tail of a record in column 1, and in 2017 one of those
    * ran past 2,045 characters, so Stata typed the WHOLE COLUMN as strL. Once
    * the bad rows are dropped the column is short again but the type does not
    * follow, and merge refuses a strL key outright:
    *
    *   key variable crash_id is strL in master data ... r(106)
    *
    * That is what stopped the run at 2017, four merges later and with nothing
    * in the message pointing back to here. compress converts strL to str# when
    * the values fit, which after the filter they always do. Run
    * unconditionally rather than inside the if, because a long value could
    * arrive on a row the filter does not touch
    *
    * EVERY kept column, not just the id. county_name is a by() variable in
    * the section 4 collapse and crash_type is compared in section 3, and a
    * misparsed row can make either of them strL just as easily. By this point
    * only the eighteen mapped columns survive, so compressing all of them
    * costs one pass over a narrow dataset
    qui compress


    * Built from the folder rather than destrung from the two-digit year
    * column, which would need a century rule. That column is used by the
    * validity filter above and dropped there
    gen int year = `yr'

    * ignore(",") mirrors the ID and AZ files. None of these arrive with a
    * thousands separator today, but a delivery formatted differently would
    * and destring errors out rather than warning when it hits one
    foreach v in total_units total_fatalities total_injuries ///
                 a_injuries b_injuries c_injuries county_code {
        `q' destring `v', replace ignore(",")
    }

    * Trailing spaces are pervasive and vary by year: 2009 pads crash_type to
    * 50 characters ("Pedestrian" plus 40 blanks) and 2010 pads county_name
    * and the population group instead, so every string comparison downstream
    * would fail somewhere without this
    *
    * LOWERCASED HERE, ONCE, and every comparison from this point on is
    * written in lower case. This is the single change that makes the file
    * survive 2010: that delivery retitles crash types, road alignment and
    * several cause codes purely by capitalisation, and each one would have
    * silently zeroed a variable. Doing it at import rather than at each
    * comparison means a flag added later cannot forget to do it
    qui replace crash_id = strtrim(crash_id)
    foreach v of varlist county_name cause1 cause2 ///
                         road_surface light_condition weather severity {
        qui replace `v' = lower(strtrim(ustrtrim(`v')))
    }

    /* [> value domain checks <] */

    * Run AFTER the rename and the lowercasing, so they test the columns this
    * file actually uses rather than raw positions. Two jobs:
    *
    *   they confirm the offset detection landed on the right columns, which
    *   matters because the anchor only pins severity and the rest are taken
    *   on trust from the baseline map
    *   they stop the build when a delivery introduces a value no flag knows
    *   about, which is not hypothetical: 2013 renamed "Darkness, Lighted
    *   Road" to "Darkness/ Lighted Road" and added "Cloudy/Overcast"
    foreach chk in severity road_surface light_condition weather {
        local dom "`dom_`chk''"
        if "`dom'" == "" {
            di as error "No value domain defined for `chk'. Add a local named"
            di as error "dom_`chk' in section 0C, in canonical form."
            error 459
        }

        * PUNCTUATION IS CANONICALISED ON BOTH SIDES before comparing, and
        * the light condition is why. The same category has now been spelled
        * three ways in six years:
        *
        *   2009-2012   "Darkness, Lighted Road"
        *   2013-2014   "Darkness/ Lighted Road"     comma to slash
        *   2015        "Darkness / Lighted Road"    space added before it
        *
        * Nothing about the category changed; IDOT is just moving punctuation
        * around, most likely to keep commas out of a comma-delimited export.
        * Listing every variant means editing this file each time a space
        * moves, and each edit is a chance to miss one and silently zero a
        * flag. So spaces are stripped and slashes are folded to commas, on
        * the observed value and on the domain entry alike
        *
        * This does NOT weaken the check in the way that matters: a genuinely
        * new category still fails it, which is how "Cloudy/Overcast" was
        * caught in 2013. It only stops the check firing on a respelling of a
        * category that is already known
        qui gen _canon = lower(`chk')
        qui replace _canon = subinstr(_canon, " ", "", .)
        qui replace _canon = subinstr(_canon, "/", ",", .)

        * The domain entries are already canonical (see section 0C), so they
        * are compared as they stand. Only the observed value needs converting
        qui gen byte _ok = (`chk' == "")
        foreach d of local dom {
            qui replace _ok = 1 if _canon == "`d'"
        }
        qui count if _ok == 0
        if r(N) > 0 {
            di as error "CrashExtract `yr': `chk' holds `r(N)' value(s) outside its known vocabulary."
            di as error `"Expected only: `dom'"'
            di as error "Found instead:"
            qui levelsof `chk' if _ok == 0, local(badvals)
            foreach b of local badvals {
                di as error "      `b'"
            }
            di as error "Either a new code was added, in which case extend the domain in"
            di as error "section 0C and check whether any flag in section 3 needs to match"
            di as error "it, or the columns are misaligned, in which case fix the baseline"
            di as error "map above. Do not just widen the domain without checking the flags."
            error 459
        }
        drop _ok _canon
    }

    /* [> one row per crash <] */

    * Everything downstream assumes it: the two merges in 1D are 1:1, and the
    * county-year collapse would double-count a crash that appeared twice.
    *
    * This was a bare `isid crash_id' until 2022, which fails with
    * "crash_id does not uniquely identify the observations" and tells you
    * nothing else: not how many, not whether the rows are identical, not
    * which ids. A duplicate can arise two quite different ways and they
    * deserve different treatment, so they are separated here.
    *
    *   AN EXACT DUPLICATE ROW is a record delivered twice. Dropping the copy
    *   loses nothing at all, so it is done silently apart from the count
    *
    *   TWO DIFFERENT ROWS SHARING AN ID is a real conflict: an amended
    *   report filed alongside the original, or two crashes issued the same
    *   number. Neither can be resolved from inside this file, so the FIRST
    *   occurrence in file order is kept and the rest are reported. Keeping
    *   one is the right call for a count panel, where the alternative is to
    *   count the crash twice
    *
    * Both are bounded. A handful is a clerical artefact; thousands would
    * mean the id column is not the id, and that must stop the build
    qui count
    local n_before_dup = r(N)
    qui duplicates drop
    qui count
    local n_exact_dup = `n_before_dup' - r(N)

    qui duplicates tag crash_id, gen(_dup)
    qui count if _dup > 0
    local n_conflict = r(N)
    local max_dup = max(20, ceil(0.0005 * `n_before_dup'))

    if `n_exact_dup' + `n_conflict' > `max_dup' {
        di as error "CrashExtract `yr': `n_exact_dup' exact duplicate row(s) and"
        di as error "`n_conflict' row(s) sharing a crash id with a DIFFERENT row,"
        di as error "against a tolerance of `max_dup'."
        di as error "At this scale column 1 is probably not the crash id any more."
        error 459
    }

    if `n_exact_dup' > 0 {
        di as text "  CrashExtract `yr': `n_exact_dup' exact duplicate row(s) dropped"
    }

    if `n_conflict' > 0 {
        di as error "NOTE: `n_conflict' row(s) in CrashExtract `yr' share a crash id with"
        di as error "a different row. Keeping the first of each and reporting the ids:"
        preserve
            qui keep if _dup > 0
            qui gen str60 _excerpt = substr(crash_id, 1, 60)
            local nshow = min(10, _N)
            list _excerpt severity county_name in 1/`nshow', noobs sep(0) string(60)
        restore

        * First in FILE order, made explicit: bysort would otherwise keep
        * whichever row its own sort happened to put first
        * by cannot prefix keep, so the flag is generated and then used
        qui gen long _ord = _n
        bysort crash_id (_ord): gen byte _first = (_n == 1)
        qui keep if _first
        drop _ord _first
    }
    drop _dup

    isid crash_id

    * The A/B/C counts must add to the injury total. This is the internal
    * consistency check that licenses building the severity split from these
    * three columns instead of from the unusable v61/v68 pair. Exact on 2009:
    * 13,009 + 40,786 + 35,420 = 89,215
    qui count if a_injuries + b_injuries + c_injuries != total_injuries
    if r(N) > 0 {
        di as error "CrashExtract `yr': `r(N)' crashes where A+B+C injuries != total injuries."
        di as error "Section 4 builds the injury severity split from these columns,"
        di as error "so they have to agree. Check the baseline map and the offset above."
        error 459
    }

    * KEPT, not read. The junk-row filter and the duplicate handler above both
    * drop rows, so n_read_crash is no longer the count in memory; line 981
    * already reported what was read
    qui count
    di as text "Crash records `yr': `r(N)' kept of `n_read_crash' read. Fatalities: " _c
    qui summ total_fatalities, meanonly
    di as text %12.0fc r(sum)

    `q' save `crash_yr', replace

    * Crash ids for this year, for the orphan checks below. The ID file keeps
    * a panel-wide list because its deliveries overlap; here the correct scope
    * is the year, since a unit record belongs to the same year's crash file
    preserve
        keep crash_id
        `q' save `ids_yr', replace
    restore

    /*-------------- 1B: animal event flags, from VehicleExtract --------------*/

    * This is the IL analogue of ID section 2, and the analogy is close. IL
    * gives a unit-level file with a most harmful event and an ordered event
    * sequence, where ID gives an event-level file with fldEventOrder. Both are
    * collapsed to crash level with (max) before going near the crash file, so
    * a crash carrying two animal strikes counts once
    *
    * ANIMAL VOCABULARY. IL has exactly two animal values, "Deer" and "Other
    * Animal", verified against all 45 values of the most harmful event column
    * and all 42 of event sequence 1. This is NOT the same split as ID's
    * "Animal - Wild" and "Animal - Domestic":
    *
    *   ID   splits on wild vs domestic, so wild_collision is a clean
    *        biological category
    *   IL   splits on deer vs everything else, so "Other Animal" pools
    *        domestic animals with non-deer wildlife and cannot be
    *        decomposed. 18,794 deer against 716 other animals in 2009 as the
    *        most harmful event
    *
    * wild_collision below is therefore DEFINED AS DEER in this file, and
    * deer_collision is generated as an identical twin so that IL-specific
    * work can be explicit about it while cross-state code can keep reading
    * wild_*. animal_other_collision carries the residual. Do not read IL
    * wild_collision as comparable to ID wild_collision without noting that
    * IL's excludes non-deer wildlife and ID's includes it. For a DVC project
    * this is a mild difference, since deer are the overwhelming majority of
    * wildlife strikes in both states, but it is a difference
    *
    * EVENT POSITION. v31 is event sequence 1 and is the direct analogue of
    * ID's fldEventOrder == 1 and of AZ's firstharmfulevent, so
    * animal_first_collision is keyed on it. v29 (most harmful) is included in
    * the unrestricted animal_collision alongside the sequence columns for the
    * same reason ID section 3B keeps column U as well as column V: an animal
    * struck in a crash whose worst event was something else appears in the
    * sequence but not in most-harmful. On 2009 the sequence columns hold 18,882
    * deer at position 1 against 18,794 in most-harmful, on 2010 17,174 against
    * 17,096, and on 2011 18,078 against 18,005, so the two are close but not
    * nested either way in any year, and the union is what animal_collision
    * wants

    * Delimiter detected per file rather than once per year: see the note in
    * the crash block. Detecting once and reusing it would work on every
    * delivery so far, and would fail confusingly on a year that converted
    * only some of its files
    local delim_v ""
    foreach d in "|" "," {
        if "`delim_v'" == "" {
            capture qui import delimited using "`ydir'/VehicleExtract.txt", ///
                varnames(nonames) stringcols(_all) delimiters("`d'") ///
                bindquote(loose) rowrange(1:1) clear
            if _rc == 0 {
                qui describe, varlist
                local nf : word count `r(varlist)'
                if `nf' >= 39 local delim_v "`d'"
            }
        }
    }
    if "`delim_v'" == "" {
        di as error "VehicleExtract.txt `yr': cannot work out the delimiter (tried pipe and comma)."
        error 459
    }
    if "`delim_v'" != "," {
        di as text "  VehicleExtract.txt `yr': delimiter is `delim_v', not comma"
    }

    clear
    `q' import delimited using "`ydir'/VehicleExtract.txt", ///
        varnames(nonames) stringcols(_all) delimiters("`delim_v'") ///
        bindquote(nobind) colrange(1:1) clear
    qui count
    local n_lines_veh = r(N)

    clear
    `q' import delimited using "`ydir'/VehicleExtract.txt", ///
        varnames(nonames) stringcols(_all) delimiters("`delim_v'") ///
        bindquote(loose) clear
    qui count
    local n_read_veh = r(N)

    local n_lost_veh  = `n_lines_veh' - `n_read_veh'
    local max_lost_veh = max(20, ceil(0.001 * `n_lines_veh'))

    di as text "VehicleExtract `yr': `n_read_veh' unit records from `n_lines_veh' lines"

    * SAME FATAL THRESHOLD AS THE CRASH FILE, and this file needs it just as
    * much. An earlier version of this block said VehicleExtract has no
    * free-text column so a loss here would be unexpected. That was wrong:
    * 2012 VehicleExtract has THIRTY-TWO odd-parity lines, more than three
    * times the crash file, and under bindquote(strict) it would have been
    * gutted the same way. Under loose it parses clean, and this guard is what
    * would say so if a future delivery stopped doing that
    if `n_lost_veh' > `max_lost_veh' {
        di as error "VehicleExtract `yr': `n_lost_veh' of `n_lines_veh' lines did not survive"
        di as error "parsing, past the tolerance of `max_lost_veh'. Animal flags are built"
        di as error "from this file, so a partial read would understate every animal series"
        di as error "without failing any other check. See the parser note in section 1A."
        error 459
    }
    if `n_lost_veh' > 0 {
        di as error "NOTE: `n_lost_veh' VehicleExtract line(s) did not survive parsing in `yr'."
        di as error "Within tolerance. Their crashes will surface as orphans below."
    }

    * layout guard
    qui describe, varlist
    local n_fields : word count `r(varlist)'
    di as text "  VehicleExtract `yr': `n_fields' fields"
    if `n_fields' < 39 {
        di as error "VehicleExtract `yr': `n_fields' fields, at least 39 needed."
        di as error "Animal flags are addressed by position. Do not run."
        error 459
    }


    /* [> drop misparsed rows before anything else reads them <] */

    * ADDED AFTER THE FIRST FULL RUN, which died here on 2015. The crash file
    * has had a validity filter since 2012; these two did not, and 2015 showed
    * why they need one.
    *
    * PersonExtract carries free text that the crash file does not: the EMS
    * agency and receiving hospital. Those values contain apostrophes
    * ("Veteran's Hospital"), stray double quotes, and in some records an
    * embedded newline. Under loose quote binding that shifts the field
    * boundaries WITHIN a line, so the record count still equals the line
    * count and the row-count guard above reports nothing lost, but about 109
    * rows in 2015 come out with the tail of a neighbouring record sitting in
    * column 1. Their crash ids read like
    *   ,","Driver",","Normal","Did Not Deploy",...
    *
    * Two things then went wrong, and both are fixed by dropping these rows
    * here rather than downstream:
    *
    *   the orphan check treated all 109 as crash ids missing from
    *   CrashExtract and stopped the build, because its tolerance is the
    *   number of CRASH lines lost to parsing, which was zero. That budget
    *   was the wrong instrument: a garbled row in THIS file is not a
    *   crash-file parse loss and should not be measured against one
    *
    *   the person type code search returned nothing, because it looks for a
    *   column holding only digits 1-9 on EVERY row and the garbled rows hold
    *   text in all of them. So the code-against-label cross-check was
    *   skipped, on a year where it was most needed
    *
    * A valid crash id is all digits, which is true in every year and every
    * file. Rows failing that are unusable and are dropped with a report,
    * under a ceiling: a handful is stray free text, thousands would mean the
    * delimiter or quoting convention moved and must stop the build
    qui gen byte _validrow = real(strtrim(v1)) < . & strtrim(v1) != ""
    qui count if _validrow == 0
    local n_junk_veh = r(N)
    local max_junk_veh = max(50, ceil(0.001 * `n_read_veh'))

    if `n_junk_veh' > `max_junk_veh' {
        di as error "VehicleExtract `yr': `n_junk_veh' of `n_read_veh' rows have a non-numeric"
        di as error "crash id, past the tolerance of `max_junk_veh'."
        di as error "At this scale the delimiter or the quoting convention has moved,"
        di as error "rather than a few rows being garbled by stray free text."
        di as error "First ten offending ids:"
        preserve
            qui keep if _validrow == 0
            qui gen str60 _excerpt = substr(v1, 1, 60)
            list _excerpt in 1/10, noobs sep(0) string(60)
        restore
        error 459
    }

    if `n_junk_veh' > 0 {
        di as error "NOTE: dropping `n_junk_veh' misparsed row(s) from VehicleExtract `yr'"
        di as error "(crash id is not numeric; free text has shifted the field boundaries)."
        drop if _validrow == 0
    }
    drop _validrow

    * strL guard, as in the crash block above: see the note there
    qui compress v1

    /* [> locate the columns <] */

    * THIS FILE DID SHIFT. 2013 inserts a unit record id at position 2, so
    * every column from the old position 2 onward moves by one: the most
    * harmful event goes from v29 to v30 and the event sequence from v31:v33
    * to v32:v34. A fixed map would have read vehicle USE as the most harmful
    * event, found no animal value anywhere, and produced a year of zero deer
    * collisions. The Deer check below would have caught it, but only as an
    * error; this locates the columns instead
    *
    * Anchor: the most harmful event column, which is "Motor Vehicle in
    * Traffic" on about four rows in five in every year
    local anchor_base 29
    local offset = -1
    forvalues o = 0/4 {
        if `offset' == -1 {
            local j = `anchor_base' + `o'
            capture confirm variable v`j'
            if _rc == 0 {
                qui count if lower(strtrim(v`j')) == "motor vehicle in traffic"
                if r(N) > 0.5 * _N {
                    local offset = `o'
                }
            }
        }
    }

    if `offset' == -1 {
        di as error "VehicleExtract `yr': cannot find the most harmful event column."
        di as error "Searched v`anchor_base' to v`=`anchor_base'+4' for a column that is mostly"
        di as error "Motor Vehicle in Traffic, and found none. Animal flags are built from"
        di as error "this column and the three event sequence columns beside it, so the"
        di as error "build stops here rather than reporting no animals."
        error 459
    }

    if `offset' != 0 {
        di as text "  VehicleExtract `yr': columns shifted by +`offset' from the baseline."
    }

    * Baseline positions, 2009-2012 layout. Event sequence 1-3 sit two, three
    * and four columns past the most harmful event in both layouts, which is
    * what makes a single offset sufficient
    local basemap unit_number 2 ev_mhe 29 ev_1 31 ev_2 32 ev_3 33

    local nmap : word count `basemap'
    local keeplist v1
    forvalues k = 1(2)`nmap' {
        local pos : word `=`k'+1' of `basemap'
        local col = `pos' + `offset'
        capture confirm variable v`col'
        if _rc != 0 {
            local nm : word `k' of `basemap'
            di as error "VehicleExtract `yr': `nm' should be at v`col' but that variable"
            di as error "does not exist. The file is shorter than the layout expects."
            error 459
        }
        local keeplist `keeplist' v`col'
    }
    keep `keeplist'

    rename v1 crash_id
    forvalues k = 1(2)`nmap' {
        local nm  : word `k' of `basemap'
        local pos : word `=`k'+1' of `basemap'
        rename v`=`pos'+`offset'' `nm'
    }

    * Lowercased for the same reason as the crash file. The event vocabulary
    * itself is stable across 2009 and 2010 in wording but not in case:
    * "Motor Vehicle in Traffic" became "Motor Vehicle In Traffic". "Deer" and
    * "Other Animal" happen to be spelled identically in both years, which is
    * luck rather than a guarantee
    qui replace crash_id = strtrim(crash_id)
    foreach v of varlist unit_number ev_mhe ev_1 ev_2 ev_3 {
        qui replace `v' = lower(strtrim(ustrtrim(`v')))
    }

    * The event vocabulary must still contain the animal values. A delivery
    * that renamed "Other Animal" would otherwise silently drop 716 crashes a
    * year out of the animal count, and nothing else in the file would notice
    qui count if ev_mhe == "deer" | ev_1 == "deer" | ev_2 == "deer" | ev_3 == "deer"
    if r(N) == 0 {
        di as error "VehicleExtract `yr': not one event field holds the value Deer."
        di as error "Deer is the single largest animal event in every IL year, so"
        di as error "either the event columns have moved or the vocabulary changed."
        di as error "Values present in the most harmful event column:"
        qui levelsof ev_mhe, local(evs)
        foreach e of local evs {
            di as error "      `e'"
        }
        error 459
    }

    * Whether this unit has ANY event recorded, which is what makes coverage
    * measurable in section 5 the way has_event_record does in the ID file.
    * "Unknown" and blank both count as no record. On 2009, 104 of 539,735
    * units fail this and every one of the 292,437 crashes has at least one
    * unit with an event, so crash-level coverage is 100.00%. The measurement
    * is kept anyway: it is what made the ID truncation visible instead of
    * silent, and the next delivery is not guaranteed to be clean
    * THE SENTINEL LIST IS YEAR-DEPENDENT and all of it has to be here. 2009
    * leaves an unused event slot BLANK; 2010 fills it with "(UNK)". Treating
    * "(UNK)" as a real event would put event coverage at a flat 100% in 2010
    * by construction and turn this measure into a tautology, which is exactly
    * what it exists not to be
    gen byte has_event_record = 0
    foreach v in ev_mhe ev_1 ev_2 ev_3 {
        qui replace has_event_record = 1 ///
            if !inlist(`v', "", "unknown", "no data", "(unk)", "(n/a)", "not reported")
    }

    * THE EVENT SIDE, named as the ID file names it. IL codes two animal
    * events, Deer and Other Animal, which map onto ID's two species codes:
    *
    *   wild_animal_      Deer, the analogue of ID's "Animal - Wild"
    *   non_wild_animal_  Other Animal, the analogue of "Animal - Domestic"
    *   animal_event      either of them. An INPUT, not an output: section 1D
    *                     unions it with the cause column to build
    *                     animal_collision
    *
    * non_wild_animal IS THE OTHER ANIMAL CODE, not "animal minus wild". An
    * earlier version of this file built it as the residual so the three would
    * sum; that is not what ID does and the two files have to agree. The
    * consequence, stated in section 3: the species families do NOT partition
    * animal_collision, because a cause-only animal crash records no species
    * and appears in animal_ alone
    *
    * IL's Other Animal pools non-deer wildlife with domestic animals and
    * cannot be decomposed, so IL's non_wild_animal is broader than ID's
    * domestic code. Worth noting before pooling the two states on that
    * family; the animal_ total is unaffected
    gen byte animal_event = 0
    gen byte wild_animal_collision = 0
    gen byte non_wild_animal_collision = 0
    foreach v in ev_mhe ev_1 ev_2 ev_3 {
        qui replace animal_event = 1 if `v' == "deer" | `v' == "other animal"
        qui replace wild_animal_collision = 1 if `v' == "deer"
        qui replace non_wild_animal_collision = 1 if `v' == "other animal"
    }

    * FIRST HARMFUL EVENT, the analogue of ID's fldeventorder == 1. ev_1 is the
    * first slot of IL's ordered event sequence, so an animal here was struck
    * before anything else rather than after the driver had already lost
    * control. Event side only: the cause column carries no ordering
    gen byte animal_first_collision       = (ev_1 == "deer" | ev_1 == "other animal")
    gen byte wild_animal_first_collision  = (ev_1 == "deer")
    gen byte non_wild_animal_first_coll   = (ev_1 == "other animal")

    drop ev_mhe ev_1 ev_2 ev_3 unit_number

    collapse (max) animal_event ///
                   wild_animal_collision ///
                   non_wild_animal_collision ///
                   animal_first_collision ///
                   wild_animal_first_collision ///
                   non_wild_animal_first_coll ///
                   has_event_record, ///
                   by(crash_id)

    strip_collapse_labels

    * Orphan check, then the merge. A unit record whose crash is not in this
    * year's CrashExtract is a hard error, exactly as in ID sections 2 and 3
    * ORPHAN CHECK, BUDGETED AGAINST THE PARSE LOSS MEASURED IN 1A. A unit
    * belonging to no crash is normally a defect in the delivery and a hard
    * error. But this file has a known, benign way of manufacturing orphans:
    * both years carry one CrashExtract row whose free-text object-struck
    * field holds an unescaped inch mark (2010: a guardrail height written with
    * an inch symbol), leaving odd quote parity, so a quote-binding parser can
    * consume the following record along with it. Every unit and person record
    * of a crash lost that way is then an orphan through no fault of the
    * delivery. Known cases: 2009 line 128,747, 2010 line 183,096, 2012 line
    * 54,511 and 2014 line 22,015, the last two being embedded newlines rather
    * than inch marks.
    *
    * 2014 IS THE MESSIEST YEAR SO FAR on this front: six malformed crash rows
    * rather than one or two, in three different shapes. One embedded-newline
    * pair (69 fields plus a 9-field fragment), and four rows that come out
    * LONGER than 77 because an unescaped quote in the free-text field let a
    * comma inside it split into extra columns. All six have columns 1-68
    * intact, which is everything this file reads, and the extra columns are
    * simply not kept. The fragment is dropped by the validity filter
    *
    * So the tolerance is exactly the number of crash lines 1A measured as
    * lost, and not one more. Within budget the orphans are named and dropped;
    * beyond it the build stops, because that is no longer a parser artefact
    `q' merge 1:1 crash_id using `ids_yr'
    qui count if _merge == 1
    local n_orph = r(N)
    if `n_orph' > 0 {
        di as error "VehicleExtract `yr': `n_orph' crash id(s) have no record in CrashExtract"
        di as error "(`n_lost_crash' crash line(s) were lost to parsing, so that many are expected)."
        di as error "First few, at most ten:"
        preserve
            qui keep if _merge == 1
            local nshow = min(10, _N)
            list crash_id in 1/`nshow', noobs sep(0)
        restore
        if `n_orph' > `n_lost_crash' {
            di as error "That is more orphans than lost lines can explain. A unit belonging"
            di as error "to no crash is a defect in this year's delivery. Stopping."
            di as error ""
            di as error "If the ids listed above look like fragments of other records rather"
            di as error "than numbers, the row-validity filter earlier in this block did not"
            di as error "catch them; widen it rather than raising this tolerance."
            error 459
        }
        di as error "Within the parse-loss budget, so these are dropped and the build continues."
        drop if _merge == 1
    }
    drop _merge

    `q' save `animal_yr', replace

    /*-------------- 1C: person records --------------*/

    * This section has NO ANALOGUE IN THE WORKING ID FILE and that is the
    * single biggest analytical gain from the IL delivery. ID section 4 asks
    * for AccdPerson_Injury and then declines to use it, because the export is
    * truncated to 411,243 of 595,514 crashes and recovers only 69% of
    * fatalities. IL's PersonExtract is complete, and the reconciliation below
    * is what establishes that
    *
    * It carries two things:
    *
    *   INJURY CLASSIFICATION (v13), person-level KABCO. This gives counts of
    *   PEOPLE at each injury level rather than counts of CRASHES, which is
    *   what the ID file wanted and could not have
    *
    *   PHYSICAL CONDITION (v24), which is where IL puts impairment. This is
    *   the ONLY place in the IL delivery that separates alcohol from drugs:
    *   the crash-level cause columns carry a single combined "Under Influence
    *   of Alcohol/Drugs" code, so an alcohol_collision built from causes alone
    *   would not be comparable to the AZ or ID alcohol series. See section 1D
    *
    * v13 CODING WAS ESTABLISHED BY RECONCILIATION, NOT FROM A CODE BOOK, so
    * the check below is load-bearing rather than cosmetic. On 2009, summing
    * person rows by v13 against the crash-level columns gives:
    *
    *        2009 person 2009 crash  2010 both 2011 both 2012 both 2013 both 2014 both 2015 both 2016 both 2017 both 2018 both 2019 both 2020 both
    *   == 4      911        911         927       918       956       991       924       998     1,078     1,090     1,035     1,012     1,194     1,335     1,271     1,241     1,178
    *   == 3   13,008     13,009      12,624    11,930    12,381    12,300    11,752    12,858    11,622    12,025    11,344     9,705     8,589     9,422     8,932     8,847     8,123
    *   == 2   40,777     40,786      41,260    39,253    39,649    39,189    38,302    41,080    41,688    42,566    43,251    43,262    37,694    44,640    43,441    45,791    46,353
    *   == 1   35,407     35,420      35,152    33,052    31,779    33,541    34,625    37,922    39,852    39,067    39,573    36,283    26,995    31,382    31,532    32,956    34,551
    *   == 0  592,911          -     600,320   581,344   564,565   589,842   606,182   638,110   668,835   640,786   649,901   638,902   477,304   578,868   591,663   597,894   608,284
    *   == .      626          -         976     1,023     1,080     1,121       952       611       491       380       370       392       258       282       260       247       205
    *
    * 2010 through 2024 reconcile EXACTLY on all four levels, person side
    * against crash side, which is why those years are shown in a single
    * column each. Only 2009 is short, by 23 across A, B and C. So the coding
    * is stable and the small 2009 gap is a data-entry artefact of that year
    * rather than a structural shortfall. The 2013 figures are read from the
    * SHIFTED column, which is what confirms the offset detection works
    *
    * So 4 is fatal, 3 is A, 2 is B, 1 is C and 0 is none. Note the ordering
    * runs LEAST severe to MOST severe, which is the reverse of the usual IDOT
    * 1-is-fatal convention, and is why this was checked rather than assumed.
    * The 23 missing injuries are the blank-v13 rows and are reported below
    * rather than reallocated

    * Counting pass first, as for the other two files. This guard was missing
    * until the 2012 parser bug was found, which left the person file as the
    * one input that could have been read short in silence: it drives
    * total_persons and every persons_* count, and a partial read would show
    * up only as a soft divergence in the section 2 reconciliation report.
    * PersonExtract carries no free text and has zero odd-parity lines in
    * 2009-2012, so this is expected to be a no-op in every year
    local delim_p ""
    foreach d in "|" "," {
        if "`delim_p'" == "" {
            capture qui import delimited using "`ydir'/PersonExtract.txt", ///
                varnames(nonames) stringcols(_all) delimiters("`d'") ///
                bindquote(loose) rowrange(1:1) clear
            if _rc == 0 {
                qui describe, varlist
                local nf : word count `r(varlist)'
                if `nf' >= 32 local delim_p "`d'"
            }
        }
    }
    if "`delim_p'" == "" {
        di as error "PersonExtract.txt `yr': cannot work out the delimiter (tried pipe and comma)."
        error 459
    }
    if "`delim_p'" != "," {
        di as text "  PersonExtract.txt `yr': delimiter is `delim_p', not comma"
    }

    clear
    `q' import delimited using "`ydir'/PersonExtract.txt", ///
        varnames(nonames) stringcols(_all) delimiters("`delim_p'") ///
        bindquote(nobind) colrange(1:1) clear
    qui count
    local n_lines_per = r(N)

    clear
    `q' import delimited using "`ydir'/PersonExtract.txt", ///
        varnames(nonames) stringcols(_all) delimiters("`delim_p'") ///
        bindquote(loose) clear
    qui count
    local n_read_per = r(N)

    local n_lost_per  = `n_lines_per' - `n_read_per'
    local max_lost_per = max(20, ceil(0.001 * `n_lines_per'))

    di as text "PersonExtract `yr': `n_read_per' person records from `n_lines_per' lines"

    if `n_lost_per' > `max_lost_per' {
        di as error "PersonExtract `yr': `n_lost_per' of `n_lines_per' lines did not survive"
        di as error "parsing, past the tolerance of `max_lost_per'. total_persons and the"
        di as error "persons_* injury counts come from this file. See section 1A."
        error 459
    }
    if `n_lost_per' > 0 {
        di as error "NOTE: `n_lost_per' PersonExtract line(s) did not survive parsing in `yr'."
        di as error "Within tolerance, but check the reconciliation report in section 2:"
        di as error "a short read here shows up there and nowhere else."
    }

    * layout guard
    qui describe, varlist
    local n_fields : word count `r(varlist)'
    di as text "  PersonExtract `yr': `n_fields' fields"
    if `n_fields' < 32 {
        di as error "PersonExtract `yr': `n_fields' fields, at least 32 needed."
        di as error "Injury and impairment are addressed by position. Do not run."
        error 459
    }


    /* [> drop misparsed rows before anything else reads them <] */

    * ADDED AFTER THE FIRST FULL RUN, which died here on 2015. The crash file
    * has had a validity filter since 2012; these two did not, and 2015 showed
    * why they need one.
    *
    * PersonExtract carries free text that the crash file does not: the EMS
    * agency and receiving hospital. Those values contain apostrophes
    * ("Veteran's Hospital"), stray double quotes, and in some records an
    * embedded newline. Under loose quote binding that shifts the field
    * boundaries WITHIN a line, so the record count still equals the line
    * count and the row-count guard above reports nothing lost, but about 109
    * rows in 2015 come out with the tail of a neighbouring record sitting in
    * column 1. Their crash ids read like
    *   ,","Driver",","Normal","Did Not Deploy",...
    *
    * Two things then went wrong, and both are fixed by dropping these rows
    * here rather than downstream:
    *
    *   the orphan check treated all 109 as crash ids missing from
    *   CrashExtract and stopped the build, because its tolerance is the
    *   number of CRASH lines lost to parsing, which was zero. That budget
    *   was the wrong instrument: a garbled row in THIS file is not a
    *   crash-file parse loss and should not be measured against one
    *
    *   the person type code search returned nothing, because it looks for a
    *   column holding only digits 1-9 on EVERY row and the garbled rows hold
    *   text in all of them. So the code-against-label cross-check was
    *   skipped, on a year where it was most needed
    *
    * A valid crash id is all digits, which is true in every year and every
    * file. Rows failing that are unusable and are dropped with a report,
    * under a ceiling: a handful is stray free text, thousands would mean the
    * delimiter or quoting convention moved and must stop the build
    *
    * WHAT THIS DOES NOT FIX, and it is worth knowing. A record broken by an
    * embedded newline produces TWO rows: a fragment, which this drops, and a
    * PARENT that keeps a valid numeric crash id and everything up to the
    * break, then simply ends. The parent survives the filter, correctly, but
    * it is truncated.
    *
    * Where the break falls decides what is lost. The free text is the EMS
    * agency and hospital, at baseline positions 17 and 18, so a parent keeps
    * the injury classification (position 13) and loses the person type (22)
    * and the physical condition (24). In practice that means:
    *
    *   the injury counts and the reconciliation in section 2 are UNAFFECTED,
    *   which is why 2010-2024 reconciled exactly even in years with breaks
    *   alcohol and drug are very slightly UNDERSTATED, because a truncated
    *   parent has a blank condition and scores 0 on both
    *
    * On 2015, the worst year seen, there are about 160 such records in
    * 731,739, so the understatement is of order 0.02% and is not worth
    * reconstructing. If a year ever shows a large count in the misparse
    * table printed at the end of section 1, revisit that judgement
    qui gen byte _validrow = real(strtrim(v1)) < . & strtrim(v1) != ""
    qui count if _validrow == 0
    local n_junk_per = r(N)
    local max_junk_per = max(50, ceil(0.001 * `n_read_per'))

    if `n_junk_per' > `max_junk_per' {
        di as error "PersonExtract `yr': `n_junk_per' of `n_read_per' rows have a non-numeric"
        di as error "crash id, past the tolerance of `max_junk_per'."
        di as error "At this scale the delimiter or the quoting convention has moved,"
        di as error "rather than a few rows being garbled by stray free text."
        di as error "First ten offending ids:"
        preserve
            qui keep if _validrow == 0
            qui gen str60 _excerpt = substr(v1, 1, 60)
            list _excerpt in 1/10, noobs sep(0) string(60)
        restore
        error 459
    }

    if `n_junk_per' > 0 {
        di as error "NOTE: dropping `n_junk_per' misparsed row(s) from PersonExtract `yr'"
        di as error "(crash id is not numeric; free text has shifted the field boundaries)."
        drop if _validrow == 0
    }
    drop _validrow

    * strL guard. THIS IS THE ONE THAT BIT: 2017 PersonExtract has a misparsed
    * row longer than 2,045 characters, which made crash_id strL for the whole
    * year and killed the merge in 1D. See the note in the crash block
    qui compress v1

    /* [> locate the columns <] */

    * Shifts the same way the vehicle file does: 2013 inserts a person record
    * id at position 2, moving the injury classification from v13 to v14 and
    * the physical condition from v24 to v25. Read at the baseline positions
    * a 2013 file would take seat position as the injury code and pedestrian
    * clothing as the driver condition, so every impairment flag would be zero
    * and the injury counts would be nonsense that still summed to something
    *
    * Anchor: the decoded person type, which is "Driver" on roughly three
    * rows in four in every year
    local anchor_base 22
    local offset = -1
    forvalues o = 0/4 {
        if `offset' == -1 {
            local j = `anchor_base' + `o'
            capture confirm variable v`j'
            if _rc == 0 {
                qui count if lower(strtrim(v`j')) == "driver"
                if r(N) > 0.5 * _N {
                    local offset = `o'
                }
            }
        }
    }

    if `offset' == -1 {
        di as error "PersonExtract `yr': cannot find the person type column."
        di as error "Searched v`anchor_base' to v`=`anchor_base'+4' for a column that is mostly"
        di as error "Driver, and found none. The injury and impairment columns are located"
        di as error "relative to it, so the build stops rather than reading the wrong ones."
        error 459
    }

    if `offset' != 0 {
        di as text "  PersonExtract `yr': columns shifted by +`offset' from the baseline."
    }

    * THE PERSON TYPE CODE IS LOCATED SEPARATELY, and 2020 is why. A single
    * offset assumes the whole file shifts together. In 2020 it does not:
    * a person record id is INSERTED at position 2 and the date of birth is
    * REMOVED at position 5, so columns 2-4 move by +1 while everything from
    * position 5 on comes back to the baseline. Net offsets in one file:
    *
    *   2009-2012   type code v2   injury v13   type v22   condition v24
    *   2013-2019   type code v3   injury v14   type v23   condition v25
    *   2020        type code v3   injury v13   type v22   condition v24
    *
    * The anchor sees person type at v22 and reports offset 0, which is right
    * for injury, type and condition and wrong only for the type code. Left
    * in the baseline map, person_type_code would have picked up the person
    * RECORD ID at v2, and the cross-check below would then have passed
    * vacuously: record ids are eight digits, so they never equal 1 or 7 and
    * neither branch of the test can fire. A guard that cannot fail is worse
    * than no guard, so the code column gets its own search
    *
    * It is found by content, not position: the only column in the first few
    * that holds nothing but a single digit 1-9 on every row
    * 99%, not 100%. The first version required EVERY row to be a single
    * digit, which one blank or one stray value is enough to defeat, and the
    * consequence of failing is that the cross-check is skipped silently.
    * A threshold makes it robust to a handful of bad rows while still being
    * unambiguous: the person record id is eight digits and scores zero, the
    * unit number is zero-padded ("01") and scores zero, and age scores zero,
    * so only the real type code column can clear 99%
    local code_col = 0
    forvalues j = 2/6 {
        if `code_col' == 0 {
            capture confirm variable v`j'
            if _rc == 0 {
                qui count if inlist(strtrim(v`j'), "1","2","3","4","5","6","7","8","9")
                if r(N) > 0.99 * _N local code_col = `j'
            }
        }
    }

    * Baseline positions for the columns that DO move together
    local basemap injury_class 13 person_type 22 person_condition 24

    local nmap : word count `basemap'
    local keeplist v1
    forvalues k = 1(2)`nmap' {
        local pos : word `=`k'+1' of `basemap'
        local col = `pos' + `offset'
        capture confirm variable v`col'
        if _rc != 0 {
            local nm : word `k' of `basemap'
            di as error "PersonExtract `yr': `nm' should be at v`col' but that variable"
            di as error "does not exist. The file is shorter than the layout expects."
            error 459
        }
        local keeplist `keeplist' v`col'
    }
    if `code_col' > 0 {
        local keeplist `keeplist' v`code_col'
    }
    keep `keeplist'

    rename v1 crash_id
    forvalues k = 1(2)`nmap' {
        local nm  : word `k' of `basemap'
        local pos : word `=`k'+1' of `basemap'
        rename v`=`pos'+`offset'' `nm'
    }
    if `code_col' > 0 {
        rename v`code_col' person_type_code
    }

    qui replace crash_id = strtrim(crash_id)
    foreach v of varlist person_type person_condition {
        qui replace `v' = lower(strtrim(ustrtrim(`v')))
    }
    `q' destring injury_class, replace ignore(",")

    /* [> truncated rows <] */

    * THE OTHER HALF OF A RECORD BROKEN BY AN EMBEDDED NEWLINE, and the second
    * full run stopped here on 2015 because of it.
    *
    * The filter above drops the FRAGMENT, whose crash id is text. It cannot
    * drop the PARENT, whose id is a perfectly good number: the parent keeps
    * every column up to the break and then simply ends. The break is at the
    * EMS agency and hospital fields, baseline positions 17 and 18, so a
    * parent carries a valid id and a valid injury classification (13) and a
    * valid type CODE (2 or 3), but a BLANK person type label (22) and a blank
    * condition (24).
    *
    * That is what broke the cross-check below. It asks whether code 1 means
    * "driver", and on a truncated parent the code says 1 while the label is
    * empty, so it read 148 truncated rows in 2015 as a column misalignment
    * and stopped. The test has to be restricted to rows that actually have a
    * label to compare, which is done in the count itself
    *
    * The parents are KEPT, deliberately. Their injury classification is
    * intact and it is the thing the person file is here for, so dropping them
    * would lose real fatalities and injuries from the reconciliation. What is
    * lost is their condition, so they score 0 on alcohol and drug:
    * 148 rows in 731,739 is an understatement of order 0.02%
    *
    * Counted and reported under a ceiling, because a large number would mean
    * the file is being read at the wrong offset rather than lightly damaged
    qui count if person_type == "" | person_type == "(unk)"
    local n_trunc = r(N)
    local max_trunc = max(100, ceil(0.002 * `n_read_per'))

    if `n_trunc' > `max_trunc' {
        di as error "PersonExtract `yr': `n_trunc' of `n_read_per' rows have a blank person"
        di as error "type, past the tolerance of `max_trunc'."
        di as error "A handful is records broken by an embedded newline. This many means the"
        di as error "person type column is not where the anchor search put it, or the file"
        di as error "is not being parsed as intended. Nothing has been kept."
        error 459
    }

    if `n_trunc' > 0 {
        di as text "  PersonExtract `yr': `n_trunc' truncated row(s) kept with a blank"
        di as text "  condition (record broken by an embedded newline; injury is intact)"
    }

    * The coded and decoded person type must agree. This is the cross-check
    * that confirms the offset detection landed on the right columns, in a
    * file whose other columns are mostly free-form
    *
    * RESTRICTED TO ROWS THAT HAVE A LABEL, for the reason above. That does
    * not weaken it: a genuine misalignment puts the wrong column here on
    * EVERY row, not on a handful, so it would still fail on the rows that do
    * carry a label
    if `code_col' > 0 {
        `q' destring person_type_code, replace ignore(",")
        qui count if person_type != "" & ///
                     ((person_type_code == 1 & person_type != "driver") | ///
                      (person_type_code == 7 & person_type != "passenger"))
        if r(N) > 0 {
            di as error "PersonExtract `yr': person type code and label disagree on `r(N)' rows"
            di as error "that carry a label. These are the same field coded and decoded, so a"
            di as error "disagreement means the offset detection above landed on the wrong"
            di as error "pair of columns. Truncated rows are already excluded from this test."
            error 459
        }
        drop person_type_code
    }
    else {
        di as error "NOTE: PersonExtract `yr' has no single-digit person type code column"
        di as error "in v2-v6, so the code-against-label cross-check was SKIPPED."
        di as error "The person type label anchored at v`=22+`offset'' and the injury and"
        di as error "condition columns are taken from it. Worth an eyeball before use."
    }

    * v13 domain check. A new injury code would land silently as "not any of
    * the five" and quietly vanish from every count below
    qui count if !inlist(injury_class, 0, 1, 2, 3, 4) & !missing(injury_class)
    if r(N) > 0 {
        di as error "PersonExtract `yr': the injury column holds `r(N)' value(s) outside 0-4."
        qui levelsof injury_class if !inlist(injury_class, 0, 1, 2, 3, 4) & !missing(injury_class), local(badinj)
        di as error "Found: `badinj'. Injury coding is documented in section 1C; re-check it."
        error 459
    }

    /* [> person-level injury counts <] */

    gen byte persons_killed     = (injury_class == 4)
    gen byte persons_a_injury   = (injury_class == 3)
    gen byte persons_b_injury   = (injury_class == 2)
    gen byte persons_c_injury   = (injury_class == 1)
    gen byte persons_no_injury  = (injury_class == 0)
    gen byte persons_inj_unknown = missing(injury_class)

    * total_persons is COUNTED here rather than read from crash column v16,
    * which undercounts (see section 0C). One row per person, so a constant 1
    * summed by crash and then by county-year
    gen byte total_persons = 1

    * Non-motorists, which the ID delivery does not identify at all. Carried
    * because a pedestrian or cyclist crash is a different event from a
    * vehicle-animal strike and an analysis may want to exclude them
    gen byte persons_pedestrian  = (person_type == "pedestrian")
    gen byte persons_pedalcyclist = (person_type == "pedalcyclist")

    /* [> impairment, drowsiness <] */

    * The exact 11 strings v24 takes are: Normal, Other/Unknown, Alcohol
    * Impaired, Had Been Drinking, Asleep/Fainted, Fatigued, Drug Impaired,
    * Illness, Medicated, No Data, and blank. Blank is the most common value
    * after Normal (184,750 rows) because the field is a DRIVER attribute and
    * is empty on passenger and non-motorist rows
    *
    * "Had Been Drinking" is pooled into alcohol, matching how ID pools
    * "Fatigued" with "Asleep, Drowsy, Fatigued": it is a weaker statement
    * than Alcohol Impaired but it is a statement about alcohol. Keeping them
    * separable would mean two more variables for 2,205 rows a year; if that
    * distinction ever matters, split here and the rest of the file follows
    *
    * "Medicated" and "Illness" are NOT pooled into drugs. Medicated means
    * prescription medication and Illness is not impairment at all, so folding
    * either into drug_collision would make the drug series mean something
    * different from ID's "Drug Impaired"
    *
    * The matched labels are spelled identically in 2009-2013, but the
    * vocabulary AROUND them moves: "No Data" became "Not Reported" in 2010,
    * and 2013 drops "Asleep/Fainted" and adds "Other", "Emotional" and
    * "Removed by EMS".
    *
    * THE DROWSINESS CODES ARE NO LONGER READ. "Asleep/Fainted" and "Fatigued"
    * both meant drowsy and both fed a drowsy_collision flag, dropped on
    * 09/09/2026 with the rest of the behaviour dummies. Noted because the two
    * codes were merged in 2013, so anyone rebuilding the flag should expect
    * 2009-2012 to be the sum of two codes and 2013 onward to be one
    *
    * 2019 ADDS A COMBINED CODE, "Impaired-Alcohol and Drugs", on 190 people.
    * Matched on substrings so it lands in BOTH alcohol_collision and
    * drug_collision, which is what it says happened. Exact equality would
    * have dropped it from both and from dui_collision as well
    *
    * The substrings are safe against the rest of the vocabulary: nothing
    * else in this column contains "alcohol" or "drug". "Had Been Drinking"
    * contains neither and stays an explicit match, and "Medicated" is still
    * deliberately excluded from drugs
    gen byte alcohol_collision = (strpos(person_condition, "alcohol") > 0 | ///
                                  person_condition == "had been drinking")
    gen byte drug_collision    = (strpos(person_condition, "drug") > 0)

    drop person_type person_condition injury_class

    * (max) up to the crash for the flags, (sum) for the counts. A crash is
    * flagged if any of its people is flagged, and carries the total of its
    * people at each injury level. Same collapse-then-max logic as ID
    * sections 2, 3 and 3B, and it is what stops a five-occupant crash with
    * one drinking driver counting five times
    collapse (sum) total_persons ///
                   persons_killed ///
                   persons_a_injury ///
                   persons_b_injury ///
                   persons_c_injury ///
                   persons_no_injury ///
                   persons_inj_unknown ///
                   persons_pedestrian ///
                   persons_pedalcyclist ///
             (max) alcohol_collision ///
                   drug_collision, ///
                   by(crash_id)

    strip_collapse_labels

    * Impaired driving of any kind. Generated AFTER the collapse so it is the
    * crash-level OR of two crash-level flags, matching ID section 3B. Built
    * at row level and maxed it would give the same answer, but a driver
    * flagged alcohol and a different driver flagged drugs in the same crash
    * is a crash with impairment either way and this makes that explicit
    gen byte dui_collision = (alcohol_collision == 1 | drug_collision == 1)

    * Orphan check. On 2009 all 292,328 person-file crash ids are in
    * CrashExtract, and 109 crashes have no person record at all. Those 109
    * are kept with zero persons rather than dropped, and section 4 reports
    * them: a crash with no occupant record is usually a parked-vehicle or
    * property-damage-only report, not a data error
    * Same parse-loss budget as 1B; see the note there
    `q' merge 1:1 crash_id using `ids_yr'
    qui count if _merge == 1
    local n_orph = r(N)
    if `n_orph' > 0 {
        di as error "PersonExtract `yr': `n_orph' crash id(s) have no record in CrashExtract"
        di as error "(`n_lost_crash' crash line(s) were lost to parsing)."
        di as error "First few, at most ten:"
        preserve
            qui keep if _merge == 1
            local nshow = min(10, _N)
            list crash_id in 1/`nshow', noobs sep(0)
        restore
        if `n_orph' > `n_lost_crash' {
            di as error "More orphans than lost lines can explain. Stopping."
            di as error "If the ids above look like fragments of other records rather than"
            di as error "numbers, the row-validity filter earlier in this block missed them."
            error 459
        }
        di as error "Within the parse-loss budget, so these are dropped."
        drop if _merge == 1
    }
    qui count if _merge == 2
    local n_no_person = r(N)
    drop _merge

    di as text "  crashes with no person record in `yr': `n_no_person'"

    `q' save `person_yr', replace

    /*-------------- 1D: assemble the year --------------*/

    use `crash_yr', clear

    `q' merge 1:1 crash_id using `animal_yr'
    qui count if _merge == 2
    assert r(N) == 0
    drop _merge

    `q' merge 1:1 crash_id using `person_yr'
    qui count if _merge == 2
    assert r(N) == 0
    drop _merge

    * A crash absent from the vehicle or person file has no animal event and
    * no impaired occupant RECORDED, so it is coded 0 rather than left
    * missing, exactly as ID section 5 does. On 2009 the vehicle file covers
    * every crash so nothing is filled on the animal side; the 109
    * person-record-free crashes are filled here
    foreach v in animal_event wild_animal_collision ///
                 non_wild_animal_collision animal_first_collision ///
                 wild_animal_first_collision non_wild_animal_first_coll ///
                 has_event_record ///
                 alcohol_collision drug_collision dui_collision {
        qui replace `v' = 0 if missing(`v')
    }
    foreach v in total_persons persons_killed persons_a_injury ///
                 persons_b_injury persons_c_injury persons_no_injury ///
                 persons_inj_unknown persons_pedestrian persons_pedalcyclist {
        qui replace `v' = 0 if missing(`v')
    }

    /* [> circumstance flags, from the crash-level cause columns <] */

    * The IL analogue of ID section 3. IL puts contributing cause at CRASH
    * level in two columns rather than at unit level in three, so there is
    * nothing to collapse and the flags are built directly here
    *
    * TWO SLOTS, NOT THREE, and an unused slot holds the literal string "NA"
    * rather than a blank, which is the same trap ID section 3B flags for its
    * "None": anything reasoning about these columns with missing() will
    * conclude they are almost always populated and be wrong about it
    *
    * ONE CODE IS MOJIBAKED, and it no longer matters but is recorded because
    * it will. "Distraction [en dash] other electronic device (navigation
    * device, DVD player, etc.)" arrives with the en dash mis-decoded as a
    * Latin-1 byte, the same defect ID section 3 records in the opposite
    * direction for its "Emotional" code. Nothing below reads the distraction
    * codes now that distracted_collision is gone, so nothing is affected. A
    * flag added here later must match "Distraction" on a substring: equality
    * against the four full labels would silently drop 168 crashes a year
    *
    * ALCOHOL IS DELIBERATELY NOT BUILT FROM THESE COLUMNS. IL's cause
    * vocabulary has a single combined "Under Influence of Alcohol/Drugs"
    * (5,739 crashes in 2009) plus "Had Been Drinking" (1,047), so it cannot
    * separate the two the way ID's "Alcohol Impaired" and "Drug Impaired"
    * can. alcohol_collision and drug_collision therefore come from the person
    * file in section 1C, and the cause-based measure is carried alongside as
    * dui_cause_collision. The two are not interchangeable and the log reports
    * how far apart they run: the cause side is an officer's judgment about
    * what caused the crash, the person side is an assessment of a specific
    * occupant, and neither is a subset of the other
    /* [> the three animal families, and the cause-based impairment flag <] */

    * REBUILT TO THE CROSS-STATE NAMING CONVENTION. The earlier version of
    * this file published four overlapping animal measures under IL-specific
    * names, which is the one thing that makes a multi-state panel unusable:
    * another state's animal_collision is its TOTAL animal measure, whereas
    * this file's animal_collision was only the event-based part, so a pooled
    * regression would have compared a subset against a total.
    *
    * Three families, and only three:
    *
    *   animal_           struck an animal OR an animal contributed. THE
    *                     TOTAL, and the family that lines up with
    *                     animal_collision in every other state file
    *   wild_animal_      the Deer event code. A subset of animal_
    *   non_wild_animal_  the Other Animal event code. A subset of animal_
    *
    * THE SPECIES FAMILIES DO NOT PARTITION animal_, and this matters when
    * reading the panel. A crash can carry both a deer and an other-animal
    * event and is counted in both. A crash known only from the cause column
    * records no species at all and appears in animal_ alone. So wild plus
    * non_wild is neither equal to nor bounded below animal at county-year
    * level, and section 4 asserts only that each is a subset of the total
    *
    * The cause column is unioned in rather than published separately, so the
    * old animal_circ_* and animal_type_* families are gone. They measured the
    * same event three ways and no other state carries the alternatives
    gen byte animal_circ = 0
    gen byte dui_cause_collision = 0

    * MATCHED ON SUBSTRINGS, NOT FULL LABELS, and the 2010 delivery is the
    * reason: "Exceeding Safe Speed for Conditions" became "...For...", two
    * distraction codes acquired a mojibaked en dash, and the reckless-driving
    * code was renamed outright. Every one of those is an exact-equality match
    * that would have gone quietly to zero.
    *
    * "animal" stays an EXACT match on purpose. A substring would also catch
    * "Evasive Action Due to Animal / Object / Non-Motorist", which is a crash
    * where the animal was AVOIDED, and folding an avoidance into a strike
    * count would overstate every animal series by a few thousand a year
    forvalues c = 1/2 {
        qui replace animal_circ = 1 if cause`c' == "animal"

        qui replace dui_cause_collision = 1 ///
            if strpos(cause`c', "under influence") > 0 | ///
               strpos(cause`c', "had been drinking") > 0
    }

    gen byte animal_collision = (animal_event == 1 | animal_circ == 1)

    drop cause1 cause2 animal_event animal_circ

    gen byte year_source = 1

    if `first_year_processed' == 1 {
        `q' save `panel', replace
        local first_year_processed = 0
    }
    else {
        `q' append using `panel'
        `q' save `panel', replace
    }

    local jc_`yr' = `n_junk'
    local jv_`yr' = `n_junk_veh'
    local jp_`yr' = `n_junk_per'
}

* THE MISPARSE TABLE. Any non-zero entry is a year where a free-text field
* contained an unescaped quote or an embedded newline, and rows were dropped
* because their crash id came out as text. See the filters in 1A, 1B and 1C
di as text _newline "{hline 70}"
di as text "Misparsed rows dropped, by year:"
di as text %6s "year" %12s "crash" %12s "vehicle" %12s "person"
local anyjunk = 0
foreach y of global il_years {
    di as text %6s "`y'" %12.0fc `jc_`y'' %12.0fc `jv_`y'' %12.0fc `jp_`y''
    if `jc_`y'' + `jv_`y'' + `jp_`y'' > 0 local anyjunk = 1
}
if `anyjunk' == 0 {
    di as text "  (none in any year: every row in every file parsed to a numeric crash id)"
}
di as text "{hline 70}"

clear
use `panel'
drop year_source

* No crash may appear in two year folders, which would double count it. The IL
* id embeds the year (200901010101) so this should be impossible, but the
* 8-character ids noted in section 0C do not, so it is checked rather than
* assumed
isid crash_id

di as text _newline "{hline 70}"
di as text "Assembled crash-level file. Crashes by year:"
tab year


/*-----------------SECTION 2: person-file reconciliation report --------------*/

* This is the section ID could not write. It compares the person-level injury
* counts built in section 1C against the crash-level counts in CrashExtract.
* ID section 4 exists to explain why its person file is unusable; this one
* exists to demonstrate that IL's is usable, which is what licenses the
* persons_* variables in the collapse
*
* Reported, not asserted. A handful of persons with a blank injury code is a
* data-entry gap, not a build error, and the right response is to see the size
* of it rather than to stop. If the gap is ever large it means the person file
* has become partial the way ID's is, and the persons_* variables should then
* be dropped rather than published

if `check_person_injury' == 1 {

    di as text _newline "Person-level injury counts against crash-level totals:"
    di as text "  (person side is the sum over PersonExtract rows, crash side is CrashExtract)"

    foreach pair in "persons_killed total_fatalities" ///
                    "persons_a_injury a_injuries" ///
                    "persons_b_injury b_injuries" ///
                    "persons_c_injury c_injuries" {

        local pv : word 1 of `pair'
        local cv : word 2 of `pair'

        qui summ `pv', meanonly
        local psum = r(sum)
        qui summ `cv', meanonly
        local csum = r(sum)
        local diff = `psum' - `csum'
        local pct = 100 * `psum' / max(`csum', 1)

        di as text "  `pv' = " %10.0fc `psum' "   vs `cv' = " %10.0fc `csum' ///
                   "   diff " %6.0fc `diff' "  (" %6.2f `pct' "%)"
    }

    qui summ persons_inj_unknown, meanonly
    di as text "  persons with a blank injury code: " %8.0fc r(sum)

    * Crashes with no person record at all
    qui count if total_persons == 0
    di as text "  crashes with no person record: `r(N)'"

    * PER-CRASH, not just in aggregate, and it runs here because the persons_*
    * variables are dropped before the collapse in section 4. The aggregate
    * totals above could match while individual crashes disagreed in
    * offsetting directions; this is the stronger statement and it is the one
    * that licenses treating the injury coding as understood
    qui count if persons_killed != total_fatalities
    if r(N) > 0 {
        di as error "  WARNING: `r(N)' crash(es) where the person-file fatality count"
        di as error "  differs from the crash-file total. Expected: none. A handful is a"
        di as error "  data-entry gap; many would mean the person file has gone partial"
        di as error "  the way ID's AccdPerson_Injury did."
    }
    else {
        di as text "  person and crash fatality counts agree on every crash"
    }
}


/*-----------------SECTION 3: severity, conditions, interactions --------------*/


/* [> severity <] */

* IL reports crash severity two ways and this uses both. v20 gives the
* three-way Fatal / Injury / Property Damage, and the A/B/C person counts give
* the injury breakdown that v20 does not. The unusable v61/v68 "most severe
* injury" pair is ignored; see section 0C
*
* The pooling matches ID and AZ so the series stay comparable. AZ reports a
* numeric code where 4 is major injury and 2 and 3 are both folded into minor;
* ID pools its B and C injury accidents into minor_injury_collision and
* carries C alone as possible_injury_collision. IL does the same here, with
* the crash's severity level taken as its most severe reported injury:
*
*   fatal_collision            at least one person killed
*   major_injury_collision     no death, at least one A injury
*   minor_injury_collision     no death and no A, at least one B or C
*   pdo_collision              property damage only
*
* possible_injury_collision is a subset and not a sibling, exactly as in the
* ID file. B injuries alone are minor_injury_collision - possible_injury_collision
*
* THE THREE-WAY SPLIT COMES FROM THE SEVERITY COLUMN, NOT FROM THE COUNTS,
* and the first full run is why. The original built injury_collision as
* "major or minor", i.e. out of the A/B/C counts, and then asserted that the
* three categories partition the panel. They do not, on 68 crashes out of
* 4,750,489:
*
*   54 crashes are severity "Injury" with A = B = C = 0, so all three flags
*      came out 0 and the crash fell into no category at all
*   14 crashes are severity "Property Damage" with an A, B or C injury
*      recorded, so pdo AND an injury flag both fired and the sum was 2
*
* Both are the severity column disagreeing with the injury counts on the same
* record. Neither can be adjudicated from inside this file, and at 0.0014% of
* the panel neither is worth adjudicating.
*
* What matters is that the partition holds BY CONSTRUCTION rather than by
* luck, so the three flags are now read straight off severity, whose
* vocabulary section 1A has already checked. The A/B/C counts then SUBDIVIDE
* the injury category instead of defining it
*
* NOT A PROBLEM, and worth saying because it looks like one in the crosstab:
* 9,227 FATAL crashes have A = B = C = 0. A crash that kills someone and
* injures nobody else is exactly that, since the death is counted in
* total_fatalities and not in the A/B/C columns
gen byte fatal_collision  = (severity == "fatal")
gen byte injury_collision = (severity == "injury")
gen byte pdo_collision    = (severity == "property damage")

* The injury severity split, now a subdivision of injury_collision. The
* residual catches the 54 crashes typed Injury with no injury recorded; it is
* carried rather than forced into minor, so the counts stay honest and the
* assert in section 4 can be exact
gen byte major_injury_collision = (injury_collision & a_injuries > 0)
gen byte minor_injury_collision = (injury_collision & a_injuries == 0 & ///
                                   (b_injuries > 0 | c_injuries > 0))
gen byte injury_unclassified_collision = (injury_collision & ///
                                          a_injuries == 0 & ///
                                          b_injuries == 0 & ///
                                          c_injuries == 0)

* The partition is now guaranteed, so this can stay a hard assert: it can
* only fail if severity holds a value outside the three, which the domain
* check in 1A already rules out
assert fatal_collision + injury_collision + pdo_collision == 1

* WHERE SEVERITY AND THE COUNTS DISAGREE, reported rather than fatal. These
* are the 68 records described above. They are not errors this file can fix,
* but they are the kind of thing that should not pass unseen, and a sudden
* rise in either would mean the severity column or the count columns had
* moved
qui count if injury_collision & a_injuries == 0 & b_injuries == 0 & c_injuries == 0
local n_inj_noabc = r(N)
qui count if pdo_collision & (a_injuries > 0 | b_injuries > 0 | c_injuries > 0)
local n_pdo_abc = r(N)

if `n_inj_noabc' + `n_pdo_abc' > 0 {
    di as text _newline "Severity column against the A/B/C injury counts:"
    di as text "  typed Injury but no A/B/C recorded:  " %8.0fc `n_inj_noabc' ///
               "   (counted as injury_unclassified)"
    di as text "  typed Property Damage but A/B/C > 0: " %8.0fc `n_pdo_abc' ///
               "   (counted as PDO; their injuries still sum into total_injuries)"

    if `n_inj_noabc' + `n_pdo_abc' > 0.001 * _N {
        di as error "That is more than 0.1% of the panel. The severity column and the"
        di as error "injury counts are meant to describe the same crash, so a gap this"
        di as error "size means one of them is not the column this file thinks it is."
        error 459
    }
}
drop severity

* Summing rows by county-year gives total_all_cause after the collapse
gen byte total_all_cause = 1

/* [> injury counts <] */

* IA carries major_injuries and minor_injuries alongside total_injuries. IL
* has the same information in its A/B/C columns, so it is renamed into IA's
* vocabulary: major is A, which IA calls serious, and minor is B + C, which is
* how IA pools its minor and possible. ID cannot build these at all, having
* only crash-level severity, so they are IL-and-IA columns rather than
* IL-only ones
gen major_injuries = a_injuries
gen minor_injuries = b_injuries + c_injuries

/* [> possible injury, the C-only detail <] */

* A SUBSET of minor_injury_collision, not a sibling, exactly as in ID: B and C
* are pooled into minor to match how AZ folds its codes 2 and 3, and this
* carries C on its own. B alone is minor minus possible
gen byte possible_injury_collision = (injury_collision & a_injuries == 0 & ///
                                      c_injuries > 0)

/* [> the three animal families <] */

* Built in sections 1B and 1D. The crosses below follow the ID file's naming
* exactly, including its asymmetry: the animal_ family carries a _collision
* suffix on its severity crosses and the two species families do not. That is
* ID's convention and the two files have to agree for an append to work
*
* EVERY CONDITION AND CAUSE INTERACTION IS GONE, as in ID: no darkness, dawn,
* ice, autumn or rural crosses. Deer activity by light and season is a real
* question and belongs in an analysis file built on this panel
gen fatal_animal_collision            = animal_collision*fatal_collision
gen injury_animal_collision           = animal_collision*injury_collision
gen major_injury_animal_collision     = animal_collision*major_injury_collision
gen minor_injury_animal_collision     = animal_collision*minor_injury_collision
gen possible_injury_animal_collision  = animal_collision*possible_injury_collision
gen pdo_animal                        = animal_collision*pdo_collision
gen animal_fatalities                 = animal_collision*total_fatalities
gen animal_injuries                   = animal_collision*total_injuries
gen animal_persons                    = animal_collision*total_persons

gen fatal_wild_animal                 = wild_animal_collision*fatal_collision
gen injury_wild_animal                = wild_animal_collision*injury_collision
gen major_injury_wild_animal          = wild_animal_collision*major_injury_collision
gen minor_injury_wild_animal          = wild_animal_collision*minor_injury_collision
gen possible_injury_wild_animal       = wild_animal_collision*possible_injury_collision
gen pdo_wild_animal                   = wild_animal_collision*pdo_collision
gen wild_animal_fatalities            = wild_animal_collision*total_fatalities
gen wild_animal_injuries              = wild_animal_collision*total_injuries
gen wild_animal_persons               = wild_animal_collision*total_persons

gen fatal_non_wild_animal             = non_wild_animal_collision*fatal_collision
gen injury_non_wild_animal            = non_wild_animal_collision*injury_collision
gen major_injury_non_wild_animal      = non_wild_animal_collision*major_injury_collision
gen minor_injury_non_wild_animal      = non_wild_animal_collision*minor_injury_collision
gen possible_injury_non_wild_animal   = non_wild_animal_collision*possible_injury_collision
gen pdo_non_wild_animal               = non_wild_animal_collision*pdo_collision
gen non_wild_animal_fatalities        = non_wild_animal_collision*total_fatalities
gen non_wild_animal_injuries          = non_wild_animal_collision*total_injuries
gen non_wild_animal_persons           = non_wild_animal_collision*total_persons

di as text _newline "The two species codes against the animal total:"
di as text "(these do NOT partition it: a cause-only animal crash has no species,"
di as text " and a crash can carry both a deer and an other-animal event)"
tab wild_animal_collision non_wild_animal_collision

/* [> alcohol, drugs and impaired driving <] */

* KEPT, unlike the condition and cause dummies, because ID builds the same
* three. IL's are built from the person file, which is the only place the
* delivery separates alcohol from drugs; the crash-level cause column
* combines them and is carried alongside as dui_cause_collision
foreach fam in alcohol drug dui {
    gen fatal_`fam'_collision        = `fam'_collision*fatal_collision
    gen injury_`fam'_collision       = `fam'_collision*injury_collision
    gen major_injury_`fam'_collision = `fam'_collision*major_injury_collision
    gen minor_injury_`fam'_collision = `fam'_collision*minor_injury_collision
    gen pdo_`fam'                    = `fam'_collision*pdo_collision
    gen `fam'_fatalities             = `fam'_collision*total_fatalities
    gen `fam'_injuries               = `fam'_collision*total_injuries
}

di as text _newline "Person-based impairment against the cause-based measure:"
di as text "(neither is a subset of the other; see the note in section 1D)"
tab dui_collision dui_cause_collision

/* [> the impaired-driver overlap with each animal family <] */

* An animal strike reported by a driver who was also flagged as impaired.
* Carried for all three families as in ID, so a DVC count can be netted of
* impaired drivers by subtraction in the ANALYSIS file: animal_collision minus
* dui_animal_collision. The subtraction is deliberately not done here, because
* both terms are already in the panel and the netted column would be a third
* copy of the same information
gen dui_animal_collision          = dui_collision*animal_collision
gen fatal_dui_animal              = dui_animal_collision*fatal_collision
gen injury_dui_animal             = dui_animal_collision*injury_collision
gen pdo_dui_animal                = dui_animal_collision*pdo_collision
gen dui_animal_fatalities         = dui_animal_collision*total_fatalities
gen dui_animal_injuries           = dui_animal_collision*total_injuries

gen dui_wild_animal_collision     = dui_collision*wild_animal_collision
gen fatal_dui_wild_animal         = dui_wild_animal_collision*fatal_collision
gen injury_dui_wild_animal        = dui_wild_animal_collision*injury_collision
gen pdo_dui_wild_animal           = dui_wild_animal_collision*pdo_collision
gen dui_wild_animal_fatalities    = dui_wild_animal_collision*total_fatalities
gen dui_wild_animal_injuries      = dui_wild_animal_collision*total_injuries

gen dui_non_wild_animal_collision = dui_collision*non_wild_animal_collision
gen fatal_dui_non_wild_animal     = dui_non_wild_animal_collision*fatal_collision
gen injury_dui_non_wild_animal    = dui_non_wild_animal_collision*injury_collision
gen pdo_dui_non_wild_animal       = dui_non_wild_animal_collision*pdo_collision
gen dui_non_wild_animal_fatalities = dui_non_wild_animal_collision*total_fatalities
gen dui_non_wild_animal_injuries  = dui_non_wild_animal_collision*total_injuries

di as text _newline "Animal families against impaired driving:"
tab animal_collision dui_collision

/*-----------------SECTION 4: collapse to county-year --------------*/


/* [> county name cleaning <] */

* All 102 Illinois counties appear under their standard IDOT spellings, with
* no blank and no "total" row: 102 distinct names and 102 distinct county
* codes, mapping one to one, in both 2009 and 2010. So unlike the ID file
* there is no post-collapse drop for an unplaceable crash
*
* THE CASE CHANGES BETWEEN YEARS. 2009 writes county and city names in upper
* case ("ST. CLAIR"), 2010 in mixed case with trailing padding ("St. Clair").
* Both are folded to lower case at import in section 1A, so the spellings
* below are given in the form the raw file uses and the code never sees it
*
* THE SPELLINGS THAT NEED WATCHING ON THE MERGE IN SECTION 5 are the ones IDOT
* closes up or punctuates and most crosswalks do not:
*
* 2016 ALSO CHANGES A SPELLING: "Jo Daviess" becomes "JoDaviess". No edit was
* needed, because the join key below already strips spaces from both sides.
* That is the argument for a normalised key over a per-county substitution
* list: the list would have needed a new entry and nobody would have known
* until the merge failed
*
*   IDOT           common crosswalk forms
*   DUPAGE         Du Page, DuPage
*   DEWITT         De Witt, DeWitt
*   LASALLE        La Salle, LaSalle
*   ST. CLAIR      St Clair, St. Clair, Saint Clair
*   JO DAVIESS     JoDaviess
*   MCHENRY        McHenry
*
* The ID file removed the "St." substitution it had inherited from other
* states because Idaho has no such county. IL DOES, along with five more of
* the same kind, so rather than patching each one the join in section 5 uses a
* NORMALISED KEY: lowercase, then strip spaces, periods and apostrophes from
* both sides. That collapses every pair above onto a single value and needs no
* per-county list to maintain. county_name itself is kept in its readable
* lowercase form for the output file
*
* Already lowercased and trimmed at import in section 1A, so this is
* idempotent. Kept because it is the step section 5's join depends on, and
* burying that dependency in the import block would make it easy to drop
replace county_name = lower(county_name)
replace county_name = strtrim(county_name)
replace county_name = ustrtrim(county_name)

* CANONICALISED HERE, BEFORE THE COLLAPSE, and that placement is the point.
* The collapse below groups by(county_name year), so any county carrying two
* spellings becomes two groups. 2016 respells "Jo Daviess" as "JoDaviess", so
* leaving it until section 5 would relabel the rows but not regroup them, and
* a year that happened to use BOTH spellings would produce two half-counties
* that no later check would catch.
*
* Stripping spaces, periods and apostrophes is the same transform the section
* 5 join key uses, so the two are guaranteed to agree. The names are ugly
* after it ("stclair", "jodaviess"), which does not matter: the READABLE name
* in the output comes from the crosswalk after the merge
replace county_name = subinstr(county_name, " ", "", .)
replace county_name = subinstr(county_name, ".", "", .)
replace county_name = subinstr(county_name, "'", "", .)
replace county_name = "st" + substr(county_name, 6, .) ///
    if substr(county_name, 1, 5) == "saint"

* Sanity check on the code-to-name mapping before the collapse throws the
* crash-level detail away. IDOT's county code is the alphabetical sequence
* number, so it should be one code per name and one name per code
preserve
    keep county_code county_name
    duplicates drop
    qui count
    local n_pairs = r(N)
    qui levelsof county_name, local(dummy)
    local n_names : word count `dummy'
    qui levelsof county_code, local(dummy2)
    local n_codes : word count `dummy2'
    di as text _newline "County code/name pairs: `n_pairs' (`n_names' names, `n_codes' codes)"
    * Run AFTER the canonicalisation above, so a county respelled between
    * years no longer shows up here as two names sharing one code. Before
    * that fix this reported 104 pairs against 103 codes, with code 43 (Jo
    * Daviess) used twice, which was the 2016 respelling rather than a defect.
    * One code over the 102 is still expected: 2016's "(UNK)" carries code 0
    if `n_pairs' != `n_names' | `n_pairs' != `n_codes' {
        di as error "County code and name do not map one to one."
        di as error "Pairs that share a name or a code:"
        duplicates list county_name
        duplicates list county_code
    }

    /* [> optional check against IDOT's own code list <] */

    * CountyCode.xlsx, if it is sitting in $raw, is IDOT's authoritative
    * code-to-name lookup: 102 rows, codes 1 to 102 contiguous, one name each.
    * It is NOT required and the build does not depend on it, because the
    * crosswalk join in section 5 goes through the county NAME carried in the
    * crash file. What it adds is an EXTERNAL reference: the check above only
    * establishes that code and name agree WITH EACH OTHER, so a delivery that
    * shifted both columns together would sail through it. This catches that
    *
    * Its spellings are a third convention again, spaced and unpunctuated
    * ("DE WITT", "DU PAGE", "LA SALLE", "ST CLAIR"), and 81 of the 102 names
    * carry a leading space. Both are absorbed by the same normalised key the
    * section 5 join uses, which is a useful confirmation that the key covers
    * IDOT's own canonical forms and not just the spellings the crash files
    * happen to use
    *
    * This runs on the deduplicated code/name pairs, not on crashes, so the
    * counts below are pairs. No nested preserve: the pairs are parked in a
    * tempfile because importing the workbook replaces the data in memory
    capture confirm file "$raw/CountyCode.xlsx"
    if _rc == 0 {

        gen data_name = county_name
        foreach ch in " " "." "'" {
            qui replace data_name = subinstr(data_name, "`ch'", "", .)
        }
        tempfile pairs
        `q' save `pairs', replace

        `q' import excel using "$raw/CountyCode.xlsx", firstrow clear
        qui destring county_code, replace ignore(",")
        qui replace county_name = lower(strtrim(ustrtrim(county_name)))
        foreach ch in " " "." "'" {
            qui replace county_name = subinstr(county_name, "`ch'", "", .)
        }
        rename county_name lookup_name
        keep county_code lookup_name
        isid county_code

        `q' merge 1:m county_code using `pairs', keep(2 3) nogenerate

        qui count if lookup_name != data_name & !missing(lookup_name)
        if r(N) > 0 {
            di as error "`r(N)' county code/name pair(s) disagree with IDOT's CountyCode.xlsx."
            di as error "The code and name columns may have shifted together, which the"
            di as error "one-to-one check above cannot detect. Mismatched pairs:"
            list county_code county_name lookup_name ///
                if lookup_name != data_name & !missing(lookup_name), noobs sep(0)
        }
        else {
            di as text "County codes agree with IDOT's CountyCode.xlsx on every pair."
        }

        qui count if missing(lookup_name)
        if r(N) > 0 {
            di as error "NOTE: `r(N)' county code(s) in the data are absent from CountyCode.xlsx."
            di as error "(the lookup holds 1-102; 2016 uses code 0 for its (UNK) county, which"
            di as error " is dropped as unplaceable below, so one such code is expected)"
            list county_code county_name if missing(lookup_name), noobs sep(0)
        }
    }
    else {
        di as text "CountyCode.xlsx not present in $raw; skipping the external county check."
    }
restore

* PERSON-LEVEL VARIABLES ARE DROPPED HERE, not published. The persons_*
* family was an IL-only addition: neither IA nor ID carries person-level
* injury counts, so publishing them would put eight columns in the panel that
* no other state can match. They have already done their job in section 2,
* where reconciling them against the crash-level counts is what establishes
* that the injury coding means what this file assumes
drop crash_id county_code a_injuries b_injuries c_injuries ///
     persons_killed persons_a_injury persons_b_injury persons_c_injury ///
     persons_no_injury persons_inj_unknown persons_pedestrian ///
     persons_pedalcyclist ///
     light_condition road_surface weather

collapse (sum) total_all_cause ///
               total_fatalities ///
               total_injuries ///
               total_persons ///
               major_injuries ///
               minor_injuries ///
               total_units ///
               fatal_collision ///
               injury_collision ///
               major_injury_collision ///
               minor_injury_collision ///
               possible_injury_collision ///
               injury_unclassified_collision ///
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
               dui_cause_collision ///
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
               dui_non_wild_animal_injuries, ///
               by(county_name year)

strip_collapse_labels

* UNPLACEABLE CRASHES. A crash whose county cannot be identified cannot enter
* a county-year panel, so it is dropped here. 2016 introduces a "(UNK)"
* county carrying county code 0 on ten crashes; left in, those ten would fail
* the crosswalk merge in section 5 and stop the build outright.
*
* Reported and bounded rather than dropped in silence. Eleven crashes in 4.75
* million is a rounding error; ten thousand would mean the county column had
* moved, and that must not be absorbed quietly
qui gen byte _noplace = inlist(county_name, "", "total", "(unk)", "(n/a)", "unknown")

qui count if _noplace
if r(N) > 0 {
    qui summ total_all_cause if _noplace, meanonly
    local n_unplaced = r(sum)
    qui summ total_all_cause, meanonly
    local n_allcrash = r(sum)

    di as error _newline "NOTE: dropping `n_unplaced' crash(es) with no identifiable county,"
    di as error "out of `n_allcrash' in the panel."
    di as text "Crashes dropped, by year:"
    tabstat total_all_cause if _noplace, by(year) statistics(sum) format(%12.0fc)

    if `n_unplaced' > 0.001 * `n_allcrash' {
        di as error "That is more than 0.1% of all crashes. At this scale the county"
        di as error "column has most likely moved or been recoded. Check the county"
        di as error "values above against the crosswalk before trusting the panel."
        error 459
    }
}
drop if _noplace
drop _noplace

/* [> event coverage <] */

* Share of this county-year's crashes with event information recorded. Where
* it is below 1 the animal counts are mechanically understated, because a
* crash with no event record contributes a zero to the event side of
* animal_collision. Expected to be 1 almost everywhere in IL; the machinery is
* kept because it is what turned a silent truncation into a visible one in ID
rename has_event_record crashes_with_event_rec
gen event_record_coverage = crashes_with_event_rec / total_all_cause
gen byte animal_data_usable = (event_record_coverage >= 0.99)

di as text _newline "Event coverage by year. Animal counts are usable where this is at or near 1:"
tabstat event_record_coverage, by(year) statistics(mean min max) format(%9.4f)

qui count if animal_data_usable == 0
if r(N) > 0 {
    di as error "WARNING: `r(N)' county-year cell(s) have incomplete event coverage."
    di as error "Their animal variables are set to missing below rather than left as"
    di as error "understated counts, because missing is the honest value: the count is"
    di as error "unknown, not low."
    qui levelsof year if animal_data_usable == 0, local(bad_years)
    di as error "Affected years: `bad_years'"
}

* Every animal variable derives from the event columns in part, so every one
* is blanked where coverage is short, and the exemption list is gone along with
* the variables it exempted. animal_data_usable is the flag doing the blanking
* and has to survive it. The pattern catches all three families and their dui
* crosses, since every one of those names contains "animal"
foreach v of varlist *animal* {
    if "`v'" != "animal_data_usable" {
        qui replace `v' = . if animal_data_usable == 0
    }
}

/* [> checks <] */

* Severity partitions the panel, and the injury split partitions the injury
* category. Both hold by construction in section 3, so a failure here means
* the collapse list was edited without the asserts being updated
assert fatal_collision + injury_collision + pdo_collision == total_all_cause ///
       & major_injury_collision + minor_injury_collision ///
         + injury_unclassified_collision == injury_collision ///
       & possible_injury_collision <= minor_injury_collision ///
       & major_injuries + minor_injuries == total_injuries ///
       & alcohol_collision <= dui_collision ///
       & drug_collision <= dui_collision ///
       & crashes_with_event_rec <= total_all_cause

* THE SPECIES FAMILIES ARE SUBSETS, NOT A PARTITION. An earlier version of
* this file asserted wild + non_wild == animal, which was true only because it
* built non_wild as the residual. It now carries the Other Animal event code,
* as ID carries its domestic code, so the sum is NOT expected to hold: a
* cause-only animal crash has no species, and a crash can carry both events.
* Each is bounded by the total and that is all that can be asserted
assert wild_animal_collision <= animal_collision ///
       & non_wild_animal_collision <= animal_collision ///
       & animal_first_collision <= animal_collision ///
       & wild_animal_first_collision <= wild_animal_collision ///
       & non_wild_animal_first_coll <= non_wild_animal_collision ///
       & animal_collision <= total_all_cause ///
       if animal_data_usable == 1

* Each family's severity crosses partition it, and the dui cross is bounded by
* both parents. Written out three times rather than looped: ID's naming puts a
* _collision suffix on the animal_ crosses and not on the species ones, and a
* loop carrying that difference as a macro was harder to read than the
* repetition and easier to get wrong
assert fatal_animal_collision + injury_animal_collision + pdo_animal ///
         == animal_collision ///
       & major_injury_animal_collision + minor_injury_animal_collision ///
         <= injury_animal_collision ///
       & possible_injury_animal_collision <= minor_injury_animal_collision ///
       & dui_animal_collision <= dui_collision ///
       & dui_animal_collision <= animal_collision ///
       if animal_data_usable == 1

assert fatal_wild_animal + injury_wild_animal + pdo_wild_animal ///
         == wild_animal_collision ///
       & major_injury_wild_animal + minor_injury_wild_animal ///
         <= injury_wild_animal ///
       & possible_injury_wild_animal <= minor_injury_wild_animal ///
       & dui_wild_animal_collision <= dui_collision ///
       & dui_wild_animal_collision <= wild_animal_collision ///
       if animal_data_usable == 1

assert fatal_non_wild_animal + injury_non_wild_animal + pdo_non_wild_animal ///
         == non_wild_animal_collision ///
       & major_injury_non_wild_animal + minor_injury_non_wild_animal ///
         <= injury_non_wild_animal ///
       & possible_injury_non_wild_animal <= minor_injury_non_wild_animal ///
       & dui_non_wild_animal_collision <= dui_collision ///
       & dui_non_wild_animal_collision <= non_wild_animal_collision ///
       if animal_data_usable == 1

* Where coverage is short they should be uniformly missing, not partly blanked
assert missing(animal_collision) & missing(wild_animal_collision) ///
       & missing(non_wild_animal_collision) & missing(dui_animal_collision) ///
       if animal_data_usable == 0

/*-----------------SECTION 5: merge with state_county_identifiers --------------*/

* IL reports both a county name and a county code, but the code is IDOT's own
* alphabetical sequence number rather than FIPS, so the crosswalk is joined on
* the name as in the ID file
*
* Worth knowing, and NOT used as the join: the IDOT code maps onto FIPS
* exactly, as county_fips = 2*code - 1. Verified on 2009 against all the cases
* where the alphabetical order is contestable, including St. Clair at code 82
* and FIPS 163, which sorts before Saline in FIPS order and after Shelby in a
* plain string sort. The identity holds because Illinois' 102 counties take
* the odd FIPS codes 1 to 203 in alphabetical order. It is left as a
* verification below rather than made the join, because it is an arithmetic
* coincidence of Illinois' county history and not a documented relationship,
* and a single county reassignment would break it silently
gen state_letter_code = "IL"

* The normalised join key described in section 4: lowercase, then strip
* spaces, periods and apostrophes. Applied to BOTH sides so neither has to
* store names the other's way. This is what makes dupage/du page,
* dewitt/de witt, lasalle/la salle, st. clair/st clair/saint clair and
* jo daviess/jodaviess all match without a per-county substitution list
gen county_join = county_name
replace county_join = subinstr(county_join, " ", "", .)
replace county_join = subinstr(county_join, ".", "", .)
replace county_join = subinstr(county_join, "'", "", .)

* "saint" is spelled out by some crosswalks and abbreviated by others, so it
* is folded to the abbreviation. Anchored with a length test so a county whose
* name merely contains the letters is untouched
replace county_join = "st" + substr(county_join, 6, .) ///
    if substr(county_join, 1, 5) == "saint"

preserve
    use "$xwalk", clear
    keep if state_letter_code == "IL"

    replace county_name = lower(county_name)
    replace county_name = strtrim(county_name)
    replace county_name = ustrtrim(county_name)

    gen county_join = county_name
    replace county_join = subinstr(county_join, " ", "", .)
    replace county_join = subinstr(county_join, ".", "", .)
    replace county_join = subinstr(county_join, "'", "", .)
    replace county_join = "st" + substr(county_join, 6, .) ///
        if substr(county_join, 1, 5) == "saint"

    * THE CROSSWALK'S NAME IS KEPT AND BECOMES THE OUTPUT NAME. An earlier
    * version dropped it "in favour of the crash file's, so the output
    * county_name is the one the raw data uses". That was the wrong call, and
    * the first complete run showed why: the crash file's spelling is not
    * stable across years, so the panel came out carrying TWO names for one
    * county.
    *
    * 2016 respelled "Jo Daviess" as "JoDaviess" (drift log, section 0C). The
    * normalised join key strips spaces, so both merge to FIPS 17085 perfectly
    * well and the merge reported zero unmatched. But the collapse is
    * by(county_name year), so the output held "jo daviess" for 2009-2015 and
    * "jodaviess" for 2016-2024: 103 county names across a 102-county state,
    * and anyone using county_name as the panel identifier would see the county
    * split in two.
    *
    * That is also what the code/name pair check reports upstream as 104 pairs
    * against 103 codes, with code 43 used twice. Code 43 is Jo Daviess.
    *
    * The crosswalk has exactly one row per county, so taking its name gives
    * one spelling for the whole panel by construction. The crash file's
    * spelling is still what the JOIN is built from; it is just not what gets
    * published
    rename county_name county_name_xw

    isid state_letter_code county_join
    tempfile xwalk_il
    `q' save `xwalk_il', replace
restore

`q' merge m:1 state_letter_code county_join using `xwalk_il', keep(1 3)

* ADOPT THE CROSSWALK'S READABLE NAME. county_name arrives here in the
* canonical key form built in section 4 ("stclair", "jodaviess"), which is
* what the join is on and is not what should be published. Most counties
* therefore differ from the crosswalk spelling by punctuation alone, so this
* is a count rather than a listing
qui count if _merge == 3 & county_name != county_name_xw
di as text _newline "County names taken from the crosswalk: " ///
    %4.0f r(N) " of " %4.0f _N " county-years differ from the canonical" _newline ///
    "  join key by punctuation and are relabelled (st. clair, jo daviess, and so on)"

qui replace county_name = county_name_xw if _merge == 3
drop county_name_xw

* Naming the unmatched counties before asserting, because "assert _merge == 3"
* on its own says that a name failed to match but not which one. All 102
* Illinois counties are present in the raw data under standard IDOT spellings,
* so a clean crosswalk should leave nothing here
count if _merge == 1
if r(N) > 0 {
    levelsof county_name if _merge == 1, local(unmatched_counties)
    di as error `"County names not matched to the crosswalk: `unmatched_counties'"'
    di as error "Normalised keys that failed:"
    levelsof county_join if _merge == 1, local(unmatched_keys)
    di as error `"  `unmatched_keys'"'

    * Print what the crosswalk holds alongside what failed, so a broken join
    * shows whether the cause is a spelling difference the normalisation does
    * not cover or a missing row
    preserve
        use `xwalk_il', clear
        levelsof county_join, local(xwalk_names)
        di as error `"Crosswalk holds for IL: `xwalk_names'"'
    restore
}
assert _merge == 3
drop _merge county_join

* The FIPS identity described above, checked rather than relied on. Reported
* and not asserted: if it ever fails, the name-based join is still the join
* that built this file and the panel is still correct
* THE CROSSWALK STORES county_fips AS A STRING, at least in this copy, so
* mod() on it raised "type mismatch", r(109). Handled rather than assumed
* either way, because the crosswalk is shared with the AZ and ID files and
* nothing here should depend on how it happens to be typed today
capture confirm variable county_fips
if _rc == 0 {
    tempvar fipsnum
    capture confirm numeric variable county_fips
    if _rc == 0 {
        qui gen double `fipsnum' = county_fips
    }
    else {
        qui gen double `fipsnum' = real(county_fips)
        qui count if missing(`fipsnum')
        if r(N) > 0 {
            di as error "WARNING: county_fips is a string and `r(N)' value(s) are not"
            di as error "numeric, so the FIPS identity below cannot be checked on them."
        }
    }

    qui count
    local n_all = r(N)
    qui count if mod(`fipsnum', 2) == 1 & `fipsnum' >= 1 & `fipsnum' <= 203
    if r(N) != `n_all' {
        di as error "WARNING: `=`n_all'-r(N)' county-years carry a county_fips outside"
        di as error "the odd numbers 1-203 that Illinois uses. Worth a look, though the"
        di as error "join above was on the name and does not depend on this."
    }

    * DROPPED EXPLICITLY, and this is not tidiness. A tempvar is cleared when
    * the DO-FILE ends, but the save in section 6 happens before that, so
    * leaving it here puts a variable called __000000 inside the delivered
    * .dta. The first successful run did exactly that: compress reported
    * "variable __000000 was double now int" just before saving
    drop `fipsnum'
}

tab year


/*-----------------SECTION 6: order, sort, save --------------*/

* ORDERED EXPLICITLY, in the ID file's layout so the two panels append with
* the columns in the same places. Wildcards are avoided: animal* would sweep
* up animal_data_usable and the dui_animal block in whatever order Stata
* happens to hold them
order state_letter_code                ///
      state_name                       ///
      county_name                      ///
      state_fips                       ///
      county_fips                      ///
      fips                             ///
      year                             ///
      animal_data_usable               ///
      crashes_with_event_rec           ///
      event_record_coverage            ///
      total_all_cause                  ///
      total_fatalities                 ///
      total_injuries                   ///
      total_persons                    ///
      major_injuries                   ///
      minor_injuries                   ///
      total_units                      ///
      fatal_collision                  ///
      injury_collision                 ///
      major_injury_collision           ///
      minor_injury_collision           ///
      possible_injury_collision        ///
      injury_unclassified_collision    ///
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
      dui_cause_collision              ///
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

* The collapse artefacts were already stripped at each collapse, so anything
* not named below carries no label, which reads better in the browser than
* "(sum) fatal_dui_wild_animal". Labelled where the name alone is not enough
label var year                          "Crash year"
label var crashes_with_event_rec        "Crashes with an event record"
label var event_record_coverage         "Share of crashes with an event record"
label var animal_data_usable            "1 = coverage at or above 0.99, animal families usable"
label var total_all_cause               "All-cause collisions"
label var total_persons                 "Persons involved, counted from PersonExtract rows"
label var major_injuries                "A injuries, which IA calls serious"
label var minor_injuries                "B + C injuries, as IA pools minor and possible"
label var possible_injury_collision     "C injuries, a SUBSET of minor_injury_collision"
label var injury_unclassified_collision "Typed Injury but no A/B/C recorded: 54 crashes"
label var animal_collision              "Animal collisions, event or circumstance"
label var wild_animal_collision         "Animal collisions, Deer event code"
label var non_wild_animal_collision     "Animal collisions, Other Animal event code"
label var alcohol_collision             "Alcohol impaired, the AZ-comparable series"
label var dui_collision                 "Alcohol or drug impaired, the IL superset"
label var dui_cause_collision           "Impairment from the cause columns, alcohol and drugs combined"
label var dui_animal_collision          "Animal collisions with an impaired driver"

sort fips year

* The panel should be 102 counties by every year in it, with no county-year
* silently absent because a county recorded no crashes in some year. Reported
* rather than asserted, because a genuinely crash-free county-year is possible
* in the small southern counties and is a substantive zero, not an error
*
* 102 is the count of REAL Illinois counties. 2016 carries a 103rd value,
* "(UNK)", which is a sentinel rather than a place and is dropped above, so
* this check still expects 102 in every year
qui levelsof year, local(all_years)
foreach y of local all_years {
    qui count if year == `y'
    if r(N) != 102 {
        di as error "Year `y' has `r(N)' county rows, not 102."
    }
}

qui summ year
local T1 = `r(min)'
local T2 = `r(max)'
* qui, because the type-change list runs to 90 lines and says nothing a
* reader of this log needs
qui compress
`q' save "$working_data/dvcs_IL_county_year_`T1'_`T2'.dta", replace

di as text _newline "Saved: $working_data/dvcs_IL_county_year_`T1'_`T2'.dta"
di as text "Log:   $working_data/dvcs_IL_build.log"

cap log close
