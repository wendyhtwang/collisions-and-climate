/*==============================================================
FILE:         MS.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang

PURPOSE:      Builds the Mississippi county-year collision panel from MS crash records and saves it as $working_data/dvcs_MS_county_year_<t1>_<t2>.dta.

SOURCES:
  2004 to 2 Sep 2019   ReportBeam crash tables, dataRAW/DVCs/MS/ReportBeam-<YYYY>-CrashData
  3 Sep 2019 to 2024   eCrash public data requests, dataRAW/DVCs/MS (2023-24 marked DRAFT)
  2005-2016            county deer tables, dataCSV/DVCs/MS (the only deer source)
  Settled 11/02/26: DRAFT years are used if they cover all 12 months (checked in
  Section 4); 2024 is the last year of the panel.

KNOWN BREAKS (data_source marks each row's era):
  - The crash tables read here carry no deer code, so deer is 2005-2016 only;
    animal_collision covers every year.
  - Alcohol share is about 1.4 pp higher in eCrash (crash-level flag) than in
    ReportBeam (built from person records).
  - From 3 Sep 2019 eCrash also records "Animal(s)" as a roadway contributing
    circumstance; the ReportBeam extract has no such field. Animal crashes rise
    25% (shared field) or 42% (with it) from 2018 to 2020.

CHANGELOG:
  07/01/2020 [Siyue Ouyang]: created
  07/08/2020 [Siyue Ouyang]: code style change
  07/13/2020 [Siyue Ouyang]: add more states
  07/15/2020 [Siyue Ouyang]: make every single state data ready-to-use, add more states
  07/26/2020 [Siyue Ouyang]: add data in ~dataRAW, update
  11/08/2020 [Owen Shao]: add TVC from dataCSV, update
  11/02/2026 [Wendy Wang]: rebuilt from crash-level records (2004-2024) to the
    Code Style Guide, with AZ.do/IA.do variable names; county tables kept for
    deer. DRAFT, not yet run.
  11/09/2026 [Wendy Wang]: use the 2023-24 DRAFT files; check that every year
    covers all 12 months; read eCrash text dates; drop crash IDs before stacking.
  11/16/2026 [Wendy Wang]: drop ReportBeam rows with non-numeric crash IDs (run
    stopped in 2006); read text dates in the crash table; sources in source.txt;
    no variable type declarations (compress sets types).
  11/16/2026 [Wendy Wang]: read crash dates written as text (2012, 2015-2018);
    stop in Section 1 if a year's dates can't be read.
  11/21/2026 [Wendy Wang]: count eCrash's "Animal(s)" roadway contributing
    circumstance as animal-related (decided 11/16/26); settle the alcohol rule
    and the post-switch ReportBeam drop; flag 2004 as possibly incomplete.
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

* confirmdir is user-written (SSC); install it if missing
cap which confirmdir
if _rc != 0 {
    cap noi ssc install confirmdir
    cap which confirmdir
    if _rc != 0 {
        di as err "confirmdir is not installed and SSC is unreachable."
        error 111
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

if "`rootDir'" == "" {
    di as err "No known Dropbox root found; add this machine's root above."
    error 601
}

* Set unconditionally: _project_main.do sets $path to AnimalCollisionsWeather
global path "`rootDir'/VehicleCollisionsDataRepo"
global working_data "$path/dataSTATA"
global ms_raw "$path/dataRAW/DVCs/MS"
global ms_csv "$path/dataCSV/DVCs/MS"
global ms_switch = td(03sep2019) // first eCrash day
di as txt "Using path: $path"

cap mkdir "$path/logs"
log using "$path/logs/clean_MS.log", replace text

set excelxlsxlargefile on

* Some ReportBeam tables hold broken rows (the 2006 vehicle table has crash ID
* "PRO") that make the ID column text; drop them so every table keys on a number
cap program drop drop_bad_ids
program define drop_bad_ids
    destring intcrashid, replace force
    count if missing(intcrashid)
    di as txt r(N) " rows with a non-numeric crash ID dropped"
    drop if missing(intcrashid)
end

*---------------------------------------------------------------
* SECTION 1: REPORTBEAM CRASH RECORDS (2004 TO 2 SEP 2019)
*---------------------------------------------------------------
* Source: Mississippi ReportBeam crash export, one folder of five tables per year
* (site and download date in dataRAW/DVCs/MS/source.txt)
* Each pass joins one year's tables on intcrashid and saves one row per crash:
* county, worst injury (KABCO), animal and alcohol flags.
* Code values (14 = Animal; conditions 4, 5, 7) are listed in
* dataRAW/DVCs/MS/ReportBeamCodeValueTable.txt.
* Column names checked across 2004-2019 (not every table in every year).

tempfile rb_all    ///
         vehicles  ///
         occupants ///
         persons
local is_first = 1
* DECISION (pending): 2004 has 60,513 crashes against about 77,800 in 2005-06,
* though all 12 months are present; kept for now
forvalues file_year = 2004/2019 {
    local folder = "$ms_raw/ReportBeam-`file_year'-CrashData/ReportBeam-`file_year'"
    di as txt _n "ReportBeam `file_year'"

    * Animal: any vehicle with sequence-of-events code 14 (Animal)
    local file_name = "`folder'-CrashVehicleTable.xlsx"
    import excel using "`file_name'", firstrow case(lower) clear
    keep intcrashid v20_*
    drop_bad_ids
    gen is_animal = 0
    foreach v of varlist v20_* {
        cap destring `v', replace force
        replace is_animal = 1 if `v' == 14
    }
    collapse (max) is_animal, ///
             by(intcrashid)
    save `vehicles', replace

    * Passengers: injury severity only
    local file_name = "`folder'-CrashOccupantTable.xlsx"
    import excel using "`file_name'", firstrow case(lower) allstring clear
    keep intcrashid ///
         o13_injury_severity_cd
    rename o13_injury_severity_cd injury_severity
    drop_bad_ids
    save `occupants', replace

    * Drivers and non-motorists: injury severity and alcohol
    local file_name = "`folder'-CrashPersonTable.xlsx"
    import excel using "`file_name'", firstrow case(lower) allstring clear
    keep intcrashid             ///
         p23_injury_severity_cd ///
         p19_condition_cd       ///
         p32_alcohol_result
    rename p23_injury_severity_cd injury_severity
    drop_bad_ids
    destring p19_condition_cd, ///
             replace force
    gen bac = real(p32_alcohol_result)
    * Settled 11/21/26: any person with condition 4, 5 or 7 (drinking, impaired,
    * intoxicated) or BAC > 0, i.e. alcohol-involved, as eCrash's flag is
    gen is_alcohol = inlist(p19_condition_cd, 4, 5, 7) | (bac > 0 & !missing(bac))
    append using `occupants'
    replace is_alcohol = 0 if missing(is_alcohol)
    * KABCO rank: 5 = K, 4 = A, 3 = B, 2 = C, 1 = D (none), 0 = blank
    replace injury_severity = strtrim(upper(injury_severity))
    gen sev_rank = 5*(injury_severity == "K") ///
                      + 4*(injury_severity == "A") ///
                      + 3*(injury_severity == "B") ///
                      + 2*(injury_severity == "C") ///
                      + 1*(injury_severity == "D")
    collapse (max) sev_rank    ///
                   is_alcohol, ///
             by(intcrashid)
    save `persons', replace

    * Crashes: one row per crash
    local file_name = "`folder'-CrashTable.xlsx"
    import excel using "`file_name'", firstrow case(lower) clear
    keep intcrashid       ///
         g1_county_nmbr   ///
         g3_reported_date ///
         g7_fatal_cnt     ///
         g8_injury_cnt
    drop_bad_ids
    destring g1_county_nmbr ///
             g7_fatal_cnt   ///
             g8_injury_cnt, ///
             replace force
    * A date-time in 2018. A split row makes the column text (2012, 2015-2018),
    * and Stata then writes each date as text; read the date from its first word
    cap confirm string variable g3_reported_date
    if _rc == 0 {
        gen temp = word(strtrim(g3_reported_date), 1)
        gen crash_date = date(temp, "MDY")
        replace crash_date = date(temp, "DMY") if missing(crash_date)
        replace crash_date = date(temp, "YMD") if missing(crash_date)
        replace crash_date = floor(real(temp)) + td(30dec1899) if missing(crash_date)
        drop temp
    }
    else {
        local date_format : format g3_reported_date
        if substr("`date_format'", 1, 3) == "%tc" gen crash_date = dofc(g3_reported_date)
        else gen crash_date = g3_reported_date
    }
    format crash_date %td
    count if missing(crash_date)
    di as txt r(N) " crashes with no date (kept in `file_year')"
    count if year(crash_date) != `file_year'
    di as txt r(N) " crashes dated outside `file_year' (kept in `file_year')"
    * Stop here, not in Section 4, if the dates were not read
    if r(N) > 0.01 * _N {
        list g3_reported_date in 1/5
        error 459
    }

    * eCrash covers 2019 from the switch date, so later ReportBeam records are dropped
    * Settled 11/21/26: drop all; 52 are in eCrash, the rest are about 1.6% of 2019
    if `file_year' == 2019 {
        count if crash_date >= $ms_switch & !missing(crash_date)
        di as txt "Dropping " r(N) " ReportBeam crashes on or after the eCrash switch"
        drop if crash_date >= $ms_switch & !missing(crash_date)
    }

    * Vehicle and person rows of dropped crashes have no match and are discarded
    merge 1:1 intcrashid using `vehicles'
    drop if _merge == 2
    drop _merge
    merge 1:1 intcrashid using `persons'
    drop if _merge == 2
    drop _merge

    * Crashes with no vehicle or person rows: no animal, no alcohol, unknown severity
    foreach v in is_animal is_alcohol sev_rank {
        replace `v' = 0 if missing(`v')
    }

    rename g1_county_nmbr county_nmbr
    rename g7_fatal_cnt total_fatalities
    rename g8_injury_cnt total_injuries
    gen year = `file_year'
    * Crash IDs are numeric here and text in eCrash, so they are not kept
    keep county_nmbr      ///
         year             ///
         crash_date       ///
         total_fatalities ///
         total_injuries   ///
         sev_rank         ///
         is_animal        ///
         is_alcohol

    if !`is_first' append using `rb_all'
    save `rb_all', replace
    local is_first = 0
}

*---------------------------------------------------------------
* SECTION 2: ECRASH CRASH RECORDS (3 SEP 2019 TO 2024)
*---------------------------------------------------------------
* Source: Mississippi eCrash public data requests; request date is in each file name
* (site and download date in dataRAW/DVCs/MS/source.txt)
* Each pass reads one workbook (sheets Crashes, Vehicles, Drivers, Passengers,
* Non-Motorists), joins on crashid and saves one row per crash.
* All six files read cleanly in the 11/16/26 run.

local ec_2019 "Public Data Request 21-02-04 1755 (19-01-01 to 19-12-31).xlsx"
local ec_2020 "Public Data Request 21-01-15 1700 (20-01-01 to 21-01-01).xlsx"
local ec_2021 "Public Data Request 22-04-12 1535 (21-01-01 to 21-12-31).xlsx"
local ec_2022 "Public Data Request 24-01-12 1055 (22-01-01 to 22-12-31).xlsx"
* 2023-24 files are marked DRAFT; Section 4 checks they cover all 12 months
local ec_2023 "Public Data Request 25-02-27 1725 (23-01-01 to 23-12-31) DRAFT.xlsx"
local ec_2024 "Public Data Request 25-02-27 1733 (24-01-01 to 24-12-31) DRAFT.xlsx"

tempfile ec_all
local is_first = 1
forvalues file_year = 2019/2024 {
    local file_name = "$ms_raw/`ec_`file_year''"
    di as txt _n "eCrash `file_year'"

    * Animal: any vehicle whose sequence of events is "Collision with animal (live)"
    import excel using "`file_name'", sheet("Vehicles") firstrow case(lower) allstring clear
    keep crashid sequenceofevents*
    gen is_animal = 0
    foreach v of varlist sequenceofevents* {
        replace is_animal = 1 if strpos(lower(`v'), "collision with animal") > 0
    }
    collapse (max) is_animal, ///
             by(crashid)
    save `vehicles', replace

    * Severity: worst injury status across drivers, passengers and non-motorists
    local is_first_sheet = 1
    foreach sheet_name in "Drivers" "Passengers" "Non-Motorists" {
        import excel using "`file_name'", sheet("`sheet_name'") firstrow case(lower) allstring clear
        keep crashid ///
             injurystatus
        if !`is_first_sheet' append using `persons'
        save `persons', replace
        local is_first_sheet = 0
    }
    * Injury status reads e.g. "(K) Fatal Injury"; character 2 is the KABCO letter
    gen temp = substr(injurystatus, 2, 1)
    gen sev_rank = 5*(temp == "K") ///
                      + 4*(temp == "A") ///
                      + 3*(temp == "B") ///
                      + 2*(temp == "C") ///
                      + 1*(temp == "O")
    drop temp
    collapse (max) sev_rank, ///
             by(crashid)
    save `persons', replace

    * Crashes: one row per crash
    import excel using "`file_name'", sheet("Crashes") firstrow case(lower) clear
    * This header is too long for a Stata name, so find it by its label
    ds, has(varlabel "Roadway Environmental Contributing Circumstances")
    local road_var "`r(varlist)'"
    assert wordcount("`road_var'") == 1
    rename `road_var' road_contrib
    keep crashid            ///
         crashdate          ///
         countyid           ///
         fatalitycount      ///
         injurycount        ///
         alcoholinvolvement ///
         road_contrib
    * Crash Date is text ("2024/01/01") in the 2024 file; handle an Excel date too
    cap confirm string variable crashdate
    if _rc == 0 gen crash_date = date(crashdate, "YMD")
    else gen crash_date = crashdate
    format crash_date %td
    * Undated crashes are dropped below; stop if the date format was not read
    count if missing(crash_date)
    di as txt r(N) " crashes with no readable date"
    assert r(N) < 0.01 * _N
    * 2019 starts at the switch date; the 2020 file runs to 1 Jan 2021
    if `file_year' == 2019 keep if crash_date >= $ms_switch & year(crash_date) == 2019
    else keep if year(crash_date) == `file_year'
    gen is_alcohol = strtrim(lower(alcoholinvolvement)) == "yes"

    merge 1:1 crashid using `vehicles'
    drop if _merge == 2
    drop _merge
    merge 1:1 crashid using `persons'
    drop if _merge == 2
    drop _merge

    * Crashes with no vehicle or person rows: no animal, unknown severity
    foreach v in is_animal sev_rank {
        replace `v' = 0 if missing(`v')
    }
    * An animal on the road also counts when it contributed without being hit
    * (e.g. "Animal(s); Weather conditions"); the ReportBeam extract has no such field
    replace is_animal = 1 if strpos(lower(road_contrib), "animal") > 0

    rename countyid county_nmbr
    rename fatalitycount total_fatalities
    rename injurycount total_injuries
    gen year = `file_year'
    keep county_nmbr      ///
         year             ///
         crash_date       ///
         total_fatalities ///
         total_injuries   ///
         sev_rank         ///
         is_animal        ///
         is_alcohol

    if !`is_first' append using `ec_all'
    save `ec_all', replace
    local is_first = 0
}

*---------------------------------------------------------------
* SECTION 3: COUNTY TABLES (2005-2016)
*---------------------------------------------------------------
* Source: county deer and all-cause tables from MS Public Safety (originals in
* dataRAW/DVCs/MS/ARCHIVE; sender in source.txt).
* Deer tables: row 1 = year (first column of each year only), row 2 = severity
* (K fatal, I injury, O PDO). Blank cells are true zeros. All-cause tables are
* kept only to check the crash-level totals in Section 4.

tempfile deer ///
         all_cause
local file_name = "$ms_csv/MS.DVC.2005-2016.CountySeverity.xlsx"
local is_first = 1
* Each pass reads one sheet; the second word is the sheet's last cell
foreach sheet_range in "2005-2009 N86" "2010-2013 K87" "2014-2016 J87" {
    gettoken sheet_name last_cell : sheet_range
    local last_cell = strtrim("`last_cell'")
    local last_col = substr("`last_cell'", 1, 1)
    import excel using "`file_name'", sheet("`sheet_name'") cellrange(A1:`last_cell') allstring clear
    rename A county_name

    * Name each column deer_<severity>_<year>, carrying the year across blank cells
    local table_year = ""
    foreach v of varlist B-`last_col' {
        if strtrim(`v'[1]) != "" local table_year = strtrim(`v'[1])
        local severity = strtrim(`v'[2])
        rename `v' deer_`severity'_`table_year'
    }
    drop in 1/2
    replace county_name = lower(strtrim(subinstr(county_name, " County", "", .)))
    drop if inlist(county_name, "non-officer", "invalid code", "total")

    reshape long deer_I_   ///
                 deer_K_   ///
                 deer_O_,  ///
            i(county_name) ///
            j(year)
    if !`is_first' append using `deer'
    save `deer', replace
    local is_first = 0
}
destring deer_I_  ///
         deer_K_  ///
         deer_O_, ///
         replace
foreach v in deer_I_ deer_K_ deer_O_ {
    replace `v' = 0 if missing(`v')
}
rename deer_K_ deer_fatal_collision
rename deer_I_ deer_injury_collision
rename deer_O_ deer_pdo_collision
gen deer_total = deer_fatal_collision  ///
               + deer_injury_collision ///
               + deer_pdo_collision
save `deer', replace

local file_name = "$ms_csv/MS.TVC.2005-2016.County.xlsx"
local is_first = 1
* Each pass reads one sheet; the second word is the sheet's last cell
foreach sheet_range in "2005-2009 F85" "2010-2016 H86" {
    gettoken sheet_name last_cell : sheet_range
    local last_cell = strtrim("`last_cell'")
    local last_col = substr("`last_cell'", 1, 1)
    import excel using "`file_name'", sheet("`sheet_name'") cellrange(A1:`last_cell') allstring clear
    rename A county_name
    foreach v of varlist B-`last_col' {
        local table_year = strtrim(`v'[1])
        rename `v' table_total_`table_year'
    }
    drop in 1
    replace county_name = lower(strtrim(subinstr(county_name, " County", "", .)))
    drop if inlist(county_name, "non-officer", "invalid code", "total")

    reshape long table_total_, ///
            i(county_name)     ///
            j(year)
    if !`is_first' append using `all_cause'
    save `all_cause', replace
    local is_first = 0
}
destring table_total_, replace
rename table_total_ table_total

merge 1:1 county_name year using `deer'
assert _merge == 3
drop _merge

gen state_letter_code = "MS"
local file_name = "$path/dataSTATA/state_county_identifiers.dta"
merge m:1 state_letter_code county_name using "`file_name'", keepusing(fips)
* The identifiers file covers every state; other states' rows are discarded
drop if _merge == 2
assert _merge == 3
drop _merge

keep fips                  ///
     year                  ///
     table_total           ///
     deer_fatal_collision  ///
     deer_injury_collision ///
     deer_pdo_collision    ///
     deer_total
isid fips year
save `deer', replace

*---------------------------------------------------------------
* SECTION 4: STACK ERAS AND COLLAPSE TO COUNTY-YEAR
*---------------------------------------------------------------

use `rb_all', clear
append using `ec_all'

* A year is used only if its crash records cover all 12 months
gen temp = month(crash_date) if year(crash_date) == year
egen temp_tag = tag(year temp)
bysort year: egen temp_months = total(temp_tag)
tab year if temp_months < 12
assert temp_months == 12
drop temp      ///
     temp_tag  ///
     temp_months

* Both formats number counties 1-82 alphabetically, so county FIPS = 2n - 1
count if !inrange(county_nmbr, 1, 82)
di as txt r(N) " crashes without a valid county dropped"
drop if !inrange(county_nmbr, 1, 82)
gen fips = "28" + string(2*county_nmbr - 1, "%03.0f")

* Crash severity = worst injury of any person (KABCO); 0 = no person record
gen total_all_cause            = 1
gen fatal_collision            = sev_rank == 5
gen major_injury_collision     = sev_rank == 4
gen minor_injury_collision     = inlist(sev_rank, 2, 3)
gen injury_collision           = inlist(sev_rank, 2, 3, 4)
gen pdo_collision              = sev_rank == 1
gen unknown_severity_collision = sev_rank == 0

count if fatal_collision != (total_fatalities > 0 & !missing(total_fatalities))
di as txt r(N) " crashes where person severity and the fatality count disagree"

* Each pass builds one cause's severity split. cond() keeps non-cause
* crashes at 0 even when their injury or fatality count is missing.
foreach cause in animal alcohol {
    gen `cause'_collision              = is_`cause'
    gen fatal_`cause'_collision        = is_`cause' * fatal_collision
    gen injury_`cause'_collision       = is_`cause' * injury_collision
    gen major_injury_`cause'_collision = is_`cause' * major_injury_collision
    gen minor_injury_`cause'_collision = is_`cause' * minor_injury_collision
    gen pdo_`cause'                    = is_`cause' * pdo_collision
    gen `cause'_fatalities = cond(is_`cause' == 1, total_fatalities, 0)
    gen `cause'_injuries   = cond(is_`cause' == 1, total_injuries, 0)
}

collapse (sum) total_all_cause                ///
               fatal_collision                ///
               major_injury_collision         ///
               minor_injury_collision         ///
               injury_collision               ///
               pdo_collision                  ///
               unknown_severity_collision     ///
               total_fatalities               ///
               total_injuries                 ///
               animal_collision               ///
               fatal_animal_collision         ///
               injury_animal_collision        ///
               major_injury_animal_collision  ///
               minor_injury_animal_collision  ///
               pdo_animal                     ///
               animal_fatalities              ///
               animal_injuries                ///
               alcohol_collision              ///
               fatal_alcohol_collision        ///
               injury_alcohol_collision       ///
               major_injury_alcohol_collision ///
               minor_injury_alcohol_collision ///
               pdo_alcohol                    ///
               alcohol_fatalities             ///
               alcohol_injuries,              ///
               by(fips                        ///
                  year)

* County-years with no crash records are true zeros
fillin fips year
foreach v of varlist total_all_cause-alcohol_injuries {
    replace `v' = 0 if _fillin == 1
}
drop _fillin

gen data_source = cond(year < 2019, "ReportBeam", ///
                        cond(year == 2019, "ReportBeam + eCrash", "eCrash"))

* Deer and the county-table totals cover 2005-2016 only
merge 1:1 fips year using `deer'
assert _merge != 2
drop _merge

gen pct_gap_vs_table = 100 * (total_all_cause - table_total) / table_total
di as txt _n "Crash-level total vs county table, % gap by year (2005-2016)"
tabstat pct_gap_vs_table,        ///
        by(year)                 ///
        statistics(mean min max) ///
        format(%6.1f)
drop table_total ///
     pct_gap_vs_table

*---------------------------------------------------------------
* SECTION 5: MERGE COUNTY IDENTIFIERS
*---------------------------------------------------------------

local file_name = "$path/dataSTATA/state_county_identifiers.dta"
merge m:1 fips using "`file_name'"
* The identifiers file covers every state; other states' rows are discarded
drop if _merge == 2
assert _merge == 3
drop _merge

*---------------------------------------------------------------
* SECTION 6: CHECKS AND SAVE
*---------------------------------------------------------------

isid fips year
qui tab year
assert r(r) == 21 // every year 2004-2024 present
bysort year: gen n_counties = _N
assert n_counties == 82
drop n_counties

assert fatal_collision  ///
     + injury_collision ///
     + pdo_collision    ///
     + unknown_severity_collision == total_all_cause
assert major_injury_collision + minor_injury_collision == injury_collision
assert animal_collision <= total_all_cause
assert alcohol_collision <= total_all_cause
foreach v of varlist total_all_cause-alcohol_injuries {
    assert `v' >= 0 if !missing(`v')
}
* Deer comes from a different source than animal, so report rather than assert
count if deer_total > animal_collision & !missing(deer_total)
di as txt r(N) " county-years with deer_total > animal_collision"

label var total_all_cause            "All-cause collisions"
label var unknown_severity_collision "Collisions with no person injury record"
label var animal_collision           "Animal-related collisions"
label var alcohol_collision          "Alcohol-related collisions (rule differs by data_source)"
label var deer_total                 "Deer collisions (county tables, 2005-2016 only)"
label var data_source                "Crash-record format behind the row"

* TODO: the 2020 append script expects the old names (total_total, animal_total,
* deer_fatal); update it or rename here
order state_letter_code              ///
      state_name                     ///
      county_name                    ///
      state_fips                     ///
      county_fips                    ///
      fips                           ///
      year                           ///
      data_source                    ///
      total_all_cause                ///
      fatal_collision                ///
      major_injury_collision         ///
      minor_injury_collision         ///
      injury_collision               ///
      pdo_collision                  ///
      unknown_severity_collision     ///
      total_fatalities               ///
      total_injuries                 ///
      animal_collision               ///
      fatal_animal_collision         ///
      injury_animal_collision        ///
      major_injury_animal_collision  ///
      minor_injury_animal_collision  ///
      pdo_animal                     ///
      animal_fatalities              ///
      animal_injuries                ///
      deer_fatal_collision           ///
      deer_injury_collision          ///
      deer_pdo_collision             ///
      deer_total                     ///
      alcohol_collision              ///
      fatal_alcohol_collision        ///
      injury_alcohol_collision       ///
      major_injury_alcohol_collision ///
      minor_injury_alcohol_collision ///
      pdo_alcohol                    ///
      alcohol_fatalities             ///
      alcohol_injuries

* Statewide shares by year, for spotting breaks between eras
preserve
    collapse (sum) total_all_cause    ///
                   animal_collision   ///
                   alcohol_collision, ///
                   by(year            ///
                      data_source)
    gen share_animal  = 100 * animal_collision  / total_all_cause
    gen share_alcohol = 100 * alcohol_collision / total_all_cause
    list year            ///
         data_source     ///
         total_all_cause ///
         share_animal    ///
         share_alcohol,  ///
         sep(0)          ///
         noobs
restore

qui summ year
local t1 = r(min)
local t2 = r(max)

* Final save
sort fips year // to keep saved files in a predictable order
compress
local file_name = "$working_data/dvcs_MS_county_year_`t1'_`t2'.dta"
save "`file_name'", replace

* Wrap up
log close
