/*==============================================================================

FILE NAME:   DE_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  Delaware (DE) county-level deer HARVEST harmonization, adapted
          from the VA/WI/OH/NC/MO/MD/KY/CA pilot scripts. DE is a THIN
          state relative to the others harmonized so far -- only 3
          counties (New Castle, Kent, Sussex), and harvest arrives as
          TWO SEPARATE, NON-ADJACENT vintages: 2010-2015 (Boyd) and
          2022-2025 (undated recent extract), with NO source located yet
          for 2016-2021 -- an UNBALANCED panel with a documented 6-year
          gap, not a data-entry omission (see Section 2). Harmonized now
          (08/18/2026) rather than held, on the understanding more historical/
	  gap years may surface later and can be appended without restructuring 
	  this script.

          DE's only population data (two aerial infrared surveys, 2005 &
          2009) is ZONE-level density, not county-level counts, and is
          NOT imported here -- see Section 3. This script therefore produces a 
	  HARVEST-ONLY county-year panel, same shape as MD/KY.

SOURCE FILES USED:

  PROVENANCE [open]: "Boyd" (2010-2015 file and 2009 survey PDF) is a
    surname only -- presumed DE Department of Natural Resources and 
    Environmental Control Division of Fish & Wildlife, affiliation not 
    confirmed. The 2022-2025 file has no attribution.
    
  DE.Harvest.2010-2015.CountySex.Boyd.xlsx   -- county harvest, 2010-11
                                                 through 2015-16 seasons
                                                 (6 seasons), WIDE format:
                                                 Sheet1 = Total harvest by
                                                 county x season, Sheet2 =
                                                 Antlered harvest by
                                                 county x season. No
                                                 Unantlered column exists
                                                 in source -- derived
                                                 below as Total minus
                                                 Antlered (see Section 2). 
						 Also carries a
                                                 "5 year Avg" column
                                                 (dropped, not a data
                                                 year) and a "Total" row
                                                 per sheet (dropped, not a
                                                 county). A second copy,
                                                 DE_Harvest_2010-2015_
                                                 CountySex_Boyd_1_.xlsx,
                                                 was also provided --
                                                 diffed cell-by-cell
                                                 (all 12 data rows across both
                                                 tables) and confirmed
                                                 identical in content,
                                                 just laid out as one
                                                 stacked sheet instead of
                                                 two -- same "two copies
                                                 provided" pattern as
                                                 MD's Eyler files. Only
                                                 the base (two-sheet) copy
                                                 is used below.
						 
  Delaware_Harvest_Data.xlsx                 -- county harvest by sex
                                                 (Antlered/Unantlered),
                                                 2022-2025, already long.
                                                 Also carries a
                                                 Turkey_Harvest column,
                                                 populated for 2025 only --
                                                 out of scope for this
                                                 deer-only pipeline, not
                                                 imported (see Section 2).
						 
  DE_Final_Report_2009.pdf / DE_Pop_2009_Boyd.pdf
                                              -- identical files (byte-
                                                 identical PDF, confirmed
                                                 same file size on
                                                 inspection). Aerial
                                                 infrared deer population
                                                 survey, 17 management
                                                 zones, Feb-Mar 2009, with
                                                 2005 comparison. Zone-
                                                 level density only. NOT
                                                 imported -- see Section 3.
						 
  DE_Deer_Density.doc                        -- narrative companion to the
                                                 2009 survey report; the
                                                 only source with any
                                                 county-level population
                                                 figures at all (2009 zone
                                                 survey rolled up to
                                                 county density for New
                                                 Castle/Kent/Sussex, with
                                                 a 2005-to-2009 % change
                                                 for Kent/Sussex only --
                                                 2005 county-level values
                                                 are not given directly
                                                 and would require back-
                                                 calculation from the %
                                                 change). NOT imported --
                                                 see Section 3.
						 
  Delaware-Deer-Harvest-at-a-Glance.pdf      -- statewide annual harvest
                                                 1954-2024 shown ONLY as a
                                                 line chart (no
                                                 underlying table, not
                                                 digitized/imported here),
                                                 plus a 2024-25 county
                                                 harvest total table used
                                                 below only as a QC cross-
                                                 check reference, not as
                                                 an import source (see
                                                 Section 2 QC block).
						 
  Wildlife-Management-Zones_2025-06-27...pdf -- 17-zone boundary map/
                                                 descriptions. Reference
                                                 only, not used for any
                                                 import; kept on file per
                                                 team practice of retaining
                                                 zone/unit shapefile-
                                                 adjacent material even
                                                 when zones are excluded
                                                 from the panel.

CHANGELOG:

08/17/2026 — Nicole: First pass. Harvest-only panel built from the single
                     clean county-sex-year xlsx (2022-2025, 3 counties).
                     Population excluded - density survey data (Section 3). 
		     QC note added documenting an unresolved ~1-2% discrepancy
                     between this xlsx's 2024 county sums and the
                     "at a Glance" PDF's 2024-25 county totals -- kept
                     both on record per team decision, not resolved here.

08/18/2026 — Nicole: Added the 2010-2015 Boyd vintage (reshaped from wide
                     Total/Antlered-by-season sheets, Unantlered derived
                     as Total minus Antlered) and appended to the 2022-
                     2025 panel. Result is an UNBALANCED panel with an
                     undocumented-source gap for 2016-2021 -- flagged,
                     not interpolated. County FIPS crosswalk (Section 1)
                     unchanged; both vintages use the same 3 counties
                     with identical source spelling.

09/15/2026 — Nicole: Clean up pass, no change to data values. Comment-only
                     expectations turned into asserts: Boyd season headers
                     checked before rename-by-position; row counts and no
                     missing cells in both vintages; unantlered >= 0 after
                     derivation; 2024 QC totals pinned (3,010 / 6,094 /
                     9,550); crosswalk merge all-matched; exact year set
                     (2010-2015, 2022-2025) and 10 years per county.
                     Removed a no-op destring-force after arithmetic.
                     FIPS crosswalk verified against Census 2020 (3/3).
                     Labels shortened to Stata's 80-char limit (earlier
                     labels were truncated in the saved .dta); long-form
                     documentation moved to -notes-. Header source
                     filenames corrected to match the import paths.

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
log using "$codeSTATA/logs/DE_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/DE"
cap mkdir "$dataCLEAN/DE"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

Delaware has only 3 counties statewide (state FIPS 10), the smallest
county count of any state harmonized so far. No source file carries a
FIPS code -- same "typed from standard Census assignments" pattern as
OH/NC/MO/MD/KY. VERIFIED 09/15/2026: all 3 name/code pairs match the
Census 2020 county FIPS reference list exactly (Kent 10001, New Castle
10003, Sussex 10005)
https://www2.census.gov/geo/docs/reference/codes2020/cou/st10_de_cou2020.txt

No spelling/spacing wrinkles here -- "New Castle" (with space, matching
the xlsx source exactly), "Kent", "Sussex" are all single- or two-word,
no apostrophes or possessives to worry about (unlike MD's
PrinceGeorge's/QueenAnne's/StMary's note).

------------------------------------------------------------------------*/

input str20 county_name str3 fips_suffix
"New Castle" "003"
"Kent"       "001"
"Sussex"     "005"
end

gen county_fips = "10" + fips_suffix
drop fips_suffix

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 3

label variable county_fips "DE county FIPS code (5-digit, state+county)"
label variable county_name "County name (source spelling)"
label variable name_clean  "Merge key: county_name upper-cased, trimmed, periods/spaces removed"
label data "DE county FIPS crosswalk, 3 counties (static reference, state FIPS 10)"

save "$dataSTATA/DE/DE_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import & Clean
*==============================================================================

/*------------------------------------------------------------------------
SECTION 2a: 2010-2015 vintage (Boyd) -- wide, two sheets, reshape to long
------------------------------------------------------------------------*/

/*------------------------------------------------------------------------

Sheet1 ("Total Harvest by County") and Sheet2 ("Antlered Deer Harvest by
County") are both wide: one row per county, one column per season
("2010-11" ... "2015-16"), plus a trailing "5 year Avg" column (dropped)
and a trailing "Total" row (state aggregate, not a county). cellrange
A2:H5 = header row + the 3 county rows, so the Total row is never read;
the -drop if county_name == "Total"- lines are a harmless guard.

No Unantlered column exists anywhere in this source -- only Total and
Antlered are reported per county-season. DECISION: derive harvest_unantlered = 
harvest_total - harvest_antlered rather than leaving it missing, so the variable 
is comparable across both vintages of this panel; this makes harvest_unantlered 
here a DERIVED value for 2010-2015, unlike 2022-2025 where it is directly 
reported by the source. Flag if this derivation should instead be left as 
missing / kept in a separate "reported vs. derived" indicator.

Season strings ("2010-11") are converted to a single integer year using
the SEASON-START year (2010-11 -> 2010), matching the convention already
implicit in the 2022-2025 vintage's plain "Year" column (2022, ... 2025),
which is presumed to also be season-start-year -- not independently
confirmed in that source, flagged for the record.

------------------------------------------------------------------------*/

import excel "$dataRAW/Deer_Harvest/DE/DE.Harvest.2010-2015.CountySex.Boyd.xlsx", ///
    sheet("Sheet1") cellrange(A2:H5) firstrow clear
count
assert r(N) == 3
rename A county_name
drop if county_name == "Total"
* columns B..G are the six season totals; H is "5 year Avg" -- drop it
drop yearAvg

* Renaming below is BY POSITION. -firstrow- keeps each header cell's text
* (e.g. "2010-11") as the variable label -- check it starts with the
* expected season-start year before trusting the position.
local y = 2010
foreach c in B C D E F G {
    local lbl : variable label `c'
    di as txt "`c' header: `lbl'"
    assert substr(strtrim("`lbl'"), 1, 4) == "`y'"
    local ++y
}
rename B total2010
rename C total2011
rename D total2012
rename E total2013
rename F total2014
rename G total2015

reshape long total, i(county_name) j(year)
rename total harvest_total
confirm numeric variable harvest_total
assert !missing(harvest_total)

tempfile boyd_total
save `boyd_total'

import excel "$dataRAW/Deer_Harvest/DE/DE.Harvest.2010-2015.CountySex.Boyd.xlsx", ///
    sheet("Sheet2") cellrange(A2:H5) firstrow clear
count
assert r(N) == 3
rename A county_name
drop if county_name == "Total"
drop yearAvg

* Same by-position guard as Sheet1.
local y = 2010
foreach c in B C D E F G {
    local lbl : variable label `c'
    di as txt "`c' header: `lbl'"
    assert substr(strtrim("`lbl'"), 1, 4) == "`y'"
    local ++y
}
rename B antlered2010
rename C antlered2011
rename D antlered2012
rename E antlered2013
rename F antlered2014
rename G antlered2015

reshape long antlered, i(county_name) j(year)
rename antlered harvest_antlered

merge 1:1 county_name year using `boyd_total', assert(match) nogenerate

gen harvest_unantlered = harvest_total - harvest_antlered
drop harvest_total

* All three already numeric (the subtraction above would have errored
* otherwise) -- the old -destring, force- here was a no-op. Check instead:
confirm numeric variable year harvest_antlered harvest_unantlered
assert !missing(harvest_antlered, harvest_unantlered)
assert harvest_unantlered >= 0      // antlered never exceeds total
isid county_name year
count
assert r(N) == 3 * 6

tempfile boyd_2010_2015
save `boyd_2010_2015'

/*------------------------------------------------------------------------
SECTION 2b: 2022-2025 vintage -- already long
------------------------------------------------------------------------*/

/*------------------------------------------------------------------------

Already county-year long format (County, Year, Antlered, Unantlered,
Turkey) -- no reshape needed, same "already long" pattern as MD/OH.
Confirmed on inspection: perfectly balanced, 3 counties x 4 years
(2022-2025), zero missing cells for the deer columns, no footer/source-
note rows.

Turkey_Harvest is dropped -- populated for 2025 only (structurally
absent/blank 2022-2024, confirmed on inspection, not a truncated read),
and out of scope for this deer-only pipeline in any case. Flag if a
separate turkey harmonization pass should pick this column up from the
same source file later.

------------------------------------------------------------------------*/

import excel "$dataRAW/Deer_Harvest/DE/Delaware_Harvest_Data.xlsx", ///
    sheet("Sheet1") firstrow clear

drop Turkey_Harvest

rename Year   year
rename County county_name
rename Antlered_Deer_Harvest   harvest_antlered
rename Unantlered_Deer_Harvest harvest_unantlered

destring year, replace force
destring harvest_antlered harvest_unantlered, replace force

* -force- above would turn any text cell into missing; the comment block
* says there are none, so check it.
assert !missing(year, harvest_antlered, harvest_unantlered)
isid county_name year
count
assert r(N) == 3 * 4
assert inrange(year, 2022, 2025)

/*------------------------------------------------------------------------

QC: cross-check against "Delaware-Deer-Harvest-at-a-Glance.pdf" 2024-25
county harvest totals (New Castle 3,055 / Kent 6,140 / Sussex 9,628).
This xlsx's 2024 county sums (antlered+unantlered) come in ~1-2% below
those figures (New Castle 3,010 / Kent 6,094 / Sussex 9,550 -- off by
45/46/78 head respectively). The cause is not confirmed. 

It does NOT look like a whole-season offset: the xlsx's 2023 and 2025 sums are
10-25% below the PDF figures (e.g. Kent 4,582 and 5,451 vs 6,140),
so the xlsx "2024" row does line up with the PDF's 2024-25 season --
which also supports reading the xlsx Year as season-start.

DECISION (08/18/2026): keep the xlsx as the imported source of record and 
document the gap rather than adjusting either number; revisit if we want it 
reconciled. The asserts pin the xlsx values so a re-pulled file that changes 
them stops here.

------------------------------------------------------------------------*/

preserve
    gen harvest_total_qc = harvest_antlered + harvest_unantlered
    list county_name year harvest_total_qc if year == 2024
    * PDF 2024-25: New Castle 3,055 | Kent 6,140 | Sussex 9,628
    assert harvest_total_qc == 3010 if year == 2024 & county_name == "New Castle"
    assert harvest_total_qc == 6094 if year == 2024 & county_name == "Kent"
    assert harvest_total_qc == 9550 if year == 2024 & county_name == "Sussex"
restore

append using `boyd_2010_2015'

/*------------------------------------------------------------------------
SECTION 2c: combine, crosswalk, finalize import
------------------------------------------------------------------------*/

/*------------------------------------------------------------------------

Two non-adjacent harvest vintages now stacked: 2010-2015 (Boyd, 6
seasons) and 2022-2025 (4 seasons) -- 10 distinct years total, with NO
source located for 2016-2021. This is an intentional gap, not a
balanced-panel assumption; downstream regressions need to handle the
missing interior years explicitly rather than treating this as a
continuous 2010-2025 series.

------------------------------------------------------------------------*/

label variable year               "Harvest year (season-start year)"
label variable county_name        "County name, as reported in source"
label variable harvest_antlered   "Antlered deer harvested"
label variable harvest_unantlered "Unantlered deer harvested (2010-15 derived: total - antlered)"

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/DE/DE_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* Only 3 counties, all present in both vintages with identical spelling,
* so every row must match in both directions.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

label data "DE deer harvest temp, 2010-2015 + 2022-2025 (no source 2016-2021)"
order county_fips county_name year harvest_antlered harvest_unantlered

isid county_fips year
count
assert r(N) == 30
codebook county_fips, compact
describe

save "$dataSTATA/DE/temp_DE_harvest_2010-2025_raw.dta", replace

*==============================================================================
* SECTION 3: POPULATION DATA - excluded, not imported
*==============================================================================

/*------------------------------------------------------------------------

DE's only population data is two aerial infrared surveys (Dec 2005 and
Feb-Mar 2009), reported almost entirely at the 17 DEER MANAGEMENT ZONE
level as DENSITY (deer per sq mi of habitat), not as county-level
headcounts, and not as an annual series -- just these two point-in-time
survey years.

The companion narrative (DE_Deer_Density.doc) does give county-level
density for 2009 alone (New Castle 47.9, Kent 30.8, Sussex 50.3 deer/
sq mi) plus a 2005-to-2009 % reduction for Kent (-11.4%) and Sussex
(-5.8%) only -- New Castle's comparison is explicitly stated in the
source as not calculable, because the 2009 survey moved/relocated the
block used for Zone 1. 2005 county-level values are NOT given directly
in the source; they would require back-calculating from the % change
(e.g. Kent 2005 approx = 30.8 / (1 - 0.114) approx = 34.8), which is
inference layered on top of an already-approximate density estimate
(source states +/-20.75% survey variability), not a measured value.

Following the MD/KY precedent (NC's Section-1 framing, option (a):  exclude, 
document, don't merge), my default is to exclude this from the panel entirely 
rather than attempt to force it into a county-year population variable via 
back-calculation and density-to-count conversion (density -> count would 
additionally require a deer-habitat-acreage variable per county per year, which 
is not available here either -- only a statewide habitat total is given).
NOT resolved unilaterally here because unlike MD/KY, this involves
converting a fundamentally different data type (zone density) rather
than just declining to broadcast a clean state-level series -- flagging
before treating this as settled precedent for any future zone-density-only state.

Also worth noting for the zone/unit reference-material track: the
management zone boundary PDF (Wildlife-Management-Zones_2025-06-27...)
is on file and could support a zone shapefile/crosswalk request to the
DE contact per the project's standing "ask about zone boundaries for
reference even when excluded from the panel" practice, if useful
downstream.

------------------------------------------------------------------------*/

*==============================================================================
* SECTION 4: FINALIZE HARVEST-ONLY PANEL
*==============================================================================

/*------------------------------------------------------------------------

No population to merge in (Section 3), so the harvest panel from Section
2 IS the final panel -- same pattern as MD/KY. Re-confirms integrity and
saves to dataCLEAN under the same naming convention as the other states.

------------------------------------------------------------------------*/

use "$dataSTATA/DE/temp_DE_harvest_2010-2025_raw.dta", clear

order county_fips county_name year harvest_antlered harvest_unantlered

label data "DE county-year deer harvest by sex, 2010-2015 + 2022-2025 (gap 2016-2021)"

notes harvest_unantlered: 2010-2015 DERIVED as total minus antlered (the Boyd source reports only total and antlered); 2022-2025 directly reported. See do-file Section 2a.
notes year: Season-start year. 2010-2015 from season labels (2010-11 -> 2010). 2022-2025 from the source's plain Year column, presumed season-start; its 2024 row matches the at-a-Glance PDF 2024-25 county totals within 1-2 pct while 2023 and 2025 do not. No source located for 2016-2021.
notes: Harvest-only panel. DE population data are two zone-level aerial density surveys (2005, 2009) with no county-year count; excluded pending Eyal sign-off (do-file Section 3).

isid county_fips year
assert inrange(year, 2010, 2025)
count
assert r(N) == 30

* the gap is exactly 2016-2021 and nothing else is missing:
* 10 distinct years (2010-2015, 2022-2025), each county present in all 10
assert !inrange(year, 2016, 2021)
quietly tab year
assert r(r) == 10
bysort county_fips: assert _N == 10
sort county_fips year

codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/DE/DE_deer_harmonized_county_year_2010-2025.dta", replace

log close
