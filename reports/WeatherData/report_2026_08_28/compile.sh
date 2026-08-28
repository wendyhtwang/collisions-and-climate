#!/bin/sh
# Run from inside this folder. Twice: pass 1 writes the .aux, pass 2 resolves
# the table of contents and cross-references.
pdflatex -interaction=nonstopmode report_2026_08_28.tex
pdflatex -interaction=nonstopmode report_2026_08_28.tex
