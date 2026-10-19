/*==============================================================================

FILE NAME:   VA_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel — 
	 Deer Harvest/Population Harmonization
	 
CURRENT LEAD: Nicole Martinez

PURPOSE:  Pilot script harmonizing Virginia (VA) county-level deer HARVEST
          and POPULATION data into a single county-year panel. VA was the
          pilot state because both datasets are compiled by the same
          source (Knox) and are county-level.

          NOTE (09/16/2026): the pilot's plan to generalize this into a
          `foreach state in ...` loop was not the route taken -- each state
          got its own script instead (14 to date), because the source
          formats differ too much to loop over. This file stays as the
          VA-specific script.

          KNOWN CHARACTERISTICS of the VA panel, documented in Section 3f
          and asserted there:
            - county_fips here is the 3-DIGIT VA code (e.g. "033"), not
              the 5-digit state+county code used by every other state's
              panel -- see the note] in 3f before the national append.
	      
            - a non-geographic "Unknown" unit (county_fips "999") carries
              Total-sheet harvest for 1981-1995.
	      
            - two units are former independent cities that no longer exist
              in Census reference files: Clifton Forge (560) and South
              Boston (780).
	      
            - 66 rows have a missing sex/age component (mostly Caroline
              Public male fawns) -- the source is blank there, not zero.
  
CHANGELOG:
		     
08/05/2026 — Nicole: First pass of a pilot script created. VA deer harvest
                     data imported & cleaned (Section 1). Section 2
                     (population data) and Section 3 (final county-year
                     panel merge) added.

                     * See inline notes for judgment calls -- county/city name 
		     conflicts (Bedford/Fairfax/Franklin/Richmond/Roanoke) and 
		     which management-plan sheets were deliberately left out of 
		     the panel.

08/06/2026 — Nicole: Going through first pass to make edits/troubleshoot
                     errors. Also addressing the [DECIDE] judgement calls.

08/07/2026 — Nicole: Trimming script to remove unnecessary information.

09/16/2026 — Nicole: Clean up pass, no change to data values. Removed the
                     exploratory peek-import blocks and a dead -levelsof-
                     line; added the missing mkdir lines for dataSTATA/VA
                     and dataCLEAN/VA. Comment-only expectations are now
                     asserts: sheet row counts, the crosswalk's 137 units,
                     every name-based merge matched, the BKI and pop-index
                     merge patterns, and the final Total/Private/Public row
                     counts. Documented what the pilot header claimed was
                     clean: 66 rows with a missing component, the "Unknown"
                     999 unit, Clifton Forge/South Boston, and the 3-digit
                     county_fips (new open item for the national append).
                     year recast to int; leftover name_clean dropped from
                     the final panel; labels shortened to Stata's 80-char
                     limit with long-form documentation in -notes-.

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

* Log file — keeps a full record of console output, useful when something
* breaks three stages later and you need to see what happened upstream
cap mkdir "$codeSTATA/logs"
log using "$codeSTATA/logs/VA_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/VA"
cap mkdir "$dataCLEAN/VA"

*==============================================================================
* SECTION 1: HARVEST DATA - Import & Clean
*==============================================================================

* ---------------------------------- 1a. --------------------------------------

* Three sheets in the harvest workbook -- Total, Private, Public -- each
* one county-year row per land-ownership category. Total and Public carry
* a note row above the header (hence cellrange(A2)); Private does not.

* Total: note row above header
import excel "$dataRAW/Deer_Harvest/VA/VA.Harvest.1947-2014.CountySex.Knox.xlsx", ///
    sheet("Total") cellrange(A2) firstrow clear
gen land_ownership = "Total"
count
assert r(N) == 7074
save "$dataSTATA/VA/temp_VA_harvest_1947-2014_total.dta", replace

* Private: header is already row 1, no offset needed
import excel "$dataRAW/Deer_Harvest/VA/VA.Harvest.1947-2014.CountySex.Knox.xlsx", ///
    sheet("Private") firstrow clear
gen land_ownership = "Private"
count
assert r(N) == 2471
save "$dataSTATA/VA/temp_VA_harvest_1947-2014_private.dta", replace

* Public: note row above header
import excel "$dataRAW/Deer_Harvest/VA/VA.Harvest.1947-2014.CountySex.Knox.xlsx", ///
    sheet("Public") cellrange(A2) firstrow clear
gen land_ownership = "Public"
count
assert r(N) == 2390

* Worth preserving this caveat as a note rather than discarding it -- it's a
* real data-quality flag about 3 specific counties' public-land kill counts
notes: Source file caveat (Public sheet): public land deer kill data for ///
    Caroline, Nottoway, and Stafford counties may be unreliable; these are ///
    kept to capture Fort AP Hill, Fort Pickett, and Quantico military lands.

save "$dataSTATA/VA/temp_VA_harvest_1947-2014_public.dta", replace

* Stack all three
use "$dataSTATA/VA/temp_VA_harvest_1947-2014_total.dta", clear
append using "$dataSTATA/VA/temp_VA_harvest_1947-2014_private.dta"
append using "$dataSTATA/VA/temp_VA_harvest_1947-2014_public.dta"

count
assert r(N) == 7074 + 2471 + 2390
describe

* Rename to match project conventions
rename County        county_fips
rename CountyName    county_name
rename Year          year
rename AntleredMales harvest_antlered_male
rename MaleFawns     harvest_fawn_male
rename Females       harvest_female
rename Unknown       harvest_unknown

* Year imported as string (Excel quirk) -- convert now that it has a real name
destring year, replace
assert inrange(year, 1947, 2014)
isid county_fips year land_ownership

* Standardized name key -- uppercase, whitespace trimmed. NOTE: unlike the
* later states, this one does NOT strip spaces/periods; VA merges on
* county_fips, and Section 2a builds its own key, so nothing depends on it.
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
label data "VA county-year deer harvest by land ownership, 1947-2014 (Knox)"

describe

save "$dataSTATA/VA/temp_VA_harvest_1947-2014_raw.dta", replace

* ---------------------------------- 1b. --------------------------------------

* Private (note row above the header)
import excel "$dataRAW/Deer_Harvest/VA/VA.BuckKillIndex.1994-2014.County.Knox.xlsx", ///
    sheet("Private") cellrange(A2) firstrow clear

local yr = 1994
foreach v in C D E F G H I J K L M N O P Q R S T U V W {
    rename `v' bki`yr'
    local yr = `yr' + 1
}
assert `yr' - 1 == 2014

rename County     county_fips
rename CountyName county_name

* Wide -> long: one row per county-year instead of one row per county with 21
* year-columns
reshape long bki, i(county_fips) j(year)
rename bki buck_kill_index
assert inrange(year, 1994, 2014)
bysort county_fips: assert _N == 21

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
assert `yr' - 1 == 2014

rename County     county_fips
rename CountyName county_name

reshape long bki, i(county_fips) j(year)
rename bki buck_kill_index
assert inrange(year, 1994, 2014)
bysort county_fips: assert _N == 21

gen land_ownership = "Public"
save "$dataSTATA/VA/temp_VA_bki_1994-2014_public.dta", replace

* Stack
use "$dataSTATA/VA/temp_VA_bki_1994-2014_private.dta", clear
append using "$dataSTATA/VA/temp_VA_bki_1994-2014_public.dta"

gen name_clean = upper(strtrim(county_name))

label variable county_fips     "VA county/city FIPS code (3-digit VA code, no state prefix)"
label variable county_name     "County name"
label variable name_clean      "county_name, uppercased and trimmed"
label variable year            "Year"
label variable buck_kill_index "Buck kill index: buck kill per unit area"
label variable land_ownership  "Land ownership: Private/Public"
label data                     "VA county-year buck kill index by land ownership, 1994-2014 (Knox)"

order county_fips county_name name_clean year land_ownership buck_kill_index

isid county_fips year land_ownership
describe

save "$dataSTATA/VA/temp_VA_bki_1994-2014_raw.dta", replace

* ---------------------------------- 1c. [REMOVED] ----------------------------
* Formerly: statewide (not county-level) 1923-2014 harvest totals, kept
* only as an optional reference/validation dataset -- never merged into
* the panel. Out of scope per the trimmed request; the raw file is
* untouched on disk if this needs to be restored later.

* ---------------------------------- 1d. [REMOVED] ----------------------------
* Formerly: 2014 county/city harvest, a redundant duplicate of the Total
* sheet's 2014 rows (already in the panel via 1a) -- never merged in
* either, kept only for its name_clean reference list. Removed here;
* Section 2's crosswalk (2a) builds its own name_clean directly from the
* Total sheet, so nothing downstream depended on this file.

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

  The management plan workbook has several other sheets (T1-T4, T5, Appx4, Appx5, 
  Appx7, Appx8) that are either statewide aggregates, survey/administrative data, 
  or narrative content -- not county-year panel material. They're intentionally 
  NOT harmonized here. Flagging this explicitly rather than silently dropping 
  them -- confirm if any of these turn out to be wanted after all (Appx4's 
  statewide DVC  time series in particular could be a useful validation check 
  against collision panel, just not a merge source for this one).
 
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

* Flagging explicitly since it affects every name-based merge below: these 5 
* base names are ambiguous without the is_city flag (Bedford, Fairfax, Franklin, 
* Richmond, Roanoke -- county + city each).
count
assert r(N) == 137
duplicates tag name_clean, gen(_name_dup)
list county_name county_fips if _name_dup > 0, sep(0)
count if _name_dup > 0
assert r(N) == 10          // 5 collision names x 2 units each

label variable county_fips "VA county/city FIPS code (3-digit, state-level)"
label variable county_name "County/city name, '(City of)' suffix preserved (source formatting)"
label variable is_city     "1 = independent city, 0 = county"
label variable name_base   "county_name with '(City of)' suffix stripped"
label variable name_clean  "Merge key: name_base, uppercased and trimmed (Section 2)"
label data "VA county/city FIPS crosswalk, 137 units (Knox harvest file, Total)"

save "$dataSTATA/VA/VA_county_crosswalk.dta", replace
describe

* A second, DEDUPLICATED version keyed on name_clean alone, for the
* population sources below (2c, 2d) that report county/city NAME only,
* with no Type/FIPS to disambiguate. `merge m:1 name_clean using
* VA_county_crosswalk.dta` errors with "does not uniquely identify
* observations in the using data" for exactly these 5 names, since the
* full crosswalk legitimately has two rows per collision name.
*
* Default here is to resolve each collision to the COUNTY, not the city, when a 
* bare name is matched. Rationale: none of Bedford City, Fairfax City, Franklin 
* City, or Richmond City/Roanoke City ever appear in these population tables 
* under their OWN distinguishing convention (contrast Chesapeake/Suffolk/
* Virginia Beach, which are large independent cities that clearly do show up as 
* such elsewhere in this same source ecosystem) -- consistent with small urban 
* independent cities not having distinct deer-population management from their
* surrounding county. This is inference, not confirmed against the
* original PDFs -- flagging before treating the resulting fips codes for these 5 
* names as final.
preserve
bysort name_clean (is_city): keep if _n == 1
save "$dataSTATA/VA/VA_county_crosswalk_nameonly.dta", replace
restore

* ---------------------------------- 2b. [REMOVED] ----------------------------
* Formerly: PopGoal (population objectives, biennial). Its only substantive
* column was pop_objective -- management-objective content, out of scope
* per the trimmed request.

* ---------------------------------- 2c. --------------------------------------

* 2014 population index by management unit. Two sheets: T1 (Private) and
* T3 (Public). [Trimmed] Originally also pulled T2 (Private, 5yr) and
* several trend/status/objective columns from T1/T3 -- dropped per scope
* decision (county/fips, year, harvest/pop counts, age/sex breakdowns,
* DVC/CWD/WSI only). pop_index is the one genuine population metric here,
* so it's the only thing kept from this source. County NAME only, no FIPS.

import excel "$dataRAW/Deer_Population/VA/VA.Deer.pop.status.2014.xlsx", ///
    sheet("T1_Private_10yr") firstrow clear
drop if strpos(upper(County), "SOURCE") > 0
rename County                      county_name
rename Index                       pop_index
gen land_ownership = "Private"
tempfile t1
save `t1'

import excel "$dataRAW/Deer_Population/VA/VA.Deer.pop.status.2014.xlsx", ///
    sheet("T3_Public_10yr") firstrow clear
drop if strpos(upper(County), "SOURCE") > 0
rename County              county_name
rename Index                pop_index
gen land_ownership = "Public"
tempfile t3
save `t3'

use `t1', clear
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
* are genuinely ambiguous without a Type indicator -- see the note in 2a for the 
* county-default rationale. `merge m:1` against the full crosswalk errors out 
* here ("does not uniquely identify observations in the using data") precisely 
* because of those 5 names.
gen name_clean = upper(strtrim(county_name))

* Two rows arrive with a blank County cell (empty/footer rows in the T1 and
* T3 sheets that the "SOURCE" filter above doesn't catch). They matched
* nothing and used to disappear silently at the 3c merge; drop them here,
* after showing what they hold.
list county_name land_ownership pop_index if strtrim(county_name) == ""
count if strtrim(county_name) == ""
assert r(N) == 2
drop if strtrim(county_name) == ""

merge m:1 name_clean using "$dataSTATA/VA/VA_county_crosswalk_nameonly.dta", ///
    keepusing(county_fips is_city) keep(match master) gen(_merge_xwalk)
list county_name if _merge_xwalk != 3
* Every row must match the crosswalk by name -- an unmatched row would
* carry a missing county_fips and then disappear at the 3c merge.
assert _merge_xwalk == 3
count
assert r(N) == 128         // 97 Private + 31 Public units reported for 2014

gen year = 2014

label variable county_fips        "VA county/city FIPS code (from crosswalk merge)"
label variable county_name        "County/city name, as reported in source"
label variable year               "Snapshot year"
label variable land_ownership     "Private/Public"
label variable pop_index          "Index: antlered buck kill per sq mi of deer habitat (not a count)"
label data "VA 2014 deer population index by management unit (Knox)"

order county_fips county_name year land_ownership pop_index
drop _merge_xwalk
save "$dataSTATA/VA/temp_VA_popstatus_2014_raw.dta", replace

* ---------------------------------- 2d. [REMOVED] ----------------------------
* Formerly: statewide DVC (deer-vehicle collision) counts, 1975-2005, from
* the management plan workbook's Appendix 4. Disregarded per scope
* decision -- Charvi's county-level DVC compilation is the DVC source of
* record for this project; this statewide VDOT series was an optional
* supplement, not a core requirement.

* ---------------------------------- 2e. [REMOVED] ----------------------------
* Formerly: static covariates (habitat composition from Appx3, human
* population from Appx9). Out of scope per the trimmed request --
* neither is harvest/pop data, an age/sex breakdown, or DVC/CWD/WSI.

*==============================================================================
* SECTION 3: BUILD THE COUNTY-YEAR PANEL
*==============================================================================

/*------------------------------------------------------------------------

Spine: the harvest panel (Section 1a), county_fips x year x land_ownership,
1947-2014, land_ownership in {Total, Private, Public}. Everything else
merges onto this spine, 1:1 on (county_fips year land_ownership), since
both remaining sources (BKI, the 2014 population index) are themselves
split by land ownership -- R equivalent: inner/left_join by all three
key columns.

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
* BKI covers Private and Public only, 1994-2014. Every other spine row
* must be master-only; every Private/Public row in range must match.
tab land_ownership _merge_bki
* BKI exists only for Private/Public rows in 1994-2014, and only for a
* FIXED SUBSET of units: 97 Private and 32 Public in every year, against
* up to 136 units in the harvest sheets. The units with no BKI are the
* independent cities and Arlington (013, 510, 515, 520, 530, 540, ...) --
* no huntable area, so no kill-per-unit-area index. So a Private/Public
* row in range may legitimately be master-only.
assert _merge_bki == 1 if land_ownership == "Total"
assert _merge_bki == 1 if !inrange(year, 1994, 2014)
assert _merge_bki == 3 if !missing(buck_kill_index)
count if !missing(buck_kill_index)
assert r(N) == 2709
count if _merge_bki == 3 & land_ownership == "Private"
assert r(N) == 97 * 21
count if _merge_bki == 3 & land_ownership == "Public"
assert r(N) == 32 * 21
drop _merge_bki

* ---------------------------------- 3b. [REMOVED] ----------------------------
* Formerly: merge in PopGoal objectives -- source data removed above (2b).

* ---------------------------------- 3c. --------------------------------------

* + 2014 population index (Private/Public only -- Total rows will not
*   match, same reasoning as BKI above)
merge 1:1 county_fips year land_ownership ///
    using "$dataSTATA/VA/temp_VA_popstatus_2014_raw.dta", ///
    keepusing(pop_index) ///
    keep(master match) gen(_merge_popstatus2014)
tab land_ownership _merge_popstatus2014 if year == 2014
* pop_index exists only for 2014 Private/Public rows (128 of them)
assert _merge_popstatus2014 == 1 if year != 2014
assert _merge_popstatus2014 == 1 if land_ownership == "Total"
count if !missing(pop_index)
assert r(N) == 128
assert year == 2014 & land_ownership != "Total" if !missing(pop_index)
drop _merge_popstatus2014

* ---------------------------------- 3d. [REMOVED] ----------------------------
* Formerly: merge in statewide DVC counts -- source data removed above (2d).

* ---------------------------------- 3e. [REMOVED] ----------------------------
* Formerly: merge in static covariates (habitat, human population) --
* source data removed above (2e).

* ---------------------------------- 3f. --------------------------------------

* Final cleanup, documentation, save
drop name_clean            // merge key from 1a, not a panel variable
recast int year            // was a double from the string destring

order county_fips county_name year land_ownership ///
    harvest_antlered_male harvest_fawn_male harvest_female harvest_unknown ///
    buck_kill_index pop_index

label variable county_fips           "VA county/city code (3-digit VA code, NO state prefix)"
label variable county_name           "County/city name, as reported in source"
label variable year                  "Harvest year"
label variable land_ownership        "Land ownership: Total, Private or Public"
label variable harvest_antlered_male "Antlered male deer harvested"
label variable harvest_fawn_male     "Male fawn/button buck deer harvested"
label variable harvest_female        "Female deer harvested"
label variable harvest_unknown       "Deer harvested, sex/age unknown"
label variable buck_kill_index       "Buck kill index: buck kill per unit area (Private/Public, 1994-2014)"
label variable pop_index             "Index: antlered buck kill per sq mi of deer habitat, 2014 only"
label data "VA county/city-year deer harvest by land ownership, 1947-2014 (Knox)"

notes: Source: Knox files (VDGIF/DWR). Row unit is county/city x year x land ownership (Total, Private, Public). Trimmed to harvest counts, age/sex breakdowns, the buck kill index and the 2014 population index; management/objective and static covariate fields were dropped per scope decision.
notes county_fips: 3-DIGIT VA code with no state prefix -- unlike every other state panel, which uses the 5-digit state+county code. Prefix with 51 before appending nationally. Three units have no match in current Census files: 999 (Unknown, Total sheet only, 1981-1995), 560 (Clifton Forge city, merged into Alleghany County in 2001) and 780 (South Boston city, reverted to a town in 1995).
notes pop_index: NOT a population count: antlered buck kill per square mile of estimated deer habitat, 3-year average (2012-2014), reported for 2014 only.
notes harvest_fawn_male: Blank (not zero) in 62 rows, almost all Caroline County Public land 1954-2013; 4 further rows have a blank antlered-male or female count. Source blanks, left as missing.
notes buck_kill_index: Private and Public only, 1994-2014 (2,709 rows): a fixed subset of 97 Private and 32 Public units in every year, not all 137. Units with no index are independent cities and Arlington, which have no huntable area. The source caveat on Caroline, Nottoway and Stafford public-land kill counts is carried in the harvest file's own note.

* county_fips is VA's 3-digit code, not the 5-digit code the other state panels 
* use, and 999/560/780 are not current Census units. The national append needs a 
* decision: prefix 51 here, and either keep, drop or reassign those three. 
* Nothing is changed here -- the Unknown row in particular is the same case as 
* MO's UNKNOWN and CA's Unknown county, both of which were excluded from their 
* panels.
*   drop if county_fips == "999"     // <- uncomment if we want it out

* Sanity checks worth running before calling this done
isid county_fips year land_ownership
assert inrange(year, 1947, 2014)
assert inlist(land_ownership, "Total", "Private", "Public")
count
assert r(N) == 11935
count if land_ownership == "Total"
assert r(N) == 7074
count if land_ownership == "Private"
assert r(N) == 2471
count if land_ownership == "Public"
assert r(N) == 2390
count if missing(harvest_antlered_male, harvest_fawn_male, harvest_female)
assert r(N) == 66          // source blanks, see notes
sort county_fips year land_ownership
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/VA/VA_deer_harmonized_county_year_1947-2014.dta", replace

log close
