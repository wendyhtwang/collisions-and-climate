/*==============================================================================

FILE NAME:   CA_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  California (CA) county-level deer HARVEST harmonization, adapted
          from the VA/WI/OH/NC/MO/MD/KY pilot scripts. 
	  
	  First pass (see changelog 08/13) worked from a typeset CDFW report 
	  (TABLE 5g Buck Kill, TABLE 5h Doe Kill) supplied only as .docx/.pdf. 
	  A cleaned xlsx workbook (two sheets, "buck harvest 1927-2009" and 
	  "doe harvest 1949 - 2009") surfaced afterward and is now the primary 
	  import source -- validated cell-by-cell against the docx extraction 
	  (see 08/14 changelog): doe matched perfectly (all 3,538 cells), 
	  buck matched for every overlapping cell (1927-2008) but the xlsx 
	  workbook is MISSING 2009 ENTIRELY for buck kill (not blank -- the 
	  column doesn't exist). 2009 buck is appended from the docx extraction 
	  rather than dropped -- see Section 2a. 
	  
	  Harvest here splits by SEX rather than by land ownership (VA) or 
	  method (WI): Buck Kill (excludes PLM kill, 1927-2009) and Doe Kill
          (INCLUDES PLM kill, 1949-2009, >75% blank cells -- doe harvest
          is tightly restricted in CA, this is a real sparsity pattern,
          not a parsing gap, see Section 2 QC). 
	  
	  CA's population source (CA_Pop_2010-15_Zone_Web.pdf) is reported by 
	  CDFW deer assessment ZONE (A, B-1...B-6, C-1...C-4, D-3...D-19,
          X-1...X-12), not county and not state-level -- the same
          geography problem WI's DMU population hit (Section 2c there),
          but here with no crosswalk file provided at all. Per that WI
          precedent, excluded from the panel rather than guessed at --
          see Section 3. This script therefore produces a HARVEST-ONLY
          county-year panel, like KY, but with two harvest variables
          (harvest_buck, harvest_doe_plm) that are NOT inherently directly
          summable to a single "total" because of the PLM-kill
          asymmetry.

SOURCE FILES USED:

  CA.Harvest.1927-09.CountySex.Web.xlsx        -- PRIMARY harvest source.
                                                 Sheet "buck harvest
                                                 1927-2009" (actually only
                                                 1927-2008, see above) and
                                                 sheet "doe harvest 1949 -
                                                 2009" (full range, incl.
                                                 PLM kill).
						 
  CA.Harvest.BuckKill.2009only.DocxExtract.csv -- SUPPLEMENTARY. The 58
                                                 county-level 2009 buck
                                                 kill values, sourced from
                                                 the docx/PDF report
                                                 (TABLE 5g) since the xlsx
                                                 above doesn't carry 2009
                                                 at all. Appended onto the
                                                 xlsx-derived buck panel
                                                 in Section 2a.
						 
  CA.Harvest.BuckKill.StatewideTotals.1927-2009.DocxExtract.csv   -- QC only
  
  CA.Harvest.DoeKillPLM.StatewideTotals.1949-2009.DocxExtract.csv -- QC only
  
  (both QC files and the 2009-only supplement come from the same run described 
  in the changelog below; the full county-level CSVs that script also 
  produces are no longer imported directly now that the xlsx is available, but 
  are kept as the validation record -- see 08/13 changelog.)

SOURCE FILES REVIEWED BUT NOT HARMONIZED HERE (see Section 3):

  CA_Pop_2010-15_Zone_Web.pdf  -- deer population by CDFW zone, 2010-2015.
                                   Not county-level, no zone->county
                                   crosswalk available. EXCLUDED (decision
                                   08/13, Section 3). Follow-up: ask CDFW
                                   for zone boundary shapefiles.

CHANGELOG:

08/13/2026 — Nicole: First pass adapting the KY harvest-only pattern to CA.
                     Ran CA_docx_table_extract.py to pull the report's
                     Word tables into long CSVs (pre-code audit step,
                     docx-flavored since there's no workbook to inspect).
                     Harvest harmonized as two separate sex-specific
                     variables per the source's own Buck/Doe split;
                     population excluded per the WI DMU zone-geography
                     precedent. Several [DECIDE] flags left open -- see
                     Sections 2 and 3.

08/14/2026 — Nicole: A cleaned xlsx workbook of the same report surfaced
                     after the first pass. Validated it cell-by-cell
                     against the 08/13 docx extraction: doe kill matched
                     exactly (3,538/3,538 cells); buck kill matched on
                     every cell for 1927-2008 (4,756/4,756) but the xlsx
                     has no 2009 column at all for buck. Switched Section
                     2 to import directly from the xlsx (matches the
                     project's usual single-clean-source pattern) and
                     append the missing 2009 buck values from the docx
                     extraction -- rather than silently truncating the buck
                     series at 2008 or leaving it entirely docx-sourced.
                     Crosswalk (Section 1) and population exclusion (Section
                     3) unchanged from the first pass.

09/15/2026 — Nicole: Cleanup pass, no change to data values. Expectations
                     that were only comments are now asserts: statewide
                     reconciliation (buck diffs only 1995-97; doe all
                     zero), crosswalk merges all-matched, buck/doe merge
                     gap exactly 1927-1948, blank-cell counts (buck 34,
                     doe 2,683). Added a pre-destring check that lists any
                     non-numeric text cells. FIPS crosswalk verified
                     against the Census 2020 county list (58/58). Labels
                     shortened to Stata's 80-char limit (earlier labels
                     were truncated in the saved .dta), long-form
                     documentation moved to -notes-. Non-decision
                     [DECIDE] tags reworded as notes.

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
log using "$codeSTATA/logs/CA_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/CA"
cap mkdir "$dataCLEAN/CA"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

Like OH/NC/MO/MD/KY, no CA source file carries a FIPS code -- both
harvest tables have county name only. Built here as a static reference
table (state FIPS 06, 58 counties, clean alphabetical numbering 001-115
by 2s -- no out-of-sequence carve-outs the way WI has Menominee).

Typed from standard Census county FIPS assignments. VERIFIED 09/15/2026: all 
58 name/code pairs match the Census 2020 county FIPS reference list exactly 
(Los Angeles = 06037; no mismatches, no missing codes)
https://www2.census.gov/geo/docs/reference/codes2020/cou/st06_ca_cou2020.txt

------------------------------------------------------------------------*/

input str20 county_name str3 fips_suffix
"Alameda"        "001"
"Alpine"         "003"
"Amador"         "005"
"Butte"          "007"
"Calaveras"      "009"
"Colusa"         "011"
"Contra Costa"   "013"
"Del Norte"      "015"
"El Dorado"      "017"
"Fresno"         "019"
"Glenn"          "021"
"Humboldt"       "023"
"Imperial"       "025"
"Inyo"           "027"
"Kern"           "029"
"Kings"          "031"
"Lake"           "033"
"Lassen"         "035"
"Los Angeles"    "037"
"Madera"         "039"
"Marin"          "041"
"Mariposa"       "043"
"Mendocino"      "045"
"Merced"         "047"
"Modoc"          "049"
"Mono"           "051"
"Monterey"       "053"
"Napa"           "055"
"Nevada"         "057"
"Orange"         "059"
"Placer"         "061"
"Plumas"         "063"
"Riverside"      "065"
"Sacramento"     "067"
"San Benito"     "069"
"San Bernardino" "071"
"San Diego"      "073"
"San Francisco"  "075"
"San Joaquin"    "077"
"San Luis Obispo" "079"
"San Mateo"      "081"
"Santa Barbara"  "083"
"Santa Clara"    "085"
"Santa Cruz"     "087"
"Shasta"         "089"
"Sierra"         "091"
"Siskiyou"       "093"
"Solano"         "095"
"Sonoma"         "097"
"Stanislaus"     "099"
"Sutter"         "101"
"Tehama"         "103"
"Trinity"        "105"
"Tulare"         "107"
"Tuolumne"       "109"
"Ventura"        "111"
"Yolo"           "113"
"Yuba"           "115"
end

gen county_fips = "06" + fips_suffix
drop fips_suffix

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 58

label variable county_fips "CA county FIPS code (5-digit string, state+county)"
label variable county_name "County name (Census spelling)"
label variable name_clean  "Merge key: county_name upper-cased, trimmed, periods/spaces removed"
label data "CA county FIPS crosswalk, 58 counties (static reference, state FIPS 06)"

save "$dataSTATA/CA/CA_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import & Clean
*==============================================================================

/*------------------------------------------------------------------------

Both sheets in the xlsx are wide (county x year), so this needs the same
header-row-becomes-year-locals reshape KY's xlsx sheets used, unlike the
08/13 pass which read already-long CSVs from the docx extraction. Buck
and doe are separate variables (not summed to a "total") because of the
PLM-kill asymmetry documented in Section 2c.

Source note (b) under TABLE 5g/5h: "Blank cells indicate no reported kill for 
the county or the kill was zero." That's a genuine either/or in the source 
itself, not an extraction artifact -- CA's own documentation doesn't 
distinguish "not tracked" from "tracked at zero." Following OH/KY's treatment 
of comparable coverage gaps, blanks are left as MISSING here (not recoded to 0), 
since recoding to 0 would falsely assert "confirmed zero kill" for cells that 
might just be unreported.

Flag: if the first-stage regressions need a hard 0/missing split, this
ambiguity can't be resolved from the source table alone. One pattern
that bears on it: the BUCK table prints explicit zeros (90 cells -- all
83 San Francisco years plus 7 others) alongside 34 blanks (1927-1946
only), while the DOE table contains no zeros at all, only blanks. So
doe blanks very likely include true zeros; buck blanks are rarer and
more ambiguous.

------------------------------------------------------------------------*/

*-------- 2a. Buck kill: xlsx 1927-2008 + docx 2009, QC, FIPS ----------------

* Stash the 2009-only supplement first so it's ready for the `append`
* below -- these 58 rows come from the docx/PDF report (TABLE 5g), not
* the xlsx, since the xlsx's "buck harvest 1927-2009" sheet stops at 2008
* despite its name (see header notes and 08/14 changelog). No preserve
* needed -- the import excel just below clears memory anyway.
import delimited "$dataRAW/Deer_Harvest/CA/CA.Harvest.BuckKill.2009only.DocxExtract.csv", ///
    stringcols(1) varnames(1) clear
isid county_name year
count
assert r(N) == 58
assert year == 2009 in 1/58
save "$dataSTATA/CA/temp_CA_harvest_buck_2009only_docx.dta", replace

import excel "$dataRAW/Deer_Harvest/CA/CA.Harvest.1927-09.CountySex.Web.xlsx", ///
    sheet("buck harvest 1927-2009") cellrange(A1:CE59) clear

rename A county_name
ds county_name, not
local yearvars `r(varlist)'
local yr = 1927
foreach v of local yearvars {
    rename `v' h`yr'
    local yr = `yr' + 1
}
* NOTE: Sheet name says "1927-2009" but it only carries 1927-2008 (CE is
* the last populated column) -- confirmed by inspecting directly, not a 
* cellrange mistake here. 2009 is appended below from the docx/PDF extraction.
assert `yr' - 1 == 2008

drop if county_name == "county"

* destring's -force- would silently turn any text cell (footnote marks,
* dashes) into missing. List any such cells first so they're visible in
* the log; blank cells are fine and stay missing.
foreach v of varlist h* {
    capture confirm string variable `v'
    if !_rc {
        quietly count if strtrim(`v') != "" & missing(real(`v'))
        if r(N) > 0 {
            di as error "`v': " r(N) " non-numeric text cell(s)"
            list county_name `v' if strtrim(`v') != "" & missing(real(`v')), noobs
        }
    }
}
destring h*, replace force
reshape long h, i(county_name) j(year)
rename h harvest_buck

isid county_name year
count
* Expect 58 counties x 82 years (1927-2008) = 4,756
assert r(N) == 4756

* 34 blank cells, all in 1927-1946 (e.g., 13 counties in 1943), kept as
* missing per the Section 2 blank-vs-zero note. Pinned so a refresh that
* changes the count stops here.
count if missing(harvest_buck)
assert r(N) == 34

* Append the 58 county-level 2009 values from the docx/PDF extraction --
* not in the xlsx at all (see note above).
append using "$dataSTATA/CA/temp_CA_harvest_buck_2009only_docx.dta"

isid county_name year
count
* Expect 58 counties x 83 years (1927-2009) = 4,814
assert r(N) == 4814

* QC: county-sum-by-year vs. the report's own STATEWIDE TOTALS row
* (STATEWIDE TOTALS isn't a row in this xlsx -- it's a footer row in the
* original typeset report, sourced from the docx-extraction QC file
* instead, same file used for the 08/13 pass since the reported totals
* themselves are unaffected by which sheet format the county data came
* from).
preserve
    collapse (sum) harvest_buck, by(year)
    tempfile buck_sums
    save `buck_sums'
restore

preserve
    import delimited "$dataRAW/Deer_Harvest/CA/CA.Harvest.BuckKill.StatewideTotals.1927-2009.DocxExtract.csv", ///
        varnames(1) clear
    merge 1:1 year using `buck_sums', gen(_m)
    assert _m == 3                     // all 83 years on both sides
    drop _m
    gen _diff = harvest_buck - harvest_buck_statewide_reported
    list year harvest_buck harvest_buck_statewide_reported _diff if _diff != 0, sep(0)
    * NOTE: nonzero ONLY for 1995 (-30), 1996 (-78), 1997 (-8) -- exactly
    * the "Unknown"-county buck harvest the source reports separately from
    * any named county. Unknown has no FIPS, so it's excluded from the county 
    * panel. Anything else nonzero stops the run.
    assert _diff == 0   if !inlist(year, 1995, 1996, 1997)
    assert _diff == -30 if year == 1995
    assert _diff == -78 if year == 1996
    assert _diff == -8  if year == 1997
restore

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/CA/CA_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* All 58 buck-kill county names match the crosswalk cleanly (no casing/
* typo issues the way KY had LaRue/Larue; the one misspelling is on the
* DOE side, 2b) -- so every row must match, in both directions.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

isid county_fips year
count
codebook county_fips, compact

save "$dataSTATA/CA/temp_CA_harvest_buck_1927-2009.dta", replace

*-------- 2b. Doe kill (incl. PLM): xlsx 1949-2009, QC, FIPS -----------------

import excel "$dataRAW/Deer_Harvest/CA/CA.Harvest.1927-09.CountySex.Web.xlsx", ///
    sheet("doe harvest 1949 - 2009") cellrange(A1:BJ59) clear

rename A county_name
ds county_name, not
local yearvars `r(varlist)'
local yr = 1949
foreach v of local yearvars {
    rename `v' h`yr'
    local yr = `yr' + 1
}
* Unlike buck, this sheet's name matches its actual coverage exactly.
assert `yr' - 1 == 2009

drop if county_name == "county"

* Same text-cell check as 2a before destring's -force-.
foreach v of varlist h* {
    capture confirm string variable `v'
    if !_rc {
        quietly count if strtrim(`v') != "" & missing(real(`v'))
        if r(N) > 0 {
            di as error "`v': " r(N) " non-numeric text cell(s)"
            list county_name `v' if strtrim(`v') != "" & missing(real(`v')), noobs
        }
    }
}
destring h*, replace force
reshape long h, i(county_name) j(year)
rename h harvest_doe_plm

* Source typo: TABLE 5h spells this county "San Luis Obisbo" throughout
* (missing the second "p"), vs. "San Luis Obispo" everywhere in TABLE 5g
* and in the crosswalk -- confirmed the typo persists unchanged in this
* xlsx too (not something introduced by the docx extraction). Confirmed
* on inspection this is the ONLY name mismatch between the two tables
* (all other 57 names match exactly) -- not caught by name_clean's
* uppercase/trim/punctuation stripping below, since it's a genuine
* misspelling, not a casing or whitespace issue. Fixed explicitly here
* rather than silently, same spirit as KY's LaRue/Larue note.
replace county_name = "San Luis Obispo" if county_name == "San Luis Obisbo"

isid county_name year
count
* Expect 58 counties x 61 years (1949-2009) = 3,538
assert r(N) == 3538

* NOTE: 2,683 of 3,538 cells (75.8%) are blank -- confirmed by direct
* inspection of the source table, not a parsing failure. Doe harvest is
* tightly restricted in CA (special-permit/PLM take only in most counties
* most years), so this sparsity is a real feature of the data. Every year
* 1949-2009 has at least one reporting county. See the Section 2 blank-vs-zero.
count if missing(harvest_doe_plm)
assert r(N) == 2683

* QC: county-sum-by-year vs. the report's own STATEWIDE TOTALS row
preserve
    collapse (sum) harvest_doe_plm, by(year)
    tempfile doe_sums
    save `doe_sums'
restore

preserve
    import delimited "$dataRAW/Deer_Harvest/CA/CA.Harvest.DoeKillPLM.StatewideTotals.1949-2009.DocxExtract.csv", ///
        varnames(1) clear
    * Normalize to doe_plm_statewide_reported regardless of which header 
    * version is on disk. The original column name
    * (harvest_doe_plm_statewide_reported, 34 chars) exceeds Stata's
    * 32-char variable name limit, so import delimited mangles it to
    * something else rather than erroring -- `capture` here means this
    * is a no-op if the shortened-header CSV is already in place.
    capture confirm variable doe_plm_statewide_reported
    if _rc {
        ds year, not
        local oldname `r(varlist)'
        rename `oldname' doe_plm_statewide_reported
    }
    merge 1:1 year using `doe_sums', gen(_m)
    assert _m == 3                     // all 61 years on both sides
    drop _m
    gen _diff = harvest_doe_plm - doe_plm_statewide_reported
    list year harvest_doe_plm doe_plm_statewide_reported _diff if _diff != 0, sep(0)
    * Unlike buck kill, TABLE 5h has no separate "Unknown" row to account
    * for, so county sums tie out exactly in every year.
    assert _diff == 0
restore

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/CA/CA_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* Every row must match now that the San Luis Obisbo/Obispo fix above has
* run.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

isid county_fips year
count
codebook county_fips, compact

save "$dataSTATA/CA/temp_CA_harvest_doe_1949-2009.dta", replace

*-------- 2c. Combine buck + doe, labels -------------------------------------

use "$dataSTATA/CA/temp_CA_harvest_buck_1927-2009.dta", clear
merge 1:1 county_fips year using "$dataSTATA/CA/temp_CA_harvest_doe_1949-2009.dta", ///
    keepusing(harvest_doe_plm) gen(_merge_doe)
* Buck-only rows must be exactly 1927-1948, before the doe table's
* coverage begins (mirrors KY's harvest_buck gap), and there must be no
* doe-only rows.
assert _merge_doe != 2
assert (_merge_doe == 1) == (year < 1949)
drop _merge_doe

/*------------------------------------------------------------------------

harvest_buck EXCLUDES PLM (Private Lands Management) kill per TABLE 5g note (a); 
harvest_doe_plm INCLUDES it per TABLE 5h's title. That means harvest_buck + 
harvest_doe_plm is NOT a clean "total deer harvest" the way KY's harvest_total 
was -- it would silently mix a PLM-exclusive and a PLM-inclusive series. NOT 
summed here for that reason. Left as two separately-labeled variables.

------------------------------------------------------------------------*/

* Labels capped at 80 chars by Stata; long-form documentation is attached
* as -notes- in Section 4.
label variable county_fips     "CA county FIPS code (5-digit string, state+county)"
label variable county_name     "County name (Census spelling; source typo Obisbo fixed)"
label variable year            "Harvest year"
label variable harvest_buck    "Buck harvest, EXCLUDES PLM kill (CDFW Table 5g), 1927-2009"
label variable harvest_doe_plm "Doe harvest, INCLUDES PLM kill (CDFW Table 5h), 1949-2009; sparse"
label data "CA harvest temp: buck + doe, not summed (see Section 2c [DECIDE])"

order county_fips county_name year harvest_buck harvest_doe_plm

isid county_fips year
count
codebook county_fips, compact
describe

save "$dataSTATA/CA/temp_CA_harvest_1927-2009_raw.dta", replace

*==============================================================================
* SECTION 3: POPULATION DATA - excluded, not imported
*==============================================================================

/*------------------------------------------------------------------------

CA_Pop_2010-15_Zone_Web.pdf reports estimated deer numbers by CDFW deer
ASSESSMENT ZONE (A; B-1 through B-6; C-1 through C-4; D-3 through D-19;
X-1 through X-12 -- roughly 45 zones), one page per year, 2010-2015. This
is WI's DMU-vs-county problem again (see WI Section 2c) but without even WI's 
partial fix: WI eventually found a DMU-to-county mapping for its NEW DMU system 
(WI Section 2a-i/2a-ii); no equivalent zone-to-county crosswalk was provided or 
found for CA's zones, and CDFW deer assessment zones are known to span multiple 
counties by design (they follow habitat/management boundaries, not political 
ones), so a simple name-based or centroid-based crosswalk isn't a safe 
assumption -- this needs an actual authoritative zone-boundary shapefile, not 
typed-in guesswork.

Leaving the zone-level series out of the county panel entirely for now, 
following the WI precedent -- raw PDF untouched on disk, not extracted or 
imported anywhere in this script. FOLLOW-UP (CDFW outreach): ask whether CDFW
publishes deer assessment zone boundary shapefiles -- would allow an
area-weighted county allocation, extending CA population coverage to
2010-2015 -- before writing this off entirely, same spirit as WI's
1981-2013 old-DMU population note.

------------------------------------------------------------------------*/

*==============================================================================
* SECTION 4: FINALIZE HARVEST-ONLY PANEL
*==============================================================================

/*------------------------------------------------------------------------

No population to merge in (Section 3), so the harvest panel from Section
2 IS the final panel -- this section just re-confirms integrity and saves
to dataCLEAN under the same naming convention the other states use.

Two items carried forward from Section 2:

  1. harvest_buck/harvest_doe_plm PLM-treatment asymmetry (2c) -- not
     summed to a total here.
     
  2. Blank-vs-zero ambiguity in the source's own note (b) -- left as
     missing throughout, not recoded to 0 (2, header note).

------------------------------------------------------------------------*/

use "$dataSTATA/CA/temp_CA_harvest_1927-2009_raw.dta", clear

order county_fips county_name year harvest_buck harvest_doe_plm

label data "CA county-year deer harvest (buck excl. PLM; doe incl. PLM), 1927-2009"

notes harvest_buck: Excludes Private Lands Management (PLM) kill per CDFW Table 5g note (a). 1927-2008 from the xlsx workbook; 2009 appended from the docx/PDF report extraction because the workbook has no 2009 buck column. 34 blank source cells (1927-1946) kept as missing; source says blank = no reported kill or kill was zero. County sums match the report statewide totals in every year except 1995-1997, where the gap equals Unknown-county harvest (no FIPS, excluded).
notes harvest_doe_plm: Includes PLM kill per CDFW Table 5h title. Missing 1927-1948 (before table coverage). Within 1949-2009, 2,683 of 3,538 cells (75.8 pct) are blank in the source and kept as missing; the doe table prints no zeros, so blanks likely include true zeros. Not summable with harvest_buck because of the PLM asymmetry (Section 2c).
notes: Harvest-only panel. CDFW deer population estimates (2010-2015) are by deer assessment zone with no zone-to-county crosswalk and are excluded (Section 3). Source: CDFW report Tables 5g and 5h.

isid county_fips year
assert inrange(year, 1927, 2009)
count
assert r(N) == 58 * 83
assert missing(harvest_doe_plm) if year < 1949
assert harvest_buck >= 0 if !missing(harvest_buck)
assert harvest_doe_plm >= 0 if !missing(harvest_doe_plm)
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/CA/CA_deer_harmonized_county_year_1927-2009.dta", replace

log close
