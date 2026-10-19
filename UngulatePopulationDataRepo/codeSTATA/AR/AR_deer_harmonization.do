/*==============================================================================

FILE NAME:   AR_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  Arkansas (AR) county-level deer HARVEST harmonization.
          Two source workbooks: (1) a wide county-by-year total-harvest
          table, 75 counties x 1988-2014, with static habitat/area
          columns and a derived harvest-per-square-mile (HPSM) block;
          (2) a STATEWIDE-ONLY harvest table by hunt method (archery/
          crossbow/muzzleloader/modern firearm) x buck/doe, 1970-2014.

          Per the NC precedent (statewide-only sex/age detail not
          imported), the statewide sex/method workbook is NOT merged into
          the county panel -- county-level harvest is total-only, so the
          panel carries harvest_total alone. The statewide file is
          imported here solely to reconcile county sums against the
          state's own grand-total series (Section 4). No population file
          of any kind was provided for AR (IN/TN-style absence by data
          availability, not an exclusion call -- see Section 5).

          YEAR-ALIGNMENT (1988-1990) -- RESOLVED: source year labels
          KEPT, no shift. Pre-code audit found that the county file's
          first three year columns reconcile EXACTLY with the statewide
          grand totals of the PRECEDING year label:

              county col 1988 sums to 106,392 = statewide 1987 total
              county col 1989 sums to 110,207 = statewide 1988 total
              county col 1990 sums to 113,079 = statewide 1989 total

          while no county column sums anywhere near the statewide 1990
          total (90,910). From 1991 on, the two series reconcile exactly
          in 13 of the 24 remaining years and within 4.5% in every other
          year except 2007-08 (see Section 4).
	  
          So one of the two files carries a one-year label offset at the
          head of the series. Decision: treat the COUNTY file as the
          reliable series and keep its labels (1988-2014, balanced, no
          gap). The statewide file has several documented errors (garbled
          1971 row, 1990 method components off by 9, implausibly low
          2007-08 doe columns -- see STATEWIDE-FILE ANOMALIES below),
          while the county file passes every internal check (acreage and
          HPSM identities exact; no missing, zero, or non-integer cells),
          so the offset is attributed to the statewide file. A shift of
          1988-1990 back one year was tried in an earlier version and
          removed.
	  
          Follow-up for AR Game & Fish Comission: confirm the county file's 
	  year labels (see Section 5).

          SEASON-YEAR CONVENTION: both files label seasons with a single year. 
	  Arkansas deer seasons span the turn of the year (roughly Sep-Feb), so 
	  the label is presumed to be the season-START year per project 
	  convention. NOT independently confirmed against AGFC documentation -- 
	  same caveat as TN/DE.

          STATIC COVARIATES & DERIVED COLUMNS: the county file carries four 
	  static columns (deer-habitat acres, non-habitat acres, total acres, 
	  total square miles) and 27 "HPSM <year>" columns. The acreage 
	  identities (habitat + non-habitat = total; sq miles = acres/640) and 
	  the HPSM identity (HPSM = harvest / TOTAL square miles -- total, not 
	  habitat, unlike VA's per-habitat-mile index) were verified exact in 
	  audit and are re-verified at import. The four static columns are KEPT 
	  asctime-invariant county covariates; the HPSM block is DROPPED after 
	  verification as purely derived (reconstructable as harvest_total / 
	  sqmi_total).

          DUPLICATE COPIES: each workbook arrived in three copies (base,
          "...1", and a Dropbox "conflicted copy 20160516"). All three
          copies of each family were verified CELL-IDENTICAL in audit
          (checksums differ only via file metadata); the base-named copy
          is used and the others are ignored.

          STATEWIDE-FILE ANOMALIES (the file is used only for reconciliation, 
	  via its grand-total column):
	  
            1. The 1971 row is internally garbled: modern-firearm
               buck/doe (2,419 + 5,486) do not remotely sum to the
               reported method total (24,681), and the total buck/doe
               split (24,219 / 501) is inconsistent with the method
               components -- digit-drop typos in the source's typeset
               table, by the look of it. Outside the county panel's
               range; noted for the record.
	       
            2. The 1990 modern-firearm components sum to 70,498 against
               a reported 70,489 (-9), which propagates to the grand
               total. Retained as reported.
	       
            3. The 2007 and 2008 doe columns are implausibly low
               (11,997 and 31,970 statewide, vs. 82,740-107,247 in every
               adjacent year), so those years' grand totals are likely
               understated -- which is exactly where the county-vs-state
               reconciliation blows up (+51,537 and +45,267). The COUNTY
               file looks right in those years (its sums sit smoothly
               between 2006 and 2009); the statewide file does not.

          COSMETIC: the county workbook's title row says "(1988-2013)"
          but the sheet carries a 2014 column with full data -- stale
          title, ignored.

SOURCE FILES USED:

  AR.Harvest.1988-2014.County.Gray.xls          (county panel spine)
  AR.Harvest.1970-2014.StateSexSeason.Gray.xls  (reconciliation only)
  
  PROVENANCE [open]: "Gray" in the filenames is a surname only. Presumed
    AGFC; institutional affiliation not confirmed.
    
  Ignored as verified byte-content duplicates:
    AR.Harvest.19882014.County.Gray1.xls
    AR.Harvest.19882014.County.Gray temp's MacBook_s conflicted copy 20160516.xls
    AR.Harvest.19702014.StateSexSeason.Gray1.xls
    AR.Harvest.19702014.StateSexSeason.Gray temp's MacBook_s conflicted copy 20160516.xls
    
  No population file provided for AR.

CHANGELOG:

08/28/2026 — Nicole: First pass. Harvest-only panel (harvest_total plus
                     four static habitat/area covariates), 75 counties x
                     1988-2014 (2,025 rows, fully balanced -- no absent
                     counties, no zero cells, all integers). Static FIPS
                     crosswalk (state FIPS 05, alphabetical 001-149 by
                     2s; St. Francis alphabetized by Census as "Saint",
                     hence 05123 between Randolph and Saline -- the AR
                     analog of TN's McMinn note). All 75 source names
                     match Census spellings exactly. County-vs-state
                     reconciliation and the 1988-1990 year-alignment
                     [DECIDE] documented in Section 4.

09/15/2026 — Nicole: Year labels are kept as in the county source
                     (1988-2014, balanced, no 1990 gap); the county file
                     is treated as the reliable series and the offset
                     against the statewide file is attributed to that
                     file's errors (see header YEAR-ALIGNMENT). 
                     Cleanup in this pass: header, Section 4-6 comments, and 
		     labels updated; variable/data labels shortened to Stata's 
		     80-char limit (earlier labels were truncated in the saved 
		     .dta), long-form notes moved to -notes-; FIPS crosswalk 
		     verified against the Census 2020 county list (75/75); 
		     final checks consolidated.

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
log using "$codeSTATA/logs/AR_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/AR"
cap mkdir "$dataCLEAN/AR"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

No source file carries a FIPS code -- county name only. Built here as a
static reference table (state FIPS 05, 75 counties, alphabetical
numbering 001-149 by 2s). One ordering quirk, same class as TN's
McMinn/McNairy note: the Census alphabetizes "St. Francis" as "Saint
Francis", so it takes code 05123 between Randolph (05121) and Saline
(05125), not a strict-ASCII "St" position after Sharp. No independent
cities, no renamed/split counties in the panel window.

VERIFIED 09/15/2026: all 75 name/code pairs match the Census 2020 county
FIPS reference list exactly (no mismatches, no missing codes)
https://www2.census.gov/geo/docs/reference/codes2020/cou/st05_ar_cou2020.txt

------------------------------------------------------------------------*/

input str20 county_name str3 fips_suffix
"Arkansas"      "001"
"Ashley"        "003"
"Baxter"        "005"
"Benton"        "007"
"Boone"         "009"
"Bradley"       "011"
"Calhoun"       "013"
"Carroll"       "015"
"Chicot"        "017"
"Clark"         "019"
"Clay"          "021"
"Cleburne"      "023"
"Cleveland"     "025"
"Columbia"      "027"
"Conway"        "029"
"Craighead"     "031"
"Crawford"      "033"
"Crittenden"    "035"
"Cross"         "037"
"Dallas"        "039"
"Desha"         "041"
"Drew"          "043"
"Faulkner"      "045"
"Franklin"      "047"
"Fulton"        "049"
"Garland"       "051"
"Grant"         "053"
"Greene"        "055"
"Hempstead"     "057"
"Hot Spring"    "059"
"Howard"        "061"
"Independence"  "063"
"Izard"         "065"
"Jackson"       "067"
"Jefferson"     "069"
"Johnson"       "071"
"Lafayette"     "073"
"Lawrence"      "075"
"Lee"           "077"
"Lincoln"       "079"
"Little River"  "081"
"Logan"         "083"
"Lonoke"        "085"
"Madison"       "087"
"Marion"        "089"
"Miller"        "091"
"Mississippi"   "093"
"Monroe"        "095"
"Montgomery"    "097"
"Nevada"        "099"
"Newton"        "101"
"Ouachita"      "103"
"Perry"         "105"
"Phillips"      "107"
"Pike"          "109"
"Poinsett"      "111"
"Polk"          "113"
"Pope"          "115"
"Prairie"       "117"
"Pulaski"       "119"
"Randolph"      "121"
"St. Francis"   "123"
"Saline"        "125"
"Scott"         "127"
"Searcy"        "129"
"Sebastian"     "131"
"Sevier"        "133"
"Sharp"         "135"
"Stone"         "137"
"Union"         "139"
"Van Buren"     "141"
"Washington"    "143"
"White"         "145"
"Woodruff"      "147"
"Yell"          "149"
end

gen county_fips = "05" + fips_suffix
gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 75

label variable county_fips "AR county FIPS code (5-digit, state+county)"
label variable county_name "County name (Census spelling)"
label variable name_clean  "Merge key: county_name upper-cased, trimmed, periods/spaces removed"
label data "AR county FIPS crosswalk, 75 units (static reference, state FIPS 05)"

save "$dataSTATA/AR/AR_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import County File, Verify, Reshape
*==============================================================================

/*------------------------------------------------------------------------

Wide county-by-year layout: title row, blank row, header row (row 3),
then 75 county rows (Excel rows 4-78), no footer/total row to strip.
Columns: A county name; B-E static habitat/area; F-AF total harvest
1988-2014 (27 columns); AG-BG derived HPSM 1988-2014 (27 columns).
Imported without firstrow (year headers are numeric and would not
survive as variable names) and renamed by position.

------------------------------------------------------------------------*/

import excel "$dataRAW/Deer_Harvest/AR/AR.Harvest.1988-2014.County.Gray.xls", ///
    sheet("Sheet1") cellrange(A4:BG78) clear

count
assert r(N) == 75

rename A county_name
rename B acres_deer_habitat
rename C acres_nondeer_habitat
rename D acres_total
rename E sqmi_total

* Harvest columns F..AF -> harvest1988..harvest2014
local y = 1988
foreach v of varlist F-AF {
    rename `v' harvest`y'
    local ++y
}
assert `y' == 2015

* Derived HPSM columns AG..BG -> hpsm1988..hpsm2014
local y = 1988
foreach v of varlist AG-BG {
    rename `v' hpsm`y'
    local ++y
}
assert `y' == 2015

*-------- 2a. Verify acreage identities --------------------------------------

* habitat + non-habitat acres == total acres; sq miles == acres / 640.
* Audit found both hold EXACTLY for all 75 rows; re-verified here to a
* float tolerance.
gen double _acr = acres_deer_habitat + acres_nondeer_habitat - acres_total
gen double _sqm = sqmi_total - acres_total/640
assert abs(_acr) < 1e-6
assert abs(_sqm) < 1e-6
drop _acr _sqm

*-------- 2b. Verify and drop derived HPSM columns ---------------------------

/*
HPSM <year> == harvest<year> / sqmi_total (TOTAL square miles, not deer-habitat 
square miles -- verified in audit; contrast VA, whose 2014 index is per square 
mile of HABITAT). Holds exactly for every county-year. Being purely derived 
from two columns the panel already carries, the 27 HPSM columns are dropped 
after verification rather than reshaped into the panel. Reconstructable at any 
time as harvest_total / sqmi_total.
*/

forvalues y = 1988/2014 {
    assert abs(hpsm`y' - harvest`y'/sqmi_total) < 1e-6
}
drop hpsm*

*-------- 2c. Harvest cell checks (no missing/zero/non-integer) --------------

* Audit: no missing cells, no zeros, no negatives, all integers, in any
* of the 75 x 27 harvest cells. Re-verified here. (A future refresh that
* introduces a genuine zero or gap will trip these asserts and should be
* documented)
forvalues y = 1988/2014 {
    assert harvest`y' < .
    assert harvest`y' > 0
    assert harvest`y' == round(harvest`y')
}

*-------- 2d. Merge FIPS from crosswalk --------------------------------------

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge 1:1 name_clean using "$dataSTATA/AR/AR_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name if _merge_xwalk != 3
* Expected here: nothing -- audit found a perfect 75/75 name match, so
* the merge must be all-matched in both directions.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

*-------- 2e. Reshape long ---------------------------------------------------

reshape long harvest, i(county_fips) j(year)
rename harvest harvest_total

isid county_fips year
count
assert r(N) == 75 * 27
assert year >= 1988 & year <= 2014
codebook county_fips, compact

save "$dataSTATA/AR/temp_AR_harvest_1988-2014.dta", replace

*==============================================================================
* SECTION 3: STATEWIDE SEX/METHOD FILE - Import (reconciliation only)
*==============================================================================

/*------------------------------------------------------------------------

AR.Harvest.19702014.StateSexSeason.Gray.xls: one statewide row per year,
1970-2014, harvest by hunt method (archery / crossbow / muzzleloader /
modern firearm) x buck/doe/total, plus overall buck/doe/grand-total.
STATEWIDE ONLY -- no county dimension -- so per the NC precedent this
detail is NOT imported into the county panel. Imported here for one
purpose: the grand-total column (P) anchors the county-sum
reconciliation in Section 4.

Layout: title row, method-band row, header row, then 45 year rows
(Excel rows 4-48). Early-year crossbow/muzzleloader cells hold "-"
(method not yet offered/tracked), which forces those columns to string
on import; only YEAR (A) and GRAND TOTAL (P) are needed and both are
fully numeric. Internal anomalies (garbled 1971 row; 1990 off by -9;
implausible 2007-08 doe columns) are documented in the header and left
as reported.

------------------------------------------------------------------------*/

import excel "$dataRAW/Deer_Harvest/AR/AR.Harvest.1970-2014.StateSexSeason.Gray.xls", ///
    sheet("Sheet1") cellrange(A4:P48) clear

count
assert r(N) == 45

rename A year
rename P state_grand_total
keep year state_grand_total

destring year state_grand_total, replace
assert year < . & state_grand_total < .
isid year
assert year >= 1970 & year <= 2014

* Spot-anchor the audited statewide totals used in the Section 4 reconciliation:
assert state_grand_total == 106392 if year == 1987
assert state_grand_total == 110207 if year == 1988
assert state_grand_total == 113079 if year == 1989
assert state_grand_total ==  90910 if year == 1990
assert state_grand_total == 208075 if year == 2014

label variable year              "Season year, as labeled in source (presumed season-start)"
label variable state_grand_total "Statewide deer harvest grand total, all methods/sexes (source-reported)"

save "$dataSTATA/AR/temp_AR_statewide_totals_1970-2014.dta", replace

*==============================================================================
* SECTION 4: RECONCILIATION - County Sums vs. Statewide Grand Totals
*==============================================================================

/*------------------------------------------------------------------------

County-year sums vs. statewide grand totals (diff = county_sum -
state_grand_total; percentages are relative to the statewide total).
The asserts below record the pattern exactly as found:

  EXACT (diff = 0), 13 years:  1991-1999, 2001, 2012, 2013, 2014
  
  Off by +1:                   2011
  
  Small (<1%):                 2000 (-71), 2003 (-794), 2004 (-1,065),
                               2009 (+1,261)
			       
  Moderate (1.7-4.3%):         2002 (+5,147), 2005 (+2,220),
                               2006 (+2,898), 2010 (+5,937)
			       
  LARGE:                       2007 (+51,537), 2008 (+45,267)
                               -- the STATEWIDE file's doe columns are
                               implausibly low in exactly these two
                               years (see header), so the statewide
                               totals are the suspect series there,
                               not the county file.
			       
  SHIFTED HEAD, 3 years:       county col 1988 sum = statewide 1987 total
                               county col 1989 sum = statewide 1988 total
                               county col 1990 sum = statewide 1989 total
                               (all EXACT; no county column matches
                               statewide 1990's 90,910)

Resolution (see header YEAR-ALIGNMENT): the county file is treated as
the reliable series and its year labels are kept -- no shift. The
shifted-head and 2007-08 asserts stay in place as a record of where the
statewide file disagrees.

------------------------------------------------------------------------*/

use "$dataSTATA/AR/temp_AR_harvest_1988-2014.dta", clear

preserve
    collapse (sum) county_sum = harvest_total, by(year)
    merge 1:1 year using "$dataSTATA/AR/temp_AR_statewide_totals_1970-2014.dta", ///
        keep(match) nogen
    gen diff = county_sum - state_grand_total

    * Full table into the log, for the record:
    list year county_sum state_grand_total diff, sep(0) noobs

    * Exact years:
    assert diff == 0 if (year >= 1991 & year <= 1999) | year == 2001 ///
        | (year >= 2012 & year <= 2014)
    assert diff == 1 if year == 2011

    * The shifted head -- county col <y> reconciles to statewide <y-1>:
    assert county_sum == 106392 if year == 1988   // = statewide 1987
    assert county_sum == 110207 if year == 1989   // = statewide 1988
    assert county_sum == 113079 if year == 1990   // = statewide 1989

    * The two big 2007-08 gaps (statewide-file doe anomaly years):
    assert diff ==  51537 if year == 2007
    assert diff ==  45267 if year == 2008

    * Everything else stays within +/-6,000 head:
    assert abs(diff) <= 6000 if !inlist(year, 1988, 1989, 1990, 2007, 2008)
restore

*==============================================================================
* SECTION 5: POPULATION DATA - no source file provided
*==============================================================================

/*------------------------------------------------------------------------

Same case as IN/TN: no population file of any kind was provided
alongside the two AR harvest workbooks. Data-availability gap (The static 
deer-habitat acreage in Section 2 is a land covariate, not a population 
measure).

FOLLOW-UP for the next AR agency (AGFC) contact:
  1. Does AGFC have a county- or zone-level deer population estimate for
     any part of 1988-2014?
  2. Confirm the county file's year labels: its columns labeled
     1988-1990 match the statewide file's 1987-1989 totals exactly. The
     panel keeps the county labels (header YEAR-ALIGNMENT); if AGFC says
     otherwise, revisit.

------------------------------------------------------------------------*/

*==============================================================================
* SECTION 6: FINALIZE HARVEST-ONLY PANEL
*==============================================================================

use "$dataSTATA/AR/temp_AR_harvest_1988-2014.dta", clear

* Year labels are kept exactly as in the county source file (1988-2014),
* with no shift -- see header YEAR-ALIGNMENT and Section 4.

*-------- 6a. Order, labels, notes -------------------------------------------

order county_fips county_name year harvest_total ///
    acres_deer_habitat acres_nondeer_habitat acres_total sqmi_total

* Stata caps variable and data labels at 80 characters -- keep them short;
* long-form documentation goes in -notes- (saved in the .dta; type -notes-).
label variable county_fips           "AR county FIPS code (5-digit string, state+county)"
label variable county_name           "County name, as reported in source (matches Census)"
label variable year                  "Season year as labeled in county source (presumed season-start)"
label variable harvest_total         "Total deer harvest, all methods/sexes (county file is total-only)"
label variable acres_deer_habitat    "Deer habitat acres (static, source-reported)"
label variable acres_nondeer_habitat "Non-deer-habitat acres (static, source-reported)"
label variable acres_total           "Total acres (static; = habitat + non-habitat)"
label variable sqmi_total            "Total square miles (static; = acres_total/640)"
label data "AR county-year deer harvest, 75 counties x 1988-2014, balanced"

notes year: Year labels kept as in the county source file (1988-2014, no shift). County columns labeled 1988-1990 sum exactly to the statewide file's 1987-1989 grand totals; given the statewide file's other documented errors, the county file is treated as the reliable series and the offset is attributed to the statewide file (do-file header and Section 4). Season label presumed to be the season-start year; not confirmed against AGFC documentation.
notes harvest_total: AR county file reports totals only; no county-level sex or hunt-method split exists. The statewide sex/method file was used only to reconcile county sums (Section 4), not imported (NC precedent).
notes: Harvest-only panel. No population source file was provided for AR (data-availability gap, not a scope exclusion; see Section 5).
notes: Derived HPSM columns (harvest per TOTAL square mile) were verified and dropped; reconstruct as harvest_total / sqmi_total.

*-------- 6b. Final checks and save ------------------------------------------

isid county_fips year
assert inrange(year, 1988, 2014)
quietly tabulate year
assert r(r) == 27
assert harvest_total > 0 & harvest_total < .
count
assert r(N) == 75 * 27
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/AR/AR_deer_harmonized_county_year_1988-2014.dta", replace

log close
