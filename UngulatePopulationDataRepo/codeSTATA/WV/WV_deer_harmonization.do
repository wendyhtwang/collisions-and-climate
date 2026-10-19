/*==============================================================================

FILE NAME:   WV_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  West Virginia (WV) county-level deer HARVEST harmonization.
          A new pattern for this project: every source is a published PDF
          report, not an agency data file. WVDNR does not distribute a
          county-level harvest dataset; the numbers exist only as printed
          tables inside the annual Big Game Bulletin. Four bulletins were
          supplied (2005, 2010, 2015, 2020), each carrying a five-year
          county-by-year block, so the four together tile 2001-2020 with no
          overlap and no gap.

          STRUCTURE. WV reports harvest by METHOD, not by sex/age class: 
	  antlered buck gun, antlerless gun, archery (bow/crossbow),
          and muzzleloader. There is no county-level sex or age breakdown
          for any year (the 2020 bulletin's Table 19 has one, but for 2020
          only and it is not imported, see Section 2e). The panel is
          therefore county-year-METHOD long, following the WI precedent
          (Total/Gun/Bow/XBow) rather than the wide sex-class layout used
          for OH/MO/TN. harvest_method takes six values:

              Total  BuckGun  AntlerlessGun  Bow  Muzzleloader  Unknown

          Total is the component sum. Unknown is populated in 2015 only,
          the same shape as WI's XBow, which exists only from 2014.

          TWO OF THE FOUR BULLETINS ARE IMAGE SCANS. The 2005 bulletin
          (all 20 pages) and pages 30-35 of the 2015 bulletin have no text
          layer, and OCR of the county tables was not reliable enough to
          trust: the tables' heavy horizontal rules overlap the digits of
          the first row of each district block, and on the 2005 pages the
          scan is skewed enough that whole rows drop out. Those eight
          tables were transcribed by hand from the page images and then
          verified arithmetically: every county figure was checked against
          the printed district subtotal and the printed state total for its
          column. All eight tables reconcile exactly on all six districts
          and all five years; nothing was accepted on the strength of the
          transcription alone. The variable source_scanned flags the
          affected rows (2001-2005 and 2011-2015) so the hand-read years
          can be dropped or tested separately downstream.

SOURCE FILES USED:

  2005 WV Big Game Bulletin.pdf        Tables 1/3/5/7, seasons 2001-2005
                                       (image scan; Tables 8 and 9 used for
                                       cross-checks and habitat area)
				       
  2010 WV Big Game Bulletin.pdf        Tables 1/3/5/7, seasons 2006-2010
                                       (text layer; Tables 8/9 likewise)
				       
  2015 WV Big Game Bulletin.pdf        Tables 1/2/3/4, seasons 2011-2015
                                       (image scan; Tables 5/6 likewise)
				       
  2020 WV Big Game Bulletin.pdf        Tables 13-16, seasons 2016-2020
                                       (text layer; Tables 17/18 likewise)
				       
  WV.Harvest.2011-15.CountySex.Web.docx / .pdf
                                       WVDNR compilation. Filename is
                                       misleading: it holds the 2006-2010
                                       harvest tables (identical to the 2010
                                       bulletin. Used here as an
                                       independent check, see Section 2d)
                                       plus kill-per-square-mile tables for
                                       2008-2013, which is the only source
                                       for habitat area in 2008/2009/2011/
                                       2012/2013.
				       
  No population file of any kind was provided or exists for WV. See Section 3.

  Derived inputs actually read by this file:
  
    WV_harvest_by_method_wide.csv
    
    WV_habitat_density.csv
    
    WV_source_reference_totals.csv

CHANGELOG:

09/01/2026 — Nicole: First pass. County-year-method panel, 55 counties x
                     2001-2020 x 6 methods = 6,600 rows, fully balanced.
                     Harvest-only (Section 3). Static FIPS crosswalk (state
                     FIPS 54, 55 counties, 001-109 by 2s, no independent
                     cities, no split/renamed counties), cross-checked
                     against the Census county-code reference list -- note
                     McDowell is 047, ahead of Marion/Marshall, the same
                     Mc-before-Ma ordering that caught us in TN.
                     Row identity (Total == component sum) holds in every
                     row. Statewide sums reproduce every harvest figure
                     WVDNR states in the bulletins' prose: the 2002 record
                     (255,356), the 2005/2010/2015/2020 season totals, the
                     2014 and 2019 comparison figures, and both quoted
                     five-year averages, none of which was used to build
                     the panel. Habitat area and kill per square mile
                     imported for the 9 of 20 years that print them.

09/16/2026 — Nicole: Clean up pass, no change to data values. Fixed an
                     assert that could not fail: -assert bow > 0 if
                     no_firearms_season == 1- passes on a MISSING bow,
                     since missing sorts above every number in Stata; it
                     now requires a real positive value. Documented and
                     pinned the 12 blank kill-per-square-mile cells (the
                     four closed-season counties, buck gun and antlerless
                     gun in 2012 and antlerless gun in 2013), which the
                     Section 4 row-count assert did not catch because the
                     rows merge, they just carry no rate. Added the
                     55-county x 120-row balance check, shortened the data
                     label to Stata's 80-char limit with the long form in
                     -notes-, and sorted the panel before saving.

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
log using "$codeSTATA/logs/WV_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/WV"
cap mkdir "$dataCLEAN/WV"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

Like IN/KY/OH/NC/MO/MD/TN, no source carries a FIPS code; the bulletins
print county names only. Built here as a static reference table (state FIPS
54, 55 counties, clean alphabetical numbering 001-109 by 2s, no independent 
cities, no DMU-style carve-outs, no renamed or split counties in the panel 
period). Spot checked against https://www2.census.gov/geo/docs/reference/codes2020/cou/st54_wv_cou2020.txt

Two things to watch, both survivable but both worth stating:

  (a) McDowell sorts as "Mac", i.e. BEFORE Marion/Marshall/Mason/Mercer,
      giving it 047 rather than a code after Marshall. Same convention that
      forced the seven-code correction in TN (McMinn/McNairy). Verified
      against the Census county-code reference list for WV rather than
      assumed from ASCII order.

  (b) The bulletins group the 55 counties into six WVDNR districts and print
      a subtotal for each. Those subtotals are not a geography we carry
      forward as an analysis unit, but they ARE the arithmetic backbone of
      the QC in Section 2, so district membership is recorded here and kept
      on the final file as `district'.

------------------------------------------------------------------------*/

input str20 county_name str3 fips_suffix byte district
"Barbour"      "001" 1
"Berkeley"     "003" 2
"Boone"        "005" 5
"Braxton"      "007" 3
"Brooke"       "009" 1
"Cabell"       "011" 5
"Calhoun"      "013" 6
"Clay"         "015" 3
"Doddridge"    "017" 6
"Fayette"      "019" 4
"Gilmer"       "021" 6
"Grant"        "023" 2
"Greenbrier"   "025" 4
"Hampshire"    "027" 2
"Hancock"      "029" 1
"Hardy"        "031" 2
"Harrison"     "033" 1
"Jackson"      "035" 6
"Jefferson"    "037" 2
"Kanawha"      "039" 5
"Lewis"        "041" 3
"Lincoln"      "043" 5
"Logan"        "045" 5
"McDowell"     "047" 4
"Marion"       "049" 1
"Marshall"     "051" 1
"Mason"        "053" 5
"Mercer"       "055" 4
"Mineral"      "057" 2
"Mingo"        "059" 5
"Monongalia"   "061" 1
"Monroe"       "063" 4
"Morgan"       "065" 2
"Nicholas"     "067" 3
"Ohio"         "069" 1
"Pendleton"    "071" 2
"Pleasants"    "073" 6
"Pocahontas"   "075" 3
"Preston"      "077" 1
"Putnam"       "079" 5
"Raleigh"      "081" 4
"Randolph"     "083" 3
"Ritchie"      "085" 6
"Roane"        "087" 6
"Summers"      "089" 4
"Taylor"       "091" 1
"Tucker"       "093" 1
"Tyler"        "095" 6
"Upshur"       "097" 3
"Wayne"        "099" 5
"Webster"      "101" 3
"Wetzel"       "103" 1
"Wirt"         "105" 6
"Wood"         "107" 6
"Wyoming"      "109" 4
end

gen county_fips = "54" + fips_suffix
gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 55

* District sizes, as the bulletins print them: 12/8/8/8/9/10.
tab district
assert inrange(district, 1, 6)
foreach pair in "1 12" "2 8" "3 8" "4 8" "5 9" "6 10" {
    local d : word 1 of `pair'
    local n : word 2 of `pair'
    count if district == `d'
    assert r(N) == `n'
}

label variable county_fips "WV county FIPS code (5-digit, state+county)"
label variable county_name "County name (Census spelling; matches bulletin spelling)"
label variable district    "WVDNR district (1-6), as the Big Game Bulletins group counties"
label variable name_clean  "county_name, uppercased/trimmed/period-and-space-stripped -- merge key"
label data "WV county FIPS crosswalk, 55 units (static reference, state FIPS 54)"

save "$dataSTATA/WV/WV_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import, Reshape & QC
*==============================================================================

/*------------------------------------------------------------------------

The printed tables have been turned into WV_harvest_by_method_wide.csv: one row 
per county-year, one column per method, 55 x 20 = 1,100 rows. What is left to do 
here is reshape to long, build the Total row, merge the crosswalk, and run the 
checks.

------------------------------------------------------------------------*/

*--------------------------------- 2a. -----------------------------------

import delimited "$dataRAW/Deer_Harvest/WV/WV_harvest_by_method_wide.csv", ///
    varnames(1) clear stringcols(1)

destring buck_gun antlerless_gun bow muzzleloader unknown_method ///
    no_firearms_season, replace

isid county_name year
count
assert r(N) == 55 * 20

/*
THE FOUR NO-FIREARMS COUNTIES: Logan, McDowell, Mingo and Wyoming
had no firearms deer season anywhere in 2001-2020, they are archery/
crossbow only. The bulletins record this three different ways, which is
exactly the sort of thing that turns into a silent zero-vs-missing error:

    2005 bulletin  prints an explicit 0 in the gun/muzzleloader tables
    
    2010 bulletin  OMITS the four county rows from those tables entirely
    
    2015 bulletin  prints the letter "C" (closed)
    
    2020 bulletin  prints an explicit 0 again

All four are the same fact: a closed season, hence a true zero harvest, not
an unobserved one. Two things settle it rather than assumption: the 2010
bulletin's own Table 8 (mortality by season) prints 0 for these counties in
the same year its Table 1 omits them, and each bulletin's printed district
subtotals reconcile only if the four contribute zero. So the extraction
records 0 for all three firearm methods in all 20 years and sets
no_firearms_season = 1; the assert below re-states that as a hard check
rather than a comment. Archery harvest in these counties is nonzero
throughout and is untouched.
*/

assert buck_gun == 0 & antlerless_gun == 0 & muzzleloader == 0 ///
    if no_firearms_season == 1
assert bow > 0 & !missing(bow) if no_firearms_season == 1

/*
THE "UNKNOWN" METHOD: The 2015 bulletin's Table 5 carries a sixth
column (deer reported with no identifiable season) totalling 109 head
statewide. No other bulletin breaks this out at county level. It is kept as
its own method rather than folded into Total-only or discarded, because it
is what reconciles the 2015 four-method sum (138,384) with WV DNR's published
2015 season total of 138,493. Left MISSING, not zero, in the other 19 years:
the category was not reported then, which is not the same as its being zero.
Same treatment as WI's XBow method, tracked only from 2014.

Worth flagging: the 2020 bulletin's own text computes its "previous five-year 
average" using 138,384 for 2015, i.e. WV DNR itself sometimes drops the 
unknown-season deer. We keep them.
*/

count if !missing(unknown_method)
assert r(N) == 55
count if !missing(unknown_method) & year != 2015
assert r(N) == 0

* Built explicitly rather than with egen rowtotal: the plain rowtotal treats
* the 19 missing Unknown years as zero silently, and rowtotal ..., missing
* would push those years' Total to missing. In 2001-2014 and 2016-2020 the four 
* reported methods ARE the whole season. Spelling it out makes the "missing 
* Unknown contributes nothing" step visible.

gen total = buck_gun + antlerless_gun + bow + muzzleloader ///
    + cond(missing(unknown_method), 0, unknown_method)
assert !missing(total)

*--------------------------------- 2b. ------------------------------------

rename (buck_gun antlerless_gun bow muzzleloader unknown_method total) ///
       (h_BuckGun h_AntlerlessGun h_Bow h_Muzzleloader h_Unknown h_Total)

reshape long h_, i(county_name year) j(harvest_method) string
rename h_ harvest

isid county_name year harvest_method
count
assert r(N) == 55 * 20 * 6

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/WV/WV_county_crosswalk.dta", ///
    keepusing(county_fips district) keep(match master) gen(_merge_xwalk)
list county_name year if _merge_xwalk == 1
* Expected here: nothing. The bulletins spell every county the Census way;
* the only spelling wobble found anywhere in the four documents is "Bonne"
* for Boone in the 2005 muzzleloader table, corrected at extraction.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

*--------------------------------- 2c. -----------------------------------

/*
Three layers of checking, the last of which uses only figures that were
never inputs to the panel.

  (1) Row identity: Total == sum of components, by construction, re-checked.
  
  (2) District subtotals: every county figure was checked at extraction
      against the printed district subtotal and printed state total for its
      column -- all 8 hand-transcribed tables and all 8 text-extracted
      tables reconcile exactly, on every district and every year.
      WV_source_reference_totals.csv carries those printed figures so the
      check can be re-run here (Section 2c-ii).
      
  (3) Prose check: each bulletin's narrative states the season total, the
      prior year's total, and a five-year average. None of these were used
      to build the panel, so reproducing them is an independent test.
*/

* (i) row identity
preserve
    keep county_fips year harvest_method harvest
    reshape wide harvest, i(county_fips year) j(harvest_method) string
    gen _comp = harvestBuckGun + harvestAntlerlessGun + harvestBow ///
        + harvestMuzzleloader + cond(missing(harvestUnknown), 0, harvestUnknown)
    assert harvestTotal == _comp
    di "Row identity Total == component sum holds in all " _N " county-years."
restore

* (ii) district subtotals and state totals, against the printed figures
preserve
    keep if inlist(harvest_method, "BuckGun", "AntlerlessGun", "Bow", "Muzzleloader", "Unknown")
    gen method = cond(harvest_method == "BuckGun", "buck_gun", ///
                 cond(harvest_method == "AntlerlessGun", "antlerless_gun", ///
                 cond(harvest_method == "Bow", "bow", ///
                 cond(harvest_method == "Muzzleloader", "muzzleloader", "unknown_method"))))
    collapse (sum) calc = harvest, by(district year method)
    gen unit = "district_" + string(district)
    tempfile calcdist
    save `calcdist'

    import delimited "$dataRAW/Deer_Harvest/WV/WV_source_reference_totals.csv", ///
        varnames(1) clear stringcols(1 2 4)
    keep if strpos(unit, "district_")
    merge 1:1 unit year method using `calcdist', keep(match) gen(_m)
    gen _diff = calc - reported
    count if _diff != 0
    assert r(N) == 0
    di "All " _N " printed district subtotals reproduce exactly."
restore

* (iii) prose check against WVDNR's own published statewide figures
preserve
    keep if harvest_method == "Total"
    collapse (sum) state_total = harvest, by(year)

    /*
    The bulletins also print an "Unknown" COUNTY row: deer that could not
    be assigned to any county. It is 0 in every table and every year except
    the 2005 bulletin's antlerless gun table: 142 deer in 2001 and 4 in 2002.
    Those 146 deer cannot belong to a county panel and are simply absent from
    it; they are added back only for this comparison, not to the data.
    */
    gen unassigned = cond(year == 2001, 142, cond(year == 2002, 4, 0))
    gen check_total = state_total + unassigned

    list year state_total unassigned check_total, sepby(year) noobs
    assert check_total == 255356 if year == 2002   // record harvest, named in 3 bulletins
    assert check_total == 135361 if year == 2005
    assert check_total == 106499 if year == 2010
    assert check_total == 104707 if year == 2014   // quoted in the 2015 bulletin text
    assert check_total == 138493 if year == 2015
    assert check_total ==  99437 if year == 2019   // quoted in the 2020 bulletin text
    assert check_total == 106861 if year == 2020

    * "previous five-year harvest average" as quoted in the 2010 and 2015 texts
    summarize check_total if inrange(year, 2005, 2009)
    assert abs(r(mean) - 147547) <= 1
    summarize check_total if inrange(year, 2010, 2014)
    assert abs(r(mean) - 126067) <= 1
    di "Statewide totals reproduce every harvest figure WVDNR states in prose."
restore

*--------------------------------- 2d. -----------------------------------

/*
WV.Harvest.2011-15.CountySex.Web.docx is misnamed: it contains the
2006-2015 harvest tables, not 2011-15. That makes it a free second witness
for the 2010 bulletin's five years. At extraction, all four method tables
were compared county by county against the 2010 bulletin: 55 counties x 5
years x 4 methods, zero disagreements. Nothing in this file is imported from
the Word document except the habitat/density tables in Section 4, which the
2010 bulletin does not carry for 2008/2009/2011/2012/2013.
*/

*--------------------------------- 2e. -----------------------------------

/*
Deliberately left out, each for a stated reason:

  - Tables 2/4/6 in the 2005 and 2010 bulletins ("harvest by locality"):
    harvest on named public lands such as WMAs, state forests, Monongahela
    National Forest tracts. This is a locality geography with no county
    crosswalk, and several units straddle county lines. Excluded on the same
    ground as CA's deer assessment zones, WI's pre-2014 DMUs, and NY's WMUs.

  - 2020 bulletin Table 19 (harvest by deer type: antlered / antlers under 3
    inches / button buck / female / shed antlers / unknown). This is the
    only county-level sex-age breakdown anywhere in the four bulletins and
    covers one season. A single-year sex-class block would not align with
    any other state's panel and would sit oddly against WV's own 19 other
    years. Worth asking WVDNR whether the deer-type breakdown exists 
    for earlier seasons; if it does, WV could be re-cut on the OH/MO sex-class 
    taxonomy instead of by method.

  - Mountaineer Heritage season. The 2020 bulletin's Table 17 splits it out
    (642 deer statewide) while its Tables 14 and 16 fold the same animals
    into archery and muzzleloader. We follow Tables 13-16, the by-year
    series, so the Mountaineer Heritage harvest is inside Bow and
    Muzzleloader. Noted because the two tables therefore disagree by
    construction, not by error.

  - Nonseasonal mortality (roadkill, crop-damage permits, illegal kill).
    Reported statewide only, and not a hunter harvest.
*/

save "$dataSTATA/WV/temp_WV_harvest_2001-2020.dta", replace

*==============================================================================
* SECTION 3: POPULATION DATA - none exists
*==============================================================================

/*------------------------------------------------------------------------

No population source of any kind was provided for WV, and none appears in
any of the four bulletins: WVDNR does not publish a county deer population
estimate or an over-winter index. This is the IN/TN case: absence by data
availability, not an MD/KY-style affirmative exclusion of a statewide-only
series.

The nearest thing WV publishes is the kill-per-square-mile-of-habitat table
(Table 9 in the 2005/2010 bulletins, Table 6 in 2015, Table 18 in 2020),
which is an INDEX derived from harvest, not a count (the same object as
VA's buck kill per square mile of habitat). It is imported in Section 4
alongside the habitat area it is computed on, and is deliberately NOT named
anything resembling population.

Worth an explicit ask on the next WVDNR follow-up: is there a county- or 
district-level deer population or density estimate on file for any part of 2001-
2020, and does the bulletin series extend back before 2001 in a form that still 
gives county detail?

------------------------------------------------------------------------*/

*==============================================================================
* SECTION 4: HABITAT AREA AND KILL-PER-SQUARE-MILE INDEX
*==============================================================================

/*------------------------------------------------------------------------

Coverage is partial and is left that way: 9 of the 20 years print a
kill-per-square-mile table (2005, 2008-2013, 2015, 2020). 2006, 2007, 2014
and 2016-2019 have none, because each bulletin prints the table for its own
season only and the four supplied bulletins are five years apart. The
2008-2013 run exists only because the Word compilation happens to carry
those years. Missing years are left missing.

Two properties of the printed rates, both documented rather than smoothed:

  (a) For the buck-gun, muzzleloader, archery and all-seasons columns the
      printed rate reproduces harvest / printed area to two decimals in
      1,391 of 1,497 checked cells, and to within one unit in the last
      printed digit in 65 more. Of the 41 that differ by more, 39 sit in
      the smallest-habitat counties (Hancock 64 sq mi, Brooke 72, Ohio 82)
      and imply an area within one square mile of the printed integer
      (i.e. WVDNR computes on unrounded acreage and prints a rounded area).
      The other cases are ALL in 2012, where nine counties imply an area
      several square miles above the printed one (Fayette: implied 667 vs
      printed 629; Ohio: 86 vs 82; also Berkeley, Boone, Marshall, Preston,
      Raleigh, Summers, Tucker). 2012 is one of the years that reaches us
      only through the Word compilation, so the likeliest explanation is
      that its area column and its rate columns are different vintages.
      Both are kept as printed.

  (b) The antlerless column is a documented exception in the bulletins' own
      footnote: where part of a county is closed to the Class N antlerless
      season, the rate is computed only on the area open to that season.
      So antlerless kill per square mile routinely exceeds harvest / full
      area in 70 county-years across the nine covered years. Both the
      rate and the full-area denominator are kept; the implied Class N area
      is not reconstructed.

  (c) The 2015 area column does not add up in the source: the eight District
      IV county areas as printed sum to 4,362 against a printed subtotal of
      4,361, and the six printed subtotals sum to 22,973 against a printed
      state total of 22,972. Re-read from the page image twice. Kept as
      printed; not reconciled.

------------------------------------------------------------------------*/

import delimited "$dataRAW/Deer_Harvest/WV/WV_habitat_density.csv", ///
    varnames(1) clear stringcols(1)

destring habitat_area_sqmi kill_sqmi_buck_gun kill_sqmi_antlerless_gun ///
    kill_sqmi_muzzleloader kill_sqmi_bow kill_sqmi_total, replace

isid county_name year
count
assert r(N) == 55 * 9

rename (kill_sqmi_buck_gun kill_sqmi_antlerless_gun kill_sqmi_bow ///
        kill_sqmi_muzzleloader kill_sqmi_total) ///
       (k_BuckGun k_AntlerlessGun k_Bow k_Muzzleloader k_Total)

reshape long k_, i(county_name year) j(harvest_method) string
rename k_ kill_per_sqmi

tempfile density
save `density'

use "$dataSTATA/WV/temp_WV_harvest_2001-2020.dta", clear
merge 1:1 county_name year harvest_method using `density', ///
    keep(master match) gen(_merge_dens)
* The Unknown method has no density column in any source -- expected non-match.
count if _merge_dens == 3
assert r(N) == 55 * 9 * 5
drop _merge_dens

* Twelve of those 2,475 rows merge but carry no printed RATE: the four
* closed-season counties (Logan, McDowell, Mingo, Wyoming) in the buck-gun
* and antlerless-gun columns for 2012, and the antlerless-gun column for
* 2013. The source leaves those cells blank instead of printing 0.00;
* harvest is 0 and the habitat area is printed in all twelve. Kept blank
* rather than filled with 0, since the rate was never published.
count if !missing(habitat_area_sqmi)
assert r(N) == 55 * 9 * 5
count if !missing(kill_per_sqmi)
assert r(N) == 55 * 9 * 5 - 12
count if missing(kill_per_sqmi) & !missing(habitat_area_sqmi)
assert r(N) == 12
assert no_firearms_season == 1 & harvest == 0 ///
    & inlist(year, 2012, 2013) ///
    if missing(kill_per_sqmi) & !missing(habitat_area_sqmi)

*==============================================================================
* SECTION 5: FINALIZE HARVEST-ONLY PANEL
*==============================================================================

gen source_bulletin = cond(year <= 2005, 2005, ///
                      cond(year <= 2010, 2010, ///
                      cond(year <= 2015, 2015, 2020)))
gen byte source_scanned = inlist(source_bulletin, 2005, 2015)

order county_fips county_name district year harvest_method harvest ///
    kill_per_sqmi habitat_area_sqmi no_firearms_season source_bulletin ///
    source_scanned

label variable county_fips        "WV county FIPS code (from crosswalk merge)"
label variable county_name        "County name, as reported in source"
label variable district           "WVDNR district (1-6), as the bulletins group counties"
label variable year               "Season start year (2020 row covers fall 2020 and Jan 2021)"
label variable harvest_method     "Total / BuckGun / AntlerlessGun / Bow / Muzzleloader / Unknown"
label variable harvest            "Deer harvested by this method (Total = sum of components)"
label variable kill_per_sqmi      "Deer kill per sq mi of habitat, as printed (index; 9 of 20 yrs)"
label variable habitat_area_sqmi  "County deer habitat open for season, sq mi, as printed"
label variable no_firearms_season "1 = no firearms deer season 2001-2020 (archery/crossbow only)"
label variable source_bulletin    "WV Big Game Bulletin the figures came from (2005/2010/2015/2020)"
label variable source_scanned     "1 = source page was an image scan, transcribed by hand"

label data "WV county-year-method deer harvest, 2001-2020 (WVDNR bulletins)"

notes: Source: four WVDNR Big Game Bulletins (2005, 2010, 2015, 2020), each printing a five-year county block; together they tile 2001-2020 with no gap or overlap. County tables were extracted; the 2005 bulletin and pages 30-35 of the 2015 bulletin are image scans and were transcribed by hand (source_scanned == 1).
notes harvest_method: WV publishes harvest by METHOD, not sex/age: BuckGun, AntlerlessGun, Bow, Muzzleloader, Unknown, and Total (the component sum). Unknown (deer with no identifiable season) is reported for 2015 only, 109 head statewide, and is missing -- not zero -- in the other 19 years.
notes harvest: Logan, McDowell, Mingo and Wyoming had no firearms season in any year 2001-2020: their gun and muzzleloader figures are true zeros (confirmed by the bulletins' mortality table and by the district subtotals), and their archery harvest is nonzero throughout. The 146 deer the 2005 bulletin could not assign to a county (142 in 2001, 4 in 2002) are not in the panel.
notes kill_per_sqmi: A harvest-derived INDEX, not a population measure, printed for 9 of the 20 years (2005, 2008-2013, 2015, 2020). Twelve cells are blank in the source: the four closed-season counties for buck gun and antlerless gun in 2012 and antlerless gun in 2013. The antlerless column is computed on the area open to the Class N season, not the full county, per the bulletins' own footnote.
notes habitat_area_sqmi: As printed. The 2015 column does not add up in the source: District IV counties sum to 4,362 against a printed subtotal of 4,361, and the six subtotals sum to 22,973 against a printed state total of 22,972. Kept as printed.
notes: No population variable. WVDNR publishes no county deer population estimate or over-winter index (do-file Section 3).

isid county_fips year harvest_method
assert inrange(year, 2001, 2020)
assert harvest >= 0 if !missing(harvest)
assert !missing(harvest) if harvest_method != "Unknown"
assert missing(harvest) if harvest_method == "Unknown" & year != 2015
count
assert r(N) == 55 * 20 * 6
bysort county_fips: assert _N == 20 * 6
sort county_fips year harvest_method
codebook county_fips, compact

tab harvest_method
tab year if harvest_method == "Total" & !missing(habitat_area_sqmi)

describe
summarize
browse

save "$dataCLEAN/WV/WV_deer_harmonized_county_year_2001-2020.dta", replace

log close
