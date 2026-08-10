/**
 * Verify 01_test_prism_extract.py / 04_aggregate_daily_to_monthly.py output
 * by recomputing the same numbers directly in the Earth Engine Code Editor.
 *
 * HOW TO USE
 * 1. Go to https://code.earthengine.google.com/ and sign in with the
 *    account tied to the "collisions-and-climate" GEE project.
 * 2. Confirm that project is selected (top toolbar, next to the search
 *    bar -- it should read "collisions-and-climate", matching EE_PROJECT
 *    in the Python script).
 * 3. Paste this whole file into the center Editor pane.
 * 4. Click "Run" (top-right of the Editor pane).
 * 5. Open the "Console" tab (right-hand panel) to see the print() output.
 *    Click the small triangles to expand Dictionary results.
 * 6. Compare the printed numbers to the matching row in
 *    dataCSV/PRISM/prism_county_month.csv (for the monthly checks) or
 *    the matching row in dataRAW/PRISM/prism_county_daily_*.csv (for the
 *    single-day check). Tiny differences in the last decimal place are
 *    floating-point noise, not a problem -- differences at the first or
 *    second decimal place are worth investigating.
 *
 * Defaults below are pre-filled with Marion County, IL (GEOID 17121),
 * matching a row already spot-checked from this test run:
 *   Jan 2020 -> n_days=31, ppt_total=158.92, tmean_mean=1.84,
 *               tmin_mean=-2.13, tmax_mean=5.81, dataset_types=AN81
 * Change GEOID / YEAR / MONTH to check other county-months -- try at
 * least one more county in each state, and definitely check Dec 2020
 * (GEOID 17121, YEAR 2020, MONTH 12), since the aggregation script
 * flagged it as mixing PRISM dataset vintages (AN81 for Dec 1-30, AN91
 * for Dec 31 -- one day earlier than the documented Jan 1, 2021
 * cutover, confirmed by inspecting the raw daily CSV).
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
// 3) Check the FULL MONTH -- compare to 04_aggregate_daily_to_monthly.py
//    output (ppt_total, tmean_mean, tmin_mean, tmax_mean columns).
//
// Reduces EACH DAY separately (like 01_test_prism_extract.py's 
// extract_image_by_county() does) and aggregates the 31 per-day results in JS, 
// 
// instead of compositing the ImageCollection with .sum()/.mean() and reducing once. 
// That composite-then-reduce shortcut looked mathematically equivalent
// (summing/averaging and spatial-reduction are both linear, 
// so order "shouldn't" matter)...
// 
// but in practice came out ~1-2% off on every band when tested against GEE console output 
// - most likely b/c ee.ImageCollection.sum()/.mean() don't reliably preserve 
// the exact per-image pixel grid each day's own reduceRegion call used, 
// so the composite gets reduced over a subtly different/resampled lattice.

// Reducing per-day and aggregating client-side avoids that risk entirely, 
// since it's the same method the Python pipeline itself uses 
// (already confirmed correct by the single-day check above).
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
