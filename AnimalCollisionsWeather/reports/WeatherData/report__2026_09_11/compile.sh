#!/bin/sh
# Run this from inside this folder. Twice: pass 1 writes the .aux,
# pass 2 resolves the contents page and cross-references.
pdflatex -interaction=nonstopmode report__2026_09_11.tex
pdflatex -interaction=nonstopmode report__2026_09_11.tex
