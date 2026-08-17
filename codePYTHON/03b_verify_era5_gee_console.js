/**
 * Manually recomputes one county-day's ERA5-Land derived values directly
 * in the Earth Engine Code Editor, to check them against
 * 03a_test_era5_extract.py's CSV output.
 *
 * - Recomputes the same derived bands as add_derived_bands() in
 *   03a_test_era5_extract.py (Kelvin->Celsius, wind speed from u/v,
 *   meters->mm) -- unlike PRISM's console check, this is testing real
 *   conversion math, not just band selection. Keep in sync if
 *   add_derived_bands() changes.
 * - Defaults are pre-filled with Elkhart County, IN (GEOID 18039),
 *   2020-01-01, matching a row already in
 *   dataRAW/ERA5/era5_county_daily_IN_2020_20260805_084325.csv.
 *
 * HOW TO USE
 * 1. Go to https://code.earthengine.google.com/, signed into the
 *    "collisions-and-climate" project.
 * 2. Paste this file into the Editor pane and click "Run".
 * 3. Open the "Console" tab to see the print() output.
 * 4. Compare the printed values to the matching row in
 *    dataRAW/ERA5/test/era5_county_daily_*.csv. Last-decimal-place
 *    differences are floating-point noise; first/second-decimal
 *    differences are worth investigating.
 */

// ---------------------------------------------------------------------
// 1) Pick one county + one date to check.
// ---------------------------------------------------------------------
var GEOID = '18039';   // Elkhart County, IN. Try '17121' (Marion, IL) too.
var DATE = '2020-01-01';

// Same county source and identifier used by the Python script.
var county = ee.FeatureCollection('TIGER/2018/Counties')
    .filter(ee.Filter.eq('GEOID', GEOID))
    .first();
print('County:', county.get('NAME'), '| GEOID:', county.get('GEOID'));

// Same date window used by build_year_image_collection() in the Python
// script -- one day, since 03a exports daily (not monthly) values.
var startDate = ee.Date(DATE);
var endDate = startDate.advance(1, 'day');

// Same raw bands read in 03a_test_era5_extract.py, before conversion.
var RAW_BANDS = [
  'temperature_2m', 'temperature_2m_min', 'temperature_2m_max',
  'dewpoint_temperature_2m', 'skin_temperature',
  'u_component_of_wind_10m', 'v_component_of_wind_10m',
  'snow_depth', 'snowfall_sum', 'surface_pressure',
  'total_precipitation_sum',
];

var era5Day = ee.ImageCollection('ECMWF/ERA5_LAND/DAILY_AGGR')
    .filterDate(startDate, endDate)
    .select(RAW_BANDS);

print('Images found for this date (should be exactly 1):', era5Day.size());

var image = ee.Image(era5Day.first());
print('Date of image:', ee.Date(image.get('system:time_start')));

// Same scale/tileScale as SCALE_METERS / TILE_SCALE in 03a -- keep these
// in sync if you ever change them there.
var SCALE_METERS = 11132.0;
var TILE_SCALE = 4;

// ---------------------------------------------------------------------
// 2) Recompute the derived bands, mirroring add_derived_bands() in
//    03a_test_era5_extract.py exactly.
// ---------------------------------------------------------------------
var tmean_c = image.select('temperature_2m').subtract(273.15).rename('tmean_c');
var tmin_c = image.select('temperature_2m_min').subtract(273.15).rename('tmin_c');
var tmax_c = image.select('temperature_2m_max').subtract(273.15).rename('tmax_c');
var dewpoint_c = image.select('dewpoint_temperature_2m').subtract(273.15).rename('dewpoint_c');
var skin_temp_c = image.select('skin_temperature').subtract(273.15).rename('skin_temp_c');

var wind_speed_10m = image.select('u_component_of_wind_10m').pow(2)
    .add(image.select('v_component_of_wind_10m').pow(2))
    .sqrt()
    .rename('wind_speed_10m');

var precip_mm = image.select('total_precipitation_sum').multiply(1000).rename('precip_mm');
var snowfall_mm = image.select('snowfall_sum').multiply(1000).rename('snowfall_mm');

var derived = image.addBands([
  tmean_c, tmin_c, tmax_c, dewpoint_c, skin_temp_c,
  wind_speed_10m, precip_mm, snowfall_mm,
]).select([
  'tmean_c', 'tmin_c', 'tmax_c', 'dewpoint_c', 'skin_temp_c',
  'wind_speed_10m', 'snow_depth', 'snowfall_mm', 'surface_pressure', 'precip_mm',
]);

// ---------------------------------------------------------------------
// 3) Reduce over the county, same reducer/scale/tileScale as
//    reduce_image_by_county() in gee_extract_utils.py.
// ---------------------------------------------------------------------
var countyMeans = derived.reduceRegion({
  reducer: ee.Reducer.mean(),
  geometry: county.geometry(),
  scale: SCALE_METERS,
  tileScale: TILE_SCALE,
});
print('Derived bands (compare to the matching date row in the CSV):', countyMeans);

// ---------------------------------------------------------------------
// 4) Sanity check the raw values behind the conversions, so a mismatch
//    above can be traced to "wrong raw band" vs. "wrong conversion math".
// ---------------------------------------------------------------------
var rawMeans = image.reduceRegion({
  reducer: ee.Reducer.mean(),
  geometry: county.geometry(),
  scale: SCALE_METERS,
  tileScale: TILE_SCALE,
});
print('Raw bands before conversion (Kelvin / meters -- for tracing mismatches):', rawMeans);
