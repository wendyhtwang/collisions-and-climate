/*==============================================================================
FILE NAME:  iqr_translation_collisions_weather.do

PURPOSE:    25th -> 75th percentile translation of the column (1)
            collisions-weather coefficients (Lunch & Learn results slides).
            Effect = (p75 - p25 of the winter measure) x coefficient.

HOW TO RUN: In the same Stata session, immediately after
            estimates_generate_collisions_weather.do. That file leaves the
            panel, est_sample, animal_share, animal_rate_100k, $FE, $SE and
            the ${rhs*} globals in memory.

OUTPUT:     $estimates/collisions_weather/iqr_translation.csv
            Percentiles are unweighted, over each regression's e(sample).
            Warm-winter (Panel B) is a 0/1 dummy: its coefficient already
            is the 0 -> 1 effect, so it is not translated here.
==============================================================================*/

tempname R
tempfile res
postfile `R' str16 outcome str3 panel double(N b se p25 p75 ymean) using `res'

foreach y in animal_share animal_rate_100k {

    local wt ""
    if "`y'" == "animal_rate_100k" local wt "[aweight=population]"

    foreach p in A C D {

        cap drop _w
        gen double _w = ${rhs`p'}

        qui reghdfe `y' _w if est_sample `wt', absorb($FE) vce($SE)
        local b  = _b[_w]
        local se = _se[_w]
        local N  = e(N)

        qui summ `y' if e(sample) `wt'
        local ym = r(mean)

        qui _pctile _w if e(sample), p(25 75)
        local q25 = r(r1)
        local q75 = r(r2)

        post `R' ("`y'") ("`p'") (`N') (`b') (`se') (`q25') (`q75') (`ym')
    }
}
postclose `R'
drop _w

preserve
    use `res', clear
    gen double iqr        = p75 - p25
    gen double effect     = iqr * b
    gen double pct_of_mean = 100 * effect / ymean
    format b se %9.4f
    format p25 p75 iqr effect pct_of_mean ymean %9.2f
    list outcome panel N b se p25 p75 iqr effect ymean pct_of_mean, ///
        noobs abbrev(12) sep(3)
    export delimited using ///
        "$estimates/collisions_weather/iqr_translation.csv", replace
restore
