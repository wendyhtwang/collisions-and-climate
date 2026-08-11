/**
 * Manually recomputes one county's PRISM daily and monthly values
 * directly in the Earth Engine Code Editor, to check them against
 * 01_test_prism_extract.py / 05_aggregate_daily_to_monthly.py's CSV
 * output.
 *
 * - Defaults are pre-filled with Marion County, IL (GEOID 17121), Jan
 *   2020 -- a row already spot-checked from the test run.
 * - Also worth checking Dec 2020 (same GEOID, MONTH=12): the aggregation
 *   script flags it as mixing PRISM vintages (AN81/AN91) at the
 *   2020/2021 boundary.
 *
 * HOW TO USE
 * 1. Go to https://code.earthengine.google.com/, signed into the
 *    "collisions-and-climate" project.
 * 2. Paste this file into the Editor pane and click "Run".
 * 3. Open the "Console" tab to see the print() output.
 * 4. Compare to the matching row in dataCSV/PRISM/prism_county_month.csv
 *    (monthly checks) or dataRAW/PRISM/prism_county_daily_*.csv (daily
 *    check). Last-decimal-place differences are floating-point noise;
 *    first/second-decimal differences are worth investigating.
 */

// ---------------------------------------------------------------------
// 1) Pick one county + one month to check.
// ---------------------------------------------------------------------
var GEOID = '17121';   // Marion County, IL. Try '18039' (Elkhart, IN) too.
var YEAR = 2020;
var MONTH = 1;         // 1-12

// Same county source and identifier used by the Python script.
var county = ee.FeatureCollection('TIGER/2018/Counties')
    .filter(ee.Filter.eq('GEOID', GEOID))
    .first();
print('County:', county.get('NAME'), '| GEOID:', county.get('GEOID'));

// Same date window used by build_year_collection() in the Python script.
var startDate = ee.Date.fromYMD(YEAR, MONTH, 1);
var endDate = startDate.advance(1, 'month');

var prismMonth = ee.ImageCollection('OREGONSTATE/PRISM/ANd')
    .filterDate(startDate, endDate)
    .select(['ppt', 'tmean', 'tmin', 'tmax']);

print('Days of daily imagery found for this month (should match n_days):',
      prismMonth.size());

// Same scale/tileScale as SCALE_METERS / tileScale in the Python script --
// keep these in sync with 01_test_prism_extract.py if you ever change them.
var SCALE_METERS = 4638.3;
var TILE_SCALE = 4;

// ---------------------------------------------------------------------
// 2) Check ONE day -- compare directly to a row in the raw daily CSV.
// ---------------------------------------------------------------------
var oneDay = ee.Image(prismMonth.first());
print('Date of first image this month:', ee.Date(oneDay.get('system:time_start')));
print('PRISM dataset_type for this image (compare to the "dataset_type" column):',
      oneDay.get('dataset_type'));

var dailyMeans = oneDay.reduceRegion({
  reducer: ee.Reducer.mean(),
  geometry: county.geometry(),
  scale: SCALE_METERS,
  tileScale: TILE_SCALE,
});
print('Single-day county means (compare to the matching date row in the daily CSV):',
      dailyMeans);

// ---------------------------------------------------------------------
// 3) Check the FULL MONTH -- compare to 05_aggregate_daily_to_monthly.py
//    output (ppt_total, tmean_mean, tmin_mean, tmax_mean columns).
//
// Reduces each day separately and aggregates client-side, matching the
// Python pipeline's method -- compositing with .sum()/.mean() first and
// reducing once tested ~1-2% off (see SCRIPT_OVERVIEW.md for why).
// ---------------------------------------------------------------------
var dailyReduced = prismMonth.map(function(img) {
  img = ee.Image(img);
  var means = img.reduceRegion({
    reducer: ee.Reducer.mean(),
    geometry: county.geometry(),
    scale: SCALE_METERS,
    tileScale: TILE_SCALE,
  });
  return ee.Feature(null, means).set(
      'date', ee.Date(img.get('system:time_start')).format('YYYY-MM-dd'));
});

print('Monthly total ppt, summed day-by-day (compare to ppt_total):',
      dailyReduced.aggregate_array('ppt').reduce(ee.Reducer.sum()));
print('Monthly mean tmean, averaged day-by-day (compare to tmean_mean):',
      dailyReduced.aggregate_array('tmean').reduce(ee.Reducer.mean()));
print('Monthly mean tmin, averaged day-by-day (compare to tmin_mean):',
      dailyReduced.aggregate_array('tmin').reduce(ee.Reducer.mean()));
print('Monthly mean tmax, averaged day-by-day (compare to tmax_mean):',
      dailyReduced.aggregate_array('tmax').reduce(ee.Reducer.mean()));

// ---------------------------------------------------------------------
// 4) Optional: list each day's dataset_type for the month, to confirm
//    (or investigate) any "mixed vintage" flag from the aggregation
//    script -- e.g. run with YEAR=2020, MONTH=12 to see the AN81->AN91
//    switch land on Dec 31 rather than Jan 1.
// ---------------------------------------------------------------------
var dailyVintages = prismMonth.map(function(img) {
  img = ee.Image(img);
  return ee.Feature(null, {
    date: ee.Date(img.get('system:time_start')).format('YYYY-MM-dd'),
    dataset_type: img.get('dataset_type'),
  });
});
print('Per-day dataset_type for the selected month:',
      dailyVintages.aggregate_array('date').zip(
          dailyVintages.aggregate_array('dataset_type')));
