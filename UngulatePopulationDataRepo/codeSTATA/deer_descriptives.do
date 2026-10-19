/*==============================================================================

FILE NAME:   deer_descriptives.do

PROJECT: Weather Changes, Ungulate Populations, & Vehicle Collisions --
	 Ungulate Population & DVC Panel --
	 Deer Descriptive Analysis

CURRENT LEAD: Nicole Martinez

PURPOSE:  Descriptive figures, maps, and summary-statistics tables for the
          national county-year deer harvest panel built by
          deer_harvest_national_append.do:

            F1  national harvest trends (fixed state sets + within-county
                year-effect index + states reporting)
            F2  national antlered vs antlerless harvest and antlerless share
            F3  state small multiples, total harvest
            F4  state small multiples, antlerless share
            F5  state small multiples, county harvest per sq mi (median, IQR)
            M1  county harvest per sq mi, early vs recent snapshots
            M2  county change in harvest between the snapshots
            M3  county antlerless share, early vs recent
            S1  summary statistics by state (harvest_total)
            S2  summary statistics by state (sex-class columns)
            S3  pooled summary statistics, every harvest variable, five samples

          Figure conventions follow Wendy's winter-weather descriptive report
          (09/11/2026) so the two read as a set: no titles baked into the
          images (captions and notes live in the LaTeX), map legends beside
          the map (outside it, so they never cover data), state borders in
          black, one shared color scale across

          DEER HARVEST ONLY. The national panel carries no population
          variables and no elk, turkey or moose for the time being, so the
	  population-vs-harvest exhibits (scatter, binscatter, county time
	  series) are stubbed in Section 7 -- see DECISION 1.

SOURCE FILES USED:

  $dataCLEAN/US_deer_harvest_county_year.dta
        -- output of deer_harvest_national_append.do (42,471 county-years,
           19 states). Its DECISIONS block is referred to below as
           "append DECISION n".

  Census 2018 cartographic boundary files, 1:20m (downloaded on first run
  into $dataRAW/Shapefiles/Census_cb_2018):
        cb_2018_us_county_20m.zip   -- county polygons + ALAND (land area)
        cb_2018_us_state_20m.zip    -- state outlines for the maps
        https://www2.census.gov/geo/tiger/GENZ2018/shp/

  Community packages (installed on first run if missing): ftools, reghdfe,
  spmap, geo2xy.

OUTPUT:

  $root/output/descriptives_deer/figures   F1-F5   (.pdf for Overleaf, .png for 
						                        slides)
  
  $root/output/descriptives_deer/maps      M1-M3   (.pdf, .png)
  
  $root/output/descriptives_deer/tables    S1-S3   (.tex booktabs + .csv),
                                           national_year_effects.csv

CHANGELOG:

10/08/2026 — Nicole: First pass. Header, setup block, section layout and assert 
                     discipline follow the per-state harmonization do files. 
		     NOT YET RUN.
		     
10/09/2026 — Nicole: Ran first pass. Bug fixes & ormatting pass. F1a legend 
                     moved off the data (it was hiding the lines above ~1,300k).
		     
10/12/2026 — Nicole: Formatting pass, no change to data values. F2 x-axis 
                     trimmed to 1980-2015.

10/15/2026 — Nicole: Formatting pass, no change to data values. F3-F5: legend
                     moved into the empty panel slot, state-name titles
                     enlarged, F3 panels forced to include zero. Maps:
                     legend moved outside the map, legend title via
                     legend(title()) (removes stray key), class breaks end
                     at the data min/max instead of +/-1000 placeholders.
                     S1 scaled to text width; S2 empty cells now "---".

==============================================================================
DECISIONS TAKEN IN THIS SCRIPT
==============================================================================

1. NO POPULATION, NO ELK / TURKEY / MOOSE.            

   US_deer_harvest_county_year.dta is a harvest panel only; append drops
   every population index by design. County-resolution population exists
   for MO (index 2002-2014), OH (pre-hunt index 1981-2014), WI (2014
   pre-hunt, 2015 post-hunt) and VA (2014 index, buck kill per sq mi of
   habitat -- an INDEX, not a count). 
   
   No elk, turkey or moose panel has been harmonized. Section 7 holds the 
   planned population exhibits as a placeholder to be filled once if the MO/OH 
   population files are re-merged.

2. NATIONAL TRENDS ARE NOT A RAW SUM.

   States enter and leave the panel at very different years (CA 1927-2009,
   DE 2010-2025, the CWD gap-fill states 2016-2021, ...), so a raw sum
   across all states is mostly a coverage series. F1 reports instead:
   
     (a) sums over two FIXED, BALANCED state sets -- 6 states 1980-2014
         (MD NC NY OH VA WI) and 8 states 1990-2014 (+ AR KY) -- with
         asserts to make sure they're balanced;
	 
     (b) a within-county index: exp(year effects) from ln(harvest) on county
         and year fixed effects, 2005 = 100, 95% CI clustered by county.
         County FE absorb level differences, so a state entering or leaving
         does not move the index directly. However, years with few states are
         estimated off those states alone, so (c) plots states reporting
         and years with fewer than 4 states are not drawn (2021 on: GA+NY,
         then NY+DE, then DE alone).
	 
3. IOWA 2001-2005 IS LEFT OUT OF THE TREND INDEX AND THE MAPS.

   Per append script DECISION 23, Iowa moved to mandatory harvest reporting in
   2006 and Iowa DNR says 2005-and-earlier estimates are not comparable
   with later years (statewide 207,504 in 2005 vs 150,552 in 2006). Left
   in, shows up as a large artificial decline in every Iowa county in
   any early-vs-recent comparison that starts in 2005. So:
   
     - excluded from the F1b index and from every map;
     
     - kept in the summary tables (S1-S3), where it is real data;
     
     - drawn DASHED in F3, so the break is visible rather than hidden.
     
   This is also why the main-window map pair starts in 2006, not 2005
   (DECISION 5).

4. PER-AREA INTENSITY USES CENSUS LAND AREA (ALAND), 2018 VINTAGE.

   harvest_per_mi2 = harvest_total / (ALAND in sq mi). Land area, not total
   area, so lake and coastal counties are not understated. The four VA
   units of append script DECISION 14 (51515, 51560, 51780, 51999) have no 2018
   county polygon and therefore no area: they get no per-area value and do
   not appear on the maps, but stay in the summary tables. Section 2
   asserts that these four are the ONLY unmatched units.

5. MAP WINDOWS.                                              

   Long run:     1985-1989 vs 2010-2014
   
   Main window:  2006-2008 vs 2012-2014
   
   Each county value is the mean over the window's observed years; a county
   needs >= 2 observed years in a window to be mapped. Wendy's weather
   maps use 10-winter windows (1982-91 vs 2016-25), but harvest coverage
   after 2014 is too thin for a 2016-25 window (DE FL GA IA MI MN NY WV
   only), so harvest snapshots end in 2014. CA leaves the panel after 2009
   and so appears only in the 1985-89 map; IN TN MO IA WV enter after 1989.

6. ANTLERLESS SHARE TAKES THE PANEL'S CLASSES AS GIVEN.

   antlerless_share = 100 * antlerless / (antlered + antlerless), unknown
   sex excluded, only where both classes exist. CA's antlerless is doe kill
   with blanks read as zero (append script DECISION 18), so CA's share sits near
   zero -- a real feature of California's restricted antlerless take, not
   a coding error, but it is not comparable with the other states. KY's
   antlerless is a residual (append script DECISION 17). F2 uses only MD NY OH 
   WI, the states with both classes in every year 1980-2014.

7. IMPUTED CWD ROWS ARE ALREADY OUT.

   append script DECISION 9 parks the Schuler et al. carried-forward values in
   harvest_total_cwd_imputed and leaves harvest_total missing. That is why
   FL IA MI MN have missing harvest_total in 2021 (every 2021 row in those
   states is imputed-only). Nothing to do here; noted so the gaps in F3 are
   not mistaken for a bug.

==============================================================================*/

*==============================================================================
* SECTION 0: SETUP
*==============================================================================

clear all
set more off
set varabbrev off
version 16.1

capture log close

global root "/mnt/data_d/Dropbox/Research/UngulatePopulationDataRepo"
global dataRAW   "$root/dataRAW"
global dataSTATA "$root/dataSTATA"
global dataCLEAN "$root/dataCLEAN"
global codeSTATA "$root/codeSTATA"

* -- descriptives-specific paths
global shpRAW    "$dataRAW/Shapefiles/Census_cb_2018"
global shpSTATA  "$dataSTATA/_shapefiles"
global outDESC   "$root/output/descriptives_deer"

di "$root"
di "$dataCLEAN"

cap mkdir "$codeSTATA/logs"
log using "$codeSTATA/logs/deer_descriptives.log", replace text

cap mkdir "$dataRAW/Shapefiles"
cap mkdir "$shpRAW"
cap mkdir "$shpSTATA"
cap mkdir "$root/output"
cap mkdir "$outDESC"
cap mkdir "$outDESC/figures"
cap mkdir "$outDESC/maps"
cap mkdir "$outDESC/tables"

* -- fail early and loudly if the input panel is not where we expect
capture confirm file "$dataCLEAN/US_deer_harvest_county_year.dta"
if _rc {
    display as error "not found: $dataCLEAN/US_deer_harvest_county_year.dta -- run deer_harvest_national_append.do first"
    exit 601
}

* -- community packages. reghdfe needs ftools.
foreach p in ftools reghdfe spmap geo2xy {
    capture which `p'
    if _rc ssc install `p', replace
}

* -- graph defaults. Colors: blue = agency-direct / antlered / main series,
*    orange = CWD gap-fill / antlerless / second series.
set scheme s1color
global c1 "42 120 214"
global c2 "235 104 52"
global gw "graphregion(color(white)) plotregion(color(white))"

* -- export helper: vector PDF for Overleaf, PNG for slides
capture program drop gexport
program define gexport
    args name sub
    graph export "$outDESC/`sub'/`name'.pdf", replace
    graph export "$outDESC/`sub'/`name'.png", replace width(2400)
end

* -- LaTeX end-of-row, built from char(92) so Stata's backslash handling
*    never touches it
local eol = char(92) + char(92)

*==============================================================================
* SECTION 1: COUNTY & STATE BOUNDARIES
*==============================================================================

/*------------------------------------------------------------------------

Census 2018 cartographic boundary files (1:20m), downloaded into $shpRAW and 
converted to Stata format in $shpSTATA. The 2018 vintage has no Bedford city VA 
(merged into Bedford County 2013), which matches the panel's current-county 
convention (append DECISION 14).

Two outputs per geography:

  us_<g>.dta           attribute table, one row per polygon (_ID key)
  
  us_<g>_shp.dta       coordinates (_ID _X _Y), what spmap draws

Contiguous US only (AK, HI and the territories dropped), projected to an
Albers equal-area conic with geo2xy: same parameters for counties and
states, so the state borders sit exactly on the county edges.

unzipfile extracts into the current directory, hence the cd; the working
directory is restored at the end of the section.

------------------------------------------------------------------------*/

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

*-------- 1a. Contiguous US, projected coordinates ---------------------------

foreach g in county state {
    use "$shpSTATA/us_`g'.dta", clear
    generate byte conus = !inlist(STATEFP, "02", "15", "60", "66", "69", "72", "78")
    keep _ID conus
    tempfile _keep_`g'
    save `_keep_`g''

    use "$shpSTATA/us_`g'_shp.dta", clear
    merge m:1 _ID using `_keep_`g'', nogenerate assert(match)
    keep if conus == 1
    drop conus
    geo2xy _Y _X, projection(albers) replace
    sort _ID shape_order
    save "$shpSTATA/us_`g'_shp_conus.dta", replace
}

*-------- 1b. County attribute file: FIPS key + land area --------------------

use "$shpSTATA/us_county.dta", clear
keep if !inlist(STATEFP, "02", "15", "60", "66", "69", "72", "78")
rename GEOID county_fips
generate double land_mi2 = ALAND / 2589988.11
keep _ID county_fips STATEFP NAME land_mi2

isid county_fips
assert land_mi2 > 0 & !missing(land_mi2)
count
* contiguous US + DC, 2018 vintage
assert r(N) == 3108

label variable county_fips "5-digit county FIPS code (Census GEOID, 2018)"
label variable land_mi2    "County land area, sq mi (Census ALAND, 2018)"
label data "CONUS county attributes for mapping (Census cb 2018 1:20m)"

save "$shpSTATA/county_attr_conus.dta", replace

*==============================================================================
* SECTION 2: LOAD PANEL & DERIVED VARIABLES
*==============================================================================

/*------------------------------------------------------------------------

Pins the panel to the vintage this script was written against (10/08/2026). The 
agency-direct figures are asserted (they reproduce the data section exactly); 
the CWD-dependent ones are reported, following append Section 4.

------------------------------------------------------------------------*/

use "$dataCLEAN/US_deer_harvest_county_year.dta", clear

isid county_fips year
count
local _N = r(N)
count if source_harvest == "agency"
assert r(N) == 38660
quietly count if main_sample
display as text "  panel: `_N' county-years; main_sample: " r(N) " (expected 42,471 / 11,190)"
codebook, compact

*-------- 2a. Land area from the boundary file (DECISION 4) ------------------

merge m:1 county_fips using "$shpSTATA/county_attr_conus.dta", ///
    keepusing(_ID land_mi2) keep(master match) gen(_merge_area)
* Expected unmatched: exactly the four VA units of append DECISION 14.
tabulate county_fips if _merge_area == 1
assert inlist(county_fips, "51515", "51560", "51780", "51999") if _merge_area == 1
drop _merge_area

generate double harvest_per_mi2 = harvest_total / land_mi2

*-------- 2b. Iowa pre-mandatory-reporting years (DECISION 3) ----------------

generate byte ia_prereport = (state == "IA" & year <= 2005)
count if ia_prereport & !missing(harvest_total)
display as text "  IA 2001-2005 county-years (excluded from index and maps): " r(N)

*-------- 2c. Antlerless share (DECISION 6) ---------------------------------

generate double antlerless_share = 100 * harvest_antlerless / ///
    (harvest_antlered + harvest_antlerless) ///
    if (harvest_antlered + harvest_antlerless) > 0
assert inrange(antlerless_share, 0, 100) if !missing(antlerless_share)

generate byte cwd = (source_harvest == "cwd")
encode state, gen(sid)

label variable harvest_per_mi2  "Deer harvested per sq mi of land area (Census 2018 ALAND)"
label variable ia_prereport     "=1 if IA 2001-2005 (before mandatory reporting; not comparable)"
label variable antlerless_share "Antlerless / (antlered + antlerless), percent"
label variable cwd              "=1 if CWD gap-fill state (Schuler et al.)"

summarize harvest_total harvest_per_mi2 antlerless_share

tempfile panel
save `panel'

*-------- 2d. State-year totals ---------------------------------------------

/*
collapse (sum) treats missing as 0, so an all-missing state-year would come
out as a 0 total. Count non-missing alongside and blank those.
*/

generate double h_trend = harvest_total if !ia_prereport

collapse (sum) h = harvest_total h_tr = h_trend al = harvest_antlered ///
               anl = harvest_antlerless ///
         (count) n_h = harvest_total n_tr = h_trend n_al = harvest_antlered ///
               n_anl = harvest_antlerless ///
         (max) cwd, by(state year)
replace h    = . if n_h   == 0
replace h_tr = . if n_tr  == 0
replace al   = . if n_al  == 0
replace anl  = . if n_anl == 0
drop n_*

isid state year
tempfile sy
save `sy'

*==============================================================================
* SECTION 3: NATIONAL TRENDS (F1, F2)
*==============================================================================

display as text _newline "{hline 78}"
display as text "SECTION 3: national trends"
display as text "{hline 78}"

*-------- 3a. Fixed, balanced state sets (DECISION 2a) ----------------------

foreach s in 6 8 {
    use `sy', clear
    if `s' == 6 keep if inlist(state, "MD", "NC", "NY", "OH", "VA", "WI") & inrange(year, 1980, 2014)
    if `s' == 8 keep if inlist(state, "AR", "KY", "MD", "NC", "NY", "OH", "VA", "WI") & inrange(year, 1990, 2014)
    * the set must really be balanced, or the line is a coverage series again
    assert !missing(h)
    bysort year: assert _N == `s'
    collapse (sum) agg`s' = h, by(year)
    replace agg`s' = agg`s' / 1000
    tempfile _a`s'
    save `_a`s''
}
use `_a6', clear
merge 1:1 year using `_a8', nogenerate

twoway (line agg6 year, lcolor("$c1") lwidth(medthick)) ///
       (line agg8 year, lcolor("$c2") lwidth(medthick)), ///
    ytitle("Deer harvested (thousands)") xtitle("") ///
    ylabel(0(250)1750, angle(0) glcolor(gs15)) xlabel(1960(10)2020) xscale(range(1959 2021)) ///
    legend(order(1 "6 states (MD NC NY OH VA WI), 1980–2014" 2 "8 states (+ AR, KY), 1990–2014") ///
           pos(5) ring(0) cols(1) region(lcolor(none) fcolor(none)) size(small)) ///
    subtitle("a. Total reported harvest, fixed state sets", pos(11) size(medsmall)) ///
    $gw name(f1a, replace) nodraw

*-------- 3b. Within-county year-effect index (DECISIONS 2b, 3) --------------

use `panel', clear
keep if year >= 1960 & harvest_total > 0 & !missing(harvest_total) ///
    & !ia_prereport & county_fips != "51999"
generate double lnh = ln(harvest_total)
egen long cty = group(county_fips)

reghdfe lnh ib2005.year, absorb(cty) vce(cluster cty)

levelsof year, local(_yrs)
tempname pf
tempfile ye
postfile `pf' year b se using `ye'
foreach y of local _yrs {
    if `y' == 2005 post `pf' (`y') (0) (0)
    else           post `pf' (`y') (_b[`y'.year]) (_se[`y'.year])
}
postclose `pf'

* states reporting, per year
use `sy', clear
keep if !missing(h)
collapse (count) n_states = h, by(year)
tempfile ns
save `ns'

use `ye', clear
merge 1:1 year using `ns', keep(master match) nogenerate
generate double idx = 100 * exp(b)
generate double lo  = 100 * exp(b - 1.96 * se)
generate double hi  = 100 * exp(b + 1.96 * se)
export delimited using "$outDESC/tables/national_year_effects.csv", replace

* years with fewer than 4 states are not drawn (DECISION 2)
keep if n_states >= 4

twoway (rarea hi lo year, color("$c1%20") lwidth(none)) ///
       (line idx year, lcolor("$c1") lwidth(medthick)), ///
    yscale(log) ylabel(10 20 50 100 200, angle(0) glcolor(gs15)) ///
    yline(100, lpattern(dash) lcolor(gs10)) ///
    ytitle("Index (2005 = 100, log scale)") xtitle("") ///
    xlabel(1960(10)2020) xscale(range(1959 2021)) legend(off) ///
    subtitle("b. Within-county harvest index, all states", pos(11) size(medsmall)) ///
    $gw name(f1b, replace) nodraw

*-------- 3c. States reporting ----------------------------------------------

use `ns', clear
keep if year >= 1960
twoway bar n_states year, barwidth(0.8) color(gs10) ///
    ytitle("States") xtitle("Season start year") ///
    ylabel(0(5)15, angle(0) glcolor(gs15)) ///
    xlabel(1960(10)2020) xscale(range(1959 2021)) ///
    subtitle("c. States reporting", pos(11) size(medsmall)) fysize(30) ///
    $gw name(f1c, replace) nodraw

graph combine f1a f1b f1c, cols(1) xcommon imargin(small) xsize(7) ysize(9) $gw
gexport F1_national_deer_harvest figures

*-------- 3d. F2: antlered vs antlerless, MD + NY + OH + WI (DECISION 6) -----

use `sy', clear
keep if inlist(state, "MD", "NY", "OH", "WI") & inrange(year, 1980, 2014)
assert !missing(al) & !missing(anl)
bysort year: assert _N == 4
collapse (sum) al anl, by(year)
generate double share = 100 * anl / (al + anl)
replace al  = al  / 1000
replace anl = anl / 1000

twoway (line al  year, lcolor("$c1") lwidth(medthick)) ///
       (line anl year, lcolor("$c2") lwidth(medthick)), ///
    ytitle("Deer harvested (thousands)") xtitle("") ylabel(0(100)700, angle(0) glcolor(gs15)) ///
    xlabel(1980(5)2015) xscale(range(1979 2015)) ///
    legend(order(1 "Antlered" 2 "Antlerless") pos(11) ring(0) cols(1) ///
           region(lcolor(none)) size(small)) ///
    subtitle("a. Harvest by sex class, MD + NY + OH + WI", pos(11) size(medsmall)) ///
    $gw name(f2a, replace) nodraw
twoway line share year, lcolor(gs6) lwidth(medthick) ///
    ytitle("Percent antlerless") xtitle("Season start year") ///
    ylabel(, angle(0) glcolor(gs15)) ///
    xlabel(1980(5)2015) xscale(range(1979 2015)) ///
    subtitle("b. Antlerless share of antlered + antlerless harvest", pos(11) size(medsmall)) ///
    $gw name(f2b, replace) nodraw

graph combine f2a f2b, cols(1) xcommon imargin(small) xsize(7) ysize(6) $gw
gexport F2_national_sexclass figures

*==============================================================================
* SECTION 4: STATE SMALL MULTIPLES (F3, F4, F5)
*==============================================================================

/*------------------------------------------------------------------------

One panel per state, shared x-axis (so each state's coverage is visible),
free y-axis. tsfill + cmissing(n) so a gap in coverage (DE 2016-2021, the
2021 imputed-only rows of DECISION 7) breaks the line instead of being
bridged.

------------------------------------------------------------------------*/

display as text _newline "{hline 78}"
display as text "SECTION 4: state small multiples"
display as text "{hline 78}"

use `sy', clear
encode state, gen(sid)
xtset sid year
tsfill
bysort sid (cwd): replace cwd = cwd[1]
bysort sid (year): replace state = state[_n-1] if state == ""

generate double hk     = h_tr / 1000
* IA 2001-2005 drawn separately, dashed (DECISION 3)
generate double hk_ia  = h / 1000 if state == "IA" & year <= 2006
bysort sid: egen nobs = count(hk)

*-------- 4a. F3: total harvest ---------------------------------------------

twoway (line hk    year if !cwd, lcolor("$c1") cmissing(n)) ///
       (line hk    year if  cwd, lcolor("$c2") cmissing(n)) ///
       (line hk_ia year,         lcolor("$c2") lpattern(dash) cmissing(n)) ///
       (scatter hk year if !cwd & nobs <= 6, mcolor("$c1") msize(vsmall)) ///
       (scatter hk year if  cwd & nobs <= 6, mcolor("$c2") msize(vsmall)), ///
    by(state, yrescale cols(5) note("") imargin(small) ///
       graphregion(color(white)) legend(at(20) pos(0))) ///
    xline(2005 2014, lpattern(shortdash) lcolor(gs12)) ///
    xlabel(1940(40)2020, labsize(small)) ///
    yscale(range(0)) ylabel(#3, angle(0) labsize(small) glcolor(gs15)) ///
    ytitle("Deer harvested (thousands)", size(medsmall)) xtitle("") ///
    legend(order(1 "Agency-direct" 2 "CWD gap-fill" ///
                 3 "IA, pre-2006") ///
           cols(1) size(small) symxsize(*0.6) region(lcolor(none))) ///
    subtitle(, pos(11) fcolor(none) lcolor(none) size(medsmall)) ///
    xsize(10) ysize(7.5)
gexport F3_state_total_harvest figures

*-------- 4b. F4: antlerless share (DECISION 6) -----------------------------

generate double share = 100 * anl / (al + anl) ///
    if !missing(al) & !missing(anl) & (al + anl) > 0
bysort sid: egen any_share = count(share)

twoway line share year if any_share > 0, lcolor("$c1") cmissing(n) ///
    by(state, cols(4) note("") imargin(small) graphregion(color(white))) ///
    xline(2005 2014, lpattern(shortdash) lcolor(gs12)) ///
    yscale(range(0 100)) ylabel(0(25)100, angle(0) labsize(small) glcolor(gs15)) ///
    xlabel(1940(40)2020, labsize(small)) ///
    ytitle("Percent antlerless", size(medsmall)) xtitle("") ///
    subtitle(, pos(11) fcolor(none) lcolor(none) size(medsmall)) xsize(9) ysize(7)
gexport F4_state_antlerless_share figures

*-------- 4c. F5: county intensity within state (median, IQR) ---------------

use `panel', clear
keep if !missing(harvest_per_mi2) & !ia_prereport
collapse (p25) q25 = harvest_per_mi2 (p50) q50 = harvest_per_mi2 ///
         (p75) q75 = harvest_per_mi2 (max) cwd, by(sid state year)
xtset sid year
tsfill
bysort sid (cwd): replace cwd = cwd[1]
bysort sid (year): replace state = state[_n-1] if state == ""

twoway (rarea q75 q25 year if !cwd, color("$c1%25") lwidth(none) cmissing(n)) ///
       (rarea q75 q25 year if  cwd, color("$c2%25") lwidth(none) cmissing(n)) ///
       (line q50 year if !cwd, lcolor("$c1") cmissing(n)) ///
       (line q50 year if  cwd, lcolor("$c2") cmissing(n)), ///
    by(state, cols(5) note("") imargin(small) graphregion(color(white)) ///
       legend(at(20) pos(0))) ///
    xlabel(1940(40)2020, labsize(small)) ///
    ylabel(0(4)16, angle(0) labsize(small) glcolor(gs15)) ///
    ytitle("Deer harvested per sq mi (median, IQR)", size(medsmall)) xtitle("") ///
    legend(order(3 "Agency-direct" 4 "CWD gap-fill") cols(1) size(small) ///
           symxsize(*0.6) region(lcolor(none))) ///
    subtitle(, pos(11) fcolor(none) lcolor(none) size(medsmall)) xsize(10) ysize(7.5)
gexport F5_state_county_intensity figures

*==============================================================================
* SECTION 5: CHOROPLETH MAPS (M1, M2, M3)
*==============================================================================

/*------------------------------------------------------------------------

County means over each window (DECISION 5): 1985-89 / 2010-14 (long run)
and 2006-08 / 2012-14 (main window). A county needs >= 2 observed years in
a window. The four VA units without a polygon (DECISION 4) and IA 2001-
2005 (DECISION 3) are out.

The map dataset starts from the full CONUS county list, so counties with no
harvest data draw in light grey ("No data") rather than vanishing.

------------------------------------------------------------------------*/

display as text _newline "{hline 78}"
display as text "SECTION 5: maps"
display as text "{hline 78}"

use `panel', clear
keep if !missing(_ID) & !ia_prereport

foreach p in "1985 1989" "2010 2014" "2006 2008" "2012 2014" {
    tokenize `p'
    local tag `1'_`2'
    foreach v in harvest_per_mi2 harvest_total antlerless_share {
        generate double _x = `v' if inrange(year, `1', `2')
        bysort county_fips: egen _nobs = count(_x)
        bysort county_fips: egen double m_`v'_`tag' = mean(_x)
        replace m_`v'_`tag' = . if _nobs < 2
        drop _x _nobs
    }
}
bysort county_fips: keep if _n == 1
keep county_fips m_*
tempfile pm
save `pm'

use "$shpSTATA/county_attr_conus.dta", clear
merge 1:1 county_fips using `pm', keep(master match) nogenerate

* change in log points (approx. percent); both windows must be positive
generate double chg_long = 100 * ln(m_harvest_total_2010_2014 / m_harvest_total_1985_1989) ///
    if m_harvest_total_1985_1989 > 0 & m_harvest_total_2010_2014 > 0 ///
     & !missing(m_harvest_total_1985_1989, m_harvest_total_2010_2014)
generate double chg_win = 100 * ln(m_harvest_total_2012_2014 / m_harvest_total_2006_2008) ///
    if m_harvest_total_2006_2008 > 0 & m_harvest_total_2012_2014 > 0 ///
     & !missing(m_harvest_total_2006_2008, m_harvest_total_2012_2014)

* counties mapped, per window (into the log, for the caption notes)
foreach v of varlist m_harvest_per_mi2_* chg_long chg_win {
    quietly count if !missing(`v')
    display as text "  `v': " r(N) " counties"
}

* -- legend end-points come from the data, so the top/bottom classes read
*    e.g. "9.0 – 25.0" rather than "9 – 1000"
local m1top = 0
foreach v of varlist m_harvest_per_mi2_* {
    quietly summarize `v'
    local m1top = max(`m1top', ceil(r(max)))
}
local chglo = 0
local chghi = 0
foreach v in chg_long chg_win {
    quietly summarize `v'
    local chglo = min(`chglo', floor(r(min)))
    local chghi = max(`chghi', ceil(r(max)))
}
* the fixed inner breaks must sit strictly inside the data range
assert `m1top' > 9
assert `chglo' < -50 & `chghi' > 50
display as text "  map class limits: per sq mi top `m1top'; change `chglo' to `chghi'"

local mapbase `"id(_ID) ocolor(none ..) osize(none ..) ndocolor(none) ndfcolor(gs14) ndlabel("No data") polygon(data("$shpSTATA/us_state_shp_conus.dta") ocolor(black) osize(vthin)) legstyle(2) legjunction(" – ")"'

*-------- 5a. M1: harvest per sq mi, one class scheme for all four ----------

local k = 0
foreach p in 1985_1989 2010_2014 2006_2008 2012_2014 {
    local ++k
    local lab = subinstr("`p'", "_", "–", 1)
    spmap m_harvest_per_mi2_`p' using "$shpSTATA/us_county_shp_conus.dta", `mapbase' ///
        clmethod(custom) clbreaks(0 0.5 1 2 4 6 9 `m1top') fcolor(Blues) ///
        legend(pos(4) ring(1) cols(1) size(small) region(lcolor(none)) ///
               title("Deer per sq mi", size(small) pos(11))) ///
        subtitle("`lab' average", size(medsmall)) ///
        name(m1_`k', replace) nodraw
}
graph combine m1_1 m1_2 m1_3 m1_4, cols(2) imargin(tiny) xsize(10) ysize(6.6) $gw
gexport M1_harvest_intensity_snapshots maps

*-------- 5b. M2: change, diverging red (decline) / blue (increase) ---------

spmap chg_long using "$shpSTATA/us_county_shp_conus.dta", `mapbase' ///
    clmethod(custom) clbreaks(`chglo' -50 -25 -10 10 25 50 `chghi') fcolor(RdBu) ///
    legend(pos(4) ring(1) cols(1) size(small) region(lcolor(none)) ///
           title("Change (log pts)", size(small) pos(11))) ///
    subtitle("1985–89 to 2010–14", size(medsmall)) ///
    name(m2_1, replace) nodraw
spmap chg_win using "$shpSTATA/us_county_shp_conus.dta", `mapbase' ///
    clmethod(custom) clbreaks(`chglo' -50 -25 -10 10 25 50 `chghi') fcolor(RdBu) ///
    legend(pos(4) ring(1) cols(1) size(small) region(lcolor(none)) ///
           title("Change (log pts)", size(small) pos(11))) ///
    subtitle("2006–08 to 2012–14", size(medsmall)) ///
    name(m2_2, replace) nodraw
graph combine m2_1 m2_2, cols(2) imargin(tiny) xsize(10) ysize(3.7) $gw
gexport M2_harvest_change maps

*-------- 5c. M3: antlerless share (DECISION 6) -----------------------------

spmap m_antlerless_share_1985_1989 using "$shpSTATA/us_county_shp_conus.dta", `mapbase' ///
    clmethod(custom) clbreaks(0 30 40 50 60 70 100) fcolor(Blues) ///
    legend(pos(4) ring(1) cols(1) size(small) region(lcolor(none)) ///
           title("% antlerless", size(small) pos(11))) ///
    subtitle("1985–1989 average", size(medsmall)) ///
    name(m3_1, replace) nodraw
spmap m_antlerless_share_2010_2014 using "$shpSTATA/us_county_shp_conus.dta", `mapbase' ///
    clmethod(custom) clbreaks(0 30 40 50 60 70 100) fcolor(Blues) ///
    legend(pos(4) ring(1) cols(1) size(small) region(lcolor(none)) ///
           title("% antlerless", size(small) pos(11))) ///
    subtitle("2010–2014 average", size(medsmall)) ///
    name(m3_2, replace) nodraw
graph combine m3_1 m3_2, cols(2) imargin(tiny) xsize(10) ysize(3.7) $gw
gexport M3_antlerless_share maps

*==============================================================================
* SECTION 6: SUMMARY-STATISTICS TABLES (S1, S2, S3)
*==============================================================================

/*------------------------------------------------------------------------

Each table is written twice: .csv (for checking) and .tex (booktabs, for
Overleaf; needs \usepackage{booktabs}). The .tex is written line by line
with -file write- rather than esttab, so no extra package is needed and
the layout is fully under our control. IA 2001-2005 stays IN the tables
(DECISION 3): it is real data, just not comparable over time.

------------------------------------------------------------------------*/

display as text _newline "{hline 78}"
display as text "SECTION 6: summary tables"
display as text "{hline 78}"

*-------- 6a. S1: total harvest by state, plus a pooled row -----------------

use `panel', clear
generate byte zero = (harvest_total == 0) if !missing(harvest_total)
generate byte miss = missing(harvest_total)
bysort state county_fips: generate byte first_cty = (_n == 1)
tempfile _s1in
save `_s1in'

foreach lvl in state pooled {
    use `_s1in', clear
    if "`lvl'" == "pooled" replace state = "Pooled"
    collapse (min) y0 = year (max) y1 = year cwd ///
             (sum) counties = first_cty main_n = main_sample ///
             (count) N = harvest_total ///
             (mean) mean = harvest_total permi2 = harvest_per_mi2 pzero = zero pmiss = miss ///
             (sd) sd = harvest_total ///
             (p10) p10 = harvest_total (p50) p50 = harvest_total (p90) p90 = harvest_total ///
             (max) max = harvest_total, by(state)
    tempfile _s1_`lvl'
    save `_s1_`lvl''
}
use `_s1_state', clear
count
assert r(N) == 19
append using `_s1_pooled'
generate source = cond(cwd == 1, "CWD", "Agency")
replace source = "" if state == "Pooled"
replace pzero = 100 * pzero
replace pmiss = 100 * pmiss
generate years = string(y0) + "--" + string(y1)
order state source years counties N mean sd p10 p50 p90 max permi2 pzero pmiss main_n
* pooled row must reproduce the panel
assert N == 42099 if state == "Pooled"
export delimited using "$outDESC/tables/S1_total_harvest_by_state.csv", replace

file open fh using "$outDESC/tables/S1_total_harvest_by_state.tex", write replace
file write fh "\begin{table}[htbp]\centering" _n ///
    "\caption{Deer harvest summary statistics by state (county-year)}" _n ///
    "\label{tab:deer-sumstats-state}" _n ///
    "\footnotesize\setlength{\tabcolsep}{3.5pt}" _n ///
    "\resizebox{\linewidth}{!}{%" _n ///
    "\begin{tabular}{@{}llcrrrrrrrrrr@{}}" _n "\toprule" _n ///
    "State & Source & Years & Counties & N & Mean & SD & P10 & Median & P90 & Max & Per sq mi & \% zero `eol'" _n ///
    "\midrule" _n
forvalues i = 1/`=_N' {
    if state[`i'] == "Pooled" file write fh "\midrule" _n
    file write fh (state[`i']) " & " (source[`i']) " & " (years[`i']) ///
        " & " %9.0fc (counties[`i']) " & " %9.0fc (N[`i']) " & " %9.0fc (mean[`i']) ///
        " & " %9.0fc (sd[`i']) " & " %9.0fc (p10[`i']) " & " %9.0fc (p50[`i']) ///
        " & " %9.0fc (p90[`i']) " & " %9.0fc (max[`i']) " & " %5.2f (permi2[`i']) ///
        " & " %5.1f (pzero[`i']) " `eol'" _n
}
file write fh "\bottomrule" _n "\end{tabular}}" _n ///
    "\begin{minipage}{\linewidth}\vspace{4pt}\scriptsize" _n ///
    "\emph{Notes:} Unit is the county-year; statistics are for \texttt{harvest\_total} over non-missing county-years. " ///
    "Per sq mi divides by Census land area (2018 cartographic boundaries); the four Virginia units with no current county " ///
    "polygon (FIPS 51515, 51560, 51780, 51999) are excluded from that column. CA's total is buck plus doe kill, which treat " ///
    "Private Lands Management take asymmetrically. Iowa 2001--2005 predates mandatory reporting and is not comparable with " ///
    "later years. CWD = Schuler et al.\ gap-fill panel." _n ///
    "\end{minipage}" _n "\end{table}" _n
file close fh

*-------- 6b. S2: sex-class columns by state --------------------------------

foreach lvl in state pooled {
    use `panel', clear
    if "`lvl'" == "pooled" replace state = "Pooled"
    collapse (count) n_al = harvest_antlered n_anl = harvest_antlerless ///
                     n_f = harvest_female n_u = harvest_unknown_sex ///
             (mean)  m_al = harvest_antlered m_anl = harvest_antlerless ///
                     m_f = harvest_female m_u = harvest_unknown_sex ///
                     share = antlerless_share, by(state)
    tempfile _s2_`lvl'
    save `_s2_`lvl''
}
use `_s2_state', clear
append using `_s2_pooled'
export delimited using "$outDESC/tables/S2_sexclass_by_state.csv", replace

file open fh using "$outDESC/tables/S2_sexclass_by_state.tex", write replace
file write fh "\begin{table}[htbp]\centering" _n ///
    "\caption{Sex-class harvest variables by state: observations and means}" _n ///
    "\label{tab:deer-sumstats-sexclass}" _n ///
    "\footnotesize\setlength{\tabcolsep}{4pt}" _n ///
    "\begin{tabular}{@{}lrrrrrrrrr@{}}" _n "\toprule" _n ///
    " & \multicolumn{2}{c}{Antlered} & \multicolumn{2}{c}{Antlerless} & \multicolumn{2}{c}{Female} & \multicolumn{2}{c}{Unknown} & Antlerless `eol'" _n ///
    "\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-7}\cmidrule(lr){8-9}" _n ///
    "State & N & Mean & N & Mean & N & Mean & N & Mean & share (\%) `eol'" _n ///
    "\midrule" _n
forvalues i = 1/`=_N' {
    if state[`i'] == "Pooled" file write fh "\midrule" _n
    file write fh (state[`i'])
    foreach v in al anl f u {
        if n_`v'[`i'] == 0 file write fh " & \multicolumn{2}{c}{---}"
        else file write fh " & " %9.0fc (n_`v'[`i']) " & " %9.0fc (m_`v'[`i'])
    }
    if missing(share[`i']) file write fh " & --- `eol'" _n
    else file write fh " & " %5.1f (share[`i']) " `eol'" _n
}
file write fh "\bottomrule" _n "\end{tabular}" _n ///
    "\begin{minipage}{\linewidth}\vspace{4pt}\scriptsize" _n ///
    "\emph{Notes:} Antlerless = all females plus male fawns/button bucks; female includes doe fawns; unknown-sex deer " ///
    "are in neither class (append DECISION 15). Antlerless share = antlerless / (antlered + antlerless), county-year mean. " ///
    "CA antlerless is doe kill with blanks read as zero; KY and DE 2010--2015 antlerless are residuals (total minus antlered)." _n ///
    "\end{minipage}" _n "\end{table}" _n
file close fh

*-------- 6c. S3: pooled, every harvest variable, five samples --------------

use `panel', clear
generate byte s_full   = 1
generate byte s_agency = (source_harvest == "agency")
generate byte s_cwd    = (source_harvest == "cwd")
generate byte s_main   = (main_sample == 1)
generate byte s_mainag = (main_sample_agency == 1)
local lab_full   "Full panel"
local lab_agency "Agency-direct"
local lab_cwd    "CWD gap-fill"
local lab_main   "Main sample (balanced 2005--2014)"
local lab_mainag "Main sample, agency only"
local vars harvest_total harvest_antlered harvest_antlerless harvest_female ///
           harvest_female_adult harvest_unknown_sex harvest_per_mi2 antlerless_share

tempname ps
tempfile s3
postfile `ps' str40 sample str40 variable N mean sd min p10 p50 p90 max using `s3'
foreach smp in full agency cwd main mainag {
    foreach v of local vars {
        quietly summarize `v' if s_`smp' == 1, detail
        if r(N) == 0 continue
        post `ps' ("`lab_`smp''") ("`v'") (r(N)) (r(mean)) (r(sd)) (r(min)) ///
                  (r(p10)) (r(p50)) (r(p90)) (r(max))
    }
}
postclose `ps'
use `s3', clear
export delimited using "$outDESC/tables/S3_pooled_summary.csv", replace

generate vlab = ""
replace vlab = "Total harvest"           if variable == "harvest_total"
replace vlab = "Antlered"                if variable == "harvest_antlered"
replace vlab = "Antlerless"              if variable == "harvest_antlerless"
replace vlab = "Female (all ages)"       if variable == "harvest_female"
replace vlab = "Adult female (NY)"       if variable == "harvest_female_adult"
replace vlab = "Unknown sex"             if variable == "harvest_unknown_sex"
replace vlab = "Total harvest per sq mi" if variable == "harvest_per_mi2"
replace vlab = "Antlerless share (\%)"   if variable == "antlerless_share"
assert vlab != ""

file open fh using "$outDESC/tables/S3_pooled_summary.tex", write replace
file write fh "\begin{table}[htbp]\centering" _n ///
    "\caption{Pooled summary statistics, deer harvest variables}" _n ///
    "\label{tab:deer-sumstats-pooled}" _n ///
    "\footnotesize\setlength{\tabcolsep}{4pt}" _n ///
    "\begin{tabular}{@{}lrrrrrrr@{}}" _n "\toprule" _n ///
    "Variable & N & Mean & SD & P10 & Median & P90 & Max `eol'" _n
forvalues i = 1/`=_N' {
    if `i' == 1 | sample[`i'] != sample[`i'-1] {
        file write fh "\midrule" _n "\multicolumn{8}{@{}l}{\emph{" (sample[`i']) "}} `eol'" _n
    }
    local f "%9.0fc"
    if variable[`i'] == "harvest_per_mi2"  local f "%9.2f"
    if variable[`i'] == "antlerless_share" local f "%9.1f"
    file write fh "\quad " (vlab[`i']) " & " %9.0fc (N[`i']) ///
        " & " `f' (mean[`i']) " & " `f' (sd[`i']) " & " `f' (p10[`i']) ///
        " & " `f' (p50[`i']) " & " `f' (p90[`i']) " & " `f' (max[`i']) " `eol'" _n
}
file write fh "\bottomrule" _n "\end{tabular}" _n ///
    "\begin{minipage}{\linewidth}\vspace{4pt}\scriptsize" _n ///
    "\emph{Notes:} Unit is the county-year. Main sample = counties with non-missing harvest in every year 2005--2014 " ///
    "(\texttt{main\_sample}); agency only drops the CWD gap-fill states (\texttt{main\_sample\_agency}), i.e.\ Iowa. " ///
    "Deer only: the panel contains no elk, turkey, or moose harvest and no population variables." _n ///
    "\end{minipage}" _n "\end{table}" _n
file close fh

*==============================================================================
* SECTION 7: POPULATION VS HARVEST -- STUB (DECISION 1)
*==============================================================================

/*------------------------------------------------------------------------

Not built: the national panel carries no population variables. If the
county population indices are re-merged from the per-state clean files on
county_fips + year...

    MO_deer_harmonized_county_year_2002-2014.dta   pop_preseason (2002-2014)
    
    OH_deer_harmonized_county_year_1980-2014.dta   pop_prehunt   (1981-2014)
    
    WI_deer_harmonized_county_year_1960-2015.dta   pop_prehunt 2014, pop_posthunt 2015
    
    VA_deer_harmonized_county_year_1947-2014.dta   pop_index 2014 (an INDEX)

...the planned exhibits are:

  (i)   raw scatter of harvest on population, one panel per state:
          twoway scatter harvest_total pop, by(state, yrescale xrescale)

  (ii)  binscatter net of county and state-year fixed effects:
          ssc install binsreg
          binsreg harvest_total pop, absorb(cty sid#year)
        (or residualise both with reghdfe ..., resid and bin the residuals)

  (iii) county time series, harvest and population each standardised
        within county, overlaid for a sample of counties per state, to
        eyeball common trends and common shocks.

MO and OH are the only two states with a multi-year county series, so (ii)
and (iii) are effectively a two-state exercise.

------------------------------------------------------------------------*/

display as text _newline "deer_descriptives.do finished. Output in: $outDESC"

log close
