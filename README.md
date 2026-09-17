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
                             population, descriptive exhibits
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
