/*==============================================================================

FILE NAME:   CWD_deer_harmonization.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Deer Harvest/Population Harmonization

CURRENT LEAD: Nicole Martinez

PURPOSE:  Harmonization of the Cornell Wildlife Health Lab's North American
          Wildlife Agency CWD Testing and Ancillary Data (2000-2022) --
          a single PRE-COMPILED 16-state county-by-season-year dataset
          (31,636 rows; AR FL GA IN IA KY MD MI MN MS NY NC OH TN VA WI)
          covering CWD surveillance test counts, deer harvest, cervid-
          industry infrastructure, state CWD-relevant regulations, and
          county geography/land-cover covariates.

          This source differs from the state-by-state scripts in three ways
          that shape the script below:
	  
            (i)   it is one multi-state file with uniform structure, so it is
                  processed by ONE script into ONE combined panel rather than
                  split into 16 per-state files;
		  
            (ii)  it carries five-digit FIPS codes directly
                  (Management_area_ID = STATEFP+COUNTYFP), so -- like VA and
                  unlike every other state -- NO name-to-FIPS crosswalk is
                  needed; Section 2 verifies the shipped codes instead of
                  building a crosswalk;
		  
            (iii) the source has ALREADY imputed gaps in 13 variables by
                  carrying values forward from the most recent prior
                  season (flagged in *_imputed columns). The source values 
		  are KEPT and the flags are carried into the panel as 0/1 
		  indicators, so downstream users can drop carried-forward 
		  values if they want reported-only series. See Section 5.

          This source overlaps the existing state harvest panels. The state 
	  panels built from agency source files remain the harvest series of 
	  record, and this panel is primarily for the CWD surveillance,
          infrastructure, and regulation variables no state panel
          carries.

SOURCE FILES USED:

  NA_wildlife_agency_CWD_surveillance_data_2000_2022_v2.csv
        -- the Dataset itself, downloaded from the Cornell eCommons
           repository (DOI: 10.7298/7txw-2681.2, accessed 03/31/2026).
           Edition 2, publication date 2024-05-02; v2 corrects errors in
           v1 (Them et al. 2023) per its metadata.
        -- NOTE a versioning wrinkle: the distributed file is named
           ..._2000_2022_v2.csv, the metadata's own entity file name is
           ..._2000_2021.csv, the internal build step (readme 4.32) names
           ..._2000_2021_v20240402.3.csv, and the metadata's stated time
           period ends 2021-06-30 -- yet the data contain a 2021-22
           season. All the same dataset; the 2021-22 rows carry NO test
           data and mostly imputed harvest (see Section 3 note).

CITATION (per readme 1.1.7): Schuler KL, Hanley BJ, Abbott RC, et al. 2024.
  North American Wildlife Agency CWD Testing and Ancillary Data (2000-2022)
  [Dataset]. Cornell University Library eCommons Repository.
  DOI: 10.7298/7txw-2681.2. CC BY 4.0.

CHANGELOG:

08/25/2026 — Nicole: First pass. Pre-code audit confirmed: key uniqueness; a
                     fully balanced 1,438-county x 22-season panel; valid FIPS
                     with state prefixes matching the state variable everywhere;
                     time-invariance of the county geography attributes; the
                     carry-forward imputation rule holding EXACTLY in 100% of
                     flagged rows; both cumulative Boolean variables consistent
                     with their season-level counterparts; and 5 rows
                     violating the buck+doe=total identity (Section 6).
                     Decisions: keep the full 43-column variable set; keep
                     source-imputed values with flags rather than blanking them;
                     one combined panel, not 16 per-state files.

09/15/2026 — Nicole: Cleanup pass, no change to data values. Section 1 now
                     lists and checks the source header row before the
                     rename-by-position (the comment claimed a verbatim
                     header assert that the code never ran). Per-state
                     county counts, the 5,078-row identity base, and the 29
                     captive-year detections are now asserted. Section 7:
                     added an AR cross-check (AR panel postdates the first
                     pass) -- AR 2003 in this source is ~22% of the agency
                     county file; overlap notes updated (AR, NY). Removed a
                     dangling line continuation in Section 8.

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
log using "$codeSTATA/logs/CWD_deer_harmonization.log", replace text

cap mkdir "$dataSTATA/CWD"
cap mkdir "$dataCLEAN/CWD"

*==============================================================================
* SECTION 1: IMPORT, HEADER VERIFICATION & MISSING-VALUE HANDLING
*==============================================================================

/*------------------------------------------------------------------------

  1. Several source headers exceed Stata's 32-character variable-name
     limit (e.g. Intrastate_movement_of_live_cervids_numeric_imputed, 51
     chars), and the truncation import delimited would apply COLLIDES for
     the base/_imputed twins of the two longest regulation names. Rather
     than depend on version-specific truncation/uniquification behavior,
     the file is imported with varnames(nonames), the header row is
     listed to the log and checked (43 columns, all non-empty, first
     column = Management_area_ID), and columns are then renamed BY
     POSITION to project names. NOT YET PINNED: a verbatim assert of all
     43 header names -- until it is added, a reordering of columns
     2-43 upstream would NOT be caught here (the Section 2/5/6 value
     checks would likely catch most, but not all, such shifts).

  2. The CSV encodes missing as the literal string "NA" and
     Management_area_ID carries leading zeros, so everything is imported
     as string, "NA" is blanked explicitly, and numeric columns are
     destrung WITHOUT -force- -- non-numeric residue should error here,
     not be silently coerced to missing (stricter than the destring-force
     habit of the early state scripts, same reasoning as the later ones).

------------------------------------------------------------------------*/

import delimited "$dataRAW/NAWA_CWD/NA_wildlife_agency_CWD_surveillance_data_2000_2022_v2.csv", ///
    varnames(nonames) stringcols(_all) clear

count
assert r(N) == 31637   // 31,636 data rows + 1 header row
quietly describe
assert r(k) == 43

* Row 1 holds the source's own column names. List them to the log and
* check the structure BEFORE renaming by position.
forvalues i = 1/43 {
    di as txt "v`i' = " v`i'[1]
}
forvalues i = 1/43 {
    assert v`i'[1] != "" & v`i'[1] != "NA"
}
assert v1[1] == "Management_area_ID"
drop in 1
assert _N == 31636

rename (v1-v43) (county_fips season_label county_name state               ///
    area_sqm longitude latitude cwd_tests_positive cwd_tests_negative     ///
    cwd_positive_ever cervid_facilities taxidermists processors           ///
    harvest_total harvest_buck harvest_doe                                ///
    reg_breeding_facilities reg_hunting_enclosures reg_interstate_import  ///
    reg_intrastate_movement reg_baiting reg_feeding reg_carcass_import    ///
    reg_urine_lures cwd_captive_year cwd_captive_ever                     ///
    forest_cover clay_percent stream_dist_avg stream_length               ///
    flag_cervid_facilities flag_taxidermists flag_processors              ///
    flag_harvest_total flag_forest_cover                                  ///
    flag_reg_breeding_facilities flag_reg_hunting_enclosures              ///
    flag_reg_interstate_import flag_reg_intrastate_movement               ///
    flag_reg_baiting flag_reg_feeding flag_reg_carcass_import             ///
    flag_reg_urine_lures)

* Source encodes missing as the literal string "NA" -- blank it before
* destring (no -force-: any other non-numeric residue must error).
foreach v of varlist _all {
    quietly replace `v' = "" if `v' == "NA"
}

destring area_sqm longitude latitude cwd_tests_positive cwd_tests_negative ///
    cwd_positive_ever cervid_facilities taxidermists processors            ///
    harvest_total harvest_buck harvest_doe reg_* cwd_captive_year          ///
    cwd_captive_ever forest_cover clay_percent stream_dist_avg             ///
    stream_length, replace

describe, short
list county_fips season_label state harvest_total in 1/3
isid county_fips season_label

*==============================================================================
* SECTION 2: KEYS, GEOGRAPHY & PANEL-STRUCTURE QC
*==============================================================================

/*------------------------------------------------------------------------

No crosswalk section: the source carries FIPS directly (STATEFP+COUNTYFP from 
the Census 2022 1:500k Cartographic Boundary Files, per its metadata). So 
instead of building name-to-FIPS, this section VERIFIES the shipped codes:

  - key uniqueness (county x season) and full balance: 1,438 counties x
    22 seasons = 31,636 rows, every county present in every season;
    
  - every FIPS is 5 digits and its 2-digit state prefix agrees with the
    state abbreviation, row by row;
    
  - county counts per state match Census (AR 75, FL 67, GA 159, IN 92,
    IA 99, KY 120, MD 24, MI 83, MN 87, MS 82, NY 62, NC 100, OH 88,
    TN 95, VA 133, WI 72 -- verified in audit; total pinned at 1,438);
    
  - county attributes that should be time-invariant (name, area,
    centroid, soils, streams) are constant within county.

Membership notes vs the existing state panels (audit-confirmed,
retained as shipped -- this source zero-fills or NA-fills units the
state agency sources omit):

  - MD includes Baltimore City (24510), which the MD panel excludes
    because the Eyler source omits it; here it appears with harvest only
    2016-17 onward and no test data at all.
    
  - NY includes all 62 counties -- the five NYC boroughs and Nassau,
    absent from the NY panel's town-level source, appear here (the
    boroughs with explicit ZERO harvest in the two seasons NY reports
    sex detail).
    
  - TN includes DeKalb County (47041), structurally absent from the TN
    panel's season files.
    
  - VA has 133 county/city units vs the VA panel's 137 -- this source's
    Census 2022 vintage postdates independent-city consolidations
    reflected in the older VA harvest file.

------------------------------------------------------------------------*/

isid county_fips season_label

* full balance: 1,438 counties x 22 seasons
by county_fips, sort: gen _nseasons = _N
assert _nseasons == 22
drop _nseasons
quietly tab county_fips
assert r(r) == 1438

* county counts per state (Census; VA 133 = post-2013 Bedford city merger)
foreach pair in "AR 75" "FL 67" "GA 159" "IN 92" "IA 99" "KY 120" "MD 24" ///
                "MI 83" "MN 87" "MS 82" "NY 62" "NC 100" "OH 88" "TN 95"  ///
                "VA 133" "WI 72" {
    local st : word 1 of `pair'
    local n  : word 2 of `pair'
    quietly tab county_fips if state == "`st'"
    assert r(r) == `n'
}

* FIPS shape + state-prefix agreement
assert strlen(county_fips) == 5 & real(county_fips) != .
gen _stfips = ""
foreach pair in "AR 05" "FL 12" "GA 13" "IN 18" "IA 19" "KY 21" "MD 24"  ///
                "MI 26" "MN 27" "MS 28" "NY 36" "NC 37" "OH 39" "TN 47"  ///
                "VA 51" "WI 55" {
    local st : word 1 of `pair'
    local fp : word 2 of `pair'
    quietly replace _stfips = "`fp'" if state == "`st'"
}
assert _stfips != ""
assert substr(county_fips, 1, 2) == _stfips
drop _stfips

* time-invariance of county attributes
foreach v in county_name state area_sqm longitude latitude clay_percent ///
             stream_dist_avg {
    bysort county_fips (season_label): assert `v' == `v'[1]
}
* stream_length is also time-invariant but missing for 47 counties (no
* Strahler-order-4+ stream in the county -- arguably a structural zero,
* but the source ships NA and it is preserved as missing rather than recoded; 
* stream_dist_avg IS populated for these counties)
bysort county_fips (season_label): assert stream_length == stream_length[1] ///
    | (missing(stream_length) & missing(stream_length[1]))

*==============================================================================
* SECTION 3: SEASON-YEAR -> YEAR (season-start convention)
*==============================================================================

/*------------------------------------------------------------------------

The source's season label ("2000-01" = July 1 2000 - June 30 2001) is
converted to the project's season-START-year convention (2000-01 -> 2000),
matching the treatment of TN's season codes and DE's season labels.
Unlike those two states, here the convention is NOT an assumption: the
source metadata defines the season window explicitly (readme 2.1.3.3).
The source label is retained alongside as season_label.

Panel year range is therefore 2000-2021 (season-start years). Note the
2021-22 season sits OUTSIDE the metadata's stated time period (ends
2021-06-30) and is thin: NO state has any test data in 2021-22 (tests
run 2000-01 through 2020-21 only), and 1,197 of its 1,356 non-missing
harvest values (88%) are carried forward from 2020-21. Retained as
shipped, with the imputation flags (Section 5) marking the carried rows.

------------------------------------------------------------------------*/

gen int year = real(substr(season_label, 1, 4))
assert year >= 2000 & year <= 2021
* label's ending two digits always == (year+1) mod 100
assert real(substr(season_label, 6, 2)) == mod(year + 1, 100)

isid county_fips year

*==============================================================================
* SECTION 4: VARIABLE LABELS (project vocabulary)
*==============================================================================

/*------------------------------------------------------------------------

Columns were already renamed (by verified position) in Section 1. Harvest
carries the harvest_* names used in the state panels (harvest_total /
harvest_buck / harvest_doe, matching KY's total/buck and CA's buck/doe
naming); surveillance and regulation variables get cwd_* / reg_* stubs.
Label text is condensed from readme Section 2 attribute definitions.

Harvest caveats (audit-confirmed):

  - MS ships NO harvest at all; MI and MN ship totals only (2019-2021),
    no sex detail.
    
  - NY ships buck detail for all 62 counties only in 2019-20 & 2020-21,
    and doe detail ONLY for the five NYC boroughs (as zeros) in those
    two seasons -- a source asymmetry, retained as shipped.
    
  - harvest_buck / harvest_doe are NEVER imputed by the source (its
    carry-forward list covers harvest_total but not the components), so
    components can be missing in rows where the total is carried.

Regulation variables are ADMINISTRATIVE-AREA-level (state-level) values
broadcast by the source to every county in the state -- audit confirmed
they are constant within state-season. They exist 2012-13 onward only,
and intrastate movement is never reported for AR or GA. Ordinal coding
throughout: 1 allowed / 0.5 restricted / 0 prohibited.

------------------------------------------------------------------------*/

label variable county_fips        "County FIPS code (5-digit, state+county; source Management_area_ID)"
label variable county_name        "County name (Census NAMELSAD spelling)"
label variable state              "State (2-letter ANSI abbreviation)"
label variable season_label       "Season-year as shipped (Jul 1 - Jun 30, e.g. 2000-01)"
label variable year               "Season-start year (2000-01 -> 2000)"
label variable cwd_tests_positive "CWD-positive wild WTD tests in county-season (ELISA/IHC)"
label variable cwd_tests_negative "CWD-negative wild WTD tests in county-season (ELISA/IHC)"
label variable cwd_positive_ever  "1 = county had >=1 positive test this season or any prior"
label variable cwd_captive_year   "1 = CWD detected in captive herd, county-season (APHIS; 1-or-missing)"
label variable cwd_captive_ever   "1 = CWD detected in captive facility this season or any prior (APHIS)"
label variable harvest_total      "Hunter-harvested WTD (source-imputed; see harvest_total_imputed)"
label variable harvest_buck       "Hunter-harvested male WTD (never imputed by source)"
label variable harvest_doe        "Hunter-harvested female WTD (never imputed by source)"
label variable cervid_facilities  "Captive cervid facilities in county (source-imputed)"
label variable taxidermists       "Taxidermy businesses in county (source-imputed)"
label variable processors         "Cervid meat processors in county (source-imputed)"
label variable reg_breeding_facilities "State reg: captive breeding facilities (1 allowed/.5 restricted/0 prohibited)"
label variable reg_hunting_enclosures  "State reg: hunting enclosures (1/.5/0)"
label variable reg_interstate_import   "State reg: interstate live-cervid import (1/.5/0)"
label variable reg_intrastate_movement "State reg: intrastate live-cervid movement (1/.5/0; never reported AR, GA)"
label variable reg_baiting             "State reg: baiting of cervids (1/.5/0)"
label variable reg_feeding             "State reg: feeding of cervids (1/.5/0)"
label variable reg_carcass_import      "State reg: whole-carcass importation (1/.5/0)"
label variable reg_urine_lures         "State reg: urine-based lures (1/.5/0)"
label variable area_sqm           "County area incl. inland water, sq m (Census 2022 1:500k)"
label variable longitude          "County inner-centroid longitude"
label variable latitude           "County inner-centroid latitude"
label variable forest_cover       "Prop. forest/shrub/wetland cover (NALCMS; source-imputed between epochs)"
label variable clay_percent       "Avg pct clay, upper 50cm of soil (Hengl 2018)"
label variable stream_dist_avg    "Avg distance (m) to nearest Strahler-4+ stream (NHDPlus)"
label variable stream_length      "Total length (m) of Strahler-4+ streams in county (missing = none)"

*==============================================================================
* SECTION 5: SOURCE IMPUTATION FLAGS
*==============================================================================

/*------------------------------------------------------------------------

The source pre-imputes 13 variables by last-observation-carried-forward
across seasons within county (readme 4.32) and ships a string flag
("imputed"/"not imputed") for each. Unlike our state scripts, undoing it here 
would discard the source's own record of WHICH values were reported.

DECISION: keep the source's imputed values, carry the flags as 0/1 byte 
indicators named {var}_imputed (1 = carried forward, 0 = agency-reported,
missing = value itself missing). Users wanting reported-only series drop flagged 
values, e.g.: replace harvest_total = . if harvest_total_imputed == 1

Audit verified, and the asserts below re-verify, that the flags are
internally airtight: (i) a flag is missing exactly when its value is
missing; (ii) every flagged value EQUALS the prior season's value (exact
carry-forward, 100% of flagged rows, all 13 variables); (iii) nothing is
flagged in a county's first season (nothing to carry from).

------------------------------------------------------------------------*/

local impvars cervid_facilities taxidermists processors harvest_total     ///
    forest_cover reg_breeding_facilities reg_hunting_enclosures           ///
    reg_interstate_import reg_intrastate_movement reg_baiting             ///
    reg_feeding reg_carcass_import reg_urine_lures

foreach v of local impvars {
    assert inlist(flag_`v', "imputed", "not imputed", "")
    * flag missing <=> value missing
    assert (flag_`v' == "") == missing(`v')
    gen byte `v'_imputed = (flag_`v' == "imputed") if flag_`v' != ""
    * exact carry-forward: flagged value equals prior season's value
    bysort county_fips (year): assert `v' == `v'[_n-1] if `v'_imputed == 1
    * never flagged in a county's first season
    bysort county_fips (year): assert `v'_imputed != 1 if _n == 1
    label variable `v'_imputed "1 = carried fwd from prior season by source; 0 = agency-reported"
    drop flag_`v'
}

*==============================================================================
* SECTION 6: INTERNAL-CONSISTENCY QC
*==============================================================================

/*------------------------------------------------------------------------

(a) Cumulative Booleans. cwd_positive_ever and cwd_captive_ever are
    ever-hit indicators; both re-derive EXACTLY from their season-level
    counterparts (zero mismatches in 31,636 rows -- unlike most sources,
    this one's derived variables actually check out).

    cwd_captive_year is shipped as 1-or-NA (29 ones, zero explicit 0s) even 
    though its metadata defines an explicit 0 ("all others were set to 0", 
    readme 4.30) -- a metadata-vs-data inconsistency. Retained as shipped; the
    assert below treats missing as 0 when re-deriving the cumulative
    version, which reconciles exactly. Recode missing->0 downstream if
    the metadata's definition is wanted.

(b) Harvest identity. In the 5,078 rows where total, buck, and doe are
    all non-missing, total = buck + doe in all but FIVE rows (audit):
    
        19025 Calhoun IA  2010-11   129 vs   83+45   (+1)
        19027 Carroll IA  2010-11   391 vs  224+166  (+1)
        19075 Grundy  IA  2010-11   138 vs   83+54   (+1)
        47155 Sevier  TN  2018-19   374 vs  278+95   (+1)
        51019 Bedford VA  2019-20  7522 vs 3730+3798 (-6)
	
    Same treatment as IN/MO in the state scripts: source-reported totals
    retained, discrepancies documented, nothing reconciled. The assert
    pins the count at exactly 5 so any change in the source surfaces.

(c) Test coverage documented, no assert. Tests span seasons 2000-01
    through 2020-21 only, and coverage varies hugely by state: WI/VA
    report from 2000-01, AR/IA/MI/NY from 2001-02/2002-03, but most
    southeastern states only from 2016-2018, and MD reports tests in
    just four seasons (2016-2019). Nothing anywhere in 2021-22.

------------------------------------------------------------------------*/

* (a) cumulative Booleans re-derive exactly
assert inlist(cwd_positive_ever, 0, 1)
assert inlist(cwd_captive_ever, 0, 1)
assert cwd_captive_year == 1 | missing(cwd_captive_year)   // no explicit 0s shipped
count if cwd_captive_year == 1
assert r(N) == 29

bysort county_fips (year): gen _cumpos = ///
    sum(cond(missing(cwd_tests_positive), 0, cwd_tests_positive) > 0)
assert cwd_positive_ever == (_cumpos > 0)
bysort county_fips (year): gen _cumcap = ///
    sum(cond(missing(cwd_captive_year), 0, cwd_captive_year))
assert cwd_captive_ever == (_cumcap > 0)
drop _cumpos _cumcap

* (b) harvest identity: count, inspect, then pin at the 5 known violations
* (same count/list-then-document flow as IN's Section 2 row-level check,
* plus a pinned assert so a re-downloaded source can't drift silently)
gen _rowdiff = harvest_total - harvest_buck - harvest_doe ///
    if !missing(harvest_total, harvest_buck, harvest_doe)
count if !missing(_rowdiff)
assert r(N) == 5078
list county_fips county_name state season_label harvest_total harvest_buck ///
    harvest_doe _rowdiff if _rowdiff != 0 & !missing(_rowdiff), sep(0)
count if _rowdiff != 0 & !missing(_rowdiff)
assert r(N) == 5
drop _rowdiff

* nonnegativity of counts
foreach v in cwd_tests_positive cwd_tests_negative harvest_total          ///
             harvest_buck harvest_doe cervid_facilities taxidermists      ///
             processors {
    assert `v' >= 0 if !missing(`v')
}
* ordinal regulations in {0, .5, 1}
foreach v of local impvars {
    if strpos("`v'", "reg_") == 1 {
        assert inlist(`v', 0, 0.5, 1) if !missing(`v')
    }
}
* proportions and coordinates in range
assert forest_cover >= 0 & forest_cover <= 1 if !missing(forest_cover)
assert clay_percent >= 0 & clay_percent <= 100
assert longitude > -180 & longitude < 0 & latitude > 0 & latitude < 90

save "$dataSTATA/temp_CWD_panel_qc_passed.dta", replace

*==============================================================================
* SECTION 7: CROSS-CHECK AGAINST EXISTING STATE HARVEST PANELS
*==============================================================================

/*------------------------------------------------------------------------

Ten of the sixteen states here now have harmonized harvest panels, but
season coverage barely overlaps. County-years with non-missing harvest
on both sides: WI (2000-2015), TN (2015), AR (2001-2014; the AR panel
was built after the first pass of this script), and NY (2019-2021; the
NY panel was extended to 2023). Findings:

  WI: 1,151 overlapping county-years vs the WI panel's Total-method
      antlered+antlerless sum. Correlation 0.99994, but only 28% match
      exactly. 2000-2004 match exactly for most counties (65-88% exact,
      median |diff| 0); 2005-2015 diverge at the ~1-2% level (median
      |diff| 24-80 head/county). Pattern is consistent with the two
      pipelines drawing different vintages of WIDNR's county harvest
      series (registration revisions), not with a processing error on
      either side. (audit, 08/25/2026.)
      
  TN: 94 counties in 2015 only. Mean |diff| 79 head (~5% of county
      harvest), ZERO exact matches -- the TN panel's TWRA season files
      and this source's TWRA 2023/2024 extracts are clearly different
      vintages. (audit, 08/25/2026; no Stata block below.)
      
  AR: 1,050 overlapping county-years, 2001-2014 (audit, 09/16/2026). 300 of 
      them -- every county in 2002, 2004, 2008, and 2009 -- are values this 
      source CARRIED FORWARD, whereas the AR panel has agency-reported values 
      for those years. Of the 750 reported rows, 666 match exactly: 2001, 2006, 
      and 2010-2014 match for all 75 counties; 2005 (71/75) and 2007 (69/75) 
      differ slightly (-339 and -531 head statewide). 2003 does NOT: this 
      source sums to 23,674 vs 107,353 in the AR panel (1 of 75 exact) -- about 
      22% of the agency county file, which itself reconciles to the AR statewide
      total within 0.7%. Treat this source's AR 2003 harvest (and the
      carried-forward AR years) as unusable for harvest.
      
  NY: 2019-2021 overlap not yet checked.

Neither side is adjusted. The state panels remain the harvest series of record 
where they exist; this panel's harvest variables are retained as shipped for use 
alongside its surveillance variables (internally consistent by construction, 
e.g. as tests-per-harvest denominators).

The blocks below re-run the WI and AR checks when those panels are
present; they REPORT rather than assert -- differences are expected.

------------------------------------------------------------------------*/

capture confirm file "$dataCLEAN/WI/WI_deer_harmonized_county_year_1960-2015.dta"
if _rc == 0 {
    preserve
    use "$dataCLEAN/WI/WI_deer_harmonized_county_year_1960-2015.dta", clear
    keep if harvest_method == "Total"
    gen double panel_total = harvest_antlered + harvest_antlerless
    keep county_fips year panel_total
    tempfile wi
    save `wi'
    restore

    preserve
    keep if state == "WI" & !missing(harvest_total)
    merge 1:1 county_fips year using `wi', keep(match) nogen
    gen diff = harvest_total - panel_total
    quietly count
    di as txt "WI cross-check: " r(N) " overlapping county-years"
    quietly count if diff == 0
    di as txt "  exact matches: " r(N)
    summarize diff, detail
    correlate harvest_total panel_total
    restore
}

capture confirm file "$dataCLEAN/AR/AR_deer_harmonized_county_year_1988-2014.dta"
if _rc == 0 {
    preserve
    use county_fips year harvest_total ///
        using "$dataCLEAN/AR/AR_deer_harmonized_county_year_1988-2014.dta", clear
    rename harvest_total panel_total
    tempfile ar
    save `ar'
    restore

    preserve
    keep if state == "AR" & !missing(harvest_total)
    merge 1:1 county_fips year using `ar', keep(match) nogen
    gen diff = harvest_total - panel_total
    gen byte exact = (diff == 0)
    quietly count
    di as txt "AR cross-check: " r(N) " overlapping county-years"
    quietly count if diff == 0 & harvest_total_imputed == 0
    di as txt "  exact matches among source-reported rows: " r(N)
    * per-year sums and exact-match counts (2003: ~23.7k vs ~107.4k)
    tabstat harvest_total panel_total exact harvest_total_imputed, ///
        by(year) stat(sum) nototal
    restore
}

*==============================================================================
* SECTION 8: FINALIZE COMBINED PANEL
*==============================================================================

use "$dataSTATA/temp_CWD_panel_qc_passed.dta", clear

order county_fips county_name state year season_label                      ///
      cwd_tests_positive cwd_tests_negative cwd_positive_ever              ///
      cwd_captive_year cwd_captive_ever                                    ///
      harvest_total harvest_buck harvest_doe                               ///
      cervid_facilities taxidermists processors                            ///
      reg_breeding_facilities reg_hunting_enclosures reg_interstate_import ///
      reg_intrastate_movement reg_baiting reg_feeding reg_carcass_import   ///
      reg_urine_lures                                                      ///
      area_sqm longitude latitude forest_cover clay_percent                ///
      stream_dist_avg stream_length *_imputed

* (dataset labels cap at 80 chars -- provenance details go in notes)
label data "CWD surveillance & ancillary panel, 16 states, 2000-2021 (Cornell CWHL v2)"
note: Source: Cornell Wildlife Health Lab, North American Wildlife Agency CWD Testing and Ancillary Data (2000-2022), v2, DOI 10.7298/7txw-2681.2, accessed 03/31/2026. Season-start-year convention (2000-01 -> 2000).
note: Source-imputed (carried-forward) values RETAINED, flagged in *_imputed (1 = carried, 0 = agency-reported) -- see CWD_deer_harmonization.do Section 5. For reported-only series, set flagged values to missing.
note: Where this panel overlaps the per-state harvest panels (AR 2001-2014, WI 2000-2015, TN 2015), values differ across source vintages, and AR 2003 is about 22 pct of the agency county file; the state panels remain the harvest series of record -- see CWD_deer_harmonization.do Section 7.

isid county_fips year
assert year >= 2000 & year <= 2021
count
assert r(N) == 31636
assert r(N) == 1438 * 22
confirm variable harvest_total_imputed forest_cover_imputed reg_baiting_imputed
foreach v of varlist *_imputed {
    assert inlist(`v', 0, 1) | missing(`v')
}
codebook county_fips, compact

describe
summarize
browse

save "$dataCLEAN/CWD_deer_harmonized_county_year_2000-2021.dta", replace

log close
