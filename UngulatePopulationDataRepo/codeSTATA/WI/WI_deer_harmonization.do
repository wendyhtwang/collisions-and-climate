/*==============================================================================

FILE NAME:   WI_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  Wisconsin (WI) county-level deer HARVEST and POPULATION
          harmonization, adapted from the VA pilot script
          (VA_deer_harmonization.do). Unlike VA, WI's harvest data is
          natively county-level but its POPULATION data is reported by
          Deer Management Unit (DMU), not county, and WI has used two
          incompatible DMU systems over time. See Section 2 header for
          the geography problem and the scope decision this script makes
          about it -- flagged, mirroring VA's county/city collision handling 
	  but at a bigger scale.

SOURCE FILES USED:

  Harvest_Deer_County_60-15_Rolley.xlsx      -- county harvest, 1960-2015
  
  Demog_Deer_NDMU_14_Rolley.xlsx             -- new-DMU (county x zone)
                                                 prehunt population, 2014
						 
  Demog_Deer_NDMU_15-17_WDNR_Online.xlsx     -- new-DMU posthunt
                                                 population, 2015-2017
						 
  Demog_Deer_Harvest_Pop_DMU_2015-2018_Stenglein.csv
                                              -- new-DMU posthunt
                                                 population (+ DMU-level
                                                 harvest), 2015-2018

SOURCE FILES REVIEWED BUT NOT HARMONIZED HERE (see inline notes):

  Harvest_Deer_DMU_59-12_Rolley.txt          -- old numeric-DMU harvest,
                                                 1959-2012 [1c, REMOVED]
						 
  Demog_Deer_DMU_81-13_Rolley.xlsx           -- old numeric-DMU population/
                                                 density/goals, 1981-2013
                                                 [2c, DEFERRED]

CHANGELOG:

08/10/2026 — Nicole: First pass adapting the VA pilot logic to WI.
                     Section 1 (county harvest) is a fairly direct port of
                     the VA pattern. Section 2 (population) required a
                     different approach because WI's population data is
                     DMU-level, not county-level -- see inline [DECIDE]
                     notes.

08/10/2026 — Nicole: Went through Section 1 and troubleshot bugs that came
                     up to harmonize the harvest data. Stopped at Section
                     2, flagging conflict between old DMUs (1959-2013) and
                     new ones (2014 on) -- DMU boundaries redrawn.

08/11/2026 — Nicole: Went through Section 2 and troubleshot bugs that came
                     up to harmonize the population data for 2014 and
                     later.

09/16/2026 — Nicole: Clean up pass, no change to data values. Added a
                     pre-destring listing of any non-numeric cells (the
                     -force- option silently makes them missing) and pinned
                     the resulting missing-cell pattern: Milwaukee Gun/Bow
                     1960-1971, Menominee Gun/Bow, Lafayette Bow 1971.
                     Documented that -collapse (sum)- treats a missing
                     zone-level estimate as 0, which is why Menominee's
                     2014 prehunt population comes out as 0 rather than
                     missing -- new note in 2a-i. Row counts, the
                     72-county crosswalk, and the population merge pattern
                     are now asserted; the 1b sex-class merge comment was
                     corrected (it says keep(match), the code keeps
                     everything). Labels shortened to Stata's 80-char
                     limit; long-form documentation moved to -notes-. year
                     recast to int; panel sorted before save.		     

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
log using "$codeSTATA/logs/WI_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/WI"
cap mkdir "$dataCLEAN/WI"

*==============================================================================
* SECTION 1: HARVEST DATA - Import & Clean
*==============================================================================

/*------------------------------------------------------------------------

WI's county harvest workbook splits harvest two ways at once, unlike VA's
single land_ownership split:

  - by SEX/AGE CLASS: Antlered vs Antlerless (this is the direct WI analog
    of VA's harvest_antlered_male/harvest_female breakdown)
    
  - by HARVEST METHOD: Total (Gun+Bow[+XBow]) / Gun / Bow / XBow (this is
    the direct WI analog of VA's Total/Private/Public land_ownership split)

Antlered and Antlerless live in SEPARATE SHEETS here (not separate columns
within one sheet, as VA's sex breakdown was). So each method needs a
reshape-long on BOTH its Antlered and Antlerless sheets, then a 1:1 merge
to recombine them into two columns of the same county-year-method row,
BEFORE stacking (appending) across methods -- R equivalent: pivot_longer()
each sheet separately, inner_join() the antlered/antlerless pair by
(county, year), then bind_rows() across the four methods.

"X Calc" sheets (Total Antlered Calc, etc.) are pure QA sheets -- Total
minus Gun minus Bow minus XBow, all zeros throughout -- not source data.
Skipped here, same as VA's validation-only sheets.

KNOWN BUG to watch for in this specific workbook: Bow Antlered and Bow
Antlerless both have a footer note ("*2014 was first year that cross-bows
were legal...") sitting in the county-name column below the last real
county row. Handled below by anchoring every import to the county
crosswalk with keep(match) -- footer/blank rows never match a real county
name and get dropped, with a QC listing to confirm nothing legitimate was
lost in the process (mirrors VA's `list ... if _merge_xwalk == 1` pattern).

------------------------------------------------------------------------*/

* ---------------------------------- 1a. --------------------------------------

* County/FIPS crosswalk. Unlike VA, no WI source file carries a FIPS code
* at all -- every sheet is county NAME only. Built here as a static
* reference table instead of extracted from a source file.
*
* This crosswalk was typed from standard Census/DNR county FIPS assignments 
* (state FIPS 55), not pulled from a project source file -- spot-checked 
* against American National Standards Institute (ANSI), Federal Information
* Processing Series (FIPS), and Other Standardized Geographic Codes:
* https://www2.census.gov/geo/docs/reference/codes2020/cou/st55_wi_cou2020.txt
* 
* Note: Menominee County (078) breaks the otherwise-alphabetical-odd
* numbering pattern; it was carved out of the Menominee Indian Reservation
* in 1961, which is also why pre-1961 harvest rows for Menominee are 0.

input str20 county_name str3 fips_suffix
"Adams" "001"
"Ashland" "003"
"Barron" "005"
"Bayfield" "007"
"Brown" "009"
"Buffalo" "011"
"Burnett" "013"
"Calumet" "015"
"Chippewa" "017"
"Clark" "019"
"Columbia" "021"
"Crawford" "023"
"Dane" "025"
"Dodge" "027"
"Door" "029"
"Douglas" "031"
"Dunn" "033"
"Eau Claire" "035"
"Florence" "037"
"Fond du Lac" "039"
"Forest" "041"
"Grant" "043"
"Green" "045"
"Green Lake" "047"
"Iowa" "049"
"Iron" "051"
"Jackson" "053"
"Jefferson" "055"
"Juneau" "057"
"Kenosha" "059"
"Kewaunee" "061"
"La Crosse" "063"
"Lafayette" "065"
"Langlade" "067"
"Lincoln" "069"
"Manitowoc" "071"
"Marathon" "073"
"Marinette" "075"
"Marquette" "077"
"Menominee" "078"
"Milwaukee" "079"
"Monroe" "081"
"Oconto" "083"
"Oneida" "085"
"Outagamie" "087"
"Ozaukee" "089"
"Pepin" "091"
"Pierce" "093"
"Polk" "095"
"Portage" "097"
"Price" "099"
"Racine" "101"
"Richland" "103"
"Rock" "105"
"Rusk" "107"
"St. Croix" "109"
"Sauk" "111"
"Sawyer" "113"
"Shawano" "115"
"Sheboygan" "117"
"Taylor" "119"
"Trempealeau" "121"
"Vernon" "123"
"Vilas" "125"
"Walworth" "127"
"Washburn" "129"
"Washington" "131"
"Waukesha" "133"
"Waupaca" "135"
"Waushara" "137"
"Winnebago" "139"
"Wood" "141"
end

gen county_fips = "55" + fips_suffix
drop fips_suffix

* Merge key: uppercase, whitespace-trimmed, periods stripped -- source
* sheets are inconsistent about "St. Croix" vs "St Croix" and "Fond du
* Lac" vs "Fond Du Lac" capitalization, so periods need to go before the
* case fold or "ST." and "ST" won't match.
gen name_clean = upper(strtrim(subinstr(county_name, ".", "", .)))

isid county_fips
isid name_clean

label variable county_fips "WI county FIPS code (5-digit, state+county)"
label variable county_name "County name (Census spelling)"
label variable name_clean  "county_name, uppercased/trimmed/period-stripped -- merge key used throughout"
label data "WI county FIPS crosswalk, 72 units (static reference, state FIPS 55)"

save "$dataSTATA/WI/WI_county_crosswalk.dta", replace
describe

* ---------------------------------- 1b. --------------------------------------

* Harvest by method (Total/Gun/Bow/XBow) x sex-class (Antlered/Antlerless).
* Each method's two sheets get reshaped separately, then merged 1:1 on
* (county_name year) to recombine into one row per county-year-method.

local methods "Total Gun Bow XBow"

foreach method of local methods {

    * --- Antlered sheet ---
    import excel "$dataRAW/Deer_Harvest/WI/Harvest.Deer.County.60-15.Rolley.xlsx", ///
        sheet("`method' Antlered") cellrange(A3) firstrow clear
    rename County county_name
    drop if missing(county_name)
    replace county_name = strtrim(county_name)

    * Year columns come in left-to-right chronological order regardless of
    * what Stata auto-names them (numeric headers like 1960 aren't valid
    * Stata variable names) -- renaming positionally sidesteps having to
    * hand-type ~56 Excel column letters and is robust to XBow's shorter
    * 2014-2015 range too.
    ds county_name, not
    local yearvars `r(varlist)'

    * XBow only starts in 2014 (crossbow harvest wasn't tracked separately
    * before then); everything else starts 1960.
    if "`method'" == "XBow" local firstyear 2014
    else local firstyear 1960

    local yr = `firstyear'
    foreach v of local yearvars {
        rename `v' h`yr'
        local yr = `yr' + 1
    }
    * -force- below converts anything non-numeric to missing WITHOUT
    * warning, so list the offending cells first (blank cells are fine and
    * stay missing; text cells are what to worry about).
    foreach v of varlist h* {
        capture confirm string variable `v'
        if !_rc {
            quietly count if strtrim(`v') != "" & missing(real(`v'))
            if r(N) > 0 {
                di as error "`method' Antlered, `v': " r(N) " non-numeric cell(s)"
                list county_name `v' if strtrim(`v') != "" & missing(real(`v')), noobs
            }
        }
    }
    destring h*, replace force
    reshape long h, i(county_name) j(year)
    rename h harvest_antlered
    tempfile ant
    save `ant'

    * --- Antlerless sheet ---
    import excel "$dataRAW/Deer_Harvest/WI/Harvest.Deer.County.60-15.Rolley.xlsx", ///
        sheet("`method' Antlerless") cellrange(A3) firstrow clear
    rename County county_name
    drop if missing(county_name)
    replace county_name = strtrim(county_name)

    ds county_name, not
    local yearvars `r(varlist)'
    if "`method'" == "XBow" local firstyear 2014
    else local firstyear 1960

    local yr = `firstyear'
    foreach v of local yearvars {
        rename `v' h`yr'
        local yr = `yr' + 1
    }
    foreach v of varlist h* {
        capture confirm string variable `v'
        if !_rc {
            quietly count if strtrim(`v') != "" & missing(real(`v'))
            if r(N) > 0 {
                di as error "`method' Antlerless, `v': " r(N) " non-numeric cell(s)"
                list county_name `v' if strtrim(`v') != "" & missing(real(`v')), noobs
            }
        }
    }
    destring h*, replace force
    reshape long h, i(county_name) j(year)
    rename h harvest_antlerless

    * Recombine antlered + antlerless into one row per county-year-method.
    * keep(match master using) keeps everything: a county-year with only
    * one of the two sheets stays in the data with the other side missing,
    * rather than disappearing here. Those rows are listed below.
    merge 1:1 county_name year using `ant', keep(match master using) gen(_merge_sexclass)
    tab _merge_sexclass
    count if _merge_sexclass != 3
    di as txt "`method': " r(N) " county-years present in only one sheet"
    list county_name year if _merge_sexclass != 3, sep(0)
    * Anything listed above has an Antlered or Antlerless value for this method 
    * but not both -- check the source workbook rather than assume it's just a 
    * footer/blank-row artifact (those get caught later at the crosswalk merge
    * instead).
    drop _merge_sexclass

    gen harvest_method = "`method'"
    tempfile `method'_combined
    save ``method'_combined'
}

* Stack all four methods
use `Total_combined', clear
append using `Gun_combined'
append using `Bow_combined'
append using `XBow_combined'

* Name cleaning + crosswalk merge -- this is also where the Bow sheets'
* footer-note row and any blank rows from the cellrange offset get
* filtered out, since neither matches a real county name.
gen name_clean = upper(strtrim(subinstr(county_name, ".", "", .)))

merge m:1 name_clean using "$dataSTATA/WI/WI_county_crosswalk.dta", ///
    keepusing(county_fips) keep(match master) gen(_merge_xwalk)
list county_name year harvest_method if _merge_xwalk == 1
* Anything listed above failed to match the crosswalk by name.
* Expected here: the Bow sheets' footer note row, and the blank row
* created by the cellrange(A3) offset landing one row above the real data.
* Confirm nothing else (a real county with a spelling/whitespace variant)
* shows up in this list before treating the drop as clean.
count if _merge_xwalk == 1
di as txt "non-county rows dropped at the crosswalk merge: " r(N)
drop if _merge_xwalk == 1
drop _merge_xwalk

label variable county_fips        "WI county FIPS code (5-digit string, state+county)"
label variable county_name        "County name, as reported in source"
label variable year               "Harvest year"
label variable harvest_method     "Harvest method: Total (Gun+Bow[+XBow]) / Gun / Bow / XBow"
label variable harvest_antlered   "Antlered deer harvested"
label variable harvest_antlerless "Antlerless deer harvested"
label data "WI county-year deer harvest by method, 1960-2015 (Rolley)"

order county_fips county_name year harvest_method harvest_antlered harvest_antlerless
drop name_clean

isid county_fips year harvest_method
quietly tab county_fips
assert r(r) == 72
assert inlist(harvest_method, "Total", "Gun", "Bow", "XBow")
foreach mth in Total Gun Bow {
    count if harvest_method == "`mth'"
    assert r(N) == 72 * 56          // 1960-2015
}
count if harvest_method == "XBow"
assert r(N) == 72 * 2               // 2014-2015 only
assert inrange(year, 2014, 2015) if harvest_method == "XBow"

* Missing harvest cells (source blanks, kept as missing): Milwaukee Gun and
* Bow 1960-1971, Menominee Gun/Bow (pre-1961 and 2014) and its 2014
* Total/XBow rows, Lafayette Bow 1971.
count if missing(harvest_antlered)
assert r(N) == 29
count if missing(harvest_antlerless)
assert r(N) == 32

describe

save "$dataSTATA/WI/temp_WI_harvest_1960-2015_raw.dta", replace

* ---------------------------------- 1c. [REMOVED] ----------------------------
* Formerly considered: Harvest_Deer_DMU_59-12_Rolley.txt -- old numeric-DMU
* harvest (whitespace-delimited: DMU code, year, 2 harvest columns),
* 1959-2012. Redundant with the county-level harvest above for the years
* they overlap, AND the old numeric DMU codes ("01", "1M", "2"...) don't
* map to counties without a crosswalk this project doesn't currently have
* (see 2c below -- same underlying problem as the old-DMU population
* data). Not harmonized here; raw file untouched.

*==============================================================================
* SECTION 2: POPULATION DATA - Import & Clean
*==============================================================================

/*------------------------------------------------------------------------

THE GEOGRAPHY PROBLEM (read this before touching this section):

VA's population data was county-level throughout, so Section 2 there was
just about resolving a handful of ambiguous county/city NAMES. WI's
population data is reported by Deer Management Unit (DMU), and WI has
used two incompatible DMU systems over the years:

  - OLD numeric DMUs ("01", "1M", "2", "3"...), used in
    Demog_Deer_DMU_81-13_Rolley.xlsx (1981-2013) and the old harvest txt
    (1c above). These do NOT correspond to county or county-fragment
    boundaries in any way recoverable from the files in this project --
    would need a historical DMU boundary shapefile to crosswalk to
    counties, which hasn't been provided.

  - NEW DMUs = County x Zone (e.g. "Adams Farmland", "Adams Forest"),
    used from ~2014 on. These DO decompose cleanly: the zone is always
    the DMU name's last word (Farmland/Forest), and everything before it
    is the county name -- confirmed against
    Deer_Management_Zones_Units_and_Metro_Subunits.shp, whose DEER_MGMT_
    field is the plain county name for each zone polygon. A few units
    (e.g. "Madeline Island Forest") are metro/island subunits that don't
    decompose to a normal county this way -- see 2a's QC listing.

  Scope decision: this script aggregates the NEW-DMU population sources (2014-
  2018) up to county-year by summing posthunt/prehunt estimates across zones 
  within a county, and does NOT attempt to bring the OLD-DMU population (1981-
  2013) into the county panel at all -- it's held out as a separate DMU-level 
  dataset (2c). If a historical DMU boundary crosswalk exists elsewhere (e.g. 
  from DVC work, or WDNR), this is worth revisiting -- it would meaningfully 
  extend WI's population coverage backward by ~30 years.

  Two overlapping-but-independent sources cover 2015-2017 posthunt population: 
  the WDNR online workbook and Stenglein's compiled CSV. Rather than silently 
  pick one, this script uses Stenglein as the primary source (single consistent 
  file spanning all four years, 2015-2018) and keeps the WDNR online numbers as 
  a separate QC dataset that gets compared against Stenglein for the overlapping 
  years -- see 2a-iii. Confirm the QC comparison looks clean before trusting 
  Stenglein as authoritative.

------------------------------------------------------------------------*/

* ---------------------------------- 2a-i. -------------------------------------

* 2014 prehunt population (Rolley). Explicit County/Zone columns (unlike
* the parsed-from-name approach needed for 2a-ii/2a-iii below) -- header
* is a messy multi-row merged block, so imported by column letter rather
* than firstrow.

import excel "$dataRAW/Deer_Population/WI/Demog.Deer.NDMU.14.Rolley.xlsx", ///
    sheet("Sheet1") cellrange(A9) clear
rename C county_name
rename D zone
rename O pop_prehunt_bucks
rename P pop_prehunt_does

keep county_name zone pop_prehunt_bucks pop_prehunt_does
drop if missing(county_name)

* Collapse zones within a county -- population counts are additive across
* the zone subunits that tile a county, so summing recovers the
* county-level prehunt estimate. Zone-level detail is discarded here;
* flagging if zone-level granularity turns out to be wanted later.
*
* NOTE: collapse (sum) treats MISSING as 0. Any county whose zone rows
* carry no estimate therefore comes out as 0, not missing -- list those
* rows first so the distinction stays visible.
count if missing(pop_prehunt_bucks) | missing(pop_prehunt_does)
di as txt "zone rows with a missing prehunt estimate: " r(N)
list county_name zone pop_prehunt_bucks pop_prehunt_does ///
    if missing(pop_prehunt_bucks) | missing(pop_prehunt_does), noobs sep(0)

collapse (sum) pop_prehunt_bucks pop_prehunt_does, by(county_name)
gen pop_prehunt = pop_prehunt_bucks + pop_prehunt_does

* Menominee comes out at 0 here (median county is ~13,000), which reads as "no 
* estimate" rather than "no deer" -- Menominee is managed largely outside the 
* standard WDNR DMU structure (see Section 3a). Kept as reported for now; 
* uncomment to treat it as missing instead:
*   replace pop_prehunt = . if pop_prehunt == 0
list county_name pop_prehunt if pop_prehunt == 0, noobs
count if pop_prehunt == 0
assert r(N) == 1                    // Menominee only

gen year = 2014

gen name_clean = upper(strtrim(subinstr(county_name, ".", "", .)))
merge m:1 name_clean using "$dataSTATA/WI/WI_county_crosswalk.dta", ///
    keepusing(county_fips) keep(match master) gen(_merge_xwalk)
list county_name if _merge_xwalk == 1
* Anything above is a DMU whose county-portion of the name didn't match a real 
* county -- check for metro/island subunits (e.g. Madeline Island) folded in 
* under an unexpected label before dropping.
drop if _merge_xwalk == 1
drop _merge_xwalk name_clean pop_prehunt_bucks pop_prehunt_does

label variable county_fips "WI county FIPS code (from crosswalk merge)"
label variable year        "Population estimate year"
label variable pop_prehunt "Prehunt deer population (bucks + does), summed over zones"
label data "WI county prehunt deer population, 2014 only (Rolley, new DMU)"

order county_fips county_name year pop_prehunt
save "$dataSTATA/WI/temp_WI_pop_prehunt_2014_raw.dta", replace

* ---------------------------------- 2a-ii. ------------------------------------

* 2015-2018 posthunt population (Stenglein) -- PRIMARY source for this
* period. DMU name needs parsing: zone is always the last word, county is
* everything before it (see geography note above).

import delimited "$dataRAW/Deer_Population/WI/Demog.Deer.Harvest_Pop.DMU.2015-2018.Stenglein.csv", ///
    clear varnames(1) stringcols(1)

gen zone = word(dmu, wordcount(dmu))
gen last_word_len = length(zone)
gen county_name = trim(substr(dmu, 1, length(dmu) - last_word_len))
drop last_word_len

* collapse (sum) treats missing as 0 -- list any DMU row with no estimate
* before summing, so a zero county can be told apart from a real zero.
count if missing(posthuntpopest)
di as txt "DMU rows with a missing posthunt estimate: " r(N)
list dmu year posthuntpopest if missing(posthuntpopest), noobs sep(0)

collapse (sum) posthuntpopest, by(county_name year)
rename posthuntpopest pop_posthunt

count if pop_posthunt == 0
di as txt "county-years summing to 0 posthunt population: " r(N)
list county_name year if pop_posthunt == 0, noobs sep(0)

gen name_clean = upper(strtrim(subinstr(county_name, ".", "", .)))
merge m:1 name_clean using "$dataSTATA/WI/WI_county_crosswalk.dta", ///
    keepusing(county_fips) keep(match master) gen(_merge_xwalk)
list county_name year if _merge_xwalk == 1
* Same check as 2a-i -- expect Madeline Island (and possibly other metro 
* subunits) to show up here across all 4 years.
drop if _merge_xwalk == 1
drop _merge_xwalk name_clean

label variable county_fips  "WI county FIPS code (from crosswalk merge)"
label variable year         "Population estimate year"
label variable pop_posthunt "Posthunt deer population estimate, summed across zones within county"
label data "WI county posthunt deer population, 2015-2018 (Stenglein, new DMU)"

order county_fips county_name year pop_posthunt
save "$dataSTATA/WI/temp_WI_pop_posthunt_2015-2018_stenglein_raw.dta", replace

* ---------------------------------- 2a-iii. -----------------------------------

* 2015-2017 posthunt population (WDNR online) -- QC cross-check against
* Stenglein, NOT merged into the final panel. Two sheets, two different
* row structures:
*   "2015-16": county name repeated across unlabeled zone blocks -- zone
*     boundaries aren't recoverable from the plain cell values (no merged
*     header cells survive to identify block breaks), but that's fine
*     since we're collapsing to county level anyway.
*   "2017": DMU name needs the same last-word parsing as Stenglein.

import excel "$dataRAW/Deer_Population/WI/Demog.Deer.NDMU.15-17.WDNR.Online.xlsx", ///
    sheet("2015-16") cellrange(A2) firstrow clear
rename ZoneCounty county_name
drop if missing(county_name) | strpos(county_name, "Source") > 0

ds county_name, not
local yearvars `r(varlist)'
local yr = 2015
foreach v of local yearvars {
    rename `v' p`yr'
    local yr = `yr' + 1
}
gen row_id = _n
list county_name p2015 p2016 if missing(real(p2015))
destring p*, replace force
reshape long p, i(row_id) j(year)
rename p pop_posthunt_wdnr
collapse (sum) pop_posthunt_wdnr, by(county_name year)
tempfile wdnr1516
save `wdnr1516'

import excel "$dataRAW/Deer_Population/WI/Demog.Deer.NDMU.15-17.WDNR.Online.xlsx", ///
    sheet("2017") cellrange(A2) firstrow clear
rename DMU dmu
rename B pop_posthunt_wdnr
drop if missing(dmu) | strpos(dmu, "Source") > 0

gen zone = word(dmu, wordcount(dmu))
gen county_name = trim(substr(dmu, 1, length(dmu) - length(zone)))
gen year = 2017
list dmu pop_posthunt_wdnr if missing(real(pop_posthunt_wdnr))
destring pop_posthunt_wdnr, replace force
collapse (sum) pop_posthunt_wdnr, by(county_name year)

append using `wdnr1516'

gen name_clean = upper(strtrim(subinstr(county_name, ".", "", .)))
merge m:1 name_clean using "$dataSTATA/WI/WI_county_crosswalk.dta", ///
    keepusing(county_fips) keep(match master) gen(_merge_xwalk)
list county_name year if _merge_xwalk == 1
drop if _merge_xwalk == 1
drop _merge_xwalk name_clean

label data "WI county posthunt population, 2015-2017 (WDNR online; QC only)"
save "$dataSTATA/WI/temp_WI_pop_posthunt_2015-2017_wdnr_qc.dta", replace

* QC comparison: how well does WDNR agree with Stenglein for the years
* they overlap? Review this before trusting Stenglein as authoritative -- large/
* systematic gaps would mean picking one source silently (as this script 
* currently does) is the wrong call.
merge 1:1 county_fips year using "$dataSTATA/WI/temp_WI_pop_posthunt_2015-2018_stenglein_raw.dta", ///
    keepusing(pop_posthunt) keep(match) gen(_merge_qc)
gen pop_posthunt_diff = pop_posthunt - pop_posthunt_wdnr
summarize pop_posthunt_diff, detail
count
local _qc_n = r(N)
count if abs(pop_posthunt_diff) > 0 & !missing(pop_posthunt_diff)
di as txt "WDNR vs Stenglein: " r(N) " of `_qc_n' overlapping county-years differ"
count if abs(pop_posthunt_diff) > 0.05 * pop_posthunt_wdnr & !missing(pop_posthunt_diff)
di as txt "  of those, differing by more than 5 pct: " r(N)
list county_fips county_name year pop_posthunt pop_posthunt_wdnr pop_posthunt_diff ///
    if abs(pop_posthunt_diff) > 0, sep(0)

* ---------------------------------- 2b. ---------------------------------------

* Combine the two population sources (2014 prehunt + 2015-2018 posthunt)
* into a single population dataset to merge onto the harvest spine.

use "$dataSTATA/WI/temp_WI_pop_prehunt_2014_raw.dta", clear
append using "$dataSTATA/WI/temp_WI_pop_posthunt_2015-2018_stenglein_raw.dta"

isid county_fips year
order county_fips county_name year pop_prehunt pop_posthunt
save "$dataSTATA/WI/temp_WI_population_2014-2018_raw.dta", replace

* ---------------------------------- 2c. [DEFERRED] -----------------------------
* Old numeric-DMU population/density/goals (Demog_Deer_DMU_81-13_Rolley.xlsx,
* 1981-2013, sheets Population/Density/Goals). NOT merged into the county
* panel -- no crosswalk from these numeric unit codes to county boundaries
* exists in the files provided. Flagged per the geography note at the top of 
* this section: worth checking whether a historical DMU boundary shapefile 
* exists before writing this off, since it would extend WI's population coverage 
* back to 1981. Raw file untouched on disk in the meantime.

*==============================================================================
* SECTION 3: BUILD THE COUNTY-YEAR PANEL
*==============================================================================

/*------------------------------------------------------------------------

Spine: the harvest panel (Section 1b), county_fips x year x harvest_method,
1960-2015. Population merges on by (county_fips year) only -- NOT by
harvest_method, since WI's population estimates aren't split by harvest
method the way VA's BKI/pop_index were split by land_ownership. That means
`merge m:1` (not `merge 1:1`) here: every harvest_method row for a given
county-year gets the same population value broadcast onto it.

Population coverage (2014-2018) only partially overlaps the harvest
spine's range (1960-2015): 2014 will match, 2015 will match, but 2016-2018
population falls entirely outside the harvest spine and will NOT survive
this merge, the same way VA's BKI (1994-2014) simply didn't match harvest
rows outside its own range. Flagged: if 2016-2018 population is
wanted in the final panel, the spine itself needs to be extended with
harvest-missing rows for those years first -- not attempted here, to keep
this merge parallel to VA's discipline of letting the harvest panel define
the year range.

------------------------------------------------------------------------*/

* ---------------------------------- 3a. --------------------------------------

use "$dataSTATA/WI/temp_WI_harvest_1960-2015_raw.dta", clear
isid county_fips year harvest_method

merge m:1 county_fips year ///
    using "$dataSTATA/WI/temp_WI_population_2014-2018_raw.dta", ///
    keepusing(pop_prehunt pop_posthunt) keep(master match) gen(_merge_pop)
* Expect _merge_pop == 1 (master-only) for every year outside 2014-2015
* (population's overlap with the harvest spine). Anything else unmatched
* is worth investigating.
tab year _merge_pop if year >= 2010
list county_fips county_name harvest_method if _merge_pop == 1 & year == 2015
* Menominee County (55078) has no posthunt population estimate in Stenglein for 
* any year 2015-2018 -- confirmed absent from the source file entirely, not a 
* parsing/matching miss. Likely because Menominee is mostly the Menominee Indian 
* Reservation and managed outside the standard WDNR DMU structure. Population is 
* legitimately missing for Menominee in 2015; its 2014 prehunt value is 0 for the 
* same reason (see 2a-i).

* Population can only attach to 2014 (prehunt) and 2015 (posthunt) rows.
assert _merge_pop == 1 if !inrange(year, 2014, 2015)
assert missing(pop_prehunt)  if year != 2014
assert missing(pop_posthunt) if year != 2015
count if !missing(pop_prehunt)
assert r(N) == 72 * 4               // every county, all four methods, 2014
count if !missing(pop_posthunt)
assert r(N) == 71 * 4               // Menominee absent from Stenglein
drop _merge_pop

* ---------------------------------- 3b. --------------------------------------

* Final cleanup, documentation, save

order county_fips county_name year harvest_method ///
    harvest_antlered harvest_antlerless pop_prehunt pop_posthunt

recast int year            // was a double from the reshape j() variable

label variable pop_prehunt  "Prehunt deer population, 2014 only (bucks + does, summed over zones)"
label variable pop_posthunt "Posthunt deer population, 2015 only (summed over zones)"
label data "WI county-year deer harvest by method + population, 1960-2015"

notes: Harvest source: Rolley county workbook (WDNR). Row unit is county x year x harvest method (Total, Gun, Bow, XBow). XBow exists for 2014-2015 only: crossbow harvest was not tracked separately before 2014.
notes pop_prehunt: 2014 only, from the Rolley new-DMU file (bucks + does, summed across the zones within each county). A prehunt estimate is NOT the same quantity as pop_posthunt, so the two are kept as separate variables rather than spliced into one series. Menominee is 0 because its zone rows carry no estimate and collapse (sum) treats missing as 0 -- read it as no estimate (do-file Section 2a-i).
notes pop_posthunt: 2015 only within this panel's range, from Stenglein's compiled new-DMU series (2015-2018; 2016-2018 fall outside the harvest spine). Menominee has no estimate in any year -- managed largely outside the standard WDNR DMU structure.
notes: Old numeric-DMU population (1981-2013) is NOT included: those unit codes do not map to counties without a historical DMU boundary shapefile (do-file Section 2c). WDNR online posthunt figures (2015-2017) are kept only as a QC cross-check against Stenglein.
notes harvest_antlered: Missing (source blanks, not zero) in 29 rows and harvest_antlerless in 32: Milwaukee Gun and Bow 1960-1971, Menominee Gun/Bow, Lafayette Bow 1971.

isid county_fips year harvest_method
assert inrange(year, 1960, 2015)
count
assert r(N) == 12240
foreach mth in Total Gun Bow {
    count if harvest_method == "`mth'"
    assert r(N) == 4032
}
count if harvest_method == "XBow"
assert r(N) == 144
sort county_fips year harvest_method
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/WI/WI_deer_harmonized_county_year_1960-2015.dta", replace

log close
