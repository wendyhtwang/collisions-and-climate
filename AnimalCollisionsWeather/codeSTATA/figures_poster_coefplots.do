/*==============================================================
FILE:         figures_poster_coefplots.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang

PURPOSE:      Coefficient plots for the Climate Frontiers 2026 poster:
              per-unit effect of each winter measure on next-fall deer
              harvest (panel 3) and on the animal share of crashes
              (panel 4), with 95% CIs.

INPUTS:       .ster files from regression_log_harvest.do (column 4) and
              estimates_generate_collisions_weather.do (column 1).
OUTPUTS:      $figures/poster_climate_frontiers_2026/
                coefplot_harvest.pdf, coefplot_crashes.pdf,
                coefplot_values.csv

CHANGELOG:
  10/26/2026 Wendy Wang: initial version.
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

global estimates "$path/dataSTATA/estimates"
global figures   "$path/figures"
local outdir     "$figures/poster_climate_frontiers_2026"

cap mkdir "$figures"
cap mkdir "`outdir'"

cap mkdir "$path/codeSTATA/logs"
log using "$path/codeSTATA/logs/figures_poster_coefplots.log", replace text

do "$path/codeSTATA/set_figure_fonts_colors.do"

*---------------------------------------------------------------
* SECTION 1: SPECIFICATION SWITCHES
*---------------------------------------------------------------
* Columns plotted, as on the poster: harvest = full controls (4),
* crashes = county + state x year FE only (1).

local col_harvest = 4
local col_crashes = 1
local w_crashes   = "none"        // weight suffix of the crash .ster
local z           = invnormal(0.975)

* Accepted first-regressor names per panel (crash Panel C is a clone
* of wsi_cold_days; a lagged run prefixes "L.").
local okA "mean_winter_temp"
local okB "warm_winter_1sd"
local okC "wsi_cold_days winter_days_below_0f"
local okD "winter_severity_index"

*---------------------------------------------------------------
* SECTION 2: READ ESTIMATES
*---------------------------------------------------------------
* Harvest: 100 x log coefficient (% change).
* Crashes: coefficient / outcome mean x 100 (% of mean share).

tempname R
tempfile res
postfile `R' str8 outcome str1 panel str32 regressor ///
    double(b se N ymean scale est lo hi) str244 ster using `res'

foreach o in harvest crashes {
    foreach p in A B C D {

        if "`o'" == "harvest" {
            local ster "$estimates/wildlife_weather/ln_harvest_p`p'_c`col_harvest'_Wnone.ster"
        }
        else {
            local pp = cond("`p'" == "B", "B1", "`p'")
            local ster "$estimates/collisions_weather/animal_share_p`pp'_c`col_crashes'_W`w_crashes'.ster"
        }

        capture confirm file "`ster'"
        if _rc {
            di as error "Missing `ster'"
            di as error "Run regression_log_harvest.do and estimates_generate_collisions_weather.do first."
            exit 601
        }

        estimates use "`ster'"
        matrix B = e(b)
        matrix V = e(V)
        local names : colnames B
        local x : word 1 of `names'

        * The winter measure is the first regressor in every specification.
        local found = 0
        foreach s of local ok`p' {
            if strpos("`x'", "`s'") > 0 local found = 1
        }
        if `found' == 0 {
            di as error "Unexpected first regressor `x' in `ster'"
            exit 459
        }

        local b  = B[1,1]
        local se = sqrt(V[1,1])
        if "`o'" == "harvest" {
            local ymean = .
            local scale = 100
        }
        else {
            local ymean = e(dep_var_mean)
            local scale = 100 / `ymean'
        }

        post `R' ("`o'") ("`p'") ("`x'") (`b') (`se') (e(N)) ///
            (`ymean') (`scale') (`b' * `scale') ///
            ((`b' - `z' * `se') * `scale') ((`b' + `z' * `se') * `scale') ///
            ("`ster'")
    }
}
postclose `R'

*---------------------------------------------------------------
* SECTION 3: LABELS, SHARED ROW RANGES, CSV
*---------------------------------------------------------------

use `res', clear

gen str32 measure = ""
replace measure = "Mean winter temp."     if panel == "A"
replace measure = "Warm-winter anomaly"   if panel == "B"
replace measure = "Extreme-cold days"     if panel == "C"
replace measure = "Winter Severity Index" if panel == "D"

gen str40 unit = ""
replace unit = "per +1°C"                       if panel == "A"
replace unit = "1+ SD warmer vs. not"           if panel == "B"
replace unit = "per extra day at or below 0°F"  if panel == "C"
replace unit = "per +1 index point"             if panel == "D"

* Value labels: 1 decimal for A/B, 2 for C/D, as on the poster.
gen str12 estlab = cond(est < 0, "-", "+") + ///
    cond(inlist(panel, "A", "B"), string(abs(est), "%4.1f"), ///
                                  string(abs(est), "%4.2f")) + "%"

export delimited outcome panel measure unit regressor b se N ymean ///
    scale est lo hi estlab ster ///
    using "`outdir'/coefplot_values.csv", replace

* Each row (winter measure) gets its own x-range, shared across the two
* figures so harvest and crash bars for the same measure are comparable.
egen double rmin = min(min(lo, 0)), by(panel)
egen double rmax = max(max(hi, 0)), by(panel)
gen double xlo    = rmin - 0.35 * (rmax - rmin)
gen double xhi    = rmax + 0.35 * (rmax - rmin)
gen double labx   = cond(est < 0, lo, hi)
gen byte   labpos = cond(est < 0, 9, 3)
gen byte   ypos   = 1

list outcome panel regressor b se est lo hi estlab, ///
    sepby(outcome) noobs abbrev(12)

*---------------------------------------------------------------
* SECTION 4: FIGURES
*---------------------------------------------------------------
* One small graph per winter measure, stacked. The WSI bar (the
* headline estimate) is in the outcome's color; the rest are gray.

foreach o in harvest crashes {

    if "`o'" == "harvest" {
        local accent "$color_vir_9"
        local otitle "Change in next-fall deer harvest (% per unit of winter measure)"
    }
    else {
        local accent "$dark_orange"
        local otitle "Change in animal share of crashes (% of mean per unit)"
    }

    foreach p in A B C D {

        qui summ xlo if outcome == "`o'" & panel == "`p'"
        local xlo = r(mean)
        qui summ xhi if outcome == "`o'" & panel == "`p'"
        local xhi = r(mean)
        qui levelsof measure if outcome == "`o'" & panel == "`p'", local(m) clean
        qui levelsof unit    if outcome == "`o'" & panel == "`p'", local(u) clean

        if "`p'" == "D" local barcol "`accent'"
        else            local barcol "$mute_calm_7"

        twoway (bar est ypos, ///
                    horizontal ///
                    barwidth(0.6) ///
                    fcolor("`barcol'") ///
                    lcolor("`barcol'")) ///
               (rcap lo hi ypos, ///
                    horizontal ///
                    lcolor(black) ///
                    lwidth(medthick) ///
                    msize(medlarge)) ///
               (scatter ypos labx, ///
                    msymbol(none) ///
                    mlabel(estlab) ///
                    mlabvposition(labpos) ///
                    mlabcolor(black) ///
                    mlabsize(large)) ///
               if outcome == "`o'" & panel == "`p'", ///
               xline(0, lcolor(gs8) lwidth(thin)) ///
               xscale(range(`xlo' `xhi') off) ///
               yscale(range(0.4 1.6) off) ///
               xlabel(none) ///
               ylabel(none) ///
               title("`m'", size(medsmall) color(black) ///
                     placement(west) justification(left) span) ///
               subtitle("`u'", size(small) color(gs7) ///
                        placement(west) justification(left) span) ///
               legend(off) ///
               plotregion(color(white)) ///
               graphregion(color(white)) ///
               name(g_`o'_`p', replace) ///
               nodraw
    }

    graph combine g_`o'_A g_`o'_B g_`o'_C g_`o'_D, ///
        cols(1) ///
        imargin(tiny) ///
        title("`otitle'", size(medsmall) color(black) ///
              placement(west) justification(left) span) ///
        note("Bars: estimates. Lines: 95% CIs. Each row has its own scale, shared across both figures.", ///
             size(vsmall)) ///
        graphregion(color(white)) ///
        xsize(5) ///
        ysize(6)

    local file_name = "`outdir'/coefplot_`o'"
    graph export "`file_name'.pdf", replace
    cap graph export "`file_name'.png", width(2400) replace
}

* Wrap Up
log close
