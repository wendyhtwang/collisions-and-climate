# Animal Collisions & Climate

Development repository for the EPIC project on warming winters, ungulate
populations, and animal-related vehicle collisions across the contiguous US.

## Layout

The repository root mirrors `/mnt/data_d/Dropbox/Research/` on Kodama. Each
top-level folder below stands for the Kodama folder of the same name, so any
path below a project folder is identical on both machines and only the root
differs.

```text
AnimalCollisionsWeather/     the weather and population component (this work)
  codePYTHON/                Earth Engine extraction, aggregation, derived vars,
                             winter severity, population, descriptive exhibits
  codeSTATA/                 merge, estimation, tables, report generation
    logs/                    Stata logs
  dataCSV/   dataRAW/        gitignored; lives on Kodama
  dataGIS/   dataPYTHON/     gitignored placeholders
  dataSTATA/                 gitignored; built .dta and .ster estimates
  documentation/             variable listings, .dta structures
  figures/   tables/         generated exhibits
  reports/                   curated PI-facing reports; notebook_exports/ holds
                             the raw notebook HTML/PDF
  grants/  paper/  slides/   placeholders, to match Kodama

UngulatePopulationDataRepo/  wildlife harvest and CWD panels
VehicleCollisionsDataRepo/   state collision files and the county-year panel

_repo/                       repo-only, never copied to Dropbox
  tools/                     update_kodama_structure.py,
                             update_main_dta_variable_summary.py
  notes/                     generated Kodama filesystem structure note
  references/                gitignored vendored clones and style guides
```

The two sibling repos are maintained by other RAs on the project. Their
Dropbox copies on Kodama are authoritative; the copies here are a convenience
snapshot, refreshed by rsync, and changes to them should go upstream through
their owners rather than through this repo.

## Path conventions

- Stata resolves a Research root by `confirmdir`, then sets `$path` to
  `<root>/AnimalCollisionsWeather` and `$pathUngulates` / `$pathCollisions`
  to the two siblings.
- Python sets its project root from `Path(__file__).resolve().parents[1]`,
  which is the same `AnimalCollisionsWeather/` directory.
- The large PRISM and ERA5 daily extracts live outside the Research tree, at
  `/mnt/data_f/AnimalCollisionsWeatherData/` on Kodama.

## Two trees on Kodama

Git is not set up on the shared Dropbox root. The clone at
`~/collisions-and-climate` is the push/pull staging point; the Dropbox tree at
`/mnt/data_d/Dropbox/Research/` is what the `.do` files read. After pulling,
sync code into Dropbox and check the result before trusting a run:

```bash
rsync -avn --exclude 'data*' --exclude '.venv' --exclude '__pycache__' \
  ~/collisions-and-climate/AnimalCollisionsWeather/ \
  /mnt/data_d/Dropbox/Research/AnimalCollisionsWeather/
```

Drop `-n` once the dry run reads correctly. Running Python from the clone
while Stata reads Dropbox is how a run silently consumes stale inputs.

## Entry point

`AnimalCollisionsWeather/codeSTATA/_project_main.do` lists every stage in run
order. Run it from `codeSTATA/`.

Two things it needs from the environment:

- `CENSUS_API_KEY` must be exported before Stata starts. `08b` reads it from
  the environment (not a flag) and raises without it whenever a run touches
  1990-1999 on a cold cache, which the default full-range build does.
- `run_upstream` at the top of SECTION 0 is `0` by default. Setting it to `1`
  rebuilds the two sibling-repo panels in SECTION 2.4; it is off because those
  scripts belong to the other RAs and the collisions append's output path is
  still unconfirmed.

`09a`, `09b` and `weather_descriptives_utils.py` are GENERATED from
`09_descriptive_weather_full.ipynb` by `make_scripts.py`. Edit the notebook and
regenerate; a hand-edit to any of the three is reverted by the next run.
