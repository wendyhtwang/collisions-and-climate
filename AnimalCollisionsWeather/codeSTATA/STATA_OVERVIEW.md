# codeSTATA script overview

Reference doc for the Stata half of the pipeline -- mirrors
`codePYTHON/SCRIPT_OVERVIEW.md`'s role for the Python half.

Naming follows the project style guide (`style guide.md`, Section 2):
`_project_main.do` is the master file (leading underscore = standalone /
special, sorts to the top). Every other file is a verb-first name describing
what it does; there is no numeric pipeline prefix on the Stata side except
`10_generate_weather_report.do`, kept numbered because it is a late, fixed
step that must run after both Python descriptive tiers and reads their
numbered outputs directly.

**What actually runs end to end** is `_project_main.do` -- every other file
below is either called by it or run standalone for a one-off check.

## Master file

### `_project_main.do`
Lists every production stage of the pipeline in the order it has to run.
Design decisions live in the child scripts, not here. Cut down 09/17/26 to
one or two lines per step, and again 09/18/26 to production calls only --
package installs, validators and diagnostics were moved into this file.
- Sections: 0 Setup, 1 User-written packages (a pointer, see below),
  2 Preparing data, 3 Descriptive data analysis, 4 Regression estimation,
  5 Main analysis tables & figures. Section headers use the style guide's
  `* SECTION n:` rule-line form so `grep "SECTION"` jumps around the whole
  repo, not just one file.
- SECTION 2 order: 2.1 weather extraction (Earth Engine, commented out --
  one-time multi-hour jobs, re-enable by hand) -> 2.2 aggregation and
  derived variables (05, 06, 06c) -> 2.3 population (08a, 08b) ->
  2.4 provenance only -> 2.5 `build_main_data_county_year.do`. 2.2 runs
  `06c_build_winter_severity.py`, so neither the merge nor the Phase 4
  exhibits build the Winter Severity Index themselves.
- SECTION 2.4 is a comment, not a step (settled 9/18/26). The ungulate and
  collisions repos each produce a ready-to-merge county-year panel that is
  copied into this project; this file runs nothing in either repo, and 2.5
  merges the copies on geoid-year without further cleaning.
- SECTION 4 runs `estimates_generate_collisions_weather.do` and the three
  `regression_*.do` harvest files. SECTION 5 runs only
  `estimates_tables_collisions_weather.do` -- the three harvest files write
  their own `.tex` directly, so they have nothing in SECTION 5. The three
  set `global root` themselves; `$path` set in SECTION 0 does not reach
  them. Same tree on Kodama, so it runs. Flagged 9/15/26 for review.
- `$path` resolution tries the Dropbox root first, then `C:/`/`D:/`, then
  errors if none exist -- matches the style guide's header template
  exactly so every child `.do` can be run standalone with the same guard.

#### Not called by the master file
Run these by hand; none produce pipeline output.
- `06b_validate_ppt_total.py` -- gate: 05 and 06 compute monthly
  precipitation totals independently and must agree exactly. Exits non-zero
  on mismatch. `--dataset ERA5` for ERA5. Worth running after any change to
  05 or 06.
- `check_animal_deer_backfill.do` -- diagnostic on the merged panel, writes
  `$tables/checks/animal_deer_backfill_violations.csv`.
- `07a`-`07h` -- ground-truth chain, PRISM and ERA5 against NOAA stations.
- PRISM/ERA5 comparison exhibits, produced inside SECTION 3.
- `02b`/`04b` WMA-level extraction, pending WMA shapefiles.

#### User-written packages (SECTION 1)
Installed once per machine, not per run. The estimation and report scripts
re-check what they need and install what is missing.

```stata
ssc install coefplot
ssc install estout
ssc install confirmdir
ssc install unique
ssc install egenmore
ssc install freqindex
ssc install matchit
ssc install clustse
ssc install parmest
ssc install tmpdir
ssc install sutex
ssc install synth
ssc install binscatter
ssc install _gwtmean
ssc install spmap
ssc install shp2dta
ssc install geoinpoly
ssc install geo2xy
ssc install mif2dta
ssc install ftools
ssc install moremata
ssc install ivreg2
ssc install reghdfe
ssc install ppmlhdfe
ssc install require
ssc install texdoc
ssc install acreg

mata: mata mlib index

net install rscript, from("https://raw.githubusercontent.com/reifjulian/rscript/master") replace
```

Python packages are pinned in `codePYTHON/requirements.txt`. To pin the
interpreter used by every `python script` call:

```stata
python set exec "$path/.venv/bin/python", permanently
```

## Preparing data

### `build_main_data_county_year.do`
Merges PRISM/ERA5 weather, Census population, vehicle collisions, and
wildlife harvest into one county-year panel, and builds the four candidate
winter-weather regressors on top of it. The file `estimates_generate_
collisions_weather.do` and the harvest regressions all read from.
- Merges deliberately keep every row on both sides (no
  `assert _merge==3`, nothing dropped), which departs from the style
  guide's default assert/drop convention -- SECTION 8 exports per-county,
  per-source unmatched-year diagnostics in its place, split into
  "unmatched, in the source's own coverage window" (worth a look) versus
  "unmatched outside it" (expected, not exported).
- SECTION 6 adds `fips_num` (numeric FIPS) and `xtset`s the panel on it,
  which SECTION 7's winter variables need for `L1.` to pull December from
  the prior year.
- SECTION 7 builds `mean_winter_temp` and the two warm-winter dummies
  here (not in the estimation files) so every downstream script uses an
  identical construction; as of 09/17/26 it reads the Winter Severity
  Index from `codePYTHON/06c_build_winter_severity.py`'s CSV instead of
  building it, closing the dependency-on-a-later-phase gap documented in
  project memory (`wsi_dependency_open_item`).
- Four open items are tracked in the file header rather than fixed
  silently: the WSI's snow-detection undercount, wildlife's
  "season-start-year" convention vs. calendar year, un-crosswalked FIPS
  drift in collisions/wildlife, and a handful of malformed St. Louis
  collision geoids. Each has its own SECTION 8 diagnostic export rather
  than an assumption baked into the merge.

### `check_animal_deer_backfill.do`
Standalone QA script: verifies that using all-animal collisions
(`animal_*`) instead of deer-only (`deer_*`) as the outcome only ever
GAINS observations, never loses any -- i.e. every non-missing `deer_*` row
also has a non-missing `animal_*` value.
- Checks this empirically against the built `main_data_county_year.dta`
  (or, with `check_raw_file = 1`, the raw collisions snapshot directly),
  rather than tracing the upstream append code, which isn't in this repo.
- Exports a violations CSV per failing outcome to
  `$tables/checks/animal_deer_backfill_violations.csv`; prints a clean
  PASS/FAIL summary either way.

## Regression estimation -- collisions ~ weather

### `estimates_generate_collisions_weather.do`
Runs the collisions-on-winter-weather regressions and saves each
specification's estimates as a `.ster` file for the table-assembly script
to read back.
- Two outcomes (animal share of all collisions; animal collisions per
  100,000 residents, population-weighted) x 4 winter-measure panels x 4
  control-set columns. Panel B's two anomaly thresholds run as separate
  specifications (B1, B2) with only one carried into the table -- 40
  regressions total.
- Attribution-free as of 09/15/26: design decisions are recorded as dated
  statements ("Settled 9/8/26: ...") rather than quoted meeting
  discussion. Follow this convention for any further edits.

### `estimates_tables_collisions_weather.do`
Reads the `.ster` files above and assembles the two LaTeX tables uploaded
to Overleaf, following the style guide's Section 13 `estout` + `texdoc`
pattern exactly (one panel per `estout` call, wrapped in a `threeparttable`
by `texdoc`).
- Same 4x4 panel/column grid as the generate script, one table per
  outcome.

## Regression estimation -- deer harvest ~ weather (Nicole's; not touched by this cleanup)

### `regression_harvest_per1000.do`, `regression_harvest_zscore.do`, `regression_log_harvest.do`
Three companion tables on the same 4-panel (winter measure) x 5-column
(specification) grid, differing only in the outcome: log(harvest_total),
harvest per 1,000 residents, and the within-county z-score of harvest,
respectively. Maintained by Nicole; each file's own header documents its
current status and open items. Out of scope for this cleanup pass --
left as-is, including their existing attribution style.
- FLAGGED (not fixed) in project memory: these three hardcode
  `global root` instead of reading `$path`, so `_project_main.do`'s path
  resolution doesn't reach them even though the same tree happens to
  exist at both locations. Raise at code review rather than editing
  Nicole's files directly.

## Report generation

### `10_generate_weather_report.do`
Knits the Tier 2 weather exhibits from
`codePYTHON/09_descriptive_weather_full.ipynb` into one dated PDF report.
- Brought into the style guide's header/SECTION format 09/17/26.
- A "DO NOT UNDO" list in the header documents six formatting fixes that
  each cost a debugging round (UTF-8 encoding on every `import delimited`,
  `xcolor` loaded before `pdfpages`, no `$`/backtick characters in `tex`
  lines, the `\DeclareUnicodeCharacter` block, non-interactive `pdflatex`,
  and copying exhibits into the report folder rather than linking them).
- SECTION 6 ("Decisions requested," reading the Tier 2 decisions-log CSV)
  is currently commented out; its CSV reference was updated to
  `prism_tier2_decisions_log.csv` to match the 09/17/26 rename in
  `codePYTHON/09_descriptive_weather_full.ipynb` (dropped the PI's name
  from the shipped filename).

## Shared utility

### `set_figure_fonts_colors.do`
Sets figure fonts and a shared RGB color palette (each color's source --
w3schools, coolors.co -- cited in a comment above it). `do`-ed at the top
of every figure-producing script, per the style guide, rather than
copy-pasted.

## Logs

### `logs/`
Auto-generated Stata run logs (`.log`), one per script that has been run.
Not source and not covered here -- they regenerate on the next run and
will pick up any comment changes made to the `.do` files above.
