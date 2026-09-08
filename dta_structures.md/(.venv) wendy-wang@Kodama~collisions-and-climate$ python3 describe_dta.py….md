#   
  
## (.venv) wendy-wang@Kodama:~/collisions-and-climate$ python3 describe_dta.py /mnt/data_d/Dropbox/Research/AnimalCollisionsWeather/dataSTATA/US_deer_harvest_county_year_04sep2026.dta  
  
US_deer_harvest_county_year_04sep2026.dta  
  
Variable                   Label                                                                     Type   
-------------------------  ------------------------------------------------------------------------  -----  
state                      State postal abbreviation                                                 str2   
county_fips                5-digit county FIPS code                                                  str5   
county_name                County name, as reported by the source                                    str26  
year                       Season start year (project convention)                                    int    
harvest_total              Total deer harvested, all categories combined                             int    
source_harvest             Compilation: agency-direct harmonization or Schuler et al. CWD panel      str6   
flag_total_constructed     =1 if total was constructed from components rather than source-reported   byte   
flag_hand_transcribed      =1 if figure was hand-transcribed from an image-scanned report (WV only)  byte   
harvest_total_cwd_imputed  CWD imputed harvest value, parked and NOT used in harvest_total           int    
in_window                  =1 if year in 2005-2014 and harvest observed                              byte   
main_sample                =1 if county balanced across all of 2005-2014 (both sources)              byte   
main_sample_agency         =1 if balanced 2005-2014 AND agency-direct (robustness sample)            byte   
  
Number of variables:    12  
Number of observations: 42471  
Sorted by: state county_fips year  
  
  
  
  
  
  
## (.venv) wendy-wang@Kodama:~/collisions-and-climate$ python3 describe_dta.py /mnt/data_d/Dropbox/Research/AnimalCollisionsWeather/dataSTATA/main_data_county_year.dta   
  
main_data_county_year.dta  
  
Variable                        Label                                                                             Type    
------------------------------  --------------------------------------------------------------------------------  ------  
geoid                                                                                                             str5    
fips_num                        Numeric county FIPS (real(geoid)); geoid remains the canonical string merge key   long    
state_fips                                                                                                        str2    
county_fips                                                                                                       str3    
county_name                                                                                                       str24   
year                                                                                                              int     
n_incomplete_months                                                                                               byte    
n_days_m1                       1 n_days                                                                          byte    
days_extremely_cold_m1          1 days_extremely_cold                                                             byte    
days_below_freezing_32f_m1      1 days_below_freezing_32f                                                         byte    
freeze_thaw_days_m1             1 freeze_thaw_days                                                                byte    
days_precip_above_10mm_m1       1 days_precip_above_10mm                                                          byte    
heating_degree_days_m1          1 heating_degree_days                                                             float   
cooling_degree_days_m1          1 cooling_degree_days                                                             float   
mean_temp_c_m1                  1 mean_temp_c                                                                     float   
tmean_variance_c2_m1            1 tmean_variance_c2                                                               float   
tmin_variance_c2_m1             1 tmin_variance_c2                                                                float   
tmax_variance_c2_m1             1 tmax_variance_c2                                                                float   
n_days_m2                       2 n_days                                                                          byte    
days_extremely_cold_m2          2 days_extremely_cold                                                             byte    
days_below_freezing_32f_m2      2 days_below_freezing_32f                                                         byte    
freeze_thaw_days_m2             2 freeze_thaw_days                                                                byte    
days_precip_above_10mm_m2       2 days_precip_above_10mm                                                          byte    
heating_degree_days_m2          2 heating_degree_days                                                             float   
cooling_degree_days_m2          2 cooling_degree_days                                                             float   
mean_temp_c_m2                  2 mean_temp_c                                                                     float   
tmean_variance_c2_m2            2 tmean_variance_c2                                                               float   
tmin_variance_c2_m2             2 tmin_variance_c2                                                                float   
tmax_variance_c2_m2             2 tmax_variance_c2                                                                float   
n_days_m3                       3 n_days                                                                          byte    
days_extremely_cold_m3          3 days_extremely_cold                                                             byte    
days_below_freezing_32f_m3      3 days_below_freezing_32f                                                         byte    
freeze_thaw_days_m3             3 freeze_thaw_days                                                                byte    
days_precip_above_10mm_m3       3 days_precip_above_10mm                                                          byte    
heating_degree_days_m3          3 heating_degree_days                                                             float   
cooling_degree_days_m3          3 cooling_degree_days                                                             float   
mean_temp_c_m3                  3 mean_temp_c                                                                     float   
tmean_variance_c2_m3            3 tmean_variance_c2                                                               float   
tmin_variance_c2_m3             3 tmin_variance_c2                                                                float   
tmax_variance_c2_m3             3 tmax_variance_c2                                                                float   
n_days_m4                       4 n_days                                                                          byte    
days_extremely_cold_m4          4 days_extremely_cold                                                             byte    
days_below_freezing_32f_m4      4 days_below_freezing_32f                                                         byte    
freeze_thaw_days_m4             4 freeze_thaw_days                                                                byte    
days_precip_above_10mm_m4       4 days_precip_above_10mm                                                          byte    
heating_degree_days_m4          4 heating_degree_days                                                             float   
cooling_degree_days_m4          4 cooling_degree_days                                                             float   
mean_temp_c_m4                  4 mean_temp_c                                                                     float   
tmean_variance_c2_m4            4 tmean_variance_c2                                                               float   
tmin_variance_c2_m4             4 tmin_variance_c2                                                                float   
tmax_variance_c2_m4             4 tmax_variance_c2                                                                float   
n_days_m5                       5 n_days                                                                          byte    
days_extremely_cold_m5          5 days_extremely_cold                                                             byte    
days_below_freezing_32f_m5      5 days_below_freezing_32f                                                         byte    
freeze_thaw_days_m5             5 freeze_thaw_days                                                                byte    
days_precip_above_10mm_m5       5 days_precip_above_10mm                                                          byte    
heating_degree_days_m5          5 heating_degree_days                                                             float   
cooling_degree_days_m5          5 cooling_degree_days                                                             float   
mean_temp_c_m5                  5 mean_temp_c                                                                     float   
tmean_variance_c2_m5            5 tmean_variance_c2                                                               float   
tmin_variance_c2_m5             5 tmin_variance_c2                                                                float   
tmax_variance_c2_m5             5 tmax_variance_c2                                                                float   
n_days_m6                       6 n_days                                                                          byte    
days_extremely_cold_m6          6 days_extremely_cold                                                             byte    
days_below_freezing_32f_m6      6 days_below_freezing_32f                                                         byte    
freeze_thaw_days_m6             6 freeze_thaw_days                                                                byte    
days_precip_above_10mm_m6       6 days_precip_above_10mm                                                          byte    
heating_degree_days_m6          6 heating_degree_days                                                             float   
cooling_degree_days_m6          6 cooling_degree_days                                                             float   
mean_temp_c_m6                  6 mean_temp_c                                                                     float   
tmean_variance_c2_m6            6 tmean_variance_c2                                                               float   
tmin_variance_c2_m6             6 tmin_variance_c2                                                                float   
tmax_variance_c2_m6             6 tmax_variance_c2                                                                float   
n_days_m7                       7 n_days                                                                          byte    
days_extremely_cold_m7          7 days_extremely_cold                                                             byte    
days_below_freezing_32f_m7      7 days_below_freezing_32f                                                         byte    
freeze_thaw_days_m7             7 freeze_thaw_days                                                                byte    
days_precip_above_10mm_m7       7 days_precip_above_10mm                                                          byte    
heating_degree_days_m7          7 heating_degree_days                                                             float   
cooling_degree_days_m7          7 cooling_degree_days                                                             float   
mean_temp_c_m7                  7 mean_temp_c                                                                     float   
tmean_variance_c2_m7            7 tmean_variance_c2                                                               float   
tmin_variance_c2_m7             7 tmin_variance_c2                                                                float   
tmax_variance_c2_m7             7 tmax_variance_c2                                                                float   
n_days_m8                       8 n_days                                                                          byte    
days_extremely_cold_m8          8 days_extremely_cold                                                             byte    
days_below_freezing_32f_m8      8 days_below_freezing_32f                                                         byte    
freeze_thaw_days_m8             8 freeze_thaw_days                                                                byte    
days_precip_above_10mm_m8       8 days_precip_above_10mm                                                          byte    
heating_degree_days_m8          8 heating_degree_days                                                             float   
cooling_degree_days_m8          8 cooling_degree_days                                                             float   
mean_temp_c_m8                  8 mean_temp_c                                                                     float   
tmean_variance_c2_m8            8 tmean_variance_c2                                                               float   
tmin_variance_c2_m8             8 tmin_variance_c2                                                                float   
tmax_variance_c2_m8             8 tmax_variance_c2                                                                float   
n_days_m9                       9 n_days                                                                          byte    
days_extremely_cold_m9          9 days_extremely_cold                                                             byte    
days_below_freezing_32f_m9      9 days_below_freezing_32f                                                         byte    
freeze_thaw_days_m9             9 freeze_thaw_days                                                                byte    
days_precip_above_10mm_m9       9 days_precip_above_10mm                                                          byte    
heating_degree_days_m9          9 heating_degree_days                                                             float   
cooling_degree_days_m9          9 cooling_degree_days                                                             float   
mean_temp_c_m9                  9 mean_temp_c                                                                     float   
tmean_variance_c2_m9            9 tmean_variance_c2                                                               float   
tmin_variance_c2_m9             9 tmin_variance_c2                                                                float   
tmax_variance_c2_m9             9 tmax_variance_c2                                                                float   
n_days_m10                      10 n_days                                                                         byte    
days_extremely_cold_m10         10 days_extremely_cold                                                            byte    
days_below_freezing_32f_m10     10 days_below_freezing_32f                                                        byte    
freeze_thaw_days_m10            10 freeze_thaw_days                                                               byte    
days_precip_above_10mm_m10      10 days_precip_above_10mm                                                         byte    
heating_degree_days_m10         10 heating_degree_days                                                            float   
cooling_degree_days_m10         10 cooling_degree_days                                                            float   
mean_temp_c_m10                 10 mean_temp_c                                                                    float   
tmean_variance_c2_m10           10 tmean_variance_c2                                                              float   
tmin_variance_c2_m10            10 tmin_variance_c2                                                               float   
tmax_variance_c2_m10            10 tmax_variance_c2                                                               float   
n_days_m11                      11 n_days                                                                         byte    
days_extremely_cold_m11         11 days_extremely_cold                                                            byte    
days_below_freezing_32f_m11     11 days_below_freezing_32f                                                        byte    
freeze_thaw_days_m11            11 freeze_thaw_days                                                               byte    
days_precip_above_10mm_m11      11 days_precip_above_10mm                                                         byte    
heating_degree_days_m11         11 heating_degree_days                                                            float   
cooling_degree_days_m11         11 cooling_degree_days                                                            float   
mean_temp_c_m11                 11 mean_temp_c                                                                    float   
tmean_variance_c2_m11           11 tmean_variance_c2                                                              float   
tmin_variance_c2_m11            11 tmin_variance_c2                                                               float   
tmax_variance_c2_m11            11 tmax_variance_c2                                                               float   
n_days_m12                      12 n_days                                                                         byte    
days_extremely_cold_m12         12 days_extremely_cold                                                            byte    
days_below_freezing_32f_m12     12 days_below_freezing_32f                                                        byte    
freeze_thaw_days_m12            12 freeze_thaw_days                                                               byte    
days_precip_above_10mm_m12      12 days_precip_above_10mm                                                         byte    
heating_degree_days_m12         12 heating_degree_days                                                            float   
cooling_degree_days_m12         12 cooling_degree_days                                                            float   
mean_temp_c_m12                 12 mean_temp_c                                                                    float   
tmean_variance_c2_m12           12 tmean_variance_c2                                                              float   
tmin_variance_c2_m12            12 tmin_variance_c2                                                               float   
tmax_variance_c2_m12            12 tmax_variance_c2                                                               float   
total_snowfall_mm_m1            1 total_snowfall_mm                                                               float   
mean_snow_depth_m1              1 mean_snow_depth                                                                 float   
total_snowfall_mm_m2            2 total_snowfall_mm                                                               float   
mean_snow_depth_m2              2 mean_snow_depth                                                                 float   
total_snowfall_mm_m3            3 total_snowfall_mm                                                               float   
mean_snow_depth_m3              3 mean_snow_depth                                                                 float   
total_snowfall_mm_m4            4 total_snowfall_mm                                                               float   
mean_snow_depth_m4              4 mean_snow_depth                                                                 float   
total_snowfall_mm_m5            5 total_snowfall_mm                                                               float   
mean_snow_depth_m5              5 mean_snow_depth                                                                 float   
total_snowfall_mm_m6            6 total_snowfall_mm                                                               float   
mean_snow_depth_m6              6 mean_snow_depth                                                                 float   
total_snowfall_mm_m7            7 total_snowfall_mm                                                               float   
mean_snow_depth_m7              7 mean_snow_depth                                                                 float   
total_snowfall_mm_m8            8 total_snowfall_mm                                                               float   
mean_snow_depth_m8              8 mean_snow_depth                                                                 float   
total_snowfall_mm_m9            9 total_snowfall_mm                                                               float   
mean_snow_depth_m9              9 mean_snow_depth                                                                 float   
total_snowfall_mm_m10           10 total_snowfall_mm                                                              float   
mean_snow_depth_m10             10 mean_snow_depth                                                                float   
total_snowfall_mm_m11           11 total_snowfall_mm                                                              float   
mean_snow_depth_m11             11 mean_snow_depth                                                                float   
total_snowfall_mm_m12           12 total_snowfall_mm                                                              float   
mean_snow_depth_m12             12 mean_snow_depth                                                                float   
population                      Total resident population, all ages, all sexes                                    long    
pop_share_0_4                   Share of population aged 0-4                                                      double  
pop_share_5_9                   Share of population aged 5-9                                                      double  
pop_share_10_14                 Share of population aged 10-14                                                    double  
pop_share_15_19                 Share of population aged 15-19                                                    double  
pop_share_20_24                 Share of population aged 20-24                                                    double  
pop_share_25_29                 Share of population aged 25-29                                                    double  
pop_share_30_34                 Share of population aged 30-34                                                    double  
pop_share_35_39                 Share of population aged 35-39                                                    double  
pop_share_40_44                 Share of population aged 40-44                                                    double  
pop_share_45_49                 Share of population aged 45-49                                                    double  
pop_share_50_54                 Share of population aged 50-54                                                    double  
pop_share_55_59                 Share of population aged 55-59                                                    double  
pop_share_60_64                 Share of population aged 60-64                                                    double  
pop_share_65_69                 Share of population aged 65-69                                                    double  
pop_share_70_74                 Share of population aged 70-74                                                    double  
pop_share_75_79                 Share of population aged 75-79                                                    double  
pop_share_80_84                 Share of population aged 80-84                                                    double  
pop_share_85plus                Share of population aged 85+                                                      double  
population_source               Census product this county-year's total came from                                 str28   
age_source                      Census product this county-year's age detail came from                            str28   
population_flag                 Non-empty if total population is missing//approximate                             str108  
age_flag                        Non-empty if age shares are missing/unusable                                      str43   
state_letter_code               Abbreviation of State Name                                                        str2    
state_name                      Name of State                                                                     str14   
fips                            Combination of State & County FIPS                                                long    
total_total                                                                                                       double  
total_fatal                                                                                                       int     
total_fatalities                                                                                                  int     
total_injury                                                                                                      double  
total_injuries                                                                                                    double  
total_pdo                                                                                                         double  
animal_total                                                                                                      int     
animal_fatal                                                                                                      int     
animal_fatalities                                                                                                 int     
animal_injury                                                                                                     int     
animal_injuries                                                                                                   int     
animal_pdo                                                                                                        int     
animal_total_injury                                                                                               byte    
deer_total                                                                                                        int     
deer_fatal                                                                                                        byte    
deer_fatalities                                                                                                   byte    
deer_injury                                                                                                       byte    
deer_injuries                                                                                                     byte    
deer_pdo                                                                                                          int     
wild_animal_fatal                                                                                                 byte    
wild_animal_injury                                                                                                byte    
wild_animal_pdo                                                                                                   int     
wild_animal_fatalities                                                                                            byte    
wild_animal_injuries                                                                                              byte    
wild_animal_total                                                                                                 int     
imputation_flag_pdo                                                                                               byte    
imputation_flag_total_total                                                                                       byte    
imputation_flag_animal_total                                                                                      byte    
imputation_flag_wild_ani_total                                                                                    byte    
imputation_flag_animal_pdo                                                                                        byte    
imputation_flag_deer_pdo                                                                                          byte    
imputation_flag_total_pdo                                                                                         byte    
imputation_flag_deer_total                                                                                        byte    
any_animal_fatal                                                                                                  int     
any_animal_injury                                                                                                 int     
any_animal_pdo                                                                                                    int     
any_animal_total                                                                                                  int     
any_animal_fatalities                                                                                             int     
any_animal_injuries                                                                                               int     
total_fatalities_to_crashes                                                                                       float   
animal_fatalities_to_crashes                                                                                      float   
deer_fatalities_to_crashes                                                                                        float   
total_pdo_to_crashes                                                                                              float   
animal_pdo_to_crashes                                                                                             float   
deer_pdo_to_crashes                                                                                               float   
deer_pdo_to_fatal                                                                                                 float   
fatalities_to_pdo                                                                                                 float   
totalfatal_to_deerfatal                                                                                           float   
flag_data_issue                                                                                                   byte    
state                           State postal abbreviation                                                         str2    
harvest_total                   Total deer harvested, all categories combined                                     int     
source_harvest                  Compilation: agency-direct harmonization or Schuler et al. CWD panel              str6    
flag_total_constructed          =1 if total was constructed from components rather than source-reported           byte    
flag_hand_transcribed           =1 if figure was hand-transcribed from an image-scanned report (WV only)          byte    
harvest_total_cwd_imputed       CWD imputed harvest value, parked and NOT used in harvest_total                   int     
in_window                       =1 if year in 2005-2014 and harvest observed                                      byte    
main_sample                     =1 if county balanced across all of 2005-2014 (both sources)                      byte    
main_sample_agency              =1 if balanced 2005-2014 AND agency-direct (robustness sample)                    byte    
mean_winter_temp                Mean of Dec(t-1)/Jan(t)/Feb(t) PRISM monthly mean temp, degrees C                 double  
warm_winter_1sd                 1 if mean_winter_temp > county's own full-sample mean + 1 SD                      byte    
warm_winter_2sd                 1 if mean_winter_temp > county's own full-sample mean + 2 SD                      byte    
wsi_cold_days                   WSI cold-stress component: # days Dec 1-Apr 30 with PRISM min temp <=0F           byte    
wsi_snow_days                   WSI snow-hazard component: # days Dec 1-Apr 30 with snow depth >=18in -- MISSING  byte    
winter_severity_index           Winter Severity Index (Kohn 1975 / WI DNR): wsi_cold_days + wsi_snow_days. Categ  byte    
merge_era5_snow                                                                                                   byte    
merge_population                                                                                                  byte    
merge_collisions                                                                                                  byte    
merge_wildlife                                                                                                    byte    
  
Number of variables:    257  
Number of observations: 151145  
Sorted by: geoid year fips_num fips_num fips_num tmean_variance_c2_m10 cooling_degree_days_m3 cooling_degree_days_m3 merge_collisions mean_temp_c_m4 tmin_variance_c2_m10 geoid geoid geoid merge_collisions harvest_total harvest_total geoid geoid geoid state_fips state_fips merge_collisions harvest_total cooling_degree_days_m1 cooling_degree_days_m1 cooling_degree_days_m1 cooling_degree_days_m5 imputation_flag_total_pdo imputation_flag_total_pdo mean_temp_c_m8 days_extremely_cold_m10 source_harvest days_extremely_cold_m1 days_extremely_cold_m1  
  
  
  
## (.venv) wendy-wang@Kodama:~/collisions-and-climate$ python3 describe_dta.py /mnt/data_d/Dropbox/Research/AnimalCollisionsWeather/dataRAW/Collisions/collisions_CONUS_county_year_1985_2020.dta   
  
collisions_CONUS_county_year_1985_2020.dta  
  
Variable                        Label                               Type    
------------------------------  ----------------------------------  ------  
state_letter_code               Abbreviation of State Name          str2    
state_name                      Name of State                       str14   
county_name                     Name of County                      str21   
state_fips                      State Code (FIPS)                   str2    
county_fips                     County Code (FIPS)                  str3    
fips                            Combination of State & County FIPS  long    
year                                                                int     
total_total                                                         double  
total_fatal                                                         int     
total_fatalities                                                    int     
total_injury                                                        double  
total_injuries                                                      double  
total_pdo                                                           double  
animal_total                                                        int     
animal_fatal                                                        int     
animal_fatalities                                                   int     
animal_injury                                                       int     
animal_injuries                                                     int     
animal_pdo                                                          int     
animal_total_injury                                                 byte    
deer_total                                                          int     
deer_fatal                                                          byte    
deer_fatalities                                                     byte    
deer_injury                                                         byte    
deer_injuries                                                       byte    
deer_pdo                                                            int     
wild_animal_fatal                                                   byte    
wild_animal_injury                                                  byte    
wild_animal_pdo                                                     int     
wild_animal_fatalities                                              byte    
wild_animal_injuries                                                byte    
wild_animal_total                                                   int     
imputation_flag_pdo                                                 byte    
imputation_flag_total_total                                         byte    
imputation_flag_animal_total                                        byte    
imputation_flag_wild_ani_total                                      byte    
imputation_flag_animal_pdo                                          byte    
imputation_flag_deer_pdo                                            byte    
imputation_flag_total_pdo                                           byte    
imputation_flag_deer_total                                          byte    
any_animal_fatal                                                    int     
any_animal_injury                                                   int     
any_animal_pdo                                                      int     
any_animal_total                                                    int     
any_animal_fatalities                                               int     
any_animal_injuries                                                 int     
total_fatalities_to_crashes                                         float   
animal_fatalities_to_crashes                                        float   
deer_fatalities_to_crashes                                          float   
total_pdo_to_crashes                                                float   
animal_pdo_to_crashes                                               float   
deer_pdo_to_crashes                                                 float   
deer_pdo_to_fatal                                                   float   
fatalities_to_pdo                                                   float   
totalfatal_to_deerfatal                                             float   
flag_data_issue                                                     byte    
  
Number of variables:    56  
Number of observations: 60804  
Sorted by: state_letter_code county_name year animal_fatal  
