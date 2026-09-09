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

* Inputs:
*   $path/dataSTATA/estimates/collisions/<outcome>_p<A-D>_c<1-4>_W<wt>.ster
*   $path/dataSTATA/estimates/collisions/_run_settings.txt
*       (both written by estimates_generate_collisions_weather.do)
*
* Outputs:
*   $path/tables/collisions/table_collisions_weather_share_panel_<A-D>.tex
*   $path/tables/collisions/table_collisions_weather_share.tex
*   $path/tables/collisions/table_collisions_weather_rate_panel_<A-D>.tex
*   $path/tables/collisions/table_collisions_weather_rate.tex
*
*   The two wrapper files (table_collisions_weather_share.tex and
*   ..._rate.tex) are what get uploaded to Overleaf and \input into the
*   Results section. The _panel_ files are pulled in by the wrappers via
*   \ExpandableInput and must sit in the matching Overleaf subfolder.
*
* Notes on two deliberate departures from the Section 13.2 template:
*   - Only Panel A carries mlabels((1) (2) (3) (4)). Panels B-D use
*     mlabels(none), since the four blocks stack inside one tabular and
*     the column numbers should print once.
*   - The FE/control indicator rows (ctrl_temp / ctrl_ppt / ctrl_age)
*     are appended to Panel D's stats() only, so the X-block appears
*     once at the foot of the table rather than under every panel.
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
cap mkdir "$tables/collisions"

cap which estout
if _rc ssc install estout
cap which texdoc
if _rc ssc install texdoc

*---------------------------------------------------------------
* SECTION 1: READ BACK THE SETTINGS THE ESTIMATION RUN USED
*---------------------------------------------------------------
* The estimation script records the choices that change how this table
* must be labelled -- the Q1 lag decision (which changes the coefficient
* NAME that keep() has to match) and the Q4 precipitation substitution
* (which changes the notes). Read them rather than restating them here,
* so the two files cannot drift apart.

local ppt_note ""
local file_name = "$estimates/collisions/_run_settings.txt"
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
    capture confirm file "$estimates/collisions/animal_share_pA_c1_W`w'.ster"
    if !_rc local share_wt = "`w'"
}
if "`share_wt'" == "" {
    di as error "No animal_share Panel A / column 1 estimates found in"
    di as error "$estimates/collisions/ -- run"
    di as error "estimates_generate_collisions_weather.do first."
    exit 601
}
di as text "Share-table weighting detected: `share_wt'"

* Detect the Q1 lag choice from the estimates themselves rather than
* trusting a second copy of the switch: if _b[mean_winter_temp] does not
* exist, the regressor was entered as L1. and Stata named the
* coefficient L.mean_winter_temp.
estimates use "$estimates/collisions/animal_share_pA_c1_W`share_wt'.ster"
capture local probe = _b[mean_winter_temp]
if _rc {
    local cp = "L."
}
else {
    local cp = ""
}
di as text "Coefficient-name prefix detected: `cp'"

*---------------------------------------------------------------
* SECTION 2: TABLE 1 -- ANIMAL SHARE OF ALL COLLISIONS
*---------------------------------------------------------------
* 2a. Load the sixteen estimates and store them under grid names.

local y   = "animal_share"
local wt  = "`share_wt'"
local tag = "share"

foreach p in A B C D {
    forvalues c = 1/4 {
        local ster = "$estimates/collisions/`y'_p`p'_c`c'_W`wt'.ster"
        capture confirm file "`ster'"
        if _rc {
            di as error "MISSING: `ster'"
            di as error "  (Panel D is skipped by the estimation script"
            di as error "   while winter_severity_index is all missing.)"
        }
        else {
            estimates use "`ster'"
            estimates store p_`p'_c_`c'
        }
    }
}

* The outcome mean goes in the column header, per the mockup and the
* convention in Eyal's own tables.
estimates use "$estimates/collisions/`y'_pA_c1_W`wt'.ster"
local ybar : di %5.3f e(dep_var_mean)

*---------------------------------------------------------------
* 2b. Panel A -- mean winter temperature
*---------------------------------------------------------------

#delimit ;
estout p_A_c_1
       p_A_c_2
       p_A_c_3
       p_A_c_4
       using "$tables/collisions/table_collisions_weather_`tag'_panel_A.tex",
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
* 2c. Panel B -- warm-winter anomalies
*---------------------------------------------------------------
* Both dummies come from the same regression, so the 2SD row reads as
* the ADDITIONAL effect of an extreme warm winter relative to a 1SD one.
* Say so in the notes (SECTION 2f) -- it is not obvious from the rows.

#delimit ;
estout p_B_c_1
       p_B_c_2
       p_B_c_3
       p_B_c_4
       using "$tables/collisions/table_collisions_weather_`tag'_panel_B.tex",
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
       varlabels(`cp'warm_winter_1sd "\(\geq\) 1\(\sigma\) above own climatology"
                 `cp'warm_winter_2sd "\(\geq\) 2\(\sigma\) above own climatology")
       keep(`cp'warm_winter_1sd
            `cp'warm_winter_2sd)
       order(`cp'warm_winter_1sd
             `cp'warm_winter_2sd)
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
       using "$tables/collisions/table_collisions_weather_`tag'_panel_C.tex",
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
* The control-set X-block is appended to THIS panel's stats() only, so
* it prints once, at the foot of the table.

#delimit ;
estout p_D_c_1
       p_D_c_2
       p_D_c_3
       p_D_c_4
       using "$tables/collisions/table_collisions_weather_`tag'_panel_D.tex",
       cells(b(fmt(3)) se(par fmt(3)))
       label style(tex)
       stats(r2
             N
             N_clust
             ctrl_temp
             ctrl_ppt
             ctrl_age,
             fmt(2 %9.0gc %9.0gc 0 0 0)
             labels("\midrule \(R^2\)"
                    "N"
                    "Clusters"
                    "\noalign{\medskip} \midrule Monthly mean-temperature controls"
                    "Annual precipitation quintiles"
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
local file_name = "$tables/collisions/table_collisions_weather_`tag'.tex"
texdoc init "`file_name'", replace force

tex \begin{table}[htpb]
tex \captionlistentry[table]{Animal-Related Collision Share and Winter Conditions}
tex \label{table:collisions_weather_share}
tex \centering
tex Table \ref{table:collisions_weather_share}. \\
tex Animal-Related Collision Share and Winter Conditions \\
tex \begin{threeparttable}
tex \begin{tabulary}{\textwidth}{l*{4}{c}@{}}
tex \toprule \toprule
tex \noalign{\smallskip}
tex & \multicolumn{4}{c}{Animal share of all collisions (\(\bar{Y}\) = `ybar')} \\
tex \cmidrule(l{5pt}r{5pt}){2-5}
tex \multicolumn{5}{l}{Panel A. Mean winter temperature} \\
tex \ExpandableInput{\tablePATH/results/collisions/table_collisions_weather_`tag'_panel_A.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{Panel B. Warm-winter anomalies} \\
tex \ExpandableInput{\tablePATH/results/collisions/table_collisions_weather_`tag'_panel_B.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{Panel C. Days below 0\(^{\circ}\)F, Dec--Apr} \\
tex \ExpandableInput{\tablePATH/results/collisions/table_collisions_weather_`tag'_panel_C.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{Panel D. Winter severity index} \\
tex \ExpandableInput{\tablePATH/results/collisions/table_collisions_weather_`tag'_panel_D.tex}
tex \noalign{\smallskip}
tex \bottomrule
tex \end{tabulary}
tex \medskip
tex \begin{tablenotes}[flushleft]
tex \setlength\labelsep{0pt}
tex \item
tex \footnotesize
tex \justify
tex Notes: Estimation results for Equation \eqref{eq:collisions_weather}. The outcome is
tex animal-related collisions as a share of all-cause collisions at the county-year level.
tex Each panel reports a separate set of regressions, differing only in the measure of
tex winter conditions on the right-hand side; within a panel, columns differ only in the
tex time-varying controls included. All regressions include county fixed effects and
tex state-by-year fixed effects. Standard errors, in parentheses, are clustered at the
tex county level. Panel B enters both anomaly dummies jointly, so the 2\(\sigma\)
tex coefficient is the additional effect of an extreme warm winter relative to a
tex 1\(\sigma\) one. The precipitation control is `ppt_note'.
tex Entry into the sample is unbalanced because states begin reporting animal-involved
tex collisions in different years.
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
* asks for this as the robustness counterpart to the share.
*
* 3a. Load and store.

local y   = "animal_rate_100k"
local wt  = "pop"
local tag = "rate"

foreach p in A B C D {
    forvalues c = 1/4 {
        local ster = "$estimates/collisions/`y'_p`p'_c`c'_W`wt'.ster"
        capture confirm file "`ster'"
        if _rc {
            di as error "MISSING: `ster'"
        }
        else {
            estimates use "`ster'"
            estimates store r_`p'_c_`c'
        }
    }
}

estimates use "$estimates/collisions/`y'_pA_c1_W`wt'.ster"
local ybar : di %5.2f e(dep_var_mean)

*---------------------------------------------------------------
* 3b. Panel A -- mean winter temperature
*---------------------------------------------------------------

#delimit ;
estout r_A_c_1
       r_A_c_2
       r_A_c_3
       r_A_c_4
       using "$tables/collisions/table_collisions_weather_`tag'_panel_A.tex",
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
* 3c. Panel B -- warm-winter anomalies
*---------------------------------------------------------------

#delimit ;
estout r_B_c_1
       r_B_c_2
       r_B_c_3
       r_B_c_4
       using "$tables/collisions/table_collisions_weather_`tag'_panel_B.tex",
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
       varlabels(`cp'warm_winter_1sd "\(\geq\) 1\(\sigma\) above own climatology"
                 `cp'warm_winter_2sd "\(\geq\) 2\(\sigma\) above own climatology")
       keep(`cp'warm_winter_1sd
            `cp'warm_winter_2sd)
       order(`cp'warm_winter_1sd
             `cp'warm_winter_2sd)
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
       using "$tables/collisions/table_collisions_weather_`tag'_panel_C.tex",
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
       using "$tables/collisions/table_collisions_weather_`tag'_panel_D.tex",
       cells(b(fmt(3)) se(par fmt(3)))
       label style(tex)
       stats(r2
             N
             N_clust
             ctrl_temp
             ctrl_ppt
             ctrl_age,
             fmt(2 %9.0gc %9.0gc 0 0 0)
             labels("\midrule \(R^2\)"
                    "N"
                    "Clusters"
                    "\noalign{\medskip} \midrule Monthly mean-temperature controls"
                    "Annual precipitation quintiles"
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
local file_name = "$tables/collisions/table_collisions_weather_`tag'.tex"
texdoc init "`file_name'", replace force

tex \begin{table}[htpb]
tex \captionlistentry[table]{Animal-Related Collision Rate and Winter Conditions}
tex \label{table:collisions_weather_rate}
tex \centering
tex Table \ref{table:collisions_weather_rate}. \\
tex Animal-Related Collision Rate and Winter Conditions \\
tex \begin{threeparttable}
tex \begin{tabulary}{\textwidth}{l*{4}{c}@{}}
tex \toprule \toprule
tex \noalign{\smallskip}
tex & \multicolumn{4}{c}{Animal collisions per 100,000 residents (\(\bar{Y}\) = `ybar')} \\
tex \cmidrule(l{5pt}r{5pt}){2-5}
tex \multicolumn{5}{l}{Panel A. Mean winter temperature} \\
tex \ExpandableInput{\tablePATH/results/collisions/table_collisions_weather_`tag'_panel_A.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{Panel B. Warm-winter anomalies} \\
tex \ExpandableInput{\tablePATH/results/collisions/table_collisions_weather_`tag'_panel_B.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{Panel C. Days below 0\(^{\circ}\)F, Dec--Apr} \\
tex \ExpandableInput{\tablePATH/results/collisions/table_collisions_weather_`tag'_panel_C.tex}
tex \tabularnewline
tex \multicolumn{5}{l}{Panel D. Winter severity index} \\
tex \ExpandableInput{\tablePATH/results/collisions/table_collisions_weather_`tag'_panel_D.tex}
tex \noalign{\smallskip}
tex \bottomrule
tex \end{tabulary}
tex \medskip
tex \begin{tablenotes}[flushleft]
tex \setlength\labelsep{0pt}
tex \item
tex \footnotesize
tex \justify
tex Notes: Estimation results for Equation \eqref{eq:collisions_weather}. The outcome is
tex animal-related collisions per 100,000 residents at the county-year level, and all
tex regressions are weighted by county population. Panel and column structure, fixed
tex effects, and clustering are as in Table \ref{table:collisions_weather_share}.
tex The precipitation control is `ppt_note'.
tex \end{tablenotes}
tex \end{threeparttable}
tex \end{table}

* Close table file
texdoc close

di as result "Wrote `file_name'"

*---------------------------------------------------------------
* SECTION 4: WHAT TO UPLOAD TO OVERLEAF
*---------------------------------------------------------------
* Ten files, into the Overleaf subfolder that \tablePATH/results/collisions
* resolves to:
*   table_collisions_weather_share.tex        <- \input this one
*   table_collisions_weather_share_panel_A-D.tex
*   table_collisions_weather_rate.tex         <- and this one
*   table_collisions_weather_rate_panel_A-D.tex
* Then reference the two wrappers from the Results section.

di as result _newline "Upload $tables/collisions/*.tex to Overleaf;"
di as result "\input the two wrapper files from the Results section."

* Wrap Up
cap log close
