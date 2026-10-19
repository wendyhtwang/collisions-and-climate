/*==============================================================================

FILE NAME:   MO_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  Missouri (MO) county-level deer HARVEST and POPULATION
          harmonization, adapted from the VA/WI/OH/NC pilot scripts.

          MO's harvest data arrives split across two files with DRIFTED
          SCHEMAS (different column order, different category coverage,
          different Total-variable naming) that have to be reconciled
          before appending -- this is the main structural wrinkle, unlike
          OH which was a single clean long-format import. Population
          arrives separately, county-name-only (no FIPS), same pattern as
          OH/WI/NC.

SOURCE FILES USED:
  PROVENANCE [open]: "Lombardo" is a surname only -- presumed MO
    Department of Conservation, affiliation not confirmed.
    
  MO.Harvest.2002-2011.CountySex.Lombardo.xlsx  -- county harvest by
                                                    sex/age x weapon
                                                    (firearm/archery),
                                                    2002-2011. Includes an
                                                    Unknown-sex category.
						    
  MO.Harvest.2012-2014.CountySex.Lombardo.xlsx  -- same concept, 2012-2014,
                                                    but column order is
                                                    archery-then-firearm
                                                    (file 1 is firearm-
                                                    then-archery), Total
                                                    vars are named
                                                    TotalA/TotalF (file 1:
                                                    TOTALF/TOTALA), and the
                                                    Unknown-sex category is
                                                    structurally absent
                                                    (not just unpopulated).
						    
  Deer_Population/MO.Pop.02-15.County.Lombardo.xlsx
                                                 -- county-year population
                                                    index, two flavors
                                                    (pre-season, next-
                                                    season), 2002-2014.
                                                    Filename says "02-15":
                                                    the sheet's years run
                                                    2002-2014, and the 2014
                                                    next-season value is
                                                    the 2015 pre-season
                                                    estimate (next-season
                                                    in year t == pre-season
                                                    in t+1 everywhere; see
                                                    Section 3).

CHANGELOG:

08/10/2026 — Nicole: First pass adapting VA/WI/OH/NC pilot logic to
                     MO. Both harvest files harmonized to a common column
                     vocabulary and appended; population merged in by
                     name. See inline notes for the UNKNOWN county placeholder 
		     rows, the 2011 Worth County gap, the Sainte Genevieve 2005 
		     arithmetic mismatch, and the FIPS crosswalk sourcing.

09/15/2026 — Nicole: Clean up pass. ONE DATA FIX: the Worth County 2011
                     population-only row (kept by the Section 4 merge) had
                     a BLANK county_name; now filled, and the leftover
                     name_clean variable is dropped from the final panel.
                     No harvest or population values change. Asserts
                     added: identity exceptions pinned (archery: Ste.
                     Genevieve 2005 only; firearm: none), UNKNOWN county
                     2004 values, all crosswalk merges, population merge
                     (only Worth 2011 population-only), pop_nextseason(t)
                     == pop_preseason(t+1). FIPS crosswalk verified against
                     Census 2020 (114/114). Stale rename notes removed. Labels 
		     shortened to Stata's 80-char limit (earlier labels were 
		     truncated in the saved .dta); long-form documentation moved 
		     to -notes-.

==============================================================================*/

*==============================================================================
* SECTION 0: SETUP
*==============================================================================

clear all
set more off
capture log close

global root "/mnt/data_d/Dropbox/Research/UngulatePopulationDataRepo"
global dataRAW   "$root/dataRAW"
global dataSTATA "$root/dataSTATA"
global dataCLEAN "$root/dataCLEAN"
global codeSTATA "$root/codeSTATA"

di "$root"
di "$dataRAW"

cap mkdir "$codeSTATA/logs"
log using "$codeSTATA/logs/MO_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/MO"
cap mkdir "$dataCLEAN/MO"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

No MO source file carries a FIPS code -- both harvest files use MDC's own
internal ordinal county code (COCODE, 001-114 + 115="UNKNOWN"), and the
population file has county name only. Built here as a static reference
table, state FIPS 29, 114 counties (Missouri has no independent city in
this data -- see note below).

SOURCING NOTE: Pulled from the Missouri Office of Administration's published 
county code table (FIPS PUB 6-4-derived), cross-checked against a Department of
Conservation cancer-registry appendix listing the same codes. Spot-checked 
against https://www2.census.gov/geo/docs/reference/codes2020/cou/st29_mo_cou2020.txt

VERIFIED 09/15/2026: all 114 codes match the Census 2020 reference list
(names match once Census "St."/"Ste." are spelled out as Saint/Sainte,
including Sainte Genevieve 186 / Saint Francois 187).

MDC's own COCODE (001-114, used inside both harvest files) is NOT the same 
sequence as the real Census FIPS codes, and the two disagree in relative order 
for exactly one pair of counties: MDC's COCODE has SAINT FRANCOIS (094) before 
SAINTE GENEVIEVE (095) -- natural alphabetical order -- but the real FIPS codes 
have Ste. Genevieve (186) BEFORE St. Francois (187), a historical quirk (Ste.
Genevieve was recoded from 193 to 186 in 1979 "to maintain alphabetic
consistency" per the state's own documentation, and the recode leap-
frogged St. Francois). Net effect: a naive 1:1 positional merge of
COCODE order onto a sorted FIPS list would silently swap the FIPS codes
for these two counties. The crosswalk below is built and merged by
COUNTY NAME, not by COCODE position.

St. Louis City is an independent city in Missouri (real FIPS 510) but never 
appears in either MO source file -- both harvest CONAME and population County 
lists top out at 114 units with no city entry. Confirmed on inspection, not an 
import artifact. Excluded from the crosswalk below.

------------------------------------------------------------------------*/

input str20 county_name str3 fips_suffix
"Adair" "001"
"Andrew" "003"
"Atchison" "005"
"Audrain" "007"
"Barry" "009"
"Barton" "011"
"Bates" "013"
"Benton" "015"
"Bollinger" "017"
"Boone" "019"
"Buchanan" "021"
"Butler" "023"
"Caldwell" "025"
"Callaway" "027"
"Camden" "029"
"Cape Girardeau" "031"
"Carroll" "033"
"Carter" "035"
"Cass" "037"
"Cedar" "039"
"Chariton" "041"
"Christian" "043"
"Clark" "045"
"Clay" "047"
"Clinton" "049"
"Cole" "051"
"Cooper" "053"
"Crawford" "055"
"Dade" "057"
"Dallas" "059"
"Daviess" "061"
"DeKalb" "063"
"Dent" "065"
"Douglas" "067"
"Dunklin" "069"
"Franklin" "071"
"Gasconade" "073"
"Gentry" "075"
"Greene" "077"
"Grundy" "079"
"Harrison" "081"
"Henry" "083"
"Hickory" "085"
"Holt" "087"
"Howard" "089"
"Howell" "091"
"Iron" "093"
"Jackson" "095"
"Jasper" "097"
"Jefferson" "099"
"Johnson" "101"
"Knox" "103"
"Laclede" "105"
"Lafayette" "107"
"Lawrence" "109"
"Lewis" "111"
"Lincoln" "113"
"Linn" "115"
"Livingston" "117"
"McDonald" "119"
"Macon" "121"
"Madison" "123"
"Maries" "125"
"Marion" "127"
"Mercer" "129"
"Miller" "131"
"Mississippi" "133"
"Moniteau" "135"
"Monroe" "137"
"Montgomery" "139"
"Morgan" "141"
"New Madrid" "143"
"Newton" "145"
"Nodaway" "147"
"Oregon" "149"
"Osage" "151"
"Ozark" "153"
"Pemiscot" "155"
"Perry" "157"
"Pettis" "159"
"Phelps" "161"
"Pike" "163"
"Platte" "165"
"Polk" "167"
"Pulaski" "169"
"Putnam" "171"
"Ralls" "173"
"Randolph" "175"
"Ray" "177"
"Reynolds" "179"
"Ripley" "181"
"Saint Charles" "183"
"Saint Clair" "185"
"Sainte Genevieve" "186"
"Saint Francois" "187"
"Saint Louis" "189"
"Saline" "195"
"Schuyler" "197"
"Scotland" "199"
"Scott" "201"
"Shannon" "203"
"Shelby" "205"
"Stoddard" "207"
"Stone" "209"
"Sullivan" "211"
"Taney" "213"
"Texas" "215"
"Vernon" "217"
"Warren" "219"
"Washington" "221"
"Wayne" "223"
"Webster" "225"
"Worth" "227"
"Wright" "229"
end

gen county_fips = "29" + fips_suffix
drop fips_suffix

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 114

label variable county_fips "MO county FIPS code (5-digit, state+county)"
label variable county_name "County name (Census, with St./Ste. spelled out Saint/Sainte)"
label variable name_clean  "Merge key: county_name upper-cased, trimmed, periods/spaces removed"
label data "MO county FIPS crosswalk, 114 counties (state FIPS 29; excl. St. Louis City)"

save "$dataSTATA/MO/MO_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import, Harmonize & Append
*==============================================================================

/*------------------------------------------------------------------------

Both files are already county-year-sex/age long format -- no reshape
needed. The work here is schema harmonization, not reshaping: the two
files disagree on column order, Total-variable naming, and whether an
Unknown-sex category exists at all. Harmonized to a common vocabulary
before appending:

  harvest_buck_firearm    harvest_buck_archery
  harvest_bbuck_firearm   harvest_bbuck_archery   (button buck)
  harvest_doe_firearm     harvest_doe_archery
  harvest_unk_firearm     harvest_unk_archery     (unknown sex/age)
  harvest_total_firearm   harvest_total_archery

------------------------------------------------------------------------*/

*--------------------------------- 2a. -----------------------------------

import excel "$dataRAW/Deer_Harvest/MO/MO.Harvest.2002-2011.CountySex.Lombardo.xlsx", ///
    sheet("SumByCounty-2002-2011") firstrow clear

rename theYEAR year
rename COCODE cocode
rename CONAME county_name
rename BKF harvest_buck_firearm
rename BBF harvest_bbuck_firearm
rename DOEF harvest_doe_firearm
rename UNF  harvest_unk_firearm
rename BKA harvest_buck_archery
rename BBA harvest_bbuck_archery
rename DOEA harvest_doe_archery
rename UNA  harvest_unk_archery
rename TOTALF harvest_total_firearm
rename TOTALA harvest_total_archery
drop Ordinal

label variable year        "Harvest year"
label variable cocode      "MDC internal county ordinal code (001-114, 115=UNKNOWN placeholder) -- NOT a FIPS code, dropped after crosswalk merge below"
label variable county_name "County name (source spelling, upper case)"
* Variable labels, per this sheet's own ColumnKey tab:
*   Starts with "B"   --> buck harvest;  starts with "DOE" --> doe harvest
*   "BB"               --> button buck
*   Ends with "F"      --> firearm season; ends with "A" --> archery season
label variable harvest_buck_firearm  "Buck harvest, firearm season"
label variable harvest_buck_archery  "Buck harvest, archery season"
label variable harvest_bbuck_firearm "Button buck harvest, firearm season"
label variable harvest_bbuck_archery "Button buck harvest, archery season"
label variable harvest_doe_firearm   "Doe harvest, firearm season"
label variable harvest_doe_archery   "Doe harvest, archery season"
label variable harvest_unk_firearm   "Unknown-sex/age harvest, firearm season"
label variable harvest_unk_archery   "Unknown-sex/age harvest, archery season"
label variable harvest_total_firearm "Total harvest, firearm season (buck + button buck + doe + unknown)"
label variable harvest_total_archery "Total harvest, archery season (buck + button buck + doe + unknown)"

* COCODE 115 = "UNKNOWN" is MDC's catch-all bucket for harvest that could not be 
* attributed to a specific county -- not a real geographic unit, so it can't 
* merge to the crosswalk and is dropped here. Mostly trivial (0 in most years) 
* but NOT negligible in 2004 (445 total: 381 firearm + 64 archery) -- worth 
* confirming that dropping this is acceptable rather than, say, footnoting it as
* an unattributed-harvest total alongside the panel.

list year cocode harvest_total_firearm harvest_total_archery if county_name == "UNKNOWN"
* pin the 2004 amounts documented above (the only non-trivial year)
assert harvest_total_firearm == 381 if county_name == "UNKNOWN" & year == 2004
assert harvest_total_archery ==  64 if county_name == "UNKNOWN" & year == 2004
drop if county_name == "UNKNOWN"

* QC: re-confirm the arithmetic identity found during inspection. One genuine 
* exception survives: Sainte Genevieve, 2005 -- BKA+BBA+DOEA+UNA = 417 but 
* TOTALA is reported as 419 (a 2-unit gap in the source, not an import bug). 
* Kept as reported rather than force-corrected; flag on whether to trust the 
* component sum or the reported total for that one county-year. Pinned below.
gen _check_f = harvest_buck_firearm + harvest_bbuck_firearm + harvest_doe_firearm + harvest_unk_firearm
gen _check_a = harvest_buck_archery + harvest_bbuck_archery + harvest_doe_archery + harvest_unk_archery
list year county_name harvest_total_firearm _check_f if _check_f != harvest_total_firearm
list year county_name harvest_total_archery _check_a if _check_a != harvest_total_archery
assert _check_f == harvest_total_firearm
count if _check_a != harvest_total_archery
assert r(N) == 1
assert county_name == "SAINTE GENEVIEVE" & year == 2005 ///
    & harvest_total_archery == 419 & _check_a == 417 ///
    if _check_a != harvest_total_archery
drop _check_f _check_a

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/MO/MO_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* Every harvest row must match, and every crosswalk county must appear.
assert _merge_xwalk == 3
drop _merge_xwalk cocode

isid county_fips year
save "$dataSTATA/MO/temp_MO_harvest_2002-2011.dta", replace

*--------------------------------- 2b. -----------------------------------

import excel "$dataRAW/Deer_Harvest/MO/MO.Harvest.2012-2014.CountySex.Lombardo.xlsx", ///
    sheet("SumByCounty-2012-2014") firstrow clear

rename theYEAR year
rename COCODE cocode
rename CONAME county_name
rename BKA harvest_buck_archery
rename BBA harvest_bbuck_archery
rename DOEA harvest_doe_archery
rename TotalA harvest_total_archery
rename BKF harvest_buck_firearm
rename BBF harvest_bbuck_firearm
rename DOEF harvest_doe_firearm
rename TotalF harvest_total_firearm
drop Ordinal

label variable year        "Harvest year"
label variable cocode      "MDC internal county ordinal code (001-114, 115=UNKNOWN placeholder) -- NOT a FIPS code, dropped after crosswalk merge below"
label variable county_name "County name (source spelling, upper case)"
* Variable labels, per this sheet's own ColumnKey tab:
*   Starts with "B"   --> buck harvest;  starts with "DOE" --> doe harvest
*   "BB"               --> button buck
*   Ends with "F"      --> firearm season; ends with "A" --> archery season
label variable harvest_buck_firearm  "Buck harvest, firearm season"
label variable harvest_buck_archery  "Buck harvest, archery season"
label variable harvest_bbuck_firearm "Button buck harvest, firearm season"
label variable harvest_bbuck_archery "Button buck harvest, archery season"
label variable harvest_doe_firearm   "Doe harvest, firearm season"
label variable harvest_doe_archery   "Doe harvest, archery season"
label variable harvest_total_firearm "Total harvest, firearm season (buck + button buck + doe + unknown)"
label variable harvest_total_archery "Total harvest, archery season (buck + button buck + doe + unknown)"

* Unknown-sex category is structurally absent from this file (not just
* unpopulated, as with OH's post-2003 gap) -- left as genuinely missing
* rather than 0, since 0 would falsely claim "zero unknown-sex harvest"
* for a category MDC stopped tracking/reporting.
gen harvest_unk_firearm = .
gen harvest_unk_archery = .

list year cocode harvest_total_firearm harvest_total_archery if county_name == "UNKNOWN"
drop if county_name == "UNKNOWN"

* QC: arithmetic identity (no Unknown component to add here -- inspection
* found this file's Totals reconcile exactly against Buck+Button+Doe with
* zero exceptions, unlike the 2002-2011 file's Sainte Genevieve gap).
gen _check_f = harvest_buck_firearm + harvest_bbuck_firearm + harvest_doe_firearm
gen _check_a = harvest_buck_archery + harvest_bbuck_archery + harvest_doe_archery
assert _check_f == harvest_total_firearm
assert _check_a == harvest_total_archery
drop _check_f _check_a

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/MO/MO_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
assert _merge_xwalk == 3
drop _merge_xwalk cocode

isid county_fips year
save "$dataSTATA/MO/temp_MO_harvest_2012-2014.dta", replace

*--------------------------------- 2c. -----------------------------------

use "$dataSTATA/MO/temp_MO_harvest_2002-2011.dta", clear
append using "$dataSTATA/MO/temp_MO_harvest_2012-2014.dta"

* Worth County (FIPS 29227) is genuinely absent for 2011 -- not a zero-harvest 
* row, no row at all in the source. Confirmed on inspection (every other county-
* year is present 2002-2014). Left as a true gap rather than imputed; will show 
* up as a hole in any balanced panel check downstream, worth flagging so it 
* isn't mistaken for a merge bug later. count if county_fips == "29227" & 
* year == 2011 assert r(N) == 0

isid county_fips year
count
assert r(N) == 114 * 13 - 1          // everything except Worth 2011
save "$dataSTATA/MO/temp_MO_harvest_2002-2014_raw.dta", replace
describe

*==============================================================================
* SECTION 3: POPULATION DATA - Import & Clean
*==============================================================================

/*------------------------------------------------------------------------

County-name-only (no FIPS), same pattern as OH/WI/NC. Two continuous,
non-integer population index fields per county-year -- a pre-season
estimate and a next-season estimate -- consistent with a model-based
reconstruction (like OH's PreHuntPop) rather than a direct count.

Unlike VA where the final panel was narrowed to a single population index, MO's 
source gives two types (pre-season / next-season) -- BUT they are the same 
series offset by one year: pop_nextseason in year t EQUALS pop_preseason in year 
t+1 exactly, for every county, 2002-2013 (1,368 of 1,368 county-years; asserted 
below). So pop_nextseason adds only one value per county beyond pop_preseason:
its 2014 value, i.e. the 2015 pre-season estimate (hence "02-15" in the
filename). Both are kept here; likely keep pop_preseason and drop or
footnote pop_nextseason.

Five counties use "St."/"Ste." abbreviations in this file (Saint Charles, Saint 
Clair, Saint Francois, Saint Louis, Sainte Genevieve) where the harvest CONAME 
field and crosswalk both use the spelled-out form -- recoded below before 
generating the merge key, rather than relying on name_clean's period/
space-stripping alone (which would leave "ST" vs "SAINT" as a residual mismatch).

Note: import excel's firstrow option sanitizes header text with spaces
into valid Stata names ("Sum Of TotalPreSeason" -> SumOfTotalPreSeason);
the renames below use that form.

------------------------------------------------------------------------*/

import excel "$dataRAW/Deer_Population/MO/MO.Pop.02-15.County.Lombardo.xlsx", ///
    sheet("Copy of Totals county Query") firstrow clear

rename theYear year
rename County county_name
rename SumOfTotalPreSeason pop_preseason
rename SumOfTotalNextSeason pop_nextseason

label variable year           "Population estimate year"
label variable county_name    "County name (source spelling)"
label variable pop_preseason  "Deer population index, pre-season (model-based; Lombardo)"
label variable pop_nextseason "Deer population index, next season (= pop_preseason of t+1)"

replace county_name = "Saint Charles"    if county_name == "St. Charles"
replace county_name = "Saint Clair"      if county_name == "St. Clair"
replace county_name = "Saint Francois"   if county_name == "St. Francois"
replace county_name = "Saint Louis"      if county_name == "St. Louis"
replace county_name = "Sainte Genevieve" if county_name == "Ste. Genevieve"

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/MO/MO_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* Every row must match once the five St./Ste. recodes above are applied.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

isid county_fips year
assert year >= 2002 & year <= 2014
assert !missing(pop_preseason, pop_nextseason)
count
assert r(N) == 114 * 13

* pop_nextseason(t) == pop_preseason(t+1) for every county, 2002-2013
sort county_fips year
by county_fips: assert pop_nextseason == pop_preseason[_n+1] if _n < _N
save "$dataSTATA/MO/temp_MO_population_2002-2014.dta", replace
describe

*==============================================================================
* SECTION 4: FINAL PANEL MERGE
*==============================================================================

/*------------------------------------------------------------------------

Harvest covers 2002-2014 (with the Worth 2011 gap noted in 2c);
population covers 2002-2014 with full county coverage each year. Unlike
OH (population starting a year after harvest), MO's two sources share
the same year range, so `_merge_pop` should come back all-matched except
for the single Worth-2011 hole, which shows up as population-only
(using-only) for that one county-year. That row is KEPT in the final
panel (114 x 13 = 1,482 rows) with harvest missing and population
present; its county_name is filled below.

------------------------------------------------------------------------*/

use "$dataSTATA/MO/temp_MO_harvest_2002-2014_raw.dta", clear
isid county_fips year

merge 1:1 county_fips year ///
    using "$dataSTATA/MO/temp_MO_population_2002-2014.dta", ///
    keepusing(pop_preseason pop_nextseason) ///
    keep(master match using) gen(_merge_pop)
* Everything matches except Worth/2011, which is population-only
* (_merge_pop == 2) because harvest has no row there.
assert _merge_pop == 3 | (_merge_pop == 2 & county_fips == "29227" & year == 2011)
count if _merge_pop == 2
assert r(N) == 1
* A using-only row gets no county_name (keepusing brings only the pop
* variables) -- fill it so the row isn't blank-named downstream.
replace county_name = "WORTH" if _merge_pop == 2
drop _merge_pop
capture drop name_clean              // merge key, not a panel variable

order county_fips county_name year ///
    harvest_buck_firearm harvest_bbuck_firearm harvest_doe_firearm harvest_unk_firearm harvest_total_firearm ///
    harvest_buck_archery harvest_bbuck_archery harvest_doe_archery harvest_unk_archery harvest_total_archery ///
    pop_preseason pop_nextseason

label data "MO county-year deer harvest (sex/age x weapon) and population index, 2002-2014"

notes: Source: Lombardo files (presumed MDC). Harvest from two files with drifted schemas (2002-2011, 2012-2014) harmonized to one vocabulary; UNKNOWN-county catch-all rows dropped (445 head in 2004, near zero otherwise).
notes harvest_unk_firearm: Unknown-sex/age harvest is structurally absent from the 2012-2014 file: missing (not zero) 2012-2014. Same for harvest_unk_archery.
notes harvest_total_archery: Sainte Genevieve 2005 reported total 419 vs component sum 417; retained as reported.
notes county_fips: Worth County (29227) has no harvest row in the source for 2011; the row exists with harvest missing and population present. St. Louis City (29510) is not in either source.
notes pop_nextseason: Equals pop_preseason of the following year for every county 2002-2013; its 2014 value is the 2015 pre-season estimate.

isid county_fips year
assert year >= 2002 & year <= 2014
assert county_name != ""
count
assert r(N) == 114 * 13
bysort county_fips: assert _N == 13
assert missing(harvest_total_firearm) == (county_fips == "29227" & year == 2011)
assert missing(harvest_unk_firearm) == (year >= 2012 | (county_fips == "29227" & year == 2011))
sort county_fips year
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/MO/MO_deer_harmonized_county_year_2002-2014.dta", replace

log close
