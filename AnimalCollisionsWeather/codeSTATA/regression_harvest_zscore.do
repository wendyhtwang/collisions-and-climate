/*==============================================================================

FILE NAME:   regression_harvest_zscore.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Preliminary Weather -> Deer Harvest Regressions

CURRENT LEAD: Nicole Martinez

PURPOSE:  Regression table: the effect of winter conditions on county deer
          harvest, outcome = the WITHIN-COUNTY z-score of harvest,
          estimated on the FULL unbalanced panel rather than the 2005-2014
          balanced window.

          Third companion to regression_log_harvest.do (Table 1) and
          regression_harvest_per1000.do (Table 2), which run the same
          4 x 5 grid on log(harvest_total) and on harvest per 1,000
          residents. The three files differ in Section 2 (the outcome) and
          in the QC that references it; everything else is deliberately
          identical so the three tables can be read side by side.

          The table is 4 PANELS x 5 COLUMNS. Panels vary the winter
          measure; columns vary the specification.

              PANEL A   mean_winter_temp        Dec t-1 + Jan t + Feb t, deg C
              PANEL B   warm_winter_1sd         1 SD or more above county norm
              PANEL C   wsi_cold_days           days min temp at or below 0F
              PANEL D   winter_severity_index   cold days + days 18in+ snow

              COL 1   county FE + state x year FE   full panel
              COL 2   + weather controls            full panel
              COL 3   + age shares                  full panel
              COL 4   + weather + age shares        full panel
              COL 5   + weather + age shares        agency-direct only

SOURCE FILES USED:
  /mnt/data_d/Dropbox/Research/AnimalCollisionsWeather/dataSTATA/main_data_county_year.dta
        -- the merged analysis panel: harvest (from
           US_deer_harvest_county_year.dta, built by
           deer_harvest_national_append.do), PRISM/ERA5 weather, Census
           population and age shares, and the collision variables.
           151,145 county-years, 1927-2025, 309 variables. Only the
           harvest, weather, population and provenance variables are
           touched here; the collision block is untouched.

OUTPUT:
  $tables/wildlife_weather/regression_harvest_zscore.tex   LaTeX fragment
  $tables/wildlife_weather/regression_harvest_zscore.csv   plain mirror

CHANGELOG:

09/14/2026 — Nicole: Written to follow regression_log_harvest.do and
                     regression_harvest_per1000.do after the meeting with
                     Eyal. Full unbalanced panel from 1981 (2); column 5
                     keyed on source_harvest rather than
                     main_sample_agency (3); old county+year column
                     removed (4); weather control row renamed and variable
                     definitions moved out of the stub labels into the
                     table notes (5); specification block moved to the
                     bottom and counts reported once (7). The moments move
                     with the sample: they are now the county's own 1981+
                     mean and SD, not the 2005-2014 window's (13).

==============================================================================
DECISIONS TAKEN IN THIS SCRIPT
==============================================================================

1. [DECIDE] THE REPORTED ZEROS ARE KEPT, BUT ONE COUNTY STILL DROPS.

   The z-score is defined at a harvest of 0, so the 103 reported zeros in
   1981+ are retained here as they are in Table 2, not dropped as log()
   drops them in Table 1. Only 70 of them survive into the estimation
   sample, against 98 in Table 2, and the 28-row difference is entirely
   San Francisco (06075) -- see decision 13. This table therefore runs on
   30,342 county-years / 1,577 counties: Table 2's 30,370 / 1,578 less
   San Francisco, and Table 1's 30,272 / 1,577 plus 70 retained zeros.
   Section 6b asserts both identities.

   [DEFERRED] Eyal's count-model suggestion (Poisson / ppmlhdfe) for
   Table 1's zeros is not attempted here either.

2. THE SAMPLE IS THE FULL UNBALANCED PANEL FROM 1981, NOT A BALANCED
   WINDOW.

   Per Eyal (09/11/2026): run on everything available; imbalance is
   acceptable at this preliminary stage. main_sample and
   main_sample_agency are therefore NOT used, and nothing here requires a
   county to appear in every year.

   The effective panel starts in 1982, not 1981. mean_winter_temp for
   year t is built from December of t-1, and the PRISM extraction begins
   in 1981, so every 1981 row is missing all four winter measures. 1981
   contributes zero observations to every column. Reported in Section 6
   so the gap is visible rather than mysterious.

   Imbalance costs this table more than it costs the other two, because
   the outcome's own moments are estimated county by county on whatever
   years that county contributes. See decision 14.

3. [DECIDE] COLUMN 5 USES source_harvest, NOT main_sample_agency.

   main_sample_agency is defined upstream as "balanced 2005-2014 AND
   agency-direct". Using it here would silently re-impose the balanced
   window that decision 2 removes, making column 5 a different sample in
   two ways at once rather than one. The agency-direct restriction is
   therefore applied through source_harvest == "agency", which is the
   same provenance test without the balance requirement.

   That gives 14 agency-direct states against 19 in the full panel. The
   five dropped are the CWD gap-fill states (FL, GA, IA, MI, MN) --
   see deer_harvest_national_append.do [DECIDE] 8.

   NOTE that the moments in decision 13 are computed ONCE, on the full
   panel, and are NOT recomputed on the agency-direct subsample. Column 5
   is a restriction of the same outcome variable, not a different one, so
   its coefficient stays comparable with columns 1-4 down the column.

4. COLUMN 1 OF THE OLD TABLE (county FE + year FE) IS REMOVED.

   Per Eyal (09/11/2026). Every remaining column carries county and
   state x year fixed effects, so the "Year FE" row is gone too.

5. WEATHER CONTROLS ARE MARCH-NOVEMBER OF YEAR t ONLY.

   Monthly mean temperature, heavy-precipitation days (>10mm) and total
   snowfall, m3 through m11. December through February are deliberately
   EXCLUDED: the winter regressor is built from Dec/Jan/Feb, and
   controlling for those months would partial out the variation the
   table is about.

   [CHANGED 09/11] On the old 2005-2014 window, July and August snowfall
   were identically zero and were excluded by name -- 25 controls rather
   than 27. That is NOT true of the full 1981+ panel: both months reach
   nonzero snowfall in high-elevation county-years the narrow window
   never contained. Section 3 therefore tests each snowfall month for
   variation on the sample actually being estimated and includes it if it
   varies, reporting any it drops. On the current vintage all nine are
   kept, so the control set is 27.

   The row is labelled simply "Weather controls" per Eyal; the month
   range and contents are in the table notes.

6. AGE SHARES: 17 OF 18, pop_share_0_4 OMITTED.

   The 18 shares sum to 1 by construction, so one has to go. Dropping
   pop_share_0_4 by hand means the omitted category is identical in
   every column and does not move if the panel is rebuilt.

7. SEs CLUSTERED ON COUNTY THROUGHOUT.

   The cluster count prints once, in the specification block at the
   bottom, not inside each panel.

8. THE TWO R-SQUARED ROWS MEASURE DIFFERENT THINGS, AND BOTH STAY --
   BUT THE SECOND ONE DOES NOT MEAN HERE WHAT IT MEANS IN TABLES 1 AND 2.

   e(r2_within) behaves as it does in the other two tables: it is
   specific to the panel's own regressor and does vary across panels. In
   column 1 it reads 0.000 / 0.000 / 0.000 / 0.001 for panels A/B/C/D,
   with D the largest, the same ordering both other tables show.

   e(r2) does NOT. It sits near 0.50 here against 0.92 in Table 2 and
   0.94 in Table 1, and that is arithmetic rather than a finding: the
   outcome is already centred within county by construction, so the
   county fixed effects have almost no level left to absorb and e(r2) is
   picking up state x year variation and nothing else. It is NOT
   evidence that this specification explains less. Reported for
   consistency with the other two tables; it should not be read across
   the three.

9. THE WINTER ANOMALY IS "1 SD OR MORE", AS INTENDED.

   Verified for Table 1 on 09/11/2026 and unchanged here: warm_winter_1sd
   is built upstream as strictly greater than the county's own mean +
   1 SD, but there are zero exact ties, so ">" and ">=" select the same
   county-years.

   Note that warm_winter_1sd standardizes the REGRESSOR against county
   norms and this table standardizes the OUTCOME against them. In Panel B
   both sides are county-standardized; the coefficient is then "SDs of
   own harvest per mild-winter year", which is the most directly
   interpretable cell in the table and also the one most exposed to
   decision 14.

10. PANELS C AND D ARE NESTED, DELIBERATELY.

    winter_severity_index = wsi_cold_days + wsi_snow_days, so Panel C's
    regressor is a component of Panel D's. They are reported as separate
    panels, never entered jointly. Panel D moving relative to Panel C is
    the snow component doing work.

    On this outcome Panel C is significant at 5% on its own in four of
    five columns -- stronger than in either other table. Section 6g
    enters the two components jointly and finds that significance does
    not survive holding snow days fixed, the same result Table 1 gives.
    Panel C should not be read as a cold-stress effect here either.

11. [DECIDE] WINTER DATING

    All four measures are the winter IMMEDIATELY PRECEDING the fall-t
    hunting season, so no lag is applied. Raynor's DVC chapter
    instruments with winter severity one year further back, on the
    theory that the channel is fawn recruitment rather than same-season
    condition. If that is the intended timing every panel needs an L1.
    and the whole table shifts. Can be a one-line change in Section 4.

    Whatever is decided applies to Tables 1, 2 and 3 together.

12. THE FRAGMENT MUST END ON A COMMENT LINE.

    The last thing written to the .tex is "% end of fragment". A
    fragment ending in \addlinespace scans past the end of file for an
    optional argument and swallows the wrapper's \bottomrule; a fragment
    ending in a blank line emits a \par inside the tabular. Both produce
    "Misplaced \noalign". A comment line ends cleanly.

13. [DECIDE] THE MOMENTS ARE THE COUNTY'S OWN 1981+ MEAN AND SD,
    COMPUTED ONCE ON EVERY YEAR THE COUNTY REPORTS HARVEST.

    harvest_z = (harvest_total - h_mean_c) / h_sd_c, where h_mean_c and
    h_sd_c are taken over that county's non-missing harvest_total in
    1981+ -- every such row, NOT only the rows that survive into an
    estimation sample, and NOT recomputed per column or per subsample.
    The outcome is therefore one variable with one definition, identical
    in all five columns, which is what the old 2005-2014-window version
    of this decision was for; only the window it is anchored to has
    changed, because decision 2 removed the old one.

    Two consequences, both deliberate:

      -- A county whose harvest never varies has h_sd_c == 0 and no
         z-score. Exactly one county is in that position: SAN FRANCISCO
         (06075), zero harvest in all 29 years it reports. It was
         already contributing no identifying variation in Table 2 (county
         FE absorb it outright), so its 28 estimation rows leaving costs
         the table nothing but the count. Named in Section 2's log.

      -- Counties enter the estimation sample only where the winter
         measures and the controls are also present, but their MOMENTS
         come from the wider set of rows. That is the right way round:
         moments that moved with the control set would make the columns
         non-comparable.

14. [DECIDE] THIS TABLE IS A REWEIGHTING OF TABLE 2, NOT INDEPENDENT
    EVIDENCE -- AND ON AN UNBALANCED PANEL THE WEIGHTS GET EXTREME.

    Under county fixed effects, h_mean_c/h_sd_c is a county constant and
    is absorbed, so regressing harvest_z is ARITHMETICALLY IDENTICAL to
    regressing harvest_total/h_sd_c. Section 6f runs both and asserts the
    coefficients agree. The estimator is therefore the levels regression
    with each county weighted by 1/h_sd_c, and the coefficients read in
    SDs of a county's own harvest.

    The weights span three orders of magnitude on this panel: h_sd_c runs
    from 0.71 to 4,508 deer, so 1/h_sd_c has a p99/p1 ratio of about 690.
    The heaviest-weighted counties are the ones a within-county SD
    describes worst:

      -- Virginia independent cities with a mean harvest of one to five
         deer, where a single animal is most of an SD; and
      -- counties observed for only TWO years, whose "SD" is the gap
         between two numbers. 170 of the 1,577 estimation counties are
         observed fewer than three years, 237 fewer than five.

    This is new with decision 2: the old balanced window gave every
    county ten years and could not produce a two-observation SD. Section
    6g reports the coefficient under three restrictions (moments from 5+
    years, from 10+ years, and dropping the top 1% of counties by
    weight). On the current vintage Panel D is unmoved by all three;
    Panels A, B and C move around and their marginal stars come and go.

    [DECIDE] Whether this table should carry a minimum-years rule for the 
    moments, or a trimmed/winsorized weight, or neither with the caveat in the 
    notes. Nothing is imposed here -- the table as written uses every county. 
    One line in Section 2 sets a threshold if we want one.

==============================================================================*/

*==============================================================================
* SECTION 0: SETUP
*==============================================================================

clear all
set more off
set varabbrev off
version 16.1

capture log close

global root "/mnt/data_d/Dropbox/Research/AnimalCollisionsWeather"
global codeSTATA "$root/codeSTATA"
global dataSTATA "$root/dataSTATA"
global dataCLEAN "$root/dataCLEAN"
global tables    "$root/tables"

di "$root"
di "$dataSTATA"

cap mkdir "$codeSTATA/logs"
log using "$codeSTATA/logs/regression_harvest_zscore.log", replace text

cap mkdir "$tables"
cap mkdir "$tables/wildlife_weather"

* ---- fail early if a dependency is missing ---------------------------------
* reghdfe needs BOTH ftools and require -- require is a small dependency-
* checking utility reghdfe calls on startup, and nothing names it until
* reghdfe refuses to run, so it is easy to miss. estout supplies esttab,
* eststo and estadd. findfile on the individual ado-files: it names the exact
* file it could not locate, and on failure adopath below shows where Stata
* actually looked, to separate "not installed" from "installed into a directory
* this session does not search." All from SSC:
*     ssc install require, replace
*     ssc install ftools, replace
*     ssc install reghdfe, replace
*     ssc install estout, replace
*     mata: mata mlib index
local _pkgmissing 0
foreach ado in require.ado ftools.ado reghdfe.ado esttab.ado eststo.ado ///
               estadd.ado {
    capture findfile `ado'
    if _rc {
        display as error "  not on the ado-path: `ado'"
        local _pkgmissing 1
    }
}
if `_pkgmissing' {
    display as error ""
    display as error "  The files above are not visible to this Stata session."
    display as error "  If they are genuinely not installed, run the ssc install"
    display as error "  lines in the comment block above, in that order."
    display as error ""
    display as error "  If they ARE installed, the ado-path is the problem: the"
    display as error "  install went somewhere this session does not search (a"
    display as error "  different user's PLUS, or a profile.do not running here)."
    display as error "  The paths Stata is searching:"
    adopath
    exit 199
}
display as text "  require / ftools / reghdfe / estout all present"

* ---- fail early if the input panel is not where we expect -------------------
capture confirm file "$dataSTATA/main_data_county_year.dta"
if _rc {
    display as error "  not found: $dataSTATA/main_data_county_year.dta"
    display as error "  (if the merged panel lives elsewhere, fix the path here"
    display as error "   and in the SOURCE FILES block above)"
    exit 601
}
display as text "  input panel located"

*==============================================================================
* SECTION 1: LOAD, VERIFY KEY, BUILD IDS AND SAMPLE MACROS
*==============================================================================

/*------------------------------------------------------------------------

THE KEY IS UNIQUE BUT NOT COMPLETE, SO PLAIN isid REFUSES.

   17 rows carry a BLANK geoid -- also blank state_fips, county_fips and
   state_name -- with county_name "st louis", state_letter_code "MN", one row
   per year 2004 through 2020. They are collision-file records that never
   matched a FIPS: merge_collisions == 2 (using-only) against
   merge_wildlife == 1. Every non-missing value on them comes from the
   collision block; harvest, weather and population are all missing.

   They are St. Louis County, Minnesota (27137), whose crash record failed to
   match on "st louis" vs "St. Louis". That is a hole in the collision panel
   worth fixing upstream, but it touches nothing here.

------------------------------------------------------------------------*/

use "$dataSTATA/main_data_county_year.dta", clear

* -- the key is unique over all rows. isid objects only to the blanks,
*    so uniqueness is checked separately before they come out.
capture drop _dupkey
quietly duplicates tag geoid year, gen(_dupkey)
assert _dupkey == 0
drop _dupkey

* -- the orphans: named in the log, asserted empty, then dropped
quietly count if geoid == ""
local _norphan = r(N)
if `_norphan' > 0 {
    display as text "  rows with a blank geoid: `_norphan'  (collision-only orphans)"
    preserve
        keep if geoid == ""
        contract state_letter_code county_name
        list state_letter_code county_name _freq, sep(0) noobs
    restore

    assert missing(harvest_total)     if geoid == ""
    assert missing(mean_winter_temp)  if geoid == ""
    assert missing(population)        if geoid == ""

    drop if geoid == ""
}
if `_norphan' != 17 {
    display as error "  NOTE: expected 17 blank-geoid orphan rows; got `_norphan'." ///
        "  Something changed in the collision merge -- find out what before" ///
        "  using this table."
}

* -- now the key holds outright
isid geoid year

assert strlen(geoid) == 5
assert real(geoid) < .

egen county_id = group(geoid)
egen state_id  = group(state)
label variable county_id "Numeric county id from geoid -- working variable for reghdfe absorb()"
label variable state_id  "Numeric state id from state postal abbreviation -- working variable"

*--------------------------------- 1a. SAMPLE ---------------------------------

/*------------------------------------------------------------------------

See decisions 2 and 3. Two samples, both unbalanced:

  $SFULL     every county-year from 1981 on -- 19 states
  $SAGENCY   the same, restricted to agency-direct harvest -- 14 states

Nothing is dropped from memory: the restriction rides on the regressions
as an -if- so the QC in Section 6 can still see what was excluded.
main_sample and main_sample_agency are deliberately NOT used.

------------------------------------------------------------------------*/

capture drop agency_direct
generate byte agency_direct = (trim(source_harvest) == "agency")
label variable agency_direct "=1 if harvest came from an agency-direct harmonization, not the CWD panel"

global SFULL   "year >= 1981"
global SAGENCY "year >= 1981 & agency_direct == 1"

* agency-direct must be a strict subset of the full panel
quietly count if $SAGENCY & !($SFULL)
assert r(N) == 0

*==============================================================================
* SECTION 2: OUTCOME
*==============================================================================

/*------------------------------------------------------------------------

Decision 13: the within-county z-score of harvest, with the county's own
1981+ mean and SD as the moments, computed on every year the county
reports a harvest and broadcast to all of its rows.

The moments are built from harvest_total -- the source-reported total from
the national append -- NOT from harvest_total_cwd_imputed, which is parked
upstream and must stay out of any estimate.

Decision 1: the reported zeros are kept. A harvest of 0 has a perfectly
good z-score; it is only the counties with NO variation that drop.

------------------------------------------------------------------------*/

*--------------------------------- 2a. MOMENTS --------------------------------

* _hbase carries harvest_total only on the rows the moments are allowed to
* see. egen ignores missing, so the three statistics below are taken over
* exactly those rows and broadcast to every row of the county -- which is
* what makes the outcome one variable with one definition (decision 13).
capture drop _hbase
generate double _hbase = harvest_total if $SFULL & !missing(harvest_total)

capture drop h_mean_c h_sd_c h_nyr_c
bysort county_id: egen double h_mean_c = mean(_hbase)
bysort county_id: egen double h_sd_c   = sd(_hbase)
bysort county_id: egen long   h_nyr_c  = count(_hbase)
drop _hbase

label variable h_mean_c "County's own mean harvest, 1981+ reported years"
label variable h_sd_c   "County's own SD of harvest, 1981+ reported years"
label variable h_nyr_c  "Years of reported harvest the moments rest on"

* A minimum-years rule for the moments would go here -- one line, see
* decision 14. Nothing is imposed on the table as written:
*     replace h_sd_c = . if h_nyr_c < 5

*--------------------------------- 2b. THE OUTCOME ----------------------------

capture drop harvest_z
generate double harvest_z = (harvest_total - h_mean_c) / h_sd_c ///
    if $SFULL & !missing(harvest_total) & h_sd_c > 0 & !missing(h_sd_c)
label variable harvest_z "Deer harvest, z-scored within county on its own 1981+ years"

* In Stata a missing h_sd_c satisfies "h_sd_c > 0", so without it every 
* single-observation county would produce a missing z-score through a path that 
* reads like success.

* The z-score exists wherever the harvest and a usable SD do, and nowhere else.
assert !missing(harvest_z) if $SFULL & !missing(harvest_total) & ///
    h_sd_c > 0 & !missing(h_sd_c)
assert missing(harvest_z) if !($SFULL)
assert missing(harvest_z) if missing(harvest_total)

* Structural: by construction the outcome is mean 0, SD 1 WITHIN each county
* over the rows the moments were taken on. If that ever fails, the moments
* and the outcome have stopped describing the same set of rows.
capture drop _zm _zs
bysort county_id: egen double _zm = mean(harvest_z)
bysort county_id: egen double _zs = sd(harvest_z)
assert abs(_zm)     < 1e-6 if !missing(_zm)
assert abs(_zs - 1) < 1e-6 if !missing(_zs)
drop _zm _zs

*--------------------------------- 2c. WHO HAS NO SD --------------------------

* Decision 13. Counties with zero within-county variation have no z-score and
* leave the table. Named rather than counted: this is the one place this
* table's sample differs from Table 2's, and the reader should be able to see
* whose rows went.

capture drop _tg
quietly egen byte _tg = tag(county_id) if $SFULL & !missing(harvest_total)
quietly count if _tg == 1 & h_sd_c == 0
local _nflat = r(N)
display as text _newline "  counties with zero harvest variation (no z-score): `_nflat'"
if `_nflat' > 0 {
    list state geoid county_name h_nyr_c h_mean_c if _tg == 1 & h_sd_c == 0, ///
        sep(0) noobs
}
quietly count if _tg == 1 & h_nyr_c == 1
local _n1yr = r(N)
display as text "  counties with a single reported year (no SD): `_n1yr'"
drop _tg

* On the current vintage the only flat county is San Francisco (06075),
* zero harvest in all 29 years it reports, and there are no
* single-year counties.
if `_nflat' != 1 | `_n1yr' != 0 {
    display as error "  NOTE: expected exactly 1 zero-variance county and 0" ///
        " single-year counties; got `_nflat' and `_n1yr'. The sample identity" ///
        " asserted in Section 6b will move with this."
}

*--------------------------------- 2d. THE ZEROS ------------------------------

* Decision 1. Reported zeros are retained, as in Table 2. Counted and named by
* state because they are the only thing separating this table's sample from
* Table 1's, exactly as they are for Table 2.

quietly count if $SFULL & harvest_total == 0
local _nzero = r(N)
display as text _newline "  county-years with harvest_total == 0, RETAINED here" ///
    " (z-scored, not dropped), dropped by log() in Table 1: `_nzero'"
if `_nzero' > 0 {
    preserve
        keep if $SFULL & harvest_total == 0
        contract state
        list state _freq, sep(0) noobs
    restore
}
if `_nzero' != 103 {
    display as error "  NOTE: expected 103 reported zeros in 1981+; got `_nzero'."
}

* Of those, the ones that survive into the estimation sample. Fewer than
* Table 2 keeps, because San Francisco's zeros leave with San Francisco.
quietly count if $SFULL & harvest_total == 0 & ///
    !missing(harvest_z, mean_winter_temp, population, pop_share_5_9, mean_temp_c_m3)
* A GLOBAL, not a local: Section 6b checks the sample against it, and a
* local would not survive running the sections separately in the do-editor
* (same reasoning as the panel globals in Section 4).
global NZEROEST = r(N)
display as text "  of those, in the estimation sample: $NZEROEST" ///
    "  (this table's obs = Table 1's obs + $NZEROEST)"

global Y    "harvest_z"
global YLAB "within-county harvest z-score"

*==============================================================================
* SECTION 3: CONTROL SETS
*==============================================================================

/*------------------------------------------------------------------------

Two control globals, built by loop so the log records exactly what went
into the regression and a change to the month range is a one-line edit.
See decision 5 (weather) and decision 6 (age shares).

------------------------------------------------------------------------*/

*--------------------------------- 3a. ---------------------------------------

global pptmode "days"          // "days" | "total" | "both"
assert inlist("$pptmode", "days", "total", "both")

global wctrl ""
local _snowkeep ""
local _snowdrop ""
forvalues m = 3/11 {
    global wctrl "$wctrl mean_temp_c_m`m'"
    if inlist("$pptmode", "days", "both") {
        global wctrl "$wctrl days_precip_above_10mm_m`m'"
    }
    if inlist("$pptmode", "total", "both") {
        global wctrl "$wctrl ppt_total_m`m'"
    }
    * A snowfall month is included only if it actually varies on THIS sample.
    * On the old 2005-2014 window July and August were identically zero and
    * were excluded by name; on the full 1981+ panel they are not. Testing
    * rather than hard-coding means the control set follows the sample instead
    * of a fact that is no longer true.
    quietly summarize total_snowfall_mm_m`m' if $SFULL
    if r(N) > 0 & r(max) > 0 {
        global wctrl "$wctrl total_snowfall_mm_m`m'"
        local _snowkeep "`_snowkeep' m`m'"
    }
    else {
        local _snowdrop "`_snowdrop' m`m'"
    }
}

local _nsnow : word count `_snowkeep'
local _nppt = cond("$pptmode" == "both", 18, 9)
local _nwexp = 9 + `_nppt' + `_nsnow'

local _nw : word count $wctrl
display as text "  weather controls (Mar-Nov of year t, pptmode = $pptmode): `_nw'"
display as text "    snowfall months kept:   `_snowkeep'"
if "`_snowdrop'" != "" {
    display as text "    snowfall months dropped (no variation): `_snowdrop'"
}
assert `_nw' == `_nwexp'

*--------------------------------- 3b. ---------------------------------------

global agectrl ""
foreach a in 5_9 10_14 15_19 20_24 25_29 30_34 35_39 40_44 45_49 50_54 ///
             55_59 60_64 65_69 70_74 75_79 80_84 85plus {
    global agectrl "$agectrl pop_share_`a'"
}

local _na : word count $agectrl
display as text "  age-share controls (pop_share_0_4 omitted): `_na'"
assert `_na' == 17

capture drop _agesum
egen double _agesum = rowtotal(pop_share_0_4 $agectrl), missing
assert abs(_agesum - 1) < 1e-4 if !missing(_agesum)
drop _agesum

*==============================================================================
* SECTION 4: PANEL DEFINITIONS, TABLE SCAFFOLDING, HELPER PROGRAM
*==============================================================================

/*------------------------------------------------------------------------

GLOBALS, not locals: these are set here but consumed in Section 5, and locals
do not survive a separate execution. Running the file end to end and running
it section by section in the do-editor have to give the same answer.

Labels are the SHORT name only (decision 5). The definitions that used
to sit in parentheses after each name now are in the Overleaf notes.

------------------------------------------------------------------------*/

global pvarA "mean_winter_temp"
global pvarB "warm_winter_1sd"
global pvarC "wsi_cold_days"
global pvarD "winter_severity_index"

global plabA "Mean winter temp"
global plabB "Winter temp anomaly"
global plabC "Extreme cold days"
global plabD "Winter severity index"

foreach P in A B C D {
    capture confirm variable ${pvar`P'}
    if _rc {
        display as error "panel `P' regressor not found: ${pvar`P'}"
        exit 111
    }
}

* ---- the column-number row, built rather than hand-typed -------------------
* Panel A's prehead writes it once, above all four panels. Built by loop so
* the count follows NCOL and cannot drift out of step with the table.
global NCOL = 5
global numrow "            "
forvalues j = 1/$NCOL {
    global numrow "$numrow &\multicolumn{1}{c}{(`j')}"
}
global numrow "$numrow \\"

* Panel titles and the specification block span the stub column plus NCOL.
global NSPAN = $NCOL + 1

* ---- helper: the two scalars esttab cannot get from e() on its own ---------
* n_clust comes straight from e(N_clust); n_county has to be counted off
* e(sample). Called immediately after each reghdfe, before eststo stores the
* estimates, so the added scalars travel with them.
capture program drop addcounts
program define addcounts
    tempvar tag
    quietly egen `tag' = tag(county_id) if e(sample)
    quietly count if `tag' == 1
    estadd scalar n_county = r(N)
    estadd scalar n_clust  = e(N_clust)
end

*==============================================================================
* SECTION 5: ESTIMATION AND EXPORT
*==============================================================================

/*------------------------------------------------------------------------

20 regressions: 4 panels x 5 columns. The five columns are written out
explicitly rather than looped, because each carries a different set of
estadd locals (the control checkmarks the table prints).

LAYOUT (decision 7, and Eyal 09/11):

   Panel A's prehead writes the provenance comments, the column-number
   row and Panel A's own title. Panels B-D append their titles and rows.
   AFTER Panel D, a separate block writes the specification rows --
   sample, counties, observations, clusters, fixed effects, controls --
   at the BOTTOM of the table, once.

   That block reads its scalars off the estimates left in memory by
   run_panel D. Every one of those scalars is identical across panels
   (all four rest on the same estimation sample -- asserted in Section
   6), so which panel it comes from does not matter.

------------------------------------------------------------------------*/

capture program drop run_panel
program define run_panel
    args P

    local x  "${pvar`P'}"
    local xl "${plab`P'}"

    * Panel A also writes the table header, so it is the only panel whose
    * esttab call uses -replace- and prints the column numbers. The column-
    * number row is written by hand into Panel A's prehead ($numrow, built in
    * Section 4) and -nonumbers- is set on every panel, so the row appears
    * exactly once and cannot be duplicated by esttab's own numbering.
    if "`P'" == "A" {
        local mode "replace"
        local head `""% Table 3. Outcome = $YLAB." "% Generated by regression_harvest_zscore.do. SEs clustered on county." "% Stars: * p<0.10, ** p<0.05, *** p<0.01." "$numrow" "\midrule" "\multicolumn{$NSPAN}{l}{\textit{Panel `P': `xl'}} \\""'
    }
    else {
        local mode "append"
        local head `""\multicolumn{$NSPAN}{l}{\textit{Panel `P': `xl'}} \\""'
    }

    eststo clear
    display as text _newline "{hline 78}"
    display as text "PANEL `P': `x'"
    display as text "{hline 78}"

    *--- col 1: county FE + state x year FE, full panel -----------------------
    quietly reghdfe $Y `x' if $SFULL, ///
        absorb(county_id state_id#year) vce(cluster county_id)
    addcounts
    estadd local fe_county "X"
    estadd local fe_styr   "X"
    estadd local ctrl_w    ""
    estadd local ctrl_age  ""
    estadd local samp      "Full panel"
    eststo c1

    *--- col 2: + weather controls -------------------------------------------
    quietly reghdfe $Y `x' $wctrl if $SFULL, ///
        absorb(county_id state_id#year) vce(cluster county_id)
    addcounts
    estadd local fe_county "X"
    estadd local fe_styr   "X"
    estadd local ctrl_w    "X"
    estadd local ctrl_age  ""
    estadd local samp      "Full panel"
    eststo c2

    *--- col 3: + age shares -------------------------------------------------
    quietly reghdfe $Y `x' $agectrl if $SFULL, ///
        absorb(county_id state_id#year) vce(cluster county_id)
    addcounts
    estadd local fe_county "X"
    estadd local fe_styr   "X"
    estadd local ctrl_w    ""
    estadd local ctrl_age  "X"
    estadd local samp      "Full panel"
    eststo c3

    *--- col 4: + weather + age shares ---------------------------------------
    quietly reghdfe $Y `x' $wctrl $agectrl if $SFULL, ///
        absorb(county_id state_id#year) vce(cluster county_id)
    addcounts
    estadd local fe_county "X"
    estadd local fe_styr   "X"
    estadd local ctrl_w    "X"
    estadd local ctrl_age  "X"
    estadd local samp      "Full panel"
    eststo c4

    *--- col 5: same as col 4, agency-direct harvest only --------------------
    quietly reghdfe $Y `x' $wctrl $agectrl if $SAGENCY, ///
        absorb(county_id state_id#year) vce(cluster county_id)
    addcounts
    estadd local fe_county "X"
    estadd local fe_styr   "X"
    estadd local ctrl_w    "X"
    estadd local ctrl_age  "X"
    estadd local samp      "Agency-direct"
    eststo c5

    *--- this panel's coefficient rows ---------------------------------------
    * No counts here -- observations, counties and clusters print once in the
    * specification block at the bottom (decision 7).
    esttab c1 c2 c3 c4 c5 using "$tables/wildlife_weather/regression_harvest_zscore.tex", ///
        `mode' fragment booktabs nomtitles nonumbers noobs collabels(none) ///
        keep(`x') coeflabel(`x' "`xl'") ///
        cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
        stats(r2_within r2, fmt(%9.3f %9.3f) ///
              labels("Within R-squared" "R-squared (incl. FE)")) ///
        starlevels(* 0.10 ** 0.05 *** 0.01) ///
        prehead(`head') ///
        postfoot("\addlinespace")

    esttab c1 c2 c3 c4 c5 using "$tables/wildlife_weather/regression_harvest_zscore.csv", ///
        `mode' plain nomtitles noobs collabels(none) ///
        keep(`x') coeflabel(`x' "`x'") ///
        cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
        stats(r2_within r2, fmt(%9.3f %9.3f) ///
              labels("Within R-squared" "R-squared (incl. FE)")) ///
        starlevels(* 0.10 ** 0.05 *** 0.01) ///
        title("Panel `P': `x'")

    *--- and into the log, where it can be read without leaving Stata --------
    esttab c1 c2 c3 c4 c5, ///
        keep(`x') coeflabel(`x' "`xl'") ///
        cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
        stats(r2_within r2 n_clust n_county N, ///
              fmt(%9.3f %9.3f %9.0gc %9.0gc %9.0gc) ///
              labels("Within R-squared" "R-squared (incl. FE)" ///
                     "# of clusters" "# of counties" "# of obs")) ///
        starlevels(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("(1)" "(2)" "(3)" "(4)" "(5)") nonumbers collabels(none)
end

run_panel A
run_panel B
run_panel C
run_panel D

*--------------------------------- 5a. ---------------------------------------
* THE SPECIFICATION BLOCK, AT THE BOTTOM, ONCE.
*
* Reads the estimates left in memory by run_panel D. Every scalar below is
* identical across the four panels (Section 6 asserts it), so the panel it
* comes from is immaterial.
*
* This is also the last thing written to the fragment, so it has the
* "% end of fragment" line -- see decision 12.

esttab c1 c2 c3 c4 c5 using "$tables/wildlife_weather/regression_harvest_zscore.tex", ///
    append fragment booktabs cells(none) nomtitles nonumbers ///
    stats(samp n_county N n_clust fe_county fe_styr ctrl_w ctrl_age, ///
          fmt(%s %9.0gc %9.0gc %9.0gc %s %s %s %s) ///
          labels("Sample" "\# of counties" "\# of observations" ///
                 "\# of clusters" "County FE" "State x year FE" ///
                 "Weather controls" "Age shares")) ///
    prehead("\midrule") ///
    postfoot("% end of fragment")

esttab c1 c2 c3 c4 c5 using "$tables/wildlife_weather/regression_harvest_zscore.csv", ///
    append plain cells(none) nomtitles nonumbers ///
    stats(samp n_county N n_clust fe_county fe_styr ctrl_w ctrl_age, ///
          fmt(%s %9.0gc %9.0gc %9.0gc %s %s %s %s) ///
          labels("Sample" "# of counties" "# of observations" ///
                 "# of clusters" "County FE" "State x year FE" ///
                 "Weather controls" "Age shares")) ///
    title("Specification")

*==============================================================================
* SECTION 6: QC
*==============================================================================

/*------------------------------------------------------------------------

Four things this table shares with the other two:

  (a) the four panels rest on identical samples -- asserted, because if
      they ever diverge the panels stop being comparable down a column;
  (b) the estimation samples are the sizes this vintage should give --
      a NOTE, not an assert, since these depend on the panel vintage;
  (c) 1981 really does contribute nothing (decision 2);
  (d) how unbalanced the panel actually is, since that is now a feature
      of the design rather than something ruled out;

and three it does not:

  (b) also ties the sample to BOTH other tables -- Table 2's less the
      zero-variance counties, Table 1's plus the retained zeros;
  (f) the rescaling identity behind decision 14, asserted rather than
      asserted-in-a-comment: the z-score regression and the harvest/SD 
      regression are the same regression;
  (g) what the county weights look like, and whether the estimates
      survive restricting them.

------------------------------------------------------------------------*/

*--------------------------------- 6a. ---------------------------------------

display as text _newline "  estimation-sample size by winter measure (col 4 spec):"
local _prev = -1
foreach v in mean_winter_temp warm_winter_1sd wsi_cold_days winter_severity_index {
    quietly count if $SFULL & !missing($Y, `v', population, pop_share_5_9, mean_temp_c_m3)
    local _thisn = r(N)
    display as text "    " %-24s "`v'" %9.0fc `_thisn'
    if `_prev' != -1 {
        assert `_thisn' == `_prev'
    }
    local _prev = `_thisn'
}
display as text "  all four panels rest on the same estimation sample"

*--------------------------------- 6b. ---------------------------------------

quietly {
    count if $SFULL & !missing($Y, mean_winter_temp, population, pop_share_5_9, mean_temp_c_m3)
    local _nf = r(N)
    egen _tf = tag(geoid) if $SFULL & !missing($Y, mean_winter_temp, population, pop_share_5_9, mean_temp_c_m3)
    count if _tf == 1
    local _cf = r(N)
    drop _tf
    levelsof state if $SFULL & !missing($Y, mean_winter_temp), local(_sf) clean

    count if $SAGENCY & !missing($Y, mean_winter_temp, population, pop_share_5_9, mean_temp_c_m3)
    local _na2 = r(N)
    egen _ta = tag(geoid) if $SAGENCY & !missing($Y, mean_winter_temp, population, pop_share_5_9, mean_temp_c_m3)
    count if _ta == 1
    local _ca = r(N)
    drop _ta
    levelsof state if $SAGENCY & !missing($Y, mean_winter_temp), local(_sa) clean

    summarize year if $SFULL & !missing($Y, mean_winter_temp), meanonly
    local _y0 = r(min)
    local _y1 = r(max)
}
local _nsf : word count `_sf'
local _nsa : word count `_sa'

display as text _newline "  cols 1-4: `_nf' obs | `_cf' counties | `_nsf' states | `_y0'-`_y1'"
display as text "    states: `_sf'"
display as text "  col 5:    `_na2' obs | `_ca' counties | `_nsa' states"
display as text "    states: `_sa'"

* Expected on the current vintage: 30,342 / 1,577 / 19 and 26,867 / 1,082 / 14.
if `_nf' != 30342 | `_cf' != 1577 {
    display as error "  NOTE: expected 30,342 obs / 1,577 counties in cols 1-4;" ///
        " got `_nf' / `_cf'. Check the merged-panel vintage before using this table."
}
if `_na2' != 26867 | `_ca' != 1082 {
    display as error "  NOTE: expected 26,867 obs / 1,082 counties in col 5;" ///
        " got `_na2' / `_ca'. Check the merged-panel vintage before using this table."
}

* --- tie to Table 2: this sample is Table 2's less the counties with no SD.
quietly count if $SFULL & !missing(mean_winter_temp, population, pop_share_5_9, mean_temp_c_m3) ///
    & !missing(harvest_total, population)
local _nrate = r(N)
quietly count if $SFULL & !missing(mean_winter_temp, population, pop_share_5_9, mean_temp_c_m3) ///
    & !missing(harvest_total, population) & missing($Y)
local _nnosd = r(N)
display as text _newline "  Table 2's sample: `_nrate' obs; of those, `_nnosd' have no z-score" ///
    " (zero-variance counties)"
assert `_nf' == `_nrate' - `_nnosd'
if `_nrate' != 30370 {
    display as error "  NOTE: expected 30,370 obs in Table 2's sample; got `_nrate'." ///
        " The two tables have diverged for some reason other than the missing SDs."
}

* --- tie to Table 1: this sample is Table 1's plus the retained zeros.
quietly count if $SFULL & harvest_total > 0 & ///
    !missing($Y, mean_winter_temp, population, pop_share_5_9, mean_temp_c_m3)
local _nnozero = r(N)
display as text "  excluding the retained zeros: `_nnozero' obs" ///
    "  (Table 1's sample -- log(harvest) drops exactly these zeros)"
assert `_nf' == `_nnozero' + $NZEROEST
if `_nnozero' != 30272 {
    display as error "  NOTE: expected 30,272 obs once the zeros come out, to match" ///
        " regression_log_harvest.do; got `_nnozero'. The tables have diverged" ///
        " for some reason other than the zeros and the missing SDs."
}

*--------------------------------- 6c. ---------------------------------------

* 1981 contributes nothing because mean_winter_temp needs December of 1980 and
* the PRISM extraction starts in 1981.
quietly count if year == 1981 & !missing(harvest_total)
local _h81 = r(N)
quietly count if year == 1981 & !missing(mean_winter_temp)
local _w81 = r(N)
display as text _newline "  1981: `_h81' county-years with harvest, `_w81' with a winter measure"
if `_w81' == 0 {
    display as text "    -> 1981 drops from every column (winter needs Dec 1980; PRISM starts 1981)"
}

*--------------------------------- 6d. ---------------------------------------

* How unbalanced is the panel? Reported -- imbalance is accepted
* at this stage. 
preserve
    keep if $SFULL & !missing($Y, mean_winter_temp)
    quietly bysort geoid: generate int _nyr = _N
    quietly egen byte _tg = tag(geoid)
    display as text _newline "  years observed per county (estimation sample):"
    summarize _nyr if _tg == 1, detail
restore

preserve
    keep if $SFULL & !missing($Y, mean_winter_temp)
    contract year
    display as text _newline "  counties per year (estimation sample):"
    list year _freq, sep(0) noobs
restore

*--------------------------------- 6e. ---------------------------------------

codebook $Y if $SFULL, compact
summarize $Y mean_winter_temp warm_winter_1sd wsi_cold_days ///
    winter_severity_index if $SFULL

*--------------------------------- 6f. ---------------------------------------

/* Decision 14, asserted rather than asserted in a comment. Under county
   fixed effects h_mean_c/h_sd_c is a county constant and is absorbed, so
   regressing the z-score is the same regression as regressing
   harvest/SD. Both are run on the col-4 spec and the coefficients have to
   agree to numerical precision. If this ever fails, the moments are NOT
   county-constant -- which would mean something has gone wrong in Section
   2a -- and the interpretation of the whole table changes.             */

capture drop harvest_over_sd
generate double harvest_over_sd = harvest_total / h_sd_c if !missing($Y)
label variable harvest_over_sd "Harvest divided by the county's own SD -- QC twin of harvest_z"

quietly reghdfe $Y $pvarD $wctrl $agectrl if $SFULL, ///
    absorb(county_id state_id#year) vce(cluster county_id)
local _bz = _b[$pvarD]
local _sez = _se[$pvarD]

quietly reghdfe harvest_over_sd $pvarD $wctrl $agectrl if $SFULL, ///
    absorb(county_id state_id#year) vce(cluster county_id)
local _bs = _b[$pvarD]
local _ses = _se[$pvarD]

display as text _newline "  rescaling identity (Panel D, col 4 spec):"
display as text "    z-score        b = " %12.8f `_bz' "   se = " %12.8f `_sez'
display as text "    harvest / SD   b = " %12.8f `_bs' "   se = " %12.8f `_ses'
assert reldif(`_bz', `_bs')   < 1e-7
assert reldif(`_sez', `_ses') < 1e-7
display as text "    identical -- this table is Table 2 reweighted by 1/SD, not new evidence"

drop harvest_over_sd

*--------------------------------- 6g. ---------------------------------------

/* What the 1/SD weights actually look like, and whether the estimates
   survive restricting them. Decision 14: reported every run, nothing
   imposed. The weights are the reason this table is not simply a units
   change.                                                               */

preserve
    keep if $SFULL & !missing($Y, mean_winter_temp, population, pop_share_5_9, mean_temp_c_m3)
    quietly egen byte _tg = tag(geoid)

    display as text _newline "  county SD of harvest, h_sd_c (estimation sample):"
    summarize h_sd_c if _tg == 1, detail

    capture drop _w
    generate double _w = 1 / h_sd_c
    quietly summarize _w if _tg == 1, detail
    local _p1  = r(p1)
    local _p99 = r(p99)
    display as text "  implied county weight 1/h_sd_c: p1 = " %9.5f `_p1' ///
        "  p99 = " %9.5f `_p99' "  ratio = " %6.0f (`_p99'/`_p1')

    foreach k in 3 5 10 {
        quietly count if _tg == 1 & h_nyr_c < `k'
        local _ck = r(N)
        quietly count if h_nyr_c < `k'
        local _rk = r(N)
        display as text "  counties whose moments rest on < `k' years: `_ck'" ///
            "  (`_rk' rows)"
    }

    * one row per county from here on, so -in 1/10- means ten counties
    quietly keep if _tg == 1
    display as text _newline "  the ten heaviest-weighted counties (smallest SD):"
    gsort h_sd_c
    list state county_name h_nyr_c h_mean_c h_sd_c in 1/10, sep(0) noobs
restore

* Sensitivity, Panel D and Panel A, col 4 spec. Displayed, never asserted:
* these are the numbers the [DECIDE] in 14 needs, not a pass/fail.
display as text _newline "  sensitivity of the col-4 estimate to the weighting:"
foreach P in A D {
    display as text "    Panel `P' (${pvar`P'}):"
    quietly reghdfe $Y ${pvar`P'} $wctrl $agectrl if $SFULL, ///
        absorb(county_id state_id#year) vce(cluster county_id)
    display as text "      as built           b = " %9.4f _b[${pvar`P'}] ///
        "  se = " %9.4f _se[${pvar`P'}] "  N = " %9.0fc e(N)
    foreach k in 5 10 {
        quietly reghdfe $Y ${pvar`P'} $wctrl $agectrl if $SFULL & h_nyr_c >= `k', ///
            absorb(county_id state_id#year) vce(cluster county_id)
        display as text "      moments from `k'+ yrs  b = " %9.4f _b[${pvar`P'}] ///
            "  se = " %9.4f _se[${pvar`P'}] "  N = " %9.0fc e(N)
    }
}

* And the nesting check decision 10 refers to: the two WSI components entered
* jointly, which neither Panel C nor Panel D does.
display as text _newline "  Panels C and D components entered jointly (col 4 spec):"
quietly reghdfe $Y wsi_cold_days wsi_snow_days $wctrl $agectrl if $SFULL, ///
    absorb(county_id state_id#year) vce(cluster county_id)
display as text "    wsi_cold_days  b = " %9.4f _b[wsi_cold_days] ///
    "  se = " %9.4f _se[wsi_cold_days]
display as text "    wsi_snow_days  b = " %9.4f _b[wsi_snow_days] ///
    "  se = " %9.4f _se[wsi_snow_days]

display as text _newline "  Table written to:"
display as text "    $tables/wildlife_weather/regression_harvest_zscore.tex"
display as text "    $tables/wildlife_weather/regression_harvest_zscore.csv"

log close

/*============================================================================*/
