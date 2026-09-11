/*******************************************************************************
Project:  Animal collisions, weather, and wildlife populations
Purpose:  Knit the Tier 2 exhibits from 09_descriptive_weather_full.ipynb into a
          single dated PDF report for the PI.

Inputs:   $path/figures/weather/tier2, files *.pdf   (exhibits)
          $path/tables/weather/tier2, files *.csv    (exhibit index, notes, decisions)
          $path/tables/weather/tier1, files *.csv    (coverage and QA tables)
Output:   $path/reports/WeatherData/report_YYYY_MM_DD/

Notes:    Tier 1 QA exhibits are indexed in Appendix B, not reproduced.
          The multi-page state exhibit goes to Appendix A via \includepdf.

          v2 (09/10/2026). Rewritten for the revised exhibit set. Moved title
	  and source note out of every exhibit so they live in the figure notes
	  instead. So each exhibit now carries a short hand-written \caption{} 
	  plus a Notes paragraph read from prism_tier2_exhibit_notes.csv, which the notebook
          writes from the same strings it used to print inside the figures. The
          captions cannot drift from the figures that way.

          DO NOT UNDO (each of these cost a debugging round on 8/28):
            - encoding("utf-8") on every import delimited. Without it Stata
              reads the UTF-8 CSVs as Latin-1 and re-emits them double-encoded,
              which pdflatex rejects.
            - xcolor BEFORE pdfpages in the preamble; pdfpages loads xcolor with
              no options and the two clash otherwise.
            - No dollar signs in any tex line: Stata expands them as global
              macros. Use \ensuremath{\geq}, never $\geq$.
            - No literal backticks in tex lines; Stata reads them as macro opens.
            - The \DeclareUnicodeCharacter block is required.
            - pdflatex -interaction=nonstopmode, or a LaTeX error hangs Stata
              waiting for keyboard input with no visible cause.
            - Exhibits are COPIED into the report folder, not linked by absolute
              path, so old reports still render after a later notebook run.
*******************************************************************************/

clear all
set more off

* texdoc is required; install once if this is a fresh Stata install.
capture which texdoc
if _rc ssc install texdoc, replace

*------------------------------------------------------------------------------
* 0. Paths
*------------------------------------------------------------------------------
if "$path" == "" {
    di as error "Global \$path is not set. Run _project_main.do, or set it here."
    exit 198
}

global fig1 "$path/figures/weather/tier1"
global fig2 "$path/figures/weather/tier2"
global tab1 "$path/tables/weather/tier1"
global tab2 "$path/tables/weather/tier2"

* Date stamp (Eyal's convention, minus the DD prefix -- this is not a diff-in-diff)
local string_sysdate: di %td_CCYY_NN_DD date(c(current_date), "DMY")
local string_sysdate = subinstr("`string_sysdate'", " ", "_", .)

cap mkdir "$path/reports"
cap mkdir "$path/reports/WeatherData"
local outdir "$path/reports/WeatherData/report_`string_sysdate'"
cap mkdir "`outdir'"
cap mkdir "`outdir'/exhibits"

*------------------------------------------------------------------------------
* 1. Verify every exhibit this report expects is on disk, and warn about any
*    Tier 2 exhibit on disk that this report does not include.
*------------------------------------------------------------------------------
local expected ///
    prism_national_long_run_warming.pdf ///
    prism_national_long_run_warming_area_weighted.pdf ///
    prism_state_trends_pooled.pdf ///
    prism_state_trends_pooled_by_region.pdf ///
    prism_winter_warming_data_section.pdf ///
    prism_mean_winter_temperature.pdf ///
    prism_winter_temperature_early_vs_recent.pdf ///
    prism_winter_temperature_change.pdf ///
    prism_extreme_cold_day_count.pdf ///
    prism_extreme_cold_early_recent_change.pdf ///
    prism_anomalous_warm_winter_frequency_1sd.pdf ///
    prism_anomalous_warm_winter_time_series_1sd.pdf ///
    prism_anomalous_warm_winter_frequency_2sd.pdf ///
    prism_anomalous_warm_winter_time_series_2sd.pdf ///
    prism_national_winter_temperature_deviations_by_decade.pdf ///
    prism_national_winter_temperature_deviations_by_decade_area_weighted.pdf ///
    prism_cross_season_anomaly_correlation.pdf ///
    prism_cross_season_trend_correlation.pdf ///
    prism_era5_national_winter_temperature_comparison.pdf ///
    prism_era5_national_winter_temperature_comparison_area_weighted.pdf ///
    prism_state_long_run_warming.pdf

* The Winter Severity Index exhibits read the merged county-year panel, which is
* another pipeline's output. If build_main_data_county_year.do has not been run,
* the notebook skips them and the report drops that section rather than failing.
local optional ///
    prism_winter_severity_index.pdf ///
    prism_winter_severity_index_sensitivity.pdf

local missing ""
foreach f of local expected {
    cap confirm file "$fig2/`f'"
    if _rc local missing "`missing' `f'"
}
if "`missing'" != "" {
    di as error "Missing Tier 2 exhibits:`missing'"
    di as error "Re-run codePYTHON/09_descriptive_weather_full.ipynb before this do-file."
    exit 601
}

local have_wsi = 1
foreach f of local optional {
    cap confirm file "$fig2/`f'"
    if _rc local have_wsi = 0
}
if `have_wsi' == 0 {
    di as text "NOTE: Winter Severity Index exhibits not found -- that section is omitted."
    di as text "      Run codeSTATA/build_main_data_county_year.do, then re-run the notebook."
}

foreach f of local expected {
    copy "$fig2/`f'" "`outdir'/exhibits/`f'", replace
}
if `have_wsi' {
    foreach f of local optional {
        copy "$fig2/`f'" "`outdir'/exhibits/`f'", replace
    }
}

local ondisk : dir "$fig2" files "*.pdf"
foreach f of local ondisk {
    local inreport : list f in expected
    local inoptional : list f in optional
    if `inreport' == 0 & `inoptional' == 0 {
        di as text "NOTE: `f' is in figures/weather/tier2 but not in this report."
    }
}

*------------------------------------------------------------------------------
* 1b. Load the per-exhibit notes the notebook wrote.
*     Stored in numbered globals because exhibit filenames run well past Stata's
*     32-character limit on macro names.
*------------------------------------------------------------------------------
import delimited using "$tab2/prism_tier2_exhibit_notes.csv", ///
    varnames(1) stringcols(_all) bindquote(strict) encoding("utf-8") clear

global NOTEFILES ""
forvalues i = 1/`=_N' {
    local f = filename[`i']
    global NOTEFILES "$NOTEFILES `f'"
    global NOTE`i' = note[`i']
}
di as text "Loaded `=_N' exhibit notes."

* One exhibit block: figure, short caption, then the notebook's own note.
capture program drop exhibitblock
program define exhibitblock
    args fname caption
    local flist "$NOTEFILES"
    local pos : list posof "`fname'" in flist
    local note ""
    if `pos' > 0 local note "${NOTE`pos'}"

    * LaTeX escaping. The unicode the exhibits emit is handled by the
    * \DeclareUnicodeCharacter block in the preamble, so only these four matter.
    foreach v in caption note {
        local `v' : subinstr local `v' "_" "\_", all
        local `v' : subinstr local `v' "&" "\&", all
        local `v' : subinstr local `v' "%" "\%", all
        local `v' : subinstr local `v' "#" "\#", all
    }

    tex \begin{figure}[H]
    tex \centering
    tex \includegraphics[width=\textwidth]{\figTwo/`fname'}
    tex \caption{`caption'}
    tex \end{figure}
    if "`note'" != "" {
        tex \vspace{-6pt}
        tex {\footnotesize\textit{Notes.} `note'\par}
    }
    tex \clearpage
end

*------------------------------------------------------------------------------
* 2. Preamble
*------------------------------------------------------------------------------
local file_name "`outdir'/report_`string_sysdate'.tex"
texdoc init "`file_name'", replace force

tex \documentclass[11pt, english, letterpaper]{article}
tex \usepackage[T1]{fontenc}
tex \usepackage[utf8]{inputenc}
tex \usepackage{textcomp}
tex \usepackage{lmodern}
tex \usepackage{graphicx}
tex \usepackage[usenames,dvipsnames,table]{xcolor}
tex % xcolor must come before pdfpages, which loads it with no options.
tex \usepackage{pdfpages}
tex \usepackage[margin=0.9in]{geometry}
tex \usepackage{babel}
tex \usepackage{caption}
tex \usepackage{float}
tex \usepackage{longtable}
tex \usepackage{booktabs}
tex \usepackage{tabularx}
tex \usepackage[shortlabels]{enumitem}
tex \usepackage{url}
tex \usepackage[colorlinks=true, linkcolor=black, urlcolor=black, citecolor=black,
tex             linkbordercolor={white}, anchorcolor=black]{hyperref}
tex %
tex % Glyphs the Python exhibits emit that pdflatex does not map by default.
tex % \ensuremath is used instead of dollar-sign math: Stata would try to expand
tex % anything after a dollar sign as a global macro.
tex \DeclareUnicodeCharacter{2265}{\ensuremath{\geq}}
tex \DeclareUnicodeCharacter{2264}{\ensuremath{\leq}}
tex \DeclareUnicodeCharacter{00D7}{\ensuremath{\times}}
tex \DeclareUnicodeCharacter{2212}{--}
tex \DeclareUnicodeCharacter{2013}{--}
tex \DeclareUnicodeCharacter{2014}{---}
tex \DeclareUnicodeCharacter{00B0}{\textdegree}
tex \DeclareUnicodeCharacter{00B2}{\textsuperscript{2}}
tex \DeclareUnicodeCharacter{2018}{\textquoteleft}
tex \DeclareUnicodeCharacter{2019}{\textquoteright}
tex \DeclareUnicodeCharacter{201C}{\textquotedblleft}
tex \DeclareUnicodeCharacter{201D}{\textquotedblright}
tex \DeclareUnicodeCharacter{03C3}{\ensuremath{\sigma}}
tex %
tex \pdfminorversion=6
tex \linespread{1.15}
tex \def\arraystretch{1.25}
tex \captionsetup{font=small, labelfont=bf, justification=raggedright, singlelinecheck=false}
tex \setlength{\parskip}{6pt}
tex \setlength{\parindent}{0pt}
tex %
tex % Exhibits live beside this .tex, so the folder compiles anywhere.
tex \newcommand*{\figTwo}{exhibits}%
tex %
tex \begin{document}

*------------------------------------------------------------------------------
* 3. Title page
*------------------------------------------------------------------------------
local prettydate = subinstr("`string_sysdate'", "_", "-", .)

tex \title{Winter Weather Panel: Descriptive Report\\[4pt]
tex \large PRISM county--month data, 1981--2025 \\[2pt]
tex \normalsize Version 2}
tex \date{`prettydate'}
tex \maketitle
tex \thispagestyle{empty}
tex \vspace{-1em}
tex \begin{center}\begin{minipage}{0.86\textwidth}\small
tex \textbf{Provenance.} All exhibits generated by
tex \path{codePYTHON/09_descriptive_weather_full.ipynb}, executed on Kodama against the
tex complete PRISM county-month panel. Figures are vector PDFs reproduced without
tex rescaling of content. Tier~1 QA exhibits are indexed in Appendix~B rather than
tex reproduced.
tex \par\vspace{6pt}
tex \textbf{What changed since the 2026-08-28 report.} Titles and source notes have been
tex removed from the images and the notes now appear beneath each figure; map legends are
tex horizontal and sit at lower left; state borders are drawn in black. New exhibits: all
tex state trends pooled into one figure, a Data-section composite, a full-sample mean
tex winter temperature map, an early/recent/change treatment of extreme-cold days, the
tex Winter Severity Index, area-weighted companions to the national exhibits, and the
tex cross-season anomaly and trend comparisons.
tex \par\vspace{6pt}
tex \textbf{One definition changed.} The warm-anomaly exhibits previously flagged a
tex \emph{detrended} residual above 1.5 SD. They now use the same construction as
tex \path{warm_winter_1sd} and \path{warm_winter_2sd} in the merged county-year panel:
tex the raw winter mean above the county's own full-sample mean by one or two standard
tex deviations. The figures and the regression table therefore describe the same object.
/*tex Section~\ref{sec:decisions} lists this and the remaining choices requiring a decision.*/
tex \end{minipage}\end{center}
tex \newpage
tex \tableofcontents
tex \newpage

*------------------------------------------------------------------------------
* 4. Section 1 -- coverage and integrity (driven by the Tier 1 CSVs)
*------------------------------------------------------------------------------
tex \section{Coverage and data integrity}
tex The panel is complete: no duplicate keys, no unmatched rows across the monthly
tex and derived files, no incomplete county-months, and no QA-field mismatches. The
tex excluded county-winters are exactly the two boundary winters that cannot be
tex complete, not unexplained missingness.
tex \par

import delimited using "$tab1/prism_tier1_coverage_integrity.csv", ///
    varnames(1) stringcols(_all) bindquote(strict) encoding("utf-8") clear

tex \begin{longtable}{@{}lr@{}}
tex \caption{Coverage and integrity diagnostics}\\
tex \toprule Metric & Value \\ \midrule \endfirsthead
tex \toprule Metric & Value \\ \midrule \endhead
tex \bottomrule \endfoot
forvalues i = 1/`=_N' {
    local m = metric[`i']
    local v = value[`i']
    local m : subinstr local m "_" " ", all
    tex `m' & `v' \\
}
tex \end{longtable}

import delimited using "$tab1/prism_tier1_qa_findings.csv", ///
    varnames(1) stringcols(_all) bindquote(strict) encoding("utf-8") clear

tex \begin{longtable}{@{}lrl@{}}
tex \caption{Tier 1 QA findings}\\
tex \toprule Check & Result & Status \\ \midrule \endfirsthead
tex \toprule Check & Result & Status \\ \midrule \endhead
tex \bottomrule \endfoot
forvalues i = 1/`=_N' {
    local c = check[`i']
    local r = result[`i']
    local s = status[`i']
    local c : subinstr local c "_" "\_", all
    local c : subinstr local c "&" "\&", all
    local c : subinstr local c "%" "\%", all
    tex `c' & `r' & `s' \\
}
tex \end{longtable}
tex \clearpage

*------------------------------------------------------------------------------
* 5. Exhibit sections
*    EDIT THE SHORT CAPTIONS HERE after reading the new run. The Notes paragraph
*    under each figure comes from the notebook and should be edited there.
*------------------------------------------------------------------------------
tex \section{Long-run winter warming}

exhibitblock "prism_national_long_run_warming.pdf" ///
    "National mean winter temperature, 1982--2025, with a fitted linear trend."

exhibitblock "prism_national_long_run_warming_area_weighted.pdf" ///
    "The same series with counties weighted by land area. The two answer different questions and both are reported."

exhibitblock "prism_state_trends_pooled.pdf" ///
    "Every state's fitted winter-temperature trend in one figure. States differ in both level and slope."

exhibitblock "prism_state_trends_pooled_by_region.pdf" ///
    "The same trends coloured by EPA climate-impact region."

tex State-level trends are reproduced panel by panel in Appendix~\ref{app:states}.
tex \clearpage

tex \section{Where winters have warmed}

exhibitblock "prism_winter_warming_data_section.pdf" ///
    "Proposed Data-section figure: the change between the two periods above, the two period means below."

exhibitblock "prism_mean_winter_temperature.pdf" ///
    "Mean winter temperature over the full sample -- the climatology the anomaly measures are taken against."

exhibitblock "prism_winter_temperature_early_vs_recent.pdf" ///
    "Mean winter temperature in the early and recent decades, on a shared colour scale."

exhibitblock "prism_winter_temperature_change.pdf" ///
    "Change in mean winter temperature between the two periods."

tex \section{Winter cold extremes}

exhibitblock "prism_extreme_cold_day_count.pdf" ///
    "Mean count of winter days with a daily minimum below 0\textdegree F."

exhibitblock "prism_extreme_cold_early_recent_change.pdf" ///
    "Extreme-cold days in the early and recent decades, and the change between them."

if `have_wsi' {
    tex \section{Winter Severity Index}

    exhibitblock "prism_winter_severity_index.pdf" ///
        "Mean Winter Severity Index (Kohn 1975 / Wisconsin DNR), read from the merged county-year panel."

    exhibitblock "prism_winter_severity_index_sensitivity.pdf" ///
        "The index under Kohn's 18-inch snow threshold and under a 12-inch alternative, on a shared scale."
}

tex \section{Anomalously warm winters}
tex \label{sec:anom}
tex Two thresholds are shown rather than one, and each map is paired with its own
tex time series. The construction matches \path{warm_winter_1sd} and
tex \path{warm_winter_2sd} in the merged county-year panel.
tex \par

exhibitblock "prism_anomalous_warm_winter_frequency_1sd.pdf" ///
    "Share of a county's winters more than one standard deviation above its own mean."

exhibitblock "prism_anomalous_warm_winter_time_series_1sd.pdf" ///
    "Share of counties flagged at one standard deviation, by winter year."

exhibitblock "prism_anomalous_warm_winter_frequency_2sd.pdf" ///
    "The same map at a two-standard-deviation threshold. Note the independent colour scale."

exhibitblock "prism_anomalous_warm_winter_time_series_2sd.pdf" ///
    "Share of counties flagged at two standard deviations, by winter year."

tex \section{Distributional shift}

exhibitblock "prism_national_winter_temperature_deviations_by_decade.pdf" ///
    "County-winter temperatures by period, after subtracting each county's own full-sample mean."

exhibitblock "prism_national_winter_temperature_deviations_by_decade_area_weighted.pdf" ///
    "The same distributions with counties weighted by land area."

tex \section{Winter warming relative to the other seasons}
tex Whether knowing how much a county warmed in summer tells us how much it warmed
tex in winter. If the seasons had moved together, these would lie on the 45-degree
tex line.
tex \par

exhibitblock "prism_cross_season_anomaly_correlation.pdf" ///
    "Winter temperature anomaly against the same year's spring, summer and fall anomalies."

exhibitblock "prism_cross_season_trend_correlation.pdf" ///
    "County winter warming trend against that county's spring, summer and fall trends."

tex \section{Robustness: PRISM versus ERA5}

exhibitblock "prism_era5_national_winter_temperature_comparison.pdf" ///
    "National winter temperature from both products. PRISM is the analysis dataset."

exhibitblock "prism_era5_national_winter_temperature_comparison_area_weighted.pdf" ///
    "The same comparison with counties weighted by land area."


/*
*------------------------------------------------------------------------------
* 6. Decisions requested (driven by the Tier 2 CSV)
*------------------------------------------------------------------------------
tex \section{Decisions requested}
tex \label{sec:decisions}

import delimited using "$tab2/prism_tier2_decisions_for_eyal.csv", ///
    varnames(1) stringcols(_all) bindquote(strict) encoding("utf-8") clear

forvalues i = 1/`=_N' {
    local d = decision[`i']
    local c = current_choice[`i']
    local s = status[`i']
    local u = issue[`i']
    foreach v in d c s u {
        local `v' : subinstr local `v' "_" "\_", all
        local `v' : subinstr local `v' "&" "\&", all
        local `v' : subinstr local `v' "%" "\%", all
    }
    tex \subsection*{`d'}
    tex \textbf{Current choice.} `c'\par
    tex \textbf{Issue.} `u'\par
    tex \textbf{Status.} `s'
}
tex \clearpage

*/

*------------------------------------------------------------------------------
* 7. Appendices
*------------------------------------------------------------------------------
tex \appendix
tex \section{State-level winter-temperature trends}
tex \label{app:states}
tex Per-state annual means with state-specific linear trends and the standard error
tex of each slope. Reproduced in full; page count follows the run. Y-axis ranges
tex differ by panel deliberately -- a common range across states whose mean winter
tex temperature spans roughly 40\textdegree C would flatten every trend to invisibility.
tex \includepdf[pages=-]{\figTwo/prism_state_long_run_warming.pdf}

tex \section{Tier 1 QA artefacts (not reproduced)}
tex The following internal QA exhibits and tables were produced by the same run and
tex are available on request. This includes the pooled-level distribution exhibit,
tex which was demoted from the report set, and the detrended warm-anomaly diagnostic.
tex \begin{itemize}[leftmargin=*,itemsep=1pt]
local t1figs : dir "$fig1" files "*.pdf"
foreach f of local t1figs {
    tex \item \path{figures/weather/tier1/`f'}
}
local t1tabs : dir "$tab1" files "*.csv"
foreach f of local t1tabs {
    tex \item \path{tables/weather/tier1/`f'}
}
tex \end{itemize}

tex \end{document}
texdoc close

*------------------------------------------------------------------------------
* 8. Compile. Twice: the first pass writes the .aux, the second resolves the
*    table of contents and the \ref cross-references.
*    -interaction=nonstopmode matters: without it a LaTeX error makes pdflatex
*    wait for keyboard input and Stata hangs with no visible reason.
*------------------------------------------------------------------------------
* A one-command compile script, so the folder can be built on any machine
* with LaTeX if this server has none.
file open sh using "`outdir'/compile.sh", write replace
file write sh "#!/bin/sh" _n
file write sh "# Run this from inside this folder. Twice: pass 1 writes the .aux," _n
file write sh "# pass 2 resolves the contents page and cross-references." _n
file write sh "pdflatex -interaction=nonstopmode report_`string_sysdate'.tex" _n
file write sh "pdflatex -interaction=nonstopmode report_`string_sysdate'.tex" _n
file close sh

cd "`outdir'"
shell pdflatex -interaction=nonstopmode "report_`string_sysdate'.tex"
shell pdflatex -interaction=nonstopmode "report_`string_sysdate'.tex"

cap confirm file "`outdir'/report_`string_sysdate'.pdf"
if _rc {
    di as error "No PDF produced. Either pdflatex is not installed on this server"
    di as error "(check: which pdflatex), or LaTeX errored -- see report_`string_sysdate'.log."
    di as error ""
    di as error "The report folder is self-contained: .tex plus every exhibit it needs."
    di as error "Copy `outdir' to any machine with LaTeX and run compile.sh,"
    di as error "or upload the folder to Overleaf."
}
else {
    di as result "Report written to `outdir'/report_`string_sysdate'.pdf"
}
