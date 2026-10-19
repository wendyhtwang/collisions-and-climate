/*==============================================================================

FILE NAME:   MD_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  Maryland (MD) county-level deer HARVEST harmonization, adapted
          from the VA/WI/OH/NC/MO pilot scripts. Harvest is the clean part
          of MD -- one file, already county-year long, no reshape, no
          footer rows, no missingness (see Section 2). MD's population
          source is NOT county-level at all -- a single statewide time
          series, no county field of any kind -- so per Nicole's decision
          (08/12/2026, matching option (a) of NC's Section 1 framing) it is 
	  documented and excluded rather than merged in. This script therefore 
	  produces a HARVEST-ONLY county-year panel; MD carries no population 
	  variable.

SOURCE FILES USED:

  PROVENANCE [open]: "Eyler" is a surname only -- presumed MD Department of 
    Natural Resources Wildlife & Heritage Service; attribution being verified 
    with Kevin Lamp (MD DNR Deer Project Leader).
    
  MD.Harvest.1931-2014.CountySex.Eyler.xls   -- county harvest by sex
                                                 (Antlered/Antlerless),
                                                 1931-2014. Two copies of
                                                 this file were provided
                                                 (a plain copy and a
                                                 "_1_" suffixed copy);
                                                 diffed cell-by-cell
                                                 (Python/xlrd, all 1,933
                                                 rows) and confirmed
                                                 byte-identical in content
                                                 -- only the plain copy is
                                                 used below.
						 
  MD_Pop_1988-2014_State_Eyler.xlsx          -- STATEWIDE deer population
                                                 estimate, one value per
                                                 year, 1988-2014. No
                                                 county field of any kind
                                                 -- not "population is
                                                 missing at the county
                                                 level for some years,"
                                                 the source itself is a
                                                 single 27-row time series.
                                                 NOT imported below -- see
                                                 Section 3.

CHANGELOG:

08/12/2026 — Nicole: First pass adapting VA/WI/OH/NC/MO pilot logic
                     to MD. Harvest harmonized following the OH/MO
                     template (single clean county-year file, static FIPS
                     crosswalk since no source file carries FIPS).
                     Population source is statewide-only with no county
                     resolution at all -- decided to exclude it
                     from the panel rather than broadcast it to every
                     county; documented in Section 3 rather than silently
                     dropped. Final output is harvest-only.

09/15/2026 — Nicole: Cleanup pass, no change to data values. Row count,
                     no-missing check (destring -force-), and crosswalk
                     merge now asserted; 23 x 84 balance and the zero-
                     harvest pattern (antlered zeros only <= 1964,
                     antlerless zeros only <= 1976) pinned. Unexplained
                     column E now listed to the log before it is dropped.
                     Baltimore City note updated with MD DNR (Kevin Lamp)
                     follow-up, pending. Apostrophe note corrected. FIPS
                     crosswalk verified against Census 2020 (23/23).
                     Labels shortened to Stata's 80-char limit (earlier
                     labels were truncated in the saved .dta); long-form
                     documentation moved to -notes-.

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
log using "$codeSTATA/logs/MD_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/MD"
cap mkdir "$dataCLEAN/MD"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

Like OH/NC/MO, no MD source file carries a FIPS code -- the harvest sheet
has county name only. Built here as a static reference table (state FIPS
24, 23 counties -- clean alphabetical numbering 001-047 by 2s, no
out-of-sequence carve-outs the way WI has Menominee or MO has the
Ste. Genevieve/St. Francois swap).

Typed from standard Census county FIPS assignments, not pulled from a
project source file. VERIFIED 09/15/2026: all 23 codes match the Census
2020 county FIPS reference list exactly (source spellings differ from
Census only in spaces/periods, see NOTE below)
https://www2.census.gov/geo/docs/reference/codes2020/cou/st24_md_cou2020.txt

Baltimore City (real FIPS 24510, an independent city, not part of any county) 
does NOT appear in the harvest source and is intentionally EXCLUDED from the 
crosswalk below -- confirmed on inspection, the harvest sheet's county list tops 
out at 23 units with no city entry. Left out rather than added with zero harvest, 
since there is no data to attach to it.

PENDING (MD DNR, Kevin Lamp): Baltimore City harvest is likely FOLDED
INTO Baltimore County's totals rather than absent -- MD only began
tracking Baltimore City separately in 2026. If confirmed, the panel is
unchanged, but this note, the Section 4 notes, and the data appendix
should say "included in Baltimore County (24005)" instead of "not in
source", and the Baltimore County series should be understood to cover
both FIPS units.

NOTE: the source spells multi-word/possessive counties with no spaces and
no periods, but KEEPS apostrophes throughout -- "AnneArundel",
"PrinceGeorge's", "QueenAnne's", "StMary's" (Census: "Anne Arundel",
"Prince George's", "Queen Anne's", "St. Mary's"). The crosswalk below
matches the source's exact spelling; name_clean strips periods and
spaces (not apostrophes), so both forms would resolve to the same key
anyway -- same defensive approach as OH's "VanWert" note.

------------------------------------------------------------------------*/

input str20 county_name str3 fips_suffix
"Allegany"       "001"
"AnneArundel"    "003"
"Baltimore"      "005"
"Calvert"        "009"
"Caroline"       "011"
"Carroll"        "013"
"Cecil"          "015"
"Charles"        "017"
"Dorchester"     "019"
"Frederick"      "021"
"Garrett"        "023"
"Harford"        "025"
"Howard"         "027"
"Kent"           "029"
"Montgomery"     "031"
"PrinceGeorge's" "033"
"QueenAnne's"    "035"
"StMary's"       "037"
"Somerset"       "039"
"Talbot"         "041"
"Washington"     "043"
"Wicomico"       "045"
"Worcester"      "047"
end

gen county_fips = "24" + fips_suffix
drop fips_suffix

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 23

label variable county_fips "MD county FIPS code (5-digit, state+county)"
label variable county_name "County name (source spelling)"
label variable name_clean  "Merge key: county_name upper-cased, trimmed, periods/spaces removed"
label data "MD county FIPS crosswalk, 23 counties (state FIPS 24; excl. Baltimore City)"

save "$dataSTATA/MD/MD_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import & Clean
*==============================================================================

/*------------------------------------------------------------------------

Already county-year long format (County, Year, Antlered, Antlerless) --
no reshape needed, the most direct import of the states so far, matching
OH's "already long, no footer rows" experience rather than VA/WI's wide
sheets.

Confirmed during inspection: perfectly balanced panel, 23 counties x 84 years 
(1931-2014) with zero missing cells and no footer/source-note rows to strip -- 
unlike the recurring "SOURCE:" footer-row problem seen in other states' exports.

------------------------------------------------------------------------*/

import excel "$dataRAW/Deer_Harvest/MD/MD.Harvest.1931-2014.CountySex.Eyler.xls", ///
    sheet("Sheet1") firstrow clear

* Column E is not one of the four documented source columns. Show what is
* in it before dropping (expected: nothing / a stray blank column).
capture confirm string variable E
if !_rc {
    count if strtrim(E) != ""
}
else {
    count if !missing(E)
}
di as txt "non-empty cells in column E: " r(N)
list E if !missing(E) in 1/20
drop E

rename County     county_name
rename Year       year
rename Antlered   harvest_antlered
rename Antlerless harvest_antlerless

destring year, replace force
destring harvest_antlered harvest_antlerless, replace force

* 23 counties x 84 years, zero missing cells (per the comment block above);
* -force- would have turned any text cell into missing, so check.
count
assert r(N) == 23 * 84
assert !missing(year, harvest_antlered, harvest_antlerless)

label variable year                "Harvest year"
label variable county_name         "County name, as reported in source"
label variable harvest_antlered    "Antlered deer harvested"
label variable harvest_antlerless  "Antlerless deer harvested"

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/MD/MD_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* Inspection found no unmatched county strings -- every row must match,
* in both directions.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

label data "MD county-year deer harvest by sex, 1931-2014 (temp)"
order county_fips county_name year harvest_antlered harvest_antlerless

isid county_fips year
count
codebook county_fips, compact
describe

save "$dataSTATA/MD/temp_MD_harvest_1931-2014_raw.dta", replace

*==============================================================================
* SECTION 3: POPULATION DATA - excluded, not imported
*==============================================================================

/*------------------------------------------------------------------------

MD_Pop_1988-2014_State_Eyler.xlsx is a single statewide time series
(Year, Population Estimate), 1988-2014, one value per year -- no county
field, no regional breakdown, nothing to key a county-level merge on even
in principle. This is the state-level-only pattern named in NC's Section 1.

SUPPORTED BY AGENCY: MD DNR (Kevin Lamp, Deer Project Leader) confirmed
county-level population estimates are not feasible for MD due to small
sample sizes.

DECISION (08/12/2026): Not imported anywhere in this script -- MD's final panel 
below is harvest-only, no population variable. Documented here rather than just 
leaving the file untouched with no mention.

------------------------------------------------------------------------*/

*==============================================================================
* SECTION 4: FINALIZE HARVEST-ONLY PANEL
*==============================================================================

/*------------------------------------------------------------------------

No population to merge in (Section 3), so the harvest panel from Section
2 IS the final panel -- this section just re-confirms integrity and saves
to dataCLEAN under the same naming convention the other states use, so it
sits consistently alongside OH/MO/etc. even though there was no merge
step here.

------------------------------------------------------------------------*/

use "$dataSTATA/MD/temp_MD_harvest_1931-2014_raw.dta", clear

order county_fips county_name year harvest_antlered harvest_antlerless

label data "MD county-year deer harvest by sex (antlered/antlerless), 1931-2014"

notes: Source: Eyler county-year file (presumed MD DNR Wildlife & Heritage Service; attribution pending MD DNR confirmation). Balanced 23 counties x 84 years, no missing cells.
notes: Baltimore City (24510) is not in the source or the panel. MD DNR indicates its harvest is likely included in Baltimore County (24005) totals (pending confirmation; tracked separately only from 2026). See do-file Section 1.
notes: Reported zeros are early-period: harvest_antlered == 0 in 423 county-years (all 1931-1964), harvest_antlerless == 0 in 751 (all 1931-1976). Kept as reported.
notes: Harvest-only panel. MD population source is statewide-only (1988-2014) and excluded; MD DNR confirmed county estimates are not feasible (do-file Section 3).

isid county_fips year
assert year >= 1931 & year <= 2014
assert !missing(harvest_antlered, harvest_antlerless)
assert harvest_antlered >= 0 & harvest_antlerless >= 0
count
assert r(N) == 23 * 84
bysort county_fips: assert _N == 84

* zero-harvest pattern (pinned): early years only
assert year <= 1964 if harvest_antlered == 0
assert year <= 1976 if harvest_antlerless == 0

sort county_fips year
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/MD/MD_deer_harmonized_county_year_1931-2014.dta", replace

log close
