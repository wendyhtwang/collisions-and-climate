/*==============================================================
FILE:          descriptive_collisions.do
PROJECT:       Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD:  Wendy Wang

PURPOSE:  Phase 3 descriptive exhibits for the 9/1/26 collisions
          snapshot (county-year, 1985-2020). First pass, NOT YET RUN.

OUTPUT ($outDESC), one PDF per exhibit:
  figures/  A1 availability; F1 national trends; F2 severity;
            F3-F5 state small multiples
  maps/     M1-M4 county maps (animal rate, animal share)
  tables/   A1 availability, F1/F2 series, S1 pooled, S2 by state (.csv)

DECISIONS:
  1. Animal numerator = the regression numerator (any_animal_total,
     then severity components, then deer_total, floored at deer_total),
     so the descriptives describe the estimated outcome. A1 and S2
     report which step each row came from.
  2. Series problems are shown in the state-level exhibits. F4 plots
     raw any_animal_total against deer_total; flag_states are drawn
     in a second color in F3.
  3. National series are ratios of sums over reporting states, plus
     the same ratio over a fixed balanced state set (bal_y0-bal_y1),
     because states enter the panel in different years. National
     lines are drawn only for years with >= min_states states.
  3a. A state-year whose animal count sums to zero statewide is
     treated as not reported (zero coded for missing: AR, IA, NE, NJ
     throughout, early years of FL, KY, OH, PA and others).
  3b. NM (excl_states) is left out of the national animal series and
     the maps: its animal count equals its all-cause count (share =
     100% on every row). It stays in F3-F5, flagged.
  4. Rates: per 100,000 residents (animal), per 1,000 (all-cause),
     matching WP Table 5 and Section 3.1. Per road-mile is the
     alternative for the PI; road miles are not in the panel.
  5. Decade maps use 2010-2019; 2020 (COVID traffic) stays in the
     trends and the full-sample map only.
  6. total_total <= 0 is treated as missing in every share and rate.
  7. Not built: alcohol-related exhibits (no alcohol variables in
     this snapshot).

CHANGELOG:
  10/18/2026: First pass.
  10/19/2026: After first run. Statewide-zero rule (3a), NM out of
    national animal series and maps (3b), min_states cut on national
    lines, one PDF per exhibit (no PNGs, no single-panel copies),
    axis and legend fixes in A1, F1, F3.
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
set varabbrev off

foreach p in confirmdir spmap {
    capture which `p'
    if _rc ssc install `p', replace
}

local rootDir = ""

confirmdir "/mnt/data_d/Dropbox/Research"
if r(confirmdir) == "0" local rootDir = "/mnt/data_d/Dropbox/Research"

if "`rootDir'" == "" {
    confirmdir "C:/Dropbox/Research"
    if r(confirmdir) == "0" local rootDir = "C:/Dropbox/Research"
}

if "`rootDir'" == "" {
    confirmdir "D:/Dropbox/Research"
    if r(confirmdir) == "0" local rootDir = "D:/Dropbox/Research"
}

if "`rootDir'" == "" {
    di as error "No Dropbox research root found. Add this machine's root above."
    exit 601
}

* Explicit globals rather than $path: the master file sets $path to
* AnimalCollisionsWeather, and this file lives in the sibling repo.
global pathVCD  "`rootDir'/VehicleCollisionsDataRepo"
global pathACW  "`rootDir'/AnimalCollisionsWeather"
global pathUNG  "`rootDir'/UngulatePopulationDataRepo"
global outDESC  "$pathVCD/output/descriptives_collisions"
global shpRAW   "$pathVCD/dataRAW/Shapefiles/Census_cb_2018"
global shpSTATA "$pathVCD/dataSTATA/_shapefiles"

cap mkdir "$pathVCD/codeSTATA/logs"
log using "$pathVCD/codeSTATA/logs/descriptive_collisions.log", replace text

cap mkdir "$pathVCD/output"
cap mkdir "$outDESC"
cap mkdir "$outDESC/figures"
cap mkdir "$outDESC/maps"
cap mkdir "$outDESC/tables"

* Shared fonts and palette globals
local file_name = "$pathACW/codeSTATA/set_figure_fonts_colors.do"
capture confirm file "`file_name'"
if _rc {
    di as error "not found: `file_name'"
    exit 601
}
* capture: the font lines may fail in console Stata; the palette
* globals this file uses are re-set below if the do-file stopped early
capture noisily do "`file_name'"
if "$bdazzled_blue" == "" {
    di as text "  fonts/colors file did not finish; using fallback palette"
    global bdazzled_blue = "61 90 128"
    global pale_cerulean = "152 193 217"
    global burnt_sienna  = "238 108 77"
    global cherry_red    = "201 76 76"
    global dark_green    = "0 109 119"
    global light_pink    = "255 221 210"
    global slab_gray     = "208 184 172"
    global mute_calm_7   = "192 192 192"
    global gunmetal      = "41 50 65"
}

* Windows and flags
local y_first    = 1985
local y_last     = 2020
local bal_y0     = 2005    // balanced window; check A1 and retune
local bal_y1     = 2019
local min_years  = 3       // min observed years for a county mean on a map
local min_states = 10      // min reporting states for a national point
local flag_states "NY WV NM"
local excl_states "NM"

global gw "graphregion(color(white)) plotregion(color(white))"

* Export helper: one PDF per exhibit
capture program drop gexport
program define gexport
    args gname fname sub
    quietly graph display `gname'
    graph export "$outDESC/`sub'/`fname'.pdf", name(`gname') replace
end

* Map class breaks pooled across several variables, so every map of
* the same measure shares one scale. Inner breaks are percentiles
* rounded to two significant figures.
capture program drop mapbreaks
program define mapbreaks, rclass
    syntax varlist(numeric min=2), Pctiles(numlist ascending >0 <100)
    local np : word count `pctiles'
    preserve
    quietly {
        keep `varlist'
        stack `varlist', into(_v) clear
        drop if missing(_v)
        summarize _v
        local lo = floor(r(min))
        local hi = ceil(r(max))
        _pctile _v, percentiles(`pctiles')
        forvalues i = 1/`np' {
            local q`i' = r(r`i')
        }
    }
    restore
    local breaks "`lo'"
    local prev = `lo'
    forvalues i = 1/`np' {
        local q = `q`i''
        if `q' > 0 local q = round(`q', 10^(floor(log10(`q')) - 1))
        if `q' > `prev' & `q' < `hi' {
            local breaks "`breaks' `q'"
            local prev = `q'
        }
    }
    local breaks "`breaks' `hi'"
    return local breaks "`breaks'"
end

*---------------------------------------------------------------
* SECTION 1: COUNTY & STATE BOUNDARIES
*---------------------------------------------------------------

* Reuse the CONUS boundary files deer_descriptives.do already built
* (Census cb 2018 1:20m, Albers); build them here only if missing.
local have_shp = 1
foreach f in us_county_shp_conus us_state_shp_conus county_attr_conus {
    capture confirm file "$pathUNG/dataSTATA/_shapefiles/`f'.dta"
    if _rc local have_shp = 0
}

if `have_shp' {
    global shpSTATA "$pathUNG/dataSTATA/_shapefiles"
}
else {
    capture which geo2xy
    if _rc ssc install geo2xy, replace
    cap mkdir "$pathVCD/dataRAW/Shapefiles"
    cap mkdir "$shpRAW"
    cap mkdir "$pathVCD/dataSTATA"
    cap mkdir "$shpSTATA"

    * unzipfile extracts into the working directory
    local _here = c(pwd)
    cd "$shpRAW"
    foreach g in county state {
        capture confirm file "cb_2018_us_`g'_20m.shp"
        if _rc {
            copy "https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_us_`g'_20m.zip" ///
                 "cb_2018_us_`g'_20m.zip", replace
            unzipfile "cb_2018_us_`g'_20m.zip", replace
        }
        spshape2dta cb_2018_us_`g'_20m, replace saving(us_`g')
        copy "us_`g'.dta"     "$shpSTATA/us_`g'.dta", replace
        copy "us_`g'_shp.dta" "$shpSTATA/us_`g'_shp.dta", replace
    }
    cd "`_here'"

    foreach g in county state {
        use "$shpSTATA/us_`g'.dta", clear
        gen byte conus = !inlist(STATEFP, "02", "15", "60", "66", "69", "72", "78")
        keep _ID conus
        tempfile keep_`g'
        save `keep_`g''

        use "$shpSTATA/us_`g'_shp.dta", clear
        merge m:1 _ID using `keep_`g'', assert(match) nogenerate
        keep if conus == 1
        drop conus
        geo2xy _Y _X, projection(albers) replace
        sort _ID shape_order
        save "$shpSTATA/us_`g'_shp_conus.dta", replace
    }

    use "$shpSTATA/us_county.dta", clear
    keep if !inlist(STATEFP, "02", "15", "60", "66", "69", "72", "78")
    rename GEOID county_fips
    gen double land_mi2 = ALAND / 2589988.11
    keep _ID county_fips STATEFP NAME land_mi2
    isid county_fips
    save "$shpSTATA/county_attr_conus.dta", replace
}

use "$shpSTATA/county_attr_conus.dta", clear
keep _ID county_fips
rename county_fips geoid
tempfile county_attr
save `county_attr'

*---------------------------------------------------------------
* SECTION 2: LOAD COLLISIONS & BUILD OUTCOMES
*---------------------------------------------------------------

local file_name = "$pathACW/dataRAW/Collisions/collisions_CONUS_county_year_1985_2020.dta"
capture confirm file "`file_name'"
if _rc {
    di as error "not found: `file_name'"
    exit 601
}
use "`file_name'", clear

* Pin the 9/1/26 snapshot
count
assert r(N) == 60804

rename state_letter_code state
gen str5 geoid = state_fips + county_fips
replace geoid = "" if strlen(geoid) != 5
count if geoid == ""
di as text "  rows without a valid 5-digit FIPS (known St. Louis issue): " r(N)
isid geoid year, missok

* Numerator: same three fills and floor as
* estimates_generate_collisions_weather.do (DECISION 1). num_source is
* set before each replace because the condition tests the old value.
gen double comp_total = any_animal_fatal + any_animal_injury + any_animal_pdo
gen double any_animal_filled = any_animal_total
gen byte num_source = 1 if !missing(any_animal_filled)

replace num_source        = 2          if missing(any_animal_filled) & !missing(comp_total)
replace any_animal_filled = comp_total if missing(any_animal_filled) & !missing(comp_total)

replace num_source        = 3          if missing(any_animal_filled) & !missing(deer_total)
replace any_animal_filled = deer_total if missing(any_animal_filled) & !missing(deer_total)

replace num_source        = 4          if !missing(any_animal_filled) & !missing(deer_total) & deer_total > any_animal_filled
replace any_animal_filled = deer_total if !missing(any_animal_filled) & !missing(deer_total) & deer_total > any_animal_filled

label define num_source_lbl 1 "native" 2 "component rebuild" ///
                            3 "deer stand-in" 4 "deer floor", replace
label values num_source num_source_lbl
tab num_source, missing

* Statewide zero = not reported (DECISION 3a)
bysort state year: egen double sy_animal = total(any_animal_filled), missing
gen byte is_zero_sy = sy_animal == 0
drop sy_animal
count if is_zero_sy
di as text "  county-years blanked by the statewide-zero rule: " r(N)
tab state if is_zero_sy
replace any_animal_filled = . if is_zero_sy
replace num_source        = . if is_zero_sy

* Left out of national animal series and maps (DECISION 3b)
gen byte is_excluded = 0
foreach s of local excl_states {
    replace is_excluded = 1 if state == "`s'"
}

* Defect markers for S2
gen byte is_inversion = !missing(deer_total, any_animal_total) & deer_total > any_animal_total
gen byte is_id_gap    = !missing(any_animal_total, comp_total) & any_animal_total != comp_total

* Shares and rates (DECISIONS 4, 6)
gen byte has_total = !missing(total_total) & total_total > 0
gen double share_animal = 100 * any_animal_filled / total_total ///
    if has_total & !missing(any_animal_filled)
gen byte is_share_gt100 = share_animal > 100 & !missing(share_animal)
count if is_share_gt100
di as text "  county-years with animal share above 100%: " r(N)

* Population: prefer the 1981-2025 file, fall back to 1990-2025
local pop_file = ""
foreach f in population_county_year_1981_2025 population_county_year_1990_2025 {
    capture confirm file "$pathACW/dataCSV/Population/`f'.dta"
    if !_rc & "`pop_file'" == "" local pop_file "$pathACW/dataCSV/Population/`f'.dta"
}
if "`pop_file'" == "" {
    di as error "no population file found in $pathACW/dataCSV/Population"
    exit 601
}
di as text "  population file: `pop_file'"

merge m:1 geoid year using "`pop_file'", keepusing(population) keep(master match) gen(merge_pop)
count if merge_pop == 1
di as text "  collisions rows with no population match: " r(N)
tab state if merge_pop == 1
drop merge_pop

gen byte has_pop = !missing(population) & population > 0
gen double rate_all_1k = 1000 * total_total / population if has_total & has_pop
gen double rate_animal_100k = 100000 * any_animal_filled / population ///
    if !missing(any_animal_filled) & has_pop

* Map polygon IDs
merge m:1 geoid using `county_attr', keep(master match) gen(merge_shp)
count if merge_shp == 1
di as text "  collisions rows with no 2018 county polygon: " r(N)
tab state if merge_shp == 1
drop merge_shp

encode state, gen(sid)

label variable any_animal_filled "All-animal collisions; component- then deer-filled, floored at deer_total"
label variable num_source        "Numerator provenance"
label variable share_animal      "Animal-related share of all collisions, percent"
label variable rate_all_1k       "All-cause collisions per 1,000 residents"
label variable rate_animal_100k  "Animal-related collisions per 100,000 residents"

summarize total_total any_animal_filled deer_total share_animal rate_all_1k rate_animal_100k

tempfile panel
save `panel'

*---------------------------------------------------------------
* SECTION 3: DATA AVAILABILITY (A1)
*---------------------------------------------------------------

* CSV: counties reporting each variable, by state-year. A reported
* zero counts as reported.
local avail_vars total_total ///
                 total_fatal ///
                 total_injury ///
                 total_pdo ///
                 any_animal_total ///
                 any_animal_fatal ///
                 any_animal_injury ///
                 any_animal_pdo ///
                 animal_total ///
                 wild_animal_total ///
                 deer_total ///
                 deer_fatal ///
                 deer_injury ///
                 deer_pdo

preserve
    gen byte n_counties = 1
    collapse (sum) n_counties (count) `avail_vars', by(state year)
    export delimited using "$outDESC/tables/A1_availability_state_year.csv", replace
restore

* Figure: one tile per state-year, colored by the modal row category
gen byte avail_cat = .
replace avail_cat = num_source if has_total & !missing(num_source)
replace avail_cat = 5 if is_zero_sy
replace avail_cat = 6 if has_total & missing(num_source) & !is_zero_sy
replace avail_cat = 7 if !has_total & !missing(num_source)
replace avail_cat = 8 if missing(avail_cat)

bysort state year: egen byte sy_cat = mode(avail_cat), minmode
bysort state year: keep if _n == 1
keep state sid year sy_cat
tab sy_cat

gen double y_lo = year - 0.45
gen double y_hi = year + 0.45
quietly summarize sid
local n_states = r(max)

local cat_lab1 "As reported"
local cat_lab2 "Rebuilt from severity counts"
local cat_lab3 "Deer count stand-in"
local cat_lab4 "Raised to deer count"
local cat_lab5 "Zero statewide, treated as missing"
local cat_lab6 "All-cause only"
local cat_lab7 "Animal count, no all-cause total"
local cat_lab8 "No counts"
global cat_col1 "$bdazzled_blue"
global cat_col2 "$pale_cerulean"
global cat_col3 "$burnt_sienna"
global cat_col4 "$cherry_red"
global cat_col5 "$gunmetal"
global cat_col6 "$mute_calm_7"
global cat_col7 "$light_pink"
global cat_col8 "$slab_gray"

* Only non-empty categories get a plot and a legend key
local plots ""
local order ""
local k = 0
forvalues c = 1/8 {
    quietly count if sy_cat == `c'
    if r(N) > 0 {
        local ++k
        local plots `"`plots' (rbar y_lo y_hi sid if sy_cat == `c', horizontal barwidth(0.85) fcolor("${cat_col`c'}") lwidth(none))"'
        local order `"`order' `k' "`cat_lab`c''""'
    }
}

twoway `plots', ///
    yscale(reverse) ///
    ylabel(1(1)`n_states', valuelabel angle(0) labsize(vsmall) nogrid noticks labgap(small)) ///
    xlabel(1985(5)2020, labsize(small)) ///
    xscale(range(1984.5 2020.5)) ///
    xline(`bal_y0' `bal_y1', lpattern(shortdash) lcolor(gs10)) ///
    ytitle("") ///
    xtitle("") ///
    legend(order(`order') ///
           cols(3) ///
           pos(6) ///
           size(vsmall) ///
           symxsize(*0.5) ///
           region(lcolor(none))) ///
    xsize(9) ///
    ysize(8) ///
    $gw ///
    name(a1, replace)
gexport a1 A1_availability_state_year figures

*---------------------------------------------------------------
* SECTION 4: NATIONAL TRENDS (F1)
*---------------------------------------------------------------

use `panel', clear

* Rows valid for each measure (DECISION 6)
gen byte v_share = has_total & !missing(any_animal_filled)
gen byte v_rall  = has_total & has_pop
gen byte v_ran   = !missing(any_animal_filled) & has_pop

gen double sh_num = any_animal_filled if v_share
gen double sh_den = total_total       if v_share
gen double ra_num = total_total       if v_rall
gen double ra_pop = population        if v_rall
gen double rn_num = any_animal_filled if v_ran
gen double rn_pop = population        if v_ran

* collapse (sum) returns 0 for all-missing groups; the counts below
* blank those
collapse (sum) sh_num ///
               sh_den ///
               ra_num ///
               ra_pop ///
               rn_num ///
               rn_pop ///
               n_sh = v_share ///
               n_ra = v_rall ///
               n_rn = v_ran ///
               an_raw = any_animal_total ///
               dr_raw = deer_total ///
         (count) n_anraw = any_animal_total ///
                 n_dr = deer_total ///
         (max) is_excluded, ///
         by(state sid year)

gen double st_share = 100 * sh_num / sh_den    if n_sh > 0
gen double st_rall  = 1000 * ra_num / ra_pop   if n_ra > 0
gen double st_ran   = 100000 * rn_num / rn_pop if n_rn > 0
gen double an_k     = an_raw / 1000            if n_anraw > 0
gen double dr_k     = dr_raw / 1000            if n_dr > 0

* National inputs: excl_states out of the animal series (DECISION 3b)
foreach v in sh_num sh_den rn_num rn_pop {
    gen double in_`v' = `v' if !is_excluded
}
gen double in_ra_num = ra_num
gen double in_ra_pop = ra_pop
gen double rep_sh = st_share if !is_excluded
gen double rep_ra = st_rall
gen double rep_rn = st_ran   if !is_excluded

* Balanced state set: a valid share in every year of the window
gen byte in_win = inrange(year, `bal_y0', `bal_y1') & n_sh > 0 & !is_excluded
bysort state: egen n_win = total(in_win)
gen byte bal_state = n_win == (`bal_y1' - `bal_y0' + 1)
levelsof state if bal_state, local(bal_list) clean
local n_bal : word count `bal_list'
di as text "  balanced states, `bal_y0'-`bal_y1' (`n_bal'): `bal_list'"

* States reporting a valid share, by year (for retuning the window)
tab year if n_sh > 0 & !is_excluded

tempfile sy_raw
save `sy_raw'

* National: all reporting states; years below min_states not drawn
collapse (sum) a_sh_num = in_sh_num ///
               a_sh_den = in_sh_den ///
               a_ra_num = in_ra_num ///
               a_ra_pop = in_ra_pop ///
               a_rn_num = in_rn_num ///
               a_rn_pop = in_rn_pop ///
         (count) n_st_sh = rep_sh ///
                 n_st_ra = rep_ra ///
                 n_st_rn = rep_rn, ///
         by(year)
gen double nat_share = 100 * a_sh_num / a_sh_den    if n_st_sh >= `min_states'
gen double nat_rall  = 1000 * a_ra_num / a_ra_pop   if n_st_ra >= `min_states'
gen double nat_ran   = 100000 * a_rn_num / a_rn_pop if n_st_rn >= `min_states'
keep year n_st_* nat_*
tempfile nat
save `nat'

* National: balanced state set, window years only
if `n_bal' > 0 {
    use `sy_raw', clear
    keep if bal_state & inrange(year, `bal_y0', `bal_y1')
    collapse (sum) b_sh_num = in_sh_num ///
                   b_sh_den = in_sh_den ///
                   b_ra_num = in_ra_num ///
                   b_ra_pop = in_ra_pop ///
                   b_rn_num = in_rn_num ///
                   b_rn_pop = in_rn_pop, ///
             by(year)
    gen double bal_share = 100 * b_sh_num / b_sh_den
    gen double bal_rall  = 1000 * b_ra_num / b_ra_pop
    gen double bal_ran   = 100000 * b_rn_num / b_rn_pop
    keep year bal_*
    tempfile nat_bal
    save `nat_bal'

    use `nat', clear
    merge 1:1 year using `nat_bal'
    assert _merge != 2
    drop _merge
}
else {
    use `nat', clear
    gen double bal_share = .
    gen double bal_rall  = .
    gen double bal_ran   = .
}
export delimited using "$outDESC/tables/F1_national_series.csv", replace
save `nat', replace

* State-year panel with gaps filled, so lines break across them
use `sy_raw', clear
xtset sid year
tsfill
bysort sid (state): replace state = state[_N] if state == ""
bysort sid (bal_state): replace bal_state = bal_state[1]
bysort sid (is_excluded): replace is_excluded = is_excluded[1]

merge m:1 year using `nat'
assert _merge != 2
drop _merge

bysort year (sid): gen byte yr_tag = _n == 1
sort sid year

gen byte flagged = 0
foreach s of local flag_states {
    replace flagged = 1 if state == "`s'"
}

tempfile sy
save `sy'

* F1a-c: thin line per state, bold national line, dashed balanced set.
* Units live in the subtitle so the y-title cannot collide with labels.
local sub_rall   "All-cause collisions per 1,000 residents"
local sub_ran    "Animal-related collisions per 100,000 residents"
local sub_share  "Animal-related share of all collisions (%)"
local cond_rall  "1"
local cond_ran   "!is_excluded"
local cond_share "!is_excluded"

foreach m in rall ran share {
    local balplot ""
    local balleg ""
    if `n_bal' > 0 {
        local balplot `"(line bal_`m' year if yr_tag, sort(year) lcolor("$burnt_sienna") lwidth(medthick) lpattern(dash))"'
        local balleg `"3 "Balanced set""'
    }

    twoway (line st_`m' year if `cond_`m'', ///
                connect(L) ///
                cmissing(n) ///
                lcolor("$pale_cerulean") ///
                lwidth(vthin)) ///
           (line nat_`m' year if yr_tag, ///
                sort(year) ///
                lcolor("$bdazzled_blue") ///
                lwidth(thick)) ///
           `balplot', ///
        ytitle("") ///
        xtitle("") ///
        ylabel(, angle(0) labsize(small) glcolor(gs15)) ///
        xlabel(1985(5)2020, labsize(small)) ///
        legend(order(2 "All states" `balleg' 1 "Single states") ///
               rows(1) ///
               pos(6) ///
               size(small) ///
               symxsize(*0.5) ///
               region(lcolor(none))) ///
        subtitle("`sub_`m''", pos(11) size(medsmall)) ///
        $gw ///
        name(f1_`m', replace) ///
        nodraw
}

* F1d: states reporting a valid animal share; dashed line = min_states
twoway bar n_st_sh year if yr_tag, ///
    barwidth(0.8) ///
    color(gs10) ///
    yline(`min_states', lpattern(dash) lcolor(gs6)) ///
    ytitle("") ///
    xtitle("") ///
    ylabel(, angle(0) labsize(small) glcolor(gs15)) ///
    xlabel(1985(5)2020, labsize(small)) ///
    subtitle("States reporting animal and all-cause counts", pos(11) size(medsmall)) ///
    $gw ///
    name(f1_nst, replace) ///
    nodraw

graph combine f1_rall f1_ran f1_share f1_nst, ///
    cols(2) ///
    imargin(small) ///
    xsize(11) ///
    ysize(7.5) ///
    note("National lines: years with at least `min_states' reporting states. Balanced set: the `n_bal' states reporting every year `bal_y0'–`bal_y1'." ///
         "`excl_states' left out of the animal series (animal count equals all-cause count).", ///
         size(vsmall)) ///
    $gw ///
    name(f1, replace)
gexport f1 F1_national_trends figures

*---------------------------------------------------------------
* SECTION 5: SEVERITY (F2)
*---------------------------------------------------------------

* Severity components are used as reported (no fill), so the set of
* reporting states differs by severity and from F1. Statewide-zero
* and excluded state-years are out (DECISIONS 3a, 3b); for injury and
* PDO the statewide-zero rule is also applied to the component itself.
use `panel', clear
foreach s in fatal injury pdo {
    gen double an_`s' = any_animal_`s' if !is_zero_sy & !is_excluded
    gen byte   vs_`s' = !missing(total_`s', an_`s') & total_`s' > 0
    gen double sn_`s' = an_`s'         if vs_`s'
    gen double sd_`s' = total_`s'      if vs_`s'
    gen byte   vr_`s' = !missing(total_`s') & has_pop
    gen double rr_`s' = total_`s'      if vr_`s'
    gen double rp_`s' = population     if vr_`s'
}
collapse (sum) sn_* sd_* rr_* rp_* vs_* vr_*, by(state year)

foreach s in injury pdo {
    replace sd_`s' = 0 if sn_`s' == 0
    replace vs_`s' = 0 if sn_`s' == 0
}
foreach s in fatal injury pdo {
    gen byte st_vs_`s' = vs_`s' > 0
    gen byte st_vr_`s' = vr_`s' > 0
}
collapse (sum) sn_* sd_* rr_* rp_* st_vs_* st_vr_*, by(year)
foreach s in fatal injury pdo {
    gen double sh_`s' = 100 * sn_`s' / sd_`s'  if st_vs_`s' >= `min_states'
    gen double rt_`s' = 1000 * rr_`s' / rp_`s' if st_vr_`s' >= `min_states'
}
keep year sh_* rt_* st_vs_* st_vr_*
export delimited using "$outDESC/tables/F2_national_severity_series.csv", replace

twoway (line rt_fatal year, lcolor("$bdazzled_blue") lwidth(medthick)) ///
       (line rt_injury year, lcolor("$burnt_sienna") lwidth(medthick)) ///
       (line rt_pdo year, lcolor("$dark_green") lwidth(medthick)), ///
    yscale(log) ///
    ylabel(0.01 0.1 1 10 100, angle(0) labsize(small) glcolor(gs15)) ///
    ytitle("") ///
    xtitle("") ///
    xlabel(1985(5)2020, labsize(small)) ///
    legend(order(1 "Fatal" 2 "Injury" 3 "Property damage only") ///
           rows(1) ///
           pos(6) ///
           size(small) ///
           region(lcolor(none))) ///
    subtitle("All-cause collisions per 1,000 residents (log scale)", pos(11) size(medsmall)) ///
    $gw ///
    name(f2_rate, replace) ///
    nodraw

twoway (line sh_fatal year, lcolor("$bdazzled_blue") lwidth(medthick)) ///
       (line sh_injury year, lcolor("$burnt_sienna") lwidth(medthick)) ///
       (line sh_pdo year, lcolor("$dark_green") lwidth(medthick)), ///
    ytitle("") ///
    xtitle("") ///
    ylabel(, angle(0) labsize(small) glcolor(gs15)) ///
    xlabel(1985(5)2020, labsize(small)) ///
    legend(order(1 "Fatal" 2 "Injury" 3 "Property damage only") ///
           rows(1) ///
           pos(6) ///
           size(small) ///
           region(lcolor(none))) ///
    subtitle("Animal-related share of collisions (%)", pos(11) size(medsmall)) ///
    $gw ///
    name(f2_share, replace) ///
    nodraw

graph combine f2_rate f2_share, ///
    cols(2) ///
    imargin(small) ///
    xsize(11) ///
    ysize(4.5) ///
    note("Years with at least `min_states' reporting states. `excl_states' left out of the animal share.", size(vsmall)) ///
    $gw ///
    name(f2, replace)
gexport f2 F2_severity figures

*---------------------------------------------------------------
* SECTION 6: STATE SMALL MULTIPLES (F3, F4, F5)
*---------------------------------------------------------------

use `sy', clear
bysort sid: egen n_any_sh = count(st_share)
bysort sid: egen n_any_ct = count(an_k)
bysort sid: egen n_any_dr = count(dr_k)
bysort sid: egen n_any_ra = count(st_rall)
sort sid year

* F3: animal share, own y-axis per state (shows within-state
* variation; NM at 100% would otherwise flatten every panel);
* flagged series in a second color
twoway (line st_share year if !flagged & n_any_sh > 0, ///
            lcolor("$bdazzled_blue") ///
            cmissing(n)) ///
       (line st_share year if flagged & n_any_sh > 0, ///
            lcolor("$burnt_sienna") ///
            cmissing(n)), ///
    by(state, ///
       yrescale ///
       cols(6) ///
       note("") ///
       imargin(small) ///
       legend(pos(6)) ///
       graphregion(color(white))) ///
    yscale(range(0)) ///
    ylabel(#3, angle(0) labsize(small) glcolor(gs15)) ///
    xlabel(1985(10)2015, labsize(small)) ///
    ytitle("Animal share of all collisions (%)", size(medsmall)) ///
    xtitle("") ///
    legend(order(1 "Animal share" 2 "Flagged: NY, WV (deer > all-animal); NM (animal = all-cause)") ///
           rows(1) ///
           size(small) ///
           region(lcolor(none))) ///
    subtitle(, pos(11) fcolor(none) lcolor(none) size(medsmall)) ///
    xsize(11) ///
    ysize(8) ///
    name(f3, replace)
gexport f3 F3_state_animal_share figures

* F4: raw any_animal_total vs deer_total; deer above all-animal is
* impossible by construction, so crossings mark series problems
twoway (line an_k year if n_any_ct > 0 | n_any_dr > 0, ///
            lcolor("$bdazzled_blue") ///
            cmissing(n)) ///
       (line dr_k year if n_any_ct > 0 | n_any_dr > 0, ///
            lcolor("$burnt_sienna") ///
            lpattern(dash) ///
            cmissing(n)), ///
    by(state, ///
       yrescale ///
       cols(6) ///
       note("") ///
       imargin(small) ///
       legend(pos(6)) ///
       graphregion(color(white))) ///
    yscale(range(0)) ///
    ylabel(#3, angle(0) labsize(small) glcolor(gs15)) ///
    xlabel(1985(10)2015, labsize(small)) ///
    ytitle("Collisions (thousands)", size(medsmall)) ///
    xtitle("") ///
    legend(order(1 "All-animal (any_animal_total), as reported" 2 "Deer (deer_total)") ///
           rows(1) ///
           size(small) ///
           region(lcolor(none))) ///
    subtitle(, pos(11) fcolor(none) lcolor(none) size(medsmall)) ///
    xsize(11) ///
    ysize(8) ///
    name(f4, replace)
gexport f4 F4_state_animal_vs_deer_counts figures

* F5: all-cause rate, common y-axis
twoway line st_rall year if n_any_ra > 0, ///
    lcolor("$bdazzled_blue") ///
    cmissing(n) ///
    by(state, ///
       cols(6) ///
       note("") ///
       imargin(small) ///
       graphregion(color(white))) ///
    ylabel(, angle(0) labsize(small) glcolor(gs15)) ///
    xlabel(1985(10)2015, labsize(small)) ///
    ytitle("All-cause collisions per 1,000 residents", size(medsmall)) ///
    xtitle("") ///
    subtitle(, pos(11) fcolor(none) lcolor(none) size(medsmall)) ///
    xsize(11) ///
    ysize(8) ///
    name(f5, replace)
gexport f5 F5_state_allcause_rate figures

*---------------------------------------------------------------
* SECTION 7: COUNTY MAPS (M1-M4)
*---------------------------------------------------------------

* County means of annual values within each window. Full sample and
* decades need min_years observed years; the balanced sample needs
* every year of bal_y0-bal_y1.
use `panel', clear
keep if !missing(_ID)

* excl_states draw as "No data" (DECISION 3b)
gen double r_val = rate_animal_100k if !is_excluded
gen double s_val = share_animal     if !is_excluded

local tags     full bal d1990 d2000 d2010
local win_full  "`y_first' `y_last'"
local win_bal   "`bal_y0' `bal_y1'"
local win_d1990 "1990 1999"
local win_d2000 "2000 2009"
local win_d2010 "2010 2019"

foreach t of local tags {
    tokenize `win_`t''
    local need = cond("`t'" == "bal", `2' - `1' + 1, `min_years')
    foreach v in r s {
        gen double _x = `v'_val if inrange(year, `1', `2')
        bysort geoid: egen _nobs = count(_x)
        bysort geoid: egen double m_`v'_`t' = mean(_x)
        replace m_`v'_`t' = . if _nobs < `need'
        drop _x _nobs
    }
}
bysort geoid: keep if _n == 1
keep geoid m_*
tempfile cty_means
save `cty_means'

* Start from every CONUS county so non-reporting ones draw as "No data"
use "$shpSTATA/county_attr_conus.dta", clear
rename county_fips geoid
merge 1:1 geoid using `cty_means', keep(master match) nogenerate

local lab_full  "All years, `y_first'–`y_last'"
local lab_bal   "Balanced counties, `bal_y0'–`bal_y1'"
local lab_d1990 "1990–1999"
local lab_d2000 "2000–2009"
local lab_d2010 "2010–2019"

local pal_r  "YlOrRd"
local pal_s  "Blues"
local legt_r "Per 100,000 residents"
local legt_s "Animal share (%)"
local fig_r  "animal_rate"
local fig_s  "animal_share"
local m_a_r  "M1"
local m_b_r  "M2"
local m_a_s  "M3"
local m_b_s  "M4"

local mapbase `"id(_ID) ocolor(none ..) osize(none ..) ndocolor(none) ndfcolor(gs14) ndlabel("No data") polygon(data("$shpSTATA/us_state_shp_conus.dta") ocolor(black) osize(vthin)) legstyle(2) legjunction(" – ")"'

foreach v in r s {
    mapbreaks m_`v'_full m_`v'_bal m_`v'_d1990 m_`v'_d2000 m_`v'_d2010, ///
        pctiles(10 25 50 75 90 97.5)
    local br "`r(breaks)'"
    di as text "  `fig_`v'' class breaks: `br'"

    local g_a ""
    local g_b ""
    foreach t of local tags {
        quietly count if !missing(m_`v'_`t')
        local n_mapped = r(N)
        di as text "  m_`v'_`t': `n_mapped' counties"
        if `n_mapped' == 0 continue

        spmap m_`v'_`t' using "$shpSTATA/us_county_shp_conus.dta", ///
            `mapbase' ///
            clmethod(custom) ///
            clbreaks(`br') ///
            fcolor(`pal_`v'') ///
            legend(pos(4) ///
                   ring(1) ///
                   cols(1) ///
                   size(small) ///
                   region(lcolor(none)) ///
                   title("`legt_`v''", size(small) pos(11))) ///
            subtitle("`lab_`t''", size(medsmall)) ///
            name(map_`v'_`t', replace) ///
            nodraw

        if inlist("`t'", "full", "bal") local g_a "`g_a' map_`v'_`t'"
        else local g_b "`g_b' map_`v'_`t'"
    }

    if "`g_a'" != "" {
        graph combine `g_a', cols(2) imargin(tiny) xsize(10) ysize(3.7) $gw name(m_a_`v', replace)
        gexport m_a_`v' `m_a_`v''_`fig_`v''_full_vs_balanced maps
    }
    if "`g_b'" != "" {
        graph combine `g_b', cols(3) imargin(tiny) xsize(14) ysize(3.4) $gw name(m_b_`v', replace)
        gexport m_b_`v' `m_b_`v''_`fig_`v''_by_decade maps
    }
}

*---------------------------------------------------------------
* SECTION 8: SUMMARY STATISTICS (S1, S2)
*---------------------------------------------------------------

* S1: pooled, every collision count plus the derived outcomes
use `panel', clear
local s_vars total_total ///
             total_fatal ///
             total_fatalities ///
             total_injury ///
             total_injuries ///
             total_pdo ///
             any_animal_total ///
             any_animal_fatal ///
             any_animal_injury ///
             any_animal_pdo ///
             any_animal_fatalities ///
             any_animal_injuries ///
             animal_total ///
             wild_animal_total ///
             deer_total ///
             deer_fatal ///
             deer_injury ///
             deer_pdo ///
             any_animal_filled ///
             share_animal ///
             rate_all_1k ///
             rate_animal_100k

tempname ps
tempfile s1
postfile `ps' str32 variable N n_zero mean sd min p10 p50 p90 max using `s1'
foreach v of local s_vars {
    quietly summarize `v', detail
    if r(N) == 0 continue
    local s_N    = r(N)
    local s_mean = r(mean)
    local s_sd   = r(sd)
    local s_min  = r(min)
    local s_p10  = r(p10)
    local s_p50  = r(p50)
    local s_p90  = r(p90)
    local s_max  = r(max)
    quietly count if `v' == 0
    post `ps' ("`v'") (`s_N') (r(N)) (`s_mean') (`s_sd') (`s_min') ///
              (`s_p10') (`s_p50') (`s_p90') (`s_max')
}
postclose `ps'
use `s1', clear
export delimited using "$outDESC/tables/S1_pooled_summary.csv", replace

* S2: by state plus a pooled row, with numerator provenance and
* defect counts for the harmonization review
use `panel', clear
gen byte one = 1
bysort state geoid: gen byte first_cty = _n == 1
forvalues k = 1/4 {
    gen byte src`k' = num_source == `k'
}
tempfile s2in
save `s2in'

foreach lvl in state pooled {
    use `s2in', clear
    if "`lvl'" == "pooled" replace state = "Pooled"
    collapse (min) y0 = year ///
             (max) y1 = year ///
             (sum) n_rows = one ///
                   counties = first_cty ///
                   n_inversion = is_inversion ///
                   n_id_gap = is_id_gap ///
                   n_share_gt100 = is_share_gt100 ///
             (count) n_share = share_animal ///
                     n_rate = rate_animal_100k ///
             (mean) pct_native = src1 ///
                    pct_component = src2 ///
                    pct_deer_standin = src3 ///
                    pct_deer_floor = src4 ///
                    pct_zero_statewide = is_zero_sy ///
                    mean_total = total_total ///
                    mean_animal = any_animal_filled ///
                    mean_deer = deer_total ///
                    mean_share = share_animal ///
                    mean_rate_100k = rate_animal_100k ///
             (p50) med_share = share_animal ///
                   med_rate_100k = rate_animal_100k ///
             (sd) sd_share = share_animal, ///
             by(state)
    tempfile s2_`lvl'
    save `s2_`lvl''
}
use `s2_state', clear
append using `s2_pooled'
foreach v of varlist pct_* {
    replace `v' = 100 * `v'
}
assert n_rows == 60804 if state == "Pooled"
export delimited using "$outDESC/tables/S2_by_state_summary.csv", replace

log close
