# Project Synopsis

**Project Description**

This project studies how climate change affects road safety by examining the relationship between warming winters, wildlife populations, and animal-related vehicle collisions across the contiguous United States. The central hypothesis is that milder winters increase the survival and reproduction rates of deer and other ungulates, leading to larger populations and, in turn, more frequent and severe animal-related vehicle collisions. By linking year-on-year variation as well as long-run trends in winter weather conditions to wildlife population dynamics and collision outcomes, the project aims to provide some of the first rigorous causal evidence on an underappreciated channel through which climate change imposes costs on human welfare.

**Research Questions**

The project addresses five interconnected questions. First, do warmer winters lead to larger deer, elk, turkey, and moose populations? Second, do larger ungulate populations translate into more animal-related vehicle collisions, and if so, how large are the effects and how are they distributed across collision severity — fatal crashes, injury crashes, and property-damage-only incidents? Third, do wildlife passages — dedicated crossing structures built to allow animals to safely cross roads — reduce animal-related collisions in their vicinity, and how do the effects evolve over time and with distance from the structure? Fourth, does chronic wasting disease (CWD), which reduces deer population levels and alters deer behavior, counteract the collision-increasing effect of warmer winters, and if so, by how much? Fifth, if wolves are present, do they act as substitutes or complements to wildlife passages, and are wolves more effective at reducing DVCs when CWD is present in the county?

**Data**

The project assembles four main datasets. The first is a county-year panel of vehicle collision outcomes spanning as far back as 1981, drawing on state-level crash data obtained from state Departments of Transportation, state police agencies, and national databases including FARS, CRSS, and HSIS. Collision outcomes are measured as shares of all-cause collisions (animal-related and alcohol-related, the latter serving as a placebo) and as rates per 100,000 residents. The second dataset is a county-year or wildlife-management-area-year panel of ungulate population estimates and hunting harvests and effort for deer, elk, turkey, and moose, assembled from state wildlife agencies. The third is a county-year-month panel of weather variables extracted from two complementary climate products — PRISM and ERA5 — via Google Earth Engine, covering 1981 to 2025 and including a wide range of temperature, precipitation, snowfall, and derived variables such as freeze-thaw days and heating degree days. The fourth is a county-year panel of CWD presence and prevalence assembled from USGS, USDA APHIS, and state wildlife surveillance programs. Where crash-level data with geographic coordinates are available, the project also constructs a grid-cell-by-month dataset around wildlife passage locations to support the event study analysis.

**Empirical Approach**

The empirical strategy proceeds in stages. In the first stage, lagged winter weather conditions are used to predict ungulate population levels the following year. LASSO and cross-validation methods are used to select the most predictive set of weather variables from the wide array collected, while always retaining simple mean winter temperature as an interpretable benchmark. Models are estimated separately for deer and in a pooled specification across species with species fixed effects. Where both population estimates and hunting harvest data are available, leave-one-out prediction exercises — leaving out a single observation, an entire year, or an entire county or wildlife management area — are used to assess how well harvest data proxies for population levels out of sample.

In the second stage, the weather variables identified as most predictive of ungulate populations are used as predictors in regression models linking weather conditions to vehicle collision outcomes. The main outcome is the share of animal-related collisions in total collisions; the alcohol-related collision share serves as a placebo to test whether the estimated effects are specific to animal-wildlife interactions rather than reflecting a general weather effect on driving behavior or crash risk. Robustness checks replace collision shares with collision rates per 100,000 residents.

The wildlife passage analysis uses an event study design. Grid cells are constructed around each passage location, and monthly collision counts are computed for each grid cell and linked to the passage via distance from centroid to structure, up to 25 kilometers. The main analysis defines event time relative to the passage completion date. A falsification test uses the announcement date, examining whether collision patterns change in the period after announcement but before construction begins, when no effect would be expected. A second robustness check restricts the sample to the pre-construction and post-completion periods, dropping the construction window.

# Tasks: Charvi

**PHASE 1 — ONBOARDING & DATA DICTIONARY SETUP**

- [ ] Review existing codebase and data to understand the full pipeline from raw state data to the county-year collision database   
* Map out each stage of the pipeline (raw ingestion → cleaning → harmonization → aggregation) and document in the metadata spreadsheet file which states have existing data, which years are covered, and what format each state's data is in (crash-level microdata, county summaries, or PDF reports)   
* Flag any known data quality issues or inconsistencies in existing code or data  
- [ ] Set up and maintain a main data dictionary covering all datasets produced by all three RAs   
      - [ ] Document variable name, label, unit, source, and notes for every variable in each dataset   
      - [ ] Update the dictionary each time a new dataset or variable is finalized by any RA   
      - [ ] Store the dictionary in a shareable format (e.g., Excel or Google Sheet) accessible to all RAs   
      - [ ] Coordinate with Nicole and Wendy to receive variable documentation as they finalize their datasets

      

      **PHASE 2 — DATA COLLECTION: VEHICLE COLLISIONS**

- [ ] Audit existing state collision data to identify gaps in state and year coverage Create a state-by-year coverage matrix showing what data exists, what format it is in, and what years are missing Identify states that have changed data formats across years and document the differences  
- [ ] Identify and pursue additional data sources for states with missing or incomplete data   
      - [ ] Review the NHTSA Fatality Analysis Reporting System (FARS) as a national baseline for fatal crashes   
      - [ ] Review the NHTSA Crash Report Sampling System (CRSS) and its predecessor GES for injury and PDO crashes   
      - [ ] Check the Highway Safety Information System (HSIS) for detailed crash data in participating states   
      - [ ] Review the FHWA State Data Program contacts to identify state-level crash data leads   
      - [ ] Contact state Departments of Transportation (DOTs) and/or Departments of Motor Vehicles (DMVs) for states not yet covered — draft outreach emails for PI review before sending   
      - [ ] Contact state police agencies where DOT data is incomplete or unavailable   
      - [ ] For states with only PDF reports, digitize the reports as CSV files (to be stored in \~/dataCSV/)  
- [ ] Write or update Stata code to ingest newly acquired raw data files and bring them into the harmonized pipeline   
      - [ ] Each state should have its own clearly commented ingestion script   
      - [ ] Ensure all ingestion scripts produce a standardized intermediate file with consistent variable names and formats   
      - [ ] Submit each completed ingestion script for code review by Wendy before passing to PI  
- [ ] Construct the county-year collision database with all required outcome and placebo variables   
* Total collisions   
* Collisions with at least one fatality; total number of fatalities   
* Collisions with at least one injury; total number of injuries   
* Property-damage-only (PDO) collisions   
* Animal-related collisions (for each severity category above)   
* Alcohol-related collisions (for each severity category above, as a placebo outcome)  
* Document any states or years where a specific variable is unavailable or unreliable  
    
  **PHASE 3 — DESCRIPTIVE ANALYSIS: COLLISIONS**  
- [ ] Produce a state-by-year data availability table showing coverage for each collision variable and severity  
- [ ] Produce trend figures showing total collisions, animal-related collisions, and alcohol-related collisions over time   
      - [ ] National aggregate trend (all states combined)   
      - [ ] State-level trends (small multiples or faceted figure)   
      - [ ] Separate figures by severity (fatal, injury, PDO)  
- [ ] Produce choropleth maps showing collision intensity by county   
      - [ ] Animal-related collision rate (per 100k people or per mile of road — flag choice for PI)   
      - [ ] Alcohol-related collision rate   
      - [ ] At minimum two time snapshots (early vs. recent); if feasible, animated or faceted maps by decade  
      - [ ] Have a map showing the means over the full sample  
      - [ ] Have a map showing means for a balanced sample  
- [ ] Produce summary statistics tables for all collision variables, by state and pooled  
- [ ] Submit all descriptive code for Wendy's code review before passing to PI  
        
      **PHASE 4 — WILDLIFE PASSAGES DATA (IF TIME PERMITS)**  
- [ ] Identify existing wildlife passage databases and assess completeness   
      - [ ] Review ARC Solutions' wildlife crossing tracker   
      - [ ] Review the FHWA wildlife crossing pilot program database   
      - [ ] Review Western Transportation Institute (WTI) datasets on wildlife crossing structures   
      - [ ] Check state DOT project databases for crossing structures not in national datasets  
- [ ] For each wildlife passage, collect the following variables   
* Location (coordinates or route milepost)   
* Date on which the plan to construct a wildlife passage was announced   
* Date construction began and date completed (or current status if incomplete)   
* Type and size of structure   
* Target species the passage was designed to accommodate   
* Expected (budgeted) construction cost at project outset   
* Expected construction duration at project outset   
* Realized final construction cost   
* Realized construction duration  
- [ ] Build a wildlife passage dataset in Stata-ready format and document all variables in the main data dictionary  
- [ ] Submit wildlife passage data collection and cleaning code for Wendy's code review before passing to PI  
        
      **PHASE 5 — CODE REVIEW RESPONSIBILITIES**  
- [ ] Serve as code reviewer for all of Nicole's submitted scripts before they go to PI   
* Check that scripts follow the project style guide   
* Verify that code runs end-to-end without errors on the shared data   
* Confirm that output matches documentation and data dictionary entries   
* Return written comments to Nicole and confirm revisions before forwarding to PI  
- [ ] Coordinate with Wendy to receive their code reviews of your scripts before passing to PI  
      

# Tasks: Nicole

**PHASE 1 — ONBOARDING & PROJECT INFRASTRUCTURE**

- [x] ~~Review existing wildlife data to understand what has already been collected and what gaps remain~~   
* Identify which states have existing data, which species are covered, and what years are available   
* Note whether each state's data is reported at the county level or the WMA level  
* Flag any known data quality issues or inconsistencies in existing data or code  
- [x] ~~Draft a project style guide for Stata (and R/Python where used), jointly with Wendy, to be shared with all RAs~~   
* Agree on file naming conventions, folder structure, and do-file header standards   
* Establish commenting standards (block comments for sections, inline comments for non-obvious logic)   
* Define variable naming conventions (snake\_case, prefixes by dataset, etc.)   
* Circulate the draft style guide to Charvi and Wendy for input before finalizing  
- [x] ~~Build and maintain the \_project\_main.do file jointly with Wendy~~   
* Agree with Wendy on the top-level folder structure the main do-file will assume   
* Set up placeholder calls for each RA's pipeline so the file can be expanded incrementally   
* Include a header block documenting the project, last updated date, and dependencies   
* Keep the file updated as new scripts are added by any RA  
    
  **PHASE 2 — DATA COLLECTION: UNGULATE AND TURKEY POPULATIONS**  
- [ ] Audit existing wildlife data to identify gaps in state, species, and year coverage   
- [ ] Create a state-by-species-by-year coverage matrix noting data type (population estimate, hunting harvest, hunting effort, or combination)   
- [ ] Identify whether each state reports at the county level or WMA level   
- [ ] For states reporting at the WMA level, obtain or construct a shapefile outlining WMA polygons  
- [ ] Identify and collect data for states with missing or incomplete coverage   
* Contact state wildlife agencies for states not yet covered — draft outreach emails for PI review before sending   
* Check the USDA Wildlife Services for supplementary population or damage data   
* Review state hunting regulation reports and harvest summaries as a secondary source   
* Collect data for deer, elk, turkey, and moose wherever available  
- [ ] For each state and species, collect the following variables where reported   
* Population estimate (if reported)   
* Hunting harvest (number of animals harvested)   
* Hunting effort (number of hunting trips or licenses, depending on what the state reports)   
* Geographic unit (county name/FIPS or WMA identifier)   
* Year  
- [ ] Construct the county-by-year (or WMA-by-year) wildlife database   
* Where a state reports at the WMA level, retain WMA as the geographic unit — do not attempt to crosswalk to counties   
* Where both population estimates and hunting data are available for the same state and species, retain both   
* Document any states, species, or years where a specific variable is unavailable or unreliable   
* Provide variable documentation to Charvi for inclusion in the main data dictionary  
    
  **PHASE 3 — DATA COLLECTION: CHRONIC WASTING DISEASE**  
- [ ] Identify and collect CWD prevalence data at the county level   
* Review the USGS National Wildlife Health Center CWD distribution map and underlying data   
* Review the USDA APHIS CWD surveillance data   
* This is likely the best source of data (map and data table available): [https://www.cdc.gov/chronic-wasting/data-research/?CDC\_AAref\_Val=https://www.cdc.gov/prions/cwd/occurrence.html](https://www.cdc.gov/chronic-wasting/data-research/?CDC_AAref_Val=https://www.cdc.gov/prions/cwd/occurrence.html)   
- [ ] Construct a county-by-year CWD database  
* Variables should include: county FIPS, year, CWD presence (binary), CWD prevalence rate where available, number of animals tested, and data source   
* Document all variables and provide them to Charvi for inclusion in the main data dictionary  
    
  **PHASE 4 — DESCRIPTIVE ANALYSIS: WILDLIFE DATA**  
- [ ] Produce a state-by-species-by-year data availability table showing coverage for each variable and data type  
- [ ] Produce trend figures for deer, elk, turkey, and moose populations and harvests over time   
      - [ ] National aggregate trends (all states combined) for each species   
      - [ ] State-level trends (small multiples or faceted figure)   
- [ ] Where both population estimates and hunting data exist, plot:  
      - [ ] Scatter plots documenting the correlation between the two  
      - [ ] A binscatter of population estimates versus hunting harvests  
      - [ ] Time series plots, by county or WMA, to eyeball if population estimates and hunting data are trending similarly and exhibit similar shocks   
- [ ] Produce choropleth maps showing population and harvest intensity by county or WMA   
* At minimum two time snapshots (early vs. recent)   
* Separate maps for each species where data permit  
- [ ] Produce summary statistics tables for all wildlife variables, by state, species, and pooled  
- [ ] Produce descriptive exhibits for CWD data   
      - [ ] Map of CWD presence and prevalence by county, with time variation if data permit   
      - [ ] Trend figure showing spread of CWD across counties over time  
- [ ] Submit all descriptive code for Charvi's code review before passing to PI  
        
      **PHASE 5 — LEAVE-ONE-OUT PREDICTION ANALYSIS**  
- [ ] For states and species where both population estimates and hunting data are available, assess how well hunting data predicts population estimates out of sample   
      - [ ] Leave one observation out (single county-year or WMA-year pair)   
      - [ ] Leave one entire year out   
      - [ ] Leave one entire county (or WMA) out  
      - [ ] Run the leave-one-out analysis separately for deer, and in a pooled model across all species with species fixed effects  
- [ ] Produce a table and figure summarizing prediction performance for each leave-one-out approach and each species  
- [ ] Submit leave-one-out analysis code for Charvi's code review before passing to PI  
        
      **PHASE 6 — REGRESSION ANALYSIS: WEATHER AND UNGULATE POPULATIONS**  
- [ ] Coordinate with Wendy to receive the county-year-month (or WMA-year-month) weather data once available  
- [ ] Run regression analysis linking lagged weather conditions to ungulate population levels (or hunting data proxy)   
* Primary specification: population at time t as a function of winter weather conditions at time t-1   
* Also estimate alternative lag structures (t-2, t-3) and different seasons (fall, spring)   
* Always include simple mean winter temperature as a benchmark specification  
- [ ] Use cross-validation and LASSO to select the set of weather variables that best predict ungulate population the following year   
      - [ ] Run separately for deer   
      - [ ] Run as a pooled model across all species with species fixed effects   
      - [ ] Document the selected weather variables and share with Wendy for use in the collision regressions  
- [ ] Produce a table of regression results for each specification, clearly indicating the benchmark and the LASSO-selected model  
- [ ] Submit all regression code for Charvi’s code review before passing to PI  
        
      **PHASE 7 — CWD ANALYSIS (IF TIME PERMITS)**  
- [ ] Assess whether CWD prevalence predicts deer population levels or hunting success   
      - [ ] Merge the CWD county-by-year database with the deer population and harvest data   
      - [ ] Run regression analysis with deer population or harvest as the outcome and CWD presence or prevalence as the main explanatory variable   
      - [ ] Include county and year fixed effects; flag additional controls for PI discussion   
      - [ ] Produce a table of results and a brief write-up of findings  
- [ ] Submit CWD analysis code for Charvi's code review before passing to PI  
        
      **PHASE 8 — CODE REVIEW RESPONSIBILITIES**  
- [ ] Serve as code reviewer for all of Wendy's submitted scripts before they go to PI   
* Check that scripts follow the project style guide   
* Verify that code runs end-to-end without errors on the shared data   
* Confirm that output matches documentation and data dictionary entries   
* Return written comments to Wendy and confirm revisions before forwarding to PI  
- [ ] Coordinate with Charvi to receive their code reviews of your own scripts before passing to PI

# Tasks: Wendy

# **PHASE 1 — ONBOARDING & PROJECT INFRASTRUCTURE**

- [ ] Review existing codebase and data to understand the full pipeline and how the weather data will connect to the collision data and the wildlife data   
- [ ] Review Charvi's county-year collision database structure and variable names   
- [ ] Review Nicole's wildlife database structure to understand the WMA geographic units where applicable   
- [ ] Flag any questions about how the weather data should be keyed to match the other datasets  
- [x] ~~Draft a project style guide for Stata (and R/Python where used), jointly with Nicole, to be shared with all RAs~~   
* Agree on file naming conventions, folder structure, and do-file header standards  
* Establish commenting standards (block comments for sections, inline comments for non-obvious logic)   
* Define variable naming conventions (snake\_case, prefixes by dataset, etc.)   
* Circulate the draft style guide to Charvi and Nicole for input before finalizing  
- [x] ~~Build and maintain the \_project\_main.do file jointly with Nicole~~   
* Agree with Nicole on the top-level folder structure the main do-file will assume   
* Set up placeholder calls for each RA's pipeline so the file can be expanded incrementally   
* Include a header block documenting the project, last updated date, and dependencies   
* Keep the file updated as new scripts are added by any RA


  # **PHASE 2 — GOOGLE EARTH ENGINE SETUP**

- [x] ~~Get access to Google Earth Engine and learn the basics of extracting climate data~~   
      - [x] ~~Create a Google Earth Engine account at code.earthengine.google.com and request access (approval is typically needed and can take a few days)~~   
      - [x] ~~Complete the official GEE getting-started guide at [developers.google.com/earth-engine/guides/getstarted](http://developers.google.com/earth-engine/guides/getstarted)~~    
      - [x] ~~Work through the [GEE JavaScript API tutorials](https://developers.google.com/earth-engine/guides/objects_methods_overview) focusing on:~~  
            - [x] ~~image collections,~~   
            - [x] ~~reducers,~~  
            - [x] ~~feature collections~~   
      - [x] ~~For Python-based extraction (recommended for large data pulls), set up the earthengine-api Python package and authenticate following the guide at [developers.google.com/earth-engine/guides/python\_install](http://developers.google.com/earth-engine/guides/python_install)~~    
      - [x] ~~Review this practical tutorial for large-scale climate data extraction using GEE and Python: [github.com/google/earthengine-api/tree/master/python/examples](http://github.com/google/earthengine-api/tree/master/python/examples)~~    
      - [x] ~~Practice extracting a small test dataset (e.g., one state, one year) before running the full extraction~~

	

# **PHASE 3 — WEATHER DATA COLLECTION**

- [ ] Extract PRISM climate data from Google Earth Engine at the county-year-month level for the contiguous US (CONUS), 1981 to end of 2025 (PRISM begins in 1981\)   
      - [x] ~~Extract all available PRISM variables: daily maximum temperature, daily minimum temperature, mean temperature, precipitation, mean dew point temperature, minimum vapor pressure deficit, maximum vapor pressure deficit~~   
      - [x] ~~Aggregate daily data to monthly means (or totals for precipitation) at the county level using county polygon shapefiles~~   
      - [ ] Also extract at the WMA level using the shapefiles provided by Nicole, for the wildlife-side analysis   
      - [x] ~~Verify output by spot-checking against published PRISM summaries for a sample of counties and months~~  
- [ ] Extract ERA5\-Land (daily aggregated) reanalysis data (as a robustness check to PRISM) from Google Earth Engine at the county-year-month level for the contiguous US, 1981 to end of 2025   
      - [x] ~~Extract all available ERA5 variables relevant to surface weather conditions, including: 2m temperature, 2m dewpoint temperature, total precipitation, snowfall, snow depth, 10m wind speed, surface pressure, and skin temperature~~   
      - [x] ~~Aggregate to monthly means (or totals where appropriate) at the county level~~   
      - [ ] Also extract at the WMA level using the shapefiles provided by Nicole   
      - [x] ~~Verify output by spot-checking against published ERA5 summaries for a sample of counties and months~~  
- [ ] Construct derived weather variables from the raw PRISM and ERA5 extracts   
      - [x] ~~Number of extremely cold days where **minimum temperature** is below **0°F** (from daily temperature data where available) (relevant threshold for metabolic stress in deer)~~  
      - [x] ~~Number of freeze-thaw days (days where min temp is below 0°C and max temp is above 0°C) (relevant threshold for road conditions)~~  
      - [x] ~~Temperature variance within each month (of all 3 PRISM temp vars: mean, min, max, not just mean)~~  
      - [x] ~~Total snowfall and snow depth (from ERA5)~~   
      - [x] ~~Number of days with precipitation above a threshold (e.g., 10mm, or presumably whatever the literature says is the relevant threshold)~~   
      - [x] ~~Heating degree days and cooling degree days (I’m using a baseline temperature of 65F, the US standard)~~  
      - [x] ~~Mean monthly temperature~~   
      - [x] ~~Flag all derived variables clearly in the code and document them for Charvi to add to the main data dictionary~~  
      - [ ] Optional side quest (literature review): Are there known thresholds in the literature (state report, academic articles) that are relevant specifically to deer, elk, turkeys, or moose?  
- [ ] Provide variable documentation for all raw and derived weather variables to Charvi for inclusion in the main data dictionary  
- [ ] Submit all data extraction and construction code for Nicole's code review before passing to PI  
      - [ ] updating \_project\_main.do (after PI sign-off on the weather pipeline)

      

      

      # **PHASE 4 — DESCRIPTIVE ANALYSIS: WEATHER DATA**

- [ ] Produce summary statistics tables for all weather variables, by county, by month, and pooled  
- [ ] Produce trend figures emphasizing winter conditions and long-run change   
      - [ ] National average winter temperature trend, 1981–2025   
      - [ ] State-level winter temperature trends (small multiples or faceted figure)   
      - [ ] **Per-state spaghetti plot**: one trend line per county within each state, to reflect within-state county variation over time (not just a single state-level aggregate line)  
      - [ ] Trend in number of days below freezing (\<32F, or \<0F?), nationally and by state   
      - [ ] Trend in freeze-thaw days, nationally and by state  
      - [ ] **Distributional comparisons decade-by-decade, by state**: to visualize the climate-change shift in the shape of the distribution, not just the mean trend  
- [ ] Produce figures showing year-to-year volatility in winter conditions   
      - [ ] Standard deviation of winter temperature by county across years   
      - [ ] Maps showing which regions have the highest interannual variability in winter conditions  
      - [ ] **Frequency/count of anomalous warm-winter shocks**: we want a metric that counts/flags anomalous warm winters specifically (in addition to the std-dev measure already listed above), so we can identify (a) which counties/states have had the most anomalous winters, and (b) which have seen the greatest long-run winter warming from the 1980s to now  
- [ ] Produce choropleth maps of key winter weather variables by county   
      - [ ] Average winter temperature (early period vs. recent period)   
      - [ ] Change in average winter temperature over the full sample period  
      - [ ] **Winter severity index** (days with min temp \< 0°F, per the Wisconsin DNR-style index)  
- [ ] Submit all descriptive code for Nicole's code review before passing to PI  
      

      # **PHASE 5 — COUNTY-YEAR POPULATION DATA COLLECTION**

- [ ] Collect county-year population data for use in constructing collision rates (collisions per 100,000 people)   
      - [ ] Download Census intercensal population estimates from the Census Bureau for all available years (typically 1990 onward in clean format)   
      - [ ] Check ICPSR for a harmonized county-year population dataset extending back to 1980 if Census intercensal estimates do not cover the full period   
      - [ ] If neither source covers 1980–1989, coordinate with PI to obtain the raw data, code, and output already prepared, and integrate with the post-1990 estimates to produce a single 1980–2025 county-year population file   
      - [ ] Verify the series is consistent at state-level totals against Census decennial counts for 1980, 1990, 2000, 2010, and 2020  
- [ ] Document all population variables and provide to Charvi for inclusion in the main data dictionary  
- [ ] Submit population data collection and cleaning code for Nicole code review before passing to PI  
      

      # **PHASE 6 — REGRESSION ANALYSIS: WEATHER AND VEHICLE COLLISIONS**

- [ ] Coordinate with Nicole to receive the set of weather variables identified as most predictive of ungulate populations before finalizing the regression specifications  
- [ ] Run regression analysis linking lagged weather conditions to vehicle collision outcomes   
* Main outcome: animal-related collision share relative to all-cause collisions   
* Main placebo outcome: alcohol-related collision share relative to all-cause collisions   
* Always include simple mean winter temperature as a benchmark specification   
* Also include the LASSO-selected weather variables from Nicole's ungulate population analysis as the preferred specification   
* Refer to the methods section of the paper draft for the exact fixed effects structure before finalizing specifications  
- [ ] Produce robustness checks using collision rates (collisions per 100,000 people) in place of collision shares   
* Run for animal-related collision rate and alcohol-related collision rate   
* Mirror the same set of specifications used in the main share-based analysis  
* When using rates per 100,000 people, the regressions should be population-weighted  
- [ ] Produce a table of regression results for each specification and outcome, clearly labeling benchmark vs. preferred vs. robustness specifications  
- [ ] Submit all regression code for Nicole code review before passing to PI  
      

      # **PHASE 7 — WILDLIFE PASSAGE EVENT STUDY (IF TIME PERMITS)**

- [ ] Coordinate with Charvi to identify the wildlife passages where crash-level coordinate data are available  
- [ ] For each qualifying wildlife passage, construct a grid cell dataset around the passage location   
      - [ ] Define grid cells around each wildlife passage location   
      - [ ] Calculate the distance from the centroid of each grid cell to the nearest wildlife passage, up to a maximum of 25 km (this exact distance should be a tuning parameter that we can easily change)   
      - [ ] Link each grid cell to its nearest wildlife passage  
- [ ] Construct monthly collision counts by grid cell   
      - [ ] For each grid cell, count collisions by type (animal-related, alcohol-related, total) and severity (fatal, injury, PDO) at the monthly level   
      - [ ] Merge with the wildlife passage metadata collected by Charvi, including construction start date, completion date, and announcement date  
- [ ] Run the main event study regression analysis (early to late treated units)  
* Define event time relative to the wildlife passage completion date   
* Unit of observation is the grid cell by month   
* Produce event study figures showing animal-related collision trends before and after passage completion, by distance band from the passage  
- [ ] Produce robustness checks and falsification tests   
      - [ ] Falsification test: define event time relative to the announcement date, using only months after announcement and before construction begins   
      - [ ] Alternative specification: restrict the sample to months before construction began and months after construction was completed, dropping the construction period  
- [ ] Produce simple before-and-after maps of animal-related collision intensity around each wildlife passage for visual illustration  
- [ ] Submit all event study code for Nicole code review before passing to PI  
      

      # **PHASE 8 — CODE REVIEW RESPONSIBILITIES**

- [ ] Serve as code reviewer for all of Charvi's submitted scripts before they go to PI   
* Check that scripts follow the project style guide   
* Verify that code runs end-to-end without errors on the shared data   
* Confirm that output matches documentation and data dictionary entries   
* Return written comments to Charvi and confirm revisions before forwarding to PI  
- [ ] Coordinate with Nicole to receive their code reviews of your own scripts before passing to PI

# Code Style Guide

# Stata Style Guide

## **1\. Proposed Folder Structure**

Top-level structure, (hopefully) mirroring what `_project_main.do` will assume:

```
AnimalCollisionsWeather/             # main project folder

├── _project_main.do               # master script, calls every RA's pipeline in order 

├── codeSTATA/                     # all files used to code, mirrors _project_main.do structure 
│   ├── 00_setup/                 # global/local definitions, path detection
│   ├── 01_clean_state/           # one file per state, e.g. clean_CO.do, clean_IA.do
│   ├── 02_build_panel/           # append/reshape into county-year panel
│   ├── 03_weather/               # weather + GEE data pipeline
│   ├── 04_ungulates/             # wildlife + CWD data pipeline 
│   ├── 05_collisions/            # vehicle collisions data pipeline 
│   ├── 06_analysis/              # regressions, LASSO selection, etc.
│   └── 07_output/                # tables and graphs 

├── dataRAW/                       # untouched source files

├── dataSTATA/                     # intermediate .dta outputs

├── figures/                       # finalized figures

├── tables/                        # finalized tables 

# other subfolders omitted for simplicity 
```

* Can be replicated in the folders for `~/VehicleCollisionsDataRepo/` and/or `~/UngulatePopulationDataRepo/` if desired.

## **2\. File Naming Conventions**

* All lowercase, words separated by underscores (snake\_case). No spaces, no `camelCase`, no `PascalCase`. The exception is state abbreviations (all uppercase, e.g. CO instead of co).  
* State-level cleaning scripts: `clean_[state_abbrev].do` (e.g. `clean_CO.do`), matching the existing convention of state files being named by state.  
* Saved intermediate datasets follow the pattern already in use across all six files: `dvcs_[state_abbrev]_county_year_[t1]_[t2].dta`, where `t1`/`t2` are the min/max year, computed via `qui summ year` to save time. It's consistent everywhere already.  
* Scripts that aren't state-specific get a verb-first name describing what they do: `build_panel.do`, `merge_population.do`, `run_lasso_selection.do`.  
* Prefix any script meant to be run standalone-only (not called by `_project_main.do`) with `_` so it sorts to the top and signals "special": `_project_main.do`, `_scratch_exploration.do`.

## **3\. Do-File Header**

Every do-file opens with a comment banner naming the file, followed by standard setup commands, in this exact order:

```
/*==============================================================
FILE:         <filename>.do
PROJECT:      Weather Changes, Ungulate Populations, & Vehicle Collisions
CURRENT LEAD: [Name]

PURPOSE:      One-sentence description of what this file does.

CHANGELOG:
  MM/DD/YYYY [Name]: description of change
  MM/DD/YYYY [Name]: description of change
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
    global path = "`rootDir'/<specific_project_folder>"
}

```

* Every `.do` file that produces or modifies a saved dataset should have this header, including throwaway-looking scripts, since "throwaway" scripts have a way of becoming permanent.  
* The changelog is append-only. Never delete a prior entry, even if you're undoing someone else's change add a new line saying so.  
* `CURRENT LEAD` reflects whoever owns the file *today*, not who originally wrote it (that's what the changelog is for).  
* The banners are a `/*=...=*/` or `*-...` block, opened and closed with a full-width line of `=` or `-`, with the program name/information on its own line in between.

Figure-producing files additionally set fonts and colors right after the header:

```
do "$path/codeSTATA/set_figure_fonts_colors.do
```

## **4\. Section Headers**

Every do-file should be broken into numbered sections this way so anyone can use `grep "SECTION"` across the repo to jump around. Large sections within a file are marked with a full-width comment banner, title centered/asterisk-padded, e.g.:

```
*---------------------------------------------------------------
* SECTION 2: MERGE COUNTY IDENTIFIERS
*---------------------------------------------------------------
```

* Rule lines are a `*-...` block, opened and closed with a full-width line of `-`, with the program name/information on its own line in between.  
* Used to separate major data sources/steps within a build file, or major panels/samples within an estimation file.

## **5\. Line Continuation and Wrapping**

Long commands are wrapped using `///` continuation, with one argument/option per line.

* The `///` is generally right-aligned in a loose column so that trailing `///` markers line up vertically within a command:

```
collapse (sum) m_tot ///
               f_tot ///
               rur_m_tot ///
               rur_f_tot, ///
               by(state ///
                  district ///
                  age_grp)
```

* Continued arguments are indented to align under the first argument on the initial line (hanging indent), not indented a fixed number of spaces from the margin.

`reghdfe`/regression calls wrap one option per line, with `absorb()`, `cluster()`, and weights each on their own line:

```
reghdfe deathrate ///
        treatment_group_post_1994 ///
        ${`controls'} ///
        [aw = pop_interp], ///
        absorb(district_id zonal_council_divisions#year) ///
        cluster(district_id) ///
        noconstant
```

`tempfile` declarations with multiple names also wrap one name per line with aligned `///`:

```
tempfile pop_shares ///
         share_literate_data ///
         water_access ///
         medical_facilities ///
         health ///
         water
```

## **6\. Variable Naming Conventions**

**Base convention:** snake\_case everywhere, with the exception of state abbreviations (otherwise no `camelCase`, no `PascalCase`, no bare abbreviations without underscores).

* **snake\_case** throughout for variables, locals, globals, and tempfiles (`tot_district_pop`, `treatment_group_post_1994`, `file_name`).  
  * No camelCase or PascalCase, with the exception of raw source-provided column names kept as-is until renamed (e.g. `xcoord`/`ycoord` before renaming to `X`/`Y`).  
* Consistent pattern for **geography variables**: e.g. `state_letter_code`, `county_name`, `fips`, `state_fips`, `county_fips`, `state_name`  
* Consistent pattern for **collision/count variables:** e.g. `total_all_cause`, `fatal_collision`, `injury_collision`, `pdo_collision`.  
* Consistent pattern for **animal/species variables:** e.g. `[species]_[type]_collision`, `deer_fatal_collision`, `deer_injury_collision`, `deer_pdo_collision`  
  * Reserving `wild_animal_*` vs. `animal_*` explicitly for the domestic/wild distinction where it exists (e.g. ID), documented per-state if not every state reports it.  
* **Boolean/dummy variables** are named descriptively and read like a condition: `treatment_group`, `balanced_deathrate`, `high_livestock_q2`, `is_affected_vulture`.  
* **Temp/scratch variables** are literally named `temp` (or `temp_v`/`temp_b` when more than one is alive at once) and always dropped immediately after use.

**General prefix conventions**:

| Prefix | Meaning | Example |
| ----- | ----- | ----- |
| `is_` | binary/boolean indicator | `is_treated`, `is_urban_county` |
| `n_` | count | `n_collisions`, `n_deer_harvested` |
| `mean_` / `total_` / `share_` | aggregation type | `mean_winter_temp`, `share_forest_land` |
| `resid_` | residualized variable | `resid_population` |
| `qtr1_`, `qtr2_`... | quarter-indexed | `qtr1_snowfall` |
| `qnt1_, qnt2_` | quintile-indexed | `qnt1_snowfall` |

* **Dataset-of-origin prefixes:** for variables merged in from a specific external source that might need disambiguation later (e.g. population data vs. collision data both having a `year` concept at slightly different granularity), prefix with a short dataset tag only when there's real ambiguity.   
  * Example: `pop_year` vs `dvc_year` only if both are in memory during a merge step and need distinguishing.  
* Local macro `file_name` is the conventional name for a path about to be used in `import delimited`.  
* `.ster` estimate files and output datasets are named to encode their position, e.g. ``p_`panel'c`column'.ster``, `c_1.ster`.

## **7\. Indentation**

* 4-space indentation inside `foreach`/`forvalues` loop bodies.  
* Continuation lines inside multi-line commands are hand-aligned with spaces to line up arguments/options in a column (see Section 5), not tab-indented.

## **8\. Comments**

**General convention:** Use `*` at the start of a line above the code it explains, not a trailing `//` comment glued to the end of the line. Easier to read and to `grep`. 

For example:

```
* Create treatment variables
gen post_1994 = (year >= 1994 & year != .)
```

Or:

```
* PA county names have OCR typos from the original source PDFs;
* hardcoded here rather than a lookup table since the list is short and staticreplace county_name = "armstrong" if county_name == "annstrong"
```

* Any deviation from the standard pipeline (a hardcoded fix, a dropped observation, a manual patch) **must** get an inline comment explaining why, plus a line in the file's changelog.  
* Commented-out old code should not linger: either delete it or, if it's worth keeping as a reference, note why in a comment (e.g. `* kept for reference: old merge logic before switching to fips-based match`).  
* Data provenance and manual-entry values are documented with source URLs and access dates directly above the code, e.g.:

```
* Manually filling in values for union territories
* Values are in thousands, from: https://dahd.nic.in/related-links/annex-ii-9-growth-cattle-population-india-1992-97
* Accessed: 7/16/2022
```

**Loop logic** is explained with a short comment above the loop describing what each pass does:

```
* First loop estimates results for panel A,
* and then for panel B
foreach controls in none weather {
```

* For short numbered sub-steps within a loop or block, an indented asterisk banner is used:

```
************************** Variation 1 **************************

* ------------------------ Variation 2 ---------------------------
```

Reserve **inline comments** for the *non-obvious*: why a choice was made, not what the command does. 

* Use `//` for **very short** inline asides, e.g. `global dist_cutoff = 100 // Conley SE distance cutoff, in km` style trailing notes on the same line as a `global`/`local` definition.

## **9\. Paths and Globals**

All file paths are built off a single global root, `$path`, established elsewhere (e.g., a master/profile script) and **never hard-coded absolute paths**.

If using secondary convenience globals (ex. `$working_data`, `$figures`, `$tables`.), they must be defined as a subpath of `$path` (ex. `global figures "$path/figures"`), never as an independent hardcoded path.

* A source .`csv`/`.dta` path is first assigned to a local named `file_name`, then used:

```
local file_name = "$path/dataRAW/BalanceTableData/data_district_census1991_age.csv"
import delimited using "`file_name'", clear
```

* Reusable sub-scripts are invoked with   
  `do "$path/codeSTATA/<script>.do"` rather than copy-pasted inline (e.g. `stable_districts_1981.do`, `consistent_district_names.do`).  
* Regression control sets and reused option lists are stored as globals and invoked via indirection, e.g. `global weather "dd_bin_* i.precip_q5"` then ``${`controls'}``.  
* Color palettes for graphs are defined as RGB-string globals at the top of every figure file (identical block copy-pasted across figure scripts), each with a comment citing its source (e.g. w3schools, coolors.co, carto.com, tsitsul.in).

## **10\. Data Cleaning / Merging Conventions**

* String identifiers used as merge keys (`state`, `county`) are always normalized immediately after import. For example:  
  * `replace state = trim(lower(state))`  
  * `replace county_name = trim(lower(county_name))`  
* FIPS codes are kept as strings throughout data cleaning/merging (destringing drops leading zeroes, which can break geographic joins).   
  * If a numeric FIPS variable is needed for a specific regression's fixed effects (FE), it is generated separately at that point in the script:  
    * `fips_num` (county-level FE)  
    * `state_fips_num` (state-level FE)  
    * `state_fips_num#year` (state-by-year FE, within `reghdfe`'s `absorb()` option)

Every `merge` is immediately followed by an explicit `assert` on `_merge` (or a `drop if`) and then `drop _merge`:

```
merge m:1 state county using "$path/DATA/INTERMEDIATE/DTA/....dta"
assert _merge == 3
drop _merge
```

Use: 

* `assert _merge == 3` when a perfect match is expected.  
* `assert _merge != 2` or `drop if _merge == 2` when the using file is allowed to have extra unmatched observations that should be discarded.

* `preserve` / `restore` to build a small side dataset (e.g. a crosswalk or centroid file) inline within a build script rather than in a separate do-file, with the body indented 4 spaces between `preserve` and `restore`.

`collapse`, `reshape`, and `keep` / `order` variable lists always list one variable per line (see Section 5), even when the list would fit on one line, once there are more than \~3 variables.

***END OF RA EDITS***

## **11\. Regression / Estimation Scripts**

* Fixed-effect indicator flags for table footers are added via `estadd local` with an `"X"`/`""` convention (present/absent), immediately after `estadd scalar`:

```
qui summ <outcome_variable> if e(sample)
estadd scalar dep_var_mean = `r(mean)'
estadd local council_yearFE = "X"
estadd local council_year_state_trendsFE = ""
estadd local state_yearFE = ""
```

* Estimates are saved to disk immediately after each specification via `estimates save "$path/dataSTATA/estimates/<Table>/<name>.ster", replace`, rather than accumulated with `eststo` and exported at the end.  
* Naming conventions for the estimation result files try to capture the key information about the model that generated the results in the file:


```
* The file suffix makes it easy to know what generated the estimates file later on when 
* it is used for producing figures or tables:
* SR: Sample Restriction 
* AR: Area Restriction 
* IY: Initial Year 
* TY: Terminal Year 
* CG: Comparison Groups 
* TD: Treatment Definer 
* TT: Time Trends 
* W: Weights 

local file_suffix = "`treatment_suffix'_SR`sample_restriction'_AR`area_var'_IY`initial_year'_TY`terminal_year'_CG`comparison'_TD`treatment_definer'_TT`trends'_C`controls'_W`weights_suffix'_unbalanced"

local reg_file_name = "<outcome>_<treatment>_`file_suffix'.ster
estimates save "$path/dataSTATA/estimates/<subfolder>/`reg_file_name'
```

* A comment block listing the numbered "variations" being run is placed above the loops that implement them, e.g. "1) Pooled effect... 2\) Pooled effects for..." etc.

## **12\. Graphs**

* The art of making good figures is thinking about what they are trying to communicate, and then removing unnecessary ink that just distracts the eye.   
* Every graph command uses the same wrapped, one-option-per-line structure as regressions, with each plotted series as its own parenthesized block:

```
tw (line estimate ///
         year_var, ///
         lwidth(medthick) ///
         lcolor(black) ///
         lpattern(solid)) ///
   (rspike max95 ///
           min95 ///
           year_var, ///
           lwidth(medthick) ///
           lcolor(black)), ///
   xlabel(1988(1)2005, angle(45)) ///
   ...
```

* Colors are referenced via the global palette (`lcolor("$mute_calm_11")`), never hard-coded RGB/hex inline.  
* The following is an example of some of the options that can/should be used when making figure (with inline comments to explain things):


```
tw <plot commands>....,
   xlabel(2010(2)2020) ///    /* enough info, but not too crowded */
   xtitle("Year", size(medium)) /// 
   ylabel(0(0.05)0.2, angle(0)) /// /* same as x-label, but the angle (0) is important so people don't need to twist their heads */
   ytitle("") /// /* we use the title option, because again, trying to avoid neck pain when reading a figure */
   yscale(outergap(-4.5)) /// /* there is often a lot of dead white space, this helps get rid of it */
   aspectratio(0.4) /// /* useful in some specific cases, not be included by default */
   title("a)Proportion of Stocks by Fishery Status", placement(9) justification(left) size(medium)) /// 
   plotregion(color(white)) /// /* gets rid of some figure borders */
   legend(label(1 "In Overfishing") /// 
          label(2 "Overfished or in Rebuilding") ///           
          order(1 2) ///
          cols(4) /// 
          symxsize(*0.3) /// /* sometime smaller legend items are better */
          ring(0) /// /* places the legend within the figure */
          bplacement(ne) ///
          region(color(none)))

```

## 

* Every figure ends with export to PDF via a `file_name` local:

```
local file_name = "$path/figures/"
graph export "`file_name'.svg", replace 
shell inkscape --export-type="pdf" "`file_name'.svg"
```

## **13\. Table-Assembly Scripts** 

A separate family of scripts, `estimates_tables_<table_name>.do`, reads back the `.ster` files saved by the `estimates_generate_*` scripts and turns them into publication-ready LaTeX tables. Each one follows the same three-stage structure: **(a)** load estimates, **(b)** export a coefficient panel with `estout`, **(c)** wrap the panel(s) in a full LaTeX table with `texdoc`. A summary statistics table (often numbered as Table 1 ot Table A1) is a partial exception (it builds a balance table with `balancetable` directly from data rather than from saved estimates) but shares the `texdoc` conventions below.

### **13.1 Loading saved estimates**

Estimates are read back and stored under names that reflect their position in the table 

First, use `estimates use <file_name>.ster`

Then, use `estimates store e_<short_easy_name_to_use_later>`

When there's no natural panel/column grid, estimates are loaded individually with short, descriptive store names instead (`e1`...`e6`; `e_do_dd`, `e_do_ddd`, `e_fc_dd_u`, etc.).

### **13.2 Exporting coefficient panels with `estout`**

Each panel of a table is written with a single `estout` call, switched into `#delimit ;` mode for the duration of the call and back to `#delimit cr` immediately after:

```
#delimit ;
estout p_1_c_1
       p_1_c_2
       p_1_c_3
       p_1_c_4
       using "$path/RESULTS/TABLES/table_<name>_panel_A.tex",
       cells(b(fmt(2)) se(par fmt(2)))
       label style(tex)
       stats(r2
             N
             N_clust1,
             fmt(2 %9.0gc %9.0gc)
             labels("\midrule \(R^2\)"
                    "N"
                    "Clusters"))
       mlabels((1) (2) (3) (4))
       collabels(none)
       varlabels(resid_x "HVS\(\times\)Post-1994"
                 resid_x1 "HVS\(\times\)[1994, 1999]")
       keep(resid_x
            resid_x1)
       order(resid_x
             resid_x1)
       prehead(

       )
       posthead(\midrule)
       prefoot()
       postfoot(
         \noalign{\smallskip}
       )
       replace;
#delimit cr
```

Fixed conventions within every `estout` call:

* Stored-estimate names to include are listed one per line (no commas), immediately after `estout`, before `using`.  
* `cells(b(fmt(2)) se(par fmt(2)))` — coefficients to 2 decimals, standard errors in parentheses directly below.  
* `label style(tex)` always included.  
* `stats(...)` always lists `r2`, then `N`, then a cluster-count stat (named `N_clust`), with any FE/sample indicator rows (`council_yearFE`, `state_yearFE`, `balanced`, `collapsed`, etc.) appended after. The `fmt()` and `labels()` sub-options list entries in the same order as the `stats()` list, one per line, and FE/indicator rows get `fmt` code `0` (integer, no decimals).  
* FE/indicator row labels are prefixed with `\midrule` (or `\noalign{\medskip} \midrule` for the first such row) inside the label string itself, so the divider is embedded in the exported `.tex` rather than added separately.  
* `mlabels((1) (2) (3) ...)` — numbered column headers matching the table's column count.  
* `collabels(none)` always included (column variable-name headers are suppressed; column numbers from `mlabels` are used instead).  
* `varlabels()` renames residualized/interaction regressors (`resid_x`, `resid_x1`, `resid_x2`, or named treatment interactions) into the display label used in the paper, with LaTeX math (`\(\times\)`) for interaction terms.  
* `keep()` and `order()` are always both specified, listing the same variables in the same order, one per line — `keep()` to drop nuisance/control coefficients from the export, `order()` to guarantee row order regardless of estimation order.  
* `prehead()`, `posthead(\midrule)`, `prefoot()`, `postfoot(\noalign{\smallskip})` are boilerplate copy-pasted unchanged across every `estout` call in the codebase — treat this block as a fixed template rather than something to customize per table.  
* Call always ends with `replace;` before `#delimit cr`.  
* Output filenames follow `table_<descriptive_table_name>_panel_<X>.tex` (or `_panel.tex` for single-panel tables), matching the `\ExpandableInput{}` path used in the corresponding `texdoc` block (12.3).

### **13.3 Wrapping panels in a full table with `texdoc`**

The full LaTeX table (title, header row, `\ExpandableInput` of the `estout` panel(s), and footnotes) is written with `texdoc`, one LaTeX line per `tex` statement:

stata

```
local file_name = "$path/tables/<sub_folder>/table_<name>.tex"
texdoc init "`file_name'", replace force

tex \begin{table}[htpb]
tex \captionlistentry[table]{<short caption for list of tables>}
tex \label{table:<name>}
tex \centering
tex Table \ref{table:<name>}. \\
tex <Table Title in Title Case> \\
tex \begin{threeparttable}
tex \begin{tabulary}{\textwidth}{l*{<n_cols>}{c}@{}}
tex \toprule \toprule
tex \noalign{\smallskip}
tex <optional multicolumn panel/group header row(s)>
tex \cmidrule(l{5pt}r{5pt}){<range>} ...
tex \ExpandableInput{\tablePATH/results/<subfolder>/table_<name>_panel_A.tex}
tex \tabularnewline
tex <Panel B header, if any> \\
\ExpandableInput{\tablePATH/results/<subfolder>/table_<name>_panel_B.tex}
tex \noalign{\smallskip}
tex \bottomrule
tex \end{tabulary}
tex \medskip
tex \begin{tablenotes}[flushleft]
tex \setlength\labelsep{0pt}
tex \item
tex \footnotesize
tex \justify
tex Notes: <plain-English description of the specification, sample, and weighting>.
tex \end{tablenotes}
tex \end{threeparttable}
tex \end{table}

* Close table file
texdoc close
```

Fixed conventions:

* `local file_name` \+ `texdoc init "`file\_name'", replace force`immediately precedes the`tex`block; comment`\* New table file`appears directly above it and`\* Close table file`directly above the closing`texdoc close\`.  
* Every table uses the `threeparttable` \+ `tabulary` LaTeX environment pair, with `\toprule \toprule` (doubled) at the top and a single `\bottomrule` at the bottom.  
* `\captionlistentry[table]{}`, `\label{table:...}`, and the `Table \ref{table:...}.` caption line are always present, in that order, immediately after `\centering`.  
* Multi-panel tables use `\multicolumn{<n+1>}{l}{Panel A. <description>} \\` / `Panel B. ...` header rows directly above each `\ExpandableInput{}`, and separate panels with `\tabularnewline`.  
* Group/sample headers spanning multiple columns (e.g. "Combined Sample" vs. "Census Urban Sample") use `\multicolumn{}{c}{}` rows plus `\cmidrule(l{5pt}r{5pt}){a-b}` underlines, placed above the `\ExpandableInput` line(s) they describe.  
* The footnotes block (`\begin{tablenotes}[flushleft]` ... `\end{tablenotes}`) always opens with the same four boilerplate lines (`\setlength\labelsep{0pt}`, `\item`, `\footnotesize`, `\justify`) before the table-specific `Notes:` text.  
* Notes text is written as ordinary prose (not `///`\-wrapped) but broken across multiple `tex` lines at natural sentence/clause breaks.  
* Notes reference the paper's equation labels directly (`Equation \eqref{eq:pre_post_DD}`) rather than restating the specification in words.

## **14\. End of File**

* Build/data-prep `.do` files end with `compress`, then `save "<path>.dta", replace`.

```
* Final Save (for .do files):
sort <key_id_vars> 	// to keep saved files in a predictable order
compress
save "<path>.dta", replace

* Wrap Up (for all files)
log close             // Close the log file safely
```

---

# R Style Guide

---

# Python Style Guide

# How We Work

1. Whenever you download raw data, save it in a subfolder under the \~/dataRAW/ folder. Create a *source.txt* file and include in it where you got the data (e.g., link to the page or the email from the person who sent it to us), and the data it was downloaded on.   
2. 

# Collection Pile

