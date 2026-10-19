/*==============================================================================

FILE NAME:   NC_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  North Carolina (NC) county-level deer HARVEST harmonization,
          adapted from the VA/WI/OH pilot scripts.

          IMPORTANT STRUCTURAL DIFFERENCE FROM VA/OH: despite the source
          filename ("...CountySex_Shaw.xlsx"), NC's file does NOT contain
          county-level age/sex breakdowns, a buck kill index, or a
          population index the way VA's and OH's sources do. It has
          three sheets:

            1. "total reported harvest"      -- county-level, but TOTAL
                                                 harvest only (no sex/age
                                                 split), wide by year,
                                                 1976-2014. This is the
                                                 only county-resolution
                                                 sheet in the workbook and
                                                 is what Section 2 below
                                                 imports.
						 
            2. "estimated harvest and density" -- STATEWIDE only. A dense
                                                 multi-block reconstruction
                                                 table (Downing's method):
                                                 buck/doe age-class harvest
                                                 percentages, population
                                                 reconstruction, deer/sq
                                                 mile density, recruitment,
                                                 % population change, etc.,
                                                 1984-2014. This is where a
                                                 NC "buck kill index" /
                                                 population-index analogue
                                                 to VA's would live, but it
                                                 is state-level, not
                                                 county-level.
						 
            3. "reported harvest trend"      -- STATEWIDE only. Redundant
                                                 restatement of buck/doe
                                                 harvest by year
                                                 (1988-2013) plus an
                                                 antlerless/antlered
                                                 proportion breakdown for
                                                 2001-2013.

          Sheets 2 and 3 are NOT imported below. Per the VA precedent (statewide 
	  DVC appendix considered, then disregarded in favor of county-level 
	  compilation as the series of record), state-level series that can't be 
	  resolved to county are candidates for exclusion rather than being 
	  merged onto every county as a pseudo-covariate. Sheets 2-3 left out of 
	  the pipeline entirely (matches the VA statewide-DVC precedent).
           
SOURCE FILES USED:

  PROVENANCE [open]: "Shaw" is a surname only -- presumed NC Wildlife
    Resources Commission, affiliation not confirmed.
    
  Deer_Population/NC.PopHarvest.1976-2014.CountySex.Shaw.xlsx
                                               -- "total reported harvest"
                                                    sheet only (see above).

CHANGELOG:

08/10/2026 — Nicole: First pass adapting the VA/WI/OH pilot logic
                     to NC. Only the county-level harvest sheet is
                     harmonized; the two statewide sheets are flagged
                     above rather than imported.

09/16/2026 — Nicole: Clean up pass, no change to data values. Footer-total
                     QC now asserts an exact match (was list-only); county
                     row count checked before reshape; crosswalk merge
                     asserted (a header or stray row can no longer be
                     dropped silently there). 30 reported zero county-years
                     (all 1976-1984) pinned. FIPS crosswalk verified
                     against Census 2020 (100/100). Labels shortened to
                     Stata's 80-char limit (earlier labels were truncated
                     in the saved .dta); long-form documentation moved to
                     -notes-. Panel sorted before save.

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
log using "$codeSTATA/logs/NC_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/NC"
cap mkdir "$dataCLEAN/NC"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

Like OH (and unlike VA), no source sheet carries a FIPS code -- county
name only. Built here as a static reference table (state FIPS 37, 100
counties, clean alphabetical numbering 001-199 by 2s -- no out-of-
sequence carve-outs the way VA has independent cities or WI has
Menominee).

Typed from standard Census county FIPS assignments (cross-checked against
NC State University Libraries' published county FIPS list). VERIFIED
09/16/2026: all 100 codes match the Census 2020 county FIPS reference list
exactly (no mismatches, no missing codes)
https://www2.census.gov/geo/docs/reference/codes2020/cou/st37_nc_cou2020.txt

NOTE: Unlike OH's "VanWert" quirk, every county name in the harvest sheet
matches the standard Census spelling (upper case in the source), including
NC's one multi-word name ("NEW HANOVER") -- name_clean below uppercases and
strips spaces anyway, for consistency with the OH/WI pattern and in case
that changes in a later version of the source file.

------------------------------------------------------------------------*/

input str20 county_name str3 fips_suffix
"Alamance" "001"
"Alexander" "003"
"Alleghany" "005"
"Anson" "007"
"Ashe" "009"
"Avery" "011"
"Beaufort" "013"
"Bertie" "015"
"Bladen" "017"
"Brunswick" "019"
"Buncombe" "021"
"Burke" "023"
"Cabarrus" "025"
"Caldwell" "027"
"Camden" "029"
"Carteret" "031"
"Caswell" "033"
"Catawba" "035"
"Chatham" "037"
"Cherokee" "039"
"Chowan" "041"
"Clay" "043"
"Cleveland" "045"
"Columbus" "047"
"Craven" "049"
"Cumberland" "051"
"Currituck" "053"
"Dare" "055"
"Davidson" "057"
"Davie" "059"
"Duplin" "061"
"Durham" "063"
"Edgecombe" "065"
"Forsyth" "067"
"Franklin" "069"
"Gaston" "071"
"Gates" "073"
"Graham" "075"
"Granville" "077"
"Greene" "079"
"Guilford" "081"
"Halifax" "083"
"Harnett" "085"
"Haywood" "087"
"Henderson" "089"
"Hertford" "091"
"Hoke" "093"
"Hyde" "095"
"Iredell" "097"
"Jackson" "099"
"Johnston" "101"
"Jones" "103"
"Lee" "105"
"Lenoir" "107"
"Lincoln" "109"
"McDowell" "111"
"Macon" "113"
"Madison" "115"
"Martin" "117"
"Mecklenburg" "119"
"Mitchell" "121"
"Montgomery" "123"
"Moore" "125"
"Nash" "127"
"New Hanover" "129"
"Northampton" "131"
"Onslow" "133"
"Orange" "135"
"Pamlico" "137"
"Pasquotank" "139"
"Pender" "141"
"Perquimans" "143"
"Person" "145"
"Pitt" "147"
"Polk" "149"
"Randolph" "151"
"Richmond" "153"
"Robeson" "155"
"Rockingham" "157"
"Rowan" "159"
"Rutherford" "161"
"Sampson" "163"
"Scotland" "165"
"Stanly" "167"
"Stokes" "169"
"Surry" "171"
"Swain" "173"
"Transylvania" "175"
"Tyrrell" "177"
"Union" "179"
"Vance" "181"
"Wake" "183"
"Warren" "185"
"Washington" "187"
"Watauga" "189"
"Wayne" "191"
"Wilkes" "193"
"Wilson" "195"
"Yadkin" "197"
"Yancey" "199"
end

gen county_fips = "37" + fips_suffix
drop fips_suffix

* Merge key: uppercase, whitespace-trimmed, periods AND spaces stripped.
gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 100

label variable county_fips "NC county FIPS code (5-digit, state+county)"
label variable county_name "County name (Census spelling)"
label variable name_clean  "Merge key: county_name upper-cased, trimmed, periods/spaces removed"
label data "NC county FIPS crosswalk, 100 units (static reference, state FIPS 37)"

save "$dataSTATA/NC/NC_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import, Reshape & Clean
*==============================================================================

/*------------------------------------------------------------------------

"total reported harvest" sheet: County/District/Region/Mang.Zone as the
first four columns, then one column per year 1976-2014 (wide), TOTAL
harvest only -- no sex/age breakdown at county level (see file header
note above). Wide-by-year, so this needs the same rename-loop +
`reshape long` treatment as WI's year-column sheets, not a straight
firstrow import: "Mang. Zone" (space + period) and bare numeric year
headers ("1976"...) would both mangle unpredictably under
`import excel ..., firstrow`.

Confirmed during inspection: 100 counties, no duplicates, no whitespace
issues, zero missing harvest cells across all 39 years, and the
county-sum-by-year matches the sheet's own "Total" footer row for every
year with no exceptions. Row 101 is blank and row 102 is the "Total"
footer row -- both dropped below rather than trusted to auto-exclude,
per the standing footer-row bug pattern seen in VA/WI.

------------------------------------------------------------------------*/

import excel "$dataRAW/Deer_Population/NC/NC.PopHarvest.1976-2014.CountySex.Shaw.xlsx", ///
    sheet("total reported harvest") cellrange(A2) clear

rename A county_name
rename B district
rename C region
rename D mgmt_zone

* Drop the blank spacer row and the "Total" footer row before reshaping,
* rather than after -- a non-numeric "Total" cell in what should be a
* year-harvest column would otherwise force the whole variable to string.
drop if missing(county_name)
drop if upper(county_name) == "TOTAL"
count
assert r(N) == 100                  // one row per county, nothing else

* Stash the state-level total-by-year row for the QC check below, before
* it's gone for good.
* NOTE: this uses the footer row that was just dropped above, so this
* block must run against the *original* import, not a later reshaped
* copy. Re-imports a throwaway copy rather than restructuring the order
* above, to keep the main import block simple.
preserve
    import excel "$dataRAW/Deer_Population/NC/NC.PopHarvest.1976-2014.CountySex.Shaw.xlsx", ///
        sheet("total reported harvest") cellrange(A2) clear
    keep if upper(A) == "TOTAL"
    drop A B C D
    ds
    local yearvars `r(varlist)'
    local yr = 1976
    foreach v of local yearvars {
        rename `v' h`yr'
        local yr = `yr' + 1
    }
    gen _dummy = 1
    reshape long h, i(_dummy) j(year)
    rename h harvest_total_reported
    drop _dummy
    tempfile statetotals
    save `statetotals'
restore

ds county_name district region mgmt_zone, not
local yearvars `r(varlist)'
local yr = 1976
foreach v of local yearvars {
    rename `v' h`yr'
    local yr = `yr' + 1
}

reshape long h, i(county_name) j(year)
rename h harvest_total
confirm numeric variable harvest_total
assert !missing(harvest_total)
assert inrange(year, 1976, 2014)

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/NC/NC_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* Inspection found no unmatched county strings -- every row must match,
* in both directions.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

label variable county_fips    "NC county FIPS code (5-digit string, state+county)"
label variable county_name    "County name, as reported in source (upper case)"
label variable district       "NCWRC district number (time-invariant)"
label variable region         "Region: C=Coastal, M=Mountain, P=Piedmont (time-invariant)"
label variable mgmt_zone      "Deer management zone name (time-invariant)"
label variable year           "Harvest year"
label variable harvest_total  "Total reported deer harvest (no county sex/age split exists)"
label data "NC county-year total deer harvest, 1976-2014 (temp)"

order county_fips county_name district region mgmt_zone year harvest_total

isid county_fips year
count
assert r(N) == 100 * 39
codebook county_fips, compact
describe

* QC: does the county-sum-by-year match the sheet's own "Total" row?
* Confirmed clean during inspection and re-checked here.
preserve
    collapse (sum) harvest_total, by(year)
    rename harvest_total harvest_total_summed
    merge 1:1 year using `statetotals', gen(_m)
    assert _m == 3                     // all 39 years on both sides
    drop _m
    destring harvest_total_reported, replace
    gen _diff = harvest_total_summed - harvest_total_reported
    list year harvest_total_summed harvest_total_reported _diff if _diff != 0, sep(0)
    assert _diff == 0
restore

save "$dataSTATA/NC/temp_NC_harvest_1976-2014_raw.dta", replace

*==============================================================================
* SECTION 3: STATEWIDE AGE/SEX, BUCK KILL INDEX & POPULATION RECONSTRUCTION
*==============================================================================

/*------------------------------------------------------------------------

NOT IMPORTED -- see the note at the top of this file. The "estimated harvest and 
density" sheet (1984-2014) holds NC's analogue of VA's buck kill index and 
population index, but only at the state level: five side-by-side sub-blocks 
(estimated harvest/density, Downing's reconstruction of hunter removal by sex/
age, population reconstruction, population reconstruction plus non-harvest 
mortality, and a final population/density/recruitment block), each with its own 
3-row merged header and non-contiguous columns. The "reported harvest trend" 
sheet (1988-2013) is a smaller, partially redundant statewide restatement of
the same buck/doe harvest split. Left un-built.

------------------------------------------------------------------------*/

*==============================================================================
* SECTION 4: BUILD THE COUNTY-YEAR PANEL
*==============================================================================

/*------------------------------------------------------------------------

Unlike VA/OH, there is only one county-level source here, so this stage
is a pass-through/finalize rather than a merge: the Section 2 harvest
file *is* the panel, at least until Section 3 is resolved.

Flagging again at the point it matters most: this panel has NO sex/age breakdown, 
NO buck kill index, and NO population index columns for NC -- every other state 
built so far (VA, OH) has at least the population index at county level.

------------------------------------------------------------------------*/

use "$dataSTATA/NC/temp_NC_harvest_1976-2014_raw.dta", clear

label data "NC county-year total deer harvest, 1976-2014 (source: Shaw)"

notes harvest_total: Total reported harvest only; the source has no county-level sex/age breakdown. County sums match the sheet footer Total row exactly in every year. 30 reported zeros, all 1976-1984 (Cabarrus, Catawba, Gaston, Jackson, Lee, Lincoln, Mecklenburg, Union, Wayne, Wilson).
notes: Harvest-only panel. The workbook's two statewide-only sheets (Downing population reconstruction/density; harvest trend) are not imported pending a decision (do-file header [DECIDE]). district, region, mgmt_zone are time-invariant county attributes from the source.

isid county_fips year
assert year >= 1976 & year <= 2014
count
assert r(N) == 100 * 39
bysort county_fips: assert _N == 39
count if harvest_total == 0
assert r(N) == 30
assert year <= 1984 if harvest_total == 0
sort county_fips year
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/NC/NC_deer_harmonized_county_year_1976-2014.dta", replace

log close
