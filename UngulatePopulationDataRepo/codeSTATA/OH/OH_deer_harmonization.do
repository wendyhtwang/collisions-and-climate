/*==============================================================================

FILE NAME:   OH_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  Ohio (OH) county-level deer HARVEST and POPULATION harmonization,
          adapted from the VA and WI pilot scripts. OH is the cleanest of
          the three so far: both source files are already county-level,
          already long-format (year x county rows, not wide-by-year like
          WI or VA's harvest sheets), and passed every arithmetic/whitespace
          QC check run during inspection -- no reshape, no footer rows, no
          whitespace bugs. The main judgment calls here are about a few
          genuine (not bug-induced) gaps in the source data -- see inline
          notes.

SOURCE FILES USED:

  PROVENANCE (confirmed): "McCoy" = Clint McCoy, Deer Program
    Administrator, Ohio Department of Natural Resources (ODNR).
    
  Deer_Harvest/OH.Harvest.80-14.CountySex.McCoy.xlsx
                                             -- county harvest by sex/age
                                                 class, 1980-2014
						 
  Deer_Population/OH.PopHarvest.80-14.CountySex.McCoy.xlsx
                                             -- PopulationIndex sheet:
                                                 county pre-hunt population
                                                 index + yearling
                                                 components, 1981-2014.
                                                 (Its HarvestData sheet is
                                                 byte-for-byte identical to
                                                 the harvest file above --
                                                 confirmed during inspection
                                                 -- so it is not re-imported
                                                 here.)

CHANGELOG:

08/10/2026 — Nicole: First pass adapting the VA/WI pilot logic to OH.
                     No reshape needed (source is already long); most of
                     this script is import + clean + merge. Flagged
                     [DECIDE] items are about genuine source-data gaps, not
                     import bugs.

09/16/2026 — Nicole: Clean up pass, no change to data values. Cuyahoga/
                     Ottawa population gap resolved as structural per OH 
		     Department of Natural Resources (Clint McCoy): too few 
		     harvest records to model. Noted ODNR's switch from numeric 
		     pop_target to categorical goals (end year pending). Flagged 
		     a likely label error: pYF + pYM do not sum to 1 (0.70-1.51), 
		     so they are not female/male shares of yearlings -- labels 
		     made neutral pending ODNR confirmation. Asserts added: 
		     88-county crosswalk, 35/34-year balance, unknown-sex 
		     missing exactly 2004-2014, population gaps exactly the 8
                     Cuyahoga/Ottawa rows, all merges. FIPS crosswalk
                     verified against Census 2020 (88/88). Labels shortened
                     to Stata's 80-char limit; long-form documentation moved
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
log using "$codeSTATA/logs/OH_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/OH"
cap mkdir "$dataCLEAN/OH"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

Like WI, no OH source file carries a FIPS code -- both sheets are county
NAME only. Built here as a static reference table (state FIPS 39, 88
counties, standard alphabetical numbering 001-175 by 2s -- no out-of-
sequence carve-outs the way WI's Menominee was).

Typed from standard Census county FIPS assignments, not pulled from a project 
source file -- same caveat as WI's crosswalk (1a). VERIFIED 09/16/2026:
all 88 codes match the Census 2020 county FIPS reference list exactly
https://www2.census.gov/geo/docs/reference/codes2020/cou/st39_oh_cou2020.txt

NOTE: the source files spell Van Wert County as "VanWert" (no space).
name_clean below strips spaces as well as periods/case, specifically so
this one matches -- double-check no other county name legitimately needs
a space preserved before reusing this pattern for another state.

------------------------------------------------------------------------*/

input str20 county_name str3 fips_suffix
"Adams" "001"
"Allen" "003"
"Ashland" "005"
"Ashtabula" "007"
"Athens" "009"
"Auglaize" "011"
"Belmont" "013"
"Brown" "015"
"Butler" "017"
"Carroll" "019"
"Champaign" "021"
"Clark" "023"
"Clermont" "025"
"Clinton" "027"
"Columbiana" "029"
"Coshocton" "031"
"Crawford" "033"
"Cuyahoga" "035"
"Darke" "037"
"Defiance" "039"
"Delaware" "041"
"Erie" "043"
"Fairfield" "045"
"Fayette" "047"
"Franklin" "049"
"Fulton" "051"
"Gallia" "053"
"Geauga" "055"
"Greene" "057"
"Guernsey" "059"
"Hamilton" "061"
"Hancock" "063"
"Hardin" "065"
"Harrison" "067"
"Henry" "069"
"Highland" "071"
"Hocking" "073"
"Holmes" "075"
"Huron" "077"
"Jackson" "079"
"Jefferson" "081"
"Knox" "083"
"Lake" "085"
"Lawrence" "087"
"Licking" "089"
"Logan" "091"
"Lorain" "093"
"Lucas" "095"
"Madison" "097"
"Mahoning" "099"
"Marion" "101"
"Medina" "103"
"Meigs" "105"
"Mercer" "107"
"Miami" "109"
"Monroe" "111"
"Montgomery" "113"
"Morgan" "115"
"Morrow" "117"
"Muskingum" "119"
"Noble" "121"
"Ottawa" "123"
"Paulding" "125"
"Perry" "127"
"Pickaway" "129"
"Pike" "131"
"Portage" "133"
"Preble" "135"
"Putnam" "137"
"Richland" "139"
"Ross" "141"
"Sandusky" "143"
"Scioto" "145"
"Seneca" "147"
"Shelby" "149"
"Stark" "151"
"Summit" "153"
"Trumbull" "155"
"Tuscarawas" "157"
"Union" "159"
"Van Wert" "161"
"Vinton" "163"
"Warren" "165"
"Washington" "167"
"Wayne" "169"
"Williams" "171"
"Wood" "173"
"Wyandot" "175"
end

gen county_fips = "39" + fips_suffix
drop fips_suffix

* Merge key: uppercase, whitespace-trimmed, periods AND spaces stripped --
* the source files spell "Van Wert" as "VanWert" with no space, so spaces
* have to come out on both sides for that one to match.
gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 88

label variable county_fips "OH county FIPS code (5-digit, state+county)"
label variable county_name "County name (Census spelling)"
label variable name_clean  "Merge key: county_name upper-cased, trimmed, periods/spaces removed"
label data "OH county FIPS crosswalk, 88 units (static reference, state FIPS 39)"

save "$dataSTATA/OH/OH_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import & Clean
*==============================================================================

/*------------------------------------------------------------------------

Already county-year-sex/age long format (Year, County, Buck, Button, Doe,
Unknown, Total) -- no reshape needed, unlike VA's wide land_ownership
sheets or WI's wide year-by-column sheets. This is the most direct import
of the three states so far.

Confirmed during inspection: Total == Buck + Button + Doe + Unknown for
all 3,080 rows with no exceptions, and no whitespace/footer-row issues in
county_name. The `assert` below re-checks this on import rather than just
trusting the inspection pass.

KNOWN GAP (not a bug -- genuine in the source): `Unknown` is populated
1980-2003 and is entirely missing 2004-2014. Left as missing rather than
recoded to 0, since 0 would falsely claim "zero unknown-sex harvest" when
the truth is "this category stopped being tracked." The Total column
still reflects Buck+Button+Doe only for 2004+, which the assert below
accounts for with `missing(harvest_unknown)`.

------------------------------------------------------------------------*/

import excel "$dataRAW/Deer_Harvest/OH/OH.Harvest.80-14.CountySex.McCoy.xlsx", ///
    sheet("HarvestData") firstrow clear

rename Year year
rename County county_name
rename Buck harvest_buck
rename Button harvest_button
rename Doe harvest_doe
rename Unknown harvest_unknown
rename Total harvest_total

* QC: re-confirm the arithmetic identity found during inspection. Treats
* missing harvest_unknown as 0 for the sum, matching the 2004+ reality
* that Total was never counting a category that no longer exists.
gen _harvest_check = harvest_buck + harvest_button + harvest_doe + ///
    cond(missing(harvest_unknown), 0, harvest_unknown)
assert _harvest_check == harvest_total
drop _harvest_check

* The identity above is only safe if unknown is missing EXACTLY 2004-2014
* (never a stray blank in 1980-2003) -- check that, and the row count.
assert missing(harvest_unknown) == (year >= 2004)
assert !missing(harvest_buck, harvest_button, harvest_doe, harvest_total)
count
assert r(N) == 88 * 35

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/OH/OH_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* Inspection found no unmatched county strings (VanWert handled by
* name_clean) -- every row must match, in both directions.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

label variable county_fips       "OH county FIPS code (from crosswalk merge)"
label variable county_name       "County name, as reported in source"
label variable year              "Harvest year"
label variable harvest_buck      "Adult male (buck) deer harvested"
label variable harvest_button    "Button buck (male fawn) deer harvested"
label variable harvest_doe       "Doe (female) deer harvested"
label variable harvest_unknown   "Unknown-sex deer harvested (tracked 1980-2003; missing 2004-2014)"
label variable harvest_total     "Total deer harvested (= buck+button+doe+unknown when unknown is tracked)"
label data "OH county-year deer harvest by sex/age class, 1980-2014 (temp)"

order county_fips county_name year harvest_buck harvest_button harvest_doe harvest_unknown harvest_total

isid county_fips year
count
codebook county_fips, compact
describe

save "$dataSTATA/OH/temp_OH_harvest_1980-2014_raw.dta", replace

*==============================================================================
* SECTION 3: POPULATION DATA - Import & Clean
*==============================================================================

/*------------------------------------------------------------------------

PopulationIndex sheet, also already county-year long format. Imported by
column letter rather than firstrow, since the source headers include
spaces and a slash ("pYM / pYF") that Stata would otherwise mangle into
an unpredictable variable name -- same defensive approach used for WI's
messy multi-row header (2a-i).

Column contents (confirmed during inspection):
  
  C: pYF   -- yearling proportion, female (source header "pYF")
  
  D: pYM   -- yearling proportion, male (source header "pYM")
  
  [VERIFY with ODNR] These were first read as the shares of YEARLINGS
  that are female/male, but pYF + pYM does not sum to 1 (range 0.70-1.51
  across 1981-2014; means 0.42 and 0.62). The more likely meaning is the
  proportion of the FEMALE harvest that is yearlings (pYF) and of the
  MALE harvest that is yearlings (pYM) -- standard inputs to a sex-age-
  kill reconstruction. Labels below are kept neutral until confirmed.
  
  E: pYM / pYF -- confirmed exactly equal to D/C for every non-missing
              row (redundant, purely derived); kept as an optional
              cross-check variable rather than dropped outright.
  
  F: PreHuntPop -- pre-hunt population index/estimate
  
  G: Target Pop (2002-present) -- management target population,
              populated 2002 onward only (matches its own header label,
              confirmed on import below). ODNR (Clint McCoy) reports that
              numeric targets were later DISCONTINUED in favor of
              increase/decrease/stabilize goal categories set from
              human-dimensions surveys; the year of the switch is pending
              from ODNR. All 2002-2014 values here are populated.
  
  H: (blank, no header, no data throughout -- not imported)

KNOWN GAP (structural -- confirmed by ODNR): PreHuntPop and pYF (and
therefore E) are missing for Cuyahoga 1981-1984 and Ottawa 1985-1988 (8
rows total); pYM IS populated in those rows. Per Clint McCoy (ODNR), these
county-years had too few harvest records to model -- a structural gap,
not a data error; no backfill exists. Left as missing, pinned below.

------------------------------------------------------------------------*/

import excel "$dataRAW/Deer_Population/OH/OH.PopHarvest.80-14.CountySex.McCoy.xlsx", ///
    sheet("PopulationIndex") cellrange(A2) clear

rename A year
rename B county_name
rename C prop_yearling_female
rename D prop_yearling_male
rename E sexratio_ym_yf_check
rename F pop_prehunt
rename G pop_target

drop H

* QC: re-confirm the redundant-ratio relationship found during inspection,
* skipping the genuine missing-data rows (Cuyahoga/Ottawa gaps above).
gen _ratio_diff = abs(sexratio_ym_yf_check - (prop_yearling_male / prop_yearling_female))
assert _ratio_diff < 1e-6 if !missing(sexratio_ym_yf_check)
drop _ratio_diff

* QC: confirm pop_target's 2002-present claim matches the actual data,
* not just the header label.
assert missing(pop_target) if year < 2002
assert !missing(pop_target) if year >= 2002

* Row count, and the structural gap is exactly the 8 Cuyahoga/Ottawa rows
count
assert r(N) == 88 * 34
gen byte _gap = (upper(strtrim(county_name)) == "CUYAHOGA" & inrange(year, 1981, 1984)) ///
    | (upper(strtrim(county_name)) == "OTTAWA" & inrange(year, 1985, 1988))
count if _gap
assert r(N) == 8
assert missing(pop_prehunt) == _gap
assert missing(prop_yearling_female) == _gap
assert !missing(prop_yearling_male)
drop _gap

gen name_clean = upper(subinstr(subinstr(strtrim(county_name), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/OH/OH_county_crosswalk.dta", ///
    keepusing(county_fips) gen(_merge_xwalk)
list county_name year if _merge_xwalk != 3
* Same as Section 2 -- every row must match.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean

label variable county_fips            "OH county FIPS code (5-digit string, state+county)"
label variable county_name            "County name, as reported in source"
label variable year                   "Population estimate year"
label variable prop_yearling_female   "pYF: yearling proportion, female (source; meaning see notes)"
label variable prop_yearling_male     "pYM: yearling proportion, male (source; meaning see notes)"
label variable sexratio_ym_yf_check   "pYM/pYF as reported (= pYM/pYF exactly; QC cross-check only)"
label variable pop_prehunt            "Pre-hunt deer population index/estimate (ODNR)"
label variable pop_target             "Management target population (populated 2002-2014 only)"
label data "OH county-year deer population index + yearling components, 1981-2014 (temp)"

order county_fips county_name year pop_prehunt pop_target prop_yearling_female prop_yearling_male sexratio_ym_yf_check

isid county_fips year
count
codebook county_fips, compact
describe

save "$dataSTATA/OH/temp_OH_population_1981-2014_raw.dta", replace

*==============================================================================
* SECTION 4: BUILD THE COUNTY-YEAR PANEL
*==============================================================================

/*------------------------------------------------------------------------

Spine: the harvest panel (Section 2), county_fips x year, 1980-2014.
Population (Section 3) covers 1981-2014 -- one year narrower than harvest
on the front end, since McCoy's population series doesn't start until
1981. `merge m:1` matches VA/WI's discipline: let the harvest panel
define the year range, don't extend it to accommodate population without
a sign-off.

Expected _merge_pop result: every 1980 row is master-only (population
doesn't start until 1981); every 1981-2014 row should match, since both
sources report the same 88 counties for their full overlapping range.

------------------------------------------------------------------------*/

use "$dataSTATA/OH/temp_OH_harvest_1980-2014_raw.dta", clear
isid county_fips year

merge 1:1 county_fips year ///
    using "$dataSTATA/OH/temp_OH_population_1981-2014_raw.dta", ///
    keepusing(pop_prehunt pop_target prop_yearling_female prop_yearling_male sexratio_ym_yf_check) ///
    gen(_merge_pop)
* Harvest-only rows must be exactly 1980 (population starts 1981), and
* there must be no population-only rows.
assert _merge_pop != 2
assert (_merge_pop == 1) == (year == 1980)
drop _merge_pop

order county_fips county_name year ///
    harvest_buck harvest_button harvest_doe harvest_unknown harvest_total ///
    pop_prehunt pop_target prop_yearling_female prop_yearling_male sexratio_ym_yf_check

label data "OH county-year deer harvest & population panel, 1980-2014 (ODNR, McCoy)"

notes: Source: Ohio DNR (Clint McCoy, Deer Program Administrator). Population fields are missing for 1980 (population series starts 1981).
notes pop_prehunt: Missing for Cuyahoga 1981-1984 and Ottawa 1985-1988: too few harvest records to model (structural, confirmed by ODNR). pYF is missing in the same 8 rows; pYM is populated.
notes pop_target: Numeric management target, populated 2002-2014. ODNR later replaced numeric targets with increase/decrease/stabilize goal categories (switch year pending from ODNR).
notes prop_yearling_female: pYF and pYM do not sum to 1 (0.70-1.51), so they are not female/male shares of yearlings; most likely the yearling share of the female (pYF) and male (pYM) harvest. Pending ODNR confirmation.
notes harvest_unknown: Unknown-sex category tracked 1980-2003 only; missing (not zero) 2004-2014. harvest_total equals buck + button + doe + unknown (unknown treated as 0 from 2004).

isid county_fips year
assert year >= 1980 & year <= 2014
count
assert r(N) == 88 * 35
bysort county_fips: assert _N == 35
sort county_fips year
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/OH/OH_deer_harmonized_county_year_1980-2014.dta", replace

log close
