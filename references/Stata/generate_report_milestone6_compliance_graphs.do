/*******************************************************************************
Program: generate_report_milestone6_compliance_graphs.do
*******************************************************************************/

cap log close
clear all
set more off, permanently
set matsize 11000
set maxvar 32767
set scheme s1mono


global path "D:/Dropbox/Research/Rebuilding Stocks"

* Get the date of making the report 
local string_sysdate: di %td_CCYY_NN_DD date(c(current_date), "DMY")
local string_sysdate = subinstr("`string_sysdate'", " ", "_", .)
* Create a folder 
cap mkdir "$path/reports/Milestone 6/report_DD`string_sysdate'", public 

* Create a new report file 
local file_name = "$path/reports/Milestone 6/report_DD`string_sysdate'/report_`string_sysdate'.tex"
texdoc init "`file_name'", replace force

* Write the header of the file 
tex \documentclass[12pt, english, letterpaper]{article}
tex \usepackage[T1]{fontenc}
tex \usepackage{textcomp}
tex \usepackage{lmodern}
tex \usepackage{graphicx}
tex \usepackage[usenames,dvipsnames,table]{xcolor}
tex \usepackage[margin=0.1in]{geometry}
tex \usepackage{babel}
tex \usepackage{gensymb}
tex \usepackage{multicol}
tex \usepackage{caption}
tex \usepackage{subcaption}
tex \usepackage{xtab}  
tex \usepackage{float}
tex \usepackage{longtable}
tex \usepackage{booktabs}
tex \usepackage{tabularx}
tex \usepackage{threeparttable}
tex \usepackage{tabulary}
tex \usepackage{pdflscape}
tex \usepackage[shortlabels]{enumitem}
tex \usepackage[colorlinks = true,
tex             linkcolor = black,
tex             urlcolor  = black,
tex             citecolor = black,
tex             linkbordercolor = {white},
tex             anchorcolor = black]{hyperref}
tex \usepackage[document]{ragged2e}
tex 
tex \pdfminorversion=6
tex \linespread{1.6} % Spacing of lines 
tex \def\arraystretch{1.3} % Spacing of table rows 
tex \setlength{\tabcolsep}{12pt} % Spacing of table columns
tex 
tex \newcommand*{\rootDir}{$path}%
tex \newcommand*{\figuresPath}{\rootDir/figures}% 
tex \begin{document}
tex 
tex \title{`sysdate' Report}
tex \author{Test}
tex \maketitle
tex \tableofcontents
tex \newpage 

* Compliance
tex \section{Surplus Quota \% graphs for each U.S. Stock}

forvalues i = 1(6)67{
	tex 	\begin{figure}[htb]
	tex     \centering
	if(`i' != 67){
		forvalues j = 0(2)4{
				local a = `i' + `j'
				local b = `a' + 1
				tex		\begin{subfigure}[b]{0.5\textwidth}
				tex 	
				tex     	\includegraphics[width=1\textwidth]{\figuresPath/compliance/quota_surplus_percent_`a'}
				tex     	\label{}
				tex 	\end{subfigure}\hspace*{\fill}
				tex		\begin{subfigure}[b]{0.5\textwidth}
				tex 	
				tex     	\includegraphics[width=1\textwidth]{\figuresPath/compliance/quota_surplus_percent_`b'}
				tex     	\label{}
				tex 	\end{subfigure}
				tex 	
		}
	}	
	if(`i' == 67){
		tex		\begin{subfigure}[b]{0.5\textwidth}
		tex 	
		tex     	\includegraphics[width=1\textwidth]{\figuresPath/compliance/quota_surplus_percent_67}
		tex     	\label{}
		tex 	\end{subfigure}\hspace*{\fill}
		tex		\begin{subfigure}[b]{0.5\textwidth}
		tex 	
		tex     	\includegraphics[width=1\textwidth]{\figuresPath/compliance/quota_surplus_percent_68}
		tex     	\label{}
		tex 	\end{subfigure}
		tex		\begin{subfigure}[b]{0.5\textwidth}
		tex 	
		tex     	\includegraphics[width=1\textwidth]{\figuresPath/compliance/quota_surplus_percent_69}
		tex     	\label{}
		tex 	\end{subfigure}\hspace*{\fill}
	}
	tex \end{figure}  
	tex \clearpage 
	tex \newpage 
}

tex \section{Percent Change in Biomass and Mean Surplus Quota \% graphs after MSA events}
foreach event in determinedoverfished enteredrebuilding{
	tex 	\begin{figure}[htb]
	tex     \centering
	tex		\begin{subfigure}[b]{0.5\textwidth}
	tex 	
	tex     	\includegraphics[width=1\textwidth]{\figuresPath/compliance/biomass_change_quota_deviation_`event'_5}
	tex     	\label{}
	tex 	\end{subfigure}\hspace*{\fill}
	tex		\begin{subfigure}[b]{0.5\textwidth}
	tex
	tex     	\includegraphics[width=1\textwidth]{\figuresPath/compliance/biomass_change_quota_deviation_`event'_10}
	tex     	\label{}
	tex 	\end{subfigure}
	tex \end{figure}  
	tex \clearpage 
	tex \newpage
}








tex \end{document}
texdoc close 

* Compile to pdf 
* 1st run -> PDF, 2nd run -> table of contents 
cd "$path/reports/Milestone 6/report_DD`string_sysdate'/"
shell pdflatex "$path/reports/Milestone 6/report_DD`string_sysdate'/report_`string_sysdate'.tex"
shell pdflatex "$path/reports/Milestone 6/report_DD`string_sysdate'/report_`string_sysdate'.tex"

