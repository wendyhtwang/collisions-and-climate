/*==============================================================================

FILE NAME:   KY_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  Kentucky (KY) county-level deer HARVEST harmonization, adapted
          from the VA/WI/OH/NC/MO/MD pilot scripts. Two county-level
          harvest files (total, and a buck-only subset) merge cleanly
          into a wide county-year panel -- no reshape surprises, no
          footer-row bugs, and both files' county sums match their own
          footer totals exactly (see Section 2). One source-level anomaly: 
	  McCreary County's buck harvest EXCEEDS its total harvest in 7 years 
	  (2006, 2008-2013) -- see Section 4.
	  
          KY's population source is the same state-level-only pattern MD hit 
	  first: a single statewide time series with no county field at all. Per 
	  the precedent MD's Section 3 set and confirmed for KY specifically, it 
	  is documented and EXCLUDED rather than merged in. This script 
	  therefore produces a HARVEST-ONLY county-year panel; KY carries no 
	  population variable.

SOURCE FILES USED:

  PROVENANCE [open]: "Sams" is a surname only -- presumed KDFWR (KY Department
    of Fish & Wildlife Resources), affiliation not confirmed.
    
  KY.Harvest.1990-2015.County.Sams.xlsx      -- county TOTAL harvest,
                                                 wide by year, 1990-2016
                                                 (2016 column present in
                                                 header only, entirely
                                                 empty -- see Section 2).
						 
  KY.BuckHarvest.1999-2015.County.Sams.xlsx  -- county BUCK-ONLY harvest,
                                                 wide by year, 1999-2015.
                                                 Subset of the years/scope
                                                 covered by the total-
                                                 harvest file above.
						 
  KY_Pop_99-15_State_Sams.xlsx               -- STATEWIDE deer population
                                                 estimate, one value per
                                                 year, 1999-2015. No
                                                 county field of any kind
                                                 -- not "population is
                                                 missing at the county
                                                 level for some years,"
                                                 the source itself is a
                                                 single 17-row time series.
                                                 NOT imported below -- see
                                                 Section 3.

CHANGELOG:

08/12/2026 — Nicole: First pass adapting VA/WI/OH/NC/MO/MD pilot logic
                     to KY. Harvest harmonized following the OH template
                     (wide subgroup columns merged on county_fips/year,
                     static FIPS crosswalk since no source file carries
                     FIPS). Population source is statewide-only with no
                     county resolution at all, matching MD exactly --
                     decided to exclude it from the panel per the MD
                     precedent rather than broadcast it to every county;
                     documented in Section 3 rather than silently dropped.
                     Final output is harvest-only (total + buck).

09/15/2026 — Nicole: Clean up pass, no change to data values. Footer-total
                     QC for both files now asserts exact matches (was
                     list-only). Row counts, no-missing checks, crosswalk
                     merges, and the 1990-1998 buck gap now asserted.
                     Documented and pinned a source anomaly: McCreary
                     County buck > total in 7 years (Section 4); also pinned the 
		     14 zero-total county-years (all 1990-1998, six eastern 
		     counties). FIPS crosswalk verified against Census 2020 
		     (120/120). Labels shortened to Stata's 80-char limit 
		     (earlier labels were truncated in the saved .dta); 
		     long-form documentation moved to -notes-.

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
log using "$codeSTATA/logs/KY_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/KY"
cap mkdir "$dataCLEAN/KY"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

Like OH/NC/MO/MD, no KY source file carries a FIPS code -- both harvest
sheets have county name only. Built here as a static reference table
(state FIPS 21, 120 counties -- clean alphabetical numbering 001-239 by
2s, no out-of-sequence carve-outs the way VA has independent cities or
WI has Menominee).

Typed from standard Census county FIPS assignments, not pulled from a
project source file. VERIFIED 09/15/2026: all 120 codes match the Census
2020 county FIPS reference list exactly (no mismatches, no missing codes)
https://www2.census.gov/geo/docs/reference/codes2020/cou/st21_ky_cou2020.txt

NOTE: source files disagree on the case of one county -- BuckHarvest
spells it "LaRue", Harvest spells it "Larue" (which is also the Census
2020 spelling; the crosswalk below types "LaRue"). Confirmed on inspection
this is the only county with a casing mismatch between the two files (all
other 119 names match exactly, including the Mc-prefixed counties --
McCracken, McCreary, McLean). Not special-cased here the way OH's
"VanWert" note is, because name_clean below already uppercases before
matching, so all spellings resolve to the same merge key without any
extra fix.

------------------------------------------------------------------------*/

input str20 county_name str3 fips_suffix
"Adair"        "001"
"Allen"        "003"
"Anderson"     "005"
"Ballard"      "007"
"Barren"       "009"
"Bath"         "011"
"Bell"         "013"
"Boone"        "015"
"Bourbon"      "017"
"Boyd"         "019"
"Boyle"        "021"
"Bracken"      "023"
"Breathitt"    "025"
"Breckinridge" "027"
"Bullitt"      "029"
"Butler"       "031"
"Caldwell"     "033"
"Calloway"     "035"
"Campbell"     "037"
"Carlisle"     "039"
"Carroll"      "041"
"Carter"       "043"
"Casey"        "045"
"Christian"    "047"
"Clark"        "049"
"Clay"         "051"
"Clinton"      "053"
"Crittenden"   "055"
"Cumberland"   "057"
"Daviess"      "059"
"Edmonson"     "061"
"Elliott"      "063"
"Estill"       "065"
"Fayette"      "067"
"Fleming"      "069"
"Floyd"        "071"
"Franklin"     "073"
"Fulton"       "075"
"Gallatin"     "077"
"Garrard"      "079"
"Grant"        "081"
"Graves"       "083"
"Grayson"      "085"
"Green"        "087"
"Greenup"      "089"
"Hancock"      "091"
"Hardin"       "093"
"Harlan"       "095"
"Harrison"     "097"
"Hart"         "099"
"Henderson"    "101"
"Henry"        "103"
"Hickman"      "105"
"Hopkins"      "107"
"Jackson"      "109"
"Jefferson"    "111"
"Jessamine"    "113"
"Johnson"      "115"
"Kenton"       "117"
"Knott"        "119"
"Knox"         "121"
"LaRue"        "123"
"Laurel"       "125"
"Lawrence"     "127"
"Lee"          "129"
"Leslie"       "131"
"Letcher"      "133"
"Lewis"        "135"
"Lincoln"      "137"
"Livingston"   "139"
"Logan"        "141"
"Lyon"         "143"
"McCracken"    "145"
"McCreary"     "147"
"McLean"       "149"
"Madison"      "151"
"Magoffin"     "153"
"Marion"       "155"
"Marshall"     "157"
"Martin"       "159"
"Mason"        "161"
"Meade"        "163"
"Menifee"      "165"
"Mercer"       "167"
"Metcalfe"     "169"
"Monroe"       "171"
"Montgomery"   "173"
"Morgan"       "175"
"Muhlenberg"   "177"
"Nelson"       "179"
"Nicholas"     "181"
"Ohio"         "183"
"Oldham"       "185"
"Owen"         "187"
"Owsley"       "189"
"Pendleton"    "191"
"Perry"        "193"
"Pike"         "195"
"Powell"       "197"
"Pulaski"      "199"
"Robertson"    "201"
"Rockcastle"   "203"
"Rowan"        "205"
"Russell"      "207"
"Scott"        "209"
"Shelby"       "211"
"Simpson"      "213"
"Spencer"      "215"
"Taylor"       "217"
"Todd"         "219"
"Trigg"        "221"
"Trimble"      "223"
"Union"        "225"
"Warren"       "227"
"Washington"   "229"
"Wayne"        "231"
"Webster"      "233"
"Whitley"      "235"
"Wolfe"        "237"
"Woodford"     "239"
end

gen county_fips = "21" + fips_suffix
drop fips_suffix

* Merge key: uppercase, whitespace-trimmed, periods AND spaces stripped --
* absorbs the LaRue/Larue casing mismatch noted above for free.
gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 120

label variable county_fips "KY county FIPS code (5-digit, state+county)"
label variable county_name "County name (Census spelling, except LaRue = Census Larue)"
label variable name_clean  "Merge key: county_name upper-cased, trimmed, periods/spaces removed"
label data "KY county FIPS crosswalk, 120 units (static reference, state FIPS 21)"

save "$dataSTATA/KY/KY_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import, Reshape & Clean
*==============================================================================

/*------------------------------------------------------------------------

Two source files, both wide-by-year, county x year:

  - Harvest: TOTAL harvest, 1990-2016 (2016 column is a bare header with
    zero populated cells for all 120 counties -- confirmed during
    inspection, not just a spot gap -- dropped below).
    
  - BuckHarvest: BUCK-ONLY harvest, 1999-2015.

Each needs the same rename-loop + `reshape long` treatment as WI/NC's
year-column sheets, not a straight firstrow import: bare numeric year
headers ("1990"...) mangle unpredictably under `import excel ..., firstrow`. 
Imported without firstrow instead, with the header row read in as an ordinary 
observation and dropped explicitly alongside the "Total"/"Total Harvest" 
footer row -- same standing footer-row pattern seen in VA/WI/NC.

Confirmed during inspection (pass over all years): for both files, the 
county-sum-by-year matches the sheet's own footer Total row exactly, every 
year, zero exceptions -- the QC blocks below re-check this rather than just 
trusting the inspection pass.

Output structure: harvest_total and harvest_buck end up as separate wide
columns on the same county-year row (OH's harvest_buck/harvest_total
naming), not a long subgroup indicator -- buck is a strict subset of
total, not an alternative categorization of it. harvest_buck is missing
for 1990-1998, before the buck-only file's coverage starts (genuine gap,
not a bug -- see Section 4 note).

------------------------------------------------------------------------*/

*--------------------------------- 2a. -----------------------------------

import excel "$dataRAW/Deer_Harvest/KY/KY.Harvest.1990-2015.County.Sams.xlsx", ///
    sheet("Sheet1") cellrange(A2:AB123) clear

rename A county_name
ds county_name, not
local yearvars `r(varlist)'
local yr = 1990
foreach v of local yearvars {
    rename `v' h`yr'
    local yr = `yr' + 1
}

drop if county_name == "County"
drop if county_name == "Total Harvest"

* Stash the footer Total row for the QC check below, before the header/
* footer drop above takes it out for good.
preserve
    import excel "$dataRAW/Deer_Harvest/KY/KY.Harvest.1990-2015.County.Sams.xlsx", ///
        sheet("Sheet1") cellrange(A2:AB123) clear
    keep if A == "Total Harvest"
    drop A
    ds
    local yearvars `r(varlist)'
    local yr = 1990
    foreach v of local yearvars {
        rename `v' h`yr'
        local yr = `yr' + 1
    }
    gen _dummy = 1
    reshape long h, i(_dummy) j(year)
    rename h harvest_total_reported
    drop _dummy
    tempfile statetotals_total
    save `statetotals_total'
restore

* Confirmed empty in inspection -- re-check rather than assume
quietly count if !missing(h2016)
assert r(N) == 0
drop h2016

count
assert r(N) == 120                  // header + footer dropped
destring h*, replace force
reshape long h, i(county_name) j(year)
rename h harvest_total
* -force- above would turn any text cell into missing; audit found none.
assert !missing(harvest_total)

* QC: county-sum-by-year vs. the sheet's own Total Harvest footer row
preserve
    collapse (sum) harvest_total, by(year)
    merge 1:1 year using `statetotals_total', gen(_m)
    * every data year 1990-2015 must match; the footer stash also carries
    * the empty 2016 column (using-only), which is dropped here
    assert _m == 3 if year <= 2015
    assert _m == 2 if year == 2016
    drop if _m == 2
    drop _m
    gen _diff = harvest_total - harvest_total_reported
    list year harvest_total harvest_total_reported _diff if _diff != 0, sep(0)
    assert _diff == 0
restore

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/KY/KY_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* name_clean absorbs the LaRue/Larue casing mismatch, and inspection found
* no other unmatched county strings -- every row must match.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

isid county_fips year
count
assert r(N) == 120 * 26
codebook county_fips, compact

save "$dataSTATA/KY/temp_KY_harvest_total_1990-2015.dta", replace

*--------------------------------- 2b. -----------------------------------

import excel "$dataRAW/Deer_Harvest/KY/KY.BuckHarvest.1999-2015.County.Sams.xlsx", ///
    sheet("Sheet1") cellrange(A1:R122) clear

rename A county_name
ds county_name, not
local yearvars `r(varlist)'
local yr = 1999
foreach v of local yearvars {
    rename `v' h`yr'
    local yr = `yr' + 1
}

drop if missing(county_name)
drop if county_name == "Total"

* Stash the footer Total row for the QC check below
preserve
    import excel "$dataRAW/Deer_Harvest/KY/KY.BuckHarvest.1999-2015.County.Sams.xlsx", ///
        sheet("Sheet1") cellrange(A1:R122) clear
    keep if A == "Total"
    drop A
    ds
    local yearvars `r(varlist)'
    local yr = 1999
    foreach v of local yearvars {
        rename `v' h`yr'
        local yr = `yr' + 1
    }
    gen _dummy = 1
    reshape long h, i(_dummy) j(year)
    rename h harvest_buck_reported
    drop _dummy
    tempfile statetotals_buck
    save `statetotals_buck'
restore

count
assert r(N) == 120                  // header + footer dropped
destring h*, replace force
reshape long h, i(county_name) j(year)
rename h harvest_buck
* -force- above would turn any text cell into missing; audit found none.
assert !missing(harvest_buck)

* QC: county-sum-by-year vs. the sheet's own Total footer row
preserve
    collapse (sum) harvest_buck, by(year)
    merge 1:1 year using `statetotals_buck', gen(_m)
    assert _m == 3                     // all 17 years, 1999-2015
    drop _m
    gen _diff = harvest_buck - harvest_buck_reported
    list year harvest_buck harvest_buck_reported _diff if _diff != 0, sep(0)
    assert _diff == 0
restore

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/KY/KY_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* Same reasoning as 2a -- every row must match.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

isid county_fips year
count
assert r(N) == 120 * 17
codebook county_fips, compact

save "$dataSTATA/KY/temp_KY_harvest_buck_1999-2015.dta", replace

*--------------------------------- 2c. -----------------------------------

use "$dataSTATA/KY/temp_KY_harvest_total_1990-2015.dta", clear
merge 1:1 county_fips year using "$dataSTATA/KY/temp_KY_harvest_buck_1999-2015.dta", ///
    keepusing(harvest_buck) gen(_merge_buck)
* Total-only rows must be exactly 1990-1998, before the buck-only file's
* coverage begins (see Section 4), and there must be no buck-only rows.
assert _merge_buck != 2
assert (_merge_buck == 1) == (year < 1999)
drop _merge_buck

label variable county_fips    "KY county FIPS code (5-digit string, state+county)"
label variable county_name    "County name, as reported in source"
label variable year           "Harvest year"
label variable harvest_total  "Total deer harvested, all sex/age combined"
label variable harvest_buck   "Adult male (buck) deer harvested; missing 1990-1998 (not tracked)"
label data "KY county-year deer harvest (total + buck), temp"

order county_fips county_name year harvest_total harvest_buck

isid county_fips year
count
codebook county_fips, compact
describe

save "$dataSTATA/KY/temp_KY_harvest_1990-2015_raw.dta", replace

*==============================================================================
* SECTION 3: POPULATION DATA - excluded, not imported
*==============================================================================

/*------------------------------------------------------------------------

KY_Pop_99-15_State_Sams.xlsx is a single statewide time series (Year,
Total Pop Estimate), 1999-2015, one value per year -- no county field, no
regional breakdown, nothing to key a county-level merge on even in
principle. This is the exact state-level-only pattern MD's Section 3
already worked through, and currently the state-level series is left out of the 
panel entirely following the MD precedent directly. Not imported anywhere in 
this script -- KY's final panel below is harvest-only, no population variable. 
Documented here rather than just leaving the file untouched with no mention.

------------------------------------------------------------------------*/

*==============================================================================
* SECTION 4: FINALIZE HARVEST-ONLY PANEL
*==============================================================================

/*------------------------------------------------------------------------

No population to merge in (Section 3), so the harvest panel from Section
2 IS the final panel -- this section just re-confirms integrity and saves
to dataCLEAN under the same naming convention the other states use.

harvest_buck is missing for 1990-1998 (buck-only file starts 1999; harvest_total 
covers the full 1990-2015 range) -- a genuine source coverage gap, not an import 
bug. Left as missing rather than recoded to 0, matching OH's treatment of its 
own Unknown-harvest coverage gap: missing means "not tracked yet," 0 would 
falsely claim "zero buck harvest" for years where bucks plainly were being taken. 

McCreary County (21147): harvest_buck EXCEEDS harvest_total in 7 county-years -- 
2006 (286 vs 281), 2008 (314 vs 171), 2009 (271 vs 162), 2010 (230 vs 107), 2011 
(352 vs 156), 2012 (289 vs 221), 2013 (296 vs 252). Buck is a strict subset of 
total, so this is impossible as reported. McCreary's TOTAL series dips to 107-
252 in exactly these years while its buck series stays smooth (217-352) and 
neighboring counties (Whitley, Wayne, Pulaski, Bell) show no such dip -- the 
total column looks like the bad one. Both files' footers still reconcile exactly, 
so the error is in the source spreadsheet, not the import. Retained as reported 
(no rows adjusted); pinned by assert below.

NOTE: 14 county-years report harvest_total == 0, all in 1990-1998, all
in six eastern counties (Estill, Knox, Leslie, Magoffin, Perry, Pike) --
plausibly closed or restricted seasons in those years (not verified);
retained as reported zeros (outside the 2005-2014 regression window).

------------------------------------------------------------------------*/

use "$dataSTATA/KY/temp_KY_harvest_1990-2015_raw.dta", clear

order county_fips county_name year harvest_total harvest_buck

label data "KY county-year deer harvest (total + buck), 1990-2015 (source: Sams)"

notes harvest_buck: Missing 1990-1998, before the buck-only source file begins (not zero). McCreary County reports buck > total in 2006 and 2008-2013; retained as reported, see do-file Section 4.
notes harvest_total: County sums match the source footer totals exactly in every year. 14 reported zeros, all 1990-1998 in Estill, Knox, Leslie, Magoffin, Perry, Pike. McCreary 2006 and 2008-2013 totals are below that county buck harvest (see do-file Section 4).
notes: Harvest-only panel. KY population source is a statewide-only series (1999-2015) with no county field; excluded per MD precedent (do-file Section 3).

isid county_fips year
assert year >= 1990 & year <= 2015
assert !missing(harvest_total)
assert harvest_total >= 0
assert harvest_buck >= 0 if !missing(harvest_buck)
assert missing(harvest_buck) == (year < 1999)
count
assert r(N) == 120 * 26

* McCreary buck > total: exactly these 7 rows, nothing else
count if harvest_buck > harvest_total & !missing(harvest_buck)
assert r(N) == 7
assert county_fips == "21147" & inlist(year, 2006, 2008, 2009, 2010, 2011, 2012, 2013) ///
    if harvest_buck > harvest_total & !missing(harvest_buck)

* 14 reported zero totals, all 1990-1998
count if harvest_total == 0
assert r(N) == 14
assert year <= 1998 if harvest_total == 0

sort county_fips year
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/KY/KY_deer_harmonized_county_year_1990-2015.dta", replace

log close
