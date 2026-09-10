/*==============================================================
FILE:         estimates_generate_collisions_weather.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang

PURPOSE:      Estimate the collisions-on-winter-weather regressions and
              save each specification's estimates to
              $dataSTATA/estimates/collisions_weather/ as a .ster file, for
              estimates_tables_collisions_weather.do to read back.

              Table 1 = animal share of all collisions.
              Table 2 = animal collisions per 100,000 residents,
                        population-weighted.
              Both tables: 4 panels (winter measure) x 4 columns
              (control set). Panel B's two anomaly thresholds are
              estimated as SEPARATE specifications (B1, B2) and only one
              is carried into the table -- see the 09/10/2026 changelog
              entry -- so this file runs 5 panels x 4 columns x 2
              outcomes = 40 regressions.

CHANGELOG:
  09/08/2026 Wendy Wang: initial version, per Eyal (9/1/26): each RA
    writes one estimation .do and one table .do; this is the estimation
    half of the collisions-weather pair. Structure follows the Sept 8
    "Collisions on Winter Weather" mockup, with three deviations from
    that mockup, all deliberate:
    (a) state-by-year FE are absorbed as `state_fips_num#year` per style
        guide Section 10, not as a pre-built `egen group()` variable;
    (b) vce() takes `cluster fips_num`, not `cluster(fips_num)` -- the
        mockup's nested parentheses are not valid reghdfe syntax;
    (c) the precipitation-quintile control degrades to a documented
        substitute rather than erroring, since ppt_total is still not
        carried into prism_derived_weather_vars.csv (see SECTION 4).
  09/10/2026 Wendy Wang: revised against Eyal's comments on the mockup at
    the 9/8/26 meeting, and against the 9/9/26 rebuild of the panel --
    (a) PANEL B IS NO LONGER ONE JOINT REGRESSION. Eyal: "I would choose
        either or... I don't think we wanted the same regression with a
        dummy for sigma and above and two sigma and above, especially
        because there's going to be overlap." warm_winter_1sd and
        warm_winter_2sd are now estimated separately as panels B1 and B2,
        both saved, and SECTION 7 prints them side by side so the choice
        of which to publish is made by looking at the numbers. Eyal's
        tie-break rule, for the record: if both are precise and point the
        same way, keep the 1SD version, "just because it has more
        support, it's like we [have a] higher frequency of those events
        in the data."
    (b) The two control-indicator rows are collapsed into one. Eyal:
        "since you're always going to be including the mean temperature
        and the precipitation quantiles together, you can just narrow
        that to one row and just call it 'weather controls.'" `ctrl_temp'
        and `ctrl_ppt' are replaced by a single `ctrl_weather'.
    (c) Q4 IS CLOSED. The 9/9/26 rebuild carries ppt_total through
        prism_derived_weather_vars.csv (12 base PRISM vars x 12 months),
        so ppt_total_m1..m12 are in the panel and the days-above-10mm
        substitute is gone. SECTION 4 now STOPS if ppt_total is absent
        rather than silently substituting: with two project trees on
        Kodama (git clone vs Dropbox) a stale CSV is a live risk, and a
        quietly mislabelled control row is worse than a failed run.
    (d) Added the all-animal backfill Eyal asked to verify on 9/8/26
        ("if there is a non-missing deer value, that should also be a
        minimum and non-missing any_animal value... you should not lose
        any observations from using the any_animal whatsoever"). SECTION
        3 now counts and fills, and reports the count. Note this is the
        FILL; check_animal_deer_backfill.do is the standalone diagnostic.
    (e) Removed the animal_to_crashes cross-check. That variable does not
        exist in the built panel -- the ratio variables that do exist are
        animal_pdo_to_crashes and animal_fatalities_to_crashes, neither
        of which is animal_total/total_total -- so the block could never
        fire and was dead code (style guide Section 8).
    (f) Added SECTION 5: missingness of each control block on the
        estimation sample, plus the frequency of each anomaly dummy.
        Column N is expected to move between columns 1 and 4; this is
        what says by how much, before the table shows it.
    (g) The sample restriction is now a flag (est_sample) applied as an
        `if' on each regression, not a keep/drop. The earlier version
        dropped the weather-only rows before xtset, which is safe only
        because Q1 currently defaults to contemporaneous: flip winter_lag
        to 1 and L1. would have been reaching for rows that no longer
        existed, blanking the regressor for every county-year whose
        predecessor sits outside the collisions panel and shrinking N
        without saying so.
  09/10/2026 Wendy Wang: output subfolder renamed from
    dataSTATA/estimates/collisions to dataSTATA/estimates/collisions_weather,
    so the .ster folder is named for the pair of scripts that writes and
    reads it rather than for the outcome alone. The matching read path in
    estimates_tables_collisions_weather.do was changed in the same pass;
    any .ster files already sitting in the old folder are stale and should
    be deleted rather than moved, since they predate the Panel B split.

* Inputs:
*   $path/dataSTATA/main_data_county_year.dta
*       (built by build_main_data_county_year.do)
*
* Outputs:
*   $path/dataSTATA/estimates/collisions_weather/<outcome>_p<A|B1|B2|C|D>_c<1-4>_W<wt>.ster
*       (40 files: 2 outcomes x 5 panels x 4 columns)
*   $path/dataSTATA/estimates/collisions_weather/_run_settings.txt
*       (the switch settings this run used; read back by the table file)
*   $path/codeSTATA/estimates_generate_collisions_weather.log
*
* OPEN QUESTIONS -- switches in SECTION 1 rather than buried assumptions,
* so they can be flipped in one place once resolved:
*   Q1. Is the winter regressor lagged once more, or is it already the
*       lag? Equation (1) writes Winter(c,t-1), but Methods footnote 5
*       describes a 2010 outcome using Dec 2009 + Jan/Feb 2010 -- which
*       is exactly what mean_winter_temp at t=2010 already contains.
*       Eyal's Slack example used L1.mean_winter_temp, which would push
*       it a full year further back. `winter_lag' below defaults to 0
*       (contemporaneous) per footnote 5. EVERY coefficient in both
*       tables depends on this. NOT YET RAISED WITH EYAL -- ask before
*       these numbers go in the paper.
*   Q2. Which numerator defines the outcome? Settled 9/8/26 in favour of
*       all-animal ("take the all animal one because some states report
*       by animal, some just report any animal"); `share_numerator' is
*       kept as a switch only so the deer-only version can be run as a
*       robustness cut without editing the body of the file.
*   Q3. Population weights on the share regressions too, or only on the
*       rate regressions? Both of Eyal's 2024 papers weight throughout;
*       our Methods asks only for the rate. `weight_share' below, empty
*       by default. Also not yet raised.
==============================================================*/

*---------------------------------------------------------------
* SECTION 0: SETUP
*---------------------------------------------------------------

cap log close
clear all
set more off, permanently
set matsize 11000
set maxvar 32767
set scheme s1mono

confirmdir "/mnt/data_d/Dropbox/Research"
if r(confirmdir) == "0" {
  local rootDir = "/mnt/data_d/Dropbox/Research"
}
confirmdir "C:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "C:/Dropbox/Research"
}
confirmdir "D:/Dropbox"
if r(confirmdir) == "0" {
  local rootDir = "D:/Dropbox/Research"
}

if "$path" == "" {
    global path = "`rootDir'/AnimalCollisionsWeather"
}

global dataSTATA  "$path/dataSTATA"
global estimates  "$path/dataSTATA/estimates"
global tables     "$path/tables"

cap mkdir "$estimates"
cap mkdir "$estimates/collisions_weather"

* Open log file in the codeSTATA directory, matching
* build_main_data_county_year.do
local log_file = "$path/codeSTATA/estimates_generate_collisions_weather.log"
cap log close
log using "`log_file'", replace text

* reghdfe and estout are required; install once if this is a fresh Stata
* install (same pattern as 10_generate_weather_report.do).
cap which reghdfe
if _rc ssc install reghdfe
cap which ftools
if _rc ssc install ftools
cap which estout
if _rc ssc install estout

*---------------------------------------------------------------
* SECTION 1: SPECIFICATION SWITCHES (the open questions)
*---------------------------------------------------------------
* Change these here, nowhere else. Every downstream local reads them.

* Q1: 0 = winter measure enters contemporaneously (Methods fn. 5)
*     1 = winter measure enters as L1. (Equation (1) as literally written)
local winter_lag = 0

* Q2: numerator of the share and of the rate. Settled 9/8/26:
*     "animal_total" per Eyal; "deer_total" is the robustness cut.
local share_numerator = "animal_total"

* Q3: weights on the SHARE regressions. Empty = unweighted (current
*     Methods). Set to "[aweight=population]" to weight like the rate.
local weight_share = ""

* Derived from Q1: the lag operator prefix applied to every winter
* regressor, and the matching prefix that will appear in the coefficient
* NAMES that estimates_tables_collisions_weather.do has to keep().
if `winter_lag' == 1 {
    local L  = "L1."
    global coef_prefix = "L."
}
else {
    local L  = ""
    global coef_prefix = ""
}

*---------------------------------------------------------------
* SECTION 2: LOAD PANEL AND FLAG THE ESTIMATION SAMPLE
*---------------------------------------------------------------

local file_name = "$dataSTATA/main_data_county_year.dta"
use "`file_name'", clear

* Numeric state FIPS for the state-by-year fixed effect. Style guide
* Section 10: build it at the point of use, keep geoid as the string key.
gen long state_fips_num = real(state_fips)
label variable state_fips_num "Numeric state FIPS; for reghdfe absorb() only"

* fips_num is real(geoid); a malformed geoid upstream would surface here
* as a missing county identifier, which cannot be a fixed effect.
qui count if missing(fips_num)
if r(N) > 0 {
    di as error "WARNING: `r(N)' rows have a missing fips_num and are"
    di as error "  being dropped. Check geoid construction in SECTION 6"
    di as error "  of build_main_data_county_year.do."
    drop if missing(fips_num)
}

* xtset is needed for the L1. operator under Q1 == 1, and doubles as the
* duplicate check: a repeated county-year would make the lag ambiguous,
* and xtset errors out rather than silently picking one.
xtset fips_num year

* The estimation sample is flagged rather than kept, and applied as an
* `if' on each regression, so that the whole weather panel stays in
* memory. This matters under Q1 == 1: the collisions panel is 1985-2020
* and does not cover every county-year the weather panel does, so
* dropping the weather-only rows first would leave L1. reaching into
* rows that are no longer there and silently blanking the regressor for
* every county-year whose predecessor is outside the collisions sample.
* Rows outside the flag would in any case contribute nothing -- the
* outcomes below are missing wherever total_total is.
gen byte est_sample = (merge_collisions == 3) ///
                      & !missing(total_total) ///
                      & total_total > 0
label variable est_sample "1 if county-year is in the collisions estimation sample"

*---------------------------------------------------------------
* SECTION 3: OUTCOMES
*---------------------------------------------------------------
* Eyal, 9/8/26, on which collision count is the numerator: "Take the all
* animal one because some states report by animal, some just report any
* animal... if there is a non-missing deer value, that should also be a
* minimum and non-missing any_animal value... You should not lose any
* observations from using the any_animal whatsoever. You should only be
* gaining observations."
*
* He believed the file that appended the state collisions data already
* backfilled a missing animal value from a non-missing deer value, but
* asked for it to be checked rather than assumed. The fill is applied
* here so the estimation sample is right regardless of what the upstream
* snapshot did; the counts below say whether it was needed.
* check_animal_deer_backfill.do is the standalone diagnostic and reports
* the offending rows.

qui count if est_sample & missing(animal_total) & !missing(deer_total)
local n_backfill = r(N)
replace animal_total = deer_total if missing(animal_total) & !missing(deer_total)

qui count if est_sample & !missing(animal_total) & !missing(deer_total) ///
             & deer_total > animal_total
local n_deer_exceeds = r(N)

di as text _newline "{hline 70}"
di as text "All-animal / deer consistency on the estimation sample:"
di as text "  rows backfilled (animal missing, deer present): `n_backfill'"
di as text "  rows where deer_total > animal_total:           `n_deer_exceeds'"
if `n_backfill' > 0 {
    di as error "  NOTE: the upstream appended collisions file did NOT"
    di as error "  already backfill these. Flag to Eyal and Charvi -- the"
    di as error "  fix belongs upstream, not here."
}
if `n_deer_exceeds' > 0 {
    di as error "  NOTE: deer exceeds all-animal somewhere, which should"
    di as error "  be impossible. Run check_animal_deer_backfill.do for"
    di as error "  the offending geoid-year rows before reporting these"
    di as error "  estimates."
}
di as text "{hline 70}"

gen double animal_share = `share_numerator' / total_total
label variable animal_share "`share_numerator' as a share of total_total"

gen double animal_rate_100k = 100000 * `share_numerator' / population ///
    if population > 0 & !missing(population)
label variable animal_rate_100k "`share_numerator' per 100,000 residents"

*---------------------------------------------------------------
* SECTION 4: WINTER REGRESSORS AND CONTROL SETS
*---------------------------------------------------------------

* --- Panel C's regressor: days below 0F over the Dec-Apr window -------
* This is numerically identical to wsi_cold_days, which is built in
* build_main_data_county_year.do SECTION 7. Cloned under its own name so
* the panel label and the variable label agree -- Panel C is a standalone
* winter measure here, not "the cold half of the WSI".
* TODO: move this clonevar upstream into SECTION 7 of the build script so
* every downstream file sees the same variable.
clonevar winter_days_below_0f = wsi_cold_days
label variable winter_days_below_0f "# days Dec 1-Apr 30 with min temp <=0F"

* --- The winter measures, one per panel -------------------------------
* B1 and B2 are the SAME panel of the published table, estimated twice:
* Eyal, 9/8/26, on running both dummies in one regression -- "I would
* choose either or... especially because there's going to be overlap
* between one sigma and above and two sigma and above. So I would just --
* you can run both and decide which one you want to keep."
global rhsA  "`L'mean_winter_temp"
global rhsB1 "`L'warm_winter_1sd"
global rhsB2 "`L'warm_winter_2sd"
global rhsC  "`L'winter_days_below_0f"
global rhsD  "`L'winter_severity_index"

* --- Monthly mean-temperature controls -------------------------------
global Wtemp ""
forvalues m = 1/12 {
    global Wtemp "$Wtemp mean_temp_c_m`m'"
}

* --- Annual precipitation quintiles ----------------------------------
* ppt_total_m1..m12 are PRISM monthly precipitation totals in mm, carried
* through prism_derived_weather_vars.csv as of the 9/9/26 rebuild. If
* they are absent, the Stata side is reading a stale dataCSV copy (Kodama
* keeps two project trees -- the git clone and the Dropbox tree the .do
* files read). Stop rather than substitute: a mislabelled control row is
* worse than a run that fails loudly.
capture confirm variable ppt_total_m1
if _rc {
    di as error "ppt_total_m1 is not in the panel. PRISM precipitation is"
    di as error "  extracted into prism_county_month.csv and, since the"
    di as error "  9/9/26 rebuild, carried into"
    di as error "  prism_derived_weather_vars.csv. Its absence here means"
    di as error "  build_main_data_county_year.do read a stale copy of"
    di as error "  that CSV -- check the column count Stata reports on"
    di as error "  import delimited (12 base vars x 12 months, not 11),"
    di as error "  rerun 06_build_derived_weather_vars.py against the"
    di as error "  Dropbox tree, and rebuild the panel."
    exit 111
}

local pptvars ""
forvalues m = 1/12 {
    local pptvars "`pptvars' ppt_total_m`m'"
}

* rowtotal reads missing as zero, which would turn a county-year with
* missing months into a spuriously dry one. Count the missing months
* first and blank the annual total if any month is absent.
egen byte temp = rowmiss(`pptvars')
egen double ppt_annual = rowtotal(`pptvars'), missing
replace ppt_annual = . if temp > 0
drop temp
label variable ppt_annual "Total annual precipitation, mm (sum of 12 PRISM monthly totals)"

* Quintiles are cut on the estimation sample, not the full weather panel,
* so the five bins carry roughly equal numbers of estimation rows.
xtile ppt_q = ppt_annual if est_sample, nq(5)
label variable ppt_q "Quintile of total annual precipitation"

global Wppt "i.ppt_q"
global ppt_control_note "annual precipitation quintiles"

* --- Age-share controls (pop_share_0_4 omitted as the base category) --
* The 18 shares sum to one, so one band has to be left out or the set is
* collinear with the fixed effects' implicit constant.
global Xage ""
foreach a in 5_9 10_14 15_19 20_24 25_29 30_34 35_39 40_44 45_49 ///
             50_54 55_59 60_64 65_69 70_74 75_79 80_84 85plus {
    global Xage "$Xage pop_share_`a'"
}

* --- The four column definitions -------------------------------------
* Monthly mean temperature and the precipitation quintiles always enter
* together, which is why the table reports them as a single "Weather
* controls" row (Eyal, 9/8/26).
global col1 ""
global col2 "$Wtemp $Wppt"
global col3 "$Xage"
global col4 "$Wtemp $Wppt $Xage"

* --- Fixed effects and standard errors -------------------------------
* County FE + state-by-year FE, clustered at the county level. State-by-
* year is the baseline rather than plain year because every outcome
* series is assembled state by state, each with its own reporting regime
* that changes over time (Eyal, 9/8/26).
global FE "fips_num state_fips_num#year"
global SE "cluster fips_num"

*---------------------------------------------------------------
* SECTION 5: WHAT THE CONTROL BLOCKS COST IN SAMPLE
*---------------------------------------------------------------
* Columns 1-4 are meant to "diagnose what and if at all the controls do
* anything" (Eyal, 9/8/26). That reading only holds if the sample is
* roughly stable across columns, so report the missingness each block
* introduces before the table does. If N moves materially between column
* 1 and column 4, raise a fixed-sample variant with Eyal rather than
* letting the reader infer it from the N row.

qui count if est_sample
local n_est = r(N)
di as text _newline "{hline 70}"
di as text "Estimation sample: `n_est' county-year rows"

foreach block in Wtemp Wppt Xage {
    if "`block'" == "Wppt" {
        local blockvars "ppt_q"
    }
    else {
        local blockvars "${`block'}"
    }
    egen byte temp = rowmiss(`blockvars')
    qui count if est_sample & temp > 0
    di as text "  rows missing at least one `block' variable: " r(N)
    drop temp
}

* Frequency of each anomaly dummy, which is the "support" Eyal's
* tie-break between 1SD and 2SD turns on.
foreach v in warm_winter_1sd warm_winter_2sd {
    qui summ `v' if est_sample
    di as text "  share of rows with `v' == 1: " %6.4f r(mean) ///
               "  (N = " r(N) ")"
}
di as text "{hline 70}"

*---------------------------------------------------------------
* SECTION 6: ESTIMATION
*---------------------------------------------------------------
* Variations being run:
*   Panels (winter measure on the right-hand side)
*     A)  Mean winter temperature, Dec(t-1)/Jan(t)/Feb(t)
*     B1) Warm-winter anomaly, >= 1SD above the county's own climatology
*     B2) Warm-winter anomaly, >= 2SD, estimated SEPARATELY from B1
*     C)  Days below 0F, Dec 1 - Apr 30
*     D)  Winter severity index (Kohn 1975 / WI DNR)
*   Columns (time-varying controls)
*     1) No time-varying controls
*     2) Weather controls: monthly mean temperature + precipitation quintiles
*     3) Age shares
*     4) All of the above
*   Outcomes (one table each)
*     animal_share      -> Table 1, weights per Q3 (default: none)
*     animal_rate_100k  -> Table 2, population-weighted
*
* estadd runs BEFORE estimates save so the dependent-variable mean and
* the X/blank control indicators travel inside the .ster file, per style
* guide Section 11. The table script then needs no access to the data.

foreach y in animal_share animal_rate_100k {

    * Weights, and the suffix that records them in the file name.
    if "`y'" == "animal_share" {
        local wt "`weight_share'"
    }
    else {
        local wt "[aweight=population]"
    }
    if "`wt'" == "" {
        local wsuffix "none"
    }
    else {
        local wsuffix "pop"
    }

    di as result _newline "=== Outcome: `y'  (weights: `wsuffix') ==="

    foreach p in A B1 B2 C D {

        * Panel D is degenerate if the WSI snow component never made it
        * into the panel. It did as of the 9/9/26 rebuild, but the two
        * project trees on Kodama mean a stale dataCSV copy can quietly
        * put it back to all-missing, so keep the guard: skip rather than
        * save four empty .ster files the table script would read back as
        * a row of missings.
        if "`p'" == "D" {
            qui count if est_sample & !missing(winter_severity_index)
            if r(N) == 0 {
                di as error "SKIPPING Panel D: winter_severity_index is"
                di as error "  entirely missing on the estimation sample."
                di as error "  Rerun 06_build_derived_weather_vars.py"
                di as error "  (which builds days_snow_depth_18in) against"
                di as error "  the Dropbox tree and rebuild"
                di as error "  main_data_county_year.dta, then rerun this."
                continue
            }
        }

        forvalues c = 1/4 {

            reghdfe `y' ///
                    ${rhs`p'} ///
                    ${col`c'} ///
                    if est_sample ///
                    `wt', ///
                    absorb($FE) ///
                    vce($SE)

            * Weighted where the regression is weighted, so the mean in
            * the column header is on the same footing as the estimates.
            qui summ `y' if e(sample) `wt'
            estadd scalar dep_var_mean = r(mean)

            * Control-set indicator rows for the table footer. One row
            * for the weather block, per Eyal 9/8/26.
            if inlist(`c', 2, 4) {
                estadd local ctrl_weather = "X"
            }
            else {
                estadd local ctrl_weather = ""
            }
            if inlist(`c', 3, 4) {
                estadd local ctrl_age = "X"
            }
            else {
                estadd local ctrl_age = ""
            }

            * File name records outcome, panel, column and weighting, so
            * it is readable without opening it (style guide Section 11).
            local reg_file_name = "`y'_p`p'_c`c'_W`wsuffix'"
            estimates save "$estimates/collisions_weather/`reg_file_name'.ster", replace
        }
    }
}

*---------------------------------------------------------------
* SECTION 7: PANEL B -- 1SD VS 2SD, SIDE BY SIDE
*---------------------------------------------------------------
* Eyal, 9/8/26: "you can run both and decide which one you want to
* keep... They'll have different magnitudes. Maybe one would be precise,
* one won't be. If they're both precise... then I probably just keep the
* one sigma, just because it has more support."
*
* Both are saved. This prints them next to each other so that decision is
* made by looking at the numbers, then recorded once in the table file's
* `panelB_sd' switch. Coefficients are pulled out of e(b)/e(V) by column
* name rather than with _b[]/_se[], so the Q1 lag prefix cannot silently
* mismatch.

foreach y in animal_share animal_rate_100k {

    if "`y'" == "animal_share" & "`weight_share'" == "" {
        local wsuffix "none"
    }
    else {
        local wsuffix "pop"
    }

    di as result _newline "{hline 78}"
    di as result "Panel B inspection -- outcome: `y' (weights: `wsuffix')"
    di as text   "{hline 78}"
    di as text %-4s "Col" %5s "SD" %14s "Coef" %14s "Std err" ///
               %9s "t" %12s "N" %10s "Clusters"

    forvalues c = 1/4 {
        foreach s in 1 2 {

            local ster = "$estimates/collisions_weather/`y'_pB`s'_c`c'_W`wsuffix'.ster"
            capture confirm file "`ster'"
            if _rc {
                di as error "  MISSING: `ster'"
                continue
            }

            estimates use "`ster'"

            * Note $coef_prefix, not `L': the regressor is written
            * L1.warm_winter_1sd but Stata stores the coefficient under
            * the canonical name L.warm_winter_1sd.
            local nm = "${coef_prefix}warm_winter_`s'sd"
            matrix temp_b = e(b)
            matrix temp_v = e(V)
            local j = colnumb(temp_b, "`nm'")

            if missing(`j') {
                di as error "  `nm' not found in `ster'"
            }
            else {
                local coef = temp_b[1, `j']
                local se   = sqrt(temp_v[`j', `j'])
                local tst  = `coef' / `se'
                di as text %-4.0f `c' %5.0f `s' %14.6f `coef' ///
                           %14.6f `se' %9.2f `tst' ///
                           %12.0fc e(N) %10.0fc e(N_clust)
            }

            matrix drop temp_b temp_v
        }
    }
    di as text "{hline 78}"
}

di as text _newline "Decide 1SD vs 2SD from the block above, then record it"
di as text "in the panelB_sd switch in estimates_tables_collisions_weather.do."
di as text "Eyal's tie-break: both precise and same-signed -> keep 1SD."

*---------------------------------------------------------------
* SECTION 8: RECORD THE SETTINGS THIS RUN USED
*---------------------------------------------------------------
* The table script needs the coefficient-name prefix (Q1) and the
* precipitation-control wording. Writing them to a small text file keeps
* the two .do files consistent without either one guessing.

local file_name = "$estimates/collisions_weather/_run_settings.txt"
file open  fh using "`file_name'", write replace
file write fh "winter_lag = `winter_lag'"                   _n
file write fh "coef_prefix = $coef_prefix"                  _n
file write fh "share_numerator = `share_numerator'"         _n
file write fh "weight_share = `weight_share'"               _n
file write fh "ppt_control_note = $ppt_control_note"        _n
file write fh "n_backfilled_animal_from_deer = `n_backfill'" _n
file write fh "n_deer_exceeds_animal = `n_deer_exceeds'"    _n
file write fh "estimation_sample_rows = `n_est'"            _n
file write fh "run_date = `c(current_date)'"                _n
file close fh

di as result _newline "Estimates written to $estimates/collisions_weather/"
di as result "Run settings written to `file_name'"

* Wrap Up
log close
