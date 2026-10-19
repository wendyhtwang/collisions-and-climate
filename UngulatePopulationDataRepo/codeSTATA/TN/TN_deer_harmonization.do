/*==============================================================================

FILE NAME:   TN_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  Tennessee (TN) county-level deer HARVEST harmonization.
          "12 same-format yearly files, no population" pattern flagged in
          the state-sequencing notes -- 12 season-level CSVs, one row per
          county, already long by construction, requiring an append/stack
          rather than a reshape. No population source file of any kind was
          provided (same IN-style case: absence by data availability, not
          an affirmative MD/KY-style exclusion -- see Section 3).

          Each of the 12 CSVs carries the same four harvest columns, sex/
          antler-status stratified: AntlerMaleCnt, AntlerlessMaleCnt,
          FemaleCnt, TotalHarvestCount. No county FIPS, no footer/total
          row to strip -- clean one-header-row files, UTF-8 with BOM.

          TWO STRUCTURAL ISSUES SURFACED DURING PRE-CODE AUDIT, both
          documented in Section 2 rather than silently resolved:

            1. The "04Season" file is a severe outlier: only 30
               of 95 counties present, statewide total = 53 head, vs.
               roughly 162,000-182,000 head/year for every other season in
               the set (05-15). This is not comparable data -- it reads as
               a fragment (special hunt? partial-year extract?) rather
               than a full statewide season report. Excluded from the
               panel below pending agency confirmation; NOT silently
               dropped -- see Section 2a.

            2. NOTE: DeKalb County is absent from every one of the 11
               remaining files (05-15Season), consistently -- not a random
               gap. Left as a missing county-year in the panel (NOT zero-
               filled) per the WI Menominee-absent-from-Stenglein
               precedent: a structural gap is documented, not imputed.
               Asserted in Section 2b.

          AGENCY STATUS: a formal TN Wildlife Resources Agency records request 
	  is in progress (routed via clerk Gabby Colarusso to TWRA.recordreq@tn.gov;
          Elizabeth Brown, Office of General Counsel, confirmed the
          Wildlife Division can fulfill it). Fee estimate 7 billed hours
          at $53.11/hr = $371.77, target completion Oct 15 2026; Eyal
          approved and an invoice was requested. That request is the
          likely route to resolving both the 2004 fragment and the
          season-year convention below.

          SEASON-YEAR CONVENTION: source filenames give only a two-digit season 
	  code ("04Season" .. "15Season"), with no in-file year variable. 
	  Following the season-start-year convention (e.g. WI/OH "2010-11" -> 
	  2010), each file is assigned season_start_year = 2000 + the two-digit 
	  code (e.g. "10Season" -> 2010). This has NOT been independently 
	  confirmed against a TDEC/TWRA report -- flagged for verification, same
          caveat as other states' un-confirmed season-start assumptions.

SOURCE FILES USED:

  TN_Harvest_04Season_CountySex_Web.csv        (excluded, see Section 2a)
  
  TN_Harvest_05Season_CountySex_Web_csv.csv
  
  TN_Harvest_06Season_CountySex_Web_csv.csv
  
  TN_Harvest_07Season_CountySex_Web_csv.csv
  
  TN_Harvest_08Season_CountySex_Web_csv.csv
  
  TN_Harvest_09Season_CountySex_Web_csv.csv
  
  TN_Harvest_10Season_CountySex_Web_csv.csv
  
  TN_Harvest_11Season_CountySex_Web_csv.csv
  
  TN_Harvest_12Season_CountySex_Web_csv.csv
  
  TN_Harvest_13Season_CountySex_Web_csv.csv
  
  TN_Harvest_14Season_CountySex_Web_csv.csv
  
  TN_Harvest_15Season_CountySex_Web_csv.csv
  
  No separate population file provided for TN.

CHANGELOG:

08/20/2026 — Nicole: First pass. Harvest-only panel (harvest_total,
                     harvest_antlered_male, harvest_antlerless_male,
                     harvest_female), 95 counties x 2005-2015 (2004
                     excluded, see Section 2a), DeKalb missing every
                     year (documented structural gap, not imputed).
                     Static FIPS crosswalk (state FIPS 47, clean
                     alphabetical-by-Census-convention 001-189 by 2s,
                     no split/renamed counties). Row-level identity
                     (component sum == TotalHarvestCount) holds exactly
                     for every row in every retained file -- first
                     harvest-only state with zero row-level QC
                     discrepancies. Population Section 3 left
                     explicitly empty: no source file, not an exclusion
                     call.

08/24/2026 — Nicole: Crosswalk verified against Census/NIST county
                     reference file. 7 codes corrected (McMinn/McNairy
                     precede Macon/Madison/Marion/Marshall/Maury in the
                     Census sequence, not strict ASCII order) -- see
                     Section 1 note. No other codes affected.

09/16/2026 — Nicole: Clean up pass, no change to data values. Asserts added
                     for things the comments only stated: the 2004
                     fragment's 30 rows / 53 head, 94 rows per season file,
                     no missing cells after destring, the stacked file's
                     column count (catches a missing BOM in any one file),
                     and the crosswalk merge. DeKalb relabeled NOTE
                     (settled); TWRA records-request status recorded in the
                     header. year recast to int (was a double from the
                     2000 + season-code arithmetic). FIPS crosswalk
                     re-verified against Census 2020 (95/95, including the
                     McMinn/McNairy ordering fixed on 08/24). Labels
                     shortened to Stata's 80-char limit; long-form
                     documentation moved to -notes-. Panel sorted before
                     save.

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
log using "$codeSTATA/logs/TN_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/TN"
cap mkdir "$dataCLEAN/TN"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

Like IN/KY/OH/NC/MO/MD, no source file carries a FIPS code -- county name
only. Built here as a static reference table (state FIPS 47, 95 counties,
clean alphabetical numbering 001-189 by 2s -- no independent cities, no
DMU-style carve-outs, no renamed/split counties). VERIFIED 09/16/2026:
all 95 name/code pairs match the Census 2020 county FIPS reference list
exactly, including the McMinn (107) / McNairy (109) placement before
Macon (111) corrected on 08/24
https://www2.census.gov/geo/docs/reference/codes2020/cou/st47_tn_cou2020.txt

------------------------------------------------------------------------*/

input str20 county_name str3 fips_suffix
"Anderson"     "001"
"Bedford"      "003"
"Benton"       "005"
"Bledsoe"      "007"
"Blount"       "009"
"Bradley"      "011"
"Campbell"     "013"
"Cannon"       "015"
"Carroll"      "017"
"Carter"       "019"
"Cheatham"     "021"
"Chester"      "023"
"Claiborne"    "025"
"Clay"         "027"
"Cocke"        "029"
"Coffee"       "031"
"Crockett"     "033"
"Cumberland"   "035"
"Davidson"     "037"
"Decatur"      "039"
"DeKalb"       "041"
"Dickson"      "043"
"Dyer"         "045"
"Fayette"      "047"
"Fentress"     "049"
"Franklin"     "051"
"Gibson"       "053"
"Giles"        "055"
"Grainger"     "057"
"Greene"       "059"
"Grundy"       "061"
"Hamblen"      "063"
"Hamilton"     "065"
"Hancock"      "067"
"Hardeman"     "069"
"Hardin"       "071"
"Hawkins"      "073"
"Haywood"      "075"
"Henderson"    "077"
"Henry"        "079"
"Hickman"      "081"
"Houston"      "083"
"Humphreys"    "085"
"Jackson"      "087"
"Jefferson"    "089"
"Johnson"      "091"
"Knox"         "093"
"Lake"         "095"
"Lauderdale"   "097"
"Lawrence"     "099"
"Lewis"        "101"
"Lincoln"      "103"
"Loudon"       "105"
"McMinn"       "107"
"McNairy"      "109"
"Macon"        "111"
"Madison"      "113"
"Marion"       "115"
"Marshall"     "117"
"Maury"        "119"
"Meigs"        "121"
"Monroe"       "123"
"Montgomery"   "125"
"Moore"        "127"
"Morgan"       "129"
"Obion"        "131"
"Overton"      "133"
"Perry"        "135"
"Pickett"      "137"
"Polk"         "139"
"Putnam"       "141"
"Rhea"         "143"
"Roane"        "145"
"Robertson"    "147"
"Rutherford"   "149"
"Scott"        "151"
"Sequatchie"   "153"
"Sevier"       "155"
"Shelby"       "157"
"Smith"        "159"
"Stewart"      "161"
"Sullivan"     "163"
"Sumner"       "165"
"Tipton"       "167"
"Trousdale"    "169"
"Unicoi"       "171"
"Union"        "173"
"Van Buren"    "175"
"Warren"       "177"
"Washington"   "179"
"Wayne"        "181"
"Weakley"      "183"
"White"        "185"
"Williamson"   "187"
"Wilson"       "189"
end

gen county_fips = "47" + fips_suffix
gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 95

label variable county_fips "TN county FIPS code (5-digit, state+county)"
label variable county_name "County name (Census spelling)"
label variable name_clean  "Merge key: county_name upper-cased, trimmed, periods/spaces removed"
label data "TN county FIPS crosswalk, 95 units (static reference, state FIPS 47)"

save "$dataSTATA/TN/TN_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import, Stack & Merge
*==============================================================================

/*------------------------------------------------------------------------

12 season-level CSVs, one row per county, already long by construction.
Stacked via append rather than reshaped. Source filenames are
inconsistently formatted (04's has no "_csv" suffix, unlike 05-15's), so
mapped explicitly by season code rather than looped off a glob pattern.

------------------------------------------------------------------------*/

*--------------------------------- 2a. -----------------------------------

/*
TN_Harvest_04Season_CountySex_Web.csv contains only 30 of 95 counties and a 
statewide TotalHarvestCount sum of 53 head, against 162,000-182,000 head/year 
for every other season on file (see below).

This is not likely plausible statewide count for a normal TN deer
season -- it reads as a fragment of a much smaller report rather than a
full county-level harvest file. Imported and inspected here for the
record, then EXCLUDED from the stacked panel rather than appended
alongside the other 11 (silent inclusion would badly distort any
year-over-year harvest trend). Flagged for agency follow-up: is
there a genuine full 2004 county-level harvest file, or does 2004
coverage not exist for this project's purposes?
*/

import delimited "$dataRAW/Deer_Harvest/TN/TN.Harvest.04Season.CountySex.Web.csv", ///
    varnames(1) clear stringcols(1)

gen season_start_year = 2004
count
assert r(N) == 30
summarize totalharvestcount
di "2004 file: " r(N) " county rows, statewide sum = " %12.0fc r(sum)
assert r(N) == 30 & r(sum) == 53
* 30 rows, sum = 53 -- confirms the fragment noted above. If a fuller
* 2004 file ever replaces this one, these asserts fail and the exclusion
* decision gets revisited rather than silently standing.
* Not saved forward -- excluded from the panel, per note above.

*--------------------------------- 2b. ----------------------------------

tempfile stacked
local first = 1

foreach yy in 05 06 07 08 09 10 11 12 13 14 15 {
    import delimited ///
        "$dataRAW/Deer_Harvest/TN/TN.Harvest.`yy'Season.CountySex.Web.csv.csv", ///
        varnames(1) clear stringcols(1)

    gen season_start_year = 2000 + `yy'

    * one row per county, DeKalb absent -> 94 rows in every season file
    count
    assert r(N) == 94

    if `first' == 1 {
        save `stacked', replace
        local first = 0
    }
    else {
        append using `stacked'
        save `stacked', replace
    }
}

use `stacked', clear

* 11 files x 94 counties, and exactly 6 columns: if any file were saved
* without the UTF-8 BOM, append would add a second county-name column
* (areatype vs ïareatype) and that season's names would come through blank.
count
assert r(N) == 94 * 11
quietly describe
assert r(k) == 6

rename ïareatype           county_name
rename antlermalecnt      harvest_antlered_male
rename antlerlessmalecnt  harvest_antlerless_male
rename femalecnt          harvest_female
rename totalharvestcount  harvest_total

destring harvest_antlered_male harvest_antlerless_male harvest_female ///
    harvest_total, replace
assert !missing(harvest_antlered_male, harvest_antlerless_male, ///
    harvest_female, harvest_total)
assert county_name != ""

* Row-level identity check: does TotalHarvestCount == sum of the three
* sex/antler-status components? YES, exactly, for all 1034 rows across all 11 
* retained years -- first harvest-only state with zero row-level discrepancies 
* (contrast IN: 72/1104 rows off; CA: buck/doe reconciliation needed). No 
* adjustment made; check kept in for the record and for the next state's comparison.
gen _sexsum = harvest_antlered_male + harvest_antlerless_male + harvest_female
gen _rowdiff = harvest_total - _sexsum
count if _rowdiff != 0
assert _rowdiff == 0
drop _sexsum _rowdiff

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/TN/TN_county_crosswalk.dta", ///
    keepusing(county_fips) keep(match master) gen(_merge_xwalk)
list county_name season_start_year if _merge_xwalk != 3
* Expected here: nothing -- pre-code audit found no unmatched county
* strings among the 94 counties present per year (DeKalb's absence is a
* row-level gap, not a name-matching failure -- see the header NOTE).
* keep(match master) already excludes DeKalb's crosswalk-only row.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

rename season_start_year year
recast int year   // the 2000 + season-code arithmetic makes it a double

isid county_fips year
bysort county_fips: assert _N == 11
count
assert r(N) == 94 * 11
* 94 (not 95) counties x 11 years (2005-2015): DeKalb missing every
* year, per the header NOTE -- expected, not an error.
codebook county_fips, compact

* Confirm DeKalb really is absent every single year, not just most:
count if county_fips == "47041"
assert r(N) == 0
di "Confirmed: DeKalb (47041) present in 0 of 11 retained years."

save "$dataSTATA/TN/temp_TN_harvest_2005-2015.dta", replace

*==============================================================================
* SECTION 3: POPULATION DATA - no source file provided
*==============================================================================

/*------------------------------------------------------------------------

Same case as IN: no population file of any kind was provided alongside
the 12 TN_Harvest_*Season_CountySex_Web.csv files. This is a data-
availability gap, not a scope decision made in this script.

FOLLOW-UP (TWRA records request, in progress -- see header AGENCY
STATUS): does TWRA have a county- or zone-level deer population estimate
on file for 2005-2015 (or any other years), and separately, does a
genuine full-coverage 2004 harvest file exist to replace the fragment
excluded in Section 2a? Also worth confirming the season-start-year
convention while the request is open.

------------------------------------------------------------------------*/

*==============================================================================
* SECTION 4: FINALIZE HARVEST-ONLY PANEL
*==============================================================================

use "$dataSTATA/TN/temp_TN_harvest_2005-2015.dta", clear

order county_fips county_name year harvest_total harvest_antlered_male ///
    harvest_antlerless_male harvest_female

label variable county_fips             "TN county FIPS code (5-digit string, state+county)"
label variable county_name             "County name, as reported in source"
label variable year                    "Season start year (2000 + source season code)"
label variable harvest_total           "Total deer harvested (= antlered male + antlerless male + female)"
label variable harvest_antlered_male   "Antlered male deer harvested"
label variable harvest_antlerless_male "Antlerless male deer harvested"
label variable harvest_female          "Female deer harvested"
label data "TN county-year deer harvest (antlered/antlerless male, female), 2005-2015"

notes year: Season-start year assigned from the two-digit source season code (05Season -> 2005). Not independently confirmed against TWRA documentation; see do-file header.
notes county_fips: 94 of 95 TN counties. DeKalb (47041) is absent from every season file -- a structural gap, left missing rather than zero-filled.
notes harvest_total: Source-reported total; equals the sum of the three components in every row (1,034 of 1,034). The 2004 season file is excluded from this panel as a fragment (30 of 95 counties, 53 head statewide); see do-file Section 2a.
notes: Harvest-only panel. No population source file was provided for TN (data-availability gap, not an exclusion). A TWRA records request is in progress (target Oct 2026).

isid county_fips year
assert year >= 2005 & year <= 2015
assert harvest_total >= 0
assert harvest_antlered_male >= 0
assert harvest_antlerless_male >= 0
assert harvest_female >= 0
assert harvest_total == harvest_antlered_male + harvest_antlerless_male + harvest_female
count
assert r(N) == 94 * 11
bysort county_fips: assert _N == 11
sort county_fips year
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/TN/TN_deer_harmonized_county_year_2005-2015.dta", replace

log close
