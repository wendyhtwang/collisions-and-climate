/*==============================================================================

FILE NAME:   VA_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel — 
	 Deer Harvest/Population Harmonization
	 
CURRENT LEAD: Nicole Martinez

PURPOSE:  Pilot script harmonizing Virginia (VA) county-level deer HARVEST
          and POPULATION data into a single county-year panel. VA was chosen
          as the pilot state because both datasets are compiled by the same
          source (Knox), are county-level, and passed the automated audit
          with zero flagged mismatches or duplicates.

          Once this logic is verified against real output, it will be
          generalized into a `foreach state in ...` loop (Stage 7-equivalent
          of the DVC pipeline) to run across all deer states.
  
CHANGELOG:
		     
08/05/2026 — Nicole: First passs of a pilot script created. VA deer harvest 
                     data imported & cleaned (Section 1). Section 2 (population 
		     data) and Section 3 (final county-year panel merge) added.
		     
		     * See inline [DECIDE] notes for judgment calls -- 
		     county/city name conflicts (Bedford/Fairfax/Franklin/
		     Richmond/Roanoke) and which management-plan sheets were 
		     deliberately left out of the panel.
		     
08/06/2026 — Nicole: Going through first pass to make edits/troubleshoot errors.
                     Also addressing the [DECIDE] judgement calls
		     
==============================================================================*/

/*------------------------------------------------------------------------

BEFORE YOU RUN THIS:

  1. Open VA.Harvest.1947-2014.CountySex.Knox.xlsx in Excel (or `import
     excel ..., describe` in Stata — see Stage 1 below) and note:
       - the exact sheet name(s) — multi-sheet workbooks need `sheet("name")`
       - which row the header is on (`cellrange` may be needed if there's a
         title row above the actual header)
       - exact column names/headers for county, year, and each harvest
         category (antlered/fawn/female/unknown per the audit notes)
       - how county names are formatted (e.g. "Fairfax County" vs "Fairfax"
         vs "FAIRFAX" — this determines your cleaning step in Stage 3)
       - whether the data is in "wide" format (one column per year) or
         "long" format (one row per county-year) — this determines whether
         you need `reshape long` in Stage 3

  2. Do the same for VA.PopGoal.1999-2015.County.Knox.xlsx (Stage 2/4).

  3. [DECIDE] Check VA.Deer management plan.2006-2015.Knox.pdf and
     VA.Deer pop status.2014.pdf — these are PDFs with population content
     that the audit flagged as covering overlapping years/geography. Confirm
     with Eyal/Wendy whether these are redundant with the clean .xlsx or
     contain something (e.g. city-level detail) worth extracting too.

  Fill in the bracketed placeholders below as you go.
  
------------------------------------------------------------------------*/

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

* Log file — keeps a full record of console output, useful when something
* breaks three stages later and you need to see what happened upstream
cap mkdir "$codeSTATA/logs"
log using "$codeSTATA/logs/VA_deer_harmonization.log", replace text

*==============================================================================
* SECTION 1: HARVEST DATA - Import & Clean
*==============================================================================

* ---------------------------------- 1a. --------------------------------------

* First pass: just look at what's in the file before importing anything.
* `describe` after `import excel` with no `firstrow`/`clear` peeks at sheet
* structure without loading data — the Stata equivalent of readxl::excel_sheets()
* plus a quick glance at readr::spec().

import excel "$dataRAW/Deer_Harvest/VA/VA.Harvest.1947-2014.CountySex.Knox.xlsx"
describe
browse

* Total: note row above header
import excel "$dataRAW/Deer_Harvest/VA/VA.Harvest.1947-2014.CountySex.Knox.xlsx", ///
    sheet("Total") cellrange(A2) firstrow clear
gen land_ownership = "Total"
save "$dataSTATA/VA/temp_VA_harvest_1947-2014_total.dta", replace

* Private: header is already row 1, no offset needed
import excel "$dataRAW/Deer_Harvest/VA/VA.Harvest.1947-2014.CountySex.Knox.xlsx", ///
    sheet("Private") firstrow clear
gen land_ownership = "Private"
save "$dataSTATA/VA/temp_VA_harvest_1947-2014_private.dta", replace

* Public: note row above header
import excel "$dataRAW/Deer_Harvest/VA/VA.Harvest.1947-2014.CountySex.Knox.xlsx", ///
    sheet("Public") cellrange(A2) firstrow clear
gen land_ownership = "Public"

* Worth preserving this caveat as a note rather than discarding it — it's a
* real data-quality flag about 3 specific counties' public-land kill counts
notes: Source file caveat (Public sheet): public land deer kill data for ///
    Caroline, Nottoway, and Stafford counties may be unreliable; these are ///
    kept to capture Fort AP Hill, Fort Pickett, and Quantico military lands.

save "$dataSTATA/VA/temp_VA_harvest_1947-2014_public.dta", replace

* Stack all three
use "$dataSTATA/VA/temp_VA_harvest_1947-2014_total.dta", clear
append using "$dataSTATA/VA/temp_VA_harvest_1947-2014_private.dta"
append using "$dataSTATA/VA/temp_VA_harvest_1947-2014_public.dta"

describe
browse

* Rename to match project conventions
rename County        county_fips
rename CountyName    county_name
rename Year          year
rename AntleredMales harvest_antlered_male
rename MaleFawns     harvest_fawn_male
rename Females       harvest_female
rename Unknown       harvest_unknown

* Year imported as string (Excel quirk) — convert now that it has a real name
destring year, replace

* Standardized name key -- uppercase, whitespace trimmed. Kept on every
* harvest/population dataset so name-based joins are consistent project-wide.
gen name_clean = upper(strtrim(county_name))

* Variable labels (documentation that travels with the .dta file)
label variable county_fips           "VA county FIPS code (3-digit, state-level)"
label variable county_name           "County name"
label variable name_clean            "county_name, uppercased and trimmed"
label variable year                  "Harvest year"
label variable harvest_antlered_male "Antlered male deer harvested"
label variable harvest_fawn_male     "Male fawn/button buck deer harvested"
label variable harvest_female        "Female deer harvested"
label variable harvest_unknown       "Deer harvested, sex/age unknown"
label variable land_ownership        "Land ownership: aggregated Total or Private/Public"

* Dataset-level label (shows in `describe` header, useful once you have many .dta
* files sitting in dataSTATA/ and need to tell them apart at a glance)
label data "VA county-year deer harvest by land ownership, 1947-2014 (source: Knox)"

describe
browse

save "$dataSTATA/VA/temp_VA_harvest_1947-2014_raw.dta", replace

* ---------------------------------- 1b. --------------------------------------

import excel "$dataRAW/Deer_Harvest/VA/VA.BuckKillIndex.1994-2014.County.Knox.xlsx", ///
    sheet("Private") cellrange(A2) firstrow clear
describe
browse

* Private
import excel "$dataRAW/Deer_Harvest/VA/VA.BuckKillIndex.1994-2014.County.Knox.xlsx", ///
    sheet("Private") cellrange(A2) firstrow clear

local yr = 1994
foreach v in C D E F G H I J K L M N O P Q R S T U V W {
    rename `v' bki`yr'
    local yr = `yr' + 1
}

rename County     county_fips
rename CountyName county_name

* Wide -> long: one row per county-year instead of one row per county with 21 
* year-columns
reshape long bki, i(county_fips) j(year)
rename bki buck_kill_index

gen land_ownership = "Private"
save "$dataSTATA/VA/temp_VA_bki_1994-2014_private.dta", replace

* Public (no title row here, so no cellrange offset needed)
import excel "$dataRAW/Deer_Harvest/VA/VA.BuckKillIndex.1994-2014.County.Knox.xlsx", ///
    sheet("Public") firstrow clear

local yr = 1994
foreach v in C D E F G H I J K L M N O P Q R S T U V W {
    rename `v' bki`yr'
    local yr = `yr' + 1
}

rename County     county_fips
rename CountyName county_name

reshape long bki, i(county_fips) j(year)
rename bki buck_kill_index

gen land_ownership = "Public"
save "$dataSTATA/VA/temp_VA_bki_1994-2014_public.dta", replace

* Stack 
use "$dataSTATA/VA/temp_VA_bki_1994-2014_private.dta", clear
append using "$dataSTATA/VA/temp_VA_bki_1994-2014_public.dta"

gen name_clean = upper(strtrim(county_name))

label variable county_fips     "VA county FIPS code (3-digit, state-level)"
label variable county_name     "County name"
label variable name_clean      "county_name, uppercased and trimmed"
label variable year            "Year"
label variable buck_kill_index "Buck Kill Index: buck kill per unit area "
label variable land_ownership  "Land ownership: Private/Public"
label data                     "VA county-year buck kill index by land ownership, 1994-2014 (source: Knox)"

order county_fips county_name name_clean year land_ownership buck_kill_index

describe
browse

save "$dataSTATA/VA/temp_VA_bki_1994-2014_raw.dta", replace

* ---------------------------------- 1c. --------------------------------------

import excel "$dataRAW/Deer_Harvest/VA/VA.Harvest.1923-2014.StateSex.Knox.xlsx", ///
    firstrow clear

describe
browse

notes: Antlered Males data, 1947-1993, includes Male Fawns. ///
       Total Males = Antlered Males + Male Fawns. ///
       Percent Female = Females / (Total Males + Females). ///
       Unknown includes animals of undocumented sex. ///
       Total Harvest = Total Males + Females + Unknown.

label data 		       "VA statewide deer harvest totals, 1923-2014 (source: Knox)"
label variable year            "Year"
label variable antlered_males  "Antlered males harvested, statewide"
label variable male_fawns      "Male fawns harvested, statewide"
label variable total_males     "Total males (antlered + fawns)"
label variable females         "Females harvested, statewide"
label variable unknown         "Sex unknown, statewide"
label variable total_harvest   "Total statewide harvest"

save "$dataSTATA/VA/temp_VA_harvest_1923-2014_statewide_raw.dta", replace

* [DECIDE] This is a STATEWIDE annual series, not county-level -- it doesn't
* fit the county-year panel grain and isn't merged into the panel below.
* Keeping it as a saved reference/validation dataset (e.g. to sanity-check
* that summed county-level harvest roughly tracks the state total) is the
* most it's used for here. Flag for Eyal/Wendy if a different use is wanted.

* ---------------------------------- 1d. --------------------------------------

import excel "$dataRAW/Deer_Harvest/VA/VA.Harvest.2014.CountySex.Knox.xlsx", ///
    firstrow clear

describe
browse

gen name_clean = upper(county_or_city)
replace name_clean = strtrim(name_clean)

label data                    "VA county/city-level deer harvest, 2014 (source: Knox) -- 95 counties + 39 independent cities"
label variable county_or_city "County or independent city name, as reported"
label variable antlered_males "Antlered males harvested"
label variable male_fawns     "Male fawns harvested"
label variable females        "Females harvested"
label variable unknown        "Sex unknown"
label variable total          "Total harvest, this unit"
label variable name_clean     "Standardized name for future merge (uppercase, whitespace trimmed)"

* [DECIDE] This 2014-only county/city file is a subset of what's already in
* the Total sheet's 2014 rows (Section 1a) -- same year, same 134-138 units,
* just re-published as a standalone table. It isn't merged into the panel
* as a data source to avoid double-counting; its real value here is
* name_clean, which is used below (Section 2) as the canonical county/city
* name list for matching the population files (several of which report
* county/city names only, with no FIPS code attached).
save "$dataSTATA/VA/temp_VA_harvest_2014_countycity_raw.dta", replace

*==============================================================================
* SECTION 2: POPULATION DATA - Import & Clean
*==============================================================================

/*------------------------------------------------------------------------

Roadmap for this section, since it's more heterogeneous than Section 1:

  2a. County/city crosswalk -- built once, used by everything below that
      only has county/city NAMES and no FIPS code.
  2b. PopGoal (VA.PopGoal.1999-2015.County.Knox.xlsx) -- already has FIPS,
      no crosswalk needed. Biennial objectives, not annual.
  2c. Pop status 2014 (VA.Deer.pop.status.2014.xlsx) -- name-only, needs
      crosswalk. Single-year (2014) snapshot, Private + Public.
  2d. 2003 status tables from the management plan workbook -- same
      treatment as 2c, but year = 2003.
  2e. Static county covariates (habitat, human population) from the same
      management plan workbook -- these have no year at all (time-invariant
      characteristics), so they're handled separately and merged into the
      final panel by county_fips only, broadcasting across all years.

  [DECIDE] The management plan workbook has several other sheets (T1-T4,
  T5, Appx4, Appx5, Appx7, Appx8) that are either statewide aggregates,
  survey/administrative data, or narrative content -- not county-year
  panel material. They're intentionally NOT harmonized here. Flagging this
  explicitly rather than silently dropping them, per team convention --
  confirm with Eyal/Wendy if any of these turn out to be wanted after all
  (Appx4's statewide DVC time series in particular could be a useful
  validation check against Charvi's collision panel, just not a merge
  source for this one).
 
------------------------------------------------------------------------*/

* ---------------------------------- 2a. --------------------------------------

* County/city crosswalk. Built from the Total sheet of the harvest file
* (Section 1a's source) because it's the only file in this batch that
* reliably pairs a FIPS code with every one of VA's 137 county/city units,
* including the "(City of)" suffix convention used elsewhere in the raw data.
*
* Why this is needed: three of the population files below (pop status 2014,
* and the 2003 status tables) report county/city NAME only -- no FIPS. R
* equivalent of what follows: build a lookup table, then
* `left_join(df, crosswalk, by = "name_clean")`.

import excel "$dataRAW/Deer_Harvest/VA/VA.Harvest.1947-2014.CountySex.Knox.xlsx", ///
    sheet("Total") cellrange(A2) firstrow clear
keep County CountyName
duplicates drop
rename County     county_fips
rename CountyName county_name

* is_city: 1 for the ~40 independent cities (formatted "X (City of)" in the
* source), 0 for counties. Needed because VA has several city/county pairs
* that share a base name -- Bedford, Fairfax, Franklin, Richmond, Roanoke
* each have BOTH a county and an independent city of the same name. Any
* name-only match has to resolve these correctly or it'll silently merge
* the wrong geography.
gen byte is_city = strpos(county_name, "(City of)") > 0
gen name_base  = subinstr(county_name, " (City of)", "", .)
gen name_clean = upper(strtrim(name_base))

* [DECIDE] Flagging explicitly since it affects every name-based merge
* below: these 5 base names are ambiguous without the is_city flag.
qui levelsof name_clean if name_clean == upper(name_clean) ///
    & name_clean != "", local(_dummy)
duplicates tag name_clean, gen(_name_dup)
list county_name county_fips if _name_dup > 0, sep(0)
notes: County/city name COLLISIONS -- Bedford, Fairfax, Franklin, Richmond, ///
    and Roanoke each have both a county and an independent city sharing ///
    the same base name. Any source file that reports these 5 names WITHOUT ///
    a city/county type indicator is genuinely ambiguous and was hand- ///
    checked below rather than auto-matched.
drop _name_dup

label variable county_fips "VA county/city FIPS code (3-digit, state-level)"
label variable county_name "County/city name, '(City of)' suffix preserved (source formatting)"
label variable is_city     "1 = independent city, 0 = county"
label variable name_base   "county_name with '(City of)' suffix stripped"
label variable name_clean  "name_base, uppercased and trimmed -- the merge key used throughout Section 2"
label data "VA county/city FIPS crosswalk, 137 units (source: Knox harvest file, Total sheet)"

save "$dataSTATA/VA/VA_county_crosswalk.dta", replace
describe

* A second, DEDUPLICATED version keyed on name_clean alone, for the
* population sources below (2c, 2d) that report county/city NAME only,
* with no Type/FIPS to disambiguate. `merge m:1 name_clean using
* VA_county_crosswalk.dta` errors with "does not uniquely identify
* observations in the using data" for exactly these 5 names, since the
* full crosswalk legitimately has two rows per collision name.
*
* [DECIDE] Default here is to resolve each collision to the COUNTY, not
* the city, when a bare name is matched. Rationale: none of Bedford City,
* Fairfax City, Franklin City, or Richmond City/Roanoke City ever appear
* in these population tables under their OWN distinguishing convention
* (contrast Chesapeake/Suffolk/Virginia Beach, which are large
* independent cities that clearly do show up as such elsewhere in this
* same source ecosystem) -- consistent with small urban independent
* cities not having distinct deer-population management from their
* surrounding county. This is inference, not confirmed against the
* original PDFs -- flag for Eyal/Wendy before treating the resulting
* fips codes for these 5 names as final.
preserve
bysort name_clean (is_city): keep if _n == 1
save "$dataSTATA/VA/VA_county_crosswalk_nameonly.dta", replace
restore

* ---------------------------------- 2b. --------------------------------------

* Population objectives (PopGoal). Already has FIPS -- no crosswalk needed.
* Biennial evaluation points (1999, 2007, 2015), not an annual series, so
* this will leave `objective` missing in most panel-years after the merge
* in Section 3. That's expected, not a data-quality problem.

import excel "$dataRAW/Deer_Population/VA/VA.PopGoal.1999-2015.County.Knox.xlsx", ///
    cellrange(A2) firstrow clear
describe
browse

rename CountyName county_name
rename County      county_fips
rename Year        year
rename Objective   pop_objective

gen name_clean = upper(strtrim(county_name))

label variable county_fips   "VA county FIPS code (3-digit, state-level)"
label variable county_name   "County name"
label variable name_clean    "county_name, uppercased and trimmed"
label variable year          "Evaluation year (biennial: 1999, 2007, 2015)"
label variable pop_objective "Population management objective set for this county-year (Reduce/Stabilize/Increase)"
label data "VA county population objectives, evaluated biennially 1999-2015 (source: Knox)"

isid county_fips year
save "$dataSTATA/VA/temp_VA_popgoal_1999-2015_raw.dta", replace

* ---------------------------------- 2c. --------------------------------------

* 2014 population status/trends by management unit. Three sheets: Private
* land over two windows (10yr and 5yr, same underlying 2014 snapshot, just
* different trailing pct-change comparisons) and Public land (10yr only --
* no 5yr public table exists in the source). County NAME only, no FIPS.

import excel "$dataRAW/Deer_Population/VA/VA.Deer.pop.status.2014.xlsx", ///
    sheet("T1_Private_10yr") firstrow clear
drop if strpos(upper(County), "SOURCE") > 0
rename County                      county_name
rename Index                       pop_index
rename RelativeAbundance           relative_abundance
rename Status                      pop_status
rename ManagementObjective         pop_objective
rename ObjectiveMet                objective_met
rename PctChange10yr20052014       pct_change_10yr
gen land_ownership = "Private"
tempfile t1
save `t1'

import excel "$dataRAW/Deer_Population/VA/VA.Deer.pop.status.2014.xlsx", ///
    sheet("T2_Private_5yr") firstrow clear
drop if strpos(upper(County), "SOURCE") > 0
keep County PctChange5yr20102014
rename County                    county_name
rename PctChange5yr20102014      pct_change_5yr
tempfile t2
save `t2'

* T1 and T2 are the same 2014 Private-land snapshot reported against two
* different comparison windows -- merge them 1:1 on county rather than
* stacking, so each county-row carries both pct-change figures.
use `t1', clear
merge 1:1 county_name using `t2', assert(match) nogenerate
tempfile t1t2
save `t1t2'

import excel "$dataRAW/Deer_Population/VA/VA.Deer.pop.status.2014.xlsx", ///
    sheet("T3_Public_10yr") firstrow clear
drop if strpos(upper(County), "SOURCE") > 0
rename County              county_name
rename Index                pop_index
rename Status                pop_status
rename ManagementObjective  pop_objective
rename ObjectiveMet         objective_met
rename PctChange10yr20052014 pct_change_10yr
gen land_ownership = "Public"
tempfile t3
save `t3'

use `t1t2', clear
append using `t3'

* Name cleaning + crosswalk merge. Chesapeake, Suffolk, and Virginia Beach
* are independent cities reported WITHOUT the "(City of)" suffix here, but
* that's harmless: the crosswalk's own name_clean is ALSO suffix-stripped
* (see 2a), so a bare "CHESAPEAKE" matches the crosswalk's Chesapeake row
* directly -- no re-appending/re-stripping needed. They're unambiguous
* because neither has a same-named county.
*
* Uses the DEDUPLICATED crosswalk (2a) rather than the full one, because
* 5 of these county names (Bedford, Fairfax, Franklin, Richmond, Roanoke)
* are genuinely ambiguous without a Type indicator -- see the [DECIDE]
* note in 2a for the county-default rationale. `merge m:1` against the
* full crosswalk errors out here ("does not uniquely identify
* observations in the using data") precisely because of those 5 names.
gen name_clean = upper(strtrim(county_name))

merge m:1 name_clean using "$dataSTATA/VA/VA_county_crosswalk_nameonly.dta", ///
    keepusing(county_fips is_city) keep(match master) gen(_merge_xwalk)
list county_name if _merge_xwalk == 1
* [DECIDE] Anything listed above failed to match the crosswalk by name --
* check for typos/format differences before proceeding; do not silently drop.

gen year = 2014

label variable county_fips        "VA county/city FIPS code (from crosswalk merge)"
label variable county_name        "County/city name, as reported in source"
label variable year               "Snapshot year"
label variable land_ownership     "Private/Public"
label variable pop_index          "Population index: antlered buck kill per sq mi of estimated deer habitat, 3-yr avg (2012-2014). NOT a population count."
label variable relative_abundance "Relative abundance category (Private land only: Low/Moderate/High)"
label variable pop_status         "Trend status (Stable/Increasing/Declining)"
label variable pop_objective      "Management objective in effect"
label variable objective_met      "Whether the objective was met (Yes/No)"
label variable pct_change_10yr    "Pct change in index, 2005-2014"
label variable pct_change_5yr     "Pct change in index, 2010-2014 (Private land only)"
label data "VA 2014 deer population status by management unit (source: Knox, VA_Deer_pop_status_2014.pdf)"

order county_fips county_name year land_ownership pop_index relative_abundance ///
    pop_status pop_objective objective_met pct_change_10yr pct_change_5yr
drop _merge_xwalk
save "$dataSTATA/VA/temp_VA_popstatus_2014_raw.dta", replace

* ---------------------------------- 2d. --------------------------------------

* 2003 status tables (T6 Private, T7 Public) from the management plan
* workbook. Same shape as 2c, one snapshot year (2003) instead of 2014.

import excel "$dataRAW/Deer_Population/VA/VA.Deer.management.plan.2006-2015.Knox.xlsx", ///
    sheet("T6_2003_Private_Status") firstrow clear
* Same footer-row cleanup as 2c (T1/T2/T3) -- missed here originally.
* Without it, the trailing "Source: ..." note row and a blank row both
* survive, both end up with missing county_fips after the crosswalk
* merge, and collide as duplicate (missing, 2003, Private) keys later
* in Section 3d.
drop if strpos(upper(CountyCity), "SOURCE") > 0 | missing(CountyCity)
rename CountyCity          county_name
rename PctAnnualChangeR    pct_annual_change
rename pvalue               p_value
rename Status                pop_status
rename Objective1999Plan    pop_objective
rename ObjectiveMet         objective_met
gen land_ownership = "Private"
tempfile t6
save `t6'

import excel "$dataRAW/Deer_Population/VA/VA.Deer.management.plan.2006-2015.Knox.xlsx", ///
    sheet("T7_2003_Public_Status") firstrow clear
drop if strpos(upper(County), "SOURCE") > 0 | missing(County)
rename County                county_name
rename PctAnnualChangeR      pct_annual_change
rename pvalue                 p_value
rename Status                 pop_status
rename Objective1999Plan     pop_objective
rename ObjectiveMet           objective_met
gen land_ownership = "Public"
tempfile t7
save `t7'

use `t6', clear
append using `t7'

* Two known-bad entries caught while building the crosswalk match (see the
* Python audit that preceded this .do file): [DECIDE] confirm both fixes.
replace county_name = "Newport News" if county_name == "Newport"
* "Bedford3" -- the trailing "3" is almost certainly a stray footnote
* marker that leaked into the cell, not part of the name.
replace county_name = "Bedford" if county_name == "Bedford3"

* This block (T6/T7) contains all 5 of the county/city name-collision
* cases at some point across Private/Public (Bedford, Fairfax, Franklin,
* Richmond, Roanoke -- see Section 2a). None are suffixed "(City of)"
* here, so they resolve to the COUNTY row via the deduplicated crosswalk's
* default, same as 2c. [DECIDE] "Bedford" specifically is worth a second
* look either way, since the corrupted "Bedford3" source cell makes it
* less certain this row is even a clean county/city read to begin with.
gen name_clean = upper(strtrim(county_name))

merge m:1 name_clean using "$dataSTATA/VA/VA_county_crosswalk_nameonly.dta", ///
    keepusing(county_fips is_city) keep(match master) gen(_merge_xwalk)
list county_name if _merge_xwalk == 1

gen year = 2003

label variable county_fips        "VA county/city FIPS code (from crosswalk merge)"
label variable county_name        "County/city name, as reported in source"
label variable year               "Snapshot year"
label variable land_ownership     "Private/Public"
label variable pct_annual_change  "Pct annual change in index, trend period 1994-2003"
label variable p_value            "P-value for the trend estimate"
label variable pop_status         "Trend status (Stable/Increasing/Declining)"
label variable pop_objective      "Objective from the 1999 Plan"
label variable objective_met      "Whether the objective was met (Yes/No)"
label data "VA 2003 deer population status vs. 1999 Plan objectives (source: Knox, VA_Deer_management_plan_2006-2015_Knox.pdf, Tables 6-7)"

order county_fips county_name year land_ownership pct_annual_change p_value ///
    pop_status pop_objective objective_met
drop _merge_xwalk
save "$dataSTATA/VA/temp_VA_mgmtstatus_2003_raw.dta", replace

* ---------------------------------- 2e. --------------------------------------

* Static county covariates: habitat composition (Appx3) and human
* population (Appx9). Both are TIME-INVARIANT -- no year dimension at all
* -- so they don't fit the year-panel shape and are handled as a separate
* cross-sectional dataset, merged into the final panel by county_fips only
* (Section 3), broadcasting the same value across every year.
*
* Both sheets carry an explicit Type column (City/County), which resolves
* the 5 name-collision cases (Bedford, Fairfax, Franklin, Richmond,
* Roanoke) cleanly -- no guessing needed here, unlike 2d's "Bedford3".

import excel "$dataRAW/Deer_Population/VA/VA.Deer.management.plan.2006-2015.Knox.xlsx", ///
    sheet("Appx3_Habitat_Data") firstrow clear
drop if missing(CountyorCity) | Type == ""
drop if CountyorCity == "STATE"
rename CountyorCity      county_name
rename Type               unit_type
rename TotalAreami2       area_total_sqmi
rename DevelopedAreami2   area_developed_sqmi
rename BarrenAreami2      area_barren_sqmi
rename ForestAreami2      area_forest_sqmi
rename OpenAreami2        area_open_sqmi
rename WetlandAreami2     area_wetland_sqmi
rename DeerHabitatmi2     area_deer_habitat_sqmi
rename DeerHabitat        pct_deer_habitat
tempfile appx3
save `appx3'

import excel "$dataRAW/Deer_Population/VA/VA.Deer.management.plan.2006-2015.Knox.xlsx", ///
    sheet("Appx9_Human_Population") firstrow clear
drop if missing(CountyorCity) | Type == ""
drop if CountyorCity == "STATE"
rename CountyorCity                       county_name
rename Type                                unit_type
rename HumanPopulation2005est             human_pop_2005
rename PopulationDensitypeoplemi2         human_pop_density
rename PopulationGrowthRate*        human_pop_growth_pct
tempfile appx9
save `appx9'

* Merge on (name, type) rather than name alone -- this is what correctly
* separates Bedford County from Bedford City, etc.
use `appx3', clear
merge 1:1 county_name unit_type using `appx9', assert(match) nogenerate

gen name_clean = upper(strtrim(county_name))
gen byte is_city = unit_type == "City"
* Merge key needs to match the crosswalk's is_city-agnostic name_clean --
* but since name_clean + is_city together are already unambiguous here
* (unlike 2c/2d), merge on both fields for a belt-and-suspenders check.
merge 1:1 name_clean is_city using "$dataSTATA/VA/VA_county_crosswalk.dta", ///
    keepusing(county_fips) keep(match master) gen(_merge_xwalk)
list county_name unit_type if _merge_xwalk == 1
drop _merge_xwalk is_city unit_type

label variable county_fips            "VA county/city FIPS code (from crosswalk merge)"
label variable county_name            "County/city name, as reported in source"
label variable name_clean             "county_name, uppercased and trimmed"
label variable area_total_sqmi        "Total land area, sq mi"
label variable area_developed_sqmi    "Developed area, sq mi"
label variable area_barren_sqmi       "Barren area, sq mi"
label variable area_forest_sqmi       "Forest area, sq mi"
label variable area_open_sqmi         "Open area, sq mi"
label variable area_wetland_sqmi      "Wetland area, sq mi"
label variable area_deer_habitat_sqmi "Estimated deer habitat area, sq mi"
label variable pct_deer_habitat       "Estimated deer habitat, % of total area"
label variable human_pop_2005         "Human population, 2005 estimate"
label variable human_pop_density      "Human population density, people/sq mi"
label variable human_pop_growth_pct   "Human population growth rate, % 2000-2005"
label data "VA county/city static covariates: habitat + human population (source: Knox, VA_Deer_management_plan_2006-2015_Knox.pdf, Appx 3 & 9). Time-invariant -- no year dimension."

isid county_fips
save "$dataSTATA/VA/temp_VA_static_covariates_raw.dta", replace

*==============================================================================
* SECTION 3: BUILD THE COUNTY-YEAR PANEL
*==============================================================================

/*------------------------------------------------------------------------

Spine: the harvest panel (Section 1a), county_fips x year x land_ownership,
1947-2014, land_ownership in {Total, Private, Public}. Everything else
merges onto this spine. Two merge shapes show up below:

  - 1:1 on (county_fips year land_ownership) for sources that are
    themselves split by land ownership (BKI, both status snapshots) --
    R equivalent: inner/left_join by all three key columns.
  - m:1 on (county_fips year) or county_fips alone for sources that
    AREN'T land-ownership-specific (PopGoal; the static covariates) --
    this broadcasts one value across the Total/Private/Public rows of a
    matching county-year. R equivalent: left_join where the right-hand
    table has fewer key columns than the left, so rows repeat.

`keep(master match)` is used throughout rather than plain `merge` so a
non-match on the incoming (using) side never silently drops a spine row --
worth double-checking after each merge that no spine rows vanish.

------------------------------------------------------------------------*/

* ---------------------------------- 3a. --------------------------------------

* Spine + Buck Kill Index

use "$dataSTATA/VA/temp_VA_harvest_1947-2014_raw.dta", clear
isid county_fips year land_ownership

merge 1:1 county_fips year land_ownership ///
    using "$dataSTATA/VA/temp_VA_bki_1994-2014_raw.dta", ///
    keepusing(buck_kill_index) keep(master match) gen(_merge_bki)
* Expect _merge_bki == 1 (master-only) for: all Total rows (BKI has no
* Total category) and all years outside 1994-2014 (BKI's range). Anything
* else unmatched is worth investigating.
tab land_ownership _merge_bki
drop _merge_bki

* ---------------------------------- 3b. --------------------------------------

* + Population objectives (PopGoal) -- broadcasts across land_ownership

merge m:1 county_fips year using "$dataSTATA/VA/temp_VA_popgoal_1999-2015_raw.dta", ///
    keepusing(pop_objective) keep(master match) gen(_merge_popgoal)
* Expect _merge_bki == 1 for the vast majority of rows -- PopGoal only has
* 3 evaluation years (1999, 2007, 2015) out of the panel's 68.
tab _merge_popgoal
rename pop_objective pop_objective_biennial_goal
drop _merge_popgoal

* ---------------------------------- 3c. --------------------------------------

* + 2014 population status snapshot (Private/Public only -- Total rows
*   will not match, same reasoning as BKI above)

merge 1:1 county_fips year land_ownership ///
    using "$dataSTATA/VA/temp_VA_popstatus_2014_raw.dta", ///
    keepusing(pop_index relative_abundance pop_status pop_objective ///
        objective_met pct_change_10yr pct_change_5yr) ///
    keep(master match) gen(_merge_popstatus2014)
tab land_ownership _merge_popstatus2014 if year == 2014
drop _merge_popstatus2014

* ---------------------------------- 3d. --------------------------------------

* + 2003 status vs. 1999 Plan objectives (Private/Public only). Shares
*   column names with 3c above by design (pop_status, pop_objective,
*   objective_met) since it's the same concept measured at a different
*   snapshot year from a different source document -- the two snapshots
*   land in different year-rows, so there's no overwrite conflict, just
*   two populated year-slices of the same columns plus 2003-specific
*   pct_annual_change/p_value.

merge 1:1 county_fips year land_ownership ///
    using "$dataSTATA/VA/temp_VA_mgmtstatus_2003_raw.dta", ///
    keepusing(pct_annual_change p_value pop_status pop_objective objective_met) ///
    keep(master match) update gen(_merge_mgmtstatus2003)
tab land_ownership _merge_mgmtstatus2003 if year == 2003
drop _merge_mgmtstatus2003

* ---------------------------------- 3e. --------------------------------------

* + Static covariates (habitat, human population) -- broadcasts across
*   both year and land_ownership; every row of a given county gets the
*   same value.

merge m:1 county_fips using "$dataSTATA/VA/temp_VA_static_covariates_raw.dta", ///
    keepusing(area_total_sqmi area_developed_sqmi area_barren_sqmi ///
        area_forest_sqmi area_open_sqmi area_wetland_sqmi ///
        area_deer_habitat_sqmi pct_deer_habitat human_pop_2005 ///
        human_pop_density human_pop_growth_pct) ///
    keep(master match) gen(_merge_covars)
tab _merge_covars
* [DECIDE] Any county/city unmatched here has no habitat/human-pop
* covariates in the final panel -- check which units these are and
* whether that's expected (e.g. a unit that didn't exist as of the
* 2005-vintage covariate data) before treating it as a gap.
drop _merge_covars

* ---------------------------------- 3f. --------------------------------------

* Final cleanup, documentation, save

order county_fips county_name year land_ownership ///
    harvest_antlered_male harvest_fawn_male harvest_female harvest_unknown ///
    buck_kill_index ///
    pop_index relative_abundance pop_status pop_objective objective_met ///
    pct_change_10yr pct_change_5yr pct_annual_change p_value ///
    pop_objective_biennial_goal ///
    area_total_sqmi area_developed_sqmi area_barren_sqmi area_forest_sqmi ///
    area_open_sqmi area_wetland_sqmi area_deer_habitat_sqmi pct_deer_habitat ///
    human_pop_2005 human_pop_density human_pop_growth_pct

label data "VA county/city-year deer harvest & population panel, 1947-2014 (source: Knox, harmonized)"

* Sanity checks worth running before calling this done -- not exhaustive,
* just the ones that would catch the mistakes this build is most prone to.
isid county_fips year land_ownership
assert year >= 1947 & year <= 2014
count if land_ownership == "Total"
count if land_ownership == "Private"
count if land_ownership == "Public"
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/VA/VA_deer_harmonized_county_year_1947-2014.dta", replace

log close

