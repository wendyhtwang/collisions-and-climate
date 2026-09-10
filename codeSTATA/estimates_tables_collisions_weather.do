/*==============================================================
FILE:         estimates_tables_collisions_weather.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: Wendy Wang

PURPOSE:      Read back the .ster files written by
              estimates_generate_collisions_weather.do and assemble them
              into the two LaTeX tables that get uploaded to Overleaf:

                Table 1  Animal share of all collisions
                Table 2  Animal collisions per 100,000 residents,
                         population-weighted

              Each table is 4 panels (winter measure) x 4 columns
              (control set). Per style guide Section 13, each panel is
              exported as its own coefficient block with estout, and the
              four blocks are wrapped into one table with texdoc.

CHANGELOG:
  09/08/2026 Wendy Wang: initial version, per Eyal (9/1/26). Layout
    follows the Sept 8 "Collisions on Winter Weather" mockup: panels
    stack (winter measure), columns iterate (control set), R^2 /
    Observations / Clusters under each panel, and a single X-block for
    the control sets at the foot of the table rather than repeated under
    every panel.
  09/10/2026 Wendy Wang: revised against Eyal's comments on the mockup at
    the 9/8/26 meeting --
    (a) The X-block is now ONE weather row, not two. Eyal: "since you are
        always going to be including the mean temperature and the
        precipitation quantiles together, you can just narrow that to one
        row and just call it weather controls." The ctrl_temp and
        ctrl_ppt indicator rows are replaced by a single ctrl_weather.
    (b) Panel B now shows ONE anomaly threshold, chosen by the panelB_sd
        switch in SECTION 1 and defaulting to 1SD. The estimation script
        runs the 1SD and 2SD dummies as separate specifications and
        prints them side by side; this file publishes whichever one that
        comparison favours, and the table notes say the other was
        estimated separately. Eyal: "I would choose either or... you can
        run both and decide which one you want to keep."
    (c) A missing .ster now stops the run instead of printing a warning
        and letting estout fail later on an unstored estimate. Panel D is
        no longer expected to be missing: winter_severity_index has been
        populated since the 9/9/26 rebuild.
    (d) The Q1 lag prefix is detected from the coefficient NAMES in
        e(b) rather than from a capture on _b[], which is what the
        detection actually depends on.
    (e) Notes rewritten to state what the two control rows contain, that
        the sample starts in 1982 (every winter measure needs December of
        the preceding year, and PRISM starts in January 1981), and which
        anomaly threshold is on display.
  09/10/2026 Wendy Wang: folders renamed -- .tex output moves from
    tables/collisions to tables/collisions_weather, and the .ster read path
    follows the estimation script from dataSTATA/estimates/collisions to
    dataSTATA/estimates/collisions_weather. The \tablePATH/results/ path in
    the \ExpandableInput lines was renamed to match on the assumption that
    the Overleaf subfolder mirrors the local one; confirm that against
    Overleaf before compiling (see SECTION 4).
  09/10/2026 Wendy Wang: Overleaf paths corrected against the actual repo,
    after the first upload failed to compile --
    (a) \tablePATH DOES NOT EXIST. main.tex defines \tabPath (= "tables")
        and \figPath (= "figures"), and neither was used anywhere in the
        project yet, so there was nothing to copy the convention from and
        the earlier drafts invented a macro name. Undefined control
        sequence -> the path collapsed to /results/... -> file not found
        -> emergency stop. The \ExpandableInput lines now emit
        exhibits_main_text/\tabPath/collisions_weather/..., which uses
        \tabPath as it is actually defined (the leaf folder name).
    (b) Exhibits are under exhibits_main_text/, not a project-root
        tables/. Paths resolve from main.tex's directory.
    (c) The notes now cite \eqref{eq:baseline}; the align block in
        04_methods.tex had no \label at all and one was added.
    (d) Both tables overflowed the page -- by ~250pt (share) and ~110pt
        (rate), with the notes running off the bottom and colliding with
        the page number. Fixed by sizing the table body (\footnotesize
        and \arraystretch 1 inside threeparttable, the latter matching
        what main.tex already does for the appendix), dropping the notes
        to \scriptsize, and cutting the notes roughly in half. Measured
        with a local pdflatex run against a copy of the Overleaf project;
        both tables now fit on one page with room to spare. The
        \scriptsize is a deliberate departure from style guide Section
        13.3, which specifies \footnotesize in the tablenotes boilerplate.

* Inputs:
*   $path/dataSTATA/estimates/collisions_weather/<outcome>_p<A|B1|B2|C|D>_c<1-4>_W<wt>.ster
*   $path/dataSTATA/estimates/collisions_weather/_run_settings.txt
*       (both written by estimates_generate_collisions_weather.do)
*
* Outputs:
*   $path/tables/collisions_weather/table_collisions_weather_share_panel_<A-D>.tex
*   $path/tables/collisions_weather/table_collisions_weather_share.tex
*   $path/tables/collisions_weather/table_collisions_weather_rate_panel_<A-D>.tex
*   $path/tables/collisions_weather/table_collisions_weather_rate.tex
*   $path/codeSTATA/estimates_tables_collisions_weather.log
*
*   The two wrapper files (table_collisions_weather_share.tex and
*   ..._rate.tex) are what get input into the Results section in
*   Overleaf. The _panel_ files are pulled in by the wrappers via
*   \ExpandableInput and must sit in the matching Overleaf subfolder.
*   See SECTION 4.
*
* Notes on three deliberate departures from the Section 13.2 template:
*   - Only Panel A carries mlabels((1) (2) (3) (4)). Panels B-D use
*     mlabels(none), since the four blocks stack inside one tabular and
*     the column numbers should print once.
*   - The control indicator rows (ctrl_weather / ctrl_age) are appended
*     to Panel D's stats() only, so the X-block appears once at the foot
*     of the table rather than under every panel.
*   - Coefficients print to 3 decimals rather than the template's 2. The
*     share outcome runs to about 0.02, so 2 decimals would round most of
*     the table to 0.00.
*
* OVERLEAF LAYOUT -- read from the repo on 9/10/26, not assumed:
*   - Exhibits live at exhibits_main_text/tables/<subfolder>/, NOT at a
*     project-root tables/. LaTeX resolves \input and \ExpandableInput
*     paths from main.tex's directory, so they are written from there.
*   - main.tex defines \tabPath as "tables" and \figPath as "figures".
*     Both name the LEAF folder, so the full path is
*     exhibits_main_text/\tabPath/<subfolder>/ -- which is what the
*     \ExpandableInput lines below emit.
*   - There is NO \tablePATH macro in this project. Earlier drafts of
*     this file assumed one; that is what broke the compile on 9/10.
*   - \ExpandableInput itself IS defined, in preamble.tex.
*   - The baseline specification is the align block in 04_methods.tex,
*     labelled eq:baseline.
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

cap mkdir "$tables"
cap mkdir "$tables/collisions_weather"

* Open log file in the codeSTATA directory, matching
* build_main_data_county_year.do
local log_file = "$path/codeSTATA/estimates_tables_collisions_weather.log"
cap log close
log using "`log_file'", replace text

cap which estout
if _rc ssc install estout
cap which texdoc
if _rc ssc install texdoc

*---------------------------------------------------------------
* SECTION 1: SETTINGS AND WHAT THE ESTIMATION RUN ACTUALLY DID
*---------------------------------------------------------------

* Which warm-winter anomaly threshold goes in Panel B: 1 or 2.
* The estimation script estimates both and prints them side by side in
* its SECTION 7. Eyal's tie-break, 9/8/26: if both are precise and point
* the same way, keep 1SD, because a 1SD winter is far more common and the
* estimate therefore has more support. Set this once, here, after looking
* at that comparison.
local panelB_sd = 1

if `panelB_sd' == 1 {
    local b_var  = "warm_winter_1sd"
    local b_row  = "\(\geq\) 1\(\sigma\) above own climatology"
    local b_head = "Panel B. Warm-winter anomaly, \(\geq\) 1\(\sigma\)"
    local b_show = "1\(\sigma\)"
    local b_alt  = "2\(\sigma\)"
}
else {
    local b_var  = "warm_winter_2sd"
    local b_row  = "\(\geq\) 2\(\sigma\) above own climatology"
    local b_head = "Panel B. Warm-winter anomaly, \(\geq\) 2\(\sigma\)"
    local b_show = "2\(\sigma\)"
    local b_alt  = "1\(\sigma\)"
}

* The estimation script records the choices that change how this table
* must be labelled. Read them rather than restating them here, so the two
* files cannot drift apart.

local ppt_note ""
local file_name = "$estimates/collisions_weather/_run_settings.txt"
capture confirm file "`file_name'"
if _rc {
    di as error "_run_settings.txt not found -- run"
    di as error "estimates_generate_collisions_weather.do first."
    exit 601
}

file open fh using "`file_name'", read
file read fh line
while r(eof) == 0 {
    if strpos(`"`line'"', "ppt_control_note = ") == 1 {
        local ppt_note = substr(`"`line'"', strlen("ppt_control_note = ") + 1, .)
    }
    file read fh line
}
file close fh

if "`ppt_note'" == "" {
    local ppt_note "annual precipitation quintiles"
}

* Q3 decides whether the SHARE regressions are weighted, which changes
* the .ster file-name suffix. Detect it rather than hardcoding "none",
* so flipping the switch upstream cannot silently break this script.
local share_wt = ""
foreach w in none pop {
    capture confirm file "$estimates/collisions_weather/animal_share_pA_c1_W`w'.ster"
    if !_rc local share_wt = "`w'"
}
if "`share_wt'" == "" {
    di as error "No animal_share Panel A / column 1 estimates found in"
    di as error "$estimates/collisions_weather/ -- run"
    di as error "estimates_generate_collisions_weather.do first."
    exit 601
}
di as text "Share-table weighting detected: `share_wt'"

* Detect the Q1 lag choice from the estimates themselves rather than
* trusting a second copy of the switch: under Q1 == 1 the regressor
* entered as L1. and Stata named the coefficient L.mean_winter_temp.
estimates use "$estimates/collisions_weather/animal_share_pA_c1_W`share_wt'.ster"
local temp_names : colnames e(b)
if strpos(" `temp_names' ", " L.mean_winter_temp ") > 0 {
    local cp = "L."
}
else {
    local cp = ""
}
di as text "Coefficient-name prefix detected: [`cp']"
di as text "Panel B threshold on display: `panelB_sd'SD"

*---------------------------------------------------------------
* SECTION 2: TABLE 1 -- ANIMAL SHARE OF ALL COLLISIONS
*---------------------------------------------------------------
* 2a. Load the sixteen estimates and store them under grid names.
*     Panel B's source file is pB1 or pB2 depending on the switch, but it
*     is stored as p_B_c_# either way so the estout call below does not
*     have to care which one is on display.

local y   = "animal_share"
local wt  = "`share_wt'"
local tag = "share"

local n_missing = 0

foreach p in A B C D {

    if "`p'" == "B" {
        local psrc = "B`panelB_sd'"
    }
    else {
        local psrc = "`p'"
    }

    forvalues c = 1/4 {
        local ster = "$estimates/collisions_weather/`y'_p`psrc'_c`c'_W`wt'.ster"
        capture confirm file "`ster'"
        if _rc {
            di as error "MISSING: `ster'"
            local n_missing = `n_missing' + 1
        }
        else {
            estimates use "`ster'"
            estimates store p_`p'_c_`c'
        }
    }
}

if `n_missing' > 0 {
    di as error "`n_missing' of 16 estimate files are missing for the"
    di as error "  share table. Rerun"
    di as error "  estimates_generate_collisions_weather.do -- and if"
    di as error "  only the Panel D files are missing, check its"
    di as error "  winter_severity_index guard, which skips the panel"
    di as error "  when the WSI snow component did not make it into the"
    di as error "  panel."
    exit 601
}

* The outcome mean goes in the column header, per the mockup and the
* convention in Eyal's own tables.
estimates use "$estimates/collisions_weather/`y'_pA_c1_W`wt'.ster"
local ybar : di %5.3f e(dep_var_mean)
local ybar = trim("`ybar'")

*---------------------------------------------------------------
* 2b. Panel A -- mean winter temperature
*---------------------------------------------------------------

#delimit ;
estout p_A_c_1
       p_A_c_2
       p_A_c_3
       p_A_c_4
       using "$tables/collisions_weather/table_collisions_weather_`tag'_panel_A.tex",
       cells(b(fmt(3)) se(par fmt(3)))
       label style(tex)
       stats(r2
             N
             N_clust,
             fmt(2 %9.0gc %9.0gc)
             labels("\midrule \(R^2\)"
                    "N"
                    "Clusters"))
       mlabels((1) (2) (3) (4))
       collabels(none)
       varlabels(`cp'mean_winter_temp "Mean winter temperature (\(^{\circ}\)C)")
       keep(`cp'mean_winter_temp)
       order(`cp'mean_winter_temp)
       prehead(

       )
       posthead(\midrule)
       prefoot()
       postfoot(
         \noalign{\smallskip}
       )
       replace;
#delimit cr

*---------------------------------------------------------------
* 2c. Panel B -- warm-winter anomaly
*---------------------------------------------------------------
* One threshold only. The other was estimated as its own specification
* and lives in the .ster folder; it is not in this table, per Eyal
* 9/8/26, because the two dummies overlap by construction.

#delimit ;
estout p_B_c_1
       p_B_c_2
       p_B_c_3
       p_B_c_4
       using "$tables/collisions_weather/table_collisions_weather_`tag'_panel_B.tex",
       cells(b(fmt(3)) se(par fmt(3)))
       label style(tex)
       stats(r2
             N
             N_clust,
             fmt(2 %9.0gc %9.0gc)
             labels("\midrule \(R^2\)"
                    "N"
                    "Clusters"))
       mlabels(none)
       collabels(none)
       varlabels(`cp'`b_var' "`b_row'")
       keep(`cp'`b_var')
       order(`cp'`b_var')
       prehead(

       )
       posthead(\midrule)
       prefoot()
       postfoot(
         \noalign{\smallskip}
       )
       replace;
#delimit cr

*---------------------------------------------------------------
* 2d. Panel C -- days below 0F, Dec-Apr
*---------------------------------------------------------------

#delimit ;
estout p_C_c_1
       p_C_c_2
       p_C_c_3
       p_C_c_4
       using "$tables/collisions_weather/table_collisions_weather_`tag'_panel_C.tex",
       cells(b(fmt(3)) se(par fmt(3)))
       label style(tex)
       stats(r2
             N
             N_clust,
             fmt(2 %9.0gc %9.0gc)
             labels("\midrule \(R^2\)"
                    "N"
                    "Clusters"))
       mlabels(none)
       collabels(none)
       varlabels(`cp'winter_days_below_0f "Extreme-cold days")
       keep(`cp'winter_days_below_0f)
       order(`cp'winter_days_below_0f)
       prehead(

       )
       posthead(\midrule)
       prefoot()
       postfoot(
         \noalign{\smallskip}
       )
       replace;
#delimit cr

*---------------------------------------------------------------
* 2e. Panel D -- winter severity index
*---------------------------------------------------------------
* The control X-block is appended to THIS panel's stats() only, so it
* prints once, at the foot of the table. One weather row, per Eyal
* 9/8/26 -- the monthly temperature controls and the precipitation
* quintiles always enter together, so they never need separate rows.

#delimit ;
estout p_D_c_1
       p_D_c_2
       p_D_c_3
       p_D_c_4
       using "$tables/collisions_weather/table_collisions_weather_`tag'_panel_D.tex",
       cells(b(fmt(3)) se(par fmt(3)))
       label style(tex)
       stats(r2
             N
             N_clust
             ctrl_weather
             ctrl_age,
             fmt(2 %9.0gc %9.0gc 0 0)
             labels("\midrule \(R^2\)"
                    "N"
                    "Clusters"
                    "\noalign{\medskip} \midrule Weather controls"
                    "Age shares"))
       mlabels(none)
       collabels(none)
       varlabels(`cp'winter_severity_index "WSI (Kohn / WI DNR)")
       keep(`cp'winter_severity_index)
       order(`cp'winter_severity_index)
       prehead(

       )
       posthead(\midrule)
       prefoot()
       postfoot(
         \noalign{\smallskip}
       )
       replace;
#delimit cr

*---------------------------------------------------------------
* 2f. Wrap the four panels into Table 1
*---------------------------------------------------------------

* New table file
local file_name = "$tables/collisions_weather/table_collisions_weather_`tag'.tex"
texdoc init "`file_name'", replace force

tex \begin{table}[htpb]
tex \captionlistentry[table]{Animal-Related Collision Share and Winter Conditions}
tex \label{table:collisions_weather_share}
tex \centering
tex Table \ref{table:collisions_weather_share}. \\
tex Animal-Related Collision Share and Winter Conditions \\
tex \begin{threeparttable}
tex \footnotesize
tex \def\arraystretch{1}
tex \begin{tabulary}{\textwidth}{l*{4}{c}@{}}
tex \toprule \toprule
tex \noalign{\smallskip}
tex & \multicolumn{4}{c}{Animal share of all collisions (\(\bar{Y}\) = `ybar')} \\
tex \cmidrule(l{5pt}r{5pt}){2-5}
tex \multicolumn{5}{l}{Panel A. Mean winter temperature} \\
tex \ExpandableInput{exhibits_main_text/\tabPath/collisions_weather/table_collisions_weather_`tag'_panel_A.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{`b_head'} \\
tex \ExpandableInput{exhibits_main_text/\tabPath/collisions_weather/table_collisions_weather_`tag'_panel_B.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{Panel C. Days below 0\(^{\circ}\)F, Dec--Apr} \\
tex \ExpandableInput{exhibits_main_text/\tabPath/collisions_weather/table_collisions_weather_`tag'_panel_C.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{Panel D. Winter severity index} \\
tex \ExpandableInput{exhibits_main_text/\tabPath/collisions_weather/table_collisions_weather_`tag'_panel_D.tex}
tex \noalign{\smallskip}
tex \bottomrule
tex \end{tabulary}
tex \medskip
tex \begin{tablenotes}[flushleft]
tex \setlength\labelsep{0pt}
tex \item
tex \scriptsize
tex \justify
tex Notes: Estimation results for Equation \eqref{eq:baseline}. The outcome is animal-related
tex collisions as a share of all-cause collisions at the county-year level; the numerator is the
tex all-animal count, backfilled from the deer-only count where it is missing. Panels differ only
tex in the measure of winter conditions, columns only in the time-varying controls: weather
tex controls are the twelve monthly mean temperatures and `ppt_note', and age shares are the
tex eighteen five-year population age bands with 0--4 omitted. All regressions include county and
tex state-by-year fixed effects; standard errors, in parentheses, are clustered at the county
tex level. Panel B reports the `b_show' threshold; the `b_alt' threshold was estimated
tex separately, since the two indicators overlap by construction. The sample begins in 1982:
tex every winter measure spans December of the preceding year, and PRISM begins in January 1981.
tex Entry is unbalanced -- states begin reporting animal-involved collisions in different years.
tex \end{tablenotes}
tex \end{threeparttable}
tex \end{table}

* Close table file
texdoc close

di as result "Wrote `file_name'"

*---------------------------------------------------------------
* SECTION 3: TABLE 2 -- ANIMAL COLLISIONS PER 100,000 RESIDENTS
*---------------------------------------------------------------
* Identical structure to Table 1, two substitutions: the outcome is
* animal_rate_100k and every regression is population-weighted. Phase 6
* asks for this as the level counterpart to the share.
*
* 3a. Load and store.

local y   = "animal_rate_100k"
local wt  = "pop"
local tag = "rate"

local n_missing = 0

foreach p in A B C D {

    if "`p'" == "B" {
        local psrc = "B`panelB_sd'"
    }
    else {
        local psrc = "`p'"
    }

    forvalues c = 1/4 {
        local ster = "$estimates/collisions_weather/`y'_p`psrc'_c`c'_W`wt'.ster"
        capture confirm file "`ster'"
        if _rc {
            di as error "MISSING: `ster'"
            local n_missing = `n_missing' + 1
        }
        else {
            estimates use "`ster'"
            estimates store r_`p'_c_`c'
        }
    }
}

if `n_missing' > 0 {
    di as error "`n_missing' of 16 estimate files are missing for the"
    di as error "  rate table. Rerun"
    di as error "  estimates_generate_collisions_weather.do."
    exit 601
}

estimates use "$estimates/collisions_weather/`y'_pA_c1_W`wt'.ster"
local ybar : di %6.2f e(dep_var_mean)
local ybar = trim("`ybar'")

*---------------------------------------------------------------
* 3b. Panel A -- mean winter temperature
*---------------------------------------------------------------

#delimit ;
estout r_A_c_1
       r_A_c_2
       r_A_c_3
       r_A_c_4
       using "$tables/collisions_weather/table_collisions_weather_`tag'_panel_A.tex",
       cells(b(fmt(3)) se(par fmt(3)))
       label style(tex)
       stats(r2
             N
             N_clust,
             fmt(2 %9.0gc %9.0gc)
             labels("\midrule \(R^2\)"
                    "N"
                    "Clusters"))
       mlabels((1) (2) (3) (4))
       collabels(none)
       varlabels(`cp'mean_winter_temp "Mean winter temperature (\(^{\circ}\)C)")
       keep(`cp'mean_winter_temp)
       order(`cp'mean_winter_temp)
       prehead(

       )
       posthead(\midrule)
       prefoot()
       postfoot(
         \noalign{\smallskip}
       )
       replace;
#delimit cr

*---------------------------------------------------------------
* 3c. Panel B -- warm-winter anomaly
*---------------------------------------------------------------

#delimit ;
estout r_B_c_1
       r_B_c_2
       r_B_c_3
       r_B_c_4
       using "$tables/collisions_weather/table_collisions_weather_`tag'_panel_B.tex",
       cells(b(fmt(3)) se(par fmt(3)))
       label style(tex)
       stats(r2
             N
             N_clust,
             fmt(2 %9.0gc %9.0gc)
             labels("\midrule \(R^2\)"
                    "N"
                    "Clusters"))
       mlabels(none)
       collabels(none)
       varlabels(`cp'`b_var' "`b_row'")
       keep(`cp'`b_var')
       order(`cp'`b_var')
       prehead(

       )
       posthead(\midrule)
       prefoot()
       postfoot(
         \noalign{\smallskip}
       )
       replace;
#delimit cr

*---------------------------------------------------------------
* 3d. Panel C -- days below 0F, Dec-Apr
*---------------------------------------------------------------

#delimit ;
estout r_C_c_1
       r_C_c_2
       r_C_c_3
       r_C_c_4
       using "$tables/collisions_weather/table_collisions_weather_`tag'_panel_C.tex",
       cells(b(fmt(3)) se(par fmt(3)))
       label style(tex)
       stats(r2
             N
             N_clust,
             fmt(2 %9.0gc %9.0gc)
             labels("\midrule \(R^2\)"
                    "N"
                    "Clusters"))
       mlabels(none)
       collabels(none)
       varlabels(`cp'winter_days_below_0f "Extreme-cold days")
       keep(`cp'winter_days_below_0f)
       order(`cp'winter_days_below_0f)
       prehead(

       )
       posthead(\midrule)
       prefoot()
       postfoot(
         \noalign{\smallskip}
       )
       replace;
#delimit cr

*---------------------------------------------------------------
* 3e. Panel D -- winter severity index
*---------------------------------------------------------------

#delimit ;
estout r_D_c_1
       r_D_c_2
       r_D_c_3
       r_D_c_4
       using "$tables/collisions_weather/table_collisions_weather_`tag'_panel_D.tex",
       cells(b(fmt(3)) se(par fmt(3)))
       label style(tex)
       stats(r2
             N
             N_clust
             ctrl_weather
             ctrl_age,
             fmt(2 %9.0gc %9.0gc 0 0)
             labels("\midrule \(R^2\)"
                    "N"
                    "Clusters"
                    "\noalign{\medskip} \midrule Weather controls"
                    "Age shares"))
       mlabels(none)
       collabels(none)
       varlabels(`cp'winter_severity_index "WSI (Kohn / WI DNR)")
       keep(`cp'winter_severity_index)
       order(`cp'winter_severity_index)
       prehead(

       )
       posthead(\midrule)
       prefoot()
       postfoot(
         \noalign{\smallskip}
       )
       replace;
#delimit cr

*---------------------------------------------------------------
* 3f. Wrap the four panels into Table 2
*---------------------------------------------------------------

* New table file
local file_name = "$tables/collisions_weather/table_collisions_weather_`tag'.tex"
texdoc init "`file_name'", replace force

tex \begin{table}[htpb]
tex \captionlistentry[table]{Animal-Related Collision Rate and Winter Conditions}
tex \label{table:collisions_weather_rate}
tex \centering
tex Table \ref{table:collisions_weather_rate}. \\
tex Animal-Related Collision Rate and Winter Conditions \\
tex \begin{threeparttable}
tex \footnotesize
tex \def\arraystretch{1}
tex \begin{tabulary}{\textwidth}{l*{4}{c}@{}}
tex \toprule \toprule
tex \noalign{\smallskip}
tex & \multicolumn{4}{c}{Animal collisions per 100,000 residents (\(\bar{Y}\) = `ybar')} \\
tex \cmidrule(l{5pt}r{5pt}){2-5}
tex \multicolumn{5}{l}{Panel A. Mean winter temperature} \\
tex \ExpandableInput{exhibits_main_text/\tabPath/collisions_weather/table_collisions_weather_`tag'_panel_A.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{`b_head'} \\
tex \ExpandableInput{exhibits_main_text/\tabPath/collisions_weather/table_collisions_weather_`tag'_panel_B.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{Panel C. Days below 0\(^{\circ}\)F, Dec--Apr} \\
tex \ExpandableInput{exhibits_main_text/\tabPath/collisions_weather/table_collisions_weather_`tag'_panel_C.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{Panel D. Winter severity index} \\
tex \ExpandableInput{exhibits_main_text/\tabPath/collisions_weather/table_collisions_weather_`tag'_panel_D.tex}
tex \noalign{\smallskip}
tex \bottomrule
tex \end{tabulary}
tex \medskip
tex \begin{tablenotes}[flushleft]
tex \setlength\labelsep{0pt}
tex \item
tex \scriptsize
tex \justify
tex Notes: Estimation results for Equation \eqref{eq:baseline}. The outcome is animal-related
tex collisions per 100,000 residents at the county-year level, and all regressions are weighted
tex by county population. The numerator, panel and column structure, control definitions, fixed
tex effects, clustering, the anomaly threshold on display, and the 1982 sample start are as in
tex Table \ref{table:collisions_weather_share}.
tex \end{tablenotes}
tex \end{threeparttable}
tex \end{table}

* Close table file
texdoc close

di as result "Wrote `file_name'"

*---------------------------------------------------------------
* SECTION 4: WHAT TO UPLOAD TO OVERLEAF
*---------------------------------------------------------------
* Ten files, into exhibits_main_text/tables/collisions_weather/ in the
* Overleaf project -- one folder, not a nested collisions_weather/
* collisions_weather/. The files:
*   table_collisions_weather_share.tex        <- input this one
*   table_collisions_weather_share_panel_A-D.tex
*   table_collisions_weather_rate.tex         <- and this one
*   table_collisions_weather_rate_panel_A-D.tex
* Then reference the two wrappers from the Results section with \input,
* naming the wrapper, not the panels (Eyal, 9/8/26).

di as result _newline "Upload $tables/collisions_weather/*.tex to Overleaf;"
di as result "input the two wrapper files from the Results section."

* Wrap Up
log close
