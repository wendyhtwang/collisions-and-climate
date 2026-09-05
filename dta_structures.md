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
  
Variable                        Label                                                   Type    
------------------------------  ------------------------------------------------------  ------  
geoid                                                                                   str5    
state_fips                                                                              str2    
county_fips                                                                             str3    
county_name                                                                             str20   
year                                                                                    int     
n_incomplete_months                                                                     byte    
n_days1                         1 n_days                                                byte    
days_extremely_cold1            1 days_extremely_cold                                   byte    
days_below_freezing_32f1        1 days_below_freezing_32f                               byte    
freeze_thaw_days1               1 freeze_thaw_days                                      byte    
days_precip_above_10mm1         1 days_precip_above_10mm                                byte    
heating_degree_days1            1 heating_degree_days                                   float   
cooling_degree_days1            1 cooling_degree_days                                   float   
mean_temp_c1                    1 mean_temp_c                                           float   
tmean_var_c_sq1                 1 tmean_var_c_sq                                        float   
tmin_variance_c21               1 tmin_variance_c2                                      float   
tmax_variance_c21               1 tmax_variance_c2                                      float   
n_days2                         2 n_days                                                byte    
days_extremely_cold2            2 days_extremely_cold                                   byte    
days_below_freezing_32f2        2 days_below_freezing_32f                               byte    
freeze_thaw_days2               2 freeze_thaw_days                                      byte    
days_precip_above_10mm2         2 days_precip_above_10mm                                byte    
heating_degree_days2            2 heating_degree_days                                   float   
cooling_degree_days2            2 cooling_degree_days                                   float   
mean_temp_c2                    2 mean_temp_c                                           float   
tmean_var_c_sq2                 2 tmean_var_c_sq                                        float   
tmin_variance_c22               2 tmin_variance_c2                                      float   
tmax_variance_c22               2 tmax_variance_c2                                      float   
n_days3                         3 n_days                                                byte    
days_extremely_cold3            3 days_extremely_cold                                   byte    
days_below_freezing_32f3        3 days_below_freezing_32f                               byte    
freeze_thaw_days3               3 freeze_thaw_days                                      byte    
days_precip_above_10mm3         3 days_precip_above_10mm                                byte    
heating_degree_days3            3 heating_degree_days                                   float   
cooling_degree_days3            3 cooling_degree_days                                   float   
mean_temp_c3                    3 mean_temp_c                                           float   
tmean_var_c_sq3                 3 tmean_var_c_sq                                        float   
tmin_variance_c23               3 tmin_variance_c2                                      float   
tmax_variance_c23               3 tmax_variance_c2                                      float   
n_days4                         4 n_days                                                byte    
days_extremely_cold4            4 days_extremely_cold                                   byte    
days_below_freezing_32f4        4 days_below_freezing_32f                               byte    
freeze_thaw_days4               4 freeze_thaw_days                                      byte    
days_precip_above_10mm4         4 days_precip_above_10mm                                byte    
heating_degree_days4            4 heating_degree_days                                   float   
cooling_degree_days4            4 cooling_degree_days                                   float   
mean_temp_c4                    4 mean_temp_c                                           float   
tmean_var_c_sq4                 4 tmean_var_c_sq                                        float   
tmin_variance_c24               4 tmin_variance_c2                                      float   
tmax_variance_c24               4 tmax_variance_c2                                      float   
n_days5                         5 n_days                                                byte    
days_extremely_cold5            5 days_extremely_cold                                   byte    
days_below_freezing_32f5        5 days_below_freezing_32f                               byte    
freeze_thaw_days5               5 freeze_thaw_days                                      byte    
days_precip_above_10mm5         5 days_precip_above_10mm                                byte    
heating_degree_days5            5 heating_degree_days                                   float   
cooling_degree_days5            5 cooling_degree_days                                   float   
mean_temp_c5                    5 mean_temp_c                                           float   
tmean_var_c_sq5                 5 tmean_var_c_sq                                        float   
tmin_variance_c25               5 tmin_variance_c2                                      float   
tmax_variance_c25               5 tmax_variance_c2                                      float   
n_days6                         6 n_days                                                byte    
days_extremely_cold6            6 days_extremely_cold                                   byte    
days_below_freezing_32f6        6 days_below_freezing_32f                               byte    
freeze_thaw_days6               6 freeze_thaw_days                                      byte    
days_precip_above_10mm6         6 days_precip_above_10mm                                byte    
heating_degree_days6            6 heating_degree_days                                   float   
cooling_degree_days6            6 cooling_degree_days                                   float   
mean_temp_c6                    6 mean_temp_c                                           float   
tmean_var_c_sq6                 6 tmean_var_c_sq                                        float   
tmin_variance_c26               6 tmin_variance_c2                                      float   
tmax_variance_c26               6 tmax_variance_c2                                      float   
n_days7                         7 n_days                                                byte    
days_extremely_cold7            7 days_extremely_cold                                   byte    
days_below_freezing_32f7        7 days_below_freezing_32f                               byte    
freeze_thaw_days7               7 freeze_thaw_days                                      byte    
days_precip_above_10mm7         7 days_precip_above_10mm                                byte    
heating_degree_days7            7 heating_degree_days                                   float   
cooling_degree_days7            7 cooling_degree_days                                   float   
mean_temp_c7                    7 mean_temp_c                                           float   
tmean_var_c_sq7                 7 tmean_var_c_sq                                        float   
tmin_variance_c27               7 tmin_variance_c2                                      float   
tmax_variance_c27               7 tmax_variance_c2                                      float   
n_days8                         8 n_days                                                byte    
days_extremely_cold8            8 days_extremely_cold                                   byte    
days_below_freezing_32f8        8 days_below_freezing_32f                               byte    
freeze_thaw_days8               8 freeze_thaw_days                                      byte    
days_precip_above_10mm8         8 days_precip_above_10mm                                byte    
heating_degree_days8            8 heating_degree_days                                   float   
cooling_degree_days8            8 cooling_degree_days                                   float   
mean_temp_c8                    8 mean_temp_c                                           float   
tmean_var_c_sq8                 8 tmean_var_c_sq                                        float   
tmin_variance_c28               8 tmin_variance_c2                                      float   
tmax_variance_c28               8 tmax_variance_c2                                      float   
n_days9                         9 n_days                                                byte    
days_extremely_cold9            9 days_extremely_cold                                   byte    
days_below_freezing_32f9        9 days_below_freezing_32f                               byte    
freeze_thaw_days9               9 freeze_thaw_days                                      byte    
days_precip_above_10mm9         9 days_precip_above_10mm                                byte    
heating_degree_days9            9 heating_degree_days                                   float   
cooling_degree_days9            9 cooling_degree_days                                   float   
mean_temp_c9                    9 mean_temp_c                                           float   
tmean_var_c_sq9                 9 tmean_var_c_sq                                        float   
tmin_variance_c29               9 tmin_variance_c2                                      float   
tmax_variance_c29               9 tmax_variance_c2                                      float   
n_days10                        10 n_days                                               byte    
days_extremely_cold10           10 days_extremely_cold                                  byte    
days_below_freezing_32f10       10 days_below_freezing_32f                              byte    
freeze_thaw_days10              10 freeze_thaw_days                                     byte    
days_precip_above_10mm10        10 days_precip_above_10mm                               byte    
heating_degree_days10           10 heating_degree_days                                  float   
cooling_degree_days10           10 cooling_degree_days                                  float   
mean_temp_c10                   10 mean_temp_c                                          float   
tmean_var_c_sq10                10 tmean_var_c_sq                                       float   
tmin_variance_c210              10 tmin_variance_c2                                     float   
tmax_variance_c210              10 tmax_variance_c2                                     float   
n_days11                        11 n_days                                               byte    
days_extremely_cold11           11 days_extremely_cold                                  byte    
days_below_freezing_32f11       11 days_below_freezing_32f                              byte    
freeze_thaw_days11              11 freeze_thaw_days                                     byte    
days_precip_above_10mm11        11 days_precip_above_10mm                               byte    
heating_degree_days11           11 heating_degree_days                                  float   
cooling_degree_days11           11 cooling_degree_days                                  float   
mean_temp_c11                   11 mean_temp_c                                          float   
tmean_var_c_sq11                11 tmean_var_c_sq                                       float   
tmin_variance_c211              11 tmin_variance_c2                                     float   
tmax_variance_c211              11 tmax_variance_c2                                     float   
n_days12                        12 n_days                                               byte    
days_extremely_cold12           12 days_extremely_cold                                  byte    
days_below_freezing_32f12       12 days_below_freezing_32f                              byte    
freeze_thaw_days12              12 freeze_thaw_days                                     byte    
days_precip_above_10mm12        12 days_precip_above_10mm                               byte    
heating_degree_days12           12 heating_degree_days                                  float   
cooling_degree_days12           12 cooling_degree_days                                  float   
mean_temp_c12                   12 mean_temp_c                                          float   
tmean_var_c_sq12                12 tmean_var_c_sq                                       float   
tmin_variance_c212              12 tmin_variance_c2                                     float   
tmax_variance_c212              12 tmax_variance_c2                                     float   
population                      Total resident population, all ages, all sexes          long    
pop_share_0_4                   Share of population aged 0-4                            double  
pop_share_5_9                   Share of population aged 5-9                            double  
pop_share_10_14                 Share of population aged 10-14                          double  
pop_share_15_19                 Share of population aged 15-19                          double  
pop_share_20_24                 Share of population aged 20-24                          double  
pop_share_25_29                 Share of population aged 25-29                          double  
pop_share_30_34                 Share of population aged 30-34                          double  
pop_share_35_39                 Share of population aged 35-39                          double  
pop_share_40_44                 Share of population aged 40-44                          double  
pop_share_45_49                 Share of population aged 45-49                          double  
pop_share_50_54                 Share of population aged 50-54                          double  
pop_share_55_59                 Share of population aged 55-59                          double  
pop_share_60_64                 Share of population aged 60-64                          double   
pop_share_65_69                 Share of population aged 65-69                          double  
pop_share_70_74                 Share of population aged 70-74                          double  
pop_share_75_79                 Share of population aged 75-79                          double  
pop_share_80_84                 Share of population aged 80-84                          double  
pop_share_85plus                Share of population aged 85+                            double  
population_source               Census product this county-year's total came from       str28   
age_source                      Census product this county-year's age detail came from  str28   
population_flag                 Non-empty if total population is missing//approximate   str108  
age_flag                        Non-empty if age shares are missing/unusable            str43   
state_letter_code               Abbreviation of State Name                              str2    
state_name                      Name of State                                           str14   
total_total                                                                             double  
total_fatal                                                                             int     
total_fatalities                                                                        int     
total_injury                                                                            double  
total_injuries                                                                          double  
total_pdo                                                                               double  
animal_total                                                                            int     
animal_fatal                                                                            int     
animal_fatalities                                                                       int     
animal_injury                                                                           int     
animal_injuries                                                                         int     
animal_pdo                                                                              int     
animal_total_injury                                                                     byte    
deer_total                                                                              int     
deer_fatal                                                                              byte    
deer_fatalities                                                                         byte    
deer_injury                                                                             byte    
deer_injuries                                                                           byte    
deer_pdo                                                                                int     
wild_animal_fatal                                                                       byte    
wild_animal_injury                                                                      byte    
wild_animal_pdo                                                                         int     
wild_animal_fatalities                                                                  byte    
wild_animal_injuries                                                                    byte    
wild_animal_total                                                                       int     
imputation_flag_pdo                                                                     byte    
imputation_flag_total_total                                                             byte    
imputation_flag_animal_total                                                            byte    
imputation_flag_wild_ani_total                                                          byte    
imputation_flag_animal_pdo                                                              byte    
imputation_flag_deer_pdo                                                                byte    
imputation_flag_total_pdo                                                               byte    
imputation_flag_deer_total                                                              byte    
any_animal_fatal                                                                        int     
any_animal_injury                                                                       int     
any_animal_pdo                                                                          int     
any_animal_total                                                                        int     
any_animal_fatalities                                                                   int     
any_animal_injuries                                                                     int     
total_fatalities_to_crashes                                                             float   
animal_fatalities_to_crashes                                                            float   
deer_fatalities_to_crashes                                                              float   
total_pdo_to_crashes                                                                    float   
animal_pdo_to_crashes                                                                   float   
deer_pdo_to_crashes                                                                     float   
deer_pdo_to_fatal                                                                       float   
fatalities_to_pdo                                                                       float   
totalfatal_to_deerfatal                                                                 float   
flag_data_issue                                                                         byte    
merge_population                                                                        byte    
merge_collisions                                                                        byte    
merge_wildlife                                                                          byte    
  
Number of variables:    215  
Number of observations: 139877  
Sorted by: geoid year tmax_variance_c21 tmax_variance_c21 merge_population tmax_variance_c21 days_precip_above_10mm2 days_precip_above_10mm2 pop_share_45_49 merge_population days_precip_above_10mm2 days_precip_above_10mm2 days_precip_above_10mm2 merge_population days_precip_above_10mm2 days_extremely_cold2 days_extremely_cold2 merge_population days_extremely_cold2 tmax_variance_c24 tmin_variance_c210 days_precip_above_10mm2 days_precip_above_10mm2 merge_population days_precip_above_10mm2 days_extremely_cold2 days_extremely_cold2 merge_population days_extremely_cold2 tmax_variance_c24 tmin_variance_c210 days_below_freezing_32f9  
  
  
  
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
