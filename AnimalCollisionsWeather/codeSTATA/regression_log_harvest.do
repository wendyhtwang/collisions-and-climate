/*==============================================================================

FILE NAME:   regression_log_harvest.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Preliminary Weather -> Deer Harvest Regressions

CURRENT LEAD: Nicole Martinez

PURPOSE:  Regression table: the effect of winter conditions on county deer
          harvest, outcome = log(harvest_total), estimated on the FULL
          unbalanced panel rather than the 2005-2014 balanced window.

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

          Definitions of the four winter measures and of the weather
          control set are NOT printed under the coefficient names -- they
          belong in the table notes in the Overleaf wrapper. The panel
          title carries the short name only.

          The specification block (sample, counts, FE, controls) prints at
          the BOTTOM of the table, after Panel D, per academic convention.
          Counts of observations, counties and clusters appear ONCE, in
          that block, not repeated inside each panel.

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
  $tables/wildlife_weather/regression_log_harvest.tex   LaTeX fragment
  $tables/wildlife_weather/regression_log_harvest.csv   plain mirror
  
CHANGELOG:

09/08/2026 — Nicole: First pass. Outcome log(harvest_total + 1), balanced
                     2005-2014 sample, 4 panels x 6 columns.

09/09/2026 — Nicole: Review & bug fixes.

09/10/2026 — Nicole: Review & bug fixes.

09/11/2026 — Nicole: Rewritten after meeting with Eyal. Outcome is now
                     log(harvest_total) with no +1 (1); sample is the full
                     unbalanced panel from 1981 (2); column 5 keyed on
                     source_harvest rather than main_sample_agency (3);
                     old county+year column removed (4); weather control
                     row renamed and variable definitions moved out of the
                     stub labels into the table notes (5);
                     specification block moved to the bottom and counts
                     reported once (7); R-squared behaviour and the
                     anomaly threshold verified (8, 9).

==============================================================================
DECISIONS TAKEN IN THIS SCRIPT
==============================================================================

1. THE OUTCOME IS log(harvest_total). NO +1.

   Per Eyal (09/11/2026): adding 1 inside the log to retain zeros is no
   longer an acceptable transformation. log() is taken on harvest_total
   directly, so county-years with a reported harvest of exactly 0 drop
   out of every column. There are 103 of them in 1981+, spread across
   CA (31), VA (29), WI (20), KY (14), NC (5) and FL (4). They are
   reported zeros in low-deer counties, retained as reported by the
   national append ([DECIDE] 6 there), so this is a deliberate loss of
   real observations, not a cleaning step. Section 2 counts and reports
   them rather than dropping them silently.

   [DEFERRED] Eyal raised a count model (Poisson / ppmlhdfe) as the
   proper way to handle the zeros later. Not attempted here.

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
   so the gap is visible.

3. [DECIDE] COLUMN 5 USES source_harvest, NOT main_sample_agency.

   main_sample_agency is defined upstream as "balanced 2005-2014 AND
   agency-direct". Using it here would silently re-impose the balanced
   window that [DECIDE] 2 removes, making column 5 a different sample in
   two ways at once rather than one. The agency-direct restriction is
   therefore applied through source_harvest == "agency", which is the
   same provenance test without the balance requirement.

   That gives 14 agency-direct states against 19 in the full panel. The
   five dropped are the CWD gap-fill states (FL, GA, IA, MI, MN) --
   see deer_harvest_national_append.do [DECIDE] 8.

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
   than 27. That is NOT true of the full 1981+ panel: July snowfall
   reaches 7.4mm and August 0.18mm in high-elevation county-years the
   narrow window never contained. Section 3 therefore tests each
   snowfall month for variation on the sample actually being estimated
   and includes it if it varies, reporting any it drops. On the current
   vintage all nine are kept, so the control set is 27.

   The row is labelled simply "Weather controls" per Eyal; the month
   range and contents are in the table notes.

6. AGE SHARES: 17 OF 18, pop_share_0_4 OMITTED.

   The 18 shares sum to 1 by construction, so one has to go. Dropping
   pop_share_0_4 by hand means the omitted category is identical in
   every column and does not move if the panel is rebuilt.

7. SEs CLUSTERED ON COUNTY THROUGHOUT.

   The cluster count prints once, in the specification block at the
   bottom, not inside each panel.

8. THE TWO R-SQUARED ROWS MEASURE DIFFERENT THINGS, AND BOTH STAY.

   Checked at Eyal's request (09/11/2026): e(r2_within) IS specific to
   the panel's own regressor and does vary across panels. In column 1,
   where the winter measure is the only regressor, it reads roughly
   0.000 / 0.000 / 0.000 / 0.001 for panels A/B/C/D -- small, but
   genuinely different, and D is the largest. e(r2) is near-identical
   everywhere because county and state x year fixed effects absorb
   about 94% of log harvest; that is the expected behavior Eyal
   described in the meeting. Both are reported so the contrast is visible.

9. THE WINTER ANOMALY IS "1 SD OR MORE", AS INTENDED.

   Checked at Eyal's request (09/11/2026): warm_winter_1sd is built
   upstream as strictly greater than the county's own mean + 1 SD, but
   there are ZERO exact ties in 136,752 non-missing rows, so ">" and
   ">=" select exactly the same county-years. The variable already means
   "1 SD or more"; no change was made. Its moments are the county's own
   full-panel mean and SD, which now line up with the estimation window
   far better than they did against the old 2005-2014 sample.

10. PANELS C AND D ARE NESTED, DELIBERATELY.

    winter_severity_index = wsi_cold_days + wsi_snow_days, so Panel C's
    regressor is a component of Panel D's. They are reported as separate
    panels, never entered jointly, so the nesting is a reading caveat
    rather than a collinearity problem. Panel D moving relative to Panel
    C is the snow component doing work.

11. [DECIDE] WINTER DATING

    All four measures are the winter IMMEDIATELY PRECEDING the fall-t
    hunting season, so no lag is applied. Raynor's DVC chapter
    instruments with winter severity one year further back, on the
    theory that the channel is fawn recruitment rather than same-season
    condition. If that is the intended timing every panel needs an L1.
    and the whole table shifts. Can be a one-line change in Section 4.

12. THE FRAGMENT MUST END ON A COMMENT LINE.

    The last thing written to the .tex is "% end of fragment". A
    fragment ending in \addlinespace scans past the end of file for an
    optional argument and swallows the wrapper's \bottomrule; a fragment
    ending in a blank line emits a \par inside the tabular. Both produce
    "Misplaced \noalign". A comment line ends cleanly.

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
log using "$codeSTATA/logs/regression_log_harvest.log", replace text

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

See [DECIDE] 2 and 3. Two samples, both unbalanced:

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

[DECIDE] 1: log(harvest_total), no +1. Zeros drop out.

The log is taken on harvest_total -- the source-reported total from the
national append -- NOT on harvest_total_cwd_imputed, which is parked
upstream and must stay out of any estimate.

------------------------------------------------------------------------*/

capture drop ln_harvest
generate double ln_harvest = ln(harvest_total) if harvest_total > 0 & !missing(harvest_total)
label variable ln_harvest "log(total deer harvest)"

* Handles the zeros. Counted and named rather than dropped silently:
* they are reported zeros, not missing data.
quietly count if $SFULL & harvest_total == 0
local _nzero = r(N)
display as text _newline "  county-years with harvest_total == 0, dropped by log(): `_nzero'"
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

assert missing(ln_harvest) if harvest_total == 0
assert !missing(ln_harvest) if !missing(harvest_total) & harvest_total > 0

global Y    "ln_harvest"
global YLAB "log(harvest)"

*==============================================================================
* SECTION 3: CONTROL SETS
*==============================================================================

/*------------------------------------------------------------------------

Two control globals, built by loop so the log records exactly what went
into the regression and a change to the month range is a one-line edit.
See [DECIDE] 5 (weather) and [DECIDE] 6 (age shares).

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
    * were excluded by name; on the full 1981+ panel they are not (July reaches
    * 7.4mm, August 0.18mm, in high-elevation county-years the narrow window
    * never contained). Testing rather than hard-coding means the control set
    * follows the sample instead of a fact that is no longer true.
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

Labels are the SHORT name only ([DECIDE] 5). The definitions that used
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

LAYOUT ([DECIDE] 7, and Eyal 09/11):

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
        local head `""% Table 1. Outcome = $YLAB." "% Generated by regression_log_harvest.do. SEs clustered on county." "% Stars: * p<0.10, ** p<0.05, *** p<0.01." "$numrow" "\midrule" "\multicolumn{$NSPAN}{l}{\textit{Panel `P': `xl'}} \\""'
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
    * specification block at the bottom ([DECIDE] 7).
    esttab c1 c2 c3 c4 c5 using "$tables/wildlife_weather/regression_log_harvest.tex", ///
        `mode' fragment booktabs nomtitles nonumbers noobs collabels(none) ///
        keep(`x') coeflabel(`x' "`xl'") ///
        cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
        stats(r2_within r2, fmt(%9.3f %9.3f) ///
              labels("Within R-squared" "R-squared (incl. FE)")) ///
        starlevels(* 0.10 ** 0.05 *** 0.01) ///
        prehead(`head') ///
        postfoot("\addlinespace")

    esttab c1 c2 c3 c4 c5 using "$tables/wildlife_weather/regression_log_harvest.csv", ///
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
* "% end of fragment" line -- see [DECIDE] 12.

esttab c1 c2 c3 c4 c5 using "$tables/wildlife_weather/regression_log_harvest.tex", ///
    append fragment booktabs cells(none) nomtitles nonumbers ///
    stats(samp n_county N n_clust fe_county fe_styr ctrl_w ctrl_age, ///
          fmt(%s %9.0gc %9.0gc %9.0gc %s %s %s %s) ///
          labels("Sample" "\# of counties" "\# of observations" ///
                 "\# of clusters" "County FE" "State x year FE" ///
                 "Weather controls" "Age shares")) ///
    prehead("\midrule") ///
    postfoot("% end of fragment")

esttab c1 c2 c3 c4 c5 using "$tables/wildlife_weather/regression_log_harvest.csv", ///
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

Four things to check:

  (a) the four panels rest on identical samples -- asserted, because if
      they ever diverge the panels stop being comparable down a column;
  (b) the estimation samples are the sizes this vintage should give --
      a NOTE, not an assert, since these depend on the panel vintage;
  (c) 1981 really does contribute nothing ([DECIDE] 2);
  (d) how unbalanced the panel actually is, since that is now a feature
      of the design rather than something ruled out.

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

* Expected on the current vintage: 30,272 / 1,577 / 19 and 26,801 / 1,082 / 14.
if `_nf' != 30272 | `_cf' != 1577 {
    display as error "  NOTE: expected 30,272 obs / 1,577 counties in cols 1-4;" ///
        " got `_nf' / `_cf'. Check the merged-panel vintage before using this table."
}
if `_na2' != 26801 | `_ca' != 1082 {
    display as error "  NOTE: expected 26,801 obs / 1,082 counties in col 5;" ///
        " got `_na2' / `_ca'. Check the merged-panel vintage before using this table."
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

display as text _newline "  Table written to:"
display as text "    $tables/wildlife_weather/regression_log_harvest.tex"
display as text "    $tables/wildlife_weather/regression_log_harvest.csv"

log close

/*============================================================================*/
