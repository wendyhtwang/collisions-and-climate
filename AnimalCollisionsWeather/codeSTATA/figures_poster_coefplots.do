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
                coefplot_harvest.{svg,png,pdf}, coefplot_crashes.{svg,png,pdf},
                coefplot_values.csv

CHANGELOG:
  10/26/2026 Wendy Wang: initial version.
  10/26/2026 Wendy Wang: layout rebuilt to match the poster (label
    column on the left, one zero line for all rows, poster sizes and
    colors); export via svg, as in the style guide.
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

* The poster is set in Arial; project defaults are restored at the end.
graph set window fontface "Arial"
graph set svg fontface "Arial"

*---------------------------------------------------------------
* SECTION 1: SPECIFICATION SWITCHES
*---------------------------------------------------------------
* Columns plotted, as on the poster: harvest = full controls (4),
* crashes = county + state x year FE only (1).

local col_harvest = 4
local col_crashes = 1
local w_crashes   = "none"        // weight suffix of the crash .ster
local z           = invnormal(0.975)
local crash_years = "1985–2020"   // for the crash caption

* Accepted first-regressor names per panel (crash Panel C is a clone
* of wsi_cold_days; a lagged run prefixes "L.").
local okA "mean_winter_temp"
local okB "warm_winter_1sd"
local okC "wsi_cold_days winter_days_below_0f"
local okD "winter_severity_index"

* Layout in inches, copied from the poster's plot block (10.2 in wide,
* four 1.75 in rows): label column, value-label margins, data region,
* and where zero sits inside the data region.
local W       = 10.2
local row_h   = 1.75
local lab_w   = 3.95
local val_w   = 1.15
local data_w  = 3.95
local zero_at = 0.62
local L       = `data_w' * `zero_at'
local R       = `data_w' * (1 - `zero_at')
local zero    = `lab_w' + `val_w' + `L'

*---------------------------------------------------------------
* SECTION 2: READ ESTIMATES
*---------------------------------------------------------------
* Harvest: 100 x log coefficient (% change).
* Crashes: coefficient / outcome mean x 100 (% of mean share).

tempname P
tempfile res
postfile `P' str8 outcome str1 panel str32 regressor ///
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

        post `P' ("`o'") ("`p'") ("`x'") (`b') (`se') (e(N)) ///
            (`ymean') (`scale') (`b' * `scale') ///
            ((`b' - `z' * `se') * `scale') ((`b' + `z' * `se') * `scale') ///
            ("`ster'")
    }
}
postclose `P'

*---------------------------------------------------------------
* SECTION 3: LABELS, CSV, ROW GEOMETRY
*---------------------------------------------------------------

use `res', clear

gen byte row = strpos("ABCD", panel)

gen str32 measure = ""
replace measure = "Mean winter temp."     if panel == "A"
replace measure = "Warm-winter anomaly"   if panel == "B"
replace measure = "Extreme-cold days"     if panel == "C"
replace measure = "Winter Severity Index" if panel == "D"

gen str40 unit = ""
replace unit = "per +1°C"               if panel == "A"
replace unit = "≥ 1 SD warmer, vs. not" if panel == "B"
replace unit = "per extra day ≤ 0°F"    if panel == "C"
replace unit = "per +1 index point"     if panel == "D"

* Value labels: 1 decimal for A/B, 2 for C/D, as on the poster.
gen str16 estlab = cond(est < 0, "−", "+") + ///
    cond(inlist(panel, "A", "B"), string(abs(est), "%4.1f"), ///
                                  string(abs(est), "%4.2f")) + "%"

export delimited outcome panel measure unit regressor b se N ymean ///
    scale est lo hi estlab ster ///
    using "`outdir'/coefplot_values.csv", replace

* One zero line for all rows. Each row gets its own scale (inches per
* unit), shared by the two figures, so its CI fits on both.
egen double negx = max(cond(lo < 0, -lo, 0)), by(panel)
egen double posx = max(cond(hi > 0,  hi, 0)), by(panel)
gen double s = min(cond(negx > 0, `L' / negx, .), cond(posx > 0, `R' / posx, .))

gen double cy     = 4 * `row_h' - (row - 0.5) * `row_h'
gen double zero_x = `zero'
gen double est_x  = `zero' + est * s
gen double lo_x   = `zero' + lo  * s
gen double hi_x   = `zero' + hi  * s

list outcome panel regressor b se est lo hi estlab, ///
    sepby(outcome) noobs abbrev(12)

*---------------------------------------------------------------
* SECTION 4: FIGURES
*---------------------------------------------------------------
* Gray bars, WSI bar in the panel color, as on the poster. Text is
* added with text() so sizes are absolute (pt) and match the poster.

local ytop = 4 * `row_h'

foreach o in harvest crashes {

    preserve
    keep if outcome == "`o'"
    sort row

    if "`o'" == "harvest" {
        local accent "$poster_green"
        local t1 "Change in next-fall deer harvest"
        local t2 " (% per unit of winter measure)"
        local n1 "Full controls. Lines show 95% CIs; each row has its own scale, shared with panel"
        local n2 "4. WSI is also significant for harvest per 1,000 residents and z-score."
    }
    else {
        local accent "$poster_orange"
        local t1 "Change in animal share of crashes"
        local t2 " (% of mean per unit)"
        local nobs : di %9.0gc N[1]
        local nobs = strtrim("`nobs'")
        local n1 "County & state × year FE; 95% CIs, county-clustered SEs; `nobs' county-years,"
        local n2 "`crash_years'. WSI also significant per 100k residents; robust to data checks."
    }

    * Row labels (bold name over gray unit) and value labels.
    local tx ""
    forvalues i = 1/`=_N' {
        local y  = cy[`i']
        local yn = `y' + 0.17
        local yu = `y' - 0.19
        local nm = measure[`i']
        local un = unit[`i']
        local tx `"`tx' text(`yn' 0.1 "{bf:`nm'}", place(e) size(22pt) color("$poster_text"))"'
        local tx `"`tx' text(`yu' 0.1 "`un'", place(e) size(19pt) color("$poster_muted"))"'

        local vl = estlab[`i']
        if panel[`i'] == "D" local vl "{bf:`vl'}"
        if est[`i'] < 0 {
            local xv = lo_x[`i'] - 0.08
            local tx `"`tx' text(`y' `xv' "`vl'", place(w) size(22pt) color("$poster_text"))"'
        }
        else {
            local xv = hi_x[`i'] + 0.08
            local tx `"`tx' text(`y' `xv' "`vl'", place(e) size(22pt) color("$poster_text"))"'
        }
    }

    twoway (pci 0.15 `zero' `=`ytop' - 0.15' `zero', ///
                lcolor("$poster_zero") ///
                lwidth(1.8pt)) ///
           (rbar zero_x est_x cy if panel != "D", ///
                horizontal ///
                barwidth(0.56) ///
                fcolor("$poster_bar_gray") ///
                lcolor("$poster_bar_gray") ///
                lwidth(none)) ///
           (rbar zero_x est_x cy if panel == "D", ///
                horizontal ///
                barwidth(0.56) ///
                fcolor("`accent'") ///
                lcolor("`accent'") ///
                lwidth(none)) ///
           (rcap lo_x hi_x cy, ///
                horizontal ///
                lcolor("$poster_ci") ///
                lwidth(3.2pt) ///
                msize(23pt)), ///
           `tx' ///
           xscale(range(0 `W') off) ///
           yscale(range(0 `ytop') off) ///
           xlabel(none) ///
           ylabel(none) ///
           title(`"{bf:`t1'}`t2'"', size(22pt) color("$poster_text") ///
                 placement(west) justification(left) span) ///
           note(`"{it:`n1'}"' `"{it:`n2'}"', size(20pt) color("$poster_muted") ///
                placement(west) justification(left) span) ///
           legend(off) ///
           plotregion(margin(zero) style(none) color(white)) ///
           graphregion(margin(small) color(white)) ///
           xsize(`W') ///
           ysize(8.4)

    local file_name = "`outdir'/coefplot_`o'"
    graph export "`file_name'.svg", replace
    cap graph export "`file_name'.png", width(3060) replace
    cap erase "`file_name'.pdf"
    cap shell inkscape --export-type="pdf" "`file_name'.svg"

    restore
}

* Restore the project's default figure fonts.
do "$path/codeSTATA/set_figure_fonts_colors.do"

* Wrap Up
log close
