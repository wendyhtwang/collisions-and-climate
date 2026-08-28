#   
  
## wendy-wang@Kodama:/mnt$ tree -L 1
.
├── data_d
├── data_e
├── data_f
└── sea_of_bytes

5 directories, 0 files
  
  
  
wendy-wang@Kodama:/mnt/data_d/Dropbox/Research/AnimalCollisionsWeather$ tree
.
├── codePYTHON
│   ├── 00_setup_earth_engine.py
│   ├── 01a_test_prism_extract.py
│   ├── 01b_verify_prism_gee_console.js
│   ├── 02a_extract_prism_county.py
│   ├── 02b_extract_prism_wma.py
│   ├── 03a_test_era5_extract.py
│   ├── 03b_verify_era5_gee_console.js
│   ├── 04a_extract_era5_county.py
│   ├── 04b_extract_era5_wma.py
│   ├── 05_aggregate_daily_to_monthly.py
│   ├── 06_build_derived_weather_vars.py
│   ├── 07a_export_prism_monthly_spotcheck.py
│   ├── 07b_compare_prism_monthly_spotcheck.py
│   ├── 07c_find_ground_truth_counties.py
│   ├── 07d_aggregate_noaa_station_daily.py
│   ├── 07e_filter_prism_ground_truth_sample.py
│   ├── 07_export_prism_monthly_spotcheck.py
│   ├── 07f_extract_era5_ground_truth_points.py
│   ├── 07g_filter_era5_ground_truth_sample.py
│   ├── 07h_compare_era5_ground_truth.py
│   ├── 08_population_data.py
│   ├── 09_descriptive_weather_full.ipynb
│   ├── 09_descriptive_weather.html
│   ├── 09_descriptive_weather.ipynb
│   ├── 09_descriptive_weather.py
│   ├── aggregation_utils.py
│   ├── era5_extract_utils.py
│   ├── gee_extract_utils.py
│   ├── ground_truth_utils.py
│   ├── __pycache__
│   │   ├── 04_aggregate_daily_to_monthly.cpython-314.pyc
│   │   ├── aggregation_utils.cpython-314.pyc
│   │   └── gee_extract_utils.cpython-314.pyc
│   ├── requirements.txt
│   └── SCRIPT_OVERVIEW.md
├── codeSTATA
│   ├── _project_main.do
│   └── set_figure_fonts_colors.do
├── dataCSV
│   ├── ERA5
│   │   ├── era5_county_month.csv
│   │   ├── era5_derived_weather_vars.csv
│   │   ├── logs
│   │   │   ├── era5_full_extract_20260805_100350.log
│   │   │   └── era5_full_extract_20260806_161249.log
│   │   └── spot_check
│   │       ├── era5_at_point_month.csv
│   │       ├── era5_ground_truth_comparison.csv
│   │       ├── era5_ground_truth_sample.csv
│   │       └── raw_hourly
│   │           ├── USC00123777_2021_12.grib
│   │           ├── USC00312635_2000_01.grib
│   │           └── USC00405525_1999_06.grib
│   └── PRISM
│       ├── prism_county_month.csv
│       ├── prism_county_month_sample.csv
│       ├── prism_derived_weather_vars.csv
│       ├── prism_spotcheck_monthly_20260806_140936.csv
│       └── spot_check
│           ├── ground_truth_candidate_counties.csv
│           ├── monthly_gee
│           │   └── results
│           │       ├── prism_monthly_spotcheck_comparison_20260806_160734.csv
│           │       └── prism_monthly_spotcheck_summary_20260806_160734.csv
│           ├── noaa_station_daily_data
│           │   ├── noaa_station_month.csv
│           │   ├── USC00123777_2021_12.csv
│           │   ├── USC00312635_2000_01.csv
│           │   └── USC00405525_1999_06.csv
│           └── prism_ground_truth_sample.csv
├── dataGIS
├── dataPYTHON
├── dataRAW
│   └── data_dictionary_DVCs.xlsx
├── dataSTATA
├── documentation
│   ├── FromJen
│   │   ├── Deer Economics.pdf
│   │   ├── DVC literature.xls
│   │   ├── Management workbook for WTD_full.pdf
│   │   ├── raynor-DVC chapter.pdf
│   │   ├── readme.txt
│   │   └── Reference Summaries_DVC.xlsx
│   └── wildlife_passages_top22_papers.xlsx
├── figures
│   └── weather
│       ├── era5_sanity_county_spaghetti_mean_temp_c_state17.png
│       ├── era5_sanity_national_trend_days_below_freezing_32f.png
│       ├── era5_sanity_national_trend_freeze_thaw_days.png
│       ├── era5_sanity_national_trend_mean_temp_c.png
│       ├── era5_sanity_state_small_multiples_days_below_freezing_32f.png
│       ├── era5_sanity_state_small_multiples_freeze_thaw_days.png
│       ├── era5_sanity_state_small_multiples_mean_temp_c.png
│       ├── prism_sanity_county_spaghetti_mean_temp_c_state17.png
│       ├── prism_sanity_county_spaghetti_multipanel_mean_temp_c.png
│       ├── prism_sanity_national_trend_days_below_freezing_32f.png
│       ├── prism_sanity_national_trend_days_extremely_cold.png
│       ├── prism_sanity_national_trend_freeze_thaw_days.png
│       ├── prism_sanity_national_trend_mean_temp_c.png
│       ├── prism_sanity_state_small_multiples_days_below_freezing_32f.png
│       ├── prism_sanity_state_small_multiples_days_extremely_cold.png
│       ├── prism_sanity_state_small_multiples_freeze_thaw_days.png
│       ├── prism_sanity_state_small_multiples_mean_temp_c.png
│       ├── tier1
│       │   ├── prism_county_spaghetti_mean_temp_c.pdf
│       │   ├── prism_interannual_variability_choropleth.pdf
│       │   ├── prism_national_trend_days_below_freezing_32f.pdf
│       │   ├── prism_national_trend_days_extremely_cold.pdf
│       │   ├── prism_national_trend_freeze_thaw_days.pdf
│       │   ├── prism_national_trend_mean_temp_c.pdf
│       │   ├── prism_state_decade_distributions_mean_temp_c.pdf
│       │   ├── prism_state_trends_days_below_freezing_32f.pdf
│       │   ├── prism_state_trends_days_extremely_cold.pdf
│       │   ├── prism_state_trends_freeze_thaw_days.pdf
│       │   └── prism_state_trends_mean_temp_c.pdf
│       └── tier2
│           ├── prism_anomalous_warm_winter_frequency_provisional.pdf
│           ├── prism_anomalous_warm_winter_time_series_provisional.pdf
│           ├── prism_era5_national_winter_temperature_comparison.pdf
│           ├── prism_extreme_cold_day_count.pdf
│           ├── prism_national_long_run_warming.pdf
│           ├── prism_national_winter_temperature_distributions_by_decade.pdf
│           ├── prism_state_long_run_warming.pdf
│           ├── prism_winter_temperature_change.pdf
│           └── prism_winter_temperature_early_vs_recent.pdf
├── grants
│   └── ICSG_Summer_RA
│       └── Award Letter - Frank.pdf
├── paper
├── slides
└── tables
    └── weather
        ├── era5_summary_by_county.csv
        ├── era5_summary_by_month.csv
        ├── era5_summary_pooled.csv
        ├── prism_summary_by_county.csv
        ├── prism_summary_by_month.csv
        ├── prism_summary_pooled.csv
        ├── tier1
        │   ├── prism_county_interannual_variability.csv
        │   ├── prism_interannual_variability_by_state.csv
        │   ├── prism_interannual_variability_by_state.pdf
        │   ├── prism_summary_by_calendar_month.csv
        │   ├── prism_summary_by_calendar_month.pdf
        │   ├── prism_summary_by_county.csv
        │   ├── prism_summary_by_county_review_flags.csv
        │   ├── prism_summary_by_county_review_flags.pdf
        │   ├── prism_summary_pooled.csv
        │   ├── prism_summary_pooled.pdf
        │   ├── prism_tier1_coverage_integrity.csv
        │   ├── prism_tier1_coverage_integrity.pdf
        │   ├── prism_tier1_qa_findings.csv
        │   └── prism_tier1_qa_findings.pdf
        └── tier2
            ├── prism_annual_anomalous_warm_winter_frequency_provisional.csv
            ├── prism_anomaly_definition_provisional.csv
            ├── prism_county_anomalous_warm_winter_frequency_provisional.csv
            ├── prism_county_extreme_cold_days.csv
            ├── prism_county_temperature_early_recent.csv
            ├── prism_county_winter_warm_anomalies_provisional.csv
            ├── prism_era5_national_winter_temperature_comparison.csv
            ├── prism_tier2_decisions_for_eyal.csv
            ├── prism_tier2_exhibit_index.csv
            └── prism_tier2_output_manifest.csv

32 directories, 134 files



  
  
## wendy-wang@Kodama:/mnt/data_f/AnimalCollisionsWeatherData$ tree 
.
├── ERA5
│   ├── derived
│   ├── extracted
│   │   └── county_daily_year
│   │       ├── era5_county_daily_1981_20260805_100350.csv
│   │       ├── era5_county_daily_1982_20260805_100350.csv
│   │       ├── era5_county_daily_1983_20260805_100350.csv
│   │       ├── era5_county_daily_1984_20260805_100350.csv
│   │       ├── era5_county_daily_1985_20260805_100350.csv
│   │       ├── era5_county_daily_1986_20260805_100350.csv
│   │       ├── era5_county_daily_1987_20260805_100350.csv
│   │       ├── era5_county_daily_1988_20260805_100350.csv
│   │       ├── era5_county_daily_1989_20260805_100350.csv
│   │       ├── era5_county_daily_1990_20260805_100350.csv
│   │       ├── era5_county_daily_1991_20260805_100350.csv
│   │       ├── era5_county_daily_1992_20260805_100350.csv
│   │       ├── era5_county_daily_1993_20260805_100350.csv
│   │       ├── era5_county_daily_1994_20260805_100350.csv
│   │       ├── era5_county_daily_1995_20260805_100350.csv
│   │       ├── era5_county_daily_1996_20260805_100350.csv
│   │       ├── era5_county_daily_1997_20260805_100350.csv
│   │       ├── era5_county_daily_1998_20260805_100350.csv
│   │       ├── era5_county_daily_1999_20260805_100350.csv
│   │       ├── era5_county_daily_2000_20260805_100350.csv
│   │       ├── era5_county_daily_2001_20260805_100350.csv
│   │       ├── era5_county_daily_2002_20260805_100350.csv
│   │       ├── era5_county_daily_2003_20260805_100350.csv
│   │       ├── era5_county_daily_2004_20260805_100350.csv
│   │       ├── era5_county_daily_2005_20260805_100350.csv
│   │       ├── era5_county_daily_2006_20260805_100350.csv
│   │       ├── era5_county_daily_2007_20260805_100350.csv
│   │       ├── era5_county_daily_2008_20260805_100350.csv
│   │       ├── era5_county_daily_2009_20260805_100350.csv
│   │       ├── era5_county_daily_2010_20260806_161249.csv
│   │       ├── era5_county_daily_2011_20260806_161249.csv
│   │       ├── era5_county_daily_2012_20260806_161249.csv
│   │       ├── era5_county_daily_2013_20260806_161249.csv
│   │       ├── era5_county_daily_2014_20260806_161249.csv
│   │       ├── era5_county_daily_2015_20260806_161249.csv
│   │       ├── era5_county_daily_2016_20260806_161249.csv
│   │       ├── era5_county_daily_2017_20260806_161249.csv
│   │       ├── era5_county_daily_2018_20260806_161249.csv
│   │       ├── era5_county_daily_2019_20260806_161249.csv
│   │       ├── era5_county_daily_2020_20260806_161249.csv
│   │       ├── era5_county_daily_2021_20260806_161249.csv
│   │       ├── era5_county_daily_2022_20260806_161249.csv
│   │       ├── era5_county_daily_2023_20260806_161249.csv
│   │       ├── era5_county_daily_2024_20260806_161249.csv
│   │       └── era5_county_daily_2025_20260806_161249.csv
│   └── source.txt
└── PRISM
    ├── derived
    ├── extracted
    │   └── county_daily_year
    │       ├── prism_county_daily_1981_20260730_011010.csv
    │       ├── prism_county_daily_1982_20260730_011010.csv
    │       ├── prism_county_daily_1983_20260730_011010.csv
    │       ├── prism_county_daily_1984_20260730_011010.csv
    │       ├── prism_county_daily_1985_20260730_011010.csv
    │       ├── prism_county_daily_1986_20260730_011010.csv
    │       ├── prism_county_daily_1987_20260730_011010.csv
    │       ├── prism_county_daily_1988_20260730_011010.csv
    │       ├── prism_county_daily_1989_20260730_011010.csv
    │       ├── prism_county_daily_1990_20260730_011010.csv
    │       ├── prism_county_daily_1991_20260730_011010.csv
    │       ├── prism_county_daily_1992_20260730_011010.csv
    │       ├── prism_county_daily_1993_20260730_011010.csv
    │       ├── prism_county_daily_1994_20260730_011010.csv
    │       ├── prism_county_daily_1995_20260730_011010.csv
    │       ├── prism_county_daily_1996_20260730_011010.csv
    │       ├── prism_county_daily_1997_20260730_011010.csv
    │       ├── prism_county_daily_1998_20260730_011010.csv
    │       ├── prism_county_daily_1999_20260730_011010.csv
    │       ├── prism_county_daily_2000_20260730_011010.csv
    │       ├── prism_county_daily_2001_20260730_011010.csv
    │       ├── prism_county_daily_2002_20260730_011010.csv
    │       ├── prism_county_daily_2003_20260730_011010.csv
    │       ├── prism_county_daily_2004_20260730_011010.csv
    │       ├── prism_county_daily_2005_20260730_011010.csv
    │       ├── prism_county_daily_2006_20260730_011010.csv
    │       ├── prism_county_daily_2007_20260730_011010.csv
    │       ├── prism_county_daily_2008_20260730_011010.csv
    │       ├── prism_county_daily_2009_20260730_011010.csv
    │       ├── prism_county_daily_2010_20260730_011010.csv
    │       ├── prism_county_daily_2011_20260730_011010.csv
    │       ├── prism_county_daily_2012_20260730_011010.csv
    │       ├── prism_county_daily_2013_20260730_011010.csv
    │       ├── prism_county_daily_2014_20260730_011010.csv
    │       ├── prism_county_daily_2015_20260730_011010.csv
    │       ├── prism_county_daily_2016_20260730_011010.csv
    │       ├── prism_county_daily_2017_20260730_011010.csv
    │       ├── prism_county_daily_2018_20260730_011010.csv
    │       ├── prism_county_daily_2019_20260730_011010.csv
    │       ├── prism_county_daily_2020_20260730_011010.csv
    │       ├── prism_county_daily_2021_20260730_011010.csv
    │       ├── prism_county_daily_2022_20260730_011010.csv
    │       ├── prism_county_daily_2023_20260730_011010.csv
    │       ├── prism_county_daily_2024_20260730_011010.csv
    │       └── prism_county_daily_2025_20260730_011010.csv
    └── source.txt

9 directories, 92 files




## wendy-wang@Kodama:/mnt/data_d/Dropbox/Research/UngulatePopulationDataRepo$ tree -L 3
.
├── codeSTATA
│   ├── logs
│   │   └── VA_deer_harmonization.log
│   ├── MO
│   │   └── MO_deer_harmonization.do
│   ├── NC
│   │   └── NC_deer_harmonization.do
│   ├── OH
│   │   └── OH_deer_harmonization.do
│   ├── VA
│   │   ├── VA_deer_harmonization.do
│   │   └── VA_deer_harmonization_trimmed.do
│   └── WI
│       └── WI_deer_harmonization.do
├── dataCLEAN
│   ├── MO
│   │   └── MO_deer_harmonized_county_year_2002-2014.dta
│   ├── NC
│   │   └── NC_deer_harmonized_county_year_1976-2014.dta
│   ├── OH
│   │   └── OH_deer_harmonized_county_year_1980-2014.dta
│   ├── VA
│   │   └── VA_deer_harmonized_county_year_1947-2014.dta
│   └── WI
├── dataRAW
│   ├── auto_inventory_deer_harvest.csv
│   ├── auto_inventory_deer_population.csv
│   ├── Data sources and contacts summary.xlsx
│   ├── Deer, Elk, Turkey Data.zip
│   ├── Deer_Harvest
│   │   ├── AL
│   │   ├── AL.Harvest.1963-2014.StateSex.Cook.xlsx
│   │   ├── AR
│   │   ├── AZ
│   │   ├── CA
│   │   ├── CA.Harvest.1927-09.CountySex.Web.docx
│   │   ├── CA.Harvest.1927-09.CountySex.Web.pdf
│   │   ├── CA.Harvest.1927-09.CountySex.Web.xlsx
│   │   ├── CO
│   │   ├── CT
│   │   ├── DE
│   │   ├── Deer Harvest by State.xlsx
│   │   ├── DE.Harvest.2010-2015.CountySex.Boyd(1).xlsx
│   │   ├── DE.Harvest.2010-2015.CountySex.Boyd.xlsx
│   │   ├── FL
│   │   ├── ID
│   │   ├── IL
│   │   ├── IN.Harvest.05-15.CountySex.Caudell.xlsx
│   │   ├── KY
│   │   ├── LA
│   │   ├── MA.Harvest.1985-2014.DMUSex.Stainbrook.xlsx
│   │   ├── MA.Harvest.2014.DMUDetailed.Stainbrook.pdf
│   │   ├── MD.Harvest.1931-2014.CountySex.Eyler(1).xls
│   │   ├── MD.Harvest.1931-2014.CountySex.Eyler.xls
│   │   ├── ME
│   │   ├── MI.Harvest.1931-2015.StateSex.Stewart.xlsx
│   │   ├── MN.Murkowski
│   │   ├── MO
│   │   ├── MT
│   │   ├── NC
│   │   ├── NE
│   │   ├── NH.Harvest.1980-2014.WMUSex.Bergeron.xlsx
│   │   ├── NJ
│   │   ├── NJ.Harvest.1986-2015.CountySex.Roberts.xlsx
│   │   ├── NM
│   │   ├── NV
│   │   ├── NY.Harvest.1954-2014.CountyTownSex.Kelly.csv
│   │   ├── OH.Harvest.80-14.CountySex.McCoy.xlsx
│   │   ├── OK.Harvest.92-15.StateSex.Bartholomew.xlsx
│   │   ├── OR
│   │   ├── OR.Harvest.12-20.WMUSexSpecies.12-20.Dion.xlsx
│   │   ├── PA
│   │   ├── RI
│   │   ├── SC
│   │   ├── SD
│   │   ├── SD.Harvest.97-15.StateSpecies.Huxoll.xlsx
│   │   ├── TN
│   │   ├── TX
│   │   ├── UT
│   │   ├── UT.Harvest.pdf
│   │   ├── VA
│   │   ├── VT
│   │   ├── WA
│   │   ├── WI
│   │   ├── WV
│   │   ├── WV.Harvest.2011-15.CountySex.Web.docx
│   │   ├── WV.Harvest.2011-15.CountySex.Web.pdf
│   │   ├── WY
│   │   └── WY.Harvest.1994-2015.StateSex.Frost.xlsx
│   ├── deer_harvest_data_inventory.R
│   ├── Deer_Population
│   │   ├── AL
│   │   ├── AZ
│   │   ├── CA
│   │   ├── CO
│   │   ├── CO.Deer Pop Plans.webloc
│   │   ├── CT
│   │   ├── DE
│   │   ├── Deer Population 1450+ Methods.pdf
│   │   ├── Deer Population 1450+.xlsx
│   │   ├── GA.PopHarvest.2005-2015.State.Killmaster.xlsx
│   │   ├── ID
│   │   ├── ID.DeerPlan.2005-2014.Ackerman.pdf
│   │   ├── KY.Pop.99-15.State.Sams.xlsx
│   │   ├── MD.Pop.1988-2014.State.Eyler.xlsx
│   │   ├── ME
│   │   ├── MI.Pop.1938-2015.Region.Stewart.xls
│   │   ├── MN
│   │   ├── MO.Pop.02-15.County.Lombardo.xlsx
│   │   ├── MT
│   │   ├── NC.PopHarvest.1976-2014.CountySex.Shaw.xlsx
│   │   ├── ND
│   │   ├── NH
│   │   ├── NJ.Pop.1986-2015.State.Roberts.xlsx
│   │   ├── OH.PopHarvest.80-14.CountySex.McCoy.xlsx
│   │   ├── OR
│   │   ├── PA
│   │   ├── QDMA data _ maps
│   │   ├── QDMA deer population.pdf
│   │   ├── SC
│   │   ├── TX
│   │   ├── USA
│   │   ├── UT
│   │   ├── VA
│   │   ├── VT.Pop.2000-15.State.Fortin.xlsx
│   │   ├── WesternUS.MD_BTD.Stoner.pdf
│   │   ├── WesternUS.MonitoringMDPopulations.Stoner.pdf
│   │   ├── White-tailed Deer Ecology and Management.pdf
│   │   ├── WI
│   │   └── WY
│   ├── deer_population_data_inventory.R
│   ├── Elk_Harvest
│   │   ├── AZ
│   │   ├── CO
│   │   ├── CT
│   │   ├── ID
│   │   ├── ME
│   │   ├── MT
│   │   ├── NV
│   │   ├── OR
│   │   ├── UT
│   │   ├── VT
│   │   ├── WA
│   │   └── WY
│   ├── Elk_Population
│   │   ├── AZ
│   │   ├── CO
│   │   ├── CT
│   │   ├── ID
│   │   ├── ME
│   │   ├── MT
│   │   ├── UT
│   │   ├── VT
│   │   ├── WA
│   │   └── WY
│   ├── NAWA_CWD
│   │   ├── NA_wildlife_agency_CWD_surveillance_data_2000_2022_v2.csv
│   │   ├── readme.txt
│   │   └── source.txt
│   ├── Turkey_Harvest
│   │   ├── AL
│   │   ├── AZ
│   │   ├── CT
│   │   ├── ID
│   │   ├── ME
│   │   ├── MT
│   │   ├── NJ
│   │   ├── OR
│   │   ├── RI
│   │   ├── SC
│   │   ├── TX
│   │   ├── UT
│   │   ├── VT
│   │   ├── WA
│   │   └── WY
│   └── Turkey_Population
│       ├── AL
│       ├── AZ
│       ├── CT
│       ├── ID
│       ├── ME
│       ├── MT
│       ├── VT
│       ├── WA
│       └── WY
├── dataSTATA
│   ├── MO
│   │   ├── MO_county_crosswalk.dta
│   │   ├── temp_MO_harvest_2002-2011.dta
│   │   ├── temp_MO_harvest_2002-2014_raw.dta
│   │   ├── temp_MO_harvest_2012-2014.dta
│   │   └── temp_MO_population_2002-2014.dta
│   ├── NC
│   │   ├── NC_county_crosswalk.dta
│   │   └── temp_NC_harvest_1976-2014_raw.dta
│   ├── OH
│   │   ├── OH_county_crosswalk.dta
│   │   ├── temp_OH_harvest_1980-2014_raw.dta
│   │   └── temp_OH_population_1981-2014_raw.dta
│   ├── VA
│   │   ├── temp_VA_bki_1994-2014_private.dta
│   │   ├── temp_VA_bki_1994-2014_public.dta
│   │   ├── temp_VA_bki_1994-2014_raw.dta
│   │   ├── temp_VA_harvest_1947-2014_private.dta
│   │   ├── temp_VA_harvest_1947-2014_public.dta
│   │   ├── temp_VA_harvest_1947-2014_raw.dta
│   │   ├── temp_VA_harvest_1947-2014_total.dta
│   │   ├── temp_VA_popstatus_2014_raw.dta
│   │   ├── VA_county_crosswalk.dta
│   │   └── VA_county_crosswalk_nameonly.dta
│   └── WI
│       ├── temp_WI_harvest_1960-2015_raw.dta
│       └── WI_county_crosswalk.dta
├── Pop_Harvest_Data.zip
└── Wendy Extraction
    ├── audit.csv
    ├── classify_pdfs.py
    ├── deer_harvest_audit.csv
    ├── extract_metadata.py
    ├── metadata_extraction
    │   ├── bin
    │   ├── include
    │   ├── lib
    │   ├── lib64 -> lib
    │   └── pyvenv.cfg
    └── repo_structure.md

137 directories, 90 files


## wendy-wang@Kodama:/mnt/data_d/Dropbox/Research/VehicleCollisionsDataRepo$ tree -L 3
.
├── codeR
│   ├── IA_Shapefile_Conversion.R
│   ├── Nicole_IA_Shapefile_Conversion_082126_edited.R
│   ├── Nicole_IA_Shapefile_Conversion_082126.R
│   ├── Nicole_IA_Shapefile_Conversion.knit.md
│   └── Nicole_IA_Shapefile_Conversion.qmd
├── codeSTATA
│   ├── Charvi - code WIP
│   │   ├── CT WIP Charvi.do
│   │   ├── IA WIP Charvi.do
│   │   └── IA WIP Wendy edits.do
│   ├── data_append_state_collisions_files.do
│   ├── data_dvcs_county_year_split
│   │   ├── AL.do
│   │   ├── AR.do
│   │   ├── AZ.do
│   │   ├── CA.do
│   │   ├── CO.do
│   │   ├── CT.do
│   │   ├── DE.do
│   │   ├── FL.do
│   │   ├── GA.do
│   │   ├── IA.do
│   │   ├── ID.do
│   │   ├── IL.do
│   │   ├── IN.do
│   │   ├── KS.do
│   │   ├── KY.do
│   │   ├── LA.do
│   │   ├── MA.do
│   │   ├── MD.do
│   │   ├── ME.do
│   │   ├── MI.do
│   │   ├── MN.do
│   │   ├── MO.do
│   │   ├── MS.do
│   │   ├── MT.do
│   │   ├── NC.do
│   │   ├── ND.do
│   │   ├── NE.do
│   │   ├── NH.do
│   │   ├── NJ.do
│   │   ├── NM.do
│   │   ├── NV.do
│   │   ├── NY.do
│   │   ├── OH.do
│   │   ├── OK.do
│   │   ├── OR.do
│   │   ├── PA.do
│   │   ├── SC.do
│   │   ├── SD.do
│   │   ├── TN.do
│   │   ├── TX.do
│   │   ├── UT.do
│   │   ├── VA.do
│   │   ├── VT.do
│   │   ├── WA.do
│   │   ├── WI.do
│   │   ├── WV.do
│   │   └── WY.do
│   ├── data_import_FARS.do
│   ├── data_population_county_year.do
│   ├── data_state_county_identifiers.do
│   └── Emily - code WIP
│       ├── CT WIP.do
│       ├── DE WIP.do
│       ├── IA WIP.do
│       ├── ID WIP.do
│       └── PA WIP.do
├── dataCSV
│   └── DVCs
│       ├── AL
│       ├── AR
│       ├── AZ
│       ├── CO
│       ├── DE
│       ├── FL
│       ├── GA
│       ├── IA
│       ├── IL
│       ├── IN
│       ├── KS
│       ├── KY
│       ├── ME
│       ├── MI
│       ├── MN
│       ├── MS
│       ├── ND
│       ├── NE
│       ├── NJ
│       ├── NM
│       ├── NY
│       ├── OH
│       ├── OK
│       ├── OR
│       ├── PA
│       ├── SC
│       ├── SD
│       ├── TN
│       ├── TX
│       ├── UT
│       ├── VA
│       ├── VT
│       ├── WA
│       └── WY
├── dataRAW
│   ├── Data sources and contacts summary.xlsx
│   ├── DVC and Deer pop availability summary.xlsx
│   ├── DVCs
│   │   ├── 0-DVC Coverage Map.docx
│   │   ├── 1-Crash report availability (old).xlsx
│   │   ├── AL
│   │   ├── AR
│   │   ├── AZ
│   │   ├── CA
│   │   ├── CO
│   │   ├── CT
│   │   ├── dates_end_EF_comments.xlsx
│   │   ├── DE
│   │   ├── DVC sources and metadata.xlsx
│   │   ├── FL
│   │   ├── GA
│   │   ├── HSIS
│   │   ├── IA
│   │   ├── ID
│   │   ├── IL
│   │   ├── IN
│   │   ├── KS
│   │   ├── KY
│   │   ├── LA
│   │   ├── MA
│   │   ├── MD
│   │   ├── ME
│   │   ├── MI
│   │   ├── MN
│   │   ├── MO
│   │   ├── MS
│   │   ├── MT
│   │   ├── NC
│   │   ├── ND
│   │   ├── NE
│   │   ├── NH
│   │   ├── NJ
│   │   ├── NM
│   │   ├── NV
│   │   ├── NY
│   │   ├── OH
│   │   ├── OK
│   │   ├── OR
│   │   ├── PA
│   │   ├── RI
│   │   ├── SC
│   │   ├── SD
│   │   ├── StateFarm.pdf
│   │   ├── TN
│   │   ├── TX
│   │   ├── UT
│   │   ├── VA
│   │   ├── VT
│   │   ├── WA
│   │   ├── WI
│   │   ├── WV
│   │   └── WY
│   ├── FARS
│   │   ├── FARS1975NationalCSV
│   │   ├── FARS1976NationalCSV
│   │   ├── FARS1977NationalCSV
│   │   ├── FARS1978NationalCSV
│   │   ├── FARS1979NationalCSV
│   │   ├── FARS1980NationalCSV
│   │   ├── FARS1981NationalCSV
│   │   ├── FARS1982NationalCSV
│   │   ├── FARS1983NationalCSV
│   │   ├── FARS1984NationalCSV
│   │   ├── FARS1985NationalCSV
│   │   ├── FARS1986NationalCSV
│   │   ├── FARS1987NationalCSV
│   │   ├── FARS1988NationalCSV
│   │   ├── FARS1989NationalCSV
│   │   ├── FARS1990NationalCSV
│   │   ├── FARS1991NationalCSV
│   │   ├── FARS1992NationalCSV
│   │   ├── FARS1993NationalCSV
│   │   ├── FARS1994NationalCSV
│   │   ├── FARS1995NationalCSV
│   │   ├── FARS1996NationalCSV
│   │   ├── FARS1997NationalCSV
│   │   ├── FARS1998NationalCSV
│   │   ├── FARS1999NationalCSV
│   │   ├── FARS2000NationalCSV
│   │   ├── FARS2001NationalCSV
│   │   ├── FARS2002NationalCSV
│   │   ├── FARS2003NationalCSV
│   │   ├── FARS2004NationalCSV
│   │   ├── FARS2005NationalCSV
│   │   ├── FARS2006NationalCSV
│   │   ├── FARS2007NationalCSV
│   │   ├── FARS2008NationalCSV
│   │   ├── FARS2009NationalCSV
│   │   ├── FARS2010NationalCSV
│   │   ├── FARS2011NationalCSV
│   │   ├── FARS2012NationalCSV
│   │   ├── FARS2013NationalCSV
│   │   ├── FARS2014NationalCSV
│   │   ├── FARS2015NationalCSV
│   │   ├── FARS2016NationalCSV
│   │   ├── FARS2017NationalCSV
│   │   ├── FARS2018NationalCSV
│   │   ├── FARS2019NationalCSV
│   │   └── source.txt
│   ├── FIPs
│   │   ├── FIPS_County_WI.txt
│   │   └── FIPS_States_USA.txt
│   ├── Population
│   │   ├── 1969_2019
│   │   ├── 1980_1989
│   │   ├── 1990_1999
│   │   ├── CountyAgeSex_2000_2010.csv
│   │   ├── countyagesex_2010_2014.csv
│   │   ├── countyagesex_2010_2017.csv
│   │   ├── countyagesex_2010_2019.csv
│   │   ├── Documentation1990_1999.txt
│   │   ├── Documentation_2000_2010.pdf
│   │   ├── Documentation_2010_2014.pdf
│   │   ├── Documentation_2010_2017.pdf
│   │   └── source.txt
│   └── US_state_county_identifiers
│       ├── all-geocodes-v2017.xlsx
│       ├── source.txt
│       ├── stateABB.csv
│       ├── US_FIPS_Codes.txt
│       ├── US_FIPS_Codes.xls
│       └── US_State_Abb.txt
├── dataSTATA
│   ├── city_town_identifiers.dta
│   ├── dvcs_AZ_county_year_1997_2024.dta
│   ├── dvcs_CO_county_year_2000_2024.dta
│   ├── dvcs_CT_15_19.dta
│   ├── dvcs_CT_95_14.dta
│   ├── dvcs_CT_MID1_CTDOT.dta
│   ├── dvcs_CT_MID2_MMUC.dta
│   ├── dvcs_DE_county_year_2004_2024.dta
│   ├── dvcs_IA_county_year_2004_2026.dta
│   ├── dvcs_IA_county_year_2015_2026.dta
│   ├── dvcs_IA_excluded_crashes.dta
│   ├── dvcs_PA_county_year_1997_2024.dta
│   ├── state_county_identifiers.dta
│   └── state_identifiers.dta
└── logistics
    ├── RA_applications
    │   └── Eyal Frank
    └── RA_applications.zip



