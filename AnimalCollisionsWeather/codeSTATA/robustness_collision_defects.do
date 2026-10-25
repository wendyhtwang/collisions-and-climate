/*==============================================================================
FILE NAME:  robustness_collision_defects.do

PURPOSE:    Column (1) collisions-weather coefficients under sample cuts
            that remove known defects in the 9/1/26 collisions snapshot.
  - Run in the same session after estimates_generate_collisions_weather.do
    has been run through the end of SECTION 4.
  - Output: $estimates/collisions_weather/robustness_collision_defects.csv
==============================================================================*/

* State-years whose animal count sums to zero statewide (zero coded for missing)
bysort state_fips_num year: egen double _sy = total(cond(est_sample, any_animal_filled, .)), missing
gen byte is_zero_sy = (_sy == 0)
drop _sy

* Sample cuts: 0 baseline; 1 drop WV 2013 (deer = carcass count);
* 2 drop share > 100; 3 drop NY and WV; 4 drop deer-floored rows;
* 5 drop statewide-zero state-years; 6 drop NM (animal = all-cause)
gen byte cut0 = est_sample
gen byte cut1 = est_sample & !(state_fips_num == 54 & year == 2013)
gen byte cut2 = est_sample & !(animal_share > 100 & !missing(animal_share))
gen byte cut3 = est_sample & !inlist(state_fips_num, 36, 54)
gen byte cut4 = est_sample & num_source != 4
gen byte cut5 = est_sample & !is_zero_sy
gen byte cut6 = est_sample & state_fips_num != 35

forvalues k = 0/6 {
    qui count if cut`k'
    di as text "  cut`k' rows: " r(N)
}
qui count if est_sample & animal_share == 0
di as text "  est_sample rows with share == 0: " r(N)
qui count if est_sample & animal_share == 0 & is_zero_sy
di as text "    of which in statewide-zero state-years: " r(N)

tempname R
tempfile res
postfile `R' str16 outcome str3 panel byte cut double(N b se p25 p75 ymean) using `res'

foreach y in animal_share animal_rate_100k {
    local wt ""
    if "`y'" == "animal_rate_100k" local wt "[aweight=population]"

    foreach p in A C D {
        cap drop _w
        gen double _w = ${rhs`p'}

        forvalues k = 0/6 {
            qui reghdfe `y' _w if cut`k' `wt', absorb($FE) vce($SE)
            local b  = _b[_w]
            local se = _se[_w]
            local N  = e(N)
            qui summ `y' if e(sample) `wt'
            local ym = r(mean)
            qui _pctile _w if e(sample), p(25 75)
            post `R' ("`y'") ("`p'") (`k') (`N') (`b') (`se') (r(r1)) (r(r2)) (`ym')
        }
    }
}
postclose `R'
drop _w cut0-cut6

preserve
    use `res', clear
    label define cut_lbl 0 "baseline" 1 "no WV 2013" 2 "no share>100" ///
                         3 "no NY, WV" 4 "no deer floor" 5 "no sw-zero" ///
                         6 "no NM", replace
    label values cut cut_lbl
    gen double t           = b / se
    gen double pct_of_mean = 100 * (p75 - p25) * b / ymean
    format b se %9.4f
    format t ymean pct_of_mean %9.2f
    list outcome panel cut N b se t ymean pct_of_mean, ///
        noobs abbrev(12) sepby(outcome panel)
    export delimited using ///
        "$estimates/collisions_weather/robustness_collision_defects.csv", replace
restore
