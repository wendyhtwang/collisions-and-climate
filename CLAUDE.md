# Project context

This project studies how climate change affects road safety by linking
warming winters to wildlife population dynamics and animal-related vehicle
collisions across the contiguous United States. Three RAs contribute
interdependent datasets — vehicle collisions, wildlife/CWD populations, and
weather — that are merged at the county-year (or wildlife-management-area-year)
level. This workspace supports the weather-data component: extracting
climate data from Google Earth Engine for all contiguous U.S. counties and,
where applicable, wildlife management areas (WMAs), 1981–2025.

Because datasets from different RAs are merged downstream, changes to
geographic units, keys, or variable naming here can break merges elsewhere.
When a task's scope, resolution, or output format isn't specified, ask
before assuming rather than defaulting to what a prior stage used.

## Reference implementation

Before writing or modifying Earth Engine extraction code, inspect relevant
examples under:

references/earthengine-api/python/examples/

Use those files as references for API syntax and program structure, but do
not copy code mechanically. Confirm that each adopted pattern is applicable
to the current Earth Engine Python API.

## Data extraction & construction principles

- Use Python 3 and the Earth Engine Python API for extraction work.
- Match the geographic unit (county vs. WMA) and temporal resolution
  (e.g., daily vs. monthly) specified for the current task — do not assume
  county-level or a particular aggregation without confirming.
- Use configurable parameters (state, year, variable, output path) rather
  than hardcoding values.
- Include clear logging and failure reporting.
- Make jobs restartable/idempotent: do not overwrite completed outputs
  unnecessarily.
- Do not launch a full-scale run until a small test run (e.g., one state,
  one year) succeeds.
- Where an independent or published benchmark exists, verify extracted
  output against it (e.g., spot-check a sample of counties/months).

## File & data conventions

- Save raw downloads in a subfolder under ~/dataRAW/, with a source.txt
  documenting where the data came from and the date it was obtained.
- Build output paths off a single project-root variable rather than
  hardcoding absolute paths, consistent with the $path convention used in
  the project's Stata style guide.
- Preserve the identifying keys needed for merging with other RAs' datasets
  (geographic FIPS or WMA identifier, year, month, and variable names).
- Document every variable produced — name, label, unit, source, and notes —
  and pass that documentation along for inclusion in the shared project
  data dictionary rather than leaving it only in code comments.

## Style & review

- Follow the shared project style guide (naming conventions, file
  structure, commenting standards) even when working in a different
  language than Stata — consistency across RAs' code matters more than any
  single convention.
- All code is peer-reviewed by another RA before it reaches the PI. Write
  and comment code with that review in mind, and flag it clearly as ready
  for review rather than final/approved.

## AI coding rules

- Explain proposed changes before making them.
- Do not run large-scale jobs without explicit approval.
- Do not authenticate, delete files, or overwrite existing outputs without
  approval.
- Flag assumptions about units, temporal aggregation, spatial/geographic
  scale, and file structure — especially where a task could plausibly apply
  to more than one geographic unit or dataset.
- Prefer simple, modular, readable code over elaborate abstractions.
- When a task touches another RA's dataset or shared files (e.g., the data
  dictionary, _project_main.do), confirm naming/keys align before merging
  or editing.
