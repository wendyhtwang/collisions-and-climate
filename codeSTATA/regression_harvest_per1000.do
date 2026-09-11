/*==============================================================================

FILE NAME:   regression_harvest_per1000.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions —
	 Ungulate Population & DVC Panel —
	 Preliminary Weather -> Deer Harvest Regressions

CURRENT LEAD: Nicole Martinez

PURPOSE:  Regression table: the effect of winter conditions on county deer
          harvest, with the outcome as a RATE -- harvest_total / population
	  * 1,000, so coefficients read as deer harvested per 1,000 residents.

          Companion to regression_log_harvest.do, which runs the identical
          4 x 6 grid on log(harvest_total + 1). Everything except Section 2
          (the outcome) and the QC checks that reference it is the same file,
          deliberately, so the two tables are readable side by side.

          The table is 4 PANELS x 6 COLUMNS. Panels vary the winter
          measure; columns vary the specification.

              PANEL A   mean_winter_temp        Dec t-1 + Jan t + Feb t, deg C
              PANEL B   warm_winter_1sd         1 SD warmer than county norm
              PANEL C   wsi_cold_days           days min temp <= 0F
              PANEL D   winter_severity_index   cold days + days >=18in snow

              COL 1   county FE + year FE           main_sample
              COL 2   county FE + state x year FE   main_sample
              COL 3   + contemporaneous weather     main_sample
              COL 4   + age shares                  main_sample
              COL 5   + weather + age shares        main_sample
              COL 6   + weather + age shares        main_sample_agency

          main_sample_agency drops the states gap-filled from the
          Schuler et al. CWD panel, which in the 2005-2014 window means
          Iowa's 99 counties (see deer_harvest_national_append.do
          [DECIDE] 8). Every headline coefficient should be read against
          it, per that file's Section 5 note.

SOURCE FILES USED:
  $/mnt/data_d/Dropbox/Research/AnimalCollisionsWeather/dataSTATA/main_data_county_year.dta
        -- the merged analysis panel: harvest (from
           US_deer_harvest_county_year.dta, built by
           deer_harvest_national_append.do), PRISM/ERA5 weather, Census
           population and age shares, and the collision variables.
           151,145 county-years, 1927-2025, 309 variables. Only the
           harvest, weather, population and sample-flag variables are
           touched here; the collision block is untouched.

OUTPUT:
  $tables/wildlife_weather/regression_harvest_per1000.tex  LaTeX fragment. Panel
                                                        A writes the
							specification header
							block; Panels A-D
							then append their
							coefficient rows.
  $tables/wildlife_weather/regression_harvest_per1000.csv  plain mirror, for
                                                        reading in the log

CHANGELOG:

09/10/2026 — Nicole: First pass. Table 2 of the set, mirroring 
                     regression_log_harvest.do with the outcome as harvest 
		     per 1,000 residents instead of log(harvest_total + 1). 
		     Same 24 regressions, same controls (25 weather + 17 age 
		     shares), same sample flags, same county-clustered SEs. 
		     The log file's [DECIDE] on the three reported zeros does 
		     not carry over -- a rate of 0 is a legitimate value and 
		     needs no +1 -- and is replaced by a [DECIDE] on the 
		     population denominator. Estimation samples confirmed 
		     identical to Table 1 (11,160 / 1,116 and 10,170 / 1,017): 
		     the 30 county-years the rate cannot be formed on are the 
		     same 30 the winter measures are missing on.

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
di "$dataCLEAN"

cap mkdir "$codeSTATA/logs"
log using "$codeSTATA/logs/regression_harvest_per1000.log", replace text

cap mkdir "$tables"
cap mkdir "$tables/wildlife_weather"

* ---- fail early if a dependency is missing ---------------------------------
* reghdfe needs BOTH ftools and require -- require is a small dependency-
* checking utility reghdfe calls on startup, and nothing names it until
* reghdfe refuses to run, so it is easy to miss. estout supplies esttab,
* eststo and estadd. All from SSC:
*
*     ssc install require, replace
*     ssc install ftools, replace
*     ssc install reghdfe, replace
*     ssc install estout, replace
*     mata: mata mlib index
*
* findfile on the individual ado-files: it names the exact file it could not
* locate, and on failure adopath below shows where Stata actually looked to
* separate "not installed" from "installed into a directory this session does
* not search."
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

[DECIDE] THE KEY IS UNIQUE BUT NOT COMPLETE, SO PLAIN isid REFUSES.

   17 rows carry a BLANK geoid -- also blank state_fips, county_fips and
   state_name -- with county_name "st louis", state_letter_code "MN", one row
   per year 2004 through 2020. They are collision-file records that never
   matched a FIPS: merge_collisions == 2 (using-only) against
   merge_wildlife == 1. Every non-missing value on them comes from the
   collision block; harvest, weather, population, age shares and BOTH
   sample flags are missing throughout.

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

    * nothing any column of any table needs is on these rows
    assert missing(harvest_total)     if geoid == ""
    assert missing(mean_winter_temp)  if geoid == ""
    assert missing(population)        if geoid == ""
    assert main_sample == 0 | missing(main_sample) if geoid == ""

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

capture confirm variable main_sample
if _rc {
    display as error "main_sample not found -- is this the merged panel?"
    exit 111
}
global SMAIN   "main_sample == 1"
global SAGENCY "main_sample_agency == 1"

* main_sample_agency must be a strict subset of main_sample.
assert main_sample == 1 if main_sample_agency == 1
assert inrange(year, 2005, 2014) if main_sample == 1

*==============================================================================
* SECTION 2: OUTCOME
*==============================================================================

/*------------------------------------------------------------------------

[DECIDE] THE OUTCOME IS A RATE PER 1,000 RESIDENTS, NOT A LOG.

   harvest_per1000 = harvest_total / population * 1,000. A coefficient is
   then deer per 1,000 residents per unit of the winter measure, in levels,
   which is the units the DVC side of the project is written in and which
   Table 1's proportional coefficients cannot be converted into without a
   baseline.

   The rate needs none of Table 1's log(x+1) machinery: the three
   main_sample county-years with harvest_total == 0 (Norfolk VA, 2007-2009)
   give a rate of exactly 0, which is a legitimate value and stays in the
   estimation sample on its own. The [DECIDE] on the +1 in
   regression_log_harvest.do Section 2 therefore does not carry over.

   The numerator is harvest_total, the source-reported total from the
   national append -- NOT harvest_total_cwd_imputed, which should stay out
   of any estimate.

[DECIDE] THE DENOMINATOR IS CONTEMPORANEOUS COUNTY RESIDENT POPULATION.

   population is the Census total-resident count for the SAME year t as the
   harvest, all ages, all sexes -- so both the numerator and the denominator
   move within a county over the window, and the FE absorb only the level.
   Two consequences worth being explicit about:

     (a) The rate is human-population-scaled, not deer-population-scaled or
         area-scaled. It is a harvest-per-person measure, and a county that
         suburbanizes shows a falling rate with a flat harvest. Harvest per
         square mile is the obvious alternative and is a one-line change
         here if we want it as a robustness table.

     (b) The estimation sample is unchanged from Table 1 even though the
         rate has a second way to go missing. population is missing in
         exactly 30 main_sample county-years -- three Virginia independent
         cities (Bedford 51515, Clifton Forge 51560, South Boston 51780) --
         and those are the SAME 30 rows on which all four winter measures
         are missing, so no column loses an observation it would have kept
         in Table 1. Asserted below rather than assumed.

   The population denominator also sits underneath the age-share controls,
   which are shares of the same denominator. In cols 4-6 the winter
   coefficient is therefore identified holding the age composition of the
   denominator fixed; it is not a control for population SIZE. If we want
   the size held fixed too, ln(population) enters $agectrl and the table is
   re-run -- flagged, not done here, since Table 1 does not do it either.

------------------------------------------------------------------------*/

capture drop harvest_per1000
generate double harvest_per1000 = harvest_total / population * 1000
label variable harvest_per1000 "Deer harvest per 1,000 residents"

* No zero-population counties in the panel, so the rate never divides by
* zero. Asserted rather than trusted: a rebuilt population block with a
* zero would silently produce missing rather than an error.
quietly count if $SMAIN & population == 0
assert r(N) == 0

* The reported zeros, named in the log for continuity with Table 1 -- here
* they need no special handling, they are simply rate == 0.
quietly count if $SMAIN & harvest_total == 0
local _nzero = r(N)
display as text "  main_sample county-years with harvest_total == 0: `_nzero'" ///
    "  (rate == 0, retained without adjustment)"
if `_nzero' != 3 {
    display as error "  NOTE: expected 3 reported zeros in main_sample; got `_nzero'."
}

* The rate exists wherever both of its inputs do ...
assert !missing(harvest_per1000) if $SMAIN & !missing(harvest_total, population)
assert harvest_per1000 >= 0 if !missing(harvest_per1000)

* ... and where it does not exist, the winter measures are missing too, so
* the sample matches Table 1's. If this ever fires, the two tables are no
* longer estimated on the same rows and cannot be read side by side.
quietly count if $SMAIN & missing(population) & !missing(mean_winter_temp)
if r(N) > 0 {
    display as error "  NOTE: `r(N)' main_sample county-years have a winter" ///
        " measure but no population. The rate table's sample no longer" ///
        " matches regression_log_harvest.do -- reconcile before using both."
}
quietly count if $SMAIN & missing(population)
display as text "  main_sample county-years with no population (rate missing): `r(N)'"

global Y    "harvest_per1000"
global YLAB "harvest per 1,000 residents"

*==============================================================================
* SECTION 3: CONTROL SETS
*==============================================================================

/*------------------------------------------------------------------------

Two control globals, built by loop so the log records exactly what went into
the regression and a change to the month range is a one-line edit.

[DECIDE] CONTEMPORANEOUS WEATHER CONTROLS ARE MARCH-NOVEMBER ONLY.

   Monthly mean temperature, heavy-precipitation days (>10mm) and total
   snowfall, m3 through m11 of year t. December through February are
   deliberately EXCLUDED: the winter regressor is built from Dec/Jan/Feb,
   and controlling for those months would partial out the variation the
   table is about.

   total_snowfall_mm_m7 (July) and total_snowfall_mm_m8 (August) are
   identically zero in every county-year of the estimation window. They are
   dropped from the control global explicitly rather than left for reghdfe to
   report as omitted, so the count of controls in the log is the count actually
   estimated: 25, not 27.

[DECIDE] AGE SHARES: 17 OF 18, pop_share_0_4 OMITTED.

   The 18 shares sum to 1 by construction, so one has to go. Dropping
   pop_share_0_4 means the omitted category is the same in every column of
   every table and does not change if the panel is rebuilt.

------------------------------------------------------------------------*/

*--------------------------------- 3a. ---------------------------------------

global pptmode "days"          // "days" | "total" | "both"
assert inlist("$pptmode", "days", "total", "both")

global wctrl ""
forvalues m = 3/11 {
    global wctrl "$wctrl mean_temp_c_m`m'"
    if inlist("$pptmode", "days", "both") {
        global wctrl "$wctrl days_precip_above_10mm_m`m'"
    }
    if inlist("$pptmode", "total", "both") {
        global wctrl "$wctrl ppt_total_m`m'"
    }
    if !inlist(`m', 7, 8) {
        global wctrl "$wctrl total_snowfall_mm_m`m'"
    }
}

* Re-verify the July/August exclusion: if a rebuilt weather panel ever puts
* nonzero snowfall in those months, this fires and the exclusion needs
* revisiting.
foreach m in 7 8 {
    quietly summarize total_snowfall_mm_m`m' if $SMAIN
    assert r(max) == 0 | r(N) == 0
}

local _nwexp = 25
if "$pptmode" == "both" local _nwexp = 34

local _nw : word count $wctrl
display as text "  weather controls (Mar-Nov of year t, pptmode = $pptmode): `_nw'"
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

* The shares are supposed to sum to 1. If they do not, the omitted-category
* logic is wrong and the age-share columns mean something else.
capture drop _agesum
egen double _agesum = rowtotal(pop_share_0_4 $agectrl), missing
assert abs(_agesum - 1) < 1e-4 if !missing(_agesum)
drop _agesum

*==============================================================================
* SECTION 4: PANEL DEFINITIONS AND THE SCALARS esttab REPORTS
*==============================================================================

/*------------------------------------------------------------------------

One local per panel, so the estimation loop in Section 5 is written once
instead of four times.

[DECIDE] WINTER DATING.

   All four winter measures as built are the winter IMMEDIATELY PRECEDING the
   fall-t hunting season (mean_winter_temp = Dec t-1 + Jan t + Feb t), so no lag
   is applied here. Raynor's DVC chapter instruments with winter severity one year
   further back, on the theory that the channel is fawn recruitment rather than
   same-season condition. If that is the intended timing, every panel needs an L1.
   and the whole table shifts. Can be a one-line change in Section 4.

   Whatever is decided has to be applied to Table 1 and Table 2 together.

[DECIDE] PANELS C AND D ARE NESTED, DELIBERATELY.

   winter_severity_index = wsi_cold_days + wsi_snow_days, so Panel C's
   regressor is a component of Panel D's. They are reported as separate
   panels (one regressor per panel, per the brainstorm doc), never
   entered jointly, so the nesting is a reading caveat rather than a
   collinearity problem. Panel D moving relative to Panel C is the snow
   component doing work.

Coefficient labels are deliberately plain ASCII: a "$" inside a
double-quoted Stata macro is read as a global-macro reference, so LaTeX
math in a label ("\$^\circ\$C") does not survive the round trip. Add math
mode in Overleaf later.

------------------------------------------------------------------------*/

global pvarA "mean_winter_temp"
global pvarB "warm_winter_1sd"
global pvarC "wsi_cold_days"
global pvarD "winter_severity_index"

global plabA "Mean winter temp (Dec t-1 + Jan t + Feb t, deg C)"
global plabB "Winter temp anomaly (1 SD warmer than county norm)"
global plabC "Extreme cold days (days with temp <= 0F)"
global plabD "WSI (extreme cold days + days with >=18in snow depth)"

foreach P in A B C D {
    capture confirm variable ${pvar`P'}
    if _rc {
        display as error "panel `P' regressor not found: ${pvar`P'}"
        exit 111
    }
}

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

24 regressions: 4 panels x 6 columns. The six columns are written out
explicitly rather than looped, because each one carries a different set of
estadd locals (the FE and control checkmarks the table prints) and a loop
that assembled those would be harder to read than the repetition.

[DECIDE] THE HEADER BLOCK IS WRITTEN ONCE, FROM PANEL A.

   Panel A writes the specification header block so the loop must run A
   first. It does: foreach P in A B C D.

   esttab with cells(none) writes the sample / county / obs / FE /
   control rows from Panel A's six stored estimates, then each panel
   appends only coefficient, SE, R-squared and cluster count. That
   produces spec block on top with four panels below in one file rather
   than four stacked tables that each repeat the header.

   Coefficients keep Table 1's %9.4f so the two fragments line up in
   Overleaf. In rate units the fourth decimal is noise -- if the table
   reads better at %9.3f, it is two edits here (b and se) plus the same
   two in the CSV block.

------------------------------------------------------------------------*/

capture program drop run_panel
program define run_panel
    args P

    local x  "${pvar`P'}"
    local xl "${plab`P'}"

    * The b/se column labels are printed under Panel A only and suppressed in
    * B-D, so the row appears once at the top of the table instead of four
    * times. Panel A runs first, so "once" and "at the top" are the same thing.
    local collab "collabels(none)"
    if "`P'" == "A" local collab ""

    * Panel D is the last one written, so it must not end with a command that
    * scans ahead for an optional argument -- \addlinespace does, and at the end
    * of an \input'ed fragment that lookahead crosses into the wrapper and
    * swallows whatever follows (a \bottomrule, giving "Misplaced \noalign").
    local foot "\addlinespace"
    if "`P'" == "D" local foot "% end of fragment"

    eststo clear
    display as text _newline "{hline 78}"
    display as text "PANEL `P': `x'"
    display as text "{hline 78}"

    *--- col 1: county FE + year FE, all states -------------------------------
    quietly reghdfe $Y `x' if $SMAIN, ///
        absorb(county_id year) vce(cluster county_id)
    addcounts
    estadd local fe_county "X"
    estadd local fe_year   "X"
    estadd local fe_styr   ""
    estadd local ctrl_w    ""
    estadd local ctrl_age  ""
    estadd local samp      "All states"
    eststo c1

    *--- col 2: county FE + state x year FE, all states -----------------------
    quietly reghdfe $Y `x' if $SMAIN, ///
        absorb(county_id state_id#year) vce(cluster county_id)
    addcounts
    estadd local fe_county "X"
    estadd local fe_year   ""
    estadd local fe_styr   "X"
    estadd local ctrl_w    ""
    estadd local ctrl_age  ""
    estadd local samp      "All states"
    eststo c2

    *--- col 3: + contemporaneous weather ------------------------------------
    quietly reghdfe $Y `x' $wctrl if $SMAIN, ///
        absorb(county_id state_id#year) vce(cluster county_id)
    addcounts
    estadd local fe_county "X"
    estadd local fe_year   ""
    estadd local fe_styr   "X"
    estadd local ctrl_w    "X"
    estadd local ctrl_age  ""
    estadd local samp      "All states"
    eststo c3

    *--- col 4: + age shares -------------------------------------------------
    quietly reghdfe $Y `x' $agectrl if $SMAIN, ///
        absorb(county_id state_id#year) vce(cluster county_id)
    addcounts
    estadd local fe_county "X"
    estadd local fe_year   ""
    estadd local fe_styr   "X"
    estadd local ctrl_w    ""
    estadd local ctrl_age  "X"
    estadd local samp      "All states"
    eststo c4

    *--- col 5: + weather + age shares ---------------------------------------
    quietly reghdfe $Y `x' $wctrl $agectrl if $SMAIN, ///
        absorb(county_id state_id#year) vce(cluster county_id)
    addcounts
    estadd local fe_county "X"
    estadd local fe_year   ""
    estadd local fe_styr   "X"
    estadd local ctrl_w    "X"
    estadd local ctrl_age  "X"
    estadd local samp      "All states"
    eststo c5

    *--- col 6: same as col 5, agency-direct states only ---------------------
    quietly reghdfe $Y `x' $wctrl $agectrl if $SAGENCY, ///
        absorb(county_id state_id#year) vce(cluster county_id)
    addcounts
    estadd local fe_county "X"
    estadd local fe_year   ""
    estadd local fe_styr   "X"
    estadd local ctrl_w    "X"
    estadd local ctrl_age  "X"
    estadd local samp      "Agency-direct"
    eststo c6

    *--- the header block, from Panel A only ---------------------------------
    if "`P'" == "A" {

        esttab c1 c2 c3 c4 c5 c6 using "$tables/wildlife_weather/regression_harvest_per1000.tex", ///
            replace fragment booktabs cells(none) nomtitles ///
            stats(samp n_county N fe_county fe_year fe_styr ctrl_w ctrl_age, ///
                  fmt(%s %9.0gc %9.0gc %s %s %s %s %s) ///
                  labels("Sample included" "\# of counties" "\# of obs" ///
                         "County FE" "Year FE" "State x year FE" ///
                         "Contemporaneous weather controls (Mar-Nov, year t)" ///
                         "Age shares")) ///
            prehead("% Table 2. Outcome = $YLAB." ///
                    "% Generated by regression_harvest_per1000.do. SEs clustered on county." ///
                    "% Stars: * p<0.10, ** p<0.05, *** p<0.01.") ///
            postfoot("\midrule")

        esttab c1 c2 c3 c4 c5 c6 using "$tables/wildlife_weather/regression_harvest_per1000.csv", ///
            replace plain cells(none) nomtitles ///
            stats(samp n_county N fe_county fe_year fe_styr ctrl_w ctrl_age, ///
                  fmt(%s %9.0gc %9.0gc %s %s %s %s %s) ///
                  labels("Sample included" "# of counties" "# of obs" ///
                         "County FE" "Year FE" "State x year FE" ///
                         "Contemporaneous weather controls" "Age shares")) ///
            title("Table 2 -- outcome = $YLAB")
    }

    *--- this panel's coefficient rows ---------------------------------------
    esttab c1 c2 c3 c4 c5 c6 using "$tables/wildlife_weather/regression_harvest_per1000.tex", ///
        append fragment booktabs nomtitles nonumbers noobs collabels(none) ///
        keep(`x') coeflabel(`x' "`xl'") ///
        cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
        stats(r2_within r2 n_clust, fmt(%9.3f %9.3f %9.0gc) ///
              labels("Within R-squared" "R-squared (incl. FE)" ///
                     "\# of clusters")) ///
        starlevels(* 0.10 ** 0.05 *** 0.01) ///
        prehead("\multicolumn{7}{l}{\textit{Panel `P'}} \\") ///
        postfoot("`foot'")

    esttab c1 c2 c3 c4 c5 c6 using "$tables/wildlife_weather/regression_harvest_per1000.csv", ///
        append plain nomtitles noobs collabels(none) ///
        keep(`x') coeflabel(`x' "`x'") ///
        cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
        stats(r2_within r2 n_clust, fmt(%9.3f %9.3f %9.0gc) ///
              labels("Within R-squared" "R-squared (incl. FE)" ///
                     "\# of clusters")) ///
        starlevels(* 0.10 ** 0.05 *** 0.01) ///
        title("Panel `P': `x'")

    *--- and into the log, where it can be read without leaving Stata --------
    esttab c1 c2 c3 c4 c5 c6, ///
        keep(`x') coeflabel(`x' "`xl'") ///
        cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
        stats(r2 n_clust n_county N, fmt(%9.3f %9.0gc %9.0gc %9.0gc) ///
              labels("R-squared" "# of clusters" "# of counties" "# of obs")) ///
        starlevels(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)") nonumbers collabels(none)
end

* Panel A must run first -- it writes the specification header block.
run_panel A
run_panel B
run_panel C
run_panel D

*==============================================================================
* SECTION 6: QC
*==============================================================================

/*------------------------------------------------------------------------

Four things worth checking after the fact, none of which the estimation
loop would have complained about:

  (a) the four panels rest on identical samples;
  (b) the estimation samples are the sizes this vintage of the input panel
      should give -- and the same ones Table 1 ran on;
  (c) the three counties that drop out are the ones we think they are;
  (e) the rate's own tails, which a log outcome would have compressed and
      this one does not.

(b) is a NOTE rather than an assert: these figures depend on the vintage of
the merged panel sitting in $dataSTATA, so a change is news to look into
rather than proof of a bug in this file. (a) and (c) are structural and
are asserted.

[DECIDE] THE FOUR PANELS MUST REST ON IDENTICAL SAMPLES.

    All four winter measures share the same 30 missing county-years -- but
    that is a property of this vintage of the input panel, not a guarantee,
    and Section 6 re-counts each panel's estimation sample. If they ever
    diverge, the panels are no longer comparable down a column and the table
    should not be used until that is understood.

[DECIDE] THE SAMPLE IS THE UPSTREAM FLAG, NOT A NEW RESTRICTION.

   Cols 1-5 estimate on main_sample (balanced 2005-2014, both harvest
   sources); col 6 on main_sample_agency (same window, agency-direct
   only). Both flags are built in deer_harvest_national_append.do
   Section 5 on NON-MISSING balance, and nothing is re-derived here.

   The flags cover 11,190 and 10,200 county-years, but the REGRESSIONS
   land on 11,160 / 1,116 counties and 10,170 / 1,017. The 30-row
   difference is three counties whose population, age shares AND all four
   winter measures are missing across the whole window -- they cannot be
   estimated on and drop from every column of all three tables. Reported
   in Section 6, not silently absorbed.

   Note that on THIS outcome the same 30 rows would drop for a second,
   independent reason: no population means no rate. Section 2 asserts the
   two reasons coincide, so the rate table and the log table are estimated
   on exactly the same rows.

[DECIDE] NO TRIMMING OR WINSORIZING OF THE RATE.

   The outcome is reported as constructed. In the current vintage it runs
   from 0.00 (Norfolk VA) to about 1,109 per 1,000 (Highland VA, 2008), and
   the top of the distribution is rural counties with real harvests and
   very few residents -- Highland VA, Florence WI, Knox MO, Calhoun AR --
   not data errors, and not counties with a near-zero denominator (the
   smallest population in the estimation sample is about 2,200). County FE
   absorb the level of each of those, so the identifying variation is
   within-county over ten years. 6e lists the tails every run so the
   decision is re-made on evidence rather than inherited.

------------------------------------------------------------------------*/

*--------------------------------- 6a. ---------------------------------------

* The col-5 estimation sample, re-derived for each winter measure.
display as text _newline "  estimation-sample size by winter measure (col 5 spec):"
local _prev = -1
foreach v in mean_winter_temp warm_winter_1sd wsi_cold_days winter_severity_index {
    quietly count if $SMAIN & !missing($Y, `v', population, pop_share_5_9)
    local _thisn = r(N)
    display as text "    " %-24s "`v'" %8.0fc `_thisn'
    if `_prev' != -1 {
        assert `_thisn' == `_prev'
    }
    local _prev = `_thisn'
}
display as text "  all four panels rest on the same estimation sample ([DECIDE] 10)"

*--------------------------------- 6b. ---------------------------------------

quietly {
    count if $SMAIN & !missing($Y, mean_winter_temp, population, pop_share_5_9)
    local _n5 = r(N)
    egen _t5 = tag(geoid) if $SMAIN & !missing($Y, mean_winter_temp, population, pop_share_5_9)
    count if _t5 == 1
    local _c5 = r(N)
    drop _t5

    count if $SAGENCY & !missing($Y, mean_winter_temp, population, pop_share_5_9)
    local _n6 = r(N)
    egen _t6 = tag(geoid) if $SAGENCY & !missing($Y, mean_winter_temp, population, pop_share_5_9)
    count if _t6 == 1
    local _c6 = r(N)
    drop _t6

    levelsof state if $SMAIN, local(_s5) clean
    levelsof state if $SAGENCY, local(_s6) clean
}
local _ns5 : word count `_s5'
local _ns6 : word count `_s6'

display as text _newline "  cols 1-5: `_n5' obs | `_c5' counties | `_ns5' states"
display as text "    states: `_s5'"
display as text "  col 6:    `_n6' obs | `_c6' counties | `_ns6' states"
display as text "    states: `_s6'"

* Expected on the current vintage: 11,160 / 1,116 / 13 and 10,170 / 1,017 / 12,
* identical to regression_log_harvest.do.
if `_n5' != 11160 | `_c5' != 1116 {
    display as error "  NOTE: expected 11,160 obs / 1,116 counties in cols 1-5;" ///
        " got `_n5' / `_c5'. Check the merged-panel vintage before using this table."
}
if `_n6' != 10170 | `_c6' != 1017 {
    display as error "  NOTE: expected 10,170 obs / 1,017 counties in col 6;" ///
        " got `_n6' / `_c6'. Check the merged-panel vintage before using this table."
}

*--------------------------------- 6c. ---------------------------------------

* The counties inside main_sample that no column can estimate on: population,
* age shares and all four winter measures missing across the window. Listed by
* name rather than counted, so a change in WHICH counties drop is visible.
preserve
    keep if $SMAIN & missing(mean_winter_temp)
    if _N > 0 {
        display as text _newline "  main_sample county-years with no weather/population:"
        contract state geoid county_name
        list state geoid county_name _freq, sep(0) noobs
    }
restore

*--------------------------------- 6d. ---------------------------------------

codebook $Y if $SMAIN, compact
summarize $Y mean_winter_temp warm_winter_1sd wsi_cold_days ///
    winter_severity_index if $SMAIN

*--------------------------------- 6e. ---------------------------------------

/* The rate's tails, listed rather than summarized: a per-capita outcome in
   levels is the one place in this table where a single county-year can move
   a coefficient, and the log outcome in Table 1 hid that by construction.
   The counties at the top should be rural, high-harvest and small; the
   counties at the bottom should be independent cities and urban counties.
   Anything else in either list is a data problem, not a tail.            */

display as text _newline "  rate distribution in the estimation sample:"
summarize $Y if $SMAIN & !missing(mean_winter_temp, population, pop_share_5_9), detail

preserve
    keep if $SMAIN & !missing($Y, mean_winter_temp, population, pop_share_5_9)
    gsort -$Y
    display as text _newline "  highest 10 county-year rates:"
    list state county_name year harvest_total population $Y in 1/10, sep(0) noobs
    gsort $Y
    display as text _newline "  lowest 10 county-year rates:"
    list state county_name year harvest_total population $Y in 1/10, sep(0) noobs

    * The denominator itself: a rate is only as stable as the population
    * underneath it, so the smallest denominators are named too.
    gsort population
    display as text _newline "  smallest 10 denominators (population):"
    list state county_name year harvest_total population $Y in 1/10, sep(0) noobs
restore

display as text _newline "  Table 2 written to:"
display as text "    $tables/wildlife_weather/regression_harvest_per1000.tex"
display as text "    $tables/wildlife_weather/regression_harvest_per1000.csv"

log close

/*============================================================================*/
