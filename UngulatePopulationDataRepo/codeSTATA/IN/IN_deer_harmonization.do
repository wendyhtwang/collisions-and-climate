/*==============================================================================

FILE NAME:   IN_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  Indiana (IN) county-level deer HARVEST harmonization. First state
          to establish the "single file, no population" pattern flagged in
          the state-sequencing notes -- one workbook, one county-level
          sheet, already in long (county x year) form rather than wide-by-
          year, and no population source file of any kind was provided.

          IMPORTANT STRUCTURAL DIFFERENCE FROM KY/MD: KY and MD each
          received a population source file that was inspected and then
          affirmatively EXCLUDED (statewide-only, no county resolution).
          IN never received a population file -- Caudell's workbook is 
	  harvest-only by construction, not by an exclusion decision. 
	  Documented as a distinct case in Section 3 rather than folded into 
	  the KY/MD precedent language.

          Two sheets:
	  
            1. "HarvestbyCounty"    -- county-level TOTAL/antlered/
                                       antlerless harvest, ALREADY LONG
                                       (NAME_L, yr, TotDeerHarv, Anterless,
                                       Antlered), 92 counties x 2005-2016,
                                       zero missing county-years. No
                                       reshape needed.
				       
            2. "TotalHarvestYear"   -- statewide annual totals (Year,
                                       Total Deer, Antlered, Antlerless),
                                       2005-2016. Used below as the QC
                                       reference series, same role the
                                       footer "Total" row plays in the
                                       wide-by-year states.

          NOTE: Source filename reads "IN_Harvest_05-15_..." but both
          sheets actually run through 2016 (12 seasons, 2005-2016), not
          2015. Confirmed by inspection, not a truncation artifact --
          TotalHarvestYear's 2016 row is fully populated and matches the
          county-level sum for that year exactly (see Section 2 QC).
          Output below is named/scoped to the true 2005-2016 coverage,
          not the filename's stated range.

SOURCE FILES USED:

  PROVENANCE [open]: "Caudell" is a surname only -- presumed Indiana Department
                     of Natural Resources Division of Fish & Wildlife, 
		     affiliation not confirmed.
    
  IN.Harvest.05-15.CountySex.Caudell.xlsx  -- both sheets described above.
                                               No separate population file
                                               provided for IN.

CHANGELOG:

08/19/2026 — Nicole: First pass. Harvest-only panel (harvest_total,
                     harvest_antlered, harvest_antlerless), 92 counties,
                     2005-2016. Static FIPS crosswalk (state FIPS 18,
                     clean alphabetical 001-183 by 2s, no split/renamed
                     counties). Row-level (TotDeerHarv vs Antlered+
                     Antlerless) and year-level (county sum vs
                     TotalHarvestYear sheet) QC checks both surfaced
                     real, unresolved discrepancies -- documented in
                     Section 2 rather than silently reconciled. Population
                     Section 3 left explicitly empty: no source file, not
                     an exclusion call.

09/15/2026 — Nicole: Clean up pass, no change to data values. Row-level
                     identity check now pinned (72 rows, only in 2009,
                     2010, 2012, 2013 -- the comment's "+/-1 to 4 runs
                     throughout" corrected); year-level QC now asserts the
                     documented 2008/2012/2013/2014 gaps and the exact
                     2016 match. Row counts, balance, and crosswalk merge
                     asserted. FIPS crosswalk verified against Census 2020
                     (92/92). Labels shortened to Stata's 80-char limit
                     (earlier labels were truncated in the saved .dta);
                     long-form documentation moved to -notes-. Panel sorted
                     by county_fips year before save.

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
log using "$codeSTATA/logs/IN_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/IN"
cap mkdir "$dataCLEAN/IN"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

Like KY/OH/NC/MO/MD, no source sheet carries a FIPS code -- county name
only. Built here as a static reference table (state FIPS 18, 92 counties,
clean alphabetical numbering 001-183 by 2s -- no independent cities, no
DMU-style carve-outs, no renamed/split counties to complicate the
sequence).

Typed from standard Census county FIPS assignments, not pulled from a
project source file. VERIFIED 09/15/2026: all 92 name/code pairs match the
Census 2020 county FIPS reference list exactly (no mismatches, no missing
codes)
https://www2.census.gov/geo/docs/reference/codes2020/cou/st18_in_cou2020.txt

NOTE: source sheet spells three counties differently from Census-standard
casing/punctuation -- "Dekalb" (Census: "DeKalb"), "Lagrange" (Census:
"LaGrange"), and "St Joseph" (Census: "St. Joseph", no period in source).
Not special-cased here the way OH's "VanWert" note is: name_clean below
uppercases and strips both periods and spaces before matching, so all
three resolve to the same merge key as their Census-standard counterparts
without any extra fix (same free-absorption logic as KY's LaRue/Larue
note).

------------------------------------------------------------------------*/

input str20 county_name str3 fips_suffix
"Adams"        "001"
"Allen"        "003"
"Bartholomew"  "005"
"Benton"       "007"
"Blackford"    "009"
"Boone"        "011"
"Brown"        "013"
"Carroll"      "015"
"Cass"         "017"
"Clark"        "019"
"Clay"         "021"
"Clinton"      "023"
"Crawford"     "025"
"Daviess"      "027"
"Dearborn"     "029"
"Decatur"      "031"
"DeKalb"       "033"
"Delaware"     "035"
"Dubois"       "037"
"Elkhart"      "039"
"Fayette"      "041"
"Floyd"        "043"
"Fountain"     "045"
"Franklin"     "047"
"Fulton"       "049"
"Gibson"       "051"
"Grant"        "053"
"Greene"       "055"
"Hamilton"     "057"
"Hancock"      "059"
"Harrison"     "061"
"Hendricks"    "063"
"Henry"        "065"
"Howard"       "067"
"Huntington"   "069"
"Jackson"      "071"
"Jasper"       "073"
"Jay"          "075"
"Jefferson"    "077"
"Jennings"     "079"
"Johnson"      "081"
"Knox"         "083"
"Kosciusko"    "085"
"LaGrange"     "087"
"Lake"         "089"
"LaPorte"      "091"
"Lawrence"     "093"
"Madison"      "095"
"Marion"       "097"
"Marshall"     "099"
"Martin"       "101"
"Miami"        "103"
"Monroe"       "105"
"Montgomery"   "107"
"Morgan"       "109"
"Newton"       "111"
"Noble"        "113"
"Ohio"         "115"
"Orange"       "117"
"Owen"         "119"
"Parke"        "121"
"Perry"        "123"
"Pike"         "125"
"Porter"       "127"
"Posey"        "129"
"Pulaski"      "131"
"Putnam"       "133"
"Randolph"     "135"
"Ripley"       "137"
"Rush"         "139"
"St. Joseph"   "141"
"Scott"        "143"
"Shelby"       "145"
"Spencer"      "147"
"Starke"       "149"
"Steuben"      "151"
"Sullivan"     "153"
"Switzerland"  "155"
"Tippecanoe"   "157"
"Tipton"       "159"
"Union"        "161"
"Vanderburgh"  "163"
"Vermillion"   "165"
"Vigo"         "167"
"Wabash"       "169"
"Warren"       "171"
"Warrick"      "173"
"Washington"   "175"
"Wayne"        "177"
"Wells"        "179"
"White"        "181"
"Whitley"      "183"
end

gen county_fips = "18" + fips_suffix
drop fips_suffix

* Merge key: uppercase, whitespace-trimmed, periods AND spaces stripped --
* absorbs the Dekalb/DeKalb, Lagrange/LaGrange, and "St Joseph"/"St.
* Joseph" mismatches noted above for free.
gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 92

label variable county_fips "IN county FIPS code (5-digit, state+county)"
label variable county_name "County name (Census spelling)"
label variable name_clean  "Merge key: county_name upper-cased, trimmed, periods/spaces removed"
label data "IN county FIPS crosswalk, 92 units (static reference, state FIPS 18)"

save "$dataSTATA/IN/IN_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import, Clean & Merge
*==============================================================================

/*------------------------------------------------------------------------

HarvestbyCounty is already county x year long -- no rename-loop/reshape
needed, the first project source with this shape. Straight firstrow
import, rename to project convention, merge onto the crosswalk.

TotalHarvestYear (statewide annual totals) plays the same QC role the
footer "Total" row plays in the wide-by-year states: imported separately
and compared against the county-level collapse below rather than trusted
on its own.

------------------------------------------------------------------------*/

*--------------------------------- 2a. Statewide QC reference -------------

import excel "$dataRAW/Deer_Harvest/IN/IN.Harvest.05-15.CountySex.Caudell.xlsx", ///
    sheet("TotalHarvestYear") cellrange(A1:D13) firstrow clear

rename Year year
rename TotalDeer harvest_total_reported
rename Antlered harvest_antlered_reported
rename Antlerless harvest_antlerless_reported

destring year harvest_total_reported harvest_antlered_reported ///
    harvest_antlerless_reported, replace

isid year
count
assert r(N) == 12
assert inrange(year, 2005, 2016)
tempfile statetotals
save `statetotals'

*--------------------------------- 2b. County-level harvest ---------------

import excel "$dataRAW/Deer_Harvest/IN/IN.Harvest.05-15.CountySex.Caudell.xlsx", ///
    sheet("HarvestbyCounty") cellrange(A1:E1105) firstrow clear

rename NAME_L county_name
rename yr year
rename TotDeerHarv harvest_total
* Source header is "Anterless" -- a typo for "Antlerless" (county-level
* value itself is fine, confirmed by inspection; only the column header
* is misspelled). Renamed to the correct project variable name.
rename Anterless harvest_antlerless
rename Antlered harvest_antlered

destring year harvest_total harvest_antlerless harvest_antlered, replace

isid county_name year
count
assert r(N) == 92 * 12
assert !missing(harvest_total, harvest_antlered, harvest_antlerless)

* Row-level identity check: does TotDeerHarv == Antlered + Antlerless?
* NOT for 72 of 1,104 county-year rows (~6.5%), all in four years; every
* other year matches exactly:
*   2009: 27 rows, all within -4..+1 (rounding/entry noise)
*   2010:  1 row  (Bartholomew, +9)
*   2012:  8 rows, 7 of them > 4 head (Ripley +245, Martin +230,
*          Jefferson +135, Jennings +126, ...; year sum +853)
*   2013: 36 rows, 11 of them > 4 head (Huntington +91, Porter +76,
*          Lake +59, ...; year sum +437)
* The 2012/2013 gaps are not likely rounding. TotDeerHarv is kept as the 
* source-reported total rather than recomputed -- see the Section 4. 
* Pinned below so a changed source file surfaces.
gen _sexsum = harvest_antlered + harvest_antlerless
gen _rowdiff = harvest_total - _sexsum
list county_name year harvest_total _sexsum _rowdiff if _rowdiff != 0, sep(0)
count if _rowdiff != 0
assert r(N) == 72
assert _rowdiff == 0 if !inlist(year, 2009, 2010, 2012, 2013)
assert inrange(_rowdiff, -4, 4) if year == 2009
drop _sexsum _rowdiff

* Year-level QC: county sum vs. the workbook's own TotalHarvestYear sheet.
* Matches closely most years (0 to +/-4 head) but NOT exactly -- 2008
* (county sum +64 vs. state sheet), 2012 (antlered/antlerless off by
* -410/-455 even though totals are close, i.e. the sex split shifts
* between the two sheets), 2013 (antlered/antlerless off by -803/+364),
* and 2014 (total off by -247) are all outside plausible rounding.
* Documented rather than reconciled -- both sheets come from the same
* Caudell workbook, so this isn't a cross-source conflict the way WI's
* Stenglein-vs-WDNR one is, but a same-workbook internal inconsistency.
* FOLLOW-UP (IN agency contact): which sheet is the series of record.
preserve
    collapse (sum) harvest_total harvest_antlered harvest_antlerless, by(year)
    merge 1:1 year using `statetotals', gen(_m)
    assert _m == 3                     // all 12 years on both sheets
    drop _m
    gen _diff_total      = harvest_total      - harvest_total_reported
    gen _diff_antlered   = harvest_antlered   - harvest_antlered_reported
    gen _diff_antlerless = harvest_antlerless - harvest_antlerless_reported
    list year harvest_total harvest_total_reported _diff_total ///
        harvest_antlered harvest_antlered_reported _diff_antlered ///
        harvest_antlerless harvest_antlerless_reported _diff_antlerless, ///
        sep(0)
    * Pin the documented values (from the audit notes above):
    assert _diff_total      ==   64 if year == 2008
    assert _diff_antlered   == -410 if year == 2012
    assert _diff_antlerless == -455 if year == 2012
    assert _diff_antlered   == -803 if year == 2013
    assert _diff_antlerless ==  364 if year == 2013
    assert _diff_total      == -247 if year == 2014
    assert _diff_total      ==    0 if year == 2016
restore

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/IN/IN_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* name_clean absorbs the Dekalb/Lagrange/St Joseph spelling differences
* noted in Section 1; all 92 counties present every year -- so every row
* must match, in both directions.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

isid county_fips year
count
codebook county_fips, compact

save "$dataSTATA/IN/temp_IN_harvest_2005-2016.dta", replace

*==============================================================================
* SECTION 3: POPULATION DATA - no source file provided
*==============================================================================

/*------------------------------------------------------------------------

Unlike KY/MD, where a statewide-only population file was received,
inspected, and then affirmatively excluded per the MD precedent, IN
was never sent a population file of any kind alongside
IN_Harvest_05-15_CountySex_Caudell.xlsx. This is a data-availability gap,
not a scope decision -- documented here so the absence of a population variable 
below isn't mistaken for either an oversight or a repeat of the MD/KY 
statewide-only exclusion.

FOLLOW-UP (IN agency contact): worth an explicit ask -- does the
DNR have a county- or zone-level deer population estimate on file for
2005-2016 (or any other years), even if it was never included in the
Caudell harvest workbook?

------------------------------------------------------------------------*/

*==============================================================================
* SECTION 4: FINALIZE HARVEST-ONLY PANEL
*==============================================================================

/*------------------------------------------------------------------------

No population to merge in (Section 3), so the harvest panel from Section
2 IS the final panel -- this section re-confirms integrity and saves to
dataCLEAN under the same naming convention the other states use.

harvest_total is kept as independently source-reported rather than recomputed as 
harvest_antlered + harvest_antlerless, per the Section 2 row-level QC note -- 
the two don't always agree, and overwriting the reported total with a derived 
sum would silently discard the source's own total-harvest figure. Confirm this 
is the desired convention vs. e.g. preferring the derived sum, or dropping the 
~6.5% of rows where they disagree.

------------------------------------------------------------------------*/

use "$dataSTATA/IN/temp_IN_harvest_2005-2016.dta", clear

order county_fips county_name year harvest_total harvest_antlered harvest_antlerless

label variable county_fips        "IN county FIPS code (5-digit string, state+county)"
label variable county_name        "County name, as reported in source"
label variable year               "Harvest year"
label variable harvest_total      "Total deer harvested (source-reported; not always antlered + antlerless)"
label variable harvest_antlered   "Antlered deer harvested"
label variable harvest_antlerless "Antlerless deer harvested (source header misspelled 'Anterless')"
label data "IN county-year deer harvest (total, antlered, antlerless), 2005-2016"

notes harvest_total: Source-reported Total Deer, kept as reported. Differs from harvest_antlered + harvest_antlerless in 72 of 1,104 rows, all in 2009, 2010, 2012, 2013 (2012-13 gaps up to 245 head). County sums also differ from the workbook statewide sheet in 2008, 2012, 2013, 2014. See do-file Section 2.
notes: Harvest-only panel. No population source file was provided for IN (data-availability gap, not an exclusion; do-file Section 3). Source: Caudell workbook (presumed Indiana DNR); filename says 05-15 but both sheets run through 2016.

isid county_fips year
assert year >= 2005 & year <= 2016
assert !missing(harvest_total, harvest_antlered, harvest_antlerless)
assert harvest_total >= 0
assert harvest_antlered >= 0
assert harvest_antlerless >= 0
count
assert r(N) == 92 * 12
bysort county_fips: assert _N == 12
sort county_fips year
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/IN/IN_deer_harmonized_county_year_2005-2016.dta", replace

log close
