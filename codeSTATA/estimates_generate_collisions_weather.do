/*==============================================================
FILE:         estimates_generate_collisions_weather.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang

PURPOSE:      Estimate the collisions-on-winter-weather regressions and
              save each specification's estimates to
              $dataSTATA/estimates/collisions/ as a .ster file, for
              estimates_tables_collisions_weather.do to read back.

              Table 1 = animal share of all collisions.
              Table 2 = animal collisions per 100,000 residents,
                        population-weighted.
              Both tables: 4 panels (winter measure) x 4 columns
              (control set) = 16 regressions each.

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

* Inputs:
*   $path/dataSTATA/main_data_county_year.dta
*       (built by build_main_data_county_year.do)
*
* Outputs:
*   $path/dataSTATA/estimates/collisions/<outcome>_p<A-D>_c<1-4>_W<wt>.ster
*       (32 files: 2 outcomes x 4 panels x 4 columns)
*
* OPEN QUESTIONS -- all four are switches in SECTION 1 rather than buried
* assumptions, so they can be flipped in one place after the meeting:
*   Q1. Is the winter regressor lagged once more, or is it already the
*       lag? Equation (1) writes Winter(c,t-1), but Methods footnote 5
*       describes a 2010 outcome using Dec 2009 + Jan/Feb 2010 -- which
*       is exactly what mean_winter_temp at t=2010 already contains.
*       Eyal's Slack example used L1.mean_winter_temp, which would push
*       it a full year further back. `winter_lag' below defaults to 0
*       (contemporaneous) per footnote 5. EVERY coefficient in both
*       tables depends on this.
*   Q2. Which numerator defines the share? animal_total is what the
*       Methods says; deer_total is the species the causal story is
*       about. `share_numerator' below.
*   Q3. Population weights on the share regressions too, or only on the
*       rate regressions? The vultures and bats papers weight
*       throughout; our Methods asks only for the rate. `weight_share'
*       below, empty by default.
*   Q4. Annual precipitation quintiles need ppt_total, which is
*       extracted into prism_county_month.csv but never carried into
*       prism_derived_weather_vars.csv, so it is not in the panel. Until
*       06_build_derived_weather_vars.py passes it through, SECTION 4
*       substitutes quintiles of days_precip_above_10mm and records that
*       substitution in $ppt_control_note for the table notes.
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
cap mkdir "$estimates/collisions"

* reghdfe and estout are required; install once if this is a fresh Stata
* install (same pattern as 10_generate_weather_report.do).
cap which reghdfe
if _rc ssc install reghdfe
cap which ftools
if _rc ssc install ftools
cap which estout
if _rc ssc install estout

*---------------------------------------------------------------
* SECTION 1: SPECIFICATION SWITCHES (the four open questions)
*---------------------------------------------------------------
* Change these here, nowhere else. Every downstream local reads them.

* Q1: 0 = winter measure enters contemporaneously (Methods fn. 5)
*     1 = winter measure enters as L1. (Equation (1) as literally written)
local winter_lag = 0

* Q2: numerator of the share and of the rate.
*     "animal_total" per the Methods; "deer_total" is the alternative.
local share_numerator = "animal_total"

* Q3: weights on the SHARE regressions. Empty = unweighted (current
*     Methods). Set to "[aweight=population]" to weight like the rate.
local weight_share = ""

* Q4 is handled in SECTION 4 (it depends on what is actually in the panel).

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
* SECTION 2: LOAD PANEL AND RESTRICT TO THE ESTIMATION SAMPLE
*---------------------------------------------------------------

local file_name = "$dataSTATA/main_data_county_year.dta"
use "`file_name'", clear

* Numeric state FIPS for the state-by-year fixed effect. Style guide
* Section 10: build it at the point of use, keep geoid as the string key.
gen long state_fips_num = real(state_fips)
label variable state_fips_num "Numeric state FIPS; for reghdfe absorb() only"

xtset fips_num year   // needed for L1. under Q1 == 1

* The collisions panel is 1985-2020 and does not cover every county-year
* in the weather panel. Drop the weather-only rows: they carry no
* outcome and would only inflate the reported N.
keep if merge_collisions == 3

* A share is undefined where there were no collisions at all.
drop if missing(total_total) | total_total <= 0

*---------------------------------------------------------------
* SECTION 3: OUTCOMES
*---------------------------------------------------------------

gen double animal_share = `share_numerator' / total_total
label variable animal_share "`share_numerator' as a share of total_total"

gen double animal_rate_100k = 100000 * `share_numerator' / population
label variable animal_rate_100k "`share_numerator' per 100,000 residents"

* Sanity check, not an assert: the collisions file already ships its own
* ratio variables (*_to_crashes). If one of them is the same quantity we
* just built, they should agree; a disagreement means either a different
* denominator or a different numerator upstream, and is worth knowing
* about BEFORE the coefficients are interpreted.
capture confirm variable animal_to_crashes
if !_rc {
    gen double temp = abs(animal_share - animal_to_crashes)
    qui summ temp, detail
    di as text "CHECK: max |animal_share - animal_to_crashes| = " r(max)
    di as text "       (if this is not ~0, the two use different numerators"
    di as text "        or denominators -- reconcile before reporting.)"
    drop temp
}

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

* --- The four winter measures (one per panel) ------------------------
global rhsA "`L'mean_winter_temp"
global rhsB "`L'warm_winter_1sd `L'warm_winter_2sd"
global rhsC "`L'winter_days_below_0f"
global rhsD "`L'winter_severity_index"

* --- Monthly mean-temperature controls -------------------------------
global Wtemp ""
forvalues m = 1/12 {
    global Wtemp "$Wtemp mean_temp_c_m`m'"
}

* --- Annual precipitation quintiles (Q4) -----------------------------
* Preferred: quintiles of total annual precipitation. Falls back to
* quintiles of the annual count of days above 10mm, which IS in the
* panel, and records the substitution so the table notes can state it
* rather than quietly mislabelling the row.
capture confirm variable ppt_total_m1
if !_rc {
    local pptvars ""
    forvalues m = 1/12 {
        local pptvars "`pptvars' ppt_total_m`m'"
    }
    egen double ppt_annual = rowtotal(`pptvars')
    global ppt_control_note "annual precipitation quintiles"
}
else {
    di as text "NOTE: ppt_total_m1 is not in the panel -- PRISM's ppt is"
    di as text "      extracted into prism_county_month.csv but is not"
    di as text "      carried into prism_derived_weather_vars.csv, which"
    di as text "      is what the merge reads. Substituting quintiles of"
    di as text "      the annual count of days above 10mm. To fix, pass"
    di as text "      ppt through 06_build_derived_weather_vars.py."
    local pptvars ""
    forvalues m = 1/12 {
        local pptvars "`pptvars' days_precip_above_10mm_m`m'"
    }
    egen double ppt_annual = rowtotal(`pptvars')
    global ppt_control_note "quintiles of the annual number of days with precipitation above 10mm (SUBSTITUTE for annual precipitation, which is not yet in the panel)"
}
xtile ppt_q = ppt_annual, nq(5)
label variable ppt_q "Quintile of annual precipitation measure (see \$ppt_control_note)"

global Wppt "i.ppt_q"

* --- Age-share controls (pop_share_0_4 omitted as the base category) --
global Xage ""
foreach a in 5_9 10_14 15_19 20_24 25_29 30_34 35_39 40_44 45_49 ///
             50_54 55_59 60_64 65_69 70_74 75_79 80_84 85plus {
    global Xage "$Xage pop_share_`a'"
}

* --- The four column definitions -------------------------------------
global col1 ""
global col2 "$Wtemp $Wppt"
global col3 "$Xage"
global col4 "$Wtemp $Wppt $Xage"

* --- Fixed effects and standard errors -------------------------------
* County FE + state-by-year FE, clustered at the county level.
global FE "fips_num state_fips_num#year"
global SE "cluster fips_num"

*---------------------------------------------------------------
* SECTION 5: ESTIMATION
*---------------------------------------------------------------
* Variations being run, per the Sept 8 mockup:
*   Panels (winter measure on the right-hand side)
*     A) Mean winter temperature, Dec(t-1)/Jan(t)/Feb(t)
*     B) Warm-winter anomaly dummies, 1SD and 2SD, entered JOINTLY, so
*        the 2SD coefficient reads as the additional effect of an extreme
*        warm winter relative to a 1SD one
*     C) Days below 0F, Dec 1 - Apr 30
*     D) Winter severity index (Kohn / WI DNR)
*   Columns (time-varying controls)
*     1) No time-varying controls
*     2) Monthly mean temperature + precipitation quintiles
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
        local wt       "`weight_share'"
    }
    else {
        local wt       "[aweight=population]"
    }
    if "`wt'" == "" {
        local wsuffix "none"
    }
    else {
        local wsuffix "pop"
    }

    di as result _newline "=== Outcome: `y'  (weights: `wsuffix') ==="

    foreach p in A B C D {

        * Panel D is empty until days_snow_depth_18in exists upstream and
        * SECTION 2 of the build script carries it through. Skip rather
        * than save 4 degenerate .ster files the table script would then
        * read back as a row of missings.
        if "`p'" == "D" {
            qui count if !missing(winter_severity_index)
            if r(N) == 0 {
                di as error "SKIPPING Panel D: winter_severity_index is"
                di as error "  entirely missing. Rerun"
                di as error "  06_build_derived_weather_vars.py (which"
                di as error "  builds days_snow_depth_18in) and rebuild"
                di as error "  main_data_county_year.dta, then rerun this."
                continue
            }
        }

        forvalues c = 1/4 {

            reghdfe `y' ${rhs`p'} ${col`c'} `wt', ///
                    absorb($FE) ///
                    vce($SE)

            qui summ `y' if e(sample)
            estadd scalar dep_var_mean = r(mean)

            * Control-set indicator rows for the table footer.
            if inlist(`c', 2, 4) {
                estadd local ctrl_temp = "X"
                estadd local ctrl_ppt  = "X"
            }
            else {
                estadd local ctrl_temp = ""
                estadd local ctrl_ppt  = ""
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
            estimates save "$estimates/collisions/`reg_file_name'.ster", replace
        }
    }
}

*---------------------------------------------------------------
* SECTION 6: RECORD THE SETTINGS THIS RUN USED
*---------------------------------------------------------------
* The table script needs the coefficient-name prefix (Q1) and the
* precipitation-control wording (Q4). Writing them to a small text file
* keeps the two .do files consistent without either one guessing.

local file_name = "$estimates/collisions/_run_settings.txt"
file open  fh using "`file_name'", write replace
file write fh "winter_lag = `winter_lag'"        _n
file write fh "coef_prefix = $coef_prefix"       _n
file write fh "share_numerator = `share_numerator'" _n
file write fh "weight_share = `weight_share'"    _n
file write fh "ppt_control_note = $ppt_control_note" _n
file write fh "run_date = `c(current_date)'"     _n
file close fh

di as result _newline "Estimates written to $estimates/collisions/"
di as result "Run settings written to `file_name'"

* Wrap Up
cap log close
