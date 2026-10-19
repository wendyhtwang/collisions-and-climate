/*==============================================================================

FILE NAME:   NY_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  New York (NY) county-level deer HARVEST harmonization. Second
          "single file, no population" state after IN, but introduces the
          town+county NESTING wrinkle flagged in the state-sequencing
          notes: the source is reported at TOWN level, nested within
          COUNTY, not at county level directly. This script's Section 2
          therefore adds a COLLAPSE step IN has no need for -- town-level
          rows are summed up to county-year before the FIPS merge, rather
          than merged directly.

          Town names in the source are truncated to 7 characters (e.g.
          "BETHLEH" for Bethlehem, "WATERVL" for Watervliet) and in
          places genuinely ambiguous on their own. This is NOT a problem
          here: county_fips is assigned via the COUNTY field (a stable
          4-character county code, unrelated to the town truncation), and
          the collapse to county-year sums numeric columns without ever
          keying on town identity. A full town-name-to-FIPS crosswalk is
          out of scope for this county-year deliverable. (The superseded
          Kelly file had no duplicate COUNTY/TOWN/YEAR rows; the reissue
          has 6 such pairs -- see the NOTE below -- which still sum
          correctly into county totals.)

          Source (flat CSV, already long by COUNTY/TOWN/YEAR): COUNTY,
          TOWN, YEAR, AD_MALE, FN_MALE, AD_FEMALE, FN_FEMALE -- 68,632
          rows, 56 counties x 1954-2023 (70 years).

          [UPDATE 08/27/2026] NY State Department of Environmental Conservation 
	  follow-up contact sent historic_deerkill_totals_1954_2023.csv, an 
	  agency reissue that SUPERSEDES the original Kelly file
          (NY_Harvest_1954-2014_CountyTownSex_Kelly.csv). Verified to
          match the Kelly file exactly on all 3,416 overlapping 1954-2014
          county-year sums, and extends coverage nine more years to 2023
          (+504 county-years). 
	  
	  Two structural differences from Kelly, both handled in Section 2: 
	  (1) no STAR column -- the annotation Kelly carried (see the SUPERSEDED 
	  note below) isn't part of this reissue, so the STAR diagnostic block 
	  is removed; (2) no Total column -- harvest_total is now DERIVED as the 
	  row sum of the four age/sex categories, justified by the Kelly-file
          identity check (Total == component sum in 100% of 59,796 rows)
          carrying over exactly in the overlap years of this reissue too
          (re-verified). The Kelly file and its raw path are retained in dataRAW 
	  for provenance but are no longer the import source as of this update.

          Source uses an age/sex taxonomy (adult male / fawn male / adult 
	  female / fawn female) DIFFERENT from the antlered/antlerless split 
	  used in IN/KY/MD/OH/NC/MO/CA/VA/WI. Kept as reported 
	  (harvest_adult_male, harvest_fawn_male, harvest_adult_female, 
	  harvest_fawn_female) rather than force-mapped to antlered/antlerless 
	  -- adult male is not necessarily equivalent to "antlered" (button 
	  bucks among fawns complicate that equivalence) and collapsing the
          taxonomies would silently discard information. Confirm whether
          a derived antlered/antlerless pair (e.g. antlered = adult male,
          antlerless = fawn male + adult female + fawn female) is wanted
          alongside the source-native categories for cross-state
          regression consistency, or whether NY's taxonomy stays as-is.

          County coverage is 56 of NY's 62 counties -- the five NYC
          boroughs (Bronx, Kings, New York, Queens, Richmond) and Nassau
          are absent from every year of the source. Confirmed this is a
          source-file characteristic, not an import error: the crosswalk
          (Section 1) was checked against the full 62-county Census list
          and the 6 missing codes (BRON, KING, NASS, "NEW ", QUEE, RICH)
          never appear anywhere in the raw CSV. Consistent with these
          being areas with no significant regulated deer season (NYC
          boroughs entirely urban; Nassau effectively suburban Long
          Island) rather than a reporting gap -- also independently
          confirmed with NYSDEC, and the same goes for the greater Buffalo
          City area (WMU 9C).

          NOTE: No separate statewide-total reference sheet exists
          for NY (unlike IN's TotalHarvestYear tab) -- this is a single
          flat file with no independent aggregate to reconcile against.
          QC is therefore limited to: (a) the Kelly-file-derived row-level
          identity (Total == AD_MALE+FN_MALE+AD_FEMALE+FN_FEMALE),
          re-verified against this reissue's 2015-2023 rows before import; (b) 
	  an exact match against Kelly's county-year totals for the full 
	  1954-2014 overlap (see [UPDATE] note above); and, in this script, (c) 
	  no missing components at town grain, the 12-row duplicate pin, 
	  county-year balance, and a town-count variation summary (Section 2c).

          NOTE: This reissue introduces 6 (COUNTY,TOWN,YEAR) pairs
          with TWO rows each (12 rows total) that Kelly never had:
          CLIN/BEEKMAN 2018, ESSE/NORTH H 2017, ESSE/NORTH H 2018,
          JEFF/LORRAIN 2018, WYOM/GENESEE 2017, WYOM/GENESEE 2018. The
          paired rows are NOT identical duplicates (e.g. Beekman 2018:
          14/0/1/0 vs 20/1/7/1) -- most likely two distinct
          hamlets/villages sharing a 7-character truncated town label,
          the exact truncation-collision risk flagged (and, in the
          Kelly file, ruled out) in the earlier header note. Both rows
          are retained and summed rather than one being dropped as a
          duplicate -- correct for this script's purposes since Section
          2 collapses to county-year without ever keying on town
          identity, so both entries contribute correctly to the county
          total either way. The town-level isid check below is relaxed
          accordingly (was a hard uniqueness assert against Kelly; now
          documents the 12-row exception explicitly rather than asserting a 
	  false uniqueness).

          NOTE / FOLLOW-UP (NYSDEC): Within several counties, the SET of towns 
	  reported varies across years (24 of 56 counties affected) -- e.g. 
	  Albany County reports 13 towns in most years but only 12 in 2013
          (Green Island absent that year). This looks like town-level
          under-reporting in specific years rather than towns
          administratively appearing/disappearing (NY town boundaries are
          stable over this period). County-year sums in affected
          years/counties are therefore likely modest undercounts relative
          to true county totals. Documented here, not imputed or
          flagged row-by-row -- full county x year x town completeness
          table would need agency follow-up to resolve properly.

          [SUPERSEDED 08/27/2026] Kelly's STAR column (asterisk on 3,252
          of 59,796 rows, unknown meaning) is moot as of the DEC
          reissue -- historic_deerkill_totals_1954_2023.csv carries no
          such column, so the diagnostic-count block built for it is
          removed in this update rather than kept around unused.

          DECISION (08/27/2026): NYSDEC's follow-up also sent
          county-year-ADJACENT but NOT county-level population data:
          antlered deer harvest density (antlered harvest per square mile)
          by Wildlife Management Unit (WMU), 89 units, 1955-2025, plus a
          WMU boundary shapefile (92 units -- 3 more than the density file
          covers, e.g. "1A"/"2A"/"9C" have no density series, plausibly
          closed-to-hunting Adirondack interior units). Following the
          project's established zone-exclusion precedent (CA deer
          assessment zones, WI pre-2014 DMUs): WMUs are a fluid
          management geography, not the static county/city/town unit
          this panel requires, and the shapefile's attribute table
          (UNIT, UNITSQMILE, MOREINFO URL, GlobalID) carries no county
          field -- building a zone-to-county crosswalk would require a
          full GIS spatial join against a county boundary layer, out of
          scope here. EXCLUDED from the panel; Section 3 documents this
          and retains the shapefile as reference/mapping material. The
          series is also a harvest-derived DENSITY index (deer per sq.
          mi.), not a population count -- see the Section 3.

SOURCE FILES USED:

  historic_deerkill_totals_1954_2023.csv -- primary harvest source as of
                                              08/27/2026, supersedes
                                              Kelly (see [UPDATE] note
                                              above).
					      
  NY_Harvest_1954-2014_CountyTownSex_Kelly.csv -- superseded; retained in
                                                    dataRAW for provenance
                                                    only, no longer
                                                    imported by this
                                                    script.
						    
  antlered_deer_harvest_density_history_for_nat_heritage.csv -- WMU-level
                                                    density index, 1955-
                                                    2025; excluded from
                                                    the panel, see Section
                                                    3.
						    
  Wildlife_Management_Units.shp (+ .dbf/.shx/.cpg/.prj) -- WMU boundary
                                                    shapefile; reference/
                                                    mapping material only,
                                                    not imported, see
                                                    Section 3.

CHANGELOG:

08/19/2026 — Nicole: First pass. Harvest-only panel (harvest_total,
                     harvest_adult_male, harvest_fawn_male,
                     harvest_adult_female, harvest_fawn_female), 56
                     counties, 1954-2014. Static FIPS crosswalk (state
                     FIPS 36, 56 of 62 counties -- 5 NYC boroughs +
                     Nassau absent from source). Town-level source rows
                     collapsed to county-year sums; row-level Total
                     identity holds exactly. Population Section 3 left
                     explicitly empty: no source file, not an exclusion
                     call (same pattern as IN).

08/27/2026 — Nicole: NYSDEC agency follow-up response incorporated.
                     Harvest source switched to the reissued
                     historic_deerkill_totals_1954_2023.csv, extending
                     the panel from 1954-2014 to 1954-2023 (56 counties
                     x 70 years, 3,920 obs); verified exact match
                     against the prior Kelly-sourced panel on all 3,416
                     overlapping county-years. STAR-column handling
                     removed (column not present in reissue). Six
                     (COUNTY,TOWN,YEAR) pairs with two source rows each
                     documented and retained (summed into county
                     totals; does not affect county-year uniqueness).
                     WMU-level antlered-harvest-density data and a WMU
                     boundary shapefile received; both excluded from
                     the panel per the zone-geography exclusion
                     precedent and documented in Section 3 rather than
                     silently dropped -- population panel remains empty
                     for NY.

09/16/2026 — Nicole: Clean up pass, no change to data values. Header
                     de-staled (Kelly-era "no duplicates"/"946 towns"/"one
                     sheet" claims; unclosed parenthesis). New asserts: no
                     missing components at town grain (collapse (sum)
                     would otherwise treat them as 0 silently), year range,
                     crosswalk merge all-matched, 70 years per county, 29
                     reported zero county-years (Montgomery 1954-68,
                     Suffolk 1954-67). Section 2c's town-count tempfile
                     was built but never used -- now summarized to the
                     log. FIPS crosswalk verified against Census 2020
                     (56/56). Labels shortened to Stata's 80-char limit;
                     long-form documentation moved to -notes-. Panel sorted
                     before save.

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
log using "$codeSTATA/logs/NY_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/NY"
cap mkdir "$dataCLEAN/NY"

*==============================================================================
* SECTION 1: COUNTY / FIPS CROSSWALK
*==============================================================================

/*------------------------------------------------------------------------

Like IN/KY/OH/NC/MO/MD, no source row carries a FIPS code -- only the
4-character COUNTY code described above. Built here as a static
reference table (state FIPS 36, 56 of NY's 62 counties -- see note above on the 
6 absent counties).

Typed from standard Census county FIPS assignments, not pulled from a
project source file. VERIFIED 09/16/2026: all 56 codes match the Census
2020 county FIPS reference list exactly; the 6 Census units not in the
crosswalk are exactly the five NYC boroughs (36005, 36047, 36061, 36081,
36085) and Nassau (36059). All 56 source COUNTY codes matched exactly to
a unique crosswalk row -- zero unmatched codes, confirmed by pre-code
audit and asserted in Section 2d.

NOTE: source COUNTY code for St. Lawrence is "ST L" (four characters
including an internal space -- first four characters of "St Lawrence"
with no period). Not a truncation collision with any other county, and
name_clean below (uppercase/trim/strip spaces+periods) resolves it
cleanly to the same merge key as every other county.

------------------------------------------------------------------------*/

input str20 county_name str4 county_code str3 fips_suffix
"Albany"       "ALBA" "001"
"Allegany"     "ALLE" "003"
"Broome"       "BROO" "007"
"Cattaraugus"  "CATT" "009"
"Cayuga"       "CAYU" "011"
"Chautauqua"   "CHAU" "013"
"Chemung"      "CHEM" "015"
"Chenango"     "CHEN" "017"
"Clinton"      "CLIN" "019"
"Columbia"     "COLU" "021"
"Cortland"     "CORT" "023"
"Delaware"     "DELA" "025"
"Dutchess"     "DUTC" "027"
"Erie"         "ERIE" "029"
"Essex"        "ESSE" "031"
"Franklin"     "FRAN" "033"
"Fulton"       "FULT" "035"
"Genesee"      "GENE" "037"
"Greene"       "GREE" "039"
"Hamilton"     "HAMI" "041"
"Herkimer"     "HERK" "043"
"Jefferson"    "JEFF" "045"
"Lewis"        "LEWI" "049"
"Livingston"   "LIVI" "051"
"Madison"      "MADI" "053"
"Monroe"       "MONR" "055"
"Montgomery"   "MONT" "057"
"Niagara"      "NIAG" "063"
"Oneida"       "ONEI" "065"
"Onondaga"     "ONON" "067"
"Ontario"      "ONTA" "069"
"Orange"       "ORAN" "071"
"Orleans"      "ORLE" "073"
"Oswego"       "OSWE" "075"
"Otsego"       "OTSE" "077"
"Putnam"       "PUTN" "079"
"Rensselaer"   "RENS" "083"
"Rockland"     "ROCK" "087"
"St Lawrence"  "ST L" "089"
"Saratoga"     "SARA" "091"
"Schenectady"  "SCHE" "093"
"Schoharie"    "SCHO" "095"
"Schuyler"     "SCHU" "097"
"Seneca"       "SENE" "099"
"Steuben"      "STEU" "101"
"Suffolk"      "SUFF" "103"
"Sullivan"     "SULL" "105"
"Tioga"        "TIOG" "107"
"Tompkins"     "TOMP" "109"
"Ulster"       "ULST" "111"
"Warren"       "WARR" "113"
"Washington"   "WASH" "115"
"Wayne"        "WAYN" "117"
"Westchester"  "WEST" "119"
"Wyoming"      "WYOM" "121"
"Yates"        "YATE" "123"
end

gen county_fips = "36" + fips_suffix
gen name_clean  = upper(subinstr(subinstr(strtrim(county_code), ".", "", .), " ", "", .))

isid county_fips
isid name_clean
count
assert r(N) == 56

label variable county_fips  "NY county FIPS code (5-digit, state+county)"
label variable county_name  "County name (Census spelling; St Lawrence without period)"
label variable county_code  "Source 4-character county code, as reported in raw CSV"
label variable name_clean   "Merge key: county_code upper-cased, trimmed, periods/spaces removed"
label data "NY county FIPS crosswalk, 56 of 62 counties (no NYC boroughs, Nassau)"

save "$dataSTATA/NY/NY_county_crosswalk.dta", replace
describe

*==============================================================================
* SECTION 2: HARVEST DATA - Import, Collapse Town->County, Merge
*==============================================================================

/*------------------------------------------------------------------------

Source is town-level, long by COUNTY/TOWN/YEAR -- the nesting wrinkle
flagged in the header. Import directly (already long, no reshape), run
row-level QC at town grain, then COLLAPSE (sum) to county-year before
the FIPS merge. This collapse step is what distinguishes NY from IN's
otherwise-identical "single file, no population" pattern.

------------------------------------------------------------------------*/

*--------------------------------- 2a. -----------------------------------

* [UPDATE 08/27/2026] Source switched to the NYSDEC reissue, which
* supersedes Kelly -- see header [UPDATE] note. No STAR column, no Total
* column in this file (both handled below).
import delimited "$dataRAW/Deer_Harvest/NY/historic_deerkill_totals_1954_2023.csv", ///
    varnames(1) case(preserve) stringcols(1 2) clear

rename COUNTY county_code
rename TOWN   town_name
rename YEAR   year
rename AD_MALE   harvest_adult_male
rename FN_MALE   harvest_fawn_male
rename AD_FEMALE harvest_adult_female
rename FN_FEMALE harvest_fawn_female

count
assert r(N) == 68632

* collapse (sum) below treats missing as 0 -- a missing component would
* silently undercount the county-year. Check there are none.
assert !missing(harvest_adult_male, harvest_fawn_male, ///
    harvest_adult_female, harvest_fawn_female)
assert inrange(year, 1954, 2023)

* [header NOTE]: 6 (county_code,town_name,year) pairs have TWO
* source rows each (12 rows total) -- NOT a Kelly-style duplicate-file
* issue, both rows carry different values and are retained. isid is
* therefore NOT asserted at town grain here (would fail on these 12
* rows); duplicates are listed for the record instead.
duplicates tag county_code town_name year, gen(_dup)
list county_code town_name year harvest_adult_male harvest_fawn_male ///
    harvest_adult_female harvest_fawn_female if _dup > 0, sep(0)
count if _dup > 0
assert r(N) == 12
drop _dup

*--------------------------------- 2b. ----------------------------------

* [UPDATE 08/27/2026] harvest_total is DERIVED here (this source has no
* Total column), justified by the Kelly-file identity check (Total ==
* component sum in all 59,796 rows of the superseded file, and
* re-verified for this reissue's 2015-2023 rows before import) -- see header 
* [UPDATE] note. Not a new judgment call, just no longer an independently 
* reported figure to check the derived sum against.
gen harvest_total = harvest_adult_male + harvest_fawn_male + harvest_adult_female + harvest_fawn_female

*--------------------------------- 2c. -----------------------------------

* [header NOTE]: town SET varies by year within 24 of 56 counties (Kelly-
* era audit figure) -- documented as likely under-reporting rather than
* town creation/dissolution. Summary written to the log below (distinct
* town labels per county-year, so the 6 duplicated pairs don't inflate it).
preserve
    contract county_code town_name year
    contract county_code year, freq(n_towns)
    bysort county_code: egen _min = min(n_towns)
    bysort county_code: egen _max = max(n_towns)
    egen _tag = tag(county_code)
    count if _tag & _min != _max
    di as txt "counties whose reported town count varies across years: " r(N) " of 56"
    list county_code _min _max if _tag & _min != _max, noobs sep(0)
restore

*--------------------------------- 2d. -----------------------------------

collapse (sum) harvest_total harvest_adult_male harvest_fawn_male ///
    harvest_adult_female harvest_fawn_female, by(county_code year)

isid county_code year
count
assert r(N) == 3920
* 56 counties x 70 years (1954-2023), confirmed balanced at the county
* level -- every county has a row in every year, even in the town-set-
* variation years noted above (a missing TOWN row lowers that county-
* year's sum, it does not drop the county-year entirely) and even in
* the 6 town-name-collision years noted in Section 2a (both rows sum
* into the same county-year without issue).

gen name_clean = upper(subinstr(subinstr(strtrim(county_code), ".", "", .), " ", "", .))
merge m:1 name_clean using "$dataSTATA/NY/NY_county_crosswalk.dta", ///
    keepusing(county_fips county_name) gen(_merge_xwalk)
list county_code year if _merge_xwalk != 3
* All 56 source codes matched the crosswalk exactly in the Section 1
* pre-code audit -- every row must match, in both directions.
assert _merge_xwalk == 3
drop _merge_xwalk name_clean
bysort county_fips: assert _N == 70

isid county_fips year
count
codebook county_fips, compact

save "$dataSTATA/NY/temp_NY_harvest_1954-2023.dta", replace

*==============================================================================
* SECTION 3: POPULATION DATA - WMU-level density received, excluded
*==============================================================================

/*------------------------------------------------------------------------

[UPDATE 08/27/2026] Unlike IN (which never received any population
file), NY's follow-up DID produce population-adjacent data -- but at
WMU (Wildlife Management Unit) resolution, not county. Per the
project's zone-exclusion precedent (CA deer assessment zones, WI
pre-2014 DMUs), this is excluded from the panel rather than broadcast
or force-mapped to county. Documented here as an affirmative exclusion
decision, not a data-availability gap -- distinct from Section 3's
original "no file provided" framing for IN/NY-as-of-08/19.

Source received: antlered_deer_harvest_density_history_for_nat_heritage.csv
-- antlered harvest per square mile, 89 WMUs, 1955-2025, two source
vintages flagged in its own "source" column (reconstructed_townships
pre-dating the WMU system; deerbook_WMU_calc post-implementation).

Also received: Wildlife_Management_Units.shp (+ .dbf/.shx/.cpg/.prj) --
a WMU boundary shapefile, 92 units. Its attribute table (UNIT,
UNITSQMILE, MOREINFO, GlobalID) carries no county field, so it does not
by itself provide a zone-to-county crosswalk; resolving one would
require a full GIS spatial join against a county boundary layer, out of
scope for this script. Per Jen's guidance that agency zone/unit
shapefiles are worth requesting "for reference and mapping purposes"
even when the population data itself is excluded, the shapefile is
retained in dataRAW as reference material but is NOT imported or merged
here.

Even setting the crosswalk problem aside, the WMU series is a harvest-derived 
DENSITY index (antlered deer harvested per sq. mi.), not a population count or 
estimate -- the same index-vs-count distinction already documented for VA's 
buck-kill-per-sqmi series. A resolved zone-to-county crosswalk would therefore 
feed a density index into the panel, not a population variable in the MO/OH 
sense; worth flagging whether that distinction matters for how a future 
crosswalk effort (if undertaken) would be used downstream.

NY's population panel remains empty. No county-level population
variable is available for NY as of this update.

------------------------------------------------------------------------*/

*==============================================================================
* SECTION 4: FINALIZE HARVEST-ONLY PANEL
*==============================================================================

/*------------------------------------------------------------------------

No population to merge in (Section 3), so the county-year harvest panel
from Section 2 IS the final panel.

------------------------------------------------------------------------*/

use "$dataSTATA/NY/temp_NY_harvest_1954-2023.dta", clear

order county_fips county_name year harvest_total harvest_adult_male ///
    harvest_fawn_male harvest_adult_female harvest_fawn_female county_code

label variable county_fips           "NY county FIPS code (5-digit string, state+county)"
label variable county_name           "County name (Census spelling, from crosswalk)"
label variable year                  "Harvest year"
label variable harvest_total         "Total deer harvested (derived: sum of the four age/sex categories)"
label variable harvest_adult_male    "Adult male deer harvested (county-year sum of town-level rows)"
label variable harvest_fawn_male     "Fawn (button buck) male deer harvested (county-year sum of town rows)"
label variable harvest_adult_female  "Adult female deer harvested (county-year sum of town-level rows)"
label variable harvest_fawn_female   "Fawn female deer harvested (county-year sum of town-level rows)"
label variable county_code           "Source 4-character NYSDEC county code"
label data "NY county-year deer harvest (adult/fawn x male/female), 1954-2023, NYSDEC"

notes: Source: NYSDEC reissue historic_deerkill_totals_1954_2023.csv (supersedes the Kelly 1954-2014 file; matches it exactly on all 3,416 overlapping county-years). Reported at town level; summed to county-year (do-file Section 2).
notes harvest_total: No Total column in the reissue; derived as the sum of the four age/sex categories (identity held in every row of the superseded Kelly file). 29 reported zeros: Montgomery 1954-1968 and Suffolk 1954-1967.
notes county_fips: 56 of 62 NY counties. The five NYC boroughs and Nassau never appear in the source (confirmed with NYSDEC). The set of reporting towns varies across years within some counties, so affected county-years may be modest undercounts.
notes: Harvest-only panel. NYSDEC WMU-level antlered harvest density (1955-2025) and WMU shapefile received but excluded (zone geography, no county field; density index, not a population count). See do-file Section 3.

isid county_fips year
assert year >= 1954 & year <= 2023
assert harvest_total >= 0
assert harvest_adult_male >= 0
assert harvest_fawn_male >= 0
assert harvest_adult_female >= 0
assert harvest_fawn_female >= 0
assert harvest_total == harvest_adult_male + harvest_fawn_male + harvest_adult_female + harvest_fawn_female
count
assert r(N) == 3920
bysort county_fips: assert _N == 70
count if harvest_total == 0
assert r(N) == 29
assert (county_fips == "36057" & year <= 1968) | (county_fips == "36103" & year <= 1967) ///
    if harvest_total == 0
sort county_fips year
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/NY/NY_deer_harmonized_county_year_1954-2023.dta", replace

log close
