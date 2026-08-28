/*******************************************************************************
Program:  10_generate_weather_report.do
Purpose:  Knit the Tier 2 exhibits from 09_descriptive_weather_full.ipynb into a
          single PI-ready PDF report, using texdoc + pdflatex.

Inputs:   $path/figures/weather/tier2/*.pdf   (exhibits)
          $path/tables/weather/tier1/*.csv    (coverage, QA findings)
          $path/tables/weather/tier2/*.csv    (decisions, anomaly caveats)
Output:   $path/reports/WeatherData/report_YYYY_MM_DD/report_YYYY_MM_DD.pdf

Notes:    Tier 1 QA exhibits are indexed in Appendix B, not reproduced -- they
          are internal QA, and embedding them adds ~40 pages nobody reads.
          The multi-page state exhibit goes to Appendix A via \includepdf.

          Run AFTER 09_descriptive_weather_full.ipynb has finished on Kodama.
*******************************************************************************/

cap log close
clear all
set more off, permanently

* texdoc is required; install once if this is a fresh Stata install.
cap which texdoc
if _rc ssc install texdoc

*------------------------------------------------------------------------------
* 0. Paths
*------------------------------------------------------------------------------
global path "/mnt/data_d/Dropbox/Research/AnimalCollisionsWeather"

global fig1 "$path/figures/weather/tier1"
global fig2 "$path/figures/weather/tier2"
global tab1 "$path/tables/weather/tier1"
global tab2 "$path/tables/weather/tier2"

* Date stamp (Eyal's convention, minus the DD prefix -- this is not a diff-in-diff)
local string_sysdate: di %td_CCYY_NN_DD date(c(current_date), "DMY")
local string_sysdate = subinstr("`string_sysdate'", " ", "_", .)

cap mkdir "$path/reports"
cap mkdir "$path/reports/WeatherData"
cap mkdir "$path/reports/WeatherData/report_`string_sysdate'"
local outdir "$path/reports/WeatherData/report_`string_sysdate'"
local file_name "`outdir'/report_`string_sysdate'.tex"

* Exhibits are COPIED into the report folder rather than linked by absolute
* path. Three reasons: the folder stays renderable after a later notebook run
* overwrites figures/ (Eyal wants old reports to stay comparable); it can be
* compiled on any machine, including Overleaf, without editing paths; and it
* survives being moved or zipped.
cap mkdir "`outdir'/exhibits"

*------------------------------------------------------------------------------
* 1. Verify every exhibit this report expects is actually on disk, and warn
*    about any Tier 2 exhibit on disk that this report does not include.
*------------------------------------------------------------------------------
local expected ///
    prism_national_long_run_warming.pdf ///
    prism_state_long_run_warming.pdf ///
    prism_winter_temperature_early_vs_recent.pdf ///
    prism_winter_temperature_change.pdf ///
    prism_extreme_cold_day_count.pdf ///
    prism_anomalous_warm_winter_frequency_provisional.pdf ///
    prism_anomalous_warm_winter_time_series_provisional.pdf ///
    prism_national_winter_temperature_distributions_by_decade.pdf ///
    prism_national_winter_temperature_deviations_by_decade.pdf ///
    prism_era5_national_winter_temperature_comparison.pdf

local missing ""
foreach f of local expected {
    cap confirm file "$fig2/`f'"
    if _rc local missing "`missing' `f'"
}
if "`missing'" != "" {
    di as error "Missing Tier 2 exhibits:`missing'"
    di as error "Run 09_descriptive_weather_full.ipynb to completion first."
    exit 601
}

foreach f of local expected {
    copy "$fig2/`f'" "`outdir'/exhibits/`f'", replace
}

local ondisk : dir "$fig2" files "*.pdf"
foreach f of local ondisk {
    local hit : list f in expected
    if !`hit' di as txt "NOTE: `f' exists but is not included in the report."
}

*------------------------------------------------------------------------------
* 2. Preamble
*------------------------------------------------------------------------------
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
tex \large PRISM county--month data, 1981--2025}
tex \author{Wendy Wang}
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
tex \textbf{Status.} The warm-anomaly exhibits in Section~\ref{sec:anom} are
tex \textbf{provisional} pending confirmation of the anomaly definition.
tex Section~\ref{sec:decisions} lists the choices requiring a decision.
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
*    EDIT THE CAPTIONS HERE after reading the new run -- one block per exhibit.
*------------------------------------------------------------------------------
tex \section{Long-run winter warming}
tex \begin{figure}[H]
tex \centering
tex \includegraphics[width=\textwidth]{\figTwo/prism_national_long_run_warming.pdf}
tex \caption{National winter temperature, 1982--2025. Each point is the unweighted
tex mean across counties, so the estimand is the average county rather than an area-
tex or population-weighted national average. The fitted slope is shown with its
tex standard error.}
tex \end{figure}
tex State-level trends are reproduced in Appendix~\ref{app:states}.
tex \clearpage

tex \section{Where winters have warmed}
tex \begin{figure}[H]
tex \centering
tex \includegraphics[width=\textwidth]{\figTwo/prism_winter_temperature_early_vs_recent.pdf}
tex \caption{Mean winter temperature in the early (1982--1991) and recent
tex (2016--2025) periods, on identical colour limits. Both panels are ten-winter
tex period means, not single-year endpoints.}
tex \end{figure}
tex \clearpage

tex \begin{figure}[H]
tex \centering
tex \includegraphics[width=\textwidth]{\figTwo/prism_winter_temperature_change.pdf}
tex \caption{Change in mean winter temperature between the two periods. The
tex diverging scale is centred at zero, so the map shows both the breadth of warming
tex and its regional heterogeneity.}
tex \end{figure}
tex \clearpage

tex \section{Cold extremes}
tex \begin{figure}[H]
tex \centering
tex \includegraphics[width=\textwidth]{\figTwo/prism_extreme_cold_day_count.pdf}
tex \caption{Mean count of winter days with a daily minimum below
tex 0\textdegree F. This is the extreme-cold measure only; it is not a Winter
tex Severity Index.}
tex \end{figure}
tex \clearpage

tex \section{Anomalously warm winters}
tex \label{sec:anom}
tex \begin{figure}[H]
tex \centering
tex \includegraphics[width=\textwidth]{\figTwo/prism_anomalous_warm_winter_frequency_provisional.pdf}
tex \caption{\textbf{Provisional.} Share of a county's eligible winters classified
tex as anomalously warm, defined as a detrended residual above 1.5 standard
tex deviations of that county's own full-sample distribution.}
tex \end{figure}
tex \clearpage

tex \begin{figure}[H]
tex \centering
tex \includegraphics[width=\textwidth]{\figTwo/prism_anomalous_warm_winter_time_series_provisional.pdf}
tex \caption{\textbf{Provisional.} Share of counties classified as anomalously warm
tex in each winter. Because each county's linear trend is removed, this isolates
tex episodic shocks from gradual warming.}
tex \end{figure}
tex \clearpage

tex \subsection*{Known properties of the provisional definition}

import delimited using "$tab2/prism_anomaly_definition_caveats.csv", ///
    varnames(1) stringcols(_all) bindquote(strict) encoding("utf-8") clear

tex \begin{enumerate}[leftmargin=*]
forvalues i = 1/`=_N' {
    local c = caveat[`i']
    local c : subinstr local c "_" "\_", all
    local c : subinstr local c "&" "\&", all
    local c : subinstr local c "%" "\%", all
    tex \item `c'
}
tex \end{enumerate}
tex \clearpage

tex \section{Distributional shift}
tex \begin{figure}[H]
tex \centering
tex \includegraphics[width=\textwidth]{\figTwo/prism_national_winter_temperature_distributions_by_decade.pdf}
tex \caption{County-winter mean temperatures pooled by period. Periods contain
tex unequal numbers of winters, and the pooled spread is dominated by persistent
tex cross-county geography, which compresses the apparent temporal shift.}
tex \end{figure}
tex \clearpage

tex \begin{figure}[H]
tex \centering
tex \includegraphics[width=\textwidth]{\figTwo/prism_national_winter_temperature_deviations_by_decade.pdf}
tex \caption{The same periods after subtracting each county's own full-sample mean.
tex Removing persistent geography isolates the within-county shift, which is the
tex quantity of interest.}
tex \end{figure}
tex \clearpage

tex \section{Robustness: PRISM versus ERA5}
tex \begin{figure}[H]
tex \centering
tex \includegraphics[width=\textwidth]{\figTwo/prism_era5_national_winter_temperature_comparison.pdf}
tex \caption{National winter temperature from both products. PRISM is the analysis
tex dataset; ERA5 is a targeted robustness check. The mean offset and correlation are
tex reported on the figure.}
tex \end{figure}
tex \clearpage

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

*------------------------------------------------------------------------------
* 7. Appendices
*------------------------------------------------------------------------------
tex \appendix
tex \section{State-level winter-temperature trends}
tex \label{app:states}
tex Per-state annual means with state-specific linear trends and the standard error
tex of each slope. Reproduced in full; page count follows the run.
tex \includepdf[pages=-]{\figTwo/prism_state_long_run_warming.pdf}

tex \section{Tier 1 QA artefacts (not reproduced)}
tex The following internal QA exhibits and tables were produced by the same run and
tex are available on request.
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
